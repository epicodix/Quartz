---
title: Redis 기초개념 - 타임딜로 이해하는 캐시/락/멱등성
tags:
  - redis
  - cache
  - distributed-lock
  - idempotency
  - msa
date: 2026-02-19
category: 2_기술_분석
status: 완성
priority: 높음
---

# 🎯 Redis 기초개념

> [!note] 한 줄 정의
> **"엄청 빠른 메모리 메모장"**
> DB는 디스크에 저장 → 느림. Redis는 RAM에 저장 → 빠름.

```
DB 조회:    요청 → 디스크 → 응답   (~10ms)
Redis 조회: 요청 → 메모리 → 응답   (~0.1ms)
```

---

## 📑 목차
- [[#1. 캐싱|캐싱]]
- [[#2. 재고 카운터|재고 카운터]]
- [[#3. 분산락|분산락]]
- [[#4. 멱등성 키|멱등성 키]]
- [[#5. EKS에서 어디에 사는가|EKS에서 위치]]

---

## 1. 캐싱

**문제상황**: 유저 1000명이 동시에 상품 정보 요청 → DB에 1000번 쿼리 → DB 죽음

**해결**: 첫 번째만 DB에서 가져오고 Redis에 저장. 나머지 999명은 Redis에서 응답.

```bash
# 저장 (EX 60 = 60초 후 자동 삭제)
SET timedeal:1 '{"name":"강아지사료","price":25000}' EX 60

# 조회
GET timedeal:1
# → {"name":"강아지사료","price":25000}
```

> [!tip] EX (Expire)
> 타임딜이 끝나면 캐시도 같이 만료되도록 TTL 설정.
> 딜 종료 시간에 맞춰 EX 값을 설정하면 됨.

---

## 2. 재고 카운터

**문제상황**: 유저 100명이 동시에 구매 클릭 → DB 동시 업데이트 → 재고 100개인데 200개 팔릴 수 있음

**해결**: Redis `DECR`은 원자적(Atomic) 처리. 한 번에 하나씩 순서 보장.

```bash
SET stock:1 100

DECR stock:1   # → 99
DECR stock:1   # → 98
GET stock:1    # → 98
```

> [!note] 원자적(Atomic)이란?
> "중간에 끼어들 수 없음"
> DECR 하는 도중에 다른 요청이 끼어들지 못함. 순서 보장.

---

## 3. 분산락

**문제상황**: 서버 여러 대가 동시에 같은 재고를 줄이려고 함

**해결**: 먼저 락을 잡은 서버만 작업. 나머지는 대기.

```bash
# 서버A가 락 획득
SET lock:stock:1 "서버A" NX EX 10
# → OK (성공)

# 서버B가 락 시도
SET lock:stock:1 "서버B" NX EX 10
# → (nil) (실패! 서버A가 갖고 있음)

# 작업 완료 후 락 해제
DEL lock:stock:1
```

> [!tip] NX / EX 옵션
> - `NX` = Not eXists. 키가 없을 때만 저장 (이미 있으면 실패)
> - `EX 10` = 10초 후 자동 해제. 서버가 죽어도 락이 영원히 안 남음

---

## 4. 멱등성 키

**문제상황**: 유저가 결제 버튼을 두 번 클릭 → 주문이 두 번 생성됨

**해결**: 요청마다 고유 ID 발급 → Redis에 기록 → 같은 ID 두 번 오면 무시

```bash
# 첫 번째 요청
SETNX idempotency:uuid-001 "처리완료"
# → 1 (성공, 처음 요청)

# 두 번째 요청 (같은 UUID)
SETNX idempotency:uuid-001 "처리완료"
# → 0 (실패, 이미 있음 → 중복 무시)

GET idempotency:uuid-001
# → "처리완료" (원래 값 그대로)
```

> [!note] 멱등성(Idempotency)이란?
> 같은 요청을 여러 번 해도 결과가 동일함.
> 결제 두 번 눌러도 한 번만 결제되는 것.

---

## 5. EKS에서 어디에 사는가

```
EKS 클러스터 (내 서비스들)
└── 주문서비스 Pod
└── 재고서비스 Pod

AWS 관리형 (EKS 밖)
└── ElastiCache (Redis) ← 여기!
    └── redis.xxx.cache.amazonaws.com:6379
```

**왜 밖에 두냐?**
- Pod는 언제든 죽었다 살아남 → 데이터 날아감
- ElastiCache는 AWS가 백업/복구/패치 다 관리
- 비용: t3.micro 기준 월 ~$12 (MSK보다 훨씬 쌈)

**연결 방법**: 그냥 엔드포인트 주소를 환경변수로 넣으면 끝
```yaml
env:
  - name: REDIS_HOST
    value: "redis.xxx.cache.amazonaws.com"
  - name: REDIS_PORT
    value: "6379"
```

---

## 📊 패턴 요약

| 패턴 | 명령 | 사용 시나리오 |
|------|------|--------------|
| 캐싱 | `SET key value EX ttl` | 상품 정보, 세션 |
| 재고 카운터 | `DECR key` | 동시 재고 차감 |
| 분산락 | `SET key val NX EX ttl` | 중복 작업 방지 |
| 멱등성 | `SETNX key value` | 중복 요청 방지 |
