---
title: SAA-C03 핵심 서비스 비교표 - 헷갈리는 서비스 쌍 완전 정리
tags:
  - SAA-C03
  - AWS
  - 자격증
  - 비교표
  - 치트시트
date: 2026-03-10
status: 완성
priority: 높음
aliases:
  - SAA비교표
  - AWS서비스비교
---

# 🎯 SAA-C03 핵심 서비스 비교표

> [!note] 사용법
> 지문에서 조건 키워드를 보는 순간 이 표의 해당 행을 떠올릴 것.
> **"어떤 서비스?"가 아니라 "이 키워드 → 이 서비스"로 반사 훈련.**

---

## 📑 목차

- [[#1. 스토리지|스토리지]]
- [[#2. 데이터베이스|데이터베이스]]
- [[#3. 컴퓨팅|컴퓨팅]]
- [[#4. 네트워킹|네트워킹]]
- [[#5. 보안 및 접근 제어|보안 / 접근 제어]]
- [[#6. 메시징 및 이벤트|메시징 / 이벤트]]
- [[#7. 캐싱|캐싱]]
- [[#8. 마이그레이션 및 전송|마이그레이션 / 전송]]
- [[#9. 모니터링 및 감사|모니터링 / 감사]]
- [[#10. 콘텐츠 전송 및 가속|콘텐츠 전송 / 가속]]

---

## 1. 스토리지

### S3 vs EFS vs EBS vs FSx

| 항목    | S3        | EFS      | EBS      | FSx for Windows | FSx for Lustre |
| ----- | --------- | -------- | -------- | --------------- | -------------- |
| 타입    | 객체        | 파일 (NFS) | 블록       | 파일 (SMB)        | 파일 (HPC)       |
| 마운트   | ❌ (API)   | ✅ 여러 EC2 | ✅ 단일 EC2 | ✅ Windows 전용    | ✅ Linux HPC    |
| 멀티 AZ | 기본        | 기본       | 단일 AZ    | Multi-AZ 옵션     | 단일 AZ          |
| 프로토콜  | HTTP/REST | NFS      | -        | SMB/NTFS        | POSIX          |

**키워드 매핑:**
- "객체 저장", "정적 웹사이트", "URL 접근" → **S3**
- "여러 EC2 동시 마운트", "공유 파일 시스템" → **EFS**
- "단일 인스턴스 OS 디스크", "빠른 I/O" → **EBS**
- "Windows 파일 공유", "Active Directory 통합" → **FSx for Windows**
- "HPC", "머신러닝", "S3 데이터 빠른 처리" → **FSx for Lustre**

> [!warning] 함정
> "파일 기반 애플리케이션" 단독으로는 EFS 선택 금지.
> "전 세계 배포 + 최소 지연" 조건이 추가되면 **S3 + CloudFront** 가 정답.

---

### S3 Glacier 종류

| 클래스 | 복구 시간 | 최소 보관 | 용도 |
|--------|---------|---------|------|
| Glacier Instant | 밀리초 | 90일 | 분기별 접근, 즉시 복구 |
| Glacier Flexible | 1~12시간 | 90일 | 연간 접근, 비용 절감 |
| Glacier Deep Archive | 12~48시간 | 180일 | 7~10년 장기 보관 |

**키워드 매핑:**
- "즉시 복구", "분기 한 번 접근" → **Glacier Instant**
- "몇 시간 내 복구 허용", "연간 접근" → **Glacier Flexible**
- "7년 이상", "규정 준수 장기 보관", "가장 저렴" → **Glacier Deep Archive**

---

### S3 Object Lock 모드

| 모드 | 관리자 삭제 | 보존 기간 변경 | 용도 |
|------|-----------|------------|------|
| Governance | ✅ 특권 사용자 가능 | 가능 | 내부 정책, 실수 방지 |
| Compliance | ❌ 루트도 불가 | ❌ 절대 불가 | 금융/의료 규정 준수 |

> [!danger] 암기 포인트
> "어떤 사용자도 수정/삭제 불가", "규정 준수 필수" → **Compliance**
> "관리자 예외 허용", "내부 정책" → **Governance**

---

## 2. 데이터베이스

### RDS Multi-AZ vs Read Replica

| 항목       | Multi-AZ         | Read Replica       |
| -------- | ---------------- | ------------------ |
| 목적       | **고가용성** (장애 조치) | **읽기 성능** 향상       |
| 동기화      | 동기 (Synchronous) | 비동기 (Asynchronous) |
| 읽기 허용    | ❌ 스탠바이는 읽기 불가    | ✅                  |
| 자동 장애 조치 | ✅                | ❌                  |
| 리전 간 복제  | ❌ (같은 리전)        | ✅                  |

**키워드 매핑:**
- "고가용성", "자동 장애 조치", "RTO 낮춤" → **Multi-AZ**
- "읽기 성능", "읽기 부하 분산", "보고서 쿼리 분리" → **Read Replica**
- "리전 간 재해 복구" + RDS → **Cross-Region Read Replica**

> [!warning] 함정
> Multi-AZ 스탠바이는 **읽기 불가**.
> 읽기 부하 분산이 목적이면 반드시 Read Replica.

---

### Aurora vs DynamoDB vs Redshift

| 항목 | Aurora | DynamoDB | Redshift |
|------|--------|----------|---------|
| 타입 | 관계형 (MySQL/PostgreSQL 호환) | NoSQL (키-값) | 데이터 웨어하우스 |
| 스케일링 | 읽기: 15개 복제본 | 자동 (서버리스) | 클러스터 크기 조정 |
| 전 세계 복제 | Aurora Global DB | Global Tables | ❌ |
| 용도 | OLTP | 밀리초 응답, 확장성 | OLAP, 분석 쿼리 |
| 최소 지연 전 세계 쓰기 | Aurora Global (<1초) | Global Tables | ❌ |

**키워드 매핑:**
- "MySQL/PostgreSQL 호환", "관계형 + 고성능" → **Aurora**
- "밀리초 응답", "무제한 확장", "NoSQL" → **DynamoDB**
- "데이터 웨어하우스", "BI 분석", "수백만 행 집계" → **Redshift**
- "전 세계 낮은 지연 쓰기" + 관계형 → **Aurora Global**
- "전 세계 낮은 지연 쓰기" + NoSQL → **DynamoDB Global Tables**

---

### ElastiCache Redis vs Memcached vs DynamoDB DAX

| 항목 | Redis | Memcached | DAX |
|------|-------|----------|-----|
| 데이터 구조 | 다양 (Set, Hash, List 등) | 단순 키-값 | DynamoDB 전용 |
| 복제 | ✅ | ❌ | ✅ |
| 지속성 | ✅ (AOF/RDB) | ❌ | ❌ |
| 멀티스레드 | ❌ | ✅ | - |
| 용도 | 세션, 리더보드, Pub/Sub | 단순 캐시, 대용량 | DynamoDB 읽기 가속 |

**키워드 매핑:**
- "세션 저장", "리더보드", "Pub/Sub", "복잡한 데이터 구조" → **Redis**
- "단순 캐싱", "멀티스레드", "스케일 아웃 필요" → **Memcached**
- "DynamoDB 읽기 성능 향상", "마이크로초 응답" → **DAX**

---

## 3. 컴퓨팅

### EC2 구매 옵션

| 옵션 | 할인율 | 조건 | 적합 케이스 |
|------|--------|------|-----------|
| On-Demand | 없음 | 없음 | 예측 불가 워크로드 |
| Reserved (1yr) | ~40% | 1년 약정 | 안정적, 예측 가능 |
| Reserved (3yr) | ~60% | 3년 약정 | 장기 안정 워크로드 |
| Savings Plans | ~66% | 유연한 약정 | 다양한 인스턴스 유형 |
| Spot | ~90% | 중단 가능 | 배치, 분석, stateless |
| Dedicated Host | 높음 | 물리 서버 | BYOL 라이선스, 규정 준수 |
| Dedicated Instance | 높음 | 단일 테넌트 | 규정 준수 (물리 서버 불필요) |

**키워드 매핑:**
- "중단 허용", "배치 처리", "비용 최소화" → **Spot**
- "소프트웨어 라이선스 (BYOL)", "소켓/코어 기준 라이선스" → **Dedicated Host**
- "단일 테넌트 필요", "다른 고객과 공유 금지" → **Dedicated Instance**
- "1~3년 약정 + 유연한 인스턴스" → **Savings Plans**

---

### Lambda vs ECS Fargate vs EC2

| 항목 | Lambda | ECS Fargate | EC2 |
|------|--------|------------|-----|
| 서버 관리 | 없음 | 없음 | 있음 |
| 최대 실행 시간 | 15분 | 무제한 | 무제한 |
| 콜드 스타트 | 있음 | 있음 (적음) | 없음 |
| 상태 | Stateless | Stateless/Stateful | 모두 가능 |
| 과금 | 실행 시간/요청 수 | vCPU/메모리 시간 | 시간당 |

**키워드 매핑:**
- "이벤트 기반", "서버리스", "15분 이내 작업" → **Lambda**
- "컨테이너", "서버 관리 없음", "긴 실행 시간" → **Fargate**
- "15분 이상 실행", "지속적 프로세스", "GPU 필요" → **EC2**

---

### Lambda Provisioned vs Reserved Concurrency

| 항목 | Reserved | Provisioned |
|------|---------|-------------|
| 목적 | 최대 동시 실행 수 제한 | 콜드 스타트 제거 |
| 웜 인스턴스 유지 | ❌ | ✅ |
| 비용 | 제한만 (추가 비용 없음) | 추가 비용 발생 |
| 콜드 스타트 해결 | ❌ | ✅ |

> [!danger] 암기 포인트
> "콜드 스타트 제거", "초기화 시간 오래 걸림" → **Provisioned Concurrency**
> "계정 동시 실행 제한", "스로틀링 방지" → **Reserved Concurrency**

---

## 4. 네트워킹

### VPC Peering vs Transit Gateway vs PrivateLink

| 항목 | VPC Peering | Transit Gateway | PrivateLink |
|------|------------|----------------|------------|
| 연결 방식 | 1:1 | 허브-스포크 | 서비스 엔드포인트 |
| 전이적 라우팅 | ❌ | ✅ | - |
| 다른 계정 | ✅ | ✅ | ✅ |
| 리전 간 | ✅ | ✅ (피어링) | ❌ |
| 용도 | 소수 VPC 연결 | 다수 VPC + 온프레미스 | 서비스 프라이빗 노출 |

**키워드 매핑:**
- "3개 이상 VPC 모두 통신", "전이적 라우팅" → **Transit Gateway**
- "2~3개 VPC 간단 연결" → **VPC Peering**
- "서비스를 VPC 내에서 프라이빗하게 노출" → **PrivateLink**
- "모든 리전 VPC 통신" → **Transit Gateway Inter-Region Peering**

---

### VPC Endpoint: Gateway vs Interface

| 항목 | Gateway Endpoint | Interface Endpoint (PrivateLink) |
|------|----------------|--------------------------------|
| 지원 서비스 | S3, DynamoDB만 | 대부분 AWS 서비스 |
| 비용 | **무료** | 시간당 + 데이터 전송 요금 |
| 라우팅 방식 | 라우팅 테이블 | ENI (VPC 내 IP) |
| 온프레미스 접근 | ❌ | ✅ (Direct Connect/VPN 통해서) |

> [!tip] 비용 절감 문제
> "S3/DynamoDB를 인터넷 없이 접근 + 비용 최소화" → **Gateway Endpoint (무료)**

---

### CloudFront vs Global Accelerator

| 항목 | CloudFront | Global Accelerator |
|------|-----------|-------------------|
| 목적 | 콘텐츠 캐싱 + CDN | TCP/UDP 트래픽 가속 |
| 캐싱 | ✅ | ❌ |
| 프로토콜 | HTTP/HTTPS | TCP, UDP |
| 정적 IP | ❌ | ✅ (Anycast IP) |
| 주요 용도 | 정적/동적 웹 콘텐츠 | 게임, IoT, 글로벌 앱 |

**키워드 매핑:**
- "정적 콘텐츠 전 세계 배포", "HTTP 캐싱" → **CloudFront**
- "고정 IP 필요", "TCP/UDP 게임 서버", "비HTTP" → **Global Accelerator**
- "전 세계 + HTTP + 캐싱 불필요" → **Global Accelerator** (헷갈림 주의!)

---

### Route53 라우팅 정책 심화

| 정책 | 키워드 | 헬스체크 |
|------|--------|---------|
| Simple | 단순 DNS | ❌ |
| Weighted | "A/B 테스트", "비율 조정", "카나리 배포" | ✅ |
| Latency | "가장 빠른 리전", "최저 지연" | ✅ |
| Failover | "Active-Passive", "기본/백업" | ✅ (필수) |
| Geolocation | "특정 국가 트래픽", "지역별 다른 콘텐츠" | ✅ |
| Geoproximity | "지역 편향(bias) 조정", "특정 리전 더 많은 트래픽" | ✅ |
| Multivalue | "복수 IP 반환", "클라이언트 로드밸런싱" | ✅ |

> [!warning] Geolocation vs Geoproximity
> - Geolocation: **사용자 위치 기반** (한국 → 한국 서버)
> - Geoproximity: **지리적 거리 + bias 값으로 조정** (특정 리전에 더 많은 트래픽 유도)

---

## 5. 보안 및 접근 제어

### IAM 핵심 구분

| 구성요소 | 용도 | 키워드 |
|---------|------|--------|
| IAM Policy | 사용자/역할 권한 | 개별 계정 권한 |
| SCP (Service Control Policy) | 조직 전체 최대 권한 제한 | "조직 전체", "루트 포함" |
| Permission Boundary | IAM 엔티티의 최대 권한 제한 | "개발자가 역할 생성 허용, 단 범위 제한" |
| Resource Policy | 리소스에 직접 연결 | S3 버킷 정책, KMS 키 정책 |

**키워드 매핑:**
- "조직 전체 계정에 강제 적용", "루트도 제한" → **SCP**
- "개발자가 IAM 역할 만들 수 있게 + 권한 초과 방지" → **Permission Boundary**
- "계정 간 S3 접근" → **S3 버킷 정책 (Resource Policy)**

---

### Active Directory 서비스 3종

| 서비스 | 특징 | 키워드 |
|--------|------|--------|
| AD Connector | 온프레미스 AD로 프록시, 사용자 저장 안함 | "기존 AD 유지", "동기화 없이 연동" |
| AWS Managed Microsoft AD | 완전 관리형 AD, AWS에서 실행 | "클라우드 네이티브 AD", "트러스트 관계" |
| Simple AD | 소규모 Samba 기반 AD | "300명 이하", "기본 AD 기능" |

> [!danger] 암기 포인트
> - 온프레미스 AD 그대로 + AWS 연동 → **AD Connector**
> - AWS에서 새 AD 관리 + 복잡한 기능 → **Managed Microsoft AD**
> - 소규모 간단 AD → **Simple AD**

---

### KMS vs CloudHSM vs Secrets Manager vs SSM Parameter Store

| 서비스 | 용도 | 키워드 |
|--------|------|--------|
| KMS | AWS 관리형 암호화 키 | "데이터 암호화", "키 관리" |
| CloudHSM | 전용 하드웨어 보안 모듈 | "FIPS 140-2 Level 3", "전용 HSM", "고객 관리 키" |
| Secrets Manager | 시크릿 자동 교체 | "DB 비밀번호 자동 교체", "자격증명 관리" |
| SSM Parameter Store | 구성값 저장 | "환경 변수", "구성 데이터", "무료 티어" |

**키워드 매핑:**
- "자동 교체", "데이터베이스 자격증명" → **Secrets Manager**
- "구성값 저장", "환경변수", "비용 최소화" → **SSM Parameter Store**
- "전용 물리 HSM", "FIPS 140-2 Level 3" → **CloudHSM**

---

### WAF vs Shield vs GuardDuty vs Inspector vs Macie

| 서비스             | 보호 대상     | 키워드                            |
| --------------- | --------- | ------------------------------ |
| WAF             | 레이어 7 공격  | "SQL 인젝션", "XSS", "웹 ACL"      |
| Shield Standard | DDoS 기본   | 자동 포함 (무료)                     |
| Shield Advanced | DDoS 고급   | "비용 보호", "DDoS 전문팀 지원"         |
| GuardDuty       | 위협 감지     | "비정상 API 호출", "악성 IP", "이상 탐지" |
| Inspector       | 취약점 스캔    | "EC2 취약점", "컨테이너 CVE 스캔"       |
| Macie           | S3 민감 데이터 | "PII 탐지", "개인정보 S3"            |

---

## 6. 메시징 및 이벤트

### SQS vs SNS vs EventBridge vs Kinesis

| 항목 | SQS | SNS | EventBridge | Kinesis Data Streams |
|------|-----|-----|-------------|---------------------|
| 패턴 | 큐 (Pull) | 팬아웃 (Push) | 이벤트 버스 | 스트리밍 |
| 소비자 | 단일 (기본) | 복수 | 복수 | 복수 (샤드) |
| 재처리 | ❌ (DLQ) | ❌ | ❌ | ✅ (Replay) |
| 순서 보장 | FIFO만 | ❌ | ❌ | 샤드 내 순서 보장 |
| 용도 | 디커플링, 버퍼링 | 알림, 멀티 구독 | AWS 이벤트 라우팅 | 실시간 분석, 로그 |

**키워드 매핑:**
- "컴포넌트 디커플링", "메시지 버퍼링" → **SQS**
- "여러 서비스에 동시 알림", "팬아웃" → **SNS**
- "S3 이벤트", "CloudTrail 이벤트", "서드파티 이벤트" → **EventBridge**
- "실시간 스트리밍", "재처리/Replay", "순서 중요" → **Kinesis Data Streams**
- "스트리밍 → S3/Redshift 전달, 최소 오버헤드" → **Kinesis Firehose**

---

### SQS Standard vs FIFO

| 항목 | Standard | FIFO |
|------|---------|------|
| 순서 보장 | ❌ (최선 노력) | ✅ |
| 중복 | 가능 | ❌ (중복 제거) |
| 처리량 | 거의 무제한 | 300~3,000 TPS |
| 용도 | 고처리량 작업 | 금융, 주문, 순서 중요 |

> [!warning] 함정
> "정확히 한 번 처리", "순서 보장" → **FIFO**
> "최대 처리량", "최소 비용" → **Standard**

---

## 7. 캐싱

### 캐싱 레이어별 선택

| 위치 | 서비스 | 키워드 |
|------|--------|--------|
| CDN (엣지) | CloudFront | "전 세계 사용자", "정적 콘텐츠", "엣지 캐싱" |
| DNS | Route53 TTL | - |
| API | API Gateway 캐시 | "API 응답 캐싱" |
| 애플리케이션 | ElastiCache Redis/Memcached | "DB 요청 캐싱", "세션" |
| 데이터베이스 | DAX | "DynamoDB 읽기 가속" |

---

## 8. 마이그레이션 및 전송

### DataSync vs Storage Gateway (File Gateway vs Volume Gateway)

| 서비스 | 목적 | 키워드 |
|--------|------|--------|
| DataSync | 온프레미스 → AWS 데이터 이동 | "마이그레이션", "일정 주기 동기화", "체크섬 검증" |
| File Gateway | 온프레미스 앱이 S3를 파일처럼 사용 | "지속적 접근", "NFS/SMB로 S3 마운트" |
| Volume Gateway | 온프레미스 블록 스토리지 클라우드 백업 | "iSCSI", "블록 스토리지 백업" |
| Tape Gateway | 테이프 백업 → S3/Glacier | "가상 테이프 라이브러리" |

> [!danger] DataSync vs File Gateway 구분
> - **DataSync**: "이동 (Migration)", "배치", "완료 후 끝"
> - **File Gateway**: "지속적 연결", "실시간 접근", "온프레미스 앱이 계속 사용"

---

### Snow Family

| 서비스 | 용량 | 네트워크 | 키워드 |
|--------|------|---------|--------|
| Snowcone | 8TB | ✅ DataSync 포함 | "소형", "엣지 컴퓨팅" |
| Snowball Edge Storage | 80TB | ❌ | "대용량 마이그레이션" |
| Snowball Edge Compute | 80TB + GPU | ❌ | "엣지 ML 처리" |
| Snowmobile | 100PB | ❌ | "엑사바이트 규모" |

**키워드 매핑:**
- "인터넷 없는 환경 → AWS 데이터 이동" → **Snowball**
- "페타바이트 이상" → **Snowmobile**
- "엣지에서 ML 처리" → **Snowball Edge Compute**

---

### 데이터베이스 마이그레이션

| 서비스 | 용도 |
|--------|------|
| DMS (Database Migration Service) | DB → DB 마이그레이션 (동종/이기종) |
| SCT (Schema Conversion Tool) | 이기종 DB 스키마 변환 (Oracle → Aurora) |

**키워드 매핑:**
- "Oracle → Aurora 마이그레이션" → **SCT (스키마 변환) + DMS (데이터 이동)**
- "MySQL → Aurora 마이그레이션" → **DMS만** (스키마 변환 불필요)

---

## 9. 모니터링 및 감사

### CloudWatch vs CloudTrail vs Config vs Trusted Advisor

| 서비스 | 목적 | 키워드 |
|--------|------|--------|
| CloudWatch | 지표 모니터링, 로그, 알람 | "CPU 사용률", "메트릭", "알람", "로그 수집" |
| CloudTrail | API 호출 감사 | "누가 무엇을 했는지", "API 로그", "컴플라이언스" |
| Config | 리소스 구성 변경 추적 | "구성 변경 이력", "규정 준수 평가" |
| Trusted Advisor | 비용/성능/보안 권고 | "비용 최적화 권장사항", "미사용 리소스" |

**키워드 매핑:**
- "메트릭 모니터링 + 알람" → **CloudWatch**
- "API 호출 이력 감사" → **CloudTrail**
- "리소스 구성 변경 추적" → **Config**
- "비용 절감 권고" → **Trusted Advisor**

---

### CloudWatch Logs Insights vs Athena vs Redshift

| 서비스 | 데이터 소스 | 키워드 |
|--------|-----------|--------|
| CloudWatch Logs Insights | CloudWatch Logs | "로그 쿼리", "실시간 분석" |
| Athena | S3 | "S3 데이터 SQL 조회", "서버리스 분석" |
| Redshift | 데이터 웨어하우스 | "대규모 OLAP", "BI 도구 연동" |

---

## 10. 콘텐츠 전송 및 가속

### CloudFront 핵심 기능

| 기능 | 설명 | 키워드 |
|------|------|--------|
| Signed URL | 개별 파일 임시 접근 | "파일 1개", "시간 제한 접근" |
| Signed Cookie | 여러 파일 임시 접근 | "여러 파일", "구독 콘텐츠" |
| OAC (Origin Access Control) | S3 직접 접근 차단 | "S3 직접 URL 차단", "CloudFront 통해서만" |
| Lambda@Edge | 엣지에서 코드 실행 | "엣지 커스텀 로직", "헤더 수정" |
| Field-Level Encryption | 특정 필드 암호화 | "신용카드 등 민감 필드 엣지 암호화" |

**Pre-signed URL vs CloudFront Signed URL:**
- **S3 Pre-signed URL**: AWS 계정 없는 사용자에게 임시 S3 접근
- **CloudFront Signed URL**: CloudFront를 통한 콘텐츠 배포에서 접근 제한

---

## 💡 최종 암기 카드

> [!note] 시험 직전 30초 리뷰

| 키워드 | 즉답 |
|--------|------|
| 조직 전체 정책 강제 | SCP |
| 콜드 스타트 제거 | Provisioned Concurrency |
| 3개+ VPC 전이적 연결 | Transit Gateway |
| 체크섬 검증 + 마이그레이션 | DataSync |
| 지속적 온프레미스 → S3 접근 | File Gateway |
| 스트리밍 → S3 직접 전달 | Kinesis Firehose |
| 여러 소스 SQL 조회, DB 부하 없음 | Athena Federated Query |
| 변경/삭제 절대 불가 Object Lock | Compliance 모드 |
| 기존 온프레미스 AD 유지 + AWS | AD Connector |
| DynamoDB 읽기 마이크로초 | DAX |
| 자동 DB 자격증명 교체 | Secrets Manager |
| 비정상 API/IP 탐지 | GuardDuty |
| S3 PII 탐지 | Macie |
| EC2 취약점 스캔 | Inspector |
| 전 세계 고정 IP + TCP 가속 | Global Accelerator |
| DR: 핵심만 최소 실행 | Pilot Light |
| DR: 축소 스케일 상시 운영 | Warm Standby |
