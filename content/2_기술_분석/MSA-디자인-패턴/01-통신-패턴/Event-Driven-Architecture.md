---
title: Event-Driven Architecture (EDA) - 이벤트 기반 아키텍처
tags:
  - MSA
  - event-driven
  - async
  - kafka
  - messaging
aliases:
  - EDA
  - 이벤트 기반 아키텍처
date: 2026-01-02
category: MSA-디자인-패턴/01-통신-패턴
status: 완성
priority: 높음
difficulty: 중급
related:
  - "[[../02-데이터-관리-패턴/Event-Sourcing|Event Sourcing]]"
  - "[[../02-데이터-관리-패턴/CQRS-패턴|CQRS]]"
  - "[[../02-데이터-관리-패턴/Saga-패턴|Saga]]"
prerequisites:
  - "[[../02-데이터-관리-패턴/Database-per-Service|Database per Service]]"
next_steps:
  - "[[../02-데이터-관리-패턴/Event-Sourcing|Event Sourcing]]"
  - "[[../02-데이터-관리-패턴/Saga-패턴|Saga]]"
---

# 🎪 Event-Driven Architecture (EDA)

> [!note] 패턴 개요
> Event-Driven Architecture는 동기 호출 대신 **이벤트를 통해 마이크로서비스가 통신**하는 설계 방식으로, 서비스를 완전히 분리(decouple)하여 높은 확장성과 복원력을 제공합니다.

> [!tip] 중요도: ⭐⭐⭐ 2026년 대세
> 2026년 현재, Event-Driven Architecture는 확장성과 복원력이 중요한 대부분의 MSA에서 표준으로 자리 잡았습니다.

---

## 📑 목차

