---
title: Rate Limiter 패턴 - 요청 속도 제한
tags:
  - MSA
  - rate-limiting
  - throttling
  - resilience4j
  - API-protection
aliases:
  - 속도 제한 패턴
  - Throttling
date: 2026-01-05
category: MSA-디자인-패턴/03-복원력-패턴
status: 완성
priority: 높음
difficulty: 중급
related:
  - "[[../01-통신-패턴/API-Gateway-패턴|API Gateway 패턴]]"
  - "[[Bulkhead-패턴|Bulkhead 패턴]]"
---

# 🚦 Rate Limiter 패턴

> [!note] 패턴 개요
> Rate Limiter는 **요청 속도를 제한**하여 서비스 과부하를 방지하는 패턴입니다. DDoS 공격, 급격한 트래픽 증가로부터 시스템을 보호합니다.

---

## 1. 핵심 개념

### 🎯 Rate Limiting이 필요한 이유

```
정상 트래픽: 초당 100건
급격한 증가: 초당 10,000건 (100배)
↓
서버 과부하 → 전체 다운
```

**Rate Limiter 적용:**
```
요청: 10,000건/초
제한: 1,000건/초 허용
차단: 9,000건/초 거부 (429 Too Many Requests)
→ 서비스 안정성 유지
```

---

## 2. Rate Limiting 알고리즘

### 1. Token Bucket (토큰 버킷)

```
버킷 용량: 100 토큰
리필 속도: 10 토큰/초

동작:
1. 요청 → 토큰 1개 소비
2. 토큰 없으면 → 거부
3. 매초 10개씩 리필
```

```yaml
resilience4j.ratelimiter:
  instances:
    api:
      limitForPeriod: 100        # 주기당 100개 허용
      limitRefreshPeriod: 1s     # 1초마다 리필
      timeoutDuration: 0ms       # 대기 없이 즉시 거부
```

---

### 2. Leaky Bucket (새는 버킷)

```
버킷 크기: 100
유출 속도: 10개/초 (고정)

특징: 요청을 큐에 담고 일정한 속도로 처리
```

---

### 3. Fixed Window (고정 윈도우)

```
시간창: 1분
제한: 100개

00:00~00:59 → 100개 허용
01:00~01:59 → 100개 허용
```

**단점: 경계 문제**
```
00:59 → 100개 요청
01:00 → 100개 요청
→ 1초 동안 200개! (burst)
```

---

### 4. Sliding Window (슬라이딩 윈도우)

```
시간창: 1분 (슬라이딩)
제한: 100개

현재 시각으로부터 과거 1분간 요청 수 카운트
→ 정확한 제한
```

---

## 3. 실제 구현

### 💻 Resilience4j RateLimiter

```java
@Service
public class ApiService {

    @RateLimiter(name = "api", fallbackMethod = "rateLimitFallback")
    public Response callApi(Request request) {
        return apiClient.call(request);
    }

    private Response rateLimitFallback(Request request, RequestNotPermitted ex) {
        log.warn("Rate limit exceeded for request: {}", request);
        throw new TooManyRequestsException("API 호출 한도 초과. 잠시 후 다시 시도해주세요.");
    }
}
```

```yaml
resilience4j.ratelimiter:
  instances:
    api:
      limitForPeriod: 100
      limitRefreshPeriod: 1s
      timeoutDuration: 0ms

    premium-api:
      limitForPeriod: 1000      # 프리미엄 사용자는 10배
      limitRefreshPeriod: 1s
```

---

### 🌐 API Gateway (Kong)

```bash
# Kong Rate Limiting 플러그인
curl -X POST http://localhost:8001/services/api-service/plugins \
  --data "name=rate-limiting" \
  --data "config.minute=100" \
  --data "config.hour=1000" \
  --data "config.policy=redis" \
  --data "config.redis_host=localhost"
```

---

### 🐳 Nginx Rate Limiting

```nginx
# nginx.conf
http {
    # IP 기반 Rate Limiting
    limit_req_zone $binary_remote_addr zone=api_limit:10m rate=10r/s;

    server {
        location /api/ {
            limit_req zone=api_limit burst=20 nodelay;
            proxy_pass http://backend;
        }
    }
}
```

---

## 4. Rate Limiting 전략

### 📊 계층별 적용

| 계층 | 제한 기준 | 예시 |
|------|---------|------|
| **글로벌** | 전체 시스템 | 초당 10,000건 |
| **IP** | IP 주소별 | IP당 분당 100건 |
| **사용자** | 로그인 사용자 | 무료: 100/분, 프리미엄: 1000/분 |
| **API Key** | 클라이언트별 | API Key당 시간당 10,000건 |
| **엔드포인트** | API별 | /orders: 500/분, /search: 1000/분 |

---

### 🎯 비즈니스 규칙

```java
@Service
public class DynamicRateLimiter {

    public int getRateLimit(User user) {
        if (user.isPremium()) {
            return 1000;  // 프리미엄: 1000/분
        } else if (user.isVerified()) {
            return 500;   // 인증됨: 500/분
        } else {
            return 100;   // 기본: 100/분
        }
    }
}
```

---

## 5. 응답 헤더

### 📋 Rate Limit 정보 제공

```http
HTTP/1.1 200 OK
X-RateLimit-Limit: 100         # 전체 한도
X-RateLimit-Remaining: 37      # 남은 횟수
X-RateLimit-Reset: 1641024000  # 리셋 시각 (Unix timestamp)
```

```http
HTTP/1.1 429 Too Many Requests
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 0
X-RateLimit-Reset: 1641024000
Retry-After: 60                # 60초 후 재시도

{
  "error": "Rate limit exceeded",
  "message": "You have exceeded the API rate limit. Please try again in 60 seconds."
}
```

---

## 6. 분산 환경 Rate Limiting

### 🔴 Redis 기반

```java
@Service
public class RedisRateLimiter {

    @Autowired
    private StringRedisTemplate redisTemplate;

    public boolean allowRequest(String key, int limit, int windowSeconds) {
        String redisKey = "rate_limit:" + key;
        Long current = redisTemplate.opsForValue().increment(redisKey);

        if (current == 1) {
            redisTemplate.expire(redisKey, windowSeconds, TimeUnit.SECONDS);
        }

        return current <= limit;
    }
}
```

---

## 7. 장단점

### ✅ 장점

1. **시스템 보호**
   - 과부하 방지
   - DDoS 공격 완화

2. **공정성**
   - 리소스 공평 분배
   - 한 사용자가 독점 방지

3. **비용 절감**
   - 외부 API 비용 제어

### ❌ 단점

1. **사용자 불편**
   - 정상 사용자도 제한 가능

2. **복잡도**
   - 분산 환경에서 구현 어려움

3. **설정 어려움**
   - 적절한 한도 결정 복잡

---

## 8. 사용 시기

### ✅ 적합한 경우

1. **공개 API**
   - 외부 개발자에게 제공

2. **유료 서비스**
   - 플랜별 차등 적용

3. **리소스 보호**
   - DB, 외부 API 호출 제한

### ❌ 부적합한 경우

1. **내부 서비스**
   - 신뢰할 수 있는 클라이언트

2. **실시간 서비스**
   - Rate Limiting이 기능 저해

---

## 📚 참고 자료

- [[../01-통신-패턴/API-Gateway-패턴|API Gateway 패턴]]
- [[Bulkhead-패턴|Bulkhead 패턴]]

---

**상위 문서**: [[_README|복원력 패턴 폴더]]
**마지막 업데이트**: 2026-01-05
