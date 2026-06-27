#!/bin/bash
# 把 docs/widget 里的设计图同步进小组件资源目录（并压到 720×720，避开 WidgetKit 入包面积上限）。
# 用法：在仓库根目录执行 ./scripts/sync-widget-assets.sh
set -euo pipefail

cd "$(dirname "$0")/.."

ASSETS="SelfDisciplineWidget/Assets.xcassets"

# docs 源图 -> 资源名（状态）
declare -a MAP=(
  "docs/widget/fitness.png:bg_exercise"   # 运动
  "docs/widget/yexiao.png:bg_noSnack"     # 别吃夜宵
  "docs/widget/night.png:bg_readSleep"    # 阅读早睡
  "docs/widget/china.png:bg_default"      # 非时段（工作日/周末统一）
)

for entry in "${MAP[@]}"; do
  src="${entry%%:*}"
  name="${entry##*:}"
  dst="$ASSETS/$name.imageset/$name.png"
  cp "$src" "$dst"
  sips -z 720 720 "$dst" >/dev/null
  printf '%-13s <- %s\n' "$name" "$src"
done

echo "完成。重新 Run 到模拟器，桌面若仍是旧图请删掉小组件重新添加。"
