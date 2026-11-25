-- EmoteCatalog v1.0 (Mecha Dino Arena) — the 12 battle emotes (plan docs/plans/EMOTES_v1.0.md; picks docs/plans/EMOTES_v0.1.md).
-- Pure data, shared by EmoteServer 1.0 (server), EmotePose 1.0 (via the character's EmoteDuration), EmoteFX / EmoteWheel / ShopScreen /
-- Lab (client copy ReplicatedStorage.EmoteShared.EmoteCatalog, made by EmoteServer).
-- Kepu 2026-11-24: lineup locked 20:12 ("keep all of these"); prices 20:13 (Stomp Stomp, GG Party, Play Dead unlocked, everything else
-- 149); unlocks 20:14 (GG Party free from the start, Stomp Stomp = win 10 Arena matches, Play Dead = win 5 Arena matches in a row).
-- unlock.kind: "free" | "earn" (stat = player attribute, need) | "robux" (price; product = SkinCatalog.PRODUCTS[rarity]).

local EC = {}

EC.Version = "1.0"

EC.ORDER = {"cooked", "mic", "skill", "tea", "easy", "party", "stomp", "moon", "shake", "arms", "dead", "yawn"}

EC.EMOTES = {
	cooked = {name = "Cooked", tag = "COOKED", dur = 3, word = "COOKED!", unlock = {kind = "robux", price = 149, rarity = "RARE"},
		desc = "Chef's hat, a pan, two egg flips, then it points at you."},
	mic = {name = "Mic Drop", tag = "MIC DROP", dur = 3, word = "BOOM", unlock = {kind = "robux", price = 149, rarity = "RARE"},
		desc = "Holds a mic out, drops it. BOOM. Nose up, looks away."},
	skill = {name = "Skill Issue", tag = "SKILL ISSUE", dur = 2.8, word = "SKILL ISSUE", unlock = {kind = "robux", price = 149, rarity = "RARE"},
		desc = "A protest sign that says SKILL ISSUE, pumped up and down."},
	tea = {name = "Tea Time", tag = "TEA", dur = 3, word = "*sip*", unlock = {kind = "robux", price = 149, rarity = "RARE"},
		desc = "A fancy cup of tea mid-fight. *sip*"},
	easy = {name = "Too Easy", tag = "TOO EASY", dur = 2.6, word = "TOO EASY", unlock = {kind = "robux", price = 149, rarity = "RARE"},
		desc = "Pixel shades drop onto its face. Lean back, slow nod."},
	party = {name = "GG Party", tag = "GG", dur = 2.6, word = "GG!", unlock = {kind = "free"},
		desc = "Party hat, big jump, confetti. GG!"},
	stomp = {name = "Stomp Stomp", tag = "STOMP", dur = 2.1, word = "STOMP!", unlock = {kind = "earn", stat = "ArenaW", need = 10, text = "Win 10 Arena matches"},
		desc = "Four war stomps with dust rings."},
	moon = {name = "Moon Call", tag = "MOON CALL", dur = 2.8, word = "AWOOO!", unlock = {kind = "robux", price = 149, rarity = "RARE"},
		desc = "Sits back and howls at the sky."},
	shake = {name = "Shake Off", tag = "SHAKE", dur = 1.7, word = "BRRR", unlock = {kind = "robux", price = 149, rarity = "RARE"},
		desc = "A wet-dog shake from nose to tail."},
	arms = {name = "Tiny Arms", tag = "TINY ARMS", dur = 2.4, word = "FLEX!", unlock = {kind = "robux", price = 149, rarity = "RARE"},
		desc = "Flexes both little arms, curl after curl."},
	dead = {name = "Play Dead", tag = "PLAY DEAD", dur = 3.3, word = "RIP", unlock = {kind = "earn", stat = "StatBestStreak", need = 5, text = "Win 5 Arena matches in a row"},
		desc = "Flops on its back, halo, RIP. Then flips back up."},
	yawn = {name = "Big Yawn", tag = "YAWN", dur = 2.7, word = "Zzz", unlock = {kind = "robux", price = 149, rarity = "RARE"},
		desc = "Huge yawn, Zzz, then a loud CHOMP."},
}

EC.SLOTS = 8

function EC.get(id)
	return type(id) == "string" and EC.EMOTES[id] or nil
end

-- stats: {[stat name] = number} (player attributes)
function EC.earned(id, stats)
	local e = EC.get(id)
	if not (e and e.unlock.kind == "earn") then return false end
	local v = stats and tonumber(stats[e.unlock.stat]) or 0
	return v >= e.unlock.need
end

-- owned: {[id] = true}; allUnlocked: SkinCatalog.ALL_UNLOCKED (the shared test switch)
function EC.owns(id, owned, allUnlocked, stats)
	local e = EC.get(id)
	if not e then return false end
	if allUnlocked == true or e.unlock.kind == "free" then return true end
	if type(owned) == "table" and owned[id] == true then return true end
	return e.unlock.kind == "earn" and EC.earned(id, stats)
end

-- a saved wheel -> 8 entries (id or false), unknown / duplicate ids dropped
function EC.sanitizeWheel(w)
	local out, seen = {}, {}
	for i = 1, EC.SLOTS do
		local id = type(w) == "table" and w[i] or nil
		if type(id) == "string" and EC.EMOTES[id] and not seen[id] then
			out[i] = id
			seen[id] = true
		else
			out[i] = false
		end
	end
	return out
end

return EC
