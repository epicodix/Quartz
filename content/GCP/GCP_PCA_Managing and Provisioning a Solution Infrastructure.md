---
title: GCP PCA Managing and Provisioning a Solution Infrastructure
summary: 이 문서는 GCP Professional Cloud Architect 시험의 'Managing and Provisioning a Solution
  Infrastructure' 파트 문제들을 분석하고, 각 선택지의 정답/오답 이유를 상세히 해설하여 시험 준비를 돕는 것을 ...
tags:
- 미분류
category: 기타
difficulty: 중급
estimated_time: 30분
created: '2025-10-31'
updated: '2025-11-08'
---



이 문서는 GCP Professional Cloud Architect 시험의 'Managing and Provisioning a Solution Infrastructure' 파트 문제들을 분석하고, 각 선택지의 정답/오답 이유를 상세히 해설하여 시험 준비를 돕는 것을 목표로 합니다.

---

### Question 1

**영어 원문 (Original English Text)**

You have deployed your frontend web application in Kubernetes. Based on historical use, you need three pods to handle normal demand. Occasionally your load will roughly double. A load balancer is already in place. How could you configure your environment to efficiently meet that demand?

- Edit your deployment's configuration file and change the number of replicas to six.
- **(정답)** Use the "kubectl autoscale" command to change the deployment’s maximum number of instances to six.
- Use the "kubectl autoscale" command to change the pod's maximum number of instances to six.
- Edit your pod's configuration file and change the number of replicas to six.

**핵심 요약**

Kubernetes 환경에서 웹 애플리케이션의 가변적인 수요에 효율적으로 대응하기 위한 자동 확장(Autoscaling) 방법을 묻는 문제입니다.

**선택지 분석 및 정답 해설**

-   **Edit your deployment's configuration file and change the number of replicas to six. (오답):** `replicas` 수를 직접 6으로 변경하는 것은 수동 스케일링입니다. 트래픽이 항상 6개 파드만큼 많지 않다면 불필요한 리소스 낭비가 발생하여 "효율적"이라는 문제의 요구사항에 부합하지 않습니다.
-   **Use the "kubectl autoscale" command to change the deployment’s maximum number of instances to six. (정답):** `kubectl autoscale` 명령어는 **Horizontal Pod Autoscaler (HPA)**를 생성합니다. HPA는 CPU 사용량이나 메모리 사용량과 같은 메트릭을 기반으로 파드(Pod)의 개수를 자동으로 조절합니다. 문제에서 "정상 수요는 3개, 가끔 두 배로 증가"한다고 했으므로, HPA를 통해 최소 3개, 최대 6개(또는 그 이상)로 설정하여 부하에 따라 유연하게 확장/축소하는 것이 가장 효율적인 방법입니다. HPA는 디플로이먼트(Deployment)를 대상으로 작동합니다.
-   **Use the "kubectl autoscale" command to change the pod's maximum number of instances to six. (오답):** 쿠버네티스에서 스케일링은 개별 파드(Pod)가 아닌, 파드를 관리하는 디플로이먼트(Deployment)와 같은 컨트롤러를 대상으로 이루어집니다.
-   **Edit your pod's configuration file and change the number of replicas to six. (오답):** 파드 자체에는 `replicas` 개념이 없으며, 파드 설정을 직접 변경하는 것은 일반적인 스케일링 방법이 아닙니다.

**PCA 핵심 역량**

-   Kubernetes 워크로드의 확장성 설계 (Horizontal Pod Autoscaler 이해)

---

### Question 2

**영어 원문 (Original English Text)**

Cymbal Direct wants to create a pipeline to automate the building of new application releases. What sequence of steps should you use?

- Set up a source code repository. Run unit tests. Check in code. Deploy. Build a Docker container.
- **(정답)** Set up a source code repository. Check in code. Run unit tests. Build a Docker container. Deploy.
- Check in code. Set up a source code repository. Run unit tests. Deploy. Build a Docker container.
- Run unit tests. Deploy. Build a Docker container. Check in code. Set up a source code repository.

