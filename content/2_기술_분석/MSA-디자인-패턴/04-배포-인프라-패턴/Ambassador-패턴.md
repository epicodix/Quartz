---
title: Ambassador 패턴 - 프록시 컨테이너
tags:
  - MSA
  - ambassador
  - proxy
  - kubernetes
aliases:
  - 앰배서더 패턴
date: 2026-01-05
category: MSA-디자인-패턴/04-배포-인프라-패턴
status: 완성
priority: 중간
difficulty: 중급
related:
  - "[[Sidecar-패턴|Sidecar 패턴]]"
---

# 🎩 Ambassador 패턴

> [!note] 패턴 개요
> Ambassador는 **네트워크 연결을 대신 처리**하는 프록시 컨테이너를 배치하여, 복잡한 네트워크 로직을 애플리케이션에서 분리하는 패턴입니다.

---

## 1. 핵심 개념

### 🎯 Ambassador 역할

```
┌──────────────────────────────────┐
│  Pod                             │
│                                  │
│  ┌────────┐      ┌────────────┐ │
│  │  App   │ ---> │ Ambassador │ ─┼──> External Service
│  │        │ <--- │  (Proxy)   │ <┼─── (DB, Cache, API)
│  └────────┘      └────────────┘ │
│   localhost         127.0.0.1   │
└──────────────────────────────────┘
```

**App 관점:**
```java
// App은 localhost로 연결 (간단!)
dbConnection = connect("localhost:5432");

// Ambassador가 실제 DB로 프록시
// localhost:5432 → prod-db.example.com:5432
```

---

## 2. 사용 사례

### 1. DB Connection Proxy

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
    env:
    - name: DB_HOST
      value: "localhost"  # Ambassador로 연결
    - name: DB_PORT
      value: "5432"

  # Ambassador (Cloud SQL Proxy)
  - name: cloudsql-proxy
    image: gcr.io/cloudsql-docker/gce-proxy:latest
    command:
    - "/cloud_sql_proxy"
    - "-instances=project:region:instance=tcp:5432"
```

---

### 2. Cache Proxy (Redis)

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: myapp
spec:
  containers:
  - name: app
    image: myapp:1.0
    env:
    - name: REDIS_URL
      value: "redis://localhost:6379"

  # Redis Ambassador
  - name: redis-proxy
    image: haproxy:latest
    ports:
    - containerPort: 6379
    volumeMounts:
    - name: config
      mountPath: /usr/local/etc/haproxy

  volumes:
  - name: config
    configMap:
      name: redis-proxy-config
```

```
# HAProxy Config
frontend redis
    bind *:6379
    default_backend redis_backend

backend redis_backend
    balance roundrobin
    server redis1 redis-master:6379 check
    server redis2 redis-replica1:6379 check backup
    server redis3 redis-replica2:6379 check backup
```

---

### 3. API Gateway Ambassador

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: myapp
spec:
  containers:
  - name: app
    image: myapp:1.0

  # Nginx Ambassador (API Gateway)
  - name: nginx-ambassador
    image: nginx:latest
    ports:
    - containerPort: 80
    volumeMounts:
    - name: nginx-config
      mountPath: /etc/nginx/nginx.conf
      subPath: nginx.conf
```

```nginx
# Nginx Config
server {
    listen 80;

    # Rate Limiting
    limit_req_zone $binary_remote_addr zone=api_limit:10m rate=10r/s;

    location /api/ {
        limit_req zone=api_limit burst=20;

        # 실제 앱으로 프록시
        proxy_pass http://localhost:8080;
        proxy_set_header Host $host;
    }
}
```

---

## 3. Sidecar vs Ambassador

### 📊 비교

| 특징 | Sidecar | Ambassador |
|------|---------|-----------|
| **목적** | 공통 기능 확장 | 네트워크 프록시 |
| **방향** | 양방향 (in/out) | 주로 Outbound |
| **예시** | 로깅, 모니터링 | DB Proxy, API Gateway |
| **위치** | 애플리케이션 옆 | 네트워크 앞 |

---

## 4. 장단점

### ✅ 장점

1. **네트워크 투명성**
   - App은 localhost로 간단하게 연결

2. **연결 관리**
   - Connection pooling
   - Retry, Circuit breaker

3. **보안 강화**
   - mTLS, 암호화
   - 인증 토큰 주입

### ❌ 단점

1. **지연 시간**
   - 프록시 홉 추가

2. **리소스**
   - 추가 컨테이너 필요

3. **복잡도**
   - 설정 및 관리 복잡

---

## 5. 사용 시기

### ✅ 적합한 경우

- Cloud 서비스 연결 (Cloud SQL, Redis)
- 복잡한 네트워크 라우팅
- Connection pooling 필요

### ❌ 부적합한 경우

- 직접 연결 가능
- 저지연 필수

---

## 📚 참고 자료

- [[Sidecar-패턴|Sidecar 패턴]]

---

**상위 문서**: [[_README|배포 인프라 패턴 폴더]]
**마지막 업데이트**: 2026-01-05
