---
title: 복원력 패턴 (Resilience Patterns)
tags:
  - MSA
  - resilience
  - fault-tolerance
  - reliability
date: 2026-01-02
category: MSA-디자인-패턴/03-복원력-패턴
status: 완성
---

# 🛡️ 복원력 패턴 (Resilience Patterns)

> [!note] 폴더 개요
> 이 폴더는 마이크로서비스 환경에서 장애에 대응하고 시스템 안정성을 확보하는 패턴들을 다룹니다. Circuit Breaker, Retry, Bulkhead 등 실전에서 반드시 필요한 복원력(Resilience) 패턴을 학습할 수 있습니다.

---

## 🎯 핵심 질문

**"서비스 장애 시 시스템 전체의 안정성을 어떻게 보장할 것인가?"**

분산 시스템에서 장애는 불가피합니다:
- 네트워크 지연 (Network Latency)
- 서비스 다운 (Service Outage)
- 리소스 고갈 (Resource Exhaustion)
- 연쇄 장애 (Cascading Failures)

복원력 패턴은 이러한 장애를 **격리(Isolation)** 하고 **복구(Recovery)** 하여 전체 시스템의 가용성을 유지합니다.

---

## 📚 이 폴더의 패턴들

### 1. Circuit Breaker 패턴 ⭐⭐⭐

**문서**: [[Circuit-Breaker-패턴]]

**핵심 개념**: 전기 회로 차단기처럼 장애 서비스로의 요청을 차단하여 연쇄 장애 방지

**3가지 상태**:
1. **Closed (정상)**: 요청 정상 처리
2. **Open (차단)**: 실패 임계치 초과 시 모든 요청 즉시 차단
3. **Half-Open (시험)**: 일정 시간 후 소수 요청으로 상태 확인

**언제 사용**:
- 외부 API 호출 시
- 다운스트림 서비스 장애가 업스트림에 영향을 주지 않도록
- Timeout보다 빠른 실패 필요 (Fail-Fast)

**난이도**: 중급
**중요도**: ⭐⭐⭐ 필수

**주요 라이브러리**:
- Resilience4j (Java)
- Polly (.NET)
- Hystrix (Netflix, maintenance mode)

**Service Mesh 통합**:
- Istio, Linkerd에서 Circuit Breaking 자동 제공

---

### 2. Retry & Timeout 패턴 ⭐⭐

**문서**: [[Retry-Timeout-패턴]]

**핵심 개념**: 일시적 장애 시 재시도, 무한 대기 방지를 위한 타임아웃 설정

**핵심 전략**:

1. **Exponential Backoff**: 재시도 간격을 지수적으로 증가
   ```
   1초 → 2초 → 4초 → 8초
   ```

2. **Jitter 추가**: 동시 재시도로 인한 Thundering Herd 방지
   ```
   2초 + random(0~1초)
   ```

3. **Timeout 설정**: 무한 대기 방지

**언제 사용**:
- 일시적 네트워크 장애
- 리소스 일시 고갈
- Rate Limiting에 걸린 경우

**난이도**: 초급
**중요도**: ⭐⭐

**주의사항**:
- 서비스와 사이드카가 모두 재시도 시 중복 재시도 발생
- 멱등성(Idempotency) 보장 필요

---

### 3. Bulkhead 패턴 ⭐⭐

**문서**: [[Bulkhead-패턴]]

**핵심 개념**: 배의 격벽처럼 리소스를 격리하여 한 부분의 장애가 전체로 번지지 않도록 방지

**Thread Pool Isolation**:
```
Service A
  ├── Thread Pool for Service B (10 threads)
  ├── Thread Pool for Service C (5 threads)
  └── Thread Pool for Service D (15 threads)

Service B가 느려져도 C, D는 정상 동작
```

**언제 사용**:
- 여러 다운스트림 서비스 호출
- 특정 서비스의 지연이 전체 리소스 고갈로 이어지는 것 방지
- 중요도에 따라 리소스 할당 차별화

**난이도**: 중급
**중요도**: ⭐⭐

