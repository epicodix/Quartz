# 🐾 뽀시레기 Sprint 1 - 극한 디테일 기획서

> **기간**: 2026.02.24 (월) ~ 02.28 (금) [5일]
> **목표**: 인프라 기반 + 핵심 API 완성 + 첫 배포

---

## 📋 Sprint 1 Overview

```
Day 1: 설계 확정 + AWS 기반
Day 2: 네트워크 + DB 구축
Day 3: 백엔드 핵심 API
Day 4: 주문 로직 + 컨테이너화
Day 5: 배포 + HTTPS + 회고
```

---

# 📅 Day 1 (2/24 월) - 설계 확정 + AWS 기반

## 타임라인

| 시간 | 태스크 | 담당 | 산출물 |
|------|--------|------|--------|
| 09:00-10:00 | 데일리 스탠드업 + 스프린트 플래닝 | 전체 | 회의록 |
| 10:00-12:00 | ERD 설계 | 백엔드 | ERD 다이어그램 |
| 10:00-12:00 | AWS 계정 + IAM 설정 | 인프라 | IAM 정책 |
| 13:00-15:00 | API 명세 작성 | 백엔드 | OpenAPI Spec |
| 13:00-15:00 | 아키텍처 다이어그램 | 인프라 | draw.io |
| 15:00-17:00 | Git 레포 구성 + 브랜치 전략 | 전체 | GitHub Repo |
| 17:00-18:00 | Day 1 리뷰 + 블로커 공유 | 전체 | 회의록 |

---

## D1-001: AWS 계정 및 IAM 설정

### 📌 태스크 정보

| 항목 | 내용 |
|------|------|
| ID | D1-001 |
| 우선순위 | P0 (Blocker) |
| 담당 | 인프라 담당자 |
| 예상 시간 | 2시간 |
| 선행 작업 | 없음 |
| 후행 작업 | D2-001 (VPC 생성) |

### 📋 체크리스트

```
[ ] AWS 루트 계정 MFA 활성화
[ ] IAM 사용자 그룹 생성
    [ ] Admins - AdministratorAccess
    [ ] Developers - PowerUserAccess + IAMReadOnlyAccess
    [ ] ReadOnly - ReadOnlyAccess
[ ] IAM 사용자 생성 (팀원별)
    [ ] 이나형 - Admins 그룹
    [ ] 박지훈 - Developers 그룹
    [ ] 박규원 - Developers 그룹
    [ ] 서주원 - Developers 그룹
[ ] 프로그래밍 방식 액세스용 사용자 생성
    [ ] bbossiregi-terraform (Terraform용)
    [ ] bbossiregi-github-actions (CI/CD용)
[ ] 비용 알림 설정
    [ ] Budget: $50/월
    [ ] 알림: 80%, 100% 도달 시
[ ] CloudTrail 활성화
```

### 📝 상세 명세

#### IAM 정책: bbossiregi-terraform

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "TerraformFullAccess",
      "Effect": "Allow",
      "Action": [
        "ec2:*",
        "eks:*",
        "rds:*",
        "s3:*",
        "iam:*",
        "elasticloadbalancing:*",
        "acm:*",
        "route53:*",
        "lambda:*",
        "events:*",
        "logs:*",
        "ecr:*"
      ],
      "Resource": "*"
    }
  ]
}
```

#### IAM 정책: bbossiregi-github-actions

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ECRAccess",
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload"
      ],
      "Resource": "*"
    },
    {
      "Sid": "EKSAccess",
      "Effect": "Allow",
      "Action": [
        "eks:DescribeCluster",
        "eks:ListClusters"
      ],
      "Resource": "*"
    }
  ]
}
```

### ✅ 완료 기준

```
1. 모든 팀원이 AWS 콘솔 로그인 가능
2. Terraform 사용자로 aws sts get-caller-identity 성공
3. GitHub Actions 사용자 액세스 키 생성 완료
4. 비용 알림 이메일 수신 테스트 완료
```

### 🧪 검증 명령어

```bash
# Terraform 사용자 검증
export AWS_ACCESS_KEY_ID=xxx
export AWS_SECRET_ACCESS_KEY=xxx
aws sts get-caller-identity

# 예상 출력
{
    "UserId": "AIDAXXXXXXXXXX",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/bbossiregi-terraform"
}
```

---

## D1-002: ERD 설계 확정

### 📌 태스크 정보

| 항목 | 내용 |
|------|------|
| ID | D1-002 |
| 우선순위 | P0 (Blocker) |
| 담당 | 백엔드 담당자 |
| 예상 시간 | 2시간 |
| 선행 작업 | 없음 |
| 후행 작업 | D2-006 (DB 스키마 생성) |

### 📋 체크리스트

```
[ ] 테이블 설계 (6개)
    [ ] users
    [ ] products
    [ ] time_deals
    [ ] orders
    [ ] order_events
    [ ] order_items (선택)
[ ] 관계 정의
    [ ] 1:N 관계 식별
    [ ] FK 제약조건 정의
[ ] 인덱스 설계
    [ ] 조회 빈도 높은 컬럼
    [ ] FK 컬럼
[ ] ERD 다이어그램 작성
    [ ] dbdiagram.io 또는 draw.io
    [ ] 노션에 첨부
[ ] DDL 초안 작성
    [ ] migrations/001_init.sql
```

### 📝 상세 명세

#### 테이블: users

```sql
CREATE TABLE users (
    -- PK
    id SERIAL PRIMARY KEY,
    
    -- 인증 정보
    email VARCHAR(255) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    
    -- 프로필
    name VARCHAR(100) NOT NULL,
    phone VARCHAR(20),
    
    -- 권한
    role VARCHAR(20) NOT NULL DEFAULT 'user',
    -- ENUM: 'user', 'admin'
    
    -- 상태
    status VARCHAR(20) NOT NULL DEFAULT 'active',
    -- ENUM: 'active', 'inactive', 'banned'
    
    -- 타임스탬프
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_login_at TIMESTAMP,
    
    -- 제약조건
    CONSTRAINT uk_users_email UNIQUE (email),
    CONSTRAINT chk_users_role CHECK (role IN ('user', 'admin')),
    CONSTRAINT chk_users_status CHECK (status IN ('active', 'inactive', 'banned'))
);

-- 인덱스
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_status ON users(status);
```

#### 테이블: products

```sql
CREATE TABLE products (
    -- PK
    id SERIAL PRIMARY KEY,
    
    -- 상품 정보
    name VARCHAR(255) NOT NULL,
    description TEXT,
    price DECIMAL(10, 2) NOT NULL,
    
    -- 이미지
    image_url VARCHAR(500),
    thumbnail_url VARCHAR(500),
    
    -- 분류
    category VARCHAR(50) NOT NULL,
    -- ENUM: 'food', 'toy', 'health', 'fashion', 'living'
    
    -- 상태
    status VARCHAR(20) NOT NULL DEFAULT 'active',
    -- ENUM: 'active', 'inactive', 'deleted'
    
    -- 타임스탬프
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    -- 제약조건
    CONSTRAINT chk_products_price CHECK (price > 0),
    CONSTRAINT chk_products_category CHECK (category IN ('food', 'toy', 'health', 'fashion', 'living')),
    CONSTRAINT chk_products_status CHECK (status IN ('active', 'inactive', 'deleted'))
);

-- 인덱스
CREATE INDEX idx_products_category ON products(category);
CREATE INDEX idx_products_status ON products(status);
```

#### 테이블: time_deals

```sql
CREATE TABLE time_deals (
    -- PK
    id SERIAL PRIMARY KEY,
    
    -- FK
    product_id INTEGER NOT NULL,
    
    -- 가격 정보
    original_price DECIMAL(10, 2) NOT NULL,
    deal_price DECIMAL(10, 2) NOT NULL,
    discount_rate INTEGER GENERATED ALWAYS AS (
        ROUND((1 - deal_price / original_price) * 100)
    ) STORED,
    
    -- 재고 관리 (핵심!)
    stock_quantity INTEGER NOT NULL,      -- 총 재고
    reserved_quantity INTEGER NOT NULL DEFAULT 0,  -- 예약된 수량
    sold_quantity INTEGER NOT NULL DEFAULT 0,      -- 판매된 수량
    -- available = stock_quantity - reserved_quantity - sold_quantity
    
    -- 시간 정보
    start_at TIMESTAMP NOT NULL,
    end_at TIMESTAMP NOT NULL,
    
    -- 상태
    status VARCHAR(20) NOT NULL DEFAULT 'scheduled',
    -- ENUM: 'scheduled', 'active', 'ended', 'soldout', 'canceled'
    
    -- 타임스탬프
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    -- 제약조건
    CONSTRAINT fk_time_deals_product FOREIGN KEY (product_id) 
        REFERENCES products(id) ON DELETE RESTRICT,
    CONSTRAINT chk_time_deals_price CHECK (deal_price > 0 AND deal_price < original_price),
    CONSTRAINT chk_time_deals_stock CHECK (stock_quantity > 0),
    CONSTRAINT chk_time_deals_reserved CHECK (reserved_quantity >= 0),
    CONSTRAINT chk_time_deals_sold CHECK (sold_quantity >= 0),
    CONSTRAINT chk_time_deals_total CHECK (reserved_quantity + sold_quantity <= stock_quantity),
    CONSTRAINT chk_time_deals_time CHECK (end_at > start_at),
    CONSTRAINT chk_time_deals_status CHECK (status IN ('scheduled', 'active', 'ended', 'soldout', 'canceled'))
);

-- 인덱스
CREATE INDEX idx_time_deals_product_id ON time_deals(product_id);
CREATE INDEX idx_time_deals_status ON time_deals(status);
CREATE INDEX idx_time_deals_start_at ON time_deals(start_at);
CREATE INDEX idx_time_deals_end_at ON time_deals(end_at);

-- 복합 인덱스 (활성 타임딜 조회용)
CREATE INDEX idx_time_deals_active ON time_deals(status, start_at, end_at) 
    WHERE status IN ('scheduled', 'active');
```

#### 테이블: orders

```sql
CREATE TABLE orders (
    -- PK
    id SERIAL PRIMARY KEY,
    
    -- FK
    user_id INTEGER NOT NULL,
    time_deal_id INTEGER NOT NULL,
    
    -- 주문 정보
    quantity INTEGER NOT NULL DEFAULT 1,
    unit_price DECIMAL(10, 2) NOT NULL,
    total_price DECIMAL(10, 2) NOT NULL,
    
    -- 상태 (사가 패턴)
    status VARCHAR(20) NOT NULL DEFAULT 'pending',
    -- 상태 전이:
    -- pending → reserved → confirmed (정상)
    -- pending → failed (재고 부족)
    -- reserved → canceled (취소/보상)
    
    -- 타임스탬프
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    reserved_at TIMESTAMP,
    confirmed_at TIMESTAMP,
    canceled_at TIMESTAMP,
    
    -- 제약조건
    CONSTRAINT fk_orders_user FOREIGN KEY (user_id) 
        REFERENCES users(id) ON DELETE RESTRICT,
    CONSTRAINT fk_orders_time_deal FOREIGN KEY (time_deal_id) 
        REFERENCES time_deals(id) ON DELETE RESTRICT,
    CONSTRAINT chk_orders_quantity CHECK (quantity > 0),
    CONSTRAINT chk_orders_price CHECK (unit_price > 0 AND total_price > 0),
    CONSTRAINT chk_orders_total CHECK (total_price = unit_price * quantity),
    CONSTRAINT chk_orders_status CHECK (status IN ('pending', 'reserved', 'confirmed', 'canceled', 'failed'))
);

-- 인덱스
CREATE INDEX idx_orders_user_id ON orders(user_id);
CREATE INDEX idx_orders_time_deal_id ON orders(time_deal_id);
CREATE INDEX idx_orders_status ON orders(status);
CREATE INDEX idx_orders_created_at ON orders(created_at DESC);
```

#### 테이블: order_events (이벤트 소싱)

```sql
CREATE TABLE order_events (
    -- PK
    id SERIAL PRIMARY KEY,
    
    -- FK
    order_id INTEGER NOT NULL,
    
    -- 이벤트 정보
    event_type VARCHAR(50) NOT NULL,
    -- ENUM: 'CREATED', 'STOCK_RESERVED', 'STOCK_RELEASED', 
    --       'PAYMENT_REQUESTED', 'PAYMENT_COMPLETED', 'PAYMENT_FAILED',
    --       'CONFIRMED', 'CANCELED'
    
    -- 이벤트 데이터
    payload JSONB NOT NULL DEFAULT '{}',
    
    -- 메타 정보
    actor_id INTEGER,  -- 누가 발생시켰는지 (user_id 또는 system)
    actor_type VARCHAR(20) NOT NULL DEFAULT 'user',
    -- ENUM: 'user', 'system', 'admin'
    
    -- 타임스탬프
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    
    -- 제약조건
    CONSTRAINT fk_order_events_order FOREIGN KEY (order_id) 
        REFERENCES orders(id) ON DELETE CASCADE,
    CONSTRAINT chk_order_events_type CHECK (event_type IN (
        'CREATED', 'STOCK_RESERVED', 'STOCK_RELEASED',
        'PAYMENT_REQUESTED', 'PAYMENT_COMPLETED', 'PAYMENT_FAILED',
        'CONFIRMED', 'CANCELED'
    ))
);

-- 인덱스
CREATE INDEX idx_order_events_order_id ON order_events(order_id);
CREATE INDEX idx_order_events_type ON order_events(event_type);
CREATE INDEX idx_order_events_created_at ON order_events(created_at);

-- JSONB 인덱스 (선택)
CREATE INDEX idx_order_events_payload ON order_events USING GIN (payload);
```

#### ERD 다이어그램

```
┌──────────────┐       ┌──────────────┐       ┌──────────────┐
│    users     │       │   products   │       │  time_deals  │
├──────────────┤       ├──────────────┤       ├──────────────┤
│ id (PK)      │       │ id (PK)      │───┐   │ id (PK)      │
│ email (UK)   │       │ name         │   │   │ product_id(FK)│◀─┘
│ password_hash│       │ description  │   │   │ original_price│
│ name         │       │ price        │   │   │ deal_price   │
│ phone        │       │ image_url    │   │   │ stock_qty    │
│ role         │       │ category     │   │   │ reserved_qty │
│ status       │       │ status       │   │   │ sold_qty     │
│ created_at   │       │ created_at   │   │   │ start_at     │
│ updated_at   │       │ updated_at   │   │   │ end_at       │
└──────┬───────┘       └──────────────┘   │   │ status       │
       │                                   │   └──────┬───────┘
       │ 1:N                               │          │ 1:N
       │                                   │          │
       ▼                                   │          ▼
┌──────────────┐                          │   ┌──────────────┐
│    orders    │◀─────────────────────────┘   │ order_events │
├──────────────┤                              ├──────────────┤
│ id (PK)      │───────────────────────────▶  │ id (PK)      │
│ user_id (FK) │                              │ order_id(FK) │
│ time_deal_id │                              │ event_type   │
│ quantity     │                              │ payload      │
│ unit_price   │                              │ actor_id     │
│ total_price  │                              │ actor_type   │
│ status       │                              │ created_at   │
│ created_at   │                              └──────────────┘
│ updated_at   │
└──────────────┘
```

### ✅ 완료 기준

```
1. ERD 다이어그램 노션에 첨부
2. 모든 테이블 DDL 파일 작성 완료
3. 팀 리뷰 완료 (ERD 확정)
4. 제약조건 및 인덱스 정의 완료
```

---

## D1-003: 시스템 아키텍처 다이어그램

### 📌 태스크 정보

| 항목 | 내용 |
|------|------|
| ID | D1-003 |
| 우선순위 | P0 |
| 담당 | 인프라 담당자 |
| 예상 시간 | 2시간 |

### 📋 체크리스트

```
[ ] 전체 아키텍처 다이어그램
[ ] 네트워크 구성도
[ ] 데이터 흐름도
[ ] 배포 구성도
```

### 📝 상세 명세

#### 전체 아키텍처

```
┌─────────────────────────────────────────────────────────────────────────┐
│                              AWS Cloud                                   │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │                        VPC (10.0.0.0/16)                          │  │
│  │                                                                    │  │
│  │  ┌─────────────────────────────────────────────────────────────┐  │  │
│  │  │              Public Subnets (10.0.1.0/24, 10.0.2.0/24)      │  │  │
│  │  │                                                              │  │  │
│  │  │  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐  │  │  │
│  │  │  │     IGW      │    │     NAT      │    │     ALB      │  │  │  │
│  │  │  │   Gateway    │    │   Gateway    │    │              │  │  │  │
│  │  │  └──────────────┘    └──────────────┘    └──────┬───────┘  │  │  │
│  │  │                                                  │          │  │  │
│  │  └──────────────────────────────────────────────────┼──────────┘  │  │
│  │                                                      │             │  │
│  │  ┌───────────────────────────────────────────────────┼───────────┐│  │
│  │  │         Private Subnets (10.0.11.0/24, 10.0.12.0/24)         ││  │
│  │  │                                                    │          ││  │
│  │  │  ┌─────────────────────────────────────────────────▼────────┐ ││  │
│  │  │  │                    EKS Cluster                           │ ││  │
│  │  │  │                                                          │ ││  │
│  │  │  │  ┌──────────┐  ┌──────────┐  ┌──────────┐               │ ││  │
│  │  │  │  │  Node 1  │  │  Node 2  │  │  Node 3  │  (Auto Scale) │ ││  │
│  │  │  │  │          │  │          │  │          │               │ ││  │
│  │  │  │  │┌────────┐│  │┌────────┐│  │┌────────┐│               │ ││  │
│  │  │  │  ││Backend ││  ││Backend ││  ││Backend ││               │ ││  │
│  │  │  │  ││ Pod    ││  ││ Pod    ││  ││ Pod    ││               │ ││  │
│  │  │  │  │└────────┘│  │└────────┘│  │└────────┘│               │ ││  │
│  │  │  │  └──────────┘  └──────────┘  └──────────┘               │ ││  │
│  │  │  │                                                          │ ││  │
│  │  │  └──────────────────────────────┬───────────────────────────┘ ││  │
│  │  │                                  │                             ││  │
│  │  │  ┌───────────────────────────────▼───────────────────────────┐││  │
│  │  │  │                        RDS                                │││  │
│  │  │  │              PostgreSQL (db.t3.micro)                     │││  │
│  │  │  │                    Primary                                │││  │
│  │  │  └───────────────────────────────────────────────────────────┘││  │
│  │  │                                                                ││  │
│  │  └────────────────────────────────────────────────────────────────┘│  │
│  │                                                                    │  │
│  └────────────────────────────────────────────────────────────────────┘  │
│                                                                          │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │                      Supporting Services                          │   │
│  │                                                                   │   │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐         │   │
│  │  │   ECR    │  │  Lambda  │  │CloudWatch│  │  Route53 │         │   │
│  │  │ Registry │  │Scheduler │  │   Logs   │  │   DNS    │         │   │
│  │  └──────────┘  └──────────┘  └──────────┘  └──────────┘         │   │
│  │                                                                   │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘
```

#### 리소스 명세

| 리소스 | 스펙 | 수량 | 예상 비용 (월) |
|--------|------|------|----------------|
| EKS Cluster | - | 1 | $72 |
| EKS Node | t3.medium | 2-4 | $60-120 |
| RDS | db.t3.micro | 1 | $15 |
| ALB | - | 1 | $20 |
| NAT Gateway | - | 1 | $32 |
| ECR | - | 1 | $1 |
| Route53 | - | 1 | $0.5 |
| **합계** | | | **~$200-260** |

---

## D1-004: API 명세 작성

### 📌 태스크 정보

| 항목 | 내용 |
|------|------|
| ID | D1-004 |
| 우선순위 | P0 |
| 담당 | 백엔드 담당자 |
| 예상 시간 | 2시간 |

### 📋 체크리스트

```
[ ] OpenAPI 3.0 스펙 파일 작성
[ ] 인증 API (2개)
[ ] 상품 API (3개)
[ ] 타임딜 API (3개)
[ ] 주문 API (4개)
[ ] 헬스체크 API (1개)
[ ] 에러 응답 형식 정의
```

### 📝 상세 명세

#### Base URL & 공통

```yaml
# openapi.yaml
openapi: 3.0.3
info:
  title: 뽀시레기 API
  version: 1.0.0
  description: 반려동물 타임딜 이커머스 API

servers:
  - url: https://api.bbossiregi.com/api/v1
    description: Production
  - url: http://localhost:8080/api/v1
    description: Local

security:
  - BearerAuth: []

components:
  securitySchemes:
    BearerAuth:
      type: http
      scheme: bearer
      bearerFormat: JWT
```

#### 공통 에러 응답

```yaml
components:
  schemas:
    Error:
      type: object
      required:
        - code
        - message
      properties:
        code:
          type: string
          example: "INVALID_REQUEST"
        message:
          type: string
          example: "잘못된 요청입니다"
        details:
          type: object
          additionalProperties: true

    ValidationError:
      type: object
      properties:
        code:
          type: string
          example: "VALIDATION_ERROR"
        message:
          type: string
          example: "유효성 검사 실패"
        errors:
          type: array
          items:
            type: object
            properties:
              field:
                type: string
              message:
                type: string
```

#### API 1: POST /auth/register

```yaml
paths:
  /auth/register:
    post:
      tags: [Auth]
      summary: 회원가입
      security: []  # 인증 불필요
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              required:
                - email
                - password
                - name
              properties:
                email:
                  type: string
                  format: email
                  maxLength: 255
                  example: "user@example.com"
                password:
                  type: string
                  format: password
                  minLength: 8
                  maxLength: 100
                  example: "password123!"
                name:
                  type: string
                  minLength: 2
                  maxLength: 100
                  example: "홍길동"
                phone:
                  type: string
                  pattern: "^01[0-9]-?[0-9]{3,4}-?[0-9]{4}$"
                  example: "010-1234-5678"
      responses:
        '201':
          description: 회원가입 성공
          content:
            application/json:
              schema:
                type: object
                properties:
                  id:
                    type: integer
                  email:
                    type: string
                  name:
                    type: string
                  created_at:
                    type: string
                    format: date-time
        '400':
          description: 유효성 검사 실패
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/ValidationError'
              examples:
                invalid_email:
                  value:
                    code: "VALIDATION_ERROR"
                    message: "유효성 검사 실패"
                    errors:
                      - field: "email"
                        message: "올바른 이메일 형식이 아닙니다"
        '409':
          description: 이메일 중복
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Error'
              example:
                code: "DUPLICATE_EMAIL"
                message: "이미 사용 중인 이메일입니다"
```

#### API 2: POST /auth/login

```yaml
  /auth/login:
    post:
      tags: [Auth]
      summary: 로그인
      security: []
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              required:
                - email
                - password
              properties:
                email:
                  type: string
                  format: email
                password:
                  type: string
      responses:
        '200':
          description: 로그인 성공
          content:
            application/json:
              schema:
                type: object
                properties:
                  access_token:
                    type: string
                    example: "eyJhbGciOiJIUzI1NiIs..."
                  token_type:
                    type: string
                    example: "Bearer"
                  expires_in:
                    type: integer
                    example: 3600
                  user:
                    type: object
                    properties:
                      id:
                        type: integer
                      email:
                        type: string
                      name:
                        type: string
                      role:
                        type: string
        '401':
          description: 인증 실패
          content:
            application/json:
              example:
                code: "INVALID_CREDENTIALS"
                message: "이메일 또는 비밀번호가 올바르지 않습니다"
```

#### API 3: GET /timedeals

```yaml
  /timedeals:
    get:
      tags: [TimeDeal]
      summary: 타임딜 목록 조회
      security: []
      parameters:
        - name: status
          in: query
          schema:
            type: string
            enum: [scheduled, active, ended, soldout]
          description: 상태 필터
        - name: page
          in: query
          schema:
            type: integer
            default: 1
            minimum: 1
        - name: per_page
          in: query
          schema:
            type: integer
            default: 20
            minimum: 1
            maximum: 100
      responses:
        '200':
          description: 성공
          content:
            application/json:
              schema:
                type: object
                properties:
                  data:
                    type: array
                    items:
                      $ref: '#/components/schemas/TimeDealSummary'
                  meta:
                    $ref: '#/components/schemas/Pagination'
              example:
                data:
                  - id: 1
                    product:
                      id: 1
                      name: "프리미엄 사료 3kg"
                      image_url: "https://..."
                      category: "food"
                    original_price: 45000
                    deal_price: 29900
                    discount_rate: 33
                    stock_quantity: 100
                    available_quantity: 87
                    start_at: "2026-02-27T14:00:00Z"
                    end_at: "2026-02-27T15:00:00Z"
                    status: "scheduled"
                    remaining_seconds: 3600
                meta:
                  total: 50
                  page: 1
                  per_page: 20
                  total_pages: 3
```

