#!/bin/bash
# Hermes 记忆同步脚本:拉取远端 → 提交本地变更 → 推送
# 无变更时静默退出(exit 0);有变更时输出摘要;失败时输出错误(exit 1)
# 适配 cron no_agent 语义:空输出 = 静默,非零退出 = 错误告警
set -u
cd "$HOME/.hermes" || exit 1

# 拉取远端(允许未配置远端时静默失败)
if ! git pull --rebase --autostash origin main >/dev/null 2>&1; then
  echo "[sync] pull 失败(远端未配置或冲突)" >&2
  exit 1
fi

# 提交本地变更(仅 memories/ 与 skills/,白名单见 .gitignore)
git add -A
if git diff --cached --quiet; then
  exit 0  # 无变更,静默
fi

CHANGED=$(git diff --cached --name-only | wc -l)
git commit -q -m "sync $(date '+%F %T')" || { echo "[sync] commit 失败" >&2; exit 1; }
echo "[sync] 已提交 $(git log -1 --format=%h) ($CHANGED 个文件)"

if ! git push origin main >/dev/null 2>&1; then
  echo "[sync] push 失败" >&2
  exit 1
fi
echo "[sync] 已推送"
