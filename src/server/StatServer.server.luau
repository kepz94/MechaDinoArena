-- StatServer v1.1 (Mecha Dino Arena) — applies the 5-stat point sheet (StatSheet 1.0) to every player dino, and turns on
-- adult spawns. MDA-2, plan docs/plans/CLASSSTATS_v1.0.md (Task 2 + deterministic map), ADR-001.
-- User: everyone spawns as an adult dino; build types via one stat sheet (option C); points added later by the stat
--   trees (part 3) arrive as player attributes StatAdded_<Stat> (Health / Attack / Defense / Speed / Support).
-- Adult spawns: script attribute ArenaAdultSpawns (default true) sets ServerScriptService.GrowthServer's attribute
--   GrowthEnabled = false at start (GrowthServer 1.2 then keeps every character at its adult base; its code is unchanged).
--   Script attribute ArenaAdultSpawnsApplied = true / false / "noGrowthServer".
-- Each player character (CharacterAdded, also SpeciesServer's raptor body):
--   1. waits for DinoMaxHealthSet (DinoHealthServer 1.0) at most BASE_WAIT s (missing -> StatState "noHealth", continues
--      with the current MaxHealth) and for GrowthState to leave "waiting" (same limit);
--   2. Species not in StatSheet.SPECIES -> StatState "noSheet", nothing written;
--   3. base = for each of BiteDamage / PounceLandDamage / PounceTickDamage / MoveWalkSpeed / MoveRunSpeed /
--      MoveCreepSpeed the character has: GrowthServer's GrowthBase_<key> (its adult value captured before any growth
--      scaling) when present, else the character's own value; MaxHealth: GrowthBaseMaxHealth when present, else
--      Humanoid.MaxHealth -> StatBase_<key>, StatBase_MaxHealth;
--   4. apply.
-- apply: GrowthState == "ready" (growth on) -> StatState "growthOn", nothing written (one writer; ADR-001 accepted risk).
--   StatEnabled == false -> base written back, StatDamageTakenMul 1, StatState "disabled". Else
--   values(base, added(species, player StatAdded_*)) written (only changed values); MaxHealth: at spawn Health = MaxHealth,
--   later the health fraction is kept. Then StatClass, StatAbilities ("Roar,Ram"), StatPoints_<Stat> (start + added),
--   StatAdded_<Stat> (after clamping), StatAddedClamped, StatAppliedAt (server time), StatState "ready".
-- Re-apply: a player StatAdded_* attribute changes; script StatEnabled changes; the character's GrowthState changes.
-- Diagnostics: script StatServerVersion, StatApplies (count); character StatState ("waiting" / "noSheet" / "noHealth" /
--   "growthOn" / "disabled" / "ready"), StatServerVersion.
-- v1.1 (game speed, MDA-37; Kepu: "turn the whole speed of the game down a little bit" -> x0.65 everyone): every
--   MoveWalkSpeed / MoveRunSpeed / MoveCreepSpeed this script writes (ready and disabled) is multiplied by
--   ServerScriptService.ArenaRules' ArenaSpeedScale (ArenaRules 1.3, default 0.65; missing / not a positive number -> 1),
--   rounded to 0.1. The Speed points (StatSheet) still multiply the base first, so the skill steps keep their ratios.
--   A change of ArenaSpeedScale re-applies every character. Diagnostic: character StatSpeedScale.
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local VERSION = "1.1"
local BASE_WAIT = 5
local DEFAULTS = {StatEnabled = true, ArenaAdultSpawns = true}

local SS = require(ServerStorage:WaitForChild("DinoArcade"):WaitForChild("StatSheet"))

script:SetAttribute("StatServerVersion", VERSION)
for k, v in pairs(DEFAULTS) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, v) end
end
script:SetAttribute("StatApplies", 0)
local function get(k)
	local v = script:GetAttribute(k)
	if v == nil then v = DEFAULTS[k] end
	return v
end

-- adult spawns through GrowthServer's own switch
do
	if get("ArenaAdultSpawns") ~= false then
		local gs = ServerScriptService:FindFirstChild("GrowthServer")
		if gs then
			gs:SetAttribute("GrowthEnabled", false)
			script:SetAttribute("ArenaAdultSpawnsApplied", true)
		else
			script:SetAttribute("ArenaAdultSpawnsApplied", "noGrowthServer")
		end
	else
		script:SetAttribute("ArenaAdultSpawnsApplied", false)
	end
end

local chars = {} -- [char] = {player, species, hum, base, baseMax, spawned}

-- v1.1: game speed scale (ArenaRules 1.3)
local SPEED_KEY = {}
for _, k in ipairs(SS.SPEED_KEYS) do SPEED_KEY[k] = true end
local function speedScale()
	local ar = ServerScriptService:FindFirstChild("ArenaRules")
	local v = ar and tonumber(ar:GetAttribute("ArenaSpeedScale"))
	if not v or v ~= v or v <= 0 then return 1 end
	return v
end
local function scaled(k, v)
	if not SPEED_KEY[k] or type(v) ~= "number" then return v end
	return math.floor(v * speedScale() * 10 + 0.5) / 10
end

local function set(inst, k, v)
	if inst:GetAttribute(k) ~= v then inst:SetAttribute(k, v) end
end

local function rawAdded(player)
	local raw = {}
	for _, s in ipairs(SS.STATS) do raw[s] = player:GetAttribute("StatAdded_" .. s) end
	return raw
