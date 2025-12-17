# Grafana + Loki 클라우드 엔지니어 실습 가이드

> **실습 환경**: Kubernetes 1.30.4 (1 Control Plane + 3 Workers)
> **목표**: 프로덕션급 로그 모니터링 스택 구축 및 운영 실습

---

## 📚 목차

1. [환경 개요](#환경-개요)
2. [Loki 설치](#loki-설치)
3. [Promtail 설치](#promtail-설치)
4. [Grafana 설정](#grafana-설정)
5. [LogQL 쿼리 실습](#logql-쿼리-실습)
6. [대시보드 구축](#대시보드-구축)
7. [트러블슈팅](#트러블슈팅)

---

## 🏗️ 환경 개요

### 클러스터 구성
```
Control Plane: cp-k8s (192.168.1.10)
Worker Nodes:
  - w1-k8s (192.168.1.101)
  - w2-k8s (192.168.1.102)
  - w3-k8s (192.168.1.103)
```

### 아키텍처
```
┌─────────────────────────────────────────────┐
│             Grafana (UI)                    │
│         http://192.168.1.10:30000           │
└─────────────────┬───────────────────────────┘
                  │ (쿼리)
┌─────────────────▼───────────────────────────┐
│              Loki (로그 저장)                │
│            Port: 3100                       │
└─────────────────▲───────────────────────────┘
                  │ (푸시)
┌─────────────────┴───────────────────────────┐
│         Promtail (로그 수집 Agent)           │
│     각 노드에서 DaemonSet으로 실행            │
│   - /var/log 수집                           │
│   - Pod 로그 수집                            │
└─────────────────────────────────────────────┘
```

### 핵심 개념
- **Loki**: "Logs for Prometheus" - 레이블 기반 로그 집계 시스템
- **Promtail**: 각 노드에서 로그 파일을 읽고 Loki로 전송하는 에이전트
- **LogQL**: Loki의 쿼리 언어 (PromQL과 유사)

---

## 📦 Loki 설치

### 1단계: Loki 배포 파일 생성

```yaml
# loki-deployment.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: logging
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: loki-config
  namespace: logging
data:
  loki.yaml: |
    auth_enabled: false

    server:
      http_listen_port: 3100
      grpc_listen_port: 9096

    common:
      path_prefix: /loki
      storage:
        filesystem:
          chunks_directory: /loki/chunks
          rules_directory: /loki/rules
      replication_factor: 1
      ring:
        kvstore:
          store: inmemory

    schema_config:
      configs:
        - from: 2020-10-24
          store: boltdb-shipper
          object_store: filesystem
          schema: v11
          index:
            prefix: index_
            period: 24h

    limits_config:
      reject_old_samples: true
      reject_old_samples_max_age: 168h
      ingestion_rate_mb: 10
      ingestion_burst_size_mb: 20
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: loki
  namespace: logging
spec:
  replicas: 1
  selector:
    matchLabels:
      app: loki
  template:
    metadata:
      labels:
        app: loki
    spec:
      containers:
      - name: loki
        image: grafana/loki:2.9.3
        args:
          - -config.file=/etc/loki/loki.yaml
        ports:
        - containerPort: 3100
          name: http
        - containerPort: 9096
          name: grpc
        volumeMounts:
        - name: config
          mountPath: /etc/loki
        - name: storage
          mountPath: /loki
        resources:
          requests:
            cpu: 100m
            memory: 256Mi
          limits:
            cpu: 500m
            memory: 1Gi
      volumes:
      - name: config
        configMap:
          name: loki-config
      - name: storage
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: loki
  namespace: logging
spec:
  type: ClusterIP
  ports:
  - port: 3100
    targetPort: 3100
    name: http
  - port: 9096
    targetPort: 9096
    name: grpc
  selector:
    app: loki
```

### 2단계: Loki 배포

```bash
# Control Plane에 접속
vagrant ssh cp-k8s-1.30.4

# Loki 배포
kubectl apply -f loki-deployment.yaml

# 배포 확인
kubectl get pods -n logging
kubectl get svc -n logging

# 로그 확인
kubectl logs -n logging -l app=loki
```

**예상 출력:**
```
NAME                    READY   STATUS    RESTARTS   AGE
loki-xxxxxxxxxx-xxxxx   1/1     Running   0          30s
```

---

## 🔍 Promtail 설치

### Promtail이란?
- **역할**: 각 Kubernetes 노드에서 로그 파일을 읽고 Loki로 전송
- **배포 방식**: DaemonSet (모든 노드에 1개씩)
- **수집 대상**:
  - `/var/log` 시스템 로그
  - `/var/log/pods` Kubernetes Pod 로그

### 1단계: Promtail 배포 파일

```yaml
# promtail-daemonset.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: promtail
  namespace: logging
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: promtail
rules:
- apiGroups: [""]
  resources:
  - nodes
  - nodes/proxy
  - services
  - endpoints
  - pods
  verbs: ["get", "watch", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: promtail
subjects:
- kind: ServiceAccount
  name: promtail
  namespace: logging
roleRef:
  kind: ClusterRole
  name: promtail
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: promtail-config
  namespace: logging
data:
  promtail.yaml: |
    server:
      http_listen_port: 9080
      grpc_listen_port: 0

    positions:
      filename: /tmp/positions.yaml

    clients:
      - url: http://loki:3100/loki/api/v1/push

    scrape_configs:
      # Pod 로그 수집
      - job_name: kubernetes-pods
        kubernetes_sd_configs:
        - role: pod
        relabel_configs:
        - source_labels: [__meta_kubernetes_pod_node_name]
          target_label: node
        - source_labels: [__meta_kubernetes_namespace]
          target_label: namespace
        - source_labels: [__meta_kubernetes_pod_name]
          target_label: pod
        - source_labels: [__meta_kubernetes_pod_container_name]
          target_label: container
        - replacement: /var/log/pods/*$1/*.log
          separator: /
          source_labels:
          - __meta_kubernetes_pod_uid
          - __meta_kubernetes_pod_container_name
          target_label: __path__
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: promtail
  namespace: logging
spec:
  selector:
    matchLabels:
      app: promtail
  template:
    metadata:
      labels:
        app: promtail
    spec:
      serviceAccountName: promtail
      containers:
      - name: promtail
        image: grafana/promtail:2.9.3
        args:
          - -config.file=/etc/promtail/promtail.yaml
        volumeMounts:
        - name: config
          mountPath: /etc/promtail
        - name: varlog
          mountPath: /var/log
          readOnly: true
        - name: varlibdockercontainers
          mountPath: /var/lib/docker/containers
          readOnly: true
        resources:
          requests:
            cpu: 50m
            memory: 128Mi
          limits:
            cpu: 200m
            memory: 256Mi
      volumes:
      - name: config
        configMap:
          name: promtail-config
      - name: varlog
        hostPath:
          path: /var/log
      - name: varlibdockercontainers
        hostPath:
          path: /var/lib/docker/containers
```

### 2단계: Promtail 배포

```bash
# Promtail 배포
kubectl apply -f promtail-daemonset.yaml

# 배포 확인 (4개 노드에 각각 배포)
kubectl get pods -n logging -l app=promtail -o wide

# 로그 수집 확인
kubectl logs -n logging -l app=promtail --tail=20
```

**예상 출력:**
```
NAME             READY   STATUS    NODE
promtail-xxxxx   1/1     Running   cp-k8s
promtail-yyyyy   1/1     Running   w1-k8s
promtail-zzzzz   1/1     Running   w2-k8s
promtail-wwwww   1/1     Running   w3-k8s
```

---

## 📊 Grafana 설정

### Grafana 접속

```bash
# Grafana 서비스 확인
kubectl get svc -n monitoring grafana

# NodePort로 접속 (브라우저에서)
# http://192.168.1.10:<NodePort>
# 기본 계정: admin / admin
```

### Loki 데이터소스 추가

1. **Grafana 로그인**
2. **Configuration (⚙️) → Data Sources → Add data source**
3. **Loki 선택**
4. **설정:**
   ```
   Name: Loki
   URL: http://loki.logging.svc.cluster.local:3100
   ```
5. **Save & Test** 클릭

✅ 성공 시: "Data source connected and labels found" 메시지

---

## 🔎 LogQL 쿼리 실습

### LogQL 기본 문법

```logql
# 1. 레이블 선택 (Log Stream Selector)
{namespace="kube-system"}

# 2. 레이블 필터링
{namespace="kube-system", pod=~"coredns.*"}

# 3. 로그 라인 필터 (Line Filter)
{namespace="kube-system"} |= "error"
{namespace="kube-system"} |~ "error|warn"

# 4. 집계 (Aggregation)
sum(rate({namespace="kube-system"}[5m]))

# 5. 파싱 (JSON)
{namespace="kube-system"} | json | level="error"
```

### 실습 쿼리

#### 쿼리 1: 모든 네임스페이스의 로그
```logql
{namespace=~".+"}
```

#### 쿼리 2: 에러 로그만 필터링
```logql
{namespace=~".+"} |~ "(?i)error|exception|fatal"
```

#### 쿼리 3: 특정 Pod의 로그
```logql
{namespace="logging", pod=~"loki.*"}
```

#### 쿼리 4: 시간당 로그 발생률
```logql
sum(rate({namespace="kube-system"}[1h])) by (pod)
```

#### 쿼리 5: 로그 레벨별 카운트
```logql
sum by (level) (count_over_time({namespace="kube-system"} | json | __error__="" [5m]))
```

### Explore 실습

1. **Grafana → Explore (나침반 아이콘)**
2. **Data Source: Loki 선택**
3. **위 쿼리들을 하나씩 실행해보기**
4. **시간 범위 조정**: Last 15 minutes → Last 1 hour
5. **Live 모드 활성화**: 우측 상단 "Live" 버튼

---

## 📈 대시보드 구축

### 기본 대시보드 만들기

1. **Create → Dashboard → Add new panel**
2. **Data Source: Loki 선택**

### 패널 1: 실시간 로그 스트림
```
Query: {namespace=~".+"}
Visualization: Logs
```

### 패널 2: 네임스페이스별 로그 발생률
```
Query: sum(rate({namespace=~".+"}[5m])) by (namespace)
Visualization: Time series
```

### 패널 3: 에러 로그 카운트
```
Query: sum(count_over_time({namespace=~".+"}|~"(?i)error"[5m]))
Visualization: Stat
```

### 패널 4: Pod별 로그 분포
```
Query: topk(10, sum(rate({namespace=~".+"}[5m])) by (pod))
Visualization: Bar chart
```

### 변수(Variables) 추가

1. **Dashboard Settings (⚙️) → Variables → Add variable**
2. **설정:**
   ```
   Name: namespace
   Type: Query
   Data source: Loki
   Query: label_values(namespace)
   ```

3. **패널에서 사용:**
   ```logql
   {namespace="$namespace"}
   ```

---

## 🧪 실전 실습

### 실습 1: 테스트 로그 생성

```bash
# 테스트 Pod 생성
kubectl run test-logger --image=busybox --restart=Never -- sh -c 'while true; do echo "$(date) - Test log entry"; sleep 2; done'

# 로그 확인
kubectl logs test-logger -f

# Grafana Explore에서 확인
{pod="test-logger"}
```

### 실습 2: 에러 로그 시뮬레이션

```bash
# 에러 로그 생성
kubectl run error-simulator --image=busybox --restart=Never -- sh -c 'for i in $(seq 1 100); do echo "ERROR: Failed to connect to database"; sleep 1; done'

# Grafana에서 쿼리
{pod="error-simulator"} |= "ERROR"
```

### 실습 3: 멀티 Pod 로그 집계

```bash
# 3개의 테스트 Pod 생성
for i in {1..3}; do
  kubectl run app-$i --image=busybox --restart=Never -- sh -c 'while true; do echo "App-'$i': Processing request"; sleep 1; done'
done

# 전체 로그 조회
{pod=~"app-.*"}

# 집계 쿼리
sum(rate({pod=~"app-.*"}[1m])) by (pod)
```

---

## 🛠️ 트러블슈팅

### 문제 1: Loki에 데이터가 없음

**증상:**
```
No data found
```

**해결:**
```bash
# Loki 상태 확인
kubectl logs -n logging -l app=loki

# Promtail이 로그를 푸시하는지 확인
kubectl logs -n logging -l app=promtail | grep "POST /loki/api/v1/push"

# Loki API 직접 확인
kubectl exec -n logging -it deploy/loki -- wget -O- http://localhost:3100/ready
```

### 문제 2: Promtail이 로그를 수집하지 않음

**해결:**
```bash
# Promtail 상태 확인
kubectl describe pod -n logging -l app=promtail

# 수집 중인 파일 확인
kubectl logs -n logging <promtail-pod-name> | grep "filepath"

# 권한 확인
kubectl get clusterrolebinding promtail
```

### 문제 3: Grafana에서 Loki 연결 실패

**해결:**
```bash
# Loki 서비스 DNS 확인
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup loki.logging.svc.cluster.local

# Loki 접근 테스트
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- curl http://loki.logging.svc.cluster.local:3100/ready
```

---

## 📚 추가 학습 자료

### Loki 공식 문서
- [Loki Documentation](https://grafana.com/docs/loki/latest/)
- [LogQL Syntax](https://grafana.com/docs/loki/latest/logql/)

### 모범 사례
1. **레이블 설계**: 카디널리티를 낮게 유지 (네임스페이스, Pod 이름 등)
2. **보존 정책**: 오래된 로그 자동 삭제 설정
3. **리소스 제한**: Loki/Promtail에 적절한 메모리 할당
4. **인덱스 최적화**: 자주 쿼리하는 레이블만 인덱싱

### 실전 시나리오
- **장애 대응**: 에러 로그 급증 시 알림 설정
- **성능 분석**: 느린 API 호출 패턴 분석
- **보안 모니터링**: 인증 실패 로그 추적
- **비용 최적화**: 불필요한 로그 필터링

---

## ✅ 체크리스트

- [ ] Loki 배포 완료
- [ ] Promtail DaemonSet 4개 노드 배포 확인
- [ ] Grafana에서 Loki 데이터소스 연결
- [ ] 기본 LogQL 쿼리 5개 이상 실행
- [ ] 커스텀 대시보드 생성 (최소 3개 패널)
- [ ] 테스트 로그 생성 및 확인
- [ ] 변수(Variables)를 사용한 동적 대시보드 구성

---

**작성일**: 2025-12-17
**실습 환경**: Kubernetes 1.30.4, Grafana 10.x, Loki 2.9.3
