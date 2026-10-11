#!/usr/bin/env python3
"""
多源聚合节点抓取器
- 11 个公开源，全部经 jsDelivr 拉取（绕开 GitHub 封锁）
- 自动解析 singbox-json / clash-yaml / v2ray-base64 / v2ray-plain 四种格式
- DNS 串行解析 + TCP 并发实测（并发过高会触发 DNS 限流，务必分两阶段）
"""
import json, base64, yaml, socket, time, collections, re, threading, sys
from concurrent.futures import ThreadPoolExecutor

HOSTS = ['fastly.jsdelivr.net', 'testingcf.jsdelivr.net', 'jsdelivr.b-cdn.net', 'cdn.jsdelivr.net']

SOURCES = [
    ('ishalumi',   'ishalumi/proxy-node-collector',       'main',   'output/nodes_base64.txt'),
    ('Au1rxx',     'Au1rxx/free-vpn-subscriptions',      'main',   'output/singbox.json'),
    ('xingchaoet', 'xingchaoet/free-vpn-subscriptions',  'main',   'output/singbox.json'),
    ('barry-far',  'barry-far/V2ray-config',             'main',   'All_Configs_Sub.txt'),
    ('peasoft',    'peasoft/NoMoreWalls',                'master', 'list.meta.yml'),
    ('Ruk1ng001',  'Ruk1ng001/freeSub',                  'main',   'singBox.json'),
    ('free-nodes', 'free-nodes/v2rayfree',               'main',   'sub'),
    ('free18',     'free18/v2ray',                       'main',   'c.yaml'),
    ('wanghaisheng','wanghaisheng/free-vpn-subscriptions','main',  'output/singbox.json'),
    ('snakem982',  'snakem982/proxypool',                'main',   'source/sing-box-2.json'),
    ('ts-sf',      'ts-sf/fly',                          'main',   'v2'),
]

# sing-box 协议名 -> Hiddify 可用名
PROTO_MAP = {'ss': 'shadowsocks', 'hy2': 'hysteria2'}

_dns_cache, _lock = {}, threading.Lock()


def resolve(host):
    with _lock:
        if host in _dns_cache:
            return _dns_cache[host]
    try:
        ip = socket.gethostbyname(host)
    except Exception:
        ip = None
    with _lock:
        _dns_cache[host] = ip
    return ip


def fetch(url, timeout=60):
    import subprocess
    out = '/tmp/_src.dat'
    r = subprocess.run(['curl', '-sS', '--noproxy', '*', '-L', '-o', out,
                        '-w', '%{http_code}', '--max-time', str(timeout), url],
                       capture_output=True, text=True)
    import os
    code = (r.stdout or '').strip()[-3:]
    if code != '200' or not os.path.exists(out) or os.path.getsize(out) < 500:
        return None
    return out


def decode_sub(raw):
    txt = raw.decode('utf-8', 'ignore')
    body = '\n'.join(l for l in txt.splitlines() if not l.strip().startswith('#')).strip()
    if '://' in body[:500]:
        return body
    for c in (body, txt.strip()):
        try:
            s = re.sub(r'\s+', '', c)
            d = base64.b64decode(s + '=' * (-len(s) % 4)).decode('utf-8', 'ignore')
            if '://' in d:
                return d
        except Exception:
            continue
    return body


def parse_links(txt):
    out = []
    for line in txt.splitlines():
        line = line.strip()
        if '://' not in line or line.startswith('#'):
            continue
        try:
            sch, rest = line.split('://', 1)
            if '@' not in rest:
                continue
            hp = rest.rsplit('@', 1)[1].split('?')[0].split('#')[0].split('/')[0]
            if ':' in hp:
                h, p = hp.rsplit(':', 1)
                if h and p.isdigit():
                    out.append((PROTO_MAP.get(sch, sch), h, int(p)))
        except Exception:
            pass
    return out


