---
title: pposiraegi EKS 플랫폼 Bootstrap 트러블슈팅 회고 — 2026-04-29
tags:
  - eks
  - karpenter
  - irsa
  - istio-ambient
  - terraform
  - troubleshooting
  - devops
  - infrastructure
aliases:
  - EKS 부트스트랩 회고
  - karpenter irsa 트러블슈팅
date: 2026-04-29
category: 교육/구름딥다이브
status: 완성
priority: 높음
---

# pposiraegi EKS 플랫폼 Bootstrap 트러블슈팅 회고

## 목차
- [[#1. 배경 및 작업 범위|배경 및 작업 범위]]
- [[#2. 발생 문제 전체 목록|발생 문제 전체 목록]]
- [[#3. 근본 원인 분석|근본 원인 분석]]
- [[#4. operation-strix 비교|operation-strix 비교]]
- [[#5. 미결 사항|미결 사항]]
- [[#6. 다음 번에 놓치지 말아야 할 것|다음 번에 놓치지 말아야 할 것]]
- [[#7. Karpenter는 됐지만, 운영 경계는 아직 덜 잠겼다|Karpenter는 됐지만, 운영 경계는 아직 덜 잠겼다]]

---

## 1. 배경 및 작업 범위

**클러스터**: `pposiraegi-cluster` (EKS 1.32, ap-northeast-2, goorm 계정 779846782353)  
**목표**: `scripts/bootstrap-platform.sh` 작성 → 플랫폼 컴포넌트 한 번에 설치

설치 순서:
```
metrics-server → ArgoCD → Karpenter → AWS LBC → Istio Ambient → gp3 StorageClass → kube-prometheus-stack+Loki → ESO → ArgoCD sync
```

작업 도중 `terraform destroy`로 클러스터 해체. 총 15개 이상의 문제가 연쇄 발생.

---

## 2. 발생 문제 전체 목록

### 2-1. Karpenter NodePool — `spec.template.spec.tolerations` 유효하지 않음

**증상**: `kubectl apply -f nodepool.yaml` → validation error  
**원인**: Karpenter v1 NodePool spec에 `tolerations` 필드가 없음 (v0.x와 스키마 다름)  
**해결**: `nodepool.yaml`에서 `tolerations` 블록 전체 제거

---

### 2-2. Istio — `platform: eks` 알 수 없는 값

**증상**: `helm install istiod` 실패  
**원인**: Istio Helm values에서 `platform: eks`는 유효한 값이 아님 (공식 문서에 없음)  
**해결**: `istiod-values.yaml`에서 `platform: eks` 제거

---

### 2-3. Gateway API CRD 미설치 → Waypoint 적용 실패

**증상**: `kubectl apply -f waypoint.yaml` → CRD `gateways.gateway.networking.k8s.io` not found  
**원인**: Istio Ambient Waypoint는 Gateway API CRD에 의존하는데, EKS에는 기본 설치 안 됨  
**해결**: bootstrap 스크립트에 CRD 사전 설치 단계 추가
```bash
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/standard-install.yaml
```

---

### 2-4. `production` 네임스페이스 없음 → Waypoint/AuthorizationPolicy 적용 실패

**증상**: `kubectl apply -f waypoint.yaml` → namespace not found  
**원인**: Waypoint보다 namespace 생성이 먼저 되어야 하는데 순서가 없었음  
**해결**: bootstrap 스크립트에서 Istio 설치 전 `base/namespace.yaml` 먼저 apply

---

### 2-5. `spec.infrastructure.replicas` Gateway API v1 비호환 (논쟁 있음)

**증상**: `kubectl apply -f waypoint.yaml` → unknown field  
**원인**: `spec.infrastructure` 필드는 GEP-1645가 필요하며 Gateway API v1.2+ + Istio 1.22+ 조합에서만 동작  
**해결 (Claude Code 세션)**: 해당 필드 제거  
**Codex 세션 판단**: Istio 1.22+/GEP-1645 기준 유효하므로 복구 (커밋 9e221ff)

> [!note] 논쟁 포인트
> 설치 환경의 Gateway API CRD 버전에 따라 달라짐. v1.2.0 standard-install 후에는 동작할 수 있음.
> 다음 번에 실제 `kubectl explain gateway.spec.infrastructure` 로 먼저 확인할 것.

---

### 2-6. gp3 StorageClass 없음 → Grafana PVC Pending

**증상**: kube-prometheus-stack 설치 후 Grafana Pod가 `Pending` 상태 (PVC unbound)  
**원인**: EKS의 기본 StorageClass는 `gp2` (in-tree driver). EBS CSI 드라이버 없이는 `gp3`를 사용할 수 없음  
**해결 (두 단계)**:
1. Terraform에 EBS CSI 드라이버 addon 추가 (`irsa.tf`)
2. `storageclass-gp3.yaml` 생성 + bootstrap에 `storage` 단계 추가
```yaml
provisioner: ebs.csi.aws.com
volumeBindingMode: WaitForFirstConsumer
parameters:
  type: gp3
  encrypted: "true"
```

---

### 2-7. Grafana datasource 기본값 충돌

**증상**: kube-prometheus-stack 설치 실패 (validation error)  
**원인**: chart가 Prometheus datasource를 자동으로 `isDefault: true`로 생성하는데, 우리도 values에서 Prometheus datasource를 선언해서 충돌  
**해결**: `kube-prometheus-stack-values.yaml`에서 Prometheus datasource 선언 제거, Loki만 유지

---

### 2-8. Loki v6.x `bucketNames` nil pointer

**증상**: Loki 설치 실패 — `nil pointer dereference: bucketNames.chunks`  
**원인**: Loki Helm chart v6.x에서 `storage.bucketNames` 필드가 필수로 변경됨. v5.x values 형식으로는 동작 안 함  
**해결**: `loki-values.yaml` 수정
```yaml
storage:
  type: s3
  bucketNames:
    chunks: pposiraegi-loki-logs
    ruler: pposiraegi-loki-logs
    admin: pposiraegi-loki-logs
  s3:
    region: ap-northeast-2
```

---

### 2-9. Karpenter — `iam:GetInstanceProfile` AccessDenied

**증상**: EC2NodeClass `Ready=False`, Karpenter controller log에 IAM AccessDenied  
**원인**: Karpenter v1은 Instance Profile을 직접 CRUD함. 이 권한이 초기 IAM 정책에 없었음  
**해결**: Karpenter controller IAM policy에 추가
```json
{
  "Action": ["iam:CreateInstanceProfile", "iam:TagInstanceProfile",
             "iam:AddRoleToInstanceProfile", "iam:RemoveRoleFromInstanceProfile",
             "iam:DeleteInstanceProfile", "iam:GetInstanceProfile"],
  "Resource": "arn:aws:iam::*:instance-profile/*"
}
```

---

### 2-10. Karpenter — `ec2:CreateFleet` on `fleet/*` 거부

**증상**: NodePool이 `Ready=True`인데 인스턴스가 안 뜸  
**원인**: `AllowScopedEC2InstanceActions` statement의 Resource 목록에 `fleet/*`가 빠짐  
**해결**: `"arn:aws:ec2:*:*:fleet/*"` 추가

---

### 2-11. Karpenter — `ec2:DeleteLaunchTemplate` 거부 (StringEquals `"*"` 리터럴 해석)

**증상**: 인스턴스 프로비저닝 실패  
**원인**: `AllowScopedEC2InstanceActionsWithTags`에서 `StringEquals { "aws:ResourceTag/karpenter.sh/nodepool" = "*" }` 조건을 쓰면 `"*"`를 와일드카드가 아닌 리터럴 값으로 해석. 태그가 없는 신규 LaunchTemplate에는 적용 안 됨  
**해결 (두 가지)**:
1. 와일드카드 조건은 `StringLike`로 변경
2. `DeleteLaunchTemplate`은 태그 조건 없이 별도 statement로 분리
```hcl
{
  Sid    = "AllowDeleteLaunchTemplate"
  Effect = "Allow"
  Action = ["ec2:DeleteLaunchTemplate"]
  Resource = "arn:aws:ec2:*:*:launch-template/*"
}
```

---

### 2-12. Karpenter — `pricing:GetProducts` AccessDenied

**증상**: Karpenter controller log에 pricing API 에러  
**원인**: Spot 인스턴스 가격 데이터 조회 권한 누락 (공식 docs 예제에 빠져있는 경우 있음)  
**해결**: IAM policy에 추가
```json
{ "Action": ["pricing:GetProducts"], "Resource": "*" }
```

---

### 2-13. IRSA 역할 자체가 없음 (LBC / ESO / Loki)

**증상**: AWS LBC, External Secrets Operator, Loki Helm install 시 ServiceAccount에 IAM 권한이 없음  
**원인**: bootstrap 스크립트 작성 시 Terraform에 IRSA 역할이 없었음 — 스크립트만 먼저 작성하고 Terraform을 나중에 맞추는 순서였음  
**해결**: `infrastructure/irsa.tf` 새로 작성 (EBS CSI, LBC, ESO, Loki 4개 역할)

---

### 2-14. Helm `pending-install` / `pending-upgrade` lock

**증상**: 설치 재시도 시 `cannot re-use a name that is still in use` 또는 release가 stuck  
**원인**: Helm release가 실패했는데 lock 상태로 남음  
**해결**: 
```bash
helm uninstall <release> -n <namespace>
kubectl delete pvc --all -n <namespace>  # PVC가 있으면
```

---

### 2-15. Karpenter 노드 join 실패 — `Registered=NodeNotFound`

**증상**: EC2 인스턴스가 `Running`, bootstrap 완료 (`nodeadm` log: `done! {"duration": 0.79s}`)인데 kubectl에 노드 미등록  
**원인**: **클러스터 SG가 Karpenter 노드에 붙지 않음**

EKS managed node group은 클러스터 SG(`sg-053cf589ea439ad2d`)를 자동으로 모든 노드에 attach함. 하지만 Karpenter 노드는 `EC2NodeClass.securityGroupSelectorTerms`에 명시된 SG만 가져감. 현재 설정:
```yaml
securityGroupSelectorTerms:
  - tags:
      karpenter.sh/discovery: "pposiraegi-cluster"
```
이 태그는 `pposiraegi-eks-node-sg`에만 있고 클러스터 SG에는 없었음.

`aws_security_group_rule.cluster_api_from_karpenter_nodes` 규칙은 "node SG → cluster SG 443 허용"인데, 이것은 **방향(inbound rule)만** 추가한 것이고, 노드가 클러스터 SG를 갖도록 **attach**하는 것과는 다른 얘기임.

**해결 (적용 전 클러스터 destroy)**:
```hcl
# infrastructure/modules/karpenter/main.tf에 추가 필요
resource "aws_ec2_tag" "cluster_sg_karpenter_discovery" {
  resource_id = var.cluster_security_group_id
  key         = "karpenter.sh/discovery"
  value       = var.cluster_name
}
```
이렇게 하면 EC2NodeClass의 selector가 클러스터 SG도 자동으로 포함함.

---

## 3. 근본 원인 분석

### IRSA 이해 부족

커뮤니티 모듈(`terraform-aws-modules/eks/aws//modules/karpenter`) 없이 직접 IAM 정책을 작성할 때 발생하는 전형적인 패턴:

| 상황 | 문제 |
|---|---|
| Karpenter v0.x → v1.x API 변경 | Instance Profile CRUD가 v1에서 새로 추가됨 |
| 공식 docs 예제 불완전 | `pricing:GetProducts`, `fleet/*` 범위 누락 |
| IAM condition 동작 오해 | `StringEquals "*"` = 리터럴 매칭, 와일드카드는 `StringLike` |
| 의존성 순서 역전 | 컴포넌트 설치 스크립트 → Terraform IRSA 역할 순으로 작성 |

### Security Group — "규칙 추가"와 "SG attach"의 차이

Karpenter 노드 네트워킹의 전제:
- 노드가 API 서버에 연결하려면 (port 443): 노드 SG → cluster SG inbound 허용 ✅ (우리가 추가)
- 컨트롤플레인이 kubelet에 연결하려면 (port 10250): 이것도 `eks_node` SG가 0.0.0.0/0 허용 ✅
- **EKS bootstrap 인증 채널**: 노드가 클러스터 SG를 가지고 있어야 EKS 내부 인증이 동작 ❌ (누락)

→ "보안 그룹 규칙을 추가하는 것"과 "그 보안 그룹을 인스턴스에 attach하는 것"은 별개의 작업.

---

## 4. operation-strix와의 비교

> [!info] 왜 operation-strix에서는 같은 문제를 안 겪었나

| 항목 | operation-strix | pposiraegi |
|---|---|---|
| EKS 프로비저닝 | `terraform-aws-modules/eks/aws` v20.x (커뮤니티 모듈) | raw `aws_eks_cluster` + `aws_eks_node_group` |
| Karpenter IAM | `//modules/karpenter` 서브모듈이 모든 권한 자동 생성 | 직접 작성 → 누락 다수 |
| 노드 클러스터 합류 | `create_access_entry = true` (EKS Access Entry) | aws-auth ConfigMap 방식 |
| 클러스터 SG 처리 | 모듈이 cluster SG에 `karpenter.sh/discovery` 태그 자동 부착 | 수동 생성 node SG에만 태그 → 클러스터 SG 누락 |
| Karpenter 버전 | 0.37.0 (pre-v1, Instance Profile 직접 관리 안 함) | v1.x (Instance Profile CRUD 필요) |
| 모니터링 스택 | 없음 | kube-prometheus + Loki (EBS CSI, gp3 필요) |

**핵심**: operation-strix는 커뮤니티 모듈이 Karpenter 요구사항을 릴리즈와 동기화해서 관리. pposiraegi는 v1 API의 신규 요구사항을 수동으로 따라가야 했는데 초기 설계에서 빠뜨림.

---

## 5. 미결 사항

클러스터 destroy 시점에 해결되지 않은 것들:

1. **Karpenter 노드 join** — cluster SG discovery 태그 미추가 (해결 방법은 2-15 참조, 다음 배포 때 적용)
2. **monitoring 설치 미완** — 노드 join이 안 되어서 gp3 PVC가 bound 안 됨
3. **ESO, ArgoCD sync** — monitoring 이후 단계는 시작도 못 함
4. **`waypoint.yaml` infrastructure.replicas 논쟁** — Claude Code 세션에서 제거, Codex 세션에서 복구. 실제 Gateway API v1.2.0 + Istio 1.22+ 환경에서 테스트 필요

---

## 6. 다음 번에 놓치지 말아야 할 것

### Terraform 설계 체크리스트 (컴포넌트 설치 전)

```
[ ] 각 Helm chart가 사용할 ServiceAccount의 IRSA 역할이 Terraform에 있는가?
[ ] Karpenter EC2NodeClass의 securityGroupSelectorTerms가 cluster SG를 포함하는가?
    → cluster SG에 karpenter.sh/discovery 태그가 있는가? (aws_ec2_tag 리소스)
[ ] EBS CSI 드라이버 addon이 있는가? (gp3 PVC 사용하는 컴포넌트 있으면 필수)
[ ] gp3 StorageClass가 default로 설정되어 있는가?
[ ] Gateway API CRD가 설치되어 있는가? (Istio Ambient Waypoint 사용 시)
```

### Karpenter v1 IAM 필수 권한 (직접 작성 시)

| 권한 | 이유 |
|---|---|
| `iam:CreateInstanceProfile` 등 6개 | v1에서 Instance Profile을 직접 CRUD |
| `ec2:CreateFleet` + `fleet/*` Resource | Fleet API 사용 |
| `ec2:DeleteLaunchTemplate` (태그 조건 없이) | 생성 직후엔 태그가 없음 |
| `pricing:GetProducts` | Spot 가격 조회 |
| 태그 와일드카드는 `StringLike` | `StringEquals "*"` = 리터럴 |

### 두 AI 도구 병렬 사용 시 주의

이번 세션에서 Claude Code + Codex를 동시에 사용하여 같은 파일을 수정함:

- `waypoint.yaml`: Claude Code가 `infrastructure.replicas` 제거 → Codex가 복구 → 워킹트리에 충돌
- `kube-prometheus-stack-values.yaml`: 양쪽에서 수정
- Terraform 모듈: 양쪽에서 추가

**교훈**: 두 도구를 병렬로 쓸 때는 파일 범위를 나눠야 함 (Terraform은 Claude Code, Kubernetes manifests는 Codex 등). 아니면 한 도구 커밋 → 다른 도구 시작.

---

## 7. Karpenter는 됐지만, 운영 경계는 아직 덜 잠겼다

이번 bootstrap 이후 확인한 결론은 “Karpenter가 안 된다”가 아니었다.

Karpenter는 Pending Pod를 감지해 NodeClaim을 만들고, EC2 Spot 노드를 프로비저닝하는 핵심 경로까지는 동작했다. 문제는 Karpenter 자체보다 **어떤 워크로드를 어떤 노드에 태울지 강제하는 운영 경계**였다.

### 7-1. 현재 Karpenter가 잘하는 부분

현재 구성은 비용 최적화 앱 워커를 자동으로 띄우는 방향으로는 꽤 잘 잡혀 있다.

- `m5.large`, `m5a.large`, `m6i.large`, `m6a.large`, `c5.large`, `c6i.large`만 허용
- `t3` 계열 제외 — burstable CPU 크레딧 변수가 있어 타임딜성 워크로드 설명에 불리
- Spot + On-Demand fallback 구조
- `consolidateAfter: 30s`로 유휴 노드 빠른 회수
- `budgets.nodes: 10%`로 disruption 속도 제한
- Spot interruption SQS/EventBridge 연결
- Karpenter node SG와 EKS cluster SG 통신 규칙 보완
- NodePool AZ를 실제 private subnet AZ와 일치

즉, “비용 최적화 앱 워커를 자동으로 띄우는 구조” 자체는 성립했다.

### 7-2. 아직 부족한 부분

현재 NodePool에는 `node-role: app` 라벨이 붙지만, 앱 Deployment에는 `nodeSelector`, `affinity`, `tolerations`가 없다.

의도는 다음과 같다.

```text
managed node group(t3.medium) = 시스템/플랫폼
Karpenter Spot node           = stateless 앱 워커
```

하지만 현재 스케줄러가 보기에는 둘 다 그냥 노드다.

따라서 앱, 모니터링, 플랫폼 컴포넌트가 섞일 가능성이 있다. Karpenter의 비용 최적화가 제대로 의미 있으려면 “앱은 Spot 노드로, 플랫폼은 안정 노드로”라는 경계를 코드로 강제해야 한다.

### 7-3. 모니터링과 Karpenter는 상충하지 않는다

상충하는 것은 Karpenter 자체가 아니라 다음 조합이다.

```text
비용 최적화형 Spot App NodePool
vs
stateful/heavy platform component
```

Prometheus, Grafana, Loki는 PVC, scrape 연속성, 캐시 메모리, 재시작 안정성이 중요하다. 따라서 프로덕션 기준에서는 app Spot NodePool에 무작정 섞기보다 별도 platform/monitoring 노드 정책이 필요하다.

실습 환경에서는 Loki cache/test/canary를 끄고 최소 구성으로 안정화했다. 이것은 편법이라기보다 작은 노드 환경에서 우선 부트스트랩을 성립시키기 위한 현실적인 축소다.

### 7-4. 앞으로 잠가야 할 경계

1. **노드 역할 분리**
   - 앱 Deployment에 `nodeSelector` 또는 `affinity`로 app NodePool 의도 명시
   - platform component는 managed node group 또는 별도 On-Demand NodePool로 분리
   - monitoring stack은 PVC/AZ/노드 안정성까지 고려해 배치

2. **ArgoCD targetRevision**
   - 현재 작업 브랜치와 ArgoCD가 바라보는 브랜치가 다르면 sync해도 과거 상태가 배포됨
   - 팀 작업에서는 “왜 반영 안 되지?”의 고전적인 함정

3. **ExternalSecret 실제 리소스**
   - ESO 설치는 bootstrap에 포함됨
   - 하지만 앱이 참조하는 `app-secret`을 만드는 `SecretStore` / `ExternalSecret` 리소스가 필요
   - 없으면 `CreateContainerConfigError` 발생

4. **Ingress / ALB / TargetGroupBinding**
   - Terraform ALB와 AWS LBC가 만드는 ALB 역할이 겹칠 수 있음
   - 둘 중 하나를 명확히 선택해야 함
   - Terraform ALB 재사용이면 `TargetGroupBinding`
   - LBC 중심이면 Kubernetes `Ingress`

5. **Istio AuthorizationPolicy**
   - `/actuator/prometheus`를 Prometheus SA만 접근하게 하려는 의도는 좋음
   - 하지만 넓은 internal allow policy가 있으면 경로 제한 의도가 약해질 수 있음
   - 서비스 간 호출 정책까지 세분화 필요

6. **앱 IRSA**
   - ServiceAccount annotation만 있고 실제 IAM Role 생성 책임이 불명확하면 런타임에서 깨짐
   - LBC/ESO/Loki/Karpenter처럼 Terraform에서 역할 생성까지 함께 관리하는 쪽이 명확함

7. **Karpenter destroy flow**
   - `terraform destroy` 전에 NodePool/NodeClaim/Spot request 정리 필요
   - 아니면 Karpenter가 만든 EC2/Spot request가 Terraform 리소스 삭제를 막을 수 있음

### 7-5. 핵심 교훈

Karpenter의 난이도는 “노드를 띄우는 것”에서 끝나지 않는다.

진짜 운영 포인트는 다음 질문에 답하는 것이다.

```text
어떤 워크로드가
어떤 노드풀에
어떤 권한으로
어떤 트래픽 경로를 통해
어떤 Secret을 받아
어떤 disruption 정책 아래에서
어떻게 scale 되는가
```

이번 실습은 Karpenter core path는 뚫었지만, 운영 경계는 아직 잠가야 한다는 점을 확인한 작업이었다.
