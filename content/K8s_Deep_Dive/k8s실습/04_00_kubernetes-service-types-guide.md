# 🚀 쿠버네티스 서비스 타입별 실습 가이드

## 📋 서비스 타입 개념 정리

### 🔗 ExternalName 서비스
외부 서비스에 대한 **DNS 별칭(CNAME)**을 제공하는 서비스
- IP 주소가 아닌 DNS 이름으로 외부 서비스에 연결
- kube-proxy에 의한 프록시 없음
- 주로 외부 데이터베이스, API 서비스 연결에 사용

### 🏠 ClusterIP 서비스 (기본값)
클러스터 **내부에서만 접근 가능**한 가상 IP를 제공
- 내부 로드밸런싱
- 파드 간 통신의 안정적인 엔드포인트 제공
- 외부에서는 접근 불가

### 👻 Headless 서비스
**ClusterIP가 None**인 서비스 (IP 할당 없음)
- DNS를 통해 개별 파드 IP 직접 반환
- StatefulSet과 함께 주로 사용
- 파드 간 직접 통신이 필요한 경우 활용

---

## 🌐 1. ExternalName 서비스 실습

### 📝 실습 시나리오
외부 MySQL 데이터베이스(db.example.com)에 대한 내부 별칭(mysql-external) 생성

### 🛠️ Step 1: ExternalName 서비스 생성

```yaml
# external-mysql-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: mysql-external
  namespace: default
spec:
  type: ExternalName
  externalName: db.example.com
  ports:
  - port: 3306
    targetPort: 3306
    protocol: TCP
```

```bash
# 서비스 생성
kubectl apply -f external-mysql-service.yaml
# service/mysql-external created

# 서비스 확인
kubectl get svc mysql-external
# NAME             TYPE           CLUSTER-IP   EXTERNAL-IP     PORT(S)    AGE
# mysql-external   ExternalName   <none>       db.example.com  3306/TCP   5s

kubectl describe svc mysql-external
# Name:              mysql-external
# Namespace:         default
# Labels:            <none>
# Annotations:       <none>
# Selector:          <none>
# Type:              ExternalName
# IP Family Policy:  SingleStack
# IP Families:       IPv4
# External Name:     db.example.com
# Port:              <unset>  3306/TCP
# TargetPort:        3306/TCP
# Endpoints:         <none>
# Session Affinity:  None
# Events:            <none>
```

### 🧪 Step 2: DNS 해석 테스트

```bash
# 테스트용 파드 생성
kubectl run test-pod --image=busybox --restart=Never -- sleep 3600
# pod/test-pod created

# 파드 내부에서 DNS 조회 테스트
kubectl exec -it test-pod -- nslookup mysql-external
# Server:		10.96.0.10
# Address:	10.96.0.10:53
# 
# mysql-external.default.svc.cluster.local	canonical name = db.example.com
# Name:	db.example.com
# Address: 93.184.216.34

kubectl exec -it test-pod -- nslookup mysql-external.default.svc.cluster.local
# Server:		10.96.0.10
# Address:	10.96.0.10:53
# 
# mysql-external.default.svc.cluster.local	canonical name = db.example.com
# Name:	db.example.com
# Address: 93.184.216.34

# 연결 테스트 (텔넷)
kubectl exec -it test-pod -- telnet mysql-external 3306
# telnet: can't connect to remote host (93.184.216.34): Connection refused
# (실제 외부 서비스가 없어서 연결 실패 - 정상)
```

### 📋 Step 3: 애플리케이션에서 사용

```yaml
# app-with-external-db.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webapp
spec:
  replicas: 2
  selector:
    matchLabels:
      app: webapp
  template:
    metadata:
      labels:
        app: webapp
    spec:
      containers:
      - name: webapp
        image: nginx
        env:
        - name: DB_HOST
          value: "mysql-external"  # ExternalName 서비스 사용
        - name: DB_PORT
          value: "3306"
        ports:
        - containerPort: 80
```

---

## 🏠 2. ClusterIP 서비스 실습

### 📝 실습 시나리오
웹 애플리케이션을 위한 내부 로드밸런서 구성

### 🛠️ Step 1: 백엔드 애플리케이션 배포

```yaml
# backend-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend-app
  labels:
    app: backend
spec:
  replicas: 3
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
    spec:
      containers:
      - name: backend
        image: nginx:alpine
        ports:
        - containerPort: 80
        env:
        - name: SERVER_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
```

