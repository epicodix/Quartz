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

## 롤백 방법

```bash
# 전체 인프라 삭제 (과금 방지)
terraform destroy

# 특정 리소스만 삭제
terraform destroy -target=aws_db_instance.postgres
terraform destroy -target=aws_elasticache_cluster.redis
```

> [!danger] destroy 전 RDS 스냅샷 필요 시 skip_final_snapshot = false 로 변경