**핵심 요약**

애플리케이션 릴리스를 자동화하기 위한 CI/CD(Continuous Integration/Continuous Deployment) 파이프라인의 올바른 단계 순서를 묻는 문제입니다.

**선택지 분석 및 정답 해설**

-   **Set up a source code repository. Check in code. Run unit tests. Build a Docker container. Deploy. (정답):** 이 순서는 CI/CD 파이프라인의 논리적인 흐름을 정확하게 따릅니다.
    1.  **소스 코드 저장소 설정:** 코드를 관리할 공간이 가장 먼저 필요합니다.
    2.  **코드 체크인:** 개발자가 코드를 저장소에 커밋(commit)하고 푸시(push)합니다. 이 행위가 파이프라인을 트리거합니다.
    3.  **단위 테스트 실행:** 코드가 저장소에 들어오면, 변경사항이 기존 기능을 손상시키지 않았는지 확인하기 위해 단위 테스트를 실행합니다. 이는 코드 품질을 보장하는 중요한 단계입니다.
    4.  **도커 컨테이너 빌드:** 테스트를 통과한 코드를 실행 가능한 컨테이너 이미지로 패키징합니다.
    5.  **배포:** 빌드된 컨테이너 이미지를 대상 환경에 배포합니다.
-   **다른 선택지 (오답):** 다른 선택지들은 각 단계의 논리적 선후 관계가 뒤바뀌어 있어 올바른 파이프라인을 구성할 수 없습니다. 예를 들어, 코드를 체크인하기 전에 단위 테스트를 실행하거나, 컨테이너를 빌드하기 전에 배포하는 것은 불가능합니다.

**PCA 핵심 역량**

-   CI/CD 파이프라인 설계 및 자동화 (각 단계의 목적과 순서 이해)

---

### Question 3

**영어 원문 (Original English Text)**

You are working with a client who has built a secure messaging application. The application is open source and consists of two components. The first component is a web app, written in Go, which is used to register an account and authorize the user’s IP address. The second is an encrypted chat protocol that uses TCP to talk to the backend chat servers running Debian. If the client's IP address doesn't match the registered IP address, the application is designed to terminate their session. The number of clients using the service varies greatly based on time of day, and the client wants to be able to easily scale as needed. What should you do?

- Deploy the web application using the App Engine standard environment with a global external Application Load Balancer and a network endpoint group. Use an unmanaged instance group for the backend chat servers. Use an external network load balancer to load-balance traffic across the backend chat servers.
- Deploy the web application using the App Engine flexible environment with a global external Application Load Balancer and a network endpoint group. Use an unmanaged instance group for the backend chat servers. Use an external passthrough Network Load Balancer to load-balance traffic across the backend chat servers.
- **(정답)** Deploy the web application using the App Engine standard environment with a global external Application Load Balancer and a network endpoint group. Use a managed instance group for the backend chat servers. Use an external passthrough Network Load Balancer to load-balance traffic across the backend chat servers.
- Deploy the web application using the App Engine standard environment with a global external Application Load Balancer and a network endpoint group. Use a managed instance group for the backend chat servers. Use a global external Network Load Balancer with SSL proxy to load-balance traffic across the backend chat servers.

**핵심 요약**

Go 웹 앱 프론트엔드와 TCP 기반 암호화 채팅 백엔드를 가진 애플리케이션을 GCP에 배포하는 문제입니다. 특히, 백엔드는 클라이언트 IP 주소 검증이 필요하며, 트래픽 변동에 따른 자동 확장이 요구됩니다.

**선택지 분석 및 정답 해설**

