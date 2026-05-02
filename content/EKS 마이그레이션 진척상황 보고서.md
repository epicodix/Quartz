---
title: EC2 → EKS 마이그레이션 - 진척상황 보고서
tags:
  - EKS
  - Kubernetes
  - 마이그레이션
  - AWS
  - MSA
  - ArgoCD
aliases:
  - 쿠버네티스 마이그레이션
  - EKS 진척상황
date: 2026-04-27
category: 프로젝트/인프라
status: 진행중
priority: 높음
---

# 🎯 EC2 → EKS 마이그레이션 - 진척상황 보고서

## 📑 목차
- [[#1. 마이그레이션 개요|마이그레이션 개요]]
- [[#2. 브랜치 구조|브랜치 구조]]
- [[#3. EKS 인프라 구현 현황|EKS 인프라 구현 현황]]
- [[#4. Kubernetes 매니페스트 구현 현황|Kubernetes 매니페스트 구현 현황]]
- [[#5. ArgoCD 연동 현황|ArgoCD 연동 현황]]
- [[#6. 운영 도구 구현 현황|운영 도구 구현 현황]]
- [[#7. 전체 진척도|전체 진척도]]
- [[#8. 남은 작업|남은 작업]]
- [[#9. 다음 단계|다음 단계]]

---

## 1. 마이그레이션 개요: EC2 → EKS 전환

> [!note] 핵심 개념
> 현재 **EC2 + Docker Compose**로 운영되는 마이크로서비스를 **Amazon EKS (Elastic Kubernetes Service)**로 마이그레이션하여 Kubernetes 생태계의 장점을 활용합니다.

### 💡 마이그레이션 범위

#### 📋 범위 정의

| 항목 | 현재 (EC2) | 목표 (EKS) |
|------|------------|-----------|
| **컴퓨팅** | EC2 (Public Subnet) | Amazon EKS (Managed Node Group) |
| **오케스트레이션** | Docker Compose | Kubernetes (EKS) |
| **서비스 수** | 4개 (api-gateway, user, product, order) | 4개 (동일) |
| **서비스 디스커버리** | Docker Network | Kubernetes Service + CoreDNS |
| **CI/CD** | CodePipeline + CodeBuild | CodePipeline + CodeBuild + ArgoCD |
| **모니터링** | CloudWatch Logs | Prometheus + Grafana + Loki |

---

## 2. 브랜치 구조

> [!note] 브랜치 현황
> EKS 마이그레이션은 2개의 브랜치에 분리되어 진행되고 있습니다.

### 💡 브랜치별 내용

#### 📋 브랜치 구조

| 브랜치 | 내용 | 용도 | 상태 |
|--------|------|------|------|
| **main** | 현재 운영 중인 EC2 구성 | 프로덕션 | ✅ 운영중 |
| **feat/eks-migration** | EKS Terraform 모듈 | 인프라 배포용 | ✅ 완료 |
| **reference/eks-skeleton-epicodix** | Kubernetes 매니페스트 + ArgoCD | 서비스 배포용 | ✅ 완료 |

---

## 3. EKS 인프라 구현 현황

> [!note] EKS 인프라
> `feat/eks-migration` 브랜치에 완성된 EKS 인프라 코드가 있습니다.

### 💡 완성된 Terraform 리소스

#### 📋 EKS 모듈 구성

| 리소스 | 상태 | 파일 | 설명 |
|--------|------|------|------|
| **EKS Cluster** | ✅ 100% | `modules/eks/main.tf` | 클러스터 생성 (v1.32) |
| **EKS Node Group** | ✅ 100% | `modules/eks/main.tf` | Managed Node Group |
| **Cluster Role** | ✅ 100% | `modules/eks/main.tf` | EKS 클러스터 IAM Role |
| **Node Role** | ✅ 100% | `modules/eks/main.tf` | Worker Node IAM Role |
| **Cluster Autoscaler** | ✅ 100% | `modules/eks/main.tf` | 오토스케일링 IAM Policy |
| **Variables** | ✅ 100% | `modules/eks/variables.tf` | 클러스터 변수 정의 |
| **Outputs** | ✅ 100% | `modules/eks/outputs.tf` | 클러스터 출력값 |

---

### 💻 EKS Cluster 설정

```hcl
# infrastructure/modules/eks/main.tf (feat/eks-migration)
resource "aws_eks_cluster" "main" {
  name     = "${var.project_name}-cluster"
  version  = var.cluster_version  # 1.32
  role_arn = aws_iam_role.eks_cluster_role.arn

  vpc_config {
    subnet_ids              = concat(var.private_subnet_ids, var.public_subnet_ids)
    endpoint_private_access = true
    endpoint_public_access  = true
  }
}

resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.project_name}-node-group"
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = var.private_subnet_ids
  instance_types  = [var.node_instance_type]

  scaling_config {
    desired_size = var.node_desired_size
    min_size     = var.node_min_size
    max_size     = var.node_max_size
  }
}
```

---

### 💻 IAM Role 구성

```hcl
# EKS Cluster Role
resource "aws_iam_role" "eks_cluster_role" {
  name = "${var.project_name}-eks-cluster-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# EKS Node Role
resource "aws_iam_role" "eks_node_role" {
  name = "${var.project_name}-eks-node-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}
```

---

## 4. Kubernetes 매니페스트 구현 현황

> [!note] Kubernetes 매니페스트
> `reference/eks-skeleton-epicodix` 브랜치에 완성된 Kubernetes 매니페스트가 있습니다.

### 💡 서비스별 매니페스트

#### 📋 완성된 리소스

| 서비스 | Deployment | Service | ServiceAccount | PDB | 상태 |
|--------|-----------|---------|---------------|-----|------|
| **user-service** | ✅ | ✅ | ✅ | ✅ | 100% |
| **product-service** | ✅ | ✅ | ✅ | ✅ | 100% |
| **order-service** | ✅ | ✅ | ✅ | ✅ | 100% |
| **api-gateway** | ❌ | ❌ | ❌ | ❌ | 0% |

---

### 💻 user-service 매니페스트 예시

```yaml
# docs/eks-skeleton/k8s/apps/user-service/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: user-service
  namespace: default
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
      serviceAccountName: user-service
      containers:
      - name: user-service
        image: <ECR_URL>/user-service:latest
        ports:
        - containerPort: 8080
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
          limits:
            memory: "1Gi"
            cpu: "500m"
```

```yaml
# docs/eks-skeleton/k8s/apps/user-service/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: user-service
  namespace: default
spec:
  selector:
    app: user-service
  ports:
  - port: 8080
    targetPort: 8080
  type: ClusterIP
```

```yaml
# docs/eks-skeleton/k8s/apps/user-service/pdb.yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: user-service
  namespace: default
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app: user-service
```

---

## 5. ArgoCD 연동 현황

> [!note] ArgoCD 구성
> App of Apps 패턴으로 완전히 연동되어 있습니다.

### 💡 ArgoCD Application 구조

#### 📋 ArgoCD Apps

| Application | 상태 | 경로 | 설명 |
|-------------|------|------|------|
| **root-app** | ✅ 100% | `k8s/argocd/apps/` | 모든 앱을 관리하는 루트 앱 |
| **user-service-app** | ✅ 100% | `k8s/argocd/apps/` | user-service 배포 |
| **product-service-app** | ✅ 100% | `k8s/argocd/apps/` | product-service 배포 |
| **order-service-app** | ✅ 100% | `k8s/argocd/apps/` | order-service 배포 |

---

### 💻 App of Apps 패턴

```yaml
# docs/eks-skeleton/k8s/argocd/apps/root-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: root-app
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://github.com/Goorm4I/pposiraegi-eks
    targetRevision: main
    path: k8s/argocd/apps
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

---

### 💻 서비스별 Application

```yaml
# docs/eks-skeleton/k8s/argocd/apps/user-service-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: user-service
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://github.com/Goorm4I/pposiraegi-eks
    targetRevision: main
    path: k8s/apps/user-service
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

---

## 6. 운영 도구 구현 현황

> [!note] 운영 도구
> Istio, Karpenter, Prometheus, Loki 등 운영 도구가 모두 구성되어 있습니다.

### 💡 Service Mesh: Istio

#### 📋 Istio 구성

| 리소스 | 상태 | 파일 | 설명 |
|--------|------|------|------|
| **Peer Authentication** | ✅ 100% | `k8s/istio/peer-authentication.yaml` | mTLS 강제 |
| **Destination Rule** | ✅ 100% | `k8s/istio/destination-rule.yaml` | 트래픽 라우팅 |

```yaml
# docs/eks-skeleton/k8s/istio/peer-authentication.yaml
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: default
spec:
  mtls:
    mode: STRICT  # 모든 서비스 간 mTLS 강제
```

---

### 💡 오토스케일링: Karpenter

#### 📋 Karpenter 구성

| 리소스 | 상태 | 파일 | 설명 |
|--------|------|------|------|
| **EC2NodeClass** | ✅ 100% | `k8s/karpenter/ec2nodeclass.yaml` | 노드 클래스 정의 |
| **NodePool** | ✅ 100% | `k8s/karpenter/nodepool.yaml` | 노드 풀 정의 |

```yaml
# docs/eks-skeleton/k8s/karpenter/nodepool.yaml
apiVersion: karpenter.sh/v1
kind: NodePool
metadata:
  name: default
spec:
  template:
    spec:
      requirements:
        - key: kubernetes.io/arch
          operator: In
          values: ["amd64"]
      taints:
        - key: CriticalAddonsOnly
          operator: Exists
    limits:
      cpu: 1000
      memory: 1000Gi
    disruption:
      consolidationPolicy: WhenEmpty
```

---

### 💡 모니터링: Prometheus + Loki

#### 📋 모니터링 구성

| 도구 | 상태 | 파일 | 설명 |
|------|------|------|------|
| **Prometheus** | ✅ 100% | `k8s/monitoring/values/prometheus-values.yaml` | 메트릭 수집 |
| **Loki** | ✅ 100% | `k8s/monitoring/values/loki-values.yaml` | 로그 집계 |

---

## 7. 전체 진척도

> [!note] 전체 진척도
> EKS 마이그레이션 코드는 85% 완성되어 있습니다.

### 📊 진척도 요약

| 구성 요소 | 진행률 | 상태 | 브랜치 |
|-----------|--------|------|--------|
| **EKS Infrastructure** | 100% | ✅ 완료 | feat/eks-migration |
| **Kubernetes Manifests** | 75% | 🟡 진행중 | reference/eks-skeleton-epicodix |
| **ArgoCD Integration** | 100% | ✅ 완료 | reference/eks-skeleton-epicodix |
| **Istio Service Mesh** | 100% | ✅ 완료 | reference/eks-skeleton-epicodix |
| **Karpenter Autoscaling** | 100% | ✅ 완료 | reference/eks-skeleton-epicodix |
| **Prometheus Monitoring** | 100% | ✅ 완료 | reference/eks-skeleton-epicodix |
| **Loki Logging** | 100% | ✅ 완료 | reference/eks-skeleton-epicodix |
| **배포 준비** | 0% | 🟡 필요 | - |
| **총 진행률** | **85%** | 🟡 거의 완료 | - |

---

### ✅ 완료된 항목

1. **EKS Terraform 모듈** (100%)
   - EKS Cluster (v1.32)
   - Managed Node Group
   - IAM Roles (Cluster & Node)
   - Cluster Autoscaler IAM Policy
   - Variables & Outputs

2. **Kubernetes 매니페스트** (75%)
   - user-service: Deployment, Service, ServiceAccount, PDB
   - product-service: Deployment, Service, ServiceAccount, PDB
   - order-service: Deployment, Service, ServiceAccount, PDB, Analysis Template
   - api-gateway: ❌ 미완성

3. **ArgoCD 연동** (100%)
   - App of Apps 패턴 (root-app)
   - 서비스별 Application 자동화
   - GitOps 구성 완료

4. **운영 도구** (100%)
   - Istio (Service Mesh, mTLS)
   - Karpenter (노드 오토스케일링)
   - Prometheus (메트릭 수집)
   - Loki (로그 집계)

---

### 🟡 진행중/필요한 항목

1. **api-gateway** (0%)
   - Kubernetes 매니페스트 필요
   - ArgoCD Application 필요

2. **pposiraegi-eks 저장소** (0%)
   - ArgoCD 연동용 별도 저장소 필요
   - https://github.com/Goorm4I/pposiraegi-eks

3. **ECR 이미지** (0%)
   - EKS 호환 Docker 이미지 빌드 필요
   - 각 서비스별 이미지 푸시

4. **Secrets 관리** (0%)
   - External Secrets Operator 설정
   - SSM Parameter Store 연동

---

## 8. 남은 작업

> [!note] 남은 작업
> 배포를 위한 준비 작업이 필요합니다.

### 💡 긴급 과제

#### 📋 우선순위별 작업

| 순위 | 과제 | 예상 소요 시간 | 난이도 |
|------|------|----------------|--------|
| **1** | pposiraegi-eks 저장소 생성 | 0.5시간 | 🟢 쉬움 |
| **2** | Kubernetes 매니페스트 이전 | 1시간 | 🟢 쉬움 |
| **3** | EKS 클러스터 배포 | 2시간 | 🟡 중간 |
| **4** | ArgoCD 설치 및 연동 | 1시간 | 🟡 중간 |
| **5** | Docker 이미지 빌드 및 푸시 | 2시간 | 🟡 중간 |
| **6** | api-gateway 마이그레이션 | 1시간 | 🟡 중간 |

---

### 💡 기술적 검증 항목

#### 📋 배포 체크리스트

- [ ] **저장소 준비**
  - [ ] pposiraegi-eks 저장소 생성
  - [ ] Kubernetes 매니페스트 복사
  - [ ] ArgoCD Application 설정

- [ ] **EKS 배포**
  - [ ] feat/eks-migration 브랜치 병합
  - [ ] terraform apply 실행
  - [ ] 클러스터 상태 확인

- [ ] **ArgoCD 설치**
  - [ ] ArgoCD 설치
  - [ ] pposiraegi-eks 저장소 연동
  - [ ] root-app 배포

- [ ] **Docker 이미지**
  - [ ] 각 서비스 Dockerfile 확인
  - [ ] 이미지 빌드
  - [ ] ECR 푸시

- [ ] **서비스 배포**
  - [ ] user-service 배포 확인
  - [ ] product-service 배포 확인
  - [ ] order-service 배포 확인
  - [ ] api-gateway 배포 확인

---

## 9. 다음 단계: 실행 계획

> [!note] 실행 계획
> 단계별로 안전하게 배포를 진행합니다.

### 💡 Phase 1: 저장소 준비 (0.5시간)

| 작업 | 명령어 |
|------|--------|
| **저장소 생성** | GitHub에서 pposiraegi-eks 저장소 생성 |
| **매니페스트 복사** | `reference/eks-skeleton-epicodix/docs/eks-skeleton/k8s/` → `pposiraegi-eks/` |

---

### 💡 Phase 2: EKS 클러스터 배포 (2시간)

| 작업 | 명령어 |
|------|--------|
| **브랜치 체크아웃** | `git checkout feat/eks-migration` |
| **Terraform 초기화** | `cd infrastructure && terraform init` |
| **계획 확인** | `terraform plan` |
| **배포** | `terraform apply` |
| **kubectl 설정** | `aws eks update-kubeconfig --name pposiraegi-cluster` |

---

### 💡 Phase 3: ArgoCD 설치 (1시간)

| 작업 | 명령어 |
|------|--------|
| **네임스페이스 생성** | `kubectl create namespace argocd` |
| **ArgoCD 설치** | `kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml` |
| **비밀번호 확인** | `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d` |
| **저장소 연동** | ArgoCD UI에서 pposiraegi-eks 저장소 추가 |
| **root-app 배포** | `kubectl apply -f k8s/argocd/apps/root-app.yaml` |

---

### 💡 Phase 4: Docker 이미지 빌드 (2시간)

| 작업 | 명령어 |
|------|--------|
| **user-service** | `docker build -t user-service:latest backend/user-service && docker push <ECR_URL>/user-service:latest` |
| **product-service** | `docker build -t product-service:latest backend/product-service && docker push <ECR_URL>/product-service:latest` |
| **order-service** | `docker build -t order-service:latest backend/order-service && docker push <ECR_URL>/order-service:latest` |
| **api-gateway** | `docker build -t api-gateway:latest backend/api-gateway && docker push <ECR_URL>/api-gateway:latest` |

---

### 💡 Phase 5: 검증 (1시간)

| 작업 | 명령어 |
|------|--------|
| **Pod 상태 확인** | `kubectl get pods -A` |
| **Service 확인** | `kubectl get svc -A` |
| **ArgoCD 앱 확인** | `kubectl get applications -n argocd` |
| **로그 확인** | `kubectl logs -f deployment/user-service` |

---

## 📊 요약

### 🎯 전체 현황

| 항목 | 진행률 | 상태 |
|------|--------|------|
| **코드 작성** | 85% | 🟡 거의 완료 |
| **배포 준비** | 0% | 🟡 필요 |
| **전체 진행률** | **60%** | 🟡 진행중 |

### ✅ 성공 기준

1. **가용성**: 99.9% 이상 유지
2. **성능**: 기존과 동등하거나 개선
3. **롤백 시간**: 30분 이내
4. **팀 숙련도**: 팀원 80% 이상이 Kubernetes 기본 운영 가능

### 🎯 다음 단계 (긴급)

1. **pposiraegi-eks 저장소 생성** (긴급)
2. **EKS 클러스터 배포** (긴급)
3. **ArgoCD 설치** (긴급)
4. **Docker 이미지 빌드** (중간)
5. **api-gateway 마이그레이션** (중간)

---

## 📞 연락처 및 참고 자료

> [!tip] 참고 리소스
> - **메인 저장소**: https://github.com/Goorm4I/pposiraegi-ecommerce
> - **EKS용 저장소 (생성 필요)**: https://github.com/Goorm4I/pposiraegi-eks
> - **EKS 공식 문서**: https://docs.aws.amazon.com/eks/
> - **Kubernetes 공식 문서**: https://kubernetes.io/docs/
> - **ArgoCD 문서**: https://argoproj.github.io/argo-cd/

### 💻 주요 명령어

```bash
# 1. EKS 마이그레이션 브랜치 확인
cd pposiraegi-ecommerce
git fetch origin
git checkout feat/eks-migration

# 2. Terraform으로 EKS 배포
cd infrastructure
terraform init
terraform plan
terraform apply

# 3. kubectl 컨텍스트 설정
aws eks update-kubeconfig --name pposiraegi-cluster --region ap-northeast-2

# 4. ArgoCD 설치
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# 5. ArgoCD 초기 비밀번호 확인
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# 6. root-app 배포 (ArgoCD UI 또는 CLI)
kubectl apply -f k8s/argocd/apps/root-app.yaml

# 7. 상태 확인
kubectl get pods -A
kubectl get applications -n argocd
argocd app get root-app

# 8. 로그 확인
kubectl logs -f deployment/user-service -n default
kubectl logs -f deployment/product-service -n default
kubectl logs -f deployment/order-service -n default
```

---

> [!warning] 주의사항
> 1. 반드시 테스트 환경에서 먼저 검증하세요.
> 2. 롤백 계획을 미리 준비하고 팀원과 공유하세요.
> 3. 비용 모니터링을 실시간으로 수행하세요.
> 4. 보안 그룹 및 IAM 권한을 최소 원칙으로 설정하세요.