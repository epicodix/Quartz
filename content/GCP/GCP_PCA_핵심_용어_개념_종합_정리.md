---
title: GCP PCA 핵심 용어 개념 종합 정리
summary: 이 문서는 GCP Professional Cloud Architect 시험 준비를 위해 필요한 주요 용어와 개념을 정리한 것입니다.
tags:
- 미분류
category: 기타
difficulty: 중급
estimated_time: 30분
created: '2025-10-31'
updated: '2025-11-08'
---

### GCP PCA 핵심 용어 및 개념 종합 정리

이 문서는 GCP Professional Cloud Architect 시험 준비를 위해 필요한 주요 용어와 개념을 정리한 것입니다.

---

#### **1. 클라우드 솔루션 아키텍처 설계 및 계획 (Designing and Planning a Cloud Solution Architecture)**

*   **비즈니스 요구사항:**
    *   **고려사항:** 비용 최적화, 애플리케이션 설계, 데이터 이동, 규정 준수, 관측 가능성(Observability).
    *   **KPI (Key Performance Indicators):** 핵심 성과 지표. 구체적이고 측정 가능하며, 시간 범위가 명확해야 함 (SMART 원칙).
    *   **SLO (Service Level Objectives):** KPI를 기반으로 서비스가 달성해야 할 목표.
*   **기술 요구사항:**
    *   **고려사항:** 고가용성, 장애 조치, 클라우드 리소스의 탄력성(할당량/제한), 확장성, 성능, 지연 시간.
    *   **Custom Machine Type:** Compute Engine에서 vCPU와 RAM을 정확하게 지정하여 비용을 최적화하는 맞춤형 머신 유형.
    *   **Preemptible VM (선점형 VM):** 단기 실행, 내결함성 워크로드에 비용 효율적이지만, 로컬에 영구 데이터를 저장하는 데는 부적합.
*   **네트워크, 스토리지 및 컴퓨팅 리소스 설계:**
    *   **VPC Network (Custom Mode):** 서브넷 및 IP 주소 범위에 대한 완전한 제어권을 제공하여 온프레미스 네트워크와의 IP 충돌 방지에 유리.
    *   **RFC 1918 Class B:** 사설 IP 주소 범위 중 `172.16.x.x` 대역.
    *   **VPC Network Peering:** 서로 다른 조직/프로젝트의 VPC 네트워크 간 비공개 통신. 서브넷 IP 범위가 겹치지 않아야 함.
    *   **Shared VPC:** **동일 조직 내에서** 여러 프로젝트가 하나의 호스트 VPC를 공유.
    *   **Global External Application Load Balancer:** 웹 기반 애플리케이션의 L7 부하 분산. URL 기반 라우팅, 지리적 근접성 기반 트래픽 분산.
    *   **External Passthrough Network Load Balancer:** L4 부하 분산. 클라이언트 IP 보존이 필요한 TCP/UDP 트래픽에 적합.
    *   **Cloud Bigtable:** 페타바이트 규모의 대용량, 높은 처리량, 일관된 낮은 지연 시간(single-digit ms)을 제공하는 NoSQL 데이터베이스 (IoT, 분석 데이터).
    *   **Firestore:** 모바일/웹 애플리케이션을 위한 문서 기반 NoSQL 데이터베이스.
    *   **StatefulSet (Kubernetes):** 안정적인 네트워크 식별자와 영구 스토리지(PersistentVolumeClaim)가 필요한 상태 저장(Stateful) 애플리케이션 관리에 사용.
    *   **Deployment (Kubernetes):** 주로 상태 비저장(Stateless) 애플리케이션 관리에 사용.
*   **마이그레이션 계획:**
    *   **Lift and Shift (리프트 앤 시프트):** 기존 VM 기반 애플리케이션을 클라우드 VM으로 최소한의 변경으로 이동.
    *   **Migrate for Anthos (Migrate to Containers):** 기존 VM을 GKE 컨테이너로 자동 변환.
    *   **컨테이너화 및 GKE 오토스케일링 Deployment:** 모놀리식 VM 애플리케이션을 수평 확장(Scale-out) 가능하도록 리팩토링하는 효과적인 방법.
