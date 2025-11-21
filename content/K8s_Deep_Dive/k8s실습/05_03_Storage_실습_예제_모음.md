# 05-03. Kubernetes 스토리지 실습 예제 모음 🎯

> 🛠️ **실전 연습**: 직접 해보면서 익히는 PV, PVC, StorageClass 활용법

## 🏃‍♂️ 빠른 시작 - 5분 실습

### 기본 PVC + Pod 조합
```bash
# 1단계: PVC 생성
kubectl create pvc my-first-pvc --claim-size=1Gi

# 2단계: PVC 상태 확인
kubectl get pvc my-first-pvc

# 3단계: Pod에서 PVC 사용
kubectl run storage-test --image=busybox --command sleep 3600 \
  --overrides='{
    "spec": {
      "volumes": [{
        "name": "storage",
        "persistentVolumeClaim": {"claimName": "my-first-pvc"}
      }],
      "containers": [{
        "name": "busybox",
        "image": "busybox", 
        "command": ["sleep", "3600"],
        "volumeMounts": [{
          "name": "storage",
          "mountPath": "/data"
        }]
      }]
    }
  }'

# 4단계: 데이터 저장 테스트
kubectl exec storage-test -- sh -c "echo 'Hello Storage!' > /data/test.txt"
kubectl exec storage-test -- cat /data/test.txt

# 5단계: 정리
kubectl delete pod storage-test
kubectl delete pvc my-first-pvc
```

## 🧪 체험형 실습 시나리오

### 실습 1: "데이터 영속성 체험하기"
> **목표**: Pod가 사라져도 데이터가 남아있는지 확인

```bash
echo "=== 🧪 실습 1: 데이터 영속성 테스트 ==="

# 1. PVC와 Pod 생성
kubectl create pvc persistent-data --claim-size=2Gi
kubectl run data-writer --image=alpine --command sleep 300 \
  --overrides='{
    "spec": {
      "volumes": [{"name": "data", "persistentVolumeClaim": {"claimName": "persistent-data"}}],
      "containers": [{
        "name": "alpine",
        "image": "alpine",
        "command": ["sleep", "300"],
        "volumeMounts": [{"name": "data", "mountPath": "/storage"}]
      }]
    }
  }'

# 2. 중요한 데이터 저장
kubectl exec data-writer -- sh -c "echo '중요한 데이터' > /storage/important.txt"
kubectl exec data-writer -- sh -c "echo '$(date)' > /storage/timestamp.txt"
kubectl exec data-writer -- ls -la /storage/

# 3. Pod 삭제 (실수로 삭제하는 상황 시뮬레이션)
echo "💥 Pod를 삭제합니다..."
kubectl delete pod data-writer

# 4. 새로운 Pod로 데이터 복구
kubectl run data-reader --image=alpine --command sleep 300 \
  --overrides='{
    "spec": {
      "volumes": [{"name": "data", "persistentVolumeClaim": {"claimName": "persistent-data"}}],
      "containers": [{
        "name": "alpine", 
        "image": "alpine",
        "command": ["sleep", "300"],
        "volumeMounts": [{"name": "data", "mountPath": "/storage"}]
      }]
    }
  }'

# 5. 데이터가 살아있는지 확인
echo "🔍 데이터 복구 확인:"
kubectl exec data-reader -- ls -la /storage/
kubectl exec data-reader -- cat /storage/important.txt
kubectl exec data-reader -- cat /storage/timestamp.txt

echo "✅ 결과: Pod가 삭제되어도 PVC의 데이터는 보존됨!"

# 정리
kubectl delete pod data-reader
kubectl delete pvc persistent-data
```

### 실습 2: "접근 모드 실험실"
> **목표**: RWO vs RWX의 차이점 체험

