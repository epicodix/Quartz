---
title: hamster_locally API 레퍼런스
tags:
  - hamster_locally
  - fastapi
  - api
  - korea-travel
date: 2026-04-04
category: 2_기술_분석
status: 완성
---

# 🗺️ hamster_locally API 레퍼런스

## 📑 목차
- [[#1. 기본 정보|기본 정보]]
- [[#2. 공통 응답 스키마|공통 응답 스키마]]
- [[#3. 엔드포인트 목록|엔드포인트 목록]]
- [[#4. 요청 예시 (curl)|요청 예시]]

---

## 1. 기본 정보

| 항목 | 값 |
|------|----|
| Base URL | `https://epix-macbookair.tail561905.ts.net` |
| 포트 | 443 (Tailscale serve → localhost:8100) |
| 문서 (Swagger) | `/docs` |
| 지원 언어 | `ko` `en` `zh` `ja` |
| 카테고리 | `food` `transport` `manner` `daily` `hospital` `place` `shopping` |

---

## 2. 공통 응답 스키마

### AIResponse

AI가 생성하는 구조화 응답. `/search`와 `/chat` 모두 이 형태로 반환.

```json
{
  "title":      "How to Call a Waiter",
  "answer":     "In Korea, it's normal to call out loud...",
  "tips_used":  ["FOO001", "FOO003"],
  "confidence": "high",
  "follow_up":  ["Do I need to tip?", "Can I pay by card?"]
}
```

| 필드 | 타입 | 설명 |
|------|------|------|
| `title` | string | 카드 헤더용 타이틀. 대화형 턴은 빈 문자열 |
| `answer` | string | 메인 답변 텍스트 |
| `tips_used` | string[] | AI가 근거로 선택한 팁 ID 목록 |
| `confidence` | string | `high` / `medium` / `low` |
| `follow_up` | string[] | 후속 질문 제안 (2-3개) |

> [!note] confidence 기준
> - **high**: 팁 인덱스가 질문에 직접 대응
> - **medium**: 부분 매칭, 추론 포함
> - **low**: 매칭 팁 없음, Gemini 일반 지식으로 답변

---

### TipResponse

팁 단건 데이터. `/tips`, `/search` 응답에 포함.

```json
{
  "id":             "FOO001",
  "category":       "food",
  "situation":      "You've just been served a bubbling hot bowl...",
  "action":         "Add a little bit of the salted shrimp...",
  "why":            "This is part of Korea's haejang culture...",
  "foreigner_trap": "That earthenware pot is incredibly hot...",
  "solutions": {
    "primary":     "Slowly add the salted shrimp to adjust seasoning...",
    "fallback":    "If you're not keen on mixing the rice in...",
    "last_resort": "If you run out of salted shrimp..."
  },
  "lang":  "en",
  "score": null
}
```

| 필드 | 타입 | 설명 |
|------|------|------|
| `id` | string | 팁 ID (예: `FOO001`, `TRA002`) |
| `category` | string | 카테고리 |
| `situation` | string | 상황 설명 |
| `action` | string | 권장 행동 |
| `why` | string | 이유 설명 |
| `foreigner_trap` | string | 외국인이 자주 하는 실수 |
| `solutions.primary` | string | 1차 해결책 |
| `solutions.fallback` | string | 2차 해결책 |
| `solutions.last_resort` | string | 최후 수단 |
| `lang` | string | 응답 언어 |
| `score` | float\|null | 검색 관련도 점수 (검색 시만 사용) |

---

## 3. 엔드포인트 목록

### GET /health

서버 상태 확인.

**응답**
```json
{
  "status":    "ok",
  "tip_count": 103,
  "langs":     ["en", "zh", "ja"]
}
```

---

### GET /tips

전체 팁 목록 조회.

**쿼리 파라미터**

| 파라미터 | 타입 | 기본값 | 설명 |
|----------|------|--------|------|
| `lang` | string | `ko` | 응답 언어 |
| `category` | string | - | 카테고리 필터 (선택) |

**응답**: `TipResponse[]`

---

### GET /tips/{tip_id}

팁 단건 조회.

**경로 파라미터**

| 파라미터 | 설명 |
|----------|------|
| `tip_id` | 팁 ID (예: `FOO001`) |

**쿼리 파라미터**

| 파라미터 | 기본값 | 설명 |
|----------|--------|------|
| `lang` | `ko` | 응답 언어 |

**응답**: `TipResponse`

---

### GET /daily

오늘의 팁 (날짜 기반 고정 픽).

**쿼리 파라미터**

| 파라미터 | 기본값 | 설명 |
|----------|--------|------|
| `lang` | `ko` | 응답 언어 |

**응답**
```json
{
  "date":     "2026-04-04",
  "category": "food",
  "tip":      { /* TipResponse */ }
}
```

---

### POST /search

자연어 검색. AI가 전체 팁 인덱스에서 직접 관련 팁을 선택하고 구조화 답변 생성.

**요청 바디**

```json
{
  "query":    "how do I call a waiter?",
  "lang":     "en",
  "category": null,
  "top_k":    3
}
```

| 필드 | 타입 | 기본값 | 설명 |
|------|------|--------|------|
| `query` | string | 필수 | 자연어 질문 |
| `lang` | string | `ko` | 응답 언어 |
| `category` | string\|null | null | 카테고리 범위 제한 (선택) |
| `top_k` | int | 3 | 최대 팁 반환 수 |

**응답**

```json
{
  "query":      "how do I call a waiter?",
  "lang":       "en",
  "ai": {
    "title":      "Calling Staff at Korean Restaurants",
    "answer":     "Hey! Most Korean restaurants have a call bell...",
    "tips_used":  ["FOO003", "FOO010"],
    "confidence": "high",
    "follow_up":  ["Do I need to tip?", "How do I pay the bill?"]
  },
  "tips":       [ /* tips_used 기반 TipResponse[] */ ],
  "latency_ms": 3918
}
```

---

### POST /chat

다중턴 대화. 세션 기반 히스토리 유지.

> [!info] 팁 매칭 분기
> - 키워드 매칭 팁 있음 → 구조화 AIResponse (title, follow_up 포함)
> - 팁 매칭 없음 → 단일 프롬프트 대화 모드 (answer만, title 빈 문자열)

**요청 바디**

```json
{
  "message":    "Are you looking for something spicy or mild?",
  "session_id": "uuid-string",
  "lang":       "en",
  "category":   null
}
```

| 필드 | 타입 | 기본값 | 설명 |
|------|------|--------|------|
| `message` | string | 필수 | 사용자 메시지 |
| `session_id` | string\|null | null | 없으면 새 세션 자동 생성 |
| `lang` | string | `ko` | 응답 언어 |
| `category` | string\|null | null | 팁 컨텍스트 카테고리 제한 |

**응답**

```json
{
  "session_id": "550e8400-e29b-41d4-a716-446655440000",
  "ai": {
    "title":      "",
    "answer":     "If you like it spicy, go for budae-jjigae...",
    "tips_used":  [],
    "confidence": "medium",
    "follow_up":  []
  },
  "lang": "en"
}
```

---

### DELETE /chat/{session_id}

세션 히스토리 초기화.

**응답**
```json
{ "status": "reset", "session_id": "..." }
```

---

### GET /translate/status

언어별 번역 캐시 현황.

**응답**
```json
{
  "total_tips": 103,
  "langs": {
    "en": { "done": 103, "total": 103, "missing": 0, "pct": 100.0 },
    "zh": { "done": 103, "total": 103, "missing": 0, "pct": 100.0 },
    "ja": { "done": 103, "total": 103, "missing": 0, "pct": 100.0 }
  }
}
```

---

## 4. 요청 예시 (curl)

### 헬스 체크
```bash
curl https://epix-macbookair.tail561905.ts.net/health
```

### 팁 목록 (영어)
```bash
curl "https://epix-macbookair.tail561905.ts.net/tips?lang=en&category=food"
```

### 팁 단건 조회
```bash
curl "https://epix-macbookair.tail561905.ts.net/tips/FOO001?lang=ja"
```

### AI 검색
```bash
curl -X POST "https://epix-macbookair.tail561905.ts.net/search" \
  -H "Content-Type: application/json" \
  -d '{"query": "how do I call a waiter?", "lang": "en"}'
```

### 오늘의 팁
```bash
curl "https://epix-macbookair.tail561905.ts.net/daily?lang=zh"
```

### 다중턴 대화 시작
```bash
curl -X POST "https://epix-macbookair.tail561905.ts.net/chat" \
  -H "Content-Type: application/json" \
  -d '{"message": "What should I eat near Gyeongbokgung?", "lang": "en"}'
```

### 대화 이어가기
```bash
curl -X POST "https://epix-macbookair.tail561905.ts.net/chat" \
  -H "Content-Type: application/json" \
  -d '{
    "message":    "I prefer spicy food",
    "session_id": "550e8400-e29b-41d4-a716-446655440000",
    "lang":       "en"
  }'
```

### 세션 초기화
```bash
curl -X DELETE "https://epix-macbookair.tail561905.ts.net/chat/550e8400-e29b-41d4-a716-446655440000"
```
