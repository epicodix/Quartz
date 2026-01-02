---
title: Terraform 설치 및 환경 구축 가이드
tags:
  - terraform
  - installation
  - setup
  - macos
  - aws
aliases:
  - 테라폼설치
  - Terraform Setup
date: 2025-12-31
category: 1_가이드/환경구축
status: 완성
priority: 높음
---

# 🚀 Terraform 설치 및 환경 구축

## 📑 목차
- [[#1. Terraform 설치|Terraform 설치]]
- [[#2. AWS 자격증명 설정|AWS 설정]]
- [[#3. 첫 번째 프로젝트|첫 프로젝트]]
- [[#4. 트러블슈팅|트러블슈팅]]

---

## 1. Terraform 설치

### 🍎 macOS 설치 (Homebrew)

> [!tip] 가장 쉬운 방법
> macOS에서는 Homebrew를 사용한 설치가 가장 간편합니다.

#### 📋 설치 단계

```bash
# 1. Homebrew가 설치되어 있는지 확인
brew --version

# Homebrew가 없다면 설치
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 2. Terraform 설치
brew tap hashicorp/tap
brew install hashicorp/tap/terraform

# 3. 설치 확인
terraform version
```

**예상 출력:**
```
Terraform v1.7.0
on darwin_arm64  # M1/M2/M3 Mac
# 또는
on darwin_amd64  # Intel Mac
```

#### 🔄 업데이트

```bash
# Terraform 업데이트
brew upgrade hashicorp/tap/terraform

# 특정 버전 설치
brew install hashicorp/tap/terraform@1.6
```

### 🐧 Linux 설치 (Ubuntu/Debian)

```bash
# 1. HashiCorp GPG 키 추가
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

# 2. 저장소 추가
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list

# 3. 패키지 업데이트 및 설치
sudo apt update
sudo apt install terraform

# 4. 설치 확인
terraform version
```

### 🪟 Windows 설치

#### Chocolatey 사용

```powershell
# PowerShell (관리자 권한)
choco install terraform

# 설치 확인
terraform version
```

#### 수동 설치

1. [Terraform 다운로드 페이지](https://www.terraform.io/downloads) 방문
2. Windows 버전 다운로드
3. ZIP 파일 압축 해제
4. `terraform.exe`를 `C:\Windows\System32`에 복사
5. 또는 별도 폴더에 저장 후 PATH 환경변수 추가

### ✅ 설치 검증

```bash
# 버전 확인
terraform version

# 도움말 확인
terraform -help

# 특정 명령어 도움말
terraform init -help
```

---

## 2. AWS 자격증명 설정

### 🔐 AWS CLI 설치 및 설정

> [!warning] 필수 사전 준비
> Terraform으로 AWS 리소스를 관리하려면 AWS 자격증명이 필요합니다.

#### 📋 AWS CLI 설치 (macOS)

```bash
# Homebrew로 설치
brew install awscli

# 설치 확인
aws --version
```

#### 🔑 AWS 자격증명 설정

```bash
# AWS 자격증명 설정
aws configure
```

**입력 내용:**
```
AWS Access Key ID [None]: AKIAIOSFODNN7EXAMPLE
AWS Secret Access Key [None]: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
Default region name [None]: ap-northeast-2
Default output format [None]: json
```

> [!info] 자격증명 위치
> 설정된 자격증명은 `~/.aws/credentials` 파일에 저장됩니다.

#### 📄 자격증명 파일 직접 편집

```bash
# credentials 파일 편집
nano ~/.aws/credentials
```

**파일 내용:**
```ini
[default]
aws_access_key_id = AKIAIOSFODNN7EXAMPLE
aws_secret_access_key = wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY

[dev]
aws_access_key_id = ANOTHER_ACCESS_KEY
aws_secret_access_key = ANOTHER_SECRET_KEY
```

#### 🏷️ 프로필 사용

```bash
# 특정 프로필로 AWS CLI 사용
aws s3 ls --profile dev

# Terraform에서 프로필 사용
export AWS_PROFILE=dev
terraform plan
```

**또는 Terraform 코드에서 직접 지정:**

```hcl
provider "aws" {
  region  = "ap-northeast-2"
  profile = "dev"  # 프로필 지정
}
```

### 🔒 보안 베스트 프랙티스

> [!danger] 절대 금지
> - ❌ 루트 계정 자격증명 사용하지 않기
> - ❌ 자격증명을 코드에 하드코딩하지 않기
> - ❌ 자격증명 파일을 Git에 커밋하지 않기

> [!tip] 권장 사항
> - ✅ IAM 사용자 생성 및 최소 권한 부여
> - ✅ MFA (Multi-Factor Authentication) 활성화
> - ✅ 액세스 키 정기적으로 교체
> - ✅ 환경 변수 사용 고려

#### 환경 변수로 자격증명 설정

```bash
# 환경 변수 설정
export AWS_ACCESS_KEY_ID="AKIAIOSFODNN7EXAMPLE"
export AWS_SECRET_ACCESS_KEY="wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
export AWS_DEFAULT_REGION="ap-northeast-2"

# Terraform 실행
terraform plan
```

**영구 설정 (bashrc/zshrc):**
```bash
# ~/.zshrc 또는 ~/.bashrc에 추가
echo 'export AWS_DEFAULT_REGION="ap-northeast-2"' >> ~/.zshrc
source ~/.zshrc
```

### 🧪 자격증명 테스트

```bash
# AWS 계정 정보 확인
aws sts get-caller-identity

# 예상 출력:
{
    "UserId": "AIDACKCEVSQ6C2EXAMPLE",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/terraform-user"
}
```

---

## 3. 첫 번째 프로젝트

### 🎯 Hello Terraform 프로젝트

> [!example] 실습 목표
> 간단한 S3 버킷을 생성하여 Terraform 워크플로우를 경험합니다.

#### 📁 프로젝트 구조

```bash
# 프로젝트 디렉토리 생성
mkdir ~/terraform-hello
cd ~/terraform-hello
```

#### 📄 main.tf 작성

```hcl
# Terraform 버전 및 Provider 설정
terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# AWS Provider 설정
provider "aws" {
  region = "ap-northeast-2"  # 서울 리전
}

# S3 버킷 생성
resource "aws_s3_bucket" "my_first_bucket" {
  bucket = "my-terraform-bucket-${formatdate("YYYYMMDDhhmmss", timestamp())}"

  tags = {
    Name        = "My First Terraform Bucket"
    Environment = "Learning"
    ManagedBy   = "Terraform"
  }
}

# S3 버킷 버저닝 활성화
resource "aws_s3_bucket_versioning" "my_first_bucket_versioning" {
  bucket = aws_s3_bucket.my_first_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

# 출력
output "bucket_name" {
  description = "생성된 S3 버킷 이름"
  value       = aws_s3_bucket.my_first_bucket.id
}

output "bucket_arn" {
  description = "S3 버킷 ARN"
  value       = aws_s3_bucket.my_first_bucket.arn
}
```

#### 🚀 실행하기

```bash
# 1. 초기화
terraform init
```

**출력:**
```
Initializing the backend...

Initializing provider plugins...
- Finding hashicorp/aws versions matching "~> 5.0"...
- Installing hashicorp/aws v5.31.0...
- Installed hashicorp/aws v5.31.0

Terraform has been successfully initialized!
```

```bash
# 2. 포맷팅 (선택사항)
terraform fmt

# 3. 검증
terraform validate
```

**출력:**
```
Success! The configuration is valid.
```

```bash
# 4. 실행 계획
terraform plan
```

**출력:**
```
Terraform will perform the following actions:

  # aws_s3_bucket.my_first_bucket will be created
  + resource "aws_s3_bucket" "my_first_bucket" {
      + bucket                      = "my-terraform-bucket-20251231143022"
      + id                          = (known after apply)
      + arn                         = (known after apply)
      ...
    }

  # aws_s3_bucket_versioning.my_first_bucket_versioning will be created
  + resource "aws_s3_bucket_versioning" "my_first_bucket_versioning" {
      ...
    }

Plan: 2 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + bucket_arn  = (known after apply)
  + bucket_name = "my-terraform-bucket-20251231143022"
```

```bash
# 5. 적용
terraform apply
```

**입력:**
```
Do you want to perform these actions?
  Enter a value: yes
```

**출력:**
```
aws_s3_bucket.my_first_bucket: Creating...
aws_s3_bucket.my_first_bucket: Creation complete after 2s [id=my-terraform-bucket-20251231143022]
aws_s3_bucket_versioning.my_first_bucket_versioning: Creating...
aws_s3_bucket_versioning.my_first_bucket_versioning: Creation complete after 1s

Apply complete! Resources: 2 added, 0 changed, 0 destroyed.

Outputs:

bucket_arn = "arn:aws:s3:::my-terraform-bucket-20251231143022"
bucket_name = "my-terraform-bucket-20251231143022"
```

```bash
# 6. 상태 확인
terraform show

# 7. 출력 값만 확인
terraform output

# 8. AWS CLI로 버킷 확인
aws s3 ls | grep terraform
```

#### 🗑️ 리소스 삭제

```bash
# 생성한 리소스 삭제
terraform destroy
```

**입력:**
```
Do you really want to destroy all resources?
  Enter a value: yes
```

**출력:**
```
aws_s3_bucket_versioning.my_first_bucket_versioning: Destroying...
aws_s3_bucket_versioning.my_first_bucket_versioning: Destruction complete after 1s
aws_s3_bucket.my_first_bucket: Destroying...
aws_s3_bucket.my_first_bucket: Destruction complete after 2s

Destroy complete! Resources: 2 destroyed.
```

---

## 4. 트러블슈팅

### 🚨 자주 발생하는 오류

#### 1. Provider 다운로드 실패

**오류 메시지:**
```
Error: Failed to install provider
```

**해결 방법:**
```bash
# 프록시 설정 확인
env | grep -i proxy

# 캐시 삭제 후 재시도
rm -rf .terraform
terraform init
```

#### 2. 자격증명 오류

**오류 메시지:**
```
Error: No valid credential sources found
```

**해결 방법:**
```bash
# 자격증명 확인
aws configure list

# 환경 변수 확인
env | grep AWS

# 자격증명 재설정
aws configure
```

#### 3. 리전 오류

**오류 메시지:**
```
Error: error validating provider credentials: retrieving caller identity from STS
```

**해결 방법:**
```hcl
# main.tf에 리전 명시
provider "aws" {
  region = "ap-northeast-2"
}
```

#### 4. 버킷 이름 중복

**오류 메시지:**
```
Error: error creating S3 bucket: BucketAlreadyExists
```

**해결 방법:**
```hcl
# 고유한 이름 생성
resource "aws_s3_bucket" "example" {
  bucket = "my-unique-bucket-${formatdate("YYYYMMDDhhmmss", timestamp())}"
}

# 또는 bucket_prefix 사용
resource "aws_s3_bucket" "example" {
  bucket_prefix = "my-bucket-"
}
```

#### 5. State Lock 오류

**오류 메시지:**
```
Error: Error acquiring the state lock
```

**해결 방법:**
```bash
# Lock 강제 해제 (주의!)
terraform force-unlock LOCK_ID

# 또는 다른 사용자의 작업이 끝날 때까지 대기
```

### 🔧 유용한 명령어

```bash
# 디버그 로그 활성화
export TF_LOG=DEBUG
terraform plan

# 특정 로그 레벨 (TRACE, DEBUG, INFO, WARN, ERROR)
export TF_LOG=TRACE

# 로그를 파일로 저장
export TF_LOG_PATH=./terraform.log
terraform apply

# 로그 비활성화
unset TF_LOG
unset TF_LOG_PATH

# State 파일 백업
cp terraform.tfstate terraform.tfstate.backup

# 특정 리소스만 적용
terraform apply -target=aws_s3_bucket.my_first_bucket

# 특정 리소스만 삭제
terraform destroy -target=aws_s3_bucket.my_first_bucket
```

---

## 📚 다음 단계

### ✅ 완료한 내용
- ✅ Terraform 설치
- ✅ AWS 자격증명 설정
- ✅ 첫 번째 프로젝트 완성

### 🎯 다음 학습 목표

1. **[[Terraform-기초-가이드|Terraform 기초 개념]]** 학습
2. **변수와 출력** 활용
3. **모듈** 사용법
4. **원격 백엔드** 설정 (S3 + DynamoDB)
5. **워크스페이스**로 환경 관리

---

## 💡 팁

> [!tip] 개발 환경 설정
>
> **VS Code 확장 프로그램:**
> - HashiCorp Terraform - 문법 하이라이팅, 자동완성
> - Terraform Autocomplete
>
> **설정 파일 (settings.json):**
> ```json
> {
>   "terraform.languageServer": {
>     "enabled": true,
>     "args": []
>   },
>   "[terraform]": {
>     "editor.formatOnSave": true
>   }
> }
> ```

> [!tip] Terraform 명령어 자동완성
> ```bash
> # Bash
> terraform -install-autocomplete
>
> # Zsh
> echo 'autoload -U +X bashcompinit && bashcompinit' >> ~/.zshrc
> echo 'complete -o nospace -C /opt/homebrew/bin/terraform terraform' >> ~/.zshrc
> source ~/.zshrc
> ```

---

## 🔗 참고 자료

- [Terraform 공식 문서](https://www.terraform.io/docs)
- [AWS Provider 문서](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Terraform 튜토리얼](https://learn.hashicorp.com/terraform)

---

> Created: 2025-12-31
> Tags: #terraform #installation #setup #macos #aws
> Category: 가이드