```bash
# 배포 실행
kubectl apply -f backend-deployment.yaml
# deployment.apps/backend-app created

# 파드 상태 확인
kubectl get pods -l app=backend
# NAME                           READY   STATUS    RESTARTS   AGE
# backend-app-7d4b8c5f47-2j9kl   1/1     Running   0          30s
# backend-app-7d4b8c5f47-8r5m2   1/1     Running   0          30s
# backend-app-7d4b8c5f47-xp3qw   1/1     Running   0          30s

kubectl get pods -o wide -l app=backend
# NAME                           READY   STATUS    RESTARTS   AGE   IP           NODE       NOMINATED NODE   READINESS GATES
# backend-app-7d4b8c5f47-2j9kl   1/1     Running   0          45s   10.244.1.5   worker-1   <none>           <none>
# backend-app-7d4b8c5f47-8r5m2   1/1     Running   0          45s   10.244.2.3   worker-2   <none>           <none>
# backend-app-7d4b8c5f47-xp3qw   1/1     Running   0          45s   10.244.1.6   worker-1   <none>           <none>
```

### 🔗 Step 2: ClusterIP 서비스 생성

```yaml
# backend-clusterip-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: backend-service
spec:
  type: ClusterIP  # 기본값이므로 생략 가능
  selector:
    app: backend
  ports:
  - name: http
    port: 8080        # 서비스 포트
    targetPort: 80    # 컨테이너 포트
    protocol: TCP
```

```bash
# 서비스 생성
kubectl apply -f backend-clusterip-service.yaml
# service/backend-service created

# 서비스 확인
kubectl get svc backend-service
# NAME              TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
# backend-service   ClusterIP   10.96.185.123   <none>        8080/TCP   15s

kubectl describe svc backend-service
# Name:              backend-service
# Namespace:         default
# Labels:            <none>
# Annotations:       <none>
# Selector:          app=backend
# Type:              ClusterIP
# IP Family Policy:  SingleStack
# IP Families:       IPv4
# IP:                10.96.185.123
# IPs:               10.96.185.123
# Port:              http  8080/TCP
# TargetPort:        80/TCP
# Endpoints:         10.244.1.5:80,10.244.1.6:80,10.244.2.3:80
# Session Affinity:  None
# Events:            <none>

# 엔드포인트 확인
kubectl get endpoints backend-service
# NAME              ENDPOINTS                                   AGE
# backend-service   10.244.1.5:80,10.244.1.6:80,10.244.2.3:80   45s
```

### 🧪 Step 3: 서비스 연결 테스트

```bash
# 클러스터 내부에서 테스트
kubectl run test-client --image=curlimages/curl --restart=Never -it --rm -- sh
# If you don't see a command prompt, try pressing enter.
/ $ 

# 파드 내부에서 서비스 호출
curl backend-service:8080
# <!DOCTYPE html>
# <html>
# <head>
# <title>Welcome to nginx!</title>
# ...

curl backend-service.default.svc.cluster.local:8080
# <!DOCTYPE html>
# <html>
# <head>
# <title>Welcome to nginx!</title>
# ...

# 여러 번 호출하여 로드밸런싱 확인
for i in {1..5}; do curl -s backend-service:8080 | grep -i server; done
# <address>nginx/1.21.5 (backend-app-7d4b8c5f47-2j9kl)</address>
# <address>nginx/1.21.5 (backend-app-7d4b8c5f47-xp3qw)</address>
# <address>nginx/1.21.5 (backend-app-7d4b8c5f47-8r5m2)</address>
# <address>nginx/1.21.5 (backend-app-7d4b8c5f47-2j9kl)</address>
# <address>nginx/1.21.5 (backend-app-7d4b8c5f47-xp3qw)</address>
# (로드밸런싱으로 요청이 다른 파드로 분산되는 것 확인)
```

### 📊 Step 4: 포트 포워딩으로 외부 접근

```bash
# 로컬에서 서비스에 접근
kubectl port-forward svc/backend-service 8080:8080
# Forwarding from 127.0.0.1:8080 -> 80
# Forwarding from [::1]:8080 -> 80
# Handling connection for 8080

# 다른 터미널에서 테스트
curl localhost:8080
# <!DOCTYPE html>
# <html>
# <head>
# <title>Welcome to nginx!</title>
# <style>
# html { color-scheme: light dark; }
# body { width: 35em; margin: 0 auto;
# font-family: Tahoma, Verdana, Arial, sans-serif; }
# </style>
# </head>
# <body>
# <h1>Welcome to nginx!</h1>
# <p>If you can see this page, the nginx web server is successfully installed and working...</p>
# </body>
# </html>
```

