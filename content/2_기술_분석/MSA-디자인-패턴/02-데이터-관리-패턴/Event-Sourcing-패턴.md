---
title: Event Sourcing 패턴 - 이벤트로 상태 관리
tags:
  - MSA
  - event-sourcing
  - event-store
  - cqrs
  - audit-log
  - time-travel
aliases:
  - 이벤트 소싱
  - Event Store
date: 2026-01-05
category: MSA-디자인-패턴/02-데이터-관리-패턴
status: 완성
priority: 높음
difficulty: 고급
related:
  - "[[CQRS-패턴|CQRS 패턴]]"
  - "[[Saga-패턴|Saga 패턴]]"
prerequisites:
  - "[[CQRS-패턴|CQRS 패턴]]"
next_steps:
  - "[[../01-통신-패턴/Event-Driven-Architecture|Event Driven Architecture]]"
---

# 📜 Event Sourcing 패턴

> [!note] 패턴 개요
> Event Sourcing은 애플리케이션 상태를 **변경 이벤트의 시퀀스**로 저장하는 패턴입니다. 현재 상태만 저장하는 대신, 상태를 변경한 **모든 이벤트를 불변(immutable) 로그**로 기록합니다.

> [!tip] 중요도: ⭐⭐⭐⭐ 고급 패턴
> 감사 추적, 시간 여행, 복잡한 비즈니스 로직이 필요한 도메인에서 강력한 솔루션입니다.

---

## 📑 목차

