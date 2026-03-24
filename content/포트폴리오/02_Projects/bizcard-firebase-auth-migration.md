---
title: Bizcard Service - Firebase Auth 마이그레이션 계획
tags:
  - bizcard
  - firebase
  - auth
  - migration
  - golang
  - react
date: 2026-03-16
status: 진행중
priority: 높음
---

# 🎯 Bizcard Firebase Auth 마이그레이션

## 📑 목차
- [[#현재 상태|현재 상태]]
- [[#마이그레이션 목표|목표]]
- [[#Step 1. Firebase Auth 활성화|Step 1]]
- [[#Step 2. React Firebase SDK 연결|Step 2]]
- [[#Step 3. Go 백엔드 토큰 검증|Step 3]]
- [[#Step 4. Firestore Rules 업데이트|Step 4]]
- [[#Step 5. 기존 데이터 마이그레이션|Step 5]]
- [[#추후 로드맵|추후 로드맵]]

---

## 현재 상태

> [!warning] 보안 이슈
> shortId만 알면 Firestore REST API 직접 호출로 phone/email 평문 조회 가능

| 항목 | 현재 |
|------|------|
| 프로젝트 | `bizcard-9d2cf` (GCP, asia-northeast3) |
| 프론트엔드 | React (business-card-generator-v4), Firebase SDK 없음 |
| 백엔드 | Go + Fiber, Admin SDK로 Firestore Write |
| 인증 | 자체 SMTP (스팸 블랙리스트 위험) |
| DB | Firestore `cards` 컬렉션, 데이터 평문 저장 |
| Security Rules | GET 오픈 / LIST 차단 / WRITE 차단 |
| Cloud Functions | 없음 |
| Firebase Hosting | 없음 |

### 현재 Firestore 문서 구조
```
cards/{shortId}
  ├── cardData.details.name       (평문)
  ├── cardData.details.phone      (평문) ← 보호 필요
  ├── cardData.details.email      (평문) ← 보호 필요
  ├── cardData.details.company
  ├── cardData.details.title
  ├── cardData.displayOptions.*
  ├── designState.*
  ├── shortId
  ├── viewCount
  ├── createdAt
  └── clientIp                    ← 개인정보, 수집 재검토 필요
```

---

## 마이그레이션 목표

```
비로그인 사용자  →  이름 / 회사 / 직책만 표시
                    전화번호 저장 원하면 → 로그인 유도

로그인 사용자    →  전체 정보 접근
                    연락처 저장, 명함 생성/관리

개발자 포함 누구도  →  phone / email 평문 조회 불가 (추후 CSE)
```

---

## Step 1. Firebase Auth 활성화

- [ ] Firebase Console → Authentication → 시작하기
- [ ] **Email/Password** 공급자 활성화
- [ ] **Google OAuth** 공급자 활성화
- [ ] 승인된 도메인 추가 (localhost + 실제 도메인)

**소요 시간:** 5분 (Console 작업)

---

## Step 2. React Firebase SDK 연결

- [ ] Firebase SDK 설치
  ```bash
  cd /Users/a1234/epicodix/business-card-generator-v4
  npm install firebase
  ```
- [ ] `src/firebase.js` 생성 (초기화 설정)
- [ ] `src/contexts/AuthContext.js` 생성 (전역 인증 상태)
- [ ] `src/components/LoginModal.js` 생성 (Google + 이메일 로그인 UI)
- [ ] `App.js`에 AuthContext Provider 연결
- [ ] 명함 뷰어에서 로그인 여부에 따라 phone/email 숨김 처리
- [ ] 로그인 버튼 / 내 명함 관리 진입점 추가

**핵심 로직:**
```javascript
// 비로그인: phone/email 마스킹
// 로그인: 전체 표시
const { user } = useAuth()
const showPrivate = !!user
```

---

## Step 3. Go 백엔드 토큰 검증

- [ ] Firebase Admin SDK 추가
  ```bash
  go get firebase.google.com/go/v4
  ```
- [ ] Service Account 키 발급 (Firebase Console → 프로젝트 설정 → 서비스 계정)
- [ ] `middleware/auth.go` 작성 (ID Token 검증)
- [ ] 명함 생성 API에 인증 미들웨어 적용
- [ ] 카드 문서에 `ownerId` (uid) 저장 시작

**검증 흐름:**
```
클라이언트 → Authorization: Bearer {idToken}
Go 서버    → Admin SDK VerifyIDToken()
           → uid 추출 → 요청 처리
```

---

## Step 4. Firestore Security Rules 업데이트

- [ ] Rules 업데이트 및 배포

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /cards/{cardId} {

      // 공개 필드만 비로그인 허용
      allow get: if true;

      // 쓰기는 인증된 사용자 + 본인 카드만
      allow create: if request.auth != null
                    && request.resource.data.ownerId == request.auth.uid;
      allow update, delete: if request.auth != null
                             && resource.data.ownerId == request.auth.uid;
      allow list: if false;
    }

    // 사용자별 private 데이터 (추후 암호화용)
    match /users/{userId} {
      allow read, write: if request.auth != null
                         && request.auth.uid == userId;
    }
  }
}
```

> [!note]
> phone/email 필드 레벨 접근 제어는 Firestore Rules에서 필드 단위로 불가.
> 클라이언트에서 로그인 여부로 표시 여부 결정 + 추후 서버사이드 마스킹 or CSE 적용.

---

## Step 5. 기존 데이터 마이그레이션

- [ ] 마이그레이션 스크립트 작성 (Go)
  - 기존 `cards` 문서에 `ownerId: "legacy"` 필드 추가
  - `clientIp` 필드 삭제 (개인정보)
- [ ] 스크립트 dry-run 검증
- [ ] 실제 적용

```go
// 마이그레이션 대상: ownerId 없는 문서 전체
// 처리: ownerId = "legacy" 설정, clientIp 삭제
```

---

## 추후 로드맵

### Phase 2 - 클라이언트 사이드 암호화 (CSE)
- Web Crypto API로 phone/email 클라이언트 암호화
- 키 = 사용자 비밀번호 기반 PBKDF2 유도
- 서버는 암호문만 저장 → 개발자 포함 평문 조회 불가

### Phase 3 - 1회성 연락처 공유
- 비로그인 사용자가 전화번호 요청 시
- Firestore에 TTL 토큰 생성 (1회용, 10분 만료)
- 토큰 검증 후 1회만 복호화 허용

### Phase 4 - 벡터 임베딩
- 명함 저장 시 Cloud Function 트리거
- 텍스트 → 임베딩 → Firestore Vector Field
- 유사 명함 추천 / AI 네트워킹

---

## 체크리스트 전체

### Step 1 (Console)
- [x] Email/Password Auth 활성화
- [x] Google OAuth 활성화

### Step 2 (React)
- [x] `npm install firebase`
- [x] `src/firebase.js`
- [x] `src/contexts/AuthContext.js`
- [x] `src/components/LoginModal.js`
- [x] App.js 연결
- [x] 명함 뷰어 phone/email 조건부 표시

### Step 3 (Go)
- [x] Admin SDK 추가
- [x] Service Account 키 발급
- [x] `middleware/auth.go`
- [x] 명함 생성 API 인증 적용
- [x] `ownerId` 저장 (Firestore 연동 시 적용 예정)

### Step 4 (Rules)
- [x] Rules 작성
- [x] 배포 및 테스트

### Step 5 (Migration)
- [x] 마이그레이션 스크립트
- [x] dry-run
- [x] 실 적용 + clientIp 삭제
