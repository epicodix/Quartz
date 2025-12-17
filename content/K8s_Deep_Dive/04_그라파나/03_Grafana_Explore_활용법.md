# 03. Grafana Explore 완벽 활용법 (실전 통합편)

> **학습 목표**: Grafana Explore를 사용하여 로그를 조회하고 분석하는 방법을 마스터하고, 실제 데이터 생성부터 프로덕션 운영 고려사항까지 학습한다.
> **실습 환경**: Kubernetes Cluster, Grafana, Loki, Promtail

---

## 🏗️ 0. 실습 환경 준비 (데이터 생성)

본격적인 실습에 앞서, 로그를 생성해주는 `log-generator`를 배포하여 풍부한 데이터를 만들어봅시다. 정적인 실습을 넘어, 실시간으로 쏟아지는 로그를 분석하는 것이 실력 향상에 지름길입니다.

### log-generator 배포

같은 폴더에 포함된 `log-generator.yaml` 파일을 사용하여 로그 생성기를 배포합니다. 이 파드는 INFO, WARN, ERROR 로그를 무작위로 생성합니다.

```bash
# 로그 생성기 배포
kubectl apply -f log-generator.yaml

# 배포 확인
kubectl get pods -l app=log-generator
```

이제 `default` 네임스페이스의 `log-generator` 파드에서 로그가 생성되고 있습니다. 아래 실습에서 `namespace="demo-app"` 대신 `namespace="default"` 또는 `app="log-generator"`를 사용하여 실습할 수 있습니다.

---

## 📌 1. Explore란?

**Grafana Explore**는 대시보드를 만들기 전에 쿼리를 테스트하고 데이터를 탐색하는 도구입니다.

```
대시보드: 완성된 모니터링 화면 (읽기 전용, 모니터링용)
Explore:  쿼리 실험실 (쓰기/수정 가능, 분석/디버깅용)
```

### Explore의 용도
1. ✅ **쿼리 개발**: LogQL 쿼리 작성 및 테스트
2. ✅ **로그 탐색**: 실시간 로그 조회 및 필터링
3. ✅ **디버깅**: 특정 시간대의 이벤트 조사 (RCA: Root Cause Analysis)
4. ✅ **임시 분석**: 대시보드 없이 빠른 데이터 딥다이브

---

## 🎯 2. Explore 접속하기

### 1단계: Explore 열기

**방법 1: 메뉴에서**
```
좌측 메뉴 → 🧭 (나침반 아이콘) Explore 클릭
```

**방법 2: 단축키**
```
Mac: ⌘ + E
Windows: Ctrl + E
```

좌측 패널 > Explore

![[스크린샷 2025-12-17 오후 1.15.55 1.png]]

### 2단계: 데이터소스 선택

```
상단 드롭다운: Loki 선택
```

![[스크린샷 2025-12-17 오후 1.18.41.png]]

---

## 🖥️ 3. Explore UI 구조

### 화면 구성

```
┌─────────────────────────────────────────────────┐
│  [Loki ▼]  [Last 15 minutes ▼]     [Run query] │  ← 헤더
├─────────────────────────────────────────────────┤
│  Query editor                                   │  ← 쿼리 입력
│  {namespace="default"} |= "ERROR"               │
│                                                 │
│  [Builder] [Code]                               │  ← 탭 전환
├─────────────────────────────────────────────────┤
│  Visualization: [Logs ▼]                        │  ← 시각화 타입
├─────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────┐   │
│  │  로그 결과 표시 영역                     │   │  ← 결과 패널
│  │                                          │   │
│  │  2025-12-17 10:30:15 INFO: Processing... │   │
│  │  2025-12-17 10:30:17 WARN: API slow...   │   │
│  └─────────────────────────────────────────┘   │
└─────────────────────────────────────────────────┘
```

### 주요 요소

#### 1. **Data Source 선택** (상단 왼쪽)
- Loki, Prometheus 등 선택

#### 2. **Time Range** (상단 중앙)
- Last 5 minutes, Last 1 hour, Custom 등

#### 3. **Run query 버튼** (상단 오른쪽)
- 쿼리 실행 (단축키: Shift + Enter)

#### 4. **Query Editor**
- **Builder**: GUI로 쿼리 작성 (초보자 추천)
- **Code**: LogQL 직접 작성 (숙련자 권장)

#### 5. **Visualization**
- Logs, Time series, Table 등 선택

#### 6. **Results Panel**
- 쿼리 결과 표시

---

## 🔍 4. 실습 가이드

### 실습 1: 첫 로그 조회

#### Step 1: 로그 조회하기

`log-generator`를 배포했다면 아래 쿼리를 사용해보세요.

```logql
{app="log-generator"}
```
*(기존 과제용 demo-app 예시: `{namespace="demo-app"}`)*

**실행 방법:**
1. Code 탭 클릭
2. 위 쿼리 입력
3. Run query 버튼 클릭 (또는 Shift+Enter)

