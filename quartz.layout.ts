import { PageLayout, SharedLayout } from "./quartz/cfg"
import * as Component from "./quartz/components"

// components shared across all pages
export const sharedPageComponents: SharedLayout = {
  head: Component.Head(),
  header: [],
  afterBody: [],
  footer: Component.Footer({
    links: {
      GitHub: "https://github.com/jackyzha0/quartz",
      "Discord Community": "https://discord.gg/cRFFHYye7t",
    },
  }),
}

// components for pages that display a single page (e.g. a single note)
export const defaultContentPageLayout: PageLayout = {
  beforeBody: [
    Component.ConditionalRender({
      component: Component.Breadcrumbs(),
      condition: (page) => page.fileData.slug !== "index",
    }),
    Component.ArticleTitle(),
    Component.ContentMeta(),
    Component.TagList(),
  ],
  left: [
    Component.PageTitle(),
    Component.MobileOnly(Component.Spacer()),
    Component.Flex({
      components: [
        {
          Component: Component.Search(),
          grow: true,
        },
        { Component: Component.Darkmode() },
        { Component: Component.ReaderMode() },
      ],
    }),
    Component.Explorer({ 
      folderClickBehavior: "collapse",
      filterFn: (node) => {
        // 임시 폴더 및 불필요한 폴더 숨기기
        const hiddenFolders = ["99_임시", "tags", ".obsidian"];
        if (hiddenFolders.includes(node.slugSegment)) {
          return false;
        }
        
        // GEMINI 루트의 단독 파일들 숨기기 (폴더에 속하지 않은 파일들)
        if (!node.isFolder && node.data) {
          const hiddenFiles = [
            "GUI_자동화_도전기",
            "Gemini_CLI_활용_가이드", 
            "Ollama_Troubleshooting_Guide",
            "gemini_cli_guide",
            "gemini_cli_introduction",
            "gemini_context_awareness_guide",
            "gemini_file_management_guide",
            "get_claude_news.py",
            "global_news_20250712",
            "kubernetes_cheatsheet", 
            "kubernetes_storage_hands_on",
            "naver_gmail_integration_guide",
            "nodejs_installation_guide",
            "내_컴퓨터를_AI_서버로_만들기_Ollama_설치_및_문제해결_가이드",
            "시리와_Gemini_연계성_강화_방안",
            "2025-08-13_학습_포인트",
            "07_02_Advanced_Pod_Concepts"
          ];
          
          // 파일 제목에서 확장자 제거하고 비교
          const fileTitle = node.data.title || node.displayName.replace(/\.md$/, '');
          return !hiddenFiles.includes(fileTitle);
        }
        
        return true;
      },
      mapFn: (node) => {
        // 폴더명 개선 매핑
        const folderDisplayNames = {
          "1_가이드": "📖 가이드",
          "2_기술_분석": "🔬 기술 분석", 
          "3_아이디어_뉴스": "💡 아이디어 & 뉴스",
          "K8s_Deep_Dive": "⚙️ 쿠버네티스 딥다이브",
          "01_네트워크 기초": "🌐 네트워크 기초",
          "02_k8s실습": "🛠️ 실습",
          "03_프로메테우스": "📊 프로메테우스",
          "04_그라파나": "📈 그라파나",
          "교육": "📚 교육",
          "구름딥다이브": "☁️ 구름딥다이브",
          "분산시스템_Distributed Systems": "🔗 분산시스템",
          "GO": "🐹 Go 언어",
          "네이버-검색광고-마이그레이션-프로젝트": "🚀 네이버 프로젝트",
          "01-프로젝트-배경": "📋 프로젝트 배경",
          "02-현재상태-분석": "🔍 현재상태 분석", 
          "03-마이그레이션-계획": "📝 마이그레이션 계획",
          "05-운영-최적화": "⚡ 운영 최적화",
          "CKA": "🎯 CKA 자격증",
          "GCP": "☁️ Google Cloud",
          "moc-k8s": "📚 쿠버네티스 노트",
          "Vagrant": "📦 Vagrant",
          "포트폴리오": "💼 포트폴리오",
          "가상화": "💻 가상화",
          "개발환경": "🛠️ 개발환경", 
          "기타": "📎 기타",
          "AI도구": "🤖 AI 도구",
          "모니터링": "📊 모니터링"
        };
        
        if (node.isFolder && folderDisplayNames[node.displayName]) {
          node.displayName = folderDisplayNames[node.displayName];
        }
        
        // 파일명 정리 (번호 패턴 제거 및 간소화)
        if (!node.isFolder && node.data) {
          let displayName = node.data.title || node.displayName;
          
          // 번호 패턴 제거 (예: "01_", "02_", "00_" 등)
          displayName = displayName.replace(/^(\d{2}_|\d{2}-\d{2}-)/g, '');
          
          // 긴 제목 줄임 (50자 초과시)
          if (displayName.length > 50) {
            displayName = displayName.substring(0, 47) + '...';
          }
          
          // 특정 패턴 정리
          displayName = displayName
            .replace(/^kubernetes_/, 'K8s ')
            .replace(/^쿠버네티스_/, 'K8s ')
            .replace(/_완벽_가이드$/, ' 가이드')
            .replace(/_실습_가이드$/, ' 실습')
            .replace(/_핵심_정리$/, ' 정리')
            .replace(/_기초_개념$/, ' 기초')
            .replace(/완전_가이드$/, '가이드')
            .replace(/완벽_정리$/, '정리');
          
          node.displayName = displayName;
        }
        
        return node;
      },
      sortFn: (a, b) => {
        // 우선순위 폴더 정의 (이모지 포함된 이름으로 업데이트)
        const priorityFolders = [
          "📖 가이드", 
          "🔬 기술 분석", 
          "⚙️ 쿠버네티스 딥다이브",
          "📚 교육",
          "💼 포트폴리오"
        ];
        
        if (a.isFolder && b.isFolder) {
          const aPriority = priorityFolders.indexOf(a.displayName);
          const bPriority = priorityFolders.indexOf(b.displayName);
          
          // 우선순위 폴더끼리 비교
          if (aPriority !== -1 && bPriority !== -1) {
            return aPriority - bPriority;
          }
          // 우선순위 폴더가 일반 폴더보다 앞에
          if (aPriority !== -1) return -1;
          if (bPriority !== -1) return 1;
        }
        
        // 기본 정렬 (폴더 우선, 이후 알파벳 순)
        if ((!a.isFolder && !b.isFolder) || (a.isFolder && b.isFolder)) {
          return a.displayName.localeCompare(b.displayName, 'ko-KR', {
            numeric: true,
            sensitivity: "base",
          });
        }
        
        return a.isFolder ? -1 : 1;
      }
    }),
  ],
  right: [
    Component.Graph(),
    Component.DesktopOnly(Component.TableOfContents()),
    Component.Backlinks(),
  ],
}

// components for pages that display lists of pages  (e.g. tags or folders)
export const defaultListPageLayout: PageLayout = {
  beforeBody: [Component.Breadcrumbs(), Component.ArticleTitle(), Component.ContentMeta()],
  left: [
    Component.PageTitle(),
    Component.MobileOnly(Component.Spacer()),
    Component.Flex({
      components: [
        {
          Component: Component.Search(),
          grow: true,
        },
        { Component: Component.Darkmode() },
      ],
    }),
    Component.Explorer({ 
      folderClickBehavior: "collapse",
      filterFn: (node) => {
        const hiddenFolders = ["99_임시", "tags", ".obsidian"];
        return !hiddenFolders.includes(node.slugSegment);
      }
    }),
  ],
  right: [],
}
