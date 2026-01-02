---
title: Terraform GCP Provider 기초 - Google Cloud 핵심 리소스 코드 블럭
tags:
  - terraform
  - gcp
  - google-cloud
  - provider
  - 코드스니펫
aliases:
  - GCP테라폼
  - GCP코드블럭
date: 2025-12-31
category: Terraform/GCP
status: 완성
priority: 높음
---

# ☁️ Terraform GCP Provider 기초

> [!note] 문서 목적
> Google Cloud Platform에서 가장 많이 사용하는 리소스들의 Terraform 코드 블럭을 제공합니다.
> 복사-붙여넣기하여 바로 사용 가능한 **실전 스니펫 모음**입니다.

## 📑 목차
- [[#1. Provider 설정|Provider 설정]]
- [[#2. Compute Engine|Compute Engine]]
- [[#3. Google Kubernetes Engine|GKE]]
- [[#4. Cloud Run|Cloud Run]]
- [[#5. Database|Database]]
- [[#6. Storage|Storage]]
- [[#7. Networking|Networking]]
- [[#8. Security|Security & IAM]]

---

## 1. Provider 설정

### 🔧 기본 Provider 설정

```hcl
# 📊 Terraform 블럭
terraform {
  required_version = ">= 1.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

# 📊 Provider 설정 - 기본
provider "google" {
  project = "my-project-id"
  region  = "asia-northeast3"  # 서울 리전
  zone    = "asia-northeast3-a"
}
```

### 🌍 멀티 프로젝트 설정

```hcl
# 📊 프로덕션 프로젝트
provider "google" {
  alias   = "prod"
  project = "my-prod-project"
  region  = "asia-northeast3"
}

# 📊 개발 프로젝트
provider "google" {
  alias   = "dev"
  project = "my-dev-project"
  region  = "asia-northeast3"
}

# 📊 미국 프로젝트 (글로벌 서비스)
provider "google" {
  alias   = "us"
  project = "my-us-project"
  region  = "us-central1"
}

# 사용 예시
resource "google_compute_instance" "prod_vm" {
  provider = google.prod
  # ...
}
```

### 🔐 자격증명 설정

```hcl
# 방법 1: 서비스 계정 키 파일 (권장)
provider "google" {
  project     = "my-project-id"
  credentials = file("~/.gcp/my-project-key.json")
  region      = "asia-northeast3"
}

# 방법 2: 환경 변수 사용
# export GOOGLE_APPLICATION_CREDENTIALS="/path/to/keyfile.json"
# export GOOGLE_PROJECT="my-project-id"
# export GOOGLE_REGION="asia-northeast3"
provider "google" {
  # 환경 변수가 자동으로 사용됨
}

# 방법 3: gcloud CLI 인증 사용 (로컬 개발)
# gcloud auth application-default login
provider "google" {
  project = "my-project-id"
  region  = "asia-northeast3"
}
```

### 🏷️ 기본 라벨 설정

```hcl
provider "google" {
  project = "my-project-id"
  region  = "asia-northeast3"

  # 모든 리소스에 자동 적용될 기본 라벨
  default_labels = {
    environment = "production"
    managed_by  = "terraform"
    team        = "devops"
    project     = "myapp"
  }
}
```

---

## 2. Compute Engine

### 🖥️ VM 인스턴스

```hcl
# 📊 Compute Instance
resource "google_compute_instance" "web" {
  name         = "web-server"
  machine_type = "e2-micro"  # 프리티어
  zone         = "asia-northeast3-a"

  # 부팅 디스크
  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 20
      type  = "pd-standard"
    }
  }

  # 네트워크 인터페이스
  network_interface {
    network = "default"

    # 외부 IP 할당
    access_config {
      # Ephemeral IP
    }
  }

  # 메타데이터
  metadata = {
    ssh-keys = "username:${file("~/.ssh/id_rsa.pub")}"
  }

  # 시작 스크립트
  metadata_startup_script = <<-EOF
    #!/bin/bash
    apt-get update
    apt-get install -y nginx
    systemctl start nginx
    systemctl enable nginx
    echo "<h1>Hello from Terraform!</h1>" > /var/www/html/index.html
  EOF

  # 서비스 계정
  service_account {
    email  = google_service_account.vm.email
    scopes = ["cloud-platform"]
  }

  # 라벨
  labels = {
    role = "web-server"
  }

  tags = ["http-server", "https-server"]
}

# 📊 방화벽 규칙 - HTTP
resource "google_compute_firewall" "http" {
  name    = "allow-http"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["http-server"]
}
```

### 📦 Instance Template & Managed Instance Group

```hcl
# 📊 Instance Template
resource "google_compute_instance_template" "web" {
  name_prefix  = "web-template-"
  machine_type = "e2-medium"
  region       = "asia-northeast3"

  disk {
    source_image = "ubuntu-os-cloud/ubuntu-2204-lts"
    auto_delete  = true
    boot         = true
    disk_size_gb = 20
  }

  network_interface {
    network = "default"

    access_config {
      # Ephemeral IP
    }
  }

  metadata_startup_script = <<-EOF
    #!/bin/bash
    apt-get update
    apt-get install -y nginx
    HOSTNAME=$(hostname)
    echo "<h1>Server: $HOSTNAME</h1>" > /var/www/html/index.html
    systemctl start nginx
  EOF

  service_account {
    email  = google_service_account.vm.email
    scopes = ["cloud-platform"]
  }

  tags = ["http-server"]

  lifecycle {
    create_before_destroy = true
  }
}

# 📊 Managed Instance Group
resource "google_compute_instance_group_manager" "web" {
  name               = "web-igm"
  base_instance_name = "web"
  zone               = "asia-northeast3-a"
  target_size        = 2

  version {
    instance_template = google_compute_instance_template.web.id
  }

  named_port {
    name = "http"
    port = 80
  }

  auto_healing_policies {
    health_check      = google_compute_health_check.web.id
    initial_delay_sec = 300
  }
}

# 📊 Health Check
resource "google_compute_health_check" "web" {
  name                = "web-health-check"
  check_interval_sec  = 10
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 3

  http_health_check {
    port         = 80
    request_path = "/"
  }
}

# 📊 Autoscaler
resource "google_compute_autoscaler" "web" {
  name   = "web-autoscaler"
  zone   = "asia-northeast3-a"
  target = google_compute_instance_group_manager.web.id

  autoscaling_policy {
    max_replicas    = 10
    min_replicas    = 2
    cooldown_period = 60

    cpu_utilization {
      target = 0.7
    }
  }
}
```

---

## 3. Google Kubernetes Engine (GKE)

### ☸️ GKE 클러스터 (Autopilot)

```hcl
# 📊 GKE Autopilot 클러스터 (권장)
resource "google_container_cluster" "autopilot" {
  name     = "autopilot-cluster"
  location = "asia-northeast3"

  # Autopilot 모드 활성화
  enable_autopilot = true

  # IP 할당 정책
  ip_allocation_policy {
    cluster_ipv4_cidr_block  = "/17"
    services_ipv4_cidr_block = "/22"
  }

  # 릴리스 채널
  release_channel {
    channel = "REGULAR"
  }

  # 네트워크 정책
  network_policy {
    enabled = true
  }

  # Workload Identity
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }
}
```

### ☸️ GKE 클러스터 (Standard)

```hcl
# 📊 GKE Standard 클러스터
resource "google_container_cluster" "standard" {
  name     = "standard-cluster"
  location = "asia-northeast3"

  # 초기 노드 풀 제거 (별도로 관리)
  remove_default_node_pool = true
  initial_node_count       = 1

  # 네트워크 설정
  network    = "default"
  subnetwork = "default"

  # IP 할당 정책
  ip_allocation_policy {
    cluster_ipv4_cidr_block  = "/17"
    services_ipv4_cidr_block = "/22"
  }

  # 마스터 인증
  master_auth {
    client_certificate_config {
      issue_client_certificate = false
    }
  }

  # Workload Identity
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # 릴리스 채널
  release_channel {
    channel = "REGULAR"
  }

  # 애드온
  addons_config {
    http_load_balancing {
      disabled = false
    }
    horizontal_pod_autoscaling {
      disabled = false
    }
  }
}

# 📊 Node Pool
resource "google_container_node_pool" "primary" {
  name       = "primary-node-pool"
  location   = "asia-northeast3"
  cluster    = google_container_cluster.standard.name
  node_count = 1

  # Autoscaling
  autoscaling {
    min_node_count = 1
    max_node_count = 5
  }

  # 노드 설정
  node_config {
    machine_type = "e2-medium"
    disk_size_gb = 100
    disk_type    = "pd-standard"

    # OAuth 스코프
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    # 라벨
    labels = {
      env = "production"
    }

    # 태그
    tags = ["gke-node"]

    # Workload Identity
    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    # 서비스 계정
    service_account = google_service_account.gke_node.email
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }
}
```

---

## 4. Cloud Run

### 🏃 Cloud Run 서비스

```hcl
# 📊 Cloud Run 서비스
resource "google_cloud_run_service" "app" {
  name     = "my-app"
  location = "asia-northeast3"

  template {
    spec {
      # 컨테이너 설정
      containers {
        image = "gcr.io/${var.project_id}/my-app:latest"

        # 리소스 제한
        resources {
          limits = {
            cpu    = "1000m"
            memory = "512Mi"
          }
        }

        # 환경 변수
        env {
          name  = "ENVIRONMENT"
          value = "production"
        }

        env {
          name = "DATABASE_URL"
          value_from {
            secret_key_ref {
              name = google_secret_manager_secret.db_url.secret_id
              key  = "latest"
            }
          }
        }

        # 포트
        ports {
          container_port = 8080
        }
      }

      # 서비스 계정
      service_account_name = google_service_account.cloud_run.email

      # 동시성
      container_concurrency = 80

      # 타임아웃
      timeout_seconds = 300
    }

    metadata {
      annotations = {
        "autoscaling.knative.dev/minScale" = "1"
        "autoscaling.knative.dev/maxScale" = "10"
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }

  autogenerate_revision_name = true
}

# 📊 Cloud Run 퍼블릭 액세스 허용
resource "google_cloud_run_service_iam_member" "public" {
  service  = google_cloud_run_service.app.name
  location = google_cloud_run_service.app.location
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# 📊 커스텀 도메인
resource "google_cloud_run_domain_mapping" "app" {
  name     = "app.example.com"
  location = google_cloud_run_service.app.location

  metadata {
    namespace = var.project_id
  }

  spec {
    route_name = google_cloud_run_service.app.name
  }
}
```

---

## 5. Database

### 🗄️ Cloud SQL (PostgreSQL)

```hcl
# 📊 Cloud SQL Instance
resource "google_sql_database_instance" "main" {
  name             = "main-db-instance"
  database_version = "POSTGRES_15"
  region           = "asia-northeast3"

  settings {
    tier = "db-f1-micro"  # 프리티어

    # 백업 설정
    backup_configuration {
      enabled            = true
      start_time         = "03:00"
      point_in_time_recovery_enabled = true
      transaction_log_retention_days = 7

      backup_retention_settings {
        retained_backups = 7
        retention_unit   = "COUNT"
      }
    }

    # IP 설정
    ip_configuration {
      ipv4_enabled    = true
      private_network = null
      require_ssl     = true

      # 허용된 네트워크
      authorized_networks {
        name  = "office"
        value = "1.2.3.4/32"
      }
    }

    # 유지보수 윈도우
    maintenance_window {
      day          = 7  # 일요일
      hour         = 3
      update_track = "stable"
    }

    # 자동 스토리지 증가
    disk_autoresize       = true
    disk_autoresize_limit = 100
    disk_size             = 10
    disk_type             = "PD_SSD"

    # 고가용성
    availability_type = "REGIONAL"  # 또는 "ZONAL"

    # 데이터베이스 플래그
    database_flags {
      name  = "max_connections"
      value = "100"
    }
  }

  deletion_protection = true
}

# 📊 Database
resource "google_sql_database" "myapp" {
  name     = "myapp"
  instance = google_sql_database_instance.main.name
}

# 📊 User
resource "google_sql_user" "admin" {
  name     = "admin"
  instance = google_sql_database_instance.main.name
  password = var.db_password  # 변수로 관리!
}

# 📊 Read Replica
resource "google_sql_database_instance" "replica" {
  name                 = "main-db-replica"
  master_instance_name = google_sql_database_instance.main.name
  region               = "asia-northeast3"
  database_version     = "POSTGRES_15"

  replica_configuration {
    failover_target = false
  }

  settings {
    tier = "db-f1-micro"

    disk_autoresize       = true
    disk_autoresize_limit = 100
    availability_type     = "ZONAL"
  }
}
```

### ⚡ Firestore

```hcl
# 📊 Firestore Database
resource "google_firestore_database" "main" {
  project     = var.project_id
  name        = "(default)"
  location_id = "asia-northeast3"
  type        = "FIRESTORE_NATIVE"

  concurrency_mode            = "OPTIMISTIC"
  app_engine_integration_mode = "DISABLED"
}

# 📊 Firestore Index
resource "google_firestore_index" "users_email" {
  project    = var.project_id
  database   = google_firestore_database.main.name
  collection = "users"

  fields {
    field_path = "email"
    order      = "ASCENDING"
  }

  fields {
    field_path = "created_at"
    order      = "DESCENDING"
  }
}
```

---

## 6. Storage

### 🪣 Cloud Storage

```hcl
# 📊 Storage Bucket
resource "google_storage_bucket" "main" {
  name          = "my-unique-bucket-${var.project_id}"
  location      = "ASIA-NORTHEAST3"
  storage_class = "STANDARD"  # STANDARD, NEARLINE, COLDLINE, ARCHIVE

  # 버저닝
  versioning {
    enabled = true
  }

  # 라이프사이클
  lifecycle_rule {
    action {
      type = "SetStorageClass"
      storage_class = "NEARLINE"
    }
    condition {
      age = 30
    }
  }

  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      age = 90
      with_state = "ARCHIVED"
    }
  }

  # CORS 설정 (웹사이트 호스팅용)
  cors {
    origin          = ["https://example.com"]
    method          = ["GET", "HEAD", "PUT", "POST", "DELETE"]
    response_header = ["*"]
    max_age_seconds = 3600
  }

  # 암호화 (고객 관리 키)
  encryption {
    default_kms_key_name = google_kms_crypto_key.bucket.id
  }

  # 균일한 버킷 수준 액세스
  uniform_bucket_level_access = true

  # 퍼블릭 액세스 방지
  public_access_prevention = "enforced"

  labels = {
    environment = "production"
  }
}

# 📊 Bucket IAM
resource "google_storage_bucket_iam_member" "viewer" {
  bucket = google_storage_bucket.main.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.app.email}"
}

# 📊 정적 웹사이트 호스팅
resource "google_storage_bucket" "website" {
  name     = "www.example.com"
  location = "ASIA-NORTHEAST3"

  website {
    main_page_suffix = "index.html"
    not_found_page   = "404.html"
  }

  uniform_bucket_level_access = true
}

resource "google_storage_bucket_iam_member" "website_public" {
  bucket = google_storage_bucket.website.name
  role   = "roles/storage.objectViewer"
  member = "allUsers"
}
```

---

## 7. Networking

### 🌐 VPC Network

```hcl
# 📊 VPC Network
resource "google_compute_network" "main" {
  name                    = "main-vpc"
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

# 📊 Subnet
resource "google_compute_subnetwork" "public" {
  name          = "public-subnet"
  ip_cidr_range = "10.0.1.0/24"
  region        = "asia-northeast3"
  network       = google_compute_network.main.id

  # Secondary IP ranges (GKE용)
  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = "10.1.0.0/16"
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = "10.2.0.0/20"
  }

  # Private Google Access
  private_ip_google_access = true

  log_config {
    aggregation_interval = "INTERVAL_10_MIN"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

resource "google_compute_subnetwork" "private" {
  name          = "private-subnet"
  ip_cidr_range = "10.0.2.0/24"
  region        = "asia-northeast3"
  network       = google_compute_network.main.id

  private_ip_google_access = true
}
```

### 🔒 방화벽 규칙

```hcl
# 📊 SSH 허용
resource "google_compute_firewall" "allow_ssh" {
  name    = "allow-ssh"
  network = google_compute_network.main.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["ssh-enabled"]
}

# 📊 내부 통신 허용
resource "google_compute_firewall" "allow_internal" {
  name    = "allow-internal"
  network = google_compute_network.main.name

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = ["10.0.0.0/8"]
}

# 📊 HTTP/HTTPS 허용
resource "google_compute_firewall" "allow_http_https" {
  name    = "allow-http-https"
  network = google_compute_network.main.name

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["web-server"]
}

# 📊 Health Check 허용
resource "google_compute_firewall" "allow_health_check" {
  name    = "allow-health-check"
  network = google_compute_network.main.name

  allow {
    protocol = "tcp"
  }

  source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
  target_tags   = ["load-balanced"]
}
```

### ⚖️ Load Balancer

```hcl
# 📊 Global HTTP Load Balancer

# 백엔드 서비스
resource "google_compute_backend_service" "web" {
  name                  = "web-backend"
  port_name             = "http"
  protocol              = "HTTP"
  timeout_sec           = 30
  enable_cdn            = true
  health_checks         = [google_compute_health_check.web.id]
  load_balancing_scheme = "EXTERNAL_MANAGED"

  backend {
    group           = google_compute_instance_group_manager.web.instance_group
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1.0
  }

  cdn_policy {
    cache_mode        = "CACHE_ALL_STATIC"
    default_ttl       = 3600
    max_ttl           = 86400
    negative_caching  = true
  }
}

# URL Map
resource "google_compute_url_map" "web" {
  name            = "web-url-map"
  default_service = google_compute_backend_service.web.id

  host_rule {
    hosts        = ["example.com"]
    path_matcher = "allpaths"
  }

  path_matcher {
    name            = "allpaths"
    default_service = google_compute_backend_service.web.id

    path_rule {
      paths   = ["/api/*"]
      service = google_compute_backend_service.api.id
    }
  }
}

# HTTPS 프록시
resource "google_compute_target_https_proxy" "web" {
  name             = "web-https-proxy"
  url_map          = google_compute_url_map.web.id
  ssl_certificates = [google_compute_ssl_certificate.web.id]
}

# Forwarding Rule
resource "google_compute_global_forwarding_rule" "web" {
  name                  = "web-forwarding-rule"
  target                = google_compute_target_https_proxy.web.id
  port_range            = "443"
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
}

# SSL Certificate (관리형)
resource "google_compute_managed_ssl_certificate" "web" {
  name = "web-ssl-cert"

  managed {
    domains = ["example.com", "www.example.com"]
  }
}
```

### 🌉 Cloud NAT

```hcl
# 📊 Cloud Router
resource "google_compute_router" "main" {
  name    = "main-router"
  network = google_compute_network.main.id
  region  = "asia-northeast3"
}

# 📊 Cloud NAT
resource "google_compute_router_nat" "main" {
  name                               = "main-nat"
  router                             = google_compute_router.main.name
  region                             = google_compute_router.main.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}
```

---

## 8. Security & IAM

### 🔐 Service Account

```hcl
# 📊 Service Account
resource "google_service_account" "app" {
  account_id   = "app-service-account"
  display_name = "Application Service Account"
  description  = "Service account for application"
}

# 📊 IAM Policy Binding
resource "google_project_iam_member" "app_storage" {
  project = var.project_id
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${google_service_account.app.email}"
}

# 📊 Service Account Key
resource "google_service_account_key" "app" {
  service_account_id = google_service_account.app.name
  public_key_type    = "TYPE_X509_PEM_FILE"
}

# 📊 커스텀 IAM Role
resource "google_project_iam_custom_role" "app_role" {
  role_id     = "appCustomRole"
  title       = "Application Custom Role"
  description = "Custom role for application"
  permissions = [
    "storage.objects.get",
    "storage.objects.list",
    "compute.instances.get",
  ]
}
```

### 🔑 Secret Manager

```hcl
# 📊 Secret
resource "google_secret_manager_secret" "db_password" {
  secret_id = "db-password"

  replication {
    automatic = true
  }

  labels = {
    environment = "production"
  }
}

# 📊 Secret Version
resource "google_secret_manager_secret_version" "db_password" {
  secret      = google_secret_manager_secret.db_password.id
  secret_data = var.db_password
}

# 📊 Secret IAM
resource "google_secret_manager_secret_iam_member" "app" {
  secret_id = google_secret_manager_secret.db_password.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.app.email}"
}
```

### 🛡️ Cloud KMS

```hcl
# 📊 Key Ring
resource "google_kms_key_ring" "main" {
  name     = "main-keyring"
  location = "asia-northeast3"
}

# 📊 Crypto Key
resource "google_kms_crypto_key" "bucket" {
  name     = "bucket-key"
  key_ring = google_kms_key_ring.main.id

  rotation_period = "7776000s"  # 90일

  lifecycle {
    prevent_destroy = true
  }
}

# 📊 KMS IAM
resource "google_kms_crypto_key_iam_member" "bucket" {
  crypto_key_id = google_kms_crypto_key.bucket.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${google_service_account.app.email}"
}
```

---

## 💡 GCP vs AWS 비교

| 서비스 | GCP | AWS |
|--------|-----|-----|
| **VM** | Compute Engine | EC2 |
| **Container** | Cloud Run, GKE | ECS, EKS |
| **Serverless** | Cloud Functions | Lambda |
| **Storage** | Cloud Storage | S3 |
| **Database** | Cloud SQL | RDS |
| **NoSQL** | Firestore | DynamoDB |
| **Load Balancer** | Cloud Load Balancing | ELB/ALB/NLB |
| **CDN** | Cloud CDN | CloudFront |
| **DNS** | Cloud DNS | Route 53 |
| **Secrets** | Secret Manager | Secrets Manager |

---

## 📚 참고 자료

### 🔗 유용한 링크
- [GCP Provider 공식 문서](https://registry.terraform.io/providers/hashicorp/google/latest/docs)
- [Google Cloud 아키텍처 센터](https://cloud.google.com/architecture)
- [Terraform GCP 모듈](https://registry.terraform.io/browse/modules?provider=google)

### 💡 GCP 특징
1. **프로젝트 기반**: AWS 계정과 달리 프로젝트 단위로 리소스 관리
2. **리전/존 구조**: region-zone 형태 (예: asia-northeast3-a)
3. **라벨 vs 태그**: GCP는 "labels", AWS는 "tags"
4. **IAM**: 서비스 계정 중심의 권한 관리
5. **무료 체험**: $300 크레딧 + 항상 무료 (Always Free) 제품

---

> Created: 2025-12-31
> Tags: #terraform #gcp #google-cloud #provider #코드스니펫
> Category: Terraform/GCP
