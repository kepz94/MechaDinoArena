# model_json.py v1.2 (1.1: joints sorted parent-first, the T-Rex data lists AnkleR before KneeR; 1.2: part transparency -> "t") — converts a generated *ModelData.luau (segments / joints) into the three.js mockup JSON format
# ({segs: [{n, root, parts: [{n, s, cf, c}]}], joints: [{n, p0, p1, c0, c1}], hrp, hip}). Used for size comparisons.
# Run: python3 tools/mockup/model_json.py src/shared/Models/RaptorModelData.luau OUT.json
import json, re, sys

src = open(sys.argv[1]).read()
nums = lambda s: [float(v) for v in s.split(",")]
segs, joints = [], []
for line in src.splitlines():
    m = re.match(r'\s*\{name = "(\w+)", root = \{([^}]*)\}, parts = \{', line)
    if m:
        segs.append({"n": m.group(1), "root": nums(m.group(2)), "parts": []})
        continue
    m = re.match(r'\s*\{name = "(\w+)", size = \{([^}]*)\}, cf = \{([^}]*)\}, color = "(\w+)"', line)
    if m and segs:
        pe = {"n": m.group(1), "s": nums(m.group(2)), "cf": nums(m.group(3)), "c": m.group(4)}
        tm = re.search(r'transparency = ([\d.]+)', line)  # v1.2: hidden parts (e.g. the pachy's Head_spike*)
        if tm:
            pe["t"] = float(tm.group(1))
        segs[-1]["parts"].append(pe)
        continue
    m = re.match(r'\s*\{name = "(\w+)", part0 = "(\w+)", part1 = "(\w+)", c0 = \{([^}]*)\}, c1 = \{([^}]*)\}', line)
    if m:
        joints.append({"n": m.group(1), "p0": m.group(2), "p1": m.group(3), "c0": nums(m.group(4)), "c1": nums(m.group(5))})
done, ordered = {"HRP"}, []
while len(ordered) < len(joints):
    for j in joints:
        if j not in ordered and j["p0"] in done:
            ordered.append(j); done.add(j["p1"])
joints = ordered
hrp = nums(re.search(r'hrp = \{size = \{([^}]*)\}', src).group(1))
hip = float(re.search(r'HipHeight = ([\d.]+)', src).group(1))
json.dump({"segs": segs, "joints": joints, "hrp": hrp, "hip": hip}, open(sys.argv[2], "w"))
print(len(segs), "segments,", sum(len(s["parts"]) for s in segs), "parts,", len(joints), "joints ->", sys.argv[2])
