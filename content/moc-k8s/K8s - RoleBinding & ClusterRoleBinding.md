---
title: 쿠버네티스 RoleBinding과 ClusterRoleBinding을 이용한 권한 부여
summary: RoleBinding과 ClusterRoleBinding은 쿠버네티스 RBAC의 핵심 요소로, Role이나 ClusterRole에
  정의된 권한을 사용자, 그룹, 서비스 어카운트에게 연결합니다. 이를 통해 특정 네임스페이스 또는 클러스터 전체에 대한 접근 권한을 세밀하게 제어할
  수 있습니다.
tags:
- Kubernetes
- RBAC
- Security
- RoleBinding
- ClusterRoleBinding
category: 가이드
difficulty: 중급
estimated_time: 10분
created: '2025-11-03'
updated: '2025-11-08'
tech_stack:
- Kubernetes
- YAML
---

#kubernetes #security #rbac

RoleBinding과 ClusterRoleBinding은 정의된 권한(**Role** 또는 **ClusterRole**)을 특정 대상(**Subject**: User, Group, `[[K8s - ServiceAccount]]`)에게 **연결(Bind)**해주는 역할을 합니다.

*   `[[K8s - Role]]` + `RoleBinding` = 특정 네임스페이스의 권한을 부여
*   `[[K8s - ClusterRole]]` + `RoleBinding` = 클러스터 전체 권한을 특정 네임스페이스 내에서만 사용하도록 제한하여 부여
*   `[[K8s - ClusterRole]]` + `ClusterRoleBinding` = 클러스터 전체 권한을 클러스터 전체에 부여

### RoleBinding 예시

`dev` 네임스페이스에서, 사용자 `jane`에게 `pod-reader` `[[K8s - Role]]`을 부여합니다.

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: read-pods
  namespace: dev
subjects:
- kind: User
  name: jane 
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role 
  name: pod-reader 
  apiGroup: rbac.authorization.k8s.io
```

이제 `jane`은 `dev` 네임스페이스의 파드만 조회할 수 있습니다.

* 관련 링크: `[[K8s - RBAC]]`

---

**작성일**: 2025-11-03
