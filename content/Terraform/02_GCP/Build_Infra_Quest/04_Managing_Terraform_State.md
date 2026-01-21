---
title: 04_Managing_Terraform_State
creation_date: 2026-01-21
date: 2026-01-21
tags: [Terraform, GCP, State, Backend, GCS]
category: 클라우드/Terraform
status: 완성
priority: 높음
model: gemini-3.0-pro preview
published: false
---

# 💾 Lab 4: Managing Terraform State (원격 저장소)

**목표**: 로컬(`terraform.tfstate`) 파일이 아닌, **GCS 버킷**을 백엔드(Backend)로 사용하여 상태 파일의 안전성, 잠금(Locking), 협업 기능을 확보합니다.

## 1. 사전 준비: GCS 버킷 생성
Terraform이 상태를 저장할 버킷은 Terraform으로 만들기보다, 미리 만들어두는 것이 일반적입니다. (Chicken-and-Egg 문제 방지)

```bash
# 유니크한 버킷 이름 생성 (예: tf-state-내이름-2026)
gsutil mb -l us-central1 gs://[YOUR_UNIQUE_BUCKET_NAME]
# 예: gsutil mb -l us-central1 gs://tf-state-a1234-lab
```

## 2. `backend.tf` 작성
작업 디렉토리: `terraform-labs/lab4/`

```hcl
terraform {
  backend "gcs" {
    bucket  = "[YOUR_UNIQUE_BUCKET_NAME]" # 위에서 만든 버킷 이름
    prefix  = "terraform/state"
  }
}

provider "google" {
  region = "us-central1"
}

resource "google_compute_instance" "vm_state_demo" {
  name         = "vm-state-demo"
  machine_type = "e2-micro"
  zone         = "us-central1-a"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  network_interface {
    network = "default"
  }
}
```

## 3. 실습 가이드 (Migration)
1.  **`terraform init`**:
    *   Terraform이 "백엔드를 GCS로 설정하시겠습니까?"라고 묻습니다. `yes` 입력.
    *   이제부터 `terraform apply`를 하면 상태 정보가 내 컴퓨터가 아닌 GCS 버킷에 저장됩니다.
2.  **`terraform plan`**:
    *   생성될 리소스와 변경 사항을 미리 확인합니다.
    *   State가 비어있다면 `+ create`가 뜰 것이고, 기존 State를 마이그레이션했다면 `No changes`가 뜰 수 있습니다.
3.  **`terraform apply`**: 리소스 생성.
4.  **확인**: GCP 콘솔 > Cloud Storage > 버킷 > `terraform/state/default.tfstate` 파일이 생겼는지 확인합니다.

## 4. 심화 실습: Terraform Import (기존 리소스 가져오기)
이미 만들어진 리소스를 Terraform 관리하로 가져오는 방법입니다.

1.  **수동 생성**: GCP 콘솔에서 VM(`manual-vm`)을 하나 만듭니다. (e2-micro)
2.  **코드 작성**: `main.tf`에 해당 VM의 껍데기 코드를 작성합니다.
    ```hcl
    resource "google_compute_instance" "manual_vm" {
      # 내용은 비워두거나 필수값만 채움
      name = "manual-vm"
      machine_type = "e2-micro"
      zone = "us-central1-a"
      boot_disk {}
      network_interface {}
    }
    ```
3.  **가져오기 (Import)**:
    ```bash
    # terraform import [RESOURCE_ADDRESS] [RESOURCE_ID]
    terraform import google_compute_instance.manual_vm projects/[PROJECT_ID]/zones/us-central1-a/instances/manual-vm
    ```
4.  **동기화**: `terraform plan`을 실행하면, Terraform이 상태 파일과 실제 리소스의 차이를 보여줍니다. 코드를 실제 설정에 맞게 수정하여 `No changes`가 뜨게 만듭니다.

## 5. 실습 종료
5.  **`terraform destroy`**: 리소스 삭제.
    *   삭제 후에도 GCS 버킷의 `tfstate` 파일은 남아있어 이력을 보존합니다.

## 4. 🤖 Gemini Prompt Tip (정석 요청법)
백엔드 설정도 사양 목록으로 요청하면 실수를 줄일 수 있습니다.

> **Prompt:**
> ```text
> Generate Terraform backend configuration based on the following specifications:
> 
> *   Backend Type: gcs
> *   Bucket Name: [YOUR_UNIQUE_BUCKET_NAME]
> *   Prefix: terraform/state
> *   Action: Configure this backend in the terraform block.
> ```

Gemini가 정확한 `backend "gcs"` 블록을 생성해줍니다.

<br>
<div align="right" style="font-size: 0.8em; color: gray; opacity: 0.6;">
  Supported by gemini-3.0-pro preview
</div>
