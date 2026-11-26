-- EggRules.spec v1.0 (Mecha Dino Arena) — run in Studio Edit; returns "PASS n" or "FAIL ...".
local SS, RS = game:GetService("ServerStorage"), game:GetService("ReplicatedStorage")
local function load(inst)
	if not inst then return nil end
	local c = inst:Clone() c.Parent = workspace
	local ok, m = pcall(require, c)
	c:Destroy()
	return ok and m or nil
end
local R = load(SS.DinoArcade:FindFirstChild("EggRules"))
if not R then return "FAIL missing / bad ServerStorage.DinoArcade.EggRules" end
local US = load(SS.DinoArcade:FindFirstChild("UniversalSkins") or (RS:FindFirstChild("SkinShared") and RS.SkinShared:FindFirstChild("UniversalSkins")))
local EC = load(SS.DinoArcade:FindFirstChild("EmoteCatalog"))
local TC = load(SS.DinoArcade:FindFirstChild("TrailCatalog"))
if not (US and EC and TC) then return "FAIL catalogs " .. tostring(US ~= nil) .. tostring(EC ~= nil) .. tostring(TC ~= nil) end
local fails, passes = {}, 0
local function eq(name, got, want)
	if got == want then passes += 1 else table.insert(fails, ("%s: got %s want %s"):format(name, tostring(got), tostring(want))) end
end
local P = R.pool(US, EC, TC)
local function count(t, kind) local n = 0 for _, it in ipairs(P[t]) do if it.kind == kind then n += 1 end end return n end
-- tiers match the live catalogs (UniversalSkins 1.5, EmoteCatalog 1.0, TrailCatalog 1.0)
eq("common skins (earn - zebra, storm)", count("common", "skin"), 5)
eq("common emotes", count("common", "emote"), 2)
eq("common trails", count("common", "trail"), 2)
eq("rare skins", count("rare", "skin"), 4)
eq("rare emotes", count("rare", "emote"), 9)
eq("rare trails", count("rare", "trail"), 7)
eq("epic skins", count("epic", "skin"), 5)
eq("legend skins", count("legend", "skin"), 7)
eq("dinos", count("dino", "dino"), 8)
local seen = {}
for _, t in ipairs(R.TIERS) do for _, it in ipairs(P[t]) do seen[it.kind .. ":" .. it.id] = t end end
eq("classic never", seen["skin:classic"], nil)
eq("party never", seen["emote:party"], nil)
eq("neon never", seen["trail:neon"], nil)
eq("zebra never", seen["skin:zebra"], nil)
eq("storm never", seen["skin:storm"], nil)
eq("prism legend", seen["skin:prism"], "legend")
eq("lava skin epic", seen["skin:lava"], "epic")
eq("lava trail rare", seen["trail:lava"], "rare")
eq("TRex dino", seen["dino:TRex"], "dino")
-- odds sum and tier rolls at the edges
local sum = 0 for _, t in ipairs(R.TIERS) do sum += R.ODDS[t] end
eq("odds 100", sum, 100)
local function seq(a, b) local i = 0 return function() i += 1 return i == 1 and a or b end end
eq("r 0 common", R.pick(P, {}, seq(0, 0)).tier, "common")
eq("r .599 common", R.pick(P, {}, seq(0.599, 0)).tier, "common")
eq("r .6 rare", R.pick(P, {}, seq(0.6, 0)).tier, "rare")
eq("r .9 epic", R.pick(P, {}, seq(0.9, 0)).tier, "epic")
eq("r .95 legend", R.pick(P, {}, seq(0.95, 0)).tier, "legend")
eq("r .97 dino", R.pick(P, {}, seq(0.97, 0)).tier, "dino")
eq("r .9999 dino", R.pick(P, {}, seq(0.9999, 0.9999)).tier, "dino")
-- owned never picked; empty tier falls to the rest (odds kept)
local ownDinos = {} for _, d in ipairs(US.DINOS) do ownDinos[d] = true end
local x = R.pick(P, {dino = ownDinos}, seq(0.999, 0))
eq("dinos owned -> not dino", x.tier ~= "dino", true)
eq("dinos owned, r .999 -> legend (last left)", x.tier, "legend")
local ownAll = {skin = {}, emote = {}, trail = {}, dino = ownDinos}
for _, t in ipairs(R.TIERS) do for _, it in ipairs(P[t]) do ownAll[it.kind][it.id] = true end end
eq("all owned -> points", R.pick(P, ownAll, seq(0.5, 0.5)).kind, "points")
local almost = table.clone(ownAll.skin) almost.arctic = nil
local y = R.pick(P, {skin = almost, emote = ownAll.emote, trail = ownAll.trail, dino = ownDinos}, seq(0.01, 0.9))
eq("only arctic left -> arctic", y.id, "arctic")
local owned2 = {skin = R.setOf("desert,riverstone,canopy,ghostbark,inkwar")}
for i = 1, 200 do
	local it = R.pick(P, owned2, math.random)
	if it.kind == "skin" and owned2.skin[it.id] then eq("owned picked " .. it.id, true, false) break end
end
passes += 1
eq("setOf", R.setOf("a,b").b, true)
eq("setOf nil", next(R.setOf(nil)), nil)
-- window
eq("endsAt", R.endsAt(1000, 48), 1000 + 172800)
eq("unseen", R.state({}, 5), "unseen")
eq("unseen nil", R.state(nil, 5), "unseen")
eq("open", R.state({first = 1000}, 1000 + 172799), "open")
eq("expired", R.state({first = 1000}, 1000 + 172800), "expired")
eq("rolled beats expired", R.state({first = 1000, roll = {kind = "skin"}}, 1e9), "rolled")
if #fails > 0 then return "FAIL " .. #fails .. "\n" .. table.concat(fails, "\n") end
return "PASS " .. passes
