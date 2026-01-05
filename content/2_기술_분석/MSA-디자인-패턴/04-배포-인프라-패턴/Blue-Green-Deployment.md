---
title: Blue-Green Deployment - 무중단 배포
tags:
  - MSA
  - deployment
  - blue-green
  - zero-downtime
  - kubernetes
aliases:
  - 블루그린 배포
date: 2026-01-05
category: MSA-디자인-패턴/04-배포-인프라-패턴
status: 완성
priority: 높음
difficulty: 중급
related:
  - "[[Canary-Deployment-패턴|Canary Deployment]]"
---

# 🔵🟢 Blue-Green Deployment

> [!note] 패턴 개요
> Blue-Green Deployment는 **두 개의 동일한 환경**(Blue/Green)을 운영하며, 트래픽을 순간적으로 전환하여 **무중단 배포**를 구현하는 패턴입니다.

---

## 1. 핵심 개념

### 🎯 배포 프로세스

```
현재 상태:
Blue (v1.0) ← 모든 트래픽 (100%)
Green (idle) ← 트래픽 없음

배포:
1. Green에 v2.0 배포
2. Green 테스트
3. 트래픽 Blue → Green 전환 (순간 전환)
4. Green (v2.0) ← 모든 트래픽 (100%)
   Blue (v1.0) ← 대기 (롤백용)
```

---

## 2. 구현 방법

### 💻 Kubernetes 구현

```yaml
# Blue Deployment (v1.0)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp-blue
  labels:
    app: myapp
    version: blue
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
      version: blue
  template:
    metadata:
      labels:
        app: myapp
        version: blue
    spec:
      containers:
      - name: myapp
        image: myapp:1.0
```

```yaml
# Green Deployment (v2.0)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp-green
  labels:
    app: myapp
    version: green
spec:
  replicas: 3
  selector:
    matchLabels:
      app: myapp
      version: green
  template:
    metadata:
      labels:
        app: myapp
        version: green
    spec:
      containers:
      - name: myapp
        image: myapp:2.0
```

```yaml
# Service (트래픽 라우팅)
apiVersion: v1
kind: Service
metadata:
  name: myapp-service
spec:
  selector:
    app: myapp
    version: blue  # 트래픽 → Blue
  ports:
  - port: 80
    targetPort: 8080
```

**전환:**
```bash
# Green으로 전환
kubectl patch service myapp-service -p '{"spec":{"selector":{"version":"green"}}}'

# 롤백 (Blue로 되돌림)
kubectl patch service myapp-service -p '{"spec":{"selector":{"version":"blue"}}}'
```

---

### 🌐 AWS ELB 구현

```bash
# 1. Blue (현재) Target Group
aws elbv2 create-target-group \
  --name myapp-blue-tg \
  --protocol HTTP \
  --port 80

# 2. Green (신규) Target Group
aws elbv2 create-target-group \
  --name myapp-green-tg \
  --protocol HTTP \
  --port 80

# 3. Listener 규칙 변경 (Blue → Green)
aws elbv2 modify-listener \
  --listener-arn $LISTENER_ARN \
  --default-actions Type=forward,TargetGroupArn=$GREEN_TG_ARN
```

---

## 3. 장단점

### ✅ 장점

1. **즉시 롤백**
   - Blue로 즉시 복구 (1초)

2. **무중단**
   - 다운타임 0

3. **안전한 테스트**
   - Green 환경에서 충분한 검증

### ❌ 단점

1. **리소스 2배**
   - Blue + Green 동시 운영

2. **DB 마이그레이션 복잡**
   - 양방향 호환 필요

3. **상태 유지 서비스 어려움**
   - 세션, WebSocket 처리 복잡

---

## 4. 사용 시기

### ✅ 적합한 경우

- 무중단 배포 필수
- 즉시 롤백 필요
- 충분한 인프라

### ❌ 부적합한 경우

- 리소스 제한적
- DB 마이그레이션 복잡
- 상태 유지 서비스

---

## 📚 참고 자료

- [[Canary-Deployment-패턴|Canary Deployment]]

---

**상위 문서**: [[_README|배포 인프라 패턴 폴더]]
**마지막 업데이트**: 2026-01-05
