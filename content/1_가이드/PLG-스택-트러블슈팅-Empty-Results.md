---
title: PLG 스택 트러블슈팅 - Empty Results 디버깅
tags:
  - troubleshooting
  - PLG
  - Grafana
  - Loki
  - Promtail
  - kubernetes
  - monitoring
aliases:
  - PLG 트러블슈팅
  - Loki Empty Results
date: 2026-02-15
category: 1_가이드/트러블슈팅
status: 완성
priority: 높음
---

# 🔍 PLG 스택 트러블슈팅 로그 - "Empty Results" 디버깅 여정

## 📑 목차
- [[#1. 상황 요약|상황 요약]]
- [[#2. 디버깅 과정|디버깅 과정]]
- [[#3. 원인 분석|원인 분석]]
- [[#4. 교훈|교훈]]
- [[#5. 유용한 디버깅 명령어 모음|디버깅 명령어]]

---

## 1. 상황 요약

| 항목 | 내용 |
|------|------|
| 증상 | Grafana에서 `{namespace="timedeal"}` 쿼리 → "Empty results" |
| 예상 원인 | Loki 설정 문제? Promtail 수집 실패? |
| 실제 원인 | **18시간 동안 API 호출이 없어서 새 로그가 없었음** 🤦 |

---

## 2. 디버깅 과정

### 💡 Step 1. Loki에 timedeal 라벨이 있는지 확인

```bash
kubectl run curl-check -n monitoring --rm -i --restart=Never \
  --image=curlimages/curl -- \
  curl -s 'http://loki:3100/loki/api/v1/label/namespace/values'
```

```json
{"status":"success","data":["kube-system","monitoring","timedeal"]}
```

> [!tip] 결과
> timedeal 라벨 존재 → Loki는 정상

---

### 💡 Step 2. Loki에서 실제 데이터 조회

```bash
kubectl run curl-loki2 -n monitoring --rm -i --restart=Never \
  --image=curlimages/curl -- \
  curl -s 'http://loki:3100/loki/api/v1/query_range?query=%7Bnamespace%3D%22timedeal%22%7D&limit=5&start=...'
```

```json
{"status":"success","data":{"resultType":"streams","result":[],...}}
```

> [!warning] 결과
> `"result":[]` → 해당 시간 범위에 데이터 없음

---

### 💡 Step 3. Promtail이 timedeal 로그를 수집하는지 확인

```bash
kubectl logs -n monitoring -l app.kubernetes.io/name=promtail --tail=50 | grep -E "(timedeal|target)"
```

> [!warning] 결과
> timedeal 관련 로그 없음 → Promtail이 수집 안 하나?

---

### 💡 Step 4. 각 노드의 Promtail에서 timedeal 로그 디렉토리 확인

```bash
for pod in $(kubectl get pods -n monitoring -l app.kubernetes.io/name=promtail -o jsonpath='{.items[*].metadata.name}'); do
  echo "=== $pod ==="
  kubectl exec -n monitoring $pod -- ls -la /var/log/pods/ 2>/dev/null | grep timedeal
done
```

```
=== promtail-92pzr ===
drwxr-xr-x ... timedeal_postgres-0_...

=== promtail-c5bgf ===
drwxr-xr-x ... timedeal_stock-service-76d9479b49-p5brn_...

=== promtail-zv2kf ===
(없음)
```

> [!tip] 결과
> stock-service 로그가 promtail-c5bgf 노드에 있음

---

### 💡 Step 5. stock-service가 어느 노드에 있는지 확인

```bash
kubectl get pods -n timedeal -o wide
```

```
NAME                             NODE
postgres-0                       k3d-timedeal-server-0
stock-service-76d9479b49-p5brn   k3d-timedeal-agent-1
```

> [!tip] 결과
> stock-service는 agent-1 노드 → promtail-c5bgf가 담당

---

### 💡 Step 6. 실제 로그 파일 내용 확인

```bash
kubectl exec -n monitoring promtail-c5bgf -- sh -c 'tail -5 /var/log/pods/timedeal_stock-service-76d9479b49-p5brn_.../stock/*.log'
```

```
2026-02-14T10:06:04... [Cancel] product=1 qty=1 released, reserved=0
2026-02-14T10:06:05... [Reserve] product=1 qty=1 reserved=1/2
...
2026-02-14T10:06:12... [Cancel] product=1 qty=1 released, reserved=0
```

> [!danger] 발견
> 로그가 **18시간 전(10:06)**에 멈춰있음!

---

### 💡 Step 7. 새 로그 발생시키기

```bash
curl -s localhost:8080/api/stock/get -d '{"product_id":1}'
curl -s localhost:8080/api/stock/reserve -d '{"product_id":1,"quantity":1}'
```

```bash
# 새 로그 확인
kubectl exec -n monitoring promtail-c5bgf -- sh -c 'tail -3 /var/log/pods/timedeal_.../stock/*.log'
```

```
2026-02-15T04:35:xx... [Reserve] product=1 qty=1 ...
```

> [!tip] 결과
> 새 로그 발생!

---

### 💡 Step 8. Grafana에서 확인

- Explore → Loki
- 시간 범위: **Last 5 minutes**
- 쿼리: `{namespace="timedeal"}`

> [!tip] 결과
> **성공!** 로그 보임!

---

## 3. 원인 분석

```
┌─────────────────────────────────────────────────────────┐
│                     문제 상황                            │
├─────────────────────────────────────────────────────────┤
│                                                         │
│   stock-service 마지막 로그: 10:06 (18시간 전)          │
│                     ↓                                   │
│   Grafana 조회 범위: Last 1 hour (최근 1시간)           │
│                     ↓                                   │
│   결과: Empty! (당연함)                                 │
│                                                         │
├─────────────────────────────────────────────────────────┤
│                     실제 상태                            │
├─────────────────────────────────────────────────────────┤
│   Promtail: ✅ 정상 (수집 대기 중)                      │
│   Loki: ✅ 정상 (저장 대기 중)                          │
│   Grafana: ✅ 정상 (조회 대기 중)                       │
│   stock-service: 😴 18시간째 API 호출 없음...           │
│                                                         │
│   → 모니터링 시스템은 정상, 모니터링할 이벤트가 없었음!  │
└─────────────────────────────────────────────────────────┘
```

---

## 4. 교훈

### 📋 "Empty results" 나오면 먼저 확인할 것

```
1순위: 시간 범위 넓히기 (Last 24h)
2순위: 실제로 이벤트가 있었는지 확인
3순위: 그 다음에 시스템 의심
```

### 📋 모니터링 테스트할 때는 부하 발생 필수

```bash
# 부하 발생시키면서 Grafana 보기
hey -z 30s -c 10 -m POST \
  -H "Content-Type: application/json" \
  -d '{"product_id":1}' \
  http://localhost:8080/api/stock/get
```

### 📋 실무에서도 흔한 실수

```
"로그 수집이 안 돼요!"
→ "서비스에 트래픽 들어가고 있어?"
→ "아... 없네요..."
→ "ㅋㅋ"
```

---

## 5. 유용한 디버깅 명령어 모음

```bash
# 1. Loki 라벨 확인
kubectl run curl-check -n monitoring --rm -i --restart=Never \
  --image=curlimages/curl -- \
  curl -s 'http://loki:3100/loki/api/v1/label/namespace/values'

# 2. 각 Promtail에서 특정 네임스페이스 로그 디렉토리 확인
for pod in $(kubectl get pods -n monitoring -l app.kubernetes.io/name=promtail -o jsonpath='{.items[*].metadata.name}'); do
  echo "=== $pod ==="
  kubectl exec -n monitoring $pod -- ls -la /var/log/pods/ 2>/dev/null | grep timedeal
done

# 3. 로그 파일 직접 확인
kubectl exec -n monitoring <promtail-pod> -- sh -c 'tail -10 /var/log/pods/<경로>/stock/*.log'

# 4. 새 로그 발생시키기
curl -s localhost:8080/api/stock/get -d '{"product_id":1}'
```

---

## ✅ 최종 상태

| 컴포넌트 | 상태 | 비고 |
|----------|------|------|
| Prometheus | ✅ 정상 | 메트릭 수집 중 |
| Loki | ✅ 정상 | 로그 저장 중 |
| Promtail | ✅ 정상 | 로그 수집 중 |
| Grafana | ✅ 정상 | 시각화 정상 |
| 사용자 | 🧠 학습 완료 | "이벤트 없으면 로그도 없다" |

---

> [!tip] 한 줄 요약
> **"모니터링 시스템 탓하기 전에, 모니터링할 게 있는지부터 확인하자"**
