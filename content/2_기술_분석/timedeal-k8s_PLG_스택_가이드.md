---
title: timedeal-k8s PLG 스택 가이드 - Prometheus + Loki + Grafana
tags:
  - kubernetes
  - k3d
  - prometheus
  - loki
  - grafana
  - promtail
  - monitoring
  - helm
  - observability
aliases:
  - PLG 스택
  - 모니터링 스택
date: 2026-02-14
category: 2_기술_분석/쿠버네티스
status: 완성
priority: 높음
---

# 🎯 timedeal-k8s PLG 스택 가이드

> [!note] 핵심 목표
> k3d 로컬 클러스터에 PLG 스택(Prometheus + Loki + Grafana)을 경량 설치하여, Go stock-service의 메트릭과 로그를 Grafana 대시보드 한 곳에서 확인한다.

## 📑 목차
- [[#1. 개요와 구성|개요와 구성]]
- [[#2. 사전 조건|사전 조건]]
- [[#3. 설치 절차|설치 절차]]
- [[#4. Grafana 접속 및 사용법|Grafana 사용법]]
- [[#5. 주요 쿼리 모음|주요 쿼리 모음]]
- [[#6. 리소스 현황|리소스 현황]]
- [[#7. 관리 명령어|관리 명령어]]
- [[#8. 트러블슈팅|트러블슈팅]]

### 📋 관련 문서
- [[timedeal-k8s_프로젝트_현황]] - 프로젝트 전체 현황
- [[k3d_EKS_찍먹_가이드_타임딜_사가패턴]] - k3d 클러스터 구축 가이드

---

## 1. 개요와 구성

### 💡 PLG 스택이란?

**P**rometheus + **L**oki + **G**rafana의 조합으로, Grafana Labs 생태계 기반의 풀스택 옵저버빌리티 솔루션.

```
┌─────────────────────────────────────────────────────┐
│  Grafana (대시보드)                                   │
│  ┌───────────────────┐  ┌─────────────────────┐      │
│  │ Prometheus 패널   │  │ Loki 패널            │      │
│  │ - CPU/메모리 차트 │  │ - Pod 로그 스트림    │      │
│  │ - RPS 그래프      │  │ - 에러 필터링        │      │
│  │ - Pod 상태        │  │ - 키워드 검색        │      │
│  └────────┬──────────┘  └──────────┬──────────┘      │
│           │                        │                  │
│     ┌─────▼─────┐           ┌──────▼──────┐          │
│     │Prometheus │           │    Loki     │          │
│     │메트릭 수집 │           │ 로그 저장   │          │
│     └─────┬─────┘           └──────▲──────┘          │
│           │                        │                  │
│  ┌────────▼────────┐     ┌────────┴────────┐         │
│  │ node-exporter   │     │   Promtail      │         │
│  │ kube-state-     │     │   (DaemonSet)   │         │
│  │ metrics         │     │   로그 수집/전송  │         │
│  └─────────────────┘     └─────────────────┘         │
└─────────────────────────────────────────────────────┘
```

### 📊 컴포넌트 역할

| 컴포넌트 | Helm 차트 | 역할 | 리소스 |
|----------|-----------|------|--------|
| Prometheus | `kube-prometheus-stack` | 메트릭 수집 (CPU, 메모리, RPS 등) | ~350Mi |
| Grafana | `kube-prometheus-stack` 포함 | 대시보드 시각화 | ~250Mi |
| Loki | `grafana/loki` | 로그 저장 백엔드 (SingleBinary) | ~210Mi |
| Promtail | `grafana/promtail` | 노드별 Pod 로그 수집 → Loki 전송 | ~50Mi/노드 |
| node-exporter | `kube-prometheus-stack` 포함 | 노드 하드웨어 메트릭 | ~10Mi/노드 |
| kube-state-metrics | `kube-prometheus-stack` 포함 | K8s 오브젝트 상태 메트릭 | ~40Mi |

---

## 2. 사전 조건

| 항목 | 필요 | 현재 |
|------|------|------|
| k3d 클러스터 | 노드 1개 이상 | k3d-timedeal (server 1 + agent 2) |
| Helm | v3+ | 설치됨 |
| 가용 메모리 | ~800Mi 이상 | ~3.8GB 가용 |
| Helm 리포 | prometheus-community, grafana | 등록됨 |

```bash
# Helm 리포 등록 (최초 1회)
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
```

---

## 3. 설치 절차

### 🔧 Step 1. 네임스페이스 생성

```bash
kubectl create namespace monitoring
```

### 🔧 Step 2. kube-prometheus-stack 설치

Prometheus + Grafana + node-exporter + kube-state-metrics를 한 번에 설치.

```bash
helm install prom prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set alertmanager.enabled=false \
  --set grafana.adminPassword=admin \
  --set prometheus.prometheusSpec.retention=6h \
  --set prometheus.prometheusSpec.resources.requests.cpu=100m \
  --set prometheus.prometheusSpec.resources.requests.memory=256Mi \
  --set prometheus.prometheusSpec.resources.limits.memory=512Mi \
  --set grafana.resources.requests.cpu=50m \
  --set grafana.resources.requests.memory=128Mi \
  --set grafana.resources.limits.memory=256Mi \
  --set prometheus-node-exporter.resources.requests.cpu=10m \
  --set prometheus-node-exporter.resources.requests.memory=32Mi \
  --set kube-state-metrics.resources.requests.cpu=10m \
  --set kube-state-metrics.resources.requests.memory=32Mi \
  --set prometheusOperator.resources.requests.cpu=50m \
  --set prometheusOperator.resources.requests.memory=64Mi
```

> [!info] 경량화 포인트
> - `alertmanager.enabled=false` → 로컬에서 알림 불필요
> - `retention=6h` → 로컬이니까 메트릭 6시간만 보존
> - 모든 컴포넌트에 리소스 요청/제한 설정 → 맥북에어 부담 최소화

### 🔧 Step 3. Loki 설치 (SingleBinary 경량 모드)

values 파일 생성 후 설치:

```yaml
# /tmp/loki-values.yaml
deploymentMode: SingleBinary
loki:
  auth_enabled: false
  commonConfig:
    replication_factor: 1
  storage:
    type: filesystem
  schemaConfig:
    configs:
      - from: "2024-01-01"
        store: tsdb
        object_store: filesystem
        schema: v13
        index:
          prefix: loki_index_
          period: 24h
singleBinary:
  replicas: 1
  resources:
    requests:
      cpu: 50m
      memory: 128Mi
    limits:
      memory: 256Mi
read:
  replicas: 0
write:
  replicas: 0
backend:
  replicas: 0
gateway:
  enabled: false
chunksCache:
  enabled: false
resultsCache:
  enabled: false
minio:
  enabled: false
```

```bash
helm install loki grafana/loki \
  --namespace monitoring \
  -f /tmp/loki-values.yaml
```

> [!info] SingleBinary 모드
> read/write/backend를 분리하지 않고 단일 Pod가 모든 역할 수행. 로컬 환경에서 리소스를 최소화하는 핵심 설정.

### 🔧 Step 4. Promtail 설치

```yaml
# /tmp/promtail-values.yaml
config:
  clients:
    - url: http://loki:3100/loki/api/v1/push
resources:
  requests:
    cpu: 20m
    memory: 64Mi
  limits:
    memory: 128Mi
```

```bash
helm install promtail grafana/promtail \
  --namespace monitoring \
  -f /tmp/promtail-values.yaml
```

> [!tip] DaemonSet
> Promtail은 DaemonSet으로 배포되어 각 노드마다 1개 Pod가 뜬다. 3노드 클러스터 = Promtail 3개.

### 🔧 Step 5. Grafana에 Loki 데이터소스 등록

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: loki-datasource
  namespace: monitoring
  labels:
    grafana_datasource: "1"
data:
  loki-datasource.yaml: |
    apiVersion: 1
    datasources:
      - name: Loki
        type: loki
        access: proxy
        url: http://loki:3100
        isDefault: false
        editable: true
EOF
```

Grafana Pod 재시작으로 sidecar가 새 데이터소스를 로딩:

```bash
kubectl rollout restart deployment prom-grafana -n monitoring
kubectl rollout status deployment prom-grafana -n monitoring --timeout=120s
```

> [!info] 왜 ConfigMap?
> Grafana의 sidecar 컨테이너(`grafana-sc-datasources`)가 `grafana_datasource: "1"` 라벨이 붙은 ConfigMap을 자동으로 감지하여 데이터소스로 등록한다. Grafana UI에서 수동 추가해도 되지만, Pod 재시작 시 날아가므로 ConfigMap 방식이 영속적.

---

## 4. Grafana 접속 및 사용법

### 🔧 접속

```bash
kubectl port-forward svc/prom-grafana 3000:80 -n monitoring
```

- URL: `http://localhost:3000`
- 계정: `admin` / `admin`

### 📋 데이터소스 확인

접속 후 **Connections → Data sources**에서 3개 확인:

| 데이터소스 | 타입 | URL | 용도 |
|-----------|------|-----|------|
| Prometheus | prometheus | `http://prom-kube-prometheus-stack-prometheus.monitoring:9090/` | 메트릭 |
| Loki | loki | `http://loki:3100` | 로그 |
| Alertmanager | alertmanager | (비활성화됨) | - |

### 📋 Explore에서 쿼리하기

1. 좌측 메뉴 → **Explore**
2. 상단 데이터소스 드롭다운 선택:
   - **Prometheus** → 메트릭 쿼리 (PromQL)
   - **Loki** → 로그 쿼리 (LogQL)
3. 쿼리 입력 → **Run query**

> [!warning] Builder vs Code 모드
> Explore에서 "Builder" 모드가 기본인 경우 라벨 자동완성이 안 될 수 있다. 우측 상단 **Code** 버튼을 눌러 직접 쿼리를 타이핑하면 확실하다.

### 📋 기본 내장 대시보드

kube-prometheus-stack에 기본 포함된 대시보드:

| 대시보드 | 확인 내용 |
|----------|---------|
| Kubernetes / Compute Resources / Namespace (Pods) | Pod별 CPU/메모리 사용량 |
| Kubernetes / Compute Resources / Node (Pods) | 노드별 리소스 분배 |
| Kubernetes / Networking / Namespace (Pods) | 네트워크 트래픽 |
| Node Exporter / Nodes | 노드 하드웨어 메트릭 |

대시보드에서 namespace를 `timedeal`로 필터링하면 stock-service 리소스를 볼 수 있다.

---

## 5. 주요 쿼리 모음

### 📊 Prometheus (PromQL)

```promql
# 전체 타겟 상태 확인
up

# timedeal 네임스페이스 Pod CPU 사용률
sum(rate(container_cpu_usage_seconds_total{namespace="timedeal"}[5m])) by (pod)

# timedeal 네임스페이스 Pod 메모리 사용량
sum(container_memory_working_set_bytes{namespace="timedeal"}) by (pod)

# stock-service Pod 재시작 횟수
kube_pod_container_status_restarts_total{namespace="timedeal", container="stock"}

# 노드별 전체 메모리 사용률 (%)
100 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes * 100)
```

### 📊 Loki (LogQL)

```logql
# timedeal 네임스페이스 전체 로그
{namespace="timedeal"}

# stock-service 로그만
{namespace="timedeal", container="stock"}

# 에러 키워드 필터
{namespace="timedeal"} |= "error"

# 특정 API 호출 로그
{namespace="timedeal"} |= "/api/stock/reserve"

# 최근 로그 속도 (초당 로그 라인)
rate({namespace="timedeal"}[1m])
```

---

## 6. 리소스 현황

> 2026-02-14 22:00 기준, 설치 직후 측정

### 📊 monitoring 네임스페이스 Pod 목록

| Pod | Ready | 메모리 | 역할 |
|-----|-------|--------|------|
| prometheus-prom-...-prometheus-0 | 2/2 | ~348Mi | 메트릭 수집/저장 |
| prom-grafana-... | 3/3 | ~249Mi | 대시보드 (+ sidecar 2개) |
| loki-0 | 2/2 | ~207Mi | 로그 저장 |
| prom-kube-prometheus-stack-operator-... | 1/1 | ~21Mi | CRD 관리 |
| prom-kube-state-metrics-... | 1/1 | ~43Mi | K8s 상태 메트릭 |
| prom-prometheus-node-exporter-... (x3) | 1/1 | ~10Mi | 노드 메트릭 |
| promtail-... (x3) | 1/1 | ~50Mi | 로그 수집 |
| loki-canary-... (x3) | 1/1 | ~15Mi | Loki 헬스체크 |

### 📊 총 리소스 추가량

| 항목 | 설치 전 | 설치 후 | 증가분 |
|------|---------|---------|--------|
| Pod 수 | 11개 | 25개 | +14개 |
| 메모리 | ~952Mi | ~2,036Mi | ~1,084Mi |
| 가용 메모리 | ~3.8GB | ~2.7GB | 여유 충분 |

---

## 7. 관리 명령어

### 🔧 상태 확인

```bash
# Pod 전체 상태
kubectl get pods -n monitoring

# Helm 릴리스 목록
helm list -n monitoring

# 리소스 사용량
kubectl top pods -n monitoring
```

### 🔧 삭제 (역순)

```bash
# Promtail 삭제
helm uninstall promtail -n monitoring

# Loki 삭제
helm uninstall loki -n monitoring

# kube-prometheus-stack 삭제
helm uninstall prom -n monitoring

# CRD 정리 (선택)
kubectl delete crd prometheuses.monitoring.coreos.com
kubectl delete crd servicemonitors.monitoring.coreos.com
kubectl delete crd alertmanagers.monitoring.coreos.com

# 네임스페이스 삭제
kubectl delete namespace monitoring
```

### 🔧 업그레이드

```bash
helm repo update
helm upgrade prom prometheus-community/kube-prometheus-stack -n monitoring
helm upgrade loki grafana/loki -n monitoring -f /tmp/loki-values.yaml
helm upgrade promtail grafana/promtail -n monitoring -f /tmp/promtail-values.yaml
```

---

## 8. 트러블슈팅

### 🚨 Grafana Explore에서 Loki 쿼리가 안 나올 때

> **증상**: `{namespace="timedeal"}` 쿼리 → "Empty results"
> **원인**: Builder 모드에서 라벨 자동완성 미지원 또는 시간 범위 부족
> **해결**:
> 1. **Code 모드**로 전환 (우측 상단 Code 버튼)
> 2. 시간 범위를 **Last 1 hour** 이상으로 확장
> 3. 직접 `{namespace="timedeal"}` 타이핑 후 Run query

### 🚨 Loki에 데이터가 있는지 CLI로 확인

```bash
# Loki 라벨 값 확인
kubectl run curl-check -n monitoring --rm -i --restart=Never \
  --image=curlimages/curl -- \
  curl -s 'http://loki:3100/loki/api/v1/label/namespace/values'
# → {"status":"success","data":["kube-system","monitoring","timedeal"]}
```

### 🚨 Promtail이 로그를 못 보내는 경우

```bash
# Promtail 로그 확인
kubectl logs -l app.kubernetes.io/name=promtail -n monitoring --tail=20

# Loki 서비스 연결 확인
kubectl run curl-loki -n monitoring --rm -i --restart=Never \
  --image=curlimages/curl -- curl -s http://loki:3100/ready
# → ready
```

### 🚨 Grafana Pod가 CrashLoop인 경우

```bash
# Grafana 로그 확인
kubectl logs -l app.kubernetes.io/name=grafana -n monitoring -c grafana --tail=30

# 리소스 부족 확인
kubectl describe pod -l app.kubernetes.io/name=grafana -n monitoring | grep -A5 "Events"

# 메모리 limit 증가
helm upgrade prom prometheus-community/kube-prometheus-stack -n monitoring \
  --set grafana.resources.limits.memory=512Mi
```

### 🚨 Prometheus 메트릭이 안 보이는 경우

```bash
# Prometheus 타겟 상태 확인
kubectl port-forward svc/prom-kube-prometheus-stack-prometheus 9090:9090 -n monitoring
# → http://localhost:9090/targets 에서 DOWN 타겟 확인
```
좋아요! Claude Code가 만든 문서가 거의 완성됐네요. 제가 추가로 정리해드릴게요.

---

## 추가할 내용: 실습 터미널 로그 정리

### 설치 결과 요약

```bash
# 최종 Pod 상태
kubectl get pods -n monitoring
```

```
NAME                                     READY   STATUS    RESTARTS   AGE
loki-0                                   2/2     Running   0          12m
loki-canary-58g9c                        1/1     Running   0          12m
loki-canary-c2hwl                        1/1     Running   0          12m
loki-canary-xk9fp                        1/1     Running   0          12m
prom-grafana-679c695c5b-t6skc            3/3     Running   0          5m
prom-kube-state-metrics-xxx              1/1     Running   0          15m
prom-prometheus-node-exporter-xxx        1/1     Running   0          15m
prometheus-prom-kube-prometheus-xxx-0    2/2     Running   0          15m
promtail-92pzr                           1/1     Running   0          10m
promtail-h7kkw                           1/1     Running   0          10m
promtail-xm2lp                           1/1     Running   0          10m
```

### 리소스 사용량

```bash
kubectl top nodes
```

```
NAME                    CPU(cores)   CPU(%)   MEMORY(bytes)   MEMORY(%)
k3d-timedeal-agent-0    1395m        17%      508Mi           12%
k3d-timedeal-agent-1    xxx          xx%      xxxMi           xx%
k3d-timedeal-server-0   xxx          xx%      xxxMi           xx%
```

---

## 검증 체크리스트

| 항목 | 상태 | 확인 방법 |
|------|------|----------|
| Prometheus 타겟 | ✅ | Explore → Prometheus → `up` 쿼리 |
| Loki 데이터소스 | ✅ | Data source health check OK |
| timedeal 로그 수집 | ✅ | label/namespace/values에 timedeal 존재 |
| Grafana 대시보드 | ✅ | Kubernetes / Compute Resources 확인 |

---

## 빠른 접속 명령어

```bash
# Grafana 접속
kubectl port-forward svc/prom-grafana 3000:80 -n monitoring

# 브라우저
open http://localhost:3000
# ID: admin / PW: admin
```

---

## 부하 테스트 + 모니터링 연동

```bash
# 터미널 1: Grafana 접속
kubectl port-forward svc/prom-grafana 3000:80 -n monitoring

# 터미널 2: 부하 테스트
hey -z 30s -c 100 -m POST \
  -H "Content-Type: application/json" \
  -d '{"product_id":1}' \
  http://localhost:8080/api/stock/get

# Grafana에서 실시간 확인
# → Dashboards → Kubernetes / Compute Resources / Namespace (Pods)
# → namespace: timedeal 선택
```
