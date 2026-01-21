---
title: 03_Interact_with_Terraform_Modules
creation_date: 2026-01-21
date: 2026-01-21
tags: [Terraform, GCP, Module, Lab]
category: 클라우드/Terraform
status: 완성
priority: 높음
model: gemini-3.0-pro preview
published: false
---

# 📦 Lab 3: Terraform Modules (모듈 활용)

**목표**: Terraform Registry에 있는 검증된 오픈소스 모듈(`terraform-google-modules`)을 사용하여 복잡한 네트워크 구성을 단 몇 줄로 구현해봅니다.

## 1. `main.tf` 작성 (Registry 모듈 사용)
작업 디렉토리: `terraform-labs/lab3/`

```hcl
provider "google" {
  region = "us-central1"
}

# Google이 제공하는 공식 네트워크 모듈 사용
module "network" {
  source  = "terraform-google-modules/network/google"
  version = "~> 6.0"

  network_name = "terraform-vpc-module"
  project_id   = "[YOUR_PROJECT_ID]" # ✨ 본인 프로젝트 ID 입력 필수

  subnets = [
    {
      subnet_name   = "subnet-01"
      subnet_ip     = "10.10.10.0/24"
      subnet_region = "us-central1"
    },
    {
      subnet_name   = "subnet-02"
      subnet_ip     = "10.10.20.0/24"
      subnet_region = "us-west1"
    }
  ]
}

# 모듈이 만든 서브넷에 VM 생성
resource "google_compute_instance" "vm_module" {
  name         = "vm-from-module"
  machine_type = "e2-micro"
  zone         = "us-central1-a"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  network_interface {
    # 모듈의 출력값(Output) 참조 방식
    subnetwork = module.network.subnets_names[0] 
    access_config {}
  }
}
```

## 2. 실습 가이드
1.  **`terraform init`**: 모듈(`terraform-google-modules/network/google`)을 다운로드합니다. 시간이 조금 걸립니다.
2.  **`terraform apply`**:
    *   내가 일일이 `google_compute_network`, `subnetwork`, `firewall` 리소스를 정의하지 않아도 모듈이 알아서 다 만들어줍니다.
    *   *Tip: 모듈을 쓰면 코드가 훨씬 간결해집니다.*
3.  **`terraform destroy`**: 생성된 모든 리소스(VPC, 서브넷 등) 일괄 삭제.

## 3. 🤖 Gemini Prompt Tip (정석 요청법)
모듈 사용 시 입력 변수(Input Variables)를 명확히 지정하는 것이 중요합니다.

> **Prompt:**
> ```text
> Generate Terraform configuration using the 'terraform-google-modules/network/google' module based on the following specifications:
> 
> *   Module Source: terraform-google-modules/network/google
> *   Network Name: terraform-vpc-module
> *   Project ID: [YOUR_PROJECT_ID]
> *   Subnet 1: subnet-01 (10.10.10.0/24 in us-central1)
> *   Subnet 2: subnet-02 (10.10.20.0/24 in us-west1)
> *   Output: Use the created subnet-01 for a new e2-micro VM instance.
> ```

Gemini가 복잡한 모듈 블록(`module "network" { ... }`)을 정확한 문법으로 작성해줍니다.

<br>
<div align="right" style="font-size: 0.8em; color: gray; opacity: 0.6;">
  Supported by gemini-3.0-pro preview
</div>
