---
title: '컨트롤 플레인 분석: 쿠버네티스의 뇌는 어떻게 동작하는가?'
summary: 쿠버네티스의 '뇌' 역할을 하는 컨트롤 플레인을 분석합니다. 선언적 관리와 컨트롤 루프를 구현하는 핵심 컴포넌트들(API 서버, etcd
  등)이 어떻게 '전문가 팀'처럼 협력하여 클러스터의 상태를 관리하고 유지하는지 설명합니다.
tags:
- Kubernetes
- Control Plane
- kube-apiserver
- etcd
- Architecture
category: 기술분석
difficulty: 중급
estimated_time: 15분
created: '2025-10-30'
updated: '2025-11-08'
tech_stack:
- Kubernetes
- kube-apiserver
- etcd
- kube-scheduler
- kube-controller-manager
---

# 3. 컨트롤 플레인 분석: 뇌는 어떻게 동작하는가?

지난 아티클에서 Container, Pod, Node라는 기본 구성 요소를 배웠습니다. 이제 핵심 질문이 남았습니다: **"그럼 이 Pod들을 누가, 어떻게 관리하는 거죠?"**

그 답이 바로 이번에 배울 **컨트롤 플레인(Control Plane)**입니다. 1편에서 배운 쿠버네티스의 핵심 철학 '선언적 관리'와 '컨트롤 루프'를 실제로 구현하는 것이 바로 컨트롤 플레인입니다.

컨트롤 플레인은 하나의 거대한 프로그램이 아니라, 각자 전문 분야가 있는 **'전문가 팀'**으로 이루어져 있습니다. 마치 회사에 CEO, CFO, CTO가 각각의 역할을 하듯이요.

---

## 컨트롤 플레인의 위치와 역할

### 전체 아키텍처 다시 보기

```
[쿠버네티스 클러스터]
│
├── [Control Plane Nodes] ← 여기가 오늘의 주제!
│   ├── kube-apiserver      (소통 창구)
│   ├── etcd                (데이터베이스)
│   ├── kube-scheduler      (배치 결정자)
│   ├── kube-controller-manager (상태 유지자)
│   └── cloud-controller-manager (클라우드 연동)
│
└── [Worker Nodes]
    └── Pod들이 실행되는 곳
```

컨트롤 플레인은 보통 **마스터 노드(Master Node)** 또는 **Control Plane Node**라고 불리는 별도의 서버에서 실행됩니다. 운영 환경에서는 고가용성을 위해 보통 3개 이상의 Control Plane Node를 구성합니다.

> **중요:** Control Plane은 "무엇을 해야 하는지" 결정하고, Worker Node는 "실제로 실행"합니다. 이 역할 분리가 쿠버네티스의 확장성과 안정성의 핵심입니다.

---

## 컨트롤 플레인의 핵심 구성 요소

각 컴포넌트를 '회사 조직'에 비유하면 이해가 쉽습니다.

### 1. API 서버 (kube-apiserver): 유일한 소통 창구

**역할:** 클러스터의 모든 요청이 거쳐 가는 유일한 '정문'입니다.

- 개발자가 `kubectl` 명령어를 사용할 때
- 클러스터 내부 컴포넌트들이 서로 통신할 때
- 외부 시스템이 쿠버네티스와 통신할 때

**모든 통신은 반드시 API 서버를 거쳐야 합니다.**

#### 왜 필요한가? (실무적 관점)

만약 모두가 제멋대로 `etcd`를 직접 수정하고, 스케줄러를 직접 호출할 수 있다면 어떻게 될까요? 클러스터는 금방 엉망이 될 겁니다.

API 서버는 다음과 같은 중요한 역할을 합니다:

**1. 인증/인가 (Authentication/Authorization)**
```
요청 → "당신은 누구인가요?" (인증)
     → "이 작업을 할 권한이 있나요?" (인가)
     → ✓ 통과 / ✗ 거부
```

