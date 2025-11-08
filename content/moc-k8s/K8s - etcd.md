---
title: K8s - etcd
summary: etcd는 `[[컨트롤 플레인 (Control Plane)]]`이 사용하는 **분산 키-값 저장소(Key-Value Store)**입니다.
  쿠버네티스 클러스터의 모든 설정과 상태 정보를 저장하는 **'유일한 진실의 원천(Single Source of Truth)'** ...
tags:
- 미분류
category: 기타
difficulty: 중급
estimated_time: 30분
created: '2025-11-03'
updated: '2025-11-08'
---

#kubernetes #component #control-plane

etcd는 `[[컨트롤 플레인 (Control Plane)]]`이 사용하는 **분산 키-값 저장소(Key-Value Store)**입니다. 쿠버네티스 클러스터의 모든 설정과 상태 정보를 저장하는 **'유일한 진실의 원천(Single Source of Truth)'** 입니다.

### 주요 역할

1.  **상태 저장**: 클러스터의 `[[원하는 상태 (Desired State)]]`와 '현재 상태(Current State)'를 모두 저장합니다.
2.  **일관성 유지**: 분산 시스템 환경에서도 데이터의 일관성과 신뢰성을 보장합니다. `[[K8s - API 서버]]`만이 etcd와 직접 통신할 수 있습니다.

### 비유: 클러스터의 데이터베이스

마치 애플리케이션의 모든 데이터를 데이터베이스에 저장하는 것처럼, 쿠버네티스는 클러스터의 모든 것을 etcd에 저장합니다. etcd가 손상되면 클러스터 전체가 먹통이 될 수 있어 매우 중요합니다.

* 관련 링크: `[[컨트롤 플레인 (Control Plane)]]`, `[[K8s - API 서버]]`

---

**작성일**: 2025-11-03
