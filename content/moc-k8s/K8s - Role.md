---
title: '쿠버네티스 Role: 네임스페이스 범위의 RBAC 권한 설정'
summary: 쿠버네티스 RBAC의 핵심 요소인 Role에 대해 설명합니다. Role은 특정 네임스페이스 내에서 Pod, Service 등 리소스에
  대한 권한(get, list, watch 등)을 정의하는 객체입니다. 예시를 통해 dev 네임스페이스에서 Pod를 조회하는 Role을 만드는 방법을
  보여줍니다.
tags:
- Kubernetes
- RBAC
- Role
- Security
category: 가이드
difficulty: 초급
estimated_time: 5분
created: '2025-11-03'
updated: '2025-11-08'
tech_stack:
- Kubernetes
- YAML
---

#kubernetes #security #rbac

`[[K8s - RBAC]]`에서 사용하는 권한의 집합으로, 특정 `[[K8s - Namespace]]` 내에서만 유효합니다.

### 예시

`dev` 네임스페이스 안에서 `Pod`를 조회(get, list)하고 감시(watch)할 수 있는 `pod-reader`라는 이름의 Role을 정의할 수 있습니다.

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: dev
  name: pod-reader
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list", "watch"]
```

이 권한은 `dev` 네임스페이스에만 적용되며, 다른 네임스페이스(예: `prod`)의 파드는 조회할 수 없습니다.

* 관련 링크: `[[K8s - ClusterRole]]`, `[[K8s - RoleBinding & ClusterRoleBinding]]`

---

**작성일**: 2025-11-03
