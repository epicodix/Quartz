---
title: SAA-C03 AWS Directory Service 완전 정복
tags:
  - SAA-C03
  - AWS
  - Directory
  - ActiveDirectory
  - 자격증
date: 2026-03-11
status: 완성
priority: 높음
aliases:
  - AD서비스
  - DirectoryService
---

# 🎯 AWS Directory Service 완전 정복 - SAA 시험 대비

> [!note] 학습 목표
> - AD Connector / Managed Microsoft AD / Simple AD를 **확실히** 구분
> - 지문의 **키워드 하나**만 보고 정답 선택
> - 함정 선택지를 **왜 틀렸는지** 설명 가능

---

## 📑 목차

- [[#Part 1 기초 개념 이해|Part 1: 기초 개념]]
- [[#Part 2 각 서비스 상세 분석|Part 2: 서비스 상세]]
- [[#Part 3 의사결정 플로우차트|Part 3: 의사결정 트리]]
- [[#Part 4 실전 문제 풀이|Part 4: 실전 문제]]
- [[#Part 5 연관 서비스 심화|Part 5: 연관 서비스]]
- [[#Part 6 최종 정리 및 암기 카드|Part 6: 최종 암기]]

---

# Part 1: 기초 개념 이해

## 1.1 Active Directory(AD)란?

Active Directory = 회사의 **"직원 명부 + 출입 시스템"**

```
실제 회사 비유:

📋 직원 명부 (Directory)
- 김철수: 개발팀, 서버실 출입 가능
- 이영희: 마케팅팀, 회의실만 출입 가능

🔐 출입 시스템 (Authentication)
- 사원증 찍으면 → 명부 확인 → 출입 허용/거부

IT 세계에서:
- 직원 명부  = 사용자 계정, 그룹, 권한 정보
- 출입 시스템 = 로그인 인증
- 서버실/회의실 = 서버, 앱, 파일 공유
```

## 1.2 왜 AWS에서 AD가 필요한가?

```
문제 상황:
회사에 1000명 직원, 온프레미스에 AD 이미 있음

[온프레미스]
  Active Directory (1000명 계정)
       │
       ├── 파일 서버
       ├── 메일 서버
       └── 인트라넷

이제 AWS도 사용하려고 함:
- EC2 서버도 같은 사원 계정으로 로그인하고 싶음
- WorkSpaces(가상 데스크톱)도 같은 계정으로 쓰고 싶음
- AWS 콘솔도 회사 계정으로 SSO 하고 싶음

질문: 어떻게 연결하지? 🤔
```

---

# Part 2: 각 서비스 상세 분석

## 2.1 한눈에 보는 비교

### 3종류 개요

```
1. AD Connector
   온프레미스 AD ◄────► AD Connector ◄────► AWS
   (계정 저장)         (저장 안함)         (서비스)
   특징: 기존 AD 그대로 유지, AWS에 복사 안함

2. AWS Managed Microsoft AD
   온프레미스 AD ◄──[Trust]──► AWS Managed MS AD
                                (AWS에 진짜 AD 있음)
   특징: AWS가 관리, 트러스트 가능, 대규모

3. Simple AD
   Simple AD (Samba 기반)
   - 500명 Small / 5,000명 Large
   - MFA 없음 / 트러스트 없음
   특징: 저렴, 단순, 소규모에 적합
```

---

## 2.2 AD Connector — "프록시"

> [!note] 핵심 개념
> AD Connector = 중개인. 사용자 정보를 **저장하지 않고** 온프레미스 AD로 인증 요청을 전달만 함.

### 인증 흐름

```
Step 1: 사용자가 AWS 서비스 접근 시도
        사용자 (ID: kim / PW: ****)
                    │
                    ▼
Step 2: AD Connector가 요청 수신
        AD Connector (AWS VPC 내)
        "온프레미스 AD한테 물어봐야지"
                    │ VPN 또는 Direct Connect
                    ▼
Step 3: 온프레미스 AD에서 인증 처리
        온프레미스 AD: "kim? 비밀번호 맞음. 개발팀, 권한 있음"
                    │
                    ▼
Step 4: AWS 서비스 접근 허용
        WorkSpaces: "어서오세요 kim님!"

핵심: AD Connector는 사용자 정보를 저장하지 않음
```

### AD Connector 선택 조건

```
✅ 선택해야 하는 상황:
- "기존 온프레미스 AD를 유지하면서 AWS 사용"
- "AWS에 사용자 데이터를 복사하고 싶지 않음"
- "기존 AD에 MFA를 추가하고 싶음"
```

### AD Connector 제한 사항

```
❌ 할 수 없는 것:
- 트러스트 관계 (Trust Relationship) → Managed Microsoft AD로
- AWS에서 사용자 직접 관리 (추가/삭제는 온프레미스에서만)
- 온프레미스 AD 없이 사용
```

---

## 2.3 AWS Managed Microsoft AD — "진짜 AD"

> [!note] 핵심 개념
> AWS가 운영하는 실제 Microsoft AD. 도메인 컨트롤러 2개(Multi-AZ)를 AWS가 자동 관리.

### 트러스트 관계 (Trust Relationship)

```
트러스트 없을 때:
  온프레미스 AD (corp.local)     AWS Managed MS AD (aws.corp.com)
  사용자: kim          ─ X ─     사용자: lee
  (온프레미스만 접근)            (AWS만 접근)

양방향 트러스트 설정 후:
  온프레미스 AD ◄──── Trust ────► AWS Managed MS AD
  kim → AWS 리소스 접근 ✅
  lee → 온프레미스 리소스 접근 ✅
```

### 트러스트 유형

| 유형 | 방향 | 접근 허용 |
|------|------|---------|
| 단방향 | 온프레미스 → AWS | 온프레미스 사용자가 AWS 접근만 가능 |
| 양방향 | 양쪽 모두 | 상호 접근 가능 |

> [!warning] 시험 포인트
> "트러스트" 키워드가 나오면 → **Managed Microsoft AD**. AD Connector는 트러스트 불가!

### Managed Microsoft AD 선택 조건

```
✅ 선택해야 하는 상황:
- "AWS에서 완전 관리형 AD 필요"
- "온프레미스 AD와 트러스트 관계 필요"
- "Microsoft AD 전체 기능 필요 (SharePoint, SQL Server 등)"
- "대규모 사용자 (5,000명 이상)"
- "MFA 필요 + 온프레미스 AD 없음"
```

---

## 2.4 Simple AD — "간단 버전"

> [!note] 핵심 개념
> Samba 4 기반의 저렴하고 간단한 AD. 소규모에 적합. **MFA 미지원**.

### Simple AD 지원 여부

| 기능 | 지원 |
|------|------|
| 기본 사용자/그룹 관리 | ✅ |
| 도메인 조인 (EC2) | ✅ |
| Kerberos SSO | ✅ |
| WorkSpaces 연동 | ✅ |
| MFA | ❌ |
| 트러스트 관계 | ❌ |
| 스키마 확장 | ❌ |
| PowerShell AD 모듈 | ❌ |

**규모:**
- Small: 500명, 2,000 객체
- Large: 5,000명, 20,000 객체

### Simple AD 선택 조건

```
✅ 선택해야 하는 상황:
- "소규모 + 저비용 + MFA 불필요"
- "기본 AD 기능만 필요"
- "온프레미스 AD 없음 + 단순 구성"
```

---

# Part 3: 의사결정 플로우차트

```
온프레미스에 기존 AD가 있는가?
│
├── YES
│    │
│    └── 기존 AD를 그대로 유지하고 AWS에 데이터 저장 안 하고 싶은가?
│         │
│         ├── YES → AD Connector (프록시, 저장 안함)
│         │
│         └── NO
│              │
│              └── 온프레미스 AD와 트러스트 관계가 필요한가?
│                   │
│                   ├── YES → Managed Microsoft AD (트러스트 지원)
│                   └── NO  → AD Connector 또는 Managed Microsoft AD
│
└── NO (온프레미스 AD 없음)
     │
     └── 소규모(5,000명 이하) + 기본 기능만 + 비용 최소 + MFA 불필요?
          │
          ├── YES → Simple AD (저렴, 기본)
          └── NO  → Managed Microsoft AD (대규모, 전체 기능, MFA 지원)
```

## 키워드 즉답 매핑

| 키워드 | 정답 |
|--------|------|
| "기존 온프레미스 AD 유지" | AD Connector |
| "자격증명을 AWS로 복사하지 않음" | AD Connector |
| "기존 AD + MFA 추가" | AD Connector |
| "트러스트 관계" / "양방향 신뢰" | Managed Microsoft AD |
| "완전 관리형 AD" / "SharePoint" | Managed Microsoft AD |
| "소규모 + 저비용 + MFA 불필요" | Simple AD |
| "500명 이하 + 기본 기능" | Simple AD |

---

# Part 4: 실전 문제 풀이

## 문제 1 — 기본

> 회사에 온프레미스 AD가 있음. 기존 AD를 계속 사용하면서 직원들이 동일한 자격증명으로 AWS 리소스에 접근. **사용자 정보를 AWS로 복사하고 싶지 않음.**
>
> A. Managed Microsoft AD 배포
> B. AD Connector 배포
> C. Simple AD 배포
> D. Cognito 사용자 풀 생성

> [!tip]- 정답 및 풀이
> **정답: B. AD Connector**
>
> 키워드 분석:
> - "온프레미스 AD 유지" → AD Connector 또는 Managed MS AD
> - "사용자 정보를 AWS로 복사하지 않음" → **AD Connector** (저장 안함)
>
> 탈락 이유:
> - A: Managed MS AD는 AWS에 사용자 정보 저장됨 ❌
> - C: Simple AD는 온프레미스 AD와 별개, 새 계정 필요 ❌
> - D: Cognito는 웹/모바일 앱 인증용 ❌

---

## 문제 2 — 트러스트 관계

> 온프레미스 AD 있음. **AWS에서 생성한 사용자가 온프레미스 리소스에도 접근**, 온프레미스 사용자도 AWS에 접근 가능해야 함.
>
> A. AD Connector 배포 후 온프레미스 AD 연결
> B. Managed Microsoft AD + **양방향 트러스트** 설정
> C. Simple AD + 온프레미스 AD 동기화
> D. IAM Identity Center로 사용자 동기화

> [!tip]- 정답 및 풀이
> **정답: B. Managed Microsoft AD + 양방향 트러스트**
>
> 키워드 분석:
> - "AWS 사용자 → 온프레미스 접근" + "온프레미스 → AWS 접근"
> - = 양방향 접근 = **트러스트 관계 필요**
> - 트러스트는 Managed Microsoft AD만 지원
>
> 탈락 이유:
> - A: AD Connector는 트러스트 불가 ❌
> - C: Simple AD는 트러스트 불가 ❌

---

## 문제 3 — MFA 함정

> 소규모 스타트업 100명. WorkSpaces 사용 예정. 온프레미스 AD 없음. **비용 최소화 + MFA 적용 필수.**
>
> A. Simple AD 배포
> B. Managed Microsoft AD 배포
> C. AD Connector 배포
> D. Cognito 사용자 풀

> [!tip]- 정답 및 풀이
> **정답: B. Managed Microsoft AD**
>
> 키워드 분석:
> - "소규모 + 저비용" → Simple AD 선택 충동 ⚠️
> - "MFA 적용 필수" → Simple AD **즉시 탈락** (MFA 미지원)
> - "온프레미스 AD 없음" → AD Connector 탈락
> - MFA 필요 + 온프레미스 AD 없음 → **Managed Microsoft AD**
>
> 함정 포인트:
> "소규모 + 저비용" 보고 Simple AD 선택하면 틀림.
> **MFA** 키워드가 Simple AD를 무조건 탈락시킴!

---

## 문제 4 — 복합 시나리오

> 금융 기업. 온프레미스 AD(5000명+). **규정상 자격증명은 반드시 온프레미스에만 저장.** 기존 자격증명으로 AWS 콘솔 SSO. **MFA 필수.**
>
> A. Managed Microsoft AD + IAM Identity Center 연동
> B. AD Connector + IAM Identity Center 연동
> C. Simple AD + MFA 활성화
> D. 온프레미스 AD를 AWS로 마이그레이션

> [!tip]- 정답 및 풀이
> **정답: B. AD Connector + IAM Identity Center**
>
> 체크리스트:
> - "온프레미스 AD 유지" → AD Connector ✅
> - "자격증명 AWS에 저장 안함" → AD Connector ✅ (Managed MS AD는 저장됨 ❌)
> - "SSO" → IAM Identity Center ✅
> - "MFA" → AD Connector MFA 지원 ✅ (Simple AD는 미지원 ❌)
>
> 탈락 이유:
> - A: Managed MS AD는 AWS에 데이터 저장됨 ❌
> - C: Simple AD는 MFA 미지원 ❌

---

## 문제 5 — WorkSpaces 시나리오

> 온프레미스 AD(2000명) 있음. IT 관리자는 **AWS에서 별도 계정 생성 없이** 기존 AD 계정으로 WorkSpaces 로그인 구성.
>
> A. Simple AD 생성 후 수동 추가
> B. AD Connector 생성 후 온프레미스 AD 연결
> C. Managed Microsoft AD 생성 후 모든 사용자 재생성
> D. Cognito 사용자 풀 생성 후 WorkSpaces 연동

> [!tip]- 정답 및 풀이
> **정답: B. AD Connector + 온프레미스 AD 연결**
>
> 키워드: "별도 계정 생성 없이" + "기존 AD 계정 그대로"
> → AD Connector (프록시, 저장 안함, 기존 계정 그대로)
>
> 탈락 이유:
> - A: 2000명 수동 추가 비현실적, 기존 AD와 별개 ❌
> - C: 2000명 재생성 비현실적 ❌
> - D: Cognito는 WorkSpaces 직접 연동 안 됨 ❌

---

# Part 5: 연관 서비스 심화

## 5.1 IAM Identity Center (구 AWS SSO)

```
목적: 여러 AWS 계정과 앱에 단일 로그인(SSO)

사용자
  │
  ▼
IAM Identity Center (SSO 포털)
  │
  ├── AWS 계정 1
  ├── AWS 계정 2
  └── SaaS 앱들
```

**Directory Service 연동 패턴:**

```
패턴 1: AD Connector + IAM Identity Center
온프레미스 AD ──── AD Connector ──── IAM Identity Center
(사용자 저장)      (프록시)           (SSO 포털)
→ 온프레미스 AD 계정으로 AWS 콘솔 SSO

패턴 2: Managed Microsoft AD + IAM Identity Center
AWS Managed Microsoft AD ──── IAM Identity Center
(AWS에서 사용자 관리)          (SSO 포털)
→ AWS 내 AD 계정으로 AWS 콘솔 SSO
```

**시험 키워드:**
- "여러 AWS 계정에 단일 로그인"
- "AWS Organizations + SSO"
→ IAM Identity Center + (AD Connector 또는 Managed Microsoft AD)

---

## 5.2 WorkSpaces + Directory Service

| 상황 | 선택 |
|------|------|
| 온프레미스 AD 있음, 기존 계정 그대로 | AD Connector |
| 온프레미스 AD 없음 + 소규모 + MFA 불필요 | Simple AD |
| 온프레미스 AD 없음 + MFA 필요 | Managed Microsoft AD |
| 온프레미스 AD 있음 + MFA 필요 | AD Connector |

---

# Part 6: 최종 정리 및 암기 카드

## 6.1 핵심 비교표

| 항목 | AD Connector | Managed MS AD | Simple AD |
|------|-------------|--------------|----------|
| 사용자 저장 위치 | 온프레미스 | AWS | AWS |
| 온프레미스 AD | 필수 | 선택 (트러스트) | 불필요 |
| 트러스트 | ❌ | ✅ | ❌ |
| MFA | ✅ | ✅ | ❌ |
| 규모 | 제한 없음 | 5,000명+ | Small 500명 / Large 5,000명 |
| 비용 | 저렴 | 비쌈 | 가장 저렴 |
| 핵심 키워드 | "기존 AD 유지" "복사 안함" | "트러스트" "완전 관리형" | "소규모+저비용" "기본 기능" |

## 6.2 즉답 카드

| 조건 | 정답 |
|------|------|
| 온프레미스 AD 유지 + AWS 연결 | AD Connector |
| 트러스트 관계 필요 | Managed Microsoft AD |
| 소규모 + 저비용 + MFA 불필요 | Simple AD |
| MFA 필요 + 온프레미스 AD 없음 | Managed Microsoft AD |
| MFA 필요 + 온프레미스 AD 있음 + 데이터 복사 안함 | AD Connector |
| 여러 AWS 계정 SSO | IAM Identity Center + AD Connector 또는 Managed MS AD |

## 6.3 함정 체크리스트

> [!danger] 시험 전 반드시 확인
> - MFA 키워드 있으면 → Simple AD **즉시 제외**
> - 트러스트 키워드 있으면 → AD Connector **즉시 제외**
> - "데이터 복사 안함" 있으면 → Managed MS AD **즉시 제외**
> - 온프레미스 AD 없으면 → AD Connector **즉시 제외**
> - "소규모 + 저비용"만 보고 Simple AD 선택 금지 → **MFA 조건 먼저 확인!**

---

## 🎯 자가 테스트 5문제

### 테스트 1
"회사에 온프레미스 AD가 있고, AWS에 자격증명을 저장하지 않으면서 WorkSpaces를 사용하려고 합니다."

> [!tip]- 정답
> **AD Connector**

### 테스트 2
"소규모 스타트업(50명)이 WorkSpaces 사용. 온프레미스 AD 없음. 비용 최소화. MFA는 필요하지 않음."

> [!tip]- 정답
> **Simple AD**

### 테스트 3
"AWS 사용자가 온프레미스 리소스에 접근하고, 온프레미스 사용자도 AWS 리소스에 접근해야 합니다."

> [!tip]- 정답
> **Managed Microsoft AD** (양방향 트러스트)

### 테스트 4
"온프레미스 AD 있음. 기존 AD를 유지하면서 MFA를 추가하여 AWS 콘솔 SSO 구현."

> [!tip]- 정답
> **AD Connector + IAM Identity Center** (MFA 활성화)

### 테스트 5
"300명 규모. AWS에서 독립적 AD 운영. 온프레미스 AD 없음. MFA 필요."

> [!tip]- 정답
> **Managed Microsoft AD** (Simple AD는 MFA 미지원)
