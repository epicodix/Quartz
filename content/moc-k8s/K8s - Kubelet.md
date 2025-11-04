#kubernetes #component #worker-node

Kubelet은 각 `[[워커 노드 (Worker Node)]]`마다 하나씩 설치되어 실행되는 **'현장 작업자' ** 에이전트입니다.

**주요 역할**

1.  **감시 (Watch)**
      * `[[K8s - API 서버]]`를 지속적으로 **감시(Watch)**하며 "자신(의 노드)에게 할당된 `[[K8s - Pod]]`가 있는지" 확인합니다.
2.  **실행 (Execute)**
      * 자신에게 할당된 파드를 발견하면, 해당 명세서(`PodSpec`)를 읽어 `[[Container Runtime]]`(예: containerd)을 통해 컨테이너를 실제로 실행시킵니다.
3.  **보고 (Report)**
      * 파드 및 노드의 '현재 상태'(예: "Pod is Running", "Node is Healthy")를 주기적으로 `[[K8s - API 서버]]`에 **보고**합니다.

>  **핵심 통신 방식**
> `[[K8s - API 서버]]`가 `Kubelet`에게 직접 명령을 내리는 푸시(Push) 방식이 아니라, **`Kubelet`이 `API 서버`를 계속 확인하는 풀(Pull)/감시(Watch) 방식**입니다.

* 관련 링크: `[[Kubernetes 핵심 컴포넌트]]`, `[[K8s - Pod 생성 과정]]`
