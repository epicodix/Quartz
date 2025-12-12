---
title: 07_ PromQL과 Prometheus 메트릭 타입 완벽 가이드
tags:
  - PromQL
  - Prometheus
  - 메트릭
  - Counter
  - Gauge
  - Histogram
  - Summary
aliases:
  - PromQL가이드
  - 메트릭타입
  - Prometheus쿼리
date: 2025-12-04
category: K8s_Deep_Dive/프로메테우스
status: 완성
priority: 높음
---


# 📊 PromQL과 Prometheus 메트릭 타입 완벽 가이드

> [!note] 학습 목표
> Prometheus의 4가지 메트릭 타입(Counter, Gauge, Histogram, Summary)을 완벽히 이해하고, PromQL 쿼리 언어를 마스터합니다.

> [!tip] 학습 순서
> 1. 메트릭 타입 이해 (Counter → Gauge → Histogram → Summary)
> 2. PromQL 기초 문법
> 3. 주요 함수 활용
> 4. 실전 예시 적용

## 목차
- [Prometheus 메트릭 타입 개요](#prometheus-메트릭-타입-개요)
- [1. Counter (카운터)](#1-counter-카운터)
- [2. Gauge (게이지)](#2-gauge-게이지)
- [3. Histogram (히스토그램)](#3-histogram-히스토그램)
- [4. Summary (요약)](#4-summary-요약)
- [PromQL 기초](#promql-기초)
- [PromQL 연산자](#promql-연산자)
- [PromQL 함수](#promql-함수)
- [PromQL 고급 기법](#promql-고급-기법)
- [실전 예시](#실전-예시)

---

## Prometheus 메트릭 타입 개요

Prometheus는 4가지 핵심 메트릭 타입을 제공합니다. 각 타입은 특정 유형의 데이터를 표현하는 데 최적화되어 있습니다.

| 타입 | 값의 특성 | 대표 예시 | 주요 PromQL 함수 |
|------|----------|----------|-----------------|
| **Counter** | 누적, 단조 증가 | HTTP 요청 수, 에러 발생 횟수 | `rate()`, `increase()` |
| **Gauge** | 증가/감소 가능 | CPU 사용률, 메모리 사용량 | 직접 사용, `avg()`, `max()` |
| **Histogram** | 값의 분포 측정 | 응답 시간, 요청 크기 | `histogram_quantile()` |
| **Summary** | 값의 분포 + 사전 계산된 백분위수 | 응답 시간, 지연 시간 | 직접 사용 |

---

## 1. Counter (카운터)

### 개념

**Counter**는 **오직 증가만 하는** 누적 메트릭입니다. 재시작 시에만 0으로 리셋됩니다.

```
시간:  0s    10s   20s   30s   [재시작]  40s   50s
값:    0  →  5  →  12  →  20  →    0   →  3  →  8
```

### 특징

✅ **단조 증가**: 절대로 감소하지 않음 (재시작 제외)
✅ **누적값**: 시스템 시작 이후의 총합
✅ **비율 계산에 적합**: `rate()`, `increase()` 함수 사용

### 메트릭 명명 규칙

Counter는 반드시 `_total` 접미사를 붙입니다.

```
✅ http_requests_total
✅ errors_total
✅ bytes_sent_total

❌ http_requests (잘못됨)
❌ error_count (잘못됨)
```

### 실제 데이터 예시

```promql
# 메트릭: http_requests_total
http_requests_total{method="GET", path="/api", status="200"} 1234
http_requests_total{method="POST", path="/api", status="201"} 567
http_requests_total{method="GET", path="/api", status="500"} 42
```

**의미**: 프로세스가 시작된 이후 총 1234개의 GET 200 응답이 있었음

### PromQL 쿼리 방법

#### ❌ 잘못된 사용법: Counter를 직접 사용

```promql
# 나쁜 예: 누적값은 의미가 없음
http_requests_total
# 결과: 1234 (그래서 뭐...?)
```

#### ✅ 올바른 사용법 1: `rate()` - 초당 증가율

```promql
# 최근 5분간 초당 평균 요청 수
rate(http_requests_total[5m])
# 결과: 12.5 req/s
```

**해석**: 지난 5분 동안 평균적으로 초당 12.5개의 요청이 있었음

#### ✅ 올바른 사용법 2: `increase()` - 기간 동안 증가량

```promql
# 최근 5분간 총 요청 수
increase(http_requests_total[5m])
# 결과: 3750
```

**해석**: 지난 5분 동안 총 3,750개의 요청이 있었음

**관계**: `increase(x[5m]) ≈ rate(x[5m]) * 300`

#### ✅ 올바른 사용법 3: `irate()` - 순간 증가율

```promql
# 최근 2개 샘플 기준 순간 증가율 (더 민감함)
irate(http_requests_total[5m])
# 결과: 15.2 req/s (갑자기 증가한 순간 포착)
```

### 실전 활용 예시

#### 1. HTTP 요청 성공률 계산

```promql
# 전체 요청 중 2xx 응답 비율
sum(rate(http_requests_total{status=~"2.."}[5m])) /
sum(rate(http_requests_total[5m])) * 100

# 결과: 99.2 (%)
```

#### 2. 에러율 모니터링

```promql
# 초당 에러 발생 수
rate(errors_total[5m])

# 에러 증가 추세 감지 (지난 5분 vs 1시간 전)
rate(errors_total[5m]) > rate(errors_total[5m] offset 1h) * 2
```

#### 3. 네트워크 대역폭 계산

```promql
# 초당 전송 바이트 (MB/s로 변환)
rate(network_bytes_sent_total[1m]) / 1024 / 1024

# 결과: 125.5 (MB/s)
```

### 주의사항

⚠️ **Counter Resets**: 프로세스 재시작 시 Counter가 0으로 리셋되는데, `rate()`와 `increase()`는 이를 자동으로 처리합니다.

```
시간:  0분   1분   2분   [재시작]  3분   4분
값:    100   150   200      10      60

rate() 결과: 50/min → 50/min → [자동 보정] → 50/min
```

⚠️ **시간 범위 선택**: `rate()`의 시간 범위는 최소 4배의 스크래핑 간격 이상으로 설정
- 스크래핑 간격 30초 → `[2m]` 이상 사용
- 스크래핑 간격 15초 → `[1m]` 이상 사용

---

## 2. Gauge (게이지)

### 개념

**Gauge**는 **증가와 감소가 모두 가능한** 현재 값을 나타내는 메트릭입니다.

```
시간:  0s    10s   20s   30s   40s   50s
값:    50 →  65 →  45 →  70 →  30 →  55
       ↑     ↑     ↓     ↑     ↓     ↑
```

### 특징

✅ **양방향 변화**: 증가와 감소 모두 가능
✅ **현재 상태**: 순간적인 값 측정
✅ **직접 사용 가능**: 특별한 함수 없이 바로 의미 있음

### 실제 데이터 예시

```promql
# CPU 사용률 (%)
node_cpu_usage_percent{cpu="0"} 45.2
node_cpu_usage_percent{cpu="1"} 62.8

# 메모리 사용량 (bytes)
node_memory_usage_bytes 4294967296

# 온도 (섭씨)
hardware_temperature_celsius{sensor="cpu"} 67.5

# 동시 접속자 수
active_connections 1523
```

### PromQL 쿼리 방법

#### ✅ 직접 사용

```promql
# 현재 CPU 사용률
node_cpu_usage_percent

# 결과: 45.2 (%)
```

#### ✅ 집계 함수 사용

```promql
# 평균 CPU 사용률 (모든 코어)
avg(node_cpu_usage_percent)

# 최대 CPU 사용률
max(node_cpu_usage_percent)

# CPU 사용률이 80% 이상인 코어 개수
count(node_cpu_usage_percent > 80)
```

#### ✅ 변화율 계산 (Gauge에도 rate() 사용 가능)

```promql
# 메모리 사용량의 증가율 (초당 bytes)
rate(node_memory_usage_bytes[5m])

# 양수면 메모리 사용 증가 중, 음수면 감소 중
```

### 실전 활용 예시

#### 1. 리소스 사용률 모니터링

```promql
# 메모리 사용률 (%)
(node_memory_usage_bytes / node_memory_total_bytes) * 100

# 결과: 75.2 (%)
```

#### 2. 큐 크기 모니터링

```promql
# 메시지 큐에 쌓인 메시지 수
queue_size

# 큐가 비워지는 속도 (음수면 쌓이는 중)
rate(queue_size[5m])
```

#### 3. 동시 연결 수 추세

```promql
# 현재 동시 연결 수
active_connections

# 10분 전과 비교
active_connections - (active_connections offset 10m)

# 결과: +250 (250명 증가)
```

#### 4. 온도 임계값 알림

```promql
# 80도 이상인 센서
hardware_temperature_celsius > 80

# 최근 5분간 평균 온도
avg_over_time(hardware_temperature_celsius[5m])
```

### 주의사항

⚠️ **Gauge에 rate() 사용 시 주의**: Gauge는 증가와 감소가 모두 있으므로 rate()의 의미를 정확히 이해해야 합니다.

```promql
# 메모리 사용량에 rate() 적용
rate(node_memory_usage_bytes[5m])

# 결과: 1048576 (bytes/s) → 초당 1MB씩 증가 중
# 결과: -524288 (bytes/s) → 초당 0.5MB씩 감소 중
```

⚠️ **스냅샷 vs 추세**: Gauge는 현재 값이지만, 알림은 추세 기반으로 설정하는 것이 좋습니다.

```promql
# 나쁜 예: 순간적인 스파이크에 반응
cpu_usage > 90

# 좋은 예: 5분 동안 지속될 때만 알림
avg_over_time(cpu_usage[5m]) > 90
```

---

## 3. Histogram (히스토그램)

### 개념

**Histogram**은 관측값의 **분포**를 측정합니다. 값을 여러 버킷(구간)으로 나누어 각 구간에 속한 관측 횟수를 기록합니다.

```
HTTP 응답 시간 분포:
0-0.1s:  ████████████████████ (1000개)
0.1-0.5s: ███████████ (550개)
0.5-1s:   ████ (200개)
1-5s:     ██ (100개)
5-∞s:     █ (50개)
```

### 구조

Histogram은 **3개의 시계열**을 자동 생성합니다:

```promql
# 1. 버킷별 누적 카운트 (le = less than or equal)
http_request_duration_seconds_bucket{le="0.1"} 1000
http_request_duration_seconds_bucket{le="0.5"} 1550  # 누적!
http_request_duration_seconds_bucket{le="1.0"} 1750  # 누적!
http_request_duration_seconds_bucket{le="5.0"} 1850  # 누적!
http_request_duration_seconds_bucket{le="+Inf"} 1900 # 전체

# 2. 총 관측 횟수
http_request_duration_seconds_count 1900

# 3. 총 관측값의 합
http_request_duration_seconds_sum 1234.56
```

**핵심**: 버킷은 **누적(cumulative)**입니다!
- `le="0.5"`는 "0.5초 **이하**"가 1550개 (0.1초 이하 포함)
- `le="+Inf"`는 모든 요청 (전체)

### 버킷 설정 예시

```go
// Go 코드에서 Histogram 정의
requestDuration := prometheus.NewHistogram(
    prometheus.HistogramOpts{
        Name: "http_request_duration_seconds",
        Help: "HTTP request duration in seconds",
        Buckets: []float64{0.1, 0.5, 1, 2, 5, 10}, // 버킷 경계
    },
)
```

### PromQL 쿼리 방법

#### ✅ 백분위수(Percentile) 계산

```promql
# 95번째 백분위수 (P95) - 95%의 요청이 이 시간 이하
histogram_quantile(0.95,
  rate(http_request_duration_seconds_bucket[5m])
)

# 결과: 0.87 (초)
# 의미: 95%의 요청이 0.87초 이내에 완료됨
```

**주요 백분위수**:
- `0.50` (P50, 중앙값/Median): 50%의 요청
- `0.90` (P90): 90%의 요청
- `0.95` (P95): 95%의 요청
- `0.99` (P99): 99%의 요청 (롱테일 감지)

#### ✅ 평균 계산

```promql
# 평균 응답 시간
rate(http_request_duration_seconds_sum[5m]) /
rate(http_request_duration_seconds_count[5m])

# 결과: 0.65 (초)
```

#### ✅ 초당 요청 수 (QPS)

```promql
# Histogram의 _count로 요청 수 계산 가능
rate(http_request_duration_seconds_count[5m])

# 결과: 125.5 (req/s)
```

#### ✅ 특정 구간 비율 계산

```promql
# 1초 이상 걸린 요청 비율
(
  rate(http_request_duration_seconds_bucket{le="+Inf"}[5m]) -
  rate(http_request_duration_seconds_bucket{le="1"}[5m])
) /
rate(http_request_duration_seconds_bucket{le="+Inf"}[5m]) * 100

# 결과: 8.5 (%)
```

### 실전 활용 예시

#### 1. SLO 모니터링 (Service Level Objective)

```promql
# SLO: 95%의 요청이 500ms 이내 완료
histogram_quantile(0.95,
  rate(http_request_duration_seconds_bucket[5m])
) < 0.5

# true면 SLO 달성, false면 위반
```

#### 2. Latency 분석

```promql
# P50, P90, P99를 한 번에 보기
histogram_quantile(0.50, rate(http_request_duration_seconds_bucket[5m]))  # Median
histogram_quantile(0.90, rate(http_request_duration_seconds_bucket[5m]))
histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[5m]))  # Tail latency

# 결과 예시:
# P50: 0.2s  (대부분 빠름)
# P90: 0.6s  (여전히 괜찮음)
# P99: 3.5s  (일부 매우 느림 → 최적화 필요!)
```

#### 3. 엔드포인트별 성능 비교

```promql
# 엔드포인트별 P95 응답 시간
histogram_quantile(0.95,
  sum by (path, le) (
    rate(http_request_duration_seconds_bucket[5m])
  )
)

# 결과:
# /api/users: 0.3s
# /api/orders: 1.2s  ← 이 엔드포인트가 느림!
# /api/products: 0.5s
```

### Histogram vs Summary

| 특성 | Histogram | Summary |
|------|-----------|---------|
| **백분위수 계산** | 서버(Prometheus)에서 | 클라이언트(앱)에서 |
| **집계 가능** | ✅ 가능 (`sum`, `avg`) | ❌ 불가능 |
| **정확도** | 근사값 (버킷 기반) | 정확 (스트리밍 계산) |
| **유연성** | 쿼리 시 백분위수 변경 가능 | 미리 정의된 백분위수만 |
| **리소스** | 서버 부하 높음 | 클라이언트 부하 높음 |
| **권장** | ✅ 대부분의 경우 권장 | 특수한 경우만 |

### 주의사항

⚠️ **버킷 설계의 중요성**: 버킷 범위를 잘못 설정하면 유용한 정보를 얻을 수 없습니다.

```go
// 나쁜 예: 버킷이 너무 넓음
Buckets: []float64{1, 10, 100}
// → 대부분의 요청이 0.1-1초 사이인데 세밀하게 볼 수 없음

// 좋은 예: 예상 범위에 맞춰 세밀하게
Buckets: []float64{0.01, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10}
```

⚠️ **histogram_quantile의 한계**: 버킷 기반 추정이므로 100% 정확하지 않습니다.

```
실제 P95: 0.87초
추정 P95: 0.85~0.90초 (버킷 간격에 따라)
```

⚠️ **반드시 rate() 사용**: Histogram bucket은 Counter이므로 반드시 `rate()`와 함께 사용

```promql
# ❌ 잘못됨
histogram_quantile(0.95, http_request_duration_seconds_bucket)

# ✅ 올바름
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))
```

---

## 4. Summary (요약)

### 개념

**Summary**는 Histogram과 유사하지만, 백분위수를 **클라이언트(애플리케이션)에서 미리 계산**합니다.

### 구조

Summary는 **2개의 시계열 + N개의 백분위수**를 생성합니다:

```promql
# 미리 계산된 백분위수
http_request_duration_seconds{quantile="0.5"} 0.23   # P50 (median)
http_request_duration_seconds{quantile="0.9"} 0.67   # P90
http_request_duration_seconds{quantile="0.99"} 2.13  # P99

# 총 관측 횟수
http_request_duration_seconds_count 1900

# 총 관측값의 합
http_request_duration_seconds_sum 1234.56
```

### Histogram과의 차이

```
┌─────────────────────────────────────────────┐
│              Histogram                      │
│  앱 → 버킷 카운트 → Prometheus → 백분위수 계산 │
│  (유연함, 서버 부하)                         │
└─────────────────────────────────────────────┘

┌─────────────────────────────────────────────┐
│              Summary                         │
│  앱 → 백분위수 계산 → Prometheus → 조회만    │
│  (정확함, 클라이언트 부하)                   │
└─────────────────────────────────────────────┘
```

### PromQL 쿼리 방법

#### ✅ 백분위수 직접 조회

```promql
# P95 응답 시간 (이미 계산되어 있음)
http_request_duration_seconds{quantile="0.95"}

# 결과: 0.87 (초)
```

#### ✅ 평균 계산

```promql
# 평균 응답 시간
rate(http_request_duration_seconds_sum[5m]) /
rate(http_request_duration_seconds_count[5m])
```

#### ❌ 집계 불가능

```promql
# ❌ 불가능: Summary는 인스턴스별로만 의미 있음
sum(http_request_duration_seconds{quantile="0.95"})
# 결과: 의미 없는 값 (여러 인스턴스의 P95를 더하는 것은 통계적으로 무의미)

# ✅ Histogram이었다면 가능
histogram_quantile(0.95,
  sum(rate(http_request_duration_seconds_bucket[5m])) by (le)
)
```

### 사용 사례

Summary는 다음 경우에만 사용:
1. **단일 인스턴스 모니터링**: 스케일아웃이 없는 경우
2. **매우 정확한 백분위수 필요**: 금융, 의료 등
3. **Prometheus 서버 리소스 제한**: 계산을 클라이언트로 오프로드

**대부분의 경우 Histogram 권장!**

---

## PromQL 기초

### 시계열 선택

#### Instant Vector (순간 벡터)

현재 시점의 값

```promql
# 기본 선택
http_requests_total

# Label 매칭
http_requests_total{method="GET"}
http_requests_total{method="GET", status="200"}

# Label 정규식
http_requests_total{status=~"2.."}  # 2xx
http_requests_total{path!="/health"}  # /health 제외
```

#### Range Vector (범위 벡터)

시간 범위의 값들

```promql
# 최근 5분간의 모든 데이터 포인트
http_requests_total[5m]

# 시간 단위
[30s]  # 30초
[5m]   # 5분
[1h]   # 1시간
[1d]   # 1일
```

#### Offset (시간 이동)

```promql
# 1시간 전 값
http_requests_total offset 1h

# 1시간 전 5분 범위
http_requests_total[5m] offset 1h

# 어제 같은 시간과 비교
http_requests_total - (http_requests_total offset 24h)
```

---

## PromQL 연산자

### 산술 연산자

```promql
# 더하기, 빼기, 곱하기, 나누기, 나머지, 거듭제곱
node_memory_total_bytes - node_memory_free_bytes  # 사용 중인 메모리
cpu_usage * 100  # 백분율 변환
rate(http_requests_total[5m]) ^ 2  # 제곱
```

### 비교 연산자

```promql
# ==, !=, >, <, >=, <=
cpu_usage > 80  # 80% 초과
http_requests_total{status=~"5.."} > 0  # 5xx 에러 발생 중

# bool 수정자: 결과를 1 또는 0으로 반환
cpu_usage > 80 bool
# 결과: 1 (true) 또는 0 (false)
```

### 논리 연산자

```promql
# and, or, unless
(cpu_usage > 80) and (memory_usage > 80)  # 둘 다 참
(cpu_usage > 80) or (memory_usage > 80)   # 하나라도 참
http_requests_total unless http_requests_total{status="200"}  # 200 제외
```

---

## PromQL 함수

### 시간 관련 함수

#### `rate()` - 초당 평균 증가율

```promql
rate(http_requests_total[5m])
# 최근 5분간의 초당 평균 요청 수
```

#### `irate()` - 순간 증가율

```promql
irate(http_requests_total[5m])
# 마지막 2개 데이터 포인트 기반 (더 민감)
```

#### `increase()` - 기간 동안 증가량

```promql
increase(http_requests_total[1h])
# 지난 1시간 동안의 총 요청 수
```

#### `delta()` - Gauge의 변화량

```promql
delta(cpu_usage[5m])
# 5분 동안의 CPU 사용률 변화
# 결과: +15 (15% 증가) 또는 -10 (10% 감소)
```

#### `idelta()` - 순간 변화량

```promql
idelta(cpu_usage[5m])
# 마지막 2개 포인트의 차이
```

---

### 집계 함수

#### `sum()` - 합계

```promql
# 모든 인스턴스의 총 요청 수
sum(rate(http_requests_total[5m]))

# 메서드별로 그룹화
sum by (method) (rate(http_requests_total[5m]))

# 메서드를 제외하고 그룹화
sum without (method) (rate(http_requests_total[5m]))
```

#### `avg()` - 평균

```promql
# 평균 CPU 사용률
avg(cpu_usage)

# 노드별 평균
avg by (node) (cpu_usage)
```

#### `max()` / `min()` - 최대/최소

```promql
# 가장 높은 CPU 사용률
max(cpu_usage)

# 가장 느린 인스턴스의 응답 시간
max by (instance) (
  histogram_quantile(0.95,
    rate(http_request_duration_seconds_bucket[5m])
  )
)
```

#### `count()` - 개수

```promql
# 에러가 발생한 인스턴스 개수
count(rate(errors_total[5m]) > 0)

# 활성 서버 개수
count(up == 1)
```

#### `topk()` / `bottomk()` - 상위/하위 K개

```promql
# CPU 사용률 상위 3개
topk(3, cpu_usage)

# 요청이 가장 적은 5개 엔드포인트
bottomk(5, sum by (path) (rate(http_requests_total[5m])))
```

#### `quantile()` - 백분위수

```promql
# 모든 인스턴스의 CPU 사용률 중 90번째 백분위수
quantile(0.90, cpu_usage)

# 결과: 75.5 (90%의 인스턴스가 75.5% 이하)
```

---

### 시간 범위 함수

#### `avg_over_time()` - 기간 평균

```promql
# 최근 5분간 평균 CPU 사용률
avg_over_time(cpu_usage[5m])
```

#### `max_over_time()` / `min_over_time()`

```promql
# 최근 1시간 최대 메모리 사용량
max_over_time(memory_usage[1h])

# 최근 1일 최소 디스크 공간
min_over_time(disk_free_bytes[1d])
```

#### `sum_over_time()` - 기간 합계

```promql
# 최근 1시간 데이터 포인트 합계
sum_over_time(metric[1h])
```

#### `count_over_time()` - 데이터 포인트 개수

```promql
# 최근 5분간 수집된 샘플 개수
count_over_time(http_requests_total[5m])
```

---

### 예측 함수

#### `predict_linear()` - 선형 예측

```promql
# 4시간 후 디스크 사용량 예측
predict_linear(disk_usage_bytes[1h], 4*3600)

# 결과: 85899345920 (80GB)
```

#### `deriv()` - 도함수 (변화율)

```promql
# 메모리 증가 속도 (초당 bytes)
deriv(memory_usage_bytes[5m])
```

---

### 기타 유용한 함수

#### `absent()` - 메트릭 부재 감지

```promql
# 메트릭이 없으면 1 반환
absent(up{job="api-server"})

# 알림 규칙에 유용
ALERT ServiceDown
IF absent(up{job="api-server"}) == 1
```

#### `changes()` - 값 변경 횟수

```promql
# 최근 5분간 값이 변경된 횟수
changes(cpu_usage[5m])
```

#### `resets()` - Counter 리셋 횟수

```promql
# 최근 1시간 재시작 횟수 추정
resets(http_requests_total[1h])
```

#### `clamp_max()` / `clamp_min()` - 값 제한

```promql
# 100을 초과하지 않도록
clamp_max(cpu_usage, 100)

# 0 미만이 되지 않도록
clamp_min(disk_free_bytes, 0)
```

#### `round()` - 반올림

```promql
# 소수점 첫째 자리로 반올림
round(cpu_usage, 0.1)
# 45.2345 → 45.2
```

---

## PromQL 고급 기법

### 벡터 매칭

#### One-to-One 매칭

```promql
# CPU 사용률 - Idle 비율
node_cpu_seconds_total{mode="user"} - node_cpu_seconds_total{mode="idle"}

# Label이 정확히 일치하는 시계열끼리 연산
```

#### Many-to-One / One-to-Many 매칭

```promql
# 인스턴스별 요청 수 / 전체 요청 수 (비율)
sum without (instance) (rate(http_requests_total[5m])) /
ignoring (instance) group_left
sum(rate(http_requests_total[5m]))

# group_left: 왼쪽 (many)의 label 유지
# group_right: 오른쪽 (many)의 label 유지
```

### Subquery (서브쿼리)

```promql
# 최근 1시간 동안 5분 단위로 계산한 P95의 최대값
max_over_time(
  histogram_quantile(0.95,
    rate(http_request_duration_seconds_bucket[5m])
  )[1h:5m]
)

# [1h:5m] = 1시간 범위를 5분 간격으로 평가
```

### Label 조작

#### `label_replace()` - Label 변경

```promql
# path label에서 숫자 제거
label_replace(
  http_requests_total,
  "path_clean",
  "/api/user",
  "path",
  "/api/user/[0-9]+"
)
```

#### `label_join()` - Label 결합

```promql
# host와 port를 결합
label_join(
  http_requests_total,
  "host_port",
  ":",
  "host",
  "port"
)
# 결과: host_port="localhost:8080"
```

---

## 실전 예시

### 1. Golden Signals 모니터링

#### Latency (지연 시간)

```promql
# P95 응답 시간
histogram_quantile(0.95,
  sum by (le) (rate(http_request_duration_seconds_bucket[5m]))
)
```

#### Traffic (트래픽)

```promql
# 초당 요청 수 (QPS)
sum(rate(http_requests_total[5m]))
```

#### Errors (에러율)

```promql
# 에러율 (%)
sum(rate(http_requests_total{status=~"5.."}[5m])) /
sum(rate(http_requests_total[5m])) * 100
```

#### Saturation (포화도)

```promql
# CPU 포화도
avg(rate(node_cpu_seconds_total{mode!="idle"}[5m])) * 100

# 메모리 포화도
(1 - node_memory_available_bytes / node_memory_total_bytes) * 100
```

---

### 2. RED Method (Rate, Errors, Duration)

```promql
# Rate: 초당 요청 수
sum(rate(http_requests_total[5m])) by (service)

# Errors: 에러율
sum(rate(http_requests_total{status=~"5.."}[5m])) by (service) /
sum(rate(http_requests_total[5m])) by (service)

# Duration: P99 응답 시간
histogram_quantile(0.99,
  sum by (service, le) (rate(http_request_duration_seconds_bucket[5m]))
)
```

---

### 3. USE Method (Utilization, Saturation, Errors)

```promql
# Utilization: CPU 사용률
100 - (avg by (instance) (
  rate(node_cpu_seconds_total{mode="idle"}[5m])
) * 100)

# Saturation: CPU Load Average
node_load1 / count without (cpu) (node_cpu_seconds_total{mode="idle"})

# Errors: 디스크 I/O 에러
rate(node_disk_io_errors_total[5m])
```

---

### 4. 복잡한 비즈니스 메트릭

#### 결제 성공률

```promql
# 전체 결제 중 성공 비율
sum(rate(payment_transactions_total{status="success"}[5m])) /
sum(rate(payment_transactions_total[5m])) * 100
```

#### 사용자당 평균 요청 수

```promql
# 총 요청 수 / 활성 사용자 수
sum(rate(http_requests_total[5m])) /
sum(active_users)
```

#### 시간대별 트래픽 패턴

```promql
# 현재 시간 vs 1주일 전 같은 시간
sum(rate(http_requests_total[5m])) /
sum(rate(http_requests_total[5m] offset 1w))

# 1보다 크면 증가, 작으면 감소
```

#### 캐시 히트율

```promql
# 캐시 히트 / (히트 + 미스)
sum(rate(cache_hits_total[5m])) /
(sum(rate(cache_hits_total[5m])) + sum(rate(cache_misses_total[5m]))) * 100
```

---

### 5. 알림 규칙 예시

#### 높은 에러율

```yaml
- alert: HighErrorRate
  expr: |
    sum(rate(http_requests_total{status=~"5.."}[5m])) /
    sum(rate(http_requests_total[5m])) > 0.05
  for: 5m
  labels:
    severity: critical
  annotations:
    summary: "에러율 5% 초과"
    description: "현재 에러율: {{ $value | humanizePercentage }}"
```

#### 느린 응답 시간

```yaml
- alert: HighLatency
  expr: |
    histogram_quantile(0.95,
      sum by (service, le) (
        rate(http_request_duration_seconds_bucket[5m])
      )
    ) > 1
  for: 10m
  labels:
    severity: warning
  annotations:
    summary: "P95 응답 시간 1초 초과"
    description: "{{ $labels.service }}: {{ $value }}s"
```

#### 디스크 고갈 예측

```yaml
- alert: DiskWillFillIn4Hours
  expr: |
    predict_linear(node_filesystem_free_bytes[1h], 4*3600) < 0
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "4시간 후 디스크 고갈 예상"
```

---

## 성능 최적화 팁

### 1. 카디널리티 관리

```promql
# ❌ 나쁜 예: 높은 카디널리티
http_requests_total{user_id="12345", session_id="abc..."}
# user_id와 session_id는 무한히 증가 → 메모리 폭발

# ✅ 좋은 예: 낮은 카디널리티
http_requests_total{method="GET", status="200", endpoint="/api"}
# 제한된 값들만 사용
```

### 2. 쿼리 효율성

```promql
# ❌ 비효율적
sum(rate(http_requests_total[5m])) by (method) /
sum(rate(http_requests_total[5m]))

# ✅ 효율적 (한 번만 계산)
sum(rate(http_requests_total[5m])) by (method) /
ignoring(method) group_left
sum(rate(http_requests_total[5m]))
```

### 3. Recording Rules 활용

자주 사용하는 복잡한 쿼리는 미리 계산:

```yaml
groups:
  - name: http_metrics
    interval: 30s
    rules:
      - record: job:http_requests:rate5m
        expr: sum by (job) (rate(http_requests_total[5m]))

      - record: job:http_error_rate:rate5m
        expr: |
          sum by (job) (rate(http_requests_total{status=~"5.."}[5m])) /
          sum by (job) (rate(http_requests_total[5m]))
```

사용:
```promql
# 원래 쿼리 대신
job:http_requests:rate5m
job:http_error_rate:rate5m
```

---

## 자주 하는 실수

### 1. Counter에 직접 집계

```promql
# ❌ 잘못됨
sum(http_requests_total)
# 각 인스턴스의 누적값을 더함 → 의미 없음

# ✅ 올바름
sum(rate(http_requests_total[5m]))
```

### 2. Histogram에 rate() 없이 사용

```promql
# ❌ 잘못됨
histogram_quantile(0.95, http_request_duration_seconds_bucket)

# ✅ 올바름
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))
```

### 3. 시간 범위가 너무 짧음

```promql
# ❌ 나쁜 예: 스크래핑 간격 30초인데 [30s] 사용
rate(http_requests_total[30s])
# → 데이터 포인트 1-2개만 사용, 부정확

# ✅ 좋은 예: 최소 4배
rate(http_requests_total[2m])
```

### 4. Gauge에 increase() 사용

```promql
# ❌ 잘못됨
increase(memory_usage_bytes[5m])
# Gauge는 증가/감소하므로 의미 없음

# ✅ 올바름
memory_usage_bytes  # 직접 사용
delta(memory_usage_bytes[5m])  # 변화량
```

---

## 참고 자료

- [Prometheus 공식 문서](https://prometheus.io/docs/)
- [PromQL 치트시트](https://promlabs.com/promql-cheat-sheet/)
- [Robust Perception 블로그](https://www.robustperception.io/blog)
- [Grafana Dashboard 예시](https://grafana.com/grafana/dashboards/)

---

## 마치며

PromQL은 강력하지만 처음에는 어려울 수 있습니다. 핵심은:

1. **메트릭 타입 이해**: Counter는 rate(), Gauge는 직접, Histogram은 histogram_quantile()
2. **시간 범위 선택**: 충분히 긴 범위 사용 (최소 2-5분)
3. **단계적 구축**: 간단한 쿼리부터 시작해서 점진적으로 복잡하게
4. **실전 연습**: 실제 데이터로 다양한 쿼리 시도

**Happy Querying!** 🚀📊
