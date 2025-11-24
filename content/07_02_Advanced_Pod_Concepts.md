---
creation_date: 2025-11-24
---

# 07-02: 고급 파드 관리 및 스케줄링 전략

쿠버네티스에서 파드를 안정적으로 운영하고, 원하는 위치에 효율적으로 배포하기 위한 고급 개념들을 정리합니다.

## 1. Probe (프로브): 파드의 상태를 확인하는 건강검진

Kubelet(노드 관리자)이 파드 내 컨테이너의 상태를 주기적으로 확인하는 방법입니다. 프로브가 실패하면 쿠버네티스는 사전에 정의된 조치를 취합니다.

### Liveness Probe (활동성 프로브)
- **"살아있는가?"** 를 확인합니다.
- 컨테이너가 응답 불능 상태(데드락 등)에 빠졌을 때, 이를 감지하고 **컨테이너를 재시작**시켜 애플리케이션의 가용성을 회복시킵니다.
```yaml
livenessProbe:
  httpGet:
    path: /healthz
    port: 8080
  initialDelaySeconds: 5 # 파드 시작 후 5초 뒤부터 검사 시작
  periodSeconds: 10      # 10초마다 검사
```

### Readiness Probe (준비성 프로브)
- **"요청을 받을 준비가 되었는가?"** 를 확인합니다.
- 컨테이너가 시작되었더라도, 무거운 데이터를 로딩하는 등의 이유로 즉시 요청을 처리할 수 없을 때 사용됩니다.
- 프로브가 실패하면, 쿠버네티스 서비스(Service)는 해당 파드를 **서비스 엔드포인트에서 일시적으로 제외**하여 트래픽을 보내지 않습니다.
```yaml
readinessProbe:
  httpGet:
    path: /ready
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 5
```

### Startup Probe (시작 프로브)
- **"시작이 완료되었는가?"** 를 확인합니다.
- 시작하는 데 시간이 매우 오래 걸리는 레거시 애플리케이션에 유용합니다.
- 이 프로브가 성공할 때까지 Liveness/Readiness 프로브는 시작되지 않아, 느린 시작 때문에 파드가 재시작되는 것을 방지합니다.
```yaml
startupProbe:
  tcpSocket:
    port: 8080
  failureThreshold: 30  # 30번 실패 시 실패로 간주 (총 5분)
  periodSeconds: 10
```

---

## 2. Init Container (초기화 컨테이너)

메인 애플리케이션 컨테이너가 시작되기 **전에** 실행되어야 하는 사전 작업을 정의하는 컨테이너입니다.

- **용도**: 데이터베이스 스키마 마이그레이션, 필수 파일 다운로드, 설정 스크립트 실행 등
- **특징**:
  - 여러 개를 정의할 수 있으며, 정의된 순서대로 실행됩니다.
  - 모든 Init 컨테이너가 성공적으로 완료되어야만 메인 컨테이너가 시작됩니다.

```yaml
spec:
  initContainers:
  - name: init-myservice
    image: busybox:1.28
    command: ['sh', '-c', 'echo "Initializing..." && sleep 5']
  - name: init-mydb
    image: busybox:1.28
    command: ['sh', '-c', 'echo "Checking DB connection..." && sleep 5']
  containers:
  - name: main-app
    image: nginx
```

---

## 3. 멀티 컨테이너 디자인 패턴

하나의 파드 안에 여러 컨테이너를 함께 배치하여 기능을 확장하거나 문제를 해결하는 패턴입니다.

### Sidecar Pattern (사이드카 패턴)
메인 컨테이너의 핵심 기능에 영향을 주지 않으면서, 부가적인 기능을 추가하는 패턴입니다.
- **예시**: 로그 수집기, 서비스 메쉬 프록시(Istio-proxy), 데이터 동기화 등
- **장점**: 메인 애플리케이션의 코드 변경 없이 기능을 확장하고, 관심사를 분리할 수 있습니다.

```yaml
spec:
  containers:
  - name: main-app
    image: nginx
    volumeMounts:
    - name: shared-logs
      mountPath: /var/log/nginx
  - name: sidecar-log-collector # 사이드카 컨테이너
    image: busybox
    command: ["sh", "-c", "while true; do cat /var/log/nginx/access.log; sleep 30; done"]
    volumeMounts:
    - name: shared-logs
      mountPath: /var/log/nginx
  volumes:
  - name: shared-logs
    emptyDir: {}
```

