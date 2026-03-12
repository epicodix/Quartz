---
title: Goorm4I 팀프로젝트 인프라 세팅
tags:
  - k3d
  - terraform
  - kubernetes
  - github
  - devops
  - infrastructure
  - team-project
aliases:
  - 팀프로젝트 인프라
  - goorm4i infra
date: 2026-02-24
category: 교육/구름딥다이브
status: 진행중
priority: 높음
---

# 🎯 Goorm4I 팀프로젝트 인프라 세팅

## 📑 목차
- [[#1. 모노레포 구조|모노레포 구조]]
- [[#2. GitHub 워크플로우 규칙|GitHub 워크플로우 규칙]]
- [[#3. k3d 로컬 K8s 환경|k3d 로컬 K8s 환경]]
- [[#4. Terraform AWS 연결|Terraform AWS 연결]]

---

## 1. 모노레포 구조

> [!note] 선택 배경
> 신입 4명 팀 구성. 멀티레포보다 모노레포가 전체 구조 파악과 협업에 유리

```
test-monorepo/
├── .github/
│   ├── PULL_REQUEST_TEMPLATE.md
│   └── ISSUE_TEMPLATE/
│       ├── feature.md
│       ├── bug.md
│       └── infra.md
├── backend/
│   └── order-service/
├── frontend/
└── infra/
    ├── docker-compose.yaml
    ├── k3d/
    ├── helm/
    └── terraform/
```

### 장단점 비교

| 항목 | 모노레포 | 멀티레포 |
|------|---------|---------|
| 전체 구조 파악 | 쉬움 | 레포마다 확인 필요 |
| 인프라 + 코드 PR | 하나로 가능 | 별도 PR |
| 충돌 가능성 | 공용 파일에서 발생 | 낮음 |
| CI/CD 설정 | 복잡해질 수 있음 | 서비스별 독립 |

### 브랜치 전략

```
main        → 보호 규칙 (PR + Approve 1개 필수)
 └── develop → 개발 통합
      ├── feature/be/#이슈번호-설명
      ├── feature/fe/#이슈번호-설명
      └── feature/infra/#이슈번호-설명
```

> [!tip] 모노레포 브랜치 네이밍
> `feature/infra/#8-k3d-setup` 처럼 폴더 prefix 붙이면 칸반보드에서 누가 뭘 건드리는지 바로 파악 가능

---

## 2. GitHub 워크플로우 규칙

### 칸반보드 흐름

```
Backlog → To Do → In Progress → Review → Done
```

- Issue opened → Backlog 자동 추가
- PR opened → Review 자동 이동
- PR merged → Done 자동 이동 + Issue 자동 Close

### 커밋 컨벤션

```
형식: Type: 설명 (#이슈번호)

Feat / Fix / Docs / Style / Refactor / Test / Chore / Build / CI
```

### PR 규칙

- `closes #이슈번호` 본문에 작성 → 머지 시 이슈 자동 Close
- 최소 리뷰어 1명 지정
- 24시간 이내 리뷰 (주말 제외)
- Approve 1개 이상 후 **작성자 본인이 머지**

### Pn 룰 (리뷰 코멘트 우선순위)

| 레벨 | 의미 |
|------|------|
| P1 | Must Fix - 반드시 수정 후 머지 |
| P2 | Should Fix - 반영 권장 |
| P3 | Optional - 작성자 자율 |
| P5 | Info - 칭찬, 정보 공유 |

### GitHub 템플릿 설정

`.github/` 폴더는 **default branch(main)** 에서만 읽힘

```
현재 상태:
  develop → 템플릿 있음 (feature PR 테스트 가능)
  main    → 팀원 오면 PR + 리뷰 후 머지 예정
```

---

## 3. k3d 로컬 K8s 환경

> [!note] 선택 이유
> Terraform(EKS)보다 먼저 구성. 팀원들이 앱 개발 단계에서 비용 없이 K8s 환경 사용 가능

### 클러스터 구성 (`infra/k3d/cluster.yaml`)

| 항목 | 값 |
|------|-----|
| 클러스터 이름 | timedeal |
| 서버 (Control Plane) | 1개 |
| 에이전트 (Worker) | 2개 |
| Ingress HTTP | localhost:8080 |
| Ingress HTTPS | localhost:8443 |
| 로컬 레지스트리 | localhost:5001 |

### 팀원 사용법

```bash
# 1. 클러스터 시작
cd infra/k3d && ./setup.sh

# 2. 상태 확인
kubectl get nodes

# 3. 로컬 이미지 올리기
docker build -t timedeal-registry:5001/order-service:latest ./backend/order-service
docker push timedeal-registry:5001/order-service:latest

# 4. 정리
./teardown.sh
```

### 단계별 작업 계획

```
지금     → k3d 로컬 환경 (현재)
중반     → Helm 차트 작성
마지막   → Terraform으로 실제 EKS 배포
```

---

## 4. Terraform AWS 연결

### 계정 정보

| 항목 | 값 |
|------|-----|
| 계정 | Goorm4I 팀 IAM (jihoon) |
| 리전 | ap-southeast-2 (시드니) |
| 프로필 | goorm |

### 파일 구조

```
infra/terraform/
├── versions.tf              # AWS provider ~5.0
├── main.tf                  # data source (caller_identity, region)
├── variables.tf             # region, aws_profile(null), project_name
├── outputs.tf               # account_id, caller_arn, region 출력
└── terraform.tfvars.example # 팀원 설정 예시
```

### 팀원별 프로필 설정

> [!warning] 주의
> `aws_profile`이 하드코딩되면 본인 IAM만 동작. `null`로 두고 환경변수 사용

```bash
# 방법 1: 환경변수
export AWS_PROFILE=본인프로필
terraform plan

# 방법 2: tfvars (gitignore됨)
cp terraform.tfvars.example terraform.tfvars
# aws_profile = "본인프로필" 로 수정 후 실행
```

### 연결 테스트 결과

```bash
terraform plan
# account_id = "779846782353"
# caller_arn = "arn:aws:iam::779846782353:user/jihoon"
# region     = "ap-southeast-2"
# 리소스 생성 없음 → 비용 0원
```

---

## 레포 링크

- GitHub: https://github.com/Goorm4I/test-monorepo
- 조직: https://github.com/orgs/Goorm4I
