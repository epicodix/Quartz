---
title: ALB + 3-Tier 아키텍처 구축 가이드
tags:
  - terraform
  - aws
  - alb
  - 3-tier
  - nat-gateway
  - devops
  - infrastructure
aliases:
  - ALB-가이드
  - 3tier-아키텍처
date: 2026-01-27
category: Terraform/01_AWS
status: 완성
priority: 높음
---

# 🎯 ALB + 3-Tier 아키텍처 구축 가이드

## 📑 목차
- [[#1. 전체 Resource Map|Resource Map]]
- [[#2. 아키텍처 설명|아키텍처 설명]]
- [[#3. ALB 핵심 개념|ALB 핵심 개념]]
- [[#4. NAT Gateway 활성화|NAT Gateway]]
- [[#5. 구현 상세|구현 상세]]
- [[#6. 검증 및 트러블슈팅|검증 및 트러블슈팅]]
- [[#7. 비용 관리|비용 관리]]
- [[#🎯 핵심 정리|핵심 정리]]

---

## 1. 전체 Resource Map

### 📋 인프라 전체 조감도 (2026-01-27 실측)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  AWS Account: 317250221510  │  Region: ap-northeast-2 (서울)               │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐     │
│  │  VPC: vpc-0478120058493042f  (10.0.0.0/16)                         │     │
│  │  ┌───────────────────────────────────────┐                         │     │
│  │  │        IGW: igw-0e396e1d3dc9e5ce7     │                         │     │
│  │  └──────────────────┬────────────────────┘                         │     │
│  │                     │                                               │     │
│  │    ┌────────────────┼──── Public Subnets ────────────────┐         │     │
│  │    │                │                                     │         │     │
│  │    │  ┌─────────────┴──────────────────────────────────┐  │         │     │
│  │    │  │  ALB: my-infra-alb                             │  │         │     │
│  │    │  │  DNS: my-infra-alb-850810618.ap-northeast-2    │  │         │     │
│  │    │  │       .elb.amazonaws.com                       │  │         │     │
│  │    │  │  SG: web-sg (HTTP 80, HTTPS 443)               │  │         │     │
│  │    │  │  Listener: HTTP:80 → TG:3000                   │  │         │     │
│  │    │  └────────────────────────────────────────────────┘  │         │     │
│  │    │                                                      │         │     │
│  │    │  ┌──────────────────────┐ ┌───────────────────────┐  │         │     │
│  │    │  │ Public Subnet 2a     │ │ Public Subnet 2c      │  │         │     │
│  │    │  │ 10.0.1.0/24          │ │ 10.0.2.0/24           │  │         │     │
│  │    │  │ subnet-0ff84de...    │ │ subnet-0138ca8...     │  │         │     │
│  │    │  │                      │ │                       │  │         │     │
│  │    │  │ ┌──────────────────┐ │ │                       │  │         │     │
│  │    │  │ │ Bastion EC2      │ │ │                       │  │         │     │
│  │    │  │ │ i-05da54ea...    │ │ │                       │  │         │     │
│  │    │  │ │ t4g.micro        │ │ │                       │  │         │     │
│  │    │  │ │ EIP: 43.201.     │ │ │                       │  │         │     │
│  │    │  │ │   127.140        │ │ │                       │  │         │     │
│  │    │  │ │ SG: bastion-sg   │ │ │                       │  │         │     │
│  │    │  │ └──────────────────┘ │ │                       │  │         │     │
│  │    │  │                      │ │                       │  │         │     │
│  │    │  │ ┌──────────────────┐ │ │                       │  │         │     │
│  │    │  │ │ NAT GW           │ │ │                       │  │         │     │
│  │    │  │ │ nat-05f73970...  │ │ │                       │  │         │     │
│  │    │  │ │ EIP: 52.79.     │ │ │                       │  │         │     │
│  │    │  │ │   182.147        │ │ │                       │  │         │     │
│  │    │  │ └──────────────────┘ │ │                       │  │         │     │
│  │    │  └──────────────────────┘ └───────────────────────┘  │         │     │
│  │    └──────────────────────────────────────────────────────┘         │     │
│  │                     │                                               │     │
│  │                     │  ALB → TG (port 3000)                        │     │
│  │                     ▼                                               │     │
│  │    ┌──────────────────────────────────────────────────────┐         │     │
│  │    │               Private Subnets                        │         │     │
│  │    │  ┌──────────────────────┐ ┌───────────────────────┐  │         │     │
│  │    │  │ Private Subnet 2a    │ │ Private Subnet 2c     │  │         │     │
│  │    │  │ 10.0.10.0/24         │ │ 10.0.20.0/24          │  │         │     │
│  │    │  │ subnet-01f4a80...    │ │ subnet-01c133e...     │  │         │     │
│  │    │  │                      │ │                       │  │         │     │
│  │    │  │ ┌──────────────────┐ │ │                       │  │         │     │
│  │    │  │ │ App EC2           │ │ │                       │  │         │     │
│  │    │  │ │ i-0241c8ae...    │ │ │                       │  │         │     │
│  │    │  │ │ t4g.micro        │ │ │                       │  │         │     │
│  │    │  │ │ IP: 10.0.10.222  │ │ │                       │  │         │     │
│  │    │  │ │ SG: app-sg       │ │ │                       │  │         │     │
│  │    │  │ │ Port: 3000       │ │ │                       │  │         │     │
│  │    │  │ └──────────────────┘ │ │                       │  │         │     │
│  │    │  └──────────────────────┘ └───────────────────────┘  │         │     │
│  │    └──────────────────────────────────────────────────────┘         │     │
│  └─────────────────────────────────────────────────────────────────────┘     │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 📊 Terraform Resource 전체 목록 (28개 + data 2개)

| 모듈 | 리소스 | ID / 값 |
|------|--------|---------|
| **module.vpc** | `aws_vpc.main` | `vpc-0478120058493042f` |
| | `aws_internet_gateway.main` | `igw-0e396e1d3dc9e5ce7` |
| | `aws_subnet.public[0]` (2a) | `subnet-0ff84debf6fe53415` |
| | `aws_subnet.public[1]` (2c) | `subnet-0138ca83fcd097139` |
| | `aws_subnet.private[0]` (2a) | `subnet-01f4a80425fc72638` |
| | `aws_subnet.private[1]` (2c) | `subnet-01c133eda1153ebf4` |
| | `aws_eip.nat[0]` | `52.79.182.147` |
| | `aws_nat_gateway.main[0]` | `nat-05f739703e915dd06` |
| | `aws_route.private_nat[0]` | `0.0.0.0/0 → NAT GW` |
| | `aws_route_table.public` | `rtb-018cb57a491d8d106` |
| | `aws_route_table.private` | `rtb-01795530294738e00` |
| | `aws_route_table_association.*` (x4) | Subnet ↔ RT 연결 |
| **module.security** | `aws_security_group.bastion` | `sg-0d1b005ffc71994d0` |
| | `aws_security_group.web` | `sg-0142f8aab69939014` |
| | `aws_security_group.app` | `sg-0c633ad0d959fa6db` |
| | `aws_security_group.db` | `sg-0249082dc97ba0367` |
| **module.ec2** | `aws_key_pair.main` | `my-infra-key` |
| | `aws_instance.bastion` | `i-05da54eaec43bb6a8` |
| | `aws_eip.bastion` | `43.201.127.140` |
| | `aws_eip_association.bastion` | EIP ↔ Bastion 연결 |
| **module.app** | `aws_instance.app` | `i-0241c8aea037d1cc0` |
| **module.alb** | `aws_lb.main` | `my-infra-alb` |
| | `aws_lb_target_group.app` | `my-infra-app-tg` (port 3000) |
| | `aws_lb_listener.http` | HTTP:80 → TG forward |
| | `aws_lb_target_group_attachment.app` | App EC2 → TG 등록 |

### 📋 Security Group 체이닝 상세

```
┌──────────────────────────────────────────────────────────────────────┐
│  SG 체이닝 흐름 (실무형 계층 보안)                                   │
│                                                                      │
│  Internet                                                            │
│     │                                                                │
│     ▼                                                                │
│  ┌─────────────────────────────────────────────┐                     │
│  │  bastion-sg (sg-0d1b00...)                  │                     │
│  │  IN:  SSH(22) ← 0.0.0.0/0                  │                     │
│  │  OUT: ALL ← 0.0.0.0/0                      │                     │
│  └──────────────────────┬──────────────────────┘                     │
│                         │ SSH(22)                                    │
│     ▼                   ▼                                            │
│  ┌─────────────────────────────────────────────┐                     │
│  │  web-sg (sg-0142f8...)  ← ALB가 사용        │                     │
│  │  IN:  HTTP(80)  ← 0.0.0.0/0                │                     │
│  │  IN:  HTTPS(443) ← 0.0.0.0/0               │                     │
│  │  OUT: ALL ← 0.0.0.0/0                      │                     │
│  └──────────────────────┬──────────────────────┘                     │
│                         │ port 3000                                  │
│                         ▼                                            │
│  ┌─────────────────────────────────────────────┐                     │
│  │  app-sg (sg-0c633a...)  ← App EC2가 사용    │                     │
│  │  IN:  3000 ← web-sg (ALB에서만 접근 가능)   │                     │
│  │  IN:  SSH(22) ← bastion-sg (관리용)         │                     │
│  │  OUT: ALL ← 0.0.0.0/0                      │                     │
│  └──────────────────────┬──────────────────────┘                     │
│                         │ port 5432                                  │
│                         ▼                                            │
│  ┌─────────────────────────────────────────────┐                     │
│  │  db-sg (sg-024908...)  ← (향후 RDS 사용)    │                     │
│  │  IN:  PostgreSQL(5432) ← app-sg             │                     │
│  │  OUT: ALL ← 0.0.0.0/0                      │                     │
│  └─────────────────────────────────────────────┘                     │
└──────────────────────────────────────────────────────────────────────┘
```

> [!tip] SG 체이닝의 핵심
> CIDR(`0.0.0.0/0`)이 아닌 **SG ID를 참조**해서 접근을 제한한다. `app-sg`는 `web-sg`를 가진 리소스(=ALB)에서만 3000번 포트 접근을 허용. 다른 곳에서는 불가능.

### 📋 Terraform 모듈 의존성 그래프

```
terraform.tfvars
     │
     ▼
┌─ module.vpc ──────────────────────────────┐
│  vpc_id, public_subnet_ids,               │
│  private_subnet_ids, nat_gateway_id       │
└─────┬──────────────┬─────────────────────┘
      │              │
      ▼              │
┌─ module.security ──┤──────────────────────┐
│  bastion_sg_id,    │  web_sg_id,          │
│  app_sg_id,        │  db_sg_id            │
└──┬──────────┬──────┤──────────────────────┘
   │          │      │
   ▼          │      │
┌─ module.ec2 │      │──────────────────────┐
│  key_name,  │      │  bastion EIP         │
└──┬──────────┘      │──────────────────────┘
   │                 │
   ▼                 │
┌─ module.app ───────┤──────────────────────┐
│  instance_id,      │  private_ip          │
└──┬─────────────────┘──────────────────────┘
   │
   ▼
┌─ module.alb ──────────────────────────────┐
│  alb_dns_name, target_group_arn           │
└───────────────────────────────────────────┘
```

### 📋 트래픽 흐름 상세

```
[사용자 브라우저]
       │
       │ HTTP GET / (port 80)
       ▼
[ALB: my-infra-alb-850810618...]
       │  SG: web-sg 허용 (HTTP 80 from 0.0.0.0/0)
       │  Listener: HTTP:80
       │  Rule: forward → Target Group (my-infra-app-tg)
       │
       │ forward (port 3000)
       ▼
[Target Group: my-infra-app-tg]
       │  Protocol: HTTP
       │  Port: 3000
       │  Health Check: GET / → 200 OK
       │
       │ port 3000
       ▼
[App EC2: i-0241c8ae... / 10.0.10.222]
       │  SG: app-sg 허용 (3000 from web-sg)
       │  Python HTTP Server (systemd)
       │  응답: "<h1>Hello from App Server</h1>"
       │
       │ (응답 역경로)
       ▼
[사용자 브라우저]
       "Hello from App Server" 표시
```

---

## 2. 아키텍처 설명

### 💡 3-Tier란?

```
Tier 1: Presentation  →  ALB (Public)     ← 사용자 접점
Tier 2: Application   →  App EC2 (Private) ← 비즈니스 로직
Tier 3: Database      →  RDS (Private)     ← 데이터 저장 (향후)
```

> [!info] 왜 3-Tier인가
> - **보안**: App/DB를 Private Subnet에 격리 → 인터넷에서 직접 접근 불가
> - **확장성**: ALB 뒤에 EC2를 여러 대 배치 가능 (수평 확장)
> - **관리**: 각 계층을 독립적으로 업데이트/스케일링 가능

### 📊 현재 구성 vs 실무 확장

| 항목 | 현재 (학습) | 실무 확장 |
|------|-------------|-----------|
| ALB | HTTP:80 | HTTPS:443 + ACM 인증서 |
| App | EC2 1대 (Python) | ECS/EKS + Auto Scaling |
| DB | 없음 | RDS PostgreSQL (Multi-AZ) |
| 캐시 | 없음 | ElastiCache Redis |
| DNS | ALB DNS 직접 사용 | Route 53 + 도메인 |
| CI/CD | 수동 배포 | CodePipeline / GitHub Actions |

---

## 3. ALB 핵심 개념

### 💡 ALB 구성 요소 4가지

```
┌──────────────────────────────────────────────┐
│  ALB (Application Load Balancer)              │
│                                               │
│  1. Load Balancer                             │
│     └─ Public Subnets 2개 이상 (Multi-AZ)    │
│     └─ Security Group (HTTP/HTTPS 허용)       │
│                                               │
│  2. Listener                                  │
│     └─ "어떤 포트/프로토콜을 수신할 것인가"   │
│     └─ HTTP:80 또는 HTTPS:443                 │
│                                               │
│  3. Target Group                              │
│     └─ "어디로 보낼 것인가"                   │
│     └─ EC2 인스턴스 목록 + Health Check       │
│                                               │
│  4. Target Group Attachment                   │
│     └─ "구체적으로 어떤 인스턴스를 등록"      │
│     └─ EC2 Instance ID + Port                 │
└──────────────────────────────────────────────┘
```

### 📊 ALB vs NLB vs CLB 비교

| 항목 | ALB | NLB | CLB (레거시) |
|------|-----|-----|-------------|
| OSI 계층 | L7 (HTTP) | L4 (TCP/UDP) | L4/L7 |
| 프로토콜 | HTTP, HTTPS, gRPC | TCP, UDP, TLS | HTTP, TCP |
| URL 라우팅 | /api/* → A, /web/* → B | 불가 | 불가 |
| WebSocket | 지원 | 지원 | 미지원 |
| 고정 IP | 불가 (DNS만) | 가능 (EIP 부착) | 불가 |
| 비용 | ~$0.0225/h | ~$0.0225/h | ~$0.025/h |
| 용도 | **웹 앱 (대부분)** | 게임/IoT/고성능 | 사용하지 마세요 |

> [!warning] ALB는 고정 IP가 없다
> ALB의 IP는 AWS가 동적으로 관리한다. 접속은 반드시 **DNS 이름**으로 해야 한다.
> 고정 IP가 필요하면 NLB를 사용하거나 Global Accelerator를 붙인다.

---

## 4. NAT Gateway 활성화

### 💡 왜 NAT Gateway가 필요한가

```
Private Subnet의 App EC2가 인터넷에 접근하려면:

[App EC2 (10.0.10.222)]
     │ 아웃바운드 요청 (yum install, pip install 등)
     ▼
[Private Route Table]
     │ 0.0.0.0/0 → NAT Gateway
     ▼
[NAT Gateway (Public Subnet)]
     │ Source IP를 NAT EIP(52.79.182.147)로 변환
     ▼
[IGW → Internet]
     │ 응답
     ▼
[NAT Gateway → App EC2]
     응답 전달 (SNAT 역변환)
```

### 📋 Terraform 구현 (기존 vpc 모듈)

NAT Gateway는 VPC 모듈에 **conditional 로직**으로 이미 구현되어 있었다:

```hcl
# terraform.tfvars 한 줄만 변경
enable_nat_gateway = true   # false → true
```

이 변수 하나로 3개 리소스가 자동 생성:
1. `aws_eip.nat[0]` - NAT용 고정 IP
2. `aws_nat_gateway.main[0]` - NAT Gateway
3. `aws_route.private_nat[0]` - Private Route Table에 NAT 라우트

> [!note] conditional 패턴의 가치
> ```hcl
> resource "aws_nat_gateway" "main" {
>   count = var.enable_nat_gateway ? 1 : 0
>   # ...
> }
> ```
> `count = 0`이면 리소스가 생성되지 않는다. 비용이 드는 리소스를 변수로 on/off 제어하는 실무 필수 패턴.

---

## 5. 구현 상세

### 📋 신규 모듈: `modules/app/`

```hcl
# modules/app/main.tf (핵심 부분)
resource "aws_instance" "app" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t4g.micro"
  key_name               = var.key_name          # Bastion과 동일 키
  subnet_id              = var.subnet_id          # Private Subnet
  vpc_security_group_ids = [var.security_group_id] # app-sg

  user_data = <<-USERDATA
    #!/bin/bash
    # Python3 내장 HTTP 서버 (패키지 설치 불필요)
    cat <<'EOF' > /home/ec2-user/index.html
    <h1>Hello from App Server</h1>
    <p>Private Subnet | Port 3000</p>
    EOF

    # systemd 서비스로 등록 (재부팅 후에도 자동 시작)
    cat <<'EOF' > /etc/systemd/system/webapp.service
    [Unit]
    Description=Simple Web App
    After=network.target
    [Service]
    ExecStart=/usr/bin/python3 -m http.server 3000
    WorkingDirectory=/home/ec2-user
    User=ec2-user
    Restart=always
    [Install]
    WantedBy=multi-user.target
    EOF

    systemctl daemon-reload
    systemctl enable --now webapp.service
  USERDATA
}
```

> [!tip] user_data 포인트
> - Python3는 AL2023에 기본 설치 → NAT Gateway 없어도 즉시 동작
> - systemd 서비스 등록 → 재부팅 후에도 자동 시작
> - 실무에서는 Docker 컨테이너나 nginx를 사용

### 📋 신규 모듈: `modules/alb/`

```hcl
# modules/alb/main.tf (핵심 부분)

# 1. ALB 본체 - Public Subnet 2개에 배치
resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false            # 외부 노출 (internet-facing)
  load_balancer_type = "application"    # ALB
  security_groups    = [var.security_group_id]  # web-sg
  subnets            = var.subnet_ids   # Public Subnet 2개
}

# 2. Target Group - 어디로 보낼지
resource "aws_lb_target_group" "app" {
  name     = "${var.project_name}-app-tg"
  port     = 3000              # App 서버 포트
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path     = "/"             # GET / 로 헬스체크
    port     = "3000"
    matcher  = "200"           # 200 응답이면 Healthy
    interval = 30              # 30초마다 체크
  }
}

# 3. Listener - 어떤 포트를 수신할지
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80               # HTTP:80 수신
  protocol          = "HTTP"

  default_action {
    type             = "forward"       # Target Group으로 전달
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# 4. Attachment - 구체적 인스턴스 등록
resource "aws_lb_target_group_attachment" "app" {
  target_group_arn = aws_lb_target_group.app.arn
  target_id        = var.target_id     # App EC2 Instance ID
  port             = 3000
}
```

### 📋 루트 main.tf 모듈 연결

```hcl
module "app" {
  source            = "./modules/app"
  project_name      = var.project_name
  subnet_id         = module.vpc.private_subnet_ids[0]   # Private!
  security_group_id = module.security.app_sg_id           # app-sg
  key_name          = module.ec2.key_name                 # 동일 SSH 키
}

module "alb" {
  source            = "./modules/alb"
  project_name      = var.project_name
  vpc_id            = module.vpc.vpc_id
  subnet_ids        = module.vpc.public_subnet_ids        # Public 2개
  security_group_id = module.security.web_sg_id            # web-sg
  target_id         = module.app.instance_id               # App EC2
}
```

> [!example] output → variable 연결 패턴
> `module.vpc.private_subnet_ids[0]` → `module.app`의 `var.subnet_id`
> `module.security.app_sg_id` → `module.app`의 `var.security_group_id`
> `module.app.instance_id` → `module.alb`의 `var.target_id`

---

## 6. 검증 및 트러블슈팅

### 📋 검증 체크리스트

```bash
# 1) ALB 접속 테스트
curl http://my-infra-alb-850810618.ap-northeast-2.elb.amazonaws.com
# 응답: <h1>Hello from App Server</h1>

# 2) HTTP 상태 코드 확인
curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" http://ALB_DNS

# 3) Bastion 경유 App EC2 SSH
ssh -J ec2-user@43.201.xxx.xxx ec2-user@10.0.10.222

# 4) App EC2에서 서비스 상태 확인
systemctl status webapp.service

# 5) App EC2에서 인터넷 접근 확인 (NAT Gateway 동작 확인)
curl -s ifconfig.me
# 응답: 52.79.182.147 (NAT EIP)
```

### 🚨 Target Group이 Unhealthy인 경우

**원인 1: App 서버가 아직 시작 안 됨**
- user_data 실행에 시간이 걸림 (EC2 부팅 후 ~30초)
- 대기 후 재확인

**원인 2: SG에서 3000번 포트가 막혀 있음**
```bash
# app-sg의 ingress 확인
aws ec2 describe-security-groups --group-ids sg-0c633ad0d959fa6db \
  --query 'SecurityGroups[0].IpPermissions'
# port 3000, source: web-sg 확인
```

**원인 3: App 서버 프로세스 다운**
```bash
# Bastion 경유 접속 후 확인
ssh -J ec2-user@43.201.xxx.xxx ec2-user@10.0.10.222
sudo systemctl status webapp.service
sudo journalctl -u webapp.service
```

### 🚨 ALB DNS에 접속이 안 되는 경우

```bash
# ALB가 Provisioning 상태인지 확인 (생성 직후 ~3분)
aws elbv2 describe-load-balancers --names my-infra-alb \
  --query 'LoadBalancers[0].State'

# DNS 해석 확인
nslookup my-infra-alb-850810618.ap-northeast-2.elb.amazonaws.com
```

---

## 7. 비용 관리

### 📊 현재 과금 리소스

| 리소스 | 시간당 | 일당 | 월 예상 |
|--------|--------|------|---------|
| NAT Gateway | $0.045 | $1.08 | $32.4 |
| ALB | $0.0225 | $0.54 | $16.2 |
| Bastion EIP | Free | Free | 사용 중이므로 무료 |
| NAT EIP | Free | Free | NAT GW에 연결 중이므로 무료 |
| Bastion EC2 | Free | Free | 프리티어 |
| App EC2 | Free | Free | 프리티어 |
| **합계** | **~$0.068** | **~$1.62** | **~$48.6** |

### 💡 비용 차단 방법

```bash
# 방법 1: ALB + App만 삭제 (NAT는 유지)
terraform destroy -target=module.alb -target=module.app

# 방법 2: NAT도 비활성화 (terraform.tfvars 수정 후)
# enable_nat_gateway = false
terraform apply

# 방법 3: 전부 삭제
terraform destroy
```

> [!warning] EIP 주의
> EIP는 **EC2/NAT에 연결된 상태에서는 무료**지만, 연결 안 한 채로 방치하면 시간당 $0.005 과금. EC2를 stop하면 EIP가 미연결 상태가 되므로 주의.

---

## 🎯 핵심 정리

### 📊 오늘 배운 것

| 개념 | 핵심 |
|------|------|
| **3-Tier** | ALB(Public) → App(Private) → DB(Private) 계층 분리 |
| **ALB 구성** | LB + Listener + Target Group + Attachment 4단 구조 |
| **SG 체이닝** | web-sg → app-sg → db-sg (CIDR 아닌 SG ID 참조) |
| **NAT Gateway** | Private Subnet → Internet 아웃바운드 (SNAT) |
| **conditional** | `count = var.xxx ? 1 : 0` 패턴으로 리소스 on/off |
| **모듈 확장** | `modules/app/`, `modules/alb/` 추가 → 기존 영향 없음 |
| **user_data** | EC2 첫 부팅 시 스크립트 자동 실행 |

### 🔧 프로젝트 파일 구조 (최종)

```
terraform-aws-infra/
├── main.tf                    # 5개 모듈 호출
├── variables.tf               # 루트 변수 (7개)
├── outputs.tf                 # 루트 출력 (15개)
├── providers.tf               # AWS Provider
├── terraform.tfvars           # 변수 값
├── modules/
│   ├── vpc/       (3파일)     # VPC, Subnet, NAT, Route (15리소스)
│   ├── security/  (3파일)     # SG 4개
│   ├── ec2/       (3파일)     # Bastion + EIP (5리소스)
│   ├── app/       (3파일)     # App EC2 (1리소스)
│   └── alb/       (3파일)     # ALB + TG + Listener (4리소스)
├── terraform.tfstate          # 28개 리소스 관리
└── terraform.tfstate.pre-module-backup
```

### 📋 접속 정보

```bash
# ALB (브라우저 접속 가능)
http://my-infra-alb-850810618.ap-northeast-2.elb.amazonaws.com

# Bastion SSH
ssh -i ~/.ssh/id_ed25519 ec2-user@43.201.xxx.xxx

# App EC2 SSH (Bastion 경유 ProxyJump)
ssh -J ec2-user@43.201.xxx.xxx ec2-user@10.0.10.222
```
