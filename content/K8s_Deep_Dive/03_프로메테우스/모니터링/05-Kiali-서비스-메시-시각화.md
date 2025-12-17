---
title: Kiali - 서비스 메시 시각화의 정석
tags:
  - Kiali
  - Istio
  - ServiceMesh
  - Visualization
  - Prometheus
aliases:
  - Kiali
  - 서비스메시시각화
  - 키알리
date: 2025-12-09
category: K8s_Deep_Dive/프로메테우스/모니터링
status: 완성
priority: 높음
---

# Kiali - 서비스 메시 시각화

> [!note] 핵심 개념
> Kiali는 Istio 서비스 메시를 **눈으로 볼 수 있게** 만드는 시각화 도구입니다.

## 📌 왜 Kiali인가?

### 문제 상황
```yaml
마이크로서비스 환경:
  - Service A → Service B → Service C
  - 어디서 느린지?
  - 어디서 에러가 나는지?
  - 트래픽 흐름이 어떻게 되는지?

→ kubectl logs로는 파악 불가능
→ Prometheus 메트릭만으로는 관계 파악 어려움
```

### Kiali의 해결책
```yaml
시각적 표현:
  ┌─────┐      ┌─────┐      ┌─────┐
  │  A  │─────→│  B  │─────→│  C  │
  └─────┘ 99%  └─────┘ 50%  └─────┘
           ✅          ❌

→ 한눈에 파악: B → C 구간에 문제!
→ 에러율, 응답시간, 트래픽량 실시간 표시
```

---

## 🎯 Kiali의 핵심 기능

### 1. Graph View (그래프 뷰)

> [!example] 가장 강력한 기능
> 서비스 간 **실시간 트래픽 흐름**을 시각화

#### 표시 정보
```yaml
노드 (서비스):
  - 서비스 이름
  - 버전 정보 (v1, v2)
  - 상태 (정상, 경고, 에러)

엣지 (연결선):
  - 요청 성공률 (99.5%)
  - 응답 시간 (p95: 200ms)
  - 트래픽량 (10 req/s)
  - 프로토콜 (HTTP, gRPC, TCP)
```

#### 실전 예시
```
┌──────────────────────────────────────┐
│  Kiali Graph View                    │
├──────────────────────────────────────┤
│                                      │
│   [Frontend]                         │
│        │ 100 req/s                   │
│        │ 99.9% ✅                    │
│        ↓                             │
│   [API Gateway]                      │
│        ├─→ [Order Service] 98% ✅    │
│        │                             │
│        └─→ [Payment] 50% ❌          │
│                ↓                     │
│           [DB] timeout               │
└──────────────────────────────────────┘

→ Payment 서비스 문제 즉시 발견!
```

---

### 2. Applications View (애플리케이션 뷰)

> [!tip] 애플리케이션 단위 모니터링

#### 표시 정보
```yaml
각 애플리케이션:
  - Health Status (건강도)
  - 에러율
  - 요청 처리량
  - 응답 시간 분포
  - 연결된 서비스 목록
```

#### 실무 활용
```yaml
시나리오: "주문 시스템이 느려요"

1. Applications 탭 클릭
2. "order-app" 선택
3. 한눈에 확인:
   ✅ Frontend: 정상
   ✅ Order API: 정상
   ❌ Payment Service: 응답시간 3초

→ 문제 지점 즉시 파악!
```

---

### 3. Workloads View (워크로드 뷰)

> [!note] Pod/Deployment 레벨 상세 정보

#### 표시 정보
```yaml
각 Workload:
  - Pod 개수 및 상태
  - CPU/메모리 사용률
  - 컨테이너 상태
  - Istio 사이드카 주입 여부
  - 로그 바로가기
```

#### 실전 예시
```
Workload: payment-service
├─ Pods: 3/3 Running
├─ CPU: 45%
├─ Memory: 1.2GB / 2GB
├─ Istio Sidecar: ✅ Injected
└─ Recent Logs:
   ERROR: Database connection timeout
   → 문제 원인 발견!
```

