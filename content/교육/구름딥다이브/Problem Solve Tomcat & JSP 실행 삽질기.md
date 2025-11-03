---
creation_date: 2025-10-31
title: 'Problem Solve: Tomcat & JSP 실행 삽질기'
category: '교육/구름딥다이브'
tags: ['Tomcat', 'JSP', 'Java', 'Troubleshooting', 'Server', 'macOS']
---

# Problem Solve: Tomcat & JSP 실행 삽질기

## 📅 Day 3 - 예상치 못한 자바의 등장

### 🔥 문제 발생
- **상황**: 강사님이 던져준 `edu03_sample` 파일들
- **예상**: HTML/CSS/JS로 구성된 일반 웹 페이지
- **현실**: `login.jsp` 파일 발견 → 자바 기반 서버사이드 코드
- **멘탈**: 💥 폭발

```
📁 edu03_sample/
├── index.html
├── login.html
└── login.jsp  ← 이놈이 문제의 시작
```

### 😱 초기 반응
```
"Live Server로는 안되는거야?"
→ JSP는 서버사이드 실행이 필요
→ Apache Tomcat 같은 WAS 필요
→ "아... 기술 부채네 ㅋㅋ"
```

---

## 🤖 AI와의 협업 시작

### Phase 1: Tomcat 설치
```bash
brew install tomcat
# ✅ 설치 완료 (Tomcat 11.0.13)
```

**첫 번째 함정**: Tomcat 11은 Java 21 이상 필요
```bash
/usr/libexec/java_home -V
# ❌ Java Runtime을 찾을 수 없음
```

### Phase 2: Java 설치
```bash
brew install openjdk@21
# ✅ Java 21 설치 완료
```

### Phase 3: VS Code 연동 시도
1. Community Server Connectors 확장 설치 ✅
2. Tomcat 서버 생성 시도 ❌
3. 서버 시작 시도 ❌

**증상**:
- "Start RSP"만 표시됨
- Tomcat 서버가 목록에 안 보임
- 출력 패널에 의미 있는 로그 없음

---

## 🌪️ 문제 증폭 단계

### 1차 시도: VS Code에서 서버 관리
```
문제: VS Code 확장이 Tomcat을 인식 못함
원인: Java 경로 설정 문제? 확장 프로그램 버그?
결과: 시간만 소비
```

### 2차 시도: 포트 혼동
```
http://localhost:9000/...
❌ ERR_CONNECTION_REFUSED

알고 보니:
- 9000: 서버 관리용 내부 포트
- 8080: 실제 웹 서비스 포트
```

### 3차 시도: 터미널에서 직접 실행
```bash
/opt/homebrew/opt/tomcat/bin/catalina run
# ✅ 서버 시작 성공!
```

**서버 로그 확인**:
```
31-Oct-2025 13:48:50.221 정보 [main] 
org.apache.coyote.AbstractProtocol.start 
프로토콜 핸들러 ["http-nio-8080"]을(를) 시작합니다.

31-Oct-2025 13:48:50.226 정보 [main] 
org.apache.catalina.startup.Catalina.start 
서버가 [295] 밀리초 내에 시작되었습니다.
```

### 4차 시도: 프로젝트 파일 접근
```
http://localhost:8080/edu-cloud7-html/edu03_sample/index.html
❌ HTTP 상태 404 – 찾을 수 없음
```

---

## 💡 단순했던 해결 과정

### 핵심 문제
**Tomcat은 실행 중이지만, 프로젝트 파일을 찾지 못함**

### 원인 파악
```bash
ls -la /opt/homebrew/opt/tomcat/libexec/webapps/
# docs, examples, host-manager, manager, ROOT만 있음
# edu-cloud7-html 없음!
```

Tomcat은 `webapps/` 폴더 안의 프로젝트만 인식함

### 해결 방법

#### ❌ 시도했던 것들
```bash
# 1. 일반 복사 (줄바꿈 때문에 실패)
cp -r /Users/a1234/epicodix/edu-cloud7-html
     /opt/homebrew/opt/tomcat/libexec/webapps/
# zsh: permission denied

# 2. sudo 사용 (불필요한 시도)
sudo cp -r ...
# 여전히 실패 (명령어 구문 오류)
```

