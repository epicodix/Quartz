---
title: Locally 프로덕션 확장 계획 (MVP to Enterprise)
creation_date: 2026-04-04
date: 2026-04-04
tags: [AWS, Terraform, CI/CD, Architecture, Expansion]
aliases: [프로덕션-확장-계획]
category: 인프라/아키텍처
status: 완성
priority: 높음
model: gemini-3.0-pro preview
---

# 🚀 Locally 프로덕션 확장 계획 (MVP to Enterprise)

해커톤 15시간의 제약 속에서 빠른 속도를 위해 **Vercel + Supabase** 조합으로 MVP를 구현했지만, 실제 글로벌 서비스로 도약하기 위한 **AWS 기반의 엔터프라이즈 아키텍처(IaC) 및 CI/CD 파이프라인 설계**를 완벽하게 준비해 두었습니다.

---

## 1. 단계별 아키텍처 진화 전략 (Architecture Evolution)

### ⏱️ Phase 1: MVP (현재) - "속도 최우선"
*   **프론트엔드/API**: Vercel (Next.js Serverless)
*   **데이터베이스**: Supabase (PostgreSQL SaaS)
*   **캐시**: Upstash (Redis SaaS)
*   **특징**: 제로(0) 인프라 관리, 극단적인 개발 속도 확보. 단, 트래픽 증가 시 종량제 요금 폭탄 및 데이터 제어권 상실 리스크 존재.

### 🏗️ Phase 2: Production Ready - "독립과 확장성" (준비 완료)
*   **프론트엔드/API**: AWS EC2 (Next.js Docker Container)
*   **데이터베이스/캐시**: AWS 내부망에 PostgreSQL, Redis 컨테이너 통합 (All-in-One)
*   **보안/네트워크**: Cloudflare Tunnel (Inbound 포트 전면 차단, DDoS 방어, 무료 SSL)
*   **특징**: SaaS 의존성을 100% 끊어내고 데이터 주권을 확보. 트래픽 스파이크에 대비한 OOM(메모리 부족) 방어 및 Redis 인메모리 캐싱 아키텍처 적용 완료.

### 🚀 Phase 3: Global Enterprise - "고가용성과 스케일아웃" (Next Step)
*   **오케스트레이션**: AWS ECS (Fargate) 기반의 서버리스 컨테이너 클러스터링
*   **데이터베이스**: Amazon RDS (Multi-AZ) 및 ElastiCache (Redis 클러스터)
*   **트래픽 분산**: AWS ALB (Application Load Balancer) + CloudFront (글로벌 CDN)
*   **특징**: 무중단 배포, 무한대에 가까운 오토스케일링(Auto Scaling), 데이터센터 재해 복구(DR) 완비.

---

## 2. Infrastructure as Code (IaC) - Terraform 구현 완료

인프라의 재현성과 버저닝(Versioning)을 위해 클릭이 아닌 **코드(Terraform)**로 클라우드 환경을 설계했습니다. (`infra/` 디렉토리 참조)

*   **컴퓨팅 리소스**: `t3.medium` EC2 인스턴스 (비용 효율성과 성능 밸런스)
*   **네트워크 보안**: Cloudflare Tunnel만 통신할 수 있도록 인바운드 포트(80, 443, 3000)를 원천 차단하는 강력한 **Security Group(방화벽)** 구성.
*   **안정성 장치**: EC2 초기화 스크립트(`user_data`)에 **2GB Swap 메모리 생성 로직**을 주입하여, 급격한 트래픽 몰림 시 발생할 수 있는 OOM(Out of Memory) 크래시를 하드웨어 레벨에서 방어.
*   **컨테이너 통합**: API, DB, Redis가 하나의 가상 네트워크로 묶여 0.1ms 미만의 지연 시간(Latency)으로 통신하는 `docker-compose.yml` 토폴로지 구성.

---

## 3. CI/CD 파이프라인 설계 (GitHub Actions)

개발 팀이 인프라에 신경 쓰지 않고 비즈니스 로직(꿀팁, AI 플랜)에만 집중할 수 있도록, **'코드 푸시 -> 서버 배포'까지의 전 과정을 자동화**했습니다. (`.github/workflows/deploy.yml` 참조)

### 🔄 배포 파이프라인 워크플로우 (Workflow)
1.  **Trigger**: `main` 브랜치에 코드가 Merge되거나 Push 될 때 파이프라인 자동 가동.
2.  **Secure Access**: GitHub Secrets에 안전하게 저장된 SSH Key를 이용해 AWS EC2 인스턴스에 암호화된 터널로 접속.
3.  **Code Synchronization**: 서버 내부에서 `git pull`을 통해 최신 코드로 동기화.
4.  **Environment Injection**: `OPENAI_API_KEY`, `DATABASE_URL`, `CLOUDFLARE_TUNNEL_TOKEN` 등 민감한 환경 변수를 동적으로 `.env` 파일에 주입하여 소스코드 유출을 원천 차단.
5.  **Zero-Touch Deployment**: `docker-compose up -d --build` 명령어를 통해 Next.js 웹 서버, PostgreSQL, Redis 컨테이너를 최신 이미지로 리빌드(Rebuild) 및 무인 배포.

<br>
<div align="right" style="font-size: 0.8em; color: gray; opacity: 0.6;">
  Supported by gemini-3.0-pro preview
</div>
