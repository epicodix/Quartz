---
title: Istio + 모니터링 통합 - 복잡도 폭발 해결
tags:
  - Istio
  - ServiceMesh
  - Prometheus
  - Kiali
  - mTLS
aliases:
  - Istio모니터링통합
  - 서비스메시모니터링
date: 2025-12-09
category: K8s_Deep_Dive/프로메테우스/모니터링
status: 완성
priority: 높음
---

# Istio + 모니터링 통합

## 📌 핵심 문제
Istio를 추가하면 기존 모니터링이 **폭발**합니다.

## 🔥 복잡도 증가

### 원래 구조 (단순)
```
Prometheus → Blackbox Exporter → 타겟
```

### Istio 추가 후 (복잡)
```
Prometheus → [Istio Sidecar] → Blackbox Exporter → [Istio Sidecar] → 타겟
                ↓                                        ↓
            mTLS 암호화                              mTLS 암호화
            트래픽 정책                              서비스 메시 규칙
```

## 🚨 주요 문제 3가지

### 문제 1: 외부 타겟 접근 불가

#### 증상
```bash
kubectl logs blackbox-exporter-xxx

# 에러:
dial tcp: lookup google.com: no such host
connection refused
```

#### 원인
```
Istio 기본 정책:
- 메시 안의 통신만 허용
- 외부 인터넷 차단 (화이트리스트 방식)
```

#### 해결: ServiceEntry
```yaml
apiVersion: networking.istio.io/v1beta1
kind: ServiceEntry
metadata:
  name: external-services
  namespace: monitoring
spec:
  hosts:
  - google.com
  - example.com
  - "*.amazonaws.com"  # 와일드카드
  ports:
  - number: 443
    name: https
    protocol: HTTPS
  - number: 80
    name: http
    protocol: HTTP
  location: MESH_EXTERNAL  # 외부임을 선언
  resolution: DNS
```

**개념**: "이 도메인들은 나가도 돼" 허가증

---
title: Istio + 모니터링 통합
aliases:
  - 08-Istio-모니터링-통합
category: K8s_Deep_Dive/프로메테우스/모니터링
status: 완성
priority: 높음

### 문제 2: Prometheus가 메트릭 수집 불가

#### 증상
```bash
# Prometheus UI에서
up{job="blackbox"} = 0

# Prometheus 로그:
Get "http://blackbox-exporter:9115/probe": connection reset
```

#### 원인
```
Istio mTLS (상호 TLS 인증):
- 메시 안의 모든 통신 암호화
- 인증서 없으면 통신 불가

Prometheus:
- 일반 HTTP로 메트릭 수집
- mTLS 모름
→ 차단!
```

#### 해결 1: 모니터링 네임스페이스 Istio 제외 (추천 ⭐⭐⭐)
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: monitoring
  labels:
    istio-injection: disabled  # ← 핵심!
```

**장점**:
- 한 줄로 90% 문제 해결
- 기존 설정 그대로 사용
- 관리 부담 최소

**단점**:
- 모니터링 컴포넌트 간 트래픽 암호화 안 됨
  (보통 같은 클러스터라 괜찮음)

#### 해결 2: 특정 포트만 mTLS 끄기
```yaml
apiVersion: security.istio.io/v1beta1
kind: PeerAuthentication
metadata:
  name: blackbox-exporter-mtls
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app: blackbox-exporter
  mtls:
    mode: PERMISSIVE  # HTTP도 허용
  portLevelMtls:
    9115:  # Blackbox 포트
      mode: DISABLE  # 이 포트는 mTLS 끄기
```

---
title: Istio + 모니터링 통합
aliases:
  - 08-Istio-모니터링-통합
category: K8s_Deep_Dive/프로메테우스/모니터링
status: 완성
priority: 높음

### 문제 3: Health Check 실패로 Pod 재시작

#### 증상
```bash
kubectl get pods
# blackbox-exporter-xxx  0/2  CrashLoopBackOff

kubectl describe pod blackbox-exporter-xxx
# Liveness probe failed: connection refused
```

#### 원인
```
Kubernetes Liveness Probe:
→ /health 체크
→ Istio mTLS 때문에 실패
→ Pod 재시작 무한 루프
```

#### 해결
```yaml
apiVersion: apps/v1
kind: Deployment
spec:
  template:
    spec:
      containers:
      - name: blackbox-exporter
        livenessProbe:
          httpGet:
            path: /health
            port: 9115
            scheme: HTTP  # HTTPS 아님!
          initialDelaySeconds: 30  # 넉넉하게
```

## 🎯 실무 권장 패턴

### 패턴 1: 모니터링 격리 (가장 간단)
```yaml
# 모니터링 네임스페이스 전체 Istio 제외
apiVersion: v1
kind: Namespace
metadata:
  name: monitoring
  labels:
    istio-injection: disabled
```

**사용 케이스**: 대부분의 경우 (90%)

### 패턴 2: 외부 타겟만 등록
```yaml
# 자주 체크하는 외부 API들
apiVersion: networking.istio.io/v1beta1
kind: ServiceEntry
metadata:
  name: blackbox-targets
spec:
  hosts:
  - api.payment.com
  - api.weather.com
  - "*.google.com"
  ports:
  - number: 443
    name: https
    protocol: HTTPS
  location: MESH_EXTERNAL
