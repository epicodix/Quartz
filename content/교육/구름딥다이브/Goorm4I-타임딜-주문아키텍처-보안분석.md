---
title: 타임딜 주문 아키텍처 상세 설계 및 보안 분석
tags:
  - redis
  - kafka
  - transactional
  - security
  - architecture
  - spring
  - portone
  - devops
aliases:
  - 타임딜 아키텍처
  - 주문 보안 분석
date: 2026-02-24
category: 교육/구름딥다이브
status: 완성
priority: 높음
---

# 🎯 타임딜 주문 아키텍처 상세 설계 및 보안 분석

## 📑 목차
- [[#0. 아키텍처 선택 배경|아키텍처 선택 배경]]
- [[#1. 전체 흐름 요약|전체 흐름 요약]]
- [[#2. Gateway / Filter 레이어|Gateway / Filter 레이어]]
- [[#3. Redis 선차감|Redis 선차감]]
- [[#4. 트랜잭션 경계|트랜잭션 경계]]
- [[#5. 포트원 결제|포트원 결제]]
- [[#6. 웹훅 / 배치 안전망|웹훅 / 배치 안전망]]
- [[#7. 상태 머신|상태 머신]]
- [[#8. Kafka 다운스트림|Kafka 다운스트림]]
- [[#9. 취약점 정리|취약점 정리]]

---

## 0. 아키텍처 선택 배경

> [!note] 면접 단골 질문 대비
> "왜 MSA 안 했어요?" / "왜 Saga 안 썼어요?" / "왜 단일 DB예요?"

### DB 전략: Shared DB (단일 RDS)

| 선택지 | 장점 | 단점 |
|--------|------|------|
| Shared DB | @Transactional로 즉시 정합성 보장 | 스케일 한계 |
| DB per Service | 서비스 독립성, 확장성 | Saga 필수, 복잡성 폭발 |

**Shared DB를 선택한 이유:**
- 이커머스 핵심(재고/결제/주문)은 즉시 일관성(Immediate Consistency) 필수
- 재고가 0인데 PENDING이 남아있으면 안 됨 → Eventually Consistent로는 커버 불가
- 4명 팀에서 DB 3개 + Saga 운영은 비현실적

### Saga 미사용 이유

> [!warning] Saga는 Eventually Consistent 전제
> - Saga = 분산 트랜잭션을 보상(Compensation)으로 처리
> - 이커머스 재고/결제는 Immediately Consistent 필요
> - 단일 DB면 @Transactional로 충분히 해결 가능
> - "문제 없는데 해결책 도입" = 오버엔지니어링

### 모노 DB로 고가용성 확보 방법

```
단일 RDS여도 고가용성 가능:

RDS Multi-AZ
  └─ Primary (ap-southeast-2a)
  └─ Standby (ap-southeast-2b) ← 자동 페일오버

읽기 부하 분산:
  └─ Read Replica → 조회 쿼리 분리
  └─ Redis 캐싱 → 재고/상품 조회 오프로드
```

---

## 1. 전체 흐름 요약

```
클라이언트
  ↓ POST /orders
Gateway (Rate Limit / Auth / 시간 검증)
  ↓
Redis Lua Script (재고 선차감 - Atomic)
  ↓
@Transactional (DB 주문 PENDING)
  ↓
포트원 결제 (트랜잭션 외부)
  ├─ 성공 → PAID + Kafka 발행
  └─ 실패 → FAILED + Redis +1 복구
  ↓
웹훅 (메인) / 배치 (안전망) - 멱등키로 중복 방어
  ↓
Kafka → 배송 / 알림 / 정산 / 로그
```

> [!note] 설계 원칙
> - 동기: Redis + DB + PG (정합성 보장)
> - 비동기: Kafka (후속 처리)
> - 안전망: 웹훅 + 배치 + 멱등키

---

## 2. Gateway / Filter 레이어

> [!tip] 공격 진입점을 여기서 1차 차단

### 검증 순서

1. **Rate Limiter** - 계정당 N req/s 초과 시 `429 Too Many Requests`
2. **JWT 인증 검증** - 실패 시 `401`
3. **타임딜 시간 검증** - 이벤트 시간 범위 밖이면 `400`
4. **계정당 동시 주문 수 제한** - 초과 시 `409`

> [!warning] 재고 점유 공격 방어
> 4번이 없으면 봇이 대량 주문으로 재고를 선점한 뒤 결제 안 하고 PENDING 방치 가능
> PENDING 유지 시간도 30~60초로 짧게 설정 필요

---

## 3. Redis 선차감

### Lua Script (Atomic 보장)

```lua
if stock <= 0 then
  return SOLD_OUT
else
  DECR stock
  SET lock:userId TTL=30s  -- PENDING 점유 시간 제한
  return SUCCESS
end
```

> [!note] Lua Script를 쓰는 이유
> Redis 명령어를 개별로 날리면 DECR과 SET 사이에 다른 요청이 끼어들 수 있음
> Lua는 Redis에서 단일 명령처럼 실행 → 원자성 보장

### 취약점 1 - Redis 복구 경로

> [!danger] Redis -1 성공 → DB 저장 실패 시
> Redis는 이미 -1 됐지만 DB 롤백은 Redis를 되돌리지 않음
> → 재고 영구 손실 발생

**대응:**
```java
try {
    redisStockService.decrease(productId); // Redis -1
    orderRepository.save(order);           // DB PENDING
} catch (Exception e) {
    redisStockService.increase(productId); // 보상: Redis +1
    redisLockService.delete(userId);       // 락 해제
    throw e;
}
```

---

## 4. 트랜잭션 경계

### @Transactional 범위

```
@Transactional 시작
  ├─ 멱등키 중복 체크 (idempotency_keys 테이블)
  │    └─ 중복이면 → 기존 주문 ID 반환 (정상 처리)
  ├─ 주문 INSERT (status = PENDING)
  └─ 실패 시 → Redis INCR + 락 해제 (보상)
@Transactional 종료 (커밋)

포트원 결제 요청 ← 반드시 트랜잭션 외부
```

> [!warning] PG를 트랜잭션 안에 넣으면 안 되는 이유
> - PG 응답 대기 시간(수초) 동안 DB 락 유지
> - 타임딜 같은 고경합 상황에서 Hot Row 경쟁 폭발
> - 트랜잭션 타임아웃 위험

---

## 5. 포트원 결제

### 결제 흐름

```
포트원 결제 요청
  ├─ 성공
  │   ├─ @Transactional: 주문 상태 → PAID
  │   └─ Kafka 이벤트 발행 (order-paid)
  │
  └─ 실패 / 타임아웃
      ├─ @Transactional: 주문 상태 → FAILED
      └─ Redis INCR stock + DEL lock:userId
```

### 취약점 2 - Redis +1 복구 누락

> [!danger] FAILED 처리 후 크래시
> DB는 FAILED 저장 완료
> Redis +1 직전 서버 다운 → 재고 영구 -1 불일치

**대응:** 배치 안전망에서 FAILED 주문의 Redis 재고 복구 커버

---

## 6. 웹훅 / 배치 안전망

### 공통 검증 순서 (웹훅 / 배치 동일)

1. 서명 검증 (웹훅: `x-imp-signature` 헤더)
2. **포트원 API 재조회** - `imp_uid` → 실제 결제 금액 확인
3. **주문 금액 일치 검증** - 재조회 금액 ≠ 주문 금액이면 차단
4. 멱등키 중복 체크
5. 상태 머신 전환 검증
6. 상태 업데이트

> [!danger] 취약점 4 - 금액 재검증 누락
> 서명 검증만 하고 포트원 API 재조회를 안 하면
> 1원짜리 결제로 웹훅 전송 → PAID 처리 가능
> **2번 단계가 핵심, 절대 생략 금지**

### 배치 안전망 대상

```
PENDING 상태가 N분 이상인 주문 조회
  → 포트원 API로 실제 결제 상태 확인
  → 상태 동기화
  → FAILED 주문의 Redis 재고 복구
```

> [!tip] Shed Lock 필요
> 멀티 인스턴스(EKS Pod 여러 개)에서 배치가 중복 실행되면 동일 주문 중복 처리 가능
> → Shed Lock 또는 분산 락으로 배치 중복 방지

---

## 7. 상태 머신

### 허용 전환 테이블

| 현재 상태 | 다음 상태 | 허용 여부 |
|-----------|-----------|-----------|
| PENDING | PAID | ✅ |
| PENDING | FAILED | ✅ |
| FAILED | PAID | ❌ 차단 |
| PAID | FAILED | ❌ 차단 |
| PAID | PAID | ❌ 중복 차단 |
| FAILED | FAILED | ❌ 중복 차단 |

### 취약점 3 - 웹훅 vs 배치 경합

> [!danger] 상태 역전 시나리오
> 1. 웹훅 지연 → 배치가 먼저 FAILED 처리
> 2. 뒤늦게 웹훅 도착 → PAID 전환 시도
> 3. FAILED → PAID 전환을 막지 않으면 이미 환불된 주문이 PAID로 변경

**대응:** 상태 전환 시 현재 상태 검증 후 변경 (DB 낙관적 락 or 명시적 조건부 UPDATE)

```sql
UPDATE orders
SET status = 'PAID'
WHERE id = :orderId AND status = 'PENDING'  -- PENDING일 때만 전환
```

---

## 8. Kafka 다운스트림

### 이벤트 흐름

```
order-paid 토픽
  ├─ 배송 서비스   → DB 주문 상태 재확인 후 처리
  ├─ 알림 서비스   → 멱등키로 중복 알림 방지
  ├─ 정산 서비스   → 금액 재검증 후 정산
  └─ 로그 서비스   → 감사 로그 적재
```

> [!warning] Kafka 메시지만 믿으면 안 됨
> Kafka 토픽에 외부에서 위조 메시지 주입 가능 (ACL 미설정 시)
> 컨슈머에서 반드시 DB 상태 재조회 후 처리

> [!tip] Kafka 보안 설정
> - SASL/TLS 인증 활성화
> - 토픽별 ACL (컨슈머/프로듀서 권한 분리)
> - EKS 내부 네트워크에서만 접근 허용

---

## 9. 취약점 정리

| 번호 | 취약점 | 발생 지점 | 대응 |
|------|--------|-----------|------|
| 1 | Redis -1 후 DB 실패 시 재고 누락 | Redis → DB 경계 | try-finally로 Redis +1 보상 보장 |
| 2 | 결제 실패 후 Redis +1 직전 크래시 | PG → Redis 경계 | 배치 안전망에서 FAILED 주문 재고 복구 |
| 3 | 웹훅 vs 배치 경합으로 상태 역전 | 웹훅 / 배치 동시 실행 | 조건부 UPDATE + 상태 전환 테이블 강제 |
| 4 | 포트원 웹훅 금액 미검증 | 웹훅 수신 | imp_uid로 포트원 API 재조회 필수 |

> [!note] 멱등키 설계
> - 서버에서 UUID로 생성 (클라이언트 값 신뢰 금지)
> - `idempotency_keys` 테이블 별도 관리
> - 웹훅 / 배치 모두 동일한 키로 중복 방어

---

## 관련 노트
- [[Goorm4I-팀프로젝트-인프라-세팅]]