```bash
echo "=== 🧪 실습 2: 접근 모드 테스트 ==="

# ReadWriteOnce 테스트
echo "1. ReadWriteOnce 테스트"
kubectl create pvc rwo-pvc --claim-size=1Gi --access-modes=ReadWriteOnce

# 첫 번째 Pod 생성
kubectl run rwo-pod1 --image=nginx \
  --overrides='{
    "spec": {
      "volumes": [{"name": "storage", "persistentVolumeClaim": {"claimName": "rwo-pvc"}}],
      "containers": [{
        "name": "nginx",
        "image": "nginx",
        "volumeMounts": [{"name": "storage", "mountPath": "/usr/share/nginx/html"}]
      }]
    }
  }'

# 두 번째 Pod 생성 (같은 PVC 사용 시도)
kubectl run rwo-pod2 --image=nginx \
  --overrides='{
    "spec": {
      "volumes": [{"name": "storage", "persistentVolumeClaim": {"claimName": "rwo-pvc"}}],
      "containers": [{
        "name": "nginx",
        "image": "nginx", 
        "volumeMounts": [{"name": "storage", "mountPath": "/usr/share/nginx/html"}]
      }]
    }
  }'

echo "Pod들의 배치 상태를 확인해보세요:"
kubectl get pods -o wide
echo "같은 노드에 배치되면 둘 다 Running, 다른 노드면 하나는 Pending"

# 정리
kubectl delete pod rwo-pod1 rwo-pod2
kubectl delete pvc rwo-pvc

echo "✅ ReadWriteOnce는 한 번에 하나의 노드에서만 사용 가능!"
```

### 실습 3: "StorageClass 탐험가"
> **목표**: 다양한 StorageClass 비교하기

```bash
echo "=== 🧪 실습 3: StorageClass 비교 ==="

# 1. 사용 가능한 StorageClass 확인
echo "📋 클러스터의 StorageClass 목록:"
kubectl get storageclass

# 2. 기본 StorageClass 찾기
echo "🏷️ 기본 StorageClass:"
kubectl get storageclass -o jsonpath='{.items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")].metadata.name}'

# 3. 각 StorageClass로 PVC 생성 테스트
echo "🧪 각 StorageClass 테스트:"
for sc in $(kubectl get storageclass -o jsonpath='{.items[*].metadata.name}'); do
  echo "--- StorageClass: $sc ---"
  
  # PVC 생성
  kubectl create pvc test-$sc --storage-class=$sc --claim-size=1Gi
  
  # 잠시 대기 후 상태 확인
  sleep 10
  status=$(kubectl get pvc test-$sc -o jsonpath='{.status.phase}')
  echo "상태: $status"
  
  if [ "$status" = "Bound" ]; then
    # 성공한 경우 PV 정보도 확인
    pv_name=$(kubectl get pvc test-$sc -o jsonpath='{.spec.volumeName}')
    echo "연결된 PV: $pv_name"
    kubectl get pv $pv_name -o custom-columns=NAME:.metadata.name,CAPACITY:.spec.capacity.storage,RECLAIM:.spec.persistentVolumeReclaimPolicy
  fi
  
  # 정리
  kubectl delete pvc test-$sc
  echo ""
done
```

### 실습 4: "용량 수사관"
> **목표**: 요청한 용량과 실제 할당된 용량 비교

```bash
echo "=== 🕵️ 실습 4: 용량 수사 ==="

# 다양한 크기로 PVC 생성
sizes=("100Mi" "500Mi" "1Gi" "2Gi")

for size in "${sizes[@]}"; do
    echo "--- 요청 크기: $size ---"
    
    # PVC 생성
    pvc_name="capacity-test-$(echo $size | tr 'A-Z' 'a-z' | sed 's/i//')"
    kubectl create pvc $pvc_name --claim-size=$size
    
    # PVC가 Bound될 때까지 대기
    kubectl wait --for=jsonpath='{.status.phase}'=Bound pvc/$pvc_name --timeout=60s
    
    # 실제 할당된 용량 확인
    pv_name=$(kubectl get pvc $pvc_name -o jsonpath='{.spec.volumeName}')
    allocated_size=$(kubectl get pv $pv_name -o jsonpath='{.spec.capacity.storage}')
    
    echo "요청: $size → 할당: $allocated_size"
    
    # Pod에서 실제 사용 가능한 용량 확인
    kubectl run capacity-checker-$pvc_name --image=busybox --rm -it \
      --overrides='{
        "spec": {
          "volumes": [{"name": "vol", "persistentVolumeClaim": {"claimName": "'$pvc_name'"}}],
          "containers": [{
            "name": "busybox",
            "image": "busybox",
            "command": ["df", "-h", "/data"],
            "volumeMounts": [{"name": "vol", "mountPath": "/data"}],
            "stdin": true,
            "tty": true
          }]
        }
      }' --restart=Never
    
    # 정리
    kubectl delete pvc $pvc_name
    echo ""
done
```

## 🎮 게임형 미션들

### 미션 1: "스토리지 레이싱"
> **목표**: 가장 빠르게 PVC를 생성하고 사용하기

