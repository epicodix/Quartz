# Kubernetes PV/PVC/StorageClass 실습 가이드 🎯

> 기억에 남는 체험형 스토리지 실습 - 단순 따라하기를 넘어 진짜 이해하기

## 💡 왜 기억이 안 남을까?

### 일반적인 학습 패턴
```
이론 읽기 → 예제 복붙 → 실행 → 성공 → 끝
```
**문제점:**
- 각 단계가 왜 필요한지 모름
- 에러를 경험하지 못함  
- 시각적으로 무슨 일이 일어나는지 안 보임
- 단순 따라하기로 끝남

### 기억에 남는 학습 패턴
```
문제 상황 → 실패 경험 → 단계별 해결 → 상태 관찰 → 반복 실험
```

## 🧠 스토리텔링으로 이해하기

### 📖 스토리: "클라우드 아파트 입주기"

```
🏢 StorageClass = "부동산 회사"
├── 종류: 원룸(local), 투룸(nfs), 펜트하우스(ssd)
└── "어떤 종류 방을 원하세요?"

📋 PVC = "아파트 신청서"  
├── 크기: 2GB 방 하나 주세요
├── 사용방식: 혼자 살 거예요(RWO) vs 룸메이트와(RWX)
└── "이 조건에 맞는 방 있나요?"

🔑 PV = "실제 방 배정"
├── 배정: "203호가 배정되었습니다"
├── 열쇠: "여기 열쇠 있어요"
└── 계약: PVC와 1:1 바인딩

🏠 Pod = "입주자"
├── 이사: "203호 /data 폴더에 짐 놓을게요"
├── 생활: "파일 저장하고 읽고"
└── 이사: Pod 삭제해도 방(PV)은 남아있음
```

## 🔥 체험형 실습

### Step 1: 문제 상황 체험하기

#### 1-1. 일부러 실패해보기
```bash
# PVC 없이 Pod 만들어서 실패 경험하기
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: homeless-pod
spec:
  containers:
  - name: app
    image: nginx
    volumeMounts:
    - name: storage
      mountPath: /data
  volumes:
  - name: storage
    persistentVolumeClaim:
      claimName: non-existent-pvc  # 존재하지 않는 PVC!
EOF
```

#실패로그1
```
Events:

  Type     Reason            Age   From               Message

  ----     ------            ----  ----               -------

  Warning  FailedScheduling  6s    default-scheduler  0/4 nodes are available: persistentvolumeclaim "non-existent-pvc" not found. preemption: 0/4 nodes are available: 4 Preemption is not helpful for scheduling.
  ```

#### 1-2. 실패 관찰하기
```bash
# 어떻게 실패하는지 관찰
kubectl describe pod homeless-pod

# 예상 결과: "persistentvolumeclaim "non-existent-pvc" not found"
# Pod 상태: Pending (스케줄링 실패)
```

#### 1-3. 문제 원인 파악
```bash
# 이벤트로 원인 확인
kubectl get events --sort-by='.lastTimestamp'

# Pod가 왜 시작 안 되는지 이해하기:
# PVC가 없음 → Pod가 스토리지를 찾을 수 없음 → 시작 불가
```



### Step 2: 단계별 문제 해결

#### 2-1. PVC 생성으로 해결
```bash
echo "=== 🏠 아파트 신청서(PVC) 작성하기 ==="
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: non-existent-pvc  # Pod가 찾던 이름과 일치!
spec:
  accessModes:
  - ReadWriteOnce  # 혼자 쓸 거예요
  resources:
    requests:
      storage: 1Gi   # 1GB 크기로 주세요
EOF
```

#### 2-2. 상태 변화 실시간 관찰
```bash
# 실시간으로 상태 변화 보기
watch -n 1 'echo "=== PVC 상태 ==="; kubectl get pvc; echo; echo "=== PV 상태 ==="; kubectl get pv; echo; echo "=== Pod 상태 ==="; kubectl get pod homeless-pod'

# 관찰 포인트:
# 1. PVC: Pending → Bound (PV와 연결됨)
# 2. PV: 자동으로 생성됨 (Dynamic Provisioning)
# 3. Pod: Pending → Running (스토리지 연결 성공)
```

