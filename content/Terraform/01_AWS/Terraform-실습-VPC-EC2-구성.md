---
title: Terraform 실습 - VPC와 EC2로 웹 서버 구축하기
tags:
  - terraform
  - aws
  - vpc
  - ec2
  - 실습
aliases:
  - VPC실습
  - Terraform실전
date: 2025-12-31
category: 1_가이드/실습
status: 완성
priority: 높음
---

# 🚀 Terraform 실전 실습: VPC와 EC2 웹 서버 구축

## 📑 목차
- [[#1. 프로젝트 개요|프로젝트 개요]]
- [[#2. 아키텍처|아키텍처]]
- [[#3. 코드 작성|코드 작성]]
- [[#4. 실행 및 테스트|실행 및 테스트]]
- [[#5. 고급 기능|고급 기능]]

---

## 1. 프로젝트 개요

> [!note] 학습 목표
> AWS VPC를 처음부터 생성하고, 퍼블릭/프라이빗 서브넷을 구성하며, EC2 인스턴스에 웹 서버를 배포하는 완전한 인프라를 Terraform으로 구축합니다.

### 🎯 구축할 리소스

| 리소스 | 개수 | 목적 |
|--------|------|------|
| VPC | 1 | 격리된 네트워크 환경 |
| 퍼블릭 서브넷 | 2 | 웹 서버 배치 (가용영역 2개) |
| 프라이빗 서브넷 | 2 | DB 서버 배치 (향후 확장) |
| Internet Gateway | 1 | 인터넷 연결 |
| NAT Gateway | 1 | 프라이빗 서브넷 아웃바운드 |
| 보안 그룹 | 2 | 웹/DB 보안 정책 |
| EC2 인스턴스 | 2 | 웹 서버 (고가용성) |
| Application Load Balancer | 1 | 트래픽 분산 |

### 💰 예상 비용

> [!warning] 비용 주의
> - EC2 t2.micro (2대): 프리티어 가능
> - NAT Gateway: **시간당 약 $0.045 + 데이터 전송 비용**
> - ALB: **시간당 약 $0.0225**
> - **실습 후 반드시 `terraform destroy` 실행!**

---

## 2. 아키텍처

### 🏗️ 네트워크 구조도

```
┌─────────────────────────────────────────────────────────────┐
│                          AWS Region                         │
│                      ap-northeast-2 (서울)                  │
│                                                             │
│  ┌────────────────────────────────────────────────────┐    │
│  │              VPC (10.0.0.0/16)                     │    │
│  │                                                     │    │
│  │  ┌─────────────────┐      ┌─────────────────┐     │    │
│  │  │ Public Subnet 1 │      │ Public Subnet 2 │     │    │
│  │  │  10.0.1.0/24    │      │  10.0.2.0/24    │     │    │
│  │  │  (AZ-A)         │      │  (AZ-C)         │     │    │
│  │  │                 │      │                 │     │    │
│  │  │  ┌───────────┐  │      │  ┌───────────┐  │     │    │
│  │  │  │ EC2 Web 1 │  │      │  │ EC2 Web 2 │  │     │    │
│  │  │  └───────────┘  │      │  └───────────┘  │     │    │
│  │  └────────┬────────┘      └────────┬────────┘     │    │
│  │           │                        │              │    │
│  │           └────────────┬───────────┘              │    │
│  │                        │                          │    │
│  │              ┌─────────▼─────────┐                │    │
│  │              │  Load Balancer    │                │    │
│  │              └─────────┬─────────┘                │    │
│  │                        │                          │    │
│  │  ┌─────────────────────▼──────────────────┐      │    │
│  │  │      Internet Gateway (IGW)            │      │    │
│  │  └────────────────────────────────────────┘      │    │
│  │                                                   │    │
│  │  ┌─────────────────┐      ┌─────────────────┐   │    │
│  │  │Private Subnet 1 │      │Private Subnet 2 │   │    │
│  │  │  10.0.11.0/24   │      │  10.0.12.0/24   │   │    │
│  │  │  (AZ-A)         │      │  (AZ-C)         │   │    │
│  │  │                 │      │                 │   │    │
│  │  │  (향후 DB 배치) │      │  (향후 DB 배치) │   │    │
│  │  └────────┬────────┘      └────────┬────────┘   │    │
│  │           │                        │            │    │
│  │           └──────────┬─────────────┘            │    │
│  │                      │                          │    │
│  │              ┌───────▼───────┐                  │    │
│  │              │  NAT Gateway  │                  │    │
│  │              └───────────────┘                  │    │
│  └─────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────┘
```

### 📊 보안 그룹 규칙

#### 웹 서버 보안 그룹

| 방향 | 프로토콜 | 포트 | 소스 | 설명 |
|------|----------|------|------|------|
| Inbound | HTTP | 80 | 0.0.0.0/0 | 웹 트래픽 |
| Inbound | SSH | 22 | My IP | 관리 접속 |
| Outbound | ALL | ALL | 0.0.0.0/0 | 모든 아웃바운드 |

#### ALB 보안 그룹

| 방향 | 프로토콜 | 포트 | 소스 | 설명 |
|------|----------|------|------|------|
| Inbound | HTTP | 80 | 0.0.0.0/0 | 웹 트래픽 |
| Outbound | HTTP | 80 | VPC CIDR | EC2 전달 |

---

## 3. 코드 작성

### 📁 프로젝트 구조

```bash
terraform-vpc-web/
├── main.tf              # VPC 및 네트워크 리소스
├── ec2.tf               # EC2 인스턴스 및 보안 그룹
├── alb.tf               # Application Load Balancer
├── variables.tf         # 변수 정의
├── outputs.tf           # 출력 정의
└── terraform.tfvars     # 변수 값
```

### 📄 variables.tf

```hcl
# 📋 프로젝트 설정
variable "project_name" {
  description = "프로젝트 이름"
  type        = string
  default     = "terraform-vpc-web"
}

variable "environment" {
  description = "환경 (dev/staging/prod)"
  type        = string
  default     = "dev"
}

# 📋 AWS 설정
variable "aws_region" {
  description = "AWS 리전"
  type        = string
  default     = "ap-northeast-2"
}

variable "availability_zones" {
  description = "가용 영역 목록"
  type        = list(string)
  default     = ["ap-northeast-2a", "ap-northeast-2c"]
}

# 📋 네트워크 설정
variable "vpc_cidr" {
  description = "VPC CIDR 블록"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "퍼블릭 서브넷 CIDR 목록"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "프라이빗 서브넷 CIDR 목록"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

# 📋 EC2 설정
variable "instance_type" {
  description = "EC2 인스턴스 타입"
  type        = string
  default     = "t2.micro"
}

variable "ami_id" {
  description = "Amazon Linux 2023 AMI ID (서울 리전)"
  type        = string
  default     = "ami-0c9c942bd7bf113a2"  # Amazon Linux 2023
}

# 📋 보안 설정
variable "allowed_ssh_cidr" {
  description = "SSH 접속 허용 IP (보안을 위해 본인 IP로 설정)"
  type        = string
  default     = "0.0.0.0/0"  # 실습용 (실제로는 본인 IP 지정!)
}
```

### 📄 main.tf

```hcl
# 📊 Terraform 설정
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
  region = var.aws_region
}

# 📊 VPC 생성
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${var.project_name}-vpc"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# 📊 Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.project_name}-igw"
    Environment = var.environment
  }
}

# 📊 퍼블릭 서브넷
resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.project_name}-public-subnet-${count.index + 1}"
    Environment = var.environment
    Type        = "Public"
  }
}

# 📊 프라이빗 서브넷
resource "aws_subnet" "private" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name        = "${var.project_name}-private-subnet-${count.index + 1}"
    Environment = var.environment
    Type        = "Private"
  }
}

# 📊 EIP for NAT Gateway
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name        = "${var.project_name}-nat-eip"
    Environment = var.environment
  }

  depends_on = [aws_internet_gateway.main]
}

# 📊 NAT Gateway
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name        = "${var.project_name}-nat-gw"
    Environment = var.environment
  }

  depends_on = [aws_internet_gateway.main]
}

# 📊 퍼블릭 라우트 테이블
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name        = "${var.project_name}-public-rt"
    Environment = var.environment
  }
}

# 📊 프라이빗 라우트 테이블
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name        = "${var.project_name}-private-rt"
    Environment = var.environment
  }
}

# 📊 퍼블릭 서브넷 라우트 테이블 연결
resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# 📊 프라이빗 서브넷 라우트 테이블 연결
resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}
```

### 📄 ec2.tf

```hcl
# 📊 웹 서버 보안 그룹
resource "aws_security_group" "web" {
  name        = "${var.project_name}-web-sg"
  description = "Security group for web servers"
  vpc_id      = aws_vpc.main.id

  # HTTP from ALB
  ingress {
    description     = "HTTP from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # SSH from allowed CIDR
  ingress {
    description = "SSH from allowed IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
  }

  # All outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-web-sg"
    Environment = var.environment
  }
}

# 📊 EC2 인스턴스 (웹 서버)
resource "aws_instance" "web" {
  count                  = length(var.availability_zones)
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public[count.index].id
  vpc_security_group_ids = [aws_security_group.web.id]

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y httpd

              # 인스턴스 정보 표시
              INSTANCE_ID=$(ec2-metadata --instance-id | cut -d " " -f 2)
              AZ=$(ec2-metadata --availability-zone | cut -d " " -f 2)

              cat > /var/www/html/index.html <<HTML
              <!DOCTYPE html>
              <html>
              <head>
                  <title>Terraform Web Server</title>
                  <style>
                      body {
                          font-family: Arial, sans-serif;
                          max-width: 800px;
                          margin: 50px auto;
                          padding: 20px;
                          background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                          color: white;
                      }
                      .container {
                          background: rgba(255, 255, 255, 0.1);
                          padding: 40px;
                          border-radius: 10px;
                          box-shadow: 0 8px 32px 0 rgba(31, 38, 135, 0.37);
                      }
                      h1 { margin-top: 0; }
                      .info {
                          background: rgba(255, 255, 255, 0.2);
                          padding: 15px;
                          border-radius: 5px;
                          margin: 10px 0;
                      }
                  </style>
              </head>
              <body>
                  <div class="container">
                      <h1>🚀 Terraform으로 구축한 웹 서버</h1>
                      <div class="info">
                          <p><strong>인스턴스 ID:</strong> $INSTANCE_ID</p>
                          <p><strong>가용 영역:</strong> $AZ</p>
                          <p><strong>서버:</strong> Web Server ${count.index + 1}</p>
                      </div>
                      <p>이 페이지는 Terraform으로 자동 배포되었습니다!</p>
                  </div>
              </body>
              </html>
HTML

              systemctl start httpd
              systemctl enable httpd
              EOF

  tags = {
    Name        = "${var.project_name}-web-${count.index + 1}"
    Environment = var.environment
    Server      = "Web-${count.index + 1}"
  }
}
```

### 📄 alb.tf

```hcl
# 📊 ALB 보안 그룹
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "Security group for Application Load Balancer"
  vpc_id      = aws_vpc.main.id

  # HTTP from anywhere
  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # All outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-alb-sg"
    Environment = var.environment
  }
}

# 📊 Application Load Balancer
resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  enable_deletion_protection = false

  tags = {
    Name        = "${var.project_name}-alb"
    Environment = var.environment
  }
}

# 📊 타겟 그룹
resource "aws_lb_target_group" "web" {
  name     = "${var.project_name}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = {
    Name        = "${var.project_name}-tg"
    Environment = var.environment
  }
}

# 📊 타겟 그룹에 EC2 인스턴스 등록
resource "aws_lb_target_group_attachment" "web" {
  count            = length(aws_instance.web)
  target_group_arn = aws_lb_target_group.web.arn
  target_id        = aws_instance.web[count.index].id
  port             = 80
}

# 📊 리스너
resource "aws_lb_listener" "web" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}
```

### 📄 outputs.tf

```hcl
# 📤 VPC 정보
output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "VPC CIDR 블록"
  value       = aws_vpc.main.cidr_block
}

# 📤 서브넷 정보
output "public_subnet_ids" {
  description = "퍼블릭 서브넷 ID 목록"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "프라이빗 서브넷 ID 목록"
  value       = aws_subnet.private[*].id
}

# 📤 EC2 정보
output "web_server_ids" {
  description = "웹 서버 인스턴스 ID 목록"
  value       = aws_instance.web[*].id
}

output "web_server_public_ips" {
  description = "웹 서버 공인 IP 목록"
  value       = aws_instance.web[*].public_ip
}

# 📤 ALB 정보
output "alb_dns_name" {
  description = "Application Load Balancer DNS 이름"
  value       = aws_lb.main.dns_name
}

output "website_url" {
  description = "웹사이트 접속 URL"
  value       = "http://${aws_lb.main.dns_name}"
}

# 📤 보안 그룹 정보
output "web_security_group_id" {
  description = "웹 서버 보안 그룹 ID"
  value       = aws_security_group.web.id
}

output "alb_security_group_id" {
  description = "ALB 보안 그룹 ID"
  value       = aws_security_group.alb.id
}
```

---

## 4. 실행 및 테스트

### 🚀 배포하기

```bash
# 1. 프로젝트 디렉토리 생성
mkdir ~/terraform-vpc-web
cd ~/terraform-vpc-web

# 2. 위 파일들 생성 (main.tf, ec2.tf, alb.tf, variables.tf, outputs.tf)

# 3. 초기화
terraform init
```

**예상 출력:**
```
Initializing the backend...
Initializing provider plugins...
- Finding hashicorp/aws versions matching "~> 5.0"...
- Installing hashicorp/aws v5.31.0...

Terraform has been successfully initialized!
```

```bash
# 4. 코드 검증
terraform validate
```

```bash
# 5. 포맷팅
terraform fmt
```

```bash
# 6. 실행 계획
terraform plan
```

**예상 출력:**
```
Plan: 24 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + alb_dns_name           = (known after apply)
  + public_subnet_ids      = [
      + (known after apply),
      + (known after apply),
    ]
  + vpc_id                 = (known after apply)
  + web_server_public_ips  = [
      + (known after apply),
      + (known after apply),
    ]
  + website_url            = (known after apply)
```

```bash
# 7. 배포 (약 5-7분 소요)
terraform apply
```

**입력:**
```
Do you want to perform these actions?
  Enter a value: yes
```

**배포 완료 출력:**
```
Apply complete! Resources: 24 added, 0 changed, 0 destroyed.

Outputs:

alb_dns_name = "terraform-vpc-web-alb-1234567890.ap-northeast-2.elb.amazonaws.com"
public_subnet_ids = [
  "subnet-0abcd1234efgh5678",
  "subnet-0ijkl9012mnop3456",
]
vpc_id = "vpc-0qrst5678uvwx9012"
web_server_public_ips = [
  "52.79.123.45",
  "52.79.234.56",
]
website_url = "http://terraform-vpc-web-alb-1234567890.ap-northeast-2.elb.amazonaws.com"
```

### 🧪 테스트하기

```bash
# 1. 웹사이트 접속 URL 확인
terraform output website_url
```

**브라우저에서 접속:**
- URL 복사하여 브라우저에서 열기
- "Terraform으로 구축한 웹 서버" 페이지 확인
- 새로고침할 때마다 다른 서버(Web Server 1 또는 2) 표시 확인

```bash
# 2. curl로 테스트
curl $(terraform output -raw website_url)

# 3. 여러 번 요청하여 로드 밸런싱 확인
for i in {1..10}; do
  curl -s $(terraform output -raw website_url) | grep "서버:"
  sleep 1
done
```

```bash
# 4. AWS CLI로 리소스 확인
# VPC 확인
aws ec2 describe-vpcs --vpc-ids $(terraform output -raw vpc_id)

# EC2 인스턴스 확인
aws ec2 describe-instances --filters "Name=tag:Name,Values=terraform-vpc-web-web-*"

# ALB 확인
aws elbv2 describe-load-balancers --names terraform-vpc-web-alb

# 타겟 그룹 헬스 체크
aws elbv2 describe-target-health --target-group-arn $(aws elbv2 describe-target-groups --names terraform-vpc-web-tg --query 'TargetGroups[0].TargetGroupArn' --output text)
```

### 🗑️ 정리하기

> [!danger] 비용 발생 방지
> 실습이 끝나면 반드시 리소스를 삭제하세요!

```bash
# 모든 리소스 삭제
terraform destroy
```

**입력:**
```
Do you really want to destroy all resources?
  Enter a value: yes
```

**예상 소요 시간:** 약 3-5분

---

## 5. 고급 기능

### 🔧 변수 파일 활용

#### terraform.tfvars

```hcl
# 프로젝트 설정
project_name = "my-web-app"
environment  = "production"

# 네트워크 설정
vpc_cidr             = "10.1.0.0/16"
public_subnet_cidrs  = ["10.1.1.0/24", "10.1.2.0/24"]
private_subnet_cidrs = ["10.1.11.0/24", "10.1.12.0/24"]

# 보안 설정 (본인 IP로 변경!)
allowed_ssh_cidr = "123.456.789.0/32"

# EC2 설정
instance_type = "t3.micro"
```

#### 환경별 변수 파일

```bash
# 개발 환경
terraform apply -var-file="dev.tfvars"

# 스테이징 환경
terraform apply -var-file="staging.tfvars"

# 프로덕션 환경
terraform apply -var-file="prod.tfvars"
```

### 📦 모듈화하기

#### 디렉토리 구조

```
terraform-vpc-web/
├── modules/
│   ├── vpc/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── ec2/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── alb/
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
├── main.tf           # 모듈 호출
├── variables.tf
└── outputs.tf
```

#### 모듈 사용 예시

```hcl
# main.tf
module "vpc" {
  source = "./modules/vpc"

  project_name = var.project_name
  environment  = var.environment
  vpc_cidr     = var.vpc_cidr
}

module "ec2" {
  source = "./modules/ec2"

  vpc_id               = module.vpc.vpc_id
  public_subnet_ids    = module.vpc.public_subnet_ids
  project_name         = var.project_name
  environment          = var.environment
}

module "alb" {
  source = "./modules/alb"

  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  target_ids        = module.ec2.instance_ids
  project_name      = var.project_name
  environment       = var.environment
}
```

### 🔄 원격 백엔드 (S3)

```hcl
# backend.tf
terraform {
  backend "s3" {
    bucket         = "my-terraform-state-bucket"
    key            = "vpc-web/terraform.tfstate"
    region         = "ap-northeast-2"
    encrypt        = true
    dynamodb_table = "terraform-lock"
  }
}
```

**백엔드 초기화:**
```bash
# S3 버킷 및 DynamoDB 테이블 생성 (사전 작업)
aws s3 mb s3://my-terraform-state-bucket
aws dynamodb create-table \
  --table-name terraform-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST

# Terraform 초기화 (백엔드 마이그레이션)
terraform init -migrate-state
```

### 🌍 워크스페이스

```bash
# 워크스페이스 생성
terraform workspace new dev
terraform workspace new staging
terraform workspace new prod

# 워크스페이스 목록 확인
terraform workspace list

# 워크스페이스 전환
terraform workspace select dev

# 현재 워크스페이스 확인
terraform workspace show
```

**워크스페이스 활용:**
```hcl
# variables.tf
locals {
  environment = terraform.workspace

  instance_counts = {
    dev     = 1
    staging = 2
    prod    = 3
  }

  instance_count = local.instance_counts[local.environment]
}

# ec2.tf
resource "aws_instance" "web" {
  count = local.instance_count
  # ...
}
```

---

## 🎯 실습 체크리스트

### ✅ 완료 확인

- [ ] Terraform 설치 완료
- [ ] AWS 자격증명 설정 완료
- [ ] VPC 생성 성공
- [ ] 퍼블릭/프라이빗 서브넷 생성 성공
- [ ] Internet Gateway 및 NAT Gateway 생성 성공
- [ ] EC2 인스턴스 2대 생성 성공
- [ ] ALB 생성 및 타겟 그룹 등록 성공
- [ ] 웹 브라우저로 ALB DNS 접속 성공
- [ ] 로드 밸런싱 동작 확인 (새로고침 시 서버 번갈아 표시)
- [ ] `terraform destroy`로 리소스 정리 완료

### 🚀 다음 학습 과제

1. **Auto Scaling Group 추가**
   - EC2 인스턴스 자동 확장/축소
   - Launch Template 활용

2. **RDS 데이터베이스 추가**
   - 프라이빗 서브넷에 RDS 배치
   - 웹 서버와 연동

3. **CloudFront 배포**
   - CDN 설정
   - HTTPS 인증서 추가

4. **모니터링 및 알람**
   - CloudWatch 메트릭
   - SNS 알림 설정

---

## 💡 트러블슈팅

### 🚨 자주 발생하는 문제

#### 1. NAT Gateway 비용 우려

**해결책:**
```hcl
# NAT Gateway 대신 NAT Instance 사용 (비용 절감)
# 또는 프라이빗 서브넷 리소스가 없다면 NAT Gateway 제거
```

#### 2. ALB 헬스 체크 실패

**확인 사항:**
- 보안 그룹 규칙 확인
- EC2 인스턴스에서 웹 서버 실행 확인
- 타겟 그룹 헬스 체크 경로 확인

```bash
# EC2 SSH 접속 후 확인
systemctl status httpd
curl localhost
```

#### 3. 서브넷 CIDR 중복

**오류:**
```
Error: error creating subnet: InvalidSubnet.Conflict
```

**해결:**
- CIDR 블록 중복 확인
- VPC CIDR 범위 내에서 서브넷 CIDR 설정

---

## 📚 참고 자료

- [AWS VPC 사용자 가이드](https://docs.aws.amazon.com/vpc/)
- [Terraform AWS Provider 문서](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)

---

> Created: 2025-12-31
> Tags: #terraform #aws #vpc #ec2 #실습
> Category: 가이드/실습
