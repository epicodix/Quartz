---
title: K8s - ReplicaSet
summary: 지정된 수의 `[[K8s - Pod]]` 복제본이 항상 실행되도록 보장합니다. (Self-healing)
tags:
- 미분류
category: 기타
difficulty: 중급
estimated_time: 30분
created: '2025-11-03'
updated: '2025-11-08'
---

#kubernetes #resource #workload

지정된 수의 `[[K8s - Pod]]` 복제본이 항상 실행되도록 보장합니다. (Self-healing)

*   **역할**: 파드 개수 유지
*   **비유**:  복사기 (항상 지정된 수만큼 유지)
*   **참고**: 사용자가 직접 `ReplicaSet`을 생성하기보다 `[[K8s - Deployment]]`를 통해 간접적으로 관리하는 것이 일반적입니다.

---

**작성일**: 2025-11-03
