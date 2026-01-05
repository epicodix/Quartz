---
title: CQRS 패턴 - 읽기와 쓰기의 분리
tags:
  - MSA
  - CQRS
  - command-query-separation
  - read-model
  - write-model
  - eventual-consistency
aliases:
  - Command Query Responsibility Segregation
  - 명령 조회 책임 분리
date: 2026-01-05
category: MSA-디자인-패턴/02-데이터-관리-패턴
status: 완성
priority: 높음
difficulty: 고급
related:
  - "[[Event-Sourcing-패턴|Event Sourcing 패턴]]"
  - "[[Saga-패턴|Saga 패턴]]"
  - "[[Database-per-Service|Database per Service]]"
prerequisites:
  - "[[Database-per-Service|Database per Service]]"
next_steps:
  - "[[Event-Sourcing-패턴|Event Sourcing 패턴]]"
---

# 🔀 CQRS 패턴

> [!note] 패턴 개요
> CQRS (Command Query Responsibility Segregation)는 **명령(쓰기)과 조회(읽기)의 책임을 분리**하는 패턴입니다. 데이터 변경과 데이터 조회를 서로 다른 모델로 처리하여 성능, 확장성, 보안을 최적화합니다.

> [!tip] 중요도: ⭐⭐⭐⭐ 고급 패턴
> 복잡한 도메인, 높은 트래픽, 서로 다른 읽기/쓰기 요구사항이 있는 시스템에서 필수적입니다.

---

## 📑 목차

