---
title: 00_Terraform_GCP_Setup_Guide
creation_date: 2026-01-21
date: 2026-01-21
tags: [Terraform, GCP, Setup, FreeTier]
category: 클라우드/Terraform
status: 완성
priority: 높음
model: gemini-3.0-pro preview
published: false
---

# 🛠️ Terraform GCP 로컬 실습 환경 구축 (0원 도전)

Google Cloud Skills Boost의 **"Build Infrastructure with Terraform on Google Cloud"** 퀘스트를 개인 계정으로 실습하기 위한 사전 준비 가이드입니다.

## 1. 💸 비용 방지 원칙 (Cost Safety)
개인 계정에서 실습할 때는 아래 규칙을 **반드시** 지켜야 요금 폭탄을 피할 수 있습니다.

1.  **리소스 즉시 삭제**: 실습(`terraform apply`) 후 반드시 `terraform destroy`를 실행합니다.
2.  **Free Tier 리전 사용**: 모든 리소스는 **`us-central1` (Iowa)**, `us-west1` (Oregon), `us-east1` (South Carolina) 중 하나에 생성합니다.
3.  **e2-micro 사용**: VM 인스턴스 타입은 무조건 `e2-micro`를 사용합니다. (월 1대 무료)
4.  **Load Balancer 금지**: 실습 코드에 `google_compute_forwarding_rule`이 있다면 주의하세요. (시간당 과금)

## 2. 환경 설정 (Prerequisites)

### 2.1 GCP 프로젝트 준비
1.  [Google Cloud Console](https://console.cloud.google.com/) 접속.
2.  새 프로젝트 생성 (예: `terraform-lab-2026`).
3.  **결제 계정 연결** (필수, 하지만 위 원칙을 지키면 과금 안 됨).
4.  **Compute Engine API 활성화**: `API 및 서비스` > `라이브러리` > `Compute Engine API` 검색 후 사용 설정.

### 2.2 로컬 툴 설치 (macOS)
```bash
# Terraform 설치
brew tap hashicorp/tap
brew install hashicorp/tap/terraform

# Google Cloud SDK 설치 (이미 있다면 패스)
brew install --cask google-cloud-sdk
```

### 2.3 인증 설정 (Authentication)
Terraform이 내 GCP 계정 권한을 쓰도록 설정합니다.

```bash
# 1. 로그인 (브라우저 열림)
gcloud auth application-default login

# 2. 프로젝트 설정
gcloud config set project [YOUR_PROJECT_ID]
```
*   `[YOUR_PROJECT_ID]`는 프로젝트 이름이 아니라 **ID**입니다. (콘솔 대시보드에서 확인)

## 3. 작업 디렉토리 구성
실습별로 폴더를 나누어 관리하는 것을 추천합니다.

```bash
mkdir -p terraform-labs/lab1
mkdir -p terraform-labs/lab2
...
```

<br>
<div align="right" style="font-size: 0.8em; color: gray; opacity: 0.6;">
  Supported by gemini-3.0-pro preview
</div>
