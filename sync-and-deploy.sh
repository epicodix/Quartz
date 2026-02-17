#!/bin/bash
set -e

CONTENT_DIR="./content"
DD_DIR="$CONTENT_DIR/AI_Paper/deep-dive"
QUARANTINE_DIR="$CONTENT_DIR/.quarantine"

# ── 1. Sync ──
echo "🔄 Syncing GEMINI folder to content..."
rsync -av --delete "$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/클라우드/GEMINI/" "$CONTENT_DIR/"
echo "✅ Sync complete!"

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

# ── 4. Deploy (변경사항 있을 때만) ──
git add .
if git diff --cached --quiet; then
    echo "📭 변경사항 없음. 커밋/푸시 스킵."
else
    echo "🚀 Deploying to GitHub..."
    git commit -m "Update content: $(date '+%Y-%m-%d %H:%M')"
    git push origin main
    echo "✅ Deployed!"
fi

# ── 5. Quarantine 복원 ──
if [ -d "$QUARANTINE_DIR" ] && ls "$QUARANTINE_DIR"/*.md 1>/dev/null 2>&1; then
    echo "🔄 Quarantine 파일 복원 중..."
    mv "$QUARANTINE_DIR"/*.md "$DD_DIR/"
    echo "✅ 복원 완료 (다음 배포 때 재검증)"
fi
rmdir "$QUARANTINE_DIR" 2>/dev/null || true

echo "🌐 Site should be live at: https://epicodix.github.io/Quartz/"
