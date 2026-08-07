---
name: sticker-emoji
description: "Use when sending stickers/GIFs as chat emotion."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos]
metadata:
  hermes:
    tags: [sticker, gif, emoji, media, chat]
---

# 表情包发送(本地表情库)

聊天中作为情绪表达主动发表情包。**原则:气氛合适就发,不等用户要求,不刷屏。**

## 表情包库

- 位置:`~/.hermes/stickers/`
- **索引必读**:`~/.hermes/stickers/INDEX.md`(每张图的内容与适用场景)
- 发送方式:回复中带 `MEDIA:/home/sato/.hermes/stickers/<文件名>`

## 常用表情

- 猫猫系列 `cat*.gif`:卖萌/治愈/安慰/惊喜,轮换用避免重复
- `cheems.jpg`:丧/躺平/自嘲(用户钦定,别用在开心场景)
- `nailong.gif`:奶龙,憨憨/可爱/犯蠢(用户钦定)
- `huanggold.gif`:用户添加,用途待确认

## 获取新表情

1. 猫猫(免key):
   ```bash
   curl -sL -x http://127.0.0.1:7890 "https://cataas.com/cat/gif?t=$(date +%s%N)" -o ~/.hermes/stickers/cat_xxx.gif
   ```
   cataas 会报超时但文件可完整下载,用 PIL 验证帧数后再用;下载后更新 INDEX.md
2. 关键词搜索:`gif-search` skill(需 TENOR_API_KEY,未配置)
3. 用户手动添加:直接放目录+更新索引

## Pitfalls

- GIF 过大(>4MB)可能发送失败,优先选小文件
- 图片质量用 PIL 验证:`Image.open(f); f.seek(0); f.n_frames`
- 新下载的图必须登记进 INDEX.md,否则下次找不到用途
