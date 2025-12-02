---
title: Ubuntu 가상머신 생성 및 설치 가이드
tags:
  - Ubuntu
  - VirtualBox
  - Linux
  - 가상머신
  - 설치가이드
aliases:
  - Ubuntu설치
  - 가상머신생성
date: 2025-12-02
category: 1_가이드/가상화
status: 완성
priority: 높음
---

# 🎯 Ubuntu 가상머신 생성 및 설치 가이드

## 📑 목차
- [[#1. 가상머신 생성 및 설정|가상머신 생성]]
- [[#2. Ubuntu ISO 다운로드|Ubuntu ISO]]
- [[#3. Ubuntu 설치 과정|설치 과정]]
- [[#4. 초기 설정 및 최적화|초기 설정]]

---

## 1. 가상머신 생성 및 설정

> [!note] 가상머신 사양 권장사항
> Ubuntu Desktop의 경우 최소 4GB RAM, 25GB 디스크 공간이 필요하며, 원활한 사용을 위해 8GB RAM을 권장합니다.

### 💡 VirtualBox에서 새 가상머신 생성

#### 📋 기본 설정

> [!example] 가상머신 생성 과정
> 1. **VirtualBox 실행** → "새로 만들기" 클릭
> 2. **이름**: Ubuntu-Desktop (또는 원하는 이름)
> 3. **유형**: Linux
> 4. **버전**: Ubuntu (64-bit)
> 5. **메모리**: 4096MB (4GB) 이상
> 6. **하드디스크**: 새 가상 하드디스크 만들기

#### 💻 상세 하드웨어 설정

```yaml
# 📊 권장 가상머신 사양
기본 설정:
  RAM: 4096MB (최소) ~ 8192MB (권장)
  프로세서: 2코어 이상
  비디오 메모리: 128MB
  하드디스크: 동적 할당, 50GB

고급 설정:
  3D 가속: 활성화
  오디오: 활성화
  USB: USB 3.0 컨트롤러
  공유 폴더: 필요시 설정
```

### 🔧 네트워크 설정

#### 📋 네트워크 어댑터 구성

| 설정 유형 | 용도 | 특징 |
|----------|------|------|
| NAT | 기본 인터넷 접속 | 외부에서 접근 불가 |
| 브리지 | 네트워크 서비스 제공 | 실제 IP 할당 |
| 호스트 전용 | 호스트와만 통신 | 격리된 네트워크 |

---

## 2. Ubuntu ISO 다운로드

### 💡 공식 Ubuntu 이미지 다운로드

#### 📋 다운로드 옵션

> [!example] Ubuntu 버전 선택
> 1. **Ubuntu Desktop 22.04 LTS**: GUI 환경, 장기 지원
> 2. **Ubuntu Server 22.04 LTS**: CLI 환경, 서버용
> 3. **Ubuntu Desktop 23.10**: 최신 기능, 9개월 지원
> 4. **다운로드 사이트**: [ubuntu.com/download](https://ubuntu.com/download)

#### 💻 다운로드 명령어 (선택사항)

```bash
# 터미널에서 직접 다운로드
wget https://releases.ubuntu.com/22.04.3/ubuntu-22.04.3-desktop-amd64.iso

# 체크섬 확인
sha256sum ubuntu-22.04.3-desktop-amd64.iso
```

### 🔍 ISO 파일 마운트

#### 📋 VirtualBox ISO 설정

> [!example] ISO 마운트 과정
> 1. **가상머신 설정** → "저장소" 클릭
> 2. **컨트롤러: IDE** 하위의 CD/DVD 아이콘 선택
> 3. **CD/DVD 드라이브** → "디스크 파일 선택"
> 4. **다운로드한 Ubuntu ISO 파일** 선택
> 5. **확인** 클릭

---

## 3. Ubuntu 설치 과정

### 💡 부팅 및 언어 설정

#### 📋 초기 설치 화면

> [!example] 설치 시작
> 1. **가상머신 시작** → ISO에서 부팅
> 2. **언어 선택**: 한국어 또는 English
> 3. **설치 옵션**: "Ubuntu 설치" 선택
> 4. **키보드 레이아웃**: Korean 또는 English (US)

#### 💻 설치 유형 및 파티션

```yaml
# 📊 설치 옵션 설정
기본 설정:
  설치 유형: "일반 설치"
  기타 옵션: 
    - "Ubuntu 설치 중 업데이트 다운로드"
    - "그래픽과 Wi-Fi 하드웨어, MP3와 기타 미디어 서드파티 소프트웨어 설치"

파티션:
  방식: "디스크 전체 사용하고 Ubuntu 설치"
  파일시스템: ext4
  스왑: 자동 설정
```

### 🔧 사용자 계정 설정

#### 📋 계정 정보 입력

| 항목 | 예시 | 설명 |
|------|------|------|
| 이름 | Ubuntu User | 표시될 사용자 이름 |
| 컴퓨터 이름 | ubuntu-desktop | 호스트네임 |
| 사용자명 | ubuntu | 로그인 ID |
| 암호 | 강력한 비밀번호 | sudo 권한용 |

---

## 4. 초기 설정 및 최적화

### 💡 설치 완료 후 기본 설정

#### 📋 시스템 업데이트

> [!example] 첫 설정 과정
> 1. **재부팅** 후 로그인
> 2. **소프트웨어 업데이터** 실행
> 3. **터미널** 열기 (Ctrl + Alt + T)
> 4. **시스템 업데이트** 실행

#### 💻 필수 업데이트 명령어

```bash
# 패키지 목록 업데이트
sudo apt update

# 설치된 패키지 업그레이드
sudo apt upgrade -y

# 불필요한 패키지 정리
sudo apt autoremove -y

# 스냅 패키지 업데이트
sudo snap refresh
```

### 🔧 VirtualBox Guest Additions 설치

#### 📋 Guest Additions 설치 과정

> [!example] 성능 향상을 위한 설치
> 1. **가상머신 메뉴** → "장치" → "Guest Additions CD 이미지 삽입"
> 2. **자동 실행 대화상자** → "실행" 클릭
> 3. **암호 입력** 후 설치 진행
> 4. **재부팅** 필요

#### 💻 수동 설치 명령어

```bash
# 의존성 패키지 설치
sudo apt install build-essential dkms linux-headers-$(uname -r)

# Guest Additions CD 마운트
sudo mkdir -p /mnt/cdrom
sudo mount /dev/cdrom /mnt/cdrom

# Guest Additions 설치
cd /mnt/cdrom
sudo ./VBoxLinuxAdditions.run

# 재부팅
sudo reboot
```

### ⚙️ 성능 최적화 설정

#### 📊 시스템 최적화 옵션

| 설정 영역 | 최적화 방법 | 효과 |
|----------|-------------|------|
| 디스플레이 | 3D 가속 활성화 | GUI 성능 향상 |
| 메모리 | 스왑 설정 조정 | 메모리 효율성 |
| 네트워크 | 어댑터 유형 최적화 | 네트워크 속도 |
| 공유폴더 | 자동 마운트 설정 | 파일 공유 편의성 |

#### 💻 추가 최적화 명령어

```bash
# 스왑 사용량 조정 (선택사항)
echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf

# 파일 시스템 성능 최적화
sudo tune2fs -o journal_data_writeback /dev/sda1

# 부팅 시간 단축
sudo systemctl disable snapd
sudo systemctl disable NetworkManager-wait-online
```

---

## 🎯 설치 완료 확인

### 🔍 정상 설치 검증

#### 📋 확인 체크리스트

> [!example] 설치 검증 항목
> 1. **부팅**: 정상적인 GUI 부팅 확인
> 2. **네트워크**: 인터넷 연결 테스트
> 3. **해상도**: 화면 해상도 자동 조정 확인
> 4. **마우스**: 마우스 포인터 자유로운 이동
> 5. **공유폴더**: 호스트와 파일 공유 테스트

#### 💻 시스템 정보 확인

```bash
# 시스템 정보 출력
neofetch

# 또는 기본 명령어로 확인
uname -a
lscpu
free -h
df -h
```

---

## 🚀 다음 단계

Ubuntu 설치 완료 후 다음 가이드들을 참고하세요:
- [[리눅스_네트워크_설정_가이드]] - 고급 네트워크 설정
- [[SSH_접속_설정_가이드]] - 원격 접속 환경 구성  
- [[리눅스_개발환경_구축_가이드]] - 개발 도구 설치 및 설정