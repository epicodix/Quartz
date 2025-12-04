---
title: M2 Mac Prometheus 설치 명령어 모음
tags:
  - Prometheus
  - Kubernetes
  - M2-Mac
  - 설치명령어
  - devops
aliases:
  - 프로메테우스설치
  - K8s모니터링
date: 2025-12-03
category: 1_가이드/가상화
status: 완성
priority: 높음
---

# 🎯 M2 Mac Prometheus 설치 명령어 모음

## 📋 검증된 설치 과정

### 1. Helm 저장소 설정

```bash
# 프로메테우스 커뮤니티 저장소 추가
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts

# 저장소 업데이트
helm repo update

# 사용 가능한 차트 확인
helm search repo prometheus
```

### 2. Prometheus 설치 (성공 확인됨)

```bash
# 최신 차트로 설치 (Kubernetes v1.30+ 호환)
helm install prometheus prometheus-community/prometheus \
  --namespace monitoring \
  --create-namespace \
  --set server.service.type=LoadBalancer \
  --set server.global.scrape_interval=15s
```

### 3. 설치 확인 명령어

```bash
# 파드 상태 확인
kubectl get pods -n monitoring

# 서비스 확인
kubectl get svc -n monitoring

# 프로메테우스 접근 (NodePort)
kubectl get svc prometheus-server -n monitoring
```

### 4. 접속 정보

```bash
# NodePort를 통한 접근
# http://192.168.1.10:31271

# 또는 포트포워딩
kubectl port-forward -n monitoring svc/prometheus-server 8080:80
# http://localhost:8080
```

## 🚨 문제 해결

### RBAC 오류 발생 시

```bash
# 기존 설치 제거
helm uninstall prometheus -n monitoring

# 최신 차트로 재설치 (위 명령어 사용)
```

### 구 버전 차트 오류

```bash
# 만약 edu/prometheus 차트에서 v1beta1 오류 발생 시
# "no matches for kind ClusterRole in version rbac.authorization.k8s.io/v1beta1"

# 해결: prometheus-community 차트 사용 (위 명령어)
```

## 💻 설치 완료 후 구성요소

- prometheus-server: 메트릭 수집 및 저장
- prometheus-alertmanager: 알림 관리  
- prometheus-node-exporter: 노드 메트릭 수집 (4개 노드)
- prometheus-pushgateway: 배치 작업 메트릭
- prometheus-kube-state-metrics: K8s 오브젝트 메트릭

## 📊 접속 정보

**프로메테우스 웹 UI**: http://192.168.1.10:31271