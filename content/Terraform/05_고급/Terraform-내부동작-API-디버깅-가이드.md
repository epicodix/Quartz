---
title: Terraform 내부동작 - AWS API 디버깅 가이드
tags:
  - terraform
  - aws-api
  - debugging
  - TF_LOG
  - devops
  - infrastructure
aliases:
  - 테라폼-내부동작
  - terraform-debug
  - TF_LOG-TRACE
date: 2026-01-27
category: Terraform/05_고급
status: 완성
priority: 높음
---

# 🎯 Terraform 내부동작 - 블랙박스 열어보기

## 📑 목차
- [[#1. Terraform은 뭘 하고 있는가|내부 구조]]
- [[#2. TF_LOG로 블랙박스 열기|디버깅 방법]]
- [[#3. 실전 분석 - terraform plan의 API 대화|실전 분석]]
- [[#4. terraform apply는 뭐가 다른가|apply 분석]]
- [[#5. 디버깅 실전 활용|실전 활용]]
- [[#🎯 핵심 정리|핵심 정리]]

---

## 1. Terraform은 뭘 하고 있는가

> [!note] 핵심 개념
> `terraform plan`을 실행하면 Terraform은 **AWS API를 직접 호출**해서 현재 인프라 상태를 확인한다. 마법이 아니라 HTTP POST 요청이다.

### 💡 전체 아키텍처

```
┌─────────────────────────────────────────────┐
│  terraform plan / apply                      │
│  (Terraform Core - Go 바이너리)              │
└──────────────┬──────────────────────────────┘
               │ gRPC 통신
               ▼
┌─────────────────────────────────────────────┐
│  terraform-provider-aws (별도 프로세스)       │
│  (hashicorp/aws v5.100.0 - Go 플러그인)      │
└──────────────┬──────────────────────────────┘
               │ HTTPS POST (AWS SDK v2)
               │ SigV4 서명 포함
               ▼
┌─────────────────────────────────────────────┐
│  AWS API Endpoints                           │
│  sts.ap-northeast-2.amazonaws.com  (인증)    │
│  ec2.ap-northeast-2.amazonaws.com  (리소스)  │
└─────────────────────────────────────────────┘
```

**3계층 구조**:
1. **Terraform Core**: HCL 파싱, 의존성 그래프, state 비교
2. **Provider Plugin**: AWS SDK를 감싼 Go 플러그인 (별도 프로세스)
3. **AWS API**: 실제 인프라를 제어하는 REST API

> [!info] Provider는 별도 프로세스
> `terraform init`에서 다운로드한 `terraform-provider-aws` 바이너리가 **별도 프로세스로 실행**되고, Terraform Core와 **gRPC**로 통신한다. 로그에서 `pid=60044` 같은 게 보이는 이유다.

---

## 2. TF_LOG로 블랙박스 열기

### 📋 로그 레벨

```bash
# 레벨: TRACE > DEBUG > INFO > WARN > ERROR
TF_LOG=TRACE terraform plan    # 모든 것 (AWS API 요청/응답 포함)
TF_LOG=DEBUG terraform plan    # API 호출 + 내부 로직
TF_LOG=INFO  terraform plan    # 주요 이벤트만
TF_LOG=WARN  terraform plan    # 경고 + 에러만
TF_LOG=ERROR terraform plan    # 에러만
```

### 💡 파일로 저장하기

```bash
# 터미널 출력 + 파일 저장
TF_LOG=TRACE TF_LOG_PATH=./debug.log terraform plan

# provider만 디버깅 (Core 로그 제외)
TF_LOG_PROVIDER=TRACE terraform plan

# Core만 디버깅 (Provider 로그 제외)
TF_LOG_CORE=TRACE terraform plan
```

### 📊 로그 레벨별 용도

| 레벨 | 용도 | 로그 양 |
|------|------|---------|
| `TRACE` | AWS API 요청/응답 본문까지 전부 | 매우 많음 |
| `DEBUG` | API 호출 + 내부 의사결정 과정 | 많음 |
| `INFO` | 버전 정보, 주요 이벤트 | 적음 |
| `WARN` | Deprecation 경고 등 | 매우 적음 |
| `ERROR` | 에러만 | 거의 없음 |

> [!tip] 실무 추천
> 평소에는 `TF_LOG=DEBUG`, API 레벨 문제 추적 시 `TF_LOG=TRACE`

---

## 3. 실전 분석 - terraform plan의 API 대화

> [!example] 실제 실습 환경 (2026-01-27)
> - 리소스: VPC + Subnet + SG + EC2 + EIP = 20개
> - Provider: hashicorp/aws v5.100.0
> - Region: ap-northeast-2

### 📋 Phase 1: 인증 (STS)

```
[15:31:49] HTTP Request  → POST https://sts.ap-northeast-2.amazonaws.com/
                           Action=GetCallerIdentity
                           Authorization: AWS4-HMAC-SHA256
                             Credential=AKIA****DVOE/20260127/ap-northeast-2/sts/aws4_request

[15:31:49] HTTP Response ← 200 OK (118ms)
                           Account: 317250221510
                           User: arn:aws:iam::317250221510:user/aws1
```

**설명**: Terraform이 가장 먼저 하는 일은 **"내가 누구인지" 확인**하는 것.
- `~/.aws/credentials`에서 Access Key를 읽음
- **STS (Security Token Service)** API로 `GetCallerIdentity` 호출
- AWS가 "너는 계정 317250221510의 aws1 유저야" 라고 응답
- **SigV4 서명**: 모든 요청에 HMAC-SHA256으로 서명 → 키가 유효한지 AWS가 검증

### 📋 Phase 2: State Refresh (EC2 API)

`terraform plan`의 **"Refreshing state..."** 가 바로 이 단계다.

```
[15:31:50] ── VPC 확인 ──────────────────────────────────
           → POST ec2.ap-northeast-2.amazonaws.com
             Action=DescribeVpcs&VpcId.1=vpc-0478120058493042f
           ← 200 OK (192ms) - XML 응답 (1437 bytes)

           → Action=DescribeVpcAttribute&Attribute=enableDnsHostnames&VpcId=vpc-047...
           ← 200 OK (87ms)

           → Action=DescribeVpcAttribute&Attribute=enableDnsSupport&VpcId=vpc-047...
           ← 200 OK (78ms)

[15:31:50] ── Key Pair 확인 ──────────────────────────────
           → Action=DescribeKeyPairs&KeyName.1=my-infra-key
           ← 200 OK (160ms)

[15:31:50] ── EIP 확인 ──────────────────────────────────
           → Action=DescribeAddresses&AllocationId.1=eipalloc-003f9a916d3a860a0
           ← 200 OK (232ms)

           → Action=DescribeAddressesAttribute&Attribute=domain-name&AllocationId.1=eipalloc-003...
           ← 200 OK (98ms)

[15:31:50] ── AMI 조회 (data source) ────────────────────
           → Action=DescribeImages
             &Filter.1.Name=name
             &Filter.1.Value.1=al2023-ami-2023*-kernel-*-arm64
             &Filter.2.Name=state
             &Filter.2.Value.1=available
             &Owner.1=amazon
           ← 200 OK - 최신 AMI ID 반환

[15:31:50] ── Subnet, Route Table, SG 확인 ──────────────
           → Action=DescribeSubnets (x4)
           → Action=DescribeRouteTables (x7)
           → Action=DescribeSecurityGroups (x5)
           → Action=DescribeInternetGateways (x1)
           ← 200 OK 연속

[15:31:50] ── EC2 Instance 확인 ──────────────────────────
           → Action=DescribeInstances
           ← Instance ID, 상태, 타입 등 반환

           → Action=DescribeInstanceAttribute (x4)
             - disableApiTermination
             - userData
             - disableApiStop
             - instanceInitiatedShutdownBehavior
           ← 200 OK 연속

           → Action=DescribeInstanceTypes
           ← t4g.micro 스펙 반환

           → Action=DescribeInstanceCreditSpecifications
           ← 크레딧 모드 (standard/unlimited) 반환

           → Action=DescribeVolumes
           ← EBS 볼륨 정보 반환
```

### 📊 API 호출 통계 (terraform plan 1회)

```
총 API 호출: 39회
엔드포인트:
  - ec2.ap-northeast-2.amazonaws.com: 38회
  - sts.ap-northeast-2.amazonaws.com: 1회

호출 빈도 TOP:
  DescribeRouteTables ........... 7회 (RT 2개 x 연관 정보)
  DescribeSecurityGroups ........ 5회 (SG 4개 + 참조 확인)
  DescribeSubnets ............... 4회 (Public 2 + Private 2)
  DescribeInstanceAttribute ..... 4회 (EC2 속성 4개 각각)
  DescribeVpcAttribute .......... 3회 (DNS Hostnames/Support/NACL)
  DescribeAddresses ............. 2회 (EIP + EIP Association)
  DescribeVpcs .................. 2회 (VPC + VPC CIDR)
  기타 .......................... 12회
```

> [!warning] 중요한 발견
> **plan만 해도 API 39회가 호출된다.** 리소스가 100개면 200회 이상. 이것이:
> - `plan`이 오래 걸리는 이유
> - AWS API Rate Limit에 걸릴 수 있는 이유
> - Provider가 별도 프로세스인 이유 (병렬 처리)

### 💡 Terraform이 하는 비교 과정

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│  .tf 파일     │     │  tfstate     │     │  AWS 실제     │
│  (원하는 상태) │     │  (기록된 상태)│     │  (현재 상태)  │
└──────┬───────┘     └──────┬───────┘     └──────┬───────┘
       │                    │                     │
       │         terraform plan                   │
       │         ┌──────────┘                     │
       │         │  1) state에서 리소스 ID 읽기    │
       │         │     (vpc-047...)               │
       │         │                                │
       │         │  2) AWS API로 현재 상태 조회 ──►│
       │         │     DescribeVpcs               │
       │         │                                │
       │         │  3) 응답 받기 ◄────────────────│
       │         │     cidr=10.0.0.0/16          │
       │         │     dns_hostnames=true         │
       ▼         ▼                                │
    ┌──────────────────┐                          │
    │ 3-way 비교        │                          │
    │                  │                          │
    │ .tf: cidr=10.0.0.0/16  ✅ 일치             │
    │ state: cidr=10.0.0.0/16                     │
    │ AWS: cidr=10.0.0.0/16                       │
    │                  │                          │
    │ → "No changes"   │                          │
    └──────────────────┘
```

---

## 4. terraform apply는 뭐가 다른가

### 📋 plan vs apply API 차이

| 단계 | plan | apply |
|------|------|-------|
| Phase 1: 인증 | `GetCallerIdentity` | `GetCallerIdentity` |
| Phase 2: Refresh | `Describe*` (읽기) | `Describe*` (읽기) |
| Phase 3: Diff | 로컬 비교 (API 없음) | 로컬 비교 (API 없음) |
| Phase 4: 실행 | **없음** | `Create*/Modify*/Delete*` |
| Phase 5: 확인 | **없음** | `Describe*` (재확인) |

### 💡 apply 시 추가되는 API 호출 예시

```bash
# 예: EC2 instance_type 변경 시
terraform apply

# Phase 4에서 추가되는 API:
→ Action=StopInstances&InstanceId.1=i-05da54eaec43bb6a8
← 200 OK (인스턴스 정지)

→ Action=ModifyInstanceAttribute&InstanceId=i-05da...&InstanceType.Value=t4g.small
← 200 OK (타입 변경)

→ Action=StartInstances&InstanceId.1=i-05da54eaec43bb6a8
← 200 OK (인스턴스 시작)

# Phase 5: 변경 확인
→ Action=DescribeInstances&InstanceId.1=i-05da...
← 200 OK (t4g.small 확인)
```

### 📊 리소스별 API 매핑

| Terraform 리소스 | 생성 API | 조회 API | 삭제 API |
|-----------------|----------|----------|----------|
| `aws_vpc` | `CreateVpc` | `DescribeVpcs` | `DeleteVpc` |
| `aws_subnet` | `CreateSubnet` | `DescribeSubnets` | `DeleteSubnet` |
| `aws_security_group` | `CreateSecurityGroup` | `DescribeSecurityGroups` | `DeleteSecurityGroup` |
| `aws_instance` | `RunInstances` | `DescribeInstances` | `TerminateInstances` |
| `aws_eip` | `AllocateAddress` | `DescribeAddresses` | `ReleaseAddress` |
| `aws_key_pair` | `ImportKeyPair` | `DescribeKeyPairs` | `DeleteKeyPair` |
| `aws_internet_gateway` | `CreateInternetGateway` | `DescribeInternetGateways` | `DeleteInternetGateway` |
| `aws_route_table` | `CreateRouteTable` | `DescribeRouteTables` | `DeleteRouteTable` |

> [!tip] AWS Console에서도 동일한 API를 호출한다
> AWS Console에서 "VPC 생성" 버튼을 클릭하면 내부적으로 `CreateVpc` API가 호출된다. Terraform이나 Console이나 결국 같은 API를 쓴다. 차이는 **누가 호출하느냐**뿐.

---

## 5. 디버깅 실전 활용

### 🚨 Case 1: "왜 plan이 느린가?"

```bash
# API 호출 횟수 세기
TF_LOG=TRACE terraform plan 2>&1 | grep "Action=" | wc -l

# 어떤 API가 가장 많이 호출되는지
TF_LOG=TRACE terraform plan 2>&1 | grep -o "Action=[^&]*" | sort | uniq -c | sort -rn
```

리소스가 많을수록 `Describe*` 호출이 급증한다. 해결:
- **모듈 분리**: `-target=module.vpc`로 특정 모듈만 plan
- **Remote State**: 다른 모듈의 output만 `terraform_remote_state`로 참조

### 🚨 Case 2: "API Rate Limit 에러"

```
Error: Throttling: Rate exceeded
```

```bash
# 어떤 API가 폭주하는지 확인
TF_LOG=TRACE terraform plan 2>&1 | grep "Action=" | sed 's/.*Action=\([^&]*\).*/\1/' | sort | uniq -c | sort -rn | head -5
```

해결:
```bash
# 병렬 실행 수 제한
terraform plan -parallelism=5    # 기본값 10 → 5로 줄이기
```

### 🚨 Case 3: "apply 후 실제 반영이 안 됐다"

```bash
# apply 후 AWS가 뭘 응답했는지 확인
TF_LOG=TRACE terraform apply 2>&1 | grep "HTTP Response" | grep "status_code=4"
```

4xx 응답이 있으면 IAM 권한 문제일 가능성이 높다.

### 🚨 Case 4: "어떤 리소스가 문제인지 모르겠다"

```bash
# 특정 리소스만 디버깅
TF_LOG=TRACE terraform plan -target=module.ec2.aws_instance.bastion 2>&1 | grep "Action="
```

### 📋 유용한 디버깅 원라이너 모음

```bash
# 1) API 호출 순서 보기
TF_LOG=TRACE terraform plan 2>&1 | grep "Action=" | sed 's/.*Action=\([^&]*\).*/\1/' | cat -n

# 2) API 호출 빈도 보기
TF_LOG=TRACE terraform plan 2>&1 | grep -o "Action=[^&]*" | sort | uniq -c | sort -rn

# 3) 실패한 API만 보기 (4xx, 5xx)
TF_LOG=TRACE terraform plan 2>&1 | grep "status_code=[45]"

# 4) 특정 리소스의 API만 보기
TF_LOG=TRACE terraform plan 2>&1 | grep "aws_instance" | grep "Action="

# 5) API 응답 시간 보기 (느린 API 찾기)
TF_LOG=TRACE terraform plan 2>&1 | grep "http.duration=" | sed 's/.*http.duration=\([0-9]*\).*/\1/' | sort -rn | head -5

# 6) 엔드포인트별 호출 수
TF_LOG=TRACE terraform plan 2>&1 | grep "http.url=" | grep -o "https://[^/]*" | sort | uniq -c | sort -rn

# 7) 파일로 저장 후 분석
TF_LOG=TRACE TF_LOG_PATH=./tf-debug.log terraform plan
grep "Action=" ./tf-debug.log | sed 's/.*Action=\([^&]*\).*/\1/' | sort | uniq -c | sort -rn
```

---

## 🎯 핵심 정리

> [!note] Terraform = AWS API 자동화 도구
> 1. **terraform init**: Provider 바이너리 다운로드 (API 호출 없음)
> 2. **terraform plan**: `GetCallerIdentity` → `Describe*` x N → 3-way 비교
> 3. **terraform apply**: plan + `Create*/Modify*/Delete*` → `Describe*` 재확인
> 4. **terraform destroy**: `Describe*` → `Delete*/Terminate*/Release*`

### 📊 실측 데이터 (20개 리소스 기준)

| 명령어 | API 호출 수 | 주요 엔드포인트 | 소요 시간 |
|--------|------------|----------------|-----------|
| `plan` | 39회 | EC2 38 + STS 1 | ~3초 |
| `apply` (변경 없음) | 39회 | EC2 38 + STS 1 | ~3초 |
| `apply` (변경 있음) | 39 + a회 | EC2 + 변경 API | ~10초+ |

### 🔧 SigV4 서명 구조

```
Authorization: AWS4-HMAC-SHA256
  Credential=AKIA****DVOE/20260127/ap-northeast-2/ec2/aws4_request
  ├── Access Key ID
  ├── 날짜 (20260127)
  ├── 리전 (ap-northeast-2)
  ├── 서비스 (ec2)
  └── aws4_request (고정값)

  SignedHeaders=content-type;host;x-amz-date
  Signature=***** (HMAC-SHA256 해시)
```

모든 API 요청은 이 서명으로 **"이 요청은 aws1 유저가 보낸 게 맞다"**를 증명한다. Secret Key가 유출되면 다른 사람이 이 서명을 만들 수 있으므로 **절대 노출 금지**.

> [!danger] 기억할 것
> `terraform plan`은 **"읽기 전용"이 아니다**. AWS API를 39회 호출하며, IAM 권한 확인과 리소스 전수 조사를 수행한다. plan이 느리거나 실패하면 `TF_LOG=TRACE`로 **어떤 API가 문제인지** 바로 확인할 수 있다.
