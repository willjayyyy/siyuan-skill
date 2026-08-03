#!/usr/bin/env python3
"""Regenerate skills/siyuan/data/endpoints.tsv from SiYuan kernel source.

Usage:
    python3 tools/gen_endpoints.py [--tag v3.7.3] [--keep]

Shallow-clones siyuan-note/siyuan at the given tag, parses kernel/api/router.go
for every route, then extracts each handler's parameters.

Output columns:  endpoint <TAB> methods <TAB> W|R <TAB> params

Binding styles covered (missing any one of these silently empties whole modules):
    arg["x"]                        direct map access
    util.BindJsonArg("x", ...)      anywhere on the line, not just line-start
    c.PostForm("x") / c.Query("x")  form and query parameters
    c.ShouldBindJSON(&v) or (v)     struct binding -> that struct's json tags
    helper(arg, ...)                one level of same-package helper expansion

W/R is derived from SiYuan's CheckReadonly middleware. It is NOT a behavioural
read/write classification -- see skills/siyuan/references/discovery.md.
"""
import argparse
import glob
import os
import re
import shutil
import subprocess
import sys
import tempfile

REPO = 'https://github.com/siyuan-note/siyuan.git'
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'skills', 'siyuan', 'data', 'endpoints.tsv')

# Handlers that live outside kernel/api/ (the router references them as model.X)
# and transports this client cannot speak. Tagged by hand.
OVERRIDE = {
    '/api/asset/upload': '<multipart>',
    '/api/system/getCaptcha': '<image>',
}
PREFIX = [('/ws/', '<websocket>'), ('/es/', '<sse>'), ('/plugin/', '<passthrough>')]


def clone(tag, dest):
    run = lambda *a: subprocess.run(a, check=True,
                                    stdout=subprocess.DEVNULL,
                                    stderr=subprocess.DEVNULL)
    run('git', 'clone', '--depth', '1', '--branch', tag,
        '--filter=blob:none', '--sparse', REPO, dest)
    run('git', '-C', dest, 'sparse-checkout', 'set', 'kernel/api')
    api = os.path.join(dest, 'kernel', 'api')
    if not os.path.isfile(os.path.join(api, 'router.go')):
        sys.exit(f'error: kernel/api/router.go missing after checkout of {tag}')
    return api


def parse_routes(src_dir):
    router = open(os.path.join(src_dir, 'router.go'), encoding='utf-8').read()
    pat = re.compile(
        r'ginServer\.(Handle|Any|GET|POST|PUT|DELETE|HEAD)\(\s*'
        r'(?:"(GET|POST|PUT|DELETE|HEAD|ANY)"\s*,\s*)?'
        r'"([^"]+)"\s*'
        r'((?:,\s*[A-Za-z0-9_.]+\s*)*)\)')
    routes = {}
    for m in pat.finditer(router):
        verb, quoted, path, rest = m.groups()
        method = quoted or (verb if verb not in ('Handle', 'Any') else 'ANY')
        parts = [p.strip() for p in rest.split(',') if p.strip()]
        if not parts:
            continue
        r = routes.setdefault(path, {'methods': set(), 'write': False, 'fn': set()})
        r['methods'].add(method)
        r['fn'].add(parts[-1].split('.')[-1])
        if 'CheckReadonly' in ','.join(parts[:-1]):
            r['write'] = True
    return routes


