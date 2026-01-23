---
title: Red Hat Summit 2026 Korea - 세션별 Q&A 정리
tags:
  - redhat
  - summit
  - ansible
  - aap
  - eda
  - openshift
  - vmware
  - lightspeed
  - ai
  - vllm
  - rhel10
  - pqc
  - kasten
  - dynatrace
date: 2026-01-22
category: 교육/컨퍼런스
status: 완성
priority: 높음
source: NotebookLM 기반 발표자료 분석
---

https://notebooklm.google.com/notebook/ac5f4eea-00a1-46cb-99ee-1f0bbd726fb4
# 🎯 Red Hat Summit 2026 Korea - 세션별 Q&A 정리

## 📑 목차
- [[#클라우드 엔지니어 핵심 역량 요약|클라우드 엔지니어 핵심 역량 요약]] ⭐
- [[#Track B-4: 가상화를 위한 AAP|Track B-4: 가상화를 위한 AAP]]
- [[#Track B-5: 지능형 자동화|Track B-5: 지능형 자동화]]
- [[#키노트 및 AI 관련|키노트 및 AI 관련]]
- [[#추가 질문 (Follow-up)|추가 질문]]
- [[#심화 Q&A (NotebookLM 기반)|심화 Q&A (Q21-Q54)]]

---

> [!tip] 클라우드 엔지니어 학습 가이드
> - ⭐ **필수**: 현업에서 바로 쓰이는 핵심 개념 (18개)
> - 표시 없음: 알면 좋지만 나중에 봐도 되는 내용
> - 양자암호/AI모델 세부사항은 참고 수준으로 스킵 가능

---

## 클라우드 엔지니어 핵심 역량 요약

> [!abstract] 핵심 메시지
> 클라우드 엔지니어는 단순히 인프라를 '운영'하는 것을 넘어, **AI, 보안, 자동화** 기술을 결합하여 비즈니스 가치를 창출하는 플랫폼을 '설계'하는 역할로 진화해야 합니다.

### 1. AI 인프라 구축 및 최적화

클라우드 엔지니어는 이제 LLM을 효율적으로 서빙하고 비용을 절감하는 아키텍처를 이해해야 합니다.

| 핵심 기술 | 설명 | 실무 적용 |
|-----------|------|-----------|
| **PagedAttention** | OS 가상 메모리 페이징을 차용한 KV 캐시 관리 | vLLM 배포 시 기본 적용 |
| **Continuous Batching** | GPU 유휴 시간 최소화 | 추론 서버 설정 최적화 |
| **FP8 양자화** | 모델 크기 50%↓, 정확도 99.5% 유지 | 비용 절감 필수 |

**플랫폼 선택 기준**:
```
단일 서버/엣지 → RHEL AI
클러스터/하이브리드 → OpenShift AI
```

> [!example] 실무 보강: vLLM 배포 예시
> ```bash
> # OpenShift에서 vLLM 서빙 (기본 설정)
> oc new-app --name=llm-server \
>   --image=quay.io/redhat-ai/vllm:latest \
>   -e MODEL_NAME=meta-llama/Llama-3-8B \
>   -e TENSOR_PARALLEL_SIZE=2 \
>   -e MAX_MODEL_LEN=4096
> ```

---

### 2. 가상화의 현대화

VMware 종속성 탈피와 클라우드 네이티브 전환이 가속화되고 있습니다.

| 기술 | 역할 | 핵심 가치 |
|------|------|-----------|
| **OpenShift Virtualization** | VM + 컨테이너 통합 관리 | 단일 플랫폼 운영 |
| **MTV** | VMware → OpenShift 마이그레이션 | 자동화된 전환 |
| **RHEL Image Mode** | OS를 컨테이너처럼 관리 | GitOps 기반 OS 관리 |

> [!example] 실무 보강: MTV 마이그레이션 흐름
> ```
> 1. VMware 환경 연결 (vCenter 크리덴셜)
> 2. 이관 대상 VM 선택 및 분석
> 3. 네트워크/스토리지 매핑 설정
> 4. 마이그레이션 플랜 생성 및 실행
> 5. 검증 후 컷오버
> ```
>
> **주의**: Cold Migration(VM 중지) vs Warm Migration(다운타임 최소화) 선택 필요

---

### 3. 지능형 자동화

단순 반복 자동화를 넘어 이벤트 기반 자동 대응이 핵심입니다.

```
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│  모니터링    │ → │     EDA      │ → │   Ansible    │
│ (이벤트발생) │    │ (Rulebook)   │    │ (자동조치)   │
└──────────────┘    └──────────────┘    └──────────────┘
```

**역할 분담**:

| 도구 | 역할 | 예시 |
|------|------|------|
| **Terraform** | 인프라 프로비저닝 (Day 0) | VPC, VM, K8s 클러스터 생성 |
| **Ansible** | 구성 관리 (Day 1-2) | 패키지 설치, 설정 변경, 패치 |
| **EDA** | 이벤트 기반 자동 대응 | 장애 감지 → 자동 복구 |

> [!example] 실무 보강: Terraform + Ansible 통합
> ```hcl
> # Terraform에서 Ansible 호출
> resource "null_resource" "ansible_provisioner" {
>   provisioner "local-exec" {
>     command = "ansible-playbook -i ${aws_instance.web.public_ip}, setup.yml"
>   }
>   depends_on = [aws_instance.web]
> }
> ```
>
> **또는** AAP의 Terraform Provider 활용:
> ```hcl
> provider "ansible" {
>   host = "https://aap.example.com"
> }
> resource "ansible_job" "deploy" {
>   job_template_id = 42
> }
> ```

---

### 4. 옵저버빌리티(Observability)

| 구분 | 모니터링 | 옵저버빌리티 |
|------|----------|--------------|
| **범위** | 사전 정의된 지표 | Unknown Unknowns 포함 |
| **방식** | 대시보드 감시 | 인과관계 추적 |
| **대응** | 알람 → 수동 조치 | RCA → 자동 권고 |

**3 Pillars of Observability**:

| Pillar | 도구 예시 | 용도 |
|--------|-----------|------|
| **Metrics** | Prometheus, Dynatrace | 수치 기반 상태 파악 |
| **Logs** | ELK, Loki | 이벤트 상세 분석 |
| **Traces** | Jaeger, Tempo | 분산 시스템 흐름 추적 |

> [!example] 실무 보강: OpenTelemetry 통합
> ```yaml
> # OTel Collector 설정 (K8s)
> apiVersion: opentelemetry.io/v1alpha1
> kind: OpenTelemetryCollector
> metadata:
>   name: otel
> spec:
>   mode: daemonset
>   config: |
>     receivers:
>       otlp:
>         protocols:
>           grpc:
>           http:
>     exporters:
>       otlp:
>         endpoint: "dynatrace-collector:4317"
>     service:
>       pipelines:
>         traces:
>           receivers: [otlp]
>           exporters: [otlp]
> ```

---

### 5. 차세대 보안

#### 양자 내성 암호(PQC) 전환 로드맵

```
┌─────────────┐   ┌─────────────┐   ┌─────────────┐   ┌─────────────┐
│ 1. 인벤토리 │ → │ 2. 우선순위 │ → │ 3. 하이브리 │ → │ 4. 완전전환 │
│ (암호자산   │   │ (장기기밀   │   │ 드 모드     │   │ (PQC Only) │
│  파악)      │   │  데이터)    │   │ (기존+PQC)  │   │             │
└─────────────┘   └─────────────┘   └─────────────┘   └─────────────┘
     현재              2025-26           2027-28          2030+
```

#### 제로 트러스트 구현 단계

| 단계 | 적용 대상 | 기술 |
|------|-----------|------|
| **1단계** | 사용자 인증 | SSO, MFA, IAM |
| **2단계** | 네트워크 세그먼트 | 마이크로세그멘테이션 |
| **3단계** | 워크로드 ID | SPIFFE/SPIRE, mTLS |
| **4단계** | 데이터 보호 | 기밀 컴퓨팅, 암호화 |

> [!example] 실무 보강: SPIRE 배포 (K8s)
> ```bash
> # SPIRE 서버 + 에이전트 설치
> helm repo add spiffe https://spiffe.github.io/helm-charts
> helm install spire spiffe/spire \
>   --set server.trustDomain=example.org
>
> # 워크로드 등록
> kubectl exec spire-server-0 -- spire-server entry create \
>   -spiffeID spiffe://example.org/app \
>   -parentID spiffe://example.org/agent \
>   -selector k8s:pod-label:app=myapp
> ```

---

### 6. 플랫폼 엔지니어링 도구

| 도구 | 용도 | 언제 사용? |
|------|------|-----------|
| **Connectivity Link** | 멀티클러스터 API 게이트웨이 | 레거시 ↔ K8s 연결 |
| **ADS** | 소프트웨어 공급망 보안 | CI/CD 보안 강화 |
| **OpenShift Lightspeed** | K8s 운영 AI 비서 | 트러블슈팅 가속화 |

> [!example] 실무 시나리오
>
> **Connectivity Link 활용**:
> - 온프렘 Oracle DB ↔ OpenShift 앱 연결
> - Rate Limiting으로 트래픽 보호
> - DR 시 자동 페일오버 정책
>
> **ADS 활용**:
> - PR 머지 전 취약점 스캔 자동화
> - 컨테이너 이미지 서명 강제
> - SBOM 자동 생성 및 저장

---

### 학습 우선순위 체크리스트

> [!success] 지금 당장 알아야 할 것
> - [ ] EDA Rulebook 작성법
> - [ ] VMware → OpenShift 마이그레이션 절차
> - [ ] Kubernetes 백업/복구 (Kasten or Velero)
> - [ ] Terraform + Ansible 통합 패턴

> [!warning] 6개월 내 준비할 것
> - [ ] vLLM 기반 추론 서버 배포
> - [ ] OpenTelemetry 기반 옵저버빌리티 구축
> - [ ] SPIFFE/SPIRE 기반 제로 트러스트

> [!info] 트렌드로 지켜볼 것
> - [ ] 양자 내성 암호(PQC) 전환 동향
> - [ ] 기밀 컴퓨팅 (SEV-SNP, TDX)
> - [ ] AI 모델 최적화 기법 (Speculative Decoding 등)

---

## Track B-4: 가상화를 위한 AAP

### Q1. VMware에서 OpenShift Virtualization으로 마이그레이션 시 AAP 역할은? ⭐

AAP는 마이그레이션의 **전체 오케스트레이션**을 담당합니다.

| 단계 | 역할 | 상세 |
|------|------|------|
| **Day 0 (발견)** | 인벤토리 수집 | 기존 VMware 환경에 접속하여 이관 대상 VM 정보 분석 |
| **Day 1 (이관)** | 실제 마이그레이션 | MTV(Migration Toolkit for Virtualization)와 연동하여 VM 이관 |
| **Day 2 (사후 처리)** | 정합성 맞춤 | 변경된 VM 정보를 ITSM/모니터링 시스템에 업데이트 |

---

### Q2. 가상화 환경에서 AAP로 자동화할 수 있는 Day 2 운영 작업은? ⭐

| 작업 유형 | 내용 |
|----------|------|
| **전원 관리** | 하이퍼바이저 점검 전후 VM 일괄 정지/기동, 호스트 간 이동 |
| **운영 가시성** | CPU/메모리 사용량, 패키지 정보 수집 → ITSM/CMDB 현행화 |
| **설정 변경** | NTP/Timezone 설정, OS 패치, 애플리케이션 배포(CI/CD) |
| **스냅샷 관리** | 작업 전후 VM 스냅샷 생성 및 관리 |
| **자원 관리** | 디스크 용량 부족 시 자동 증설 + 티켓 처리 |

---

### Q3. vSphere 환경과 AAP 연동 방법 및 지원 모듈은?

**연동 방법**:
- VMware 관리 콘솔(GUI) 없이 **컬렉션/모듈로 vSphere API와 직접 통신**

**지원 현황**:
- VMware 컬렉션: 최근 90일간 **3,400만 건** 이상 사용
- 지원 하이퍼바이저: VMware, Nutanix, Hyper-V, KVM, OpenStack 등

---

### Q4. VM 프로비저닝 자동화 워크플로우 예시는? ⭐

> [!success] 기존 2~3주 → **수 분**으로 단축

```
┌─────────────┐   ┌─────────────┐   ┌─────────────┐
│ 1. 사용자   │ → │ 2. 인프라   │ → │ 3. 네트워크 │
│    요청     │   │ 프로비저닝  │   │ /스토리지   │
│ (사양 입력) │   │ (VM 생성)   │   │ (IP, DNS)   │
└─────────────┘   └─────────────┘   └─────────────┘
                                           ↓
┌─────────────┐   ┌─────────────┐   ┌─────────────┐
│ 6. 서비스   │ ← │ 5. 보안     │ ← │ 4. 미들웨어 │
│    오픈     │   │    점검     │   │ 설치(WAS등) │
│ (L4/DNS)    │   │             │   │             │
└─────────────┘   └─────────────┘   └─────────────┘
```

**핵심**: 팀 간 소통 없이 워크플로우로 자동 연결

---

### Q5. 하이브리드(VMware + OpenShift) 환경 통합 관리 방법은? ⭐

| 기능 | 설명 |
|------|------|
| **단일 제어** | VMware/OpenShift 모두 지원하는 모듈로 단일 플랫폼에서 관리 |
| **서베이(Survey)** | 사용자에게 표준화된 카탈로그 제공 → 일관된 형상의 VM 생성 보장 |

---

## Track B-5: 지능형 자동화

### Q6. EDA + Lightspeed 연계 자가치유(Self-healing) 데모 시나리오 ⭐

```
┌─────────────────────────────────────────────────────────────────┐
│  1. 장애 발생: Node 1의 HTTPD 서비스 장애                        │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  2. 관찰 (EDA): Kafka 플러그인으로 장애 이벤트 수집              │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  3. 평가 및 트리거: Rulebook 분석 → Controller에 워크플로우 요청 │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  4. 분석 (AI): Red Hat AI Platform이 로그 분석 → 해결 방법 판단  │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  5. 티켓 생성: ITSM에 장애 티켓 생성 + 분석 데이터 동기화        │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  6. 해결책 생성 (Lightspeed): "이 문제 해결하는 플레이북 만들어줘"│
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  7. 복구: 생성된 플레이북 실행 → 서비스 복구                     │
└─────────────────────────────────────────────────────────────────┘
```

---

### Q7. Dynatrace/ServiceNow와 EDA 연동 아키텍처는? ⭐

```
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│  Dynatrace   │ → │     EDA      │ → │  ServiceNow  │
│  (관찰)      │    │   (판단)     │    │   (기록)     │
│ 문제 감지    │    │ Rulebook     │    │ 티켓 생성    │
└──────────────┘    └──────────────┘    └──────────────┘
                           ↓
                    ┌──────────────┐
                    │   Ansible    │
                    │   (조치)     │
                    │ 복구 실행    │
                    └──────────────┘
                           ↓
              정상 상태 감지 → 티켓 자동 종료
```

---

### Q8. 실제 고객 사례에서 EDA 적용 범위는?

| 기업 | 환경 | 적용 범위 | 성과 |
|------|------|-----------|------|
| **Bancolombia** | 온프레미스 + 클라우드 하이브리드 | Self-healing 인프라 | MTTR 90%↓, 자동 해결 40%↑ |
| **스페인 보험사** | Dynatrace + EDA | AIOps 환경 | Downtime 50%↓ |

---

### Q9. ITSM 티켓 자동 생성 및 종료 워크플로우 구현 방법은? ⭐

| 단계 | 동작 |
|------|------|
| **생성** | 이벤트 발생 → EDA → Playbook → ServiceNow 모듈로 티켓 생성 |
| **조치** | 리소스 증설 등 복구 작업 수행 |
| **검증** | 모니터링 시스템(Alertmanager)이 문제 해결 감지 |
| **종료** | 해제 이벤트 → EDA → Playbook → 티켓 'Resolved/Closed' 상태 변경 |

---

### Q10. Red Hat Insights와 EDA 연동 자동화 시나리오는? ⭐

| 시나리오 | 흐름 |
|----------|------|
| **CVE 대응** | 보안 취약점 발견 → EDA → 패치 Playbook 자동 실행 |
| **구성 드리프트 교정** | 표준 설정 벗어남 감지 → 원래대로 롤백 |
| **리소스 최적화** | 과다 사용 감지 → 인스턴스 크기 조정 / 불필요 리소스 종료 |

---

## 키노트 및 AI 관련

### Q11. Red Hat AI 전략에서 Ansible Lightspeed의 포지션은?

> **코딩 어시스턴트(Coding Assistant)** 역할
> - 자연어 → Playbook 코드 생성
> - 자동화 진입 장벽 낮춤
> - 기술 격차(Skills Gap) 해소

---

### Q12. Lightspeed가 레드햇 검증 모범사례로 학습되었다는 의미는?

| 범용 AI (ChatGPT 등) | Lightspeed |
|---------------------|------------|
| 일반적인 웹 데이터로 학습 | 레드햇이 검증한 자동화 Best Practices로 학습 |
| 품질 불균일 | 엔터프라이즈급 품질 보장 |
| 추가 검증 필요 | 바로 사용 가능 수준 |

---

### Q13. AI 환각(Hallucination) 방지를 위한 Lightspeed 설계 철학은?

> [!warning] 핵심 철학
> **"설명 가능한 신뢰 체계"** + **Human-in-the-loop**

1. AI가 코드 생성
2. 운영자가 **검토(Review)**
3. 출처/근거 확인
4. **승인 버튼** 눌러야 적용

---

### Q14. 자연어로 플레이북 생성 시 지원하는 프롬프트 예시는?

| 용도 | 프롬프트 예시 | 환경 |
|------|---------------|------|
| 장애 해결 | "이 에러를 어떻게 해결할 수 있어?" | CLI |
| 서비스 설치 | "Install HTTPD service." | VS Code |
| 구성 변경 | "Create a playbook to update NTP settings." | VS Code |

---

### Q15. RHEL 10 Lightspeed vs AAP Lightspeed 차이는?

| 구분 | RHEL 10 Lightspeed | AAP Lightspeed |
|------|-------------------|----------------|
| **환경** | CLI (터미널) | VS Code 에디터 |
| **용도** | 리눅스 운영/트러블슈팅 | Playbook 코드 생성 |
| **예시** | "systemctl 에러 원인 뭐야?" | "Apache 설치하는 플레이북 만들어줘" |
| **역할** | 운영자 멘토 | 코딩 파트너 |

---

## 추가 질문 (Follow-up)

### Q16. Bancolombia 90% MTTR 단축의 구체적 자동화 항목은?

- 특정 작업이 아닌 **전체 프로세스 자동화** 결과
- 장애 감지 → 티켓 생성 → 조치 → 종료까지 End-to-End
- 수동 처리하던 반복적 문제들을 워크플로우로 전환

---

### Q17. 자동 해결 비율 40% 측정 기준은?

```
자동 해결 비율 = (자동 처리된 인시던트 / 전체 인시던트) × 100
```

- 기존: 운영자가 수동으로 해결
- EDA 도입 후: 사람 개입 없이 티켓 자동 종료
- 이 비율이 40% 이상 증가

---

### Q18. "이 에러를 어떻게 해결할 수 있어?" 데모 재현 방법은?

```bash
# 1. 실패하는 명령어 실행
$ systemctl start httpd
# → 에러 발생

# 2. Lightspeed CLI로 질문
$ genie "How to fix this error?"

# 3. 응답 예시
"30번째 줄에 오타가 있습니다.
/etc/httpd/conf/httpd.conf 파일을 열어 수정하세요."
```

---

### Q19. Lightspeed CLI vs VS Code 확장 차이는?

| 구분 | CLI (RHEL) | VS Code 확장 (AAP) |
|------|-----------|-------------------|
| **목적** | 운영/트러블슈팅 | 자동화 개발 |
| **입력** | 터미널에서 자연어 질문 | 주석으로 요청 작성 |
| **출력** | 해결 가이드 (텍스트) | Ansible 코드 (YAML) |

---

### Q20. 워크플로우 잡 템플릿에서 조건부 분기 설정 방법은?

**비주얼 디자이너** 사용:

```
                    ┌─────────────┐
                    │  작업 A     │
                    └─────────────┘
                     ↙️         ↘️
            (성공/녹색)      (실패/빨간)
                 ↓               ↓
        ┌─────────────┐  ┌─────────────┐
        │  작업 B     │  │  롤백/알림  │
        │  (다음 단계) │  │  (에러 처리) │
        └─────────────┘  └─────────────┘
```

---

---

## 심화 Q&A (NotebookLM 기반)

> [!info] 출처
> Red Hat Summit 2026 Korea 발표 자료를 NotebookLM으로 분석한 결과입니다.
> 자료에 없는 항목은 일반 기술 문서 기반으로 보충했습니다.

### 키노트 및 플랫폼 전략

#### Q21. vLLM의 PagedAttention이 메모리 효율을 높이는 원리는?

vLLM은 리눅스 OS의 **페이징(Paging)** 기법을 차용하여, LLM 추론 시 생성되는 **KV 캐시(Key-Value Cache)** 데이터를 논리적인 메모리 블록으로 나누어 관리합니다. 이를 통해 메모리 단편화(Fragmentation) 문제를 해결하고, GPU 메모리 공간의 낭비를 줄여 효율성을 높입니다.

---

#### Q22. RHEL Image Mode의 롤백 방식은? ⭐

RHEL 이미지 모드는 운영체제를 **컨테이너 이미지 레이어 단위**로 관리하기 때문에, 업데이트가 실패하거나 문제가 발생했을 때 이전 이미지 레이어로 전환하는 방식으로 쉽게 롤백을 수행할 수 있습니다.

---

#### Q23. 오픈소스 AI 모델이 규제 준수에 유리한 이유는?

오픈소스 AI는 **투명성**을 제공하고 특정 벤더의 폐쇄형 AI와 달리 기업이 자체 데이터와 인프라에 대한 **통제권(Sovereignty)**을 가질 수 있어 거버넌스 및 책임 있는 AI(Responsible AI) 구현에 유리합니다.

---

### RHEL 10 심화

#### Q24. RHEL 10에서 Y2K38 문제를 어떻게 해결했나?

RHEL 10은 32비트 아키텍처에서 2038년 1월 19일 이후 시간이 음수로 표현되는 오버플로우 문제(Y2K38)를 해결하여 임베디드 시스템 등에서도 안전하게 사용할 수 있도록 대비했습니다.

---

#### Q25. ML-KEM과 ML-DSA의 차이점은?

| 알고리즘 | 용도 | 설명 |
|----------|------|------|
| **ML-KEM** | 키 교환 (Key Exchange) | 양자 내성 키 캡슐화 메커니즘 |
| **ML-DSA** | 디지털 서명 (Digital Signature) | 인증서 서명 등에 사용 |

---

#### Q26. 기밀 컴퓨팅에서 AMD SEV-SNP와 Intel TDX 차이는?

> [!note] 보충 자료
> 발표 자료에 상세 비교는 없으나, 일반 기술 문서 기반으로 정리합니다.

| 구분 | AMD SEV-SNP | Intel TDX |
|------|-------------|-----------|
| **보호 단위** | VM 단위 (하이퍼바이저로부터 격리) | TD(Trust Domain) 단위 |
| **메모리 암호화** | AES-128 (SME 기반) | AES-128-XTS (TME 기반) |
| **무결성 보장** | SNP로 메모리 무결성 추가 | 기본 내장 |
| **Attestation** | AMD 키 서버 기반 | Intel SGX 인프라 활용 |
| **적용 시점** | EPYC 3세대(Milan)+ | Sapphire Rapids+ |

---

#### Q27. NPU 드라이버 내장의 장점은?

RHEL AI 및 RHEL 10에는 AMD, Intel, NVIDIA 등의 다양한 AI 가속기(NPU 등) 드라이버가 OS 이미지에 미리 포함되어 있어, 사용자가 별도로 커널을 설정하거나 드라이버를 설치하는 복잡한 과정 없이 하드웨어를 **즉시 사용**할 수 있습니다.

---

#### Q28. 리얼타임 커널이 기본 포함된 이유는?

기존에는 별도 애드온으로 구매해야 했던 리얼타임 커널이 RHEL 10부터는 기본 포함되어, **국방(레이더)이나 금융 거래 시스템**과 같이 초저지연(Low Latency)이 필요한 환경을 추가 비용 없이 구축할 수 있도록 지원하기 위함입니다.

---

### 다이나트레이스 Observability

#### Q29. Smartscape Topology가 Pod 간 관계를 매핑하는 방식은? ⭐

다이나트레이스의 Smartscape Topology는 사용자가 별도로 설정하지 않아도 **OneAgent가 수집한 데이터**를 기반으로 데이터 간의 연결 관계와 선후 관계(인과 관계)를 자동으로 추적하고 시각화하여 시스템의 현재 상황을 매핑합니다.

---

#### Q30. Davis AI가 Unknown Unknowns를 탐지하는 방법은? ⭐

기존 모니터링이 사전에 정의된 규칙(예상된 문제)만 확인하는 것과 달리, Davis AI는 **데이터의 맥락(Context)과 상관관계**를 분석하여 사용자가 미처 알지 못했던 문제(Unknown Unknowns)의 원인을 스스로 추적하고 규명합니다.

---

#### Q31. OneAgent와 OpenTelemetry는 어떻게 공존하나?

> [!note] 보충 자료
> 발표 자료에 없으나, 다이나트레이스 공식 문서 기반으로 정리합니다.

| 방식 | 설명 |
|------|------|
| **OTLP 수집** | OpenTelemetry Collector → Dynatrace로 메트릭/트레이스 전송 |
| **자동 연계** | OneAgent가 수집한 데이터와 OTel 데이터를 Smartscape에서 통합 |
| **W3C Trace Context** | 분산 트레이싱 표준 준수로 상호 운용성 확보 |
| **하이브리드 모드** | 일부는 OneAgent, 일부는 OTel SDK로 계측 가능 |

---

### Red Hat AI

#### Q32. InstructLab이 기존 RLHF보다 효율적인 이유는?

InstructLab은 모델에 지식과 기술(Skill)을 쉽게 추가할 수 있는 도구로, **RAG(검색 증강 생성)**와 함께 사용할 경우 모델 전체를 재학습시키는 것보다 훨씬 적은 비용으로 도메인 특화 모델을 만들 수 있으며 높은 성능과 정확도를 제공합니다.

---

#### Q33. Llama Stack과 LangChain의 차이점은?

Llama Stack은 **추론, 벡터 검색, 평가 등의 기능을 단일 API**로 제공하여 에이전트 구축을 돕습니다.

> [!note] 보충 비교

| 구분 | Llama Stack | LangChain |
|------|-------------|-----------|
| **주체** | Meta 공식 | 커뮤니티/LangChain Inc. |
| **목적** | Llama 모델 최적화 서빙 | 다양한 LLM 오케스트레이션 |
| **API 통일성** | 단일 표준 API | 추상화 레이어 (다양한 백엔드) |
| **에이전트** | 네이티브 지원 | LangGraph 등 별도 모듈 |

---

#### Q34. MCP(Model Context Protocol)란 무엇인가?

MCP는 AI 애플리케이션의 **'USB 허브'**와 같은 역할을 하는 프로토콜로, AI 모델이 기존의 다양한 IT 시스템 및 데이터 소스와 **표준화된 방식**으로 상호 작용하고 통합될 수 있도록 지원합니다.

---

#### Q35. OpenShift AI와 RHEL AI 중 선택 기준은? ⭐

| 구분 | RHEL AI | OpenShift AI |
|------|---------|--------------|
| **환경** | 단일 서버, 엣지 | 쿠버네티스 클러스터 |
| **용도** | LLM 개발/서빙 (경량) | 대규모 분산 학습, MLOps |
| **스케일** | 수직 확장 | 수평 확장 |
| **적합 대상** | PoC, 소규모 팀 | 엔터프라이즈 프로덕션 |

---

### 양자 보안

#### Q36. HNDL 공격이란 무엇이고 대응 방법은? ⭐

**HNDL(Harvest Now, Decrypt Later)**은 해커들이 현재의 암호화된 데이터를 수집해 두었다가, 향후 양자 컴퓨터가 상용화되는 시점(Q-Day)에 복호화하여 정보를 탈취하려는 공격 형태입니다.

**대응**: 지금부터 **양자 내성 암호(PQC)**로 전환하여 데이터를 보호해야 합니다.

---

#### Q37. 하이브리드 암호화 전환 시 성능 오버헤드는?

> [!note] 보충 자료
> 발표 자료에 수치는 없으나, NIST/업계 벤치마크 기반으로 정리합니다.

| 항목 | 영향 |
|------|------|
| **TLS 핸드셰이크** | 약 10-30% 지연 증가 (ML-KEM 기준) |
| **키 크기** | RSA 2048 → ML-KEM-768: 키 크기 약 2배 |
| **서명 크기** | ECDSA → ML-DSA: 서명 크기 약 10배 |
| **CPU 사용량** | 격자 기반 연산으로 소폭 증가 |

> 하이브리드 모드(기존 + PQC 병행)는 오버헤드가 더 크지만, 전환기 호환성 확보에 필수

---

#### Q38. SPIFFE/SPIRE 기반 워크로드 아이덴티티의 장점은? ⭐

네트워크 내부의 워크로드도 신뢰하지 않는 **제로 트러스트 원칙**에 따라, 각 워크로드에 검증 가능한 ID(SPIFFE ID)를 자동으로 발급하고 관리합니다. 이를 통해 정적 시크릿(Static Secret) 사용을 최소화하고 안전한 통신(mTLS 등)을 구현할 수 있습니다.

---

#### Q39. Q-Day 전에 PQC로 전환해야 할 데이터 우선순위는?

| 우선순위 | 데이터 유형 | 이유 |
|----------|-------------|------|
| **1순위** | 장기 기밀 데이터 | 국가 기밀, 의료 기록, 금융 데이터 |
| **2순위** | 장기 유효 인증서/키 | CA 루트 인증서, 코드 서명 키 |
| **3순위** | 규제 대상 데이터 | GDPR, HIPAA 적용 데이터 |

---

### vLLM 추론 최적화

#### Q40. Continuous Batching과 Static Batching의 차이는?

| 구분 | Static Batching | Continuous Batching |
|------|-----------------|---------------------|
| **동작** | 배치 내 모든 요청 완료까지 대기 | 완료된 슬롯에 새 요청 즉시 투입 |
| **GPU 효율** | 유휴 시간 발생 | 가동률 극대화 |
| **지연시간** | 긴 요청에 의해 전체 지연 | 개별 요청 독립 처리 |

---

#### Q41. INT8/FP8 양자화가 정확도에 미치는 영향은?

일반적인 양자화는 모델 크기를 줄이는 대신 정확도가 떨어질 수 있으나, vLLM의 **LLM Compressor** 등을 활용하여 FP8 등으로 양자화할 경우 모델 크기를 절반 이하로 줄이면서도 **정확도를 99.5% 수준**으로 유지할 수 있습니다.

---

#### Q42. Speculative Decoding이란?

> [!note] 보충 자료
> 발표 자료에 없으나, vLLM 공식 문서 기반으로 정리합니다.

```
┌─────────────────────────────────────────────────────────┐
│  1. Draft 모델 (소형)이 N개 토큰을 빠르게 예측           │
└─────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────┐
│  2. Target 모델 (대형)이 예측 토큰들을 한 번에 검증      │
└─────────────────────────────────────────────────────────┘
                         ↓
┌─────────────────────────────────────────────────────────┐
│  3. 일치하는 토큰은 채택, 불일치 시점부터 재생성         │
└─────────────────────────────────────────────────────────┘
```

**효과**: 대형 모델의 forward pass 횟수를 줄여 **추론 속도 2-3배 향상**

---

#### Q43. 멀티 GPU에서 Tensor Parallelism 병목 최소화 방법은?

파이토치(PyTorch) 기본 설정만으로는 병목이 발생할 수 있어, vLLM 등은 **All-Reduce 연산**과 같은 통신 과정을 최적화한 **커스텀 커널(Custom CUDA Kernels)**을 사용하여 GPU 간 데이터 취합 속도를 높이고 병목을 최소화합니다.

---

### OpenShift 애드온

#### Q44. Connectivity Link가 기존 Ingress Controller와 다른 점은? ⭐

| 구분 | Ingress Controller | Connectivity Link |
|------|-------------------|-------------------|
| **범위** | 단일 클러스터 내부 | 멀티클러스터, 하이브리드 |
| **연결 방향** | East-West 중심 | North-South (레거시 포함) |
| **추가 기능** | 기본 라우팅 | Rate Limiting, QoS, DR 정책 |

---

#### Q45. ADS가 SBOM을 생성하는 방식은?

**ADS(Advanced Developer Suite)**는 안전한 소프트웨어 공급망(Trusted Software Supply Chain) 구축을 위해 빌드 및 배포 파이프라인 단계에서 **아티팩트 서명, 취약점 분석, 정책 검사** 등을 자동화합니다.

> SBOM은 빌드 시점에 의존성을 분석하여 CycloneDX/SPDX 형식으로 자동 생성

---

#### Q46. Zero Trust Workload Identity 구현 원리는? ⭐

네트워크 내부에 있더라도 어떤 워크로드도 기본적으로 신뢰하지 않습니다. **SPIFFE/SPIRE**를 통해 각 워크로드에 고유한 신분증(ID)을 부여하고, 작업을 수행할 때마다 이 신분증을 검증하여 권한을 부여하는 방식입니다.

---

### Veeam/Kasten 백업

#### Q47. Kasten K10의 애플리케이션 정합성 보장 방식은? ⭐

단순한 볼륨 복제가 아니라, 클러스터 전체와 데이터베이스가 포함된 애플리케이션의 **정합성(Application Consistency)**을 유지하는 형태로 백업을 수행하여, 복구 시 데이터 손상 없이 서비스가 정상 작동하도록 보장합니다.

---

#### Q48. VMware VM을 OpenShift PV로 변환하는 과정은? ⭐

Veeam Kasten의 마이그레이션 기능을 활용하며, **Transform Set** 기능을 통해 레거시 환경(VMware 등)의 볼륨 및 설정 정보를 OpenShift 환경에 맞는 정보(PV 등)로 자동으로 변환하여 이관합니다.

---

#### Q49. Immutable Backup 구현 방식은? ⭐

랜섬웨어 대응을 위해 백업 데이터를 **Immutable(불변) 저장소**에 보관하여, 해커나 악의적인 관리자라도 백업된 데이터를 수정하거나 삭제할 수 없도록 보호합니다.

> S3 Object Lock, WORM 스토리지 등 활용

---

### AAP/EDA 심화

#### Q50. AAP에서 HashiCorp Vault 연동 방법은?

> [!note] 보충 자료
> 발표 자료에 없으나, AAP 공식 문서 기반으로 정리합니다.

| 방식 | 설명 |
|------|------|
| **Credential Plugin** | AAP에서 Vault를 External Credential Source로 등록 |
| **Lookup Plugin** | Playbook 내에서 `hashi_vault` lookup으로 시크릿 조회 |
| **EE 포함** | Execution Environment에 hvac 라이브러리 포함 |

```yaml
# Credential Type 설정 예시
injectors:
  extra_vars:
    my_secret: "{{ lookup('hashi_vault', 'secret/data/app') }}"
```

---

#### Q51. 이기종 하이퍼바이저 인벤토리 동기화 방법은? ⭐

Ansible Automation Platform은 VMware, Nutanix, OpenStack 등 다양한 하이퍼바이저의 API와 연동되는 모듈을 통해 각 VM의 상태 정보와 자원 현황을 수집하고, 이를 ITSM이나 CMDB에 자동으로 동기화하여 가시성을 확보합니다.

---

#### Q52. EDA Rulebook에서 복합 이벤트 처리 방식은? ⭐

> [!note] 보충 자료
> 발표 자료에 상세 없으나, EDA 문서 기반으로 정리합니다.

```yaml
# 복합 조건 Rulebook 예시
rules:
  - name: 복합 장애 감지
    condition:
      all:
        - event.alert.severity == "critical"
        - event.alert.count >= 3
        - event.alert.duration > 300  # 5분 이상 지속
    action:
      run_job_template:
        name: emergency-response
```

| 연산자 | 설명 |
|--------|------|
| `all` | 모든 조건 충족 (AND) |
| `any` | 하나 이상 충족 (OR) |
| `not_all` | 모든 조건 미충족 |

---

#### Q53. EDA Controller 고가용성 구성 방법은?

> [!note] 보충 자료
> 발표 자료에 없으나, AAP 2.4+ 아키텍처 기반으로 정리합니다.

| 구성 요소 | HA 전략 |
|-----------|---------|
| **EDA Controller** | 다중 인스턴스 + 로드밸런서 |
| **이벤트 소스** | Kafka 클러스터 (파티션 기반 분산) |
| **Rulebook 실행** | 여러 Worker에서 병렬 처리 |
| **상태 저장** | PostgreSQL HA (Patroni 등) |

> 이벤트 유실 방지: Kafka Consumer Group의 offset 관리로 재시도 보장

---

#### Q54. Insights 취약점 오탐 필터링 방법은?

> [!note] 보충 자료
> 발표 자료에 없으나, Red Hat Insights 문서 기반으로 정리합니다.

| 방법 | 설명 |
|------|------|
| **Disable Rule** | 특정 규칙을 시스템/그룹 단위로 비활성화 |
| **Risk Adjustment** | 환경에 맞게 위험도 재평가 |
| **Playbook 커스터마이징** | 자동 생성된 Playbook을 수정하여 예외 처리 |
| **Tagging** | 시스템 태그로 그룹화하여 정책 차등 적용 |

---

## 📚 참고 자료

### 세션 목록

| 트랙      | 세션명                                              |
| ------- | ------------------------------------------------ |
| A-1     | 차세대 플랫폼: 레드햇의 하이브리드 클라우드 전략                      |
| A-2     | 다이나트레이스 OpenShift K8s 환경을 위한 AI 기반 Observability |
| A-3     | Red Hat AI 로드맵: Red Hat AI 비전과 전략                |
| A-4     | 다가오는 양자 컴퓨팅 시대를 위한 플랫폼 보호 전략                     |
| A-5     | Red Hat AI Inference Server: vLLM 기반 LLM 서빙      |
| B-1     | Red Hat OpenShift 파헤치기: OpenShift를 빛내는 조연들       |
| B-3     | Veeam: 컨테이너 백업 마이그레이션                            |
| **B-4** | **자동화 가속화: 가상화를 위한 Ansible Automation Platform** |
| **B-5** | **지능형 자동화로 운영 효율성 달성**                           |

### 영상 링크

- [YouTube 플레이리스트](https://www.youtube.com/watch?v=a-A3klpGpDE&list=PLvPkYsISg2ZNL8gHbOcoYTKqgUxLHriFI)

### 관련 문서

- [[Ansible_EDA_이벤트기반_자동화]]
- [[Ansible Automation Platform 구성]]
- [[OpenShift Virtualization]]
