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

本地 `~/WorkBuddy/2026-10-10-22-31-28/sub-repo/refresh.sh` 由 launchd 每 12 小时执行：

1. 经 jsDelivr 拉取上游配置（带防反爬校验）
2. 全量实测节点连通性
3. 生成仅含可用节点的配置
4. Git 提交并推送

日志：`~/WorkBuddy/2026-10-10-22-31-28/sub-repo/refresh.log`

手动触发：

```bash
bash ~/WorkBuddy/2026-10-10-22-31-28/sub-repo/refresh.sh
```