**2. 검증 (Validation)**
```
"Pod 이름에 특수문자는 안 됩니다"
"메모리 요청량이 음수일 수 없습니다"
→ 잘못된 요청은 미리 걸러냄
```

**3. 변환 및 기본값 적용 (Mutation)**
```
사용자가 일부 필드를 생략하면
→ API 서버가 기본값을 자동으로 채워줌
```

**4. etcd와의 유일한 통신 창구**

다른 컴포넌트들은 `etcd`에 직접 접근하지 못합니다. 오직 API 서버만 `etcd`를 읽고 쓸 수 있습니다. 이것이 데이터 일관성을 보장하는 핵심입니다.

**5. Watch 메커니즘 제공**

API 서버는 RESTful API이면서도 특별한 기능이 있습니다:

```
일반 REST API: "지금 상태가 어때?" (요청 → 응답)
Kubernetes API: "상태가 바뀌면 알려줘!" (연결 유지 → 변경 시 즉시 알림)
```

이 Watch 메커니즘 덕분에 컨트롤러들은 폴링(주기적 확인) 없이도 변경 사항을 즉시 감지할 수 있습니다.

#### 비유

**회사의 '중앙 안내 데스크' 또는 'CEO 비서실'**

모든 방문객과 내부 직원은 이 곳을 통해서만 CEO(클러스터)에게 용무를 전달할 수 있습니다. 비서실은 신분을 확인하고, 권한을 체크하고, 메시지를 정리해서 전달합니다.

---

### 2. etcd: 모든 것을 기억하는 데이터베이스

**역할:** 클러스터의 **모든 상태 정보를 저장**하는 분산 데이터베이스입니다.

- 사용자가 선언한 '원하는 상태' (예: "nginx Pod 3개")
- 현재 클러스터의 '실제 상태' (예: "nginx Pod 2개 실행 중, 1개 Pending")
- 모든 리소스의 메타데이터 (이름, 레이블, 생성 시간 등)

#### etcd의 특징

**1. 일관성 보장 (Consistency)**

`etcd`는 Raft 합의 알고리즘을 사용하여 분산 환경에서도 데이터 일관성을 보장합니다:

```
etcd-1, etcd-2, etcd-3 (3대로 구성)
└── 과반수(2대 이상)가 동의해야 변경 완료
    └── 네트워크 분리 등의 상황에서도 일관성 유지
```

**2. Key-Value 저장소**

`etcd`는 단순한 Key-Value 저장소입니다:

```
Key: /registry/pods/default/nginx-abc123
Value: {Pod의 모든 정보를 JSON 형태로}
```

**3. Watch 지원**

특정 Key의 변경 사항을 실시간으로 감지할 수 있습니다. API 서버가 이 기능을 활용하여 다른 컴포넌트들에게 변경 사항을 알립니다.

#### 왜 필요한가? (실무적 관점)

`etcd`는 클러스터의 **'유일한 진실의 원천(Single Source of Truth)'**입니다.

만약 `etcd`의 데이터가 손상되면:
- 클러스터는 어떤 Pod가 있어야 하는지 모릅니다
- 어떤 설정이 적용되어 있는지 모릅니다
- 사실상 클러스터 전체가 기억상실에 걸립니다

**그래서 실제 운영 환경에서는:**

```
Production 환경
├── etcd를 최소 3대로 구성 (홀수 권장)
├── 정기적인 백업 (매일 또는 매시간)
├── 별도의 고성능 디스크 사용 (SSD)
└── etcd만 전용으로 사용하는 서버 구성
```

`etcd`가 죽으면 클러스터가 멈추므로, 가장 신경 써서 관리해야 하는 컴포넌트입니다.

#### 비유

**회사의 '중앙 원장(Ledger)' 또는 '전사 데이터베이스'**

모든 계약서, 직원 명부, 프로젝트 상태가 기록된 곳입니다. 이것이 손상되면 회사는 누가 직원인지, 무슨 프로젝트를 하고 있는지조차 모르게 됩니다.