- [[#1. 핵심 개념|핵심 개념]]
- [[#2. 문제와 해결|문제와 해결]]
- [[#3. CQRS 아키텍처|CQRS 아키텍처]]
- [[#4. 구현 패턴|구현 패턴]]
- [[#5. 실제 구현|실제 구현]]
- [[#6. 동기화 전략|동기화 전략]]
- [[#7. 장단점|장단점]]
- [[#8. 사용 시기|사용 시기]]
- [[#9. 실전 사례|실전 사례]]

---

## 1. 핵심 개념

### 🎯 정의

CQRS는 Martin Fowler가 제안한 **Command Query Separation (CQS)** 원칙을 확장한 패턴입니다.

**CQS 원칙:**
- **Command (명령)**: 상태를 변경하지만 값을 반환하지 않음
- **Query (조회)**: 값을 반환하지만 상태를 변경하지 않음

**CQRS 확장:**
- Command와 Query를 **서로 다른 모델**로 분리
- **서로 다른 DB**를 사용할 수도 있음

### 📊 전통적인 CRUD vs CQRS

**전통적인 CRUD (단일 모델):**
```
┌─────────────┐
│  Client     │
└──────┬──────┘
       │
       ▼
┌─────────────┐
│  Service    │  ← 동일한 Entity 모델
└──────┬──────┘
       │
       ▼
┌─────────────┐
│  Database   │  ← 단일 DB
└─────────────┘
```

**CQRS (명령/조회 분리):**
```
       ┌─────────────┐
       │   Client    │
       └──────┬──────┘
              │
    ┌─────────┴─────────┐
    │                   │
    ▼                   ▼
┌────────────┐    ┌────────────┐
│ Command    │    │  Query     │
│ Service    │    │  Service   │
└─────┬──────┘    └──────┬─────┘
      │                  │
      ▼                  ▼
┌────────────┐    ┌────────────┐
│Write Model │    │ Read Model │  ← 서로 다른 모델
│   (정규화)  │    │  (비정규화) │
└─────┬──────┘    └──────┬─────┘
      │                  │
      ▼                  ▼
┌────────────┐    ┌────────────┐
│  Write DB  │    │  Read DB   │  ← 서로 다른 DB
│ (PostgreSQL)    │ (Elasticsearch)
└────────────┘    └────────────┘
       │                  ▲
       └──────────────────┘
          동기화 (이벤트)
```

---

## 2. 문제와 해결

### 🚨 해결하려는 문제

#### 문제 1: 읽기/쓰기 요구사항 불일치

> [!example] E-Commerce 시스템
> **쓰기 요구사항**:
> - 주문 생성 (초당 100건)
> - 강한 일관성 필요
> - 정규화된 데이터 구조
> - 트랜잭션 보장
>
> **읽기 요구사항**:
> - 상품 검색 (초당 10,000건)
> - 최종 일관성 허용
> - 비정규화된 데이터 (JOIN 최소화)
> - 전문 검색, 필터링, 정렬

**단일 모델의 문제:**
```sql
-- 쓰기에 최적화 (정규화)
CREATE TABLE orders (
    id UUID PRIMARY KEY,
    user_id UUID,
    status VARCHAR(20)
);

CREATE TABLE order_items (
    id UUID PRIMARY KEY,
    order_id UUID,
    product_id UUID,
    quantity INT
);

-- 읽기 시 복잡한 JOIN 필요 (느림!)
SELECT o.*, oi.*, p.*
FROM orders o
JOIN order_items oi ON o.id = oi.order_id
JOIN products p ON oi.product_id = p.id
WHERE o.user_id = ?;
```

#### 문제 2: 성능 병목

```
단일 DB 구조:
- 읽기 95%, 쓰기 5%
- 읽기 쿼리가 복잡 (다중 JOIN, 집계)
- 쓰기 트랜잭션이 읽기 블로킹
→ DB 성능 저하
```

#### 문제 3: 확장성 제한

```
단일 모델:
- 읽기와 쓰기가 같이 증가
- Scale-up만 가능 (Vertical Scaling)
- 비용 급증

CQRS:
- 읽기와 쓰기 독립적으로 확장
- Scale-out 가능 (Horizontal Scaling)
- 비용 효율적
```

### ✅ CQRS의 해결 방법

#### 해결 1: 모델 분리

```java
// Write Model (정규화, DDD 적용)
@Entity
public class Order {
    @Id
    private UUID id;
    private UUID userId;
    private OrderStatus status;

    @OneToMany
    private List<OrderItem> items;

    public void addItem(Product product, int quantity) {
        // 비즈니스 로직
        validateStock(product, quantity);
        items.add(new OrderItem(product, quantity));
    }
}

// Read Model (비정규화, DTO)
public class OrderSummaryDTO {
    private UUID orderId;
    private String userName;
    private List<String> productNames;  // JOIN 없이 바로 조회
    private BigDecimal totalAmount;
    private String status;
}
```

#### 해결 2: DB 분리

```
Write DB (PostgreSQL):
- ACID 트랜잭션
- 정규화
- 관계형 데이터

Read DB (Elasticsearch):
- 전문 검색
- 집계 쿼리
- 비정규화
- 캐시 친화적
```

#### 해결 3: 독립적 확장

```
Write:
- Master DB 1대
- Slave DB 2대 (백업)
- 초당 100건 처리

Read:
- Elasticsearch 클러스터 10대
- 초당 10,000건 처리
- Redis 캐시 추가
```

---

## 3. CQRS 아키텍처

### 📐 기본 구조

```
┌───────────────────────────────────────────────────────┐
│                   API Gateway                         │
└────────────┬──────────────────────┬───────────────────┘
             │                      │
     Command (POST/PUT/DELETE)   Query (GET)
             │                      │
             ▼                      ▼
┌─────────────────────┐   ┌─────────────────────┐
│  Command Handler    │   │   Query Handler     │
│                     │   │                     │
│  - Validation       │   │  - Caching          │
│  - Business Logic   │   │  - Projection       │
│  - Event Publishing │   │  - Filtering        │
└──────────┬──────────┘   └──────────┬──────────┘
           │                         │
           ▼                         ▼
┌─────────────────────┐   ┌─────────────────────┐
│   Write Model       │   │   Read Model        │
│                     │   │                     │
│  Order (Entity)     │   │  OrderSummary (DTO) │
│  OrderItem (Entity) │   │  ProductView (DTO)  │
└──────────┬──────────┘   └──────────┬──────────┘
           │                         │
           ▼                         ▼
┌─────────────────────┐   ┌─────────────────────┐
│   Write Database    │   │   Read Database     │
│                     │   │                     │
│  PostgreSQL         │   │  Elasticsearch      │
│  (정규화, ACID)      │   │  (비정규화, 검색)    │
└──────────┬──────────┘   └──────────▲──────────┘
           │                         │
           └─────────────────────────┘
                 Event Bus
                (Kafka/RabbitMQ)
```

---

### 🔄 데이터 흐름

**Command 흐름 (쓰기):**
```
1. Client → POST /orders
2. Command Handler → Validate
3. Command Handler → Business Logic
4. Write DB ← Save Order
5. Event Bus ← Publish OrderCreatedEvent
6. Client ← Response (201 Created)
```

**Query 흐름 (읽기):**
```
1. Client → GET /orders/123
2. Query Handler → Check Cache
3. Read DB ← Query (if cache miss)
4. Client ← Response (200 OK)
```

**동기화 흐름:**
```
1. Event Bus → OrderCreatedEvent
2. Event Handler → Listen
3. Read DB ← Update OrderSummary
```

---

## 4. 구현 패턴

### 1. Simple CQRS (단순 CQRS)

**특징**: 같은 DB, 다른 모델

```java
// Command Side
@Service
public class OrderCommandService {

    @Autowired
    private OrderRepository orderRepository;

    @Transactional
    public UUID createOrder(CreateOrderCommand command) {
        // Write Model 사용
        Order order = new Order(command.getUserId());
        command.getItems().forEach(item ->
            order.addItem(item.getProductId(), item.getQuantity())
        );

        return orderRepository.save(order).getId();
    }
}

// Query Side
@Service
public class OrderQueryService {

    @Autowired
    private OrderSummaryRepository orderSummaryRepository;

    public OrderSummaryDTO getOrder(UUID orderId) {
        // Read Model 사용 (비정규화)
        return orderSummaryRepository.findById(orderId)
            .orElseThrow(() -> new OrderNotFoundException(orderId));
    }
}
```

**장점**: 구현 간단, 마이그레이션 쉬움
**단점**: 성능 향상 제한적

---

### 2. CQRS with Separate DBs (DB 분리)

**특징**: 서로 다른 DB 사용

```yaml
# application.yml
spring:
  datasource:
    write:
      url: jdbc:postgresql://localhost:5432/orders_write
      username: write_user
      password: secret

    read:
      url: jdbc:postgresql://localhost:5432/orders_read
      username: read_user
      password: secret
```

```java
@Configuration
public class DataSourceConfig {

    @Bean
    @ConfigurationProperties("spring.datasource.write")
    public DataSource writeDataSource() {
        return DataSourceBuilder.create().build();
    }

    @Bean
    @ConfigurationProperties("spring.datasource.read")
    public DataSource readDataSource() {
        return DataSourceBuilder.create().build();
    }
}
```

---

### 3. CQRS + Event Sourcing (이벤트 소싱)

**특징**: Write Model을 이벤트로 저장

```java
// Event Store (Write Side)
@Service
public class OrderEventStore {

    public void save(UUID orderId, DomainEvent event) {
        eventRepository.save(new EventEntry(
            orderId,
            event.getClass().getName(),
            serialize(event),
            Instant.now()
        ));

        // Read Model 업데이트용 이벤트 발행
        eventBus.publish(event);
    }

    public List<DomainEvent> getEvents(UUID orderId) {
        return eventRepository.findByAggregateId(orderId)
            .stream()
            .map(this::deserialize)
            .collect(Collectors.toList());
    }
}

// Projection (Read Side)
@Component
public class OrderSummaryProjection {

    @EventListener
    public void on(OrderCreatedEvent event) {
        OrderSummary summary = new OrderSummary();
        summary.setOrderId(event.getOrderId());
        summary.setUserName(event.getUserName());
        summary.setStatus("CREATED");
        orderSummaryRepository.save(summary);
    }

    @EventListener
    public void on(OrderCompletedEvent event) {
        OrderSummary summary = orderSummaryRepository.findById(event.getOrderId());
        summary.setStatus("COMPLETED");
        orderSummaryRepository.save(summary);
    }
}
```

---

## 5. 실제 구현

### 💻 Spring Boot + Axon Framework

**의존성:**
```xml
<dependency>
    <groupId>org.axonframework</groupId>
    <artifactId>axon-spring-boot-starter</artifactId>
    <version>4.9.0</version>
</dependency>
```

**Command 정의:**
```java
public class CreateOrderCommand {
    @TargetAggregateIdentifier
    private final UUID orderId;
    private final UUID userId;
    private final List<OrderItemDTO> items;
}

public class CompleteOrderCommand {
    @TargetAggregateIdentifier
    private final UUID orderId;
}
```

**Aggregate (Write Model):**
```java
@Aggregate
public class OrderAggregate {

    @AggregateIdentifier
    private UUID orderId;
    private OrderStatus status;

    public OrderAggregate() {
        // Axon requires no-arg constructor
    }

    @CommandHandler
    public OrderAggregate(CreateOrderCommand command) {
        // Validation
        if (command.getItems().isEmpty()) {
            throw new IllegalArgumentException("Order must have items");
        }

        // Apply event
        apply(new OrderCreatedEvent(
            command.getOrderId(),
            command.getUserId(),
            command.getItems()
        ));
    }

    @EventSourcingHandler
    public void on(OrderCreatedEvent event) {
        this.orderId = event.getOrderId();
        this.status = OrderStatus.CREATED;
    }

    @CommandHandler
    public void handle(CompleteOrderCommand command) {
        // Business logic
        if (status != OrderStatus.PAID) {
            throw new IllegalStateException("Order must be paid first");
        }

        apply(new OrderCompletedEvent(command.getOrderId()));
    }

    @EventSourcingHandler
    public void on(OrderCompletedEvent event) {
        this.status = OrderStatus.COMPLETED;
    }
}
```

**Projection (Read Model):**
```java
@Component
public class OrderSummaryProjection {

    @Autowired
    private OrderSummaryRepository repository;

    @EventHandler
    public void on(OrderCreatedEvent event) {
        OrderSummary summary = new OrderSummary();
        summary.setOrderId(event.getOrderId());
        summary.setUserId(event.getUserId());
        summary.setItemCount(event.getItems().size());
        summary.setStatus("CREATED");
        summary.setCreatedAt(Instant.now());

        repository.save(summary);
    }

    @EventHandler
    public void on(OrderCompletedEvent event) {
        repository.findById(event.getOrderId()).ifPresent(summary -> {
            summary.setStatus("COMPLETED");
            summary.setCompletedAt(Instant.now());
            repository.save(summary);
        });
    }
}
```

**Query Handler:**
```java
@Component
public class OrderQueryHandler {

    @Autowired
    private OrderSummaryRepository repository;

    @QueryHandler
    public OrderSummary handle(FindOrderQuery query) {
        return repository.findById(query.getOrderId())
            .orElseThrow(() -> new OrderNotFoundException(query.getOrderId()));
    }

    @QueryHandler
    public List<OrderSummary> handle(FindOrdersByUserQuery query) {
        return repository.findByUserId(query.getUserId());
    }
}
```

---

### 🚀 Elasticsearch 읽기 모델

**설정:**
```java
@Configuration
@EnableElasticsearchRepositories(basePackages = "com.example.read.repository")
public class ElasticsearchConfig {

    @Bean
    public RestHighLevelClient client() {
        return new RestHighLevelClient(
            RestClient.builder(
                new HttpHost("localhost", 9200, "http")
            )
        );
    }
}
```

**Read Model (Elasticsearch Document):**
```java
@Document(indexName = "order_summaries")
public class OrderSummaryDocument {

    @Id
    private String id;

    @Field(type = FieldType.Keyword)
    private String orderId;

    @Field(type = FieldType.Keyword)
    private String userId;

    @Field(type = FieldType.Text)
    private String userName;  // 비정규화: User 정보 포함

    @Field(type = FieldType.Nested)
    private List<OrderItemSummary> items;  // 비정규화: 아이템 정보 포함

    @Field(type = FieldType.Double)
    private BigDecimal totalAmount;

    @Field(type = FieldType.Keyword)
    private String status;

    @Field(type = FieldType.Date)
    private Instant createdAt;
}
```

**검색 쿼리:**
```java
@Service
public class OrderSearchService {

    @Autowired
    private ElasticsearchOperations elasticsearchOperations;

    public List<OrderSummaryDocument> searchOrders(String keyword) {
        NativeSearchQuery searchQuery = new NativeSearchQueryBuilder()
            .withQuery(QueryBuilders.multiMatchQuery(keyword, "userName", "items.productName"))
            .withPageable(PageRequest.of(0, 10))
            .build();

        return elasticsearchOperations.search(searchQuery, OrderSummaryDocument.class)
            .stream()
            .map(SearchHit::getContent)
            .collect(Collectors.toList());
    }

    public List<OrderSummaryDocument> findByUserAndStatus(String userId, String status) {
        NativeSearchQuery searchQuery = new NativeSearchQueryBuilder()
            .withQuery(QueryBuilders.boolQuery()
                .must(QueryBuilders.termQuery("userId", userId))
                .must(QueryBuilders.termQuery("status", status)))
            .build();

        return elasticsearchOperations.search(searchQuery, OrderSummaryDocument.class)
            .stream()
            .map(SearchHit::getContent)
            .collect(Collectors.toList());
    }
}
```

---

## 6. 동기화 전략

### 1. 동기 업데이트 (Synchronous)

```java
@Transactional
public UUID createOrder(CreateOrderCommand command) {
    // 1. Write DB에 저장
    Order order = orderRepository.save(new Order(command));

    // 2. Read DB에 즉시 동기화
    OrderSummary summary = toSummary(order);
    orderSummaryRepository.save(summary);

    return order.getId();
}
```

**장점**: 즉시 일관성
**단점**: 성능 저하, 결합도 증가

---

### 2. 비동기 이벤트 (Asynchronous Event)

```java
// Command Side
@Transactional
public UUID createOrder(CreateOrderCommand command) {
    Order order = orderRepository.save(new Order(command));

    // 이벤트 발행 (비동기)
    eventPublisher.publish(new OrderCreatedEvent(order));

    return order.getId();
}

// Event Handler (별도 스레드/서비스)
@Async
@EventListener
public void handleOrderCreated(OrderCreatedEvent event) {
    OrderSummary summary = toSummary(event);
    orderSummaryRepository.save(summary);
}
```

**장점**: 성능, 확장성
**단점**: 최종 일관성 (약간의 지연)

---

### 3. CDC (Change Data Capture)

**Debezium 사용:**
```yaml
# Debezium Connector 설정
name: order-connector
connector.class: io.debezium.connector.postgresql.PostgresConnector
database.hostname: localhost
database.port: 5432
database.user: postgres
database.password: secret
database.dbname: orders
table.include.list: public.orders,public.order_items
```

```java
@Component
public class DebeziumEventListener {

    @KafkaListener(topics = "dbserver1.public.orders")
    public void handleOrderChange(ConsumerRecord<String, String> record) {
        ChangeEvent event = parseChangeEvent(record.value());

        if (event.getOperation() == Operation.CREATE) {
            OrderSummary summary = buildSummary(event);
            orderSummaryRepository.save(summary);
        }
    }
}
```

**장점**:
- Write 모델 변경 불필요
- 신뢰성 높음 (DB 트랜잭션 로그 기반)

**단점**:
- 설정 복잡
- DB별 지원 상이

---

## 7. 장단점

### ✅ 장점

1. **성능 최적화**
   - 읽기와 쓰기를 독립적으로 최적화
   - 복잡한 JOIN 제거

2. **확장성**
   - 읽기와 쓰기를 독립적으로 스케일링
   - 비용 효율적

3. **유연성**
   - 읽기 모델을 다양하게 구성 (검색, 분석, 보고서)
   - 기술 스택 자유 (PostgreSQL + Elasticsearch)

4. **보안**
   - 읽기와 쓰기 권한 분리
   - 민감 정보 제어

### ❌ 단점

1. **복잡도 증가**
   - 두 개의 모델 유지
   - 동기화 로직 필요

2. **최종 일관성**
   - 읽기 모델이 즉시 업데이트되지 않음
   - 사용자 혼란 가능

3. **중복 코드**
   - Command와 Query 코드 분리
   - 유지보수 비용

4. **학습 곡선**
   - 팀 교육 필요
   - 디버깅 어려움

---

## 8. 사용 시기

### ✅ 적합한 경우

1. **읽기/쓰기 비율 차이**
   - 읽기 95%, 쓰기 5%
   - 읽기 쿼리가 복잡

2. **성능 요구사항**
   - 높은 처리량 필요
   - 낮은 지연시간 요구

3. **복잡한 도메인**
   - DDD 적용
   - 비즈니스 로직 복잡

4. **다양한 뷰**
   - 검색, 분석, 보고서 등 다양한 읽기 패턴

### ❌ 부적합한 경우

1. **단순한 CRUD**
   - 복잡도 대비 이점 없음

2. **즉시 일관성 필수**
   - 금융 거래 등

3. **소규모 시스템**
   - 오버 엔지니어링

---

## 9. 실전 사례

### 🏢 Microsoft Azure

**사용 사례**: Dynamics 365

```
Write: SQL Server (트랜잭션)
Read: Azure Search (검색), Cosmos DB (글로벌 읽기)
```

**효과**:
- 글로벌 읽기 지연 90% 감소
- 검색 성능 10배 향상

---

### 🏢 Netflix

**사용 사례**: 사용자 활동 추적

```
Write: Cassandra (쓰기 최적화)
Read: Elasticsearch (검색), Redshift (분석)
```

**효과**:
- 초당 100만 이벤트 처리
- 실시간 추천 가능

---

## 📚 참고 자료

### 🔗 관련 패턴

- [[Event-Sourcing-패턴|Event Sourcing]]
- [[Saga-패턴|Saga 패턴]]
- [[Database-per-Service|Database per Service]]

### 📖 추가 학습 자료

- [CQRS - Martin Fowler](https://martinfowler.com/bliki/CQRS.html)
- [CQRS Journey - Microsoft](https://docs.microsoft.com/en-us/previous-versions/msp-n-p/jj554200(v=pandp.10))
- [Implementing Domain-Driven Design - Vaughn Vernon](https://www.oreilly.com/library/view/implementing-domain-driven-design/9780133039900/)

---

**상위 문서**: [[_README|데이터 관리 패턴 폴더]]
**마지막 업데이트**: 2026-01-05
**다음 학습**: [[Event-Sourcing-패턴|Event Sourcing 패턴]]

<br>
<div align="right" style="font-size: 0.8em; color: gray; opacity: 0.6;">
  Supported by Sonnet 4.5
</div>