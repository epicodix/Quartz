---
title: GCP PCA Designing and Planning a Cloud Solution Architecture
summary: 이 문서는 GCP Professional Cloud Architect 시험의 '솔루션 아키텍처 설계 및 계획' 파트 문제들을 분석하고,
  각 선택지의 정답/오답 이유를 상세히 해설하여 시험 준비를 돕는 것을 목표로 합니다.
tags:
- 미분류
category: 기타
difficulty: 중급
estimated_time: 30분
created: '2025-10-30'
updated: '2025-11-08'
---


이 문서는 GCP Professional Cloud Architect 시험의 '솔루션 아키텍처 설계 및 계획' 파트 문제들을 분석하고, 각 선택지의 정답/오답 이유를 상세히 해설하여 시험 준비를 돕는 것을 목표로 합니다.

---

### Question 1

**영어 원문 (Original English Text)**

You are working in a mixed environment of VMs and Kubernetes. Some of your resources are on-premises, and some are in Google Cloud. Using containers as a part of your CI/CD pipeline has sped up releases significantly. You want to start migrating some of those VMs to containers so you can get similar benefits. You want to automate the migration process where possible. What should you do?

- A. Manually create a GKE cluster. Use Cloud Build to import VMs and convert them to containers.
- B. **(정답)** Manually create a GKE cluster, and then use Migrate for Anthos to set up the cluster, import VMs, and convert them to containers.
- C. Use Migrate for Anthos to automate the creation of Compute Engine instances to import VMs and convert them to containers.
- D. Use Migrate for Compute Engine to import VMs and convert them to containers.

**핵심 요약**

온프레미스 또는 클라우드의 VM을 GKE 컨테이너로 자동화하여 마이그레이션하는 가장 적합한 방법을 묻는 문제입니다.

**선택지 분석 및 정답 해설**

- **A (오답):** Cloud Build는 소스 코드를 빌드, 테스트, 배포하는 CI/CD 도구입니다. VM을 컨테이너로 변환하는 마이그레이션 기능은 제공하지 않습니다.
- **B (정답):** 이 시나리오의 핵심 도구는 **Migrate for Anthos**입니다. 이 서비스는 기존 VM(온프레미스, Compute Engine 등)을 GKE 클러스터의 컨테이너로 자동 변환해주는 강력한 마이그레이션 도구입니다. 전제 조건으로 대상 GKE 클러스터가 먼저 존재해야 하므로, '수동으로 GKE 클러스터 생성 후 Migrate for Anthos 사용'이 올바른 순서입니다.
- **C (오답):** Migrate for Anthos는 VM을 Compute Engine 인스턴스로 만드는 것이 아니라, GKE 클러스터 내의 컨테이너로 변환하는 도구입니다.
- **D (오답):** Migrate for Compute Engine은 VM을 Compute Engine(GCE) VM으로 마이그레이션하는 도구입니다. 컨테이너로 변환하는 기능은 없습니다. 문제의 목표는 '컨테이너화'이므로 적합하지 않습니다.

**PCA 핵심 역량**

- 애플리케이션 현대화 및 마이그레이션 전략 설계

---

### Question 2

**영어 원문 (Original English Text)**

Cymbal Direct is working with Cymbal Retail, a separate, autonomous division of Cymbal with different staff, networking teams, and data center. Cymbal Direct and Cymbal Retail are not in the same Google Cloud organization. Cymbal Retail needs access to Cymbal Direct’s web application for making bulk orders, but the application will not be available on the public internet. You want to ensure that Cymbal Retail has access to your application with low latency. You also want to avoid egress network charges if possible. What should you do?

- A. Verify that the subnet Cymbal Retail is using has the same IP address range with Cymbal Direct’s subnet range, and then enable VPC Network Peering for the project.
- B. **(정답)** Verify that the subnet range Cymbal Retail is using doesn’t overlap with Cymbal Direct’s subnet range, and then enable VPC Network Peering for the project.
- C. If Cymbal Retail does not have access to a Google Cloud data center, use Carrier Peering to connect the two networks.
- D. Specify Cymbal Direct’s project as the Shared VPC host project, and then configure Cymbal Retail’s project as a service project.

**핵심 요약**

서로 다른 GCP 조직(Organization)에 속한 두 개의 VPC를 비공개적으로 연결하면서, 지연 시간을 낮추고 Egress 비용을 피하는 방법을 묻는 문제입니다.