### Step 3: 동작 원리 확인

#### 3-1. StorageClass 탐정놀이
```bash
echo "🕵️ 미션: 어떤 StorageClass가 사용되었을까?"

# PVC 정보 확인
kubectl describe pvc non-existent-pvc

# 사용된 StorageClass 찾기
kubectl get storageclass

# 정답 확인
echo "사용된 StorageClass: $(kubectl get pvc non-existent-pvc -o jsonpath='{.spec.storageClassName}')"
```

#### 3-2. 실제 파일 저장 테스트
```bash
echo "💾 미션: 실제로 파일을 저장할 수 있나?"

# Pod 안에서 파일 생성
kubectl exec homeless-pod -- sh -c "echo 'Hello Persistent Storage!' > /data/test.txt"

# 파일 확인
kubectl exec homeless-pod -- cat /data/test.txt

# 디스크 사용량 확인
kubectl exec homeless-pod -- df -h /data
```

#### 3-3. 영속성 테스트
```bash
echo "🔄 미션: Pod가 재시작되어도 데이터가 남아있을까?"

# Pod 삭제
kubectl delete pod homeless-pod

# 같은 PVC로 새 Pod 생성
kubectl run new-pod --image=nginx --overrides='{"spec":{"volumes":[{"name":"vol","persistentVolumeClaim":{"claimName":"non-existent-pvc"}}],"containers":[{"name":"nginx","image":"nginx","volumeMounts":[{"name":"vol","mountPath":"/data"}]}]}}'

# 기존 파일이 남아있는지 확인
kubectl exec new-pod -- cat /data/test.txt
# 결과: "Hello Persistent Storage!" (데이터 유지됨!)
```

## 🎮 게임식 실습 미션들

### 미션 1: 용량 수사관
```bash
echo "📏 미션: 요청한 용량과 실제 할당된 용량이 같을까?"

# 500Mi 요청
kubectl create pvc mystery-pvc --claim-size=500Mi

# 실제 할당된 용량 확인
kubectl get pv -o custom-columns=NAME:.metadata.name,CAPACITY:.spec.capacity.storage,CLAIM:.spec.claimRef.name

# Pod에서 실제 사용 가능한 용량 확인
kubectl run capacity-checker --image=busybox --rm -it \
  --overrides='{"spec":{"volumes":[{"name":"vol","persistentVolumeClaim":{"claimName":"mystery-pvc"}}],"containers":[{"name":"busybox","image":"busybox","volumeMounts":[{"name":"vol","mountPath":"/data"}],"stdin":true,"tty":true}]}}' \
  -- df -h /data

# 정리
kubectl delete pvc mystery-pvc
```

### 미션 2: 접근 모드 실험
```bash
echo "🚪 미션: 여러 Pod가 같은 PVC를 동시에 사용할 수 있을까?"

# ReadWriteOnce PVC 생성
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: single-access-pvc
spec:
  accessModes:
  - ReadWriteOnce  # 한 번에 하나의 노드에서만 접근
  resources:
    requests:
      storage: 1Gi
EOF

# 첫 번째 Pod 생성
kubectl run pod1 --image=nginx --overrides='{"spec":{"volumes":[{"name":"vol","persistentVolumeClaim":{"claimName":"single-access-pvc"}}],"containers":[{"name":"nginx","image":"nginx","volumeMounts":[{"name":"vol","mountPath":"/data"}]}]}}'

# 두 번째 Pod 생성
kubectl run pod2 --image=nginx --overrides='{"spec":{"volumes":[{"name":"vol","persistentVolumeClaim":{"claimName":"single-access-pvc"}}],"containers":[{"name":"nginx","image":"nginx","volumeMounts":[{"name":"vol","mountPath":"/data"}]}]}}'

# 결과 관찰
echo "두 Pod의 상태와 배치된 노드를 확인해보세요:"
kubectl get pods -o wide

# 같은 노드: 둘 다 Running
# 다른 노드: 하나는 Pending (RWO 제한)

# 정리
kubectl delete pod pod1 pod2
kubectl delete pvc single-access-pvc
```

