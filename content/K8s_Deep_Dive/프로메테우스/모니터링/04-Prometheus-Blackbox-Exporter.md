---
title: Prometheus Blackbox Exporter - 외부 관점 모니터링
tags:
  - Prometheus
  - Blackbox
  - Monitoring
  - ExternalMonitoring
aliases:
  - BlackboxExporter
  - 블랙박스모니터링
date: 2025-12-09
category: K8s_Deep_Dive/프로메테우스/모니터링
status: 완성
priority: 높음
---

# Prometheus Blackbox Exporter

## 📌 핵심 개념
블랙박스 = **내부를 모르는 상태에서 외부에서 테스트**

## 🔄 화이트박스 vs 블랙박스

| 구분 | 화이트박스 | 블랙박스 |
|------|-----------|---------|
| **관점** | 서버 내부 | 사용자 외부 |
| **확인 내용** | CPU, 메모리, 프로세스 | 접속 가능 여부 |
| **도구** | Node Exporter, MySQL Exporter | Blackbox Exporter |
| **질문** | "서버 건강한가?" | "사용자가 쓸 수 있나?" |

## 🎯 Blackbox Exporter의 역할

### 동작 방식
```bash
# 15초마다 자동으로 실행
curl https://example.com
ping example.com
nc -zv example.com 443

# 결과를 메트릭으로 변환
probe_success 1
probe_duration_seconds 0.234
```

### 왜 prefix가 probe_인가?
```
일반 Exporter:
mysql_up → MySQL 1개 모니터링

Blackbox Exporter:
probe_success{target="example.com"} 1
probe_success{target="api.example.com"} 1
probe_success{target="payment.com"} 0

→ "조사(probe)" 결과들
→ 1개의 Exporter가 여러 타겟 검사
```

## ✅ 유용한 경우

### 1. 외부 사용자 관점 모니터링
```
상황: 서버는 정상인데 사용자는 접속 안 됨

내부 모니터링:
✅ CPU: 30%
✅ 메모리: 정상
✅ 애플리케이션: Running

블랙박스:
❌ probe_success 0
→ 방화벽/DNS/로드밸런서 문제 발견!
```

### 2. 외부 의존성 모니터링
```yaml
# 우리가 의존하는 외부 서비스
- targets:
  - https://payment-api.pg.com  # 결제 API
  - https://map-api.example.com # 지도 API
  - https://cdn.example.com     # CDN
```

### 3. 멀티 리전 체크
```
서울 Blackbox → 서울 서버: 50ms ✅
도쿄 Blackbox → 서울 서버: 80ms ✅
미국 Blackbox → 서울 서버: 500ms ❌
→ 미국 사용자 경험 나쁨 (CDN 필요)
```

### 4. SSL 인증서 만료 감지
```yaml
# Alert 설정
- alert: SSLCertExpiringSoon
  expr: probe_ssl_earliest_cert_expiry - time() < 86400 * 7
  annotations:
    summary: "SSL 인증서 7일 후 만료!"
```

## ❌ 불필요한 경우

### 1. 내부 마이크로서비스
```
❌ 나쁜 사용:
Service A → Blackbox → Service B

✅ 더 나은 방법:
- Kubernetes Liveness Probe
- Service Mesh (Istio) 메트릭
- 직접 /metrics 스크랩
```

### 2. 상세 분석이 필요할 때
```
블랙박스로 알 수 있는 것:
✅ 접속 되나? (Yes/No)
✅ 응답시간? (0.5초)

알 수 없는 것:
❌ 어느 API가 느린가?
❌ 어떤 쿼리가 문제인가?
❌ 메모리 누수가 있나?

→ APM/Logs/Traces 필요
```

## 🔧 ConfigMap이 필요한 이유

### 다양한 검사 방식
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: blackbox-config
data:
  blackbox.yml: |
    modules:
      # HTTP 200 체크
      http_2xx:
        prober: http
        timeout: 5s
        http:
          valid_status_codes: [200]

      # HTTPS + SSL 체크
      http_2xx_with_ssl:
        prober: http
        http:
          fail_if_not_ssl: true

      # TCP 포트 체크
      tcp_connect:
        prober: tcp
        timeout: 5s

      # ICMP Ping
      icmp:
        prober: icmp
```

### 왜 복잡한가?
```
MySQL Exporter: 1개 Exporter = 1개 MySQL
Blackbox Exporter: 1개 Exporter = 여러 타겟 + 여러 방식

→ 재사용성은 높지만 설정이 복잡함
```

## 📊 트레이드오프 분석

| 항목 | 장점 ✅ | 단점 ❌ |
|------|--------|--------|
| 관점 | 사용자 경험 그대로 | 원인 파악 어려움 |
| 설정 | 간단 (URL만) | 복잡한 시나리오 제한 |
| 의존성 | 앱 수정 불필요 | 깊은 분석 불가 |
| 범위 | 외부 서비스 가능 | 인증 필요시 복잡 |
| 비용 | 가벼움 | 자주 체크 시 트래픽 비용 |

## 🎨 실무 패턴

### 패턴 1: 레이어드 모니터링 (추천)
```
[Layer 1] Blackbox - 빠른 장애 감지
→ 30초마다 체크
→ 죽으면 즉시 알람

[Layer 2] 화이트박스 - 상세 분석
→ CPU, 메모리, 로그
→ 원인 파악

예시:
1. Blackbox: "api.example.com 응답 없음!" (30초)
2. Prometheus: "Pod 재시작 중" (원인)
3. Logs: "OutOfMemory Error" (근본 원인)
```

### 패턴 2: Critical Path만 체크
```
✅ 핵심만:
/health (전체 서비스)
/api/orders (매출 직결)
/api/payments (결제)

❌ 모든 엔드포인트 (비효율)
```

### 패턴 3: 외부 vs 내부 분리
```yaml
# 외부 노출 서비스 → 블랙박스
- targets:
  - https://www.example.com
  - https://api.example.com

# 내부 서비스 → 직접 스크랩
- targets:
  - http://order-service:8080/metrics
```

## 🚀 실전 설정 예시

### 최소 ConfigMap
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: blackbox-config
data:
  blackbox.yml: |
    modules:
      http_2xx:
        prober: http
        timeout: 5s
        http:
          valid_http_versions: ["HTTP/1.1", "HTTP/2.0"]
          method: GET
          fail_if_not_ssl: true
```

### Prometheus 설정
```yaml
scrape_configs:
- job_name: 'blackbox'
  metrics_path: /probe
  params:
    module: [http_2xx]
  static_configs:
  - targets:
    - https://example.com
    - https://api.example.com
  relabel_configs:
  - source_labels: [__address__]
    target_label: __param_target
  - target_label: __address__
    replacement: blackbox-exporter:9115
```

## 🔗 연관 개념
- [[01-Exporter-개념]] - Exporter 기본 이해
- [[08-Istio-모니터링-통합]] - Istio와 Blackbox 통합
- [[06-모니터링-트레이드오프]] - 도입 결정 기준

## 💡 핵심 철학
> **"서버가 살아있다" ≠ "사용자가 쓸 수 있다"**
>
> 블랙박스는 이 간극을 메워주는 도구입니다.

## 📚 더 읽어보기
- [Prometheus Blackbox Exporter 공식 문서](https://github.com/prometheus/blackbox_exporter)
- [Blackbox Exporter Configuration Examples](https://github.com/prometheus/blackbox_exporter/tree/master/example)
