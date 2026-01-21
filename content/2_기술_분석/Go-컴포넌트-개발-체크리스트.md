---
title: Go 컴포넌트 개발 - 에러 없는 체크리스트
tags:
  - golang
  - backend
  - devops
  - checklist
aliases:
  - Go개발가이드
  - Gemini가이드
date: 2025-01-06
category: 2_기술_분석/Go
status: 완성
priority: 높음
---

# 🎯 Go 컴포넌트 개발 - 에러 없는 체크리스트

## 📑 목차
- [[#1. 필수 사전 체크|필수 사전 체크]]
- [[#2. 구조체 정의 규칙|구조체 정의]]
- [[#3. API 핸들러 패턴|API 핸들러]]
- [[#4. 일반적인 에러 해결|에러 해결]]

---

## 1. 필수 사전 체크

> [!note] 작업 전 반드시 확인
> 이 항목들을 확인하지 않으면 99% 에러 발생

### ✅ 환경 체크리스트

```bash
# 1. 프로젝트 경로 확인
pwd
# 출력: /Users/a1234/facebook-marketing-dashboard

# 2. Go 버전 확인 (1.19 이상)
go version

# 3. 기존 서버 종료
lsof -ti:8080 | xargs kill -9

# 4. 의존성 업데이트
go mod tidy
```

### ✅ 파일 수정 전

```bash
# 1. 파일 존재 확인
ls -la <파일경로>

# 2. 백업 생성
cp main.go main.go.bak

# 3. 컴파일 테스트
go build -o test-binary main.go
```

---

## 2. 구조체 정의 규칙

> [!warning] 가장 흔한 에러 원인
> 구조체 필드가 소문자로 시작하면 JSON 변환 실패

### 💡 올바른 구조체 작성법

```go
// ✅ 올바른 예시
type MyData struct {
    ID        string    `json:"id"`          // 대문자 시작
    Name      string    `json:"name"`        // json 태그 필수
    Count     int       `json:"count"`
    Amount    float64   `json:"amount"`
    CreatedAt time.Time `json:"created_at"`
}

// ❌ 잘못된 예시
type MyData struct {
    id        string    // 소문자 - JSON 변환 안됨!
    Name      string    // json 태그 없음
    count     int       // 소문자 - 접근 불가!
}
```

### 📋 필드 타입 선택 가이드

| 데이터 종류 | Go 타입 | JSON 예시 |
|-------------|---------|-----------|
| 문자열 | `string` | `"hello"` |
| 정수 | `int`, `int64` | `123` |
| 실수 | `float64` | `123.45` |
| 불린 | `bool` | `true` |
| 배열 | `[]string` | `["a", "b"]` |
| 객체 | `MyStruct` | `{"key": "value"}` |
| 선택적 값 | `*string` | `null` or `"value"` |
| 시간 | `time.Time` | `"2025-01-06T10:00:00Z"` |

---

## 3. API 핸들러 패턴

> [!example] 실제 상황
> 1. **문제**: API 호출 시 CORS 에러 발생
> 2. **감지**: 브라우저 콘솔에 "CORS policy" 에러
> 3. **조치**: CORS 헤더 추가
> 4. **결과**: API 정상 동작

### 💻 완전한 핸들러 템플릿

```go
// 📊 응답 구조체 정의 (main.go 상단)
type MyResponse struct {
    Data    interface{} `json:"data"`
    Error   string      `json:"error,omitempty"`
    Success bool        `json:"success"`
}

// 📋 핸들러 함수
func myHandler() http.HandlerFunc {
    return func(w http.ResponseWriter, r *http.Request) {
        // 1️⃣ CORS 헤더 (필수!)
        w.Header().Set("Access-Control-Allow-Origin", "*")
        w.Header().Set("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        w.Header().Set("Access-Control-Allow-Headers", "Content-Type")
        w.Header().Set("Content-Type", "application/json")

        // 2️⃣ OPTIONS 요청 처리
        if r.Method == "OPTIONS" {
            w.WriteHeader(http.StatusOK)
            return
        }

        // 3️⃣ HTTP 메서드 검증
        if r.Method != "POST" {
            http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
            return
        }

        // 4️⃣ 요청 바디 파싱
        var request struct {
            Param string `json:"param"`
        }
        if err := json.NewDecoder(r.Body).Decode(&request); err != nil {
            http.Error(w, err.Error(), http.StatusBadRequest)
            return
        }

        // 5️⃣ 비즈니스 로직
        result := processData(request.Param)

        // 6️⃣ 응답 반환
        response := MyResponse{
            Data:    result,
            Success: true,
        }
        json.NewEncoder(w).Encode(response)
    }
}

// 📋 main()에서 등록
func main() {
    mux := http.NewServeMux()
    mux.HandleFunc("/api/my-endpoint", myHandler())  // ⚠️ () 필수!

    http.ListenAndServe(":8080", mux)
}
```

### 🔍 단계별 체크포인트

- [ ] CORS 헤더 4개 모두 설정
- [ ] OPTIONS 메서드 처리
- [ ] HTTP 메서드 검증
- [ ] 요청 파싱 에러 처리
- [ ] 응답 JSON 인코딩
- [ ] main()에 라우팅 등록 (함수 호출)

---

## 4. 일반적인 에러 해결

### 🚨 에러 1: "undefined: os"

**증상:**
```
./main.go:100:10: undefined: os
```

**해결:**
```go
import (
    "os"  // ← 이거 추가!
    // 다른 imports...
)
```

---

### 🚨 에러 2: "cannot use ... as type interface{}"

**증상:**
```go
xData := []string{"a", "b", "c"}
trace.X = xData  // 에러!
```

**해결:**
```go
// ✅ 타입 변환 필요
xData := []string{"a", "b", "c"}
xInterface := make([]interface{}, len(xData))
for i, v := range xData {
    xInterface[i] = v
}
trace.X = xInterface  // OK!
```

---

### 🚨 에러 3: "json: cannot unmarshal ... into Go struct field"

**증상:**
```
json: cannot unmarshal string into Go struct field MyStruct.count of type int
```

**원인:** JSON 타입과 Go 타입 불일치

**해결:**
```go
// JSON에서 숫자가 문자열로 올 수 있음
type MyStruct struct {
    Count string `json:"count"`  // int → string
}

// 또는 변환 로직 추가
count, _ := strconv.Atoi(data.Count)
```

---

### 🚨 에러 4: "no such file or directory"

**증상:**
```
open ads.csv: no such file or directory
```

**해결:**
```go
// ✅ 절대/상대 경로 정확히
filePath := filepath.Join("data", "brands", brandID, "raw", "ads.csv")

// ✅ 파일 존재 확인
if _, err := os.Stat(filePath); os.IsNotExist(err) {
    return fmt.Errorf("파일 없음: %s", filePath)
}

// ✅ 현재 디렉토리 확인
pwd, _ := os.Getwd()
log.Printf("현재 경로: %s", pwd)
```

---

### 🚨 에러 5: "Handler.ServeHTTP method is nil"

**증상:**
```
panic: runtime error: invalid memory address or nil pointer dereference
```

**원인:** 핸들러 등록 시 함수 호출 누락

**해결:**
```go
// ❌ 잘못된 코드
mux.HandleFunc("/api/test", myHandler)

// ✅ 올바른 코드
mux.HandleFunc("/api/test", myHandler())  // () 추가!
```

---

### 🚨 에러 6: "invalid character ... looking for beginning of value"

**증상:**
```
invalid character '<' looking for beginning of value
```

**원인:** JSON 파싱 실패 (HTML이나 다른 형식 받음)

**해결:**
```go
// ✅ 응답 타입 확인
resp, err := http.Get(url)
if err != nil {
    return err
}

// Content-Type 확인
contentType := resp.Header.Get("Content-Type")
if !strings.Contains(contentType, "application/json") {
    return fmt.Errorf("JSON이 아님: %s", contentType)
}

// 바디 읽어서 로그 출력
body, _ := io.ReadAll(resp.Body)
log.Printf("응답: %s", string(body))
```

---

## 🎯 빠른 체크리스트

### 새 API 엔드포인트 추가 시

1. **구조체 정의** (`internal/domain/models.go`)
   - [ ] 필드 대문자 시작
   - [ ] json 태그 추가
   - [ ] 주석 작성

2. **핸들러 작성** (`main.go`)
   - [ ] CORS 헤더 4개
   - [ ] OPTIONS 처리
   - [ ] HTTP 메서드 검증
   - [ ] 에러 처리
   - [ ] JSON 응답

3. **라우팅 등록** (`main()`)
   - [ ] `mux.HandleFunc("/api/...", handler())`
   - [ ] 함수 호출 () 확인

4. **테스트**
   - [ ] `go build` 성공
   - [ ] 서버 시작
   - [ ] `curl` 테스트
   - [ ] 브라우저 확인

---

## 💡 자주 사용하는 코드 스니펫

### CSV 파일 읽기
```go
file, err := os.Open("data.csv")
if err != nil {
    return err
}
defer file.Close()

reader := csv.NewReader(file)
records, err := reader.ReadAll()
```

### JSON 파일 읽기
```go
data, err := os.ReadFile("config.json")
if err != nil {
    return err
}

var config MyConfig
if err := json.Unmarshal(data, &config); err != nil {
    return err
}
```

### HTTP GET 요청
```go
resp, err := http.Get("http://api.example.com/data")
if err != nil {
    return err
}
defer resp.Body.Close()

var result MyStruct
json.NewDecoder(resp.Body).Decode(&result)
```

### 파일 존재 확인
```go
if _, err := os.Stat(filePath); os.IsNotExist(err) {
    log.Printf("파일 없음: %s", filePath)
}
```

---

## 🔧 디버깅 팁

### 1. 로그 추가하기
```go
log.Printf("디버그: 변수값 = %+v", myVariable)
log.Printf("에러 발생: %v", err)
```

### 2. 구조체 전체 출력
```go
fmt.Printf("%+v\n", myStruct)  // 필드명 포함
fmt.Printf("%#v\n", myStruct)  // Go 문법 형태
```

### 3. HTTP 요청/응답 확인
```go
// 요청 바디 읽기
body, _ := io.ReadAll(r.Body)
log.Printf("요청 바디: %s", string(body))

// 응답 확인
data, _ := json.Marshal(response)
log.Printf("응답: %s", string(data))
```

---

## 📚 관련 문서

- [[GO_FRONTEND_GUIDE]] - 상세 구현 가이드
- [[GO_QUICKSTART]] - 빠른 시작
- 프로젝트: `/Users/a1234/facebook-marketing-dashboard`

---

> [!tip] 핵심 정리
> 1. 구조체 필드는 **대문자**로 시작
> 2. json 태그 **필수**
> 3. CORS 헤더 **4개** 설정
> 4. 핸들러 등록 시 **함수 호출** ()
> 5. 에러는 **반드시 체크**

이 체크리스트를 따르면 에러 없이 개발할 수 있습니다! 🚀
