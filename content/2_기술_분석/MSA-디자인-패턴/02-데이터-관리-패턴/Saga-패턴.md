---
title: Saga 패턴 - 분산 트랜잭션 관리
tags:
  - MSA
  - saga
  - distributed-transaction
  - choreography
  - orchestration
  - eventual-consistency
aliases:
  - Saga Pattern
  - 분산 트랜잭션
  - Long Running Transaction
date: 2026-01-05
category: MSA-디자인-패턴/02-데이터-관리-패턴
status: 완성
priority: 높음
difficulty: 고급
related:
  - "[[Event-Sourcing-패턴|Event Sourcing 패턴]]"
  - "[[CQRS-패턴|CQRS 패턴]]"
  - "[[Database-per-Service|Database per Service]]"
  - "[[../01-통신-패턴/Event-Driven-Architecture|Event Driven Architecture]]"
prerequisites:
  - "[[Database-per-Service|Database per Service]]"
  - "[[../01-통신-패턴/Event-Driven-Architecture|Event Driven Architecture]]"
next_steps:
  - "[[Event-Sourcing-패턴|Event Sourcing 패턴]]"
  - "[[CQRS-패턴|CQRS 패턴]]"
---

# 🔄 Saga 패턴

> [!note] 패턴 개요
> Saga는 마이크로서비스 환경에서 **여러 서비스에 걸친 분산 트랜잭션을 관리**하기 위한 패턴입니다. 각 서비스의 로컬 트랜잭션을 순차적으로 실행하고, 실패 시 **보상 트랜잭션(Compensating Transaction)**으로 롤백합니다.

> [!tip] 중요도: ⭐⭐⭐⭐ 핵심 패턴
> 마이크로서비스에서 ACID 트랜잭션은 불가능합니다. Saga는 **최종 일관성(Eventual Consistency)**을 보장하는 유일한 실용적 해결책입니다.

---

## 📑 목차

