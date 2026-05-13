---
title: 멘토링 핵심 개념 정리 - 네트워크 & EKS
tags:
  - network
  - eks
  - kubernetes
  - cidr
  - nat-gateway
  - cloudfront
  - service
  - ingress
  - devops
  - infrastructure
aliases:
  - 멘토링질문정리
  - EKS네트워크개념
date: 2026-05-12
category: K8s_Deep_Dive
status: 완성
priority: 높음
---

# 🎯 멘토링 핵심 개념 정리 — 네트워크 & EKS

> 멘토링에서 나온 질문들을 pposiraegi 프로젝트 맥락으로 정리한 문서.
> 이론 → 우리 프로젝트 적용 순서로 설명.

## 📑 목차

- [[#1. CIDR|CIDR]]
- [[#2. Public IP vs Private IP|Public IP vs Private IP]]
- [[#3. NAT Gateway|NAT Gateway]]
- [[#4. CloudFront — 왜 쓰는지|CloudFront]]
- [[#5. Service & Ingress|Service & Ingress]]
- [[#6. Image Tag|Image Tag]]

---

## 1. CIDR

> [!note] 핵심 개념
> CIDR(Classless Inter-Domain Routing) — IP 주소 범위를 표현하는 표기법.
> `IP주소/프리픽스길이` 형식. 프리픽스가 짧을수록 범위가 넓다.

### 읽는 방법

```
10.0.0.0/16
└─ 10.0.x.x 전체 (앞 16비트 고정, 나머지 16비트 자유)
   → 65,536개 주소

10.0.1.0/24
└─ 10.0.1.x 전체 (앞 24비트 고정, 나머지 8비트 자유)
   → 256개 주소
```

### 비트 계산법

| CIDR | 고정 비트 | 자유 비트 | 주소 수 |
|------|----------|----------|--------|
| /8   | 8        | 24       | 16,777,216 |
| /16  | 16       | 16       | 65,536 |
| /24  | 24       | 8        | 256 |
| /32  | 32       | 0        | 1 (단일 IP) |

### pposiraegi 프로젝트 적용

```
VPC:             10.0.0.0/16     → 10.0.x.x 전 대역
Public Subnet A: 10.0.1.0/24    → 10.0.1.0 ~ 10.0.1.255
Public Subnet B: 10.0.2.0/24    → 10.0.2.0 ~ 10.0.2.255
Private Subnet A: 10.0.11.0/24  → EKS 노드, RDS, Redis (AZ-a)
Private Subnet B: 10.0.12.0/24  → EKS 노드, RDS, Redis (AZ-b)
```

> [!tip] 외울 필요 없는 것
> 매번 계산하지 않아도 됨. /16 = 65K개, /24 = 256개만 기억하면 실무에서 충분.

---

## 2. Public IP vs Private IP

> [!note] 핵심 개념
> Public IP = 인터넷에서 라우팅 가능한 주소.
> Private IP = 인터넷에서 라우팅 불가, VPC 내부에서만 사용.

### Private IP 대역 (RFC 1918)

```
10.0.0.0/8       (10.x.x.x)
172.16.0.0/12    (172.16.x.x ~ 172.31.x.x)
192.168.0.0/16   (192.168.x.x)
```

우리 VPC `10.0.0.0/16`은 Private 대역.

### 자주 하는 오해

> [!warning] "Public Subnet = Public IP"가 아니다
> Public Subnet의 정의는 **라우팅 테이블이 IGW(Internet Gateway)를 향하는 서브넷**.
> 거기 올라간 리소스가 Public IP(EIP)를 가져야 인터넷 접근이 가능.
>
> - ALB: Public Subnet + Public IP → 인터넷에서 접근 가능
> - NAT GW: Public Subnet + EIP → 인터넷으로 나갈 수 있음
> - EKS 노드: Private Subnet + Private IP → 인터넷 직접 접근 불가

### pposiraegi 리소스별 정리

| 리소스 | 서브넷 | IP 종류 | 인터넷 접근 |
|--------|--------|---------|-----------|
| ALB | Public | Public (AWS 관리) | 가능 (CloudFront에서) |
| NAT GW | Public | EIP (고정) | 아웃바운드만 |
| EKS 노드 | Private | Private | 불가 (NAT GW 경유) |
| RDS | Private | Private | 불가 |
| Redis | Private | Private | 불가 |
| Pod IP | Private | Private | 불가 |

---

## 3. NAT Gateway

> [!note] 핵심 개념
> NAT(Network Address Translation) — Private IP를 Public IP로 변환해서 인터넷으로 내보내는 장치.
> **단방향**: Private → 인터넷은 가능, 인터넷 → Private는 불가.

### 동작 원리

```
EKS 노드 (10.0.11.5)
  → NAT GW (100.x.x.x EIP로 변환)
    → IGW
      → ECR (인터넷)

응답:
  ECR → IGW → NAT GW (역변환: EIP → 10.0.11.5)
    → EKS 노드
```

외부에서 보면 요청 출처가 EIP 하나로만 보임. 노드 IP는 숨겨짐.

### pposiraegi에서 NAT GW가 필요한 이유

Private Subnet의 EKS 노드들이 인터넷으로 나가야 하는 트래픽:

| 트래픽 | 이유 |
|--------|------|
| ECR 이미지 pull | 컨테이너 이미지 가져오기 (VPC Endpoint 없음) |
| EC2 API 호출 | Karpenter가 Spot 노드 프로비저닝 |
| SQS 호출 | Karpenter Spot Interruption 이벤트 수신 |
| Secrets Manager | External Secrets Operator 시크릿 동기화 |
| CloudWatch Logs | 로그 전송 |

> [!warning] 현재 단일 NAT GW 구조의 비용 주의
> `public_a` 하나에만 배치.
> AZ-b(10.0.12.x) 노드의 아웃바운드 트래픽이 AZ 경계를 넘어 AZ-a NAT GW로 나감.
> → AZ 간 데이터 전송 비용($0.01/GB) + NAT GW 데이터 처리 비용($0.045/GB) 이중 발생.
> 고가용성이 필요하면 AZ별 NAT GW 배치가 맞지만 비용 증가.

---

## 4. CloudFront — 왜 쓰는지

> [!note] 핵심 개념
> CloudFront = AWS CDN(Content Delivery Network).
> 전 세계 엣지 서버에서 컨텐츠를 캐싱해 지연시간 감소 + 보안 레이어 추가.

### "그냥 CDN이니까" 보다 깊은 이유

#### 성능

- React 빌드 파일(JS/CSS/이미지)을 S3에서 직접 서빙하면 서울 리전까지 매번 왕복
- CloudFront 엣지에서 캐싱 → 유저 근처에서 응답 (`default_ttl: 3600`)

#### 라우팅 분기

```
pposiraegi.cloud
  /api/*  → ALB → EKS (api-gateway)   # TTL: 0 (캐싱 안 함)
  /*      → S3  → React 빌드 파일      # TTL: 3600
```

같은 도메인으로 프론트/백엔드를 분리 서빙. 브라우저 CORS 문제도 없음.

#### 보안

```
ALB SG 인바운드 규칙:
  출처: CloudFront managed prefix list만 허용
  → ALB 주소 직접 접근 완전 차단

S3 버킷:
  퍼블릭 액세스 전부 차단
  OAC(Origin Access Control)로 CloudFront만 S3 접근 가능
```

> [!example] 멘토 질문 답변 예시
> "CloudFront를 쓰는 이유가 CDN 성능 외에도,
> ALB와 S3를 퍼블릭에 직접 노출하지 않고 CloudFront 뒤에 숨겨서
> 보안 레이어로도 활용하고 있습니다.
> 또 같은 도메인으로 정적/동적 요청을 경로 기반으로 분기할 수 있어서
> CORS 설정 복잡도도 줄었습니다."

---

## 5. Service & Ingress

> [!note] 핵심 개념
> Service: Pod에 안정적인 고정 진입점 제공 (Pod IP는 재시작마다 바뀜).
> Ingress: 외부 HTTP(S) 트래픽을 클러스터 내부로 라우팅하는 규칙.

### Service 타입

| 타입 | 설명 | 접근 범위 |
|------|------|----------|
| ClusterIP | 클러스터 내부 전용 가상 IP | 클러스터 내부만 |
| NodePort | 노드의 고정 포트로 노출 | 노드 IP로 접근 가능 |
| LoadBalancer | 클라우드 LB 자동 생성 | 인터넷 |

### Ingress

```yaml
# 일반적인 Ingress 사용 예
kind: Ingress
metadata:
  annotations:
    kubernetes.io/ingress.class: alb
spec:
  rules:
  - http:
      paths:
      - path: /api
        backend:
          service:
            name: api-gateway
            port: 8080
```

→ AWS LBC가 이 Ingress를 보고 ALB를 자동 생성하고 관리.

### pposiraegi의 선택: Ingress 없음

```
일반 방식:  Ingress → AWS LBC → ALB 생성/소유
우리 방식:  Terraform → ALB 생성/소유
            TargetGroupBinding → Pod IP를 TG에 등록
```

**왜 Ingress를 안 쓰냐:**
- ALB 소유권을 Terraform에 완전히 주기 위해
- Ingress 방식은 AWS LBC가 ALB를 만들어서 Terraform state와 충돌 가능
- `terraform destroy`하면 Ingress가 만든 ALB는 그대로 남는 문제

**TargetGroupBinding이 하는 일:**

```yaml
kind: TargetGroupBinding
spec:
  targetGroupName: pposiraegi-tg   # Terraform이 만든 TG
  targetType: ip                    # 노드 아닌 Pod IP 직접 등록
  serviceRef:
    name: api-gateway
    port: 8080
```

AWS LBC가 이걸 보고 api-gateway Pod IP들을 TG에 자동 등록/해제.
Service는 ClusterIP로 충분 — ALB가 직접 Pod IP로 보냄.

> [!example] 한 줄 정리
> "Service는 Pod 앞단의 고정 주소이고, Ingress는 외부 트래픽을 Service로 연결하는 라우팅 규칙입니다.
> 우리 프로젝트는 Ingress 대신 Terraform ALB + TargetGroupBinding 패턴을 써서
> 인프라 소유권을 Terraform 단일로 유지합니다."

---

## 6. Image Tag

> [!note] 핵심 개념
> 컨테이너 이미지를 식별하는 레이블. 버전 추적과 롤백의 기준이 됨.

### 태그 전략 종류

| 전략 | 예시 | 특징 |
|------|------|------|
| `latest` | `api-gateway:latest` | 편리하지만 버전 추적 불가 |
| Git SHA | `api-gateway:a3f9c2b` | 정확한 버전 추적, 롤백 가능 |
| 시맨틱 버전 | `api-gateway:1.2.3` | 명시적이지만 수동 관리 |
| 날짜+SHA | `api-gateway:20260512-a3f9c2b` | 가독성 + 추적 |

### pposiraegi 현재 상태와 문제

```yaml
# CI에서 두 태그로 push
IMAGE_TAG: ${{ github.sha }}
# → ECR에 sha 태그 + latest 태그 둘 다 push

# Deployment는 latest 고정
image: 779846782353.dkr.ecr.../pposiraegi-api-gateway:latest
# imagePullPolicy 미선언 → 기본값 IfNotPresent
```

**문제:**
- `imagePullPolicy: IfNotPresent` + `latest` → latest가 바뀌어도 기존 노드에서 재pull 안 함
- 어떤 sha가 실제로 돌고 있는지 Deployment만 봐서는 알 수 없음
- 롤백 시 "이전 버전"이 명확하지 않음

**개선 방향:**

```yaml
# CI에서 sha 태그로 deployment 업데이트
image: 779846782353.dkr.ecr.../pposiraegi-api-gateway:${{ github.sha }}
imagePullPolicy: IfNotPresent  # sha 태그는 불변이므로 IfNotPresent OK
```

GitOps(ArgoCD) 환경이면 manifest의 image tag를 sha로 커밋 → ArgoCD가 감지하고 자동 배포.

> [!tip] `imagePullPolicy` 규칙
> - `latest` 태그: `Always` 써야 변경 감지 가능 (매 시작마다 pull)
> - sha/버전 태그: `IfNotPresent` OK (태그가 불변이므로)

---

## 🎯 전체 흐름 한 눈에

```
[사용자] → Route53 (pposiraegi.cloud)
  → CloudFront (HTTPS 종료, 엣지 캐싱)
      ├── /*    → S3 (React 정적 파일, OAC)
      └── /api/* → ALB (Public Subnet, CIDR: 10.0.1/24, 10.0.2/24)
                    → TargetGroupBinding (Pod IP 직접 등록)
                      → api-gateway Pod (Private Subnet, 10.0.11/24)
                          → ztunnel mTLS → waypoint L7
                            → user/product/order-service
                                → RDS :5432 / Redis :6379

아웃바운드 (이미지 pull, AWS API):
  EKS 노드 (10.0.11.x, Private IP)
    → NAT GW (Public Subnet, EIP: Public IP로 변환)
      → IGW → ECR / AWS API
```

---

## 📊 개념 연결 관계

| 개념 | 연결 개념 |
|------|----------|
| CIDR | VPC 설계, 서브넷 분리 |
| Public/Private IP | NAT GW 필요성, 보안 격리 |
| NAT GW | Private 서브넷 아웃바운드, 비용 |
| CloudFront | 보안(ALB 은닉), 성능(캐싱), 라우팅 분기 |
| Service (ClusterIP) | Pod 고정 진입점, TargetGroupBinding과 연동 |
| Ingress vs TGB | IaC 소유권, Terraform 일관성 |
| Image Tag | 배포 추적, 롤백, imagePullPolicy |
