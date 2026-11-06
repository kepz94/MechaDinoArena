# herrera_old_parts.py v1.0 (Mecha Dino Arena) — dumps HerreraPartsServer's piece lists (the looks in the game now) as JSON
# for the Herrera parts redesign mockup ({pieces: {id: [[anchor, size, pos, rotXYZ deg, colourKey, role?], ...], glider_open},
# colors: {key: [r, g, b, material, transparency]}}). Runs the server's own piece functions in lupa (pip install lupa).
# Run: python3 tools/mockup/herrera_old_parts.py src/server/HerreraPartsServer.server.luau MODEL.json (model_json.py) OUT.json
import json, re, sys
from lupa import LuaRuntime
src = open(sys.argv[1]).read()
model = json.load(open(sys.argv[2]))
a = src.index("local C = {"); b = src.index("local PARTS = {")
c = src.index("-- ---------- pieces"); d = src.index("local BUILD = {")
code = src[a:b] + "\n" + src[c:d] + "\nreturn {ironclaw = ironclaw, glider = glider, quills = quills, smoke = smoke, plating = plating, siphon = siphon, strobe = strobe, breaker = breaker, caltrops = caltrops, goo = goo, hadren = hadren}"
L = LuaRuntime(unpack_returned_tuples=True)
L.execute("""
Color3 = {fromRGB = function(r, g, b) return {r = r, g = g, b = b} end}
Enum = setmetatable({}, {__index = function(_, k) return setmetatable({}, {__index = function(_, v) return k .. "." .. v end}) end})
math.rad = math.rad
math.atan2 = function(y, x) return math.atan(y, x) end
""")
sizes = {p["n"]: p["s"] for s in model["segs"] for p in s["parts"]}
lua_sizes = L.table_from({k: L.table_from(v) for k, v in sizes.items()})
L.globals().SIZES = lua_sizes
L.execute("""
CHAR = {GetScale = function() return 1 end, FindFirstChild = function(self, n)
  local s = SIZES[n]; if not s then return nil end
  return {Name = n, Size = {X = s[1], Y = s[2], Z = s[3]}, IsA = function() return true end}
end}
local mt = {__div = function(a, k) return {X = a.X / k, Y = a.Y / k, Z = a.Z / k} end}
local orig = CHAR.FindFirstChild
CHAR.FindFirstChild = function(self, n, r) local o = orig(self, n) if o then setmetatable(o.Size, mt) end return o end
""")
fns = L.execute(code)
C = L.execute(src[a:b] + "\nreturn C")
def tolist(t): return [tolist(v) if hasattr(v, "values") else v for v in t.values()]
out = {}
for k in ["ironclaw", "glider", "quills", "smoke", "plating", "siphon", "strobe", "breaker", "caltrops", "goo", "hadren"]:
    f = fns[k]
    res = f(L.globals().CHAR) if k == "quills" else (f(False) if k == "glider" else f())
    out[k] = [tolist(p) for p in res.values()]
cols = {}
for key in C.keys():
    v = C[key]
    col = v[1]; cols[key] = [col["r"], col["g"], col["b"], v[2], v[3] if v[3] is not None else 0]
out["glider_open"] = [tolist(p) for p in fns["glider"](True).values()]
json.dump({"pieces": out, "colors": cols}, open(sys.argv[3], "w"))
print({k: len(v) for k, v in out.items()})