*   **미래 솔루션 개선 구상:**
    *   **Twelve-Factor App Development:** 클라우드 네이티브 애플리케이션 설계를 위한 모범 사례.

#### **2. 솔루션 인프라 관리 및 프로비저닝 (Managing and Provisioning a Solution Infrastructure)**

*   **CI/CD 파이프라인:**
    *   **순서:** 소스 코드 저장소 설정 → 코드 체크인 → 단위 테스트 실행 → 도커 컨테이너 빌드 → 배포.
    *   **Cloud Build:** CI/CD 자동화 도구.
*   **Infrastructure as Code (IaC):**
    *   **Terraform:** 멀티클라우드를 지원하는 선언적 IaC 도구. 반복 가능, 병렬 배포.
    *   **Cloud Deployment Manager:** GCP 전용 IaC 서비스.
*   **Kubernetes 확장성:**
    *   **Horizontal Pod Autoscaler (HPA):** `kubectl autoscale` 명령어를 사용하여 디플로이먼트의 파드 개수를 부하에 따라 자동으로 조절.
*   **데이터 생명주기 관리:**
    *   **소프트 삭제 (Soft Deletion):** 데이터를 즉시 영구 삭제하지 않고, 일정 기간 보존 후 삭제하는 전략.
    *   **Cloud Storage Lifecycle Management:** Cloud Storage 객체의 수명 주기를 자동으로 관리하여 비용 효율적인 보존 및 삭제.
*   **IoT 데이터 파이프라인:**
    *   **ClearBlade IoT Core + Pub/Sub + Dataflow + Nearline Storage:** IoT 데이터 수집, 처리, 비용 효율적인 장기 저장을 위한 표준 아키텍처.

#### **3. 보안 및 규정 준수 설계 (Designing for Security and Compliance)**

*   **Compute Engine 보안:**
    *   **네트워크 태그 (Network Tags):** 방화벽 규칙에 사용되어 VM 인스턴스 그룹에 규칙 적용.
    *   **Shielded VM (보호된 VM):** 보안 부팅(Secure Boot), vTPM 등을 통해 VM의 무결성 및 보안 강화.
    *   **서비스 계정 (Service Accounts):** VM이 GCP 서비스에 접근할 때 사용하는 신원. 최소 권한 원칙 적용.
*   **네트워크 접근 제어 및 감사:**
    *   **VPC Service Controls:** GCP 서비스 주위에 서비스 경계(Service Perimeter)를 설정하여 데이터 무단 반출 방지 및 승인된 네트워크에서만 접근 허용.
    *   **VPC Flow Logs:** VM 인스턴스 간 네트워크 트래픽 흐름 기록. 감사 및 포렌식에 활용.
*   **IAM (Identity and Access Management):**
    *   **리소스 계층 구조:** Google 권장 사례에 따라 조직, 폴더, 프로젝트 단위로 계층 구조를 구성.
    *   **최소 권한 원칙:** 필요한 최소한의 권한만 부여.
    *   **그룹 및 역할:** 사용자 개별이 아닌 그룹에 역할을 부여하고, 미리 정의된 역할(Predefined Roles) 또는 커스텀 역할(Custom Roles) 사용.
*   **웹 애플리케이션 보안:**
    *   **Google Cloud Armor (WAF):** 웹 애플리케이션 방화벽. DDoS 공격 및 웹 공격 방어, 특정 IP 차단.
    *   **IAP (Identity-Aware Proxy):** 사용자 신원 기반으로 애플리케이션 접근 제어.
*   **지속적인 규정 준수:**
    *   **Security Command Center (SCC):** GCP 환경의 보안 상태를 중앙에서 관리. 자산 검색, 보안 상태 분석, 규정 준수 보고서(예: PCI-DSS) 제공.

#### **4. 기술 및 비즈니스 프로세스 분석 및 최적화 (Analyzing and Optimizing Technical and Business Processes)**

*   **Terraform 워크플로우:** `terraform init` → `terraform plan` → `terraform apply`.
*   **CI/CD 자동화:**
    *   **Cloud Build Trigger:** Cloud Source Repositories에 코드 업데이트 시 빌드 프로세스 자동 트리거.
