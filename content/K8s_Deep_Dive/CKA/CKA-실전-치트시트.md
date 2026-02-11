---
title: CKA 실전 치트시트 - 자주 삽질하는 패턴 정리
tags:
  - cka
  - kubernetes
  - cheatsheet
  - exam
aliases:
  - CKA 치트시트
date: 2026-02-08
category: K8s_Deep_Dive
status: 완성
priority: 높음
---

# 🎯 CKA 실전 치트시트

> 모의고사에서 실제로 삽질한 것들 기반으로 정리

---

## 0. 문제 영어 → 명령어 매핑

### 문제 읽는 순서

```
1단계: 뭘 만드는가?
  "Create a pod" / "Create a deployment" / "Create a ConfigMap"
  → 기본 명령어 결정

2단계: 이름은?
  "named XXX" → NAME 위치에 넣기

3단계: 어디에?
  "in namespace XXX" → -n XXX

4단계: 어떤 이미지?
  "using image XXX" → --image=XXX

5단계: 추가 속성?
  "with label" / "replicas" / "port" 등 → 해당 옵션 추가

6단계: 데이터/연결?
  "with: KEY=VALUE" → --from-literal
  "as environment variables" → envFrom
  "mount as volume at /path" → volumes + volumeMounts
```

### 키워드 → 명령어 총정리

| 문제 표현 | 명령어/옵션 |
|----------|------------|
| Create a pod | `kubectl run` |
| Create a deployment | `kubectl create deployment` |
| Create a ConfigMap | `kubectl create configmap` |
| Create a Secret | `kubectl create secret generic` |
| Expose | `kubectl expose` |
| named "XXX" | NAME 위치 또는 `--name=XXX` |
| using image XXX | `--image=XXX` |
| in namespace XXX | `-n XXX` |
| with replicas X | `--replicas=X` |
| with label key=value | `--labels='key=value'` (run만!) |
| on port XX | `--port=XX` |
| with: KEY=VALUE | `--from-literal=KEY=VALUE` (반복!) |
| as environment variables | `envFrom` |
| mount as a volume at /path | `volumes` + `volumeMounts` |
| as a ClusterIP/NodePort | `--type=ClusterIP` / `--type=NodePort` |
| Command: XXX | `--command -- XXX` |

> [!warning] 핵심 구분
> - "as environment variables" → `envFrom`
> - "at /some/path" 경로 언급 → `volumes` + `volumeMounts`

---

## 1. dry-run 뼈대 생성 (모든 문제의 시작)

```bash
# Pod
kubectl run NAME --image=IMAGE --dry-run=client -o yaml > pod.yaml

# Deployment
kubectl create deployment NAME --image=IMAGE --replicas=N --dry-run=client -o yaml > deploy.yaml

# Service
kubectl expose deployment NAME --port=80 --name=SVC_NAME --dry-run=client -o yaml > svc.yaml

# ConfigMap
kubectl create configmap NAME --from-literal=KEY=VALUE --dry-run=client -o yaml

# Secret
kubectl create secret generic NAME --from-literal=KEY=VALUE --dry-run=client -o yaml
```

---

## 2. Volume 마운트 3종 패턴

> 구조는 전부 동일: `volumes`에서 선언 → `volumeMounts`에서 붙이기

### emptyDir (컨테이너 간 공유)

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
```

### secret (시크릿 파일 마운트)

```yaml
spec:
  volumes:
    - name: secret-vol
      secret:
        secretName: db-secret
  containers:
    - name: app
      image: busybox
      volumeMounts:
        - name: secret-vol
          mountPath: /etc/secrets
          readOnly: true
```

### configMap (설정 파일 마운트)

```yaml
spec:
  volumes:
    - name: config-vol
      configMap:
        name: app-config
  containers:
    - name: app
      image: nginx
      volumeMounts:
        - name: config-vol
          mountPath: /etc/config
```

---

## 3. ConfigMap/Secret을 환경변수로 주입

### envFrom (전체 키 주입)

```yaml
spec:
  containers:
    - name: app
      image: nginx
      envFrom:
        - configMapRef:
            name: app-config
```

### env (개별 키 주입)

```yaml
spec:
  containers:
    - name: app
      image: nginx
      env:
        - name: DB_HOST
          valueFrom:
            configMapKeyRef:
              name: app-config
              key: DB_HOST
