
> **SAA는 문해력보다 패턴 인식! 이 문서 하나로 정리 끝!**

---

## 📦 스토리지 패턴

### S3 스토리지 클래스

| 키워드 | 정답 | 암기 이미지 |
|--------|------|-------------|
| "자주 접근" | S3 Standard | **책상 위** 📚 - 바로 손 닿는 곳 |
| "자주 안 씀 + 즉시 접근" | S3 Standard-IA | **창고 앞쪽 선반** - 안 쓰지만 바로 꺼냄 |
| "패턴 모름 / 변동" | S3 Intelligent-Tiering | **AI 정리왕** 🤖 - 알아서 옮겨줌 |
| "90일+ 거의 안 봄" | Glacier Instant Retrieval | **냉동실** 🧊 - 얼렸지만 바로 해동 |
| "분~시간 대기 OK" | Glacier Flexible Retrieval | **창고 깊숙이** - 찾는데 시간 걸림 |
| "연 1~2회 감사용" | Glacier Deep Archive | **땅에 묻은 타임캡슐** ⏰ - 12시간 기다림 |

### EBS/EFS/기타 스토리지

| 키워드 | 정답 | 암기 이미지 |
|--------|------|-------------|
| "고성능 + 공유 파일" | EFS | **공용 Google Drive** ☁️ |
| "고성능 + 한 서버만" | Instance Store | **RAM디스크** 💨 - 끄면 증발 |
| "Windows 파일 공유" | FSx for Windows | **회사 공유폴더** 📁 |
| "HPC / 수백만 IOPS" | FSx for Lustre | **슈퍼컴퓨터 전용 SSD** 🚀 |
| "NetApp 호환" | FSx for NetApp ONTAP | **엔터프라이즈 NAS** |
| "단일 AZ 저렴" | EFS One Zone | **저렴한 창고** - 재해 취약 |

### 💡 스토리지 선택 공식

```
공유 필요?
  ├─ Yes → 파일 시스템
  │         ├─ Linux  → EFS
  │         ├─ Windows → FSx for Windows  
  │         └─ HPC    → FSx for Lustre
  └─ No  → 블록 스토리지
            ├─ 영구 저장 → EBS
            └─ 임시/초고속 → Instance Store
```

---

## 🔐 보안 패턴

### 탐지 & 방어 서비스

| 키워드 | 정답 | 암기 이미지 |
|--------|------|-------------|
| "이상 탐지 / 위협 탐지" | GuardDuty | **경비원** 👮 - 신고만, 체포 안 함 |
| "SQL Injection / XSS" | WAF | **공항 보안검색대** ✈️ |
| "DDoS 방어" | Shield Advanced | **방패 든 기사** 🛡️ |
| "VPC 트래픽 차단" | Network Firewall | **소방 방화문** 🚪 |
| "설정 변경 추적" | Config | **CCTV** 📹 - 녹화만, 막지 않음 |
| "API 호출 기록" | CloudTrail | **블랙박스** 📦 - 누가 뭘 했는지 기록 |
| "취약점 스캔" | Inspector | **건물 안전점검** 🔍 |
| "민감정보 탐지 (S3)" | Macie | **개인정보 탐정** 🕵️ |

### 키 & 비밀 관리

| 키워드 | 정답 | 암기 이미지 |
|--------|------|-------------|
| "비밀번호 자동 로테이션" | Secrets Manager | **스마트 금고** 🔐 - 자동으로 바꿔줌 |
| "그냥 설정값 저장" | Parameter Store | **포스트잇** 📝 - 저장만, 안 바꿔줌 |
| "암호화 키 관리" | KMS | **마스터키 보관함** 🔑 |
| "HSM 전용" | CloudHSM | **전용 금고실** 🏦 |

### 암호화 선택 공식