### 미션 3: 스토리지 클래스 비교
```bash
echo "🏪 미션: 다양한 StorageClass 체험하기"

# 사용 가능한 StorageClass 확인
kubectl get storageclass

# 다른 StorageClass로 PVC 생성 (예시)
for sc in $(kubectl get storageclass -o jsonpath='{.items[*].metadata.name}'); do
  echo "=== StorageClass: $sc ==="
  
  kubectl create pvc test-pvc-$sc --storage-class=$sc --claim-size=1Gi
  
  # 성공/실패 확인
  sleep 5
  kubectl get pvc test-pvc-$sc
  
  # 정리
  kubectl delete pvc test-pvc-$sc --ignore-not-found
  
  echo ""
done
```

## 📊 시각적 상태 추적

### 실시간 대시보드
터미널을 4개 열고 각각에서 실행:

```bash
# 터미널 1: PVC 상태 모니터링
watch -n 2 "echo '=== PVC 상태 ==='; kubectl get pvc -o wide"

# 터미널 2: PV 상태 모니터링  
watch -n 2 "echo '=== PV 상태 ==='; kubectl get pv -o wide"

# 터미널 3: Pod 상태 모니터링
watch -n 2 "echo '=== Pod 상태 ==='; kubectl get pods -o wide"

# 터미널 4: 이벤트 로그
kubectl get events --watch
```

### 상태 변화 기록기
```bash
#!/bin/bash
# storage-monitor.sh - 상태 변화를 CSV로 기록

echo "시간,PVC상태,PV상태,Pod상태" > storage_timeline.csv

while true; do
    timestamp=$(date '+%H:%M:%S')
    pvc_status=$(kubectl get pvc my-test-pvc -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")
    pv_count=$(kubectl get pv --no-headers 2>/dev/null | wc -l)
    pod_status=$(kubectl get pod my-test-pod -o jsonpath='{.status.phase}' 2>/dev/null || echo "NotFound")
    
    echo "$timestamp,$pvc_status,PV개수:$pv_count,$pod_status" | tee -a storage_timeline.csv
    
    sleep 3
done
```

## 🔄 반복 학습 패턴

### 패턴 1: 생성 → 관찰 → 삭제 → 반복
```bash
echo "🔄 스토리지 라이프사이클 반복 연습"

for i in {1..5}; do
    echo "=== 🔄 반복 $i회차 ($(date)) ==="
    
    # 1. PVC 생성
    echo "1. PVC 생성 중..."
    kubectl create pvc cycle-pvc-$i --claim-size=1Gi
    
    # 2. 상태 확인
    echo "2. PVC 상태 확인:"
    kubectl get pvc cycle-pvc-$i
    
    # 3. Pod 생성  
    echo "3. Pod 생성 중..."
    kubectl run cycle-pod-$i --image=busybox --command sleep 30 \
      --overrides='{"spec":{"volumes":[{"name":"vol","persistentVolumeClaim":{"claimName":"cycle-pvc-'$i'"}}],"containers":[{"name":"busybox","image":"busybox","command":["sleep","30"],"volumeMounts":[{"name":"vol","mountPath":"/data"}]}]}}'
    
    # 4. 데이터 생성
    echo "4. 테스트 데이터 생성:"
    kubectl wait --for=condition=Ready pod/cycle-pod-$i --timeout=60s
    kubectl exec cycle-pod-$i -- sh -c "echo 'Test data from cycle $i' > /data/test-$i.txt"
    kubectl exec cycle-pod-$i -- ls -la /data/
    
    # 5. 정리
    echo "5. 리소스 정리:"
    kubectl delete pod cycle-pod-$i
    kubectl delete pvc cycle-pvc-$i
    
    echo "✅ $i회차 완료. 5초 후 다음 회차..."
    sleep 5
done
```

