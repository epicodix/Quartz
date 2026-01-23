---
title: Ansible EDA - 이벤트 기반 자동화
tags:
  - ansible
  - eda
  - event-driven
  - automation
  - aap
  - devops
  - self-healing
aliases:
  - EDA
  - Event-Driven-Ansible
date: 2026-01-22
category: 2_기술_분석/자동화
status: 완성
priority: 높음
---

# 🎯 Ansible EDA - 이벤트 기반 자동화

## 📑 목차
- [[#1. 개요|개요]]
- [[#2. 핵심 구성요소|핵심 구성요소]]
- [[#3. Self-Healing 아키텍처|Self-Healing 아키텍처]]
- [[#4. Lightspeed 연계|Lightspeed 연계]]
- [[#5. 설정 스니펫|설정 스니펫]]
- [[#6. 트러블슈팅 가이드|트러블슈팅 가이드]]
- [[#7. 운영 체크리스트|운영 체크리스트]]
- [[#8. 도입 시 고려사항|도입 시 고려사항]]
- [[#9. 실제 도입 사례 및 ROI|실제 도입 사례 및 ROI]]

---

## 1. 개요

### 💡 EDA란?

> [!info] Ansible EDA (Event-Driven Ansible)
> 이벤트가 발생했을 때 규칙(Rule)을 평가하여 **자동으로 Playbook을 실행**하는 실시간 자동화 프레임워크

### 📊 기존 Ansible vs EDA

| 구분 | 기존 Ansible | Ansible EDA |
|------|-------------|-------------|
| **트리거** | 사람이 수동 실행 / Cron 스케줄 | 이벤트 발생 시 자동 |
| **반응 속도** | 분~시간 (주기적 점검 공백) | 초 단위 (실시간) |
| **대응 방식** | 사후 조치 중심 | 즉시 대응 |
| **On-call 부담** | 높음 (새벽 콜 대응) | 낮음 (자동 복구) |

### 🎯 핵심 가치

> [!note] EDA의 진짜 가치
> ```
> 기존: 새벽 3시 장애 → 담당자 전화 → 잠 깨서 노트북 열고 → 조치
> EDA:  새벽 3시 장애 → 자동 복구 → 담당자는 아침에 로그만 확인
> ```
> **→ On-call 부담 감소 + MTTR 단축이 핵심 ROI**

---

## 2. 핵심 구성요소

### 📋 3단계 파이프라인 (Source → Rule → Action)

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   SOURCE    │ → │    RULE     │ → │   ACTION    │
│  (Input)    │    │ (Evaluate)  │    │ (Execute)   │
└─────────────┘    └─────────────┘    └─────────────┘
```

| 구성요소 | 역할 | 예시 |
|----------|------|------|
| **Source** | 이벤트를 수신하는 플러그인 | Webhook, Kafka, Prometheus Alertmanager |
| **Rule** | 조건 정의 (when) | `event.alert.status == "firing"` |
| **Action** | 조건 충족 시 실행할 작업 | `run_playbook`, `run_module`, `debug` |

### 📊 동작 원리 (Observe → Evaluate → Respond)

```
┌─────────────────────────────────────────────────────────────────┐
│  1. OBSERVE (관찰)                                              │
│     Dynatrace, Kafka, Prometheus 등에서 이벤트 수집              │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  2. EVALUATE (평가)                                             │
│     Rulebook이 이벤트 분석 → 조건 충족 여부 판단                  │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  3. RESPOND (응답)                                              │
│     Automation Controller에 Job Template 실행 요청 (Trigger)     │
│     → 단일 Playbook 또는 Workflow Job Template 실행 가능         │
└─────────────────────────────────────────────────────────────────┘
```

### 🔌 지원 Event Source

| 카테고리 | Source | 설명 |
|----------|--------|------|
| **모니터링** | Dynatrace, Prometheus, Alertmanager | AI 기반 이상 탐지 및 알림 |
| **ITSM** | ServiceNow | 티켓 생성/종료 연동 (변경 관리 자동화) |
| **Red Hat** | Red Hat Insights | 보안 취약점, 설정 드리프트 감지 |
| **메시지 큐** | Kafka (플러그인) | 대용량 이벤트 스트림 처리 |
| **범용** | Webhook, Syslog | 커스텀 이벤트 수신 |

### 🎯 주요 사용 사례

| 시나리오 | 트리거 | 자동 대응 |
|----------|--------|-----------|
| **인프라 장애 복구** | CPU 90% 초과 | Auto Scale-out |
| **서비스 복구** | 프로세스 다운 감지 | 자동 재기동 |
| **디스크 관리** | 임계치 도달 | 로그 정리 + 알림 |
| **보안 대응** | 비인가 로그인 반복 | 계정 자동 잠금 |
| **방화벽** | IDS/IPS 경보 | 자동 차단 규칙 추가 |
| **ITSM 연동** | 장애 발생 | ServiceNow 티켓 자동 생성 → 복구 → 티켓 종료 |

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

## 3. Self-Healing 아키텍처

### 💡 개념

> [!note] Self-Healing (자동복구)
> 서비스 장애 발생 시 **운영자의 개입 없이 즉시 자동으로 복구**를 수행하는 시스템
> MTTR(평균 복구 시간)을 분 단위 → 초 단위로 단축

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

---

## 4. Lightspeed 연계

### 💡 Ansible Lightspeed란?

> [!info] 역할 구분
> - **EDA**: 이벤트 기반 자동 실행 엔진 (Reflex, 반사신경)
> - **Lightspeed**: 운영자를 위한 지능형 Copilot (Brain, 설계/검증 보조)
>
> **주의**: Lightspeed는 "실행"이 아니라 "작성 보조" 역할

### 🔄 EDA + Lightspeed 통합 시나리오

```
┌─────────────────────────────────────────────────────────────────┐
│  1. 장애 발생 (예: HTTPD 서비스 오류)                            │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  2. EDA 감지 → ITSM 티켓 자동 생성 + 기초 조치 Playbook 실행     │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  3. 복구 Playbook 없거나 수정 필요 시                            │
│     → Lightspeed에 자연어 프롬프트:                              │
│       "이 문제를 해결하는 플레이북을 만들어줘"                    │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  4. Lightspeed가 해결 코드 자동 생성 → 검토 후 실행              │
└─────────────────────────────────────────────────────────────────┘
```

### 🛠️ Lightspeed 주요 기능

| 기능 | 설명 | 예시 프롬프트 |
|------|------|---------------|
| **플레이북 생성** | 자연어로 Playbook 초안 작성 | "Nginx 설치하고 시작하는 플레이북 만들어줘" |
| **에러 분석** | 로그 분석 후 수정안 제시 | "이 에러를 어떻게 해결할 수 있어?" |
| **리팩터링** | 복잡한 로직 개선 제안 | "이 플레이북을 더 효율적으로 바꿔줘" |

### ⚠️ AI 검증 프로세스

> [!warning] 핵심 원칙
> **"AI 판단을 맹신하지 말고, 설명 가능한 신뢰 체계를 갖출 것"**

| 단계 | 설명 |
|------|------|
| 1. 생성 | Lightspeed가 Playbook/Rulebook 초안 생성 |
| 2. 검토 | 운영자가 제안된 코드 리뷰 (환각 가능성 체크) |
| 3. 승인 | 확인 후 생성 버튼 클릭 |
| 4. 테스트 | Dry-run 또는 Staging 환경에서 검증 |
| 5. 적용 | 프로덕션 배포 |

> [!tip] Lightspeed 장점
> 레드햇이 검증한 자동화 모범 사례로 학습되어, 범용 AI보다 Ansible 관련 정확도가 높음

---

## 5. 설정 스니펫

### 📝 Webhook 알림 스크립트 (Managed Node)

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

### 📝 Workflow Job Template (여러 Playbook 순차 실행)

> [!tip] 워크플로우 활용
> 하나의 이벤트로 여러 Playbook을 순차 실행하려면 **Workflow Job Template** 사용

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  진단       │ →  │  복구       │ →  │  검증       │
│  Playbook   │     │  Playbook   │     │  Playbook   │
└─────────────┘     └─────────────┘     └─────────────┘
      │                   │                   │
      ↓                   ↓                   ↓
   성공/실패 분기      조건부 실행         알림 전송
```

**장점**: 복잡한 문제 해결 과정을 단일 이벤트로 자동화

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
          text: "{{ service_name }} on {{ target_host }} 자동 복구 완료"
```

---

## 6. 트러블슈팅 가이드

### 🔧 문제 해결

| 증상 | 원인 | 해결 방법 |
|------|------|-----------|
| 이벤트 수신 안됨 (404/500/Timeout) | 방화벽 차단, 잘못된 포트 | 포트 5000 인바운드 허용, URL 경로 확인 |
| Rulebook 로드 실패 | YAML 문법 오류, 들여쓰기 | `ansible-rulebook --check` 로 검증 |
| Playbook 실행 안됨 | Controller 연결 실패, 인증 오류 | API 토큰 및 네트워크 확인 |
| 조건 매칭 안됨 | 이벤트 페이로드 구조 불일치 | `debug` 액션으로 실제 페이로드 확인 |
| 중복 실행 | 이벤트 중복 발생 | throttle 설정 또는 debounce 로직 추가 |

### 💻 디버깅 명령어

```bash
# EDA Rulebook 검증
ansible-rulebook --check -r watchdog_rulebook.yml

# EDA 로그 확인
podman logs eda-controller

# 실시간 이벤트 모니터링
ansible-rulebook -r rulebook.yml --verbose
```

---

## 7. 운영 체크리스트

### ✅ 배포 전 필수 점검

#### 1. 네트워크

- [ ] EDA ↔ Controller 통신: API 포트(443) 도달 가능
- [ ] Webhook 포트 개방: 인바운드 5000 허용
- [ ] Managed Node → EDA: 아웃바운드 허용

#### 2. 인증/권한

- [ ] EDA Controller API 토큰 발급 및 적용
- [ ] ServiceAccount 권한 확인 (RBAC)

#### 3. 모니터링

- [ ] EDA 이벤트 로그 수집 설정
- [ ] 알림 채널 연동 (Slack, PagerDuty 등)

#### 4. 고가용성

- [ ] EDA Controller 이중화 (Active-Standby)
- [ ] 장애 시 Fallback 플레이북 준비

#### 5. 보안

- [ ] Webhook 엔드포인트 인증 적용
- [ ] 민감 정보 Vault/Secret 저장

---

## 8. 도입 시 고려사항

### 🎯 도입 전 3대 준비 영역

> [!note] Red Hat Summit 2026 권장사항

| 영역 | 점검 항목 |
|------|-----------|
| **인프라 준비 상태** | 기존 인프라와 AI 워크로드가 잘 연결되고 최적화되어 있는가? |
| **실시간 대응 체계** | 이벤트 발생 시 사람이 아닌 시스템이 실시간으로 대응/복구 가능한가? |
| **신뢰성 확보** | AI/자동화의 판단을 설명할 수 있고 신뢰할 수 있는 환경인가? |

### 🧪 PoC 검증 시나리오 (권장)

| 시나리오 | 흐름 |
|----------|------|
| **자가 치유 (Self-healing)** | 장애 발생 → 자동 티켓 생성 → 복구 Playbook 실행 |
| **리소스 최적화** | 클라우드 불필요 리소스 감지 → 자동 축소/종료 |
| **디스크 용량 부족** | 모니터링 감지 → ITSM 티켓 → 디스크 증설 → 티켓 종료 |

### 🔄 기존 Tower/AWX에서 마이그레이션

```
┌─────────────────┐     ┌─────────────────────────┐     ┌─────────────────┐
│  Ansible Tower  │ →  │  Automation Controller  │ →  │  + EDA 추가     │
│  (레거시)        │     │  (Tower 기능 업그레이드)  │     │  (이벤트 자동화) │
└─────────────────┘     └─────────────────────────┘     └─────────────────┘
```

> [!info] 마이그레이션 경로
> 기존 Ansible Tower → Automation Controller로 전환 후, EDA를 추가하여 이벤트 기반 자동화 구현
> **기존 Playbook 자산 그대로 재활용 가능** (트리거만 이벤트 기반으로 변경)

### 🎯 자동 조치 범위 정의

> [!warning] 중요
> 모든 것을 자동화하면 안 됨. **자동화할 작업**과 **수동 승인 필요한 작업** 명확히 구분

| 자동화 권장 | 수동 승인 권장 |
|-------------|----------------|
| 서비스 재시작 | 데이터 삭제/마이그레이션 |
| 로그 정리 | 프로덕션 배포 |
| 스케일 아웃 | 방화벽 정책 변경 |
| 캐시 초기화 | 사용자 계정 관련 조치 |

### ⚠️ 주의사항

- **무한 루프 방지**: 이벤트 → 조치 → 이벤트 반복 주의
- **Circuit Breaker**: 연속 실패 시 자동화 중단 로직
- **감사 로그**: 모든 자동 조치 이력 기록 필수

---

## 9. 실제 도입 사례 및 ROI

### 📊 글로벌 도입 성과 (Red Hat Summit 2026 발표)

| 기업 | 지표 | 성과 |
|------|------|------|
| **Bancolombia** (콜롬비아 금융) | MTTR (평균 복구 시간) | **90% 이상 단축** |
| | 자동 해결 비율 | **40% 이상 증가** |
| **스페인 보험사** | 서비스 중단 (Downtime) | **50% 감소** |
| **전체 평균** | 운영 효율성 | **10% 이상 증가** |

### 🎯 ROI 측정 지표

| 지표 | 측정 방법 | 기대 효과 |
|------|-----------|-----------|
| **MTTR** | 장애 발생 ~ 복구 완료 시간 | 분 단위 → 초 단위 |
| **자동 해결 비율** | (자동 해결 건수 / 전체 장애 건수) × 100 | 수동 개입 감소 |
| **Downtime** | 서비스 불가용 시간 누적 | SLA 준수율 향상 |
| **인시 절감** | 운영자 수동 작업 시간 감소 | 고부가가치 업무 집중 |

### 💡 도입 효과 요약

> [!success] 핵심 가치
> - **속도**: 실시간 대응으로 장애 영향 최소화
> - **일관성**: 사람 실수 제거, 표준화된 대응
> - **확장성**: 노드 수 증가에도 운영 부담 동일
> - **비용**: 인건비 절감 + 다운타임 비용 절감

---

## 📚 참고 자료

### 공식 문서

- [Red Hat AAP EDA Documentation](https://access.redhat.com/documentation/en-us/red_hat_ansible_automation_platform)
- [Ansible Rulebook Reference](https://ansible.readthedocs.io/projects/rulebook/)

### Red Hat Summit 2026 Korea 세션

- **Track B-4**: 자동화 가속화 - 가상화를 위한 Ansible Automation Platform
- **Track B-5**: 지능형 자동화로 운영 효율성 달성
- [YouTube 플레이리스트](https://www.youtube.com/watch?v=a-A3klpGpDE&list=PLvPkYsISg2ZNL8gHbOcoYTKqgUxLHriFI)

### 관련 주제

- [[Prometheus Alertmanager 설정]]
- [[Ansible Automation Platform 구성]]
- [[Ansible Lightspeed 활용]]
- [[KEDA_쿠버네티스_이벤트기반_오토스케일링]] (K8s Pod 스케일링은 이 문서 참고)