def parse_handlers(src_dir):
    files = [f for f in sorted(glob.glob(os.path.join(src_dir, '*.go')))
             if not f.endswith('_test.go')]
    for f in files:
        if os.path.getsize(f) == 0:
            sys.exit(f'error: {f} is empty -- a partial checkout would silently '
                     'drop that module\'s parameters')

    structs = {}
    for f in files:
        src = open(f, encoding='utf-8', errors='replace').read()
        for sm in re.finditer(r'type\s+([A-Za-z0-9_]+)\s+struct\s*\{(.*?)\n\}', src, re.S):
            tags = re.findall(r'`[^`]*json:"([^",]+)', sm.group(2))
            if tags:
                structs[sm.group(1)] = tags

    raw_args, calls = {}, {}
    func_pat = re.compile(r'\nfunc\s+([A-Za-z0-9_]+)\s*\(([^)]*)\)[^{]*\{')
    for f in files:
        src = open(f, encoding='utf-8', errors='replace').read()
        idx = [(m.group(1), m.end()) for m in func_pat.finditer(src)]
        for i, (name, start) in enumerate(idx):
            body = src[start:idx[i + 1][1] if i + 1 < len(idx) else len(src)]
            a = set(re.findall(r'arg\["([A-Za-z0-9_]+)"\]', body))
            a |= set(re.findall(r'BindJsonArg\(\s*"([A-Za-z0-9_]+)"', body))
            a |= set(re.findall(r'c\.PostForm\(\s*"([A-Za-z0-9_]+)"', body))
            a |= set(re.findall(r'c\.(?:Default)?Query\(\s*"([A-Za-z0-9_]+)"', body))
            for vm in re.finditer(r'(?:ShouldBindJSON|BindJSON|ShouldBind)\(\s*&?(\w+)', body):
                var = vm.group(1)
                tm = (re.search(rf'\b{var}\s*:?=\s*(?:&)?([A-Za-z0-9_]+)\{{', body)
                      or re.search(rf'var\s+{var}\s+([A-Za-z0-9_]+)', body))
                if tm and tm.group(1) in structs:
                    a |= set(structs[tm.group(1)])
            if re.search(r'MultipartForm|FormFile', body):
                a.add('<multipart>')
            raw_args[name] = a
            calls[name] = set(re.findall(r'\b([a-z][A-Za-z0-9_]*)\(\s*arg\b', body))
    return raw_args, calls


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--tag', default='v3.7.3', help='SiYuan git tag to parse')
    ap.add_argument('--keep', action='store_true', help='keep the clone for inspection')
    args = ap.parse_args()

    tmp = tempfile.mkdtemp(prefix='siyuan-src-')
    try:
        print(f'cloning siyuan {args.tag} ...')
        src_dir = clone(args.tag, tmp)
        routes = parse_routes(src_dir)
        raw_args, calls = parse_handlers(src_dir)

        def params(fn, depth=0):
            out = set(raw_args.get(fn, ()))
            if depth < 1:
                for callee in calls.get(fn, ()):
                    out |= params(callee, depth + 1)
            return out

        lines, unresolved = [], set()
        for path in sorted(routes):
            r = routes[path]
            ps = set()
            for fn in r['fn']:
                ps |= params(fn)
                if fn not in raw_args:
                    unresolved.add(fn)
            methods = 'ANY' if 'ANY' in r['methods'] else '+'.join(sorted(r['methods']))
            p = ','.join(sorted(ps)) or '-'
            if path in OVERRIDE:
                p = OVERRIDE[path]
            else:
                for pre, tag in PREFIX:
                    if path.startswith(pre):
                        p = tag
                        break
            lines.append(f"{path}\t{methods}\t{'W' if r['write'] else 'R'}\t{p}")

        os.makedirs(os.path.dirname(OUT), exist_ok=True)
        open(OUT, 'w', encoding='utf-8').write('\n'.join(lines) + '\n')

        api = sum(1 for l in lines if l.startswith('/api/'))
        writes = sum(1 for l in lines if l.split('\t')[2] == 'W')
        withp = sum(1 for l in lines if l.split('\t')[3] != '-')
        pct = 100 * withp // len(lines)
        print(f'wrote {os.path.relpath(OUT, ROOT)}')
        print(f'  routes      : {len(lines)}  ({api} under /api/)')
        print(f'  writes (W)  : {writes}')
        print(f'  with params : {withp} ({pct}%)')
        if unresolved:
            print(f'  handlers outside kernel/api (tag by hand if callable): '
                  f'{sorted(unresolved)}')
        print('\nv3.7.3 baseline: 548 routes, 540 under /api/, 300 W, ~80% with params.')
        if pct < 70:
            print('\nWARNING: parameter coverage below 70%. A regex or a checkout '
                  'likely failed silently -- do not ship this file.', file=sys.stderr)
            sys.exit(1)
    finally:
        if args.keep:
            print(f'clone kept at {tmp}')
        else:
            shutil.rmtree(tmp, ignore_errors=True)


if __name__ == '__main__':
    main()