```
누가 키 관리?

AWS가 전부       → SSE-S3 (가장 간단)
AWS + 내가 감사  → SSE-KMS (감사 로그 O) ⭐ 자주 출제
내가 전부        → SSE-C (Customer 제공)

💡 "규정 준수 / 감사 / 키 관리" = KMS!
```

### 접근 제어 계층

| 레벨 | 서비스 | 암기 |
|------|--------|------|
| 조직 전체 | SCP | **회사 취업규칙** 📋 - 예외 없음 |
| 사용자/역할 | IAM Policy | **개인 출입증** 🎫 |
| 리소스 | Resource Policy | **문 앞 명단** 📃 |
| 네트워크 | Security Group / NACL | **건물 경비실** 🏢 |

```
⚠️ "SCP가 Deny하면 IAM이 Allow해도 안 됨!"

넓음 ←――――――――――――――――――――→ 좁음
  SCP → IAM → Resource Policy → SG/NACL
```

---

## 🌐 네트워크 패턴

### 연결 서비스

| 키워드 | 정답 | 암기 이미지 |
|--------|------|-------------|
| "VPC 여러 개 연결" | Transit Gateway | **고속도로 IC** 🛣️ |
| "온프레미스 + 전용선" | Direct Connect | **해저 케이블** 🔌 |
| "Direct Connect 백업" | Site-to-Site VPN | **예비 터널** 🚇 |
| "VPC 간 직접 연결" | VPC Peering | **직통 전화** ☎️ |
| "온프레미스 DNS 연동" | Route 53 Resolver | **전화번호부 공유** 📖 |

### VPC 엔드포인트

| 키워드 | 정답 | 암기 이미지 |
|--------|------|-------------|
| "프라이빗 S3/DynamoDB" | Gateway Endpoint | **VIP 전용문** 🚪 - 무료! |
| "프라이빗 API/Lambda" | Interface Endpoint | **내선전화** ☎️ - 돈 나감 |

```
💡 Gateway vs Interface

Gateway Endpoint (무료)
  - S3, DynamoDB만!
  - 라우팅 테이블에 추가
  
Interface Endpoint (유료)
  - 나머지 전부 (API GW, Lambda, SNS...)
  - ENI 생성됨 (프라이빗 IP)
```

### 로드밸런싱

| 키워드 | 정답 | 암기 이미지 |
|--------|------|-------------|
| "HTTP/HTTPS 라우팅" | ALB | **웹 안내데스크** 🖥️ |
| "TCP/UDP 초고속" | NLB | **고속 터널** 🚄 |
| "고정 IP 필요" | NLB | NLB는 고정 IP 지원! |
| "어플라이언스 검사" | GWLB | **세관 검사대** 🛃 |
| "레거시 / Classic" | CLB | **구형** - 신규 비추천 |

### 글로벌 네트워크

| 키워드 | 정답 | 암기 이미지 |
|--------|------|-------------|
| "정적 콘텐츠 캐싱" | CloudFront | **편의점 체인** 🏪 |
| "고정 IP + 글로벌 분산" | Global Accelerator | **전세계 대리점 번호** 🌍 |

```
💡 CloudFront vs Global Accelerator

CloudFront
  - 콘텐츠 캐싱 (이미지, 동영상)
  - 엣지에서 응답
  
Global Accelerator  
  - 캐싱 없음, TCP/UDP
  - 고정 IP 2개 제공
  - 가장 가까운 엣지 → AWS 백본
```

---

## ⚡ 컴퓨팅 패턴

### EC2 관련

| 키워드 | 정답 | 암기 이미지 |
|--------|------|-------------|
| "서버 완전 제어" | EC2 | **자가용** 🚗 - 내가 다 관리 |
| "70%+ 저렴 / 중단 가능" | Spot Instance | **땡처리 항공권** ✈️ |
| "1~3년 약정" | Reserved Instance | **헬스장 연회원** 💪 |
| "유연한 약정" | Savings Plan | **통신사 약정** 📱 |
| "물리 서버 전용" | Dedicated Host | **전용 별장** 🏠 |
| "배치 그룹 / 저지연" | Cluster Placement Group | **같은 방 배치** |
| "분산 / 장애 격리" | Spread Placement Group | **각 방 1명씩** |