---

## 👻 3. Headless 서비스 실습

### 📝 실습 시나리오
StatefulSet을 이용한 분산 데이터베이스 클러스터 구성

### 🛠️ Step 1: Headless 서비스 생성

```yaml
# mongodb-headless-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: mongodb-headless
  labels:
    app: mongodb
spec:
  clusterIP: None  # Headless 서비스의 핵심
  selector:
    app: mongodb
  ports:
  - name: mongodb
    port: 27017
    targetPort: 27017
```

```bash
# Headless 서비스 생성
kubectl apply -f mongodb-headless-service.yaml
# service/mongodb-headless created

# 서비스 확인 (CLUSTER-IP가 None인지 확인)
kubectl get svc mongodb-headless
# NAME               TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)     AGE
# mongodb-headless   ClusterIP   None         <none>        27017/TCP   10s

kubectl describe svc mongodb-headless
# Name:              mongodb-headless
# Namespace:         default
# Labels:            app=mongodb
# Annotations:       <none>
# Selector:          app=mongodb
# Type:              ClusterIP
# IP Family Policy:  SingleStack
# IP Families:       IPv4
# IP:                None
# IPs:               None
# Port:              mongodb  27017/TCP
# TargetPort:        27017/TCP
# Endpoints:         <none>
# Session Affinity:  None
# Events:            <none>
```

### 🗄️ Step 2: StatefulSet 배포

```yaml
# mongodb-statefulset.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mongodb
spec:
  serviceName: mongodb-headless  # Headless 서비스와 연결
  replicas: 3
  selector:
    matchLabels:
      app: mongodb
  template:
    metadata:
      labels:
        app: mongodb
    spec:
      containers:
      - name: mongodb
        image: mongo:5.0
        ports:
        - containerPort: 27017
        env:
        - name: MONGO_INITDB_ROOT_USERNAME
          value: "admin"
        - name: MONGO_INITDB_ROOT_PASSWORD
          value: "password"
        volumeMounts:
        - name: mongodb-storage
          mountPath: /data/db
  volumeClaimTemplates:
  - metadata:
      name: mongodb-storage
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 1Gi
```

```bash
# StatefulSet 배포
kubectl apply -f mongodb-statefulset.yaml
# statefulset.apps/mongodb created

# 파드 상태 확인
kubectl get pods -l app=mongodb
# NAME        READY   STATUS    RESTARTS   AGE
# mongodb-0   1/1     Running   0          2m15s
# mongodb-1   1/1     Running   0          1m45s
# mongodb-2   1/1     Running   0          1m15s

kubectl get statefulset mongodb
# NAME      READY   AGE
# mongodb   3/3     2m30s

# StatefulSet 상세 정보
kubectl get pods -l app=mongodb -o wide
# NAME        READY   STATUS    RESTARTS   AGE     IP           NODE       NOMINATED NODE   READINESS GATES
# mongodb-0   1/1     Running   0          3m      10.244.1.7   worker-1   <none>           <none>
# mongodb-1   1/1     Running   0          2m30s   10.244.2.4   worker-2   <none>           <none>
# mongodb-2   1/1     Running   0          2m      10.244.1.8   worker-1   <none>           <none>
```

### 🔍 Step 3: DNS 해석 테스트

