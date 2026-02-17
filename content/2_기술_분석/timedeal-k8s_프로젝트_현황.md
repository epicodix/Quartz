---
title: timedeal-k8s 프로젝트 현황
tags:
  - kubernetes
  - k3d
  - go
  - react
  - saga-pattern
  - timedeal
  - ecommerce
  - monitoring
aliases:
  - 타임딜 프로젝트
  - timedeal-k8s
date: 2026-02-14
category: 2_기술_분석/쿠버네티스
status: 진행중
priority: 높음
---

# 🎯 timedeal-k8s 프로젝트 현황

> [!note] 프로젝트 요약
> k3d 로컬 클러스터 위에서 타임딜 이커머스의 핵심 패턴(사가 트랜잭션, 실시간 모니터링, 부하 테스트)을 검증하고, EKS 프로덕션 이전을 준비하는 프로젝트.

## 📑 목차
- [[#1. 프로젝트 개요|프로젝트 개요]]
- [[#2. 아키텍처|아키텍처]]
- [[#3. 디렉토리 구조|디렉토리 구조]]
- [[#4. K8s 리소스 현황|K8s 리소스 현황]]
- [[#5. 백엔드 - Go Stock Service|백엔드]]
- [[#6. 프론트엔드 - React UI|프론트엔드]]
- [[#7. 개발 및 운영 명령어|명령어 모음]]
- [[#8. 발견된 이슈와 해결|이슈 트래킹]]
- [[#9. 로드맵|로드맵]]

---

## 1. 프로젝트 개요

| 항목 | 내용 |
|------|------|
| 경로 | `~/timedeal-k8s/` |
| 클러스터 | k3d (k3d-timedeal), 노드 3개 (server 1 + agent 2) |
| 네임스페이스 | `timedeal` |
| Git 계정 | epicodix (Goorm4I 조직) |
| 현재 버전 | stock-service:**v2** (버그 패치 적용) |
| 관련 문서 | [[k3d_EKS_찍먹_가이드_타임딜_사가패턴]], [[timedeal-k8s_PLG_스택_가이드]] |

### 💡 기술 스택

| 레이어 | 기술 | 버전 |
|--------|------|------|
| 프론트엔드 | React + Vite | 19.2 / 8.0-beta |
| 백엔드 | Go (net/http) | 1.22 |
| DB | PostgreSQL (StatefulSet) | 15-alpine |
| 컨테이너 | Docker (멀티스테이지) | Alpine 3.19 |
| 오케스트레이션 | Kubernetes (k3d) | v1.33.6+k3s1 |
| Ingress | Traefik (k3d 내장) | - |

---

## 2. 아키텍처

```
┌──────────────────────────────────────────────────────┐
│  브라우저 (http://localhost:5173)                      │
│  React 프론트엔드                                      │
│  ┌─────────────┐  ┌──────────────────┐                │
│  │ 타임딜 탭   │  │ 모니터링 탭       │                │
│  │ - 카운트다운 │  │ - 총요청/성공률   │                │
│  │ - 상품카드   │  │ - 응답시간 차트   │                │
│  │ - 구매/취소  │  │ - 재고변화 그래프 │                │
│  │ - Toast알림  │  │ - 헬스체크 상태   │                │
│  └─────────────┘  └──────────────────┘                │
└───────────────────────┬──────────────────────────────┘
                        │ Vite proxy (/api → :8080)
                        ▼
              ┌───────────────────┐
              │ k3d Ingress       │
              │ Traefik :8080     │
              │ / → stock-service │
              └────────┬──────────┘
                       ▼
         ┌──────────────────────────┐
         │  stock-service (Go)     │
         │  Pod 1개 (v2)           │
         │  Port 8081              │
         │                         │
         │  /health                │
         │  /api/stock/get         │
         │  /api/stock/reserve     │  ← 사가 Step 1
         │  /api/stock/confirm     │  ← 사가 Step 3 (성공)
         │  /api/stock/cancel      │  ← 보상 트랜잭션
         │                         │
         │  [In-Memory Map+Mutex]  │
         └──────────────────────────┘
                       │
                       ▼ (아직 미연결)
         ┌──────────────────────────┐
         │  PostgreSQL 15           │
         │  StatefulSet (1 Pod)     │
         │  PVC 1Gi                 │
         │  DB: timedeal            │
         └──────────────────────────┘
```

### 📊 사가 패턴 플로우

```
정상 구매:
  reserve (Reserved += N) → 결제처리 → confirm (Quantity -= N, Reserved -= N)

결제 실패 (보상):
  reserve (Reserved += N) → 결제실패 → cancel (Reserved -= N)  ← 원상복구

재고 부족:
  reserve → 409 Conflict → 주문 거부
```

---

## 3. 디렉토리 구조

```
timedeal-k8s/
├── frontend/                       # React + Vite 프론트엔드
│   ├── src/
│   │   ├── App.jsx                 # 메인 앱 (11개 컴포넌트, 단일파일)
│   │   ├── App.css                 # 화이트&블랙 테마 스타일
│   │   ├── index.css               # 글로벌 스타일
│   │   └── main.jsx                # 엔트리포인트
│   ├── dist/                       # 빌드 결과물
│   ├── vite.config.js              # Vite 설정 + API 프록시
│   ├── package.json                # React 19.2, Vite 8
│   └── eslint.config.js
│
├── stock-service/                  # Go 백엔드
│   ├── main.go                     # Stock API (v2 - 버그 수정)
│   ├── Dockerfile                  # 멀티스테이지 빌드
│   └── k8s/
│       └── deployment.yaml         # Deployment + Service
│
├── ingress.yaml                    # Traefik Ingress 라우팅
├── postgres.yaml                   # PostgreSQL StatefulSet + ConfigMap
└── db-secret.yaml                  # DB 자격증명 Secret
```

---

## 4. K8s 리소스 현황

> 2026-02-14 기준 `timedeal` 네임스페이스

### 🔧 워크로드

| 리소스 | 이름 | 상태 | 비고 |
|--------|------|------|------|
| Deployment | stock-service | 1/1 Ready | v2 이미지, HPA 삭제됨 |
| StatefulSet | postgres | 1/1 Ready | PVC 1Gi 바인딩 |
| Ingress | timedeal-ingress | Active | Traefik, `/ → stock-service:8081` |

### 🔧 설정

| 리소스 | 이름 | 용도 |
|--------|------|------|
| ConfigMap | postgres-config | DB명, 유저, 패스워드 |
| Secret | db-credentials | DB 접속 정보 (호스트, 포트 포함) |
| PVC | pgdata-postgres-0 | PostgreSQL 데이터 (1Gi, local-path) |

### 🔧 클러스터 노드 리소스

| 노드 | CPU | 메모리 | 역할 |
|------|-----|--------|------|
| k3d-timedeal-server-0 | ~155m (1%) | ~558Mi (14%) | control-plane |
| k3d-timedeal-agent-0 | ~107m (1%) | ~177Mi (4%) | worker |
| k3d-timedeal-agent-1 | ~120m (1%) | ~217Mi (5%) | worker |
| **합계** | **~382m** | **~952Mi** | 여유 충분 |

---

## 5. 백엔드 - Go Stock Service

### 💻 API 엔드포인트

| 경로 | 메서드 | 설명 | 응답 코드 |
|------|--------|------|-----------|
| `/health` | GET | 헬스체크 | 200 |
| `/api/stock/get` | POST | 재고 조회 | 200 / 404 |
| `/api/stock/reserve` | POST | 재고 임시 예약 | 200 / 409 |
| `/api/stock/confirm` | POST | 재고 확정 차감 | 200 / 409 |
| `/api/stock/cancel` | POST | 예약 롤백 (보상) | 200 |

### 💻 데이터 구조

```go
type Stock struct {
    ProductID int `json:"product_id"`
    Quantity  int `json:"quantity"`   // 실제 재고
    Reserved  int `json:"reserved"`   // 예약 수량
}

// 초기 데이터
stocks = map[int]*Stock{
    1: {ProductID: 1, Quantity: 100, Reserved: 0},
    2: {ProductID: 2, Quantity: 50, Reserved: 0},
}
```

### 📊 v1 → v2 변경사항

| 항목 | v1 (버그) | v2 (수정) |
|------|----------|----------|
| cancelStock | `Reserved -= qty` (음수 가능) | `Reserved < qty` 검증 후 0으로 보호 |
| confirmStock | 재고 부족 검증 없음 | `Quantity < qty` 시 409 반환 |
| 결과 | 100개 넘게 구매 가능 | 재고 0 이하 구매 차단 |

---

## 6. 프론트엔드 - React UI

### 💡 컴포넌트 구조

```
App (App.jsx, 단일 파일)
├── Header                  탭 네비게이션 (타임딜 | 모니터링)
├── TimeDealTab
│   ├── CountdownTimer      10분 카운트다운, 1분 미만 시 빨간색
│   ├── ProductCard          상품 정보 + 재고 프로그레스바
│   ├── PurchaseControls     수량 선택 (1/2/3/5/10) + 구매/취소
│   └── MessageToast         결과 알림 (성공/실패/정보)
└── MonitorTab
    ├── StatsCards            총요청 | 성공률 | 평균응답시간
    ├── ResponseTimeChart     CSS 바 차트 (최근 20건)
    ├── StockHistoryChart     CSS 라인 차트 (최근 30건)
    └── HealthStatus          /health 폴링 (5초 간격)
```

### 📊 디자인 테마

| 요소 | 값 | 용도 |
|------|-----|------|
| 배경 | #FFFFFF, #F8F9FA | 페이지, 카드 |
| 텍스트 | #000000, #1A1A1A | 제목, 본문 |
| 보더 | #E5E5E5 | 카드, 구분선 |
| 버튼 | #000000 → #333333 (hover) | 구매하기 |
| 위험 | #FF4444 | 재고 부족, 느린 응답 |
| 카운트다운 | 블랙 배경 + 화이트 텍스트 | 타이머 영역 |

### 💻 핵심 메커니즘: trackedFetch

모든 API 요청을 래핑하여 모니터링 데이터를 자동 수집하는 함수.

```javascript
const trackedFetch = async (url, opts) => {
  const start = performance.now()
  const res = await fetch(url, opts)
  const elapsed = Math.round(performance.now() - start)
  // → metrics (총요청, 성공/실패, 누적시간) 업데이트
  // → responseHistory (최근 20건) 업데이트
  return res
}
```

### 🔧 폴링 주기

| 대상 | 주기 | 용도 |
|------|------|------|
| 재고 조회 (`/api/stock/get`) | 3초 | 재고 수량 실시간 표시 |
| 헬스 체크 (`/health`) | 5초 | 서비스 상태 모니터링 |
| 카운트다운 | 1초 | 타임딜 타이머 |

---

## 7. 개발 및 운영 명령어

### 🔧 로컬 개발

```bash
# 프론트엔드 개발 서버
cd ~/timedeal-k8s/frontend && npm run dev
# → http://localhost:5173 (Vite proxy → :8080)

# 프론트엔드 빌드
cd ~/timedeal-k8s/frontend && npm run build
```

### 🔧 백엔드 빌드 + 배포

```bash
# Docker 이미지 빌드
docker build -t stock-service:v2 ~/timedeal-k8s/stock-service/

# k3d 클러스터에 이미지 import
k3d image import stock-service:v2 -c timedeal

# 배포 업데이트
kubectl set image deployment/stock-service -n timedeal stock=stock-service:v2

# 또는 전체 재시작
kubectl rollout restart deployment/stock-service -n timedeal
```

### 🔧 K8s 관리

```bash
# 전체 리소스 확인
kubectl get all -n timedeal

# Pod 로그 실시간
kubectl logs -f -l app=stock-service -n timedeal

# 재고 수동 확인
kubectl exec -n timedeal deployment/stock-service -- \
  wget -qO- --post-data='{"product_id":1}' \
  --header='Content-Type: application/json' \
  http://localhost:8081/api/stock/get

# 재고 초기화 (Pod 재시작)
kubectl rollout restart deployment/stock-service -n timedeal
```

### 🔧 부하 테스트

```bash
# hey 설치
brew install hey

# 재고 조회 부하 (동시 10명, 200건)
hey -n 200 -c 10 -m POST \
  -H "Content-Type: application/json" \
  -d '{"product_id":1}' \
  http://localhost:8080/api/stock/get

# 동시 구매 부하 (동시 50명, 150건)
hey -n 150 -c 50 -m POST \
  -H "Content-Type: application/json" \
  -d '{"product_id":1,"quantity":1}' \
  http://localhost:8080/api/stock/reserve
```

---

## 8. 발견된 이슈와 해결

### 🚨 이슈 1: 재고 값 왔다갔다 (90개 ↔ 98개)

> **원인**: In-Memory 저장 + replicas: 2 → Pod마다 독립된 재고 상태
> **해결**: 로컬 테스트 시 replicas: 1 + HPA 삭제

### 🚨 이슈 2: 100개 넘게 구매 가능

> **원인**: `cancelStock`에서 Reserved 음수 보호 없음 → `available = Quantity - (-N)` = 초과
> **해결**: v2 패치 - Reserved/Quantity 하한 검증 추가

### 🚨 이슈 3: replicas 수동 변경이 무시됨

> **원인**: HPA `minReplicas: 2`가 deployment replicas를 강제 복원
> **해결**: `kubectl delete hpa stock-service -n timedeal`

> [!tip] 상세 내용
> [[k3d_EKS_찍먹_가이드_타임딜_사가패턴#부록 A. 발견된 버그와 수정|부록 A 참고]]

---

## 9. 로드맵

### ✅ 완료

- [x] k3d 클러스터 구성 (server 1 + agent 2)
- [x] Go Stock Service 배포 (사가 패턴 API)
- [x] PostgreSQL StatefulSet 배포
- [x] Ingress 라우팅 설정
- [x] React 프론트엔드 리디자인 (화이트&블랙)
- [x] 실시간 모니터링 대시보드 (trackedFetch)
- [x] 백엔드 버그 수정 (v2 - Reserved 음수, Confirm 검증)
- [x] HPA 이슈 해결

### 🔜 다음 단계

- [ ] **PLG 스택 구축** - Prometheus + Loki + Grafana
  - Prometheus: 메트릭 수집 (RPS, P99 응답시간, Pod CPU/메모리)
  - Loki: 로그 중앙화 (Go 서비스 로그 수집)
  - Grafana: 통합 대시보드 (메트릭 + 로그 한 화면)
- [ ] **Redis 도입** - 인메모리 → Redis로 재고 이관
  - Multi-Pod 정합성 해결
  - 분산 락 (Redlock)
  - 타임딜 TTL 자동 만료
- [ ] **대기열 시스템** - Redis List 기반 주문 큐
  - 동시 접속 폭주 시 선착순 큐잉
  - 순차 처리로 서버 부하 분산
- [ ] **Rate Limiting** - API 보호
  - IP당 초당 요청 제한
  - 봇 차단
- [ ] **EKS 이전** - Kustomize overlay 기반 환경 분리
  - RDS 연결
  - ALB Ingress Controller
  - IRSA (ServiceAccount)
