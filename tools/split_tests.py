"""Split a large GUT test file: its helpers (vars, before_each, after_each, every func that
is not a test) go to a base script in test/helpers/, and its tests to several test files
that extend it, by cut points (the first test of each new file).

    python3 tools/split_tests.py test/unit/test_game.gd game_case \
        test_game:test_first_one test_game_build:test_some_test ...
"""
import pathlib, sys
sys.path.insert(0, str(pathlib.Path(__file__).parent))
from gdsplit import parse

src = pathlib.Path(sys.argv[1])
base = sys.argv[2]
cuts = [a.split(':') for a in sys.argv[3:]]
lines, items = parse(src)
head = ''.join(lines[:items[0].lo])
cur = None
starts = {t: f for f, t in cuts}
out = {f: [] for f, _ in cuts}
helpers = []
for it in items:
    if it.name in starts:
        cur = starts[it.name]
    is_test = it.kind == 'func' and it.name.startswith('test_')
    if is_test:
        if cur is None:
            raise SystemExit(f'test {it.name} before the first cut')
        out[cur].append(it)
    else:
        helpers.append(it)


def join(its):
    s = ''
    prev = None
    for it in its:
        t = it.text.rstrip('\n') + '\n'
        if prev is not None:
            s += '\n' if prev.kind in ('var', 'const') and it.kind in ('var', 'const') and not t.startswith('#') else '\n\n\n'
        s += t
        prev = it
    return s


root = src.parent.parent
hp = root / 'helpers' / f'{base}.gd'
hp.parent.mkdir(exist_ok=True)
assert head.startswith('extends GutTest'), head[:40]
doc = head[len('extends GutTest\n'):]
hp.write_text('extends GutTest\n' + f'## Shared setup and helpers for the {src.stem}* test files.\n' + doc.rstrip('\n') + '\n\n' + join(helpers))
src.unlink()
for f, its in out.items():
    p = src.parent / f'{f}.gd'
    p.write_text(f'extends "res://test/helpers/{base}.gd"\n\n\n' + join(its))
    print(p, len(its), 'tests', len(p.read_text().splitlines()), 'lines')
print(hp, len(hp.read_text().splitlines()), 'lines')
