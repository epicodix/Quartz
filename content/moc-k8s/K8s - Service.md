---
title: 쿠버네티스 서비스(K8s - Service)의 역할과 개념
summary: 쿠버네티스(Kubernetes) 서비스는 여러 Pod에 대한 고정된 네트워크 엔드포인트(IP, DNS)를 제공하는 리소스입니다. Pod의
  IP가 변경되더라도 서비스의 고유 주소를 통해 안정적으로 접근하고 트래픽을 분산(로드 밸런싱)하는 역할을 합니다.
tags:
- Kubernetes
- Service
- Networking
- Pod
- Resource
category: 기술분석
difficulty: 초급
estimated_time: 5분
created: '2025-11-03'
updated: '2025-11-08'
tech_stack:
- Kubernetes
---

#kubernetes #resource #networking

여러 `[[K8s - Pod]]`에 접근할 수 있는 고정된 네트워크 엔드포인트(고유 IP, DNS)를 제공합니다.

*   **역할**: `[[K8s - Pod]]`로의 접근 경로 제공 (로드 밸런싱)
*   **비유**:  고정된 출입구 (뒤에 있는 파드들의 IP가 변해도, Service의 IP는 고정됨)
*   관련 링크: `[[K8s - Ingress]]`

---

**작성일**: 2025-11-03
