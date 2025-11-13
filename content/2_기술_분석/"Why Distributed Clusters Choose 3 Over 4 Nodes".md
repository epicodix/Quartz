---
creation_date: 2025-11-12
---
# 분산 합의 알고리즘과 Quorum: 클러스터 홀수 구성의 기술적 필연성

## Abstract

현대 분산 시스템에서 etcd, Consul, ZooKeeper 등의 합의 기반 저장소는 3, 5, 7개의 홀수 노드 구성을 권장한다. 본 문서는 Raft 합의 알고리즘을 중심으로 Quorum 메커니즘의 수학적 원리를 분석하고, 노드 수에 따른 장애 허용도(Fault Tolerance)와 비용 효율성을 정량적으로 평가하여 홀수 구성이 최적 선택인 이유를 논증한다.

## 1. Background: Distributed Consensus Problem

### 1.1 CAP 정리와 일관성 모델

분산 시스템은 CAP 정리(Consistency, Availability, Partition Tolerance)에 따라 네트워크 분할(Partition) 상황에서 일관성과 가용성 중 하나를 선택해야 한다. etcd와 같은 CP 시스템은 **Strong Consistency**를 보장하기 위해 합의 알고리즘을 사용한다.

### 1.2 Split-Brain 문제의 형식화

N개 노드로 구성된 클러스터 C = {n₁, n₂, ..., nₙ}가 네트워크 분할로 인해 두 개의 부분 집합 S₁, S₂로 분리되었을 때:

```
C = S₁ ∪ S₂, where S₁ ∩ S₂ = ∅
```

만약 |S₁| = |S₂| = N/2 (짝수 노드의 경우) 상황에서 각 파티션이 독립적으로 Leader를 선출하면:

- **시간 t**: Leader(S₁) = n₁, Leader(S₂) = n₂
- **쓰기 연산**: Write(key, value_A) → S₁, Write(key, value_B) → S₂
- **결과**: 네트워크 복구 후 key에 대한 값이 value_A와 value_B로 불일치 발생

이는 **Linearizability 위반**이며, 분산 트랜잭션의 ACID 속성 중 Consistency를 파괴한다.

## 2. Raft Consensus Algorithm과 Quorum

### 2.1 Raft의 핵심 구성 요소

Raft는 Replicated State Machine을 구현하기 위한 합의 알고리즘으로, 다음 세 가지 하위 프로토콜로 구성된다:

1. **Leader Election**: Follower → Candidate → Leader 전환 메커니즘
2. **Log Replication**: Leader가 모든 Follower에게 로그 엔트리 복제
3. **Safety**: 커밋된 엔트리의 영속성 보장

### 2.2 Quorum의 수학적 정의

> **Definition**: 전체 노드 수 N에 대한 Quorum Q는 다음과 같이 정의된다:
> 
> ```
> Q = ⌊N/2⌋ + 1
> ```

이 정의의 핵심 속성은 **Quorum Intersection Property**이다:

> **Theorem** (Quorum Intersection): 임의의 두 Quorum Q₁, Q₂에 대해
> 
> ```
> |Q₁ ∩ Q₂| ≥ 1
> ```
> 
> **증명**:
> 
> - Q₁과 Q₂가 각각 최소 ⌊N/2⌋ + 1개의 노드를 포함
> - 전체 노드 수가 N이므로
> - |Q₁| + |Q₂| ≥ 2(⌊N/2⌋ + 1) > N
> - 따라서 Q₁과 Q₂는 최소 1개 이상의 공통 노드를 가져야 함 (비둘기집 원리)

### 2.3 Raft에서의 Quorum 적용

#### Leader Election (Term-based Voting)

```
RequestVote RPC:
- Candidate는 모든 노드에게 투표 요청
- 각 노드는 term당 1번만 투표
- Candidate가 Quorum 이상의 투표를 받으면 Leader로 전환

조건: votes_received ≥ ⌊N/2⌋ + 1
```

