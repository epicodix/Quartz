---
title: EKS 인프라 담당자 실무 가이드 - 필수 지식 + 학습 로드맵
tags:
  - eks
  - kubernetes
  - infrastructure
  - production
  - devops
  - karpenter
  - observability
  - security
  - terraform
aliases:
  - EKS 실무
  - 인프라 담당자 가이드
date: 2026-04-15
category: K8s_Deep_Dive/k8s실습
status: 완성
priority: 높음
---

# 🎯 EKS 인프라 담당자 실무 가이드

## 📑 목차
- [[#1. 인프라 담당자가 항상 알고 있어야 할 것들|인프라 담당자 필수 지식]]
- [[#2. 현재 구조 진단|현재 구조 진단]]
- [[#3. 실무 수준으로 올리기 위한 학습 로드맵|학습 로드맵]]
- [[#4. 각 영역별 깊이있는 내용|각 영역별 심화]]

---

## 1. 인프라 담당자가 항상 알고 있어야 할 것들

인프라 담당자는 "구성하는 사람"이 아니라 **"클러스터에서 일어나는 모든 일을 설명할 수 있는 사람"**이다.

### 1-1. 트러블슈팅 흐름 (머릿속에 즉시 떠올라야 함)

```
장애 발생
├── Pod 레벨?
│   ├── Pending    → 스케줄링 문제 (리소스, NodeSelector, Affinity, Taint)
│   ├── ImagePull  → ECR 권한, 이미지 태그 오류
│   ├── CrashLoop  → 애플리케이션 오류, 환경변수 누락, OOM
│   └── Running but 502 → readiness 미통과, preStop 누락
│
├── 네트워크 레벨?
│   ├── Pod → Pod 안됨  → NetworkPolicy, DNS, SG
│   ├── 외부 → Pod 안됨 → ALB → Ingress → Service → Pod 체인 확인
│   └── Pod → AWS 안됨  → IRSA, VPC 라우팅
│
└── 노드 레벨?
    ├── 노드 NotReady  → kubelet, 디스크, 메모리 압박
    ├── 노드 안 생김   → Karpenter 권한, EC2 쿼터, Spot 가용성
    └── 노드 갑자기 사라짐 → Spot 인터럽션 (SQS 이벤트 확인)
```

### 1-2. 항상 모니터링해야 할 지표

| 지표 | 임계값 기준 | 도구 |
|------|-----------|------|
| Pod CPU/Memory 사용률 | request의 80% 초과 → HPA 동작 확인 | Prometheus |
| 노드 수 변화 | 급격한 증가 → 비용 알람 | Karpenter 로그 |
| PVC 사용률 | 85% 이상 → 확장 필요 | CloudWatch |
| ALB 5xx 비율 | 1% 이상 → 즉시 조사 | CloudWatch ALB 메트릭 |
| etcd 크기 | EKS는 AWS 관리, 그러나 오브젝트 수 과다 주의 | kubectl |
| 인증서 만료일 | 30일 이내 → 갱신 준비 | cert-manager alert |

### 1-3. 비용 구조 이해 (매달 설명할 수 있어야 함)

```
EKS 비용 구조
├── Control Plane: $0.10/시간 (클러스터당 고정 ~$72/월)
├── 노드 (EC2)
│   ├── On-demand: 안정적, 비쌈
│   └── Spot: 최대 70% 절감, 중단 가능
├── ALB: $0.008/LCU + 시간당 $0.0225
├── NAT Gateway: $0.045/시간 + $0.045/GB  ← 데이터 전송 주의
└── EBS (PVC): gp3 기준 $0.08/GB/월
```

> [!warning] NAT Gateway 함정
> Pod가 외부 API를 자주 호출하면 NAT Gateway 데이터 전송 비용이 예상 외로 크다.
> ECR 이미지 pull도 NAT를 탄다 → VPC Endpoint(S3, ECR) 설정으로 절감 가능.

### 1-4. 클러스터 업그레이드 주기 이해

```
EKS 버전 지원 정책
- 신규 버전 출시 후 약 14개월 지원
- 지원 종료 전 자동 강제 업그레이드 → 미리 해야 함

업그레이드 순서 (반드시 이 순서)
1. Control Plane 업그레이드 (AWS 콘솔 or CLI)
2. 시스템 노드그룹 업그레이드 (AMI 교체)
3. Karpenter NodeClass AMI 업그레이드
4. 애드온 업그레이드 (vpc-cni, coredns, kube-proxy)
5. 앱 호환성 확인
```

> [!danger] 한 버전씩만
> 1.29 → 1.31 같은 두 버전 스킵은 지원 안 됨. 반드시 1.29 → 1.30 → 1.31 순서.

---

## 2. 현재 구조 진단

> [!example] 현재 구현된 것 (잘 된 것들)

| 영역 | 구현 여부 | 비고 |
|------|---------|------|
| EKS 클러스터 | ✅ | OIDC, 시스템 노드그룹 |
| Karpenter 노드 오토스케일링 | ✅ | On-demand + Spot NodePool |
| IRSA | ✅ | 서비스별 최소 권한 |
| External Secrets Operator | ✅ | SSM → K8s Secret |
| Argo CD App of Apps | ✅ | GitOps 자동화 |
| ALB Controller + Ingress | ✅ | HTTPS, SSL redirect |
| HPA | ✅ | CPU 기반 스케일링 |
| PDB | ✅ | Karpenter 통합 |
| Graceful Shutdown | ✅ | preStop + terminationGrace |
| Topology Spread | ✅ | 멀티 AZ 분산 |
| Probe 분리 | ✅ | startup/liveness/readiness |

> [!warning] 현재 없는 것들 (실무에서 필요한 것들)

| 영역 | 현재 상태 | 실무 임팩트 |
|------|---------|-----------|
| Observability 스택 | ❌ | 장애 원인 파악 불가 |
| NetworkPolicy | ❌ | Pod 간 트래픽 무제한 |
| cert-manager | ❌ | 인증서 수동 관리 |
| external-dns | ❌ | Route53 수동 관리 |
| Velero (백업) | ❌ | K8s 리소스 복구 불가 |
| ResourceQuota / LimitRange | ❌ | 네임스페이스 리소스 폭주 가능 |
| Terraform 원격 상태 | ❌ | 팀 협업 시 state 충돌 |
| VPC Endpoint | ❌ | ECR/S3 NAT 비용 누수 |
| Argo Rollouts | ❌ | 배포 시 카나리/블루그린 불가 |

---

## 3. 실무 수준으로 올리기 위한 학습 로드맵

### 3-1. 즉시 필요 (배포 전 반드시)

#### Observability: Prometheus + Grafana + Loki

```
현재 상태: CloudWatch만 있음 → 컨테이너 레벨 메트릭/로그 없음
문제: Pod OOM 터져도 원인 파악 못 함, 느린 API 어디서 왜 느린지 모름
```

```bash
# kube-prometheus-stack (Prometheus + Grafana + AlertManager 한번에)
helm install prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace \
  -f values/prometheus-values.yaml
```

핵심 대시보드:
- **USE 메트릭**: Utilization, Saturation, Errors (노드/Pod 단위)
- **RED 메트릭**: Rate, Errors, Duration (서비스 단위)
- Karpenter 대시보드 (공식 Grafana 대시보드 ID: 20311)

#### NetworkPolicy: Pod 간 트래픽 제한

```yaml
# 기본 정책: pposiraegi 네임스페이스 내부 통신만 허용
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
  namespace: pposiraegi
spec:
  podSelector: {}
  policyTypes: [Ingress]
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-internal
  namespace: pposiraegi
spec:
  podSelector: {}
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: pposiraegi
```

> [!note] NetworkPolicy는 VPC CNI 필요
> EKS의 AWS VPC CNI는 NetworkPolicy를 지원한다.
> EKS 1.25+ 에서는 VPC CNI에 NetworkPolicy 컨트롤러가 내장됨.

#### ResourceQuota + LimitRange

```yaml
# 네임스페이스 전체 상한 (폭주 방지)
apiVersion: v1
kind: ResourceQuota
metadata:
  name: pposiraegi-quota
  namespace: pposiraegi
spec:
  hard:
    requests.cpu: "8"
    requests.memory: 16Gi
    limits.cpu: "16"
    limits.memory: 32Gi
    pods: "50"
---
# 개별 컨테이너 기본값 (requests 없는 Pod 방지)
apiVersion: v1
kind: LimitRange
metadata:
  name: pposiraegi-limits
  namespace: pposiraegi
spec:
  limits:
    - type: Container
      default:
        cpu: 200m
        memory: 256Mi
      defaultRequest:
        cpu: 100m
        memory: 128Mi
```

---

### 3-2. 단기 (1-2개월)

#### cert-manager: 인증서 자동 갱신

```
현재: ACM 인증서를 수동으로 ARN 입력
문제: 갱신 까먹으면 HTTPS 인증서 만료 → 서비스 장애
```

```bash
helm install cert-manager jetstack/cert-manager \
  -n cert-manager --create-namespace \
  --set installCRDs=true
```

```yaml
# Let's Encrypt ClusterIssuer
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your@email.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
      - http01:
          ingress:
            class: alb
```

#### external-dns: Route53 자동 동기화

```
현재: Ingress 만들 때마다 Route53 레코드 수동 추가
문제: Ingress ADDRESS 바뀌면 DNS도 수동으로 바꿔야 함
```

```bash
helm install external-dns external-dns/external-dns \
  --set provider=aws \
  --set "domainFilters[0]=pposiraegi.com" \
  --set policy=sync
```

Ingress에 어노테이션만 추가하면 Route53이 자동 동기화:
```yaml
annotations:
  external-dns.alpha.kubernetes.io/hostname: api.pposiraegi.com
```

#### VPC Endpoint: NAT 비용 절감

```hcl
# ECR + S3 VPC Endpoint (데이터 전송 비용 절감)
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [var.private_route_table_id]
}

resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.region}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [var.private_subnet_a_id, var.private_subnet_b_id]
  security_group_ids  = [var.internal_sg_id]
  private_dns_enabled = true
}
```

> [!tip] ECR pull이 NAT를 통하지 않으면
> 노드 100대가 이미지 pull 할 때 NAT 데이터 비용이 0이 된다.
> Interface Endpoint는 시간당 $0.01이지만 트래픽 많으면 훨씬 이득.

---

### 3-3. 중기 (3-6개월)

#### Argo Rollouts: 안전한 배포 전략

```
현재: Deployment 교체 → 롤링 업데이트 (구버전 Pod 즉시 종료)
실무: 신버전 5% 트래픽 → 에러율 확인 → 점진 증가 → 100%
```

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: api-gateway
spec:
  strategy:
    canary:
      steps:
        - setWeight: 10     # 10% 트래픽 신버전
        - pause: {duration: 5m}   # 5분 관찰
        - setWeight: 50
        - pause: {duration: 5m}
        - setWeight: 100
      # 자동 롤백: 에러율 5% 초과 시
      analysis:
        templates:
          - templateName: success-rate
        args:
          - name: service-name
            value: api-gateway
```

#### Terraform Remote State: 팀 협업

```hcl
# backend.tf
terraform {
  backend "s3" {
    bucket         = "pposiraegi-tfstate"
    key            = "infrastructure/terraform.tfstate"
    region         = "ap-northeast-2"
    dynamodb_table = "pposiraegi-tflock"   # 동시 apply 방지
    encrypt        = true
  }
}
```

> [!note] 언제 도입해야 하나
> 인프라 작업자가 2명 이상이 되는 순간 필수다.
> 혼자일 때도 state 파일 날리면 재앙이니 S3 백업은 해두는 게 낫다.

#### Velero: 재해 복구

```
쿠버네티스 리소스(Deployment, Secret, ConfigMap 등) + PV 데이터 백업
실수로 namespace 날려도 복구 가능
```

```bash
velero install \
  --provider aws \
  --plugins velero/velero-plugin-for-aws \
  --bucket pposiraegi-velero-backup \
  --backup-location-config region=ap-northeast-2

# 매일 새벽 2시 백업
velero schedule create daily-backup \
  --schedule "0 2 * * *" \
  --ttl 168h  # 7일 보관
```

---

### 3-4. 심화 (실무 고수 레벨)

#### Service Mesh (Istio / Linkerd)

```
현재: 서비스간 통신이 암호화 안 됨, 재시도 로직 앱에 있음
Service Mesh 도입 시:
- mTLS: Pod 간 통신 자동 암호화
- 서킷 브레이커: 다운된 서비스로 연결 차단 (앱 코드 수정 없이)
- 분산 트레이싱: 요청이 어느 서비스에서 얼마나 걸렸는지 시각화
- 트래픽 미러링: 실제 트래픽을 새버전으로도 복사해서 테스트
```

> [!warning] Service Mesh 도입 비용
> 모든 Pod에 사이드카 컨테이너가 붙음 → CPU/Memory 약 10-15% 증가.
> 복잡도도 올라가니 규모가 작으면 오버엔지니어링이 될 수 있다.

#### OPA Gatekeeper / Kyverno: 정책 강제

```
"루트로 실행하는 컨테이너 배포 금지"
"resources.requests 없는 Deployment 거부"
"허가된 레지스트리(ECR)에서만 이미지 pull 허용"
같은 규칙을 코드로 강제
```

```yaml
# Kyverno: ECR 외 이미지 차단 예시
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: restrict-image-registries
spec:
  validationFailureAction: Enforce
  rules:
    - name: validate-registries
      match:
        resources:
          kinds: [Pod]
      validate:
        message: "ECR 이미지만 허용됩니다."
        pattern:
          spec:
            containers:
              - image: "*.dkr.ecr.ap-northeast-2.amazonaws.com/*"
```

#### CoreDNS 튜닝

```
실무에서 DNS 쿼리가 레이턴시 병목이 되는 경우가 있다.
기본 ndots:5 설정이 불필요한 DNS 쿼리를 5번씩 날린다.
```

```yaml
# Pod spec에서 DNS 쿼리 최적화
spec:
  dnsConfig:
    options:
      - name: ndots
        value: "2"    # 기본 5 → 2로 줄이면 외부 도메인 쿼리 빨라짐
      - name: single-request-reopen
```

---

## 4. 각 영역별 깊이있는 내용

### 4-1. Karpenter 심화: 실무에서 자주 만나는 상황

#### Spot 인터럽션 발생 시 흐름

```
1. AWS → SQS: "이 Spot 인스턴스 2분 후 회수"
2. Karpenter → SQS 폴링 → 인터럽션 감지
3. Karpenter → Pod cordon + drain (PDB 존중)
4. PDB: 최소 replicas 보장하면서 Pod 옮김
5. Karpenter → 새 노드 프로비저닝 (다른 인스턴스 타입/AZ)
6. 기존 노드 종료
```

> [!tip] Spot 인터럽션에 강한 구조
> - `consolidationPolicy: WhenUnderutilized` + Spot 다양한 인스턴스 타입
> - PDB `minAvailable: 1` 필수
> - 중요 서비스는 On-demand NodePool에 `nodeSelector` 고정

#### Karpenter 비용 최적화 전략

```yaml
# 앱별로 On-demand / Spot 선택
# 중요 서비스 (user-service, order-service)
nodeSelector:
  karpenter.sh/capacity-type: on-demand

# 비용 절감 가능한 서비스 (api-gateway, product-service)
nodeSelector:
  karpenter.sh/capacity-type: spot
```

### 4-2. Argo CD 심화: GitOps 브랜치 전략

```
단순 구조 (소규모 팀)
  main 브랜치 → Argo CD가 자동 sync → 프로덕션 배포

환경 분리 구조 (실무)
  dev 브랜치   → Argo CD dev 앱  → dev 클러스터
  staging 브랜치 → Argo CD staging 앱 → staging 클러스터
  main 브랜치   → Argo CD prod 앱 → prod 클러스터

이미지 태그 자동 업데이트: Argo CD Image Updater
  ECR에 새 이미지 push → Image Updater가 k8s 레포 커밋 자동 생성 → Argo CD sync
```

### 4-3. IRSA 심화: 최소 권한 원칙 점검

```bash
# 실제로 어떤 AWS API를 호출하는지 CloudTrail로 확인
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=Username,AttributeValue=<role-name> \
  --start-time $(date -d '7 days ago' +%s) \
  --output json | jq '.Events[].CloudTrailEvent' | jq -r '.eventName' | sort -u
```

> [!tip] 권한 최소화 접근법
> 처음엔 넓게 주고, CloudTrail로 실제 사용 API 확인 → 나머지 제거.
> AWS IAM Access Analyzer를 활용하면 미사용 권한을 자동으로 찾아준다.

### 4-4. EKS 네트워크 심화: IP 고갈 문제

```
EKS 기본 VPC CNI: 노드당 ENI × IP 할당
문제: t3.medium = ENI 3개 × IP 6개 = 최대 18개 Pod (실제론 더 적음)
```

```bash
# 현재 노드별 가용 IP 확인
kubectl get nodes -o custom-columns=\
NAME:.metadata.name,\
MAX_PODS:.status.allocatable.pods
```

해결책: **Prefix Delegation** (EKS 1.24+)
```
기존: ENI당 IP 1개씩 할당 → IP 낭비
Prefix: ENI당 /28 CIDR(16개 IP) 할당 → 같은 ENI로 4배 더 많은 Pod
```

---

## 요약: 우선순위 학습 순서

```
즉시 (프로덕션 전)
  1. Prometheus + Grafana (관찰 없이는 운영 불가)
  2. NetworkPolicy (최소한의 보안)
  3. ResourceQuota / LimitRange (폭주 방지)

단기 (1-2개월)
  4. cert-manager (인증서 자동화)
  5. external-dns (Route53 자동화)
  6. VPC Endpoint (비용 절감)

중기 (3-6개월)
  7. Argo Rollouts (안전한 배포)
  8. Terraform Remote State (팀 협업)
  9. Velero (재해 복구)

심화 (고수 레벨)
  10. Service Mesh (Istio/Linkerd)
  11. OPA Gatekeeper / Kyverno (정책 코드화)
  12. EKS 업그레이드 전략 실습
  13. Prefix Delegation / CoreDNS 튜닝
```

> [!note] 핵심 마인드셋
> 실무 인프라 담당자의 역할은 **"구성"이 아니라 "설명"**이다.
> "왜 이 구조인가", "장애가 나면 어디서 나는가", "비용이 왜 이만큼인가"를
> 즉시 대답할 수 있을 때 실무 수준이다.
