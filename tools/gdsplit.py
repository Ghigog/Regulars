"""Split a large GDScript class into parts, rewriting references so they still resolve.

Used to break game/main.gd, hud.gd, build.gd, crew.gd and desk_screen.gd into the folders
beside them (see CLAUDE.md, "Finding and changing code"). It moves whole top-level items
(funcs, vars, consts, inner classes, with the comments above them) by cut points, then:
- inside a part, prefixes what stayed behind: `<backref>.x` for instance members,
  `Class.X` for constants, statics and inner classes, `<backref>.<part>.x` for another part;
- in the class itself, `x` becomes `<part>.x` (or `PartClass.x` when static);
- in other files, `<receiver>.x` becomes `<receiver>.<part>.x` (or `PartClass.x`).
It prints PROBLEM lines (clashes, locals shadowing members) and "stray?" lines (`a.x` where
`a` is not a known receiver) to review by hand. Check the result by running the tests.

    python3 tools/gdsplit.py plan.json [--dry]

plan.json:
    root        the project directory
    file        the script to split, relative to root
    class       its class_name
    backref     the name a part uses for its owner ("game"); omit for "game"
    inherited   a file of the owner's inherited member names (tools/godot_members.gd)
    header      text put first in the split file if missing ("class_name Game\n")
    anchor      the member after which the `var part := PartClass.new(self)` lines go
    keep        names that stay in the class whatever the cuts say
    parts       [{var, class, file, short, doc: [lines], static: bool}] (static: no instance)
    cuts        [[first item name, part var or "main"], ...] in file order
    other_globs files to rewrite references in
    receivers   names that hold the class in other files ("game", "Hud");
    file_receivers  {path: [extra receivers]} for one file only
    list        true: only print the items with their owners
"""
import json, re, sys, pathlib

IDENT = re.compile(r'[A-Za-z_][A-Za-z0-9_]*')
ITEM_START = re.compile(r'^(static\s+func|static\s+var|func|var|const|signal|enum|class|@\w+)\b')
DECL_KW = {'func', 'var', 'const', 'signal', 'enum', 'class', 'class_name', 'extends'}
VIRTUALS = {'_ready', '_process', '_physics_process', '_input', '_unhandled_input',
            '_unhandled_key_input', '_notification', '_enter_tree', '_exit_tree', '_init', '_draw'}


def tokens(text):
    """(start, end, name) for identifiers in code, outside strings and comments."""
    i, n = 0, len(text)
    out = []
    while i < n:
        c = text[i]
        if c == '#':
            j = text.find('\n', i)
            i = n if j < 0 else j
            continue
        if c in '"\'':
            q3 = text[i:i + 3]
            if q3 in ('"""', "'''"):
                j = text.find(q3, i + 3)
                i = n if j < 0 else j + 3
                continue
            j = i + 1
            while j < n and text[j] != c:
                if text[j] == '\\':
                    j += 1
                if text[j] == '\n':
                    break
                j += 1
            i = j + 1
            continue
        if c.isalpha() or c == '_':
            m = IDENT.match(text, i)
            out.append((m.start(), m.end(), m.group()))
            i = m.end()
            continue
        if c.isdigit():
            m = re.compile(r'[0-9][0-9A-Za-z_.]*').match(text, i)
            i = m.end()
            continue
        i += 1
    return out


def strip_code(text):
    """The text with strings and comments blanked, for regex scans."""
    out = list(text)
    i, n = 0, len(text)
    while i < n:
        c = text[i]
        if c == '#':
            j = text.find('\n', i)
            j = n if j < 0 else j
            for k in range(i, j):
                out[k] = ' '
            i = j
            continue
        if c in '"\'':
            q3 = text[i:i + 3]
            if q3 in ('"""', "'''"):
                j = text.find(q3, i + 3)
                j = n if j < 0 else j + 3
            else:
                j = i + 1
                while j < n and text[j] != c and text[j] != '\n':
                    if text[j] == '\\':
                        j += 1
                    j += 1
                j += 1
            for k in range(i, min(j, n)):
                if out[k] != '\n':
                    out[k] = ' '
            i = j
            continue
        i += 1
    return ''.join(out)