### 컨테이너

| 키워드 | 정답 | 암기 이미지 |
|--------|------|-------------|
| "컨테이너 + 서버 관리 싫음" | Fargate | **렌터카** 🚗 - 차만 몰면 됨 |
| "컨테이너 + 서버 제어" | ECS on EC2 | **내 차** - 엔진도 관리 |
| "Kubernetes 필요" | EKS | **쿠버네티스** ☸️ |
| "컨테이너 이미지 저장" | ECR | **컨테이너 창고** 📦 |

### 서버리스 & 배치

| 키워드 | 정답 | 암기 이미지 |
|--------|------|-------------|
| "이벤트 기반 / 짧은 작업" | Lambda | **자판기** 🎰 - 버튼 누르면 실행 |
| "15분 이상 작업" | Fargate / EC2 | Lambda는 15분 제한! |
| "배치 / 대규모 병렬" | AWS Batch | **공장 야간작업** 🏭 |
| "크론잡 / 스케줄" | EventBridge + Lambda | **알람시계** ⏰ |

### 💡 컴퓨팅 선택 공식

```
서버 관리 할래?
  ├─ Yes → EC2 / ECS on EC2
  └─ No  → 서버리스
            ├─ 짧은 작업 (15분↓) → Lambda
            ├─ 컨테이너 → Fargate
            └─ 배치 작업 → AWS Batch
```

---

## 🗄️ 데이터베이스 패턴

### 관계형 DB

| 키워드 | 정답 | 암기 이미지 |
|--------|------|-------------|
| "관계형 + 관리형" | RDS | **아파트** 🏢 - 관리비 내고 편하게 |
| "관계형 + 5배 성능" | Aurora | **펜트하우스** 🌟 - 비싸고 빠름 |
| "서버리스 DB + 간헐적" | Aurora Serverless | **모텔** 🏨 - 쓸 때만 결제 |
| "읽기 부하 분산" | Read Replica | **분신술** 👥 |
| "장애 자동 복구" | Multi-AZ | **보험** 🛡️ |

```
💡 Multi-AZ vs Read Replica

Multi-AZ = "보험" 🛡️
  - 동기 복제, 장애 시 자동 전환
  - 성능 향상 X, 같은 리전
  
Read Replica = "분신술" 👥  
  - 비동기 복제, 읽기 분산
  - 장애조치 수동, 다른 리전 가능
```

### NoSQL & 특수 DB

| 키워드 | 정답 | 암기 이미지 |
|--------|------|-------------|
| "Key-Value + 무한 확장" | DynamoDB | **해시태그 검색** # |
| "밀리초 → 마이크로초" | DAX | **DynamoDB 터보** 🏎️ |
| "인메모리 캐시" | ElastiCache | **냉장고 앞 메모판** 📋 |
| "Redis vs Memcached" | Redis=고급 / Memcached=단순 | **스위스칼 vs 커터칼** 🔪 |
| "그래프 / 관계" | Neptune | **인맥 지도** 🕸️ |
| "시계열 / IoT" | Timestream | **심전도 그래프** 📈 |
| "원장 / 불변" | QLDB | **공증 문서** 📜 - 수정 불가 |
| "문서형 / MongoDB" | DocumentDB | **JSON 서랍장** 📂 |

### 💡 DB 선택 공식

```
SQL 필요?
  ├─ Yes → 고가용성/성능?
  │         ├─ 최고 성능 → Aurora
  │         └─ 일반     → RDS
  └─ No  → 뭘 저장?
            ├─ Key-Value  → DynamoDB
            ├─ 캐시       → ElastiCache
            ├─ 그래프     → Neptune  
            ├─ 시계열     → Timestream
            ├─ 불변 원장  → QLDB
            └─ 문서(JSON) → DocumentDB
```

