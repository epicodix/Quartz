---
title: 'GCP VPC 핵심 분석: 클라우드 네트워크의 기초와 실제'
summary: GCP VPC의 글로벌 스코프, 서브넷, 방화벽 규칙 등 핵심 개념을 기술적으로 분석하고, `gcloud` 명령어 예시를 통해 실무적인
  이해를 돕는 문서입니다. 클라우드 네트워크의 기초를 다룹니다.
tags:
- GCP
- VPC
- Network
- Firewall
- gcloud
category: 기술분석
difficulty: 중급
estimated_time: 15분
created: '2025-10-30'
updated: '2025-11-08'
tech_stack:
- GCP
- gcloud
---

# GCP VPC 핵심 분석: 클라우드 네트워크의 기초와 실제

VPC(Virtual Private Cloud)는 Google Cloud Platform(GCP) 내에서 사용자의 프로젝트별로 격리된 프라이빗 네트워크 공간을 제공하는 글로벌 서비스입니다. 모든 GCP 리소스(VM, GKE, Cloud SQL 등)는 VPC 네트워크 내에 생성되어야 하며, 이는 보안과 통신의 가장 기본적인 경계를 설정합니다.

이 글은 GCP VPC의 핵심 특징과 주요 구성 요소를 기술적인 관점에서 설명하고, 실제 `gcloud` 명령어 예시를 통해 실무적인 이해를 돕는 것을 목표로 합니다.

---

### 1. GCP VPC의 핵심 특징: 글로벌(Global) 스코프

타사 클라우드의 VPC가 특정 리전(Region)에 종속되는 것과 달리, GCP의 VPC는 **글로벌 리소스**라는 매우 중요한 특징을 가집니다.

-   **기술적 의미:** 하나의 VPC가 전 세계 모든 GCP 리전에 걸쳐 존재하는 논리적인 네트워크 경계입니다. VPC 자체는 리전을 갖지 않으며, 그 하위 구성 요소인 서브넷(Subnet)이 각 리전에 속하게 됩니다.
-   **아키텍처 관점의 이점:** 이 글로벌 특성 덕분에, 별도의 VPN이나 복잡한 피어링(Peering) 설정 없이도 **서로 다른 리전에 있는 VM들이 동일 VPC 내에서 내부 IP로 직접 통신**할 수 있습니다. 이는 글로벌 서비스 아키텍처를 매우 단순화시키는 강력한 장점입니다.
    -   **예시:** 서울 리전(`asia-northeast3`)의 웹 서버와 런던 리전(`europe-west2`)의 데이터베이스 서버가 같은 VPC 내에 있다면, 추가 설정 없이 내부 IP 주소를 사용하여 서로 통신할 수 있습니다.

---

### 2. 서브넷 (Subnetwork): 리전 단위의 IP 주소 범위

서브넷은 VPC 내에서 특정 리전에 할당되는 IP 주소 범위(CIDR block)입니다. 모든 리소스(VM, GKE 노드 등)는 반드시 특정 리전의 서브넷 내에 생성되어야 하며, 해당 서브넷의 IP 범위 내에서 내부 IP를 할당받습니다.

#### 모드 (Modes)

1.  **Auto Mode VPC:**
    -   프로젝트 생성 시 기본으로 만들어지는 `default` VPC가 이 모드입니다.
    -   GCP의 모든 리전에 미리 정의된 CIDR 범위(`10.128.0.0/20`, `10.132.0.0/20` 등)의 서브넷이 자동으로 생성됩니다.
    -   빠른 테스트나 학습용으로는 편리하지만, IP 주소 범위가 중복될 수 있어 프로덕션 환경에는 권장되지 않습니다.

2.  **Custom Mode VPC:**
    -   프로덕션 환경에서 반드시 사용해야 하는 방식입니다.
    -   VPC를 직접 생성하고, 필요한 리전에 원하는 IP 범위의 서브넷을 수동으로 만듭니다. 이를 통해 체계적인 IP 주소 관리(IPAM)가 가능해집니다.

#### `gcloud` 예시

