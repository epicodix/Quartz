---
title: GCP Professional Cloud Architect 완전 정복 가이드
summary: '현재는 개념 나열 위주인데, **"언제 무엇을 선택해야 하는가"** 관점 추가:'
tags:
- 미분류
category: 기타
difficulty: 중급
estimated_time: 30분
created: '2025-10-31'
updated: '2025-11-08'
---



### **1. 각 섹션에 실전 의사결정 트리 추가**

현재는 개념 나열 위주인데, **"언제 무엇을 선택해야 하는가"** 관점 추가:

```
#### 로드 밸런서 선택 가이드
┌─ 웹 애플리케이션 (HTTP/HTTPS)?
│  ├─ 글로벌 + URL 라우팅 필요 → Global External Application LB
│  └─ 리전 내부만 → Regional Internal Application LB
│
└─ TCP/UDP 트래픽?
   ├─ 클라이언트 IP 보존 필요 → External Passthrough Network LB
   ├─ SSL 오프로드 필요 → SSL Proxy LB
   └─ 내부 트래픽만 → Internal Passthrough Network LB
```

### **2. 자주 헷갈리는 개념 비교표 추가**

**예시: Labels vs Tags vs Annotations**

markdown

```markdown
| 구분 | Labels | Network Tags | Kubernetes Annotations |
|------|--------|--------------|------------------------|
| 용도 | 비용 추적/관리 | 방화벽 규칙 적용 | 메타데이터 저장 |
| 적용 대상 | 모든 GCP 리소스 | Compute Engine VM | Kubernetes 객체 |
| 청구서 필터링 | ✅ | ❌ | ❌ |
| 네트워크 정책 | ❌ | ✅ | ❌ |
```

**예시: Storage 선택**

markdown

```markdown
| 요구사항 | 추천 서비스 | 이유 |
|---------|-----------|------|
| 파일 공유 (NFS) | Filestore | NFS 프로토콜 지원 |
| VM 블록 스토리지 | Persistent Disk | VM에 직접 연결 |
| 객체 스토리지 | Cloud Storage | 비정형 데이터, 저렴 |
| 고성능 병렬 I/O | Hyperdisk | 높은 IOPS 필요 시 |
```

### **3. 실전 시나리오별 솔루션 패턴**

markdown

```markdown
#### 시나리오 패턴 1: "비용 최적화 + 고가용성"
문제 신호: "cost-effective", "highly available"
솔루션 조합:
- Compute: Preemptible VM + MIG + Autoscaling
- Storage: Nearline/Coldline for archival
- Database: Cloud SQL HA (동일 리전 내 다중 존)
주의: DR까지 필요하면 Cross-region replica 추가

#### 시나리오 패턴 2: "IP 주소 보존 필요"
문제 신호: "client IP address", "IP-based authentication"
솔루션:
- ✅ External Passthrough Network LB
- ✅ Preserve client IP 옵션
- ❌ SSL Proxy (IP 변경함)
- ❌ HTTP(S) LB (X-Forwarded-For 헤더로만 확인 가능)
```

### **4. 핵심 숫자/제한사항 추가**

markdown

```markdown
#### 알아야 할 숫자들
- **Cloud Bigtable 지연시간**: Single-digit milliseconds (10ms 미만)
- **VPC Peering**: 최대 25개까지 연결 가능
- **Shared VPC**: 동일 조직 내에서만 가능
- **Preemptible VM**: 최대 24시간까지만 실행
- **Custom Machine Type**: 
  - vCPU: 1개 또는 짝수(2, 4, 6...)
  - Memory: vCPU당 0.9~6.5GB
- **GKE Node Pool**: 최소 3개 노드 권장 (고가용성)
```

### **5. 오답 함정 패턴 추가**

markdown

```markdown
#### 자주 나오는 오답 패턴
1. **"Pod에 replica 설정"** → ❌ Deployment에 설정
2. **"Labels로 방화벽 규칙"** → ❌ Network Tags 사용
3. **"GKE가 멀티클라우드"** → ❌ GCP 전용 (Terraform이 멀티클라우드)
4. **"IAP만으로 위치 기반 제어"** → ❌ VPC Service Controls 필요
5. **"VPC Flow Logs 자동 활성화"** → ❌ 명시적으로 활성화해야 함
```

### **6. 서비스 조합별 Use Case**

markdown

`````markdown
#### 자주 출제되는 서비스 조합

**IoT 데이터 파이프라인**
````
IoT Device → ClearBlade IoT Core → Pub/Sub 
→ Dataflow (스트리밍 처리) 
→ BigQuery (분석) / Bigtable (실시간 조회)
→ Cloud Storage Nearline (장기 보관)
````

**CI/CD 파이프라인**
````
Cloud Source Repo → Cloud Build (자동 트리거)
→ Container Registry → GKE (Deployment)
→ Cloud Monitoring (관측)
````

**멀티리전 웹 앱 DR**
````
Global External ALB → MIG (리전 A + 리전 B)
Cloud SQL HA + Cross-region Replica
Multi-region Cloud Storage (백업)
````

### **7. 명령어 예시 추가**
````markdown
#### 자주 사용하는 명령어

**Kubernetes Autoscaling**
```bash
kubectl autoscale deployment my-app \
  --min=3 --max=10 --cpu-percent=70
```

**Terraform 워크플로우**
```bash
terraform init      # 초기화
terraform plan      # 변경 사항 미리보기
terraform apply     # 적용
terraform destroy   # 리소스 삭제
```

**gcloud 기본**
```bash
gcloud compute instances create INSTANCE_NAME \
  --machine-type=e2-medium \
  --preemptible \
  --network-tags=web-server
```
````

### **8. 약어 및 용어 Glossary 추가**
````markdown
#### 필수 약어 정리
- **MIG**: Managed Instance Group
- **HPA**: Horizontal Pod Autoscaler
- **VPA**: Vertical Pod Autoscaler
- **ALB**: Application Load Balancer
- **NLB**: Network Load Balancer
- **PVC**: PersistentVolumeClaim
- **WAF**: Web Application Firewall
- **SCC**: Security Command Center
- **IAP**: Identity-Aware Proxy
- **SLI**: Service Level Indicator (측정값)
- **SLO**: Service Level Objective (목표)
- **SLA**: Service Level Agreement (계약)
````

### **9. 체크리스트 형식 문제 해결 가이드**
````markdown
#### 문제 풀이 체크리스트

**보안 문제 나올 때:**
□ 네트워크 레벨: VPC Service Controls? Firewall rules?
□ 인스턴스 레벨: Shielded VM? Service Account?
□ 애플리케이션 레벨: IAP? Cloud Armor?
□ 데이터 레벨: CMEK? Customer-managed encryption?
□ 감사: VPC Flow Logs? Cloud Audit Logs?

**성능/확장성 문제 나올 때:**
□ 수평 확장: MIG Autoscaling? GKE HPA?
□ 부하 분산: 적절한 LB 선택?
□ 캐싱: Cloud CDN? Memorystore?
□ 데이터베이스: Read replica? Connection pooling?
□ 모니터링: Cloud Monitoring? Cloud Trace?
````

### **10. 섹션별 "자주 틀리는 이유" 추가**
````markdown
#### Module 2에서 20% 받은 이유 분석

**1번 문제 (20% 오답)**
- 틀린 이유: Pod vs Deployment 개념 혼동
- 핵심: Pod는 배포 단위 ❌, Deployment가 replica 관리 ✅
- 기억법: "Deploy(배포)ment가 replica를 배치(deploy)"

**3번 문제 (오답)**
- 틀린 이유: SSL Proxy가 IP 주소를 보존한다고 착각
- 핵심: IP 보존 = Passthrough LB만 가능
- 기억법: "Pass(통과)through = IP가 그대로 통과"
````

---

## 🎯 최종 추천 구조
`````

[기존 개념 정리] ↓ [의사결정 트리] ← 언제 뭘 쓸지 ↓ [비교표] ← 헷갈리는 것들 ↓ [실전 패턴] ← 자주 나오는 조합 ↓ [오답 함정] ← 실수 방지 ↓ [체크리스트] ← 문제 풀 때 확인사항

```

이렇게 보완하면 단순 암기가 아니라 **실전 문제 해결 능력**이 크게 향상될 것입니다! 

특정 섹션 먼저 디벨롭해드릴까요? 아니면 Module 2 재시험 대비 집중 정리가 필요하신가요?
```


# GCP Professional Cloud Architect 완전 정복 가이드

---

## 📚 Module 1: Designing and Planning a Cloud Solution Architecture

### 1 비즈니스 요구사항 분석

#### 핵심 개념

- **KPI (Key Performance Indicators)**: 비즈니스 성과를 측정하는 구체적 지표
- **SLO (Service Level Objectives)**: 서비스가 달성해야 할 기술적 목표
- **SLA (Service Level Agreement)**: 고객과의 서비스 수준 계약

#### 의사결정 트리: 비즈니스 요구사항 우선순위