#### API 4: GET /timedeals/{id}

```yaml
  /timedeals/{id}:
    get:
      tags: [TimeDeal]
      summary: 타임딜 상세 조회
      security: []
      parameters:
        - name: id
          in: path
          required: true
          schema:
            type: integer
      responses:
        '200':
          description: 성공
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/TimeDealDetail'
              example:
                id: 1
                product:
                  id: 1
                  name: "프리미엄 사료 3kg"
                  description: "최고급 원료로 만든 프리미엄 사료"
                  image_url: "https://..."
                  category: "food"
                original_price: 45000
                deal_price: 29900
                discount_rate: 33
                stock_quantity: 100
                reserved_quantity: 10
                sold_quantity: 3
                available_quantity: 87
                start_at: "2026-02-27T14:00:00Z"
                end_at: "2026-02-27T15:00:00Z"
                status: "active"
                remaining_seconds: 1823
        '404':
          description: 타임딜 없음
          content:
            application/json:
              example:
                code: "NOT_FOUND"
                message: "타임딜을 찾을 수 없습니다"
```

#### API 5: POST /orders (핵심 - 사가 패턴)

```yaml
  /orders:
    post:
      tags: [Order]
      summary: 주문 생성 (재고 예약)
      description: |
        사가 패턴 Step 1-2 수행:
        1. 주문 생성 (status: pending)
        2. 재고 예약 (reserved_quantity += quantity)
        3. 주문 상태 변경 (status: reserved)
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              required:
                - time_deal_id
              properties:
                time_deal_id:
                  type: integer
                  example: 1
                quantity:
                  type: integer
                  minimum: 1
                  maximum: 10
                  default: 1
                  example: 2
      responses:
        '201':
          description: 주문 생성 및 재고 예약 성공
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Order'
              example:
                id: 123
                user_id: 1
                time_deal_id: 1
                quantity: 2
                unit_price: 29900
                total_price: 59800
                status: "reserved"
                created_at: "2026-02-27T14:05:00Z"
                reserved_at: "2026-02-27T14:05:00Z"
        '400':
          description: 잘못된 요청
          content:
            application/json:
              examples:
                deal_not_active:
                  value:
                    code: "DEAL_NOT_ACTIVE"
                    message: "타임딜이 진행 중이 아닙니다"
                invalid_quantity:
                  value:
                    code: "INVALID_QUANTITY"
                    message: "수량은 1~10 사이여야 합니다"
        '409':
          description: 재고 부족
          content:
            application/json:
              example:
                code: "INSUFFICIENT_STOCK"
                message: "재고가 부족합니다"
                details:
                  available: 1
                  requested: 2
        '401':
          description: 인증 필요
```

#### API 6: DELETE /orders/{id} (취소 - 보상 트랜잭션)

```yaml
  /orders/{id}:
    delete:
      tags: [Order]
      summary: 주문 취소 (보상 트랜잭션)
      description: |
        사가 패턴 보상 트랜잭션:
        1. reserved_quantity -= quantity
        2. order status → canceled
      parameters:
        - name: id
          in: path
          required: true
          schema:
            type: integer
      responses:
        '200':
          description: 주문 취소 성공
          content:
            application/json:
              example:
                id: 123
                status: "canceled"
                canceled_at: "2026-02-27T14:10:00Z"
        '400':
          description: 취소 불가
          content:
            application/json:
              examples:
                already_confirmed:
                  value:
                    code: "CANNOT_CANCEL"
                    message: "이미 확정된 주문은 취소할 수 없습니다"
                already_canceled:
                  value:
                    code: "ALREADY_CANCELED"
                    message: "이미 취소된 주문입니다"
        '404':
          description: 주문 없음
```

#### API 7: GET /health

```yaml
  /health:
    get:
      tags: [System]
      summary: 헬스체크
      security: []
      responses:
        '200':
          description: 정상
          content:
            application/json:
              example:
                status: "healthy"
                timestamp: "2026-02-27T14:00:00Z"
                version: "1.0.0"
                checks:
                  database: "ok"
                  redis: "ok"
```

---

## D1-005: Git 레포지토리 구성

### 📌 태스크 정보

| 항목 | 내용 |
|------|------|
| ID | D1-005 |
| 우선순위 | P0 |
| 담당 | 전체 (팀장 주도) |
| 예상 시간 | 1시간 |

### 📋 체크리스트

```
[ ] GitHub Organization 생성 (선택)
[ ] 레포지토리 생성
[ ] 브랜치 보호 규칙 설정
[ ] 디렉토리 구조 생성
[ ] .gitignore 작성
[ ] README.md 초안 작성
[ ] PR 템플릿 작성
[ ] Issue 템플릿 작성
```

### 📝 상세 명세

#### 디렉토리 구조

```
bbossiregi/
├── .github/
│   ├── workflows/
│   │   ├── ci.yml
│   │   └── cd.yml
│   ├── PULL_REQUEST_TEMPLATE.md
│   └── ISSUE_TEMPLATE/
│       ├── bug_report.md
│       └── feature_request.md
│
├── backend/
│   ├── cmd/
│   │   └── main.go
│   ├── internal/
│   │   ├── config/
│   │   │   └── config.go
│   │   ├── handler/
│   │   │   ├── auth.go
│   │   │   ├── product.go
│   │   │   ├── timedeal.go
│   │   │   └── order.go
│   │   ├── service/
│   │   │   ├── auth.go
│   │   │   ├── stock.go
│   │   │   └── order.go
│   │   ├── repository/
│   │   │   ├── user.go
│   │   │   ├── product.go
│   │   │   ├── timedeal.go
│   │   │   └── order.go
│   │   ├── model/
│   │   │   └── models.go
│   │   └── middleware/
│   │       ├── auth.go
│   │       └── logger.go
│   ├── pkg/
│   │   └── response/
│   │       └── response.go
│   ├── migrations/
│   │   └── 001_init.sql
│   ├── Dockerfile
│   ├── go.mod
│   └── go.sum
│
├── frontend/
│   ├── src/
│   │   ├── components/
│   │   ├── pages/
│   │   ├── hooks/
│   │   ├── api/
│   │   ├── store/
│   │   ├── App.jsx
│   │   └── main.jsx
│   ├── public/
│   ├── Dockerfile
│   ├── package.json
│   └── vite.config.js
│
├── terraform/
│   ├── modules/
│   │   ├── vpc/
│   │   ├── eks/
│   │   ├── rds/
│   │   └── ecr/
│   ├── environments/
│   │   ├── dev/
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   └── terraform.tfvars
│   │   └── prod/
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
│
├── k8s/
│   ├── base/
│   │   ├── namespace.yaml
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   └── configmap.yaml
│   ├── overlays/
│   │   ├── dev/
│   │   └── prod/
│   └── kustomization.yaml
│
├── lambda/
│   ├── scheduler/
│   │   ├── main.py
│   │   └── requirements.txt
│   └── notifier/
│
├── docs/
│   ├── adr/
│   │   └── 001-database-choice.md
│   ├── api/
│   │   └── openapi.yaml
│   └── architecture/
│       └── system-architecture.png
│
├── scripts/
│   ├── setup-local.sh
│   └── deploy.sh
│
├── .gitignore
├── .env.example
├── docker-compose.yml
├── Makefile
└── README.md
```

#### .gitignore

```gitignore
# Dependencies
node_modules/
vendor/

# Build outputs
dist/
build/
bin/

# IDE
.idea/
.vscode/
*.swp
*.swo

# Environment
.env
.env.local
*.tfvars
!*.tfvars.example

# Terraform
.terraform/
*.tfstate
*.tfstate.*
crash.log

# OS
.DS_Store
Thumbs.db

# Logs
*.log
logs/

# Test coverage
coverage/
*.out

# Compiled
*.exe
*.dll
*.so
*.dylib
```

#### PR 템플릿

```markdown
<!-- .github/PULL_REQUEST_TEMPLATE.md -->

## 📝 변경 사항
<!-- 변경 내용을 간략히 설명해주세요 -->

## 🔗 관련 이슈
<!-- Closes #123 -->

## ✅ 체크리스트
- [ ] 코드 컨벤션 준수
- [ ] 테스트 작성/통과
- [ ] 문서 업데이트 (필요시)
- [ ] 로컬 테스트 완료

## 📸 스크린샷 (선택)
<!-- UI 변경이 있다면 스크린샷 첨부 -->

## 🧪 테스트 방법
<!-- 리뷰어가 테스트할 수 있는 방법 -->
```

#### 브랜치 보호 규칙

```yaml
# main 브랜치
- Require pull request before merging: ✅
  - Required approving reviews: 1
  - Dismiss stale reviews: ✅
- Require status checks: ✅
  - Required checks: ci
- Require conversation resolution: ✅
- Do not allow bypassing: ✅
```

### ✅ 완료 기준

```
1. GitHub 레포지토리 생성 및 팀원 초대 완료
2. main 브랜치 보호 규칙 적용
3. 디렉토리 구조 생성 완료
4. README.md 초안 작성 완료
5. 모든 팀원 clone 및 push 테스트 완료
```

---

# 📅 Day 2 (2/25 화) - 네트워크 + DB 구축

## 타임라인

| 시간 | 태스크 | 담당 | 산출물 |
|------|--------|------|--------|
| 09:00-09:30 | 데일리 스탠드업 | 전체 | - |
| 09:30-12:00 | VPC + 서브넷 + NAT/IGW | 인프라 | Terraform 코드 |
| 09:30-12:00 | Go 프로젝트 초기화 | 백엔드 | main.go |
| 13:00-15:00 | 보안 그룹 설정 | 인프라 | Terraform 코드 |
| 13:00-15:00 | DB 연결 모듈 | 백엔드 | db/postgres.go |
| 15:00-17:00 | RDS 구축 | 인프라 | Terraform 코드 |
| 15:00-17:00 | DDL 실행 + 테스트 데이터 | 백엔드 | SQL 파일 |
| 17:00-18:00 | Day 2 리뷰 + 연결 테스트 | 전체 | - |

---

## D2-001: VPC 생성

### 📌 태스크 정보

| 항목 | 내용 |
|------|------|
| ID | D2-001 |
| 우선순위 | P0 |
| 담당 | 인프라 |
| 예상 시간 | 1시간 |
| 선행 작업 | D1-001 (IAM) |

### 📋 체크리스트

```
[ ] VPC 생성 (10.0.0.0/16)
[ ] DNS 호스트이름 활성화
[ ] DNS 해석 활성화
[ ] 태그 설정
```

### 📝 Terraform 코드

```hcl
# terraform/modules/vpc/main.tf

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${var.project_name}-vpc"
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name        = "${var.project_name}-igw"
    Project     = var.project_name
    Environment = var.environment
  }
}
```

```hcl
# terraform/modules/vpc/variables.tf

variable "project_name" {
  type        = string
  description = "프로젝트 이름"
}

variable "environment" {
  type        = string
  description = "환경 (dev, staging, prod)"
}

variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR 블록"
  default     = "10.0.0.0/16"
}

variable "azs" {
  type        = list(string)
  description = "가용 영역"
  default     = ["ap-northeast-2a", "ap-northeast-2c"]
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "퍼블릭 서브넷 CIDR"
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "프라이빗 서브넷 CIDR"
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}
```

### 🧪 검증

```bash
# Terraform 실행
cd terraform/environments/dev
terraform init
terraform plan
terraform apply

# 검증
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=bbossiregi-vpc"
```

---

## D2-002: 서브넷 구성

### 📋 체크리스트

```
[ ] Public 서브넷 2개 생성 (Multi-AZ)
[ ] Private 서브넷 2개 생성 (Multi-AZ)
[ ] 서브넷 태그 설정 (EKS용 필수!)
```

### 📝 Terraform 코드

```hcl
# terraform/modules/vpc/subnets.tf

# Public Subnets
resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name                                           = "${var.project_name}-public-${var.azs[count.index]}"
    Project                                        = var.project_name
    Environment                                    = var.environment
    "kubernetes.io/role/elb"                       = "1"  # EKS ALB용
    "kubernetes.io/cluster/${var.project_name}-eks" = "shared"
  }
}

# Private Subnets
resource "aws_subnet" "private" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.azs[count.index]

  tags = {
    Name                                           = "${var.project_name}-private-${var.azs[count.index]}"
    Project                                        = var.project_name
    Environment                                    = var.environment
    "kubernetes.io/role/internal-elb"              = "1"  # EKS Internal LB용
    "kubernetes.io/cluster/${var.project_name}-eks" = "shared"
  }
}
```

---

## D2-003: NAT Gateway

### 📝 Terraform 코드

```hcl
# terraform/modules/vpc/nat.tf

# Elastic IP for NAT
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name        = "${var.project_name}-nat-eip"
    Project     = var.project_name
    Environment = var.environment
  }

  depends_on = [aws_internet_gateway.main]
}

# NAT Gateway (단일 - 비용 절감)
resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id  # 첫 번째 퍼블릭 서브넷에 배치

  tags = {
    Name        = "${var.project_name}-nat"
    Project     = var.project_name
    Environment = var.environment
  }

  depends_on = [aws_internet_gateway.main]
}
```

---

## D2-004: 라우팅 테이블

### 📝 Terraform 코드

```hcl
# terraform/modules/vpc/routes.tf

# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name        = "${var.project_name}-public-rt"
    Project     = var.project_name
    Environment = var.environment
  }
}

# Public Subnet Association
resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Private Route Table
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name        = "${var.project_name}-private-rt"
    Project     = var.project_name
    Environment = var.environment
  }
}

# Private Subnet Association
resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}
```

---

## D2-005: 보안 그룹

### 📝 Terraform 코드

```hcl
# terraform/modules/vpc/security_groups.tf

# ALB Security Group
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "Security group for ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-alb-sg"
    Project     = var.project_name
    Environment = var.environment
  }
}

# EKS Node Security Group
resource "aws_security_group" "eks_nodes" {
  name        = "${var.project_name}-eks-nodes-sg"
  description = "Security group for EKS worker nodes"
  vpc_id      = aws_vpc.main.id

  # ALB에서 오는 트래픽 허용
  ingress {
    description     = "From ALB"
    from_port       = 0
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # 노드 간 통신
  ingress {
    description = "Node to node"
    from_port   = 0
    to_port     = 65535
    protocol    = "-1"
    self        = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project_name}-eks-nodes-sg"
    Project     = var.project_name
    Environment = var.environment
  }
}

# RDS Security Group
resource "aws_security_group" "rds" {
  name        = "${var.project_name}-rds-sg"
  description = "Security group for RDS"
  vpc_id      = aws_vpc.main.id

  # EKS에서 오는 트래픽만 허용
  ingress {
    description     = "PostgreSQL from EKS"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_nodes.id]
  }

  # Bastion에서 오는 트래픽 (디버깅용)
  ingress {
    description = "PostgreSQL from Bastion"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.0.1.0/24"]  # Public 서브넷
  }

  tags = {
    Name        = "${var.project_name}-rds-sg"
    Project     = var.project_name
    Environment = var.environment
  }
}
```

---

## D2-006: RDS PostgreSQL 구축

### 📋 체크리스트

```
[ ] DB 서브넷 그룹 생성
[ ] 파라미터 그룹 생성 (선택)
[ ] RDS 인스턴스 생성
[ ] 시크릿 매니저에 자격증명 저장
[ ] 연결 테스트
```

### 📝 Terraform 코드

```hcl
# terraform/modules/rds/main.tf

# DB Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-db-subnet"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name        = "${var.project_name}-db-subnet"
    Project     = var.project_name
    Environment = var.environment
  }
}

# RDS Instance
resource "aws_db_instance" "main" {
  identifier = "${var.project_name}-db"

  # 엔진
  engine               = "postgres"
  engine_version       = "15.4"
  instance_class       = var.instance_class
  
  # 스토리지
  allocated_storage     = 20
  max_allocated_storage = 100  # Auto scaling
  storage_type          = "gp3"
  storage_encrypted     = true

  # 데이터베이스
  db_name  = var.db_name
  username = var.db_username
  password = var.db_password
  port     = 5432

  # 네트워크
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.security_group_id]
  publicly_accessible    = false

  # 백업
  backup_retention_period = 7
  backup_window          = "03:00-04:00"
  maintenance_window     = "Mon:04:00-Mon:05:00"

  # 성능
  performance_insights_enabled = false  # 비용 절감

  # 옵션
  skip_final_snapshot = var.environment != "prod"
  deletion_protection = var.environment == "prod"

  tags = {
    Name        = "${var.project_name}-db"
    Project     = var.project_name
    Environment = var.environment
  }
}

# Outputs
output "endpoint" {
  value = aws_db_instance.main.endpoint
}

output "address" {
  value = aws_db_instance.main.address
}
```

```hcl
# terraform/modules/rds/variables.tf

variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "security_group_id" {
  type = string
}

variable "instance_class" {
  type    = string
  default = "db.t3.micro"
}

variable "db_name" {
  type    = string
  default = "bbossiregi"
}

variable "db_username" {
  type    = string
  default = "bbossiregi"
}

variable "db_password" {
  type      = string
  sensitive = true
}
```

---

## D2-007: DB 스키마 생성

### 📋 체크리스트

```
[ ] DDL 실행
[ ] 테스트 데이터 삽입
[ ] 연결 테스트
```

### 📝 테스트 데이터

```sql
-- migrations/002_seed.sql

-- 테스트 유저
INSERT INTO users (email, password_hash, name, role) VALUES
('admin@bbossiregi.com', '$2a$10$xxxxx', '관리자', 'admin'),
('user1@test.com', '$2a$10$xxxxx', '테스트유저1', 'user'),
('user2@test.com', '$2a$10$xxxxx', '테스트유저2', 'user');

-- 테스트 상품
INSERT INTO products (name, description, price, image_url, category) VALUES
('프리미엄 강아지 사료 3kg', '최고급 원료로 만든 프리미엄 사료입니다.', 45000, 'https://via.placeholder.com/300', 'food'),
('고양이 캣타워 대형', '튼튼한 구조의 대형 캣타워입니다.', 89000, 'https://via.placeholder.com/300', 'living'),
('강아지 장난감 세트', '다양한 장난감이 포함된 세트입니다.', 25000, 'https://via.placeholder.com/300', 'toy'),
('반려동물 영양제', '면역력 강화에 도움이 되는 영양제입니다.', 35000, 'https://via.placeholder.com/300', 'health'),
('강아지 패딩 조끼', '따뜻한 겨울용 패딩 조끼입니다.', 55000, 'https://via.placeholder.com/300', 'fashion');

-- 테스트 타임딜 (오늘 + 내일)
INSERT INTO time_deals (product_id, original_price, deal_price, stock_quantity, start_at, end_at, status) VALUES
-- 진행 중
(1, 45000, 29900, 100, NOW() - INTERVAL '30 minutes', NOW() + INTERVAL '30 minutes', 'active'),
-- 예정
(2, 89000, 59900, 50, NOW() + INTERVAL '1 hour', NOW() + INTERVAL '2 hours', 'scheduled'),
(3, 25000, 15900, 200, NOW() + INTERVAL '3 hours', NOW() + INTERVAL '4 hours', 'scheduled'),
-- 내일
(4, 35000, 24900, 150, NOW() + INTERVAL '1 day', NOW() + INTERVAL '1 day' + INTERVAL '1 hour', 'scheduled'),
(5, 55000, 35900, 80, NOW() + INTERVAL '1 day' + INTERVAL '2 hours', NOW() + INTERVAL '1 day' + INTERVAL '3 hours', 'scheduled');
```

### 🧪 검증

```bash
# RDS 연결 테스트 (Bastion 또는 Port Forwarding)
psql -h <rds-endpoint> -U bbossiregi -d bbossiregi

# 테이블 확인
\dt

# 데이터 확인
SELECT * FROM users;
SELECT * FROM products;
SELECT * FROM time_deals;
```

# 📅 Day 3 (2/26 수) - 백엔드 핵심 API 개발

## 타임라인

| 시간 | 태스크 | 담당 | 산출물 |
|------|--------|------|--------|
| 09:00-09:30 | 데일리 스탠드업 | 전체 | 회의록 |
| 09:30-10:30 | Go 프로젝트 구조 세팅 | 백엔드 | 디렉토리 구조 |
| 10:30-12:00 | DB 연결 + 설정 모듈 | 백엔드 | config/, db/ |
| 13:00-14:30 | 인증 API (회원가입/로그인) | 백엔드 | handler/auth.go |
| 14:30-16:00 | 상품/타임딜 조회 API | 백엔드 | handler/product.go, timedeal.go |
| 16:00-17:30 | 타임딜 스케줄러 로직 | 백엔드 | service/scheduler.go |
| 17:30-18:00 | Day 3 리뷰 + API 테스트 | 전체 | Postman Collection |

---

## D3-001: Go 프로젝트 초기화

### 📌 태스크 정보

| 항목 | 내용 |
|------|------|
| ID | D3-001 |
| 우선순위 | P0 (Blocker) |
| 담당 | 백엔드 |
| 예상 시간 | 1시간 |
| 선행 작업 | D2-006 (RDS 구축) |
| 후행 작업 | D3-002 (DB 연결) |

### 📋 체크리스트

```
[ ] go mod init
[ ] 디렉토리 구조 생성
[ ] 의존성 설치
    [ ] gin-gonic/gin (웹 프레임워크)
    [ ] lib/pq (PostgreSQL 드라이버)
    [ ] golang-jwt/jwt (JWT)
    [ ] joho/godotenv (환경변수)
    [ ] go-playground/validator (유효성 검사)
    [ ] golang.org/x/crypto (bcrypt)
[ ] main.go 기본 구조
[ ] Makefile 작성
[ ] .env.example 작성
```

### 📝 상세 명세

#### go.mod

```go
// backend/go.mod
module github.com/bbossiregi/backend

go 1.22

require (
    github.com/gin-gonic/gin v1.9.1
    github.com/lib/pq v1.10.9
    github.com/golang-jwt/jwt/v5 v5.2.0
    github.com/joho/godotenv v1.5.1
    github.com/go-playground/validator/v10 v10.17.0
    golang.org/x/crypto v0.18.0
)
```

#### 디렉토리 구조 (최종)

```
backend/
├── cmd/
│   └── api/
│       └── main.go              # 엔트리포인트
│
├── internal/
│   ├── config/
│   │   └── config.go            # 환경 설정
│   │
│   ├── database/
│   │   └── postgres.go          # DB 연결
│   │
│   ├── model/
│   │   ├── user.go              # User 모델
│   │   ├── product.go           # Product 모델
│   │   ├── timedeal.go          # TimeDeal 모델
│   │   ├── order.go             # Order 모델
│   │   └── response.go          # 공통 응답 구조체
│   │
│   ├── repository/
│   │   ├── user_repo.go         # User DB 작업
│   │   ├── product_repo.go      # Product DB 작업
│   │   ├── timedeal_repo.go     # TimeDeal DB 작업
│   │   └── order_repo.go        # Order DB 작업
│   │
│   ├── service/
│   │   ├── auth_service.go      # 인증 비즈니스 로직
│   │   ├── stock_service.go     # 재고 관리 (사가 패턴)
│   │   ├── order_service.go     # 주문 비즈니스 로직
│   │   └── scheduler_service.go # 타임딜 스케줄러
│   │
│   ├── handler/
│   │   ├── auth_handler.go      # 인증 API 핸들러
│   │   ├── product_handler.go   # 상품 API 핸들러
│   │   ├── timedeal_handler.go  # 타임딜 API 핸들러
│   │   ├── order_handler.go     # 주문 API 핸들러
│   │   └── health_handler.go    # 헬스체크 핸들러
│   │
│   ├── middleware/
│   │   ├── auth.go              # JWT 인증 미들웨어
│   │   ├── logger.go            # 로깅 미들웨어
│   │   ├── cors.go              # CORS 미들웨어
│   │   └── recovery.go          # 패닉 복구
│   │
│   └── router/
│       └── router.go            # 라우터 설정
│
├── pkg/
│   ├── response/
│   │   └── response.go          # 응답 헬퍼
│   ├── validator/
│   │   └── validator.go         # 커스텀 유효성 검사
│   └── utils/
│       ├── hash.go              # 비밀번호 해싱
│       └── jwt.go               # JWT 유틸
│
├── migrations/
│   ├── 001_init.sql
│   └── 002_seed.sql
│
├── .env.example
├── Dockerfile
├── Makefile
└── go.mod
```

