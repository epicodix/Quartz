---
title: API Gateway Security - API 보안 강화
tags:
  - MSA
  - security
  - api-gateway
  - authentication
  - authorization
  - jwt
aliases:
  - API 게이트웨이 보안
date: 2026-01-05
category: MSA-디자인-패턴/05-보안-거버넌스-패턴
status: 완성
priority: 높음
difficulty: 중급
related:
  - "[[../01-통신-패턴/API-Gateway-패턴|API Gateway 패턴]]"
  - "[[Zero-Trust-Architecture|Zero Trust Architecture]]"
  - "[[Service-to-Service-Auth|Service-to-Service Auth]]"
---

# 🔐 API Gateway Security

> [!note] 패턴 개요
> API Gateway에서 **인증(Authentication), 인가(Authorization), 보안 정책**을 중앙화하여 전체 시스템의 보안을 강화하는 패턴입니다.

---

## 1. 핵심 보안 기능

### 🎯 보안 계층

```
Client Request
      ↓
┌─────────────────────────────────┐
│  API Gateway (보안 계층)          │
│                                 │
│  1. Rate Limiting (DDoS 방어)   │
│  2. Authentication (인증)       │
│  3. Authorization (인가)        │
│  4. Input Validation (검증)    │
│  5. TLS Termination (암호화)   │
│  6. IP Whitelist/Blacklist     │
└─────────────────────────────────┘
      ↓
  Internal Services (신뢰)
```

---

## 2. 인증 (Authentication)

### 1. JWT Token 인증

```java
@Component
public class JwtAuthenticationFilter extends OncePerRequestFilter {

    @Autowired
    private JwtTokenUtil jwtTokenUtil;

    @Override
    protected void doFilterInternal(
        HttpServletRequest request,
        HttpServletResponse response,
        FilterChain chain
    ) throws ServletException, IOException {

        String token = extractToken(request);

        if (token != null && jwtTokenUtil.validateToken(token)) {
            // 사용자 정보 추출
            String userId = jwtTokenUtil.getUserId(token);
            List<String> roles = jwtTokenUtil.getRoles(token);

            // 인증 정보 설정
            Authentication auth = new JwtAuthenticationToken(userId, roles);
            SecurityContextHolder.getContext().setAuthentication(auth);

            // 다운스트림 서비스에 전달
            request.setAttribute("X-User-Id", userId);
            request.setAttribute("X-User-Roles", String.join(",", roles));
        } else {
            response.sendError(HttpServletResponse.SC_UNAUTHORIZED, "Invalid token");
            return;
        }

        chain.doFilter(request, response);
    }

    private String extractToken(HttpServletRequest request) {
        String bearerToken = request.getHeader("Authorization");
        if (bearerToken != null && bearerToken.startsWith("Bearer ")) {
            return bearerToken.substring(7);
        }
        return null;
    }
}
```

---

### 2. OAuth 2.0 / OpenID Connect

```yaml
# Spring Cloud Gateway - OAuth 2.0
spring:
  cloud:
    gateway:
      routes:
      - id: protected-api
        uri: http://api-service
        predicates:
        - Path=/api/**
        filters:
        - TokenRelay  # OAuth 토큰 전달

  security:
    oauth2:
      client:
        registration:
          google:
            client-id: ${GOOGLE_CLIENT_ID}
            client-secret: ${GOOGLE_CLIENT_SECRET}
            scope: openid,profile,email
        provider:
          google:
            issuer-uri: https://accounts.google.com
```

---

## 3. 인가 (Authorization)

### 📋 역할 기반 접근 제어 (RBAC)

```java
@Service
public class AuthorizationService {

    public boolean authorize(String userId, String resource, String action) {
        List<String> userRoles = getUserRoles(userId);

        // 역할별 권한 체크
        for (String role : userRoles) {
            if (hasPermission(role, resource, action)) {
                return true;
            }
        }

        return false;
    }

    private boolean hasPermission(String role, String resource, String action) {
        // 권한 매트릭스
        Map<String, Set<String>> permissions = Map.of(
            "ADMIN", Set.of("users:*", "orders:*", "products:*"),
            "USER", Set.of("orders:read", "orders:create", "profile:*"),
            "GUEST", Set.of("products:read")
        );

        Set<String> rolePermissions = permissions.getOrDefault(role, Set.of());
        String requiredPermission = resource + ":" + action;

        // 와일드카드 매칭
        return rolePermissions.contains(requiredPermission) ||
               rolePermissions.contains(resource + ":*");
    }
}
```

---

### 🔑 Kong RBAC 플러그인

```bash
# 1. Consumer 생성
curl -X POST http://localhost:8001/consumers \
  --data "username=john"

# 2. JWT Credential 발급
curl -X POST http://localhost:8001/consumers/john/jwt

# 3. ACL 그룹 할당
curl -X POST http://localhost:8001/consumers/john/acls \
  --data "group=premium-users"

# 4. Route에 ACL 적용
curl -X POST http://localhost:8001/routes/{route-id}/plugins \
  --data "name=acl" \
  --data "config.whitelist=premium-users"
```

---

## 4. 보안 정책

### 1. Rate Limiting (속도 제한)

```yaml
# Kong Rate Limiting
plugins:
- name: rate-limiting
  config:
    minute: 100
    hour: 1000
    policy: redis
    redis_host: localhost
    redis_port: 6379
```

