# Kubernetes 복습 & 치트시트 📚

> 까먹은 쿠버네티스 개념과 명령어를 빠르게 되살리기 위한 실무 가이드

## 🧠 핵심 개념 복습 (30초)

### 쿠버네티스란?
```
쿠버네티스 = 컨테이너 오케스트레이션 플랫폼
목적: 여러 서버에서 컨테이너들을 자동으로 관리

기본 구조:
클러스터 → 노드들 → 파드들 → 컨테이너들
```

### 핵심 리소스
- **Pod**: 가장 작은 배포 단위 (컨테이너 그룹)
- **Deployment**: Pod들을 관리 (복제, 업데이트, 복구)
- **Service**: 네트워킹 (로드밸런싱, 서비스 디스커버리)
- **PV/PVC**: 영구 스토리지
- **Namespace**: 리소스 격리

## ⚡ 자주 쓰는 명령어

### 기본 조회 명령어
```bash
# 기본 형태: kubectl get [리소스타입]
kubectl get pods              # 파드 목록
kubectl get svc               # 서비스 목록  
kubectl get deploy            # 디플로이먼트 목록
kubectl get pv,pvc            # 스토리지 목록
kubectl get all               # 모든 리소스

# 상세보기
kubectl describe pod [이름]   # 파드 상세 정보
kubectl logs [파드이름]       # 로그 확인
kubectl get pods -o wide      # 더 많은 컬럼 표시
kubectl get pods --watch      # 실시간 모니터링
```

### 생성/삭제 명령어
```bash
# 빠른 생성
kubectl run nginx --image=nginx                    # 파드 하나
kubectl create deployment nginx --image=nginx      # 디플로이먼트
kubectl expose deployment nginx --port=80           # 서비스 노출

# YAML 파일 적용
kubectl apply -f my-app.yaml                       # 파일 적용
kubectl apply -f .                                 # 현재 디렉토리 모든 YAML

# 삭제
kubectl delete pod [이름]                          # 특정 파드 삭제
kubectl delete -f my-app.yaml                      # 파일로 삭제
kubectl delete all --all                           # 모든 리소스 삭제 (주의!)
```

### 디버깅 명령어
```bash
# 파드 내부 접속
kubectl exec -it [파드이름] -- /bin/bash           # bash 셸 접속
kubectl exec [파드이름] -- ls /app                 # 명령어 실행

# 포트 포워딩
kubectl port-forward pod/[파드이름] 8080:80        # 로컬 8080 → 파드 80

# 파일 복사
kubectl cp [파드이름]:/path/file ./local-file     # 파드 → 로컬
kubectl cp ./local-file [파드이름]:/path/file     # 로컬 → 파드
```

## 🎯 스토리지 개념 정리

### 비유로 이해하기
```
🏪 StorageClass = "스토리지 쇼핑몰"
├── AWS EBS 매장
├── NFS 매장  
└── 로컬디스크 매장

🧾 PVC = "주문서"
└── "1GB 디스크 주세요!"

📦 PV = "실제 배송된 디스크"
└── 쿠버네티스가 자동으로 연결

🏠 Pod = "사용자"
└── "주문한 디스크를 /data에 연결해주세요"
```

### 실제 동작 순서
```bash
1. StorageClass 정의 (어떤 종류 디스크?)
2. PVC 생성 (얼마나 필요?)  
3. PV 자동 생성 (쿠버네티스가 알아서)
4. Pod에서 PVC 사용 (마운트)
```

### 스토리지 접근 모드
- **ReadWriteOnce (RWO)**: 하나의 노드에서만 읽기/쓰기
- **ReadOnlyMany (ROX)**: 여러 노드에서 읽기만
- **ReadWriteMany (RWX)**: 여러 노드에서 읽기/쓰기

## 📚 YAML 작성 가이드

### 기본 구조 (항상 동일)
```yaml
apiVersion: ???      # API 버전
kind: ???           # 리소스 타입
metadata:            # 메타데이터
  name: ???         # 이름 (필수)
  labels: {}        # 라벨 (선택)
spec:               # 실제 설정
  # 여기가 리소스마다 다름
```

### Pod YAML 템플릿
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-pod
  labels:
    app: my-app
