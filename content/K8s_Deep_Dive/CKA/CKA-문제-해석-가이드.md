---
title: CKA 문제 해석 가이드 - 25문제 전체
tags:
  - cka
  - kubernetes
  - kubectl
  - 영어해석
  - 치트시트
aliases:
  - CKA 영어 패턴
  - 문제 키워드 매핑
date: 2026-02-08
category: K8s_Deep_Dive/CKA
status: 완성
priority: 높음
---

# 🎯 CKA 문제 해석 가이드 (25문제)

> [!tip] 핵심
> 문제 영어 → kubectl 명령어로 1:1 매핑. 문제별로 "뭘 만들고, 어떤 옵션이 필요한지" 빠르게 파악

---

## 📑 목차
- [[#📗 BASIC (Q1-Q10)|BASIC Q1-Q10]]
- [[#📙 INTERMEDIATE (Q11-Q20)|INTERMEDIATE Q11-Q20]]
- [[#📕 ADVANCED (Q21-Q25)|ADVANCED Q21-Q25]]

---

## 📗 BASIC (Q1-Q10)

### Q1. Pod 생성 (3분)

> Create a pod named "web-pod" using the nginx:1.25 image in the namespace "dev". The pod should have a label "app=web".

| 문장 | 명령어 |
|-----|--------|
| Create a pod | `kubectl run` |
| named "web-pod" | `web-pod` |
| using nginx:1.25 | `--image=nginx:1.25` |
| in namespace "dev" | `-n dev` |
| label "app=web" | `--labels='app=web'` |

```bash
kubectl run web-pod --image=nginx:1.25 -n dev --labels='app=web'
```

> [!note] 포인트
> "Create a pod" = `kubectl run` (deployment 아님!)

---

### Q2. Deployment 생성 (3분)

> Create a deployment named "api-deploy" in the default namespace. Image: httpd:2.4, Replicas: 3, Label: tier=backend

| 문장 | 명령어 |
|-----|--------|
| Create a deployment | `kubectl create deployment` |
| named "api-deploy" | `api-deploy` |
| Image: httpd:2.4 | `--image=httpd:2.4` |
| Replicas: 3 | `--replicas=3` |
| Label: tier=backend | **별도 명령!** |

```bash
kubectl create deployment api-deploy --image=httpd:2.4 --replicas=3
kubectl label deployment api-deploy tier=backend
```

> [!danger] 함정
> `kubectl create deployment`에는 `--labels` 옵션이 **없다!**

---

### Q3. Service 노출 (3분)

> Expose the deployment "api-deploy" as a ClusterIP service named "api-svc" on port 80.

| 문장 | 명령어 |
|-----|--------|
| Expose | `kubectl expose` |
| deployment "api-deploy" | `deployment api-deploy` |
| as a ClusterIP service | `--type=ClusterIP` (기본값) |
| named "api-svc" | `--name=api-svc` |
| on port 80 | `--port=80` |

```bash
kubectl expose deployment api-deploy --name=api-svc --port=80
```

> [!warning] 주의
> `--name` = 서비스 이름, `--cluster-ip` = IP 주소 (다른 용도!)

---

### Q4. ConfigMap + Pod (5분)

> Create a ConfigMap named "app-config" with: DB_HOST=mysql.default.svc, DB_PORT=3306. Create a pod named "config-pod" using nginx that loads this ConfigMap as environment variables.

**Part 1: ConfigMap**

```bash
kubectl create configmap app-config \
  --from-literal=DB_HOST=mysql.default.svc \
  --from-literal=DB_PORT=3306
```

**Part 2: Pod** - "as environment variables" = `envFrom`

```bash
kubectl run config-pod --image=nginx --dry-run=client -o yaml > pod.yaml
# envFrom 섹션 추가 후 apply
```

```yaml
    envFrom:
    - configMapRef:
        name: app-config
```

---

### Q5. Secret + Volume Mount (7분)

> Create a Secret named "db-secret" with: username=admin, password=secretpass123. Create a pod "secret-pod" using busybox that mounts the secret as a volume at /etc/secrets. Command: sleep 3600

**Part 1: Secret**

```bash
kubectl create secret generic db-secret \
  --from-literal=username=admin \
  --from-literal=password=secretpass123
```

**Part 2: Pod** - "mount as a volume at /path" = `volumes` + `volumeMounts`

```bash
kubectl run secret-pod --image=busybox --dry-run=client -o yaml --command -- sleep 3600 > pod.yaml
```

```yaml
    volumeMounts:
    - name: secret-vol
      mountPath: /etc/secrets
  volumes:
  - name: secret-vol
    secret:
      secretName: db-secret
```

---

### Q6. Resource Limits (5분)

> Create a pod named "limited-pod" with nginx image. Memory request: 64Mi, limit: 128Mi. CPU request: 100m, limit: 200m.

```bash
kubectl run limited-pod --image=nginx:1.25 --dry-run=client -o yaml > pod.yaml
# resources 섹션 추가
```

```yaml
    resources:
      requests:
        memory: "64Mi"
        cpu: "100m"
      limits:
        memory: "128Mi"
        cpu: "200m"
```

> [!tip] 포인트
> `resources` → `requests`/`limits` → `memory`/`cpu` 3단 구조

---

### Q7. Multi-Container + Shared Volume (7분)

> Create pod "multi-pod" with two containers: web(nginx), logger(busybox, sleep 3600). Both share volume "shared-data" mounted at /data.

```bash
kubectl run multi-pod --image=nginx --dry-run=client -o yaml > pod.yaml
# 두 번째 컨테이너 + volumes 추가
```

```yaml
spec:
  volumes:
  - name: shared-data
    emptyDir: {}
  containers:
  - name: web
    image: nginx
    volumeMounts:
    - name: shared-data
      mountPath: /data
  - name: logger
    image: busybox
    command: ["sleep", "3600"]
    volumeMounts:
    - name: shared-data
      mountPath: /data
```

> [!danger] 주의
> - `volumes`는 `spec` 바로 아래 (containers와 같은 레벨)
> - 두 번째 컨테이너는 `containers:` 배열에 `-`로 추가
> - `emptyDir: {}` 중괄호 필수

---

### Q8. Node Selector (5분)

> Label node with "disk=ssd". Create pod "node-pod" with nginx that only runs on disk=ssd nodes.

**Part 1: 노드 라벨링**

```bash
# 노드 이름 확인
kubectl get nodes
# 라벨 추가
kubectl label node NODE_NAME disk=ssd
```

**Part 2: Pod with nodeSelector**

```bash
kubectl run node-pod --image=nginx --dry-run=client -o yaml > pod.yaml
# nodeSelector 추가
```

```yaml
spec:
  nodeSelector:
    disk: ssd
  containers:
  - name: node-pod
    image: nginx
```

> [!tip] 포인트
> `nodeSelector`는 `spec` 바로 아래 (containers와 같은 레벨)
> key: value 형태 (= 아님!)

---

### Q9. ServiceAccount (5분)

> Create namespace "prod" if not exists. Create ServiceAccount "app-sa" in namespace "prod". Create pod "sa-pod" using nginx in "prod" with ServiceAccount "app-sa".

```bash
kubectl create namespace prod --dry-run=client -o yaml | kubectl apply -f -
kubectl create serviceaccount app-sa -n prod
kubectl run sa-pod --image=nginx -n prod --dry-run=client -o yaml > pod.yaml
# serviceAccountName 추가
```

```yaml
spec:
  serviceAccountName: app-sa
  containers:
  - name: sa-pod
    image: nginx
```

> [!tip] 포인트
> `serviceAccountName`은 `spec` 바로 아래

---

### Q10. 디버깅 (5분)

> Run: kubectl run broken-pod --image=nginx:nonexistent-tag. Debug and fix the issue so the pod runs successfully.

```bash
# 1. 상태 확인
kubectl get pods
kubectl describe pod broken-pod

# 2. 이미지 수정
kubectl set image pod/broken-pod broken-pod=nginx:latest

# 또는 edit로 수정
kubectl edit pod broken-pod
# image: nginx:nonexistent-tag → image: nginx:latest
```

> [!tip] 포인트
> `kubectl describe`로 Events 확인 → ImagePullBackOff/ErrImagePull 확인
> `kubectl set image`로 빠르게 이미지 변경

---

## 📙 INTERMEDIATE (Q11-Q20)

### Q11. PersistentVolume (5분)

> Create PV "pv-data": Capacity 1Gi, ReadWriteOnce, Host Path /mnt/data, Storage Class manual

전체 YAML 작성 필요 (imperative 명령 없음)

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-data
spec:
  capacity:
    storage: 1Gi
  accessModes:
  - ReadWriteOnce
  hostPath:
    path: /mnt/data
  storageClassName: manual
```

```bash
kubectl apply -f pv.yaml
kubectl get pv
```

> [!warning] 주의
> PV는 `kubectl create` 명령이 없음! YAML 직접 작성 필수
> `kubectl explain pv.spec`으로 필드 확인

---

### Q12. PVC + Pod (5분)

> Create PVC "pvc-data": 500Mi, ReadWriteOnce, storageClass manual. Create pod "pvc-pod" with nginx mounting PVC at /usr/share/nginx/html

**Part 1: PVC**

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-data
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 500Mi
  storageClassName: manual
```

**Part 2: Pod**

```yaml
spec:
  volumes:
  - name: pvc-vol
    persistentVolumeClaim:
      claimName: pvc-data
  containers:
  - name: pvc-pod
    image: nginx
    volumeMounts:
    - name: pvc-vol
      mountPath: /usr/share/nginx/html
```

> [!tip] 포인트
> PVC 볼륨 = `persistentVolumeClaim.claimName`
> PV의 storageClassName과 PVC의 storageClassName이 일치해야 바인딩됨

---

### Q13. Rolling Update (5분)

> Create deployment "rolling-deploy": nginx:1.19, Replicas 4. Update image to nginx:1.25. Verify rollout status.

```bash
# 생성
kubectl create deployment rolling-deploy --image=nginx:1.19 --replicas=4

# 이미지 업데이트
kubectl set image deployment/rolling-deploy nginx=nginx:1.25

# 롤아웃 상태 확인
kubectl rollout status deployment/rolling-deploy

# 히스토리 확인
kubectl rollout history deployment/rolling-deploy
```

> [!tip] 포인트
> `kubectl set image deployment/NAME CONTAINER=IMAGE`
> 컨테이너 이름은 `kubectl describe deployment`로 확인

---

### Q14. Rollback (3분)

> Rollback "rolling-deploy" to previous version. Verify image is back to nginx:1.19.

```bash
# 롤백
kubectl rollout undo deployment/rolling-deploy

# 확인
kubectl describe deployment rolling-deploy | grep Image
```

---

### Q15. Scale (2분)

> Scale deployment "rolling-deploy" to 6 replicas.

```bash
kubectl scale deployment rolling-deploy --replicas=6
kubectl get deployment rolling-deploy
```

---

### Q16. NetworkPolicy (7분)

> Create NetworkPolicy "api-netpol" in default namespace: Applies to pods with label "app=api". Allow ingress only from pods with label "app=web". Allow only port 80.

YAML 직접 작성 필요

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: api-netpol
  namespace: default
spec:
  podSelector:
    matchLabels:
      app: api
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: web
    ports:
    - protocol: TCP
      port: 80
```

> [!warning] 주의
> - `podSelector` = 이 정책이 **적용되는** 대상
> - `ingress.from.podSelector` = 허용할 **출발지**
> - `kubectl explain networkpolicy.spec`으로 구조 확인

---

### Q17. Role (5분)

> Create Role "pod-reader" in namespace "dev": Allows get, list, watch on pods.

```bash
kubectl create role pod-reader \
  --verb=get --verb=list --verb=watch \
  --resource=pods \
  -n dev
```

> [!tip] 포인트
> `--verb`를 각각 반복! (`--from-literal`과 같은 패턴)

---

### Q18. RoleBinding (5분)

> Create RoleBinding "read-pods" in namespace "dev": Bind role "pod-reader" to user "jane".

```bash
kubectl create rolebinding read-pods \
  --role=pod-reader \
  --user=jane \
  -n dev
```

---

### Q19. Logs & Exec (3분)

> Given pod "web-pod" in namespace "dev": 1) Get last 50 lines of logs. 2) Exec into pod and run: cat /etc/os-release

```bash
# 마지막 50줄
kubectl logs web-pod -n dev --tail=50

# exec
kubectl exec web-pod -n dev -- cat /etc/os-release
```

> [!tip] 포인트
> `--tail=N` = 마지막 N줄
> `exec` 뒤에 `--` 필수

---

### Q20. ResourceQuota (5분)

> Create ResourceQuota "dev-quota" in namespace "dev": Max pods 10, requests.cpu 4, requests.memory 4Gi.

```bash
kubectl create quota dev-quota -n dev \
  --hard=pods=10,requests.cpu=4,requests.memory=4Gi
```

> [!tip] 포인트
> `kubectl create quota`로 imperative 생성 가능!
> `--hard=key=value,key=value` 콤마로 구분 (--from-literal과 다름!)

---

## 📕 ADVANCED (Q21-Q25)

### Q21. Ingress (7분)

> Create Ingress "web-ingress": Host myapp.example.com, Path /api, Backend service "api-svc" port 80.

```bash
kubectl create ingress web-ingress \
  --rule="myapp.example.com/api=api-svc:80"
```

또는 YAML:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web-ingress
spec:
  rules:
  - host: myapp.example.com
    http:
      paths:
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: api-svc
            port:
              number: 80
```

> [!tip] 포인트
> `kubectl create ingress`로 imperative 가능!
> `--rule="host/path=service:port"` 형식

---

### Q22. Init Container (7분)

> Create pod "init-pod" with: Init container name=init, image=busybox, command: ["sh", "-c", "echo 'init' && sleep 5"]. Main container name=main, image=nginx.

```bash
kubectl run init-pod --image=nginx --dry-run=client -o yaml > pod.yaml
# initContainers 섹션 추가
```

```yaml
spec:
  initContainers:
  - name: init
    image: busybox
    command: ["sh", "-c", "echo 'init' && sleep 5"]
  containers:
  - name: main
    image: nginx
```

> [!danger] 주의
> `initContainers`는 `containers`와 같은 레벨 (`spec` 바로 아래)
> Init이 완료되어야 Main이 시작됨

---

### Q23. Taint & Toleration (5분)

> 1) Taint node: key=dedicated, value=web, effect=NoSchedule. 2) Create pod "taint-pod" with nginx that tolerates this taint.

**Part 1: Taint 추가**

```bash
kubectl taint nodes NODE_NAME dedicated=web:NoSchedule
```

**Part 2: Pod with Toleration**

```yaml
spec:
  tolerations:
  - key: "dedicated"
    operator: "Equal"
    value: "web"
    effect: "NoSchedule"
  containers:
  - name: taint-pod
    image: nginx
```

> [!tip] 포인트
> Taint = 노드에 "경고 딱지" 붙이기
> Toleration = Pod에 "이 딱지 괜찮아" 설정
> `kubectl explain pod.spec.tolerations`

---

### Q24. Sidecar 로그 패턴 (7분)

> Create pod "sidecar-pod": Main nginx writes logs to /var/log/nginx. Sidecar busybox runs "tail -f /var/log/nginx/access.log". Share volume "logs".

```yaml
spec:
  volumes:
  - name: logs
    emptyDir: {}
  containers:
  - name: main
    image: nginx
    volumeMounts:
    - name: logs
      mountPath: /var/log/nginx
  - name: sidecar
    image: busybox
    command: ["tail", "-f", "/var/log/nginx/access.log"]
    volumeMounts:
    - name: logs
      mountPath: /var/log/nginx
```

> [!tip] 포인트
> Q7과 같은 패턴! emptyDir + 두 컨테이너가 같은 경로 마운트

---

### Q25. 클러스터 정보 조회 (5분)

> 1) List all nodes and status. 2) List pods in kube-system. 3) Get cluster version. 4) Check events in default namespace.

```bash
# 1. 노드 목록
kubectl get nodes

# 2. kube-system pods
kubectl get pods -n kube-system

# 3. 클러스터 버전
kubectl version

# 4. 이벤트
kubectl get events --sort-by='.lastTimestamp'
```

---

## 📊 난이도별 핵심 요약

| 구간 | 핵심 | imperative 가능 여부 |
|------|------|---------------------|
| Q1-Q7 | run/create + dry-run → yaml 편집 | 대부분 가능 |
| Q8-Q10 | nodeSelector, serviceAccount, 디버깅 | 부분 가능 |
| Q11-Q12 | PV/PVC | YAML 직접 작성 필수 |
| Q13-Q15 | rollout, scale | 전부 imperative |
| Q16 | NetworkPolicy | YAML 직접 작성 필수 |
| Q17-Q20 | RBAC, logs, quota | 전부 imperative |
| Q21-Q25 | Ingress, init, taint, sidecar | 혼합 |

> [!warning] YAML 직접 작성 필수 리소스
> PV, PVC, NetworkPolicy, Toleration → 이 4개는 반드시 YAML 구조 암기!
