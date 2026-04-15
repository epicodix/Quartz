---
title: AWS 파이프라인 모니터링 가이드 - pposiraegi-ecommerce-msa
tags:
  - AWS
  - 모니터링
  - CI/CD
  - CloudWatch
  - CodeBuild
aliases:
  - 파이프라인모니터링
date: 2026-04-14
category: DevOps/모니터링
status: 완성
priority: 높음
---

# 🎯 AWS 파이프라인 모니터링 가이드 - pposiraegi-ecommerce-msa

## 📑 목차
- [[#1. 현재 파이프라인 상태|현재 파이프라인 상태]]
- [[#2. AWS 모니터링 도구 개요|AWS 모니터링 도구 개요]]
- [[#3. CodePipeline 모니터링|CodePipeline 모니터링]]
- [[#4. CodeBuild 모니터링|CodeBuild 모니터링]]
- [[#5. ECS 애플리케이션 모니터링|ECS 애플리케이션 모니터링]]
- [[#6. 실시간 알림 설정|실시간 알림 설정]]

---

## 1. 현재 파이프라인 상태: CI/CD 구성 현황

> [!note] 현재 상태
> - **프로젝트**: pposiraegi-ecommerce-msa
> - **CI/CD 도구**: GitHub Actions (예정)
> - **인프라**: ECR + ECS Fargate
> - **파이프라인 단계**: Build → Push to ECR → Deploy to ECS

### 💡 현재 구현 현황

#### 📋 구성된 리소스

> [!example] 현재 배포 구성
> 1. **문제**: CI/CD 파이프라인 미구현
> 2. **감지**: GitHub Actions 워크플로우 파일 미존재
> 3. **조치**: GitHub Actions 또는 AWS CodePipeline 도입 필요
> 4. **결과**: 수동 배포 필요

**현재 구성된 AWS 리소스**:
- ✅ ECR 리포지토리 (api-gateway, user-service, product-service, order-service)
- ✅ ECS 클러스터 및 서비스
- ✅ CloudWatch 로그 그룹
- ❌ CodePipeline (미구현)
- ❌ CodeBuild (미구현)

---

## 2. AWS 모니터링 도구 개요: 사용 가능한 서비스

### 💡 AWS 모니터링 서비스 비교

| 서비스 | 용도 | 가격 | 복잡도 | 추천도 |
|--------|------|------|--------|--------|
| **CloudWatch Logs** | 로그 수집 및 분석 | 저렴함 | 낮음 | ⭐⭐⭐⭐⭐ |
| **CloudWatch Metrics** | 지표 대시보드 | 무료 계층 있음 | 낮음 | ⭐⭐⭐⭐⭐ |
| **CloudWatch Alarms** | 임계값 기반 알림 | 저렴함 | 낮음 | ⭐⭐⭐⭐⭐ |
| **X-Ray** | 분산 추적 | 비쌈 | 중간 | ⭐⭐⭐ |
| **CodePipeline Console** | 파이프라인 상태 | 무료 | 낮음 | ⭐⭐⭐⭐⭐ |
| **CodeBuild Logs** | 빌드 로그 | 무료 | 낮음 | ⭐⭐⭐⭐⭐ |

---

## 3. CodePipeline 모니터링: 파이프라인 실행 상태 추적

> [!note] CodePipeline 모니터링
> - **자동화**: 파이프라인 각 단계의 성공/실패 추적
> - **시각화**: AWS Console 또는 CloudWatch 대시보드
> - **알림**: SNS를 통한 실시간 알림

### 💡 CodePipeline 설정 가이드

#### 📋 1. CodePipeline 생성 (Terraform)

> [!example] infrastructure/codepipeline.tf 생성
> ```hcl
> ###############################################################
> # CodePipeline
> ###############################################################
> 
> resource "aws_codepipeline" "main" {
>   name     = "${var.project_name}-pipeline"
>   role_arn = aws_iam_role.codepipeline_role.arn
> 
>   artifact_store {
>     location = aws_s3_bucket.artifacts.id
>     type     = "S3"
>   }
> 
>   stage {
>     name = "Source"
> 
>     action {
>       name             = "Source"
>       category         = "Source"
>       owner            = "ThirdParty"
>       provider         = "GitHub"
>       version          = "1"
>       output_artifacts = ["source_output"]
> 
>       configuration = {
>         Owner      = "Goorm4I"
>         Repo       = "pposiraegi-ecommerce-msa"
>         Branch     = "main"
>         OAuthToken = var.github_oauth_token
>       }
>     }
>   }
> 
>   stage {
>     name = "Build"
> 
>     action {
>       name            = "Build"
>       category        = "Build"
>       owner           = "AWS"
>       provider        = "CodeBuild"
>       input_artifacts = ["source_output"]
>       version         = "1"
> 
>       configuration = {
>         ProjectName = aws_codebuild_project.main.name
>       }
>     }
>   }
> 
>   stage {
>     name = "Deploy"
> 
>     action {
>       name            = "Deploy"
>       category        = "Deploy"
>       owner           = "AWS"
>       provider        = "ECS"
>       input_artifacts = ["build_output"]
>       version         = "1"
> 
>       configuration = {
>         ClusterName = aws_ecs_cluster.main.name
>         ServiceName = aws_ecs_service.msa["api-gateway"].name
>         FileName    = "imagedefinitions.json"
>       }
>     }
>   }
> }
> 
> ###############################################################
> # CodePipeline IAM Role
> ###############################################################
> 
> resource "aws_iam_role" "codepipeline_role" {
>   name = "${var.project_name}-codepipeline-role"
> 
>   assume_role_policy = jsonencode({
>     Version = "2012-10-17"
>     Statement = [{
>       Effect    = "Allow"
>       Principal = { Service = "codepipeline.amazonaws.com" }
>       Action    = "sts:AssumeRole"
>     }]
>   })
> }
> 
> resource "aws_iam_role_policy_attachment" "codepipeline_policy" {
>   role       = aws_iam_role.codepipeline_role.name
>   policy_arn = "arn:aws:iam::aws:policy/AWSCodePipelineFullAccess"
> }
> 
> ###############################################################
> # S3 Bucket for Artifacts
> ###############################################################
> 
> resource "aws_s3_bucket" "artifacts" {
>   bucket = "${var.project_name}-artifacts"
> 
>   versioning {
>     enabled = true
>   }
> 
>   lifecycle_rule {
>     enabled = true
> 
>     expiration {
>       days = 30
>     }
>   }
> }
> ```

#### 📋 2. CodePipeline 모니터링 방법

> [!example] Console에서 모니터링
> 1. AWS Console → CodePipeline → 파이프라인 선택
> 2. **Execution history**: 최근 실행 기록 확인
> 3. **Stage details**: 각 단계별 상세 정보
> 4. **Action details**: 개별 액션의 로그 및 에러 메시지

> [!example] CloudWatch로 모니터링
> ```bash
> # 파이프라인 실행 성공/실패 카운트
> aws cloudwatch get-metric-statistics \
>   --namespace AWS/CodePipeline \
>   --metric-name ExecutionsSucceeded \
>   --dimensions Name=Pipeline,Value=pposiraegi-pipeline \
>   --start-time 2026-04-01T00:00:00Z \
>   --end-time 2026-04-14T23:59:59Z \
>   --period 86400 \
>   --statistics Sum
> ```

---

## 4. CodeBuild 모니터링: 빌드 로그 및 지표

> [!note] CodeBuild 모니터링
> - **실시간 로그**: 빌드 진행 상황 실시간 확인
> - **지표**: 빌드 시간, 성공률, 실패율
> - **알림**: 빌드 실패 시 즉시 알림

### 💡 CodeBuild 설정 가이드

#### 📋 1. CodeBuild 프로젝트 생성 (Terraform)

> [!example] infrastructure/codebuild.tf 추가
> ```hcl
> ###############################################################
> # CodeBuild Project
> ###############################################################
> 
> resource "aws_codebuild_project" "main" {
>   name          = "${var.project_name}-build"
>   description   = "Build project for pposiraegi e-commerce"
>   build_timeout = "60"
>   service_role  = aws_iam_role.codebuild_role.arn
> 
>   artifacts {
>     type = "CODEPIPELINE"
>   }
> 
>   source {
>     type      = "CODEPIPELINE"
>     buildspec = "buildspec.yml"
>   }
> 
>   environment {
>     compute_type    = "BUILD_GENERAL1_SMALL"
>     image           = "aws/codebuild/amazonlinux2-aarch64-standard:5.0"
>     type            = "ARM_CONTAINER"
>     privileged_mode = true
> 
>     environment_variable {
>       name  = "AWS_ACCOUNT_ID"
>       value = var.aws_account_id
>     }
>   }
> 
>   logs_config {
>     s3_logs {
>       status   = "ENABLED"
>       location = "${aws_s3_bucket.artifacts.id}/build-logs"
>     }
>   }
> }
> 
> ###############################################################
> # CodeBuild IAM Role
> ###############################################################
> 
> resource "aws_iam_role" "codebuild_role" {
>   name = "${var.project_name}-codebuild-role"
> 
>   assume_role_policy = jsonencode({
>     Version = "2012-10-17"
>     Statement = [{
>       Effect    = "Allow"
>       Principal = { Service = "codebuild.amazonaws.com" }
>       Action    = "sts:AssumeRole"
>     }]
>   })
> }
> 
> resource "aws_iam_role_policy_attachment" "codebuild_base" {
>   role       = aws_iam_role.codebuild_role.name
>   policy_arn = "arn:aws:iam::aws:policy/CodeBuildBasePolicy-AWSCodeBuild-AdminAccess"
> }
> 
> resource "aws_iam_role_policy" "codebuild_ecr" {
>   name = "${var.project_name}-codebuild-ecr"
>   role = aws_iam_role.codebuild_role.id
> 
>   policy = jsonencode({
>     Version = "2012-10-17"
>     Statement = [
>       {
>         Effect = "Allow"
>         Action = [
>           "ecr:GetAuthorizationToken",
>           "ecr:BatchCheckLayerAvailability",
>           "ecr:GetDownloadUrlForLayer",
>           "ecr:GetRepositoryPolicy",
>           "ecr:DescribeRepositories",
>           "ecr:ListImages",
>           "ecr:DescribeImages",
>           "ecr:BatchGetImage",
>           "ecr:InitiateLayerUpload",
>           "ecr:UploadLayerPart",
>           "ecr:CompleteLayerUpload",
>           "ecr:PutImage"
>         ]
>         Resource = "*"
>       }
>     ]
>   })
> }
> ```

#### 📋 2. buildspec.yml 작성

> [!example] backend/buildspec.yml
> ```yaml
> version: 0.2
> 
> phases:
>   install:
>     runtime-versions:
>       java: corretto21
>     commands:
>       - echo "Installing dependencies..."
>   
>   pre_build:
>     commands:
>       - echo "Logging in to Amazon ECR..."
>       - aws ecr get-login-password --region $AWS_DEFAULT_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com
>       - echo "ECR login complete"
>   
>   build:
>     commands:
>       - echo "Building Docker image..."
>       - cd backend
>       - chmod +x gradlew
>       - ./gradlew :user-service:bootJar :product-service:bootJar :order-service:bootJar :api-gateway:bootJar
>       - echo "Build complete"
>   
>   post_build:
>     commands:
>       - echo "Building and pushing Docker images..."
>       - for service in user-service product-service order-service api-gateway; do
>           echo "Building $service..."
>           cd $service
>           docker build -t $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/pposiraegi-$service:latest .
>           docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_DEFAULT_REGION.amazonaws.com/pposiraegi-$service:latest
>           cd ..
>         done
>       - echo "All images pushed successfully"
> 
> artifacts:
>   files:
>     - '**/*'
> ```

#### 📋 3. CodeBuild 모니터링 방법

> [!example] 빌드 로그 확인
> 1. AWS Console → CodeBuild → 빌드 프로젝트 선택
> 2. **Build history**: 빌드 실행 기록
> 3. **Build details**: 빌드 상세 정보 (시간, 지속시간, 상태)
> 4. **Logs**: 실시간 빌드 로그

> [!example] CloudWatch로 빌드 지표 확인
> ```bash
> # 빌드 시간 추적
> aws cloudwatch get-metric-statistics \
>   --namespace AWS/CodeBuild \
>   --metric-name BuildDuration \
>   --dimensions Name=ProjectName,Value=pposiraegi-build \
>   --start-time 2026-04-01T00:00:00Z \
>   --end-time 2026-04-14T23:59:59Z \
>   --period 86400 \
>   --statistics Average
> ```

---

## 5. ECS 애플리케이션 모니터링: 배포 후 모니터링

> [!note] ECS 모니터링
> - **배포 상태**: 새 버전 배치 진행 상황
> - **서비스 상태**: 서비스 가용성, CPU/Memory 사용량
> - **로그**: 애플리케이션 로그 (CloudWatch Logs)

### 💡 ECS 모니터링 설정

#### 📋 1. CloudWatch 대시보드 생성

> [!example] infrastructure/cloudwatch-dashboard.tf 추가
> ```hcl
> ###############################################################
> # CloudWatch Dashboard
> ###############################################################
> 
> resource "aws_cloudwatch_dashboard" "main" {
>   dashboard_name = "${var.project_name}-dashboard"
> 
>   dashboard_body = jsonencode({
>     widgets = [
>       {
>         type   = "metric"
>         x      = 0
>         y      = 0
>         width  = 12
>         height = 6
>         properties = {
>           metrics = [
>             ["AWS/ECS", "CPUUtilization", "ServiceName", "pposiraegi-api-gateway-service"],
>             [".", "CPUUtilization", "ServiceName", "pposiraegi-user-service"],
>             [".", "CPUUtilization", "ServiceName", "pposiraegi-product-service"],
>             [".", "CPUUtilization", "ServiceName", "pposiraegi-order-service"]
>           ]
>           period = 300
>           stat   = "Average"
>           region = "ap-southeast-2"
>           title  = "ECS CPU Utilization"
>         }
>       },
>       {
>         type   = "log"
>         x      = 0
>         y      = 6
>         width  = 24
>         height = 6
>         properties = {
>           logGroupName  = "/ecs/pposiraegi-api-gateway"
>           region        = "ap-southeast-2"
>           title         = "API Gateway Logs"
>           view          = "table"
>           columns       = ["@timestamp", "@message"]
>           startTime    = "PT1H"
>           endTime      = "PT0H"
>         }
>       }
>     ]
>   })
> }
> ```

#### 📋 2. ECS CloudWatch Alarms 설정

> [!example] infrastructure/ecs-alarms.tf 추가
> ```hcl
> ###############################################################
> # CloudWatch Alarms for ECS
> ###############################################################
> 
> resource "aws_cloudwatch_metric_alarm" "cpu_high" {
>   alarm_name          = "${var.project_name}-cpu-high"
>   comparison_operator = "GreaterThanThreshold"
>   evaluation_periods  = "2"
>   metric_name         = "CPUUtilization"
>   namespace           = "AWS/ECS"
>   period              = "300"
>   statistic           = "Average"
>   threshold           = "80"
>   alarm_description   = "ECS CPU utilization > 80%"
>   datapoints_to_alarm = "2"
> 
>   dimensions {
>     name  = "ServiceName"
>     value = "pposiraegi-api-gateway-service"
>   }
> }
> 
> resource "aws_cloudwatch_metric_alarm" "memory_high" {
>   alarm_name          = "${var.project_name}-memory-high"
>   comparison_operator = "GreaterThanThreshold"
>   evaluation_periods  = "2"
>   metric_name         = "MemoryUtilization"
>   namespace           = "AWS/ECS"
>   period              = "300"
>   statistic           = "Average"
>   threshold           = "80"
>   alarm_description   = "ECS memory utilization > 80%"
>   datapoints_to_alarm = "2"
> 
>   dimensions {
>     name  = "ServiceName"
>     value = "pposiraegi-api-gateway-service"
>   }
> }
> ```

---

## 6. 실시간 알림 설정: 파이프라인 실패 시 알림

> [!note] 알림 설정
> - **SNS Topic**: 알림 메시지 전달
> - **Email/SMS/Slack**: 다양한 채널로 알림 수신
> - **EventBridge**: 파이프라인 이벤트 감지

### 💡 알림 설정 가이드

#### 📋 1. SNS Topic 생성 (Terraform)

> [!example] infrastructure/sns.tf 추가
> ```hcl
> ###############################################################
> # SNS Topic for Pipeline Notifications
> ###############################################################
> 
> resource "aws_sns_topic" "pipeline_alerts" {
>   name = "${var.project_name}-pipeline-alerts"
> }
> 
> resource "aws_sns_topic_subscription" "email" {
>   topic_arn = aws_sns_topic.pipeline_alerts.arn
>   protocol  = "email"
>   endpoint  = "devops@example.com"
> }
> 
> # Slack 알림 (선택사항)
> resource "aws_sns_topic_subscription" "slack" {
>   topic_arn = aws_sns_topic.pipeline_alerts.arn
>   protocol  = "https"
>   endpoint  = "https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK"
> }
> ```

#### 📋 2. EventBridge Rule 생성

> [!example] infrastructure/eventbridge.tf 추가
> ```hcl
> ###############################################################
> # EventBridge Rule for Pipeline Events
> ###############################################################
> 
> resource "aws_cloudwatch_event_rule" "pipeline_failed" {
>   name        = "${var.project_name}-pipeline-failed"
>   description = "Triggered when pipeline execution fails"
> 
>   event_pattern = jsonencode({
>     source      = ["aws.codepipeline"]
>     detail-type = ["CodePipeline Pipeline Execution State Change"]
>     detail = {
>       state    = ["FAILED"]
>       pipeline = ["pposiraegi-pipeline"]
>     }
>   })
> }
> 
> resource "aws_cloudwatch_event_target" "sns_target" {
>   rule           = aws_cloudwatch_event_rule.pipeline_failed.name
>   target_id      = "sns-target"
>   arn            = aws_sns_topic.pipeline_alerts.arn
> }
> ```

---

## 📊 모니터링 대시보드 구성 예시

### 💡 CloudWatch 대시보드 위젯

| 위젯 유형 | 모니터링 항목 | 갱신 주기 |
|-----------|---------------|-----------|
| **Line Chart** | 파이프라인 실행 시간 추이 | 5분 |
| **Number Widget** | 최근 24시간 성공/실패 횟수 | 1분 |
| **Log Widget** | 최근 빌드 로그 | 30초 |
| **Gauge** | ECS CPU/Memory 사용량 | 1분 |
| **Bar Chart** | 각 서비스별 배포 횟수 | 5분 |

---

## 🚀 추천 모니터링 구성

### 💡 단계별 구현 로드맵

#### 📋 Phase 1: 기본 모니터링 (즉시)

> [!example] 1주 완료
> - [ ] CloudWatch Logs 활성화 (이미 구성됨)
> - [ ] CodePipeline 생성
> - [ ] CodeBuild 생성
> - [ ] 기본 CloudWatch 대시보드 생성

#### 📋 Phase 2: 알림 시스템 (2주)

> [!example] 2주 완료
> - [ ] SNS Topic 생성
> - [ ] 이메일 알림 설정
> - [ ] EventBridge Rule 생성
> - [ ] Slack 알림 통합 (선택사항)

#### 📋 Phase 3: 고급 모니터링 (1개월)

> [!example] 1개월 완료
> - [ ] X-Ray 분산 추적 도입
> - [ ] CloudWatch Synthetics 설정
> - [ ] 사용자 정의 지표 추가
> - [ ] 이상 탐지(Anomaly Detection) 설정

---

## ✅ 요약

### 📋 지원되는 모니터링 기능

1. **파이프라인 모니터링**
   - ✅ CodePipeline 실행 상태
   - ✅ CodeBuild 빌드 로그
   - ✅ 배포 진행 상황

2. **애플리케이션 모니터링**
   - ✅ ECS 서비스 상태 (이미 구성됨)
   - ✅ CloudWatch Logs (이미 구성됨)
   - ✅ CPU/Memory 지표

3. **알림 시스템**
   - ⏳ SNS 기반 알림 (구현 필요)
   - ⏳ 이메일/Slack 알림 (구현 필요)
   - ⏳ 실시간 알림 (구현 필요)

### 🎯 다음 단계

1. GitHub Actions 또는 AWS CodePipeline 선택
2. Terraform으로 파이프라인 리소스 추가
3. CloudWatch 대시보드 및 알림 설정
4. 모니터링 가이드 문서화