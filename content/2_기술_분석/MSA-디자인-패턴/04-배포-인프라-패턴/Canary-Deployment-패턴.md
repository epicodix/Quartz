---
title: Canary Deployment - 점진적 배포
tags:
  - MSA
  - deployment
  - canary
  - progressive-delivery
  - istio
aliases:
  - 카나리 배포
date: 2026-01-05
category: MSA-디자인-패턴/04-배포-인프라-패턴
status: 완성
priority: 높음
difficulty: 중급
related:
  - "[[Blue-Green-Deployment|Blue-Green Deployment]]"
---

# 🐤 Canary Deployment

> [!note] 패턴 개요
> Canary Deployment는 신규 버전을 **소수 사용자에게 먼저 배포**하여 안정성을 검증한 후, 점진적으로 확대하는 패턴입니다.

---

## 1. 핵심 개념

### 🎯 배포 단계

```
Phase 1: v2.0 → 5% 트래픽
         v1.0 → 95% 트래픽
         ↓ 모니터링 (에러율, 응답시간)

Phase 2: v2.0 → 25% 트래픽
         v1.0 → 75% 트래픽
         ↓ 문제없음

Phase 3: v2.0 → 50% 트래픽
         v1.0 → 50% 트래픽
         ↓ 계속 증가

Phase 4: v2.0 → 100% 트래픽
         v1.0 → 0% (제거)
```

---

## 2. 구현 방법

### 💻 Istio VirtualService

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: myapp
spec:
  hosts:
  - myapp
  http:
  - match:
    - headers:
        canary:
          exact: "true"
    route:
    - destination:
        host: myapp
        subset: v2
  - route:
    - destination:
        host: myapp
        subset: v1
      weight: 95
    - destination:
        host: myapp
        subset: v2
      weight: 5
```

**점진적 증가:**
```bash
# Phase 1: 5%
kubectl patch virtualservice myapp --type merge -p '
{
  "spec": {
    "http": [{
      "route": [
        {"destination": {"subset": "v1"}, "weight": 95},
        {"destination": {"subset": "v2"}, "weight": 5}
      ]
    }]
  }
}'

# Phase 2: 25%
kubectl patch virtualservice myapp --type merge -p '
{
  "spec": {
    "http": [{
      "route": [
        {"destination": {"subset": "v1"}, "weight": 75},
        {"destination": {"subset": "v2"}, "weight": 25}
      ]
    }]
  }
}'

# Phase 3: 100%
kubectl patch virtualservice myapp --type merge -p '
{
  "spec": {
    "http": [{
      "route": [
        {"destination": {"subset": "v2"}, "weight": 100}
      ]
    }]
  }
}'
```

---

### 🚀 Flagger (자동 Canary)

```yaml
apiVersion: flagger.app/v1beta1
kind: Canary
metadata:
  name: myapp
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: myapp
  service:
    port: 80
  analysis:
    interval: 1m
    threshold: 5
    maxWeight: 50
    stepWeight: 10
    metrics:
    - name: request-success-rate
      thresholdRange:
        min: 99
    - name: request-duration
      thresholdRange:
        max: 500
```

**자동 진행:**
```
0% → 10% → 20% → 30% → 40% → 50% → 100%
     ↓     ↓     ↓     ↓     ↓
   (각 단계 1분 모니터링, 성공률 99% 이상 확인)
```

---

## 3. 모니터링 메트릭

### 📊 핵심 지표

```
✅ 성공 조건:
- 에러율 < 0.1%
- P95 응답시간 < 500ms
- CPU 사용률 < 80%

❌ 롤백 조건:
- 에러율 > 1%
- P95 응답시간 > 1s
- 5xx 에러 급증
```

---

## 4. 장단점

### ✅ 장점

1. **점진적 위험 감소**
   - 소수 사용자만 영향

2. **데이터 기반 결정**
   - 실제 트래픽으로 검증

3. **자동 롤백**
   - 문제 발견 시 즉시 복구

### ❌ 단점

1. **배포 시간 길어짐**
   - 단계별 검증 필요

2. **복잡한 설정**
   - 트래픽 분산 인프라 필요

3. **모니터링 필수**
   - 메트릭 수집/분석 시스템 필요

---

## 📚 참고 자료

- [[Blue-Green-Deployment|Blue-Green Deployment]]

---

**상위 문서**: [[_README|배포 인프라 패턴 폴더]]
**마지막 업데이트**: 2026-01-05
