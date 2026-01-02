---
title: 09_그라파나 PagerDuty 온콜 시스템 실무 가이드
tags:
  - Grafana
  - PagerDuty
  - OnCall
  - Incident-Management
  - devops
  - infrastructure
aliases:
  - 그라파나-페이저듀티
  - 온콜-시스템
  - 인시던트-관리
date: 2025-12-21
category: K8s_Deep_Dive/04_그라파나
status: 완성
priority: 높음
---

# 📟 그라파나 PagerDuty 온콜 시스템 실무 가이드

## 📑 목차
- [[#1. PagerDuty 온콜 시스템 개요|온콜 시스템 개요]]
- [[#2. 그라파나와 PagerDuty 연동|연동 설정]]
- [[#3. 인시던트 관리 전략|인시던트 관리]]
- [[#4. 온콜 로테이션 및 에스컬레이션|온콜 관리]]
- [[#5. 실전 운영 노하우|운영 노하우]]

---

## 1. PagerDuty 온콜 시스템 개요

> [!note] 핵심 개념
> PagerDuty는 인시던트 관리와 온콜 로테이션의 업계 표준으로, 자동화된 에스컬레이션과 통합 알림 관리를 제공합니다.

### 💡 PagerDuty vs 일반 알림 시스템

**🤔 질문**: "왜 슬랙이 아닌 PagerDuty를 써야 할까요?"

#### 📊 비교 분석표

| 기능 | 슬랙 알림 | PagerDuty |
|------|-----------|-----------|
| 알림 전달 | 채널 기반 | 개인 직접 전달 (SMS/전화) |
| 온콜 관리 | 수동 | 자동 로테이션 |
| 에스컬레이션 | 없음 | 다단계 자동 에스컬레이션 |
| 인시던트 추적 | 제한적 | 전문적 인시던트 관리 |
| SLA 준수 | 어려움 | 자동 SLA 모니터링 |
| 비용 | 무료 | 유료 (팀당 $19-49/월) |

#### 📋 PagerDuty 핵심 구조

> [!example] 현업 시나리오
> 1. **Critical Alert** 발생 → 즉시 온콜 엔지니어에게 전화
> 2. **5분 미응답** → 팀 리드에게 에스컬레이션
> 3. **15분 미해결** → 매니저 및 경영진까지 에스컬레이션
> 4. **해결 후** → 자동 포스트모템 프로세스 시작

---

## 2. 그라파나와 PagerDuty 연동

### 💡 연동 아키텍처

#### 💻 기본 연동 설정

```yaml
# 📊 PagerDuty 서비스 연동 ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-pagerduty-config
  namespace: monitoring
data:
  pagerduty-config.yaml: |
    contact_points:
      - name: pagerduty-critical
        type: pagerduty
        uid: pd-critical
        settings:
          integrationKey: "${PD_INTEGRATION_KEY_CRITICAL}"
          severity: critical
          component: "Kubernetes Cluster"
          group: "Infrastructure"
          class: "System Alert"
          
      - name: pagerduty-warning  
        type: pagerduty
        uid: pd-warning
        settings:
          integrationKey: "${PD_INTEGRATION_KEY_WARNING}"
          severity: warning
          component: "Application"
          group: "Platform"
```

#### 💻 Prometheus AlertManager PagerDuty 설정

```yaml
# 📊 AlertManager PagerDuty 라우팅
apiVersion: v1
kind: ConfigMap
metadata:
  name: alertmanager-pagerduty
  namespace: monitoring
data:
  alertmanager.yml: |
    global:
      pagerduty_url: 'https://events.pagerduty.com/v2/enqueue'
    
    route:
      group_by: ['alertname', 'cluster', 'service']
      group_wait: 30s
      group_interval: 5m
      repeat_interval: 12h
      receiver: 'default'
      routes:
        # Critical 알림 - 즉시 PagerDuty
        - matchers:
            - severity="critical"
          receiver: 'pagerduty-critical'
          group_wait: 10s
          repeat_interval: 5m
          
        # Database 관련 - DBA 온콜
        - matchers:
            - component="database"
            - severity=~"critical|warning"
          receiver: 'pagerduty-dba'
          
        # Security 관련 - 보안팀 즉시 알림
        - matchers:
            - team="security"
          receiver: 'pagerduty-security'
          group_wait: 0s
    
    receivers:
      - name: 'pagerduty-critical'
        pagerduty_configs:
          - routing_key: '${PD_INTEGRATION_KEY_INFRA}'
            description: '{{ .GroupLabels.alertname }}: {{ .CommonAnnotations.summary }}'
            severity: 'critical'
            details:
              cluster: '{{ .GroupLabels.cluster }}'
              namespace: '{{ .GroupLabels.namespace }}'
              pod: '{{ .GroupLabels.pod }}'
              firing_alerts: '{{ len .Alerts.Firing }}'
              resolved_alerts: '{{ len .Alerts.Resolved }}'
            links:
              - href: 'https://grafana.company.com/d/{{ .GroupLabels.dashboard_uid }}'
                text: 'Grafana Dashboard'
              - href: 'https://runbooks.company.com/{{ .GroupLabels.alertname }}'
                text: 'Runbook'
      
      - name: 'pagerduty-dba'
        pagerduty_configs:
          - routing_key: '${PD_INTEGRATION_KEY_DBA}'
            description: 'DB Alert: {{ .CommonAnnotations.summary }}'
            component: 'Database'
            group: 'DBA Team'
```

---

## 3. 인시던트 관리 전략

### 💡 심각도 분류 체계

#### 📊 인시던트 심각도 매트릭스

| 심각도 | 영향도 | 응답 시간 | 온콜 대상 | 에스컬레이션 |
|--------|--------|-----------|-----------|-------------|
| P0 (Critical) | 서비스 완전 중단 | 즉시 | 모든 온콜 엔지니어 | 5분 후 매니저 |
| P1 (High) | 주요 기능 장애 | 15분 | 해당 팀 온콜 | 30분 후 팀 리드 |
| P2 (Medium) | 성능 저하 | 1시간 | 담당 엔지니어 | 4시간 후 팀 리드 |
| P3 (Low) | 미미한 영향 | 4시간 | 업무 시간 내 | 다음 업무일 |

#### 💻 심각도별 PagerDuty 정책

```yaml
# 📊 심각도별 PagerDuty 서비스 구성
apiVersion: v1
kind: ConfigMap
metadata:
  name: pagerduty-service-config
  namespace: monitoring
data:
  services.json: |
    {
      "services": [
        {
          "name": "Production Infrastructure - P0",
          "escalation_policy": "infra-p0-escalation",
          "alert_creation": "create_alerts_and_incidents",
          "alert_grouping": "time",
          "alert_grouping_timeout": 300,
          "auto_resolve_timeout": 14400,
          "acknowledgement_timeout": 300
        },
        {
          "name": "Application Services - P1",
          "escalation_policy": "app-p1-escalation", 
          "alert_creation": "create_alerts_and_incidents",
          "alert_grouping": "intelligent",
          "auto_resolve_timeout": 3600,
          "acknowledgement_timeout": 900
        }
      ],
      "escalation_policies": [
        {
          "name": "infra-p0-escalation",
          "num_loops": 3,
          "escalation_rules": [
            {
              "escalation_delay_in_minutes": 0,
              "targets": [
                {"type": "schedule", "id": "primary-oncall-schedule"}
              ]
            },
            {
              "escalation_delay_in_minutes": 5,
              "targets": [
                {"type": "schedule", "id": "secondary-oncall-schedule"},
                {"type": "user", "id": "team-lead-user-id"}
              ]
            },
            {
              "escalation_delay_in_minutes": 15,
              "targets": [
                {"type": "user", "id": "manager-user-id"}
              ]
            }
          ]
        }
      ]
    }
```

### 💡 런북 기반 대응

#### 📋 자동화된 런북 연동

> [!example] 런북 자동 연결 시나리오
> 1. **알림 발생**: CPU 사용률 95% 초과
> 2. **PagerDuty 인시던트**: 자동으로 해당 런북 링크 첨부
> 3. **온콜 엔지니어**: 런북 가이드에 따라 즉시 대응
> 4. **자동 해결**: 가능한 경우 자동 스케일링 실행

#### 💻 런북 통합 알림 템플릿

```yaml
# 📊 런북 연동 알림 템플릿
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: runbook-integrated-alerts
  namespace: monitoring
spec:
  groups:
  - name: infrastructure.rules
    rules:
    - alert: HighCPUUsage
      expr: (100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)) > 90
      for: 5m
      labels:
        severity: critical
        team: infrastructure
        runbook_url: "https://runbooks.company.com/cpu-high-usage"
        playbook_id: "INFRA-001"
        auto_remediation: "scale_out"
      annotations:
        summary: "노드 {{ $labels.instance }} CPU 사용률 위험 수준"
        description: |
          CPU 사용률이 {{ $value }}%로 위험 수준입니다.
          
          📋 즉시 조치 사항:
          1. 현재 워크로드 확인
          2. 자동 스케일링 상태 점검  
          3. 리소스 할당 재조정 고려
          
          🔗 상세 가이드: {{ $labels.runbook_url }}
        dashboard_url: "https://grafana.company.com/d/node-overview/{{ $labels.instance }}"
        escalation_time: "5분"
```

---

## 4. 온콜 로테이션 및 에스컬레이션

### 💡 온콜 스케줄 설계

#### 📊 온콜 로테이션 패턴

| 로테이션 타입 | 주기 | 적용 팀 | 장점 | 단점 |
|---------------|------|---------|------|------|
| Weekly Rotation | 1주 | 소규모 팀 | 예측 가능 | 번아웃 위험 |
| Follow-the-Sun | 지역별 8시간 | 글로벌 팀 | 24시간 커버 | 복잡한 관리 |
| Tiered System | 1차/2차/3차 | 대규모 조직 | 전문성 활용 | 지연 가능성 |

#### 💻 PagerDuty 스케줄 설정 예시

```json
{
  "schedule": {
    "name": "Infrastructure Primary Oncall",
    "time_zone": "Asia/Seoul",
    "schedule_layers": [
      {
        "name": "Primary Layer",
        "start": "2025-01-01T09:00:00+09:00",
        "rotation_virtual_start": "2025-01-01T09:00:00+09:00",
        "rotation_turn_length_seconds": 604800,
        "users": [
          {"user": {"id": "USER1", "type": "user_reference"}},
          {"user": {"id": "USER2", "type": "user_reference"}},
          {"user": {"id": "USER3", "type": "user_reference"}},
          {"user": {"id": "USER4", "type": "user_reference"}}
        ],
        "restrictions": [
          {
            "type": "daily_restriction",
            "start_time_of_day": "09:00:00",
            "duration_seconds": 32400
          }
        ]
      },
      {
        "name": "Secondary Layer (Nights/Weekends)",
        "start": "2025-01-01T18:00:00+09:00",
        "rotation_turn_length_seconds": 604800,
        "users": [
          {"user": {"id": "SENIOR1", "type": "user_reference"}},
          {"user": {"id": "SENIOR2", "type": "user_reference"}}
        ]
      }
    ]
  }
}
```

### 💡 에스컬레이션 정책

#### 📋 다단계 에스컬레이션 전략

> [!example] 실제 에스컬레이션 시나리오
> **인시던트**: 프로덕션 DB 연결 실패 (P0)
> 
> 1. **0분**: 1차 온콜 DBA에게 즉시 알림
> 2. **5분**: 미응답 시 2차 온콜 + 팀 리드
> 3. **15분**: 미해결 시 인프라 매니저 + CTO
> 4. **30분**: 경영진 및 외부 벤더 연락

#### 💻 비즈니스 시간 기반 에스컬레이션

```yaml
# 📊 비즈니스 시간 고려 에스컬레이션 정책
apiVersion: v1
kind: ConfigMap
metadata:
  name: escalation-policy-config
  namespace: monitoring
data:
  business-hours-escalation.json: |
    {
      "escalation_policies": [
        {
          "name": "Business Hours Infrastructure",
          "description": "업무 시간 인프라 에스컬레이션 (09:00-18:00 KST)",
          "num_loops": 2,
          "escalation_rules": [
            {
              "escalation_delay_in_minutes": 0,
              "targets": [
                {
                  "type": "schedule",
                  "id": "business-hours-primary"
                }
              ]
            },
            {
              "escalation_delay_in_minutes": 10,
              "targets": [
                {
                  "type": "user",
                  "id": "team-lead-infra"
                },
                {
                  "type": "schedule", 
                  "id": "senior-engineers"
                }
              ]
            },
            {
              "escalation_delay_in_minutes": 30,
              "targets": [
                {
                  "type": "user",
                  "id": "infra-manager"
                }
              ]
            }
          ]
        },
        {
          "name": "After Hours Critical Only",
          "description": "업무 외 시간 Critical만 (18:00-09:00 KST)",
          "escalation_rules": [
            {
              "escalation_delay_in_minutes": 0,
              "targets": [
                {
                  "type": "schedule",
                  "id": "after-hours-oncall"
                }
              ]
            },
            {
              "escalation_delay_in_minutes": 15,
              "targets": [
                {
                  "type": "user",
                  "id": "senior-oncall-engineer"
                }
              ]
            }
          ]
        }
      ]
    }
```

---

## 5. 실전 운영 노하우

### 💡 인시던트 라이프사이클 관리

#### 📊 인시던트 단계별 체크리스트

| 단계 | 소요시간 | 핵심 액션 | 담당자 |
|------|----------|-----------|--------|
| Detection | 0-2분 | 모니터링 시스템 감지 | 자동화 |
| Response | 2-5분 | 온콜 엔지니어 응답 | 1차 온콜 |
| Triage | 5-15분 | 심각도 판단 및 팀 소집 | 인시던트 커맨더 |
| Mitigation | 15분-1시간 | 임시 해결책 적용 | 해당 팀 |
| Resolution | 1-4시간 | 근본 원인 해결 | 전담 팀 |
| Post-mortem | 1-3일 | 분석 및 개선책 | 인시던트 커맨더 |

#### 💻 인시던트 자동화 워크플로우

```yaml
# 📊 인시던트 자동 워크플로우
apiVersion: v1
kind: ConfigMap
metadata:
  name: incident-automation
  namespace: monitoring
data:
  automation-rules.yaml: |
    automation_actions:
      - name: "auto-scale-on-high-cpu"
        condition:
          - alert_name: "HighCPUUsage"
          - severity: "critical"
          - duration: "> 5m"
        actions:
          - type: "kubernetes_scale"
            parameters:
              deployment: "{{ .Labels.deployment }}"
              namespace: "{{ .Labels.namespace }}"
              replicas: "+2"
          - type: "pagerduty_note"
            parameters:
              message: "자동 스케일링 실행: +2 replicas"
          - type: "slack_notification"
            parameters:
              channel: "#auto-remediation"
              message: "🤖 자동 해결: {{ .Labels.deployment }} 스케일 아웃 완료"
      
      - name: "database-failover"
        condition:
          - alert_name: "DatabaseDown"
          - severity: "critical"
        actions:
          - type: "database_failover"
            parameters:
              primary: "{{ .Labels.primary_db }}"
              secondary: "{{ .Labels.secondary_db }}"
          - type: "pagerduty_escalate"
            parameters:
              escalate_to: "dba-manager"
              message: "자동 페일오버 실행, 검증 필요"
```

### 💡 팀 협업 및 커뮤니케이션

#### 📋 War Room 운영 가이드

> [!example] Critical 인시던트 War Room
> **목표**: 30분 이내 서비스 복구
> 
> **역할 분담**:
> - **인시던트 커맨더**: 전체 조율 및 의사결정
> - **기술 리드**: 기술적 문제 해결 주도  
> - **커뮤니케이션 매니저**: 이해관계자 소통
> - **스크라이브**: 타임라인 및 액션 기록

#### 💻 PagerDuty 인시던트 템플릿

```json
{
  "incident_template": {
    "title": "[{{ .severity }}] {{ .service }} - {{ .summary }}",
    "description": {
      "content": "**인시던트 개요**\n{{ .description }}\n\n**영향도**\n- 서비스: {{ .service }}\n- 사용자 영향: {{ .user_impact }}\n- 지역: {{ .region }}\n\n**초기 대응**\n1. [ ] 현재 상태 파악\n2. [ ] 우선순위 결정\n3. [ ] War Room 소집 (필요시)\n4. [ ] 이해관계자 알림\n\n**타임라인**\n{{ .start_time }} - 인시던트 시작\n\n**참고 링크**\n- [Grafana Dashboard]({{ .dashboard_url }})\n- [Runbook]({{ .runbook_url }})\n- [Status Page]({{ .status_page_url }})",
      "content_type": "text/markdown"
    },
    "escalation_policy": {
      "id": "{{ .escalation_policy_id }}"
    },
    "service": {
      "id": "{{ .service_id }}"
    },
    "priority": {
      "id": "{{ .priority_id }}"
    }
  }
}
```

### 💡 성능 및 운영 최적화

> [!tip] PagerDuty 비용 최적화
> 1. **알림 노이즈 제거**: 불필요한 알림 필터링으로 비용 절약
> 2. **인텔리전트 그룹핑**: 연관 알림 자동 그룹화
> 3. **자동 해결**: 가능한 문제 자동 복구로 인시던트 수 감소
> 4. **적절한 임계값**: False Positive 최소화

#### 💻 운영 메트릭 대시보드

```yaml
# 📊 온콜 운영 메트릭 대시보드
apiVersion: v1
kind: ConfigMap
metadata:
  name: oncall-metrics-dashboard
  namespace: monitoring
data:
  dashboard.json: |
    {
      "dashboard": {
        "title": "온콜 운영 메트릭",
        "panels": [
          {
            "title": "MTTA (Mean Time To Acknowledge)",
            "type": "stat",
            "targets": [
              {
                "expr": "avg(pagerduty_incident_acknowledge_time_seconds) / 60"
              }
            ]
          },
          {
            "title": "MTTR (Mean Time To Resolution)", 
            "type": "stat",
            "targets": [
              {
                "expr": "avg(pagerduty_incident_resolution_time_seconds) / 3600"
              }
            ]
          },
          {
            "title": "주간 인시던트 트렌드",
            "type": "timeseries",
            "targets": [
              {
                "expr": "sum(rate(pagerduty_incidents_total[7d])) by (severity)"
              }
            ]
          },
          {
            "title": "팀별 온콜 부하",
            "type": "bargauge",
            "targets": [
              {
                "expr": "sum(pagerduty_oncall_hours_total) by (team)"
              }
            ]
          }
        ]
      }
    }
```

> [!warning] 운영 고려사항
> - **Fatigue 관리**: 온콜 로테이션으로 번아웃 방지 필요
> - **False Positive 최소화**: 불필요한 알림은 신뢰도 저하 초래
> - **비용 관리**: PagerDuty는 인시던트 수에 따른 과금 구조
> - **교육 필수**: 새 팀원 대상 온콜 절차 교육 반드시 필요

---

## 📚 참고 자료

- [PagerDuty Integration Guide](https://www.pagerduty.com/docs/guides/prometheus-integration-guide/)
- [Grafana PagerDuty Contact Points](https://grafana.com/docs/grafana/latest/alerting/manage-notifications/receiver-integrations/configure-pagerduty/)
- [인시던트 관리 모범 사례](https://response.pagerduty.com/)

---

> [!info] 다음 학습  
> [[08_Final_Project_장애_복구_시나리오|최종 프로젝트: 장애 복구 시나리오]] 에서 PagerDuty를 활용한 종합적인 인시던트 관리 시스템을 구축해보겠습니다.