---
title: 01_Terraform_Fundamentals
creation_date: 2026-01-21
date: 2026-01-21
tags: [Terraform, GCP, Lab]
category: 클라우드/Terraform
status: 완성
priority: 높음
model: gemini-3.0-pro preview
published: false
---

# 🏗️ Lab 1: Terraform Fundamentals

**목표**: Terraform 설정 파일을 작성하고, GCP VM 인스턴스를 생성/수정/삭제하는 기본 워크플로우(`init` -> `plan` -> `apply` -> `destroy`)를 익힙니다.

## 1. `main.tf` 작성
작업 디렉토리: `terraform-labs/lab1/`

```hcl
terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
      version = "4.51.0"
    }
  }
}

provider "google" {
  # gcloud config set project로 설정했다면 생략 가능하지만 명시 권장
  # project = "[YOUR_PROJECT_ID]" 
  region  = "us-central1"
  zone    = "us-central1-a"
}

resource "google_compute_instance" "vm_instance" {
  name         = "terraform-instance"
  machine_type = "e2-micro"  # ✨ Free Tier (원래 랩: e2-medium)
  tags         = ["web", "dev"]

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  network_interface {
    network = "default"
    access_config {
      # Ephemeral public IP
    }
  }
}
```

## 2. 실습 진행 (Workflow)

### Step 1. 초기화
Terraform Provider 플러그인을 다운로드합니다.
```bash
terraform init
```

### Step 2. 계획 확인
어떤 리소스가 생성될지 미리 봅니다.
```bash
terraform plan
```
*   `+ create` 표시 확인.

### Step 3. 적용 (생성)
실제로 GCP에 리소스를 생성합니다.
```bash
terraform apply
# Enter a value: yes 입력
```
*   완료 후 GCP 콘솔 > Compute Engine에서 `terraform-instance`가 생성되었는지 확인하세요.

### Step 4. 인프라 수정 및 검증
`main.tf`를 수정하여 태그를 변경해봅니다.
```hcl
  tags = ["web", "dev", "test"] # "test" 추가
```

#### 4.1 코드 품질 관리 (Best Practice)
실무에서는 적용 전에 항상 코드를 정리하고 검사합니다.
```bash
# 코드 포맷팅 (들여쓰기 정렬)
terraform fmt

# 문법 유효성 검사
terraform validate
```

#### 4.2 출력 변수 (Outputs) 추가
생성된 VM의 내부 IP 등을 확인하고 싶다면 `outputs.tf`를 작성합니다.
```hcl
# outputs.tf
output "vm_internal_ip" {
  value = google_compute_instance.vm_instance.network_interface.0.network_ip
}
```
다시 적용하면 IP가 출력됩니다.
```bash
terraform apply
# Apply complete! Outputs:
# vm_internal_ip = "10.128.0.2"
```

### Step 5. 삭제 (중요!)
실습이 끝나면 리소스를 삭제하여 과금을 방지합니다.
```bash
terraform destroy
# Enter a value: yes 입력
```

## 3. 🤖 Gemini Prompt Tip (정석 요청법)
Gemini Code Assist에게 명확한 사양(Specification)을 제시하여 코드를 생성하는 정석적인 방법입니다.

> **Prompt:**
> ```text
> Generate the Terraform configuration for a Google Compute Engine virtual machine, saving it to main.tf, based on the following specifications:
> 
> *   Name: terraform-instance
> *   Machine Type: e2-micro
> *   Zone: us-central1-a
> *   Boot Disk: Debian 11
> *   Network: Default network
> *   Tags: web, dev
> ```

Gemini가 위 사양을 완벽하게 반영한 `resource "google_compute_instance"` 블록을 작성해줍니다. `e2-micro`를 명시함으로써 비용 발생을 원천 차단하는 것이 핵심입니다.

<br>
<div align="right" style="font-size: 0.8em; color: gray; opacity: 0.6;">
  Supported by gemini-3.0-pro preview
</div>
