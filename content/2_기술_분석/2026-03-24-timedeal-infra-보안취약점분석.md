---
title: timedeal-order 인프라(Terraform) 보안 취약점 분석
tags:
  - 보안
  - 취약점분석
  - Terraform
  - AWS
  - 인프라
  - timedeal
  - RDS
  - ElastiCache
aliases:
  - timedeal 인프라 보안
  - terraform 취약점
date: 2026-03-24
category: 2_기술_분석/보안
status: 완성
priority: 높음
---

# 🎯 timedeal 인프라(Terraform) 보안 취약점 분석

> [!note] 분석 대상
> - 경로: `/Users/a1234/Goorm4I/pposiraegi---terraform-infra/main.tf`
> - 스택: AWS (VPC, EC2, RDS, ElastiCache, ALB, CloudFront, S3, Route53)
> - 분석일: 2026-03-24

---

## 📑 목차
- [[#1. 취약점 요약표|취약점 요약표]]
- [[#2. HIGH — DB 자격증명 user_data 평문 노출|HIGH: DB 자격증명 평문 노출]]
- [[#3. HIGH — Terraform state 로컬 평문 저장|HIGH: Terraform state 평문 저장]]
- [[#4. MEDIUM — RDS 암호화 미설정|MEDIUM: RDS 암호화 미설정]]
- [[#5. MEDIUM — RDS skip_final_snapshot = true|MEDIUM: RDS 스냅샷 스킵]]
- [[#6. MEDIUM — RDS 자동 백업 비활성화|MEDIUM: RDS 자동 백업]]
- [[#7. MEDIUM — ElastiCache 암호화 미설정|MEDIUM: Redis 암호화]]
- [[#8. MEDIUM — EC2 EBS 볼륨 미암호화|MEDIUM: EBS 암호화]]
- [[#9. LOW — CloudFront → ALB HTTP 평문 통신|LOW: CF→ALB 평문]]
- [[#10. LOW — RDS deletion_protection 없음|LOW: RDS 삭제 보호]]
- [[#11. LOW — 모니터링/알람 없음|LOW: 모니터링 없음]]

---

## 1. 취약점 요약표

| 취약점 | 위치 | 위험도 | 즉시 조치 |
|--------|------|--------|----------|
| DB 자격증명 user_data 평문 전달 | aws_instance.backend | 🔴 HIGH | Secrets Manager 전환 |
| Terraform state 로컬 평문 저장 | terraform 백엔드 미설정 | 🔴 HIGH | S3 암호화 백엔드 구성 |
| RDS 저장 데이터 암호화 없음 | aws_db_instance.db | 🟡 MEDIUM | storage_encrypted = true |
| RDS skip_final_snapshot = true | aws_db_instance.db | 🟡 MEDIUM | false로 변경 |
| RDS 자동 백업 미설정 | aws_db_instance.db | 🟡 MEDIUM | backup_retention_period 설정 |
| ElastiCache 암호화/인증 없음 | aws_elasticache_cluster.redis | 🟡 MEDIUM | 전송/저장 암호화 추가 |
| EC2 EBS 볼륨 암호화 없음 | aws_instance.backend/bastion | 🟡 MEDIUM | root_block_device 암호화 |
| CloudFront → ALB HTTP 평문 | aws_cloudfront_distribution | 🟢 LOW | HTTP→HTTPS 변경 |
| RDS 삭제 보호 없음 | aws_db_instance.db | 🟢 LOW | deletion_protection = true |
| CloudWatch 알람/로그 없음 | 전체 | 🟢 LOW | 기본 알람 구성 |

---

## 2. HIGH — DB 자격증명 user_data 평문 노출

### 취약 코드

```hcl
# main.tf - aws_instance.backend
user_data = templatefile("user_data.sh", {
  db_url      = "jdbc:postgresql://${aws_db_instance.db.endpoint}/ecommerce"
  db_username = var.db_username
  db_password = var.db_password   # ← 평문 삽입
  jwt_secret  = var.jwt_secret    # ← 평문 삽입
  ...
})
```

### 문제점

- EC2 user_data는 **인스턴스 메타데이터 서버에서 조회 가능**
- `curl http://169.254.169.254/latest/user-data` 한 줄로 DB 비밀번호 + JWT secret 노출
- IMDSv1이 활성화된 경우 인증 없이 접근 가능

### 공격 시나리오

```
1. EC2에 SSRF 취약점 또는 RCE 발생
2. curl http://169.254.169.254/latest/user-data
   → db_password, jwt_secret 평문 획득
3. RDS에 직접 접속 (VPC 내부에서) → 전체 DB 탈취
4. JWT secret으로 임의 토큰 서명 → 모든 사용자 사칭
```

### 조치 방안

```hcl
# 1. AWS Secrets Manager에 저장
resource "aws_secretsmanager_secret" "db_creds" {
  name = "${var.project_name}/db-credentials"
}

# 2. EC2 IAM 역할에 조회 권한 부여
resource "aws_iam_role_policy" "secrets_policy" {
  role = aws_iam_role.ec2_ssm_role.name
  policy = jsonencode({
    Statement = [{
      Effect   = "Allow"
      Action   = "secretsmanager:GetSecretValue"
      Resource = aws_secretsmanager_secret.db_creds.arn
    }]
  })
}

# 3. user_data에서 런타임에 조회
# user_data.sh 내부:
# DB_PASS=$(aws secretsmanager get-secret-value --secret-id ... | jq -r .SecretString)
```

---

## 3. HIGH — Terraform state 로컬 평문 저장

### 문제점

- `terraform` 블록에 `backend "s3"` 설정 없음 → **로컬 `terraform.tfstate` 파일에 저장**
- state 파일에는 모든 `sensitive = true` 변수 포함 (`db_password`, `jwt_secret`)
- 로컬 파일이 git에 포함되거나 유출되면 전체 자격증명 노출

### 공격 시나리오

```
1. terraform.tfstate 파일 git 커밋 실수
2. GitHub 레포 공개 → 검색엔진에 노출
3. db_password, jwt_secret 평문으로 state에 저장됨
4. 즉시 RDS 접속 + JWT 위조 가능
```

### 조치 방안

```hcl
terraform {
  backend "s3" {
    bucket         = "pposiraegi-tfstate"
    key            = "prod/terraform.tfstate"
    region         = "ap-northeast-2"
    encrypt        = true              # AES-256 암호화
    dynamodb_table = "tf-state-lock"   # 동시 수정 방지
  }
}
```

```bash
# .gitignore 필수 추가
echo "terraform.tfstate" >> .gitignore
echo "terraform.tfstate.backup" >> .gitignore
echo "*.tfvars" >> .gitignore  # db_password 포함 가능
```

---

## 4. MEDIUM — RDS 암호화 미설정

### 취약 코드

```hcl
resource "aws_db_instance" "db" {
  # storage_encrypted = true  ← 없음 (기본값 false)
  # kms_key_id        = ...   ← 없음
}
```

### 문제점

- RDS EBS 볼륨이 평문으로 저장
- 스냅샷도 암호화 안 됨 → 스냅샷 탈취 시 데이터 노출
- AWS 규정 준수(PCI-DSS, HIPAA) 위반 가능

### 조치 방안

```hcl
resource "aws_db_instance" "db" {
  storage_encrypted = true
  # kms_key_id = aws_kms_key.rds.arn  # 커스텀 KMS 키 사용 시
}
```

> [!warning] 주의
> 기존 암호화되지 않은 RDS에 암호화 추가는 직접 불가.
> 스냅샷 → 암호화 복사 → 복원 과정 필요 (다운타임 발생)

---

## 5. MEDIUM — RDS skip_final_snapshot = true

### 취약 코드

```hcl
resource "aws_db_instance" "db" {
  skip_final_snapshot = true  # ← terraform destroy 시 스냅샷 없이 DB 삭제
}
```

### 문제점

- `terraform destroy` 실행 시 **데이터베이스가 스냅샷 없이 즉시 삭제**
- 실수 또는 CI/CD 파이프라인 오류로 프로덕션 데이터 영구 소실 가능
- 복구 방법 없음

### 조치 방안

```hcl
resource "aws_db_instance" "db" {
  skip_final_snapshot       = false
  final_snapshot_identifier = "${var.project_name}-db-final-snapshot"
  deletion_protection       = true  # 추가 보호
}
```

---

## 6. MEDIUM — RDS 자동 백업 비활성화

### 문제점

```hcl
resource "aws_db_instance" "db" {
  # backup_retention_period 없음 → 기본값 0 (비활성화)
  # backup_window 없음
}
```

- `backup_retention_period = 0` (기본값) → **자동 백업 완전 비활성화**
- PITR(Point-in-Time Recovery) 불가
- 장애 발생 시 마지막 수동 스냅샷 이후 데이터 전량 손실

### 조치 방안

```hcl
resource "aws_db_instance" "db" {
  backup_retention_period = 7           # 7일 보관
  backup_window           = "03:00-04:00"  # 새벽 3시 (한국 시간 기준 트래픽 최소)
}
```

---

## 7. MEDIUM — ElastiCache 암호화/인증 없음

### 취약 코드

```hcl
resource "aws_elasticache_cluster" "redis" {
  # at_rest_encryption_enabled  = true  ← 없음
  # transit_encryption_enabled  = true  ← 없음
  # auth_token                          ← 없음
}
```

### 문제점

- Redis 저장 데이터 평문
- Redis 프로토콜 평문 전송 (VPC 내 스니핑 가능)
- 인증 없음 → VPC 내 접근 가능한 모든 서버에서 Redis 명령 실행 가능

### 조치 방안

```hcl
resource "aws_elasticache_replication_group" "redis" {
  # cluster 대신 replication_group 사용 (암호화 지원)
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  auth_token                 = var.redis_auth_token
}
```

---

## 8. MEDIUM — EC2 EBS 볼륨 암호화 없음

### 취약 코드

```hcl
resource "aws_instance" "backend" {
  # root_block_device { encrypted = true } ← 없음
}
```

### 문제점

- OS 디스크에 애플리케이션 로그, 임시 파일, 환경변수 파일 등 저장 가능
- 볼륨 스냅샷 탈취 시 데이터 노출

### 조치 방안

```hcl
resource "aws_instance" "backend" {
  root_block_device {
    encrypted   = true
    volume_size = 20
  }
}
```

---

## 9. LOW — CloudFront → ALB HTTP 평문 통신

### 취약 코드

```hcl
custom_origin_config {
  origin_protocol_policy = "http-only"  # ← HTTP 평문
}
```

### 문제점

- 사용자 → CloudFront: HTTPS (암호화)
- CloudFront → ALB: HTTP (평문) ← 취약 구간
- AWS 내부 네트워크이지만 VPC 내 패킷 스니핑 가능
- API 토큰, 요청 본문이 평문으로 전달됨

### 조치 방안

```hcl
custom_origin_config {
  origin_protocol_policy = "https-only"
  origin_ssl_protocols   = ["TLSv1.2"]
}
# ALB에 ACM 인증서 + HTTPS 리스너 추가 필요
```

---

## 10. LOW — RDS deletion_protection 없음

```hcl
resource "aws_db_instance" "db" {
  deletion_protection = true  # 추가 권장
}
```

- `deletion_protection = true` 없으면 콘솔/CLI에서 RDS 즉시 삭제 가능
- 실수 또는 권한 탈취 시 데이터 손실

---

## 11. LOW — 모니터링/알람 없음

전체 Terraform 코드에 다음 없음:
- CloudWatch 알람 (CPU, 메모리, DB 연결 수)
- SNS 토픽 (알람 수신)
- VPC Flow Logs (비정상 트래픽 감지)
- CloudTrail (API 호출 감사 로그)

---

## 🎯 전체 잘 된 부분 (참고)

| 항목 | 구현 내용 |
|------|----------|
| ALB 직접 접근 차단 | CloudFront Origin-facing prefix list만 허용 |
| Bastion SSH | `var.my_ip` (관리자 IP만 허용) |
| App SG | ALB에서만 앱 포트 접근 |
| RDS SG | App 서버에서만 5432 접근 |
| Redis SG | App 서버에서만 6379 접근 |
| S3 버킷 | 퍼블릭 접근 완전 차단 + OAC |
| HTTPS | CloudFront ACM 인증서 + TLSv1.2_2021 |
| SSM | IAM Role로 콘솔 긴급 접근 지원 |

---

## 🎯 우선 조치 순서

1. Terraform backend S3 설정 (state 파일 암호화 + DynamoDB 잠금)
2. `.gitignore`에 `terraform.tfstate`, `*.tfvars` 추가
3. Secrets Manager로 DB password, JWT secret 이전
4. RDS `skip_final_snapshot = false`, `backup_retention_period = 7`
5. RDS `storage_encrypted = true` (재생성 필요)
6. ElastiCache → replication_group으로 전환 + 암호화 + auth_token
