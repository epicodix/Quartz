---
title: Terraform 기초 - Infrastructure as Code 시작하기
tags:
  - terraform
  - iac
  - infrastructure
  - devops
  - 클라우드
aliases:
  - 테라폼
  - IaC기초
date: 2025-12-31
category: 1_가이드/인프라
status: 완성
priority: 높음
---

# 🎯 Terraform 기초 가이드

## 📑 목차
- [[#1. Terraform이란?|Terraform 소개]]
- [[#2. 핵심 개념|핵심 개념]]
- [[#3. HCL 문법 기초|HCL 문법]]
- [[#4. Terraform 워크플로우|워크플로우]]
- [[#5. 실전 예시|실전 예시]]

---

## 1. Terraform이란?

> [!note] 핵심 개념
> **Terraform**은 HashiCorp에서 만든 오픈소스 Infrastructure as Code (IaC) 도구입니다. 코드로 인프라를 정의하고, 버전 관리하며, 재사용 가능한 방식으로 인프라를 구축/변경/삭제할 수 있습니다.

### 💡 Infrastructure as Code (IaC)란?

**🤔 질문**: "왜 인프라를 코드로 관리해야 할까요?"

#### 📋 전통적인 방식 vs IaC

| 방식 | 전통적인 인프라 관리 | Infrastructure as Code |
|------|---------------------|------------------------|
| **생성 방법** | 콘솔 UI 클릭, 수동 설정 | 코드 작성 및 실행 |
| **재현성** | 낮음 (사람마다 다름) | 높음 (코드가 동일하면 결과 동일) |
| **버전 관리** | 어려움 | Git으로 관리 가능 |
| **협업** | 문서화 필요, 오류 발생 쉬움 | 코드 리뷰, PR 프로세스 |
| **속도** | 느림 (수동 작업) | 빠름 (자동화) |
| **확장성** | 수동 반복 작업 | 코드 재사용 |

### 🚀 Terraform의 장점

1. **멀티 클라우드 지원**
   - AWS, GCP, Azure, 오라클 클라우드 등 지원
   - 하나의 도구로 여러 클라우드 관리 가능

2. **선언적 문법**
   - "어떻게(How)" 대신 "무엇을(What)" 정의
   - 최종 상태만 선언하면 Terraform이 알아서 처리

3. **실행 계획 미리보기**
   - `terraform plan`으로 변경사항 사전 확인
   - 프로덕션 환경 보호

4. **상태 관리**
   - 현재 인프라 상태 추적
   - 변경사항만 적용 (전체 재생성 X)

---

## 2. 핵심 개념

### 📊 Terraform 아키텍처

```
┌─────────────────┐
│  Terraform CLI  │
└────────┬────────┘
         │
         ├─── Configuration Files (.tf)
         │    └── HCL (HashiCorp Configuration Language)
         │
         ├─── State File (terraform.tfstate)
         │    └── 현재 인프라 상태 저장
         │
         └─── Provider Plugins
              ├── AWS Provider
              ├── GCP Provider
              ├── Azure Provider
              └── Kubernetes Provider
```

### 🔧 주요 구성 요소

#### 1. Provider (프로바이더)

> [!info] Provider란?
> Terraform과 API를 연결해주는 플러그인입니다. 각 클라우드 서비스와 통신하는 역할을 합니다.

```hcl
# AWS Provider 설정 예시
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-northeast-2"  # 서울 리전
}
```

**주요 Provider:**
- `aws` - Amazon Web Services
- `google` - Google Cloud Platform
- `azurerm` - Microsoft Azure
- `kubernetes` - Kubernetes 클러스터
- `docker` - Docker 컨테이너

#### 2. Resource (리소스)

> [!note] Resource란?
> 실제로 생성/관리할 인프라 구성 요소입니다. VM, 네트워크, 스토리지 등 모든 것이 리소스입니다.

```hcl
# EC2 인스턴스 생성 예시
resource "aws_instance" "web_server" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"

  tags = {
    Name = "MyWebServer"
    Environment = "Development"
  }
}
```

**구조 분석:**
- `resource` - 키워드
- `"aws_instance"` - 리소스 타입 (Provider_ResourceType)
- `"web_server"` - 리소스 이름 (코드 내에서 참조할 때 사용)
- `{ ... }` - 리소스 설정

#### 3. Variable (변수)

> [!tip] Variable 사용 이유
> 코드 재사용성을 높이고, 환경별로 다른 값을 쉽게 적용할 수 있습니다.

```hcl
# 📋 변수 정의 (variables.tf)
variable "instance_type" {
  description = "EC2 인스턴스 타입"
  type        = string
  default     = "t2.micro"
}

variable "environment" {
  description = "환경 구분"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "환경은 dev, staging, prod 중 하나여야 합니다."
  }
}

# 📋 변수 사용
resource "aws_instance" "web" {
  instance_type = var.instance_type

  tags = {
    Environment = var.environment
  }
}
```

**변수 타입:**
- `string` - 문자열
- `number` - 숫자
- `bool` - 참/거짓
- `list(type)` - 리스트
- `map(type)` - 맵
- `object({...})` - 객체

#### 4. Output (출력)

> [!info] Output이란?
> Terraform 실행 후 필요한 정보를 출력합니다. 다른 모듈에서 참조하거나, 사용자에게 정보를 제공할 때 사용합니다.

```hcl
# 출력 정의
output "instance_ip" {
  description = "EC2 인스턴스의 공인 IP"
  value       = aws_instance.web_server.public_ip
}

output "instance_id" {
  description = "EC2 인스턴스 ID"
  value       = aws_instance.web_server.id
}
```

#### 5. State (상태)

> [!warning] State 파일 중요!
> `terraform.tfstate` 파일은 현재 인프라의 실제 상태를 저장합니다. 이 파일이 손상되면 인프라 관리가 어려워지므로 반드시 백업하고 보호해야 합니다.

```json
// terraform.tfstate 예시 (일부)
{
  "version": 4,
  "terraform_version": "1.6.0",
  "resources": [
    {
      "type": "aws_instance",
      "name": "web_server",
      "instances": [
        {
          "attributes": {
            "id": "i-0123456789abcdef",
            "public_ip": "52.79.123.456",
            "instance_type": "t2.micro"
          }
        }
      ]
    }
  ]
}
```

**State 관리 베스트 프랙티스:**
- ✅ 원격 백엔드 사용 (S3, GCS, Terraform Cloud)
- ✅ State 잠금 (동시 수정 방지)
- ✅ State 파일 암호화
- ❌ State 파일을 Git에 커밋하지 않기
- ❌ 직접 State 파일 수정하지 않기

---

## 3. HCL 문법 기초

### 💻 HashiCorp Configuration Language (HCL)

> [!note] HCL이란?
> Terraform의 설정 언어입니다. JSON과 유사하지만 더 읽기 쉽고, 주석과 변수를 지원합니다.

#### 📝 기본 구조

```hcl
# 1. 블록 (Block)
resource "aws_instance" "example" {
  # 2. 인자 (Arguments)
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"

  # 3. 중첩 블록 (Nested Block)
  tags {
    Name = "example-instance"
  }
}
```

#### 🔍 주석

```hcl
# 한 줄 주석

/*
여러 줄 주석
여러 줄 주석
*/

// 이것도 한 줄 주석 (비권장)
```

#### 📦 데이터 타입

```hcl
# 문자열
variable "name" {
  default = "hello"
}

# 숫자
variable "count" {
  default = 3
}

# 불리언
variable "enabled" {
  default = true
}

# 리스트
variable "availability_zones" {
  default = ["ap-northeast-2a", "ap-northeast-2c"]
}

# 맵
variable "tags" {
  default = {
    Environment = "dev"
    Project     = "terraform-study"
  }
}

# 객체
variable "instance_config" {
  type = object({
    instance_type = string
    ami           = string
    disk_size     = number
  })
}
```

#### 🔗 참조 표현식

```hcl
# 변수 참조
var.instance_type

# 리소스 속성 참조
aws_instance.web_server.public_ip

# 로컬 값 참조
local.common_tags

# 데이터 소스 참조
data.aws_ami.ubuntu.id

# 리스트 인덱싱
var.availability_zones[0]

# 맵 참조
var.tags["Environment"]
```

#### 🛠️ 함수

```hcl
# 문자열 함수
upper("hello")           # "HELLO"
lower("WORLD")           # "world"
format("Hello, %s", "Terraform")  # "Hello, Terraform"

# 숫자 함수
min(1, 2, 3)            # 1
max(1, 2, 3)            # 3

# 컬렉션 함수
length([1, 2, 3])       # 3
concat([1, 2], [3, 4])  # [1, 2, 3, 4]

# 날짜/시간
timestamp()             # 현재 시간

# 파일 함수
file("${path.module}/config.txt")  # 파일 내용 읽기
```

---

## 4. Terraform 워크플로우

### 🔄 기본 작업 흐름

```
┌─────────┐     ┌─────────┐     ┌─────────┐     ┌─────────┐
│  Write  │ ──> │  Init   │ ──> │  Plan   │ ──> │  Apply  │
└─────────┘     └─────────┘     └─────────┘     └─────────┘
   코드 작성     초기화          검토             적용
```

### 📋 상세 단계

#### 1. Write (코드 작성)

```bash
# 프로젝트 디렉토리 생성
mkdir terraform-practice
cd terraform-practice

# main.tf 파일 작성
```

```hcl
# main.tf
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
  region = "ap-northeast-2"
}

resource "aws_instance" "example" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"

  tags = {
    Name = "terraform-example"
  }
}
```

#### 2. Init (초기화)

```bash
terraform init
```

**수행 작업:**
- ✅ Provider 플러그인 다운로드
- ✅ 백엔드 초기화
- ✅ 모듈 다운로드

```
Initializing the backend...
Initializing provider plugins...
- Finding hashicorp/aws versions matching "~> 5.0"...
- Installing hashicorp/aws v5.31.0...

Terraform has been successfully initialized!
```

#### 3. Plan (실행 계획)

```bash
terraform plan
```

**수행 작업:**
- ✅ 현재 상태와 코드 비교
- ✅ 변경될 내용 미리보기
- ✅ 문법 오류 체크

```
Terraform will perform the following actions:

  # aws_instance.example will be created
  + resource "aws_instance" "example" {
      + ami                    = "ami-0c55b159cbfafe1f0"
      + instance_type          = "t2.micro"
      + id                     = (known after apply)
      + public_ip              = (known after apply)
      ...
    }

Plan: 1 to add, 0 to change, 0 to destroy.
```

**Plan 출력 기호:**
- `+` 생성될 리소스
- `-` 삭제될 리소스
- `~` 변경될 리소스
- `-/+` 재생성될 리소스

#### 4. Apply (적용)

```bash
terraform apply
```

**수행 작업:**
- ✅ Plan 실행
- ✅ 승인 요청 (`yes` 입력)
- ✅ 인프라 변경 적용
- ✅ State 파일 업데이트

```
Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value: yes

aws_instance.example: Creating...
aws_instance.example: Still creating... [10s elapsed]
aws_instance.example: Creation complete after 30s [id=i-0123456789abcdef]

Apply complete! Resources: 1 added, 0 changed, 0 destroyed.
```

**자동 승인 (주의!):**
```bash
terraform apply -auto-approve  # 승인 없이 즉시 적용
```

#### 5. 기타 중요 명령어

```bash
# 현재 상태 확인
terraform show

# 리소스 목록 확인
terraform state list

# 특정 리소스 상태 확인
terraform state show aws_instance.example

# 인프라 삭제
terraform destroy

# 코드 포맷팅
terraform fmt

# 코드 검증
terraform validate

# 출력 값 확인
terraform output
```

---

## 5. 실전 예시

### 💻 간단한 웹 서버 구축

> [!example] 실습 목표
> AWS EC2 인스턴스를 생성하고, 보안 그룹을 설정하여 웹 서버를 구축합니다.

#### 📁 프로젝트 구조

```
terraform-web-server/
├── main.tf           # 메인 설정
├── variables.tf      # 변수 정의
├── outputs.tf        # 출력 정의
└── terraform.tfvars  # 변수 값
```

#### 📄 main.tf

```hcl
# 📊 Terraform 및 Provider 설정
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

# 📊 보안 그룹 - HTTP 허용
resource "aws_security_group" "web_sg" {
  name        = "${var.project_name}-web-sg"
  description = "Security group for web server"

  # HTTP 인바운드 허용
  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH 인바운드 허용 (관리용)
  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # 모든 아웃바운드 허용
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-web-sg"
    Environment = var.environment
  }
}

# 📊 EC2 인스턴스 - 웹 서버
resource "aws_instance" "web" {
  ami           = var.ami_id
  instance_type = var.instance_type

  vpc_security_group_ids = [aws_security_group.web_sg.id]

  # 사용자 데이터 - 웹 서버 자동 설치
  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y httpd
              systemctl start httpd
              systemctl enable httpd
              echo "<h1>Hello from Terraform!</h1>" > /var/www/html/index.html
              EOF

  tags = {
    Name        = "${var.project_name}-web-server"
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}
```

#### 📄 variables.tf

```hcl
# 📋 AWS 리전
variable "aws_region" {
  description = "AWS 리전"
  type        = string
  default     = "ap-northeast-2"
}

# 📋 프로젝트 이름
variable "project_name" {
  description = "프로젝트 이름"
  type        = string
  default     = "my-web-app"
}

# 📋 환경
variable "environment" {
  description = "환경 (dev/staging/prod)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "환경은 dev, staging, prod 중 하나여야 합니다."
  }
}

# 📋 AMI ID
variable "ami_id" {
  description = "Amazon Linux 2 AMI ID"
  type        = string
  default     = "ami-0c55b159cbfafe1f0"  # Amazon Linux 2 (서울 리전)
}

# 📋 인스턴스 타입
variable "instance_type" {
  description = "EC2 인스턴스 타입"
  type        = string
  default     = "t2.micro"
}
```

#### 📄 outputs.tf

```hcl
# 📤 웹 서버 공인 IP
output "web_server_public_ip" {
  description = "웹 서버의 공인 IP 주소"
  value       = aws_instance.web.public_ip
}

# 📤 웹 서버 URL
output "web_server_url" {
  description = "웹 서버 접속 URL"
  value       = "http://${aws_instance.web.public_ip}"
}

# 📤 보안 그룹 ID
output "security_group_id" {
  description = "보안 그룹 ID"
  value       = aws_security_group.web_sg.id
}
```

#### 📄 terraform.tfvars (선택사항)

```hcl
project_name  = "my-terraform-web"
environment   = "dev"
instance_type = "t2.micro"
```

### 🚀 실행하기

```bash
# 1. 디렉토리 생성 및 이동
mkdir terraform-web-server
cd terraform-web-server

# 2. 위 파일들 생성 (main.tf, variables.tf, outputs.tf)

# 3. Terraform 초기화
terraform init

# 4. 실행 계획 확인
terraform plan

# 5. 인프라 생성
terraform apply

# 출력 예시:
# web_server_public_ip = "52.79.123.456"
# web_server_url = "http://52.79.123.456"

# 6. 웹 브라우저에서 확인
# http://52.79.123.456 접속 -> "Hello from Terraform!" 확인

# 7. 인프라 삭제 (실습 종료 시)
terraform destroy
```

---

## 🎯 다음 학습 단계

### 📚 추천 학습 경로

1. **모듈 (Modules)**
   - 코드 재사용성 향상
   - 복잡한 인프라 구조화

2. **원격 백엔드 (Remote Backend)**
   - S3 + DynamoDB로 State 관리
   - 팀 협업 설정

3. **워크스페이스 (Workspaces)**
   - 환경별 인프라 관리 (dev/staging/prod)

4. **프로비저너 (Provisioners)**
   - 리소스 생성 후 설정 자동화

5. **데이터 소스 (Data Sources)**
   - 기존 인프라 정보 참조

6. **고급 기능**
   - Dynamic Blocks
   - For Each / Count
   - 조건문 (Conditional Expressions)

### 🔗 유용한 자료

- [Terraform 공식 문서](https://www.terraform.io/docs)
- [Terraform Registry](https://registry.terraform.io/) - Provider 및 모듈 검색
- [Learn Terraform](https://learn.hashicorp.com/terraform) - HashiCorp 공식 튜토리얼
- [Terraform Best Practices](https://www.terraform-best-practices.com/)

---

## 💡 팁 및 베스트 프랙티스

> [!tip] 실전 팁
>
> **1. 항상 Plan 먼저 실행**
> - `terraform apply` 전에 반드시 `terraform plan`으로 확인
>
> **2. State 파일 보호**
> - `.gitignore`에 `*.tfstate` 추가
> - 원격 백엔드 사용 (S3, GCS, Terraform Cloud)
>
> **3. 변수 활용**
> - 하드코딩 대신 변수 사용
> - 환경별로 다른 `.tfvars` 파일 관리
>
> **4. 명명 규칙**
> - 리소스 이름: `resource_type.descriptive_name`
> - 변수 이름: `snake_case` 사용
>
> **5. 주석 작성**
> - 복잡한 로직에는 주석 추가
> - 변수에는 `description` 필수

> [!warning] 주의사항
>
> **1. 비용 관리**
> - 실습 후 반드시 `terraform destroy` 실행
> - 예상치 못한 비용 발생 방지
>
> **2. 민감한 정보**
> - API 키, 비밀번호 등은 변수로 관리
> - 환경 변수 또는 Vault 사용
>
> **3. State 파일 동시 수정 방지**
> - State Locking 활성화
> - 여러 사람이 동시에 apply 하지 않기

---

## 🏁 마치며

이 가이드로 Terraform의 기초를 배웠습니다. 다음 단계는:

1. ✅ 실제로 간단한 인프라 구축해보기
2. ✅ 모듈을 사용한 코드 재사용 학습
3. ✅ 팀 협업을 위한 원격 백엔드 설정


---

> Created: 2025-12-31
> Tags: #terraform #iac #infrastructure #devops #클라우드
> Category: 가이드
