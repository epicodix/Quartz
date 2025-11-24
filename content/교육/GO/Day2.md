# 🚀 Go 언어 Day 2: Database & Testing 마스터하기

## 📋 Today's Goal
> **"어제 만든 TODO API에 PostgreSQL을 연동하고, 프로덕션급 테스트를 작성한다!"**

## 🎯 학습 목표 (8시간)
1. PostgreSQL 연동 & 마이그레이션 (2시간)
2. Context 패턴 완벽 이해 (1시간)
3. 테스트 작성 (2시간)
4. Docker 배포 & 환경 설정 (2시간)
5. 실전 프로젝트 완성 (1시간)

---

## 📚 Part 1: Database Layer 구축 (2시간)

### 1.1 프로젝트 구조 업데이트
```bash
go-day2/
├── cmd/
│   └── server/
│       └── main.go
├── internal/
│   ├── config/
│   │   └── config.go
│   ├── database/
│   │   ├── postgres.go
│   │   └── migrations/
│   ├── handlers/
│   │   └── todo.go
│   ├── models/
│   │   └── todo.go
│   └── repository/
│       ├── interface.go
│       └── postgres/
│           └── todo.go
├── docker-compose.yml
├── Dockerfile
├── .env
└── go.mod
```

### 1.2 Configuration 설정
```go
// internal/config/config.go
package config

import (
    "fmt"
    "os"
    "strconv"
    "time"
)

type Config struct {
    Port        string
    DatabaseURL string
    DB          DBConfig
    Server      ServerConfig
}

type DBConfig struct {
    Host         string
    Port         int
    User         string
    Password     string
    Database     string
    SSLMode      string
    MaxOpenConns int
    MaxIdleConns int
    MaxLifetime  time.Duration
}

type ServerConfig struct {
    ReadTimeout  time.Duration
    WriteTimeout time.Duration
    IdleTimeout  time.Duration
}

func Load() (*Config, error) {
    cfg := &Config{
        Port: getEnv("PORT", "8080"),
        DB: DBConfig{
            Host:         getEnv("DB_HOST", "localhost"),
            Port:         getEnvAsInt("DB_PORT", 5432),
            User:         getEnv("DB_USER", "postgres"),
            Password:     getEnv("DB_PASSWORD", "postgres"),
            Database:     getEnv("DB_NAME", "todoapp"),
            SSLMode:      getEnv("DB_SSLMODE", "disable"),
            MaxOpenConns: getEnvAsInt("DB_MAX_OPEN_CONNS", 25),
            MaxIdleConns: getEnvAsInt("DB_MAX_IDLE_CONNS", 5),
            MaxLifetime:  getEnvAsDuration("DB_MAX_LIFETIME", 5*time.Minute),
        },
        Server: ServerConfig{
            ReadTimeout:  getEnvAsDuration("SERVER_READ_TIMEOUT", 15*time.Second),
            WriteTimeout: getEnvAsDuration("SERVER_WRITE_TIMEOUT", 15*time.Second),
            IdleTimeout:  getEnvAsDuration("SERVER_IDLE_TIMEOUT", 60*time.Second),
        },
    }
    
    cfg.DatabaseURL = fmt.Sprintf(
        "postgres://%s:%s@%s:%d/%s?sslmode=%s",
        cfg.DB.User, cfg.DB.Password, cfg.DB.Host, cfg.DB.Port, cfg.DB.Database, cfg.DB.SSLMode,
    )
    
    return cfg, nil
}

func getEnv(key, defaultValue string) string {
    if value := os.Getenv(key); value != "" {
        return value
    }
    return defaultValue
}

func getEnvAsInt(key string, defaultValue int) int {
    valueStr := getEnv(key, "")
    if value, err := strconv.Atoi(valueStr); err == nil {
        return value
    }
    return defaultValue
}

func getEnvAsDuration(key string, defaultValue time.Duration) time.Duration {
    valueStr := getEnv(key, "")
    if value, err := time.ParseDuration(valueStr); err == nil {
        return value
    }
    return defaultValue
}
```