-   **Deploy the web application using the App Engine standard environment with a global external Application Load Balancer and a network endpoint group. Use a managed instance group for the backend chat servers. Use an external passthrough Network Load Balancer to load-balance traffic across the backend chat servers. (정답):**
    *   **웹 앱 (Go):** App Engine 표준 환경은 Go를 포함한 여러 언어를 지원하며, 트래픽에 따라 자동으로 확장/축소되는 완전 관리형 플랫폼으로 웹 앱에 적합합니다. 글로벌 외부 Application Load Balancer와 네트워크 엔드포인트 그룹(NEG)은 App Engine과 연동하여 효율적인 트래픽 분산을 제공합니다.
    *   **백엔드 채팅 서버 (Debian, TCP):** "클라이언트 수가 크게 변동"하므로 **관리형 인스턴스 그룹(MIG)**을 사용하여 자동 확장을 구현하는 것이 필수적입니다.
    *   **부하 분산기 (클라이언트 IP 보존):** "클라이언트의 IP 주소가 등록된 IP와 일치하지 않으면 세션을 종료"하는 요구사항은 백엔드 서버가 원본 클라이언트 IP를 알아야 함을 의미합니다. **외부 패스스루 네트워크 부하 분산기(External Passthrough Network Load Balancer)**는 L4(TCP/UDP)에서 작동하며, 클라이언트의 요청 패킷을 백엔드 서버로 **그대로 통과**시켜 원본 클라이언트 IP를 보존합니다.
-   **Deploy the web application using the App Engine standard environment with a global external Application Load Balancer and a network endpoint group. Use a managed instance group for the backend chat servers. Use a global external Network Load Balancer with SSL proxy to load-balance traffic across the backend chat servers. (오답):** SSL 프록시 부하 분산기는 클라이언트와 LB 간의 SSL 연결을 종료하고 새로운 연결을 백엔드로 생성합니다. 이 과정에서 원본 클라이언트 IP가 기본적으로 보존되지 않으며, 문제에서 "암호화된 채팅 프로토콜"이라고 명시했으므로 LB에서 SSL을 처리할 필요가 없습니다.
-   **다른 선택지 (오답):**
    *   "unmanaged instance group"은 자동 확장을 제공하지 않아 트래픽 변동에 효율적으로 대응할 수 없습니다.
    *   "App Engine flexible environment"도 가능하지만, 표준 환경이 Go 앱에 더 적합하고 비용 효율적일 수 있습니다.

**PCA 핵심 역량**

-   GCP 컴퓨팅 및 네트워킹 서비스 선택 (App Engine, MIG, Load Balancer 유형별 특징 및 사용 사례 이해)
-   클라이언트 IP 보존 요구사항에 따른 부하 분산기 선택

---

### Question 4

**영어 원문 (Original English Text)**

Cymbal Direct needs to use a tool to deploy its infrastructure. You want something that allows for repeatable deployment processes, uses a declarative language, and allows parallel deployment. You also want to deploy infrastructure as code on Google Cloud and other cloud providers. What should you do?

- **(정답)** Automate the deployment with Terraform scripts.
- Use Google Kubernetes Engine (GKE) to create deployments and manifests for your applications.
- Automate the deployment with Cloud Deployment Manager.
- Develop in Docker containers for portability and ease of deployment.

**핵심 요약**

반복 가능하고, 선언적이며, 병렬 배포가 가능하고, Google Cloud 및 다른 클라우드 프로바이더 모두에서 인프라를 코드로 배포할 수 있는 도구를 선택하는 문제입니다.

**선택지 분석 및 정답 해설**

-   **Automate the deployment with Terraform scripts. (정답):** Terraform은 HashiCorp에서 개발한 오픈소스 Infrastructure as Code (IaC) 도구입니다.
    *   **반복 가능한 배포:** 코드로 인프라를 정의하므로 동일한 환경을 여러 번 생성할 수 있습니다.
    *   **선언적 언어:** 원하는 인프라의 최종 상태를 정의하면 Terraform이 이를 달성하기 위한 작업을 수행합니다.
    *   **병렬 배포:** 리소스 간의 의존성을 분석하여 독립적인 리소스들을 병렬로 생성할 수 있습니다.
    *   **멀티클라우드 지원:** GCP뿐만 아니라 AWS, Azure 등 다양한 클라우드 프로바이더를 지원하여 문제의 "Google Cloud 및 다른 클라우드 프로바이더" 요구사항을 완벽하게 충족합니다.
