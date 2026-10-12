# 免费节点订阅仓库

> 由本地脚本每 12 小时自动刷新并推送。**订阅请使用 jsDelivr 地址**（GitHub raw 在国内被墙）。

## 订阅地址

**推荐（fastly 端点，实测最稳）：**
```
https://fastly.jsdelivr.net/gh/dakang824/Free-Hiddify-Node@main/out/singbox-verified.json
```

**备用端点（任选其一，内容完全相同）：**

| 端点 | 状态 |
|---|---|
| `https://fastly.jsdelivr.net/gh/dakang824/Free-Hiddify-Node@main/out/singbox-verified.json` | 推荐 |
| `https://testingcf.jsdelivr.net/gh/dakang824/Free-Hiddify-Node@main/out/singbox-verified.json` | 可用 |
| `https://jsdelivr.b-cdn.net/gh/dakang824/Free-Hiddify-Node@main/out/singbox-verified.json` | 可用 |
| `https://cdn.jsdelivr.net/gh/dakang824/Free-Hiddify-Node@main/out/singbox-verified.json` | **本机被 reset，勿用** |

> ⚠️ 不要使用 `raw.githubusercontent.com`，该域名在大陆被墙。
> ⚠️ 本机实测 `cdn.jsdelivr.net` 主域出现 `Connection reset by peer`，故推荐 fastly 端点。
> ⚠️ push 后 jsDelivr 有约 5 分钟缓存延迟。

## 客户端导入

Hiddify：首页 → 配置 → 右上角「+」→ 从剪贴板导入，粘贴上面的地址。
其他客户端（Clash Verge / v2rayN / NekoBox）需改用 `clash.yaml` 或 `v2ray-base64` 格式。

## 内容说明

| 文件 | 说明 |
|---|---|
| `out/singbox-verified.json` | Hiddify 直接可用，仅含 `outbounds` 字段 |
| `out/NODES.md` | 节点清单（协议 / 服务器 / 端口） |

**只有实测连通的节点才会被收录。** 流水线会做 TCP + TLS 握手验证，可用率通常在 2% 左右。

## 安全提醒

本仓库内的节点均为**第三方公开共享资源**：

- 节点所有者可看到经由该节点的全部流量
- **禁止用于登录银行、邮箱、支付等敏感账号**
- 仅建议用于临时访问公开内容
- 真正需要隐私保护请自建 VPS 或使用付费服务

## 自动刷新机制

本地 `refresh.sh` 由 launchd 每 12 小时执行：

1. **多源抓取**（11 个公开源，自动经jsDelivr 拉取，绕开 GitHub 封锁）
2. **格式统一**（singbox-json / clash-yaml / v2ray-base64 / v2ray-plain 四种格式自动解析）
3. **全量实测**（DNS 串行解析 + TCP 并发连接验证）
4. **生成配置**（仅保留实测可用节点，按延迟排序）
5. **同步到 Hiddify + Git 推送**

### 多源 vs 单源实测对比

| 策略 | 唯一节点 | 可用 | 可用率 |
|---|---|---|---|
| 单源（Au1rxx） | 1,882 | 34 | **1.8%** |
| **多源聚合（11 源）** | 4,676 | 1,877 | **40.2%** |

多源策略使可用率提升约 22 倍。

### 各源贡献

| 源 | 解析节点数 |
|---|---|
| barry-far | 7,608 |
| ishalumi | 2,673 |
| Au1rxx | 1,818 |
| xingchaoet | 1,756 |
| peasoft | 544 |
| free-nodes | 593 |
| Ruk1ng001 | 475 |
| ts-sf | 201 |
| free18 | 215 |
| wanghaisheng | 141 |
| snakem982 | 59 |

日志：`refresh.log` ｜ 手动触发：`bash refresh.sh`
---

## 双重定时机制

本仓库同时使用两套定时机制，各司其职：

### 1. 本地 launchd（主力，负责实测）

- **频率**：每天 12:00（本地时间）
- **脚本**：`refresh.sh`
- **职责**：11 源抓取 → **在中国大陆出口做 TCP 实测筛选** → 生成配置 → 推送
- **意义**：这是唯一可信的可用性依据

```bash
# 查看状态
launchctl print gui/$(id -u)/com.zhuanz.hiddify.nodes | grep -E "state|runs"
# 立即手动执行
launchctl start gui/$(id -u)/com.zhuanz.hiddify.nodes
```

### 2. GitHub Actions（兜底，负责抓取）

- **文件**：`.github/workflows/auto-refresh.yml`
- **频率**：每天 12:00（`cron: '0 4 * * *'` UTC = 北京时间 12:00）
- **职责**：抓取并发布，但**不做连通性实测**

### ⚠️ 为什么 Actions 不能替代本地实测

GitHub Actions 的 runner 位于**美国机房**。它实测通过的节点，对中国大陆用户未必可用。

实测数据：本机（大陆出口）筛出的可用节点中，约 **17% 是 Cloudflare / 美欧机房 IP**（172.64-172.67、104.16-104.31 等）。这类节点在美区 runner 上会被判定为"可用"，但在国内经常连不通。

**因此本仓库的可用节点以本地实测结果为准。** 查看 commit 历史时，认准提交者：

- `zhuanz-sub-bot` → **本地实测，可信**
- `github-actions[bot]` → 美区视角，仅供参考

### 三种运行模式对照

| 场景 | 建议 |
|---|---|
| 电脑开机且12:00 醒着 | 本地 launchd 会自动跑，效果最佳 |
| 电脑关机/合盖 | Actions 兜底更新，但节点未经国内实测 |
| 想立即更新 | `launchctl start gui/$(id -u)/com.zhuanz.hiddify.nodes` |
