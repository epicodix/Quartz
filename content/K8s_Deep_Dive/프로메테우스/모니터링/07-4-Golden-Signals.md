---
title: 4 Golden Signals - Google SRE 핵심 지표
tags:
  - Prometheus
  - Monitoring
  - SRE
  - Google
  - Metrics
aliases:
  - 4GoldenSignals
  - 골든시그널
date: 2025-12-09
category: K8s_Deep_Dive/프로메테우스/모니터링
status: 완성
priority: 높음
---

# 4 Golden Signals

## 📌 핵심 개념
> Google SRE가 권장하는 **최소한으로 모니터링해야 할 4가지**

뭘 모니터링할지 모르겠다면? → 이 4가지만 봐도 80% 커버!

## 🎯 4가지 신호

### 1. Latency (지연시간)
**질문**: 얼마나 빠르게 응답하나?

#### 측정 대상
```
- API 응답 시간
- 데이터베이스 쿼리 시간
- 페이지 로딩 시간
```

#### Prometheus 예시
```promql
# P95 응답 시간 (95%의 요청이 이 시간 내에 완료)
histogram_quantile(0.95,
  rate(http_request_duration_seconds_bucket[5m])
)

# 슬로우 쿼리 개수
mysql_global_status_slow_queries
```

#### Alert 예시
```yaml
- alert: HighLatency
  expr: histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m])) > 1
  for: 5m
  annotations:
    summary: "API 응답이 느립니다 (P95 > 1초)"
```

---
title: 4 Golden Signals
aliases:
  - 07-4-Golden-Signals
category: K8s_Deep_Dive/프로메테우스/모니터링
status: 완성
priority: 높음

### 2. Traffic (트래픽)
**질문**: 얼마나 많은 요청이 오나?

#### 측정 대상
```
- 초당 요청 수 (RPS, Requests Per Second)
- 초당 쿼리 수 (QPS, Queries Per Second)
- 동시 접속자 수
```

#### Prometheus 예시
```promql
# 초당 HTTP 요청 수
rate(http_requests_total[5m])

# 초당 MySQL 쿼리 수
rate(mysql_global_status_queries[5m])

# Redis 초당 명령 수
rate(redis_commands_processed_total[1m])
```

#### 용도
```
✅ 용량 계획 (스케일링 판단)
✅ 비정상 트래픽 감지 (DDoS, 버그)
✅ 비즈니스 성장 추이
```

---
title: 4 Golden Signals
aliases:
  - 07-4-Golden-Signals
category: K8s_Deep_Dive/프로메테우스/모니터링
status: 완성
priority: 높음

### 3. Errors (에러율)
**질문**: 얼마나 실패하나?

#### 측정 대상
```
- HTTP 5xx 에러율
- HTTP 4xx 에러율 (필요시)
- 데이터베이스 연결 실패
- 타임아웃
```

#### Prometheus 예시
```promql
# 에러율 (5xx)
sum(rate(http_requests_total{status=~"5.."}[5m])) /
sum(rate(http_requests_total[5m])) * 100

# MySQL 커넥션 에러
rate(mysql_global_status_connection_errors_total[5m])

# Redis 연결 실패
redis_rejected_connections_total
```

#### Alert 예시
```yaml
- alert: HighErrorRate
  expr: |
    sum(rate(http_requests_total{status=~"5.."}[5m])) /
    sum(rate(http_requests_total[5m])) > 0.05
  for: 5m
  annotations:
    summary: "에러율이 5%를 초과했습니다"
```

---
title: 4 Golden Signals
aliases:
  - 07-4-Golden-Signals
category: K8s_Deep_Dive/프로메테우스/모니터링
status: 완성
priority: 높음

### 4. Saturation (포화도)
**질문**: 리소스가 얼마나 찼나?

#### 측정 대상
```
- CPU 사용률
- 메모리 사용률
- 디스크 사용률
- 네트워크 대역폭
- 커넥션 풀 사용률
```

