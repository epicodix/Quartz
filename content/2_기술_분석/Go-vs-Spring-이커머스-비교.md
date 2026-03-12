---
title: Go vs Spring Boot - 이커머스 관점 비교
tags:
  - go
  - spring-boot
  - kotlin
  - 이커머스
  - 분산시스템
  - 백엔드
aliases:
  - Go vs Spring
  - 스프링 비교
date: 2026-02-24
category: 2_기술_분석/backend
status: 완성
priority: 높음
---

# 🎯 Go vs Spring Boot - 이커머스 관점 비교

> 타임딜 프로젝트(Go + Kafka + Saga)를 직접 짜고 부딪히면서 체득한 내용.
> 이론이 아닌 실제 장애 포인트 기반 정리.

## 📑 목차
- [[#1. 코드 대응 비교|코드 대응 비교]]
- [[#2. 초반 vs 후반 압박|초반 vs 후반 압박]]
- [[#3. Kafka 써도 되는 곳 vs 안 되는 곳|Kafka 써도 되는 곳]]
- [[#4. 이커머스 실무 정석 구조|이커머스 실무 정석 구조]]
- [[#5. 핵심 결론|핵심 결론]]

---

## 1. 코드 대응 비교

> [!note] 핵심
> Go에서 직접 짜던 것들을 Spring이 숨겨놓은 것. 개념은 동일.

### 트랜잭션

```go
// Go - 직접 짜야 함
func (s *OrderService) CreateOrder(req OrderRequest) (*Order, error) {
    tx, err := db.Begin()
    if err != nil { return nil, err }
    defer tx.Rollback()
    // ... 로직
    return order, tx.Commit()
}
```

```kotlin
// Spring - 어노테이션 하나
@Transactional
fun createOrder(req: OrderRequest): Order {
    // 예외 터지면 자동 롤백
}
```

### 의존성 주입 (DI)

```go
// Go - 직접 조립 (NewXxx 패턴)
func NewOrderService(repo *OrderRepository, kafka *KafkaService) *OrderService {
    return &OrderService{repo: repo, kafka: kafka}
}
// main.go에서 직접 연결
svc := NewOrderService(repo, kafka)
```

```kotlin
// Spring - 선언만 하면 자동 주입
@Service
class OrderService(
    private val repo: OrderRepository,  // Spring이 알아서 주입
    private val kafka: KafkaService     // Spring이 알아서 주입
)
```

### Repository (쿼리)

```go
// Go - SQL 직접 작성
func (r *OrderRepo) FindByUserID(id int) ([]*Order, error) {
    rows, err := r.db.Query("SELECT * FROM orders WHERE user_id = ?", id)
    // ... rows 파싱
}
```

```kotlin
// Spring - 메서드 이름이 곧 SQL
interface OrderRepository : JpaRepository<Order, Long> {
    fun findByUserId(userId: Long): List<Order>
    // SELECT * FROM orders WHERE user_id = ? 자동 생성
}
```

### 예외 처리 (전역)

```go
// Go - 라우터마다 직접 처리
func (h *Handler) CreateOrder(w http.ResponseWriter, r *http.Request) {
    order, err := h.svc.CreateOrder(req)
    if err != nil {
        http.Error(w, err.Error(), 400)  // 매번 직접
        return
    }
}
```

```kotlin
// Spring - 한 곳에서 전부 처리 (corsMiddleware 개념)
@RestControllerAdvice
class GlobalExceptionHandler {
    @ExceptionHandler(NotFoundException::class)
    fun handle(e: NotFoundException) = ResponseEntity.status(404).body(...)
    // 모든 핸들러에 자동 적용
}
```

### 한눈에 비교

| Go | Spring |
|----|--------|
| `tx.Begin/Rollback/Commit` | `@Transactional` |
| `NewOrderHandler(hub)` | `@Service` 자동 주입 |
| `corsMiddleware` | `@ControllerAdvice` |
| `"SELECT * FROM ..."` | `findByUserId()` |
| `go removeClient(conn)` | `@Async` |

---

## 2. 초반 vs 후반 압박

```
Spring Boot
  초반: 설정 많다, 코드 길다, 학습 곡선 있다  →  고통
  후반: 이미 검증된 패턴이 버텨줌              →  안정

Go
  초반: 빠르다, 심플하다, 돌아간다             →  쾌감
  후반: "어? 이 케이스 안 짰는데?"             →  비명
```

### 후반에 터지는 순서

```
1단계  이벤트 유실
       새벽 2시: "주문 들어왔는데 재고 안 빠짐"
       → Kafka publish 타이밍에 서버 재시작
       → Outbox 없으니 추적 불가

2단계  보상 트랜잭션 실패
       "환불했는데 재고가 안 돌아왔어요"
       → rollback 도중 Redis 잠깐 죽음
       → Saga 상태 없으니 어디서 멈췄는지 모름

3단계  중복 결제
       "결제가 두 번 됐어요"
       → 네트워크 타임아웃 → 클라이언트 재시도
       → 멱등성 처리 없었던 것

4단계  상태 미스매치
       "주문은 완료인데 배송이 안 시작됨"
       → 인메모리 상태가 pod 재시작으로 증발
```

> [!warning] 부하테스트 함정
> k6 1만 TPS는 **양**을 테스트.
> 장애는 **타이밍**에서 난다.
> 깔끔한 환경 + 네트워크 한 번에 성공 → 장애 안 잡힘.

---

## 3. Kafka 써도 되는 곳 vs 안 되는 곳

> [!danger] 이커머스 핵심은 즉시 일관성 (Eventual이 아닌 Immediate)

```
❌ Kafka 쓰면 안 되는 곳 (실패하면 안 됨)
  주문 생성
  재고 차감
  결제 처리
  환불

✅ Kafka 써도 되는 곳 (실패해도 재시도 가능)
  배송 시작 알림
  이메일 / 푸시
  통계 집계
  정산 배치
```

### 코드 양의 본질

```
Go 10줄   → 문제의 30% 해결
Spring 50줄 → 문제의 90% 해결

나머지 70%를 Go로 채우면
→ 결국 100줄 이상
→ 검증 안 된 직접 구현
```

Spring 보일러플레이트의 정체:
```
@Transactional    ← 누군가 데이터 날린 경험
멱등키            ← 누군가 중복결제 맞은 경험
PG 트랜잭션 밖   ← 누군가 커넥션 풀 고갈 겪은 경험
Outbox Pattern   ← 누군가 이벤트 유실로 고객 돈 날린 경험

더럽게 도배된 게 아니라
10년치 프로덕션 장애 경험이 코드로 굳어진 것
```

---

## 4. 이커머스 실무 정석 구조

### 단일 DB 기준 (Saga 불필요)

> [!tip] Saga는 DB가 분리될 때만 필요
> 단일 DB → @Transactional 하나로 해결
> DB 여러 개, 서비스 여러 개 → Saga 필요

```
@Transactional (짧게 끝냄)
  재고 차감 (Redis atomic DECR)
  주문 상태 = PENDING
  멱등키 저장
커넥션 반납          ← 핵심! PG 대기 전에 반납

PG 호출 (트랜잭션 밖, 2~3초)
  성공 콜백 → 주문 상태 = PAID
  실패 콜백 → 주문 상태 = CANCELLED + 재고 복구
  타임아웃  → 멱등키로 PG 상태 조회 후 결정

Kafka → 배송 / 알림 / 정산 (여기서만 사용)
```

### PG를 트랜잭션 밖에 두는 이유

```
PG를 트랜잭션 안에 넣으면
  커넥션 획득 → PG 대기 2~3초 → 커넥션 반납

커넥션 풀 20개 + 동시 주문 20명
→ 커넥션 20개 전부 PG 기다리는 중
→ 21번째 요청 → 커넥션 없음 → 장애

PG를 트랜잭션 밖에 두면
  커넥션 획득 → 재고/주문 저장 0.001초 → 커넥션 반납
  PG 대기 2~3초 (커넥션 없이)
→ 동시 2000명도 가능
```

---

## 5. 핵심 결론

> 짧고 보기 좋은 Go Saga 코드보다
> 더럽게 도배된 Spring @Transactional이 **돈을 지킨다**.

```
코드가 짧다 = 문제를 덜 풀었다 일 가능성을 항상 의심할 것

부하테스트 통과 ≠ 데이터 정합성 보장
k6는 처리량을 보여주고, 장애는 엣지케이스에서 터진다

Saga, Outbox, 분산 트랜잭션은 원래 복잡한 문제
복잡도는 어딘가에 반드시 존재하고
Go는 그걸 개발자한테 떠넘기는 구조
```

### 기술 선택 기준

| 상황 | 선택 |
|------|------|
| DB 하나, 빠른 개발 | Go + 트랜잭션 직접 관리 |
| DB 하나, 이커머스 | Spring + @Transactional |
| DB 여러 개, MSA | Spring + Saga + Outbox |
| 배송/알림/통계 | Kafka (어디서든 OK) |

---
목업은 언제나 이상적인 면만 보여준다. 실제 운영환경의 괴리감은 파고들어야 해결 가능하다!