-   **Use Google Kubernetes Engine (GKE) to create deployments and manifests for your applications. (오답):** GKE는 컨테이너화된 애플리케이션을 배포하고 관리하는 컨테이너 오케스트레이션 서비스입니다. 인프라 전체를 프로비저닝하는 IaC 도구가 아니며, Google Cloud에 특화되어 있어 멀티클라우드 요구사항을 충족하지 못합니다.
-   **Automate the deployment with Cloud Deployment Manager. (오답):** Cloud Deployment Manager는 GCP의 IaC 서비스이지만, **GCP에만 특화**되어 있어 다른 클라우드 프로바이더를 지원하지 않습니다.
-   **Develop in Docker containers for portability and ease of deployment. (오답):** Docker는 애플리케이션을 컨테이너화하는 기술이지, 인프라 자체를 코드로 프로비저닝하는 도구가 아닙니다.

**PCA 핵심 역량**

-   Infrastructure as Code (IaC) 도구 선택 (Terraform, Cloud Deployment Manager의 특징 및 멀티클라우드 지원 여부 이해)

---

### Question 5

**영어 원문 (Original English Text)**

Cymbal Direct wants a layered approach to security when setting up Compute Engine instances. What are some options you could use to make your Compute Engine instances more secure?

- Use labels to allow traffic only from certain sources and ports. Use a Compute Engine service account.
- **(정답)** Use network tags to allow traffic only from certain sources and ports. Turn on Secure boot and vTPM.
- Use labels to allow traffic only from certain sources and ports. Turn on Secure boot and vTPM.
- Use network tags to allow traffic only from certain sources and ports. Use a Compute Engine service account.

**핵심 요약**

Compute Engine 인스턴스에 대한 계층적 보안(Layered Security)을 구현하기 위한 옵션을 묻는 문제입니다.

**선택지 분석 및 정답 해설**

-   **Use network tags to allow traffic only from certain sources and ports. Turn on Secure boot and vTPM. (정답):** 이 선택지는 네트워크 수준과 인스턴스 수준의 보안을 모두 강화하는 올바른 조합입니다.
    *   **네트워크 태그 (Network Tags):** GCP 방화벽 규칙은 네트워크 태그를 사용하여 특정 VM 인스턴스 그룹에 규칙을 적용합니다. 이를 통해 특정 소스 IP 주소와 포트에서만 트래픽을 허용하여 네트워크 접근을 제어할 수 있습니다. (라벨은 방화벽 규칙에 사용되지 않습니다.)
    *   **보안 부팅 (Secure Boot) 및 vTPM (virtual Trusted Platform Module):** 이들은 Shielded VM의 핵심 기능으로, VM의 부팅 프로세스 및 런타임 무결성을 보호하여 부트킷, 루트킷과 같은 저수준 공격으로부터 VM을 방어합니다.
-   **Use labels to allow traffic only from certain sources and ports. Use a Compute Engine service account. (오답):** 방화벽 규칙에는 "labels"가 아닌 "network tags"가 사용됩니다. 서비스 계정 사용은 좋은 보안 관행이지만, 이 선택지의 다른 부분이 틀렸습니다.
-   **Use labels to allow traffic only from certain sources and ports. Turn on Secure boot and vTPM. (오답):** 마찬가지로 방화벽 규칙에 "labels"를 사용하는 것이 틀렸습니다.
-   **Use network tags to allow traffic only from certain sources and ports. Use a Compute Engine service account. (오답):** 이 선택지는 네트워크 태그 사용은 맞지만, Secure Boot 및 vTPM과 같은 인스턴스 수준의 강력한 보안 기능을 포함하지 않아 "계층적 보안" 접근에 덜 포괄적입니다.

**PCA 핵심 역량**

-   Compute Engine 보안 강화 (네트워크 태그와 라벨의 차이, Shielded VM 기능 이해)

---

### Question 6

**영어 원문 (Original English Text)**

Cymbal Direct must meet compliance requirements. You need to ensure that employees with valid accounts cannot access their VPC network from locations outside of its secure corporate network, including from home. You also want a high degree of visibility into network traffic for auditing and forensics purposes. What should you do?