#### Prometheus 예시
```promql
# CPU 사용률
100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# 메모리 사용률
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100

# MySQL 커넥션 사용률
mysql_global_status_threads_connected /
mysql_global_variables_max_connections * 100

# Redis 메모리 사용률
redis_memory_used_bytes / redis_memory_max_bytes * 100
```

#### Alert 예시
```yaml
- alert: HighCPU
  expr: node_cpu_usage_percent > 80
  for: 10m
  annotations:
    summary: "CPU 사용률이 80%를 초과했습니다"

- alert: DiskAlmostFull
  expr: node_filesystem_avail_bytes / node_filesystem_size_bytes < 0.1
  for: 5m
  annotations:
    summary: "디스크 여유 공간이 10% 미만입니다"
```

---
title: 4 Golden Signals
aliases:
  - 07-4-Golden-Signals
category: K8s_Deep_Dive/프로메테우스/모니터링
status: 완성
priority: 높음

## 🎨 실전 적용: MySQL 모니터링

### 4 Golden Signals로 구성
```yaml
# 1. Latency
mysql_global_status_slow_queries  # 슬로우 쿼리

# 2. Traffic
mysql_global_status_queries  # 초당 쿼리 수

# 3. Errors
mysql_global_status_connection_errors_total  # 연결 에러

# 4. Saturation
mysql_global_status_threads_connected /
mysql_global_variables_max_connections  # 커넥션 사용률
```

### Grafana 대시보드 예시
```
┌─────────────────────────────┐
│ MySQL 4 Golden Signals      │
├─────────────────────────────┤
│ Latency:                    │
│ 슬로우 쿼리: 5개/분          │
│                             │
│ Traffic:                    │
│ QPS: 1,234                  │
│                             │
│ Errors:                     │
│ 연결 에러: 0                 │
│                             │
│ Saturation:                 │
│ 커넥션 사용률: 65%           │
└─────────────────────────────┘
```

---
title: 4 Golden Signals
aliases:
  - 07-4-Golden-Signals
category: K8s_Deep_Dive/프로메테우스/모니터링
status: 완성
priority: 높음

## 🎯 실전 적용: 웹 애플리케이션

### API 서버 예시
```promql
# 1. Latency - P95 응답 시간
histogram_quantile(0.95,
  rate(http_request_duration_seconds_bucket{job="api"}[5m])
)

# 2. Traffic - 초당 요청 수
sum(rate(http_requests_total{job="api"}[5m]))

# 3. Errors - 에러율
sum(rate(http_requests_total{job="api",status=~"5.."}[5m])) /
sum(rate(http_requests_total{job="api"}[5m]))

# 4. Saturation - Pod CPU 사용률
sum(rate(container_cpu_usage_seconds_total{pod=~"api-.*"}[5m])) /
sum(kube_pod_container_resource_limits{resource="cpu",pod=~"api-.*"})
```

---
title: 4 Golden Signals
aliases:
  - 07-4-Golden-Signals
category: K8s_Deep_Dive/프로메테우스/모니터링
status: 완성
priority: 높음

## 📊 시각화 예시

### 대시보드 레이아웃
```
┌─────────────────────────────────────────┐
│         서비스 건강도 대시보드            │
├─────────────────────────────────────────┤
│ 🟢 Latency: 200ms (목표: <500ms)        │
│ 🟢 Traffic: 1.2K RPS (정상)             │
│ 🟢 Errors: 0.1% (목표: <1%)             │
│ 🟡 Saturation: CPU 75% (주의)           │
├─────────────────────────────────────────┤
│          [그래프 영역]                   │
│   Latency 추이 (최근 24시간)             │
│   [선 그래프]                            │
│                                         │
│   Traffic 추이 (최근 24시간)             │
│   [영역 그래프]                          │
└─────────────────────────────────────────┘
```

---
title: 4 Golden Signals
aliases:
  - 07-4-Golden-Signals
category: K8s_Deep_Dive/프로메테우스/모니터링
status: 완성
priority: 높음

## ⚠️ 흔한 실수

### ❌ 너무 많은 메트릭 수집
```
수백 개의 메트릭 수집
→ 관리 불가능
→ 중요한 것 놓침
```