### Ambassador Pattern (앰배서더 패턴)
메인 컨테이너가 외부 서비스와 통신하는 방식을 단순화시켜주는 프록시 역할을 합니다.
- **예시**: 서비스 디스커버리, 인증/인가, 요청 재시도, 샤딩(Sharding) 로직 처리
- **장점**: 메인 애플리케이션은 `localhost`로만 통신하면 되므로, 복잡한 외부 네트워크 환경으로부터 격리됩니다.

```yaml
spec:
  containers:
  - name: main-app
    # 이 앱은 localhost:9000 으로만 요청을 보냄
    image: my-app 
  - name: ambassador-proxy # 앰배서더 컨테이너
    image: envoyproxy/envoy
    # Envoy 설정은 복잡한 외부 DB 주소나 샤딩 로직을 처리
```

### Adapter Pattern (어댑터 패턴)
메인 컨테이너의 출력(로그, 메트릭 등)을 외부 시스템이 요구하는 표준화된 형식으로 변환합니다.
- **예시**: 다양한 형식의 애플리케이션 로그를 JSON 형식으로 통일하여 모니터링 시스템(Prometheus, Datadog)으로 전송
- **장점**: 애플리케이션의 로그/메트릭 출력 방식을 변경하지 않고도, 표준 모니터링 시스템과 통합할 수 있습니다.

```yaml
spec:
  containers:
  - name: main-app
    image: my-legacy-app
    # 이 앱은 /var/logs/app.log 에 일반 텍스트 로그를 남김
  - name: adapter-log-formatter # 어댑터 컨테이너
    image: fluentd
    # Fluentd는 app.log를 읽어 JSON으로 변환 후 중앙 로그 서버로 전송
```

---

## 4. Pod Affinity / Anti-Affinity (파드 어피니티 / 안티-어피니티)

파드를 **다른 파드와의 관계**에 따라 특정 노드에 함께 배치하거나, 혹은 떨어뜨려 배치하는 스케줄링 규칙입니다.

### Pod Affinity (파드 선호도)
- **"친한 파드와 같이 있자"**
- 특정 라벨을 가진 파드가 실행 중인 노드에 새로운 파드를 함께 배치합니다.
- **용도**: 네트워크 지연을 줄이기 위해 웹 서버와 캐시 서버를 같은 노드에 배치할 때 사용합니다.

```yaml
podAffinity:
  requiredDuringSchedulingIgnoredDuringExecution: # 반드시 함께
  - labelSelector:
      matchExpressions:
      - key: app
        operator: In
        values:
        - cache
    topologyKey: kubernetes.io/hostname
```

### Pod Anti-Affinity (파드 반선호도)
- **"싫어하는 파드와는 떨어져 있자"**
- 특정 라벨을 가진 파드가 실행 중인 노드를 피해 다른 노드에 배치합니다.
- **용도**: 고가용성을 위해 동일한 애플리케이션의 복제본들을 서로 다른 노드/존/리전에 분산시킬 때 사용합니다.

```yaml
podAntiAffinity:
  preferredDuringSchedulingIgnoredDuringExecution: # 가급적이면 떨어져서
  - weight: 100
    podAffinityTerm:
      labelSelector:
        matchExpressions:
        - key: app
          operator: In
          values:
          - my-app
      topologyKey: kubernetes.io/hostname
```

---

## 5. Topology Spread Constraints (토폴로지 분배 제약조건)

고가용성을 위해 파드를 여러 토폴로지 도메인(노드, 존, 리전 등)에 걸쳐 **최대한 균등하게 분배**하는 가장 강력하고 유연한 방법입니다.

- **용도**: 특정 노드나 존에 장애가 발생해도 서비스 전체에 미치는 영향을 최소화합니다.
- **주요 필드**:
  - `maxSkew`: 도메인 간에 허용되는 파드 수의 최대 불균형 값
  - `topologyKey`: 파드를 분배할 기준 (예: `kubernetes.io/hostname`, `topology.kubernetes.io/zone`)
  - `whenUnsatisfiable`: 제약조건을 만족할 수 없을 때의 동작 (`DoNotSchedule` 또는 `ScheduleAnyway`)

```yaml
topologySpreadConstraints:
- maxSkew: 1
  topologyKey: topology.kubernetes.io/zone # '존'을 기준으로 분배
  whenUnsatisfiable: DoNotSchedule
  labelSelector:
    matchLabels:
      app: my-distributed-app
- maxSkew: 1
  topologyKey: kubernetes.io/hostname # '노드'를 기준으로 분배
  whenUnsatisfiable: DoNotSchedule
  labelSelector:
    matchLabels:
      app: my-distributed-app
```