end

local function writeHealth(st, newMax, atSpawn)
	local hum = st.hum
	if hum.MaxHealth == newMax and not atSpawn then return end
	local frac = hum.MaxHealth > 0 and hum.Health / hum.MaxHealth or 1
	hum.MaxHealth = newMax
	if atSpawn then hum.Health = newMax else hum.Health = math.clamp(frac * newMax, 0, newMax) end
end

local function apply(char, st, atSpawn)
	if not char.Parent then return end
	if char:GetAttribute("GrowthState") == "ready" then
		set(char, "StatState", "growthOn")
		return
	end
	if get("StatEnabled") == false then
		for k, v in pairs(st.base) do set(char, k, scaled(k, v)) end -- v1.1: + speed scale
		set(char, "StatSpeedScale", speedScale()) -- v1.1
		writeHealth(st, st.baseMax, atSpawn)
		set(char, "StatDamageTakenMul", 1)
		set(char, "StatState", "disabled")
		return
	end
	local added, clamped = SS.added(st.species, rawAdded(st.player))
	local base = table.clone(st.base)
	base.MaxHealth = st.baseMax
	local vals = SS.values(base, added)
	for k, v in pairs(vals) do
		if k == "MaxHealth" then writeHealth(st, v, atSpawn) else set(char, k, scaled(k, v)) end -- v1.1: + speed scale
	end
	set(char, "StatSpeedScale", speedScale()) -- v1.1
	local sheet = SS.SPECIES[st.species]
	local points = SS.points(st.species, added)
	set(char, "StatClass", sheet.class)
	set(char, "StatAbilities", table.concat(sheet.abilities, ","))
	for _, s in ipairs(SS.STATS) do
		set(char, "StatPoints_" .. s, points[s])
		set(char, "StatAdded_" .. s, added[s])
	end
	set(char, "StatAddedClamped", clamped)
	char:SetAttribute("StatAppliedAt", workspace:GetServerTimeNow())
	set(char, "StatState", "ready")
	script:SetAttribute("StatApplies", (script:GetAttribute("StatApplies") or 0) + 1)
end

local function onCharacter(player, char)
	local hum = char:WaitForChild("Humanoid", 10)
	if not hum or not char.Parent then return end
	set(char, "StatServerVersion", VERSION)
	set(char, "StatState", "waiting")
	local t0 = os.clock()
	while char.Parent and os.clock() - t0 < BASE_WAIT
		and (char:GetAttribute("DinoMaxHealthSet") == nil or char:GetAttribute("GrowthState") == "waiting") do
		task.wait(0.1)
	end
	if not char.Parent then return end
	local noHealth = char:GetAttribute("DinoMaxHealthSet") == nil
	local species = char:GetAttribute("Species")
	if SS.SPECIES[species] == nil then
		set(char, "StatState", "noSheet")
		return
	end
	-- base: GrowthServer's pre-scaling capture GrowthBase_<key> / GrowthBaseMaxHealth when present (so a character that
	-- spawned while growth was on still gets its adult base), else the character's own value
	local base = {}
	for _, list in ipairs({SS.ATTACK_KEYS, SS.SPEED_KEYS}) do
		for _, k in ipairs(list) do
			local own = char:GetAttribute(k)
			local v = char:GetAttribute("GrowthBase_" .. k)
			if type(own) ~= "number" then v = nil end -- only keys the character itself has
			if type(v) ~= "number" then v = own end
			if type(v) == "number" then
				base[k] = v
				set(char, "StatBase_" .. k, v)
			end
		end
	end
	local gMax = char:GetAttribute("GrowthBaseMaxHealth")
	local st = {player = player, species = species, hum = hum, base = base,
		baseMax = type(gMax) == "number" and gMax or hum.MaxHealth}
	set(char, "StatBase_MaxHealth", st.baseMax)
	chars[char] = st
	apply(char, st, true)
	if noHealth and char:GetAttribute("StatState") == "ready" then set(char, "StatState", "noHealth") end
	char:GetAttributeChangedSignal("GrowthState"):Connect(function()
		if chars[char] then apply(char, st, false) end
	end)
	char.AncestryChanged:Connect(function(_, parent)
		if not parent then chars[char] = nil end
	end)
end

local function onPlayer(player)
	player.CharacterAdded:Connect(function(char) onCharacter(player, char) end)
	if player.Character then task.spawn(onCharacter, player, player.Character) end
	player.AttributeChanged:Connect(function(name)
		if string.sub(name, 1, 9) ~= "StatAdded" then return end
		local char = player.Character
		local st = char and chars[char]
		if st then apply(char, st, false) end
	end)
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do task.spawn(onPlayer, p) end
Players.PlayerRemoving:Connect(function(p)
	for char, st in pairs(chars) do
		if st.player == p then chars[char] = nil end
	end
end)

script:GetAttributeChangedSignal("StatEnabled"):Connect(function()
	for char, st in pairs(chars) do apply(char, st, false) end
end)

-- v1.1: re-apply when the game speed changes
do
	local ar = ServerScriptService:FindFirstChild("ArenaRules")
	if ar then
		ar:GetAttributeChangedSignal("ArenaSpeedScale"):Connect(function()
			for char, st in pairs(chars) do apply(char, st, false) end
		end)
	end
end