````
비즈니스 요구사항 분석 시작
│
├─ 비용이 최우선인가?
│  ├─ Yes → Preemptible VM, Committed Use Discounts, Sustained Use Discounts
│  └─ No → 다음 단계
│
├─ 규정 준수가 필수인가?
│  ├─ Yes → VPC Service Controls, CMEK, Compliance Reports (SCC)
│  └─ No → 다음 단계
│
├─ 글로벌 서비스인가?
│  ├─ Yes → Multi-region 리소스, Global Load Balancer, Cloud CDN
│  └─ No → Regional 리소스로 비용 절감
│
└─ 고가용성 요구사항은?
   ├─ 99.99% 이상 → Multi-region + Active-Active
   ├─ 99.9% 이상 → Regional HA + Automated failover
   └─ 그 외 → Single-zone + Manual recovery
```

#### 실전 시나리오 패턴

**패턴 1: "Cost-effective + Scalable"**
```
문제 신호: "minimize costs", "handle variable load", "budget constraints"

솔루션 조합:
✅ Compute: 
   - Preemptible VMs (80% 할인, 최대 24시간)
   - MIG with Autoscaling (수요 기반 확장)
   - E2 machine types (범용 워크로드, 저렴)
   
✅ Storage:
   - Standard Storage → Nearline (30일) → Coldline (90일) → Archive (365일)
   - Lifecycle Management로 자동 전환
   
✅ Database:
   - Cloud SQL (소규모) vs Spanner (글로벌)
   - Read Replicas로 읽기 부하 분산

❌ 피해야 할 것:
   - N1 machine types (구세대, 비쌈)
   - 고정 용량 리소스 (낭비)
   - Multi-region (불필요 시)
```

**패턴 2: "High Availability + Low Latency"**
```
문제 신호: "99.99% uptime", "sub-second response", "global users"

솔루션 조합:
✅ Compute:
   - Regional MIG (여러 존에 분산)
   - Global External Application LB (지리적 근접성 라우팅)
   
✅ Database:
   - Cloud Spanner (multi-region, 99.999% SLA)
   - Cloud Bigtable (single-digit ms latency)
   
✅ Caching:
   - Cloud CDN (정적 컨텐츠)
   - Memorystore (Redis/Memcached)
   
✅ 네트워크:
   - Premium Tier (Google backbone 사용)
   - Cloud Armor (DDoS 방어)

실제 아키텍처:
[Users] → [Cloud CDN] → [Global LB] 
    → [MIG Zone A] [MIG Zone B] [MIG Zone C]
    → [Memorystore] + [Cloud Spanner]
```

---

### 2 기술 요구사항 설계

#### Compute 선택 가이드
```
Compute 서비스 선택 플로우차트
│
├─ 컨테이너 기반인가?
│  ├─ Yes → Kubernetes 필요?
│  │  ├─ Yes → GKE (관리형 Kubernetes)
│  │  └─ No → Cloud Run (서버리스 컨테이너)
│  └─ No → 다음 단계
│
├─ 서버 관리를 최소화하고 싶은가?
│  ├─ Yes → 언어/프레임워크는?
│  │  ├─ Python/Java/Go/Node.js → App Engine Standard
│  │  ├─ 커스텀 런타임 → App Engine Flexible
│  │  └─ 이벤트 기반 → Cloud Functions
│  └─ No → Compute Engine (VM)
│
└─ VM이 필요한 경우
   ├─ 워크로드 특성은?
   │  ├─ 단기 실행, 내결함성 → Preemptible VM
   │  ├─ 안정적 예측 가능 → Standard VM
   │  └─ 고성능 필요 → N2 or C2 machine types
   │
   └─ 스케일링 필요?
      ├─ Yes → Managed Instance Group
      └─ No → Unmanaged Instance Group
````

#### Machine Type 비교표

|Machine Type|vCPU|Memory/vCPU|용도|비용|
|---|---|---|---|---|
|**E2**|2-32|0.5-8 GB|범용, 비용 최적화|💰|
|**N2**|2-80|0.5-8 GB|균형잡힌 성능|💰💰|
|**N2D**|2-224|0.5-8 GB|AMD 기반, 가성비|💰💰|
|**C2**|4-60|4 GB (고정)|컴퓨팅 집약적|💰💰💰|
|**M2**|4-416|28-59 GB|메모리 집약적|💰💰💰💰|
|**Custom**|1+|0.9-6.5 GB|정확한 사양 필요|변동|

#### 스토리지 선택 가이드

markdown

````markdown
┌─ 어떤 데이터인가?
│
├─ 블록 스토리지 (VM에 연결)?
│  ├─ 표준 성능 → Standard Persistent Disk
│  ├─ 고성능 SSD → SSD Persistent Disk
│  ├─ 최고 성능 → Hyperdisk (수십만 IOPS)
│  └─ 임시 데이터 → Local SSD (VM 종료 시 삭제)
│
├─ 파일 스토리지 (NFS)?
│  ├─ 완전 관리형 → Filestore
│  └─ 초고성능 → Filestore Enterprise
│
├─ 객체 스토리지?
│  ├─ 자주 접근 → Standard Storage
│  ├─ 월 1회 미만 → Nearline (30일)
│  ├─ 분기 1회 미만 → Coldline (90일)
│  └─ 연 1회 미만 → Archive (365일)
│
└─ 구조화된 데이터 (데이터베이스)?
   └─ 아래 데이터베이스 섹션 참조
```

#### 데이터베이스 선택 가이드
```
데이터베이스 선택 Decision Tree
│
├─ 관계형 데이터베이스 필요?
│  ├─ Yes → 확장성 요구사항은?
│  │  ├─ 글로벌, 수평 확장 → Cloud Spanner
│  │  ├─ 리전, 수직 확장 → Cloud SQL
│  │  └─ PostgreSQL 호환 + 확장 → AlloyDB
│  │
│  └─ No → NoSQL 선택
│     │
│     ├─ 문서 기반 (모바일/웹)?
│     │  └─ Firestore (실시간 동기화)
│     │
│     ├─ 대용량, 낮은 지연시간?
│     │  └─ Cloud Bigtable (IoT, 시계열, 분석)
│     │
│     ├─ 인메모리 캐시?
│     │  └─ Memorystore (Redis/Memcached)
│     │
│     └─ 데이터 웨어하우스?
│        └─ BigQuery (페타바이트급 분석)
````

#### 데이터베이스 비교표

|서비스|유형|최대 크기|지연시간|Use Case|비용|
|---|---|---|---|---|---|
|**Cloud SQL**|RDBMS|64TB|10-100ms|일반 웹앱, OLTP|💰💰|
|**Cloud Spanner**|RDBMS|무제한|10ms|글로벌 애플리케이션|💰💰💰💰|
|**AlloyDB**|PostgreSQL|64TB+|<10ms|엔터프라이즈 워크로드|💰💰💰|
|**Firestore**|NoSQL 문서|무제한|<100ms|모바일/웹 앱|💰|
|**Bigtable**|NoSQL Wide-column|페타바이트|1-10ms|IoT, 시계열|💰💰💰|
|**BigQuery**|Data Warehouse|페타바이트|초 단위|분석, BI|💰💰|
|**Memorystore**|In-memory|300GB|<1ms|캐싱|💰💰|

#### 알아야 할 숫자들

markdown

````markdown
#### 성능 기준
- **Cloud Bigtable**: Single-digit milliseconds (1-9ms)
- **Cloud Spanner**: 글로벌 strong consistency, <10ms
- **Memorystore**: Sub-millisecond (<1ms)
- **Persistent Disk**: 
  - Standard: ~20 IOPS/GB
  - SSD: ~30 IOPS/GB
  - Hyperdisk: 최대 350,000 IOPS

#### 용량 제한
- **VPC Peering**: 최대 25개 VPC 연결
- **Shared VPC**: 최대 100개 서비스 프로젝트
- **Cloud SQL**: 
  - MySQL: 최대 64TB
  - PostgreSQL: 최대 64TB
- **Preemptible VM**: 최대 24시간 실행
- **GKE Node Pool**: 노드당 최대 110개 Pod

#### 네트워크
- **VPC Subnet**: /29 ~ /8 CIDR 블록
- **RFC 1918 사설 IP**:
  - Class A: 10.0.0.0/8
  - Class B: 172.16.0.0/12
  - Class C: 192.168.0.0/16
