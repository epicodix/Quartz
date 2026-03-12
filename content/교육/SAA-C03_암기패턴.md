---
title: SAA-C03 족집게 암기패턴
tags:
  - AWS
  - SAA-C03
  - 자격증
date: 2026-03-07
status: 진행중
---

# SAA-C03 족집게 암기패턴

> [!tip] 사용법
> 문제 읽기 전에 **키워드만 스캔** → 여기서 패턴 매칭 → 보기 읽기
> 아침에 1독하고 문제 풀면 정답률 확 올라감

---

## 1. 핵심 판단 기준 (제일 중요)

| 키워드 | 정답 방향 |
|--------|-----------|
| **막는다 / 차단** | SCP, Network Firewall, NACL, Security Group |
| **탐지 / 알람만** | Config, GuardDuty, CloudTrail |
| **웹 공격 방어** | WAF (SQL Injection, XSS 등) |
| **특정 국가 접근 제한** | WAF (지리적 차단) |
| **리전 제한 / 계정 정책** | SCP, Control Tower 가드레일 |
| **최소 운영 오버헤드** | 관리형 서비스 (RDS, Lambda, SQS, Fargate) |
| **비용 최적화** | S3-IA/Glacier, Spot, Reserved, Savings Plans |
| **고가용성** | Multi-AZ, Auto Scaling, ELB |
| **인터넷 없이 AWS 서비스** | VPC Endpoint |
| **AWS 계정 없는 외부인** | 공유 링크 (CloudWatch, QuickSight 등) |
| **누가 변경했나 / API 이력** | CloudTrail |
| **무엇이 바뀌었나 / 리소스 상태** | Config |
| **SMB 프로토콜 + S3 저장** | S3 File Gateway |
| **외부 계정 접근 허용** | IAM 역할 위임 (IAM 사용자 생성 절대 X) |
| **단일 계정 내 그룹 권한** | IAM 정책 (SCP X) |
| **타사 어플라이언스 + IP 패킷 검사** | GWLB |
| **소셜 네트워크 / 관계 분석 / 추천** | Neptune + Neptune Streams |
| **디바이스별 다른 콘텐츠** | Lambda@Edge (User-Agent 헤더) + CloudFront |
| **멀티 계정 + 중앙 디렉터리 인증** | Organizations + IAM Identity Center(SSO) |
| **암호화된 스냅샷 교차 계정 공유** | KMS 키 정책에 상대 계정 추가 + 스냅샷 공유 |

---

## 2. 네트워크 서비스 한 줄 정리

| 서비스 | 한 줄 | 함정 |
|--------|-------|------|
| **Network Firewall** | VPC 트래픽 검사 + 필터링 (AWS 자체 방화벽) | GuardDuty랑 혼동 금지 |
| **GWLB** | 타사 방화벽 어플라이언스 앞에 세우기 (L3, IP 패킷) | ALB/NLB는 타사 어플라이언스 아님 |
| **ALB** | L7, URL/헤더/경로 기반 라우팅 | |
| **NLB** | L4, 고정 IP, 초고성능 TCP | |
| **GuardDuty** | 위협 탐지만 함, 막지는 않음 | 막는다고 착각 금지 |
| **Transit Gateway** | VPC 여러 개 허브로 연결 | 트래픽 검사 아님 |
| **PrivateLink** | 타사 서비스를 내 VPC 안으로 | |
| **VPC Endpoint** | 인터넷 없이 AWS 서비스 접근 | |
| **CloudFront** | CDN + 엣지 캐싱 | 인증서는 반드시 us-east-1 |
| **Traffic Mirroring** | 트래픽 복사 (분석용) | 필터링 아님 |
| **Firewall Manager** | 멀티 계정 방화벽 중앙 관리 | 단일 계정엔 필요 없음 |

---

## 3. ACM 인증서 리전 규칙

> [!warning] 시험 단골 함정
> - **CloudFront** + ACM → 반드시 **us-east-1**
> - **Regional API Gateway** + ACM → **API GW와 같은 리전**
> - **ALB** + ACM → **ALB와 같은 리전**

---

## 4. 스토리지 / 데이터베이스 패턴

