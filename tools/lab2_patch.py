# Applies tools/lab2_patch.luau (BLOCK + PAIRS, Luau long strings) to src/client/Lab.client.luau, exactly as the Luau applier does in Studio.
import re, sys
patch = open('tools/lab2_patch.luau', encoding='utf-8').read()
body = patch.split('-- apply (Studio)')[0]
strs = re.findall(r'\[=====\[(.*?)\]=====\]', body, re.S)
strs = [x[1:] if x.startswith('\n') else x for x in strs]
block, pairs = strs[:3], strs[3:]
assert len(pairs) % 2 == 0
p = 'src/client/Lab.client.luau'
s = open(p, encoding='utf-8').read()
i1 = s.find(block[0]); i2 = s.find(block[1], i1)
assert i1 >= 0 and i2 >= 0, 'block markers'
s = s[:i1] + block[2] + s[i2:]
for k in range(0, len(pairs), 2):
    o, n = pairs[k], pairs[k+1]
    assert s.count(o) == 1, ('count', k//2 + 1, s.count(o), o[:60])
    s = s.replace(o, n)
open(p, 'w', encoding='utf-8').write(s)
print('pairs', len(pairs)//2)