- [[#1. 핵심 개념|핵심 개념]]
- [[#2. 문제와 해결|문제와 해결]]
- [[#3. 아키텍처 구조|아키텍처 구조]]
- [[#4. 핵심 구성 요소|핵심 구성 요소]]
- [[#5. 통신 방식 비교|통신 방식 비교]]
- [[#6. 실제 구현|실제 구현]]
- [[#7. 장단점|장단점]]
- [[#8. 사용 시기|사용 시기]]
- [[#9. 2026년 표준 스택|2026년 표준 스택]]
- [[#10. 실전 사례|실전 사례]]

---

## 1. 핵심 개념

### 🎯 정의

Event-Driven Architecture는 **이벤트의 생성, 감지, 소비, 반응**을 중심으로 설계된 아키텍처 패턴입니다.

**핵심 특징:**
- **비동기 통신**: 서비스가 이벤트를 발행하고 응답을 기다리지 않음
- **느슨한 결합**: 서비스 간 직접적인 의존성 없음
- **이벤트 중심**: 도메인 이벤트가 시스템의 중심

### 📊 기본 플로우

```
Order Service (Producer)
    ↓ 주문 생성
[OrderPlaced Event] → Message Broker (Kafka)
                           ↓
         ┌─────────────────┼─────────────────┐
         ↓                 ↓                 ↓
    Inventory         Payment          Notification
     Service          Service            Service
   (Consumer)       (Consumer)         (Consumer)
```

**특징:**
- Order Service는 다운스트림 서비스를 몰라도 됨
- 새로운 Consumer 추가 시 Order Service 수정 불필요
- 한 서비스의 장애가 다른 서비스에 영향 없음

---

## 2. 문제와 해결

### 🚨 해결하려는 문제

#### 문제 1: 동기 호출의 강한 결합

**전통적인 REST API 방식:**
```
Order Service
    ↓ REST API Call
Payment Service (응답 대기... 블로킹)
    ↓ REST API Call
Inventory Service (응답 대기... 블로킹)
    ↓
응답 → Payment → Order
```

**문제점:**
- Payment Service가 다운되면 Order Service도 실패
- 지연시간 누적 (Order → Payment → Inventory)
- 서비스 간 강한 의존성

#### 문제 2: 확장성 제약

- 동기 호출은 요청-응답 대기로 Thread 블로킹
- 높은 트래픽 시 병목 발생

#### 문제 3: 장애 전파

- 한 서비스의 장애가 연쇄적으로 전파 (Cascading Failure)

### ✅ Event-Driven의 해결 방법

#### 해결 1: 느슨한 결합

```
Order Service → [Event] → Kafka
                            ↓
                      (비동기 처리)
                            ↓
                   Payment, Inventory 독립 처리
```

- Order Service는 이벤트 발행 후 즉시 응답
- 다운스트림 서비스의 상태와 무관

#### 해결 2: 높은 확장성

- 이벤트는 Queue에 저장되어 Consumer가 자신의 속도로 처리
- Consumer를 수평 확장하여 처리량 증가

#### 해결 3: 장애 격리

- Payment Service 장애 시 Order Service는 정상 동작
- 이벤트는 Kafka에 보관되어 복구 후 처리

---

## 3. 아키텍처 구조

### 📐 전체 아키텍처

```
┌─────────────────────────────────────────────────┐
│                Event Producers                  │
│   (Order Service, User Service, etc.)           │
└─────────────────┬───────────────────────────────┘
                  │ Publish Events
                  ▼
┌─────────────────────────────────────────────────┐
│           Event Bus / Message Broker            │
│                  (Apache Kafka)                 │
│                                                 │
│  Topics:                                        │
│  - orders.created                               │
│  - payments.processed                           │
│  - inventory.updated                            │
└─────────────────┬───────────────────────────────┘
                  │ Subscribe to Events
                  ▼
┌─────────────────────────────────────────────────┐
│                Event Consumers                  │
│  (Inventory, Payment, Notification, etc.)       │
└─────────────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────┐
│              Event Store (선택)                  │
│        (모든 이벤트 영구 저장)                    │
└─────────────────────────────────────────────────┘
```

### 🔄 이벤트 플로우 예시 (전자상거래)

```
1. 사용자가 주문 생성
   Order Service → [OrderCreated Event]
                     {
                       orderId: "12345",
                       userId: "user-1",
                       items: [...],
                       totalAmount: 50000
                     }

2. 이벤트가 Kafka Topic으로 발행
   Topic: "orders.created"

3. 다양한 Consumer가 이벤트 소비

   Inventory Service:
   - 재고 차감
   - [InventoryReserved Event] 발행

   Payment Service:
   - 결제 처리
   - [PaymentProcessed Event] 발행

   Notification Service:
   - 주문 확인 이메일 발송

   Analytics Service:
   - 주문 데이터 수집
   - 실시간 대시보드 업데이트
```

---

## 4. 핵심 구성 요소

### 1️⃣ Event Producer (이벤트 생산자)

**역할**: 도메인 이벤트를 생성하고 발행

**예시 코드 (Spring Boot + Kafka)**:
```java
@Service
public class OrderService {

    @Autowired
    private KafkaTemplate<String, OrderCreatedEvent> kafkaTemplate;

    public Order createOrder(CreateOrderRequest request) {
        // 1. 주문 생성 (비즈니스 로직)
        Order order = Order.create(request);
        orderRepository.save(order);

        // 2. 이벤트 발행
        OrderCreatedEvent event = OrderCreatedEvent.builder()
            .orderId(order.getId())
            .userId(request.getUserId())
            .items(order.getItems())
            .totalAmount(order.getTotalAmount())
            .timestamp(Instant.now())
            .build();

        kafkaTemplate.send("orders.created", event);

        // 3. 즉시 응답 (비동기)
        return order;
    }
}
```

**중요 원칙:**
- 이벤트는 **과거 시제** (`OrderCreated`, `PaymentProcessed`)
- 이벤트는 **불변** (Immutable)
- 이벤트 발행은 **멱등성** 보장 필요 (중복 발행 시에도 안전)

---

### 2️⃣ Event Bus (이벤트 버스)

**역할**: 이벤트 전송을 위한 중앙 통신 채널

**주요 제품:**

| 제품 | 특징 | 사용 사례 |
|------|------|----------|
| **Apache Kafka** | 고처리량, 영구 저장, 순서 보장 | 대규모 이벤트 스트리밍, Event Sourcing |
| **RabbitMQ** | 유연한 라우팅, AMQP 표준 | 복잡한 메시지 라우팅 |
| **AWS EventBridge** | 서버리스, AWS 통합 | AWS 환경, 간단한 이벤트 처리 |
| **Azure Event Grid** | 서버리스, Azure 통합 | Azure 환경 |
| **NATS** | 경량, 낮은 지연시간 | IoT, 실시간 메시징 |

**Kafka Topic 설계 예시:**
```
orders.created          # 주문 생성 이벤트
orders.cancelled        # 주문 취소 이벤트
payments.processed      # 결제 완료 이벤트
payments.failed         # 결제 실패 이벤트
inventory.reserved      # 재고 예약 이벤트
inventory.released      # 재고 해제 이벤트
```

---

### 3️⃣ Event Consumer (이벤트 소비자)

**역할**: 이벤트를 수신하고 비즈니스 로직 처리

**예시 코드 (Spring Boot + Kafka)**:
```java
@Service
public class InventoryEventConsumer {

    @Autowired
    private InventoryService inventoryService;

    @KafkaListener(
        topics = "orders.created",
        groupId = "inventory-service-group"
    )
    public void handleOrderCreated(OrderCreatedEvent event) {
        log.info("Received OrderCreated event: {}", event.getOrderId());

        try {
            // 재고 차감
            inventoryService.reserveItems(event.getItems());

            // 성공 이벤트 발행
            publishInventoryReservedEvent(event.getOrderId());

        } catch (OutOfStockException e) {
            // 실패 이벤트 발행 (보상 트랜잭션)
            publishInventoryFailedEvent(event.getOrderId(), e.getMessage());
        }
    }
}
```

**Consumer Group:**
- 여러 Consumer 인스턴스가 같은 Group에 속함
- Kafka가 메시지를 인스턴스 간 분산 (부하 분산)
- 각 메시지는 Group 내 하나의 인스턴스만 처리

```
Kafka Topic: orders.created
    ↓
Consumer Group: inventory-service-group
    ├─→ Instance 1 (Partition 0, 1)
    ├─→ Instance 2 (Partition 2, 3)
    └─→ Instance 3 (Partition 4, 5)
```

---

### 4️⃣ Event Store (이벤트 저장소)

**역할**: 이벤트를 영구 저장하여 시스템 이력의 신뢰할 수 있는 소스 제공

**사용 사례:**
- Event Sourcing 패턴과 함께 사용
- 감사 추적 (Audit Trail)
- 시스템 상태 재구축

**구현 옵션:**
- **Kafka** (retention 무제한 설정)
- **EventStore DB** (전용 Event Store)
- **PostgreSQL** (이벤트 테이블)

---

## 5. 통신 방식 비교

### 📊 REST API (동기) vs Event-Driven (비동기)

| Feature | REST API (Synchronous) | Event-Driven (Async) |
|---------|------------------------|----------------------|
| **Coupling** | 강한 결합 (Tight) | 느슨한 결합 (Loose) |
| **Communication** | 동기 (Blocking) | 비동기 (Non-blocking) |
| **Scalability** | 확장 어려움 | 고확장성 |
| **Fault Tolerance** | 서비스 가용성에 의존 | 독립적으로 동작 가능 |
| **즉시 응답** | ✅ 가능 | ❌ 불가능 (Eventually Consistent) |
| **Complexity** | 낮음 | 중간 |
| **Use Case** | 직접 API 호출 (로그인, 조회) | 실시간 처리 (알림, 로그, 분석) |
| **Error Handling** | 직접 응답 확인 | Retry, Dead Letter Queue |

### 🎯 하이브리드 접근 (추천)

대부분의 실무 MSA는 **동기 + 비동기 혼합**:

```
Client
  ↓ REST API (동기)
API Gateway
  ↓
Order Service
  ├─→ Payment Service (REST API) - 즉시 확인 필요
  └─→ [OrderCreated Event] → Kafka
                ↓
           Notification Service (비동기) - 즉시 응답 불필요
```

**선택 기준:**
- **동기 (REST)**: 즉시 응답 필요, 직접 결과 확인
- **비동기 (Event)**: 백그라운드 처리, 여러 서비스 통지

---

## 6. 실제 구현

### 🛠️ 기술 스택

**Producer/Consumer:**
- Java/Spring Boot: Spring Kafka
- Node.js: kafkajs
- Python: kafka-python, confluent-kafka
- Go: sarama

**Message Broker:**
- Apache Kafka (추천)
- RabbitMQ
- AWS EventBridge (서버리스)

### 💻 전체 예시 코드 (Spring Boot + Kafka)

#### 1. 이벤트 정의

```java
@Data
@Builder
public class OrderCreatedEvent {
    private String orderId;
    private String userId;
    private List<OrderItem> items;
    private BigDecimal totalAmount;
    private Instant timestamp;
}
```

#### 2. Producer 설정

```yaml
# application.yml
spring:
  kafka:
    bootstrap-servers: localhost:9092
    producer:
      key-serializer: org.apache.kafka.common.serialization.StringSerializer
      value-serializer: org.springframework.kafka.support.serializer.JsonSerializer
      acks: all  # 모든 Replica 확인 (안정성)
      retries: 3
```

```java
@Configuration
public class KafkaProducerConfig {

    @Bean
    public ProducerFactory<String, OrderCreatedEvent> producerFactory() {
        return new DefaultKafkaProducerFactory<>(producerConfigs());
    }

    @Bean
    public KafkaTemplate<String, OrderCreatedEvent> kafkaTemplate() {
        return new KafkaTemplate<>(producerFactory());
    }
}
```

#### 3. Consumer 설정

```yaml
spring:
  kafka:
    consumer:
      bootstrap-servers: localhost:9092
      group-id: inventory-service-group
      key-deserializer: org.apache.kafka.common.serialization.StringDeserializer
      value-deserializer: org.springframework.kafka.support.serializer.JsonDeserializer
      properties:
        spring.json.trusted.packages: "*"
      enable-auto-commit: false  # 수동 커밋 (안정성)
```

```java
@Service
@Slf4j
public class InventoryEventConsumer {

    @KafkaListener(
        topics = "orders.created",
        groupId = "inventory-service-group",
        containerFactory = "kafkaListenerContainerFactory"
    )
    public void consume(
        @Payload OrderCreatedEvent event,
        @Header(KafkaHeaders.RECEIVED_TOPIC) String topic,
        @Header(KafkaHeaders.OFFSET) Long offset,
        Acknowledgment acknowledgment
    ) {
        log.info("Consumed event from topic={}, offset={}, orderId={}",
            topic, offset, event.getOrderId());

        try {
            // 비즈니스 로직 처리
            inventoryService.reserveItems(event.getItems());

            // 수동 커밋 (처리 완료 확인 후)
            acknowledgment.acknowledge();

        } catch (Exception e) {
            log.error("Failed to process event: {}", event, e);
            // Retry 로직 또는 Dead Letter Queue로 이동
        }
    }
}
```

---

## 7. 장단점

### ✅ 장점

1. **병목 제거**
   - 서비스가 응답을 기다리며 블로킹되지 않음
   - 높은 처리량 (Throughput)

2. **복원력 향상**
   - 한 서비스의 장애가 전체 시스템으로 전파되지 않음
   - 이벤트는 Queue에 보관되어 복구 후 처리

3. **실시간 인사이트**
   - 이벤트가 지속적으로 흐르며 실시간 분석 가능
   - Event Stream Processing (Kafka Streams, Flink)

4. **유연성**
   - 기존 서비스 재작성 없이 새 Consumer 추가
   - 비즈니스 로직 변경 시 영향 범위 최소화

5. **확장성**
   - Consumer를 수평 확장하여 처리량 증가
   - Producer와 Consumer가 독립적으로 확장

### ❌ 단점

1. **Eventually Consistent (최종 일관성)**
   - 즉시 일관성 보장 불가
   - 예: 주문 생성 후 재고 차감까지 수 초 소요

2. **복잡도 증가**
   - 이벤트 추적 어려움 (분산 트레이싱 필수)
   - 디버깅이 동기 방식보다 어려움

3. **메시지 순서 보장 문제**
   - Kafka는 Partition 내에서만 순서 보장
   - 여러 Partition 사용 시 전역 순서 보장 안 됨

4. **중복 메시지 처리**
   - At-least-once 전달 시 중복 가능
   - Consumer의 멱등성 보장 필요

5. **운영 복잡도**
   - Kafka 클러스터 관리 필요
   - 모니터링, 알람 설정 복잡

---

## 8. 사용 시기

### ✅ 적합한 경우

1. **높은 확장성 필요**
   - 수만~수백만 TPS 처리
   - 예: 전자상거래 주문, 로그 수집

2. **느슨한 결합 추구**
   - 서비스 간 독립성 확보
   - 마이크로서비스가 자주 변경되는 환경

3. **실시간 이벤트 처리**
   - 실시간 알림, 추천 시스템
   - 스트림 분석 (Fraud Detection, 이상 탐지)

4. **복잡한 워크플로우**
   - 여러 서비스가 협력하는 프로세스
   - 예: 주문 → 결제 → 배송 → 알림

5. **감사 추적 필요**
   - Event Sourcing과 함께 사용
   - 모든 이벤트 보존

### ❌ 부적합한 경우

1. **즉각적인 응답 필수**
   - 예: 결제 승인 (즉시 성공/실패 확인)
   - 사용자가 실시간 결과 대기

2. **단순한 CRUD 앱**
   - 간단한 RESTful API면 충분
   - 오버엔지니어링 방지

3. **팀의 기술 역량 부족**
   - Kafka, 비동기 처리 경험 없음
   - 학습 비용 고려

4. **소규모 서비스 (3-5개 미만)**
   - Kafka 운영 비용 > 이점
   - REST API로 충분

---

## 9. 2026년 표준 스택

### 🏆 추천 구성

```
┌─────────────────────────────────────────────────┐
│        Event Streaming Platform                 │
│          Apache Kafka Cluster                   │
│  (3 Brokers, Replication Factor: 3)             │
└─────────────────┬───────────────────────────────┘
                  │
    ┌─────────────┼─────────────┐
    │             │             │
    ▼             ▼             ▼
Schema       Kafka         Kafka
Registry     Connect      Streams
(Avro)     (CDC, Sink)  (Processing)

Monitoring:
- Prometheus + Grafana
- Kafka Exporter
- Confluent Control Center
```

### 📦 주요 도구

1. **Apache Kafka** (Core)
   - 버전: 3.6+ (2026년 안정 버전)
   - KRaft 모드 (ZooKeeper 제거)

2. **Schema Registry** (Confluent)
   - Avro, Protobuf, JSON Schema 관리
   - Schema 버전 관리 및 호환성 검사

3. **Kafka Connect**
   - DB → Kafka (CDC: Change Data Capture)
   - Kafka → DB, S3, Elasticsearch (Sink)

4. **Kafka Streams / ksqlDB**
   - 실시간 스트림 처리
   - 이벤트 변환, 집계, Join

5. **Monitoring**
   - **Prometheus + Grafana**: 메트릭 수집 및 대시보드
   - **Jaeger**: 분산 트레이싱
   - **ELK Stack**: 로그 중앙화

---

## 10. 실전 사례

### 📊 성능 데이터 (연구 결과)

> [!example] 실제 성능 비교
> Event-Driven Architecture가 API-Driven 대비:
> - ✅ **응답 시간 19.18% 개선**
> - ✅ **에러율 34.40% 감소**
> - ⚠️ CPU 사용량 8.52% 증가 (비동기 처리 오버헤드)

### 🏢 실제 기업 사례

#### Netflix

**규모:**
- 수천 개의 마이크로서비스
- 초당 수백만 이벤트 처리

**아키텍처:**
```
User Action (Play Video)
  ↓ [ViewingStarted Event]
Kafka
  ├─→ Recommendation Service (시청 패턴 분석)
  ├─→ Billing Service (사용량 계산)
  ├─→ Analytics Service (메트릭 수집)
  └─→ Content Delivery Service (CDN 최적화)
```

#### Uber

**사용 사례:**
- 실시간 위치 추적
- 운전자-승객 매칭
- 요금 계산

**이벤트 플로우:**
```
Driver Location Update
  ↓ [LocationUpdated Event] (매 5초)
Kafka
  ├─→ Matching Service
  ├─→ ETA Calculation Service
  └─→ Fraud Detection Service
```

---

## 📚 참고 자료

### 🔗 관련 패턴

- [[../02-데이터-관리-패턴/Event-Sourcing|Event Sourcing]] - 이벤트를 상태 저장소로 사용
- [[../02-데이터-관리-패턴/CQRS-패턴|CQRS]] - Event-Driven과 자주 함께 사용
- [[../02-데이터-관리-패턴/Saga-패턴|Saga]] - 이벤트 기반 분산 트랜잭션

### 📖 추가 학습 자료

- [Confluent Kafka Documentation](https://docs.confluent.io/)
- [Building Event-Driven Microservices - Adam Bellemare](https://www.oreilly.com/library/view/building-event-driven-microservices/9781492057888/)
- [Kafka: The Definitive Guide](https://www.confluent.io/resources/kafka-the-definitive-guide/)

---

**상위 문서**: [[_README|통신 패턴 폴더]]
**마지막 업데이트**: 2026-01-02
**다음 학습**: [[../02-데이터-관리-패턴/Event-Sourcing|Event Sourcing 패턴]]
