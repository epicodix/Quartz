---
title: Linux 가상머신 트러블슈팅 및 FAQ
tags:
  - Linux
  - VirtualBox
  - 트러블슈팅
  - FAQ
  - 문제해결
aliases:
  - 리눅스트러블슈팅
  - 가상머신문제해결
date: 2025-12-02
category: 1_가이드/트러블슈팅
status: 완성
priority: 높음
---

# 🎯 Linux 가상머신 트러블슈팅 및 FAQ

## 📑 목차
- [[#1. VirtualBox 설치 관련 문제|VirtualBox 문제]]
- [[#2. Ubuntu 설치 관련 문제|Ubuntu 설치 문제]]
- [[#3. 네트워크 및 SSH 문제|네트워크 문제]]
- [[#4. 성능 및 최적화 문제|성능 문제]]

---

## 1. VirtualBox 설치 관련 문제

### 🚨 macOS 권한 및 보안 문제

#### 📋 "시스템 확장이 차단됨" 오류

> [!danger] 문제: Oracle 시스템 확장이 차단됨
> VirtualBox 설치 후 가상머신을 실행할 수 없는 경우

**💡 해결방법**:
1. **시스템 환경설정** → **보안 및 개인정보보호**
2. **일반** 탭에서 "Oracle America, Inc.의 시스템 소프트웨어 로드가 차단됨" 메시지 확인
3. **허용** 버튼 클릭
4. **관리자 비밀번호** 입력
5. **재부팅** 후 VirtualBox 재실행

#### 📋 "커널 드라이버가 설치되지 않음" 오류

```bash
# 오류 메시지 예시
The VirtualBox kernel modules do not match this version of VirtualBox

# 해결 명령어
sudo /Library/Application\ Support/VirtualBox/LaunchDaemons/VirtualBoxStartup.sh restart

# VirtualBox 커널 모듈 재설치
sudo kextload -b org.virtualbox.kext.VBoxDrv
sudo kextload -b org.virtualbox.kext.VBoxNetFlt
sudo kextload -b org.virtualbox.kext.VBoxNetAdp
sudo kextload -b org.virtualbox.kext.VBoxUSB
```

### ⚠️ Homebrew 설치 관련 문제

#### 📊 설치 방법별 문제 비교

| 설치 방법 | 문제점 | 해결책 |
|----------|---------|--------|
| 공식 .dmg | 권한 설정 복잡 | 시스템 환경설정에서 허용 |
| Homebrew | 권한 자동 처리 안됨 | `brew install --cask virtualbox` 후 수동 권한 설정 |
| 수동 설치 | 최신 버전 보장 | 공식 사이트에서 다운로드 권장 |

---

## 2. Ubuntu 설치 관련 문제

### 🚨 부팅 및 설치 오류

#### 📋 "Failed to start the virtual machine" 오류

> [!warning] 가상머신 시작 실패
> 하드웨어 가상화 또는 메모리 부족 문제

**원인 및 해결방법**:
```yaml
메모리 부족:
  - 증상: "VERR_EM_NO_MEMORY" 오류
  - 해결: RAM 할당량 줄이기 (2GB → 1GB)
  - 명령: VirtualBox 설정 → 시스템 → 기본 메모리

하드웨어 가속 문제:
  - 증상: "VT-x is not available" 오류  
  - 해결: 가상화 기능 확인
  - Intel Mac: Intel VT-x 활성화
  - Apple Silicon: 지원 안됨 (대안: UTM, Parallels)
```

#### 📋 ISO 부팅 실패

```bash
# 일반적인 ISO 문제
1. ISO 파일 손상 확인
   sha256sum ubuntu-22.04.3-desktop-amd64.iso
   
2. ISO 마운트 확인
   VirtualBox → 설정 → 저장소 → IDE 컨트롤러
   
3. 부팅 순서 변경
   VirtualBox → 설정 → 시스템 → 마더보드 → 부팅 순서
```

### ⚙️ 설치 진행 중 문제

#### 📊 설치 단계별 문제 해결

| 단계 | 문제 | 해결방법 |
|------|------|----------|
| 언어선택 | 한글 폰트 깨짐 | English 선택 후 설치 완료 후 한글 설정 |
| 파티션 | 디스크 인식 안됨 | 가상 디스크 크기 재설정 (25GB → 50GB) |
| 사용자 설정 | 비밀번호 정책 오류 | 8자 이상, 영문+숫자+특수문자 조합 |
| 설치 진행 | 멈춤 현상 | RAM 4GB 이상 할당, 3D 가속 비활성화 |

---

## 3. 네트워크 및 SSH 문제

### 🚨 네트워크 연결 문제

#### 📋 인터넷 연결 안됨

> [!warning] "네트워크 연결 없음" 오류
> 가상머신에서 인터넷에 접속할 수 없는 경우

**단계별 진단**:
```bash
# 1. 네트워크 인터페이스 확인
ip addr show
# 출력에 enp0s3 또는 eth0이 있어야 함

# 2. DNS 설정 확인  
nslookup google.com
# 응답이 없으면 DNS 문제

# 3. 게이트웨이 확인
ip route show
# default via가 설정되어 있어야 함

# 4. VirtualBox 네트워크 설정 확인
# 설정 → 네트워크 → 어댑터 1 → NAT 활성화
```

#### 📋 브리지 어댑터 문제

```yaml
문제점:
  - Wi-Fi 연결시 브리지 불안정
  - IP 할당 실패
  - 호스트와 연결 안됨

해결방법:
  1. 네트워크 어댑터 변경:
     - Wi-Fi → 이더넷 (가능한 경우)
     - 브리지 → NAT + 포트포워딩
  
  2. 네트워크 재시작:
     - sudo systemctl restart networking
     - sudo netplan apply
  
  3. DHCP 갱신:
     - sudo dhclient -r
     - sudo dhclient
```

### 🔒 SSH 접속 문제

#### 📋 "Connection refused" 오류

```bash
# SSH 서비스 상태 확인
sudo systemctl status ssh

# 서비스 재시작
sudo systemctl restart ssh

# 포트 확인
sudo netstat -tlnp | grep :22

# 방화벽 확인
sudo ufw status
sudo ufw allow ssh
```

#### 📋 키 인증 실패

```bash
# SSH 키 권한 설정
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
chmod 600 ~/.ssh/id_rsa
chmod 644 ~/.ssh/id_rsa.pub

# SELinux 컨텍스트 복구 (필요시)
restorecon -R ~/.ssh
```

---

## 4. 성능 및 최적화 문제

### 🚨 성능 저하 문제

#### 📋 가상머신 느림 현상

> [!tip] 성능 최적화 체크리스트
> 가상머신이 느리게 동작하는 경우 확인할 사항들

**하드웨어 설정 최적화**:
```yaml
메모리 설정:
  - 권장: 호스트 RAM의 50% 이하
  - 최소: Ubuntu Desktop 4GB
  - 최적: 8GB 이상

CPU 설정:
  - 권장: 호스트 CPU 코어의 절반
  - 최소: 2코어
  - VT-x/AMD-V 활성화 필수

저장소 설정:
  - SSD 사용 권장
  - 동적 할당 vs 고정 크기
  - 호스트 캐시: 비활성화
```

#### 📋 Guest Additions 문제

```bash
# Guest Additions 설치 확인
lsmod | grep vbox

# 수동 재설치
sudo apt purge virtualbox-guest*
sudo apt install virtualbox-guest-utils virtualbox-guest-x11

# 3D 가속 테스트
glxinfo | grep "direct rendering"
```

### ⚙️ 디스플레이 및 해상도 문제

#### 📊 화면 관련 문제 해결

| 문제 | 원인 | 해결방법 |
|------|------|----------|
| 해상도 고정 | Guest Additions 미설치 | Guest Additions 재설치 |
| 화면 깨짐 | 3D 가속 충돌 | 3D 가속 비활성화 |
| 마우스 잠김 | 마우스 통합 문제 | 호스트 키(Cmd) + I |
| 전체화면 문제 | 스케일링 문제 | View → Auto-resize Guest Display |

#### 💻 해상도 수동 설정

```bash
# 현재 해상도 확인
xrandr

# 사용 가능한 해상도 추가
gtf 1920 1080 60
# 출력된 Modeline을 사용하여:
xrandr --newmode "1920x1080_60.00" 173.00 1920 2048 2248 2576 1080 1083 1088 1120 -hsync +vsync
xrandr --addmode Virtual1 1920x1080_60.00
xrandr --output Virtual1 --mode 1920x1080_60.00
```

---

## 🔍 고급 진단 및 로그 분석

### 💻 시스템 로그 확인

#### 📋 주요 로그 파일 위치

```bash
# VirtualBox 호스트 로그 (macOS)
~/VirtualBox VMs/[VM이름]/Logs/VBox.log

# Ubuntu 시스템 로그
sudo journalctl -xe
sudo dmesg | tail -20
/var/log/syslog

# 네트워크 로그
/var/log/kern.log
sudo journalctl -u networking
```

### 🔧 성능 모니터링

```bash
# 시스템 리소스 확인
htop
iostat 1 5
free -h
df -h

# 네트워크 트래픽
iftop
netstat -i
```

---

## 📋 자주 묻는 질문 (FAQ)

### ❓ Apple Silicon Mac에서 VirtualBox 사용 가능한가요?

> [!info] Apple Silicon 제한사항
> VirtualBox는 Apple Silicon(M1/M2) Mac에서 정식 지원되지 않습니다.

**대안**:
- **UTM**: 오픈소스 가상화 (QEMU 기반)
- **Parallels Desktop**: 상용 소프트웨어
- **VMware Fusion**: 개인용 무료

### ❓ 가상머신을 다른 컴퓨터로 이전하는 방법은?

```bash
# VirtualBox 가상머신 내보내기
VBoxManage export "VM이름" --output "~/Desktop/ubuntu-vm.ova"

# 다른 컴퓨터에서 가져오기  
VBoxManage import "~/Desktop/ubuntu-vm.ova"
```

### ❓ 스냅샷 기능 사용 방법은?

```bash
# 현재 상태 스냅샷 생성
VBoxManage snapshot "VM이름" take "스냅샷이름" --description "설명"

# 스냅샷 목록 확인
VBoxManage snapshot "VM이름" list

# 스냅샷으로 복원
VBoxManage snapshot "VM이름" restore "스냅샷이름"
```

---

## 🎯 추가 리소스 및 참고자료

### 📚 관련 문서
- [[macOS에서_VirtualBox_설치_가이드]] - 기본 설치 가이드
- [[Ubuntu_가상머신_생성_가이드]] - Ubuntu 설치 과정
- [[리눅스_네트워크_설정_가이드]] - 네트워크 설정 상세

### 🔗 유용한 링크
- [VirtualBox 공식 문서](https://www.virtualbox.org/manual/)
- [Ubuntu 공식 가이드](https://help.ubuntu.com/)
- [VirtualBox 포럼](https://forums.virtualbox.org/)

### 📞 지원 요청시 포함할 정보
- 호스트 OS 버전 (macOS 버전)
- VirtualBox 버전
- 게스트 OS 버전 (Ubuntu 버전)
- 오류 메시지 전체 텍스트
- VBox.log 파일의 관련 부분