- **(정답)** Enable VPC Service Controls, define a network perimeter to restrict access to authorized networks, and enable VPC Flow Logs for the networks you need to monitor.
- Enable Identity-Aware Proxy (IAP) to allow users to access services securely. Use Google Cloud Observability to view audit logs for the networks you need to monitor.
- Enable VPC Service Controls, and use Google Cloud Observability to view audit logs for the networks you need to monitor.
- Ensure that all users install Cloud VPN. Enable VPC Flow Logs for the networks you need to monitor.

**핵심 요약**

보안 규정 준수를 위해 기업 네트워크 외부에서의 VPC 접근을 제한하고, 네트워크 트래픽에 대한 높은 가시성을 확보하여 감사 및 포렌식에 활용하는 방법을 묻는 문제입니다.

**선택지 분석 및 정답 해설**

-   **Enable VPC Service Controls, define a network perimeter to restrict access to authorized networks, and enable VPC Flow Logs for the networks you need to monitor. (정답):** 이 선택지는 문제의 두 가지 핵심 요구사항을 모두 충족하는 가장 적합한 솔루션입니다.
    *   **VPC 서비스 컨트롤 (VPC Service Controls):** GCP 서비스(예: Cloud Storage, BigQuery) 주위에 **서비스 경계(Service Perimeter)**를 설정하여, 승인된 네트워크(예: 기업 네트워크)에서만 해당 서비스에 접근하도록 제한할 수 있습니다. 이는 기업 네트워크 외부에서의 VPC 접근을 효과적으로 차단합니다.
    *   **VPC 흐름 로그 (VPC Flow Logs):** VM 인스턴스 간의 네트워크 트래픽 흐름에 대한 상세 정보를 기록합니다. 이 로그는 네트워크 모니터링, 보안 분석, 감사 및 포렌식에 필수적인 "높은 가시성"을 제공합니다.
-   **Enable Identity-Aware Proxy (IAP) to allow users to access services securely. Use Google Cloud Observability to view audit logs for the networks you need to monitor. (오답):** IAP는 개별 애플리케이션에 대한 사용자 기반 접근 제어에 사용되며, VPC 네트워크 전체에 대한 접근 제한과는 거리가 있습니다. 감사 로그(Audit Logs)는 누가 어떤 작업을 했는지(API 호출)를 기록하지만, 네트워크 트래픽 자체의 흐름에 대한 가시성은 제공하지 않습니다.
-   **Enable VPC Service Controls, and use Google Cloud Observability to view audit logs for the networks you need to monitor. (오답):** VPC Service Controls는 맞지만, 네트워크 트래픽 가시성을 위해서는 감사 로그가 아닌 VPC 흐름 로그가 필요합니다.
-   **Ensure that all users install Cloud VPN. Enable VPC Flow Logs for the networks you need to monitor. (오답):** Cloud VPN은 온프레미스와 GCP 간의 안전한 연결을 제공하지만, 기업 네트워크 외부에서 VPC 접근을 "제한"하는 직접적인 메커니즘은 아닙니다. 사용자가 VPN을 사용하지 않고 다른 경로로 접근하는 것을 막을 수는 없습니다.

**PCA 핵심 역량**

-   네트워크 보안 및 규정 준수 (VPC Service Controls, VPC Flow Logs의 역할 이해)

---

### Question 7

**영어 원문 (Original English Text)**

You need to deploy a load balancer for a web-based application with multiple backends in different regions. You want to direct traffic to the backend closest to the end user, but also to different backends based on the URL the user is accessing. Which of the following could be used to implement this?