---

## 📨 메시징 & 통합 패턴

### 메시지 큐

| 키워드 | 정답 | 암기 이미지 |
|--------|------|-------------|
| "순서 보장 / 중복 방지" | SQS FIFO | **은행 번호표** 🎫 |
| "대용량 / 순서 상관X" | SQS Standard | **뷔페 줄** 🍽️ - 빠른 사람 먼저 |
| "1:N 알림 / 팬아웃" | SNS | **확성기** 📢 |
| "SNS + SQS 조합" | 팬아웃 패턴 | **확성기 → 여러 줄** |

### 이벤트 & 스트리밍

| 키워드 | 정답 | 암기 이미지 |
|--------|------|-------------|
| "이벤트 라우팅 / 규칙" | EventBridge | **우체국 분류기** 📮 |
| "실시간 스트리밍" | Kinesis Data Streams | **컨베이어 벨트** �icing |
| "실시간 → S3 전송" | Kinesis Firehose | **소방호스** 🚒 → S3에 쏨 |
| "실시간 SQL 분석" | Kinesis Data Analytics | **실시간 스코어보드** |

### Kinesis 가족 정리

```
💡 Kinesis Family = "실시간" 키워드!

┌─────────────────────┬─────────────────────────────┐
│ Data Streams        │ 실시간 수집 (커스텀 처리)   │
│ Data Firehose       │ 실시간 전송 (S3/Redshift)   │
│ Data Analytics      │ 실시간 분석 (SQL)           │
│ Video Streams       │ 실시간 영상                 │
└─────────────────────┴─────────────────────────────┘

⭐ Firehose = "소방호스로 S3에 쏴버림" 🚒
```

### 워크플로우

| 키워드 | 정답 | 암기 이미지 |
|--------|------|-------------|
| "워크플로우 오케스트레이션" | Step Functions | **플로우차트** 📐 |
| "레거시 SWF" | SWF | **구형** - Step Functions 추천 |

### 💡 메시징 선택 공식

```
1:1 vs 1:N?
  ├─ 1:1 → SQS
  │        ├─ 순서 필요 → FIFO
  │        └─ 순서 불필요 → Standard
  └─ 1:N → SNS (팬아웃)
  
실시간?
  ├─ Yes → Kinesis
  └─ No  → SQS/SNS

이벤트 규칙 라우팅?
  └─ EventBridge
```

---

## 📊 분석 & 빅데이터 패턴

### 분석 서비스

| 키워드 | 정답 | 암기 이미지 |
|--------|------|-------------|
| "S3 쿼리 / 서버리스 SQL" | Athena | **S3 위 돋보기** 🔍 |
| "데이터 웨어하우스" | Redshift | **거대한 엑셀** 📊 |
| "BI 대시보드" | QuickSight | **예쁜 차트 PPT** 📈 |
| "하둡/스파크" | EMR | **빅데이터 공장** 🏭 |
| "검색 엔진 / 로그" | OpenSearch | **사이트 내 검색창** 🔎 |

### ETL & 카탈로그

| 키워드 | 정답 | 암기 이미지 |
|--------|------|-------------|
| "ETL 서버리스" | Glue | **데이터 믹서기** 🧃 |
| "데이터 카탈로그" | Glue Data Catalog | **도서관 색인** 📚 |
| "스키마 자동 발견" | Glue Crawler | **데이터 탐험가** 🔦 |

### 데이터 이동

| 키워드 | 정답 | 암기 이미지 |
|--------|------|-------------|
| "파일 동기화" | DataSync | **이삿짐 센터** 🚚 |
| "대용량 물리 이동 (TB~PB)" | Snowball Edge | **택배 트럭** 📦 |
| "엑사바이트 이동" | Snowmobile | **컨테이너 트럭** 🚛 |
| "하이브리드 스토리지" | Storage Gateway | **클라우드 연결 창고** |

