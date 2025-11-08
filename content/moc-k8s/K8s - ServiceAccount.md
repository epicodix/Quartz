---
title: K8s - ServiceAccount
summary: ServiceAccount는 **사람(User)이 아닌, `[[K8s - Pod]]`가 사용하는 ID**입니다.
tags:
- 미분류
category: 기타
difficulty: 중급
estimated_time: 30분
created: '2025-11-03'
updated: '2025-11-08'
---

#kubernetes #security #rbac

ServiceAccount는 **사람(User)이 아닌, `[[K8s - Pod]]`가 사용하는 ID**입니다.

파드 안에서 실행되는 애플리케이션이 `[[K8s - API 서버]]`와 통신하여 다른 리소스(예: 다른 파드 목록 조회)에 접근해야 할 때, 이 ServiceAccount의 신원을 사용하여 인증을 받습니다.

### 주요 특징

*   네임스페이스에 종속됩니다. `[[K8s - Namespace]]`를 생성하면 `default`라는 이름의 ServiceAccount가 자동으로 생성됩니다.
*   `[[K8s - RoleBinding & ClusterRoleBinding]]`을 통해 `[[K8s - RBAC]]` 권한을 부여받을 수 있습니다.

예를 들어, CI/CD 파드가 배포를 위해 다른 `[[K8s - Deployment]]`를 업데이트해야 할 때, 해당 파드는 `deployment-updater`와 같은 권한을 가진 ServiceAccount를 사용해야 합니다.

* 관련 링크: `[[K8s - RBAC]]`

---

**작성일**: 2025-11-03
