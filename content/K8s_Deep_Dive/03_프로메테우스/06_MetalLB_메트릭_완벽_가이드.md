---
title: 06_MetalLB 메트릭 완벽 가이드 - Prometheus 모니터링
tags:
  - MetalLB
  - Prometheus
  - 메트릭
  - 모니터링
  - Kubernetes
aliases:
  - MetalLB메트릭
  - MetalLB모니터링
  - LoadBalancer메트릭
date: 2025-12-04
category: K8s_Deep_Dive/프로메테우스
status: 완성
priority: 높음
---

# 🎯 MetalLB 메트릭 완벽 가이드

> [!note] 학습 목표
> MetalLB의 모든 메트릭을 이해하고, 실전에서 효과적으로 모니터링하는 방법을 마스터합니다.

## 📚 목차

- [[#개요]]
- [[#메트릭 수집 아키텍처]]
- [[#주요 메트릭 상세 설명]]
- [[#실전 활용 예시]]
- [[#알림 규칙 설정]]
- [[#트러블슈팅]]

---

## 개요

**MetalLB**는 Kubernetes 클러스터에 LoadBalancer 타입 서비스를 제공하는 네트워크 로드밸런서입니다. Prometheus 메트릭을 통해 IP 할당 상태, BGP 세션 상태, ARP 응답 등을 모니터링할 수 있습니다.

### MetalLB 구성 요소

```yaml
Controller:
  - IP 할당/해제 관리 (IPAM)
  - 메트릭 엔드포인트: :7472/metrics

Speaker:
  - 네트워크 발표 (Layer2 ARP 또는 BGP)
  - 메트릭 엔드포인트: :7472/metrics
```

---

## 메트릭 수집 아키텍처

```
┌─────────────────────────────────────────────────┐
│          Kubernetes API Server                  │
│     (LoadBalancer 서비스 생성 요청)              │
└────────────────┬────────────────────────────────┘
                 │ Watch Events
                 ▼
┌─────────────────────────────────────────────────┐
│        MetalLB Controller Pod                   │
│  - IP Address Manager (IPAM)                   │
│  - Metrics Exporter :7472/metrics              │
└────────────────┬────────────────────────────────┘
                 │ Scrape
                 ▼
┌─────────────────────────────────────────────────┐
│            Prometheus Server                    │
│  - ServiceMonitor 또는 scrape config 사용       │
│  - 30초마다 메트릭 수집                          │
└─────────────────────────────────────────────────┘
```

### 메트릭 엔드포인트

- **Controller**: `http://<controller-pod>:7472/metrics`
- **Speaker**: `http://<speaker-pod>:7472/metrics`

---

## 주요 메트릭 상세 설명

### 1. IP 할당 관련 메트릭

#### `metallb_allocator_addresses_in_use_total`

> [!important] 가장 중요한 메트릭
> 현재 할당된 IP 주소의 총 개수

**타입**: Gauge
**Labels**:
- `pool`: IP Pool 이름

**예시**:
```promql
# 현재 사용 중인 IP 개수
metallb_allocator_addresses_in_use_total{pool="default"} 5

# Pool별 사용량
metallb_allocator_addresses_in_use_total
```

**사용 사례**:
- ✅ IP Pool 사용률 모니터링
- ✅ IP 고갈 사전 경고
- ✅ 서비스 증가 추세 분석

---

#### `metallb_allocator_addresses_total`

**타입**: Gauge
**설명**: IP Pool에서 사용 가능한 전체 IP 주소 개수

**Labels**:
- `pool`: IP Pool 이름

**예시**:
```promql
# 전체 IP 개수
metallb_allocator_addresses_total{pool="default"} 20

# 사용 가능한 IP 개수 계산
metallb_allocator_addresses_total - metallb_allocator_addresses_in_use_total

# 사용률 계산
(metallb_allocator_addresses_in_use_total / metallb_allocator_addresses_total) * 100
```

---

#### `metallb_allocator_ip_addresses_in_use_total`

**타입**: Gauge
**설명**: 각 서비스에 할당된 IP 주소 (더 상세한 버전)

**Labels**:
- `pool`: IP Pool 이름
- `service`: 서비스 이름
- `namespace`: 네임스페이스

**예시**:
```promql
# 특정 네임스페이스의 IP 사용량
sum(metallb_allocator_ip_addresses_in_use_total{namespace="production"})

# 서비스별 IP 사용 확인
metallb_allocator_ip_addresses_in_use_total{service="nginx"}
```

---

### 2. IP 할당 오류 메트릭

#### `metallb_allocator_addresses_errors_total`

**타입**: Counter
**설명**: IP 할당 실패 횟수 누적

**원인**:
- IP Pool 고갈
- 잘못된 설정
- 네트워크 충돌

**예시**:
```promql
# 최근 5분간 할당 실패율
rate(metallb_allocator_addresses_errors_total[5m])

# 전체 할당 실패 횟수
sum(metallb_allocator_addresses_errors_total)
```

---

### 3. BGP 관련 메트릭 (BGP 모드)

#### `metallb_bgp_session_up`

**타입**: Gauge
**설명**: BGP 세션 상태 (1=Up, 0=Down)

**Labels**:
- `peer`: BGP peer 주소

**예시**:
```promql
# 모든 BGP 세션 상태 확인
metallb_bgp_session_up

# 다운된 세션 찾기
metallb_bgp_session_up == 0

# 정상 세션 개수
sum(metallb_bgp_session_up)
```

**알림 예시**:
```yaml
alert: MetalLBBGPSessionDown
expr: metallb_bgp_session_up == 0
for: 2m
```

---

#### `metallb_bgp_updates_total`

**타입**: Counter
**설명**: BGP 업데이트 메시지 전송 횟수

**Labels**:
- `peer`: BGP peer 주소

**예시**:
```promql
# 최근 5분간 BGP 업데이트 빈도
rate(metallb_bgp_updates_total[5m])

# Peer별 업데이트 횟수
sum(metallb_bgp_updates_total) by (peer)
```

---

#### `metallb_bgp_announced_prefixes_total`

**타입**: Gauge
**설명**: BGP를 통해 발표된 프리픽스 개수

**예시**:
```promql
# 발표된 라우트 개수
metallb_bgp_announced_prefixes_total

# Peer별 발표 개수
metallb_bgp_announced_prefixes_total{peer="192.168.1.1"}
```

---

### 4. Layer2 관련 메트릭 (L2 모드)

#### `metallb_speaker_announced`

**타입**: Gauge
**설명**: Speaker가 현재 발표 중인 서비스 개수

**Labels**:
- `node`: 노드 이름
- `protocol`: 프로토콜 (layer2, bgp)

**예시**:
```promql
# 노드별 발표 중인 서비스 개수
metallb_speaker_announced{protocol="layer2"}

# 특정 노드의 서비스 개수
metallb_speaker_announced{node="w1-k8s"}
```

---

#### `metallb_layer2_requests_received_total`

**타입**: Counter
**설명**: 수신된 ARP 요청 총 개수

**예시**:
```promql
# 초당 ARP 요청 수
rate(metallb_layer2_requests_received_total[1m])

# 비정상적으로 높은 ARP 요청 (ARP 스캔 감지)
rate(metallb_layer2_requests_received_total[1m]) > 100
```

---

#### `metallb_layer2_responses_sent_total`

**타입**: Counter
**설명**: 전송된 ARP 응답 총 개수

**예시**:
```promql
# ARP 응답 성공률
rate(metallb_layer2_responses_sent_total[1m]) /
rate(metallb_layer2_requests_received_total[1m])
```

---

### 5. 시스템 메트릭

#### `metallb_k8s_client_config_loaded_bool`

**타입**: Gauge
**설명**: Kubernetes 설정 로드 상태 (1=성공, 0=실패)

**예시**:
```promql
# 설정 로드 실패 감지
metallb_k8s_client_config_loaded_bool == 0
```

---

#### `metallb_k8s_client_api_duration_seconds`

**타입**: Histogram
**설명**: Kubernetes API 호출 지연 시간

**예시**:
```promql
# 평균 API 호출 시간
rate(metallb_k8s_client_api_duration_seconds_sum[5m]) /
rate(metallb_k8s_client_api_duration_seconds_count[5m])

# 95번째 백분위수
histogram_quantile(0.95,
  rate(metallb_k8s_client_api_duration_seconds_bucket[5m])
)
```

---

## 실전 활용 예시

### 1. IP Pool 사용률 대시보드

```promql
# Gauge: 현재 사용률
(metallb_allocator_addresses_in_use_total / metallb_allocator_addresses_total) * 100

# Graph: 시간별 IP 할당 추세
metallb_allocator_addresses_in_use_total[1h]

# Table: Pool별 상세 현황
metallb_allocator_addresses_in_use_total
```

---

### 2. 서비스별 IP 사용 현황

```promql
# 네임스페이스별 IP 사용량
sum(metallb_allocator_ip_addresses_in_use_total) by (namespace)

# 가장 많은 IP를 사용하는 서비스 Top 5
topk(5,
  sum(metallb_allocator_ip_addresses_in_use_total) by (service, namespace)
)
```

---

### 3. BGP 세션 모니터링

```promql
# 전체 BGP 세션 상태
metallb_bgp_session_up

# 다운된 세션 알림
ALERTS{alertname="MetalLBBGPSessionDown"}

# BGP 업데이트 빈도 (Flapping 감지)
rate(metallb_bgp_updates_total[5m]) > 10
```

---

### 4. Layer2 ARP 트래픽 분석

```promql
# 초당 ARP 요청/응답
rate(metallb_layer2_requests_received_total[1m])
rate(metallb_layer2_responses_sent_total[1m])

# 응답하지 못한 ARP 요청 (비정상)
rate(metallb_layer2_requests_received_total[1m]) -
rate(metallb_layer2_responses_sent_total[1m])
```

---

## 알림 규칙 설정

### 1. IP Pool 고갈 경고

```yaml
groups:
  - name: metallb-ip-pool
    rules:
      - alert: MetalLBIPPoolNearlyExhausted
        expr: |
          (metallb_allocator_addresses_in_use_total /
           metallb_allocator_addresses_total) > 0.8
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "MetalLB IP Pool 80% 사용 중"
          description: "Pool {{ $labels.pool }}의 IP가 {{ $value | humanizePercentage }} 사용 중입니다."

      - alert: MetalLBIPPoolExhausted
        expr: |
          (metallb_allocator_addresses_in_use_total /
           metallb_allocator_addresses_total) >= 0.95
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "MetalLB IP Pool 거의 고갈"
          description: "Pool {{ $labels.pool }}의 IP가 {{ $value | humanizePercentage }} 사용 중입니다. 즉시 조치 필요!"
```

---

### 2. IP 할당 실패 알림

```yaml
- alert: MetalLBIPAllocationFailure
  expr: |
    rate(metallb_allocator_addresses_errors_total[5m]) > 0
  for: 1m
  labels:
    severity: critical
  annotations:
    summary: "MetalLB IP 할당 실패 발생"
    description: "최근 5분간 {{ $value }} 건의 IP 할당 실패가 발생했습니다."
```

---

### 3. BGP 세션 다운 알림

```yaml
- alert: MetalLBBGPSessionDown
  expr: |
    metallb_bgp_session_up == 0
  for: 2m
  labels:
    severity: critical
  annotations:
    summary: "MetalLB BGP 세션 다운"
    description: "Peer {{ $labels.peer }}와의 BGP 세션이 다운되었습니다."

- alert: MetalLBBGPFlapping
  expr: |
    rate(metallb_bgp_updates_total[5m]) > 20
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "MetalLB BGP Flapping 감지"
    description: "Peer {{ $labels.peer }}에서 비정상적으로 높은 BGP 업데이트 빈도가 감지되었습니다."
```

---

### 4. Layer2 ARP 이상 감지

```yaml
- alert: MetalLBHighARPTraffic
  expr: |
    rate(metallb_layer2_requests_received_total[1m]) > 100
  for: 3m
  labels:
    severity: warning
  annotations:
    summary: "MetalLB 높은 ARP 트래픽"
    description: "노드 {{ $labels.node }}에서 비정상적으로 높은 ARP 요청이 감지되었습니다. ({{ $value }}/s)"

- alert: MetalLBARPResponseFailure
  expr: |
    rate(metallb_layer2_responses_sent_total[1m]) <
    (rate(metallb_layer2_requests_received_total[1m]) * 0.5)
  for: 2m
  labels:
    severity: critical
  annotations:
    summary: "MetalLB ARP 응답 실패"
    description: "ARP 요청의 50% 이상이 응답되지 않고 있습니다."
```

---

### 5. 설정 로드 실패 알림

```yaml
- alert: MetalLBConfigLoadFailure
  expr: |
    metallb_k8s_client_config_loaded_bool == 0
  for: 1m
  labels:
    severity: critical
  annotations:
    summary: "MetalLB 설정 로드 실패"
    description: "MetalLB가 Kubernetes 설정을 로드하지 못했습니다."
```

---

## 트러블슈팅

### 1. 메트릭이 수집되지 않을 때

#### 확인 사항

```bash
# 1. MetalLB Pod 상태 확인
kubectl get pods -n metallb-system

# 2. Controller Pod 메트릭 엔드포인트 확인
kubectl exec -n metallb-system <controller-pod> -- \
  wget -qO- localhost:7472/metrics | head -20

# 3. ServiceMonitor 확인 (Prometheus Operator 사용 시)
kubectl get servicemonitor -n metallb-system

# 4. Prometheus Targets 확인
# Prometheus UI → Status → Targets
# metallb 관련 타겟이 UP 상태인지 확인
```

---

### 2. 메트릭 값이 0인 경우

```bash
# Controller 로그 확인
kubectl logs -n metallb-system <controller-pod> | grep -i error

# ConfigMap 확인
kubectl get configmap -n metallb-system metallb -o yaml

# IP Pool 설정 확인 (CRD 사용 시)
kubectl get ipaddresspool -n metallb-system
```

---

### 3. BGP 메트릭이 안 나올 때

```bash
# BGP 모드 설정 확인
kubectl get bgppeer -n metallb-system

# Speaker Pod 로그 확인
kubectl logs -n metallb-system <speaker-pod> | grep -i bgp

# BGP 피어 연결 확인
kubectl exec -n metallb-system <speaker-pod> -- \
  wget -qO- localhost:7472/metrics | grep bgp_session_up
```

---

### 4. Layer2 메트릭이 안 나올 때

```bash
# L2Advertisement 확인
kubectl get l2advertisement -n metallb-system

# Speaker Pod 네트워크 확인
kubectl exec -n metallb-system <speaker-pod> -- ip addr

# ARP 테이블 확인 (호스트에서)
arp -a | grep <loadbalancer-ip>
```

---

## 메트릭 직접 확인 방법

### Port-Forward로 메트릭 조회

```bash
# Controller 메트릭
kubectl port-forward -n metallb-system \
  deployment/metallb-controller 7472:7472

# 다른 터미널에서
curl http://localhost:7472/metrics

# Speaker 메트릭 (특정 Pod)
kubectl port-forward -n metallb-system \
  <speaker-pod-name> 7472:7472

curl http://localhost:7472/metrics
```

---

### Prometheus Query 예시

```promql
# 전체 MetalLB 메트릭 조회
{__name__=~"metallb_.*"}

# IP 관련 메트릭만
{__name__=~"metallb_allocator.*"}

# BGP 관련 메트릭만
{__name__=~"metallb_bgp.*"}

# Layer2 관련 메트릭만
{__name__=~"metallb_layer2.*"}
```

---

## Grafana 대시보드 예시

### 패널 구성

#### 1. IP Pool 상태
- **Visualization**: Gauge
- **Query**:
  ```promql
  (metallb_allocator_addresses_in_use_total /
   metallb_allocator_addresses_total) * 100
  ```

#### 2. IP 할당 추세
- **Visualization**: Graph
- **Query**:
  ```promql
  metallb_allocator_addresses_in_use_total
  ```

#### 3. Pool별 사용 현황
- **Visualization**: Bar Chart
- **Query**:
  ```promql
  metallb_allocator_addresses_in_use_total
  ```

#### 4. BGP 세션 상태
- **Visualization**: Stat
- **Query**:
  ```promql
  sum(metallb_bgp_session_up)
  ```

#### 5. 할당 오류 발생률
- **Visualization**: Graph
- **Query**:
  ```promql
  rate(metallb_allocator_addresses_errors_total[5m])
  ```

---

## 참고 자료

> [!info] 추가 학습 리소스
> - [MetalLB 공식 문서](https://metallb.universe.tf/)
> - [MetalLB GitHub](https://github.com/metallb/metallb)
> - [[01_프로메테우스_기초_개념_완벽_정리|프로메테우스 기초]]
> - [[02_모니터링_파이프라인_완벽_이해|모니터링 파이프라인]]

---

## 버전 정보

```yaml
작성일: 2025-12-04
MetalLB 버전: v0.13.x 기준
Kubernetes 버전: v1.30.x 기준
관련 문서:
  - [[07_PromQL_메트릭_타입_완벽_가이드]]
  - [[08_PromQL_레이블_매처_완벽_가이드]]
```

---

## 추가 팁

### 메트릭 보존 기간 설정

```yaml
# Prometheus values.yaml
prometheus:
  prometheusSpec:
    retention: 30d  # 30일 보관
    retentionSize: "50GB"  # 최대 50GB
```

### 메트릭 샘플링 간격 조정

```yaml
# ServiceMonitor
spec:
  endpoints:
  - port: metrics
    interval: 30s  # 기본값
    scrapeTimeout: 10s
```

### 고급 쿼리 예시

```promql
# 지난 24시간 동안 최대 IP 사용량
max_over_time(metallb_allocator_addresses_in_use_total[24h])

# 시간당 평균 IP 사용량
avg_over_time(metallb_allocator_addresses_in_use_total[1h])

# IP 할당 속도 (시간당)
rate(metallb_allocator_addresses_in_use_total[1h]) * 3600
```

---

> [!tip] 마무리
> **이 가이드를 통해 MetalLB의 모든 메트릭을 효과적으로 모니터링하고, 문제를 사전에 감지할 수 있습니다!** 🚀

---

**📅 최종 업데이트**: 2025-12-04
**✍️ 작성**: Claude Code 학습 세션
**🔗 연관 문서**: [[00_프로메테우스_시리즈_목차]]
