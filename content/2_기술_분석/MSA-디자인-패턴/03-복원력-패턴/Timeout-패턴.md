---
title: Timeout 패턴 - 무한 대기 방지
tags:
  - MSA
  - timeout
  - resilience4j
  - fault-tolerance
aliases:
  - 타임아웃 패턴
date: 2026-01-05
category: MSA-디자인-패턴/03-복원력-패턴
status: 완성
priority: 높음
difficulty: 초급
related:
  - "[[서킷브레이커-패턴|Circuit Breaker 패턴]]"
  - "[[Retry-패턴|Retry 패턴]]"
---

# ⏱️ Timeout 패턴

> [!note] 패턴 개요
> Timeout은 **무한 대기를 방지**하기 위해 최대 대기 시간을 설정하는 패턴입니다. 느린 응답으로 인한 리소스 낭비와 연쇄 장애를 방지합니다.

---

## 1. 핵심 개념

### 🚨 Timeout 없는 시스템의 위험

```
요청 → 외부 API 호출 → (응답 없음, 무한 대기)
↓
스레드 블로킹
↓
스레드 풀 고갈
↓
전체 서비스 마비
```

### ✅ Timeout 적용

```
요청 → 외부 API 호출 → 3초 대기 → TimeoutException
                              ↓
                         즉시 Fallback
                              ↓
                         스레드 반환
```

---

## 2. Timeout 유형

### 1. Connection Timeout (연결 타임아웃)

```yaml
# RestTemplate 설정
spring:
  rest:
    connection-timeout: 2000  # 2초
```

```java
@Bean
public RestTemplate restTemplate() {
    SimpleClientHttpRequestFactory factory = new SimpleClientHttpRequestFactory();
    factory.setConnectTimeout(2000);  // 연결 타임아웃 2초
    factory.setReadTimeout(5000);     // 읽기 타임아웃 5초
    return new RestTemplate(factory);
}
```

### 2. Read Timeout (읽기 타임아웃)

```java
@TimeLimiter(name = "paymentService")
public CompletableFuture<Payment> processPayment(PaymentRequest request) {
    return CompletableFuture.supplyAsync(() ->
        paymentClient.charge(request)
    );
}
```

```yaml
resilience4j.timelimiter:
  instances:
    paymentService:
      timeoutDuration: 3s
      cancelRunningFuture: true
```

---

## 3. 적절한 Timeout 설정

### 📊 Timeout 계산

```
Timeout = P95 응답 시간 + 버퍼

예시:
- P95 응답 시간: 500ms
- 버퍼: 500ms
→ Timeout: 1000ms (1초)
```

### 🎯 서비스별 Timeout 전략

| 서비스 | Connection | Read | 이유 |
|--------|-----------|------|------|
| **내부 서비스** | 100ms | 1s | 빠른 응답 기대 |
| **외부 API** | 2s | 5s | 느린 네트워크 |
| **DB 쿼리** | 100ms | 3s | 복잡한 쿼리 허용 |
| **결제 API** | 1s | 10s | 중요하지만 느림 |

---

## 4. 실제 구현

### 💻 Resilience4j TimeLimiter

```java
@Service
public class PaymentService {

    @TimeLimiter(name = "payment", fallbackMethod = "paymentFallback")
    @CircuitBreaker(name = "payment")
    public CompletableFuture<Payment> charge(PaymentRequest request) {
        return CompletableFuture.supplyAsync(() ->
            paymentGateway.charge(request)
        );
    }

    private CompletableFuture<Payment> paymentFallback(
        PaymentRequest request,
        TimeoutException ex
    ) {
        log.error("Payment timeout after {}s", timeoutDuration);
        return CompletableFuture.completedFuture(
            Payment.failed("결제 처리 시간 초과")
        );
    }
}
```

### 🌐 WebClient (Reactive)

```java
@Bean
public WebClient webClient() {
    HttpClient httpClient = HttpClient.create()
        .option(ChannelOption.CONNECT_TIMEOUT_MILLIS, 2000)
        .responseTimeout(Duration.ofSeconds(5));

    return WebClient.builder()
        .clientConnector(new ReactorClientHttpConnector(httpClient))
        .build();
}

// 사용
webClient.get()
    .uri("/api/data")
    .retrieve()
    .bodyToMono(Data.class)
    .timeout(Duration.ofSeconds(3))  // 추가 타임아웃
    .onErrorResume(TimeoutException.class, ex ->
        Mono.just(Data.empty())
    );
```

---

## 5. 주의사항

### ⚠️ Timeout 체인

```
Client → API Gateway → Service A → Service B
  (5s)      (4s)         (3s)        (2s)

규칙: 각 계층의 Timeout은 하위보다 길어야 함
Client(5s) > Gateway(4s) > ServiceA(3s) > ServiceB(2s)
```

### 🔄 Retry와 함께 사용

```yaml
resilience4j:
  retry:
    instances:
      payment:
        maxAttempts: 3
        waitDuration: 1s

  timelimiter:
    instances:
      payment:
        timeoutDuration: 5s

# 전체 시간 = 5s (timeout) × 3 (retry) = 15s
```

---

## 6. 장단점

### ✅ 장점

1. **리소스 보호**
   - 스레드 낭비 방지
   - 무한 대기 차단

2. **예측 가능성**
   - 최대 응답 시간 보장
   - SLA 준수

### ❌ 단점

1. **설정 어려움**
   - 적절한 값 결정 복잡

2. **조기 종료 위험**
   - 정상 요청도 취소 가능

---

## 📚 참고 자료

- [[서킷브레이커-패턴|Circuit Breaker 패턴]]
- [[Retry-패턴|Retry 패턴]]

---

**상위 문서**: [[_README|복원력 패턴 폴더]]
**마지막 업데이트**: 2026-01-05
