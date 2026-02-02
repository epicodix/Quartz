---
title: VPC 네트워크 기초 - 클라우드 엔지니어를 위한 CS 지식
tags:
  - network
  - vpc
  - aws
  - cs-fundamentals
  - infrastructure
aliases:
  - vpc-네트워크-기초
  - 네트워크-cs지식
date: 2026-01-25
category: 1_가이드/Network
status: 완성
priority: 높음
---

# 🎯 VPC 네트워크 기초 - 클라우드 엔지니어를 위한 CS 지식

## 📑 목차
- [[#1. OSI 7계층과 TCP/IP|OSI 7계층과 TCP/IP]]
- [[#2. IP 주소 체계|IP 주소 체계]]
- [[#3. CIDR과 서브넷|CIDR과 서브넷]]
- [[#4. VPC 핵심 컴포넌트|VPC 핵심 컴포넌트]]
- [[#5. 라우팅 심화|라우팅 심화]]
- [[#6. Security Group vs NACL|Security Group vs NACL]]
- [[#7. NAT와 IP 변환|NAT와 IP 변환]]
- [[#8. DNS와 VPC|DNS와 VPC]]
- [[#9. VPC 확장 (Peering, TGW, Endpoints)|VPC 확장]]
- [[#10. 패킷 흐름 완전 분석|패킷 흐름 완전 분석]]
- [[#11. 트러블슈팅 체크리스트|트러블슈팅 체크리스트]]

---

## 1. OSI 7계층과 TCP/IP

> [!note] 왜 알아야 하나?
> AWS 리소스가 어느 계층에서 동작하는지 알아야 트러블슈팅이 가능.
> "ALB vs NLB 차이" = "7계층 vs 4계층 차이"

### 📊 OSI 7계층 vs TCP/IP 4계층

```
OSI 7계층              TCP/IP 4계층         AWS 리소스
─────────────────────────────────────────────────────────
7. Application  ┐
6. Presentation ├─→  Application         ALB, API Gateway, WAF
5. Session      ┘

4. Transport    ───→  Transport           NLB, Security Group (L4)

3. Network      ───→  Internet            VPC, Subnet, Route Table,
                                          IGW, NAT, NACL

2. Data Link    ┐
1. Physical     ┴─→  Network Access       ENI, VPC 내부 통신
```

### 💡 각 계층에서 보는 것

| 계층 | 데이터 단위 | 식별자 | 장비/리소스 |
|------|------------|--------|------------|
| L7 Application | Data | URL, Header | ALB, WAF |
| L4 Transport | Segment | Port | NLB, SG |
| L3 Network | Packet | IP 주소 | Router, RT, NACL |
| L2 Data Link | Frame | MAC 주소 | Switch, ENI |

### 💡 AWS 로드밸런서 차이

```
ALB (L7):
  - HTTP/HTTPS 이해
  - URL 경로 기반 라우팅 (/api → 서버A, /web → 서버B)
  - Host 헤더 기반 라우팅 (a.com → 서버A, b.com → 서버B)
  - 느리지만 똑똑함

NLB (L4):
  - TCP/UDP 포트만 봄
  - 패킷을 그대로 전달 (수정 없음)
  - 빠름, 고성능, 고정 IP 가능
  - WebSocket, gRPC에 적합
```

---

## 2. IP 주소 체계

### 📊 IPv4 구조

```
10.0.1.5 = 32비트 주소

10      .  0       .  1       .  5
00001010   00000000   00000001   00000101
└──────┘   └──────┘   └──────┘   └──────┘
 옥텟1      옥텟2      옥텟3      옥텟4
 (0-255)   (0-255)   (0-255)   (0-255)
```

### 📊 Public vs Private IP

| 구분 | 특징 | 대역 |
|------|------|------|
| **Public IP** | 인터넷에서 유일, 라우팅 가능 | ISP가 할당 |
| **Private IP** | 내부에서만 유효, 인터넷 직접 불가 | RFC 1918 |

**Private IP 대역 (암기!):**

```
Class A: 10.0.0.0/8      → 10.0.0.0 ~ 10.255.255.255    (가장 큼)
Class B: 172.16.0.0/12   → 172.16.0.0 ~ 172.31.255.255  (중간)
Class C: 192.168.0.0/16  → 192.168.0.0 ~ 192.168.255.255 (가정용)
```

> [!tip] AWS VPC는 Private 대역만 사용
> VPC CIDR로 `10.0.0.0/16`, `172.16.0.0/16` 등을 설정
> Public IP는 IGW + Elastic IP로 매핑해서 사용

### 📊 특수 IP 주소

| IP | 용도 |
|----|------|
| 0.0.0.0/0 | 모든 IP (라우팅에서 "기본 경로") |
| 127.0.0.1 | Localhost (자기 자신) |
| 169.254.x.x | Link-local (DHCP 실패 시 자동 할당) |
| 255.255.255.255 | 브로드캐스트 |

---

## 3. CIDR과 서브넷

### 📊 CIDR 표기법

```
10.0.0.0/16
└──┬───┘ └┬┘
   │      └── Prefix: 네트워크 비트 수
   └── Network Address
```

**핵심 공식:**
```
사용 가능 IP = 2^(32 - prefix) - 2

/8  = 2^24 = 16,777,216개
/16 = 2^16 = 65,536개
/24 = 2^8  = 256개
/28 = 2^4  = 16개
/32 = 2^0  = 1개 (단일 IP 지정)
```

> [!warning] AWS는 서브넷당 5개 IP 예약
> .0 = 네트워크 주소
> .1 = VPC 라우터
> .2 = AWS DNS
> .3 = AWS 예약
> .255 = 브로드캐스트
> → /24 서브넷 실제 사용 가능: 251개

### 📊 서브넷 설계 전략

```
VPC: 10.0.0.0/16 (65,536개)
│
├── Public Subnets (작게)
│   ├── 10.0.1.0/24 (AZ-a) → Bastion, NAT, ALB
│   └── 10.0.2.0/24 (AZ-c) → ALB
│
├── Private Subnets - App (중간)
│   ├── 10.0.10.0/24 (AZ-a) → App 서버
│   └── 10.0.20.0/24 (AZ-c) → App 서버
│
├── Private Subnets - DB (작게)
│   ├── 10.0.100.0/24 (AZ-a) → RDS, ElastiCache
│   └── 10.0.110.0/24 (AZ-c) → RDS Standby
│
└── 여유 공간
    └── 10.0.200.0/24 ~ → 미래 확장용
```

**설계 원칙:**
```
1. Public은 최소한으로 (노출 영역 최소화)
2. Private 계층 분리 (App ↔ DB 분리)
3. AZ당 동일 구조 (Multi-AZ 고가용성)
4. CIDR 겹침 금지 (VPC Peering 대비)
5. 여유 공간 확보 (미래 확장)
```

### 📊 CIDR 빠른 계산

| CIDR | 1옥텟 | 2옥텟 | 3옥텟 | 4옥텟 | IP 수 |
|------|-------|-------|-------|-------|-------|
| /8 | 고정 | 변경 | 변경 | 변경 | 16M |
| /16 | 고정 | 고정 | 변경 | 변경 | 65K |
| /24 | 고정 | 고정 | 고정 | 변경 | 256 |
| /28 | 고정 | 고정 | 고정 | 일부 | 16 |
| /32 | 고정 | 고정 | 고정 | 고정 | 1 |

---

## 4. VPC 핵심 컴포넌트

### 📊 VPC 구성요소 맵

```
┌─────────────────────────────────────────────────────────────┐
│  AWS Cloud                                                   │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  VPC (10.0.0.0/16)                                     │ │
│  │                                                         │ │
│  │   ┌─────────┐         ┌─────────────┐                  │ │
│  │   │   IGW   │◄───────►│  Internet   │                  │ │
│  │   └────┬────┘         └─────────────┘                  │ │
│  │        │                                                │ │
│  │   ┌────┴─────────────────────────────────────────┐     │ │
│  │   │  Public Subnet (10.0.1.0/24)                 │     │ │
│  │   │   ┌─────────┐    ┌─────────┐                 │     │ │
│  │   │   │ Bastion │    │   NAT   │                 │     │ │
│  │   │   │   EC2   │    │ Gateway │                 │     │ │
│  │   │   └─────────┘    └────┬────┘                 │     │ │
│  │   └───────────────────────┼──────────────────────┘     │ │
│  │                           │                             │ │
│  │   ┌───────────────────────┼──────────────────────┐     │ │
│  │   │  Private Subnet (10.0.10.0/24)               │     │ │
│  │   │   ┌─────────┐    ┌─────────┐    ┌─────────┐  │     │ │
│  │   │   │   App   │    │   App   │    │   RDS   │  │     │ │
│  │   │   │   EC2   │    │   EC2   │    │         │  │     │ │
│  │   │   └─────────┘    └─────────┘    └─────────┘  │     │ │
│  │   └──────────────────────────────────────────────┘     │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### 💡 컴포넌트 상세

#### Internet Gateway (IGW)

```
역할: VPC ↔ 인터넷 관문
특징:
  - VPC당 1개
  - 수평 확장 (AWS 관리, 대역폭 제한 없음)
  - 양방향 (Inbound + Outbound)
  - 무료
```

#### NAT Gateway

```
역할: Private → 인터넷 (단방향)
특징:
  - 반드시 Public Subnet에 위치
  - Elastic IP 필요
  - 단방향 (Outbound만)
  - 유료! ($0.045/h + 데이터 처리)

왜 필요?
  - Private EC2가 apt update, pip install 등 하려면 필요
  - 외부 API 호출 시 필요
```

#### ENI (Elastic Network Interface)

```
역할: 가상 네트워크 카드
특징:
  - EC2 인스턴스에 붙는 네트워크 인터페이스
  - Private IP, Public IP, MAC 주소 보유
  - Security Group은 ENI에 적용됨
  - 인스턴스 간 이동 가능 (페일오버)
```

#### Elastic IP (EIP)

```
역할: 고정 Public IP
특징:
  - 인스턴스 재시작해도 IP 유지
  - 미사용 시 과금 ($0.005/h)
  - 빠른 장애조치 (다른 인스턴스로 재할당)
```

---

## 5. 라우팅 심화

### 📊 Route Table 구조

```
┌────────────────────┬─────────────────┬──────────────┐
│ Destination       │ Target          │ Status       │
├────────────────────┼─────────────────┼──────────────┤
│ 10.0.0.0/16       │ local           │ Active       │ ← VPC 내부
│ 0.0.0.0/0         │ igw-xxxxx       │ Active       │ ← 인터넷
│ 172.31.0.0/16     │ pcx-xxxxx       │ Active       │ ← Peering
│ pl-xxxxxxxx       │ vpce-xxxxx      │ Active       │ ← S3 Endpoint
└────────────────────┴─────────────────┴──────────────┘
```

### 💡 라우팅 우선순위 (Longest Prefix Match)

```
목적지 IP: 10.0.1.50

라우팅 테이블:
  10.0.0.0/16 → local
  10.0.1.0/24 → nat-gw (실제로는 이상한 예시지만)
  0.0.0.0/0   → igw

매칭 결과:
  - /24가 /16보다 더 구체적 (prefix가 김)
  - /24 라우트로 전달

규칙: Prefix가 길수록 우선순위 높음
     /32 > /24 > /16 > /8 > /0
```

### 💡 Main Route Table vs Custom Route Table

```
Main RT:
  - VPC 생성 시 자동 생성
  - 명시적 연결 없는 서브넷은 자동으로 Main RT 사용
  - 기본: local 라우트만 있음

Custom RT:
  - 직접 생성
  - 서브넷에 명시적 연결 필요
  - Public RT: IGW 라우트 추가
  - Private RT: NAT GW 라우트 추가
```

> [!warning] 흔한 실수
> 서브넷을 만들고 RT Association을 안 하면 Main RT 사용
> → Main RT에 IGW 없으면 "Public Subnet인데 인터넷 안 됨" 현상

---

## 6. Security Group vs NACL

### 📊 비교표

| 특성 | Security Group | NACL |
|------|---------------|------|
| **적용 대상** | ENI (인스턴스) | Subnet 전체 |
| **상태** | Stateful | Stateless |
| **규칙 유형** | 허용만 | 허용 + 거부 |
| **규칙 평가** | 모든 규칙 종합 | 번호 순 (낮은 번호 우선) |
| **기본 정책** | Inbound 거부 | 모두 허용 |
| **적용 시점** | 인스턴스 진입 시 | 서브넷 경계 |

### 💡 Stateful vs Stateless

```
┌─────────────────────────────────────────────────────────┐
│  Stateful (Security Group)                              │
│                                                         │
│  Client ──HTTP 요청──► EC2                              │
│         ◄──HTTP 응답──                                  │
│                                                         │
│  Inbound 80 허용하면 → 응답 자동 허용                    │
│  "연결 상태를 기억함"                                    │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│  Stateless (NACL)                                       │
│                                                         │
│  Client ──HTTP 요청──► EC2                              │
│         ◄──HTTP 응답──  ← 이것도 별도 규칙 필요!         │
│                                                         │
│  Inbound 80 허용 + Outbound 1024-65535 허용 필요        │
│  "각 패킷을 독립적으로 판단"                             │
└─────────────────────────────────────────────────────────┘
```

### 💡 Ephemeral Port (임시 포트)

```
왜 1024-65535를 열어야 하나?

클라이언트가 서버에 요청할 때:
  Source:      클라이언트IP:54321 (랜덤 고포트)
  Destination: 서버IP:80

서버가 응답할 때:
  Source:      서버IP:80
  Destination: 클라이언트IP:54321 ← 원래 포트로 돌려줌

NACL에서 Outbound 54321 포트가 막혀있으면?
  → 응답 못 보냄!

해결: Outbound 1024-65535 허용 (임시 포트 범위)
```

### 📊 NACL 규칙 예시

```
Inbound:
┌──────┬──────────┬────────────┬───────┬──────────┬────────┐
│ Rule │ Type     │ Source     │ Port  │ Protocol │ Action │
├──────┼──────────┼────────────┼───────┼──────────┼────────┤
│ 100  │ HTTP     │ 0.0.0.0/0 │ 80    │ TCP      │ ALLOW  │
│ 110  │ HTTPS    │ 0.0.0.0/0 │ 443   │ TCP      │ ALLOW  │
│ 120  │ SSH      │ 10.0.0.0/8│ 22    │ TCP      │ ALLOW  │
│ *    │ All      │ 0.0.0.0/0 │ All   │ All      │ DENY   │ ← 기본
└──────┴──────────┴────────────┴───────┴──────────┴────────┘

Outbound:
┌──────┬──────────┬────────────┬───────────┬──────────┬────────┐
│ Rule │ Type     │ Dest       │ Port      │ Protocol │ Action │
├──────┼──────────┼────────────┼───────────┼──────────┼────────┤
│ 100  │ Custom   │ 0.0.0.0/0 │ 1024-65535│ TCP      │ ALLOW  │ ← 응답용
│ 110  │ HTTP     │ 0.0.0.0/0 │ 80        │ TCP      │ ALLOW  │
│ 120  │ HTTPS    │ 0.0.0.0/0 │ 443       │ TCP      │ ALLOW  │
│ *    │ All      │ 0.0.0.0/0 │ All       │ All      │ DENY   │
└──────┴──────────┴────────────┴───────────┴──────────┴────────┘
```

### 💡 SG 체인 설계 (Best Practice)

```
인터넷
   │
   ▼
┌──────────────────┐
│ web-sg           │  Inbound: 0.0.0.0/0:80,443
│ (ALB)            │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│ app-sg           │  Inbound: web-sg:3000
│ (App Server)     │           bastion-sg:22
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│ db-sg            │  Inbound: app-sg:5432
│ (RDS)            │
└──────────────────┘

┌──────────────────┐
│ bastion-sg       │  Inbound: MyIP:22
│ (Bastion Host)   │
└──────────────────┘
```

**핵심: CIDR 대신 SG를 참조하면 유지보수가 쉬움**

---

## 7. NAT와 IP 변환

### 📊 NAT 유형

| 유형 | 설명 | AWS |
|------|------|-----|
| **SNAT** (Source NAT) | 출발지 IP 변환 | NAT Gateway |
| **DNAT** (Dest NAT) | 목적지 IP 변환 | ALB, NLB |
| **PAT** (Port NAT) | IP + Port 변환 | NAT Gateway (실제로는 PAT) |

### 💡 NAT Gateway 동작 원리

```
Private EC2 (10.0.10.5) → curl google.com

1. EC2가 패킷 생성
   Source: 10.0.10.5:54321
   Dest:   142.250.x.x:443 (Google)

2. Private RT → NAT Gateway로 전달
   (0.0.0.0/0 → nat-gw)

3. NAT Gateway가 Source IP 변환 (SNAT)
   Source: 52.78.x.x:32145 (NAT의 EIP)
   Dest:   142.250.x.x:443

4. IGW 통해 인터넷으로

5. Google 응답
   Source: 142.250.x.x:443
   Dest:   52.78.x.x:32145

6. NAT Gateway가 역변환
   Dest: 10.0.10.5:54321

7. EC2 수신 완료

핵심: NAT는 변환 테이블을 유지하여 응답을 올바른 인스턴스로 전달
```

### 💡 NAT Gateway vs NAT Instance

| | NAT Gateway | NAT Instance |
|--|-------------|--------------|
| 관리 | AWS 관리형 | 직접 관리 |
| 가용성 | AZ 내 고가용성 | 직접 HA 구성 |
| 대역폭 | 최대 100 Gbps | 인스턴스 타입 의존 |
| 비용 | $0.045/h + 데이터 | 인스턴스 비용만 |
| 보안그룹 | 적용 불가 | 적용 가능 |
| 용도 | 프로덕션 | 테스트/비용절감 |

---

## 8. DNS와 VPC

### 📊 DNS 기초

```
Domain: api.example.com

조회 과정:
1. Local DNS Cache 확인
2. /etc/hosts 확인
3. DNS Resolver에 질의
4. Root DNS → .com DNS → example.com DNS
5. A Record 반환: 13.124.xxx.xxx
```

### 💡 VPC DNS 설정

```hcl
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true   # VPC 내 DNS 해석 활성화
  enable_dns_hostnames = true   # EC2에 DNS 호스트명 부여
}
```

| 설정 | 효과 |
|------|------|
| enable_dns_support | VPC 내부 DNS 서버 활성화 (10.0.0.2) |
| enable_dns_hostnames | EC2에 public DNS 이름 부여 |

### 💡 Route53 Private Hosted Zone

```
VPC 내부에서만 작동하는 DNS

예시:
  db.internal.mycompany.com → 10.0.10.50 (RDS)
  cache.internal.mycompany.com → 10.0.10.100 (Redis)

장점:
  - 내부 리소스에 의미있는 이름 부여
  - IP 변경 시 DNS만 수정 (앱 수정 불필요)
  - 외부 노출 없음
```

---

## 9. VPC 확장 (Peering, TGW, Endpoints)

### 📊 VPC Peering

```
VPC A (10.0.0.0/16) ←──Peering──→ VPC B (172.16.0.0/16)

특징:
  - 1:1 연결 (직접 연결된 VPC만 통신)
  - 전이 불가 (A↔B, B↔C 연결해도 A↔C 불가)
  - 리전 간 가능 (Inter-Region)
  - CIDR 겹치면 불가

설정 필요:
  1. Peering 연결 생성
  2. 상대방 수락
  3. 양쪽 RT에 상대 CIDR → pcx-xxx 라우트 추가
  4. 양쪽 SG에서 상대 CIDR 허용
```

### 📊 Transit Gateway (TGW)

```
Hub-Spoke 모델

         ┌─── VPC A
         │
TGW ─────┼─── VPC B
         │
         ├─── VPC C
         │
         └─── On-premises (VPN/DX)

장점:
  - 중앙 집중 라우팅
  - VPC 추가 시 TGW에만 연결
  - 전이적 라우팅 가능 (A→TGW→C)

비용: $0.05/h + 데이터 처리
```

### 📊 VPC Endpoint

```
AWS 서비스에 프라이빗 연결 (인터넷 안 거침)

종류:
1. Gateway Endpoint (무료)
   - S3, DynamoDB
   - Route Table에 추가됨

2. Interface Endpoint (유료)
   - 그 외 AWS 서비스 (SQS, SNS, ECR 등)
   - ENI로 생성됨 (Private IP 부여)
   - PrivateLink 기반
```

**예시: S3 Gateway Endpoint**
```
Without Endpoint:
  EC2 → NAT GW → IGW → S3 (인터넷 경유, 비용 발생)

With Endpoint:
  EC2 → S3 Endpoint → S3 (AWS 백본, 무료, 빠름)
```

---

## 10. 패킷 흐름 완전 분석

### 📊 시나리오: 인터넷 → ALB → EC2 → RDS

```
1. DNS 조회
   Client → DNS: api.example.com?
   DNS → Client: 52.78.xxx.xxx (ALB IP)

2. Client → ALB
   ┌────────────────────────────────────────┐
   │ Packet                                 │
   │ Src: 203.0.113.50:54321 (Client)       │
   │ Dst: 52.78.xxx.xxx:443 (ALB)           │
   └────────────────────────────────────────┘

   경로: Internet → IGW → ALB (Public Subnet)
   체크: NACL Inbound → web-sg Inbound (443)

3. ALB → EC2 (Target)
   ┌────────────────────────────────────────┐
   │ Packet                                 │
   │ Src: 10.0.1.50:xxxxx (ALB Private IP)  │
   │ Dst: 10.0.10.5:3000 (EC2)              │
   └────────────────────────────────────────┘

   경로: ALB → (local route) → EC2 (Private Subnet)
   체크: app-sg Inbound (web-sg:3000)

4. EC2 → RDS
   ┌────────────────────────────────────────┐
   │ Packet                                 │
   │ Src: 10.0.10.5:54321 (EC2)             │
   │ Dst: 10.0.100.50:5432 (RDS)            │
   └────────────────────────────────────────┘

   경로: EC2 → (local route) → RDS
   체크: db-sg Inbound (app-sg:5432)

5. 응답은 역순 (SG가 Stateful이라 자동 허용)
```

### 📊 시나리오: Private EC2 → 외부 API

```
1. EC2 → curl api.external.com
   ┌────────────────────────────────────────┐
   │ Src: 10.0.10.5:54321                   │
   │ Dst: 52.85.xxx.xxx:443                 │
   └────────────────────────────────────────┘

2. Private RT → NAT Gateway
   (0.0.0.0/0 → nat-gw)

3. NAT Gateway → IGW → Internet
   ┌────────────────────────────────────────┐
   │ Src: 52.78.xxx.xxx:32145 (NAT EIP)     │ ← SNAT!
   │ Dst: 52.85.xxx.xxx:443                 │
   └────────────────────────────────────────┘

4. 외부 서버 응답
   ┌────────────────────────────────────────┐
   │ Src: 52.85.xxx.xxx:443                 │
   │ Dst: 52.78.xxx.xxx:32145               │
   └────────────────────────────────────────┘

5. NAT → EC2 (역변환)
   ┌────────────────────────────────────────┐
   │ Src: 52.85.xxx.xxx:443                 │
   │ Dst: 10.0.10.5:54321                   │ ← 역SNAT
   └────────────────────────────────────────┘
```

---

## 11. 트러블슈팅 체크리스트

### 🔍 "인스턴스가 인터넷 안 됨"

```
□ 1. 인스턴스 위치 확인
     - Public Subnet? → IGW 라우트 있는지
     - Private Subnet? → NAT GW 있는지

□ 2. Route Table 확인
     - 0.0.0.0/0 라우트 존재?
     - RT가 서브넷에 연결됐는지?

□ 3. Public IP 확인 (Public Subnet인 경우)
     - Public IP 할당됐는지?
     - Elastic IP 연결됐는지?

□ 4. Security Group Outbound
     - 0.0.0.0/0 허용?

□ 5. NACL
     - Outbound 허용?
     - Inbound 응답 포트(1024-65535) 허용?

□ 6. NAT Gateway 상태 (Private인 경우)
     - Status: Available?
     - Public Subnet에 있는지?
     - EIP 할당됐는지?
```

### 🔍 "ALB Health Check 실패"

```
□ 1. Target Group Health Check 설정
     - Path가 실제 존재? (200 반환?)
     - Port 맞는지?

□ 2. Security Group
     - ALB SG → Target SG 허용?
     - Health Check Port 열려있는지?

□ 3. 앱 상태
     - 앱이 실행 중인지?
     - Health endpoint 응답하는지?

□ 4. 서브넷
     - ALB가 타겟과 통신 가능한 서브넷에 있는지?
```

### 🔍 "RDS 연결 안 됨"

```
□ 1. Security Group
     - RDS SG에 App SG 허용?
     - Port 5432 (PostgreSQL) / 3306 (MySQL)?

□ 2. 서브넷
     - RDS와 App이 같은 VPC?
     - Private Subnet에서 접근 시도?

□ 3. 연결 경로
     - 로컬 PC에서 직접 연결 시도?
       → Bastion 통해야 함
     - VPN/Direct Connect 없으면 불가

□ 4. RDS 상태
     - Status: Available?
     - Endpoint 주소 정확?
```

### 🔍 VPC Flow Logs 활용

```bash
# Flow Log 형식
# version account-id interface-id srcaddr dstaddr srcport dstport protocol packets bytes start end action log-status

# 예시 (REJECT)
2 123456789012 eni-abc123 10.0.1.5 10.0.10.50 54321 5432 6 1 40 1620000000 1620000060 REJECT OK

해석:
  - 10.0.1.5:54321 → 10.0.10.50:5432
  - Protocol 6 = TCP
  - Action: REJECT ← 문제!
  - Security Group 또는 NACL에서 막힘
```

---

## 📋 핵심 요약

```
VPC = 가상 네트워크 (Private IP 대역)
Subnet = VPC 쪼갬 (Public/Private)
Route Table = 패킷 길 안내
IGW = 인터넷 관문 (양방향)
NAT = Private→인터넷 (단방향, 유료)
SG = 인스턴스 방화벽 (Stateful)
NACL = 서브넷 방화벽 (Stateless)
Peering = VPC 간 직접 연결
Endpoint = AWS 서비스 프라이빗 연결
```

---

> [!note] 문서 정보
> - 작성일: 2026-01-25
> - 관련 문서: [[Terraform-AWS-VPC-구축-가이드]]
