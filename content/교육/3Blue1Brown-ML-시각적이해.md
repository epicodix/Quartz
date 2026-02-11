---
title: 3Blue1Brown - 머신러닝 시각적 이해
tags:
  - machine-learning
  - transformer
  - gpt
  - topology
  - 3blue1brown
  - 시각화
aliases:
  - 3B1B ML
  - Transformer 시각화
date: 2026-02-08
category: 교육
status: 완성
priority: 높음
---

# 🎯 3Blue1Brown - 머신러닝 시각적 이해

> [!note] 왜 이 영상들인가?
> ML에 대한 막연한 이해를 **시각적으로 한방에** 풀어주는 콘텐츠.
> 수식 없이 직관적으로 "아 이렇게 돌아가는구나" 깨닫게 해줌.

---

## 📑 목차
- [[#1. Transformer와 Attention|Transformer와 Attention]]
- [[#2. GPT 모델의 작동 원리|GPT 모델의 작동 원리]]
- [[#3. Topology와 ML의 연결|Topology와 ML의 연결]]
- [[#4. 핵심 개념 정리|핵심 개념 정리]]

---

## 1. Transformer와 Attention

### 📺 영상
- [Attention in transformers, visually explained](https://www.youtube.com/watch?v=eMlx5fFNoYc)
- [But what is a GPT? Visual intro to transformers](https://www.youtube.com/watch?v=wjZofJX0v4M)

### 💡 핵심 아이디어

**Attention = "어디를 봐야 하는가"**

```
문장: "The cat sat on the mat because it was tired"
                                    ^^
                                    it이 뭘 가리키는가?
```

- 사람은 문맥으로 "it = cat"임을 앎
- Transformer는 **Attention 점수**로 이걸 계산

### 🔢 Softmax 함수

```
입력: [2.0, 1.0, 0.1]
      ↓ softmax
출력: [0.7, 0.2, 0.1]  (합 = 1.0)
```

- 여러 값을 **확률 분포**로 변환
- 가장 큰 값이 가장 높은 확률
- Attention에서 "어디에 집중할지" 결정

### 🎯 Query, Key, Value

| 개념 | 비유 | 역할 |
|-----|-----|-----|
| Query (Q) | 질문 | "나는 뭘 찾고 있는가?" |
| Key (K) | 라벨 | "나는 어떤 정보를 갖고 있는가?" |
| Value (V) | 내용 | "실제 정보" |

```
Attention(Q, K, V) = softmax(Q × K^T / √d) × V
```

→ Query와 Key가 얼마나 매칭되는지 계산 → 그만큼 Value 가져옴

---

## 2. GPT 모델의 작동 원리

### 🧱 텐서와 다차원 배열

**단어 → 숫자 벡터 (Embedding)**

```
"cat" → [0.2, -0.5, 0.8, 0.1, ...]  (768차원)
"dog" → [0.3, -0.4, 0.7, 0.2, ...]
```

- 비슷한 의미 = 비슷한 벡터 (가까운 위치)
- 이게 **고차원 공간에서의 위치**

### 📐 다차원 공간의 직관

```
2D: 점은 (x, y)
3D: 점은 (x, y, z)
768D: 점은 (x1, x2, ..., x768)
```

- 시각화는 불가능하지만 **수학적으로는 동일**
- 거리, 방향, 유사도 계산 가능

### 🔄 Transformer 레이어

```
입력 토큰들
    ↓
[Attention] ← 토큰 간 관계 파악
    ↓
[Feed Forward] ← 각 토큰 개별 처리
    ↓
[Layer Norm] ← 안정화
    ↓
(반복 x N번)
    ↓
다음 토큰 예측
```

GPT-3: 96개 레이어
GPT-4: 120개+ 레이어 (추정)

---

## 3. Topology와 ML의 연결

### 📺 영상
- [Who cares about topology?](https://www.youtube.com/watch?v=AmgkSdhK4K8)

### 💡 Topology란?

**"찢거나 붙이지 않고 변형해도 유지되는 성질"**

```
도넛 🍩 = 커피컵 ☕ (위상적으로 동일)
       둘 다 구멍이 1개

공 ⚽ ≠ 도넛 🍩 (위상적으로 다름)
     구멍 개수가 다름
```

### 🧠 ML에서의 Topology

**고차원 데이터의 "형태"를 이해**

```
데이터셋이 고차원 공간에서 어떤 모양인가?
- 클러스터로 뭉쳐있나?
- 연결되어 있나?
- 구멍이 있나?
```

### 🎯 왜 중요한가?

1. **차원 축소** (t-SNE, UMAP)
   - 고차원 → 2D로 시각화할 때 위상 구조 보존

2. **Manifold Learning**
   - 데이터가 실제로는 저차원 곡면 위에 있다는 가정
   - 그 곡면의 형태 = 위상

3. **Neural Network의 학습**
   - 입력 공간을 "접고 펴서" 분류 가능한 형태로 변환
   - 이 변환이 위상적 변형

---

## 4. 핵심 개념 정리

### 📊 한눈에 보기

| 개념 | 한줄 설명 |
|-----|----------|
| Embedding | 단어 → 고차원 벡터 |
| Attention | "어디를 봐야 하는가" 계산 |
| Softmax | 값들을 확률로 변환 |
| Transformer | Attention 반복 적용하는 구조 |
| Topology | 형태의 본질적 성질 |

### 🔗 연결고리

```
텍스트
  ↓ Embedding
고차원 벡터들 (Topology적 구조를 가짐)
  ↓ Attention (Softmax)
문맥 반영된 벡터
  ↓ 여러 레이어
다음 단어 예측
```

---

## 📚 추천 시청 순서

1. **Neural Network 기초**
   - [But what is a neural network?](https://www.youtube.com/watch?v=aircAruvnKk)

2. **Transformer 이해**
   - [But what is a GPT?](https://www.youtube.com/watch?v=wjZofJX0v4M)
   - [Attention in transformers](https://www.youtube.com/watch?v=eMlx5fFNoYc)

3. **수학적 직관**
   - [Who cares about topology?](https://www.youtube.com/watch?v=AmgkSdhK4K8)

---

> [!tip] 복습 포인트
> - Attention = Query와 Key의 유사도로 Value 가중합
> - Softmax = 확률 분포로 변환
> - 고차원 공간에서 단어들은 의미에 따라 위치함
> - Topology = 본질적 형태 (구멍 개수 등)

---

## 5. 2026 트렌드 - 더 파고들고 싶다면

> [!note] 기초 이해했으면 이쪽으로
> 위 개념들이 실제로 어떻게 발전하고 있는지

### 🔥 LLM 핵심 트렌드

| 키워드 | 한줄 설명 | 왜 중요한가 |
|-------|----------|------------|
| **RAG** | 검색 + 생성 결합 | 환각 줄이고 최신 정보 반영 |
| **RLHF** | 사람 피드백으로 학습 | ChatGPT가 똑똑해진 비결 |
| **MoE** | 전문가 모델 여러개 조합 | 적은 연산으로 큰 모델 효과 |
| **Agent** | LLM + 도구 사용 | 검색, 코딩, API 호출 등 |

### ⚡ 효율화 (작게, 빠르게)

| 키워드 | 한줄 설명 | 관심 가질 상황 |
|-------|----------|---------------|
| **Quantization** | 32bit → 4bit 압축 | 맥북에서 LLM 돌리고 싶을 때 |
| **LoRA / QLoRA** | 일부만 학습 | 내 데이터로 파인튜닝하고 싶을 때 |
| **Speculative Decoding** | 작은 모델이 초안, 큰 모델이 검증 | 추론 속도 2-3배 향상 |
| **KV Cache 최적화** | 메모리 효율화 | 긴 문맥 처리할 때 |

### 🖼️ Multimodal (텍스트 넘어서)

| 키워드 | 한줄 설명 | 예시 |
|-------|----------|-----|
| **VLM** | 이미지 + 텍스트 이해 | GPT-4V, Gemini |
| **Text-to-Video** | 텍스트 → 영상 생성 | Sora, Runway |
| **Audio LLM** | 음성 직접 이해/생성 | GPT-4o 실시간 대화 |

### 🧠 Reasoning (더 똑똑하게)

| 키워드 | 한줄 설명 | 핵심 |
|-------|----------|-----|
| **Chain of Thought** | 단계별 사고 | "먼저... 그다음..." |
| **Test-time Compute** | 추론 시 더 많이 생각 | o1, o3 모델 방식 |
| **Self-Reflection** | 스스로 검토/수정 | 답변 품질 향상 |

### 📱 On-device AI (로컬에서)

| 키워드 | 한줄 설명 | 관련 도구 |
|-------|----------|----------|
| **MLX** | Apple Silicon 최적화 | M1/M2/M3 맥에서 LLM |
| **llama.cpp** | CPU에서 LLM 실행 | 어디서든 로컬 추론 |
| **Edge AI** | 디바이스에서 직접 | 프라이버시, 오프라인 |

---

### 🎯 관심사별 추천 경로

**"LLM 활용에 관심"**
```
RAG → Agent → Tool Use → LangChain/LlamaIndex
```

**"모델 직접 만져보고 싶음"**
```
Quantization → LoRA → Hugging Face → 파인튜닝
```

**"맥북에서 로컬로 돌리고 싶음"**
```
llama.cpp → MLX → Ollama → 로컬 챗봇
```

**"최신 연구 따라가고 싶음"**
```
arXiv daily → Hugging Face Papers → Twitter/X ML 계정들
```

---

> [!warning] 주의
> 트렌드 쫓다가 기초 놓치면 안됨.
> 위의 3Blue1Brown 영상들로 **Attention, Embedding, Topology** 확실히 이해하고 넘어갈 것.
