---
title: 08_PromQL 레이블 매처 완벽 가이드
tags:
  - PromQL
  - 레이블매처
  - Label
  - 정규식
  - Prometheus
aliases:
  - 레이블매처
  - LabelMatcher
  - PromQL필터
date: 2025-12-04
category: K8s_Deep_Dive/프로메테우스
status: 완성
priority: 높음
---

# 🎯 PromQL 레이블 매처 완벽 가이드

> [!note] 학습 목표
> PromQL의 핵심인 레이블 매처를 완벽히 이해하고, 정규식을 활용한 고급 필터링 기법을 마스터합니다.

> [!important] 레이블 매처란?
> 시계열 데이터를 필터링하는 조건식입니다. 수천~수만 개의 시계열 중에서 원하는 것만 선택할 수 있게 해줍니다.

> [!tip] 4가지 매처 타입
> - `=` : 완전 일치 (가장 빠름)
> - `!=` : 불일치
> - `=~` : 정규식 일치 (유연함)
> - `!~` : 정규식 불일치

## 목차
- [레이블 매처란?](#레이블-매처란)
- [4가지 매처 타입](#4가지-매처-타입)
- [정규식 패턴 상세](#정규식-패턴-상세)
- [복합 조건 & 고급 패턴](#복합-조건--고급-패턴)
- [특수한 레이블 매처](#특수한-레이블-매처)
- [레이블 존재 여부 확인](#레이블-존재-여부-확인)
- [실전 활용 예시](#실전-활용-예시)
- [성능 최적화](#성능-최적화)
- [자주 하는 실수](#자주-하는-실수)
- [디버깅 팁](#디버깅-팁)
- [치트시트](#치트시트)

---

## 레이블 매처란?

**레이블 매처(Label Matcher)**는 시계열 데이터를 필터링하는 조건식입니다. 수천~수만 개의 시계열 중에서 원하는 것만 선택할 수 있게 해줍니다.

### 기본 구조

```promql
metric_name{label_name="value"}
```

### 왜 중요한가?

Prometheus의 모든 메트릭은 레이블(Label)이라는 키-값 쌍으로 구성됩니다:

```
메트릭 이름: http_requests_total
레이블:
  - method: "GET"
  - status: "200"
  - path: "/api/users"
  - instance: "web-server-1:8080"
```

하나의 메트릭 이름이 레이블 조합으로 수천 개의 **시계열(time series)**로 분리됩니다. 레이블 매처는 이 중에서 필요한 시계열만 선택하는 도구입니다.

---

## 4가지 매처 타입

### 1. `=` : 완전 일치 (Equality Matcher)

정확히 일치하는 값만 선택

#### 기본 사용법

```promql
# method가 정확히 "GET"인 시계열만
http_requests_total{method="GET"}

# status가 정확히 "200"인 것만
http_requests_total{status="200"}

# 여러 조건 동시에 (AND)
http_requests_total{method="GET", status="200"}
```

#### 실제 데이터 예시

```
원본 데이터:
http_requests_total{method="GET", status="200", path="/api"} 1234
http_requests_total{method="POST", status="200", path="/api"} 567
http_requests_total{method="GET", status="404", path="/api"} 89

쿼리: http_requests_total{method="GET"}
결과:
✅ http_requests_total{method="GET", status="200", path="/api"} 1234
✅ http_requests_total{method="GET", status="404", path="/api"} 89
❌ http_requests_total{method="POST", status="200", path="/api"} (제외)
```

#### 특징

- 가장 빠른 매처 (인덱스 직접 조회)
- 대소문자 구분 (case-sensitive)
- 완전히 일치해야 함

---

### 2. `!=` : 불일치 (Inequality Matcher)

일치하지 않는 값 선택

#### 기본 사용법

```promql
# method가 "GET"이 아닌 모든 것
http_requests_total{method!="GET"}

# status가 "200"이 아닌 모든 것 (에러 감지에 유용)
http_requests_total{status!="200"}

# health check 경로 제외
http_requests_total{path!="/health"}

# 여러 조건 (AND)
http_requests_total{method!="GET", status!="200"}
```

#### 실제 데이터 예시

```
원본 데이터:
http_requests_total{method="GET"} 1234
http_requests_total{method="POST"} 567
http_requests_total{method="PUT"} 89
http_requests_total{method="DELETE"} 34

쿼리: http_requests_total{method!="GET"}
결과:
❌ http_requests_total{method="GET"} (제외)
✅ http_requests_total{method="POST"} 567
✅ http_requests_total{method="PUT"} 89
✅ http_requests_total{method="DELETE"} 34
```

#### ⚠️ 중요한 주의사항

`!=`는 **해당 레이블이 있으면서** 값이 다른 경우만 선택합니다!

```promql
# path 레이블이 있고 "/health"가 아닌 것
http_requests_total{path!="/health"}

# 💡 path 레이블 자체가 없는 시계열은 제외됨!
```

**예시:**

```
원본 데이터:
http_requests_total{path="/api"} 100
http_requests_total{path="/health"} 50
http_requests_total{} 200  ← path 레이블 없음

쿼리: http_requests_total{path!="/health"}
결과:
✅ http_requests_total{path="/api"} 100
❌ http_requests_total{path="/health"} (제외)
❌ http_requests_total{} (path 레이블이 없어서 제외!)
```

---

### 3. `=~` : 정규식 일치 (Regex Matcher)

정규식 패턴과 일치하는 값 선택

#### 기본 사용법

```promql
# status가 2xx (200, 201, 204 등)
http_requests_total{status=~"2.."}

# status가 4xx 또는 5xx (에러)
http_requests_total{status=~"[45].."}

# path가 /api로 시작
http_requests_total{path=~"/api/.*"}

# method가 GET 또는 POST
http_requests_total{method=~"GET|POST"}

# instance가 web-로 시작하고 숫자로 끝남
http_requests_total{instance=~"web-.*-[0-9]+"}
```

#### 실제 데이터 예시

```
원본 데이터:
http_requests_total{status="200"} 1234
http_requests_total{status="201"} 567
http_requests_total{status="204"} 89
http_requests_total{status="404"} 123
http_requests_total{status="500"} 45

쿼리: http_requests_total{status=~"2.."}
결과:
✅ http_requests_total{status="200"} 1234
✅ http_requests_total{status="201"} 567
✅ http_requests_total{status="204"} 89
❌ http_requests_total{status="404"} (제외)
❌ http_requests_total{status="500"} (제외)
```

#### 특징

- 유연하고 강력함
- `=`보다 10~100배 느림
- RE2 정규식 문법 사용 (Go 정규식)
- 전체 문자열 매칭 (암묵적 `^...$`)

---

### 4. `!~` : 정규식 불일치 (Negative Regex Matcher)

정규식 패턴과 일치하지 않는 값 선택

#### 기본 사용법

```promql
# status가 2xx가 아닌 것 (에러만)
http_requests_total{status!~"2.."}

# path가 /api/로 시작하지 않는 것
http_requests_total{path!~"/api/.*"}

# method가 GET, POST가 아닌 것
http_requests_total{method!~"GET|POST"}

# 프로덕션이 아닌 환경
http_requests_total{env!~"prod.*"}
```

#### 실제 데이터 예시

```
원본 데이터:
http_requests_total{status="200"} 1234
http_requests_total{status="201"} 567
http_requests_total{status="404"} 123
http_requests_total{status="500"} 45

쿼리: http_requests_total{status!~"2.."}
결과:
❌ http_requests_total{status="200"} (제외)
❌ http_requests_total{status="201"} (제외)
✅ http_requests_total{status="404"} 123
✅ http_requests_total{status="500"} 45
```

#### 특징

- `!=`처럼 해당 레이블이 있는 시계열만 대상
- 정규식이므로 느림
- 복잡한 제외 조건 표현 가능

---

## 정규식 패턴 상세

### 기본 메타 문자

| 메타문자 | 의미 | 예시 | 매칭 예시 |
|---------|------|------|----------|
| `.` | 임의의 한 글자 | `2..` | 200, 201, 299 |
| `*` | 0개 이상 반복 | `/api.*` | /api, /api/, /api/users |
| `+` | 1개 이상 반복 | `web-[0-9]+` | web-1, web-123 |
| `?` | 0개 또는 1개 | `https?` | http, https |
| `\|` | OR | `GET\|POST` | GET, POST |
| `[]` | 문자 집합 | `[45]..` | 400, 500 |
| `()` | 그룹화 | `(prod\|staging)-.*` | prod-server, staging-db |
| `^` | 시작 | `^/api` | /api로 시작 |
| `$` | 끝 | `.*\\.json$` | .json으로 끝 |
| `\\` | 이스케이프 | `\\.` | 점(.) 문자 그대로 |

### 상세 예시

#### 1. 점(.) - 임의의 한 글자

```promql
# 2 + 아무거나 2글자 = 2xx
status=~"2.."
# 매칭: 200, 201, 299
# 불일치: 2, 20, 2000

# 정확히 3글자
path=~"..."
# 매칭: /v1, /v2
# 불일치: /api, /health
```

#### 2. 별표(*) - 0개 이상 반복

```promql
# /api 뒤에 아무거나 0개 이상
path=~"/api.*"
# 매칭: /api, /api/, /api/users, /api/v1/users

# web- 뒤에 아무거나
instance=~"web-.*"
# 매칭: web-, web-1, web-server-prod
```

#### 3. 플러스(+) - 1개 이상 반복

```promql
# 숫자 1개 이상
instance=~"web-[0-9]+"
# 매칭: web-1, web-123
# 불일치: web-, web-abc

# 문자 1개 이상
error_code=~".+"
# 레이블이 있고 비어있지 않은 것
```

#### 4. 물음표(?) - 0개 또는 1개

```promql
# s가 있거나 없거나
protocol=~"https?"
# 매칭: http, https
# 불일치: httpss

# 선택적 슬래시
path=~"/api/?"
# 매칭: /api, /api/
```

#### 5. 파이프(|) - OR

```promql
# GET 또는 POST
method=~"GET|POST"
# 매칭: GET, POST
# 불일치: PUT, DELETE

# 여러 상태 코드
status=~"200|201|204"

# 여러 환경
env=~"production|staging|qa"
```

#### 6. 대괄호([]) - 문자 집합

```promql
# 4 또는 5로 시작하는 3자리
status=~"[45].."
# 매칭: 400, 404, 500, 503

# 소문자 a-z
name=~"[a-z]+"

# 숫자 0-9
id=~"[0-9]{3}"  # 정확히 3자리 숫자

# 부정 (^)
# 숫자가 아닌 것
name=~"[^0-9]+"
```

#### 7. 캐럿(^) - 시작

```promql
# /api로 시작
path=~"^/api"
# 매칭: /api, /api/users
# 불일치: /health/api, /v1/api

# prod로 시작
instance=~"^prod-.*"
# 매칭: prod-web-1, prod-db-2
# 불일치: staging-prod, test-prod
```

#### 8. 달러($) - 끝

```promql
# .json으로 끝
path=~".*\\.json$"
# 매칭: /api/data.json, /users.json
# 불일치: /api.json/data

# 숫자로 끝
instance=~".*-[0-9]+$"
# 매칭: web-1, api-server-123
# 불일치: web-1-prod
```

#### 9. 괄호(()) - 그룹화

```promql
# (prod 또는 staging) + 아무거나
instance=~"(prod|staging)-.*"
# 매칭: prod-web-1, staging-db-2
# 불일치: dev-web-1

# 버전 패턴
version=~"v([0-9]+)\\.([0-9]+)\\.([0-9]+)"
# 매칭: v1.2.3, v10.20.30
```

#### 10. 중괄호({}) - 반복 횟수

```promql
# 정확히 3자리 숫자
status=~"[0-9]{3}"
# 매칭: 200, 404, 500
# 불일치: 20, 2000

# 2~4자리 숫자
port=~"[0-9]{2,4}"
# 매칭: 80, 443, 8080

# 최소 2자리
code=~"[0-9]{2,}"
# 매칭: 10, 100, 1000
```

### 이스케이프

특수 문자를 문자 그대로 사용하려면 백슬래시(`\`)로 이스케이프:

```promql
# 점(.)을 문자로
domain=~"example\\.com"
# 매칭: example.com
# 불일치: exampleXcom

# 대괄호를 문자로
tag=~"\\[important\\]"
# 매칭: [important]

# 백슬래시를 문자로
path=~"C:\\\\Users"
# 매칭: C:\Users
```

---

## 복합 조건 & 고급 패턴

### AND 조건 (콤마로 구분)

여러 레이블 조건을 모두 만족해야 함:

```promql
# method=GET AND status=200
http_requests_total{method="GET", status="200"}

# 프로덕션 AND 2xx 응답
http_requests_total{env="production", status=~"2.."}

# web 서버 AND GET 요청 AND /api 경로
http_requests_total{
  instance=~"web-.*",
  method="GET",
  path=~"/api/.*"
}

# 4가지 조건 모두
http_requests_total{
  env="production",
  method=~"GET|POST",
  status=~"2..",
  path!~"/health|/metrics"
}
```

### OR 조건

#### 방법 1: 정규식 사용 (권장)

```promql
# status가 200 OR 201 OR 204
http_requests_total{status=~"200|201|204"}

# env가 production OR staging
http_requests_total{env=~"production|staging"}

# method가 GET, POST, PUT 중 하나
http_requests_total{method=~"GET|POST|PUT"}
```

#### 방법 2: 여러 쿼리를 or로 연결

```promql
# status=200 OR status=500
http_requests_total{status="200"}
or
http_requests_total{status="500"}

# 프로덕션 OR 높은 에러율
sum(rate(http_requests_total{env="production"}[5m]))
or
sum(rate(http_requests_total{status=~"5.."}[5m])) > 10
```

### 복잡한 비즈니스 로직

#### 1. IP 주소 패턴

```promql
# 192.168.x.x 대역
http_requests_total{client_ip=~"192\\.168\\..*"}

# 10.0.0.0/8 사설 IP
http_requests_total{client_ip=~"10\\..*"}

# 특정 서브넷 (192.168.1.x)
http_requests_total{client_ip=~"192\\.168\\.1\\..*"}
```

#### 2. 이메일 도메인

```promql
# Gmail 또는 Yahoo 사용자
user_logins_total{email=~".*@(gmail|yahoo)\\.com"}

# 회사 이메일만 (특정 도메인)
user_logins_total{email=~".*@company\\.com$"}

# 무료 이메일 제외
user_logins_total{email!~".*@(gmail|yahoo|hotmail)\\.com"}
```

#### 3. UUID 패턴

```promql
# 표준 UUID (8-4-4-4-12)
http_requests_total{
  request_id=~"[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}"
}

# UUID v4 (세 번째 그룹이 4로 시작)
http_requests_total{
  request_id=~"[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}"
}
```

#### 4. 버전 번호

```promql
# Semantic Versioning (v1.2.3)
app_info{version=~"v[0-9]+\\.[0-9]+\\.[0-9]+"}

# Major 버전 1.x.x
app_info{version=~"v1\\..*"}

# 특정 버전 범위 (v2.0.0 ~ v2.9.x)
app_info{version=~"v2\\.[0-9]\\..*"}
```

#### 5. 파일 확장자

```promql
# 이미지 파일
http_requests_total{path=~".*\\.(jpg|jpeg|png|gif|svg)$"}

# 정적 파일
http_requests_total{path=~".*\\.(css|js|jpg|png|ico)$"}

# API 엔드포인트만 (확장자 없음)
http_requests_total{path!~".*\\.[a-z]+$"}
```

#### 6. 데이터센터/리전

```promql
# 특정 데이터센터 (dc1, dc2, dc3)
node_cpu_usage{instance=~".*-dc[1-3]-.*"}

# AWS 리전 (us-east, us-west)
http_requests_total{region=~"us-(east|west)-[0-9]+"}

# 유럽 리전만
http_requests_total{region=~"eu-.*"}
```

#### 7. 포트 번호

```promql
# 8xxx 포트
http_requests_total{instance=~".*:8[0-9]{3}"}

# 웰노운 포트 (1-1023)
http_requests_total{instance=~".*:[0-9]{1,3}"}

# 특정 포트들 (80, 443, 8080, 8443)
http_requests_total{instance=~".*:(80|443|8080|8443)"}
```

---

## 특수한 레이블 매처

### `__name__` : 메트릭 이름 매칭

메트릭 이름 자체도 특수 레이블 `__name__`로 취급됩니다!

#### 기본 사용법

```promql
# 일반 방식
http_requests_total

# __name__ 사용 (동일한 결과)
{__name__="http_requests_total"}

# 장점: 메트릭 이름에 정규식 사용 가능!
```

#### 패턴 매칭

```promql
# http로 시작하는 모든 메트릭
{__name__=~"http_.*"}
# 결과: http_requests_total, http_response_size_bytes, http_duration_seconds...

# _total로 끝나는 모든 Counter
{__name__=~".*_total"}
# 결과: http_requests_total, errors_total, bytes_sent_total...

# node 또는 container로 시작하는 메트릭
{__name__=~"(node|container)_.*"}

# cpu 관련 메트릭 찾기
{__name__=~".*cpu.*"}
# 결과: node_cpu_seconds_total, container_cpu_usage_seconds_total...
```

#### 실전 활용

```promql
# 특정 job의 모든 메트릭 개수
count({job="api-server"})

# HTTP 관련 메트릭의 총 요청 수
sum(rate({__name__=~"http_requests.*"}[5m]))

# 메트릭 이름으로 그룹화
sum by (__name__) (rate({job="api-server"}[5m]))
```

#### 주의사항

```promql
# ❌ 너무 광범위한 패턴은 느림
{__name__=~".*"}  # 모든 메트릭 (매우 느림!)

# ✅ 구체적인 패턴 사용
{__name__=~"^http_.*", job="api-server"}
```

---

## 레이블 존재 여부 확인

### 레이블이 있는 것만 선택

#### 방법 1: 빈 문자열이 아닌 것

```promql
# error_code 레이블이 있고 비어있지 않음
http_requests_total{error_code!=""}

# 모든 값 매칭
http_requests_total{error_code=~".+"}
```

#### 방법 2: 구체적인 값들

```promql
# user_id가 있는 요청 (값은 상관없음)
http_requests_total{user_id=~".*"}
```

### 레이블이 없는 것만 선택

안타깝게도 직접적인 방법은 없지만 우회 가능:

```promql
# 전체에서 error_code가 있는 것을 뺌
http_requests_total
unless
http_requests_total{error_code=~".+"}

# 또는 absent() 함수 사용
absent(http_requests_total{error_code=""})
```

### 실전 예시

```promql
# 인증된 사용자 요청만 (user_id 있음)
sum(rate(http_requests_total{user_id!=""}[5m]))

# 익명 요청만 (user_id 없음)
sum(rate(http_requests_total[5m]))
unless
sum(rate(http_requests_total{user_id!=""}[5m]))

# 에러 코드가 설정된 요청
sum(rate(http_requests_total{error_code=~".+"}[5m]))
```

---

## 실전 활용 예시

### 예시 1: 에러 모니터링

#### 모든 에러 (4xx, 5xx)

```promql
# 초당 에러 수
sum(rate(http_requests_total{status=~"[45].."}[5m]))

# 에러율 (%)
sum(rate(http_requests_total{status=~"[45].."}[5m])) /
sum(rate(http_requests_total[5m])) * 100
```

#### 서버 에러만 (5xx)

```promql
# 5xx 에러 수
sum(rate(http_requests_total{status=~"5.."}[5m]))

# 엔드포인트별 5xx 에러
sum by (path) (rate(http_requests_total{status=~"5.."}[5m]))
```

#### 특정 에러 코드

```promql
# 404, 500, 503만
sum(rate(http_requests_total{status=~"404|500|503"}[5m]))

# 401, 403 (인증/권한 에러)
sum(rate(http_requests_total{status=~"40[13]"}[5m]))
```

#### 특정 경로의 에러율

```promql
# /api/users 경로의 에러율
sum(rate(http_requests_total{path="/api/users", status=~"[45].."}[5m])) /
sum(rate(http_requests_total{path="/api/users"}[5m])) * 100
```

---

### 예시 2: 환경별 트래픽

#### 프로덕션 트래픽

```promql
# 프로덕션 QPS
sum(rate(http_requests_total{env="production"}[5m]))

# 프로덕션 에러율
sum(rate(http_requests_total{env="production", status=~"5.."}[5m])) /
sum(rate(http_requests_total{env="production"}[5m])) * 100
```

#### 환경별 비교

```promql
# 스테이징 vs 프로덕션 트래픽
sum by (env) (
  rate(http_requests_total{env=~"production|staging"}[5m])
)

# 환경별 평균 응답 시간
avg by (env) (
  rate(http_request_duration_seconds_sum[5m]) /
  rate(http_request_duration_seconds_count[5m])
)
```

#### 개발 환경 제외

```promql
# dev, local 제외한 모든 트래픽
sum(rate(http_requests_total{env!~"dev|local"}[5m]))

# 프로덕션 유사 환경만 (prod, staging, qa)
sum(rate(http_requests_total{env=~"prod.*|staging|qa"}[5m]))
```

---

### 예시 3: 엔드포인트 성능 분석

#### API 엔드포인트만

```promql
# /api/ 경로의 P95 응답 시간
histogram_quantile(0.95,
  sum by (path, le) (
    rate(http_request_duration_seconds_bucket{path=~"/api/.*"}[5m])
  )
)

# API 버전별 트래픽
sum by (path) (
  rate(http_requests_total{path=~"/api/v[0-9]+/.*"}[5m])
)
```

#### 관리자 페이지

```promql
# /admin 경로 트래픽
sum(rate(http_requests_total{path=~"/admin/.*"}[5m]))

# 관리자 페이지 응답 시간
avg(rate(http_request_duration_seconds_sum{path=~"/admin/.*"}[5m]) /
    rate(http_request_duration_seconds_count{path=~"/admin/.*"}[5m]))
```

#### 정적 파일 제외

```promql
# 동적 콘텐츠만 (정적 파일 제외)
sum(rate(http_requests_total{path!~".*\\.(css|js|png|jpg|ico|svg)$"}[5m]))

# API 엔드포인트만 (확장자 없는 경로)
sum(rate(http_requests_total{path!~".*\\.[a-z]+$", path=~"/api/.*"}[5m]))
```

#### 특정 리소스 타입

```promql
# 사용자 관련 엔드포인트
sum by (path) (
  rate(http_requests_total{path=~".*/users?(/.*)?"}[5m])
)

# ID 포함 경로 (RESTful)
sum(rate(http_requests_total{path=~".*/[0-9]+$"}[5m]))
```

---

### 예시 4: 인스턴스/노드 그룹별 집계

#### 서버 타입별

```promql
# 웹 서버만
sum(rate(http_requests_total{instance=~"web-.*"}[5m]))

# 서버 타입별 CPU 사용률
avg by (server_type) (
  node_cpu_usage{instance=~"(web|api|db)-.*"}
)

# API 서버의 메모리 사용량
sum(node_memory_usage_bytes{instance=~"api-.*"})
```

#### 데이터센터별

```promql
# dc1, dc2, dc3 데이터센터별 트래픽
sum by (datacenter) (
  rate(http_requests_total{instance=~".*-(dc[1-3])-.*"}[5m])
)

# 특정 DC의 CPU 사용률
avg(node_cpu_usage{instance=~".*-dc1-.*"})
```

#### 프로덕션 노드만

```promql
# prod로 시작하는 인스턴스
avg(node_cpu_usage{instance=~"^prod-.*"})

# 프로덕션 웹 서버
sum(rate(http_requests_total{instance=~"^prod-web-.*"}[5m]))
```

#### 포트별

```promql
# 8xxx 포트의 트래픽
sum(rate(http_requests_total{instance=~".*:8[0-9]{3}"}[5m]))

# 표준 HTTP/HTTPS 포트
sum(rate(http_requests_total{instance=~".*:(80|443)$"}[5m]))
```

---

### 예시 5: 사용자 행동 분석

#### 인증 상태별

```promql
# 인증된 사용자 요청
sum(rate(http_requests_total{user_id!=""}[5m]))

# 익명 사용자 요청
sum(rate(http_requests_total{user_id=""}[5m]))

# 인증 실패 비율
sum(rate(http_requests_total{status="401"}[5m])) /
sum(rate(http_requests_total[5m])) * 100
```

#### 사용자 타입별

```promql
# 프리미엄 사용자
sum(rate(http_requests_total{user_tier="premium"}[5m]))

# 무료 vs 유료 사용자 비교
sum by (user_tier) (
  rate(http_requests_total{user_tier=~"free|premium"}[5m])
)
```

#### 디바이스/플랫폼별

```promql
# 모바일 트래픽
sum(rate(http_requests_total{user_agent=~".*Mobile.*"}[5m]))

# iOS vs Android
sum by (platform) (
  rate(http_requests_total{user_agent=~".*(iOS|Android).*"}[5m])
)

# 데스크톱 브라우저
sum(rate(http_requests_total{user_agent=~".*(Chrome|Firefox|Safari).*", user_agent!~".*Mobile.*"}[5m]))
```

---

## 성능 최적화

### 1. 매처 타입 선택

성능 순서 (빠름 → 느림):

```
= (완전 일치) > != (불일치) > =~ (정규식) > !~ (부정 정규식)
```

#### ✅ 좋은 예

```promql
# 완전 일치 사용 (빠름)
http_requests_total{method="GET", status="200"}

# 구체적인 조건 먼저
http_requests_total{job="api-server", method="GET", status=~"2.."}
```

#### ❌ 나쁜 예

```promql
# 불필요한 정규식 (느림)
http_requests_total{method=~"GET"}  # method="GET"으로 충분

# 너무 광범위한 조건
{__name__=~".*"}  # 모든 메트릭 (매우 느림!)
```

---

### 2. 정규식 최적화

#### 앵커 사용

```promql
# ❌ 비효율적: 모든 문자열 검사
instance=~".*prod.*"

# ✅ 효율적: 시작 패턴 명시
instance=~"^prod-.*"

# ✅ 더 효율적: 시작과 끝 명시
instance=~"^prod-web-[0-9]+$"
```

#### 구체적인 패턴

```promql
# ❌ 너무 포괄적
path=~"/api.*"

# ✅ 더 구체적
path=~"^/api/v[12]/.*$"

# ✅ 완전 일치 가능하면 사용
path="/api/users"
```

#### 불필요한 정규식 제거

```promql
# ❌ 정규식 불필요
status=~"200"

# ✅ 완전 일치 사용
status="200"

# ❌ OR는 정규식 필요 없음
method="GET" or method="POST"

# ✅ 정규식으로 간단히
method=~"GET|POST"
```

---

### 3. 카디널리티 관리

**카디널리티(Cardinality)**: 레이블 조합의 개수

#### ❌ 높은 카디널리티 (위험)

```promql
# user_id는 무한히 증가 → 메모리 폭발
http_requests_total{user_id="12345"}

# session_id도 마찬가지
http_requests_total{session_id="abc123..."}

# 타임스탬프를 레이블로 (절대 안 됨!)
http_requests_total{timestamp="2024-01-01T00:00:00Z"}
```

#### ✅ 낮은 카디널리티 (안전)

```promql
# 제한된 값만 사용
http_requests_total{method="GET"}  # 10개 이하
http_requests_total{status="200"}  # 수십 개

# 그룹화된 값
http_requests_total{user_tier="premium"}  # free, premium, enterprise
http_requests_total{region="us-east-1"}  # 리전 수는 제한적
```

#### 카디널리티 확인

```promql
# 메트릭의 시계열 개수
count(http_requests_total)

# 레이블 값의 개수
count(count by (status) (http_requests_total))

# 위험 신호: 10,000개 이상
count(http_requests_total) > 10000
```

---

### 4. 쿼리 구조 최적화

#### 필터 순서

```promql
# ✅ 좋은 예: 구체적인 조건 먼저
http_requests_total{
  job="api-server",          # 특정 job
  instance="web-1:8080",     # 특정 instance
  method=~"GET|POST",        # 그 다음 정규식
  path=~"/api/.*"            # 마지막 정규식
}

# ❌ 나쁜 예: 광범위한 조건 먼저
http_requests_total{
  path=~"/api/.*",           # 너무 많은 시계열
  method=~"GET|POST",
  job="api-server"
}
```

#### 조건 결합

```promql
# ❌ 비효율적: 두 번 쿼리
sum(rate(http_requests_total{method="GET"}[5m])) /
sum(rate(http_requests_total[5m]))

# ✅ 효율적: 한 번 계산 후 재사용
sum(rate(http_requests_total{method="GET"}[5m])) /
ignoring(method) group_left
sum(rate(http_requests_total[5m]))
```

---

## 자주 하는 실수

### 실수 1: 이스케이프 누락

#### 점(.) 이스케이프

```promql
# ❌ 잘못됨: 점이 정규식에서 "임의의 문자"
path=~"/api.v1"
# 매칭: /api.v1, /apixv1, /api/v1 (의도하지 않음)

# ✅ 올바름: 점을 이스케이프
path=~"/api\\.v1"
# 매칭: /api.v1만
```

#### 백슬래시 이스케이프

```promql
# ❌ 잘못됨
path=~"C:\Users"  # 오류!

# ✅ 올바름: 백슬래시를 두 번
path=~"C:\\\\Users"
```

---

### 실수 2: 앵커 누락

```promql
# ❌ 의도: "api로 시작"
# 실제: "api가 포함"
instance=~"api.*"
# 매칭: api-server, my-api-server, test-api-prod (의도하지 않음)

# ✅ 올바름: ^ 앵커 사용
instance=~"^api-.*"
# 매칭: api-server, api-prod만

# ❌ 의도: ".json으로 끝"
# 실제: ".json이 포함"
path=~".*\\.json"
# 매칭: /data.json, /data.json.bak (의도하지 않음)

# ✅ 올바름: $ 앵커 사용
path=~".*\\.json$"
# 매칭: /data.json만
```

---

### 실수 3: != 오해

```promql
# path!="/health"의 의미:
# "path 레이블이 있고, 그 값이 /health가 아닌 것"

# ❌ 오해: "path가 /health가 아닌 모든 것"
http_requests_total{path!="/health"}
# → path 레이블이 없는 시계열은 제외됨!

# ✅ 모든 시계열 포함하려면
http_requests_total
unless
http_requests_total{path="/health"}
```

**예시:**

```
원본 데이터:
http_requests_total{path="/api"} 100
http_requests_total{path="/health"} 50
http_requests_total{} 200  ← path 레이블 없음

쿼리: http_requests_total{path!="/health"}
결과:
✅ http_requests_total{path="/api"} 100
❌ http_requests_total{path="/health"} (제외)
❌ http_requests_total{} (의도와 다르게 제외됨!)
```

---

### 실수 4: 정규식 성능

```promql
# ❌ 매우 느림: 모든 문자열 검사
instance=~".*prod.*"
# 10,000개 시계열 → 각각 "prod" 포함 여부 검사

# ✅ 빠름: 명확한 패턴
instance=~"^prod-.*$"
# 인덱스로 "prod-"로 시작하는 것만 빠르게 필터

# ❌ 느림: 복잡한 패턴
path=~"(/api/v[0-9]+/users/[0-9]+/profile|/admin/.*|/health)"

# ✅ 빠름: 여러 조건으로 분리
(
  http_requests_total{path=~"^/api/v[0-9]+/users/.*"}
  or
  http_requests_total{path=~"^/admin/.*"}
  or
  http_requests_total{path="/health"}
)
```

---

### 실수 5: 대소문자 혼동

```promql
# Prometheus 레이블은 대소문자 구분!

# ❌ 매칭 안 됨
http_requests_total{method="get"}
# 실제 데이터: method="GET"

# ✅ 정확히 일치
http_requests_total{method="GET"}

# 💡 대소문자 무관하게 하려면
http_requests_total{method=~"(?i)get"}  # (?i)는 case-insensitive
```

---

## 디버깅 팁

### 1. 레이블 확인하기

#### Prometheus UI에서

```promql
# 메트릭의 모든 시계열과 레이블 보기
http_requests_total

# 특정 레이블의 모든 값 나열
count by (status) (http_requests_total)

# 결과:
# {status="200"} 1234
# {status="404"} 89
# {status="500"} 45
```

#### 레이블 조합 개수 (카디널리티)

```promql
# 총 시계열 개수
count(http_requests_total)
# 결과: 4567

# method별 시계열 개수
count by (method) (http_requests_total)

# 높은 카디널리티 경고
count(http_requests_total) > 10000
```

---

### 2. 정규식 테스트

#### 매칭 개수 확인

```promql
# 패턴 A
count(http_requests_total{status=~"2.."})
# 결과: 1000

# 패턴 B
count(http_requests_total{status=~"[23].."})
# 결과: 1500 (2xx, 3xx)

# 차이 확인
count(http_requests_total{status=~"[23].."}) -
count(http_requests_total{status=~"2.."})
# 결과: 500 (3xx만)
```

#### 점진적 테스트

```promql
# 1단계: 전체
http_requests_total

# 2단계: 첫 번째 조건 추가
http_requests_total{job="api-server"}

# 3단계: 두 번째 조건 추가
http_requests_total{job="api-server", method=~"GET|POST"}

# 4단계: 세 번째 조건 추가
http_requests_total{
  job="api-server",
  method=~"GET|POST",
  path=~"/api/.*"
}

# 각 단계마다 결과 개수 확인
count(http_requests_total{...})
```

---

### 3. 차이 비교

#### A에는 있고 B에는 없는 것

```promql
# 전체 - 성공 = 에러
http_requests_total
unless
http_requests_total{status="200"}

# GET - GET+200 = GET 에러만
http_requests_total{method="GET"}
unless
http_requests_total{method="GET", status="200"}
```

#### A와 B의 교집합

```promql
# GET이면서 2xx
http_requests_total{method="GET"}
and
http_requests_total{status=~"2.."}

# 동일한 결과 (더 간단)
http_requests_total{method="GET", status=~"2.."}
```

---

### 4. 샘플 데이터 확인

```promql
# 상위 10개 시계열
topk(10, http_requests_total)

# 특정 조건의 샘플
limit_sample(10, http_requests_total{status=~"5.."})

# 레이블 값 확인
sort_desc(
  count by (path) (http_requests_total)
)
```

---

## 치트시트

### 매처 타입

| 매처 | 문법 | 설명 | 예시 |
|------|------|------|------|
| **완전 일치** | `label="value"` | 정확히 일치 | `{method="GET"}` |
| **불일치** | `label!="value"` | 일치하지 않음 | `{method!="GET"}` |
| **정규식** | `label=~"pattern"` | 정규식 일치 | `{status=~"2.."}` |
| **부정 정규식** | `label!~"pattern"` | 정규식 불일치 | `{status!~"2.."}` |

### 정규식 메타문자

| 메타문자 | 의미 | 예시 | 매칭 |
|---------|------|------|------|
| `.` | 임의의 한 글자 | `2..` | 200, 201, 299 |
| `*` | 0개 이상 | `/api.*` | /api, /api/, /api/users |
| `+` | 1개 이상 | `web-[0-9]+` | web-1, web-123 |
| `?` | 0개 또는 1개 | `https?` | http, https |
| `\|` | OR | `GET\|POST` | GET, POST |
| `[]` | 문자 집합 | `[45]..` | 400, 500 |
| `()` | 그룹화 | `(prod\|staging)-.*` | prod-web, staging-db |
| `^` | 시작 | `^/api` | /api로 시작 |
| `$` | 끝 | `\\.json$` | .json으로 끝 |
| `\\` | 이스케이프 | `\\.` | 점 문자 그대로 |
| `{n}` | 정확히 n번 | `[0-9]{3}` | 200, 404 |
| `{n,m}` | n~m번 | `[0-9]{2,4}` | 80, 443, 8080 |
| `{n,}` | n번 이상 | `[0-9]{2,}` | 10, 100, 1000 |

### 자주 쓰는 패턴

| 목적 | 패턴 | 예시 |
|------|------|------|
| **2xx 상태** | `status=~"2.."` | 200, 201, 204 |
| **에러 (4xx, 5xx)** | `status=~"[45].."` | 404, 500, 503 |
| **API 경로** | `path=~"/api/.*"` | /api/users, /api/orders |
| **정적 파일** | `path=~".*\\.(css\|js\|png)$"` | style.css, app.js |
| **IP 주소** | `ip=~"192\\.168\\..*"` | 192.168.1.1 |
| **이메일** | `email=~".*@gmail\\.com"` | user@gmail.com |
| **버전** | `version=~"v[0-9]+\\..*"` | v1.2.3 |
| **숫자 ID** | `path=~".*/[0-9]+$"` | /users/123 |

### 성능 최적화 체크리스트

- ✅ 가능하면 `=` (완전 일치) 사용
- ✅ 정규식에 `^`, `$` 앵커 사용
- ✅ 구체적인 조건을 먼저 배치
- ✅ 높은 카디널리티 레이블 피하기
- ✅ `.*pattern.*` 대신 `^pattern-.*$` 사용
- ❌ `{__name__=~".*"}` 같은 광범위한 패턴 피하기
- ❌ 불필요한 정규식 피하기

### 디버깅 쿼리

```promql
# 시계열 개수
count(metric_name)

# 레이블 값 나열
count by (label_name) (metric_name)

# 상위 10개
topk(10, metric_name)

# 패턴 매칭 개수
count(metric_name{label=~"pattern"})

# A - B 차이
metric_name unless metric_name{condition}
```

---

## 학습 로드맵

### 1단계: 기초 (1주)

- `=`, `!=` 완전 일치/불일치
- 기본 정규식: `.`, `*`, `|`
- AND 조건 (콤마)

```promql
http_requests_total{method="GET"}
http_requests_total{method="GET", status="200"}
http_requests_total{status=~"2..|3.."}
```

### 2단계: 중급 (2주)

- 앵커: `^`, `$`
- 문자 집합: `[]`, `[^]`
- 반복: `+`, `?`, `{n,m}`
- `__name__` 메트릭 매칭

```promql
http_requests_total{path=~"^/api/.*$"}
http_requests_total{status=~"[45].."}
{__name__=~"http_.*", job="api-server"}
```

### 3단계: 고급 (1개월)

- 복잡한 패턴 조합
- 성능 최적화
- 카디널리티 관리
- 디버깅 기법

```promql
http_requests_total{
  instance=~"^(prod|staging)-web-[0-9]+:8[0-9]{3}$",
  path!~".*\\.(css|js|png)$|/health|/metrics",
  status=~"[45].."
}
```

---

## 참고 자료

- [Prometheus 공식 문서 - Querying](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [RE2 정규식 문법](https://github.com/google/re2/wiki/Syntax)
- [PromQL 치트시트](https://promlabs.com/promql-cheat-sheet/)
- [Prometheus Best Practices](https://prometheus.io/docs/practices/naming/)

---

## 마치며

레이블 매처는 PromQL의 가장 기초이자 핵심입니다. 이를 잘 활용하면:

- 🎯 **정확한 데이터 선택**: 원하는 시계열만 정확히 필터링
- 🚀 **빠른 쿼리**: 효율적인 패턴으로 성능 향상
- 🔍 **효과적인 모니터링**: 복잡한 시스템도 원하는 각도로 관찰
- 💰 **비용 절감**: 카디널리티 관리로 메모리 사용 최적화

**연습이 중요합니다!** 실제 데이터로 다양한 패턴을 시도해보세요. 처음에는 간단한 조건부터 시작해서 점진적으로 복잡한 패턴으로 발전시키세요.

Happy Querying! 🎯📊
