---
title: macOS에서 리눅스 설치 종합 가이드
tags:
  - Linux
  - macOS
  - VirtualBox
  - Ubuntu
  - 설치가이드
aliases:
  - 리눅스설치가이드
  - 가상머신종합가이드
date: 2025-12-02
category: 1_가이드/종합
status: 완성
priority: 높음
---

# 🎯 macOS에서 리눅스 설치 종합 가이드

## 📑 목차
- [[#1. 개요 및 준비사항|개요]]
- [[#2. 설치 단계별 가이드|설치 단계]]
- [[#3. 주요 설정 및 최적화|설정 최적화]]
- [[#📚 관련 가이드 링크|관련 가이드]]

---

## 1. 개요 및 준비사항

> [!note] macOS에서 리눅스 실행 방법
> macOS에서 리눅스를 실행하는 가장 일반적이고 안정적인 방법은 VirtualBox를 사용한 가상화입니다.

### 💡 시스템 요구사항

#### 📋 하드웨어 요구사항

| 구성요소 | 최소 사양 | 권장 사양 | 설명 |
|----------|-----------|-----------|------|
| **RAM** | 8GB | 16GB 이상 | 호스트 4GB + 게스트 4GB |
| **저장공간** | 60GB | 100GB 이상 | macOS + VirtualBox + Ubuntu |
| **CPU** | Intel/Apple Silicon | Intel 권장 | VirtualBox는 Intel에서 최적 |
| **네트워크** | Wi-Fi/이더넷 | 유선 권장 | 안정적인 다운로드를 위해 |

#### ⚠️ Apple Silicon 사용자 주의사항

> [!warning] Apple Silicon 제한 및 권장 솔루션
> M1/M2 Mac 사용자는 VirtualBox가 지원되지 않으므로 다른 가상화 솔루션을 선택해야 합니다.

```yaml
Apple Silicon 권장 순위:
  1순위 - VMware Fusion:
    - 장점: 개인용 완전 무료, 뛰어난 성능, Rocky Linux 완벽 지원
    - 단점: 상업적 사용 제한
    - 적용: 모든 Linux 배포판 설치 성공
    
  2순위 - UTM:
    - 장점: 완전 무료, 오픈소스, ARM 네이티브 지원
    - 단점: 설정 복잡, Rocky Linux 설치 어려움
    - 적용: Ubuntu 등 일반 배포판 권장
    
  3순위 - Parallels Desktop:
    - 장점: 최고 성능, 사용 편의성
    - 단점: 연간 구독료 필요 ($99/년)
    - 적용: 예산이 있는 경우 최적 선택
```

> [!tip] Rocky Linux 설치 경험
> 실제 테스트 결과, VirtualBox와 UTM에서는 Rocky Linux 설치 시 문제가 발생했지만, **VMware Fusion에서는 완벽하게 설치가 가능**합니다.

---

## 2. 설치 단계별 가이드

### 💡 전체 설치 프로세스

#### 📋 설치 순서 및 예상 소요시간

> [!example] 설치 로드맵
> 1. **VirtualBox 설치** (15분)
> 2. **Ubuntu ISO 다운로드** (30분)
> 3. **가상머신 생성 및 설정** (10분)
> 4. **Ubuntu 설치** (30분)
> 5. **네트워크 및 SSH 설정** (15분)
> 
> **총 소요시간**: 약 1시간 40분

### 🔧 단계별 상세 가이드

#### 1단계: VirtualBox 설치
> 📖 **상세 가이드**: [[macOS에서_VirtualBox_설치_가이드]]

**핵심 포인트**:
- Oracle 공식 사이트에서 다운로드
- macOS 보안 설정에서 Oracle 허용 필요
- 시스템 확장 프로그램 승인 필수

#### 2단계: Ubuntu 가상머신 생성
> 📖 **상세 가이드**: [[Ubuntu_가상머신_생성_가이드]]

**핵심 설정**:
```yaml
가상머신 설정:
  이름: Ubuntu-Desktop-22.04
  운영체제: Linux → Ubuntu (64-bit)
  메모리: 4096MB (4GB)
  하드디스크: 동적 할당 50GB
  
네트워크:
  어댑터 1: NAT (기본) 또는 브리지 어댑터
  
디스플레이:
  비디오 메모리: 128MB
  3D 가속: 활성화
```

#### 3단계: 네트워크 및 SSH 설정
> 📖 **상세 가이드**: [[리눅스_네트워크_설정_가이드]]

**주요 설정**:
- SSH 서버 설치 및 활성화
- 네트워크 어댑터 설정 (브리지 또는 NAT)
- 방화벽 설정 및 포트 열기

---

## 3. 주요 설정 및 최적화

### 💡 성능 최적화

#### 📋 VirtualBox 최적화 설정

```yaml
# 📊 성능 최적화 체크리스트
시스템 설정:
  프로세서: 2코어 이상
  실행 제한: 85%
  PAE/NX 활성화: 체크
  
가속:
  하드웨어 가속: VT-x/AMD-V 활성화
  Nested Paging: 활성화
  
디스플레이:
  비디오 메모리: 128MB
  3D 가속: 활성화 (안정성 확인 후)
  2D 비디오 가속: 활성화
```

#### 💻 Guest Additions 설치

```bash
# Ubuntu에서 Guest Additions 설치
sudo apt update
sudo apt install build-essential dkms linux-headers-$(uname -r) -y

# VirtualBox 메뉴에서 Guest Additions CD 삽입 후
cd /media/$USER/VBox_GAs_*
sudo ./VBoxLinuxAdditions.run
sudo reboot
```

### 🔒 보안 설정

#### 📋 SSH 보안 강화

```bash
# SSH 설정 파일 편집
sudo nano /etc/ssh/sshd_config

# 권장 보안 설정
Port 22
PermitRootLogin no
PasswordAuthentication yes  # 초기 설정 후 no로 변경
PubkeyAuthentication yes
MaxAuthTries 3
X11Forwarding no

# 방화벽 설정
sudo ufw enable
sudo ufw allow ssh
sudo ufw status
```

### ⚙️ 개발 환경 설정

#### 📋 기본 개발 도구 설치

```bash
# 시스템 업데이트
sudo apt update && sudo apt upgrade -y

# 기본 개발 도구
sudo apt install -y \
  git \
  curl \
  wget \
  vim \
  htop \
  tree \
  unzip \
  build-essential

# Node.js (선택사항)
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
sudo apt install -y nodejs

# Docker (선택사항)
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
```

---

## 📚 관련 가이드 링크

### 🔗 설치 가이드
- **[[가상화/VMware_Fusion_Rocky_Linux_설치_가이드]]**: VMware Fusion으로 Rocky Linux 설치 (★ 권장)
- **[[가상화/macOS에서_VirtualBox_설치_가이드]]**: VirtualBox 설치 및 설정 (Intel Mac 전용)
- **[[가상화/Ubuntu_가상머신_생성_가이드]]**: Ubuntu 가상머신 생성 과정
- **[[가상화/리눅스_네트워크_설정_가이드]]**: 네트워크 및 SSH 접속 설정

### 🛠️ 문제해결 및 비교
- **[[가상화/Linux_가상머신_트러블슈팅_가이드]]**: 문제해결 및 FAQ
- **[[가상화/macOS_가상화_솔루션_비교_가이드]]**: VirtualBox vs UTM vs VMware Fusion 상세 비교

### 📊 활용 가이드 (예정)
- **리눅스_개발환경_구축_가이드**: 개발 도구 설치 및 설정
- **Docker_컨테이너_관리_가이드**: 컨테이너 환경 구성
- **쿠버네티스_실습환경_구축**: K8s 학습 환경 설정

---

## 🎯 다음 단계 추천

### 💡 학습 경로 제안

#### 📋 초급자 경로
1. **Linux 기본 명령어 학습**
2. **파일 시스템 이해**
3. **패키지 관리 (apt) 활용**
4. **사용자 및 권한 관리**

#### 📋 중급자 경로
1. **Shell 스크립팅**
2. **네트워크 설정 및 관리**
3. **서비스 및 프로세스 관리 (systemd)**
4. **보안 설정 강화**

#### 📋 고급자 경로
1. **Docker 컨테이너 활용**
2. **쿠버네티스 클러스터 구축**
3. **CI/CD 파이프라인 구성**
4. **모니터링 및 로깅 시스템**

### 🚀 실습 프로젝트 제안

```yaml
프로젝트 아이디어:
  웹 서버 구축:
    - Apache/Nginx 설치
    - SSL 인증서 설정
    - 도메인 연결
    
  개발 환경 구성:
    - Git 서버 설치
    - Jenkins CI/CD
    - 코드 품질 도구 연동
    
  클라우드 실습:
    - 가상머신을 클라우드로 이전
    - 스케일링 및 로드밸런싱
    - 모니터링 대시보드 구축
```

---

## 📝 체크리스트

### ✅ 설치 완료 확인

> [!example] 최종 확인 사항
> - [ ] VirtualBox 정상 실행
> - [ ] Ubuntu 부팅 및 로그인
> - [ ] 인터넷 연결 확인
> - [ ] SSH 접속 가능
> - [ ] Guest Additions 설치
> - [ ] 화면 해상도 자동 조정
> - [ ] 파일 공유 기능 테스트
> - [ ] 스냅샷 생성 및 복원 테스트

### 🔧 선택적 설정
> - [ ] 고정 IP 주소 설정
> - [ ] SSH 키 인증 설정
> - [ ] 자동 백업 스크립트 구성
> - [ ] 개발 도구 설치
> - [ ] Docker 설치 및 설정

**2025-12-02 현재 시각 기준으로 작성된 가이드입니다.**