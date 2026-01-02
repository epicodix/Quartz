---
title: Terraform Azure Provider 기초 - Azure 핵심 리소스 코드 블럭
tags:
  - terraform
  - azure
  - microsoft
  - provider
  - 코드스니펫
aliases:
  - Azure테라폼
  - Azure코드블럭
date: 2025-12-31
category: Terraform/Azure
status: 완성
priority: 높음
---

# ☁️ Terraform Azure Provider 기초

> [!note] 문서 목적
> Microsoft Azure에서 가장 많이 사용하는 리소스들의 Terraform 코드 블럭을 제공합니다.
> 복사-붙여넣기하여 바로 사용 가능한 **실전 스니펫 모음**입니다.

## 📑 목차
- [[#1. Provider 설정|Provider 설정]]
- [[#2. Virtual Machines|Virtual Machines]]
- [[#3. Azure Kubernetes Service|AKS]]
- [[#4. Container|Container Instances]]
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
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

# 📊 Provider 설정
provider "azurerm" {
  features {}
}
```

### 🔐 자격증명 설정

```hcl
# 방법 1: Azure CLI 인증 (권장 - 로컬 개발)
# az login
provider "azurerm" {
  features {}
}

# 방법 2: 서비스 프린시pal (CI/CD)
provider "azurerm" {
  features {}

  subscription_id = var.subscription_id
  client_id       = var.client_id
  client_secret   = var.client_secret
  tenant_id       = var.tenant_id
}

# 방법 3: 환경 변수 사용
# export ARM_SUBSCRIPTION_ID="..."
# export ARM_CLIENT_ID="..."
# export ARM_CLIENT_SECRET="..."
# export ARM_TENANT_ID="..."
provider "azurerm" {
  features {}
}
```

### 🌍 멀티 Subscription 설정

```hcl
# 📊 프로덕션 Subscription
provider "azurerm" {
  alias           = "prod"
  subscription_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
  features {}
}

# 📊 개발 Subscription
provider "azurerm" {
  alias           = "dev"
  subscription_id = "yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy"
  features {}
}

# 사용 예시
resource "azurerm_resource_group" "prod_rg" {
  provider = azurerm.prod
  name     = "prod-resources"
  location = "Korea Central"
}
```

---

## 2. Virtual Machines

### 📦 Resource Group (필수!)

```hcl
# 📊 Resource Group (Azure의 모든 리소스는 RG 안에 생성)
resource "azurerm_resource_group" "main" {
  name     = "main-resources"
  location = "Korea Central"  # 한국 중부 리전

  tags = {
    environment = "production"
    managed_by  = "terraform"
  }
}
```

### 🖥️ Linux Virtual Machine

```hcl
# 📊 Virtual Network (네트워크 인터페이스 생성 전 필요)
resource "azurerm_virtual_network" "main" {
  name                = "main-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

# 📊 Subnet
resource "azurerm_subnet" "main" {
  name                 = "main-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]
}

# 📊 Network Interface
resource "azurerm_network_interface" "main" {
  name                = "main-nic"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.main.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.main.id
  }
}

# 📊 Public IP
resource "azurerm_public_ip" "main" {
  name                = "main-pip"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# 📊 Linux Virtual Machine
resource "azurerm_linux_virtual_machine" "main" {
  name                = "main-vm"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  size                = "Standard_B1s"  # 가장 저렴한 옵션
  admin_username      = "azureuser"

  network_interface_ids = [
    azurerm_network_interface.main.id,
  ]

  # SSH 키 인증
  admin_ssh_key {
    username   = "azureuser"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  # OS 디스크
  os_disk {
    name                 = "main-osdisk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 30
  }

  # 이미지
  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  # 커스텀 데이터 (부팅 스크립트)
  custom_data = base64encode(<<-EOF
    #!/bin/bash
    apt-get update
    apt-get install -y nginx
    systemctl start nginx
    echo "<h1>Hello from Terraform!</h1>" > /var/www/html/index.html
  EOF
  )

  tags = {
    environment = "production"
  }
}

# 📊 데이터 디스크
resource "azurerm_managed_disk" "data" {
  name                 = "main-datadisk"
  location             = azurerm_resource_group.main.location
  resource_group_name  = azurerm_resource_group.main.name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = 100
}

resource "azurerm_virtual_machine_data_disk_attachment" "main" {
  managed_disk_id    = azurerm_managed_disk.data.id
  virtual_machine_id = azurerm_linux_virtual_machine.main.id
  lun                = 0
  caching            = "ReadWrite"
}
```

### 📈 Virtual Machine Scale Set

```hcl
# 📊 Load Balancer
resource "azurerm_lb" "main" {
  name                = "main-lb"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.lb.id
  }
}

resource "azurerm_public_ip" "lb" {
  name                = "lb-pip"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_lb_backend_address_pool" "main" {
  loadbalancer_id = azurerm_lb.main.id
  name            = "BackEndAddressPool"
}

resource "azurerm_lb_probe" "main" {
  loadbalancer_id = azurerm_lb.main.id
  name            = "http-probe"
  port            = 80
  protocol        = "Http"
  request_path    = "/"
}

resource "azurerm_lb_rule" "main" {
  loadbalancer_id                = azurerm_lb.main.id
  name                           = "LBRule"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "PublicIPAddress"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.main.id]
  probe_id                       = azurerm_lb_probe.main.id
}

# 📊 VM Scale Set
resource "azurerm_linux_virtual_machine_scale_set" "main" {
  name                = "main-vmss"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Standard_B1s"
  instances           = 2
  admin_username      = "azureuser"

  admin_ssh_key {
    username   = "azureuser"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }

  network_interface {
    name    = "main-nic"
    primary = true

    ip_configuration {
      name      = "internal"
      primary   = true
      subnet_id = azurerm_subnet.main.id

      load_balancer_backend_address_pool_ids = [
        azurerm_lb_backend_address_pool.main.id
      ]
    }
  }

  custom_data = base64encode(<<-EOF
    #!/bin/bash
    apt-get update
    apt-get install -y nginx
    HOSTNAME=$(hostname)
    echo "<h1>Server: $HOSTNAME</h1>" > /var/www/html/index.html
    systemctl start nginx
  EOF
  )
}

# 📊 Autoscale Settings
resource "azurerm_monitor_autoscale_setting" "main" {
  name                = "autoscale-config"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  target_resource_id  = azurerm_linux_virtual_machine_scale_set.main.id

  profile {
    name = "defaultProfile"

    capacity {
      default = 2
      minimum = 1
      maximum = 10
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.main.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 70
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT1M"
      }
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.main.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 30
      }

      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT1M"
      }
    }
  }
}
```

---

## 3. Azure Kubernetes Service (AKS)

### ☸️ AKS 클러스터

```hcl
# 📊 AKS 클러스터
resource "azurerm_kubernetes_cluster" "main" {
  name                = "main-aks"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = "mainaks"
  kubernetes_version  = "1.28"

  # 기본 노드 풀
  default_node_pool {
    name                = "default"
    node_count          = 2
    vm_size             = "Standard_B2s"
    os_disk_size_gb     = 30
    vnet_subnet_id      = azurerm_subnet.aks.id
    enable_auto_scaling = true
    min_count           = 1
    max_count           = 5

    upgrade_settings {
      max_surge = "10%"
    }
  }

  # Identity
  identity {
    type = "SystemAssigned"
  }

  # Network Profile
  network_profile {
    network_plugin    = "azure"
    load_balancer_sku = "standard"
    service_cidr      = "10.1.0.0/16"
    dns_service_ip    = "10.1.0.10"
  }

  # Azure AD RBAC
  azure_active_directory_role_based_access_control {
    managed                = true
    azure_rbac_enabled     = true
    admin_group_object_ids = [var.admin_group_id]
  }

  # 애드온
  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  }

  # HTTP Application Routing (비권장 - Ingress Controller 사용 권장)
  http_application_routing_enabled = false

  tags = {
    environment = "production"
  }
}

# 📊 추가 노드 풀
resource "azurerm_kubernetes_cluster_node_pool" "gpu" {
  name                  = "gpu"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.main.id
  vm_size               = "Standard_NC6"
  node_count            = 1

  enable_auto_scaling = true
  min_count           = 0
  max_count           = 3

  node_labels = {
    "workload" = "gpu"
  }

  node_taints = [
    "gpu=true:NoSchedule"
  ]
}

# 📊 Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "main" {
  name                = "main-workspace"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}
```

---

## 4. Container Instances

### 🐳 Azure Container Instances

```hcl
# 📊 Container Group
resource "azurerm_container_group" "main" {
  name                = "main-container-group"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  os_type             = "Linux"
  dns_name_label      = "myapp-${random_string.suffix.result}"
  ip_address_type     = "Public"

  container {
    name   = "myapp"
    image  = "nginx:latest"
    cpu    = "0.5"
    memory = "1.0"

    ports {
      port     = 80
      protocol = "TCP"
    }

    environment_variables = {
      "ENVIRONMENT" = "production"
    }

    secure_environment_variables = {
      "API_KEY" = var.api_key
    }

    volume {
      name       = "logs"
      mount_path = "/var/log"
      read_only  = false
      share_name = azurerm_storage_share.logs.name
      storage_account_name = azurerm_storage_account.main.name
      storage_account_key  = azurerm_storage_account.main.primary_access_key
    }
  }

  tags = {
    environment = "production"
  }
}

resource "random_string" "suffix" {
  length  = 8
  special = false
  upper   = false
}
```

---

## 5. Database

### 🗄️ Azure SQL Database

```hcl
# 📊 SQL Server
resource "azurerm_mssql_server" "main" {
  name                         = "main-sqlserver"
  resource_group_name          = azurerm_resource_group.main.name
  location                     = azurerm_resource_group.main.location
  version                      = "12.0"
  administrator_login          = "sqladmin"
  administrator_login_password = var.sql_admin_password

  minimum_tls_version = "1.2"

  azuread_administrator {
    login_username = var.aad_admin_login
    object_id      = var.aad_admin_object_id
  }

  tags = {
    environment = "production"
  }
}

# 📊 SQL Database
resource "azurerm_mssql_database" "main" {
  name           = "main-db"
  server_id      = azurerm_mssql_server.main.id
  collation      = "SQL_Latin1_General_CP1_CI_AS"
  license_type   = "LicenseIncluded"
  max_size_gb    = 2
  sku_name       = "S0"  # Standard, 10 DTU
  zone_redundant = false

  # 자동 백업
  short_term_retention_policy {
    retention_days = 7
  }

  long_term_retention_policy {
    weekly_retention  = "P4W"
    monthly_retention = "P12M"
    yearly_retention  = "P5Y"
    week_of_year      = 1
  }

  tags = {
    environment = "production"
  }
}

# 📊 방화벽 규칙
resource "azurerm_mssql_firewall_rule" "allow_azure" {
  name             = "AllowAzureServices"
  server_id        = azurerm_mssql_server.main.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

resource "azurerm_mssql_firewall_rule" "office" {
  name             = "AllowOffice"
  server_id        = azurerm_mssql_server.main.id
  start_ip_address = "1.2.3.4"
  end_ip_address   = "1.2.3.4"
}
```

### 🌍 Cosmos DB

```hcl
# 📊 Cosmos DB Account
resource "azurerm_cosmosdb_account" "main" {
  name                = "main-cosmos"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"

  consistency_policy {
    consistency_level       = "Session"
    max_interval_in_seconds = 5
    max_staleness_prefix    = 100
  }

  geo_location {
    location          = azurerm_resource_group.main.location
    failover_priority = 0
  }

  geo_location {
    location          = "Japan East"
    failover_priority = 1
  }

  capabilities {
    name = "EnableServerless"
  }
}

# 📊 Cosmos DB SQL Database
resource "azurerm_cosmosdb_sql_database" "main" {
  name                = "myapp"
  resource_group_name = azurerm_cosmosdb_account.main.resource_group_name
  account_name        = azurerm_cosmosdb_account.main.name
}

# 📊 Cosmos DB Container
resource "azurerm_cosmosdb_sql_container" "users" {
  name                = "users"
  resource_group_name = azurerm_cosmosdb_account.main.resource_group_name
  account_name        = azurerm_cosmosdb_account.main.name
  database_name       = azurerm_cosmosdb_sql_database.main.name
  partition_key_path  = "/userId"

  indexing_policy {
    indexing_mode = "consistent"

    included_path {
      path = "/*"
    }

    excluded_path {
      path = "/\"_etag\"/?"
    }
  }
}
```

---

## 6. Storage

### 🪣 Blob Storage

```hcl
# 📊 Storage Account
resource "azurerm_storage_account" "main" {
  name                     = "mainstorage${random_string.storage.result}"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"  # GRS, RAGRS, ZRS
  account_kind             = "StorageV2"
  access_tier              = "Hot"

  # 보안
  min_tls_version                 = "TLS1_2"
  enable_https_traffic_only       = true
  allow_nested_items_to_be_public = false

  # Blob 속성
  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      days = 7
    }

    container_delete_retention_policy {
      days = 7
    }
  }

  # 네트워크 규칙
  network_rules {
    default_action             = "Deny"
    bypass                     = ["AzureServices"]
    ip_rules                   = ["1.2.3.4"]
    virtual_network_subnet_ids = [azurerm_subnet.main.id]
  }

  tags = {
    environment = "production"
  }
}

resource "random_string" "storage" {
  length  = 8
  special = false
  upper   = false
}

# 📊 Blob Container
resource "azurerm_storage_container" "main" {
  name                  = "content"
  storage_account_name  = azurerm_storage_account.main.name
  container_access_type = "private"
}

# 📊 파일 업로드
resource "azurerm_storage_blob" "example" {
  name                   = "index.html"
  storage_account_name   = azurerm_storage_account.main.name
  storage_container_name = azurerm_storage_container.main.name
  type                   = "Block"
  source                 = "index.html"
}

# 📊 Lifecycle Management
resource "azurerm_storage_management_policy" "main" {
  storage_account_id = azurerm_storage_account.main.id

  rule {
    name    = "archive-old-data"
    enabled = true

    filters {
      prefix_match = ["logs/"]
      blob_types   = ["blockBlob"]
    }

    actions {
      base_blob {
        tier_to_cool_after_days_since_modification_greater_than    = 30
        tier_to_archive_after_days_since_modification_greater_than = 90
        delete_after_days_since_modification_greater_than          = 365
      }

      snapshot {
        delete_after_days_since_creation_greater_than = 90
      }
    }
  }
}
```

---

## 7. Networking

### 🌐 Virtual Network & Subnet

```hcl
# 📊 Virtual Network
resource "azurerm_virtual_network" "main" {
  name                = "main-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  tags = {
    environment = "production"
  }
}

# 📊 Subnets
resource "azurerm_subnet" "public" {
  name                 = "public-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_subnet" "private" {
  name                 = "private-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.2.0/24"]

  service_endpoints = ["Microsoft.Sql", "Microsoft.Storage"]
}

resource "azurerm_subnet" "aks" {
  name                 = "aks-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.10.0/24"]
}
```

### 🔒 Network Security Group

```hcl
# 📊 NSG
resource "azurerm_network_security_group" "web" {
  name                = "web-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  # HTTP
  security_rule {
    name                       = "AllowHTTP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # HTTPS
  security_rule {
    name                       = "AllowHTTPS"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # SSH (특정 IP만)
  security_rule {
    name                       = "AllowSSH"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "1.2.3.4/32"
    destination_address_prefix = "*"
  }

  tags = {
    environment = "production"
  }
}

# 📊 NSG Association
resource "azurerm_subnet_network_security_group_association" "web" {
  subnet_id                 = azurerm_subnet.public.id
  network_security_group_id = azurerm_network_security_group.web.id
}
```

### ⚖️ Application Gateway

```hcl
# 📊 Public IP for App Gateway
resource "azurerm_public_ip" "appgw" {
  name                = "appgw-pip"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

# 📊 Application Gateway
resource "azurerm_application_gateway" "main" {
  name                = "main-appgw"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 2
  }

  gateway_ip_configuration {
    name      = "gateway-ip-config"
    subnet_id = azurerm_subnet.appgw.id
  }

  frontend_port {
    name = "http-port"
    port = 80
  }

  frontend_ip_configuration {
    name                 = "frontend-ip-config"
    public_ip_address_id = azurerm_public_ip.appgw.id
  }

  backend_address_pool {
    name = "backend-pool"
  }

  backend_http_settings {
    name                  = "http-settings"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 60
  }

  http_listener {
    name                           = "http-listener"
    frontend_ip_configuration_name = "frontend-ip-config"
    frontend_port_name             = "http-port"
    protocol                       = "Http"
  }

  request_routing_rule {
    name                       = "routing-rule"
    rule_type                  = "Basic"
    http_listener_name         = "http-listener"
    backend_address_pool_name  = "backend-pool"
    backend_http_settings_name = "http-settings"
    priority                   = 100
  }

  tags = {
    environment = "production"
  }
}

resource "azurerm_subnet" "appgw" {
  name                 = "appgw-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.3.0/24"]
}
```

---

## 8. Security & IAM

### 🔐 Role Assignment

```hcl
# 📊 현재 클라이언트 정보 조회
data "azurerm_client_config" "current" {}

# 📊 Role Assignment - Storage Blob Data Contributor
resource "azurerm_role_assignment" "storage" {
  scope                = azurerm_storage_account.main.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}

# 📊 Role Assignment - AKS Cluster Admin
resource "azurerm_role_assignment" "aks_admin" {
  scope                = azurerm_kubernetes_cluster.main.id
  role_definition_name = "Azure Kubernetes Service Cluster Admin Role"
  principal_id         = var.admin_group_id
}
```

### 🔑 Key Vault

```hcl
# 📊 Key Vault
resource "azurerm_key_vault" "main" {
  name                       = "main-kv-${random_string.kv.result}"
  location                   = azurerm_resource_group.main.location
  resource_group_name        = azurerm_resource_group.main.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 7
  purge_protection_enabled   = true

  network_acls {
    bypass         = "AzureServices"
    default_action = "Deny"
    ip_rules       = ["1.2.3.4"]
  }

  tags = {
    environment = "production"
  }
}

resource "random_string" "kv" {
  length  = 8
  special = false
  upper   = false
}

# 📊 Key Vault Access Policy
resource "azurerm_key_vault_access_policy" "main" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  secret_permissions = [
    "Get", "List", "Set", "Delete", "Purge"
  ]

  key_permissions = [
    "Get", "List", "Create", "Delete"
  ]

  certificate_permissions = [
    "Get", "List", "Create", "Delete"
  ]
}