| 상황 | 정답 |
|------|------|
| **DB 자격증명 저장 + 자동 교체** | Secrets Manager |
| **설정값 저장 (교체 불필요)** | Parameter Store |
| **온프레미스 → EFS 자동 마이그레이션** | DataSync 에이전트 설치 + 같은 AZ EC2 |
| **대용량 오프라인 이전** | Snowball |
| **실시간 스트리밍 + 쿼리** | Kinesis Data Streams + Kinesis Analytics |
| **배치성 데이터 적재** | Kinesis Firehose → S3/Redshift |
| **메시지 순서 보장** | SQS FIFO or Kinesis (파티션키 동일하게) |
| **S3 쿼리** | Athena |
| **읽기/쓰기 트래픽 분리** | Read Replica (Multi-AZ는 장애복구용, 읽기분리 X) |
| **40초 내 장애조치 + 읽기 오프로드** | Multi-AZ 클러스터 + 리더 엔드포인트 |
| **S3 우발적 삭제 보호** | 버전 관리 + MFA 삭제 활성화 |
| **SMB + 장기보관 24시간 내 검색** | S3 File Gateway + Glacier Deep Archive (표준=12시간) |
| **DR - 핵심만 켜둠** | 파일럿 라이트 (Pilot Light) |
| **DR - 감소 용량으로 항상 켜짐** | 웜 대기 (Warm Standby) |
| **DR - 즉시 전환** | 멀티 사이트 액티브-액티브 |
| **24시간 RPO + 비용 최소 DR** | 스냅샷 교차 리전 복사 |

---

## 5. 보안 패턴

| 상황                        | 정답                             |
| ------------------------- | ------------------------------ |
| **외부 AWS 계정에 내 계정 접근 허용** | 교차 계정 IAM 역할 (절대 IAM 사용자 생성 X) |
| **조직 전체 서비스/리전 제한**       | 루트 OU에 SCP                     |
| **리전 제한 + 인터넷 차단 예방**     | Control Tower 가드레일             |
| **AWS 계정 없는 외부인 대시보드 공유** | CloudWatch 공유 링크               |
| **IAM 암호 복잡성 / 교체 주기**    | 계정 전체 암호 정책 (개별 설정 X)          |
| **Config**                | 탐지만, 막지 않음                     |
| **API 구독자만 접근 제어**        | API 사용 계획 + API 키              |

---

## 6. 자주 나오는 함정 모음

> [!danger] 이것만 기억하자

1. **GuardDuty = 탐지만, 차단 불가** → 차단하려면 Network Firewall 또는 WAF
2. **WAF = 웹 공격 방어** → VPC 인터넷 차단이나 계정 정책과 무관
3. **Config = 감지/경고만** → 실제 차단은 안 됨
4. **SQS 일반 = 순서 보장 안됨** → FIFO 써야 순서 보장
5. **Parameter Store = 자동 교체 없음** → Secrets Manager가 자동 교체
6. **IAM 사용자 = 내부용** → 외부 계정엔 IAM 역할 위임
7. **Firehose = 실시간 아님** → 진짜 실시간은 Kinesis Data Streams
8. **인스턴스 스토어 = 재부팅 시 데이터 소실** → 영구 저장은 EBS/EFS/S3
9. **스팟 인스턴스 = 중단 가능** → Stateful 앱에 쓰면 안됨
10. **CloudFront ACM = us-east-1 고정**
11. **Multi-AZ = 장애복구용** → 읽기 분리 안됨, Read Replica 써야 함
12. **SCP = 조직/다수 계정용** → 단일 계정 권한은 IAM 정책
13. **크로스 리전 VPC 피어링** → 보안그룹 ID 참조 불가, IP 주소 써야 함
14. **같은 리전 VPC 피어링** → 보안그룹 ID 참조 가능
15. **Glacier Deep Archive 표준 검색 = 12시간** → 24시간 이내 충족 가능
16. **ACM = SSL 인증서용** → 범용 암호화 키 관리는 KMS
17. **QLDB = 금융/감사 원장용** → 소셜 네트워크 관계는 Neptune
18. **SNS 데드레터 큐 = 전달 실패 메시지만 보관** → 정상 플로우 변경 없음
19. **예산 임계값 도달 시 리소스 차단** → AWS Budgets + IAM 역할 + SCP
20. **Lambda는 Tomcat 지원 안함** → Java/Tomcat 앱은 Elastic Beanstalk

---

## 7. 이미지 연상 암기법

> [!tip] 그림으로 외우면 절대 안 까먹음

### 보안 / 모니터링