def split_params(s):
    depth, cur, parts = 0, '', []
    for ch in s:
        if ch in '([{':
            depth += 1
        elif ch in ')]}':
            depth -= 1
        if ch == ',' and depth == 0:
            parts.append(cur)
            cur = ''
        else:
            cur += ch
    if cur.strip():
        parts.append(cur)
    names = []
    for p in parts:
        m = IDENT.search(p)
        if m:
            names.append(m.group())
    return names


def locals_of(text):
    code = strip_code(text)
    names = set()
    for m in re.finditer(r'\bfunc\b\s*\w*\s*\(', code):
        depth, j = 1, m.end()
        while j < len(code) and depth:
            depth += {'(': 1, ')': -1}.get(code[j], 0)
            j += 1
        names.update(split_params(code[m.end():j - 1]))
    first = code.split('\n', 1)
    body = first[1] if len(first) > 1 else ''
    if re.match(r'\s*class\b', code):
        for m in re.finditer(r'\b(?:var|const|func|signal|enum|class)\s+(\w+)', body):
            names.add(m.group(1))
    elif not re.match(r'\s*(static\s+)?func\b', code):
        body = ''   # a var/const item: its own name is a member, not a local
    for m in re.finditer(r'\b(?:var|const)\s+(\w+)', body):
        names.add(m.group(1))
    for m in re.finditer(r'\bfor\s+(\w+)\s*(?::\s*[\w\[\]]+\s*)?\bin\b', code):
        names.add(m.group(1))
    return names


class Item:
    def __init__(self, lines, lo, hi, head):
        self.lo, self.hi = lo, hi          # line indices [lo, hi) including leading comments
        self.head = head                   # index of the declaration line
        decl = lines[head]
        d = re.sub(r'^@\w+(\([^)]*\))?\s*', '', decl)
        m = re.match(r'(static\s+)?(func|var|const|signal|enum|class)\s+(\w+)', d)
        self.static = bool(m and m.group(1))
        self.kind = m.group(2) if m else 'other'
        self.name = m.group(3) if m else None
        self.text = ''.join(lines[lo:hi])

    @property
    def is_static_kind(self):
        return self.kind in ('const', 'enum', 'class') or self.static


def parse(path):
    lines = pathlib.Path(path).read_text().splitlines(keepends=True)
    starts = [i for i, l in enumerate(lines) if ITEM_START.match(l)]
    items = []
    for k, s in enumerate(starts):
        prev_hi = s
        while prev_hi > 0 and (lines[prev_hi - 1].strip() == '' or lines[prev_hi - 1].startswith('#')):
            prev_hi -= 1
        if k == 0:
            prev_hi = max(prev_hi, next(i for i, l in enumerate(lines) if l.startswith('extends')) + 1)
        lo = prev_hi
        while lo < s and not lines[lo].startswith('#'):
            lo += 1
        nxt = starts[k + 1] if k + 1 < len(starts) else len(lines)
        hi = nxt
        while hi > s + 1 and (lines[hi - 1].strip() == '' or lines[hi - 1].startswith('#')):
            hi -= 1
        items.append(Item(lines, lo, hi, s))
    return lines, items


