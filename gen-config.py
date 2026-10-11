import json, datetime, collections

alive = json.load(open('/tmp/union_alive.json'))
per_src = json.load(open('/tmp/per_src.json'))

# 保留原始 JSON 的节点（singbox/clash 结构完整，可直接用）
outbounds = []
seen = set()
for a in sorted(alive, key=lambda x: x['ms']):
    raw = a.get('raw')
    srv, port = a['server'], a['port']
    if srv in seen:
        continue
    seen.add(srv)
    if raw and raw.startswith('{'):
        try:
            o = json.loads(raw)
            o['tag'] = '%s %s %s' % (a['protocol'], srv, port)
            outbounds.append(o)
        except Exception:
            pass

#补上仅有 v2ray 明文链接的节点（转成 singbox 通用格式不可靠，保守跳过）
print('写入配置 %d 个节点' % len(outbounds))

profile = {'outbounds': outbounds}
REPO = '/Users/Zhuanz/WorkBuddy/2026-10-10-22-31-28/sub-repo'
json.dump(profile, open(REPO + '/out/singbox-verified.json', 'w'), ensure_ascii=False)
json.dump(profile, open(REPO + '/hiddify-free-verified.json', 'w'), ensure_ascii=False)

lines = [
    '# 可用节点清单',
    '> 自动生成 %s' % datetime.datetime.now().strftime('%Y-%m-%d %H:%M'),
    '> 多源聚合 11 个公开源，实测可用 %d 个（%.1f%%）' % (len(alive), len(alive) / 4676 * 100),
    '',
    '## 各源贡献',
    '',
    '| 源 | 解析节点数 |',
    '|---|---|',
]
for k, v in sorted(per_src.items(), key=lambda x: -x[1]):
    lines.append('| %s | %d |' % (k, v))

lines += ['', '## 可用协议分布', '',
          '| 协议 | 数量 |', '|---|---|']
pc = collections.Counter(a['protocol'] for a in alive)
for k, v in pc.most_common():
    lines.append('| %s | %d |' % (k, v))

lines += ['', '## 延迟分位', '',
          '- 中位数: %d ms' % sorted(a['ms'] for a in alive)[len(alive) // 2],
          '- p90: %d ms' % sorted(a['ms'] for a in alive)[int(len(alive) * 0.9)],
          '', '## 最快 20 个', '',
          '| # | 协议 | 服务器 | 端口 | 延迟 |', '|---|---|---|---|---|']
for i, a in enumerate(sorted(alive, key=lambda x: x['ms'])[:20], 1):
    lines.append('| %d | %s | %s | %s | %d ms |' % (i, a['protocol'], a['server'], a['port'], a['ms']))

open(REPO + '/out/NODES.md', 'w').write('\n'.join(lines) + '\n')
print('已生成 out/singbox-verified.json (%d 节点) 与 out/NODES.md' % len(outbounds))
print('可用协议:', dict(pc))