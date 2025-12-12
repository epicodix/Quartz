---
title: 🔥 Prometheus 핵심 치트시트
tags:
  - Prometheus
  - CheatSheet
  - 치트시트
  - 빠른참조
aliases:
  - 프로메테우스치트시트
  - Prometheus빠른참조
date: 2025-12-12
category: K8s_Deep_Dive/프로메테우스
status: 완성
priority: 최우선
---

# 🔥 Prometheus 핵심 치트시트

> **빠르게 기억할 핵심만 모았습니다!**

---

## 📌 1. 핵심 개념 (30초 요약)

```yaml
Prometheus란?
  - Pull 기반 시계열 메트릭 DB
  - Kubernetes 공식 모니터링 도구
  - CNCF Graduated 프로젝트

핵심 특징:
  ✅ Pull 방식 (서버가 주기적으로 수집)
  ✅ Service Discovery (자동 타겟 발견)
  ✅ PromQL (강력한 쿼리 언어)
  ✅ 시계열 데이터 저장

데이터 흐름:
  Exporter(수집) → Prometheus(저장) → Grafana(시각화)
```

---

## 📊 2. 메트릭 타입 (4가지만 기억!)

### Counter - 계속 증가만
```yaml
특징:
  - 누적값 (재시작 시에만 0으로)
  - 절대 감소 안함
예시: http_requests_total, errors_total
필수 함수: rate(), increase()
```

**PromQL 예시:**
```promql
# ❌ 잘못 - 누적값은 의미없음
http_requests_total

# ✅ 올바름 - 초당 요청 수
rate(http_requests_total[5m])

# ✅ 올바름 - 5분간 총 증가량
increase(http_requests_total[5m])
```

---

### Gauge - 증가/감소 가능
```yaml
특징:
  - 현재 값
  - 증가/감소 모두 가능
예시: cpu_usage_percent, memory_bytes, temperature
사용: 직접 사용 가능 (함수 불필요)
```

**PromQL 예시:**
```promql
# ✅ 현재 CPU 사용률
node_cpu_usage_percent

# ✅ 평균 CPU
avg(node_cpu_usage_percent)

# ✅ 메모리 사용률 계산
(node_memory_used_bytes / node_memory_total_bytes) * 100
```

---

### Histogram - 값의 분포
```yaml
특징:
  - 버킷으로 분포 측정
  - 백분위수(P95, P99) 계산 가능
예시: http_request_duration_seconds_bucket
필수 함수: histogram_quantile()
```

**PromQL 예시:**
```promql
# P95 응답시간 (95%가 이 시간 이내)
histogram_quantile(0.95,
  rate(http_request_duration_seconds_bucket[5m])
)

# P99 응답시간
histogram_quantile(0.99,
  rate(http_request_duration_seconds_bucket[5m])
)
```

---

### Summary - 사전 계산된 백분위수
```yaml
특징:
  - 클라이언트에서 백분위수 미리 계산
  - Histogram보다 가벼움
예시: http_request_duration_seconds{quantile="0.95"}
사용: 직접 사용 (계산 이미 완료됨)
```

---

## 🎯 3. PromQL 핵심 패턴

### 기본 쿼리
```promql
# 메트릭 조회
metric_name

# 레이블 필터
metric_name{label="value"}

# 정규표현식
metric_name{label=~"value.*"}
metric_name{label!~"value.*"}
```

### 시간 범위
```promql
metric_name[5m]   # 최근 5분 (레인지 벡터)
metric_name[1h]   # 최근 1시간
metric_name[1d]   # 최근 1일

# 과거 시점
metric_name offset 1h   # 1시간 전
metric_name offset 1d   # 1일 전
```

### 필수 함수 TOP 10
```promql
# 1. rate() - Counter 전용, 초당 증가율
rate(http_requests_total[5m])

# 2. irate() - 순간 증가율 (더 민감)
irate(http_requests_total[5m])

# 3. increase() - 기간 동안 총 증가량
increase(http_requests_total[5m])

# 4. sum() - 합계
sum(metric_name)

# 5. avg() - 평균
avg(metric_name)

# 6. max() / min() - 최대/최소
max(metric_name)

# 7. count() - 개수
count(metric_name)

# 8. topk() - 상위 K개
topk(5, metric_name)

# 9. by - 그룹화
sum by (label) (metric_name)

# 10. without - 특정 레이블 제외
sum without (pod) (metric_name)
```

### 실전 쿼리 패턴
```promql
# CPU 사용률
100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# 메모리 사용률
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100

# 에러율
sum(rate(http_requests_total{status=~"5.."}[5m])) /
sum(rate(http_requests_total[5m])) * 100

# QPS (초당 쿼리)
sum(rate(http_requests_total[5m]))

# 현재 vs 1시간 전 비교
rate(metric[5m]) / rate(metric[5m] offset 1h)
```

