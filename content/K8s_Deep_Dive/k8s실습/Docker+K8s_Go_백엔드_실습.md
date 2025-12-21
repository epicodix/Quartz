---
title: Docker + K8s Go 백엔드 실습 - 명함 서비스 배포
tags:
  - docker
  - kubernetes
  - golang
  - devops
  - backend
  - cka
aliases:
  - Go 백엔드 도커화
  - 쿠버네티스 배포 실습
date: 2024-12-18
category: K8s_Deep_Dive/k8s실습
status: 완성
priority: 높음
---

# 🐳 Docker + K8s Go 백엔드 실습 - 명함 서비스 배포

## 📑 목차
- [[#1. 프로젝트 개요|프로젝트 개요]]
- [[#2. Go 백엔드 개발|Go 백엔드 개발]]
- [[#3. Docker 이미지 빌드|Docker 이미지 빌드]]
- [[#4. 이미지 전송 및 배포|이미지 전송 및 배포]]
- [[#5. Kubernetes 배포|Kubernetes 배포]]
- [[#6. 핵심 학습 포인트|핵심 학습 포인트]]

---

## 1. 프로젝트 개요

### 💡 배경
- **기존**: React(Frontend) + Firebase(Backend) 구조의 명함 서비스
- **목표**: BaaS 의존성을 탈피하고 직접 백엔드를 구축하여 Cloud Native 아키텍처 학습

### 🏗️ 아키텍처 진화

**AS-IS (BaaS 의존형)**
```
사용자 → Netlify(React) → Firebase(DB + 인증)
```

**TO-BE (Cloud Native)**
```
사용자 → Netlify(React) → K8s(Go API) → Database
```

### 📊 기술 스택 비교

| 구분 | 기존 | 신규 |
|------|------|------|
| Frontend | React (Netlify) | React (Netlify) - 유지 |
| Backend | Firebase Functions | Go + Fiber |
| DB | Firestore | PostgreSQL (예정) |
| 배포 | Firebase Hosting | Kubernetes |
| 장점 | 빠른 개발 | 확장성, 학습 효과 |

---

## 2. Go 백엔드 개발

### 💻 프로젝트 구조
```
my-card-service/
├── backend/
│   ├── main.go
│   ├── go.mod
│   ├── go.sum
│   ├── Dockerfile
│   └── k8s/
│       ├── deployment.yaml
│       └── service.yaml
└── frontend/ (기존 React)
```

### 🐹 Go 서버 코드 (main.go)

```go
package main

import (
    "fmt"
    "log"
    "github.com/gofiber/fiber/v2"
    "github.com/gofiber/fiber/v2/middleware/cors"
)

// 명함 데이터 구조체
type BusinessCardRequest struct {
    Name    string `json:"name"`
    Company string `json:"company"`
    Phone   string `json:"phone"`
    Email   string `json:"email"`
}

func main() {
    app := fiber.New()

    // CORS 설정 (프론트엔드 통신 허용)
    app.Use(cors.New(cors.Config{
        AllowOrigins: "*",
        AllowHeaders: "Origin, Content-Type, Accept",
    }))

    // 기본 경로
    app.Get("/", func(c *fiber.Ctx) error {
        return c.SendString("안녕? 나는 Go 주방장이야! 👨‍🍳")
    })

    // 명함 생성 API
    app.Post("/api/card", func(c *fiber.Ctx) error {
        card := new(BusinessCardRequest)

        if err := c.BodyParser(card); err != nil {
            return c.Status(400).JSON(fiber.Map{
                "error": "데이터 형식이 올바르지 않습니다",
            })
        }

        fmt.Printf("📢 명함 주문: %s, %s\n", card.Name, card.Company)

        return c.JSON(fiber.Map{
            "status":  "success",
            "message": "명함이 성공적으로 접수되었습니다!",
            "data":    card,
        })
    })

    log.Fatal(app.Listen(":8000"))
}
```

### 🔧 핵심 포인트
1. **Fiber 프레임워크**: Go에서 가장 빠른 웹 프레임워크 중 하나
2. **CORS 설정**: 프론트엔드(Netlify)와 통신을 위한 필수 설정
3. **구조체 활용**: JSON 데이터를 Go 구조체로 매핑

---

## 3. Docker 이미지 빌드

### 🐳 Dockerfile (멀티스테이지 빌드)

```dockerfile
# 1단계: 빌드 환경
FROM golang:1.25-alpine AS builder

WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN go build -o main .

# 2단계: 실행 환경
FROM alpine:latest
WORKDIR /root/
COPY --from=builder /app/main .
EXPOSE 8000
CMD ["./main"]
```

### 📊 이미지 최적화 결과
- **빌드 전 크기**: ~800MB (golang:alpine 포함)
- **빌드 후 크기**: 18.3MB (실행 파일만)
- **최적화 비율**: 97% 용량 절약

### 🛠️ 빌드 명령어
```bash
# 이미지 빌드
docker build -t go-backend .

# 로컬 실행 테스트
docker run -d -p 8080:8000 --name my-server go-backend

# 접속 확인
curl http://localhost:8080/
```

---

## 4. 이미지 전송 및 배포

### 🚚 이미지 전송 방법

#### 방법 1: Docker Hub (권장)
```bash
# 태깅
docker tag go-backend:latest username/go-backend:1.0

# 업로드
docker push username/go-backend:1.0
```

#### 방법 2: 수동 전송 (폐쇄망)
```bash
# 맥북에서 이미지 추출
docker save -o go-backend.tar go-backend:latest

# 서버로 전송
scp go-backend.tar root@100.107.101.20:/root/

# 서버에서 로드
docker load -i go-backend.tar
```

### 💡 실습 경험
- **문제**: OrbStack(로컬)과 원격 K8s 클러스터 간 이미지 공유 불가
- **해결**: `docker save/load` 방식으로 수동 전송
- **학습**: 실제 환경에서는 Container Registry의 중요성 체감

---

## 5. Kubernetes 배포

### ☸️ CKA 스타일 명령어

```bash
# Deployment 생성 (명령형)
kubectl create deployment go-chef \
  --image=go-backend:latest \
  --replicas=1 \
  --port=8000 \
  --dry-run=client -o yaml > go-chef.yaml

# Service 생성
kubectl expose deployment go-chef \
  --type=NodePort \
  --port=8000 \
  --name=go-chef-svc \
  --dry-run=client -o yaml > service.yaml
```

### 📄 Deployment YAML 수정

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: go-chef
spec:
  replicas: 1
  selector:
    matchLabels:
      app: go-chef
  template:
    metadata:
      labels:
        app: go-chef
    spec:
      containers:
      - name: go-backend
        image: go-backend:latest
        imagePullPolicy: Never  # 로컬 이미지 사용 (중요!)
        ports:
        - containerPort: 8000
```

### 🚀 배포 실행
```bash
# 배포
kubectl apply -f go-chef.yaml

# 상태 확인
kubectl get pods
kubectl get pods -o wide
```

---

## 6. 핵심 학습 포인트

### 🎯 기술적 성과

#### 컨테이너화 (Containerization)
- **멀티스테이지 빌드**: 용량 최적화 (800MB → 18MB)
- **이미지 포터빌리티**: "내 컴퓨터에서만 돌아가는" 문제 해결

#### 네트워크 이해
- **포트 매핑**: 호스트 포트 ↔ 컨테이너 포트 개념
- **CORS 정책**: 프론트엔드-백엔드 통신 설정

#### CKA 시험 대비
- **명령형 명령어**: `kubectl create ... --dry-run=client -o yaml`
- **트러블슈팅**: 이미지 정책, 네트워크 설정

### 🧠 아키텍처 사고

#### Cloud Native 패턴
1. **관심사 분리**: 프론트엔드(Netlify) vs 백엔드(K8s) 역할 분담
2. **확장성**: Stateless 서버로 수평 확장 가능
3. **이식성**: 어떤 K8s 클러스터에서도 동일하게 동작

#### DevOps 파이프라인 이해
```
코드 작성 → 도커 빌드 → 이미지 전송 → K8s 배포 → 서비스 노출
```

### 🚨 트러블슈팅 경험

| 문제 | 원인 | 해결책 |
|------|------|--------|
| Go 버전 불일치 | Dockerfile golang:1.23 vs go.mod 1.24+ | golang:1.25-alpine 사용 |
| 포트 연결 실패 | 8080:8080 매핑 vs 실제 8000 포트 | 8080:8000으로 수정 |
| 이미지 Not Found | 로컬 이미지가 K8s 클러스터에 없음 | imagePullPolicy: Never + 수동 전송 |

### 💡 다음 단계

#### 즉시 실습 가능
1. **Service 설정**: NodePort/LoadBalancer로 외부 접근
2. **ConfigMap**: 환경 변수 분리
3. **Secret**: API 키 등 민감 정보 관리

#### 중급 과정
1. **Persistent Volume**: DB 연동 시 데이터 영속성
2. **Ingress Controller**: 도메인 기반 라우팅
3. **HPA**: 자동 스케일링 설정

---

## 🏆 결론

이번 실습을 통해 **"BaaS 의존"**에서 **"Cloud Native"**로의 전환 첫 단계를 완료했습니다.

특히 **"네트워크 뚫기"**가 진짜 엔지니어링 실력의 핵심임을 체감했고, Docker + Kubernetes의 조합이 왜 현대 개발의 표준인지 이해하게 되었습니다.

다음 목표는 이 백엔드에 **데이터베이스를 연결**하고, **CI/CD 파이프라인**을 구축하여 완전한 Cloud Native 애플리케이션을 완성하는 것입니다.

---

> 🎓 **CKA 시험 TIP**: 이번 실습의 모든 명령어(create, expose, apply)는 CKA 시험 필수 스킬입니다. 특히 `--dry-run=client -o yaml` 패턴을 체화하세요!