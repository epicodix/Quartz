---
title: Bulkhead 패턴 - 리소스 격리로 장애 제한
tags:
  - MSA
  - bulkhead
  - isolation
  - thread-pool
  - resilience4j
  - fault-tolerance
aliases:
  - 격벽 패턴
  - Resource Isolation
date: 2026-01-05
category: MSA-디자인-패턴/03-복원력-패턴
status: 완성
priority: 높음
difficulty: 중급
related:
  - "[[서킷브레이커-패턴|Circuit Breaker 패턴]]"
  - "[[Rate-Limiter-패턴|Rate Limiter 패턴]]"
  - "[[Timeout-패턴|Timeout 패턴]]"
prerequisites:
  - "[[서킷브레이커-패턴|Circuit Breaker 패턴]]"
next_steps:
  - "[[Retry-패턴|Retry 패턴]]"
---

# 🛡️ Bulkhead 패턴

> [!note] 패턴 개요
> Bulkhead는 배의 격벽처럼 **리소스를 격리**하여 한 부분의 장애가 전체로 확산되는 것을 방지하는 패턴입니다. 스레드 풀, 커넥션 풀 등을 분리하여 장애 영향 범위를 제한합니다.

> [!tip] 중요도: ⭐⭐⭐ 필수 패턴
> Circuit Breaker와 함께 사용하여 시스템의 복원력을 극대화합니다.

---

## 📑 목차

