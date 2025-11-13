---
creation_date: 2025-11-12
---

# 쿠버네티스 StatefulSet, Headless Service, ClusterIP 실습 가이드

이 가이드는 쿠버네티스에서 상태 유지가 필요한 애플리케이션(Stateful Application)을 배포하는 데 사용되는 `StatefulSet`과, 이를 지원하는 `Headless Service`의 개념을 실습 중심으로 설명합니다. 또한, 일반적인 `ClusterIP` 서비스와의 차이점을 코드를 통해 비교하여 개념을 명확히 이해할 수 있도록 돕습니다.

## 1. 왜 StatefulSet이 필요한가?

`Deployment`는 주로 상태가 없는(Stateless) 애플리케이션에 사용됩니다. 파드(Pod)가 다시 시작되면 내부 데이터가 사라지고, 파드의 이름이나 네트워크 주소(IP)도 예측 불가능하게 변경됩니다. 하지만 데이터베이스나 분산 시스템처럼 각 노드가 고유한 상태와 식별자를 가져야 하는 애플리케이션에는 적합하지 않습니다.

`StatefulSet`은 이러한 문제를 해결하기 위해 등장했으며, 다음과 같은 특징을 가집니다.

- **안정적이고 고유한 네트워크 식별자**: 파드는 `(StatefulSet 이름)-(순번)` 형식의 예측 가능한 호스트 이름을 갖습니다. (예: `web-0`, `web-1`)
- **안정적이고 지속적인 스토리지**: 각 파드는 고유한 `PersistentVolumeClaim`(PVC)을 통해 자신만의 영구 스토리지를 가집니다. 파드가 재시작되어도 동일한 스토리지에 다시 연결됩니다.
- **순차적인 배포 및 스케일링**: 파드는 정해진 순서(0, 1, 2...)에 따라 순차적으로 생성되고, 역순(..., 2, 1, 0)으로 삭제됩니다.

## 2. 실습 환경

이 실습은 로컬 쿠버네티스 환경인 `minikube`를 기준으로 설명합니다.

```bash
# minikube 시작
minikube start
```

---

## 3. Headless Service: 파드를 위한 고유 주소 생성

`StatefulSet`의 안정적인 네트워크 식별자를 구현하려면 `Headless Service`가 필수적입니다. 일반적인 서비스(`ClusterIP`)와 달리, `Headless Service`는 가상의 단일 IP 주소를 갖지 않습니다. 대신, 서비스에 속한 각 파드의 실제 IP 주소를 가리키는 DNS 레코드를 생성합니다.

이를 통해 클라이언트는 서비스 이름 대신 **개별 파드의 고유한 주소**(`web-0.nginx`, `web-1.nginx`)로 직접 통신할 수 있습니다.

### Headless Service YAML 작성

`headless-service.yaml` 파일을 생성합니다.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx # StatefulSet이 이 서비스를 참조할 이름
spec:
  ports:
  - port: 80
    name: web
  clusterIP: None # 이 부분이 Headless Service의 핵심입니다.
  selector:
    app: nginx # StatefulSet의 파드 라벨과 일치해야 합니다.
```

- `clusterIP: None`: 이 설정을 통해 쿠버네티스는 이 서비스에 가상 IP를 할당하지 않습니다.

### 서비스 생성 및 확인

```bash
# Headless Service 생성
kubectl apply -f headless-service.yaml

# 서비스 목록 확인
kubectl get svc nginx
```

**실행 결과:**
`CLUSTER-IP`가 일반적인 IP 주소가 아닌 `None`으로 표시되는 것을 확인할 수 있습니다.

```
NAME    TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
nginx   ClusterIP   None         <none>        80/TCP    5s
```

---

## 4. StatefulSet: 상태를 갖는 파드 배포

이제 위에서 만든 `Headless Service`를 사용하는 `StatefulSet`을 배포해 보겠습니다. 이 예제에서는 간단한 Nginx 웹서버를 사용합니다.

### StatefulSet YAML 작성

`statefulset.yaml` 파일을 생성합니다.

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: web
spec:
  serviceName: "nginx" # 사용할 Headless Service 이름
  replicas: 2 # 파드를 2개 생성
  selector:
    matchLabels:
      app: nginx # spec.template.metadata.labels와 일치해야 함
  template:
    metadata:
      labels:
        app: nginx # Headless Service의 selector와 일치해야 함
    spec:
      containers:
      - name: nginx
        image: nginx:1.19.0
        ports:
        - containerPort: 80
          name: web
        volumeMounts:
        - name: www
          mountPath: /usr/share/nginx/html # 볼륨을 마운트할 경로
  volumeClaimTemplates: # 각 파드를 위한 PVC를 자동으로 생성하는 템플릿
  - metadata:
      name: www
    spec:
      accessModes: [ "ReadWriteOnce" ]
      resources:
        requests:
          storage: 1Gi # 각 파드마다 1GB의 스토리지를 요청
```

- `serviceName: "nginx"`: 이 `StatefulSet`이 `nginx`라는 이름의 `Headless Service`에 속한다는 것을 명시합니다.
- `volumeClaimTemplates`: 이 부분이 `StatefulSet`의 핵심 기능 중 하나입니다. `replicas` 수만큼 `PersistentVolumeClaim`(PVC)을 자동으로 생성합니다.
  - `web-0` 파드는 `www-web-0`이라는 PVC를, `web-1` 파드는 `www-web-1`이라는 PVC를 갖게 됩니다.

### StatefulSet 생성 및 확인

```bash
# StatefulSet 생성
kubectl apply -f statefulset.yaml

# 파드 생성 과정 확인 (순차적으로 생성되는 것을 볼 수 있음)
kubectl get pods -w
```