#### main.go

```go
// backend/cmd/api/main.go
package main

import (
    "log"
    "os"

    "github.com/bbossiregi/backend/internal/config"
    "github.com/bbossiregi/backend/internal/database"
    "github.com/bbossiregi/backend/internal/router"
    "github.com/bbossiregi/backend/internal/service"
    "github.com/joho/godotenv"
)

func main() {
    // 환경변수 로드
    if err := godotenv.Load(); err != nil {
        log.Println("No .env file found, using environment variables")
    }

    // 설정 로드
    cfg := config.Load()

    // DB 연결
    db, err := database.NewPostgresDB(cfg.Database)
    if err != nil {
        log.Fatalf("Failed to connect to database: %v", err)
    }
    defer db.Close()

    log.Println("✅ Database connected successfully")

    // 스케줄러 시작
    scheduler := service.NewSchedulerService(db)
    go scheduler.Start()

    log.Println("✅ Scheduler started")

    // 라우터 설정
    r := router.Setup(db, cfg)

    // 서버 시작
    port := cfg.Server.Port
    if port == "" {
        port = "8080"
    }

    log.Printf("🚀 Server starting on port %s", port)
    if err := r.Run(":" + port); err != nil {
        log.Fatalf("Failed to start server: %v", err)
    }
}
```

#### Makefile

```makefile
# backend/Makefile

.PHONY: run build test clean docker-build docker-run

# 변수
APP_NAME=bbossiregi-api
GO=go
MAIN_PATH=./cmd/api

# 개발
run:
	$(GO) run $(MAIN_PATH)/main.go

# 빌드
build:
	CGO_ENABLED=0 GOOS=linux $(GO) build -o bin/$(APP_NAME) $(MAIN_PATH)/main.go

# 테스트
test:
	$(GO) test -v ./...

test-coverage:
	$(GO) test -v -coverprofile=coverage.out ./...
	$(GO) tool cover -html=coverage.out -o coverage.html

# 린트
lint:
	golangci-lint run

# 정리
clean:
	rm -rf bin/
	rm -f coverage.out coverage.html

# Docker
docker-build:
	docker build -t $(APP_NAME):latest .

docker-run:
	docker run -p 8080:8080 --env-file .env $(APP_NAME):latest

# 마이그레이션
migrate-up:
	psql $(DATABASE_URL) -f migrations/001_init.sql

migrate-seed:
	psql $(DATABASE_URL) -f migrations/002_seed.sql

# 의존성
deps:
	$(GO) mod download
	$(GO) mod tidy
```

#### .env.example

```bash
# backend/.env.example

# Server
PORT=8080
GIN_MODE=debug  # debug, release, test

# Database
DB_HOST=localhost
DB_PORT=5432
DB_USER=bbossiregi
DB_PASSWORD=your_password_here
DB_NAME=bbossiregi
DB_SSLMODE=disable  # disable, require, verify-full

# JWT
JWT_SECRET=your_jwt_secret_here_min_32_chars
JWT_EXPIRES_IN=3600  # seconds

# App
APP_ENV=development  # development, staging, production
```

### ✅ 완료 기준

```
1. go mod init 완료
2. 모든 디렉토리 구조 생성
3. go mod tidy로 의존성 설치 완료
4. make run으로 서버 시작 가능 (에러 없음)
```

### 🧪 검증

```bash
cd backend

# 의존성 설치
go mod tidy

# 빌드 테스트
go build ./...

# 실행 테스트 (DB 연결 전이므로 에러 예상)
make run
```

---

## D3-002: 설정 및 DB 연결 모듈

### 📌 태스크 정보

| 항목 | 내용 |
|------|------|
| ID | D3-002 |
| 우선순위 | P0 |
| 담당 | 백엔드 |
| 예상 시간 | 1.5시간 |
| 선행 작업 | D3-001 |
| 후행 작업 | D3-003 (인증 API) |

### 📋 체크리스트

```
[ ] config.go 작성
[ ] postgres.go 작성
[ ] Connection pool 설정
[ ] Health check 쿼리
[ ] 연결 테스트
```

### 📝 상세 명세

#### config.go

```go
// backend/internal/config/config.go
package config

import (
    "os"
    "strconv"
    "time"
)

type Config struct {
    Server   ServerConfig
    Database DatabaseConfig
    JWT      JWTConfig
    App      AppConfig
}

type ServerConfig struct {
    Port    string
    GinMode string
}

type DatabaseConfig struct {
    Host     string
    Port     string
    User     string
    Password string
    DBName   string
    SSLMode  string

    // Connection pool
    MaxOpenConns    int
    MaxIdleConns    int
    ConnMaxLifetime time.Duration
    ConnMaxIdleTime time.Duration
}

type JWTConfig struct {
    Secret    string
    ExpiresIn time.Duration
}

type AppConfig struct {
    Env string
}

func Load() *Config {
    return &Config{
        Server: ServerConfig{
            Port:    getEnv("PORT", "8080"),
            GinMode: getEnv("GIN_MODE", "debug"),
        },
        Database: DatabaseConfig{
            Host:            getEnv("DB_HOST", "localhost"),
            Port:            getEnv("DB_PORT", "5432"),
            User:            getEnv("DB_USER", "bbossiregi"),
            Password:        getEnv("DB_PASSWORD", ""),
            DBName:          getEnv("DB_NAME", "bbossiregi"),
            SSLMode:         getEnv("DB_SSLMODE", "disable"),
            MaxOpenConns:    getEnvInt("DB_MAX_OPEN_CONNS", 25),
            MaxIdleConns:    getEnvInt("DB_MAX_IDLE_CONNS", 5),
            ConnMaxLifetime: getEnvDuration("DB_CONN_MAX_LIFETIME", 5*time.Minute),
            ConnMaxIdleTime: getEnvDuration("DB_CONN_MAX_IDLE_TIME", 1*time.Minute),
        },
        JWT: JWTConfig{
            Secret:    getEnv("JWT_SECRET", ""),
            ExpiresIn: getEnvDuration("JWT_EXPIRES_IN", 3600*time.Second),
        },
        App: AppConfig{
            Env: getEnv("APP_ENV", "development"),
        },
    }
}

// DSN 생성
func (c *DatabaseConfig) DSN() string {
    return "host=" + c.Host +
        " port=" + c.Port +
        " user=" + c.User +
        " password=" + c.Password +
        " dbname=" + c.DBName +
        " sslmode=" + c.SSLMode
}

// 헬퍼 함수들
func getEnv(key, defaultValue string) string {
    if value := os.Getenv(key); value != "" {
        return value
    }
    return defaultValue
}

func getEnvInt(key string, defaultValue int) int {
    if value := os.Getenv(key); value != "" {
        if intVal, err := strconv.Atoi(value); err == nil {
            return intVal
        }
    }
    return defaultValue
}

func getEnvDuration(key string, defaultValue time.Duration) time.Duration {
    if value := os.Getenv(key); value != "" {
        if intVal, err := strconv.Atoi(value); err == nil {
            return time.Duration(intVal) * time.Second
        }
    }
    return defaultValue
}
```

#### postgres.go

```go
// backend/internal/database/postgres.go
package database

import (
    "database/sql"
    "fmt"
    "log"
    "time"

    _ "github.com/lib/pq"
    "github.com/bbossiregi/backend/internal/config"
)

func NewPostgresDB(cfg config.DatabaseConfig) (*sql.DB, error) {
    // 연결
    db, err := sql.Open("postgres", cfg.DSN())
    if err != nil {
        return nil, fmt.Errorf("failed to open database: %w", err)
    }

    // Connection pool 설정
    db.SetMaxOpenConns(cfg.MaxOpenConns)
    db.SetMaxIdleConns(cfg.MaxIdleConns)
    db.SetConnMaxLifetime(cfg.ConnMaxLifetime)
    db.SetConnMaxIdleTime(cfg.ConnMaxIdleTime)

    // Ping 테스트
    if err := db.Ping(); err != nil {
        return nil, fmt.Errorf("failed to ping database: %w", err)
    }

    // 연결 정보 로깅
    log.Printf("📦 Database connected: host=%s, port=%s, db=%s",
        cfg.Host, cfg.Port, cfg.DBName)
    log.Printf("📦 Connection pool: maxOpen=%d, maxIdle=%d",
        cfg.MaxOpenConns, cfg.MaxIdleConns)

    return db, nil
}

// HealthCheck - DB 상태 확인
func HealthCheck(db *sql.DB) error {
    ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
    defer cancel()

    var result int
    err := db.QueryRowContext(ctx, "SELECT 1").Scan(&result)
    if err != nil {
        return fmt.Errorf("database health check failed: %w", err)
    }
    return nil
}
```

### ✅ 완료 기준

```
1. make run 실행 시 "Database connected" 로그 출력
2. Connection pool 설정 적용 확인
3. 잘못된 DB 정보로 실행 시 적절한 에러 메시지
```

### 🧪 검증

```bash
# .env 파일 생성 (RDS 정보로)
cp .env.example .env
vi .env  # DB 정보 입력

# 실행
make run

# 예상 출력
# ✅ Database connected successfully
# ✅ Scheduler started
# 🚀 Server starting on port 8080
```

---

## D3-003: 공통 모델 및 응답 구조체

### 📌 태스크 정보

| 항목 | 내용 |
|------|------|
| ID | D3-003 |
| 우선순위 | P0 |
| 담당 | 백엔드 |
| 예상 시간 | 30분 |

### 📝 상세 명세

#### 공통 응답 구조체

```go
// backend/internal/model/response.go
package model

import "time"

// 성공 응답
type Response struct {
    Success bool        `json:"success"`
    Data    interface{} `json:"data,omitempty"`
    Meta    *Meta       `json:"meta,omitempty"`
}

// 에러 응답
type ErrorResponse struct {
    Success bool        `json:"success"`
    Error   ErrorDetail `json:"error"`
}

type ErrorDetail struct {
    Code    string      `json:"code"`
    Message string      `json:"message"`
    Details interface{} `json:"details,omitempty"`
}

// 페이지네이션
type Meta struct {
    Total      int `json:"total"`
    Page       int `json:"page"`
    PerPage    int `json:"per_page"`
    TotalPages int `json:"total_pages"`
}

// 유효성 검사 에러
type ValidationError struct {
    Field   string `json:"field"`
    Message string `json:"message"`
}
```

#### User 모델

```go
// backend/internal/model/user.go
package model

import "time"

type User struct {
    ID           int        `json:"id"`
    Email        string     `json:"email"`
    PasswordHash string     `json:"-"` // JSON에서 제외
    Name         string     `json:"name"`
    Phone        *string    `json:"phone,omitempty"`
    Role         string     `json:"role"`
    Status       string     `json:"status"`
    CreatedAt    time.Time  `json:"created_at"`
    UpdatedAt    time.Time  `json:"updated_at"`
    LastLoginAt  *time.Time `json:"last_login_at,omitempty"`
}

// 회원가입 요청
type RegisterRequest struct {
    Email    string  `json:"email" validate:"required,email,max=255"`
    Password string  `json:"password" validate:"required,min=8,max=100"`
    Name     string  `json:"name" validate:"required,min=2,max=100"`
    Phone    *string `json:"phone,omitempty" validate:"omitempty,len=13"`
}

// 로그인 요청
type LoginRequest struct {
    Email    string `json:"email" validate:"required,email"`
    Password string `json:"password" validate:"required"`
}

// 로그인 응답
type LoginResponse struct {
    AccessToken string `json:"access_token"`
    TokenType   string `json:"token_type"`
    ExpiresIn   int    `json:"expires_in"`
    User        User   `json:"user"`
}

// JWT Claims
type JWTClaims struct {
    UserID int    `json:"user_id"`
    Email  string `json:"email"`
    Role   string `json:"role"`
    jwt.RegisteredClaims
}
```

#### Product 모델

```go
// backend/internal/model/product.go
package model

import "time"

type Product struct {
    ID           int       `json:"id"`
    Name         string    `json:"name"`
    Description  *string   `json:"description,omitempty"`
    Price        float64   `json:"price"`
    ImageURL     *string   `json:"image_url,omitempty"`
    ThumbnailURL *string   `json:"thumbnail_url,omitempty"`
    Category     string    `json:"category"`
    Status       string    `json:"status"`
    CreatedAt    time.Time `json:"created_at"`
    UpdatedAt    time.Time `json:"updated_at"`
}

// 상품 요약 (타임딜 목록용)
type ProductSummary struct {
    ID       int     `json:"id"`
    Name     string  `json:"name"`
    ImageURL *string `json:"image_url,omitempty"`
    Category string  `json:"category"`
}
```

#### TimeDeal 모델

```go
// backend/internal/model/timedeal.go
package model

import "time"

type TimeDeal struct {
    ID               int       `json:"id"`
    ProductID        int       `json:"product_id"`
    OriginalPrice    float64   `json:"original_price"`
    DealPrice        float64   `json:"deal_price"`
    DiscountRate     int       `json:"discount_rate"`
    StockQuantity    int       `json:"stock_quantity"`
    ReservedQuantity int       `json:"reserved_quantity"`
    SoldQuantity     int       `json:"sold_quantity"`
    StartAt          time.Time `json:"start_at"`
    EndAt            time.Time `json:"end_at"`
    Status           string    `json:"status"`
    CreatedAt        time.Time `json:"created_at"`
    UpdatedAt        time.Time `json:"updated_at"`
}

// 타임딜 목록 응답
type TimeDealSummary struct {
    ID                int            `json:"id"`
    Product           ProductSummary `json:"product"`
    OriginalPrice     float64        `json:"original_price"`
    DealPrice         float64        `json:"deal_price"`
    DiscountRate      int            `json:"discount_rate"`
    StockQuantity     int            `json:"stock_quantity"`
    AvailableQuantity int            `json:"available_quantity"`
    StartAt           time.Time      `json:"start_at"`
    EndAt             time.Time      `json:"end_at"`
    Status            string         `json:"status"`
    RemainingSeconds  int            `json:"remaining_seconds"`
}

// 타임딜 상세 응답
type TimeDealDetail struct {
    ID                int       `json:"id"`
    Product           Product   `json:"product"`
    OriginalPrice     float64   `json:"original_price"`
    DealPrice         float64   `json:"deal_price"`
    DiscountRate      int       `json:"discount_rate"`
    StockQuantity     int       `json:"stock_quantity"`
    ReservedQuantity  int       `json:"reserved_quantity"`
    SoldQuantity      int       `json:"sold_quantity"`
    AvailableQuantity int       `json:"available_quantity"`
    StartAt           time.Time `json:"start_at"`
    EndAt             time.Time `json:"end_at"`
    Status            string    `json:"status"`
    RemainingSeconds  int       `json:"remaining_seconds"`
}

// 가용 재고 계산
func (t *TimeDeal) AvailableQuantity() int {
    return t.StockQuantity - t.ReservedQuantity - t.SoldQuantity
}

// 남은 시간 계산 (초)
func (t *TimeDeal) RemainingSeconds() int {
    if t.Status == "ended" || t.Status == "soldout" {
        return 0
    }
    now := time.Now()
    if t.Status == "scheduled" {
        return int(t.StartAt.Sub(now).Seconds())
    }
    // active
    remaining := int(t.EndAt.Sub(now).Seconds())
    if remaining < 0 {
        return 0
    }
    return remaining
}
```

#### Order 모델

```go
// backend/internal/model/order.go
package model

import "time"

type Order struct {
    ID          int        `json:"id"`
    UserID      int        `json:"user_id"`
    TimeDealID  int        `json:"time_deal_id"`
    Quantity    int        `json:"quantity"`
    UnitPrice   float64    `json:"unit_price"`
    TotalPrice  float64    `json:"total_price"`
    Status      string     `json:"status"`
    CreatedAt   time.Time  `json:"created_at"`
    UpdatedAt   time.Time  `json:"updated_at"`
    ReservedAt  *time.Time `json:"reserved_at,omitempty"`
    ConfirmedAt *time.Time `json:"confirmed_at,omitempty"`
    CanceledAt  *time.Time `json:"canceled_at,omitempty"`
}

// 주문 생성 요청
type CreateOrderRequest struct {
    TimeDealID int `json:"time_deal_id" validate:"required,gt=0"`
    Quantity   int `json:"quantity" validate:"required,min=1,max=10"`
}

// 주문 상태
const (
    OrderStatusPending   = "pending"
    OrderStatusReserved  = "reserved"
    OrderStatusConfirmed = "confirmed"
    OrderStatusCanceled  = "canceled"
    OrderStatusFailed    = "failed"
)

// 주문 이벤트
type OrderEvent struct {
    ID        int       `json:"id"`
    OrderID   int       `json:"order_id"`
    EventType string    `json:"event_type"`
    Payload   string    `json:"payload"` // JSON string
    ActorID   *int      `json:"actor_id,omitempty"`
    ActorType string    `json:"actor_type"`
    CreatedAt time.Time `json:"created_at"`
}

// 이벤트 타입
const (
    EventOrderCreated      = "CREATED"
    EventStockReserved     = "STOCK_RESERVED"
    EventStockReleased     = "STOCK_RELEASED"
    EventPaymentRequested  = "PAYMENT_REQUESTED"
    EventPaymentCompleted  = "PAYMENT_COMPLETED"
    EventPaymentFailed     = "PAYMENT_FAILED"
    EventOrderConfirmed    = "CONFIRMED"
    EventOrderCanceled     = "CANCELED"
)
```

---

## D3-004: 응답 헬퍼 및 미들웨어

### 📌 태스크 정보

| 항목 | 내용 |
|------|------|
| ID | D3-004 |
| 우선순위 | P0 |
| 담당 | 백엔드 |
| 예상 시간 | 1시간 |

### 📝 상세 명세

#### 응답 헬퍼

```go
// backend/pkg/response/response.go
package response

import (
    "net/http"

    "github.com/gin-gonic/gin"
    "github.com/bbossiregi/backend/internal/model"
)

// 성공 응답
func Success(c *gin.Context, data interface{}) {
    c.JSON(http.StatusOK, model.Response{
        Success: true,
        Data:    data,
    })
}

// 성공 응답 (페이지네이션)
func SuccessWithMeta(c *gin.Context, data interface{}, meta *model.Meta) {
    c.JSON(http.StatusOK, model.Response{
        Success: true,
        Data:    data,
        Meta:    meta,
    })
}

// 생성 성공
func Created(c *gin.Context, data interface{}) {
    c.JSON(http.StatusCreated, model.Response{
        Success: true,
        Data:    data,
    })
}

// 에러 응답
func Error(c *gin.Context, statusCode int, code, message string) {
    c.JSON(statusCode, model.ErrorResponse{
        Success: false,
        Error: model.ErrorDetail{
            Code:    code,
            Message: message,
        },
    })
}

// 에러 응답 (상세)
func ErrorWithDetails(c *gin.Context, statusCode int, code, message string, details interface{}) {
    c.JSON(statusCode, model.ErrorResponse{
        Success: false,
        Error: model.ErrorDetail{
            Code:    code,
            Message: message,
            Details: details,
        },
    })
}

// 400 Bad Request
func BadRequest(c *gin.Context, message string) {
    Error(c, http.StatusBadRequest, "BAD_REQUEST", message)
}

// 401 Unauthorized
func Unauthorized(c *gin.Context, message string) {
    Error(c, http.StatusUnauthorized, "UNAUTHORIZED", message)
}

// 403 Forbidden
func Forbidden(c *gin.Context, message string) {
    Error(c, http.StatusForbidden, "FORBIDDEN", message)
}

// 404 Not Found
func NotFound(c *gin.Context, message string) {
    Error(c, http.StatusNotFound, "NOT_FOUND", message)
}

// 409 Conflict
func Conflict(c *gin.Context, code, message string) {
    Error(c, http.StatusConflict, code, message)
}

// 500 Internal Server Error
func InternalError(c *gin.Context, message string) {
    Error(c, http.StatusInternalServerError, "INTERNAL_ERROR", message)
}

// 유효성 검사 에러
func ValidationError(c *gin.Context, errors []model.ValidationError) {
    c.JSON(http.StatusBadRequest, model.ErrorResponse{
        Success: false,
        Error: model.ErrorDetail{
            Code:    "VALIDATION_ERROR",
            Message: "유효성 검사 실패",
            Details: errors,
        },
    })
}
```

#### 유틸: 비밀번호 해싱

```go
// backend/pkg/utils/hash.go
package utils

import (
    "golang.org/x/crypto/bcrypt"
)

const bcryptCost = 10

// 비밀번호 해싱
func HashPassword(password string) (string, error) {
    bytes, err := bcrypt.GenerateFromPassword([]byte(password), bcryptCost)
    return string(bytes), err
}

// 비밀번호 검증
func CheckPassword(password, hash string) bool {
    err := bcrypt.CompareHashAndPassword([]byte(hash), []byte(password))
    return err == nil
}
```

#### 유틸: JWT

```go
// backend/pkg/utils/jwt.go
package utils

import (
    "errors"
    "time"

    "github.com/golang-jwt/jwt/v5"
    "github.com/bbossiregi/backend/internal/model"
)

var (
    ErrInvalidToken = errors.New("invalid token")
    ErrExpiredToken = errors.New("token has expired")
)

// JWT 생성
func GenerateToken(userID int, email, role, secret string, expiresIn time.Duration) (string, error) {
    claims := model.JWTClaims{
        UserID: userID,
        Email:  email,
        Role:   role,
        RegisteredClaims: jwt.RegisteredClaims{
            ExpiresAt: jwt.NewNumericDate(time.Now().Add(expiresIn)),
            IssuedAt:  jwt.NewNumericDate(time.Now()),
            Issuer:    "bbossiregi",
        },
    }

    token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
    return token.SignedString([]byte(secret))
}

// JWT 검증
func ValidateToken(tokenString, secret string) (*model.JWTClaims, error) {
    token, err := jwt.ParseWithClaims(tokenString, &model.JWTClaims{}, func(token *jwt.Token) (interface{}, error) {
        if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
            return nil, ErrInvalidToken
        }
        return []byte(secret), nil
    })

    if err != nil {
        return nil, err
    }

    if claims, ok := token.Claims.(*model.JWTClaims); ok && token.Valid {
        return claims, nil
    }

    return nil, ErrInvalidToken
}
```

#### 미들웨어: JWT 인증

```go
// backend/internal/middleware/auth.go
package middleware

import (
    "strings"

    "github.com/gin-gonic/gin"
    "github.com/bbossiregi/backend/internal/config"
    "github.com/bbossiregi/backend/pkg/response"
    "github.com/bbossiregi/backend/pkg/utils"
)

func AuthMiddleware(cfg *config.Config) gin.HandlerFunc {
    return func(c *gin.Context) {
        // Authorization 헤더 확인
        authHeader := c.GetHeader("Authorization")
        if authHeader == "" {
            response.Unauthorized(c, "인증 토큰이 필요합니다")
            c.Abort()
            return
        }

        // Bearer 토큰 추출
        parts := strings.Split(authHeader, " ")
        if len(parts) != 2 || parts[0] != "Bearer" {
            response.Unauthorized(c, "잘못된 인증 형식입니다")
            c.Abort()
            return
        }

        tokenString := parts[1]

        // 토큰 검증
        claims, err := utils.ValidateToken(tokenString, cfg.JWT.Secret)
        if err != nil {
            response.Unauthorized(c, "유효하지 않은 토큰입니다")
            c.Abort()
            return
        }

        // Context에 사용자 정보 저장
        c.Set("userID", claims.UserID)
        c.Set("userEmail", claims.Email)
        c.Set("userRole", claims.Role)

        c.Next()
    }
}

// Admin 권한 확인
func AdminOnly() gin.HandlerFunc {
    return func(c *gin.Context) {
        role, exists := c.Get("userRole")
        if !exists || role != "admin" {
            response.Forbidden(c, "관리자 권한이 필요합니다")
            c.Abort()
            return
        }
        c.Next()
    }
}
```