- [[#1. 핵심 개념|핵심 개념]]
- [[#2. 문제와 해결|문제와 해결]]
- [[#3. Event Store|Event Store]]
- [[#4. 이벤트 재생|이벤트 재생]]
- [[#5. 실제 구현|실제 구현]]
- [[#6. 스냅샷|스냅샷]]
- [[#7. 장단점|장단점]]
- [[#8. 사용 시기|사용 시기]]
- [[#9. 실전 사례|실전 사례]]

---

## 1. 핵심 개념

### 🎯 전통적인 방식 vs Event Sourcing

**전통적인 방식 (State-Based):**
```sql
-- 현재 상태만 저장
UPDATE bank_accounts
SET balance = 1500
WHERE account_id = 'A123';

-- 과거 정보 손실!
-- 어떻게 1500원이 되었는지 알 수 없음
```

**Event Sourcing (Event-Based):**
```sql
-- 모든 변경을 이벤트로 저장
INSERT INTO events (aggregate_id, event_type, data, timestamp)
VALUES
  ('A123', 'AccountCreated', '{"initial_balance": 1000}', '2026-01-01'),
  ('A123', 'MoneyDeposited', '{"amount": 500}', '2026-01-02'),
  ('A123', 'MoneyWithdrawn', '{"amount": 300}', '2026-01-03'),
  ('A123', 'MoneyDeposited', '{"amount": 300}', '2026-01-04');

-- 현재 잔액 = 이벤트 재생 결과
-- 1000 + 500 - 300 + 300 = 1500
```

---

### 📊 이벤트 흐름

```
명령 (Command)          이벤트 (Event)          현재 상태 (State)
─────────────────────────────────────────────────────────────
CreateAccount(1000)  → AccountCreated       → balance: 1000
Deposit(500)         → MoneyDeposited       → balance: 1500
Withdraw(300)        → MoneyWithdrawn       → balance: 1200
Deposit(300)         → MoneyDeposited       → balance: 1500

         ↓
   Event Store에
   영구 저장
```

---

## 2. 문제와 해결

### 🚨 해결하려는 문제

#### 문제 1: 감사 추적 (Audit Trail) 부재

```sql
-- 전통적 방식
SELECT * FROM orders WHERE id = 123;
-- 결과: status = 'CANCELLED'

-- 질문: 누가? 언제? 왜 취소했는가?
-- → 답변 불가능!
```

#### 문제 2: 과거 상태 복원 불가

```
요구사항: "2주 전 주문 상태가 어땠는지 확인해주세요"
전통적 방식: 불가능 (현재 상태만 저장)
```

#### 문제 3: 비즈니스 인사이트 부족

```
질문: "고객들이 장바구니에 물건을 담았다가 삭제하는 패턴은?"
전통적 방식: 알 수 없음 (삭제된 데이터는 사라짐)
```

### ✅ Event Sourcing의 해결

#### 해결 1: 완벽한 감사 추적

```
Event Log:
T1 - OrderCreated (by: user123, reason: "new purchase")
T2 - OrderPaid (by: user123, payment_id: "pay456")
T3 - OrderShipped (by: admin789, tracking: "TR123")
T4 - OrderCancelled (by: user123, reason: "wrong address")

→ 모든 변경 이력 보존!
```

#### 해결 2: 시간 여행 (Time Travel)

```java
// 특정 시점의 상태 복원
Order orderAt2WeeksAgo = eventStore.replayUntil(
    orderId,
    Instant.now().minus(14, ChronoUnit.DAYS)
);
```

#### 해결 3: 비즈니스 분석

```sql
-- 장바구니 이탈 분석
SELECT COUNT(*)
FROM events
WHERE event_type = 'ItemAddedToCart'
AND aggregate_id NOT IN (
    SELECT aggregate_id
    FROM events
    WHERE event_type = 'OrderPlaced'
);
```

---

## 3. Event Store

### 📦 Event Store 구조

```sql
CREATE TABLE event_store (
    id BIGSERIAL PRIMARY KEY,
    aggregate_id UUID NOT NULL,         -- 집합체 ID (주문ID 등)
    aggregate_type VARCHAR(100),        -- 집합체 타입 (Order, Account)
    event_type VARCHAR(100) NOT NULL,   -- 이벤트 타입
    event_data JSONB NOT NULL,          -- 이벤트 데이터
    version INT NOT NULL,               -- 버전 (동시성 제어)
    timestamp TIMESTAMP NOT NULL,       -- 발생 시각
    user_id UUID,                       -- 누가 실행했는지
    metadata JSONB,                     -- 추가 메타데이터

    UNIQUE(aggregate_id, version)       -- 동일 버전 중복 방지
);

CREATE INDEX idx_aggregate ON event_store(aggregate_id);
CREATE INDEX idx_type ON event_store(event_type);
CREATE INDEX idx_timestamp ON event_store(timestamp);
```

### 📝 이벤트 예시

```json
{
  "id": 12345,
  "aggregate_id": "order-uuid-123",
  "aggregate_type": "Order",
  "event_type": "OrderCreatedEvent",
  "event_data": {
    "orderId": "order-uuid-123",
    "customerId": "cust-456",
    "items": [
      {"productId": "prod-789", "quantity": 2, "price": 50000}
    ],
    "totalAmount": 100000
  },
  "version": 1,
  "timestamp": "2026-01-05T10:30:00Z",
  "user_id": "user-123",
  "metadata": {
    "ipAddress": "192.168.1.100",
    "userAgent": "Mozilla/5.0..."
  }
}
```

---

## 4. 이벤트 재생

### 🔄 Aggregate 복원

```java
@Aggregate
public class OrderAggregate {

    @AggregateIdentifier
    private String orderId;
    private OrderStatus status;
    private List<OrderItem> items;
    private BigDecimal totalAmount;

    // 이벤트 재생으로 상태 복원
    public static OrderAggregate from(List<DomainEvent> events) {
        OrderAggregate order = new OrderAggregate();

        for (DomainEvent event : events) {
            order.apply(event);
        }

        return order;
    }

    private void apply(DomainEvent event) {
        if (event instanceof OrderCreatedEvent) {
            apply((OrderCreatedEvent) event);
        } else if (event instanceof OrderPaidEvent) {
            apply((OrderPaidEvent) event);
        } else if (event instanceof OrderCancelledEvent) {
            apply((OrderCancelledEvent) event);
        }
    }

    @EventSourcingHandler
    private void apply(OrderCreatedEvent event) {
        this.orderId = event.getOrderId();
        this.items = event.getItems();
        this.totalAmount = event.getTotalAmount();
        this.status = OrderStatus.CREATED;
    }

    @EventSourcingHandler
    private void apply(OrderPaidEvent event) {
        this.status = OrderStatus.PAID;
    }

    @EventSourcingHandler
    private void apply(OrderCancelledEvent event) {
        this.status = OrderStatus.CANCELLED;
    }
}
```

---

## 5. 실제 구현

### 💻 Axon Framework

```java
// Command
public class CreateOrderCommand {
    @TargetAggregateIdentifier
    private final String orderId;
    private final String customerId;
    private final List<OrderItem> items;
}

// Event
public class OrderCreatedEvent {
    private final String orderId;
    private final String customerId;
    private final List<OrderItem> items;
    private final Instant createdAt;
}

// Aggregate
@Aggregate
public class OrderAggregate {

    @AggregateIdentifier
    private String orderId;
    private OrderStatus status;

    protected OrderAggregate() {
        // Axon requires no-arg constructor
    }

    @CommandHandler
    public OrderAggregate(CreateOrderCommand command) {
        // Validation
        validateCommand(command);

        // Publish event (Event Store에 저장)
        apply(new OrderCreatedEvent(
            command.getOrderId(),
            command.getCustomerId(),
            command.getItems(),
            Instant.now()
        ));
    }

    @EventSourcingHandler
    public void on(OrderCreatedEvent event) {
        // 상태 변경 (이벤트 재생 시 실행됨)
        this.orderId = event.getOrderId();
        this.status = OrderStatus.CREATED;
    }

    @CommandHandler
    public void handle(CancelOrderCommand command) {
        if (this.status == OrderStatus.SHIPPED) {
            throw new IllegalStateException("Cannot cancel shipped order");
        }

        apply(new OrderCancelledEvent(
            command.getOrderId(),
            command.getReason(),
            Instant.now()
        ));
    }

    @EventSourcingHandler
    public void on(OrderCancelledEvent event) {
        this.status = OrderStatus.CANCELLED;
    }
}
```

---

### 🗄️ EventStore DB (전문 Event Store)

```bash
# EventStoreDB 실행
docker run --name esdb -d \
  -p 2113:2113 \
  -p 1113:1113 \
  eventstore/eventstore:latest \
  --insecure \
  --run-projections=All
```

```java
// EventStore 클라이언트
@Service
public class OrderEventStore {

    private final EventStoreDBClient client;

    public void save(String streamName, DomainEvent event) {
        EventData eventData = EventData.builderAsJson(
            event.getClass().getSimpleName(),
            event
        ).build();

        WriteResult result = client.appendToStream(
            streamName,
            eventData
        ).get();
    }

    public List<DomainEvent> getEvents(String streamName) {
        ReadResult result = client.readStream(streamName)
            .get();

        return result.getEvents()
            .stream()
            .map(this::deserialize)
            .collect(Collectors.toList());
    }
}
```

---

## 6. 스냅샷

### ⚡ 성능 최적화

**문제**: 이벤트가 많으면 재생 시간 증가

```
OrderAggregate 복원:
- 이벤트 10,000개
- 재생 시간: 5초
→ 너무 느림!
```

**해결**: 스냅샷 (Snapshot)

```
이벤트:  [1] [2] [3] ... [9998] [9999] [10000]
                        ↑
                   스냅샷 (9000번 이벤트 시점)

복원 시:
1. 스냅샷 로드 (9000번 상태)
2. 9001~10000번 이벤트만 재생
→ 재생 시간: 0.5초
```

### 📸 스냅샷 구현

```java
@Aggregate
public class OrderAggregate {

    private static final int SNAPSHOT_THRESHOLD = 100;

    @EventSourcingHandler
    public void on(OrderCreatedEvent event, @SequenceNumber Long sequenceNumber) {
        this.orderId = event.getOrderId();
        this.status = OrderStatus.CREATED;

        // 100개 이벤트마다 스냅샷 생성
        if (sequenceNumber % SNAPSHOT_THRESHOLD == 0) {
            createSnapshot();
        }
    }

    @SnapshotTriggerDefinition(snapshotter = "snapshotterBean")
    private void createSnapshot() {
        // Axon이 자동으로 현재 상태를 스냅샷으로 저장
    }
}
```

```sql
-- 스냅샷 테이블
CREATE TABLE aggregate_snapshots (
    aggregate_id UUID PRIMARY KEY,
    aggregate_type VARCHAR(100),
    sequence_number BIGINT,
    snapshot_data JSONB,
    timestamp TIMESTAMP
);
```

---

## 7. 장단점

### ✅ 장점

1. **완벽한 감사 추적**
   - 모든 변경 이력 보존
   - 규제 준수 용이

2. **시간 여행**
   - 과거 상태 복원 가능
   - 디버깅 용이

3. **이벤트 재사용**
   - 동일 이벤트로 다양한 뷰 생성
   - CQRS와 완벽한 조합

4. **비즈니스 인사이트**
   - 이벤트 분석으로 패턴 발견
   - 예측 모델링

### ❌ 단점

1. **복잡도**
   - 학습 곡선 steep
   - 이벤트 버저닝 필요

2. **저장 공간**
   - 모든 이벤트 저장 (공간 증가)

3. **쿼리 제한**
   - 현재 상태 조회 어려움
   - CQRS 필수

4. **이벤트 불변성**
   - 이벤트 수정 불가
   - 보상 이벤트 필요

---

## 8. 사용 시기

### ✅ 적합한 경우

1. **감사 요구사항**
   - 금융, 의료, 법률 도메인
   - 규제 준수

2. **복잡한 비즈니스 로직**
   - DDD 적용
   - 상태 전이 복잡

3. **분석 요구사항**
   - 사용자 행동 분석
   - 비즈니스 인사이트

### ❌ 부적합한 경우

1. **단순 CRUD**
   - 오버 엔지니어링

2. **실시간 조회**
   - 이벤트 재생 느림

3. **소규모 시스템**
   - 복잡도 대비 이점 없음

---

## 9. 실전 사례

### 🏢 GitHub

**사용 사례**: Git 커밋 로그

```
커밋 = 이벤트
모든 변경사항을 커밋으로 기록
→ 완벽한 Event Sourcing!
```

---

### 🏢 Stripe

**사용 사례**: 결제 이력

```
모든 결제 이벤트 기록:
- PaymentInitiated
- PaymentAuthorized
- PaymentCaptured
→ 감사 추적, 분쟁 해결
```

---

## 📚 참고 자료

### 🔗 관련 패턴

- [[CQRS-패턴|CQRS 패턴]]
- [[Saga-패턴|Saga 패턴]]

### 📖 추가 학습 자료

- [Event Sourcing - Martin Fowler](https://martinfowler.com/eaaDev/EventSourcing.html)
- [Versioning in an Event Sourced System](https://leanpub.com/esversioning)

---

**상위 문서**: [[_README|데이터 관리 패턴 폴더]]
**마지막 업데이트**: 2026-01-05

<br>
<div align="right" style="font-size: 0.8em; color: gray; opacity: 0.6;">
  Supported by Sonnet 4.5
</div>