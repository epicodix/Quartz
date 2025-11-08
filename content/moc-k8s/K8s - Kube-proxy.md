---
title: K8s - Kube-proxy
summary: Kube-proxy는 클러스터의 각 `[[워커 노드 (Worker Node)]]`에서 실행되는 네트워크 프록시입니다. 쿠버네티스의
  `[[K8s - Service]]` 개념을 가능하게 하는 핵심 컴포넌트입니다.
tags:
- 미분류
category: 기타
difficulty: 중급
estimated_time: 30분
created: '2025-11-03'
updated: '2025-11-08'
---

#kubernetes #component #worker-node

Kube-proxy는 클러스터의 각 `[[워커 노드 (Worker Node)]]`에서 실행되는 네트워크 프록시입니다. 쿠버네티스의 `[[K8s - Service]]` 개념을 가능하게 하는 핵심 컴포넌트입니다.

### 주요 역할

1.  **네트워크 규칙 관리**: `[[K8s - Service]]`와 그에 속한 `[[K8s - Pod]]`들의 IP 주소를 감시하다가, 특정 서비스로 들어온 요청을 실제 파드로 전달(포워딩)할 수 있도록 노드의 네트워크 규칙(예: iptables, IPVS)을 설정하고 관리합니다.
2.  **로드 밸런싱**: 서비스에 속한 파드가 여러 개일 경우, 요청을 분산시키는 간단한 로드 밸런싱 기능을 수행합니다.

간단히 말해, Kube-proxy는 **클러스터 내부의 트래픽을 올바른 목적지(파드)로 안내하는 '교통 경찰'** 역할을 합니다.

* 관련 링크: `[[워커 노드 (Worker Node)]]`, `[[K8s - Service]]`

---

**작성일**: 2025-11-03
