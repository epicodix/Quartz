---
title: CKA 환경설정 가이드 - Tailscale + VMware Fusion + Rocky Linux
tags:
  - kubernetes
  - cka
  - tailscale
  - vmware-fusion
  - rocky-linux
  - devops
  - infrastructure
aliases:
  - CKA환경
  - 쿠버네티스실습환경
date: 2025-12-11
category: CKA/환경설정
status: 완성
priority: 높음
---

# 🎯 CKA 실습 환경 구축 가이드

## 📑 목차
- [[#1. 환경 개요|환경 개요]]
- [[#2. 하드웨어 구성|하드웨어 구성]]
- [[#3. VM 구성 상세|VM 구성 상세]]
- [[#4. 네트워크 설정|네트워크 설정]]
- [[#5. 쿠버네티스 클러스터 구축|쿠버네티스 클러스터 구축]]
- [[#6. Tailscale 네트워크 연결|Tailscale 네트워크 연결]]
- [[#7. 관리 및 운영 팁|관리 및 운영 팁]]

---

## 1. 환경 개요

> [!note] 핵심 개념
> M2 맥북 + VMware Fusion + Rocky Linux로 구성된 2025년형 CKA v1.30 실습 환경

### 💡 아키텍처 구성

**Host**: M2 MacBook Air (Apple Silicon)
**Hypervisor**: VMware Fusion Pro 13.x
**Guest OS**: Rocky Linux 9 ARM64
**Container Runtime**: containerd 1.7.x
**Kubernetes**: v1.30.14 (kubeadm 방식)
**Network Plugin**: Calico v3.28.0
**Remote Access**: Tailscale VPN

### 📊 환경 구성 비교표

| 항목 | CKA 시험환경 | 구축환경 |
|------|-------------|-----------|
| OS | Ubuntu 22.04 | Rocky Linux 9 |
| 패키지 관리자 | apt-get | dnf/yum |
| 쿠버네티스 버전 | v1.30.x | v1.30.14 |
| 컨테이너 런타임 | containerd | containerd |
| 네트워크 플러그인 | 다양 | Calico |
| 동작 원리 | 100% 동일 | 100% 동일 |

---

## 2. 하드웨어 구성

### 📋 VM 리소스 할당

> [!example] 리소스 배분
> **Master Node (k8s-master)**
> - vCPU: 2 Core
> - RAM: 4GB
> - Disk: 40GB
> - IP: 172.16.151.129
> - Tailscale IP: TBD
> 
> **Worker Node (k8s-worker1)**
> - vCPU: 2 Core  
> - RAM: 2GB
> - Disk: 40GB
> - IP: 172.16.151.130
> - Tailscale IP: TBD

### 💻 Host OS 설정

```bash
# Host OS 정보
시스템: macOS Sequoia (Apple Silicon)
VMware: Fusion Pro 13.x
터미널: iTerm2 (권장) / 기본 터미널

# SSH 접속 설정 (/etc/hosts)
172.16.151.129 k8s-master
172.16.151.130 k8s-worker1
```

---

## 3. VM 구성 상세

### 💡 베이스 이미지 생성 과정

> [!tip] Golden Image 방식
> 하나의 베이스 VM을 완성한 후 복제(Clone)하는 방식으로 구성 시간 단축

#### 📋 OS 설치 및 기본 설정

```bash
# 1. Rocky Linux 9 ARM64 ISO 다운로드
# 2. VMware Fusion에서 VM 생성 (Minimal Install)
# 3. 기본 계정 설정
#   - Root 계정 활성화
#   - 비밀번호: 0000 (실습용)
```

#### 💻 시스템 기본 설정

```bash
# Swap 비활성화 (쿠버네티스 필수 조건)
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# SELinux 설정 (Permissive 모드)
setenforce 0
sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

# 방화벽 비활성화 (실습용)
systemctl stop firewalld
systemctl disable firewalld

# SSH Root 접속 허용
sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
systemctl restart sshd
```

#### 📊 컨테이너 환경 설정

```bash
# 커널 모듈 로드
cat <<EOF | tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

# 네트워크 브리지 설정
cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sysctl --system
```

---

## 4. 네트워크 설정

### 🌐 다중 네트워크 구성

> [!warning] 네트워크 계층
> 1. **VMware NAT**: VM → 인터넷 연결
> 2. **Calico CNI**: Pod 간 통신
> 3. **Tailscale VPN**: 원격 접속

#### 💻 로컬 네트워크 (VMware)

```bash
# VM 네트워크 대역: 172.16.151.x/24
# Gateway: 172.16.151.2
# DNS: 8.8.8.8, 8.8.4.4

# Hosts 파일 설정 (모든 노드)
cat <<EOF >> /etc/hosts
172.16.151.129 k8s-master
172.16.151.130 k8s-worker1
EOF
```

#### 🔧 Tailscale 설정

```bash
# Rocky Linux 9 설치 방법
curl -fsSL https://pkgs.tailscale.com/stable/rhel/9/tailscale.repo | \
    sudo tee /etc/yum.repos.d/tailscale.repo

sudo dnf install tailscale
sudo systemctl enable --now tailscaled
sudo tailscale up
```

---

## 5. 쿠버네티스 클러스터 구축

### 📋 컨테이너 런타임 설치

> [!example] Containerd 구성
> Docker 대신 containerd 사용 (CKA 표준)

```bash
# Docker 저장소 추가
dnf install -y yum-utils
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

# containerd 설치
dnf install -y containerd.io

# 설정 파일 생성
mkdir -p /etc/containerd
containerd config default | tee /etc/containerd/config.toml

# SystemdCgroup 활성화 (v1.30+ 필수)
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

# 서비스 시작
systemctl restart containerd
systemctl enable containerd
```

### 💻 쿠버네티스 도구 설치

```bash
# 저장소 추가 (v1.30 지정)
cat <<EOF | tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.30/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.30/rpm/repodata/repomd.xml.key
EOF

# 설치
dnf install -y kubelet kubeadm kubectl --disableexcludes=kubernetes

# Kubelet 활성화
systemctl enable --now kubelet
```

### 🎯 마스터 노드 초기화

```bash
# 클러스터 초기화 (Calico 네트워크 대역 지정)
kubeadm init --pod-network-cidr=192.168.0.0/16

# kubectl 권한 설정
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# CNI(Calico) 설치
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/tigera-operator.yaml
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/custom-resources.yaml
```

### 💡 워커 노드 연결

```bash
# 마스터 초기화 완료 후 출력되는 join 명령어 실행
kubeadm join 172.16.151.129:6443 --token <TOKEN> \
    --discovery-token-ca-cert-hash sha256:<HASH>

# 연결 확인 (마스터에서)
kubectl get nodes
```

---

## 6. Tailscale 네트워크 연결

### 🌐 원격 접속 환경 구성

> [!note] Tailscale 장점
> - 네트워크 변경(집 ↔ 카페) 시에도 동일 IP 유지
> - NAT 뒤의 VM들도 직접 접속 가능
> - Zero-Trust 보안 모델

#### 📋 설치 과정

```bash
# 1. 각 VM에 Tailscale 설치
curl -fsSL https://pkgs.tailscale.com/stable/rhel/9/tailscale.repo | \
    sudo tee /etc/yum.repos.d/tailscale.repo
    
sudo dnf install tailscale
sudo systemctl enable --now tailscaled

# 2. 네트워크 연결
sudo tailscale up

# 3. 상태 확인
tailscale status
```

#### 💻 접속 방법

```bash
# 기존 로컬 접속
ssh root@172.16.151.129  # 네트워크 변경시 접속 불가

# Tailscale 접속 (어디서든 가능)
ssh root@100.x.x.x      # Tailscale IP로 접속
```

---

## 7. 관리 및 운영 팁

### 🔧 자동화 스크립트

> [!tip] VM 관리 자동화
> 매번 VMware 창을 켜고 끄는 번거로움 해결

#### 📋 시작 스크립트 (k8s-up.sh)

```bash
#!/bin/bash

VMRUN="/Applications/VMware Fusion.app/Contents/Library/vmrun"
MASTER_VM="/Users/a1234/Virtual Machines.localized/Rocky Linux 64-bit Arm.vmwarevm/Rocky Linux 64-bit Arm.vmx"
WORKER_VM="/Users/a1234/Virtual Machines.localized/Clone of Rocky Linux 64-bit Arm.vmwarevm/Clone of Rocky Linux 64-bit Arm.vmx"

echo "🚀 쿠버네티스 실습 환경을 시작합니다..."

"$VMRUN" start "$MASTER_VM" nogui
echo "✅ Master Node 실행 완료!"

"$VMRUN" start "$WORKER_VM" nogui  
echo "✅ Worker Node 실행 완료!"

echo "🎉 잠시 후(약 30초) ssh로 접속하세요!"
```

#### 💻 사용법

```bash
chmod +x k8s-up.sh
./k8s-up.sh

# 종료는 SSH에서
poweroff
```

### 📊 스냅샷 관리

> [!warning] 백업 전략
> 중요한 단계마다 스냅샷 생성 필수

#### 💡 권장 스냅샷 포인트

1. **"Initial Ready State"**: 클러스터 구축 직후
2. **"Pre-Exam State"**: 실습 시작 전 깨끗한 상태
3. **"Working State"**: 특정 설정 완료 후

#### 🔧 복구 방법

```bash
# VMware Fusion에서
Virtual Machine → Snapshots → Restore to Snapshot
```

### 📋 일상 사용 패턴

```bash
# 1. 실습 시작
./k8s-up.sh

# 2. SSH 접속 (탭 2개)
ssh root@k8s-master
ssh root@k8s-worker1

# 3. kubectl 단축키 활용
alias k=kubectl
k get nodes

# 4. 실습 종료
poweroff  # 각 VM에서
```

### 🚨 트러블슈팅

> [!danger] 자주 발생하는 문제
> 1. **NotReady 상태**: CNI 플러그인 미설치
> 2. **join 실패**: 토큰 만료 또는 네트워크 문제  
> 3. **SSH 거부**: PermitRootLogin 설정 확인

#### 💻 해결 명령어

```bash
# CNI 재설치
kubectl delete -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/custom-resources.yaml
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/custom-resources.yaml

# Join 토큰 재생성
kubeadm token create --print-join-command

# 클러스터 초기화 (최후의 수단)
kubeadm reset
```

---

## 🎉 완성된 환경의 가치

### ⭐ 달성 목표

- [x] CKA 시험과 95% 동일한 쿠버네티스 v1.30 환경
- [x] 어디서든 접속 가능한 Tailscale 네트워크  
- [x] VMware Fusion 기반 안정적인 가상화
- [x] Rocky Linux로 RHEL 계열 경험 습득

### 🚀 다음 단계

1. **CKA 핵심 실습**: Pod, Deployment, Service 생성
2. **트러블슈팅 연습**: Node NotReady, Pod 실패 상황 해결
3. **RBAC 설정**: ServiceAccount, Role, RoleBinding
4. **백업/복구**: etcd 백업, 클러스터 복구 실습

> [!note] 성공 지표
> `kubectl get nodes` 실행 시 두 노드 모두 Ready 상태 = 환경 구축 완료!