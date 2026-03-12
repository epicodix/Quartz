## 오늘 실습 명령어 전체 정리 (검증 포함)

### 1단계: 환경 확인

```bash
# Terraform 설치 확인
terraform version

# AWS CLI 설정 확인
aws configure list
aws configure list --profile default

# AWS 계정 확인 (어느 계정으로 배포되는지)
aws sts get-caller-identity

# 기존 키페어 확인
aws ec2 describe-key-pairs --query 'KeyPairs[*].KeyName' --output table
```

---

### 2단계: 프로젝트 폴더 생성

```bash
# 폴더 생성
mkdir -p ~/terraform-ec2-test
cd ~/terraform-ec2-test

# 하위 폴더 생성
mkdir -p app load-test

# 생성 확인
ls -la
```

---

### 3단계: Terraform 파일 작성 후 검증

```bash
cd ~/terraform-ec2-test

# 파일 목록 확인
ls -la

# 각 파일 내용 확인
cat variables.tf
cat main.tf
cat outputs.tf
cat providers.tf
cat user_data.sh
cat app/package.json
cat app/app.js
cat app/Dockerfile
cat load-test/k6-script.js
```

---

### 4단계: Terraform 초기화

```bash
cd ~/terraform-ec2-test

# 프로바이더 다운로드 (aws, tls)
terraform init

# 초기화 결과 확인 (.terraform 폴더 생성됨)
ls -la
ls -la .terraform/providers/
```

---

### 5단계: 문법 검증

```bash
# 문법 오류 체크
terraform validate

# 성공 시 출력:
# Success! The configuration is valid.
```

---

### 6단계: 배포 계획 확인

```bash
# 어떤 리소스가 생성되는지 미리 확인
terraform plan

# 특정 프로필로 실행 (계정 지정)
AWS_PROFILE=default terraform plan
```

---

### 7단계: 인프라 배포

```bash
# 배포 실행 (확인 프롬프트 있음)
terraform apply

# 자동 승인으로 배포 (프롬프트 없이)
terraform apply -auto-approve

# 특정 프로필로 배포
AWS_PROFILE=default terraform apply -auto-approve
```

---

### 8단계: 배포 결과 확인

```bash
# 전체 출력값 확인
terraform output

# 개별 출력값 확인
terraform output public_ip
terraform output -raw public_ip
terraform output ssh_command
terraform output access_url
terraform output backend_url

# 생성된 리소스 상태 확인
terraform show

# 생성된 키 파일 확인
ls -la *.pem
cat time-deal-test-key.pem | head -5
```

---

### 9단계: 서버 부팅 대기 및 헬스체크

```bash
# EC2 IP 변수로 저장
EC2_IP=$(terraform output -raw public_ip)
echo $EC2_IP

# 서버 준비될 때까지 반복 체크 (user_data 실행 완료까지 5~8분)
for i in 1 2 3 4 5 6 7 8 9 10; do
  echo "=== 시도 $i ==="
  curl -s --max-time 5 http://$EC2_IP:8080/api/health && break
  echo "아직 빌드 중... 60초 대기"
  sleep 60
done

# 단일 헬스체크
curl http://$EC2_IP:8080/api/health

# 상품 조회 테스트
curl http://$EC2_IP:8080/api/products/1

# JSON 예쁘게 출력
curl -s http://$EC2_IP:8080/api/products/1 | python3 -m json.tool
```

---

### 10단계: SSH 접속 및 서버 내부 확인

