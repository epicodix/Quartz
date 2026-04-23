---
title: 학습 계획 — 클라우드 인프라 엔지니어 (AI 서빙 인프라 저변 확대)
tags:
  - 학습계획
  - EKS
  - CKA
  - AI서빙
  - MLOps
  - Karpenter
  - ArgoCD
date: 2026-04-18
category: 99_임시
status: 진행중
priority: 높음
---

# 학습 계획 — 클라우드 인프라 엔지니어

> [!note] 포지셔닝 목표
> **좁게**: "클라우드 인프라 엔지니어, AI 서빙 인프라 이해 있음"
> EKS + Karpenter + ArgoCD 메인 → AI 서빙 인프라는 부가 강점으로

---

## 현재 상태 (2026-04-18 기준)

| 항목 | 상태 |
|------|------|
| Phase 1 EC2 모놀리스 | 완료 |
| Phase 2 ECS Fargate MSA | 완료 |
| Operation Strix (EKS 설계 연구) | 완료 |
| kubeadm 로컬 클러스터 | 완료 |
| Prometheus + Grafana 설치 실습 | 완료 |
| Phase 3 EKS 실제 구현 | 다음 주 착수 |
| CKA | 준비 중 |
| AWS SAA | 준비 중 |

---

## 1. Phase 3 EKS — 최우선 (4~6주)

> [!tip] 핵심 원칙
> Operation Strix에서 설계한 것들을 실제로 구현하고 결과를 문서화.
> "설계 연구"를 "직접 구현 완료"로 바꾸는 것이 목표.

### 구현 체크리스트

- [ ] Terraform으로 EKS 클러스터 프로비저닝 (modules/eks 실제 적용)
- [ ] Karpenter 설치 및 NodePool 설정 (On-Demand 20% / Spot 80%)
- [ ] Spot Interruption SQS + EventBridge 연동 실제 동작 확인
- [ ] Pause Pod (Over-provisioning) 패턴 실제 배포 및 검증
- [ ] ArgoCD App of Apps 실제 구현 (kubectl 접근 차단 확인)
- [ ] IRSA 실제 설정 (Karpenter Service Account 단위 권한)
- [ ] Prometheus + Grafana on EKS 배포 (kube-state-metrics, node-exporter)
- [ ] GitHub Actions terraform-pr.yml 실제 PR 코멘트 동작 확인
- [ ] Day 2 Ops 시나리오 A/B/C 실제 재현 및 결과 기록

### 문서화 목표

각 구현마다 "설계 의도 → 실제 결과 → 발생한 문제 → 해결" 패턴으로 기록.
Operation Strix docs/ 챕터들을 "설계"에서 "구현 완료"로 업데이트.

---

## 2. 자격증 — Phase 3와 병행

### CKA (최우선)

- EKS Phase 3 실습이 CKA 준비와 직결됨
- 실습하면서 약한 영역 파악 후 집중 보완

| 도메인 | 비중 | 현재 수준 |
|--------|------|-----------|
| Cluster Architecture, Installation & Configuration | 25% | 보통 |
| Workloads & Scheduling | 15% | 양호 |
| Services & Networking | 20% | 보통 |
| Storage | 10% | 약함 |
| Troubleshooting | 30% | 보통 |

> [!warning] Storage 취약
> PV/PVC/StorageClass 개념 실습 추가 필요. EKS에서 EBS CSI Driver 실습으로 병행.

### AWS SAA

- CKA 이후 집중
- 타임딜 Phase 1/2 구축 경험이 상당 부분 커버
- 약한 영역: Lambda, DynamoDB, S3 고급 기능

---

## 3. AI 서빙 인프라 저변 확대 — Phase 3 이후

> [!note] 타이밍
> Phase 3 완료 + CKA 취득 이후. 지금 손 대면 분산됨.

### 3-1. K8s 위의 AI 서빙 기초

- [ ] vLLM on Kubernetes 기본 배포 실습
  - Deployment, Service, GPU nodeSelector 설정
  - Ollama on K8s (GPU 없이 로컬 CPU 먼저)
- [ ] GPU NodePool 개념 이해
  - Karpenter GPU NodePool 설정 (nvidia.com/gpu resource)
  - GPU 인스턴스 타입 (g4dn, g5) 비용 구조 파악

### 3-2. GCP AI 인프라 (이미 있는 강점 심화)

- [ ] Vertex AI 서빙 인프라 실습 (AI Hypercomputer 배지 기반)
  - Model Registry → Endpoint 배포 → 오토스케일링
  - GKE + Vertex AI 연동 구조 이해
- [ ] Cloud Run 인퍼런스 비용 최적화
  - min-instances 설정으로 Cold Start 제거 (hamster_locally 경험 연결)

### 3-3. MLOps 파이프라인 기초

- [ ] 모델 레지스트리 개념 (MLflow or Vertex AI Model Registry)
- [ ] 인퍼런스 모니터링 (Prometheus로 레이턴시, 처리량 수집)
- [ ] 모델 드리프트 감지 개념 이해

---

## 4. 포트폴리오 업데이트 타임라인

| 시점 | 업데이트 내용 |
|------|--------------|
| Phase 3 완료 후 | Operation Strix "설계 연구" → "직접 구현 완료"로 전환 |
| Phase 3 완료 후 | 이력서 결과 항목에 실제 수치 추가 |
| CKA 취득 후 | 이력서 자격증 준비 → 취득으로 변경 |
| AI 서빙 실습 후 | 포트폴리오 슬라이드 12장 (AI 오케스트레이션) 강화 |

---

## 5. hamster_locally GitHub 공개 여부

> [!example] 결정 보류 조건
> Phase 3 착수 전에 올리면 분산됨. Phase 3 완료 후 판단.
> 올린다면: `.env.example` 추가 + README 아키텍처 다이어그램 1개.

---

## 참고 자료

- [EKS Best Practices Guide](https://aws.github.io/aws-eks-best-practices/)
- [Karpenter Docs](https://karpenter.sh/docs/)
- [ArgoCD App of Apps Pattern](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/)
- [vLLM Docs](https://docs.vllm.ai/)
- [CKA Curriculum](https://github.com/cncf/curriculum)
