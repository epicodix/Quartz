---
title: EPIX Card - 네트워킹 플랫폼 전체 설계
tags:
  - epix-card
  - networking
  - firestore
  - mcp
  - golang
  - react
  - fcm
  - vector-search
date: 2026-03-16
status: 설계중
priority: 높음
---

# EPIX Card - 네트워킹 플랫폼 전체 설계

## 목차
- [[#서비스 비전|서비스 비전]]
- [[#전체 아키텍처|전체 아키텍처]]
- [[#가중치 체계|가중치 체계]]
- [[#Firestore 데이터 설계|Firestore 데이터 설계]]
- [[#백엔드 API 설계|백엔드 API 설계]]
- [[#MCP 서버 설계|MCP 서버 설계]]
- [[#FCM Web Push 설계|FCM Web Push 설계]]
- [[#벡터 임베딩 설계|벡터 임베딩 설계]]
- [[#보안 설계|보안 설계]]
- [[#Phase 로드맵|Phase 로드맵]]

---

## 서비스 비전

> 명함 = 개인정보 + 네트워킹 자산
> 단순한 명함 공유를 넘어, AI가 관계를 분석하고 최적의 네트워크를 제안하는 플랫폼

```
비로그인 사용자  →  명함 열람 (연락처 마스킹)
로그인 사용자    →  연락처 확인, 명함 저장, 관계 형성
AI (MCP)        →  네트워크 분석, 연결 추천, 관계도 측정
```

---

## 가중치 체계

> [!note] 핵심 원칙
> 클릭 기반 가중치가 아닌 **상호작용의 질과 신뢰 수준**으로 측정
> 정적 가중치는 백엔드 저장, 동적 보정(응답률/응답속도/시간 감쇠)은 MCP 서버에서 계산

### 1. 관계 형성

| 타입 | 가중치 | 비고 |
|------|--------|------|
| `view` | 1 | 프로필 열람 |
| `share_copy` | 2 | 공유 링크 복사 |
| `card_received` | 3 | 명함 수신만 |
| `push_enabled` | 3 | 웹푸시 허용 = 연락 받을 의지 |
| `push_click` | 4 | 푸시 알림 클릭 |
| `contact_save` / `vcard_download` | 5 | 연락처 저장 |
| `qr_scan` | 5 | QR 스캔 = 오프라인 만남 증거 |
| `memo_added` | 6 | 메모/태그 추가 |
| `mutual_exchange` | **15** | 상호 명함 교환 핵심 이벤트 |
| `linkedin_click` / `remember_click` | 2 | 클릭 기반 (낮음) |
| `contact_phone` / `contact_email` | 1 | 클릭 발생 빈도 낮음 |

### 2. 메시징

| 타입 | 가중치 | 비고 |
|------|--------|------|
| `message_first` | 5 | 관계 시작 의지 |
| `message_reply` | 8 | 양방향 대화 성립 |
| `conv_deep` | 12 | 3회 이상 왕복 |
| `message_no_reply` | **-2** | 관계 약화 신호 |

**동적 보정 (MCP 계산)**
```
응답률 보정:  ≥80% → ×1.3 / ≥50% → ×1.0 / ≥20% → ×0.7 / 그 이하 → ×0.3
응답속도 보정: ≤10분 → ×1.5 / ≤1시간 → ×1.2 / ≤24시간 → ×1.0 / 초과 → ×0.8
```

### 3. AI / MCP

| 타입 | 가중치 | 신뢰 수준 |
|------|--------|----------|
| `ai_recommend_accept` | 10 | medium |
| `calendar_share` | 15 | high |
| `document_share` | 18 | high |
| `intro_accept` | 20 | high |
| `project_create` | **25** | high |

### 4. 관계 티어

| 티어 | 점수 범위 | 의미 |
|------|---------|------|
| `weak` | ~14 | 약한 연결 |
| `normal` | 15~39 | 일반 관계 |
| `strong` | 40~79 | 강한 관계 |
| `close` | 80+ | 긴밀한 관계 |

---

## 전체 아키텍처

```
┌─────────────────────────────────────────────────────┐
│                   React 프론트엔드                    │
│  명함 뷰어 / 에디터 / 내 네트워크 / 알림              │
└────────────────────┬────────────────────────────────┘
                     │ HTTPS + Bearer Token
┌────────────────────▼────────────────────────────────┐
│              Go + Fiber 백엔드 API                    │
│  /api/card   /api/network   /api/notify              │
│  Firebase Admin SDK (토큰 검증 + Firestore Write)    │
└──────┬──────────────┬───────────────────────────────┘
       │              │
┌──────▼──────┐ ┌─────▼──────────────────────────────┐
│  Firestore  │ │         Cloud Functions              │
│  (데이터)   │ │  임베딩 생성 / 관계도 계산 / 알림     │
└──────┬──────┘ └─────┬──────────────────────────────┘
       │              │
┌──────▼──────────────▼──────────────────────────────┐
│                 MCP 서버 (Go)                         │
│  Claude가 도구로 연결 → 네트워크 분석 / 추천           │
└─────────────────────────────────────────────────────┘
                     │
┌────────────────────▼────────────────────────────────┐
│              FCM (Firebase Cloud Messaging)           │
│  Web Push → 열람 알림 / 연결 요청 / 메시지            │
└─────────────────────────────────────────────────────┘
```

---

## Firestore 데이터 설계

### 컬렉션 구조 전체

```
firestore/
├── cards/{cardId}
├── users/{uid}
│   ├── savedCards/{cardId}
│   └── fcmTokens/{tokenId}
├── views/{viewId}
├── connections/{connectionId}
└── messages/{threadId}
    └── messages/{msgId}
```

---

### cards/{cardId}

명함 문서. 기존 구조 유지 + ownerId, embedding 추가.

```javascript
{
  // 기존 필드
  shortId: "AbCdEf",
  cardData: {
    details: {
      name: "홍길동",
      title: "소프트웨어 엔지니어",
      company: "EPIX",
      email: "gildong@epix.kr",      // Phase 2에서 암호화
      phone: "010-1234-5678",        // Phase 2에서 암호화
      website: "epix.kr",
      sns: "instagram.com/epix",
      address: "서울시 강남구"
    },
    displayOptions: { ... }
  },
  designState: { ... },
  viewCount: 42,
  createdAt: Timestamp,

  // 신규 필드
  ownerId: "firebase-uid",           // "legacy" = 마이그레이션된 구 데이터
  embedding: [0.12, -0.34, ...],    // 768차원 텍스트 임베딩 벡터
  updatedAt: Timestamp
}
```

---

### users/{uid}

사용자 프로필 + 설정.

```javascript
{
  uid: "firebase-uid",
  displayName: "홍길동",
  email: "gildong@epix.kr",
  photoURL: "https://...",
  createdAt: Timestamp,
  lastSeenAt: Timestamp,

  // 네트워킹 관련
  primaryCardId: "AbCdEf",          // 대표 명함
  networkCount: 12,                  // 연결된 사람 수
  totalViews: 120,                   // 내 명함 총 열람 수

  // 알림 설정
  notifyOnView: true,               // 내 명함 열람 시 알림
  notifyOnConnection: true,         // 새 연결 시 알림
  notifyOnMessage: true             // 메시지 수신 시 알림
}
```

---

### users/{uid}/savedCards/{cardId}

내가 저장한 명함 (단방향 관심).

```javascript
{
  cardId: "AbCdEf",
  cardOwnerId: "other-uid",
  savedAt: Timestamp,
  memo: "AWS 리인벤트에서 만남",     // 사용자 메모
  tags: ["개발자", "클라우드"],      // 분류 태그
  lastContactedAt: Timestamp         // 마지막 연락 시점
}
```

---

### users/{uid}/fcmTokens/{tokenId}

Web Push 토큰. 멀티 디바이스 지원.

```javascript
{
  token: "fcm-registration-token",
  deviceType: "web",                // "web" | "android" | "ios"
  createdAt: Timestamp,
  lastActiveAt: Timestamp
}
```

---

### views/{viewId}

명함 열람 로그. 단방향 기록.

```javascript
{
  cardId: "AbCdEf",
  cardOwnerId: "owner-uid",
  viewerUid: "viewer-uid",          // null = 비로그인
  viewerAnonymousId: "device-xxx",  // 비로그인 식별용 (localStorage)
  viewedAt: Timestamp,
  source: "share_link"              // "share_link" | "qr_code" | "search"
}
```

> [!note] 비로그인 처리
> 비로그인 사용자는 localStorage의 anonymousId로 중복 집계를 방지.
> 개인 식별은 불가능하지만 동일 기기 재방문 감지 가능.

---

### connections/{connectionId}

상호 교환 연결. connectionId = uid1_uid2 (알파벳 정렬로 고정).

```javascript
{
  uids: ["uid-a", "uid-b"],         // 항상 정렬된 순서
  initiatorUid: "uid-a",            // 먼저 저장한 쪽
  connectedAt: Timestamp,           // 상호 저장 완료 시점
  strength: 3,                      // 관계 강도 (교류 횟수 기반)
  lastInteractionAt: Timestamp,

  // 각자의 메모 (상대방에게 비공개)
  memos: {
    "uid-a": "컨퍼런스에서 만난 개발자",
    "uid-b": "EPIX 팀 분"
  }
}
```

> [!note] 연결 조건
> 양쪽이 서로의 명함을 savedCards에 저장했을 때 자동으로 connection 문서 생성.
> Cloud Function 트리거로 처리.

---

### messages/{threadId}

메시지 스레드. threadId = connection connectionId와 동일.

```javascript
// 스레드 문서
{
  participants: ["uid-a", "uid-b"],
  lastMessage: "안녕하세요!",
  lastMessageAt: Timestamp,
  unreadCount: {
    "uid-a": 0,
    "uid-b": 1
  }
}

// messages/{threadId}/messages/{msgId}
{
  senderUid: "uid-a",
  text: "안녕하세요!",
  sentAt: Timestamp,
  readAt: Timestamp               // null = 미읽음
}
```

---

## 백엔드 API 설계

### 엔드포인트 목록

```
인증 불필요
  GET  /api/card/:shortId              명함 조회 (연락처 마스킹)
  POST /api/view/:cardId               열람 로그 기록

인증 필요 (Bearer Token)
  POST /api/card                       명함 생성
  PUT  /api/card/:cardId               명함 수정
  DELETE /api/card/:cardId             명함 삭제

  GET  /api/my/cards                   내 명함 목록
  GET  /api/my/network                 내 연결 목록
  GET  /api/my/views                   내 명함 열람 로그
  GET  /api/my/savedCards              저장한 명함 목록
  POST /api/my/savedCards/:cardId      명함 저장 (→ connection 트리거)
  DELETE /api/my/savedCards/:cardId    저장 취소

  GET  /api/messages/:threadId         메시지 목록
  POST /api/messages/:threadId         메시지 전송

  POST /api/fcm/register               FCM 토큰 등록
```

---

## MCP 서버 설계

Claude Desktop / Claude Code에서 연결하는 MCP 서버.
Go로 구현, Firestore에 직접 접근.

### 제공 도구 (Tools)

```
도구                      설명
──────────────────────────────────────────────────────
get_my_network            내 연결 목록 + 관계 강도
get_view_history          내 명함을 본 사람 목록
recommend_connections     벡터 유사도 기반 추천 (직군/관심사)
analyze_relationship      특정 uid와의 관계 강도 분석
get_network_graph         전체 관계도 (노드/엣지 데이터)
search_cards              키워드 + 벡터 하이브리드 검색
send_push_notification    특정 사용자에게 웹푸시 전송
```

### MCP 서버 구조 (Go)

```
mcp-server/
├── main.go              # MCP 프로토콜 핸들러
├── tools/
│   ├── network.go       # get_my_network, analyze_relationship
│   ├── recommend.go     # recommend_connections (벡터 검색)
│   ├── search.go        # search_cards
│   └── notify.go        # send_push_notification
├── firestore/
│   └── client.go        # Firestore 연결
└── config/
    └── config.go        # 환경변수
```

### 사용 예시

```
사용자: "나랑 비슷한 직군 개발자 추천해줘"
Claude → recommend_connections(uid, limit=5)
       → 벡터 유사도 상위 5명 반환
       → "서울에서 활동하는 클라우드 엔지니어 3분을 추천드려요..."

사용자: "이번 달 내 명함 누가 봤어?"
Claude → get_view_history(uid, period="this_month")
       → 로그인 사용자 열람 목록 반환
       → "로그인 사용자 7명이 명함을 확인했어요. 그 중 2명은..."
```

---

## FCM Web Push 설계

Firebase에 이미 포함된 FCM 활용. 추가 비용 없음.

### 알림 종류

```
이벤트                  알림 내용
──────────────────────────────────────────────────────
명함 열람 (로그인 유저)  "홍길동님이 내 명함을 확인했습니다"
상호 연결 완료          "김철수님과 연결되었습니다!"
메시지 수신             "홍길동: 안녕하세요!"
연결 추천               "AI가 새 연결을 추천합니다"
```

### 프론트엔드 FCM 설정

```javascript
// public/firebase-messaging-sw.js (Service Worker)
importScripts('https://www.gstatic.com/firebasejs/10.x.x/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.x.x/firebase-messaging-compat.js');

firebase.initializeApp({ ... });
const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  self.registration.showNotification(payload.notification.title, {
    body: payload.notification.body,
    icon: '/logo192.png'
  });
});
```

### 백엔드 FCM 전송 (Go)

```go
// Admin SDK로 FCM 메시지 전송
message := &messaging.Message{
  Token: fcmToken,
  Notification: &messaging.Notification{
    Title: "새 연결!",
    Body:  "홍길동님과 연결되었습니다.",
  },
  Data: map[string]string{
    "type":   "new_connection",
    "uid":    targetUid,
  },
}
```

---

## 벡터 임베딩 설계

명함 정보를 텍스트로 변환 → 임베딩 → Firestore Vector Field에 저장.

### 임베딩 입력 텍스트 구성

```
"{name} {title} {company} {website} {address}"
예: "홍길동 소프트웨어 엔지니어 EPIX epix.kr 서울 강남구"
```

### Cloud Function 트리거

```
cards 문서 생성/수정 시 자동 트리거
  → Vertex AI Embedding API 호출 (text-embedding-004)
  → 768차원 벡터 반환
  → cards/{cardId}.embedding 필드에 저장
```

### 벡터 검색 쿼리 (Firestore Vector Search)

```go
// 유사한 명함 검색
query := client.Collection("cards").
  FindNearest("embedding", queryVector, 10,
    firestore.DistanceMeasureCosineSimilarity, nil)
```

---

## 보안 설계

### Firestore Security Rules (최종)

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    match /cards/{cardId} {
      allow get: if true;
      allow list: if false;
      allow create: if request.auth != null
                    && request.resource.data.ownerId == request.auth.uid;
      allow update, delete: if request.auth != null
                             && resource.data.ownerId == request.auth.uid;
    }

    match /users/{uid} {
      allow read, write: if request.auth != null
                         && request.auth.uid == uid;
    }

    match /users/{uid}/savedCards/{cardId} {
      allow read, write: if request.auth != null
                         && request.auth.uid == uid;
    }

    match /users/{uid}/fcmTokens/{tokenId} {
      allow read, write: if request.auth != null
                         && request.auth.uid == uid;
    }

    match /views/{viewId} {
      // 쓰기: 서버(Admin SDK)만 가능
      allow read: if request.auth != null
                  && request.auth.uid == resource.data.cardOwnerId;
      allow write: if false;
    }

    match /connections/{connectionId} {
      // 본인이 포함된 연결만 읽기 가능
      allow read: if request.auth != null
                  && request.auth.uid in resource.data.uids;
      allow write: if false; // Cloud Function만 생성
    }

    match /messages/{threadId} {
      allow read, write: if request.auth != null
                         && request.auth.uid in resource.data.participants;

      match /messages/{msgId} {
        allow read, write: if request.auth != null
                           && request.auth.uid in
                              get(/databases/$(database)/documents/messages/$(threadId)).data.participants;
      }
    }
  }
}
```

### 개인정보 처리 방침

| 데이터 | 처리 방식 | 보존 기간 |
|--------|----------|----------|
| 이름/회사/직책 | 평문 (공개 정보) | 계정 삭제 시까지 |
| 이메일/전화 | Phase 2에서 CSE 암호화 | 계정 삭제 시까지 |
| 열람 로그 | 비로그인 anonymousId 수집 없음 | 1년 후 자동 삭제 |
| FCM 토큰 | 서버에 암호화 저장 | 비활성 90일 후 삭제 |
| IP 주소 | 수집 안 함 (기존 데이터 삭제 완료) | - |

---

## Phase 로드맵

### Phase 1 - 열람 로그 + 저장 기능 (현재)
- [ ] `views` 컬렉션 로그 기록 API
- [ ] `savedCards` 저장/취소 API
- [ ] React: 저장 버튼 UI
- [ ] React: 내 명함 열람 현황 페이지

### Phase 2 - 연결 + 메시지
- [ ] Cloud Function: 상호 저장 → connection 자동 생성
- [ ] 메시지 API + React 채팅 UI
- [ ] FCM Web Push 연동
- [ ] React: 내 네트워크 페이지

### Phase 3 - 벡터 임베딩 + 추천
- [ ] Cloud Function: 명함 생성 시 임베딩 자동 생성
- [ ] Firestore Vector Index 설정
- [ ] 유사 명함 추천 API

### Phase 4 - MCP 서버
- [ ] MCP 서버 Go 구현
- [ ] 도구: get_my_network, recommend_connections
- [ ] 도구: analyze_relationship, get_network_graph
- [ ] Claude Desktop 연동 테스트

### Phase 5 - CSE 암호화 (보안 강화)
- [ ] Web Crypto API + AES-256-GCM
- [ ] PBKDF2 키 유도
- [ ] 서버는 암호문만 저장

---

## 현재 구현 완료

- [x] Firebase Auth (Email/Password + Google OAuth)
- [x] React AuthContext + LoginModal
- [x] Go 백엔드 Firebase ID Token 검증 미들웨어
- [x] Firestore Security Rules 배포
- [x] 기존 데이터 마이그레이션 (ownerId 추가, clientIp 삭제)