```

---

### 3 네트워크 아키텍처 설계

#### Load Balancer 선택 완전 가이드
```
Load Balancer 선택 플로우차트
│
├─ 트래픽 유형은?
│  │
│  ├─ HTTP/HTTPS 웹 트래픽
│  │  │
│  │  ├─ 글로벌 서비스인가?
│  │  │  ├─ Yes → **Global External Application LB**
│  │  │  │          기능: URL 맵, SSL 종료, Cloud CDN, Cloud Armor
│  │  │  │          Use case: 전 세계 사용자 대상 웹앱
│  │  │  │
│  │  │  └─ No (리전 내) → **Regional External Application LB**
│  │  │             Use case: 단일 리전 웹앱
│  │  │
│  │  └─ 내부 트래픽만? → **Regional Internal Application LB**
│  │                     Use case: 마이크로서비스 간 통신
│  │
│  └─ TCP/UDP 트래픽 (Non-HTTP)
│     │
│     ├─ 클라이언트 IP 보존 필요?
│     │  ├─ Yes → **External Passthrough Network LB**
│     │  │         ⚠️ 중요: IP 주소가 변경되지 않음
│     │  │         Use case: IP 기반 인증, 게임 서버
│     │  │
│     │  └─ No (SSL 오프로드 필요) → **SSL Proxy LB** or **TCP Proxy LB**
│     │                               Use case: 레거시 앱, SSL 종료
│     │
│     └─ 내부 트래픽만? → **Internal Passthrough Network LB**
│                        Use case: 내부 서비스 간 TCP/UDP
```

#### Load Balancer 비교표

| Load Balancer | Layer | 범위 | IP 보존 | SSL 종료 | URL 라우팅 | Use Case |
|--------------|-------|------|---------|---------|-----------|----------|
| **Global External Application** | L7 | 글로벌 | ❌ (헤더) | ✅ | ✅ | 글로벌 웹앱 |
| **Regional External Application** | L7 | 리전 | ❌ (헤더) | ✅ | ✅ | 리전 웹앱 |
| **Regional Internal Application** | L7 | 리전 | ✅ | ✅ | ✅ | 내부 마이크로서비스 |
| **External Passthrough Network** | L4 | 리전 | ✅ | ❌ | ❌ | IP 보존 필요 |
| **Internal Passthrough Network** | L4 | 리전 | ✅ | ❌ | ❌ | 내부 TCP/UDP |
| **SSL Proxy** | L4 | 글로벌 | ❌ | ✅ | ❌ | SSL 오프로드 |
| **TCP Proxy** | L4 | 글로벌 | ❌ | ❌ | ❌ | 글로벌 TCP |

#### Global External Application Load Balancer 구조
```
[전 세계 사용자들]
        ↓
[Anycast IP: 하나의 글로벌 IP 주소]
        ↓
[Global Forwarding Rule] ← SSL 인증서 연결
        ↓
[Target HTTPS Proxy] ← URL Map 확인
        ↓