```
💡 데이터 이동 선택

네트워크로 가능?
  ├─ Yes → DataSync (자동화)
  └─ No  → 물리적 이동
            ├─ TB~PB   → Snowball Edge
            └─ EB 이상 → Snowmobile (트럭 옴!)
```

---

## 🤖 AI/ML 패턴

| 키워드 | 정답 | 암기 이미지 |
|--------|------|-------------|
| "이미지 분석 / 얼굴" | Rekognition | **얼굴 인식 카메라** 📷 |
| "텍스트 → 음성" | Polly | **AI 성우** 🎙️ |
| "음성 → 텍스트" | Transcribe | **속기사** ✍️ |
| "번역" | Translate | **통역사** 🌐 |
| "문서 OCR / 추출" | Textract | **OCR 스캐너** 📄 |
| "자연어 이해 / 감정" | Comprehend | **국어 선생님** 📖 |
| "추천 시스템" | Personalize | **넷플릭스 추천** 🎬 |
| "이상 탐지 (지표)" | Lookout for Metrics | **이상 감지 센서** 🚨 |
| "ML 모델 구축" | SageMaker | **AI 연구소** 🔬 |
| "챗봇" | Lex | **AI 상담원** 💬 |
| "예측" | Forecast | **일기예보** 🌤️ |
| "사기 탐지" | Fraud Detector | **신용카드 이상거래** 💳 |
| "코드 추천" | CodeWhisperer | **AI 페어 프로그래머** 👨‍💻 |

---

## 🔄 마이그레이션 패턴

| 키워드 | 정답 | 암기 이미지 |
|--------|------|-------------|
| "DB 마이그레이션" | DMS | **DB 이삿짐** 🚚 |
| "스키마 변환" | SCT | **통역 + 이사** - DMS 세트 |
| "서버 마이그레이션" | MGN | **서버 복제기** 📠 |
| "VMware 그대로" | VMware Cloud on AWS | **VMware 호텔** 🏨 |
| "마이그레이션 현황" | Migration Hub | **이사 현황판** 📋 |

### 💡 마이그레이션 선택 공식

```
뭘 옮김?
  ├─ DB     → DMS (+ SCT 스키마 변환)
  ├─ 서버   → MGN (Application Migration Service)
  ├─ 파일   → DataSync
  └─ 대용량 → Snowball / Snowmobile

"이기종 DB (Oracle→Aurora)" = DMS + SCT!
```

---

## 🔄 DR(재해복구) 패턴

### 4단계 전략 - **"백파워멀"** 로 외우기!

```
💰 비용 낮음 ←―――――――――――――――――――――→ 비용 높음
⏰ RTO 길음 ←―――――――――――――――――――――→ RTO 짧음

   Backup     Pilot      Warm       Multi-Site
   Restore    Light     Standby     Active
     ↓         ↓          ↓           ↓
   백업      파일럿      워밍업       멀티
```

| 전략 | 암기 이미지 | RTO | 비용 |
|------|-------------|-----|------|
| **Backup & Restore** | 📦 이삿짐 - 다 풀어야 함 | 24시간+ | 💰 |
| **Pilot Light** | 🔥 가스레인지 종불 - 불 붙이면 됨 | 수십 분 | 💰💰 |
| **Warm Standby** | 🚗 공회전 차 - 악셀만 밟으면 됨 | 수 분 | 💰💰💰 |
| **Multi-Site Active** | 🏃‍♂️🏃‍♂️ 쌍둥이 - 둘 다 뛰는 중 | 즉시 | 💰💰💰💰 |

```
💡 Pilot Light vs Warm Standby 구분

Pilot Light = 최소한만 실행 (DB만 켜둠)
              → 서버 시작 필요
              
Warm Standby = 축소 버전 실행 중 
               → 스케일 업만 필요
```

---

## 🌍 글로벌 서비스 패턴

### 글로벌 데이터베이스

