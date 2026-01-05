---
title: Zero Trust Architecture - 제로 트러스트 아키텍처
tags:
  - MSA
  - security
  - zero-trust
  - mTLS
  - service-mesh
aliases:
  - 제로 트러스트
  - Never Trust, Always Verify
date: 2026-01-05
category: MSA-디자인-패턴/05-보안-거버넌스-패턴
status: 완성
priority: 높음
difficulty: 고급
related:
  - "[[API-Gateway-Security|API Gateway Security]]"
  - "[[Service-to-Service-Auth|Service-to-Service Auth]]"
---

# 🛡️ Zero Trust Architecture

> [!note] 패턴 개요
> Zero Trust는 **"아무것도 신뢰하지 않는다(Never Trust, Always Verify)"** 원칙으로, 네트워크 내/외부를 구분하지 않고 모든 접근을 검증하는 보안 모델입니다.

---

## 1. 핵심 개념

### 🎯 전통적 보안 vs Zero Trust

**전통적 보안 (Perimeter Security):**
```
┌─────────────────────────────────┐
│     Internal Network (신뢰)     │
│                                 │
│  Service A → Service B (검증 ❌)│
│  Service B → Service C (검증 ❌)│
│                                 │
└─────────────────────────────────┘
         ↑
      방화벽 (경계)
         ↑
    External (불신)
```

**문제:**
- 내부 침입 시 전체 노출
- 측면 이동(Lateral Movement) 쉬움

**Zero Trust:**
```
Service A → Service B (mTLS ✅, 인증 ✅, 인가 ✅)
Service B → Service C (mTLS ✅, 인증 ✅, 인가 ✅)
모든 통신 검증!
```

---

## 2. Zero Trust 원칙

### 📋 5가지 핵심 원칙

1. **최소 권한 (Least Privilege)**
   - 필요한 최소한의 권한만 부여

2. **명시적 검증 (Explicit Verification)**
   - 모든 요청 검증 (내부/외부 구분 없음)

3. **침해 가정 (Assume Breach)**
   - 이미 침투당했다고 가정하고 설계

4. **마이크로 세그먼테이션 (Micro-Segmentation)**
   - 네트워크를 작은 단위로 분리

5. **지속적 모니터링 (Continuous Monitoring)**
   - 실시간 위협 탐지

---

## 3. 구현 방법

### 1. mTLS (Mutual TLS)

**Istio로 자동 mTLS:**
```yaml
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: production
spec:
  mtls:
    mode: STRICT  # 모든 통신 mTLS 강제
```

**동작:**
```
Service A → Service B

1. Service A: 클라이언트 인증서 제시
2. Service B: 인증서 검증 + 서버 인증서 제시
3. Service A: 서버 인증서 검증
4. 암호화된 통신 시작
```

---

### 2. 서비스별 Identity

**SPIFFE (Secure Production Identity Framework For Everyone):**
```
Service A Identity: spiffe://cluster.local/ns/default/sa/service-a
Service B Identity: spiffe://cluster.local/ns/default/sa/service-b

각 서비스는 고유한 Identity 보유
→ 인증서 자동 발급/갱신 (Istio)
```

---

### 3. 세분화된 인가 정책

**Istio AuthorizationPolicy:**
```yaml
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: order-service-authz
  namespace: production
spec:
  selector:
    matchLabels:
      app: order-service
  rules:
  # Rule 1: User Service만 주문 조회 가능
  - from:
    - source:
        principals: ["cluster.local/ns/default/sa/user-service"]
    to:
    - operation:
        methods: ["GET"]
        paths: ["/orders/*"]

  # Rule 2: Payment Service만 결제 상태 업데이트 가능
  - from:
    - source:
        principals: ["cluster.local/ns/default/sa/payment-service"]
    to:
    - operation:
        methods: ["POST"]
        paths: ["/orders/*/payment"]

  # Rule 3: 나머지는 모두 거부 (기본 Deny)
```

---

