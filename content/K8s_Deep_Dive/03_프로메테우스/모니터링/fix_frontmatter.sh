#!/bin/bash

for file in 02-* 03-* 04-* 06-* 07-* 08-* 09-*; do
  if [ -f "$file" ]; then
    # category와 status, priority 필드 추가
    sed -i '' '/^category:/d' "$file"
    sed -i '' '/^status:/d' "$file"
    sed -i '' '/^priority:/d' "$file"
    sed -i '' '/^---$/a\
title: '"$(grep "^# " "$file" | head -1 | sed 's/^# //')"'\
aliases:\
  - '"$(basename "$file" .md)"'\
category: K8s_Deep_Dive/프로메테우스/모니터링\
status: 완성\
priority: 높음
' "$file" 2>/dev/null || echo "Processing $file..."
  fi
done
