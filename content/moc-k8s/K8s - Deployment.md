---
title: 쿠버네티스(Kubernetes) Deployment 리소스
summary: 쿠버네티스(Kubernetes) Deployment는 Pod와 ReplicaSet에 대한 선언적 업데이트를 제공하는 워크로드 리소스입니다.
  애플리케이션의 배포, 롤링 업데이트, 롤백을 관리하며 ReplicaSet을 통해 Pod의 수를 유지하는 역할을 합니다.
tags:
- Kubernetes
- Deployment
- ReplicaSet
- Workload
- Resource
category: 교육
difficulty: 초급
estimated_time: 10분
created: '2025-11-03'
updated: '2025-11-08'
tech_stack:
- Kubernetes
---

#kubernetes #resource #workload

`[[K8s - Pod]]`와 `[[K8s - ReplicaSet]]`에 대한 선언적 업데이트를 제공하는 리소스입니다.

*   **역할**: 애플리케이션 배포 및 롤링 업데이트, 롤백 관리
*   **비유**:  설계도 (몇 개를 실행할지, 어떤 버전을 쓸지 정의)
*   **관계**: `Deployment`가 `[[K8s - ReplicaSet]]`을 관리하고, `ReplicaSet`이 `[[K8s - Pod]]`의 개수를 관리합니다.

---

**작성일**: 2025-11-03
