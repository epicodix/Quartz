---
title: Service-to-Service Auth - 서비스 간 인증
tags:
  - MSA
  - security
  - authentication
  - mTLS
  - jwt
  - service-mesh
aliases:
  - 서비스 간 인증
date: 2026-01-05
category: MSA-디자인-패턴/05-보안-거버넌스-패턴
status: 완성
priority: 높음
difficulty: 중급
related:
  - "[[Zero-Trust-Architecture|Zero Trust Architecture]]"
  - "[[API-Gateway-Security|API Gateway Security]]"
---

# 🔑 Service-to-Service Auth

> [!note] 패턴 개요
> 마이크로서비스 간 통신에서 **서비스의 신원을 확인**하고 **권한을 검증**하는 인증/인가 메커니즘입니다.

---

## 1. 인증 방식

### 1. mTLS (Mutual TLS) ⭐

**가장 안전하고 권장되는 방식**

```
Service A                    Service B
    │                            │
    ├─ 1. Client Cert ──────────>│
    │                            ├─ Verify Client Cert
    │<────── 2. Server Cert ─────┤
    ├─ Verify Server Cert        │
    │                            │
    ├─ 3. Encrypted Data ────────>│
    │<───── 4. Encrypted Data ───┤
```

**Istio 자동 mTLS:**
```yaml
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: production
spec:
  mtls:
    mode: STRICT
```

**장점:**
- 강력한 보안 (양방향 인증)
- 인증서 자동 rotation
- 암호화된 통신

**단점:**
- 설정 복잡
- 성능 오버헤드

---

### 2. JWT Token

**Service Account Token:**
```java
@Service
public class OrderService {

    @Autowired
    private RestTemplate restTemplate;

    @Autowired
    private JwtTokenProvider jwtTokenProvider;

    public Payment processPayment(Order order) {
        // 1. Service Token 생성
        String serviceToken = jwtTokenProvider.createServiceToken(
            "order-service",  // issuer
            "payment-service", // audience
            Duration.ofMinutes(5)
        );

        // 2. Token을 헤더에 포함하여 요청
        HttpHeaders headers = new HttpHeaders();
        headers.setBearerAuth(serviceToken);

        HttpEntity<PaymentRequest> request = new HttpEntity<>(
            new PaymentRequest(order),
            headers
        );

        return restTemplate.postForObject(
            "http://payment-service/charge",
            request,
            Payment.class
        );
    }
}
```

**Payment Service 검증:**
```java
@Component
public class ServiceTokenFilter extends OncePerRequestFilter {

    @Autowired
    private JwtTokenValidator jwtTokenValidator;

    @Override
    protected void doFilterInternal(
        HttpServletRequest request,
        HttpServletResponse response,
        FilterChain chain
    ) throws ServletException, IOException {

        String token = extractToken(request);

        if (token != null) {
            Claims claims = jwtTokenValidator.validateToken(token);

            // 1. Issuer 검증
            String issuer = claims.getIssuer();
            if (!isValidService(issuer)) {
                response.sendError(401, "Invalid service");
                return;
            }

            // 2. Audience 검증 (자신인지)
            String audience = claims.getAudience();
            if (!"payment-service".equals(audience)) {
                response.sendError(401, "Invalid audience");
                return;
            }

            // 3. 만료 시간 검증
            if (claims.getExpiration().before(new Date())) {
                response.sendError(401, "Token expired");
                return;
            }

            // 인증 정보 설정
            request.setAttribute("service-id", issuer);
        }

        chain.doFilter(request, response);
    }
}
```

---

### 3. API Key

**간단한 환경용:**
```java
@Configuration
public class ServiceApiKeyConfig {

    @Value("${service.api-keys}")
    private Map<String, String> apiKeys;

    @Bean
    public WebFilter apiKeyFilter() {
        return (exchange, chain) -> {
            String apiKey = exchange.getRequest()
                .getHeaders()
                .getFirst("X-API-Key");

            if (apiKey == null || !isValidApiKey(apiKey)) {
                exchange.getResponse().setStatusCode(HttpStatus.UNAUTHORIZED);
                return exchange.getResponse().setComplete();
            }

            return chain.filter(exchange);
        };
    }

    private boolean isValidApiKey(String apiKey) {
        return apiKeys.containsValue(apiKey);
    }
}
```

**문제점:**
- API Key 노출 위험
- Rotation 어려움
- 단방향 인증만 가능

---

## 2. 서비스 Identity

### 🆔 Kubernetes Service Account

```yaml
# Service Account 생성
apiVersion: v1
kind: ServiceAccount
metadata:
  name: order-service-sa
  namespace: production

---
# Deployment에서 사용
apiVersion: apps/v1
kind: Deployment
metadata:
  name: order-service
spec:
  template:
    spec:
      serviceAccountName: order-service-sa
      containers:
      - name: order-service
        image: order-service:1.0
```

