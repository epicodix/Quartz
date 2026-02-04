---
title: GCP Cloud Run 소액 결제 트러블슈팅 (22원의 범인)
creation_date: 2026-02-02
date: 2026-02-02
tags: [GCP, CloudRun, Billing, Troubleshooting, Gcloud, Cost-Optimization, Practice]
aliases: [GCP 22원 결제 원인, Cloud Build 버킷 삭제, Multi-Region 과금 이슈]
category: 클라우드/GEMINI/포트폴리오
status: 완료
priority: 높음
model: gemini-3.0-pro preview
---

# 1. 상황 개요 (Context)

## 1.1. 문제 인식 (The Problem)
Google Cloud Platform(GCP)에서 예상치 못한 소액 결제(₩22, ₩40 등)가 발생했다.
Cloud Run 및 관련 리소스는 GCP의 **'무료 등급(Free Tier)'** 범위 내에서 사용 중이라고 확신했으나, 1월 청구서에 **Cloud Storage (US Region)** 비용이 청구되었다.

- **증상**: 1월 17~20일 배포 후 약 22원의 스토리지 비용 발생.
- **의문**: "Cloud Storage는 월 5GB까지 무료인데, 왜 300MB 쓰고 돈이 나가지?"

## 1.2. 작업 환경 (Environment)
- **작성일**: 2026년 2월 2일 월요일
- **OS**: Darwin (macOS)
- **GCP 프로젝트**: `claude-business-card`
- **목표**: 비용 발생 원인을 정확히 규명하고, 서비스 중단 없이 비용 요소를 제거한다.

---

# 2. 탐정 놀이: 원인 추적 (Investigation Flow)

터미널에서 `gcloud` CLI를 사용하여 리소스를 전수 조사했다.

## 2.1. 현재 리소스 스캔
먼저 현재 프로젝트에 존재하는 스토리지 버킷과 아티팩트 저장소를 확인했다.

```bash
# 1. Cloud Storage 버킷 목록 조회
$ gcloud storage ls --project=claude-business-card
gs://claude-business-card_cloudbuild/               <-- 의심스러운 녀석 (1)
gs://run-sources-claude-business-card-asia-northeast3/

# 2. Artifact Registry (컨테이너 이미지) 목록 조회
$ gcloud artifacts repositories list --project=claude-business-card
REPOSITORY               LOCATION         SIZE (MB)
claude-business-card     asia-northeast3  0
cloud-run-source-deploy  asia-northeast3  12.944
gcr.io                   us               76.383      <-- 의심스러운 녀석 (2)
```

## 2.2. 용량 및 속성 분석
가장 유력한 용의자인 `cloudbuild` 버킷의 용량과 설정을 뜯어보았다.

```bash
# 3. 버킷 용량 확인
$ gcloud storage du gs://claude-business-card_cloudbuild/ -s --readable-sizes
316.15MiB    gs://claude-business-card_cloudbuild

# 4. [결정적 단서] 버킷 위치 설정(Type) 확인
$ gcloud storage buckets describe gs://claude-business-card_cloudbuild/ --format="value(locationType, location)"
multi-region    US
```

## 2.3. 핵심 원인 (Root Cause)
**"범인은 `Multi-Region` 설정이다."**

GCP Free Tier 정책의 맹점이었다.
- **무료 조건**: 특정 리전(us-east1 등)의 **Regional(단일 리전)** Storage 5GB.
- **실제 상황**: Cloud Build가 생성한 버킷은 **Multi-Region(다중 리전)** 유형이었다.
- **결론**: Multi-Region 스토리지에는 무료 등급이 적용되지 않는다. 단 1MB를 써도 과금된다.

---

# 3. 알리바이 확인: 안전성 검증 (Impact Analysis)

비용을 줄이겠다고 무턱대고 삭제했다가 운영 중인 서비스가 멈추면 안 된다.
**"이 버킷을 지워도 서비스는 무사한가?"** 를 검증했다.

## 3.1. 서비스 의존성 분석
현재 운영 중인 `portfolio-status-api` 서비스의 설정 파일(YAML)을 분석했다.

```bash
# 서비스 상세 설정 조회
$ gcloud run services describe portfolio-status-api --region=asia-northeast3 --format="yaml"
```

**[분석 결과]**
1.  **이미지 위치**: `image: gcr.io/claude-business-card/portfolio-status-api`
    - 서비스는 `gcr.io`에 있는 완성된 이미지를 참조한다.
2.  **버킷 참조**: `gs://claude-business-card_cloudbuild`는 설정 어디에도 없다.
3.  **결론**: 삭제하려는 버킷은 배포 과정에서 생긴 **"로그 및 임시 소스 파일(부산물)"**일 뿐, 런타임 서비스와는 100% 무관하다.

---

# 4. 집행: 해결 조치 (Execution)

검증이 끝났으므로 과금 주범인 버킷을 삭제했다.

```bash
# 버킷 및 내부 파일 강제 삭제 (-r)
$ gcloud storage rm -r gs://claude-business-card_cloudbuild/

# 실행 로그 (Output)
Removing objects:
Removing gs://claude-business-card_cloudbuild/source/1768962461...tgz
...
Removing buckets:
Removing gs://claude-business-card_cloudbuild/...
Completed 1/1
```

---

# 5. 사후 검증 (Verification)

수술은 성공했다. 환자가 깨어나는지 확인한다.

## 5.1. 서비스 생존 확인
```bash
# API 상태 체크 엔드포인트 호출
$ curl -s https://portfolio-status-api-1060223101922.asia-northeast3.run.app/api/status
```

**[응답 결과]**
```json
{
  "projects": [
    { "name": "오픈챗 서비스", "status": "online", ... },
    { "name": "Quartz 기술 블로그", "status": "online", ... },
    { "name": "비즈니스 명함", "status": "online", ... }
  ],
  "timestamp": "2026-02-02T01:02:31...",
  "system_load": "stable"
}
```

## 5.2. 최종 결론
1.  **조치 완료**: 비용 유발 리소스(`gs://...cloudbuild`) 삭제 완료.
2.  **서비스 상태**: 정상 (`online`).
3.  **기대 효과**: 다음 달 Cloud Storage 청구 비용 **₩0 예상**.

<br>
<div align="right" style="font-size: 0.8em; color: gray; opacity: 0.6;">
  Supported by gemini-3.0-pro preview
</div>