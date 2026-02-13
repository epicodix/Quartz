---
title: 이벤트 도배방지 - Debounce & Throttle 패턴
tags:
  - debounce
  - throttle
  - event-driven
  - apps-script
  - architecture
  - rate-limiting
aliases:
  - 디바운스
  - 쓰로틀
  - 도배방지
date: 2026-02-12
category: 2_기술_분석/이벤트_처리
status: 완성
priority: 보통
---

# 🎯 이벤트 도배방지 - Debounce & Throttle 패턴

## 📑 목차
- [[#1. 문제 상황|문제 상황]]
- [[#2. 핵심 패턴 비교|핵심 패턴 비교]]
- [[#3. 실전 적용 사례|실전 적용 사례]]
- [[#4. 적용 가능한 기술 스택|적용 가능한 기술 스택]]
- [[#5. 패턴 선택 가이드|패턴 선택 가이드]]

---

## 1. 문제 상황

> [!note] 핵심 개념
> 이벤트 기반 시스템에서 짧은 시간 내 동일한 이벤트가 연속 발생하면, 후속 작업(알림, API 호출, DB 갱신)이 **도배**되는 문제가 발생한다.

### 💡 실제 경험한 시나리오

**Notion → Discord 알림 도배**

```
10:00:01  태스크A 상태변경 → Discord 알림
10:00:03  태스크B 상태변경 → Discord 알림
10:00:05  태스크C 상태변경 → Discord 알림
```

Notion에서 여러 태스크를 연속으로 수정하면, 웹훅이 건건이 트리거되어 Discord에 알림이 도배됨.

---

## 2. 핵심 패턴 비교

### 📊 3가지 패턴 비교표

| 패턴 | 동작 방식 | 적합한 상황 | 단점 |
|------|----------|------------|------|
| **Debounce** | 마지막 이벤트 후 N초 대기 → 1회 실행 | 연속 입력, 배치 알림 | 첫 이벤트 반응 지연 |
| **Throttle** | N초에 최대 1회만 실행 | API Rate Limit, 스크롤 | 마지막 이벤트 유실 가능 |
| **Cooldown** | 실행 후 N초간 무시 | 버튼 중복클릭 방지 | 최신 상태 반영 불가 |

### 💻 동작 시각화

```
이벤트:  ──A──B──C──────D──E──────────

Debounce:          [C 처리]      [E 처리]
  (3초 대기)   A,B 무시          D 무시

Throttle: [A 처리]       [D 처리]
  (3초 간격)  B,C 무시     E 무시

Cooldown: [A 처리]       [D 처리]
  (3초 잠금)  B,C 무시     E 무시
```

> [!warning] Cooldown vs Debounce 차이
> Cooldown은 **첫 번째** 이벤트를 처리하고 나머지를 무시한다. 따라서 **최신 상태가 반영되지 않는** 치명적 단점이 있다.
> Debounce는 **마지막** 이벤트를 처리하므로 항상 최신 상태가 반영된다.

---

## 3. 실전 적용 사례

### 💡 Google Apps Script + CacheService 디바운스

> [!example] Notion → Sheets → Discord 파이프라인
> 1. **웹훅 수신**: Notion 변경 → Cloud Run → Apps Script 트리거
> 2. **변경 감지**: Notion API 조회 → 시트 비교 → 변경사항 추출
> 3. **캐시 저장**: CacheService에 최신 변경사항 덮어쓰기
> 4. **트리거 예약**: 기존 예약 삭제 → 30초 후 새로 예약
> 5. **발송**: 30초 후 캐시에서 최신 상태 읽어서 Discord 전송

#### 📋 구현 핵심 코드

```javascript
// 1. 변경 감지 시 → 캐시에 최신 상태 저장 (덮어쓰기)
const cache = CacheService.getScriptCache();
cache.put("pending_discord_changes", JSON.stringify(payload), 120);

// 2. 기존 예약된 트리거 삭제 (리셋)
const triggers = ScriptApp.getProjectTriggers();
for (const t of triggers) {
  if (t.getHandlerFunction() === "sendDelayedDiscordUpdate_") {
    ScriptApp.deleteTrigger(t);
  }
}

// 3. 30초 후 실행 예약 (새로 시작)
ScriptApp.newTrigger("sendDelayedDiscordUpdate_")
  .timeBased()
  .after(30 * 1000)
  .create();
```

```javascript
// 4. 30초 후 실행: 캐시에서 최신 상태 읽어서 발송
function sendDelayedDiscordUpdate_() {
  const cache = CacheService.getScriptCache();
  const cached = cache.get("pending_discord_changes");
  if (cached) {
    const payload = JSON.parse(cached);
    sendDiscordUpdate_(payload.sprintChanges, payload.taskChanges);
    cache.remove("pending_discord_changes");
  }
}
```

> [!tip] 핵심 포인트
> 이벤트가 올 때마다 캐시를 **덮어쓰고** 타이머를 **리셋**한다. 덕분에 30초 내 연속 변경이 있으면 항상 **마지막(최신) 상태**만 발송된다.

#### 📊 결과

```
10:00:01  태스크A 완료 → 캐시 저장, 30초 타이머 시작
10:00:05  태스크B 완료 → 캐시 덮어쓰기, 타이머 리셋
10:00:08  태스크C 완료 → 캐시 덮어쓰기, 타이머 리셋
10:00:38  → Discord 1건 발송 (A+B+C 모두 반영된 최신 상태)
```

---

## 4. 적용 가능한 기술 스택

### 🔧 서버리스 / 경량 환경

| 기술 | 디바운스 구현 방식 | 적합도 |
|------|-------------------|--------|
| **Google Apps Script** | CacheService + TimeBased Trigger | 실전 검증 완료 |
| **AWS Lambda** | DynamoDB TTL + EventBridge Scheduler | 확장성 우수 |
| **Cloud Functions** | Firestore + Cloud Scheduler | GCP 네이티브 |
| **Cloudflare Workers** | KV Store + Durable Objects | 엣지 처리 |

### 🔧 메시지 큐 / 스트리밍

| 기술 | 패턴 | 적합한 상황 |
|------|------|------------|
| **Redis** | `SETEX` (TTL 키) + Pub/Sub | 가장 범용적, 고성능 |
| **Kafka** | Windowed Aggregation | 대규모 이벤트 스트리밍 |
| **RabbitMQ** | Delayed Message Plugin | 기존 큐 인프라 활용 |
| **SQS** | Message Deduplication (5분 윈도우) | AWS 네이티브 |

### 🔧 프론트엔드 / 클라이언트

| 기술 | 구현 | 적합한 상황 |
|------|------|------------|
| **lodash.debounce** | `_.debounce(fn, 300)` | 검색 자동완성, 입력 |
| **RxJS** | `debounceTime(300)` | Angular/복잡한 스트림 |
| **React** | `useDeferredValue` / custom hook | React 컴포넌트 |

### 🔧 인프라 레벨

| 기술 | 패턴 | 적합한 상황 |
|------|------|------------|
| **API Gateway** | Rate Limiting / Throttling | API 보호 |
| **Nginx** | `limit_req_zone` | 요청 제한 |
| **Istio/Envoy** | Circuit Breaker + Rate Limit | K8s 서비스 메시 |

---

## 5. 패턴 선택 가이드

> [!info] 상황별 추천

```
알림/노티피케이션 도배 방지
  → Debounce (마지막 상태만 발송)

API Rate Limit 준수
  → Throttle (일정 간격 실행)

버튼 중복 클릭 방지
  → Cooldown (첫 클릭만 처리)

대량 이벤트 집계/배치
  → Windowed Aggregation (시간 윈도우 단위 집계)

마이크로서비스 장애 전파 방지
  → Circuit Breaker (실패 임계치 초과 시 차단)
```

### 📋 의사결정 플로우

```
이벤트 연속 발생?
├─ 최신 상태가 중요한가?
│  ├─ YES → Debounce
│  └─ NO  → Throttle 또는 Cooldown
├─ 모든 이벤트를 처리해야 하는가?
│  ├─ YES → Queue + Batch Processing
│  └─ NO  → Debounce / Throttle
└─ 외부 API 호출 제한?
   └─ YES → Throttle + Exponential Backoff
```

> [!tip] 실무 팁
> 디바운스 대기 시간은 사용 사례에 따라 조절한다.
> - 검색 자동완성: 200~300ms
> - 알림 배치: 10~60초
> - 데이터 동기화: 30초~5분
> 너무 짧으면 도배 방지 효과가 없고, 너무 길면 응답성이 떨어진다.
