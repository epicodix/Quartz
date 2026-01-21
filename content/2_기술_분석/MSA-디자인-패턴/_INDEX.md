---
title: MSA 디자인 패턴 디렉토리 인덱스
tags:
  - index
  - MSA
  - architecture
  - design-patterns
date: 2026-01-05
status: 완성
---

# 📚 MSA 디자인 패턴 학습 디렉토리

> [!info] 디렉토리 목적
> 이 디렉토리는 2026년 현대적인 마이크로서비스 아키텍처(MSA) 디자인 패턴을 체계적으로 학습하기 위한 지식 베이스입니다. 각 패턴은 독립적인 문서로 작성되어 있으며, MOC(Map of Contents) 방식으로 구조화되어 있습니다.

---

## 🎯 AI를 위한 디렉토리 가이드

### 📋 이 디렉토리를 읽는 방법

1. **시작점**: `00-MSA-디자인-패턴-MOC.md` 문서부터 읽으세요
2. **폴더별 가이드**: 각 폴더의 `_README.md`에 해당 카테고리 개요가 있습니다
3. **완성도 확인**: 각 문서의 YAML frontmatter `status` 필드를 확인하세요
   - `완성`: 학습 가능한 완전한 문서
   - `작성중`: 기본 구조는 있으나 내용 보강 필요
   - `계획중`: 템플릿만 있고 내용 작성 필요
4. **관계 파악**: `related`, `prerequisites` 필드로 문서 간 관계 확인

---

## 📂 디렉토리 구조

```
MSA-디자인-패턴/
├── _INDEX.md                                    ← 현재 문서 (전체 가이드)
├── 00-MSA-디자인-패턴-MOC.md                    ← 메인 허브 (여기서 시작)
│
├── 01-통신-패턴/                                ← Communication Patterns
│   ├── _README.md                              (폴더 개요)
│   ├── API-Gateway-패턴.md                     [완성]
│   ├── 서비스-디스커버리-패턴.md                [완성]
│   ├── Service-Mesh-패턴.md                    [완성]
│   └── Event-Driven-Architecture.md            [완성]
│
├── 02-데이터-관리-패턴/                         ← Data Management Patterns
│   ├── _README.md                              (폴더 개요)
│   ├── Database-per-Service.md                 [완성]
│   ├── Saga-패턴.md                            [완성]
│   ├── CQRS-패턴.md                            [완성]
│   └── Event-Sourcing-패턴.md                  [완성]
│
├── 03-복원력-패턴/                              ← Resilience Patterns
│   ├── _README.md                              (폴더 개요)
│   ├── 서킷브레이커-패턴.md                     [완성]
│   ├── Retry-패턴.md                           [완성]
│   ├── Timeout-패턴.md                         [완성]
│   ├── Bulkhead-패턴.md                        [완성]
│   └── Rate-Limiter-패턴.md                    [완성]
│
├── 04-배포-인프라-패턴/                         ← Deployment Patterns
│   ├── _README.md                              (폴더 개요)
│   ├── Blue-Green-Deployment.md                [완성]
│   ├── Canary-Deployment-패턴.md               [완성]
│   ├── Sidecar-패턴.md                         [완성]
│   └── Ambassador-패턴.md                      [완성]
│
├── 05-보안-거버넌스-패턴/                       ← Security & Governance
│   ├── _README.md                              (폴더 개요)
│   ├── API-Gateway-Security.md                 [완성]
│   ├── Zero-Trust-Architecture.md              [완성]
│   └── Service-to-Service-Auth.md              [완성]
│
└── 99-실전-적용/                                ← Practical Application
    ├── _README.md                              (실전 가이드)
    ├── 실습/                                    (실습 자료)
    └── 케이스스터디/                            (사례 연구)
```

---

## 📊 완성도 현황 (2026-01-05 기준)

### ✅ 완성된 문서 (21개)

**통신 패턴 (4개)**
- [x] API Gateway 패턴
- [x] 서비스 디스커버리 패턴
- [x] Service Mesh 패턴
- [x] Event-Driven Architecture

**데이터 관리 패턴 (4개)**
- [x] Database per Service
- [x] Saga 패턴
- [x] CQRS 패턴
- [x] Event Sourcing 패턴

**복원력 패턴 (5개)**
- [x] 서킷브레이커 패턴
- [x] Retry 패턴
- [x] Timeout 패턴
- [x] Bulkhead 패턴
- [x] Rate Limiter 패턴

