---
title: KEDA - 쿠버네티스 이벤트 기반 오토스케일링
tags:
  - keda
  - kubernetes
  - autoscaling
  - event-driven
  - hpa
  - devops
aliases:
  - KEDA
  - Kubernetes Event-Driven Autoscaling
date: 2026-01-22
category: 2_기술_분석/쿠버네티스
status: 완성
priority: 중간
---

# 🎯 KEDA - 쿠버네티스 이벤트 기반 오토스케일링

## 📑 목차
- [[#1. 개요|개요]]
- [[#2. 핵심 구성요소|핵심 구성요소]]
- [[#3. 지원 Scaler|지원 Scaler]]
- [[#4. 설정 예시|설정 예시]]
- [[#5. 트러블슈팅|트러블슈팅]]

---

## 1. 개요

### 💡 KEDA란?

> [!info] KEDA (Kubernetes Event-Driven Autoscaling)
> 외부 이벤트 소스 메트릭 기반으로 Pod 수량을 자동 조절하는 쿠버네티스용 오토스케일러
> - **CNCF 프로젝트** (Microsoft 주도 기여)
> - **핵심 기능**: 0개까지 스케일 다운 가능 (비용 절감)

### 📊 기존 HPA vs KEDA 비교

| 항목 | HPA (기존) | KEDA |
|------|-----------|------|
| **메트릭 소스** | CPU/Memory만 | 60+ 외부 소스 지원 |
| **최소 Pod** | 1개 | **0개** (Scale to Zero) |
| **스케일링 기준** | 리소스 사용률 | 이벤트 수 / 큐 길이 등 |
| **설정 복잡도** | 낮음 | 중간 |

### 🎯 주요 사용 사례

| 시나리오 | 설명 |
|----------|------|
| **메시지 큐 Consumer** | Kafka lag에 따라 Consumer Pod 자동 조절 |
| **배치 작업** | 작업 없을 때 0개, 작업 들어오면 자동 확장 |
| **비용 최적화** | 트래픽 없는 시간대 Pod 0개로 축소 |
| **이벤트 처리** | 이벤트 발생량에 비례한 처리 용량 확보 |

---

## 2. 핵심 구성요소

### 📋 아키텍처

```
┌─────────────────────────────────────────────────────────────┐
│                      KEDA Operator                          │
├─────────────┬─────────────┬─────────────┬──────────────────┤
│   Scaler    │ ScaledObject│  ScaledJob  │  Metrics Server  │
│  (메트릭    │ (Deployment │  (Job 기반  │  (HPA에 메트릭   │
│   수집)     │  스케일링)  │  스케일링)  │   제공)          │
└─────────────┴─────────────┴─────────────┴──────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│                    Kubernetes HPA                           │
│              (KEDA가 생성/관리하는 HPA)                      │
└─────────────────────────────────────────────────────────────┘
```

### 📋 구성요소 설명

| 구성요소 | 역할 |
|----------|------|
| **Scaler** | 외부 시스템(Kafka, Prometheus 등)에서 메트릭 수집 |
| **ScaledObject** | Deployment/StatefulSet 대상 + 트리거 정의 |
| **ScaledJob** | Job 기반 워크로드 스케일링 (배치 작업용) |
| **Metrics Server** | 수집한 메트릭을 HPA가 이해할 수 있는 형태로 변환 |

---

## 3. 지원 Scaler

### 🔌 주요 Scaler (60+ 지원)

| 카테고리 | Scaler |
|----------|--------|
| **메시지 큐** | Kafka, RabbitMQ, AWS SQS, Azure Service Bus, Redis Streams, NATS |
| **데이터베이스** | PostgreSQL, MySQL, MongoDB, Redis, Cassandra |
| **모니터링** | Prometheus, Datadog, New Relic, Dynatrace, Graphite |
| **클라우드** | AWS CloudWatch, GCP Pub/Sub, Azure Monitor, Azure Queue |
| **기타** | Cron, HTTP Requests, Elasticsearch, etcd, Metrics API |

---

## 4. 설정 예시

### 📝 Kafka Consumer 스케일링

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: kafka-consumer-scaler
  namespace: production
spec:
  scaleTargetRef:
    name: kafka-consumer-deployment    # 대상 Deployment
  pollingInterval: 15                  # 메트릭 수집 주기 (초)
  cooldownPeriod: 300                  # 스케일 다운 대기 시간 (초)
  minReplicaCount: 0                   # 이벤트 없으면 0까지 축소
  maxReplicaCount: 100
  triggers:
    - type: kafka
      metadata:
        bootstrapServers: kafka.production:9092
        consumerGroup: order-processor
        topic: orders
        lagThreshold: "50"             # lag 50 이상이면 스케일 아웃
```

### 📝 Prometheus 메트릭 기반 스케일링

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: http-scaler
spec:
  scaleTargetRef:
    name: api-deployment
  minReplicaCount: 1
  maxReplicaCount: 20
  triggers:
    - type: prometheus
      metadata:
        serverAddress: http://prometheus.monitoring:9090
        metricName: http_requests_per_second
        query: sum(rate(http_requests_total{app="api"}[2m]))
        threshold: "100"               # 초당 100 요청당 1 Pod
```

### 📝 Cron 기반 스케일링 (시간대별)

```yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: cron-scaler
spec:
  scaleTargetRef:
    name: batch-processor
  minReplicaCount: 0
  maxReplicaCount: 10
  triggers:
    - type: cron
      metadata:
        timezone: Asia/Seoul
        start: 0 9 * * 1-5             # 평일 오전 9시
        end: 0 18 * * 1-5              # 평일 오후 6시
        desiredReplicas: "5"           # 업무 시간에 5개 유지
```

### 📝 인증이 필요한 경우 (TriggerAuthentication)

```yaml
apiVersion: keda.sh/v1alpha1
kind: TriggerAuthentication
metadata:
  name: kafka-auth
spec:
  secretTargetRef:
    - parameter: sasl_username
      name: kafka-secrets
      key: username
    - parameter: sasl_password
      name: kafka-secrets
      key: password
---
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: kafka-scaler-with-auth
spec:
  scaleTargetRef:
    name: kafka-consumer
  triggers:
    - type: kafka
      authenticationRef:
        name: kafka-auth               # 위에서 정의한 인증 참조
      metadata:
        bootstrapServers: kafka:9092
        consumerGroup: my-group
        topic: events
```

---

## 5. 트러블슈팅

### 🔧 문제 해결

| 증상 | 원인 | 해결 방법 |
|------|------|-----------|
| Pod 스케일 안됨 | Scaler 연결 실패 | `kubectl describe scaledobject` 로 에러 확인 |
| 0으로 스케일 다운 안됨 | minReplicaCount 미설정 | `minReplicaCount: 0` 명시 |
| 스케일 아웃 느림 | pollingInterval 너무 김 | 15초 이하로 조정 |
| 메트릭 수집 실패 | 인증 문제 | TriggerAuthentication 리소스 확인 |
| HPA 충돌 | 기존 HPA 존재 | 기존 HPA 삭제 후 KEDA 적용 |

### 💻 디버깅 명령어

```bash
# ScaledObject 상태 확인
kubectl describe scaledobject <name>

# KEDA Operator 로그
kubectl logs -n keda -l app=keda-operator

# KEDA가 생성한 HPA 확인
kubectl get hpa

# 외부 메트릭 확인
kubectl get --raw "/apis/external.metrics.k8s.io/v1beta1"

# ScaledObject 이벤트 확인
kubectl get events --field-selector involvedObject.name=<scaledobject-name>
```

---

## 📚 참고 자료

### 공식 문서

- [KEDA Official Docs](https://keda.sh/docs/)
- [KEDA Scalers List](https://keda.sh/docs/scalers/)
- [KEDA GitHub](https://github.com/kedacore/keda)

### 관련 주제

- [[Kubernetes HPA 심화]]
- [[Prometheus 모니터링]]
- [[Kafka 운영 가이드]]

---

> [!tip] Ansible EDA와의 차이
> - **KEDA**: 쿠버네티스 Pod 수량 조절 (스케일링 전용)
> - **Ansible EDA**: 인프라 전체 자동화 (Playbook 실행)
> - 관련 문서: [[Ansible_EDA_이벤트기반_자동화]]
