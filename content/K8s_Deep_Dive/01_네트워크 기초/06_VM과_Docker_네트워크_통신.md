---
title: VM과 Docker 네트워크 통신
tags:
  - VM
  - Docker
  - 네트워크
  - 호스트
  - Guest OS
aliases:
  - VM네트워크
  - Docker네트워크
  - 호스트통신
date: 2025-12-02
category: K8s_Deep_Dive/네트워크기초
status: 완성
priority: 높음
---

# VM과 Docker 네트워크 통신

## 📑 목차
- [[#1. 집과 아파트로 이해하는 기본 개념|집과 아파트 비유]]
- [[#2. VM 네트워크 - 독립된 집|VM 네트워크]]
- [[#3. Docker 네트워크 - 아파트 내부|Docker 네트워크]]
- [[#4. 실제 통신 시나리오와 문제 해결|통신 시나리오]]

---

## 1. 집과 아파트로 이해하는 기본 개념

### 🏠 현실 세계 비유

> [!note] 핵심 비유
> **Host (물리 서버) = 땅**  
> **VM = 독립된 집**  
> **Docker = 아파트 내부의 방들**

#### 📊 전체 구조 한눈에 보기

```
🌍 물리적 땅 (Host - macOS/Windows/Linux)
├── 🏠 집1 (VM - Ubuntu)
│   ├── 📞 전화선 (네트워크 인터페이스)
│   ├── 🚪 대문 (방화벽)
│   └── 👥 거주자들 (프로세스들)
│
├── 🏢 아파트 건물 (Docker Host)
│   ├── 🏠 101호 (Container 1 - nginx)
│   ├── 🏠 102호 (Container 2 - mysql)  
│   ├── 🏠 103호 (Container 3 - redis)
│   ├── 📞 공용 전화 (docker0 브리지)
│   └── 🚪 건물 입구 (호스트 포트)
│
└── 📡 인터넷 (외부 세계)
```

### 💡 주소 체계 이해하기

#### 📋 현실 vs 네트워크 주소

```yaml
현실 세계:
  국가: 대한민국
  시/도: 서울특별시  
  구: 강남구
  동: 역삼동
  번지: 123-45
  건물: ABC빌딩
  호수: 501호

네트워크 세계:
  물리 네트워크: 192.168.1.0/24
  Host 주소: 192.168.1.100
  VM 주소: 192.168.1.101 (브리지 모드)
  또는: 10.0.2.15 (NAT 모드)
  
  Docker 네트워크: 172.17.0.0/16
  Container 1: 172.17.0.2
  Container 2: 172.17.0.3
```

---

## 2. VM 네트워크 - 독립된 집

### 🏠 VM은 완전히 독립된 집

#### 📊 VM의 네트워크 모드들

**1. 브리지 모드 = 같은 동네에 별도 집 짓기**
```yaml
특징:
  - VM이 물리 네트워크에 직접 연결
  - 독립된 IP 주소 할당 (192.168.1.101)
  - 외부에서 직접 접근 가능
  
현실 비유:
  - 원래 집 옆에 새 집을 지음
  - 별도의 주소와 전화번호 
  - 우체국배달부가 직접 방문 가능
  
네트워크 흐름:
  외부 → 라우터 → VM (직접 연결)
  
실제 사용:
  # VirtualBox 브리지 설정
  VM 설정 → 네트워크 → 브리지 어댑터
  결과: VM IP = 192.168.1.101 (Host와 같은 대역)
```

**2. NAT 모드 = 집안에 쪽방 만들기**
```yaml
특징:
  - VM이 Host 뒤에 숨어서 인터넷 접근
  - 내부 IP만 가짐 (10.0.2.15)
  - 외부에서 직접 접근 불가능
  
현실 비유:
  - 집주인(Host)의 주소로 우편물 받기
  - 외부 사람들은 집주인을 통해서만 연락 가능
  - 쪽방 거주자는 외부로 나갈 수 있지만, 외부에서 찾아올 수 없음
  
네트워크 흐름:
  외부 → Host → NAT 변환 → VM
  
포트 포워딩:
  Host:8080 → VM:80 (특별한 우편함 설치)
```

**3. 호스트 전용 = 집안에서만 소통**
```yaml
특징:
  - VM과 Host만 통신 가능
  - 인터넷 연결 없음
  - 완전 격리된 환경
  
현실 비유:
  - 집안에만 있는 내선 전화
  - 외부 전화선 연결 안됨
  - 가족들끼리만 통화 가능
```

### 🔧 VM 네트워크 실제 설정

#### 💻 VirtualBox 네트워크 설정 비교

```yaml
브리지 모드 설정:
  VM 설정 → 네트워크 → 어댁터 1
  - 네트워크 어댑터 사용함: 체크
  - 다음에 연결됨: 브리지 어댑터
  - 이름: Wi-Fi (호스트의 네트워크 카드)
  
결과:
  Host: 192.168.1.100
  VM: 192.168.1.101 (자동 할당)
  외부에서 VM 직접 접근: 가능

NAT 모드 설정:
  VM 설정 → 네트워크 → 어댑터 1  
  - 다음에 연결됨: NAT
  - 포트 포워딩 규칙 추가 (필요시)
  
결과:
  Host: 192.168.1.100
  VM: 10.0.2.15 (VirtualBox 내부 대역)
  외부에서 VM 접근: 포트포워딩 필요
```

---

## 3. Docker 네트워크 - 아파트 내부

### 🏢 Docker는 아파트 건물 시스템

#### 📊 Docker 네트워크 모드들

**1. Bridge 네트워크 (기본) = 아파트 내부 네트워크**
```yaml
특징:
  - 각 컨테이너는 독립된 IP (방번호)
  - docker0 브리지가 공용 복도 역할
  - 외부 접근은 포트 포워딩 필요
  
현실 비유:
  - 아파트 내부의 각 호실 (101호, 102호...)
  - 공용 복도를 통해 서로 소통
  - 외부 방문자는 아파트 입구에서 호수 확인 필요
  
네트워크 구조:
  docker0 (172.17.0.1) ← 아파트 관리사무소
  ├── nginx (172.17.0.2) ← 101호
  ├── mysql (172.17.0.3) ← 102호
  └── redis (172.17.0.4) ← 103호
```

**2. Host 네트워크 = 집주인과 같은 방 사용**
```yaml
특징:
  - 컨테이너가 호스트 네트워크 직접 사용
  - 별도 IP 없음, 호스트와 동일
  - 포트 충돌 주의 필요
  
현실 비유:
  - 셰어하우스에서 방주인과 같은 방 사용
  - 전화번호, 주소 모두 동일
  - 개인 공간 없음, 모든 것 공유
  
사용법:
  docker run --network=host nginx
  # 컨테이너의 포트 80이 호스트 포트 80과 동일
```

**3. None 네트워크 = 완전 격리된 방**
```yaml
특징:
  - 네트워크 연결 없음
  - 외부 통신 불가능
  - 보안이 중요한 작업용
  
현실 비유:
  - 지하 벙커의 격리실
  - 전화선, 인터넷 연결 차단
  - 완전히 독립된 공간
```

### 💻 Docker 네트워크 실제 동작

#### 📋 컨테이너 간 통신 실습

```bash
# 1. 기본 브리지 네트워크에서 컨테이너 실행
docker run -d --name web nginx
docker run -d --name db mysql:5.7

# 2. 각 컨테이너의 IP 확인
docker inspect web | grep IPAddress
# "IPAddress": "172.17.0.2"

docker inspect db | grep IPAddress  
# "IPAddress": "172.17.0.3"

# 3. 컨테이너끼리 통신 테스트
docker exec web ping 172.17.0.3
# 성공! (같은 아파트 내부 통신)

# 4. 호스트에서 컨테이너로 접근
curl http://172.17.0.2:80
# 성공! (아파트 관리사무소에서 각 호실로)
```

#### 🔧 사용자 정의 네트워크 생성

```bash
# 1. 사용자 정의 네트워크 생성 (더 좋은 아파트 건설)
docker network create myapp-network
# 새로운 아파트 단지 건설

# 2. 컨테이너를 특정 네트워크에 연결
docker run -d --network=myapp-network --name web nginx
docker run -d --network=myapp-network --name db mysql:5.7

# 3. 이제 컨테이너 이름으로 통신 가능!
docker exec web ping db
# 성공! (아파트 내부 이름표 시스템)

# 4. 네트워크 정보 확인
docker network inspect myapp-network
```

---

## 4. 실제 통신 시나리오와 문제 해결

### 🎯 복잡한 시나리오: VM + Docker 조합

#### 📊 전체 구조 (현실적인 개발 환경)

```
🖥️ 맥북 (macOS Host) - 192.168.1.100
│
├── 🏠 Rocky Linux VM (VirtualBox) - 192.168.1.101
│   └── 🏢 Docker 환경
│       ├── 📦 Prometheus (172.17.0.2:9090)
│       ├── 📦 Grafana (172.17.0.3:3000)  
│       └── 📦 Node-exporter (172.17.0.4:9100)
│
└── 🌐 브라우저 (macOS에서 실행)
    └── 목표: Grafana에 접근하고 싶음!
```

#### 🔧 단계별 접근 방법

**방법 1: 이중 포트 포워딩 (추천)**
```bash
# 1단계: VM 내부 Docker 포트 포워딩
# Rocky Linux에서 실행
docker run -d -p 3000:3000 grafana/grafana

# 2단계: VirtualBox 포트 포워딩 설정
# VM 설정 → 네트워크 → 고급 → 포트 포워딩
# 호스트 포트: 3000 → 게스트 포트: 3000

# 결과: 맥북 브라우저에서 접근
# http://localhost:3000 → VirtualBox → Rocky Linux → Docker → Grafana
```

**방법 2: 브리지 모드 + 직접 접근**
```bash
# 1단계: VM을 브리지 모드로 설정
# VirtualBox → VM 설정 → 네트워크 → 브리지 어댑터

# 2단계: VM에서 Docker 포트 바인딩
docker run -d -p 3000:3000 grafana/grafana

# 3단계: 맥북에서 VM IP로 직접 접근
# http://192.168.1.101:3000
```

### 🚨 일반적인 문제 상황들

#### 📋 "연결할 수 없음" 문제 해결

**문제 1: 맥북에서 Docker 컨테이너에 접근 안됨**
```yaml
증상: "This site can't be reached"
원인 분석:
  1. VM의 방화벽이 막고 있음
  2. Docker 포트 바인딩 안됨  
  3. VirtualBox 네트워크 설정 문제
  
해결책:
  # 1. 방화벽 확인 및 해제 (Rocky Linux에서)
  sudo firewall-cmd --list-all
  sudo firewall-cmd --add-port=3000/tcp --permanent
  sudo firewall-cmd --reload
  
  # 2. Docker 포트 바인딩 확인
  docker ps | grep 3000
  # 0.0.0.0:3000->3000/tcp 가 보여야 함
  
  # 3. 네트워크 연결 테스트
  # VM 내부에서
  curl localhost:3000
  # 호스트에서  
  curl 192.168.1.101:3000
```

**문제 2: 컨테이너끼리 통신 안됨**
```yaml
증상: "Connection refused between containers"
원인:
  - 잘못된 IP 사용
  - 네트워크 격리 
  - 포트 번호 오류
  
해결책:
  # 1. 컨테이너 IP 확인
  docker inspect <container> | grep IPAddress
  
  # 2. 네트워크 연결 확인  
  docker exec container1 ping container2
  
  # 3. 사용자 정의 네트워크 사용 (권장)
  docker network create app-net
  docker run --network=app-net --name db mysql
  docker run --network=app-net --name app myapp
  # 이제 앱에서 'db'라는 이름으로 접근 가능
```

### 💡 네트워크 디버깅 도구들

#### 🔧 단계별 연결 테스트

```bash
# 1. 호스트 → VM 연결 테스트
ping 192.168.1.101

# 2. VM → Docker 브리지 테스트  
docker exec container_name ip addr show

# 3. 컨테이너 내부 → 외부 연결 테스트
docker exec container_name ping 8.8.8.8

# 4. 포트 열림 여부 확인
nmap -p 3000 192.168.1.101

# 5. 프로세스가 실제로 포트 사용 중인지 확인
netstat -tulpn | grep 3000
```

### 🎯 Best Practice 권장사항

#### ✅ 개발 환경 설정 가이드

```yaml
간단한 구성 (학습용):
  - VirtualBox NAT 모드
  - 포트 포워딩 사용
  - 보안 설정 최소화
  
실무에 가까운 구성:
  - VirtualBox 브리지 모드  
  - Docker Compose 사용
  - 방화벽 및 보안 설정 적용

권장 포트 할당:
  - Grafana: 3000
  - Prometheus: 9090
  - Node-exporter: 9100
  - 사용자 앱: 8080, 8081, 8082...
  
네트워크 명명 규칙:
  - 환경별: dev-network, prod-network
  - 서비스별: web-network, db-network
  - 프로젝트별: myapp-network
```

#### 📊 문제 해결 체크리스트

```yaml
연결이 안될 때 확인 순서:

1단계 - 기본 연결:
  [ ] VM이 정상 부팅되었는가?
  [ ] 호스트에서 VM으로 ping이 되는가?
  [ ] VM에서 외부 인터넷이 되는가?

2단계 - Docker 확인:
  [ ] 컨테이너가 정상 실행 중인가?
  [ ] 포트 바인딩이 올바른가?
  [ ] 방화벽이 포트를 막고 있지 않는가?

3단계 - 네트워크 경로:
  [ ] VirtualBox 포트 포워딩 설정이 맞는가?
  [ ] Docker 브리지 네트워크가 정상인가?
  [ ] 각 단계별로 telnet 테스트 해봤는가?

4단계 - 로그 확인:
  [ ] Docker 로그에 오류가 있는가?
  [ ] VM 시스템 로그는 정상인가?
  [ ] 네트워크 패킷이 실제로 전달되고 있는가?
```

**이제 VM과 Docker의 복잡한 네트워크도 "집과 아파트" 개념으로 쉽게 이해하실 수 있을 것입니다!** 🎯

어떤 부분이 더 궁금하신지 말씀해주세요. 실제 실습하면서 막히는 부분을 구체적으로 도와드릴게요! 😊