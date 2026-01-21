---
title: Claude_세션_2026-01-21_포트폴리오_운영시스템_구축
creation_date: 2026-01-21
date: 2026-01-21
tags: [Claude, Session, Go, CloudRun, BigQuery, Terraform, Netlify, Tailscale]
aliases: [포트폴리오 운영 세션]
category: 클라우드/Session
status: 완성
priority: 높음
published: false
---

# 🗓️ Claude 세션 기록 (2026-01-21)

## 📋 세션 개요
포트폴리오 사이트(`on.epix.kr`)에 **실시간 모니터링 시스템**을 구축하고, **비용 효율적인 트래픽 제어** 메커니즘을 적용한 세션입니다.

---

## 1. 주요 작업 내역

### 1.1 Butterfly Server 개선 (Go)
- **하트 로직 버그 수정**: `handleHeartFormation` 함수가 `count` 파라미터를 무시하던 문제 해결
- **실시간 대형 업데이트**: 나비 수 조절 시 `debouncedHeartUpdate()`로 자동 갱신
- **Tailscale Funnel 테스트**: 로컬 서버를 `https://epix-macbookair.tail561905.ts.net/`으로 외부 공개

### 1.2 GS네오텍 채용 정보 리서치
- 클라우드 엔지니어 채용 직무 분석 (SA, Ops, Data Engineer)
- 올리브영 GCP 사례 분석 (BigQuery, Cloud Composer, GKE)
- 향후 과제 예측: FinOps, App Modernization, GenAI
- 신입 역할 분석: IaC 실무, PoC 수행, 자동화, Troubleshooting

### 1.3 포트폴리오 사이트 업데이트
- Kubernetes 프로젝트 설명 수정 (Inflearn 실습 환경 구축)
- 메타 광고 프로젝트: `Python + GraphQL` 강조
- 프로젝트 섹션 소개문 변경: "Go + Cloud Run 기반의 실시간 서비스 상태 감지"

### 1.4 데이터 파이프라인 구축 (핵심)
**아키텍처**: Cloud Scheduler → Cloud Run (Go) → BigQuery

| 단계 | 작업 내용 |
|------|----------|
| **Infrastructure** | Terraform으로 BigQuery Dataset/Table 생성 (파티셔닝, 90일 만료) |
| **Backend** | Go `handlers/collector.go` 작성 (BigQuery Insert 로직) |
| **Deployment** | Cloud Run 배포 (`gcloud builds submit` + `gcloud run deploy`) |

### 1.5 비용 방어 & 트래픽 모니터링
- **Max Instances = 1**: 비용 폭탄 방지
- **Cache-Control**: `max-age=5`로 F5 연타 방어
- **Traffic Middleware**: Go에서 요청 수 카운팅
- **UI 뱃지**: "Go 모니터링 시스템: Stable (6 req/min)" 표시
- **Last Minute Count**: 폭주 기록 1분간 유지 로직 추가

---

## 2. 자주 사용한 쉘 명령어 패턴

### 2.1 Netlify 배포
```bash
# 포트폴리오 프로덕션 배포
cd portfolio && netlify deploy --prod --dir=.
```

### 2.2 Tailscale Funnel
```bash
# 로컬 포트 외부 공개
tailscale funnel --bg 8081

# Funnel 상태 확인
tailscale funnel status

# Funnel 종료
tailscale funnel --https=443 off
```

### 2.3 Terraform (BigQuery)
```bash
# 초기화 및 배포
cd portfolio/status-api/infra
terraform init
terraform apply -auto-approve

# GCP 인증 (필요 시)
gcloud auth application-default login
```

### 2.4 Cloud Run 배포 (Go)
```bash
# 이미지 빌드 + 레지스트리 푸시
cd portfolio/status-api
gcloud builds submit --tag gcr.io/claude-business-card/portfolio-status-api

# Cloud Run 서비스 배포
gcloud run deploy portfolio-status-api \
  --image gcr.io/claude-business-card/portfolio-status-api \
  --region asia-northeast3 \
  --platform managed \
  --allow-unauthenticated

# 최대 인스턴스 제한 (비용 방어)
gcloud run services update portfolio-status-api \
  --max-instances 1 \
  --region asia-northeast3
```

### 2.5 부하 테스트
```bash
# 1000회 비동기 요청 (curl)
for i in {1..1000}; do
  curl -s "https://portfolio-status-api-1060223101922.asia-northeast3.run.app/api/status" > /dev/null &
done
```

### 2.6 Go 모듈 관리
```bash
# 의존성 정리
cd portfolio/status-api
go mod tidy

# 새 패키지 추가
go get cloud.google.com/go/bigquery
```

---

## 3. 생성된 파일 목록

| 경로 | 설명 |
|------|------|
| `portfolio/status-api/infra/main.tf` | BigQuery Terraform 코드 |
| `portfolio/status-api/handlers/collector.go` | BigQuery 적재 로직 |
| `GEMINI/07_Practice_GSNeotek_...` | GS네오텍 채용 분석 리포트 |
| `GEMINI/08_Practice_Portfolio_Ops_Pipeline.md` | 모니터링 파이프라인 가이드 |
| `GEMINI/09_Practice_Cost_Efficient_Traffic_Control.md` | 비용 방어 & 트래픽 제어 가이드 |

---

## 4. 핵심 배운 점 (면접 대비)

### Cloud Run 장점
- Serverless로 비용 효율적 (Scale to Zero)
- Docker 컨테이너 기반으로 이식성 높음
- Traffic Splitting으로 A/B 테스트 가능

### Cloud Run 단점 (면접 필수!)
1. **Cold Start**: 첫 요청 시 2~5초 지연
2. **지속 고부하 시 비효율**: 24시간 서비스엔 VM/GKE가 경제적
3. **백그라운드 작업 제한**: 응답 후 CPU Throttling
4. **Stateless**: 로컬 파일 저장 불가 → 외부 스토리지 필수

### 비용 제어 포인트
- `max-instances` 설정으로 물리적 한계 설정
- `Cache-Control` 헤더로 불필요한 요청 감소
- BigQuery 파티셔닝 + 만료 설정으로 스토리지 비용 0원 유지

---

## 5. 다음 단계 (To-Do)

- [ ] Cloud Scheduler 설정: `/api/collect`를 10분마다 호출
- [ ] BigQuery 조회 API: `GET /api/analytics`에서 시계열 데이터 반환
- [ ] 프론트엔드 차트: Plotly.js로 Latency 추이 시각화
- [ ] OIDC 인증: 스케줄러 외 무단 호출 차단

<br>
<div align="right" style="font-size: 0.8em; color: gray; opacity: 0.6;">
  Session with Claude Opus 4.5 | 2026-01-21
</div>