---

### 3. 스케줄러 (kube-scheduler): Pod를 배치하는 전문가

**역할:** 새로 생성된 Pod를 **어느 Node에 배치할지 결정**합니다.

주의: 스케줄러는 "결정"만 합니다. 실제로 Pod를 실행하는 것은 각 Node의 `kubelet`이 합니다.

#### 스케줄링 프로세스

```
1. API 서버 감시: "Node가 아직 배정되지 않은 Pod가 있나?"
2. 필터링 (Filtering): "이 Pod를 실행할 수 있는 Node는?"
   - 리소스(CPU, 메모리) 충분한가?
   - Node 선택자(nodeSelector) 조건에 맞는가?
   - Taints/Tolerations 조건은?
   
3. 점수 매기기 (Scoring): "그 중에서 가장 좋은 Node는?"
   - 리소스가 가장 균등하게 분산되는 Node는?
   - 같은 애플리케이션의 Pod가 이미 많이 있는 Node는 피하기
   - 데이터가 이미 있는 Node에 우선 배치하기
   
4. 결정: "Node A가 최적이네!"
5. API 서버에 전달: "이 Pod는 Node A에 배치해줘"
```

#### 왜 필요한가? (실무적 관점)

스케줄러가 없다면 개발자가 직접 "이 Pod는 서버 3번에..."라고 지정해야 합니다. 클러스터가 100대라면? 생각만 해도 끔찍하죠.

스케줄러는 다음과 같은 복잡한 결정을 자동으로 내립니다:

**시나리오 1: 리소스 최적화**
```
Pod가 4GB 메모리를 요청
├── Node 1: 8GB 중 7GB 사용 중 → ✗ 불가능
├── Node 2: 16GB 중 8GB 사용 중 → ✓ 가능
└── Node 3: 16GB 중 2GB 사용 중 → ✓ 가능하고 더 여유로움 → 선택!
```

**시나리오 2: 고가용성**
```
같은 애플리케이션의 Pod 3개를 배치
├── Node 1: Pod A 배치
├── Node 2: Pod B 배치
└── Node 3: Pod C 배치
→ 한 Node가 죽어도 서비스는 계속 운영됨
```

**시나리오 3: 특수 하드웨어**
```
GPU 작업이 필요한 Pod
└── GPU가 장착된 Node에만 배치
```

#### 고급 스케줄링 옵션 (미리보기)

실전에서는 더 세밀한 제어가 가능합니다:

- **Node Affinity**: "특정 레이블이 있는 Node에 배치해줘"
- **Pod Affinity**: "A Pod와 같은 Node에 배치해줘" (캐시 공유 등)
- **Pod Anti-Affinity**: "A Pod와 다른 Node에 배치해줘" (고가용성)
- **Taints and Tolerations**: "이 Node는 특별한 Pod만 받아줘"

#### 비유

**신입사원을 어느 부서, 어느 자리에 배치할지 결정하는 '인사팀 담당자'**

각 팀의 업무량, 신입의 역량, 팀 간의 협업 필요성 등을 모두 고려하여 최적의 배치를 결정합니다.

---

### 4. 컨트롤러 매니저 (kube-controller-manager): 상태를 맞추는 해결사들

**역할:** 1편에서 배운 **'컨트롤 루프'를 실제로 실행**하는 컴포넌트입니다.

컨트롤러 매니저는 사실 여러 개의 컨트롤러를 하나의 프로세스로 묶어놓은 것입니다. 각 컨트롤러는 한 가지 리소스 타입에만 집중합니다.

#### 주요 컨트롤러들

**1. Node Controller**
```
임무: "모든 Node가 살아있나?"
주기: 매 10초마다 확인

시나리오:
- Node 1이 40초 동안 응답 없음
- Node Controller: "Node 1이 죽었다고 판단"
- API 서버에 알림: "Node 1의 Pod들을 다른 Node에 재배치해줘"
```

