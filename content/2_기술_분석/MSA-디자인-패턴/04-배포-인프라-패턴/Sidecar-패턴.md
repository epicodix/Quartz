---
title: Sidecar 패턴 - 보조 컨테이너
tags:
  - MSA
  - sidecar
  - kubernetes
  - service-mesh
  - istio
aliases:
  - 사이드카 패턴
date: 2026-01-05
category: MSA-디자인-패턴/04-배포-인프라-패턴
status: 완성
priority: 높음
difficulty: 중급
related:
  - "[[Ambassador-패턴|Ambassador 패턴]]"
  - "[[../01-통신-패턴/Service-Mesh-패턴|Service Mesh]]"
---

# 🏍️ Sidecar 패턴

> [!note] 패턴 개요
> Sidecar는 메인 애플리케이션 옆에 **보조 컨테이너를 배치**하여 로깅, 모니터링, 프록시 등의 **공통 기능을 분리**하는 패턴입니다.

---

## 1. 핵심 개념

### 🎯 Sidecar 구조

```
┌─────────────────────────────────┐
│          Pod                    │
│                                 │
│  ┌──────────────┐ ┌──────────┐ │
│  │ Main App     │ │ Sidecar  │ │
│  │ (Business    │ │ (Logging)│ │
│  │  Logic)      │ │          │ │
│  └──────────────┘ └──────────┘ │
│         │              │        │
│         └──────────────┘        │
│       Shared Volume             │
└─────────────────────────────────┘
```

---

## 2. 사용 사례

### 1. 로깅 Sidecar

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: myapp
spec:
  containers:
  # 메인 애플리케이션
  - name: app
    image: myapp:1.0
    volumeMounts:
    - name: logs
      mountPath: /var/log/app

  # 로깅 Sidecar
  - name: log-shipper
    image: fluentd:latest
    volumeMounts:
    - name: logs
      mountPath: /var/log/app
    env:
    - name: FLUENT_ELASTICSEARCH_HOST
      value: "elasticsearch"

  volumes:
  - name: logs
    emptyDir: {}
```

---

### 2. Proxy Sidecar (Istio Envoy)

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: myapp
  annotations:
    sidecar.istio.io/inject: "true"  # 자동 주입
spec:
  containers:
  - name: app
    image: myapp:1.0
    ports:
    - containerPort: 8080

  # Istio가 자동으로 Envoy Sidecar 주입
  # - Traffic 관리
  # - mTLS 암호화
  # - Metrics 수집
  # - Tracing
```

---

### 3. Config Watcher Sidecar

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: myapp
spec:
  containers:
  # 메인 앱
  - name: app
    image: myapp:1.0
    volumeMounts:
    - name: config
      mountPath: /etc/config

  # Config 동기화 Sidecar
  - name: config-syncer
    image: config-syncer:1.0
    command: ["watch-and-sync"]
    args:
    - --source=consul://config/myapp
    - --dest=/etc/config
    volumeMounts:
    - name: config
      mountPath: /etc/config

  volumes:
  - name: config
    emptyDir: {}
```

---

## 3. 장단점

### ✅ 장점

1. **관심사 분리**
   - 비즈니스 로직과 인프라 로직 분리

2. **재사용**
   - 동일한 Sidecar를 여러 앱에 적용

3. **독립 배포**
   - Sidecar 업데이트가 앱에 영향 없음

### ❌ 단점

1. **리소스 증가**
   - Pod당 추가 컨테이너

2. **복잡도**
   - 관리해야 할 컨테이너 증가

3. **시작 시간**
   - Pod 초기화 시간 증가

---

## 4. 사용 시기

### ✅ 적합한 경우

- 공통 기능 분리 (로깅, 모니터링)
- Service Mesh 적용
- 설정 동기화

### ❌ 부적합한 경우

- 단순한 애플리케이션
- 리소스 제약적 환경

---

## 📚 참고 자료

- [[Ambassador-패턴|Ambassador 패턴]]
- [[../01-통신-패턴/Service-Mesh-패턴|Service Mesh]]

---

**상위 문서**: [[_README|배포 인프라 패턴 폴더]]
**마지막 업데이트**: 2026-01-05
