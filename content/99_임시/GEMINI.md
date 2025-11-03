# Gemini CLI 에이전트 블로그 스타일 가이드

## 1. 친절하고 균형 잡힌 어조

*   **전문성 유지**: 기술적인 내용을 다루되, 독자가 쉽게 이해할 수 있도록 전문 용어는 간결하게 설명합니다.
*   **긍정적이고 격려하는 어조**: 독자가 새로운 기술을 배우거나 문제를 해결하는 과정에서 자신감을 가질 수 있도록 돕습니다.
*   **균형 잡힌 시각**: 특정 기술이나 접근 방식의 장점뿐만 아니라, 고려해야 할 점이나 잠재적인 단점도 함께 제시하여 독자가 정보에 기반한 결정을 내릴 수 있도록 돕습니다.

## 2. 명확하고 간결한 문체

*   **직관적인 표현**: 복잡한 문장보다는 짧고 명료한 문장을 사용하여 의미 전달을 최우선으로 합니다.
*   **능동태 사용**: 가능한 한 능동태를 사용하여 글에 활력을 불어넣고, 주어를 명확히 합니다.
*   **불필요한 수식어 제거**: 핵심 내용을 흐리지 않도록 불필요한 형용사나 부사는 사용하지 않습니다.

## 3. 구조화된 콘텐츠

*   **제목과 소제목**: H1, H2, H3 등 적절한 제목과 소제목을 사용하여 글의 계층 구조를 명확히 하고, 독자가 내용을 빠르게 훑어볼 수 있도록 돕습니다.
*   **목록 활용**: 정보를 나열할 때는 순서 없는 목록(unordered list)이나 순서 있는 목록(ordered list)을 사용하여 가독성을 높입니다.
*   **코드 블록**: 코드 예시는 반드시 코드 블록(```)을 사용하여 본문과 구분하고, 언어를 명시하여 신택스 하이라이팅이 적용되도록 합니다.
*   **강조**: `인라인 코드`나 **볼드체**를 사용하여 중요한 용어나 개념을 강조합니다.

## 4. 실용적인 예시와 설명

*   **단계별 가이드**: 복잡한 절차는 단계별로 나누어 설명하고, 각 단계마다 명확한 지침을 제공합니다.
*   **실제 시나리오**: 독자가 직면할 수 있는 실제 문제 상황을 제시하고, 이에 대한 해결책을 구체적인 예시와 함께 설명합니다.
*   **시각 자료**: (가능하다면) 다이어그램, 스크린샷 등 시각 자료를 활용하여 이해를 돕습니다.

## 5. SEO 친화적인 글쓰기

*   **키워드 포함**: 주요 키워드를 제목, 소제목, 본문에 자연스럽게 포함하여 검색 엔진 최적화에 기여합니다.
*   **메타 설명**: (필요시) 블로그 게시물의 내용을 요약하는 간결하고 매력적인 메타 설명을 작성합니다.

## 6. 일관성 유지

*   **용어 통일**: 동일한 개념에 대해서는 항상 같은 용어를 사용합니다.
*   **서식 통일**: 글 전체에 걸쳐 일관된 서식 규칙을 적용합니다.

---

### 예시 (적용된 스타일)

```markdown
# NestJS에서 TypeORM과 PostgreSQL 연동하기

안녕하세요! 오늘은 NestJS 프로젝트에서 TypeORM을 사용하여 PostgreSQL 데이터베이스와 연동하는 방법에 대해 알아보겠습니다. 이 가이드는 백엔드 개발을 시작하는 분들에게 유용할 것입니다.

## 1. 프로젝트 설정

먼저, NestJS 프로젝트를 생성하고 필요한 패키지를 설치해야 합니다.

```bash
nest new my-nestjs-app
cd my-nestjs-app
npm install @nestjs/typeorm typeorm pg
```

## 2. 데이터베이스 연결 구성

`app.module.ts` 파일에 TypeORM 설정을 추가합니다.

```typescript
// src/app.module.ts
import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';

@Module({
  imports: [
    TypeOrmModule.forRoot({
      type: 'postgres',
      host: 'localhost',
      port: 5432,
      username: 'your_username',
      password: 'your_password',
      database: 'your_database',
      entities: [__dirname + '/**/*.entity{.ts,.js}'],
      synchronize: true, // 개발 환경에서만 사용 권장
    }),
  ],
})
export class AppModule {}
```

**참고**: `synchronize: true` 옵션은 개발 단계에서 엔티티 변경 시 자동으로 데이터베이스 스키마를 동기화해줍니다. 하지만 **운영 환경에서는 데이터 손실의 위험이 있으므로 사용하지 않는 것이 좋습니다.**

## 3. 엔티티 정의

`src/entities` 폴더에 `user.entity.ts` 파일을 생성하고 사용자 엔티티를 정의합니다.

```typescript
// src/entities/user.entity.ts
import { Entity, PrimaryGeneratedColumn, Column } from 'typeorm';

@Entity()
export class User {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ length: 500 })
  name: string;

  @Column()
  isActive: boolean;
}
```

이처럼 명확하고 구조화된 방식으로 정보를 전달하면 독자의 이해를 돕고, 블로그의 가치를 높일 수 있습니다.

## Gemini Added Memories
- 사용자 GitHub 계정: epicodix
- 프로젝트 네이밍 컨벤션:
    - **브랜딩/포트폴리오 관련 저장소:** `portfolio-<프로젝트-이름>` 또는 `branding-<프로젝트-이름>`
        *   예시: `portfolio-website`, `portfolio-v2`, `branding-assets`
    - **교육 및 실습 관련 저장소:** `edu-<주제>` 또는 `practice-<주제>` 또는 `lab-<주제>`
        *   예시: `edu-html-css`, `practice-react-todo`, `deepdive-cloud-native-labs`
    - **일반 프로젝트 저장소:** `project-<이름>` 또는 프로젝트의 핵심 기능을 나타내는 짧은 이름
        *   예시: `task-manager-api`, `image-gallery`
- 첫 프로젝트 설정:
    - 프로젝트 이름: `edu-cloud7-html`
    - 로컬 경로: `/Users/a1234/epicodix/edu-cloud7-html`
    - GitHub 연결 준비 완료 (사용자 GitHub 저장소 생성 및 연결 필요)
- Obsidian 파일 관리 규칙: Git 작업 및 교육 내용 관련 Obsidian 파일은 별도 카테고리 및 태그를 통해 관리 (예: `[[교육/구름딥다이브/클라우드네이티브]]`, `#git`, `#cloud-native`)