**2. ReplicaSet Controller**
```
임무: "Pod 개수가 원하는 만큼인가?"
관찰: etcd의 ReplicaSet 리소스를 watch

시나리오:
- 원하는 상태: nginx Pod 3개
- 현재 상태: nginx Pod 2개
- ReplicaSet Controller: "1개 부족하네!"
- API 서버에 요청: "nginx Pod 1개 더 만들어줘"
```

**3. Deployment Controller**
```
임무: "롤링 업데이트를 관리"
관찰: Deployment 리소스를 watch

시나리오:
- 사용자: nginx 버전을 1.19 → 1.21로 업데이트
- Deployment Controller:
  1. 새 버전의 ReplicaSet 생성
  2. 새 Pod 하나씩 생성
  3. 새 Pod가 정상 작동 확인
  4. 구 버전 Pod 하나씩 삭제
  → 무중단 배포 완성!
```

**4. Service Controller**
```
임무: "Service가 제대로 동작하는가?"
- 로드밸런서 생성/업데이트
- Endpoint 업데이트
```

**5. Job Controller**
```
임무: "일회성 작업이 완료되었나?"
- 성공하면 종료
- 실패하면 재시도
```

#### 컨트롤 루프 복습 (실제 동작)

각 컨트롤러는 다음 루프를 끊임없이 반복합니다:

```go
for {
    // 1. 관찰 (Observe)
    desired := getDesiredState()  // etcd에서 원하는 상태 읽기
    current := getCurrentState()  // etcd에서 현재 상태 읽기
    
    // 2. 비교 (Compare)
    if desired != current {
        // 3. 실행 (Act)
        diff := calculateDiff(desired, current)
        takeAction(diff)  // API 서버에 변경 요청
    }
    
    // 4. 대기 후 반복
    sleep(10 seconds)
}
```

#### 왜 필요한가? (실무적 관점)

컨트롤러가 없다면 쿠버네티스는 그냥 "한 번 실행하고 끝"인 시스템일 뿐입니다. 컨트롤러 덕분에:

- **자동 복구 (Self-healing)**: Pod가 죽으면 자동으로 새로 생성
- **자동 확장 (Auto-scaling)**: 부하에 따라 Pod 개수 자동 조절
- **무중단 배포 (Rolling Update)**: 서비스 중단 없이 새 버전 배포
- **상태 유지 (Reconciliation)**: 누군가 수동으로 Pod를 지워도 자동으로 다시 생성

#### 비유

**'영업팀장', '인사팀장', '시설관리팀장' 등 각 부서의 '팀장들'**

각자 자기 팀의 목표(원하는 상태)를 달성하기 위해 끊임없이 현재 상황을 체크하고 문제를 해결합니다.

---

### 5. Cloud Controller Manager: 클라우드와의 연결 고리

**역할:** 클라우드 제공자(AWS, GCP, Azure 등)의 API와 쿠버네티스를 연결합니다.

#### 주요 기능

**1. Node Controller**
- 클라우드 VM이 삭제되면 쿠버네티스 Node도 제거

**2. Route Controller**
- 클러스터 네트워크 라우팅을 클라우드 VPC에 설정

**3. Service Controller**
- `type: LoadBalancer` Service를 만들면
- 실제 클라우드 로드밸런서(ELB, Cloud Load Balancer 등) 자동 생성

**예시:**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-app
spec:
  type: LoadBalancer  # ← 이 한 줄로
  ports:
    - port: 80
