---
title: Istio Ambient Mesh + EKS 1.35 업데이트 노트
tags:
  - istio
  - ambient-mesh
  - eks
  - kubernetes-1-35
  - timedeal
  - devops
  - infrastructure
aliases:
  - Ambient Mesh 노트
  - EKS 1.35 노트
  - phase3 v4 근거
date: 2026-04-27
category: K8s_Deep_Dive
status: 완성
priority: 높음
---

# Istio Ambient Mesh + EKS 1.35 업데이트 노트

> 타임딜 백엔드 EKS 마이그레이션의 phase3 도식 v4 작업 근거 자료. 2026-04-27 기준 최신 정보 정리.

## 핵심 요약

- **Istio Ambient Mode**가 1.24(2024-11) GA 이후 1.5년간 검증되어 2026 현재는 **"sidecar 대체 default"** 위치.
- **EKS 1.35 (Timbernetes)** 가 2026-01-28 출시. **In-Place Pod Resize (GA)** 가 hero feature.
- 타임딜처럼 **빠른 스파이크 + Stateless** 도메인엔 둘 다 거의 정답에 가깝게 맞물림.

---

## 1. Istio Ambient Mesh

### 아키텍처 변화

```
[기존 Sidecar Mode]
  Pod ─[Envoy sidecar]─ ↔ ─[Envoy sidecar]─ Pod
       (Pod마다 Envoy 1개)

[Ambient Mode]
  Pod ─ Pod IP ─ ┬─ ztunnel (노드 daemon, L4 mTLS) ─ HBONE 터널 ─ ztunnel ─ Pod
                 │
                 └─ L7 필요 시 ─ waypoint proxy (네임스페이스/서비스 단위 deployment)
```

### 컴포넌트

| 컴포넌트 | 위치 | 역할 | 구현 |
|---------|------|------|------|
| **ztunnel** | 노드별 DaemonSet | L3/L4: mTLS, AuthN/AuthZ L4, telemetry | Rust |
| **waypoint proxy** | 네임스페이스/서비스 단위 Deployment, **선택적** | L7: 라우팅, 정책, resilience | Envoy |
| **HBONE** | ztunnel ↔ ztunnel 간 | 암호화 터널 프로토콜 | HTTP/2 CONNECT 기반 |

### Sidecar vs Ambient 트레이드오프

| 축 | Sidecar | Ambient |
|----|---------|---------|
| Pod 부팅 시간 | Envoy 사이드카 부팅 대기 (수 초) | 즉시 (앱 컨테이너만) |
| Pod당 메모리 | ~50~150MB (Envoy) | ~0 |
| 노드당 메모리 | 작음 (Pod별 분산) | ztunnel 1개 (공유, ~30MB) |
| L7 정책 적용 | 어디든 | waypoint 배포된 곳만 |
| 검증 기간 | 8년+ | 1.5년 (1.24 GA부터) |
| AI/ML 워크로드 적합도 | sidecar 오버헤드 큼 | 매우 유리 |
| 운영 복잡도 | 단일 패턴 | ztunnel + waypoint 2중 |

### 성능 데이터 (2026 기준)

> [!info] 핵심 수치
> - sidecar 대비 메모리 **70%+ 절감**
> - ztunnel 자체 성능 **75% 향상** (1.24 → 1.27 4 릴리즈 동안)
> - Multi-cluster Beta (KubeCon EU 2026 발표)

### 타임딜 적용 가치

| 타임딜 특성 | Ambient의 가치 |
|----------|--------------|
| Karpenter Spot으로 빠른 노드/Pod 증설 | sidecar 부팅 대기 제거 → **Pod ready 시간 단축** |
| 결제 스파이크 시 Pod 100개+ 동시 띄우기 | sidecar 100개 메모리 절감 = **GB 단위 절감** |
| 서비스 간 통신은 mTLS gRPC가 거의 전부 | **ztunnel만으로 충분**, waypoint 거의 불필요 |
| L7 라우팅(Canary 등)은 ArgoCD Rollouts가 처리 | Istio L7은 **선택적**으로만 |

> [!tip] 면접 답변 차별점
> "Sidecar/Ambient 둘 다 검토 후, 타임딜은 부팅 시간 + 메모리 절감 효과가 결정적이라 Ambient 채택. 단 L7 정책이 거의 없는 도메인이라 ztunnel만 활용하고 waypoint는 도입하지 않음."

