# Applies a pairs-only Luau patch (PAIRS = {{old, new}, ...} as [=====[ ]=====] strings) to a source file, exactly as in Studio.
# Usage: python3 -I tools/lab_pairs.py <patch.luau> <target file>
import re, sys
patch = open(sys.argv[1], encoding='utf-8').read()
body = patch.split('\nlocal s = sc.Source')[0]
strs = re.findall(r'\[=====\[(.*?)\]=====\]', body, re.S)
strs = [x[1:] if x.startswith('\n') else x for x in strs]
assert len(strs) % 2 == 0
s = open(sys.argv[2], encoding='utf-8').read()
for k in range(0, len(strs), 2):
    o, n = strs[k], strs[k+1]
    assert s.count(o) == 1, ('count', k//2 + 1, s.count(o), o[:60])
    s = s.replace(o, n)
open(sys.argv[2], 'w', encoding='utf-8').write(s)
print('pairs', len(strs)//2)
