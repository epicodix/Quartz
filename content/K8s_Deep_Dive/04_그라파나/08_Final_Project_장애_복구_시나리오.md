# 08. [Final Project] 장애 복구 시뮬레이션

> **학습 목표**: 실제 운영 환경과 유사한 **'결제 서비스(Payment Service)'**를 구축하고, 의도적으로 장애를 유발한 뒤 대시보드와 로그를 분석하여 복구하는 전체 과정을 경험합니다.
> **선수 지식**: [[07_통합_모니터링_시스템_구축]]

---

## 🏗️ 1. 시뮬레이션 환경 구축

우리는 이제 단순한 로그 생성기가 아닌, **상태(State)**와 **설정(Config)**을 가진 진짜 애플리케이션을 배포합니다.

### 1-1. Payment Service 배포

기존 `log-generator`가 있다면 삭제하고 새로운 서비스를 배포합니다.

```bash
# 기존 파드 삭제
kubectl delete deploy log-generator

# Payment Service 배포
kubectl apply -f payment-service.yaml
```

이 서비스는 `/etc/config/config.json` 파일을 실시간으로 감시하며 동작 방식을 바꿉니다.

### 1-2. 모니터링 대시보드 수정

이전 실습에서 만든 **Full Stack Monitoring** 대시보드를 엽니다.
Loki 로그 패널의 쿼리를 수정하여 새 서비스의 로그를 바라보게 합니다.

```logql
# 기존: {app="log-generator"}
# 수정: {app="payment-service"}
```

---

## 🔥 2. 시나리오: 블랙 프라이데이 (Traffic Surge)

**상황**: 갑작스러운 트래픽 폭주로 인해 결제 서비스가 마비되었습니다.

### 2-1. 장애 유발 (Trigger)

트래픽은 5배로 늘리고(`traffic_speed: 5.0`), DB 연결 풀은 아주 작게(`db_pool_size: 2`) 줄여서 병목을 만듭니다.

```bash
# ConfigMap 수정하여 장애 유발
kubectl patch configmap payment-config --type merge -p '{"data":{"config.json":"{\"traffic_speed\": 5.0, \"db_pool_size\": 2, \"memory_leak\": false, \"payment_gateway_latency_ms\": 50}"}}"
```

*Tip: 이 명령어는 실제 운영 중인 서비스의 설정을 핫(Hot)하게 변경합니다. 파드를 재시작할 필요가 없습니다!*

### 2-2. 증상 관찰 (Observe)

이제 Grafana 대시보드를 확인해봅시다.

1.  **Logs Panel**: 빨간색 에러 로그가 폭포수처럼 쏟아집니다.
    *   `ERROR: [Database] ConnectionPoolExhausted: Could not acquire connection`
    *   자바(Java) 스타일의 Stack Trace가 보입니다.
2.  **Stat Panel**: Error Count가 급격히 상승하여 **Red** 상태가 됩니다.
3.  **Logs Context**: 에러 로그 주변을 보면, 성공 로그(INFO)가 거의 보이지 않습니다.

**분석 결과**:
"트래픽이 `traffic_speed` 증가로 인해 늘어났으나, `Active Connections`가 `Max` 값에 도달하여 더 이상 처리를 못 하고 있군. **DB Connection Pool 고갈**이 원인이다!"

---

## 🛠️ 3. 장애 복구 (Fix)

분석이 끝났으니 해결책을 적용합니다. DB 연결 풀을 늘려줍니다.

### 3-1. 설정 변경 (Patch)

연결 풀을 2개에서 20개로 10배 증설합니다.

```bash
# DB Pool Size 2 -> 20으로 증설
kubectl patch configmap payment-config --type merge -p '{"data":{"config.json":"{\"traffic_speed\": 5.0, \"db_pool_size\": 20, \"memory_leak\": false, \"payment_gateway_latency_ms\": 50}"}}"
```

### 3-2. 회복 확인 (Verify)

변경 후 약 5~10초 뒤(애플리케이션이 설정 파일을 다시 읽는 시간) 대시보드를 봅니다.

1.  **Logs Panel**: `ERROR` 로그가 멈추고 `INFO: Processed transaction...` 로그가 다시 흐르기 시작합니다.
2.  **Stat Panel**: 최근 1분간 에러 개수가 0으로 떨어집니다.
3.  **Slack (Alert)**: 만약 06강에서 Alert를 걸어놨다면 "Resolved" 알림이 올 것입니다.

---

## ☠️ 4. 보너스 시나리오: 메모리 누수 (The Slow Death)

이번엔 더 무서운 장애, **메모리 누수(Memory Leak)**를 체험해봅시다.

### 4-1. 장애 유발

```bash
# 메모리 누수 활성화 (True)
kubectl patch configmap payment-config --type merge -p '{"data":{"config.json":"{\"traffic_speed\": 2.0, \"db_pool_size\": 50, \"memory_leak\": true, \"payment_gateway_latency_ms\": 50}"}}"
```

### 4-2. 증상 관찰

1.  **Logs Panel**: 주기적으로 `WARN: [System] High memory usage detected` 로그가 보입니다.
2.  **Prometheus Panel**: 메모리 사용량 그래프(Gauge/Time Series)가 계단식으로 계속 올라갑니다.
3.  **결말**: 결국 파드는 Kubernetes에 의해 `OOMKilled` 당하고 재시작(Restart) 됩니다.
    *   *확인 방법*: 터미널에서 `kubectl get pods -w`로 `RESTARTS` 카운트가 올라가는지 확인.

### 4-3. 해결

코드를 고쳐야 하지만, 급한대로 설정을 끕니다.

```bash
kubectl patch configmap payment-config --type merge -p '{"data":{"config.json":"{\"traffic_speed\": 2.0, \"db_pool_size\": 50, \"memory_leak\": false, \"payment_gateway_latency_ms\": 50}"}}"
```

---

## 🎓 프로젝트 회고

여러분은 방금 **DevOps 엔지니어의 하루**를 경험했습니다.

1.  모니터링 시스템 구축 (Dashboard)
2.  이상 징후 감지 (Alerting)
3.  로그 분석을 통한 원인 규명 (RCA)
4.  설정 변경을 통한 긴급 조치 (Troubleshooting)
5.  정상화 확인 (Validation)

이 사이클을 빠르고 정확하게 수행하는 것이 SRE/DevOps의 핵심 역량입니다. 수고하셨습니다!