```bash
echo "🏁 미션 1: 스토리지 레이싱 (시간 측정)"

start_time=$(date +%s)

# 1. PVC 생성
echo "1. PVC 생성 중..."
kubectl create pvc racing-pvc --claim-size=1Gi

# 2. Bound 상태까지 시간 측정
echo "2. Bound 상태까지 대기..."
kubectl wait --for=jsonpath='{.status.phase}'=Bound pvc/racing-pvc --timeout=60s
bound_time=$(date +%s)

# 3. Pod 생성 및 마운트
echo "3. Pod 생성 및 마운트..."
kubectl run racing-pod --image=alpine --command sleep 60 \
  --overrides='{
    "spec": {
      "volumes": [{"name": "storage", "persistentVolumeClaim": {"claimName": "racing-pvc"}}],
      "containers": [{
        "name": "alpine",
        "image": "alpine",
        "command": ["sleep", "60"],
        "volumeMounts": [{"name": "storage", "mountPath": "/data"}]
      }]
    }
  }'

# 4. Pod Running 상태까지 시간 측정
kubectl wait --for=condition=Ready pod/racing-pod --timeout=60s
ready_time=$(date +%s)

# 5. 데이터 쓰기 테스트
echo "4. 데이터 쓰기 테스트..."
kubectl exec racing-pod -- sh -c "echo 'Racing complete!' > /data/result.txt"
kubectl exec racing-pod -- cat /data/result.txt
complete_time=$(date +%s)

# 결과 발표
echo "🏆 레이싱 결과:"
echo "PVC Bound: $((bound_time - start_time))초"
echo "Pod Ready: $((ready_time - start_time))초"  
echo "전체 완료: $((complete_time - start_time))초"

# 정리
kubectl delete pod racing-pod
kubectl delete pvc racing-pvc
```

### 미션 2: "에러 디텍티브"
> **목표**: 의도적으로 에러를 만들고 해결하기

```bash
echo "🕵️ 미션 2: 에러 디텍티브"

# 에러 시나리오 1: 존재하지 않는 PVC 참조
echo "💥 에러 시나리오 1: 존재하지 않는 PVC"
kubectl run error-pod1 --image=nginx \
  --overrides='{
    "spec": {
      "volumes": [{"name": "storage", "persistentVolumeClaim": {"claimName": "non-existent-pvc"}}],
      "containers": [{
        "name": "nginx",
        "image": "nginx",
        "volumeMounts": [{"name": "storage", "mountPath": "/data"}]
      }]
    }
  }'

echo "Pod 상태 확인:"
kubectl get pod error-pod1
echo "에러 원인 파악:"
kubectl describe pod error-pod1 | grep -A 5 "Events:"

# 해결책 적용
echo "🔧 해결책: PVC 생성"
kubectl create pvc non-existent-pvc --claim-size=1Gi

echo "Pod 상태 변화 관찰:"
sleep 5
kubectl get pod error-pod1

# 정리
kubectl delete pod error-pod1
kubectl delete pvc non-existent-pvc

echo "✅ 에러 해결 완료!"

# 에러 시나리오 2: 잘못된 StorageClass
echo "💥 에러 시나리오 2: 잘못된 StorageClass"
kubectl create pvc wrong-sc-pvc --storage-class=non-existent-class --claim-size=1Gi

echo "PVC 상태 확인:"
sleep 10
kubectl get pvc wrong-sc-pvc

echo "에러 이벤트 확인:"
kubectl get events --field-selector involvedObject.name=wrong-sc-pvc

# 해결책
echo "🔧 해결책: 올바른 StorageClass 사용"
kubectl delete pvc wrong-sc-pvc
default_sc=$(kubectl get storageclass -o jsonpath='{.items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")].metadata.name}')
kubectl create pvc correct-sc-pvc --storage-class=$default_sc --claim-size=1Gi

echo "올바른 PVC 상태:"
sleep 5
kubectl get pvc correct-sc-pvc

kubectl delete pvc correct-sc-pvc
echo "✅ 모든 에러 해결 완료!"
```

## 📊 모니터링 및 분석

