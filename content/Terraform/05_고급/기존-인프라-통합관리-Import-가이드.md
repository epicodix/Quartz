---
title: 기존 인프라 Terraform 통합 관리 - Import 완전 가이드
tags:
  - terraform
  - import
  - migration
  - devops
  - infrastructure
aliases:
  - tf-import-가이드
  - 인프라-통합관리
date: 2026-01-25
category: Terraform/05_고급
status: 완성
priority: 높음
---

# 🎯 기존 인프라 Terraform 통합 관리 가이드

## 📑 목차
- [[#1. 왜 기존 인프라를 Import 하는가|왜 Import?]]
- [[#2. Import 워크플로우|Import 워크플로우]]
- [[#3. AWS 리소스별 Import 실전|AWS Import 실전]]
- [[#4. GCP 리소스별 Import 실전|GCP Import 실전]]
- [[#5. Import Block 방식 (Terraform 1.5+)|Import Block]]
- [[#6. 대규모 Import 전략|대규모 Import]]
- [[#7. 통합 관리 환경 구축|통합 관리 환경]]
- [[#8. 주의사항과 트러블슈팅|주의사항]]

---

## 1. 왜 기존 인프라를 Import 하는가

> [!note] 핵심
> 콘솔에서 클릭으로 만든 리소스를 Terraform 코드 관리로 편입시키는 작업.
> "클릭 인프라"에서 "코드 인프라"로 전환하는 것이 목표.

### 💡 Import가 필요한 상황

```
1. 콘솔에서 만든 기존 리소스를 Terraform으로 관리하고 싶을 때
2. 팀원이 콘솔에서 급하게 만든 리소스를 코드로 정리할 때
3. 다른 도구(CloudFormation, Ansible 등)에서 Terraform으로 전환할 때
4. 여러 계정/프로젝트의 인프라를 하나의 Terraform으로 통합할 때
```

### 📊 Import 전후 비교

```
Before (혼돈):
  - 콘솔에서 만든 VPC 3개
  - CLI로 만든 EC2 5대
  - 누가 언제 만들었는지 모름
  - 변경 이력 없음
  - 똑같은 거 재현 불가

After (통합 관리):
  - 모든 리소스가 .tf 파일에 정의
  - terraform plan으로 변경사항 추적
  - git으로 변경 이력 관리
  - terraform apply로 동일 환경 재현 가능
```

---

## 2. Import 워크플로우

### 📋 전체 흐름

```
Step 1: 기존 리소스 ID 확인 (콘솔/CLI)
    ↓
Step 2: .tf 파일에 빈 리소스 블록 작성
    ↓
Step 3: terraform import 실행
    ↓
Step 4: terraform state show로 실제 속성 확인
    ↓
Step 5: state show 내용으로 .tf 파일 채우기
    ↓
Step 6: terraform plan → 차이 0 되는지 확인
    ↓
Step 7: 완료! 이후부터 Terraform으로 관리
```

### 💻 Step by Step 실전

#### Step 1: 리소스 ID 확인

```bash
# AWS
aws ec2 describe-vpcs --query 'Vpcs[*].[VpcId,Tags[?Key==`Name`].Value|[0]]' --output table
# ┌──────────────────────┬────────────┐
# │ vpc-04d16adb5ed53902c│ default    │
# │ vpc-0478120058493042f│ my-infra   │
# └──────────────────────┴────────────┘

aws ec2 describe-instances --query 'Reservations[*].Instances[*].[InstanceId,Tags[?Key==`Name`].Value|[0],State.Name]' --output table

# GCP
gcloud compute instances list --format="table(name,zone,status)"
gcloud compute networks list --format="table(name,subnet_mode)"
```

#### Step 2: 빈 리소스 블록 작성

```hcl
# import_resources.tf

# 아직 속성은 비워둠 → import 후에 채울 것
resource "aws_vpc" "existing" {}

resource "aws_instance" "existing_web" {}

resource "aws_security_group" "existing_sg" {}
```

#### Step 3: Import 실행

```bash
# 형식: terraform import <리소스주소> <실제ID>

# AWS 예시
terraform import aws_vpc.existing vpc-04d16adb5ed53902c
terraform import aws_instance.existing_web i-0123456789abcdef
terraform import aws_security_group.existing_sg sg-0123456789abcdef

# GCP 예시
terraform import google_compute_instance.existing_vm \
  projects/my-project/zones/asia-northeast3-a/instances/my-vm

terraform import google_compute_network.existing_net \
  projects/my-project/global/networks/my-network
```

출력:
```
Import successful!
The resources that were imported are shown above.
These resources are now in your Terraform state.
```

#### Step 4: State에서 실제 속성 확인

```bash
terraform state show aws_vpc.existing
```

출력 예시:
```hcl
# aws_vpc.existing:
resource "aws_vpc" "existing" {
    arn                              = "arn:aws:ec2:ap-northeast-2:317250221510:vpc/vpc-04d16adb5ed53902c"
    cidr_block                       = "172.31.0.0/16"
    default_network_acl_id           = "acl-xxx"
    default_route_table_id           = "rtb-xxx"
    default_security_group_id        = "sg-xxx"
    dhcp_options_id                  = "dopt-xxx"
    enable_dns_hostnames             = true
    enable_dns_support               = true
    id                               = "vpc-04d16adb5ed53902c"
    instance_tenancy                 = "default"
    tags                             = {}
    tags_all                         = {}
}
```

#### Step 5: .tf 파일 채우기

```hcl
# state show 결과에서 필요한 속성만 복사
resource "aws_vpc" "existing" {
  cidr_block           = "172.31.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  instance_tenancy     = "default"

  tags = {
    Name = "default-vpc"
  }
}
```

> [!warning] 주의
> - `id`, `arn`, `owner_id` 등 computed 속성은 넣지 않음
> - `tags_all`은 넣지 않음 (`tags`만)
> - state show에서 `(known after apply)`인 것들은 제외

#### Step 6: Plan으로 차이 확인

```bash
terraform plan
```

```
No changes. Your infrastructure matches the configuration.
```

이 메시지가 나오면 성공. 차이가 있으면 .tf 파일을 수정하여 맞춤.

---

## 3. AWS 리소스별 Import 실전

### 📊 주요 리소스 Import 명령어

```bash
# VPC
terraform import aws_vpc.main vpc-xxxxxxxxx

# Subnet
terraform import aws_subnet.public subnet-xxxxxxxxx

# Internet Gateway
terraform import aws_internet_gateway.main igw-xxxxxxxxx

# Route Table
terraform import aws_route_table.public rtb-xxxxxxxxx

# Route Table Association
terraform import aws_route_table_association.public rtbassoc-xxxxxxxxx

# Security Group
terraform import aws_security_group.web sg-xxxxxxxxx

# EC2 Instance
terraform import aws_instance.app i-xxxxxxxxx

# RDS
terraform import aws_db_instance.main my-database-identifier

# S3 Bucket
terraform import aws_s3_bucket.main my-bucket-name

# IAM Role
terraform import aws_iam_role.main role-name

# IAM Policy
terraform import aws_iam_policy.main arn:aws:iam::123456789012:policy/policy-name

# ALB
terraform import aws_lb.main arn:aws:elasticloadbalancing:...

# Target Group
terraform import aws_lb_target_group.main arn:aws:elasticloadbalancing:...

# ECS Cluster
terraform import aws_ecs_cluster.main cluster-name

# ECS Service
terraform import aws_ecs_service.main cluster-name/service-name

# Lambda
terraform import aws_lambda_function.main function-name

# CloudWatch Alarm
terraform import aws_cloudwatch_metric_alarm.main alarm-name
```

### 💡 ID 찾기 치트시트

```bash
# VPC, Subnet, SG, IGW, RT
aws ec2 describe-vpcs --output table
aws ec2 describe-subnets --filters "Name=vpc-id,Values=vpc-xxx" --output table
aws ec2 describe-security-groups --filters "Name=vpc-id,Values=vpc-xxx" --output table
aws ec2 describe-internet-gateways --output table
aws ec2 describe-route-tables --filters "Name=vpc-id,Values=vpc-xxx" --output table

# EC2
aws ec2 describe-instances --output table

# RDS (identifier 사용, id 아님)
aws rds describe-db-instances --query 'DBInstances[*].DBInstanceIdentifier'

# S3 (버킷 이름 사용)
aws s3 ls

# IAM
aws iam list-roles --query 'Roles[*].RoleName'
aws iam list-policies --scope Local --query 'Policies[*].[PolicyName,Arn]'

# ALB (ARN 사용)
aws elbv2 describe-load-balancers --query 'LoadBalancers[*].[LoadBalancerName,LoadBalancerArn]'

# Lambda
aws lambda list-functions --query 'Functions[*].FunctionName'
```

---

## 4. GCP 리소스별 Import 실전

### 📊 주요 리소스 Import 명령어

```bash
# 형식: projects/{{project}}/...

# Compute Instance
terraform import google_compute_instance.vm \
  projects/my-project/zones/asia-northeast3-a/instances/my-vm

# VPC Network
terraform import google_compute_network.main \
  projects/my-project/global/networks/my-network

# Subnet
terraform import google_compute_subnetwork.main \
  projects/my-project/regions/asia-northeast3/subnetworks/my-subnet

# Firewall Rule
terraform import google_compute_firewall.allow_http \
  projects/my-project/global/firewalls/allow-http

# Cloud SQL
terraform import google_sql_database_instance.main \
  projects/my-project/instances/my-db

# GKE Cluster
terraform import google_container_cluster.main \
  projects/my-project/locations/asia-northeast3/clusters/my-cluster

# Cloud Storage Bucket
terraform import google_storage_bucket.main \
  projects/my-project/buckets/my-bucket

# Cloud Run Service
terraform import google_cloud_run_service.main \
  locations/asia-northeast3/namespaces/my-project/services/my-service

# Service Account
terraform import google_service_account.main \
  projects/my-project/serviceAccounts/my-sa@my-project.iam.gserviceaccount.com
```

### 💡 GCP ID 찾기

```bash
gcloud compute instances list --format="table(name,zone)"
gcloud compute networks list
gcloud compute networks subnets list
gcloud compute firewall-rules list
gcloud sql instances list
gcloud container clusters list
gcloud storage ls
gcloud run services list
```

---

## 5. Import Block 방식 (Terraform 1.5+)

> [!info] 새로운 방식
> Terraform 1.5부터 CLI 대신 코드로 import 가능.
> `terraform plan`에서 import를 미리보기할 수 있음.

### 💻 기존 방식 (CLI)

```bash
# 하나씩 수동 실행
terraform import aws_vpc.existing vpc-xxx
terraform import aws_subnet.public subnet-xxx
# ... 리소스가 많으면 노가다
```

### 💻 새로운 방식 (Import Block)

```hcl
# imports.tf
import {
  to = aws_vpc.existing
  id = "vpc-04d16adb5ed53902c"
}

import {
  to = aws_subnet.public
  id = "subnet-0ff84debf6fe53415"
}

import {
  to = aws_security_group.web
  id = "sg-0142f8aab69939014"
}
```

```bash
# plan에서 import 미리보기 가능!
terraform plan
# aws_vpc.existing: Preparing import...
# aws_vpc.existing: Refreshing state...
# Plan: 3 to import, 0 to add, 0 to change, 0 to destroy.

terraform apply  # import 실행
```

### 💻 코드 자동 생성 (Terraform 1.5+)

```bash
# import block + 빈 resource로 코드 자동 생성
terraform plan -generate-config-out=generated.tf
```

```hcl
# generated.tf (자동 생성됨!)
resource "aws_vpc" "existing" {
  cidr_block           = "172.31.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  instance_tenancy     = "default"
  tags                 = {}
}
```

> [!tip] 이 방식의 장점
> - state show → 복사 → 붙여넣기 노가다 없음
> - plan에서 import 미리보기 가능
> - 여러 리소스 한번에 import
> - 코드 리뷰 가능 (PR에서 확인)

---

## 6. 대규모 Import 전략

### 📋 단계별 전략

```
Phase 1: 인벤토리 작성
  - 현재 존재하는 모든 리소스 목록화
  - 어떤 게 Terraform 관리이고 어떤 게 수동인지 분류

Phase 2: 우선순위 결정
  - 핵심 인프라부터 (VPC, IAM)
  - 자주 변경되는 것 우선 (SG, EC2)
  - 데이터가 있는 것은 마지막 (RDS, S3)

Phase 3: 순차 Import
  - 의존성 순서대로 (VPC → Subnet → SG → EC2)
  - 각 단계에서 plan 차이 0 확인

Phase 4: 검증
  - terraform plan → "No changes" 확인
  - 실제 운영 영향 없는지 확인
```

### 📊 Import 순서 (의존성 기반)

```
1. VPC
2. Subnet
3. Internet Gateway
4. NAT Gateway
5. Route Table
6. Route Table Association
7. Security Group
8. EC2 / RDS / ECS 등
9. ALB / Target Group
10. Route53 / CloudFront
```

### 💻 인벤토리 스크립트

```bash
#!/bin/bash
# aws-inventory.sh - 현재 리소스 목록 수집

echo "=== VPCs ==="
aws ec2 describe-vpcs --query 'Vpcs[*].[VpcId,CidrBlock,Tags[?Key==`Name`].Value|[0]]' --output table

echo "=== Subnets ==="
aws ec2 describe-subnets --query 'Subnets[*].[SubnetId,VpcId,CidrBlock,AvailabilityZone,Tags[?Key==`Name`].Value|[0]]' --output table

echo "=== Security Groups ==="
aws ec2 describe-security-groups --query 'SecurityGroups[*].[GroupId,VpcId,GroupName]' --output table

echo "=== EC2 Instances ==="
aws ec2 describe-instances --query 'Reservations[*].Instances[*].[InstanceId,InstanceType,State.Name,Tags[?Key==`Name`].Value|[0]]' --output table

echo "=== RDS ==="
aws rds describe-db-instances --query 'DBInstances[*].[DBInstanceIdentifier,Engine,DBInstanceStatus]' --output table

echo "=== S3 Buckets ==="
aws s3 ls

echo "=== Lambda ==="
aws lambda list-functions --query 'Functions[*].[FunctionName,Runtime]' --output table
```

---

## 7. 통합 관리 환경 구축

### 📊 멀티 클라우드 통합 구조

```
terraform-infra/
├── aws/
│   ├── backend.tf          # S3 Remote State
│   ├── providers.tf        # AWS Provider
│   ├── vpc.tf
│   ├── ec2.tf
│   └── ...
├── gcp/
│   ├── backend.tf          # GCS Remote State
│   ├── providers.tf        # Google Provider
│   ├── network.tf
│   ├── compute.tf
│   └── ...
├── modules/                 # 공통 모듈
│   ├── vpc/
│   ├── compute/
│   └── monitoring/
└── scripts/
    ├── inventory.sh         # 리소스 인벤토리
    └── import-all.sh        # 일괄 Import
```

### 💻 Remote Backend 설정 (팀 협업 필수)

```hcl
# AWS - S3 Backend
terraform {
  backend "s3" {
    bucket         = "my-terraform-state-317250221510"
    key            = "prod/terraform.tfstate"
    region         = "ap-northeast-2"
    dynamodb_table = "terraform-lock"    # State Locking
    encrypt        = true
  }
}

# 필요한 리소스 (한 번만 수동 생성)
# 1. S3 Bucket (상태 저장)
# 2. DynamoDB Table (동시 접근 방지)
```

```hcl
# GCP - GCS Backend
terraform {
  backend "gcs" {
    bucket = "my-terraform-state-gcp"
    prefix = "prod/terraform.tfstate"
  }
}
```

### 💻 Remote Backend 용 리소스 생성

```hcl
# bootstrap/main.tf (이것만 로컬 state로 관리)

provider "aws" {
  region = "ap-northeast-2"
}

# State 저장용 S3
resource "aws_s3_bucket" "terraform_state" {
  bucket = "my-terraform-state-317250221510"

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name = "Terraform State"
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"    # 상태 파일 버전 관리
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# State Locking용 DynamoDB
resource "aws_dynamodb_table" "terraform_lock" {
  name         = "terraform-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name = "Terraform Lock"
  }
}
```

### 📊 State 관리 명령어

```bash
# State 목록
terraform state list

# State에서 리소스 상세 확인
terraform state show aws_instance.app

# 리소스 이름 변경 (삭제-재생성 방지)
terraform state mv aws_instance.old_name aws_instance.new_name

# 모듈로 이동
terraform state mv aws_vpc.main module.vpc.aws_vpc.main

# 관리에서 제외 (리소스는 남기고 state에서만 제거)
terraform state rm aws_instance.temp

# State 강제 새로고침
terraform apply -refresh-only

# State Pull/Push (Remote Backend)
terraform state pull > backup.tfstate
terraform state push backup.tfstate
```

### 💻 .gitignore 필수 설정

```gitignore
# Terraform
.terraform/
*.tfstate
*.tfstate.backup
*.tfplan
crash.log

# 민감 정보
*.tfvars        # 비밀번호 포함 가능
!example.tfvars # 예시 파일은 커밋

# OS
.DS_Store
```

---

## 8. 주의사항과 트러블슈팅

### 🔍 Import 시 주의사항

> [!warning] Import는 State만 가져옴
> - Import는 .tf 코드를 자동 생성하지 않음 (1.5+ generate-config 제외)
> - State에만 추가되고, 코드는 직접 작성해야 함
> - 코드 없이 plan하면 "destroy" 계획이 나옴!

```bash
# 잘못된 순서
terraform import aws_instance.app i-xxx
terraform plan
# 결과: 1 to destroy ← 코드가 없으니 삭제하겠다고 함!

# 올바른 순서
# 1. import
# 2. state show로 속성 확인
# 3. .tf 파일 작성
# 4. plan → "No changes" 확인
```

### 🔍 Import 후 plan 차이가 나는 경우

```
원인 1: 속성 누락
  → state show에서 빠뜨린 속성 추가

원인 2: 기본값 차이
  → AWS가 자동 설정한 값과 Terraform 기본값이 다름
  → 명시적으로 값 지정

원인 3: computed 속성을 .tf에 넣음
  → id, arn 등 자동 계산 속성은 제거

원인 4: tags_all
  → tags만 사용, tags_all은 제거
```

### 🔍 "Resource already managed" 에러

```bash
# 이미 state에 있는 리소스를 다시 import 시도
Error: Resource already managed by Terraform

# 해결: state에서 먼저 제거 후 재import
terraform state rm aws_instance.app
terraform import aws_instance.app i-xxx
```

### 🔍 "Cannot import non-existent resource" 에러

```bash
# 리소스 ID가 잘못됨
Error: Cannot import non-existent remote object

# 해결: ID 다시 확인
aws ec2 describe-instances --instance-ids i-xxx
```

### 📊 Import 체크리스트

```
□ 리소스 ID 정확한지 확인
□ .tf 파일에 resource 블록 작성
□ terraform import 실행
□ terraform state show로 속성 확인
□ .tf 파일에 속성 채우기
□ computed 속성 (id, arn) 제거
□ terraform plan → "No changes" 확인
□ lifecycle { prevent_destroy = true } 추가 (중요 리소스)
□ git commit
```

---

## 📋 실전 예시: 기존 Default VPC Import

### 💻 현재 AWS 계정의 Default VPC를 Terraform으로 관리

```bash
# 1. Default VPC ID 확인
aws ec2 describe-vpcs --filters "Name=isDefault,Values=true" \
  --query 'Vpcs[0].VpcId' --output text
# vpc-04d16adb5ed53902c
```

```hcl
# 2. imports.tf (Import Block 방식)
import {
  to = aws_vpc.default
  id = "vpc-04d16adb5ed53902c"
}

# 3. default_vpc.tf
resource "aws_vpc" "default" {
  cidr_block           = "172.31.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  instance_tenancy     = "default"

  tags = {
    Name      = "default-vpc"
    ManagedBy = "terraform"
  }

  lifecycle {
    prevent_destroy = true   # Default VPC 삭제 방지
  }
}
```

```bash
# 4. plan으로 확인
terraform plan
# Plan: 1 to import, 0 to add, 1 to change, 0 to destroy.
# (tags 추가만 변경됨)

# 5. apply
terraform apply
```

---

> [!note] 문서 정보
> - 작성일: 2026-01-25
> - 관련 문서: [[Terraform-워크플로우-치트시트]], [[팀-협업-가이드]]
> - Terraform 버전: v1.14.3 (import block 지원)