---

### 4. Services View (서비스 뷰)

> [!example] Kubernetes Service + Istio VirtualService

#### 표시 정보
```yaml
각 Service:
  - 엔드포인트 목록
  - 라우팅 규칙 (VirtualService)
  - Destination Rules
  - 연결된 Workload
  - 트래픽 분배 비율
```

#### Canary 배포 모니터링
```yaml
Service: api-service

Traffic Splitting:
  ├─ v1 (stable): 90% → 99.9% success ✅
  └─ v2 (canary): 10% → 95% success ⚠️

→ v2에 문제 있음, 롤백 고려!
```

---

### 5. Istio Config (설정 검증)

> [!warning] 설정 오류 자동 감지

#### 검증 항목
```yaml
자동 체크:
  - VirtualService 문법 오류
  - DestinationRule 충돌
  - Gateway 설정 문제
  - AuthorizationPolicy 오류

결과:
  ✅ Valid
  ⚠️ Warning
  ❌ Error
```

#### 실전 예시
```yaml
❌ Error: VirtualService "api-route"
   문제: host "api.example.com" not found
   원인: Gateway에 해당 host 정의 안 됨

→ 설정 배포 전에 미리 발견!
```

---

## 🔧 Kiali 동작 원리

### 데이터 소스
```yaml
Kiali가 데이터를 가져오는 곳:

1. Prometheus:
   - 메트릭 데이터
   - istio_requests_total
   - istio_request_duration_seconds

2. Kubernetes API:
   - Pod, Service 정보
   - Deployment 상태

3. Istio API:
   - VirtualService
   - DestinationRule
   - Gateway 설정

4. Jaeger (선택):
   - Distributed Tracing
   - 요청 흐름 추적
```

### 아키텍처
```
┌─────────────────────────────────────┐
│           Kiali UI                  │
│      (Web Browser)                  │
└────────────┬────────────────────────┘
             ↓ HTTP
┌─────────────────────────────────────┐
│        Kiali Backend                │
├─────────────────────────────────────┤
│  ┌─────────┬──────────┬──────────┐ │
│  │Prometheus│   K8s   │  Istio  │ │
│  │  Query  │   API   │   API   │ │
│  └────┬────┴────┬─────┴────┬────┘ │
└───────│─────────│──────────│──────┘
        ↓         ↓          ↓
   [Prometheus] [K8s] [Istio Control]
```

---

## 💼 실무 활용 시나리오

### 시나리오 1: 장애 대응

> [!example] "API가 느려요!"

**문제 접수**:
```
사용자: "주문이 안 돼요!"
시간: 오후 2시
```

**Kiali로 빠른 파악**:
```yaml
1단계: Graph View 확인 (10초)
   → payment-service 에러율 50%

2단계: Workloads 클릭 (5초)
   → payment-service Pod 1개만 Running
   → 나머지 2개 CrashLoopBackOff

3단계: Logs 확인 (5초)
   → "Database connection pool exhausted"

4단계: 조치 (1분)
   → Pod 스케일 아웃
   → DB 커넥션 풀 증가

총 소요 시간: 1분 30초 ✅
```

**Kiali 없었다면**:
```yaml
1. kubectl get pods (어디가 문제지?)
2. kubectl logs payment-xxx (하나씩 확인)
3. kubectl describe pod (왜 죽었지?)
4. Prometheus 쿼리 작성 (메트릭 찾기)
5. 관계 파악 (어디서 호출되나?)

총 소요 시간: 20분+ ❌
```

---

### 시나리오 2: Canary 배포 모니터링

> [!tip] 새 버전 안전하게 배포

**배포 계획**:
```yaml
기존: api-v1 (100%)
신규: api-v2 (테스트 필요)

단계:
  1. v2 10% 트래픽
  2. 문제 없으면 50%
  3. 문제 없으면 100%
```

