---
title: MSA 인프라 모듈화 구성 평가 및 학습 우선순위
tags:
  - AWS
  - Terraform
  - MSA
  - Infrastructure
  - ECS
aliases:
  - 인프라 모듈화
  - MSA 모듈
date: 2026-04-16
category: DevOps/Infrastructure
status: 완성
priority: 높음
---

# 🎯 MSA 인프라 모듈화 구성 평가 및 학습 우선순위

## 📑 목차
- [[#1. 현재 인프라 구조 분석|현재 인프라 구조 분석]]
- [[#2. 모듈화 분석|모듈화 분석]]
- [[#3. 모듈별 중요도 및 학습 우선순위|모듈별 중요도 및 학습 우선순위]]
- [[#4. 미래 중요성 예측|미래 중요성 예측]]
- [[#5. 모듈화 권장 사항|모듈화 권장 사항]]

---

## 1. 현재 인프라 구조 분석

> [!note] 현재 상황
> 현재 `modules/` 디렉토리는 비어있으며, 모든 인프라 리소스가 `main.tf`와 `pipeline.tf`에 직접 정의되어 있습니다.

### 📊 구성된 리소스 목록

| 카테고리 | 리소스 | 설명 |
|---------|--------|------|
| 네트워킹 | VPC, Subnets, NAT Gateway, Route Tables | 퍼블릭/프라이빗 서브넷 구성 |
| 로드 밸런싱 | ALB, Target Group, Listener | 트래픽 분산 및 헬스체크 |
| 컴퓨팅 | ECS Fargate, Task Definitions, Services | 컨테이너 오케스트레이션 |
| 데이터베이스 | RDS PostgreSQL, Subnet Group | 관계형 데이터베이스 |
| 캐싱 | ElastiCache Redis, Subnet Group | 인메모리 캐싱 |
| 스토리지 | S3 (프론트엔드), CloudFront OAC | 정적 호스팅 및 CDN |
| DNS/SSL | Route53, ACM (us-east-1) | 도메인 및 인증서 관리 |
| 서비스 디스커버리 | AWS Cloud Map | 마이크로서비스 통신 |
| CI/CD | CodePipeline, CodeBuild | 자동화 배포 파이프라인 |
| 모니터링 | CloudWatch Logs | 로그 집계 |
| 보안 | Security Groups (6개) | 네트워크 접근 제어 |
| 시크릿 관리 | SSM Parameter Store | 민감 정보 관리 |
| 컨테이너 레지스트리 | ECR Repositories (4개) | Docker 이미지 저장 |

---

## 2. 모듈화 분석

### 📋 현재 상태

#### 💡 모듈화 수준: 미구현

```
infrastructure/
├── main.tf (811줄 - 모든 리소스 포함)
├── pipeline.tf (316줄 - CI/CD 리소스)
├── variables.tf
├── outputs.tf
└── modules/ (비어있음)
```

#### ⚠️ 현재 구조의 문제점

1. **유지보수 어려움**: 800줄 이상의 단일 파일
2. **재사용성 부족**: 다른 환경(dev/staging)에서 재사용 불가
3. **의존성 관리 복잡**: 모든 리소스가 한 파일에 섞여 있음
4. **테스트 어려움**: 특정 모듈만 테스트하기 어려움
5. **협업 효율성 저하**: 여러 사람이 동시에 수정하기 어려움

---

## 3. 모듈별 중요도 및 학습 우선순위

### 🚨 학습 우선순위 매트릭스

> [!tip] 평가 기준
> - **현재 중요도**: 현재 프로젝트에서의 필요성
> - **미래 중요도**: 클라우드 네이티브 트렌드에서의 중요성
> - **학습 난이도**: 1(쉬움) ~ 5(어려움)
> - **시장 가치**: 채용 시장에서의 인기도

### 📊 1순위: 필수 마스터 (즉시 학습 필요)

#### 3.1 ECS Fargate & 컨테이너 오케스트레이션

**🎯 중요도**: ⭐⭐⭐⭐⭐

| 항목 | 설명 |
|------|------|
| 현재 중요도 | 핵심 - 마이크로서비스 실행 환경 |
| 미래 중요도 | 매우 높음 - 서버리스 컨테이너 표준 |
| 학습 난이도 | 4/5 |
| 시장 가치 | 매우 높음 |

**📚 학습 포인트**
- Fargate vs EC2 Launch Type 차이
- Task Definition 구조
- Service Auto Scaling
- Health Check 구성
- Blue/Green Deployment

**🔧 실습 필수 개념**
```hcl
# 핵심 리소스 이해
- aws_ecs_cluster
- aws_ecs_task_definition
- aws_ecs_service
- aws_iam_role (execution/task role)
- aws_cloudwatch_log_group
```

**💡 질문**: "컨테이너가 비정상 종료되면 어떻게 자동 재시작되는가?"

---

#### 3.2 Terraform 모듈화 패턴

**🎯 중요도**: ⭐⭐⭐⭐⭐

| 항목 | 설명 |
|------|------|
| 현재 중요도 | 높음 - 인프라 스케일링 필수 |
| 미래 중요도 | 매우 높음 - IaC 표준 |
| 학습 난이도 | 3/5 |
| 시장 가치 | 매우 높음 |

**📚 학습 포인트**
- 모듈 구조 설계 (재사용성 고려)
- Module Outputs & Variables
- Remote State & State Lock
- Workspace 활용
- CI/CD 통합

**🔧 권장 모듈 구조**
```
modules/
├── vpc/
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
├── ecs/
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
├── rds/
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
├── redis/
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
└── networking/
    ├── main.tf
    ├── variables.tf
    └── outputs.tf
```

---

#### 3.3 Service Discovery (AWS Cloud Map)

**🎯 중요도**: ⭐⭐⭐⭐⭐

| 항목 | 설명 |
|------|------|
| 현재 중요도 | 높음 - MSA 내부 통신의 핵심 |
| 미래 중요도 | 매우 높음 - 서비스 메시 진입 필수 |
| 학습 난이도 | 3/5 |
| 시장 가치 | 높음 |

**📚 학습 포인트**
- Private DNS Namespace 구성
- Service Registration
- Health Check Custom Config
- Multi-value Routing
- gRPC 통신과의 연동

**💡 질문**: "서비스 A가 서비스 B의 IP를 어떻게 동적으로 찾는가?"

---

### 📊 2순위: 중요 마스터 (1-2개월 내)

#### 3.4 Security Groups & 네트워크 보안

**🎯 중요도**: ⭐⭐⭐⭐

| 항목 | 설명 |
|------|------|
| 현재 중요도 | 매우 높음 - 보안 핵심 |
| 미래 중요도 | 높음 - Zero Trust 진입 필수 |
| 학습 난이도 | 3/5 |
| 시장 가치 | 높음 |

**📚 학습 포인트**
- SG 규칙 설계 (최소 권한 원칙)
- Ingress/Egress 트래픽 흐름
- Self-referencing SG
- Layer 7 vs Layer 4 보안
- AWS Network Firewall 연동

**🔧 현재 SG 구조**
```
- redis_sg (6379)
- alb_sg (80)
- api_gateway_sg (8080)
- internal_msa_sg (8080, 9090)
- rds_sg (5432)
```

---

#### 3.5 SSM Parameter Store & 시크릿 관리

**🎯 중요도**: ⭐⭐⭐⭐

| 항목 | 설명 |
|------|------|
| 현재 중요도 | 높음 - 보안 필수 |
| 미래 중요도 | 높음 - Secrets Manager 이주 고려 |
| 학습 난이도 | 2/5 |
| 시장 가치 | 중간 |

**📚 학습 포인트**
- String vs SecureString
- KMS 암호화
- ECS에 secrets 전달
- 로테이션 전략
- Secrets Manager vs Parameter Store

---

#### 3.6 ALB & Target Group

**🎯 중요도**: ⭐⭐⭐⭐

| 항목 | 설명 |
|------|------|
| 현재 중요도 | 높음 - 트래픽 진입점 |
| 미래 중요도 | 높음 - L7 로드 밸런싱 표준 |
| 학습 난이도 | 3/5 |
| 시장 가치 | 높음 |

**📚 학습 포인트**
- ALB vs NLB vs CLB
- Target Group Health Check
- Listener Rules
- Path-based Routing
- Sticky Sessions

---

### 📊 3순위: 지식 습득 (시간 남을 때)

#### 3.7 CloudFront & CDN

**🎯 중요도**: ⭐⭐⭐

| 항목 | 설명 |
|------|------|
| 현재 중요도 | 중간 - 프론트엔드 성능 |
| 미래 중요도 | 높음 - Edge Computing |
| 학습 난이도 | 3/5 |
| 시장 가치 | 중간 |

**📚 학습 포인트**
- Origin Access Control (OAC)
- Cache Behaviors
- Custom Error Pages (SPA 라우팅)
- Lambda@Edge
- CloudFront Functions

---

#### 3.8 CodePipeline & CodeBuild

**🎯 중요도**: ⭐⭐⭐

| 항목 | 설명 |
|------|------|
| 현재 중요도 | 높음 - CI/CD 자동화 |
| 미래 중요도 | 중간 - GitHub Actions/GitLab CI 경쟁 |
| 학습 난이도 | 3/5 |
| 시장 가치 | 중간 |

**📚 학습 포인트**
- Pipeline 구조 (Source → Build → Deploy)
- Path Filters (특정 디렉토리 변경 감지)
- V2 Pipeline
- IAM Role 설계
- Buildspec 작성

---

#### 3.9 RDS & ElastiCache

**🎯 중요도**: ⭐⭐⭐

| 항목 | 설명 |
|------|------|
| 현재 중요도 | 중간 - 관리형 서비스 |
| 미래 중요도 | 중간 - Serverless DB(Aurora Serverless) |
| 학습 난이도 | 3/5 |
| 시장 가치 | 중간 |

**📚 학습 포인트**
- Multi-AZ 구성
- Read Replica
- Backup & Restore
- Redis Cluster Mode
- Cache Hit Rate 최적화

---

#### 3.10 Route53 & ACM

**🎯 중요도**: ⭐⭐

| 항목 | 설명 |
|------|------|
| 현재 중요도 | 낮음 - 한 번 설정하면 변경 적음 |
| 미래 중요도 | 낮음 - 안정적인 서비스 |
| 학습 난이도 | 2/5 |
| 시장 가치 | 낮음 |

**📚 학습 포인트**
- DNS Record Types (A, CNAME, Alias)
- Hosted Zones
- Certificate Validation (DNS vs Email)
- us-east-1 리전 제약

---

## 4. 미래 중요성 예측

### 🔮 2026-2028 트렌드

#### 4.1 매우 중요해질 기술

| 기술 | 이유 | 준비 필요 시기 |
|------|------|----------------|
| Kubernetes | Fargate 제약 없는 표준 | 2026년 하반기 |
| Service Mesh (Istio/Linkerd) | 마이크로서비스 관리 복잡도 증가 | 2027년 |
| Event-driven Architecture (SQS/SNS/EventBridge) | 비동기 처리 필수 | 2026년 하반기 |
| Observability (X-Ray, OpenTelemetry) | 분산 시스템 디버깅 | 2027년 |
| GitOps (ArgoCD/Flux) | IaC 자동화 표준 | 2027년 |

#### 4.2 점진적으로 중요해질 기술

| 기술 | 이유 |
|------|------|
| Lambda (Serverless) | 특정 기능별로 적용 |
| Step Functions | 오케스트레이션 복잡도 증가 |
| App Runner | 간단한 컨테이너 배포 |
| EKS | Kubernetes 관형 서비스 |

#### 4.3 정체 또는 감소할 기술

| 기술 | 이유 |
|------|------|
| EC2 직접 운영 | Fargate/Serverless 이주 |
| CodePipeline (순수 AWS) | GitHub Actions 경쟁 |
| Classic Load Balancer | ALB/NLB로 대체 완료 |

---

## 5. 모듈화 권장 사항

### 📋 단계별 모듈화 로드맵

#### 1단계: 핵심 모듈 분리 (즉시)

```hcl
# 모듈 구조
modules/
├── vpc/
│   ├── main.tf          # VPC, Subnets, NAT, Route Tables
│   ├── variables.tf
│   └── outputs.tf
├── ecs/
│   ├── main.tf          # Cluster, Task Definitions, Services
│   ├── variables.tf
│   └── outputs.tf
└── alb/
    ├── main.tf          # ALB, Target Group, Listener
    ├── variables.tf
    └── outputs.tf
```

#### 2단계: 데이터 계층 분리 (1개월 후)

```hcl
modules/
├── rds/
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
└── redis/
    ├── main.tf
    ├── variables.tf
    └── outputs.tf
```

#### 3단계: 완전 모듈화 (3개월 후)

```hcl
modules/
├── vpc/
├── ecs/
├── alb/
├── rds/
├── redis/
├── cloudfront/
├── security/
├── cloudmap/
├── ssm/
├── ecr/
└── pipeline/
```

### 🔧 모듈화 예시

#### VPC 모듈 구조

```hcl
# modules/vpc/main.tf
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = var.name }
}

resource "aws_subnet" "public" {
  for_each = var.public_subnets
  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = true
  tags = { Name = "${var.name}-public-${each.key}" }
}

# modules/vpc/variables.tf
variable "name" { type = string }
variable "vpc_cidr" { type = string }
variable "public_subnets" {
  type = map(object({
    cidr = string
    az   = string
  }))
}

# modules/vpc/outputs.tf
output "vpc_id" { value = aws_vpc.main.id }
output "public_subnet_ids" { value = [for s in aws_subnet.public : s.id] }
```

#### 사용 예시

```hcl
# main.tf
module "vpc" {
  source = "./modules/vpc"

  name    = "pposiraegi"
  vpc_cidr = "10.0.0.0/16"

  public_subnets = {
    a = { cidr = "10.0.1.0/24", az = "ap-northeast-2a" }
    b = { cidr = "10.0.2.0/24", az = "ap-northeast-2c" }
  }
}

module "ecs" {
  source = "./modules/ecs"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids
  # ...
}
```

---

## 🎯 학습 우선순위 요약

### 1개월 내 목표

1. ✅ **ECS Fargate 마스터** - 핵심 실행 환경
2. ✅ **Terraform 모듈화** - 인프라 스케일링
3. ✅ **Service Discovery** - MSA 통신

### 3개월 내 목표

4. ⭐ **Security Groups** - 네트워크 보안
5. ⭐ **SSM Parameter Store** - 시크릿 관리
6. ⭐ **ALB 구성** - 로드 밸런싱

### 6개월 내 목표

7. 📚 **Kubernetes 기초** - 다음 단계
8. 📚 **Service Mesh** - 고급 MSA
9. 📚 **Observability** - 모니터링

---

> [!example] 실전 적용 팁
> 1. **지금 당장**: ECS Fargate와 Terraform 모듈화에 집중
> 2. **다음 주**: Service Discovery와 Security Groups 학습
> 3. **이번 달**: ALB와 Target Group 마스터
> 4. **지속적**: Cloud, DevOps 트렌드 모니터링

> [!warning] 주의사항
> - 한 번에 모든 것을 배우려 하지 마세요
> - 실무에서 필요한 것부터 학습하세요
> - Hands-on 실습이 이론보다 중요합니다