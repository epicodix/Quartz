---
title: Locally 일정 생성 AI 프롬프트 튜닝 전략 (숙소 기반 스토리라인)
creation_date: 2026-04-05
date: 2026-04-05
tags: [AI, Prompt_Engineering, Product, Feature, Storyline]
aliases: [일정생성-프롬프트-튜닝]
category: 기획/AI
status: 완료
priority: 보통
model: gemini-3.0-pro preview
---

# 🎯 Locally 일정 생성: 숙소 기반 스토리라인 튜닝 전략

현재 Locally의 AI 일정 생성 백엔드(`hamster_locally/itinerary.py`)는 숙소(`lodging`) 정보가 입력되면 AI에게 **"매일 이 근처에서 시작하고 끝내라(Start and end each day near this location)"**라는 다소 경직된(Hard-coded) 프롬프트를 주입하고 있습니다.

이 방식은 사용자가 숙소를 입력했을 때 **"숙소 근처 동네(예: 명동)에만 갇혀버리는 지루한 여행 일정"**을 생성할 위험(Product Risk)이 있습니다. 이를 해결하고 여행자의 실제 기대(자연스러운 동선)를 충족시키기 위해 프롬프트를 스토리라인 기반으로 고도화하는 전략을 정리합니다.

---

## 1. 문제 정의 (The Problem)
*   **현재 프롬프트**: `lodging_section = f"\n## Lodging\n{loc.name} ... \nStart and end each day near this location.\n"`
*   **발생 가능한 결과**: 3박 4일 내내 명동 숙소를 예약한 외국인에게 남대문, 남산, 을지로만 뺑뺑 도는 일정을 추천하여 성수동이나 홍대 같은 핫플레이스를 놓치게 만듭니다.

## 2. 해결책: '스토리라인(Storyline)' 기반 프롬프트 주입
단순히 "숙소 근처에 머물라"는 지시어 대신, **"숙소를 베이스캠프로 삼되, 날짜별(Day N)로 확장되는 여행의 흐름(Flow)"**을 AI에게 학습(Prompting)시킵니다.

### 💡 제안하는 Prompt (수정 가이드)
백엔드/AI 담당자(종태/이세종님)가 `itinerary.py`의 `lodging_section`을 다음과 같이 수정하면 됩니다.

```python
# [AS-IS] 기존 코드
lodging_section = f"\n## Lodging\n{loc.name} | {loc.address}{coord} | Region: {loc.region}\nStart and end each day near this location.\n"

# [TO-BE] 수정 제안 코드
lodging_section = f"""
## Lodging (Basecamp)
{loc.name} | {loc.address}{coord} | Region: {loc.region}
Apply the following natural traveler storyline based on the lodging location:
1. First Day: Start exploring areas relatively close to the lodging to ease into the trip.
2. Middle Days: DO NOT trap the traveler in the lodging zone. Feel free to travel to different major zones (e.g., Gangnam, Seongsu, Hongdae) for main attractions.
3. Last Day: Keep activities within or very close to the lodging zone for a relaxed morning and easy luggage pickup before departure.
"""
```

## 3. 기대 효과 (Expected Impact)
*   **1일차 (워밍업)**: 도착 후 피곤한 몸을 이끌고 무리하게 멀리 나가는 대신, 숙소 근처에서 가볍게 동네를 파악하고 첫 한국 식사를 즐기는 현실적인 첫날.
*   **2~3일차 (딥 다이브)**: 본격적인 여행 시작! 숙소 위치(명동 등)에 구애받지 않고, 서울 전역의 핫플레이스(성수, 홍대, 강남 등)를 마음껏 탐험하는 날.
*   **마지막 날 (마무리)**: 무거운 캐리어를 끌고 멀리 가지 않도록, 출국 준비를 위해 숙소 근처(명동 등)에서 마지막 가벼운 쇼핑과 식사를 제안하는 **센스 있는 AI 가이드** 완성.

<br>
<div align="right" style="font-size: 0.8em; color: gray; opacity: 0.6;">
  Supported by gemini-3.0-pro preview
</div>
