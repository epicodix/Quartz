---
title: gRPC - 마이크로서비스 고성능 통신의 핵심
tags:
  - gRPC
  - microservices
  - protobuf
  - http2
  - api
  - devops
  - infrastructure
aliases:
  - gRPC 개념
  - RPC 통신
  - Protocol Buffers
date: 2026-01-01
category: 2_기술_분석/통신프로토콜
status: 완성
priority: 높음
---

# 🎯 gRPC - 마이크로서비스 고성능 통신의 핵심

## 📑 목차
- [[#1. 배경 왜 REST만으로는 부족했나|배경과 문제점]]
- [[#2. 해결책 gRPC의 등장|gRPC 탄생]]
- [[#3. gRPC의 핵심 엔진|핵심 기술]]
- [[#4. REST vs gRPC 상세 비교|비교 분석]]
- [[#5. 실전 활용 가이드|실전 활용]]
- [[#6. gRPC의 한계와 트레이드오프|한계와 현실]]
- [[#🎯 실전 예시|실전 예시]]

---

## 1. 배경: 왜 REST만으로는 부족했나?

> [!note] 핵심 개념
> gRPC는 단순히 "새로운 API 방식"이 아니라, **"서비스 간의 대화 비용을 최소화하려는 시도"**에서 탄생한 기술입니다.

### 💡 모놀리식에서 MSA로의 전환

**🤔 질문**: "마이크로서비스로 전환하면서 어떤 문제가 발생했을까?"

#### 📋 구체적인 시나리오

> [!example] 실제 상황
> 1. **과거 (모놀리식)**: 함수 호출이 메모리 내부에서 일어나므로 매우 빠름
> 2. **현재 (MSA)**: 서비스가 쪼개지면서 서비스 간 통신(네트워크 호출)이 빈번해짐
> 3. **문제**: REST API(JSON + HTTP/1.1)를 사용하니 비효율 발생
> 4. **필요**: "원격 함수를 로컬 함수처럼 빠르게 호출하는 방법"

### 🚨 REST API의 3가지 한계

#### 1. 데이터 크기 문제
- **JSON은 텍스트 기반**: 데이터 크기가 크고 파싱에 CPU 자원 과다 소모
- **네트워크 대역폭 낭비**: 같은 데이터를 전송해도 바이너리보다 3~10배 큼

#### 2. 계약의 느슨함
- **타입 안정성 부족**: 클라이언트와 서버가 주고받을 데이터 형식을 강제하지 않음
- **런타임 에러 빈번**: 배포 후에야 오류 발견
- **문서화 부담**: API 스펙 문서를 별도로 관리해야 함

#### 3. HTTP/1.1의 성능 한계
- **Head-of-Line Blocking**: 한 번에 하나의 요청만 처리
- **연결 오버헤드**: 요청마다 새로운 TCP 연결 필요
- **스트리밍 부족**: 실시간 양방향 통신 어려움

> [!warning] 핵심 질문
> "서로 다른 언어로 짜인 서버끼리, 마치 내부에 있는 함수를 호출하듯 빠르고 안전하게 통신할 수는 없을까?"

---

## 2. 해결책: gRPC의 등장

> [!info] 구글의 답변
> 구글은 이 문제를 해결하기 위해 내부적으로 사용하던 기술을 2015년 오픈소스로 공개했습니다. 이것이 **gRPC**입니다.

### 📚 gRPC의 의미

```
gRPC = Google Remote Procedure Call
```

- **Remote**: 네트워크 너머 다른 서버에 있는
- **Procedure**: 함수/메서드를
- **Call**: 마치 로컬 함수처럼 호출

### 💡 핵심 철학

> [!tip] 설계 철학
> "원격 호출을 로컬 호출처럼 만들어라"
> - 빠르게 (성능)
> - 안전하게 (타입 안정성)
> - 쉽게 (자동 코드 생성)

---

## 3. gRPC의 핵심 엔진

### 🔧 1. Protocol Buffers - 통신 언어의 혁신

> [!note] Protocol Buffers란?
> 구글이 개발한 **구조화된 데이터 직렬화 포맷**으로, JSON의 바이너리 버전이라 할 수 있습니다.

#### 📊 작동 원리

```protobuf
// 📄 user.proto - 데이터 계약서
syntax = "proto3";

package user;

// 사용자 정보 정의
message User {
  int32 id = 1;
  string name = 2;
  string email = 3;
  repeated string roles = 4;
}

// 서비스 정의
service UserService {
  rpc GetUser(GetUserRequest) returns (User);
  rpc ListUsers(ListUsersRequest) returns (stream User);
}

message GetUserRequest {
  int32 user_id = 1;
}

message ListUsersRequest {
  int32 page_size = 1;
  string page_token = 2;
}
```

#### ⚙️ 자동 코드 생성

```bash
# 📋 .proto 파일에서 다양한 언어의 코드 자동 생성
protoc --go_out=. --go-grpc_out=. user.proto        # Go
protoc --java_out=. --grpc-java_out=. user.proto    # Java
protoc --python_out=. --grpc-python_out=. user.proto # Python
```

#### ✅ Protocol Buffers의 장점

| 특징 | 설명 | 효과 |
|------|------|------|
| **바이너리 포맷** | 기계가 읽기 편한 형식 | JSON 대비 3~10배 작은 크기 |
| **스키마 정의** | .proto 파일로 명세 | 컴파일 타임 타입 체크 |
| **자동 생성** | 다양한 언어 지원 | 개발 시간 단축, 오류 감소 |
| **하위 호환성** | 필드 추가/삭제 가능 | 점진적 업데이트 가능 |

### 🚀 2. HTTP/2 - 고속도로의 확장

> [!note] HTTP/2의 핵심
> gRPC는 HTTP/2를 기본 프로토콜로 사용하여 통신 성능을 극대화합니다.

#### 💻 주요 기능

**1. 멀티플렉싱 (Multiplexing)**
```
HTTP/1.1: 요청1 → 응답1 → 요청2 → 응답2 (순차)
HTTP/2:   요청1 ─┐
          요청2 ─┼→ 동시 전송 → ─┬─ 응답1
          요청3 ─┘                └─ 응답2, 응답3
```

**2. 양방향 스트리밍**
```go
// 📡 서버 스트리밍 예시
stream, err := client.ListUsers(ctx, &req)
for {
    user, err := stream.Recv()
    if err == io.EOF {
        break
    }
    fmt.Println(user)
}
```

**3. 헤더 압축**
- HPACK 알고리즘으로 중복 헤더 제거
- 반복 요청 시 오버헤드 최소화

#### 📊 HTTP/2 vs HTTP/1.1 성능 비교

| 항목 | HTTP/1.1 | HTTP/2 |
|------|----------|--------|
| **동시 요청** | 6~8개 (브라우저 제한) | 무제한 (멀티플렉싱) |
| **연결 수** | 요청마다 새 연결 | 단일 연결 재사용 |
| **헤더 크기** | 중복 전송 | HPACK 압축 |
| **우선순위** | 없음 | 스트림별 우선순위 지정 |

---

## 4. REST vs gRPC 상세 비교

### 📊 핵심 비교표

| 특징 | REST API | gRPC |
|------|----------|------|
| **데이터 포맷** | JSON (텍스트, 사람이 읽기 쉬움) | Protocol Buffers (바이너리, 기계 최적화) |
| **프로토콜** | 주로 HTTP/1.1 | HTTP/2 (멀티플렉싱) |
| **계약** | 자유로운 형식, 선택적 OpenAPI | .proto 파일(계약 강제, 컴파일 타임 검증) |
| **성능** | 상대적으로 느림 | 매우 빠름 (압축+바이너리) |
| **브라우저 지원** | ✅ 네이티브 지원 | ⚠️ gRPC-Web 필요 |
| **스트리밍** | ❌ 제한적 (SSE, 웹소켓 별도) | ✅ 양방향 스트리밍 기본 지원 |
| **사람 가독성** | ✅ JSON 직접 읽기 가능 | ❌ 바이너리 (디버깅 도구 필요) |
| **주요 사용처** | 웹 브라우저 ↔ 서버, 공개 API | 마이크로서비스 간 내부 통신 |
| **도구** | Postman, curl, 브라우저 | BloomRPC, grpcurl, 전용 클라이언트 |

### 🎯 선택 가이드

> [!tip] 언제 무엇을 사용할까?

#### ✅ REST를 사용해야 할 때
1. **웹 브라우저 클라이언트**: 프론트엔드 ↔ 백엔드
2. **공개 API**: 외부 개발자에게 제공
3. **단순한 CRUD**: 복잡한 통신 패턴 불필요
4. **캐싱 중요**: HTTP 캐싱 메커니즘 활용

#### ✅ gRPC를 사용해야 할 때
1. **마이크로서비스 간 통신**: 서버 ↔ 서버
2. **고성능 요구**: 지연시간, 대역폭이 중요
3. **다중 언어 환경**: Polyglot 아키텍처
4. **실시간 스트리밍**: 채팅, 알림, 실시간 피드

---

## 5. 실전 활용 가이드

### 💡 현대 MSA의 표준 전략

> [!example] 하이브리드 아키텍처
> ```
> 브라우저/모바일 앱
>       ↓ (REST/JSON)
>   API Gateway
>       ↓ (gRPC)
> ┌─────────┬─────────┬─────────┐
> │ Service │ Service │ Service │
> │    A    │    B    │    C    │
> └─────────┴─────────┴─────────┘
>       ↕ (gRPC - 내부 통신)
> ```

### 📋 도입 체크리스트

#### 1. 기술 요구사항
- [ ] HTTP/2 지원 인프라 (대부분 최신 환경 지원)
- [ ] Protocol Buffers 컴파일러 설치
- [ ] gRPC 라이브러리 (언어별)

#### 2. 개발 프로세스
```bash
# 1. .proto 파일 작성 (계약 정의)
# 2. 코드 생성
make proto-gen

# 3. 서버 구현
# - Generated stub 상속
# - 비즈니스 로직 구현

# 4. 클라이언트 구현
# - Generated client 사용
# - 원격 호출

# 5. 테스트
grpcurl -d '{"user_id": 1}' localhost:50051 user.UserService/GetUser
```

#### 3. 운영 고려사항
- **로드 밸런싱**: L7 로드 밸런서 필요 (HTTP/2 인지)
- **모니터링**: OpenTelemetry, Prometheus 연동
- **디버깅**: grpcurl, BloomRPC 활용
- **보안**: TLS/mTLS 인증서 관리

### 🔧 실전 팁

> [!tip] Best Practices
> 1. **버전 관리**: .proto 파일을 Git으로 관리하고 변경 시 하위 호환성 유지
> 2. **에러 처리**: gRPC 상태 코드 체계적으로 활용
> 3. **타임아웃 설정**: 모든 호출에 적절한 타임아웃 지정
> 4. **재시도 정책**: 일시적 오류 대비 재시도 로직
> 5. **스트리밍 주의**: 대용량 스트림은 백프레셔 구현

---

## 6. gRPC의 한계와 트레이드오프

> [!warning] 현실 체크
> gRPC는 강력하지만 **은탄환(Silver Bullet)이 아닙니다**. 프로토콜 변경만으로는 근본적인 아키텍처 문제를 해결할 수 없습니다.

### 🚨 1. gRPC의 주요 단점

#### 📋 개발 및 디버깅의 어려움

> [!example] 실제 문제
> **상황**: 운영 중 API 응답이 이상한데, 디버깅하려고 하니...
> - **REST**: `curl`로 바로 확인, 브라우저 개발자 도구로 분석 가능
> - **gRPC**: 바이너리 데이터라 읽을 수 없음, 전용 도구(grpcurl, BloomRPC) 필요

**문제점**:
- **사람이 읽을 수 없음**: Wireshark로 패킷 캡처해도 바이너리만 보임
- **도구 의존성**: 개발자 모두가 grpcurl, BloomRPC 설치 및 사용법 숙지 필요
- **로그 복잡도**: JSON 로그처럼 간단하게 찍을 수 없음
- **러닝 커브**: 신규 팀원 온보딩 시간 증가

#### 🌐 브라우저 지원의 한계

```
❌ 직접 지원 불가능
├─ 웹 브라우저는 HTTP/2의 일부 기능만 지원
├─ gRPC 바이너리 프레임을 네이티브로 처리 못함
└─ 결과: gRPC-Web이라는 별도 프록시/변환 계층 필요

⚠️ gRPC-Web의 제약
├─ 양방향 스트리밍 불가 (서버 스트리밍만 가능)
├─ 추가 프록시 구성 필요 (Envoy, Nginx)
└─ 성능 오버헤드 발생
```

#### 🔧 인프라 복잡도 증가

| 항목 | REST | gRPC | 차이점 |
|------|------|------|--------|
| **로드 밸런서** | L4/L7 모두 가능 | L7 필수 (HTTP/2 인지) | ALB/Envoy 등 필요 |
| **API Gateway** | 기본 지원 | 추가 설정 필요 | Kong, Envoy 등 일부만 지원 |
| **CDN 캐싱** | 쉬움 | 매우 어려움 | HTTP 캐시 헤더 활용 불가 |
| **방화벽** | 표준 HTTP 필터 | Deep Packet Inspection 어려움 | 보안팀 저항 가능 |

#### 📊 생태계 성숙도 차이

> [!info] 실제 프로젝트 경험
> "Swagger UI처럼 클릭만으로 API 테스트하는 도구가 없어서 QA팀이 불편해함"

- **문서화**: Swagger/OpenAPI처럼 보편화된 표준 부족
- **Mock 서버**: Postman Mock Server 같은 쉬운 도구 부족
- **테스트 도구**: REST Assured처럼 성숙한 테스트 프레임워크 적음
- **모니터링**: APM 도구들의 gRPC 지원이 REST보다 뒤처짐

---

### 🔄 2. 언어별 생태계 차이

> [!note] 핵심 인사이트
> "모든 언어에서 gRPC 경험이 동일하지 않습니다"

#### 📊 언어별 비교표

| 언어 | 성숙도 | 특징 | 장점 | 단점 |
|------|--------|------|------|------|
| **Go** | ⭐⭐⭐⭐⭐ | Google 공식 지원 | - 네이티브 퍼포먼스<br>- 간결한 코드<br>- 동시성 처리 우수 | - 제네릭 부족 (1.18 이전)<br>- 에러 처리 장황 |
| **Java** | ⭐⭐⭐⭐⭐ | 가장 풍부한 생태계 | - Spring Boot 통합 우수<br>- 방대한 라이브러리<br>- 엔터프라이즈급 도구 | - 메모리 사용량 많음<br>- 컴파일/빌드 느림 |
| **Python** | ⭐⭐⭐ | 기본 지원 | - 간단한 구현<br>- ML/AI 워크로드 통합 | - **성능 이슈 심각**<br>- GIL로 인한 동시성 제약<br>- Protobuf 직렬화 느림 |
| **Node.js** | ⭐⭐⭐⭐ | 활발한 커뮤니티 | - 비동기 처리 자연스러움<br>- 웹 통합 쉬움 | - 타입 안전성 약함<br>- 네이티브 바인딩 의존 |
| **Rust** | ⭐⭐⭐ | 최고 성능 | - 메모리 안전성<br>- C++ 수준 성능 | - 러닝 커브 가파름<br>- 생태계 작음 |
| **C#** | ⭐⭐⭐⭐ | .NET Core 통합 | - Visual Studio 도구 우수<br>- ASP.NET 통합 | - Windows 편향적<br>- 크로스플랫폼 제한 |

#### 💡 언어별 현실적 조언

**Go 사용 시**:
```go
// ✅ Go의 강점: 간결하고 빠름
func (s *server) GetUser(ctx context.Context, req *pb.GetUserRequest) (*pb.User, error) {
    // 고루틴으로 병렬 처리 쉬움
    go s.logRequest(req)
    return s.db.FindUser(ctx, req.Id)
}

// ⚠️ 주의점: 에러 처리가 장황해질 수 있음
```

**Java 사용 시**:
```java
// ✅ Java의 강점: 엔터프라이즈 기능 풍부
@GrpcService
public class UserServiceImpl extends UserServiceGrpc.UserServiceImplBase {
    @Autowired
    private UserRepository repository;

    @Override
    public void getUser(GetUserRequest request, StreamObserver<User> responseObserver) {
        // Spring 생태계와 완벽 통합
        User user = repository.findById(request.getId());
        responseObserver.onNext(user);
        responseObserver.onCompleted();
    }
}

// ⚠️ 주의점: 메모리와 시작 시간
```

**Python 사용 시**:
```python
# ⚠️ Python의 약점: 성능 문제
class UserService(user_pb2_grpc.UserServiceServicer):
    def GetUser(self, request, context):
        # GIL 때문에 멀티스레딩 효과 제한적
        # CPU 바운드 작업 시 asyncio도 한계
        return self.db.find_user(request.id)

# 🔧 해결책:
# - 순수 Python 대신 Cython/PyPy 고려
# - CPU 작업은 별도 서비스로 분리 (Go/Rust)
```

> [!warning] 실전 교훈
> "Python 마이크로서비스에 gRPC 도입했다가 레이턴시 2배 증가한 사례 있음. Python은 JSON도 충분히 느려서 Protobuf 이점이 상쇄됨."

---

### ⚠️ 3. 은탄환의 함정: gRPC로 해결 안 되는 것들

> [!danger] 가장 흔한 오해
> "구형 모놀리식을 gRPC로 바꾸면 빨라질 거야!"
>
> **현실**: 아키텍처의 근본적 문제는 프로토콜 변경으로 해결 안 됩니다.

#### 📋 안티패턴 사례

**❌ 안티패턴 1: N+1 문제 그대로**
```go
// 🚨 gRPC를 써도 여전히 느린 코드
func (s *server) GetUserPosts(ctx context.Context, req *pb.UserRequest) (*pb.PostList, error) {
    user := s.GetUser(ctx, req)  // RPC 호출 1회

    posts := []*pb.Post{}
    for _, postId := range user.PostIds {
        // 🔥 문제: 각 포스트마다 개별 RPC 호출!
        post := s.GetPost(ctx, &pb.PostRequest{Id: postId})  // N번 호출
        posts = append(posts, post)
    }
    return &pb.PostList{Posts: posts}, nil
}

// ✅ 올바른 방법: Batch API 설계
func (s *server) GetUserPosts(ctx context.Context, req *pb.UserRequest) (*pb.PostList, error) {
    user := s.GetUser(ctx, req)
    // 한 번의 호출로 모든 포스트 가져오기
    posts := s.GetPostsBatch(ctx, &pb.BatchRequest{Ids: user.PostIds})
    return posts, nil
}
```

**❌ 안티패턴 2: 과도한 서비스 분리**
```
Before (Monolith):           After (Badly designed MSA):
┌─────────────┐             ┌───────┐   ┌──────┐   ┌──────┐
│   Single    │             │ API   │──→│ User │──→│ Auth │
│   App       │             │Gateway│   │Service   │Service│
│  (100ms)    │             └───────┘   └──────┘   └──────┘
└─────────────┘                  │          │          │
                                 └─→┌──────┐─┘          │
                                    │ Post │←───────────┘
                                    │Service
                                    └──────┘

응답 시간: 100ms              응답 시간: 450ms (네트워크 홉 증가)
                              + 디버깅 복잡도 10배
```

> [!example] 실제 사례
> **문제**: 모놀리식 100ms → MSA+gRPC 전환 → 450ms로 증가
>
> **원인**:
> 1. 서비스 간 네트워크 레이턴시 (각 5-10ms × 10회 호출 = 50-100ms)
> 2. 직렬화/역직렬화 오버헤드 누적
> 3. 서비스 경계가 잘못 설계됨 (너무 잘게 쪼갬)
>
> **교훈**: gRPC는 통신 효율을 높일 뿐, **잘못된 아키텍처는 고칠 수 없음**

#### 🎯 gRPC가 해결하는 것 vs 해결 못하는 것

| 문제 | gRPC로 해결? | 실제 해결책 |
|------|-------------|------------|
| JSON 파싱 느림 | ✅ 해결 | Protobuf 바이너리 |
| HTTP/1.1 병목 | ✅ 해결 | HTTP/2 멀티플렉싱 |
| 타입 불일치 오류 | ✅ 해결 | .proto 계약 강제 |
| **N+1 쿼리 문제** | ❌ 안 됨 | **API 설계 개선 (Batch, Join)** |
| **과도한 서비스 분리** | ❌ 안 됨 | **DDD, Bounded Context 적용** |
| **DB 병목** | ❌ 안 됨 | **캐싱, 인덱싱, 쿼리 최적화** |
| **비효율적 알고리즘** | ❌ 안 됨 | **알고리즘 개선, 자료구조 최적화** |
| **메모리 누수** | ❌ 안 됨 | **코드 프로파일링, 리팩토링** |

---

### 🔍 4. 도입 전 체크리스트: 정말 gRPC가 필요한가?

> [!tip] 의사결정 프레임워크
> 다음 질문들에 답해보세요:

#### ✅ gRPC 도입이 **적합한** 경우

- [ ] 서버 간(Server-to-Server) 통신이 주된 사용 사례
- [ ] 지연시간이 비즈니스에 크리티컬 (실시간 시스템, 금융, 게임)
- [ ] 다중 언어 환경 (Polyglot)이지만 타입 안전성 필요
- [ ] 스트리밍이 핵심 요구사항 (실시간 로그, 알림)
- [ ] 팀이 Protobuf, HTTP/2에 익숙하거나 학습 의지 있음
- [ ] 인프라가 HTTP/2를 잘 지원 (최신 k8s, Envoy, Istio)

#### ⚠️ gRPC 도입이 **위험한** 경우

- [ ] 브라우저 클라이언트가 주된 사용자
- [ ] 외부 개발자에게 공개 API 제공
- [ ] 팀의 대부분이 REST에만 익숙
- [ ] 레거시 인프라 (오래된 로드 밸런서, 방화벽)
- [ ] 빠른 프로토타이핑 필요 (스타트업 MVP)
- [ ] 디버깅/모니터링 도구가 REST에 최적화됨

#### 🎯 현실적 접근법

```
단계별 도입 전략:

1단계: 가장 핫한 경로(Hot Path)만 gRPC로 전환
   예: API Gateway ↔ 인증 서비스 (초당 1만 요청)

2단계: 모니터링으로 효과 측정
   - 레이턴시 감소 확인
   - 에러율 증가 없는지 체크
   - 팀 만족도 조사

3단계: 성공 시 점진적 확대
   실패 시: REST 유지하거나 다른 최적화 시도

⚠️ 절대 하지 말 것: 한 번에 전체 시스템 마이그레이션
```

---

### 💡 5. 실전 의사결정 예시

> [!example] Case Study: 이커머스 플랫폼

**상황**:
- 일일 주문 100만 건
- 프론트엔드 (React) + 백엔드 (Java/Spring)
- 마이크로서비스 15개

**의사결정**:
```
✅ gRPC 사용
├─ 주문 서비스 ↔ 결제 서비스 (높은 트래픽, 짧은 레이턴시 필요)
├─ 상품 서비스 ↔ 재고 서비스 (실시간 재고 확인)
└─ 알림 서비스 (Server Streaming으로 실시간 주문 상태 푸시)

❌ REST 유지
├─ 프론트엔드 ↔ API Gateway (브라우저 호환성)
├─ 외부 파트너 API (표준성, 접근성)
└─ 어드민 대시보드 (개발 속도 우선)

결과:
- 핵심 경로 레이턴시 40% 감소 (150ms → 90ms)
- 하지만 개발 시간 30% 증가 (학습 비용)
- ROI: 6개월 후 긍정적 평가
```

---

### 📚 참고: gRPC 대안 기술들

| 기술 | 특징 | 사용 사례 |
|------|------|----------|
| **GraphQL** | 유연한 쿼리, 단일 엔드포인트 | 클라이언트 주도 데이터 페칭 |
| **Apache Thrift** | Facebook 개발, 다중 언어 | 레거시 시스템 통합 |
| **Cap'n Proto** | Protobuf 설계자 개발, 더 빠름 | 극한 성능 필요 시 |
| **JSON-RPC** | 간단한 RPC, JSON 사용 | 간단한 내부 API |
| **MessagePack** | 바이너리 JSON, 간단함 | Protobuf보다 가벼운 대안 |
| **WebSocket** | 양방향 통신 | 브라우저 실시간 통신 |

---

## 🎯 실전 예시

### 💻 예시 1: 간단한 사용자 서비스

#### 1. Proto 정의
```protobuf
// user_service.proto
syntax = "proto3";

package user.v1;

service UserService {
  rpc CreateUser(CreateUserRequest) returns (User);
  rpc GetUser(GetUserRequest) returns (User);
  rpc StreamUsers(StreamUsersRequest) returns (stream User);
}

message User {
  int32 id = 1;
  string email = 2;
  string name = 3;
  int64 created_at = 4;
}

message CreateUserRequest {
  string email = 1;
  string name = 2;
}

message GetUserRequest {
  int32 id = 1;
}

message StreamUsersRequest {
  int32 batch_size = 1;
}
```

#### 2. Go 서버 구현
```go
// server/main.go
package main

import (
    "context"
    "log"
    "net"

    pb "myapp/proto/user/v1"
    "google.golang.org/grpc"
)

type server struct {
    pb.UnimplementedUserServiceServer
}

func (s *server) GetUser(ctx context.Context, req *pb.GetUserRequest) (*pb.User, error) {
    // 비즈니스 로직
    return &pb.User{
        Id:    req.Id,
        Email: "user@example.com",
        Name:  "John Doe",
    }, nil
}

func main() {
    lis, err := net.Listen("tcp", ":50051")
    if err != nil {
        log.Fatalf("failed to listen: %v", err)
    }

    s := grpc.NewServer()
    pb.RegisterUserServiceServer(s, &server{})

    log.Println("Server listening on :50051")
    if err := s.Serve(lis); err != nil {
        log.Fatalf("failed to serve: %v", err)
    }
}
```

#### 3. Python 클라이언트
```python
# client/main.py
import grpc
from proto.user.v1 import user_service_pb2, user_service_pb2_grpc

def run():
    with grpc.insecure_channel('localhost:50051') as channel:
        stub = user_service_pb2_grpc.UserServiceStub(channel)

        # 단일 요청
        response = stub.GetUser(user_service_pb2.GetUserRequest(id=1))
        print(f"User: {response.name} ({response.email})")

        # 스트리밍
        for user in stub.StreamUsers(user_service_pb2.StreamUsersRequest(batch_size=10)):
            print(f"Streamed: {user.name}")

if __name__ == '__main__':
    run()
```

### 📊 예시 2: 성능 비교 실험

```go
// benchmark_test.go
func BenchmarkRESTAPI(b *testing.B) {
    for i := 0; i < b.N; i++ {
        resp, _ := http.Get("http://localhost:8080/users/1")
        io.ReadAll(resp.Body)
        resp.Body.Close()
    }
}

func BenchmarkGRPC(b *testing.B) {
    conn, _ := grpc.Dial("localhost:50051", grpc.WithInsecure())
    defer conn.Close()
    client := pb.NewUserServiceClient(conn)

    for i := 0; i < b.N; i++ {
        client.GetUser(context.Background(), &pb.GetUserRequest{Id: 1})
    }
}
```

**결과 (대략적 수치)**:
```
BenchmarkRESTAPI-8    3000    450000 ns/op    2500 B/op
BenchmarkGRPC-8      10000    120000 ns/op     800 B/op
```

---

## 📚 참고 자료

> [!info] 추가 학습 자료
> - [gRPC 공식 문서](https://grpc.io/docs/)
> - [Protocol Buffers 가이드](https://protobuf.dev/)
> - [HTTP/2 스펙 RFC 7540](https://tools.ietf.org/html/rfc7540)
> - [gRPC Best Practices](https://grpc.io/docs/guides/performance/)

## 🔗 관련 문서
- [[K8s_Deep_Dive/서비스메시]] - Service Mesh와 gRPC
- [[2_기술_분석/마이크로서비스-패턴]] - MSA 디자인 패턴
- [[GCP/Cloud-Run-gRPC]] - 클라우드 환경 gRPC 배포

---

## 💡 핵심 요약

> [!success] 균형잡힌 결론
> **gRPC는 강력하지만 만능은 아닙니다**
>
> ✅ **gRPC가 빛나는 곳**:
> - 서버 간 고성능 통신 (마이크로서비스 내부)
> - 타입 안전성이 중요한 다중 언어 환경
> - 실시간 스트리밍 요구사항
>
> ⚠️ **gRPC로 해결 안 되는 것**:
> - 잘못된 아키텍처 설계 (N+1 문제, 과도한 분리)
> - 데이터베이스 병목
> - 비효율적인 알고리즘
>
> 🎯 **현실적 접근**:
> 1. **외부 API**: REST (호환성, 접근성)
> 2. **핵심 내부 통신**: gRPC (성능, 타입 안전성)
> 3. **나머지**: 팀 역량과 트레이드오프 고려하여 선택
>
> **기억하세요**: 기술은 도구일 뿐, 좋은 설계가 먼저입니다.

---

*마지막 업데이트: 2026-01-01*
*작성자: Claude Code*
*카테고리: 기술 분석 / 통신 프로토콜*