**선택지 분석 및 정답 해설**

- **A (오답):** VPC Peering의 가장 중요한 전제 조건은 두 VPC의 서브넷 IP 범위가 **겹치지 않아야(non-overlapping)** 한다는 것입니다. IP 범위가 동일하면 라우팅 충돌이 발생하여 피어링을 설정할 수 없습니다.
- **B (정답):** **VPC Network Peering**은 서로 다른 프로젝트나 조직에 속한 VPC 네트워크를 Google의 내부 백본 네트워크를 통해 비공개적으로 연결하는 가장 표준적인 방법입니다. 내부 네트워크를 사용하므로 지연 시간이 낮고, 피어링된 VPC 간의 통신에는 Egress 비용이 발생하지 않아 모든 요구사항을 충족합니다.
- **C (오답):** Carrier Peering은 온프레미스 환경과 Google의 엣지 네트워크를 연결하는 하이브리드 클라우드 솔루션입니다. GCP VPC 간의 연결에는 사용되지 않습니다.
- **D (오답/사용자 선택):** Shared VPC는 **동일한 조직(Organization) 내에서** 여러 프로젝트가 하나의 호스트 VPC를 공유하는 기술입니다. 문제에서 두 주체는 '동일한 Google Cloud 조직에 있지 않다'고 명시했으므로 Shared VPC는 적용할 수 없습니다.

**PCA 핵심 역량**

- VPC 네트워크 설계 (특히 VPC Peering 및 Shared VPC의 사용 사례와 제약 조건 이해)

---

### Question 3

**영어 원문 (Original English Text)**

Cymbal Direct developers have written a new application. Based on initial usage estimates, you decide to run the application on Compute Engine instances with 15 Gb of RAM and 4 CPUs. These instances store persistent data locally. After the application runs for several months, historical data indicates that the application requires 30 Gb of RAM. Cymbal Direct management wants you to make adjustments that will minimize costs. What should you do?

- A. **(정답)** Stop the instance, and then use the command `gcloud compute instances set-machine-type VM_NAME --machine-type n2-custom-4-30720`. Start the instance again.
- B. Stop the instance, and then use the command `gcloud compute instances set-machine-type VM_NAME --machine-type n2-custom-4-30720`. Set the instance’s metadata to: `preemptible: true`. Start the instance again.
- C. Stop the instance, and then use the command `gcloud compute instances set-machine-type VM_NAME --machine-type e2-standard-8`. Start the instance again.
- D. Stop the instance, and then use the command `gcloud compute instances set-machine-type VM_NAME --machine-type e2-standard-8`. Set the instance’s metadata to: `preemptible: true`. Start the instance again.

**핵심 요약**

Compute Engine VM의 리소스(RAM)를 비용 효율적으로 조정하는 방법을 묻는 문제입니다. CPU는 그대로, RAM만 두 배로 늘려야 합니다.

**선택지 분석 및 정답 해설**

- **A (정답):** GCP는 **Custom Machine Type**을 제공하여, 미리 정의된 유형을 따르지 않고 필요한 vCPU와 RAM 용량을 정확하게 지정할 수 있습니다. 이는 불필요한 리소스에 대한 비용을 지불하지 않게 하여 비용을 최적화하는 가장 좋은 방법입니다. `n2-custom-4-30720`은 vCPU 4개와 RAM 30720MB(30GB)를 정확히 지정하는 명령어입니다.
- **B (오답):** Preemptible VM(선점형 VM)은 언제든지 Google에 의해 종료될 수 있는 단기 실행 인스턴스입니다. 비용은 매우 저렴하지만, 문제에서 '영구 데이터(persistent data)를 로컬에 저장'한다고 했으므로, 언제든 종료될 수 있는 선점형 VM은 데이터 유실 위험 때문에 적합하지 않습니다.
- **C (오답):** `e2-standard-8`은 vCPU 8개와 RAM 32GB를 제공합니다. CPU 요구사항은 4개인데 8개로 늘어나므로 불필요한 비용이 발생합니다.
- **D (오답):** C와 마찬가지로 CPU가 불필요하게 늘어나며, B와 마찬가지로 선점형 VM은 이 시나리오에 적합하지 않습니다.

