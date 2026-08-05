#!/bin/bash
# 沙盒验证 .gitignore 白名单 + sync-memory.sh 行为(不触碰真实 ~/.hermes)
# 用例A:白名单只跟踪 memories/skills,敏感文件与 .lock 绝不入库
# 用例B:无变更时静默(exit 0,无输出)
# 用例C:有变更时提交并推送(exit 0,远端 HEAD 前移)
# 用例D:远端不可达时失败(exit 1,报错)
# 用法:bash scripts/verify-sync-sandbox.sh /path/to/sync-memory.sh
set -u
SCRIPT="${1:-$HOME/.hermes/scripts/sync-memory.sh}"
PASS=0; FAIL=0
ok()  { echo "  PASS: $1"; PASS=$((PASS+1)); }
bad() { echo "  FAIL: $1"; FAIL=$((FAIL+1)); }

bash -n "$SCRIPT" && ok "bash -n 脚本语法" || bad "语法检查"

TMP=$(mktemp -d /tmp/hermes-verify-XXXXXX)
trap 'rm -rf "$TMP"' EXIT
export HOME="$TMP/home"
H="$HOME/.hermes"
mkdir -p "$H/memories" "$H/skills/sample" "$H/scripts" "$H/sessions" "$H/.ssh"
git init --bare -q "$TMP/remote.git"

cp "$SCRIPT" "$H/scripts/sync-memory.sh" && chmod +x "$H/scripts/sync-memory.sh"
printf '/*\n!/memories/\n!/memories/**\n!/skills/\n!/skills/**\n!/.gitignore\n/memories/*.lock\n' > "$H/.gitignore"

printf '记忆A\n' > "$H/memories/MEMORY.md"
printf '技能X\n' > "$H/skills/sample/skill.md"
printf 'SECRET=xx\n' > "$H/.env"
printf '{"token":"yy"}\n' > "$H/auth.json"
printf 'sqlite\n' > "$H/state.db"
printf '历史\n' > "$H/sessions/old.jsonl"
: > "$H/memories/MEMORY.md.lock"

cd "$H" || exit 1
git init -qb main
git config user.name test; git config user.email test@local
git remote add origin "$TMP/remote.git"

# 用例A:白名单
git add -A
STAGED=$(git diff --cached --name-only)
LEAK=$(echo "$STAGED" | grep -E '\.env|auth\.json|state\.db|sessions/|\.ssh|\.lock' || true)
[ -z "$LEAK" ] && ok "白名单无泄露" || bad "白名单泄露: $LEAK"
echo "$STAGED" | grep -qE '^(memories/|skills/|\.gitignore$)' && ok "合法文件已入库" || bad "合法文件缺失"
git commit -qm init && git push -q origin main && ok "初始推送成功" || bad "初始推送"

# 用例B:无变更静默
OUT=$("$H/scripts/sync-memory.sh" 2>&1); RC=$?
[ $RC -eq 0 ] && [ -z "$OUT" ] && ok "无变更:静默且 exit=0" || bad "无变更:rc=$RC out='$OUT'"

# 用例C:变更→提交+推送(注意:HEAD_BEFORE 必须在运行脚本前捕获)
printf '新记忆\n' >> "$H/memories/MEMORY.md"
HEAD_BEFORE=$(git rev-parse main)
OUT=$("$H/scripts/sync-memory.sh" 2>&1); RC=$?
git fetch -q origin main 2>/dev/null || true
REMOTE_HEAD=$(git rev-parse origin/main 2>/dev/null || echo none)
echo "$OUT" | grep -q "已提交" && [ $RC -eq 0 ] && [ "$REMOTE_HEAD" != "$HEAD_BEFORE" ] \
  && ok "变更:提交+推送,远端 HEAD 前移" || bad "变更:rc=$RC out='$OUT'"

# 用例D:远端不可达→失败
printf '再一条\n' >> "$H/memories/MEMORY.md"
git remote set-url origin "/nonexistent/remote.git"
OUT=$("$H/scripts/sync-memory.sh" 2>&1); RC=$?
[ $RC -ne 0 ] && echo "$OUT" | grep -qE 'pull 失败|push 失败' \
  && ok "远端不可达:exit=$RC 且报错" || bad "远端不可达:rc=$RC out='$OUT'"

echo "===== 结果:$PASS 通过 / $FAIL 失败 ====="
[ $FAIL -eq 0 ]
