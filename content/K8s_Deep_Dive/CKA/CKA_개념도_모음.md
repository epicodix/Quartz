---
title: CKA 핵심 개념도 모음
tags:
  - cka
  - kubernetes
  - diagram
  - visual
  - study
aliases:
  - CKA개념도
  - CKA시각화
date: 2026-05-12
category: K8s_Deep_Dive/CKA
status: 완성
priority: 높음
---

# 🎯 CKA 핵심 개념도 모음

CKA 시험에서 자주 출제되는 4개 핵심 주제를 시각적으로 정리한 개념도 모음입니다.  
각 HTML 파일은 브라우저에서 바로 열어볼 수 있습니다.

---

## 📋 목차

- [[#1. Pod 스케줄링 흐름|Pod 스케줄링]]
- [[#2. RBAC 권한 구조|RBAC]]
- [[#3. PV / PVC 바인딩|PV/PVC]]
- [[#4. NetworkPolicy 트래픽 제어|NetworkPolicy]]

---

## 1. Pod 스케줄링 흐름

> [!note] 핵심 개념
> `kubectl apply` → API Server → etcd → Scheduler(Filtering/Scoring) → kubelet → containerd

**개념도 파일**: `file:///Users/a1234/resume/diagrams/cka_pod_scheduling.html`

### 주요 포인트

| 단계 | 역할 | 트러블슈팅 |
|------|------|-----------|
| Filtering | 자원 부족 노드 제거 (CPU/Memory, Taint, NodeSelector) | `Pending` 상태 → describe pod |
| Scoring | 남은 노드 점수화 (자원 여유, Affinity) | `kubectl describe node` |
| Binding | 최고점 노드에 Pod 배치 | `Events` 섹션 확인 |

**Pod 상태별 원인**:
- `Pending` → 스케줄링 실패 (자원/Taint/Affinity)
- `ContainerCreating` → 이미지 풀 중 또는 볼륨 마운트 대기
- `CrashLoopBackOff` → 컨테이너 실행 후 즉시 종료 (앱 오류)
- `ImagePullBackOff` → 이미지 없음 / 레지스트리 인증 실패

관련 문서: [[CKA-실전-치트시트]] · [[CKA_시험_대비_핵심_복습_가이드]]

---

## 2. RBAC 권한 구조

> [!note] 핵심 개념
> Subject → Binding → Role → Resource  
> **Namespace 범위**: Role + RoleBinding  
> **Cluster 범위**: ClusterRole + ClusterRoleBinding

**개념도 파일**: `file:///Users/a1234/resume/diagrams/cka_rbac.html`

### 주요 포인트

| 리소스 | 범위 | 주요 verb |
|--------|------|----------|
| Role | namespace | get, list, create, delete, patch |
| ClusterRole | cluster-wide | nodes, PV, namespace 전체 |
| RoleBinding | namespace | Subject ↔ Role 연결 |
| ClusterRoleBinding | cluster-wide | Subject ↔ ClusterRole 연결 |

> [!warning] 자주 틀리는 포인트
> - `rules.verbs`는 **OR** 조건 (get **또는** list **또는** create)
> - `rules.resources`도 **OR** 조건
> - 하나의 Rule 안에서 verbs × resources = 허용 조합 **AND**

```bash
# RBAC 빠른 생성
kubectl create role pod-reader --verb=get,list --resource=pods -n default
kubectl create rolebinding read-pods --role=pod-reader --user=jane -n default

# 권한 확인
kubectl auth can-i get pods --as=jane -n default
```

---

## 3. PV / PVC 바인딩

> [!note] 핵심 개념
> StorageClass → PV 동적 프로비저닝 → PVC 바인딩 → Pod 마운트

**개념도 파일**: `file:///Users/a1234/resume/diagrams/cka_pv_pvc.html`

### 바인딩 조건 3가지

모든 조건이 **AND**로 충족되어야 바인딩:

1. `capacity.storage` — PVC 요청 크기 ≤ PV 크기
2. `accessModes` — PVC 요청 모드가 PV에 포함
3. `storageClassName` — 동일한 StorageClass (또는 둘 다 빈 값)

### accessModes 비교

| 모드 | 설명 | 주요 사용처 |
|------|------|-----------|
| ReadWriteOnce (RWO) | 1개 노드 읽기/쓰기 | DB, 단일 서버 |
| ReadOnlyMany (ROX) | 다수 노드 읽기 전용 | 설정 파일 공유 |
| ReadWriteMany (RWX) | 다수 노드 읽기/쓰기 | NFS, 공유 스토리지 |

### reclaimPolicy

- `Retain` — PVC 삭제 후 PV 수동 정리 필요 (데이터 보존)
- `Delete` — PVC 삭제 시 PV + 실제 스토리지 자동 삭제

---

## 4. NetworkPolicy 트래픽 제어

> [!note] 핵심 개념
> podSelector로 대상 Pod 선택 → ingress(들어오는 트래픽) / egress(나가는 트래픽) 제어

**개념도 파일**: `file:///Users/a1234/resume/diagrams/cka_networkpolicy.html`

### 방향 정의

- **ingress** = 선택된 Pod **로 들어오는** 트래픽 (from)
- **egress** = 선택된 Pod **에서 나가는** 트래픽 (to)

### 기본 패턴

```yaml
# Deny-All (가장 먼저 적용)
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
spec:
  podSelector: {}    # 네임스페이스 전체 Pod
  policyTypes:
  - Ingress
  - Egress
  # rules 없음 = 모두 차단
```

> [!danger] DNS 반드시 허용
> egress 정책 적용 시 DNS(포트 53 UDP/TCP) 명시 허용 필수  
> 빠뜨리면 Pod 내 도메인 이름 해석 실패 → 서비스 통신 불가

> [!warning] AND vs OR 혼동 주의
> - 같은 규칙 블록 안 `podSelector + namespaceSelector` → **AND** (둘 다 충족)
> - 별도 `-` 블록으로 분리 → **OR** (하나라도 충족)

```bash
# NetworkPolicy 확인
kubectl get networkpolicy -n <namespace>
kubectl describe networkpolicy <name> -n <namespace>
```

---

## 관련 문서

- [[CKA_시험_대비_핵심_복습_가이드]]
- [[CKA-실전-치트시트]]
- [[CKA-문제-해석-가이드]]
- [[CKA-실습-삽질기록-Q1-Q7]]