### 도입 전제 조건

- Istio 1.24+ (ambient profile)
- Kubernetes 1.27+ (1.35는 당연 OK)
- CNI: Cilium / Calico 등과 호환 (eBPF 호환 필수)
- AWS EKS Console에서 Ambient 호환 버전 직접 배포 가능

---

## 2. EKS 1.35 / Kubernetes 1.35 "Timbernetes"

### 출시 정보

| 항목 | 값 |
|------|-----|
| K8s 1.35 GA | 2025-12 |
| **EKS 1.35 출시** | **2026-01-28** |
| 코드네임 | "Timbernetes" (The World Tree) |
| 향상 | 60 enhancement / 22 alpha / 19 beta / 17 GA |
| 후속 | K8s 1.36 "Haru" (2026-04-22) |

### 주요 신기능

#### 1. In-Place Pod Resize (GA) — 가장 임팩트 큼

> [!example] 실제 시나리오
> - **기존**: Pod CPU 부족 → Pod 재시작하며 새 spec으로 띄우거나, 새 Pod replicas 추가
> - **1.35**: `kubectl patch` 또는 VPA로 **재시작 없이** CPU/Memory 조정
> - **타임딜 활용**: 결제 트래픽 폭증 시 새 Pod 띄우기 전에 **기존 Pod 자원부터 키워서 즉시 흡수**

```yaml
# Pod 재시작 없이 변경 가능한 resource
spec:
  containers:
  - resources:
      requests: { cpu: 500m, memory: 512Mi }    # 동적 조정 OK
      limits:   { cpu: 2000m, memory: 2Gi }     # 동적 조정 OK
```

#### 2. HPA Configurable Tolerance (Beta)

```yaml
# per-resource tolerance window
behavior:
  scaleUp:
    policies: [...]
    tolerance: 0.05    # CPU 5% 마진
  scaleDown:
    tolerance: 0.10    # 10% 마진
```

타임딜 의의: **결제 Pod는 민감(5%)**, **상품 조회 Pod는 둔감(15%)** 같은 차등 운용 가능.

#### 3. PreferSameNode Traffic Distribution (GA)

```yaml
spec:
  trafficDistribution: PreferSameNode  # 같은 노드 endpoint 우선
```

- 노드 간 네트워크 hop 감소 → **레이턴시 미세 개선**
- AZ 분산 자체가 깨지진 않음 (fallback 보장)
- gRPC mTLS 환경에서 의외로 큰 효과

#### 4. Gang Scheduling (Alpha)

- 관련 Pod 그룹을 "전부 또는 아무것도" 스케줄
- AI/ML 학습 잡에서 핵심
- 타임딜 백엔드와는 거리 있음

#### 5. Authentication Configuration (GA)

- API server 인증을 config file로 (CLI flag 대신)

### 주요 Deprecation — 마이그레이션 영향 큼

> [!warning] 즉시 영향
> | 항목 | 영향 | 액션 |
> |------|------|------|
> | **containerd 1.x** | 1.35가 마지막 지원 | **1.36 가기 전 containerd 2.0+ 마이그레이션 필수** |
> | **IPVS proxy mode** | kube-proxy 변경 | nftables로 전환 (EKS 관리 영역, 자동 가능성) |
> | **cgroups v1** | 노드 OS 영향 | cgroups v2 강제 (대부분 최신 OS는 OK) |
> | **Ingress NGINX** | 2026-03부터 best-effort 유지보수 | Gateway API 또는 다른 ingress 권장 |
> | gogo protobuf | API 라이브러리 교체 | 라이브러리 사용자만 영향 |

### 타임딜 프로젝트 직접 영향 매핑

| 항목 | 타임딜 영향 | 액션 |
|------|-----------|------|
| In-Place Pod Resize | 매우 큼 | KEDA/HPA + VPA 조합 재설계 검토 |
| HPA Configurable Tolerance | 큼 | 결제 Pod와 일반 Pod 차등 tolerance |
| PreferSameNode | 중간 | gRPC mTLS 호출 레이턴시 개선 |
| containerd 2.0 | 즉시 | Karpenter EC2NodeClass에 Bottlerocket 1.20+ 또는 AL2023 latest 명시 |
| IPVS → nftables | 낮음 | EKS 관리 영역 |
| Ingress NGINX | 영향 없음 | phase3_eks 도식은 ALB + LBC 사용 |