**PCA 핵심 역량**

- Compute Engine 머신 유형 선택 및 비용 최적화

---

### Question 4 (수정된 해설)

**영어 원문 (Original English Text)**

Cymbal Direct's employees will use Google Workspace. Your current on-premises network cannot meet the requirements to connect to Google's public infrastructure.
*Constraint added: Cymbal Direct’s on-premises network cannot meet the requirements for peering.*

- A. Order a Dedicated Interconnect from a Google Cloud partner, and ensure that proper routes are configured.
- B. **(정답)** Connect the on-premises network to Google’s public infrastructure via a partner that supports Carrier Peering.
- C. Connect the network to a Google point of presence, and enable Direct Peering.
- D. Order a Partner Interconnect from a Google Cloud partner, and ensure that proper routes are configured.

**핵심 요약**

온프레미스 네트워크에서 Google Workspace와 같은 **Google 공개 서비스**에 안정적으로 연결해야 하지만, **직접 피어링을 할 기술적/물리적 요구사항은 충족하지 못하는** 상황의 해결책을 묻는 문제입니다.

**선택지 분석 및 정답 해설**

- **A, D (오답):** Dedicated/Partner Interconnect는 온프레미스 네트워크와 **VPC 네트워크(내부망)**를 비공개적으로 연결하는 서비스입니다. 주 목적이 Google의 **공개 인프라**에 접속하는 것이므로, VPC 연결을 위한 Interconnect는 최적의 답이 아닙니다.

- **C (오답):** Direct Peering은 사용자의 네트워크와 Google의 엣지 네트워크를 직접 연결하여 Google 공개 서비스 트래픽을 교환하는 가장 좋은 방법 중 하나입니다. 하지만 문제의 새로운 전제 조건에서 **'피어링 요구사항을 충족할 수 없다'**고 명시했기 때문에, 이 선택지는 불가능합니다. (Direct Peering을 위해서는 Google의 피어링 위치에 물리적인 장비가 있어야 하는 등의 요구사항이 있습니다.)

- **B (정답):** **Carrier Peering**은 **Direct Peering의 요구사항을 충족하지 못하는 고객**을 위해 설계된 서비스입니다. 고객은 파트너 통신사(Carrier)에 연결하기만 하면, 그 파트너사가 이미 구축해 놓은 Google과의 연결을 통해 Google 공개 서비스에 접근할 수 있습니다. 따라서 '피어링 요구사항을 충족할 수 없는' 상황에서 Google 공개 인프라에 안정적으로 연결하기 위한 가장 적합한 솔루션입니다.

**PCA 핵심 역량**

- 하이브리드 클라우드 연결 설계 (Interconnect vs. Direct Peering vs. **Carrier Peering**의 차이점과 사용 사례의 명확한 이해)

---

### Question 5

**영어 원문 (Original English Text)**

You are working with a client who is using Google Kubernetes Engine (GKE) to migrate applications from a virtual machine–based environment to a microservices-based architecture. Your client has a complex legacy application that stores a significant amount of data on the file system of its VM. You do not want to re-write the application to use an external service to store the file system data. What should you do?

- A. **(정답)** In Cloud Shell, create a YAML file defining your StatefulSet called `statefulset.yaml`. Create a StatefulSet in GKE by running the command `kubectl apply -f statefulset.yaml`
- B. In Cloud Shell, create a YAML file defining your Pod called `pod.yaml`. Create a Pod in GKE by running the command `kubectl apply -f pod.yaml`
- C. In Cloud Shell, create a YAML file defining your Deployment called `deployment.yaml`. Create a Deployment in GKE by running the command `kubectl apply -f deployment.yaml`
- D. In Cloud Shell, create a YAML file defining your Container called `build.yaml`. Create a Container in GKE by running the command `gcloud builds submit –config build.yaml .`

**핵심 요약**

파일 시스템에 데이터를 저장하는 **상태 저장(Stateful)** 애플리케이션을 GKE로 마이그레이션하는 방법을 묻는 문제입니다.

**선택지 분석 및 정답 해설**

