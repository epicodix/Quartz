---
title: 'Phase 1: Strangler Fig Pattern 구현'
summary: 기존 Apps Script 시스템을 유지하면서 신규 기능만 GCP로 구현하는 점진적 마이그레이션
tags:
- 미분류
category: 기타
difficulty: 중급
estimated_time: 30분
created: '2025-11-08'
updated: '2025-11-08'
---

# Phase 1: Strangler Fig Pattern 구현

## 개요
기존 Apps Script 시스템을 유지하면서 신규 기능만 GCP로 구현하는 점진적 마이그레이션

## 구현 목표
- [ ] 기존 시스템 무중단 운영
- [ ] 신규 실시간 API 서비스 구축
- [ ] 트래픽 점진적 이전 (10% → 50% → 100%)
- [ ] 성능/안정성 비교 분석

## 아키텍처 설계

### Before (기존)
```
Google Sheets ← Apps Script → 정적 웹사이트
```

### After (Phase 1)
```
                 ┌─ Apps Script (기존 배치)
Google Sheets ←──┤
                 └─ Cloud Functions (신규 실시간) → Firestore → React 웹앱
```

## 구현 단계

### 1단계: GCP 프로젝트 설정
```bash
# gcloud CLI 설정
gcloud init
gcloud config set project naver-ad-analytics

# 필요한 API 활성화
gcloud services enable cloudfunctions.googleapis.com
gcloud services enable firestore.googleapis.com
gcloud services enable run.googleapis.com
```

### 2단계: Cloud Functions - 데이터 수집 서비스

#### 디렉토리 구조
```
naver-ad-collector/
├── functions/
│   ├── naver-keyword-api/
│   │   ├── main.py
│   │   └── requirements.txt
│   └── naver-datalab-api/
│       ├── main.py
│       └── requirements.txt
├── shared/
│   └── naver_auth.py
└── deploy.sh
```

#### naver-keyword-api/main.py
```python
import functions_framework
from google.cloud import firestore
import hmac
import hashlib
import base64
import time
import requests

@functions_framework.http
def naver_keyword_api(request):
    """네이버 키워드도구 API 호출"""
    
    # CORS 처리
    if request.method == 'OPTIONS':
        headers = {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'GET, POST',
            'Access-Control-Allow-Headers': 'Content-Type',
        }
        return ('', 204, headers)
    
    try:
        # 요청 파라미터 파싱
        keyword = request.args.get('keyword')
        if not keyword:
            return {'error': 'keyword parameter required'}, 400
        
        # 네이버 API 인증 정보 (환경변수에서 로드)
        access_key = os.environ['NAVER_ACCESS_KEY']
        secret_key = os.environ['NAVER_SECRET_KEY']
        customer_id = os.environ['NAVER_CUSTOMER_ID']
        
        # HMAC 서명 생성
        timestamp = str(int(time.time() * 1000))
        method = "GET"
        api_url = "/keywordstool"
        signature_string = f"{timestamp}.{method}.{api_url}"
        
        signature = base64.b64encode(
            hmac.new(
                secret_key.encode('utf-8'),
                signature_string.encode('utf-8'),
                hashlib.sha256
            ).digest()
        ).decode('utf-8')
        
        # API 호출
        url = f"https://api.naver.com/keywordstool?hintKeywords={keyword}&showDetail=1"
        headers = {
            'X-Timestamp': timestamp,
            'X-API-KEY': access_key,
            'X-Customer': customer_id,
            'X-Signature': signature
        }
        
        response = requests.get(url, headers=headers)
        data = response.json()
        
        # Firestore에 저장
        db = firestore.Client()
        doc_ref = db.collection('keyword_data').document()
        doc_ref.set({
            'keyword': keyword,
            'data': data,
            'timestamp': firestore.SERVER_TIMESTAMP,
            'source': 'keyword_api'
        })
        
        # CORS 헤더와 함께 응답
        headers = {'Access-Control-Allow-Origin': '*'}
        return (data, 200, headers)
        
    except Exception as e:
        return {'error': str(e)}, 500
```

### 3단계: Firestore 데이터 모델 설계

#### Collections 구조
```
keyword_data/
├── {doc_id}/
│   ├── keyword: string
│   ├── pc_search_count: number
│   ├── mobile_search_count: number
│   ├── competition: string
│   ├── timestamp: timestamp
│   └── raw_data: object

trend_data/
├── {doc_id}/
│   ├── keyword: string
│   ├── period: string
│   ├── ratio: number
│   └── timestamp: timestamp

user_requests/
├── {doc_id}/
│   ├── keyword: string
│   ├── user_ip: string
│   ├── timestamp: timestamp
│   └── status: string
```

### 4단계: Cloud Run - Web API 서비스

