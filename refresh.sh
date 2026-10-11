#!/usr/bin/env bash
# ============================================================
#  节点仓库维护：抓取 -> 实测 -> 生成 -> 提交推送
#  由 launchd 每 12 小时调用一次
# ============================================================
set -uo pipefail

REPO="/Users/Zhuanz/WorkBuddy/2026-10-10-22-31-28/sub-repo"
OUT="$REPO/out"
SCRIPTS="/Users/Zhuanz/WorkBuddy/2026-10-10-22-31-28/hiddify-free-nodes/scripts"
PY=/Users/Zhuanz/.workbuddy/binaries/python/envs/default/bin/python3
LOG="/Users/Zhuanz/WorkBuddy/2026-10-10-22-31-28/sub-repo/refresh.log"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG"; }

log "===== 开始刷新 ====="

# ---------- 1. 拉取上游 ----------
JSD="https://cdn.jsdelivr.net/gh/Au1rxx/free-vpn-subscriptions@main/output/singbox.json"
if ! curl -sS --noproxy '*' -L -o /tmp/sb.json --max-time 90 "$JSD"; then
  log "拉取失败，跳过本次刷新"
  exit 1
fi
SZ=$(wc -c < /tmp/sb.json | tr -d ' ')
if ! head -c 1 /tmp/sb.json | grep -q '{' || [ "$SZ" -lt 10000 ]; then
  log "内容不是有效 JSON（疑似反爬拦截），跳过"
  exit 1
fi
log "拉取成功 ${SZ} 字节"

# ---------- 2. 全量实测 ----------
cd /tmp
if ! "$PY" "$SCRIPTS/deep_probe.py" > /tmp/probe_out.txt 2>&1; then
  log "实测脚本异常，跳过"
  tail -5 /tmp/probe_out.txt >> "$LOG"
  exit 1
fi
CNT=$(grep -oE '共 [0-9]+' /tmp/probe_out.txt | grep -oE '[0-9]+' | tail -1)
CNT=${CNT:-0}
log "实测完成，可用节点 ${CNT} 个"
grep -E "^结果分布|^可用协议" /tmp/probe_out.txt >> "$LOG"

if [ "$CNT" -lt 3 ]; then
  log "可用节点过少（<3），保留上一版不更新"
  exit 1
fi

# ---------- 3. 生成配置 ----------
if ! "$PY" "$SCRIPTS/build.py" > /tmp/build_out.txt 2>&1; then
  log "配置生成失败，跳过"
  tail -5 /tmp/build_out.txt >> "$LOG"
  exit 1
fi
NODES=$(grep -oE '节点数: [0-9]+' /tmp/build_out.txt | grep -oE '[0-9]+' | tail -1)
log "已生成配置，可用节点 ${NODES} 个"

# ---------- 4. 复制到仓库 ----------
cp "$REPO/../hiddify-free-nodes/hiddify-free-verified.json" "$OUT/singbox-verified.json" 2>/dev/null \
  || cp /Users/Zhuanz/WorkBuddy/2026-10-10-22-31-28/hiddify-free-nodes/hiddify-free-verified.json "$OUT/singbox-verified.json"

# 生成节点清单
"$PY" -c "
import json
d=json.load(open('$OUT/singbox-verified.json'))
ob=d['outbounds']
lines=['# 可用节点清单','> 自动生成 '+__import__('datetime').datetime.now().strftime('%Y-%m-%d %H:%M'),'','总数: %d'%len(ob),'','| # | 协议 | 服务器 | 端口 |','|---|---|---|---|']
for i,o in enumerate(ob,1):
    lines.append('| %d | %s | %s | %s |'%(i,o.get('type','?'),o.get('server','?'),o.get('server_port') or o.get('port','?')))
open('$OUT/NODES.md','w').write('\n'.join(lines)+'\n')
print('清单已生成')
"

# ---------- 5. 提交推送 ----------
cd "$REPO"
git add -A out/ README.md refresh.sh 2>/dev/null

if git diff --staged --quiet; then
  log "内容无变化，跳过提交"
  log "===== 刷新结束（无变化）====="
  exit 0
fi

COMMIT_MSG="chore: 刷新节点 $(date '+%Y-%m-%d %H:%M') — ${NODES} 个可用"
git -c user.name="zhuanz-sub-bot" \
    -c user.email="dakang824@users.noreply.github.com" \
    commit -m "$COMMIT_MSG" >> "$LOG" 2>&1

# 非交互式推送：launchd 下无 TTY，必须禁用提示
export GIT_TERMINAL_PROMPT=0
export GIT_ASKPASS=/usr/bin/true

if git push origin main >> "$LOG" 2>&1; then
  log "推送成功"
  log "订阅地址: https://cdn.jsdelivr.net/gh/dakang824/Free-Hiddify-Node@main/out/singbox-verified.json"
else
  log "推送失败。排查顺序："
  log "  1) SSH：确认公钥已加入 GitHub → Settings → SSH keys"
  log "     公钥: cat ~/.ssh/id_ed25519.pub"
  log "  2) HTTPS：改用 PAT方式"
  log "     git remote set-url origin https://github.com/dakang824/Free-Hiddify-Node.git"
  log "     git config --global credential.helper osxkeychain"
  log "     git push -u origin main  # 提示时输入用户名+PAT"
fi

log "===== 刷新结束，${NODES} 个节点 ====="