---
title: Ansible EDA & KEDA - 이벤트 기반 자동화 완벽 가이드
tags:
  - ansible
  - eda
  - keda
  - kubernetes
  - event-driven
  - automation
  - devops
aliases:
  - EDA
  - Event-Driven-Ansible
  - KEDA
date: 2026-01-21
category: 2_기술_분석/자동화
status: 완성
priority: 높음
---

# 🎯 Ansible EDA & KEDA - 이벤트 기반 자동화

## 📑 목차
- [[#1. 개요|개요]]
- [[#2. Ansible EDA|Ansible EDA]]
- [[#3. KEDA|KEDA]]
- [[#4. Self-Healing 아키텍처|Self-Healing 아키텍처]]
- [[#5. 설정 스니펫|설정 스니펫]]
- [[#6. 트러블슈팅 가이드|트러블슈팅 가이드]]
- [[#7. 운영 체크리스트|운영 체크리스트]]
- [[#8. 도입 시 고려사항|도입 시 고려사항]]

---

## 1. 개요

### 💡 이벤트 기반 자동화란?

> [!note] 핵심 개념
> **"무언가가 일어났을 때 즉시 반응"** - 사람이 실행하거나 스케줄(Cron)에 의존하는 방식에서 벗어나, 이벤트 발생 시 자동으로 대응하는 패러다임

### 📊 Request-driven vs Event-driven 비교

| 구분 | Request-driven (기존) | Event-driven (EDA/KEDA) |
|------|----------------------|-------------------------|
| **트리거** | 사람이 수동 실행 / Cron 스케줄 | 이벤트 발생 시 자동 |
| **반응 속도** | 분~시간 (주기적 점검 공백) | 초~밀리초 (실시간) |
| **대응 방식** | 사후 조치 중심 | 사전 예방 / 즉시 대응 |
| **운영 부담** | 높음 (수동 개입 필요) | 낮음 (자동화) |

---

## 2. Ansible EDA

### 💡 정의

> [!info] Ansible EDA (Event-Driven Ansible)
> 이벤트가 발생했을 때 규칙(Rule)을 평가하여 자동으로 Playbook을 실행하는 실시간 자동화 프레임워크

### 📋 핵심 구성요소 (3단계 파이프라인)

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   SOURCE    │ → │    RULE     │ → │   ACTION    │
│  (Input)    │    │ (Evaluate)  │    │ (Execute)   │
└─────────────┘    └─────────────┘    └─────────────┘
```

| 구성요소 | 역할 | 예시 |
|----------|------|------|
| **Source** | 이벤트를 수신하는 플러그인 | Webhook, Kafka, Prometheus Alertmanager, Syslog |
| **Rule** | 조건 정의 (when) | `event.alert.status == "firing"` |
| **Action** | 조건 충족 시 실행할 작업 | `run_playbook`, `run_module`, `debug` |

### 🎯 주요 사용 사례

| 시나리오 | 트리거 | 자동 대응 |
|----------|--------|-----------|
| **인프라 장애 복구** | CPU 90% 초과 | Auto Scale-out |
| **서비스 복구** | 프로세스 다운 감지 | 자동 재기동 |
| **디스크 관리** | 임계치 도달 | 로그 정리 + 알림 |
| **보안 대응** | 비인가 로그인 반복 | 계정 자동 잠금 |
| **방화벽** | IDS/IPS 경보 | 자동 차단 규칙 추가 |

### 🔧 설치 전략: RHEL 9 vs RHEL 10

| 항목 | RHEL 9 (권장) | RHEL 10 |
|------|---------------|---------|
| **설치 방식** | RPM (Standard) | Container Only |
| **지원 상태** | AAP 공식 완전 지원 | Lab 레벨 |
| **안정성** | 검증됨 | 실험적 |
| **권장 용도** | 프로덕션 | 테스트/개발 |

> [!tip] Best Practice
> **혼합 구조 권장**: Controller는 RHEL 9 (RPM), EDA는 Container로 구성하여 안정성과 최신 기능 모두 확보

---

## 3. KEDA

### 💡 정의

> [!info] KEDA (Kubernetes Event-Driven Autoscaling)
> 외부 이벤트 소스 메트릭 기반으로 Pod 수량을 자동 조절하는 쿠버네티스용 오토스케일러. **0개까지 스케일 다운** 가능

### 📋 기존 HPA vs KEDA 비교

| 항목 | HPA (기존) | KEDA |
|------|-----------|------|
| **메트릭 소스** | CPU/Memory만 | 60+ 외부 소스 지원 |
| **최소 Pod** | 1개 | **0개** (비용 절감) |
| **스케일링 기준** | 리소스 사용률 | 이벤트 수 / 큐 길이 등 |

### 📋 핵심 구성요소

| 구성요소 | 역할 |
|----------|------|
| **Scaler** | 외부 시스템에서 메트릭 수집 |
| **ScaledObject** | Deployment 대상 + 트리거 정의 |
| **ScaledJob** | Job 기반 워크로드 스케일링 |
| **Metrics Server** | HPA에 메트릭 제공 |

### 🔌 지원 Scaler (주요)

| 카테고리 | Scaler |
|----------|--------|
| **메시지 큐** | Kafka, RabbitMQ, AWS SQS, Azure Service Bus, Redis Streams |
| **데이터베이스** | PostgreSQL, MySQL, MongoDB, Redis |
| **모니터링** | Prometheus, Datadog, New Relic, Dynatrace |
| **클라우드** | AWS CloudWatch, GCP Pub/Sub, Azure Monitor |
| **기타** | Cron, HTTP Requests, Elasticsearch, NATS |

---

## 4. Self-Healing 아키텍처

### 💡 개념

> [!note] Self-Healing (자동복구)
> 서비스 장애 발생 시 **운영자의 개입 없이 즉시 자동으로 복구**를 수행하는 시스템. MTTR(평균 복구 시간)을 초 단위로 단축

### 📊 Watchdog 자동복구 흐름 (4단계)

```
┌──────────────┐   ┌──────────────┐   ┌──────────────┐   ┌──────────────┐
│  Detection   │ → │  Transport   │ → │   Decision   │ → │   Recovery   │
│  (감지)       │   │  (전달)       │   │   (판단)      │   │   (복구)      │
└──────────────┘   └──────────────┘   └──────────────┘   └──────────────┘
     systemd           Webhook           EDA Rule          Playbook
    OnFailure           POST              Match            Execute
```

#### 상세 흐름

1. **Detection (감지)**: Managed Node의 systemd가 서비스 실패 감지
2. **Transport (전달)**: OnFailure 유닛이 Webhook으로 EDA에 이벤트 전송
3. **Decision (판단)**: EDA Rulebook이 조건 매칭 수행
4. **Recovery (복구)**: 매칭 시 Controller가 복구 Playbook 실행

### 🔄 Ansible EDA + KEDA 연계 시나리오

```
[Prometheus Alert: 응답 지연]
         ↓
[Ansible EDA] → 캐시 초기화 Playbook 실행
         ↓
[KEDA] → 메시지 큐 lag 감지 → Consumer Pod 자동 증가
         ↓
[서비스 정상화]
```

---

## 5. 설정 스니펫

### 📝 Ansible EDA - Webhook 알림 스크립트

```bash
#!/bin/bash
# /usr/local/bin/eda_notify.sh
# Managed Node에서 EDA로 이벤트 전송

SERVICE_NAME=$1
HOST=$(hostname)
TIMESTAMP=$(date -Iseconds)

curl -X POST http://eda-controller:5000/endpoint \
  -H "Content-Type: application/json" \
  -d "{
    \"event\": \"service_failed\",
    \"service\": \"${SERVICE_NAME}\",
    \"host\": \"${HOST}\",
    \"timestamp\": \"${TIMESTAMP}\"
  }"
```

### 📝 Systemd OnFailure 연동

```ini
# /etc/systemd/system/nginx.service.d/override.conf
[Unit]
OnFailure=eda-notify@%n.service

# /etc/systemd/system/eda-notify@.service
[Unit]
Description=EDA Notify for %i

[Service]
Type=oneshot
ExecStart=/usr/local/bin/eda_notify.sh %i
```

> [!warning] 주의
> 설정 변경 후 반드시 `systemctl daemon-reload` 실행 필요

### 📝 EDA Rulebook 예시

```yaml
# watchdog_rulebook.yml
---
- name: 서비스 장애 자동 복구
  hosts: all
  sources:
    - ansible.eda.webhook:
        host: 0.0.0.0
        port: 5000

  rules:
    - name: Nginx 서비스 다운 시 재시작
      condition: >
        event.payload.event == "service_failed" and
        event.payload.service is match("nginx.*")
      action:
        run_playbook:
          name: playbooks/restart_service.yml
          extra_vars:
            target_host: "{{ event.payload.host }}"
            service_name: "{{ event.payload.service }}"

    - name: 디스크 용량 부족 시 정리
      condition: event.alert.labels.alertname == "DiskSpaceLow"
      action:
        run_playbook:
          name: playbooks/cleanup_disk.yml
```

### 📝 복구용 Playbook 예시

```yaml
# playbooks/restart_service.yml
---
- name: 서비스 자동 복구
  hosts: "{{ target_host }}"
  become: yes

  tasks:
    - name: 서비스 상태 확인
      ansible.builtin.systemd:
        name: "{{ service_name }}"
      register: service_status

    - name: 서비스 재시작
      ansible.builtin.systemd:
        name: "{{ service_name }}"
        state: restarted
      when: service_status.status.ActiveState != "active"

    - name: 복구 결과 알림
      ansible.builtin.uri:
        url: "{{ slack_webhook_url }}"
        method: POST
        body_format: json
        body:
          text: "✅ {{ service_name }} on {{ target_host }} 자동 복구 완료"
```

### 📝 KEDA ScaledObject 예시

```yaml
# kafka-consumer-scaler.yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: kafka-consumer-scaler
  namespace: production
spec:
  scaleTargetRef:
    name: kafka-consumer-deployment
  pollingInterval: 15          # 메트릭 수집 주기 (초)
  cooldownPeriod: 300          # 스케일 다운 대기 시간 (초)
  minReplicaCount: 0           # 이벤트 없으면 0까지 축소
  maxReplicaCount: 100
  triggers:
    - type: kafka
      metadata:
        bootstrapServers: kafka.production:9092
        consumerGroup: order-processor
        topic: orders
        lagThreshold: "50"     # lag 50 이상이면 스케일 아웃
```

### 📝 KEDA Prometheus 기반 스케일링

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
        threshold: "100"       # 초당 100 요청당 1 Pod
```

---

## 6. 트러블슈팅 가이드

### 🔧 Ansible EDA 문제 해결

| 증상 | 원인 | 해결 방법 |
|------|------|-----------|
| 이벤트 수신 안됨 (404/500/Timeout) | 방화벽 차단, 잘못된 포트 | 포트 5000 인바운드 허용, URL 경로 확인 |
| Rulebook 로드 실패 | YAML 문법 오류, 들여쓰기 | `ansible-rulebook --check` 로 검증 |
| Playbook 실행 안됨 | Controller 연결 실패, 인증 오류 | API 토큰 및 네트워크 확인 |
| 조건 매칭 안됨 | 이벤트 페이로드 구조 불일치 | `debug` 액션으로 실제 페이로드 확인 |
| 중복 실행 | 이벤트 중복 발생 | throttle 설정 또는 debounce 로직 추가 |

### 🔧 KEDA 문제 해결

| 증상 | 원인 | 해결 방법 |
|------|------|-----------|
| Pod 스케일 안됨 | Scaler 연결 실패 | `kubectl describe scaledobject` 로 에러 확인 |
| 0으로 스케일 다운 안됨 | minReplicaCount 설정 | `minReplicaCount: 0` 명시 |
| 스케일 아웃 느림 | pollingInterval 너무 김 | 15초 이하로 조정 |
| 메트릭 수집 실패 | 인증 문제 | TriggerAuthentication 리소스 확인 |

### 💻 디버깅 명령어

```bash
# EDA Rulebook 검증
ansible-rulebook --check -r watchdog_rulebook.yml

# EDA 로그 확인
podman logs eda-controller

# KEDA ScaledObject 상태
kubectl describe scaledobject kafka-consumer-scaler

# KEDA 메트릭 확인
kubectl get --raw "/apis/external.metrics.k8s.io/v1beta1"

# HPA 상태 (KEDA가 생성)
kubectl get hpa
```

---

## 7. 운영 체크리스트

### ✅ 배포 전 필수 점검 (5대 영역)

#### 1. 네트워크

- [ ] EDA ↔ Controller 통신: API 포트(443) 도달 가능
- [ ] Webhook 포트 개방: 인바운드 5000 허용
- [ ] Managed Node → EDA: 아웃바운드 허용

#### 2. 인증/권한

- [ ] EDA Controller API 토큰 발급 및 적용
- [ ] KEDA TriggerAuthentication 설정 완료
- [ ] ServiceAccount 권한 확인 (RBAC)

#### 3. 모니터링

- [ ] EDA 이벤트 로그 수집 설정
- [ ] KEDA 메트릭 Prometheus 연동
- [ ] 알림 채널 연동 (Slack, PagerDuty 등)

#### 4. 고가용성

- [ ] EDA Controller 이중화 (Active-Standby)
- [ ] KEDA Operator 복제본 2+ 설정
- [ ] 장애 시 Fallback 플레이북 준비

#### 5. 보안

- [ ] Webhook 엔드포인트 인증 적용
- [ ] 민감 정보 Vault/Secret 저장
- [ ] 네트워크 정책(NetworkPolicy) 적용

---

## 8. 도입 시 고려사항

### 🎯 5가지 핵심 영역

#### 1. 자동 조치 범위 정의

> [!warning] 중요
> 모든 것을 자동화하면 안 됨. **자동화할 작업**과 **수동 승인 필요한 작업** 명확히 구분

| 자동화 권장 | 수동 승인 권장 |
|-------------|----------------|
| 서비스 재시작 | 데이터 삭제/마이그레이션 |
| 로그 정리 | 프로덕션 배포 |
| 스케일 아웃 | 방화벽 정책 변경 |
| 캐시 초기화 | 사용자 계정 관련 조치 |

#### 2. 승인 프로세스

- 위험도 높은 작업: 2인 이상 승인 필요
- 변경 관리(Change Management) 연동 고려
- 감사 로그(Audit Log) 필수

#### 3. 테스트 전략

```
Dev → Staging → Canary → Production
```

- Dry-run 모드로 먼저 검증
- 점진적 롤아웃 (일부 노드부터)
- 롤백 플레이북 준비

#### 4. 장애 대응 시나리오

- EDA 자체 장애 시 대응 방안
- 무한 루프 방지 (이벤트 → 조치 → 이벤트 반복)
- Circuit Breaker 패턴 적용

#### 5. 조직 준비도

- 운영팀 교육 및 문서화
- On-call 프로세스 업데이트
- 책임 소재 명확화 (자동화 실패 시)

---

## 📚 참고 자료

### 공식 문서

- [Red Hat AAP EDA Documentation](https://access.redhat.com/documentation/en-us/red_hat_ansible_automation_platform)
- [KEDA Official Docs](https://keda.sh/docs/)
- [Ansible Rulebook Reference](https://ansible.readthedocs.io/projects/rulebook/)

### 관련 주제

- [[Kubernetes HPA 심화]]
- [[Prometheus Alertmanager 설정]]
- [[Ansible Automation Platform 구성]]
