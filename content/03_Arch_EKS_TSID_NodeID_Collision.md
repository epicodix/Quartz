---
title: "EKS 환경에서 TSID Node ID 충돌 방지: Istio가 정답일까?"
creation_date: 2026-04-23
date: 2026-04-23
tags: [EKS, Kubernetes, MSA, TSID, Istio, Architecture, Troubleshooting]
aliases: [EKS-TSID-충돌-해결기, 분산환경-고유ID-생성, Istio-한계점]
category: Architecture/Distributed-Systems
status: 초안
priority: 높음
model: gemini-3.0-pro preview
summary: "분산 MSA 환경에서 고유 식별자(TSID) 생성 시 발생하는 Node ID 충돌 문제를 다룹니다. 네트워크 계층의 Istio(SPIFFE ID)가 해결책이 될 수 없는 이유를 분석하고, 애플리케이션 계층에서의 올바른 해결 방안(StatefulSet, Redis INCR, VPC CNI 제한)을 제시합니다."
---

# EKS 환경에서 TSID Node ID 충돌 방지: Istio가 정답일까?

## 1. 기술적 난제: 분산 환경에서의 완벽한 고유 식별자(ID) 생성

마이크로서비스 아키텍처(MSA)로 전환하면서 마주하게 되는 첫 번째 관문 중 하나는 **'어떻게 여러 파드(Pod)에서 동시에 채번하더라도 절대 중복되지 않는 고유한 ID를 만들 것인가?'** 입니다. 기존 모놀리식 환경에서는 DB의 `AUTO_INCREMENT`에 의존하면 그만이었지만, 초당 수천 건의 주문(트래픽)이 몰리는 타임딜 이커머스 환경에서는 DB 병목을 유발하는 치명적인 안티 패턴입니다.

이를 해결하기 위해 Twitter의 Snowflake나 **TSID(Time-Sorted Unique Identifier)** 와 같은 시간 기반 분산 ID 생성기를 도입하게 됩니다. TSID는 보통 64비트 정수로 구성되며, 이 중 **10비트(0~1023)** 를 파드를 식별하는 **Node ID(Worker ID)** 로 할당하여 동시성을 보장합니다.

### 문제의 시작: EKS의 광활한 IP 대역과 Node ID 충돌 (Collision)

보통 개발 환경에서는 파드의 IP 주소 마지막 자릿수나, IP를 숫자로 변환 후 1024로 나눈 나머지(`IP % 1024`)를 Node ID로 사용합니다. 
하지만 AWS EKS 기본 설정(VPC CNI) 환경에서는 파드가 VPC의 넓은 대역(예: `/16`, 65,536개 IP)에서 무작위로 IP를 할당받습니다. 만약 `10.0.1.5`와 `10.0.5.5` IP를 가진 두 파드가 동시에 띄워진다면, 둘 다 `% 1024` 연산 결과가 같아져 **TSID Node ID 충돌**이 발생합니다. 결국 동일한 밀리초에 두 파드가 같은 주문 번호를 발급하는 대형 사고로 이어질 수 있습니다.

---

## 2. 빗나간 가설: "Istio가 알아서 해주지 않을까?"

EKS 클러스터 내에 강력한 서비스 메시인 **Istio**가 구축되어 있다면, 이런 합리적인 의심을 해볼 수 있습니다.
> *"Istio가 파드마다 강력한 보안 신원(Identity)을 부여해 주는데, 그걸 TSID의 Node ID로 쓰면 해결되지 않을까?"*

결론부터 말하자면, **Istio는 이 문제의 정답이 될 수 없습니다.**

### 관심사의 불일치 (Separation of Concerns)

Istio가 파드에 부여하는 것은 네트워크 계층의 암호화와 상호 인증(mTLS)을 위한 **SPIFFE ID**(`spiffe://cluster.local/ns/default/sa/order-sa`)입니다.

1. **포맷의 한계:** TSID는 비즈니스 로직에서 사용하는 '0부터 1023 사이의 고유한 10비트 정수(Integer)'가 필요합니다. Istio의 SPIFFE ID는 긴 문자열(URI) 포맷입니다.
2. **해시 충돌 위험:** 이 문자열을 정수로 변환하기 위해 해싱(Hashing)을 하고 10비트로 줄이게 되면, 필연적으로 해시 충돌(Hash Collision)이 발생하여 동일한 TSID가 발급될 위험을 안게 됩니다.

결국, 네트워크 계층의 보안 식별자(Istio)와 애플리케이션 계층의 비즈니스 식별자 생성(TSID)은 **관심사를 명확히 분리**해야만 안전한 시스템을 설계할 수 있습니다.

---

## 3. 해결을 위한 선택: 애플리케이션 계층과 인프라 계층의 대안

그렇다면 EKS 환경에서 TSID Node ID를 안전하게 할당하는 방법은 무엇일까요? 크게 두 가지 접근법이 있습니다.

### 대안 A. 인프라 관점: AWS VPC CNI Custom Networking (IP 대역 격리)

EKS 파드에 할당되는 IP 자체를 TSID Node ID의 한계치인 1,024개로 묶어버리는 방법입니다.
- **방식:** AWS VPC에 파드 전용으로 `/22` 서브넷(IP 1,024개)을 생성하고, VPC CNI의 Custom Networking 기능을 통해 파드는 무조건 이 대역에서만 IP를 받도록 강제합니다.
- **장점:** 수학적으로 IP 충돌 확률이 0%가 되며, 기존 `IP % 1024` 로직을 그대로 사용할 수 있습니다.
- **단점:** 파드를 1,024개 이상 확장(Scale-out)할 수 없는 강력한 인프라 제약이 발생합니다.

### 대안 B. 애플리케이션 관점: StatefulSet 또는 Redis 기반 중앙 할당 (추천)

인프라의 확장성을 제한하지 않고 아키텍처로 풀어내는 방식입니다.

1. **StatefulSet의 Ordinal(순차 번호) 활용:**
   Deployment 대신 StatefulSet으로 파드를 배포하면 `order-service-0`, `order-service-1` 처럼 고유한 번호가 붙습니다. 애플리케이션 시작 시 컨테이너의 `HOSTNAME` 환경 변수에서 맨 뒤의 숫자를 파싱하여 0~1023 사이의 TSID Node ID로 고정하여 사용합니다.

2. **Redis `INCR` 연산을 통한 동적 할당:**
   파드가 시작되는(Init) 단계에서 공통 캐시(ElastiCache Redis)에 접속해 `INCR tsid:node:generator` 명령어를 날립니다. Redis의 원자적(Atomic) 연산을 통해 1~1023 사이의 겹치지 않는 고유 정수를 런타임에 확정적으로 발급받습니다. (종료 시 반납 로직 포함)

---

## 4. 결론 및 인사이트

클라우드 네이티브 환경에서 모든 문제를 하나의 은탄환(Silver Bullet, 예: Istio)으로 해결하려는 시도는 종종 맹점에 빠지기 쉽습니다. 

Istio는 네트워크 트래픽 제어와 보안의 목적에 충실하게 남겨두고, 비즈니스 로직에 결합되는 식별자 생성 문제는 애플리케이션 내부(StatefulSet, Redis)에서 명확하게 통제하는 것이 올바른 **관심사의 분리(Separation of Concerns)** 입니다. 인프라 자동화 도구의 목적을 정확히 이해하고 적재적소에 배치하는 것이 아키텍트의 진정한 역할임을 다시 한번 깨닫는 트러블슈팅 경험이었습니다.

<br>
<div align="right" style="font-size: 0.8em; color: gray; opacity: 0.6;">
  Supported by gemini-3.0-pro preview
</div>