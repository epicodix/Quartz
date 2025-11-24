# 🚀 Go 언어 Day 1: 시작부터 실무 코드까지

## 📋 Today's Goal
> **"오늘 끝나고 나면 Go로 간단한 REST API 서버를 만들 수 있다!"**

## 🎯 학습 목표 (8시간)
1. Go 환경 설정 & 기본 문법 (2시간)
2. Go만의 특별한 기능 이해 (2시간)
3. 실전 프로젝트: TODO API 만들기 (4시간)

---

## 📚 Part 1: Go 환경 설정 & 기본 (1-2시간)

### 1.1 설치 & 환경설정
```bash
# Go 설치 확인
go version

# 프로젝트 생성
mkdir go-day1 && cd go-day1
go mod init github.com/yourusername/go-day1

# VS Code 확장 설치
# - Go (공식)
# - Go Test Explorer
```

### 1.2 Hello, Go! (첫 10분)
```go
// main.go
package main

import "fmt"

func main() {
    fmt.Println("Hello, Go!")
}
```

```bash
# 실행
go run main.go

# 빌드
go build -o myapp main.go
./myapp
```

### 1.3 Go 기본 문법 속성 (30분)
```go
package main

import (
    "fmt"
    "errors"
)

// 1. 변수 선언
func variables() {
    // var 명시적 선언
    var name string = "Go"
    var age int = 13
    
    // 타입 추론
    var language = "Golang"
    
    // Short declaration (함수 내부만)
    nickname := "Gopher"
    
    // 다중 선언
    var (
        x int    = 1
        y string = "hello"
    )
    
    fmt.Printf("Name: %s, Age: %d\n", name, age)
}

// 2. 함수 - 다중 반환값!
func getUserInfo(id int) (string, int, error) {
    if id <= 0 {
        return "", 0, errors.New("invalid id")
    }
    return "John", 25, nil
}

// 3. 구조체
type User struct {
    ID   int    `json:"id"`
    Name string `json:"name"`
    Age  int    `json:"age"`
}

// 4. 메서드
func (u User) Greeting() string {
    return fmt.Sprintf("Hi, I'm %s", u.Name)
}

// 5. 인터페이스
type Greeter interface {
    Greeting() string
}

func main() {
    // 에러 처리 패턴 (Go의 핵심!)
    name, age, err := getUserInfo(1)
    if err != nil {
        fmt.Printf("Error: %v\n", err)
        return
    }
    fmt.Printf("User: %s, %d\n", name, age)
    
    // 구조체 사용
    user := User{
        ID:   1,
        Name: "Alice",
        Age:  30,
    }
    fmt.Println(user.Greeting())
}
```

### 1.4 Go 특별한 기능 (30분)
```go
package main

import (
    "fmt"
    "time"
)

// 1. Goroutines (동시성)
func printNumbers(prefix string) {
    for i := 1; i <= 5; i++ {
        fmt.Printf("%s: %d\n", prefix, i)
        time.Sleep(100 * time.Millisecond)
    }
}

// 2. Channels
func worker(id int, jobs <-chan int, results chan<- int) {
    for job := range jobs {
        fmt.Printf("Worker %d processing job %d\n", id, job)
        time.Sleep(time.Second)
        results <- job * 2
    }
}

// 3. Defer (정리 작업)
func fileOperation() error {
    fmt.Println("Opening file...")
    defer fmt.Println("Closing file...") // 함수 끝날 때 실행
    
    fmt.Println("Processing file...")
    return nil
}

func main() {
    // Goroutines 실행
    go printNumbers("A")
    go printNumbers("B")
    time.Sleep(1 * time.Second)
    
    // Channel 사용
    jobs := make(chan int, 5)
    results := make(chan int, 5)
    
    // Worker 시작
    for w := 1; w <= 3; w++ {
        go worker(w, jobs, results)
    }
    
    // Job 전송
    for j := 1; j <= 5; j++ {
        jobs <- j
    }
    close(jobs)
    
    // 결과 수집
    for r := 1; r <= 5; r++ {
        <-results
    }
}
```

---

## 🔨 Part 2: 실전 프로젝트 - TODO REST API (4시간)

### 프로젝트 구조
```
go-day1/
├── main.go
├── handlers/
│   └── todo.go
├── models/
│   └── todo.go
└── go.mod
```

### Step 1: 모델 정의
```go
// models/todo.go
package models

import "time"

type Todo struct {
    ID        int       `json:"id"`
    Title     string    `json:"title"`
    Completed bool      `json:"completed"`
    CreatedAt time.Time `json:"created_at"`
}

type CreateTodoRequest struct {
    Title string `json:"title"`
}

type UpdateTodoRequest struct {
    Title     string `json:"title"`
    Completed bool   `json:"completed"`
}
```

