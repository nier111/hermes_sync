#!/usr/bin/env bash
# fetch_meme.sh - 从"发表情"站(fabiaoqing.com)搜索下载中文互联网梗图/表情包
# 用法: fetch_meme.sh <关键词> [输出路径]
# 示例: fetch_meme.sh 奶龙 /tmp/nailong.gif
#       fetch_meme.sh cheems /tmp/cheems.jpg
# 无 API key，免配置，走 img.soutula.com CDN（bmiddle 换 large 拿原图）

set -euo pipefail

KW="${1:?用法: fetch_meme.sh <关键词> [输出路径]}"
OUT="${2:-$HOME/.hermes/stickers/meme_$(date +%s).img}"
UA="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36"

# URL 编码关键词
ENC=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$KW")

# 搜索页抓懒加载图直链（data-original），bmiddle 尺寸换 large 拿原图
RAW=$(curl -sL "https://www.fabiaoqing.com/search/bqb/keyword/${ENC}" -H "User-Agent: ${UA}" \
  | grep -oE 'data-original="https://img\.soutula\.com/[^"]*"' \
  | sed 's/data-original="//; s/"$//; s|/bmiddle/|/large/|' \
  | sort -u)

if [ -z "$RAW" ]; then
  echo "ERROR: 关键词 '$KW' 没搜到表情包" >&2
  exit 1
fi

# 优先 gif，其次任意图；逐个尝试下载
PICK=$(echo "$RAW" | grep -i '\.gif$' | head -1 || true)
[ -z "$PICK" ] && PICK=$(echo "$RAW" | head -1)

for u in $RAW; do
  [ "$u" != "$PICK" ] && continue
  if curl -sL "$u" -o "$OUT" --max-time 30 \
       -H "Referer: https://www.fabiaoqing.com/" -H "User-Agent: ${UA}"; then
    if file "$OUT" | grep -qiE "gif|jpeg|png|webp"; then
      echo "OK: $OUT <- $u"
      echo "TYPE: $(file -b "$OUT")"
      echo "SIZE: $(du -h "$OUT" | cut -f1)"
      exit 0
    fi
  fi
done

echo "ERROR: 下载失败" >&2
rm -f "$OUT"
exit 1
