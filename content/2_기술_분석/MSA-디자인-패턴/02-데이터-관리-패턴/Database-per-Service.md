---
title: Database per Service 패턴 - 서비스별 독립 데이터베이스
tags:
  - MSA
  - database
  - data-management
  - polyglot-persistence
aliases:
  - 데이터베이스 퍼 서비스
  - Database per Service
date: 2026-01-02
category: MSA-디자인-패턴/02-데이터-관리-패턴
status: 완성
priority: 높음
difficulty: 초급
related:
  - "[[CQRS-패턴|CQRS 패턴]]"
  - "[[Saga-패턴|Saga 패턴]]"
  - "[[../01-통신-패턴/API-Gateway-패턴|API Gateway 패턴]]"
prerequisites:
  - "[[../01-통신-패턴/API-Gateway-패턴|API Gateway 패턴]]"
next_steps:
  - "[[CQRS-패턴|CQRS 패턴]]"
  - "[[Saga-패턴|Saga 패턴]]"
---

# 🗄️ Database per Service 패턴

> [!note] 패턴 개요
> Database per Service는 각 마이크로서비스가 **자신만의 독립적인 데이터베이스를 소유**하고, 다른 서비스의 데이터베이스에 직접 접근하는 것을 금지하는 MSA의 가장 기본적인 데이터 관리 원칙입니다.

> [!tip] 중요도: ⭐⭐⭐ MSA 필수 원칙
> 2026년 MSA에서 Database per Service는 단순한 패턴이 아니라 **마이크로서비스의 정체성을 보장하는 핵심 원칙**입니다.

---

## 📑 목차

