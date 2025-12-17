# 01. Grafana 기초 개념 완벽 정리

> **학습 목표**: Grafana가 무엇이고, 왜 사용하는지, 핵심 개념을 이해한다.

---

## 📌 Grafana란?

### 정의
**Grafana**는 오픈소스 메트릭 시각화 및 분석 플랫폼입니다.

```
데이터소스 → Grafana → 대시보드 → 사용자
(Prometheus,  (쿼리 & 변환)  (그래프, 테이블)  (모니터링)
 Loki, MySQL)
```

### 핵심 특징
1. **다양한 데이터소스 지원**: Prometheus, Loki, MySQL, PostgreSQL, CloudWatch 등 50+ 통합
2. **강력한 시각화**: Time series, Logs, Bar chart, Pie chart, Heatmap 등
3. **알림 기능**: 임계값 기반 알림, Slack/Email/PagerDuty 연동
4. **플러그인 생태계**: 커뮤니티 대시보드 및 플러그인

---

## 🏗️ Grafana 아키텍처

### 전체 구조
```
┌─────────────────────────────────────────────────┐
│                   User Browser                  │
│              (Dashboard 접속)                    │
└───────────────────┬─────────────────────────────┘
                    │ HTTP/HTTPS
┌───────────────────▼─────────────────────────────┐
│              Grafana Server                     │
│  ┌──────────────┐  ┌──────────────┐            │
│  │  Dashboard   │  │   Plugins    │            │
│  │   Engine     │  │   (Panel)    │            │
│  └──────────────┘  └──────────────┘            │
│  ┌──────────────────────────────────┐          │
│  │    Data Source Plugins           │          │
│  │  (Prometheus, Loki, MySQL...)    │          │
│  └──────────────┬───────────────────┘          │
└─────────────────┼───────────────────────────────┘
                  │ 쿼리 전송
┌─────────────────▼───────────────────────────────┐
│            Data Sources                         │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐     │
│  │Prometheus│  │   Loki   │  │  MySQL   │     │
│  └──────────┘  └──────────┘  └──────────┘     │
└─────────────────────────────────────────────────┘
```

### 주요 컴포넌트

#### 1. **Dashboard (대시보드)**
- 여러 Panel의 집합
- JSON 형태로 저장
- 버전 관리 가능
- URL로 공유 가능

#### 2. **Panel (패널)**
- 대시보드의 기본 단위
- 하나의 쿼리 + 시각화
- Time series, Stat, Logs, Table 등 다양한 타입

#### 3. **Data Source (데이터소스)**
- 실제 데이터를 가져오는 출처
- 각 데이터소스마다 고유한 쿼리 언어 사용
  - Prometheus → PromQL
  - Loki → LogQL
  - MySQL → SQL

#### 4. **Query (쿼리)**
- 데이터소스에서 데이터를 가져오는 명령
- 각 Panel마다 하나 이상의 쿼리 설정 가능

#### 5. **Variables (변수)**
- 대시보드를 동적으로 만드는 기능
- 드롭다운으로 선택 가능
- 예: 네임스페이스, Pod 이름 선택

---

## 🎨 Grafana vs 다른 도구

### Grafana vs Kibana

| 특징 | Grafana | Kibana |
|------|---------|--------|
| **주 용도** | 메트릭 + 로그 시각화 | 로그 분석 (ELK Stack) |
| **데이터소스** | 다양한 소스 지원 | 주로 Elasticsearch |
| **쿼리 언어** | 소스별 (PromQL, LogQL 등) | KQL (Kibana Query Language) |
| **학습 곡선** | 중간 | 높음 |
| **비용** | 오픈소스 (무료) | 오픈소스 + Enterprise |
| **강점** | 유연성, 통합성 | 로그 검색, 분석 |

### Grafana vs Datadog

| 특징 | Grafana | Datadog |
|------|---------|---------|
| **배포 방식** | Self-hosted | SaaS (클라우드) |
| **비용** | 무료 (오픈소스) | 유료 (호스트당 과금) |
| **설정 복잡도** | 높음 (직접 구성) | 낮음 (관리형) |
| **커스터마이징** | 매우 높음 | 제한적 |
| **적합한 환경** | On-premise, K8s | 멀티 클라우드 |

---

## 🔑 핵심 개념

### 1. Time Range (시간 범위)
모든 쿼리는 시간 범위를 가집니다.

```
Last 5 minutes  → now-5m ~ now
Last 1 hour     → now-1h ~ now
Last 24 hours   → now-24h ~ now
Custom          → 2025-01-01 ~ 2025-01-31
```

### 2. Refresh Rate (갱신 주기)
대시보드가 자동으로 데이터를 갱신하는 주기

```
5s, 10s, 30s, 1m, 5m, 15m, 30m, 1h
Live (실시간)
```

### 3. Annotation (주석)
대시보드에 이벤트를 표시하는 기능

```
예: "배포 완료", "장애 발생", "스케일 아웃"
→ 그래프 위에 수직선으로 표시
```