![[스크린샷 2025-12-17 오후 1.19.45.png]]

**예상 결과:**
```
2025-12-17 10:30:15 INFO: Processing request - user_id=456
2025-12-17 10:30:17 WARN: API response slow - latency=574ms
2025-12-17 10:30:19 ERROR: Database connection failed
```

#### Step 2: 시간 범위 조정

```
상단 Time Range: Last 15 minutes → Last 5 minutes
```

로그가 줄어든 것을 확인!
![[스크린샷 2025-12-17 오후 1.20.25.png]]

#### Step 3: Live 모드 활성화

```
우측 상단: [Live] 버튼 클릭
```

→ 실시간으로 새 로그가 자동으로 추가됩니다! (터미널의 `tail -f`와 유사)

![[스크린샷 2025-12-17 오후 1.21.03.png]]

---

### 실습 2: 로그 필터링 (LogQL 핵심)

로그의 홍수 속에서 원하는 정보만 찾으려면 필터링이 필수입니다.

#### ERROR 로그만 보기

```logql
{app="log-generator"} |= "ERROR"
```

**결과:**
```
2025-12-17 10:30:19 ERROR: Database connection failed
2025-12-17 10:30:39 ERROR: Timeout exception
```

![[스크린샷 2025-12-17 오후 1.21.38.png]]

#### WARN 또는 ERROR 로그

```logql
{app="log-generator"} |~ "ERROR|WARN"
```

#### INFO 로그 제외

```logql
{app="log-generator"} != "INFO"
```

#### 대소문자 무시 검색 (Regex)

```logql
{app="log-generator"} |~ "(?i)error"
```
→ ERROR, Error, error 모두 검색

---

### 실습 3: 로그 → 메트릭 변환 (Log Aggregation)

로그의 양을 세어 그래프로 그릴 수 있습니다. "로그가 얼마나 많이 발생했는가?"를 시각화합니다.

#### Pod별 로그 발생률

```logql
sum(rate({app="log-generator"}[1m])) by (pod)
```

**Visualization 변경:**
```
Logs → Time series
```

![[스크린샷 2025-12-17 오후 1.28.14.png]]
*Explorer에서 확인 후 유용하다면 [Add to dashboard] 버튼으로 바로 대시보드에 추가할 수 있습니다.*

**그래프 해석:**
- X축: 시간
- Y축: 초당 로그 라인 수
- 각 선: Pod별 로그 발생 빈도

#### 5분간 ERROR 개수 (Stat 패널용)

```logql
sum(count_over_time({app="log-generator"} |= "ERROR" [5m]))
```

**Visualization:**
```
Stat (숫자 표시)
```

![[스크린샷 2025-12-17 오후 1.32.50.png]]

---

### 실습 4: Split View (비교 분석)

두 개의 쿼리를 동시에 실행하여 상관관계를 분석할 때 유용합니다.

#### 전체 로그 vs ERROR 로그 비교

**1. Split 버튼 클릭** (우측 상단)

**2. 왼쪽 패널:** (전체 트래픽)
```logql
sum(rate({app="log-generator"}[1m]))
```

**3. 오른쪽 패널:** (에러 트래픽)
```logql
sum(rate({app="log-generator"} |= "ERROR" [1m]))
```

![[스크린샷 2025-12-17 오후 1.34.48.png]]

**분석 포인트:**
- 전체 트래픽이 증가할 때 에러도 같이 증가하는가? (시스템 부하 문제)
- 전체 트래픽은 일정한데 에러만 증가하는가? (코드/DB 문제)

---

### 실습 5: 로그 라인 상세 분석

#### 로그 라인 클릭

```
로그 라인 클릭 → 상세 정보 패널 열림
```

**표시 정보:**
- **Timestamp**: 나노초 단위의 정확한 시간
- **Labels**: `app`, `pod`, `namespace`, `node_name` 등 메타데이터
- **Log content**: 로그 메시지 본문

![[스크린샷 2025-12-17 오후 1.39.53.png]]

#### Filter 액션 (Ad-hoc 쿼리)

로그 상세 패널에서 필드를 클릭하여 바로 쿼리에 추가할 수 있습니다.
```
latency=574ms → Filter for value 클릭
→ 쿼리에 자동 추가: {app="log-generator"} |= "latency=574ms"
```

![[스크린샷 2025-12-17 오후 1.45.44.png]]

#### Context 보기 (전후 맥락 파악)

```
로그 라인 클릭 → Show context
```
→ 해당 로그가 발생하기 **직전/직후의 로그**를 보여줍니다. 에러 발생 시 어떤 작업이 선행되었는지 파악하는 데 결정적입니다.

---

## ⚙️ 5. 고급 기능

### 1. Query History (쿼리 히스토리)
작성했던 쿼리가 기억나지 않을 때 유용합니다.
```
우측 패널: History 탭 클릭
→ 이전에 실행한 쿼리 목록 조회 및 재실행
```
![[스크린샷 2025-12-17 오후 1.47.59.png]]

