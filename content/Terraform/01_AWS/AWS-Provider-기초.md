---
title: Terraform AWS Provider 기초 - 핵심 리소스 코드 블럭 모음
tags:
  - terraform
  - aws
  - provider
  - 코드스니펫
  - 실무
aliases:
  - AWS테라폼
  - AWS코드블럭
date: 2025-12-31
category: Terraform/AWS
status: 완성
priority: 높음
---

# ☁️ Terraform AWS Provider 기초

> [!note] 문서 목적
> AWS에서 가장 많이 사용하는 리소스들의 Terraform 코드 블럭을 제공합니다.
> 복사-붙여넣기하여 바로 사용 가능한 **실전 스니펫 모음**입니다.

## 📑 목차
- [[#1. Provider 설정|Provider 설정]]
- [[#2. VPC & 네트워킹|VPC & 네트워킹]]
- [[#3. Compute|Compute (EC2, ASG)]]
- [[#4. Container|Container (ECS, EKS)]]
- [[#5. Database|Database]]
- [[#6. Storage|Storage]]
- [[#7. Security|Security]]
- [[#8. Load Balancing|Load Balancing]]

---

## 1. Provider 설정

### 🔧 기본 Provider 설정

```hcl
# 📊 Terraform 블럭
terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# 📊 Provider 설정 - 단일 리전
provider "aws" {
  region = "ap-northeast-2"  # 서울 리전
}
```

### 🌍 멀티 리전 설정

```hcl
# 📊 기본 리전 (서울)
provider "aws" {
  alias  = "seoul"
  region = "ap-northeast-2"
}

# 📊 보조 리전 (도쿄) - DR용
provider "aws" {
  alias  = "tokyo"
  region = "ap-northeast-1"
}

# 📊 미국 리전 (버지니아) - 글로벌 서비스용
provider "aws" {
  alias  = "us_east"
  region = "us-east-1"
}

# 사용 예시
resource "aws_instance" "seoul_web" {
  provider = aws.seoul
  # ...
}

resource "aws_instance" "tokyo_web" {
  provider = aws.tokyo
  # ...
}
```

### 🔐 자격증명 설정 방법

```hcl
# 방법 1: AWS CLI 프로필 사용 (권장)
provider "aws" {
  region  = "ap-northeast-2"
  profile = "default"  # ~/.aws/credentials의 프로필
}

# 방법 2: 환경 변수 사용
# 코드 없음, 환경 변수만 설정:
# export AWS_ACCESS_KEY_ID="..."
# export AWS_SECRET_ACCESS_KEY="..."
# export AWS_DEFAULT_REGION="ap-northeast-2"

# 방법 3: 공유 자격증명 파일 경로 지정
provider "aws" {
  region                   = "ap-northeast-2"
  shared_credentials_files = ["~/.aws/credentials"]
  profile                  = "production"
}

# 방법 4: IAM 역할 (EC2/ECS에서 실행 시)
provider "aws" {
  region = "ap-northeast-2"
  # IAM Role이 자동으로 사용됨
}
```

### 🏷️ 기본 태그 설정

```hcl
provider "aws" {
  region = "ap-northeast-2"

  # 모든 리소스에 자동으로 적용될 기본 태그
  default_tags {
    tags = {
      Environment = "Production"
      ManagedBy   = "Terraform"
      Team        = "DevOps"
      Project     = "MyProject"
      CostCenter  = "Engineering"
    }
  }
}
```

---

## 2. VPC & 네트워킹

### 🌐 VPC 생성

```hcl
# 📊 VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "main-vpc"
  }
}

# 📊 Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main-igw"
  }
}
```

### 🔀 서브넷 생성

```hcl
# 📊 퍼블릭 서브넷
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.${count.index + 1}.0/24"
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-${count.index + 1}"
    Type = "Public"
  }
}

# 📊 프라이빗 서브넷
resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index + 11}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "private-subnet-${count.index + 1}"
    Type = "Private"
  }
}

# 📊 가용 영역 데이터 소스
data "aws_availability_zones" "available" {
  state = "available"
}
```

### 🛣️ 라우트 테이블

```hcl
# 📊 퍼블릭 라우트 테이블
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "public-rt"
  }
}

# 📊 라우트 테이블 연결
resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}
```

### 🔒 보안 그룹

```hcl
# 📊 웹 서버 보안 그룹
resource "aws_security_group" "web" {
  name        = "web-sg"
  description = "Security group for web servers"
  vpc_id      = aws_vpc.main.id

  # HTTP 인바운드
  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS 인바운드
  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH 인바운드 (특정 IP만)
  ingress {
    description = "SSH from office"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["1.2.3.4/32"]  # 본인 IP로 변경
  }

  # 모든 아웃바운드
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "web-sg"
  }
}

# 📊 데이터베이스 보안 그룹
resource "aws_security_group" "database" {
  name        = "database-sg"
  description = "Security group for database"
  vpc_id      = aws_vpc.main.id

  # MySQL/MariaDB (웹 서버에서만 접근)
  ingress {
    description     = "MySQL from web servers"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]
  }

  # PostgreSQL (웹 서버에서만 접근)
  ingress {
    description     = "PostgreSQL from web servers"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "database-sg"
  }
}
```

### 🌉 NAT Gateway

```hcl
# 📊 Elastic IP for NAT Gateway
resource "aws_eip" "nat" {
  count  = 1
  domain = "vpc"

  tags = {
    Name = "nat-eip"
  }

  depends_on = [aws_internet_gateway.main]
}

# 📊 NAT Gateway
resource "aws_nat_gateway" "main" {
  count         = 1
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name = "main-nat-gw"
  }

  depends_on = [aws_internet_gateway.main]
}

# 📊 프라이빗 라우트 테이블 (NAT Gateway 사용)
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[0].id
  }

  tags = {
    Name = "private-rt"
  }
}

# 📊 프라이빗 서브넷 라우트 테이블 연결
resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}
```

---

## 3. Compute (EC2, Auto Scaling)

### 🖥️ EC2 인스턴스

```hcl
# 📊 최신 Amazon Linux 2023 AMI 조회
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# 📊 EC2 인스턴스
resource "aws_instance" "web" {
  ami           = data.aws_ami.amazon_linux_2023.id
  instance_type = "t3.micro"

  subnet_id                   = aws_subnet.public[0].id
  vpc_security_group_ids      = [aws_security_group.web.id]
  associate_public_ip_address = true

  # 키 페어
  key_name = "my-keypair"

  # 사용자 데이터 (부팅 시 실행)
  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y httpd
              systemctl start httpd
              systemctl enable httpd
              echo "<h1>Hello from Terraform!</h1>" > /var/www/html/index.html
              EOF

  # 루트 볼륨 설정
  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true
    delete_on_termination = true
  }

  # 추가 EBS 볼륨
  ebs_block_device {
    device_name = "/dev/sdf"
    volume_size = 100
    volume_type = "gp3"
    encrypted   = true
  }

  tags = {
    Name = "web-server"
    Role = "WebServer"
  }

  lifecycle {
    create_before_destroy = true
  }
}
```

### 🚀 Launch Template

```hcl
# 📊 Launch Template
resource "aws_launch_template" "web" {
  name_prefix   = "web-"
  image_id      = data.aws_ami.amazon_linux_2023.id
  instance_type = "t3.micro"

  vpc_security_group_ids = [aws_security_group.web.id]

  key_name = "my-keypair"

  user_data = base64encode(<<-EOF
              #!/bin/bash
              yum update -y
              yum install -y httpd
              systemctl start httpd
              systemctl enable httpd
              INSTANCE_ID=$(ec2-metadata --instance-id | cut -d " " -f 2)
              echo "<h1>Server: $INSTANCE_ID</h1>" > /var/www/html/index.html
              EOF
  )

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size = 20
      volume_type = "gp3"
      encrypted   = true
      delete_on_termination = true
    }
  }

  monitoring {
    enabled = true
  }

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "web-asg-instance"
    }
  }
}
```

### 📈 Auto Scaling Group

```hcl
# 📊 Auto Scaling Group
resource "aws_autoscaling_group" "web" {
  name                = "web-asg"
  desired_capacity    = 2
  min_size            = 1
  max_size            = 5
  health_check_type   = "ELB"
  health_check_grace_period = 300

  vpc_zone_identifier = aws_subnet.private[*].id
  target_group_arns   = [aws_lb_target_group.web.arn]

  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "web-asg-instance"
    propagate_at_launch = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

# 📊 Auto Scaling Policy - CPU 기반
resource "aws_autoscaling_policy" "cpu_scale_up" {
  name                   = "cpu-scale-up"
  autoscaling_group_name = aws_autoscaling_group.web.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = 1
  cooldown               = 300
}

resource "aws_autoscaling_policy" "cpu_scale_down" {
  name                   = "cpu-scale-down"
  autoscaling_group_name = aws_autoscaling_group.web.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = -1
  cooldown               = 300
}

# 📊 CloudWatch Alarm - Scale Up
resource "aws_cloudwatch_metric_alarm" "cpu_high" {
  alarm_name          = "web-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 70

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web.name
  }

  alarm_actions = [aws_autoscaling_policy.cpu_scale_up.arn]
}

# 📊 CloudWatch Alarm - Scale Down
resource "aws_cloudwatch_metric_alarm" "cpu_low" {
  alarm_name          = "web-cpu-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 30

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web.name
  }

  alarm_actions = [aws_autoscaling_policy.cpu_scale_down.arn]
}

# 📊 Auto Scaling Schedule - 업무시간 스케일링
resource "aws_autoscaling_schedule" "scale_up_morning" {
  scheduled_action_name  = "scale-up-morning"
  min_size               = 2
  max_size               = 5
  desired_capacity       = 3
  recurrence             = "0 9 * * 1-5"  # 평일 09:00
  autoscaling_group_name = aws_autoscaling_group.web.name
}

resource "aws_autoscaling_schedule" "scale_down_evening" {
  scheduled_action_name  = "scale-down-evening"
  min_size               = 1
  max_size               = 2
  desired_capacity       = 1
  recurrence             = "0 18 * * 1-5"  # 평일 18:00
  autoscaling_group_name = aws_autoscaling_group.web.name
}
```

---

## 4. Container (ECS, EKS)

### 🐳 ECS Fargate

```hcl
# 📊 ECS 클러스터
resource "aws_ecs_cluster" "main" {
  name = "main-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = "main-ecs-cluster"
  }
}

# 📊 CloudWatch Logs 그룹
resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/my-app"
  retention_in_days = 7

  tags = {
    Name = "my-app-logs"
  }
}

# 📊 ECS Task Definition
resource "aws_ecs_task_definition" "app" {
  family                   = "my-app"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name      = "my-app"
      image     = "nginx:latest"
      essential = true

      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
          protocol      = "tcp"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.app.name
          "awslogs-region"        = "ap-northeast-2"
          "awslogs-stream-prefix" = "ecs"
        }
      }

      environment = [
        {
          name  = "ENVIRONMENT"
          value = "production"
        }
      ]
    }
  ])

  tags = {
    Name = "my-app-task"
  }
}

# 📊 ECS Service
resource "aws_ecs_service" "app" {
  name            = "my-app-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = aws_subnet.private[*].id
    security_groups  = [aws_security_group.web.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.web.arn
    container_name   = "my-app"
    container_port   = 80
  }

  depends_on = [aws_lb_listener.web]
}

# 📊 ECS Execution Role
resource "aws_iam_role" "ecs_execution" {
  name = "ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# 📊 ECS Task Role
resource "aws_iam_role" "ecs_task" {
  name = "ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}
```

### ☸️ EKS 클러스터

```hcl
# 📊 EKS 클러스터 IAM Role
resource "aws_iam_role" "eks_cluster" {
  name = "eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# 📊 EKS 클러스터
resource "aws_eks_cluster" "main" {
  name     = "main-eks-cluster"
  role_arn = aws_iam_role.eks_cluster.arn
  version  = "1.28"

  vpc_config {
    subnet_ids              = concat(aws_subnet.public[*].id, aws_subnet.private[*].id)
    endpoint_private_access = true
    endpoint_public_access  = true
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy
  ]

  tags = {
    Name = "main-eks-cluster"
  }
}

# 📊 EKS Node Group IAM Role
resource "aws_iam_role" "eks_node_group" {
  name = "eks-node-group-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  role       = aws_iam_role.eks_node_group.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  role       = aws_iam_role.eks_node_group.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "eks_container_registry_policy" {
  role       = aws_iam_role.eks_node_group.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# 📊 EKS Node Group
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "main-node-group"
  node_role_arn   = aws_iam_role.eks_node_group.arn
  subnet_ids      = aws_subnet.private[*].id

  scaling_config {
    desired_size = 2
    min_size     = 1
    max_size     = 5
  }

  instance_types = ["t3.medium"]

  update_config {
    max_unavailable = 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_container_registry_policy,
  ]

  tags = {
    Name = "main-eks-node-group"
  }
}
```

---

## 5. Database

### 🗄️ RDS (MySQL/PostgreSQL)

```hcl
# 📊 RDS Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = "main-db-subnet-group"
  subnet_ids = aws_subnet.private[*].id

  tags = {
    Name = "main-db-subnet-group"
  }
}

# 📊 RDS Parameter Group
resource "aws_db_parameter_group" "mysql" {
  name   = "mysql-params"
  family = "mysql8.0"

  parameter {
    name  = "character_set_server"
    value = "utf8mb4"
  }

  parameter {
    name  = "collation_server"
    value = "utf8mb4_unicode_ci"
  }

  tags = {
    Name = "mysql-params"
  }
}

# 📊 RDS Instance
resource "aws_db_instance" "main" {
  identifier     = "main-db"
  engine         = "mysql"
  engine_version = "8.0"
  instance_class = "db.t3.micro"

  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = "myapp"
  username = "admin"
  password = var.db_password  # 변수로 관리 (절대 하드코딩 금지!)

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.database.id]
  parameter_group_name   = aws_db_parameter_group.mysql.name

  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "sun:04:00-sun:05:00"

  skip_final_snapshot       = false
  final_snapshot_identifier = "main-db-final-snapshot"

  enabled_cloudwatch_logs_exports = ["error", "general", "slowquery"]

  tags = {
    Name = "main-db"
  }
}

# 📊 RDS Read Replica
resource "aws_db_instance" "replica" {
  identifier     = "main-db-replica"
  replicate_source_db = aws_db_instance.main.identifier
  instance_class = "db.t3.micro"

  skip_final_snapshot = true

  tags = {
    Name = "main-db-replica"
  }
}
```

### ⚡ DynamoDB

```hcl
# 📊 DynamoDB 테이블
resource "aws_dynamodb_table" "users" {
  name           = "users"
  billing_mode   = "PAY_PER_REQUEST"  # 또는 "PROVISIONED"
  hash_key       = "user_id"
  range_key      = "timestamp"

  attribute {
    name = "user_id"
    type = "S"  # String
  }

  attribute {
    name = "timestamp"
    type = "N"  # Number
  }

  attribute {
    name = "email"
    type = "S"
  }

  # Global Secondary Index
  global_secondary_index {
    name            = "EmailIndex"
    hash_key        = "email"
    projection_type = "ALL"
  }

  # Point-in-time Recovery
  point_in_time_recovery {
    enabled = true
  }

  # 서버 측 암호화
  server_side_encryption {
    enabled = true
  }

  # Time to Live
  ttl {
    attribute_name = "expiration_time"
    enabled        = true
  }

  tags = {
    Name = "users-table"
  }
}

# 📊 DynamoDB 테이블 (Provisioned 모드)
resource "aws_dynamodb_table" "sessions" {
  name           = "sessions"
  billing_mode   = "PROVISIONED"
  read_capacity  = 5
  write_capacity = 5
  hash_key       = "session_id"

  attribute {
    name = "session_id"
    type = "S"
  }

  # Auto Scaling
  tags = {
    Name = "sessions-table"
  }
}

# 📊 DynamoDB Auto Scaling - Read
resource "aws_appautoscaling_target" "dynamodb_read" {
  max_capacity       = 100
  min_capacity       = 5
  resource_id        = "table/${aws_dynamodb_table.sessions.name}"
  scalable_dimension = "dynamodb:table:ReadCapacityUnits"
  service_namespace  = "dynamodb"
}

resource "aws_appautoscaling_policy" "dynamodb_read_policy" {
  name               = "DynamoDBReadCapacityUtilization:${aws_appautoscaling_target.dynamodb_read.resource_id}"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.dynamodb_read.resource_id
  scalable_dimension = aws_appautoscaling_target.dynamodb_read.scalable_dimension
  service_namespace  = aws_appautoscaling_target.dynamodb_read.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "DynamoDBReadCapacityUtilization"
    }
    target_value = 70.0
  }
}
```

---

## 6. Storage

### 🪣 S3 버킷

```hcl
# 📊 S3 버킷
resource "aws_s3_bucket" "main" {
  bucket = "my-unique-bucket-name-12345"

  tags = {
    Name = "main-bucket"
  }
}

# 📊 S3 버킷 버저닝
resource "aws_s3_bucket_versioning" "main" {
  bucket = aws_s3_bucket.main.id

  versioning_configuration {
    status = "Enabled"
  }
}

# 📊 S3 버킷 암호화
resource "aws_s3_bucket_server_side_encryption_configuration" "main" {
  bucket = aws_s3_bucket.main.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
      # 또는 KMS 사용
      # sse_algorithm     = "aws:kms"
      # kms_master_key_id = aws_kms_key.s3.arn
    }
  }
}

# 📊 S3 버킷 퍼블릭 액세스 차단
resource "aws_s3_bucket_public_access_block" "main" {
  bucket = aws_s3_bucket.main.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# 📊 S3 버킷 라이프사이클
resource "aws_s3_bucket_lifecycle_configuration" "main" {
  bucket = aws_s3_bucket.main.id

  rule {
    id     = "archive-old-versions"
    status = "Enabled"

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "GLACIER"
    }

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }

  rule {
    id     = "delete-old-logs"
    status = "Enabled"

    filter {
      prefix = "logs/"
    }

    expiration {
      days = 30
    }
  }
}

# 📊 S3 버킷 정적 웹사이트 호스팅
resource "aws_s3_bucket_website_configuration" "main" {
  bucket = aws_s3_bucket.main.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}
```

---

## 7. Security

### 🔐 IAM 역할 및 정책

```hcl
# 📊 IAM 역할
resource "aws_iam_role" "app" {
  name = "app-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "app-role"
  }
}

# 📊 IAM 정책
resource "aws_iam_policy" "s3_read" {
  name        = "s3-read-policy"
  description = "Policy for S3 read access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.main.arn,
          "${aws_s3_bucket.main.arn}/*"
        ]
      }
    ]
  })
}

# 📊 정책 연결
resource "aws_iam_role_policy_attachment" "app_s3" {
  role       = aws_iam_role.app.name
  policy_arn = aws_iam_policy.s3_read.arn
}

# 📊 Instance Profile
resource "aws_iam_instance_profile" "app" {
  name = "app-instance-profile"
  role = aws_iam_role.app.name
}
```

### 🔑 KMS 키

```hcl
# 📊 KMS 키
resource "aws_kms_key" "main" {
  description             = "KMS key for encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  tags = {
    Name = "main-kms-key"
  }
}

# 📊 KMS 별칭
resource "aws_kms_alias" "main" {
  name          = "alias/main-key"
  target_key_id = aws_kms_key.main.key_id
}
```

---

## 8. Load Balancing

### ⚖️ Application Load Balancer

```hcl
# 📊 ALB
resource "aws_lb" "main" {
  name               = "main-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id

  enable_deletion_protection = false
  enable_http2              = true

  tags = {
    Name = "main-alb"
  }
}

# 📊 ALB 보안 그룹
resource "aws_security_group" "alb" {
  name        = "alb-sg"
  description = "Security group for ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "alb-sg"
  }
}

# 📊 타겟 그룹
resource "aws_lb_target_group" "web" {
  name     = "web-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/health"
    matcher             = "200"
  }

  stickiness {
    type            = "lb_cookie"
    cookie_duration = 86400
    enabled         = true
  }

  tags = {
    Name = "web-tg"
  }
}

# 📊 ALB 리스너 (HTTP)
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# 📊 ALB 리스너 (HTTPS)
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate.main.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

# 📊 리스너 규칙 (경로 기반 라우팅)
resource "aws_lb_listener_rule" "api" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }

  condition {
    path_pattern {
      values = ["/api/*"]
    }
  }
}
```

### 🔗 Network Load Balancer

```hcl
# 📊 NLB
resource "aws_lb" "nlb" {
  name               = "main-nlb"
  internal           = false
  load_balancer_type = "network"
  subnets            = aws_subnet.public[*].id

  enable_deletion_protection       = false
  enable_cross_zone_load_balancing = true

  tags = {
    Name = "main-nlb"
  }
}

# 📊 NLB 타겟 그룹
resource "aws_lb_target_group" "nlb_tg" {
  name     = "nlb-tg"
  port     = 80
  protocol = "TCP"
  vpc_id   = aws_vpc.main.id

  health_check {
    enabled  = true
    protocol = "TCP"
    interval = 30
  }

  tags = {
    Name = "nlb-tg"
  }
}

# 📊 NLB 리스너
resource "aws_lb_listener" "nlb" {
  load_balancer_arn = aws_lb.nlb.arn
  port              = "80"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nlb_tg.arn
  }
}
```

---

## 📚 참고 자료

### 🔗 유용한 링크
- [AWS Provider 공식 문서](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS 아키텍처 센터](https://aws.amazon.com/architecture/)
- [Terraform AWS 모듈](https://registry.terraform.io/browse/modules?provider=aws)

### 💡 베스트 프랙티스
1. **민감 정보 관리**: 비밀번호는 변수로, AWS Secrets Manager 사용
2. **태그 전략**: 모든 리소스에 일관된 태그 적용
3. **리소스 명명**: 환경-서비스-리소스타입 형식 사용 (예: prod-web-alb)
4. **State 관리**: S3 원격 백엔드 + DynamoDB 잠금 사용
5. **모듈화**: 재사용 가능한 코드는 모듈로 분리

---

> Created: 2025-12-31
> Tags: #terraform #aws #provider #코드스니펫
> Category: Terraform/AWS
