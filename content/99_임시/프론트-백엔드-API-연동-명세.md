---
title: 프론트-백엔드 API 연동 명세
date: 2026-03-05
status: 긴급
---

# 프론트-백엔드 API 연동 명세

> 프론트엔드 Mock 데이터 기준으로 작성
> 백엔드는 이 응답 형식에 맞춰 구현하면 프론트 수정 최소화 가능

---

## 1. 타임딜 목록 조회

```
GET /api/timedeals
```

Response:
```json
[
  {
    "id": 1,
    "productName": "수의사가 직접 설계한 유기농 강아지 사료 2kg",
    "productImage": "https://이미지URL",
    "images": [
      "https://이미지URL1",
      "https://이미지URL2"
    ],
    "features": [
      "100% 유기농 인증 원료만 사용",
      "수의사 10인 공동 설계"
    ],
    "originalPrice": 50000,
    "discountPrice": 25000,
    "discountRate": 50,
    "stock": 51,
    "totalStock": 100,
    "startTime": "2026-03-05T10:00:00.000Z",
    "endTime": "2026-03-05T11:00:00.000Z",
    "status": "ACTIVE"
  }
]
```

status 값:
- `ACTIVE`   → 진행 중
- `UPCOMING` → 예정
- `SOLDOUT`  → 품절

---

## 2. 타임딜 상세 조회

```
GET /api/timedeals/{id}
```

Response: 목록 조회의 단일 객체와 동일

---

## 3. 주문 생성

```
POST /api/orders
```

Request:
```json
{
  "timedealId": 1,
  "quantity": 1
}
```

Response:
```json
{
  "orderId": "order-001",
  "timedealId": 1,
  "productName": "상품명",
  "quantity": 1,
  "totalPrice": 25000,
  "status": "PENDING",
  "createdAt": "2026-03-05T10:00:00.000Z"
}
```

재고 소진 시:
```json
{
  "status": 409,
  "success": false,
  "error": {
    "code": "SOLD_OUT",
    "message": "재고가 소진되었습니다."
  }
}
```

---

## 4. 주문 상태 조회

```
GET /api/orders/{orderId}
```

Response:
```json
{
  "orderId": "order-001",
  "timedealId": 1,
  "productName": "상품명",
  "quantity": 1,
  "totalPrice": 25000,
  "status": "COMPLETED",
  "failReason": null,
  "createdAt": "2026-03-05T10:00:00.000Z"
}
```

status 값:
- `PENDING`   → 결제 대기
- `COMPLETED` → 결제 완료
- `FAILED`    → 결제 실패

실패 시 failReason 예시: `"재고 소진"`, `"잔액 부족"`, `"결제 승인 거절"`

---

---

## 5. 타임딜 등록 (관리자)

```
POST /api/timedeals
```

Request:
```json
{
  "productName": "상품명 | 부제목",
  "originalPrice": 50000,
  "discountPrice": 25000,
  "stock": 100,
  "totalStock": 100,
  "startTime": "2026-03-05T10:00:00.000Z",
  "endTime": "2026-03-05T11:00:00.000Z",
  "status": "UPCOMING",
  "images": ["https://이미지URL1", "https://이미지URL2"],
  "description": "상품 설명",
  "tags": ["강아지", "간식"]
}
```

Response: 생성된 타임딜 단일 객체 (목록 조회의 단일 객체와 동일 + id 포함)

---

## 6. 타임딜 수정 (관리자)

```
PUT /api/timedeals/{id}
```

Request: POST와 동일한 구조 (변경할 필드만 포함해도 OK)

Response: 수정된 타임딜 단일 객체

---

## 7. 타임딜 삭제 (관리자)

```
DELETE /api/timedeals/{id}
```

Response: 204 No Content (body 없음)

---

## 주의사항

- 모든 응답은 배열/객체 직접 반환 (공통 래퍼 불필요)
- 타임딜 목록은 `startTime` 기준 정렬 권장
- `stock`은 실시간 Redis 재고 반영
- `discountRate`는 백엔드에서 계산해서 내려줄 것
  - 계산식: `round((1 - discountPrice / originalPrice) * 100)`
- 관리자 API (POST/PUT/DELETE /api/timedeals)는 인증 토큰 필수
  - Header: `Authorization: Bearer {accessToken}`
  - 권한 없을 시 403 Forbidden 반환