**Kiali로 실시간 모니터링**:
```yaml
Graph View - Versioned App Graph:

[Frontend]
    ├─→ [API v1] 90%
    │    └─ Success: 99.9% ✅
    │    └─ Latency: 100ms
    │
    └─→ [API v2] 10%
         └─ Success: 99.8% ✅
         └─ Latency: 95ms

결과: v2 성능 더 좋음! → 50%로 증가
```

---

### 시나리오 3: 보안 정책 검증

> [!warning] mTLS 적용 확인

**보안 요구사항**:
```yaml
모든 서비스 간 통신:
  - mTLS 암호화 필수
  - 인증서 검증
```

**Kiali로 시각 확인**:
```yaml
Graph View - Security Display:

[Service A] ──🔒──→ [Service B]  ✅ mTLS
                       ↓
                       🔒
                       ↓
               [Service C]  ✅ mTLS

vs

[Legacy]    ──🚫──→ [Service D]  ❌ Plain HTTP

→ Legacy 서비스 문제 즉시 발견!
```

---

## 🎨 Kiali Graph 종류

### 1. Versioned App Graph
```yaml
용도: Canary 배포, A/B 테스트
표시: 버전별 트래픽 분리

[App v1] ─→ [DB]
    │
[App v2] ──┘

→ 버전별 성능 비교
```

### 2. Workload Graph
```yaml
용도: Deployment 단위 분석
표시: Pod 레벨 상세 정보

[Frontend Deployment]
       ↓
[API Deployment]
       ↓
[DB StatefulSet]

→ 실제 Pod 상태 확인
```

### 3. Service Graph
```yaml
용도: 서비스 아키텍처 파악
표시: Kubernetes Service 단위

[frontend-svc]
       ↓
[api-svc]
       ↓
[mysql-svc]

→ 전체 구조 이해
```

---

## ⚙️ Kiali 설치 및 설정

### 빠른 설치
```bash
# Istio addons으로 설치 (가장 간단)
kubectl apply -f https://raw.githubusercontent.com/istio/istio/release-1.20/samples/addons/kiali.yaml

# 접속
kubectl port-forward -n istio-system svc/kiali 20001:20001
# 브라우저: http://localhost:20001
```

### 프로덕션 설치
```bash
# Helm으로 설치 (권장)
helm repo add kiali https://kiali.org/helm-charts
helm install kiali-server kiali/kiali-server \
  -n istio-system \
  -f kiali-values.yaml
```

### 주요 설정
```yaml
# kiali-values.yaml
auth:
  strategy: "anonymous"  # 또는 "token", "openid"

external_services:
  prometheus:
    url: "http://prometheus.monitoring:9090"
  grafana:
    url: "http://grafana.monitoring:3000"
  tracing:
    enabled: true
    url: "http://jaeger-query:16686"

deployment:
  ingress:
    enabled: true
    class_name: nginx
    hosts:
    - kiali.example.com
```

---

## 🔍 Kiali vs 다른 도구

| 기능 | Kiali | Grafana | Jaeger |
|------|-------|---------|--------|
| **서비스 그래프** | ✅ 최고 | ⚠️ 플러그인 필요 | ❌ 없음 |
| **메트릭 대시보드** | ⚠️ 기본만 | ✅ 최고 | ❌ 없음 |
| **Tracing** | ⚠️ 연동만 | ❌ 없음 | ✅ 최고 |
| **Istio 설정** | ✅ 관리 가능 | ❌ 없음 | ❌ 없음 |
| **학습 곡선** | 쉬움 | 중간 | 어려움 |
| **주 용도** | 서비스 메시 | 메트릭 시각화 | 분산 추적 |

### 실무 조합
```yaml
권장 구성:
  - Kiali: 서비스 관계 파악, 빠른 장애 대응
  - Grafana: 상세 메트릭, 커스텀 대시보드
  - Jaeger: 복잡한 트랜잭션 디버깅

사용 순서:
  1. Kiali Graph: "어디가 문제인가?"
  2. Kiali Workload: "어떤 Pod가 문제인가?"
  3. Grafana: "정확한 수치는?"
  4. Jaeger: "왜 느린가?"
```