**배포 & 인프라 패턴 (4개)**
- [x] Blue-Green Deployment
- [x] Canary Deployment 패턴
- [x] Sidecar 패턴
- [x] Ambassador 패턴

**보안 & 거버넌스 (3개)**
- [x] API Gateway Security
- [x] Zero Trust Architecture
- [x] Service-to-Service Auth

**실전 적용 (1개)**
- [x] 실전 적용 가이드 (_README.md)

---

## 🚀 개발 우선순위 및 TODO

### 🔴 높은 우선순위

현재 모든 핵심 패턴 문서가 완성되었습니다.

### 🟡 중간 우선순위 (향후 추가 예정)

**99-실전-적용 폴더 보강**
- [ ] 학습-로드맵.md 작성
- [ ] 패턴-선택-가이드.md 작성
- [ ] 2026-추천-아키텍처-스택.md 작성
- [ ] 실전-체크리스트.md 작성

**실습 자료**
- [ ] Kafka 실습 (Event-Driven Architecture)
- [ ] Istio 실습 (Service Mesh)
- [ ] Axon Framework 실습 (Event Sourcing + CQRS)
- [ ] Saga 패턴 구현 (Choreography vs Orchestration)

**케이스 스터디**
- [ ] Netflix MSA 전환 사례
- [ ] 금융권 Event Sourcing 적용 사례
- [ ] 대규모 트래픽 처리 (쿠팡, 배민)

**고급 주제**
- [ ] AI/ML 워크로드를 위한 MSA
- [ ] Multi-tenancy 패턴
- [ ] Data Mesh 아키텍처

### 🟢 낮은 우선순위

**도구 및 프레임워크 상세**
- [ ] Spring Cloud 상세 가이드
- [ ] Kubernetes Operators 패턴
- [ ] Service Mesh 비교 (Istio vs Linkerd vs Consul)

---

## 🎓 학습 순서 추천

### 초급 (MSA 입문)

1. [[00-MSA-디자인-패턴-MOC]] - 전체 개요
2. [[01-통신-패턴/API-Gateway-패턴]] - 가장 기본적인 패턴
3. [[02-데이터-관리-패턴/Database-per-Service]] - MSA의 핵심 원칙
4. [[03-복원력-패턴/서킷브레이커-패턴]] - 장애 처리의 기본
5. [[03-복원력-패턴/Retry-패턴]] - 재시도 패턴
6. [[03-복원력-패턴/Timeout-패턴]] - 타임아웃 설정

### 중급 (실무 적용)

7. [[01-통신-패턴/서비스-디스커버리-패턴]] - 동적 서비스 탐색
8. [[01-통신-패턴/Event-Driven-Architecture]] - 비동기 통신의 핵심
9. [[02-데이터-관리-패턴/Saga-패턴]] - 분산 트랜잭션 관리
10. [[01-통신-패턴/Service-Mesh-패턴]] - 현대적 통신 인프라
11. [[04-배포-인프라-패턴/Sidecar-패턴]] - Service Mesh의 기반
12. [[04-배포-인프라-패턴/Blue-Green-Deployment]] - 무중단 배포
13. [[04-배포-인프라-패턴/Canary-Deployment-패턴]] - 점진적 배포
14. [[03-복원력-패턴/Bulkhead-패턴]] - 리소스 격리
15. [[03-복원력-패턴/Rate-Limiter-패턴]] - 속도 제한

### 고급 (아키텍처 설계)

16. [[02-데이터-관리-패턴/CQRS-패턴]] - 읽기/쓰기 분리
17. [[02-데이터-관리-패턴/Event-Sourcing-패턴]] - 이벤트 기반 상태 관리
18. [[05-보안-거버넌스-패턴/API-Gateway-Security]] - API 보안
19. [[05-보안-거버넌스-패턴/Zero-Trust-Architecture]] - 보안 강화
20. [[05-보안-거버넌스-패턴/Service-to-Service-Auth]] - 서비스 간 인증
21. [[04-배포-인프라-패턴/Ambassador-패턴]] - 프록시 패턴

---

## 🔗 문서 간 관계 맵

### 함께 사용되는 패턴 조합

**Event-Driven 스택**
```
Event-Driven Architecture
    ├─→ Event Sourcing (이벤트 저장)
    ├─→ CQRS (읽기/쓰기 분리)
    └─→ Saga (분산 트랜잭션)
```

