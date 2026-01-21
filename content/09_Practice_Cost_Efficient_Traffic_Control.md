---
title: CloudRun_비용방어_및_트래픽모니터링_구축기
creation_date: 2026-01-21
date: 2026-01-21
tags: [Go, CloudRun, FinOps, Security, TrafficControl]
aliases: [비용 효율적 트래픽 제어, Go Traffic Monitor]
category: 클라우드/Project
status: 완성
priority: 높음
model: gemini-3.0-pro preview
published: false
---

# 🛡️ Cloud Run 비용 방어 및 실시간 트래픽 모니터링 구축기

> **"무제한 확장은 무제한 요금 청구서를 의미한다."**
> 클라우드 네이티브 환경에서 비용 폭탄(Billing Bomb)을 막기 위한 안전장치를 걸고, Go 미들웨어로 실시간 트래픽 부하를 감지하는 시스템을 구축했습니다.

## 1. 문제 정의 (Problem)
포트폴리오 사이트는 트래픽 예측이 불가능합니다. 만약 악의적인 공격(DDoS)이나 단순 실수로 F5 연타가 발생한다면?
*   **Serverless의 양면성**: Cloud Run은 트래픽에 맞춰 자동으로 인스턴스를 늘립니다(Scale-out). 이는 서비스 가용성엔 좋지만, **개인 프로젝트에서는 예산 초과의 주범**이 됩니다.
*   **가시성 부재**: 현재 서버가 공격받고 있는지, 평온한지 알 방법이 없습니다.

## 2. 해결 전략 (Solution)

### 2.1 물리적 비용 방어 (Infrastructure Level)
**"최악의 상황에서도 인스턴스는 1개만 뜬다."**
Cloud Run의 `max-instances` 설정을 통해 물리적인 과금 한계선을 그었습니다.

```bash
gcloud run services update portfolio-status-api \
  --max-instances 1 \
  --region asia-northeast3
```
*   **효과**: 트래픽이 폭주해도 요청이 큐(Queue)에 쌓이거나 드랍될 뿐, 인스턴스가 수십 개로 복제되어 비용을 발생시키지 않습니다.

### 2.2 논리적 트래픽 방어 (Application Level)
**"불필요한 요청은 서버까지 오지도 말라."**
Go 핸들러에 `Cache-Control` 헤더를 적용하여 CDN과 브라우저 캐싱을 유도했습니다.

```go
// main.go
w.Header().Set("Cache-Control", "public, max-age=5")
```
*   **효과**: 5초 내의 중복 요청(F5 연타)은 브라우저 캐시에서 처리되어, 서버 리소스 사용량을 획기적으로 줄입니다.

### 2.3 실시간 모니터링 (Observability)
Go의 `sync.Mutex`와 `Goroutine`을 활용해 메모리 내에서 가볍게 요청 수를 카운팅합니다.

```go
// Traffic Middleware
func trafficMiddleware(next http.HandlerFunc) http.HandlerFunc {
    return func(w http.ResponseWriter, r *http.Request) {
        requestCountMutex.Lock()
        requestCount++
        requestCountMutex.Unlock()
        next(w, r)
    }
}
```
*   **판단 로직**:
    *   `< 60 req/min`: **Stable (안정)**
    *   `> 300 req/min`: **High Traffic (부하 감지)**

## 3. 한계점 및 장단점 분석 (Trade-offs)

면접관이 *"이 구조의 문제점은 없나요?"* 라고 물었을 때의 답변입니다.

| 구분 | 장점 (Pros) | 단점 및 한계 (Cons) |
| :--- | :--- | :--- |
| **Max Instance = 1** | **확실한 비용 통제**.<br>절대로 예산을 초과하지 않음. | **가용성 저하**.<br>동시 접속자가 폭증하면 응답이 매우 느려지거나 503 에러 발생. |
| **In-Memory Counter** | **구현이 매우 간단하고 빠름**.<br>외부 DB(Redis) 없이 Go 언어 자체 기능만 사용. | **분산 환경에서 부정확**.<br>인스턴스가 여러 개로 늘어나면(Scale-out) 각자 카운팅하므로 전체 트래픽 합산 불가. (현재는 인스턴스가 1개라 문제없음) |
| **Cache-Control** | **서버 부하 감소**.<br>네트워크 비용 절감. | **실시간성 저하**.<br>서비스 상태가 바뀌어도 5초간은 사용자에게 갱신되지 않음. |

## 4. 향후 개선 방향 (Future Work)
1.  **Redis 도입**: 인스턴스를 여러 개로 확장(Scale-out)해야 한다면, 트래픽 카운터를 Redis 같은 외부 저장소로 옮겨 중앙에서 관리해야 합니다.
2.  **Cloudflare/WAF 적용**: 애플리케이션 레벨이 아닌, 네트워크 앞단에서 DDoS를 차단하는 것이 더 효율적입니다.

<br>
<div align="right" style="font-size: 0.8em; color: gray; opacity: 0.6;">
  Supported by gemini-3.0-pro preview
</div>