#### 미들웨어: 로거

```go
// backend/internal/middleware/logger.go
package middleware

import (
    "log"
    "time"

    "github.com/gin-gonic/gin"
)

func LoggerMiddleware() gin.HandlerFunc {
    return func(c *gin.Context) {
        start := time.Now()
        path := c.Request.URL.Path
        method := c.Request.Method

        // 요청 처리
        c.Next()

        // 로그 기록
        latency := time.Since(start)
        statusCode := c.Writer.Status()
        clientIP := c.ClientIP()

        log.Printf("[%s] %s %s %d %v %s",
            method,
            path,
            clientIP,
            statusCode,
            latency,
            c.Errors.String(),
        )
    }
}
```

#### 미들웨어: CORS

```go
// backend/internal/middleware/cors.go
package middleware

import (
    "github.com/gin-gonic/gin"
)

func CORSMiddleware() gin.HandlerFunc {
    return func(c *gin.Context) {
        c.Writer.Header().Set("Access-Control-Allow-Origin", "*")
        c.Writer.Header().Set("Access-Control-Allow-Credentials", "true")
        c.Writer.Header().Set("Access-Control-Allow-Headers", "Content-Type, Content-Length, Authorization, Accept, X-Requested-With")
        c.Writer.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, PATCH, DELETE, OPTIONS")

        if c.Request.Method == "OPTIONS" {
            c.AbortWithStatus(204)
            return
        }

        c.Next()
    }
}
```

---

## D3-005: 인증 API (회원가입/로그인)

### 📌 태스크 정보

| 항목 | 내용 |
|------|------|
| ID | D3-005 |
| 우선순위 | P1 |
| 담당 | 백엔드 |
| 예상 시간 | 1.5시간 |

### 📋 체크리스트

```
[ ] User Repository 구현
[ ] Auth Service 구현
[ ] Auth Handler 구현
    [ ] POST /auth/register
    [ ] POST /auth/login
[ ] 유효성 검사
[ ] 에러 처리
[ ] 테스트
```

### 📝 상세 명세

#### User Repository

```go
// backend/internal/repository/user_repo.go
package repository

import (
    "context"
    "database/sql"
    "errors"
    "time"

    "github.com/bbossiregi/backend/internal/model"
)

var (
    ErrUserNotFound      = errors.New("user not found")
    ErrDuplicateEmail    = errors.New("email already exists")
)

type UserRepository struct {
    db *sql.DB
}

func NewUserRepository(db *sql.DB) *UserRepository {
    return &UserRepository{db: db}
}

// 이메일로 사용자 조회
func (r *UserRepository) FindByEmail(ctx context.Context, email string) (*model.User, error) {
    query := `
        SELECT id, email, password_hash, name, phone, role, status, 
               created_at, updated_at, last_login_at
        FROM users
        WHERE email = $1 AND status = 'active'
    `

    var user model.User
    var phone, lastLoginAt sql.NullString
    var lastLogin sql.NullTime

    err := r.db.QueryRowContext(ctx, query, email).Scan(
        &user.ID,
        &user.Email,
        &user.PasswordHash,
        &user.Name,
        &phone,
        &user.Role,
        &user.Status,
        &user.CreatedAt,
        &user.UpdatedAt,
        &lastLogin,
    )

    if err == sql.ErrNoRows {
        return nil, ErrUserNotFound
    }
    if err != nil {
        return nil, err
    }

    if phone.Valid {
        user.Phone = &phone.String
    }
    if lastLogin.Valid {
        user.LastLoginAt = &lastLogin.Time
    }

    return &user, nil
}

// 사용자 생성
func (r *UserRepository) Create(ctx context.Context, user *model.User) error {
    query := `
        INSERT INTO users (email, password_hash, name, phone, role, status)
        VALUES ($1, $2, $3, $4, $5, $6)
        RETURNING id, created_at, updated_at
    `

    err := r.db.QueryRowContext(ctx, query,
        user.Email,
        user.PasswordHash,
        user.Name,
        user.Phone,
        user.Role,
        user.Status,
    ).Scan(&user.ID, &user.CreatedAt, &user.UpdatedAt)

    if err != nil {
        // 중복 이메일 체크 (PostgreSQL unique violation)
        if isPgUniqueViolation(err) {
            return ErrDuplicateEmail
        }
        return err
    }

    return nil
}

// 마지막 로그인 시간 업데이트
func (r *UserRepository) UpdateLastLogin(ctx context.Context, userID int) error {
    query := `UPDATE users SET last_login_at = $1 WHERE id = $2`
    _, err := r.db.ExecContext(ctx, query, time.Now(), userID)
    return err
}

// 이메일 존재 여부 확인
func (r *UserRepository) ExistsByEmail(ctx context.Context, email string) (bool, error) {
    query := `SELECT EXISTS(SELECT 1 FROM users WHERE email = $1)`
    var exists bool
    err := r.db.QueryRowContext(ctx, query, email).Scan(&exists)
    return exists, err
}

// PostgreSQL unique violation 체크
func isPgUniqueViolation(err error) bool {
    return strings.Contains(err.Error(), "duplicate key") ||
           strings.Contains(err.Error(), "unique constraint")
}
```

#### Auth Service

```go
// backend/internal/service/auth_service.go
package service

import (
    "context"
    "errors"

    "github.com/bbossiregi/backend/internal/config"
    "github.com/bbossiregi/backend/internal/model"
    "github.com/bbossiregi/backend/internal/repository"
    "github.com/bbossiregi/backend/pkg/utils"
)

var (
    ErrInvalidCredentials = errors.New("invalid email or password")
    ErrEmailAlreadyExists = errors.New("email already exists")
)

type AuthService struct {
    userRepo *repository.UserRepository
    cfg      *config.Config
}

func NewAuthService(userRepo *repository.UserRepository, cfg *config.Config) *AuthService {
    return &AuthService{
        userRepo: userRepo,
        cfg:      cfg,
    }
}

// 회원가입
func (s *AuthService) Register(ctx context.Context, req *model.RegisterRequest) (*model.User, error) {
    // 이메일 중복 확인
    exists, err := s.userRepo.ExistsByEmail(ctx, req.Email)
    if err != nil {
        return nil, err
    }
    if exists {
        return nil, ErrEmailAlreadyExists
    }

    // 비밀번호 해싱
    hashedPassword, err := utils.HashPassword(req.Password)
    if err != nil {
        return nil, err
    }

    // 사용자 생성
    user := &model.User{
        Email:        req.Email,
        PasswordHash: hashedPassword,
        Name:         req.Name,
        Phone:        req.Phone,
        Role:         "user",
        Status:       "active",
    }

    if err := s.userRepo.Create(ctx, user); err != nil {
        if errors.Is(err, repository.ErrDuplicateEmail) {
            return nil, ErrEmailAlreadyExists
        }
        return nil, err
    }

    return user, nil
}

// 로그인
func (s *AuthService) Login(ctx context.Context, req *model.LoginRequest) (*model.LoginResponse, error) {
    // 사용자 조회
    user, err := s.userRepo.FindByEmail(ctx, req.Email)
    if err != nil {
        if errors.Is(err, repository.ErrUserNotFound) {
            return nil, ErrInvalidCredentials
        }
        return nil, err
    }

    // 비밀번호 검증
    if !utils.CheckPassword(req.Password, user.PasswordHash) {
        return nil, ErrInvalidCredentials
    }

    // JWT 생성
    token, err := utils.GenerateToken(
        user.ID,
        user.Email,
        user.Role,
        s.cfg.JWT.Secret,
        s.cfg.JWT.ExpiresIn,
    )
    if err != nil {
        return nil, err
    }

    // 마지막 로그인 시간 업데이트
    _ = s.userRepo.UpdateLastLogin(ctx, user.ID)

    return &model.LoginResponse{
        AccessToken: token,
        TokenType:   "Bearer",
        ExpiresIn:   int(s.cfg.JWT.ExpiresIn.Seconds()),
        User:        *user,
    }, nil
}
```

#### Auth Handler

```go
// backend/internal/handler/auth_handler.go
package handler

import (
    "errors"
    "net/http"

    "github.com/gin-gonic/gin"
    "github.com/go-playground/validator/v10"
    "github.com/bbossiregi/backend/internal/model"
    "github.com/bbossiregi/backend/internal/service"
    "github.com/bbossiregi/backend/pkg/response"
)

type AuthHandler struct {
    authService *service.AuthService
    validate    *validator.Validate
}

func NewAuthHandler(authService *service.AuthService) *AuthHandler {
    return &AuthHandler{
        authService: authService,
        validate:    validator.New(),
    }
}

// POST /api/v1/auth/register
func (h *AuthHandler) Register(c *gin.Context) {
    var req model.RegisterRequest

    // JSON 파싱
    if err := c.ShouldBindJSON(&req); err != nil {
        response.BadRequest(c, "잘못된 요청 형식입니다")
        return
    }

    // 유효성 검사
    if err := h.validate.Struct(&req); err != nil {
        validationErrors := translateValidationErrors(err)
        response.ValidationError(c, validationErrors)
        return
    }

    // 회원가입 처리
    user, err := h.authService.Register(c.Request.Context(), &req)
    if err != nil {
        if errors.Is(err, service.ErrEmailAlreadyExists) {
            response.Error(c, http.StatusConflict, "DUPLICATE_EMAIL", "이미 사용 중인 이메일입니다")
            return
        }
        response.InternalError(c, "회원가입 처리 중 오류가 발생했습니다")
        return
    }

    response.Created(c, user)
}

// POST /api/v1/auth/login
func (h *AuthHandler) Login(c *gin.Context) {
    var req model.LoginRequest

    // JSON 파싱
    if err := c.ShouldBindJSON(&req); err != nil {
        response.BadRequest(c, "잘못된 요청 형식입니다")
        return
    }

    // 유효성 검사
    if err := h.validate.Struct(&req); err != nil {
        validationErrors := translateValidationErrors(err)
        response.ValidationError(c, validationErrors)
        return
    }

    // 로그인 처리
    result, err := h.authService.Login(c.Request.Context(), &req)
    if err != nil {
        if errors.Is(err, service.ErrInvalidCredentials) {
            response.Unauthorized(c, "이메일 또는 비밀번호가 올바르지 않습니다")
            return
        }
        response.InternalError(c, "로그인 처리 중 오류가 발생했습니다")
        return
    }

    response.Success(c, result)
}

// 유효성 검사 에러 번역
func translateValidationErrors(err error) []model.ValidationError {
    var errors []model.ValidationError
    for _, e := range err.(validator.ValidationErrors) {
        errors = append(errors, model.ValidationError{
            Field:   e.Field(),
            Message: getValidationMessage(e),
        })
    }
    return errors
}

func getValidationMessage(e validator.FieldError) string {
    switch e.Tag() {
    case "required":
        return "필수 입력 항목입니다"
    case "email":
        return "올바른 이메일 형식이 아닙니다"
    case "min":
        return "최소 " + e.Param() + "자 이상이어야 합니다"
    case "max":
        return "최대 " + e.Param() + "자까지 가능합니다"
    default:
        return "유효하지 않은 값입니다"
    }
}
```

### 🧪 검증

```bash
# 서버 실행
make run

# 회원가입 테스트
curl -X POST http://localhost:8080/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "password123",
    "name": "테스트유저"
  }'

# 예상 응답 (201)
{
  "success": true,
  "data": {
    "id": 1,
    "email": "test@example.com",
    "name": "테스트유저",
    "role": "user",
    "status": "active",
    "created_at": "2026-02-26T10:00:00Z"
  }
}

# 로그인 테스트
curl -X POST http://localhost:8080/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "password123"
  }'

# 예상 응답 (200)
{
  "success": true,
  "data": {
    "access_token": "eyJhbGciOiJIUzI1NiIs...",
    "token_type": "Bearer",
    "expires_in": 3600,
    "user": { ... }
  }
}

# 중복 이메일 테스트 (409)
# 잘못된 비밀번호 테스트 (401)
```

---

## D3-006: 타임딜 조회 API

### 📌 태스크 정보

| 항목 | 내용 |
|------|------|
| ID | D3-006 |
| 우선순위 | P1 |
| 담당 | 백엔드 |
| 예상 시간 | 1.5시간 |

### 📋 체크리스트

```
[ ] TimeDeal Repository 구현
    [ ] FindAll (목록)
    [ ] FindByID (상세)
[ ] TimeDeal Handler 구현
    [ ] GET /timedeals
    [ ] GET /timedeals/:id
[ ] 페이지네이션
[ ] 테스트
```

### 📝 상세 명세

#### TimeDeal Repository

```go
// backend/internal/repository/timedeal_repo.go
package repository

import (
    "context"
    "database/sql"
    "errors"



    "github.com/bbossiregi/backend/internal/model"
)

var (
    ErrTimeDealNotFound = errors.New("time deal not found")
)

type TimeDealRepository struct {
    db *sql.DB
}

func NewTimeDealRepository(db *sql.DB) *TimeDealRepository {
    return &TimeDealRepository{db: db}
}

// 타임딜 목록 조회
func (r *TimeDealRepository) FindAll(ctx context.Context, status string, page, perPage int) ([]model.TimeDealSummary, int, error) {
    // 전체 개수 조회
    countQuery := `SELECT COUNT(*) FROM time_deals WHERE ($1 = '' OR status = $1)`
    var total int
    if err := r.db.QueryRowContext(ctx, countQuery, status).Scan(&total); err != nil {
        return nil, 0, err
    }

    // 목록 조회
    query := `
        SELECT 
            td.id, td.original_price, td.deal_price,
            td.stock_quantity, td.reserved_quantity, td.sold_quantity,
            td.start_at, td.end_at, td.status,
            p.id, p.name, p.image_url, p.category
        FROM time_deals td
        JOIN products p ON td.product_id = p.id
        WHERE ($1 = '' OR td.status = $1)
        ORDER BY 
            CASE td.status 
                WHEN 'active' THEN 1 
                WHEN 'scheduled' THEN 2 
                ELSE 3 
            END,
            td.start_at ASC
        LIMIT $2 OFFSET $3
    `

    offset := (page - 1) * perPage
    rows, err := r.db.QueryContext(ctx, query, status, perPage, offset)
    if err != nil {
        return nil, 0, err
    }
    defer rows.Close()

    var deals []model.TimeDealSummary
    for rows.Next() {
        var deal model.TimeDealSummary
        var product model.ProductSummary
        var imageURL sql.NullString
        var reservedQty, soldQty int

        err := rows.Scan(
            &deal.ID, &deal.OriginalPrice, &deal.DealPrice,
            &deal.StockQuantity, &reservedQty, &soldQty,
            &deal.StartAt, &deal.EndAt, &deal.Status,
            &product.ID, &product.Name, &imageURL, &product.Category,
        )
        if err != nil {
            return nil, 0, err
        }

        if imageURL.Valid {
            product.ImageURL = &imageURL.String
        }
        deal.Product = product
        deal.AvailableQuantity = deal.StockQuantity - reservedQty - soldQty
        deal.DiscountRate = int((1 - deal.DealPrice/deal.OriginalPrice) * 100)
        deal.RemainingSeconds = calculateRemainingSeconds(deal.Status, deal.StartAt, deal.EndAt)

        deals = append(deals, deal)
    }

    return deals, total, nil
}

// 타임딜 상세 조회
func (r *TimeDealRepository) FindByID(ctx context.Context, id int) (*model.TimeDealDetail, error) {
    query := `
        SELECT 
            td.id, td.original_price, td.deal_price,
            td.stock_quantity, td.reserved_quantity, td.sold_quantity,
            td.start_at, td.end_at, td.status,
            p.id, p.name, p.description, p.price, p.image_url, p.category, p.status
        FROM time_deals td
        JOIN products p ON td.product_id = p.id
        WHERE td.id = $1
    `

    var deal model.TimeDealDetail
    var product model.Product
    var description, imageURL sql.NullString

    err := r.db.QueryRowContext(ctx, query, id).Scan(
        &deal.ID, &deal.OriginalPrice, &deal.DealPrice,
        &deal.StockQuantity, &deal.ReservedQuantity, &deal.SoldQuantity,
        &deal.StartAt, &deal.EndAt, &deal.Status,
        &product.ID, &product.Name, &description, &product.Price, &imageURL, &product.Category, &product.Status,
    )

    if err == sql.ErrNoRows {
        return nil, ErrTimeDealNotFound
    }
    if err != nil {
        return nil, err
    }

    if description.Valid {
        product.Description = &description.String
    }
    if imageURL.Valid {
        product.ImageURL = &imageURL.String
    }

    deal.Product = product
    deal.AvailableQuantity = deal.StockQuantity - deal.ReservedQuantity - deal.SoldQuantity
    deal.DiscountRate = int((1 - deal.DealPrice/deal.OriginalPrice) * 100)
    deal.RemainingSeconds = calculateRemainingSeconds(deal.Status, deal.StartAt, deal.EndAt)

    return &deal, nil
}

// 남은 시간 계산
func calculateRemainingSeconds(status string, startAt, endAt time.Time) int {
    now := time.Now()
    
    switch status {
    case "scheduled":
        return int(startAt.Sub(now).Seconds())
    case "active":
        remaining := int(endAt.Sub(now).Seconds())
        if remaining < 0 {
            return 0
        }
        return remaining
    default:
        return 0
    }
}
```

#### TimeDeal Handler

```go
// backend/internal/handler/timedeal_handler.go
package handler

import (
    "errors"
    "strconv"

    "github.com/gin-gonic/gin"
    "github.com/bbossiregi/backend/internal/model"
    "github.com/bbossiregi/backend/internal/repository"
    "github.com/bbossiregi/backend/pkg/response"
)

type TimeDealHandler struct {
    timeDealRepo *repository.TimeDealRepository
}

func NewTimeDealHandler(timeDealRepo *repository.TimeDealRepository) *TimeDealHandler {
    return &TimeDealHandler{timeDealRepo: timeDealRepo}
}

// GET /api/v1/timedeals
func (h *TimeDealHandler) List(c *gin.Context) {
    // 쿼리 파라미터
    status := c.DefaultQuery("status", "")
    page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
    perPage, _ := strconv.Atoi(c.DefaultQuery("per_page", "20"))

    // 유효성 검사
    if page < 1 {
        page = 1
    }
    if perPage < 1 || perPage > 100 {
        perPage = 20
    }

    // 상태 유효성 검사
    validStatuses := map[string]bool{
        "": true, "scheduled": true, "active": true, "ended": true, "soldout": true,
    }
    if !validStatuses[status] {
        response.BadRequest(c, "유효하지 않은 상태 값입니다")
        return
    }

    // 조회
    deals, total, err := h.timeDealRepo.FindAll(c.Request.Context(), status, page, perPage)
    if err != nil {
        response.InternalError(c, "타임딜 목록 조회 중 오류가 발생했습니다")
        return
    }

    // 페이지네이션 메타
    totalPages := (total + perPage - 1) / perPage
    meta := &model.Meta{
        Total:      total,
        Page:       page,
        PerPage:    perPage,
        TotalPages: totalPages,
    }

    response.SuccessWithMeta(c, deals, meta)
}

// GET /api/v1/timedeals/:id
func (h *TimeDealHandler) Get(c *gin.Context) {
    // 경로 파라미터
    idStr := c.Param("id")
    id, err := strconv.Atoi(idStr)
    if err != nil {
        response.BadRequest(c, "유효하지 않은 ID입니다")
        return
    }

    // 조회
    deal, err := h.timeDealRepo.FindByID(c.Request.Context(), id)
    if err != nil {
        if errors.Is(err, repository.ErrTimeDealNotFound) {
            response.NotFound(c, "타임딜을 찾을 수 없습니다")
            return
        }
        response.InternalError(c, "타임딜 조회 중 오류가 발생했습니다")
        return
    }

    response.Success(c, deal)
}
```

### 🧪 검증

```bash
# 타임딜 목록 조회
curl http://localhost:8080/api/v1/timedeals

# 상태 필터
curl "http://localhost:8080/api/v1/timedeals?status=active"

# 페이지네이션
curl "http://localhost:8080/api/v1/timedeals?page=1&per_page=10"

# 타임딜 상세 조회
curl http://localhost:8080/api/v1/timedeals/1
```

---

## D3-007: 타임딜 스케줄러

### 📌 태스크 정보

| 항목 | 내용 |
|------|------|
| ID | D3-007 |
| 우선순위 | P0 |
| 담당 | 백엔드 |
| 예상 시간 | 1.5시간 |

### 📋 체크리스트

```
[ ] Scheduler Service 구현
    [ ] 상태 전이 로직
    [ ] scheduled → active
    [ ] active → ended
    [ ] active → soldout
[ ] 1분 주기 실행
[ ] 로깅
[ ] 테스트
```

### 📝 상세 명세

#### Scheduler Service

```go
// backend/internal/service/scheduler_service.go
package service

import (
    "context"
    "database/sql"
    "log"
    "time"
)

type SchedulerService struct {
    db       *sql.DB
    interval time.Duration
    stopCh   chan struct{}
}

func NewSchedulerService(db *sql.DB) *SchedulerService {
    return &SchedulerService{
        db:       db,
        interval: 1 * time.Minute,
        stopCh:   make(chan struct{}),
    }
}

// 스케줄러 시작
func (s *SchedulerService) Start() {
    log.Println("⏰ Scheduler started, interval:", s.interval)

    // 시작 시 즉시 한 번 실행
    s.run()

    ticker := time.NewTicker(s.interval)
    defer ticker.Stop()

    for {
        select {
        case <-ticker.C:
            s.run()
        case <-s.stopCh:
            log.Println("⏰ Scheduler stopped")
            return
        }
    }
}

// 스케줄러 중지
func (s *SchedulerService) Stop() {
    close(s.stopCh)
}

// 상태 업데이트 실행
func (s *SchedulerService) run() {
    ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
    defer cancel()

    // 트랜잭션 시작
    tx, err := s.db.BeginTx(ctx, nil)
    if err != nil {
        log.Printf("❌ Scheduler: failed to begin transaction: %v", err)
        return
    }
    defer tx.Rollback()

    now := time.Now()

    // 1. scheduled → active
    activated, err := s.activateDeals(ctx, tx, now)
    if err != nil {
        log.Printf("❌ Scheduler: failed to activate deals: %v", err)
        return
    }

    // 2. active → ended (시간 만료)
    ended, err := s.expireDeals(ctx, tx, now)
    if err != nil {
        log.Printf("❌ Scheduler: failed to expire deals: %v", err)
        return
    }

    // 3. active → soldout (재고 소진)
    soldout, err := s.markSoldOut(ctx, tx)
    if err != nil {
        log.Printf("❌ Scheduler: failed to mark soldout: %v", err)
        return
    }

    // 커밋
    if err := tx.Commit(); err != nil {
        log.Printf("❌ Scheduler: failed to commit: %v", err)
        return
    }

    // 변경 사항 로깅
    if activated > 0 || ended > 0 || soldout > 0 {
        log.Printf("⏰ Scheduler: activated=%d, ended=%d, soldout=%d",
            activated, ended, soldout)
    }
}

// scheduled → active
func (s *SchedulerService) activateDeals(ctx context.Context, tx *sql.Tx, now time.Time) (int64, error) {
    query := `
        UPDATE time_deals
        SET status = 'active', updated_at = $1
        WHERE status = 'scheduled'
        AND start_at <= $1
        AND end_at > $1
    `
    result, err := tx.ExecContext(ctx, query, now)
    if err != nil {
        return 0, err
    }
    return result.RowsAffected()
}

// active → ended
func (s *SchedulerService) expireDeals(ctx context.Context, tx *sql.Tx, now time.Time) (int64, error) {
    query := `
        UPDATE time_deals
        SET status = 'ended', updated_at = $1
        WHERE status = 'active'
        AND end_at <= $1
    `
    result, err := tx.ExecContext(ctx, query, now)
    if err != nil {
        return 0, err
    }
    return result.RowsAffected()
}

// active → soldout
func (s *SchedulerService) markSoldOut(ctx context.Context, tx *sql.Tx) (int64, error) {
    query := `
        UPDATE time_deals
        SET status = 'soldout', updated_at = CURRENT_TIMESTAMP
        WHERE status = 'active'
        AND stock_quantity <= (reserved_quantity + sold_quantity)
    `
    result, err := tx.ExecContext(ctx, query)
    if err != nil {
        return 0, err
    }
    return result.RowsAffected()
}
```

