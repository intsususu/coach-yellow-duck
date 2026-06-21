#!/bin/sh
# 升级小版本：第一位小数（MINOR）+1，PATCH 归零。
# 用法：create PR 前，确认要升小版本时运行  ./scripts/bump-minor.sh
set -e

PBXPROJ="HealthApp.xcodeproj/project.pbxproj"
cur=$(grep -m1 -E 'MARKETING_VERSION = [0-9]' "$PBXPROJ" | sed -E 's/.*= ([0-9.]+);.*/\1/')
major=$(echo "$cur" | cut -d. -f1)
minor=$(echo "$cur" | cut -d. -f2)
minor=$((minor + 1))
new="$major.$minor.0"
perl -i -pe "s/MARKETING_VERSION = [0-9][0-9.]*;/MARKETING_VERSION = $new;/g" "$PBXPROJ"

# version code 同步 +1（构建号必须单调递增）
code=$(grep -m1 -E 'CURRENT_PROJECT_VERSION = [0-9]' "$PBXPROJ" | sed -E 's/.*= ([0-9]+);.*/\1/')
newcode=$((${code:-0} + 1))
perl -i -pe "s/CURRENT_PROJECT_VERSION = [0-9]+;/CURRENT_PROJECT_VERSION = $newcode;/g" "$PBXPROJ"

git add "$PBXPROJ"
# --no-verify 跳过 pre-commit，避免 PATCH 又被 +1
git commit --no-verify -m "chore: 升级小版本 $cur → $new (build $newcode)"
echo "→ 小版本已升级: $cur → $new   version code: $code → $newcode"
