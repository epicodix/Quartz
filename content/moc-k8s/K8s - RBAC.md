#kubernetes #security #moc

**RBAC (Role-Based Access Control)**: 역할 기반 접근 제어

*   **개념**: **누가(Subject)** + **무엇을(Resource)** + **어떻게(Verb)** 할 수 있는가를 정의합니다.

      * 예: `User 'Alice'`가 `dev 네임스페이스`의 `Pod`를 `get, list, watch` 할 수 있다.

*   **관련 리소스**

      * `[[K8s - Role]]`: 특정 `[[K8s - Namespace]]` 내에서만 유효한 권한 정의
      * `[[K8s - ClusterRole]]`: 클러스터 전체 범위의 권한 정의 (예: Node 관리)
      * `[[K8s - RoleBinding & ClusterRoleBinding]]`: 위에서 정의한 권한(Role/ClusterRole)을 실제 사용자(`[[K8s - ServiceAccount]]`, User)에게 **부여(Bind)**
      * `[[K8s - ServiceAccount]]`: `[[K8s - Pod]]`가 `[[K8s - API 서버]]`와 통신할 때 사용하는 ID
