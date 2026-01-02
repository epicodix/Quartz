---
title: Gemini AI Server v2 - Tailscale Funnel 통합 가이드
tags:
  - gemini
  - ai
  - go
  - python
  - tailscale
  - devops
  - api-server
aliases:
  - gemini-server-v2
  - ai-server-tailscale
date: 2025-12-30
category: GEMINI/2_기술_분석
status: 완성
priority: 높음
---

# 🤖 Gemini AI Server v2 - Tailscale Funnel 통합

> [!info] 프로젝트 정보
> **작성일**: 2025-12-30 19:41 KST
> **경로**: `/Users/a1234/python_algorithm_2026/ai-cli-tool/`
> **기술 스택**: Go 1.21+, Python 3.10+, Gemini 2.5 Flash, Tailscale
> **상태**: 프로덕션 준비 완료 ✅

## 📑 목차
- [[#1. 프로젝트 개요|프로젝트 개요]]
- [[#2. 아키텍처 설계|아키텍처 설계]]
- [[#3. 주요 기능|주요 기능]]
- [[#4. 설치 및 배포|설치 및 배포]]
- [[#5. API 사용 가이드|API 사용 가이드]]
- [[#6. Tailscale 통합|Tailscale 통합]]
- [[#7. 운영 및 모니터링|운영 및 모니터링]]
- [[#8. 트러블슈팅|트러블슈팅]]

---

## 1. 프로젝트 개요

### 🎯 목적

Gemini 2.5 Flash AI 모델을 활용한 뉴스 브리핑 및 정보 검색 서버를 개발하고, Tailscale Funnel을 통해 안전하게 공개 인터넷에 노출하는 프로젝트.

### 💡 핵심 가치

1. **비동기 처리**: 긴 작업을 백그라운드에서 처리하고 웹훅으로 결과 전송
2. **간편한 배포**: 단일 명령어로 서버 배포 및 Tailscale 설정
3. **실시간 모니터링**: 웹 UI와 메트릭스 대시보드 제공
4. **안전한 공개**: Tailscale Funnel로 HTTPS 자동 설정

### 📊 v1 vs v2 비교

| 기능 | v1 (기본) | v2 (개선) |
|------|-----------|-----------|
| 동기 API | ✅ | ✅ |
| 비동기 작업 큐 | ❌ | ✅ (채널 기반) |
| 웹훅 콜백 | ❌ | ✅ |
| 웹 UI | ❌ | ✅ (실시간 메트릭스) |
| Health Check | ❌ | ✅ |
| 메트릭스 API | ❌ | ✅ |
| Tailscale 통합 | ❌ | ✅ (Serve/Funnel) |
| 배포 자동화 | ❌ | ✅ (deploy.sh) |

---

## 2. 아키텍처 설계

### 🏗️ 시스템 구조

```
┌─────────────────────────────────────────────────────────┐
│                   클라이언트 (브라우저/API)              │
└───────────────────────┬─────────────────────────────────┘
                        │
                        │ HTTPS (Tailscale Funnel)
                        │
┌───────────────────────▼─────────────────────────────────┐
│              Tailscale (Serve/Funnel)                    │
└───────────────────────┬─────────────────────────────────┘
                        │
                        │ HTTP/HTTPS
                        │
┌───────────────────────▼─────────────────────────────────┐
│              Go HTTP Server (gemini_server_v2.go)        │
│  ┌─────────────────────────────────────────────────┐    │
│  │  HTTP Handlers                                  │    │
│  │  - / (웹 UI)                                    │    │
│  │  - /api/chat (동기)                             │    │
│  │  - /api/chat/async (비동기)                     │    │
│  │  - /api/jobs/{id} (상태 조회)                   │    │
│  │  - /health, /metrics                            │    │
│  └──────────┬──────────────────────────────────────┘    │
│             │                                            │
│  ┌──────────▼──────────┐      ┌──────────────────┐      │
│  │  Job Queue (채널)   │◄─────┤  Job Store (맵)  │      │
│  └──────────┬──────────┘      └──────────────────┘      │
│             │                                            │
│  ┌──────────▼──────────┐                                │
│  │  Worker Pool        │                                │
│  │  (고루틴 x N)       │                                │
│  └──────────┬──────────┘                                │
└─────────────┼──────────────────────────────────────────┘
              │
              │ exec.Command()
              │
┌─────────────▼─────────────────────────────────────────┐
│       Python Agent (gemini_agent.py)                   │
│  ┌───────────────────────────────────────────────┐    │
│  │  google.genai SDK                             │    │
│  │  - Gemini 2.5 Flash                           │    │
│  │  - Google Search Grounding                    │    │
│  └───────────────────────────────────────────────┘    │
└───────────────────────────────────────────────────────┘
```

### 🔄 요청 처리 흐름

#### 동기 요청 (Sync)

```
1. 클라이언트 → POST /api/chat
2. Go 서버 → Python 에이전트 실행
3. Python → Gemini API 호출
4. Gemini → Google Search Grounding
5. Python → 결과 반환
6. Go 서버 → 클라이언트 응답 (즉시)
```

#### 비동기 요청 (Async)

```
1. 클라이언트 → POST /api/chat/async
2. Go 서버 → Job 생성 + Job ID 반환 (즉시)
3. 백그라운드:
   - Job Queue에 추가
   - Worker가 Job 처리
   - Python 에이전트 호출
   - 결과 저장
   - 웹훅 콜백 (옵션)
4. 클라이언트 → GET /api/jobs/{id} (상태 조회)
```

---

## 3. 주요 기능

### 💬 1. 동기 API (`/api/chat`)

> [!example] 사용 시나리오
> **상황**: 실시간 챗봇 애플리케이션
> **요구사항**: 즉각적인 응답 필요
> **처리 시간**: 평균 2-5초

**요청:**
```bash
curl -X POST http://localhost:8080/api/chat \
  -H "Content-Type: application/json" \
  -d '{"prompt": "오늘 AI 뉴스 요약해줘"}'
```

**응답:**
```json
{
  "response": "오늘 주요 AI 뉴스...",
  "source": "Gemini 2.5 Flash (Sync)",
  "status": "completed"
}
```

### ⏱️ 2. 비동기 API (`/api/chat/async`)

> [!example] 사용 시나리오
> **상황**: 대량의 뉴스 분석 작업
> **요구사항**: 10분 이상 소요되는 작업
> **장점**: 클라이언트 대기 불필요, 서버 부하 분산

**작업 생성:**
```bash
curl -X POST http://localhost:8080/api/chat/async \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "2024년 AI 트렌드 전체 분석",
    "webhook_url": "https://my-app.com/webhook"
  }'
```

**즉시 응답:**
```json
{
  "job_id": "550e8400-e29b-41d4-a716-446655440000",
  "status": "pending",
  "source": "Gemini 2.5 Flash (Async)"
}
```

**상태 조회:**
```bash
curl http://localhost:8080/api/jobs/550e8400-e29b-41d4-a716-446655440000
```

### 🔔 3. 웹훅 콜백

작업 완료 시 지정한 URL로 POST 요청:

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "prompt": "2024년 AI 트렌드 전체 분석",
  "status": "completed",
  "response": "...",
  "created_at": "2025-12-30T10:00:00Z",
  "completed_at": "2025-12-30T10:05:00Z"
}
```

### 🌐 4. 웹 UI

> [!tip] 주요 기능
> - 실시간 요청/응답 테스트
> - 비동기 작업 상태 추적
> - 서버 메트릭스 대시보드 (자동 새로고침 5초마다)

**접속:**
- 로컬: `http://localhost:8080`
- Tailscale: `https://epix-macbookair`
- Funnel: `https://epix-macbookair.{tailnet}.ts.net`

---

## 4. 설치 및 배포

### 📦 사전 준비

```bash
# 1. Go 설치 확인
go version  # 1.21+

# 2. Python 설치 확인
python3 --version  # 3.10+

# 3. Tailscale 설치 (선택)
tailscale version

# 4. Python 패키지 설치
pip3 install google-genai
```

### ⚙️ 환경 설정

```bash
# .env 파일 생성
cd /Users/a1234/python_algorithm_2026/ai-cli-tool
cat > .env <<EOF
GEMINI_API_KEY=your_gemini_api_key_here
EOF
```

### 🚀 빠른 배포

```bash
# 방법 1: 자동 배포 (권장)
./deploy.sh

# 방법 2: Funnel 활성화
./deploy.sh --funnel

# 방법 3: 개발 모드 (Tailscale 없이)
./deploy.sh --dev

# 방법 4: 워커 수 조정
./deploy.sh --workers 10
```

### 🔧 수동 배포

```bash
# 1. Go 의존성 설치
go get github.com/joho/godotenv
go get github.com/google/uuid

# 2. 빌드
go build -o gemini_server_v2 gemini_server_v2.go

# 3. 실행
./gemini_server_v2 -server -workers 3

# 4. Tailscale 설정 (별도 터미널)
./setup_tailscale.sh serve
```

---

## 5. API 사용 가이드

### 📡 엔드포인트 요약

| HTTP | 경로 | 설명 | 응답시간 |
|------|------|------|----------|
| `GET` | `/` | 웹 UI | 즉시 |
| `POST` | `/api/chat` | 동기 채팅 | 2-10초 |
| `POST` | `/api/chat/async` | 비동기 채팅 | 즉시 (Job ID) |
| `GET` | `/api/jobs/{id}` | 작업 상태 | 즉시 |
| `GET` | `/health` | Health Check | 즉시 |
| `GET` | `/metrics` | 메트릭스 | 즉시 |

### 💻 코드 예시

#### Python 클라이언트

```python
import requests
import time

# 동기 요청
def sync_request(prompt):
    res = requests.post(
        "http://localhost:8080/api/chat",
        json={"prompt": prompt}
    )
    return res.json()

# 비동기 요청
def async_request(prompt, webhook_url=None):
    # 작업 생성
    res = requests.post(
        "http://localhost:8080/api/chat/async",
        json={
            "prompt": prompt,
            "webhook_url": webhook_url
        }
    )
    job_id = res.json()["job_id"]

    # 폴링 (웹훅 없을 때)
    while True:
        status = requests.get(
            f"http://localhost:8080/api/jobs/{job_id}"
        ).json()

        if status["status"] == "completed":
            return status["response"]
        elif status["status"] == "failed":
            raise Exception(status["error"])

        time.sleep(2)

# 사용 예시
result = sync_request("오늘 뉴스")
print(result["response"])
```

#### JavaScript (Fetch API)

```javascript
// 동기 요청
async function syncRequest(prompt) {
    const res = await fetch('http://localhost:8080/api/chat', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ prompt })
    });
    return await res.json();
}

// 비동기 요청
async function asyncRequest(prompt, webhookUrl) {
    // 작업 생성
    const createRes = await fetch('http://localhost:8080/api/chat/async', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ prompt, webhook_url: webhookUrl })
    });
    const { job_id } = await createRes.json();

    // 폴링
    while (true) {
        const statusRes = await fetch(`http://localhost:8080/api/jobs/${job_id}`);
        const status = await statusRes.json();

        if (status.status === 'completed') {
            return status.response;
        } else if (status.status === 'failed') {
            throw new Error(status.error);
        }

        await new Promise(r => setTimeout(r, 2000));
    }
}

// 사용
syncRequest('오늘 AI 뉴스').then(data => console.log(data.response));
```

---

## 6. Tailscale 통합

### 🔐 Tailscale Serve (내부 전용)

> [!note] 권장 설정
> Tailscale 네트워크 내부에서만 접근 가능.
> 외부 공개 없이 안전하게 팀원들과 공유.

**설정:**
```bash
./setup_tailscale.sh serve
```

**접속:**
```bash
# Tailscale 디바이스에서
curl https://epix-macbookair/health

# 다른 Tailscale 디바이스에서
curl https://irix/health  # (irix에 서버 실행 시)
```

### 🌍 Tailscale Funnel (공개)

> [!warning] 보안 주의
> 공개 인터넷에서 누구나 접근 가능.
> Rate Limiting과 API 키 인증 추가 권장.

**설정:**
```bash
./setup_tailscale.sh funnel
```

**공개 URL 확인:**
```bash
tailscale funnel status
```

**접속:**
```
https://epix-macbookair.your-tailnet.ts.net
```

### 📊 상태 관리

```bash
# 현재 상태 확인
./setup_tailscale.sh status

# 서비스 중지
./setup_tailscale.sh stop

# 재시작
./setup_tailscale.sh stop
./setup_tailscale.sh serve  # 또는 funnel
```

---

## 7. 운영 및 모니터링

### ❤️ Health Check

```bash
# 서버 상태 확인
curl http://localhost:8080/health
```

**응답:**
```json
{
  "status": "healthy",
  "timestamp": 1735538400,
  "uptime": 3600.5
}
```

### 📊 메트릭스 모니터링

```bash
# 메트릭스 조회
curl http://localhost:8080/metrics | jq
```

**응답:**
```json
{
  "uptime_seconds": 3600.5,
  "total_requests": 150,
  "success_requests": 145,
  "failed_requests": 5,
  "avg_response_time": 2.3,
  "queue_length": 2,
  "total_jobs": 50
}
```

### 📝 로그 관리

```bash
# 실시간 로그
tail -f server.log

# 에러만 필터링
grep "❌" server.log

# 성공 요청만
grep "✅" server.log

# 특정 Job ID 추적
grep "550e8400-e29b-41d4-a716-446655440000" server.log
```

### 🔧 서버 관리

```bash
# 서버 시작
./deploy.sh

# 서버 중지
./deploy.sh --stop

# 재시작
./deploy.sh --stop && ./deploy.sh

# 워커 수 변경
./deploy.sh --stop
./deploy.sh --workers 10
```

---

## 8. 트러블슈팅

### ❓ 문제 해결 가이드

#### 1. 서버가 시작되지 않음

> [!danger] 증상
> `./deploy.sh` 실행 시 오류 발생

**해결 순서:**

```bash
# 1. API 키 확인
cat .env | grep GEMINI_API_KEY

# 2. 포트 충돌 확인
lsof -i :8080

# 3. 충돌 시 프로세스 종료
kill -9 $(lsof -ti:8080)

# 4. Python 패키지 확인
python3 -c "import google.genai" || pip3 install google-genai

# 5. 재시도
./deploy.sh
```

#### 2. Tailscale 연결 실패

> [!danger] 증상
> Tailscale URL로 접속 불가

**해결 순서:**

```bash
# 1. Tailscale 상태 확인
tailscale status

# 2. 인증 여부 확인
tailscale up

# 3. Serve 재설정
./setup_tailscale.sh stop
./setup_tailscale.sh serve

# 4. 방화벽 확인 (macOS)
# 시스템 설정 → 네트워크 → 방화벽
```

#### 3. Python 에이전트 오류

> [!danger] 증상
> 500 에러, "Python 실행 에러"

**해결 순서:**

```bash
# 1. Python 스크립트 직접 실행
export GEMINI_API_KEY="your_key"
python3 gemini_agent.py "테스트"

# 2. 에러 로그 확인
tail -n 50 server.log

# 3. API 키 검증
python3 check_models.py

# 4. Python 경로 확인
which python3
```

#### 4. 작업 큐 지연

> [!warning] 증상
> 비동기 작업이 `pending` 상태로 멈춤

**해결 순서:**

```bash
# 1. 메트릭스 확인
curl http://localhost:8080/metrics

# 2. 워커 수 확인 및 증가
./deploy.sh --stop
./deploy.sh --workers 10

# 3. 큐 길이 모니터링
watch -n 1 'curl -s http://localhost:8080/metrics | jq .queue_length'
```

### 🐛 에러 코드 참조

| HTTP | 의미 | 원인 | 해결 |
|------|------|------|------|
| 400 | Bad Request | JSON 형식 오류 | 요청 페이로드 확인 |
| 404 | Not Found | Job ID 없음 | Job ID 재확인 |
| 405 | Method Not Allowed | GET/POST 잘못 사용 | HTTP 메서드 확인 |
| 500 | Internal Server Error | Python 오류 | `server.log` 확인 |

---

## 9. 다음 단계

### 🚀 향후 개선 계획

1. **인증 시스템**
   - API 키 인증 미들웨어
   - JWT 토큰 기반 인증

2. **Rate Limiting**
   - IP 기반 요청 제한
   - API 키별 할당량 관리

3. **데이터베이스 연동**
   - Job 영속성 (PostgreSQL)
   - 요청 히스토리 저장

4. **멀티 모델 지원**
   - GPT-4 통합
   - Claude 통합
   - 모델 선택 API

5. **Kubernetes 배포**
   - Helm 차트 작성
   - 오토스케일링 설정

### 📚 관련 문서

- [[K8s_Deep_Dive/k8s실습/07_02_서비스와_엔드포인트|Kubernetes 서비스 가이드]]
- [[GCP/Cloud-Run-배포-가이드|GCP Cloud Run 배포]]
- [[Tailscale-네트워크-설정|Tailscale 네트워크 설정]]

---

## 10. 참고 자료

### 🔗 외부 링크

- [Gemini API 문서](https://ai.google.dev/docs)
- [Tailscale Funnel 공식 가이드](https://tailscale.com/kb/1223/funnel)
- [Go Concurrency Patterns](https://go.dev/blog/pipelines)

### 📂 파일 구조

```
ai-cli-tool/
├── gemini_agent.py           # Python AI 에이전트
├── gemini_server_v2.go       # Go HTTP 서버 (v2)
├── deploy.sh                 # 배포 자동화 스크립트
├── setup_tailscale.sh        # Tailscale 설정 스크립트
├── DEPLOYMENT_GUIDE.md       # 상세 배포 가이드
├── .env                      # 환경변수 (비공개)
├── go.mod                    # Go 모듈 정의
├── server.log                # 서버 로그
└── .gemini_server.pid        # 서버 PID 파일
```

---

**마지막 업데이트**: 2025-12-30 19:41 KST
**프로젝트 경로**: `/Users/a1234/python_algorithm_2026/ai-cli-tool/`
**작성자**: Claude Sonnet 4.5
