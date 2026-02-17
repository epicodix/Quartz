---
title: RAG 평가 시스템 설계 문서
tags:
  - RAG
  - evaluation
  - benchmark
  - LLM
  - Obsidian
  - architecture
  - Python
aliases:
  - RAG 벤치마크
  - RAG 평가 설계
date: 2026-02-15
category: 2_기술_분석/AI
status: 완성
priority: 높음
---

# 🎯 RAG 평가 시스템 설계 문서

> [!note] 시리즈
> [[AI-에이전트-RAG-시스템-상세설계|1편: 전체 아키텍처 + MVP 설계]]
> [[MLX-기반-RAG-시스템-구축-가이드|2편: MLX 런타임 + Go 연동 + 메모리 최적화]]
> **3편: 데이터셋 + 평가 시스템 + 벤치마크 (이 문서)**

> [!tip] 핵심 아이디어
> "Claude가 설계한 아키텍처"를 문서화해두면
> → 다른 AI한테 줄 때 "컨텍스트 손실" 최소화
> → 나중에 다시 Claude한테 물어볼 때도 빠름
> → 나 자신도 까먹었을 때 참고

---

## 📑 목차
- [[#1. 프로젝트 개요|프로젝트 개요]]
- [[#2. 시스템 아키텍처|시스템 아키텍처]]
- [[#3. 디렉토리 구조|디렉토리 구조]]
- [[#4. 핵심 컴포넌트 명세|핵심 컴포넌트]]
- [[#5. 설정 파일|설정 파일]]
- [[#6. 실행 순서|실행 순서]]
- [[#7. 확장 계획|확장 계획]]
- [[#8. 트러블슈팅|트러블슈팅]]

---

## 1. 프로젝트 개요

### 📋 목적
- Obsidian 기술문서(200+)를 RAG 데이터셋으로 활용
- 로컬 LLM 성능 평가를 위한 개인 벤치마크 시스템 구축
- AI 구독 의존도 점진적 감소를 위한 인프라

### 📋 핵심 가치
- **모델 독립적**: LLM은 교체 가능, 데이터/파이프라인은 자산
- **실무 중심**: 일반 벤치마크가 아닌 "내 도메인" 기준 평가
- **장기 투자**: 2-3년 후 로컬 전환 대비

---

## 2. 시스템 아키텍처

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│   Phase 1    │────▶│   Phase 2    │────▶│   Phase 3    │
│  문서 전처리  │     │  RAG 구축    │     │  벤치마크    │
└──────────────┘     └──────────────┘     └──────────────┘

┌─────────────────────────────────────────────────────────┐
│                    Data Layer                           │
│  - Obsidian Vault (원본)                                │
│  - Vector DB (Chroma)                                   │
│  - Q&A Dataset (JSONL)                                  │
│  - Evaluation Results (JSON)                            │
└─────────────────────────────────────────────────────────┘
```

---

## 3. 디렉토리 구조

```
rag-eval-system/
├── docs/                    # 설계 문서
│   ├── ARCHITECTURE.md
│   ├── SETUP.md
│   ├── TROUBLESHOOTING.md
│   └── DECISIONS.md
│
├── src/
│   ├── preprocessing/       # Phase 1: 문서 전처리
│   │   ├── __init__.py
│   │   ├── analyzer.py      # 문서 품질 분석
│   │   ├── frontmatter.py   # frontmatter 생성
│   │   └── dedup.py         # 중복 감지
│   │
│   ├── rag/                 # Phase 2: RAG 시스템
│   │   ├── __init__.py
│   │   ├── chunker.py       # 청킹 로직
│   │   ├── embedder.py      # 임베딩 생성
│   │   └── retriever.py     # 검색 로직
│   │
│   ├── evaluation/          # Phase 3: 평가 시스템
│   │   ├── __init__.py
│   │   ├── qa_generator.py  # Q&A 생성
│   │   ├── benchmark.py     # 벤치마크 실행
│   │   └── metrics.py       # 평가 지표
│   │
│   └── models/              # LLM 어댑터 (교체 가능)
│       ├── __init__.py
│       ├── base.py          # 추상 인터페이스
│       ├── ollama.py        # Ollama 연동
│       ├── glm.py           # GLM API
│       └── openai_compat.py # OpenAI 호환 API
│
├── data/
│   ├── raw/                 # Obsidian vault 심볼릭 링크
│   ├── processed/           # 전처리된 문서
│   ├── vectordb/            # Chroma DB
│   └── eval/                # 평가 데이터셋
│       ├── qa_dataset.jsonl
│       ├── qa_easy.jsonl
│       ├── qa_medium.jsonl
│       └── qa_hard.jsonl
│
├── results/                 # 벤치마크 결과
│   └── {model}_{date}.json
│
├── scripts/
│   ├── preprocess.py        # 전처리 실행
│   ├── build_vectordb.py    # 벡터DB 구축
│   ├── generate_qa.py       # Q&A 생성
│   └── run_benchmark.py     # 벤치마크 실행
│
├── config/
│   ├── config.yaml          # 메인 설정
│   └── models.yaml          # 모델별 설정
│
└── requirements.txt
```

---

## 4. 핵심 컴포넌트 명세

### 📋 4-1. 문서 품질 분석기 (`analyzer.py`)

**목적**: Obsidian 문서를 RAG 적합성 기준으로 분류

```python
@dataclass
class DocAnalysis:
    path: str
    quality: DocQuality  # HIGH, MEDIUM, LOW, SKIP
    issues: list[str]
    metrics: dict
    suggested_actions: list[str]
```

| 등급 | 조건 | 액션 |
|------|------|------|
| HIGH | 헤딩 구조 O, 500자+, 완결성 80%+ | 바로 사용 |
| MEDIUM | 이슈 2개 이하, 500자+ | 전처리 후 사용 |
| LOW | 그 외 | 수동 검토 |
| SKIP | 100자 미만, 링크 모음 | RAG 제외 |

---

### 📋 4-2. Frontmatter 생성기 (`frontmatter.py`)

**목적**: 메타데이터 없는 문서에 자동 생성

```yaml
title: string      # H1 또는 파일명에서 추출
category: string   # 키워드 기반 감지
tags: list         # 자동 추출 (최대 8개)
type: string       # tutorial, reference, troubleshooting, ...
difficulty: string # beginner, intermediate, advanced
doc_id: string     # 파일 경로 해시 (12자)
```

카테고리 키워드 매핑:
```python
CATEGORY_KEYWORDS = {
    'kubernetes': ['kubectl', 'pod', 'deployment', 'service', ...],
    'terraform': ['terraform', 'tf', 'provider', 'resource', ...],
    'docker': ['docker', 'container', 'dockerfile', ...],
}
```

---

### 📋 4-3. Q&A 생성기 (`qa_generator.py`)

**목적**: 문서에서 평가용 Q&A 쌍 자동 생성

| 타입 | 설명 | 예시 |
|------|------|------|
| FACTUAL | 사실/명령어 | "Pod 삭제 명령어는?" |
| CONCEPTUAL | 개념 설명 | "Service의 역할은?" |
| PROCEDURAL | 절차/방법 | "ConfigMap 마운트 방법은?" |
| TROUBLESHOOTING | 문제 해결 | "CrashLoopBackOff 원인은?" |
| COMPARISON | 비교 | "Deployment vs StatefulSet?" |

출력 포맷 (JSONL):
```json
{
  "question": "질문",
  "answer": "정답",
  "question_type": "factual",
  "difficulty": "medium",
  "source_doc": "k8s/pods.md",
  "metadata": {"key_terms": ["..."]}
}
```

---

### 📋 4-4. LLM 어댑터 인터페이스 (`models/base.py`)

**목적**: 모델 교체를 쉽게 하기 위한 추상화

```python
from abc import ABC, abstractmethod

class BaseLLM(ABC):
    @abstractmethod
    def generate(self, prompt: str, **kwargs) -> str:
        pass

    @abstractmethod
    def get_model_info(self) -> dict:
        pass

    @property
    @abstractmethod
    def context_length(self) -> int:
        pass
```

구현체:
- `OllamaLLM`: 로컬 Ollama
- `GLMLLM`: Z.AI GLM API
- `OpenAICompatLLM`: OpenAI 호환 API (DeepSeek 등)

---

### 📋 4-5. 벤치마크 실행기 (`benchmark.py`)

```python
@dataclass
class BenchmarkResult:
    model_name: str
    timestamp: str

    # 정확도
    accuracy_by_type: dict[str, float]
    accuracy_by_difficulty: dict[str, float]
    overall_accuracy: float

    # 성능
    avg_latency_ms: float
    tokens_per_second: float

    # 샘플
    examples: list[dict]  # 좋은/나쁜 응답 샘플
```

채점 방식:
- 키워드 매칭 (기본)
- 임베딩 유사도 (선택)
- LLM-as-Judge (고급, 별도 모델 필요)

---

## 5. 설정 파일

### config.yaml

```yaml
paths:
  vault: "/path/to/obsidian/vault"
  vectordb: "./data/vectordb"
  eval_data: "./data/eval"
  results: "./results"

preprocessing:
  min_doc_length: 200
  skip_patterns:
    - "templates/"
    - ".obsidian/"

chunking:
  method: "heading"
  max_chunk_size: 1500
  overlap: 100

embedding:
  model: "sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2"
  batch_size: 32

qa_generation:
  questions_per_chunk: 3
  temperature: 0.7
  target_total: 500
```

### models.yaml

```yaml
models:
  qwen2.5-32b:
    type: ollama
    model_name: "qwen2.5:32b"
    context_length: 32768

  glm-4:
    type: glm
    api_key: "${GLM_API_KEY}"
    model_name: "glm-4"
    context_length: 128000

  deepseek-v3:
    type: openai_compat
    api_base: "https://api.deepseek.com/v1"
    api_key: "${DEEPSEEK_API_KEY}"
    model_name: "deepseek-chat"
    context_length: 64000

default_model: qwen2.5-32b
```

---

## 6. 실행 순서

### Phase 1: 문서 전처리

```bash
# 문서 품질 분석
python scripts/preprocess.py analyze

# frontmatter 생성 (dry-run)
python scripts/preprocess.py frontmatter --dry-run

# frontmatter 적용
python scripts/preprocess.py frontmatter --apply

# 중복 검사
python scripts/preprocess.py dedup
```

### Phase 2: RAG 구축

```bash
# 벡터DB 생성
python scripts/build_vectordb.py

# 검색 테스트
python scripts/build_vectordb.py --test "kubectl pod 삭제"
```

### Phase 3: Q&A 생성

```bash
# Q&A 데이터셋 생성
python scripts/generate_qa.py --model glm-4 --target 500

# 품질 검토 (샘플)
python scripts/generate_qa.py --review-sample 50
```

### Phase 4: 벤치마크

```bash
# 단일 모델 평가
python scripts/run_benchmark.py --model qwen2.5-32b

# 여러 모델 비교
python scripts/run_benchmark.py --compare qwen2.5-32b,glm-4,deepseek-v3

# 결과 리포트
python scripts/run_benchmark.py --report
```

---

## 7. 확장 계획

### 단기 (1-3개월)
- 기본 시스템 구축
- Q&A 500개 생성
- 현재 모델 baseline 측정

### 중기 (3-12개월)
- 새 모델 출시 시 자동 평가
- 평가 지표 고도화 (LLM-as-Judge)
- 웹 UI 대시보드

### 장기 (1년+)
- 에이전트 기능 추가
- 문서 자동 업데이트 연동
- 팀 공유 기능

---

## 8. 트러블슈팅

> [!warning] GLM이 아키텍처 이해 못하고 이상하게 구현함
> 함수 단위로 쪼개서 요청. "이 시그니처 그대로, 내부만 구현해" 식으로.

> [!warning] 벡터 검색 품질이 안 좋음
> 1. 임베딩 모델 교체 시도
> 2. 청킹 사이즈 조정
> 3. 메타데이터 필터링 추가

> [!warning] Q&A 품질이 떨어짐
> 1. 온도 낮추기 (0.5)
> 2. 수동 검토 후 필터링
> 3. 고품질 문서만 선별해서 생성

---

## 📋 이 문서 활용법

```
다른 AI한테 줄 때:
"이 설계문서 읽고, src/preprocessing/analyzer.py 구현해줘"

→ 전체 맥락 + 구체적 스펙 전달
→ "알아서 해석"할 여지 최소화
```

> [!tip] 한 줄 요약
> **"모델은 교체 가능한 부품, 데이터와 평가 파이프라인이 진짜 자산"**