```

```
Cloud Controller Manager가 자동으로:
├── AWS ELB 생성
├── Public IP 할당
└── 쿠버네티스 Service와 연결
```

#### 비유

**'외부 업체 담당자'**

회사가 외부 서비스(클라우드)를 사용할 때, 그 서비스와의 계약, 설정, 관리를 담당하는 직원입니다.

---

## 전문가 팀의 협업 과정: 실제 시나리오

이제 모든 컴포넌트를 알았으니, 실제로 어떻게 협력하는지 구체적인 시나리오로 알아보겠습니다.

### 시나리오: "Nginx 배포를 3개로 스케일 아웃하기"

개발자가 다음 명령을 실행했다고 가정합니다:

```bash
kubectl scale deployment nginx --replicas=3
```

현재 nginx Pod는 1개만 실행 중입니다. 이제 3개로 늘려야 합니다.

#### 단계별 프로세스

**1단계: 사용자 → API 서버**

```
kubectl → API 서버: "nginx Deployment의 replicas를 3으로 변경해줘"
API 서버:
  ├── 인증 확인: "이 사용자가 누군지 확인"
  ├── 인가 확인: "Deployment를 수정할 권한이 있는지 확인"
  ├── 검증: "replicas=3이 유효한 값인지 확인"
  └── ✓ 통과!
```

**2단계: API 서버 → etcd**

```
API 서버 → etcd: "nginx Deployment의 spec.replicas를 3으로 업데이트"
etcd:
  ├── 변경 사항 저장
  └── "저장 완료!"
```

**3단계: Deployment Controller 감지**

```
Deployment Controller (watch 중):
  "어? nginx Deployment의 spec.replicas가 1에서 3으로 바뀌었네!"
  
현재 상황 파악:
  ├── 원하는 상태: replicas=3
  └── 현재 상태: Pod 1개만 실행 중
  
결정:
  "ReplicaSet의 replicas도 3으로 업데이트해야겠다"
  
Deployment Controller → API 서버:
  "nginx ReplicaSet의 replicas를 3으로 변경해줘"
```

**4단계: API 서버 → etcd (다시)**

```
API 서버 → etcd: "nginx ReplicaSet의 spec.replicas를 3으로 업데이트"
```

**5단계: ReplicaSet Controller 감지**

```
ReplicaSet Controller (watch 중):
  "nginx ReplicaSet의 replicas가 바뀌었네!"
  
현재 상황 파악:
  ├── 원하는 상태: Pod 3개
  ├── 현재 상태: Pod 1개
  └── 차이: 2개 부족!
  
ReplicaSet Controller → API 서버:
  "nginx Pod 2개를 생성해줘"
```

**6단계: API 서버 → etcd (또 다시)**

```
API 서버 → etcd:
  "새로운 Pod 2개의 정보를 저장"
  (아직 Node는 배정되지 않은 상태)
```

**7단계: Scheduler 감지**

```
Scheduler (watch 중):
  "Node가 배정되지 않은 Pod 2개를 발견!"
  
스케줄링 프로세스:
  ├── 필터링: "어느 Node에 배치 가능한가?"
  │   ├── Node 1: CPU/메모리 충분 ✓
  │   ├── Node 2: CPU/메모리 충분 ✓
  │   └── Node 3: 메모리 부족 ✗
  │
  ├── 점수 매기기:
  │   ├── Node 1: 50점 (이미 nginx Pod 1개 있음)
  │   └── Node 2: 80점 (리소스 여유로움)
  │
  └── 결정:
      ├── Pod 1 → Node 2
      └── Pod 2 → Node 1 (분산 배치)

Scheduler → API 서버:
  "Pod 1은 Node 2에, Pod 2는 Node 1에 배정해줘"
```

**8단계: API 서버 → etcd (마지막)**

```
API 서버 → etcd:
  "Pod 1의 spec.nodeName = node-2"
  "Pod 2의 spec.nodeName = node-1"
```

**9단계: Kubelet 감지 (다음 편에서 자세히)**

```
Node 1의 Kubelet (watch 중):
  "내 Node로 배정된 새 Pod가 있네!"
  → 컨테이너 런타임에 지시해서 실제로 컨테이너 실행
  
Node 2의 Kubelet (watch 중):
  "내 Node로 배정된 새 Pod가 있네!"
  → 컨테이너 런타임에 지시해서 실제로 컨테이너 실행
