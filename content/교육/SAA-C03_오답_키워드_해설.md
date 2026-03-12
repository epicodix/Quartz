---
title: SAA-C03 오답 키워드 해설 - 지문에서 정답으로 가는 로직
tags:
  - SAA-C03
  - AWS
  - 자격증
  - 오답노트
date: 2026-03-10
status: 진행중
priority: 높음
---

# 🎯 SAA-C03 오답 키워드 해설

> [!note] 사용법
> 각 문제마다 **지문 키워드 → 정답 서비스** 연결 로직을 정리.
> 외우는 게 아니라 **키워드 보는 순간 반사적으로 연결**되도록 훈련.

---

## 📑 목차

- [[#1. 실수 키워드 놓침|실수 / 키워드 놓침 (9개)]]
- [[#2. 응용 부족|응용 부족 (12개)]]
- [[#3. 진짜 모름|진짜 모름 (10개)]]
- [[#4. 핵심 비교표 모음|핵심 비교표 모음]]

---

## 1. 실수 / 키워드 놓침

> [!tip] 패턴
> 개념은 알고 있으나 지문에서 해당 키워드를 놓침. 시험에서 시간 여유 있으면 자연 해결.

### Q75 — 트랜잭션 삭제 + RESTful API

| 지문 키워드 | 정답 |
|------------|------|
| 트랜잭션 삭제, 메시지 큐 | SQS |
| RESTful API 엔드포인트 | API Gateway |

**해답 로직:** 삭제 요청 → SQS 큐잉 → API Gateway로 REST 노출

---

### Q176 — 트래픽이 AWS 네트워크를 벗어나지 않도록

| 지문 키워드 | 정답 |
|------------|------|
| AWS 네트워크 벗어나지 않음 | VPC 엔드포인트 |
| DynamoDB / S3 접근 | Gateway Endpoint (무료) |
| 기타 AWS 서비스 | Interface Endpoint |

**해답 로직:** "인터넷 경유 금지" = VPC Endpoint 즉시 선택

---

### Q213 — SQL 주입 / 스크립팅 공격 차단

| 지문 키워드 | 정답 |
|------------|------|
| SQL 인젝션 | WAF |
| XSS (크로스 사이트 스크립팅) | WAF |
| 레이어7 공격 | WAF |
| DDoS | Shield |

**해답 로직:** "SQL 주입" or "스크립팅" 단어 보이면 → WAF 반사 선택

---

### Q310 — 구매 후 파일 액세스 URL 제공

| 지문 키워드 | 정답 |
|------------|------|
| 구매 후 파일 접근 허용 | Pre-signed URL |
| 임시 URL, 시간 제한 | Pre-signed URL |
| AWS 계정 없는 외부 사용자 | Pre-signed URL |

**해답 로직:** "구매 → 파일 접근 URL" = Pre-signed URL. CloudFront Signed URL은 CDN 배포 시.

---

### Q374 — 여러 VPC 연결 (3개 이상)

| 지문 키워드 | 정답 |
|------------|------|
| 모든 VPC가 서로 통신 (3개+) | Transit Gateway |
| 전이적 라우팅 필요 | Transit Gateway |
| VPC 2~3개 소규모 | VPC Peering |

**해답 로직:** VPC 여러 개 + "모든 VPC 통신" = TGW. Peering은 N*(N-1)/2 연결 필요.

---

### Q401 — 단일 실패 지점 방지

| 지문 키워드 | 정답 |
|------------|------|
| 단일 실패 지점 제거 | Multi-AZ |
| 고가용성 (HA) | Multi-AZ |
| 장애 조치 자동화 | Multi-AZ + ALB |

---

### Q474 — 모든 리전의 모든 VPC와 통신

| 지문 키워드 | 정답 |
|------------|------|
| 모든 리전, 모든 VPC 통신 | Transit Gateway (리전 간 피어링) |
| 리전 간 TGW 연결 | TGW Inter-Region Peering |

---

### Q479 — 구성 검증 후 배포

| 지문 키워드 | 정답 |
|------------|------|
| 인프라 코드로 배포 | CloudFormation |
| 배포 전 검증 | CloudFormation Change Set |
| 일관된 환경 복제 | CloudFormation Template |

---

### Q663 — 데이터베이스 요청 캐싱

| 지문 키워드 | 정답 |
|------------|------|
| DB 요청을 캐시 | ElastiCache Redis |
| 세션 저장, 리더보드 | Redis |
| 단순 캐시, 멀티스레드 | Memcached |

> [!warning] 습관 주의
> "캐시" 보이면 바로 Redis 가는 습관 — 지문에서 "DB 요청 캐시" 명시 확인 필수.

---

## 2. 응용 부족

> [!tip] 패턴
> 개념은 알지만 지문의 특정 조건을 정답과 연결 못함.

### Q52 — 다양한 크기 출력 파일 + 고가용성 + 최소 오버헤드

| 지문 키워드 | 정답 |
|------------|------|
| 다양한 크기 파일 생성 | EFS (크기 제한 없음, 자동 확장) |
| 여러 EC2 동시 접근 | EFS |
| 고가용성 | EFS (Multi-AZ 기본) |

**함정:** S3도 파일 저장 가능하나 → 마운트해서 직접 파일 I/O 필요 → EFS

---

### Q128 — 상태 비저장 + 중단 허용 + 비용 최소화

| 지문 키워드 | 정답 |
|------------|------|
| 상태 비저장 (Stateless) | 컨테이너 (ECS/EKS) 적합 |
| 중단 허용 (Interruption Tolerant) | Spot Instance |
| 비용 최소화 | Spot |

**해답 로직:** 상태 비저장 + 중단 허용 = Spot이 핵심. ECS vs EKS는 "기존 Kubernetes 사용 여부"로 구분.

---

### Q141 — 가능한 빨리 전 세계 사용자에게 콘텐츠 제공

| 지문 키워드 | 정답 |
|------------|------|
| 정적 콘텐츠, 전 세계 배포 | CloudFront |
| 동적 콘텐츠, 전 세계 TCP 가속 | Global Accelerator |
| 단순 HTTP 트래픽 분산 | ALB (리전 내) |

**함정:** "전 세계" 보인다고 Route53 리전 라우팅 선택 금지. 콘텐츠 전송이면 CloudFront.

---

### Q200 — Cognito + API Gateway 접근 제어

| 지문 키워드 | 정답 |
|------------|------|
| 사용자 로그인/인증 | Cognito 사용자 풀 |
| AWS 리소스 접근 권한 | Cognito 자격증명 풀 |
| API Gateway 접근 제어 | Cognito 사용자 풀 권한 부여자 |

**해답 로직:** "API Gateway + Cognito 검증" = 사용자 풀 권한 부여자(Authorizer) 설정

```
사용자 → 로그인(User Pool) → JWT 토큰 → API Gateway → Cognito Authorizer 검증 → 허용
```

---

### Q217 — 기본 인프라 정상 시 부하 처리 불필요 + 활성-수동 장애 조치

| 지문 키워드 | 정답 |
|------------|------|
| 기본 인프라 정상 시 불필요 | Pilot Light |
| 활성-수동 장애 조치로 충분 | Pilot Light 또는 Warm Standby |
| 핵심 시스템만 최소 실행 | Pilot Light |

**DR 전략 키워드 매핑:**
- "수시간 RTO 허용" → Backup & Restore
- "핵심만 최소 실행, 장애 시 스케일 업" → Pilot Light
- "축소 스케일로 항상 실행" → Warm Standby
- "항상 풀 스케일" → Active-Active

---

### Q243 — 파일 기반 애플리케이션 + 최소 대기 시간

| 지문 키워드 | 정답 |
|------------|------|
| 파일 기반 | EFS 가능성 있음 |
| **최소 대기 시간으로 데이터 제공** | S3 + CloudFront |
| 전 세계 사용자 | CloudFront 캐싱 |

> [!warning] 함정
> "파일 기반" → EFS 선택 충동 주의.
> "최소 대기 시간 + 전 세계" 키워드가 있으면 CloudFront가 우선.

---

### Q419 — 최소 관리 원칙 + 조직 전체 정책

| 지문 키워드 | 정답 |
|------------|------|
| 조직 전체 계정에 적용 | SCP (Service Control Policy) |
| 루트 포함 모든 IAM 차단 | SCP |
| 최소 권한 원칙 조직 레벨 | SCP |

**해답 로직:** "조직(Organization) + 전체 계정 + 정책 강제" = SCP. 개별 계정 IAM으로는 불충분.

---

### Q445 — 이전 기간 데이터 접근 + 업데이트 + S3 이동

| 지문 키워드 | 정답 |
|------------|------|
| 온프레미스 → AWS 데이터 이동 | DataSync |
| 이전 기간 데이터 접근 유지 | DataSync로 S3 복사 후 로컬 유지 |
| 정기적 동기화 | DataSync 예약 실행 |

---

### Q490 — 최소한의 코딩 + 지속적 백업 + RCU 영향 없음

| 지문 키워드 | 정답 |
|------------|------|
| 최소 코딩, 백업 자동화 | AWS Backup |
| DynamoDB 백업 | AWS Backup (온디맨드/예약) |
| RCU/WCU 영향 없음 | AWS Backup (백그라운드 처리) |

---

### Q519 — 데이터 신속 수집 + 분석 + 카탈로그

| 지문 키워드 | 정답 |
|------------|------|
| 데이터 카탈로그, 메타데이터 관리 | AWS Glue Data Catalog |
| ETL 변환 | AWS Glue |
| S3 데이터 SQL 분석 | Athena + Glue Catalog |

---

### Q594 — 실행/로드에 오랜 시간 + Lambda 콜드 스타트

| 지문 키워드 | 정답 |
|------------|------|
| 콜드 스타트 제거 | Provisioned Concurrency |
| 초기화 시간 오래 걸림 | Provisioned Concurrency |
| 예열된 Lambda 유지 | Provisioned Concurrency (웜 풀) |

**Reserved vs Provisioned:**
- Reserved: 최대 동시 실행 수 제한 (콜드 스타트 해결 안됨)
- Provisioned: 미리 초기화 상태 유지 (콜드 스타트 없음)

---

### Q626 — 데이터 무결성 자동 검증 + 전송

| 지문 키워드 | 정답 |
|------------|------|
| 데이터 무결성 검증 | DataSync (자동 체크섬 검증) |
| 온프레미스 → AWS 전송 | DataSync |
| 전송 중 검증 | DataSync |

**DataSync 핵심 특징:** 전송 시 자동으로 체크섬 검증. 데이터 손상 자동 감지.

---

## 3. 진짜 모름

> [!warning] 집중 암기 필요

### Q101 — Object Lock 모드 선택 (100년 보존)

| 지문 키워드 | Governance | Compliance |
|------------|-----------|------------|
| 관리자도 삭제 가능 | ✅ | ❌ |
| 루트도 삭제 불가 | ❌ | ✅ |
| 보존 기간 변경 가능 | 특권 사용자 가능 | ❌ 절대 불가 |
| 규정 준수 (금융/의료) | 덜 엄격 | 엄격 |

**키워드 매핑:**
- "변경/삭제 절대 불가", "규정 준수 필수" → **Compliance**
- "내부 정책, 실수 방지, 관리자 예외 허용" → **Governance**

> [!danger] 함정
> 100년 보존 요구 + "어떤 사용자도 수정 불가" → **Compliance 모드**
> 100년이어도 "관리자는 변경 가능" → Governance

---

### Q260 & Q334 — Active Directory 연동

| 시나리오 | 정답 서비스 |
|---------|-----------|
| 온프레미스 AD 그대로 유지 + AWS 연동 | AD Connector |
| 완전 관리형 AD, 클라우드 네이티브 | AWS Managed Microsoft AD |
| 소규모, 간단한 AD 기능 | Simple AD |
| MFA + AD 통합 | AD Connector + MFA |

**키워드 매핑:**
- "기존 AD 유지", "동기화 없이 프록시" → **AD Connector**
- "AWS에서 완전 관리", "트러스트 관계" → **Managed Microsoft AD**
- "300명 이하 소규모" → **Simple AD**

---

### Q414 — DataSync vs File Gateway 구분

| | DataSync | File Gateway |
|--|---------|-------------|
| 목적 | 데이터 이동/마이그레이션 | 지속적 온프레미스 파일 접근 |
| 실행 방식 | 일회성 or 예약 실행 | 상시 실행 |
| 프로토콜 | 에이전트 기반 | NFS / SMB |
| 적합 케이스 | 마이그레이션, 배치 동기화 | 온프레미스 앱이 S3를 파일처럼 사용 |

**키워드 매핑:**
- "거의 실시간", "지속적", "온프레미스 앱이 S3 접근" → **File Gateway**
- "마이그레이션", "일정 주기 동기화", "배치" → **DataSync**

---

### Q523 — 여러 DynamoDB 테이블 조회, 기본 성능 영향 없이

| 지문 키워드 | 정답 |
|------------|------|
| 여러 데이터 소스 SQL 조회 | Athena Federated Query |
| DynamoDB 기본 성능 영향 없음 | Federated Query (Lambda 커넥터) |
| 운영 효율적 | Federated Query (서버리스) |

**해답 로직:**
```
Athena Federated Query
= Lambda 커넥터로 DynamoDB/RDS/Redis 등 여러 소스 SQL 조회
= 원본 DB에 직접 부하 없이 분리된 Lambda로 처리
```

---

### Q547 — 대용량 스트리밍 → S3, 최소 운영 오버헤드

| 지문 키워드 | 정답 |
|------------|------|
| 스트리밍 데이터 수집 | Kinesis |
| S3로 직접 전달 | Kinesis Data **Firehose** |
| 최소 운영 오버헤드 | Firehose (완전 관리형) |
| 재처리/Replay 필요 | Kinesis Data Streams |

**키워드 매핑:**
- "스트리밍 + S3 저장 + 최소 오버헤드" → **Firehose**
- "스트리밍 + 재처리 + 여러 소비자" → **Data Streams**

---

### Q550 — ECS 실행 역할 vs 태스크 역할

| 역할 | 목적 | 예시 |
|------|------|------|
| ECS 실행 역할 (Execution Role) | ECS 에이전트가 AWS 접근 | ECR 이미지 pull, CloudWatch 로그 쓰기 |
| ECS 태스크 역할 (Task Role) | 컨테이너가 AWS 접근 | 컨테이너가 S3, DynamoDB 접근 |

**키워드 매핑:**
- "ECR에서 이미지 가져오기", "로그 전송" → **실행 역할**
- "컨테이너가 S3/DynamoDB 접근" → **태스크 역할**

---

### Q556 — EC2가 DynamoDB 접근, 자격증명 노출 금지

| 지문 키워드 | 정답 |
|------------|------|
| API 자격증명 노출 금지 | IAM Role (액세스 키 사용 금지) |
| 저장 + 검색 (읽기/쓰기) | 읽기 + 쓰기 권한 모두 포함 |
| EC2 인스턴스 프로필 | IAM Role → 인스턴스 프로필 연결 |

> [!warning] A vs B 함정
> A: 읽기 권한만 (Read Only)
> B: 읽기 + 쓰기 권한
> 지문에 "저장하고 검색" = 읽기+쓰기 → **B 선택**

---

### Q698 — MSK (Managed Streaming for Kafka) 보안

| 지문 키워드 | 정답 |
|------------|------|
| 클라이언트 인증서 기반 인증 | mTLS |
| 사용자명/비밀번호 인증 | SASL/SCRAM |
| 브로커 간 암호화 | TLS |
| 저장 데이터 암호화 | KMS |

**MSK 인증 방식:**
- mTLS: 클라이언트 인증서 ↔ 서버 인증서 상호 검증
- SASL/SCRAM: ID/PW 기반, Secrets Manager 통합
- IAM: IAM 정책 기반 (MSK Serverless 포함)

---

## 4. 핵심 비교표 모음

### S3 스토리지 클래스 최소 보관 기간

| 클래스 | 최소 보관 | 최소 크기 |
|--------|---------|---------|
| Standard | 없음 | 없음 |
| Intelligent-Tiering | 없음 | 128KB 미만은 FA 고정 |
| Standard-IA | 30일 | 128KB |
| One Zone-IA | 30일 | 128KB |
| Glacier Instant | 90일 | 128KB |
| Glacier Flexible | 90일 | 40KB |
| Glacier Deep Archive | 180일 | 40KB |

### DR 전략 4종

| 전략 | RTO | RPO | 비용 | 특징 |
|------|-----|-----|------|------|
| Backup & Restore | 수시간 | 수시간 | ★ | S3 백업 후 복원 |
| Pilot Light | 수십분 | 분 | ★★ | 핵심만 최소 실행 |
| Warm Standby | 수분 | 초~분 | ★★★ | 축소 스케일 상시 운영 |
| Active-Active | ~0 | ~0 | ★★★★ | 완전 이중화 |

### ELB 종류

| | ALB | NLB | GWLB |
|--|-----|-----|------|
| 레이어 | 7 (HTTP) | 4 (TCP/UDP) | 3 (IP) |
| 정적 IP | ❌ | ✅ | - |
| 경로 기반 라우팅 | ✅ | ❌ | - |
| WebSocket | ✅ | ✅ | - |
| 용도 | 웹앱 | 게임/금융/TCP | 방화벽 어플라이언스 |

### Route 53 라우팅 정책

| 정책 | 용도 | 키워드 |
|------|------|--------|
| Simple | 단순 레코드 | - |
| Weighted | A/B 테스트 | 비율, 카나리 |
| Latency | 최저 지연 리전 | 가장 빠른 리전 |
| Failover | Active-Passive | 장애 조치, 자동 전환 |
| Geolocation | 국가/지역별 | 특정 국가 트래픽 |
| Multivalue | 복수 IP | 단순 LB |

### SQS 핵심 파라미터

| 파라미터 | 기본 | 최대 | 용도 |
|---------|------|------|------|
| Visibility Timeout | 30초 | 12시간 | 처리 중 숨김 (Lambda 타임아웃보다 길게) |
| Message Retention | 4일 | 14일 | 보존 기간 |
| Delivery Delay | 0 | 15분 | 전송 지연 |
| Max Receive Count | - | - | DLQ 이동 기준 |

---

> [!tip] 시험 당일 루틴
> 1. 이 노트 키워드 매핑표 10분 복습
> 2. hard65 오답 번호만 재확인
> 3. DR 전략 4종, AD 서비스 3종 암기 확인
