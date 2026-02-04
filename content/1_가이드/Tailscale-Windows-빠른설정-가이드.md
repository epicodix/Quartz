---
title: Tailscale Windows 빠른 설정 가이드
tags:
  - tailscale
  - windows
  - vpn
  - setup
aliases:
  - Tailscale 윈도우 설정
  - 테일스케일 설정
date: 2026-02-02
category: 1_가이드/네트워크
status: 완성
priority: 높음
---

# Tailscale Windows 빠른 설정 가이드

> [!tip] 목적
> 새 Windows 디바이스에 Tailscale 설치하고 SSH/원격 접속 가능하게 만들기.
> **관리자 PowerShell에 복붙만 하면 끝!**

---

## 1. Tailscale 설치 (1분)

### 방법 A: winget (권장)

```powershell
winget install Tailscale.Tailscale
```

### 방법 B: 수동 다운로드

https://tailscale.com/download/windows 에서 다운로드 후 설치

---

## 2. Tailscale 로그인

설치 후 시스템 트레이에서 Tailscale 아이콘 클릭 → 로그인

또는 PowerShell에서:
```powershell
tailscale login
```

> [!note] 초대받은 네트워크 참여
> 초대 링크 클릭 → 로그인 → 네트워크 참여 수락

---

## 3. 원클릭 전체 설정 (관리자 PowerShell)

> [!danger] 중요
> **관리자 권한**으로 PowerShell 실행 필수!
> (시작 → PowerShell 검색 → 우클릭 → 관리자로 실행)

아래 전체를 복사해서 붙여넣기:

```powershell
# ============================================
# Tailscale Windows 전체 설정 스크립트
# 관리자 PowerShell에서 실행
# ============================================

Write-Host "=== Tailscale Windows 설정 시작 ===" -ForegroundColor Cyan

# 1. OpenSSH 서버 설치
Write-Host "`n[1/5] OpenSSH 서버 설치 중..." -ForegroundColor Yellow
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0

# 2. SSH 서비스 시작 및 자동 시작 설정
Write-Host "`n[2/5] SSH 서비스 설정 중..." -ForegroundColor Yellow
Start-Service sshd
Set-Service -Name sshd -StartupType Automatic

# 3. SSH 방화벽 규칙 추가
Write-Host "`n[3/5] SSH 방화벽 규칙 추가 중..." -ForegroundColor Yellow
New-NetFirewallRule -Name "OpenSSH-Server-In-TCP" -DisplayName "OpenSSH Server (TCP 22)" -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 -ErrorAction SilentlyContinue

# 4. ICMP (ping) 허용
Write-Host "`n[4/5] ICMP (ping) 허용 중..." -ForegroundColor Yellow
New-NetFirewallRule -Name "ICMP-Allow-Incoming" -DisplayName "Allow ICMP (Ping)" -Protocol ICMPv4 -IcmpType 8 -Direction Inbound -Action Allow -ErrorAction SilentlyContinue

# 5. Tailscale 상태 확인
Write-Host "`n[5/5] Tailscale 상태 확인 중..." -ForegroundColor Yellow
tailscale status

# 완료
Write-Host "`n=== 설정 완료! ===" -ForegroundColor Green
Write-Host "Tailscale IP: " -NoNewline
tailscale ip -4
Write-Host "`n다른 기기에서 SSH 테스트: ssh $env:USERNAME@<위의 IP>" -ForegroundColor Cyan
```

---

## 4. 설정 확인

### Tailscale 상태 확인
```powershell
tailscale status
```

### 내 Tailscale IP 확인
```powershell
tailscale ip -4
```

### SSH 서비스 상태 확인
```powershell
Get-Service sshd
```

---

## 5. 다른 기기에서 접속 테스트

### Mac/Linux에서 테스트

```bash
# Tailscale ping (DERP 릴레이 통해서라도 연결 확인)
tailscale ping <Windows의 Tailscale IP>

# 일반 ping
ping <Windows의 Tailscale IP>

# SSH 접속
ssh <윈도우사용자명>@<Windows의 Tailscale IP>
```

---

## 6. 트러블슈팅

### 문제: `tailscale status` 안 됨

```powershell
# Tailscale 서비스 재시작
Restart-Service Tailscale
```

### 문제: SSH 연결 거부

```powershell
# SSH 서비스 상태 확인
Get-Service sshd

# 서비스 시작
Start-Service sshd

# 방화벽 규칙 확인
Get-NetFirewallRule -Name "*ssh*" | Select-Object Name, Enabled, Direction, Action
```

### 문제: ping 안 됨 (SSH는 됨)

```powershell
# ICMP 방화벽 규칙 다시 추가
netsh advfirewall firewall add rule name="ICMP Allow" protocol=icmpv4:8,any dir=in action=allow
```

### 문제: direct connection not established

> [!info] 참고
> DERP 릴레이 통해 연결되는 건 정상 동작임. 속도만 약간 느림.
> NAT 환경에서 흔히 발생. 기능상 문제 없음.

---

## 7. 유용한 명령어 모음

| 명령어 | 설명 |
|--------|------|
| `tailscale status` | 연결된 기기 목록 |
| `tailscale ip -4` | 내 Tailscale IPv4 |
| `tailscale ping <IP>` | Tailscale 네트워크로 ping |
| `tailscale up` | Tailscale 연결 |
| `tailscale down` | Tailscale 연결 해제 |
| `tailscale logout` | 로그아웃 |

---

## 8. 요약 체크리스트

- [ ] Tailscale 설치
- [ ] Tailscale 로그인 & 네트워크 참여
- [ ] 관리자 PowerShell에서 전체 설정 스크립트 실행
- [ ] 다른 기기에서 `tailscale ping` 테스트
- [ ] SSH 접속 테스트

---

> 작성일: 2026-02-02 | 삽질 방지용