---

## D3-008: 라우터 설정

### 📌 태스크 정보

| 항목 | 내용 |
|------|------|
| ID | D3-008 |
| 우선순위 | P0 |
| 담당 | 백엔드 |
| 예상 시간 | 30분 |

### 📝 상세 명세

```go
// backend/internal/router/router.go
package router

import (
    "database/sql"

    "github.com/gin-gonic/gin"
    "github.com/bbossiregi/backend/internal/config"
    "github.com/bbossiregi/backend/internal/handler"
    "github.com/bbossiregi/backend/internal/middleware"
    "github.com/bbossiregi/backend/internal/repository"
    "github.com/bbossiregi/backend/internal/service"
)

func Setup(db *sql.DB, cfg *config.Config) *gin.Engine {
    // Gin 모드 설정
    gin.SetMode(cfg.Server.GinMode)

    r := gin.New()

    // 글로벌 미들웨어
    r.Use(gin.Recovery())
    r.Use(middleware.LoggerMiddleware())
    r.Use(middleware.CORSMiddleware())

    // Repositories
    userRepo := repository.NewUserRepository(db)
    timeDealRepo := repository.NewTimeDealRepository(db)
    // orderRepo := repository.NewOrderRepository(db)  // Day 4

    // Services
    authService := service.NewAuthService(userRepo, cfg)
    // stockService := service.NewStockService(db)  // Day 4
    // orderService := service.NewOrderService(...)  // Day 4

    // Handlers
    authHandler := handler.NewAuthHandler(authService)
    timeDealHandler := handler.NewTimeDealHandler(timeDealRepo)
    healthHandler := handler.NewHealthHandler(db)
    // orderHandler := handler.NewOrderHandler(...)  // Day 4

    // API v1
    v1 := r.Group("/api/v1")
    {
        // Health
        v1.GET("/health", healthHandler.Check)

        // Auth (인증 불필요)
        auth := v1.Group("/auth")
        {
            auth.POST("/register", authHandler.Register)
            auth.POST("/login", authHandler.Login)
        }

        // TimeDeals (인증 불필요 - 조회)
        timedeals := v1.Group("/timedeals")
        {
            timedeals.GET("", timeDealHandler.List)
            timedeals.GET("/:id", timeDealHandler.Get)
        }

        // Orders (인증 필요) - Day 4
        // orders := v1.Group("/orders")
        // orders.Use(middleware.AuthMiddleware(cfg))
        // {
        //     orders.POST("", orderHandler.Create)
        //     orders.GET("", orderHandler.List)
        //     orders.GET("/:id", orderHandler.Get)
        //     orders.DELETE("/:id", orderHandler.Cancel)
        // }

        // Admin (관리자 전용) - 선택
        // admin := v1.Group("/admin")
        // admin.Use(middleware.AuthMiddleware(cfg))
        // admin.Use(middleware.AdminOnly())
        // {
        //     admin.POST("/products", ...)
        //     admin.POST("/timedeals", ...)
        // }
    }

    return r
}
```

#### Health Handler

```go
// backend/internal/handler/health_handler.go
package handler

import (
    "database/sql"
    "time"

    "github.com/gin-gonic/gin"
    "github.com/bbossiregi/backend/pkg/response"
)

type HealthHandler struct {
    db *sql.DB
}

func NewHealthHandler(db *sql.DB) *HealthHandler {
    return &HealthHandler{db: db}
}

// GET /api/v1/health
func (h *HealthHandler) Check(c *gin.Context) {
    // DB 체크
    dbStatus := "ok"
    if err := h.db.Ping(); err != nil {
        dbStatus = "error"
    }

    response.Success(c, gin.H{
        "status":    "healthy",
        "timestamp": time.Now().Format(time.RFC3339),
        "version":   "1.0.0",
        "checks": gin.H{
            "database": dbStatus,
        },
    })
}
```

---

## D3-009: Day 3 검증 및 리뷰

### 📋 Day 3 완료 기준 체크리스트

```
[ ] Go 프로젝트 구조 완성
[ ] DB 연결 성공
[ ] 회원가입 API 동작
[ ] 로그인 API 동작 + JWT 발급
[ ] 타임딜 목록 조회 동작
[ ] 타임딜 상세 조회 동작
[ ] 스케줄러 동작 (로그 확인)
[ ] 헬스체크 API 동작
[ ] Postman Collection

```



# 📅 Day 4 (2/27 목) - 주문 로직 + 컨테이너화

## 타임라인