| 키워드 | 정답 | 설명 |
|--------|------|------|
| "DynamoDB 글로벌" | Global Tables | **전세계 동기화** 🌍 |
| "Aurora 글로벌" | Global Database | **1초 내 복제** ⚡ |
| "S3 글로벌" | Cross-Region Replication | **버킷 복제** |

### Route 53 라우팅 정책

| 정책 | 키워드 | 암기 |
|------|--------|------|
| **Simple** | 기본 | 그냥 하나 (밸런싱 X) |
| **Weighted** | 비율 / A/B테스트 | **저울** ⚖️ |
| **Latency** | 빠른 곳 / 성능 | **스톱워치** ⏱️ |
| **Failover** | Primary-Secondary | **예비 발전기** |
| **Geolocation** | 접속 국가 / 법규 | **여권 검사** 🛂 |
| **Geoproximity** | 거리 + 가중치 | **거리순 + 조절** |
| **Multivalue** | 헬스체크 + 다중 | **예비 여러 개** |

```
💡 Route 53 선택 공식

성능 최적화? → Latency
법적 규제?   → Geolocation  
장애조치?    → Failover
A/B테스트?   → Weighted
```

---

## 💰 비용 최적화 패턴

### 비용 관리 도구

| 키워드 | 정답 | 암기 이미지 |
|--------|------|-------------|
| "미사용 리소스 찾기" | Trusted Advisor | **재무 상담사** 💼 |
| "비용 시각화" | Cost Explorer | **가계부 앱** 📱 |
| "예산 알림" | AWS Budgets | **예산 초과 알림** 🔔 |
| "RI 추천" | Compute Optimizer | **절약 코치** 🏋️ |
| "리소스 최적화" | Compute Optimizer | **다이어트 코치** |

### EC2 구매 옵션

```
💵 비용 비교 (같은 사양 기준)

On-Demand ████████████████████ 100%
Reserved  ████████████         60% (1년)
Reserved  ██████████           40% (3년 전체 선결제)  
Spot      ██████               30% (언제든 뺏김!)
Savings P ████████████         유연한 RI

💡 선택 기준
- 확실하면 → Reserved / Savings Plan
- 중단 가능 → Spot
- 모르겠음 → On-Demand
```

---

## 🏗️ 아키텍처 패턴

### 결합도 낮추기 (Decoupling)

| 상황 | 정답 | 이유 |
|------|------|------|
| "동기 → 비동기" | SQS | 큐에 넣고 잊어버림 |
| "1:N 팬아웃" | SNS + SQS | 확성기 → 여러 줄 |
| "이벤트 기반 라우팅" | EventBridge | 규칙별 분기 |
| "워크플로우" | Step Functions | 플로우차트 |

### 고가용성 (HA)