```bash
# 각 파드의 FQDN 확인
kubectl get pods -l app=mongodb -o wide
# NAME        READY   STATUS    RESTARTS   AGE     IP           NODE       NOMINATED NODE   READINESS GATES
# mongodb-0   1/1     Running   0          5m      10.244.1.7   worker-1   <none>           <none>
# mongodb-1   1/1     Running   0          4m30s   10.244.2.4   worker-2   <none>           <none>
# mongodb-2   1/1     Running   0          4m      10.244.1.8   worker-1   <none>           <none>

# DNS 테스트용 파드 생성
kubectl run dns-test --image=busybox --restart=Never -- sleep 3600
# pod/dns-test created

# Headless 서비스 DNS 조회 (모든 파드 IP 반환)
kubectl exec -it dns-test -- nslookup mongodb-headless
# Server:		10.96.0.10
# Address:	10.96.0.10:53
# 
# Name:	mongodb-headless.default.svc.cluster.local
# Address: 10.244.1.7
# Name:	mongodb-headless.default.svc.cluster.local
# Address: 10.244.2.4
# Name:	mongodb-headless.default.svc.cluster.local
# Address: 10.244.1.8

# 개별 파드 DNS 조회
kubectl exec -it dns-test -- nslookup mongodb-0.mongodb-headless
# Server:		10.96.0.10
# Address:	10.96.0.10:53
# 
# Name:	mongodb-0.mongodb-headless.default.svc.cluster.local
# Address: 10.244.1.7

kubectl exec -it dns-test -- nslookup mongodb-1.mongodb-headless
# Server:		10.96.0.10
# Address:	10.96.0.10:53
# 
# Name:	mongodb-1.mongodb-headless.default.svc.cluster.local
# Address: 10.244.2.4

kubectl exec -it dns-test -- nslookup mongodb-2.mongodb-headless
# Server:		10.96.0.10
# Address:	10.96.0.10:53
# 
# Name:	mongodb-2.mongodb-headless.default.svc.cluster.local
# Address: 10.244.1.8

# FQDN으로 모든 파드 IP 확인
kubectl exec -it dns-test -- nslookup mongodb-headless.default.svc.cluster.local
# Server:		10.96.0.10
# Address:	10.96.0.10:53
# 
# Name:	mongodb-headless.default.svc.cluster.local
# Address: 10.244.1.7
# Name:	mongodb-headless.default.svc.cluster.local
# Address: 10.244.2.4
# Name:	mongodb-headless.default.svc.cluster.local
# Address: 10.244.1.8
```

### 📊 Step 4: 개별 파드 직접 접근 테스트

```bash
# MongoDB 클라이언트로 개별 노드 접근
kubectl run mongo-client --image=mongo:5.0 --restart=Never -it --rm -- bash
# If you don't see a command prompt, try pressing enter.
# root@mongo-client:/# 

# 각 MongoDB 인스턴스에 개별 연결 테스트
mongo mongodb://admin:password@mongodb-0.mongodb-headless:27017
# MongoDB shell version v5.0.15
# connecting to: mongodb://admin:password@mongodb-0.mongodb-headless:27017/
# Implicit session: session { "id" : UUID("...") }
# MongoDB server version: 5.0.15
# > 

# 연결 테스트 (ping)
kubectl exec -it dns-test -- ping mongodb-0.mongodb-headless
# PING mongodb-0.mongodb-headless.default.svc.cluster.local (10.244.1.7): 56 data bytes
# 64 bytes from 10.244.1.7: seq=0 ttl=62 time=0.123 ms
# 64 bytes from 10.244.1.7: seq=1 ttl=62 time=0.089 ms

kubectl exec -it dns-test -- ping mongodb-1.mongodb-headless  
# PING mongodb-1.mongodb-headless.default.svc.cluster.local (10.244.2.4): 56 data bytes
# 64 bytes from 10.244.2.4: seq=0 ttl=62 time=0.156 ms
# 64 bytes from 10.244.2.4: seq=1 ttl=62 time=0.102 ms

# MongoDB 포트 연결 테스트
kubectl exec -it dns-test -- telnet mongodb-0.mongodb-headless 27017
# Connected to mongodb-0.mongodb-headless.default.svc.cluster.local
# (연결 성공 확인)
```

### 🔧 Step 5: 일반 ClusterIP와 비교 실습

```yaml
# mongodb-clusterip-service.yaml (비교용)
apiVersion: v1
kind: Service
metadata:
  name: mongodb-clusterip
spec:
  type: ClusterIP
  selector:
    app: mongodb
  ports:
  - name: mongodb
    port: 27017
    targetPort: 27017
```

