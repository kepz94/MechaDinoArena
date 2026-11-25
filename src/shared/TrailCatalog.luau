-- TrailCatalog v1.0 (Mecha Dino Arena) — the 10 dino trails (plan docs/plans/TRAILS_v1.0.md; picks docs/plans/TRAILS_v0.1.md;
-- mockups docs/mockups/trails_v0.1.html, docs/mockups/trails_shop_lab_v0.1.html).
-- Pure data, shared by TrailServer 1.0 (server), TrailFX / TrailLook / ShopScreen / Lab (client copy ReplicatedStorage.TrailShared.TrailCatalog,
-- made by TrailServer).
-- Kepu 2026-11-24: 23:18 shows whenever moving / unlocks like emotes / island and matches / 10; 23:31 all 10 kept, Neon Streak free,
-- Fossil Prints = win 25 Arena matches, Comet Tail = get 250 kills; 23:55 one trail for every dino (pick A).
-- unlock.kind: "free" | "earn" (stat = player attribute, need) | "robux" (price; product = SkinCatalog.PRODUCTS[rarity]).
-- sw: the swatch colours (left to right) for cards and the detail strip.

local TC = {}

TC.Version = "1.0"

TC.ORDER = {"neon", "fossil", "comet", "rainbow", "bolt", "lava", "leaf", "bubble", "pixel", "bones"}
TC.NONE = "none"
TC.DEFAULT = "neon"

local RGB = Color3.fromRGB
local BUY = {kind = "robux", price = 149, rarity = "RARE"}

TC.TRAILS = {
	neon = {name = "Neon Streak", tag = "NEON", unlock = {kind = "free"}, sw = {RGB(127, 233, 255), RGB(59, 155, 255)},
		desc = "A clean electric-blue ribbon off the hips. The starter everyone gets."},
	fossil = {name = "Fossil Prints", tag = "FOSSIL", unlock = {kind = "earn", stat = "ArenaW", need = 25, text = "Win 25 Arena matches", unit = "WINS"},
		sw = {RGB(243, 230, 196), RGB(201, 168, 106)},
		desc = "Glowing bone-white dino footprints stamped where every foot lands. They fade after a few seconds."},
	comet = {name = "Comet Tail", tag = "COMET", unlock = {kind = "earn", stat = "StatKills", need = 250, text = "Get 250 kills", unit = "KILLS"},
		sw = {RGB(255, 243, 160), RGB(255, 138, 46), RGB(255, 59, 31)},
		desc = "The tail tip burns like the asteroid that got the others. Fire, sparks, little rocks."},
	rainbow = {name = "Rainbow Road", tag = "RAINBOW", unlock = BUY,
		sw = {RGB(255, 59, 59), RGB(255, 155, 46), RGB(255, 226, 59), RGB(70, 224, 138), RGB(59, 184, 255), RGB(138, 91, 255)},
		desc = "The classic. Six bright bands that flow out behind you."},
	bolt = {name = "Lightning", tag = "BOLT", unlock = BUY, sw = {RGB(255, 255, 255), RGB(127, 233, 255), RGB(59, 107, 255)},
		desc = "A crackling electric line that jumps along your path, with sparks."},
	lava = {name = "Lava Steps", tag = "LAVA", unlock = BUY, sw = {RGB(255, 210, 74), RGB(255, 90, 31), RGB(58, 26, 16)},
		desc = "Every step leaves a molten print, embers float up and a bit of smoke drifts off."},
	leaf = {name = "Leaf Storm", tag = "LEAF", unlock = BUY, sw = {RGB(155, 224, 90), RGB(63, 154, 69), RGB(42, 107, 48)},
		desc = "Jungle leaves whirl up behind you, spin and drift down to the ground."},
	bubble = {name = "Bubble Pop", tag = "BUBBLE", unlock = BUY, sw = {RGB(217, 246, 255), RGB(138, 216, 255), RGB(255, 182, 239)},
		desc = "Shiny bubbles float up and wobble, then pop."},
	pixel = {name = "Pixel Dust", tag = "PIXEL", unlock = BUY, sw = {RGB(255, 200, 50), RGB(127, 233, 255), RGB(255, 90, 138)},
		desc = "8-bit squares in the game's colours drop out behind you and blink away."},
	bones = {name = "Bone Zone", tag = "BONES", unlock = BUY, sw = {RGB(245, 239, 224), RGB(207, 195, 166)},
		desc = "Little bones and the odd skull clatter out behind you, bounce once and fade."},
}

function TC.get(id)
	return type(id) == "string" and TC.TRAILS[id] or nil
end

-- stats: {[stat name] = number} (player attributes)
function TC.earned(id, stats)
	local t = TC.get(id)
	if not (t and t.unlock.kind == "earn") then return false end
	local v = stats and tonumber(stats[t.unlock.stat]) or 0
	return v >= t.unlock.need
end

-- owned: {[id] = true}; allUnlocked: SkinCatalog.ALL_UNLOCKED (the shared test switch)
function TC.owns(id, owned, allUnlocked, stats)
	local t = TC.get(id)
	if not t then return false end
	if allUnlocked == true or t.unlock.kind == "free" then return true end
	if type(owned) == "table" and owned[id] == true then return true end
	return t.unlock.kind == "earn" and TC.earned(id, stats)
end

-- a saved / requested choice -> a known id or TC.NONE (nil / unknown -> nil)
function TC.clean(id)
	if id == TC.NONE or id == "" then return TC.NONE end
	return TC.get(id) and id or nil
end

-- the swatch colours as a ColorSequence (for a UIGradient on a card strip)
function TC.colorSequence(id)
	local t = TC.get(id)
	if not t then return ColorSequence.new(Color3.fromRGB(42, 51, 70)) end
	local n = #t.sw
	if n == 1 then return ColorSequence.new(t.sw[1]) end
	local kps = {}
	for i, c in ipairs(t.sw) do table.insert(kps, ColorSequenceKeypoint.new((i - 1) / (n - 1), c)) end
	return ColorSequence.new(kps)
end

return TC
