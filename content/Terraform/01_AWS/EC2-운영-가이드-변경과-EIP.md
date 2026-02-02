---
title: EC2 운영 가이드 - 인스턴스 변경과 Elastic IP 실전
tags:
  - terraform
  - aws
  - ec2
  - elastic-ip
  - networking
  - devops
aliases:
  - ec2-운영-가이드
  - ec2-eip
date: 2026-01-25
category: Terraform/01_AWS
status: 완성
priority: 높음
---

# 🎯 EC2 운영 가이드 - 인스턴스 변경과 Elastic IP 실전

## 📑 목차
- [[#1. EC2 생성 코드|EC2 생성]]
- [[#2. EC2 변경 위험도 분류|변경 위험도]]
- [[#3. 변경 전 체크리스트|변경 전 체크]]
- [[#4. instance_type 변경 실습|타입 변경 실습]]
- [[#5. Elastic IP 구성|EIP 구성]]
- [[#6. EIP + instance_type 변경 검증|EIP 검증]]
- [[#7. SSH 접속 및 확인 방법|SSH 확인 방법]]
- [[#8. 실습 결과 요약|결과 요약]]

---

## 1. EC2 생성 코드

### 💻 AMI 자동 조회 (data source)

```hcl
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023*-kernel-*-arm64"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}
```

> [!info] data source란?
> AWS에 이미 존재하는 리소스를 조회하는 블록.
> 위 코드는 "Amazon Linux 2023 ARM64 최신 AMI"를 자동으로 찾아줌.
> 하드코딩 대신 사용하면 항상 최신 AMI를 참조 가능.

### 💻 SSH Key Pair 등록

```bash
# 로컬에서 키 생성
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N "" -C "aws-terraform"
```

```hcl
resource "aws_key_pair" "main" {
  key_name   = "${var.project_name}-key"
  public_key = file("~/.ssh/id_ed25519.pub")

  tags = {
    Name    = "${var.project_name}-key"
    Project = var.project_name
  }
}
```

### 💻 Bastion EC2 인스턴스

```hcl
resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t4g.micro"
  key_name               = aws_key_pair.main.key_name
  subnet_id              = aws_subnet.public[0].id
  vpc_security_group_ids = [aws_security_group.bastion.id]

  root_block_device {
    volume_size = 8
    volume_type = "gp3"
  }

  tags = {
    Name    = "${var.project_name}-bastion"
    Project = var.project_name
    Role    = "bastion"
  }

  lifecycle {
    ignore_changes = [ami]  # AMI 업데이트로 재생성 방지
  }
}
```

> [!warning] `ignore_changes = [ami]`가 없으면?
> data source가 최신 AMI를 조회할 때마다 plan에서 `-/+` replace가 뜸.
> → apply 하면 인스턴스 삭제 후 재생성 → 데이터 소실!

### 💻 Output 설정

```hcl
output "bastion_public_ip" {
  description = "Bastion Host Elastic IP (고정)"
  value       = aws_eip.bastion.public_ip
}

output "bastion_instance_id" {
  description = "Bastion Instance ID"
  value       = aws_instance.bastion.id
}

output "bastion_ssh_command" {
  description = "SSH 접속 명령어"
  value       = "ssh -i ~/.ssh/id_ed25519 ec2-user@${aws_eip.bastion.public_ip}"
}
```

---

## 2. EC2 변경 위험도 분류

### 📊 안전한 변경 (서비스 영향 없음, 중단 없음)

| 속성 | Terraform 동작 | 설명 |
|------|---------------|------|
| tags | `~ update in-place` | 즉시 반영 |
| security_groups | `~ update in-place` | 즉시 반영 |
| monitoring | `~ update in-place` | 즉시 반영 |
| iam_instance_profile | `~ update in-place` | 즉시 반영 |
| volume_size 확장 | `~ update in-place` | 확장만 가능, 축소 불가 |

### 📊 다운타임 있는 변경 (데이터 유지, 잠시 중단)

| 속성 | Terraform 동작 | 설명 |
|------|---------------|------|
| instance_type | `~ update in-place` | 중지 → 변경 → 재시작 |

> [!info] instance_type 변경 시 발생하는 일
> 1. Terraform이 EC2 Stop API 호출
> 2. 인스턴스 중지 대기
> 3. ModifyInstanceAttribute로 타입 변경
> 4. EC2 Start API 호출
> 5. 인스턴스 시작 대기
>
> 소요 시간: 약 1분
> EBS 데이터: 유지
> Private IP: 유지
> Public IP: EIP 없으면 변경됨!

### 📊 위험한 변경 (인스턴스 삭제 재생성)

| 속성 | Terraform 동작 | 설명 |
|------|---------------|------|
| **ami** | `-/+ replace` | 새 OS로 재생성 |
| **subnet_id** | `-/+ replace` | 다른 서브넷으로 이동 불가 |
| **availability_zone** | `-/+ replace` | 다른 AZ로 이동 불가 |
| **key_name** | `-/+ replace` | SSH 키 변경 |
| **user_data** | `-/+ replace` | 부트스트랩 스크립트 변경 |

> [!danger] 재생성 시 잃는 것
> - Instance ID 변경
> - Public/Private IP 변경 (EIP 제외)
> - EBS root volume 삭제 (delete_on_termination=true)
> - 인스턴스 내부의 모든 설치 패키지, 설정, 데이터
> - 메모리 상태, 실행 중인 프로세스
> - /tmp, /var/log 등 임시 데이터

### 📊 plan 읽기 실전

```bash
# 안전 (태그 추가)
  ~ resource "aws_instance" "bastion" {
      ~ tags = {
          + "Env" = "dev"
        }
    }

# 다운타임 (타입 변경)
  ~ resource "aws_instance" "bastion" {
      ~ instance_type = "t4g.micro" -> "t4g.small"
    }

# 위험! (AMI 변경 → 재생성)
-/+ resource "aws_instance" "bastion" {
      ~ ami = "ami-aaa" -> "ami-bbb"  # forces replacement
      ~ id  = "i-xxx" -> (known after apply)  ← ID 바뀜 = 새 인스턴스
    }
```

> [!tip] 핵심 판단 기준
> - `~` = 안전
> - `-/+` + `forces replacement` = 위험, 멈추고 생각
> - `id = (known after apply)` = 새 인스턴스 = 데이터 소실

---

## 3. 변경 전 체크리스트

### 📋 instance_type 변경 전

```
□ 1. EIP 연결 여부 확인
     EIP 없으면 → Public IP 바뀜 → SSH 끊김, DNS 깨짐

□ 2. 같은 아키텍처인지 확인
     ARM(t4g) → ARM(t4g): OK
     ARM(t4g) → x86(t3): AMI 불일치로 replace 발생!

□ 3. 현재 AZ에서 지원되는 타입인지 확인
     같은 패밀리(t4g.micro → t4g.small): 보통 OK
     다른 패밀리: AZ 지원 여부 확인 필요

□ 4. 실행 중인 프로세스 확인
     중지되므로 진행 중인 작업 중단됨

□ 5. plan에서 ~ (update) 인지 확인
     -/+ (replace) 가 뜨면 멈출 것
```

### 📋 위험한 변경 (ami, subnet 등) 전

```
□ 1. plan에서 -/+ 또는 forces replacement 확인
□ 2. 데이터 백업 (EBS 스냅샷)
□ 3. 별도 EBS 볼륨은 delete_on_termination=false 확인
□ 4. Elastic IP 연결 여부 (재연결 가능)
□ 5. Security Group, IAM Role 재적용 여부
□ 6. User Data로 자동 설정 가능한지 (수동 설치 최소화)
```

---

## 4. instance_type 변경 실습

### 📋 실습 시나리오

```
t4g.micro (메모리 1GB) → t4g.small (메모리 2GB) → t4g.micro (원복)
```

### 💻 변경 전 상태 확인 (SSH)

```bash
ssh -i ~/.ssh/id_ed25519 ec2-user@<PUBLIC_IP>
```

인스턴스 내부에서 확인하는 명령어들:

```bash
# 메타데이터로 인스턴스 정보 확인 (IMDSv2)
TOKEN=$(curl -s -X PUT 'http://169.254.169.254/latest/api/token' \
  -H 'X-aws-ec2-metadata-token-ttl-seconds: 21600')

# 인스턴스 타입
curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/instance-type

# 인스턴스 ID
curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/instance-id

# Public IP
curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/public-ipv4

# Private IP
curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/local-ipv4

# CPU 수
nproc

# 메모리
free -h | grep Mem

# 디스크
df -h /

# 가동 시간
uptime
```

> [!info] EC2 메타데이터 서비스 (IMDS)
> - `169.254.169.254`는 AWS 메타데이터 서버 (Link-local 주소)
> - 인스턴스 내부에서만 접근 가능
> - IMDSv2는 토큰 기반 (보안 강화)
> - 인스턴스 타입, ID, IP, IAM Role 등 조회 가능
> - 트러블슈팅 시 매우 유용

### 💻 데이터 유지 테스트용 파일 생성

```bash
# 변경 전에 테스트 파일 생성
echo '이 파일이 살아있으면 데이터 유지 성공' > ~/test-survival.txt
```

### 💻 Terraform 코드 변경

```hcl
# ec2.tf
# 변경 전
instance_type = "t4g.micro"

# 변경 후
instance_type = "t4g.small"
```

### 💻 Plan 확인

```bash
terraform plan
```

```
  ~ resource "aws_instance" "bastion" {
        id            = "i-05da54eaec43bb6a8"        ← ID 유지!
      ~ instance_type = "t4g.micro" -> "t4g.small"    ← 변경
      ~ public_ip     = "..." -> (known after apply)  ← IP 바뀔 수 있음
    }

Plan: 0 to add, 1 to change, 0 to destroy.
```

**확인 포인트:**
```
✅ ~ update in-place (재생성 아님)
✅ id 유지됨
✅ 0 to destroy
⚠️ public_ip → (known after apply): EIP 없으면 바뀜
```

### 💻 Apply

```bash
terraform apply -auto-approve
# 약 1분 소요 (중지 → 변경 → 재시작)
```

### 📊 실습 결과 (EIP 없을 때)

| 항목 | 변경 전 | 변경 후 |
|------|---------|---------|
| Instance Type | t4g.micro | t4g.small |
| Instance ID | i-05da54eaec43bb6a8 | i-05da54eaec43bb6a8 (유지) |
| CPU | 2 vCPU | 2 vCPU |
| **Memory** | **916MB** | **1.8GB (2배)** |
| Private IP | 10.0.1.68 | 10.0.1.68 (유지) |
| **Public IP** | **43.201.104.118** | **13.124.102.92 (변경!)** |
| 테스트 파일 | 있음 | 있음 (유지) |
| Uptime | 7분 | 0분 (리부팅) |

---

## 5. Elastic IP 구성

### 💡 왜 필요한가?

```
EIP 없이 instance_type 변경 → Public IP 바뀜
  → SSH 접속 주소 변경
  → DNS A레코드 깨짐
  → 외부 연동 서비스에 IP 재등록 필요

EIP 있으면 → 어떤 변경을 해도 IP 유지
```

### 💻 Terraform 코드

```hcl
# Elastic IP 생성
resource "aws_eip" "bastion" {
  domain = "vpc"

  tags = {
    Name    = "${var.project_name}-bastion-eip"
    Project = var.project_name
  }
}

# EC2에 연결
resource "aws_eip_association" "bastion" {
  instance_id   = aws_instance.bastion.id
  allocation_id = aws_eip.bastion.id
}
```

> [!info] EIP vs eip_association 분리하는 이유
> - EIP와 EC2를 독립적으로 관리 가능
> - EC2가 재생성되어도 EIP는 유지
> - association만 다시 걸면 됨
> - 한 EIP를 다른 인스턴스로 옮길 수도 있음

### 📊 EIP 비용

| 상태 | 비용 |
|------|------|
| 실행 중인 EC2에 연결 | **무료** |
| EC2 중지 상태 | $0.005/h (~$3.6/월) |
| 미연결 (방치) | $0.005/h (~$3.6/월) |
| 2번째 EIP (같은 인스턴스) | $0.005/h |

> [!warning] EIP 비용 함정
> - EC2 끌 때 EIP 과금 시작
> - 안 쓰는 EIP 방치하면 계속 과금
> - `terraform destroy` 하면 EIP도 해제되므로 비용 걱정 없음
> - 단, destroy 후 re-apply 시 새 IP 할당 (고정 IP 변경)

### 💻 Plan 확인

```bash
terraform plan
```

```
+ aws_eip.bastion           ← EIP 생성
+ aws_eip_association       ← EC2에 연결

Plan: 2 to add, 0 to change, 0 to destroy.
```

**EC2에 영향 없음 (중지 없음!)** — EIP 붙이는 건 인스턴스를 건드리지 않습니다.

---

## 6. EIP + instance_type 변경 검증

### 📋 핵심 테스트: EIP 붙인 상태에서 타입 변경하면 IP 유지되는가?

```
t4g.small (EIP: 43.201.xxx.xxx)
    ↓ instance_type 변경
t4g.micro (EIP: 43.201.xxx.xxx)  ← 유지!
```

### 📊 실습 결과

| 항목 | EIP 없이 타입 변경 | EIP 있고 타입 변경 |
|------|-------------------|-------------------|
| Instance ID | 유지 | 유지 |
| Private IP | 유지 | 유지 |
| **Public IP** | **변경됨!** | **유지!** |
| 데이터 | 유지 | 유지 |
| 다운타임 | ~1분 | ~1분 |

### 📊 전체 IP 변화 추적 (실제 실습 기록)

| 단계           | Public IP          | Instance Type | 비고         |
| ------------ | ------------------ | ------------- | ---------- |
| 최초 생성        | 43.201.104.118     | t4g.micro     | 자동 할당      |
| type → small | **13.124.102.92**  | t4g.small     | **IP 바뀜!** |
| EIP 연결       | **43.201.xxx.xxx** | t4g.small     | 고정 IP 할당   |
| type → micro | **43.201.xxx.xxx** | t4g.micro     | **IP 유지!** |
|              |                    |               |            |

---

## 7. SSH 접속 및 확인 방법

### 💻 기본 접속

```bash
ssh -i ~/.ssh/id_ed25519 ec2-user@<EIP_주소>
```

### 💻 원라이너로 확인 (접속하지 않고 실행)

```bash
# 인스턴스 타입만 확인
ssh -i ~/.ssh/id_ed25519 ec2-user@43.201.xxx.xxx \
  "TOKEN=\$(curl -s -X PUT 'http://169.254.169.254/latest/api/token' -H 'X-aws-ec2-metadata-token-ttl-seconds: 21600') && curl -s -H \"X-aws-ec2-metadata-token: \$TOKEN\" http://169.254.169.254/latest/meta-data/instance-type"
```

### 💻 전체 상태 확인 스크립트

```bash
#!/bin/bash
# check-instance.sh
HOST=${1:-43.201.xxx.xxx}
KEY=~/.ssh/id_ed25519

ssh -i $KEY -o StrictHostKeyChecking=no ec2-user@$HOST "
TOKEN=\$(curl -s -X PUT 'http://169.254.169.254/latest/api/token' \
  -H 'X-aws-ec2-metadata-token-ttl-seconds: 21600')

echo '=== Instance Type ==='
curl -s -H \"X-aws-ec2-metadata-token: \$TOKEN\" \
  http://169.254.169.254/latest/meta-data/instance-type

echo ''
echo '=== Instance ID ==='
curl -s -H \"X-aws-ec2-metadata-token: \$TOKEN\" \
  http://169.254.169.254/latest/meta-data/instance-id

echo ''
echo '=== Public IP ==='
curl -s -H \"X-aws-ec2-metadata-token: \$TOKEN\" \
  http://169.254.169.254/latest/meta-data/public-ipv4

echo ''
echo '=== Private IP ==='
curl -s -H \"X-aws-ec2-metadata-token: \$TOKEN\" \
  http://169.254.169.254/latest/meta-data/local-ipv4

echo ''
echo '=== CPU ==='
nproc

echo ''
echo '=== Memory ==='
free -h | grep Mem

echo ''
echo '=== Disk ==='
df -h /

echo ''
echo '=== Uptime ==='
uptime
"
```

### 💻 Terraform으로 확인 (SSH 없이)

```bash
# 현재 인스턴스 상태
terraform state show aws_instance.bastion

# Output 값만
terraform output bastion_public_ip
terraform output bastion_ssh_command

# AWS CLI로 직접
aws ec2 describe-instances \
  --instance-ids i-05da54eaec43bb6a8 \
  --query 'Reservations[0].Instances[0].[InstanceType,State.Name,PublicIpAddress,PrivateIpAddress]' \
  --output table
```

---

## 8. 실습 결과 요약

### 📊 변경 유형별 대응 전략

| 변경 | 동작 | IP 영향 | 데이터 | 대응 |
|------|------|---------|--------|------|
| tags | 즉시 반영 | 없음 | 유지 | 그냥 apply |
| SG | 즉시 반영 | 없음 | 유지 | 그냥 apply |
| instance_type | 중지/시작 | EIP 없으면 변경 | 유지 | EIP 필수 |
| ami | **삭제 재생성** | 전부 변경 | **소실** | ignore_changes |
| subnet_id | **삭제 재생성** | 전부 변경 | **소실** | 절대 변경 금지 |

### 📋 실무 필수 설정

```hcl
resource "aws_instance" "app" {
  # ...

  lifecycle {
    ignore_changes  = [ami, user_data]  # 재생성 방지
    prevent_destroy = true               # 삭제 차단
  }
}

# 고정 IP 필수
resource "aws_eip" "app" {
  domain = "vpc"
}

resource "aws_eip_association" "app" {
  instance_id   = aws_instance.app.id
  allocation_id = aws_eip.app.id
}
```

### 📋 현재 인프라 상태

```
VPC:     vpc-0478120058493042f (10.0.0.0/16)
Bastion: i-05da54eaec43bb6a8 (t4g.micro)
EIP:     43.201.xxx.xxx (고정)
SSH:     ssh -i ~/.ssh/id_ed25519 ec2-user@43.201.xxx.xxx
```

---

> [!note] 문서 정보
> - 작성일: 2026-01-25
> - 관련 문서: [[Terraform-AWS-VPC-구축-가이드]], [[Terraform-워크플로우-치트시트]]
> - 프로젝트: ~/terraform-aws-infra/
