-- FillerRules v1.0 (Mecha Dino Arena) — filler bots: names, made-up records, how many, looks, emotes, timings.
-- Filler Bots v1.0, plan docs/plans/FILLER_BOTS_v1.0.md T1 (MDA-573), ADR-014, mockup docs/mockups/filler_bots_v0.1 (option A).
-- Kepu 2026-11-25: bots on the island and in matches when there aren't enough players, acting like players; picks: the island
--   fills to 8, made-up W-L that stays the same, never on the leaderboard.
-- Pure: no instances, no services. Lives in ServerStorage.DinoArcade.FillerRules (server only). Spec tools/tests/FillerRules.spec.luau.
-- API:
--   name(rng, used) -> string: a Roblox-style name from the word lists below (patterns AdjNoun[digits], Noun_Suffix,
--     xAdjNounx, NounSuffix<year>, lower noun2fast / noun_main). 3..20 characters, letters and digits, at most one underscore,
--     never first or last. Never in `used` and never a practice bot name (PRACTICE); the name is added to `used`.
--   valid(name) -> bool: the name rules above.
--   record(name) -> w, l: FNV-1a 32-bit hash of the name. games = 20 + floor(70 x u1 / 0.7) when u1 < 0.7, else 6 + floor(214 x ((u1 - 0.7) / 0.3)^1.5) (u1 from the hash);
--     win rate = 0.36 + 0.28 x (u2 + u3) / 2; w = round(games x rate) kept within games x 0.36 .. 0.64, l = games - w. The same name always gives the same record.
--   wanted(realPlayers, fillTo) -> bots: 0 when realPlayers is not a number >= 1, else clamp(fillTo - realPlayers, 0, fillTo - 1).
--   look(rng, skinIds, trailIds) -> skinId, trailId: "classic" with weight CLASSIC (0.4) or when no other skin, else a random
--     non-classic id; trail "" with weight NO_TRAIL (0.3) or an empty list, else a random id.
--   emote(rng, state) -> id or nil: state = {afterKill, inSafe, idleFor, idleNeed, emoteIds}. No ids -> nil. afterKill -> an
--     emote with chance AFTER_KILL (0.5). inSafe and idleFor >= idleNeed -> an emote. Else nil.
--   idleGap(rng) -> 20..45 s; joinDelay(rng) -> 8..20 s; respawnDelay() -> 5 s; leaveWalkMax() -> 25 s.
--   tier(rng) -> "Hard" with chance HARD (0.4), else "Normal" (PracticeRules tier names).
local M = {}
M.VERSION = "1.0"

M.CLASSIC = 0.4
M.NO_TRAIL = 0.3
M.AFTER_KILL = 0.5
M.HARD = 0.4
M.PRACTICE = {"Fang", "Mako", "Rook", "Ember", "Vex", "Grit", "Talon", "Nova", "Bolt", "Sable", "Rex", "Dash", "Quill", "Moss",
	"Jinx", "Onyx", "Pike", "Rusty", "Zed", "Kiwi", "Blaze", "Clank", "Drift", "Echo", "Flint", "Gizmo", "Hex", "Ivy",
	"Jolt", "Knox", "Lumen", "Mortar", "Nyx", "Orbit", "Pixel", "Rivet", "Scrap", "Torque", "Volt", "Wrench", "Yuki", "Zap"}

-- word lists, written by hand: no slurs, no real people, no brands
M.ADJ = {"Mossy", "Lava", "Frosty", "Shadow", "Storm", "Cosmic", "Lucky", "Silly", "Big", "Lil", "Tiny", "Mega", "Ultra", "Epic",
	"Sneaky", "Swift", "Mighty", "Crazy", "Toxic", "Turbo", "Neon", "Cyber", "Rusty", "Golden", "Spooky", "Fuzzy", "Salty",
	"Chunky", "Speedy", "Grumpy", "Jumbo", "Stormy", "Sunny", "Wild", "Feral", "Atomic", "Pixel", "Retro", "Hyper", "Sly"}
M.NOUN = {"Raptor", "Rex", "Dino", "Pachy", "Teno", "Dilo", "Troodon", "Herrera", "Theri", "Claw", "Fang", "Tail", "Bite",
	"Stomp", "Roar", "Fossil", "Saur", "Spike", "Scale", "Mech", "Bolt", "Volt", "Laser", "Robo", "Gear", "Zap", "Rocket",
	"Comet", "Egg", "Nest", "Jaw", "Talon", "Horn", "Crest", "Raider", "Dash", "Blaster", "Chomp", "Thunder", "Meteor"}
M.SUFFIX = {"Gamer", "Main", "King", "Queen", "Lord", "Hunter", "Rider", "Master", "Boss", "Kid", "Fan", "Slayer", "Runner",
	"Smash", "Rush", "Energy", "Plays", "Pro", "Squad", "Legend", "Champ", "Buddy", "Zone", "Time"}

