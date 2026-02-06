---
title: gcloud CLI 명령어 정리
tags:
  - gcp
  - gcloud
  - cli
  - devops
aliases:
  - gcloud 명령어
  - GCP CLI
date: 2026-02-06
category: GCP/CLI
status: 완성
---

# gcloud CLI 명령어 정리

## 1. Config 관리 (멀티 계정)

여러 GCP 계정/프로젝트를 사용할 때 config로 스위칭.

```bash
# config 목록 확인
gcloud config configurations list

# config 스위칭
gcloud config configurations activate [CONFIG_NAME]

# 현재 프로젝트 확인
gcloud config get-value project

# 현재 계정 확인
gcloud config get-value account
```

### 내 Config 설정

| Config Name | 용도 | 계정 |
|-------------|------|------|
| `default` | 기본 (포트폴리오 등) | rkvrh00@gmail.com |
| `cka-new` | CKA 실습용 | 새 계정, 크레딧 사용 |

---

## 2. 프로젝트 관리

```bash
# 프로젝트 목록 (ID, 이름, 번호)
gcloud projects list --format="table(projectId,name,projectNumber)"

# 프로젝트 전환
gcloud config set project [PROJECT_ID]
```

---

## 3. Cloud Run

```bash
# 서비스 목록
gcloud run services list --format="table(metadata.name,status.url,region)"

# 특정 리전만
gcloud run services list --region=asia-northeast3

# 서비스 상세 정보
gcloud run services describe [SERVICE_NAME] --region=asia-northeast3

# 로그 확인
gcloud run services logs read [SERVICE_NAME] --region=asia-northeast3
```

---

## 4. Cloud Scheduler

```bash
# job 목록 (리전 필수)
gcloud scheduler jobs list --location=asia-northeast3

# job 생성 (HTTP 타겟)
gcloud scheduler jobs create http [JOB_NAME] \
  --location=asia-northeast3 \
  --schedule="*/10 * * * *" \
  --uri="https://[CLOUD_RUN_URL]/api/endpoint" \
  --http-method=POST

# job 실행 (수동)
gcloud scheduler jobs run [JOB_NAME] --location=asia-northeast3

# job 삭제
gcloud scheduler jobs delete [JOB_NAME] --location=asia-northeast3
```

---

## 5. BigQuery (bq CLI)

```bash
# 데이터셋 목록
bq ls --project_id=[PROJECT_ID]

# 테이블 목록
bq ls [PROJECT_ID]:[DATASET_ID]

# 테이블 상세 정보 (사이즈, 행 수, 위치)
bq show --format=prettyjson [PROJECT_ID]:[DATASET].[TABLE]

# 쿼리 실행
bq query --project_id=[PROJECT_ID] --use_legacy_sql=false \
  "SELECT * FROM [DATASET].[TABLE] LIMIT 10"
```

---

## 6. API 활성화

```bash
# API 활성화
gcloud services enable cloudscheduler.googleapis.com
gcloud services enable run.googleapis.com
gcloud services enable bigquery.googleapis.com

# 활성화된 API 목록
gcloud services list --enabled
```

---

## 7. 비용 관련

```bash
# 빌링 계정 목록
gcloud billing accounts list

# 프로젝트에 연결된 빌링 계정
gcloud billing projects describe [PROJECT_ID]
```

---

## 8. 유용한 포맷 옵션

```bash
# 테이블 형식
--format="table(field1,field2)"

# JSON 형식
--format="json"

# 값만 추출
--format="value(fieldName)"

# Pretty JSON
--format="prettyjson"
```

---

## 관련 문서

- [[GCP Skills Boost 학습]]
- [[Terraform GCP 설정]]
