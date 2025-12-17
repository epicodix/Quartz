# 05-02. Kubernetes 스토리지 개념 정리: PV, PVC, StorageClass 이해하기

> **🎯 목표**: "Pod가 죽어도 데이터는 살아남는다!" - 쿠버네티스 스토리지의 핵심을 쉽게 이해하기

## 🤔 **이런 고민 해본 적 있나요?**

```
😰 "Pod를 재시작했더니 업로드한 파일들이 다 사라졌어요!"
😱 "데이터베이스 Pod가 죽었는데 모든 데이터가 증발했어요!"
🤷 "Docker에서는 볼륨 마운트가 쉬웠는데, 쿠버네티스는 왜 이렇게 복잡해요?"
```

**바로 이런 문제를 해결하는 게 오늘 배울 스토리지입니다!**

## 📚 **이 문서에서 배우는 것**
1. [왜 쿠버네티스 스토리지가 필요한가?](#왜-필요한가)
2. [아파트 임대로 이해하는 스토리지 개념](#아파트-비유)
3. [핵심 4요소: PV, PVC, StorageClass, VolumeClaimTemplate](#핵심-4요소)
4. [기본 사용법과 자주 하는 실수들](#기본-사용법)

> 💡 **실습은 다음 문서에서**: 실제 따라하기는 [05-03 실습 예제 모음](05_03_Storage_실습_예제_모음.md)을 참고하세요!

---

## 📖 핵심 개념 정리

### 🏢 스토리지 아키텍처 (아파트 임대 비유)

```
🏪 StorageClass = "부동산 회사"
├── AWS EBS 매장 (고성능 SSD)
├── NFS 매장 (공유 스토리지)  
└── 로컬 디스크 매장 (빠르지만 노드 종속)

📋 PVC = "아파트 신청서"
├── 크기: 10GB 방 주세요
├── 사용 방식: 혼자 살 거예요 (RWO) vs 룸메이트와 (RWX)
└── 위치: 어느 매장에서든 상관없어요

🔑 PV = "실제 배정된 방"
├── 실제 스토리지: /dev/disk1 (203호)
├── 계약서: PVC와 1:1 바인딩
└── 상태: Available → Bound → Released

🏠 Pod = "입주자"
├── 이사: /data 폴더에 짐을 넣어요
├── 생활: 파일 저장, 읽기, 수정
└── 이사 후에도: 방(PV)은 그대로 남아있어요
```

### 🔄 동작 흐름

```
1. 📋 PVC 생성 → "10GB RWO 스토리지 주세요!"
2. 🏪 StorageClass → "어떤 종류? AWS EBS로 드릴게요"
3. 🔑 PV 자동 생성 → "여기 10GB EBS 볼륨이에요"
4. 🤝 바인딩 → PVC ↔ PV 연결
5. 🏠 Pod 마운트 → "/data에 연결 완료!"
```

---

## 🗄️ PersistentVolume (PV)

### 📝 정의
- **실제 스토리지 리소스**를 나타내는 클러스터 레벨 객체
- 관리자가 미리 프로비저닝하거나 StorageClass를 통해 동적으로 생성
- Pod과 독립적인 생명주기를 가짐

### 🔧 PV 기본 구조

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: my-pv
  labels:
    type: local
spec:
  capacity:
    storage: 10Gi                    # 용량
  accessModes:
  - ReadWriteOnce                   # 접근 모드
  persistentVolumeReclaimPolicy: Retain  # 회수 정책
  storageClassName: manual          # StorageClass
  hostPath:                         # 스토리지 타입
    path: /mnt/data
```

### 🚪 접근 모드 (Access Modes)

| 모드 | 축약 | 설명 | 사용 사례 |
|------|------|------|----------|
| ReadWriteOnce | RWO | 하나의 노드에서만 읽기/쓰기 | 데이터베이스, 개인 파일 |
| ReadOnlyMany | ROX | 여러 노드에서 읽기만 | 설정 파일, 정적 콘텐츠 |
| ReadWriteMany | RWX | 여러 노드에서 읽기/쓰기 | 공유 파일 시스템, 로그 |
| ReadWriteOncePod | RWOP | 하나의 Pod에서만 읽기/쓰기 | 단일 Pod 전용 |

### ♻️ 회수 정책 (Reclaim Policy)

```yaml
# Retain: PVC 삭제해도 PV 유지 (수동 정리 필요)
persistentVolumeReclaimPolicy: Retain

# Delete: PVC 삭제 시 PV도 자동 삭제
persistentVolumeReclaimPolicy: Delete

# Recycle: 데이터 삭제 후 재사용 (Deprecated)
persistentVolumeReclaimPolicy: Recycle
```

### 📊 PV 상태

```bash
# Available: 사용 가능한 상태
# Bound: PVC와 바인딩된 상태
# Released: PVC는 삭제되었지만 아직 회수되지 않은 상태
# Failed: 자동 회수 실패 상태

kubectl get pv
# NAME     CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM
# my-pv    10Gi       RWO            Retain           Bound    default/my-pvc
```

### 📋 PV 타입별 예시

#### HostPath (로컬 스토리지)
- **용도**: 개발/테스트 환경
- **특징**: 특정 노드의 디렉토리 사용
- **제한**: 해당 노드에서만 접근 가능

#### NFS (네트워크 스토리지)
- **용도**: 여러 Pod에서 공유
- **특징**: ReadWriteMany 지원
- **제한**: 네트워크 성능에 의존

#### 클라우드 스토리지 (AWS EBS, GCE PD 등)
- **용도**: 프로덕션 환경
- **특징**: 고성능, 자동 백업
- **제한**: 클라우드 종속

---

## 📋 PersistentVolumeClaim (PVC)

### 📝 정의
- **스토리지에 대한 사용자 요청**
- Pod가 필요한 스토리지 사양을 선언
- PV와 바인딩되어 실제 스토리지에 접근

### 🔧 PVC 기본 구조

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-pvc
  namespace: default
spec:
  accessModes:
  - ReadWriteOnce               # 접근 모드
  resources:
    requests:
      storage: 8Gi              # 요청 용량
  storageClassName: fast-ssd    # StorageClass 지정
  selector:                     # PV 선택 조건 (선택사항)
    matchLabels:
      type: ssd
```

### 📝 PVC 옵션 사용법

#### 기본 PVC (자동 매칭)
```yaml
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 3Gi
# StorageClass 생략 시 기본 SC 사용
```

#### StorageClass 지정
```yaml
spec:
  storageClassName: fast-ssd  # 특정 SC 사용
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 50Gi
```

#### 라벨 셀렉터 (수동 PV 선택)
```yaml
spec:
  selector:
    matchLabels:
      tier: premium        # 특정 라벨의 PV만 매칭
  resources:
    requests:
      storage: 10Gi
```

### 📊 PVC 상태 확인

```bash
# PVC 목록 확인
kubectl get pvc

# PVC 상세 정보
kubectl describe pvc my-pvc

# PVC 상태별 의미
# Pending: 적합한 PV를 찾지 못함
# Bound: PV와 성공적으로 바인딩됨
# Lost: 바인딩된 PV가 사라짐
```

---

## 🏪 StorageClass

### 📝 정의
- **스토리지의 "클래스" 또는 "프로파일"**을 정의
- 동적 프로비저닝을 위한 템플릿 역할
- 관리자가 다양한 서비스 수준의 스토리지를 제공

### 🔧 StorageClass 기본 구조

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast-ssd
provisioner: kubernetes.io/aws-ebs    # 프로비저너
parameters:                           # 프로비저너별 파라미터
  type: gp3
  iops: "3000"
  encrypted: "true"
reclaimPolicy: Delete                 # 기본 회수 정책
allowVolumeExpansion: true            # 볼륨 확장 허용
volumeBindingMode: WaitForFirstConsumer  # 바인딩 모드
```

### 🎛️ 주요 필드 설명

#### Provisioner (프로비저너)
```yaml
# AWS EBS
provisioner: kubernetes.io/aws-ebs

# Google Cloud Persistent Disk  
provisioner: kubernetes.io/gce-pd

# Azure Disk
provisioner: kubernetes.io/azure-disk

# NFS (외부 프로비저너)
provisioner: nfs-client-provisioner

# 로컬 스토리지 (프로비저너 없음)
provisioner: kubernetes.io/no-provisioner
```

#### Volume Binding Mode
```yaml
# Immediate: PVC 생성 즉시 바인딩
volumeBindingMode: Immediate

# WaitForFirstConsumer: Pod가 스케줄링될 때 바인딩
volumeBindingMode: WaitForFirstConsumer
```

### 📝 주요 StorageClass 유형

#### AWS EBS (클라우드 블록 스토리지)
```yaml
metadata:
  name: aws-ebs-gp3
provisioner: kubernetes.io/aws-ebs
parameters:
  type: gp3              # GP3 유형
  iops: "3000"           # IOPS 설정
  encrypted: "true"      # 암호화 사용
```
**특징**: 고성능, 자동 스냅샷, 암호화 지원

#### NFS (공유 네트워크 스토리지)
```yaml
metadata:
  name: nfs-storage  
provisioner: nfs.csi.k8s.io
parameters:
  server: 192.168.1.100
  path: /shared/data
```
**특징**: ReadWriteMany 지원, 여러 Pod 동시 접근

#### Local (로컬 디스크)
```yaml
metadata:
  name: local-storage
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
```
**특징**: 최고 성능, 노드 종속성

### 🏷️ 기본 StorageClass 설정

```bash
# 기본 StorageClass 설정
kubectl patch storageclass fast-ssd -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

# 기본 StorageClass 해제
kubectl patch storageclass fast-ssd -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'

# 기본 StorageClass 확인
kubectl get storageclass
# NAME               PROVISIONER             RECLAIMPOLICY   VOLUMEBINDINGMODE      ALLOWVOLUMEEXPANSION   AGE
# fast-ssd (default) kubernetes.io/aws-ebs   Delete          WaitForFirstConsumer   true                   5d
```

---

## 📄 VolumeClaimTemplate

### 📝 정의
- **StatefulSet에서 사용하는 PVC 템플릿**
- 각 Pod 인스턴스마다 고유한 PVC를 자동 생성
- 순서가 있는 스토리지 프로비저닝 제공

### 🔧 VolumeClaimTemplate 기본 구조

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: web
spec:
  serviceName: "nginx"
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx
        volumeMounts:
        - name: www
          mountPath: /usr/share/nginx/html
  volumeClaimTemplates:              # 핵심 부분!
  - metadata:
      name: www
    spec:
      accessModes:
      - ReadWriteOnce
      storageClassName: fast-ssd
      resources:
        requests:
          storage: 1Gi
```

### 📈 VolumeClaimTemplate 사용 사례

#### 1. MySQL 클러스터
```yaml
# mysql-statefulset.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mysql
spec:
  serviceName: mysql
  replicas: 3
  selector:
    matchLabels:
      app: mysql
  template:
    metadata:
      labels:
        app: mysql
    spec:
      containers:
      - name: mysql
        image: mysql:8.0
        env:
        - name: MYSQL_ROOT_PASSWORD
          value: "password"
        - name: MYSQL_USER
          value: "user"
        - name: MYSQL_PASSWORD
          value: "password"
        - name: MYSQL_DATABASE
          value: "testdb"
        volumeMounts:
        - name: mysql-storage
          mountPath: /var/lib/mysql
        - name: mysql-config
          mountPath: /etc/mysql/conf.d
      volumes:
      - name: mysql-config
        configMap:
          name: mysql-config
  volumeClaimTemplates:
  - metadata:
      name: mysql-storage
    spec:
      accessModes:
      - ReadWriteOnce
      storageClassName: fast-ssd
      resources:
        requests:
          storage: 20Gi
```

#### 2. Elasticsearch 클러스터
```yaml
# elasticsearch-statefulset.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: elasticsearch
spec:
  serviceName: elasticsearch
  replicas: 3
  selector:
    matchLabels:
      app: elasticsearch
  template:
    metadata:
      labels:
        app: elasticsearch
    spec:
      containers:
      - name: elasticsearch
        image: docker.elastic.co/elasticsearch/elasticsearch:8.10.0
        env:
        - name: discovery.type
          value: single-node
        - name: ES_JAVA_OPTS
          value: "-Xms512m -Xmx512m"
        volumeMounts:
        - name: es-data
          mountPath: /usr/share/elasticsearch/data
      initContainers:
      - name: fix-permissions
        image: busybox
        command: ["sh", "-c", "chown -R 1000:1000 /usr/share/elasticsearch/data"]
        volumeMounts:
        - name: es-data
          mountPath: /usr/share/elasticsearch/data
  volumeClaimTemplates:
  - metadata:
      name: es-data
    spec:
      accessModes:
      - ReadWriteOnce
      storageClassName: fast-ssd
      resources:
        requests:
          storage: 100Gi
```

### 📊 VolumeClaimTemplate 특징

#### 자동 PVC 생성
```bash
# StatefulSet 생성 후 PVC 확인
kubectl get pvc

# 예상 결과: 각 Pod마다 PVC 자동 생성
# NAME           STATUS   VOLUME                CAPACITY   ACCESS MODES
# www-web-0      Bound    pvc-abcd1234          1Gi        RWO
# www-web-1      Bound    pvc-efgh5678          1Gi        RWO  
# www-web-2      Bound    pvc-ijkl9012          1Gi        RWO
```

#### Pod-PVC 매핑 규칙
```bash
# 규칙: {VolumeClaimTemplate이름}-{StatefulSet이름}-{순서번호}
# 
# StatefulSet: web
# VolumeClaimTemplate: www
# 
# 결과:
# - Pod: web-0 ↔ PVC: www-web-0
# - Pod: web-1 ↔ PVC: www-web-1  
# - Pod: web-2 ↔ PVC: www-web-2
```

---

## 🔗 관련 문서

### 더 많은 실습을 원한다면
**📖 [05-03. Storage 실습 예제 모음](05_03_Storage_실습_예제_모음.md)**
- 체험형 실습 시나리오
- 게임형 미션들  
- 문제 해결 가이드
- 실시간 모니터링 방법

### 빠른 명령어 참고
**📖 [Kubernetes 치트시트](../../kubernetes_cheatsheet.md)**
- 자주 쓰는 kubectl 명령어
- YAML 템플릿
- 디버깅 팁

## 🚨 일반적인 문제와 해결법

### PVC Pending 문제

**원인**:
- 적합한 PV가 없음
- StorageClass가 존재하지 않음  
- 용량이나 접근 모드 불일치

**해결법**:
```bash
# 상태 확인
kubectl describe pvc [PVC이름]
kubectl get storageclass
kubectl get pv

# 임시 해결
kubectl create pvc temp-pvc --claim-size=1Gi
```

### Pod 마운트 실패
**원인**: PVC 이름 오타, 다른 네임스페이스, 드라이버 문제

```bash
# 진단
kubectl describe pod [Pod이름]
kubectl get events --sort-by='.lastTimestamp'

# 해결
kubectl get pvc  # 이름 확인
kubectl delete pod [Pod이름] && kubectl apply -f pod.yaml
```

### 동적 프로비저닝 실패
**원인**: 프로비저너 미설치, 권한 부족, API 접근 문제

```bash
# 진단
kubectl get pods -n kube-system | grep provisioner
kubectl describe storageclass [SC이름]

# 해결
kubectl patch storageclass [SC이름] -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

---

## 🎯 실무 활용 패턴

### 환경별 StorageClass 전략

| 환경 | 특징 | reclaimPolicy | 비용 최적화 |
|------|------|---------------|-------------|
| 개발 | 빠른 테스트 | Delete | local, no-provisioner |
| 스테이징 | 안정성 | Delete | gp2, 비암호화 |
| 프로덕션 | 고성능+보안 | Retain | gp3, 암호화, 고IOPS |

### 애플리케이션별 전략

| 애플리케이션 | StorageClass | 특징 | 사용 사례 |
|------------|--------------|------|----------|
| 데이터베이스 | io2, 고IOPS | 최고 성능 | PostgreSQL, MySQL |
| 로그 수집 | NFS, RWX | 공유 접근 | Fluentd, ELK |
| 빌드 캐시 | gp3, Retain | 재사용 | Jenkins, CI/CD |
| 콘텐츠 전송 | 고대역폭 | 네트워크 성능 | CDN, 미디어 |

### 주요 고려사항

#### 성능 vs 비용
- **고성능 필요**: io1/io2, 높은 IOPS
- **비용 중요**: gp2/gp3, 적정 용량
- **공유 필요**: NFS, ReadWriteMany

#### 보안 고려
- 프로덕션: 암호화 필수
- 개발: 암호화 선택
- 백업: Retain 정책 사용

---

## 📋 주요 명령어

```bash
# 상태 조회
kubectl get pv,pvc,storageclass
kubectl describe pvc [PVC이름]
kubectl get events --sort-by='.lastTimestamp'

# 생성
kubectl create pvc my-pvc --claim-size=10Gi
kubectl create pvc my-pvc --claim-size=10Gi --storage-class=fast-ssd

# 디버깅
kubectl exec [Pod이름] -- df -h
kubectl get events --field-selector involvedObject.name=[PVC이름]

# 정리
kubectl delete pvc [PVC이름]
kubectl delete pv [PV이름]
```

---

## 🎯 마스터 체크리스트

### Level 1: 기초 이해
- [ ] PV, PVC, StorageClass의 역할 설명할 수 있다
- [ ] 수동으로 PV/PVC를 생성하고 Pod에 마운트할 수 있다
- [ ] 접근 모드(RWO, ROX, RWX)의 차이점을 안다
- [ ] 데이터 영속성을 테스트해봤다

### Level 2: 실무 적용  
- [ ] StorageClass를 생성하고 동적 프로비저닝을 설정할 수 있다
- [ ] VolumeClaimTemplate을 사용한 StatefulSet을 만들 수 있다
- [ ] 환경별로 다른 StorageClass 전략을 수립할 수 있다
- [ ] 스토리지 관련 문제를 진단하고 해결할 수 있다

### Level 3: 고급 운영
- [ ] 다양한 스토리지 백엔드(AWS EBS, NFS, Local)를 설정할 수 있다
- [ ] 스토리지 성능을 모니터링하고 최적화할 수 있다
- [ ] 백업/복원 전략을 수립하고 구현할 수 있다
- [ ] 프로덕션 환경의 스토리지 아키텍처를 설계할 수 있다

---

## 💡 핵심 요약

### 🎯 기억할 포인트

1. **스토리지 삼총사**: PV(실제 디스크) ↔ PVC(신청서) ↔ Pod(사용자)
2. **동적 vs 정적**: StorageClass로 자동 생성 vs 관리자가 수동 생성
3. **접근 모드가 중요**: RWO(개인용) vs RWX(공유용)
4. **데이터는 Pod보다 오래 산다**: 영속성의 핵심
5. **StatefulSet = VolumeClaimTemplate**: 순서가 중요한 앱을 위한 스토리지

### 🚨 주의사항

1. **reclaimPolicy 확인**: Delete vs Retain (데이터 손실 위험)
2. **volumeBindingMode 이해**: Immediate vs WaitForFirstConsumer
3. **노드 어피니티**: Local 스토리지 사용 시 노드 제약
4. **백업 전략**: 중요한 데이터는 반드시 백업
5. **용량 계획**: 스토리지 비용과 성능 고려

---

**💫 마지막 한마디**: 스토리지는 "상태가 있는 앱"의 생명선입니다. 처음엔 복잡해 보이지만, 아파트 임대 과정과 비슷하다고 생각하면 쉽게 이해할 수 있어요. 실습을 통해 직접 체험하면서 마스터하세요!

---

*📚 이 문서는 Kubernetes 스토리지 시스템의 모든 것을 담고 있습니다. 북마크하고 필요할 때마다 참고하세요!*