```

**최종 결과:**

```
[클러스터 상태]
├── Node 1
│   ├── nginx-pod-1 (기존)
│   └── nginx-pod-3 (새로 생성)
└── Node 2
    └── nginx-pod-2 (새로 생성)

→ 원하는 상태(3개) 달성! ✓
```

---

## 컨트롤 플레인의 설계 철학

이렇게 복잡한 과정을 거치는 이유가 뭘까요? 간단히 하면 안 될까요?

### 1. 역할 분리 (Separation of Concerns)

각 컴포넌트는 **한 가지 일만 잘 합니다**:

- API 서버: 검증과 저장
- Scheduler: 배치 결정
- Controller: 상태 유지
- etcd: 데이터 저장

이렇게 분리하면:
- 각 컴포넌트를 독립적으로 개선 가능
- 버그가 발생해도 격리됨
- 테스트가 쉬움

### 2. 선언적 API의 실현

모든 컴포넌트가 "어떻게"가 아닌 "무엇을"에 집중합니다:

```
사용자: "replicas=3이면 좋겠어" (선언)
컨트롤러들: "알겠어, 내가 알아서 만들어줄게" (자동 실행)
```

### 3. 확장성 (Scalability)

Control Plane의 각 컴포넌트는 독립적으로 확장 가능합니다:

```
트래픽이 많아지면:
├── API 서버: 3대 → 5대
├── etcd: 3대 유지
└── Controller Manager: 3대 유지
```

### 4. 복원력 (Resilience)

한 컴포넌트가 죽어도 다른 컴포넌트는 계속 동작합니다:

```
Scheduler 장애 발생
├── 기존 Pod는 정상 동작 ✓
├── 새 Pod 배치만 멈춤 (일시적)
└── Scheduler 재시작되면 자동으로 밀린 작업 처리
```

---

## 정리

오늘 배운 Control Plane의 핵심 요소들:

### 1. **API 서버**: 모든 통신의 중심
- 유일한 소통 창구
- 인증/인가/검증 담당
- etcd와의 유일한 연결점

### 2. **etcd**: 진실의 원천
- 모든 상태 정보 저장
- 분산 합의로 일관성 보장
- 백업이 가장 중요한 컴포넌트

### 3. **Scheduler**: 최적 배치 결정
- Pod를 어느 Node에 배치할지 결정
- 리소스 효율과 고가용성 고려
- 결정만 하고, 실행은 kubelet이 담당

### 4. **Controller Manager**: 상태 유지의 핵심
- 컨트롤 루프의 실제 구현체
- 각 컨트롤러가 특정 리소스 타입만 관리
- 자동 복구, 자동 확장의 실행자

### 5. **Cloud Controller Manager**: 클라우드 연동
- 클라우드 제공자와의 통합
- 로드밸런서, 스토리지 등 자동 관리

### 핵심 동작 원리

```
1. 사용자가 "원하는 상태" 선언
   ↓
2. API 서버가 검증 후 etcd에 저장
   ↓
3. 컨트롤러가 변경 감지 (Watch)
   ↓
4. "현재 상태"와 "원하는 상태" 비교
   ↓
5. 차이를 없애기 위한 조치 실행
   ↓
6. (1번으로 돌아가 무한 반복)
```

---

## 실무에서 알아야 할 팁

### Control Plane 고가용성 (HA) 구성

운영 환경에서는 Control Plane을 단일 장애점(Single Point of Failure)으로 만들면 안 됩니다.

**권장 구성:**

```
[Control Plane HA 구성]
├── API 서버: 3대 이상
│   └── 로드밸런서로 트래픽 분산
│
├── etcd: 3대 또는 5대 (반드시 홀수)
│   └── Raft 합의 알고리즘으로 과반수 동의 필요
│
├── Scheduler: 3대 (Leader Election으로 1대만 활성화)
│   └── 나머지는 대기 상태
│
└── Controller Manager: 3대 (Leader Election)
    └── 나머지는 대기 상태