---

## 💡 실무 팁

### 1. Display 옵션 활용
```yaml
Graph 화면 우측 설정:

Traffic Animation: ON
  → 트래픽 흐름 시각적 표시

Traffic Distribution:
  → Requests percentage 표시

Security:
  → mTLS 적용 여부 표시 (자물쇠 아이콘)

Response Time:
  → p50, p95, p99 표시
```

### 2. 시간 범위 조정
```yaml
우측 상단 Time Range:

Last 1m: 실시간 모니터링
Last 5m: 최근 트렌드
Last 30m: 배포 후 안정성 확인
Custom: 특정 시간대 분석
```

### 3. Namespace 필터링
```yaml
Graph 상단:

Namespace: default, prod, staging
  → 한 번에 여러 네임스페이스 선택 가능

App: 특정 애플리케이션만
Workload: 특정 워크로드만
```

### 4. 문제 있는 곳 빠르게 찾기
```yaml
Graph Legend:

🟢 녹색: 정상
🟡 노란색: 경고 (에러율 < 5%)
🔴 빨간색: 심각 (에러율 ≥ 5%)

→ 빨간색부터 클릭해서 확인!
```

---

## 🚨 주의사항

### Kiali의 한계

> [!warning] 완벽하지 않습니다

```yaml
❌ 할 수 없는 것:

1. 메트릭 장기 보관
   → Prometheus retention 기간에 의존

2. 복잡한 쿼리
   → PromQL 직접 작성은 Grafana가 나음

3. 로그 집계
   → ELK나 Loki 필요

4. 비즈니스 메트릭
   → 커스텀 대시보드는 Grafana로
```

### 성능 고려사항
```yaml
Kiali 리소스 사용:

기본:
  - CPU: 0.5 core
  - Memory: 1GB

대규모 클러스터 (100+ 서비스):
  - CPU: 2 core
  - Memory: 4GB
  - Prometheus 부하 증가

→ 적절한 리소스 할당 필요
```

---

## 🔗 연관 문서

### 📚 이어서 읽기
```yaml
시각화 마스터:
  - [[06-모니터링-트레이드오프]] - 언제 Kiali를 도입할까?
  - [[07-4-Golden-Signals]] - Kiali에서 무엇을 봐야 하나?
  - [[08-Istio-모니터링-통합]] - Istio + Kiali 통합

기반 지식:
  - [[../01_프로메테우스_기초_개념_완벽_정리]] - 메트릭 이해
  - [[03-관측성-3대-축]] - 시각화의 역할
  - [[09-모니터링-스택-설치-순서]] - Kiali 설치 타이밍
```

---

## 📚 더 읽어보기

### 공식 문서
- [Kiali 공식 문서](https://kiali.io/docs/)
- [Kiali Features](https://kiali.io/docs/features/)
- [Kiali FAQ](https://kiali.io/docs/faq/)

### 실습 자료
- [Kiali Tutorial](https://kiali.io/docs/tutorials/)
- [Istio Observability](https://istio.io/latest/docs/tasks/observability/)

---

## 🎯 핵심 요약

> [!tip] Kiali 한 줄 요약
> **"서비스 메시를 눈으로 보고 싶다면 Kiali!"**

```yaml
Kiali의 가치:

1. 빠른 장애 대응
   - 1분 안에 문제 지점 파악

2. 직관적 이해
   - 복잡한 마이크로서비스도 한눈에

3. 안전한 배포
   - Canary 배포 실시간 모니터링

4. 보안 검증
   - mTLS 적용 여부 시각적 확인

결론:
  Istio 쓰면 Kiali는 필수!
  "보이지 않으면 관리할 수 없다"
```

---

**📅 작성일**: 2025년 12월 9일
**🎯 난이도**: 초급~중급
**⏱️ 학습 시간**: 30분~1시간
