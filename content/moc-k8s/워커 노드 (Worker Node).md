#kubernetes #architecture #worker-node #moc

워커 노드(Worker Node)는 쿠버네티스 클러스터에서 **실제 애플리케이션 컨테이너가 배포되고 실행되는 '일꾼' 서버**입니다.

`[[컨트롤 플레인 (Control Plane)]]`으로부터 명령을 받아 `[[K8s - Pod]]`를 실행하고, 네트워크를 설정하며, 자신의 상태를 컨트롤 플레인에 보고하는 역할을 수행합니다.

### 워커 노드의 핵심 컴포넌트

*   `[[K8s - Kubelet]]`: 각 노드의 '현장 작업자'. 컨트롤 플레인의 지시를 받아 컨테이너를 실행하고 노드와 파드의 상태를 보고합니다.
*   `[[K8s - Kube-proxy]]`: 노드의 네트워크 규칙을 관리하여 파드 간, 또는 외부와의 통신을 가능하게 합니다.
*   **`[[Container Runtime]]`**: 컨테이너를 실제로 실행하는 소프트웨어 (예: containerd, CRI-O).

* 관련 링크: `[[Kubernetes 핵심 컴포넌트]]`, `[[Kubernetes (MOC)]]`