```bash
# ClusterIP 서비스 생성
kubectl apply -f mongodb-clusterip-service.yaml
# service/mongodb-clusterip created

# ClusterIP 서비스 확인
kubectl get svc mongodb-clusterip
# NAME                TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)     AGE
# mongodb-clusterip   ClusterIP   10.96.243.158   <none>        27017/TCP   15s

# DNS 비교 테스트
kubectl exec -it dns-test -- nslookup mongodb-clusterip
# Server:		10.96.0.10
# Address:	10.96.0.10:53
# 
# Name:	mongodb-clusterip.default.svc.cluster.local
# Address: 10.96.243.158
# (단일 가상 IP 반환)

kubectl exec -it dns-test -- nslookup mongodb-headless
# Server:		10.96.0.10
# Address:	10.96.0.10:53
# 
# Name:	mongodb-headless.default.svc.cluster.local
# Address: 10.244.1.7
# Name:	mongodb-headless.default.svc.cluster.local
# Address: 10.244.2.4
# Name:	mongodb-headless.default.svc.cluster.local
# Address: 10.244.1.8
# (모든 파드 IP 리스트 반환)

# 🎯 핵심 차이점 확인:
# ✅ ClusterIP: 로드밸런서 역할의 단일 가상 IP (10.96.243.158)
# ✅ Headless: DNS를 통한 개별 파드 IP 직접 반환 (10.244.1.7, 10.244.2.4, 10.244.1.8)
```

---

## 🔧 4. 통합 실습 시나리오 및 트러블슈팅

### 🎯 종합 실습: 3-Tier 아키텍처 구성

```yaml
# complete-3tier-app.yaml
---
# Frontend (LoadBalancer/NodePort)
apiVersion: v1
kind: Service
metadata:
  name: frontend-service
spec:
  type: LoadBalancer
  selector:
    app: frontend
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
      - name: frontend
        image: nginx:alpine
        env:
        - name: BACKEND_URL
          value: "http://backend-service:8080"
---
# Backend (ClusterIP)
apiVersion: v1
kind: Service
metadata:
  name: backend-service
spec:
  type: ClusterIP
  selector:
    app: backend
  ports:
  - port: 8080
    targetPort: 8080
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
spec:
  replicas: 3
  selector:
    matchLabels:
      app: backend
  template:
    metadata:
      labels:
        app: backend
    spec:
      containers:
      - name: backend
        image: httpd:alpine
        env:
        - name: DB_HOST
          value: "postgres-headless"
        ports:
        - containerPort: 8080
---
# Database (Headless + StatefulSet)
apiVersion: v1
kind: Service
metadata:
  name: postgres-headless
spec:
  clusterIP: None
  selector:
    app: postgres
  ports:
  - port: 5432
    targetPort: 5432
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
spec:
  serviceName: postgres-headless
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
      - name: postgres
        image: postgres:13
        env:
        - name: POSTGRES_PASSWORD
          value: "password"
        - name: POSTGRES_DB
          value: "myapp"
        ports:
        - containerPort: 5432
---
# External Service (ExternalName)
apiVersion: v1
kind: Service
metadata:
  name: external-api
spec:
  type: ExternalName
  externalName: api.github.com
  ports:
  - port: 443
    targetPort: 443
```

### 🐛 트러블슈팅 가이드

#### 문제 1: ExternalName DNS 해석 실패
```bash
# 증상 확인
kubectl exec -it test-pod -- nslookup external-service
# nslookup: can't resolve 'external-service'
# Server:		10.96.0.10
# Address:	10.96.0.10:53
# 
# ** server can't find external-service: NXDOMAIN

# 해결방법
# 1. CoreDNS 상태 확인
kubectl get pods -n kube-system -l k8s-app=kube-dns
# NAME                       READY   STATUS    RESTARTS   AGE
# coredns-558bd4d5db-j8x9k   1/1     Running   0          5d
# coredns-558bd4d5db-q2m7l   1/1     Running   0          5d

# 2. 서비스 정의 확인
kubectl describe svc external-service
# Name:              external-service
# Namespace:         default
# Labels:            <none>
# Annotations:       <none>
# Selector:          <none>
# Type:              ExternalName
# IP Family Policy:  SingleStack
# IP Families:       IPv4
# External Name:     invalid.example.com  # ← 잘못된 FQDN
# Port:              <unset>  443/TCP
# TargetPort:        443/TCP
# Endpoints:         <none>
# Session Affinity:  None

# 3. ExternalName을 올바른 FQDN으로 수정
kubectl edit svc external-service
# externalName을 유효한 도메인(예: api.github.com)으로 변경
```