### Step 2: 핸들러 구현
```go
// handlers/todo.go
package handlers

import (
    "encoding/json"
    "net/http"
    "strconv"
    "sync"
    "time"
    
    "github.com/gorilla/mux"
    "github.com/yourusername/go-day1/models"
)

type TodoHandler struct {
    todos  map[int]*models.Todo
    nextID int
    mu     sync.RWMutex
}

func NewTodoHandler() *TodoHandler {
    return &TodoHandler{
        todos:  make(map[int]*models.Todo),
        nextID: 1,
    }
}

// GET /todos
func (h *TodoHandler) GetTodos(w http.ResponseWriter, r *http.Request) {
    h.mu.RLock()
    defer h.mu.RUnlock()
    
    todos := make([]*models.Todo, 0, len(h.todos))
    for _, todo := range h.todos {
        todos = append(todos, todo)
    }
    
    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(todos)
}

// GET /todos/{id}
func (h *TodoHandler) GetTodo(w http.ResponseWriter, r *http.Request) {
    vars := mux.Vars(r)
    id, err := strconv.Atoi(vars["id"])
    if err != nil {
        http.Error(w, "Invalid ID", http.StatusBadRequest)
        return
    }
    
    h.mu.RLock()
    todo, exists := h.todos[id]
    h.mu.RUnlock()
    
    if !exists {
        http.Error(w, "Todo not found", http.StatusNotFound)
        return
    }
    
    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(todo)
}

// POST /todos
func (h *TodoHandler) CreateTodo(w http.ResponseWriter, r *http.Request) {
    var req models.CreateTodoRequest
    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        http.Error(w, "Invalid request body", http.StatusBadRequest)
        return
    }
    
    h.mu.Lock()
    todo := &models.Todo{
        ID:        h.nextID,
        Title:     req.Title,
        Completed: false,
        CreatedAt: time.Now(),
    }
    h.todos[h.nextID] = todo
    h.nextID++
    h.mu.Unlock()
    
    w.Header().Set("Content-Type", "application/json")
    w.WriteHeader(http.StatusCreated)
    json.NewEncoder(w).Encode(todo)
}

// PUT /todos/{id}
func (h *TodoHandler) UpdateTodo(w http.ResponseWriter, r *http.Request) {
    vars := mux.Vars(r)
    id, err := strconv.Atoi(vars["id"])
    if err != nil {
        http.Error(w, "Invalid ID", http.StatusBadRequest)
        return
    }
    
    var req models.UpdateTodoRequest
    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        http.Error(w, "Invalid request body", http.StatusBadRequest)
        return
    }
    
    h.mu.Lock()
    todo, exists := h.todos[id]
    if !exists {
        h.mu.Unlock()
        http.Error(w, "Todo not found", http.StatusNotFound)
        return
    }
    
    todo.Title = req.Title
    todo.Completed = req.Completed
    h.mu.Unlock()
    
    w.Header().Set("Content-Type", "application/json")
    json.NewEncoder(w).Encode(todo)
}

// DELETE /todos/{id}
func (h *TodoHandler) DeleteTodo(w http.ResponseWriter, r *http.Request) {
    vars := mux.Vars(r)
    id, err := strconv.Atoi(vars["id"])
    if err != nil {
        http.Error(w, "Invalid ID", http.StatusBadRequest)
        return
    }
    
    h.mu.Lock()
    _, exists := h.todos[id]
    if !exists {
        h.mu.Unlock()
        http.Error(w, "Todo not found", http.StatusNotFound)
        return
    }
    
    delete(h.todos, id)
    h.mu.Unlock()
    
    w.WriteHeader(http.StatusNoContent)
}
```

### Step 3: 메인 서버
```go
// main.go
package main

import (
    "log"
    "net/http"
    "os"
    "time"
    
    "github.com/gorilla/mux"
    "github.com/yourusername/go-day1/handlers"
)

// Middleware
func loggingMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        start := time.Now()
        log.Printf("[%s] %s %s", r.Method, r.RequestURI, time.Since(start))
        next.ServeHTTP(w, r)
    })
}

func main() {
    todoHandler := handlers.NewTodoHandler()
    
    r := mux.NewRouter()
    r.Use(loggingMiddleware)
    
    // Routes
    r.HandleFunc("/todos", todoHandler.GetTodos).Methods("GET")
    r.HandleFunc("/todos", todoHandler.CreateTodo).Methods("POST")
    r.HandleFunc("/todos/{id}", todoHandler.GetTodo).Methods("GET")
    r.HandleFunc("/todos/{id}", todoHandler.UpdateTodo).Methods("PUT")
    r.HandleFunc("/todos/{id}", todoHandler.DeleteTodo).Methods("DELETE")
    
    // Health check
    r.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
        w.WriteHeader(http.StatusOK)
        w.Write([]byte("OK"))
    }).Methods("GET")
    
    port := os.Getenv("PORT")
    if port == "" {
        port = "8080"
    }
    
    log.Printf("Server starting on port %s", port)
    if err := http.ListenAndServe(":"+port, r); err != nil {
        log.Fatal(err)
    }
}
```

### Step 4: 의존성 설치 & 실행
```bash
# Gorilla Mux 설치
go get -u github.com/gorilla/mux

# 실행
go run main.go

# 다른 터미널에서 테스트
# Create
curl -X POST http://localhost:8080/todos \
  -H "Content-Type: application/json" \
  -d '{"title":"Learn Go"}'

# Get all
curl http://localhost:8080/todos

# Update
curl -X PUT http://localhost:8080/todos/1 \
  -H "Content-Type: application/json" \
  -d '{"title":"Learn Go","completed":true}'

# Delete
curl -X DELETE http://localhost:8080/todos/1
```

---

## 🎯 Day 1 체크리스트

### ✅ 오늘 배운 것
- [ ] Go 기본 문법 (변수, 함수, 구조체)
- [ ] Error handling 패턴
- [ ] Goroutines & Channels 기초
- [ ] HTTP 서버 구현
- [ ] REST API 설계

### 📝 숙제
1. Todo API에 다음 기능 추가:
   - 검색 기능 (query parameter)
   - 정렬 기능 (created_at, completed)
   - 페이지네이션

2. 에러 처리 개선:
   - Custom error types
   - Proper HTTP status codes

### 🚀 내일 예고 (Day 2)
- Database 연동 (PostgreSQL)
- Context 활용
- Testing 작성
- Docker 배포

---

## 💡 추가 학습 자료
- [A Tour of Go](https://go.dev/tour/)
- [Effective Go](https://go.dev/doc/effective_go)
- [Go by Example](https://gobyexample.com/)

**🎉 축하합니다! Day 1을 완료했습니다. 이제 당신은 Go로 REST API를 만들 수 있습니다!**