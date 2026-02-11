---
title: CKA 실습 삽질 기록 - Q1~Q7
tags:
  - cka
  - kubernetes
  - kubectl
  - 실습
  - 삽질기록
aliases:
  - CKA Q1-Q7 삽질
  - kubectl 명령어 실수
date: 2026-02-08
category: K8s_Deep_Dive/k8s실습
status: 완성
priority: 높음
---

# 🎯 CKA 실습 삽질 기록 (Q1-Q7)

> [!warning] 소요 시간
> 2회차(Q1-Q5): 목표 21분 → **실제: 1시간 이상** 😭
> 3회차(Q1-Q7): 목표 30분 → **실제: ~50분** (장족의 발전!)

---

## 📑 목차
- [[#Q1. Pod 생성|Q1. Pod 생성]]
- [[#Q2. Deployment 생성|Q2. Deployment 생성]]
- [[#Q3. Service 노출|Q3. Service 노출]]
- [[#Q4. ConfigMap + Pod|Q4. ConfigMap + Pod]]
- [[#Q5. Secret + Volume Mount|Q5. Secret + Volume Mount]]
- [[#Q6. Resource Limits Pod|Q6. Resource Limits Pod]]
- [[#Q7. Multi-Container + Shared Volume|Q7. Multi-Container + Shared Volume]]
- [[#📊 핵심 교훈 요약|핵심 교훈 요약]]

---

## Q1. Pod 생성

> **문제**: nginx:1.25 이미지로 "web-pod" Pod 생성, namespace: dev, label: app=web

### 🚨 삽질 포인트

#### 1. Namespace 지정 위치 혼동

```bash
# ❌ 틀린 명령어
kubectl run web-pod --image=nginx:1.25 --labels=app=web --namespace dev

# ✅ 올바른 명령어
kubectl run web-pod --image=nginx:1.25 --labels=app=web -n dev
```

> [!tip] 핵심
> `-n` 또는 `--namespace=` 형태로 사용. `--namespace dev`처럼 `=` 없이 공백으로 쓰면 에러

#### 2. Labels 문법 혼동

```bash
# ❌ 틀린 문법
kubectl run web-pod --image=nginx:1.25 --labels app=web

# ✅ 올바른 문법
kubectl run web-pod --image=nginx:1.25 --labels=app=web
```

> [!note] 기억할 것
> `--labels`는 반드시 `=`로 연결해야 함

---

## Q2. Deployment 생성

> **문제**: httpd:2.4 이미지로 "api-deploy" Deployment 생성, replicas: 3, label: tier=backend

### 🚨 삽질 포인트

#### 1. `--labels` 플래그가 없다!

```bash
# ❌ 존재하지 않는 옵션
kubectl create deployment api-deploy --image=httpd:2.4 --replicas=3 --labels=tier=backend

# ✅ 올바른 방법: 생성 후 별도로 라벨 추가
kubectl create deployment api-deploy --image=httpd:2.4 --replicas=3
kubectl label deployment api-deploy tier=backend
```

> [!danger] 중요
> `kubectl create deployment`에는 `--labels` 옵션이 **없다**!
> Pod와 달리 Deployment는 라벨을 별도 명령으로 추가해야 함

#### 2. 라벨 적용 대상 확인

```bash
# Deployment 자체에 라벨 확인
kubectl get deployment api-deploy --show-labels

# Pod에 라벨 확인 (selector로 자동 생성됨)
kubectl get pods --selector=app=api-deploy --show-labels
```

---

## Q3. Service 노출

> **문제**: api-deploy를 ClusterIP 서비스 "api-svc"로 port 80에 노출

### 🚨 삽질 포인트

#### 1. expose 명령어에 TYPE 필요

```bash
# ❌ 타입 미지정 (기본값이 ClusterIP이긴 하지만 명시적으로!)
kubectl expose deployment api-deploy --port=80 --name=api-svc

# ✅ 타입 명시
kubectl expose deployment api-deploy --port=80 --name=api-svc --type=ClusterIP
```

#### 2. `--name` vs `--cluster-ip` 혼동

```bash
# ❌ 이름 지정 잘못
kubectl expose deployment api-deploy --port=80 --cluster-ip=api-svc

# ✅ 올바른 이름 지정
kubectl expose deployment api-deploy --port=80 --name=api-svc
```

> [!warning] 주의
> `--cluster-ip`는 IP 주소 지정용 (예: `--cluster-ip=10.96.0.100`)
> 서비스 이름은 `--name` 사용

---

## Q4. ConfigMap + Pod

> **문제**: ConfigMap "app-config" 생성 (DB_HOST, DB_PORT), Pod "config-pod"에서 환경변수로 로드

### 🚨 삽질 포인트

#### 1. `--from-literal` 여러 개 지정

```bash
# ❌ 콤마로 구분 (안됨)
kubectl create configmap app-config --from-literal=DB_HOST=mysql.default.svc,DB_PORT=3306

# ✅ 각각 따로 지정
kubectl create configmap app-config \
  --from-literal=DB_HOST=mysql.default.svc \
  --from-literal=DB_PORT=3306
```

> [!tip] 핵심
> `--from-literal`은 **각 키-값 쌍마다 반복** 사용

#### 2. Pod에서 ConfigMap 로드 - envFrom 문법

```yaml
# ❌ 틀린 YAML
spec:
  containers:
  - name: config-pod
    image: nginx
    env:
      configMapRef:
        name: app-config

# ✅ 올바른 YAML
spec:
  containers:
  - name: config-pod
    image: nginx
    envFrom:
    - configMapRef:
        name: app-config
```

> [!danger] 중요
> - `env`가 아니라 `envFrom` 사용
> - `envFrom`은 **배열 형태** (`-` 필요)

#### 3. 빠른 YAML 생성

```bash
# dry-run으로 YAML 생성
kubectl run config-pod --image=nginx --dry-run=client -o yaml > pod.yaml
# 이후 envFrom 섹션 추가
```

---

## Q5. Secret + Volume Mount

> **문제**: Secret "db-secret" 생성 (username, password), Pod "secret-pod"에서 /etc/secrets에 볼륨 마운트

### 🚨 삽질 포인트

#### 1. Secret 생성 - `--from-literal` 반복

```bash
# ❌ 틀린 방법
kubectl create secret generic db-secret --from-literal=username=admin,password=secretpass123

# ✅ 올바른 방법
kubectl create secret generic db-secret \
  --from-literal=username=admin \
  --from-literal=password=secretpass123
```

#### 2. `--dry-run` 위치

```bash
# ❌ 틀린 위치
kubectl run secret-pod --image=busybox --dry-run=client --command -- sleep 3600 -o yaml

# ✅ 올바른 위치 (-o yaml을 --dry-run 바로 뒤에)
kubectl run secret-pod --image=busybox --dry-run=client -o yaml --command -- sleep 3600
```

#### 3. volumeMounts 문법

```yaml
# ❌ 틀린 YAML (들여쓰기, 구조 오류)
spec:
  containers:
  - name: secret-pod
    volumeMounts:
    - name: secret-vol
      mountPath: /etc/secrets
  volumes:
    - name: secret-vol
      secret:
        secretName: db-secret

# ✅ 올바른 YAML
spec:
  containers:
  - name: secret-pod
    image: busybox
    command: ["sleep", "3600"]
    volumeMounts:
    - name: secret-vol
      mountPath: /etc/secrets
  volumes:
  - name: secret-vol
    secret:
      secretName: db-secret
```

> [!warning] 주의
> - `volumes`는 `spec` 바로 아래 (containers와 같은 레벨)
> - `volumeMounts`는 container 안에

---

## Q6. Resource Limits Pod

> **문제**: nginx:1.25 이미지로 "limited-pod" 생성, requests(64Mi/100m), limits(128Mi/200m)

### 🚨 삽질 포인트

#### 1. resources 구조 (비교적 순조로움)

```yaml
# ✅ 올바른 YAML
spec:
  containers:
  - name: limited-pod
    image: nginx:1.25
    resources:
      requests:
        memory: "64Mi"
        cpu: "100m"
      limits:
        memory: "128Mi"
        cpu: "200m"
```

> [!tip] 핵심
> `resources` → `requests`/`limits` → `memory`/`cpu` 3단 구조
> 공식 문서에서 복붙하면 빠름. `kubectl explain pod.spec.containers.resources`로 확인 가능

#### 2. 검증 명령어

```bash
kubectl describe pod limited-pod | grep -A 10 "Limits\|Requests"
```

> [!success] 이번엔 잘함
> dry-run → vim에서 resources 붙여넣기 → apply. 깔끔하게 통과!

---

## Q7. Multi-Container + Shared Volume

> **문제**: "multi-pod" 생성. Container 1: web(nginx), Container 2: logger(busybox, sleep 3600). 공유 볼륨 "shared-data"를 /data에 마운트

### 🚨 삽질 포인트

#### 1. 사이드카 패턴이란 걸 몰랐음

> [!note] 핵심 개념
> 하나의 Pod 안에 여러 컨테이너가 같은 볼륨을 공유하는 패턴
> - `emptyDir`: Pod 수명과 같이하는 임시 볼륨
> - 컨테이너끼리 파일 시스템을 공유할 때 사용

#### 2. vim에서 multi-container 구조 편집 실패 → `:q!`로 나옴

```yaml
# ✅ 올바른 YAML (핵심 구조)
spec:
  volumes:                      # Pod 레벨에서 볼륨 선언
    - name: shared-data
      emptyDir: {}
  containers:
    - name: web                 # 컨테이너 1
      image: nginx
      volumeMounts:
        - name: shared-data
          mountPath: /data
    - name: logger              # 컨테이너 2 (- 하나 더 추가)
      image: busybox
      command: ["sleep", "3600"]
      volumeMounts:
        - name: shared-data
          mountPath: /data
```

> [!danger] 자주 틀리는 부분
> - `volumes`는 `spec` 바로 아래 (containers와 같은 레벨)
> - 두 번째 컨테이너는 `containers:` 배열에 `-`로 추가
> - `emptyDir: {}` 중괄호 빼먹지 않기

#### 3. `kubectl explain` 활용 (이번에 처음 사용)

```bash
kubectl explain pod.spec.volumes.emptyDir
kubectl explain pod.spec.containers.volumeMounts
```

> [!tip] 교훈
> vim에서 헤매기 전에 `kubectl explain`으로 필드명 먼저 확인하면 시간 절약됨

---

## 📊 핵심 교훈 요약

| 문제 | 핵심 실수 | 올바른 방법 |
|------|----------|------------|
| Q1 | `--namespace dev` (공백) | `--namespace=dev` 또는 `-n dev` |
| Q2 | `--labels` 옵션 사용 시도 | 별도로 `kubectl label` 명령 사용 |
| Q3 | `--cluster-ip`로 이름 지정 | `--name`으로 서비스 이름 지정 |
| Q4 | `env:` + `configMapRef` | `envFrom:` + 배열 형태 |
| Q5 | 콤마로 여러 값 지정, `--comand` 오타 | `--from-literal` 반복, `--command` |
| Q6 | (순조로움) | resources 3단 구조 기억 |
| Q7 | vim multi-container 편집 실패 | `kubectl explain` 먼저 확인 |

---

---

> [!info] 상세 패턴은 [[CKA-실전-치트시트|치트시트]] 참고

> [!success] 3회차 기록 (2026-02-08)
> Q1-Q7 총 ~50분. 2회차(1시간+) 대비 개선!
> 다음 목표: **30분 이내** 클리어
