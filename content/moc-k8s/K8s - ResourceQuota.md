---
title: Kubernetes ResourceQuota를 이용한 네임스페이스 리소스 제한
summary: Kubernetes의 ResourceQuota는 Namespace별로 사용할 수 있는 CPU, 메모리 등 리소스의 총량을 제한하는
  기능입니다. 이를 통해 특정 팀이나 애플리케이션이 클러스터의 모든 자원을 독점하는 것을 방지하여 안정적인 운영을 돕습니다.
tags:
- kubernetes
- policy
- ResourceQuota
- Namespace
category: 기술분석
difficulty: 초급
estimated_time: 5분
created: '2025-11-03'
updated: '2025-11-08'
tech_stack:
- Kubernetes
---

#kubernetes #policy

`[[K8s - Namespace]]`별로 사용할 수 있는 리소스(CPU, 메모리)의 총량을 제한(Quota)하는 기능입니다.

*   **필요성**: 특정 팀이나 애플리케이션이 클러스터의 모든 자원을 독점하는 것을 방지합니다.

---

**작성일**: 2025-11-03