- [[#1. 핵심 개념|핵심 개념]]
- [[#2. 문제와 해결|문제와 해결]]
- [[#3. Bulkhead 유형|Bulkhead 유형]]
- [[#4. 실제 구현|실제 구현]]
- [[#5. 장단점|장단점]]
- [[#6. 사용 시기|사용 시기]]

---

## 1. 핵심 개념

### 🎯 배의 격벽 비유

```
배의 구조 (Bulkhead 없음):
┌─────────────────────────────────┐
│                                 │
│   하나의 공간 (전체 침수 위험)    │
│                                 │
└─────────────────────────────────┘
       구멍 → 전체 침몰!

배의 구조 (Bulkhead 있음):
┌────┬────┬────┬────┬────┐
│ 1  │ 2  │ 3  │ 4  │ 5  │ ← 격벽으로 분리
└────┴────┴────┴────┴────┘
       구멍 → 1번만 침수, 나머지 안전!
```

### 📊 시스템 적용

**Bulkhead 없음 (위험):**
```
공용 스레드 풀 (200개):
┌────────────────────────────────┐
│ Payment API: 180개 스레드 대기  │ ← 느린 API가 전체 독점
│ User API: 10개 스레드 대기      │
│ Product API: 10개 스레드 대기   │
│ Available: 0개                 │
└────────────────────────────────┘
→ 모든 API 마비!
```

**Bulkhead 적용 (안전):**
```
격리된 스레드 풀:
┌─────────────────────────────────┐
│ Payment Pool: 50개 (50개 대기)  │ ← 격리됨
├─────────────────────────────────┤
│ User Pool: 75개 (30개 사용 중)  │ ← 정상 동작
├─────────────────────────────────┤
│ Product Pool: 75개 (20개 사용 중)│ ← 정상 동작
└─────────────────────────────────┘
→ Payment만 영향, 나머지 정상!
```

---

## 2. 문제와 해결

### 🚨 해결하려는 문제

#### 문제: 리소스 독점으로 인한 전체 장애

> [!example] 실제 장애 시나리오
> **상황**: E-Commerce 시스템, 결제 API 응답 시간 10초로 증가
>
> **장애 전파**:
> 1. 09:00 - 결제 API 느려짐 (10초)
> 2. 09:01 - 전체 스레드 200개가 결제 대기
> 3. 09:02 - 상품 조회, 사용자 정보 API도 스레드 없어 마비
> 4. 09:03 - 전체 서비스 다운
>
> **피해**:
> - 모든 기능 중단
> - 고객 이탈
> - 매출 손실

### ✅ Bulkhead의 해결

```
09:00 - 결제 API 느려짐
09:01 - 결제 Pool 50개 스레드만 대기 (격리!)
09:02 - 상품/사용자 API는 자체 Pool로 정상 동작 ✅
09:03 - 결제 외 기능 모두 정상

피해 최소화:
- 결제만 일시 중단
- 다른 기능은 정상
- 고객 이탈 방지
```

---

## 3. Bulkhead 유형

### 1. Thread Pool Bulkhead (스레드 풀 격리)

```java
// Resilience4j 설정
resilience4j.bulkhead:
  instances:
    paymentService:
      maxConcurrentCalls: 50        # 최대 동시 호출 50개
      maxWaitDuration: 500ms        # 대기 시간 500ms

    userService:
      maxConcurrentCalls: 100
      maxWaitDuration: 100ms
```

```java
@Service
public class PaymentService {

    @Bulkhead(name = "paymentService", type = Bulkhead.Type.THREADPOOL)
    public CompletableFuture<Payment> processPayment(PaymentRequest request) {
        return CompletableFuture.supplyAsync(() -> {
            return paymentGateway.charge(request);
        });
    }
}
```

---

### 2. Semaphore Bulkhead (세마포어 격리)

```java
resilience4j.bulkhead:
  instances:
    productService:
      maxConcurrentCalls: 100       # 최대 동시 호출 제한
      maxWaitDuration: 0ms          # 대기 없이 즉시 실패
```

```java
@Bulkhead(name = "productService", type = Bulkhead.Type.SEMAPHORE)
public Product getProduct(String productId) {
    return productRepository.findById(productId);
}
```

**차이점:**

| 특징 | Thread Pool | Semaphore |
|------|-------------|-----------|
| **스레드** | 별도 스레드 풀 사용 | 호출 스레드 사용 |
| **성능** | 스레드 전환 오버헤드 | 빠름 (오버헤드 없음) |
| **격리** | 강력 (완전 격리) | 약함 (카운트만 제한) |
| **비용** | 높음 (스레드 생성) | 낮음 |
| **사용처** | 외부 API 호출 | 내부 서비스 호출 |

---

## 4. 실제 구현

### 💻 Resilience4j Bulkhead

**의존성:**
```xml
<dependency>
    <groupId>io.github.resilience4j</groupId>
    <artifactId>resilience4j-bulkhead</artifactId>
</dependency>
```

**설정 (application.yml):**
```yaml
resilience4j:
  thread-pool-bulkhead:
    instances:
      paymentService:
        maxThreadPoolSize: 50          # 최대 스레드 50개
        coreThreadPoolSize: 25         # 기본 스레드 25개
        queueCapacity: 100             # 대기 큐 100개
        keepAliveDuration: 60s         # 유휴 스레드 유지 시간

  bulkhead:
    instances:
      userService:
        maxConcurrentCalls: 100
        maxWaitDuration: 100ms
```

**사용 예시:**
```java
@Service
public class OrderService {

    @Autowired
    private PaymentClient paymentClient;

    @Autowired
    private UserClient userClient;

    // Thread Pool Bulkhead (외부 API)
    @Bulkhead(name = "paymentService", type = Bulkhead.Type.THREADPOOL,
              fallbackMethod = "paymentFallback")
    public CompletableFuture<Payment> processPayment(OrderRequest order) {
        return CompletableFuture.supplyAsync(() ->
            paymentClient.charge(order.getAmount())
        );
    }

    private CompletableFuture<Payment> paymentFallback(OrderRequest order, BulkheadFullException ex) {
        return CompletableFuture.completedFuture(
            Payment.pending("서비스 혼잡, 잠시 후 다시 시도해주세요")
        );
    }

    // Semaphore Bulkhead (내부 서비스)
    @Bulkhead(name = "userService", type = Bulkhead.Type.SEMAPHORE)
    public User getUser(String userId) {
        return userClient.getUserById(userId);
    }
}
```

---

### 🔄 이벤트 리스너

```java
@Component
public class BulkheadEventListener {

    @PostConstruct
    public void registerEventListeners() {
        bulkheadRegistry.getAllBulkheads().forEach(bulkhead -> {
            bulkhead.getEventPublisher()
                .onCallPermitted(this::onCallPermitted)
                .onCallRejected(this::onCallRejected)
                .onCallFinished(this::onCallFinished);
        });
    }

    private void onCallPermitted(BulkheadOnCallPermittedEvent event) {
        log.debug("Bulkhead [{}] - Call permitted", event.getBulkheadName());
    }

    private void onCallRejected(BulkheadOnCallRejectedEvent event) {
        log.warn("⚠️ Bulkhead [{}] - Call rejected! (Full)", event.getBulkheadName());
        alertService.sendAlert("Bulkhead Full: " + event.getBulkheadName());
    }

    private void onCallFinished(BulkheadOnCallFinishedEvent event) {
        log.debug("Bulkhead [{}] - Call finished, duration={}ms",
            event.getBulkheadName(),
            event.getElapsedDuration().toMillis());
    }
}
```

---

### 📊 메트릭

```java
@RestController
@RequestMapping("/actuator/bulkhead")
public class BulkheadMetricsController {

    @Autowired
    private BulkheadRegistry bulkheadRegistry;

    @GetMapping
    public Map<String, Object> getBulkheadMetrics() {
        Map<String, Object> metrics = new HashMap<>();

        bulkheadRegistry.getAllBulkheads().forEach(bulkhead -> {
            Bulkhead.Metrics m = bulkhead.getMetrics();

            Map<String, Object> bulkheadMetrics = new HashMap<>();
            bulkheadMetrics.put("availableConcurrentCalls", m.getAvailableConcurrentCalls());
            bulkheadMetrics.put("maxAllowedConcurrentCalls", m.getMaxAllowedConcurrentCalls());

            metrics.put(bulkhead.getName(), bulkheadMetrics);
        });

        return metrics;
    }
}
```

---

## 5. 장단점

### ✅ 장점

1. **장애 격리**
   - 한 서비스 장애가 다른 서비스에 영향 없음

2. **예측 가능한 성능**
   - 리소스 보장
   - SLA 준수 용이

3. **우선순위 지정**
   - 중요한 서비스에 더 많은 리소스 할당

### ❌ 단점

1. **리소스 낭비**
   - 유휴 리소스 존재 가능

2. **설정 복잡도**
   - 적절한 크기 결정 어려움

3. **오버헤드**
   - Thread Pool 사용 시 성능 비용

---

## 6. 사용 시기

### ✅ 적합한 경우

1. **외부 API 호출**
   - 느린 API 격리

2. **다양한 SLA**
   - 서비스마다 다른 성능 요구사항

3. **공유 리소스**
   - DB 커넥션 풀, HTTP 클라이언트

### ❌ 부적합한 경우

1. **리소스 충분**
   - 오버헤드만 증가

2. **단일 서비스**
   - 격리 불필요

---

## 📚 참고 자료

- [[서킷브레이커-패턴|Circuit Breaker 패턴]]
- [[Rate-Limiter-패턴|Rate Limiter 패턴]]

---

**상위 문서**: [[_README|복원력 패턴 폴더]]
**마지막 업데이트**: 2026-01-05

<br>
<div align="right" style="font-size: 0.8em; color: gray; opacity: 0.6;">
  Supported by Sonnet 4.5
</div>