| 서비스 | 이미지 연상 | 핵심 |
|--------|-------------|------|
| **GuardDuty** | 경비원 — 수상한 사람 발견하고 **보고만** 함, 잡진 않음 | 탐지만 |
| **Network Firewall** | 소방 방화문 — **물리적으로 막음** | 차단 |
| **WAF** | 웹사이트 입구 보안검색대 — **웹 공격만** 막음 | SQL injection, XSS |
| **Config** | CCTV — **녹화만**, 막지 않음 | 감지/기록 |
| **CloudTrail** | 블랙박스 — 누가 뭘 했는지 **기록만** | API 이력 |
| **Macie** | 개인정보 탐지견 — S3에서 **민감한 데이터 냄새 맡음** | S3 개인정보 탐지 |
| **Inspector** | 건물 안전 점검원 — EC2/컨테이너 **취약점 스캔** | 취약점 진단 |
| **Shield** | 방패 — **DDoS 공격 막기** | Standard=무료, Advanced=유료 |
| **SCP** | 회사 취업규칙 — 전 직원 **강제 적용**, 예외 없음 | 조직 전체 정책 |
| **Secrets Manager** | 금고 + 자동 잠금장치 — 비밀번호 넣고 **자동으로 바꿔줌** | 자동 교체 |
| **Parameter Store** | 메모장 — **저장만**, 안 바꿔줌 | 자동 교체 없음 |
| **KMS** | 열쇠 보관소 — 암호화 키 **중앙 관리** | 키 관리 |

---

### 네트워크

| 서비스 | 이미지 연상 | 핵심 |
|--------|-------------|------|
| **Transit Gateway** | 고속도로 IC — VPC들 **허브로 연결** | VPC 다수 연결 |
| **GWLB** | 세관 검사대 — 짐이 **어플라이언스 통과 후** 목적지로 | 타사 방화벽 연동 |
| **PrivateLink** | 전용 터널 — 타사 서비스를 **내 VPC 안으로** 끌어옴 | 인터넷 안 거침 |
| **VPC Endpoint** | 건물 내부 통로 — 인터넷 안 거치고 **AWS 서비스 직통** | S3, DynamoDB 등 |
| **CloudFront** | 전국 편의점 — **가까운 엣지에서** 바로 줌 | CDN, us-east-1 인증서 |
| **Route 53** | 도로 안내판 — **도메인 → IP** 변환 + 트래픽 분산 | DNS, 헬스체크 |
| **ALB** | 스마트 교통경찰 — URL/헤더 보고 **어디로 갈지** 결정 | L7, 경로 기반 |
| **NLB** | 초고속 분기기 — 내용 안 보고 **무조건 빠르게** | L4, 고정 IP |
| **Direct Connect** | 전용 광케이블 — 인터넷 안 쓰고 **AWS 직접 연결** | 온프레미스 연결 |

---

### 스토리지 / 데이터

| 서비스 | 이미지 연상 | 핵심 |
|--------|-------------|------|
| **S3 Standard** | 일반 책상 위 파일 — 자주 꺼내 씀 | 자주 접근 |
| **S3-IA** | 창고 선반 — 가끔 꺼냄, 꺼낼 때 요금 | 비정기 접근 |
| **Glacier** | 지하 냉동 창고 — 거의 안 꺼냄, 꺼내는 데 시간 걸림 | 장기 보관 |
| **EBS** | PC 하드디스크 — **EC2 한 대에 붙음** | 단일 AZ |
| **EFS** | 공유 네트워크 드라이브 — **여러 EC2가 동시에** 씀 | 멀티 AZ |
| **FSx** | 전문가용 공유 드라이브 — Windows(SMB) or 고성능(Lustre) | 특수 파일시스템 |
| **DataSync** | 이사업체 — 온프레미스 데이터 **AWS로 이사** | 데이터 마이그레이션 |
| **Snowball** | 이삿짐 트럭 — 인터넷 느리면 **물리적으로 옮김** | 대용량 오프라인 |

---

### 컴퓨트 / 메시지

| 서비스 | 이미지 연상 | 핵심 |
|--------|-------------|------|
| **Lambda** | 자판기 — 버튼 누르면 **즉시 실행**, 대기 없음 | 서버리스, 이벤트 기반 |
| **Fargate** | 기사 딸린 렌터카 — 컨테이너 실행하는데 **서버 관리 불필요** | 서버리스 컨테이너 |
| **Spot Instance** | 땡처리 항공권 — **싸지만 취소될 수 있음** | 중단 가능, Stateless만 |
| **Reserved** | 연간 구독권 — **1~3년 약정**, 싸게 씀 | 장기 고정 워크로드 |
| **SQS** | 은행 대기 번호표 — **순서 없이** 처리 (FIFO는 순서대로) | 디커플링 |
| **SNS** | 단체 카톡방 — **한 번에 여러 곳**으로 메시지 발송 | 팬아웃 |
| **EventBridge** | 자동화 비서 — 이벤트 보고 **알아서 처리** | 이벤트 기반 자동화 |
| **Kinesis Streams** | 컨베이어 벨트 — **실시간**으로 데이터 흘러감 | 실시간 처리 |
| **Kinesis Firehose** | 대형 화물차 — **모아서** 목적지로 배달 | 배치, 실시간 아님 |
| **Step Functions** | 플로우차트 — 여러 Lambda를 **순서대로 연결** | 워크플로우 |