| 시간 | 태스크 | 담당 | 산출물 |
|------|--------|------|--------|
| 09:00-09:30 | 데일리 스탠드업 | 전체 | 회의록 |
| 09:30-12:00 | 주문 API (사가 패턴) | 백엔드 | order_handler.go |
| 09:30-11:00 | ECR 레포지토리 생성 | 인프라 | Terraform 코드 |
| 11:00-12:00 | Dockerfile 작성 | 인프라 | Dockerfile |
| 13:00-15:00 | 재고 관리 서비스 (동시성) | 백엔드 | stock_service.go |
| 13:00-15:00 | EKS 클러스터 생성 | 인프라 | Terraform 코드 |
| 15:00-17:00 | 주문 취소 (보상 트랜잭션) | 백엔드 | 보상 로직 |
| 15:00-17:00 | K8s 매니페스트 작성 | 인프라 | k8s/*.yaml |
| 17:00-18:00 | Day 4 리뷰 + 통합 테스트 | 전체 | 테스트 결과 |

---

## D4-001: 주문 Repository 구현

### 📌 태스크 정보

| 항목 | 내용 |
|------|------|
| ID | D4-001 |
| 우선순위 | P0 (Blocker) |
| 담당 | 백엔드 |
| 예상 시간 | 1시간 |
| 선행 작업 | D3-006 (타임딜 API) |
| 후행 작업 | D4-002 (재고 서비스) |

### 📋 체크리스트

```
[ ] Order Repository 구현
    [ ] Create (주문 생성)
    [ ] FindByID (주문 조회)
    [ ] FindByUserID (사용자별 주문 목록)
    [ ] UpdateStatus (상태 변경)
[ ] OrderEvent Repository 구현
    [ ] Create (이벤트 기록)
    [ ] FindByOrderID (이벤트 조회)
[ ] 트랜잭션 처리 준비
```

### 📝 상세 명세

#### Order Repository

```go
// backend/internal/repository/order_repo.go
package repository

import (
    "context"
    "database/sql"
    "encoding/json"
    "errors"
    "time"

    "github.com/bbossiregi/backend/internal/model"
)

var (
    ErrOrderNotFound = errors.New("order not found")
)

type OrderRepository struct {
    db *sql.DB
}

func NewOrderRepository(db *sql.DB) *OrderRepository {
    return &OrderRepository{db: db}
}

// 주문 생성 (트랜잭션 내에서 호출)
func (r *OrderRepository) CreateTx(ctx context.Context, tx *sql.Tx, order *model.Order) error {
    query := `
        INSERT INTO orders (user_id, time_deal_id, quantity, unit_price, total_price, status)
        VALUES ($1, $2, $3, $4, $5, $6)
        RETURNING id, created_at, updated_at
    `

    err := tx.QueryRowContext(ctx, query,
        order.UserID,
        order.TimeDealID,
        order.Quantity,
        order.UnitPrice,
        order.TotalPrice,
        order.Status,
    ).Scan(&order.ID, &order.CreatedAt, &order.UpdatedAt)

    return err
}

// 주문 상태 변경 (트랜잭션 내에서 호출)
func (r *OrderRepository) UpdateStatusTx(ctx context.Context, tx *sql.Tx, orderID int, status string) error {
    var query string
    var args []interface{}

    now := time.Now()

    switch status {
    case model.OrderStatusReserved:
        query = `UPDATE orders SET status = $1, reserved_at = $2, updated_at = $2 WHERE id = $3`
        args = []interface{}{status, now, orderID}
    case model.OrderStatusConfirmed:
        query = `UPDATE orders SET status = $1, confirmed_at = $2, updated_at = $2 WHERE id = $3`
        args = []interface{}{status, now, orderID}
    case model.OrderStatusCanceled:
        query = `UPDATE orders SET status = $1, canceled_at = $2, updated_at = $2 WHERE id = $3`
        args = []interface{}{status, now, orderID}
    default:
        query = `UPDATE orders SET status = $1, updated_at = $2 WHERE id = $3`
        args = []interface{}{status, now, orderID}
    }

    result, err := tx.ExecContext(ctx, query, args...)
    if err != nil {
        return err
    }

    rowsAffected, _ := result.RowsAffected()
    if rowsAffected == 0 {
        return ErrOrderNotFound
    }

    return nil
}

// ID로 주문 조회
func (r *OrderRepository) FindByID(ctx context.Context, id int) (*model.Order, error) {
    query := `
        SELECT id, user_id, time_deal_id, quantity, unit_price, total_price,
               status, created_at, updated_at, reserved_at, confirmed_at, canceled_at
        FROM orders
        WHERE id = $1
    `

    var order model.Order
    var reservedAt, confirmedAt, canceledAt sql.NullTime

    err := r.db.QueryRowContext(ctx, query, id).Scan(
        &order.ID,
        &order.UserID,
        &order.TimeDealID,
        &order.Quantity,
        &order.UnitPrice,
        &order.TotalPrice,
        &order.Status,
        &order.CreatedAt,
        &order.UpdatedAt,
        &reservedAt,
        &confirmedAt,
        &canceledAt,
    )

    if err == sql.ErrNoRows {
        return nil, ErrOrderNotFound
    }
    if err != nil {
        return nil, err
    }

    if reservedAt.Valid {
        order.ReservedAt = &reservedAt.Time
    }
    if confirmedAt.Valid {
        order.ConfirmedAt = &confirmedAt.Time
    }
    if canceledAt.Valid {
        order.CanceledAt = &canceledAt.Time
    }

    return &order, nil
}

// ID로 주문 조회 (트랜잭션 내, FOR UPDATE)
func (r *OrderRepository) FindByIDForUpdate(ctx context.Context, tx *sql.Tx, id int) (*model.Order, error) {
    query := `
        SELECT id, user_id, time_deal_id, quantity, unit_price, total_price,
               status, created_at, updated_at, reserved_at, confirmed_at, canceled_at
        FROM orders
        WHERE id = $1
        FOR UPDATE
    `

    var order model.Order
    var reservedAt, confirmedAt, canceledAt sql.NullTime

    err := tx.QueryRowContext(ctx, query, id).Scan(
        &order.ID,
        &order.UserID,
        &order.TimeDealID,
        &order.Quantity,
        &order.UnitPrice,
        &order.TotalPrice,
        &order.Status,
        &order.CreatedAt,
        &order.UpdatedAt,
        &reservedAt,
        &confirmedAt,
        &canceledAt,
    )

    if err == sql.ErrNoRows {
        return nil, ErrOrderNotFound
    }
    if err != nil {
        return nil, err
    }

    if reservedAt.Valid {
        order.ReservedAt = &reservedAt.Time
    }
    if confirmedAt.Valid {
        order.ConfirmedAt = &confirmedAt.Time
    }
    if canceledAt.Valid {
        order.CanceledAt = &canceledAt.Time
    }

    return &order, nil
}

// 사용자별 주문 목록 조회
func (r *OrderRepository) FindByUserID(ctx context.Context, userID, page, perPage int) ([]model.Order, int, error) {
    // 전체 개수 조회
    countQuery := `SELECT COUNT(*) FROM orders WHERE user_id = $1`
    var total int
    if err := r.db.QueryRowContext(ctx, countQuery, userID).Scan(&total); err != nil {
        return nil, 0, err
    }

    // 목록 조회
    query := `
        SELECT id, user_id, time_deal_id, quantity, unit_price, total_price,
               status, created_at, updated_at, reserved_at, confirmed_at, canceled_at
        FROM orders
        WHERE user_id = $1
        ORDER BY created_at DESC
        LIMIT $2 OFFSET $3
    `

    offset := (page - 1) * perPage
    rows, err := r.db.QueryContext(ctx, query, userID, perPage, offset)
    if err != nil {
        return nil, 0, err
    }
    defer rows.Close()

    var orders []model.Order
    for rows.Next() {
        var order model.Order
        var reservedAt, confirmedAt, canceledAt sql.NullTime

        err := rows.Scan(
            &order.ID,
            &order.UserID,
            &order.TimeDealID,
            &order.Quantity,
            &order.UnitPrice,
            &order.TotalPrice,
            &order.Status,
            &order.CreatedAt,
            &order.UpdatedAt,
            &reservedAt,
            &confirmedAt,
            &canceledAt,
        )
        if err != nil {
            return nil, 0, err
        }

        if reservedAt.Valid {
            order.ReservedAt = &reservedAt.Time
        }
        if confirmedAt.Valid {
            order.ConfirmedAt = &confirmedAt.Time
        }
        if canceledAt.Valid {
            order.CanceledAt = &canceledAt.Time
        }

        orders = append(orders, order)
    }

    return orders, total, nil
}
```

#### OrderEvent Repository

```go
// backend/internal/repository/order_event_repo.go
package repository

import (
    "context"
    "database/sql"
    "encoding/json"

    "github.com/bbossiregi/backend/internal/model"
)

type OrderEventRepository struct {
    db *sql.DB
}

func NewOrderEventRepository(db *sql.DB) *OrderEventRepository {
    return &OrderEventRepository{db: db}
}

// 이벤트 생성 (트랜잭션 내에서 호출)
func (r *OrderEventRepository) CreateTx(ctx context.Context, tx *sql.Tx, event *model.OrderEvent) error {
    query := `
        INSERT INTO order_events (order_id, event_type, payload, actor_id, actor_type)
        VALUES ($1, $2, $3, $4, $5)
        RETURNING id, created_at
    `

    return tx.QueryRowContext(ctx, query,
        event.OrderID,
        event.EventType,
        event.Payload,
        event.ActorID,
        event.ActorType,
    ).Scan(&event.ID, &event.CreatedAt)
}

// 주문별 이벤트 조회
func (r *OrderEventRepository) FindByOrderID(ctx context.Context, orderID int) ([]model.OrderEvent, error) {
    query := `
        SELECT id, order_id, event_type, payload, actor_id, actor_type, created_at
        FROM order_events
        WHERE order_id = $1
        ORDER BY created_at ASC
    `

    rows, err := r.db.QueryContext(ctx, query, orderID)
    if err != nil {
        return nil, err
    }
    defer rows.Close()

    var events []model.OrderEvent
    for rows.Next() {
        var event model.OrderEvent
        var actorID sql.NullInt64

        err := rows.Scan(
            &event.ID,
            &event.OrderID,
            &event.EventType,
            &event.Payload,
            &actorID,
            &event.ActorType,
            &event.CreatedAt,
        )
        if err != nil {
            return nil, err
        }

        if actorID.Valid {
            id := int(actorID.Int64)
            event.ActorID = &id
        }

        events = append(events, event)
    }

    return events, nil
}

// 이벤트 Payload 생성 헬퍼
func CreateEventPayload(data map[string]interface{}) string {
    if data == nil {
        return "{}"
    }
    bytes, _ := json.Marshal(data)
    return string(bytes)
}
```

---

## D4-002: 재고 관리 서비스 (동시성 제어 핵심!)

### 📌 태스크 정보

| 항목 | 내용 |
|------|------|
| ID | D4-002 |
| 우선순위 | P0 (Blocker) |
| 담당 | 백엔드 |
| 예상 시간 | 2시간 |
| 선행 작업 | D4-001 |
| 후행 작업 | D4-003 (주문 서비스) |

### 📋 체크리스트

```
[ ] Stock Service 구현
    [ ] ReserveStock (재고 예약 - 비관적 락)
    [ ] ReleaseStock (재고 해제 - 보상)
    [ ] ConfirmStock (재고 확정)
[ ] 동시성 제어 (SELECT FOR UPDATE)
[ ] 재고 부족 예외 처리
[ ] 데드락 방지
```

### 📝 상세 명세

#### Stock Service (핵심!)

```go
// backend/internal/service/stock_service.go
package service

import (
    "context"
    "database/sql"
    "errors"
    "fmt"
    "time"
)

var (
    ErrInsufficientStock = errors.New("insufficient stock")
    ErrDealNotActive     = errors.New("deal is not active")
    ErrDealNotFound      = errors.New("deal not found")
)

type StockService struct {
    db *sql.DB
}

func NewStockService(db *sql.DB) *StockService {
    return &StockService{db: db}
}

// TimeDeal 정보 (재고 관리용)
type TimeDealStock struct {
    ID               int
    ProductID        int
    DealPrice        float64
    StockQuantity    int
    ReservedQuantity int
    SoldQuantity     int
    Status           string
    StartAt          time.Time
    EndAt            time.Time
}

// 가용 재고 계산
func (t *TimeDealStock) AvailableQuantity() int {
    return t.StockQuantity - t.ReservedQuantity - t.SoldQuantity
}

// 재고 예약 (사가 패턴 Step 2)
// 트랜잭션 내에서 호출되어야 함
func (s *StockService) ReserveStock(ctx context.Context, tx *sql.Tx, timeDealID, quantity int) (*TimeDealStock, error) {
    // 1. SELECT FOR UPDATE로 타임딜 락 획득
    deal, err := s.getTimeDealForUpdate(ctx, tx, timeDealID)
    if err != nil {
        return nil, err
    }

    // 2. 타임딜 상태 확인
    if deal.Status != "active" {
        return nil, ErrDealNotActive
    }

    // 3. 재고 확인
    available := deal.AvailableQuantity()
    if available < quantity {
        return nil, fmt.Errorf("%w: available=%d, requested=%d", 
            ErrInsufficientStock, available, quantity)
    }

    // 4. 재고 예약 (reserved_quantity 증가)
    err = s.updateReservedQuantity(ctx, tx, timeDealID, quantity)
    if err != nil {
        return nil, err
    }

    // 5. 업데이트된 정보 반환
    deal.ReservedQuantity += quantity
    return deal, nil
}

// 재고 해제 (보상 트랜잭션)
// 주문 취소 시 호출
func (s *StockService) ReleaseStock(ctx context.Context, tx *sql.Tx, timeDealID, quantity int) error {
    // 1. SELECT FOR UPDATE로 타임딜 락 획득
    deal, err := s.getTimeDealForUpdate(ctx, tx, timeDealID)
    if err != nil {
        return err
    }

    // 2. 예약된 수량 확인 (음수 방지)
    if deal.ReservedQuantity < quantity {
        return fmt.Errorf("cannot release more than reserved: reserved=%d, release=%d",
            deal.ReservedQuantity, quantity)
    }

    // 3. 재고 해제 (reserved_quantity 감소)
    query := `
        UPDATE time_deals
        SET reserved_quantity = reserved_quantity - $1,
            updated_at = CURRENT_TIMESTAMP
        WHERE id = $2
    `
    _, err = tx.ExecContext(ctx, query, quantity, timeDealID)
    return err
}

// 재고 확정 (결제 완료 후)
// reserved → sold 이동
func (s *StockService) ConfirmStock(ctx context.Context, tx *sql.Tx, timeDealID, quantity int) error {
    // 1. SELECT FOR UPDATE로 타임딜 락 획득
    deal, err := s.getTimeDealForUpdate(ctx, tx, timeDealID)
    if err != nil {
        return err
    }

    // 2. 예약된 수량 확인
    if deal.ReservedQuantity < quantity {
        return fmt.Errorf("cannot confirm more than reserved: reserved=%d, confirm=%d",
            deal.ReservedQuantity, quantity)
    }

    // 3. reserved → sold 이동
    query := `
        UPDATE time_deals
        SET reserved_quantity = reserved_quantity - $1,
            sold_quantity = sold_quantity + $1,
            updated_at = CURRENT_TIMESTAMP
        WHERE id = $2
    `
    _, err = tx.ExecContext(ctx, query, quantity, timeDealID)
    return err
}

// SELECT FOR UPDATE - 비관적 락
func (s *StockService) getTimeDealForUpdate(ctx context.Context, tx *sql.Tx, timeDealID int) (*TimeDealStock, error) {
    query := `
        SELECT id, product_id, deal_price, stock_quantity, reserved_quantity, 
               sold_quantity, status, start_at, end_at
        FROM time_deals
        WHERE id = $1
        FOR UPDATE
    `

    var deal TimeDealStock
    err := tx.QueryRowContext(ctx, query, timeDealID).Scan(
        &deal.ID,
        &deal.ProductID,
        &deal.DealPrice,
        &deal.StockQuantity,
        &deal.ReservedQuantity,
        &deal.SoldQuantity,
        &deal.Status,
        &deal.StartAt,
        &deal.EndAt,
    )

    if err == sql.ErrNoRows {
        return nil, ErrDealNotFound
    }
    if err != nil {
        return nil, err
    }

    return &deal, nil
}

// reserved_quantity 증가
func (s *StockService) updateReservedQuantity(ctx context.Context, tx *sql.Tx, timeDealID, quantity int) error {
    query := `
        UPDATE time_deals
        SET reserved_quantity = reserved_quantity + $1,
            updated_at = CURRENT_TIMESTAMP
        WHERE id = $2
    `
    _, err := tx.ExecContext(ctx, query, quantity, timeDealID)
    return err
}

// 타임딜 조회 (트랜잭션 없이)
func (s *StockService) GetTimeDeal(ctx context.Context, timeDealID int) (*TimeDealStock, error) {
    query := `
        SELECT id, product_id, deal_price, stock_quantity, reserved_quantity, 
               sold_quantity, status, start_at, end_at
        FROM time_deals
        WHERE id = $1
    `

    var deal TimeDealStock
    err := s.db.QueryRowContext(ctx, query, timeDealID).Scan(
        &deal.ID,
        &deal.ProductID,
        &deal.DealPrice,
        &deal.StockQuantity,
        &deal.ReservedQuantity,
        &deal.SoldQuantity,
        &deal.Status,
        &deal.StartAt,
        &deal.EndAt,
    )

    if err == sql.ErrNoRows {
        return nil, ErrDealNotFound
    }
    if err != nil {
        return nil, err
    }

    return &deal, nil
}
```

---

## D4-003: 주문 서비스 (사가 패턴 구현)

### 📌 태스크 정보

| 항목 | 내용 |
|------|------|
| ID | D4-003 |
| 우선순위 | P0 (Blocker) |
| 담당 | 백엔드 |
| 예상 시간 | 2시간 |
| 선행 작업 | D4-002 |
| 후행 작업 | D4-004 (주문 핸들러) |

### 📋 체크리스트

```
[ ] Order Service 구현
    [ ] CreateOrder (사가 패턴 실행)
    [ ] CancelOrder (보상 트랜잭션)
    [ ] GetOrder
    [ ] ListOrders
[ ] 트랜잭션 관리
[ ] 이벤트 기록
[ ] 에러 처리 및 롤백
```

### 📝 상세 명세

#### Order Service

```go
// backend/internal/service/order_service.go
package service

import (
    "context"
    "database/sql"
    "errors"
    "fmt"
    "log"

    "github.com/bbossiregi/backend/internal/model"
    "github.com/bbossiregi/backend/internal/repository"
)

var (
    ErrOrderAlreadyCanceled  = errors.New("order already canceled")
    ErrOrderAlreadyConfirmed = errors.New("order already confirmed")
    ErrCannotCancelOrder     = errors.New("cannot cancel order in current status")
    ErrUnauthorized          = errors.New("unauthorized to access this order")
)

type OrderService struct {
    db             *sql.DB
    orderRepo      *repository.OrderRepository
    orderEventRepo *repository.OrderEventRepository
    stockService   *StockService
}

func NewOrderService(
    db *sql.DB,
    orderRepo *repository.OrderRepository,
    orderEventRepo *repository.OrderEventRepository,
    stockService *StockService,
) *OrderService {
    return &OrderService{
        db:             db,
        orderRepo:      orderRepo,
        orderEventRepo: orderEventRepo,
        stockService:   stockService,
    }
}

// 주문 생성 - 사가 패턴 구현
// Step 1: 주문 생성 (pending)
// Step 2: 재고 예약 (reserved_quantity += quantity)
// Step 3: 주문 상태 변경 (reserved)
func (s *OrderService) CreateOrder(ctx context.Context, userID int, req *model.CreateOrderRequest) (*model.Order, error) {
    // 트랜잭션 시작
    tx, err := s.db.BeginTx(ctx, &sql.TxOptions{
        Isolation: sql.LevelSerializable, // 직렬화 격리 수준
    })
    if err != nil {
        return nil, fmt.Errorf("failed to begin transaction: %w", err)
    }
    defer tx.Rollback() // 에러 시 자동 롤백

    // ===== Step 1: 타임딜 정보 조회 및 검증 =====
    deal, err := s.stockService.getTimeDealForUpdate(ctx, tx, req.TimeDealID)
    if err != nil {
        if errors.Is(err, ErrDealNotFound) {
            return nil, fmt.Errorf("time deal not found: %d", req.TimeDealID)
        }
        return nil, err
    }

    // 타임딜 상태 확인
    if deal.Status != "active" {
        return nil, ErrDealNotActive
    }

    // 재고 사전 확인
    available := deal.AvailableQuantity()
    if available < req.Quantity {
        return nil, fmt.Errorf("%w: available=%d, requested=%d",
            ErrInsufficientStock, available, req.Quantity)
    }

    // ===== Step 2: 주문 생성 (pending) =====
    order := &model.Order{
        UserID:     userID,
        TimeDealID: req.TimeDealID,
        Quantity:   req.Quantity,
        UnitPrice:  deal.DealPrice,
        TotalPrice: deal.DealPrice * float64(req.Quantity),
        Status:     model.OrderStatusPending,
    }

    if err := s.orderRepo.CreateTx(ctx, tx, order); err != nil {
        return nil, fmt.Errorf("failed to create order: %w", err)
    }

    // 이벤트 기록: CREATED
    err = s.recordEvent(ctx, tx, order.ID, model.EventOrderCreated, userID, map[string]interface{}{
        "time_deal_id": req.TimeDealID,
        "quantity":     req.Quantity,
        "unit_price":   deal.DealPrice,
        "total_price":  order.TotalPrice,
    })
    if err != nil {
        return nil, fmt.Errorf("failed to record event: %w", err)
    }

    // ===== Step 3: 재고 예약 =====
    _, err = s.stockService.ReserveStock(ctx, tx, req.TimeDealID, req.Quantity)
    if err != nil {
        // 재고 부족 또는 타임딜 비활성 - 주문 실패 처리
        order.Status = model.OrderStatusFailed
        s.orderRepo.UpdateStatusTx(ctx, tx, order.ID, model.OrderStatusFailed)
        
        // 이벤트 기록: FAILED
        s.recordEvent(ctx, tx, order.ID, "FAILED", userID, map[string]interface{}{
            "reason": err.Error(),
        })
        
        // 트랜잭션 커밋 (실패 상태로)
        tx.Commit()
        return nil, err
    }

    // 이벤트 기록: STOCK_RESERVED
    err = s.recordEvent(ctx, tx, order.ID, model.EventStockReserved, userID, map[string]interface{}{
        "quantity": req.Quantity,
    })
    if err != nil {
        return nil, fmt.Errorf("failed to record event: %w", err)
    }

    // ===== Step 4: 주문 상태 변경 (reserved) =====
    if err := s.orderRepo.UpdateStatusTx(ctx, tx, order.ID, model.OrderStatusReserved); err != nil {
        return nil, fmt.Errorf("failed to update order status: %w", err)
    }
    order.Status = model.OrderStatusReserved

    // 트랜잭션 커밋
    if err := tx.Commit(); err != nil {
        return nil, fmt.Errorf("failed to commit transaction: %w", err)
    }

    log.Printf("✅ Order created: id=%d, user=%d, deal=%d, qty=%d, total=%.2f",
        order.ID, userID, req.TimeDealID, req.Quantity, order.TotalPrice)

    return order, nil
}

// 주문 취소 - 보상 트랜잭션
func (s *OrderService) CancelOrder(ctx context.Context, userID, orderID int) (*model.Order, error) {
    // 트랜잭션 시작
    tx, err := s.db.BeginTx(ctx, nil)
    if err != nil {
        return nil, fmt.Errorf("failed to begin transaction: %w", err)
    }
    defer tx.Rollback()

    // 주문 조회 (FOR UPDATE)
    order, err := s.orderRepo.FindByIDForUpdate(ctx, tx, orderID)
    if err != nil {
        return nil, err
    }

    // 권한 확인
    if order.UserID != userID {
        return nil, ErrUnauthorized
    }

    // 상태 확인
    switch order.Status {
    case model.OrderStatusCanceled:
        return nil, ErrOrderAlreadyCanceled
    case model.OrderStatusConfirmed:
        return nil, ErrOrderAlreadyConfirmed
    case model.OrderStatusPending, model.OrderStatusReserved:
        // 취소 가능
    default:
        return nil, ErrCannotCancelOrder
    }

    // ===== 보상 트랜잭션: 재고 해제 =====
    if order.Status == model.OrderStatusReserved {
        err = s.stockService.ReleaseStock(ctx, tx, order.TimeDealID, order.Quantity)
        if err != nil {
            return nil, fmt.Errorf("failed to release stock: %w", err)
        }

        // 이벤트 기록: STOCK_RELEASED
        err = s.recordEvent(ctx, tx, order.ID, model.EventStockReleased, userID, map[string]interface{}{
            "quantity": order.Quantity,
        })
        if err != nil {
            return nil, fmt.Errorf("failed to record event: %w", err)
        }
    }

    // 주문 상태 변경 (canceled)
    if err := s.orderRepo.UpdateStatusTx(ctx, tx, order.ID, model.OrderStatusCanceled); err != nil {
        return nil, fmt.Errorf("failed to update order status: %w", err)
    }
    order.Status = model.OrderStatusCanceled

    // 이벤트 기록: CANCELED
    err = s.recordEvent(ctx, tx, order.ID, model.EventOrderCanceled, userID, map[string]interface{}{
        "reason": "user_requested",
    })
    if err != nil {
        return nil, fmt.Errorf("failed to record event: %w", err)
    }

    // 커밋
    if err := tx.Commit(); err != nil {
        return nil, fmt.Errorf("failed to commit transaction: %w", err)
    }

    log.Printf("✅ Order canceled: id=%d, user=%d", order.ID, userID)

    return order, nil
}

// 주문 조회
func (s *OrderService) GetOrder(ctx context.Context, userID, orderID int) (*model.Order, error) {
    order, err := s.orderRepo.FindByID(ctx, orderID)
    if err != nil {
        return nil, err
    }

    // 권한 확인
    if order.UserID != userID {
        return nil, ErrUnauthorized
    }

    return order, nil
}

// 주문 목록 조회
func (s *OrderService) ListOrders(ctx context.Context, userID, page, perPage int) ([]model.Order, int, error) {
    return s.orderRepo.FindByUserID(ctx, userID, page, perPage)
}

// 이벤트 기록 헬퍼
func (s *OrderService) recordEvent(ctx context.Context, tx *sql.Tx, orderID int, eventType string, actorID int, data map[string]interface{}) error {
    event := &model.OrderEvent{
        OrderID:   orderID,
        EventType: eventType,
        Payload:   repository.CreateEventPayload(data),
        ActorID:   &actorID,
        ActorType: "user",
    }
    return s.orderEventRepo.CreateTx(ctx, tx, event)
}
```

---

## D4-004: 주문 API 핸들러

### 📌 태스크 정보

| 항목 | 내용 |
|------|------|
| ID | D4-004 |
| 우선순위 | P0 |
| 담당 | 백엔드 |
| 예상 시간 | 1시간 |
| 선행 작업 | D4-003 |

### 📋 체크리스트

```
[ ] Order Handler 구현
    [ ] POST /orders (주문 생성)
    [ ] GET /orders (목록 조회)
    [ ] GET /orders/:id (상세 조회)
    [ ] DELETE /orders/:id (주문 취소)
[ ] 에러 응답 처리
[ ] 테스트
```

### 📝 상세 명세

#### Order Handler

```go
// backend/internal/handler/order_handler.go
package handler

import (
    "errors"
    "net/http"
    "strconv"

    "github.com/gin-gonic/gin"
    "github.com/go-playground/validator/v10"
    "github.com/bbossiregi/backend/internal/model"
    "github.com/bbossiregi/backend/internal/repository"
    "github.com/bbossiregi/backend/internal/service"
    "github.com/bbossiregi/backend/pkg/response"
)

type OrderHandler struct {
    orderService *service.OrderService
    validate     *validator.Validate
}

func NewOrderHandler(orderService *service.OrderService) *OrderHandler {
    return &OrderHandler{
        orderService: orderService,
        validate:     validator.New(),
    }
}

// POST /api/v1/orders
func (h *OrderHandler) Create(c *gin.Context) {
    // 사용자 ID 추출 (JWT 미들웨어에서 설정)
    userID, exists := c.Get("userID")
    if !exists {
        response.Unauthorized(c, "인증이 필요합니다")
        return
    }

    var req model.CreateOrderRequest

    // JSON 파싱
    if err := c.ShouldBindJSON(&req); err != nil {
        response.BadRequest(c, "잘못된 요청 형식입니다")
        return
    }

    // 기본값 설정
    if req.Quantity == 0 {
        req.Quantity = 1
    }

    // 유효성 검사
    if err := h.validate.Struct(&req); err != nil {
        validationErrors := translateValidationErrors(err)
        response.ValidationError(c, validationErrors)
        return
    }

    // 수량 범위 검사
    if req.Quantity < 1 || req.Quantity > 10 {
        response.Error(c, http.StatusBadRequest, "INVALID_QUANTITY", "수량은 1~10 사이여야 합니다")
        return
    }

    // 주문 생성
    order, err := h.orderService.CreateOrder(c.Request.Context(), userID.(int), &req)
    if err != nil {
        // 에러 타입별 응답
        switch {
        case errors.Is(err, service.ErrDealNotFound):
            response.NotFound(c, "타임딜을 찾을 수 없습니다")
        case errors.Is(err, service.ErrDealNotActive):
            response.Error(c, http.StatusBadRequest, "DEAL_NOT_ACTIVE", "타임딜이 진행 중이 아닙니다")
        case errors.Is(err, service.ErrInsufficientStock):
            // 재고 부족 - 상세 정보 포함
            response.ErrorWithDetails(c, http.StatusConflict, "INSUFFICIENT_STOCK", "재고가 부족합니다", map[string]interface{}{
                "message": err.Error(),
            })
        default:
            response.InternalError(c, "주문 생성 중 오류가 발생했습니다")
        }
        return
    }

    response.Created(c, order)
}

// GET /api/v1/orders
func (h *OrderHandler) List(c *gin.Context) {
    userID, exists := c.Get("userID")
    if !exists {
        response.Unauthorized(c, "인증이 필요합니다")
        return
    }

    // 쿼리 파라미터
    page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
    perPage, _ := strconv.Atoi(c.DefaultQuery("per_page", "20"))

    if page < 1 {
        page = 1
    }
    if perPage < 1 || perPage > 100 {
        perPage = 20
    }

    // 조회
    orders, total, err := h.orderService.ListOrders(c.Request.Context(), userID.(int), page, perPage)
    if err != nil {
        response.InternalError(c, "주문 목록 조회 중 오류가 발생했습니다")
        return
    }

    // 페이지네이션 메타
    totalPages := (total + perPage - 1) / perPage
    meta := &model.Meta{
        Total:      total,
        Page:       page,
        PerPage:    perPage,
        TotalPages: totalPages,
    }

    response.SuccessWithMeta(c, orders, meta)
}

// GET /api/v1/orders/:id
func (h *OrderHandler) Get(c *gin.Context) {
    userID, exists := c.Get("userID")
    if !exists {
        response.Unauthorized(c, "인증이 필요합니다")
        return
    }

    // 경로 파라미터
    idStr := c.Param("id")
    orderID, err := strconv.Atoi(idStr)
    if err != nil {
        response.BadRequest(c, "유효하지 않은 주문 ID입니다")
        return
    }

    // 조회
    order, err := h.orderService.GetOrder(c.Request.Context(), userID.(int), orderID)
    if err != nil {
        switch {
        case errors.Is(err, repository.ErrOrderNotFound):
            response.NotFound(c, "주문을 찾을 수 없습니다")
        case errors.Is(err, service.ErrUnauthorized):
            response.Forbidden(c, "이 주문에 접근할 권한이 없습니다")
        default:
            response.InternalError(c, "주문 조회 중 오류가 발생했습니다")
        }
        return
    }

    response.Success(c, order)
}

// DELETE /api/v1/orders/:id
func (h *OrderHandler) Cancel(c *gin.Context) {
    userID, exists := c.Get("userID")
    if !exists {
        response.Unauthorized(c, "인증이 필요합니다")
        return
    }

    // 경로 파라미터
    idStr := c.Param("id")
    orderID, err := strconv.Atoi(idStr)
    if err != nil {
        response.BadRequest(c, "유효하지 않은 주문 ID입니다")
        return
    }

    // 취소
    order, err := h.orderService.CancelOrder(c.Request.Context(), userID.(int), orderID)
    if err != nil {
        switch {
        case errors.Is(err, repository.ErrOrderNotFound):
            response.NotFound(c, "주문을 찾을 수 없습니다")
        case errors.Is(err, service.ErrUnauthorized):
            response.Forbidden(c, "이 주문에 접근할 권한이 없습니다")
        case errors.Is(err, service.ErrOrderAlreadyCanceled):
            response.Error(c, http.StatusBadRequest, "ALREADY_CANCELED", "이미 취소된 주문입니다")
        case errors.Is(err, service.ErrOrderAlreadyConfirmed):
            response.Error(c, http.StatusBadRequest, "CANNOT_CANCEL", "이미 확정된 주문은 취소할 수 없습니다")
        case errors.Is(err, service.ErrCannotCancelOrder):
            response.Error(c, http.StatusBadRequest, "CANNOT_CANCEL", "현재 상태에서는 주문을 취소할 수 없습니다")
        default:
            response.InternalError(c, "주문 취소 중 오류가 발생했습니다")
        }
        return
    }

    response.Success(c, order)
}
```

---

## D4-005: 라우터 업데이트

### 📝 상세 명세

```go
// backend/internal/router/router.go (업데이트)
package router

import (
    "database/sql"

    "github.com/gin-gonic/gin"
    "github.com/bbossiregi/backend/internal/config"
    "github.com/bbossiregi/backend/internal/handler"
    "github.com/bbossiregi/backend/internal/middleware"
    "github.com/bbossiregi/backend/internal/repository"
    "github.com/bbossiregi/backend/internal/service"
)

func Setup(db *sql.DB, cfg *config.Config) *gin.Engine {
    gin.SetMode(cfg.Server.GinMode)

    r := gin.New()

    // 글로벌 미들웨어
    r.Use(gin.Recovery())
    r.Use(middleware.LoggerMiddleware())
    r.Use(middleware.CORSMiddleware())

    // Repositories
    userRepo := repository.NewUserRepository(db)
    timeDealRepo := repository.NewTimeDealRepository(db)
    orderRepo := repository.NewOrderRepository(db)
    orderEventRepo := repository.NewOrderEventRepository(db)

    // Services
    authService := service.NewAuthService(userRepo, cfg)
    stockService := service.NewStockService(db)
    orderService := service.NewOrderService(db, orderRepo, orderEventRepo, stockService)

    // Handlers
    authHandler := handler.NewAuthHandler(authService)
    timeDealHandler := handler.NewTimeDealHandler(timeDealRepo)
    orderHandler := handler.NewOrderHandler(orderService)
    healthHandler := handler.NewHealthHandler(db)

    // API v1
    v1 := r.Group("/api/v1")
    {
        // Health
        v1.GET("/health", healthHandler.Check)

        // Auth (인증 불필요)
        auth := v1.Group("/auth")
        {
            auth.POST("/register", authHandler.Register)
            auth.POST("/login", authHandler.Login)
        }

        // TimeDeals (인증 불필요)
        timedeals := v1.Group("/timedeals")
        {
            timedeals.GET("", timeDealHandler.List)
            timedeals.GET("/:id", timeDealHandler.Get)
        }

        // Orders (인증 필요)
        orders := v1.Group("/orders")
        orders.Use(middleware.AuthMiddleware(cfg))
        {
            orders.POST("", orderHandler.Create)
            orders.GET("", orderHandler.List)
            orders.GET("/:id", orderHandler.Get)
            orders.DELETE("/:id", orderHandler.Cancel)
        }
    }

    return r
}
```

---

## D4-006: ECR 레포지토리 생성

### 📌 태스크 정보

| 항목 | 내용 |
|------|------|
| ID | D4-006 |
| 우선순위 | P0 |
| 담당 | 인프라 |
| 예상 시간 | 30분 |
| 선행 작업 | D2-005 (보안 그룹) |
| 후행 작업 | D4-007 (Dockerfile) |

### 📋 체크리스트

```
[ ] ECR 레포지토리 생성
[ ] 이미지 스캔 활성화
[ ] 라이프사이클 정책 설정
[ ] 푸시 테스트
```

### 📝 Terraform 코드

```hcl
# terraform/modules/ecr/main.tf

resource "aws_ecr_repository" "backend" {
  name                 = "${var.project_name}-backend"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name        = "${var.project_name}-backend"
    Project     = var.project_name
    Environment = var.environment
  }
}

# 라이프사이클 정책 (이미지 정리)
resource "aws_ecr_lifecycle_policy" "backend" {
  repository = aws_ecr_repository.backend.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus     = "any"
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# Frontend 레포지토리 (선택)
resource "aws_ecr_repository" "frontend" {
  name                 = "${var.project_name}-frontend"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name        = "${var.project_name}-frontend"
    Project     = var.project_name
    Environment = var.environment
  }
}

output "backend_repository_url" {
  value = aws_ecr_repository.backend.repository_url
}

output "frontend_repository_url" {
  value = aws_ecr_repository.frontend.repository_url
}
```

### 🧪 검증

```bash
# ECR 로그인
aws ecr get-login-password --region ap-northeast-2 | \
  docker login --username AWS --password-stdin \
  <account-id>.dkr.ecr.ap-northeast-2.amazonaws.com

# 레포지토리 확인
aws ecr describe-repositories
```

---

## D4-007: Dockerfile 작성

### 📌 태스크 정보

| 항목 | 내용 |
|------|------|
| ID | D4-007 |
| 우선순위 | P0 |
| 담당 | 인프라/백엔드 |
| 예상 시간 | 30분 |

### 📋 체크리스트

```
[ ] 멀티 스테이지 빌드
[ ] 최소 이미지 (scratch/alpine)
[ ] 빌드 테스트
[ ] 로컬 실행 테스트
```

### 📝 Dockerfile

```dockerfile
# backend/Dockerfile

# ===== Build Stage =====
FROM golang:1.22-alpine AS builder

# 빌드 의존성 설치
RUN apk add --no-cache git ca-certificates tzdata

# 작업 디렉토리 설정
WORKDIR /app

# 의존성 파일 복사 및 다운로드 (캐싱 활용)
COPY go.mod go.sum ./
RUN go mod download

# 소스 코드 복사
COPY . .

# 빌드
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build -ldflags="-w -s" -o /app/server ./cmd/api/main.go

# ===== Runtime Stage =====
FROM alpine:3.19

# 타임존 및 인증서
RUN apk --no-cache add ca-certificates tzdata

# 비루트 사용자 생성
RUN adduser -D -g '' appuser

WORKDIR /app

# 빌드된 바이너리 복사
COPY --from=builder /app/server .

# 비루트 사용자로 실행
USER appuser

# 포트 노출
EXPOSE 8080

# 헬스체크
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8080/api/v1/health || exit 1

# 실행
ENTRYPOINT ["./server"]
```

### 🧪 검증

```bash
# 빌드
cd backend
docker build -t bbossiregi-backend:latest .

# 이미지 크기 확인 (목표: < 30MB)
docker images bbossiregi-backend

# 로컬 실행 테스트
docker run -p 8080:8080 \
  -e DB_HOST=host.docker.internal \
  -e DB_PORT=5432 \
  -e DB_USER=bbossiregi \
  -e DB_PASSWORD=xxx \
  -e DB_NAME=bbossiregi \
  -e JWT_SECRET=xxx \
  bbossiregi-backend:latest

# 헬스체크
curl http://localhost:8080/api/v1/health
```

---

## D4-008: EKS 클러스터 생성

### 📌 태스크 정보

| 항목 | 내용 |
|------|------|
| ID | D4-008 |
| 우선순위 | P0 (Blocker) |
| 담당 | 인프라 |
| 예상 시간 | 2시간 (클러스터 생성 ~15분) |
| 선행 작업 | D2-004 (라우팅 테이블) |
| 후행 작업 | D4-009 (K8s 매니페스트) |

### 📋 체크리스트

```
[ ] EKS 클러스터 생성
[ ] Node Group 생성
[ ] IAM 역할 및 정책
[ ] kubectl 연결 설정
[ ] 기본 네임스페이스 생성
```

### 📝 Terraform 코드

```hcl
# terraform/modules/eks/main.tf

# EKS 클러스터 IAM 역할
resource "aws_iam_role" "eks_cluster" {
  name = "${var.project_name}-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-eks-cluster-role"
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster.name
}

# EKS 클러스터
resource "aws_eks_cluster" "main" {
  name     = "${var.project_name}-eks"
  role_arn = aws_iam_role.eks_cluster.arn
  version  = "1.29"

  vpc_config {
    subnet_ids              = var.private_subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = true
    security_group_ids      = [var.cluster_security_group_id]
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator"]

  tags = {
    Name        = "${var.project_name}-eks"
    Project     = var.project_name
    Environment = var.environment
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy
  ]
}

# Node Group IAM 역할
resource "aws_iam_role" "eks_nodes" {
  name = "${var.project_name}-eks-nodes-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-eks-nodes-role"
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_nodes.name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_nodes.name
}

resource "aws_iam_role_policy_attachment" "eks_container_registry" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_nodes.name
}

# Node Group
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.project_name}-node-group"
  node_role_arn   = aws_iam_role.eks_nodes.arn
  subnet_ids      = var.private_subnet_ids

  capacity_type  = "ON_DEMAND"  # 또는 SPOT (비용 절감)
  instance_types = ["t3.medium"]

  scaling_config {
    desired_size = 2
    max_size     = 4
    min_size     = 1
  }

  update_config {
    max_unavailable = 1
  }

  labels = {
    role = "worker"
  }

  tags = {
    Name        = "${var.project_name}-node-group"
    Project     = var.project_name
    Environment = var.environment
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_container_registry,
  ]
}

# Outputs
output "cluster_endpoint" {
  value = aws_eks_cluster.main.endpoint
}

output "cluster_name" {
  value = aws_eks_cluster.main.name
}

output "cluster_certificate_authority" {
  value = aws_eks_cluster.main.certificate_authority[0].data
}
```

```hcl
# terraform/modules/eks/variables.tf

variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "cluster_security_group_id" {
  type = string
}
```

### 🧪 검증

```bash
# kubeconfig 업데이트
aws eks update-kubeconfig --name bbossiregi-eks --region ap-northeast-2

# 클러스터 확인
kubectl cluster-info

# 노드 확인
kubectl get nodes

# 예상 출력
NAME                                             STATUS   ROLES    AGE   VERSION
ip-10-0-11-xxx.ap-northeast-2.compute.internal   Ready    <none>   5m    v1.29.x
ip-10-0-12-xxx.ap-northeast-2.compute.internal   Ready    <none>   5m    v1.29.x
```

---

## D4-009: Kubernetes 매니페스트 작성

### 📌 태스크 정보

| 항목 | 내용 |
|------|------|
| ID | D4-009 |
| 우선순위 | P0 |
| 담당 | 인프라 |
| 예상 시간 | 1.5시간 |
| 선행 작업 | D4-008 |

### 📋 체크리스트

```
[ ] Namespace
[ ] ConfigMap
[ ] Secret
[ ] Deployment
[ ] Service
[ ] HPA (선택)
[ ] Ingress (Day 5)
```

### 📝 상세 명세

#### Namespace

```yaml
# k8s/base/namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: bbossiregi
  labels:
    app: bbossiregi
    env: production
```

#### ConfigMap

```yaml
# k8s/base/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: backend-config
  namespace: bbossiregi
data:
  GIN_MODE: "release"
  DB_SSLMODE: "require"
  APP_ENV: "production"
```

#### Secret

```yaml
# k8s/base/secret.yaml
# 주의: 실제 값은 base64 인코딩 필요
# kubectl create secret으로 생성 권장
apiVersion: v1
kind: Secret
metadata:
  name: backend-secret
  namespace: bbossiregi
type: Opaque
data:
  DB_HOST: <base64-encoded>
  DB_PORT: NTQzMg==  # 5432
  DB_USER: <base64-encoded>
  DB_PASSWORD: <base64-encoded>
  DB_NAME: <base64-encoded>
  JWT_SECRET: <base64-encoded>
```

#### Secret 생성 스크립트

```bash
# scripts/create-secrets.sh
#!/bin/bash

# 환경변수 설정
DB_HOST="your-rds-endpoint.ap-northeast-2.rds.amazonaws.com"
DB_PORT="5432"
DB_USER="bbossiregi"
DB_PASSWORD="your-password"
DB_NAME="bbossiregi"
JWT_SECRET="your-jwt-secret-min-32-characters"

# Secret 생성
kubectl create secret generic backend-secret \
  --namespace=bbossiregi \
  --from-literal=DB_HOST=$DB_HOST \
  --from-literal=DB_PORT=$DB_PORT \
  --from-literal=DB_USER=$DB_USER \
  --from-literal=DB_PASSWORD=$DB_PASSWORD \
  --from-literal=DB_NAME=$DB_NAME \
  --from-literal=JWT_SECRET=$JWT_SECRET \
  --dry-run=client -o yaml | kubectl apply -f -
```

#### Deployment

```yaml
# k8s/base/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: bbossiregi
  labels:
    app: backend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: backend
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    metadata:
      labels:
        app: backend
    spec:
      containers:
        - name: backend
          image: <account-id>.dkr.ecr.ap-northeast-2.amazonaws.com/bbossiregi-backend:latest
          imagePullPolicy: Always
          ports:
            - containerPort: 8080
              protocol: TCP
          envFrom:
            - configMapRef:
                name: backend-config
            - secretRef:
                name: backend-secret
          resources:
            requests:
              cpu: "100m"
              memory: "128Mi"
            limits:
              cpu: "500m"
              memory: "512Mi"
          livenessProbe:
            httpGet:
              path: /api/v1/health
              port: 8080
            initialDelaySeconds: 15
            periodSeconds: 20
            timeoutSeconds: 5
            failureThreshold: 3
          readinessProbe:
            httpGet:
              path: /api/v1/health
              port: 8080
            initialDelaySeconds: 5
            periodSeconds: 10
            timeoutSeconds: 3
            failureThreshold: 3
      terminationGracePeriodSeconds: 30
```

#### Service

```yaml
# k8s/base/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: backend-service
  namespace: bbossiregi
  labels:
    app: backend
spec:
  type: ClusterIP
  selector:
    app: backend
  ports:
    - name: http
      port: 80
      targetPort: 8080
      protocol: TCP
```

#### HPA (Horizontal Pod Autoscaler)

```yaml
# k8s/base/hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: backend-hpa
  namespace: bbossiregi
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: backend
  minReplicas: 2
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 80
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
        - type: Pods
          value: 1
          periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 0
      policies:
        - type: Pods
          value: 2
          periodSeconds: 60
```

#### Kustomization

```yaml
# k8s/base/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: bbossiregi

resources:
  - namespace.yaml
  - configmap.yaml
  - deployment.yaml
  - service.yaml
  - hpa.yaml

commonLabels:
  app.kubernetes.io/name: bbossiregi
  app.kubernetes.io/component: backend
```

### 🧪 검증

```bash
# 네임스페이스 생성
kubectl apply -f k8s/base/namespace.yaml

# Secret 생성
./scripts/create-secrets.sh

# 전체 배포 (kustomize)
kubectl apply -k k8s/base/

# 또는 개별 적용
kubectl apply -f k8s/base/configmap.yaml
kubectl apply -f k8s/base/deployment.yaml
kubectl apply -f k8s/base/service.yaml

# 상태 확인
kubectl get all -n bbossiregi

# Pod 로그 확인
kubectl logs -f deployment/backend -n bbossiregi

# 예상 출력
NAME                           READY   STATUS    RESTARTS   AGE
pod/backend-xxx-xxx            1/1     Running   0          2m
pod/backend-xxx-yyy            1/1     Running   0          2m

NAME                      TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
service/backend-service   ClusterIP   172.20.xxx.xxx  <none>        80/TCP    2m

NAME                      READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/backend   2/2     2            2           2m
```

---

## D4-010: Day 4 검증 - 주문 플로우 테스트

### 📋 Day 4 완료 기준 체크리스트

```
[ ] 주문 API 4개 완성
    [ ] POST /orders (주문 생성)
    [ ] GET /orders (목록 조회)
    [ ] GET /orders/:id (상세 조회)
    [ ] DELETE /orders/:id (취소)
[ ] 사가 패턴 동작 확인
    [ ] 주문 생성 시 재고 예약
    [ ] 주문 취소 시 재고 해제
[ ] 동시성 테스트 (선택)
[ ] ECR 이미지 푸시 완료
[ ] EKS 클러스터 생성 완료
[ ] K8s 매니페스트 작성 완료
[ ] Pod 정상 실행 확인
```

### 🧪 주문 플로우 테스트

```bash
# 1. 로그인하여 토큰 획득
TOKEN=$(curl -s -X POST http://localhost:8080/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"user1@test.com","password":"password123"}' | jq -r '.data.access_token')

echo "Token: $TOKEN"

# 2. 활성 타임딜 확인
curl -s http://localhost:8080/api/v1/timedeals?status=active | jq

# 3. 주문 생성 (재고 예약)
curl -s -X POST http://localhost:8080/api/v1/orders \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "time_deal_id": 1,
    "quantity": 2
  }' | jq

# 예상 응답
{
  "success": true,
  "data": {
    "id": 1,
    "user_id": 2,
    "time_deal_id": 1,
    "quantity": 2,
    "unit_price": 29900,
    "total_price": 59800,
    "status": "reserved",
    "created_at": "2026-02-27T10:00:00Z",
    "reserved_at": "2026-02-27T10:00:00Z"
  }
}

# 4. 타임딜 재고 확인 (reserved_quantity 증가)
curl -s http://localhost:8080/api/v1/timedeals/1 | jq '.data | {stock_quantity, reserved_quantity, sold_quantity, available_quantity}'

# 5. 주문 목록 조회
curl -s http://localhost:8080/api/v1/orders \
  -H "Authorization: Bearer $TOKEN" | jq

# 6. 주문 상세 조회
curl -s http://localhost:8080/api/v1/orders/1 \
  -H "Authorization: Bearer $TOKEN" | jq

# 7. 주문 취소 (재고 해제)
curl -s -X DELETE http://localhost:8080/api/v1/orders/1 \
  -H "Authorization: Bearer $TOKEN" | jq

# 예상 응답
{
  "success": true,
  "data": {
    "id": 1,
    "status": "canceled",
    "canceled_at": "2026-02-27T10:05:00Z"
  }
}

# 8. 타임딜 재고 확인 (reserved_quantity 감소)
curl -s http://localhost:8080/api/v1/timedeals/1 | jq '.data | {stock_quantity, reserved_quantity, sold_quantity, available_quantity}'
```

### 🧪 동시성 테스트 (선택)

```bash
# 동시에 10개 주문 요청 (재고 100개 기준)
# Apache Benchmark 또는 hey 사용

# hey 설치 (Go)
go install github.com/rakyll/hey@latest

# 동시성 테스트 (10개 동시, 총 50개 요청)
hey -n 50 -c 10 \
  -m POST \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"time_deal_id":1,"quantity":1}' \
  http://localhost:8080/api/v1/orders

# 결과 확인
# - 성공 주문 수 확인
# - 재고 정합성 확인 (reserved_quantity + sold_quantity = 성공 주문 수)
```

### 🧪 이벤트 기록 확인

```sql
-- order_events 테이블 확인
SELECT 
    oe.id,
    oe.order_id,
    oe.event_type,
    oe.payload,
    oe.created_at
FROM order_events oe
JOIN orders o ON oe.order_id = o.id
WHERE o.user_id = 2
ORDER BY oe.created_at DESC;

-- 예상 결과
-- id | order_id | event_type     | payload                          | created_at
-- 4  | 1        | CANCELED       | {"reason":"user_requested"}      | ...
-- 3  | 1        | STOCK_RELEASED | {"quantity":2}                   | ...
-- 2  | 1        | STOCK_RESERVED | {"quantity":2}                   | ...
-- 1  | 1        | CREATED        | {"time_deal_id":1,"quantity":2}  | ...
```

---

## D4-011: CI/CD 파이프라인 초안

### 📝 GitHub Actions Workflow

```yaml
# .github/workflows/ci.yml
name: CI

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up Go
        uses: actions/setup-go@v5
        with:
          go-version: '1.22'

      - name: Cache Go modules
        uses: actions/cache@v4
        with:
          path: ~/go/pkg/mod
          key: ${{ runner.os }}-go-${{ hashFiles('**/go.sum') }}
          restore-keys: |
            ${{ runner.os }}-go-

      - name: Download dependencies
        working-directory: ./backend
        run: go mod download

      - name: Run tests
        working-directory: ./backend
        run: go test -v -race -coverprofile=coverage.out ./...

      - name: Upload coverage
        uses: codecov/codecov-action@v4
        with:
          files: ./backend/coverage.out
          flags: backend

  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up Go
        uses: actions/setup-go@v5
        with:
          go-version: '1.22'

      - name: Run golangci-lint
        uses: golangci/golangci-lint-action@v4
        with:
          version: latest
          working-directory: ./backend

  build:
    needs: [test, lint]
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Build Docker image
        uses: docker/build-push-action@v5
        with:
          context: ./backend
          push: false
          tags: bbossiregi-backend:${{ github.sha }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
```

```yaml
# .github/workflows/cd.yml
name: CD

on:
  push:
    branches: [main]
    paths:
      - 'backend/**'

env:
  AWS_REGION: ap-northeast-2
  ECR_REPOSITORY: bbossiregi-backend
  EKS_CLUSTER_NAME: bbossiregi-eks

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ env.AWS_REGION }}

      - name: Login to Amazon ECR
        id: login-ecr
        uses: aws-actions/amazon-ecr-login@v2

      - name: Build, tag, and push image to Amazon ECR
        id: build-image
        env:
          ECR_REGISTRY: ${{ steps.login-ecr.outputs.registry }}
          IMAGE_TAG: ${{ github.sha }}
        run: |
          docker build -t $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG ./backend
          docker push $ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG
          echo "image=$ECR_REGISTRY/$ECR_REPOSITORY:$IMAGE_TAG" >> $GITHUB_OUTPUT

      - name: Update kubeconfig
        run: |
          aws eks update-kubeconfig --name ${{ env.EKS_CLUSTER_NAME }} --region ${{ env.AWS_REGION }}

      - name: Deploy to EKS
        env:
          IMAGE: ${{ steps.build-image.outputs.image }}
        run: |
          kubectl set image deployment/backend \
            backend=$IMAGE \
            -n bbossiregi
          kubectl rollout status deployment/backend -n bbossiregi --timeout=5m
