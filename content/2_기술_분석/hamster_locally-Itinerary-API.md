---
title: hamster_locally Itinerary API 레퍼런스
tags:
  - hamster_locally
  - itinerary
  - fastapi
  - api
date: 2026-04-04
category: 2_기술_분석
status: 완성
---

# 🗺️ Itinerary API 레퍼런스

## 📑 목차
- [[#1. 엔드포인트|엔드포인트]]
- [[#2. 요청 스키마|요청 스키마]]
- [[#3. 응답 스키마|응답 스키마]]
- [[#4. 요청 예시|요청 예시]]
- [[#5. Swagger 문서|Swagger 문서]]

---

## 1. 엔드포인트

| 메서드 | 경로 | 설명 |
|--------|------|------|
| `POST` | `/itinerary` | 여행 일정 생성 |
| `GET` | `/itinerary-preview` | 프리뷰 UI |

---

## 2. 요청 스키마

### ItineraryRequest

```json
{
  "nights":     2,
  "city":       "서울",
  "must_visit": ["경복궁", "광장시장"],
  "focus":      "free",
  "pace":       "relaxed",
  "lang":       "en",
  "provider":   "gemini",
  "food_ctx":   null
}
```

| 필드 | 타입 | 기본값 | 설명 |
|------|------|--------|------|
| `nights` | integer | 필수 | 몇박 (days = nights + 1) |
| `city` | string | 필수 | 도시명 (`서울`, `부산`, `제주`) |
| `must_visit` | string[] | `[]` | 반드시 포함할 명소/식당 |
| `focus` | TravelFocus | 필수 | 여행 중심 |
| `pace` | TravelPace | 필수 | 여행 페이스 |
| `lang` | string | `en` | 응답 언어 (`ko` `en` `zh` `ja`) |
| `provider` | AIProvider | `gemini` | AI 모델 선택 |
| `food_ctx` | FoodContext\|null | `null` | `focus=food`일 때 세부 취향 |

### Enum 값

**TravelFocus**

| 값 | 설명 |
|----|------|
| `food` | 음식 중심 |
| `sightseeing` | 관광 중심 |
| `free` | 자유 탐방 |

**TravelPace**

| 값 | 하루 장소 수 |
|----|------------|
| `relaxed` | 2-3곳 |
| `normal` | 3-4곳 |
| `fast` | 5곳+ |

**AIProvider**

| 값 | 모델 |
|----|------|
| `gemini` | Gemini 2.5 Flash (기본값) |
| `gpt` | GPT-4o |

---

### FoodContext

`focus: "food"` 일 때만 사용.

```json
{
  "styles":        ["michelin", "traditional"],
  "budget":        "luxury",
  "dietary":       ["no_pork"],
  "specific_want": "미슐랭 별 2개 이상 꼭 포함해줘"
}
```

| 필드 | 타입 | 기본값 | 설명 |
|------|------|--------|------|
| `styles` | FoodStyle[] | `[]` | 복수 선택 가능 |
| `budget` | FoodBudget | `mid` | 1인 예산 기준 |
| `dietary` | string[] | `[]` | 식이 제한 |
| `specific_want` | string | `""` | 자유 입력 요청 |

**FoodStyle** — `michelin` `local` `street` `traditional` `trending` `hidden`

**FoodBudget**

| 값 | 기준 |
|----|------|
| `budget` | ₩10,000 이하 |
| `mid` | ₩10,000-30,000 |
| `luxury` | ₩30,000+ |

---

## 3. 응답 스키마

### ItineraryResponse

```json
{
  "title":        "Relaxed 3-Day Seoul Exploration",
  "city":         "서울",
  "nights":       2,
  "days":         3,
  "focus":        "free",
  "pace":         "relaxed",
  "lang":         "en",
  "overall_tips": ["tip text...", "tip text..."],
  "itinerary":    [ /* ItineraryDay[] */ ]
}
```

---

### ItineraryDay

```json
{
  "day":        1,
  "theme":      "Historic Seoul",
  "daily_note": "Start early to avoid crowds at Gyeongbokgung.",
  "blocks":     [ /* ItineraryBlock[] */ ]
}
```

---

### ItineraryBlock

```json
{
  "time":           "09:00",
  "type":           "attraction",
  "name":           "Gyeongbokgung Palace",
  "name_local":     "경복궁",
  "duration_min":   120,
  "address":        "161 Sajik-ro, Jongno-gu",
  "coords":         null,
  "cost_estimate":  "3,000 KRW",
  "reservation":    false,
  "note":           "Free entry in Hanbok.",
  "tip_ids":        ["FOO001"],
  "transport_next": { /* TransportSegment */ }
}
```

| 필드 | 타입 | 설명 |
|------|------|------|
| `time` | string | 시작 시간 `HH:MM` |
| `type` | BlockType | 블록 유형 |
| `name` | string | 영문 장소명 |
| `name_local` | string | 한국어 장소명 |
| `duration_min` | integer | 체류 시간 (분) |
| `address` | string | 주소 |
| `cost_estimate` | string | 비용 추정 |
| `reservation` | boolean | 예약 필요 여부 |
| `note` | string | 팁/주의사항 |
| `tip_ids` | string[] | 연관 팁 ID |
| `transport_next` | TransportSegment\|null | 다음 블록까지 이동 정보 |

**BlockType** — `attraction` `meal` `cafe` `shopping` `rest` `transport`

---

### TransportSegment

> [!info] 현재 상태
> AI 추정값. 향후 Kakao Mobility API 실측값으로 교체 예정.

```json
{
  "method":       "subway",
  "duration_min": 20,
  "distance_m":   null,
  "cost_krw":     1400,
  "note":         "Line 3 Gyeongbokgung → Anguk, 2 stops"
}
```

| 필드 | 타입 | 설명 |
|------|------|------|
| `method` | string | `walk` `subway` `taxi` `bus` |
| `duration_min` | integer | 이동 시간 (분) |
| `distance_m` | integer\|null | 거리 (미터) |
| `cost_krw` | integer\|null | 비용 (원) |
| `note` | string | 노선/출구 상세 |

---

## 4. 요청 예시

### 자유 탐방 2박 3일
```bash
curl -X POST "https://epix-macbookair.tail561905.ts.net/itinerary" \
  -H "Content-Type: application/json" \
  -d '{
    "nights": 2,
    "city": "서울",
    "must_visit": [],
    "focus": "free",
    "pace": "relaxed",
    "lang": "en",
    "provider": "gemini"
  }'
```

### 음식 중심 + 미슐랭 (GPT)
```bash
curl -X POST "https://epix-macbookair.tail561905.ts.net/itinerary" \
  -H "Content-Type: application/json" \
  -d '{
    "nights": 2,
    "city": "서울",
    "must_visit": [],
    "focus": "food",
    "pace": "relaxed",
    "lang": "en",
    "provider": "gpt",
    "food_ctx": {
      "styles": ["michelin", "traditional"],
      "budget": "luxury",
      "dietary": [],
      "specific_want": "미슐랭 별 2개 이상 포함"
    }
  }'
```

### 특정 명소 포함
```bash
curl -X POST "https://epix-macbookair.tail561905.ts.net/itinerary" \
  -H "Content-Type: application/json" \
  -d '{
    "nights": 3,
    "city": "서울",
    "must_visit": ["경복궁", "광장시장", "금돼지식당"],
    "focus": "sightseeing",
    "pace": "normal",
    "lang": "ja",
    "provider": "gemini"
  }'
```

---

## 5. Swagger 문서

```
https://epix-macbookair.tail561905.ts.net/docs    ← Try it out 가능
https://epix-macbookair.tail561905.ts.net/redoc   ← 읽기 전용, 공유용
```

> [!note] Swagger 자동 반영
> FastAPI가 Pydantic 모델 기반으로 자동 생성. 모델 변경 시 별도 작업 없이 반영됨.
