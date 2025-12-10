---
title: Harbor - 프로메테우스 연동 트러블슈팅
tags:
  - prometheus
  - harbor
  - kubernetes
  - troubleshooting
  - devops
  - monitoring
aliases:
  - Harbor-연동-문제해결
  - 프로메테우스-Harbor-실습
date: 2025-12-08
category: K8s_Deep_Dive/실습
status: 완성
priority: 높음
---

# 🚨 Harbor - 프로메테우스 연동 트러블슈팅

## 📑 목차
- [[#1. 문제 상황|문제 상황]]
- [[#2. 핵심 문제 분석|핵심 문제 분석]]
- [[#3. 해결 방법|해결 방법]]
- [[#4. 실습 한계점|실습 한계점]]
- [[#5. 학습 포인트|학습 포인트]]

---

## 1. 문제 상황

### 💻 실습 환경
- **강의**: 프로메테우스 학습 키트 - ch6.3 Harbor 외부 연동
- **목표**: 쿠버네티스 내부 프로메테우스가 외부 Harbor에서 메트릭 수집
- **플랫폼**: macOS (M1/M2/Intel)
- **도구**: Vagrant + VirtualBox

### 🚨 발생한 문제들

#### 문제 1: VirtualBox 실행 실패
```bash
irix@irix 1.vagrantup-harbor % vagrant up
==> harbor: Setting the name of the VM: 6.3.harbor(github_SysNet4Admin)
There was an error while executing `VBoxManage`

Stderr: VBoxManage: error: The object functionality is limited
VBoxManage: error: Details: code E_ACCESSDENIED (0x80070005), component MachineWrap, interface IMachine
```

**원인**: 
- macOS 보안 설정에서 VirtualBox 커널 확장 차단
- 이전 VM 세션이 비정상 종료되어 잠금 상태
- VirtualBox 버전과 macOS 호환성 문제

#### 문제 2: Vagrant 디렉토리 구조 혼동
```bash
irix@irix 6.3 % vagrant up
A Vagrant environment or target machine is required to run this command.
```

**원인**: Vagrantfile이 하위 디렉토리(`1.vagrantup-harbor`)에 있어 상위에서 실행 불가

#### 문제 3: YAML 설정 파일 헤더 누락
```bash
error: error validating "4.add-harbor-to-the-prometheus.yaml": 
error validating data: [apiVersion not set, kind not set]
```

**원인**: ConfigMap의 필수 헤더 정보(`apiVersion`, `kind`, `metadata`) 누락

---

## 2. 핵심 문제 분석

### 🔍 근본 원인
1. **인프라 문제**: VirtualBox와 macOS 호환성 이슈
2. **설정 문제**: YAML 파일 구조 손상
3. **아키텍처 이해**: 외부 메트릭 수집 구조 미숙

### 💡 문제 해결 접근법
- **우선순위**: 학습 목표(프로메테우스 외부 연동) 달성이 핵심
- **대안**: VM 설치 대신 Docker를 활용한 실습 환경 구성
- **핵심**: 네트워크 연결성과 메트릭 수집 구조 이해

---

## 3. 해결 방법

### 🛠️ 해결책 1: macOS VirtualBox 문제 (근본 해결)

#### A. 보안 설정 확인
1. **시스템 설정** → **개인정보 보호 및 보안** → **보안** 섹션
2. "Oracle America, Inc." 시스템 소프트웨어 차단 여부 확인
3. 차단되었다면 **[허용]** 클릭 후 재부팅

#### B. VirtualBox 강제 초기화
```bash
# VirtualBox GUI에서 문제 VM 삭제
# 터미널에서 강제 삭제
vagrant destroy -f
vagrant up
```

#### C. VirtualBox 재설치
1. 기존 VirtualBox 완전 삭제 (`VirtualBox_Uninstall.tool` 사용)
2. 최신 버전 다운로드 및 설치
3. 설치 시 보안 승인 필수

### 🎯 해결책 2: Docker 기반 대안 실습 (추천)

#### A. 가벼운 메트릭 타겟 생성
```bash
# Harbor 대신 간단한 메트릭 소스 실행
docker run -d -p 9090:9090 --name fake-harbor prom/prometheus

# 또는 node-exporter 사용
docker run -d -p 9100:9100 prom/node-exporter
```

#### B. 프로메테우스 설정 수정
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
  namespace: default
data:
  prometheus.yml: |
    scrape_configs:
    # 기존 설정들...
    
    # begin; external app harbor (실습용)
    - job_name: harbor
      metrics_path: /metrics
      static_configs:
      - targets:
        - host.docker.internal:9090  # 내 맥북을 외부 서버로 지정
    # end;
```

#### C. 설정 적용 및 재시작
```bash
# 설정 적용
kubectl apply -f 4.add-harbor-to-the-prometheus.yaml

# 프로메테우스 포드 재시작 (새 설정 로드)
kubectl delete pod -l app=prometheus-server

# 포트 충돌 피해서 접속
kubectl port-forward service/prometheus-server 8080:80
```

### 📊 해결책 3: YAML 파일 복구
```yaml
apiVersion: v1  # 필수 헤더
kind: ConfigMap # 필수 헤더
metadata:       # 필수 헤더
  name: prometheus-config
  namespace: default
data:
  prometheus.yml: |
    # 기존 설정 내용 그대로...
```

---

## 4. 실습 한계점

### ⚠️ 현재 접근법의 제약사항

#### A. 보안 무시
- **실습**: HTTP 평문 통신
- **실제**: Harbor는 HTTPS + 인증서 필요
- **실무 설정 예시**:
```yaml
- job_name: harbor
  scheme: https
  tls_config:
    ca_file: /etc/prometheus/secrets/harbor-ca.crt
    insecure_skip_verify: true
  static_configs:
  - targets:
    - 192.168.1.63:443
```

#### B. 메트릭 데이터 불일치
| 구분 | 실습 데이터 | 실제 Harbor 데이터 |
|------|-------------|-------------------|
| 내용 | Go 런타임 정보 | Harbor 비즈니스 메트릭 |
| 예시 | `go_memstats_alloc_bytes` | `harbor_project_count_total` |
| 의미 | 프로메테우스 자체 상태 | 이미지 저장소 상태 |

#### C. 진짜 Harbor 메트릭 예시
```
harbor_project_count_total      5           # 프로젝트 수
harbor_repo_count_total         12          # 리포지토리 수  
harbor_storage_usage_bytes      5368709120  # 저장 용량 (5GB)
harbor_up                       1           # 서비스 상태
```

---

## 5. 학습 포인트

### ✅ 성공적으로 학습한 것들

#### A. 외부 메트릭 수집 아키텍처
- **개념**: 쿠버네티스 내부 → 외부 시스템 데이터 수집
- **방법**: `static_configs` + `targets` 설정
- **네트워크**: 클러스터 외부 접근 가능성 확인

#### B. 트러블슈팅 스킬
- **문제 분석**: 에러 메시지 → 근본 원인 파악
- **우회 전략**: 환경 제약 → 대안 솔루션 도출
- **설정 관리**: ConfigMap 수정 → Pod 재시작 필수

#### C. 실무 응용 가능성
```yaml
# 패턴: 모든 외부 시스템 연동에 적용 가능
- job_name: external-service
  static_configs:
  - targets:
    - external-server.company.com:9090
```

### 🎯 핵심 교훈

#### A. 인프라 != 핵심 학습
- VM 설치 문제 ≠ 프로메테우스 이해 부족
- 환경 구축 ≠ 모니터링 개념 학습
- **중요한 것**: 데이터 흐름과 설정 구조 이해

#### B. 실무 관점
- **CKA/CKAD 시험**: ConfigMap 수정 → Pod 재생성 패턴 중요
- **운영 환경**: 인증서, HTTPS, 방화벽 설정 필수
- **모니터링**: 메트릭 종류와 의미 파악이 핵심

### 💪 자신감 회복 포인트
> "이건 실력 문제가 아니라, 환경(macOS)과 도구(VirtualBox)의 호환성 문제입니다."

1. **문제 해결 능력**: 에러를 보고 근본 원인을 찾아냄
2. **유연성**: VM 안 되면 Docker로 우회
3. **구조 이해**: 외부 연동의 본질을 파악
4. **실무 센스**: 실습 한계점까지 정확히 인식

---

## 📝 향후 실습 가이드

### 🚀 추천 학습 순서
1. **현재 성과 정리**: 외부 연동 구조 이해 완료 ✅
2. **다음 단계**: 프로메테우스 쿼리(PromQL) 학습
3. **심화 과정**: 실제 Harbor 구축 시 보안 설정 적용

### 🛡️ 실무 적용 시 체크리스트
- [ ] HTTPS 인증서 설정
- [ ] 방화벽 포트 개방
- [ ] 메트릭 엔드포인트 확인  
- [ ] 네트워크 정책 검토
- [ ] 모니터링 데이터 검증

> **결론**: "도로 포장 공사"에 막혀 "운전 연수"를 못할 뻔했지만, 우회로를 찾아 목적지에 도달했습니다. 이제 프로메테우스 외부 연동의 핵심을 완전히 이해하셨습니다! 🎉