# 🛠️ Prometheus 접속 장애 트러블슈팅 가이드

이 문서는 Kubernetes 클러스터 내 Prometheus 접속 불가 현상을 해결하는 과정의 **의식의 흐름(Stream of Consciousness)**과 실제 사용된 명령어를 기록한 가이드입니다.

---

## 1. 🚨 상황 인지 (The Problem)

> [!FAILURE] 증상
> "이전에 `http://192.168.1.11/graph` 주소로 접속이 되었는데, 지금은 접속이 안 됩니다."

가장 먼저 든 생각은 두 가지입니다.
1. **Pod가 죽었나?** (Application Down)
2. **Service 연결이 끊어졌나?** (Network Configuration Change)

---

## 2. 🔍 초기 진단 (Initial Check)

우선 현재 내가 있는 `default` 네임스페이스의 상황을 확인합니다.

```bash
kubectl get po,svc
```

> [!WARNING] 결과 확인
> - `nginx`, `nfs`, `redis` 등은 보이지만 **Prometheus 관련 Pod나 Service가 전혀 보이지 않음.**
> - "삭제되었거나, 다른 네임스페이스(`monitoring` 등)에 격리되어 있을 것이다."라고 가설 수립.

---

## 3. 🕵️‍♂️ 전역 검색 (Global Search)

사라진 Prometheus를 찾기 위해 모든 네임스페이스(`-A`)를 뒤지고, 이전에 접속했던 IP(`192.168.1.11`)나 이름(`prometheus`)을 검색합니다.

```bash
kubectl get po,svc,ingress -A -o wide | grep -E 'prometheus|192.168.1.11'
```

> [!INFO] 발견 및 분석 (Analysis)
> 결과에서 다음 정보를 확인했습니다:
> 1. `monitoring` 네임스페이스에 Pod들이 정상(`Running`) 상태임. -> **죽지 않았음.**
> 2. `service/prometheus-server`가 존재하지만 **TYPE이 `ClusterIP`로 설정되어 있음.**
> 3. `EXTERNAL-IP` 항목이 `<none>`임.

> [!tip] 💡 의식의 흐름: 원인 도출
> "아하, Pod는 살아있는데 Service Type이 `ClusterIP`라서 클러스터 내부에서만 접근 가능하게 잠겨있구나. 외부 IP(`192.168.1.11`)를 할당받으려면 Type을 `LoadBalancer`로 바꿔야 해."

---

## 4. 🔧 해결 조치 (Resolution)

원인을 찾았으니, 서비스 설정을 변경하여 외부 문을 열어줍니다. 굳이 yaml 파일을 열어서 수정하고 적용할 필요 없이 `patch` 명령어로 즉시 수정합니다.

```bash
kubectl patch svc prometheus-server -n monitoring -p '{"spec": {"type": "LoadBalancer"}}'
```

> [!NOTE] 명령어 설명
> - `-n monitoring`: `monitoring` 네임스페이스를 타겟팅.
> - `-p '{"spec": {"type": "LoadBalancer"}}'`: 서비스 스펙 중 `type`만 콕 집어서 `LoadBalancer`로 덮어쓰기.

---

## 5. ✅ 검증 (Verification)

변경 사항이 적용되어 IP를 잘 받아왔는지 확인합니다.

```bash
kubectl get svc prometheus-server -n monitoring -o wide
```

> [!SUCCESS] 최종 결과
> ```text
> NAME                TYPE           EXTERNAL-IP    PORT(S)
> prometheus-server   LoadBalancer   192.168.1.11   80:32633/TCP
> ```
> `EXTERNAL-IP`에 `192.168.1.11`이 다시 할당된 것을 확인했습니다. 이제 브라우저에서 접속이 가능합니다.

---

## 📝 요약 (Summary)

1. **상황:** Prometheus 접속 불가.
2. **원인:** 서비스 타입이 `ClusterIP`로 설정되어 외부 IP 할당이 해제됨.
3. **해결:** `kubectl patch`를 통해 `LoadBalancer`로 변경.
4. **교훈:** 리소스가 안 보일 땐 당황하지 말고 `-A` (All Namespaces) 옵션을 켜자.