def extract(path):
    raw = open(path, 'rb').read()
    try:
        d = json.loads(raw)
        if isinstance(d, dict):
            key = 'outbounds' if 'outbounds' in d else ('proxies' if 'proxies' in d else None)
            if key:
                out = []
                for o in d[key]:
                    if o.get('server'):
                        t = PROTO_MAP.get(o.get('type'), o.get('type', '?'))
                        out.append((t, str(o['server']),
                                    int(o.get('server_port') or o.get('port') or 0),
                                    json.dumps(o, ensure_ascii=False)))
                return out
    except Exception:
        pass
    txt = decode_sub(raw)
    if 'proxies:' in txt:
        try:
            y = yaml.safe_load(txt)
            out = []
            for p in (y or {}).get('proxies', []) or []:
                if p.get('server'):
                    t = PROTO_MAP.get(p.get('type'), p.get('type', '?'))
                    out.append((t, str(p['server']), int(p.get('port') or 0), None))
            return out
        except Exception:
            pass
    # v2ray 明文：逐条保留完整链接
    out = []
    for line in txt.splitlines():
        line = line.strip()
        if '://' in line and not line.startswith('#'):
            out.append((None, None, 0, line))
    return out


def main():
    print('[多源抓取] 开始')
    allnodes = {}
    raw_links = []
    per_src = {}
    for tag, repo, branch, path in SOURCES:
        got = None
        for h in HOSTS:
            got = fetch('https://%s/gh/%s@%s/%s' % (h, repo, branch, path))
            if got:
                break
        if not got:
            print('  [FAIL] %s' % tag)
            continue
        try:
            ns = extract(got)
        except Exception as e:
            print('  [ERR]  %s %s' % (tag, e))
            continue
        n = 0
        for proto, srv, port, rawjson in ns:
            if srv and port:
                allnodes.setdefault((srv, port, proto), rawjson)
                n += 1
            elif rawjson:
                raw_links.append(rawjson)
                n += 1
        per_src[tag] = n
        print('  [OK]   %-14s %d 个' % (tag, n))

    # v2ray 明文链接单独解析
    for link in raw_links:
        for proto, h, p in parse_links(link):
            allnodes.setdefault((h, p, proto), 'V2RAYLINK:' + link)

    print('[多源抓取] 去重后 %d 个唯一节点' % len(allnodes))

    # 阶段1：DNS 串行
    print('[实测] DNS 解析中...')
    resolved = []
    for (srv, port, proto), rawjson in allnodes.items():
        ip = resolve(srv)
        if ip:
            resolved.append((srv, ip, port, proto, rawjson))
        if len(resolved) % 800 == 0 and len(resolved) and resolved[-1][0]:
            print('  已解析 %d' % len(resolved), flush=True)
    print('[实测] DNS 成功 %d / %d' % (len(resolved), len(allnodes)))

    # 阶段2：TCP 并发
    print('[实测] TCP 连接中...')
    ok = []

    def probe(item):
        srv, ip, port, proto, rawjson = item
        st = time.time()
        sk = socket.socket()
        sk.settimeout(2.5)
        try:
            sk.connect((ip, port))
            return (srv, ip, port, proto, int((time.time() - st) * 1000), rawjson)
        except Exception:
            return None
        finally:
            sk.close()

    with ThreadPoolExecutor(max_workers=25) as ex:
        for r in ex.map(probe, resolved):
            if r:
                ok.append(r)
    ok.sort(key=lambda x: x[4])
    total = max(len(allnodes), 1)
    print('[实测] 可用 %d 个 (%.1f%%)' % (len(ok), len(ok) / total * 100))

    json.dump([{'server': r[0], 'ip': r[1], 'port': r[2], 'protocol': r[3], 'ms': r[4],
                'raw': r[5]} for r in ok], open('/tmp/union_alive.json', 'w'), ensure_ascii=False)
    json.dump(per_src, open('/tmp/per_src.json', 'w'), ensure_ascii=False, indent=1)
    print('[多源抓取] 完成，可用 %d 个' % len(ok))


if __name__ == '__main__':
    main()