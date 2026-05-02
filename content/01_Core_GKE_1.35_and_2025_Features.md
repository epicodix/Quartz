---
title: "GKE 1.35 및 2025년 최신 기능 분석: AI 인프라의 새로운 기준"
creation_date: 2026-04-23
date: 2026-04-23
tags: [GKE, Kubernetes, AI-Infrastructure, Autopilot, Cloud-Native]
aliases: [GKE-1.35-Features, GKE-vs-EKS-2025]
category: Cloud/GCP
status: 완성
priority: 높음
model: gemini-3.0-pro preview
summary: GKE 1.35의 핵심 업데이트와 AI/ML 워크로드 최적화 기능, 그리고 2025년 시점에서의 GKE vs EKS 비교 분석을 다룹니다.
---

# [Tech Deep Dive] GKE 1.35: AI 시대를 위한 쿠버네티스의 진화와 2025년의 선택

2025년과 2026년 초를 기점으로 GKE(Google Kubernetes Engine)는 단순한 컨테이너 오케스트레이션을 넘어 **'AI 슈퍼컴퓨팅 플랫폼'**으로 완전히 탈바꿈했습니다. 특히 최신 버전인 **GKE 1.35**와 **Autopilot**의 진화는 인프라 관리의 복잡성을 제거하고 AI 워크로드 최적화에 집중하고 있습니다.

---

## 1. GKE 1.35: "제어권은 정교하게, 성능은 극단으로"

GKE 1.35 버전은 관리형 서비스의 편의성과 엔터프라이즈가 요구하는 세밀한 제어권 사이의 균형을 맞추는 데 집중했습니다.

*   **Autopilot 특권 워크로드 제어 (Privileged Workloads):** 그동안 Autopilot은 보안을 위해 특권(Privileged) 컨테이너 실행을 엄격히 제한했습니다. 1.35 버전부터는 관리자가 허용 목록(Allowlist)을 통해 특정 파트너 솔루션이나 커스텀 워크로드에 대해 정교하게 권한을 부여할 수 있게 되었습니다.
*   **Slurm Operator (Preview):** 전통적인 HPC(고성능 컴퓨팅) 스케줄러인 Slurm을 GKE에서 직접 사용할 수 있는 애드온이 추가되었습니다. 이는 AI 학습과 같은 대규모 배치 작업을 쿠버네티스 네이티브 환경에서 더 효율적으로 관리할 수 있게 합니다.
*   **Gateway API v1.5 & DRANET GA:** 고성능 네트워킹을 위한 DRA(Dynamic Resource Allocation) API가 GA(General Availability)로 전환되었습니다. 특히 NVIDIA A3 Ultra, A4 시리즈 등 최신 GPU 인스턴스에 최적화된 네트워킹을 제공합니다.
*   **OCI 이미지 볼륨 마운트:** (K8s 1.35 공통) ML 모델이나 설정 파일을 별도의 Init 컨테이너 없이 OCI 이미지 형태로 직접 읽기 전용 볼륨으로 마운트할 수 있어, 대용량 모델 배포 속도가 획기적으로 개선되었습니다.

## 2. 2025년 GKE Autopilot의 대변혁: "Standard와의 경계 붕괴"

2025년 GKE의 가장 큰 전략적 변화는 **"Autopilot for Everyone"**입니다.

*   **Compute Classes in Standard:** 이제 Standard 모드 클러스터에서도 특정 워크로드에 대해 Autopilot의 관리형 컴퓨팅(Compute Class)을 선택적으로 적용할 수 있습니다. 즉, 클러스터 전체를 Autopilot으로 전환하지 않고도 필요한 부분만 '서버리스'처럼 운영할 수 있습니다.
*   **GKE Agent Sandbox:** gVisor 기반의 보안 격리 기술을 통해, LLM이 생성한 코드를 실행하거나 외부 에이전트가 활동하는 환경을 안전하게 격리합니다. 콜드 스타트 성능이 기존 대비 최대 90% 개선되어 실시간 AI 에이전트 서비스에 최적화되었습니다.
*   **Axion(N4A) 지원:** Google이 자체 설계한 Arm 기반 프로세서 Axion을 Autopilot에서 즉시 사용할 수 있어, 성능 대비 비용 효율성을 극대화했습니다.

## 3. AI/ML 워크로드 최적화: Inference Gateway와 Cluster Director

GKE는 이제 단순한 컨테이너 실행기가 아닌 **AI 추론 및 학습 전용 플랫폼**으로 진화했습니다.

*   **Inference Gateway (GA):** LLM 추론 시 '문맥 캐시(Context Caching)'를 인식하여 동일한 요청을 최적의 가속기로 라우팅합니다. 이를 통해 꼬리 지연 시간(Tail Latency)을 최대 60%까지 줄일 수 있습니다.
*   **Cluster Director:** 최대 **13만 노드** 규모의 거대 클러스터를 단일 단위로 관리할 수 있는 기능을 제공합니다. 이는 수만 개의 GPU/TPU를 동원하는 초대형 모델 학습을 위한 핵심 기술입니다.

## 4. GKE vs EKS 2025: 무엇을 선택해야 하는가?

2025년 시점에서의 두 플랫폼 비교는 더 이상 '기능 유무'가 아닌 **'운영 철학'**의 차이로 좁혀졌습니다.

| 비교 항목 | Google GKE (2025) | AWS EKS (2025) |
| :--- | :--- | :--- |
| **제어 평면 비용** | 1개 존 클러스터 무료 (비용 절감 우위) | 시간당 $0.10 (약 $73/월) 고정 발생 |
| **AI/ML 최적화** | TPU/GPU 통합, Inference Gateway 등 압도적 | Karpenter 기반의 유연한 노드 스케일링 강점 |
| **운영 편의성** | Autopilot을 통한 완전 자동화 (최상) | EKS Auto 모드 출시로 추격 중이나 설정 복잡도 존재 |
| **업데이트 속도** | 업스트림 출시 후 수주 내 적용 (가장 빠름) | 안정성 중심의 보수적 업데이트 주기 |
| **추천 대상** | AI/ML 네이티브 기업, 운영 인력 최소화 지향 | 기존 AWS 에코시스템(S3, RDS 등) 의존도가 높은 기업 |

---

### 💡 결론: 2025년의 GKE는 '지능형 인프라'입니다.

GKE 1.35와 최신 기능들은 인프라 엔지니어가 "노드 패칭"이나 "오토스케일링 튜닝"에 쏟는 시간을 줄이고, "AI 모델 배포 전략"과 "비용 최적화"에 집중할 수 있게 해줍니다. 특히 **Inference Gateway**와 **Agent Sandbox**의 등장은 GKE가 단순한 인프라를 넘어 AI 애플리케이션의 런타임으로서 독보적인 위치에 있음을 증명합니다.

<br>
<div align="right" style="font-size: 0.8em; color: gray; opacity: 0.6;">
  Supported by gemini-3.0-pro preview
</div>