#### 문제 2: ClusterIP 서비스 연결 실패
```bash
# 증상 확인
kubectl exec -it client-pod -- curl backend-service:8080
# curl: (7) Failed to connect to backend-service port 8080: Connection refused

# 진단 단계
# 1. 서비스 존재 확인
kubectl get svc backend-service
# NAME              TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)    AGE
# backend-service   ClusterIP   10.96.185.123   <none>        8080/TCP   5m

# 2. 엔드포인트 확인 (문제 발견!)
kubectl get endpoints backend-service
# NAME              ENDPOINTS   AGE
# backend-service   <none>      5m
# ↑ 엔드포인트가 비어있음 = 파드가 서비스와 연결되지 않음

# 3. 파드 상태 확인
kubectl get pods -l app=backend
# No resources found in default namespace.
# ↑ 파드가 없음! 또는 라벨 불일치

# 4. 라벨 셀렉터 확인
kubectl describe svc backend-service
# Selector:          app=backend  # 서비스는 app=backend 라벨을 찾음

kubectl get pods --show-labels
# NAME                           READY   STATUS    RESTARTS   AGE     LABELS
# backend-app-7d4b8c5f47-2j9kl   1/1     Running   0          30m     app=web,pod-template-hash=7d4b8c5f47
# ↑ 파드 라벨이 app=web로 잘못 설정됨 (app=backend가 아님)

# 5. 해결: 파드 라벨 수정 또는 서비스 셀렉터 수정
kubectl patch deployment backend-app -p '{"spec":{"template":{"metadata":{"labels":{"app":"backend"}}}}}'
# deployment.apps/backend-app patched

# 6. 수정 후 확인
kubectl get endpoints backend-service
# NAME              ENDPOINTS                                   AGE
# backend-service   10.244.1.5:80,10.244.1.6:80,10.244.2.3:80   7m
# ↑ 이제 엔드포인트가 정상적으로 등록됨
```

#### 문제 3: Headless 서비스 개별 파드 접근 실패
```bash
# 증상 확인
kubectl exec -it client-pod -- nslookup mongodb-0.mongodb-headless
# nslookup: can't resolve 'mongodb-0.mongodb-headless'
# Server:		10.96.0.10
# Address:	10.96.0.10:53
# 
# ** server can't find mongodb-0.mongodb-headless: NXDOMAIN

# 해결방법
# 1. StatefulSet 상태 확인
kubectl get statefulset
# NAME      READY   AGE
# mongodb   2/3     5m    # ← 일부 파드가 준비되지 않음

kubectl describe statefulset mongodb
# Name:               mongodb
# Namespace:          default
# CreationTimestamp:  Mon, 13 Nov 2025 14:30:00 +0900
# Selector:           app=mongodb
# Labels:             <none>
# Annotations:        <none>
# Replicas:           3 desired | 2 ready
# ...
# Conditions:
#   Type             Status  Reason
#   ----             ------  ------
#   Progressing      True    ReplicaSetUpdated
# Events:
#   Type    Reason            Age   From                    Message
#   ----    ------            ----  ----                    -------
#   Normal  SuccessfulCreate  5m    statefulset-controller  create Claim mongodb-storage-mongodb-0 Pod mongodb-0 in StatefulSet mongodb success
#   Warning FailedCreate      2m    statefulset-controller  create Pod mongodb-2 in StatefulSet mongodb failed: persistentvolumeclaim "mongodb-storage-mongodb-2" not found

# 2. 파드 상태 상세 확인
kubectl get pods -l app=mongodb
# NAME        READY   STATUS    RESTARTS   AGE
# mongodb-0   1/1     Running   0          5m
# mongodb-1   1/1     Running   0          4m
# mongodb-2   0/1     Pending   0          2m    # ← 파드가 Pending 상태

kubectl describe pod mongodb-2
# Events:
#   Type     Reason            Age   From               Message
#   ----     ------            ----  ----               -------
#   Warning  FailedScheduling  2m    default-scheduler  persistentvolumeclaim "mongodb-storage-mongodb-2" not bound: no persistent volumes available

# 3. PVC 상태 확인 (문제 발견!)
kubectl get pvc
# NAME                        STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
# mongodb-storage-mongodb-0   Bound    pvc-abc123...                              1Gi        RWO            standard       5m
# mongodb-storage-mongodb-1   Bound    pvc-def456...                              1Gi        RWO            standard       4m
# mongodb-storage-mongodb-2   Pending                                                                      standard       2m

# 4. 해결: 스토리지 프로비저너 확인 및 PV 생성
kubectl get storageclass
# NAME                 PROVISIONER            RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
# standard (default)   kubernetes.io/gce-pd   Delete          Immediate           true                   10d

# 일시적 해결: 해당 PVC 삭제 후 StatefulSet 재시작
kubectl delete pvc mongodb-storage-mongodb-2
kubectl delete pod mongodb-2

# 5. 수정 후 DNS 테스트
kubectl exec -it client-pod -- nslookup mongodb-0.mongodb-headless
# Server:		10.96.0.10
# Address:	10.96.0.10:53
# 
# Name:	mongodb-0.mongodb-headless.default.svc.cluster.local
# Address: 10.244.1.7
# ✅ 이제 정상적으로 해석됨

# 6. Headless 서비스 serviceName 확인
kubectl get statefulset mongodb -o yaml | grep serviceName
#  serviceName: mongodb-headless  # ✅ 올바르게 설정됨
```