```

**왜 홀수인가?**

```
etcd 3대 구성:
├── 1대 장애 → 2대 남음 (과반수 OK) ✓
└── 2대 장애 → 1대 남음 (과반수 NO) ✗

etcd 4대 구성:
├── 1대 장애 → 3대 남음 (과반수 OK) ✓
└── 2대 장애 → 2대 남음 (과반수 NO) ✗

→ 3대나 4대나 허용 가능한 장애 대수는 1대로 같음
→ 4대는 비용만 더 들고 이득이 없음!
```

### Control Plane 모니터링 포인트

**1. API 서버**
- 초당 요청 수 (QPS)
- 응답 시간 (Latency)
- 에러율
- etcd 통신 지연

**2. etcd**
- 디스크 I/O 성능 (매우 중요!)
- DB 크기 (2GB 이상이면 경고)
- 합의(Consensus) 지연
- 리더 변경 횟수

**3. Scheduler**
- 스케줄링 대기 중인 Pod 수
- 스케줄링 실패율
- 스케줄링 소요 시간

**4. Controller Manager**
- 각 컨트롤러의 동기화 지연
- 작업 큐 크기
- 재시도 횟수

### 성능 튜닝 팁

**etcd 최적화**

```yaml
# etcd 전용 고성능 디스크 사용
- SSD 필수 (HDD는 절대 안 됨)
- 낮은 지연시간이 중요
- IOPS가 높아야 함

# 별도의 디스크에 etcd 데이터 저장
--data-dir=/dedicated-disk/etcd

# 정기적인 defragmentation
$ etcdctl defrag
```

**API 서버 최적화**

```yaml
# Watch 캐시 크기 조정
--watch-cache-sizes=deployments.apps#100,pods#1000

# etcd 연결 풀 크기
--max-requests-inflight=400
--max-mutating-requests-inflight=200
```

---

## 트러블슈팅: 흔한 문제들

### 문제 1: "Pod가 Pending 상태에서 멈춤"

**증상:**
```bash
$ kubectl get pods
NAME                    READY   STATUS    
nginx-abc123           0/1     Pending
```

**원인 진단:**

```bash
# Pod 상세 정보 확인
$ kubectl describe pod nginx-abc123

Events:
  Warning  FailedScheduling  pod has unbound immediate PersistentVolumeClaims
```

**가능한 원인:**
1. 리소스 부족 (모든 Node의 CPU/메모리가 꽉 참)
2. Node Selector 조건에 맞는 Node 없음
3. Taints/Tolerations 미스매치
4. PersistentVolume 없음

**해결:**
```bash
# 클러스터 리소스 확인
$ kubectl top nodes

# Node에 여유가 없다면 Node 추가 또는 Pod 개수 줄이기
```

### 문제 2: "etcd가 느려서 클러스터 전체가 느림"

**증상:**
- kubectl 명령어가 매우 느림
- Pod 생성/삭제가 지연됨
- API 서버 로그에 "etcdserver: request timed out" 에러

**원인 진단:**

```bash
# etcd 성능 확인
$ etcdctl check perf

# 디스크 I/O 확인
$ iostat -x 1
```

**가능한 원인:**
1. 디스크가 너무 느림 (HDD 사용 중이거나 I/O 병목)
2. etcd DB가 너무 큼 (오래된 이벤트 쌓임)
3. 네트워크 지연

**해결:**
```bash
# 1. etcd compaction 실행
$ etcdctl compact $(etcdctl endpoint status --write-out="json" | jq -r '.[0].Status.header.revision')

# 2. defragmentation
$ etcdctl defrag

# 3. etcd 백업 후 오래된 이벤트 제거
$ kubectl delete events --all-namespaces --field-selector=...
```

### 문제 3: "Controller Manager가 동작하지 않음"

**증상:**
- Pod가 죽어도 자동으로 재생성되지 않음
- Deployment 변경이 적용되지 않음

**원인 진단:**

```bash
# Controller Manager 로그 확인
$ kubectl logs -n kube-system kube-controller-manager-master1

