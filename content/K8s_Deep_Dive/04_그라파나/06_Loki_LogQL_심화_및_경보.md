# 06. Loki LogQL 심화 및 경보(Alerting)

> **학습 목표**: 텍스트 로그를 숫자로 변환(Log Aggregation)하여 추세를 분석하고, 이상 징후 발생 시 슬랙(Slack) 등으로 알람을 보내는 모니터링의 꽃, Alerting을 배웁니다.
> **선수 지식**: [[03_Grafana_Explore_LogQL_분석]] (기초 LogQL)

---

## 📊 1. 로그를 메트릭으로 변환하기 (Log to Metrics)

Prometheus는 "현재 CPU 80%"라는 수치를 주지만, Loki는 "DB 연결 실패"라는 텍스트를 줍니다.
이 텍스트 로그를 "분당 에러 5건"이라는 **숫자**로 바꿔야 그래프를 그리고 경보를 걸 수 있습니다.

### 1-1. Range Vector Aggregation
기초에서 배운 `count_over_time` 외에도 다양한 함수가 있습니다.

| 함수 | 설명 | 예시 |
| :--- | :--- | :--- |
| `rate(Log[1m])` | **초당** 로그 발생 건수 (Logs/sec) | 트래픽 추이 분석 |
| `count_over_time(Log[1m])` | 1분간 발생한 **총 건수** | 에러 카운트 |
| `bytes_over_time(Log[1m])` | 로그의 **용량(Bytes)** | 스토리지 사용량 분석 |

### 1-2. Unwrap: 로그 안의 숫자 추출하기
로그 내용이 다음과 같다면?
`level=info msg="request processed" latency=150ms`

단순 개수가 아니라 저 `150ms`라는 값의 평균을 구하고 싶다면 **Unwrap**을 씁니다.
```logql
# 1. 먼저 latency 레이블을 파싱(Parser)
{app="backend"} | logfmt 
# 2. unwrap으로 값을 꺼내고 집계
| unwrap latency | __error__="" 
# 3. 평균 계산 (avg_over_time)
| avg_over_time[1m]
```
→ *이제 로그 데이터로 응답 속도 그래프를 그릴 수 있습니다!*

---

## 🕵️ 2. 고급 LogQL 패턴

### 2-1. Top N 쿼리 (범인 찾기)
"가장 에러를 많이 뱉는 파드 3놈만 잡아와!"
```logql
topk(3, sum(rate({app="log-generator"} |= "ERROR" [1m])) by (pod))
```

### 2-2. 비교 연산
"에러 비율이 5% 넘는 애들만 보고 싶어"
```logql
# (에러율 / 전체율) * 100 > 5
(
  sum(rate({app="backend"} |= "error" [1m])) 
  / 
  sum(rate({app="backend"}[1m]))
) * 100 > 5
```
→ *이 쿼리는 조건이 참일 때만 데이터를 반환하므로 Alerting에 아주 적합합니다.*

---

## 🚨 3. Alerting (경보) 설정

Grafana Alerting을 사용하면 대시보드를 보고 있지 않아도 문제가 생기면 연락을 받을 수 있습니다.

### 3-1. Contact Point 설정 (어디로 보낼까?)
1. 좌측 메뉴 **Alerting** → **Contact points**.
2. **+ Add contact point** 클릭.
3. **Integration**: `Slack`, `Email`, `Discord`, `Webhook` 등 선택.
   - *Slack 예시*: Webhook URL을 입력하면 해당 채널로 메시지가 쏘아집니다.
4. **Test** 버튼으로 메시지가 오는지 확인 후 저장.

### 3-2. Alert Rule 만들기 (언제 보낼까?)
1. **Alerting** → **Alert rules** → **+ New alert rule**.
2. **Step 1: Define query**
   - Loki 데이터소스 선택.
   - 쿼리 입력: `sum(count_over_time({app="log-generator"} |= "ERROR" [1m]))`
   - *의미: 1분간 발생한 에러의 총 개수.*
3. **Step 2: Define conditions**
   - **Condition**: `WHEN last() OF A IS ABOVE 10`
   - *해석: 방금(last) 조회한 에러 개수가 10개를 넘으면(IS ABOVE 10) 발동하라.*
4. **Step 3: Add details**
   - **Rule name**: `Critical Error Surge`
   - **Folder**: 저장할 폴더 선택.
   - **Summary**: `High error rate detected in {{ $labels.pod }}` (메시지 템플릿)
5. **Save rule and exit** 클릭.

### 3-3. 상태 확인
- **Normal**: 조건 미달 (평화로움 😌)
- **Pending**: 조건 충족했지만 지속 시간 대기 중 (간 보는 중 🤔)
- **Firing**: 경보 발송! (비상! 🚨)

---

## 🎯 요약 및 다음 단계

이제 여러분은:
1. 로그 텍스트에서 **의미 있는 숫자(Metric)**를 뽑아내고,
2. 그 숫자를 기반으로 **자동화된 감시 체계(Alert)**를 구축했습니다.

마지막 장인 **[[07_통합_모니터링_시스템_구축]]**에서는 지금까지 배운 모든 것(Prometheus, Loki, Explore, Dashboard, Alert)을 총동원하여, 실제 운영 환경 수준의 **"Full Stack Monitoring System"**을 완성하고 마무리하겠습니다.
