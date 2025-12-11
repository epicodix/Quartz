---
title: CKA 실습문제 P1 - 종합 클러스터 진단 및 복구
tags:
  - kubernetes
  - cka
  - troubleshooting
  - practical-exam
  - node-management
  - networking
aliases:
  - CKA문제P1
  - 클러스터진단
date: 2025-12-11
category: CKA/실습문제
status: 완성
priority: 높음
---

# 🎯 CKA 실습문제 P1: 종합 클러스터 진단 및 복구

## 📑 목차
- [[#실습 시나리오 세팅|실습 시나리오 세팅]]
- [[#문제 상황 개요|문제 상황 개요]]
- [[#Task 1: 노드 장애 조치|Task 1: 노드 장애 조치]]
- [[#Task 2: 스케줄링 문제 해결|Task 2: 스케줄링 문제 해결]]
- [[#Task 3: DNS 서비스 복구|Task 3: DNS 서비스 복구]]
- [[#Task 4: 서비스 검증|Task 4: 서비스 검증]]
- [[#풀이 과정 분석|풀이 과정 분석]]
- [[#핵심 학습 포인트|핵심 학습 포인트]]

---

## 실습 시나리오 세팅

### 🛠️ 환경 구성
```bash
# 클러스터 구성
- Master: k8s-master (Ready)
- Worker: k8s-worker1 (NotReady)
- Network: Calico CNI
- Version: Kubernetes v1.30.14
```

### 🎭 문제 상황 생성 명령어
```bash
# 1. Broken App Deployment 생성 (스케줄링 실패용)
kubectl create deployment broken-app --image=nginx --replicas=3

# 2. Worker 노드에 maintenance taint 추가 (스케줄링 방해)
kubectl taint nodes k8s-worker1 maintenance=true:NoSchedule

# 3. Worker 노드에서 kubelet 서비스 중단 (노드 장애)
ssh root@100.74.129.75
systemctl stop kubelet
exit

# 4. CoreDNS scale을 0으로 설정 (DNS 서비스 중단)
kubectl scale deployment coredns --replicas=0 -n kube-system
```

---

## 문제 상황 개요

### 📊 초기 상태 확인
```bash
kubectl get nodes
# NAME          STATUS     ROLES           AGE     VERSION
# k8s-master    Ready      control-plane   4h      v1.30.14
# k8s-worker1   NotReady   <none>          3h58m   v1.30.14

kubectl get pods | grep Pending
# broken-app-654c7d464f-4ddt7   0/1   Pending   0   50m
# broken-app-654c7d464f-mdrcp   0/1   Pending   0   50m
# broken-app-654c7d464f-xhqwh   0/1   Pending   0   50m

kubectl get deployment coredns -n kube-system
# NAME      READY   UP-TO-DATE   AVAILABLE   AGE
# coredns   0/0     0            0           4h32m
```

---

## Task 1: 노드 장애 조치

### 📝 문제 설명
`k8s-worker1` 노드가 현재 `NotReady` 상태로 보고되고 있습니다.

**조건:**
1. `k8s-worker1` 노드를 진단하고, 정상적인 `Ready` 상태로 전환하십시오.
2. 해당 노드에서 Kubelet 서비스가 정상적으로 실행되어야 합니다.

### 🔍 진단 과정

#### 1단계: 노드 상태 분석
```bash
kubectl describe node k8s-worker1
```

**핵심 단서 확인**:
```yaml
Conditions:
  Ready    Unknown    NodeStatusUnknown   Kubelet stopped posting node status.
```

#### 2단계: Worker 노드 직접 진단
```bash
ssh root@100.74.129.75
systemctl status kubelet
```

**결과 분석**:
```bash
Active: inactive (dead) since Thu 2025-12-11 15:37:11 KST
```

#### 3단계: 문제 해결
```bash
# kubelet 서비스 재시작
systemctl start kubelet
systemctl enable kubelet

# 상태 확인
systemctl status kubelet
exit
```

### ✅ 검증 결과
```bash
kubectl get nodes
# NAME          STATUS   ROLES           AGE     VERSION
# k8s-master    Ready    control-plane   4h      v1.30.14
# k8s-worker1   Ready    <none>          3h58m   v1.30.14
```

---

## Task 2: 스케줄링 문제 해결

### 📝 문제 설명
Task 1 완료 후에도 `broken-app` Deployment의 Pod들이 `Pending` 상태입니다.

**조건:**
1. `broken-app` Deployment의 Pod들이 정상적으로 스케줄링되도록 문제를 해결하세요
2. 최소 1개 이상의 Pod가 `Running` 상태가 되어야 합니다

### 🔍 진단 과정

#### 1단계: Pod 실패 원인 분석
```bash
kubectl describe pod broken-app-654c7d464f-4ddt7
```

**에러 메시지 분석**:
```
Warning  FailedScheduling: 0/2 nodes are available: 
1 node(s) had untolerated taint {maintenance: true}, 
1 node(s) had untolerated taint {node-role.kubernetes.io/control-plane}
```

#### 2단계: Taint 확인
```bash
kubectl describe node k8s-worker1 | grep -A3 Taints
# Taints: maintenance=true:NoSchedule
```

#### 3단계: 문제 해결
```bash
kubectl taint nodes k8s-worker1 maintenance=true:NoSchedule-
```

### ✅ 검증 결과
```bash
kubectl get pods | grep broken-app
# broken-app-654c7d464f-4ddt7   1/1   Running   0   87m
# broken-app-654c7d464f-mdrcp   1/1   Running   0   87m
# broken-app-654c7d464f-xhqwh   1/1   Running   0   87m
```

---

## Task 3: DNS 서비스 복구

### 📝 문제 설명
클러스터 내부의 서비스 디스커버리 기능이 작동하지 않습니다.

**조건:**
1. `kube-system` 네임스페이스의 `coredns` Deployment가 정상적으로 작동하도록 수정하십시오.
2. `coredns`는 최소 2개의 레플리카를 가져야 합니다.

### 🔍 진단 과정

#### 1단계: CoreDNS 상태 확인
```bash
kubectl get deployment coredns -n kube-system
# NAME      READY   UP-TO-DATE   AVAILABLE   AGE
# coredns   0/0     0            0           4h32m
```

#### 2단계: 문제 해결
```bash
kubectl scale deployment coredns --replicas=2 -n kube-system
```

### ✅ 검증 결과
```bash
kubectl get pods -n kube-system | grep coredns
# coredns-55cb58b774-r9hkn   1/1   Running   0   7m58s
# coredns-55cb58b774-vj2kx   1/1   Running   0   7m58s
```

---

## Task 4: 서비스 검증

### 📝 문제 설명
위의 모든 작업을 완료한 후, 클러스터가 정상 작동하는지 검증하십시오.

**검증 방법:**
임시 Pod(`test-pod`)를 생성하여 `kubernetes.default` 서비스의 도메인 이름 해석이 성공해야 합니다.

### 🔍 검증 과정

#### 1단계: busybox 버전 이슈 해결
```bash
# 실패 사례
kubectl run test-dns --image=busybox --restart=Never -- nslookup kubernetes.default
kubectl logs test-dns
# ** server can't find kubernetes.default: NXDOMAIN
```

#### 2단계: 올바른 busybox 버전 사용
```bash
kubectl run test-dns-fix --image=busybox:1.28 --restart=Never --rm -it -- nslookup kubernetes.default
```

### ✅ 최종 검증 결과
```
Server:    10.96.0.10
Address 1: 10.96.0.10 kube-dns.kube-system.svc.cluster.local

Name:      kubernetes.default
Address 1: 10.96.0.1 kubernetes.default.svc.cluster.local
pod "test-dns-fix" deleted
```

---

## 풀이 과정 분석

### 🧠 문제 해결 사고 과정

#### 1. **증상 분석 우선순위**
```
노드 NotReady → Pod Pending → DNS 실패
    ↓              ↓            ↓
kubelet 문제    Taint 문제    Scale 문제
```

#### 2. **진단 명령어 체계**
```bash
# 노드 문제 진단
kubectl get nodes
kubectl describe node <NODE_NAME>
ssh <NODE> systemctl status kubelet

# Pod 문제 진단  
kubectl get pods
kubectl describe pod <POD_NAME>

# DNS 문제 진단
kubectl get deployment coredns -n kube-system
kubectl get pods -n kube-system | grep coredns
```

#### 3. **해결책 적용 순서**
1. **인프라 복구**: kubelet 재시작 (노드 안정화)
2. **스케줄링 복구**: Taint 제거 (Pod 배치 가능)
3. **서비스 복구**: CoreDNS Scale up (DNS 기능 활성화)
4. **기능 검증**: DNS 해결 테스트 (종합 확인)

---

## 핵심 학습 포인트

### 💡 CKA 핵심 스킬

#### 1. **에러 메시지 해석 능력**
```bash
# 이 메시지만 봐도 즉시 문제 파악 가능
"NodeStatusUnknown: Kubelet stopped posting node status"
→ kubelet 서비스 문제

"FailedScheduling: untolerated taint {maintenance: true}"
→ Taint 문제

"coredns 0/0"
→ Deployment Scale 문제
```

#### 2. **체계적 진단 순서**
```
1. 상위 리소스부터 → 하위 리소스
   (Node → Pod → Container)

2. 에러 이벤트 우선 확인
   kubectl describe <RESOURCE>

3. 계층별 상태 점검
   Service → Deployment → Pod → Node
```

#### 3. **복합 문제 해결 패턴**
```bash
# 하나씩 단계별 해결
문제1(kubelet) → 해결 → 검증
문제2(taint) → 해결 → 검증  
문제3(dns) → 해결 → 검증
통합검증 → 최종 완료
```

### 🎯 실전 팁

#### 1. **자주 실수하는 포인트**
- 노드만 Ready 되어도 끝이라고 착각 (Taint 확인 필수)
- busybox 최신 버전 nslookup 호환성 문제
- 명령어 문법 실수 (`kubectl run --` 구분자 위치)

#### 2. **시간 절약 방법**
```bash
# 한 번에 여러 상태 확인
kubectl get nodes,pods,deployments -A

# 핵심만 빠르게 확인
kubectl describe node <NAME> | grep -E "(Taints|Ready)"
kubectl describe pod <NAME> | tail -10

# 자주 쓰는 명령어 alias 설정
alias k=kubectl
alias kgp="kubectl get pods"
alias kgn="kubectl get nodes"
```

#### 3. **검증 체크리스트**
```bash
# 최종 검증 단계별 확인
□ kubectl get nodes → 모든 노드 Ready
□ kubectl get pods → 모든 Pod Running  
□ kubectl get pods -n kube-system → CoreDNS Running
□ DNS 테스트 → kubernetes.default 해결 성공
```

---

## 🏆 성과 측정

### ✅ 완료된 작업
- [x] **Task 1**: 노드 장애 복구 (kubelet 재시작)
- [x] **Task 2**: 스케줄링 문제 해결 (Taint 제거)
- [x] **Task 3**: DNS 서비스 복구 (CoreDNS Scale up)
- [x] **Task 4**: 서비스 검증 (DNS 해결 테스트)

### 📊 습득한 CKA 스킬
1. **노드 트러블슈팅**: kubelet 진단 및 복구
2. **스케줄링 관리**: Taint/Toleration 이해
3. **DNS 관리**: CoreDNS Deployment 운영
4. **종합 검증**: 기능 테스트 수행

### 🚀 다음 단계 권장사항
1. **Storage 문제**: PV/PVC 트러블슈팅
2. **RBAC 문제**: 권한 관련 장애 해결
3. **Network 문제**: Service/Ingress 연결 문제
4. **Security 문제**: SecurityContext, NetworkPolicy

> [!note] 실습 완료 기준
> 모든 Task 완료 + DNS 테스트 성공 = **CKA 실전 레벨 달성** 🎉