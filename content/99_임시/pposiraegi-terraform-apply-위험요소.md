---
title: Terraform Apply 전 위험요소 & 체크리스트
tags:
  - terraform
  - aws
  - pposiraegi
  - infra
date: 2026-03-11
status: 진행중
---

# 🚨 Terraform Apply 전 위험요소 & 체크리스트

> apply 전에 이 문서 한 번 읽고 GO

---

## 1. docker-compose depends_on 문제 (높음)

**상황**: `docker-compose.yml`에서 backend가 db/redis에 `depends_on` 걸려 있음

```yaml
# docker-compose.yml (원본)
backend:
  depends_on:
    db:
      condition: service_healthy
    redis:
      condition: service_healthy
```

**문제**: override에서 db/redis를 `profiles: ["local"]`로 비활성화하면, backend가 이 서비스들의 healthcheck를 기다리다 실패할 수 있음

**해결책**:
- `docker-compose up -d backend` 대신 전체 up 후 확인하거나
- override에 `depends_on: {}` 추가해서 의존성 제거

> [!warning] apply 후 EC2 SSH 접속해서 직접 확인 필수
> `docker-compose ps` 로 backend 컨테이너 상태 체크

---

## 2. tfstate 로컬 관리 (중간)

**상황**: tfstate가 로컬에만 있음 (`*.tfstate` gitignore됨)

**문제**:
- 팀원이 apply하면 state 충돌
- 로컬 PC 날아가면 state 유실 → `terraform import` 지옥

**지금은 괜찮지만**: apply 시 누가 할지 팀 내 합의 필요

> [!note] 나중에 S3 backend + DynamoDB locking 붙이면 해결

---

## 3. RDS 초기 스키마 (중간)

**상황**: `application.yaml` 기준 `ddl-auto: update`

**흐름**:
- 첫 기동 시 빈 RDS DB에 JPA가 스키마 자동 생성
- `update`라 데이터 날아가진 않지만 컬럼 삭제는 반영 안 됨

**확인사항**: `application-prod.yaml` 파일이 없음 → `application.yaml` 기본값 사용
- `ddl-auto: update` ✅ (create가 아니라서 재시작해도 데이터 유지)

> [!tip] 나중에 Flyway 붙이면 마이그레이션 이력 관리 가능

---

## 4. EC2 부팅 후 앱 기동까지 시간 (낮음)

**상황**: user_data에서 git clone → gradle 빌드 → docker build 순서

**예상 소요시간**:
```
Docker 설치         : ~1분
git clone           : ~30초
gradle 빌드 (캐시 없음): ~5분
docker build        : ~2분
────────────────────
총합                : 약 8~10분
```

**문제**: ALB 헬스체크가 `/v3/api-docs`로 날아오는데 앱 뜨기 전까지 unhealthy 상태
- 503 뜨는 기간이 있음 (정상)

> [!info] `/var/log/user-data.log` 로 진행상황 확인 가능
> `ssh ec2-user@<IP> "sudo tail -f /var/log/user-data.log"`

---

## 5. Redis application.yaml 포트 (낮음)

**상황**: `application.yaml`에 Redis 포트가 `16379` (로컬 개발용 비표준 포트)

```yaml
data:
  redis:
    port: 16379  # ← 이거
```

**해결**: docker-compose.override.yml에서 `SPRING_DATA_REDIS_PORT: "6379"` env 주입하므로 override됨 ✅

---

## 6. db_password tfvars 누락 (높음)

**apply 전 terraform.tfvars에 반드시 추가**:
```hcl
db_password = "강력한_비밀번호_여기에"
```

없으면 terraform이 interactive prompt로 물어봄 (CI/CD 환경에서 hang)

---

## 7. ElastiCache parameter group (낮음)

**상황**: `default.redis7` 사용

- ap-southeast-2 리전에서 redis7 지원 확인 필요
- 안 되면 `default.redis6.x` 로 변경

---

## apply 순서 및 체크리스트

### apply 전
- [ ] `terraform.tfvars`에 `db_password` 추가
- [ ] `terraform validate` 통과 확인
- [ ] `terraform plan` 출력 검토 (신규 리소스 수 확인)
- [ ] 현재 ip 확인해서 `my_ip` 맞는지 체크 (`curl ifconfig.me`)

### apply 중 (약 15분 소요)
```
aws_vpc, subnets, igw, security_groups  : 즉시
aws_elasticache_cluster                 : ~10분
aws_db_instance                         : ~5분
aws_instance (EC2)                      : RDS/ElastiCache 완료 후
aws_lb, cloudfront                      : 병렬
```