### 4. 네트워크 분리 (마이크로 세그먼테이션)

**Kubernetes Network Policy:**
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: order-service-netpol
  namespace: production
spec:
  podSelector:
    matchLabels:
      app: order-service
  policyTypes:
  - Ingress
  - Egress
  ingress:
  # User Service로부터만 ingress 허용
  - from:
    - podSelector:
        matchLabels:
          app: user-service
    ports:
    - protocol: TCP
      port: 8080
  egress:
  # Payment Service로만 egress 허용
  - to:
    - podSelector:
        matchLabels:
          app: payment-service
    ports:
    - protocol: TCP
      port: 8080
  # DNS 쿼리 허용
  - to:
    - namespaceSelector:
        matchLabels:
          name: kube-system
    ports:
    - protocol: UDP
      port: 53
```

---

## 4. 지속적 검증

### 📊 실시간 모니터링

```java
@Component
public class ContinuousVerificationService {

    public boolean verifyAccess(ServiceRequest request) {
        // 1. Identity 검증
        if (!verifyIdentity(request.getClientCertificate())) {
            log.warn("Invalid client identity: {}", request.getClientId());
            return false;
        }

        // 2. 권한 재검증 (캐시 사용하되 주기적 갱신)
        if (!hasCurrentPermission(request.getServiceId(), request.getResource())) {
            log.warn("Permission revoked for service: {}", request.getServiceId());
            return false;
        }

        // 3. 행동 분석 (이상 탐지)
        if (isAnomalousBehavior(request)) {
            log.error("Anomalous behavior detected: {}", request);
            alertService.sendSecurityAlert(request);
            return false;
        }

        // 4. Rate Limiting (서비스별)
        if (exceedsRateLimit(request.getServiceId())) {
            log.warn("Rate limit exceeded: {}", request.getServiceId());
            return false;
        }

        return true;
    }

    private boolean isAnomalousBehavior(ServiceRequest request) {
        // ML 기반 이상 탐지
        // - 비정상적인 요청 빈도
        // - 평소와 다른 엔드포인트 접근
        // - 의심스러운 데이터 패턴
        return mlModel.predictAnomaly(request) > 0.8;
    }
}
```

---

## 5. 실전 구현

### 🚀 Istio 기반 Zero Trust

```yaml
# 1. 전역 mTLS 강제
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: default
  namespace: istio-system
spec:
  mtls:
    mode: STRICT

---
# 2. 기본 Deny All
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: deny-all
  namespace: production
spec:
  {}  # 빈 spec = 모두 거부

---
# 3. 명시적 허용만 추가
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: allow-user-to-order
  namespace: production
spec:
  selector:
    matchLabels:
      app: order-service
  action: ALLOW
  rules:
  - from:
    - source:
        principals: ["cluster.local/ns/production/sa/user-service"]
    to:
    - operation:
        methods: ["GET", "POST"]
        paths: ["/orders/*"]
```

---

## 6. 장단점

### ✅ 장점

1. **강력한 보안**
   - 내부 침투 시에도 피해 최소화

2. **명확한 권한 관리**
   - 서비스별 권한 명시적 정의

3. **감사 추적**
   - 모든 접근 로깅

### ❌ 단점

1. **복잡도 증가**
   - 정책 관리 복잡

2. **성능 오버헤드**
   - mTLS, 인증/인가 검증

3. **초기 설정 어려움**
   - 모든 서비스 간 관계 정의 필요

---

## 7. 사용 시기

### ✅ 적합한 경우

- 금융, 의료 등 보안 중요
- 규제 준수 필요
- 멀티 테넌트 환경

### ❌ 부적합한 경우

- 소규모 시스템
- 성능 critical
- 빠른 개발 필요

---

## 📚 참고 자료

- [[API-Gateway-Security|API Gateway Security]]
- [[Service-to-Service-Auth|Service-to-Service Auth]]

---

**상위 문서**: [[_README|보안 거버넌스 패턴 폴더]]
**마지막 업데이트**: 2026-01-05
