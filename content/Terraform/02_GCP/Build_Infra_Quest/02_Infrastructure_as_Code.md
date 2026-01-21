---
title: 02_Infrastructure_as_Code
creation_date: 2026-01-21
date: 2026-01-21
tags: [Terraform, GCP, VPC, Lab]
category: 클라우드/Terraform
status: 완성
priority: 높음
model: gemini-3.0-pro preview
published: false
---

# 🔗 Lab 2: Infrastructure as Code (리소스 의존성)

**목표**: VPC 네트워크와 서브넷을 직접 정의하고, VM 인스턴스가 해당 네트워크를 참조(`reference`)하도록 구성하여 리소스 간의 **암시적 의존성(Implicit Dependency)**을 이해합니다.

## 1. `main.tf` 작성
작업 디렉토리: `terraform-labs/lab2/`

```hcl
provider "google" {
  region = "us-central1"
}

# 1. VPC 네트워크 생성
resource "google_compute_network" "vpc_network" {
  name = "terraform-network"
  auto_create_subnetworks = false # 커스텀 서브넷 사용
}

# 2. 서브넷 생성
resource "google_compute_subnetwork" "subnetwork" {
  name          = "terraform-subnetwork"
  ip_cidr_range = "10.20.0.0/16"
  region        = "us-central1"
  network       = google_compute_network.vpc_network.id # 🔗 참조 (의존성 발생)
}

# 3. 방화벽 규칙 생성 (SSH 허용)
resource "google_compute_firewall" "allow_ssh" {
  name    = "allow-ssh"
  network = google_compute_network.vpc_network.id

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"] # 주의: 실습용으로만 전체 허용
}

# 4. VM 인스턴스 생성 (서브넷 안에 배치)
resource "google_compute_instance" "vm_instance" {
  name         = "terraform-instance-2"
  machine_type = "e2-micro" # ✨ Free Tier
  zone         = "us-central1-a"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.subnetwork.id # 🔗 참조
    access_config {
      # Public IP 부여
    }
  }
}
```

## 2. 학습 포인트 (Dependency Graph)
Terraform은 위 코드를 보고 실행 순서를 자동으로 결정합니다.
1.  `vpc_network` 생성 (독립적)
2.  `subnetwork` 생성 (`vpc_network` ID가 필요하므로 1번 후 실행)
3.  `vm_instance` 생성 (`subnetwork` ID가 필요하므로 2번 후 실행)

## 3. 실습 가이드
1.  `terraform init`
2.  `terraform apply`
3.  **확인**: GCP 콘솔 > VPC 네트워크에서 `terraform-network`와 `10.20.0.0/16` 대역 확인.
4.  `terraform destroy` (**필수**)

## 4. 🤖 Gemini Prompt Tip (정석 요청법)
복잡한 의존성 관계도 사양 목록(List)으로 명확히 전달하세요.

> **Prompt:**
> ```text
> Generate Terraform configuration for a custom VPC network and a VM instance based on the following specifications:
> 
> *   VPC Name: terraform-network
> *   Subnet Name: terraform-subnetwork
> *   Subnet Region: us-central1
> *   Subnet Range: 10.20.0.0/16
> *   VM Name: terraform-instance-2
> *   VM Machine Type: e2-micro
> *   VM Zone: us-central1-a
> *   Dependency: The VM must use the custom subnet created above.
> ```

Gemini는 `depends_on`을 명시하거나 리소스 ID 참조를 통해 의존성을 올바르게 설정한 코드를 생성합니다.

<br>
<div align="right" style="font-size: 0.8em; color: gray; opacity: 0.6;">
  Supported by gemini-3.0-pro preview
</div>
