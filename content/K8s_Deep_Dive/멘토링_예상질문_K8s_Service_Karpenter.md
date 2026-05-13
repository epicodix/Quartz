---
title: 멘토링 예상질문 - K8s Service & Karpenter & 핵심 오브젝트
tags:
  - kubernetes
  - eks
  - karpenter
  - service
  - hpa
  - pdb
  - irsa
  - devops
aliases:
  - 멘토링K8s질문
  - Karpenter개념
date: 2026-05-12
category: K8s_Deep_Dive
status: 완성
priority: 높음
---

# 🎯 멘토링 예상질문 — K8s Service & Karpenter & 핵심 오브젝트

> pposiraegi 프로젝트 기준. "왜 이렇게 했는지"까지 설명할 수 있어야 함.

## 📑 목차

- [[#1. Service 타입 3가지|Service 타입]]
- [[#2. Ingress 없는 이유|Ingress 없는 이유]]
- [[#3. Karpenter vs Cluster Autoscaler|Karpenter vs CA]]
- [[#4. Karpenter 핵심 개념|Karpenter 핵심 개념]]
- [[#5. HPA|HPA]]
- [[#6. PDB|PDB]]
- [[#7. IRSA|IRSA]]
- [[#8. ExternalSecrets & ConfigMap|시크릿 관리]]
- [[#9. Probe (readiness vs liveness)|Probe]]
- [[#10. Resource requests vs limits|리소스 설정]]

---

## 1. Service 타입 3가지

> [!note] 핵심
> Service = Pod에 고정 진입점 제공. Pod IP는 재시작마다 바뀌므로 Service가 앞단에서 받아줌.

### ClusterIP (우리 프로젝트 전체 사용)

```yaml
spec:
  type: ClusterIP   # 기본값, 생략 가능
  selector:
    app: api-gateway
  ports:
  - port: 8080
    targetPort: 8080
```

- 클러스터 내부에서만 접근 가능한 가상 IP 할당
- kube-proxy가 이 IP를 실제 Pod IP로 변환(iptables/IPVS)
- 외부 노출 없음

### NodePort

```yaml
spec:
  type: NodePort
  ports:
  - port: 8080
    nodePort: 30080   # 30000~32767 고정
```

- 모든 노드의 특정 포트로 접근 가능
- `노드IP:30080` → Service → Pod
- 보안상 취약, 포트 관리 복잡 → 프로덕션에서 잘 안 씀

### LoadBalancer

```yaml
spec:
  type: LoadBalancer
```

- 클라우드 LB를 자동 생성
- EKS에서는 AWS LBC가 ALB/NLB 생성
- Terraform과 소유권 충돌 가능 → 우리가 안 쓰는 이유

### pposiraegi 정리

| 서비스 | 타입 | 외부 노출 방법 |
|--------|------|--------------|
| api-gateway | ClusterIP | TargetGroupBinding → Terraform ALB |
| user-service | ClusterIP | 내부 전용 (api-gateway가 호출) |
| product-service | ClusterIP | 내부 전용 |
| order-service | ClusterIP | 내부 전용 |

---

## 2. Ingress 없는 이유

> [!example] 멘토 질문 답변 (한 줄)
> "ALB 소유권을 Terraform에 완전히 주기 위해, Ingress 대신 TargetGroupBinding 패턴을 썼습니다."

### Ingress 방식의 문제

```
Ingress 선언 → AWS LBC가 ALB 자동 생성/소유
→ terraform destroy 해도 이 ALB는 안 지워짐
→ Terraform state와 실제 AWS 리소스 불일치 (state drift)
```

### 우리 방식

```
Terraform → ALB + Target Group + Listener 생성 (소유권 Terraform)
TargetGroupBinding → LBC가 Pod IP만 TG에 등록/해제
Service 타입 → ClusterIP (LB 타입 불필요)
```

```yaml
kind: TargetGroupBinding
spec:
  targetGroupName: pposiraegi-tg   # Terraform이 만든 TG
  targetType: ip                    # Pod IP 직접 등록 (NodePort 경유 없음)
  serviceRef:
    name: api-gateway
    port: 8080
```

---

## 3. Karpenter vs Cluster Autoscaler

> [!note] 핵심 차이
> CA는 노드 그룹(ASG) 단위로 스케일. Karpenter는 Pod 요구사항을 직접 보고 EC2를 프로비저닝.

| 항목 | Cluster Autoscaler | Karpenter |
|------|-------------------|-----------|
| 동작 방식 | ASG 단위 스케일 in/out | Pod spec 보고 EC2 직접 생성 |
| 노드 타입 | 노드 그룹에 고정 | 요구사항 맞는 인스턴스 자동 선택 |
| 속도 | 느림 (ASG 경유) | 빠름 (EC2 API 직접 호출) |
| Spot 지원 | 복잡한 설정 필요 | 기본 지원 (capacity-type) |
| 빈 노드 정리 | 제한적 | Consolidation으로 자동 최적화 |
| AWS 종속성 | 없음 | AWS 전용 (karpenter.k8s.aws) |

> [!tip] 면접 포인트
> "Karpenter는 Pending Pod의 resource requests와 node selector를 직접 분석해서
> 가장 적합한 EC2 인스턴스 타입을 골라 바로 생성합니다.
> CA처럼 미리 노드 그룹을 정의해둘 필요가 없어서 훨씬 유연합니다."

---

## 4. Karpenter 핵심 개념

### NodePool

```yaml
# 우리 프로젝트
apiVersion: karpenter.sh/v1
kind: NodePool
spec:
  template:
    spec:
      requirements:
        - key: karpenter.sh/capacity-type
          operator: In
          values: ["spot", "on-demand"]   # Spot 우선, On-Demand 폴백
        - key: node.kubernetes.io/instance-type
          operator: In
          values: [m5.large, m5a.large, m6i.large, m6a.large, c5.large, c6i.large]
          # t3 제외 — burstable CPU는 타임딜 부하 테스트에 부적합
  disruption:
    consolidationPolicy: WhenEmptyOrUnderutilized
    consolidateAfter: 30s
    budgets:
      - nodes: "10%"   # 동시에 최대 10% 노드만 교체/회수
  limits:
    cpu: "20"
    memory: 40Gi        # 클러스터 전체 상한선
```

**왜 t3를 뺐나:** t3는 CPU 크레딧 방식이라 지속 부하 시 성능이 떨어짐. 타임딜 특성상 순간 트래픽이 집중되므로 burstable 제외.

### EC2NodeClass

```yaml
apiVersion: karpenter.k8s.aws/v1
kind: EC2NodeClass
spec:
  amiSelectorTerms:
    - alias: al2023@latest    # Amazon Linux 2023 최신 AMI 자동 선택
  role: "pposiraegi-eks-node-role"
  subnetSelectorTerms:
    - tags:
        karpenter.sh/discovery: "pposiraegi-cluster"   # Private Subnet에 태그로 찾음
  blockDeviceMappings:
    - ebs:
        volumeSize: 20Gi
        volumeType: gp3
        encrypted: true
```

NodePool이 "어떤 종류의 노드를" 정의한다면, EC2NodeClass는 "어떤 설정으로" 만들지를 정의.

### Spot Interruption 처리

```
AWS → SQS (Spot Interruption 이벤트 발행)
  → Karpenter가 SQS 폴링
    → 2분 전 감지 → 해당 노드 cordon + drain
      → Pod를 다른 노드로 이동
        → EC2 회수
```

SQS가 있는 이유가 바로 이것. Karpenter가 Private Subnet에서 NAT GW → SQS API를 폴링.

### Consolidation

```
consolidationPolicy: WhenEmptyOrUnderutilized
consolidateAfter: 30s
```

- **WhenEmpty:** 노드에 Pod가 없으면 30초 후 자동 삭제
- **WhenUnderutilized:** 여러 노드에 분산된 Pod를 적은 수의 노드로 합칠 수 있으면 재배치 후 빈 노드 삭제
- 비용 최적화 핵심 기능

> [!warning] budgets: "10%" 의미
> Spot 노드 회수나 Consolidation 시 동시에 회수되는 노드 비율 상한.
> 전체 10개 중 최대 1개만 동시에 교체 → 서비스 안정성 유지.
> PDB(minAvailable: 1)와 함께 동작해서 Pod 중단 최소화.

---

## 5. HPA

> [!note] 핵심
> Pod 수를 CPU/메모리 기준으로 자동 조절. Karpenter와 역할이 다름.

```yaml
# api-gateway HPA
spec:
  scaleTargetRef:
    kind: Deployment
    name: api-gateway
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70   # 전체 Pod 평균 CPU 70% 초과 시 스케일 아웃
```

### HPA vs Karpenter 역할 분리

```
트래픽 증가
  → HPA: Pod 수 늘림 (기존 노드 안에서)
    → 노드 용량 부족
      → Karpenter: 새 EC2 노드 추가
        → HPA가 늘린 Pod 스케줄
```

HPA가 Pod를 늘리고, Karpenter가 그 Pod를 담을 노드를 추가. 둘이 수직으로 협력하는 구조.

> [!tip] 자주 나오는 질문
> "HPA랑 Karpenter 둘 다 스케일링인데 뭐가 달라요?"
> → HPA = 수평 Pod 스케일링 (애플리케이션 레이어)
> → Karpenter = 노드 스케일링 (인프라 레이어)

---

## 6. PDB

> [!note] 핵심
> 노드 유지보수/Spot 회수 시 강제로 Pod가 한 번에 다 죽는 것을 방지.

```yaml
# api-gateway PDB
spec:
  minAvailable: 1       # 최소 1개 Pod는 항상 Running 보장
  selector:
    matchLabels:
      app: api-gateway
```

### 동작 시나리오

```
Karpenter가 노드 회수 시도 (Consolidation or Spot Interruption)
  → drain 전 PDB 확인
    → api-gateway Pod 2개 중 1개 삭제 시도
      → minAvailable: 1 → OK (1개 남음)
      → 다른 노드에 새 Pod 뜨면 나머지 1개 삭제
        → 서비스 중단 없이 노드 교체 완료
```

> [!warning] PDB 없으면?
> 노드 drain 시 Pod 전체가 동시에 종료될 수 있음.
> 짧은 순간 서비스 다운 발생 가능.

---

## 7. IRSA

> [!note] 핵심
> IRSA(IAM Roles for Service Accounts) — Pod에 AWS 권한을 부여하는 방법.
> 노드 EC2 인스턴스 프로파일 대신 Pod 단위로 세밀하게 권한 부여.

### 동작 원리

```
ServiceAccount에 IAM Role ARN 어노테이션
  → Pod 시작 시 EKS가 OIDC 토큰 주입
    → Pod 안 SDK가 토큰으로 STS AssumeRoleWithWebIdentity 호출
      → 임시 AWS 자격증명 발급
        → S3/Secrets Manager 등 접근
```

### 우리 프로젝트 적용

```yaml
# serviceaccount.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: api-gateway
  namespace: production
  annotations:
    eks.amazonaws.com/role-arn: "arn:aws:iam::779846782353:role/pposiraegi-api-gateway-role"
```

```yaml
# deployment.yaml
spec:
  serviceAccountName: api-gateway   # 이 SA가 붙어야 Role 적용됨
```

> [!tip] 왜 노드 IAM Role 안 씀?
> 노드에 권한 주면 그 노드의 모든 Pod가 같은 권한을 가짐.
> IRSA는 Pod별로 다른 권한 → 최소권한 원칙 준수.
> api-gateway SA는 api-gateway에 필요한 권한만, ESO SA는 Secrets Manager만.

---

## 8. ExternalSecrets & ConfigMap

### ConfigMap — 비민감 설정값

```yaml
# 우리 app-config
data:
  SPRING_PROFILES_ACTIVE: "prod"
  USER_SERVICE_URL: "http://user-service:8080"    # K8s DNS로 서비스 디스커버리
  USER_GRPC_URL: "static://user-service:9090"
```

`http://user-service:8080` — K8s DNS가 `user-service.production.svc.cluster.local`로 해석.
Pod끼리 Service 이름만으로 통신 가능한 이유.

### ExternalSecrets — 민감 설정값

```
Kubernetes Secret을 직접 만들지 않고
AWS Secrets Manager / SSM에서 자동으로 가져와서 Secret 생성.
```

```yaml
# external-secret.yaml
spec:
  refreshInterval: 1h          # 1시간마다 SSM에서 최신값 동기화
  secretStoreRef:
    name: aws-ssm              # ClusterSecretStore (SSM 연결)
  target:
    name: app-secret           # 생성할 K8s Secret 이름
  data:
  - secretKey: DB_PASSWORD
    remoteRef:
      key: /pposiraegi/db_password   # SSM Parameter Store 경로
```

```
SSM Parameter Store (/pposiraegi/db_password)
  → ESO (IRSA로 SSM 접근)
    → K8s Secret (app-secret) 자동 생성/갱신
      → Pod의 env에 마운트
```

> [!tip] 왜 Secret을 직접 안 만드나?
> K8s Secret은 etcd에 base64로 저장 (암호화 아님).
> 직접 만들면 git에 커밋하기 어렵고, 갱신 자동화도 안 됨.
> SSM + ESO = 중앙 관리 + 자동 갱신 + IRSA 인증.

---

## 9. Probe — readiness vs liveness

```yaml
# api-gateway deployment
readinessProbe:
  httpGet:
    path: /actuator/health/readiness
    port: 8081
  initialDelaySeconds: 40    # 컨테이너 시작 후 40초 대기 (JVM warm-up)
  periodSeconds: 10
  failureThreshold: 5

livenessProbe:
  httpGet:
    path: /actuator/health/liveness
    port: 8081
  initialDelaySeconds: 90    # readiness보다 더 늦게 시작
  periodSeconds: 15
  failureThreshold: 3
```

| 항목 | readinessProbe | livenessProbe |
|------|---------------|--------------|
| 실패 시 동작 | Service에서 Pod 제거 (트래픽 차단) | Pod 재시작 |
| 목적 | 트래픽 받을 준비 됐는지 | 프로세스가 살아있는지 |
| 실패해도 | Pod는 Running 유지 | Pod 재시작 |

> [!example] 실제 시나리오
> 배포 직후 JVM 뜨는 데 30~40초 걸림.
> readinessProbe가 실패하는 동안 Service가 트래픽을 안 보냄 → 기존 Pod가 계속 서빙.
> readiness 통과하면 그때 트래픽 전환 → 무중단 배포 가능.

> [!warning] initialDelaySeconds 설정 이유
> Spring Boot + JVM 기동 시간 때문에 40초 설정.
> 너무 짧으면 아직 뜨는 중인데 실패 판정 → 재시작 루프.

---

## 10. Resource requests vs limits

```yaml
# api-gateway
resources:
  requests:
    cpu: "250m"       # 0.25 코어 보장 요청 (스케줄링 기준)
    memory: "512Mi"   # 512MB 보장 요청
  limits:
    cpu: "500m"       # 최대 0.5 코어 (초과 시 throttle)
    memory: "1Gi"     # 최대 1GB (초과 시 OOMKill)
```

### requests vs limits 차이

| 항목 | requests | limits |
|------|----------|--------|
| 역할 | 스케줄링 기준 | 실행 중 상한선 |
| CPU 초과 시 | - | throttle (느려짐, 죽지 않음) |
| memory 초과 시 | - | OOMKill (Pod 재시작) |
| Karpenter | 이 값으로 노드 선택 | - |

> [!tip] Karpenter와의 관계
> Karpenter는 Pending Pod의 `requests` 합산을 보고 노드 크기를 결정.
> requests가 너무 작으면 → 작은 노드 선택 → 실제로 limit까지 쓰면 throttle/OOMKill.
> requests가 너무 크면 → 큰 노드 낭비 → 비용 증가.
> requests ≈ 실제 평균 사용량, limits ≈ 피크 사용량으로 설정하는 게 이상적.

---

## 🎯 예상 질문 & 한 줄 답변

| 질문 | 핵심 답변 |
|------|----------|
| Service 타입 왜 ClusterIP? | ALB를 Terraform이 소유, TargetGroupBinding으로 Pod 연결 |
| Ingress 왜 안 써? | Terraform과 ALB 소유권 충돌 방지 |
| Karpenter가 CA랑 다른 점? | Pod 요구사항 보고 EC2 직접 생성, 인스턴스 타입 유연 선택 |
| Spot 갑자기 죽으면? | SQS Interruption 이벤트 → 2분 전 drain → PDB로 최소 Pod 보장 |
| Consolidation이란? | 빈/적은 노드 자동 정리로 비용 최적화 |
| HPA랑 Karpenter 관계? | HPA=Pod 스케일, Karpenter=노드 스케일. 수직으로 협력 |
| PDB 없으면 어떻게 됨? | 노드 drain 시 Pod 전체 동시 종료 → 서비스 다운 |
| IRSA 왜 써? | Pod별 최소권한 AWS 접근, 노드 전체에 권한 주는 것보다 안전 |
| readiness vs liveness? | readiness=트래픽 차단, liveness=Pod 재시작 |
| requests vs limits? | requests=스케줄링 기준, limits=실행 중 상한 |
| ExternalSecrets 왜 써? | K8s Secret 직접 관리 대신 SSM 중앙관리 + 자동갱신 |
| t3 인스턴스 왜 뺐나? | burstable CPU → 지속 부하에 성능 불안정 |
