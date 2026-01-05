---
title: Retry 패턴 - 일시적 장애 자동 복구
tags:
  - MSA
  - retry
  - resilience4j
  - backoff
  - fault-tolerance
aliases:
  - 재시도 패턴
  - Automatic Retry
date: 2026-01-05
category: MSA-디자인-패턴/03-복원력-패턴
status: 완성
priority: 중간
difficulty: 초급
related:
  - "[[서킷브레이커-패턴|Circuit Breaker 패턴]]"
  - "[[Timeout-패턴|Timeout 패턴]]"
prerequisites:
  - "[[서킷브레이커-패턴|Circuit Breaker 패턴]]"
---

# 🔁 Retry 패턴

> [!note] 패턴 개요
> Retry 패턴은 일시적 장애(Transient Failure)가 발생했을 때 **자동으로 재시도**하여 복구하는 패턴입니다. 네트워크 일시 중단, DB 커넥션 타임아웃 등에 효과적입니다.

> [!tip] 중요도: ⭐⭐⭐ 필수 패턴
> 클라우드 환경에서 네트워크 불안정성을 해결하는 가장 기본적인 패턴입니다.

---

## 📑 목차

- [[#1. 핵심 개념|핵심 개념]]
- [[#2. Retry 전략|Retry 전략]]
- [[#3. 실제 구현|실제 구현]]
- [[#4. 주의사항|주의사항]]
- [[#5. 장단점|장단점]]

---

## 1. 핵심 개념

### 🎯 일시적 장애 vs 영구적 장애

**일시적 장애 (Retry 효과적):**
```
- 네트워크 일시 중단
- DB 커넥션 풀 고갈 (잠시 후 복구)
- 일시적 타임아웃
- 503 Service Unavailable
```

**영구적 장애 (Retry 무의미):**
```
- 404 Not Found
- 401 Unauthorized
- 비즈니스 로직 에러
- 데이터 유효성 오류
```

### 📊 Retry 흐름

```
시도 1: API 호출 → ❌ 실패 (네트워크 끊김)
  ↓ 대기 1초
시도 2: API 호출 → ❌ 실패
  ↓ 대기 2초 (Exponential Backoff)
시도 3: API 호출 → ✅ 성공!
```

---

## 2. Retry 전략

### 1. Fixed Delay (고정 지연)

```
시도 간격: 1초 - 1초 - 1초
```

```yaml
resilience4j.retry:
  instances:
    simpleRetry:
      maxAttempts: 3
      waitDuration: 1s
```

**장점**: 간단
**단점**: 서버 부하 시 비효율적

---

### 2. Exponential Backoff (지수 백오프)

```
시도 간격: 1초 - 2초 - 4초 - 8초
```

```yaml
resilience4j.retry:
  instances:
    exponentialRetry:
      maxAttempts: 5
      waitDuration: 1s
      enableExponentialBackoff: true
      exponentialBackoffMultiplier: 2
```

**장점**: 서버 부하 감소
**단점**: 재시도 시간 길어짐

---

### 3. Jitter (지터 추가)

```
시도 간격: 0.8초 - 1.9초 - 4.2초 (랜덤)
```

```yaml
resilience4j.retry:
  instances:
    jitterRetry:
      maxAttempts: 3
      waitDuration: 1s
      enableRandomizedWait: true
      randomizedWaitFactor: 0.5  # ±50% 랜덤
```

**장점**: Thundering Herd 방지
**단점**: 예측 불가능

---

## 3. 실제 구현

### 💻 Spring Retry

```xml
<dependency>
    <groupId>org.springframework.retry</groupId>
    <artifactId>spring-retry</artifactId>
</dependency>
```

```java
@Service
public class PaymentService {

    @Retryable(
        value = {SocketTimeoutException.class, IOException.class},
        maxAttempts = 3,
        backoff = @Backoff(delay = 1000, multiplier = 2)
    )
    public Payment processPayment(PaymentRequest request) {
        return paymentGateway.charge(request);
    }

    @Recover
    public Payment recover(Exception e, PaymentRequest request) {
        log.error("Payment failed after retries", e);
        return Payment.failed("결제 처리 실패");
    }
}
```

---

### 🚀 Resilience4j Retry

```yaml
resilience4j.retry:
  instances:
    paymentService:
      maxAttempts: 3
      waitDuration: 1s
      enableExponentialBackoff: true
      exponentialBackoffMultiplier: 2
      retryExceptions:
        - java.io.IOException
        - java.util.concurrent.TimeoutException
      ignoreExceptions:
        - com.example.BusinessException
```

```java
@Service
public class PaymentService {

    @Retry(name = "paymentService", fallbackMethod = "paymentFallback")
    public Payment processPayment(PaymentRequest request) {
        return paymentClient.charge(request);
    }

    private Payment paymentFallback(PaymentRequest request, Exception ex) {
        log.error("Payment failed after {} retries", ex);
        return Payment.failed("결제 서비스 일시 중단");
    }
}
```

---

### 📊 이벤트 리스너

```java
@Component
public class RetryEventListener {

    @PostConstruct
    public void registerEventListeners() {
        retryRegistry.getAllRetries().forEach(retry -> {
            retry.getEventPublisher()
                .onRetry(this::onRetry)
                .onSuccess(this::onSuccess)
                .onError(this::onError);
        });
    }

    private void onRetry(RetryOnRetryEvent event) {
        log.warn("Retry [{}] - Attempt #{}, Last exception: {}",
            event.getName(),
            event.getNumberOfRetryAttempts(),
            event.getLastThrowable().getMessage());
    }

    private void onSuccess(RetryOnSuccessEvent event) {
        log.info("Retry [{}] - Success after {} attempts",
            event.getName(),
            event.getNumberOfRetryAttempts());
    }

    private void onError(RetryOnErrorEvent event) {
        log.error("Retry [{}] - Failed after {} attempts",
            event.getName(),
            event.getNumberOfRetryAttempts());
    }
}
```

---

## 4. 주의사항

### ⚠️ 멱등성 (Idempotency) 필수

**문제:**
```java
// ❌ 멱등하지 않음 (위험!)
public void updateStock(String productId, int quantity) {
    int current = stockRepository.getQuantity(productId);
    stockRepository.setQuantity(productId, current - quantity);
    // 재시도 시 중복 차감!
}
```

**해결:**
```java
// ✅ 멱등성 보장
public void updateStock(String requestId, String productId, int quantity) {
    if (processedRequests.contains(requestId)) {
        return;  // 이미 처리됨
    }

    int current = stockRepository.getQuantity(productId);
    stockRepository.setQuantity(productId, current - quantity);
    processedRequests.add(requestId);
}
```

---

### 🚫 재시도하면 안 되는 경우

```java
resilience4j.retry:
  instances:
    safeRetry:
      ignoreExceptions:
        - java.lang.IllegalArgumentException    # 입력 검증 오류
        - com.example.BusinessException         # 비즈니스 로직 오류
        - javax.persistence.EntityNotFoundException
```

---

### ⏱️ Timeout과 함께 사용

```java
@Retry(name = "paymentService")
@TimeLimiter(name = "paymentService")  // 타임아웃 3초
public CompletableFuture<Payment> processPayment(PaymentRequest request) {
    return CompletableFuture.supplyAsync(() ->
        paymentClient.charge(request)
    );
}
```

---

## 5. 장단점

### ✅ 장점

1. **자동 복구**
   - 일시적 장애 자동 해결
   - 사용자 경험 개선

2. **간단한 구현**
   - 설정만으로 적용 가능

3. **효과 즉시**
   - 네트워크 불안정 환경에서 큰 효과

### ❌ 단점

1. **지연 시간 증가**
   - 재시도로 인한 응답 지연

2. **서버 부하**
   - 실패한 요청 반복

3. **멱등성 요구**
   - 구현 복잡도 증가

---

## 📚 참고 자료

- [[서킷브레이커-패턴|Circuit Breaker 패턴]]
- [[Timeout-패턴|Timeout 패턴]]

---

**상위 문서**: [[_README|복원력 패턴 폴더]]
**마지막 업데이트**: 2026-01-05

<br>
<div align="right" style="font-size: 0.8em; color: gray; opacity: 0.6;">
  Supported by Sonnet 4.5
</div>