spec:
  containers:        # 컨테이너들 (배열)
  - name: main       # 컨테이너 이름
    image: nginx     # 이미지
    ports:           # 포트들 (선택)
    - containerPort: 80
    env:             # 환경변수 (선택)
    - name: ENV_VAR
      value: "value"
    volumeMounts:    # 마운트들 (선택)
    - name: vol-name
      mountPath: /path
  volumes:           # 볼륨들 (선택)
  - name: vol-name
    emptyDir: {}
```

### Deployment YAML 템플릿
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-deployment
  labels:
    app: my-app
spec:
  replicas: 3        # 복제본 수
  selector:
    matchLabels:
      app: my-app
  template:
    metadata:
      labels:
        app: my-app
    spec:
      containers:
      - name: main
        image: nginx
        ports:
        - containerPort: 80
```

### Service YAML 템플릿
```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-service
spec:
  selector:
    app: my-app      # Pod 라벨과 매칭
  ports:
  - port: 80         # 서비스 포트
    targetPort: 80   # 컨테이너 포트
  type: ClusterIP    # ClusterIP, NodePort, LoadBalancer
```

### PVC YAML 템플릿
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-pvc
spec:
  accessModes:
  - ReadWriteOnce    # RWO, ROX, RWX
  resources:
    requests:
      storage: 1Gi
  storageClassName: standard  # 선택사항
```

## 🚨 자주 하는 실수들

### 1. YAML 들여쓰기
```yaml
# ❌ 잘못된 예
spec:
containers:        # 들여쓰기 부족
- name: web
image: nginx       # 들여쓰기 부족

# ✅ 올바른 예  
spec:
  containers:      # 2칸 들여쓰기
  - name: web      # 리스트 표시 (-)
    image: nginx   # 4칸 들여쓰기
```

### 2. 라벨 vs 이름 혼동
```yaml
# 이름은 유니크, 라벨은 중복 가능
metadata:
  name: my-pod           # 유니크한 식별자
  labels:
    app: nginx           # 그룹핑용 (여러 파드가 같은 라벨 가능)
```

### 3. 서비스 셀렉터 불일치
```yaml
# Service의 selector와 Pod의 labels가 일치해야 함
# Service
spec:
  selector:
    app: my-app    # 이 라벨로 Pod를 찾음

# Pod  
metadata:
  labels:
    app: my-app    # 일치해야 함!
```

## ⚡ 빠른 실습 예제

### 5분 실습: 기본기 확인
```bash
# 1. 간단한 파드 생성
kubectl run test-pod --image=nginx --dry-run=client -o yaml

# 2. 디플로이먼트 생성  
kubectl create deployment test-deploy --image=nginx --replicas=3

# 3. 서비스 노출
kubectl expose deployment test-deploy --port=80 --type=NodePort

# 4. 상태 확인
kubectl get all

# 5. 정리
kubectl delete deployment test-deploy
kubectl delete service test-deploy
```

### 10분 실습: 스토리지 테스트
```bash
# 1. PVC 생성
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim  
metadata:
  name: test-pvc
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 1Gi
EOF

# 2. PVC 사용하는 파드 생성
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: test-storage-pod
spec:
  containers:
  - name: test
    image: busybox
    command: ['sleep', '3600']
    volumeMounts:
    - name: storage
      mountPath: /data
  volumes:
  - name: storage
    persistentVolumeClaim:
      claimName: test-pvc
EOF

# 3. 테스트
kubectl exec test-storage-pod -- touch /data/test.txt
kubectl exec test-storage-pod -- ls /data

# 4. 정리
kubectl delete pod test-storage-pod
kubectl delete pvc test-pvc
```

## 🎯 기억하기 쉬운 패턴들

### 명령어 패턴
```bash
kubectl [동작] [리소스타입] [이름] [옵션]

# 예시들
kubectl get     pods                    # 조회
kubectl describe pod    my-pod          # 상세조회  
kubectl delete  deploy  my-deploy       # 삭제
kubectl apply   -f      my-file.yaml    # 적용
```

### 리소스 관계도
```
Namespace
    └── Deployment
            └── ReplicaSet
                    └── Pod
                            └── Container

Service (로드밸런싱)
    └── Pod(들)

Ingress (외부 노출)
    └── Service
            └── Pod(들)

StorageClass
    └── PV
            └── PVC
                    └── Pod (마운트)
```

## 💡 실무 팁

### 자동완성 설정
```bash
# .bashrc 또는 .zshrc에 추가
alias k='kubectl'
source <(kubectl completion bash)  # bash용
source <(kubectl completion zsh)   # zsh용
complete -F __start_kubectl k

