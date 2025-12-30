---
title: Helm 핵심 명령어 완벽 정리 - 꼭 외워야 할 것들
tags:
  - helm
  - kubernetes
  - package-manager
  - chart
  - deployment
  - devops
aliases:
  - helm-commands
  - 헬름명령어
  - 헬름기본
date: 2025-11-28
category: K8s_Deep_Dive/도구
status: 완성
priority: 높음
---

# ⚡ Helm 핵심 명령어 완벽 정리

## 📑 목차
- [[#🎯 Helm 기본 개념|Helm 기본 개념]]
- [[#📦 Repository 관리 명령어|Repository 관리 명령어]]
- [[#🚀 설치/업그레이드/삭제 명령어|설치/업그레이드/삭제 명령어]]
- [[#🔍 조회/상태 확인 명령어|조회/상태 확인 명령어]]
- [[#⏮️ 롤백 및 히스토리 명령어|롤백 및 히스토리 명령어]]
- [[#⚙️ Chart 개발 명령어|Chart 개발 명령어]]
- [[#💡 실전 필수 패턴|실전 필수 패턴]]

---

## 🎯 Helm 기본 개념 (꼭 알아야 할 용어들)

### 📋 핵심 용어 암기

| 용어 | 의미 | 비유 |
|------|------|------|
| **Chart** | 쿠버네티스 앱 패키지 | 앱 설치파일 (apk, deb) |
| **Release** | 설치된 Chart 인스턴스 | 실제 설치된 앱 |
| **Repository** | Chart들이 저장된 곳 | 앱스토어 |
| **Values** | 설정값들 | 앱 설정 파일 |

> [!note] 핵심 개념
> **Chart + Values = Release** (패키지 + 설정 = 실제 설치)

### 📋 Chart 구조 (외워둬야 할 필수 파일들)

```
my-app-chart/
├── Chart.yaml          # Chart 메타데이터 (이름, 버전)
├── values.yaml         # 기본 설정값 ⭐ 가장 중요!
├── charts/             # 의존성 차트들
├── templates/          # 쿠버네티스 YAML 템플릿들
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── ingress.yaml
│   └── _helpers.tpl    # 공통 템플릿 함수
└── .helmignore         # 패키징 시 제외할 파일들
```

---

## 📦 Repository 관리 명령어 (꼭 외우기!)

### 🔥 필수 암기 명령어

```bash
# 1. 저장소 추가 (가장 많이 씀!)
helm repo add [저장소이름] [URL]

# 2. 저장소 목록 확인
helm repo list

# 3. 저장소 업데이트 (새 Chart 버전 확인)
helm repo update

# 4. Chart 검색
helm search repo [검색어]
```

### 💡 실전 필수 저장소들 (외워두기!)

```bash
# 가장 많이 쓰는 저장소들
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add stable https://charts.helm.sh/stable
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add metallb https://metallb.github.io/metallb
```

### 📋 Repository 관리 패턴

```bash
# 새 환경 셋업할 때 루틴
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
helm search repo nginx  # 사용 가능한 Chart 찾기
```

---

## 🚀 설치/업그레이드/삭제 명령어 (핵심!)

### 🔥 설치 명령어 패턴

```bash
# 1. 기본 설치
helm install [릴리즈이름] [차트이름]
helm install my-nginx bitnami/nginx

# 2. 네임스페이스 지정 설치 ⭐ 자주 씀
helm install [릴리즈이름] [차트이름] -n [네임스페이스] --create-namespace

# 3. 설정값 변경하며 설치 ⭐ 가장 중요!
helm install [릴리즈이름] [차트이름] --set [key=value]
helm install my-nginx bitnami/nginx --set replicaCount=3

# 4. 설정 파일로 설치 ⭐ 운영에서 필수!
helm install [릴리즈이름] [차트이름] -f [values파일]
helm install my-nginx bitnami/nginx -f prod-values.yaml

# 5. 여러 설정 조합
helm install my-nginx bitnami/nginx \
  --set replicaCount=3 \
  --set service.type=LoadBalancer \
  -f prod-values.yaml \
  -n production \
  --create-namespace
```

### 🔥 업그레이드 명령어 (꼭 외우기!)

```bash
# 1. Chart 버전 업그레이드
helm upgrade [릴리즈이름] [차트이름]

# 2. 설정 변경 업그레이드
helm upgrade my-nginx bitnami/nginx --set image.tag=1.22.0

# 3. 설정 파일로 업그레이드
helm upgrade my-nginx bitnami/nginx -f new-values.yaml

# 4. 강제 업그레이드 (문제 해결용)
helm upgrade [릴리즈이름] [차트이름] --force

# 5. 설치가 안되어 있으면 설치, 있으면 업그레이드
helm upgrade --install [릴리즈이름] [차트이름]  # ⭐ 자주 씀!
```

### 🗑️ 삭제 명령어

```bash
# 1. 릴리즈 삭제
helm uninstall [릴리즈이름]

# 2. 네임스페이스 지정 삭제
helm uninstall [릴리즈이름] -n [네임스페이스]

# 3. 삭제 시 히스토리도 완전 제거
helm uninstall [릴리즈이름] --no-hooks
```

---

## 🔍 조회/상태 확인 명령어 (디버깅 필수!)

### 🔥 상태 확인 (꼭 외우기!)

```bash
# 1. 설치된 릴리즈 목록 ⭐ 가장 많이 씀!
helm list
helm ls  # 줄임말

# 2. 모든 네임스페이스 릴리즈 확인
helm list -A

# 3. 특정 릴리즈 상태 확인
helm status [릴리즈이름]

# 4. 릴리즈에 사용된 설정값 확인 ⭐ 디버깅 필수!
helm get values [릴리즈이름]

# 5. 실제 배포된 매니페스트 확인
helm get manifest [릴리즈이름]

# 6. 모든 정보 확인
helm get all [릴리즈이름]
```

### 📋 Chart 정보 확인

```bash
# 1. Chart 정보 보기
helm show chart [차트이름]

# 2. Chart의 기본 설정값 보기 ⭐ 중요!
helm show values [차트이름]
helm show values bitnami/nginx  # nginx 기본 설정 확인

# 3. Chart 전체 정보
helm show all [차트이름]

# 4. Chart 버전 목록
helm search repo [차트이름] --versions
```

### 🔍 템플릿 렌더링 (설치 전 미리보기)

```bash
# 1. 실제 배포될 YAML 미리보기 ⭐ 매우 유용!
helm template [릴리즈이름] [차트이름]

# 2. 설정값 적용해서 미리보기
helm template my-nginx bitnami/nginx --set replicaCount=3

# 3. 설정 파일 적용해서 미리보기
helm template my-nginx bitnami/nginx -f prod-values.yaml
```

---

## ⏮️ 롤백 및 히스토리 명령어 (운영 필수!)

### 🔄 롤백 명령어 (꼭 외우기!)

```bash
# 1. 이전 버전으로 롤백 ⭐ 응급상황 필수!
helm rollback [릴리즈이름]

# 2. 특정 리비전으로 롤백
helm rollback [릴리즈이름] [리비전번호]
helm rollback my-nginx 2  # 2번 리비전으로 롤백

# 3. 롤백 과정 확인
helm rollback [릴리즈이름] [리비전번호] --dry-run
```

### 📚 히스토리 관리

```bash
# 1. 릴리즈 히스토리 확인 ⭐ 롤백 전 필수!
helm history [릴리즈이름]

# 2. 상세 히스토리 확인
helm history [릴리즈이름] --max [개수]

# 예시 히스토리 출력
# REVISION  UPDATED                   STATUS        CHART           DESCRIPTION
# 1         Tue Nov 28 10:00:00 2023  superseded    nginx-13.2.23   Install complete
# 2         Tue Nov 28 11:00:00 2023  deployed      nginx-13.2.24   Upgrade complete
```

---

## ⚙️ Chart 개발 명령어 (개발자용)

### 🛠️ Chart 생성 및 개발

```bash
# 1. 새 Chart 생성
helm create [차트이름]
helm create my-app

# 2. Chart 문법 검사 ⭐ 배포 전 필수!
helm lint [차트경로]
helm lint ./my-app

# 3. Chart 패키징
helm package [차트경로]
helm package ./my-app

# 4. 의존성 관리
helm dependency update [차트경로]
helm dependency list [차트경로]
```

### 📦 로컬 Chart 테스트

```bash
# 1. 로컬 Chart 설치
helm install test-app ./my-app

# 2. 로컬 Chart 템플릿 확인
helm template test-app ./my-app

# 3. 설정값과 함께 로컬 Chart 테스트
helm install test-app ./my-app -f test-values.yaml --dry-run
```

---

## 💡 실전 필수 패턴 (외워두면 유용!)

### 🔥 환경별 배포 패턴

```bash
# 1. 개발 환경 배포
helm upgrade --install myapp-dev ./chart \
  -f values-dev.yaml \
  -n development \
  --create-namespace

# 2. 스테이징 환경 배포
helm upgrade --install myapp-staging ./chart \
  -f values-staging.yaml \
  -n staging \
  --create-namespace

# 3. 프로덕션 환경 배포 (신중하게!)
helm upgrade --install myapp-prod ./chart \
  -f values-prod.yaml \
  -n production \
  --create-namespace \
  --wait \
  --timeout=10m
```

### 🚨 트러블슈팅 패턴

```bash
# 1. 설치 실패 시 확인 순서
helm list -A                    # 릴리즈 상태 확인
helm status [릴리즈이름]        # 상태 상세 확인
helm get values [릴리즈이름]    # 설정값 확인
kubectl get events              # 쿠버네티스 이벤트 확인

# 2. 업그레이드 실패 시 롤백
helm history [릴리즈이름]       # 히스토리 확인
helm rollback [릴리즈이름]      # 이전 버전으로 롤백

# 3. Chart 문제 해결
helm lint ./chart               # Chart 문법 검사
helm template test ./chart      # 템플릿 렌더링 확인
```

### 📋 모니터링 패턴

```bash
# 1. 전체 릴리즈 상태 모니터링
helm list -A
kubectl get pods -A

# 2. 특정 릴리즈 상세 모니터링
helm status myapp
helm get values myapp
kubectl logs -l app=myapp -f

# 3. 업그레이드 진행상황 모니터링
helm upgrade myapp ./chart --wait --timeout=5m
kubectl rollout status deployment/myapp
```

### ⚙️ 설정값 관리 패턴

```bash
# 1. 기본값 확인 후 커스터마이징
helm show values bitnami/nginx > values.yaml
# values.yaml 편집 후
helm install my-nginx bitnami/nginx -f values.yaml

# 2. 환경변수로 설정값 전달
helm install my-nginx bitnami/nginx \
  --set image.tag=${APP_VERSION} \
  --set ingress.hostname=${DOMAIN_NAME}

# 3. 여러 설정 파일 조합
helm install my-nginx bitnami/nginx \
  -f values-base.yaml \
  -f values-prod.yaml \
  --set replicaCount=5
```

---

## 🎯 암기 체크리스트

### ✅ 기본 명령어 (반드시 외우기!)

- [ ] `helm repo add/list/update`
- [ ] `helm install/upgrade/uninstall`
- [ ] `helm list/status`
- [ ] `helm get values/manifest`
- [ ] `helm rollback/history`

### ✅ 자주 쓰는 옵션들

- [ ] `--set key=value` (설정값 변경)
- [ ] `-f values.yaml` (설정 파일 사용)
- [ ] `-n namespace --create-namespace` (네임스페이스 지정)
- [ ] `--upgrade --install` (설치 또는 업그레이드)
- [ ] `--dry-run` (실제 실행 안 하고 확인)
- [ ] `--wait --timeout=5m` (완료 대기)

### ✅ 트러블슈팅 명령어

- [ ] `helm template` (배포 전 미리보기)
- [ ] `helm lint` (Chart 문법 검사)
- [ ] `helm get all` (모든 정보 확인)
- [ ] `helm history` (히스토리 확인)

> [!tip] 학습 팁
> 1. **기본 4개 명령어**부터: `install`, `upgrade`, `list`, `uninstall`
> 2. **설정 변경 방법** 익히기: `--set`과 `-f` 옵션
> 3. **트러블슈팅 도구** 활용: `template`, `status`, `get values`
> 4. **환경별 배포 패턴** 익히기: dev/staging/prod 구분

---

## 📚 참고자료

- [Helm 공식 문서](https://helm.sh/docs/)
- [Helm Chart 개발 가이드](https://helm.sh/docs/chart_template_guide/)
- [Bitnami Charts](https://charts.bitnami.com/)
- [Artifact Hub](https://artifacthub.io/) - Chart 검색