```

---

# Day 4 완료! 🎉

Day 4 주요 달성 사항:
1. ✅ 주문 API (사가 패턴) 완성
2. ✅ 재고 관리 서비스 (동시성 제어)
3. ✅ 보상 트랜잭션 구현
4. ✅ ECR 레포지토리 생성
5. ✅ Dockerfile 작성
6. ✅ EKS 클러스터 생성
7. ✅ K8s 매니페스트 작성


# 📅 Day 5 (2/28 금) - 배포 + HTTPS + 회고

## 타임라인

| 시간 | 태스크 | 담당 | 산출물 |
|------|--------|------|--------|
| 09:00-09:30 | 데일리 스탠드업 | 전체 | 회의록 |
| 09:30-11:00 | ALB Ingress Controller 설치 | 인프라 | Ingress 리소스 |
| 09:30-11:00 | 백엔드 최종 점검 및 버그 수정 | 백엔드 | 수정된 코드 |
| 11:00-12:00 | ACM 인증서 + Route53 설정 | 인프라 | HTTPS 활성화 |
| 13:00-14:30 | 이미지 빌드 + ECR 푸시 + EKS 배포 | 전체 | 실행 중인 서비스 |
| 14:30-16:00 | E2E 테스트 + 버그 수정 | 전체 | 테스트 결과 |
| 16:00-17:00 | 모니터링 설정 (CloudWatch) | 인프라 | 대시보드 |
| 17:00-18:00 | 스프린트 회고 + 문서화 | 전체 | 회고록, README |

---

## D5-001: ALB Ingress Controller 설치

### 📌 태스크 정보

| 항목 | 내용 |
|------|------|
| ID | D5-001 |
| 우선순위 | P0 (Blocker) |
| 담당 | 인프라 |
| 예상 시간 | 1.5시간 |
| 선행 작업 | D4-008 (EKS 클러스터) |
| 후행 작업 | D5-002 (ACM 인증서) |

### 📋 체크리스트

```
[ ] IAM OIDC Provider 생성
[ ] IAM Policy 생성 (ALB Controller용)
[ ] IAM Role 생성 (ServiceAccount용)
[ ] AWS Load Balancer Controller 설치
[ ] Ingress 리소스 생성
[ ] ALB 생성 확인
```

### 📝 상세 명세

#### IAM OIDC Provider 생성

```bash
# OIDC Provider 확인
aws eks describe-cluster --name bbossiregi-eks --query "cluster.identity.oidc.issuer" --output text

# eksctl로 OIDC Provider 생성
eksctl utils associate-iam-oidc-provider \
    --region ap-northeast-2 \
    --cluster bbossiregi-eks \
    --approve
```

#### IAM Policy 생성

```bash
# AWS Load Balancer Controller IAM Policy 다운로드
curl -O https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.7.1/docs/install/iam_policy.json

# IAM Policy 생성
aws iam create-policy \
    --policy-name AWSLoadBalancerControllerIAMPolicy \
    --policy-document file://iam_policy.json
```

#### Terraform으로 IAM Role 생성

```hcl
# terraform/modules/eks/alb_controller.tf

# OIDC Provider 데이터
data "aws_eks_cluster" "main" {
  name = aws_eks_cluster.main.name
}

data "tls_certificate" "eks" {
  url = data.aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = data.aws_eks_cluster.main.identity[0].oidc[0].issuer
}

# ALB Controller IAM Role
resource "aws_iam_role" "alb_controller" {
  name = "${var.project_name}-alb-controller-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:aud" = "sts.amazonaws.com"
            "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
          }
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-alb-controller-role"
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_iam_role_policy_attachment" "alb_controller" {
  policy_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/AWSLoadBalancerControllerIAMPolicy"
  role       = aws_iam_role.alb_controller.name
}

data "aws_caller_identity" "current" {}

output "alb_controller_role_arn" {
  value = aws_iam_role.alb_controller.arn
}
```

#### AWS Load Balancer Controller 설치 (Helm)

```bash
# Helm 설치 (없는 경우)
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# EKS Helm 차트 리포지토리 추가
helm repo add eks https://aws.github.io/eks-charts
helm repo update

# AWS Load Balancer Controller 설치
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=bbossiregi-eks \
  --set serviceAccount.create=true \
  --set serviceAccount.name=aws-load-balancer-controller \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=arn:aws:iam::<ACCOUNT_ID>:role/bbossiregi-alb-controller-role \
  --set region=ap-northeast-2 \
  --set vpcId=<VPC_ID>

# 설치 확인
kubectl get deployment -n kube-system aws-load-balancer-controller
```

#### Ingress 리소스 생성

```yaml
# k8s/base/ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: backend-ingress
  namespace: bbossiregi
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}]'
    alb.ingress.kubernetes.io/healthcheck-path: /api/v1/health
    alb.ingress.kubernetes.io/healthcheck-interval-seconds: '15'
    alb.ingress.kubernetes.io/healthcheck-timeout-seconds: '5'
    alb.ingress.kubernetes.io/healthy-threshold-count: '2'
    alb.ingress.kubernetes.io/unhealthy-threshold-count: '2'
    alb.ingress.kubernetes.io/tags: Project=bbossiregi,Environment=production
spec:
  rules:
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: backend-service
                port:
                  number: 80
```

### 🧪 검증

```bash
# Ingress 적용
kubectl apply -f k8s/base/ingress.yaml

# Ingress 상태 확인
kubectl get ingress -n bbossiregi

# ALB 주소 확인 (생성까지 2-3분 소요)
kubectl get ingress backend-ingress -n bbossiregi -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# 예상 출력
# k8s-bbossire-backendi-xxxxxxxxxx-xxxxxxxxxx.ap-northeast-2.elb.amazonaws.com

# 헬스체크 테스트
ALB_URL=$(kubectl get ingress backend-ingress -n bbossiregi -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
curl http://$ALB_URL/api/v1/health

# 예상 응답
{
  "success": true,
  "data": {
    "status": "healthy",
    "timestamp": "2026-02-28T09:30:00Z",
    "version": "1.0.0",
    "checks": {
      "database": "ok"
    }
  }
}
```

---

## D5-002: ACM 인증서 발급

### 📌 태스크 정보

| 항목 | 내용 |
|------|------|
| ID | D5-002 |
| 우선순위 | P1 |
| 담당 | 인프라 |
| 예상 시간 | 30분 |
| 선행 작업 | D5-001 |
| 후행 작업 | D5-003 (Route53) |

### 📋 체크리스트

```
[ ] ACM 인증서 요청
[ ] DNS 검증 레코드 생성
[ ] 인증서 발급 확인
[ ] Ingress에 인증서 연결
```

### 📝 Terraform 코드

```hcl
# terraform/modules/acm/main.tf

# ACM 인증서
resource "aws_acm_certificate" "main" {
  domain_name               = var.domain_name
  subject_alternative_names = ["*.${var.domain_name}"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name        = "${var.project_name}-cert"
    Project     = var.project_name
    Environment = var.environment
  }
}

# Route53 Zone (이미 존재하는 경우 data source 사용)
data "aws_route53_zone" "main" {
  name         = var.domain_name
  private_zone = false
}

# DNS 검증 레코드
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.main.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.main.zone_id
}

# 인증서 검증 완료 대기
resource "aws_acm_certificate_validation" "main" {
  certificate_arn         = aws_acm_certificate.main.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

output "certificate_arn" {
  value = aws_acm_certificate.main.arn
}
```

```hcl
# terraform/modules/acm/variables.tf

variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "domain_name" {
  type        = string
  description = "도메인 이름 (예: bbossiregi.com)"
}
```

### 🧪 검증

```bash
# 인증서 상태 확인
aws acm describe-certificate \
  --certificate-arn <certificate-arn> \
  --query 'Certificate.Status'

# 예상 출력: "ISSUED"
```

---

## D5-003: Route53 DNS 설정

### 📌 태스크 정보

| 항목 | 내용 |
|------|------|
| ID | D5-003 |
| 우선순위 | P1 |
| 담당 | 인프라 |
| 예상 시간 | 30분 |
| 선행 작업 | D5-002 |

### 📋 체크리스트

```
[ ] Hosted Zone 확인/생성
[ ] ALB Alias 레코드 생성
[ ] DNS 전파 확인
```

### 📝 Terraform 코드

```hcl
# terraform/modules/route53/main.tf

# Hosted Zone (이미 존재하는 경우 data source)
data "aws_route53_zone" "main" {
  name         = var.domain_name
  private_zone = false
}

# API 서브도메인 → ALB
resource "aws_route53_record" "api" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "api.${var.domain_name}"
  type    = "A"

  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = true
  }
}

# 루트 도메인 (선택 - 프론트엔드용)
resource "aws_route53_record" "root" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = var.alb_dns_name
    zone_id                = var.alb_zone_id
    evaluate_target_health = true
  }
}

# www 서브도메인 (선택)
resource "aws_route53_record" "www" {
  zone_id = data.aws_route53_zone.main.zone_id
  name    = "www.${var.domain_name}"
  type    = "CNAME"
  ttl     = 300
  records = [var.domain_name]
}

output "api_domain" {
  value = aws_route53_record.api.fqdn
}
```

```hcl
# terraform/modules/route53/variables.tf

variable "domain_name" {
  type = string
}

variable "alb_dns_name" {
  type        = string
  description = "ALB DNS 이름"
}

variable "alb_zone_id" {
  type        = string
  description = "ALB Hosted Zone ID"
}
```

### 🧪 검증

```bash
# DNS 레코드 확인
dig api.bbossiregi.com

# 예상 응답 (A 레코드가 ALB IP로 해석)
;; ANSWER SECTION:
api.bbossiregi.com.     60      IN      A       xx.xx.xx.xx

# HTTP 테스트
curl http://api.bbossiregi.com/api/v1/health
```

---

## D5-004: HTTPS 활성화

### 📌 태스크 정보

| 항목 | 내용 |
|------|------|
| ID | D5-004 |
| 우선순위 | P1 |
| 담당 | 인프라 |
| 예상 시간 | 30분 |
| 선행 작업 | D5-002, D5-003 |

### 📋 체크리스트

```
[ ] Ingress에 HTTPS 설정 추가
[ ] HTTP → HTTPS 리다이렉트 설정
[ ] HTTPS 접속 테스트
```

### 📝 Ingress 업데이트 (HTTPS)

```yaml
# k8s/base/ingress-https.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: backend-ingress
  namespace: bbossiregi
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    # HTTPS 설정
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
    alb.ingress.kubernetes.io/ssl-redirect: '443'
    alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:ap-northeast-2:<ACCOUNT_ID>:certificate/<CERT_ID>
    # 헬스체크
    alb.ingress.kubernetes.io/healthcheck-path: /api/v1/health
    alb.ingress.kubernetes.io/healthcheck-interval-seconds: '15'
    alb.ingress.kubernetes.io/healthcheck-timeout-seconds: '5'
    alb.ingress.kubernetes.io/healthy-threshold-count: '2'
    alb.ingress.kubernetes.io/unhealthy-threshold-count: '2'
    # 보안 헤더
    alb.ingress.kubernetes.io/ssl-policy: ELBSecurityPolicy-TLS13-1-2-2021-06
    # 태그
    alb.ingress.kubernetes.io/tags: Project=bbossiregi,Environment=production
spec:
  rules:
    - host: api.bbossiregi.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: backend-service
                port:
                  number: 80
```

### 🧪 검증

```bash
# Ingress 업데이트
kubectl apply -f k8s/base/ingress-https.yaml

# HTTPS 테스트
curl https://api.bbossiregi.com/api/v1/health

# HTTP → HTTPS 리다이렉트 확인
curl -I http://api.bbossiregi.com/api/v1/health
# 예상: 301 Moved Permanently, Location: https://...

# SSL 인증서 확인
openssl s_client -connect api.bbossiregi.com:443 -servername api.bbossiregi.com < /dev/null 2>/dev/null | openssl x509 -noout -dates
```

---

## D5-005: 최종 이미지 빌드 및 배포

### 📌 태스크 정보

| 항목 | 내용 |
|------|------|
| ID | D5-005 |
| 우선순위 | P0 (Blocker) |
| 담당 | 전체 |
| 예상 시간 | 1시간 |
| 선행 작업 | D4-007 (Dockerfile), D5-001 |

### 📋 체크리스트

```
[ ] 최종 코드 점검
[ ] Docker 이미지 빌드
[ ] ECR 푸시
[ ] EKS 배포
[ ] Pod 상태 확인
[ ] 서비스 정상 동작 확인
```

### 📝 배포 스크립트

```bash
#!/bin/bash
# scripts/deploy.sh

