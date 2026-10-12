#!/usr/bin/env bash
# ============================================================
#  安装/重载「每天 12:00 刷新节点」定时任务
#  在你自己的终端里执行本脚本（沙箱环境无法操作 launchctl）
# ============================================================
set -uo pipefail

PLIST="$HOME/Library/LaunchAgents/com.zhuanz.hiddify.nodes.plist"
SCRIPT="$HOME/WorkBuddy/2026-10-10-22-31-28/sub-repo/refresh.sh"
UID_=$(id -u)

echo "=========================================="
echo " 安装每日 12:00 定时刷新任务"
echo "=========================================="

# 1. 前置检查
if [ ! -f "$PLIST" ]; then
  echo "✗找不到 plist：$PLIST"
  exit 1
fi
if [ ! -f "$SCRIPT" ]; then
  echo "✗ 找不到 refresh.sh：$SCRIPT"
  exit 1
fi
chmod +x "$SCRIPT" 2>/dev/null

# 2. 语法校验
if ! plutil -lint "$PLIST" >/dev/null 2>&1; then
  echo "✗ plist 语法错误"
  plutil -lint "$PLIST"
  exit 1
fi
echo "✓ plist 语法正确"

# 3. 确认调度配置
python3 - "$PLIST" <<'PY'
import plistlib, sys
d = plistlib.load(open(sys.argv[1], 'rb'))
s = d.get('StartCalendarInterval')
if s:
    print("✓ 调度：每天 %02d:%02d" % (s['Hour'], s['Minute']))
elif 'StartInterval' in d:
    print("✓ 调度：每 %d 秒" % d['StartInterval'])
else:
    print("✗ 未找到调度配置")
PY

# 4. 先卸载旧的（忽略错误）
launchctl bootout "gui/$UID_/$PLIST" 2>/dev/null
launchctl unload "$PLIST" 2>/dev/null

# 5. 加载
echo ""
echo "正在加载任务..."
if launchctl bootstrap "gui/$UID_" "$PLIST" 2>/dev/null; then
  echo "✓ 加载成功（bootstrap）"
elif launchctl load -w "$PLIST" 2>/dev/null; then
  echo "✓ 加载成功（load）"
else
  echo "✗ 加载失败，请尝试：sudo launchctl bootstrap gui/$UID_ $PLIST"
  exit 1
fi

# 6. 验证
echo ""
sleep 1
if launchctl list 2>/dev/null | grep -q "com.zhuanz.hiddify.nodes"; then
  echo "=========================================="
  echo " ✓ 安装完成"
  echo "=========================================="
  launchctl list | grep "com.zhuanz.hiddify.nodes"
  echo ""
  echo "任务标识 : com.zhuanz.hiddify.nodes"
  echo "执行时间 : 每天 12:00（本地时间）"
  echo "执行内容 : 多源抓取 → 实测 → 生成配置 → 推送 GitHub"
  echo "日志     : $HOME/WorkBuddy/2026-10-10-22-31-28/sub-repo/refresh.log"
  echo ""
  echo "常用命令："
  echo "  查看状态 : launchctl list | grep com.zhuanz.hiddify.nodes"
  echo "  立即执行 : launchctl start com.zhuanz.hiddify.nodes"
  echo "  卸载     : launchctl bootout gui/$UID_/$PLIST"
else
  echo "✗ 任务未出现在列表中，请手动检查"
fi