**실행 결과:**
`web-0`이 먼저 생성되고 `Running` 상태가 된 후에 `web-1`이 생성되는 것을 확인할 수 있습니다.

```
NAME    READY   STATUS              RESTARTS   AGE
web-0   0/1     ContainerCreating   0          3s
web-0   1/1     Running             0          5s
web-1   0/1     ContainerCreating   0          5s
web-1   1/1     Running             0          7s
```

---

## 5. 네트워크 식별자 및 데이터 영속성 검증

### 고유 호스트 이름 확인

각 파드는 예측 가능한 고유한 호스트 이름을 갖습니다. `kubectl exec`를 통해 확인해 봅시다.

```bash
# web-0 파드의 호스트 이름 확인
kubectl exec web-0 -- hostname
# 출력: web-0

# web-1 파드의 호스트 이름 확인
kubectl exec web-1 -- hostname
# 출력: web-1
```

### DNS를 통한 파드 조회 (Headless Service의 역할)

`Headless Service`는 각 파드에 대해 `(파드이름).(서비스이름).(네임스페이스).svc.cluster.local` 형식의 DNS A 레코드를 생성합니다. `busybox` 같은 유틸리티 파드를 실행하여 `nslookup`으로 이를 확인할 수 있습니다.

```bash
# nslookup을 위한 임시 파드 실행
kubectl run -it --rm --image=busybox:1.28 dns-test -- /bin/sh

# 임시 파드 셸에서 아래 명령어 실행
# (서비스 이름으로 조회 시, 각 파드의 IP 목록이 반환됨)
nslookup nginx

# (개별 파드 주소로 조회 시, 해당 파드의 IP가 반환됨)
nslookup web-0.nginx
nslookup web-1.nginx
```

### 데이터 영속성 테스트

`StatefulSet`의 가장 중요한 기능인 데이터 영속성을 테스트해 보겠습니다. `web-0` 파드에 파일을 생성한 후, 파드를 삭제했다가 다시 생성되었을 때 파일이 남아있는지 확인합니다.

1. **`web-0` 파드에 데이터 쓰기**
   ```bash
   kubectl exec web-0 -- /bin/sh -c 'echo "Hello from web-0" > /usr/share/nginx/html/index.html'
   ```

2. **`web-0` 파드 삭제**
   `StatefulSet` 컨트롤러가 파드가 삭제된 것을 감지하고 즉시 동일한 이름(`web-0`)과 스토리지(`www-web-0`)를 가진 새 파드를 생성합니다.
   ```bash
   kubectl delete pod web-0
   ```

3. **새로 생성된 `web-0` 파드에서 데이터 확인**
   잠시 후 새 `web-0` 파드가 `Running` 상태가 되면 아래 명령어를 실행합니다.
   ```bash
   kubectl exec web-0 -- /bin/sh -c 'cat /usr/share/nginx/html/index.html'
   ```

**실행 결과:**
"Hello from web-0" 메시지가 그대로 출력되는 것을 볼 수 있습니다. 이는 파드가 삭제되어도 `PersistentVolume`에 저장된 데이터는 보존됨을 의미합니다.

---

## 6. 비교: Deployment와 ClusterIP 서비스

`StatefulSet`과 비교하기 위해 일반적인 `Deployment`와 `ClusterIP` 서비스 조합을 살펴보겠습니다.

### Deployment 및 ClusterIP 서비스 YAML

`deployment-service.yaml` 파일을 생성합니다.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-nginx-svc
spec:
  selector:
    app: my-nginx
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
  # clusterIP를 명시하지 않으면 기본값인 'ClusterIP' 타입으로 생성됨

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-nginx-deployment
spec:
  replicas: 2
  selector:
    matchLabels:
      app: my-nginx
  template:
    metadata:
      labels:
        app: my-nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.19.0
        ports:
        - containerPort: 80
```

### 생성 및 확인

```bash
kubectl apply -f deployment-service.yaml

# 서비스 확인
kubectl get svc my-nginx-svc
# 출력: CLUSTER-IP에 가상 IP가 할당됨

# 파드 확인
kubectl get pods -l app=my-nginx
# 출력: 파드 이름이 랜덤한 해시값으로 생성됨 (예: my-nginx-deployment-6b...-abcde)
```

`ClusterIP` 서비스는 단일 가상 IP를 통해 들어온 요청을 파드들에게 **로드 밸런싱**합니다. 개별 파드에 직접 접근할 수 있는 안정적인 주소를 제공하지 않으며, 파드 자체도 고유한 식별자나 영구 스토리지를 갖지 않습니다.

## 7. 정리

- **StatefulSet + Headless Service**:
  - **언제**: 데이터베이스, 메시지 큐, 분산 파일 시스템 등 각 노드가 고유한 상태와 식별자를 가져야 할 때 사용합니다.
  - **동작**: 예측 가능한 파드 이름(`web-0`), 고유한 DNS 주소(`web-0.nginx`), 그리고 파드와 1:1로 매핑되는 영구 스토리지(`www-web-0`)를 제공합니다.
  - **네트워크**: `Headless Service`는 파드에 직접 접근할 수 있는 DNS 레코드를 제공합니다.

- **Deployment + ClusterIP Service**:
  - **언제**: 웹서버, API 게이트웨이 등 상태가 없고 쉽게 복제하여 수평 확장이 가능한(Stateless) 애플리케이션에 사용합니다.
  - **동작**: 파드는 언제든지 교체될 수 있는 소모품으로 취급됩니다. 파드 이름과 IP는 동적으로 할당됩니다.
  - **네트워크**: `ClusterIP` 서비스는 단일 진입점(가상 IP)을 통해 요청을 여러 파드에 분산(로드 밸런싱)합니다.
