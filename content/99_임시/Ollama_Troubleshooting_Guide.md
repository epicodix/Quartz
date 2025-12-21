# Ollama AI 서버 외부 접근 및 `curl` 테스트 문제 해결 가이드

이 문서는 Ollama AI 서버를 로컬 및 외부에서 테스트하는 과정에서 발생할 수 있는 일반적인 문제들과 그 해결 방법을 상세히 설명합니다. 특히 `curl` 명령어의 JSON 파싱 문제와 `ngrok`을 통한 외부 접근 시 발생하는 `403 Forbidden` 오류에 초점을 맞춥니다.

---

## 1. `curl` 명령어 JSON 파싱 문제 해결

`curl` 명령어를 사용하여 JSON 데이터를 포함한 POST 요청을 보낼 때, 셸(특히 Zsh)이 JSON 문자열을 올바르게 해석하지 못하여 `curl: option -d: requires parameter` 또는 `zsh: command not found`와 같은 오류가 발생할 수 있습니다. 이는 JSON 내의 줄 바꿈이나 특수 문자, 따옴표 처리 방식 때문에 발생합니다.

### 문제 상황 예시

```bash
curl http://localhost:11434/api/generate -d
     '{
          "model": "llama3",
          "prompt": "대한민국의 수도는 어디야?",
          "stream": false
        }'
# 또는
curl https://your-ngrok-url/api/generate -d
     '{"model": "llama3", "prompt": "대한민국의 수도는 어디야?",
     "stream": false}'
```

### 해결 방법: `printf`와 `curl -d @-` 조합 사용

가장 확실한 해결책은 `printf` 명령어를 사용하여 JSON 문자열을 정확하게 출력하고, 이를 파이프(`|`)를 통해 `curl` 명령어로 전달하는 것입니다. `curl -d @-` 옵션은 표준 입력(`-`)에서 요청 본문 데이터를 읽어오도록 지시합니다.

```bash
printf '{"model": "llama3", "prompt": "대한민국의 수도는 어디야?", "stream": false}' | \
curl -X POST http://localhost:11434/api/generate \
     -H "Content-Type: application/json" \
     -d @-
```

**설명:**
*   `printf '...'`: JSON 데이터를 정확히 한 줄 문자열로 출력합니다.
*   `|`: `printf`의 출력을 `curl`의 입력으로 전달합니다.
*   `curl -X POST ...`: POST 요청임을 명시합니다.
*   `-H "Content-Type: application/json"`: 요청 헤더에 JSON 타입임을 명시합니다.
*   `-d @-`: 표준 입력에서 데이터를 읽어 요청 본문으로 사용합니다.

이 방법을 사용하면 셸의 JSON 파싱 문제를 우회하고 안정적으로 API 요청을 보낼 수 있습니다.

---

## 2. `ngrok` 인증 오류 해결 (`ERR_NGROK_4018`)

`ngrok`은 무료 플랜에서도 사용을 위해 계정 생성 및 인증 토큰(authtoken) 등록을 필수로 요구합니다. 이 과정이 누락되면 `authentication failed: Usage of ngrok requires a verified account and authtoken` 오류가 발생합니다.

### 문제 상황 예시

```
ERROR:  authentication failed: Usage of ngrok requires a verified account and authtoken.
ERROR:  Sign up for an account: https://dashboard.ngrok.com/signup
ERROR:  Install your authtoken: https://dashboard.ngrok.com/get-started/your-authtoken
ERROR:  ERR_NGROK_4018
```

### 해결 방법: `ngrok config add-authtoken`

1.  **ngrok 계정 생성:** 아직 계정이 없다면 [ngrok 웹사이트](https://dashboard.ngrok.com/signup)에서 계정을 생성합니다.
2.  **Authtoken 확인:** 로그인 후 [대시보드](https://dashboard.ngrok.com/get-started/your-authtoken)에서 본인의 인증 토큰을 복사합니다.
3.  **Authtoken 등록:** 터미널에서 다음 명령어를 실행하여 토큰을 등록합니다. `<YOUR_AUTHTOKEN>` 부분을 복사한 실제 토큰으로 바꿔줍니다.

    ```bash
    ngrok config add-authtoken <YOUR_AUTHTOKEN>
    ```

    성공적으로 등록되면 `Authtoken saved to configuration file: ...` 메시지가 출력됩니다.

---

## 3. `ngrok` 403 Forbidden 및 Ollama 서버 바인딩/Origin 문제 해결

`ngrok`을 통해 Ollama 서버에 접근할 때 `403 Forbidden` 오류가 발생하는 경우가 있습니다. 이는 주로 Ollama 서버의 네트워크 설정 또는 `Origin` 헤더 처리 문제 때문에 발생합니다.

### 문제 상황 예시

`ngrok` 웹 인터페이스(`http://localhost:4040`)에서 `POST /api/generate` 요청에 대해 `403 Forbidden` 응답이 기록됩니다.

### 해결 방법: Ollama 서버 환경 변수 설정

Ollama는 기본적으로 `localhost`에서의 요청만 허용하거나, 특정 `Origin` 헤더를 가진 요청만 허용합니다. `ngrok`을 통한 요청을 허용하려면 다음 환경 변수를 설정하여 Ollama 서버를 시작해야 합니다.

1.  **기존 Ollama 프로세스 종료:**
    ```bash
pkill -f ollama
    ```

2.  **Ollama 서버 재시작 (외부 접속 및 모든 Origin 허용):**
    `OLLAMA_HOST`를 `http://0.0.0.0:11434`로 명시하고, `OLLAMA_ORIGINS`를 `*`로 설정하여 모든 네트워크 인터페이스 및 모든 `Origin`에서의 요청을 허용합니다.

    ```bash
    OLLAMA_HOST=http://0.0.0.0:11434 OLLAMA_ORIGINS=* /Applications/Ollama.app/Contents/Resources/ollama serve &
    ```

    **설명:**
    *   `OLLAMA_HOST=http://0.0.0.0:11434`: Ollama 서버가 모든 네트워크 인터페이스(`0.0.0.0`)의 11434 포트에서 HTTP 요청을 수신하도록 명시적으로 설정합니다. 프로토콜(`http://`)과 포트까지 명시하는 것이 중요합니다.
    *   `OLLAMA_ORIGINS=*`: 모든 `Origin` 헤더를 가진 요청을 허용합니다. 이는 `ngrok`과 같은 터널링 서비스를 통해 들어오는 요청의 `Origin`이 다양할 수 있으므로 테스트 목적으로 유용합니다. (보안상 실제 운영 환경에서는 특정 Origin만 허용하는 것이 좋습니다.)

이 설정을 적용한 후 `ngrok` 터널을 통해 다시 테스트하면 `403 Forbidden` 오류가 해결되고 정상적인 응답을 받을 수 있습니다.

---

## 결론

`curl` 명령어의 셸 파싱 문제와 Ollama 서버의 네트워크/Origin 설정 문제는 외부에서 AI 서버에 접근하려는 시도에서 흔히 발생할 수 있습니다. 이 가이드에서 제시된 해결책들을 통해 이러한 문제들을 극복하고 Ollama AI 서버를 성공적으로 활용할 수 있기를 바랍니다.