- **(정답)** The request is received by the global external Application Load Balancer. A global forwarding rule sends the request to a target proxy, which checks the URL map and selects the backend service. The backend service sends the request to Compute Engine instance groups in multiple regions.
- The request is received by the proxy Network Load Balancer, which uses a global forwarding rule to check the URL map, then sends the request to a backend service. The request is processed by Compute Engine instance groups in multiple regions.
- The request is matched by a URL map and then sent to a proxy Network Load Balancer. A global forwarding rule sends the request to a target proxy, which selects a backend service and sends the request to Compute Engine instance groups in multiple regions.
- The request is matched by a URL map and then sent to a global external Application Load Balancer. A global forwarding rule sends the request to a target proxy, which selects a backend service. The backend service sends the request to Compute Engine instance groups in multiple regions.

**핵심 요약**

여러 리전에 백엔드를 가진 웹 애플리케이션에 대해, 사용자에게 가장 가까운 백엔드로 트래픽을 보내고 URL 경로에 따라 다른 백엔드로 라우팅하는 부하 분산기 구성 방법을 묻는 문제입니다.

**선택지 분석 및 정답 해설**

-   **The request is received by the global external Application Load Balancer. A global forwarding rule sends the request to a target proxy, which checks the URL map and selects the backend service. The backend service sends the request to Compute Engine instance groups in multiple regions. (정답):** 이 선택지는 글로벌 외부 Application Load Balancer의 정확한 작동 흐름을 설명합니다.
    1.  **글로벌 외부 Application Load Balancer:** 웹 기반 애플리케이션에 적합한 L7 부하 분산기입니다.
    2.  **글로벌 전달 규칙 (Global Forwarding Rule):** LB의 외부 IP 주소로 들어오는 트래픽을 받아 대상 프록시로 전달합니다.
    3.  **대상 HTTP(S) 프록시 (Target HTTP(S) Proxy):** 클라이언트 연결을 종료하고, URL 맵을 참조하여 요청을 라우팅합니다.
    4.  **URL 맵 (URL Map):** 요청의 호스트 및 경로(예: `/images`, `/api`)에 따라 어떤 백엔드 서비스로 트래픽을 보낼지 결정합니다. 이는 "URL에 따라 다른 백엔드로 라우팅"하는 요구사항을 충족합니다.
    5.  **백엔드 서비스 (Backend Service):** 여러 리전에 분산된 Compute Engine 인스턴스 그룹(백엔드)을 관리하며, 사용자에게 가장 가까운(지리적 근접성) 건강한 백엔드로 트래픽을 보냅니다.
-   **The request is matched by a URL map and then sent to a global external Application Load Balancer. A global forwarding rule sends the request to a target proxy, which selects a backend service. The backend service sends the request to Compute Engine instance groups in multiple regions. (오답):** URL 맵은 요청이 부하 분산기에 도달한 후, 대상 프록시에 의해 참조되어 라우팅 결정을 내리는 구성 요소입니다. 요청이 URL 맵에 의해 먼저 일치된 후 LB로 보내지는 것이 아닙니다.
-   **다른 선택지 (오답):** 프록시 네트워크 부하 분산기(Proxy Network Load Balancer)는 L4 부하 분산기로, URL 기반 라우팅(L7 기능)을 지원하지 않습니다.

**PCA 핵심 역량**

-   글로벌 외부 Application Load Balancer의 구성 요소 및 요청 처리 흐름 이해

---

### Question 8

**영어 원문 (Original English Text)**

Cymbal Direct wants to allow partners to make orders programmatically, without having to speak on the phone with an agent. What should you consider when designing the API?

- The API backend should be loosely coupled. Clients should not be required to know too many details of the services they use. REST APIs using gRPC should be used for all external APIs.
- **(정답)** The API backend should be loosely coupled. Clients should not be required to know too many details of the services they use. For REST APIs, HTTP(S) is the most common protocol.
- The API backend should be tightly coupled. Clients should know a significant amount about the services they use. REST APIs using gRPC should be used for all external APIs.
- The API backend should be tightly coupled. Clients should know a significant amount about the services they use. For REST APIs, HTTP(S) is the most common protocol used.

**핵심 요약**

파트너가 프로그램적으로 주문할 수 있도록 API를 설계할 때 고려해야 할 사항을 묻는 문제입니다. 특히 API 설계 원칙과 프로토콜 선택에 대한 이해가 필요합니다.