**복원력 스택**
```
Service Mesh
    ├─→ Circuit Breaker (장애 차단)
    ├─→ Retry & Timeout (재시도)
    └─→ Bulkhead (리소스 격리)
```

**배포 스택**
```
Sidecar Pattern
    ├─→ Service Mesh (통신 관리)
    ├─→ Blue-Green Deployment (안전한 배포)
    └─→ Canary Deployment (점진적 배포)
```

**마이그레이션 스택**
```
Strangler Fig Pattern
    ├─→ API Gateway (라우팅 제어)
    └─→ Database per Service (데이터 분리)
```

---

## 📝 문서 작성 규칙

### YAML Frontmatter 필수 필드

모든 문서는 다음 frontmatter를 포함해야 합니다:

```yaml
---
title: [패턴명] - [부제목]
tags:
  - [카테고리]
  - [기술스택]
  - MSA
  - design-patterns
aliases:
  - [별명1]
  - [별명2]
date: YYYY-MM-DD
category: MSA-디자인-패턴/[폴더명]
status: 완성 | 작성중 | 계획중
priority: 높음 | 중간 | 낮음
difficulty: 초급 | 중급 | 고급
related:
  - "[[관련문서1]]"
  - "[[관련문서2]]"
prerequisites:
  - "[[선행학습1]]"
next_steps:
  - "[[다음학습1]]"
---
```

### 문서 구조 템플릿

```markdown
# 🎯 [패턴명]

> [!note] 패턴 개요
> [한 문장 요약]

## 📑 목차
- [[#1. 핵심 개념|핵심 개념]]
- [[#2. 문제와 해결|문제와 해결]]
- [[#3. 아키텍처|아키텍처]]
- [[#4. 실제 구현|실제 구현]]
- [[#5. 장단점|장단점]]
- [[#6. 사용 시기|사용 시기]]
- [[#7. 실전 사례|실전 사례]]

---

## 1. 핵심 개념
[핵심 개념 설명]

## 2. 문제와 해결
### 해결하려는 문제
### 패턴의 해결 방법

## 3. 아키텍처
[다이어그램 및 구조 설명]

## 4. 실제 구현
### 4.1 기술 스택
### 4.2 코드 예시

## 5. 장단점
### ✅ 장점
### ❌ 단점

## 6. 사용 시기
### 적합한 경우
### 부적합한 경우

## 7. 실전 사례
[실제 기업/프로젝트 사례]

## 📚 참고 자료
```

---

## 🤖 AI 에이전트를 위한 지침

### 새로운 패턴 추가 시

1. **적절한 폴더 선택**: 패턴의 카테고리에 맞는 폴더에 배치
2. **Frontmatter 작성**: 위의 템플릿 필수 필드 모두 작성
3. **관계 설정**: `related`, `prerequisites` 필드로 다른 문서와 연결
4. **MOC 업데이트**: `00-MSA-디자인-패턴-MOC.md`에 새 패턴 추가
5. **이 INDEX 업데이트**: 완성도 현황 및 TODO 업데이트

### 기존 패턴 보강 시

1. **Status 확인**: frontmatter의 `status` 필드 확인
2. **실습 추가**: 해당 폴더의 `실습/` 하위 폴더에 추가
3. **케이스 스터디 추가**: `케이스스터디/` 하위 폴더에 추가
4. **Status 업데이트**: 작업 완료 후 `status` 필드 갱신

### 문서 검색 및 참조

1. **키워드 검색**: 옵시디언 검색 또는 grep 활용
2. **태그 활용**: `tags` 필드로 관련 문서 찾기
3. **그래프 뷰**: 옵시디언 그래프 뷰로 관계 시각화
4. **역링크**: 어떤 문서가 현재 문서를 참조하는지 확인

---

## 📞 연락 및 피드백

이 지식 베이스에 대한 개선 사항이나 추가할 내용이 있다면:
- TODO 섹션에 추가
- 관련 문서의 frontmatter에 `status: 작성중` 표시
- 구체적인 개선 방향을 코멘트로 남기기

---

## 🔄 마지막 업데이트

- **날짜**: 2026-01-05
- **주요 변경**: 전체 디렉토리 구조 및 파일명 정리, 21개 패턴 완성 반영
- **완성 패턴**: 21개 (통신 4개, 데이터 4개, 복원력 5개, 배포 4개, 보안 3개, 실전 1개)
- **다음 계획**: 99-실전-적용 폴더 문서 작성 (학습 로드맵, 패턴 선택 가이드 등)
