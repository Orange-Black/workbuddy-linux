#!/usr/bin/env bash
#
# 生成 index.json：四个官方 Linux 通道各自的最新版本、下载地址与接口声明的校验值。
# 数据来自腾讯官方更新接口，仓库里不存放任何腾讯的二进制包。
#
# 用法: ./scripts/update-index.sh [输出文件]   （默认 index.json）
#
set -euo pipefail

cd "$(dirname "$0")/.."
OUT="${1:-index.json}"

command -v jq >/dev/null 2>&1 || { echo "需要 jq" >&2; exit 1; }

CHANNELS=()
for arch in x64 arm64; do
  for type in deb rpm; do
    CHANNELS+=("$arch:$type")
  done
done

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT

entries="[]"
fail=0
for spec in "${CHANNELS[@]}"; do
  arch=${spec%%:*}; type=${spec##*:}
  echo "查询 workbuddy-linux-$arch-$type ..." >&2
  if json=$(./install.sh --check --json --arch "$arch" --channel "$type" 2>/dev/null); then
    # installed / up_to_date 是生成者本机的状态，不属于公共索引，去掉
    entries=$(jq -c --argjson e "$json" '. + [($e | del(.installed, .up_to_date))]' <<<"$entries")
  else
    echo "  失败" >&2
    fail=1
    entries=$(jq -c --arg a "$arch" --arg t "$type" \
      '. + [{"platform":("workbuddy-linux-" + $a + "-" + $t),"type":$t,"arch":$a,"error":"查询失败"}]' <<<"$entries")
  fi
done

jq -S --arg updated "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
  '{
     updated: $updated,
     source: "https://copilot.tencent.com/v2/update",
     note: "本索引只记录腾讯官方接口返回的元数据，不托管任何二进制包。官方 api_sha256 与实际下载文件的历史实测值不一致，请以实际下载后自行计算的 sha256 为准。",
     channels: (map({key: .platform, value: .}) | from_entries)
   }' <<<"$entries" >"$tmp"

# jq -S 会按键排序，channels 用 platform 当键方便机器读取
mv "$tmp" "$OUT"
trap - EXIT
echo "已写入 $OUT" >&2

# 任一通道查询失败就以非 0 退出：让 Action 红掉、不要提交残缺索引
exit "$fail"
