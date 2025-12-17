# Grafana + Loki 완벽 가이드 시리즈

> **목표**: 클라우드 엔지니어를 위한 실전 로그 모니터링 마스터
> **환경**: Kubernetes 1.30.4, Grafana 10.x, Loki 2.9.3
> **실습 환경**: http://192.168.1.12

---

## 📚 학습 로드맵

### 🎯 Phase 1: 기초 개념 (이론)
- [[01_Grafana_기초_개념_완벽_정리|01. Grafana 기초 개념 완벽 정리]]
- [[02_Loki_아키텍처_완벽_이해|02. Loki 아키텍처 완벽 이해]]
- [[03_Grafana_vs_Kibana_비교|03. Grafana vs Kibana 도구 비교]]

### 🛠️ Phase 2: 환경 구축 (실습)
- [[04_Loki_Promtail_설치_가이드|04. Loki + Promtail 설치 가이드]]
- [[05_Grafana_데이터소스_연결|05. Grafana 데이터소스 연결]]
- [[06_테스트_환경_구성|06. 테스트 로그 생성 환경 구성]]

### 🔍 Phase 3: LogQL 마스터 (실습)
- [[07_LogQL_기초_쿼리|07. LogQL 기초 쿼리 (Stream Selector)]]
- [[08_LogQL_필터링_파싱|08. LogQL 필터링 및 파싱]]
- [[09_LogQL_집계_메트릭|09. LogQL 집계 및 메트릭 생성]]
- [[10_LogQL_고급_패턴|10. LogQL 고급 패턴 (Regex, Parsing)]]

### 📊 Phase 4: 대시보드 구축 (실습)
- [[03_Grafana_Explore_활용법|11. Grafana Explore 완벽 활용법]]
- [[04_첫_대시보드_만들기|12. 첫 번째 대시보드 만들기]]
- [[13_Panel_시각화_타입|13. Panel 시각화 타입 완벽 가이드]]
- [[14_Variables_동적_대시보드|14. Variables로 동적 대시보드 만들기]]
- [[15_실시간_로그_모니터링_대시보드|15. 실시간 로그 모니터링 대시보드]]

### 🚀 Phase 5: 실전 시나리오 (응용)
- [[16_장애_탐지_대시보드|16. 장애 탐지 대시보드 구축]]
- [[17_성능_분석_대시보드|17. 성능 분석 대시보드]]
- [[18_보안_모니터링|18. 보안 이벤트 모니터링]]
- [[19_Alert_Rule_설정|19. Alert Rule 설정 가이드]]

### 🎓 Phase 6: 고급 주제
- [[20_Prometheus_Loki_통합|20. Prometheus + Loki 통합 대시보드]]
- [[21_Loki_스토리지_최적화|21. Loki 스토리지 최적화]]
- [[22_프로덕션_베스트_프랙티스|22. 프로덕션 베스트 프랙티스]]

---

## 🎯 빠른 참조 (Quick Reference)

### 필수 치트시트
- [[실습-치트시트|실습 치트시트]] - LogQL 쿼리 모음
- [[kubectl_명령어_모음|kubectl 명령어 모음]]
- [[트러블슈팅_가이드|트러블슈팅 가이드]]

### 대시보드 템플릿
- [[대시보드_템플릿_1_기본_로그_모니터링|기본 로그 모니터링 템플릿]]
- [[대시보드_템플릿_2_에러_추적|에러 추적 템플릿]]
- [[대시보드_템플릿_3_성능_분석|성능 분석 템플릿]]

---

## 📋 학습 체크리스트

### 기초 단계
- [ ] Grafana 기본 개념 이해
- [ ] Loki 아키텍처 이해
- [ ] Loki + Promtail 설치 완료
- [ ] Grafana 데이터소스 연결 성공
- [ ] Explore에서 첫 로그 조회

### 중급 단계
- [ ] LogQL Stream Selector 사용
- [ ] LogQL Line Filter 사용
- [ ] 기본 집계 쿼리 작성
- [ ] 첫 대시보드 생성 (최소 3개 패널)
- [ ] 로그 레벨별 필터링

### 고급 단계
- [ ] 정규표현식 패턴 활용
- [ ] 로그 파싱 및 레이블 추출
- [ ] Variables를 사용한 동적 대시보드
- [ ] Alert Rule 설정
- [ ] Prometheus + Loki 통합 대시보드

---

## 🌟 실습 환경 정보

### 접속 정보
```
Grafana URL: http://192.168.1.12
계정: admin / admin
Loki URL (내부): http://loki.logging:3100
```

### Kubernetes 환경
```
Control Plane: cp-k8s (192.168.1.10)
Workers: w1-k8s, w2-k8s, w3-k8s
```

### 배포된 컴포넌트
```
Namespace: logging
- Loki (1 pod)
- Promtail (4 pods - DaemonSet)

Namespace: demo-app
- log-generator (2 pods)
- web-api (1 pod)

Namespace: monitoring
- Grafana (1 pod)
- Prometheus (기존 설치)
```

---

## 🔗 관련 자료

### 공식 문서
- [Grafana Documentation](https://grafana.com/docs/grafana/latest/)
- [Loki Documentation](https://grafana.com/docs/loki/latest/)
- [LogQL Syntax](https://grafana.com/docs/loki/latest/logql/)

### 내부 참조
- [[../03_프로메테우스/00_프로메테우스_시리즈_목차|프로메테우스 시리즈]]
- [[../02_k8s실습/|Kubernetes 실습]]

---

## 📝 학습 순서 추천

**초보자:**
1. 01 → 02 → 04 → 05 → 07 → 11 → 12

**중급자:**
2. 04 → 07 → 08 → 09 → 11 → 12 → 13 → 15

**고급자:**
3. 10 → 14 → 16 → 17 → 18 → 20 → 22

---

**최종 수정일**: 2025-12-17
**작성자**: Claude + 사용자 실습
