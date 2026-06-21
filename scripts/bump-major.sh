#!/bin/sh
# 升级大版本：MAJOR+1，MINOR 与 PATCH 归零。仅在你主动决定大改版时运行。
# 用法：./scripts/bump-major.sh
set -e

PBXPROJ="HealthApp.xcodeproj/project.pbxproj"
cur=$(grep -m1 -E 'MARKETING_VERSION = [0-9]' "$PBXPROJ" | sed -E 's/.*= ([0-9.]+);.*/\1/')
major=$(echo "$cur" | cut -d. -f1)
major=$((major + 1))
new="$major.0.0"
perl -i -pe "s/MARKETING_VERSION = [0-9][0-9.]*;/MARKETING_VERSION = $new;/g" "$PBXPROJ"

# version code 同步 +1（构建号必须单调递增）
code=$(grep -m1 -E 'CURRENT_PROJECT_VERSION = [0-9]' "$PBXPROJ" | sed -E 's/.*= ([0-9]+);.*/\1/')
newcode=$((${code:-0} + 1))
perl -i -pe "s/CURRENT_PROJECT_VERSION = [0-9]+;/CURRENT_PROJECT_VERSION = $newcode;/g" "$PBXPROJ"

git add "$PBXPROJ"
git commit --no-verify -m "chore: 升级大版本 $cur → $new (build $newcode)"
echo "→ 大版本已升级: $cur → $new   version code: $code → $newcode"
