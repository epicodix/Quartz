---
title: k3d EKS 찍먹 가이드 - 타임딜 사가 패턴
tags:
  - k3d
  - kubernetes
  - go
  - saga-pattern
  - microservices
  - eks
aliases:
  - k3d 찍먹
  - 사가패턴 실습
date: 2026-02-12
category: 2_기술_분석/쿠버네티스
status: 완성
priority: 높음
---

# 🎯 k3d EKS 찍먹 가이드 - 타임딜 사가 패턴

## 📑 목차
- [[#1. 목표와 구조|목표와 구조]]
- [[#2. Day 1 - k3d 클러스터 + Go API|Day 1]]
- [[#3. Day 2 - 서비스 간 통신 + DB|Day 2]]
- [[#4. Day 3 - 사가 패턴 구현|Day 3]]
- [[#5. EKS 이전 시 차이점|EKS 이전]]
- [[#6. 트러블슈팅|트러블슈팅]]
- [[#부록 A. 발견된 버그와 수정|버그 수정]]
- [[#부록 B. React 프론트엔드 UI|프론트엔드 UI]]
- [[#부록 C. 부하 테스트|부하 테스트]]

---

## 1. 목표와 구조

> [!note] 핵심 목표
> k3d 로컬 환경에서 EKS 프로덕션과 동일한 구조로 타임딜 서비스를 구성하고, 사가 패턴(보상 트랜잭션)을 검증한다.

### 💡 아키텍처

```
k3d 클러스터 (로컬)
├── Namespace: timedeal
│     ├── Go 서비스 (재고 + 타임딜 스케줄러)
│     ├── Spring Boot 서비스 (상품/주문/인증 API)
│     ├── PostgreSQL (StatefulSet)
│     └── (선택) Redis (타임딜 캐시)
│
└── Ingress (Traefik)
      ├── /api/stock/*    → Go 서비스
      └── /api/*          → Spring Boot 서비스
```

### 📊 k3d vs EKS 비교

| 항목 | k3d (로컬) | EKS (프로덕션) |
|------|-----------|--------------|
| Ingress | Traefik (내장) | ALB Ingress Controller |
| DB | PostgreSQL 컨테이너 | RDS PostgreSQL |
| 스토리지 | local-path | EBS CSI Driver |
| 서비스 노출 | localhost:8080 | ALB + Route53 |
| IAM | 없음 | IRSA (ServiceAccount) |
| 매니페스트 호환 | 90% 동일 | Kustomize overlay로 차이 관리 |

---

## 2. Day 1 - k3d 클러스터 + Go API

### 🔧 k3d 클러스터 생성

```bash
# k3d 설치 (미설치 시)
brew install k3d

# 클러스터 생성 (포트 매핑 포함)
k3d cluster create timedeal \
  --port 8080:80@loadbalancer \
  --agents 2

# 확인
kubectl cluster-info
kubectl get nodes
```

### 🔧 네임스페이스 생성

```bash
kubectl create namespace timedeal
kubectl config set-context --current --namespace=timedeal
```

### 💻 Go 재고 서비스 작성

#### 프로젝트 구조

```
stock-service/
├── main.go
├── Dockerfile
└── k8s/
    ├── deployment.yaml
    └── service.yaml
```

#### main.go

```go
package main

import (
    "encoding/json"
    "log"
    "net/http"
    "sync"
)

type Stock struct {
    ProductID int `json:"product_id"`
    Quantity  int `json:"quantity"`
    Reserved  int `json:"reserved"`
}

var (
    stocks = map[int]*Stock{
        1: {ProductID: 1, Quantity: 100, Reserved: 0},
        2: {ProductID: 2, Quantity: 50, Reserved: 0},
    }
    mu sync.Mutex
)

// 재고 조회
func getStock(w http.ResponseWriter, r *http.Request) {
    mu.Lock()
    defer mu.Unlock()

    var req struct{ ProductID int `json:"product_id"` }
    json.NewDecoder(r.Body).Decode(&req)

    stock, ok := stocks[req.ProductID]
    if !ok {
        http.Error(w, `{"error":"not found"}`, 404)
        return
    }
    json.NewEncoder(w).Encode(stock)
}

// 재고 임시 확보 (사가 Step 1)
func reserveStock(w http.ResponseWriter, r *http.Request) {
    mu.Lock()
    defer mu.Unlock()

    var req struct {
        ProductID int `json:"product_id"`
        Quantity  int `json:"quantity"`
    }
    json.NewDecoder(r.Body).Decode(&req)

    stock, ok := stocks[req.ProductID]
    if !ok {
        http.Error(w, `{"error":"not found"}`, 404)
        return
    }

    available := stock.Quantity - stock.Reserved
    if available < req.Quantity {
        w.WriteHeader(409)
        json.NewEncoder(w).Encode(map[string]any{
            "error":     "insufficient stock",
            "available": available,
            "requested": req.Quantity,
        })
        return
    }

    stock.Reserved += req.Quantity
    log.Printf("[Reserve] product=%d qty=%d reserved=%d/%d",
        req.ProductID, req.Quantity, stock.Reserved, stock.Quantity)

    json.NewEncoder(w).Encode(map[string]any{
        "status":   "reserved",
        "reserved": req.Quantity,
    })
}

// 재고 확정 (사가 Step 3 - 성공)
func confirmStock(w http.ResponseWriter, r *http.Request) {
    mu.Lock()
    defer mu.Unlock()

    var req struct {
        ProductID int `json:"product_id"`
        Quantity  int `json:"quantity"`
    }
    json.NewDecoder(r.Body).Decode(&req)

    stock, ok := stocks[req.ProductID]
    if !ok {
        http.Error(w, `{"error":"not found"}`, 404)
        return
    }

    if stock.Quantity < req.Quantity {
        w.WriteHeader(409)
        json.NewEncoder(w).Encode(map[string]any{"error": "insufficient stock"})
        return
    }
    stock.Quantity -= req.Quantity
    if stock.Reserved < req.Quantity {
        stock.Reserved = 0
    } else {
        stock.Reserved -= req.Quantity
    }
    log.Printf("[Confirm] product=%d qty=%d remaining=%d",
        req.ProductID, req.Quantity, stock.Quantity)

    json.NewEncoder(w).Encode(map[string]any{
        "status":    "confirmed",
        "remaining": stock.Quantity,
    })
}

// 재고 롤백 (사가 보상 트랜잭션)
func cancelStock(w http.ResponseWriter, r *http.Request) {
    mu.Lock()
    defer mu.Unlock()

    var req struct {
        ProductID int `json:"product_id"`
        Quantity  int `json:"quantity"`
    }
    json.NewDecoder(r.Body).Decode(&req)

    stock, ok := stocks[req.ProductID]
    if !ok {
        http.Error(w, `{"error":"not found"}`, 404)
        return
    }

    if stock.Reserved < req.Quantity {
        stock.Reserved = 0
    } else {
        stock.Reserved -= req.Quantity
    }
    log.Printf("[Cancel] product=%d qty=%d released, reserved=%d",
        req.ProductID, req.Quantity, stock.Reserved)

    json.NewEncoder(w).Encode(map[string]any{
        "status":   "cancelled",
        "released": req.Quantity,
    })
}

// 헬스체크
func health(w http.ResponseWriter, r *http.Request) {
    json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
}

func main() {
    http.HandleFunc("/health", health)
    http.HandleFunc("/api/stock/get", getStock)
    http.HandleFunc("/api/stock/reserve", reserveStock)
    http.HandleFunc("/api/stock/confirm", confirmStock)
    http.HandleFunc("/api/stock/cancel", cancelStock)

    log.Println("Stock service starting on :8081")
    log.Fatal(http.ListenAndServe(":8081", nil))
}
```

#### Dockerfile

```dockerfile
FROM golang:1.22-alpine AS builder
WORKDIR /app
COPY main.go .
RUN go build -o stock-service main.go

FROM alpine:3.19
COPY --from=builder /app/stock-service /stock-service
EXPOSE 8081
CMD ["/stock-service"]
```

#### 빌드 + k3d에 로드

```bash
# 이미지 빌드
docker build -t stock-service:v1 ./stock-service/

# k3d 클러스터에 이미지 로드 (레지스트리 없이 바로 사용)
k3d image import stock-service:v1 -c timedeal
```

#### k8s/deployment.yaml

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: stock-service
  namespace: timedeal
spec:
  replicas: 2
  selector:
    matchLabels:
      app: stock-service
  template:
    metadata:
      labels:
        app: stock-service
    spec:
      containers:
      - name: stock
        image: stock-service:v1
        imagePullPolicy: Never    # k3d import 이미지 사용
        ports:
        - containerPort: 8081
        livenessProbe:
          httpGet:
            path: /health
            port: 8081
          initialDelaySeconds: 5
        resources:
          requests:
            cpu: 100m
            memory: 64Mi
          limits:
            cpu: 200m
            memory: 128Mi
---
apiVersion: v1
kind: Service
metadata:
  name: stock-service
  namespace: timedeal
spec:
  selector:
    app: stock-service
  ports:
  - port: 8081
    targetPort: 8081
```

#### 배포 + 테스트

```bash
# 배포
kubectl apply -f stock-service/k8s/

# 확인
kubectl get pods -n timedeal
kubectl logs -l app=stock-service -n timedeal

# 포트포워딩으로 테스트
kubectl port-forward svc/stock-service 8081:8081 -n timedeal &

# 재고 조회
curl -s localhost:8081/api/stock/get \
  -d '{"product_id":1}' | jq

# 재고 예약
curl -s localhost:8081/api/stock/reserve \
  -d '{"product_id":1,"quantity":5}' | jq

# 재고 확정
curl -s localhost:8081/api/stock/confirm \
  -d '{"product_id":1,"quantity":5}' | jq

# 재고 취소 (보상 트랜잭션)
curl -s localhost:8081/api/stock/cancel \
  -d '{"product_id":1,"quantity":5}' | jq
```

> [!tip] Day 1 완료 기준
> Go 재고 서비스가 k3d에서 2개 Pod으로 돌아가고, reserve/confirm/cancel API가 curl로 정상 응답하면 성공.

---

## 3. Day 2 - 서비스 간 통신 + DB

### 🔧 PostgreSQL 배포

```yaml
# postgres.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: postgres-config
  namespace: timedeal
data:
  POSTGRES_DB: timedeal
  POSTGRES_USER: postgres
  POSTGRES_PASSWORD: postgres
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
  namespace: timedeal
spec:
  serviceName: postgres
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
        image: postgres:15-alpine
        ports:
        - containerPort: 5432
        envFrom:
        - configMapRef:
            name: postgres-config
        volumeMounts:
        - name: pgdata
          mountPath: /var/lib/postgresql/data
  volumeClaimTemplates:
  - metadata:
      name: pgdata
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 1Gi
---
apiVersion: v1
kind: Service
metadata:
  name: postgres
  namespace: timedeal
spec:
  selector:
    app: postgres
  ports:
  - port: 5432
    targetPort: 5432
```

```bash
kubectl apply -f postgres.yaml

# DB 접속 테스트
kubectl exec -it postgres-0 -n timedeal -- psql -U postgres -d timedeal
```

### 🔧 DB 접속 정보를 Secret으로 관리

```yaml
# db-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-credentials
  namespace: timedeal
type: Opaque
stringData:
  DB_HOST: postgres.timedeal.svc.cluster.local
  DB_PORT: "5432"
  DB_NAME: timedeal
  DB_USER: postgres
  DB_PASSWORD: postgres
```

### 💻 서비스 간 통신 테스트

```
k3d 내부에서 서비스 간 통신:

Spring Boot → Go:
  http://stock-service.timedeal.svc.cluster.local:8081/api/stock/reserve

Go → PostgreSQL:
  postgres.timedeal.svc.cluster.local:5432

형식: <서비스명>.<네임스페이스>.svc.cluster.local:<포트>
같은 네임스페이스면: <서비스명>:<포트> 으로 축약 가능
```

> [!tip] Day 2 완료 기준
> PostgreSQL이 k3d에서 돌아가고, Go 서비스에서 DB 접속이 되면 성공. Spring Boot는 Day 3에서 간단한 mock으로 대체 가능.

---

## 4. Day 3 - 사가 패턴 구현

### 💡 사가 패턴이란?

> [!note] 핵심 개념
> 분산 시스템에서 여러 서비스에 걸친 트랜잭션을 관리하는 패턴. DB 트랜잭션처럼 한번에 롤백할 수 없으므로, 각 단계의 **보상 트랜잭션(Compensating Transaction)**을 정의한다.

### 📊 두 가지 방식 비교

| | Choreography | Orchestration |
|--|-------------|---------------|
| 방식 | 이벤트 기반 (각자 반응) | 중앙 조율자가 관리 |
| 구현 | 이벤트 브로커 필요 (SQS, Redis) | HTTP 호출로 가능 |
| 복잡도 | 서비스 많으면 추적 어려움 | 흐름이 한눈에 보임 |
| 우리 선택 | - | Orchestration (간단, 찍먹용) |

### 💻 사가 플로우: 타임딜 주문

```
주문 Orchestrator (Spring Boot or Go로 테스트)

정상 플로우:
  1. 주문 생성 (status: PENDING)
  2. → Go: POST /api/stock/reserve     ← 재고 임시 확보
  3. → 결제 처리 (mock)
  4. → Go: POST /api/stock/confirm     ← 재고 확정
  5. 주문 완료 (status: COMPLETED)

실패 플로우 (결제 실패):
  1. 주문 생성 (status: PENDING)
  2. → Go: POST /api/stock/reserve     ← 재고 임시 확보
  3. → 결제 실패!
  4. → Go: POST /api/stock/cancel      ← 보상: 재고 복구
  5. 주문 취소 (status: CANCELLED)

실패 플로우 (재고 부족):
  1. 주문 생성 (status: PENDING)
  2. → Go: POST /api/stock/reserve     ← 409 Conflict!
  3. 주문 거부 (status: REJECTED)
```

### 💻 Go로 간단한 주문 Orchestrator 테스트

```go
// order-test/main.go - 사가 패턴 테스트 스크립트
package main

import (
    "bytes"
    "encoding/json"
    "fmt"
    "log"
    "net/http"
)

const stockURL = "http://stock-service:8081"

type StockRequest struct {
    ProductID int `json:"product_id"`
    Quantity  int `json:"quantity"`
}

func callStock(endpoint string, req StockRequest) (map[string]any, int, error) {
    body, _ := json.Marshal(req)
    resp, err := http.Post(stockURL+endpoint, "application/json", bytes.NewReader(body))
    if err != nil {
        return nil, 0, err
    }
    defer resp.Body.Close()

    var result map[string]any
    json.NewDecoder(resp.Body).Decode(&result)
    return result, resp.StatusCode, nil
}

func processOrder(productID, quantity int, simulatePaymentFail bool) {
    fmt.Printf("\n=== 주문 시작: 상품 %d, 수량 %d ===\n", productID, quantity)

    // Step 1: 재고 예약
    fmt.Println("[Step 1] 재고 예약 요청...")
    result, status, err := callStock("/api/stock/reserve", StockRequest{productID, quantity})
    if err != nil || status != 200 {
        fmt.Printf("[FAIL] 재고 부족! status=%d result=%v\n", status, result)
        fmt.Println("[결과] 주문 REJECTED")
        return
    }
    fmt.Printf("[OK] 재고 예약 완료: %v\n", result)

    // Step 2: 결제 처리 (mock)
    fmt.Println("[Step 2] 결제 처리 중...")
    if simulatePaymentFail {
        fmt.Println("[FAIL] 결제 실패!")

        // 보상 트랜잭션: 재고 복구
        fmt.Println("[보상] 재고 복구 요청...")
        cancelResult, _, _ := callStock("/api/stock/cancel", StockRequest{productID, quantity})
        fmt.Printf("[보상 완료] %v\n", cancelResult)
        fmt.Println("[결과] 주문 CANCELLED")
        return
    }
    fmt.Println("[OK] 결제 성공!")

    // Step 3: 재고 확정
    fmt.Println("[Step 3] 재고 확정...")
    confirmResult, _, _ := callStock("/api/stock/confirm", StockRequest{productID, quantity})
    fmt.Printf("[OK] %v\n", confirmResult)
    fmt.Println("[결과] 주문 COMPLETED")
}

func main() {
    // 테스트 1: 정상 주문
    processOrder(1, 5, false)

    // 테스트 2: 결제 실패 → 보상 트랜잭션
    processOrder(1, 3, true)

    // 테스트 3: 재고 부족
    processOrder(1, 999, false)
}
```

### 🔧 k3d에서 사가 테스트 실행

```bash
# 방법 1: kubectl run으로 일회성 Pod 실행
kubectl run saga-test --rm -it \
  --image=golang:1.22-alpine \
  --namespace=timedeal \
  --restart=Never \
  -- sh -c "
    cd /tmp &&
    cat > main.go << 'EOF'
    (위의 main.go 코드)
    EOF
    go run main.go
  "

# 방법 2: 로컬에서 port-forward 후 테스트
kubectl port-forward svc/stock-service 8081:8081 -n timedeal &

# 정상 주문
curl -s localhost:8081/api/stock/reserve \
  -d '{"product_id":1,"quantity":5}' | jq
curl -s localhost:8081/api/stock/confirm \
  -d '{"product_id":1,"quantity":5}' | jq

# 결제 실패 시나리오 (reserve → cancel)
curl -s localhost:8081/api/stock/reserve \
  -d '{"product_id":1,"quantity":3}' | jq
curl -s localhost:8081/api/stock/cancel \
  -d '{"product_id":1,"quantity":3}' | jq

# 재고 부족 시나리오
curl -s localhost:8081/api/stock/reserve \
  -d '{"product_id":1,"quantity":999}' | jq
# → 409 Conflict 응답
```

### 📊 사가 패턴 상태 다이어그램

```
                    ┌─────────┐
                    │ PENDING │
                    └────┬────┘
                         │
                    재고 예약 요청
                         │
               ┌─────────┼─────────┐
               │ 성공                │ 실패 (재고 부족)
               ▼                    ▼
          ┌─────────┐         ┌──────────┐
          │RESERVED │         │ REJECTED │
          └────┬────┘         └──────────┘
               │
          결제 처리
               │
       ┌───────┼───────┐
       │ 성공          │ 실패
       ▼               ▼
  재고 확정         재고 복구 (보상)
       │               │
       ▼               ▼
┌───────────┐   ┌───────────┐
│ COMPLETED │   │ CANCELLED │
└───────────┘   └───────────┘
```

> [!tip] Day 3 완료 기준
> 3가지 시나리오(정상/결제실패/재고부족)가 k3d에서 정상 동작하면 사가 패턴 찍먹 성공!

---

## 5. EKS 이전 시 차이점

### 📋 Kustomize로 환경 분리

```
k8s/
├── base/                    # 공통 매니페스트
│   ├── kustomization.yaml
│   ├── deployment.yaml
│   ├── service.yaml
│   └── namespace.yaml
├── overlays/
│   ├── local/               # k3d용
│   │   ├── kustomization.yaml
│   │   └── patches/
│   │       └── db-config.yaml    # PostgreSQL 컨테이너
│   └── production/          # EKS용
│       ├── kustomization.yaml
│       └── patches/
│           ├── db-config.yaml    # RDS 엔드포인트
│           ├── ingress.yaml      # ALB Ingress
│           └── hpa.yaml          # Auto Scaling
```

### 🔧 환경별 차이 관리

```yaml
# overlays/local/patches/db-config.yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-credentials
stringData:
  DB_HOST: postgres.timedeal.svc.cluster.local

# overlays/production/patches/db-config.yaml
apiVersion: v1
kind: Secret
metadata:
  name: db-credentials
stringData:
  DB_HOST: timedeal-db.xxxx.ap-northeast-2.rds.amazonaws.com
```

```bash
# 로컬 배포
kubectl apply -k k8s/overlays/local

# 프로덕션 배포
kubectl apply -k k8s/overlays/production
```

---

## 6. 트러블슈팅

### 🔍 자주 겪는 문제

| 증상 | 원인 | 해결 |
|------|------|------|
| ImagePullBackOff | k3d에 이미지 미로드 | `k3d image import <이미지> -c timedeal` |
| CrashLoopBackOff | 앱 에러 | `kubectl logs <pod>` 확인 |
| 서비스 간 통신 실패 | DNS 미해석 | `<svc>.<ns>.svc.cluster.local` 형식 확인 |
| PVC Pending | StorageClass 미설정 | k3d는 `local-path` 자동 제공, 확인 |
| 포트 충돌 | 이미 사용 중인 포트 | `lsof -i :8080` 확인 후 kill |

### 🔧 디버깅 명령어

```bash
# Pod 상태 확인
kubectl get pods -n timedeal -o wide

# Pod 로그 실시간
kubectl logs -f -l app=stock-service -n timedeal

# Pod 내부 접속
kubectl exec -it <pod-name> -n timedeal -- sh

# 서비스 DNS 테스트
kubectl run dns-test --rm -it --image=busybox --restart=Never -- \
  nslookup stock-service.timedeal.svc.cluster.local

# 클러스터 전체 상태
kubectl get all -n timedeal
```

---

> [!warning] 주의사항
> - k3d 클러스터는 Docker 위에서 돌아가므로 Docker Desktop이 실행 중이어야 함
> - 맥북 에어 기준 메모리 4GB 이상 Docker에 할당 권장
> - `imagePullPolicy: Never` 반드시 설정 (k3d import 이미지 사용 시)
> - 연휴 끝나고 팀원들에게 데모할 때: `k3d cluster start timedeal`로 바로 재시작 가능

---

## 부록 A. 발견된 버그와 수정

> [!danger] In-Memory + Multi-Pod 재고 불일치 버그
> 테스트 중 재고가 90개 ↔ 98개로 왔다갔다하는 현상 발견. 원인을 추적한 결과 **3개 레이어의 버그**가 중첩되어 있었다.

### 📊 버그 1: Multi-Pod 상태 불일치

**증상**: 재고 조회 결과가 매번 다른 값을 반환

**원인**: Go 서비스가 `map[int]*Stock` 인메모리에 재고를 저장하는데, `replicas: 2`로 배포하면 각 Pod이 독립된 메모리를 가짐. K8s Service의 라운드로빈 로드밸런싱으로 요청이 번갈아 다른 Pod으로 갔기 때문.

```
Pod 1: quantity=90 (구매 반영됨)
Pod 2: quantity=98 (다른 요청 받음)
→ 폴링할 때마다 다른 Pod 응답 → 값이 왔다갔다
```

**해결**: 로컬 테스트 시 `replicas: 1`로 설정. 프로덕션에서는 RDS 등 공유 저장소 사용 필수.

### 📊 버그 2: Reserved 음수 → 초과 구매 허용

**증상**: 재고 100개인데 100개 넘게 구매 가능

**원인**: `cancelStock`에서 `Reserved` 값의 하한 검증이 없어 음수로 내려감.

```
available = Quantity - Reserved
         = 86 - (-45)
         = 131    ← 100개 상품인데 131개 구매 가능!
```

**수정 전** (버그):
```go
// cancelStock - Reserved가 음수로 내려감
stock.Reserved -= req.Quantity

// confirmStock - Quantity가 음수로 내려감
stock.Quantity -= req.Quantity
stock.Reserved -= req.Quantity
```

**수정 후** (v2):
```go
// cancelStock - 음수 보호
if stock.Reserved < req.Quantity {
    stock.Reserved = 0
} else {
    stock.Reserved -= req.Quantity
}

// confirmStock - 재고 부족 검증 + 음수 보호
if stock.Quantity < req.Quantity {
    w.WriteHeader(409)
    json.NewEncoder(w).Encode(map[string]any{"error": "insufficient stock"})
    return
}
stock.Quantity -= req.Quantity
if stock.Reserved < req.Quantity {
    stock.Reserved = 0
} else {
    stock.Reserved -= req.Quantity
}
```

### 📊 버그 3: HPA가 replicas 강제 복원

**증상**: `kubectl scale --replicas=1` 해도 계속 2개로 돌아감

**원인**: HPA(Horizontal Pod Autoscaler)가 `minReplicas: 2`로 설정되어, deployment의 replicas를 수동으로 줄여도 HPA가 다시 2로 올림.

```bash
# HPA 확인
kubectl get hpa -n timedeal
# → minPods: 2, maxPods: 10

# 해결: 로컬 테스트 시 HPA 삭제
kubectl delete hpa stock-service -n timedeal
kubectl scale deployment stock-service -n timedeal --replicas=1
```

### 📋 이미지 재빌드 절차

```bash
# 코드 수정 후 v2 빌드
docker build -t stock-service:v2 ./stock-service/

# k3d 클러스터에 이미지 import
k3d image import stock-service:v2 -c timedeal

# 배포 업데이트
kubectl set image deployment/stock-service -n timedeal stock=stock-service:v2

# rollout 확인
kubectl rollout status deployment/stock-service -n timedeal
```

> [!tip] 교훈
> 1. **인메모리 상태 + replicas > 1 = 반드시 불일치** 발생. 공유 저장소(Redis/DB) 없이 멀티 Pod은 위험.
> 2. **모든 감소 연산에 하한 검증 필수**. `A -= B` 할 때 `A >= B` 확인 안 하면 음수 버그.
> 3. **HPA는 deployment replicas를 덮어씀**. 수동 스케일링 전에 HPA 상태부터 확인.

---

## 부록 B. React 프론트엔드 UI

> [!note] 핵심 변경
> MVP 수준의 인라인 스타일 단일 컴포넌트에서, 모던 화이트&블랙 디자인 + 실시간 모니터링 대시보드로 리디자인. 추가 라이브러리 없이 순수 React + CSS로 구현.

### 💡 컴포넌트 구조

```
App (단일 파일 App.jsx)
├── Header (탭 네비게이션: 타임딜 | 모니터링)
├── TimeDealTab
│   ├── CountdownTimer      10분 카운트다운
│   ├── ProductCard          재고 프로그레스바 포함
│   ├── PurchaseControls     수량 선택 + 구매/취소 버튼
│   └── MessageToast         결과 알림 (성공/실패/정보)
└── MonitorTab
    ├── StatsCards            총요청 / 성공률 / 평균응답시간
    ├── ResponseTimeChart     CSS 바 차트 (최근 20건)
    ├── StockHistoryChart     CSS 라인 시각화 (최근 30건)
    └── HealthStatus          /health 엔드포인트 폴링
```

### 📊 디자인 테마

| 항목 | 값 |
|------|-----|
| 배경 | #FFFFFF / #F8F9FA |
| 텍스트 | #1A1A1A / #000000 |
| 보더 | #E5E5E5 |
| 액센트 | #000000 (버튼, 프로그레스바) |
| 위험 | #FF4444 (재고 부족, 느린 응답) |
| 카운트다운 | 블랙 배경 + 화이트 텍스트 |

### 💻 핵심 구현: trackedFetch

모든 API 요청을 래핑하여 응답시간과 성공/실패를 자동 추적하는 함수. 모니터링 탭의 데이터 소스.

```javascript
const trackedFetch = useCallback(async (url, opts) => {
  const start = performance.now()
  try {
    const res = await fetch(url, opts)
    const elapsed = Math.round(performance.now() - start)

    setMetrics(prev => ({
      total: prev.total + 1,
      success: res.ok ? prev.success + 1 : prev.success,
      fail: res.ok ? prev.fail : prev.fail + 1,
      totalTime: prev.totalTime + elapsed,
    }))
    setResponseHistory(prev => [...prev.slice(-19), { time: elapsed, ok: res.ok }])
    return res
  } catch (e) {
    const elapsed = Math.round(performance.now() - start)
    setMetrics(prev => ({
      total: prev.total + 1,
      success: prev.success,
      fail: prev.fail + 1,
      totalTime: prev.totalTime + elapsed,
    }))
    setResponseHistory(prev => [...prev.slice(-19), { time: elapsed, ok: false }])
    throw e
  }
}, [])
```

### 🔧 실행 방법

```bash
cd ~/timedeal-k8s/frontend
npm run dev
# → http://localhost:5173/
```

Vite 프록시가 API 요청을 k3d Ingress(`localhost:8080`)로 포워딩.

---

## 부록 C. 부하 테스트

> [!note] 목적
> stock-service의 동시 요청 처리 능력과 사가 패턴의 정합성을 검증. 부하 중에도 재고가 음수로 내려가지 않는지, 모니터링 대시보드가 실시간으로 반영되는지 확인.

### 🔧 사전 준비

```bash
# hey 설치 (미설치 시)
brew install hey

# 재고 초기화 (Pod 재시작)
kubectl rollout restart deployment/stock-service -n timedeal

# 포트포워딩 (Ingress 없이 직접 테스트 시)
kubectl port-forward svc/stock-service 8081:8081 -n timedeal &
```

### 💻 테스트 1: 재고 조회 부하

읽기 전용 요청. 서비스의 기본 처리 성능 측정.

```bash
# 동시 10명, 총 200건 재고 조회
hey -n 200 -c 10 \
  -m POST \
  -H "Content-Type: application/json" \
  -d '{"product_id":1}' \
  http://localhost:8080/api/stock/get
```

### 💻 테스트 2: 동시 구매 (reserve) 부하

재고 100개에 동시 50명이 1개씩 구매 시도. Mutex 경합 + 409 발생 확인.

```bash
# 동시 50명, 총 150건 예약 시도
hey -n 150 -c 50 \
  -m POST \
  -H "Content-Type: application/json" \
  -d '{"product_id":1,"quantity":1}' \
  http://localhost:8080/api/stock/reserve
```

> [!warning] 주의
> reserve만 하고 confirm/cancel을 안 하면 Reserved가 계속 쌓임. 테스트 후 Pod 재시작으로 초기화 필요.

### 💻 테스트 3: 사가 전체 플로우 (스크립트)

reserve → confirm을 순차 실행하면서 동시성 검증.

```bash
#!/bin/bash
# saga-load-test.sh - 동시 10명이 각각 사가 플로우 실행

BASE_URL="http://localhost:8080"

run_saga() {
  local id=$1
  # Step 1: Reserve
  RESERVE=$(curl -s -w "\n%{http_code}" -X POST \
    -H "Content-Type: application/json" \
    -d '{"product_id":1,"quantity":1}' \
    "$BASE_URL/api/stock/reserve")

  STATUS=$(echo "$RESERVE" | tail -1)

  if [ "$STATUS" = "409" ]; then
    echo "[Worker $id] 재고 부족 - 주문 거부"
    return
  fi

  # Step 2: Confirm
  curl -s -X POST \
    -H "Content-Type: application/json" \
    -d '{"product_id":1,"quantity":1}' \
    "$BASE_URL/api/stock/confirm" > /dev/null

  echo "[Worker $id] 구매 완료"
}

# 동시 10명 실행
for i in $(seq 1 10); do
  run_saga $i &
done
wait

# 결과 확인
echo ""
echo "=== 최종 재고 ==="
curl -s -X POST \
  -H "Content-Type: application/json" \
  -d '{"product_id":1}' \
  "$BASE_URL/api/stock/get" | python3 -m json.tool
```

```bash
chmod +x saga-load-test.sh
./saga-load-test.sh
```

### 📊 결과 확인 포인트

| 확인 항목 | 기대 결과 |
|----------|----------|
| 재고 음수 여부 | quantity >= 0 (절대 음수 아님) |
| Reserved 음수 여부 | reserved >= 0 (v2 패치 검증) |
| 409 응답 | 재고 소진 후 모든 reserve 요청이 409 |
| 총 구매 수 | 초기 재고(100)를 초과하지 않음 |
| 모니터링 탭 | 요청 수, 성공률, 응답시간 실시간 반영 |

### 💻 모니터링 탭과 함께 테스트

```bash
# 터미널 1: 프론트엔드 (모니터링 탭 열어두기)
cd ~/timedeal-k8s/frontend && npm run dev

# 터미널 2: 부하 테스트 실행
hey -n 100 -c 20 \
  -m POST \
  -H "Content-Type: application/json" \
  -d '{"product_id":1,"quantity":1}' \
  http://localhost:8080/api/stock/reserve
```

브라우저에서 모니터링 탭을 열어두면 부하 테스트 중 응답시간 바 차트와 재고 변화 그래프가 실시간으로 변하는 것을 관찰할 수 있다.

> [!tip] hey 결과 읽는 법
> ```
> Summary:
>   Total:        0.1234 secs     ← 전체 소요시간
>   Requests/sec: 810.37          ← 초당 처리량 (RPS)
>   Average:      0.0123 secs     ← 평균 응답시간
>   Fastest:      0.0012 secs
>   Slowest:      0.0456 secs
>
> Status code distribution:
>   [200] 100 responses           ← 성공
>   [409] 50 responses            ← 재고 부족 (정상)
> ```
