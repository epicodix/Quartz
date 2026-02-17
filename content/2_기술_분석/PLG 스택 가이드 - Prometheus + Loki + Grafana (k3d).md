# 🔍 PLG 스택 가이드 - Prometheus + Loki + Grafana (k3d)

## 📑 목차
- [[#1. 개요|개요]]
- [[#2. 설치 과정|설치 과정]]
- [[#3. Grafana 접속 및 사용|Grafana 사용]]
- [[#4. 주요 쿼리 예시|쿼리 예시]]
- [[#5. 트러블슈팅|트러블슈팅]]
- [[#6. CS 개념 정리|CS 개념]]

> [!info] 관련 문서
> - [[k3d_EKS_찍먹_가이드_타임딜_사가패턴]]

---

## 1. 개요

### PLG 스택이란?

```
PLG = Prometheus + Loki + Grafana

┌─────────────────────────────────────────────────────────┐
│                     Grafana (시각화)                    │
│                 http://localhost:3000                   │
└──────────────┬────────────────────────┬─────────────────┘
               │                        │
               ▼                        ▼
┌──────────────────────┐    ┌──────────────────────┐
│     Prometheus       │    │        Loki          │
│     (메트릭 수집)     │    │     (로그 수집)       │
│   CPU, 메모리, RPS   │    │   Pod 로그, 에러     │
└──────────┬───────────┘    └──────────┬───────────┘
           │                           │
           ▼                           ▼
┌──────────────────────┐    ┌──────────────────────┐
│   node-exporter      │    │      Promtail        │
│   kube-state-metrics │    │    (DaemonSet)       │
│   (메트릭 노출)       │    │   (로그 전송)        │
└──────────────────────┘    └──────────────────────┘
```

### 왜 필요한가?

| 상황 | 해결책 |
|------|--------|
| Pod가 왜 죽었지? | Loki에서 로그 검색 |
| CPU 사용량이 높은 Pod는? | Prometheus 메트릭 |
| 부하 테스트 중 성능 변화? | Grafana 대시보드 실시간 관찰 |
| HPA가 제대로 동작하나? | Grafana에서 Pod 수 변화 확인 |

---

## 2. 설치 과정

### 2.1 네임스페이스 생성

```bash
kubectl create namespace monitoring
```

### 2.2 kube-prometheus-stack 설치

```bash
# Helm 리포 업데이트
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# 설치 (경량 옵션)
helm install prom prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set alertmanager.enabled=false \
  --set grafana.adminPassword=admin \
  --set prometheus.prometheusSpec.retention=6h \
  --set prometheus.prometheusSpec.resources.requests.memory=256Mi \
  --set prometheus.prometheusSpec.resources.requests.cpu=100m
```

```
# 결과
NAME: prom
LAST DEPLOYED: Sat Feb 14 21:54:41 2026
NAMESPACE: monitoring
STATUS: deployed
```

> [!info] kube-prometheus-stack 포함 컴포넌트
> - **Prometheus**: 메트릭 수집/저장
> - **Grafana**: 시각화 대시보드
> - **node-exporter**: 노드 메트릭 (DaemonSet)
> - **kube-state-metrics**: K8s 오브젝트 메트릭

### 2.3 Loki 설치

```bash
# Helm 리포 추가
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# values 파일 생성
cat > /tmp/loki-values.yaml << 'EOF'
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
          prefix: index_
          period: 24h
singleBinary:
  replicas: 1
  resources:
    requests:
      cpu: 100m
      memory: 256Mi
read:
  replicas: 0
write:
  replicas: 0
backend:
  replicas: 0
gateway:
  enabled: false
minio:
  enabled: false
EOF

# 설치
helm install loki grafana/loki \
  --namespace monitoring \
  -f /tmp/loki-values.yaml
```

```
# 결과
NAME: loki
LAST DEPLOYED: Sat Feb 14 21:56:20 2026
NAMESPACE: monitoring
STATUS: deployed
```

### 2.4 Promtail 설치

```bash
# values 파일 생성
cat > /tmp/promtail-values.yaml << 'EOF'
config:
  clients:
    - url: http://loki:3100/loki/api/v1/push
EOF

# 설치
helm install promtail grafana/promtail \
  --namespace monitoring \
  -f /tmp/promtail-values.yaml
```

```
# 결과
NAME: promtail
LAST DEPLOYED: Sat Feb 14 21:56:35 2026
NAMESPACE: monitoring
STATUS: deployed
```

> [!info] Promtail 역할
> - 각 노드에 DaemonSet으로 배포
> - `/var/log/pods/` 경로에서 모든 Pod 로그 수집
> - Loki로 전송

### 2.5 Grafana에 Loki 데이터소스 추가

```bash
cat << 'EOF' | kubectl apply -f -
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

# Grafana 재시작하여 데이터소스 로딩
kubectl rollout restart deployment prom-grafana -n monitoring
```

### 2.6 설치 확인

```bash
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

### 2.7 리소스 사용량

```bash
kubectl top pods -n monitoring
```

```
NAME                                     CPU(cores)   MEMORY(bytes)
loki-0                                   13m          165Mi
prom-grafana-xxx                         4m           174Mi
prom-kube-state-metrics-xxx              2m           30Mi
prometheus-prom-kube-prometheus-xxx-0    26m          384Mi
promtail-xxx                             6m           48Mi (x3)
```

**총 사용량: ~1,000Mi 메모리**

---

## 3. Grafana 접속 및 사용

### 3.1 접속

```bash
kubectl port-forward svc/prom-grafana 3000:80 -n monitoring
```

```
http://localhost:3000
ID: admin
PW: admin
```

### 3.2 Prometheus 메트릭 조회

1. 좌측 메뉴 → **Explore**
2. 상단 데이터소스 → **Prometheus** 선택
3. 쿼리 입력:

```promql
# 모든 타겟 상태
up

# 특정 네임스페이스 Pod CPU
sum(rate(container_cpu_usage_seconds_total{namespace="timedeal"}[5m])) by (pod)

# 메모리 사용량
sum(container_memory_usage_bytes{namespace="timedeal"}) by (pod)
```

### 3.3 Loki 로그 조회

1. 좌측 메뉴 → **Explore**
2. 상단 데이터소스 → **Loki** 선택
3. 쿼리 입력:

```logql
# timedeal 네임스페이스 전체 로그
{namespace="timedeal"}

# stock-service 로그만
{namespace="timedeal", app="stock-service"}

# 에러 로그만
{namespace="timedeal"} |= "error"

# Reserve 로그만
{namespace="timedeal"} |= "[Reserve]"
```

### 3.4 기본 제공 대시보드

1. 좌측 메뉴 → **Dashboards**
2. 검색: "Kubernetes / Compute Resources"
3. 네임스페이스 필터 → `timedeal` 선택

**주요 대시보드:**
- Kubernetes / Compute Resources / Namespace (Pods)
- Kubernetes / Compute Resources / Node (Pods)
- Node Exporter / Nodes

---

## 4. 주요 쿼리 예시

### Prometheus (메트릭)

```promql
# Pod 재시작 횟수
kube_pod_container_status_restarts_total{namespace="timedeal"}

# HPA 현재 replica 수
kube_horizontalpodautoscaler_status_current_replicas{namespace="timedeal"}

# 요청 처리량 (RPS) - 메트릭 노출 시
rate(http_requests_total{namespace="timedeal"}[1m])

# 노드별 CPU 사용률
100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)
```

### Loki (로그)

```logql
# 최근 에러 로그
{namespace="timedeal"} |= "error" | json

# 특정 시간대 로그
{namespace="timedeal"} |= "[Reserve]"

# 로그 카운트 (시간별)
count_over_time({namespace="timedeal"}[5m])

# 특정 product_id 로그
{namespace="timedeal"} |~ "product.*=.*1"
```

---

## 5. 트러블슈팅

### Loki에서 로그가 안 보일 때

```bash
# 1. Promtail이 돌고 있는지 확인
kubectl get pods -n monitoring -l app.kubernetes.io/name=promtail

# 2. Promtail 로그 확인
kubectl logs -n monitoring -l app.kubernetes.io/name=promtail --tail=20

# 3. Loki에 timedeal 라벨이 있는지 확인
kubectl run curl-loki -n monitoring --rm -i --restart=Never \
  --image=curlimages/curl -- \
  curl -s 'http://loki:3100/loki/api/v1/label/namespace/values'
```

**결과에 `timedeal`이 있어야 정상:**
```json
{
  "status": "success",
  "data": ["kube-system", "monitoring", "timedeal"]
}
```

### Grafana에서 데이터소스 연결 실패

```bash
# 데이터소스 목록 확인
kubectl run curl-grafana -n monitoring --rm -i --restart=Never \
  --image=curlimages/curl -- \
  curl -s -u admin:admin 'http://prom-grafana:80/api/datasources'

# Loki 연결 테스트
kubectl run curl-grafana2 -n monitoring --rm -i --restart=Never \
  --image=curlimages/curl -- \
  curl -s -u admin:admin 'http://prom-grafana:80/api/datasources/uid/loki/health'
```

### Pod 상태 확인

```bash
# 전체 상태
kubectl get pods -n monitoring

# 특정 Pod 로그
kubectl logs -n monitoring <pod-name>

# Pod 재시작
kubectl rollout restart deployment prom-grafana -n monitoring
```

---

## 6. CS 개념 정리

### 6.1 Prometheus

> [!note] 정의
> 시계열(time-series) 메트릭 수집 및 저장 시스템. Pull 방식으로 타겟에서 메트릭을 가져옴.

**핵심 개념:**
- **메트릭 타입**: Counter, Gauge, Histogram, Summary
- **Pull 방식**: Prometheus가 주기적으로 타겟에서 수집
- **PromQL**: 메트릭 쿼리 언어

```
수집 흐름:
Pod (metrics endpoint) ←── Prometheus (scrape) → 저장 → Grafana (시각화)
```

### 6.2 Loki

> [!note] 정의
> 로그 집계 시스템. Prometheus와 유사한 라벨 기반 인덱싱. 로그 내용은 인덱싱하지 않아 경량.

**핵심 개념:**
- **라벨 기반**: `{namespace="timedeal", app="stock-service"}`
- **LogQL**: 로그 쿼리 언어 (PromQL과 유사)
- **경량**: 메타데이터만 인덱싱, 로그 원문은 압축 저장

### 6.3 Promtail

> [!note] 정의
> Loki의 로그 수집 에이전트. DaemonSet으로 각 노드에 배포되어 Pod 로그를 Loki로 전송.

```
Pod 로그 → /var/log/pods/ → Promtail(수집) → Loki(저장) → Grafana(조회)
```

### 6.4 DaemonSet

> [!note] 정의
> 클러스터의 모든 노드(또는 지정된 노드)에 Pod를 하나씩 배포하는 컨트롤러.

**용도:**
- 로그 수집 (Promtail, Fluentd)
- 모니터링 에이전트 (node-exporter)
- 네트워크 플러그인 (kube-proxy)

```
노드 3개 = DaemonSet Pod 3개 (각 노드에 1개씩)
```

### 6.5 메트릭 vs 로그

| | 메트릭 (Prometheus) | 로그 (Loki) |
|--|---------------------|-------------|
| 형태 | 숫자 (시계열) | 텍스트 |
| 용도 | 성능 추이, 알림 | 디버깅, 에러 추적 |
| 예시 | CPU 80%, RPS 1000 | "[Error] connection refused" |
| 쿼리 | PromQL | LogQL |

---

## 7. 전체 아키텍처

```
k3d 클러스터 (timedeal)
│
├── Namespace: timedeal
│   ├── stock-service (Deployment, 2-4 replicas)
│   ├── postgres (StatefulSet)
│   └── HPA (자동 스케일링)
│
├── Namespace: monitoring
│   ├── Prometheus (메트릭 수집)
│   ├── Loki (로그 수집)
│   ├── Grafana (시각화)
│   ├── Promtail (DaemonSet, 로그 전송)
│   ├── node-exporter (DaemonSet, 노드 메트릭)
│   └── kube-state-metrics (K8s 메트릭)
│
└── Ingress (Traefik)
    └── localhost:8080 → stock-service
```

---

## 8. 정리 명령어

```bash
# PLG 스택 삭제
helm uninstall promtail -n monitoring
helm uninstall loki -n monitoring
helm uninstall prom -n monitoring
kubectl delete namespace monitoring

# 또는 클러스터 전체 삭제
k3d cluster delete timedeal
```

---

> [!success] PLG 스택 설치 완료!
> - Prometheus: 메트릭 수집 ✅
> - Loki: 로그 수집 ✅
> - Grafana: 시각화 대시보드 ✅
> - Promtail: 로그 전송 에이전트 ✅