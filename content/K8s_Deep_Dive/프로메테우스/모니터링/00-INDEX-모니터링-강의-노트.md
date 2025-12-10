---
title: 📖 모니터링 강의 노트 인덱스 - Exporter와 Istio 통합
tags:
  - 목차
  - Prometheus
  - 인덱스
  - 모니터링
  - Exporter
  - Istio
  - Blackbox
aliases:
  - 모니터링목차
  - Exporter학습가이드
date: 2025-12-09
category: K8s_Deep_Dive/프로메테우스/모니터링
status: 완성
priority: 높음
---

# 📖 모니터링 강의 노트 인덱스

> [!note] 수업 내용 기반 체계적 정리
> 2025년 12월 9일 수업 내용을 바탕으로 **Exporter 개념부터 Istio 통합까지** 정리한 실무 모니터링 가이드

## 🎯 시리즈 개요

### 💡 학습 목표
```yaml
핵심 이해:
  - Exporter가 왜 필요한지 완전 이해
  - 관측성 3대 축 (Metrics/Logs/Traces) 파악
  - 블랙박스 모니터링의 필요성
  - Istio 환경에서의 모니터링 통합

실무 적용:
  - 트레이드오프 관점에서 도구 선택
  - 4 Golden Signals 기반 모니터링
  - 올바른 설치 순서 이해
  - 문제 해결 능력 배양
```

### 📚 학습 흐름
```
개념 → 판단 → 도구 → 통합 → 실무
  ↓       ↓      ↓      ↓       ↓
 01-02  06-07  04-05  08-09   실전
```

---

## 📋 시리즈 구성

### 📖 01편: Exporter 개념
**파일**: [[01-Exporter-개념]]

> [!note] 핵심 질문
> "Redis나 MySQL 모니터링할 때 왜 Exporter를 꼭 배포하나요?"

**핵심 내용**:
- Prometheus의 언어 장벽
- Exporter = 통역사
- 3단계 동작 방식 (수집→번역→제공)
- 왜 YAML로 따로 배포하나

**주요 포인트**:
```yaml
- Prometheus 형식: redis_up 1
- 기존 앱 형식: INFO 명령어 → 텍스트 덩어리
- Exporter: 양쪽 언어를 모두 아는 통역사
- /metrics 엔드포인트 제공
```

---

### 🎯 02편: Exporter 사용 시나리오
**파일**: [[02-Exporter-사용-시나리오]]

> [!tip] 판단 기준
> "그 소프트웨어가 태어난 시대"를 보라

**핵심 내용**:
- 필요한 경우: 레거시 앱 (MySQL, Redis)
- 불필요한 경우: 클라우드 네이티브 앱 (K8s, Istio)
- 판단 체크리스트
- 실무 사례

**비교표**:
| 애플리케이션 | Exporter 필요 | 이유 |
|------------|-------------|------|
| MySQL, Redis | ✅ | Prometheus 형식 미지원 |
| Kubernetes | ❌ | /metrics 내장 |
| Nginx | ✅ | 상태 페이지는 다른 형식 |
| 직접 개발한 앱 | ❌ | 라이브러리로 직접 구현 |

---

### 🔍 03편: 관측성 3대 축
**파일**: [[03-관측성-3대-축]]

> [!example] 실무 시나리오
> "하나의 도구로는 부족하다! 세 가지 관점이 필요하다"

**핵심 내용**:
- **Metrics**: 숫자 데이터 (Prometheus)
- **Logs**: 텍스트 데이터 (ELK, Loki)
- **Traces**: 요청 흐름 (Jaeger)
- 장애 대응 3단계

**장애 대응 시나리오**:
```yaml
1단계 Metrics: "어디가" 문제인지 파악
  → MySQL 응답시간 급증

2단계 Logs: "무슨" 에러인지 확인
  → "Lock wait timeout exceeded"

3단계 Traces: "어느 부분이" 느린지 식별
  → /api/order에서 긴 트랜잭션
```

---

### 🎯 07편: 4 Golden Signals
**파일**: [[07-4-Golden-Signals]]

> [!note] Google SRE 권장
> 무엇을 모니터링할지 모르겠다면? → 이 4가지부터!

**핵심 내용**:
1. **Latency**: 얼마나 빠르게?
2. **Traffic**: 얼마나 많이?
3. **Errors**: 얼마나 실패?
4. **Saturation**: 얼마나 찼나?

**MySQL 적용 예시**:
```promql
# 1. Latency
mysql_global_status_slow_queries

# 2. Traffic
mysql_global_status_queries

# 3. Errors
mysql_global_status_connection_errors_total

# 4. Saturation
mysql_global_status_threads_connected /
mysql_global_variables_max_connections
```

---

### 🔧 04편: Prometheus Blackbox Exporter
**파일**: [[04-Prometheus-Blackbox-Exporter]]

> [!warning] 핵심 철학
> "서버가 살아있다" ≠ "사용자가 쓸 수 있다"

