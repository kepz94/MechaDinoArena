-- EggRules v1.0 (Mecha Dino Arena) — the Favorite Egg's prize pool, odds, pick and 48 h window (ModuleScript,
-- ServerStorage.DinoArcade). Plan docs/plans/FAVORITE_EGG_v1.0.md Task 1 (MDA-607), mockup docs/mockups/favorite_egg_v0.1.html
-- "B · Prize reel". Kepu 2026-11-26 picks: "One ever", "By rarity", "Reroll to new", "Per player, 48 h", "Owned + parts maxed";
-- red-team "Lower paid odds" (60 / 30 / 5 / 2 / 3), "When they first see it", "Leave them out" (Zebra, Storm Front).
-- Pure data + maths: no services; the catalogs are passed in.
-- pool(US, EC, TC) -> {common = {...}, rare = {...}, epic = {...}, legend = {...}, dino = {...}}; each item {kind, id, name, tier}.
--   Skins (US.ORDER): unlock "earn" -> common; "robux" RARE / EPIC / LEGENDARY -> rare / epic / legend; "free" never; EXCLUDE never.
--   Emotes (EC.ORDER), trails (TC.ORDER): "earn" -> common; "robux" by rarity (missing rarity -> rare); "free" never.
--   Dinos (US.DINOS): dino.
-- pick(pool, owned, rand, odds) -> item | {kind = "points"}. owned = {skin = set, emote = set, trail = set, dino = set}. rand() ->
--   [0, 1). A tier counts only while it has an item not owned; its odds share is odds[tier] (ODDS by default). With no tier left
--   -> points. Uses rand() twice (tier, item).
-- setOf(csv) -> {[id] = true}.
-- endsAt(first, hours) -> first + hours * 3600 (WINDOW_H 48).
-- state(rec, now, hours) -> "rolled" (rec.roll), "unseen" (no rec.first), "expired" (now >= endsAt), "open".
local M = {}
M.VERSION = "1.0"
M.TIERS = {"common", "rare", "epic", "legend", "dino"}
M.ODDS = {common = 60, rare = 30, epic = 5, legend = 2, dino = 3}
M.TIER_NAME = {common = "COMMON", rare = "RARE", epic = "EPIC", legend = "LEGENDARY", dino = "DINO"}
M.EXCLUDE = {skin = {zebra = true, storm = true}} -- the Quest Stand specials (red-team R4)
M.VERSION = "1.1" -- v1.1 (Kepu 2026-11-26 16:14 on mockup docs/mockups/skin_drop_v0.1.html: "A1-a3 should be free as well as the holiday ones" / "They're the ones to earn" / 16:15 "Okay let's build"; earn goals and the rest of the lineup: standing pick, recommended): the December holiday skins (UniversalSkins 1.6) are never Favorite Egg prizes, so they stay
-- earn-only in their window. Switch: M.EXCLUDE_HOLIDAY (true; false = 1.0).
M.EXCLUDE_HOLIDAY = true
if M.EXCLUDE_HOLIDAY then
	for _, id in ipairs({"gingerbread", "candycane", "frostbite", "holidaylights"}) do M.EXCLUDE.skin[id] = true end
end
M.WINDOW_H = 48
M.ALL_OWNED_POINTS = 10
local RAR = {RARE = "rare", EPIC = "epic", LEGENDARY = "legend"}

local function tierOf(unlock)
	if type(unlock) ~= "table" then return nil end
	if unlock.kind == "earn" then return "common" end
	if unlock.kind == "robux" then return RAR[unlock.rarity or "RARE"] or "rare" end
	return nil
end

function M.pool(US, EC, TC)
	local p = {}
	for _, t in ipairs(M.TIERS) do p[t] = {} end
	local function add(kind, id, name, tier)
		if tier and not (M.EXCLUDE[kind] and M.EXCLUDE[kind][id]) then
			table.insert(p[tier], {kind = kind, id = id, name = name, tier = tier})
		end
	end
	for _, id in ipairs(US and US.ORDER or {}) do
		local s = US.SKINS[id]
		if s then add("skin", id, s.name, tierOf(s.unlock)) end
	end
	for _, id in ipairs(EC and EC.ORDER or {}) do
		local e = EC.EMOTES[id]
		if e then add("emote", id, e.name, tierOf(e.unlock)) end
	end
	for _, id in ipairs(TC and TC.ORDER or {}) do
		local t = TC.TRAILS[id]
		if t then add("trail", id, t.name, tierOf(t.unlock)) end
	end
	for _, d in ipairs(US and US.DINOS or {}) do
		add("dino", d, US.DINO_NAMES and US.DINO_NAMES[d] or d, "dino")
	end
	return p
end

function M.setOf(csv)
	local s = {}
	if type(csv) == "string" then for id in csv:gmatch("[^,]+") do s[id] = true end end
	return s
end

function M.pick(pool, owned, rand, odds)
	odds = odds or M.ODDS
	owned = owned or {}
	local avail, total = {}, 0
	for _, t in ipairs(M.TIERS) do
		local list = {}
		for _, it in ipairs(pool[t] or {}) do
			if not (owned[it.kind] and owned[it.kind][it.id]) then table.insert(list, it) end
		end
		local w = math.max(0, tonumber(odds[t]) or 0)
		if #list > 0 and w > 0 then
			avail[t] = list
			total += w
		end
	end
	if total <= 0 then return {kind = "points"} end
	local r = rand() * total
	local tier
	for _, t in ipairs(M.TIERS) do
		if avail[t] then
			local w = math.max(0, tonumber(odds[t]) or 0)
			if r < w then tier = t break end
			r -= w
			tier = t -- float edge: the last available tier
		end
	end
	local list = avail[tier]
	local i = math.clamp(math.floor(rand() * #list) + 1, 1, #list)
	return list[i]
end

function M.endsAt(first, hours)
	return (tonumber(first) or 0) + (tonumber(hours) or M.WINDOW_H) * 3600
end

function M.state(rec, now, hours)
	if type(rec) ~= "table" then return "unseen" end
	if type(rec.roll) == "table" then return "rolled" end
	if not tonumber(rec.first) then return "unseen" end
	if now >= M.endsAt(rec.first, hours) then return "expired" end
	return "open"
end

return M