[URL Map] ← 경로 기반 라우팅
    ├─ /api/* → Backend Service A
    ├─ /images/* → Backend Service B (Cloud CDN 활성화)
    └─ /* → Backend Service C (기본)
        ↓
[Backend Services] ← Health Check, Session Affinity
        ↓
[Instance Groups]
    ├─ us-central1 MIG (3 instances)
    ├─ europe-west1 MIG (3 instances)
    └─ asia-east1 MIG (2 instances)

💡 트래픽 분산 방식:
- 지리적 근접성 (가장 가까운 백엔드)
- 백엔드 용량 (최소 부하)
- Health Check 통과한 인스턴스만
```

#### VPC 네트워크 패턴

**패턴 1: VPC Peering (다른 조직 간 연결)**
```
조직 A - 프로젝트 1                조직 B - 프로젝트 2
    VPC-A (10.1.0.0/16) ←--Peering--→ VPC-B (10.2.0.0/16)
         ↓                                    ↓
    Subnet-A1                            Subnet-B1
    10.1.1.0/24                          10.2.1.0/24

✅ 사용 시기:
- 다른 조직과 비공개 통신
- 서브넷 IP 범위가 겹치지 않음
- 양방향 Peering 필요

❌ 제약사항:
- 최대 25개 VPC Peering
- Transitive peering 불가 (A↔B, B↔C일 때 A↔C 자동 연결 안됨)
- IP 범위 중복 불가
```

**패턴 2: Shared VPC (동일 조직 내 공유)**
```
조직 A
├─ Host Project (VPC 소유)
│  └─ Shared VPC (10.0.0.0/16)
│      ├─ Subnet-us-central1 (10.0.1.0/24)
│      └─ Subnet-us-east1 (10.0.2.0/24)
│
└─ Service Projects (VPC 사용)
   ├─ Project-Dev → Shared VPC 사용
   ├─ Project-Test → Shared VPC 사용
   └─ Project-Prod → Shared VPC 사용

✅ 사용 시기:
- 동일 조직 내 여러 프로젝트
- 중앙 집중식 네트워크 관리
- IP 주소 낭비 방지

👤 IAM 역할:
- Shared VPC Admin (조직 레벨)
- Service Project Admin (프로젝트 레벨)
```

**패턴 3: Hybrid Connectivity (온프레미스 연결)**
```
온프레미스 데이터센터
        ↓
    [선택지]
        ↓
┌───────┴───────┐
│               │
▼               ▼
Cloud VPN    Interconnect
(저렴, 간단)   (고성능, 안정)
│               │
├─ 99.9% SLA   ├─ 99.99% SLA
├─ 1.5-3 Gbps  ├─ 10-100 Gbps
└─ IPsec 터널   └─ 전용 연결
        │               │
        └───────┬───────┘
                ↓
            [VPC Router]
                ↓
        [Subnet in GCP]

🔐 Cloud VPN 선택 시나리오:
- 낮은 트래픽 (<1 Gbps)
- 빠른 구축 필요
- 예산 제약

⚡ Interconnect 선택 시나리오:
- 높은 트래픽 (>10 Gbps)
- 낮은 지연시간 필수
- 미션 크리티컬 워크로드
```

---

### 4 마이그레이션 전략

#### 마이그레이션 의사결정 트리
```
온프레미스 → GCP 마이그레이션 전략
│
├─ 리팩토링 없이 빠르게 이전?
│  ├─ Yes → **Lift and Shift**
│  │         방법: Migrate for Compute Engine
│  │         대상: VM 기반 레거시 앱
│  │         기간: 주 단위
│  │         위험: 낮음
│  │
│  └─ No → 다음 단계
│
├─ 컨테이너화 가능?
│  ├─ Yes → **Migrate to Containers**
│  │         방법: Migrate for Anthos
│  │         대상: 상태 비저장 앱
│  │         기간: 월 단위
│  │         혜택: 자동 확장, 효율성
│  │
│  └─ No → 다음 단계
│
├─ 마이크로서비스로 분해?
│  ├─ Yes → **Re-architect**
│  │         방법: GKE, Cloud Run, App Engine
│  │         대상: 모놀리식 앱
│  │         기간: 분기 단위
│  │         혜택: 최대 클라우드 이점
│  │
│  └─ No → 하이브리드 접근
│
└─ 데이터베이스 마이그레이션?
   ├─ MySQL/PostgreSQL → Cloud SQL (Database Migration Service)
   ├─ Oracle/SQL Server → Cloud SQL or AlloyDB
   ├─ MongoDB → Firestore or Bigtable
   └─ 데이터 웨어하우스 → BigQuery
```

#### 마이그레이션 패턴별 비교

| 패턴 | 복잡도 | 기간 | 비용 절감 | 클라우드 이점 | 위험도 |
|------|-------|------|----------|-------------|--------|
| **Lift & Shift** | ⭐ | 1-4주 | 10-20% | ⭐ | 낮음 |
| **Improve & Move** | ⭐⭐ | 1-3개월 | 20-30% | ⭐⭐ | 중간 |
| **Migrate to Containers** | ⭐⭐⭐ | 2-4개월 | 30-50% | ⭐⭐⭐ | 중간 |
| **Re-architect** | ⭐⭐⭐⭐⭐ | 6-12개월 | 50-70% | ⭐⭐⭐⭐⭐ | 높음 |

#### 실전 마이그레이션 시나리오

**시나리오 1: E-commerce 모놀리식 앱 마이그레이션**
```
현재 상태:
- 온프레미스 Ubuntu VM 10대
- MySQL 데이터베이스
- 정적 파일 (이미지, CSS)
- 피크 시간대 성능 문제

단계별 접근:
Phase 1 (1개월): Lift & Shift
├─ VM → Compute Engine MIG
├─ MySQL → Cloud SQL
└─ 정적 파일 → Cloud Storage + Cloud CDN

Phase 2 (3개월): Modernize
├─ MIG → GKE Deployment
├─ 모놀리스 → 마이크로서비스 분해
│  ├─ 인증 서비스
│  ├─ 제품 카탈로그 서비스
│  ├─ 주문 처리 서비스
│  └─ 결제 서비스
└─ Cloud SQL → Spanner (글로벌 확장)

Phase 3 (6개월): Optimize
├─ Cloud CDN 최적화
├─ Memorystore 캐싱 추가
├─ Cloud Armor WAF 적용
└─ Cloud Monitoring 대시보드
````

---

### 5 Kubernetes 아키텍처 패턴

#### StatefulSet vs Deployment

markdown

````markdown
┌─ 애플리케이션 상태는?
│
├─ 상태 비저장 (Stateless)
│  → **Deployment** 사용
│  
│  특징:
│  ✅ Pod 이름이 랜덤 (nginx-abc123)
│  ✅ 순서 없이 생성/삭제
│  ✅ 어떤 Pod든 동일한 역할
│  ✅ 수평 확장 쉬움
│  
│  Use Case:
│  - 웹 서버 (nginx, Apache)
│  - API 서버
│  - 프론트엔드 앱
│  
│  예시:
│  ```yaml
│  apiVersion: apps/v1
│  kind: Deployment
│  metadata:
│    name: web-app
│  spec:
│    replicas: 3
│    selector:
│      matchLabels:
│        app: web
│    template:
│      metadata:
│        labels:
│          app: web
│      spec:
│        containers:
│        - name: nginx
│          image: nginx:1.21
│  ```
│
└─ 상태 저장 (Stateful)
   → **StatefulSet** 사용
   
   특징:
   ✅ Pod 이름이 고정 (mysql-0, mysql-1)
   ✅ 순서대로 생성/삭제
   ✅ 각 Pod는 고유 식별자
   ✅ PersistentVolumeClaim 자동 생성
   
   Use Case:
   - 데이터베이스 (MySQL, PostgreSQL)
   - 메시지 큐 (Kafka, RabbitMQ)
   - 분산 파일 시스템
   
   예시:
```yaml
   apiVersion: apps/v1
   kind: StatefulSet
   metadata:
     name: mysql
   spec:
     serviceName: mysql
     replicas: 3
     selector:
       matchLabels:
         app: mysql
     template:
       metadata:
         labels:
           app: mysql
       spec:
         containers:
         - name: mysql
           image: mysql:8.0
           volumeMounts:
           - name: data
             mountPath: /var/lib/mysql
     volumeClaimTemplates:
     - metadata:
         name: data
       spec:
         accessModes: ["ReadWriteOnce"]
         resources:
           requests:
             storage: 10Gi
```
```

#### Kubernetes 스토리지 계층 구조
```
Kubernetes 스토리지 계층
│
├─ PersistentVolume (PV)
│  └─ 클러스터 레벨 리소스
│     관리자가 프로비저닝
│     예: GCE Persistent Disk, Filestore
│
├─ PersistentVolumeClaim (PVC)
│  └─ 네임스페이스 레벨 리소스
│     사용자가 요청
│     PV를 동적/정적으로 바인딩
│
├─ StorageClass
│  └─ 동적 프로비저닝 정의
│     PVC 생성 시 자동으로 PV 생성
│     예: standard, ssd, balanced
│
└─ Volume
   └─ Pod 레벨 리소스
      PVC를 마운트하여 사용

실제 흐름:
1. StorageClass 정의 (관리자)
2. PVC 생성 (개발자)
   ↓
3. StorageClass에 따라 PV 자동 생성
   ↓
4. PVC와 PV 바인딩
   ↓
5. Pod가 PVC를 볼륨으로 마운트
   ↓
6. 컨테이너에서 /data 경로로 접근
````

---

### 6 자주 틀리는 문제 패턴

#### 오답 함정 TOP 10

markdown

```markdown
❌ 함정 1: "Pod에 replicas 설정"
✅ 정답: Deployment에 replicas 설정
🧠 기억법: Pod는 최소 단위, Deploy(배포)ment가 여러 개 배치

❌ 함정 2: "Labels로 방화벽 규칙 적용"
✅ 정답: Network Tags 사용
🧠 기억법: 
   - Labels = 라벨지 = 비용 청구서에 붙임
   - Tags = 태그 = 네트워크에 태그

❌ 함정 3: "GKE가 멀티클라우드 지원"
✅ 정답: Terraform이 멀티클라우드, GKE는 GCP 전용
🧠 기억법: K(Kubernetes)는 Google 제품

❌ 함정 4: "SSL Proxy가 클라이언트 IP 보존"
✅ 정답: Passthrough LB만 IP 보존
🧠 기억법: Pass(통과)through = IP가 변경 없이 통과

❌ 함정 5: "VPC Flow Logs 자동 활성화"
✅ 정답: 수동으로 활성화 필요
🧠 기억법: 비용이 발생하므로 명시적 활성화

❌ 함정 6: "IAP로 지리적 접근 제어"
✅ 정답: VPC Service Controls 필요
🧠 기억법: IAP = Identity(신원), VPC SC = Location(위치)

❌ 함정 7: "Shared VPC로 다른 조직 연결"
✅ 정답: VPC Peering 사용 (Shared VPC는 동일 조직만)
🧠 기억법: Shared = 가족끼리 공유, Peering = 친구와 연결

❌ 함정 8: "Preemptible VM으로 데이터베이스 운영"
✅ 정답: Standard VM 사용 (Preemptible은 24시간 내 종료됨)
🧠 기억법: Preemptible = 선점 = 언제든 빼앗김 = 중요 작업 불가

❌ 함정 9: "BigQuery는 OLTP 데이터베이스"
✅ 정답: BigQuery는 OLAP (분석용), Cloud SQL/Spanner가 OLTP
🧠 기억법: Big = 큰 데이터 = 분석, SQL = 작은 트랜잭션

❌ 함정 10: "Cloud CDN으로 동적 콘텐츠 캐싱"
✅ 정답: Cloud CDN은 정적 콘텐츠만, 동적은 Memorystore
🧠 기억법: CDN = Content Delivery = 변하지 않는 파일 배포
```

---

### 7 실전 문제 풀이 체크리스트

#### 보안 문제가 나왔을 때

markdown

```markdown
□ **네트워크 레벨**
  ├─ 외부 공격 차단? → Cloud Armor (DDoS, WAF)
  ├─ 방화벽 규칙? → VPC Firewall Rules + Network Tags
  ├─ 프라이빗 통신? → Private Google Access
  └─ 데이터 경계? → VPC Service Controls

□ **인스턴스 레벨**
  ├─ VM 무결성? → Shielded VM (vTPM, Integrity Monitoring)
  ├─ 최소 권한? → Service Account (not default!)
  ├─ OS 패치? → OS Patch Management
  └─ 비밀 관리? → Secret Manager

□ **애플리케이션 레벨**
  ├─ 사용자 인증? → IAP (Identity-Aware Proxy)
  ├─ API 보호? → API Gateway + Cloud Endpoints
  ├─ 컨테이너 보안? → Binary Authorization
  └─ 코드 취약점? → Cloud Security Scanner

□ **데이터 레벨**
  ├─ 암호화 키 관리? → CMEK (Customer-Managed Encryption Keys)
  ├─ 전송 중 암호화? → SSL/TLS 필수
  ├─ 저장 시 암호화? → 기본 활성화 (Google-managed)
  └─ 민감 데이터 검출? → Cloud DLP (Data Loss Prevention)

□ **감사 및 모니터링**
  ├─ 누가 무엇을? → Cloud Audit Logs (Admin, Data Access)
  ├─ 네트워크 흐름? → VPC Flow Logs
  ├─ 위협 탐지? → Security Command Center (SCC)
  └─ 컴플라이언스? → Compliance Reports Manager
```

#### 성능/확장성 문제가 나왔을 때

markdown

```markdown
□ **수평 확장 (Scale Out)**
  ├─ VM → MIG + Autoscaling Policy
  ├─ GKE → HPA (Horizontal Pod Autoscaler)
  ├─ App Engine → Automatic Scaling
  └─ Cloud Functions → Concurrent executions

□ **부하 분산**
  ├─ HTTP/HTTPS? → Application Load Balancer
  ├─ TCP/UDP? → Network Load Balancer
  ├─ 글로벌? → Global LB
  └─ 리전? → Regional LB

□ **캐싱 전략**
  ├─ 정적 콘텐츠? → Cloud CDN
  ├─ 데이터베이스 쿼리? → Memorystore (Redis)
  ├─ API 응답? → Cloud Endpoints Caching
  └─ 세션 데이터? → Memorystore

□ **데이터베이스 최적화**
  ├─ 읽기 부하? → Read Replicas
  ├─ 쓰기 부하? → Sharding (Spanner, Bigtable)
  ├─ 연결 관리? → Cloud SQL Proxy + Connection Pooling
  └─ 쿼리 최적화? → Query Insights

□ **모니터링 및 진단**
  ├─ 메트릭 수집? → Cloud Monitoring
  ├─ 로그 분석? → Cloud Logging
  ├─ 트레이싱? → Cloud Trace
  └─ 프로파일링? → Cloud Profiler
```

#### 비용 최적화 문제가 나왔을 때

markdown

````markdown
□ **Compute 비용 절감**
  ├─ 단기 작업? → Preemptible VMs (80% 할인)
  ├─ 예측 가능? → Committed Use Discounts (57% 할인, 1-3년)
  ├─ 장기 실행? → Sustained Use Discounts (자동 30% 할인)
  ├─ 적정 크기? → Rightsizing Recommendations
  └─ 유휴 리소스? → Idle VM Recommender

□ **Storage 비용 절감**
  ├─ 접근 빈도?
  │  ├─ 매일 → Standard Storage
  │  ├─ 월 1회 → Nearline (30일)
  │  ├─ 분기 1회 → Coldline (90일)
  │  └─ 연 1회 → Archive (365일)
  ├─ 자동 전환? → Lifecycle Management
  └─ 중복 데이터? → Deduplication (Filestore)

□ **네트워크 비용 절감**
  ├─ 인터넷 이그레스? → Cloud CDN으로 캐싱
  ├─ 리전 간 통신? → 동일 리전 배치
  ├─ 외부 IP? → Internal IP 사용
  └─ NAT? → Cloud NAT 대신 Private Google Access

□ **데이터베이스 비용 절감**
  ├─ 개발/테스트? → Cloud SQL Shared-core instances
  ├─ 사용하지 않을 때? → Automated Backups + 인스턴스 삭제
  ├─ 읽기 전용? → Read Replicas (비용 절감)
  └─ BigQuery? → Partitioning + Clustering

□ **비용 모니터링**
  ├─ 예산 알림? → Budget Alerts
  ├─ 비용 분석? → Cost Table + Labels
  ├─ 프로젝트별 추적? → Billing Accounts
  └─ 리소스 할당? → Quotas
```

---

### 8 서비스 조합별 실전 아키텍처

#### IoT 데이터 파이프라인
```
실시간 IoT 데이터 처리 아키텍처

[수백만 IoT 디바이스]
        ↓ MQTT/HTTP
[ClearBlade IoT Core] ← 디바이스 관리, 인증
        ↓
[Cloud Pub/Sub] ← 메시지 버퍼링 (at-least-once delivery)
        ↓
    ┌───┴───┐
    ↓       ↓
[Dataflow] [Cloud Functions]
(스트리밍)  (이벤트 처리)
    ↓       ↓
    ├───────┤
    ↓       ↓
[BigQuery] [Bigtable]
(분석)     (실시간 조회)
    ↓
[Looker/Data Studio]
(시각화)
    
병렬 처리:
[Pub/Sub] → [Cloud Storage] ← 원본 데이터 보관 (Archive)

핵심 결정 포인트:
- Pub/Sub: 메시지 유실 방지 (7일 보관)
- Dataflow: 윈도우 기반 집계 (1분 단위)
- Bigtable: 낮은 지연시간 읽기 (<10ms)
- BigQuery: 대용량 히스토리컬 분석
```

#### CI/CD 파이프라인
```
완전 자동화된 배포 파이프라인

[개발자 Git Push]
        ↓
[Cloud Source Repositories] ← 프라이빗 Git 저장소
        ↓ Trigger
[Cloud Build] ← 빌드 자동화
    │
    ├─ Step 1: 코드 테스트 (pytest, jest)
    ├─ Step 2: 컨테이너 이미지 빌드
    ├─ Step 3: 취약점 스캔 (Container Analysis)
    ├─ Step 4: 이미지 푸시
    │
    ↓
[Artifact Registry] ← 컨테이너 이미지 저장소
        ↓
[GKE Deployment] ← Kubernetes 배포
    │
    ├─ Dev 환경 (자동 배포)
    ├─ Staging 환경 (자동 배포)
    └─ Prod 환경 (수동 승인)
        ↓
[Cloud Monitoring] ← SLI/SLO 추적
[Cloud Logging] ← 로그 집계

고급 패턴:
- Binary Authorization: 서명된 이미지만 배포
- Canary Deployment: 트래픽 점진적 이동 (5% → 50% → 100%)
- Rollback: 이전 버전으로 즉시 복구
```

#### 멀티리전 웹 애플리케이션 (DR)
```
재해 복구가 포함된 글로벌 웹 앱

[전 세계 사용자]
        ↓
[Cloud DNS] ← 지리적 라우팅
        ↓
[Global External Application LB]
        ↓
    ┌───┴───┐
    ↓       ↓
[us-central1] [europe-west1]
    │            │
    ├─ MIG (3 zones) ← Active
    ├─ MIG (3 zones) ← Active
    │            │
    ↓            ↓
[Cloud SQL HA] [Cloud SQL Replica]
Primary (RW)   Read Replica (RO)
    │            │
    └────┬───────┘
         ↓ Cross-region replication
         
[Multi-region Cloud Storage] ← 정적 파일
    │
    └─ 자동 복제 (us + eu)

재해 복구 시나리오:
1. us-central1 장애 발생
2. Health Check 실패 감지 (10초)
3. LB가 트래픽을 europe-west1로 자동 라우팅
4. Cloud SQL Read Replica를 Primary로 승격
5. 복구 시간: <5분

SLA 계산:
- Global LB: 99.99%
- Cloud SQL HA: 99.95%
- Cloud Storage Multi-region: 99.95%
= 전체 SLA: ~99.89%
```

#### 마이크로서비스 아키텍처 (Anthos Service Mesh)
```
클라우드 네이티브 마이크로서비스

[Frontend Service]
        ↓
[Istio Ingress Gateway] ← TLS 종료, 라우팅
        ↓
    ┌───┴────────┐
    ↓            ↓
[Auth Service] [API Gateway Service]
    ↓            ↓
    └────┬───────┘
         ↓
    ┌────┴────┐────┐────┐
    ↓         ↓    ↓    ↓
[Product] [Order] [Payment] [Inventory]
Service   Service Service  Service
    │         │      │        │
    ├─────────┼──────┼────────┤
    ↓         ↓      ↓        ↓
[Memorystore Redis] ← 세션/캐시 공유
    │
    ↓
[Cloud SQL] / [Spanner] / [Firestore]
(각 서비스별 독립 DB)

Istio Service Mesh 기능:
✅ 트래픽 관리: 
   - Canary Deployment (10% 트래픽)
   - Circuit Breaker (실패 시 차단)
   - Retry Logic (자동 재시도)

✅ 보안:
   - mTLS (서비스 간 암호화)
   - RBAC (역할 기반 접근 제어)
   - JWT 검증

✅ 관측성:
   - Distributed Tracing (Cloud Trace)
   - 서비스 메시 메트릭 (Prometheus)
   - 로그 집계 (Cloud Logging)
````

---

### 9 약어 및 용어 Glossary

#### 필수 약어 정리

markdown

```markdown
**Infrastructure**
- MIG: Managed Instance Group (자동 확장 VM 그룹)
- NEG: Network Endpoint Group (엔드포인트 그룹)
- VPC: Virtual Private Cloud (가상 사설 네트워크)
- CIDR: Classless Inter-Domain Routing (IP 주소 표기법)

**Kubernetes**
- GKE: Google Kubernetes Engine
- HPA: Horizontal Pod Autoscaler (Pod 수평 확장)
- VPA: Vertical Pod Autoscaler (Pod 수직 확장)
- PVC: PersistentVolumeClaim (스토리지 요청)
- PV: PersistentVolume (스토리지 리소스)
- CRD: Custom Resource Definition (커스텀 리소스)

**Networking**
- ALB: Application Load Balancer (L7)
- NLB: Network Load Balancer (L4)
- CDN: Content Delivery Network (콘텐츠 배포 네트워크)
- BGP: Border Gateway Protocol (라우팅 프로토콜)
- NAT: Network Address Translation (주소 변환)
- IAP: Identity-Aware Proxy (신원 기반 프록시)

**Security**
- IAM: Identity and Access Management
- CMEK: Customer-Managed Encryption Keys
- mTLS: mutual TLS (양방향 TLS)
- WAF: Web Application Firewall
- SCC: Security Command Center
- DLP: Data Loss Prevention (데이터 유출 방지)
- CSEK: Customer-Supplied Encryption Keys

**Observability**
- SLI: Service Level Indicator (측정 가능한 지표)
  예: 응답 시간, 에러율, 가용성
- SLO: Service Level Objective (목표)
  예: 99.9% 가용성, 응답시간 <200ms
- SLA: Service Level Agreement (계약)
  예: 99.95% 보장, 위반 시 환불
- MTTR: Mean Time To Repair (평균 복구 시간)
- MTTF: Mean Time To Failure (평균 고장 시간)

**Database**
- OLTP: Online Transaction Processing (트랜잭션 처리)
  예: Cloud SQL, Spanner
- OLAP: Online Analytical Processing (분석 처리)
  예: BigQuery
- RPO: Recovery Point Objective (데이터 손실 허용 시간)
- RTO: Recovery Time Objective (복구 목표 시간)

**Development**
- CI/CD: Continuous Integration/Continuous Deployment
- IaC: Infrastructure as Code (Terraform, Deployment Manager)
- GitOps: Git 기반 운영 방식
- Blue/Green: 두 환경을 번갈아 배포
- Canary: 일부 트래픽만 신버전으로
```

---

### 🔟 자주 사용하는 명령어

#### gcloud 핵심 명령어

bash

```bash
# ===== 프로젝트 관리 =====
gcloud config set project PROJECT_ID
gcloud config list
gcloud projects list

# ===== Compute Engine =====
# VM 인스턴스 생성
gcloud compute instances create INSTANCE_NAME \
  --zone=us-central1-a \
  --machine-type=e2-medium \
  --preemptible \
  --boot-disk-size=20GB \
  --boot-disk-type=pd-standard \
  --network-tags=web-server \
  --metadata=startup-script='#!/bin/bash
    apt-get update
    apt-get install -y nginx'

# MIG 생성
gcloud compute instance-groups managed create WEB_MIG \
  --base-instance-name=web \
  --template=web-template \
  --size=3 \
  --region=us-central1

# Autoscaling 설정
gcloud compute instance-groups managed set-autoscaling WEB_MIG \
  --min-num-replicas=3 \
  --max-num-replicas=10 \
  --target-cpu-utilization=0.7 \
  --cool-down-period=90

# ===== VPC 네트워크 =====
# VPC 생성
gcloud compute networks create MY_VPC \
  --subnet-mode=custom

# 서브넷 생성
gcloud compute networks subnets create MY_SUBNET \
  --network=MY_VPC \
  --region=us-central1 \
  --range=10.0.1.0/24 \
  --enable-private-ip-google-access

# 방화벽 규칙
gcloud compute firewall-rules create ALLOW_HTTP \
  --network=MY_VPC \
  --allow=tcp:80 \
  --source-ranges=0.0.0.0/0 \
  --target-tags=web-server

# ===== Cloud SQL =====
# 인스턴스 생성
gcloud sql instances create INSTANCE_NAME \
  --database-version=MYSQL_8_0 \
  --tier=db-n1-standard-1 \
  --region=us-central1 \
  --enable-bin-log \
  --backup-start-time=03:00

# 복제본 생성
gcloud sql instances create READ_REPLICA \
  --master-instance-name=INSTANCE_NAME \
  --tier=db-n1-standard-1 \
  --region=us-east1
```

#### kubectl 핵심 명령어

bash

```bash
# ===== Deployment 관리 =====
# Deployment 생성
kubectl create deployment my-app \
  --image=gcr.io/PROJECT_ID/my-app:v1 \
  --replicas=3

# Deployment 업데이트 (Rolling Update)
kubectl set image deployment/my-app \
  my-app=gcr.io/PROJECT_ID/my-app:v2 \
  --record

# Rollback
kubectl rollout undo deployment/my-app

# 히스토리 확인
kubectl rollout history deployment/my-app

# ===== Autoscaling =====
# HPA 설정
kubectl autoscale deployment my-app \
  --min=3 \
  --max=10 \
  --cpu-percent=70

# HPA 상태 확인
kubectl get hpa

# ===== Service 관리 =====
# ClusterIP Service (내부 통신)
kubectl expose deployment my-app \
  --port=80 \
  --target-port=8080 \
  --type=ClusterIP

# LoadBalancer Service (외부 노출)
kubectl expose deployment my-app \
  --port=80 \
  --target-port=8080 \
  --type=LoadBalancer

# ===== ConfigMap & Secret =====
# ConfigMap 생성
kubectl create configmap app-config \
  --from-literal=DB_HOST=mysql.default.svc.cluster.local \
  --from-literal=DB_PORT=3306

# Secret 생성
kubectl create secret generic db-secret \
  --from-literal=username=admin \
  --from-literal=password=secret123

# ===== 디버깅 =====
# Pod 로그 확인
kubectl logs POD_NAME -f

# Pod 내부 접속
kubectl exec -it POD_NAME -- /bin/bash

# 이벤트 확인
kubectl get events --sort-by='.lastTimestamp'

# 리소스 사용량
kubectl top pods
kubectl top nodes
```

#### Terraform 워크플로우

bash

```bash
# ===== 초기화 =====
terraform init      # 플러그인 다운로드

# ===== 계획 =====
terraform plan      # 변경 사항 미리보기
terraform plan -out=tfplan  # 계획 저장

# ===== 적용 =====
terraform apply     # 리소스 생성/변경
terraform apply tfplan  # 저장된 계획 적용
terraform apply -auto-approve  # 승인 없이 적용

# ===== 확인 =====
terraform show      # 현재 상태 표시
terraform state list  # 관리 중인 리소스 목록
terraform state show google_compute_instance.vm  # 특정 리소스 상세

# ===== 삭제 =====
terraform destroy   # 모든 리소스 삭제
terraform destroy -target=google_compute_instance.vm  # 특정 리소스만

# ===== 형식 및 검증 =====
terraform fmt       # 코드 포맷팅
terraform validate  # 문법 검증

# ===== Workspace =====
terraform workspace list  # Workspace 목록
terraform workspace new dev  # 새 Workspace
terraform workspace select prod  # Workspace 전환
```

#### Cloud Build 예시 (`cloudbuild.yaml`)

yaml

````yaml
steps:
  # Step 1: 코드 테스트
  - name: 'python:3.9'
    entrypoint: 'pytest'
    args: ['tests/']

  # Step 2: Docker 이미지 빌드
  - name: 'gcr.io/cloud-builders/docker'
    args: ['build', '-t', 'gcr.io/$PROJECT_ID/my-app:$COMMIT_SHA', '.']

  # Step 3: 이미지 푸시
  - name: 'gcr.io/cloud-builders/docker'
    args: ['push', 'gcr.io/$PROJECT_ID/my-app:$COMMIT_SHA']

  # Step 4: GKE 배포
  - name: 'gcr.io/cloud-builders/kubectl'
    args:
      - 'set'
      - 'image'
      - 'deployment/my-app'
      - 'my-app=gcr.io/$PROJECT_ID/my-app:$COMMIT_SHA'
    env:
      - 'CLOUDSDK_COMPUTE_REGION=us-central1'
      - 'CLOUDSDK_CONTAINER_CLUSTER=production-cluster'

images:
  - 'gcr.io/$PROJECT_ID/my-app:$COMMIT_SHA'
```

---

### 11 Module 2 재시험 집중 대비

#### Module 2에서 20% 받은 이유 분석

**자주 틀린 문제 패턴:**
1. Pod vs Deployment 개념 혼동
2. Load Balancer 유형 선택 오류
3. 스토리지 옵션 잘못된 선택
4. IAM 권한 범위 오해

#### 집중 복습 영역

**1. Kubernetes 리소스 계층 구조**
```
Cluster (클러스터)
└─ Namespace (네임스페이스)
   └─ Deployment (배포 컨트롤러)
      └─ ReplicaSet (복제 컨트롤러)
         └─ Pod (최소 실행 단위)
            └─ Container (컨테이너)

❌ 틀린 사고: "Pod에 replicas 설정"
✅ 올바른 사고: 
   - Pod = 1개 이상의 컨테이너 묶음
   - Deployment = Pod의 desired state 관리
   - ReplicaSet = Pod 복제본 개수 유지 (Deployment가 자동 생성)
```

**2. Load Balancer 결정 트리 (재정리)**
```
문제: "사용자 IP 주소를 백엔드에서 확인해야 합니다"

❌ 오답 선택: SSL Proxy Load Balancer
   이유: SSL Proxy는 연결을 종료하고 새 연결을 생성 → IP 변경됨

✅ 정답: External Passthrough Network Load Balancer
   이유: DSR (Direct Server Return) 방식 → 원본 IP 보존

기억법: 
- "Passthrough" = 통과 = 변경 없이 그대로
- "Proxy" = 대리 = 중간에서 변경
```

**3. 스토리지 문제 해결 패턴**
```
시나리오별 정답:

Q: "여러 VM에서 동시에 읽기/쓰기가 필요합니다"
❌ Persistent Disk (ReadWriteOnce만 지원)
✅ Filestore (NFS, ReadWriteMany 지원)

Q: "VM 재시작 후에도 데이터 유지 필요"
❌ Local SSD (VM 종료 시 삭제)
✅ Persistent Disk (영구 저장)

Q: "수백만 개의 작은 파일 저장"
❌ Persistent Disk (파일시스템 오버헤드)
✅ Cloud Storage (객체 스토리지, 무제한)

Q: "데이터베이스용 고성능 스토리지"
❌ Standard Persistent Disk (낮은 IOPS)
✅ SSD Persistent Disk 또는 Hyperdisk
```

**4. IAM 권한 범위**
```
조직 계층 구조:
Organization (조직)
└─ Folder (폴더)
   └─ Project (프로젝트)
      └─ Resource (리소스)

권한 상속 규칙:
- 상위 레벨 권한 = 하위 모든 레벨에 적용
- 하위 레벨 권한 = 해당 레벨만 적용
- 권한 취소 불가 (하위에서 상위 권한 제거 불가)

예제:
Q: "프로젝트 A의 VM만 관리하는 권한"
❌ Organization-level Compute Admin
   → 모든 프로젝트의 VM 관리 가능 (과도한 권한)
✅ Project-level Compute Instance Admin
   → 해당 프로젝트만 관리

Q: "특정 Cloud Storage 버킷만 읽기"
❌ Project-level Storage Object Viewer
   → 프로젝트 내 모든 버킷 접근
✅ Bucket-level Storage Object Viewer
   → 특정 버킷만 접근
````

---

### 12 시험 직전 최종 체크리스트

#### 시험 시작 전 (5분)

markdown

```markdown
□ 계산기 준비 (비용 계산, SLA 계산)
□ 메모장 준비 (의사결정 트리 스케치용)
□ 타이머 설정 (문제당 평균 2분)
□ 심호흡 3회
```

#### 문제 풀이 순서

markdown

````markdown
1. 문제 읽기 (30초)
   └─ 키워드 밑줄: cost-effective, highly available, secure

2. 요구사항 분류 (20초)
   ├─ 필수 요구사항 (MUST): "must", "required", "ensure"
   ├─ 선호 요구사항 (SHOULD): "prefer", "ideally"
   └─ 제약사항 (CONSTRAINT): "cannot", "limited", "only"

3. 선택지 제거 (40초)
   ├─ 명백히 틀린 답 2개 제거
   └─ 남은 2개 중 요구사항 대조

4. 최종 선택 (30초)
   └─ 의심스러우면 플래그 + 다음 문제로
```

#### 문제 유형별 키워드 매핑

**비용 최적화**
```
키워드 발견 → 즉시 떠올려야 할 서비스

"cost-effective" → Preemptible VM, Committed Use Discounts
"minimize costs" → E2 machine types, Standard Storage
"budget constraints" → Autoscaling, Serverless (Cloud Run, Functions)
"pay only for what you use" → Cloud Functions, Cloud Run
````


````
**고가용성**
"99.99% uptime" → Multi-zone MIG, Cloud SQL HA
"high availability" → Regional resources, Load Balancer
"disaster recovery" → Cross-region replication, Backup
"no single point of failure" → Multi-zone deployment
"automatic failover" → Cloud SQL HA, MIG health checks
```

**보안**
```
"secure" → VPC Service Controls, CMEK
"compliance" → Compliance Reports, SCC
"encrypt" → CMEK (고객 관리), Google-managed (기본)
"least privilege" → Custom IAM roles, Service Accounts
"prevent data exfiltration" → VPC Service Controls
"DDoS protection" → Cloud Armor
"web application firewall" → Cloud Armor
```

**성능**
```
"low latency" → Memorystore, Cloud CDN, Bigtable
"sub-second" → Memorystore (<1ms)
"single-digit milliseconds" → Bigtable (1-9ms)
"real-time" → Pub/Sub, Dataflow streaming
"high throughput" → Bigtable, Hyperdisk
```

**확장성**
```
"scalable" → MIG Autoscaling, GKE HPA
"handle traffic spikes" → Autoscaling, Load Balancer
"millions of users" → Global Load Balancer, Cloud CDN
"elastic" → Managed services (GKE, Cloud Run)
```

---

### 13 실전 시험 시뮬레이션 문제

#### 문제 1: 아키텍처 설계 (자주 나오는 유형)
```
시나리오:
귀사는 전 세계 사용자를 대상으로 하는 전자상거래 웹사이트를 운영합니다.
다음 요구사항을 충족하는 아키텍처를 설계해야 합니다:
- 99.95% 이상의 가용성
- 지역별 낮은 지연시간 (<100ms)
- 비용 효율적인 솔루션
- DDoS 공격으로부터 보호

어떤 조합을 선택해야 합니까?

A) Regional External Application Load Balancer + Cloud Armor + MIG in single zone
B) Global External Application Load Balancer + Cloud CDN + Multi-region MIG + Cloud Armor
C) TCP Proxy Load Balancer + Cloud Armor + MIG in multiple zones
D) Internal Load Balancer + VPC Service Controls + Regional MIG

정답: B

해설:
✅ Global External Application LB:
   - 전 세계 사용자 대상 → 글로벌 LB 필수
   - 지리적 근접성 라우팅으로 지연시간 최소화

✅ Cloud CDN:
   - 정적 컨텐츠 캐싱으로 지연시간 감소
   - 오리진 서버 부하 감소 → 비용 절감

✅ Multi-region MIG:
   - 여러 리전 배포 → 고가용성
   - 한 리전 장애 시 자동 페일오버

✅ Cloud Armor:
   - DDoS 방어
   - WAF 규칙으로 악의적 트래픽 차단

❌ A가 틀린 이유: Single zone → 가용성 부족
❌ C가 틀린 이유: TCP Proxy는 HTTP 트래픽에 부적합
❌ D가 틀린 이유: Internal LB는 외부 사용자 접근 불가
```

#### 문제 2: 데이터베이스 선택 (헷갈리는 유형)
```
시나리오:
IoT 센서에서 초당 10만 건의 시계열 데이터가 들어옵니다.
데이터는 센서 ID와 타임스탬프로 조회되며, 10ms 이하의 읽기 지연시간이 필요합니다.
데이터는 3개월 후 BigQuery로 이동하여 분석합니다.

어떤 데이터베이스를 선택해야 합니까?

A) Cloud SQL with read replicas
B) Cloud Spanner
C) Cloud Bigtable
D) Firestore

정답: C

해설:
✅ Cloud Bigtable이 정답인 이유:
   - 시계열 데이터에 최적화 (row key = sensor_id#timestamp)
   - Single-digit millisecond 지연시간 (1-9ms)
   - 초당 수백만 건 쓰기 가능
   - BigQuery로 데이터 익스포트 지원

❌ A가 틀린 이유:
   - Cloud SQL은 OLTP용, 대량 시계열 데이터 부적합
   - 초당 10만 건 쓰기 처리 어려움

❌ B가 틀린 이유:
   - Spanner는 트랜잭션 일관성이 필요한 경우
   - 시계열 데이터에는 과도한 스펙 (비용 비효율)

❌ D가 틀린 이유:
   - Firestore는 모바일/웹 앱용
   - 대규모 시계열 데이터 처리에 부적합

기억법: "Time-series + Low latency = Bigtable"
```

#### 문제 3: 네트워킹 (IP 보존 함정)
```
시나리오:
레거시 애플리케이션이 클라이언트 IP 주소 기반으로 액세스 제어를 수행합니다.
TCP 트래픽을 처리하며, SSL 종료는 애플리케이션 레벨에서 수행합니다.
GCP로 마이그레이션하면서 이 기능을 유지해야 합니다.

어떤 로드 밸런서를 사용해야 합니까?

A) Global External Application Load Balancer
B) SSL Proxy Load Balancer
C) External Passthrough Network Load Balancer
D) Internal Passthrough Network Load Balancer

정답: C

해설:
✅ External Passthrough Network LB:
   - 클라이언트 IP 주소 보존 (DSR 방식)
   - TCP 트래픽 처리
   - Layer 4 로드 밸런싱
   - SSL 종료 안함 (애플리케이션에서 처리)

❌ A가 틀린 이유:
   - HTTP(S) 전용
   - 클라이언트 IP는 X-Forwarded-For 헤더로만 전달

❌ B가 틀린 이유:
   - SSL Proxy는 연결을 종료하고 새 연결 생성
   - 클라이언트 IP 변경됨

❌ D가 틀린 이유:
   - Internal LB는 VPC 내부 트래픽만 처리
   - 외부 클라이언트 접근 불가

핵심 포인트:
"Client IP preservation" + "TCP" = Passthrough Network LB
```

#### 문제 4: Kubernetes (Pod vs Deployment 함정)
```
시나리오:
GKE에서 웹 애플리케이션을 실행 중입니다.
트래픽 증가에 따라 자동으로 Pod 수를 3개에서 10개까지 확장하고 싶습니다.

어떻게 구성해야 합니까?

A) Pod 매니페스트에서 replicas: 3-10으로 설정
B) Deployment를 생성하고 HPA를 구성하여 min=3, max=10으로 설정
C) StatefulSet을 생성하고 replicas를 10으로 설정
D) Pod를 10개 생성하고 수동으로 관리

정답: B

해설:
✅ Deployment + HPA:
   - Deployment: desired state 관리 (replicas 설정)
   - HPA: CPU/Memory 기반 자동 확장
   - min=3, max=10으로 범위 지정

❌ A가 틀린 이유:
   - Pod 자체에는 replicas 설정 불가
   - Pod는 단일 인스턴스만 표현

❌ C가 틀린 이유:
   - StatefulSet은 상태 저장 앱용 (DB 등)
   - 웹 앱은 stateless → Deployment 사용

❌ D가 틀린 이유:
   - 수동 관리는 자동 확장 불가
   - Pod 장애 시 자동 복구 안됨

명령어:
```bash
kubectl create deployment web-app --image=nginx --replicas=3
kubectl autoscale deployment web-app --min=3 --max=10 --cpu-percent=70
```
```

#### 문제 5: 스토리지 선택 (접근 패턴 기반)
```
시나리오:
회사는 다음과 같은 데이터를 저장해야 합니다:
- 로그 파일: 30일간 자주 접근, 이후 분기별 1회 접근
- 사용자 업로드 이미지: 매일 접근
- 백업 파일: 연 1회 접근

비용 효율적인 스토리지 전략은?

A) 모든 데이터를 Standard Storage에 저장
B) 로그 → Nearline, 이미지 → Standard, 백업 → Coldline
C) 로그 → Standard + Lifecycle (30일 후 Nearline), 이미지 → Standard, 백업 → Archive
D) 모든 데이터를 Coldline에 저장

정답: C

해설:
✅ 최적 전략:
   - 로그 파일:
     ├─ 처음 30일: Standard (자주 접근)
     └─ 30일 후: Nearline (월 1회 미만)
   - 이미지: Standard (매일 접근)
   - 백업: Archive (연 1회 접근)

스토리지 클래스 비교:
| 클래스 | 접근 빈도 | 최소 보관 기간 | 비용 |
|--------|-----------|----------------|------|
| Standard | 자주 | 없음 | 💰💰💰 |
| Nearline | 월 1회 미만 | 30일 | 💰💰 |
| Coldline | 분기 1회 미만 | 90일 | 💰 |
| Archive | 연 1회 미만 | 365일 | 💰 (최저) |

Lifecycle Policy 예시:
```json
{
  "lifecycle": {
    "rule": [
      {
        "action": {"type": "SetStorageClass", "storageClass": "NEARLINE"},
        "condition": {"age": 30}
      }
    ]
  }
}
```

❌ B가 틀린 이유:
   - 로그를 처음부터 Nearline에 저장 → 30일간 빈번한 접근 시 비용 증가

❌ D가 틀린 이유:
   - 이미지를 Coldline에 저장 → 매일 접근 시 Early Deletion Fee 발생
```

---

### 14 시험 당일 Cheat Sheet (암기 카드)

#### 1분 안에 복습할 핵심 내용

**Load Balancer 선택**
```
HTTP/HTTPS?
  ├─ 글로벌? → Global External Application LB
  └─ 리전? → Regional External/Internal Application LB

TCP/UDP?
  ├─ IP 보존? → Passthrough Network LB
  └─ SSL 종료? → SSL/TCP Proxy LB
```

**Database 선택**
```
관계형?
  ├─ 글로벌 확장? → Spanner
  └─ 리전? → Cloud SQL / AlloyDB

NoSQL?
  ├─ 시계열/IoT? → Bigtable (<10ms)
  ├─ 문서형? → Firestore
  ├─ 캐시? → Memorystore (<1ms)
  └─ 분석? → BigQuery
```

**Compute 선택**
```
컨테이너?
  ├─ Kubernetes 필요? → GKE
  └─ 서버리스? → Cloud Run

코드만?
  ├─ 이벤트 기반? → Cloud Functions
  └─ 웹 앱? → App Engine

VM 필요?
  ├─ 내결함성? → Preemptible VM
  └─ 안정성? → Standard VM
```

**Storage 선택**
```
VM 블록? → Persistent Disk
파일 공유? → Filestore (NFS)
객체? → Cloud Storage
  ├─ 매일 접근 → Standard
  ├─ 월 1회 → Nearline
  ├─ 분기 1회 → Coldline
  └─ 연 1회 → Archive
```

**보안 체크리스트**
```
□ 네트워크: Cloud Armor (DDoS/WAF)
□ 접근 제어: IAP (Identity-Aware Proxy)
□ 암호화: CMEK (고객 관리 키)
□ 경계: VPC Service Controls
□ 감사: Cloud Audit Logs
□ VM: Shielded VM
```

**HA/DR 체크리스트**
```
□ 고가용성: Multi-zone MIG
□ 재해복구: Cross-region replica
□ 백업: Automated snapshots
□ 모니터링: Cloud Monitoring + Alerts
□ Health Check: LB health checks
```

**비용 최적화 체크리스트**
```
□ Compute: Preemptible VM, E2 types
□ Storage: Lifecycle management
□ Network: Same region, Private IPs
□ Database: Right-sizing, Read replicas
□ Committed Use: 1-3년 약정 (57% 할인)
```

---

### 15 자주 나오는 비교 시나리오

#### Shared VPC vs VPC Peering
```
┌─────────────────┬──────────────────┬──────────────────┐
│     구분        │   Shared VPC     │   VPC Peering    │
├─────────────────┼──────────────────┼──────────────────┤
│ 조직 요구사항   │ 동일 조직 내     │ 다른 조직 가능   │
│ 관리 주체       │ 중앙 집중식      │ 분산형           │
│ IAM 권한        │ 세분화 가능      │ 프로젝트 레벨    │
│ 방화벽 규칙     │ 중앙에서 관리    │ 각자 관리        │
│ IP 주소 관리    │ 중앙 할당        │ 각자 할당        │
│ Use Case        │ 같은 회사 내     │ 파트너사 연결    │
│                 │ 여러 프로젝트    │                  │
└─────────────────┴──────────────────┴──────────────────┘

시나리오:
Q: "같은 회사 내 Dev, Test, Prod 프로젝트를 연결"
✅ Shared VPC (중앙 관리 + IAM 세분화)

Q: "외부 파트너 회사의 GCP 프로젝트와 연결"
✅ VPC Peering (조직 간 연결)
```

#### Cloud SQL HA vs Read Replica
```
┌─────────────────┬──────────────────┬──────────────────┐
│     구분        │   HA Config      │  Read Replica    │
├─────────────────┼──────────────────┼──────────────────┤
│ 목적            │ 고가용성         │ 읽기 확장        │
│ 장애 조치       │ 자동 (초 단위)   │ 수동 승격        │
│ 복제 방식       │ 동기식           │ 비동기식         │
│ 쓰기 가능       │ Primary만        │ Replica는 읽기만 │
│ 지연시간        │ 약간 증가        │ 낮음 (읽기 부하) │
│ 리전            │ 동일 리전        │ 다른 리전 가능   │
│ Use Case        │ 장애 대응        │ 읽기 부하 분산   │
│                 │                  │ 지리적 분산      │
└─────────────────┴──────────────────┴──────────────────┘

조합 전략:
Primary (us-central1)
├─ HA Standby (us-central1-b) ← 고가용성
├─ Read Replica (us-east1) ← 읽기 확장
└─ Read Replica (europe-west1) ← DR + 글로벌 서비스
```

#### HPA vs VPA
```
┌─────────────────┬──────────────────┬──────────────────┐
│     구분        │   HPA            │   VPA            │
├─────────────────┼──────────────────┼──────────────────┤
│ 확장 방향       │ 수평 (Pod 수)    │ 수직 (리소스)    │
│ 메트릭          │ CPU, Memory,     │ CPU, Memory      │
│                 │ Custom           │                  │
│ 반응 속도       │ 빠름 (분 단위)   │ 느림 (Pod 재시작)│
│ 다운타임        │ 없음             │ 있음 (재시작)    │
│ Use Case        │ 트래픽 증가      │ 리소스 부족      │
│                 │                  │ 최적화           │
└─────────────────┴──────────────────┴──────────────────┘

언제 사용?
HPA: 트래픽 패턴이 변동적 (낮-밤, 평일-주말)
VPA: 리소스 요청량이 부적절 (너무 많거나 적음)

함께 사용 가능? ✅ Yes (CPU 기반 HPA + Memory 기반 VPA)
```

#### Preemptible VM vs Spot VM vs Standard VM
```
┌─────────────────┬──────────┬──────────┬──────────┐
│     구분        │Preemptible│  Spot   │ Standard │
├─────────────────┼──────────┼──────────┼──────────┤
│ 할인율          │ ~80%     │ 60-91%   │ 0%       │
│ 최대 실행 시간  │ 24시간   │ 없음     │ 무제한   │
│ 종료 알림       │ 30초     │ 30초     │ N/A      │
│ 가용성 보장     │ 없음     │ 없음     │ 있음     │
│ Use Case        │ 배치작업 │ 배치작업 │ 프로덕션 │
│                 │ CI/CD    │ CI/CD    │ 상시 서비스│
└─────────────────┴──────────┴──────────┴──────────┘

선택 가이드:
□ 24시간 이내 작업? → Preemptible
□ 장기 배치 작업? → Spot
□ 중요한 서비스? → Standard (+ MIG로 가용성 확보)
□ 비용이 최우선? → Preemptible/Spot + 재시작 로직
```

---

### 16 마지막 조언 및 시험 팁

#### 시험 중 시간 관리
```
총 시간: 120분 (2시간)
문제 수: 50-60문제
문제당 평균 시간: 2-2.4분

전략:
├─ 1차 풀이 (90분): 확실한 문제부터 빠르게
├─ 플래그 문제 재검토 (20분): 의심스러운 문제
└─ 최종 검토 (10분): 실수 확인

시간 분배:
□ 쉬운 문제 (30%): 1분 이내
□ 중간 문제 (50%): 2-3분
□ 어려운 문제 (20%): 4-5분 (플래그 후 나중에)
```

#### 문제 풀이 실수 방지
```
❌ 흔한 실수:
1. "가장 적합한" vs "유일한" 헷갈림
   → "best" = 여러 옵션 중 최선
   → "only" = 단 하나의 정답

2. 모든 요구사항 확인 안함
   → 체크리스트로 모든 조건 대조

3. 키워드 놓침
   → "minimize cost", "high availability" 밑줄

4. 시간에 쫓겨 급하게 선택
   → 플래그 후 나중에 재검토

5. 경험에만 의존
   → GCP 특화 기능 확인 (다른 클라우드와 다름)
```

#### 합격을 위한 마인드셋
```
✅ 자신감:
- 이 가이드 내용만 완벽히 이해해도 70% 이상 가능
- 모든 문제를 다 맞출 필요 없음 (합격선 70%)

✅ 전략:
- 확실한 문제부터 점수 확보
- 모르는 문제에 시간 낭비 금지
- 플래그 기능 적극 활용

✅ 평정심:
- 어려운 문제 나와도 당황하지 말기
- 모든 수험생이 동일한 난이도
- 2-3개 틀려도 합격 가능

✅ 실전 연습:
- 공식 Practice Exam 필수
- Coursera "Preparing for Professional Cloud Architect"
- Qwiklabs 핸즈온 LAB 권장
```

#### 시험 후 결과 확인
```
즉시 확인:
- 시험 종료 후 10분 내 Pass/Fail 표시
- 섹션별 점수 (%) 확인

합격 시:
□ 인증서 다운로드 (PDF)
□ LinkedIn 프로필에 추가
□ Credly 디지털 배지 수령
□ 유효기간: 2년

불합격 시:
□ 섹션별 약점 파악
□ 14일 후 재응시 가능
□ 이 가이드로 약점 집중 복습
□ Practice Exam 재도전
````

---

**작성일**: 2025-10-31