**핵심 내용**:
- 화이트박스 vs 블랙박스
- 왜 prefix가 `probe_`인가
- ConfigMap이 필요한 이유
- 유용한 경우 vs 불필요한 경우

**트레이드오프**:
| 항목 | 장점 ✅ | 단점 ❌ |
|------|--------|--------|
| 관점 | 사용자 경험 그대로 | 원인 파악 어려움 |
| 설정 | 간단 (URL만) | 복잡한 시나리오 제한 |
| 범위 | 외부 서비스 가능 | 깊은 분석 불가 |

---

### 💼 06편: 모니터링 트레이드오프
**파일**: [[06-모니터링-트레이드오프]]

> [!tip] 실무 핵심 원칙
> "뭘 할 수 있나"보다 "언제, 왜 해야 하나"

**핵심 내용**:
- 기술 선택 질문 리스트
- 비용 계산 (시간, 리소스, 기회)
- 단계별 접근 (Phase 1-4)
- 알람 피로 관리

**의사결정 프레임워크**:
```yaml
질문 리스트:
  □ 팀 규모는? (2명 vs 20명)
  □ 예산은? (돈 vs 시간)
  □ 인프라는? (클라우드 vs 온프레미스)
  □ 긴급도는? (장애 감지 vs 최적화)
  □ 기존 스택은?
```

---

### 🏗️ 08편: Istio 모니터링 통합
**파일**: [[08-Istio-모니터링-통합]]

> [!danger] 복잡도 폭발
> Istio를 추가하면 기존 모니터링이 **폭발**합니다!

**핵심 내용**:
- 3가지 주요 문제
  1. 외부 타겟 접근 불가
  2. Prometheus 메트릭 수집 불가
  3. Health Check 실패로 Pod 재시작
- ServiceEntry, PeerAuthentication
- 실무 권장 패턴

**해결 요약**:
| 문제 | 원인 | 해결 |
|------|------|------|
| 외부 접근 안 됨 | Istio 외부 차단 | ServiceEntry 또는 네임스페이스 Istio 제외 |
| 메트릭 수집 안 됨 | mTLS 인증 실패 | 네임스페이스 Istio 제외 (권장) |
| Pod 재시작 반복 | Health check 실패 | Probe 설정 수정 또는 Istio 제외 |

---

### 🚀 09편: 모니터링 스택 설치 순서
**파일**: [[09-모니터링-스택-설치-순서]]

> [!note] 핵심 원칙
> 외우지 말고 "레이어"로 이해하라

**핵심 내용**:
- 레이어 구조 (K8s → Istio → Prometheus → Kiali)
- 왜 이 순서인가?
- 데이터 흐름 이해
- ConfigMap 수정이 필요한 이유

**설치 원칙**:
```yaml
아래에서 위로:
  Layer 1: Kubernetes (기반)
  Layer 2: Istio (메트릭 생성)
  Layer 3: Prometheus (메트릭 수집)
  Layer 4: Kiali (시각화)

원칙:
  데이터 생성 → 수집 → 저장 → 시각화
```

---

## 🎯 학습 순서 추천

### 초급 (1주차)
```yaml
기본 이해:
  - [ ] [[01-Exporter-개념]] - Exporter가 뭐지?
  - [ ] [[02-Exporter-사용-시나리오]] - 언제 필요해?
  - [ ] [[03-관측성-3대-축]] - 전체 그림 이해
```

### 중급 (2-3주차)
```yaml
실무 적용:
  - [ ] [[07-4-Golden-Signals]] - 무엇을 측정?
  - [ ] [[04-Prometheus-Blackbox-Exporter]] - 외부 모니터링
  - [ ] [[06-모니터링-트레이드오프]] - 언제 도입?
```

### 고급 (4주차+)
```yaml
복잡한 환경:
  - [ ] [[08-Istio-모니터링-통합]] - Istio 문제 해결
  - [ ] [[09-모니터링-스택-설치-순서]] - 아키텍처 이해
```

---

## 🔗 연관 문서

### 📚 프로메테우스 시리즈 연관성

```yaml
기반 지식:
  - [[../00_프로메테우스_시리즈_목차]] - 전체 목차
  - [[../01_프로메테우스_기초_개념_완벽_정리]] - 기초 개념
  - [[../02_모니터링_파이프라인_완벽_이해]] - 파이프라인 구조

PromQL 학습:
  - [[../07_PromQL_메트릭_타입_완벽_가이드]] - 메트릭 타입
  - [[../08_PromQL_레이블_매처_완벽_가이드]] - 레이블 매칭
  - [[../09_PromQL_핵심_개념_정리]] - PromQL 쿼리
```

---

**📅 작성일**: 2025년 12월 9일
**📖 총 학습 시간**: 약 3-4시간 (집중 학습 기준)
**🎯 완료 후 수준**: Exporter 개념부터 Istio 통합까지 실무 적용 가능
