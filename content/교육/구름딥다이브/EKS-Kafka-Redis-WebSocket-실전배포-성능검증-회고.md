---
title: EKS + Kafka + Redis + WebSocket 실전 배포 및 성능 검증 회고
tags:
  - eks
  - kafka
  - redis
  - kubernetes
  - go
  - terraform
  - 회고
  - devops
  - infrastructure
aliases:
  - EKS찍먹회고
  - timedeal-eks
date: 2026-02-21
category: 교육/구름딥다이브
status: 완성
priority: 높음
---

# 🎯 EKS + Kafka + Redis + WebSocket 실전 배포 및 성능 검증 회고

> 타임딜 이커머스를 소재로 Go 백엔드 + React FE를 AWS EKS에 직접 배포하고,
> Redis(재고관리) + Kafka(이벤트스트리밍) + WebSocket(실시간 FE) 3중주를 구현 및 k6 부하테스트로 검증한 기록

## 📑 목차
- [[#1. 무엇을 만들었나|무엇을 만들었나]]
- [[#2. 아키텍처 구조|아키텍처 구조]]
- [[#3. 잘 된 것|잘 된 것]]
- [[#4. 삽질 목록|삽질 목록]]
- [[#5. 핵심 개념 정리|핵심 개념 정리]]
- [[#6. 보안 관점 아쉬운 점|보안 관점 아쉬운 점]]
- [[#7. 다음에 해볼 것|다음에 해볼 것]]

---

## 1. 무엇을 만들었나

타임딜 이커머스 서비스를 AWS EKS에 직접 배포

**기술 스택:**

| 영역 | 기술 |
|------|------|
| 인프라 | AWS EKS (1.32), Terraform, ECR |
| 백엔드 | Go (net/http), Kafka 프로듀서/컨슈머, Redis DECR |
| 프론트엔드 | React, WebSocket, nginx |
| 메시지큐 | Apache Kafka 3.9.0 (KRaft, Zookeeper 없음) |
| 캐시/재고 | AWS ElastiCache Redis 7.1 |
| 부하테스트 | k6 (100 VUs) |

**구현한 기능:**
- 타임딜 상품 목록 / 상세 조회 (Redis 실시간 재고 반영)
- 주문 생성 (Choreography Saga 패턴)
- 실시간 Kafka 이벤트 → WebSocket → FE 화면 표시
- k6 부하테스트 결과 확인

---

## 2. 아키텍처 구조

```
[Browser]
    │ HTTP / WebSocket
    ▼
[AWS ELB (Classic)]
    │
    ├──→ [FE Pod: nginx + React]   (timedeal namespace)
    │
    └──→ [BE Pod x2: Go 서버]
              │
              ├──→ [Kafka StatefulSet]   ← PVC (EBS gp2 5Gi)
              │         └── topic: order-events
              │
              └──→ [AWS ElastiCache Redis 7.1]
                        └── stock:{id} 키로 재고 관리
```

**Saga 플로우:**
```
POST /api/orders
  → ORDER_CREATED (Kafka)
  → Redis DECR stock:{id}
  → STOCK_RESERVED (Kafka)
  → 결제 시뮬레이션 (80% 성공)
  → PAYMENT_COMPLETED / FAILED (Kafka)
  → ORDER_COMPLETED / CANCELLED (Kafka)
  → WebSocket → FE 실시간 표시
```

---

## 3. 잘 된 것

> [!note] 성공 포인트
> 백엔드 - 프론트엔드 - 인프라 3중주가 실제로 맞물려 돌아가는 걸 눈으로 확인했다

**k6 부하테스트 결과 (100 VUs):**
- API 응답 성공률: **100%**
- Saga 성공률: **37%** (나머지 63%는 재고 소진으로 정상 CANCELLED)
- p95 응답시간: **3초 이내**

**실시간 이벤트 흐름 확인:**
- 주문 → Kafka → WebSocket → FE 화면에 실시간 이벤트 로그 표시
- `📜 실시간 Kafka 이벤트 4건 / ✅ 주문 완료` 실제로 보임

**Redis 재고 동기화:**
- `GET /api/timedeals` 호출 시 Redis `stock:{id}` 실시간 값 반영
- 부하테스트 후 재고 0으로 FE에 정확히 표시

---

## 4. 삽질 목록

> [!warning] 삽질은 곧 학습이다

### 4-1. ARM vs AMD64 아키텍처 불일치

**문제:** Mac M1(ARM)에서 빌드한 Docker 이미지가 EKS(x86)에서 `exec format error`

**해결:**
```bash
docker build --platform linux/amd64 -t timedeal-backend .
```

### 4-2. Kafka PVC Pending

**문제:** Kafka StatefulSet의 PVC가 Pending 상태로 파드 시작 안 됨

**원인:** EBS CSI 드라이버 미설치 + gp2 기본 StorageClass 미설정

**해결:**
```bash
# EBS CSI 드라이버 설치
aws eks create-addon --addon-name aws-ebs-csi-driver --cluster-name timedeal-eks

# IRSA 권한 연결
eksctl create iamserviceaccount \
  --name ebs-csi-controller-sa \
  --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy

# gp2를 기본 StorageClass로 설정
kubectl patch storageclass gp2 \
  -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

### 4-3. ElastiCache 연결 timeout

**문제:** 백엔드 파드에서 ElastiCache로 연결 안 됨

**원인:** EKS가 자동 생성한 SG(`eks-cluster-sg-*`)가 Redis SG 인바운드에 미포함

**해결:** Redis SG에 EKS 자동생성 SG 인바운드 6379 추가

### 4-4. WebSocket Kafka 이벤트 미수신

**문제:** 주문 성공인데 FE 실시간 이벤트가 안 들어옴

**원인:** 파드 2개가 같은 Kafka Consumer Group ID 사용
→ Kafka가 파드 중 1개에만 메시지 전달
→ WebSocket 연결된 파드 ≠ 메시지 받은 파드

**해결:** 파드 hostname 기반 unique Group ID
```go
hostname, _ := os.Hostname()
groupID := "timedeal-ws-consumer-" + hostname
// 파드마다 다른 그룹 → 모든 파드가 모든 메시지 수신
```

### 4-5. terraform destroy VPC 삭제 실패

**문제:** k8s `LoadBalancer` Service가 생성한 ELB/ENI/SG가 VPC에 남아서 삭제 불가

**교훈:** `terraform destroy` 전에 반드시
```bash
kubectl delete service --all -n timedeal
```
로 LoadBalancer 먼저 제거해야 VPC 깔끔하게 삭제됨

### 4-6. Terraform Security Group description 한글

**문제:** `aws_security_group` resource의 `description` 필드에 한글 입력 시 AWS API 거부

**해결:** description은 반드시 영어로 작성

### 4-7. 재고 FE 미반영 (핵심 버그)

**문제:** k6로 재고를 다 소진해도 FE에는 항상 초기값 표시

**원인:** `TimedealHandler`가 `RedisService` 의존성 없이 인메모리 하드코딩값만 반환

**해결:** `NewTimedealHandler(redisSvc)` 로 Redis 주입 후 조회 시 실시간 `GetStock()` 호출

---

## 5. 핵심 개념 정리

### Redis 재고 패턴

```
초기화:  SET stock:1 47  (서버 시작 시, 키 없을 때만)
차감:    DECR stock:1    → 원자적 감소, 반환값으로 재고 확인
롤백:    INCR stock:1    → Saga 실패 시 복구
조회:    GET stock:1     → FE에 실시간 재고 표시
```

**핵심:** `DECR`은 원자적(atomic)이라 동시 요청에도 중복 차감 없음

### Kafka Consumer Group 전략

| 전략 | 효과 | 사용 케이스 |
|------|------|------------|
| 공유 Group ID | 파드 중 1개만 메시지 수신 | 작업 분산 처리 |
| Unique Group ID (hostname) | 모든 파드가 메시지 수신 | WebSocket 브로드캐스트 |

### StatefulSet vs Deployment

| | Deployment | StatefulSet |
|--|-----------|-------------|
| 파드 이름 | 랜덤 hash | 고정 (kafka-0, kafka-1) |
| 스토리지 | 공유 or 임시 | 파드별 독립 PVC |
| 사용처 | 백엔드/FE | Kafka, Redis, DB |

### 재고 초기화 로직

```
서버 시작
  └→ initStock()
       └→ SetStock() - Redis EXISTS 체크
            ├→ 키 있으면: 생략 (재시작 시 재고 보존)
            └→ 키 없으면: SET 초기값
```

- 파드 재시작: Redis 키 유지 → 재고 그대로 보존
- terraform destroy → apply: Redis도 삭제 → 초기값 재설정

---

## 6. 보안 관점 아쉬운 점

> [!danger] 현재 구조의 보안 취약점

- **인증 없음**: URL만 알면 누구나 주문 API 호출 가능
- **Rate Limiting 없음**: 1명이 초당 수천 건 주문 가능
- **CORS 전체 개방**: `Access-Control-Allow-Origin: *`
- **백엔드 퍼블릭 노출**: Private Subnet에 있어야 정상

**실무라면 추가해야 할 것:**

| 레이어 | 방법 |
|--------|------|
| 인증 | JWT 토큰 (Spring Security) |
| Rate Limit | Redis로 IP당 N회/분 제한 |
| CORS | 허용 도메인 화이트리스트 |
| 네트워크 | ALB → Private Subnet 백엔드 |
| WAF | AWS WAF (SQL injection, XSS 차단) |

→ 스프링부트 팀원들이 Spring Security 붙이면 자연스럽게 해결

---

## 7. 다음에 해볼 것

- [ ] Spring Boot로 동일 구조 재현 (팀프로젝트)
- [ ] MSK (Managed Kafka) 사용 vs EKS 내 Kafka 비용/운영 비교
- [ ] HPA (Horizontal Pod Autoscaler) 붙여서 부하 시 파드 자동 증가 확인
- [ ] JWT 인증 + Rate Limiting 추가
- [ ] Helm Chart로 배포 자동화
- [ ] `kubectl delete service` 먼저 하고 `terraform destroy` 습관화

---

> [!tip] 이번 찍먹 핵심 교훈
> **"AWS 리소스는 서로 연결되어 있다"**
> EKS가 만드는 ELB, ENI, SG는 Terraform 밖에 생성되므로
> 항상 k8s 오브젝트 먼저 정리 → 그 다음 terraform destroy