### 패턴 2: 에러 시나리오 체험
```bash
echo "💥 다양한 에러 상황 체험하기"

scenarios=(
    "huge-pvc:1000Gi:용량 초과"
    "bad-sc-pvc:1Gi:non-existent:없는 StorageClass"  
    "readonly-pvc:1Gi::ReadOnlyMany 테스트"
)

for scenario in "${scenarios[@]}"; do
    IFS=':' read -r name size sc description <<< "$scenario"
    
    echo "=== 💥 시나리오: $description ==="
    
    # PVC 생성 (에러 예상)
    if [ -n "$sc" ] && [ "$sc" != "::" ]; then
        kubectl create pvc $name --claim-size=$size --storage-class=$sc || echo "예상된 에러 발생"
    else
        kubectl create pvc $name --claim-size=$size || echo "예상된 에러 발생"
    fi
    
    # 에러 상태 관찰
    sleep 10
    echo "PVC 상태:"
    kubectl get pvc $name || echo "PVC 생성 실패"
    
    echo "에러 이벤트:"
    kubectl get events --field-selector involvedObject.name=$name
    
    # 정리
    kubectl delete pvc $name --ignore-not-found
    
    echo "다음 시나리오까지 5초..."
    sleep 5
done
```

## 💾 학습 기록 템플릿

### 실습 노트 자동 생성
```bash
# create-learning-note.sh
cat << EOF > "storage-learning-$(date +%Y%m%d).md"
# 스토리지 학습 기록 - $(date)

## 🎯 오늘 배운 핵심 개념

### StorageClass (부동산 회사)
- [ ] 역할: 어떤 종류의 스토리지를 제공할지 정의
- [ ] 종류: $(kubectl get storageclass -o jsonpath='{.items[*].metadata.name}')
- [ ] 기본값: $(kubectl get storageclass -o jsonpath='{.items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")].metadata.name}')

### PVC (신청서)
- [ ] 목적: 스토리지를 요청하는 명세서
- [ ] 접근 모드:
  - ReadWriteOnce (RWO): 한 노드에서만 읽기/쓰기
  - ReadOnlyMany (ROX): 여러 노드에서 읽기만
  - ReadWriteMany (RWX): 여러 노드에서 읽기/쓰기

### PV (실제 할당된 디스크)  
- [ ] 특징: PVC와 1:1 바인딩
- [ ] 라이프사이클: Available → Bound → Released → Failed

## 🧪 직접 해본 실습

### 성공한 것들
- [ ] PVC 생성: \`kubectl create pvc\`
- [ ] Pod에 마운트: \`volumeMounts + volumes\`
- [ ] 데이터 저장: \`kubectl exec pod -- echo 'data' > /path/file\`
- [ ] 영속성 확인: Pod 재시작해도 데이터 유지

### 경험한 에러들
| 에러 상황 | 원인 | 해결 방법 | 배운 점 |
|-----------|------|-----------|---------|
| PVC not found | PVC 없이 Pod 생성 | PVC 먼저 생성 | 순서가 중요함 |
| Pending PVC | 없는 StorageClass | 올바른 SC 지정 | SC 확인 필수 |
| Pod Pending | RWO 충돌 | 다른 노드 배치 | 접근 모드 이해 |

## 🎮 재밌었던 미션들
- [ ] 용량 수사관: 요청 vs 실제 용량 확인
- [ ] 접근 모드 실험: RWO로 여러 Pod 테스트  
- [ ] 영속성 테스트: Pod 삭제 후 데이터 확인
- [ ] 실시간 모니터링: watch로 상태 변화 관찰

## 🔗 이해한 관계도
\`\`\`
StorageClass ──┐
               ├─→ PV ←──→ PVC ←──→ Pod
사용가능한 디스크 ┘     실제디스크   신청서    사용자
\`\`\`

## 🎯 다음에 해볼 것
- [ ] NFS 스토리지 클래스 만들어보기
- [ ] 백업과 복원 실습  
- [ ] StatefulSet과 PVC 조합
- [ ] 동적 프로비저닝 깊이 이해하기

## 💡 핵심 명령어 체크리스트
\`\`\`bash
# 조회
kubectl get pvc,pv,storageclass
kubectl describe pvc [이름]

# 생성  
kubectl create pvc [이름] --claim-size=1Gi
kubectl create pvc [이름] --claim-size=1Gi --storage-class=[SC이름]

# 디버깅
kubectl get events --sort-by='.lastTimestamp'
kubectl exec [pod] -- df -h /mount/path

# 정리
kubectl delete pvc [이름]
# PV는 보통 자동으로 정리됨 (StorageClass 설정에 따라)
\`\`\`

---

**💡 기억할 점**: 스토리지는 "요청(PVC) → 할당(PV) → 사용(Pod)" 순서!
EOF

echo "✅ 학습 노트 생성 완료: storage-learning-$(date +%Y%m%d).md"
```