---

## 3. phase3_eks 도식 v4 변경 사항

v3에서 다음을 반영:

### 변경 항목

| 영역 | v3 (현재) | v4 (1.35 + Ambient) |
|------|----------|--------------------|
| K8s 버전 | 1.31 | **1.35 (Timbernetes)** |
| 메시 | Istio sidecar mTLS STRICT | **Istio Ambient (ztunnel + 선택적 waypoint)** |
| Pod 메시 표시 | "Envoy sidecar" 칩 | **제거** (또는 "ztunnel(node)" 표시) |
| 스케일링 | HPA + KEDA | HPA + KEDA + **In-Place Pod Resize** |
| HPA tolerance | 단일 값 | **per-resource tolerance** |
| 노드 OS | (미명시) | **Bottlerocket 1.20+ / containerd 2.0** |
| Service trafficDistribution | (미적용) | **PreferSameNode** 명시 |

### 추가 박스 (v4에서 신설)

- **"1.35 신기능 활용" 박스** — In-Place Pod Resize, HPA Tolerance, PreferSameNode 3가지 묶어서
- **"Ambient Mode 효과" 박스** — 메모리 70% 절감, Pod 부팅시간 단축

---

## 4. 다음 액션 (선택)

### eks-skeleton 업그레이드 (필요 시)

`docs/eks-skeleton/terraform/modules/eks/main.tf`의 `kubernetes_version = "1.31"` → `"1.35"` 변경.

> [!note] 주의
> eks-skeleton은 reference/eks-skeleton-epicodix 브랜치에 이미 push됨. 업그레이드한다면:
> 1. 새 commit으로 1.35 적용 (호환 검증 포함)
> 2. INSTALL.md의 단계도 1.35 호환 명령으로 업데이트
> 3. 또는 PR description 코멘트로 "1.35 권장" 추가만

### Ambient 적용 가이드 보완

- Helm 값 차이: `istioctl install --set profile=ambient`
- ztunnel 설치: `kubectl apply -f manifests/charts/ztunnel/`
- waypoint 옵션: 정책 필요 namespace에만 `kubectl apply -f waypoint.yaml`

### 도식 시리즈 정리

eks_concepts/ 폴더에 다음 도식 추가 검토:

- `ambient_vs_sidecar.html` — 트레이드오프 도식 (ansible/velero/autoscaler 시리즈와 같은 포맷)
- `inplace_pod_resize.html` — 1.35 hero feature 단독 설명

---

## References

### Istio Ambient
- [Istio / Overview — Ambient Mode](https://istio.io/latest/docs/ambient/overview/)
- [Istio / Ambient Reaches GA in v1.24](https://istio.io/latest/blog/2024/ambient-reaches-ga/)
- [Istio / Sidecar or ambient?](https://istio.io/latest/docs/overview/dataplane-modes/)
- [Solo.io — Traffic in ambient mesh: Ztunnel, eBPF, waypoint](https://www.solo.io/blog/traffic-ambient-mesh-ztunnel-ebpf-waypoint)
- [imesh.ai — Implement Istio Ambient Mesh on EKS in 5 Steps](https://imesh.ai/blog/istio-ambient-install-eks/)

### EKS 1.35 / K8s 1.35
- [AWS What's New — Amazon EKS supports Kubernetes 1.35](https://aws.amazon.com/about-aws/whats-new/2026/01/amazon-eks-distro-kubernetes-version-1-35/)
- [InfoQ — Kubernetes 1.35 In-Place Pod Resize and AI Scheduling](https://www.infoq.com/news/2025/12/kubernetes-1-35/)
- [Sysdig — Kubernetes 1.35 New Security Features](https://www.sysdig.com/blog/kubernetes-1-35-whats-new)
- [Aicademy — Kubernetes 1.35 Features Upgrade Guide](https://blog.aicademy.ac/kubernetes-1-35-features-upgrade-guide)
- [Marcin Cuber — EKS Upgrade Journey 1.34 → 1.35](https://marcincuber.medium.com/amazon-eks-upgrade-journey-from-1-34-to-1-35-timbernetes-the-world-tree-release-61a9475aec86)