### 1.3 Database Connection
```go
// internal/database/postgres.go
package database

import (
    "context"
    "database/sql"
    "fmt"
    "time"
    
    _ "github.com/lib/pq"
    "github.com/yourusername/go-day2/internal/config"
)

type DB struct {
    *sql.DB
}

func NewConnection(cfg *config.DBConfig) (*DB, error) {
    dsn := fmt.Sprintf(
        "host=%s port=%d user=%s password=%s dbname=%s sslmode=%s",
        cfg.Host, cfg.Port, cfg.User, cfg.Password, cfg.Database, cfg.SSLMode,
    )
    
    db, err := sql.Open("postgres", dsn)
    if err != nil {
        return nil, fmt.Errorf("failed to open database: %w", err)
    }
    
    // Connection pool settings
    db.SetMaxOpenConns(cfg.MaxOpenConns)
    db.SetMaxIdleConns(cfg.MaxIdleConns)
    db.SetConnMaxLifetime(cfg.MaxLifetime)
    
    ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
    defer cancel()
    
    if err := db.PingContext(ctx); err != nil {
        return nil, fmt.Errorf("failed to ping database: %w", err)
    }
    
    return &DB{db}, nil
}

func (db *DB) Migrate() error {
    query := `
    CREATE TABLE IF NOT EXISTS todos (
        id SERIAL PRIMARY KEY,
        title VARCHAR(255) NOT NULL,
        completed BOOLEAN DEFAULT FALSE,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
    );
    
    CREATE INDEX IF NOT EXISTS idx_todos_completed ON todos(completed);
    CREATE INDEX IF NOT EXISTS idx_todos_created_at ON todos(created_at DESC);
    `
    
    _, err := db.Exec(query)
    return err
}
```

### 1.4 Repository Pattern
```go
// internal/repository/interface.go
package repository

import (
    "context"
    "github.com/yourusername/go-day2/internal/models"
)

type TodoRepository interface {
    Create(ctx context.Context, todo *models.Todo) error
    GetByID(ctx context.Context, id int) (*models.Todo, error)
    GetAll(ctx context.Context, filter TodoFilter) ([]*models.Todo, error)
    Update(ctx context.Context, todo *models.Todo) error
    Delete(ctx context.Context, id int) error
}

type TodoFilter struct {
    Completed *bool
    Limit     int
    Offset    int
    OrderBy   string
    Search    string
}
```

```go
// internal/repository/postgres/todo.go
package postgres

import (
    "context"
    "database/sql"
    "fmt"
    "strings"
    
    "github.com/yourusername/go-day2/internal/models"
    "github.com/yourusername/go-day2/internal/repository"
)

type TodoRepository struct {
    db *sql.DB
}

func NewTodoRepository(db *sql.DB) repository.TodoRepository {
    return &TodoRepository{db: db}
}

func (r *TodoRepository) Create(ctx context.Context, todo *models.Todo) error {
    query := `
        INSERT INTO todos (title, completed) 
        VALUES ($1, $2) 
        RETURNING id, created_at, updated_at
    `
    
    err := r.db.QueryRowContext(
        ctx, query, todo.Title, todo.Completed,
    ).Scan(&todo.ID, &todo.CreatedAt, &todo.UpdatedAt)
    
    if err != nil {
        return fmt.Errorf("failed to create todo: %w", err)
    }
    
    return nil
}

func (r *TodoRepository) GetByID(ctx context.Context, id int) (*models.Todo, error) {
    query := `
        SELECT id, title, completed, created_at, updated_at 
        FROM todos 
        WHERE id = $1
    `
    
    todo := &models.Todo{}
    err := r.db.QueryRowContext(ctx, query, id).Scan(
        &todo.ID, &todo.Title, &todo.Completed, 
        &todo.CreatedAt, &todo.UpdatedAt,
    )
    
    if err == sql.ErrNoRows {
        return nil, models.ErrTodoNotFound
    }
    if err != nil {
        return nil, fmt.Errorf("failed to get todo: %w", err)
    }
    
    return todo, nil
}

func (r *TodoRepository) GetAll(ctx context.Context, filter repository.TodoFilter) ([]*models.Todo, error) {
    query := `SELECT id, title, completed, created_at, updated_at FROM todos WHERE 1=1`
    args := []interface{}{}
    argCount := 0
    
    // Dynamic query building
    if filter.Completed != nil {
        argCount++
        query += fmt.Sprintf(" AND completed = $%d", argCount)
        args = append(args, *filter.Completed)
    }
    
    if filter.Search != "" {
        argCount++
        query += fmt.Sprintf(" AND title ILIKE $%d", argCount)
        args = append(args, "%"+filter.Search+"%")
    }
    
    // Order by
    orderBy := "created_at DESC"
    if filter.OrderBy != "" {
        orderBy = filter.OrderBy
    }
    query += " ORDER BY " + orderBy
    
    // Pagination
    if filter.Limit > 0 {
        argCount++
        query += fmt.Sprintf(" LIMIT $%d", argCount)
        args = append(args, filter.Limit)
    }
    
    if filter.Offset > 0 {
        argCount++
        query += fmt.Sprintf(" OFFSET $%d", argCount)
        args = append(args, filter.Offset)
    }
    
    rows, err := r.db.QueryContext(ctx, query, args...)
    if err != nil {
        return nil, fmt.Errorf("failed to get todos: %w", err)
    }
    defer rows.Close()
    
    todos := []*models.Todo{}
    for rows.Next() {
        todo := &models.Todo{}
        err := rows.Scan(
            &todo.ID, &todo.Title, &todo.Completed,
            &todo.CreatedAt, &todo.UpdatedAt,
        )
        if err != nil {
            return nil, fmt.Errorf("failed to scan todo: %w", err)
        }
        todos = append(todos, todo)
    }
    
    return todos, nil
}

func (r *TodoRepository) Update(ctx context.Context, todo *models.Todo) error {
    query := `
        UPDATE todos 
        SET title = $2, completed = $3, updated_at = CURRENT_TIMESTAMP 
        WHERE id = $1
        RETURNING updated_at
    `
    
    err := r.db.QueryRowContext(
        ctx, query, todo.ID, todo.Title, todo.Completed,
    ).Scan(&todo.UpdatedAt)
    
    if err == sql.ErrNoRows {
        return models.ErrTodoNotFound
    }
    if err != nil {
        return fmt.Errorf("failed to update todo: %w", err)
    }
    
    return nil
}

func (r *TodoRepository) Delete(ctx context.Context, id int) error {
    query := `DELETE FROM todos WHERE id = $1`
    
    result, err := r.db.ExecContext(ctx, query, id)
    if err != nil {
        return fmt.Errorf("failed to delete todo: %w", err)
    }
    
    rowsAffected, err := result.RowsAffected()
    if err != nil {
        return fmt.Errorf("failed to get rows affected: %w", err)
    }
    
    if rowsAffected == 0 {
        return models.ErrTodoNotFound
    }
    
    return nil
}
```