#### app.js (Express.js)
```javascript
const express = require('express');
const { Firestore } = require('@google-cloud/firestore');
const cors = require('cors');

const app = express();
const db = new Firestore();

app.use(cors());
app.use(express.json());

// 키워드 데이터 조회 API
app.get('/api/keyword/:keyword', async (req, res) => {
    try {
        const keyword = req.params.keyword;
        
        // 최근 데이터 조회
        const snapshot = await db
            .collection('keyword_data')
            .where('keyword', '==', keyword)
            .orderBy('timestamp', 'desc')
            .limit(1)
            .get();
        
        if (snapshot.empty) {
            // 데이터가 없으면 실시간 수집 요청
            const collectUrl = `${process.env.FUNCTION_BASE_URL}/naver-keyword-api?keyword=${keyword}`;
            const response = await fetch(collectUrl);
            const data = await response.json();
            
            return res.json(data);
        }
        
        // 기존 데이터 반환
        const doc = snapshot.docs[0];
        res.json(doc.data());
        
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// 트렌드 데이터 조회 API
app.get('/api/trend/:keyword', async (req, res) => {
    try {
        const keyword = req.params.keyword;
        
        const snapshot = await db
            .collection('trend_data')
            .where('keyword', '==', keyword)
            .orderBy('period', 'asc')
            .get();
        
        const trends = snapshot.docs.map(doc => doc.data());
        res.json(trends);
        
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

const port = process.env.PORT || 8080;
app.listen(port, () => {
    console.log(`Server running on port ${port}`);
});
```

### 5단계: React 프론트엔드

#### components/KeywordSearch.jsx
```jsx
import React, { useState } from 'react';

function KeywordSearch() {
    const [keyword, setKeyword] = useState('');
    const [data, setData] = useState(null);
    const [loading, setLoading] = useState(false);
    
    const handleSearch = async () => {
        if (!keyword) return;
        
        setLoading(true);
        try {
            const response = await fetch(
                `${process.env.REACT_APP_API_URL}/api/keyword/${keyword}`
            );
            const result = await response.json();
            setData(result);
        } catch (error) {
            console.error('Error:', error);
        } finally {
            setLoading(false);
        }
    };
    
    return (
        <div className="keyword-search">
            <div className="search-input">
                <input
                    type="text"
                    value={keyword}
                    onChange={(e) => setKeyword(e.target.value)}
                    placeholder="키워드 입력"
                />
                <button onClick={handleSearch} disabled={loading}>
                    {loading ? '검색 중...' : '검색'}
                </button>
            </div>
            
            {data && (
                <div className="search-results">
                    <h3>검색 결과: {keyword}</h3>
                    <div className="data-grid">
                        <div>PC 검색량: {data.keywordList?.[0]?.monthlyPcQcCnt}</div>
                        <div>모바일 검색량: {data.keywordList?.[0]?.monthlyMobileQcCnt}</div>
                        <div>경쟁도: {data.keywordList?.[0]?.compIdx}</div>
                    </div>
                </div>
            )}
        </div>
    );
}

export default KeywordSearch;
```

## 배포 스크립트

### deploy.sh
```bash
#!/bin/bash

echo "=== Phase 1 배포 시작 ==="

# 1. Cloud Functions 배포
echo "Cloud Functions 배포 중..."
cd functions/naver-keyword-api
gcloud functions deploy naver-keyword-api \
    --runtime python39 \
    --trigger-http \
    --allow-unauthenticated \
    --set-env-vars NAVER_ACCESS_KEY=$NAVER_ACCESS_KEY,NAVER_SECRET_KEY=$NAVER_SECRET_KEY,NAVER_CUSTOMER_ID=$NAVER_CUSTOMER_ID

cd ../naver-datalab-api
gcloud functions deploy naver-datalab-api \
    --runtime python39 \
    --trigger-http \
    --allow-unauthenticated

# 2. Cloud Run 배포
echo "Cloud Run 서비스 배포 중..."
cd ../../api-service
gcloud run deploy naver-api-service \
    --source . \
    --platform managed \
    --region asia-northeast1 \
    --allow-unauthenticated

# 3. Firebase 배포
echo "Frontend 배포 중..."
cd ../frontend
npm run build
firebase deploy --only hosting

echo "=== 배포 완료 ==="
```

## 모니터링 설정

### Cloud Monitoring 대시보드
```yaml
# monitoring-dashboard.yaml
displayName: "네이버 광고 데이터 Phase 1"
widgets:
  - title: "API 호출 횟수"
    scorecard:
      query: 'resource.type="cloud_function"'
  - title: "응답 시간"
    xyChart:
      query: 'resource.type="cloud_run_revision"'
  - title: "에러율"
    scorecard:
      query: 'severity="ERROR"'
```

## 테스트 계획

### 1. 기능 테스트
- [ ] 네이버 API 호출 정상 작동
- [ ] Firestore 데이터 저장/조회
- [ ] React 앱 정상 렌더링

### 2. 성능 테스트
- [ ] Apps Script vs Cloud Functions 응답 시간 비교
- [ ] 동시 요청 처리 성능 측정
- [ ] GCP 무료 티어 한도 확인

### 3. 안정성 테스트
- [ ] API 에러 처리 확인
- [ ] 네트워크 장애 시 복구
- [ ] 데이터 일관성 검증

## 다음 단계
1. [ ] Phase 1 구현 완료 후 사용자 피드백 수집
2. [ ] 성능 지표 분석 및 개선사항 도출
3. [ ] Phase 2 마이크로서비스 분해 계획 수립

---
**업데이트**: 2025-11-08  
**상태**: 구현 대기

---

**작성일**: 2025-11-08