local function pick(rng, list) return list[rng:NextInteger(1, #list)] end

function M.valid(n)
	if type(n) ~= "string" or #n < 3 or #n > 20 then return false end
	if n:find("[^%w_]") then return false end
	local _, us = n:gsub("_", "")
	if us > 1 then return false end
	if n:sub(1, 1) == "_" or n:sub(-1) == "_" then return false end
	return true
end

local practiceSet = {}
for _, n in ipairs(M.PRACTICE) do practiceSet[n] = true; practiceSet[string.lower(n)] = true end

local function roll(rng)
	local p = rng:NextNumber()
	if p < 0.30 then
		local n = pick(rng, M.ADJ) .. pick(rng, M.NOUN)
		if rng:NextNumber() < 0.5 then n ..= tostring(rng:NextInteger(1, 999)) end
		return n
	elseif p < 0.50 then
		local n = pick(rng, M.NOUN) .. "_" .. pick(rng, M.SUFFIX)
		if rng:NextNumber() < 0.4 then n = string.lower(n) end
		return n
	elseif p < 0.62 then
		return "x" .. pick(rng, M.ADJ) .. pick(rng, M.NOUN) .. "x"
	elseif p < 0.82 then
		return pick(rng, M.NOUN) .. pick(rng, M.SUFFIX) .. tostring(rng:NextInteger(2008, 2016))
	else
		local w = string.lower(pick(rng, M.NOUN))
		local q = rng:NextNumber()
		if q < 0.4 then return w .. "2fast" end
		if q < 0.7 then return w .. "_main" end
		return w .. string.lower(pick(rng, M.NOUN)) .. tostring(rng:NextInteger(1, 99))
	end
end

function M.name(rng, used)
	used = used or {}
	local n
	for _ = 1, 60 do
		n = roll(rng)
		if M.valid(n) and not used[n] and not practiceSet[n] then used[n] = true return n end
	end
	-- fallback: a long numbered name that cannot clash
	repeat
		n = pick(rng, M.NOUN) .. pick(rng, M.SUFFIX) .. tostring(rng:NextInteger(100, 99999))
		if #n > 20 then n = n:sub(1, 20) end
	until M.valid(n) and not used[n] and not practiceSet[n]
	used[n] = true
	return n
end

local function fnv(s)
	local h = 2166136261
	for i = 1, #s do
		h = bit32.bxor(h, string.byte(s, i))
		h = (h * 16777619) % 4294967296
	end
	return h
end

function M.record(name)
	local h = fnv(tostring(name))
	local u1 = (h % 1000) / 1000
	local u2 = (math.floor(h / 1000) % 1000) / 1000
	local u3 = (math.floor(h / 1000000) % 1000) / 1000
	local games
	if u1 < 0.7 then games = 20 + math.floor(70 * u1 / 0.7) else games = 6 + math.floor(214 * ((u1 - 0.7) / 0.3) ^ 1.5) end
	local rate = 0.36 + 0.28 * (u2 + u3) / 2
	local w = math.floor(games * rate + 0.5)
	w = math.clamp(w, math.ceil(games * 0.36), math.floor(games * 0.64))
	return w, games - w
end

function M.wanted(realPlayers, fillTo)
	if type(realPlayers) ~= "number" or realPlayers < 1 then return 0 end
	fillTo = tonumber(fillTo) or 8
	return math.floor(math.clamp(fillTo - realPlayers, 0, math.max(fillTo - 1, 0)))
end

function M.look(rng, skinIds, trailIds)
	local others = {}
	for _, id in ipairs(skinIds or {}) do if id ~= "classic" then table.insert(others, id) end end
	local skin = "classic"
	if #others > 0 and rng:NextNumber() >= M.CLASSIC then skin = pick(rng, others) end
	local trail = ""
	local trails = trailIds or {}
	if #trails > 0 and rng:NextNumber() >= M.NO_TRAIL then trail = pick(rng, trails) end
	return skin, trail
end

function M.emote(rng, state)
	local ids = state and state.emoteIds
	if type(ids) ~= "table" or #ids == 0 then return nil end
	if state.afterKill then
		if rng:NextNumber() < M.AFTER_KILL then return pick(rng, ids) end
		return nil
	end
	if state.inSafe and (tonumber(state.idleFor) or 0) >= (tonumber(state.idleNeed) or 20) then return pick(rng, ids) end
	return nil
end

function M.idleGap(rng) return 20 + rng:NextNumber() * 25 end
function M.joinDelay(rng) return 8 + rng:NextNumber() * 12 end
function M.respawnDelay() return 5 end
function M.leaveWalkMax() return 25 end
function M.tier(rng) return rng:NextNumber() < M.HARD and "Hard" or "Normal" end

return M