- [[#1. 핵심 개념|핵심 개념]]
- [[#2. 문제와 해결|문제와 해결]]
- [[#3. 아키텍처 구조|아키텍처 구조]]
- [[#4. 구현 방법|구현 방법]]
- [[#5. 데이터 동기화|데이터 동기화]]
- [[#6. 장단점|장단점]]
- [[#7. 사용 시기|사용 시기]]
- [[#8. 2026년 표준 스택|2026년 표준 스택]]
- [[#9. 실전 사례|실전 사례]]

---

## 1. 핵심 개념

### 🎯 정의

Database per Service는 **각 마이크로서비스가 자신만의 데이터 저장소를 독점적으로 소유**하는 아키텍처 원칙입니다.

**핵심 원칙:**
- **데이터 소유권**: 서비스가 자신의 데이터에 대한 완전한 제어권 보유
- **직접 접근 금지**: 다른 서비스가 다른 서비스의 DB에 직접 접근 불가
- **API 통신만 허용**: 서비스 간 데이터 교환은 API를 통해서만 가능
- **폴리글랏 퍼시스턴스**: 각 서비스가 최적의 DB 기술 자유롭게 선택

### 📊 기본 아키텍처

```
┌─────────────────────────────────────────────────────────────┐
│                  Service Boundary                   │
│                                                     │
│  ┌─────────────────┐    ┌─────────────────┐        │
│  │  Order Service │    │ Payment Service │        │
│  │                │    │                │        │
│  │  ┌─────────┐   │    │  ┌─────────┐   │        │
│  │  │PostgreSQL│   │    │  │ MongoDB  │   │        │
│  │  │   DB    │   │    │  │   DB    │   │        │
│  │  └─────────┘   │    │  └─────────┘   │        │
│  └─────────────────┘    └─────────────────┘        │
│           │                     │                   │
│           └─────────┬─────────┘                   │
│                     │ API Calls                   │
│                     ▼                            │
│  ┌─────────────────┐    ┌─────────────────┐        │
│  │Inventory Service│    │Customer Service│        │
│  │                │    │                │        │
│  │  ┌─────────┐   │    │  ┌─────────┐   │        │
│  │  │  Redis  │   │    │  │MySQL    │   │        │
│  │  │  Cache  │   │    │  │   DB    │   │        │
│  │  └─────────┘   │    │  └─────────┘   │        │
│  └─────────────────┘    └─────────────────┘        │
└─────────────────────────────────────────────────────────────┘
```

**동작 방식:**
- 각 서비스는 자신의 DB를 완전히 소유
- 서비스 간 통신은 API 또는 이벤트를 통해서만 이루어짐
- 각 서비스는 자신에게 최적화된 DB 기술 선택 가능

---

## 2. 문제와 해결

### 🚨 해결하려는 문제

#### 문제 1: 공유 데이터베이스의 결합

**전통적인 공유 DB 방식:**
```
Service A ──┐
            ├── Shared DB ← 결합도 높음!
Service B ──┤
            └── 공유 스키마 → 모든 서비스 영향
Service C ──┘
```

**문제점:**
- **강한 결합**: 한 서비스의 스키마 변경이 다른 모든 서비스에 영향
- **독립성 상실**: 개별 서비스 배포 불가능
- **기술 종속**: 모든 서비스가 동일한 DB 기술에 종속
- **확장성 제한**: 전체 시스템의 확장이 한정된 리소스에 종속

#### 문제 2: 데이터 일관성 관리

- **분산 트랜잭션**: 여러 서비스에 걸친 데이터 정합성 보장 어려움
- **CAP 이론**: 일관성 vs 가용성 vs 파티션 내성 트레이드오프
- **데이터 동기화**: 서비스 간 데이터 상태 불일치 발생

#### 문제 3: 운영 복잡도

- **단일 장애점**: 공유 DB 장애 시 모든 서비스 영향
- **성능 병목**: 하나의 DB에서 모든 트래픽 처리
- **보안 경계**: 데이터 접근 제어 복잡

### ✅ Database per Service의 해결 방법

#### 해결 1: 완전한 데이터 소유권

```
Order Service ── PostgreSQL (Order 데이터)
                    │
Payment Service ── MongoDB (Payment 데이터)
                    │
Inventory Service ─ Redis (재고 데이터)
```

- **느슨한 결합**: 각 서비스가 독립적인 스키마 관리
- **독립적 배포**: 스키마 변경이 다른 서비스에 영향 없음
- **기술 자유도**: 각 서비스에 최적화된 DB 선택

#### 해결 2: API 기반 데이터 접근

```mermaid
sequenceDiagram
    participant S1 as Service A
    participant API as API Gateway
    participant S2 as Service B
    participant DB as Service B DB

    S1->>API: Request data from Service B
    API->>S2: Forward request
    S2->>DB: Query own database
    DB-->>S2: Return data
    S2-->>API: Response
    API-->>S1: Final response
```

- **간접 접근**: 다른 서비스의 데이터는 API를 통해서만 접근
- **캡슐화**: 데이터 구조 변경이 API 계약에만 영향
- **보안 강화**: 인증/인가를 통한 데이터 접근 제어

#### 해결 3. 폴리글랏 퍼시스턴스

| 서비스 | 데이터 특성 | 최적 DB | 선택 이유 |
|--------|------------|---------|----------|
| 주문 서비스 | 관계형 데이터 | PostgreSQL | ACID 트랜잭션, 복잡한 조인 |
| 결제 서비스 | 문서 데이터 | MongoDB | 스키마 유연성, 빠른 쓰기 |
| 상품 서비스 | 검색 데이터 | Elasticsearch | 전문 검색, 텍스트 분석 |
| 재고 서비스 | 실시간 데이터 | Redis | 빠른 읽기/쓰기, TTL |
| 로그 서비스 | 시계열 데이터 | InfluxDB | 시계열 데이터 최적화 |

---

## 3. 아키텍처 구조

### 📐 전체 아키텍처

```
┌─────────────────────────────────────────────────────────────┐
│                Application Layer                    │
│                                                     │
│  ┌─────────────────────────────────────────────────┐      │
│  │           API Gateway                    │      │
│  │  (Authentication, Routing, Rate Limiting)   │      │
│  └─────────────────────────────────────────────────┘      │
└─────────────────────┬─────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│               Service Layer                         │
│                                                     │
│  ┌─────────────────┐  ┌─────────────────┐            │
│  │  Order Service │  │ Payment Service │            │
│  │                │  │                │            │
│  │ Business Logic │  │ Business Logic │            │
│  │ Data Access    │  │ Data Access    │            │
│  └─────────────────┘  └─────────────────┘            │
│           │                    │                      │
│           └─────────┬──────────┘                      │
│                     │ API Calls                      │
│                     ▼                               │
│  ┌─────────────────┐  ┌─────────────────┐            │
│  │Inventory Service│  │Customer Service│            │
│  │                │  │                │            │
│  │ Business Logic │  │ Business Logic │            │
│  │ Data Access    │  │ Data Access    │            │
│  └─────────────────┘  └─────────────────┘            │
└─────────────────────┬─────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│               Data Layer                           │
│                                                     │
│  ┌─────────────────┐  ┌─────────────────┐            │
│  │  PostgreSQL    │  │    MongoDB      │            │
│  │  (Orders)      │  │  (Payments)     │            │
│  └─────────────────┘  └─────────────────┘            │
│                                                     │
│  ┌─────────────────┐  ┌─────────────────┐            │
│  │     Redis      │  │     MySQL       │            │
│  │ (Inventory)    │  │ (Customers)     │            │
│  └─────────────────┘  └─────────────────┘            │
└─────────────────────────────────────────────────────────────┘
```

### 🔄 데이터 흐름 예시

**주문 생성 시나리오:**

```mermaid
sequenceDiagram
    participant Client as Client
    participant API as API Gateway
    participant Order as Order Service
    participant Payment as Payment Service
    participant Inventory as Inventory Service
    participant OrderDB as Order DB
    participant PaymentDB as Payment DB
    participant InventoryDB as Inventory DB

    Client->>API: Create Order Request
    API->>Order: Forward order request
    
    Order->>Inventory: Check stock availability
    Inventory->>InventoryDB: Query inventory
    InventoryDB-->>Inventory: Stock info
    Inventory-->>Order: Stock available
    
    Order->>Payment: Process payment
    Payment->>PaymentDB: Create payment record
    PaymentDB-->>Payment: Payment created
    Payment-->>Order: Payment successful
    
    Order->>Inventory: Reserve inventory
    Inventory->>InventoryDB: Update stock
    InventoryDB-->>Inventory: Stock updated
    Inventory-->>Order: Inventory reserved
    
    Order->>OrderDB: Create order
    OrderDB-->>Order: Order created
    Order-->>API: Order created
    API-->>Client: Order confirmation
```

---

## 4. 구현 방법

### 🛠️ 기술 구현

#### 1. 서비스별 데이터베이스 설계

**Order Service 데이터베이스:**
```sql
-- PostgreSQL - 주문 데이터
CREATE TABLE orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL,
    total_amount DECIMAL(10,2) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE order_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID REFERENCES orders(id),
    product_id UUID NOT NULL,
    quantity INTEGER NOT NULL,
    unit_price DECIMAL(10,2) NOT NULL
);

CREATE INDEX idx_orders_customer_id ON orders(customer_id);
CREATE INDEX idx_orders_status ON orders(status);
```

**Payment Service 데이터베이스:**
```javascript
// MongoDB - 결제 데이터
db.payments.createIndex({ "orderId": 1 });
db.payments.createIndex({ "status": 1 });
db.payments.createIndex({ "createdAt": 1 });

// 샘플 문서
{
  "_id": ObjectId("..."),
  "orderId": "uuid-order-123",
  "amount": 99.99,
  "currency": "USD",
  "status": "completed",
  "paymentMethod": "credit_card",
  "transactionId": "txn_123456789",
  "createdAt": ISODate("2026-01-02T10:00:00Z"),
  "updatedAt": ISODate("2026-01-02T10:05:00Z")
}
```

**Inventory Service 데이터베이스:**
```redis
# Redis - 재고 데이터
# Key: inventory:product:{productId}
# Value: JSON string

SET inventory:product:prod-123 '{"quantity": 100, "reserved": 5, "available": 95}'
GET inventory:product:prod-123

# 재고 예약 (Redis Transaction)
MULTI
GET inventory:product:prod-123
SET inventory:product:prod-123 '{"quantity": 100, "reserved": 10, "available": 90}'
EXEC
```

#### 2. 서비스 간 API 통신

**Order Service API:**
```java
// Spring Boot - Order Controller
@RestController
@RequestMapping("/api/orders")
public class OrderController {
    
    private final OrderService orderService;
    private final InventoryClient inventoryClient;
    private final PaymentClient paymentClient;
    
    @PostMapping
    public ResponseEntity<OrderResponse> createOrder(
            @RequestBody CreateOrderRequest request) {
        
        // 1. 재고 확인
        InventoryResponse inventory = inventoryClient
            .checkStock(request.getItems());
        
        if (!inventory.isAvailable()) {
            return ResponseEntity.badRequest()
                .body(new OrderResponse("Insufficient stock"));
        }
        
        // 2. 결제 처리
        PaymentResponse payment = paymentClient
            .processPayment(new PaymentRequest(
                request.getTotalAmount(),
                request.getPaymentMethod()
            ));
        
        if (!payment.isSuccessful()) {
            return ResponseEntity.badRequest()
                .body(new OrderResponse("Payment failed"));
        }
        
        // 3. 주문 생성 (자신의 DB에만 접근)
        Order order = orderService.createOrder(request, payment);
        
        // 4. 재고 예약
        inventoryClient.reserveInventory(
            request.getItems(), 
            order.getId()
        );
        
        return ResponseEntity.ok(
            new OrderResponse(order, "Order created successfully")
        );
    }
}
```

**Inventory Service API:**
```java
// Spring Boot - Inventory Controller
@RestController
@RequestMapping("/api/inventory")
public class InventoryController {
    
    private final InventoryService inventoryService;
    
    @PostMapping("/check")
    public ResponseEntity<InventoryResponse> checkStock(
            @RequestBody List<InventoryItem> items) {
        
        boolean available = inventoryService.checkAvailability(items);
        return ResponseEntity.ok(new InventoryResponse(available));
    }
    
    @PostMapping("/reserve")
    public ResponseEntity<Void> reserveInventory(
            @RequestBody ReserveInventoryRequest request) {
        
        inventoryService.reserve(request.getItems(), request.getOrderId());
        return ResponseEntity.ok().build();
    }
}
```

#### 3. 데이터 접근 계층 구현

**Order Service Repository:**
```java
// Spring Data JPA
@Repository
public interface OrderRepository extends JpaRepository<Order, UUID> {
    
    List<Order> findByCustomerId(UUID customerId);
    
    @Query("SELECT o FROM Order o WHERE o.status = :status")
    List<Order> findByStatus(@Param("status") String status);
    
    @Query("SELECT o FROM Order o WHERE o.createdAt BETWEEN :start AND :end")
    List<Order> findByDateRange(
        @Param("start") LocalDateTime start,
        @Param("end") LocalDateTime end
    );
}
```

**Payment Service Repository:**
```java
// Spring Data MongoDB
@Repository
public interface PaymentRepository extends MongoRepository<Payment, String> {
    
    Optional<Payment> findByOrderId(String orderId);
    
    List<Payment> findByStatus(String status);
    
    List<Payment> findByCreatedAtBetween(Date start, Date end);
}
```

**Inventory Service Repository:**
```java
// Spring Data Redis
@Repository
public class InventoryRepository {
    
    private final RedisTemplate<String, String> redisTemplate;
    
    public Optional<Inventory> findByProductId(String productId) {
        String key = "inventory:product:" + productId;
        String value = redisTemplate.opsForValue().get(key);
        
        if (value != null) {
            return Optional.of(JsonUtils.fromJson(value, Inventory.class));
        }
        return Optional.empty();
    }
    
    @Transactional
    public boolean reserveStock(String productId, int quantity, String orderId) {
        String key = "inventory:product:" + productId;
        
        return redisTemplate.execute(new SessionCallback<Boolean>() {
            @Override
            public Boolean execute(RedisOperations operations) throws DataAccessException {
                operations.watch(key);
                
                String currentValue = operations.opsForValue().get(key);
                Inventory inventory = JsonUtils.fromJson(currentValue, Inventory.class);
                
                if (inventory.getAvailable() < quantity) {
                    return false;
                }
                
                operations.multi();
                inventory.setReserved(inventory.getReserved() + quantity);
                inventory.setAvailable(inventory.getAvailable() - quantity);
                operations.opsForValue().set(key, JsonUtils.toJson(inventory));
                return operations.exec() != null;
            }
        });
    }
}
```

---

### 🔧 Docker Compose 예시

```yaml
# docker-compose.yml
version: '3.8'
services:
  # Order Service
  order-service:
    build: ./order-service
    environment:
      - SPRING_DATASOURCE_URL=jdbc:postgresql://postgres-order:5432/orders
      - INVENTORY_SERVICE_URL=http://inventory-service:8082
      - PAYMENT_SERVICE_URL=http://payment-service:8083
    depends_on:
      - postgres-order
    ports:
      - "8081:8080"

  postgres-order:
    image: postgres:15
    environment:
      - POSTGRES_DB=orders
      - POSTGRES_USER=order_user
      - POSTGRES_PASSWORD=order_pass
    volumes:
      - postgres_order_data:/var/lib/postgresql/data
      - ./order-service/schema.sql:/docker-entrypoint-initdb.d/schema.sql

  # Payment Service
  payment-service:
    build: ./payment-service
    environment:
      - SPRING_DATA_MONGODB_URI=mongodb://payment_user:payment_pass@mongodb-payment:27017/payments
    depends_on:
      - mongodb-payment
    ports:
      - "8083:8080"

  mongodb-payment:
    image: mongo:6
    environment:
      - MONGO_INITDB_ROOT_USERNAME=payment_user
      - MONGO_INITDB_ROOT_PASSWORD=payment_pass
      - MONGO_INITDB_DATABASE=payments
    volumes:
      - mongodb_payment_data:/data/db

  # Inventory Service
  inventory-service:
    build: ./inventory-service
    environment:
      - SPRING_REDIS_HOST=redis-inventory
      - SPRING_REDIS_PORT=6379
    depends_on:
      - redis-inventory
    ports:
      - "8082:8080"

  redis-inventory:
    image: redis:7-alpine
    volumes:
      - redis_inventory_data:/data

volumes:
  postgres_order_data:
  mongodb_payment_data:
  redis_inventory_data:
```

---

## 5. 데이터 동기화

### 🔄 동기화 전략

#### 1. API 기반 동기화 (요청-응답)

**실시간 동기화:**
```java
// Service간 데이터 조회
@Service
public class OrderService {
    
    public OrderDTO getOrderWithCustomerInfo(UUID orderId) {
        // 1. 자신의 DB에서 주문 정보 조회
        Order order = orderRepository.findById(orderId)
            .orElseThrow(() -> new OrderNotFoundException());
        
        // 2. Customer Service API로 고객 정보 조회
        CustomerDTO customer = customerClient
            .getCustomerById(order.getCustomerId());
        
        // 3. 데이터 조합하여 반환
        return OrderDTO.builder()
            .id(order.getId())
            .totalAmount(order.getTotalAmount())
            .status(order.getStatus())
            .customer(customer)
            .build();
    }
}
```

**장점:**
- 실시간 데이터 일관성 보장
- 간단한 구현
- 즉각적인 데이터 확인

**단점:**
- 네트워크 호출로 인한 레이턴시
- 서비스 간 강한 결합 가능성
- 성능 병목 발생

---

#### 2. 이벤트 기반 동기화 (비동기)

**이벤트 발행:**
```java
// Order Service - 이벤트 발행
@Service
public class OrderService {
    
    private final ApplicationEventPublisher eventPublisher;
    
    public Order createOrder(CreateOrderRequest request) {
        // 주문 생성 로직
        Order order = createOrderLogic(request);
        
        // 이벤트 발행
        OrderCreatedEvent event = new OrderCreatedEvent(
            order.getId(),
            order.getCustomerId(),
            order.getTotalAmount(),
            order.getItems()
        );
        eventPublisher.publishEvent(event);
        
        return order;
    }
}

// 이벤트 클래스
@Data
@Builder
public class OrderCreatedEvent {
    private UUID orderId;
    private UUID customerId;
    private BigDecimal totalAmount;
    private List<OrderItem> items;
    private Instant createdAt;
}
```

**이벤트 수신 및 데이터 복제:**
```java
// Customer Service - 이벤트 수신
@Service
public class CustomerService {
    
    @EventListener
    @Async
    public void handleOrderCreated(OrderCreatedEvent event) {
        // 고객 정보에 최근 주문 정보 추가
        Customer customer = customerRepository
            .findById(event.getCustomerId())
            .orElseThrow(() -> new CustomerNotFoundException());
        
        customer.setLastOrderDate(event.getCreatedAt());
        customer.incrementOrderCount();
        customer.addRecentOrder(event.getOrderId());
        
        customerRepository.save(customer);
    }
}
```

**Kafka 이벤트 설정:**
```java
// Kafka Producer 설정
@Configuration
@EnableKafka
public class KafkaConfig {
    
    @Bean
    public ProducerFactory<String, Object> producerFactory() {
        Map<String, Object> config = new HashMap<>();
        config.put(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, "localhost:9092");
        config.put(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, StringSerializer.class);
        config.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, JsonSerializer.class);
        return new DefaultKafkaProducerFactory<>(config);
    }
    
    @Bean
    public KafkaTemplate<String, Object> kafkaTemplate() {
        return new KafkaTemplate<>(producerFactory());
    }
}

// 이벤트 발행
@Service
public class EventPublisherService {
    
    @Autowired
    private KafkaTemplate<String, Object> kafkaTemplate;
    
    public void publishOrderCreated(OrderCreatedEvent event) {
        kafkaTemplate.send("order-events", event);
    }
}
```

**장점:**
- 서비스 간 느슨한 결합
- 높은 성능과 확장성
- 이벤트 소스로 재처리 가능

**단점:**
- 최종 일관성(Eventual Consistency)
- 이벤트 순서 보장 복잡
- 중복 이벤트 처리 필요

---

#### 3. 데이터 복제 패턴

**Read Replica 패턴:**
```java
// 여러 서비스에서 참조하는 데이터 복제
@Service
public class ProductReplicationService {
    
    @Scheduled(fixedDelay = 300000) // 5분마다
    public void replicateProductData() {
        // Product Service에서 최신 상품 정보 조회
        List<Product> products = productClient.getAllProducts();
        
        // 로컬 캐시 또는 Read DB에 저장
        products.forEach(product -> {
            productCache.put(product.getId(), product);
            localProductRepository.save(product);
        });
    }
}
```

**CDC (Change Data Capture):**
```java
// Debezium을 이용한 DB 변경 감지
@Configuration
public class CDCConfig {
    
    @Bean
    public io.debezium.config.Configuration connectorConfig() {
        return io.debezium.config.Configuration.create()
            .with("connector.class", "io.debezium.connector.postgresql.PostgresConnector")
            .with("database.hostname", "localhost")
            .with("database.port", "5432")
            .with("database.user", "debezium")
            .with("database.password", "dbz")
            .with("database.dbname", "orders")
            .with("database.server.name", "orders-cdc")
            .with("table.include.list", "public.orders,public.order_items")
            .build();
    }
}
```

---

### 🔄 데이터 일관성 전략

#### 1. Saga 패턴을 통한 분산 트랜잭션

**Choreography 방식:**
```mermaid
sequenceDiagram
    participant Order as Order Service
    participant Kafka
    participant Payment as Payment Service
    participant Inventory as Inventory Service
    participant Notification as Notification Service

    Order->>Kafka: OrderCreated
    Kafka->>Payment: ProcessPayment
    Payment->>Kafka: PaymentCompleted/PaymentFailed
    
    alt PaymentCompleted
        Kafka->>Inventory: ReserveInventory
        Inventory->>Kafka: InventoryReserved/InventoryFailed
        
        alt InventoryReserved
            Kafka->>Notification: SendOrderConfirmation
        else InventoryFailed
            Kafka->>Order: CancelOrder
        end
    else PaymentFailed
        Kafka->>Order: CancelOrder
    end
```

**보상 트랜잭션:**
```java
// 보상 트랜잭션 구현
@Service
public class OrderService {
    
    @EventListener
    public void handlePaymentFailed(PaymentFailedEvent event) {
        // 결제 실패 시 주문 취소
        Order order = orderRepository.findById(event.getOrderId())
            .orElseThrow(() -> new OrderNotFoundException());
        
        order.setStatus(OrderStatus.CANCELLED);
        order.setCancellationReason("Payment failed: " + event.getReason());
        orderRepository.save(order);
        
        // 보상 이벤트 발행
        eventPublisher.publishEvent(new OrderCancelledEvent(
            event.getOrderId(),
            "Payment failed"
        ));
    }
    
    @EventListener
    public void handleInventoryFailed(InventoryFailedEvent event) {
        // 재고 예약 실패 시 결제 취소
        PaymentRefundRequest refund = new PaymentRefundRequest(
            event.getOrderId(),
            event.getAmount()
        );
        paymentClient.processRefund(refund);
        
        // 주문 취소
        Order order = orderRepository.findById(event.getOrderId())
            .orElseThrow(() -> new OrderNotFoundException());
        
        order.setStatus(OrderStatus.CANCELLED);
        order.setCancellationReason("Insufficient inventory");
        orderRepository.save(order);
    }
}
```

---

## 6. 장단점

### ✅ 장점

1. **서비스 독립성**
   - 각 서비스가 자신의 데이터를 완전히 제어
   - 독립적인 개발, 배포, 확장 가능
   - 기술 스택 자유도 극대화

2. **확장성**
   - 각 서비스가 자신의 데이터베이스를 독립적으로 스케일링
   - 부하 분산 및 성능 최적화
   - 리소스 사용량에 따른 비용 최적화

3. **기술 최적화**
   - 데이터 특성에 맞는 최적의 DB 기술 선택
   - 폴리글랏 퍼시스턴스 실현
   - 각 도메인의 요구사항에 맞는 솔루션

4. **장애 격리**
   - 한 서비스의 DB 장애가 다른 서비스에 영향 최소화
   - 시스템 전체의 가용성 향상
   - 장애 범위 제한 및 복구 용이

5. **보안 강화**
   - 데이터 접근 경계 명확화
   - 세분화된 접근 제어 정책 적용
   - 감사 추적 및 규제 준수 용이

### ❌ 단점

1. **데이터 일관성 복잡성**
   - 분산 트랜잭션 관리 어려움
   - 최종 일관성 수용 필요
   - 데이터 동기화 로직 복잡

2. **조인 쿼리 불가**
   - 서비스 간 데이터 조인 직접 불가
   - API 호출을 통한 데이터 조합 필요
   - 성능 저하 및 복잡성 증가

3. **운영 오버헤드**
   - 다수의 데이터베이스 관리 필요
   - 모니터링, 백업, 복구 대상 증가
   - 운영 비용 증가

4. **데이터 중복**
   - 참조 데이터의 중복 저장 가능성
   - 데이터 불일치 위험
   - 동기화 전략 필요

5. **쿼리 복잡성**
   - 복잡한 비즈니스 쿼리 구현 어려움
   - 여러 서비스의 데이터 조합 필요
   - 성능 최적화 복잡

---

## 7. 사용 시기

### ✅ 적합한 경우

1. **마이크로서비스 아키텍처**
   - 서비스 간 명확한 도메인 경계
   - 독립적인 팀 구조
   - 개별 서비스 스케일링 필요

2. **다양한 데이터 요구사항**
   - 관계형 데이터, 문서 데이터, 시계열 데이터 혼재
   - 각 도메인의 특수한 데이터 요구사항
   - 폴리글랏 퍼시스턴스 필요

3. **높은 확장성 요구**
   - 각 서비스의 다른 성장 속도
   - 부하 분산 필요
   - 독립적인 리소스 관리

4. **강력한 보안 요구**
   - 데이터 접근 경계 명확화 필요
   - 규제 준수 (GDPR, HIPAA 등)
   - 세분화된 접근 제어

5. **팀 자율성 중시**
   - 각 팀이 자신의 기술 스택 선택
   - 독립적인 개발 및 배포 주기
   - 빠른 혁신과 실험 필요

### ❌ 부적합한 경우

1. **단일 데이터베이스로 충분**
   - 단순한 CRUD 기반 애플리케이션
   - 강한 일관성이 필수적
   - 복잡한 서비스 간 조인 필요

2. **소규모 팀/프로젝트**
   - 운영 오버헤드 > 이점
   - 단순한 아키텍처 선호
   - 제한된 리소스 환경

3. **실시간 강한 일관성 요구**
   - 금융 거래 시스템 등
   - ACID 트랜잭션 필수
   - 데이터 일관성이 비즈니스 핵심

4. **단일 팀 운영**
   - 팀 간 협업 오버헤드 작음
   - 통합된 데이터 관리 용이
   - 단일 기술 스택 선호

---

## 8. 2026년 표준 스택

### 🏆 추천 구성

```
┌─────────────────────────────────────────────────────────────┐
│                Service Mesh (Istio)                 │
│              (Communication, Security)            │
└─────────────────────┬─────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│               API Gateway (Kong/Ambassador)          │
│            (Authentication, Routing)            │
└─────────────────────┬─────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│               Business Services                     │
│                                                     │
│  ┌─────────────────┐  ┌─────────────────┐            │
│  │  Order Service │  │ Payment Service │            │
│  │  (Spring Boot) │  │ (Node.js)      │            │
│  └─────────────────┘  └─────────────────┘            │
│           │                    │                      │
│           └─────────┬──────────┘                      │
│                     │                              │
│  ┌─────────────────┐  ┌─────────────────┐            │
│  │Inventory Service│  │Customer Service│            │
│  │   (Go)         │  │  (Python)      │            │
│  └─────────────────┘  └─────────────────┘            │
└─────────────────────┬─────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│               Data Layer (Polyglot)                 │
│                                                     │
│  ┌─────────────────┐  ┌─────────────────┐            │
│  │  PostgreSQL    │  │    MongoDB      │            │
│  │  (ACID, Join)  │  │  (Documents)   │            │
│  └─────────────────┘  └─────────────────┘            │
│                                                     │
│  ┌─────────────────┐  ┌─────────────────┐            │
│  │     Redis      │  │  Elasticsearch │            │
│  │  (Cache, Real) │  │  (Search)      │            │
│  └─────────────────┘  └─────────────────┘            │
└─────────────────────────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────┐
│               Infrastructure                     │
│                                                     │
│  ┌─────────────────┐  ┌─────────────────┐            │
│  │    Kafka       │  │   Prometheus   │            │
│  │  (Events)      │  │ (Monitoring)   │            │
│  └─────────────────┘  └─────────────────┘            │
│                                                     │
│  ┌─────────────────┐  ┌─────────────────┐            │
│  │    Jaeger      │  │   Grafana      │            │
│  │ (Tracing)      │  │ (Dashboard)    │            │
│  └─────────────────┘  └─────────────────┘            │
└─────────────────────────────────────────────────────────────┘
```

### 📦 주요 도구

#### 1. 관계형 데이터베이스

**PostgreSQL (표준 선택)**
- 버전: 15+
- 특징: ACID, JSON 지원, 확장성
- 사용 사례: 주문, 회원, 재고 관리

**MySQL (대안)**
- 버전: 8.0+
- 특징: 성능, 생태계, 호환성

#### 2. NoSQL 데이터베이스

**MongoDB (문서 데이터)**
- 버전: 6.0+
- 특징: 스키마 유연성, 스케일링
- 사용 사례: 프로필, 설정, 로그

**Redis (키-밸류/캐시)**
- 버전: 7.0+
- 특징: 인메모리, 빠른 속도
- 사용 사례: 세션, 캐시, 실시간 데이터

**Elasticsearch (검색)**
- 버전: 8.0+
- 특징: 전문 검색, 분석
- 사용 사례: 상품 검색, 로그 분석

#### 3. 시계열 데이터베이스

**InfluxDB (시계열)**
- 버전: 2.0+
- 특징: 시계열 데이터 최적화
- 사용 사례: 모니터링, IoT

**TimescaleDB (PostgreSQL 확장)**
- 버전: 2.0+
- 특징: PostgreSQL 호환, 시계열

#### 4. 이벤트 브로커

**Apache Kafka (표준)**
- 버전: 3.5+
- 특징: 높은 처리량, 영속성
- 사용 사례: 이벤트 스트리밍

**RabbitMQ (대안)**
- 버전: 3.12+
- 특징: 간단한 설정, 라우팅

---

### 🚀 2026년 트렌드

1. **데이터 메시 (Data Mesh)**
   - 분산된 데이터 아키텍처 패러다임
   - 데이터 도메인별 소유권
   - 자율적인 데이터 제품

2. **서버리스 데이터베이스**
   - AWS Aurora Serverless
   - Google Cloud Firestore
   - Azure Cosmos DB Serverless

3. **AI 기반 데이터 최적화**
   - 자동 인덱싱
   - 쿼리 최적화
   - 성능 예측

4. **멀티 클라우드 데이터베이스**
   - 크로스 클라우드 복제
   - 글로벌 분산 데이터베이스
   - 엣지 컴퓨팅 통합

---

## 9. 실전 사례

### 🏢 실제 기업 사례

#### Netflix

**아키텍처:**
```
Video Playback Service
  ↓ DynamoDB (시청 기록)
  
Recommendation Service
  ↓ Cassandra (추천 데이터)
  
User Profile Service
  ↓ PostgreSQL (회원 정보)
  
Content Catalog Service
  ↓ Elasticsearch (콘텐츠 검색)
```

**특징:**
- 각 서비스별 최적화된 DB 선택
- 글로벌 분산 데이터베이스
- 높은 가용성과 성능

**성과:**
- 각 서비스 독립적 스케일링으로 99.99% 가용성 달성
- 데이터 특성에 맞는 DB 선택으로 40% 성능 향상
- 장애 격리로 전체 시스템 안정성 확보

#### Uber

**아키텍처:**
```
Ride Service
  ↓ PostgreSQL (주행 데이터)
  
Payment Service
  ↓ MongoDB (결제 기록)
  
Matching Service
  ↓ Redis (실시간 매칭)
  
Geospatial Service
  ↓ PostGIS (위치 데이터)
```

**특징:**
- 지리적 데이터에 최적화된 PostGIS
- 실시간 매칭을 위한 Redis
- 유연한 결제 데이터를 위한 MongoDB

---

#### Amazon

**아키텍처:**
```
Order Service
  ↓ Aurora (주문 데이터)
  
Product Service
  ↓ DynamoDB (상품 정보)
  
Search Service
  ↓ Elasticsearch (상품 검색)
  
Recommendation Service
  ↓ S3 + ML (추천 모델)
```

**특징:**
- AWS 서비스 활용 극대화
- 각 도메인별 최적화된 데이터 솔루션
- 서버리스 아키텍처 통합

### 📊 성능 데이터

**Database per Service 도입 전후 비교:**

| 메트릭 | 도입 전 | 도입 후 | 개선율 |
|--------|--------|--------|--------|
| **서비스 독립성** | 20% | 95% | 375% ↑ |
| **배포 속도** | 2주 | 2일 | 86% ↓ |
| **장애 전파** | 전체 시스템 | 단일 서비스 | 90% ↓ |
| **DB 스케일링** | 전체 | 개별 | 유연성 ↑ |
| **기술 선택 자유도** | 1개 | 5개 | 400% ↑ |
| **운영 복잡도** | 낮음 | 높음 | +150% |

---

## 📚 참고 자료

### 🔗 관련 패턴

- [[CQRS-패턴|CQRS 패턴]] - 읽기/쓰기 분리로 데이터 접근 최적화
- [[Saga-패턴|Saga 패턴]] - 분산 트랜잭션 관리
- [[../01-통신-패턴/Event-Driven-Architecture|Event-Driven Architecture]] - 비동기 데이터 동기화
- [[../03-복원력-패턴/Circuit-Breaker-패턴|Circuit Breaker 패턴]] - 장애 격리

### 📖 추가 학습 자료

- [Designing Data-Intensive Applications - Martin Kleppmann](https://dataintensive.net/)
- [Microservices Patterns - Chris Richardson](https://microservices.io/patterns/data/database-per-service.html)
- [Building Microservices - Sam Newman](https://www.oreilly.com/library/view/building-microservices/9781491950340/)
- [Data Mesh Principles - Zhamak Dehghani](https://martinfowler.com/articles/data-monolith-to-mesh.html)

---

**상위 문서**: [[_README|데이터 관리 패턴 폴더]]
**마지막 업데이트**: 2026-01-02
**다음 학습**: [[CQRS-패턴|CQRS 패턴]]