```bash
# SSH 접속
ssh -i time-deal-test-key.pem -o StrictHostKeyChecking=no ec2-user@$EC2_IP

# === EC2 내부에서 실행 ===

# 컨테이너 상태 확인
docker compose ps
docker compose -f /home/ec2-user/app/docker-compose.yml ps

# 컨테이너 로그 확인
docker compose logs
docker compose logs backend
docker compose logs backend --tail 50
docker compose logs mysql --tail 20

# user_data 실행 로그 확인 (부팅 스크립트)
sudo cat /var/log/user-data.log

# 시스템 리소스 확인
free -h          # 메모리
df -h            # 디스크
top -bn1 | head  # CPU

# OS TCP 설정 확인
cat /proc/sys/net/core/somaxconn
cat /proc/sys/net/ipv4/tcp_max_syn_backlog

# 네트워크 연결 상태
ss -tan | awk '{print $1}' | sort | uniq -c

# Docker 리소스 사용량 실시간
docker stats --no-stream

# EC2에서 나가기
exit
```

---

### 11단계: MySQL 데이터 확인

```bash
# EC2 접속 후 MySQL 쿼리 실행
ssh -i time-deal-test-key.pem ec2-user@$EC2_IP

# MySQL 컨테이너 접속
docker exec -it app-mysql-1 mysql -uroot -proot1234

# MySQL 내부에서 실행
USE timedeal;
SHOW TABLES;
SELECT COUNT(*) FROM orders;
SELECT * FROM orders LIMIT 10;
SHOW STATUS LIKE 'Max_used_connections';
SHOW STATUS LIKE 'Threads_connected';
exit;

# 또는 한 줄로 실행
docker exec app-mysql-1 mysql -uroot -proot1234 -e "SELECT COUNT(*) FROM timedeal.orders;"
docker exec app-mysql-1 mysql -uroot -proot1234 -e "SHOW STATUS LIKE 'Max_used_connections';"
```

---

### 12단계: Redis 데이터 확인

```bash
# EC2 접속 후
ssh -i time-deal-test-key.pem ec2-user@$EC2_IP

# Redis 재고 확인
docker exec app-redis-1 redis-cli GET stock:1

# Redis 메모리 사용량
docker exec app-redis-1 redis-cli INFO memory | grep used_memory_human

# 또는 로컬에서 직접
ssh -i time-deal-test-key.pem ec2-user@$EC2_IP "docker exec app-redis-1 redis-cli GET stock:1"
```

---

### 13단계: 재고 리셋

```bash
# 재고 1000개로 리셋
curl -X POST http://$EC2_IP:8080/api/admin/reset-stock \
  -H 'Content-Type: application/json' \
  -d '{"stock": 1000}'

# 리셋 확인
curl http://$EC2_IP:8080/api/products/1
```

---

### 14단계: k6 부하 테스트

```bash
# k6 설치 (Mac)
brew install k6

# 설치 확인
k6 version

# 기본 테스트 (점진적 증가)
cd ~/terraform-ec2-test
k6 run -e BASE_URL=http://$EC2_IP:8080 load-test/k6-script.js

# 스파이크 테스트 (갑작스런 폭주)
k6 run -e BASE_URL=http://$EC2_IP:8080 -e SCENARIO=spike load-test/k6-script.js

# 정상 부하 테스트 (p95 측정)
k6 run -e BASE_URL=http://$EC2_IP:8080 -e SCENARIO=steady load-test/k6-script.js

# 결과를 JSON으로 저장
k6 run -e BASE_URL=http://$EC2_IP:8080 --out json=results.json load-test/k6-script.js
```

---

### 15단계: 부하 테스트 중 실시간 모니터링

```bash
# 터미널 1: k6 실행
k6 run -e BASE_URL=http://$EC2_IP:8080 load-test/k6-script.js

# 터미널 2: EC2 접속해서 실시간 모니터링
ssh -i time-deal-test-key.pem ec2-user@$EC2_IP

# Docker 리소스 실시간
watch -n 1 'docker stats --no-stream'

# 연결 수 실시간
watch -n 1 'ss -tan state established | wc -l'

# 백엔드 로그 실시간
docker compose logs -f backend
```

---

### 16단계: 부하 테스트 후 결과 검증