- [[#1. 핵심 개념|핵심 개념]]
- [[#2. 문제와 해결|문제와 해결]]
- [[#3. Saga 패턴 종류|Saga 패턴 종류]]
- [[#4. Choreography vs Orchestration|Choreography vs Orchestration]]
- [[#5. 보상 트랜잭션|보상 트랜잭션]]
- [[#6. 실제 구현|실제 구현]]
- [[#7. 격리 수준과 문제|격리 수준과 문제]]
- [[#8. 장단점|장단점]]
- [[#9. 사용 시기|사용 시기]]
- [[#10. 실전 사례|실전 사례]]

---

## 1. 핵심 개념

### 🎯 정의

Saga는 일련의 **로컬 트랜잭션**들로 구성되며, 각 트랜잭션은:
1. 데이터를 업데이트하고
2. 메시지/이벤트를 발행하여 다음 트랜잭션을 트리거

실패 시, 이미 완료된 트랜잭션을 **보상 트랜잭션**으로 되돌립니다.

### 📊 전통적인 ACID vs Saga

**모놀리스 (ACID 트랜잭션):**
```sql
BEGIN TRANSACTION;
  UPDATE orders SET status = 'CONFIRMED';
  UPDATE inventory SET quantity = quantity - 1;
  INSERT INTO payments VALUES (...);
COMMIT;  -- 모두 성공 또는 모두 실패
```

**마이크로서비스 (Saga):**
```
Order Service    → 주문 생성 (성공)
  ↓ Event
Inventory Service → 재고 감소 (성공)
  ↓ Event
Payment Service  → 결제 시도 (❌ 실패!)
  ↓ Compensation
Inventory Service → 재고 복구 (보상)
  ↓ Compensation
Order Service    → 주문 취소 (보상)
```

---

## 2. 문제와 해결

### 🚨 해결하려는 문제

#### 문제 1: 분산 환경에서 ACID 불가능

> [!example] E-Commerce 주문 시나리오
> **요구사항**: 주문 생성 시 원자적으로 처리
> 1. 주문 생성 (Order Service)
> 2. 재고 감소 (Inventory Service)
> 3. 결제 처리 (Payment Service)
> 4. 배송 예약 (Shipping Service)

**전통적인 2PC (Two-Phase Commit) 문제점:**
```
Coordinator
  ├─ Prepare → Order DB
  ├─ Prepare → Inventory DB
  ├─ Prepare → Payment DB
  └─ Prepare → Shipping DB

만약 Payment DB가 응답 없으면?
→ 모든 DB가 Lock 상태로 대기
→ 전체 시스템 성능 저하
```

**2PC의 한계:**
- 높은 지연 시간 (모든 DB가 준비 완료 대기)
- 단일 장애점 (Coordinator 다운 시 전체 중단)
- 확장성 부족 (참여자 수만큼 느려짐)
- NoSQL DB는 2PC 미지원

#### 문제 2: 부분 실패 처리

```
시나리오: 주문 → 재고 → 결제
09:00:00 - 주문 생성 ✅
09:00:01 - 재고 감소 ✅
09:00:02 - 결제 실패 ❌ (카드 한도 초과)

문제: 주문과 재고는 이미 변경됨
→ 어떻게 되돌릴 것인가?
```

#### 문제 3: 데이터 일관성

```
A 계좌 (Bank Service A): -100,000원
B 계좌 (Bank Service B): +100,000원

만약 A 차감 후 B 증가 실패?
→ 돈이 사라짐!
```

### ✅ Saga의 해결 방법

#### 해결 1: 로컬 트랜잭션 + 이벤트

```
각 서비스는 자체 DB만 사용 (로컬 트랜잭션)
→ 빠르고 확장 가능

서비스 간 통신은 이벤트/메시지
→ 느슨한 결합
```

#### 해결 2: 보상 트랜잭션

```
정방향: T1 → T2 → T3 → T4
역방향: C4 → C3 → C2 → C1

T3 실패 시:
C3 (T3 보상) → C2 (T2 보상) → C1 (T1 보상)
```

#### 해결 3: 최종 일관성

```
즉시 일관성 (ACID): ❌ 불가능
최종 일관성 (Saga): ✅ 가능

"일정 시간 후에는 모든 데이터가 일관된 상태"
```

---

## 3. Saga 패턴 종류

### 1. Choreography (코레오그래피) - 분산형

**정의**: 각 서비스가 **독립적으로** 이벤트를 발행하고 구독

```
┌─────────────┐  OrderCreated   ┌──────────────┐
│Order Service│ ──────────────> │Event Bus     │
└─────────────┘                 │(Kafka/RabbitMQ)
                                └──────────────┘
                                       │
                    ┌──────────────────┼──────────────────┐
                    ▼                  ▼                  ▼
            ┌──────────────┐   ┌──────────────┐  ┌──────────────┐
            │Inventory Svc │   │Payment Svc   │  │Shipping Svc  │
            └──────────────┘   └──────────────┘  └──────────────┘
                    │
                    │ InventoryReserved
                    ▼
            ┌──────────────┐
            │Event Bus     │
            └──────────────┘
```

**특징:**
- 중앙 조정자 없음
- 이벤트 기반 통신
- 각 서비스가 자율적으로 동작

**장점:**
- 느슨한 결합
- 확장성 높음
- 단일 장애점 없음

**단점:**
- 전체 흐름 파악 어려움
- 순환 의존성 위험
- 디버깅 복잡

---

### 2. Orchestration (오케스트레이션) - 중앙 집중형

**정의**: **Orchestrator**가 모든 트랜잭션을 중앙에서 관리

```
                ┌─────────────────────┐
                │   Saga Orchestrator │
                │   (Order Saga)      │
                └─────────────────────┘
                          │
         ┌────────────────┼────────────────┐
         ▼                ▼                ▼
  ┌────────────┐   ┌────────────┐  ┌────────────┐
  │Inventory   │   │Payment     │  │Shipping    │
  │Service     │   │Service     │  │Service     │
  └────────────┘   └────────────┘  └────────────┘
         │                │                │
         └────────────────┴────────────────┘
                          │
                     응답 (Success/Fail)
```

**특징:**
- 중앙 Orchestrator가 모든 단계 제어
- 명령(Command) 기반 통신
- 명시적인 워크플로우

**장점:**
- 명확한 흐름
- 쉬운 모니터링
- 복잡한 로직 처리 용이

**단점:**
- Orchestrator가 단일 장애점
- 결합도 높음
- Orchestrator 복잡도 증가

---

## 4. Choreography vs Orchestration

### 📊 상세 비교

| 구분 | Choreography | Orchestration |
|------|--------------|---------------|
| **제어 방식** | 분산 (각 서비스) | 중앙 (Orchestrator) |
| **통신 방식** | Event (발행/구독) | Command (요청/응답) |
| **결합도** | 낮음 (느슨한 결합) | 높음 (중앙 의존) |
| **복잡도** | 서비스 수 증가 시 ↑ | Orchestrator에 집중 |
| **모니터링** | 어려움 (분산 추적) | 쉬움 (중앙 관리) |
| **장애 대응** | 복잡 (분산 보상) | 명확 (중앙 제어) |
| **확장성** | 높음 | 중간 |
| **적합 사례** | 단순 워크플로우 | 복잡한 비즈니스 로직 |

---

### 🔍 실제 예시 비교

#### Choreography 예시 (주문 프로세스)

```java
// Order Service
@TransactionalEventListener
public class OrderService {

    public void createOrder(OrderRequest request) {
        // 1. 로컬 트랜잭션
        Order order = orderRepository.save(new Order(request));

        // 2. 이벤트 발행
        eventPublisher.publish(new OrderCreatedEvent(order));
    }
}

// Inventory Service (독립적으로 구독)
@EventListener
public class InventoryService {

    public void handleOrderCreated(OrderCreatedEvent event) {
        try {
            // 재고 차감
            inventoryRepository.decreaseStock(event.getProductId(), event.getQuantity());

            // 성공 이벤트 발행
            eventPublisher.publish(new InventoryReservedEvent(event.getOrderId()));
        } catch (InsufficientStockException e) {
            // 실패 이벤트 발행
            eventPublisher.publish(new InventoryReservationFailedEvent(event.getOrderId()));
        }
    }
}

// Payment Service (독립적으로 구독)
@EventListener
public class PaymentService {

    public void handleInventoryReserved(InventoryReservedEvent event) {
        try {
            // 결제 처리
            Payment payment = paymentGateway.charge(event.getAmount());

            eventPublisher.publish(new PaymentCompletedEvent(event.getOrderId()));
        } catch (PaymentFailedException e) {
            eventPublisher.publish(new PaymentFailedEvent(event.getOrderId()));
        }
    }
}

// Order Service (보상 트랜잭션)
@EventListener
public class OrderService {

    public void handlePaymentFailed(PaymentFailedEvent event) {
        // 주문 취소
        Order order = orderRepository.findById(event.getOrderId());
        order.cancel();
        orderRepository.save(order);

        // 재고 복구 이벤트 발행
        eventPublisher.publish(new OrderCancelledEvent(event.getOrderId()));
    }
}
```

---

#### Orchestration 예시 (주문 프로세스)

```java
// Order Saga Orchestrator
@Service
public class OrderSagaOrchestrator {

    @Autowired
    private InventoryServiceClient inventoryClient;

    @Autowired
    private PaymentServiceClient paymentClient;

    @Autowired
    private ShippingServiceClient shippingClient;

    public void executeOrderSaga(OrderRequest request) {
        SagaState state = new SagaState();

        try {
            // Step 1: 주문 생성
            Order order = createOrder(request);
            state.setOrderId(order.getId());

            // Step 2: 재고 예약
            InventoryResponse inventory = inventoryClient.reserve(
                order.getProductId(),
                order.getQuantity()
            );
            state.setInventoryReservationId(inventory.getId());

            // Step 3: 결제 처리
            PaymentResponse payment = paymentClient.charge(
                order.getCustomerId(),
                order.getTotalAmount()
            );
            state.setPaymentId(payment.getId());

            // Step 4: 배송 예약
            ShippingResponse shipping = shippingClient.schedule(
                order.getId(),
                order.getDeliveryAddress()
            );
            state.setShippingId(shipping.getId());

            // 모두 성공
            completeOrder(order);

        } catch (InventoryException e) {
            // 보상: 주문만 취소
            compensateOrder(state);

        } catch (PaymentException e) {
            // 보상: 재고 복구, 주문 취소
            compensateInventory(state);
            compensateOrder(state);

        } catch (ShippingException e) {
            // 보상: 결제 환불, 재고 복구, 주문 취소
            compensatePayment(state);
            compensateInventory(state);
            compensateOrder(state);
        }
    }

    private void compensateOrder(SagaState state) {
        orderService.cancel(state.getOrderId());
    }

    private void compensateInventory(SagaState state) {
        inventoryClient.release(state.getInventoryReservationId());
    }

    private void compensatePayment(SagaState state) {
        paymentClient.refund(state.getPaymentId());
    }
}
```

---

## 5. 보상 트랜잭션

### 💡 보상 트랜잭션 설계 원칙

#### 1. 멱등성 (Idempotency)

```java
// ❌ 멱등하지 않음
public void cancelOrder(String orderId) {
    Order order = orderRepository.findById(orderId);
    order.setQuantity(order.getQuantity() - 1);  // 중복 호출 시 문제!
}

// ✅ 멱등성 보장
public void cancelOrder(String orderId) {
    Order order = orderRepository.findById(orderId);
    if (order.getStatus() != OrderStatus.CANCELLED) {
        order.cancel();
        orderRepository.save(order);
    }
}
```

#### 2. 재시도 가능 (Retryable)

```java
@Retryable(maxAttempts = 3, backoff = @Backoff(delay = 1000))
public void refundPayment(String paymentId) {
    // 네트워크 오류 시 재시도
    paymentGateway.refund(paymentId);
}
```

#### 3. 시맨틱 롤백 vs 기술적 롤백

```java
// ❌ 기술적 롤백 (불가능 - 이미 커밋됨)
DELETE FROM orders WHERE id = ?;

// ✅ 시맨틱 롤백 (상태 변경)
UPDATE orders SET status = 'CANCELLED' WHERE id = ?;
```

---

### 📋 보상 트랜잭션 예시

| 정방향 트랜잭션 | 보상 트랜잭션 |
|----------------|--------------|
| 주문 생성 | 주문 취소 (status = CANCELLED) |
| 재고 감소 | 재고 복구 (quantity += N) |
| 결제 승인 | 결제 환불 |
| 포인트 차감 | 포인트 복구 |
| 이메일 발송 | 취소 이메일 발송 |
| 배송 예약 | 배송 취소 |

> [!warning] 보상 불가능한 작업
> - 이메일 발송 (되돌릴 수 없음 → 취소 이메일로 대체)
> - 외부 시스템 호출 (되돌리기 어려움 → 로그 기록)
> - 시간 기반 작업 (시간은 되돌릴 수 없음)

---

## 6. 실제 구현

### 💻 Netflix Conductor (Orchestration)

**의존성:**
```xml
<dependency>
    <groupId>com.netflix.conductor</groupId>
    <artifactId>conductor-client</artifactId>
    <version>3.13.0</version>
</dependency>
```

**워크플로우 정의:**
```json
{
  "name": "order_saga",
  "description": "주문 처리 Saga",
  "version": 1,
  "tasks": [
    {
      "name": "create_order",
      "taskReferenceName": "create_order_ref",
      "type": "SIMPLE"
    },
    {
      "name": "reserve_inventory",
      "taskReferenceName": "reserve_inventory_ref",
      "type": "SIMPLE"
    },
    {
      "name": "process_payment",
      "taskReferenceName": "process_payment_ref",
      "type": "SIMPLE"
    },
    {
      "name": "schedule_shipping",
      "taskReferenceName": "schedule_shipping_ref",
      "type": "SIMPLE"
    }
  ],
  "failureWorkflow": "order_saga_compensation",
  "schemaVersion": 2
}
```

**보상 워크플로우:**
```json
{
  "name": "order_saga_compensation",
  "description": "주문 처리 롤백",
  "tasks": [
    {
      "name": "refund_payment",
      "taskReferenceName": "refund_payment_ref",
      "type": "SIMPLE"
    },
    {
      "name": "release_inventory",
      "taskReferenceName": "release_inventory_ref",
      "type": "SIMPLE"
    },
    {
      "name": "cancel_order",
      "taskReferenceName": "cancel_order_ref",
      "type": "SIMPLE"
    }
  ]
}
```

---

### 🚀 Axon Framework (Event Sourcing + Saga)

**의존성:**
```xml
<dependency>
    <groupId>org.axonframework</groupId>
    <artifactId>axon-spring-boot-starter</artifactId>
    <version>4.9.0</version>
</dependency>
```

**Saga 정의:**
```java
@Saga
public class OrderSaga {

    @Autowired
    private transient CommandGateway commandGateway;

    private String orderId;
    private String inventoryReservationId;
    private String paymentId;

    @StartSaga
    @SagaEventHandler(associationProperty = "orderId")
    public void handle(OrderCreatedEvent event) {
        this.orderId = event.getOrderId();

        // 재고 예약 명령 전송
        ReserveInventoryCommand command = new ReserveInventoryCommand(
            UUID.randomUUID().toString(),
            event.getProductId(),
            event.getQuantity()
        );

        commandGateway.send(command);
    }

    @SagaEventHandler(associationProperty = "orderId")
    public void handle(InventoryReservedEvent event) {
        this.inventoryReservationId = event.getReservationId();

        // 결제 처리 명령 전송
        ProcessPaymentCommand command = new ProcessPaymentCommand(
            UUID.randomUUID().toString(),
            event.getOrderId(),
            event.getTotalAmount()
        );

        commandGateway.send(command);
    }

    @SagaEventHandler(associationProperty = "orderId")
    public void handle(PaymentCompletedEvent event) {
        this.paymentId = event.getPaymentId();

        // 주문 완료 명령 전송
        CompleteOrderCommand command = new CompleteOrderCommand(orderId);
        commandGateway.send(command);
    }

    @SagaEventHandler(associationProperty = "orderId")
    @EndSaga
    public void handle(OrderCompletedEvent event) {
        // Saga 종료
        log.info("Order {} completed successfully", event.getOrderId());
    }

    // ─────────────────────────────────
    // 보상 트랜잭션
    // ─────────────────────────────────

    @SagaEventHandler(associationProperty = "orderId")
    public void handle(PaymentFailedEvent event) {
        // 재고 복구
        ReleaseInventoryCommand command = new ReleaseInventoryCommand(
            inventoryReservationId
        );
        commandGateway.send(command);
    }

    @SagaEventHandler(associationProperty = "orderId")
    public void handle(InventoryReleasedEvent event) {
        // 주문 취소
        CancelOrderCommand command = new CancelOrderCommand(orderId);
        commandGateway.send(command);
    }

    @SagaEventHandler(associationProperty = "orderId")
    @EndSaga
    public void handle(OrderCancelledEvent event) {
        // Saga 종료 (실패)
        log.warn("Order {} cancelled due to failure", event.getOrderId());
    }
}
```

---

### 📦 Camunda (BPMN 기반 Orchestration)

**워크플로우 정의 (BPMN):**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<bpmn:definitions xmlns:bpmn="http://www.omg.org/spec/BPMN/20100524/MODEL">
  <bpmn:process id="OrderSagaProcess" name="Order Saga" isExecutable="true">

    <bpmn:startEvent id="StartEvent" name="Order Created" />

    <bpmn:serviceTask id="ReserveInventory" name="Reserve Inventory"
                      camunda:delegateExpression="#{reserveInventoryDelegate}" />

    <bpmn:serviceTask id="ProcessPayment" name="Process Payment"
                      camunda:delegateExpression="#{processPaymentDelegate}" />

    <bpmn:serviceTask id="ScheduleShipping" name="Schedule Shipping"
                      camunda:delegateExpression="#{scheduleShippingDelegate}" />

    <bpmn:endEvent id="EndEvent" name="Order Completed" />

    <!-- 보상 경로 -->
    <bpmn:boundaryEvent id="PaymentError" attachedToRef="ProcessPayment">
      <bpmn:errorEventDefinition errorRef="PaymentError" />
    </bpmn:boundaryEvent>

    <bpmn:serviceTask id="RefundPayment" name="Refund Payment"
                      camunda:delegateExpression="#{refundPaymentDelegate}" />

    <bpmn:serviceTask id="ReleaseInventory" name="Release Inventory"
                      camunda:delegateExpression="#{releaseInventoryDelegate}" />

    <bpmn:serviceTask id="CancelOrder" name="Cancel Order"
                      camunda:delegateExpression="#{cancelOrderDelegate}" />

  </bpmn:process>
</bpmn:definitions>
```

**Java Delegate:**
```java
@Component("processPaymentDelegate")
public class ProcessPaymentDelegate implements JavaDelegate {

    @Autowired
    private PaymentService paymentService;

    @Override
    public void execute(DelegateExecution execution) throws Exception {
        String orderId = (String) execution.getVariable("orderId");
        BigDecimal amount = (BigDecimal) execution.getVariable("amount");

        try {
            Payment payment = paymentService.charge(orderId, amount);
            execution.setVariable("paymentId", payment.getId());

        } catch (PaymentException e) {
            throw new BpmnError("PaymentError", "Payment failed: " + e.getMessage());
        }
    }
}
```

---

## 7. 격리 수준과 문제

### ⚠️ Saga의 격리 문제

Saga는 ACID의 **격리(Isolation)**를 보장하지 못합니다.

#### 문제 1: Dirty Read (더티 리드)

```
시간   | Saga A (주문 생성)      | Saga B (재고 조회)
─────────────────────────────────────────────────────────
T1     | 재고 100 → 99 감소     |
T2     |                        | 재고 조회: 99 (✅)
T3     | 결제 실패, 보상 시작    |
T4     | 재고 99 → 100 복구     |
T5     |                        | 재고 99로 알고 있음 (❌ 잘못된 데이터)
```

#### 문제 2: Lost Update (업데이트 손실)

```
시간   | Saga A               | Saga B
─────────────────────────────────────────────
T1     | 재고 100 읽기         |
T2     |                      | 재고 100 읽기
T3     | 재고 99로 업데이트    |
T4     |                      | 재고 98로 업데이트 (❌ A의 변경 손실)
```

---

### 🛡️ 대응 전략

#### 1. Semantic Lock (시맨틱 락)

```java
public class Inventory {
    private int quantity;
    private int reserved;  // 예약된 수량

    public void reserve(int amount) {
        if (quantity - reserved < amount) {
            throw new InsufficientStockException();
        }
        reserved += amount;  // 즉시 예약 (다른 Saga가 못 봄)
    }

    public void confirmReservation(int amount) {
        reserved -= amount;
        quantity -= amount;  // 최종 확정
    }

    public void cancelReservation(int amount) {
        reserved -= amount;  // 예약 취소
    }
}
```

#### 2. Commutative Update (교환 가능한 업데이트)

```java
// ❌ 비교환적 업데이트 (순서 중요)
quantity = 100;
quantity = 50;  // 최종 50

// ✅ 교환 가능한 업데이트 (순서 무관)
quantity = 100;
quantity -= 10;  // 90
quantity -= 5;   // 85
// 순서가 바뀌어도 결과 동일
```

#### 3. Pessimistic View (비관적 뷰)

```java
// 진행 중인 Saga 데이터는 숨김
public List<Product> getAvailableProducts() {
    return productRepository.findAll()
        .stream()
        .filter(p -> p.getStatus() == ProductStatus.AVAILABLE)  // PENDING 제외
        .collect(Collectors.toList());
}
```

#### 4. Reread Value (재읽기)

```java
public void completePayment(String orderId) {
    // 최신 데이터 재조회
    Order order = orderRepository.findById(orderId);

    if (order.getStatus() == OrderStatus.CANCELLED) {
        // 이미 취소됨, 결제 중단
        return;
    }

    paymentGateway.charge(order.getTotalAmount());
}
```

#### 5. Version File (버전 파일)

```java
@Entity
public class Order {
    @Id
    private String id;

    @Version  // Optimistic Locking
    private Long version;

    private OrderStatus status;
}

// 업데이트 시 버전 체크
public void updateOrder(Order order) {
    int updated = orderRepository.update(order);
    if (updated == 0) {
        throw new OptimisticLockException("Order was modified by another transaction");
    }
}
```

---

## 8. 장단점

### ✅ 장점

1. **확장성**
   - 서비스별 독립적인 DB
   - 2PC보다 훨씬 빠름

2. **가용성**
   - 단일 장애점 없음 (Choreography)
   - 부분 실패 허용

3. **느슨한 결합**
   - 서비스 독립성 유지
   - 기술 스택 자유

4. **최종 일관성**
   - 실용적인 일관성 보장
   - 비즈니스 요구사항 충족

### ❌ 단점

1. **복잡도**
   - 보상 로직 구현 필요
   - 디버깅 어려움

2. **격리 부족**
   - Dirty Read, Lost Update 가능
   - 추가 대응 전략 필요

3. **모니터링 어려움**
   - 분산 추적 필요
   - 상태 파악 복잡

4. **테스트 어려움**
   - 다양한 실패 시나리오
   - 통합 테스트 복잡

---

## 9. 사용 시기

### ✅ 적합한 경우

1. **마이크로서비스 환경**
   - 여러 서비스에 걸친 트랜잭션
   - Database per Service 패턴 사용

2. **긴 트랜잭션**
   - 외부 API 호출 포함
   - 사람의 개입 필요 (승인 프로세스)

3. **최종 일관성 허용**
   - 즉시 일관성 불필요
   - 비즈니스적으로 허용 가능

### ❌ 부적합한 경우

1. **강한 일관성 필요**
   - 금융 거래 (실시간 정산)
   - 재고 정확성이 critical

2. **단일 DB**
   - 모놀리스 애플리케이션
   - ACID 트랜잭션 가능

3. **보상 불가능**
   - 되돌릴 수 없는 작업
   - 외부 시스템 의존

---

## 10. 실전 사례

### 🏢 Uber

**사용 사례**: 차량 배차 프로세스

```
1. 승객 요청
2. 드라이버 매칭
3. 드라이버 확인
4. 요금 계산
5. 결제 처리

실패 시:
- 드라이버 매칭 취소
- 요청 재할당
- 결제 환불
```

**구현**: Cadence (Uber 자체 개발)

---

### 🏢 Amazon

**사용 사례**: 주문 처리

```
Order → Inventory → Payment → Shipping

Payment 실패 시:
→ Inventory 복구
→ Order 취소
→ 고객 알림
```

**효과**:
- 99.99% 주문 성공률
- 평균 보상 시간 2초

---

## 📚 참고 자료

### 🔗 관련 패턴

- [[Event-Sourcing-패턴|Event Sourcing]] - Saga와 함께 사용
- [[CQRS-패턴|CQRS]] - 읽기/쓰기 분리
- [[../01-통신-패턴/Event-Driven-Architecture|Event Driven Architecture]]

### 📖 추가 학습 자료

- [Microservices Patterns - Chris Richardson](https://microservices.io/patterns/data/saga.html)
- [Saga Pattern - Microsoft](https://docs.microsoft.com/en-us/azure/architecture/reference-architectures/saga/saga)
- [Designing Data-Intensive Applications - Martin Kleppmann](https://dataintensive.net/)

---

**상위 문서**: [[_README|데이터 관리 패턴 폴더]]
**마지막 업데이트**: 2026-01-05
**다음 학습**: [[Event-Sourcing-패턴|Event Sourcing 패턴]]

<br>
<div align="right" style="font-size: 0.8em; color: gray; opacity: 0.6;">
  Supported by Sonnet 4.5
</div>