---
title: Terraform AWS VPC 구축 가이드 - 처음부터 끝까지
tags:
  - terraform
  - aws
  - vpc
  - networking
  - devops
  - infrastructure
aliases:
  - terraform-vpc-가이드
  - aws-vpc-terraform
date: 2026-01-25
category: 1_가이드/Terraform
status: 진행중
priority: 높음
---

# 🎯 Terraform AWS VPC 구축 가이드

## 📑 목차
- [[#1. 프로젝트 개요|프로젝트 개요]]
- [[#2. AWS 계정 준비|AWS 계정 준비]]
- [[#3. 로컬 환경 설정|로컬 환경 설정]]
- [[#4. Terraform 프로젝트 구조|프로젝트 구조]]
- [[#5. VPC 아키텍처 설계|VPC 아키텍처 설계]]
- [[#6. Terraform 코드 작성|코드 작성]]
- [[#7. 배포 (Plan & Apply)|배포]]
- [[#8. 비용 관리|비용 관리]]
- [[#🎯 다음 단계|다음 단계]]

---

## 1. 프로젝트 개요

> [!note] 핵심 목표
> Terraform으로 AWS VPC를 Multi-AZ 구성으로 설계하고 프로비저닝한다.
> 네트워킹 + IaC 실력을 동시에 갈고닦는 것이 목적.

### 💡 왜 VPC부터 시작하는가?

**🤔 질문**: "클라우드 엔지니어에게 가장 범용적인 스킬은?"

- 서버리스든 K8s든 결국 **네트워크 위에서 동작**
- 장애의 80%가 네트워크 문제
- AWS/GCP/Azure 모두 동일한 네트워크 개념 사용
- 면접 단골 질문: "Private Subnet의 Pod가 외부 API 호출 안 될 때 어떻게 디버깅?"

### 📋 예산 및 환경

| 항목 | 값 |
|------|-----|
| AWS 크레딧 | $200 (신규 가입) |
| 추가 지원금 | 10만원 (~$75) |
| 총 예산 | ~$275 |
| 사용 기간 | 6개월 |
| 로컬 환경 | macOS (Apple Silicon) |
| Terraform | v1.14.3 |
| AWS CLI | v2.33.6 |
| 리전 | ap-northeast-2 (서울) |

---

## 2. AWS 계정 준비

### 💡 2025년 7월 이후 신규 프리 티어

> [!info] AWS 프리 티어 변경사항 (2025.07.15~)
> 신규 가입 시 **최대 $200 크레딧** 제공 (기존 12개월 Free Tier와 다름)
> - 가입 즉시 $100 크레딧
> - 서비스 탐색 미션 완료 시 추가 $100 적립
> - 6개월간 유효, 유료 플랜 전환 전까지 과금 없음

#### 📋 계정 생성 단계

1. AWS 공식 사이트 접속
2. 이메일 + 비밀번호로 계정 생성
3. **플랜 선택: "무료(6개월)"** 선택
   - 크레딧 소진 또는 6개월 후 자동 해지 (과금 없음)
   - 유료 플랜은 크레딧 초과분이 카드로 빠지므로 학습용은 무료 선택
4. 결제 카드 등록 (체크카드 가능, 과금되지 않음)
5. 본인 인증 완료

#### 📋 IAM Access Key 생성

1. AWS 콘솔 로그인
2. **IAM → Users → 본인 계정 → Security credentials**
3. **Create access key** 클릭
4. 사용 사례: **"Command Line Interface(CLI)"** 선택
5. 경고 확인란 체크 후 생성
6. **Access Key ID**와 **Secret Access Key** 저장 (이후 다시 볼 수 없음)

> [!warning] 주의사항
> - Secret Access Key는 생성 시 한 번만 표시됨
> - 분실 시 키를 삭제하고 새로 생성해야 함
> - 절대 Git에 커밋하거나 공개 저장소에 노출하지 말 것

---

## 3. 로컬 환경 설정

### 💻 AWS CLI 설치

```bash
# macOS (Homebrew)
brew install awscli

# 설치 확인
aws --version
# aws-cli/2.33.6 Python/3.13.11 Darwin/24.6.0 source/arm64
```

### 💻 AWS 자격 증명 설정

```bash
aws configure
```

입력 항목:
```
AWS Access Key ID [None]: AKIA............
AWS Secret Access Key [None]: xxxxxxxxxxxxxxxxxxxxxxxx
Default region name [None]: ap-northeast-2
Default output format [None]: json
```

### 💻 연결 확인

```bash
aws sts get-caller-identity
```

정상 출력 예시:
```json
{
    "UserId": "AIDAXXXXXXXXXXXX",
    "Account": "317250221510",
    "Arn": "arn:aws:iam::317250221510:user/aws1"
}
```

> [!tip] 팁
> 이 명령어가 성공하면 Terraform도 동일한 자격 증명을 사용하므로 별도 설정 불필요

### 💻 Terraform 확인

```bash
terraform version
# Terraform v1.14.3 on darwin_arm64
```

> [!info] Terraform 미설치 시
> ```bash
> brew tap hashicorp/tap
> brew install hashicorp/tap/terraform
> ```

---

## 4. Terraform 프로젝트 구조

### 📋 디렉토리 구조

```
~/terraform-aws-infra/
├── providers.tf          # Provider 및 Terraform 설정
├── variables.tf          # 변수 정의
├── terraform.tfvars      # 변수 값 (실제 값 할당)
├── vpc.tf                # VPC, Subnet, IGW, NAT, Route Table
├── security_groups.tf    # Security Groups (bastion, web, app, db)
├── outputs.tf            # 출력값 정의
├── .terraform/           # (자동생성) Provider 플러그인
├── .terraform.lock.hcl   # (자동생성) Provider 버전 잠금
└── terraform.tfstate     # (자동생성) 인프라 상태 파일
```

### 💡 파일 분리 원칙

| 파일 | 역할 | 비유 |
|------|------|------|
| `providers.tf` | "어떤 클라우드를 쓸 건지" | 도구 선택 |
| `variables.tf` | "어떤 값을 바꿀 수 있게 할 건지" | 설계 도면의 치수 표기 |
| `terraform.tfvars` | "실제로 어떤 값을 쓸 건지" | 실제 치수 값 |
| `vpc.tf` | "네트워크를 어떻게 구성할 건지" | 건물 설계도 |
| `security_groups.tf` | "누가 어디에 접근 가능한지" | 출입 권한표 |
| `outputs.tf` | "만들고 나서 뭘 확인할 건지" | 완공 검수 체크리스트 |

---

## 5. VPC 아키텍처 설계

### 📊 네트워크 다이어그램

```
┌─────────────────────────────────────────────────────────────┐
│  VPC: 10.0.0.0/16 (65,536 IPs)                             │
│                                                             │
│  ┌─────────────────────┐  ┌─────────────────────┐          │
│  │  Public Subnet       │  │  Public Subnet       │          │
│  │  10.0.1.0/24         │  │  10.0.2.0/24         │          │
│  │  AZ: ap-northeast-2a │  │  AZ: ap-northeast-2c │          │
│  │  (Bastion, ALB)      │  │  (ALB)               │          │
│  └────────┬─────────────┘  └────────┬─────────────┘          │
│           │                          │                       │
│           │    Internet Gateway      │                       │
│           └──────────┬───────────────┘                       │
│                      │                                       │
│  ┌─────────────────────┐  ┌─────────────────────┐          │
│  │  Private Subnet      │  │  Private Subnet      │          │
│  │  10.0.10.0/24        │  │  10.0.20.0/24        │          │
│  │  AZ: ap-northeast-2a │  │  AZ: ap-northeast-2c │          │
│  │  (App, DB)           │  │  (App, DB)           │          │
│  └──────────────────────┘  └──────────────────────┘          │
└─────────────────────────────────────────────────────────────┘
```

### 📊 CIDR 설계

| 구분 | CIDR | IP 범위 | 용도 |
|------|------|---------|------|
| VPC | 10.0.0.0/16 | 10.0.0.0 ~ 10.0.255.255 | 전체 네트워크 |
| Public-2a | 10.0.1.0/24 | 10.0.1.0 ~ 10.0.1.255 | Bastion, ALB |
| Public-2c | 10.0.2.0/24 | 10.0.2.0 ~ 10.0.2.255 | ALB (Multi-AZ) |
| Private-2a | 10.0.10.0/24 | 10.0.10.0 ~ 10.0.10.255 | App, DB |
| Private-2c | 10.0.20.0/24 | 10.0.20.0 ~ 10.0.20.255 | App, DB (Multi-AZ) |

> [!tip] CIDR 설계 팁
> - `/16` = 65,536개 IP → VPC 전체 범위로 충분
> - `/24` = 256개 IP → 서브넷당 약 251개 사용 가능 (AWS가 5개 예약)
> - Public과 Private 서브넷의 CIDR을 다른 대역으로 분리하면 라우팅 규칙이 직관적

### 📊 라우팅 설계

| Route Table | 목적지 | 타겟 | 설명 |
|-------------|--------|------|------|
| Public RT | 0.0.0.0/0 | Internet Gateway | 인터넷 직접 통신 |
| Private RT | 0.0.0.0/0 | NAT Gateway (옵션) | NAT 통해 외부 통신 |
| (공통) | 10.0.0.0/16 | local | VPC 내부 통신 (자동) |

### 📊 Security Group 체인

```
인터넷 → [web-sg: 80,443] → ALB
                              ↓
         [app-sg: 3000] ← ALB에서만 접근 가능
                              ↓
         [db-sg: 5432] ← App에서만 접근 가능

별도: [bastion-sg: 22] → Bastion Host → [app-sg: 22] → App 서버
```

| Security Group | Inbound | Source | 용도 |
|---------------|---------|--------|------|
| bastion-sg | 22 (SSH) | 0.0.0.0/0 | SSH 접속 (실무: 본인 IP만) |
| web-sg | 80, 443 | 0.0.0.0/0 | HTTP/HTTPS 트래픽 |
| app-sg | 3000 | web-sg | ALB에서만 앱 접근 |
| app-sg | 22 | bastion-sg | Bastion에서만 SSH |
| db-sg | 5432 | app-sg | App에서만 DB 접근 |

---

## 6. Terraform 코드 작성

### 💻 providers.tf

```hcl
terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}
```

> [!info] 코드 설명
> - `required_version`: Terraform CLI 최소 버전
> - `source`: Provider 출처 (HashiCorp 공식 AWS Provider)
> - `version = "~> 5.0"`: 5.x 대 최신 버전 사용 (6.0 미만)
> - `region = var.region`: 변수로 리전 관리 → 환경별 유연 대응

### 💻 variables.tf

```hcl
variable "region" {
  description = "AWS Region"
  type        = string
  default     = "ap-northeast-2"
}

variable "project_name" {
  description = "프로젝트 이름 (리소스 태깅용)"
  type        = string
  default     = "my-infra"
}

variable "vpc_cidr" {
  description = "VPC CIDR 블록"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnets" {
  description = "Public Subnet CIDR 목록"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnets" {
  description = "Private Subnet CIDR 목록"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.20.0/24"]
}

variable "availability_zones" {
  description = "사용할 가용영역"
  type        = list(string)
  default     = ["ap-northeast-2a", "ap-northeast-2c"]
}

variable "enable_nat_gateway" {
  description = "NAT Gateway 생성 여부 (비용 발생)"
  type        = bool
  default     = false
}
```

> [!info] 변수 설계 포인트
> - `list(string)`: 서브넷을 리스트로 관리 → `count`로 반복 생성
> - `enable_nat_gateway`: bool 변수로 비용 제어 → 필요할 때만 true로 변경
> - `default`: 기본값 지정 → `tfvars` 없어도 동작

### 💻 terraform.tfvars

```hcl
region       = "ap-northeast-2"
project_name = "my-infra"
vpc_cidr     = "10.0.0.0/16"

public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnets = ["10.0.10.0/24", "10.0.20.0/24"]

availability_zones = ["ap-northeast-2a", "ap-northeast-2c"]

# NAT Gateway: 시간당 $0.045 과금
# 필요할 때만 true로 변경 후 apply
enable_nat_gateway = false
```

### 💻 vpc.tf

```hcl
# ============================================================
# VPC
# ============================================================
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name    = "${var.project_name}-vpc"
    Project = var.project_name
  }
}

# ============================================================
# Internet Gateway
# ============================================================
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name    = "${var.project_name}-igw"
    Project = var.project_name
  }
}

# ============================================================
# Public Subnets (count로 반복 생성)
# ============================================================
resource "aws_subnet" "public" {
  count = length(var.public_subnets)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnets[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name    = "${var.project_name}-public-${var.availability_zones[count.index]}"
    Project = var.project_name
    Tier    = "public"
  }
}

# ============================================================
# Private Subnets
# ============================================================
resource "aws_subnet" "private" {
  count = length(var.private_subnets)

  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnets[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name    = "${var.project_name}-private-${var.availability_zones[count.index]}"
    Project = var.project_name
    Tier    = "private"
  }
}

# ============================================================
# NAT Gateway (비용 절약: 변수로 on/off 제어)
# ============================================================
resource "aws_eip" "nat" {
  count  = var.enable_nat_gateway ? 1 : 0
  domain = "vpc"

  tags = {
    Name    = "${var.project_name}-nat-eip"
    Project = var.project_name
  }
}

resource "aws_nat_gateway" "main" {
  count = var.enable_nat_gateway ? 1 : 0

  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name    = "${var.project_name}-nat"
    Project = var.project_name
  }

  depends_on = [aws_internet_gateway.main]
}

# ============================================================
# Route Tables
# ============================================================

# Public Route Table: 0.0.0.0/0 → Internet Gateway
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name    = "${var.project_name}-public-rt"
    Project = var.project_name
  }
}

resource "aws_route_table_association" "public" {
  count = length(var.public_subnets)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Private Route Table
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name    = "${var.project_name}-private-rt"
    Project = var.project_name
  }
}

# NAT Gateway 있을 때만 Private → NAT 라우트 추가
resource "aws_route" "private_nat" {
  count = var.enable_nat_gateway ? 1 : 0

  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main[0].id
}

resource "aws_route_table_association" "private" {
  count = length(var.private_subnets)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}
```

> [!info] 핵심 Terraform 패턴
> - `count = length(var.xxx)`: 리스트 길이만큼 반복 생성
> - `count.index`: 현재 반복 인덱스 (0, 1, 2...)
> - `조건 ? true값 : false값`: 삼항 연산자로 리소스 on/off
> - `depends_on`: 명시적 의존성 (IGW 먼저 생성 후 NAT 생성)

### 💻 security_groups.tf

```hcl
# ============================================================
# Bastion (SSH 접속용) Security Group
# ============================================================
resource "aws_security_group" "bastion" {
  name        = "${var.project_name}-bastion-sg"
  description = "Bastion host SSH access"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # 실무에서는 본인 IP로 제한
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-bastion-sg"
    Project = var.project_name
  }
}

# ============================================================
# Web (HTTP/HTTPS) Security Group
# ============================================================
resource "aws_security_group" "web" {
  name        = "${var.project_name}-web-sg"
  description = "Web traffic (HTTP/HTTPS)"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-web-sg"
    Project = var.project_name
  }
}

# ============================================================
# App (Private 영역 앱 서버) Security Group
# ============================================================
resource "aws_security_group" "app" {
  name        = "${var.project_name}-app-sg"
  description = "App server - only from web SG"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "From Web SG"
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]
  }

  ingress {
    description     = "SSH from Bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-app-sg"
    Project = var.project_name
  }
}

# ============================================================
# DB Security Group
# ============================================================
resource "aws_security_group" "db" {
  name        = "${var.project_name}-db-sg"
  description = "Database - only from app SG"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "PostgreSQL from App"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-db-sg"
    Project = var.project_name
  }
}
```

> [!info] Security Group 체인 핵심
> - `security_groups = [aws_security_group.web.id]`: CIDR 대신 **SG 참조**
> - 이렇게 하면 web-sg에 속한 리소스만 app에 접근 가능
> - 실무에서 가장 중요한 보안 패턴: **계층별 접근 제어**

### 💻 outputs.tf

```hcl
output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "VPC CIDR Block"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "Public Subnet IDs"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Private Subnet IDs"
  value       = aws_subnet.private[*].id
}

output "internet_gateway_id" {
  description = "Internet Gateway ID"
  value       = aws_internet_gateway.main.id
}

output "nat_gateway_id" {
  description = "NAT Gateway ID (if enabled)"
  value       = var.enable_nat_gateway ? aws_nat_gateway.main[0].id : null
}

output "security_group_ids" {
  description = "Security Group IDs"
  value = {
    bastion = aws_security_group.bastion.id
    web     = aws_security_group.web.id
    app     = aws_security_group.app.id
    db      = aws_security_group.db.id
  }
}
```

> [!info] Output 활용
> - `[*].id`: Splat 표현식 → 리스트의 모든 요소에서 id 추출
> - Output 값은 다른 Terraform 모듈에서 `data` 소스로 참조 가능
> - `terraform output vpc_id` 명령으로 개별 값 조회 가능

---

## 7. 배포 (Plan & Apply)

### 💻 Step 1: 초기화

```bash
cd ~/terraform-aws-infra
terraform init
```

출력 확인 포인트:
```
Initializing provider plugins...
- Installing hashicorp/aws v5.100.0...
Terraform has been successfully initialized!
```

> [!info] `terraform init`이 하는 일
> - `.terraform/` 디렉토리 생성
> - Provider 플러그인 다운로드 (hashicorp/aws)
> - `.terraform.lock.hcl` 생성 (버전 잠금)
> - Backend 초기화 (현재는 로컬)

### 💻 Step 2: Plan (변경사항 미리보기)

```bash
terraform plan
```

출력 확인 포인트:
```
Plan: 16 to add, 0 to change, 0 to destroy.
```

생성될 16개 리소스:

| 번호 | 리소스 | 설명 |
|------|--------|------|
| 1 | aws_vpc.main | VPC |
| 2 | aws_internet_gateway.main | IGW |
| 3-4 | aws_subnet.public[0,1] | Public Subnet x2 |
| 5-6 | aws_subnet.private[0,1] | Private Subnet x2 |
| 7-8 | aws_route_table.public/private | Route Table x2 |
| 9-12 | aws_route_table_association x4 | RT 연결 |
| 13-16 | aws_security_group x4 | SG (bastion, web, app, db) |

> [!tip] Plan 읽는 법
> - `+` create: 새로 생성
> - `~` update: 변경 (in-place)
> - `-` destroy: 삭제
> - `-/+` replace: 삭제 후 재생성 (주의!)

### 💻 Step 3: Apply (실제 배포)

```bash
terraform apply
```

- `yes` 입력하면 실제 AWS에 리소스 생성
- 완료 후 `terraform.tfstate` 파일에 상태 저장

### 💻 Step 4: 확인

```bash
# Output 값 확인
terraform output

# 특정 값만 확인
terraform output vpc_id

# AWS CLI로 실제 리소스 확인
aws ec2 describe-vpcs --filters "Name=tag:Project,Values=my-infra"
```

### 💻 정리 (리소스 삭제)

```bash
terraform destroy
```

> [!warning] 주의
> - `destroy`는 모든 리소스를 삭제함
> - 실습 끝나면 반드시 실행하여 불필요한 과금 방지
> - NAT Gateway가 켜져 있으면 시간당 $0.045 과금됨

---

## 8. 비용 관리

### 📊 이 VPC 구성의 비용

| 리소스 | 비용 |
|--------|------|
| VPC | 무료 |
| Subnet | 무료 |
| Internet Gateway | 무료 |
| Route Table | 무료 |
| Security Group | 무료 |
| **NAT Gateway** | **$0.045/h + 데이터 처리 $0.045/GB** |
| Elastic IP (미연결) | $0.005/h |

> [!danger] NAT Gateway 비용 주의
> - 24시간 켜두면: $0.045 x 24 = **$1.08/일**
> - 한 달 켜두면: **~$32.4/월**
> - 반드시 `enable_nat_gateway = false`로 기본 설정
> - 필요할 때만 true로 변경 → apply → 실습 → false로 변경 → apply

### 📋 Budget Alert 설정 (필수)

```
AWS 콘솔 → Billing → Budgets → Create Budget
→ Monthly cost budget
→ 임계값: $50, $100, $150 단계별 알람
→ 이메일 알림 설정
```

---

## 🎯 다음 단계

> [!example] 이후 학습 로드맵
> 1. **EC2 Bastion Host**: Public Subnet에 t2.micro 배포
> 2. **ALB + Target Group**: 로드밸런싱 구성
> 3. **RDS PostgreSQL**: Private Subnet에 DB 배포
> 4. **NAT Gateway 실습**: Private Subnet → 외부 통신 테스트
> 5. **Terraform 모듈화**: VPC를 재사용 가능한 모듈로 분리
> 6. **Remote Backend**: S3 + DynamoDB로 State 관리

---

## 🔧 자주 쓰는 Terraform 명령어

```bash
terraform init          # 초기화 (Provider 다운로드)
terraform plan          # 변경사항 미리보기
terraform apply         # 실제 배포
terraform destroy       # 전체 삭제
terraform output        # 출력값 확인
terraform state list    # 관리 중인 리소스 목록
terraform state show aws_vpc.main   # 특정 리소스 상세 정보
terraform fmt           # 코드 포맷팅
terraform validate      # 문법 검증
```

---

## 📋 트러블슈팅

### 🔍 "Error: No valid credential sources found"

```bash
# AWS 자격 증명 재확인
aws sts get-caller-identity

# 안 되면 재설정
aws configure
```

### 🔍 "Error: creating VPC: UnauthorizedOperation"

- IAM 유저에 EC2/VPC 권한이 없는 경우
- `AdministratorAccess` 정책 연결 필요 (학습용)

### 🔍 NAT Gateway 삭제 안 됨

- EIP 연결 해제가 먼저 필요
- `terraform destroy`가 자동으로 순서 처리하므로 보통 문제 없음
- 수동 삭제 시: NAT Gateway 삭제 → EIP Release 순서

---

> [!note] 문서 정보
> - 작성일: 2026-01-25
> - 환경: macOS (Apple Silicon), Terraform v1.14.3, AWS CLI v2.33.6
> - 프로젝트 경로: `~/terraform-aws-infra/`