```bash
# 주문 건수 확인 (1000개여야 정상)
ssh -i time-deal-test-key.pem ec2-user@$EC2_IP \
  "docker exec app-mysql-1 mysql -uroot -proot1234 -e 'SELECT COUNT(*) FROM timedeal.orders;'"

# Redis 재고 확인 (0이어야 정상)
ssh -i time-deal-test-key.pem ec2-user@$EC2_IP \
  "docker exec app-redis-1 redis-cli GET stock:1"

# MySQL 최대 커넥션 사용량
ssh -i time-deal-test-key.pem ec2-user@$EC2_IP \
  "docker exec app-mysql-1 mysql -uroot -proot1234 -e \"SHOW STATUS LIKE 'Max_used_connections';\""

# 백엔드 에러 로그 확인
ssh -i time-deal-test-key.pem ec2-user@$EC2_IP \
  "docker compose -f /home/ec2-user/app/docker-compose.yml logs backend 2>&1 | grep -i error | tail -20"
```

---

### 17단계: 앱 튜닝 후 재배포

```bash
# EC2 접속
ssh -i time-deal-test-key.pem ec2-user@$EC2_IP

# app.js 수정 (connectionLimit 등)
sudo vi /home/ec2-user/app/backend/app.js

# 또는 로컬에서 직접 덮어쓰기
ssh -i time-deal-test-key.pem ec2-user@$EC2_IP "sudo tee /home/ec2-user/app/backend/app.js > /dev/null << 'EOF'
... 새 코드 ...
EOF"

# 재빌드 및 재시작
cd /home/ec2-user/app
docker compose up -d --build

# 재시작 확인
docker compose ps
docker compose logs backend --tail 10

# 헬스체크
curl http://localhost:8080/api/health
```

---

### 18단계: CloudWatch 메트릭 확인 (AWS CLI)

```bash
# 인스턴스 ID 확인
INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=time-deal-test-server" \
  --query 'Reservations[0].Instances[0].InstanceId' \
  --output text)
echo $INSTANCE_ID

# CPU 사용률 조회 (최근 1시간)
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions Name=InstanceId,Value=$INSTANCE_ID \
  --start-time $(date -u -v-1H +%Y-%m-%dT%H:%M:%SZ) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --period 60 \
  --statistics Average Maximum

# 네트워크 In/Out
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name NetworkIn \
  --dimensions Name=InstanceId,Value=$INSTANCE_ID \
  --start-time $(date -u -v-1H +%Y-%m-%dT%H:%M:%SZ) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --period 60 \
  --statistics Sum
```

---

### 19단계: 리소스 정리 (필수!)

```bash
cd ~/terraform-ec2-test

# 삭제 전 리소스 확인
terraform show | head -50

# 리소스 삭제 (확인 프롬프트)
terraform destroy

# 자동 승인으로 삭제
terraform destroy -auto-approve

# 삭제 완료 확인
terraform show
# (아무것도 출력 안 되면 성공)

# AWS 콘솔에서도 확인
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=time-deal-test-server" \
  --query 'Reservations[*].Instances[*].[InstanceId,State.Name]'
```

---

### 요약: 전체 플로우

```
1. 환경 확인     terraform version / aws sts get-caller-identity
2. 폴더 생성     mkdir -p ~/terraform-ec2-test
3. 파일 작성     cat 으로 확인
4. 초기화        terraform init
5. 검증          terraform validate
6. 계획          terraform plan
7. 배포          terraform apply
8. 출력 확인     terraform output
9. 헬스체크      curl /api/health
10. SSH 접속     ssh -i *.pem ec2-user@IP
11. 컨테이너     docker compose ps/logs
12. MySQL        docker exec mysql ...
13. Redis        docker exec redis-cli ...
14. 재고 리셋    curl -X POST /api/admin/reset-stock
15. 부하 테스트  k6 run ...
16. 결과 검증    SELECT COUNT(*) / GET stock:1
17. 튜닝         vi app.js → docker compose up --build
18. CloudWatch   aws cloudwatch get-metric-statistics
19. 삭제         terraform destroy
```

---

이 정도면 빠짐없이 정리된 것 같아요. 추가로 빠진 거 있어요?