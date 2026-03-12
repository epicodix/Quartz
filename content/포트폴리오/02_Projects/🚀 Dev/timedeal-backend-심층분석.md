---
title: 타임딜 백엔드 - 심층 한계 분석 (개인 참고용)
tags:
  - spring-boot
  - aws
  - architecture
  - deep-analysis
  - personal
aliases:
  - timedeal-deep
  - 타임딜심층분석
date: 2026-03-03
category: 포트폴리오/Dev
status: 완성
priority: 높음
---

# 타임딜 백엔드 — 심층 한계 분석 (개인 참고용)

> [!danger] 이 문서는 개인 참고용이에요
> 면접 준비 문서(`timedeal-backend-면접준비.md`)와는 별개로,
> "우리가 안 한 것, 못 한 것, 알고 있는 한계"를 날것 그대로 정리한 문서예요.
> 팀원용 아니고, 스스로 깊게 이해하기 위한 용도.

---

## 📑 목차
- [[#1. 프론트엔드 병목 — 검증 안 된 최대 미지수|프론트엔드 병목]]
- [[#2. MSA 전환 시 문제가 n배로 늘어나는 이유|MSA 복잡성 폭발]]
- [[#3. 모니터링 공백 — 우리가 못 보고 있는 것들|모니터링 공백]]
- [[#4. 그 외 알고 있는 깊은 구조적 한계들|기타 구조적 한계]]

---

## 1. 프론트엔드 병목 — 검증 안 된 최대 미지수

### 우리가 검증한 것 vs 실제 세계

```
우리가 검증한 것:
K6 → ALB → Spring Boot → Redis/DB
(HTTP 요청 레벨, 백엔드 처리 능력)

실제 Flash Sale에서 일어나는 것:
사용자 브라우저 → CDN → ALB → Spring Boot → Redis/DB
     └─ JavaScript 렌더링
     └─ 버튼 클릭 이벤트
     └─ 네트워크 왕복
     └─ 결제 UI 상태 전환
```

K6는 HTTP 요청을 직접 쏘는 도구예요. 실제 사용자가 브라우저에서 경험하는 것과 다른 부분이 많아요.

---

### 1-1. 대기열(Queue) 없는 Flash Sale의 구조적 문제

**지금 우리 구조:**
```
오픈 시간 → 모든 사용자가 동시에 "구매하기" 클릭 → ALB에 동시 폭발
```

**진짜 Flash Sale이 필요한 것:**
```
오픈 시간 → 대기열 진입 (Waiting Room)
               └─ 순번 발급 (Redis SORTED SET or SQS)
               └─ 앞 사람 처리되면 다음 번호 입장 허가
               └─ 1명씩 또는 N명씩 내보내기
```

대기열이 없으면 생기는 문제:
- **Thundering Herd Problem**: 수천 명이 정확히 같은 시각에 요청 → ALB, Spring, Redis 동시 폭발
- **브라우저 레벨 경합**: JS 타이머로 오픈 시각에 맞추는 유저들 → 1초 안에 수천 요청 집중
- **재고 소진 후 지속적 재시도**: Redis가 SOLD_OUT 반환해도 프론트에서 재시도 루프 → 의미 없는 부하 지속

---

### 1-2. 정적 자산(Static Cache) 관리 미검토

Flash Sale 페이지 자체의 성능:
```
문제: 수천 명이 동시에 /timedeal 페이지를 열면
      → HTML, CSS, JS 파일 요청도 동시에 수천 건
      → S3+CloudFront (CDN)가 없으면 EC2/ALB가 정적 파일까지 다 처리

우리 MVP에서 이 부분은 완전 미검증
→ 백엔드 API가 버텨도 프론트 정적 파일 서빙에서 먼저 터질 수 있음
```

필요한 것:
- CDN(CloudFront) 앞단에서 정적 파일 캐싱
- API 응답 캐싱 (상품 정보는 자주 안 바뀜 → Cache-Control 헤더)
- 남은 재고 실시간 표시는 SSE(Server-Sent Events) 또는 폴링 주기 설계

---

### 1-3. 브라우저 레벨 이중 클릭 방지 미검증

K6는 정직하게 한 번만 요청해요. 실제 사용자는:
- 버튼이 안 눌린 것 같아서 여러 번 클릭
- 네트워크 느리면 앱에서 재시도 로직 있으면 자동 재시도
- HTTP 502 받으면 브라우저 자동 재전송

우리 SELECT FOR UPDATE로 DB 레벨 이중 결제는 막았지만, 이중 주문 시도(PENDING 2건 생성)는 막을 수 없어요. 실제로 K6에서도 동일 유저가 2건 시도하는 시나리오 테스트 없었어요.

---

## 2. MSA 전환 시 문제가 n배로 늘어나는 이유

### 지금 우리 구조의 편안함

```
[Spring Boot 1개 프로세스]
  ├── OrderService
  ├── StockService (Redis)
  ├── PaymentService (Cloud Run 호출)
  └── ProductService

→ 서비스 간 호출 = 메서드 호출 (지연 0ms)
→ 트랜잭션 = @Transactional 하나로 해결
→ 롤백 = JPA가 알아서
→ 로깅 = 단일 로그 파일
```

### MSA로 가면 생기는 문제들

**2-1. 분산 트랜잭션 문제**
```
주문 서비스 ─→ 재고 서비스 ─→ 결제 서비스
     DB-1           DB-2           DB-3

@Transactional이 3개 DB에 걸쳐 동작 안 함
→ 재고는 차감됐는데 결제가 실패하면?
→ 결제는 됐는데 주문 DB 저장이 실패하면?
→ Saga 패턴 (보상 트랜잭션)이 필요
   = 지금 코드 구조를 거의 다시 짜야 함
```

**2-2. 네트워크 지연이 모든 서비스 간에 생김**
```
지금: OrderService.confirmPayment() = 메서드 호출 (~0ms)
MSA: Order-Service → HTTP → Payment-Service = 10~50ms + 오류 가능성

100개 API 호출이 있으면 각각 10ms씩 추가되고
하나라도 실패하면 전체 흐름 실패 가능성
→ Timeout, Retry, Circuit Breaker를 모든 서비스 간 통신에 설정해야
```

**2-3. 분산 추적(Distributed Tracing) 없으면 디버깅 불가**
```
오류 로그:
Order-Service: ERROR 결제 실패
Payment-Service: ERROR 내부 오류
Stock-Service: (로그 없음)

어디서 터진 건지 correlation ID 없으면 추적 불가
→ Jaeger, Zipkin, AWS X-Ray 같은 도구 필요
→ 우리 MVP에서 이미 CloudWatch Appender도 충돌로 포기한 상황
```

**2-4. 데이터 소유권 분리 = 조인 불가**
```
지금: SELECT o.*, p.name FROM orders o JOIN products p ON ...
MSA: Order DB에는 product_id만 있고 product 이름은 Product 서비스에 있음
     → API 호출로 가져와야 함 (N+1 문제의 서비스 버전)
     → 또는 이벤트로 비동기 동기화 (eventual consistency)
```

**2-5. 서비스 간 계약(API Contract) 관리**
```
지금: StockService.decrement(productId) 시그니처 바꾸면 IDE가 전부 알려줌
MSA: Stock-Service API 스펙 바뀌면
     → Order-Service가 런타임에 오류 발생 (컴파일 타임 체크 안 됨)
     → OpenAPI 스펙 관리 + 소비자 주도 계약 테스트(Pact) 필요
     → 버전 관리 (/v1, /v2) 필요
```

**현실 요약:**
```
MVP의 문제 목록: 10개
MSA 전환 후 문제 목록: 10개 × 서비스 수 × 통신 경로 수
                      + 분산 트랜잭션 문제
                      + 분산 추적 문제
                      + 데이터 동기화 문제
                      + 서비스 계약 관리 문제
= 기하급수적으로 증가
```

---

## 3. 모니터링 공백 — 우리가 못 보고 있는 것들

### 3-1. CloudWatch 설정 현황과 공백

**설정된 것:**
```
- EC2 기본 메트릭 (CPU, NetworkIn/Out) — 자동 수집
- ALB 기본 메트릭 (RequestCount, TargetResponseTime) — 자동 수집
- RDS 기본 메트릭 (CPUUtilization, DatabaseConnections) — 자동 수집
```

**없는 것:**
```
- Spring Boot Application 레벨 메트릭 (JVM heap, GC, Tomcat thread)
  → Spring Actuator + CloudWatch Metrics 연동 미구현
  → 처음에 CloudWatch Appender 충돌로 포기

- HikariCP 메트릭 (active/idle/waiting 실시간)
  → 부하테스트 때 로그로만 확인 (실시간 대시보드 없음)

- Redis 메트릭 (hit rate, memory, evicted keys)
  → ElastiCache 기본 메트릭만 있고 앱 레벨 추적 없음

- 커스텀 비즈니스 메트릭
  → 초당 주문 건수, PAID/FAILED 비율, 재고 소진 속도 등
  → 완전히 없음
```

**공백의 실제 의미:**
```
부하테스트 중 무슨 일이 일어나고 있는지 실시간으로 볼 수가 없었음
→ 테스트 끝난 후 로그 파일 분석 + DB 직접 SQL로 사후 분석
→ 프로덕션이라면 이미 장애 발생 후에야 알게 되는 구조
```

---

### 3-2. Grafana 미구현의 의미

Grafana는 시각화 도구고, 데이터 소스가 있어야 해요. 우리 경우:

```
데이터 소스가 될 수 있는 것들:
- CloudWatch (연동 가능하지만 미구현)
- Prometheus (Spring Actuator → Prometheus 연동 미구현)
- RDS Performance Insights (있지만 Grafana로 안 봄)

결과: 숫자는 있는데 한눈에 보이는 대시보드가 없음
→ 이상 감지 → 수동 조회 → 사후 분석 방식
→ 실시간 이상 감지 및 자동 알림 없음
```

**프로덕션에서 필요한 것:**
```
1. Prometheus (메트릭 수집) → Spring Actuator /actuator/prometheus 엔드포인트
2. Grafana (시각화) → JVM, HikariCP, HTTP, 비즈니스 메트릭 대시보드
3. AlertManager → 임계값 초과 시 Slack/PagerDuty 알림
4. Loki (로그 집계) → K6 결과 + 앱 로그 중앙화

이 스택 전체가 MVP에 없음
```

---

### 3-3. 분산 추적(Tracing) 완전 부재

```
현재 로그 형태:
[2026-02-27 11:48:23] INFO  OrderService - 주문 생성: orderId=123
[2026-02-27 11:48:23] INFO  StockService - Redis DECR: product=1, result=99
[2026-02-27 11:48:24] ERROR PaymentService - PG 오류

문제:
- 어떤 요청이 어떤 로그를 생성했는지 연결이 안 됨
- 900 VU 동시에 찍히는 로그에서 orderId=123의 전체 흐름 추적 불가
- Cloud Run(Mock PG) 로그와 Spring Boot 로그 연결 불가

필요한 것:
- MDC (Mapped Diagnostic Context) 로 각 요청에 traceId 부여
- 모든 로그에 traceId 포함
- 외부 서비스 호출 시 traceId 헤더 전파 (X-Trace-Id)
```

---

### 3-4. 알람/인시던트 대응 체계 없음

```
지금: 문제 발생 → 아무도 모름 → 누군가 직접 확인할 때 발견
필요: 문제 발생 → CloudWatch Alarm → SNS → Slack/Email 즉시 알림

미구현 알람 목록:
- HikariCP waiting > 50 → DB 병목 시작 신호
- Redis 연결 오류 → 1차 방어선 위험
- 5xx 에러율 > 5% → 서버 이상
- ALB UnhealthyHostCount > 0 → EC2 다운
- RDS CPUUtilization > 80% → DB 과부하
- PAYING 상태 주문 누적 > 10건 → 고착 시작
```

---

## 4. 그 외 알고 있는 깊은 구조적 한계들

### 4-1. 보안 — HTTP만 열려있는 ALB

```
현재 설정:
ALB: port 80 (HTTP) only
→ HTTPS 없음 → 통신 내용 평문

실제 문제:
- 주문 요청에 userId, 결제 정보가 평문으로 전달됨
- 중간자 공격(MITM) 가능
- WAF(Web Application Firewall) 없음 → SQL Injection, XSS 무방비
- DDoS 보호 없음 → AWS Shield가 기본 탑재이지만 고급 보호 없음

MVP에서 의도적으로 제외했지만, 실제 서비스라면 첫 번째 보안 감사에서 지적됨
```

---

### 4-2. 데이터 라이프사이클 — DB가 무한히 쌓임

```
현재 상태:
주문이 발생할 때마다 orders 테이블에 레코드 추가
→ 삭제 없음, 아카이빙 없음, 파티셔닝 없음

Flash Sale 1회: 수천~수만 건
1년 후: 수백만 건

문제:
- PAID/FAILED는 조회 거의 없지만 계속 인덱스에 포함
- 시간이 지나면 SELECT 속도 저하
- RDS 스토리지 비용 증가

필요한 것:
- 6개월 이상 오래된 주문 → S3 Glacier 아카이빙
- 파티셔닝 (주문 날짜 기준 월별 파티션)
- TTL 있는 Redis 키 관리 (현재 DECR 키가 언제까지 남는지 불명확)
```

---

### 4-3. Flash Sale 시작 시각 정밀도 — 클락 스큐

```
시나리오:
Flash Sale 12:00:00 시작
EC2 서버 시간: 12:00:00.000
Redis 서버 시간: 11:59:59.800 (200ms 빠름)
사용자 브라우저 시간: 12:00:00.500 (500ms 느림)

문제:
- 서버 시각 기준으로 "아직 시작 전" 처리될 수 있음
- 반대로 종료 시각도 부정확해짐
- NTP 동기화가 되어 있어도 ms 단위 차이는 존재

실제 Flash Sale 서비스(쿠팡, 무신사 등)에서 이 부분을 어떻게 처리하는지 궁금한 포인트
→ 서버 단일 시간 기준 + Redis TTL 기반이 가장 안전
```

---

### 4-4. 멱등성(Idempotency) — 재시도 안전성 미구현

```
멱등성이란:
같은 요청을 여러 번 해도 결과가 1번 한 것과 같아야 함

우리 API 현황:
POST /api/orders → 같은 요청 2번 보내면 주문 2건 생성
POST /api/orders/{id}/pay → 같은 요청 2번 보내면?
    → SELECT FOR UPDATE로 2번째는 PAYING 체크로 막힘 ✅
    → 하지만 orderId 자체가 클라이언트에서 생성한다면 또 다른 문제

실제로 필요한 것:
- 클라이언트에서 Idempotency-Key 헤더 전송
- 서버에서 Redis로 "이 키로 이미 처리됨" 캐시 (TTL 24시간)
- 중복 요청 → 캐시 히트 → 이전 응답 그대로 반환

네트워크 오류 + 클라이언트 자동 재시도 시나리오에서 없으면 이중 주문 가능
```

---

### 4-5. RDS 단일 인스턴스 — 읽기 부하 분산 없음

```
현재:
모든 읽기/쓰기가 RDS 단일 인스턴스로

Flash Sale 중 읽기 패턴:
- GET /api/orders/{id} (결과 조회) → 결제한 사람 수만큼 읽기 발생
- GET /api/products/{id} (상품 정보) → 모든 사용자가 반복 조회
- 관리자 통계 조회 → 복잡한 집계 쿼리

문제:
- 쓰기 성능이 중요한 Flash Sale 중에 읽기가 같은 인스턴스를 씀
- RDS Read Replica가 없음
- 상품 정보는 자주 안 바뀌는데 매번 DB 조회

해결책:
- 상품 정보 → Redis 또는 Spring Cache로 캐싱
- 주문 결과 조회 → Read Replica 분리
- 현재는 단일 인스턴스가 모든 부하 감당
```

---

### 4-6. 배포 중 진행 중인 주문 처리

```
현재 배포 방식:
./scripts/deploy.sh → SSM으로 EC2에 kill + 재시작

문제:
kill 시점에 진행 중인 주문이 있으면?
→ TX1 (PENDING 저장 중): DB 롤백됨 (Redis는 복구 안 됨 → 재고 누수)
→ NO TX 구간 (PG 호출 중): PG는 처리 완료됐는데 Spring Boot가 죽으면 PAYING 고착
→ TX3/TX4 (PAID/FAILED 저장 중): DB 롤백 + Redis는 복구 안 됨

Connection Draining (종료 유예 시간)이 없음
→ ALB에서 "새 요청은 안 받고, 기존 요청 처리 완료 후 종료" 설정 필요
→ spring.lifecycle.timeout-per-shutdown-phase 설정 필요
```

---

### 4-7. K6 결과 분석 자동화 없음

```
현재:
k6-result-*.json 파일이 S3에 저장됨
→ 수동으로 다운로드 → jq로 파싱 → 엑셀 붙여넣기

필요한 것:
- S3 업로드 시 Lambda 트리거 → 메트릭 파싱 → CloudWatch/Grafana로 자동 집계
- 테스트 실행 시마다 결과 비교 (전 회차 대비 성능 개선/저하)
- p(50), p(95), p(99) 자동 비교 리포트

이게 있어야 "우리 코드 변경이 성능에 영향 줬는지" 빠르게 알 수 있음
→ CI/CD에 K6 성능 테스트 자동 포함 가능
```

---

### 4-8. 비용 최적화 — 검증 안 된 스케일 비용

```
현재 인프라 월 비용 추정:
EC2 t3.medium: $30/월
RDS db.t3.medium: $60/월
ElastiCache cache.t3.micro: $15/월
ALB: $20/월
NAT Gateway: $35/월 + 데이터 전송
K6 EC2 × 3 (테스트 시만): 무시 가능
총: ~$160~170/월

문제:
지금 사용 중인 AWS 크레딧이 약 $119 남아있음
→ 크레딧 소진 시 즉시 월 $160~170 과금
→ NAT Gateway가 의외로 비쌈 ($0.045/시간 × 720시간 = $32/월 + 데이터 전송)

스케일아웃 비용 시뮬레이션을 해본 적 없음:
EKS 전환 시: EKS 클러스터 기본 $75/월 + 노드 × EC2 비용
RDS Multi-AZ: 단일 인스턴스 대비 2배 비용
→ "성능은 좋아지는데 비용이 얼마나 드는지" 분석 없이 방향만 제시하는 상태
```

---

## 정리: 우리가 모르는 것의 분류

### 알고 있고 해결책도 아는 것 (면접에서 당당하게)
- PAYING 고착 → @Scheduled 스케줄러
- Cold Pool → minimum-idle = maximum-pool-size
- K6 setup() 경합 → master/worker 분리 (이미 해결)
- SELECT FOR UPDATE → 이중 결제 방지

### 알고 있지만 해결책이 복잡한 것 (솔직하게 인정)
- 프론트엔드 병목 → 대기열, CDN, SSE 설계 필요
- 분산 트랜잭션 → Saga 패턴 (대규모 리팩토링)
- 모니터링 공백 → Prometheus + Grafana + AlertManager 스택 구축

### 몰랐는데 이 문서 작성하면서 알게 된 것 (면접 때 "고민해봤어요" 레벨)
- 멱등성 키 미구현 → 네트워크 재시도 시 이중 주문 가능
- 배포 중 Connection Draining 없음 → 진행 중 주문 강제 종료
- Clock Skew → Flash Sale 시작 시각 정밀도
- 데이터 라이프사이클 → DB 무한 증가
- HTTP only ALB → 보안 감사 첫 지적 포인트

---

*작성일: 2026-03-03*
*이 문서는 개인 학습 및 인터뷰 심층 준비용*
