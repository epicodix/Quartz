---
title: MLOps 핵심 개념 정리
tags:
  - MLOps
  - DevOps
  - ML
  - Kubernetes
  - EKS
  - 커리어
aliases:
  - MLOps
  - 머신러닝운영
date: 2026-05-17
category: 2_기술_분석
status: 완성
priority: 높음
---

# 🎯 MLOps 핵심 개념

## 📑 목차
- [[#1. MLOps란|MLOps란]]
- [[#2. DevOps와 무엇이 다른가|DevOps와의 차이]]
- [[#3. ML 파이프라인 전체 흐름|ML 파이프라인]]
- [[#4. 핵심 도구 스택|핵심 도구 스택]]
- [[#5. 모델 서빙|모델 서빙]]
- [[#6. 모델 모니터링|모델 모니터링]]
- [[#7. 내 스택과 연결 포인트|내 스택 연결]]

---

## 1. MLOps란

> [!note] 한 줄 정의
> ML 모델을 프로덕션에 **안정적으로 배포하고, 지속적으로 운영·개선**하는 엔지니어링 체계

DevOps가 "코드를 빠르고 안정적으로 배포"라면,
MLOps는 "모델을 빠르고 안정적으로 배포 + 데이터/성능 변화까지 관리"

```
데이터 → 학습 → 모델 → 배포 → 서빙 → 모니터링 → 재학습
           ↑___________________________|
```

---

## 2. DevOps와 무엇이 다른가

| 구분 | DevOps | MLOps |
|------|--------|-------|
| 배포 대상 | 코드 | 코드 + 모델 + 데이터 |
| 버전 관리 | Git | Git + 데이터 버전 + 모델 버전 |
| 테스트 기준 | 기능 정확성 | 모델 정확도, 데이터 분포 |
| 재배포 트리거 | 코드 변경 | 코드 변경 **또는 데이터 변화** |
| 실패 원인 | 버그 | 버그 + **데이터 드리프트** |

> [!warning] MLOps의 핵심 어려움
> 코드가 안 바뀌어도 **데이터가 바뀌면 모델 성능이 떨어진다.**
> 이게 일반 DevOps에는 없는 개념.

---

## 3. ML 파이프라인 전체 흐름

```
1. Data Ingestion     데이터 수집 (S3, DB, API)
        ↓
2. Feature Engineering  특성 가공 (Feature Store)
        ↓
3. Training           모델 학습 (GPU 인스턴스)
        ↓
4. Evaluation         성능 평가 (정확도, F1, 레이턴시)
        ↓
5. Model Registry     모델 버전 등록 (MLflow)
        ↓
6. Serving            API로 서빙 (KServe, BentoML)
        ↓
7. Monitoring         성능·데이터 드리프트 감시
        ↓
8. Re-training        성능 저하 시 자동 재학습 트리거
```

---

## 4. 핵심 도구 스택

### 실험 관리
- **MLflow** — 실험 추적(파라미터, 메트릭, 아티팩트), 모델 레지스트리
  - 로컬~EKS 어디서나 돌아감, 오픈소스
  - "이 모델이 어떤 데이터로 학습됐는가" 추적

### ML 파이프라인 오케스트레이션
- **Kubeflow** — EKS 위에서 ML 파이프라인 정의·실행
  - 학습 → 평가 → 배포를 DAG으로 자동화
  - Argo Workflows 기반
- **Apache Airflow** — 데이터 파이프라인 스케줄링

### Feature Store
- **Feast** — 학습·서빙 시점의 피처 일관성 보장
  - 학습할 때 쓴 피처와 서빙할 때 쓰는 피처가 달라지는 문제(Training-Serving Skew) 방지

### 모델 서빙
- **KServe** (구 KFServing) — K8s 네이티브 모델 서빙
- **BentoML** — 모델을 컨테이너로 패키징해서 EKS 배포
- **Triton Inference Server** (NVIDIA) — GPU 최적화 서빙

### 데이터 버전 관리
- **DVC** (Data Version Control) — Git처럼 데이터·모델 버전 관리, S3 백엔드

---

## 5. 모델 서빙

> [!info] 서빙 방식 2가지

### 실시간 서빙 (Online Inference)
- 요청 들어오면 즉시 예측 반환
- REST API 또는 gRPC
- 레이턴시 중요 → p95 Latency 모니터링
- EKS + HPA로 트래픽 따라 스케일

### 배치 서빙 (Batch Inference)
- 대량 데이터를 일괄 처리
- 레이턴시보다 처리량이 중요
- CronJob 또는 Argo Workflows로 스케줄링
- S3에 결과 저장

### GPU 인프라 (Karpenter 연결)

```yaml
# Karpenter NodePool에 GPU 노드 추가
requirements:
  - key: karpenter.k8s.aws/instance-family
    operator: In
    values: [g4dn, g5]   # NVIDIA GPU 인스턴스
  - key: karpenter.sh/capacity-type
    operator: In
    values: [spot]        # 학습은 Spot으로 비용 절감
```

---

## 6. 모델 모니터링

> [!note] 일반 앱 모니터링과 다른 점
> 코드 버그 외에 **데이터 자체가 변하는 것**을 감지해야 한다.

### 데이터 드리프트 (Data Drift)
- 서빙 시점 입력 데이터 분포가 학습 데이터와 달라지는 현상
- 예: 타임딜 앱에서 상품 카테고리 분포가 바뀌면 추천 모델 성능 저하

### 모델 드리프트 (Model Drift / Concept Drift)
- 현실 세계가 바뀌어서 모델의 예측이 맞지 않게 되는 현상
- 예: 코로나 이후 사용자 구매 패턴이 바뀌면 기존 모델이 틀림

### 봐야 할 지표

| 지표 | 의미 |
|------|------|
| 예측 분포 변화 | 출력값 분포가 갑자기 달라지면 드리프트 신호 |
| 입력 피처 분포 | 학습 시 데이터와 비교 |
| 비즈니스 지표 | 클릭률, 전환율 — 모델 성능의 최종 판단 |
| 모델 레이턴시 | p95 기준, GPU 메모리 포함 |

> [!tip] 옵저버빌리티 연결
> 모델 모니터링 = 옵저버빌리티 그대로 적용
> Metrics(예측 분포) + Logs(추론 실패) + Traces(파이프라인 어디서 느린지)

---

## 7. 내 스택과 연결 포인트

> [!example] 지금 할 수 있는 것들

| 내 경험 | MLOps 연결 |
|---------|-----------|
| EKS + Karpenter | GPU 노드풀 추가, 학습 워크로드 스케줄링 |
| Terraform | MLflow, Kubeflow 인프라 코드화 |
| Observability (Prometheus + Loki + Grafana) | 모델 서빙 레이턴시, 드리프트 알람 |
| Istio Ambient | 모델 서빙 API mTLS, 트래픽 제어 |
| S3 + IRSA | 모델 아티팩트 저장, DVC 백엔드 |
| CI/CD (CodePipeline) | 모델 재학습 파이프라인 자동화 |

> [!tip] 진입 전략
> MLflow + KServe를 EKS 위에 Terraform으로 띄우는 것부터 시작.
> 기존 pposiraegi 인프라에 ML 서빙 레이어 추가하는 형태로 포트폴리오 확장 가능.

---

## 관련 문서

- [[멘토링_핵심개념_네트워크_EKS]]
- [[멘토링_예상질문_K8s_Service_Karpenter]]
- [[PLG 스택 가이드 - Prometheus + Loki + Grafana (k3d)]]
