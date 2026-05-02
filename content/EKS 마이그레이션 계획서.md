---
title: ECS Fargate → EKS 마이그레이션 계획서
tags:
  - EKS
  - Kubernetes
  - 마이그레이션
  - AWS
  - MSA
aliases:
  - 쿠버네티스 마이그레이션
  - EKS 계획
date: 2026-04-27
category: 프로젝트/인프라
status: 계획중
priority: 높음
---

# 🎯 ECS Fargate → EKS 마이그레이션 계획서

## 📑 목차
- [[#1. 마이그레이션 개요|마이그레이션 개요]]
- [[#2. 현재 아키텍처 (ECS Fargate)|현재 아키텍처 (ECS Fargate)]]
- [[#3. 목표 아키텍처 (EKS)|목표 아키텍처 (EKS)]]
- [[#4. 마이그레이션 이유|마이그레이션 이유]]
- [[#5. 마이그레이션 전략|마이그레이션 전략]]
- [[#6. 단계별 실행 계획|단계별 실행 계획]]
- [[#7. 기술 스택|기술 스택]]
- [[#8. 리스크 관리|리스크 관리]]

---

## 1. 마이그레이션 개요: ECS → EKS 전환

> [!note] 핵심 개념
> 현재 **ECS Fargate**로 운영되는 마이크로서비스를 **Amazon EKS (Elastic Kubernetes Service)**로 마이그레이션하여 Kubernetes 생태계의 장점을 활용합니다.

### 💡 마이그레이션 범위

#### 📋 범위 정의

| 항목 | 현재 (ECS) | 목표 (EKS) |
|------|------------|-----------|
| **컨테이너 오케스트레이션** | AWS ECS Fargate | Amazon EKS |
| **서비스 수** | 4개 (api-gateway, user, product, order) | 4개 (동일) |
| **서비스 디스커버리** | AWS Cloud Map | Kubernetes Service + CoreDNS |
| **로드 밸런싱** | AWS ALB | AWS Load Balancer Controller |
| **인그레스** | ALB + CloudFront | ALB Ingress Controller |
| **CI/CD** | CodePipeline + CodeBuild | CodePipeline + CodeBuild + kubectl/helm |
| **모니터링** | CloudWatch Logs | CloudWatch + Prometheus + Grafana |

---

## 2. 현재 아키텍처 (ECS Fargate)

> [!note] 현재 구조
> ECS Fargate를 사용하여 4개의 마이크로서비스가 배포되어 있습니다.

### 💡 현재 아키텍처 다이어그램

#### 📋 트래픽 흐름 (현재)

```
사용자
  │
  ▼
CloudFront (CDN)
  │
  ├─ /api/*  ──────────────► IGW ──► ALB ──► ECS Service (API Gateway)
  │                                             │
  │                                             ▼
  │                                    Cloud Map (Service Discovery)
  │                                             │
  │                        ┌────────────────────┼────────────────────┐
  │                        ▼                    ▼                    ▼
  │                 User Service        Product Service        Order Service
  │                   (Fargate)           (Fargate)            (Fargate)
  │                        │                    │                    │
  │                        ▼                    ▼                    ▼
  │                   RDS PostgreSQL     ElastiCache Redis      (기타)
  │                  (Private Subnet)   (Private Subnet)
  │
  └─ /*  ──────────────────► S3 (프론트엔드)
```

---

### 💡 현재 구성 요소

#### 📋 ECS 리소스 현황

| 리소스 | 상태 | 설명 |
|--------|------|------|
| **ECS Cluster** | ✅ | pposiraegi-cluster |
| **ECS Task Definitions** | ✅ | 4개 서비스용 태스크 정의 |
| **ECS Services** | ✅ | 4개 서비스 배포 완료 |
| **Cloud Map** | ✅ | pposiraegi.internal 네임스페이스 |
| **ECR Repositories** | ✅ | 4개 서비스용 레포지토리 |
| **CloudWatch Logs** | ✅ | 서비스별 로그 그룹 |

---

## 3. 목표 아키텍처 (EKS)

> [!note] 목표 구조
> EKS 클러스터를 사용하여 Kubernetes 네이티브 방식으로 마이크로서비스를 배포합니다.

### 💡 목표 아키텍처 다이어그램

#### 📋 트래픽 흐름 (목표)

```
사용자
  │
  ▼
CloudFront (CDN)
  │
  ├─ /api/*  ──────────────► IGW ──► ALB ──► Ingress Controller (NGINX/AWS LB)
  │                                             │
  │                                             ▼
  │                                    EKS Cluster (pposiraegi-eks)
  │                                             │
  │                    ┌────────────────────────┼────────────────────────┐
  │                    ▼                        ▼                        ▼
  │              api-gateway              user-service            product-service
  │              (Deployment)             (Deployment)           (Deployment)
  │                    │                        │                        │
  │                    ▼                        ▼                        ▼
  │              order-service              (기타 서비스)            (기타)
  │              (Deployment)
  │
  └─ /*  ──────────────────► S3 (프론트엔드)

외부 리소스 연동
  │
  ├─ RDS PostgreSQL ──────────────────────────────────────────────────────►
  ├─ ElastiCache Redis ───────────────────────────────────────────────────►
  ├─ SSM Parameter Store ─────────────────────────────────────────────────►
  └─ CloudWatch Logs ────────────────────────────────────────────────────►
```

---

### 💡 EKS 구성 요소

#### 📋 Kubernetes 리소스 계획

| 리소스 | 상태 | 설명 |
|--------|------|------|
| **EKS Cluster** | 🟡 계획중 | pposiraegi-eks 클러스터 생성 |
| **Node Groups** | 🟡 계획중 | Managed Node Group (Fargate Profile도 고려) |
| **Namespaces** | 🟡 계획중 | pposiraegi 네임스페이스 |
| **Deployments** | 🟡 계획중 | 4개 서비스용 Deployment |
| **Services** | 🟡 계획중 | ClusterIP, LoadBalancer Service |
| **ConfigMaps** | 🟡 계획중 | 애플리케이션 설정 |
| **Secrets** | 🟡 계획중 | SSM Parameter Store 통합 (External Secrets Operator) |
| **Ingress** | 🟡 계획중 | AWS Load Balancer Controller |

---

## 4. 마이그레이션 이유

> [!note] 왜 EKS인가?
> Kubernetes 생태계의 장점과 장기적인 확장성을 위해 EKS로 마이그레이션합니다.

### 💡 기술적 이유

#### 📋 EKS의 장점

| 장점 | 설명 | 효과 |
|------|------|------|
| **Kubernetes 생태계** | 방대한 오픈소스 도구 활용 가능 | Helm, ArgoCD, Prometheus 등 |
| **포터빌리티** | 표준 Kubernetes API 사용 | 클라우드 간 이동 용이 |
| **고급 기능** | HPA, Pod Disruption Budget 등 | 자동 스케일링 고도화 |
| **커뮤니티** | 활발한 커뮤니티 지원 | 문제 해결 용이 |
| **GitOps** | ArgoCD, Flux 등 활용 | 선언적 배포 가능 |
| **멀티 클라우드** | 하이브리드 클라우드 구현 가능 | 공급업체 종속성 감소 |

---

### 💡 비즈니스 이유

#### 📋 비즈니스 가치

| 이유 | 설명 |
|------|------|
| **개발 생산성 향상** | Kubernetes 도구 생태계 활용 |
| **운영 효율성** | GitOps로 자동화 강화 |
| **확장성** | 대규모 서비스 확장 용이 |
| **인재 확보** | Kubernetes 스킬 보유 |
| **장기적 비용** | 오픈소스 도구로 비용 절감 가능 |

---

## 5. 마이그레이션 전략

> [!note] 전략 개요
> 점진적 마이그레이션을 통해 리스크를 최소화합니다.

### 💡 마이그레이션 접근법

#### 📋 전략 옵션

| 전략 | 설명 | 장점 | 단점 |
|------|------|------|------|
| **Big Bang** | 한 번에 전체 마이그레이션 | 빠른 완료 | 높은 리스크 |
| **Phased (점진적)** | 서비스별 순차적 마이그레이션 | 리스크 분산 | 긴 기간 |
| **Side-by-Side** | ECS와 EKS 병행 운영 | 롤백 용이 | 복잡한 운영 |

---

### 💡 선택 전략: Phased (점진적 마이그레이션)

#### 📋 마이그레이션 단계

```
Phase 1: EKS 클러스터 설정
  ├─ EKS 클러스터 생성
  ├─ Node Group 설정
  ├─ AWS Load Balancer Controller 설치
  └─ External Secrets Operator 설치

Phase 2: 첫 번째 서비스 마이그레이션 (user-service)
  ├─ Kubernetes 매니페스트 작성
  ├─ Helm Chart 작성
  ├─ 테스트 배포
  └─ 트래픽 전환

Phase 3: 나머지 서비스 마이그레이션
  ├─ product-service
  ├─ order-service
  └─ api-gateway (마지막)

Phase 4: ECS 리소스 정리
  ├─ 모든 서비스 마이그레이션 확인
  ├─ ECS 리소스 삭제
  └─ Cloud Map 삭제

Phase 5: 운영 최적화
  ├─ HPA 설정
  ├─ Prometheus + Grafana 설치
  └─ ArgoCD 설치 (GitOps)
```

---

## 6. 단계별 실행 계획

> [!note] 실행 계획
> 총 5단계로 나누어 마이그레이션을 진행합니다.

### 💡 Phase 1: EKS 클러스터 설정 (3일)

#### 📋 작업 목록

| 작업 | 예상 시간 | 난이도 | 담당자 |
|------|-----------|--------|--------|
| **EKS 모듈 Terraform 작성** | 1일 | 🔴 높음 | 인프라 팀 |
| **EKS 클러스터 생성** | 0.5일 | 🟡 중간 | 인프라 팀 |
| **Node Group 설정** | 0.5일 | 🟡 중간 | 인프라 팀 |
| **AWS Load Balancer Controller 설치** | 0.5일 | 🟡 중간 | 인프라 팀 |
| **External Secrets Operator 설치** | 0.5일 | 🟡 중간 | 인프라 팀 |

#### 💻 Terraform 구조

```hcl
# infrastructure/modules/eks/main.tf
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name    = var.cluster_name
  cluster_version = "1.28"

  vpc_id          = var.vpc_id
  subnet_ids      = var.private_subnet_ids

  eks_managed_node_groups = {
    main = {
      instance_types = ["t3.medium"]
      min_size     = 1
      max_size     = 3
      desired_size = 2
    }
  }

  enable_irsa = true  # IAM Roles for Service Accounts
}
```

---

### 💡 Phase 2: 첫 번째 서비스 마이그레이션 (2일)

#### 📋 작업 목록

| 작업 | 예상 시간 | 난이도 | 담당자 |
|------|-----------|--------|--------|
| **user-service Kubernetes 매니페스트 작성** | 0.5일 | 🟡 중간 | 백엔드 팀 |
| **Helm Chart 작성** | 0.5일 | 🟡 중간 | 백엔드 팀 |
| **테스트 배포** | 0.5일 | 🟢 쉬움 | 전체 |
| **트래픽 전환** | 0.5일 | 🟡 중간 | 인프라 팀 |

#### 💻 Kubernetes 매니페스트 예시

```yaml
# user-service/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: user-service
  namespace: pposiraegi
spec:
  replicas: 2
  selector:
    matchLabels:
      app: user-service
  template:
    metadata:
      labels:
        app: user-service
    spec:
      containers:
      - name: user-service
        image: <ECR_URL>/user-service:latest
        ports:
        - containerPort: 8080
        env:
        - name: DB_HOST
          valueFrom:
            secretKeyRef:
              name: user-service-secrets
              key: db-host
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: user-service-secrets
              key: db-password
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
          limits:
            memory: "1Gi"
            cpu: "500m"
```

```yaml
# user-service/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: user-service
  namespace: pposiraegi
spec:
  selector:
    app: user-service
  ports:
  - port: 8080
    targetPort: 8080
  type: ClusterIP
```

---

### 💡 Phase 3: 나머지 서비스 마이그레이션 (3일)

#### 📋 작업 목록

| 서비스 | 예상 시간 | 난이도 | 담당자 |
|--------|-----------|--------|--------|
| **product-service** | 0.75일 | 🟡 중간 | 백엔드 팀 |
| **order-service** | 0.75일 | 🟡 중간 | 백엔드 팀 |
| **api-gateway** | 1일 | 🔴 높음 | 백엔드 팀 |
| **통합 테스트** | 0.5일 | 🟡 중간 | QA 팀 |

#### 💻 Ingress 설정

```yaml
# ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: api-gateway-ingress
  namespace: pposiraegi
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
spec:
  rules:
  - host: api.pposiraegi.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: api-gateway
            port:
              number: 8080
```

---

### 💡 Phase 4: ECS 리소스 정리 (1일)

#### 📋 작업 목록

| 작업 | 예상 시간 | 난이도 | 담당자 |
|------|-----------|--------|--------|
| **모든 서비스 마이그레이션 확인** | 0.25일 | 🟢 쉬움 | 전체 |
| **ECS 리소스 삭제** | 0.25일 | 🟡 중간 | 인프라 팀 |
| **Cloud Map 삭제** | 0.25일 | 🟡 중간 | 인프라 팀 |
| **최종 테스트** | 0.25일 | 🟡 중간 | QA 팀 |

---

### 💡 Phase 5: 운영 최적화 (3일)

#### 📋 작업 목록

| 작업 | 예상 시간 | 난이도 | 담당자 |
|------|-----------|--------|--------|
| **HPA (Horizontal Pod Autoscaler) 설정** | 0.5일 | 🟡 중간 | 인프라 팀 |
| **Prometheus + Grafana 설치** | 1일 | 🔴 높음 | 인프라 팀 |
| **ArgoCD 설치 (GitOps)** | 1일 | 🔴 높음 | 인프라 팀 |
| **문서화** | 0.5일 | 🟢 쉬움 | 전체 |

#### 💻 HPA 설정 예시

```yaml
# hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: user-service-hpa
  namespace: pposiraegi
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: user-service
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

---

## 7. 기술 스택

> [!note] 기술 스택
> EKS 마이그레이션에 필요한 기술 스택입니다.

### 💡 코어 기술

#### 📋 Kubernetes 구성

| 기술 | 용도 | 버전 |
|------|------|------|
| **Amazon EKS** | Kubernetes 클러스터 | 1.28+ |
| **eksctl** | EKS 클러스터 관리 | 최신 |
| **kubectl** | Kubernetes 클러스터 조작 | 1.28+ |
| **Helm** | 패키지 매니저 | 3.x |
| **Kustomize** | 매니페스트 커스터마이징 | 최신 |

---

### 💻 AWS 리소스

#### 📋 AWS 구성 요소

| 리소스 | 용도 | 설정 |
|--------|------|------|
| **EKS Cluster** | Kubernetes 제어 플레인 | Managed |
| **Node Group** | Worker Nodes | t3.medium x 2~3 |
| **ALB** | 외부 트래픽 로드 밸런싱 | Internet-facing |
| **NLB** | 내부 서비스 로드 밸런싱 | Internal |
| **RDS PostgreSQL** | 데이터베이스 | 기존 활용 |
| **ElastiCache Redis** | 캐시 | 기존 활용 |
| **SSM Parameter Store** | 시크릿 관리 | External Secrets |
| **CloudWatch** | 로그 및 메트릭 | Container Insights |

---

### 💻 애드온 및 컨트롤러

#### 📋 필수 애드온

| 애드온 | 용도 | 설치 방법 |
|--------|------|-----------|
| **AWS Load Balancer Controller** | ALB/NLB 통합 | Helm |
| **External Secrets Operator** | SSM Parameter Store 통합 | Helm |
| **Metrics Server** | HPA 메트릭 수집 | kubectl |
| **Cluster Autoscaler** | 노드 자동 스케일링 | Helm |
| **Prometheus Adapter** | 커스텀 메트릭 | Helm |

---

### 💻 모니터링 및 관리

#### 📋 운영 도구

| 도구 | 용도 | 우선순위 |
|------|------|----------|
| **Prometheus** | 메트릭 수집 | 높음 |
| **Grafana** | 대시보드 | 높음 |
| **ArgoCD** | GitOps 배포 | 중간 |
| **Loki** | 로그 집계 | 중간 |
| **Jaeger** | 분산 추적 | 낮음 |

---

## 8. 리스크 관리

> [!note] 리스크 관리
> 마이그레이션 과정에서 발생할 수 있는 리스크와 완화 방안입니다.

### 💡 주요 리스크

#### 📋 리스크 매트릭스

| 리스크 | 확률 | 영향 | 완화 방안 |
|--------|------|------|-----------|
| **서비스 중단** | 중간 | 높음 | 점진적 마이그레이션, 롤백 계획 |
| **성능 저하** | 중간 | 중간 | 부하 테스트, 모니터링 강화 |
| **비용 증가** | 높음 | 중간 | 비용 최적화, Right Sizing |
| **팀 학습 곡선** | 높음 | 중간 | 교육, 문서화, 멘토링 |
| **보안 이슈** | 낮음 | 높음 | IRSA, Network Policies, Pod Security Standards |

---

### 💻 롤백 계획

#### 📋 롤백 절차

```bash
# 1. EKS 트래픽 차단
kubectl scale deployment api-gateway --replicas=0 -n pposiraegi

# 2. ECS 서비스 스케일업
aws ecs update-service --cluster pposiraegi-cluster \
  --service pposiraegi-api-gateway-service \
  --desired-count 1

# 3. ALB 타겟 그룹 변경
# AWS 콘솔에서 EKS 타겟 그룹에서 ECS 타겟 그룹으로 변경

# 4. DNS 확인
nslookup api.pposiraegi.com

# 5. 로그 확인
aws logs tail /ecs/pposiraegi-api-gateway --follow
```

---

## 📊 요약

### 🎯 마이그레이션 일정

| 단계 | 기간 | 주요 작업 |
|------|------|-----------|
| **Phase 1** | 3일 | EKS 클러스터 설정 |
| **Phase 2** | 2일 | user-service 마이그레이션 |
| **Phase 3** | 3일 | 나머지 서비스 마이그레이션 |
| **Phase 4** | 1일 | ECS 리소스 정리 |
| **Phase 5** | 3일 | 운영 최적화 |
| **총 기간** | **12일** | 약 2주 |

### ✅ 성공 기준

1. **가용성**: 99.9% 이상 유지
2. **성능**: 기존과 동등하거나 개선
3. **롤백 시간**: 30분 이내
4. **팀 숙련도**: 팀원 80% 이상이 Kubernetes 기본 운영 가능

### 🎯 다음 단계

1. **EKS 모듈 Terraform 작성 시작**
2. **팀 교육 (Kubernetes 기초)**
3. **테스트 환경 구축**
4. **사용자 승인 획득**

---

## 📞 연락처 및 참고 자료

> [!tip] 참고 리소스
> - **저장소**: https://github.com/Goorm4I/pposiraegi-ecommerce
> - **EKS 공식 문서**: https://docs.aws.amazon.com/eks/
> - **Kubernetes 공식 문서**: https://kubernetes.io/docs/
> - **Helm 문서**: https://helm.sh/docs/

### 💻 주요 명령어

```bash
# EKS 클러스터 생성
eksctl create cluster --name pposiraegi-eks --region ap-northeast-2

# kubectl 컨텍스트 설정
aws eks update-kubeconfig --name pposiraegi-eks --region ap-northeast-2

# Helm 리포지토리 추가
helm repo add eks https://aws.github.io/eks-charts
helm repo update

# AWS Load Balancer Controller 설치
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system --set clusterName=pposiraegi-eks

# External Secrets Operator 설치
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets external-secrets/external-secrets \
  -n external-secrets --create-namespace

# 배포
kubectl apply -f user-service/deployment.yaml
kubectl apply -f user-service/service.yaml

# 상태 확인
kubectl get pods -n pposiraegi
kubectl get services -n pposiraegi
kubectl logs -f deployment/user-service -n pposiraegi
```

---

> [!warning] 주의사항
> 1. 반드시 테스트 환경에서 먼저 검증하세요.
> 2. 롤백 계획을 미리 준비하고 팀원과 공유하세요.
> 3. 비용 모니터링을 실시간으로 수행하세요.
> 4. 보안 그룹 및 IAM 권한을 최소 원칙으로 설정하세요.