### 실시간 대시보드 설정
```bash
echo "📊 스토리지 실시간 모니터링 대시보드 설정"

# 터미널을 여러 개 열어서 각각 실행
echo "터미널 1: PVC 모니터링"
echo "watch -n 2 \"kubectl get pvc -o wide\""

echo "터미널 2: PV 모니터링"  
echo "watch -n 2 \"kubectl get pv -o wide\""

echo "터미널 3: Pod 모니터링"
echo "watch -n 2 \"kubectl get pods -o wide\""

echo "터미널 4: 이벤트 모니터링"
echo "kubectl get events --watch"

echo "터미널 5: 리소스 사용량"
echo "watch -n 5 \"kubectl top nodes; echo; kubectl top pods\""
```

### 스토리지 상태 로깅
```bash
# 스토리지 상태를 CSV로 기록하는 스크립트
cat << 'EOF' > storage-monitor.sh
#!/bin/bash
# storage-monitor.sh - 스토리지 상태 모니터링

LOG_FILE="storage_timeline_$(date +%Y%m%d_%H%M%S).csv"

echo "시간,PVC개수,PV개수,Bound된PVC,Pending된PVC,총용량(GB)" > $LOG_FILE

while true; do
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    pvc_total=$(kubectl get pvc --no-headers 2>/dev/null | wc -l)
    pv_total=$(kubectl get pv --no-headers 2>/dev/null | wc -l)
    pvc_bound=$(kubectl get pvc --no-headers 2>/dev/null | grep Bound | wc -l)
    pvc_pending=$(kubectl get pvc --no-headers 2>/dev/null | grep Pending | wc -l)
    
    # 총 할당된 용량 계산 (GB)
    total_capacity=$(kubectl get pv -o jsonpath='{.items[*].spec.capacity.storage}' 2>/dev/null | \
        sed 's/Gi/G/g' | sed 's/Mi/M/g' | \
        awk '{for(i=1;i<=NF;i++) {
            if($i ~ /G$/) sum += substr($i,1,length($i)-1)
            else if($i ~ /M$/) sum += substr($i,1,length($i)-1)/1024
        }} END {printf "%.2f", sum}')
    
    echo "$timestamp,$pvc_total,$pv_total,$pvc_bound,$pvc_pending,$total_capacity" | tee -a $LOG_FILE
    
    sleep 10
done
EOF

chmod +x storage-monitor.sh
echo "✅ 모니터링 스크립트 생성 완료: ./storage-monitor.sh"
```

## 🎯 고급 실습 시나리오

### 시나리오 1: "데이터베이스 스토리지 실습"
```bash
echo "🗄️ 시나리오 1: 데이터베이스 스토리지"

# MySQL용 PVC 생성
kubectl create pvc mysql-data --claim-size=5Gi

# MySQL Deployment 생성
cat << EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mysql
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mysql
  template:
    metadata:
      labels:
        app: mysql
    spec:
      containers:
      - name: mysql
        image: mysql:8.0
        env:
        - name: MYSQL_ROOT_PASSWORD
          value: "password123"
        - name: MYSQL_DATABASE
          value: "testdb"
        ports:
        - containerPort: 3306
        volumeMounts:
        - name: mysql-storage
          mountPath: /var/lib/mysql
      volumes:
      - name: mysql-storage
        persistentVolumeClaim:
          claimName: mysql-data
EOF

# 서비스 생성
kubectl expose deployment mysql --port=3306 --type=ClusterIP

# 데이터베이스 연결 테스트
echo "MySQL이 시작될 때까지 대기..."
kubectl wait --for=condition=Ready pod -l app=mysql --timeout=120s

# 테스트 클라이언트로 데이터 삽입
kubectl run mysql-client --image=mysql:8.0 --rm -it --restart=Never \
  -- mysql -h mysql -uroot -ppassword123 -e "
    USE testdb;
    CREATE TABLE users (id INT, name VARCHAR(50));
    INSERT INTO users VALUES (1, 'Alice'), (2, 'Bob');
    SELECT * FROM users;
  "

echo "🔄 MySQL Pod 재시작 후 데이터 영속성 테스트"
kubectl delete pod -l app=mysql

# Pod 재시작 대기
kubectl wait --for=condition=Ready pod -l app=mysql --timeout=120s

# 데이터가 남아있는지 확인
kubectl run mysql-client-2 --image=mysql:8.0 --rm -it --restart=Never \
  -- mysql -h mysql -uroot -ppassword123 -e "
    USE testdb;
    SELECT * FROM users;
  "

echo "✅ 데이터베이스 영속성 테스트 완료"

# 정리
kubectl delete deployment mysql
kubectl delete service mysql  
kubectl delete pvc mysql-data
```

