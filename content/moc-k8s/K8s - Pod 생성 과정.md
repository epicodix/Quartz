---
title: K8s - Pod 생성 과정
summary: 사용자가 `kubectl run nginx` 명령을 실행했을 때의 7단계 흐름입니다.
tags:
- 미분류
category: 기타
difficulty: 중급
estimated_time: 30분
created: '2025-11-03'
updated: '2025-11-08'
---

#kubernetes #process

사용자가 `kubectl run nginx` 명령을 실행했을 때의 7단계 흐름입니다.

1.  **요청**: 사용자 → `[[K8s - API 서버]]`
      * `kubectl`이 "nginx 파드 실행해줘!" (`Deployment` 생성 요청)
2.  **저장**: `[[K8s - API 서버]]` → `[[K8s - etcd]]`
      * "원하는 상태: nginx `[[K8s - Deployment]]` 1개"를 `[[K8s - etcd]]`에 저장
3.  **감시**: `[[K8s - Controller Manager]]` → `[[K8s - API 서버]]`
      * `Deployment Controller`가 `API 서버`를 감시하다 새 `Deployment` 발견
4.  **정의**: `[[K8s - Controller Manager]]` → `[[K8s - API 서버]]`
      * `ReplicaSet Controller`가 `[[K8s - Pod]]` 명세서를 생성해 `API 서버`에 "이 명세대로 Pod 생성해줘" 요청
5.  **결정**: `[[K8s - Scheduler]]` → `[[K8s - API 서버]]`
      * `Scheduler`가 노드가 할당되지 않은(nodeName: null) 파드를 발견
      * "이 파드는 '워커 노드 2번'이 적합해"라고 판단, 파드 정보에 `nodeName`을 업데이트
6.  **생성**: `[[K8s - Kubelet]]` (Node 2) → `[[Container Runtime]]`
      * '워커 노드 2번'의 `Kubelet`이 자신에게 할당된 파드를 발견
      * `Container Runtime`을 통해 컨테이너 실행!
7.  **연결**: `[[K8s - Kube-proxy]]`
      * 새 파드가 생성된 것을 감지하고, 해당 파드에 접근할 수 있도록 노드의 네트워크 규칙(iptables 등)을 설정

---

**작성일**: 2025-11-03
