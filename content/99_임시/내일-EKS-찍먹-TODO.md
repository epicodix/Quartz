---
title: EKS 찍먹 TODO - 백/프론트/인프라 3중주
date: 2026-02-19
status: 진행중
---

# 내일 EKS 찍먹 TODO

> 목표: Go 백엔드 + React FE + EKS(Kafka/Redis) 실제 연동 확인

---

## 오늘 못 한 것 (내일 시작 전 Claude한테 맡기기)

- [ ] Go 백엔드 작성 (`timedeal-k8s/backend/`)
- [ ] EKS 테라폼 작성 (`timedeal-k8s/terraform/`)

---

## 내일 순서

### 1. 인프라 띄우기
- [ ] `cd timedeal-k8s/terraform && terraform apply`
- [ ] EKS 클러스터 확인 (`kubectl get nodes`)
- [ ] ElastiCache Redis 엔드포인트 확인

### 2. EKS에 Kafka 올리기
- [ ] Kafka StatefulSet 배포 (`kubectl apply`)
- [ ] 토픽 생성 (`order-events`)
- [ ] 동작 확인

### 3. 백엔드 빌드 & 배포
- [ ] ECR 레포 생성
- [ ] Docker 이미지 빌드 & push
- [ ] EKS에 배포 + 환경변수 (Redis/Kafka 엔드포인트) 주입
- [ ] ALB 주소 확인

### 4. FE 빌드 & 배포
- [ ] `.env` 수정
  ```
  REACT_APP_USE_MOCK=false
  REACT_APP_API_URL=http://{ALB주소}
  REACT_APP_WS_URL=ws://{ALB주소}/ws/events
  ```
- [ ] Docker 이미지 빌드 & ECR push
- [ ] EKS에 배포

### 5. 3중주 확인
- [ ] FE 접속 → 타임딜 목록 실제 데이터로 나오는지
- [ ] 구매 클릭 → 주문 생성 → Kafka 이벤트 발행
- [ ] `/monitor` 페이지 → 실시간 이벤트 흐름 확인
- [ ] Redis 재고 카운터 동작 확인

### 6. 정리 (과금 주의!)
- [ ] `terraform destroy`

---

## 폴더 구조

```
timedeal-k8s/
├── timedeal-front/     # FE (완성)
├── backend/            # Go 백엔드 (내일 Claude가 먼저 만들어줌)
└── terraform/          # EKS 인프라 (내일 Claude가 먼저 만들어줌)
```

---

## FE가 필요한 백엔드 API

```
GET  /api/timedeals          타임딜 목록
GET  /api/timedeals/:id      타임딜 상세
POST /api/orders             주문 생성 → Kafka 발행
GET  /api/orders/:id         주문 상태 조회
WS   /ws/events              Kafka 이벤트 실시간 스트리밍
```

---

## 예상 비용 (찍먹 3시간 기준)

```
EKS 클러스터   $0.10/h  × 3h = $0.30
t3.medium × 2  $0.17/h  × 3h = $0.51
ElastiCache    $0.02/h  × 3h = $0.06
─────────────────────────────────────
합계                          ~$1
```

끝나면 반드시 terraform destroy!
