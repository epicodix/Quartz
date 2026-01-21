---
title: 포트폴리오_실시간_모니터링_파이프라인_구축기
creation_date: 2026-01-21
date: 2026-01-21
tags: [Go, CloudRun, BigQuery, Terraform, Observability, Portfolio]
aliases: [포트폴리오 모니터링, Go BigQuery Pipeline]
category: 클라우드/Project
status: 완성
priority: 높음
model: gemini-3.0-pro preview
published: false
---

# 🚀 포트폴리오 실시간 모니터링 파이프라인 구축기

> **"단순 핑(Ping) 체크를 넘어, 데이터 엔지니어링 역량을 보여주자."**
> Cloud Run과 BigQuery를 활용해 **운영비 0원**으로 실시간 서비스 상태를 수집하고 저장하는 파이프라인을 구축했습니다.

## 1. 아키텍처 (Architecture)

```mermaid
graph LR
    Scheduler[Cloud Scheduler] -- "Trigger (Every 10m)" --> API[Cloud Run (Go)]
    API -- "Check Health" --> Projects[Target Services]
    API -- "Insert Logs" --> BQ[(BigQuery)]
    Portfolio[Portfolio Web] -- "Fetch Status" --> API
```

*   **Collector**: Go 언어로 작성된 경량 API 서버 (Cloud Run).
*   **Storage**: BigQuery (Partitioned Table로 비용 최적화).
*   **Trigger**: Cloud Scheduler (주기적 실행).
*   **FinOps**: 모든 구성 요소가 프리 티어(Free Tier) 내에서 동작.

## 2. 핵심 구현 내용

### 2.1 인프라 (IaC by Terraform)
BigQuery 테이블을 Terraform으로 관리하여 **"코드형 인프라(IaC)"** 역량을 증명했습니다.
*   **Partitioning**: `check_time` 기준 일(Day) 단위 파티셔닝 적용 → 쿼리 비용 최소화.
*   **Expiration**: 90일 후 데이터 자동 삭제 → 스토리지 비용 0원 유지.

```hcl
resource "google_bigquery_table" "service_latency_log" {
  time_partitioning {
    type = "DAY"
    field = "check_time"
  }
  # ... 스키마 정의
}
```

### 2.2 백엔드 (Go + BigQuery)
단순 HTTP 요청뿐만 아니라, **Google Cloud Client Library**를 활용해 데이터를 적재하는 로직을 추가했습니다.

*   **동시성(Concurrency)**: Goroutine을 사용해 여러 프로젝트를 병렬로 체크.
*   **수집 API**: `/api/collect` 엔드포인트를 통해 스케줄러가 트리거 가능.

```go
// status-api/handlers/collector.go
func CollectAndSave(ctx context.Context) error {
    // 1. 상태 체크 (병렬)
    statuses := CheckAllProjects(ctx)
    
    // 2. BigQuery 적재 (Bulk Insert)
    inserter := client.Dataset("portfolio_ops").Table("service_latency_log").Inserter()
    return inserter.Put(ctx, logs)
}
```

## 3. 배포 및 운영 (DevOps)

### 3.1 배포 프로세스
1.  **Docker Build**: `golang:1.24-alpine` 기반 최적화 이미지 빌드.
2.  **Cloud Build**: `gcloud builds submit`으로 이미지 레지스트리(GCR) 등록.
3.  **Cloud Run Deploy**: `gcloud run deploy`로 무중단 배포.

### 3.2 향후 과제 (To-Do)
*   [ ] **Cloud Scheduler 설정**: GCP 콘솔에서 `POST /api/collect`를 10분 주기로 호출하도록 설정.
*   [ ] **시각화 (Visualization)**: `GET /api/analytics` 핸들러를 수정하여 BigQuery 데이터를 조회(`SELECT`)하고, 프론트엔드 차트에 연결.
*   [ ] **보안 강화**: OIDC Token 인증을 적용하여 스케줄러 외의 무단 호출 차단.

<br>
<div align="right" style="font-size: 0.8em; color: gray; opacity: 0.6;">
  Supported by gemini-3.0-pro preview
</div>
