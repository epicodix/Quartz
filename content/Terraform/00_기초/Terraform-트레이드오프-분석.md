---
title: Terraform 트레이드오프 분석 - 언제 써야 하고 언제 안 써야 하나
tags:
  - terraform
  - iac
  - 의사결정
  - 트레이드오프
  - 실무
aliases:
  - 테라폼선택기준
  - IaC의사결정
date: 2025-12-31
category: 2_기술_분석/인프라
status: 완성
priority: 높음
---

# ⚖️ Terraform 트레이드오프 분석

> [!quote] 핵심 질문
> "모든 인프라를 Terraform으로 관리해야 할까?"
> **정답: 아니다. 상황에 따라 ClickOps가 더 나을 수 있다.**

## 📑 목차
- [[#1. 핵심 개념|핵심 개념]]
- [[#2. 안 써도 되는 경우|ClickOps가 나은 경우]]
- [[#3. 반드시 써야 하는 경우|Terraform이 필수인 경우]]
- [[#4. 의사결정 프레임워크|의사결정 기준]]
- [[#5. 실무 사례|실무 사례]]

---

## 1. 핵심 개념: Terraform의 본질

> [!note] Terraform = 자동화 도구
> "라면 하나 끓이는데 요리 로봇을 프로그래밍할 필요는 없다."
> 하지만 "매일 100인분 단체 급식을 만든다면 자동화 시스템이 필수다."

### 💡 마케터 관점의 비유

| 업무 | 수동 방식 | 자동화 방식 | 선택 기준 |
|------|-----------|-------------|-----------|
| **일회성 광고 리포트** | 엑셀 수작업 | Python + SQL 자동화 | 횟수 1회 → 수작업 |
| **월간 정기 리포트** | 매달 수작업 반복 | 매크로/스크립트 | 월 1회 이상 → 자동화 |
| **실시간 대시보드** | 불가능 | BI 도구 필수 | 실시간 → 자동화 필수 |

**인프라도 똑같습니다:**
- **1회성 테스트 서버** → 콘솔 클릭 (ClickOps)
- **주기적으로 생성/삭제하는 환경** → Terraform
- **운영 환경 (Production)** → Terraform 필수

---

## 2. 안 써도 되는 경우 (Manual/ClickOps 승리)

> [!tip] ClickOps가 나은 상황
> Terraform의 **학습 비용**과 **관리 오버헤드**가 효과보다 클 때

### 🚫 Case 1. 빠른 프로토타이핑 & 학습

#### 📋 상황
```
개발자: "그냥 EC2 하나 띄워서 파이썬 코드 돌려보고 싶어요."
예상 생명주기: 1-2시간
```

#### 🔍 분석

**ClickOps (콘솔):**
- 시간: 5분 (클릭 몇 번)
- 코드: 0줄
- 삭제: 인스턴스 Terminate 버튼 클릭

**Terraform:**
- 시간: 20분 (main.tf 작성 + init + plan + apply)
- 코드: 30-50줄
- 관리: terraform.tfstate 파일 관리
- 삭제: terraform destroy

**결론:** 🏆 **ClickOps 승리** (4배 빠름)

#### ⚠️ 주의사항

> [!warning] 함정
> "빠른 테스트"가 계속 반복되면 ClickOps는 손해입니다!
> - 3번 이상 반복 → Terraform 고려
> - 팀원이 똑같은 환경 필요 → Terraform 필수

### 🚫 Case 2. 변동이 거의 없는 초소규모 프로젝트

#### 📋 상황
```
프로젝트: 정적 웹사이트 호스팅
리소스: S3 버킷 1개
변경 주기: 1년에 0-1회
팀 규모: 1명
```

#### 🔍 분석

| 항목 | ClickOps | Terraform |
|------|----------|-----------|
| **초기 구축 시간** | 5분 | 15분 |
| **유지보수** | 없음 | State 파일 관리 |
| **변경 빈도** | 거의 없음 | 거의 없음 |
| **복잡도** | 매우 낮음 | 불필요하게 높음 |

**결론:** 🏆 **ClickOps 승리** (과도한 엔지니어링 방지)

> [!example] 실제 사례
> 회사 소개 페이지를 S3에 올리는 경우, Terraform으로 관리하는 건 "닭 잡는데 소 잡는 칼 쓰는 격"입니다.

### 🚫 Case 3. 복잡한 1회성 마이그레이션

#### 📋 상황
```
작업: 레거시 온프레미스 → AWS 마이그레이션
특수성: DB 스키마 수동 조정, 애플리케이션별 세밀한 설정 필요
반복 가능성: 0% (한 번 옮기면 끝)
```

#### 🔍 분석

**Terraform으로 자동화하려면:**
1. 현재 인프라 분석 (1일)
2. Terraform 코드 작성 (2-3일)
3. 테스트 및 디버깅 (1-2일)
4. 실제 마이그레이션 (1일)

**수동으로 마이그레이션:**
1. AWS Migration Hub 사용
2. 수동 설정 및 테스트 (2-3일)
3. 완료

**결론:** 🏆 **수동 마이그레이션 승리** (1회성 작업에는 자동화 오버헤드)

---

## 3. 반드시 써야 하는 경우 (Terraform Essential)

> [!danger] 안 쓰면 재앙
> 이런 상황에서 ClickOps를 고집하면 **팀 전체가 고통**받습니다.

### ✅ Case 1. 환경의 일치 (Dev / Staging / Prod)

#### 📋 상황
```
환경: 개발(Dev), 스테이징(Staging), 운영(Prod) 3개
요구사항: "세 환경이 완전히 동일해야 함"
```

#### 🚨 ClickOps의 재앙

**시나리오:**
```
개발자 A: Dev 서버를 수동으로 세팅 (보안 그룹 포트 8080 오픈)
개발자 B: Staging 서버를 수동으로 세팅 (실수로 포트 8081 오픈)
운영팀: Prod 서버를 수동으로 세팅 (포트 80 오픈)

결과:
✅ Dev에서 테스트 성공
✅ Staging에서 테스트... 포트 에러!
❌ Prod 배포... 장애 발생!
🔥 새벽 3시 긴급 전화
```

#### 🏆 Terraform의 승리

```hcl
# variables.tf
variable "environment" {
  type = string
}

variable "app_port" {
  type = number
  default = 8080
}

# main.tf
resource "aws_security_group" "app" {
  name = "${var.environment}-app-sg"

  ingress {
    from_port   = var.app_port
    to_port     = var.app_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
```

**실행:**
```bash
# Dev 환경
terraform apply -var="environment=dev"

# Staging 환경
terraform apply -var="environment=staging"

# Prod 환경
terraform apply -var="environment=prod"
```

**결과:**
- ✅ 모든 환경이 **100% 동일**
- ✅ 인간의 실수(Human Error) **0%**
- ✅ 코드 리뷰로 사전 검증

> [!success] ROI 계산
> **투자:** Terraform 학습 1주 + 코드 작성 1일
> **수익:** 환경 불일치 장애 0건, 디버깅 시간 월 10시간 절약
> **회수 기간:** 1개월

### ✅ Case 2. 재해 복구 (Disaster Recovery)

#### 📋 상황
```
사고: AWS 리전 장애 / 해킹 / 실수로 리소스 삭제
복구 목표: 1시간 이내
```

#### 🚨 ClickOps의 재앙

**시나리오:**
```
새벽 2시: "서울 리전이 다운됐습니다!"
인프라팀: "도쿄 리전으로 긴급 이전!"

수동 작업:
1. VPC 생성 (클릭 20번)
2. 서브넷 4개 생성 (클릭 80번)
3. 보안 그룹 5개 생성 (클릭 100번)
4. EC2 인스턴스 10대 생성 (클릭 200번)
5. 로드밸런서 설정 (클릭 50번)
...

예상 시간: 4-6시간
문제: "예전 설정이 어땠더라...?"
결과: 불완전한 복구, 숨은 버그 발생
```

#### 🏆 Terraform의 승리

```bash
# 1. 리전 변경
# terraform.tfvars
aws_region = "ap-northeast-1"  # 서울 → 도쿄

# 2. 복구 실행
terraform apply -auto-approve

# 소요 시간: 10-15분
# 정확도: 100% (기존과 동일)
```

**추가 효과:**
- 📋 **인프라 문서화 자동 완성** (코드 = 문서)
- 🔍 **변경 이력 추적** (Git History)
- ✅ **감사 대응** (Compliance Audit)

> [!example] 실제 사례
> 2021년 AWS 서울 리전 장애 시, Terraform으로 관리하던 회사들은 1시간 내에 도쿄 리전으로 이전 완료. 수동 관리 회사들은 복구에 하루 이상 소요.

### ✅ Case 3. 팀 협업 및 변경 이력 추적

#### 📋 상황
```
팀 규모: 5명 이상
변경 빈도: 주 1회 이상
보안 요구: 누가, 언제, 왜 바꿨는지 추적 필요
```

#### 🚨 ClickOps의 재앙

**시나리오:**
```
월요일 아침:
보안팀: "보안 그룹이 0.0.0.0/0으로 열려있습니다!"
CTO: "누가 했어?!"

AWS CloudTrail 확인:
- 변경자: admin 계정 (5명이 공유)
- 이유: 기록 없음
- 승인: 없음

결과:
😡 범인 찾기 미팅 1시간
😡 재발 방지 대책 회의 2시간
😡 보안 감사 리포트 작성 4시간
```

#### 🏆 Terraform의 승리

**Git 기반 워크플로우:**
```bash
# 1. 개발자가 브랜치 생성
git checkout -b feature/add-new-sg

# 2. 코드 수정
# security_group.tf
resource "aws_security_group" "web" {
  ingress {
    from_port   = 443
    to_port     = 443
    cidr_blocks = ["10.0.0.0/16"]  # 내부 네트워크만 허용
  }
}

# 3. Pull Request 생성
git push origin feature/add-new-sg

# 4. 코드 리뷰
팀원 A: "왜 443만 열었나요?"
개발자: "HTTPS만 필요해서요. HTTP는 리다이렉트 처리합니다."
팀원 B: "LGTM (Looks Good To Me)"

# 5. 승인 후 Merge
# 6. terraform apply 자동 실행 (CI/CD)
```

**추적 가능한 이력:**
```
commit a1b2c3d
Author: 김개발 <kim@company.com>
Date: 2025-12-31

feat: Add HTTPS-only security group for web servers

- Remove HTTP (port 80) ingress rule
- Add HTTPS (port 443) with internal CIDR only
- Related: JIRA-1234 (보안 정책 강화)

Reviewed-by: 이보안 <lee@company.com>
```

**효과:**
- ✅ **누가 (Who)**: Git Author
- ✅ **언제 (When)**: Commit Timestamp
- ✅ **무엇을 (What)**: Code Diff
- ✅ **왜 (Why)**: Commit Message + PR Description
- ✅ **승인자**: Git Reviewer

> [!success] ROI 계산
> **투자:** Git + Terraform 워크플로우 구축 1주
> **수익:** 사고 조사 시간 0시간, 보안 감사 대응 30분 (자동 추출)
> **추가 효과:** 팀 신뢰도 향상, 사고율 감소

### ✅ Case 4. 비용 절감 (생성과 파괴의 자유)

#### 📋 상황
```
리소스: GPU 인스턴스 (시간당 $3.06)
사용 패턴: 업무시간(9-18시)만 사용
현재 문제: 퇴근 후 끄는 걸 깜빡함
```

#### 🚨 ClickOps의 재앙

**비용 계산:**
```
시나리오 1: 항상 켜둠
- 월 비용: $3.06 × 24시간 × 30일 = $2,203
- 실제 사용: 9시간/일
- 낭비: $1,468 (67%)

시나리오 2: 수동으로 켜고 끔
- 깜빡한 날: 월 5일
- 낭비: $3.06 × 15시간 × 5일 = $230
```

#### 🏆 Terraform의 승리

**방법 1: 완전 삭제 후 재생성**
```bash
# 출근 시
terraform apply    # 2분 소요

# 퇴근 시
terraform destroy  # 1분 소요
```

**방법 2: Auto Scaling Schedule**
```hcl
resource "aws_autoscaling_schedule" "scale_down" {
  scheduled_action_name  = "scale-down-evening"
  min_size              = 0
  max_size              = 0
  desired_capacity      = 0
  recurrence            = "0 18 * * 1-5"  # 평일 18시
  autoscaling_group_name = aws_autoscaling_group.gpu.name
}

resource "aws_autoscaling_schedule" "scale_up" {
  scheduled_action_name  = "scale-up-morning"
  min_size              = 1
  max_size              = 5
  desired_capacity      = 2
  recurrence            = "0 9 * * 1-5"  # 평일 9시
  autoscaling_group_name = aws_autoscaling_group.gpu.name
}
```

**비용 절감:**
```
월 비용: $3.06 × 9시간 × 22일 = $606
절감액: $2,203 - $606 = $1,597 (72% 절감)
연간 절감: $19,164
```

> [!success] ROI 계산
> **투자:** Terraform 코드 작성 2시간
> **수익:** 연간 $19,164 절감
> **회수 기간:** 즉시

### ✅ Case 5. 멀티 클라우드 & 하이브리드 클라우드

#### 📋 상황
```
요구사항: AWS + GCP + Azure 동시 사용
이유: 각 클라우드의 특화 서비스 활용
- AWS: 메인 인프라
- GCP: BigQuery (데이터 분석)
- Azure: Active Directory 연동
```

#### 🚨 ClickOps의 재앙

**관리 포인트:**
- AWS 콘솔
- GCP 콘솔
- Azure Portal
- 3가지 다른 UI/UX 학습
- 3가지 다른 권한 체계
- 통합 관리 불가능

#### 🏆 Terraform의 승리

```hcl
# AWS 리소스
provider "aws" {
  region = "ap-northeast-2"
}

resource "aws_instance" "web" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t3.micro"
}

# GCP 리소스
provider "google" {
  project = "my-project"
  region  = "asia-northeast3"
}

resource "google_bigquery_dataset" "analytics" {
  dataset_id = "analytics_data"
  location   = "asia-northeast3"
}

# Azure 리소스
provider "azurerm" {
  features {}
}

resource "azurerm_virtual_network" "main" {
  name                = "main-network"
  address_space       = ["10.0.0.0/16"]
  location            = "koreacentral"
  resource_group_name = azurerm_resource_group.main.name
}
```

**효과:**
- ✅ **단일 도구**로 모든 클라우드 관리
- ✅ **일관된 문법** (HCL)
- ✅ **통합 State 관리**
- ✅ **크로스 클라우드 참조** 가능

---

## 4. 의사결정 프레임워크

### 🎯 Terraform 도입 결정 매트릭스

> [!note] 점수 계산법
> 각 항목에 점수를 매긴 후 합산하세요.
> - **0-15점**: ClickOps 권장
> - **16-30점**: 선택적 도입
> - **31-50점**: Terraform 필수

#### 📊 체크리스트

| 평가 항목 | 점수 | 배점 기준 |
|-----------|------|-----------|
| **리소스 개수** | | 1-5개(0점), 6-20개(3점), 21개 이상(5점) |
| **환경 개수** | | 1개(0점), 2개(5점), 3개 이상(10점) |
| **팀 규모** | | 1명(0점), 2-5명(5점), 6명 이상(10점) |
| **변경 빈도** | | 월 1회 미만(0점), 주 1회(5점), 일 1회 이상(10점) |
| **생명주기** | | 1주 미만(0점), 1개월-1년(3점), 1년 이상(5점) |
| **재생성 필요성** | | 없음(0점), 가끔(3점), 자주(5점) |
| **컴플라이언스** | | 불필요(0점), 선택(3점), 필수(5점) |

#### 🧮 예제 계산

**Case A: 스타트업 초기**
```
리소스 개수: 8개 (3점)
환경 개수: Dev + Prod (5점)
팀 규모: 3명 (5점)
변경 빈도: 주 2회 (5점)
생명주기: 2년 예상 (5점)
재생성: 가끔 (3점)
컴플라이언스: 불필요 (0점)

총점: 26점 → 선택적 도입 (권장)
```

**Case B: 엔터프라이즈**
```
리소스 개수: 150개 (5점)
환경 개수: Dev + Staging + Prod + DR (10점)
팀 규모: 15명 (10점)
변경 빈도: 일 5회 (10점)
생명주기: 5년 이상 (5점)
재생성: 자주 (5점)
컴플라이언스: 필수 (5점)

총점: 50점 → Terraform 필수
```

### 🔄 단계별 도입 전략

> [!tip] 점진적 도입
> "한 번에 모든 걸 Terraform으로 옮기지 마세요!"

#### 1단계: 파일럿 (1-2주)

**목표:** 작은 성공 경험
```
대상: 개발 환경의 일부 (EC2 2-3대)
범위: main.tf 하나로 관리
학습: terraform init/plan/apply/destroy
```

#### 2단계: 확장 (1개월)

**목표:** 모듈화 및 구조화
```
대상: 개발 환경 전체
구조: modules/ 디렉토리 도입
학습: 모듈, 변수, 출력
```

#### 3단계: 프로덕션 (2-3개월)

**목표:** 운영 환경 적용
```
대상: Staging → Prod 순차 적용
필수: 원격 백엔드 (S3 + DynamoDB)
학습: State 관리, Locking
```

#### 4단계: 고도화 (지속)

**목표:** 완전 자동화
```
대상: 모든 인프라
구현: CI/CD 파이프라인 통합
학습: Terraform Cloud, Atlantis
```

---

## 5. 실무 사례

### 💼 Case Study 1: 스타트업 A사

**배경:**
- 팀: 개발자 5명
- 인프라: AWS 기반
- 문제: 개발자마다 다르게 서버 세팅

**도입 전:**
```
개발자 A: "내 로컬에선 되는데..."
개발자 B: "저는 보안 그룹 이렇게 설정했는데요?"
CTO: "누가 Prod 서버 설정 바꿨어?!"

결과: 주 1회 환경 불일치 이슈
```

**도입 과정:**
```
Week 1: CTO가 Terraform 학습
Week 2: Dev 환경 Terraform 적용 (파일럿)
Week 3: Staging 환경 추가
Week 4: Prod 환경 적용 + Git 워크플로우 구축
```

**도입 후:**
```
✅ 환경 불일치 이슈: 0건
✅ 신규 개발자 온보딩: 1일 → 1시간
✅ 인프라 변경 추적: 100% Git History
✅ 비용 절감: 월 $500 (불필요한 리소스 자동 정리)
```

### 💼 Case Study 2: 대기업 B사

**배경:**
- 팀: 인프라 15명, 개발 50명
- 인프라: AWS + GCP + On-Premise
- 문제: 감사 대응 어려움, 변경 관리 혼란

**도입 전:**
```
감사팀: "지난달 보안 그룹 변경 내역 제출하세요."
인프라팀: *3일간 CloudTrail 로그 분석*
         *엑셀로 수작업 정리*
         *30페이지 리포트 작성*
```

**도입 과정:**
```
Month 1-2: Terraform 교육 및 표준 수립
Month 3-4: 신규 프로젝트에만 Terraform 적용
Month 5-6: 기존 인프라 Import (terraform import)
Month 7-12: 레거시 점진적 마이그레이션
```

**도입 후:**
```
✅ 감사 대응: Git 로그 추출 10분
✅ 변경 승인: PR 리뷰 프로세스 자동화
✅ 장애 복구: 평균 4시간 → 30분
✅ 인프라 문서: 자동 생성 (terraform-docs)
✅ 비용 가시성: 태그 기반 자동 분류
```

### 💼 Case Study 3: 교육기관 C사 (안 쓴 사례)

**배경:**
- 팀: 교수 1명, 조교 2명
- 인프라: AWS 교육용 계정
- 사용: 학기 중 3개월만 사용

**Terraform 미도입 결정:**
```
이유:
1. 리소스: EC2 5대, S3 버킷 2개 (매우 단순)
2. 생명주기: 학기 종료 후 모두 삭제
3. 변경: 학기 중 거의 없음
4. 팀: 비개발자 위주

결정: AWS CloudFormation Template 1개로 관리
     (학기 시작: Create Stack, 종료: Delete Stack)
```

**결과:**
```
✅ 학습 비용 최소화
✅ 목적 달성 (교육용 환경 제공)
✅ 관리 부담 없음
```

---

## 🎓 학습 전략 (훈련생 관점)

### 📚 단계별 학습 로드맵

> [!tip] 학습 단계
> "콘솔로 이해 → Terraform으로 구현"

#### Phase 1: 구조 이해 (콘솔 학습)

**목표:** AWS 리소스 간 관계 파악
```
방법: AWS 콘솔에서 직접 클릭
학습 내용:
- VPC 안에 Subnet이 있구나
- Subnet 안에 EC2가 있구나
- EC2는 Security Group으로 보호되는구나
- Load Balancer가 트래픽을 분산하는구나

시간: 1-2주
```

#### Phase 2: 코드로 전환 (Terraform 학습)

**목표:** 구조를 코드로 표현
```
방법: Terraform 기초 가이드 학습
학습 내용:
- 콘솔에서 클릭한 것을 코드로 작성
- terraform plan으로 미리보기
- terraform apply로 생성

시간: 1주
```

#### Phase 3: 실전 프로젝트 (포트폴리오)

**목표:** 채용 담당자 감동시키기
```
방법: 파이널 프로젝트를 Terraform으로 구성
구성:
├── terraform/
│   ├── modules/          # 재사용 가능한 모듈
│   ├── environments/
│   │   ├── dev/
│   │   ├── staging/
│   │   └── prod/
│   └── README.md

강조점:
✅ "환경 재현 가능" (면접관이 terraform apply 한 번에 실행 가능)
✅ "모범 사례 적용" (모듈화, 원격 백엔드)
✅ "문서화" (README + 주석)

시간: 파이널 프로젝트 기간 (2-4주)
```

### 💡 면접 어필 포인트

> [!quote] 면접에서 이렇게 말하세요
> "프로젝트 인프라를 Terraform으로 코드화했습니다.
> 덕분에 팀원들이 5분 안에 동일한 환경을 구축할 수 있었고,
> Dev/Staging/Prod 환경 불일치 문제가 0건이었습니다."

**추가 어필:**
```
면접관: "Terraform 왜 썼어요? 콘솔이 더 쉽지 않나요?"

답변 (초급):
"처음엔 콘솔이 더 쉬웠지만, 팀원들이
같은 환경을 만들 때 Terraform이 훨씬 빨랐습니다."

답변 (중급):
"IaC를 통해 인프라 변경 이력을 Git으로 관리하고,
코드 리뷰를 통해 실수를 사전에 방지했습니다."

답변 (고급):
"CI/CD 파이프라인과 통합하여 PR 머지 시
자동으로 terraform plan을 실행하고,
승인 후 apply하는 GitOps 워크플로우를 구축했습니다."
```

---

## 🔑 핵심 정리

### ✅ Terraform을 쓸 때

1. **환경이 2개 이상** (Dev/Prod)
2. **팀원이 2명 이상**
3. **변경이 주 1회 이상**
4. **재생성 필요성 있음**
5. **컴플라이언스 필요**
6. **비용 최적화 중요**

### ❌ Terraform을 안 써도 될 때

1. **1회성 테스트**
2. **초소규모 (리소스 5개 미만)**
3. **변경이 거의 없음**
4. **혼자 관리**
5. **학습/프로토타이핑**

### ⚖️ 결론

> [!quote] 골든 룰
> **"반복되면 Terraform, 1회성이면 ClickOps"**

> [!success] 실무 조언
> 회사에 입사하면 사수에게 이렇게 물어보세요:
>
> **"지금 이 작업, Terraform으로 모듈화해 두면
> 다음에 다른 팀원들이 재사용할 수 있을 것 같은데
> 제가 한번 만들어볼까요?"**
>
> → 사수가 감동의 눈물을 흘립니다 🥹

---

## 📊 ROI 요약표

| 상황 | Terraform 투자 | Terraform 수익 | 회수 기간 |
|------|----------------|----------------|-----------|
| **멀티 환경** | 학습 1주 + 코드 2일 | 환경 불일치 장애 0건 | 1개월 |
| **재해 복구** | 코드 작성 3일 | 복구 시간 6시간 → 15분 | 첫 장애 시 |
| **팀 협업** | 워크플로우 구축 1주 | 사고 조사 4시간 → 0시간 | 2주 |
| **비용 절감** | 코드 작성 2시간 | 연 $19,164 절감 | 즉시 |

---

> Created: 2025-12-31
> Tags: #terraform #tradeoff #의사결정 #실무 #ROI
> Category: 기술분석