### ✅ 4 Golden Signals에 집중
```
핵심 4가지만 확실히
→ 이상 징후 빠르게 감지
→ 필요하면 추가 메트릭 수집
```

---
title: 4 Golden Signals
aliases:
  - 07-4-Golden-Signals
category: K8s_Deep_Dive/프로메테우스/모니터링
status: 완성
priority: 높음

## 🎓 확장: USE Method vs RED Method

### USE Method (인프라)
```
For every resource:
- Utilization (사용률)
- Saturation (포화도)
- Errors (에러)

적용 대상: CPU, 메모리, 디스크, 네트워크
```

### RED Method (서비스)
```
For every service:
- Rate (요청률 = Traffic)
- Errors (에러율)
- Duration (응답시간 = Latency)

적용 대상: API, 마이크로서비스
```

**관계**:
- 4 Golden Signals = RED + Saturation
- USE는 인프라에 특화

---
title: 4 Golden Signals
aliases:
  - 07-4-Golden-Signals
category: K8s_Deep_Dive/프로메테우스/모니터링
status: 완성
priority: 높음

## 💡 실무 팁

### 1. 우선순위
```
Phase 1: Errors & Saturation
→ 서비스 죽는 걸 막기 (생존)

Phase 2: Latency
→ 사용자 경험 개선

Phase 3: Traffic
→ 용량 계획, 비즈니스 인사이트
```

### 2. Alert 설정
```
Critical (즉시):
- Errors > 5%
- Saturation > 90%

Warning (근무시간 내):
- Latency P95 > 1초
- Saturation > 80%

Info (주간 리포트):
- Traffic 추이
- Latency 추이
```

### 3. SLO 연결
```yaml
# SLO: 99.9% 가용성
- alert: SLOViolation
  expr: |
    (1 - (
      sum(rate(http_requests_total{status=~"5.."}[30d])) /
      sum(rate(http_requests_total[30d]))
    )) < 0.999
  annotations:
    summary: "SLO 위반: 99.9% 가용성 미달"
```

---
title: 4 Golden Signals
aliases:
  - 07-4-Golden-Signals
category: K8s_Deep_Dive/프로메테우스/모니터링
status: 완성
priority: 높음

## 🔗 연관 개념
- [[03-관측성-3대-축]] - Metrics의 역할
- [[06-모니터링-트레이드오프]] - 무엇을 측정할 것인가
- [[05-Prometheus-실무-활용]] - 실제 구현

---
title: 4 Golden Signals
aliases:
  - 07-4-Golden-Signals
category: K8s_Deep_Dive/프로메테우스/모니터링
status: 완성
priority: 높음

## 📚 더 읽어보기
- [Google SRE Book - Monitoring Distributed Systems](https://sre.google/sre-book/monitoring-distributed-systems/)
- [The USE Method](http://www.brendangregg.com/usemethod.html)
- [The RED Method](https://www.weave.works/blog/the-red-method-key-metrics-for-microservices-architecture/)

---
title: 4 Golden Signals
aliases:
  - 07-4-Golden-Signals
category: K8s_Deep_Dive/프로메테우스/모니터링
status: 완성
priority: 높음

## 💼 체크리스트: 4 Golden Signals 구현

```
□ Latency 측정 중인가?
  → 응답 시간, P95/P99

□ Traffic 측정 중인가?
  → RPS, QPS

□ Errors 측정 중인가?
  → 5xx 에러율, 연결 실패

□ Saturation 측정 중인가?
  → CPU, 메모리, 커넥션 풀

□ 대시보드에 4가지 모두 표시되나?
  → Grafana 패널

□ Alert 설정했나?
  → 임계값 초과 시 알림
```

---
title: 4 Golden Signals
aliases:
  - 07-4-Golden-Signals
category: K8s_Deep_Dive/프로메테우스/모니터링
status: 완성
priority: 높음

## 🎯 핵심 메시지

> **"무엇을 모니터링할지 모르겠다면?"**
>
> → 4 Golden Signals부터 시작하라!
>
> 이것만 제대로 해도 대부분의 문제를 감지할 수 있습니다.
