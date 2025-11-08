---
title: Container Runtime
summary: 컨테이너 런타임(Container Runtime)은 컨테이너를 실제로 실행하고 관리하는 소프트웨어입니다. 쿠버네티스는 컨테이너를 직접
  실행하지 않고, 각 `[[워커 노드 (Worker Node)]]`에 설치된 컨테이너 런타임을 통해 이 작업을 수행합니다.
tags:
- 미분류
category: 기타
difficulty: 중급
estimated_time: 30분
created: '2025-11-03'
updated: '2025-11-08'
---

#kubernetes #component #worker-node

컨테이너 런타임(Container Runtime)은 컨테이너를 실제로 실행하고 관리하는 소프트웨어입니다. 쿠버네티스는 컨테이너를 직접 실행하지 않고, 각 `[[워커 노드 (Worker Node)]]`에 설치된 컨테이너 런타임을 통해 이 작업을 수행합니다.

`[[K8s - Kubelet]]`이 컨테이너 런타임에게 "이 이미지로 컨테이너를 실행해줘"라고 명령을 내리는 방식입니다.

### 주요 컨테이너 런타임

*   **containerd**: 현재 쿠버네티스에서 가장 널리 사용되는 표준 컨테이너 런타임입니다. (도커에서 분리됨)
*   **CRI-O**: 쿠버네티스를 위해 경량화된 대안으로 만들어진 런타임입니다.

과거에는 도커(Docker)가 주로 사용되었지만, 현재는 쿠버네티스가 CRI(Container Runtime Interface)라는 표준 인터페이스를 통해 다양한 런타임과 호환되도록 설계되어 있습니다.

* 관련 링크: `[[워커 노드 (Worker Node)]]`, `[[K8s - Kubelet]]`

---

**작성일**: 2025-11-03