| 상황 | 정답 |
|------|------|
| "EC2 자동 복구" | Auto Scaling + ALB |
| "RDS 장애조치" | Multi-AZ |
| "읽기 부하 분산" | Read Replica |
| "리전 장애 대비" | 다중 리전 + Route 53 |
| "S3 고가용성" | 기본 99.999999999% (11 9's) |

### Well-Architected 6가지 축

```
💡 "보신성비운지" 로 외우기!

보 - 보안 (Security)
신 - 신뢰성 (Reliability)  
성 - 성능 효율성 (Performance Efficiency)
비 - 비용 최적화 (Cost Optimization)
운 - 운영 우수성 (Operational Excellence)
지 - 지속 가능성 (Sustainability) ← 신규!
```

---

## ❌ 오답 신호 키워드

| 보이면 의심! | 이유 |
|-------------|------|
| "CloudWatch로 **차단**" | ❌ 모니터링만 함 |
| "GuardDuty로 **차단**" | ❌ 탐지만 함 |
| "Config로 **차단**" | ❌ 기록만 함 |
| "S3 Standard로 **아카이브**" | ❌ 비쌈 |
| "Lambda **24시간** 실행" | ❌ 15분 제한 |
| "SQS로 **실시간**" | ❌ 폴링 방식 (Kinesis!) |
| "NAT Gateway로 **인바운드**" | ❌ 아웃바운드 전용 |
| "Read Replica로 **장애조치**" | ❌ 수동임 (Multi-AZ!) |
| "Interface Endpoint로 **S3**" | ❌ Gateway가 무료! |

---

## 🧪 최종 점검 퀴즈

> **Q1.** "로그 파일 90일 후 삭제, 연 1회 감사 접근"
> <details><summary>정답</summary>S3 + Lifecycle → Glacier Deep Archive</details>

> **Q2.** "VPC 3개를 서로 연결, 풀메시 피하고 싶음"
> <details><summary>정답</summary>Transit Gateway</details>

> **Q3.** "RDS 비밀번호 30일마다 자동 변경"
> <details><summary>정답</summary>Secrets Manager</details>

> **Q4.** "주문 처리 순서 보장 + 중복 방지"
> <details><summary>정답</summary>SQS FIFO</details>

> **Q5.** "S3 데이터를 서버리스로 SQL 분석"
> <details><summary>정답</summary>Athena</details>

> **Q6.** "DynamoDB 읽기 지연을 마이크로초로"
> <details><summary>정답</summary>DAX</details>

> **Q7.** "Oracle → Aurora PostgreSQL 마이그레이션"
> <details><summary>정답</summary>DMS + SCT</details>

> **Q8.** "글로벌 유저, 가장 빠른 리전으로 라우팅"
> <details><summary>정답</summary>Route 53 Latency Routing</details>

> **Q9.** "페타바이트 데이터를 AWS로 물리 이동"
> <details><summary>정답</summary>Snowball Edge</details>

> **Q10.** "실시간 클릭스트림 → S3 저장"
> <details><summary>정답</summary>Kinesis Data Firehose</details>

> **Q11.** "프라이빗 서브넷에서 S3 접근 (비용 최소화)"
> <details><summary>정답</summary>Gateway Endpoint (무료)</details>

> **Q12.** "RTO 1시간, 비용 최소화 DR"
> <details><summary>정답</summary>Pilot Light</details>

> **Q13.** "SQL Injection 방어"
> <details><summary>정답</summary>WAF</details>

> **Q14.** "멀티 어카운트 S3 퍼블릭 차단 강제"
> <details><summary>정답</summary>SCP</details>

> **Q15.** "EC2에서 짧은 이벤트 처리로 전환 (비용 최소화)"
> <details><summary>정답</summary>Lambda</details>

---

## 📝 시험 직전 체크리스트

```
□ S3 스토리지 클래스 6개 (비용/속도 순서)
□ DR 전략 4단계 (백파워멀)
□ Kinesis 가족 4개 구분
□ SQS Standard vs FIFO
□ Multi-AZ vs Read Replica  
□ VPC Endpoint (Gateway vs Interface)
□ SSE-S3 vs SSE-KMS vs SSE-C
□ Route 53 라우팅 정책 7개
□ GuardDuty vs Config vs CloudTrail (탐지 vs 기록)
□ Secrets Manager vs Parameter Store
□ ALB vs NLB vs GWLB
□ EFS vs FSx (Linux vs Windows vs HPC)
□ Athena vs Redshift (서버리스 vs 웨어하우스)
□ DMS + SCT (이기종 DB 마이그레이션)
□ Global Accelerator vs CloudFront
```

---

**🎯 시험 팁:**
1. **"가장 비용 효율적"** = 서버리스 우선 (Lambda, Fargate, Athena...)
2. **"최소 운영 오버헤드"** = 관리형 서비스 (RDS, Aurora, Fargate...)
3. **"가장 빠른"** = 캐시 또는 엣지 (CloudFront, DAX, ElastiCache...)
4. **"규정 준수 / 감사"** = KMS, CloudTrail, Config

---

화이팅! 🚀 합격 기원합니다! 🎉