**선택지 분석 및 정답 해설**

-   **The API backend should be loosely coupled. Clients should not be required to know too many details of the services they use. For REST APIs, HTTP(S) is the most common protocol. (정답):** 이 선택지는 API 설계의 모범 사례를 정확하게 설명합니다.
    *   **느슨한 결합 (Loose Coupling):** API 클라이언트(파트너 시스템)와 API 백엔드 시스템은 서로의 내부 구현에 대해 최소한의 정보만 알아야 합니다. 이는 백엔드 시스템을 변경하거나 업데이트할 때 클라이언트에 미치는 영향을 최소화하여 시스템의 유연성과 유지보수성을 높입니다.
    *   **클라이언트의 세부 정보 불필요:** 클라이언트가 백엔드의 세부 사항을 많이 알 필요가 없어야 합니다.
    *   **REST API와 HTTP(S):** REST는 아키텍처 스타일이며, 특정 프로토콜에 종속되지 않지만, 외부 API의 경우 **HTTP(S) 프로토콜 위에서 JSON 또는 XML 페이로드와 함께 구현**되는 것이 사실상의 표준입니다.
-   **The API backend should be loosely coupled. Clients should not be required to know too many details of the services they use. REST APIs using gRPC should be used for all external APIs. (오답):** "REST APIs using gRPC"는 개념적으로 틀린 설명입니다. REST는 HTTP(S) 기반의 아키텍처 스타일이며, gRPC는 HTTP/2와 Protocol Buffers를 사용하는 별도의 RPC(Remote Procedure Call) 프레임워크입니다. 둘은 다른 기술 스택입니다.
-   **다른 선택지 (오답):** "강한 결합 (tightly coupled)"은 백엔드 변경 시 클라이언트에도 큰 영향을 미쳐 좋지 않은 설계입니다.

**PCA 핵심 역량**

-   API 설계 원칙 (느슨한 결합), REST API의 특징 및 프로토콜 선택

---

### Question 9

**영어 원문 (Original English Text)**

Your existing application runs on Ubuntu Linux VMs in an on-premises hypervisor. You want to deploy the application to Google Cloud with minimal refactoring. What should you do?

- Set up a Google Kubernetes Engine (GKE) cluster, and then create a deployment with an autoscaler.
- **(정답)** Write Terraform scripts to deploy the application as Compute Engine instances.
- Isolate the core features that the application provides. Use App Engine to deploy each feature independently as a microservice.
- Use a Dedicated or Partner Interconnect to connect the on-premises network where your application is running to your VPC: Configure an endpoint for a global external Application Load Balancer that connects to the existing VMs.

**핵심 요약**

온프레미스 VM에서 실행되는 기존 애플리케이션을 "최소한의 리팩토링"으로 Google Cloud에 배포하는 방법을 묻는 문제입니다.

**선택지 분석 및 정답 해설**

-   **Write Terraform scripts to deploy the application as Compute Engine instances. (정답):** "최소한의 리팩토링"이라는 요구사항은 **Lift and Shift (리프트 앤 시프트)** 마이그레이션 전략을 의미합니다. 기존 VM 기반 애플리케이션을 클라우드의 VM(Compute Engine 인스턴스)으로 그대로 옮기는 것이 가장 적은 변경으로 가능합니다. Terraform 스크립트를 사용하면 이 과정을 자동화하고 반복 가능하게 만들 수 있습니다.
-   **Set up a Google Kubernetes Engine (GKE) cluster, and then create a deployment with an autoscaler. (오답):** VM 기반 애플리케이션을 GKE 컨테이너로 옮기려면 애플리케이션을 컨테이너화해야 합니다. 이는 상당한 리팩토링(Re-platforming)이 필요하므로 "최소한의 리팩토링" 요구사항에 부합하지 않습니다.
-   **Isolate the core features that the application provides. Use App Engine to deploy each feature independently as a microservice. (오답):** 기존 모놀리식 애플리케이션을 마이크로서비스로 분리하고 App Engine에 배포하는 것은 "재설계(Re-architecting)" 전략으로, 가장 많은 리팩토링이 필요합니다.
-   **Use a Dedicated or Partner Interconnect to connect the on-premises network where your application is running to your VPC: Configure an endpoint for a global external Application Load Balancer that connects to the existing VMs. (오답):** 이 방법은 온프레미스 환경과 GCP를 연결하는 하이브리드 클라우드 구성입니다. 애플리케이션을 Google Cloud에 "배포"하는 것이 아니라, 온프레미스에 계속 두는 방식이므로 문제의 의도와 다릅니다.

