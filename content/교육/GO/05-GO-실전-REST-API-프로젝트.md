---
title: GO 실전 REST API 프로젝트
tags:
  - golang
  - rest-api
  - http
  - json
  - web-development
  - project
aliases:
  - Go-REST-API
  - Go-HTTP-Server
  - GO-실전프로젝트
date: 2025-11-26
category: 교육/GO/실전
status: 완성
priority: 높음
---

# 🚀 GO 실전 REST API 프로젝트

## 📋 목차
- [[#1. 프로젝트 설정|1. 프로젝트 설정]]
- [[#2. 기본 HTTP 서버|2. 기본 HTTP 서버]]
- [[#3. TODO API 구현|3. TODO API 구현]]
- [[#4. 미들웨어 구현|4. 미들웨어 구현]]
- [[#5. 에러 처리|5. 에러 처리]]
- [[#6. 테스트 작성|6. 테스트 작성]]

---

## 1. 프로젝트 설정

### 📁 프로젝트 구조

```
todo-api/
├── go.mod
├── go.sum
├── main.go
├── config/
│   └── config.go
├── models/
│   ├── todo.go
│   ├── user.go
│   └── response.go
├── handlers/
│   ├── todo.go
│   ├── user.go
│   └── health.go
├── middleware/
│   ├── auth.go
│   ├── logging.go
│   ├── cors.go
│   └── ratelimit.go
├── storage/
│   ├── interface.go
│   ├── memory.go
│   └── postgres.go
├── utils/
│   ├── validator.go
│   └── jwt.go
└── tests/
    ├── handlers_test.go
    └── integration_test.go
```

### 🎯 프로젝트 초기화

```bash
# 프로젝트 생성
mkdir todo-api && cd todo-api
go mod init github.com/yourusername/todo-api

# 필요한 의존성 설치
go get github.com/gorilla/mux
go get github.com/joho/godotenv
go get github.com/golang-jwt/jwt/v4
go get github.com/go-playground/validator/v10
go get golang.org/x/time
```

### ⚙️ 설정 구조

```go
// config/config.go
package config

import (
    "log"
    "os"
    "strconv"
    
    "github.com/joho/godotenv"
)

type Config struct {
    Port        string
    Environment string
    JWTSecret   string
    DBHost      string
    DBPort      int
    DBUser      string
    DBPassword  string
    DBName      string
    RateLimit   int
}

func Load() *Config {
    // .env 파일 로드 (옵션)
    if err := godotenv.Load(); err != nil {
        log.Println("No .env file found")
    }
    
    config := &Config{
        Port:        getEnv("PORT", "8080"),
        Environment: getEnv("ENVIRONMENT", "development"),
        JWTSecret:   getEnv("JWT_SECRET", "your-secret-key"),
        DBHost:      getEnv("DB_HOST", "localhost"),
        DBPort:      getEnvAsInt("DB_PORT", 5432),
        DBUser:      getEnv("DB_USER", "postgres"),
        DBPassword:  getEnv("DB_PASSWORD", "password"),
        DBName:      getEnv("DB_NAME", "todoapp"),
        RateLimit:   getEnvAsInt("RATE_LIMIT", 100),
    }
    
    return config
}

func getEnv(key, defaultValue string) string {
    if value, exists := os.LookupEnv(key); exists {
        return value
    }
    return defaultValue
}

func getEnvAsInt(name string, defaultValue int) int {
    valueStr := getEnv(name, "")
    if value, err := strconv.Atoi(valueStr); err == nil {
        return value
    }
    return defaultValue
}
```

---

## 2. 기본 HTTP 서버

### 🔧 메인 서버 구조

```go
// main.go
package main

import (
    "context"
    "log"
    "net/http"
    "os"
    "os/signal"
    "syscall"
    "time"
    
    "github.com/gorilla/mux"
    "github.com/yourusername/todo-api/config"
    "github.com/yourusername/todo-api/handlers"
    "github.com/yourusername/todo-api/middleware"
    "github.com/yourusername/todo-api/storage"
)

type Server struct {
    config  *config.Config
    router  *mux.Router
    storage storage.Storage
}

func NewServer(cfg *config.Config) *Server {
    s := &Server{
        config: cfg,
        router: mux.NewRouter(),
    }
    
    // 스토리지 초기화 (메모리 스토리지 사용)
    s.storage = storage.NewMemoryStorage()
    
    // 라우터 설정
    s.setupRoutes()
    s.setupMiddleware()
    
    return s
}

func (s *Server) setupMiddleware() {
    // 전역 미들웨어 적용 순서가 중요!
    s.router.Use(middleware.LoggingMiddleware)
    s.router.Use(middleware.CORSMiddleware)
    s.router.Use(middleware.RateLimitMiddleware(s.config.RateLimit))
}

func (s *Server) setupRoutes() {
    // Health check
    s.router.HandleFunc("/health", handlers.HealthCheck).Methods("GET")
    
    // API v1
    api := s.router.PathPrefix("/api/v1").Subrouter()
    
    // Public routes
    api.HandleFunc("/auth/login", handlers.Login).Methods("POST")
    api.HandleFunc("/auth/register", handlers.Register).Methods("POST")
    
    // Protected routes
    protected := api.PathPrefix("").Subrouter()
    protected.Use(middleware.AuthMiddleware(s.config.JWTSecret))
    
    // TODO routes
    todoHandler := handlers.NewTodoHandler(s.storage)
    protected.HandleFunc("/todos", todoHandler.GetTodos).Methods("GET")
    protected.HandleFunc("/todos", todoHandler.CreateTodo).Methods("POST")
    protected.HandleFunc("/todos/{id}", todoHandler.GetTodo).Methods("GET")
    protected.HandleFunc("/todos/{id}", todoHandler.UpdateTodo).Methods("PUT")
    protected.HandleFunc("/todos/{id}", todoHandler.DeleteTodo).Methods("DELETE")
    
    // User routes
    userHandler := handlers.NewUserHandler(s.storage)
    protected.HandleFunc("/users/profile", userHandler.GetProfile).Methods("GET")
    protected.HandleFunc("/users/profile", userHandler.UpdateProfile).Methods("PUT")
}

func (s *Server) Start() error {
    server := &http.Server{
        Addr:         ":" + s.config.Port,
        Handler:      s.router,
        ReadTimeout:  10 * time.Second,
        WriteTimeout: 10 * time.Second,
        IdleTimeout:  60 * time.Second,
    }
    
    // Graceful shutdown 처리
    go func() {
        sigChan := make(chan os.Signal, 1)
        signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)
        <-sigChan
        
        log.Println("Shutting down server...")
        
        ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
        defer cancel()
        
        if err := server.Shutdown(ctx); err != nil {
            log.Printf("Error during server shutdown: %v", err)
        }
    }()
    
    log.Printf("Server starting on port %s", s.config.Port)
    return server.ListenAndServe()
}

func main() {
    cfg := config.Load()
    server := NewServer(cfg)
    
    if err := server.Start(); err != nil && err != http.ErrServerClosed {
        log.Fatalf("Server failed to start: %v", err)
    }
    
    log.Println("Server stopped")
}
```

---

## 3. TODO API 구현

### 📊 데이터 모델

```go
// models/todo.go
package models

import (
    "time"
    "github.com/go-playground/validator/v10"
)

type Todo struct {
    ID          int       `json:"id"`
    UserID      int       `json:"user_id"`
    Title       string    `json:"title" validate:"required,min=1,max=100"`
    Description string    `json:"description" validate:"max=500"`
    Completed   bool      `json:"completed"`
    Priority    Priority  `json:"priority" validate:"oneof=low medium high"`
    DueDate     *time.Time `json:"due_date,omitempty"`
    CreatedAt   time.Time `json:"created_at"`
    UpdatedAt   time.Time `json:"updated_at"`
}

type Priority string

const (
    PriorityLow    Priority = "low"
    PriorityMedium Priority = "medium"
    PriorityHigh   Priority = "high"
)

type CreateTodoRequest struct {
    Title       string     `json:"title" validate:"required,min=1,max=100"`
    Description string     `json:"description" validate:"max=500"`
    Priority    Priority   `json:"priority" validate:"oneof=low medium high"`
    DueDate     *time.Time `json:"due_date,omitempty"`
}

type UpdateTodoRequest struct {
    Title       *string    `json:"title,omitempty" validate:"omitempty,min=1,max=100"`
    Description *string    `json:"description,omitempty" validate:"omitempty,max=500"`
    Completed   *bool      `json:"completed,omitempty"`
    Priority    *Priority  `json:"priority,omitempty" validate:"omitempty,oneof=low medium high"`
    DueDate     *time.Time `json:"due_date,omitempty"`
}

type TodoFilter struct {
    UserID    int      `json:"user_id"`
    Completed *bool    `json:"completed,omitempty"`
    Priority  Priority `json:"priority,omitempty"`
    Limit     int      `json:"limit"`
    Offset    int      `json:"offset"`
}

// models/user.go
package models

type User struct {
    ID        int       `json:"id"`
    Username  string    `json:"username" validate:"required,min=3,max=20"`
    Email     string    `json:"email" validate:"required,email"`
    Password  string    `json:"-"`  // 패스워드는 JSON에서 제외
    FullName  string    `json:"full_name" validate:"max=50"`
    CreatedAt time.Time `json:"created_at"`
    UpdatedAt time.Time `json:"updated_at"`
}

type LoginRequest struct {
    Username string `json:"username" validate:"required"`
    Password string `json:"password" validate:"required,min=6"`
}

type RegisterRequest struct {
    Username string `json:"username" validate:"required,min=3,max=20"`
    Email    string `json:"email" validate:"required,email"`
    Password string `json:"password" validate:"required,min=6"`
    FullName string `json:"full_name" validate:"max=50"`
}

// models/response.go
package models

type APIResponse struct {
    Success bool        `json:"success"`
    Data    interface{} `json:"data,omitempty"`
    Error   *APIError   `json:"error,omitempty"`
}

type APIError struct {
    Code    string `json:"code"`
    Message string `json:"message"`
    Details string `json:"details,omitempty"`
}

type PaginatedResponse struct {
    Data       interface{} `json:"data"`
    Pagination Pagination  `json:"pagination"`
}

type Pagination struct {
    Page      int `json:"page"`
    PerPage   int `json:"per_page"`
    Total     int `json:"total"`
    TotalPage int `json:"total_pages"`
}
```

### 🗄️ 스토리지 인터페이스

```go
// storage/interface.go
package storage

import (
    "github.com/yourusername/todo-api/models"
)

type Storage interface {
    // Todo operations
    GetTodos(filter models.TodoFilter) ([]models.Todo, int, error)
    GetTodoByID(userID, todoID int) (*models.Todo, error)
    CreateTodo(todo *models.Todo) error
    UpdateTodo(userID, todoID int, updates models.UpdateTodoRequest) (*models.Todo, error)
    DeleteTodo(userID, todoID int) error
    
    // User operations
    GetUserByID(userID int) (*models.User, error)
    GetUserByUsername(username string) (*models.User, error)
    CreateUser(user *models.User) error
    UpdateUser(userID int, user *models.User) error
}

// storage/memory.go
package storage

import (
    "errors"
    "sync"
    "time"
    
    "github.com/yourusername/todo-api/models"
)

type MemoryStorage struct {
    mu      sync.RWMutex
    todos   map[int]*models.Todo
    users   map[int]*models.User
    usersByUsername map[string]*models.User
    nextTodoID int
    nextUserID int
}

func NewMemoryStorage() *MemoryStorage {
    ms := &MemoryStorage{
        todos:           make(map[int]*models.Todo),
        users:           make(map[int]*models.User),
        usersByUsername: make(map[string]*models.User),
        nextTodoID:      1,
        nextUserID:      1,
    }
    
    // 테스트 데이터 추가
    ms.seedData()
    
    return ms
}

func (ms *MemoryStorage) seedData() {
    // 테스트 사용자 추가
    testUser := &models.User{
        ID:        1,
        Username:  "testuser",
        Email:     "test@example.com",
        FullName:  "Test User",
        CreatedAt: time.Now(),
        UpdatedAt: time.Now(),
    }
    ms.users[1] = testUser
    ms.usersByUsername["testuser"] = testUser
    ms.nextUserID = 2
    
    // 테스트 TODO 추가
    testTodos := []*models.Todo{
        {
            ID:          1,
            UserID:      1,
            Title:       "Learn Go",
            Description: "Complete Go tutorial",
            Priority:    models.PriorityHigh,
            Completed:   false,
            CreatedAt:   time.Now(),
            UpdatedAt:   time.Now(),
        },
        {
            ID:          2,
            UserID:      1,
            Title:       "Build REST API",
            Description: "Create a TODO API with Go",
            Priority:    models.PriorityMedium,
            Completed:   true,
            CreatedAt:   time.Now(),
            UpdatedAt:   time.Now(),
        },
    }
    
    for _, todo := range testTodos {
        ms.todos[todo.ID] = todo
    }
    ms.nextTodoID = 3
}

func (ms *MemoryStorage) GetTodos(filter models.TodoFilter) ([]models.Todo, int, error) {
    ms.mu.RLock()
    defer ms.mu.RUnlock()
    
    var todos []models.Todo
    
    for _, todo := range ms.todos {
        if todo.UserID != filter.UserID {
            continue
        }
        
        // 완료 상태 필터
        if filter.Completed != nil && todo.Completed != *filter.Completed {
            continue
        }
        
        // 우선순위 필터
        if filter.Priority != "" && todo.Priority != filter.Priority {
            continue
        }
        
        todos = append(todos, *todo)
    }
    
    total := len(todos)
    
    // 페이지네이션
    start := filter.Offset
    end := start + filter.Limit
    
    if start > total {
        return []models.Todo{}, total, nil
    }
    
    if end > total {
        end = total
    }
    
    return todos[start:end], total, nil
}

func (ms *MemoryStorage) GetTodoByID(userID, todoID int) (*models.Todo, error) {
    ms.mu.RLock()
    defer ms.mu.RUnlock()
    
    todo, exists := ms.todos[todoID]
    if !exists {
        return nil, errors.New("todo not found")
    }
    
    if todo.UserID != userID {
        return nil, errors.New("access denied")
    }
    
    return todo, nil
}

func (ms *MemoryStorage) CreateTodo(todo *models.Todo) error {
    ms.mu.Lock()
    defer ms.mu.Unlock()
    
    todo.ID = ms.nextTodoID
    todo.CreatedAt = time.Now()
    todo.UpdatedAt = time.Now()
    
    ms.todos[todo.ID] = todo
    ms.nextTodoID++
    
    return nil
}

func (ms *MemoryStorage) UpdateTodo(userID, todoID int, updates models.UpdateTodoRequest) (*models.Todo, error) {
    ms.mu.Lock()
    defer ms.mu.Unlock()
    
    todo, exists := ms.todos[todoID]
    if !exists {
        return nil, errors.New("todo not found")
    }
    
    if todo.UserID != userID {
        return nil, errors.New("access denied")
    }
    
    // 업데이트 적용
    if updates.Title != nil {
        todo.Title = *updates.Title
    }
    if updates.Description != nil {
        todo.Description = *updates.Description
    }
    if updates.Completed != nil {
        todo.Completed = *updates.Completed
    }
    if updates.Priority != nil {
        todo.Priority = *updates.Priority
    }
    if updates.DueDate != nil {
        todo.DueDate = updates.DueDate
    }
    
    todo.UpdatedAt = time.Now()
    
    return todo, nil
}

func (ms *MemoryStorage) DeleteTodo(userID, todoID int) error {
    ms.mu.Lock()
    defer ms.mu.Unlock()
    
    todo, exists := ms.todos[todoID]
    if !exists {
        return errors.New("todo not found")
    }
    
    if todo.UserID != userID {
        return errors.New("access denied")
    }
    
    delete(ms.todos, todoID)
    return nil
}

func (ms *MemoryStorage) GetUserByID(userID int) (*models.User, error) {
    ms.mu.RLock()
    defer ms.mu.RUnlock()
    
    user, exists := ms.users[userID]
    if !exists {
        return nil, errors.New("user not found")
    }
    
    return user, nil
}

func (ms *MemoryStorage) GetUserByUsername(username string) (*models.User, error) {
    ms.mu.RLock()
    defer ms.mu.RUnlock()
    
    user, exists := ms.usersByUsername[username]
    if !exists {
        return nil, errors.New("user not found")
    }
    
    return user, nil
}

func (ms *MemoryStorage) CreateUser(user *models.User) error {
    ms.mu.Lock()
    defer ms.mu.Unlock()
    
    // 사용자명 중복 체크
    if _, exists := ms.usersByUsername[user.Username]; exists {
        return errors.New("username already exists")
    }
    
    user.ID = ms.nextUserID
    user.CreatedAt = time.Now()
    user.UpdatedAt = time.Now()
    
    ms.users[user.ID] = user
    ms.usersByUsername[user.Username] = user
    ms.nextUserID++
    
    return nil
}

func (ms *MemoryStorage) UpdateUser(userID int, user *models.User) error {
    ms.mu.Lock()
    defer ms.mu.Unlock()
    
    existingUser, exists := ms.users[userID]
    if !exists {
        return errors.New("user not found")
    }
    
    existingUser.FullName = user.FullName
    existingUser.Email = user.Email
    existingUser.UpdatedAt = time.Now()
    
    return nil
}
```

### 🎛️ TODO 핸들러

```go
// handlers/todo.go
package handlers

import (
    "encoding/json"
    "net/http"
    "strconv"
    
    "github.com/gorilla/mux"
    "github.com/yourusername/todo-api/models"
    "github.com/yourusername/todo-api/storage"
    "github.com/yourusername/todo-api/utils"
)

type TodoHandler struct {
    storage   storage.Storage
    validator *utils.Validator
}

func NewTodoHandler(storage storage.Storage) *TodoHandler {
    return &TodoHandler{
        storage:   storage,
        validator: utils.NewValidator(),
    }
}

func (h *TodoHandler) GetTodos(w http.ResponseWriter, r *http.Request) {
    userID := getUserIDFromContext(r.Context())
    
    // 쿼리 파라미터 파싱
    filter := models.TodoFilter{
        UserID: userID,
        Limit:  10,
        Offset: 0,
    }
    
    // completed 필터
    if completedStr := r.URL.Query().Get("completed"); completedStr != "" {
        if completed, err := strconv.ParseBool(completedStr); err == nil {
            filter.Completed = &completed
        }
    }
    
    // priority 필터
    if priority := r.URL.Query().Get("priority"); priority != "" {
        filter.Priority = models.Priority(priority)
    }
    
    // 페이지네이션
    if pageStr := r.URL.Query().Get("page"); pageStr != "" {
        if page, err := strconv.Atoi(pageStr); err == nil && page > 0 {
            filter.Offset = (page - 1) * filter.Limit
        }
    }
    
    if limitStr := r.URL.Query().Get("limit"); limitStr != "" {
        if limit, err := strconv.Atoi(limitStr); err == nil && limit > 0 && limit <= 100 {
            filter.Limit = limit
        }
    }
    
    todos, total, err := h.storage.GetTodos(filter)
    if err != nil {
        utils.WriteErrorResponse(w, http.StatusInternalServerError, "INTERNAL_ERROR", err.Error())
        return
    }
    
    // 페이지네이션 정보
    page := (filter.Offset / filter.Limit) + 1
    totalPages := (total + filter.Limit - 1) / filter.Limit
    
    response := models.PaginatedResponse{
        Data: todos,
        Pagination: models.Pagination{
            Page:      page,
            PerPage:   filter.Limit,
            Total:     total,
            TotalPage: totalPages,
        },
    }
    
    utils.WriteSuccessResponse(w, response)
}

func (h *TodoHandler) GetTodo(w http.ResponseWriter, r *http.Request) {
    userID := getUserIDFromContext(r.Context())
    
    vars := mux.Vars(r)
    todoID, err := strconv.Atoi(vars["id"])
    if err != nil {
        utils.WriteErrorResponse(w, http.StatusBadRequest, "INVALID_ID", "Invalid todo ID")
        return
    }
    
    todo, err := h.storage.GetTodoByID(userID, todoID)
    if err != nil {
        utils.WriteErrorResponse(w, http.StatusNotFound, "TODO_NOT_FOUND", err.Error())
        return
    }
    
    utils.WriteSuccessResponse(w, todo)
}

func (h *TodoHandler) CreateTodo(w http.ResponseWriter, r *http.Request) {
    userID := getUserIDFromContext(r.Context())
    
    var req models.CreateTodoRequest
    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        utils.WriteErrorResponse(w, http.StatusBadRequest, "INVALID_JSON", "Invalid request body")
        return
    }
    
    if err := h.validator.Validate(req); err != nil {
        utils.WriteValidationErrorResponse(w, err)
        return
    }
    
    todo := &models.Todo{
        UserID:      userID,
        Title:       req.Title,
        Description: req.Description,
        Priority:    req.Priority,
        DueDate:     req.DueDate,
        Completed:   false,
    }
    
    if err := h.storage.CreateTodo(todo); err != nil {
        utils.WriteErrorResponse(w, http.StatusInternalServerError, "CREATE_ERROR", err.Error())
        return
    }
    
    w.WriteHeader(http.StatusCreated)
    utils.WriteSuccessResponse(w, todo)
}

func (h *TodoHandler) UpdateTodo(w http.ResponseWriter, r *http.Request) {
    userID := getUserIDFromContext(r.Context())
    
    vars := mux.Vars(r)
    todoID, err := strconv.Atoi(vars["id"])
    if err != nil {
        utils.WriteErrorResponse(w, http.StatusBadRequest, "INVALID_ID", "Invalid todo ID")
        return
    }
    
    var req models.UpdateTodoRequest
    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        utils.WriteErrorResponse(w, http.StatusBadRequest, "INVALID_JSON", "Invalid request body")
        return
    }
    
    if err := h.validator.Validate(req); err != nil {
        utils.WriteValidationErrorResponse(w, err)
        return
    }
    
    todo, err := h.storage.UpdateTodo(userID, todoID, req)
    if err != nil {
        if err.Error() == "todo not found" || err.Error() == "access denied" {
            utils.WriteErrorResponse(w, http.StatusNotFound, "TODO_NOT_FOUND", err.Error())
        } else {
            utils.WriteErrorResponse(w, http.StatusInternalServerError, "UPDATE_ERROR", err.Error())
        }
        return
    }
    
    utils.WriteSuccessResponse(w, todo)
}

func (h *TodoHandler) DeleteTodo(w http.ResponseWriter, r *http.Request) {
    userID := getUserIDFromContext(r.Context())
    
    vars := mux.Vars(r)
    todoID, err := strconv.Atoi(vars["id"])
    if err != nil {
        utils.WriteErrorResponse(w, http.StatusBadRequest, "INVALID_ID", "Invalid todo ID")
        return
    }
    
    err = h.storage.DeleteTodo(userID, todoID)
    if err != nil {
        if err.Error() == "todo not found" || err.Error() == "access denied" {
            utils.WriteErrorResponse(w, http.StatusNotFound, "TODO_NOT_FOUND", err.Error())
        } else {
            utils.WriteErrorResponse(w, http.StatusInternalServerError, "DELETE_ERROR", err.Error())
        }
        return
    }
    
    w.WriteHeader(http.StatusNoContent)
}

// 컨텍스트에서 사용자 ID 추출
func getUserIDFromContext(ctx context.Context) int {
    if userID, ok := ctx.Value("user_id").(int); ok {
        return userID
    }
    return 0
}

// handlers/health.go
package handlers

func HealthCheck(w http.ResponseWriter, r *http.Request) {
    utils.WriteSuccessResponse(w, map[string]interface{}{
        "status":    "healthy",
        "timestamp": time.Now(),
        "version":   "1.0.0",
    })
}
```

---

## 4. 미들웨어 구현

### 🔐 인증 미들웨어

```go
// middleware/auth.go
package middleware

import (
    "context"
    "net/http"
    "strings"
    
    "github.com/yourusername/todo-api/utils"
)

func AuthMiddleware(jwtSecret string) func(http.Handler) http.Handler {
    return func(next http.Handler) http.Handler {
        return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
            // Authorization 헤더 확인
            authHeader := r.Header.Get("Authorization")
            if authHeader == "" {
                utils.WriteErrorResponse(w, http.StatusUnauthorized, "MISSING_TOKEN", "Authorization header required")
                return
            }
            
            // Bearer 토큰 추출
            tokenParts := strings.SplitN(authHeader, " ", 2)
            if len(tokenParts) != 2 || tokenParts[0] != "Bearer" {
                utils.WriteErrorResponse(w, http.StatusUnauthorized, "INVALID_TOKEN", "Invalid authorization format")
                return
            }
            
            tokenString := tokenParts[1]
            
            // JWT 토큰 검증
            claims, err := utils.ValidateJWT(tokenString, jwtSecret)
            if err != nil {
                utils.WriteErrorResponse(w, http.StatusUnauthorized, "INVALID_TOKEN", err.Error())
                return
            }
            
            // 사용자 ID를 컨텍스트에 저장
            userID := int(claims["user_id"].(float64))
            ctx := context.WithValue(r.Context(), "user_id", userID)
            
            next.ServeHTTP(w, r.WithContext(ctx))
        })
    }
}

// middleware/logging.go
package middleware

import (
    "log"
    "net/http"
    "time"
)

func LoggingMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        start := time.Now()
        
        // Response writer wrapper to capture status code
        lrw := &loggingResponseWriter{
            ResponseWriter: w,
            statusCode:     200,
        }
        
        next.ServeHTTP(lrw, r)
        
        duration := time.Since(start)
        log.Printf("[%s] %s %s %d %v", 
            r.Method, r.RequestURI, r.RemoteAddr, lrw.statusCode, duration)
    })
}

type loggingResponseWriter struct {
    http.ResponseWriter
    statusCode int
}

func (lrw *loggingResponseWriter) WriteHeader(code int) {
    lrw.statusCode = code
    lrw.ResponseWriter.WriteHeader(code)
}

// middleware/cors.go
package middleware

func CORSMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        w.Header().Set("Access-Control-Allow-Origin", "*")
        w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
        w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")
        
        if r.Method == "OPTIONS" {
            w.WriteHeader(http.StatusOK)
            return
        }
        
        next.ServeHTTP(w, r)
    })
}

// middleware/ratelimit.go
package middleware

import (
    "net/http"
    "sync"
    "time"
    
    "golang.org/x/time/rate"
    "github.com/yourusername/todo-api/utils"
)

type IPRateLimiter struct {
    ips map[string]*rate.Limiter
    mu  *sync.RWMutex
    r   rate.Limit
    b   int
}

func NewIPRateLimiter(r rate.Limit, b int) *IPRateLimiter {
    i := &IPRateLimiter{
        ips: make(map[string]*rate.Limiter),
        mu:  &sync.RWMutex{},
        r:   r,
        b:   b,
    }
    
    return i
}

func (i *IPRateLimiter) AddIP(ip string) *rate.Limiter {
    i.mu.Lock()
    defer i.mu.Unlock()
    
    limiter := rate.NewLimiter(i.r, i.b)
    i.ips[ip] = limiter
    
    return limiter
}

func (i *IPRateLimiter) GetLimiter(ip string) *rate.Limiter {
    i.mu.Lock()
    limiter, exists := i.ips[ip]
    
    if !exists {
        i.mu.Unlock()
        return i.AddIP(ip)
    }
    
    i.mu.Unlock()
    return limiter
}

var limiter = NewIPRateLimiter(1, 5) // 1 request per second, burst of 5

func RateLimitMiddleware(requestsPerSecond int) func(http.Handler) http.Handler {
    return func(next http.Handler) http.Handler {
        return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
            ip := r.RemoteAddr
            limiter := limiter.GetLimiter(ip)
            
            if !limiter.Allow() {
                utils.WriteErrorResponse(w, http.StatusTooManyRequests, "RATE_LIMIT_EXCEEDED", "Too many requests")
                return
            }
            
            next.ServeHTTP(w, r)
        })
    }
}
```

---

## 5. 에러 처리

### 🛠️ 유틸리티 함수들

```go
// utils/validator.go
package utils

import (
    "fmt"
    "strings"
    
    "github.com/go-playground/validator/v10"
)

type Validator struct {
    validate *validator.Validate
}

func NewValidator() *Validator {
    return &Validator{
        validate: validator.New(),
    }
}

func (v *Validator) Validate(i interface{}) error {
    return v.validate.Struct(i)
}

func (v *Validator) GetValidationErrors(err error) []string {
    var errors []string
    
    if validationErrors, ok := err.(validator.ValidationErrors); ok {
        for _, err := range validationErrors {
            switch err.Tag() {
            case "required":
                errors = append(errors, fmt.Sprintf("%s is required", err.Field()))
            case "email":
                errors = append(errors, fmt.Sprintf("%s must be a valid email", err.Field()))
            case "min":
                errors = append(errors, fmt.Sprintf("%s must be at least %s characters", err.Field(), err.Param()))
            case "max":
                errors = append(errors, fmt.Sprintf("%s must be at most %s characters", err.Field(), err.Param()))
            case "oneof":
                errors = append(errors, fmt.Sprintf("%s must be one of: %s", err.Field(), err.Param()))
            default:
                errors = append(errors, fmt.Sprintf("%s is invalid", err.Field()))
            }
        }
    }
    
    return errors
}

// utils/jwt.go
package utils

import (
    "errors"
    "time"
    
    "github.com/golang-jwt/jwt/v4"
)

type Claims struct {
    UserID   int    `json:"user_id"`
    Username string `json:"username"`
    jwt.RegisteredClaims
}

func GenerateJWT(userID int, username, secret string) (string, error) {
    claims := Claims{
        UserID:   userID,
        Username: username,
        RegisteredClaims: jwt.RegisteredClaims{
            ExpiresAt: jwt.NewNumericDate(time.Now().Add(24 * time.Hour)),
            IssuedAt:  jwt.NewNumericDate(time.Now()),
            NotBefore: jwt.NewNumericDate(time.Now()),
        },
    }
    
    token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
    return token.SignedString([]byte(secret))
}

func ValidateJWT(tokenString, secret string) (jwt.MapClaims, error) {
    token, err := jwt.Parse(tokenString, func(token *jwt.Token) (interface{}, error) {
        if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
            return nil, errors.New("unexpected signing method")
        }
        return []byte(secret), nil
    })
    
    if err != nil {
        return nil, err
    }
    
    if claims, ok := token.Claims.(jwt.MapClaims); ok && token.Valid {
        return claims, nil
    }
    
    return nil, errors.New("invalid token")
}

// utils/response.go
package utils

import (
    "encoding/json"
    "net/http"
    "github.com/go-playground/validator/v10"
    "github.com/yourusername/todo-api/models"
)

func WriteResponse(w http.ResponseWriter, statusCode int, response models.APIResponse) {
    w.Header().Set("Content-Type", "application/json")
    w.WriteHeader(statusCode)
    json.NewEncoder(w).Encode(response)
}

func WriteSuccessResponse(w http.ResponseWriter, data interface{}) {
    response := models.APIResponse{
        Success: true,
        Data:    data,
    }
    WriteResponse(w, http.StatusOK, response)
}

func WriteErrorResponse(w http.ResponseWriter, statusCode int, code, message string) {
    response := models.APIResponse{
        Success: false,
        Error: &models.APIError{
            Code:    code,
            Message: message,
        },
    }
    WriteResponse(w, statusCode, response)
}

func WriteValidationErrorResponse(w http.ResponseWriter, err error) {
    validator := NewValidator()
    errors := validator.GetValidationErrors(err)
    
    response := models.APIResponse{
        Success: false,
        Error: &models.APIError{
            Code:    "VALIDATION_ERROR",
            Message: "Validation failed",
            Details: strings.Join(errors, "; "),
        },
    }
    WriteResponse(w, http.StatusBadRequest, response)
}
```

---

## 6. 테스트 작성

### 🧪 핸들러 테스트

```go
// tests/handlers_test.go
package tests

import (
    "bytes"
    "encoding/json"
    "net/http"
    "net/http/httptest"
    "testing"
    "time"
    
    "github.com/gorilla/mux"
    "github.com/yourusername/todo-api/handlers"
    "github.com/yourusername/todo-api/models"
    "github.com/yourusername/todo-api/storage"
    "github.com/yourusername/todo-api/utils"
)

func setupTestHandler() (*handlers.TodoHandler, storage.Storage) {
    testStorage := storage.NewMemoryStorage()
    handler := handlers.NewTodoHandler(testStorage)
    return handler, testStorage
}

func TestCreateTodo(t *testing.T) {
    handler, _ := setupTestHandler()
    
    tests := []struct {
        name           string
        payload        models.CreateTodoRequest
        expectedStatus int
        expectedError  string
    }{
        {
            name: "Valid todo creation",
            payload: models.CreateTodoRequest{
                Title:       "Test Todo",
                Description: "Test Description",
                Priority:    models.PriorityMedium,
            },
            expectedStatus: http.StatusCreated,
        },
        {
            name: "Empty title should fail",
            payload: models.CreateTodoRequest{
                Title:       "",
                Description: "Test Description",
                Priority:    models.PriorityMedium,
            },
            expectedStatus: http.StatusBadRequest,
            expectedError:  "VALIDATION_ERROR",
        },
        {
            name: "Invalid priority should fail",
            payload: models.CreateTodoRequest{
                Title:       "Test Todo",
                Description: "Test Description",
                Priority:    "invalid",
            },
            expectedStatus: http.StatusBadRequest,
            expectedError:  "VALIDATION_ERROR",
        },
    }
    
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            payload, _ := json.Marshal(tt.payload)
            req := httptest.NewRequest("POST", "/todos", bytes.NewBuffer(payload))
            req.Header.Set("Content-Type", "application/json")
            
            // Mock user context
            ctx := context.WithValue(req.Context(), "user_id", 1)
            req = req.WithContext(ctx)
            
            rr := httptest.NewRecorder()
            handler.CreateTodo(rr, req)
            
            if status := rr.Code; status != tt.expectedStatus {
                t.Errorf("Expected status %d, got %d", tt.expectedStatus, status)
            }
            
            var response models.APIResponse
            json.NewDecoder(rr.Body).Decode(&response)
            
            if tt.expectedError != "" {
                if response.Success {
                    t.Errorf("Expected error response, got success")
                }
                if response.Error == nil || response.Error.Code != tt.expectedError {
                    t.Errorf("Expected error code %s, got %v", tt.expectedError, response.Error)
                }
            } else {
                if !response.Success {
                    t.Errorf("Expected success response, got error: %v", response.Error)
                }
            }
        })
    }
}

func TestGetTodos(t *testing.T) {
    handler, _ := setupTestHandler()
    
    req := httptest.NewRequest("GET", "/todos", nil)
    ctx := context.WithValue(req.Context(), "user_id", 1)
    req = req.WithContext(ctx)
    
    rr := httptest.NewRecorder()
    handler.GetTodos(rr, req)
    
    if status := rr.Code; status != http.StatusOK {
        t.Errorf("Expected status %d, got %d", http.StatusOK, status)
    }
    
    var response models.APIResponse
    json.NewDecoder(rr.Body).Decode(&response)
    
    if !response.Success {
        t.Errorf("Expected success response, got error: %v", response.Error)
    }
}

func TestGetTodosPagination(t *testing.T) {
    handler, _ := setupTestHandler()
    
    req := httptest.NewRequest("GET", "/todos?page=1&limit=1", nil)
    ctx := context.WithValue(req.Context(), "user_id", 1)
    req = req.WithContext(ctx)
    
    rr := httptest.NewRecorder()
    handler.GetTodos(rr, req)
    
    if status := rr.Code; status != http.StatusOK {
        t.Errorf("Expected status %d, got %d", http.StatusOK, status)
    }
    
    var response models.APIResponse
    json.NewDecoder(rr.Body).Decode(&response)
    
    if !response.Success {
        t.Errorf("Expected success response, got error: %v", response.Error)
    }
    
    // Check if pagination is working
    data := response.Data.(map[string]interface{})
    pagination := data["pagination"].(map[string]interface{})
    
    if pagination["per_page"] != float64(1) {
        t.Errorf("Expected per_page 1, got %v", pagination["per_page"])
    }
}

// 벤치마크 테스트
func BenchmarkCreateTodo(b *testing.B) {
    handler, _ := setupTestHandler()
    payload := models.CreateTodoRequest{
        Title:       "Benchmark Todo",
        Description: "Benchmark Description",
        Priority:    models.PriorityMedium,
    }
    
    b.ResetTimer()
    
    for i := 0; i < b.N; i++ {
        payloadBytes, _ := json.Marshal(payload)
        req := httptest.NewRequest("POST", "/todos", bytes.NewBuffer(payloadBytes))
        req.Header.Set("Content-Type", "application/json")
        ctx := context.WithValue(req.Context(), "user_id", 1)
        req = req.WithContext(ctx)
        
        rr := httptest.NewRecorder()
        handler.CreateTodo(rr, req)
    }
}
```

### 🔄 통합 테스트

```go
// tests/integration_test.go
package tests

import (
    "bytes"
    "encoding/json"
    "net/http"
    "net/http/httptest"
    "testing"
    
    "github.com/gorilla/mux"
    "github.com/yourusername/todo-api/config"
    "github.com/yourusername/todo-api/handlers"
    "github.com/yourusername/todo-api/middleware"
    "github.com/yourusername/todo-api/models"
    "github.com/yourusername/todo-api/storage"
    "github.com/yourusername/todo-api/utils"
)

func setupTestServer() *httptest.Server {
    cfg := &config.Config{
        JWTSecret: "test-secret",
    }
    
    testStorage := storage.NewMemoryStorage()
    
    router := mux.NewRouter()
    router.Use(middleware.CORSMiddleware)
    
    // API routes
    api := router.PathPrefix("/api/v1").Subrouter()
    
    // Todo routes with auth
    protected := api.PathPrefix("").Subrouter()
    protected.Use(middleware.AuthMiddleware(cfg.JWTSecret))
    
    todoHandler := handlers.NewTodoHandler(testStorage)
    protected.HandleFunc("/todos", todoHandler.GetTodos).Methods("GET")
    protected.HandleFunc("/todos", todoHandler.CreateTodo).Methods("POST")
    protected.HandleFunc("/todos/{id}", todoHandler.GetTodo).Methods("GET")
    protected.HandleFunc("/todos/{id}", todoHandler.UpdateTodo).Methods("PUT")
    protected.HandleFunc("/todos/{id}", todoHandler.DeleteTodo).Methods("DELETE")
    
    return httptest.NewServer(router)
}

func getTestJWT() string {
    token, _ := utils.GenerateJWT(1, "testuser", "test-secret")
    return token
}

func TestTodoWorkflow(t *testing.T) {
    server := setupTestServer()
    defer server.Close()
    
    token := getTestJWT()
    client := &http.Client{}
    
    // 1. Create Todo
    createPayload := models.CreateTodoRequest{
        Title:       "Integration Test Todo",
        Description: "Testing full workflow",
        Priority:    models.PriorityHigh,
    }
    
    payloadBytes, _ := json.Marshal(createPayload)
    req, _ := http.NewRequest("POST", server.URL+"/api/v1/todos", bytes.NewBuffer(payloadBytes))
    req.Header.Set("Content-Type", "application/json")
    req.Header.Set("Authorization", "Bearer "+token)
    
    resp, err := client.Do(req)
    if err != nil {
        t.Fatalf("Failed to create todo: %v", err)
    }
    defer resp.Body.Close()
    
    if resp.StatusCode != http.StatusCreated {
        t.Errorf("Expected status %d, got %d", http.StatusCreated, resp.StatusCode)
    }
    
    var createResponse models.APIResponse
    json.NewDecoder(resp.Body).Decode(&createResponse)
    
    if !createResponse.Success {
        t.Errorf("Expected success response, got error: %v", createResponse.Error)
    }
    
    // Extract created todo ID
    todoData := createResponse.Data.(map[string]interface{})
    todoID := int(todoData["id"].(float64))
    
    // 2. Get Todo
    req, _ = http.NewRequest("GET", server.URL+fmt.Sprintf("/api/v1/todos/%d", todoID), nil)
    req.Header.Set("Authorization", "Bearer "+token)
    
    resp, err = client.Do(req)
    if err != nil {
        t.Fatalf("Failed to get todo: %v", err)
    }
    defer resp.Body.Close()
    
    if resp.StatusCode != http.StatusOK {
        t.Errorf("Expected status %d, got %d", http.StatusOK, resp.StatusCode)
    }
    
    // 3. Update Todo
    updatePayload := models.UpdateTodoRequest{
        Title:     stringPtr("Updated Integration Test Todo"),
        Completed: boolPtr(true),
    }
    
    payloadBytes, _ = json.Marshal(updatePayload)
    req, _ = http.NewRequest("PUT", server.URL+fmt.Sprintf("/api/v1/todos/%d", todoID), bytes.NewBuffer(payloadBytes))
    req.Header.Set("Content-Type", "application/json")
    req.Header.Set("Authorization", "Bearer "+token)
    
    resp, err = client.Do(req)
    if err != nil {
        t.Fatalf("Failed to update todo: %v", err)
    }
    defer resp.Body.Close()
    
    if resp.StatusCode != http.StatusOK {
        t.Errorf("Expected status %d, got %d", http.StatusOK, resp.StatusCode)
    }
    
    // 4. List Todos
    req, _ = http.NewRequest("GET", server.URL+"/api/v1/todos", nil)
    req.Header.Set("Authorization", "Bearer "+token)
    
    resp, err = client.Do(req)
    if err != nil {
        t.Fatalf("Failed to list todos: %v", err)
    }
    defer resp.Body.Close()
    
    if resp.StatusCode != http.StatusOK {
        t.Errorf("Expected status %d, got %d", http.StatusOK, resp.StatusCode)
    }
    
    // 5. Delete Todo
    req, _ = http.NewRequest("DELETE", server.URL+fmt.Sprintf("/api/v1/todos/%d", todoID), nil)
    req.Header.Set("Authorization", "Bearer "+token)
    
    resp, err = client.Do(req)
    if err != nil {
        t.Fatalf("Failed to delete todo: %v", err)
    }
    defer resp.Body.Close()
    
    if resp.StatusCode != http.StatusNoContent {
        t.Errorf("Expected status %d, got %d", http.StatusNoContent, resp.StatusCode)
    }
}

// Helper functions
func stringPtr(s string) *string {
    return &s
}

func boolPtr(b bool) *bool {
    return &b
}

// 부하 테스트
func TestConcurrentRequests(t *testing.T) {
    server := setupTestServer()
    defer server.Close()
    
    token := getTestJWT()
    client := &http.Client{}
    
    // 동시에 여러 요청 보내기
    const numRequests = 50
    results := make(chan error, numRequests)
    
    for i := 0; i < numRequests; i++ {
        go func() {
            createPayload := models.CreateTodoRequest{
                Title:       fmt.Sprintf("Concurrent Todo %d", i),
                Description: "Testing concurrent creation",
                Priority:    models.PriorityMedium,
            }
            
            payloadBytes, _ := json.Marshal(createPayload)
            req, _ := http.NewRequest("POST", server.URL+"/api/v1/todos", bytes.NewBuffer(payloadBytes))
            req.Header.Set("Content-Type", "application/json")
            req.Header.Set("Authorization", "Bearer "+token)
            
            resp, err := client.Do(req)
            if err != nil {
                results <- err
                return
            }
            resp.Body.Close()
            
            if resp.StatusCode != http.StatusCreated {
                results <- fmt.Errorf("unexpected status code: %d", resp.StatusCode)
                return
            }
            
            results <- nil
        }()
    }
    
    // 결과 수집
    for i := 0; i < numRequests; i++ {
        if err := <-results; err != nil {
            t.Errorf("Request %d failed: %v", i, err)
        }
    }
}
```

### 🏃‍♂️ 테스트 실행

```bash
# 모든 테스트 실행
go test ./...

# 특정 패키지 테스트
go test ./tests

# 벤치마크 테스트
go test -bench=. ./tests

# 커버리지 확인
go test -cover ./...

# 상세한 커버리지 리포트
go test -coverprofile=coverage.out ./...
go tool cover -html=coverage.out

# 레이스 컨디션 검사
go test -race ./...
```

---

## ✅ 체크리스트

### 프로젝트 구조
- [ ] 적절한 패키지 구조 설계
- [ ] 환경 설정 관리
- [ ] 의존성 주입 패턴
- [ ] 인터페이스 기반 설계

### HTTP 서버
- [ ] REST API 엔드포인트 구현
- [ ] HTTP 상태 코드 적절히 사용
- [ ] JSON 요청/응답 처리
- [ ] Graceful shutdown 구현

### 보안 및 인증
- [ ] JWT 기반 인증
- [ ] 미들웨어 체인
- [ ] CORS 설정
- [ ] Rate limiting

### 에러 처리
- [ ] 일관된 에러 응답 형식
- [ ] 입력 검증
- [ ] 로깅 구현
- [ ] 에러 복구 메커니즘

### 테스트
- [ ] 단위 테스트 작성
- [ ] 통합 테스트 작성
- [ ] 벤치마크 테스트
- [ ] 커버리지 확인

---

> [!tip] 완성!
> 축하합니다! Go로 완전한 REST API를 구현했습니다. 이제 데이터베이스 연동, 도커화, 배포 등으로 확장해보세요!