```

---

## 4. Multi-Container Pod (사이드카 패턴)

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
    - name: logger            # 두번째 컨테이너는 - 하나 더
      image: busybox
      command: ["sleep", "3600"]
      volumeMounts:
        - name: shared-data
          mountPath: /data
```

---

## 5. 자주 하는 실수 목록

| 실수 | 올바른 사용법 |
|------|-------------|
| `--comand` | `--command` (m 두개) |
| `--port80` | `--port=80` (= 필수) |
| `kubectl label pods deploy-name` | `kubectl label deployment deploy-name` |
| `tier-backend` | `tier=backend` (= 로 key=value) |
| `kubect` | `kubectl` (오타 주의) |
| `Create` (대문자) | `create` (소문자) |

---

## 6. 필드명 까먹을 때

```bash
kubectl explain pod.spec.volumes.secret
kubectl explain pod.spec.volumes.emptyDir
kubectl explain pod.spec.volumes.configMap
kubectl explain pod.spec.containers.volumeMounts
kubectl explain pod.spec.containers.envFrom
kubectl explain pod.spec.containers.env
```

---

## 7. Label & Selector

```bash
# 라벨 추가
kubectl label TYPE NAME key=value

# 라벨 확인
kubectl get TYPE NAME --show-labels

# 라벨로 필터
kubectl get pods -l app=nginx

# 라벨 삭제
kubectl label TYPE NAME key-
```

---

## 8. Resource Requests/Limits

```yaml
spec:
  containers:
    - name: app
      image: nginx:1.25
      resources:
        requests:
          memory: "64Mi"
          cpu: "100m"
        limits:
          memory: "128Mi"
          cpu: "200m"
```

```bash
# 필드 확인
kubectl explain pod.spec.containers.resources.limits
kubectl explain pod.spec.containers.resources.requests

# 검증
kubectl describe pod POD_NAME | grep -A 10 "Limits\|Requests"
```

---

## 9. 검증 명령어

```bash
# Pod 상태
kubectl get pods

# 환경변수 확인
kubectl exec POD_NAME -- env | grep KEY

# 마운트 파일 확인
kubectl exec POD_NAME -- ls /mount/path
kubectl exec POD_NAME -- cat /mount/path/file

# 서비스 확인
kubectl get svc SVC_NAME

# 라벨 확인
kubectl get TYPE NAME --show-labels

# Pod 상세 (트러블슈팅)
kubectl describe pod POD_NAME
```

---

> 📅 2026-02-08 모의고사 기록
> - Q1 Pod 생성: ~4분
> - Q2 Deployment + Label: ~8분 (label 타입 혼동)
> - Q3 Service Expose: ~4분 (flag 오타)
> - Q4 ConfigMap + envFrom: ~15분 (vim 편집 고전)
> - Q5 Secret + Volume: ~15분 (--comand 오타, vim 고전, 터미널 크래시)
> - Q6 Resource Limits: 깔끔 통과
> - Q7 Multi-Container + emptyDir: kubectl explain 활용, 터미널 크래시
> 목표: 내일 30분 이내 클리어

---

## 10. Vim 빠른 참조

### 모드 전환 & 저장

| 키 | 동작 |
|---|------|
| `i` / `a` | 입력 모드 (커서 앞/뒤) |
| `o` / `O` | 아래/위에 새 줄 + 입력 모드 |
| `ESC` | 명령 모드로 복귀 |
| `:wq` | 저장 후 종료 |
| `:q!` | 저장 안하고 강제 종료 |

### 이동 & 편집

| 키 | 동작 |
|---|------|
| `gg` / `G` | 파일 맨 위/아래 |
| `dd` / `yy` / `p` | 줄 삭제/복사/붙여넣기 |
| `3dd` / `3yy` | 3줄 삭제/복사 |
| `u` / `Ctrl+r` | 실행 취소/다시 실행 |
| `/단어` → `n`/`N` | 검색 → 다음/이전 |
| `cw` | 단어 삭제 + 입력모드 |

### YAML 필수 설정

| 키 | 동작 |
|---|------|
| `:set nu` | 줄번호 표시 |
| `:set paste` | 붙여넣기 모드 (들여쓰기 깨짐 방지) |
| `:set nopaste` | 붙여넣기 모드 해제 |
| `>>` / `<<` | 들여쓰기 추가/제거 |
| `V` → `jjj` → `>` | 여러 줄 선택 후 들여쓰기 |

### YAML 복붙 순서

```
:set paste → i → (붙여넣기) → ESC → :set nopaste → :wq
```