```bash
# 1. Custom Mode VPC 생성
gcloud compute networks create my-custom-vpc --subnet-mode=custom

# 2. 위 VPC 내에 서울 리전(asia-northeast3)용 서브넷 생성
gcloud compute networks subnets create my-seoul-subnet \
  --network=my-custom-vpc \
  --region=asia-northeast3 \
  --range=10.10.1.0/24
```

---

### 3. 방화벽 규칙 (Firewall Rules): 트래픽 통제의 핵심

GCP 방화벽 규칙은 VPC 네트워크 레벨에서 동작하는 **상태 저장(Stateful)** 방화벽입니다. 즉, 허용된 요청(Request)에 대한 응답(Response) 트래픽은 별도의 규칙 없이 자동으로 허용됩니다.

#### 주요 구성 요소

-   **방향 (Direction):** `INGRESS` (수신) 또는 `EGRESS` (송신)
-   **작업 (Action):** `ALLOW` 또는 `DENY`
-   **소스/대상 (Source/Destination):** 트래픽의 출발지 또는 목적지를 지정합니다.
    -   `--source-ranges` / `--destination-ranges`: IP CIDR 블록 (예: `0.0.0.0/0`은 모든 IP)
    -   `--target-tags`: 특정 네트워크 태그가 지정된 VM에만 규칙 적용
    -   `--target-service-accounts`: 특정 서비스 계정을 사용하는 VM에만 규칙 적용 (Tags보다 권장)
-   **프로토콜/포트 (Protocol/Ports):** 허용하거나 거부할 프로토콜과 포트 번호 (예: `tcp:22`, `tcp:80`, `icmp`)

#### 기본 규칙

-   **묵시적 거부 (Implied Deny):** 우선순위가 가장 낮은 규칙으로, 다른 어떤 규칙과도 일치하지 않는 모든 수신(Ingress) 트래픽을 거부합니다.
-   **묵시적 허용 (Implied Allow):** 우선순위가 가장 낮은 규칙으로, 다른 어떤 규칙과도 일치하지 않는 모든 송신(Egress) 트래픽을 허용합니다.

#### `gcloud` 예시

```bash
# 'web-server' 태그가 지정된 모든 VM에 대해 외부로부터의 HTTP(80) 트래픽 허용
gcloud compute firewall-rules create allow-http-ingress \
  --network=my-custom-vpc \
  --direction=INGRESS \
  --action=ALLOW \
  --rules=tcp:80 \
  --source-ranges=0.0.0.0/0 \
  --target-tags=web-server
```

---

### 4. 라우트 (Routes)와 외부 연결

라우트는 특정 목적지로 가는 트래픽을 어떤 다음 홉(Next Hop)으로 보낼지 정의하는 규칙입니다. 대부분의 경우 GCP가 자동으로 관리해 줍니다.

-   **시스템 생성 라우트:** VPC 내 서브넷 간 통신, 인터넷으로 나가는 기본 경로(`0.0.0.0/0`) 등이 자동으로 생성됩니다.
-   **Cloud NAT (Network Address Translation):** 외부 IP가 없는 비공개 VM이 외부 인터넷(예: GitHub에서 소스 다운로드, 외부 API 호출)에 접근해야 할 때 사용합니다. Cloud NAT 게이트웨이를 통해 여러 VM이 공유된 공인 IP를 사용하여 아웃바운드 통신을 할 수 있게 됩니다.
-   **비공개 Google 액세스 (Private Google Access):** 외부 IP가 없는 VM이 Google의 다른 서비스(예: Google Storage, BigQuery, Artifact Registry)에 접근할 때, 비싼 인터넷 트래픽을 사용하지 않고 Google의 내부 네트워크를 통해 안전하고 빠르게 접근하도록 허용하는 기능입니다.

---

## 결론

GCP VPC는 단순한 네트워크 격리 도구를 넘어, **글로벌 스코프**와 **자동화된 라우팅**, **계층적인 방화벽 규칙**, 다양한 연결 옵션을 제공하는 강력한 클라우드 네트워킹의 핵심입니다. Auto/Custom 모드의 차이를 이해하고, 태그나 서비스 계정을 활용한 방화벽 규칙을 효과적으로 설계하며, Cloud NAT과 같은 외부 연결 옵션을 적절하게 사용하는 것이 안전하고 효율적인 GCP 아키텍처 설계의 첫걸음입니다.

---

**작성일**: 2025-10-30
