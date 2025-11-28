---
title: MetalLB 쉽게 이해하기 - LoadBalancer 서비스를 온프레미스에서
tags:
  - kubernetes
  - metallb
  - loadbalancer
  - on-premise
  - networking
  - devops
aliases:
  - metallb-basic
  - 메탈엘비
  - 로드밸런서
date: 2025-11-28
category: K8s_Deep_Dive/네트워킹
status: 완성
priority: 높음
---

# 🔌 MetalLB 쉽게 이해하기

## 📑 목차
- [[#🤔 문제 상황|문제 상황]]
- [[#☁️ 클라우드 vs 🏠 온프레미스 차이|클라우드 vs 온프레미스 차이]]
- [[#🔧 MetalLB가 해결하는 방법|MetalLB가 해결하는 방법]]
- [[#🌐 Layer 2 vs BGP 모드 실생활 비유|Layer 2 vs BGP 모드 실생활 비유]]
- [[#💡 실전 예시로 이해하기|실전 예시로 이해하기]]

---

## 🤔 문제 상황: LoadBalancer 타입이 pending으로 계속 남는다!

### 💻 집에서 실습할 때 겪는 문제

```bash
# 쿠버네티스 클러스터에서 nginx 배포
kubectl create deployment nginx --image=nginx

# LoadBalancer 타입으로 서비스 노출
kubectl expose deployment nginx --type=LoadBalancer --port=80

# 서비스 상태 확인
kubectl get svc
```

**결과:**
```
NAME    TYPE           CLUSTER-IP     EXTERNAL-IP   PORT(S)        AGE
nginx   LoadBalancer   10.96.85.123   <pending>     80:31234/TCP   5m
```

> [!warning] 문제 발생!
> **EXTERNAL-IP가 `<pending>` 상태로 계속 남아있습니다!**

### 🚫 왜 이런 일이 생길까?

**LoadBalancer 타입 서비스**는 쿠버네티스에게 이렇게 말하는 겁니다:
> "외부에서 접근 가능한 IP 주소 하나 달라!"

하지만 **온프레미스/개인 환경**에서는:
- AWS처럼 자동으로 ELB를 만들어주는 서비스가 없음
- 누가 IP 주소를 할당해줄지 모름
- 결국 `<pending>` 상태로 계속 대기

---

## ☁️ 클라우드 vs 🏠 온프레미스 차이

### ☁️ AWS/GCP/Azure에서는...

```bash
kubectl expose deployment nginx --type=LoadBalancer --port=80

# 🎉 자동으로 클라우드 LoadBalancer 생성!
kubectl get svc
```

**결과:**
```
NAME    TYPE           EXTERNAL-IP                           PORT(S)
nginx   LoadBalancer   a1b2c3-1234567890.us-west-2.elb...   80:31234/TCP
```

> [!success] 성공!
> **AWS ELB(Elastic Load Balancer)가 자동 생성되어 진짜 인터넷 IP를 할당!**

### 🏠 집/회사 서버에서는...

```bash
kubectl expose deployment nginx --type=LoadBalancer --port=80

# ❌ 아무도 IP를 할당해주지 않음
kubectl get svc
```

**결과:**
```
NAME    TYPE           EXTERNAL-IP   PORT(S)        AGE
nginx   LoadBalancer   <pending>     80:31234/TCP   ∞
```

> [!danger] 문제!
> **누가 IP 주소를 할당해줄까요? → 아무도 없습니다!**

---

## 🔧 MetalLB가 해결하는 방법

### 🎯 MetalLB의 역할

> [!note] 핵심 개념
> MetalLB는 온프레미스 환경에서 **"IP 할당해주는 역할"**을 대신 수행합니다.

### 📋 MetalLB 설치 및 설정 과정

#### 1단계: MetalLB 설치
```bash
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.5/config/manifests/metallb-native.yaml
```

#### 2단계: IP 주소 풀 설정
```yaml
# ip-pool.yaml
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: example-pool
  namespace: metallb-system
spec:
  addresses:
  - 192.168.1.240-192.168.1.250  # 이 범위에서 IP 할당
```

#### 3단계: L2Advertisement 설정
```yaml
# l2-config.yaml  
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: example
  namespace: metallb-system
spec:
  ipAddressPools:
  - example-pool
```

#### 4단계: 설정 적용
```bash
kubectl apply -f ip-pool.yaml
kubectl apply -f l2-config.yaml
```

### 🎉 결과 확인

```bash
# 이제 LoadBalancer 서비스 생성
kubectl expose deployment nginx --type=LoadBalancer --port=80

# 서비스 상태 확인
kubectl get svc
```

**성공 결과:**
```
NAME    TYPE           CLUSTER-IP     EXTERNAL-IP     PORT(S)
nginx   LoadBalancer   10.96.85.123   192.168.1.240   80:31234/TCP
```

> [!success] 해결!
> **192.168.1.240으로 실제 접속 가능!**

```bash
# 브라우저나 curl로 접속 가능
curl http://192.168.1.240
# → nginx 웹페이지 출력!
```

---

## 🌐 Layer 2 vs BGP 모드 실생활 비유

### 🏠 Layer 2 모드: "동네 슈퍼마켓"

#### 🛒 동작 방식
- **상황**: 동네에 슈퍼 하나만 있음
- **고객**: "콜라 어디서 사지?"
- **답변**: "저기 슈퍼 가세요!"
- **결과**: 모든 고객이 같은 슈퍼로 몰림

#### 📡 기술적 동작
```bash
# 클라이언트가 192.168.1.240을 찾을 때
클라이언트: "192.168.1.240 어디 있어?" (ARP 요청)
MetalLB Node: "여기요! 저예요!" (ARP 응답)
→ 해당 노드로만 모든 트래픽 집중
```

#### ✅ 장점
- **설정 간단**: 공유기 하나면 충분
- **학습 쉬움**: ARP만 이해하면 됨
- **빠른 구축**: 바로 적용 가능

#### ❌ 단점
- **단일 장애점**: 해당 노드 죽으면 서비스 중단
- **부하 집중**: 하나 노드에만 트래픽 몰림

### 🏢 BGP 모드: "대형 체인점"

#### 🛒 동작 방식
- **상황**: 여러 지점에 같은 브랜드 매장
- **고객**: "콜라 어디서 사지?"
- **답변**: "가까운 매장 아무데나 가세요!"
- **결과**: 고객들이 여러 매장에 분산

#### 📡 기술적 동작
```bash
# BGP 라우터들과 협상
MetalLB: "라우터야, 192.168.1.240은 Node1, Node2, Node3이 처리할게"
라우터: "알겠어, 트래픽 여러 노드에 분산해서 보낼게"
→ 트래픽이 여러 노드로 분산 처리
```

#### ✅ 장점
- **고가용성**: 한 노드 죽어도 다른 노드가 처리
- **부하분산**: 여러 노드에 트래픽 분산
- **확장성**: 노드 추가 시 자동으로 부하분산

#### ❌ 단점
- **설정 복잡**: BGP 라우터 설정 필요
- **학습 곡선**: BGP 프로토콜 이해 필요
- **네트워크 요구사항**: BGP 지원 라우터 필수

---

## 📊 언제 어떤 모드를 선택할까?

| 환경 | 추천 모드 | 이유 | 설정 난이도 |
|------|-----------|------|-------------|
| **개인 실습** | Layer 2 | 공유기 하나, 빠른 구축 | ⭐ (쉬움) |
| **소규모 개발팀** | Layer 2 | 간단한 네트워크, 적은 트래픽 | ⭐ (쉬움) |
| **회사 개발서버** | Layer 2 | 빠른 프로토타이핑 | ⭐⭐ (보통) |
| **회사 스테이징** | BGP | 운영 환경과 유사한 구성 | ⭐⭐⭐ (어려움) |
| **회사 운영서버** | BGP | 고가용성, 부하분산 필수 | ⭐⭐⭐⭐ (매우 어려움) |

---

## 💡 실전 예시로 이해하기

### 🏠 집에서 실습 시나리오

#### 환경
- **네트워크**: 192.168.1.0/24 (일반적인 가정용 공유기)
- **클러스터**: minikube 또는 3대 노드 클러스터
- **목표**: nginx 웹서버를 외부에서 접근 가능하게 만들기

#### 설정 과정

1. **IP 범위 확인**
```bash
# 현재 네트워크에서 사용 안 하는 IP 범위 찾기
ping 192.168.1.240  # 응답 없으면 사용 가능
ping 192.168.1.241  # 응답 없으면 사용 가능
...
ping 192.168.1.250  # 응답 없으면 사용 가능
```

2. **MetalLB 설정**
```yaml
# home-ip-pool.yaml
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: home-pool
  namespace: metallb-system
spec:
  addresses:
  - 192.168.1.240-192.168.1.245  # 6개 IP만 사용
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: home-l2
  namespace: metallb-system
spec:
  ipAddressPools:
  - home-pool
```

3. **테스트 앱 배포**
```bash
# nginx 배포
kubectl create deployment home-nginx --image=nginx

# LoadBalancer 서비스 생성
kubectl expose deployment home-nginx --type=LoadBalancer --port=80

# IP 할당 확인
kubectl get svc
```

4. **결과**
```
NAME         TYPE           EXTERNAL-IP     PORT(S)
home-nginx   LoadBalancer   192.168.1.240   80:32123/TCP
```

5. **접속 테스트**
```bash
# 같은 네트워크 내 어디서든 접속 가능
curl http://192.168.1.240
# → "Welcome to nginx!" 페이지 출력

# 스마트폰이나 다른 PC에서도 접속 가능
# 브라우저에서 http://192.168.1.240 입력
```

### 🏢 회사 BGP 시나리오

#### 환경
- **네트워크**: 복잡한 기업 네트워크, BGP 라우터 존재
- **클러스터**: 10대 노드 클러스터
- **목표**: 고가용성 웹서비스 구축

#### 설정 과정

1. **네트워크팀과 협의**
```bash
# 할당 받을 IP 범위 협의
# 예: 10.100.50.0/28 (16개 IP 중 14개 사용 가능)
```

2. **BGP 라우터 설정** (네트워크팀 작업)
```bash
# 라우터에서 BGP 피어 설정
# MetalLB와 BGP 세션 설정
```

3. **MetalLB BGP 설정**
```yaml
# company-bgp-pool.yaml
apiVersion: metallb.io/v1beta2
kind: BGPPeer
metadata:
  name: company-router
  namespace: metallb-system
spec:
  myASN: 65001
  peerASN: 65000
  peerAddress: 10.100.1.1
---
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: company-pool
  namespace: metallb-system
spec:
  addresses:
  - 10.100.50.1-10.100.50.14
---
apiVersion: metallb.io/v1beta1
kind: BGPAdvertisement
metadata:
  name: company-bgp
  namespace: metallb-system
spec:
  ipAddressPools:
  - company-pool
```

4. **결과**: 트래픽이 여러 노드에 자동 분산

---

## 🎯 핵심 정리

### 🔑 MetalLB의 본질

> [!tip] 한 줄 요약
> **MetalLB = 온프레미스 환경에서 LoadBalancer 타입을 실제로 사용 가능하게 만드는 도구**

### 📋 비교 정리

| 구분 | MetalLB 없을 때 | MetalLB 설치 후 |
|------|----------------|----------------|
| **LoadBalancer 서비스** | `<pending>` 계속 | 실제 IP 할당 |
| **외부 접근** | NodePort로만 가능 | 깔끔한 IP로 접근 |
| **포트** | 랜덤 포트 (30000+) | 표준 포트 (80, 443) |
| **사용성** | 복잡함 | 클라우드처럼 간단 |

### 🚀 다음 단계

1. **Layer 2 모드**로 시작하여 기본 개념 익히기
2. **간단한 웹앱**으로 LoadBalancer 타입 테스트
3. **고가용성**이 필요하면 BGP 모드 고려
4. **모니터링** 및 **로그 분석**으로 문제 해결 능력 향상

> [!success] 이제 MetalLB를 이해했다면
> 온프레미스 환경에서도 클라우드처럼 편리하게 LoadBalancer 서비스를 사용할 수 있습니다!