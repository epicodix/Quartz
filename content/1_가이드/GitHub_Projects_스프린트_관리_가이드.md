---
title: GitHub Projects 기반 스프린트 관리 가이드
tags:
  - GitHub
  - ProjectManagement
  - Agile
  - Sprint
  - TeamCollaboration
aliases:
  - 스프린트 관리 가이드
  - GitHub Projects 활용법
date: 2026-02-12
category: 1_가이드/프로젝트관리
status: 완성
priority: 높음
---

# 🎯 GitHub Projects 기반 스프린트 관리 가이드

## 📑 목차
- [[#1. 왜 GitHub Projects로 관리하는가?|왜 GitHub Projects로 관리하는가?]]
- [[#2. 기본 설정|기본 설정]]
- [[#3. 스프린트 흐름 관리|스프린트 흐름 관리]]
- [[#4. 실전 예시|실전 예시]]
- [[#5. 팀별 역할 정의|팀별 역할 정의]]
- [[#6. 모범 사례|모범 사례]]

---

## 1. 왜 GitHub Projects로 관리하는가?

> [!note] 핵심 개념
> GitHub 생태계를 활용하면 코드 작성부터 프로젝트 관리까지 모든 과정이 하나의 플랫폼에서 연동되어 투명한 협업이 가능합니다.

### 💡 Notion vs GitHub 역할 분리

| 구분 | Notion | GitHub |
|------|--------|--------|
| **목적** | 기획/문서 관리 | 실행/이력 관리 |
| **특징** | 유연한 문서 작성 | 코드와의 연동 |
| **장점** | 텍스트 기반 상세 기록 | 자동화된 상태 추적 |

### 🤔 문제 상황

**기존 방식의 한계:**
- 백로그에 태스크 12개가 쌓여있음
- 누가 언제 태스크를 가져갔는지 불분명
- 단순 상태 변경만 보이고 "누가 했는지" 안 보임
- "알아서 했나보다" 수준의 추적만 가능

**해결책:**
- **GitHub Issues**: 태스크 생성 및 담당자 할당
- **GitHub Projects**: 칸반보드 시각적 관리
- **Pull Request**: 코드 리뷰 및 자동 상태 변경
- **자동화**: PR 머지 시 Issue 자동 닫힘

---

## 2. 기본 설정

### 💻 GitHub Projects 설정

#### 📋 칸반보드 기본 컬럼 구조

```yaml
백로그 (Backlog):
  - 처리될 모든 태스크
  - 우선순위별 정렬
  
이번 스프린트 (Sprint):
  - 현재 스프린트에서 처리할 태스크
  - 담당자 지정 완료
  
진행중 (In Progress):
  - 실제 작업이 시작된 태스크
  - 브랜치 생성 완료
  
리뷰 (Review):
  - PR 생성 완료
  - 코드 리뷰 진행중
  
완료 (Done):
  - PR 머지 완료
  - Issue 자동 닫힘
```

#### 🔧 자동화 규칙 설정

```yaml
# Issue 생성 시
When: Issue created
Then: Add to "백로그" column

# 담당자 지정 시
When: Issue assigned
Then: Move to "이번 스프린트" column

# PR 생성 시
When: PR created with linked issue
Then: Move linked issue to "리뷰" column

# PR 머지 시
When: PR merged
Then: Move linked issue to "완료" column
  Close linked issue automatically
```

---

## 3. 스프린트 흐름 관리

### 📊 스프린트 플래닝 프로세스

#### **1단계: Sprint Planning**

> [!example] Sprint Planning 미팅
> **질문**: "이번 스프린트에 뭐 할래?"
> 
> 1. **백로그 검토**: 모든 팀원이 백로그 확인
> 2. **태스크 선택**: 각자 처리할 태스크 선택
> 3. **담당자 할당**: Issue에 Assignee 지정
> 4. **이번 스프린트로 이동**: Projects에서 컬럼 이동

#### **2단계: 작업 착수**

> [!tip] 작업 시작 전 확인사항
> - Issue 상세 내용 再次 확인
> - 구현 방법론 논의
> - 브랜치 생성 규칙 준수
> - 작업 예상 시간 산정

#### **3단계: 진행 및 리뷰**

> [!warning] 리뷰 요청 전 체크리스트
> - [ ] 코드 작성 완료
> - [ ] 단위 테스트 통과
> - [ ] 코드 컨벤션 준수
> - [ ] PR 설명 작성

#### **4단계: 완료**

> [!success] 완료 조건
> - PR이 머지됨
> - Issue가 자동으로 닫힘
> - Projects 컬럼이 "완료"로 이동
> - 다음 스프린트 플래닝에 반영

---

## 4. 실전 예시

### 💻 ERD 설계 태스크 라이프사이클

#### 📋 전체 흐름 테이블

| 날짜 | 누가 | 무슨 태스크 | 행동 |
|------|------|-------------|------|
| 2/12 | 홍길동 | ERD 설계 | 백로그 → 이번 스프린트 (태스크 수주) |
| 2/13 | 홍길동 | ERD 설계 | 이번 스프린트 → 진행중 (착수) |
| 2/14 | 김철수 | ERD 설계 | 진행중 → 리뷰 (PR 올림) |
| 2/15 | 홍길동 | ERD 설계 | 리뷰 → 완료 (머지) |

#### 🔧 GitHub Issues 생성 예시

```markdown
# Issue: ERD 설계

**담당자**: @홍길동
**스프린트**: Sprint #1
**우선순위**: 높음

## 설명
프로젝트의 기본 데이터베이스 구조를 설계합니다.

## 작업 항목
- [ ] 요구사항 분석
- [ ] 엔티티 관계 정의
- [ ] ERD 다이어그램 작성
- [ ] 팀원 리뷰 및 피드백 반영
- [ ] 최종 ERD 확정

## 완료 조건
- ERD 다이어그램 완성
- 팀원 리뷰 통과
- docs/erd.md 파일 생성
```

#### 📝 Pull Request 생성 예시

```markdown
# PR: ERD 설계 완료

**연결된 Issue**: #1 ERD 설계
**리뷰어**: @김철수, @이영희

## 변경 내용
- 데이터베이스 엔티티 5개 설계
- 관계 정의 및 다이어그램 작성
- 문서화 완료

## 테스트 방법
- docs/erd.md 파일 확인
- 다이어그램 가독성 검토

## 스크린샷
[ERD 다이어그램 이미지]
```

---

## 5. 팀별 역할 정의

### 👥 역할별 책임 범위

| 역할 | 주요 책임 | GitHub 활용 |
|------|-----------|-------------|
| **PM/리드** | 스프린트 기획, 진행 관리 | Projects 관리, Issue 생성 |
| **개발자** | 태스크 수주, 구현, PR 생성 | Issue Assignee, PR Author |
| **리뷰어** | 코드 리뷰, 품질 보증 | PR Review, 승인 |
| **팀원 전체** | 지식 공유, 상호 협력 | 댓글, 토론, 피드백 |

### 📋 일일 스탠드업 체크리스트

```yaml
어제 한 일:
  - 어떤 Issue를 작업했나요?
  - 어떤 상태로 변경했나요?
  
오늘 할 일:
  - 어떤 Issue를 진행할 건가요?
  - 예상 완료 시간은?
  
막히는 점:
  - 도움이 필요한 부분이 있나요?
  - 누가 도와줄 수 있나요?
```

---

## 6. 모범 사례

### 💡 효율적인 협업 팁

#### **Issue 작성 Best Practice**

> [!tip] 제목 작성법
> - **나쁜 예**: "기능 구현"
> - **좋은 예**: "[FE] 로그인 페이지 UI 구현"

> [!tip] 설명 작성법
> - **배경**: 왜 이 작업이 필요한가?
> - **요구사항**: 구현해야 할 기능 목록
> - **완료조건**: 어떻게 완료되었다고 인정할 것인가?

#### **PR 관리 Best Practice**

> [!warning] PR 전 확인사항
> 1. **커밋 메시지**: 명확하고 일관성 있게
> 2. **PR 크기**: 너무 크지 않게 (300라인 이하 권장)
> 3. **설명**: 무엇을, 왜, 어떻게 변경했는지
> 4. **테스트**: 변경사항 검증 방법 포함

#### **자동화 활용**

```yaml
# GitHub Actions 예시
name: Auto-close completed issues
on:
  pull_request:
    types: [closed]

jobs:
  auto-close:
    if: github.event.pull_request.merged == true
    runs-on: ubuntu-latest
    steps:
      - name: Close linked issue
        uses: actions/github-script@v6
        with:
          script: |
            const pr = context.payload.pull_request;
            const issueNumber = pr.body.match(/#(\d+)/)?.[1];
            if (issueNumber) {
              await github.rest.issues.update({
                owner: context.repo.owner,
                repo: context.repo.repo,
                issue_number: issueNumber,
                state: 'closed'
              });
            }
```

### 📊 성과 측정 및 시각화

#### **스프린트 성과 지표**

| 지표 | 계산 방법 | 목표치 |
|------|-----------|--------|
| **완료율** | 완료된 태스크 / 할당된 태스크 | 80% 이상 |
| **리뷰 시간** | PR 생성 → 머지까지의 평균 시간 | 24시간 이내 |
| **참여도** | 팀원별 할당된 태스크 수 | 균등 분배 |

#### **주간 리포트 템플릿**

```markdown
# Sprint #1 주간 리포트

## 📊 성과 요약
- 완료된 태스크: 8/10 (80%)
- 평균 리뷰 시간: 18시간
- 팀원별 참여도: 균등

## ✅ 완료된 태스크
1. ERD 설계 (@홍길동)
2. API 명세서 작성 (@김철수)
...

## 🚧 진행중인 태스크
1. 로그인 기능 구현 (@이영희) - 리뷰중
2. 데이터베이스 설정 (@박민준) - 진행중

## 🔍 개선점
- PR 리뷰 속도 개선 필요
- Issue 설명 구체화 필요
```

---

## 🎯 결론

GitHub Projects를 활용한 스프린트 관리는 다음과 같은 장점을 제공합니다:

1. **투명성**: 모든 작업 과정이 기록으로 남음
2. **자동화**: Issue와 PR의 연동으로 상태 자동 변경
3. **시각화**: 칸반보드로 진행 상황
4. **협업**: 코드와 이력의 통합으로 효율적인 팀워크