```

**사용 케이스**: 특정 외부 API만 체크할 때

### 패턴 3: 개발 환경용 (모든 외부 허용)
```yaml
apiVersion: networking.istio.io/v1beta1
kind: ServiceEntry
metadata:
  name: allow-all-external
spec:
  hosts:
  - "*"  # 모든 외부 도메인
  ports:
  - number: 443
    name: https
    protocol: HTTPS
  - number: 80
    name: http
    protocol: HTTP
  location: MESH_EXTERNAL
```

**주의**: 프로덕션에서는 보안상 비추천

## 🔧 완전한 설정 예시

```yaml
# 1. 모니터링 네임스페이스 (Istio 제외)
apiVersion: v1
kind: Namespace
metadata:
  name: monitoring
  labels:
    istio-injection: disabled

---
title: Istio + 모니터링 통합
aliases:
  - 08-Istio-모니터링-통합
category: K8s_Deep_Dive/프로메테우스/모니터링
status: 완성
priority: 높음
# 2. Blackbox ConfigMap
apiVersion: v1
kind: ConfigMap
metadata:
  name: blackbox-config
  namespace: monitoring
data:
  blackbox.yml: |
    modules:
      http_2xx:
        prober: http
        timeout: 5s
        http:
          valid_status_codes: []
          method: GET
          fail_if_not_ssl: true

---
title: Istio + 모니터링 통합
aliases:
  - 08-Istio-모니터링-통합
category: K8s_Deep_Dive/프로메테우스/모니터링
status: 완성
priority: 높음
# 3. Blackbox Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: blackbox-exporter
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app: blackbox-exporter
  template:
    metadata:
      labels:
        app: blackbox-exporter
    spec:
      containers:
      - name: blackbox-exporter
        image: prom/blackbox-exporter:v0.24.0
        args:
        - "--config.file=/config/blackbox.yml"
        ports:
        - containerPort: 9115
        volumeMounts:
        - name: config
          mountPath: /config
        livenessProbe:
          httpGet:
            path: /health
            port: 9115
          initialDelaySeconds: 30
      volumes:
      - name: config
        configMap:
          name: blackbox-config

---
title: Istio + 모니터링 통합
aliases:
  - 08-Istio-모니터링-통합
category: K8s_Deep_Dive/프로메테우스/모니터링
status: 완성
priority: 높음
# 4. Blackbox Service
apiVersion: v1
kind: Service
metadata:
  name: blackbox-exporter
  namespace: monitoring
spec:
  selector:
    app: blackbox-exporter
  ports:
  - port: 9115
    targetPort: 9115

---
title: Istio + 모니터링 통합
aliases:
  - 08-Istio-모니터링-통합
category: K8s_Deep_Dive/프로메테우스/모니터링
status: 완성
priority: 높음
# 5. 외부 타겟 허용 (필요시)
apiVersion: networking.istio.io/v1beta1
kind: ServiceEntry
metadata:
  name: external-targets
  namespace: monitoring
spec:
  hosts:
  - google.com
  - "*.amazonaws.com"
  ports:
  - number: 443
    name: https
    protocol: HTTPS
  location: MESH_EXTERNAL
  resolution: DNS
```

## 🔍 트러블슈팅 체크리스트

### 1단계: Pod 상태 확인
```bash
# Pod Running인지 확인
kubectl get pod -n monitoring | grep blackbox

# Istio 사이드카 없는지 확인 (있으면 문제)
kubectl get pod blackbox-exporter-xxx -n monitoring \
  -o jsonpath='{.spec.containers[*].name}'
# 출력: blackbox-exporter (istio-proxy 없어야 함)
```

### 2단계: 외부 접근 테스트
```bash
# Blackbox에서 직접 외부 접근 테스트
kubectl exec -it blackbox-exporter-xxx -n monitoring -- \
  wget -O- https://google.com

# 성공하면 OK
# 실패하면 ServiceEntry 필요
```

### 3단계: Prometheus 수집 테스트
```bash
# Port-forward
kubectl port-forward -n monitoring svc/blackbox-exporter 9115:9115

# 로컬에서 테스트
curl "http://localhost:9115/probe?target=https://google.com&module=http_2xx"

# probe_success 1 나오면 OK
```

### 4단계: Prometheus 확인
```
Prometheus UI → Status → Targets
blackbox job이 UP이어야 함
```

## 📊 문제별 해결 요약

| 문제 | 원인 | 해결 |
|------|------|------|
| 외부 접근 안 됨 | Istio 외부 차단 | ServiceEntry 또는 네임스페이스 Istio 제외 |
| 메트릭 수집 안 됨 | mTLS 인증 실패 | 네임스페이스 Istio 제외 (권장) |
| Pod 재시작 반복 | Health check 실패 | Probe 설정 수정 또는 Istio 제외 |

## 🔗 연관 개념
- [[04-Prometheus-Blackbox-Exporter]] - Blackbox 기본 개념
- [[09-모니터링-스택-설치-순서]] - 올바른 설치 순서
- [[Istio-기본-개념]] - Istio mTLS 이해

## 💡 핵심 교훈
```
복잡도 최소화가 답:
- monitoring 네임스페이스는 Istio 제외
- 90% 문제 해결
- 나중에 필요하면 세밀하게 조정
```

## 📚 더 읽어보기
- [Istio ServiceEntry](https://istio.io/latest/docs/reference/config/networking/service-entry/)
- [Istio mTLS Troubleshooting](https://istio.io/latest/docs/ops/common-problems/security-issues/)