def main():
    plan = json.loads(pathlib.Path(sys.argv[1]).read_text())
    dry = '--dry' in sys.argv
    root = pathlib.Path(plan['root'])
    src = root / plan['file']
    lines, items = parse(src)
    owner_cls = {'main': plan['class']}
    owner_var = {'main': None}
    for p in plan['parts']:
        owner_cls[p['var']] = p['class']
        owner_var[p['var']] = p['var']
    by_name = {it.name: it for it in items if it.name}
    # cut points
    cuts = {c[0]: c[1] for c in plan['cuts']}
    for c in cuts:
        if c not in by_name:
            raise SystemExit(f'no item {c}')
    cur = 'main'
    keep = set(plan.get('keep', [])) | VIRTUALS
    for it in items:
        if it.name in cuts:
            cur = cuts[it.name]
        it.owner = 'main' if (it.name in keep or it.kind == 'other') else cur
    if plan.get('list'):
        for it in items:
            print(f'{it.lo + 1:5d} {it.owner:12s} {it.kind:6s} {it.name}')
        return
    members = {}
    for it in items:
        if it.name:
            kind = 'static' if it.is_static_kind else 'inst'
            members[it.name] = (it.owner, kind)
    for n in pathlib.Path(plan['inherited']).read_text().split():
        members.setdefault(n, ('main', 'inst'))
    problems = []
    # part vars must not clash with locals anywhere in the class or with members
    all_locals = set()
    for it in items:
        all_locals |= locals_of(it.text)
    for p in plan['parts']:
        if p['var'] in members or p['var'] in all_locals:
            problems.append(f"part var '{p['var']}' clashes with a member or a local")

    back = plan.get('backref', 'game')
    inherited = set(pathlib.Path(plan['inherited']).read_text().split())

    def ref(frm, to, kind, name):
        if frm == to:
            return None
        if kind == 'static':
            return f'{owner_cls[to]}.{name}'
        if frm == 'main':
            return f'{owner_var[to]}.{name}'
        if to == 'main':
            return f'{back}.{name}'
        return f'{back}.{owner_var[to]}.{name}'

    func_names = {it.name for it in items if it.kind == 'func'}

    def rewrite(it):
        text = it.text
        loc = locals_of(text)
        static_ctx = it.is_static_kind or it.kind == 'var' and False
        toks = tokens(text)
        out, last = [], 0
        prev_name = None
        for (a, b, name) in toks:
            before = text[:a].rstrip(' \t')
            pc = before[-1:] if before else ''
            new = None
            if pc in ('.', '$', '@') or prev_name in DECL_KW:
                pass
            elif name == 'self':
                if it.owner != 'main' and it.kind != 'class':
                    new = back
            elif name in loc and not (text[b:].lstrip(' \t')[:1] == '(' and members.get(name, ('', ''))[0] != ''
                                      and name in func_names):
                # a local of this name; a call `name(...)` still means the method (GDScript
                # calls a local Callable with .call())
                if name in members and members[name][0] != it.owner:
                    problems.append(f'{it.name}: local {name} shadows a member')
            elif name in members:
                to, kind = members[name]
                if to == 'main' and name in inherited and it.owner == 'main':
                    pass
                elif it.kind == 'class' and kind == 'inst':
                    pass   # an inner class's own members (it cannot see the outer's)
                else:
                    r = ref(it.owner, to, kind, name)
                    if r:
                        if kind == 'inst' and (it.is_static_kind) and r.startswith((back, owner_var.get(to) or '\0')):
                            problems.append(f'{it.name}: static context uses instance member {name}')
                        if kind == 'inst' and it.kind == 'var' and it.owner != 'main':
                            problems.append(f'{it.name}: moved var initializer uses {name}')
                        new = r
            prev_name = name
            if new is not None:
                out.append(text[last:a])
                out.append(new)
                last = b
        out.append(text[last:])
        return ''.join(out)

    new_text = {it: rewrite(it) for it in items}
    # main file: drop moved items, keep the rest verbatim (rewritten)
    keep_lines = []
    i = 0
    moved = [it for it in items if it.owner != 'main']
    by_lo = {it.lo: it for it in items}
    out = []
    pos = 0
    for it in items:
        out.append(''.join(lines[pos:it.lo]))
        if it.owner == 'main':
            out.append(new_text[it])
            if plan.get('anchor') == it.name:
                out.append(''.join(f"var {p['var']} := {p['class']}.new(self)   # {p['short']}\n" for p in plan['parts'] if not p.get('static')))
        pos = it.hi
    out.append(''.join(lines[pos:]))
    main_text = re.sub(r'\n{4,}', '\n\n\n', ''.join(out))
    if not plan.get('anchor') in by_name:
        problems.append('anchor item not found')
    head = plan['header']
    if head and not main_text.startswith(head):
        main_text = head + main_text
    files = {src: main_text}
    for p in plan['parts']:
        its = [it for it in items if it.owner == p['var']]
        body = ''
        prev = None
        for it in its:
            t = new_text[it].rstrip('\n') + '\n'
            if prev is None:
                body += t
            elif prev.kind in ('var', 'const') and it.kind in ('var', 'const') and not t.startswith('#'):
                body += t
            else:
                body += '\n\n' + t
            prev = it
        hdr = (f"class_name {p['class']}\nextends RefCounted\n" + ''.join(f'## {l}\n' for l in p['doc']) +
               (f"\nvar {back}: {plan['class']}\n\n\nfunc _init({back}_: {plan['class']}) -> void:\n\t{back} = {back}_\n\n\n" if not p.get('static') else '\n\n'))
        files[root / p['file']] = hdr + body
    # other files: receiver.name -> receiver.part.name
    moved_names = {it.name: it.owner for it in moved if it.name}
    recv = plan.get('receivers', ['game'])
    pat = re.compile(r'\b(' + '|'.join(map(re.escape, recv)) + r')\.(' + '|'.join(map(re.escape, moved_names)) + r')\b')
    stray = re.compile(r'\b(\w+)\.(' + '|'.join(map(re.escape, moved_names)) + r')\b')
    report = {}
    for g in plan['other_globs']:
        for f in sorted(root.glob(g)):
            if f == src or f in files:
                continue
            t = f.read_text()
            rel = str(f.relative_to(root))
            frecv = recv + plan.get('file_receivers', {}).get(rel, [])
            pat = re.compile(r'\b(' + '|'.join(map(re.escape, frecv)) + r')\.(' + '|'.join(map(re.escape, moved_names)) + r')\b')
            t2 = pat.sub(lambda m: (f'{owner_cls[moved_names[m.group(2)]]}.{m.group(2)}' if members[m.group(2)][1] == 'static'
                                   else f'{m.group(1)}.{owner_var[moved_names[m.group(2)]]}.{m.group(2)}'), t)
            for m in stray.finditer(strip_code(t)):
                if m.group(1) not in frecv and m.group(1) not in owner_var:
                    report.setdefault(f'{m.group(1)}.{m.group(2)}', set()).add(f.name)
            if t2 != t:
                files[f] = t2
    # the class's own explicit `Class.x` in its own and the new files
    cpat = re.compile(r'\b' + re.escape(plan['class']) + r'\.(' + '|'.join(map(re.escape, moved_names)) + r')\b')
    for f in [src] + [root / p['file'] for p in plan['parts']]:
        mine = 'main' if f == src else next(p['var'] for p in plan['parts'] if root / p['file'] == f)
        files[f] = cpat.sub(lambda m: m.group(0) if moved_names[m.group(1)] == mine and members[m.group(1)][1] == 'static'
                            and False else (f'{owner_cls[moved_names[m.group(1)]]}.{m.group(1)}'
                            if members[m.group(1)][1] == 'static' else m.group(0)), files[f])
    for k in sorted(report):
        print('stray?', k, sorted(report[k]))
    for pr in sorted(set(problems)):
        print('PROBLEM', pr)
    if not dry:
        for f, t in files.items():
            pathlib.Path(f).parent.mkdir(parents=True, exist_ok=True)
            pathlib.Path(f).write_text(t)
        print('wrote', len(files), 'files')


if __name__ == '__main__':
    main()