### 📋 실습 검증 체크리스트

#### ✅ ExternalName 서비스 검증
- [ ] 외부 DNS 이름이 올바르게 해석되는가?
- [ ] 포트가 정확히 매핑되었는가?
- [ ] 애플리케이션에서 별칭을 통해 접근 가능한가?

#### ✅ ClusterIP 서비스 검증  
- [ ] 서비스에 ClusterIP가 할당되었는가?
- [ ] 엔드포인트에 파드 IP들이 등록되었는가?
- [ ] 로드밸런싱이 정상 작동하는가?
- [ ] 내부에서만 접근 가능하고 외부에서는 접근 불가한가?

#### ✅ Headless 서비스 검증
- [ ] ClusterIP가 None으로 설정되었는가?
- [ ] DNS 조회시 개별 파드 IP들이 반환되는가?
- [ ] StatefulSet 파드들이 안정적인 네트워크 ID를 가지는가?
- [ ] `pod-name.service-name` 형태로 개별 접근이 가능한가?

### 🧹 실습 환경 정리

```bash
# 모든 리소스 정리
kubectl delete -f complete-3tier-app.yaml
kubectl delete -f external-mysql-service.yaml
kubectl delete -f backend-deployment.yaml
kubectl delete -f backend-clusterip-service.yaml
kubectl delete -f mongodb-statefulset.yaml
kubectl delete -f mongodb-headless-service.yaml

# 테스트 파드 정리
kubectl delete pod test-pod dns-test mongo-client --ignore-not-found=true

# PVC 정리 (StatefulSet 볼륨)
kubectl delete pvc -l app=mongodb
```

---

## 🎓 핵심 정리 및 실무 팁

### 📊 서비스 타입별 사용 케이스

| 서비스 타입 | 주요 사용 사례 | DNS 해석 결과 | 로드밸런싱 |
|-------------|----------------|---------------|------------|
| **ExternalName** | 외부 DB, API 연동<br>레거시 시스템 통합 | 외부 FQDN CNAME | ❌ |
| **ClusterIP** | 마이크로서비스 간 통신<br>내부 API 게이트웨이 | 가상 IP 1개 | ✅ |
| **Headless** | 분산 DB 클러스터<br>P2P 애플리케이션 | 모든 파드 IP | ❌ |

### 💡 실무 베스트 프랙티스

#### 1. ExternalName 사용시
- 외부 의존성 추상화로 환경별 설정 분리
- DNS 캐시 TTL 고려하여 설계
- 외부 서비스의 가용성 모니터링 필수

#### 2. ClusterIP 활용시
- 기본 서비스 타입으로 내부 통신에 최적
- 포트명을 명시적으로 지정하여 가독성 향상
- Health Check와 함께 사용하여 안정성 확보

#### 3. Headless 서비스 구성시
- StatefulSet과 함께 사용하여 안정적인 네트워크 아이덴티티 제공
- 데이터베이스 클러스터, 분산 시스템에 필수
- DNS 기반 서비스 디스커버리 활용

### 🔍 추가 학습 자료

#### 관련 쿠버네티스 리소스
- [[Ingress Controller]]
- [[NetworkPolicy]]
- [[StatefulSet]]
- [[ConfigMap and Secret]]

#### 실무 시나리오
- [[Multi-cluster Service Discovery]]
- [[Service Mesh with Istio]]
- [[Blue-Green Deployment with Services]]

---

*작성일: 2025.11.13*  
*태그: #kubernetes #service #networking #devops #실습*