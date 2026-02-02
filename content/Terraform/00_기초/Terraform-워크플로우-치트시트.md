---
title: Terraform 워크플로우 치트시트 - 언제 뭘 해야 하는지
tags:
  - terraform
  - workflow
  - cheatsheet
  - devops
aliases:
  - tf-워크플로우
  - tf-치트시트
date: 2026-01-25
category: Terraform/00_기초
status: 완성
priority: 높음
---

# 🎯 Terraform 워크플로우 치트시트

## 📑 목차
- [[#1. 핵심 명령어 4개|핵심 명령어]]
- [[#2. init은 언제 해야 하나|init 타이밍]]
- [[#3. 매번 해야 하는 루틴|작업 루틴]]
- [[#4. plan 읽는 법|plan 읽기]]
- [[#5. 안전한 apply 습관|안전한 apply]]
- [[#6. 리전과 존|리전/존 정리]]
- [[#7. 리소스 확인 방법|리소스 확인]]
- [[#8. 상황별 빠른 참조|빠른 참조]]
- [[#9. lifecycle로 사고 방지|사고 방지]]
- [[#10. 자주 하는 실수 모음|자주 하는 실수]]

---

## 1. 핵심 명령어 4개

```bash
terraform init      # 도구 세팅 (Provider 다운로드)
terraform plan      # 미리보기 (뭐가 바뀌는지)
terraform apply     # 실행 (실제 반영)
terraform destroy   # 전부 삭제
```

### 📊 보조 명령어

```bash
terraform fmt           # 코드 포맷 정리
terraform validate      # 문법 검증
terraform output        # 출력값 확인
terraform state list    # 관리 중인 리소스 목록
terraform state show    # 리소스 상세 정보
terraform console       # 표현식 테스트 (REPL)
terraform graph         # 의존성 그래프 생성
```

---

## 2. init은 언제 해야 하나

> [!note] 핵심 규칙
> `terraform {}`, `provider {}`, `module {}` 블록을 건드렸으면 init.
> 나머지는 바로 plan/apply.

### ✅ init 필요한 경우

| 상황 | 예시 |
|------|------|
| 처음 프로젝트 시작 | `terraform init` (최초 1회) |
| Provider 버전 변경 | `aws "~> 5.0"` → `"~> 6.0"` |
| 새 Provider 추가 | aws + google 같이 쓸 때 |
| Backend 설정 변경 | local → S3 |
| Module 추가/변경 | `module "vpc" { source = "..." }` |
| .terraform/ 삭제됨 | 폴더 날렸거나 git clone 직후 |
| lock 파일 충돌 | `.terraform.lock.hcl` 문제 |

### ❌ init 필요 없는 경우

| 상황 | 바로 할 것 |
|------|-----------|
| 리소스 추가/수정/삭제 | `plan → apply` |
| 변수 값 변경 (tfvars) | `plan → apply` |
| output 변경 | `plan → apply` |
| 태그 변경 | `plan → apply` |
| Security Group 규칙 수정 | `plan → apply` |

### 💡 init 관련 유용한 옵션

```bash
# Provider 업그레이드 (lock 파일 갱신)
terraform init -upgrade

# Backend 재설정
terraform init -reconfigure

# Module만 갱신
terraform init -upgrade
```

---

## 3. 매번 해야 하는 루틴

```
코드 수정 (.tf 파일 편집)
    │
    ▼
terraform fmt              # 포맷 정리 (선택, 습관 들이면 좋음)
    │
    ▼
terraform validate         # 문법 체크 (선택)
    │
    ▼
terraform plan             # 반드시! 변경사항 미리보기
    │
    ▼
 사람이 눈으로 확인
 - "+" 만 있으면 → 안전
 - "~" 있으면 → 내용 확인
 - "-/+" 있으면 → 멈추고 생각!
 - "-" 있으면 → 정말 삭제할 건지 확인
    │
    ▼
terraform apply            # 확인 후 실행
    │
    ▼
terraform output           # 결과 확인 (선택)
```

---

## 4. plan 읽는 법

### 📊 기호 의미

```
  +  create              새로 생성 (안전)
  -  destroy             삭제 (주의!)
  ~  update in-place     제자리 수정 (안전)
 -/+ replace             삭제 후 재생성 (위험!)
 +/- create then destroy 생성 후 삭제 (약간 안전)
  <= read                데이터 소스 읽기 (안전)
```

### 💡 위험 신호 감지

```
# 이게 보이면 인스턴스가 날아간다
-/+ resource "aws_instance" "app" {
      ~ ami = "ami-xxx" → "ami-yyy"  # forces replacement ← 핵심!
    }

# "forces replacement" = 이 속성 때문에 재생성됨
```

### 📊 재생성 유발 속성 (주요 리소스)

| 리소스 | 변경 시 재생성되는 속성 |
|--------|----------------------|
| **aws_instance** | ami, subnet_id, availability_zone |
| **aws_db_instance** | identifier, engine, availability_zone |
| **aws_eks_cluster** | name |
| **google_compute_instance** | name, machine_type, zone, boot_disk |
| **google_sql_database_instance** | name, region |

> [!warning] 변경해도 재생성 안 되는 속성
> - tags, security_groups (EC2)
> - instance_type (EC2, 중지 후 변경)
> - ingress/egress (Security Group)

---

## 5. 안전한 apply 습관

### 💻 Plan 파일로 저장 후 Apply

```bash
# 1. plan 결과를 파일로 저장
terraform plan -out=tfplan

# 2. plan 파일로 정확히 그 변경만 apply
terraform apply tfplan

# 장점:
# - plan과 apply 사이에 상태가 바뀌어도 안전
# - 보이는 그대로만 실행됨
# - CI/CD에서 필수 패턴
```

### 💻 특정 리소스만 Apply

```bash
# SG만 변경하고 싶을 때 (다른 건 건드리기 싫을 때)
terraform apply -target=aws_security_group.web

# 여러 개 지정 가능
terraform apply -target=aws_subnet.public[0] -target=aws_subnet.public[1]
```

> [!warning] -target 주의
> - 의존성 있는 리소스가 누락될 수 있음
> - 임시 조치용이지, 상시 사용은 비추
> - 이후 전체 plan으로 확인 필수

### 💻 Destroy도 부분 가능

```bash
# 특정 리소스만 삭제
terraform destroy -target=aws_nat_gateway.main

# NAT Gateway만 삭제하고 나머지는 유지
# → 비용 절약용으로 유용
```

---

## 6. 리전과 존

### 📊 AWS vs GCP 비교

```
AWS 구조:
  Region      = ap-northeast-2 (서울)
  └── AZ      = ap-northeast-2a, 2b, 2c, 2d

GCP 구조:
  Region      = asia-northeast3 (서울)
  └── Zone    = asia-northeast3-a, b, c
```

| 항목 | AWS | GCP |
|------|-----|-----|
| 서울 리전 | `ap-northeast-2` | `asia-northeast3` |
| 도쿄 리전 | `ap-northeast-1` | `asia-northeast1` |
| 미국 동부 | `us-east-1` | `us-east1` |
| 가용영역 | `ap-northeast-2a` | `asia-northeast3-a` |

### 💡 리소스별 리전/존 지정 방식

```
AWS:
  - Provider에서 region 설정 → 전체 적용
  - Subnet이 AZ를 결정 → EC2는 Subnet 따라감
  - EC2에 직접 AZ 지정 안 함

GCP:
  - Provider에서 region/zone 설정
  - VM에 zone 직접 지정
  - 리전 리소스 vs 존 리소스 구분 필요
```

```hcl
# AWS: Subnet이 AZ 결정
resource "aws_instance" "app" {
  subnet_id = aws_subnet.private[0].id  # 이 서브넷의 AZ로 감
}

# GCP: VM에 zone 직접 지정
resource "google_compute_instance" "app" {
  zone = "asia-northeast3-a"  # 직접 지정
}
```

> [!tip] 헷갈림 방지
> AWS: **서브넷이 위치를 결정** (간접 지정)
> GCP: **리소스가 직접 zone 지정** (직접 지정)

---

## 7. 리소스 확인 방법 (콘솔 안 가고)

### 💻 Terraform State 활용

```bash
# 관리 중인 모든 리소스 목록
terraform state list
# aws_vpc.main
# aws_subnet.public[0]
# aws_subnet.public[1]
# aws_security_group.web
# ...

# 특정 리소스 상세 정보 (ID, 속성 전부)
terraform state show aws_vpc.main
# id = "vpc-0478120058493042f"
# cidr_block = "10.0.0.0/16"
# ...

# 특정 리소스 간단 ID만
terraform output vpc_id
```

### 💻 CLI로 직접 확인

```bash
# AWS
aws ec2 describe-vpcs --filters "Name=tag:Project,Values=my-infra"
aws ec2 describe-instances --filters "Name=tag:Name,Values=my-infra-*"
aws ec2 describe-security-groups --filters "Name=vpc-id,Values=vpc-xxx"

# GCP
gcloud compute instances list
gcloud compute instances describe INSTANCE_NAME --zone=asia-northeast3-a
gcloud compute networks list
gcloud compute firewall-rules list
```

### 💡 Output을 미리 정의해두면 편하다

```hcl
# outputs.tf
output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

# 사용
terraform output              # 전체
terraform output vpc_id       # 개별
terraform output -json        # JSON 형식 (스크립트에서 파싱)
```

---

## 8. 상황별 빠른 참조

| 상황 | 명령어 |
|------|--------|
| 처음 시작 | `init → plan → apply` |
| 코드 수정 후 | `plan → apply` |
| provider 변경 | `init → plan → apply` |
| 뭐가 있는지 확인 | `state list` |
| 특정 리소스 상세 | `state show <resource>` |
| 하나만 적용 | `apply -target=<resource>` |
| 전부 삭제 | `destroy` |
| 하나만 삭제 | `destroy -target=<resource>` |
| 코드 정리 | `fmt` |
| 문법 확인 | `validate` |
| 리소스 이름 변경 | `state mv old_name new_name` |
| 관리에서 제외 | `state rm <resource>` |
| 기존 리소스 편입 | `import <resource> <id>` |
| 현재 상태 새로고침 | `apply -refresh-only` |

---

## 9. lifecycle로 사고 방지

### 💻 prevent_destroy (삭제 차단)

```hcl
resource "aws_db_instance" "main" {
  # ...

  lifecycle {
    prevent_destroy = true
  }
}

# destroy 시도하면:
# Error: Instance cannot be destroyed
# 실수로 DB 날리는 것 방지
```

### 💻 create_before_destroy (교체 시 새 거 먼저)

```hcl
resource "aws_instance" "app" {
  # ...

  lifecycle {
    create_before_destroy = true
  }
}

# 기본: 삭제 → 생성 (다운타임 발생)
# 설정 후: 생성 → 정상 확인 → 삭제 (무중단)
```

### 💻 ignore_changes (특정 속성 변경 무시)

```hcl
resource "aws_instance" "app" {
  ami = "ami-xxx"

  lifecycle {
    ignore_changes = [ami, tags]
  }
}

# AMI가 바뀌어도 재생성 안 함
# 콘솔에서 태그 수동 변경해도 되돌리지 않음
```

### 📊 lifecycle 사용 가이드

| 옵션 | 언제 쓰나 |
|------|----------|
| prevent_destroy | RDS, S3 등 데이터 있는 리소스 |
| create_before_destroy | 무중단 교체가 필요한 EC2, ASG |
| ignore_changes | 외부에서 변경되는 속성 (Auto Scaling 등) |

---

## 10. 자주 하는 실수 모음

### 🔍 실수 1: plan 안 보고 apply

```bash
# 나쁜 습관
terraform apply -auto-approve   # 뭐가 바뀌는지도 모르고 실행

# 좋은 습관
terraform plan -out=tfplan      # 먼저 확인
terraform apply tfplan           # 확인한 것만 실행
```

### 🔍 실수 2: tfstate를 git에 커밋

```
terraform.tfstate에는 비밀번호, Access Key 등이 포함될 수 있음

.gitignore에 반드시 추가:
  *.tfstate
  *.tfstate.backup
  .terraform/
  *.tfvars (민감 변수 포함 시)
```

### 🔍 실수 3: 여러 명이 동시에 apply

```
A가 apply 중에 B도 apply → state 충돌 → 인프라 꼬임

해결: Remote Backend + State Locking
  - S3 + DynamoDB (AWS)
  - GCS (GCP)
  - Terraform Cloud
```

### 🔍 실수 4: 리소스 이름 변경 시 삭제-재생성

```hcl
# 변경 전
resource "aws_instance" "web" { ... }

# 변경 후 (이름만 바꿈)
resource "aws_instance" "app" { ... }

# Terraform은 web 삭제 + app 생성으로 판단!
# 해결: state mv로 이름만 변경
terraform state mv aws_instance.web aws_instance.app
```

### 🔍 실수 5: destroy 대상 착각

```bash
# VPC만 삭제하려고 했는데...
terraform destroy
# → 전체 인프라 삭제!

# 올바른 방법
terraform destroy -target=aws_nat_gateway.main
```

---

> [!note] 문서 정보
> - 작성일: 2026-01-25
> - 관련 문서: [[Terraform-기초-가이드]], [[Terraform-설치-및-환경구축]]
