---
title: 쿠버네티스 네임스페이스(Namespace) 개념과 필요성
summary: 쿠버네티스 네임스페이스는 단일 클러스터 내 리소스를 논리적으로 격리하는 가상 클러스터입니다. 여러 팀이나 프로젝트가 클러스터를 공유할
  때 사용하며, ResourceQuota와 RBAC을 통해 자원 및 권한 관리를 할 수 있습니다.
tags:
- kubernetes
- namespace
- isolation
- policy
category: 교육
difficulty: 초급
estimated_time: 5분
created: '2025-11-03'
updated: '2025-11-08'
tech_stack:
- Kubernetes
- ResourceQuota
- RBAC
---

#kubernetes #policy #isolation

단일 쿠버네티스 클러스터 내의 리소스를 논리적으로 분리하는 가상 클러스터입니다.

*   **필요성**: 하나의 클러스터를 여러 팀(개발, 운영)이나 여러 프로젝트가 공유할 때 리소스를 격리하기 위해 사용합니다.
*   `[[K8s - ResourceQuota]]`를 통해 네임스페이스별 자원 사용량을 제한할 수 있습니다.
*   `[[K8s - RBAC]]`의 `[[K8s - Role]]`은 네임스페이스 범위 내에서 권한을 정의합니다.

**예시**

```
클러스터
├── dev (개발팀 네임스페이스)
│   ├── Pod: frontend-dev
│   └── Pod: backend-dev
├── staging (스테이징 네임스페이스)
└── prod (운영팀 네임스페이스)
    ├── Pod: frontend-prod
    └── Pod: backend-prod
```

---

**작성일**: 2025-11-03