# Leader election 상태 확인
$ kubectl get lease -n kube-system kube-controller-manager
```

**가능한 원인:**
1. Controller Manager가 Leader를 획득하지 못함
2. API 서버와 통신 불가
3. 권한 문제 (RBAC)

---

## FAQ: 자주 묻는 질문

### Q1: "Control Plane Node에도 애플리케이션 Pod를 실행할 수 있나요?"

**답변:** 기술적으로는 가능하지만, **운영 환경에서는 절대 권장하지 않습니다.**

이유:
- Control Plane이 과부하되면 전체 클러스터가 멈출 수 있음
- 보안상 Control Plane은 격리하는 것이 좋음

기본적으로 Control Plane Node에는 Taint가 설정되어 있어 일반 Pod가 배치되지 않습니다:

```bash
$ kubectl describe node master1
Taints: node-role.kubernetes.io/control-plane:NoSchedule
```

### Q2: "API 서버를 여러 대 실행하면 데이터 불일치가 생기지 않나요?"

**답변:** 아니요. API 서버는 **Stateless**합니다.

모든 API 서버는:
- 같은 etcd를 바라봄
- etcd가 유일한 진실의 원천
- API 서버 간에는 동기화할 상태가 없음

따라서 여러 대의 API 서버가 동시에 동작해도 문제없습니다.

### Q3: "Scheduler와 Controller Manager는 왜 여러 대인데 1대만 활성화되나요?"

**답변:** **Leader Election** 때문입니다.

이 컴포넌트들은 Stateful하므로 여러 대가 동시에 동작하면 문제가 생깁니다:

```
잘못된 경우:
├── Scheduler A: "Pod를 Node 1에 배치!"
└── Scheduler B: "같은 Pod를 Node 2에 배치!"
    → 충돌!
```

그래서:
- 3대를 실행하지만 1대만 Leader로 활성화
- Leader가 죽으면 나머지 중 하나가 자동으로 Leader가 됨
- 고가용성은 확보하되 충돌은 방지

### Q4: "etcd 없이 쿠버네티스를 사용할 수 있나요?"

**답변:** 이론적으로는 가능하지만 사실상 불가능합니다.

etcd는 쿠버네티스 아키텍처의 핵심입니다. 대안:
- **K3s**: 경량 쿠버네티스로 etcd 대신 SQLite 사용 가능
- **Managed 서비스**: EKS, GKE 등은 etcd를 내부적으로 관리해줌

일반적인 쿠버네티스에서는 etcd가 필수입니다.

---

## 다음 단계를 위한 준비

지금까지 Control Plane의 "뇌"가 어떻게 생각하고 결정하는지 배웠습니다. 하지만 아직 한 가지가 남았습니다:

> **"그래서 실제로 컨테이너는 누가 실행하나요?"**

Control Plane은 "무엇을 해야 하는지" 결정만 합니다. 실제로 컨테이너를 실행하는 것은 **Worker Node의 컴포넌트들**입니다.

다음 아티클에서는:
- **kubelet**: Control Plane의 명령을 받아 실제로 Pod를 실행하는 "현장 관리자"
- **Container Runtime**: Docker, containerd 등 실제 컨테이너를 실행하는 엔진
- **kube-proxy**: 네트워크 트래픽을 Pod로 전달하는 "교통 경찰"

이 세 가지 컴포넌트가 어떻게 협력해서 우리가 선언한 Pod를 실제 컨테이너로 만들어내는지 알아보겠습니다.

---

### 다음 아티클

### 다음 아티클

- [워커 노드 분석: 근육은 어떻게 움직이는가?](./04_워커노드_분석_근육은_어떻게_움직이는가.md)

---

**작성일**: 2025-10-30