---

### 2. IP Whitelist/Blacklist

```yaml
# Kong IP Restriction
plugins:
- name: ip-restriction
  config:
    whitelist:
    - 192.168.1.0/24  # 내부 네트워크만 허용
    - 10.0.0.5        # 특정 IP
    blacklist:
    - 1.2.3.4         # 차단할 IP
```

---

### 3. Request Validation

```java
@Component
public class RequestValidationFilter implements GlobalFilter, Ordered {

    @Override
    public Mono<Void> filter(ServerWebExchange exchange, GatewayFilterChain chain) {
        ServerHttpRequest request = exchange.getRequest();

        // 1. Content-Type 검증
        if (!isValidContentType(request)) {
            return sendError(exchange, HttpStatus.UNSUPPORTED_MEDIA_TYPE);
        }

        // 2. 크기 제한
        if (exceedsMaxSize(request)) {
            return sendError(exchange, HttpStatus.PAYLOAD_TOO_LARGE);
        }

        // 3. SQL Injection 체크
        if (containsSqlInjection(request)) {
            return sendError(exchange, HttpStatus.BAD_REQUEST);
        }

        return chain.filter(exchange);
    }

    private boolean containsSqlInjection(ServerHttpRequest request) {
        String[] dangerousPatterns = {"' OR '1'='1", "DROP TABLE", "SELECT * FROM"};
        String queryString = request.getURI().getQuery();

        if (queryString != null) {
            for (String pattern : dangerousPatterns) {
                if (queryString.toUpperCase().contains(pattern)) {
                    return true;
                }
            }
        }

        return false;
    }

    @Override
    public int getOrder() {
        return -200;  // 인증 전에 실행
    }
}
```

---

## 5. TLS/SSL 설정

### 🔒 HTTPS Termination

```yaml
# Kubernetes Ingress with TLS
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: api-gateway
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  tls:
  - hosts:
    - api.example.com
    secretName: api-tls-cert
  rules:
  - host: api.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: api-gateway
            port:
              number: 80
```

---

## 6. 보안 헤더

### 📋 HTTP Security Headers

```java
@Configuration
public class SecurityHeadersConfig {

    @Bean
    public WebFilter securityHeadersFilter() {
        return (exchange, chain) -> {
            ServerHttpResponse response = exchange.getResponse();
            HttpHeaders headers = response.getHeaders();

            // 1. XSS Protection
            headers.add("X-XSS-Protection", "1; mode=block");

            // 2. Content Type Options
            headers.add("X-Content-Type-Options", "nosniff");

            // 3. Frame Options (Clickjacking 방지)
            headers.add("X-Frame-Options", "DENY");

            // 4. HSTS (HTTPS 강제)
            headers.add("Strict-Transport-Security", "max-age=31536000; includeSubDomains");

            // 5. Content Security Policy
            headers.add("Content-Security-Policy", "default-src 'self'");

            // 6. Referrer Policy
            headers.add("Referrer-Policy", "no-referrer");

            return chain.filter(exchange);
        };
    }
}
```

---

## 7. 감사 로깅

### 📝 Security Audit Log

```java
@Component
public class SecurityAuditLogger {

    @Autowired
    private AuditLogRepository auditLogRepository;

    public void logSecurityEvent(
        String eventType,
        String userId,
        String resource,
        String action,
        boolean success
    ) {
        AuditLog log = AuditLog.builder()
            .timestamp(Instant.now())
            .eventType(eventType)
            .userId(userId)
            .resource(resource)
            .action(action)
            .success(success)
            .ipAddress(getCurrentIpAddress())
            .userAgent(getCurrentUserAgent())
            .build();

        auditLogRepository.save(log);

        // 실패 시 알림
        if (!success) {
            alertService.sendSecurityAlert(log);
        }
    }
}
```

---

## 8. 실전 체크리스트

### ✅ API Gateway 보안 체크리스트

- [ ] **인증**
  - [ ] JWT/OAuth 2.0 구현
  - [ ] 토큰 만료 시간 설정
  - [ ] Refresh Token 구현

- [ ] **인가**
  - [ ] RBAC 구현
  - [ ] 권한 매트릭스 정의
  - [ ] 최소 권한 원칙 적용

- [ ] **Rate Limiting**
  - [ ] 글로벌/IP/사용자별 제한
  - [ ] DDoS 방어 설정

- [ ] **입력 검증**
  - [ ] SQL Injection 방어
  - [ ] XSS 방어
  - [ ] 크기 제한

- [ ] **TLS/SSL**
  - [ ] HTTPS 강제
  - [ ] 최신 TLS 버전 사용
  - [ ] 인증서 자동 갱신

- [ ] **보안 헤더**
  - [ ] HSTS 설정
  - [ ] CSP 설정
  - [ ] X-Frame-Options 설정

- [ ] **모니터링**
  - [ ] 감사 로깅
  - [ ] 실시간 알림
  - [ ] 이상 탐지

---

## 📚 참고 자료

- [[../01-통신-패턴/API-Gateway-패턴|API Gateway 패턴]]
- [[Zero-Trust-Architecture|Zero Trust Architecture]]

---

**상위 문서**: [[_README|보안 거버넌스 패턴 폴더]]
**마지막 업데이트**: 2026-01-05
