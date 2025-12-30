---
title: 01_Core_도커의_내부구조_고립의_원리
creation_date: 2025-12-30
date: 2025-12-30
tags:
  - Docker
  - Kubernetes
  - Linux
  - Kernel
  - Namespaces
  - Cgroups
  - CS
  - Container
  - Virtualization
aliases:
  - 도커-내부구조
  - 고립의-원리
  - Namespaces-Cgroups
  - PID-Namespace
  - UnionFS
category: K8s_Deep_Dive
status: 완성
priority: 높음
model: gemini-3.0-pro preview
---

# 01. 도커의 내부 구조: 왜 '고립(Isolation)'을 선택했는가?

> **"컨테이너는 마법 상자가 아니다. 리눅스 커널이 만든 정교한 감옥이다."**

개발자들은 흔히 도커를 "가볍고 편리한 배포 도구"로만 생각합니다. 하지만 엔지니어링 관점에서 도커(컨테이너)의 본질은 **"철저한 고립(Isolation)"**입니다.

이 글에서는 도커가 **PID, Namespace, Cgroups**라는 기술을 이용해 프로세스를 어떻게 감옥에 가두는지 살펴봅니다. 그리고 우리가 **왜 이토록 고립에 집착했는지**, 그로 인해 **어떤 대가를 치르게 되었는지** 알아봅니다.

---

## 1. 컨테이너의 실체: "착각 속에 사는 프로세스"

결론부터 말하자면, 컨테이너는 호스트 OS 입장에서 **그냥 실행 중인 프로세스(Process)**일 뿐입니다.
다만, **Namespaces**라는 커널 기능을 이용해 **"자신만의 세상에 갇혀, 자신이 왕(PID 1)인 줄 아는"** 프로세스입니다.

---

## 2. 고립의 마법사: Namespaces (네임스페이스)

Namespaces는 시스템 리소스를 쪼개어 프로세스마다 별도의 공간처럼 보여줍니다. 즉, **옆방에서 무슨 일이 일어나는지 전혀 모르게 만드는 기술**입니다.

### 2.1. PID Namespace (프로세스 ID 격리)
*   **컨테이너 내부:** 내가 실행한 앱(Nginx)이 **PID 1**번(시스템 관리자)입니다.
*   **호스트 외부:** 실제로는 호스트 OS의 **PID 14523**번일 수 있습니다.

#### 👁️ 실전 확인: 시선의 차이
**[컨테이너 내부]** "나는 이 세상의 유일한 지배자(PID 1)다!"
```bash
root@container:/# ps -ef
UID        PID  CMD
root         1  nginx: master process
```

**[호스트 외부]** "너는 그냥 14523번 프로세스일 뿐이야."
```bash
$ ps aux | grep nginx
root      14523  nginx: master process
```

### 2.2. NET Namespace (네트워크 격리)
*   **고립:** 컨테이너는 자신만의 `eth0`와 `lo`(Localhost)를 가집니다.
*   **효과:** 컨테이너 A의 80번 포트와 컨테이너 B의 80번 포트는 절대 충돌하지 않습니다. 서로 다른 세상에 살기 때문입니다.

---

## 3. 자원의 통제: Cgroups (Control Groups)

Namespaces가 "보이지 않는 벽"을 세웠다면, **Cgroups**는 "식량 배급 제한"을 겁니다. 고립된 죄수가 폭동(CPU 독점)을 일으키지 못하게 하기 위함입니다.

*   **CPU:** 할당된 시간(Quota) 이상은 절대 못 씀.
*   **Memory:** 할당량 초과 시 가차 없이 사살(OOM Kill).

---

## 4. ☸️ 쿠버네티스 Pod의 정체: "독방을 공유하는 수감자들"

쿠버네티스의 **Pod**는 **Namespace를 공유하는 컨테이너들의 묶음**입니다.

1.  K8s는 **`pause`**라는 투명 인간 같은 컨테이너를 먼저 만들어 방(Namespace)을 팝니다.
2.  실제 앱 컨테이너들은 이 방에 **합류(Join)**합니다.
3.  그래서 Pod 내 컨테이너들은 **같은 IP(NET Namespace)**와 **같은 저장소(MNT/Volume)**를 공유할 수 있습니다. 이것이 사이드카 패턴의 원리입니다.

---

## 5. 결론: 고립의 역설 (The Paradox of Isolation)

우리는 **"애플리케이션 간의 충돌 방지"**라는 평화를 얻기 위해 **"고립"**을 선택했습니다.
Namespaces 덕분에 옆집 앱이 내 포트를 뺏어가거나 파일을 덮어쓸 걱정은 사라졌습니다.

**하지만 이 선택은 치명적인 대가를 가져왔습니다.**

> **"벽이 너무 높아서 대화(통신)조차 불가능해졌다."**

*   **문제 1:** IP가 격리되어 서로를 찾을 수 없다. (IP Discovery 문제)
*   **문제 2:** 컨테이너는 언제든 죽고, IP는 계속 바뀐다. (Ephemerality)
*   **문제 3:** 내가 보낸 패킷이 저 벽 너머로 갈 수 있는가? (Routing 문제)

이제 우리는 이 **고립된 섬들을 연결할 다리**가 필요합니다. 다음 글 **[[02_Core_네트워크_연결의_원리|02. 쿠버네티스 네트워크]]**에서 그 해결책인 **CoreDNS**와 **Kube-Proxy**를 만나봅니다.

<br>
<div align="right" style="font-size: 0.8em; color: gray; opacity: 0.6;">
  Supported by gemini-3.0-pro preview
</div>