**중요**: Quorum Intersection에 의해 동일한 term에서 두 개의 Leader가 동시에 선출되는 것은 수학적으로 불가능하다.

#### Log Replication (Majority Commit)

```
AppendEntries RPC:
- Leader가 로그 엔트리를 Follower에게 전송
- Follower가 로그를 디스크에 기록하고 ACK 응답
- Leader는 Quorum 이상의 ACK를 받으면 해당 엔트리를 Committed로 표시

조건: ack_count ≥ ⌊N/2⌋ + 1
```

Committed 엔트리는 모든 미래의 Leader에서도 보존됨이 보장된다(Safety Property).

## 3. 노드 수별 정량적 분석

### 3.1 Fault Tolerance 계산

전체 노드 N, Quorum Q에 대해 허용 가능한 최대 장애 노드 수 F는:

```
F = N - Q = N - (⌊N/2⌋ + 1) = ⌊(N-1)/2⌋
```

### 3.2 노드 구성별 특성 비교

|N|Q|F|Q/N|F/N|분석|
|---|---|---|---|---|---|
|1|1|0|1.00|0.00|SPOF, 프로덕션 부적합|
|2|2|0|1.00|0.00|Split-brain 취약, 장애 허용 없음|
|**3**|**2**|**1**|**0.67**|**0.33**|**최소 HA 구성, 비용 효율 최적**|
|4|3|1|0.75|0.25|3-node와 동일한 F, 25% 비용 증가|
|**5**|**3**|**2**|**0.60**|**0.40**|**고가용성 구성, F=2 달성**|
|6|4|2|0.67|0.33|5-node와 동일한 F, 20% 비용 증가|
|**7**|**4**|**3**|**0.57**|**0.43**|**엔터프라이즈급, 3중 장애 허용**|

### 3.3 성능 및 비용 효율성 지표

**Marginal Fault Tolerance Gain (MFTG)**:

```
MFTG(N) = [F(N) - F(N-1)] / [Cost(N) - Cost(N-1)]
```

노드 추가 시 단위 비용당 장애 허용도 증가량:

- N: 3→4, MFTG = (1-1)/1 = **0** (비효율)
- N: 4→5, MFTG = (2-1)/1 = **1** (효율적)
- N: 5→6, MFTG = (2-2)/1 = **0** (비효율)
- N: 6→7, MFTG = (3-2)/1 = **1** (효율적)

**결론**: 홀수 구성이 항상 최적의 MFTG를 제공한다.

## 4. 실전 환경별 권장 구성

### 4.1 워크로드 특성에 따른 선택

**3-node (etcd 기본 권장)**

```
Use case:
- 중소규모 Kubernetes 클러스터 (< 1000 nodes)
- RTO < 30s, RPO = 0 요구사항
- 예산 제약이 있는 환경

Performance:
- Write latency: ~5ms (LAN 환경)
- Throughput: ~10k writes/sec
- Recovery time: ~election timeout (150-300ms)
```

**5-node (엔터프라이즈 표준)**

```
Use case:
- 대규모 Kubernetes 클러스터 (> 1000 nodes)
- 멀티 데이터센터 배포
- 연간 2회 이상의 노드 유지보수 필요

Benefits:
- Rolling upgrade 중에도 F=1 유지
- 1개 노드 유지보수 + 1개 예상치 못한 장애 동시 허용
```

**7-node (초고가용성 요구 환경)**

```
Use case:
- 금융/의료 등 규제 산업
- 99.999% (연간 5분 이하 다운타임) SLA 요구
- Multi-region 지리적 분산

Consideration:
- Write latency 증가 (복제 오버헤드)
- 네트워크 대역폭 소비 증가
- 합의 달성 시간 증가 가능
```

### 4.2 네트워크 레이턴시와 Quorum 크기

**Raft Performance Model**:

