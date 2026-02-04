---
title: 카카오 OAuth 토큰 갱신 트러블슈팅
tags:
  - oauth
  - kakao
  - troubleshooting
  - api
aliases:
  - 카카오 토큰 갱신
  - Kakao OAuth
date: 2026-02-02
category: 1_가이드/API
status: 완성
priority: 높음
---

# 카카오 OAuth 토큰 갱신 트러블슈팅

> [!note] 배경
> Daily Paper Summary 프로젝트에서 카카오톡 알림이 갑자기 안 오는 문제 발생. 원인은 Access Token 만료 (-401 에러).

---

## 1. 문제 상황

### 증상
- `run.sh` 실행 시 카카오톡 알림이 전송되지 않음
- curl 응답: `{"msg":"this access token does not exist","code":-401}`

### 원인
- 카카오 Access Token은 약 **6시간**만 유효
- 기존에는 토큰 만료 시 수동으로 재발급 필요

---

## 2. 해결 과정

### 2.1 OAuth 기본 개념 복습

```
┌─────────────┐     1. 인증 요청         ┌─────────────┐
│   사용자      │ ──────────────────▶    │  카카오      │
│  (브라우저)   │                        │   인증서버    │
└─────────────┘                        └─────────────┘
       │                                    │
       │ 2. 로그인 & 동의                   │
       │◀───────────────────────────────────│
       │                                    │
       │ 3. Authorization Code              │
       │◀───────────────────────────────────│
       │                                    │
┌─────────────┐     4. Code → Token   ┌─────────────┐
│   내 서버     │ ──────────────────▶   │  카카오      │
│  (localhost)│                       │  토큰서버     │
└─────────────┘ ◀──────────────────── └─────────────┘
                  5. Access + Refresh Token
```

### 2.2 Redirect URI 문제

> [!warning] 삽질 포인트 1
> 카카오는 **HTTPS만 허용** (localhost 제외)

**시도한 것들:**
| Redirect URI | 결과 | 에러 |
|-------------|------|------|
| `https://on.epix.kr/oauth` | 실패 | KOE201 (서비스 설정 오류) |
| `https://localhost/oauth` | 실패 | 페이지 없음 (코드는 URL에 있음) |
| `http://localhost:8888/oauth` | 성공 | - |

**해결:** localhost는 HTTP도 허용됨!

### 2.3 로컬 OAuth 서버 구현

간단한 Go 서버로 Authorization Code를 받아 Token으로 교환:

```go
// oauth_server.go (임시 사용 후 삭제)
http.HandleFunc("/oauth", func(w http.ResponseWriter, r *http.Request) {
    code := r.URL.Query().Get("code")

    // Token 교환
    data := url.Values{}
    data.Set("grant_type", "authorization_code")
    data.Set("client_id", clientID)
    data.Set("client_secret", clientSecret)
    data.Set("redirect_uri", redirectURI)
    data.Set("code", code)

    resp, _ := http.Post(
        "https://kauth.kakao.com/oauth/token",
        "application/x-www-form-urlencoded",
        strings.NewReader(data.Encode()),
    )
    // ... 토큰 파싱 및 출력
})
```

### 2.4 Authorization Code 사용 시 주의

> [!danger] 삽질 포인트 2
> Authorization Code는 **1회용**! 한 번 사용하면 즉시 만료됨.

```bash
# 이미 사용된 코드로 재시도 시
{"error":"invalid_grant","error_description":"authorization code not found","error_code":"KOE320"}
```

**교훈:** 서버를 먼저 종료하고 코드를 수동으로 교환하려 했더니 실패. 서버가 이미 코드를 소비한 상태였음.

---

## 3. 최종 구현

### 3.1 .env 파일 구조

```bash
# Kakao API (나에게 보내기)
KAKAO_REST_API_KEY=f26e933c...
KAKAO_CLIENT_SECRET=lutzieHp...
KAKAO_ACCESS_TOKEN=GORQAqCk...   # 6시간 유효
KAKAO_REFRESH_TOKEN=VzG5Npa4...  # 2달 유효
```

### 3.2 자동 토큰 갱신 로직 (run.sh)

