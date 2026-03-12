---
title: 뽀시래기 이커머스 API 명세
date: 2026-03-05
status: 진행중
---

# 뽀시래기 이커머스 API 명세

> Base URL: `http://localhost:8081` (로컬) / 배포 후 변경 예정
> Content-Type: `application/json`
> 인증 방식: JWT Bearer Token

---

## 공통 응답 형식

```json
{
  "status": 200,
  "success": true,
  "data": { ... },
  "error": null
}
```

실패 시:
```json
{
  "status": 400,
  "success": false,
  "data": null,
  "error": {
    "code": "에러코드",
    "message": "에러 메시지"
  }
}
```

---

## 1. 인증 (Auth)

### 로그인
```
POST /api/v1/auth/login
```

Request:
```json
{
  "email": "user@example.com",   // 필수
  "password": "password123"      // 필수
}
```

Response:
```json
{
  "status": 200,
  "success": true,
  "data": {
    "accessToken": "eyJhbGci...",
    "refreshToken": "eyJhbGci...",
    "tokenType": "Bearer"
  }
}
```

---

### 로그아웃
```
POST /api/v1/auth/logout
```

Request:
```json
{
  "refreshToken": "eyJhbGci..."
}
```

Response:
```json
{
  "status": 200,
  "success": true,
  "data": null
}
```

---

## 2. 회원 (User)

### 회원가입
```
POST /api/v1/users
```

Request:
```json
{
  "email": "user@example.com",   // 필수
  "password": "password123",     // 필수
  "name": "홍길동",              // 필수, 2~20자
  "nickname": "길동이",          // 선택
  "phoneNumber": "010-1234-5678" // 필수
}
```

Response:
```json
{
  "status": 200,
  "success": true,
  "data": {
    "id": 1,
    "nickname": "길동이",
    "profileImageUrl": null
  }
}
```

---

### 회원 조회
```
GET /api/v1/users/{id}
Authorization: Bearer {accessToken}
```

Response:
```json
{
  "status": 200,
  "success": true,
  "data": {
    "id": 1,
    "nickname": "길동이",
    "profileImageUrl": null
  }
}
```

---

## 3. 배송지 (Address)

> 모든 배송지 API는 로그인 필요
> Header: `Authorization: Bearer {accessToken}`

### 배송지 목록 조회
```
GET /api/v1/users/me/addresses
```

Response:
```json
{
  "status": 200,
  "success": true,
  "data": [
    {
      "id": "tsid값",
      "recipientName": "홍길동",
      "phoneNumber": "010-1234-5678",
      "secondaryPhoneNumber": null,
      "zipCode": "12345",
      "baseAddress": "서울시 강남구",
      "detailAddress": "101호",
      "requestMessage": "문 앞에 놔주세요",
      "isDefault": true,
      "lastUsedAt": "2026-03-05T10:00:00"
    }
  ]
}
```

---

### 배송지 등록
```
POST /api/v1/users/me/addresses
```

Request:
```json
{
  "recipientName": "홍길동",        // 필수, 2~20자
  "phoneNumber": "010-1234-5678",   // 필수
  "secondaryPhoneNumber": null,     // 선택
  "zipCode": "12345",               // 필수, 5자리 숫자
  "baseAddress": "서울시 강남구",   // 필수
  "detailAddress": "101호",         // 선택, 최대 100자
  "requestMessage": "문 앞에",      // 선택, 최대 255자
  "isDefault": true                 // 선택
}
```

---

### 배송지 수정
```
PUT /api/v1/users/me/addresses/{addressId}
```

Request: 배송지 등록과 동일

---

### 배송지 삭제
```
DELETE /api/v1/users/me/addresses/{addressId}
```

Response:
```json
{
  "status": 200,
  "success": true,
  "data": null
}
```

---

## 구현 현황

| 도메인 | 엔드포인트 | 상태 |
|--------|-----------|------|
| 인증 | 로그인, 로그아웃 | 완료 |
| 회원 | 회원가입, 회원조회 | 완료 |
| 배송지 | CRUD | 완료 |
| 상품 | - | 미구현 |
| 주문/결제 | - | 미구현 |
| 타임딜 | - | 미구현 |

> Swagger UI: `http://localhost:8081/swagger-ui/index.html`