# 📊 Key Vault Secret
resource "azurerm_key_vault_secret" "db_password" {
  name         = "db-password"
  value        = var.db_password
  key_vault_id = azurerm_key_vault.main.id

  depends_on = [azurerm_key_vault_access_policy.main]
}
```

---

## 💡 Azure 특징 & 베스트 프랙티스

### 🎯 Azure 고유 개념

1. **Resource Group**: 모든 리소스는 반드시 RG에 속함 (AWS/GCP와 다름)
2. **Location**: 리전 이름이 문자열 (예: "Korea Central", "East US")
3. **Tags vs Labels**: Azure는 "tags" 사용
4. **Naming Convention**: 많은 리소스가 전역 고유 이름 필요 (Storage Account 등)

### 📋 클라우드 비교

| 서비스 | Azure | AWS | GCP |
|--------|-------|-----|-----|
| **VM** | Virtual Machines | EC2 | Compute Engine |
| **Container** | ACI, AKS | ECS, EKS | Cloud Run, GKE |
| **Storage** | Blob Storage | S3 | Cloud Storage |
| **Database** | Azure SQL | RDS | Cloud SQL |
| **NoSQL** | Cosmos DB | DynamoDB | Firestore |
| **Load Balancer** | App Gateway, Load Balancer | ALB, NLB | Cloud Load Balancing |

### 💡 베스트 프랙티스

1. **리소스 그룹 전략**: 환경별, 애플리케이션별로 RG 분리
2. **명명 규칙**: `<project>-<env>-<resource>` (예: myapp-prod-vm)
3. **태그 전략**: environment, cost-center, owner 등 일관된 태그
4. **보안**: NSG + Service Endpoints + Private Link 조합
5. **비용 관리**: Budget Alert 설정, Reserved Instances 활용

---

## 📚 참고 자료

### 🔗 유용한 링크
- [Azure Provider 공식 문서](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Azure 아키텍처 센터](https://docs.microsoft.com/azure/architecture/)
- [Terraform Azure 모듈](https://registry.terraform.io/browse/modules?provider=azurerm)

---

> Created: 2025-12-31
> Tags: #terraform #azure #microsoft #provider #코드스니펫
> Category: Terraform/Azure
