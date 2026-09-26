#!/usr/bin/env bash
#
# 上游出现新版本时，自动创建一个「直达链接型」Release（不附带任何二进制文件）。
# 由 .github/workflows/update-index.yml 在刷新索引后调用，也可以本地手动跑。
#
# 用法: ./scripts/publish-release.sh [--dry-run]
#
set -euo pipefail

cd "$(dirname "$0")/.."

command -v jq >/dev/null 2>&1 || { echo "需要 jq" >&2; exit 1; }
command -v gh >/dev/null 2>&1 || { echo "需要 gh (GitHub CLI)" >&2; exit 1; }

DRY_RUN=0
[ "${1:-}" = "--dry-run" ] && DRY_RUN=1

# 仓库坐标：优先环境变量，其次从 origin 推，最后退回默认值
REPO="${GH_REPO:-}"
if [ -z "$REPO" ]; then
  REPO=$(git remote get-url origin 2>/dev/null | sed -E 's#^(git@|https://|ssh://git@)github\.com[:/]##; s#\.git$##' || true)
fi
case "$REPO" in
  */*/*|"") REPO="ziyue67/workbuddy-linux" ;;   # 含代理前缀或推导失败时用默认值
esac

VERSION=$(jq -r '.channels["workbuddy-linux-x64-deb"].version // empty' index.json)
[ -n "$VERSION" ] || { echo "index.json 里没有版本号" >&2; exit 1; }
TAG="v$VERSION"

exists=0
if gh release view "$TAG" -R "$REPO" >/dev/null 2>&1; then
  exists=1
fi

notes=$(mktemp)
trap 'rm -f "$notes"' EXIT
./scripts/release-notes.sh >"$notes"

if [ "$DRY_RUN" -eq 1 ]; then
  printf '== 演练：仓库 %s，标签 %s，已存在=%s ==\n\n' "$REPO" "$TAG" "$exists" >&2
  cat "$notes"
  exit 0
fi

if [ "$exists" -eq 1 ]; then
  echo "Release $TAG 已存在，跳过（本脚本只负责发布新版本）"
  exit 0
fi

gh release create "$TAG" -R "$REPO" \
  --title "WorkBuddy for Linux $VERSION" \
  --notes-file "$notes" \
  --latest

echo "已创建 Release $TAG：https://github.com/$REPO/releases/tag/$TAG"
