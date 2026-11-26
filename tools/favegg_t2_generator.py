"""Favorite Egg T2 (MDA-608): additive grant hooks. Applies the pairs to the repo files and writes a Studio install script per file
into the given folder. Run: python3 -I tools/favegg_t2_generator.py <outdir>"""
import sys, pathlib

OUT = pathlib.Path(sys.argv[1])
ROOT = pathlib.Path(__file__).resolve().parent.parent

EMOTE_NOTE = '''local VERSION = "1.0"
VERSION = "1.1" -- v1.1 EmoteGrant
-- v1.1 (Favorite Egg, plan docs/plans/FAVORITE_EGG_v1.0.md Task 2, MDA-608): server-only BindableFunction EmoteGrant (child of this
--   script): Invoke(player, id, reason) -> "ok" (written to owned with one UpdateAsync, wheel filled, EmoteUnlocked set) / "owned" /
--   "unknown" / "notLoaded" / "failed" / "disabled". Buying and receipts are not touched. Switch: script attribute EmoteGrantEnabled
--   (true, read per call). Diagnostic: EmoteGrants.
'''
EMOTE_HOOK = '''hook.Parent = ServerStorage
-- v1.1: EmoteGrant (see the v1.1 note)
if script:GetAttribute("EmoteGrantEnabled") == nil then script:SetAttribute("EmoteGrantEnabled", true) end
do
	local grantFn = script:FindFirstChild("EmoteGrant") or Instance.new("BindableFunction")
	grantFn.Name = "EmoteGrant"
	grantFn.Parent = script
	grantFn.OnInvoke = function(player, id, reason)
		if script:GetAttribute("EmoteGrantEnabled") == false then return "disabled" end
		if typeof(player) ~= "Instance" or not player:IsA("Player") or type(id) ~= "string" or not EC.get(id) then return "unknown" end
		local st = states[player]
		if not (st and st.loaded and store) then return "notLoaded" end
		if st.owned[id] == true then return "owned" end
		local ok, value = pcall(function()
			return store:UpdateAsync("u" .. player.UserId, function(old)
				local v = blank(old)
				v.owned[id] = true
				return v
			end)
		end)
		if not (ok and player.Parent) then return "failed" end
		if type(value) == "table" and type(value.owned) == "table" then st.owned = value.owned end
		st.owned[id] = true
		bump("EmoteGrants")
		if fillWheel(player) then task.spawn(saveWheel, player) end
		player:SetAttribute("EmoteUnlocked", id)
		publish(player)
		setResult(player, "granted")
		return "ok"
	end
end
'''

TRAIL_NOTE = '''local VERSION = "1.0"
VERSION = "1.1" -- v1.1 TrailGrant
-- v1.1 (Favorite Egg, plan docs/plans/FAVORITE_EGG_v1.0.md Task 2, MDA-608): server-only BindableFunction TrailGrant (child of this
--   script): Invoke(player, id, reason) -> "ok" (written to owned with one UpdateAsync, TrailUnlocked set) / "owned" / "unknown" /
--   "notLoaded" / "failed" / "disabled". Buying and receipts are not touched. Switch: script attribute TrailGrantEnabled (true, read
--   per call). Diagnostic: TrailGrants.
'''
TRAIL_HOOK = '''hook.Parent = ServerStorage
-- v1.1: TrailGrant (see the v1.1 note)
if script:GetAttribute("TrailGrantEnabled") == nil then script:SetAttribute("TrailGrantEnabled", true) end
do
	local grantFn = script:FindFirstChild("TrailGrant") or Instance.new("BindableFunction")
	grantFn.Name = "TrailGrant"
	grantFn.Parent = script
	grantFn.OnInvoke = function(player, id, reason)
		if script:GetAttribute("TrailGrantEnabled") == false then return "disabled" end
		if typeof(player) ~= "Instance" or not player:IsA("Player") or type(id) ~= "string" or not TC.get(id) then return "unknown" end
		local st = states[player]
		if not (st and st.loaded and store) then return "notLoaded" end
		if st.owned[id] == true then return "owned" end
		local ok, value = pcall(function()
			return store:UpdateAsync("u" .. player.UserId, function(old)
				local v = blank(old)
				v.owned[id] = true
				return v
			end)
		end)
		if not (ok and player.Parent) then return "failed" end
		if type(value) == "table" and type(value.owned) == "table" then st.owned = value.owned end
		st.owned[id] = true
		bump("TrailGrants")
		player:SetAttribute("TrailUnlocked", id)
		publish(player)
		setResult(player, "granted")
		return "ok"
	end
end
'''