**Token 자동 주입:**
```bash
# Pod 내에서 접근 가능
cat /var/run/secrets/kubernetes.io/serviceaccount/token

# 이 Token으로 다른 서비스 호출 시 인증
```

---

### 🔐 SPIFFE/SPIRE

**SPIFFE (Secure Production Identity Framework For Everyone):**
```
Service A Identity:
spiffe://cluster.local/ns/production/sa/order-service

Service B Identity:
spiffe://cluster.local/ns/production/sa/payment-service
```

**자동 인증서 발급:**
```bash
# SPIRE Agent가 자동으로
# 1. Identity 확인
# 2. 인증서 발급
# 3. 주기적 rotation (매 1시간)
```

---

## 3. 권한 관리

### 📋 서비스별 권한 매트릭스

```yaml
# Istio AuthorizationPolicy
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: payment-service-authz
spec:
  selector:
    matchLabels:
      app: payment-service
  rules:
  # Order Service만 결제 요청 가능
  - from:
    - source:
        principals:
        - "cluster.local/ns/production/sa/order-service"
    to:
    - operation:
        methods: ["POST"]
        paths: ["/charge"]

  # Refund Service만 환불 가능
  - from:
    - source:
        principals:
        - "cluster.local/ns/production/sa/refund-service"
    to:
    - operation:
        methods: ["POST"]
        paths: ["/refund"]
```

---

## 4. 모범 사례

### ✅ Best Practices

1. **mTLS 사용**
   - Istio/Linkerd로 자동화

2. **짧은 Token TTL**
   - Service Token: 5분 이하

3. **최소 권한**
   - 필요한 엔드포인트만 허용

4. **자동 Rotation**
   - 인증서/Key 주기적 갱신

5. **감사 로깅**
   - 모든 서비스 간 호출 기록

---

### 🚫 안티 패턴

```java
// ❌ 나쁜 예: Hardcoded API Key
public class BadService {
    private static final String API_KEY = "secret-key-123";

    public void callPayment() {
        headers.add("X-API-Key", API_KEY);  // 코드에 하드코딩!
    }
}

// ✅ 좋은 예: 환경 변수 + Secret 관리
@Service
public class GoodService {

    @Value("${payment.api-key}")  // Kubernetes Secret에서 주입
    private String apiKey;

    public void callPayment() {
        headers.add("X-API-Key", apiKey);
    }
}
```

---

## 5. 구현 예시

### 💻 Spring Cloud 구현

```java
// 1. Service Token 생성
@Component
public class ServiceTokenProvider {

    @Value("${spring.application.name}")
    private String serviceName;

    @Autowired
    private JwtEncoder jwtEncoder;

    public String createToken(String targetService) {
        Instant now = Instant.now();

        JwtClaimsSet claims = JwtClaimsSet.builder()
            .issuer(serviceName)
            .audience(List.of(targetService))
            .issuedAt(now)
            .expiresAt(now.plus(5, ChronoUnit.MINUTES))
            .build();

        return jwtEncoder.encode(JwtEncoderParameters.from(claims)).getTokenValue();
    }
}

// 2. RestTemplate Interceptor
@Component
public class ServiceAuthInterceptor implements ClientHttpRequestInterceptor {

    @Autowired
    private ServiceTokenProvider tokenProvider;

    @Override
    public ClientHttpResponse intercept(
        HttpRequest request,
        byte[] body,
        ClientHttpRequestExecution execution
    ) throws IOException {

        // URL에서 대상 서비스 추출
        String targetService = extractServiceName(request.getURI());

        // Token 생성 및 추가
        String token = tokenProvider.createToken(targetService);
        request.getHeaders().setBearerAuth(token);

        return execution.execute(request, body);
    }
}

// 3. RestTemplate 설정
@Configuration
public class RestTemplateConfig {

    @Autowired
    private ServiceAuthInterceptor serviceAuthInterceptor;

    @Bean
    public RestTemplate restTemplate() {
        RestTemplate restTemplate = new RestTemplate();
        restTemplate.setInterceptors(List.of(serviceAuthInterceptor));
        return restTemplate;
    }
}
```

---

## 6. 비교표

### 📊 인증 방식 비교

| 방식 | 보안 수준 | 복잡도 | 성능 | 권장 사용처 |
|------|----------|--------|------|------------|
| **mTLS** | ⭐⭐⭐⭐⭐ | 높음 | 중간 | 프로덕션 (Istio) |
| **JWT** | ⭐⭐⭐⭐ | 중간 | 높음 | REST API |
| **API Key** | ⭐⭐ | 낮음 | 높음 | 개발 환경 |
| **Service Account** | ⭐⭐⭐⭐ | 중간 | 높음 | Kubernetes |

---

## 📚 참고 자료

- [[Zero-Trust-Architecture|Zero Trust Architecture]]
- [[API-Gateway-Security|API Gateway Security]]

---

**상위 문서**: [[_README|보안 거버넌스 패턴 폴더]]
**마지막 업데이트**: 2026-01-05
