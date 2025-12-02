---
title: macOS에서 VirtualBox 설치 가이드
tags:
  - VirtualBox
  - macOS
  - 가상화
  - 설치가이드
  - infrastructure
aliases:
  - VirtualBox설치
  - 가상머신설치
date: 2025-12-02
category: 1_가이드/가상화
status: 완성
priority: 높음
---

# 🎯 macOS에서 VirtualBox 설치 가이드

## 📑 목차
- [[#1. VirtualBox 다운로드 및 설치|다운로드 및 설치]]
- [[#2. 시스템 권한 설정|시스템 권한 설정]]
- [[#3. VirtualBox 기본 설정|기본 설정]]
- [[#💻 설치 확인|설치 확인]]

---

## 1. VirtualBox 다운로드 및 설치

> [!note] VirtualBox 개요
> Oracle VirtualBox는 무료 가상화 소프트웨어로, macOS에서 리눅스 등 다른 OS를 실행할 수 있게 해줍니다.

### 💡 다운로드 방법

**🤔 질문**: "어디서 VirtualBox를 다운로드하나요?"

#### 📋 공식 사이트에서 다운로드

> [!example] 다운로드 과정
> 1. **사이트**: [Oracle VirtualBox 공식 사이트](https://www.virtualbox.org/)
> 2. **선택**: "Downloads" 클릭
> 3. **버전**: "macOS / Intel hosts" 또는 "macOS / Apple Silicon" 선택
> 4. **다운로드**: .dmg 파일 다운로드

#### 💻 설치 과정

```bash
# Homebrew를 통한 설치 (선택사항)
brew install --cask virtualbox

# 또는 다운로드한 .dmg 파일 실행
open VirtualBox-7.0.x-OSX.dmg
```

---

## 2. 시스템 권한 설정

> [!warning] 중요한 보안 설정
> macOS에서 VirtualBox를 실행하기 위해서는 시스템 확장 프로그램을 허용해야 합니다.

### 🔧 시스템 환경설정

#### 📋 권한 허용 과정

> [!example] 권한 설정 단계
> 1. **시스템 환경설정** 열기
> 2. **보안 및 개인정보보호** 클릭
> 3. **일반** 탭에서 Oracle 관련 항목 허용
> 4. **개인정보보호** 탭에서 VirtualBox 권한 허용

#### 💻 터미널을 통한 확인

```bash
# 시스템 확장 프로그램 확인
system_profiler SPExtensionsDataType | grep -i virtualbox

# VirtualBox 서비스 확인
ps aux | grep -i virtualbox
```

---

## 3. VirtualBox 기본 설정

### 💡 초기 설정 최적화

#### 📋 성능 최적화 설정

| 설정 항목 | 권장 값 | 설명 |
|----------|---------|------|
| 기본 머신 폴더 | 충분한 용량의 디스크 | SSD 권장 |
| 호스트 키 | Command + Control | macOS 친화적 설정 |
| 업데이트 확인 | 주간 | 보안 패치 유지 |

#### 💻 네트워크 어댑터 설정

```yaml
# 📊 VirtualBox 기본 네트워크 설정
NAT 네트워크:
  - 용도: 인터넷 접속
  - IP 대역: 10.0.2.0/24
  - 특징: 외부에서 접근 불가

브리지 어댑터:
  - 용도: 외부 네트워크 접근
  - IP 대역: 호스트와 동일 네트워크
  - 특징: 실제 네트워크 장치처럼 동작
```

---

## 💻 설치 확인

### 🔍 설치 검증

#### 📋 정상 설치 확인 체크리스트

> [!example] 확인 항목
> 1. **VirtualBox 실행**: Applications 폴더에서 실행 확인
> 2. **관리자 권한**: 새 가상머신 생성 테스트
> 3. **확장팩**: Oracle VM VirtualBox Extension Pack 설치 (선택사항)
> 4. **호스트 전용 네트워크**: 네트워크 어댑터 생성 테스트

#### 💻 CLI 확인 명령어

```bash
# VirtualBox 버전 확인
VBoxManage --version

# 가상머신 목록 확인
VBoxManage list vms

# 호스트 정보 확인
VBoxManage list hostinfo
```

### 🚨 일반적인 문제 및 해결방법

> [!warning] 자주 발생하는 문제
> - **권한 오류**: 시스템 환경설정에서 Oracle 허용 필요
> - **실행 불가**: macOS 보안 정책으로 인한 차단 - Gatekeeper 우회 필요
> - **성능 문제**: 하드웨어 가속 활성화 확인

---

## 🎯 다음 단계

설치 완료 후 다음 가이드를 참고하세요:
- [[Ubuntu_가상머신_생성_가이드]] - 우분투 가상머신 생성
- [[리눅스_네트워크_설정_가이드]] - 네트워크 환경 구성
- [[SSH_접속_설정_가이드]] - 원격 접속 설정