### apply 후 확인
- [ ] `terraform output` 으로 엔드포인트 확인
- [ ] EC2 SSH 접속: `ssh -i ~/.ssh/id_ed25519 ec2-user@<backend_public_ip>`
- [ ] 부팅 로그 확인: `sudo tail -f /var/log/user-data.log`
- [ ] docker-compose 상태: `cd ~/app && docker-compose ps`
- [ ] 백엔드 응답: `curl http://localhost:8080/v3/api-docs`
- [ ] ALB 헬스체크 통과 여부 AWS 콘솔 확인

---

## 8. 실제 배포 장애 기록 (2026-03-19)

### 8-1. prod 프로파일 ddl-auto: validate + 빈 RDS (높음)

**상황**: `application-prod.yaml`에 `ddl-auto: validate`로 설정되어 있음

**문제**: EC2 user_data.sh가 RDS에 스키마를 생성하지 않고 앱을 바로 기동 → RDS가 비어있으면 앱이 즉시 종료

```
SchemaManagementException: Schema validation: missing table [categories]
```

**근본 원인**: user_data.sh에 스키마 초기화 로직 없음. prod 첫 배포 시 RDS는 항상 비어있음

**해결책**:
- docker-compose.prod.yml 오버라이드에 `SPRING_JPA_HIBERNATE_DDL_AUTO: update` 주입
- 또는 Flyway 도입으로 마이그레이션 관리

> [!danger] validate 상태에서 배포하면 컨테이너가 즉시 Exited(1) 됨. apply 후 반드시 확인

---

### 8-2. docker-compose.yml 환경변수 하드코딩 (높음)

**상황**: git에 올라간 `docker-compose.yml`이 DB/Redis를 하드코딩

```yaml
# docker-compose.yml (문제)
backend:
  environment:
    SPRING_DATASOURCE_URL: jdbc:postgresql://db:5432/ecommerce  # 로컬 컨테이너
    SPRING_DATA_REDIS_HOST: redis                               # 로컬 컨테이너
```

**문제**: `.env` 파일이나 shell 환경변수로 오버라이드 불가. RDS/ElastiCache 연결 안 됨

**해결책**: `docker-compose.prod.yml` 오버라이드 파일로 배포 시 환경변수 덮어쓰기

```bash
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d backend
```

> [!warning] user_data.sh의 `.env` 생성은 `backend/` 하위에 생성하지만 docker-compose가 읽는 위치는 `app/` 루트임 → 적용 안 됨

---

### 8-3. Redis AUTH 에러 (ElastiCache 무인증) (중간)

**상황**: ElastiCache Redis를 비밀번호 없이 구성 (`auth-token` 미설정)

**문제**: `SPRING_DATA_REDIS_PASSWORD=''` (빈 문자열)로 설정해도 Redisson이 AUTH 명령 전송

```
ERR AUTH <password> called without any password configured for the default user
```

**해결책**: docker-compose.prod.yml에서 `SPRING_DATA_REDIS_PASSWORD` 항목 자체를 제거 (키 없음 = AUTH 안 보냄)

> [!tip] ElastiCache 무인증 구성 시 반드시 password 환경변수를 아예 빼야 함. 빈 문자열도 AUTH 전송됨

---

### 8-4. Hibernate 7 enum 타입 매핑 변경 (중간)

**상황**: `@Enumerated` 어노테이션 없는 enum 필드가 Hibernate 7에서 `TINYINT`(ordinal) 기대

**영향 테이블**: `orders.status`, `order_items.status`, `shipments.status`

```
SchemaManagementException: wrong column type encountered in column [status] in table [order_items];
found [varchar (Types#VARCHAR)], but expecting [smallint (Types#TINYINT)]
```

**해결책**: 해당 enum 필드에 `@Enumerated(EnumType.STRING)` 추가하거나, DB 컬럼을 `SMALLINT`으로 생성

> [!note] Hibernate 7(Spring Boot 4) 업그레이드 시 `@Enumerated` 없는 enum 전수 검사 필요

---

### 8-5. @Embeddable 컬럼명 충돌 (낮음)

**상황**: `Shipments` 엔티티의 `PhoneNumber` 임베디드 필드에 `@Embedded` + `@AttributeOverride` 없이 `@Column(name="receiver_phone")` 만 선언

**문제**: Hibernate가 실제로 사용하는 컬럼명은 `PhoneNumber` 클래스 내부의 `@Column(name="phone_number")`

```
SchemaManagementException: missing column [phone_number] in table [shipments]
```

**해결책**: `@Embedded` + `@AttributeOverride`로 명시적 컬럼명 지정 권장

---

## 롤백 방법

```bash
# 전체 인프라 삭제 (과금 방지)
terraform destroy

# 특정 리소스만 삭제
terraform destroy -target=aws_db_instance.postgres
terraform destroy -target=aws_elasticache_cluster.redis
```

> [!danger] destroy 전 RDS 스냅샷 필요 시 skip_final_snapshot = false 로 변경
