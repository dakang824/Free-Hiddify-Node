#!/usr/bin/env bash
# ============================================================
#  多源节点仓库维护：11 源抓取 -> 全量实测 -> 生成 -> 提交推送
#  由 launchd 每 12 小时调用
# ============================================================
set -uo pipefail

REPO="/Users/Zhuanz/WorkBuddy/2026-10-10-22-31-28/sub-repo"
OUT="$REPO/out"
PY=/Users/Zhuanz/.workbuddy/binaries/python/versions/3.13.12/bin/python3
LOG="$REPO/refresh.log"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG"; }

cd "$REPO" || exit 1
log "===== 开始多源刷新 ====="

# ---------- 1. 多源抓取 + 实测 ----------
if ! "$PY" "$REPO/fetch-multi.py" > /tmp/fetch_log.txt 2>&1; then
  log "抓取脚本异常，保留上一版"
  tail -20 /tmp/fetch_log.txt >> "$LOG" 2>/dev/null
  exit 1
fi
grep -E "^\[|已解析" /tmp/fetch_log.txt >> "$LOG"

if ! grep -qE "^\[多源抓取\] 完成" /tmp/fetch_log.txt; then
  log "抓取未完成，保留上一版"
  exit 1
fi

UNIQ=$(grep -oE "去重后 [0-9]+ 个唯一节点" /tmp/fetch_log.txt | grep -oE "[0-9]+" | tail -1)
ALIVE=$(grep -oE "完成，可用 [0-9]+ 个" /tmp/fetch_log.txt | grep -oE "[0-9]+" | tail -1)
UNIQ=${UNIQ:-0}; ALIVE=${ALIVE:-0}
log "去重节点 ${UNIQ} 个，可用 ${ALIVE} 个"

if [ "$ALIVE" -lt 20 ]; then
  log "可用节点过少（<20），保留上一版不更新"
  exit 1
fi

# ---------- 2. 生成配置 ----------
if ! "$PY" "$REPO/gen-config.py" >> "$LOG" 2>&1; then
  log "配置生成失败"
  exit 1
fi
NODES=$(grep -oE "写入配置 [0-9]+ 个节点" "$LOG" | tail -1 | grep -oE "[0-9]+" | tail -1)
log "已生成配置，${NODES:-?} 个节点"

# ---------- 3. 同步到 Hiddify ----------
HIDDY_CFG="$HOME/Library/Application Support/app.hiddify.com/configs/a7f3c21e-5b84-4d19-9e62-3c8f1a4b7d05.json"
if [ -d "$(dirname "$HIDDY_CFG")" ]; then
  cp "$OUT/singbox-verified.json" "$HIDDY_CFG" 2>/dev/null && log "已同步到 Hiddify 配置目录"
fi

# ---------- 4. 提交推送 ----------
git add -A out/ 2>/dev/null

if git diff --staged --quiet; then
  log "内容无变化，跳过提交"
  log "===== 刷新结束（无变化）====="
  exit 0
fi

git -c user.name="zhuanz-sub-bot" \
    -c user.email="dakang824@users.noreply.github.com" \
    commit -m "chore: 刷新节点 $(date '+%Y-%m-%d %H:%M') — ${ALIVE} 可用 / ${UNIQ} 唯一" >> "$LOG" 2>&1

export GIT_TERMINAL_PROMPT=0
export GIT_ASKPASS=/usr/bin/true

if git push origin main >> "$LOG" 2>&1; then
  log "推送成功"
  log "订阅: https://fastly.jsdelivr.net/gh/dakang824/Free-Hiddify-Node@main/out/singbox-verified.json"
else
  log "推送失败，请检查 SSH key 绑定情况"
fi

log "===== 刷新结束，${ALIVE} 个可用节点 ====="