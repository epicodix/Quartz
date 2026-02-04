---
title: Windows SSH 원격 접속 트러블슈팅 기록
tags:
  - troubleshooting
  - windows
  - ssh
  - openssh
  - devops
  - infrastructure
aliases:
  - Windows SSH 삽질
date: 2026-02-03
category: 99_임시/트러블슈팅
status: 진행중
priority: 높음
---

# Windows SSH 원격 접속 트러블슈팅 기록

## 📑 목차
- [[#1. 배경 및 목표|배경 및 목표]]
- [[#2. 환경 정보|환경 정보]]
- [[#3. 발생한 문제들|발생한 문제들]]
- [[#4. 시도한 해결 방법|시도한 해결 방법]]
- [[#5. 교훈 및 결론|교훈 및 결론]]
- [[#6. 향후 계획|향후 계획]]

---

## 1. 배경 및 목표

> [!note] 목표
> Tailscale VPN을 통해 Mac에서 Windows PC로 SSH 원격 접속하여 터미널 제어

**요구사항:**
- 상대방이 Windows에서 작업 중이어도 방해 없이 원격 제어
- RDP(화면 공유) 방식이 아닌 SSH 쉘 접속 필요
- Tailscale 네트워크를 통한 보안 연결

---

## 2. 환경 정보

### 클라이언트 (접속하는 쪽)
- **기기**: epix-macbookair
- **OS**: macOS
- **Tailscale IP**: 100.96.229.124

### 서버 (접속 대상)
- **기기**: win-tm9spgbopgn
- **OS**: Windows 11 Home Edition
- **Tailscale IP**: 100.71.14.69
- **보안 소프트웨어**: 안랩 V3

---

## 3. 발생한 문제들

### 3.1. Windows 11 Home 에디션 제약

> [!warning] 핵심 문제
> Windows 11 Home 에디션은 OpenSSH Server 기본 기능 설치를 지원하지 않음

```powershell
# 이 명령어가 Home 에디션에서 작동하지 않음
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
```

**증상:**
- 선택적 기능에서 OpenSSH Server가 보이지 않음
- PowerShell 명령어 실행 시 무반응 또는 실패

### 3.2. 패키지 매니저 문제

| 도구 | 결과 |
|------|------|
| winget | 실패 |
| Chocolatey | 실패 |
| GUI 선택적 기능 | 무반응 (설치 대기 상태 지속) |

### 3.3. MSI 수동 설치 후 서비스 시작 실패

```powershell
PS> Start-Service sshd
# 오류: '.' 컴퓨터의 sshd 서비스를 열 수 없습니다.
```

**원인:** 설정 파일 및 호스트 키 부재
```
sshd -d
__PROGRAMDATA__\ssh/sshd_config: No such file or directory
```

### 3.4. 방화벽 이슈 (다중 레이어)

> [!danger] 숨은 보스: 안랩 V3
> Windows 기본 방화벽을 꺼도 안랩 자체 방화벽이 SSH 포트(22) 차단

**확인된 상태:**
- sshd 서비스: Running
- 포트 22: LISTENING (0.0.0.0:22)
- Tailscale ping: 성공 (20ms)
- SSH 접속: 실패 (Operation timed out)

---

## 4. 시도한 해결 방법

### 4.1. OpenSSH MSI 수동 설치 (부분 성공)

```powershell
# 1. GitHub에서 MSI 다운로드
# https://github.com/PowerShell/Win32-OpenSSH/releases/latest

# 2. 설정 디렉토리 생성
New-Item -Path "C:\ProgramData\ssh" -ItemType Directory -Force

# 3. 설정 파일 복사
Copy-Item "C:\Windows\System32\OpenSSH\sshd_config_default" -Destination "C:\ProgramData\ssh\sshd_config"

# 4. 호스트 키 생성
ssh-keygen -A

# 5. 서비스 시작
Start-Service sshd
Set-Service -Name sshd -StartupType Automatic
```

**결과:** 서비스는 Running 상태가 됨

### 4.2. 방화벽 규칙 추가

```powershell
# Windows 기본 방화벽
New-NetFirewallRule -Name "sshd" -DisplayName "OpenSSH Server" -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 -Profile Any

# netsh 방식
netsh advfirewall firewall add rule name="OpenSSH" dir=in action=allow protocol=TCP localport=22
```

### 4.3. Windows 방화벽 비활성화 테스트

```powershell
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False
```

**결과:** 여전히 실패 (안랩이 별도로 차단 중으로 추정)

---

## 5. 교훈 및 결론

> [!important] 핵심 교훈: 환경 일치의 중요성
> 온프레미스 서비스 이전 시 OS 환경 차이를 간과하면 안 됨

### 5.1. Windows SSH의 현실

| 구분 | Linux | Windows |
|------|-------|---------|
| 설치 | `apt install openssh-server` | MSI + 설정파일 + 호스트키 + 방화벽 + 백신... |
| 권한 | `sudo` | UAC (SSH에서 상승 불가) |
| 에디션 제약 | 없음 | Home vs Pro |
| 기본 지원 | O | X (원래 RDP 문화) |

### 5.2. 다중 방화벽 레이어 인식

```
[SSH 요청]
    → Windows 방화벽 (해결)
    → 안랩 V3 방화벽 (미해결)
    → [접속 실패]
```

### 5.3. 실패 원인 요약

1. **Windows 11 Home 에디션**: OpenSSH Server 기본 미지원
2. **안랩 V3**: 자체 방화벽으로 SSH 차단 (Windows 방화벽과 별개)
3. **UAC 제약**: SSH 접속해도 관리자 권한 상승 불가

---

## 6. 향후 계획

### 6.1. 단기 해결책

- [ ] 안랩 V3 방화벽 설정에서 SSH(포트 22) 허용
- [ ] 또는 안랩 실시간 감시 비활성화 후 테스트

### 6.2. 장기 해결책

> [!tip] 권장 방향
> Linux 환경으로 통일하여 환경 일치 달성

**옵션 1: WSL2 활용**
```powershell
wsl --install
# Ubuntu에서 SSH 서버 구성
sudo apt install openssh-server
```

**옵션 2: 별도 Linux 머신 사용**
- Docker 컨테이너로 서비스 배포
- Linux VM 또는 물리 서버 사용

**옵션 3: Windows Pro 업그레이드**
- 기본 OpenSSH Server 지원
- RDP 호스트 기능 포함

---

## 관련 문서

- [[Tailscale 네트워크 설정]]
- [[WSL2 설치 가이드]]

---

> 작성일: 2026-02-03
> 상태: 안랩 방화벽 해결 후 재시도 예정