---

## 🏗️ 4. Native vs Operator (핵심 차이)

### 비교표
```yaml
┌─────────────┬──────────────────┬────────────────────┐
│   항목      │   Native         │   Operator         │
├─────────────┼──────────────────┼────────────────────┤
│ 설정 방식   │ prometheus.yml   │ ServiceMonitor CRD │
│ 설정 복잡도 │ 높음 (regex)     │ 낮음 (선언적)       │
│ 변경 반영   │ 재시작 필요      │ 자동 (10-30초)      │
│ Pod 표시    │ Annotation       │ Label              │
│ 네임스페이스│ 어려움           │ 쉬움 (RBAC)         │
│ 협업        │ 운영팀 병목      │ 개발팀 셀프서비스   │
│ GitOps      │ 낮음             │ 높음               │
│ 추천        │ 간단한 환경      │ 프로덕션, 멀티팀    │
└─────────────┴──────────────────┴────────────────────┘
```

### Native 방식
```yaml
# Pod Annotation 필수
annotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "9104"
  prometheus.io/path: "/metrics"

# prometheus.yml에 복잡한 relabel_configs 작성
relabel_configs:
- source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
  action: keep
  regex: true
```

### Operator 방식
```yaml
# ServiceMonitor CRD만 생성
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: mysql-exporter
spec:
  selector:
    matchLabels:
      app: mysql-exporter
  endpoints:
  - port: metrics
    interval: 30s
```

---

## 🎯 5. ServiceMonitor 핵심 필드

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: my-service-monitor
  namespace: my-namespace
spec:
  # 1. Service 선택 (필수!)
  selector:
    matchLabels:
      app: my-app

  # 2. 수집 설정
  endpoints:
  - port: metrics          # Service의 포트 이름
    path: /metrics         # 기본값: /metrics
    interval: 30s          # 수집 주기
    scrapeTimeout: 10s     # 타임아웃
    scheme: http           # http 또는 https

  # 3. 네임스페이스 선택 (선택사항)
  namespaceSelector:
    matchNames:
    - my-namespace
    # 또는 모든 네임스페이스
    # any: true
```

### PodMonitor (Service 없이 Pod 직접 수집)
```yaml
apiVersion: monitoring.coreos.com/v1
kind: PodMonitor
metadata:
  name: my-pod-monitor
spec:
  selector:
    matchLabels:
      app: my-app
  podMetricsEndpoints:
  - port: http
    path: /metrics
```

**언제 뭘 쓸까?**
```yaml
ServiceMonitor:
  - Deployment (일반 앱)
  - Service 있는 경우
  - 권장! (프로덕션 표준)

PodMonitor:
  - DaemonSet (node-exporter)
  - StatefulSet (개별 Pod 추적)
  - Service 없는 경우
```

---

## 🏆 6. 4 Golden Signals (꼭 모니터링!)

```yaml
1. Latency (지연시간):
   측정: histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))
   목표: P95 < 500ms

2. Traffic (트래픽):
   측정: rate(http_requests_total[5m])
   목표: RPS 추세 파악

3. Errors (에러율):
   측정: sum(rate(http_requests_total{status=~"5.."}[5m])) /
         sum(rate(http_requests_total[5m])) * 100
   목표: < 1%

4. Saturation (포화도):
   측정: CPU, 메모리, 디스크 사용률
   목표: < 80%
```

### Alert 우선순위
```yaml
Critical (즉시 대응):
  - Errors > 5%
  - Saturation > 90%

Warning (근무시간):
  - Latency P95 > 1초
  - Saturation > 80%

Info (주간 리포트):
  - Traffic 추이
```

---

## 🛠️ 7. 자주 쓰는 kubectl 명령어

### CRD 확인
```bash
# ServiceMonitor 목록
kubectl get servicemonitor -n monitoring

# PodMonitor 목록
kubectl get podmonitor -n monitoring

# PrometheusRule (Alert) 목록
kubectl get prometheusrule -n monitoring

# 상세 정보
kubectl describe servicemonitor mysql-exporter -n monitoring
```

### Prometheus 설정 확인
```bash
# Prometheus ConfigMap 확인
kubectl get configmap prometheus-config -n monitoring -o yaml

# Prometheus Pod 로그
kubectl logs prometheus-xxx -n monitoring

# Prometheus Reload (설정 재적용)
curl -X POST http://prometheus:9090/-/reload
```

### Target 확인
```bash
# Prometheus UI에서 확인
http://prometheus:9090/targets

# 또는 API
curl http://prometheus:9090/api/v1/targets
```

---

## 🔧 8. 트러블슈팅 체크리스트

### "메트릭이 안 보여요!"

```yaml
1단계 - Exporter 확인:
  □ Pod 정상 실행 중?
    kubectl get pods -n <namespace>

  □ /metrics 엔드포인트 응답?
    kubectl port-forward pod/<exporter-pod> 9104:9104
    curl localhost:9104/metrics

