---
title: StatefulSet vs Deployment - PV/PVC 개념 완전 정리
tags:
  - kubernetes
  - statefulset
  - deployment
  - pv
  - pvc
  - storage
date: 2026-02-19
category: K8s_Deep_Dive
status: 완성
priority: 높음
---

# 🎯 StatefulSet vs Deployment, PV/PVC

> [!note] 핵심 질문
> "Kafka는 왜 Deployment가 아니라 StatefulSet으로 띄우나?"
> → **Pod가 죽어도 같은 이름 + 같은 저장소를 유지해야 해서**

---

## 📑 목차
- [[#1. Deployment vs StatefulSet|Deployment vs StatefulSet]]
- [[#2. PV와 PVC란|PV와 PVC란]]
- [[#3. StatefulSet + PVC 동작 원리|동작 원리]]
- [[#4. 이뮤터블과 PVC는 다른 개념|이뮤터블 vs PVC]]
- [[#5. 실전 적용|실전 적용]]

---

## 1. Deployment vs StatefulSet

### Deployment (일반적인 서비스용)

```
특징
├── Pod 이름이 랜덤으로 바뀜 (pod-a3f2x → pod-k9m1z)
├── 죽으면 새 이름으로 살아남
├── 저장소 없음 (컨테이너 꺼지면 데이터 날아감)
└── 언제든 죽어도 괜찮은 것들에 사용
```

```
사용 대상: 주문서비스, 재고서비스, 결제서비스...
→ 코드만 실행하면 됨. 데이터는 Redis/RDS/Kafka에 있음.
```

### StatefulSet (상태 있는 것들용)

```
특징
├── Pod 이름이 고정 (kafka-0 → kafka-0)
├── 죽어도 같은 이름으로 살아남
├── 각 Pod마다 고유한 저장소 붙음
└── 데이터를 직접 들고 있어야 하는 것들에 사용
```

```
사용 대상: Kafka, MySQL, Elasticsearch...
→ "나는 kafka-0이야"라는 정체성이 중요. 저장된 데이터가 있음.
```

### 한눈에 비교

| 항목 | Deployment | StatefulSet |
|------|-----------|------------|
| Pod 이름 | 랜덤 | 고정 (이름-0, 이름-1) |
| 재시작 후 | 새 이름 | 같은 이름 |
| 저장소 | 없음 | Pod마다 PVC 붙음 |
| 사용 예 | API 서버, 서비스 | Kafka, DB |

---

## 2. PV와 PVC란

```
PV  (Persistent Volume)  = 실제 저장공간
                           AWS에서는 EBS 디스크 한 장

PVC (Persistent Volume Claim) = "나 저장공간 필요해요" 요청서
                                 Pod가 PV에 연결 신청하는 것
```

### 관계도

```
물리 세계          쿠버네티스 세계
────────────────────────────────────────
AWS EBS 디스크 ──→ PV (쿠버가 인식한 것)
                    ↕
                   PVC (Pod의 신청서)
                    ↕
                  kafka-0 Pod (실제 사용)
```

> [!example] 비유
> - EBS 디스크 = 실제 하드디스크
> - PV = 그 디스크를 쿠버네티스에 등록한 것
> - PVC = "나 100GB 주세요" 요청서
> - Pod = 실제로 쓰는 사람

---

## 3. StatefulSet + PVC 동작 원리

### 정상 동작

```
kafka-0 Pod ──── PVC ──── EBS 디스크 (메시지 저장됨)
     │
     │  장애 발생! kafka-0 죽음
     ▼
kafka-0 재시작
     │
     │  같은 PVC에 다시 연결
     ▼
kafka-0 Pod ──── PVC ──── EBS 디스크 (메시지 그대로!)
```

### Deployment였다면 (데이터 유실)

```
kafka-??? 죽음
     ↓
kafka-새이름 생김
     ↓
PVC 연결 안 됨 (이름이 달라서 매핑 불가)
     ↓
메시지 전부 날아감 💥
```

---

## 4. 이뮤터블과 PVC는 다른 개념

> [!warning] 헷갈리기 쉬운 부분

```
이뮤터블 (Immutable)
= 컨테이너 이미지는 바꾸지 않는다는 원칙
= 코드 변경 → 새 이미지 빌드 → 기존 Pod 교체
= "코드/설정의 불변성"

PV / PVC
= 데이터 저장소 연결
= Pod가 죽어도 데이터는 살아있음
= "데이터의 영속성"
```

**함께 쓰이는 방식**

```
컨테이너 = 이뮤터블 (코드는 이미지에 고정)
PVC      = 데이터만 따로 분리해서 보관

→ 컨테이너를 교체해도 데이터는 PVC에 그대로
```

---

## 5. 실전 적용

### 타임딜 팀프로젝트 구성

```yaml
# Kafka StatefulSet 예시 (개념)
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: kafka
spec:
  replicas: 1
  volumeClaimTemplates:       # ← 각 Pod마다 PVC 자동 생성
  - metadata:
      name: kafka-data
    spec:
      storageClassName: gp2   # AWS EBS
      resources:
        requests:
          storage: 10Gi
```

### EKS에서 실제 흐름

```
1. StatefulSet 배포
   ↓
2. kafka-0 Pod 생성
   ↓
3. PVC 자동 생성 (kafka-data-kafka-0)
   ↓
4. AWS EBS 볼륨 자동 프로비저닝 (gp2)
   ↓
5. EBS ↔ PVC ↔ kafka-0 연결 완료
```

---

## 📊 최종 정리

```
Deployment  → 상태 없는 서비스 (언제든 죽어도 OK)
StatefulSet → 상태 있는 서비스 (이름 고정 + 저장소 필요)

PV          → 실제 디스크 (EBS)
PVC         → 그 디스크 사용 신청서

이뮤터블    → 코드/이미지는 고정 (별개 개념)
```

> [!tip] 팀프로젝트 선택 기준
> - 내 서비스 코드 → Deployment
> - Kafka → StatefulSet + PVC
> - Redis → ElastiCache (EKS 밖, 월 ~$12)
> - DB → RDS (EKS 밖, 데이터 안전하게)
