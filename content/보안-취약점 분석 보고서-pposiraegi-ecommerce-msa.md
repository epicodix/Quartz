---
title: 보안 취약점 분석 보고서 - pposiraegi-ecommerce-msa
tags:
  - 보안
  - 취약점분석
  - AWS
  - SpringBoot
  - React
aliases:
  - 취약점분석보고서
date: 2026-04-14
category: 보안/취약점분석
status: 완성
priority: 높음
---

# 🎯 보안 취약점 분석 보고서 - pposiraegi-ecommerce-msa

## 📑 목차
- [[#1. 분석 개요|분석 개요]]
- [[#2. 프론트엔드 취약점|프론트엔드 취약점]]
- [[#3. 백엔드 취약점|백엔드 취약점]]
- [[#4. 인프라 취약점|인프라 취약점]]
- [[#5. 우선순위별 대응 계획|우선순위별 대응 계획]]

---

## 1. 분석 개요: 개요 및 분석 범위

> [!note] 분석 개요
> - **대상 저장소**: Goorm4I/pposiraegi-ecommerce-msa
> - **분석 일자**: 2026년 4월 14일
> - **분석 범위**: 프론트엔드(React), 백엔드(Spring Boot MSA), 인프라(Terraform/AWS)

### 💡 분석 방법

#### 📋 수행된 분석 항목

> [!example] 분석 도구 및 방법
> 1. **문제**: 보안 취약점 식별 필요
> 2. **감지**: npm audit, 코드 정적 분석, 수동 코드 검토
> 3. **조치**: 취약점 식별 및 심각도 분류
> 4. **결과**: 38개의 프론트엔드 취약점, 다수의 인프라/백엔드 보안 문제 발견

---

## 2. 프론트엔드 취약점: NPM 의존성 및 보안 문제

> [!note] 취약점 요약
> - **총 취약점 수**: 38개
> - **Critical**: 1개
> - **High**: 21개
> - **Moderate**: 7개
> - **Low**: 9개

### 💡 주요 취약점 상세

#### 📋 Critical 취약점

> [!danger] Axios (<=1.14.0) - SSRF 및 메타데이터 유출
> - **CVE**: GHSA-3p68-rc4w-qgx5, GHSA-fvcv-3m26-pcqx
> - **영향도**: Critical
> - **설명**: 
>   - NO_PROXY 호스트명 정규화 우회로 인한 SSRF (Server-Side Request Forgery)
>   - 헤더 인젝션 체인을 통한 클라우드 메타데이터 무제한 유출
> - **대응방안**: 
>   ```bash
>   npm install axios@latest
>   ```

#### 📊 High 취약점

| 패키지 | 취약점 내용 | 영향도 | 대응방안 |
|--------|-------------|--------|----------|
| node-forge | 인증서 체인 검증 우회, 서명 위조 | High | 최신 버전으로 업그레이드 |
| lodash | 코드 인젝션, 프로토타입 오염 | High | 최신 버전으로 업그레이드 |
| flatted | DoS, 프로토타입 오염 | High | 최신 버전으로 업그레이드 |
| minimatch | ReDoS (정규표현식 서비스 거부) | High | 최신 버전으로 업그레이드 |
| serialize-javascript | RCE, CPU 소진 DoS | High | 최신 버전으로 업그레이드 |
| rollup | 경로 트래버스를 통한 임의 파일 쓰기 | High | 최신 버전으로 업그레이드 |

---

## 3. 백엔드 취약점: 코드 레벨 보안 문제

### 💡 주요 보안 문제

#### 📋 하드코딩된 비밀 정보

> [!danger] JWT Secret Key 하드코딩
> **위치**: 
> - `backend/api-gateway/src/main/resources/application.yaml`
> - `backend/user-service/src/main/resources/application.yaml`
> 
> **문제 코드**:
> ```yaml
> jwt:
>   secret: ${JWT_SECRET:iqe7Fa7xrhXwJ5SLoee88Yg7DeUuJflj4+IE/XIl81tmZ24qNd4tCUble1Zk2drO=}
> ```
> 
> **대응방안**:
> - 환경 변수로만 관리하도록 변경
> - 기본값 제거: `secret: ${JWT_SECRET}`
> - production 환경에서는 반드시 AWS SSM Parameter Store 사용

> [!warning] 기본 비밀번호 사용
> **위치**: `backend/user-service/src/main/resources/application.yaml`
> 
> **문제 코드**:
> ```yaml
> password: "0000"
> ```
> 
> **대응방안**:
> - 기본값 제거: `password: ${DB_PASSWORD}`
> - production 환경에서는 AWS SSM Parameter Store 사용

#### 📋 SonarQube 토큰 노출

> [!danger] SonarQube 인증 토큰 하드코딩
> **위치**: `backend/build.gradle`
> 
> **문제 코드**:
> ```gradle
> property "sonar.token", "squ_7e6f31e5153f34d283f58563ec584d08ff9fa579"
> ```
> 
> **대응방안**:
> - 환경 변수로 변경: `property "sonar.token", System.getenv("SONAR_TOKEN")`
> - 또는 `sonar-project.properties` 파일 사용 후 .gitignore 추가
> - 토큰 재발급 및 기존 토큰 폐기

---

## 4. 인프라 취약점: Terraform/AWS 보안 문제

### 💡 Terraform 보안 문제

#### 📋 민감 정보 관리

> [!warning] 민감한 변수 평문 저장 가능성
> **위치**: `infrastructure/variables.tf`
> 
> **문제점**:
> - `jwt_secret`, `db_password` 변수가 민감 정보로 표시되어 있지만
> - `.tfvars` 파일에 평문으로 저장될 수 있음
> - `terraform.tfvars` 파일이 .gitignore에 없을 경우 리포지토리에 커밋됨
> 
> **대응방안**:
> ```terraform
> # terraform.tfvars를 .gitignore에 추가
> # echo "terraform.tfvars" >> .gitignore
> 
> # 또는 환경 변수 사용
> # export TF_VAR_jwt_secret="your-secret"
> # export TF_VAR_db_password="your-password"
> ```

#### 📋 보안 그룹 구성

> [!warning] 과도하게 개방된 인바운드 규칙
> **위치**: `infrastructure/main.tf`
> 
> **문제점**:
> - ALB가 모든 IP에서의 HTTP 접속을 허용 (`0.0.0.0/0`)
> - CloudFront를 통한 HTTPS 강제 리다이렉트 구성 필요
> 
> **현황**:
> ```hcl
> ingress {
>   from_port   = 80
>   to_port     = 80
>   protocol    = "tcp"
>   cidr_blocks = ["0.0.0.0/0"]
> }
> ```
> 
> **대응방안**:
> - CloudFront 전용 보안 그룹 추가
> - ALB 인바운드를 CloudFront IP 범위로 제한

> [!info] S3 Public Access Block 확인
> **위치**: `infrastructure/main.tf`
> 
> **현재 상태**: ✅ 양호
> - S3 버킷이 CloudFront OAC를 통해서만 접근 가능
> - Public Access Block 활성화

---

## 5. 우선순위별 대응 계획: 취약점 수정 로드맵

> [!note] 우선순위 분류
> - **P0 (즉시 조치)**: Critical/High 취약점, 민감 정보 노출
> - **P1 (1주 이내)**: Moderate 취약점, 보안 설정 개선
> - **P2 (1개월 이내)**: Low 취약점, 코딩 표준 준수

### 💡 P0: 즉시 조치 사항

#### 📋 프론트엔드

> [!example] 1. Axios 업그레이드
> ```bash
> cd frontend
> npm install axios@latest
> npm audit fix
> ```

> [!example] 2. 기타 High 취약점 패치
> ```bash
> npm install lodash@latest
> npm install node-forge@latest
> npm install minimatch@latest
> npm audit fix
> ```

#### 📋 백엔드

> [!example] 1. JWT Secret 기본값 제거
> 
> **변경 전**:
> ```yaml
> jwt:
>   secret: ${JWT_SECRET:iqe7Fa7xrhXwJ5SLoee88Yg7DeUuJflj4+IE/XIl81tmZ24qNd4tCUble1Zk2drO=}
> ```
> 
> **변경 후**:
> ```yaml
> jwt:
>   secret: ${JWT_SECRET}
> ```

> [!example] 2. DB 비밀번호 기본값 제거
> 
> **변경 전**:
> ```yaml
> spring:
>   datasource:
>     password: "0000"
> ```
> 
> **변경 후**:
> ```yaml
> spring:
>   datasource:
>     password: ${DB_PASSWORD}
> ```

> [!example] 3. SonarQube 토큰 환경 변수화
> 
> **변경 전**:
> ```gradle
> property "sonar.token", "squ_7e6f31e5153f34d283f58563ec584d08ff9fa579"
> ```
> 
> **변경 후**:
> ```gradle
> property "sonar.token", System.getenv("SONAR_TOKEN")
> ```

#### 📋 인프라

> [!example] 1. .gitignore에 민감 파일 추가
> 
> **추가 내용**:
> ```gitignore
> # terraform.tfvars
> terraform.tfvars
> *.tfstate
> .terraform/
> ```

> [!example] 2. 환경 변수 사용 가이드 추가
> 
> **README에 추가**:
> ```markdown
> ## 환경 변수 설정
> 
> 프로덕션 배포 시 다음 환경 변수를 설정해야 합니다:
> 
> ```bash
> export TF_VAR_jwt_secret="your-jwt-secret"
> export TF_VAR_db_password="your-db-password"
> export JWT_SECRET="your-jwt-secret"
> export DB_PASSWORD="your-db-password"
> ```
> ```

### 💡 P1: 1주 이내 조치 사항

#### 📋 Moderate 취약점 패치

> [!example] 1. 나머지 의존성 업그레이드
> ```bash
> cd frontend
> npm update
> npm audit fix
> ```

#### 📋 보안 설정 강화

> [!example] 1. ALB 보안 그룹 개선
> 
> - CloudFront IP 범위로 인바운드 제한
> - HTTPS만 허용하도록 구성

### 💡 P2: 1개월 이내 조치 사항

#### 📋 Low 취약점 및 코딩 표준

> [!example] 1. SAST 도구 도입
> - OWASP Dependency-Check 도입
> - SonarQube Security Hotspots 규칙 활성화
> - GitHub Security 사용

> [!example] 2. 보안 테스트 자동화
> - CI/CD 파이프라인에 보안 스캔 추가
> - Docker 이미지 스캔 (Trivy)

---

## 📊 취약점 요약표

| 카테고리 | Critical | High | Moderate | Low | 총계 |
|----------|----------|------|----------|-----|------|
| 프론트엔드 의존성 | 1 | 21 | 7 | 9 | 38 |
| 백엔드 코드 | - | 1 | - | - | 1 |
| 인프라 구성 | - | - | 2 | - | 2 |
| **합계** | **1** | **22** | **9** | **9** | **41** |

---

## 🚨 주요 발견사항

1. **프론트엔드**: Axios 취약점으로 SSRF 및 메타데이터 유출 가능
2. **백엔드**: JWT Secret 및 DB 비밀번호가 하드코딩됨
3. **백엔드**: SonarQube 토큰이 리포지토리에 노출됨
4. **인프라**: Terraform 변수 파일(.tfvars)이 실수로 커밋될 수 있음
5. **인프라**: ALB가 모든 IP에서의 접속을 허용함

---

## ✅ 검증 체크리스트

- [x] 프론트엔드 npm audit 실행
- [x] 하드코딩된 비밀정보 검색
- [x] 테라폼 구성 검토
- [x] 우선순위별 대응 계획 수립
- [x] 보고서 작성