```
Commit_Latency ≈ RTT × ⌈log₂(Q)⌉ + Disk_Write_Time

Example (3-node):
- LAN (RTT=1ms): ~6ms
- WAN (RTT=50ms): ~100ms

Example (7-node, cross-region):
- RTT=100ms: ~300ms+
```

따라서 지리적으로 분산된 클러스터에서는 노드 수 증가가 성능에 미치는 영향을 면밀히 분석해야 한다.

## 5. 실무 구현 고려사항

### 5.1 etcd 클러스터 구성 모범 사례

```yaml
# Recommended 3-node etcd configuration
etcd-1:
  name: etcd-1
  initial-cluster: etcd-1=https://10.0.1.10:2380,etcd-2=https://10.0.1.11:2380,etcd-3=https://10.0.1.12:2380
  initial-cluster-state: new
  initial-cluster-token: etcd-cluster-prod
  
  # Performance tuning
  heartbeat-interval: 100    # Leader heartbeat (ms)
  election-timeout: 1000     # Follower → Candidate (ms)
  
  # Disk I/O
  quota-backend-bytes: 8589934592  # 8GB
  auto-compaction-mode: periodic
  auto-compaction-retention: "1h"
```

### 5.2 Failure Scenario 시뮬레이션

**Scenario 1: Single Node Failure (3-node)**

```
t=0: [Leader A] [Follower B] [Follower C] - Normal
t=1: [Leader A] [Follower B] [DOWN]       - C 장애
t=2: [Leader A] [Follower B] ✓            - Quorum 유지 (2/3)
     Write operations continue normally
```

**Scenario 2: Network Partition (3-node)**

```
t=0: [Leader A] [Follower B] [Follower C]
t=1: [Leader A] | [Follower B] [Follower C]  (네트워크 분할)
t=2: [Read-only] | [New Leader B] [Follower C] ✓
     Majority partition (B, C) elects new leader
     Minority (A) becomes read-only
```

### 5.3 모니터링 메트릭

```prometheus
# Critical etcd metrics
etcd_server_has_leader                    # 0 or 1
etcd_server_leader_changes_seen_total     # Leader 변경 횟수
etcd_network_peer_round_trip_time_seconds # Peer 간 RTT
etcd_disk_wal_fsync_duration_seconds      # Write-Ahead Log fsync 시간

# Quorum health
up{job="etcd"} == 1                       # 정상 노드 수
count(up{job="etcd"} == 1) >= 2           # Quorum 체크 (3-node 기준)
```

## 6. Conclusion

홀수 노드 구성은 Quorum 기반 합의 알고리즘의 수학적 특성에서 비롯된 필연적 선택이다:

1. **수학적 필연성**: Quorum Intersection Property에 의한 Split-brain 방지
2. **비용 효율성**: 짝수 구성 대비 동일한 장애 허용도를 낮은 비용으로 달성
3. **성능 최적화**: 최소 Quorum 크기 유지로 합의 레이턴시 최소화

**실무 권장사항**:

- 개발/테스트: 단일 노드 (minikube, kind)
- 프로덕션 기본: **3-node** (비용 대비 효율 최적)
- 엔터프라이즈: **5-node** (운영 유연성 확보)
- 미션 크리티컬: **7-node** (최대 가용성)

분산 시스템 설계 시 노드 수는 단순한 스케일링 문제가 아닌, Fault Tolerance, Performance, Cost 간의 트레이드오프를 고려한 **정량적 의사결정**이 되어야 한다.

## References

1. Ongaro, D., & Ousterhout, J. (2014). In Search of an Understandable Consensus Algorithm (Extended Version). USENIX ATC.
2. Kubernetes Documentation: Operating etcd clusters for Kubernetes
3. etcd Performance Benchmarks: https://etcd.io/docs/latest/op-guide/performance/
4. 3GPP TS 23.501: System architecture for 5G (NTN integration)