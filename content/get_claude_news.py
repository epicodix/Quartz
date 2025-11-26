import requests
from bs4 import BeautifulSoup

def get_latest_claude_news_from_blog(url):
    """
    주어진 URL의 블로그에서 최신 Claude 관련 뉴스 제목을 가져옵니다.
    이 함수는 예시이며, 실제 웹사이트 구조에 따라 수정이 필요합니다.
    """
    try:
        response = requests.get(url)
        response.raise_for_status()  # HTTP 오류 발생 시 예외 발생

        soup = BeautifulSoup(response.text, 'html.parser')

        # 예시: 블로그 글 제목이 'h2' 태그 안에 'entry-title' 클래스로 있다고 가정
        # 실제 웹사이트의 HTML 구조를 분석하여 정확한 셀렉터를 찾아야 합니다.
        titles = soup.find_all('h2', class_='entry-title')
        
        news_items = []
        for title_tag in titles:
            link_tag = title_tag.find('a')
            if link_tag:
                title = link_tag.get_text(strip=True)
                link = link_tag['href']
                # 'Claude' 또는 'Anthropic' 키워드가 포함된 제목만 필터링
                if 'claude' in title.lower() or 'anthropic' in title.lower():
                    news_items.append({'title': title, 'link': link})
        
        return news_items

    except requests.exceptions.RequestException as e:
        print(f"웹 페이지를 가져오는 중 오류 발생: {e}")
        return []
    except Exception as e:
        print(f"데이터 파싱 중 오류 발생: {e}")
        return []

if __name__ == "__main__":
    # Anthropic 공식 블로그 URL (예시, 실제 URL로 대체해야 함)
    # 실제 Anthropic 블로그 URL은 https://www.anthropic.com/news 입니다.
    anthropic_blog_url = "https://www.anthropic.com/news" 
    
    print(f"'{anthropic_blog_url}'에서 Claude 관련 최신 뉴스 수집 중...")
    latest_news = get_latest_claude_news_from_blog(anthropic_blog_url)

    if latest_news:
        print("\n--- 최신 Claude 뉴스 ---")
        for item in latest_news:
            print(f"제목: {item['title']}")
            print(f"링크: {item['link']}")
            print("-" * 20)
    else:
        print("최신 Claude 뉴스를 찾을 수 없거나 오류가 발생했습니다.")

    # --- X(트위터)와 같은 소셜 미디어 정보 수집에 대한 설명 ---
    print("\n--- X(트위터)와 같은 소셜 미디어 정보 수집 ---")
    print("X(트위터)와 같은 소셜 미디어 플랫폼에서 정보를 수집하려면 해당 플랫폼의 API를 사용해야 합니다.")
    print("API 사용은 일반적으로 개발자 계정 등록, API 키 발급, 그리고 사용량 제한 및 정책 준수가 필요합니다.")
    print("예를 들어, Python에서는 `tweepy`와 같은 라이브러리를 사용하여 X API와 상호작용할 수 있습니다.")
    print("하지만 API 키 없이는 직접적인 예시 코드를 제공하기 어렵습니다.")
    print("개념적으로는 특정 키워드(예: 'Claude', 'Anthropic')를 포함하는 트윗을 검색하고, 이를 필터링하여 수집하는 방식이 됩니다.")