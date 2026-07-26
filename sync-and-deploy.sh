#!/bin/bash
set -e

CONTENT_DIR="./content"
DD_DIR="$CONTENT_DIR/AI_Paper/deep-dive"
QUARANTINE_DIR="$CONTENT_DIR/.quarantine"
PAPER_OUTPUT_DIR="$HOME/daily-paper-summary/output"
DAILY_DIR="$CONTENT_DIR/AI_Paper/daily"
WEEKLY_DIR="$CONTENT_DIR/AI_Paper/weekly"

# ── 1. Sync ──
echo "🔄 Syncing local AI Paper output to Quartz content..."

if [ ! -d "$PAPER_OUTPUT_DIR" ]; then
    echo "❌ Local paper output directory is missing: $PAPER_OUTPUT_DIR"
    exit 1
fi

mkdir -p "$DAILY_DIR" "$WEEKLY_DIR" "$DD_DIR"

# launchd cannot reliably read the iCloud-backed Obsidian vault because of
# macOS TCC permissions. The generator's local output is the source of truth
# for deployment; Obsidian remains a separate copy for reading and editing.
rsync -av \
    --include='20??-??-??-summary.md' \
    --exclude='*' \
    "$PAPER_OUTPUT_DIR/" "$DAILY_DIR/"

rsync -av \
    --include='weekly-*.md' \
    --exclude='*' \
    "$PAPER_OUTPUT_DIR/" "$WEEKLY_DIR/"

if [ -d "$PAPER_OUTPUT_DIR/deep-dive" ]; then
    rsync -av "$PAPER_OUTPUT_DIR/deep-dive/" "$DD_DIR/"
fi

echo "✅ Local AI Paper sync complete!"

# ── 1-1. 키캡 이모지 제거 (CustomOgImages 오류 방지) ──
# U+FE0F (variation selector) + U+20E3 (combining enclosing keysign) 제거
echo "🧹 키캡 이모지 제거 중..."
find "$CONTENT_DIR" -name "*.md" -exec perl -i -pe 's/\x{ef}\x{b8}\x{8f}\x{e2}\x{83}\x{a3}//g' {} \;
echo "✅ 키캡 이모지 제거 완료"

# ── 2. 검증 게이트 ──
echo "🔍 Deep Dive 품질 검증 중..."
mkdir -p "$QUARANTINE_DIR"
QUARANTINED_LIST=""

if [ -d "$DD_DIR" ]; then
    for md_file in "$DD_DIR"/*.md; do
        [ -f "$md_file" ] || continue
        BASENAME=$(basename "$md_file" .md)
        REASON=""

        # 검증 1: GLM 호출 실패
        if grep -q "Deep Dive 분석 실패" "$md_file"; then
            REASON="GLM 실패"
        fi

        # 검증 2: 키캅 이모지
        if [ -z "$REASON" ] && grep -qP '[0-9]\x{FE0F}\x{20E3}|\x{1F51F}' "$md_file" 2>/dev/null; then
            REASON="키캅 이모지"
        fi
        # grep -P 미지원 시 fallback
        if [ -z "$REASON" ] && grep -q '0️⃣\|1️⃣\|2️⃣\|3️⃣\|4️⃣\|5️⃣\|6️⃣\|7️⃣\|8️⃣\|9️⃣\|🔟' "$md_file" 2>/dev/null; then
            REASON="키캅 이모지"
        fi

        # 검증 3: 본문 10줄 미만
        if [ -z "$REASON" ]; then
            # YAML frontmatter 이후 본문 줄 수 계산
            BODY_LINES=$(awk '/^---$/{n++;next} n>=2{print}' "$md_file" | grep -c '.' 2>/dev/null || echo "0")
            if [ "$BODY_LINES" -lt 10 ]; then
                REASON="본문 부족 (${BODY_LINES}줄)"
            fi
        fi

        # 실패 시 quarantine
        if [ -n "$REASON" ]; then
            mv "$md_file" "$QUARANTINE_DIR/"
            echo "QUARANTINED:${BASENAME}:${REASON}"
            QUARANTINED_LIST="${QUARANTINED_LIST}${BASENAME}:${REASON}\n"
        fi
    done
fi

if [ -n "$QUARANTINED_LIST" ]; then
    echo "⚠️  $(echo -e "$QUARANTINED_LIST" | grep -c '.' ) 파일 quarantine 처리됨"
else
    echo "✅ 모든 DD 파일 검증 통과"
fi

# ── 3. Build ──
echo "🔨 Building Quartz site..."
npx quartz build
echo "✅ Build complete!"

# ── 4. Deploy ──
git add .
if git diff --cached --quiet; then
    echo "📭 소스 변경사항 없음."
else
    echo "🚀 Committing source changes to GitHub (Backup)..."
    git commit -m "Update content: $(date '+%Y-%m-%d %H:%M')"
    if ! GIT_TERMINAL_PROMPT=0 git push origin main; then
        echo "⚠️  GitHub backup push failed; continuing with Cloudflare Pages deploy."
    fi
fi

echo "🚀 Deploying to Cloudflare Pages..."
# wrangler를 사용하여 빌드된 public 폴더를 직접 배포합니다.
npx wrangler pages deploy public --project-name=epicodix
echo "✅ Deployed to Cloudflare Pages!"

# ── 5. Search Engine Indexing (Ping) ──
echo "🔔 Notifying search engines of update..."
# Google Sitemap Ping (Legacy but often works)
curl -s "https://www.google.com/ping?sitemap=https://epicodix.pages.dev/sitemap.xml" > /dev/null
# IndexNow (Bing, Naver, etc.)
curl -s "https://www.bing.com/indexnow?url=https://epicodix.pages.dev/&key=7727bff7727bff7727bff7727bff7727" > /dev/null
echo "✅ Indexing pings sent!"

# ── 6. Quarantine 복원 ──
if [ -d "$QUARANTINE_DIR" ] && ls "$QUARANTINE_DIR"/*.md 1>/dev/null 2>&1; then
    echo "🔄 Quarantine 파일 복원 중..."
    mv "$QUARANTINE_DIR"/*.md "$DD_DIR/"
    echo "✅ 복원 완료 (다음 배포 때 재검증)"
fi
rmdir "$QUARANTINE_DIR" 2>/dev/null || true

echo "🌐 Site should be live at: https://epicodix.pages.dev"