*   **애플리케이션 내구성:**
    *   **Regional Managed Instance Group (MIG):** 리전 내 여러 존에 VM을 분산하여 존 장애 시에도 서비스 지속성 확보.
*   **재해 복구 (Disaster Recovery):**
    *   **RTO (Recovery Time Objective):** 서비스 복구 목표 시간.
    *   **RPO (Recovery Point Objective):** 데이터 손실 허용 범위.
    *   **Hot/Warm/Cold DR 패턴:** RTO/RPO 요구사항에 따른 DR 전략 선택.
*   **시스템 과부하 방지:**
    *   **Graceful Degradation (점진적 성능 저하):** 시스템 부하가 높을 때 핵심 기능은 유지하고 비핵심 기능의 성능을 낮추는 전략.
    *   **Circuit Breaker (회로 차단기), Exponential Backoff (지수 백오프), Jitter (지터):** 분산 시스템에서 장애 전파 방지 및 재시도 로직 최적화 패턴.
*   **배포 전략:**
    *   **Canary Testing (카나리 테스트):** 소수의 사용자에게만 새 버전을 먼저 배포하여 피드백을 수집하고 문제 발생 시 빠르게 롤백.
    *   **A/B Testing:** 두 가지 버전의 기능을 비교하여 사용자 반응 측정.
    *   **Blue/Green Deployment:** 두 개의 동일한 환경을 준비하여 새 버전을 배포하고 트래픽을 전환.
*   **확장성 문제 시뮬레이션:**
    *   **Load Test (부하 테스트):** 애플리케이션에 인위적으로 부하를 주어 확장성 및 성능 한계 테스트.

#### **5. 구현 관리 (Managing Implementation)**

*   **비용 관리 및 접근 제어:**
    *   **Billing Account Administrator 역할:** 예산 관리자에게 부여.
    *   **프로젝트 예산 (Project Budget):** 프로젝트별 예산 설정.
    *   **Billing Alerts (결제 알림):** 예산 초과 시 알림.
    *   **리소스 할당량 (Resource Quotas):** 배포 가능한 리소스 양 제한.
    *   **라벨 (Labels):** 리소스에 태그를 지정하여 비용 추적 및 관리.
*   **DR 전략 (웹 앱 + MySQL):**
    *   **Global external Application Load Balancer + MIGs (두 리전):** 웹 앱의 고가용성 및 DR.
    *   **Cloud SQL HA + Cross-region Replica:** MySQL 데이터베이스의 고가용성 및 DR.
    *   **Multi-region Cloud Storage (백업):** 데이터 백업 및 복구.

#### **6. 솔루션 및 운영 안정성 보장 (Ensuring Solution and Operations Reliability)**

*   **멀티클라우드 모니터링:**
    *   **Cloud Monitoring:** GCP 및 AWS 등 멀티클라우드 환경의 성능 메트릭 및 로그 수집, 대시보드, 알림.
    *   **Uptime Check:** 웹 서비스의 가용성 모니터링.
*   **온콜 로테이션 및 알림:**
    *   **Pub/Sub (알림 채널):** 모니터링 알림을 수신하여 다른 서비스로 전달.
    *   **Cloud Run Function:** Pub/Sub 메시지를 받아 온콜 API로 알림 전송.
*   **릴리스 안정성:**
    *   **Agile Development:** 빠른 릴리스 주기, 자동화된 빌드/테스트, 버전 관리.
    *   **Canary Deployment:** 새 버전의 안정성 검증.
*   **마이크로서비스 문제 해결:**
    *   **Cloud Monitoring, Cloud Trace, Cloud Profiler:** 분산 시스템에서 성능 병목 현상, 지연 시간, 리소스 사용량 분석.
*   **운영 인시던트 관리:**
    *   **인시던트 커맨더 (Incident Commander):** 인시던트 대응 총괄.
    *   **블레임리스 사후 분석 (Blameless Post-mortem):** 문제의 근본 원인 분석 및 재발 방지 대책 수립.
*   **신뢰할 수 있는 컨테이너 배포:**
    *   **Binary Authorization:** 서명된 컨테이너 이미지만 프로덕션 환경에 배포되도록 강제.

---

**작성일**: 2025-10-31
