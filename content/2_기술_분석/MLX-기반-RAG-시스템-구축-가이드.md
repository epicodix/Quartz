---
title: MLX 기반 RAG 시스템 구축 완전 가이드
tags:
  - MLX
  - RAG
  - Ollama
  - LLM
  - Apple-Silicon
  - Python
  - Go
  - ChromaDB
  - architecture
aliases:
  - MLX RAG 가이드
  - Apple Silicon LLM
date: 2026-02-15
category: 2_기술_분석/AI
status: 완성
priority: 높음
---

# 🎯 MLX 기반 RAG 시스템 구축 완전 가이드

> [!note] 시리즈
> [[AI-에이전트-RAG-시스템-상세설계|1편: 전체 아키텍처 + MVP 설계]]
> **2편: MLX 런타임 + Go 연동 + 메모리 최적화 (이 문서)**

---

## 📑 목차
- [[#1. 임베딩 모델 선택|임베딩 모델 선택]]
- [[#2. MLX + Go 연동 전략|Go 연동 전략]]
- [[#3. MLX 모델 메모리 관리|메모리 관리]]
- [[#4. MLX vs Ollama 비교|MLX vs Ollama]]
- [[#5. 최종 구성 요약|최종 구성]]

---

## 1. 임베딩 모델 선택

> [!warning] 핵심 현실
> MLX는 생성(LLM) 모델에 최적화되어 있음. 임베딩 전용 라이브러리는 아직 미성숙.
> **임베딩: sentence-transformers (MPS 가속) / 생성: MLX** 조합이 현재 최적.

### 📊 한국어 임베딩 모델 비교 (sentence-transformers)

| 모델 | 크기 | 메모리 | 속도(ms) | 품질 | 추천 용도 |
|------|------|--------|----------|------|-----------|
| multilingual-e5-small | 118MB | 200MB | 8-12 | ⭐⭐⭐ | MVP, 속도 우선 |
| multilingual-e5-large | 1.1GB | 1.4GB | 25-35 | ⭐⭐⭐⭐ | 균형 |
| BAAI/bge-m3 | 2.2GB | 2.8GB | 80-120 | ⭐⭐⭐⭐⭐ | 품질 최우선 (무거움) |
| KoSimCSE-roberta-multitask | 440MB | 560MB | 15-25 | ⭐⭐⭐⭐⭐(한국어) | 한국어 전용 |

> [!tip] 16GB 환경 권장
> - 속도 우선: multilingual-e5-small (MLX와 함께 여유로움)
> - 품질 우선: KoSimCSE (한국어 특화, 메모리 적당)
> - bge-m3는 MLX 모델과 동시 로드 시 메모리 부족 가능

### 💻 임베딩 모듈 구현

```python
# rag_engine/embeddings.py
import torch
from sentence_transformers import SentenceTransformer
from typing import Union, Literal
import numpy as np

class Embedder:
    PRESETS = {
        "fast": "intfloat/multilingual-e5-small",
        "balanced": "BM-K/KoSimCSE-roberta-multitask",
        "quality": "intfloat/multilingual-e5-large",
        "best": "BAAI/bge-m3",
    }

    def __init__(self, model: Literal["fast", "balanced", "quality", "best"] = "balanced",
                 device: str = "auto"):
        if device == "auto":
            if torch.backends.mps.is_available():
                device = "mps"
            elif torch.cuda.is_available():
                device = "cuda"
            else:
                device = "cpu"

        model_name = self.PRESETS.get(model, model)
        self.model = SentenceTransformer(model_name, device=device)
        self.model_name = model_name
        self.dimension = self.model.get_sentence_embedding_dimension()

    def embed(self, texts: Union[str, list[str]], is_query: bool = False) -> np.ndarray:
        if isinstance(texts, str):
            texts = [texts]
        if "e5" in self.model_name.lower():
            prefix = "query: " if is_query else "passage: "
            texts = [prefix + t for t in texts]
        return self.model.encode(texts, normalize_embeddings=True,
                                  show_progress_bar=len(texts) > 50, batch_size=32)

    def embed_query(self, query: str) -> np.ndarray:
        return self.embed(query, is_query=True)[0]

    def embed_documents(self, documents: list[str]) -> np.ndarray:
        return self.embed(documents, is_query=False)
```

---

## 2. MLX + Go 연동 전략

### 📊 연동 방식 비교

| 방식 | 레이턴시 | 구현 복잡도 | 메모리 오버헤드 | 적합한 경우 |
|------|----------|------------|-----------------|-------------|
| subprocess (매번 실행) | 3-5초 | ⭐ | 매번 2GB+ | 비권장 |
| **FastAPI (HTTP)** | 5-15ms | ⭐⭐ | 상주 ~2.5GB | **MVP 권장** |
| gRPC | 1-5ms | ⭐⭐⭐ | 상주 ~2.5GB | 최적화 단계 |
| Unix Socket | <1ms | ⭐⭐ | 상주 ~2.5GB | 성능 최적화 |
| llama.cpp Go 바인딩 | 0ms | ⭐⭐⭐⭐ | 통합 ~2GB | MLX 포기 시 |

> [!tip] 권장 경로
> MVP → FastAPI (HTTP) / 최적화 → Unix Socket

### 📋 아키텍처

```
Go (daily-paper-summary)
         │
         │ HTTP localhost:8000 (JSON, ~10ms)
         ▼
Python (FastAPI)
         │
    ┌────┴────┐
    │         │
 Embedder   MLX Generator
 (KoSimCSE) (Qwen 3B-4bit)
  ~500MB      ~2GB
    │         │
    └────┬────┘
         │
      ChromaDB (~50MB)
```

### 💻 FastAPI 서버 핵심 엔드포인트

```python
# mlx_server/main.py
from fastapi import FastAPI
from pydantic import BaseModel

app = FastAPI(title="MLX RAG Engine")

# 엔드포인트:
# GET  /health        → 상태 확인
# POST /embed         → 텍스트 임베딩
# POST /index         → 문서 인덱싱
# POST /search        → 벡터 검색
# POST /generate      → 텍스트 생성
# POST /rag           → 검색+생성 통합
# POST /model/load    → 모델 로드
# POST /model/unload  → 모델 언로드

class RAGRequest(BaseModel):
    query: str
    k: int = 3
    max_tokens: int = 512

class RAGResponse(BaseModel):
    answer: str
    sources: list
    elapsed_ms: float
    model_was_cold: bool

@app.post("/rag", response_model=RAGResponse)
async def rag(request: RAGRequest):
    # 1. 검색
    search_results = retriever.search(request.query, k=request.k)
    # 2. 컨텍스트 구성
    context = "\n\n".join([r["content"] for r in search_results])
    # 3. 프롬프트 구성 + 생성
    if not generator.is_loaded():
        generator.load()
    result = generator.generate(prompt=build_prompt(request.query, context),
                                 max_tokens=request.max_tokens)
    return RAGResponse(answer=result["text"], sources=search_results, ...)
```

### 💻 Go 클라이언트

```go
// pkg/mlx/client.go
package mlx

type Client struct {
    baseURL    string
    httpClient *http.Client
}

func NewClient(baseURL string) *Client {
    return &Client{
        baseURL:    baseURL,
        httpClient: &http.Client{Timeout: 120 * time.Second},
    }
}

func (c *Client) RAG(ctx context.Context, query string) (*RAGResponse, error) {
    req := RAGRequest{Query: query, K: 3, MaxTokens: 512}
    // POST localhost:8000/rag
    return c.doPost(ctx, "/rag", req, &RAGResponse{})
}

// Go CLI 사용:
// paper ask "쿠버네티스 파드 재시작 방법은?"
```

---

## 3. MLX 모델 메모리 관리

> [!warning] Ollama vs MLX
> Ollama는 `keep_alive`로 자동 언로드. MLX는 **직접 구현 필요**.

### 📊 콜드 스타트 실측값

| 모델 | 로드 시간 | 메모리 |
|------|-----------|--------|
| Qwen2.5-1.5B-4bit | 0.8-1.2초 | 1.0GB |
| Qwen2.5-3B-4bit | 1.5-2.0초 | 1.8GB |
| Qwen2.5-7B-4bit | 3.0-4.0초 | 4.2GB |

> [!tip] MLX 콜드스타트가 Ollama(3-5초)보다 빠름!
> 3B 모델 기준: MLX 1.5초 vs Ollama 3초

### 💻 MLX Generator (자동 메모리 관리)

```python
# mlx_server/generator.py
import gc, time, threading
import mlx.core as mx
from mlx_lm import load, generate

class MLXGenerator:
    DEFAULT_MODEL = "mlx-community/Qwen2.5-3B-Instruct-4bit"

    def __init__(self, auto_unload_seconds=300, auto_load=True):
        self.auto_unload_seconds = auto_unload_seconds
        self._model = None
        self._tokenizer = None
        self._last_used = time.time()
        self._unload_timer = None
        if auto_load:
            self.load()

    def is_loaded(self): return self._model is not None

    def load(self):
        self._model, self._tokenizer = load(self.DEFAULT_MODEL)
        _ = generate(self._model, self._tokenizer, prompt="Hello",
                     max_tokens=1, verbose=False)  # 웜업
        self._last_used = time.time()
        self._schedule_unload()

    def unload(self):
        self._model = None
        self._tokenizer = None
        gc.collect()
        mx.metal.clear_cache()  # Metal 캐시 정리

    def _schedule_unload(self):
        """5분 유휴 시 자동 언로드"""
        if self._unload_timer:
            self._unload_timer.cancel()
        self._unload_timer = threading.Timer(
            self.auto_unload_seconds, self._check_and_unload)
        self._unload_timer.daemon = True
        self._unload_timer.start()

    def _check_and_unload(self):
        idle = time.time() - self._last_used
        if idle >= self.auto_unload_seconds:
            self.unload()

    def generate(self, prompt, max_tokens=512, temperature=0.3):
        if not self.is_loaded():
            self.load()
        self._last_used = time.time()
        self._schedule_unload()
        response = generate(self._model, self._tokenizer,
                           prompt=prompt, max_tokens=max_tokens,
                           temp=temperature, verbose=False)
        return {"text": response, "tokens": len(self._tokenizer.encode(response))}
```

### 📊 메모리 상태 변화

```
메모리
  ▲
3GB ─┬──────────────────────┐              ┌──────────
     │ 모델+임베딩 (~2.8GB) │              │ 재로드
1GB ─┤                      │   ┌──────────┘
     │                      │   │ 임베딩만 (~0.8GB)
0GB ─┴──────────────────────┴───┴────────────────────→ 시간
    요청1                  요청2  5분 유휴   요청3
                                  자동 언로드
```

---

## 4. MLX vs Ollama 비교

| 항목 | Ollama | MLX |
|------|--------|-----|
| 설치 | brew install ollama | pip install mlx mlx-lm |
| 모델 생태계 | 수백 개 바로 사용 | mlx-community ~100개 |
| **추론 속도 (M2)** | 45-55 tok/s | **70-85 tok/s (+30-50%)** |
| **콜드 스타트** | 3-5초 | **1.5-2초** |
| 메모리 관리 | keep_alive 자동 | 직접 구현 필요 |
| API 서버 | 내장 | FastAPI 직접 구현 |
| 멀티 플랫폼 | Mac/Linux/Windows | **Apple Silicon 전용** |
| 파인튜닝 | 미지원 | mlx-lm fine-tune 지원 |

> [!tip] 선택 기준
> - Apple Silicon 전용 + 최대 속도 → **MLX**
> - 빠른 시작 + 안정성 + 멀티 플랫폼 → **Ollama**

---

## 5. 최종 구성 요약

### 📋 아키텍처

```
Go (daily-paper-summary)
         │ HTTP localhost:8000
         ▼
Python (FastAPI)
    ┌────┴────┐
 Embedder   MLX Generator      ChromaDB
 (KoSimCSE) (Qwen 3B-4bit)     ~50MB
  ~500MB      ~2GB
```

### 📋 메모리 사용량

| 상태 | 메모리 | 시스템 여유 |
|------|--------|------------|
| 활성 (LLM 로드) | ~2.8GB | ~6-8GB |
| 유휴 (LLM 언로드) | ~0.8GB | ~8-10GB |

### 📋 예상 성능

| 항목 | 수치 |
|------|------|
| 임베딩 (단일 문장) | 15-25ms |
| 임베딩 (배치 100문장) | 500-800ms |
| 생성 콜드 스타트 | 1.5-2초 |
| 생성 웜 스타트 (TTFT) | 0.1-0.2초 |
| 생성 속도 | 70-85 tok/s |
| 전체 RAG (웜) | 5-7초 |
| 전체 RAG (콜드) | 7-9초 |

### 📋 빠른 시작

```bash
# 1. 환경 설정
python -m venv .venv && source .venv/bin/activate

# 2. 의존성 설치
pip install mlx mlx-lm sentence-transformers chromadb fastapi uvicorn psutil

# 3. 모델 사전 다운로드
python -c "
from mlx_lm import load
load('mlx-community/Qwen2.5-3B-Instruct-4bit')
from sentence_transformers import SentenceTransformer
SentenceTransformer('BM-K/KoSimCSE-roberta-multitask')
"

# 4. 서버 실행
python -m mlx_server.main

# 5. 테스트
curl http://localhost:8000/health
```

> [!tip] 한 줄 요약
> **"임베딩은 sentence-transformers(MPS), 생성은 MLX, 연동은 FastAPI — Apple Silicon 네이티브 RAG"**