## 🎯 기억 정착 전략

### 1. 남에게 설명하기 연습
```bash
echo "🗣️ 설명 연습 스크립트"

echo "친구야, 쿠버네티스 스토리지는 이런 거야:"
echo "1. 먼저 PVC라는 신청서를 쓴다 - '1GB 디스크 주세요'"
echo "2. 그럼 쿠버네티스가 알아서 PV(실제 디스크)를 준비해준다" 
echo "3. Pod가 그 PV를 /data 같은 곳에 마운트해서 쓰는 거야"
echo "4. Pod가 죽어도 PV는 살아있어서 데이터가 안 사라져!"
echo ""
echo "RWO는 '혼자만 쓸 거야', RWX는 '여러 명이 같이 써도 돼'라는 뜻이야"
```

### 2. 자주 하는 실수 체크리스트
```bash
# 실수 방지 체크리스트
echo "❌ 자주 하는 실수들:"
echo "1. PVC 없이 Pod부터 만들기 → Pod Pending"
echo "2. 존재하지 않는 StorageClass 지정 → PVC Pending"  
echo "3. RWO PVC를 여러 노드에서 사용 → Pod Pending"
echo "4. 용량을 너무 크게 요청 → PVC Pending"
echo "5. PVC 이름을 Pod volumeMount에서 틀리게 쓰기"
```

### 3. 체크포인트 질문들
```bash
echo "🤔 스스로 확인하기:"
echo "Q1. StorageClass의 역할은?"
echo "Q2. PVC와 PV의 차이는?"  
echo "Q3. RWO와 RWX의 차이는?"
echo "Q4. Pod가 삭제되면 데이터도 사라질까?"
echo "Q5. 같은 PVC를 여러 Pod에서 동시에 쓸 수 있을까?"
```

## 🚀 마스터 체크리스트

### Level 1: 기초 (✅ 체크해보세요)
- [ ] PVC 생성할 수 있다
- [ ] Pod에 PVC를 마운트할 수 있다  
- [ ] 파일을 저장하고 읽을 수 있다
- [ ] Pod를 삭제하고 재생성해도 데이터가 유지됨을 확인했다

### Level 2: 응용 (🎯 도전해보세요)
- [ ] 다양한 StorageClass를 사용해봤다
- [ ] 접근 모드의 차이를 실험으로 확인했다
- [ ] 용량 제한 에러를 경험하고 해결했다
- [ ] 실시간 상태 모니터링을 해봤다

### Level 3: 고급 (🔥 마스터 레벨)
- [ ] 에러 상황을 일부러 만들고 해결할 수 있다
- [ ] kubectl events로 문제 원인을 파악할 수 있다
- [ ] 다른 사람에게 스토리지 개념을 설명할 수 있다
- [ ] 실제 프로젝트에서 스토리지 설계를 할 수 있다

---

**💡 핵심 메시지**: 스토리지는 "아파트 임대"와 같다!
- StorageClass = 부동산 회사 (어떤 종류?)
- PVC = 임대 신청서 (얼마나, 어떻게?)  
- PV = 실제 배정된 방 (계약 완료)
- Pod = 입주자 (실제 사용)

**🎯 기억법**: 실패를 두려워하지 말고 에러를 경험하며 배우자!

---

*이 가이드를 통해 스토리지를 진짜로 이해하고 오래 기억하세요! 🚀*