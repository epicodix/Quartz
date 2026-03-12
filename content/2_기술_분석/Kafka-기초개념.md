---
title: Kafka 기초개념 - 타임딜로 이해하는 이벤트 기반 메시징
tags:
  - kafka
  - message-queue
  - event-driven
  - msa
  - async
date: 2026-02-19
category: 2_기술_분석
status: 완성
priority: 높음
---

# 🎯 Kafka 기초개념

> [!note] 한 줄 정의
> **"순서 보장되는 메시지 우체국"**
> 서비스들이 서로 직접 호출하지 않고, Kafka를 통해 메시지를 주고받음.

---

## 📑 목차
- [[#1. 왜 필요한가|왜 필요한가]]
- [[#2. 핵심 용어 3개|핵심 용어]]
- [[#3. 타임딜 주문 흐름|타임딜 흐름]]
- [[#4. EKS에서 어디에 사는가|EKS에서 위치]]
- [[#5. 직접 찍먹 (K3d)|찍먹]]
- [[#6. 이커머스에서 Kafka의 함정|이커머스 함정]]

---

## 1. 왜 필요한가

**Kafka 없을 때 (직접 호출)**

```
주문서비스 → 재고서비스 호출
           → 재고서비스 죽음
           → 주문도 실패 💥
```

**Kafka 있을 때 (비동기)**

```
주문서비스 → Kafka에 "주문됨" 메시지 저장 → 유저에게 즉시 응답 ✅
재고서비스  → 나중에 살아나면 Kafka에서 읽어서 처리
```

> [!tip] 핵심 이점
> - 서비스 간 **의존성 제거** (재고서비스 죽어도 주문 가능)
> - **비동기** 처리 (유저는 기다리지 않음)
> - 메시지가 **보존**됨 (재고서비스가 살아나면 밀린 것 처리)

---

## 2. 핵심 용어 3개

```
토픽(Topic)     = 우체통 분류함
                  order-events, payment-events, stock-events...

프로듀서(Producer) = 편지 쓰는 사람
                     메시지를 Kafka에 넣는 서비스

컨슈머(Consumer)   = 편지 받는 사람
                     Kafka에서 메시지를 읽어서 처리하는 서비스
```

**시각화**

```
주문서비스 (Producer)
    │
    │  {"eventType":"ORDER_CREATED", "orderId":"001"}
    ▼
[order-events 토픽]  ← Kafka
    │
    ├──→ 재고서비스 (Consumer)  → 재고 차감
    ├──→ 결제서비스 (Consumer)  → 결제 처리
    └──→ 알림서비스 (Consumer)  → 카카오톡 발송
```

> [!note] 컨슈머 그룹
> 같은 토픽을 여러 서비스가 **독립적으로** 읽을 수 있음.
> 재고서비스가 읽었다고 결제서비스 못 읽는 게 아님.

---

## 3. 타임딜 주문 흐름

```
1. 유저가 구매 클릭

2. 주문서비스
   → Kafka에 메시지 발행
     {"eventType":"ORDER_CREATED","orderId":"order-001","userId":"user-123"}
   → 유저에게 즉시 응답 ("주문 접수됨")

3. 재고서비스 (Kafka에서 읽음)
   → Redis DECR stock:1
   → Kafka에 메시지 발행
     {"eventType":"STOCK_RESERVED","orderId":"order-001"}

4. 결제서비스 (Kafka에서 읽음)
   → 결제 처리
   → Kafka에 메시지 발행
     {"eventType":"PAYMENT_COMPLETED","orderId":"order-001"}

5. 알림서비스 (Kafka에서 읽음)
   → 카카오톡 발송
```

> [!example] 실제 메시지 예시
> ```json
> {"eventType":"ORDER_CREATED","orderId":"order-001","userId":"user-123","itemId":1,"quantity":1}
> {"eventType":"STOCK_RESERVED","orderId":"order-001","stockRemaining":49}
> {"eventType":"PAYMENT_COMPLETED","orderId":"order-001","amount":25000}
> ```

---

## 4. EKS에서 어디에 사는가

**MSK (AWS 관리형 Kafka)**
- AWS Console에서 생성
- EKS 밖에 위치
- 비용: 최소 3 브로커 × $0.21/시간 = **월 ~$450** 💸

**EKS 안 StatefulSet**
- 팀프로젝트 수준에서 권장
- 노드 비용만 추가 (이미 내고 있는 EC2)
- 데이터 영속성은 PVC로 해결

```
팀프로젝트 현실 아키텍처

EKS 안
├── 주문/재고/결제/알림 서비스 (Deployment)
└── Kafka (StatefulSet + PVC)    ← 비싸서 안에서

EKS 밖
├── ElastiCache (Redis)           ← 쌈, 편함
└── RDS (PostgreSQL)              ← 데이터는 AWS한테
```

---

## 5. 직접 찍먹 (K3d)

```bash
# 토픽 생성
kubectl exec -it kafka-client -- kafka-topics.sh \
  --bootstrap-server kafka:9092 \
  --create --topic order-events \
  --partitions 3 --replication-factor 1

# 터미널 1: Consumer (받기)
kubectl exec -it kafka-client -- kafka-console-consumer.sh \
  --bootstrap-server kafka:9092 \
  --topic order-events --from-beginning

# 터미널 2: Producer (보내기)
kubectl exec -it kafka-client -- kafka-console-producer.sh \
  --bootstrap-server kafka:9092 \
  --topic order-events
# → 입력하면 터미널 1에 실시간으로 나타남
```

> [!tip] K3d 찍먹 시 이미지
> Bitnami 이미지는 2025년 8월부터 유료화됨.
> `apache/kafka:3.9.0` 공식 이미지 사용 권장.

---

## 6. 이커머스에서 Kafka의 함정

> [!danger] 핵심 착각
> "Kafka 있으면 재고서비스 죽어도 주문 가능" → 이커머스에서 이게 독이다.

### 왜 함정인가

```
Kafka 문서가 보여주는 장점
  재고서비스 죽어도 주문 접수 ✅
  나중에 살아나면 밀린 것 처리 ✅

이커머스에서 실제로 일어나는 일
  주문 접수됨 → 유저한테 응답
       ↓
  재고서비스 죽음
       ↓
  나중에 살아나서 처리
       ↓
  근데 그 사이에 재고가 0 됨
       ↓
  재고 없는데 주문 완료 💥
```

### Kafka 써도 되는 곳 vs 안 되는 곳

| 구간 | Kafka | 이유 |
|------|-------|------|
| 주문 생성 | ❌ | 실패하면 안 됨 |
| 재고 차감 | ❌ | 즉시 일관성 필요 |
| 결제 처리 | ❌ | 돈 관련 |
| 환불 | ❌ | 돈 관련 |
| 배송 알림 | ✅ | 늦어도 됨 |
| 이메일/푸시 | ✅ | 실패해도 재시도 가능 |
| 통계 집계 | ✅ | Eventually OK |
| 정산 배치 | ✅ | 배치로 처리 |

### 타임딜 프로젝트에서 실제로 발생한 허점

```
타임딜 구현 (Go + Kafka + Saga)

ORDER_CREATED  → Kafka 발행
STOCK_RESERVED → Kafka 발행   ← 재고 차감을 비동기로 처리
PAYMENT_COMPLETED → Kafka 발행

문제
  Outbox 없음 → Kafka produce 실패 시 이벤트 유실
  Saga 상태 인메모리 → 서버 재시작 시 어디까지 했는지 모름
  보상 트랜잭션 실패 → 재고 롤백도 실패 가능, 아무도 모름
```

> [!note] 부하테스트로는 안 잡힌다
> k6로 1만 TPS 밀어도 정상.
> 장애는 **타이밍**에서 난다.
> 네트워크 순단, 서버 재시작, 결제 버튼 두 번 클릭...
> 이건 부하테스트가 아닌 **실제 운영**에서만 터진다.

### 이커머스 실무 정석

```
재고/주문/결제  →  @Transactional 단일 트랜잭션 (즉시 일관성)
배송/알림/정산  →  Kafka (Eventually Consistent 허용)
```

> [[Go-vs-Spring-이커머스-비교]] 참고

---

## 📊 요약

| 구분 | 내용 |
|------|------|
| 역할 | 서비스 간 비동기 메시지 전달 |
| 핵심 개념 | 토픽 / 프로듀서 / 컨슈머 |
| 장점 | 서비스 독립성, 장애 격리, 메시지 보존 |
| 운영 위치 | 팀프로젝트는 EKS 안 StatefulSet |
| AWS 관리형 | MSK (비쌈, 월 ~$450+) |