2단계 - Service 확인 (ServiceMonitor 사용 시):
  □ Service 존재?
    kubectl get svc -n <namespace>

  □ Service Label과 ServiceMonitor selector 일치?
    kubectl get svc <service-name> -o yaml
    kubectl get servicemonitor <sm-name> -o yaml

  □ Service의 port name과 endpoints의 port 일치?

3단계 - ServiceMonitor 확인:
  □ ServiceMonitor 생성됨?
    kubectl get servicemonitor -n <namespace>

  □ Namespace Label 있음?
    kubectl get namespace <namespace> --show-labels

4단계 - Prometheus 확인:
  □ Target에 표시됨?
    http://prometheus:9090/targets

  □ Prometheus Operator 로그
    kubectl logs -n monitoring <prometheus-operator-pod>
```

---

## 📖 9. 핵심 메트릭 예시

### 쿠버네티스 리소스
```promql
# Pod CPU 사용률
sum(rate(container_cpu_usage_seconds_total{pod="my-pod"}[5m])) * 100

# Pod 메모리 사용률
container_memory_usage_bytes{pod="my-pod"} /
container_spec_memory_limit_bytes{pod="my-pod"} * 100

# Pod 재시작 횟수
kube_pod_container_status_restarts_total

# Deployment replicas
kube_deployment_status_replicas_available
```

### MySQL
```promql
# 연결 수
mysql_global_status_threads_connected

# 슬로우 쿼리
rate(mysql_global_status_slow_queries[5m])

# QPS
rate(mysql_global_status_queries[5m])

# 커넥션 사용률
mysql_global_status_threads_connected /
mysql_global_variables_max_connections * 100
```

### Redis
```promql
# 메모리 사용률
redis_memory_used_bytes / redis_memory_max_bytes * 100

# 초당 명령 수
rate(redis_commands_processed_total[1m])

# 연결된 클라이언트
redis_connected_clients

# Hit Rate
rate(redis_keyspace_hits_total[5m]) /
(rate(redis_keyspace_hits_total[5m]) + rate(redis_keyspace_misses_total[5m])) * 100
```

---

## ⚡ 10. 빠른 참조 - 시간 단위

```promql
[30s]   # 30초
[5m]    # 5분  (가장 많이 사용)
[1h]    # 1시간
[1d]    # 1일
[1w]    # 1주
[1y]    # 1년

offset 1h    # 1시간 전
offset 1d    # 1일 전
offset 1w    # 1주일 전
```

---

## 💡 11. 꿀팁

### 메모리 효율적인 쿼리
```promql
# ❌ 비효율 - 모든 시계열 로드
sum(metric_name)

# ✅ 효율 - 필요한 것만 먼저 필터
sum(metric_name{job="api"})
```

### 레이블 매칭
```promql
# 정확히 일치
{label="value"}

# 정규표현식 (느림!)
{label=~"value.*"}

# NOT 매칭
{label!="value"}
{label!~"value.*"}

# 여러 조건 AND
{label1="value1", label2="value2"}
```

### Recording Rules (자주 쓰는 쿼리 미리 계산)
```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: recording-rules
spec:
  groups:
  - name: api_metrics
    interval: 30s
    rules:
    - record: api:request_rate:5m
      expr: sum(rate(http_requests_total{job="api"}[5m]))
```

---

## 🎯 마지막 체크리스트

```yaml
□ 메트릭 타입 4가지 구분 가능?
  Counter, Gauge, Histogram, Summary

□ PromQL 기본 함수 사용 가능?
  rate(), sum(), avg(), by

□ Native vs Operator 차이 이해?
  Annotation vs ServiceMonitor

□ 4 Golden Signals 알고 있음?
  Latency, Traffic, Errors, Saturation

□ ServiceMonitor 작성 가능?
  selector + endpoints

□ 트러블슈팅 순서 숙지?
  Exporter → Service → ServiceMonitor → Prometheus
```

---

## 📚 더 알아보기

상세 문서:
- [[01_프로메테우스_기초_개념_완벽_정리|기초 개념]]
- [[07_PromQL_메트릭_타입_완벽_가이드|메트릭 타입 상세]]
- [[09_PromQL_핵심_개념_정리|PromQL 상세]]
- [[12_Prometheus_Native_vs_Operator_완벽_비교|Native vs Operator]]
- [[13_ServiceMonitor_PodMonitor_CRD_완벽_가이드|ServiceMonitor 상세]]
- [[모니터링/07-4-Golden-Signals|4 Golden Signals]]

---

**📅 최종 업데이트**: 2025-12-12
**🎯 용도**: 빠른 참조용 치트시트
**⏱️ 읽는 시간**: 5분

> 💡 **Tip**: 이 문서를 북마크하고 실무에서 자주 확인하세요!