---

## 🎯 Part 2: Context Pattern 마스터 (1시간)

### 2.1 Context를 활용한 Request ID 추적
```go
// internal/middleware/request_id.go
package middleware

import (
    "context"
    "net/http"
    
    "github.com/google/uuid"
)

type contextKey string

const RequestIDKey contextKey = "requestID"

func RequestID(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        requestID := r.Header.Get("X-Request-ID")
        if requestID == "" {
            requestID = uuid.New().String()
        }
        
        ctx := context.WithValue(r.Context(), RequestIDKey, requestID)
        w.Header().Set("X-Request-ID", requestID)
        
        next.ServeHTTP(w, r.WithContext(ctx))
    })
}

func GetRequestID(ctx context.Context) string {
    if requestID, ok := ctx.Value(RequestIDKey).(string); ok {
        return requestID
    }
    return ""
}
```

### 2.2 Context를 활용한 로깅
```go
// internal/logger/logger.go
package logger

import (
    "context"
    "log"
    
    "github.com/yourusername/go-day2/internal/middleware"
)

type Logger struct {
    *log.Logger
}

func (l *Logger) WithContext(ctx context.Context) *Logger {
    requestID := middleware.GetRequestID(ctx)
    if requestID != "" {
        return &Logger{
            Logger: log.New(l.Writer(), l.Prefix()+" ["+requestID+"] ", l.Flags()),
        }
    }
    return l
}

func (l *Logger) InfoContext(ctx context.Context, msg string) {
    l.WithContext(ctx).Println("INFO:", msg)
}

func (l *Logger) ErrorContext(ctx context.Context, msg string) {
    l.WithContext(ctx).Println("ERROR:", msg)
}
```

---

## 🧪 Part 3: Testing (2시간)

### 3.1 Unit Test
```go
// internal/repository/postgres/todo_test.go
package postgres

import (
    "context"
    "database/sql"
    "testing"
    "time"
    
    "github.com/DATA-DOG/go-sqlmock"
    "github.com/stretchr/testify/assert"
    "github.com/yourusername/go-day2/internal/models"
)

func TestTodoRepository_Create(t *testing.T) {
    db, mock, err := sqlmock.New()
    assert.NoError(t, err)
    defer db.Close()
    
    repo := NewTodoRepository(db)
    
    todo := &models.Todo{
        Title:     "Test Todo",
        Completed: false,
    }
    
    rows := sqlmock.NewRows([]string{"id", "created_at", "updated_at"}).
        AddRow(