---
title: SAA-C03 응용력 강화 - 결정 로직 (2026-03-12 47오답 기반)
tags:
  - SAA-C03
  - AWS
  - 자격증
  - 오답분석
  - 결정로직
date: 2026-03-12
status: 진행중
priority: 긴급
---

# 🎯 SAA-C03 응용력 강화 — 결정 로직

> [!danger] 핵심 문제
> 키워드 암기는 됨. 패턴이 조금만 바뀌면 같은 답을 못 찾음.
> 이 노트는 **왜(Why) 그 서비스인지 로직**을 다룬다.
> 키워드가 아니라 **조건의 조합**으로 판단하는 훈련.

---

## 📑 목차
- [[#1. SQS 디커플링과 세션 관리|SQS 디커플링 / 세션 관리]]
- [[#2. 데이터베이스 선택 로직|데이터베이스 선택 로직]]
- [[#3. 스토리지 서비스 구분|스토리지 서비스 구분]]
- [[#4. 보안과 거버넌스|보안 / 거버넌스]]
- [[#5. 마이그레이션과 통합|마이그레이션 / 통합]]
- [[#6. 네트워킹|네트워킹]]

---

## 1. SQS 디커플링과 세션 관리

> [!note] 핵심 판단 원칙
> "계층 간 연결이 직접 연결(tight coupling)"이면 → **SQS로 끊어라**
> "EC2가 죽어도 사용자 세션이 살아야 하면" → **ElastiCache Redis로 외부화**

### 1-1. SQS 디커플링 — 변형 패턴 3가지

같은 정답(SQS)이 이렇게 다르게 나온다:

| 지문 표현                     | 실제 의미            | 정답                 |
| ------------------------- | ---------------- | ------------------ |
| "한 계층이 오버로드되면 트랜잭션이 삭제됨"  | 계층 간 버퍼 없음       | SQS                |
| "컴퓨팅 노드 조정하는 기본 서버"       | 중앙 조율자 제거 → 큐 기반 | SQS + Auto Scaling |
| "EC2에서 폴링 → 비용 절감"        | EC2 폴링 제거        | Lambda + SQS 트리거   |
| "애플리케이션 가동 중지 → 처음부터 재시작" | 작업 단위를 큐에 저장     | SQS + 독립 Lambda 함수 |
|                           |                  |                    |

> [!example] 반복 실수 (Q43, Q69, Q79, Q51)
> - Q43: RESTful API 계층 간 오버로드 → **SQS**로 버퍼링
> - Q69: 컴퓨팅 노드 조율하는 기본 서버 → **SQS** + Worker Auto Scaling
> - Q79: EC2로 SQS 폴링 → **Lambda**가 SQS 트리거로 대체 (비용 절감)
> - Q51: 모놀리스 → 중단 시 처음부터 재시작 → **SQS**로 작업 단위 분리

### 1-2. SQS + S3 대용량 메시지 (Q1)

```
SQS 최대 메시지 크기 = 256KB

256KB 초과 → S3에 저장 + SQS에 S3 URL만 전달
Java SDK = Amazon SQS Extended Client Library (코드 변경 최소화)
```

> [!warning] 함정
> "코드 변경 최소화" = Extended Client Library 사용. S3 따로 업로드 + SQS 별도 연동(D)은 코드 변경 많음.

### 1-3. 세션 관리 외부화 (Q3, Q31)

```
증상: EC2 Auto Scaling + sticky session + 세션 손실
원인: 세션 데이터가 EC2 안에 있음 → EC2 죽으면 세션 소멸

해결: ElastiCache Redis에 세션 저장 (외부화)
     → EC2가 어느 노드든 같은 세션 데이터 접근 가능
```

> [!tip] 판단 기준
> - "세션 데이터 손실 방지" + Auto Scaling = **ElastiCache Redis**
> - sticky session(고정 세션)은 임시방편일 뿐, 근본 해결 아님

### 1-4. 이미지 업로드 + 비동기 처리 (Q80)

```
문제: EC2가 업로드받고 직접 리사이징 → 느림
해결:
  1. S3 Presigned URL → 클라이언트가 S3에 직접 업로드 (EC2 바이패스)
  2. S3 이벤트 → SQS → Lambda가 리사이징
```

---

## 2. 데이터베이스 선택 로직

> [!note] 핵심 판단 원칙
> Aurora = RDS의 HA/성능 강화판. 읽기 오프로드 + 빠른 장애조치가 필요하면 Aurora.
> DynamoDB = 스키마 없음, 무한 확장. 30일 이상 데이터 자동 삭제 = TTL.

### 2-1. RDS vs Aurora 선택 기준

| 조건 | 선택 |
|------|------|
| 고가용성 + **40초 이내** 장애조치 | Aurora (일반 RDS Multi-AZ는 60~120초) |
| 읽기 오프로드 + 비용 최소화 | Aurora (Read Replica 최대 15개) |
| 읽기 급증 + 자동 확장 | Aurora Auto Scaling (Read Replica 수 자동 조절) |
| 여러 개발 환경 + 비용 효율 | Aurora Serverless v2 (사용 안 할 때 0에 가깝게 축소) |
| DB 연결 수 폭증 (Lambda 등) | RDS Proxy (연결 풀링) |
| Oracle 기능 유지 + 읽기 오프로드 | RDS for Oracle + Read Replica |

> [!example] 반복 실수
> - Q26: "40초 이내 장애조치 + 읽기 오프로드" → **Aurora** (RDS Multi-AZ가 아님)
> - Q88: "읽기 요청 많음 + MySQL + 자동 확장" → **Aurora Auto Scaling**
> - Q92: "인프라 추가 없이 더 큰 워크로드" → **RDS Proxy** (연결 관리로 부하 감소)
> - Q98: "개발 환경 여러 개 + 8시간 중 절반만 사용" → **Aurora Serverless** (사용량 기반 과금)

### 2-2. RDS Point-in-Time Recovery (Q8)

```
요구: 지난 30일 중 5분 전 상태로 복원
조건: RDS 자동 백업 활성화 + 백업 보존 기간 = 35일(최대)

PITR = 자동 백업 + 트랜잭션 로그 조합
→ 1초 단위 복원 가능 (보존 기간 내)
```

> [!warning] 함정
> 스냅샷만으로는 5분 전 복원 불가. 스냅샷은 특정 시점 전체 백업.

### 2-3. DynamoDB 선택 기준

| 조건 | 선택 |
|------|------|
| 데이터 자동 만료 (30일 이후 삭제) | **TTL** 속성 설정 (비용 0, 개발 노력 최소) |
| 아침 미사용 + 저녁 예측 불가 급증 | **On-demand** 모드 (프로비저닝 불필요) |
| 읽기 급증 + 캐싱 필요 | **DAX** (DynamoDB Accelerator) |
| 스키마 빠르게 발전시킴 | DynamoDB (NoSQL = 스키마 유연) |

> [!example] 반복 실수
> - Q61: "지난 30일만 필요, 크기 계속 증가" → **TTL** (Lambda로 삭제하는 건 개발 노력 과다)
> - Q82: "아침 미사용, 저녁 급증, 빠르게 발생" → **On-demand** 모드

---

## 3. 스토리지 서비스 구분

> [!note] FSx 4종 구분이 핵심. 헷갈리면 무조건 틀린다.

### 3-1. FSx 4종 완전 구분

| FSx 종류 | 프로토콜 | 사용 시기 |
|----------|----------|-----------|
| **FSx for Windows** | SMB | Windows 앱 + SQL Server + AD 인증 |
| **FSx for Lustre** | POSIX | HPC + ML + 고성능 단일 프로토콜 |
| **FSx for NetApp ONTAP** | NFS + SMB (멀티프로토콜) | 온프레미스 NetApp 마이그레이션, 멀티프로토콜 필요 |
| **FSx for OpenZFS** | NFS | ZFS 기반 Linux 워크로드 |

> [!example] 반복 실수
> - Q18: Windows 앱 + SQL Server + 파일 공유 → **FSx for Windows File Server**
> - Q53: HPC + NFS + SMB 멀티프로토콜 → **FSx for NetApp ONTAP** (Lustre가 아님. Lustre는 단일 프로토콜)

### 3-2. Storage Gateway 3종 구분

| 게이트웨이 | 프로토콜 | 저장 위치 | 사용 시기 |
|-----------|---------|-----------|----------|
| **File Gateway** | NFS, SMB | S3 | 온프레미스 → S3 백업/아카이브 |
| **Volume Gateway** | iSCSI | S3 (EBS 스냅샷) | 블록 스토리지 백업 |
| **Tape Gateway** | iSCSI VTL | S3 Glacier | 물리 테이프 대체 |

> [!example] Q4 실수
> "온프레미스 NFS 서버 → S3 정기 백업, 비용 효율" → **Storage Gateway File Gateway**
> (DataSync는 대량 1회성/주기적 전송, File Gateway는 지속적 연동)

### 3-3. DataSync vs Storage Gateway

```
DataSync = 데이터 이동 (마이그레이션/동기화), 대역폭 제한 가능
Storage Gateway = 온프레미스 ↔ AWS 지속적 연동 (백업, 티어링)

판단:
- "마이그레이션", "n일 이내 전송", "대역폭 제어" → DataSync
- "지속적 백업", "NFS 서버를 S3처럼" → File Gateway
- "리전 간 파일 시스템 동기화" → DataSync
```

> [!example] 반복 실수
> - Q39: FSx로 30TB 마이그레이션 + 대역폭 제어 → **DataSync**
> - Q56: 리전 간 NFS 동기화 → **DataSync**

### 3-4. EFS와 S3 lifecycle (Q13)

```
요구: POSIX + 공유 + EC2 여러 대 + 30일 이후 드물게 접근
→ EFS + EFS Lifecycle Management (EFS-IA로 자동 이동)

POSIX 호환 = EFS (NFS). EBS는 단일 EC2에만 붙음.
```

### 3-5. S3 버전관리 + lifecycle 함정 (Q74)

```
S3 버전관리 활성화 시:
- 삭제 = 실제 삭제 아님, "삭제 마커" 생성
- lifecycle 규칙이 현재 버전만 타겟하면 삭제 마커는 남음
- 4년 이후에도 오브젝트 수 증가 이유 = 삭제 마커 누적

해결: lifecycle 규칙에 "만료된 오브젝트 삭제 마커 제거" 추가
```

### 3-6. S3 Transfer Acceleration vs DataSync (Q36)

```
Transfer Acceleration = CloudFront 엣지 → S3로 글로벌 업로드 가속
                       = 인터넷 연결 있음 + 빠르게 + 운영 복잡성 최소

DataSync = 에이전트 설치 필요, 온프레미스 데이터 이동에 적합
```

---

## 4. 보안과 거버넌스

> [!note] 핵심 구분
> AWS Config = 리소스 상태/변경 감지 + 규정 준수 자동화
> CloudTrail = API 호출 이력 (누가 뭘 했나)
> 둘 다 필요한 경우도 있음

### 4-1. AWS Config vs CloudTrail

| 질문 | 서비스 |
|------|--------|
| "보안 그룹 규칙이 위반인지 자동 탐지" | **Config** (관리형 규칙: restricted-ssh) |
| "EC2/SG 변경 사항 추적/감사" | **Config** (변경 이력) + **CloudTrail** (API 이력) |
| "누가 SG를 변경했나" | **CloudTrail** |
| "SG가 규정 위반이면 SNS 알림" | **Config Rule** + SNS |

> [!example] 반복 실수
> - Q67: "SG에 SSH 0.0.0.0/0 포함 시 자동 탐지+알림" → **AWS Config Rule** (restricted-ssh 관리형 규칙)
> - Q86: "EC2 과도한 프로비저닝 + SG 변경 추적 감사" → **Config + CloudTrail**

### 4-2. IAM Role vs 자격증명 하드코딩 (Q71, Q99)

```
CloudFormation + EC2 + DynamoDB 접근 + 자격증명 노출 없이
→ EC2 Instance Profile (IAM Role 연결)
→ CloudFormation에서 IAM Role ARN 참조만 하면 됨

RDS 자격증명 하드코딩 → Secrets Manager
→ 코드에서 Secrets Manager API 호출로 교체
→ 자동 로테이션도 가능
```

### 4-3. EBS 암호화 강제 (Q21)

```
요구: ap-southeast-2의 모든 새 EC2 EBS 볼륨 암호화 강제
방법 (2가지 조합):
  1. AWS Config Rule로 비암호화 볼륨 탐지 + Lambda 자동 수정
  2. EC2 콘솔/CLI에서 "EBS 기본 암호화" 설정 활성화 (리전 단위)
     → 이후 생성되는 모든 EBS 자동 암호화
```

### 4-4. Organizations + S3 접근 제한 (Q75)

```
"S3 버킷을 Organizations 내 계정만 접근"
→ S3 버킷 정책에 조건 추가:
   Condition: { "StringEquals": { "aws:PrincipalOrgID": "o-xxxx" } }
```

---

## 5. 마이그레이션과 통합

### 5-1. 실시간 데이터 수집 → S3 (Q5)

```
요구: 1분마다 결제 데이터 → 실시간 분석 → S3 저장
→ Kinesis Data Firehose (완전 관리형, S3/Redshift/OpenSearch 직접 전달)

Kinesis Data Streams = 직접 개발 필요 (소비자 코드 작성)
Firehose = 코드 없음, 최소 오버헤드
```

### 5-2. Kubernetes + MongoDB → AWS (Q37)

```
요구: 온프레미스 Kubernetes + MongoDB → AWS, 코드/배포 변경 없음
→ Amazon EKS (Kubernetes 그대로) + Amazon DocumentDB (MongoDB 호환)
```

### 5-3. AWS Transfer Family (Q66)

```
요구: SFTP로 파일 수신 + 고가용성 + 최소 운영
→ AWS Transfer Family for SFTP
→ 완전 관리형, S3/EFS에 직접 저장, 서버 관리 불필요
```

### 5-4. Glue ETL (Q100)

```
요구: CSV → Redshift/S3 분석, COTS 앱은 CSV 처리 불가
→ AWS Glue (서버리스 ETL)
→ CSV를 Parquet/ORC 등으로 변환 → Redshift Spectrum이나 S3에 저장
```

---

## 6. 네트워킹

### 6-1. ALB + Private Subnet EC2 (Q14)

```
인터넷 트래픽이 EC2에 도달 안 함
원인: ALB는 퍼블릭 서브넷에 있어야 함
     (ALB 자체는 퍼블릭 서브넷, EC2는 프라이빗 서브넷 가능)

해결: ALB를 퍼블릭 서브넷에 배치
     EC2는 프라이빗 서브넷 유지 가능
```

### 6-2. VPC Endpoint (Q63)

```
요구: EC2 → S3 접근, 인터넷 경유 금지
→ VPC Gateway Endpoint for S3 (무료, 라우팅 테이블만 추가)

Gateway Endpoint = S3, DynamoDB만 지원 (무료)
Interface Endpoint = 나머지 AWS 서비스 (비용 발생)
```

### 6-3. 다중 리전 트래픽 라우팅

| 요구 | 서비스 |
|------|--------|
| 다중 리전 Lambda + API GW 장애조치 | **Route 53** (Failover Routing) |
| 다중 리전 NLB로 트래픽 라우팅 + 성능 개선 | **Route 53 + Global Accelerator** |
| 글로벌 사용자 + 고정 Anycast IP | **Global Accelerator** |

> [!example] 반복 실수
> - Q34: 다중 리전 Lambda/API GW 장애조치 → **Route 53 Failover Routing**
> - Q58: 미국+유럽 NLB 2개 → 전체 라우팅 → **Route 53 + Global Accelerator**

### 6-4. Direct Connect 비용 (Q50)

```
요구: 데이터웨어하우스 쿼리 결과(50MB) 반환 + 최저 egress 비용
→ Direct Connect로 결과 반환 (인터넷 egress보다 저렴)

CloudFront = 웹 콘텐츠 캐싱/배포용. 쿼리 결과 반환에는 부적합.
```

---

## 7. Route 53 라우팅 정책

> [!danger] 2회 연속 오답 주의
> 라우팅 정책 이름이 헷갈려서 계속 틀림. 이름 + 사용 시기 세트로 암기.

| 정책 | 사용 시기 | 핵심 |
|------|-----------|------|
| **Simple** | 단순 단일 레코드 | 헬스체크 없음 |
| **Weighted** | A/B 테스트, 트래픽 분산 비율 지정 | % 기반 |
| **Latency** | 가장 빠른 리전으로 | 사용자 → 가장 낮은 레이턴시 리전 |
| **Failover** | Active-Passive 장애조치 | 헬스체크 실패 시 secondary로 |
| **Geolocation** | 국가/대륙별 다른 콘텐츠 | 위치 기반 |
| **Geoproximity** | 지리적 거리 + bias 조절 | Traffic Flow 필요 |
| **Multivalue Answer** | **여러 IP 모두 반환** + 헬스체크 | ELB 아님, 단순 다중 IP |
| **IP-based** | CIDR 기반 라우팅 | ISP별 다른 엔드포인트 |

> [!example] 반복 실수
> - Q9: "모든 정상 EC2 IP 반환" → **Multivalue Answer** (Simple은 헬스체크 없음, Weighted는 비율 분산)
> - Q65: 온프레미스(us-west-1 근처) + AWS(eu-central-1) + 로딩 시간 최소 → **Latency-based**

```
Multivalue ≠ ELB
Multivalue = DNS 수준에서 여러 IP 반환 (각각 헬스체크 가능)
ELB = 트래픽 로드밸런싱 (다른 레이어)
```

---

## 8. 스토리지 계층 선택 로직

### 8-1. 스토리지 3종 조합 (Q3)

```
요구: 최대 I/O 성능 10TB + 내구성 300TB + 아카이브 900TB
→ Instance Store (최대 I/O, 임시) + S3 Standard (내구성) + S3 Glacier (아카이브)

Instance Store = EC2에 물리적으로 붙은 NVMe, 최고 I/O, EC2 종료 시 소멸
EBS = 영구 블록, Instance Store보다 I/O 낮음
```

### 8-2. S3 스토리지 클래스 선택

| 클래스 | 사용 시기 |
|--------|-----------|
| **Standard** | 자주 접근 |
| **Standard-IA** | 드물게 접근 + 패턴 예측 가능 |
| **Intelligent-Tiering** | 접근 패턴 **불규칙/예측 불가** → 자동 계층 이동 |
| **One Zone-IA** | 드물게 + 단일 AZ 허용 (재현 가능한 데이터) |
| **Glacier Instant** | 즉시 복구 필요 아카이브 |
| **Glacier Flexible** | 수분~수시간 복구 허용 |
| **Glacier Deep Archive** | 가장 저렴, 12시간 복구 |

> [!example] Q52: "30일 후 접근 패턴 불규칙" → **S3 Intelligent-Tiering** (Standard-IA가 아님)

### 8-3. S3 Object Lock (Q27)

```
요구: 5년 동안 덮어쓰기/삭제 불가 + 암호화 + 키 자동 교체
→ S3 Object Lock (Compliance 모드) + SSE-KMS (자동 키 교체)

Object Lock 모드:
- Governance: 특정 권한 있는 사용자는 삭제 가능
- Compliance: 루트 계정 포함 누구도 삭제 불가 (규정 준수용)

"절대 삭제 불가" = Compliance 모드
```

### 8-4. S3 암호화 키 관리 (Q29)

```
SSE-S3  = AWS가 키 완전 관리 (사용자 통제 없음)
SSE-KMS = 고객이 KMS에서 키 관리 (교체, 감사 가능) ← 규정 준수 팀이 관리
SSE-C   = 고객이 키 직접 제공 (AWS에 키 저장 안 함)

"규정 준수 팀이 키 관리" = SSE-KMS (고객 관리형 키)
```

### 8-5. Volume Gateway (온프레미스 백업 + 로컬 액세스) (Q55)

```
요구: 온프레미스 백업 솔루션 교체 + AWS 백업 + 로컬 액세스 유지 + 자동 전송
→ Storage Gateway Volume Gateway (Cached 모드)

Cached 모드: 자주 쓰는 데이터는 로컬 캐시, 전체는 S3
Stored 모드: 전체 로컬 저장 + S3 백업 (완전한 로컬 액세스)

"로컬 액세스 유지 + AWS 백업" = Volume Gateway
File Gateway는 파일 공유 (NFS/SMB), 블록 스토리지 아님
```

### 8-6. S3 Lifecycle 로그 보관 (Q54)

```
요구: 30일 높은 가용성 분석 + 60일 백업 + 90일 후 삭제
→ S3 Standard (0~30일) → S3 Glacier (30~90일) → 만료 삭제

Glacier Instant Retrieval이 아닌 Glacier Flexible = 백업 목적으로 충분
```

---

## 9. 백업과 복구

### 9-1. AWS Backup (Q57, Q59)

```
AWS Backup = 중앙화된 백업 관리 서비스
지원: RDS, DynamoDB, EFS, EBS, EC2, Storage Gateway

"RDS 일일 백업 2년 이상 유지" → AWS Backup (보존 기간 제한 없음)
"DynamoDB 월별 백업 7년 유지" → AWS Backup

RDS 자동 백업 = 최대 35일만 보존 → 장기 보관 불가
→ 장기 보관이 필요하면 무조건 AWS Backup
```

### 9-2. RDS 삭제 보호 + 안정성 (Q34)

```
요구: 직원이 DB 삭제 → 24시간 다운타임 방지
→ RDS 삭제 보호(Deletion Protection) 활성화
   + EC2 Multi-AZ Auto Scaling (단일 AZ 제거)

"실수로 삭제 방지" = Deletion Protection
"EC2 단일 AZ" = 가용성 위험 → 여러 AZ + ASG
```

### 9-3. On-Demand Capacity Reservation (Q56)

```
요구: 특정 리전, 특정 3개 AZ, 1주일간 EC2 용량 보장
→ On-Demand Capacity Reservation

Reserved Instance = 할인 목적, 용량 보장 아님
Capacity Reservation = 특정 AZ에 용량 예약 (할인 없음, 즉시 사용 가능)
```

---

## 10. 네트워킹 추가 패턴

### 10-1. NAT Instance vs NAT Gateway (Q14-2)

```
NAT Instance = EC2 기반, 수동 확장, 단일 장애점
NAT Gateway  = 완전 관리형, 자동 확장, 고가용성

"NAT 인스턴스가 트래픽 감당 못함 + HA + 자동 확장" = NAT Gateway
```

### 10-2. VPC Interface Endpoint for SQS (Q17)

```
요구: 프라이빗 서브넷 EC2 → SQS, 보안 연결
→ VPC Interface Endpoint for SQS

SQS는 S3/DynamoDB가 아님 → Gateway Endpoint 불가
SQS = Interface Endpoint (PrivateLink 사용, 비용 발생)

Gateway Endpoint: S3, DynamoDB만 (무료)
Interface Endpoint: 나머지 AWS 서비스 (비용)
```

### 10-3. Direct Connect + VPN 하이브리드 (Q64)

```
요구: 일관된 짧은 지연시간 + HA + 비용 최소 + 기본 연결 실패 시 느려도 됨
→ Direct Connect (기본, 저지연) + VPN (백업, 저렴)

Direct Connect + Direct Connect 이중화 = 비용 높음
Direct Connect + VPN 백업 = 비용 최소 + HA
"느려도 됨" = VPN 백업 허용 신호
```

### 10-4. VPC Peering 교차 계정 (Q53)

```
요구: 별도 AWS 계정의 VPC-A EC2 → VPC-B EC2 파일 접근
    단일 장애점 없음 + 대역폭 문제 없음
→ VPC Peering

VPC Peering = 두 VPC 직접 연결, 단일 장애점 없음, 대역폭 제한 없음
Transit Gateway = 여러 VPC 허브 연결 (비용 더 높음, 2개면 과잉)
PrivateLink = 서비스 노출용, 파일 접근에는 부적합
```

### 10-5. API Gateway + 커스텀 도메인 (Q63-2)

```
요구: Route 53 도메인 + API Gateway + HTTPS
→ ACM(AWS Certificate Manager)에서 인증서 발급
   + API Gateway에 커스텀 도메인 이름 설정
   + Route 53 → API Gateway 엔드포인트로 ALIAS 레코드

API Gateway URL 기본값 = execute-api.amazonaws.com → 커스텀 도메인으로 교체
```

### 10-6. Aurora Serverless (평일만 사용) (Q61)

```
요구: RDS PostgreSQL + 평일 업무 시간만 트래픽 + 비용 최적화
→ Aurora Serverless v2

Aurora Serverless = 트래픽 없을 때 0 ACU까지 축소 (사실상 비용 0)
일반 RDS = 인스턴스 항상 실행 → 비용 발생
RDS 중지 = 최대 7일만 자동 중지 가능
```

---

## 11. 보안 추가 패턴

### 11-1. KMS 암호화 AMI 교차 계정 공유 (Q10)

```
요구: KMS 암호화 EBS 스냅샷 포함 AMI → 다른 AWS 계정 공유
→ 1. KMS 키 정책에 대상 계정 추가 (키 사용 권한 부여)
   2. AMI 공유 설정에 대상 계정 추가

KMS 키는 계정 간 자동 공유 안 됨 → 키 정책 명시적 추가 필수
AMI만 공유해도 키 없으면 스냅샷 복호화 불가
```

### 11-2. Secrets Manager 자동 로테이션 (Q43)

```
요구: Aurora 자격증명 암호화 + 14일마다 자동 교체
→ AWS Secrets Manager

Secrets Manager = 자동 로테이션 지원 (Lambda 함수로 교체 실행)
Systems Manager Parameter Store = 암호화는 되지만 자동 로테이션 없음

"자동 교체(rotation)" = Secrets Manager 즉시 선택
```

### 11-3. 리소스 자동 태깅 (Q49)

```
요구: Organizations 특정 계정의 모든 리소스 생성 시 비용센터 ID 태깅
→ EventBridge (리소스 생성 이벤트 감지) + Lambda (RDS에서 비용센터 조회 후 태그)

Tag Policy (SCP) = 태그 강제하지만 값을 동적으로 조회 불가
AWS Config = 탐지는 하지만 자동 태깅 아님
```

---

## 12. 변형 패턴 빠른 판단표

> [!tip] 이 표가 응용력의 핵심. "같은 답인데 다르게 표현"을 정리.

| 지문 표현 | 실제 의도 | 정답 |
|-----------|-----------|------|
| 계층 간 트랜잭션 삭제 / 오버로드 | 버퍼 없는 tight coupling | SQS |
| EC2에서 스크립트로 폴링 + 비용 절감 | EC2 대신 서버리스 트리거 | Lambda + SQS |
| 세션 손실 방지 + Auto Scaling | 세션 외부화 | ElastiCache Redis |
| 256KB 초과 메시지 + SQS + 코드 최소 변경 | 대용량 메시지 우회 | SQS Extended Client + S3 |
| 40초 이내 장애조치 | Aurora만 가능 | Aurora Multi-AZ |
| 읽기 많음 + 자동 확장 | 읽기 복제본 오토스케일링 | Aurora Auto Scaling |
| 인프라 추가 없이 DB 부하 감소 | 연결 수 감소 | RDS Proxy |
| 아침 미사용 저녁 급증 예측 불가 | 사용량 기반 과금 | DynamoDB On-demand |
| 30일 이후 데이터 자동 삭제 | 만료 속성 | DynamoDB TTL |
| POSIX + 공유 + 자주/드물게 | NFS 공유 + 계층화 | EFS + Lifecycle (EFS-IA) |
| NFS + SMB 멀티프로토콜 | 두 프로토콜 동시 지원 | FSx for NetApp ONTAP |
| Windows + SQL Server + 파일 공유 | Windows 전용 FSx | FSx for Windows |
| 대역폭 제한 + n일 이내 마이그레이션 | 이동 도구 | DataSync |
| 리전 간 NFS 파일 시스템 동기화 | 복제 도구 | DataSync |
| 온프레미스 NFS → S3 지속 백업 | 게이트웨이 연동 | File Gateway |
| SFTP + HA + 최소 운영 | 완전 관리형 SFTP | AWS Transfer Family |
| 글로벌 → S3 빠르게 + 복잡성 최소 | 엣지 가속 업로드 | S3 Transfer Acceleration |
| SG SSH 0.0.0.0/0 탐지 + 알림 | 규정 준수 자동화 | AWS Config (restricted-ssh) |
| 자격증명 하드코딩 제거 | 시크릿 관리 | Secrets Manager |
| CloudFormation + DB 접근 + 노출 없이 | 역할 기반 접근 | IAM Instance Profile |
| Organizations 계정만 S3 접근 | 조직 단위 조건 | aws:PrincipalOrgID 버킷 정책 |
| 1분마다 데이터 → 실시간 → S3 | 관리형 스트리밍 수집 | Kinesis Data Firehose |
| CSV → Redshift + 형식 변환 + 최소 오버헤드 | 서버리스 ETL | AWS Glue |
| 인터넷 없이 EC2 → S3 | 프라이빗 AWS 접근 | VPC Gateway Endpoint |
| 다중 리전 API 장애조치 | DNS 기반 라우팅 | Route 53 Failover |
| 다중 리전 NLB + 성능 + 고가용성 | Anycast + DNS | Global Accelerator |
| 모든 정상 EC2 IP 반환 (헬스체크 포함) | DNS 다중 응답 | Route 53 Multivalue Answer |
| 사용자 위치 기준 가장 빠른 리전 | 레이턴시 기반 | Route 53 Latency-based |
| DNS 서버 → AWS 마이그레이션 + 최소 운영 | 관리형 DNS | Route 53 (완전 관리형) |
| 최대 I/O 스토리지 (임시 허용) | 물리 NVMe | Instance Store |
| 30일 후 액세스 패턴 불규칙 | 자동 계층 이동 | S3 Intelligent-Tiering |
| n년간 삭제/덮어쓰기 절대 불가 | 불변 스토리지 | S3 Object Lock Compliance |
| 규정 준수 팀이 암호화 키 관리 | 고객 관리 키 | SSE-KMS |
| 온프레미스 백업 + 로컬 액세스 유지 | 블록 백업 게이트웨이 | Volume Gateway |
| RDS/DynamoDB 장기 백업 (35일 초과) | 중앙 백업 관리 | AWS Backup |
| 특정 AZ 용량 n일 보장 | 용량 예약 | On-Demand Capacity Reservation |
| NAT 인스턴스 한계 + HA + 자동 확장 | 관리형 NAT | NAT Gateway |
| 프라이빗 서브넷 EC2 → SQS 보안 연결 | 프라이빗 서비스 접근 | VPC Interface Endpoint |
| Direct Connect 기본 + 실패 시 느려도 됨 | 하이브리드 HA 최저 비용 | Direct Connect + VPN 백업 |
| 교차 계정 VPC 연결 (단일 장애점 없음) | VPC 직접 연결 | VPC Peering |
| Aurora + 자격증명 n일마다 자동 교체 | 시크릿 로테이션 | Secrets Manager (자동 로테이션) |
| 평일만 트래픽 + DB 비용 최적화 | 트래픽 없을 때 0 | Aurora Serverless v2 |
| 리소스 생성 시 동적 값으로 자동 태깅 | 이벤트 기반 자동화 | EventBridge + Lambda |
| KMS 암호화 AMI + 교차 계정 공유 | 키 정책 공유 | KMS 키 정책 + AMI 공유 설정 |
