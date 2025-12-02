---
title: VMware Fusion으로 Rocky Linux 설치 가이드
tags:
  - VMware
  - RockyLinux
  - macOS
  - 가상화
  - RHEL
aliases:
  - VMware설치
  - RockyLinux설치
date: 2025-12-02
category: 1_가이드/가상화
status: 완성
priority: 높음
---

# 🎯 VMware Fusion으로 Rocky Linux 설치 가이드

## 📑 목차
- [[#1. VMware Fusion 개요 및 설치|VMware Fusion 설치]]
- [[#2. Rocky Linux 소개|Rocky Linux 소개]]
- [[#3. VMware Fusion으로 Rocky Linux 설치|설치 과정]]
- [[#4. 초기 설정 및 최적화|초기 설정]]

---

## 1. VMware Fusion 개요 및 설치

> [!note] VMware Fusion 개인용 무료 라이선스
> VMware Fusion은 2024년부터 개인 사용자에게 무료로 제공되며, 상업적 용도가 아닌 경우 라이선스 비용 없이 사용 가능합니다.

### 💡 VMware Fusion vs 다른 가상화 솔루션

#### 📊 가상화 솔루션 비교

| 구분 | VirtualBox | UTM | VMware Fusion |
|------|------------|-----|---------------|
| **가격** | 무료 | 무료 | 개인용 무료 |
| **Intel Mac** | ✅ 최적 | ✅ 지원 | ✅ 최적 |
| **Apple Silicon** | ❌ 미지원 | ✅ 최적 | ✅ 지원 |
| **Rocky Linux** | ⚠️ 설치 문제 | ⚠️ 설치 문제 | ✅ 완벽 지원 |
| **성능** | 보통 | 좋음 | 매우 좋음 |
| **사용 편의성** | 보통 | 복잡 | 매우 쉬움 |
| **기업 지원** | 제한적 | 없음 | 완전 지원 |

### 🔧 VMware Fusion 설치

#### 📋 다운로드 및 설치 과정

> [!example] VMware Fusion 설치 단계
> 1. **공식 사이트 접속**: [VMware Fusion 개인용](https://www.vmware.com/products/fusion.html)
> 2. **계정 생성**: VMware 계정 생성 (무료)
> 3. **라이선스 등록**: 개인용 라이선스 키 발급
> 4. **다운로드**: Fusion Pro 개인용 버전 다운로드
> 5. **설치**: .dmg 파일 실행 후 설치

#### 💻 설치 명령어 (선택사항)

```bash
# Homebrew를 통한 설치 (라이선스는 별도 등록 필요)
brew install --cask vmware-fusion

# 직접 다운로드 후 설치
open VMware-Fusion-*.dmg
```

#### 🔒 라이선스 등록

```yaml
라이선스 등록 과정:
  1. VMware Fusion 실행
  2. "라이선스 입력" 선택
  3. VMware 계정으로 로그인
  4. 개인용 라이선스 키 자동 적용
  
개인용 라이선스 제한사항:
  - 상업적 용도 금지
  - 기업 환경 사용 불가
  - 개인 학습/개발 목적만 허용
```

---

## 2. Rocky Linux 소개

> [!note] Rocky Linux란?
> Rocky Linux는 Red Hat Enterprise Linux(RHEL)의 무료 대안으로, CentOS의 후속 프로젝트입니다. 엔터프라이즈 환경에서 안정성과 보안을 중시하는 서버용 Linux 배포판입니다.

### 💡 Rocky Linux 특징

#### 📋 주요 특징 및 장점

```yaml
Rocky Linux 8.x/9.x 특징:
  기반: RHEL 소스코드 100% 호환
  지원 기간: 10년 장기 지원 (LTS)
  패키지 관리: DNF/YUM
  초기화 시스템: systemd
  기본 쉘: Bash
  방화벽: firewalld
  SELinux: 기본 활성화

장점:
  - 엔터프라이즈급 안정성
  - RHEL 호환성
  - 강력한 보안 기능
  - 서버 환경에 최적화
  - 무료 라이선스
```

#### 📊 Rocky Linux vs 다른 배포판

| 배포판 | 기반 | 패키지 관리 | 주요 용도 | 학습 난이도 |
|--------|------|-------------|-----------|-------------|
| **Rocky Linux** | RHEL | DNF/YUM | 서버, 엔터프라이즈 | 중급 |
| **Ubuntu** | Debian | APT | 데스크톱, 서버 | 초급 |
| **CentOS Stream** | RHEL | DNF/YUM | 테스트, 개발 | 중급 |
| **AlmaLinux** | RHEL | DNF/YUM | 서버, 엔터프라이즈 | 중급 |

### 🎯 Rocky Linux 선택 이유

#### 📋 Rocky Linux가 적합한 경우

> [!example] Rocky Linux 사용 추천 시나리오
> - **엔터프라이즈 환경 학습**: RHEL 환경 실습
> - **서버 관리자 준비**: 리눅스 시스템 관리 학습
> - **인증 시험 대비**: RHCSA, RHCE 등 Red Hat 인증
> - **보안 중심 환경**: SELinux, firewalld 활용
> - **장기 운영 시스템**: 10년 지원 기간 활용

---

## 3. VMware Fusion으로 Rocky Linux 설치

### 💡 Rocky Linux ISO 다운로드

#### 📋 ISO 이미지 선택

```yaml
Rocky Linux 9.x 다운로드 옵션:
  Minimal ISO:
    - 용량: ~2GB
    - 구성: 최소 시스템만 설치
    - 용도: 서버 환경, 커스텀 구성
    
  DVD ISO:
    - 용량: ~10GB
    - 구성: 완전한 패키지 포함
    - 용도: 오프라인 설치, 개발 환경
    
  Boot ISO:
    - 용량: ~1GB
    - 구성: 네트워크 설치용
    - 용도: 최신 패키지로 설치
```

#### 💻 다운로드 링크 및 확인

```bash
# Rocky Linux 9 다운로드 (예시)
wget https://download.rockylinux.org/pub/rocky/9/isos/x86_64/Rocky-9.3-x86_64-minimal.iso

# 체크섬 확인
sha256sum Rocky-9.3-x86_64-minimal.iso
# 또는
curl -s https://download.rockylinux.org/pub/rocky/9/isos/x86_64/CHECKSUM | grep minimal
```

### 🔧 VMware Fusion 가상머신 생성

#### 📋 가상머신 생성 마법사

> [!example] 가상머신 생성 과정
> 1. **VMware Fusion 실행** → "새로 만들기" 클릭
> 2. **설치 방법**: "디스크 또는 이미지에서 설치"
> 3. **ISO 선택**: 다운로드한 Rocky Linux ISO 선택
> 4. **운영체제**: "Linux" → "Red Hat Enterprise Linux 9 64비트"
> 5. **가상머신 이름**: "Rocky-Linux-9" (또는 원하는 이름)

#### 💻 하드웨어 설정

```yaml
# 📊 Rocky Linux 권장 사양
기본 설정:
  메모리: 2048MB (최소) ~ 4096MB (권장)
  프로세서: 2코어
  하드디스크: 20GB (최소) ~ 40GB (권장)
  네트워크: NAT (기본) 또는 브리지

고급 설정:
  가상화 엔진: Intel VT-x/AMD-V
  3D 그래픽: 비활성화 (서버용)
  사운드: 비활성화 (선택사항)
  USB: USB 3.1 지원
```

### ⚙️ Rocky Linux 설치 과정

#### 📋 Anaconda 설치 프로그램

> [!example] 설치 단계
> 1. **부팅 메뉴**: "Install Rocky Linux 9" 선택
> 2. **언어 선택**: 한국어 또는 English (United States)
> 3. **설치 요약**: 각 항목 설정
>    - 키보드: 한국어 또는 US
>    - 시간대: Asia/Seoul
>    - 소프트웨어 선택: 최소 설치 또는 서버
>    - 설치 대상: 자동 파티셔닝

#### 💻 네트워크 및 호스트 이름

```yaml
네트워크 설정:
  이더넷: 자동 활성화
  IPv4: DHCP (기본) 또는 고정 IP
  IPv6: 자동 (기본값)
  
호스트네임:
  형식: rocky-linux.local
  예시: dev-rocky.example.com
```

#### 🔒 사용자 계정 설정

```yaml
Root 계정:
  상태: 활성화 (권장하지 않음)
  대안: sudo 권한 사용자 생성

사용자 계정:
  사용자명: rockyuser (예시)
  암호: 강력한 비밀번호
  관리자 권한: 체크 (sudo 그룹)
  
보안 고려사항:
  - Root 직접 로그인 비활성화
  - 복잡한 비밀번호 설정
  - SSH 키 인증 준비
```

---

## 4. 초기 설정 및 최적화

### 💡 설치 완료 후 기본 설정

#### 📋 시스템 업데이트

```bash
# 시스템 업데이트
sudo dnf update -y

# 기본 도구 설치
sudo dnf install -y \
    vim \
    wget \
    curl \
    git \
    htop \
    tree \
    net-tools \
    bind-utils

# 개발 도구 그룹 설치 (선택사항)
sudo dnf groupinstall -y "Development Tools"
```

### 🔧 VMware Tools 설치

#### 📋 VMware Tools 설치 과정

> [!example] VMware Tools 설치
> 1. **VMware 메뉴**: "가상머신" → "VMware Tools 설치"
> 2. **자동 마운트**: CD/DVD 드라이브에 Tools 이미지 마운트
> 3. **수동 설치**: 터미널에서 설치 스크립트 실행

#### 💻 VMware Tools 설치 명령어

```bash
# VMware Tools CD 마운트 확인
lsblk

# 마운트 디렉토리 생성
sudo mkdir -p /mnt/cdrom

# CD 마운트
sudo mount /dev/sr0 /mnt/cdrom

# VMware Tools 압축 해제
cd /tmp
sudo cp /mnt/cdrom/VMwareTools-*.tar.gz .
sudo tar -xzf VMwareTools-*.tar.gz

# 설치 실행
cd vmware-tools-distrib
sudo ./vmware-install.pl

# 기본 설정으로 설치 (모든 질문에 Enter)
# 재부팅
sudo reboot
```

### ⚙️ 네트워크 및 방화벽 설정

#### 📋 네트워크 설정

```bash
# 네트워크 인터페이스 확인
ip addr show
nmcli device status

# 고정 IP 설정 (선택사항)
sudo nmcli con mod "System eth0" \
    ipv4.addresses 192.168.1.100/24 \
    ipv4.gateway 192.168.1.1 \
    ipv4.dns 8.8.8.8 \
    ipv4.method manual

# 네트워크 재시작
sudo nmcli con up "System eth0"
```

#### 🔒 방화벽 및 SELinux 설정

```bash
# 방화벽 상태 확인
sudo firewall-cmd --state
sudo firewall-cmd --list-all

# SSH 포트 허용
sudo firewall-cmd --permanent --add-service=ssh
sudo firewall-cmd --reload

# SELinux 상태 확인
sestatus

# SELinux 모드 변경 (필요시)
sudo setenforce 0  # 임시로 Permissive
# 영구적 변경: /etc/selinux/config 파일 편집
```

### 🚀 SSH 서버 설정

#### 📋 SSH 서비스 활성화

```bash
# SSH 서비스 시작 및 활성화
sudo systemctl start sshd
sudo systemctl enable sshd

# SSH 서비스 상태 확인
sudo systemctl status sshd

# SSH 설정 파일 편집 (보안 강화)
sudo vim /etc/ssh/sshd_config
```

#### 🔧 SSH 보안 설정

```bash
# /etc/ssh/sshd_config 권장 설정
Port 22
PermitRootLogin no
PasswordAuthentication yes
PubkeyAuthentication yes
MaxAuthTries 3
X11Forwarding no

# 설정 적용
sudo systemctl restart sshd

# 방화벽에서 SSH 허용
sudo firewall-cmd --permanent --add-service=ssh
sudo firewall-cmd --reload
```

---

## 🔍 설치 확인 및 테스트

### 💻 시스템 정보 확인

```bash
# 시스템 정보 출력
hostnamectl
cat /etc/os-release
uname -a

# 하드웨어 정보
lscpu
free -h
df -h
lsblk

# 네트워크 연결 테스트
ping -c 4 google.com
curl -I http://google.com
```

### 📊 성능 및 리소스 확인

```bash
# 시스템 리소스 모니터링
htop
iostat 1 5
vmstat 1 5

# 서비스 상태 확인
sudo systemctl list-unit-files --type=service
sudo systemctl list-units --failed
```

---

## 🎯 Rocky Linux 활용 가이드

### 💡 패키지 관리 기본

#### 📋 DNF 명령어 기본

```bash
# 패키지 검색
dnf search nginx
dnf info nginx

# 패키지 설치
sudo dnf install nginx
sudo dnf install -y htop vim

# 패키지 업데이트
sudo dnf update
sudo dnf update nginx

# 패키지 제거
sudo dnf remove nginx
sudo dnf autoremove

# 그룹 패키지 관리
dnf grouplist
sudo dnf groupinstall "Web Server"
```

### 🔧 시스템 서비스 관리

```bash
# 서비스 관리 (systemctl)
sudo systemctl start nginx
sudo systemctl stop nginx
sudo systemctl restart nginx
sudo systemctl reload nginx
sudo systemctl enable nginx
sudo systemctl disable nginx

# 서비스 상태 확인
systemctl status nginx
systemctl is-active nginx
systemctl is-enabled nginx

# 로그 확인
journalctl -u nginx
journalctl -f  # 실시간 로그
```

---

## 🚨 문제해결 및 팁

### ⚠️ 일반적인 문제들

#### 📋 VMware Fusion 관련 문제

| 문제 | 원인 | 해결방법 |
|------|------|----------|
| 부팅 실패 | UEFI 설정 문제 | 가상머신 설정에서 BIOS 모드로 변경 |
| 네트워크 연결 안됨 | 네트워크 어댑터 설정 | NAT 또는 브리지 모드 재설정 |
| VMware Tools 설치 실패 | 커널 헤더 누락 | `dnf install kernel-devel` 실행 |
| 성능 저하 | 리소스 부족 | RAM/CPU 할당량 증가 |

#### 💻 Rocky Linux 관련 팁

```bash
# 최소 설치 후 GUI 추가 설치
sudo dnf groupinstall "GNOME Desktop Environment"
sudo systemctl set-default graphical.target

# 네트워크 인터페이스 이름 확인
nmcli device show

# 시간 동기화
sudo timedatectl set-timezone Asia/Seoul
sudo chrony sources
```

---

## 📚 다음 단계 및 학습 리소스

### 🎯 학습 경로 제안

```yaml
초급 단계:
  - 기본 명령어 숙달
  - 파일 시스템 구조 이해
  - 패키지 관리 (DNF) 활용
  - 사용자 및 권한 관리

중급 단계:
  - 서비스 및 프로세스 관리
  - 네트워크 설정 및 관리
  - 방화벽 및 SELinux 설정
  - 쉘 스크립팅

고급 단계:
  - 시스템 모니터링 및 로깅
  - 웹 서버 구축 (Apache/Nginx)
  - 컨테이너 환경 (Docker/Podman)
  - 자동화 도구 (Ansible)
```

### 🔗 관련 가이드
- [[리눅스_네트워크_설정_가이드]] - 고급 네트워크 설정
- [[Linux_가상머신_트러블슈팅_가이드]] - 문제해결 가이드
- [[../macOS_리눅스_설치_종합_가이드]] - 전체 설치 가이드 개요
- **Red_Hat_인증_준비_가이드** (예정) - RHCSA/RHCE 준비

**VMware Fusion의 개인용 무료 라이선스를 활용해 Rocky Linux를 성공적으로 설치하고 엔터프라이즈 Linux 환경을 경험해보세요!**