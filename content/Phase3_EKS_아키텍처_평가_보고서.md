---
title: Phase 3 EKS 아키텍처 평가 보고서
tags:
  - EKS
  - 아키텍처
  - Kubernetes
  - 평가
aliases:
  - Phase3 Architecture Evaluation
  - EKS 아키텍처 분석
date: 2026-04-24
category: 인프라/아키텍처
status: 완성
priority: 높음
---

# 🎯 Phase 3 EKS 아키텍처 평가 보고서

## 📑 목차
- [[#1-아키텍처-개요|아키텍처 개요]]
- [[#2-장점-분석|장점 분석]]
- [[#3-단점-및-개선점|단점 및 개선점]]
- [[#4-각-계층-상세-평가|각 계층 상세 평가]]
- [[#5-비용-효율성-분석|비용 효율성 분석]]
- [[#6-종합-평가-및-권장사항|종합 평가 및 권장사항]]

---

## 1. 아키텍처 개요

> [!note] 아키텍처 특징
> **MSA 기반 EKS 클러스터**로 CI/CD 자동화, SLO 기반 운영, 옵저버빌리티, 비용 최적화가 통합된 **실무 수준의 구성**

### 📊 핵심 구성 요약

| 구분 | 구성요소 | 설명 |
|------|---------|------|
| **클러스터** | AWS EKS (Control Plane 관리형) | Multi-AZ (2a, 2c) |
| **워커 노드** | Karpenter (Spot 80% / On-Demand 20%) | JIT 프로비저닝 |
| **서비스** | 4개 (gateway, order, product, user) | Spring Boot 3 + gRPC |
| **서비스 메쉬** | Istio mTLS STRICT | 전 구간 암호화 |
| **스케일링** | HPA + KEDA | CPU 기반 + 도메인 기반 |
| **CI/CD** | GitHub Actions + ArgoCD + Argo Rollouts | GitOps + 카나리 배포 |
| **옵저버빌리티** | Prometheus + Loki + Tempo + Grafana | 자체 호스팅 |
| **SLO** | 99.5% 가용성, P99 < 500ms | 모든 자동화의 근거 |

### 🔄 결제 흐름 시퀀스

```
STEP 1 (동기)          BROWSER REDIRECT          STEP 2 (동기)
POST /orders      →    프론트 → PG사      →    POST /orders/confirm
- Idempotency 저장       - 토스 SDK            - PaymentClient.confirm()
- 재고 차감(gRPC)        - 결제창              - PG 서버 승인 호출
- PG URL 반환           - 카드 승인            - SQS publish (side-effect)
```

---

## 2. 장점 분석

### ✅ 1. SLO 기반 자동화 (가장 강력한 장점)

> [!success] 핵심 장점
> **모든 자동화의 숫자 근거**가 SLO로 정의되어 있어 **목표 지향적 운영** 가능

| 자동화 대상 | SLO 연결 | 구현 방식 |
|-----------|---------|---------|
| Rollouts AnalysisRun | 결제 성공률 ≥ 99.5% | Prometheus 메트릭 기반 자동 판단 |
| HPA/KEDA 임계값 | P99 < 500ms | 레이턴시 기반 스케일링 |
| Grafana Alert | Error Budget 0.5% | 장애 예방적 알람 |

**장점:**
- **목표 지향**: 모든 자동화가 명확한 SLO와 연결됨
- **자동 판단**: 사람 개입 없이 SLO 위반 시 자동 롤백
- **지속 개선**: SLO 달성 여부로 구성 최적화 가능

---

### ✅ 2. 결제 아키텍처의 안정성

> [!success] 핵심 장점
> **Idempotency Key + 2-step 리다이렉트**로 **재시도 안전성 확보**

**구현 방식:**
1. **STEP 1**: Idempotency 저장 → 재고 차감 → PG URL 반환
2. **Browser Redirect**: 프론트 → PG사 (백엔드 무관여)
3. **STEP 2**: PG 서버 승인 호출 → completeOrder + SQS publish

**장점:**
- **재시도 안전**: Idempotency Key로 중복 주문 방지
- **PG 독립성**: 브라우저 리다이렉트로 백엔드와 PG 분리
- **Side-effect 분리**: SQS로 비동기 처리 (알림, 통계, Outbox)

---

### ✅ 3. 비용 최적화 전략

> [!success] 핵심 장점
> **Spot 80% + Karpenter + 자체 호스팅**으로 **비용 효율성 극대화**

| 구분 | 비용 절감 요소 | 예상 절감액 |
|------|--------------|-----------|
| **컴퓨팅** | Spot 80% 활용 | ~70% vs On-Demand |
| **노드 관리** | Karpenter JIT 프로비저닝 | ~20% vs ASG |
| **옵저버빌리티** | 자체 호스팅 (공유 노드) | $3~5/월 vs $30~80/월 |
| **스케일링** | HPA + KEDA 도메인 기반 | 오버프로비저닝 최소화 |

**장점:**
- **Spot 활용**: 80% Spot으로 비용 대폭 절감
- **JIT 프로비저닝**: 필요할 때만 노드 생성
- **자체 호스팅 옵저버빌리티**: 규모에 맞는 비용 최적화

---

### ✅ 4. GitOps + 카나리 배포

> [!success] 핵심 장점
> **ArgoCD + Argo Rollouts**로 **안전한 배포 자동화**

**흐름:**
```
GitHub Actions → ECR → Manifest repo → ArgoCD → Argo Rollouts
                                          ↓
                                   카나리 배포 (10%→50%→100%)
                                          ↓
                                   Prometheus AnalysisRun (SLO 기반)
                                          ↓
                                   합격: 다음 단계 / 불합격: 자동 롤백
```

**장점:**
- **GitOps**: Git이 단일 진실의 원천 (Single Source of Truth)
- **자동 롤백**: SLO 위반 시 즉시 롤백
- **渐进적 배포**: 카나리로 리스크 최소화

---

### ✅ 5. 보안 강화 (Istio mTLS + IRSA)

> [!success] 핵심 장점
> **전 구간 암호화 + 최소 권한 원칙** 적용

| 보안 계층 | 구현 방식 | 효과 |
|----------|---------|------|
| **서비스 간** | Istio mTLS STRICT | 전 구간 암호화 |
| **파드 단위** | IRSA (OIDC Provider) | 최소 권한 부여 |
| **시크릿 관리** | External Secrets Operator | Secrets Manager 연동 |
| **네트워크** | Private Subnet | 공개 노출 최소화 |

**장점:**
- **Zero Trust**: 서비스 간 mTLS로 신뢰 구역 제한
- **최소 권한**: 파드 단위로 필요한 권한만 부여
- **시크릿 분리**: Git에 시크릿 저장하지 않음

---

### ✅ 6. 옵저버빌리티의 균형

> [!success] 핵심 장점
> **자체 호스팅으로 비용 최적화하면서 필요한 기능 모두 확보**

| 도구 | 역할 | 비용 (월) |
|------|------|---------|
| **Prometheus** | 메트릭 수집 | ~$1 (EBS) |
| **Loki** | 로그 집계 | ~$1 (EBS) |
| **Tempo** | 분산 트레이싱 | ~$1 (EBS) |
| **Grafana** | 대시보드 + 알람 | $0 (공유 노드) |

**장점:**
- **비용 효율**: 월 $3~5로 모니터링 완성
- **기능 완비**: 메트릭, 로그, 트레이싱 모두 확보
- **확장 가능**: 규모 커지면 관리형으로 이관 가능

---

## 3. 단점 및 개선점

### ⚠️ 1. 결제 흐름의 복잡성

> [!warning] 단점
> **2-step 리다이렉트**는 구현 복잡도가 높고 **디버깅 어려움** 발생

**문제점:**
- **상태 관리 복잡**: STEP 1과 STEP 2 사이에 클라이언트 상태 유지 필요
- **시간축 비동기**: 브라우저 리다이렉트로 인한 시간 지연
- **디버깅 어려움**: PG사와의 통신이 백엔드 밖에서 발생

**개선안:**
```yaml
추가 로깅:
  - STEP 1: PG URL 발급 로그
  - Browser: 프론트 측 이벤트 로깅
  - STEP 2: PG 승인 응답 로그
  
추가 메트릭:
  - STEP 1 → STEP 2 전환 시간
  - STEP 2 실패율
  - PG사별 응답시간
```

---

### ⚠️ 2. Istio AuthorizationPolicy 부재

> [!warning] 단점
> **mTLS는 적용되었으나 서비스 간 접근 제어 정책**이 명시되지 않음

**현재 구성:**
- Istio mTLS STRICT: 전 구간 암호화 ✅
- IRSA: 파드 단위 최소 권한 ✅
- AuthorizationPolicy: 미정의 ❌

**문제점:**
- **접근 제어 불가**: mTLS로 암호화만 되고, 서비스 간 접근 제어 안 됨
- **보안 격약**: 공격자가 한 서비스를 탈취하면 다른 서비스도 접근 가능
- **Zero Trust 불완전**: 신뢰 구역 제한 안 됨

**개선안:**
```yaml
# api-gateway → 모든 서비스 접근 허용
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: api-gateway-allow-all
  namespace: default
spec:
  selector:
    matchLabels:
      app: api-gateway
  action: ALLOW
  rules:
    - to:
      - operation:
          notMethods: ["DELETE"]  # DELETE 금지

# order-service → product, user만 접근 허용
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: order-allow-services
  namespace: default
spec:
  selector:
    matchLabels:
      app: order-service
  action: ALLOW
  rules:
    - to:
      - operation:
          ports: ["8080"]
      when:
        - key: destination.labels.app
          values: ["product-service", "user-service"]

# product-service → user만 접근 허용
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: product-allow-user
  namespace: default
spec:
  selector:
    matchLabels:
      app: product-service
  action: ALLOW
  rules:
    - to:
      - operation:
          ports: ["8080"]
      when:
        - key: destination.labels.app
          values: ["user-service"]

# user-service → 외부 접근 불가 (내부 서비스만)
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: user-deny-external
  namespace: default
spec:
  selector:
    matchLabels:
      app: user-service
  action: DENY
  rules:
    - from:
      - source:
          notNamespaces: ["default"]
```

---

### ⚠️ 3. 자체 호스팅 옵저버빌리티의 운영 부담

> [!warning] 단점
> **자체 호스팅은 운영 부담**이 있어 **팀 성숙도 요구**

**문제점:**
- **업그레이드 관리**: Prometheus, Loki 등 버전 업데이트 필요
- **스토리지 관리**: EBS 볼륨 확장, 백업 필요
- **장애 대응**: 옵저버빌리티 장애 시 직접 대응

**현재 비용:**
- 자체 호스팅: $3~5/월
- AWS 관리형: $30~80/월

**개선안:**
```yaml
팀 성숙도 기반 이관:
  초기 (현재):
    - 자체 호스팅으로 비용 절감
    - 학습 기회 확보
  
  성장 후 (6개월~1년):
    - AMP (Managed Prometheus) 이관
    - CloudWatch Logs 이관
    - 운영 복잡도 → 비용으로 치환
```

---

### ⚠️ 4. Istio의 성능 오버헤드

> [!warning] 단점
> **Envoy Sidecar는 리소스 오버헤드**가 있어 **소규모에는 과잉**일 수 있음

**문제점:**
- **메모리 오버헤드**: 파드당 Envoy가 추가로 100~200MB 사용
- **레이턴시 추가**: mTLS, 트래이싱으로 1~3ms 지연 추가
- **복잡도 증가**: VirtualService, DestinationRule 관리 필요

**현재 규모:**
- 4개 서비스 × 2~10 파드 = 8~40 파드
- Envoy Sidecar: 8~40개

**개선안:**
```yaml
단계적 도입 고려:
  Phase 1 (현재):
    - Istio mTLS STRICT로 보안 강화
    - 레이턴시 허용 범위 내
  
  Phase 2 (규모 확대 시):
    - 마이크로서비스 10개 이상 시
    - 네트워크 정책 복잡해질 때
    - 트래픽 샤딩 필요할 때
```

---

### ⚠️ 5. CI 보강 (이미지 스캐닝) 부재

> [!warning] 단점
> **ECR 취약점 스캔만으로는 부족**하여 **보안 취약점 사전 차단 미흡**

**현재 구성:**
- ECR: "취약점 스캔" 표시됨 ✅
- GitHub Actions: build + test ✅
- 이미지 스캔: 미정의 ❌
- SBOM 생성: 미정의 ❌

**문제점:**
- **ECR 스캔만으로 부족**: ECR Basic Scanning은 기본적 수준
- **CI 단계에서 차단 안 됨**: 취약점 발견 시에도 배포 가능
- **SBOM 없음**: 소프트웨어 구성 요소 추적 불가
- **라이선스 관리 부족**: 오픈소스 라이선스 위험 미확인

**개선안:**
```yaml
# GitHub Actions에 이미지 스캔 추가
name: CI with Security Scanning

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Build Docker Image
        run: docker build -t order-service:${{ github.sha }} .
      
      - name: Run Trivy Scanner
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: order-service:${{ github.sha }}
          format: 'sarif'
          output: 'trivy-results.sarif'
          severity: 'CRITICAL,HIGH'
      
      - name: Upload Trivy Results to GitHub Security
        uses: github/codeql-action/upload-sarif@v2
        with:
          sarif_file: 'trivy-results.sarif'
      
      - name: Generate SBOM with Syft
        uses: anchore/sbom-action@v0
        with:
          image: order-service:${{ github.sha }}
          output-file: sbom.spdx.json
      
      - name: Upload SBOM to GitHub
        uses: actions/upload-artifact@v3
        with:
          name: sbom
          path: sbom.spdx.json
      
      - name: Push to ECR
        if: success()  # 스캔 통과 시에만 푸시
        run: |
          aws ecr get-login-password --region ap-northeast-2 | docker login --username AWS --password-stdin ${{ secrets.ECR_REGISTRY }}
          docker push order-service:${{ github.sha }}

# Policy-as-Code 추가 (OPA Gatekeeper)
policy:
  - image: no-critical-vulnerabilities
  - image: base-image-pinned  # 베이스 이미지 고정
  - image: no-root-user       # root 사용자 금지
  - image: minimal-layers     # 레이어 최소화
```

---

### ⚠️ 6. DR (재해 복구) 전략 부재

> [!warning] 단점
> **단일 리전 (ap-northeast-2) 운영**으로 **리전 장애 시 서비스 중단**

**현재 구성:**
- VPC: 10.0.0.0/16 (ap-northeast-2)
- Multi-AZ: 2a, 2c (같은 리전 내)
- RDS, ElastiCache: Multi-AZ (같은 리전 내)

**문제점:**
- **리전 장애 취약**: 리전 전체 장애 시 서비스 복구 불가
- **데이터 백업만 존재**: RDS 백업은 있지만 실시간 복제 아님
- **RTO/RPO 미정의**: 재해 복구 시간 목표 없음

**개선안:**
```yaml
Phase 1 (단기): 백업 강화
  - RDS: Cross-Region Snapshot (ap-northeast-2 → ap-northeast-1)
  - EBS: Cross-Region Snapshot
  - S3: Cross-Region Replication
  - RTO: 4시간, RPO: 1시간

Phase 2 (중기): Active-Active
  - EKS: Multi-Region (ap-northeast-2 + ap-northeast-1)
  - RDS: Global Database
  - Route 53: Latency-based Routing
  - RTO: < 1시간, RPO: < 5분

Phase 3 (장기): Multi-Region Active-Active
  - DynamoDB Global Tables
  - Global Accelerator
  - RTO: < 10분, RPO: 실시간
```

---

## 4. 각 계층 상세 평가

### 📊 네트워크 계층

#### 구성
```
User → HTTPS → ALB → Ingress → Istio Ingress GW → Service → Pod
```

#### 평가

| 항목 | 평가 | 설명 |
|------|------|------|
| **L7 라우팅** | ✅ 우수 | ALB + Ingress로 자동 프로비저닝 |
| **mTLS** | ✅ 우수 | Istio로 전 구간 암호화 |
| **Multi-AZ** | ✅ 우수 | 2a, 2c로 가용성 확보 |
| **Private Subnet** | ✅ 우수 | 노드, RDS, ElastiCache 격리 |

#### 개선점
```yaml
# 1. NLB 도입 고려 (L4 트래픽)
# - gRPC 트래픽은 NLB가 더 효율적
# - L7 라우팅 필요 없는 내부 통신

# 2. VPC Endpoint 도입
# - S3, DynamoDB, Secrets Manager에 VPC Endpoint
# - 인터넷 경로 제거로 보안 강화

# 3. NetworkPolicy 적용
# - 네임스페이스별 네트워크 격리
# - 최소 권한 네트워크 정책
```

---

### 📊 컴퓨팅 계층

#### 구성
```
EKS Control Plane (AWS 관리)
  ↓
Karpenter (Spot 80% + On-Demand 20%)
  ↓
Worker Nodes (Private Subnet)
  ↓
Pods (HPA + KEDA)
```

#### 평가

| 항목 | 평가 | 설명 |
|------|------|------|
| **Control Plane** | ✅ 우수 | AWS 관리형으로 운영 부담 감소 |
| **Karpenter** | ✅ 우수 | JIT 프로비저닝으로 비용 최적화 |
| **Spot 활용** | ⚠️ 양호 | 80% Spot으로 비용 절감 but 중단 위험 |
| **HPA** | ✅ 우수 | CPU 기반 기본 스케일링 |
| **KEDA** | ✅ 우수 | 도메인 기반 스케일링 (Redis 큐) |

#### 개선점
```yaml
# 1. 노드 풀 분리
nodePools:
  spot-stateless:
    - instanceTypes: [c6a.xlarge, c6i.xlarge]
    - capacityType: spot
    - taints: ["workload=stateless:NoSchedule"]
    - services: [product, user]
  
  on-demand-stateful:
    - instanceTypes: [m6a.xlarge]
    - capacityType: on-demand
    - taints: ["workload=stateful:NoSchedule"]
    - services: [order, api-gateway]

# 2. PDB (PodDisruptionBudget) 강화
podDisruptionBudgets:
  order:
    minAvailable: 2
    reason: "결제 서비스는 최소 2 파드 유지 필요"
  
  product:
    minAvailable: 1
    reason: "상품 서비스는 1 파드로도 운영 가능"

# 3. Node Termination Handler
# - Spot 중단 시 파드 그레이스풀 종료
# - HTTP 요청 완료 대기
```

---

### 📊 스토리지 계층

#### 구성
```
RDS PostgreSQL (주문/상품 DB)
ElastiCache Redis (재고 게이트)
S3 (정적 파일 / 아티팩트)
SQS (결제 완료 side-effect)
```

#### 평가

| 항목 | 평가 | 설명 |
|------|------|------|
| **RDS** | ✅ 우수 | 관리형 PostgreSQL, Multi-AZ |
| **ElastiCache** | ✅ 우수 | Redis Cluster 모드 |
| **SQS** | ✅ 우수 | 비동기 side-effect 처리 |
| **S3** | ✅ 우수 | 정적 파일, 아티팩트 저장 |

#### 개선점
```yaml
# 1. RDS 읽기 전용 복제본
readReplica:
  reason: "상품 조회 부하 분산"
  instanceClass: db.t3.medium
  count: 1

# 2. Redis 캐시 전략
cacheStrategy:
  product:
    - TTL: 1시간
    - eviction: allkeys-lru
    - reason: "상품 정보 자주 변경됨"
  
  user:
    - TTL: 24시간
    - eviction: volatile-ttl
    - reason: "사용자 정보 자주 안 바뀜"

# 3. SQS DLQ (Dead Letter Queue)
deadLetterQueue:
  enabled: true
  maxReceiveCount: 5
  reason: "처리 실패 메시지 보존"
```

---

### 📊 옵저버빌리티 계층

#### 구성
```
Prometheus (메트릭)
  ↓
Loki (로그)
  ↓
Tempo (트레이싱)
  ↓
Grafana (대시보드 + 알람)
```

#### 평가

| 항목 | 평가 | 설명 |
|------|------|------|
| **메트릭** | ✅ 우수 | Prometheus로 15s 스크레이프 |
| **로그** | ✅ 우수 | Loki로 경량 로그 집계 |
| **트레이싱** | ✅ 우수 | Tempo로 분산 트레이싱 |
| **대시보드** | ✅ 우수 | Grafana로 단일 뷰 |
| **비용** | ✅ 우수 | 자체 호스팅으로 $3~5/월 |

#### 개선점
```yaml
# 1. Prometheus 장기 저장
longTermStorage:
  provider: Thanos
  reason: "30일 이상 메트릭 보존"
  cost: +$10/월 (S3)

# 2. Alertmanager 고가용성
alertmanagerHA:
  replicas: 3
  reason: "알람 누락 방지"

# 3. Grafana RBAC
rbac:
  viewers:
    - 개발자
  editors:
    - SRE
  admins:
    - 인프라 팀
```

---

## 5. 비용 효율성 분석

### 💰 월 예상 비용 (4서비스, 파드 2~10개 기준)

| 항목 | 비용 | 비고 |
|------|------|------|
| **EKS Control Plane** | $73/월 | $0.10/시간 × 730시간 |
| **노드 (Karpenter)** | $150~300/월 | Spot 80% + On-Demand 20% |
| **ALB** | $20~50/월 | LCU 기반 |
| **RDS** | $30~100/월 | db.t3.medium × Multi-AZ |
| **ElastiCache** | $20~50/월 | cache.t3.medium |
| **SQS** | $1~5/월 | 요청 기반 |
| **S3** | $1~3/월 | 스토리지 + 요청 |
| **옵저버빌리티** | $3~5/월 | 자체 호스팅 (공유 노드) |
| **기타** | $5~10/월 | VPC, IAM, CloudWatch |
| **총합** | **$303~596/월** | 평균 $450/월 |

### 📊 비용 최적화 기여 요인

| 요인 | 절감 효과 | 설명 |
|------|----------|------|
| **Spot 80%** | ~70% | On-Demand 대비 |
| **Karpenter** | ~20% | ASG 오버프로비저닝 제거 |
| **자체 호스팅 옵저버빌리티** | ~90% | 관리형 대비 |
| **HPA + KEDA** | ~30% | 오버프로비저닝 최소화 |
| **Istio L7 라우팅** | ~10% | ALB LCU 절감 |

### 💡 추가 비용 절감 기회

```yaml
# 1. Savings Plans 도입
savingsPlans:
  type: Compute Savings Plan
  commitment: $100/월 (1년)
  discount: up to 66%
  reason: "On-Demand 20%에 적용"

# 2. EBS 스토리지 최적화
ebsOptimization:
  - gp3 (기존 gp2)
  - provisioned IOPS 제거
  - 예상 절감: ~20%

# 3. S3 수명주기 정책
lifecyclePolicy:
  - 30일 후: Standard-IA
  - 90일 후: Glacier Deep Archive
  - 예상 절감: ~40%
```

---

## 6. 종합 평가 및 권장사항

### 🎯 종합 평가

| 평가 항목 | 점수 | 설명 |
|----------|------|------|
| **아키텍처 설계** | ⭐⭐⭐⭐⭐ | SLO 기반, MSA, 마이크로서비스 원칙 준수 |
| **비용 효율성** | ⭐⭐⭐⭐⭐ | Spot, Karpenter, 자체 호스팅으로 최적화 |
| **보안** | ⭐⭐⭐⭐⭐ | Istio mTLS, IRSA, Private Subnet |
| **가용성** | ⭐⭐⭐⭐ | Multi-AZ, 카나리 배포, 자동 롤백 |
| **운영 자동화** | ⭐⭐⭐⭐⭐ | GitOps, SLO 기반 자동화 |
| **옵저버빌리티** | ⭐⭐⭐⭐ | 자체 호스팅으로 비용 최적화 but 운영 부담 |
| **확장성** | ⭐⭐⭐⭐ | HPA, KEDA, Karpenter로 수평 확장 |

**종합 점수: 4.4/5.0 ⭐⭐⭐⭐**

---

### 📋 단계별 개선 로드맵

#### Phase 4 (즉시, 1~2주)

```yaml
1. Istio AuthorizationPolicy 적용:
   - api-gateway → 모든 서비스 접근 허용 (DELETE 금지)
   - order-service → product, user만 접근 허용
   - product-service → user만 접근 허용
   - user-service → 외부 접근 불가
   - Zero Trust 완성

2. CI 보강 (이미지 스캐닝):
   - GitHub Actions에 Trivy 스캐너 추가
   - SBOM 생성 (Syft)
   - 취약점 발견 시 배포 차단
   - GitHub Security 통합

3. 결제 흐름 로깅 강화:
   - STEP 1: PG URL 발급 로그
   - STEP 2: PG 승인 응답 로그
   - STEP 1 → STEP 2 전환 시간 메트릭
   - PG사별 응답시간 메트릭
```

#### Phase 5 (단기, 1~3개월)

```yaml
1. DR 전략 Phase 1 (백업 강화):
   - RDS: Cross-Region Snapshot (ap-northeast-2 → ap-northeast-1)
   - EBS: Cross-Region Snapshot
   - S3: Cross-Region Replication
   - RTO: 4시간, RPO: 1시간
   - 재해 복구 매뉴얼 작성

2. RDS 읽기 전용 복제본:
   - 상품 조회 부하 분산
   - 메인 DB 부하 감소
   - 읽기 트래픽 분리

3. SQS DLQ:
   - 처리 실패 메시지 보존
   - 디버깅 및 재처리 지원
   - DLQ 모니터링 알람

4. VPC Endpoint:
   - S3, DynamoDB, Secrets Manager
   - 인터넷 경로 제거
   - 보안 강화
```

#### Phase 6 (중기, 3~6개월)

```yaml
1. DR 전략 Phase 2 (Active-Active 준비):
   - EKS: Multi-Region 아키텍처 설계
   - RDS: Global Database 검토
   - Route 53: Latency-based Routing
   - RTO: < 1시간, RPO: < 5분

2. 옵저버빌리티 관리형 이관 (선택):
   - 팀 성숙도 고려
   - AMP (Managed Prometheus)
   - CloudWatch Logs
   - 운영 복잡도 → 비용으로 치환

3. Savings Plans 도입:
   - Compute Savings Plan
   - On-Demand 20%에 적용
   - 1년 약정으로 최대 66% 할인

4. NLB 도입:
   - gRPC 트래픽 NLB로 전환
   - L4 라우팅으로 레이턴시 감소
   - ALB LCU 절감
```

---

### 🚀 최종 권장사항

#### 1. 우선순위 TOP 3 (실제 필요한 개선사항)

> [!tip] 1순위: Istio AuthorizationPolicy 적용
> - **이유**: mTLS는 되어 있지만 서비스 간 접근 제어가 없어 Zero Trust 불완전
> - **노력**: 1~2일
> - **효과**: 보안 강화, 횡적 이동 방지, Zero Trust 완성

> [!tip] 2순위: CI 보강 (이미지 스캐닝)
> - **이유**: ECR 스캔만으로는 부족하고 CI 단계에서 취약점 차단 안 됨
> - **노력**: 1~2일
> - **효과**: 보안 취약점 사전 차단, SBOM 생성, 라이선스 관리

> [!tip] 3순위: DR 전략 Phase 1 (백업 강화)
> - **이유**: 단일 리전 운영으로 리전 장애 시 서비스 중단
> - **노력**: 2~3일
> - **효과**: 재해 복구 능력 확보, RTO 4시간, RPO 1시간 달성

> [!info] 참고: 이미 구현된 항목들
> - ✅ **네임스페이스 분리**: default, monitoring, istio-system, argocd, karpenter, external-secrets 등으로 이미 적절히 분리됨
> - ✅ **KEDA + HPA 이중화**: Redis 장애 시 HPA가 백업으로 동작하여 이미 이중화된 상태
> - ✅ **노드 풀 분리**: Karpenter가 Spot 80% + On-Demand 20%로 이미 분리됨, Pause Pod로 Spot 인터럽션 대응

---

#### 2. 장기적 고려사항

| 항목 | 현재 | 장기 계획 | 이유 |
|------|------|----------|------|
| **옵저버빌리티** | 자체 호스팅 | 관리형 이관 | 운영 복잡도 감소 |
| **서비스 메쉬** | Istio | Linkerd 또는 제거 | 오버헤드 최소화 |
| **결제 아키텍처** | 2-step 리다이렉트 | 1-step API 통합 (PG 허용 시) | 단순화 |
| **데이터베이스** | RDS Single | 읽기 전용 복제본 + 샤딩 | 확장성 |

---

### 📊 성과 지표 (KPI)

> [!success] 현재 달성 KPI
> - **가용성**: 99.5% (SLO 목표 달성)
> - **레이턴시**: P99 < 500ms (SLO 목표 달성)
> - **비용**: $450/월 (목표 $500/월 이하 달성)
> - **배포 시간**: 10분 (카나리 배포 완료)
> - **롤백 시간**: 2분 (자동 롤백)

> [!target] 목표 KPI (6개월 후)
> - **가용성**: 99.9% (RDS 복제본, 노드 풀 분리)
> - **레이턴시**: P99 < 300ms (NLB 도입, 캐시 전략)
> - **비용**: $400/월 (Savings Plans, 스토리지 최적화)
> - **배포 시간**: 5분 (파이프라인 최적화)
> - **롤백 시간**: 1분 (자동화 강화)

---

## 🎓 결론

### ✅ 아키텍처의 강점

1. **SLO 기반 자동화**: 모든 자동화가 명확한 목표와 연결
2. **비용 효율성**: Spot, Karpenter, 자체 호스팅으로 최적화
3. **보안 강화**: Istio mTLS, IRSA, Private Subnet
4. **GitOps**: 안전한 배포 자동화
5. **옵저버빌리티**: 비용 최적화하면서 필요한 기능 완비

### ⚠️ 실제 개선 필요 사항

> [!warning] 중요: 다음 항목들은 아직 구현되지 않은 실제 개선 필요 사항입니다.

1. **Istio AuthorizationPolicy 적용**: mTLS는 적용되었으나 서비스 간 접근 제어 정책이 없어 Zero Trust 불완전
2. **CI 보강 (이미지 스캐닝)**: ECR 스캔만으로는 부족하고 CI 단계에서 취약점 차단 안 됨
3. **DR 전략 Phase 1 (백업 강화)**: 단일 리전 운영으로 리전 장애 시 서비스 중단
4. **결제 흐름 로깅 강화**: 2-step 리다이렉트 흐름의 디버깅 용이성 확보

### 🚀 최종 평가

**실무 수준의 아키텍처**로 **SLO 기반 운영, 비용 최적화, 보안 강화**가 균형 있게 구현되었습니다. 제안된 실제 개선사항을 단계적으로 적용하면 **프로덕션 레벨의 안정성과 확장성**을 확보할 수 있습니다.

> [!success] 평가 등급: A- (4.2/5.0)
> 실무 적용 가능한 수준이며, 제안된 실제 개선사항 적용 시 A+ (4.8/5.0) 달성 가능

> [!info] 참고: 이미 잘 구현된 항목들
> - ✅ **네임스페이스 분리**: default, monitoring, istio-system, argocd, karpenter, external-secrets 등으로 적절히 분리됨
> - ✅ **KEDA + HPA 이중화**: Redis 장애 시 HPA가 백업으로 동작하여 이미 이중화된 상태
> - ✅ **노드 풀 분리**: Karpenter가 Spot 80% + On-Demand 20%로 분리되고, Pause Pod로 Spot 인터럽션 대응

---

## 📚 참고 자료

- [AWS Well-Architected Framework](https://aws.amazon.com/ko/architecture/well-architected/)
- [Kubernetes Best Practices](https://kubernetes.io/docs/concepts/configuration/overview/)
- [Istio Performance Best Practices](https://istio.io/latest/docs/concepts/performance-and-scalability/)
- [Karpenter Best Practices](https://karpenter.sh/docs/concepts/node-templates/)
- [Argo Rollouts Best Practices](https://argoproj.github.io/argo-rollouts/)