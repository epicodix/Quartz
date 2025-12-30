---
title: 02_Core_네트워크_연결의_원리
creation_date: 2025-12-30
date: 2025-12-30
tags:
  - Kubernetes
  - Network
  - CoreDNS
  - KubeProxy
  - IPTables
  - Packet-Journey
  - CS
  - Netfilter
  - Service
aliases:
  - 쿠버네티스-네트워크
  - 연결의-원리
  - CoreDNS-KubeProxy
  - Service-Discovery
  - ClusterIP-진실
category: K8s_Deep_Dive
status: 완성
priority: 높음
model: gemini-3.0-pro preview
---

# 02. 쿠버네티스 네트워크: 고립된 섬들을 연결하는 법

[[01_Core_도커의_내부구조_고립의_원리|이전 글(01. 도커의 내부 구조)]]에서 우리는 평화를 위해 **Namespaces**라는 벽을 세워 프로세스들을 감옥에 가뒀습니다.

하지만 시스템은 혼자서 돌아가지 않습니다. 웹 서버는 DB와 대화해야 하고, 프론트엔드는 백엔드를 호출해야 합니다. 여기서 딜레마가 발생합니다.

> **"철저하게 격리시켰는데, 어떻게 자유롭게 통신하게 할 것인가?"**

이 모순을 해결하기 위해 쿠버네티스는 **CoreDNS(전화번호부)**와 **Kube-Proxy(터널 굴착기)**라는 정교한 시스템을 도입했습니다.

---

## 1. 고립의 대가: "너의 이름은 뭐니?"

도커의 격리 때문에 컨테이너 A는 컨테이너 B의 존재조차 모릅니다. 게다가 쿠버네티스 환경에서 파드(Pod)는 언제든 죽었다 살아나며 IP가 바뀝니다(Ephemeral).

그래서 K8s는 **Service**라는 **'변하지 않는 대문(Virtual IP)'**을 만듭니다.
> *"야, DB 찾을 때 IP 찾지 마. 그냥 `my-db`라고 불러. 내가 알아서 연결해줄게."*

이 약속을 지키기 위해 두 가지 컴포넌트가 움직입니다.

---

## 2. 전화번호부: CoreDNS (Discovery)

고립된 파드가 세상 밖 친구를 찾는 첫 번째 단계는 **이름 풀이**입니다.

1.  **동작:** 파드 안에서 `nslookup my-db`를 칩니다.
2.  **CoreDNS:** K8s API를 감시하다가, 최신 **ClusterIP(`10.96.0.100`)**를 알려줍니다.
    > *"아, `my-db`? 걔네 대표 번호는 `10.96.0.100`이야."*

하지만 이 **ClusterIP는 가짜(Virtual)**입니다. 핑(Ping)을 때려도 응답하지 않습니다. 네트워크 인터페이스에 할당된 실제 IP가 아니기 때문입니다. **그저 표지판일 뿐입니다.**

---

## 3. 터널 굴착기: Kube-Proxy와 Netfilter

가짜 IP인 ClusterIP로 보낸 패킷이 어떻게 진짜 파드(`10.244.2.10`)에 도착할까요?
여기서 **Kube-Proxy**가 등장합니다.

Kube-Proxy는 트래픽을 직접 중개하는 프록시 서버가 아닙니다. **리눅스 커널의 네트워크 규칙(IPTables/IPVS)을 조작하는 설정 관리자**입니다.

### 패킷의 탈옥 과정 (The Packet's Escape)

**Pod A**가 **Service B(`10.96.0.100`)**로 편지를 보내는 과정을 상상해 봅시다.

1.  **출발:** Pod A는 `10.96.0.100`을 목적지로 패킷을 던집니다.
2.  **탈출:** 패킷은 Pod A의 격리벽(NET Namespace)을 넘어 호스트의 네트워크 스택으로 나옵니다.
3.  **납치 (DNAT):** 호스트 커널의 **IPTables**가 이 패킷을 낚아챕니다.
    > *"잠깐, 목적지가 `10.96.0.100`이네? 이건 Kube-Proxy가 심어놓은 미끼야."*
4.  **변조:** 커널은 패킷의 목적지를 실제 **Pod B의 IP(`10.244.2.10`)**로 바꿔치기합니다. (NAT)
5.  **도착:** 이제 패킷은 실제 주소를 달고 유유히 Pod B의 격리벽 안으로 들어갑니다.

---

## 4. 결론: 추상화라는 이름의 환상

우리가 `kubectl apply -f service.yaml`을 할 때 일어나는 일은 마법이 아닙니다.

1.  **고립(Isolation):** 각 파드는 서로를 볼 수 없는 감옥에 갇혀 있다.
2.  **추상화(Abstraction):** 쿠버네티스는 'Service'라는 개념으로 이들이 마치 옆에 있는 것처럼 느끼게 해준다.
3.  **실체(Reality):** 그 뒤에서는 **CoreDNS**가 이름을 대고, **Kube-Proxy**가 커널 레벨에서 패킷을 납치하고 주소를 조작(NAT)하여 벽을 넘나들게 하고 있다.

결국 쿠버네티스 네트워킹은 **"고립된 환경에서 통신을 가능케 하기 위한, 리눅스 커널 기능(Netfilter)의 거대한 자동화 시스템"**입니다.

<br>
<div align="right" style="font-size: 0.8em; color: gray; opacity: 0.6;">
  Supported by gemini-3.0-pro preview
</div>