set -e

# 변수 설정
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION="ap-northeast-2"
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
IMAGE_NAME="bbossiregi-backend"
IMAGE_TAG=$(git rev-parse --short HEAD)
NAMESPACE="bbossiregi"

echo "=========================================="
echo "🚀 뽀시레기 백엔드 배포 시작"
echo "=========================================="
echo "Account: $AWS_ACCOUNT_ID"
echo "Region: $AWS_REGION"
echo "Image: $ECR_REGISTRY/$IMAGE_NAME:$IMAGE_TAG"
echo "=========================================="

# 1. ECR 로그인
echo "📦 ECR 로그인..."
aws ecr get-login-password --region $AWS_REGION | \
  docker login --username AWS --password-stdin $ECR_REGISTRY

# 2. Docker 이미지 빌드
echo "🔨 Docker 이미지 빌드..."
cd backend
docker build -t $IMAGE_NAME:$IMAGE_TAG .
docker tag $IMAGE_NAME:$IMAGE_TAG $ECR_REGISTRY/$IMAGE_NAME:$IMAGE_TAG
docker tag $IMAGE_NAME:$IMAGE_TAG $ECR_REGISTRY/$IMAGE_NAME:latest

# 3. ECR 푸시
echo "📤 ECR 푸시..."
docker push $ECR_REGISTRY/$IMAGE_NAME:$IMAGE_TAG
docker push $ECR_REGISTRY/$IMAGE_NAME:latest

# 4. kubeconfig 업데이트
echo "⚙️ kubeconfig 업데이트..."
aws eks update-kubeconfig --name bbossiregi-eks --region $AWS_REGION

# 5. 배포
echo "🚀 EKS 배포..."
kubectl set image deployment/backend \
  backend=$ECR_REGISTRY/$IMAGE_NAME:$IMAGE_TAG \
  -n $NAMESPACE

# 6. 롤아웃 상태 확인
echo "⏳ 롤아웃 상태 확인..."
kubectl rollout status deployment/backend -n $NAMESPACE --timeout=5m

# 7. Pod 상태 확인
echo "✅ Pod 상태 확인..."
kubectl get pods -n $NAMESPACE -l app=backend

# 8. 서비스 테스트
echo "🧪 서비스 테스트..."
sleep 10  # ALB 헬스체크 대기
curl -s https://api.bbossiregi.com/api/v1/health | jq

echo "=========================================="
echo "✅ 배포 완료!"
echo "=========================================="
```

### 🧪 검증

```bash
# 배포 스크립트 실행
chmod +x scripts/deploy.sh
./scripts/deploy.sh

# 수동 확인
kubectl get pods -n bbossiregi
kubectl get svc -n bbossiregi
kubectl get ingress -n bbossiregi

# Pod 로그 확인
kubectl logs -f deployment/backend -n bbossiregi

# 이벤트 확인
kubectl get events -n bbossiregi --sort-by='.lastTimestamp'
```

---

## D5-006: E2E 테스트

### 📌 태스크 정보

| 항목 | 내용 |
|------|------|
| ID | D5-006 |
| 우선순위 | P0 |
| 담당 | 전체 |
| 예상 시간 | 1.5시간 |

### 📋 체크리스트

```
[ ] 헬스체크 API
[ ] 회원가입 API
[ ] 로그인 API
[ ] 타임딜 목록 조회
[ ] 타임딜 상세 조회
[ ] 주문 생성 (재고 예약)
[ ] 주문 조회
[ ] 주문 취소 (재고 해제)
[ ] 에러 케이스 테스트
```

### 📝 E2E 테스트 스크립트

```bash
#!/bin/bash
# scripts/e2e-test.sh

set -e

BASE_URL="https://api.bbossiregi.com/api/v1"
# 로컬 테스트: BASE_URL="http://localhost:8080/api/v1"

echo "=========================================="
echo "🧪 뽀시레기 E2E 테스트 시작"
echo "=========================================="
echo "Base URL: $BASE_URL"
echo "=========================================="

# 테스트 카운터
PASSED=0
FAILED=0

# 테스트 헬퍼 함수
test_api() {
    local name=$1
    local method=$2
    local endpoint=$3
    local data=$4
    local expected_status=$5
    local auth_header=$6

    echo -n "Testing: $name... "

    if [ -n "$auth_header" ]; then
        response=$(curl -s -w "\n%{http_code}" -X $method "$BASE_URL$endpoint" \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer $auth_header" \
            -d "$data")
    else
        response=$(curl -s -w "\n%{http_code}" -X $method "$BASE_URL$endpoint" \
            -H "Content-Type: application/json" \
            -d "$data")
    fi

    status_code=$(echo "$response" | tail -n 1)
    body=$(echo "$response" | sed '$d')

    if [ "$status_code" -eq "$expected_status" ]; then
        echo "✅ PASSED (HTTP $status_code)"
        ((PASSED++))
        echo "$body" | jq -c '.' 2>/dev/null || echo "$body"
    else
        echo "❌ FAILED (Expected: $expected_status, Got: $status_code)"
        ((FAILED++))
        echo "$body" | jq -c '.' 2>/dev/null || echo "$body"
    fi
    echo ""
}

# ========================================
# 1. 헬스체크
# ========================================
echo "=== 1. 헬스체크 ==="
test_api "Health Check" "GET" "/health" "" 200

# ========================================
# 2. 인증 테스트
# ========================================
echo "=== 2. 인증 테스트 ==="

# 회원가입 (새 유저)
RANDOM_EMAIL="test_$(date +%s)@example.com"
test_api "Register (New User)" "POST" "/auth/register" \
    "{\"email\":\"$RANDOM_EMAIL\",\"password\":\"password123\",\"name\":\"E2E테스터\"}" 201

# 회원가입 (중복 이메일)
test_api "Register (Duplicate Email)" "POST" "/auth/register" \
    "{\"email\":\"$RANDOM_EMAIL\",\"password\":\"password123\",\"name\":\"중복테스트\"}" 409

# 로그인 (성공)
LOGIN_RESPONSE=$(curl -s -X POST "$BASE_URL/auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"$RANDOM_EMAIL\",\"password\":\"password123\"}")

TOKEN=$(echo $LOGIN_RESPONSE | jq -r '.data.access_token')
echo "Token acquired: ${TOKEN:0:20}..."

test_api "Login (Success)" "POST" "/auth/login" \
    "{\"email\":\"$RANDOM_EMAIL\",\"password\":\"password123\"}" 200

# 로그인 (잘못된 비밀번호)
test_api "Login (Wrong Password)" "POST" "/auth/login" \
    "{\"email\":\"$RANDOM_EMAIL\",\"password\":\"wrongpassword\"}" 401

# ========================================
# 3. 타임딜 테스트
# ========================================
echo "=== 3. 타임딜 테스트 ==="

# 타임딜 목록 조회
test_api "TimeDeal List (All)" "GET" "/timedeals" "" 200

# 타임딜 목록 조회 (상태 필터)
test_api "TimeDeal List (Active)" "GET" "/timedeals?status=active" "" 200

# 타임딜 상세 조회
test_api "TimeDeal Detail (ID: 1)" "GET" "/timedeals/1" "" 200

# 타임딜 상세 조회 (없는 ID)
test_api "TimeDeal Detail (Not Found)" "GET" "/timedeals/99999" "" 404

# ========================================
# 4. 주문 테스트
# ========================================
echo "=== 4. 주문 테스트 ==="

# 주문 생성 전 재고 확인
echo "📦 주문 전 타임딜 재고 확인..."
curl -s "$BASE_URL/timedeals/1" | jq '.data | {stock_quantity, reserved_quantity, sold_quantity}'

# 주문 생성 (성공)
ORDER_RESPONSE=$(curl -s -X POST "$BASE_URL/orders" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN" \
    -d '{"time_deal_id":1,"quantity":1}')
ORDER_ID=$(echo $ORDER_RESPONSE | jq -r '.data.id')

test_api "Create Order (Success)" "POST" "/orders" \
    '{"time_deal_id":1,"quantity":1}' 201 "$TOKEN"

# 주문 생성 후 재고 확인
echo "📦 주문 후 타임딜 재고 확인 (reserved_quantity +1)..."
curl -s "$BASE_URL/timedeals/1" | jq '.data | {stock_quantity, reserved_quantity, sold_quantity}'

# 주문 생성 (인증 없음)
test_api "Create Order (No Auth)" "POST" "/orders" \
    '{"time_deal_id":1,"quantity":1}' 401

# 주문 생성 (잘못된 수량)
test_api "Create Order (Invalid Quantity)" "POST" "/orders" \
    '{"time_deal_id":1,"quantity":100}' 400 "$TOKEN"

# 주문 목록 조회
test_api "Order List" "GET" "/orders" "" 200 "$TOKEN"

# 주문 상세 조회
test_api "Order Detail" "GET" "/orders/$ORDER_ID" "" 200 "$TOKEN"

# 주문 취소
test_api "Cancel Order" "DELETE" "/orders/$ORDER_ID" "" 200 "$TOKEN"

# 주문 취소 후 재고 확인
echo "📦 주문 취소 후 타임딜 재고 확인 (reserved_quantity -1)..."
curl -s "$BASE_URL/timedeals/1" | jq '.data | {stock_quantity, reserved_quantity, sold_quantity}'

# 이미 취소된 주문 재취소
test_api "Cancel Order (Already Canceled)" "DELETE" "/orders/$ORDER_ID" "" 400 "$TOKEN"

# ========================================
# 결과 요약
# ========================================
echo "=========================================="
echo "🏁 E2E 테스트 결과"
echo "=========================================="
echo "✅ Passed: $PASSED"
echo "❌ Failed: $FAILED"
echo "=========================================="

if [ $FAILED -gt 0 ]; then
    echo "⚠️ 일부 테스트 실패!"
    exit 1
else
    echo "🎉 모든 테스트 통과!"
    exit 0
fi
```

### 🧪 테스트 실행

```bash
# 테스트 스크립트 실행
chmod +x scripts/e2e-test.sh
./scripts/e2e-test.sh

# 예상 출력
==========================================
🧪 뽀시레기 E2E 테스트 시작
==========================================
Base URL: https://api.bbossiregi.com/api/v1
==========================================
=== 1. 헬스체크 ===
Testing: Health Check... ✅ PASSED (HTTP 200)
{"success":true,"data":{"status":"healthy",...}}

=== 2. 인증 테스트 ===
Testing: Register (New User)... ✅ PASSED (HTTP 201)
...

==========================================
🏁 E2E 테스트 결과
==========================================
✅ Passed: 15
❌ Failed: 0
==========================================
🎉 모든 테스트 통과!
```

---

## D5-007: CloudWatch 모니터링 설정

### 📌 태스크 정보

| 항목 | 내용 |
|------|------|
| ID | D5-007 |
| 우선순위 | P2 |
| 담당 | 인프라 |
| 예상 시간 | 1시간 |

### 📋 체크리스트

```
[ ] Container Insights 활성화
[ ] 로그 그룹 설정
[ ] 대시보드 생성
[ ] 알람 설정 (선택)
```

### 📝 Container Insights 활성화

```bash
# CloudWatch Container Insights 설치
# FluentBit DaemonSet으로 로그 수집

# CloudWatch 에이전트 네임스페이스 생성
kubectl apply -f https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/cloudwatch-namespace.yaml

# CloudWatch 에이전트 ConfigMap
kubectl apply -f https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/cwagent-configmap.yaml

# FluentBit ConfigMap (클러스터 이름 수정 필요)
ClusterName=bbossiregi-eks
RegionName=ap-northeast-2
FluentBitHttpPort='2020'
FluentBitReadFromHead='Off'
[[ ${FluentBitReadFromHead} = 'On' ]] && FluentBitReadFromTail='Off'|| FluentBitReadFromTail='On'
[[ -z ${FluentBitHttpPort} ]] && FluentBitHttpServer='Off' || FluentBitHttpServer='On'

kubectl create configmap fluent-bit-cluster-info \
    --from-literal=cluster.name=${ClusterName} \
    --from-literal=http.server=${FluentBitHttpServer} \
    --from-literal=http.port=${FluentBitHttpPort} \
    --from-literal=read.head=${FluentBitReadFromHead} \
    --from-literal=read.tail=${FluentBitReadFromTail} \
    --from-literal=logs.region=${RegionName} -n amazon-cloudwatch

# FluentBit DaemonSet 배포
kubectl apply -f https://raw.githubusercontent.com/aws-samples/amazon-cloudwatch-container-insights/latest/k8s-deployment-manifest-templates/deployment-mode/daemonset/container-insights-monitoring/fluent-bit/fluent-bit.yaml
```

### 📝 CloudWatch 대시보드

```json
// cloudwatch-dashboard.json
{
  "widgets": [
    {
      "type": "metric",
      "x": 0,
      "y": 0,
      "width": 12,
      "height": 6,
      "properties": {
        "title": "Pod CPU Utilization",
        "metrics": [
          ["ContainerInsights", "pod_cpu_utilization", "ClusterName", "bbossiregi-eks", "Namespace", "bbossiregi", "PodName", "backend"]
        ],
        "view": "timeSeries",
        "region": "ap-northeast-2",
        "period": 60
      }
    },
    {
      "type": "metric",
      "x": 12,
      "y": 0,
      "width": 12,
      "height": 6,
      "properties": {
        "title": "Pod Memory Utilization",
        "metrics": [
          ["ContainerInsights", "pod_memory_utilization", "ClusterName", "bbossiregi-eks", "Namespace", "bbossiregi", "PodName", "backend"]
        ],
        "view": "timeSeries",
        "region": "ap-northeast-2",
        "period": 60
      }
    },
    {
      "type": "metric",
      "x": 0,
      "y": 6,
      "width": 12,
      "height": 6,
      "properties": {
        "title": "ALB Request Count",
        "metrics": [
          ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", "app/k8s-bbossire-backendi/xxxxx"]
        ],
        "view": "timeSeries",
        "region": "ap-northeast-2",
        "stat": "Sum",
        "period": 60
      }
    },
    {
      "type": "metric",
      "x": 12,
      "y": 6,
      "width": 12,
      "height": 6,
      "properties": {
        "title": "ALB Target Response Time",
        "metrics": [
          ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", "app/k8s-bbossire-backendi/xxxxx"]
        ],
        "view": "timeSeries",
        "region": "ap-northeast-2",
        "stat": "Average",
        "period": 60
      }
    },
    {
      "type": "metric",
      "x": 0,
      "y": 12,
      "width": 12,
      "height": 6,
      "properties": {
        "title": "RDS CPU Utilization",
        "metrics": [
          ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", "bbossiregi-db"]
        ],
        "view": "timeSeries",
        "region": "ap-northeast-2",
        "period": 60
      }
    },
    {
      "type": "metric",
      "x": 12,
      "y": 12,
      "width": 12,
      "height": 6,
      "properties": {
        "title": "RDS Database Connections",
        "metrics": [
          ["AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", "bbossiregi-db"]
        ],
        "view": "timeSeries",
        "region": "ap-northeast-2",
        "period": 60
      }
    }
  ]
}
```

### 📝 알람 설정 (Terraform)

```hcl
# terraform/modules/monitoring/alarms.tf

# 높은 CPU 사용률 알람
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "${var.project_name}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "pod_cpu_utilization"
  namespace           = "ContainerInsights"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "CPU utilization is above 80%"

  dimensions = {
    ClusterName = "${var.project_name}-eks"
    Namespace   = var.project_name
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

# 5xx 에러 알람
resource "aws_cloudwatch_metric_alarm" "alb_5xx_errors" {
  alarm_name          = "${var.project_name}-alb-5xx"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "ALB 5xx errors exceeded threshold"

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }

  alarm_actions = [aws_sns_topic.alerts.arn]

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

# SNS Topic
resource "aws_sns_topic" "alerts" {
  name = "${var.project_name}-alerts"
}

# 이메일 구독 (수동으로 확인 필요)
resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}
```

---

## D5-008: 문서화

### 📌 태스크 정보

| 항목 | 내용 |
|------|------|
| ID | D5-008 |
| 우선순위 | P1 |
| 담당 | 전체 |
| 예상 시간 | 30분 |

### 📝 README.md 업데이트

```markdown
# 🐾 뽀시레기 (BBossiregi)

> 반려동물 타임딜 이커머스 플랫폼

## 📋 프로젝트 개요

뽀시레기는 반려동물 용품을 타임딜 방식으로 판매하는 이커머스 플랫폼입니다.
사가 패턴을 활용한 분산 트랜잭션으로 재고 정합성을 보장합니다.

### 주요 기능

- 🔐 **사용자 인증**: JWT 기반 회원가입/로그인
- 🛒 **타임딜**: 시간 제한 특가 상품 판매
- 📦 **주문 관리**: 사가 패턴 기반 주문 처리
- 📊 **재고 관리**: 비관적 락을 통한 동시성 제어

## 🏗 아키텍처

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Client    │───▶│     ALB     │───▶│     EKS     │
└─────────────┘    └─────────────┘    └──────┬──────┘
                                              │
                                              ▼
                                       ┌─────────────┐
                                       │     RDS     │
                                       │ (PostgreSQL)│
                                       └─────────────┘
```

## 🛠 기술 스택

### Backend
- **Language**: Go 1.22
- **Framework**: Gin
- **Database**: PostgreSQL 15
- **ORM**: database/sql + Raw SQL

### Infrastructure
- **Cloud**: AWS (EKS, RDS, ALB, ECR)
- **IaC**: Terraform
- **Container**: Docker, Kubernetes
- **CI/CD**: GitHub Actions

## 🚀 시작하기

### 사전 요구사항

- Go 1.22+
- Docker
- kubectl
- AWS CLI
- Terraform 1.5+

### 로컬 개발

```bash
# 레포지토리 클론
git clone https://github.com/your-org/bbossiregi.git
cd bbossiregi

# 환경변수 설정
cp backend/.env.example backend/.env
# .env 파일 편집

# 의존성 설치
cd backend
go mod download

# 로컬 실행
make run
```

### 배포

```bash
# 배포 스크립트 실행
./scripts/deploy.sh
```

## 📡 API 엔드포인트

| Method | Endpoint | 설명 | 인증 |
|--------|----------|------|------|
| GET | /api/v1/health | 헬스체크 | ❌ |
| POST | /api/v1/auth/register | 회원가입 | ❌ |
| POST | /api/v1/auth/login | 로그인 | ❌ |
| GET | /api/v1/timedeals | 타임딜 목록 | ❌ |
| GET | /api/v1/timedeals/:id | 타임딜 상세 | ❌ |
| POST | /api/v1/orders | 주문 생성 | ✅ |
| GET | /api/v1/orders | 주문 목록 | ✅ |
| GET | /api/v1/orders/:id | 주문 상세 | ✅ |
| DELETE | /api/v1/orders/:id | 주문 취소 | ✅ |

## 📁 프로젝트 구조

```
bbossiregi/
├── backend/           # Go 백엔드
│   ├── cmd/           # 엔트리포인트
│   ├── internal/      # 내부 패키지
│   └── migrations/    # DB 마이그레이션
├── terraform/         # IaC
├── k8s/               # Kubernetes 매니페스트
├── scripts/           # 배포 스크립트
└── docs/              # 문서
```

## 👥 팀

- 이나형 - 팀장 / 인프라
- 박지훈 - 백엔드
- 박규원 - 백엔드
- 서주원 - 백엔드

## 📄 라이선스

MIT License
```

---

## D5-009: 스프린트 회고

### 📌 태스크 정보

| 항목 | 내용 |
|------|------|
| ID | D5-009 |
| 우선순위 | P0 |
| 담당 | 전체 |
| 예상 시간 | 1시간 |

### 📋 회고 아젠다

```
1. Sprint 1 목표 달성 현황 검토 (10분)
2. 잘한 점 (Keep) 공유 (15분)
3. 개선할 점 (Problem) 공유 (15분)
4. 시도할 것 (Try) 논의 (15분)
5. Sprint 2 계획 미리보기 (5분)
```

### 📝 회고 템플릿

```markdown
# 🔄 Sprint 1 회고록

## 📅 기간
2026.02.24 (월) ~ 02.28 (금)

## 🎯 목표 달성 현황

### 완료된 항목 ✅
- [ ] AWS 인프라 구축 (VPC, RDS, EKS)
- [ ] 백엔드 API 개발 (인증, 타임딜, 주문)
- [ ] 사가 패턴 구현 (재고 예약/해제)
- [ ] 컨테이너화 및 배포
- [ ] HTTPS 설정

### 미완료 항목 ❌
- (있다면 기재)

## 💚 Keep (잘한 점)

### 기술적
- 

### 협업
- 

## 💔 Problem (개선할 점)

### 기술적
- 

### 협업
- 

## 💡 Try (시도할 것)

### Sprint 2에서 시도
- 

## 📊 수치 지표

| 지표 | 목표 | 달성 |
|------|------|------|
| 계획된 태스크 | 30개 | ?개 |
| 완료된 태스크 | 30개 | ?개 |
| 버그 발생 | 0개 | ?개 |
| E2E 테스트 통과율 | 100% | ?% |

## 🗓 Sprint 2 미리보기

1. 프론트엔드 개발 시작
2. 결제 모듈 연동
3. 실시간 재고 알림
4. 성능 테스트 및 최적화
5. 관리자 대시보드

## 📝 개인별 한마디

### 이나형 (인프라)
> 

### 박지훈 (백엔드)
> 

### 박규원 (백엔드)
> 

### 서주원 (백엔드)
> 
```

---

## D5-010: Day 5 완료 체크리스트

### 📋 최종 완료 기준

```
[ ] ALB Ingress Controller 설치 완료
[ ] ACM 인증서 발급 완료
[ ] Route53 DNS 설정 완료
[ ] HTTPS 접속 가능
[ ] 최종 이미지 ECR 푸시 완료
[ ] EKS 배포 완료 (Pod Running)
[ ] E2E 테스트 전체 통과
[ ] CloudWatch 로그 수집 확인
[ ] README.md 업데이트 완료
[ ] 스프린트 회고 완료
```

### 🧪 최종 검증

```bash
# 1. 서비스 상태 확인
kubectl get all -n bbossiregi

# 예상 출력
NAME                           READY   STATUS    RESTARTS   AGE
pod/backend-xxx-xxx            1/1     Running   0          1h
pod/backend-xxx-yyy            1/1     Running   0          1h

NAME                      TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
service/backend-service   ClusterIP   172.20.xxx.xxx  <none>        80/TCP    1h

NAME                      READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/backend   2/2     2            2           1h

# 2. HTTPS 헬스체크
curl https://api.bbossiregi.com/api/v1/health

# 3. E2E 테스트
./scripts/e2e-test.sh

# 4. 로그 확인
kubectl logs -f deployment/backend -n bbossiregi --tail=100
```

---

# 🎉 Sprint 1 완료!

## 📊 Sprint 1 달성 요약

| 카테고리 | 항목 | 상태 |
|---------|------|------|
| **인프라** | VPC + 서브넷 + NAT | ✅ |
| | RDS PostgreSQL | ✅ |
| | EKS 클러스터 | ✅ |
| | ALB + HTTPS | ✅ |
| | Route53 DNS | ✅ |
| **백엔드** | 인증 API | ✅ |
| | 타임딜 API | ✅ |
| | 주문 API (사가 패턴) | ✅ |
| | 재고 관리 (동시성) | ✅ |
| **DevOps** | Dockerfile | ✅ |
| | K8s 매니페스트 | ✅ |
| | CI/CD 파이프라인 | ✅ |
| **문서화** | API 명세 | ✅ |
| | README | ✅ |
| | 회고록 | ✅ |

## 🔜 Sprint 2 예고

```
Week 2: 프론트엔드 + 고급 기능

Day 6-7: React 프론트엔드 개발
- 타임딜 목록/상세 페이지
- 로그인/회원가입
- 주문하기

Day 8-9: 고급 기능
- 실시간 재고 (WebSocket)
- 결제 모듈 연동
- 알림 기능

Day 10: 성능 테스트 + 최적화
- 부하 테스트 (k6)
- 쿼리 최적화
- 캐싱 (Redis)
```

---

# 🐾 뽀시레기 Sprint 1 완료! 수고하셨습니다! 🎊