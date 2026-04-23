---
title: ECS → EKS 마이그레이션 가이드
tags:
  - eks
  - ecs
  - karpenter
  - argocd
  - migration
  - terraform
  - irsa
  - kubernetes
  - devops
  - infrastructure
aliases:
  - EKS 마이그레이션
  - ECS to EKS
date: 2026-04-15
category: K8s_Deep_Dive/k8s실습
status: 완성
priority: 높음
---

# 🎯 ECS → EKS 마이그레이션 가이드

## 📑 목차
- [[#1. 핵심 원칙|핵심 원칙]]
- [[#2. 사전 준비 코드 수정|사전 준비 (코드 수정)]]
- [[#3. 인프라 구성 순서|인프라 구성 순서]]
- [[#4. 시크릿 부트스트랩 순서|시크릿 부트스트랩 순서]]
- [[#5. IRSA 연결 확인|IRSA 연결 확인]]
- [[#6. 앱 배포 후 검증 체크리스트|앱 배포 후 검증 체크리스트]]
- [[#7. DNS 컷오버 무중단|DNS 컷오버 (무중단)]]
- [[#8. 자주 터지는 문제와 원인|자주 터지는 문제와 원인]]
- [[#9. ECS 레이어 정리 순서|ECS 레이어 정리 순서]]
- [[#10. 요약|요약]]

---

## 1. 핵심 원칙

> [!note] 플랫폼 교체의 본질
> ECS → EKS는 "코드 마이그레이션"이 아니라 **"컨테이너 실행 레이어 교체"**다.
> RDS, Redis, ECR, SSM, Route53은 그대로 두고 실행 플랫폼만 바꾼다.

| 변하지 않는 것 | 변하는 것 |
|--------------|---------|
| RDS 엔드포인트 | ECS → EKS |
| ElastiCache 엔드포인트 | Task Definition → Deployment.yaml |
| ECR 이미지 URI | ALB (ECS용) → ALB Ingress (K8s용) |
| SSM 파라미터 경로 | ECS IAM Role → IRSA |
| Route53 레코드 | Service Discovery → K8s DNS |

---

## 2. 사전 준비 (코드 수정)

### 2-1. 헬스체크 엔드포인트 분리

> [!warning] 이걸 안 하면
> DB가 순간 끊길 때마다 Pod가 재시작된다. liveness가 DB 체크하면 안 된다.

ECS는 단일 `/actuator/health`로 충분했지만, K8s는 3가지가 다르게 동작한다.

```yaml
# application.yaml 추가
management:
  endpoint:
    health:
      probes:
        enabled: true     # /actuator/health/liveness, /actuator/health/readiness 활성화
      group:
        liveness:
          include: ping   # 프로세스 살아있으면 OK (DB 끊겨도 재시작 X)
        readiness:
          include: db, redis   # 의존성 연결 확인 후 트래픽 수신
  endpoints:
    web:
      exposure:
        include: health, info, prometheus
```

#### 📊 Probe 역할 비교표

| Probe | 실패 시 동작 | 체크 대상 |
|-------|-----------|---------|
| startupProbe | 재시작 (기동 중 liveness 비활성화) | ping (기동 완료 여부) |
| livenessProbe | 재시작 | ping (프로세스 이상) |
| readinessProbe | 트래픽 차단 (재시작 X) | db, redis (의존성) |

### 2-2. Graceful Shutdown

```yaml
# application.yaml
server:
  shutdown: graceful
spring:
  lifecycle:
    timeout-per-shutdown-phase: 30s
```

> [!tip] K8s drain 흐름
> `preStop: sleep 5` → ALB 타깃 deregister → `SIGTERM` → graceful shutdown (30s) → `SIGKILL`
> terminationGracePeriodSeconds: 60 이 전체를 감싼다.

### 2-3. 수평 확장 가능 여부 확인

- 세션이 메모리/로컬에 있으면 Redis로 이동
- 파일 업로드가 로컬 디스크로 가면 S3로 이동
- JWT stateless 구조면 문제없음 ✅

---

## 3. 인프라 구성 순서

> [!danger] 순서가 틀리면
> 의존성 오류가 연속으로 터진다. 반드시 이 순서대로 진행한다.

```
1. terraform apply (eks, karpenter)
   └── EKS 클러스터 + 시스템 노드 생성

2. 서브넷 태깅 (수동)
   └── ALB Controller 서브넷 자동 발견에 필수

3. kubectl apply NodePool
   └── Karpenter 워커 노드풀 등록

4. terraform apply (irsa, alb-controller, addons)
   └── 시스템 앱 (ESO, Argo CD, ALB Controller)

5. kubectl apply (namespace, ClusterSecretStore, ExternalSecret)
   └── K8s Secret 생성 확인 후 다음 단계

6. Argo CD App of Apps 등록
   └── 앱 배포 자동화

7. 앱 검증 후 DNS 컷오버
```

### 3-1. EKS 클러스터 뜬 직후 필수 작업

```bash
# kubeconfig 업데이트
aws eks update-kubeconfig --name pposiraegi-cluster --region ap-northeast-2

# Public 서브넷 태깅 (외부 ALB용)
aws ec2 create-tags \
  --resources <public-subnet-a-id> <public-subnet-b-id> \
  --tags Key=kubernetes.io/role/elb,Value=1 \
         Key=kubernetes.io/cluster/pposiraegi-cluster,Value=shared

# Private 서브넷 태깅 (Pod / 내부 ALB용)
aws ec2 create-tags \
  --resources <private-subnet-a-id> <private-subnet-b-id> \
  --tags Key=kubernetes.io/role/internal-elb,Value=1 \
         Key=kubernetes.io/cluster/pposiraegi-cluster,Value=shared
```

> [!danger] 서브넷 태깅 누락
> ALB Controller가 서브넷을 못 찾아 Ingress가 ADDRESS 없이 영원히 Pending 상태가 된다.
> 마이그레이션 중 가장 자주 막히는 1순위 포인트.

### 3-2. Karpenter NodePool 적용

```bash
# EC2NodeClass에 실제 값 채우기
CLUSTER_NAME=$(terraform output -raw eks_cluster_name)
NODE_ROLE=$(terraform output -raw eks_node_role_name)   # ARN 아닌 이름

sed -i "s/REPLACE_ME_NODE_ROLE_NAME/$NODE_ROLE/g" \
  modules/karpenter/nodepools/general.yaml
sed -i "s/REPLACE_ME_CLUSTER_NAME/$CLUSTER_NAME/g" \
  modules/karpenter/nodepools/general.yaml

kubectl apply -f modules/karpenter/nodepools/general.yaml
kubectl apply -f modules/karpenter/nodepools/spot.yaml
```

---

## 4. 시크릿 부트스트랩 순서

> [!warning] ESO 순서 주의
> ExternalSecret이 없으면 앱 Pod가 시크릿 마운트 실패로 못 뜬다.
> 앱 배포 전에 반드시 Secret 생성 확인 후 진행.

```bash
# 1. ClusterSecretStore + ExternalSecret 적용
kubectl apply -f k8s/secrets/external-secret.yaml

# 2. ESO가 SSM에서 값을 읽어 K8s Secret 생성 확인
kubectl get externalsecret -n pposiraegi
# READY=True 가 되면 다음 단계

# 3. Secret 실제 생성 확인
kubectl get secret -n pposiraegi
# pposiraegi-secrets 가 있어야 함
```

---

## 5. IRSA 연결 확인

> [!warning] IRSA 어노테이션 누락
> ServiceAccount에 어노테이션이 없으면 Pod가 AWS API 호출 시 AccessDenied.

```bash
# terraform output에서 ARN 가져오기
IRSA_ARN=$(terraform output -raw irsa_role_arns | jq -r '.["api-gateway"]')

# ServiceAccount 어노테이션 확인
kubectl describe sa api-gateway -n pposiraegi
# Annotations: eks.amazonaws.com/role-arn: arn:aws:iam::...  있어야 함
```

---

## 6. 앱 배포 후 검증 체크리스트

### 6-1. Pod 기본 상태

```bash
# 모든 Pod Running + Ready 확인
kubectl get pods -n pposiraegi

# CrashLoopBackOff 시
kubectl logs <pod> -n pposiraegi --previous

# Pending 지속 시 (Karpenter가 노드 프로비저닝 중이면 1~2분 대기)
kubectl describe pod <pod> -n pposiraegi
# Events: 0/2 nodes available → 정상 (Karpenter가 노드 만드는 중)
```

### 6-2. 서비스간 내부 통신

```bash
# K8s DNS 동작 확인 (api-gateway → user-service 내부 호출)
kubectl exec -it <api-gateway-pod> -n pposiraegi -- \
  curl http://user-service.pposiraegi.svc.cluster.local:8080/actuator/health
```

### 6-3. Ingress / ALB 확인

```bash
# ALB ADDRESS 할당 확인 (2~3분 소요)
kubectl get ingress -n pposiraegi
# ADDRESS 컬럼에 xxx.ap-northeast-2.elb.amazonaws.com 나와야 함

# HTTPS 직접 테스트
curl -v https://<alb-address>/actuator/health -H "Host: api.pposiraegi.com"
```

---

## 7. DNS 컷오버 (무중단)

> [!example] 컷오버 전략: 가중치 기반 점진적 전환
> 한 번에 전환하지 않고 Route53 가중치 라우팅으로 트래픽을 조금씩 넘긴다.

```
ECS 100% → ECS 90% / EKS 10% → ECS 50% / EKS 50% → EKS 100%
각 단계 사이에 에러율, 응답 시간 모니터링 후 진행
```

```bash
# EKS ALB 주소 확인
EKS_ALB=$(kubectl get ingress api-gateway-ingress -n pposiraegi \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo $EKS_ALB
```

> [!tip] TTL 미리 낮추기
> 전환 1시간 전에 Route53 TTL을 300 → 60으로 낮춰두면 전환 즉시 반영된다.
> 컷오버 완료 후 다시 300으로 올리면 된다.

---

## 8. 자주 터지는 문제와 원인

| 증상 | 원인 | 해결 |
|------|------|------|
| Pod `Pending` 지속 | Karpenter NodePool 미적용 or 리밋 초과 | `kubectl describe pod` Events 확인, `kubectl get nodepool` |
| `ImagePullBackOff` | 노드 IAM Role에 ECR 권한 없음 | `AmazonEC2ContainerRegistryReadOnly` 정책 연결 확인 |
| `CrashLoopBackOff` | 시크릿 미생성, DB 연결 실패 | `kubectl logs --previous`, ExternalSecret READY 상태 확인 |
| Ingress `ADDRESS` 없음 | 서브넷 태깅 누락, ALB Controller 미동작 | 서브넷 태깅 확인, ALB Controller 로그 확인 |
| 서비스간 `ECONNREFUSED` | Service 이름/포트 오타, DNS 미동작 | `kubectl get svc -n pposiraegi`, exec으로 curl 직접 테스트 |
| `AccessDenied` (SSM/S3) | IRSA 어노테이션 누락 | ServiceAccount 어노테이션 확인 |
| 502 Bad Gateway | preStop 없이 Pod 종료 | preStop sleep 5, graceful shutdown 설정 |
| HPA 스케일 안됨 | metrics-server 미설치 | `kubectl top pods` 에러 시 metrics-server 설치 |

#### 💻 ALB Controller 로그 확인

```bash
kubectl logs -n kube-system \
  -l app.kubernetes.io/name=aws-load-balancer-controller \
  --tail=50
```

---

## 9. ECS 레이어 정리 순서

> [!tip] 서두르지 말 것
> EKS에서 24시간 이상 정상 운영 확인 후 ECS를 내린다.

```bash
# 1. ECS 서비스 desired count → 0 (트래픽 모니터링하면서 단계적으로)
aws ecs update-service \
  --cluster pposiraegi \
  --service api-gateway \
  --desired-count 0

# 다른 서비스도 동일하게 처리

# 2. 1~2일 후 문제없으면 ECS 모듈 제거
terraform destroy -target=module.ecs

# 3. CodePipeline → Argo CD GitOps로 교체 (선택)
terraform destroy -target=module.pipeline
```

---

## 10. 요약

> [!note] 가장 많이 막히는 4가지 포인트

```
1순위: 서브넷 태깅 누락       → Ingress ADDRESS 안 남
2순위: ESO 순서 미준수         → 앱보다 먼저 Secret 생성 확인
3순위: IRSA ARN 어노테이션     → SA에 실제로 붙었는지 확인
4순위: Karpenter NodePool 미적용 → 노드 안 뜨면 전부 Pending
```

이 4개만 순서대로 확인하면 나머지는 로그 보면서 잡을 수 있다.

#### 📋 최종 체크리스트

- [ ] application.yaml: health probes 분리 (liveness/readiness)
- [ ] application.yaml: graceful shutdown 설정
- [ ] 서브넷 태깅: elb / internal-elb / cluster shared
- [ ] Karpenter NodePool: REPLACE_ME 채워서 적용
- [ ] ExternalSecret READY=True 확인
- [ ] 각 ServiceAccount IRSA ARN 어노테이션 확인
- [ ] Ingress ADDRESS 할당 확인
- [ ] 서비스간 내부 통신 확인 (exec curl)
- [ ] HTTPS 엔드포인트 외부 호출 확인
- [ ] Route53 TTL 낮추기 → 가중치 점진적 전환
- [ ] ECS desired count 0 → 24h 모니터링 → terraform destroy