---

### DR 전략 (재해 복구)

```
백업/복원     ← 가장 싸고 느림
    ↓
파일럿 라이트  ← 가스레인지 파일럿 불꽃 (DB만 켜둠)
    ↓
웜 대기       ← 공회전 중인 차 (작은 규모로 켜져 있음)
    ↓
멀티 사이트   ← 복사본이 똑같이 돌아감 (가장 비쌈)
```

> [!example] 문제 키워드 → DR 전략 매핑
> - "RTO/RPO 최소" → 멀티 사이트
> - "감소된 용량으로 실행 + 확장 가능" → 웜 대기
> - "핵심 서비스만 유지" → 파일럿 라이트
> - "비용 최소" → 백업/복원

---

## 8. 오답 노트

| 문제 | 내가 고른 것 | 정답 | 핵심 |
|------|-------------|------|------|
| Q19 | C (Transit GW) | D | 타사 어플라이언스 = GWLB |
| Q27 | B (IAM 사용자) | A | AWS 계정 없는 외부인 = 공유 링크 |
| Q56 | B | C | Regional API GW 인증서 = 같은 리전 |
| Q95 | - | D | 읽기분리 = Read Replica (동일 스펙), Multi-AZ는 장애복구 |
| Q102 | A, C | A, B | 온프레미스→EFS = DataSync 에이전트 설치 |
| Q122 | C (ACM) | B | 암호화 키 관리 = KMS, ACM은 SSL 인증서 전용 |
| Q151 | B (WAF) | A, C | WAF는 인터넷 차단 아님, 리전 제한 = Control Tower + SCP |
| Q168 | B (보안그룹) | D | 조직 전체 제한 = 루트 OU SCP |
| Q170 | B (ALB 보안그룹) | C | 국가 제한 = WAF |
| Q222 | B (IAM 사용자) | A | 외부 계정 접근 = IAM 역할 위임 |
| Q261 | A, E | A, C | 디바이스별 콘텐츠 = Lambda@Edge (User-Agent) |
| Q273 | - | B | DR 감소용량+항상켜짐 = 웜 대기 |
| Q320 | - | A | 실시간 쿼리 = Kinesis Streams + Analytics |
| Q339 | - | C | 자동 교체 = Secrets Manager |
| Q349 | D | B | 암호화 스냅샷 공유 = KMS 키 정책에 상대 계정 추가 |
| Q362 | - | B, E | 순서 보장 = SQS FIFO + Kinesis 파티션키 |
| Q364 | - | B, D | SQS+SNS 암호화 = KMS 고객관리키 + 키 정책 + TLS |
| Q366 | - | D | API 구독 제어 = 사용 계획 + API 키 |
| Q395 | D (Config) | C | 누가 변경했나 = CloudTrail |
| Q420 | - | D | 40초 장애조치+읽기오프로드 = Multi-AZ 클러스터 + 리더 엔드포인트 |
| Q455 | - | B, D, F | 예산 차단 = Budgets + IAM 역할 + SCP |
| Q476 | A (SCP) | C | 단일 계정 그룹 권한 = IAM 정책 (SCP는 조직 전체용) |
| Q484 | A, D | A, E | 멀티계정 중앙인증 = Organizations + IAM Identity Center |
| Q510 | - | C | 크로스 리전 VPC 피어링 = IP 주소 (보안그룹 ID 불가) |
| Q558 | A (Transit GW) | B, C | 동일 계정 두 VPC = VPC 피어링 |
| Q588 | B (DMS) | D | 24시간 RPO + 비용최소 = 스냅샷 교차 리전 복사 |
| Q631 | C | B | 소셜 관계 분석 = Neptune + Neptune Streams (QLDB는 금융 원장) |
| Q660 | D | B | 24시간 내 검색 = Deep Archive 표준(12시간)도 가능 |
| Q689 | B (Inbound) | A | VPC→온프레미스 DNS = Outbound Endpoint |

---

> [!note] 학습 현황
> - 1회차: 30%대
> - 2회차: 60%대
> - 3회차: 87% (90문항, 암기 영향)
> - 신규 130문항 진행 중
> - 목표: 신규 문항 70%+ → 시험 예약