- **A (정답):** **StatefulSet**은 데이터베이스와 같이 안정적인 네트워크 식별자(DNS 이름)와 영구적인 스토리지(Persistent Storage)가 필요한 상태 저장 애플리케이션을 관리하기 위해 설계된 쿠버네티스 리소스입니다. YAML 파일에 PersistentVolumeClaim(PVC)을 함께 정의하여, Pod가 재시작되어도 동일한 스토리지에 연결되도록 보장합니다. 문제의 '파일 시스템에 데이터 저장' 요구사항을 충족하는 유일한 방법입니다.
- **B (오답):** Pod를 직접 생성하는 것은 권장되지 않습니다. Pod가 죽으면 컨트롤러에 의해 관리되지 않으므로 영원히 사라집니다.
- **C (오답):** Deployment는 주로 상태 비저장(Stateless) 애플리케이션을 위해 사용됩니다. Deployment의 Pod들은 언제든지 교체될 수 있으며, 안정적인 식별자나 스토리지를 보장하지 않습니다.
- **D (오답):** `gcloud builds submit`은 Cloud Build 작업을 제출하는 명령어이며, 쿠버네티스 리소스를 생성하는 명령어가 아닙니다.

**PCA 핵심 역량**

- GKE 워크로드 유형 선택 (Deployment vs. StatefulSet의 차이점 이해)

---

### Question 6

**영어 원문 (Original English Text)**

Cymbal Direct drones continuously send data during deliveries. You need to process and analyze the incoming telemetry data. After processing, the data should be retained, but it will only be accessed once every month or two. Your CIO has issued a directive to incorporate managed services wherever possible. You want a cost-effective solution to process the incoming streams of data. What should you do?

- A. Ingest data with ClearBlade IoT Core, and then store it in BigQuery.
- B. Ingest data with ClearBlade IoT Core, and then publish to Pub/Sub. Use BigQuery to process the data, and store it in a Standard Cloud Storage bucket.
- C. Ingest data with ClearBlade IoT Core, process it with Dataprep, and store it in a Coldline Cloud Storage bucket.
- D. **(정답)** Ingest data with ClearBlade IoT Core, and then publish to Pub/Sub. Use Dataflow to process the data, and store it in a Nearline Cloud Storage bucket.

**핵심 요약**

IoT 스트리밍 데이터를 수집, 처리 후, 거의 접근하지 않는 데이터를 비용 효율적으로 저장하는 완전 관리형 파이프라인을 설계하는 문제입니다.

**선택지 분석 및 정답 해설**

- **A, B (오답):** BigQuery는 대화형 분석 및 데이터 웨어하우징에 사용되는 도구이며, 실시간 스트리밍 데이터를 처리하는 데는 적합하지 않습니다. 또한 Standard Storage는 자주 접근하는 데이터에 적합하여 비용 효율적이지 않습니다.
- **C (오답):** Dataprep은 데이터를 시각적으로 탐색, 정리, 준비하는 도구로, 대규모 실시간 스트림 처리에 적합하지 않습니다. Coldline Storage는 1년에 한 번 미만으로 접근하는 데이터(보관용)에 적합하며, 한두 달에 한 번 접근하는 데이터에는 Nearline이 더 적합합니다.
- **D (정답):** 이 아키텍처는 각 단계에 가장 적합한 관리형 서비스를 사용합니다.
    - **수집:** IoT Core와 Pub/Sub은 대규모 스트리밍 데이터를 안정적으로 수집하는 표준 조합입니다.
    - **처리:** Dataflow는 대규모 스트리밍 및 배치 데이터 처리를 위한 완전 관리형 서비스입니다.
    - **저장:** Nearline Storage는 30일에 한 번 정도 접근하는 데이터에 대해 가장 비용 효율적인 스토리지 클래스입니다. 문제의 '한두 달에 한 번 접근' 요구사항에 완벽히 부합합니다.

**PCA 핵심 역량**

- 데이터 파이프라인 설계 (각 단계에 적합한 GCP 관리형 서비스 선택)

---

### Question 7

**영어 원문 (Original English Text)**

You are creating a new project. You plan to set up a Dedicated interconnect between two of your data centers in the near future and want to ensure that your resources are only deployed to the same regions where your data centers are located. You need to make sure that you don’t have any overlapping IP addresses that could cause conflicts when you set up the interconnect. You want to use RFC 1918 class B address space. What should you do?