### 시나리오 2: "파일 서버 클러스터"
```bash
echo "📁 시나리오 2: 파일 서버 클러스터"

# 공유 스토리지용 PVC (RWX 지원하는 경우)
kubectl create pvc shared-files --claim-size=3Gi --access-modes=ReadWriteMany

# 여러 파일 서버 Pod 생성
for i in {1..3}; do
  kubectl run fileserver-$i --image=nginx \
    --overrides='{
      "spec": {
        "volumes": [{"name": "shared", "persistentVolumeClaim": {"claimName": "shared-files"}}],
        "containers": [{
          "name": "nginx",
          "image": "nginx", 
          "volumeMounts": [{"name": "shared", "mountPath": "/usr/share/nginx/html"}]
        }]
      }
    }'
done

echo "파일 서버들의 배치 확인:"
kubectl get pods -o wide -l run

# 각 서버에서 파일 생성
for i in {1..3}; do
  kubectl exec fileserver-$i -- sh -c "echo 'Hello from server $i' > /usr/share/nginx/html/server-$i.txt"
done

# 모든 서버에서 파일 확인
for i in {1..3}; do
  echo "=== Server $i 파일 목록 ==="
  kubectl exec fileserver-$i -- ls -la /usr/share/nginx/html/
done

echo "✅ 공유 파일 시스템 테스트 완료"

# 정리  
kubectl delete pod fileserver-1 fileserver-2 fileserver-3
kubectl delete pvc shared-files
```

## 🔧 문제 해결 가이드

### 일반적인 문제들과 해결책

#### PVC가 Pending 상태
```bash
echo "🚨 PVC Pending 문제 해결"

# 1. PVC 상태 확인
kubectl describe pvc [PVC이름]

# 2. 일반적인 원인들 체크
echo "체크포인트:"
echo "1. StorageClass 존재 여부"
kubectl get storageclass

echo "2. 요청한 용량이 너무 큰지 확인"
kubectl get pvc [PVC이름] -o jsonpath='{.spec.resources.requests.storage}'

echo "3. 접근 모드가 지원되는지 확인"
kubectl get pvc [PVC이름] -o jsonpath='{.spec.accessModes}'

echo "4. 클러스터 이벤트 확인"
kubectl get events --field-selector involvedObject.name=[PVC이름]
```

#### Pod가 PVC를 마운트하지 못함
```bash
echo "🚨 Pod 마운트 실패 해결"

# 1. Pod 상태 확인
kubectl describe pod [Pod이름]

# 2. PVC 바인딩 상태 확인  
kubectl get pvc

# 3. 볼륨 설정 확인
kubectl get pod [Pod이름] -o yaml | grep -A 10 volumes:
kubectl get pod [Pod이름] -o yaml | grep -A 10 volumeMounts:
```

## 📝 학습 체크리스트

### ✅ 기본 레벨
- [ ] PVC 생성하고 Pod에 마운트할 수 있다
- [ ] 파일을 저장하고 Pod 재시작 후에도 유지됨을 확인했다
- [ ] StorageClass를 지정해서 PVC를 생성할 수 있다
- [ ] 다양한 접근 모드의 차이를 이해한다

### ✅ 중급 레벨  
- [ ] 에러 상황을 진단하고 해결할 수 있다
- [ ] 여러 StorageClass의 특징을 비교할 수 있다
- [ ] kubectl 명령어로 스토리지 상태를 모니터링할 수 있다
- [ ] 실제 애플리케이션(DB 등)에 스토리지를 적용할 수 있다

### ✅ 고급 레벨
- [ ] 복잡한 스토리지 시나리오를 설계할 수 있다
- [ ] 성능과 용량을 고려한 스토리지 선택을 할 수 있다
- [ ] 문제 발생 시 로그와 이벤트를 분석해서 원인을 파악할 수 있다
- [ ] 다른 팀원에게 스토리지 개념을 설명할 수 있다

---

**🎯 실습 완료 후 할 일:**
1. 이론편(05_02)으로 돌아가서 개념 재정리
2. 실제 프로젝트에 스토리지 요구사항 적용해보기  
3. 고급 스토리지 기능(Snapshot, CSI 등) 학습

**💡 기억할 핵심:**
- 실패를 두려워하지 말고 에러를 통해 배우기
- 실제 상황에서 자주 연습하기
- 문제 해결 과정을 기록하고 공유하기

---

*실습이 최고의 학습법입니다! 🚀*