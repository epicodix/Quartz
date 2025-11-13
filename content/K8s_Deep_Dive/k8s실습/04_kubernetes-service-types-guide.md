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

# 서비스 확인
kubectl get svc mysql-external
kubectl describe svc mysql-external
```

### 🧪 Step 2: DNS 해석 테스트

```bash
# 테스트용 파드 생성
kubectl run test-pod --image=busybox --restart=Never -- sleep 3600

# 파드 내부에서 DNS 조회 테스트
kubectl exec -it test-pod -- nslookup mysql-external
kubectl exec -it test-pod -- nslookup mysql-external.default.svc.cluster.local

# 연결 테스트 (텔넷)
kubectl exec -it test-pod -- telnet mysql-external 3306
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

# 파드 상태 확인
kubectl get pods -l app=backend
kubectl get pods -o wide -l app=backend
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

# 서비스 확인
kubectl get svc backend-service
kubectl describe svc backend-service

# 엔드포인트 확인
kubectl get endpoints backend-service
```

### 🧪 Step 3: 서비스 연결 테스트

```bash
# 클러스터 내부에서 테스트
kubectl run test-client --image=curlimages/curl --restart=Never -it --rm -- sh

# 파드 내부에서 서비스 호출
curl backend-service:8080
curl backend-service.default.svc.cluster.local:8080

# 여러 번 호출하여 로드밸런싱 확인
for i in {1..10}; do curl -s backend-service:8080 | grep -i server; done
```

### 📊 Step 4: 포트 포워딩으로 외부 접근

```bash
# 로컬에서 서비스에 접근
kubectl port-forward svc/backend-service 8080:8080

# 다른 터미널에서 테스트
curl localhost:8080
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

# 서비스 확인 (CLUSTER-IP가 None인지 확인)
kubectl get svc mongodb-headless
kubectl describe svc mongodb-headless
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

# 파드 상태 확인
kubectl get pods -l app=mongodb
kubectl get statefulset mongodb
```

### 🔍 Step 3: DNS 해석 테스트

```bash
# 각 파드의 FQDN 확인
kubectl get pods -l app=mongodb -o wide

# DNS 테스트용 파드 생성
kubectl run dns-test --image=busybox --restart=Never -- sleep 3600

# Headless 서비스 DNS 조회
kubectl exec -it dns-test -- nslookup mongodb-headless

# 개별 파드 DNS 조회
kubectl exec -it dns-test -- nslookup mongodb-0.mongodb-headless
kubectl exec -it dns-test -- nslookup mongodb-1.mongodb-headless
kubectl exec -it dns-test -- nslookup mongodb-2.mongodb-headless

# 모든 파드 IP 확인
kubectl exec -it dns-test -- nslookup mongodb-headless.default.svc.cluster.local
```

### 📊 Step 4: 개별 파드 직접 접근 테스트

```bash
# MongoDB 클라이언트로 개별 노드 접근
kubectl run mongo-client --image=mongo:5.0 --restart=Never -it --rm -- bash

# 각 MongoDB 인스턴스에 개별 연결
mongo mongodb://admin:password@mongodb-0.mongodb-headless:27017
mongo mongodb://admin:password@mongodb-1.mongodb-headless:27017
mongo mongodb://admin:password@mongodb-2.mongodb-headless:27017

# 클러스터 상태 확인
rs.status()
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

# DNS 비교 테스트
kubectl exec -it dns-test -- nslookup mongodb-clusterip
kubectl exec -it dns-test -- nslookup mongodb-headless

# 차이점 확인:
# ClusterIP: 단일 가상 IP 반환
# Headless: 모든 파드 IP 리스트 반환
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

# 해결방법
# 1. CoreDNS 상태 확인
kubectl get pods -n kube-system -l k8s-app=kube-dns

# 2. 서비스 정의 확인
kubectl describe svc external-service

# 3. ExternalName이 올바른 FQDN인지 확인
kubectl edit svc external-service
```

#### 문제 2: ClusterIP 서비스 연결 실패
```bash
# 증상 확인
kubectl exec -it client-pod -- curl backend-service:8080
# curl: (7) Failed to connect

# 진단 단계
# 1. 서비스 존재 확인
kubectl get svc backend-service

# 2. 엔드포인트 확인
kubectl get endpoints backend-service

# 3. 파드 상태 확인
kubectl get pods -l app=backend

# 4. 포트 매핑 확인
kubectl describe svc backend-service
kubectl describe pod <backend-pod-name>

# 5. 네트워크 정책 확인
kubectl get networkpolicies
```

#### 문제 3: Headless 서비스 개별 파드 접근 실패
```bash
# 증상 확인
kubectl exec -it client-pod -- nslookup mongodb-0.mongodb-headless
# nslookup: can't resolve

# 해결방법
# 1. StatefulSet 상태 확인
kubectl get statefulset
kubectl describe statefulset mongodb

# 2. 파드명 규칙 확인 (statefulset-name-ordinal)
kubectl get pods -l app=mongodb

# 3. Headless 서비스의 serviceName 확인
kubectl get statefulset mongodb -o yaml | grep serviceName

# 4. DNS 서브도메인 확인
kubectl exec -it client-pod -- nslookup mongodb-headless.default.svc.cluster.local
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