- A. Create a new project, delete the default VPC network, set up the network in custom mode, and then use IP addresses in the 192.168.x.x address range to create subnets in your desired zones. Use VPC Network Peering to connect the zones in the same region to create regional networks.
- B. Create a new project, leave the default network in place, and then use the default 10.x.x.x network range to create subnets in your desired regions.
- C. Create a new project, delete the default VPC network, set up an auto mode VPC network, and then use the default 10.x.x.x network range to create subnets in your desired regions.
- D. **(정답)** Create a new project, delete the default VPC network, set up a custom mode VPC network, and then use IP addresses in the 172.16.x.x address range to create subnets in your desired regions.

**핵심 요약**

향후 온프레미스와의 Interconnect 연결을 고려하여, IP 충돌 없이 특정 리전에만 리소스를 배포하는 VPC 네트워크를 설계하는 문제입니다.

**선택지 분석 및 정답 해설**

- **A (오답):** `192.168.x.x`는 Class C 주소 공간입니다. 문제에서는 Class B(`172.16.0.0` – `172.31.255.255`)를 요구했습니다. 또한 VPC Peering은 존(zone)이 아닌 VPC를 연결하는 기술입니다.
- **B, C (오답):** Auto mode 또는 default VPC는 모든 리전에 자동으로 서브넷을 생성하므로, '특정 리전에만 리소스를 배포'하려는 요구사항에 위배됩니다. 또한 온프레미스 네트워크와 IP가 충돌할 가능성이 매우 높습니다.
- **D (정답):** 이 방법은 모든 요구사항을 충족합니다.
    - **`delete the default VPC network`**: IP 충돌 가능성을 원천 차단합니다.
    - **`set up a custom mode VPC network`**: 필요한 리전에만 원하는 IP 범위로 서브넷을 생성하여 완벽한 제어권을 가집니다.
    - **`use IP addresses in the 172.16.x.x address range`**: RFC 1918 Class B 주소 공간 요구사항을 만족합니다.

**PCA 핵심 역량**

- VPC 네트워크 설계 (Auto vs. Custom 모드, IP 주소 계획)

---

### Question 8

**영어 원문 (Original English Text)**

Customers need to have a good experience when accessing your web application so they will continue to use your service. You want to define key performance indicators (KPIs) to establish a service level objective (SLO). Which KPI could you use?

- A. Eighty-five percent of requests are successful
- B. Eighty-five percent of customers are satisfied users
- C. **(정답)** Eighty-five percent of requests succeed when aggregated over 1 minute
- D. Low latency for > 85% of requests when aggregated over 1 minute

**핵심 요약**

서비스 수준 목표(SLO)를 설정하기 위한 적절한 핵심 성과 지표(KPI)를 선택하는 문제입니다.

**선택지 분석 및 정답 해설**

- **A (오답):** '85%의 요청이 성공한다'는 목표는 좋지만, 측정 기간이 정의되지 않아 불완전합니다. 1년 동안 85%인지, 1초 동안 85%인지 알 수 없습니다.
- **B (오답):** '고객 만족도'는 정량적으로 측정하기 매우 어려운 주관적인 지표이므로, 기술적인 SLO로 사용하기에 부적합합니다.
- **C (정답):** 이 선택지는 **구체적이고 측정 가능하며, 시간 범위가 명확**합니다. '1분 동안 집계했을 때', '85%의 요청이 성공한다'는 것은 SLO의 가용성(Availability) 지표로 사용하기에 매우 적합한 형태입니다.
- **D (오답/사용자 선택):** '낮은 지연 시간(Low latency)'이라는 표현은 주관적이며, 어느 정도가 '낮은' 것인지에 대한 명확한 기준(threshold)이 없습니다. 예를 들어 '95%의 요청이 200ms 이내에 처리된다'와 같이 구체적인 수치가 필요합니다.

**PCA 핵심 역량**

- 서비스 모니터링 및 안정성 설계 (SRE 원칙, SLO/SLI/SLA의 개념 이해)

---

### Question 9

**영어 원문 (Original English Text)**

Cymbal Direct has created a proof of concept for a social integration service that highlights images of its products from social media. The proof of concept is a monolithic application running on a single SuSE Linux virtual machine (VM). The current version requires increasing the VM’s CPU and RAM in order to scale. You would like to refactor the VM so that you can scale out instead of scaling up. What should you do?