OWN_NOTE = '''VERSION = "1.1" -- v1.1 fresh store (account reset)
VERSION = "1.2" -- v1.2 OwnGrant + maxed dinos
-- v1.2 (Favorite Egg, plan docs/plans/FAVORITE_EGG_v1.0.md Task 2, MDA-608; Kepu 2026-11-26 "Owned + parts maxed"): server-only
--   BindableFunction OwnGrant (child of this script): Invoke(player, key, maxed) -> "ok" (value.owned[key] = true, and with maxed
--   value.maxed[key] = true; written as every other change) / "owned" (owned, and maxed when asked) / "unknown" (not one of
--   TutorialRules.ALL_DINOS) / "notLoaded" (TutState "wait") / "notReady" (no stored value yet: "new" in the tutorial) / "allOwned"
--   ("grand" / "off": every dino already) / "disabled". New player attribute MaxedDinos (comma list of value.maxed; SkillServer
--   1.16 gives those dinos every mecha part like FreeDino). Switch: script attribute OwnGrantEnabled (true, read per call).
--   Diagnostic: OwnGrants.
'''
OWN_PUB = '''	player:SetAttribute("FreeDino", v and type(v.free) == "string" and v.free or "")
	local mx = {} -- v1.2: maxed dinos
	if v and type(v.maxed) == "table" then for _, k in ipairs(R.ALL_DINOS) do if v.maxed[k] then table.insert(mx, k) end end end
	player:SetAttribute("MaxedDinos", table.concat(mx, ","))
'''
OWN_FN = '''Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do task.spawn(onPlayer, p) end
'''
OWN_GRANT = '''-- v1.2: OwnGrant (see the v1.2 note)
if script:GetAttribute("OwnGrantEnabled") == nil then script:SetAttribute("OwnGrantEnabled", true) end
fn("OwnGrant").OnInvoke = function(player, key, maxed)
	if script:GetAttribute("OwnGrantEnabled") == false then return "disabled" end
	if typeof(player) ~= "Instance" or not player:IsA("Player") or type(key) ~= "string" or not table.find(R.ALL_DINOS, key) then return "unknown" end
	local d = data[player]
	if not d or d.state == "wait" then return "notLoaded" end
	if d.state == "grand" or d.state == "off" then return "allOwned" end
	if not d.value then return "notReady" end
	d.value.owned = type(d.value.owned) == "table" and d.value.owned or {}
	local had = d.value.owned[key] == true and (not maxed or (type(d.value.maxed) == "table" and d.value.maxed[key] == true))
	if had then return "owned" end
	d.value.owned[key] = true
	if maxed then
		d.value.maxed = type(d.value.maxed) == "table" and d.value.maxed or {}
		d.value.maxed[key] = true
	end
	d.dirty = true
	publish(player, d)
	script:SetAttribute("OwnGrants", (script:GetAttribute("OwnGrants") or 0) + 1)
	player:SetAttribute("OwnLastResult", "granted " .. key)
	task.spawn(write, player, d)
	return "ok"
end

''' + OWN_FN

