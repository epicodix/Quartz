---
title: CKA 시험 대비 핵심 복습 가이드
tags:
  - cka
  - kubernetes
  - exam
  - certification
  - study-guide
aliases:
  - CKA복습가이드
  - 시험대비
  - CKA준비
date: 2025-12-08
category: K8s_Deep_Dive/k8s실습
status: 완성
priority: 최우선
---

# 🎯 CKA 시험 대비 핵심 복습 가이드

## 📑 목차
- [[#🚨 최우선 복습 파트 (80% 출제)|최우선 복습]]
- [[#⚡ 시험 3일 전 체크리스트|3일 전 체크리스트]]
- [[#📚 문서별 복습 우선순위|복습 우선순위]]
- [[#💡 실습 명령어 암기 리스트|필수 암기]]
- [[#⏰ 시간 관리 전략|시간 관리]]

---

## 🚨 최우선 복습 파트 (CKA 80% 출제)

### 1. 🔐 RBAC (15-20% 출제) **[최우선]**

> [!danger] 필수 복습 파일
> **주 문서**: `08_01_쿠버네티스_클러스터_권한_관리_시험_부록.md`
> 
> 이 문서는 실제 CKA 시험 문제 패턴으로 작성되어 있어 **반드시 숙지**해야 합니다.

#### 🎯 핵심 암기 사항
```bash
# ServiceAccount + Role + RoleBinding 세트 (5분 내 완성)
kubectl create serviceaccount my-sa -n namespace
kubectl create role my-role --verb=get,list,watch --resource=pods -n namespace
kubectl create rolebinding my-binding --role=my-role --serviceaccount=namespace:my-sa -n namespace

# 검증 (반드시 마지막에 실행)
kubectl auth can-i get pods -n namespace --as=system:serviceaccount:namespace:my-sa
```

#### ⚠️ 자주 틀리는 실수
- **apiGroups**: pods/services는 `[""]`, deployments는 `["apps"]`
- **verbs**: "read"가 아니라 `["get", "list", "watch"]`
- **네임스페이스 vs 클러스터**: nodes, pv는 ClusterRole 필요

### 2. 💾 스토리지 (10-15% 출제) **[최우선]**

> [!danger] 필수 복습 파일
> **주 문서**: `05_02_Storage_PV_PVC_VolumeClaimTemplate_완전정리.md`
> **실습**: `05_03_Storage_실습_예제_모음.md`

#### 🎯 핵심 개념
```yaml
# PVC 생성 패턴 (암기 필수)
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-pvc
spec:
  accessModes:
    - ReadWriteOnce  # RWO(단일 노드), RWX(다중 노드), ROX(읽기 전용)
  resources:
    requests:
      storage: 1Gi
```

#### ⚠️ 주요 실수
- **accessModes** 선택 오류: 단일 Pod → RWO, 다중 Pod 동시 접근 → RWX
- **volumeMounts vs volumes** 구분 못함
- **StorageClass** 지정 누락

### 3. 🚀 Pod 스케줄링 (10-15% 출제) **[최우선]**

> [!danger] 필수 복습 파일
> **주 문서**: `07_02_고급파드관리및스케줄링전략.md`
> **보조**: `06_02_테인트와_톨러레이션_파드_할당_조건.md`

#### 🎯 핵심 스케줄링 패턴
```yaml
# nodeSelector (가장 간단)
spec:
  nodeSelector:
    disktype: ssd

# toleration (테인트가 있는 노드에 배치)
spec:
  tolerations:
  - key: "dedicated"
    operator: "Equal"
    value: "special-user"
    effect: "NoSchedule"
```

#### ⚠️ 주요 실수
- **Affinity vs Anti-Affinity** 헷갈림
- **preferredDuringScheduling vs required** 차이점 모름
- **toleration** 문법 오류

### 4. ⚕️ Pod Health Checks (10% 출제) **[중요]**

> [!danger] 필수 복습 파일
> **주 문서**: `07_02_고급파드관리및스케줄링전략.md` (Probe 섹션)

#### 🎯 핵심 Probe 패턴
```yaml
# livenessProbe (재시작 트리거)
livenessProbe:
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 30
  periodSeconds: 10

# readinessProbe (트래픽 차단)
readinessProbe:
  httpGet:
    path: /ready
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 5
```

### 5. 📊 모니터링 & 오토스케일링 (10% 출제) **[중요]**

> [!danger] 필수 복습 파일
> **주 문서**: `09-3_메트릭서버와_HPA_상세가이드.md`

#### 🎯 HPA 핵심 명령어
```bash
# HPA 생성 (한 줄로 해결)
kubectl autoscale deployment my-app --cpu-percent=70 --min=2 --max=10

# 메트릭서버 상태 확인
kubectl top nodes
kubectl top pods
```

---

## ⚡ 시험 3일 전 체크리스트

### Day -3: 핵심 명령어 반복 암기
- [ ] RBAC 3가지 패턴 (SA+Role, User+ClusterRole, 커스텀 Role) 각각 5분 내 구현
- [ ] 스토리지 PVC 생성 및 Pod 연결 2분 내 완성
- [ ] nodeSelector, toleration, affinity 각각 3분 내 작성

### Day -2: 실전 시나리오 연습  
- [ ] **종합 문제**: monitoring 네임스페이스에 prometheus SA 생성, 클러스터 전체 pod 읽기 권한
- [ ] **종합 문제**: nginx pod + PVC 연결 + nodeSelector로 특정 노드 배치
- [ ] **종합 문제**: HPA로 CPU 70% 기준 auto-scaling 설정

### Day -1: 최종 점검
- [ ] `kubectl` 치트시트 마지막 확인
- [ ] 자주 틀리는 YAML 문법 체크 (하이픈, 들여쓰기)
- [ ] 시험 환경에서 `kubectl explain` 사용법 숙지

---

## 📚 문서별 복습 우선순위

### 🔥 최우선 (반드시 정독)
| 순위 | 문서명 | 복습 이유 | 예상 소요시간 |
|------|--------|----------|---------------|
| 1 | `08_01_쿠버네티스_클러스터_권한_관리_시험_부록.md` | 실제 시험 문제 패턴, 고득점 필수 | 2시간 |
| 2 | `05_02_Storage_PV_PVC_VolumeClaimTemplate_완전정리.md` | 스토리지 개념 완벽 이해 | 1.5시간 |
| 3 | `07_02_고급파드관리및스케줄링전략.md` | Probe, 스케줄링 집중 | 1시간 |
| 4 | `09-3_메트릭서버와_HPA_상세가이드.md` | 모니터링 및 스케일링 | 1시간 |

### ⚡ 고중요도 (핵심 정리)
| 순위 | 문서명 | 복습 포인트 | 예상 소요시간 |
|------|--------|-------------|---------------|
| 5 | `04_00_kubernetes-service-types-guide.md` | Service 타입별 차이점 | 30분 |
| 6 | `06_02_테인트와_톨러레이션_파드_할당_조건.md` | Taint/Toleration 실습 | 30분 |
| 7 | `9-2_쿠버네티스_롤링업데이트와_동적배포.md` | Deployment 업데이트 전략 | 30분 |

### 📖 참고용 (시간 남을 때)
- `moc-k8s/` 폴더의 개념 정리 문서들
- `K8s_Deep_Dive/` 시리즈 (이론 보강용)
- `네트워크 기초/` (네트워킹 이해 보강)

---

## 💡 실습 명령어 암기 리스트

### 🔐 RBAC 필수 명령어 (암기 필수)
```bash
# 기본 생성
kubectl create serviceaccount SA_NAME -n NAMESPACE
kubectl create role ROLE_NAME --verb=VERBS --resource=RESOURCES -n NAMESPACE
kubectl create rolebinding BINDING_NAME --role=ROLE_NAME --serviceaccount=NS:SA -n NAMESPACE

# 클러스터 레벨
kubectl create clusterrole CLUSTERROLE_NAME --verb=VERBS --resource=RESOURCES
kubectl create clusterrolebinding BINDING_NAME --clusterrole=ROLE --user=USER

# 검증 (필수!)
kubectl auth can-i VERB RESOURCE --as=USER/SA
```

### 💾 스토리지 필수 명령어
```bash
# PVC 생성
kubectl create -f pvc.yaml

# Pod에 볼륨 연결 확인
kubectl describe pod POD_NAME | grep -A 5 Mounts
```

### 🚀 스케줄링 확인 명령어
```bash
# 노드 정보 확인
kubectl get nodes --show-labels
kubectl describe node NODE_NAME

# Pod 스케줄링 상태 확인
kubectl get pods -o wide
kubectl describe pod POD_NAME | grep -A 5 Events
```

### 📊 모니터링 명령어
```bash
# 메트릭 확인
kubectl top nodes
kubectl top pods

# HPA 상태 확인
kubectl get hpa
kubectl describe hpa HPA_NAME
```

---

## ⏰ 시간 관리 전략

### 📋 문제 유형별 목표 시간
| 문제 유형 | 목표 시간 | 배점 비중 | 전략 |
|-----------|-----------|----------|------|
| **RBAC** | 10-15분 | 15-20% | 첫 15분 집중, 고득점 확보 |
| **스토리지** | 8-12분 | 10-15% | PVC 패턴 암기로 빠르게 처리 |
| **스케줄링** | 8-12분 | 10-15% | nodeSelector 우선, affinity 후순위 |
| **네트워킹** | 10-15분 | 10-15% | Service, Ingress 기본기 |
| **트러블슈팅** | 15-20분 | 20-25% | logs, describe 활용 |

### ⚡ 시험 당일 전략
1. **첫 30분**: 쉬운 문제 우선 해결 (확실한 점수 확보)
2. **중간 60분**: 고배점 문제 집중 (RBAC, 트러블슈팅)
3. **마지막 30분**: 검토 및 미완성 문제 마무리

---

## 🎯 마지막 당부

### ✅ 시험 성공의 핵심
1. **명령어 암기**: `kubectl create` 명령어 완벽 숙지
2. **YAML 구조**: 들여쓰기, 하이픈 실수 방지
3. **검증 습관**: 모든 작업 후 `kubectl get`, `kubectl describe`로 확인
4. **시간 관리**: 모르는 문제에 시간 낭비 금지

### 🚨 자주 실수하는 부분
- **네임스페이스 누락**: `-n namespace` 빼먹기
- **문법 오류**: YAML 들여쓰기, 하이픈(-) 실수
- **검증 생략**: 권한 설정 후 `kubectl auth can-i` 실행 안함
- **시간 분배**: 어려운 문제에 과도한 시간 투자

### 💪 자신감 부스터
> **당신의 옵시디언 문서가 증명하는 것들:**
> - 체계적인 학습: 기초부터 고급까지 단계별 학습 완료
> - 실전 경험: Harbor, Prometheus 등 복잡한 실습 성공
> - 문제해결 능력: DNS, 스토리지 등 다양한 트러블슈팅 경험
> 
> **이미 충분히 준비되었습니다. 자신 있게 도전하세요!** 🚀

---

## 📝 마지막 점검 (시험 당일)

### ⏰ 시험 시작 전 (5분)
- [ ] `kubectl` 버전 확인
- [ ] `kubectl explain` 사용법 테스트
- [ ] 별칭 설정: `alias k=kubectl`
- [ ] 자동완성 확인: `source <(kubectl completion bash)`

### 🎯 시험 중 체크리스트
- [ ] 각 문제마다 네임스페이스 확인
- [ ] YAML 작성 시 들여쓰기 2칸 유지
- [ ] 모든 작업 후 `kubectl get` 으로 상태 확인
- [ ] 15분마다 시간 체크, 진행률 점검

**CKA 시험 성공을 위해 파이팅! 🎉**