---
title: 포트폴리오 상태 모니터링 API 구축 - Go + Cloud Run
tags:
  - portfolio
  - go
  - cloud-run
  - api
  - monitoring
  - devops
aliases:
  - 포트폴리오 API
  - Status API
date: 2026-01-16
category: 포트폴리오/인프라
status: 진행중
priority: 높음
---

# 🎯 포트폴리오 상태 모니터링 API 구축

## 📑 목차
- [[#1. 프로젝트 개요|프로젝트 개요]]
- [[#2. 아키텍처 설계|아키텍처 설계]]
- [[#3. Go API 구현|Go API 구현]]
- [[#4. 포트폴리오 연동|포트폴리오 연동]]
- [[#5. 배포 계획|배포 계획]]

---

## 1. 프로젝트 개요

> [!note] 핵심 아이디어
> 포트폴리오 사이트 자체가 "실시간 모니터링 대시보드"가 되어, 실제 운영 중인 프로젝트들의 상태를 증명

### 💡 왜 만들었나?

**문제 상황**:
- 포트폴리오에 프로젝트를 나열만 하면 "실제로 운영 중인지" 증명 어려움
- 클라우드 엔지니어 신입 지원 시 "실전 경험"을 어필할 방법 필요

**솔루션**:
- Netlify 배포 프로젝트들의 실시간 상태 체크
- GA4 데이터 시각화 (숫자 노출 없이 트렌드만)
- 30초마다 자동 갱신으로 "지금도 운영 중" 증명

### 🎯 목표

1. **실시간 상태 모니터링**: 2개 프로젝트의 Online/Offline 상태
2. **트렌드 시각화**: 7일간 트래픽 트렌드 (정규화된 값)
3. **무료 운영**: Cloud Run 무료 티어 내에서 운영
4. **빠른 응답**: Go 기반으로 평균 응답시간 < 100ms

---

## 2. 아키텍처 설계

### 📊 전체 구조

```
[사용자 브라우저]
       ↓
┌─────────────────────────────────┐
│ GitHub Pages / Netlify          │  ← 포트폴리오 HTML (정적)
│ portfolio-3d.html               │
└─────────────────────────────────┘
       ↓ (JavaScript fetch, 30초마다)
┌─────────────────────────────────┐
│ GCP Cloud Run                   │  ← Go API
│ portfolio-status-api            │
│ - 30초 캐싱                     │
│ - CORS 허용                     │
└─────────────────────────────────┘
       ↓ (Health Check)
┌─────────────────────────────────┐
│ 실제 프로젝트들                  │
│ - openchatt.netlify.app         │
│ - biz.epix.kr                   │
└─────────────────────────────────┘
```

### 🏗️ Go API 구조

```
status-api/
├── main.go              # HTTP 서버 + 캐싱
├── handlers/
│   ├── health.go       # Netlify 프로젝트 핑 체크
│   └── analytics.go    # GA4 데이터 (Mock)
├── models/
│   └── types.go        # 데이터 구조
├── Dockerfile          # Cloud Run 배포용
├── deploy.sh           # 배포 스크립트
└── README.md
```

### 💾 데이터 모델

```go
type ProjectStatus struct {
    Name       string    // "오픈챗 서비스"
    URL        string    // "https://openchatt.netlify.app"
    Status     string    // "online" | "offline"
    ResponseMs int       // 응답 시간 (ms)
    CheckedAt  time.Time
}

type AnalyticsData struct {
    ProjectName string
    Trend       []int     // [58, 64, 64, 55, 57, 49, 67]
    Activity    string    // "high" | "medium" | "low"
    Growth      string    // "up" | "stable" | "down"
}
```

---

## 3. Go API 구현

### 🔧 핵심 기능

#### 3.1. Health Check (handlers/health.go)

```go
// 5초 타임아웃으로 프로젝트 핑 체크
// Goroutine으로 병렬 처리 (빠른 응답)

var projects = []struct {
    Name string
    URL  string
}{
    {"오픈챗 서비스", "https://openchatt.netlify.app"},
    {"비즈니스 명함", "https://biz.epix.kr"},
}

func CheckAllProjects(ctx context.Context) []models.ProjectStatus {
    // 병렬로 모든 프로젝트 체크
    // HTTP 200-399 → "online"
    // 그 외 → "offline"
}
```

#### 3.2. 캐싱 (main.go)

```go
// 30초 캐싱으로 API 호출 최소화
const cacheDuration = 30 * time.Second

// 백그라운드 고루틴으로 캐시 자동 갱신
go cacheUpdater()
```

#### 3.3. CORS 설정

```go
func corsMiddleware(next http.HandlerFunc) http.HandlerFunc {
    return func(w http.ResponseWriter, r *http.Request) {
        w.Header().Set("Access-Control-Allow-Origin", "*")
        w.Header().Set("Access-Control-Allow-Methods", "GET, OPTIONS")
        // GitHub Pages에서 호출 가능
    }
}
```

### 📊 API 엔드포인트

| 엔드포인트 | 설명 | 응답 시간 |
|-----------|------|----------|
| `GET /api/status` | 전체 상태 (프로젝트 + 분석) | ~80ms |
| `GET /api/health` | 프로젝트 상태만 | ~75ms |
| `GET /api/analytics` | GA4 분석만 | ~5ms |

### 🧪 로컬 테스트 결과

```json
{
  "projects": [
    {
      "name": "오픈챗 서비스",
      "url": "https://openchatt.netlify.app",
      "status": "online",
      "responseMs": 74
    },
    {
      "name": "비즈니스 명함",
      "url": "https://biz.epix.kr",
      "status": "online",
      "responseMs": 83
    }
  ],
  "analytics": [
    {
      "projectName": "오픈챗 서비스",
      "trend": [58, 64, 64, 55, 57, 49, 67],
      "activity": "medium",
      "growth": "stable"
    }
  ]
}
```

---

## 4. 포트폴리오 연동

### 🎨 UI 디자인 (화이트 & 블랙 미니멀)

#### 4.1. 프로젝트 카드 하단 상태 표시

```
┌─────────────────────────────────┐
│ 오픈챗 서비스                    │
│ Netlify 배포 | 2024 - 현재      │
│ [설명...]                       │
│                                 │
│ [Netlify] [실시간] [서버리스]   │
├─────────────────────────────────┤
│ 🟢 Online (74ms)  ▂▃▅▇█▆▇      │ ← 새로 추가!
└─────────────────────────────────┘
```

#### 4.2. CSS 스타일

```css
/* 상태 점 (깜빡임 애니메이션) */
.status-dot.online {
    background: #000000;
    animation: pulse 2s infinite;
}

/* 7일 트렌드 차트 */
.trend-bar {
    width: 4px;
    background: #E5E5E5;
    border-radius: 2px;
}

.trend-bar.active {
    background: #000000;  /* 50% 이상 */
}
```

#### 4.3. JavaScript API 연동

```javascript
const API_URL = 'http://localhost:8080';  // 로컬 테스트
// const API_URL = 'https://portfolio-status-api-xxxxx.run.app';  // 배포 후

async function fetchProjectStatus() {
    const response = await fetch(`${API_URL}/api/status`);
    const data = await response.json();

    // 프로젝트 카드 업데이트
    updateProjectStatus(card, status, analytics);
}

// 30초마다 자동 갱신
setInterval(fetchProjectStatus, 30000);
```

---

## 5. 배포 계획

### 🚀 Cloud Run 배포 단계

#### 5.1. 배포 스크립트 실행

```bash
cd /Users/a1234/portfolio/status-api
./deploy.sh
```

**배포 과정**:
1. Go 코드 빌드
2. Docker 이미지 생성
3. Google Container Registry 업로드
4. Cloud Run 서비스 생성/업데이트
5. URL 생성: `https://portfolio-status-api-xxxxx-an.a.run.app`

**배포 시간**: 1-2분

#### 5.2. 배포 설정

```bash
gcloud run deploy portfolio-status-api \
  --source . \
  --platform managed \
  --region asia-northeast3 \  # 서울
  --allow-unauthenticated \   # 공개 API
  --memory 128Mi \             # 최소 메모리
  --min-instances 0 \          # 무료 티어
  --max-instances 1
```

#### 5.3. 포트폴리오 HTML URL 변경

```javascript
// 배포 후 API URL 변경
const API_URL = 'https://portfolio-status-api-xxxxx-an.a.run.app';
```

#### 5.4. 포트폴리오 배포

- GitHub Pages 또는
- Netlify

---

## 💰 비용 분석

### Cloud Run 무료 티어

```
월 200만 요청: 무료
180만 vCPU-초: 무료
36만 GB-초: 무료

예상 사용량:
- 요청: ~86,400건/월 (30초마다 × 30일)
- 메모리: 128Mi × 0.1초/요청 = 11,059 GB-초
- vCPU: 1 vCPU × 0.1초/요청 = 8,640 vCPU-초

→ 100% 무료 티어 내 운영 가능! ✅
```

---

## 📊 성과 지표

### 기술적 성과

- ✅ **응답 시간**: 평균 80ms (목표 < 100ms)
- ✅ **가용성**: 두 프로젝트 모두 Online 확인
- ✅ **캐싱**: 30초 단위로 API 호출 최소화
- ✅ **병렬 처리**: Goroutine으로 동시 체크

### 비즈니스 임팩트

> [!tip] 클라우드 엔지니어 역량 증명
> - "실제 운영 중"을 실시간으로 증명
> - Go + Cloud Run 실전 경험
> - 모니터링 시스템 설계 역량
> - 비용 최적화 (무료 티어 운영)

---

## 🔜 다음 단계

### 즉시 진행

1. 브라우저 로컬 테스트 (진행 중)
2. Cloud Run 배포
3. 포트폴리오 HTML URL 변경
4. GitHub Pages 배포

### 향후 개선

1. **GA4 실제 연동**
   - Mock 데이터 → 실제 GA4 Data API
   - Service Account 설정

2. **프로젝트 추가**
   - Quartz 기술 블로그
   - 구글 스프레드시트 웹앱들

3. **알림 기능**
   - 프로젝트 Offline 시 Slack 알림
   - Uptime 통계 누적

---

## 📚 참고 자료

- Go API 소스: `/Users/a1234/portfolio/status-api/`
- 포트폴리오 HTML: `/Users/a1234/portfolio/portfolio-3d.html`
- Cloud Run 문서: https://cloud.google.com/run/docs
- GA4 Data API: https://developers.google.com/analytics/devguides/reporting/data/v1

---

## 🏷️ 관련 문서

- [[GCP Cloud Run 가이드]]
- [[Go 언어 베스트 프랙티스]]
- [[포트폴리오 전략]]