### 2. Query Inspector
쿼리 성능 문제를 진단할 때 사용합니다.
```
쿼리 결과 아래: Inspector 버튼 클릭
→ 실행 시간, 스캔한 데이터 양(MB/GB) 확인
```
![[스크린샷 2025-12-17 오후 1.50.40.png]]

### 3. Share Explore
동료에게 "이 로그 좀 봐줘"라고 할 때 사용합니다.
```
상단: Share 버튼 → Copy link
→ 현재 쿼리와 시간 범위가 포함된 URL 공유
```

---

## 🎯 6. 실전 시나리오

### 시나리오 1: 장애 발생 시 긴급 로그 조사

**상황:** "13:30경에 결제 서비스가 느려졌다"는 보고 접수

**조사 단계:**
1. **Time Range**: 13:25 ~ 13:35 설정 (장애 시간 전후 5분)
2. **쿼리 작성**: 키워드 기반 필터링
   ```logql
   {app="payment"} |~ "(?i)error|timeout|slow|fail"
   ```
3. **패턴 파악**: 특정 DB 에러가 반복되는지 확인
![[스크린샷 2025-12-17 오후 1.51.25.png]]

### 시나리오 2: 특정 사용자 추적 (User Journey)

**상황:** `user_id=123` 고객이 오류를 제보함

**조사 단계:**
1. **쿼리 작성**:
   ```logql
   {namespace="default"} |= "user_id=123"
   ```
2. **Context 확인**: 에러 로그 주변의 INFO 로그를 통해 사용자가 어떤 행동을 했는지 추적
![[스크린샷 2025-12-17 오후 1.56.58.png]]

---

## 🏭 7. 프로덕션 운영 가이드 (Deep Dive)

학습 환경과 실제 운영 환경(Production)은 규모와 요구사항이 다릅니다. 프로덕션 도입 시 고려해야 할 핵심 사항들을 정리했습니다.

### 1. 아키텍처: Monolithic vs Microservices
- **Monolithic (학습용)**: Loki 바이너리 하나가 모든 역할(수집, 저장, 쿼리)을 수행. 설정이 쉽지만 확장에 한계가 있음.
- **Microservices (프로덕션용)**: Loki를 여러 컴포넌트(Distributor, Ingester, Querier, Query Frontend 등)로 쪼개어 배포.
  - **장점**: 읽기/쓰기 경로의 독립적 확장 가능 (로그가 폭주하면 Ingester만 증설, 조회가 느리면 Querier 증설).

### 2. 스토리지 전략: Object Storage 필수
- 로컬 디스크는 확장이 어렵고 데이터 유실 위험이 있습니다.
- 프로덕션에서는 **S3, GCS, Azure Blob Storage** 같은 Object Storage를 백엔드로 사용해야 합니다.
- **Index**: BoltDB-shipper 또는 TSDB 사용 (S3에 인덱스 파일도 저장).

### 3. 데이터 보존 (Retention)
- 모든 로그를 영원히 저장할 수는 없습니다. (비용 문제)
- **Compactor** 컴포넌트를 사용하여 오래된 로그를 정리합니다.
  ```yaml
  # loki.yaml 예시
  limits_config:
    retention_period: 30d  # 30일 보관
  compactor:
    working_directory: /data/retention
    shared_store: s3
  ```

### 4. 쿼리 성능 최적화
- **Label Cardinality 주의**: `user_id`, `trace_id` 같이 무한히 늘어나는 값은 **절대로 레이블(Labels)로 쓰면 안 됩니다.** 인덱스가 폭발하여 Loki가 죽을 수 있습니다.
  - ❌ Bad: `{user_id="123"}`
  - ⭕ Good: `{app="frontend"} |= "user_id=123"` (레이블로 범위를 좁히고 필터로 찾기)
- **Parallel Queries**: 쿼리를 여러 개로 쪼개어 병렬 처리하도록 설정합니다 (Query Frontend 역할).

### 5. 보안 (Security)
- **Multi-tenancy**: Loki는 `X-Scope-OrgID` 헤더를 통해 데이터를 격리할 수 있습니다. 팀별로 로그 접근 권한을 분리할 때 사용합니다.
- **Log Redaction**: 비밀번호, 개인정보 등 민감 데이터는 Promtail 단계에서 마스킹(Masking) 처리하여 저장되지 않도록 해야 합니다.

---

## 🎓 연습 문제 (Self-Check)

1. `log-generator` 파드에서 발생하는 **WARN** 로그만 실시간으로 조회해보세요.
2. 지난 1시간 동안 가장 많은 로그를 발생시킨 파드가 무엇인지 그래프로 그려보세요.
3. `log-generator`에서 `latency`가 500ms 이상인 로그만 찾아보세요. (힌트: LogQL 파싱 기능이 필요할 수 있지만, 지금은 텍스트 필터 `|=` 로 시도해보세요)

---