```bash
# 카카오 메시지 전송
KAKAO_RESULT=$(curl -s -X POST "https://kapi.kakao.com/v2/api/talk/memo/default/send" \
  -H "Authorization: Bearer $KAKAO_ACCESS_TOKEN" \
  -d "template_object=$TEMPLATE")

# 토큰 만료 시 자동 갱신
if echo "$KAKAO_RESULT" | grep -q '"code":-401'; then
  echo "토큰 만료. 갱신 중..."

  # Refresh Token으로 새 Access Token 발급
  REFRESH_RESULT=$(curl -s -X POST "https://kauth.kakao.com/oauth/token" \
    -d "grant_type=refresh_token" \
    -d "client_id=$KAKAO_REST_API_KEY" \
    -d "client_secret=$KAKAO_CLIENT_SECRET" \
    -d "refresh_token=$KAKAO_REFRESH_TOKEN")

  NEW_ACCESS=$(echo "$REFRESH_RESULT" | grep -o '"access_token":"[^"]*"' | cut -d'"' -f4)
  NEW_REFRESH=$(echo "$REFRESH_RESULT" | grep -o '"refresh_token":"[^"]*"' | cut -d'"' -f4)

  # .env 업데이트
  sed -i '' "s|KAKAO_ACCESS_TOKEN=.*|KAKAO_ACCESS_TOKEN=$NEW_ACCESS|" .env
  if [ -n "$NEW_REFRESH" ]; then
    sed -i '' "s|KAKAO_REFRESH_TOKEN=.*|KAKAO_REFRESH_TOKEN=$NEW_REFRESH|" .env
  fi

  # 재전송
  curl -s -X POST "..." -H "Authorization: Bearer $NEW_ACCESS" ...
fi
```

---

## 4. 토큰 생명주기

### 4.1 유효기간

| 토큰 종류 | 유효기간 | 갱신 조건 |
|----------|---------|----------|
| Access Token | 약 6시간 (21599초) | Refresh Token으로 갱신 |
| Refresh Token | 약 2달 | 만료 1달 전부터 갱신 시 새로 발급 |

### 4.2 자동 갱신 흐름

```
[Access Token 만료]
       │
       ▼
[Refresh Token으로 갱신 요청]
       │
       ├── Refresh Token 유효기간 > 1달 ──▶ Access Token만 발급
       │
       └── Refresh Token 유효기간 < 1달 ──▶ 둘 다 새로 발급
```

> [!tip] 핵심
> **한 달에 한 번만 실행**되어도 Refresh Token이 자동 갱신되므로, 사실상 **영구적으로 재인증 불필요**!

---

## 5. 카카오 개발자 콘솔 설정

### 필수 설정 항목

1. **내 애플리케이션 → 앱 설정 → 앱 키**
   - REST API 키 복사

2. **제품 설정 → 카카오 로그인**
   - 활성화 설정: ON
   - Redirect URI 등록: `http://localhost:8888/oauth`

3. **제품 설정 → 카카오 로그인 → 보안**
   - Client Secret 생성 및 활성화

4. **제품 설정 → 카카오 로그인 → 동의항목**
   - `talk_message` (카카오톡 메시지 전송) 권한 설정

---

## 6. 빠른 재인증 가이드

2달 이상 미사용으로 Refresh Token이 만료된 경우:

### 6.1 임시 OAuth 서버 실행

```go
// oauth_server.go 생성 후
go run oauth_server.go
```

### 6.2 브라우저에서 인증

```
https://kauth.kakao.com/oauth/authorize?client_id={REST_API_KEY}&redirect_uri=http://localhost:8888/oauth&response_type=code&scope=talk_message
```

### 6.3 토큰 확인 및 .env 업데이트

터미널에 출력된 토큰을 `.env`에 복사

---

## 7. 에러 코드 정리

| 코드 | 설명 | 해결 |
|------|------|------|
| -401 | Access Token 만료/무효 | Refresh Token으로 갱신 |
| KOE201 | 서비스 설정 오류 | 개발자 콘솔에서 앱 설정 확인 |
| KOE303 | Redirect URI 불일치 | 등록된 URI와 정확히 일치하는지 확인 |
| KOE320 | Authorization Code 무효 | 코드는 1회용, 새로 발급 필요 |

---

> 작성일: 2026-02-02 | Daily Paper Summary 프로젝트
