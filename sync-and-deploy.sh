#!/bin/bash
set -e

echo "🔄 Syncing GEMINI folder to content..."
rsync -av --delete "$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/클라우드/GEMINI/" ./content/
echo "✅ Sync complete!"

echo "🔨 Building Quartz site..."
npx quartz build
echo "✅ Build complete!"

echo "🚀 Deploying to GitHub..."
git add .
git commit -m "Update content: $(date '+%Y-%m-%d %H:%M')"
git push origin main
echo "✅ Deployed!"

echo "🌐 Site should be live at: https://epicodix.github.io/Quartz/"
