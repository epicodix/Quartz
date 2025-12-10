---
title: Exporter 사용 시나리오 - 언제 필요한가?
tags:
  - Prometheus
  - Kubernetes
  - Monitoring
  - Exporter
  - DevOps
aliases:
  - Exporter사용시나리오
  - Exporter판단기준
date: 2025-12-09
category: K8s_Deep_Dive/프로메테우스/모니터링
status: 완성
priority: 높음
---

# Exporter 사용 시나리오

## ✅ Exporter가 필요한 경우

### 1. 레거시/전통적인 애플리케이션
Prometheus 이전 시대에 만들어진 소프트웨어

| 카테고리 | 예시 | 이유 |
|---------|------|------|
| 데이터베이스 | MySQL, PostgreSQL, MongoDB, Redis | 각자의 프로토콜로 상태 제공 |
| 메시지 큐 | RabbitMQ, Kafka (구버전) | Prometheus 형식 미지원 |
| 웹서버 | Nginx, Apache | 상태 페이지는 있지만 형식 다름 |
| 시스템 | Node Exporter | OS는 Prometheus를 모름 |

### 확인 방법
```bash
# 애플리케이션 실행 후
curl http://localhost:포트/metrics

# 404 에러 또는 다른 형식 → Exporter 필요
# Prometheus 형식 → Exporter 불필요
```

## ❌ Exporter가 불필요한 경우

### 1. 최신 클라우드 네이티브 애플리케이션
처음부터 `/metrics` 엔드포인트 내장

| 카테고리 | 예시 |
|---------|------|
| Kubernetes | kube-apiserver, kubelet, etcd |
| 서비스 메시 | Istio, Linkerd |
| 모니터링 도구 | Prometheus, Grafana |
| 최신 프레임워크 | Go apps, Spring Boot (Actuator) |

### 2. 직접 개발하는 애플리케이션
```python
# Python 예시: 코드에 직접 구현
from prometheus_client import Counter, start_http_server

request_count = Counter('app_requests_total', 'Total requests')

@app.route('/api')
def api():
    request_count.inc()
    return "OK"

start_http_server(8000)  # /metrics 자동 제공
```

## 🎯 판단 기준 체크리스트

```
□ 소프트웨어가 Prometheus 이전 시대 제품인가?
  → Yes: Exporter 필요

□ /metrics 엔드포인트가 있는가?
  → Yes: Exporter 불필요

□ Prometheus 공식 Exporter 목록에 있는가?
  → Yes: 원래 앱은 메트릭 없음

□ 직접 개발하는 코드인가?
  → Yes: 라이브러리로 직접 구현 추천
```

## 💼 실무 사례

### MySQL 모니터링
```yaml
# MySQL Exporter 필요
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mysql-exporter
spec:
  template:
    spec:
      containers:
      - name: exporter
        image: prom/mysqld-exporter
        env:
        - name: DATA_SOURCE_NAME
          value: "user:pass@tcp(mysql:3306)/"
```

### Kubernetes 자체 모니터링
```yaml
# Exporter 불필요 - 직접 스크랩
- job_name: 'kubernetes-apiservers'
  kubernetes_sd_configs:
  - role: endpoints
  # kube-apiserver가 이미 /metrics 제공
```

## 🔗 연관 개념
- [[01-Exporter-개념]] - Exporter가 무엇인가?
- [[05-Prometheus-실무-활용]] - 실제 유용성 판단
- [[06-모니터링-트레이드오프]] - 도입 결정 기준

## 💡 핵심 원칙
> "그 소프트웨어가 태어난 시대"를 보라
> - Prometheus 이전 → Exporter 필요
> - Prometheus 이후 → 내장 지원