### 4. Alert (알림)
특정 조건을 만족하면 알림을 발송

```
조건: CPU > 80% for 5 minutes
알림: Slack, Email, PagerDuty
```

---

## 📊 Grafana의 강점

### 1. **통합 모니터링**
하나의 대시보드에서 여러 데이터 소스 통합 가능

```
┌─────────────────────────────────────┐
│        통합 대시보드                │
├─────────────────────────────────────┤
│  [Prometheus] CPU, Memory           │
│  [Loki] 애플리케이션 로그            │
│  [MySQL] 비즈니스 메트릭             │
│  [CloudWatch] AWS 리소스            │
└─────────────────────────────────────┘
```

### 2. **재사용 가능한 대시보드**
- JSON 형태로 import/export
- Grafana.com에서 커뮤니티 대시보드 다운로드
- 버전 관리 시스템에 저장 가능

### 3. **강력한 변수 시스템**
동적 대시보드 생성 가능

```
변수 $namespace 선택: kube-system
→ 모든 Panel의 쿼리에 자동 적용
→ {namespace="$namespace"}
```

### 4. **플러그인 생태계**
- Panel 플러그인: 새로운 시각화 타입 추가
- Data Source 플러그인: 새로운 데이터 소스 연결
- App 플러그인: 전체 앱 통합

---

## 🎯 Grafana의 활용 사례

### 1. **인프라 모니터링**
```
대시보드: Kubernetes Cluster Monitoring
- CPU/Memory 사용률 (Prometheus)
- Pod 상태 (kube-state-metrics)
- 네트워크 트래픽 (node-exporter)
```

### 2. **애플리케이션 로그 분석**
```
대시보드: Application Logs
- 에러율 추세 (Loki)
- 로그 레벨 분포 (Loki)
- 실시간 로그 스트림 (Loki)
```

### 3. **비즈니스 메트릭**
```
대시보드: Business Metrics
- 일일 주문 수 (MySQL)
- 매출 추이 (PostgreSQL)
- 사용자 활동 (InfluxDB)
```

### 4. **SRE/DevOps**
```
대시보드: SLO/SLI Monitoring
- Availability (99.9% uptime)
- Latency (p50, p95, p99)
- Error Rate (< 0.1%)
```

---

## 🧩 Grafana + Loki 조합의 강점

### 왜 Grafana + Loki인가?

#### 1. **비용 효율성**
```
기존: ELK Stack (Elasticsearch)
→ 모든 필드를 인덱싱 → 저장 공간 많이 필요

Loki: 레이블만 인덱싱
→ 로그 내용은 압축 저장 → 저장 공간 절약
```

#### 2. **Kubernetes 네이티브**
```
Promtail (DaemonSet)
→ 모든 노드에서 자동으로 Pod 로그 수집
→ 레이블 자동 추가 (namespace, pod, container)
```

#### 3. **Prometheus와 일관된 경험**
```
PromQL: rate(http_requests_total[5m])
LogQL:  rate({job="nginx"}[5m])

→ 유사한 문법, 학습 곡선 낮음
```

#### 4. **통합 대시보드**
```
하나의 대시보드에서:
- CPU 급증 (Prometheus 메트릭)
- 에러 로그 급증 (Loki 로그)
→ 상관관계 분석 쉬움
```

---

## 📚 용어 정리

| 용어 | 설명 | 예시 |
|------|------|------|
| **Dashboard** | 여러 Panel의 집합 | "Kubernetes Monitoring" |
| **Panel** | 하나의 시각화 단위 | CPU 사용률 그래프 |
| **Data Source** | 데이터 출처 | Prometheus, Loki |
| **Query** | 데이터 가져오기 명령 | `{namespace="demo-app"}` |
| **Variable** | 대시보드 변수 | `$namespace`, `$pod` |
| **Annotation** | 이벤트 표시 | "배포 완료" 마커 |
| **Alert** | 알림 규칙 | CPU > 80% 시 Slack 알림 |
| **PromQL** | Prometheus 쿼리 언어 | `rate(http_requests[5m])` |
| **LogQL** | Loki 쿼리 언어 | `{job="nginx"} \|= "error"` |

---

## 🎓 다음 단계

이제 Grafana의 기본 개념을 이해했으니:
1. [[02_Loki_아키텍처_완벽_이해|Loki 아키텍처]] 학습
2. [[04_Loki_Promtail_설치_가이드|실습 환경 구축]]
3. [[03_Grafana_Explore_활용법|Explore 실습]]

---

## ✅ 학습 체크

- [ ] Grafana가 무엇인지 설명할 수 있다
- [ ] Dashboard와 Panel의 차이를 이해한다
- [ ] Data Source의 역할을 안다
- [ ] Grafana와 Kibana의 차이를 설명할 수 있다
- [ ] Grafana + Loki 조합의 강점을 이해한다

---

**다음**: [[02_Loki_아키텍처_완벽_이해|02. Loki 아키텍처 완벽 이해]]
