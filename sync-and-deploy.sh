#!/bin/bash
echo " Syncing GEMINI folder to content..."
rsync -av --delete ~/Library/Mobile\ Documents/com~apple~CloudDocs/GEMINI/ ./content/
echo "✅ Sync complete!"

echo " Deploying to GitHub..."
git add .
git commit -m "Update content: $(date '+%Y-%m-%d %H:%M')"
git push origin main
echo " Deployed!"
