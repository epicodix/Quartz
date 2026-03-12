---
title: CKA YAML 치트시트 - 손으로 외우기
tags:
  - kubernetes
  - cka
  - cheatsheet
  - yaml
aliases:
  - CKA치트시트
  - YAML템플릿
date: 2026-02-17
category: K8s_Deep_Dive/k8s실습
status: 완성
priority: 높음
---

# CKA YAML 치트시트 - 손으로 외우기

> [!tip] 사용법
> 출력해서 빈 종이에 보지 않고 따라 쓰는 연습!
> 3번 이상 반복하면 시험장에서 안 보고 씀

---

## 1. PersistentVolume (PV)

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: ___
spec:
  capacity:
    storage: ___Gi
  accessModes:
    - ReadWriteOnce
  storageClassName: ___
  hostPath:
    path: /___
```

---

## 2. PersistentVolumeClaim (PVC)

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: ___
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: ___
  resources:
    requests:
      storage: ___Mi
```

---

## 3. Pod + PVC 마운트

```yaml
spec:
  volumes:
  - name: ___
    persistentVolumeClaim:
      claimName: ___
  containers:
  - name: ___
    image: ___
    volumeMounts:
    - mountPath: /___
      name: ___
```

---

## 4. Pod + ConfigMap (envFrom)

```yaml
spec:
  containers:
  - name: ___
    image: ___
    envFrom:
    - configMapRef:
        name: ___
```

---

## 5. Pod + Secret 볼륨 마운트

```yaml
spec:
  volumes:
  - name: ___
    secret:
      secretName: ___
  containers:
  - name: ___
    image: ___
    command: ["sleep", "3600"]
    volumeMounts:
    - name: ___
      mountPath: /___
```

---

## 6. Pod + 리소스 제한

```yaml
spec:
  containers:
  - name: ___
    image: ___
    resources:
      requests:
        memory: "___Mi"
        cpu: "___m"
      limits:
        memory: "___Mi"
        cpu: "___m"
```

---

## 7. 멀티 컨테이너 + 공유 볼륨

```yaml
spec:
  containers:
  - name: ___
    image: ___
    volumeMounts:
    - mountPath: /___
      name: ___
  - name: ___
    image: ___
    command: ["sleep", "3600"]
    volumeMounts:
    - mountPath: /___
      name: ___
  volumes:
  - name: ___
    emptyDir: {}
```

---

## 8. NodeSelector

```yaml
spec:
  containers:
  - name: ___
    image: ___
  nodeSelector:
    ___: ___
```

---

## 9. NetworkPolicy

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: ___
spec:
  podSelector:
    matchLabels:
      ___: ___
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          ___: ___
    ports:
    - protocol: TCP
      port: ___
```

---

## 10. Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ___
spec:
  rules:
  - host: ___
    http:
      paths:
      - path: /___
        pathType: Prefix
        backend:
          service:
            name: ___
            port:
              number: ___
```

---

## 11. Init Container

```yaml
spec:
  initContainers:
  - name: ___
    image: ___
    command: ["sh", "-c", "___"]
  containers:
  - name: ___
    image: ___
```

---

## 12. Toleration (Taint 허용)

```yaml
spec:
  containers:
  - name: ___
    image: ___
  tolerations:
  - key: "___"
    operator: "Equal"
    value: "___"
    effect: "NoSchedule"
```

---

## 13. Sidecar 패턴

```yaml
spec:
  containers:
  - name: ___
    image: nginx
    volumeMounts:
    - name: ___
      mountPath: /var/log/nginx
  - name: ___
    image: busybox
    command: ["tail", "-f", "/var/log/nginx/access.log"]
    volumeMounts:
    - name: ___
      mountPath: /var/log/nginx
  volumes:
  - name: ___
    emptyDir: {}
```

---

## kubectl 명령어 빠른 참조

```bash
# Pod 생성 (dry-run YAML 뽑기)
kubectl run ___ --image=___ --dry-run=client -o yaml > ___.yaml

# Deployment 생성
kubectl create deployment ___ --image=___ --replicas=___

# ConfigMap 생성
kubectl create configmap ___ --from-literal=KEY=VALUE

# Secret 생성
kubectl create secret generic ___ --from-literal=KEY=VALUE

# Service 노출
kubectl expose deployment ___ --name=___ --port=___

# 라벨 추가
kubectl label TYPE NAME key=value

# Pod template 라벨 (patch)
kubectl patch deployment ___ -p '{"spec":{"template":{"metadata":{"labels":{"key":"value"}}}}}'

# 노드 라벨
kubectl label node ___ key=value

# Taint 추가
kubectl taint node ___ key=value:NoSchedule

# Role 생성
kubectl create role ___ --verb=get,list,watch --resource=pods -n ___

# RoleBinding 생성
kubectl create rolebinding ___ --role=___ --user=___ -n ___

# ResourceQuota 생성
kubectl create quota ___ --hard=pods=10,requests.cpu=4,requests.memory=4Gi -n ___

# 롤링 업데이트
kubectl set image deployment/___ ___=image:tag

# 롤백
kubectl rollout undo deployment/___

# 스케일
kubectl scale deployment ___ --replicas=___

# 로그 (마지막 50줄)
kubectl logs ___ -n ___ --tail=50

# Exec
kubectl exec -it ___ -n ___ -- /bin/sh
```

---

> [!warning] 자주 틀리는 포인트
> - `volumeMounts` M 대문자!
> - `volumemounts` (X) `volumeMounts` (O)
> - `storageClassName` 대소문자 주의
> - `persistentVolumeClaim` 대소문자 주의
> - `envFrom` vs `env` + `valueFrom` 구분
> - `nodeSelector`는 `containers`와 같은 레벨 (spec 바로 아래)
> - `volumes`도 `containers`와 같은 레벨
> - `tolerations`도 `containers`와 같은 레벨