# 사용법: 탭 키로 자동완성!
k get po<TAB>  → k get pods
k describe pod my-<TAB>  → 파드 이름 자동완성
```

### 유용한 Alias들
```bash
# 자주 쓰는 명령어들
alias k='kubectl'
alias kgp='kubectl get pods'
alias kgs='kubectl get svc' 
alias kgd='kubectl get deploy'
alias kga='kubectl get all'
alias kdp='kubectl describe pod'
alias kl='kubectl logs'
alias kex='kubectl exec -it'

# 네임스페이스 관련
alias kgpn='kubectl get pods --all-namespaces'
alias kns='kubectl config set-context --current --namespace'

# 빠른 삭제
alias kdel='kubectl delete'
alias kdelp='kubectl delete pod'
alias kdelf='kubectl delete -f'
```

### kubectl 출력 포맷
```bash
# 다양한 출력 형태
kubectl get pods -o wide                    # 더 많은 컬럼
kubectl get pods -o yaml                    # YAML 형태
kubectl get pods -o json                    # JSON 형태
kubectl get pods -o jsonpath='{.items[*].metadata.name}'  # 특정 필드만

# 정렬
kubectl get pods --sort-by='.metadata.name'
kubectl get pods --sort-by='.status.startTime'
```

### 리소스 모니터링
```bash
# 실시간 모니터링
kubectl get pods --watch                    # 변화 실시간 감시
kubectl top nodes                          # 노드 리소스 사용량
kubectl top pods                           # 파드 리소스 사용량

# 이벤트 확인
kubectl get events --sort-by='.lastTimestamp'
kubectl get events --field-selector involvedObject.name=my-pod
```

### 문제 해결 명령어
```bash
# 파드가 안 뜨는 경우
kubectl describe pod [파드이름]              # 상세 정보로 원인 파악
kubectl logs [파드이름] --previous          # 이전 컨테이너 로그
kubectl get events                          # 클러스터 이벤트 확인

# 네트워크 문제
kubectl exec -it [파드이름] -- nslookup [서비스이름]
kubectl exec -it [파드이름] -- curl [서비스이름]

# 스토리지 문제  
kubectl get pv,pvc                          # PV/PVC 상태 확인
kubectl describe pvc [PVC이름]               # PVC 상세 정보
```

## 🚀 고급 사용법

### 라벨과 셀렉터 활용
```bash
# 라벨로 필터링
kubectl get pods -l app=nginx               # app=nginx 라벨을 가진 파드들
kubectl get pods -l 'env in (dev,test)'     # env가 dev 또는 test인 파드들
kubectl get pods -l 'tier!=frontend'       # tier가 frontend가 아닌 파드들

# 라벨 추가/제거
kubectl label pod my-pod env=production     # 라벨 추가
kubectl label pod my-pod env-               # 라벨 제거
```

### ConfigMap과 Secret
```bash
# ConfigMap 생성
kubectl create configmap my-config --from-literal=key1=value1 --from-literal=key2=value2
kubectl create configmap my-config --from-file=config.properties

# Secret 생성  
kubectl create secret generic my-secret --from-literal=username=admin --from-literal=password=secret
kubectl create secret docker-registry my-registry-secret --docker-server=myregistry.com --docker-username=user --docker-password=pass

# 사용 예시
# Pod에서 ConfigMap 사용
env:
- name: CONFIG_KEY
  valueFrom:
    configMapKeyRef:
      name: my-config
      key: key1

# Pod에서 Secret 사용
env:
- name: PASSWORD
  valueFrom:
    secretKeyRef:
      name: my-secret
      key: password
```

### 헬스체크 설정
```yaml
# Liveness와 Readiness Probe
spec:
  containers:
  - name: app
    image: my-app
    livenessProbe:      # 컨테이너 살아있는지 확인
      httpGet:
        path: /health
        port: 8080
      initialDelaySeconds: 30
      periodSeconds: 10
    readinessProbe:     # 트래픽 받을 준비됐는지 확인
      httpGet:
        path: /ready
        port: 8080
      initialDelaySeconds: 5
      periodSeconds: 5
```

---

## 📖 참고 자료

- [Kubernetes 공식 문서](https://kubernetes.io/docs/)
- [kubectl 치트시트](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
- [YAML 온라인 검증기](http://www.yamllint.com/)

---

*이 치트시트를 북마크하고 필요할 때마다 참고하세요! 🚀*