**PCA 핵심 역량**

-   클라우드 마이그레이션 전략 (Lift and Shift, Re-platforming, Re-architecting) 이해

---

### Question 10

**영어 원문 (Original English Text)**

Cymbal Direct's user account management app allows users to delete their accounts whenever they like. Cymbal Direct also has a very generous 60-day return policy for users. The customer service team wants to make sure that they can still refund or replace items for a customer even if the customer’s account has been deleted. What can you do to ensure that the customer service team has access to relevant account information?

- Ensure that the user clearly understands that after they delete their account, all their information will also be deleted. Remind them to download a copy of their order history and account information before deleting their account. Have the support agent copy any open or recent orders to a shared spreadsheet.
- Disable the account. Export account information to Cloud Storage. Have the customer service team permanently delete the data after 30 days.
- Restore a previous copy of the user information database from a snapshot. Have a database administrator capture needed information about the customer.
- **(정답)** Temporarily disable the account for 30 days. Export account information to Cloud Storage, and enable lifecycle management to delete the data in 60 days.

**핵심 요약**

사용자가 계정을 삭제하더라도, 60일 반품 정책을 위해 고객 서비스팀이 관련 계정 정보에 접근할 수 있도록 데이터를 관리하는 방법을 묻는 문제입니다.

**선택지 분석 및 정답 해설**

-   **Temporarily disable the account for 30 days. Export account information to Cloud Storage, and enable lifecycle management to delete the data in 60 days. (정답):** 이 선택지는 "소프트 삭제(Soft Deletion)" 및 데이터 보존 정책을 가장 효과적으로 구현합니다.
    1.  **계정 일시 비활성화:** 사용자가 계정을 삭제하더라도 즉시 데이터를 완전히 삭제하지 않고, 로그인만 막아 고객 서비스팀이 60일 동안 정보에 접근할 수 있도록 합니다.
    2.  **Cloud Storage로 내보내기:** 활성 데이터베이스에서 데이터를 분리하여 Cloud Storage와 같은 저렴하고 내구성이 뛰어난 스토리지에 보관합니다.
    3.  **수명 주기 관리 (Lifecycle Management):** Cloud Storage의 기능을 활용하여 60일(반품 정책 기간)이 지난 후 데이터를 자동으로 삭제하도록 설정합니다. 이는 규정 준수 및 자동화된 데이터 관리에 매우 효율적입니다.
-   **Ensure that the user clearly understands that after they delete their account, all their information will also be deleted. Remind them to download a copy of their order history and account information before deleting their account. Have the support agent copy any open or recent orders to a shared spreadsheet. (오답):** 사용자에게 책임을 전가하거나 수동으로 스프레드시트에 복사하는 것은 비효율적이고 오류 발생 가능성이 높으며, 규정 준수를 보장하기 어렵습니다.
-   **Disable the account. Export account information to Cloud Storage. Have the customer service team permanently delete the data after 30 days. (오답):** 30일 후에 영구 삭제하면 60일 반품 정책을 충족할 수 없습니다.
-   **Restore a previous copy of the user information database from a snapshot. Have a database administrator capture needed information about the customer. (오답):** 특정 사용자 정보만을 위해 전체 데이터베이스 스냅샷을 복원하는 것은 매우 비효율적이고 복잡하며, 운영에 부담을 줍니다.

**PCA 핵심 역량**

-   데이터 생명주기 관리, 데이터 보존 정책, 소프트 삭제 전략

---

**작성일**: 2025-10-31
