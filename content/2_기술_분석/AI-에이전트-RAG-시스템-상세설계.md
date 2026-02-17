---
title: AI 에이전트 RAG 시스템 - 상세 설계
tags:
  - RAG
  - LLM
  - Ollama
  - LangChain
  - ChromaDB
  - architecture
  - AI-agent
aliases:
  - 옵시디언 RAG 설계
  - AI 에이전트 아키텍처
date: 2026-02-15
category: 2_기술_분석/AI
status: 완성
priority: 높음
---

# 🎯 AI 에이전트 RAG 시스템 상세 설계

## 📑 목차
- [[#1. 전체 아키텍처|전체 아키텍처]]
- [[#2. MVP 컷라인 (주말 2일)|MVP 컷라인]]
- [[#3. LLM 라우터 결정 트리|LLM 라우터]]
- [[#4. 옵시디언 마크다운 청킹 전략|청킹 전략]]
- [[#5. MCP vs LangChain 트레이드오프|MCP vs LangChain]]
- [[#6. 최종 요약|최종 요약]]

---

## 1. 전체 아키텍처

> [!note] 핵심 개념
> 4계층 구조의 AI 에이전트 시스템. 폐쇄망 대응 + 하이브리드 LLM 라우팅.

```
┌────────────────────────────────────────────────────────────────┐
│  Layer 1: 사용자 인터페이스                                      │
│  • Obsidian Plugin  → 노트/문서 작업                            │
│  • CLI Agent        → 터미널 기반 작업                          │
│  • VS Code Extension → 코드 개발                                │
│  • Web UI (Streamlit) → 웹 기반 접근                            │
├────────────────────────────────────────────────────────────────┤
│  Layer 2: 에이전트 오케스트레이터 (MCP)                          │
│  ┌──────────┬──────────┬──────────┬──────────┐                 │
│  │ K8s/EKS  │ Code     │ Docs     │ DevOps   │                 │
│  │ Agent    │ Review   │ Writer   │ Agent    │                 │
│  └──────────┴──────────┴──────────┴──────────┘                 │
├────────────────────────────────────────────────────────────────┤
│  Layer 3: RAG 엔진                                              │
│  Index Sources:                                                 │
│  • Obsidian Vault    • Code Repo                               │
│  • K8s Docs          • Internal Wiki                           │
│                    ↓                                            │
│         Vector Store (ChromaDB/Milvus)                         │
├────────────────────────────────────────────────────────────────┤
│  Layer 4: LLM 백엔드 (자동 라우팅)                               │
│  ┌─────────────┬─────────────┬─────────────┐                   │
│  │   Ollama    │   GLM-4     │  Fallback   │                   │
│  │  (폐쇄망)   │   (z.ai)    │ (Claude/    │                   │
│  │ • Qwen 32B  │ • GLM-4-9B  │  Gemini)    │                   │
│  │ • DeepSeek  │ • GLM-4-Plus│             │                   │
│  │ • CodeLlama │             │             │                   │
│  └─────────────┴─────────────┴─────────────┘                   │
└────────────────────────────────────────────────────────────────┘
```

### 📊 핵심 설계 특징

| 특징 | 설명 |
|------|------|
| **다중 진입점** | 4가지 UI 옵션으로 다양한 워크플로우 지원 |
| **MCP 기반** | Model Context Protocol로 에이전트 간 표준화된 통신 |
| **하이브리드 RAG** | 여러 소스(코드, 문서, 위키)를 통합 인덱싱 |
| **폐쇄망 대응** | Ollama로 오프라인 환경에서도 운영 가능 |
| **자동 LLM 라우팅** | 작업 특성에 따라 최적 모델 자동 선택 |

---

## 2. MVP 컷라인 (주말 2일)

> [!tip] 핵심
> Layer 4 → Layer 3 → CLI 순서. 48시간 내 동작하는 결과물.

### 💻 Day 1 (토요일): Layer 4 + Layer 3 기초

**오전 4h - Layer 4 LLM 백엔드**

| 포함 | 제외 |
|------|------|
| Ollama 설치 + Qwen2.5:7B 단일 모델 | GLM-4, Fallback |
| 단순 API 래퍼 (completions만) | 라우터 로직 |

**오후 6h - Layer 3 RAG 기초**

| 포함 | 제외 |
|------|------|
| ChromaDB 로컬 (Docker 불필요) | Code Repo, K8s Docs |
| Obsidian Vault 단일 소스만 | 하이브리드 검색 |
| 단순 청킹 (헤딩 기준 split) | |

### 💻 Day 2 (일요일): CLI + 통합

**오전 4h - CLI Agent**

| 포함 | 제외 |
|------|------|
| Typer/Click 기반 단일 명령어 | 대화 히스토리 |
| `ask "질문"` → RAG 검색 → LLM 응답 | 스트리밍 출력 |

**오후 4h - 통합 + 테스트**

| 포함 |
|------|
| End-to-end 파이프라인 연결 |
| 5개 테스트 쿼리로 검증 |
| README + 실행 스크립트 |

### 📋 MVP 코드 구조

```
obsidian-rag-mvp/
├── main.py              # CLI 진입점 (50줄)
├── rag/
│   ├── indexer.py       # 마크다운 → ChromaDB (80줄)
│   └── retriever.py     # 검색 로직 (40줄)
├── llm/
│   └── ollama_client.py # Ollama 호출 (30줄)
└── config.yaml          # 경로 설정
```

### 📋 MVP 실행 예시

```bash
# 1. 인덱싱 (최초 1회)
python main.py index --vault ~/obsidian/notes

# 2. 질의
python main.py ask "쿠버네티스 파드 트러블슈팅 방법은?"
```

---

## 3. LLM 라우터 결정 트리

> [!note] 핵심 개념
> 네트워크 상태 → 작업 유형 분류 → 복잡도 분석 → 최적 모델 선택

```
                        [요청 수신]
                            │
                ┌───────────┴───────────┐
          [폐쇄망/오프라인]         [인터넷 연결]
                │                       │
          Ollama 강제             [작업 유형 분류]
                               ┌────────┼────────┐
                          [코드 작업] [문서/요약] [대화/추론]
                               │        │        │
                          [복잡도 & 토큰 분석]
                               │
                         [라우팅 매트릭스]
```

### 📊 라우팅 매트릭스

| 작업 유형 | 복잡도 | 추천 모델 | 레이턴시 | 비용/1M tok |
|-----------|--------|-----------|----------|-------------|
| 코드 생성/리뷰 | 단순 | Ollama (DeepSeek Coder 7B) | 2-5s | $0 |
| 코드 생성/리뷰 | 복잡 | GLM-4-Plus | 5-15s | ~$14 |
| 문서 요약 | 단순/중간 | Ollama (Qwen2.5 7B) | 1-3s | $0 |
| 문서 요약 | 복잡 (긴글) | GLM-4-9B (128K ctx) | 3-8s | ~$0.14 |
| 추론/분석 | 모든 복잡도 | GLM-4-Plus | 5-20s | ~$14 |
| 한국어 특화 | 모든 복잡도 | Ollama (Qwen2.5) | 2-5s | $0 |
| Fallback | 실패 시 | Claude 3.5 Sonnet | 2-10s | $3/$15 |

### 💻 복잡도 판단 기준

```
입력 토큰 < 2K   → "단순"
입력 토큰 2K-8K  → "중간"
입력 토큰 > 8K   → "복잡"
코드 라인 > 200  → "복잡" 승격
```

### 💻 라우터 구현 코드

```python
# llm/router.py

from enum import Enum
from dataclasses import dataclass

class TaskType(Enum):
    CODE = "code"
    DOCUMENT = "document"
    REASONING = "reasoning"
    CONVERSATION = "conversation"

class Complexity(Enum):
    SIMPLE = "simple"      # < 2K tokens
    MEDIUM = "medium"      # 2K - 8K tokens
    COMPLEX = "complex"    # > 8K tokens

@dataclass
class RoutingDecision:
    provider: str          # "ollama" | "glm" | "claude"
    model: str
    reason: str
    estimated_latency: str
    estimated_cost: float

class LLMRouter:

    ROUTING_TABLE = {
        (TaskType.CODE, Complexity.SIMPLE, True): ("ollama", "deepseek-coder:7b"),
        (TaskType.CODE, Complexity.SIMPLE, False): ("ollama", "deepseek-coder:7b"),
        (TaskType.CODE, Complexity.COMPLEX, False): ("glm", "glm-4-plus"),

        (TaskType.DOCUMENT, Complexity.SIMPLE, True): ("ollama", "qwen2.5:7b"),
        (TaskType.DOCUMENT, Complexity.SIMPLE, False): ("ollama", "qwen2.5:7b"),
        (TaskType.DOCUMENT, Complexity.COMPLEX, False): ("glm", "glm-4-9b"),

        (TaskType.REASONING, Complexity.SIMPLE, False): ("glm", "glm-4-plus"),
        (TaskType.REASONING, Complexity.COMPLEX, False): ("glm", "glm-4-plus"),
    }

    def route(self, query: str, context: str = "", is_offline: bool = False) -> RoutingDecision:
        task_type = self._classify_task(query)
        complexity = self._estimate_complexity(query, context)

        if is_offline:
            return RoutingDecision(
                provider="ollama",
                model="qwen2.5:7b",
                reason="오프라인 환경 - 로컬 모델만 가능",
                estimated_latency="2-5s",
                estimated_cost=0.0
            )

        key = (task_type, complexity, is_offline)
        provider, model = self.ROUTING_TABLE.get(
            key, ("ollama", "qwen2.5:7b")
        )

        return RoutingDecision(
            provider=provider, model=model,
            reason=f"{task_type.value} 작업, {complexity.value} 복잡도",
            estimated_latency=self._estimate_latency(provider),
            estimated_cost=self._estimate_cost(provider, query, context)
        )

    def _classify_task(self, query: str) -> TaskType:
        code_keywords = ["코드", "함수", "버그", "리팩토링", "구현",
                        "code", "function", "debug", "implement"]
        doc_keywords = ["요약", "정리", "문서", "설명", "번역",
                       "summarize", "explain", "document"]
        query_lower = query.lower()

        if any(kw in query_lower for kw in code_keywords):
            return TaskType.CODE
        elif any(kw in query_lower for kw in doc_keywords):
            return TaskType.DOCUMENT
        else:
            return TaskType.REASONING

    def _estimate_complexity(self, query: str, context: str) -> Complexity:
        total_chars = len(query) + len(context)
        estimated_tokens = total_chars * 1.5

        if estimated_tokens < 2000:
            return Complexity.SIMPLE
        elif estimated_tokens < 8000:
            return Complexity.MEDIUM
        else:
            return Complexity.COMPLEX
```

---

## 4. 옵시디언 마크다운 청킹 전략

> [!note] 핵심 개념
> 구조 파싱 → 헤딩 기반 분할 → 크기 조정 → 메타데이터 부착

### 📋 Phase 1: 청킹 규칙

**규칙 1: 헤딩 기반 분할 (Primary)**

| 레벨 | 동작 |
|------|------|
| H1 (`#`) | 새 청크 시작 (최상위 구분) |
| H2 (`##`) | 새 청크 시작 (주요 섹션) |
| H3 (`###`) | 부모 H2가 500자 초과시만 분할 |
| H4+ (`####`) | 분할하지 않음 (부모에 포함) |

**규칙 2: 크기 제한**

| 항목 | 값 |
|------|-----|
| 최소 청크 | 100자 (너무 작으면 부모와 병합) |
| 최대 청크 | 1500자 (~500 토큰) |
| 타겟 청크 | 500-800자 (~200-300 토큰) |
| 오버랩 | 50자 (문맥 연결용) |

**규칙 3: 코드블록 처리**
- 코드블록은 절대 분할하지 않음
- 코드 + 설명 = 하나의 청크로 유지
- 코드가 1000자 초과 → 별도 청크로 분리 (설명 복제)

**규칙 4: Frontmatter 활용**
- 모든 청크에 메타데이터 상속
- `tags` → 필터링용 메타데이터
- `title` → 청크 prefix로 추가
- `aliases` → 검색 확장용

### 📋 Phase 2: 최종 청크 형태

```json
{
  "id": "k8s-troubleshoot-pod-status-001",
  "content": "## Pod 상태 확인\nPod가 정상...\n```bash\n...",
  "metadata": {
    "source": "K8s 트러블슈팅 가이드.md",
    "heading_path": ["K8s 트러블슈팅 가이드", "Pod 상태 확인"],
    "tags": ["kubernetes", "devops"],
    "char_count": 650,
    "has_code": true,
    "code_lang": "bash",
    "h1": "K8s 트러블슈팅 가이드",
    "h2": "Pod 상태 확인",
    "created": "2024-01-15"
  }
}
```

### 📊 200개 파일 예상 결과

| 항목 | 값 |
|------|-----|
| 총 청크 수 | 600-900개 |
| 평균 청크 크기 | 500-700자 |
| 임베딩 차원 | 1024 (bge-m3 기준) |
| 벡터 DB 크기 | ~50-100MB |
| 인덱싱 시간 | 5-10분 (로컬 임베딩) |

### 💻 청킹 구현 코드

```python
# rag/chunker.py

import re
import yaml
from dataclasses import dataclass

@dataclass
class Chunk:
    id: str
    content: str
    metadata: dict

class ObsidianChunker:

    def __init__(self, min_chunk=100, max_chunk=1500,
                 target_chunk=700, overlap=50):
        self.min_chunk = min_chunk
        self.max_chunk = max_chunk
        self.target_chunk = target_chunk
        self.overlap = overlap

    def chunk_file(self, filepath: str) -> list[Chunk]:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()

        frontmatter, body = self._extract_frontmatter(content)
        sections = self._split_by_headings(body)
        chunks = self._adjust_chunk_sizes(sections)
        return self._attach_metadata(chunks, frontmatter, filepath)

    def _extract_frontmatter(self, content: str) -> tuple[dict, str]:
        pattern = r'^---\s*\n(.*?)\n---\s*\n'
        match = re.match(pattern, content, re.DOTALL)
        if match:
            try:
                fm = yaml.safe_load(match.group(1))
                return fm or {}, content[match.end():]
            except yaml.YAMLError:
                pass
        return {}, content

    def _split_by_headings(self, content: str) -> list[dict]:
        # 코드블록 임시 치환 (분할 방지)
        code_blocks = []
        def save_code(match):
            code_blocks.append(match.group(0))
            return f"__CODE_BLOCK_{len(code_blocks)-1}__"

        protected = re.sub(r'```[\s\S]*?```', save_code, content)

        sections = []
        pattern = r'^(#{1,2})\s+(.+)'
        current_section = {"level": 0, "title": "", "content": ""}

        for line in protected.split('\n'):
            heading_match = re.match(pattern, line)
            if heading_match:
                if current_section["content"].strip():
                    sections.append(current_section.copy())
                level = len(heading_match.group(1))
                title = heading_match.group(2)
                current_section = {
                    "level": level, "title": title,
                    "content": line + "\n"
                }
            else:
                current_section["content"] += line + "\n"

        if current_section["content"].strip():
            sections.append(current_section)

        # 코드블록 복원
        for section in sections:
            for i, code in enumerate(code_blocks):
                section["content"] = section["content"].replace(
                    f"__CODE_BLOCK_{i}__", code)
        return sections

    def _adjust_chunk_sizes(self, sections: list[dict]) -> list[dict]:
        adjusted = []
        for section in sections:
            content_len = len(section["content"])
            if content_len < self.min_chunk and adjusted:
                adjusted[-1]["content"] += "\n" + section["content"]
            elif content_len > self.max_chunk:
                adjusted.extend(self._split_large_section(section))
            else:
                adjusted.append(section)
        return adjusted

    def _split_large_section(self, section: dict) -> list[dict]:
        paragraphs = re.split(r'\n\n+', section["content"])
        chunks, current_chunk = [], ""
        for para in paragraphs:
            if len(current_chunk) + len(para) < self.target_chunk:
                current_chunk += para + "\n\n"
            else:
                if current_chunk:
                    chunks.append({**section, "content": current_chunk.strip()})
                current_chunk = para + "\n\n"
        if current_chunk:
            chunks.append({**section, "content": current_chunk.strip()})
        return chunks

    def _attach_metadata(self, chunks, frontmatter, filepath):
        result = []
        for i, chunk in enumerate(chunks):
            chunk_id = f"{filepath.stem}-{i:03d}"
            has_code = "```" in chunk["content"]
            code_lang = None
            if has_code:
                lang_match = re.search(r'```(\w+)', chunk["content"])
                code_lang = lang_match.group(1) if lang_match else None

            result.append(Chunk(
                id=chunk_id, content=chunk["content"],
                metadata={
                    "source": filepath.name,
                    "heading": chunk.get("title", ""),
                    "heading_level": chunk.get("level", 0),
                    "tags": frontmatter.get("tags", []),
                    "title": frontmatter.get("title", filepath.stem),
                    "has_code": has_code, "code_lang": code_lang,
                    "char_count": len(chunk["content"]),
                }
            ))
        return result
```

---

## 5. MCP vs LangChain 트레이드오프

> [!warning] 결론
> **1인 개발 MVP 기준: LangChain으로 시작**, 나중에 MCP로 전환 가능

### 📊 비교표

| 항목 | MCP 직접 구현 | LangChain Agent |
|------|-------------|-----------------|
| 구현 시간 | 40-50시간 | 10-15시간 |
| 참고 자료 | 부족 | 풍부 |
| 디버깅 | 어려움 | LangSmith 지원 |
| 미래 확장성 | 좋음 (표준) | MCP 불일치 |
| 보일러플레이트 | 많음 | 적음 |

### 📋 권장 마이그레이션 경로

```
Phase 1 (MVP, 2일)     → LangChain으로 빠르게 검증 (4개 Tool)
Phase 2 (안정화, 2주)   → LangChain 유지 + Tool 추가 (10개 Tool)
Phase 3 (확장, 4주)    → MCP로 전환 (필요시, Claude 연동)
```

### 💻 하이브리드 전략 (추천)

> [!tip] 핵심
> LangChain으로 시작하되, MCP 호환 인터페이스로 래핑 → 나중에 전환 시 Tool 코드 재사용

```python
# agent/hybrid.py
from abc import ABC, abstractmethod
from langchain.tools import tool

class MCPCompatibleTool(ABC):
    @property
    @abstractmethod
    def name(self) -> str: pass

    @property
    @abstractmethod
    def description(self) -> str: pass

    @property
    @abstractmethod
    def input_schema(self) -> dict: pass

    @abstractmethod
    def execute(self, **kwargs) -> str: pass

class SearchDocsTool(MCPCompatibleTool):
    def __init__(self, retriever):
        self.retriever = retriever

    @property
    def name(self): return "search_docs"

    @property
    def description(self): return "옵시디언 문서에서 관련 내용을 검색합니다."

    @property
    def input_schema(self):
        return {
            "type": "object",
            "properties": {
                "query": {"type": "string", "description": "검색 쿼리"}
            },
            "required": ["query"]
        }

    def execute(self, query: str) -> str:
        results = self.retriever.search(query, k=3)
        return "\n\n".join(r.content for r in results)

# LangChain 어댑터
def to_langchain_tool(mcp_tool: MCPCompatibleTool):
    @tool(name=mcp_tool.name, description=mcp_tool.description)
    def wrapper(**kwargs):
        return mcp_tool.execute(**kwargs)
    return wrapper

# 사용:
# search_tool = SearchDocsTool(retriever)
# langchain_tool = to_langchain_tool(search_tool)  # LangChain에서 사용
# mcp_server.register_tool(search_tool)             # MCP 전환 시 동일 객체 재사용
```

---

## 6. 최종 요약

| 항목 | 권장 사항 | 이유 |
|------|----------|------|
| **MVP 범위** | Ollama + ChromaDB + CLI만 | 48시간 내 동작하는 결과물 |
| **LLM 라우팅** | MVP에서는 제외, Phase 2에서 추가 | 복잡도 증가 대비 효용 낮음 |
| **청킹 전략** | 헤딩 기반 + 코드블록 보호 | 옵시디언 구조에 최적화 |
| **MCP vs LangChain** | LangChain으로 시작 | 1인 개발 생산성, 나중에 전환 가능 |

### 📋 구현 전략

```
Opus 4.5 (설계/두뇌)     → 무제한 무료 (KDT 제공)
Claude Code (구현)        → 로컬에서 실행
GLM (운영 비용)           → 10분의 1 가격
Ollama (폐쇄망)          → 완전 무료

사람(나) = 방향 지시 + 리뷰 + 검증
```

> [!tip] 한 줄 요약
> **"Opus로 설계, Claude Code로 구현, GLM/Ollama로 운영 — 에이전트가 에이전트를 만드는 시대"**