#### ✅ 실제 해결책

**방법 1: 심볼릭 링크 (권장)**
```bash
ln -s /Users/a1234/epicodix/edu-cloud7-html \
      /opt/homebrew/opt/tomcat/libexec/webapps/edu-cloud7-html

# 장점: 원본 파일 수정이 즉시 반영됨
```

**방법 2: ROOT에 직접 복사 (간단)**
```bash
cp -r /Users/a1234/epicodix/edu-cloud7-html/edu03_sample \
      /opt/homebrew/opt/tomcat/libexec/webapps/ROOT/

# 접속: http://localhost:8080/edu03_sample/index.html
```

### 최종 실행 단계
```bash
# 1. Tomcat 시작
/opt/homebrew/opt/tomcat/bin/catalina run

# 2. 브라우저 접속
http://localhost:8080/edu-cloud7-html/edu03_sample/index.html
# 또는
http://localhost:8080/edu03_sample/index.html

# ✅ 성공!
```

---

## 📝 교훈 정리

### 기술적 학습
1. **JSP ≠ HTML**: JSP는 서버사이드 실행 필요
2. **WAS의 역할**: Tomcat 같은 서버가 Java 코드를 실행
3. **프로젝트 배포**: `webapps/` 폴더에 파일이 있어야 함
4. **환경 일치**: Java 버전 + Tomcat 버전 호환성 확인

### 문제 해결 과정
```
복잡한 시도들
├── VS Code 확장 연동 ❌
├── 포트 혼동 ❌
├── 권한 문제 해결 시도 ❌
└── sudo 사용 ❌

실제 해결
└── 프로젝트를 webapps에 배치 ✅
```

### 핵심 인사이트
> **"문제가 복잡해 보일 때, 가장 기본적인 것을 놓치고 있을 가능성이 크다"**

- VS Code 연동 같은 복잡한 설정보다
- 터미널에서 직접 실행하는 게 더 명확
- 프레임워크/툴의 기본 동작 원리 이해가 중요

---

## 🎯 체크리스트 (다음에 참고용)

### Tomcat 프로젝트 실행 시
- [ ] Java 설치 확인: `java -version`
- [ ] Tomcat 설치 확인: `brew info tomcat`
- [ ] 버전 호환성 확인 (Tomcat 11 = Java 21+)
- [ ] 프로젝트를 `webapps/`에 배치
- [ ] Tomcat 시작: `catalina run`
- [ ] 포트 8080으로 접속
- [ ] 404 에러 시 파일 경로 재확인

### 디버깅 순서
1. 서버가 실행 중인가?
2. 올바른 포트로 접속했는가?
3. 파일이 `webapps/` 안에 있는가?
4. 파일 경로가 URL과 일치하는가?

---

## 🚀 최종 동작 코드

### Tomcat 실행
```bash
/opt/homebrew/opt/tomcat/bin/catalina run

# 다른 터미널에서 로그 모니터링 (선택)
tail -f /opt/homebrew/opt/tomcat/libexec/logs/catalina.out
```

**프로젝트 구조**:
```
/opt/homebrew/opt/tomcat/libexec/webapps/
├── ROOT/
│   └── edu03_sample/  ← 여기에 파일들
│       ├── index.html
│       ├── login.html
│       └── login.jsp
└── edu-cloud7-html/  ← 또는 심볼릭 링크
    └── edu03_sample/
        └── ...
```

**접속 URL**:
- `http://localhost:8080/edu03_sample/index.html`
- `http://localhost:8080/edu-cloud7-html/edu03_sample/index.html`

---

## 💭 회고

**예상 시간**: 10분  
**실제 소요 시간**: 약 1시간  
**배운 점**: "기술 부채"를 미루지 말고 지금 해결하는 게 나중을 위해 이득

> "와씨 완벽하다" - 문제 해결 직후의 나

```