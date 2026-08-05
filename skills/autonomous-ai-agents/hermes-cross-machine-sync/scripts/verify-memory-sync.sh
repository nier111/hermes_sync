#!/bin/bash
# 沙盒验证 sync-memory.sh 与白名单 .gitignore 的行为。
# 用法:bash verify-memory-sync.sh [sync-script-path] [hermes-home]
#   默认:${HERMES_HOME:-$HOME/.hermes}/scripts/sync-memory.sh 与 ${HERMES_HOME:-$HOME/.hermes}
# 在隔离的 fake HOME + 本地 bare remote 中跑 4 个用例;任一失败则退出非零。
# 注意:被测脚本通过 $HOME/.hermes 定位仓库,所以覆盖 HOME 即可让它在沙盒里运行。
set -u
HERMES_HOME="${2:-${HERMES_HOME:-$HOME/.hermes}}"
SYNC_SCRIPT="${1:-$HERMES_HOME/scripts/sync-memory.sh}"

PASS=0; FAIL=0
ok()  { echo "  PASS: $1"; PASS=$((PASS+1)); }
bad() { echo "  FAIL: $1"; FAIL=$((FAIL+1)); }

[ -f "$SYNC_SCRIPT" ] || { echo "sync script not found: $SYNC_SCRIPT"; exit 2; }
[ -f "$HERMES_HOME/.gitignore" ] || bad "真实 .gitignore 缺失($HERMES_HOME/.gitignore)"
bash -n "$SYNC_SCRIPT" && ok "bash -n 语法" || bad "语法检查"

TMP=$(mktemp -d /tmp/hermes-verify-XXXXXX)
trap 'rm -rf "$TMP"' EXIT
export HOME="$TMP/home"
H="$HOME/.hermes"
mkdir -p "$H/memories" "$H/skills/sample" "$H/scripts" "$H/sessions" "$H/.ssh"
git init --bare -q "$TMP/remote.git"

# 沙盒内自建白名单(自包含;真实文件另做存在性检查)
cat > "$H/.gitignore" <<'EOF'
/*
!/memories/
!/memories/**
!/skills/
!/skills/**
!/.gitignore
/memories/*.lock
/skills/**/*.lock
EOF

cp "$SYNC_SCRIPT" "$H/scripts/sync-memory.sh"; chmod +x "$H/scripts/sync-memory.sh"

# 样本:合法内容 + 敏感/噪音文件
printf '记忆A\n' > "$H/memories/MEMORY.md"
printf '用户B\n' > "$H/memories/USER.md"
printf '技能X\n' > "$H/skills/sample/skill.md"
printf 'SECRET=xx\n' > "$H/.env"
printf '{"token":"yy"}\n' > "$H/auth.json"
printf 'sqlite\n' > "$H/state.db"
printf '历史\n' > "$H/sessions/old.jsonl"
printf 'key\n' > "$H/.ssh/id_ed25519"
: > "$H/memories/MEMORY.md.lock"

cd "$H" || exit 1
git init -qb main
git config user.name test; git config user.email test@local
git remote add origin "$TMP/remote.git"

# 用例A:白名单——敏感/锁文件绝不入库,合法文件入库
git add -A
STAGED=$(git diff --cached --name-only)
LEAK=$(echo "$STAGED" | grep -E '\.env|auth\.json|state\.db|sessions/|\.ssh|\.lock' || true)
[ -z "$LEAK" ] && ok "白名单无泄露(敏感/锁文件未入库)" || bad "白名单泄露: $LEAK"
ALLOWED=$(echo "$STAGED" | grep -cE '^(memories/|skills/|\.gitignore$)')
[ "$ALLOWED" -ge 4 ] && ok "合法文件已入库($ALLOWED 个)" || bad "合法文件缺失"
git commit -qm init
git push -q origin main && ok "初始推送成功" || bad "初始推送"

# 用例B:无变更 → 静默且 exit 0
OUT=$("$H/scripts/sync-memory.sh" 2>&1); RC=$?
[ $RC -eq 0 ] && [ -z "$OUT" ] && ok "无变更:静默且 exit=0" || bad "无变更:rc=$RC out='$OUT'"

# 用例C:变更 → 提交+推送,远端 HEAD 前移
# 坑:HEAD_BEFORE 必须在被测脚本运行前采集(运行后再取就是新旧对比,必假失败)
printf '新记忆\n' >> "$H/memories/MEMORY.md"
HEAD_BEFORE=$(git rev-parse main)
OUT=$("$H/scripts/sync-memory.sh" 2>&1); RC=$?
git fetch -q origin main 2>/dev/null || true
REMOTE_HEAD=$(git rev-parse origin/main 2>/dev/null || echo none)
echo "$OUT" | grep -q "已提交" && [ $RC -eq 0 ] && [ "$REMOTE_HEAD" != "$HEAD_BEFORE" ] \
  && ok "变更:提交+推送,远端 HEAD 前移(${REMOTE_HEAD:0:7})" || bad "变更:rc=$RC out='$OUT'"

# 用例D:远端不可达 → exit 非零且报错
printf '再一条\n' >> "$H/memories/MEMORY.md"
git remote set-url origin "/nonexistent/remote.git"
OUT=$("$H/scripts/sync-memory.sh" 2>&1); RC=$?
[ $RC -ne 0 ] && echo "$OUT" | grep -qE 'pull 失败|push 失败' \
  && ok "远端不可达:exit=$RC 且报错" || bad "远端不可达:rc=$RC out='$OUT'"

echo "===== 结果:$PASS 通过 / $FAIL 失败 ====="
[ $FAIL -eq 0 ]