**구현 방법**:
- Thread Pool Isolation (Resilience4j, Hystrix)
- Semaphore Isolation (경량)

---

## 🗺️ 학습 순서 추천

```mermaid
graph LR
    A[Retry & Timeout] --> B[Circuit Breaker]
    B --> C[Bulkhead]
    C --> D[Service Mesh 통합]
```

### 1단계: Retry & Timeout (기초)

**먼저 학습해야 하는 이유**:
- 가장 기본적이고 직관적
- Circuit Breaker의 기초가 됨

**학습 시간**: 1-2일

---

### 2단계: Circuit Breaker (핵심)

**반드시 학습해야 하는 이유**:
- 연쇄 장애 방지의 핵심
- 대부분의 MSA에서 필수

**학습 시간**: 3-5일

---

### 3단계: Bulkhead (고급)

**필요 시 학습**:
- 리소스 격리가 필요한 경우
- 여러 서비스 호출 시

**학습 시간**: 2-3일

---

## 📊 패턴 비교

| 항목 | Circuit Breaker | Retry & Timeout | Bulkhead |
|------|-----------------|-----------------|----------|
| **목적** | 장애 전파 차단 | 일시적 장애 극복 | 리소스 격리 |
| **복잡도** | 중간 | 낮음 | 중간 |
| **적용 시점** | 다운스트림 장애 | 일시적 네트워크 장애 | 리소스 경합 |
| **Fail-Fast** | ✅ | ❌ | 부분적 |
| **리소스 보호** | ❌ | ❌ | ✅ |
| **학습 곡선** | 중간 | 완만 | 중간 |
| **사용 빈도** | 매우 높음 | 높음 | 중간 |

---

## 🔗 패턴 조합 전략

### 조합 1: Circuit Breaker + Retry ⭐⭐⭐

**가장 일반적인 조합**

```
Request → Retry (최대 3회)
            ↓
      Circuit Breaker
            ↓
      Downstream Service
```

**동작 순서**:
1. Retry가 먼저 재시도 (일시적 장애 대응)
2. 지속적 실패 시 Circuit Breaker가 차단 (Fail-Fast)

**주의사항**:
- Retry 횟수 * Circuit Breaker 임계치 = 실제 실패 횟수
- 과도한 재시도 방지 필요

**관련 문서**:
- [[Circuit-Breaker-패턴]]
- [[Retry-Timeout-패턴]]

---

### 조합 2: Circuit Breaker + Bulkhead

**리소스 보호 + 장애 격리**

```
Thread Pool A (10 threads) → Circuit Breaker → Service A
Thread Pool B (5 threads) → Circuit Breaker → Service B
```

**장점**:
- Service A 장애 시 Thread Pool A만 영향
- Circuit Breaker로 빠른 실패 처리

**관련 문서**:
- [[Circuit-Breaker-패턴]]
- [[Bulkhead-패턴]]

---

### 조합 3: 전체 복원력 스택

**Service Mesh 환경**

```
Retry (Sidecar)
  ↓
Circuit Breaker (Sidecar)
  ↓
Timeout (Sidecar)
  ↓
Bulkhead (Application)
```

**구현**:
- Istio/Linkerd: Retry, Circuit Breaker, Timeout 자동 제공
- Application: Bulkhead는 애플리케이션 레벨에서 구현

---

## 💡 실전 적용 가이드

### 시나리오 1: 외부 API 호출

**요구사항**:
- 외부 결제 API 호출
- API 장애 시 전체 시스템 다운 방지

**추천 패턴**:
1. **Timeout**: 5초 (외부 API 응답 보장 안 됨)
2. **Retry**: 최대 3회, Exponential Backoff
3. **Circuit Breaker**: 50% 이상 실패 시 30초간 차단
4. **Fallback**: 캐시된 결과 또는 기본값 반환

**설정 예시 (Resilience4j)**:
```yaml
resilience4j:
  circuitbreaker:
    instances:
      payment-api:
        failure-rate-threshold: 50
        wait-duration-in-open-state: 30s
        sliding-window-size: 10
  retry:
    instances:
      payment-api:
        max-attempts: 3
        wait-duration: 1s
        exponential-backoff-multiplier: 2
```