SKILL_NOTE = '''VERSION = "1.15" -- v1.15 universal skill points + bonus points
VERSION = "1.16" -- v1.16 maxed dinos (Favorite Egg)
-- v1.16 (Favorite Egg, plan docs/plans/FAVORITE_EGG_v1.0.md Task 2, MDA-608): the v1.13 free-dino rule also holds for every dino in
--   the player attribute MaxedDinos (comma list, DinoOwnership 1.2: a dino won from the Favorite Egg). A MaxedDinos change
--   republishes the player. Switch: script attribute SkillMaxedDinosEnabled (true, read per publish / buy; false = 1.15).
'''
SKILL_FREE_OLD = '''local function freeOn(d) -- v1.13: the active dino is the player's free dino
	return script:GetAttribute("SkillFreePartsEnabled") ~= false and type(d.freeDino) == "string" and d.freeDino ~= ""
		and d.active == d.freeDino
end'''
SKILL_FREE_NEW = '''local function freeOn(d) -- v1.13: the active dino is the player's free dino
	if script:GetAttribute("SkillFreePartsEnabled") ~= false and script:GetAttribute("SkillMaxedDinosEnabled") ~= false -- v1.16
		and type(d.maxedDinos) == "string" and d.active and table.find(string.split(d.maxedDinos, ","), d.active) then return true end
	return script:GetAttribute("SkillFreePartsEnabled") ~= false and type(d.freeDino) == "string" and d.freeDino ~= ""
		and d.active == d.freeDino
end'''
SKILL_PUB_OLD = '''	d.freeDino = player:GetAttribute("FreeDino") -- v1.13
'''
SKILL_PUB_NEW = '''	d.freeDino = player:GetAttribute("FreeDino") -- v1.13
	d.maxedDinos = player:GetAttribute("MaxedDinos") -- v1.16
'''
SKILL_HOOK_OLD = '''	player:GetAttributeChangedSignal("FreeDino"):Connect(function()
		local d = data[player]
		if d and d.loaded then publish(player, d, false) end
	end)
'''
SKILL_HOOK_NEW = SKILL_HOOK_OLD + '''	player:GetAttributeChangedSignal("MaxedDinos"):Connect(function() -- v1.16
		local d = data[player]
		if d and d.loaded then publish(player, d, false) end
	end)
'''
if "SkillMaxedDinosEnabled\") == nil" not in SKILL_FREE_NEW:
    SKILL_FREE_NEW = 'if script:GetAttribute("SkillMaxedDinosEnabled") == nil then script:SetAttribute("SkillMaxedDinosEnabled", true) end -- v1.16\n' + SKILL_FREE_NEW

JOBS = {
    "EmoteServer": ("src/server/EmoteServer.server.luau", "game:GetService(\"ServerScriptService\").EmoteServer",
                    [('local VERSION = "1.0"\n', EMOTE_NOTE), ("hook.Parent = ServerStorage\n", EMOTE_HOOK)]),
    "TrailServer": ("src/server/TrailServer.server.luau", "game:GetService(\"ServerScriptService\").TrailServer",
                    [('local VERSION = "1.0"\n', TRAIL_NOTE), ("hook.Parent = ServerStorage\n", TRAIL_HOOK)]),
    "DinoOwnership": ("src/server/DinoOwnership.server.luau", "game:GetService(\"ServerScriptService\").DinoOwnership",
                      [('VERSION = "1.1" -- v1.1 fresh store (account reset)\n', OWN_NOTE),
                       ('\tplayer:SetAttribute("FreeDino", v and type(v.free) == "string" and v.free or "")\n', OWN_PUB),
                       (OWN_FN, OWN_GRANT)]),
    "SkillServer": ("src/server/SkillServer.server.luau", "game:GetService(\"ServerScriptService\").SkillServer",
                    [('VERSION = "1.15" -- v1.15 universal skill points + bonus points\n', SKILL_NOTE),
                     (SKILL_FREE_OLD, SKILL_FREE_NEW), (SKILL_PUB_OLD, SKILL_PUB_NEW), (SKILL_HOOK_OLD, SKILL_HOOK_NEW)]),
}

def h(s):
    x = 0
    for b in s.encode("utf-8"):
        x = (x * 31 + b) % 2147483647
    return x

for name, (path, studio, pairs) in JOBS.items():
    p = ROOT / path
    src = p.read_text(encoding="utf-8")
    for a, b in pairs:
        assert src.count(a) == 1, (name, a[:60], src.count(a))
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
    (OUT / f"t2_{name}.luau").write_text("\n".join(lua), encoding="utf-8")
    print(name, len(src.encode("utf-8")), h(src))
