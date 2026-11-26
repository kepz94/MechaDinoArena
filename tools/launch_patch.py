"""Launch batch (Kepu 2026-11-26 08:06-08:10): pairs patches applied to repo files, plus a Studio install script per file.
Usage: python3 -I tools/launch_patch.py <outdir> <jobname>...   Each job is a module-level JOBS entry."""
import sys, pathlib, importlib.util
ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = pathlib.Path(sys.argv[1])

def h(s):
    x = 0
    for b in s.encode("utf-8"):
        x = (x * 31 + b) % 2147483647
    return x

def run(name, path, studio, pairs):
    p = ROOT / path
    src = p.read_text(encoding="utf-8")
    for a, b in pairs:
        assert src.count(a) == 1, (name, a[:80], src.count(a))
        src = src.replace(a, b)
    p.write_text(src, encoding="utf-8")
    lua = [f"local sc = {studio}", "local PAIRS = {"]
    for a, b in pairs:
        assert "]=====]" not in a + b
        lua.append("{[=====[" + a + "]=====], [=====[" + b + "]=====]},")
    lua.append("}")
    lua.append('''local s = sc.Source
for k, pr in ipairs(PAIRS) do
	local a, b = string.find(s, pr[1], 1, true)
	assert(a, "miss " .. k)
	assert(not string.find(s, pr[1], b + 1, true), "dup " .. k)
	s = s:sub(1, a - 1) .. pr[2] .. s:sub(b + 1)
end
local m = Instance.new("ModuleScript")
m.Source = "return function()\\n" .. s .. "\\nend"
m.Parent = workspace
local okC, errC = pcall(require, m)
m:Destroy()
if not okC then return "COMPILE FAIL " .. tostring(errC) end
sc.Source = s
local h = 0 for i = 1, #s do h = (h * 31 + s:byte(i)) % 2147483647 end
return #s .. " " .. h''')
    (OUT / f"{name}.luau").write_text("\n".join(lua), encoding="utf-8")
    print(name, len(src.encode("utf-8")), h(src))

spec = importlib.util.spec_from_file_location("jobs", sys.argv[2])
jobs = importlib.util.module_from_spec(spec)
spec.loader.exec_module(jobs)
for name, (path, studio, pairs) in jobs.JOBS.items():
    run(name, path, studio, pairs)