---

### 시나리오 2: 내부 서비스 호출

**요구사항**:
- 마이크로서비스 간 호출
- 특정 서비스 장애가 전체 시스템에 영향 없도록

**추천 패턴**:
1. **Service Mesh**: Istio로 Circuit Breaker 자동 적용
2. **Bulkhead**: 중요 서비스에 더 많은 스레드 할당
3. **Timeout**: 서비스별 SLA에 맞춰 설정

**Istio 설정 예시**:
```yaml
apiVersion: networking.istio.io/v1
kind: DestinationRule
metadata:
  name: payment-service
spec:
  host: payment-service
  trafficPolicy:
    connectionPool:
      tcp:
        maxConnections: 100
      http:
        http1MaxPendingRequests: 50
        maxRequestsPerConnection: 2
    outlierDetection:
      consecutiveErrors: 5
      interval: 30s
      baseEjectionTime: 30s
```

---

### 시나리오 3: 대규모 트래픽 처리

**요구사항**:
- 블랙프라이데이 같은 트래픽 급증
- 리소스 고갈 방지

**추천 패턴**:
1. **Bulkhead**: VIP 사용자와 일반 사용자 스레드 풀 분리
2. **Rate Limiting**: API Gateway에서 적용
3. **Circuit Breaker**: 다운스트림 서비스 보호

**아키텍처**:
```
API Gateway (Rate Limiting)
  ↓
Service A
  ├── VIP Thread Pool (20 threads)
  └── Normal Thread Pool (10 threads)
        ↓
    Circuit Breaker
        ↓
    Service B
```

---

## ⚠️ 안티패턴 주의

### 1. 중복 재시도 (Retry Storm)

**문제**:
```
Client Retry
  ↓
API Gateway Retry
  ↓
Service A Retry
  ↓
Service B Retry
= 3^4 = 81배 요청!
```

**해결**:
- 재시도는 한 레이어에서만 수행
- Service Mesh를 사용하면 Sidecar에서만 재시도

---

### 2. Circuit Breaker 없이 Retry만 사용

**문제**:
다운된 서비스에 계속 재시도 → 리소스 낭비

**해결**:
- Circuit Breaker와 함께 사용
- 지속적 장애 시 빠른 실패 (Fail-Fast)

---

### 3. 과도한 Timeout

**문제**:
```
Timeout: 60초 → 사용자가 60초 대기
```

**해결**:
- 합리적인 Timeout 설정 (보통 3-10초)
- 사용자 경험 고려

---

## 🚀 다음 단계

### 이 폴더의 패턴을 학습한 후

1. **[[../01-통신-패턴/Service-Mesh-패턴|Service Mesh]]** 학습
   - Istio/Linkerd에서 복원력 패턴 자동 적용 방법

2. **[[../04-배포-인프라-패턴/_README|배포 패턴]]** 으로 이동
   - Blue-Green, Canary 배포로 장애 최소화

3. **[[../99-실전-적용/실전-체크리스트|실전 체크리스트]]** 확인
   - 배포 전 복원력 패턴 적용 여부 점검

---

## 📋 체크리스트

학습 완료 후 확인:

- [ ] Circuit Breaker의 3가지 상태를 설명할 수 있다
- [ ] Retry의 Exponential Backoff 원리를 이해한다
- [ ] Jitter를 추가하는 이유를 안다
- [ ] Bulkhead 패턴으로 리소스를 격리하는 방법을 안다
- [ ] Service Mesh에서 복원력 패턴을 적용하는 방법을 안다
- [ ] Retry Storm을 방지하는 방법을 안다
- [ ] 멱등성(Idempotency)의 중요성을 이해한다
- [ ] Circuit Breaker의 임계치와 타임아웃을 설정할 수 있다

---

**상위 문서**: [[../00-MSA-디자인-패턴-MOC|MSA 디자인 패턴 MOC]]
**마지막 업데이트**: 2026-01-02