- A. Make sure that the application declares any dependent requirements in a `requirements.txt` or equivalent statement so that they can be referenced in a startup script, and attach external persistent volumes to the VMs.
- B. **(정답)** Use containers instead of VMs, and use a GKE autoscaling deployment.
- C. Move the existing codebase and VM provisioning scripts to git, and attach external persistent volumes to the VMs.
- D. Make sure that the application declares any dependent requirements in a `requirements.txt` or equivalent statement so that they can be referenced in a startup script. Specify the startup script in a managed instance group template, and use an autoscaling policy.

**핵심 요약**

단일 VM에서 수직 확장(Scale-up)하는 모놀리식 애플리케이션을 수평 확장(Scale-out)이 가능하도록 리팩토링하는 방법을 묻는 문제입니다.

**선택지 분석 및 정답 해설**

- **A, C, D (오답):** 이 선택지들은 모두 VM 기반의 아키텍처를 유지하면서 확장하려는 시도입니다. Managed Instance Group(MIG)을 사용한 오토스케일링(D)도 가능하지만, 문제의 핵심은 '리팩토링'이며, VM보다 더 현대적이고 효율적인 수평 확장 방식은 컨테이너를 사용하는 것입니다.
- **B (정답):** **컨테이너화**는 모놀리식 애플리케이션을 현대화하고 수평 확장을 용이하게 하는 가장 대표적인 방법입니다. 애플리케이션을 컨테이너로 패키징하고, 이를 **GKE의 오토스케일링 Deployment**로 배포하면, 부하에 따라 Pod(컨테이너 인스턴스)의 개수를 자동으로 늘리거나 줄여 손쉽게 수평 확장을 구현할 수 있습니다. 이는 'Scale-up'에서 'Scale-out'으로 전환하는 가장 이상적인 리팩토링 경로입니다.

**PCA 핵심 역량**

- 애플리케이션 현대화 및 컨테이너화 전략 설계

---

### Question 10

**영어 원문 (Original English Text)**

Cymbal Direct is evaluating database options to store the analytics data from its experimental drone deliveries. You're currently using a small cluster of MongoDB NoSQL database servers. You want to move to a managed NoSQL database service with consistent low latency that can scale throughput seamlessly and can handle the petabytes of data you expect after expanding to additional markets. What should you do?

- A. Extract the data from MongoDB. Insert the data into Firestore using Native mode.
- B. Extract the data from MongoDB, and insert the data into BigQuery.
- C. Extract the data from MongoDB. Insert the data into Firestore using Datastore mode.
- D. **(정답)** Create a Bigtable instance, extract the data from MongoDB, and insert the data into Bigtable.

**핵심 요약**

페타바이트(Petabyte) 규모의 대용량, 낮은 지연 시간, 높은 처리량이 요구되는 NoSQL 워크로드를 위한 최적의 GCP 관리형 데이터베이스를 선택하는 문제입니다.

**선택지 분석 및 정답 해설**

- **A, C (오답):** Firestore(Native/Datastore 모드)는 모바일 및 웹 애플리케이션을 위한 문서 기반 NoSQL 데이터베이스로, 확장성이 뛰어나지만 페타바이트 규모의 대용량 분석 데이터와 높은 처리량보다는 실시간 동기화 및 사용 편의성에 더 중점을 둡니다.
- **B (오답/사용자 선택):** BigQuery는 대규모 데이터 분석을 위한 서버리스 데이터 웨어하우스입니다. 분석 쿼리 성능은 뛰어나지만, 일관되게 낮은 지연 시간의 트랜잭션 처리(OLTP)가 아닌 분석 처리(OLAP)에 최적화되어 있습니다. 문제의 '낮은 지연 시간' 요구사항에 부합하지 않습니다.
- **D (정답):** **Cloud Bigtable**은 HBase API와 호환되는 완전 관리형 와이드 컬럼 NoSQL 데이터베이스입니다. **페타바이트 규모의 데이터, 매우 높은 읽기/쓰기 처리량, 일관되게 한 자릿수 밀리초(single-digit millisecond)의 낮은 지연 시간**을 위해 설계되었습니다. 분석 및 IoT 데이터와 같은 대규모 워크로드에 가장 적합한 선택입니다.

**PCA 핵심 역량**

- 데이터베이스 솔루션 선택 (각 GCP 데이터베이스 서비스의 특징과 사용 사례 이해)

---

**작성일**: 2025-10-30
