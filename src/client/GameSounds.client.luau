-- GameSounds v1.0 (Mecha Dino Arena) — the arcade layer of core game sounds, played only for you (LocalScript,
-- StarterPlayerScripts). MDA-552, plan docs/plans/SOUND_PASS_v1.0.md; Kepu 2026-11-16 14:38 "okay lets do the sound pass",
-- picks "Mixed", "Core first, then dinos", "Sound board in Studio"; 14:50 picks from the Sound Pick Board page
-- (docs/mockups/sound_pick_board_v0.1.html): "hit A, kill A, captured C, lost A, contested A, moving C, tick C, go B, click B,
-- win A, lose A". The 11 sounds are original 8-bit sounds made for this game (files docs/sfx/MDA_SFX_<event>.wav).
-- Every sound is 2D (SoundService:PlayLocalSound of a template Sound in the SoundGroup "GameSFX"), so it does not fade with
-- distance, and only you hear it. Nothing on the server changes; everything is read from state the game already replicates.
-- Events (each one: script attribute GameSounds_<event>Enabled (default true), GameSoundsId_<event> (the asset id; "" = silent),
-- GameSoundsVol_<event>):
--   * hit       your character's LastDealtAt changes (TrooStatsServer stamps the attacker on every LastHitAt / TrooHitAt /
--               KilledAt it causes); at most once per GameSoundsHitGap (0.07) s.
--   * kill      any dino's KilledAt changes (players' characters, DinoIsland.Bots) with KilledBy == your name or KilledByUserId ==
--               your UserId (read one frame after KilledAt changes); at most once per model per KilledAt value.
--   * captured / lost / contested
--               ReplicatedStorage.Hardpoint HpOcc changes while HpPhase is "live" and you have a HardpointTeam: your team letter =
--               captured, the other letter = lost, "C" = contested, "N" = nothing; the same sound not again within
--               GameSoundsOccGap (1) s.
--   * moving    while HpPhase "live": once per point (HpIndex) when HpPointEndsAt - server time drops to GameSoundsMoveWarn (5) s.
--   * tick      while HpPhase "warmup": when the whole seconds left (ceil(HpPointEndsAt - server time)) become 3, 2 or 1
--               (from GameSoundsTickFrom, 3).
--   * go        HpPhase changes from "warmup" to "live".
--   * win / lose HpPhase changes to "results": HpWinner == your team -> win, the other team -> lose; "draw" -> nothing.
--   * click     a GuiButton's Activated inside one of the ScreenGuis named in GameSoundsClickGuis (menus, Lab, pre-game, island and
--               respawn screens; not the ability / attack buttons).
--   * hurt      (v1.2) your character's Humanoid health drops (every damage path ends there: ArenaPvP bridges DummyHealth to
--               Humanoid:TakeDamage) to a value above 0 and below MaxHealth; not within GameSoundsHurtSpawnIgnore (1) s of the
--               character spawning (a MaxHealth set on spawn also lowers Health); at most once per GameSoundsHurtGap (0.15) s.
--   * died      (v1.2) your character's Humanoid.Died; once per character.
--   * cloak / shield / adren / cannon
--               (v1.3, the Raptor's buttons) any dino's (players' characters, DinoIsland.Bots) CloakStartedAt /
--               EnergyShieldStartedAt / AdrenalineStartedAt / ScreechStartedAt (Shock Cannon) changes to a number: a 3D copy of
--               the sound at that dino's HumanoidRootPart (else PrimaryPart), heard by everyone near it (each client plays its
--               own copy; RollOffMaxDistance GameSoundsAbilityRange (200), RollOffMinDistance GameSoundsAbilityNear (10)).
--   * scent     (v1.3) your character's ScentStartedAt changes to a number: 2D, only you (only you see the trails).
--   * dgatling / dmortar / dspine / dover / dhiss / dpump / dscope
--               (v1.4, the Dilophosaurus' buttons) like cloak: 3D at the dino, heard by everyone near it, on DiloGatlingAt (the
--               press; the sound covers the spin-up and the burst) / DiloMortarFireAt (the canister leaves) / DiloSpineBurstAt
--               (the spines leave) / DiloOverdriveAt (the press; the sound covers the 0.7 s charge) / DiloHissBlastAt (the blast)
--               / DiloPumpJoltAt (the jolt) / DiloScopeShotAt (the shot).
--   Not while you are in the menu (player InMenu), except click.
-- Switch: script attribute GameSoundsEnabled (default true, read per event). SoundGroup GameSFX volume: GameSoundsVolume (1).
-- Diagnostics: GameSoundsVersion, GameSoundsLast ("<event>"), GameSoundsCount_<event>; v1.3 GameSoundsLast3D ("<event>:<dino>").
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local VERSION = "1.0"
VERSION = "1.1" -- v1.1 the uploaded sound ids are the defaults
-- v1.1 (MDA-552; Kepu 2026-11-16 15:04 "You upload it. I'm away from the PC"): the 11 sounds were imported through Studio's Asset
--   Manager to BloxSolidYT's inventory; their ids are now the GameSoundsId_<event> defaults (IDS below).
VERSION = "1.2" -- v1.2 getting hit and death sounds
VERSION = "1.3" -- v1.3 the Raptor's ability sounds
VERSION = "1.4" -- v1.4 the Dilophosaurus' ability sounds
-- v1.2 (MDA-552; Kepu 2026-11-16 15:27 picks from the Sound Pick Board round 2: "hurt C, died C"): two original sounds in the punchy
--   real style (hurt = crunchy punch with a metal tick, 0.30 s; died = low dying growl and thud, 1.50 s), files
--   docs/sfx/MDA_SFX_hurt.wav / MDA_SFX_died.wav, imported through Studio's Asset Manager. New events "hurt" and "died" (header).
-- v1.3 (MDA-552; Kepu 2026-11-16 15:45 "Next" -> the Raptor first (the default dino); 15:50 picks from the Sound Pick Board round 3:
--   "cloak C, shield B, adren A, cannon A, scent A"; who hears: "Nearby, Scent only you"): five original sounds (files
--   docs/sfx/MDA_SFX_<event>.wav), imported through Studio's Asset Manager. New events cloak, shield, adren, cannon (3D at the dino)
--   and scent (2D, yours only) (header). Bite, pounce, roar, the Thrusters boost and the Shock Mine keep their own sounds.
-- v1.4 (MDA-552; Kepu 2026-11-16 15:57 "next" -> the Dilophosaurus (the most silent buttons); 16:02 picks from the Sound Pick Board
--   round 4: "gatling B, mortar B, spine B, over A, hiss B, pump A, scope C"): seven original sounds (files
--   docs/sfx/MDA_SFX_dilo_<part>.wav), imported through Studio's Asset Manager, heard like the Raptor's (3D at the dino). Spring Jets
--   keeps its thruster sound (DiloMovesFX); the dilo's bite and spit stay silent.
script:SetAttribute("GameSoundsVersion", VERSION)
local player = Players.LocalPlayer

local EVENTS = {"hit", "kill", "captured", "lost", "contested", "moving", "tick", "go", "click", "win", "lose",
	"hurt", "died", -- v1.2 hurt, died
	"cloak", "shield", "adren", "cannon", "scent", -- v1.3 Raptor buttons
	"dgatling", "dmortar", "dspine", "dover", "dhiss", "dpump", "dscope"} -- v1.4 Dilophosaurus buttons
local IDS = {hit = "123580812773962", kill = "76655662060940", captured = "113513728853752", lost = "124135883749071",
	contested = "101864400003768", moving = "136030860049130", tick = "86647331351122", go = "122207388352651",
	click = "100987841683034", win = "71840308309828", lose = "81529780885336",
	hurt = "75565630737484", died = "97374555569398", -- v1.1; v1.2 hurt, died
	cloak = "71499307467716", shield = "127396962777997", adren = "127472396863191", cannon = "103381972237825",
	scent = "73289725571120", -- v1.3
	dgatling = "78744560071574", dmortar = "88561547660478", dspine = "70381297668849", dover = "139341624407479",
	dhiss = "91279059395796", dpump = "75209586059891", dscope = "123275908451380"} -- v1.4
local VOL = {hit = 0.5, kill = 0.7, captured = 0.6, lost = 0.6, contested = 0.5, moving = 0.6, tick = 0.6, go = 0.7,
	click = 0.4, win = 0.7, lose = 0.7, hurt = 0.6, died = 0.8,
	cloak = 0.7, shield = 0.7, adren = 0.7, cannon = 0.8, scent = 0.6, -- v1.3
	dgatling = 0.6, dmortar = 0.8, dspine = 0.7, dover = 0.7, dhiss = 0.8, dpump = 0.7, dscope = 0.7} -- v1.4
for k, v in pairs({GameSoundsEnabled = true, GameSoundsVolume = 1, GameSoundsHitGap = 0.07, GameSoundsOccGap = 1,
	GameSoundsMoveWarn = 5, GameSoundsTickFrom = 3, GameSoundsHurtGap = 0.15, GameSoundsHurtSpawnIgnore = 1, -- v1.2
	GameSoundsAbilityRange = 200, GameSoundsAbilityNear = 10, -- v1.3
	GameSoundsClickGuis = "MainMenu,Lab,LabButton,PregameScreen,IslandDino,PhoneMenu,RespawnScreen,CameraButton,SquadButton,PortalHUD,ArenaQueue,ArenaStatus,HardpointHUD"}) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, v) end
end
for _, e in ipairs(EVENTS) do
	if script:GetAttribute("GameSounds_" .. e .. "Enabled") == nil then script:SetAttribute("GameSounds_" .. e .. "Enabled", true) end
	if script:GetAttribute("GameSoundsId_" .. e) == nil then script:SetAttribute("GameSoundsId_" .. e, IDS[e] or "") end
	if script:GetAttribute("GameSoundsVol_" .. e) == nil then script:SetAttribute("GameSoundsVol_" .. e, VOL[e]) end
end
local function num(k, d) return tonumber(script:GetAttribute(k)) or d end

local group = SoundService:FindFirstChild("GameSFX")
if not (group and group:IsA("SoundGroup")) then
	group = Instance.new("SoundGroup")
	group.Name = "GameSFX"
	group.Parent = SoundService
end
local templates = {}
local function template(e)
	local id = script:GetAttribute("GameSoundsId_" .. e)
	id = type(id) == "string" and id or tostring(id or "")
	if id == "" or id == "0" then return nil end
	if not id:find("^rbxasset") then id = "rbxassetid://" .. id end
	local s = templates[e]
	if not s then
		s = Instance.new("Sound")
		s.Name = "GameSounds_" .. e
		s.SoundGroup = group
		s.Parent = script
		templates[e] = s
	end
	if s.SoundId ~= id then s.SoundId = id end
	s.Volume = num("GameSoundsVol_" .. e, VOL[e])
	return s
end
local function play(e, inMenuOk)
	if script:GetAttribute("GameSoundsEnabled") == false or script:GetAttribute("GameSounds_" .. e .. "Enabled") == false then return end
	if not inMenuOk and player:GetAttribute("InMenu") == true then return end
	group.Volume = num("GameSoundsVolume", 1)
	local s = template(e)
	script:SetAttribute("GameSoundsLast", e)
	script:SetAttribute("GameSoundsCount_" .. e, (script:GetAttribute("GameSoundsCount_" .. e) or 0) + 1)
	if s then SoundService:PlayLocalSound(s) end
end
for _, e in ipairs(EVENTS) do template(e) end -- preload the ones that have ids

-- hit (your character's LastDealtAt) ---------------------------------------------------------------------------------------
local lastHit = 0
local function hookChar(char)
	char:GetAttributeChangedSignal("LastDealtAt"):Connect(function()
		if os.clock() - lastHit < num("GameSoundsHitGap", 0.07) then return end
		lastHit = os.clock()
		play("hit")
	end)
end
player.CharacterAdded:Connect(hookChar)
if player.Character then hookChar(player.Character) end

-- v1.2 hurt / died (your character's Humanoid) ------------------------------------------------------------------------------
local lastHurt = 0
local function hookHealth(char)
	local spawnedAt = os.clock()
	local hum = char:WaitForChild("Humanoid", 10)
	if not (hum and hum:IsA("Humanoid")) then return end
	local last = hum.Health
	local diedPlayed = false
	hum.HealthChanged:Connect(function(h)
		local prev = last
		last = h
		if h >= prev - 0.01 or h <= 0 or h >= hum.MaxHealth then return end
		if os.clock() - spawnedAt < num("GameSoundsHurtSpawnIgnore", 1) then return end
		if os.clock() - lastHurt < num("GameSoundsHurtGap", 0.15) then return end
		lastHurt = os.clock()
		play("hurt")
	end)
	hum.Died:Connect(function()
		if diedPlayed then return end
		diedPlayed = true
		play("died")
	end)
end
player.CharacterAdded:Connect(hookHealth)
if player.Character then task.spawn(hookHealth, player.Character) end

-- v1.3 the Raptor's ability sounds: 3D at the dino for cloak / shield / adren / cannon, 2D yours only for scent ---------------
local Debris = game:GetService("Debris")
local ABILITY = {cloak = "CloakStartedAt", shield = "EnergyShieldStartedAt", adren = "AdrenalineStartedAt",
	cannon = "ScreechStartedAt"}
for e, attr in pairs({dgatling = "DiloGatlingAt", dmortar = "DiloMortarFireAt", dspine = "DiloSpineBurstAt", -- v1.4 Dilophosaurus
	dover = "DiloOverdriveAt", dhiss = "DiloHissBlastAt", dpump = "DiloPumpJoltAt", dscope = "DiloScopeShotAt"}) do
	ABILITY[e] = attr
end
local function play3D(e, m)
	if script:GetAttribute("GameSoundsEnabled") == false or script:GetAttribute("GameSounds_" .. e .. "Enabled") == false then return end
	if player:GetAttribute("InMenu") == true then return end
	local root = m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart
	if not (root and root:IsA("BasePart")) then return end
	group.Volume = num("GameSoundsVolume", 1)
	local tpl = template(e)
	script:SetAttribute("GameSoundsLast", e)
	script:SetAttribute("GameSoundsLast3D", e .. ":" .. m.Name)
	script:SetAttribute("GameSoundsCount_" .. e, (script:GetAttribute("GameSoundsCount_" .. e) or 0) + 1)
	if not tpl then return end
	local s = tpl:Clone()
	s.RollOffMaxDistance = num("GameSoundsAbilityRange", 200)
	s.RollOffMinDistance = num("GameSoundsAbilityNear", 10)
	s.Parent = root
	s:Play()
	Debris:AddItem(s, math.max(tpl.TimeLength, 1) + 0.5)
end
local hookedAbility = setmetatable({}, {__mode = "k"})
local function hookAbility(m)
	if hookedAbility[m] or not m:IsA("Model") then return end
	hookedAbility[m] = true
	for e, attr in pairs(ABILITY) do
		m:GetAttributeChangedSignal(attr):Connect(function()
			if typeof(m:GetAttribute(attr)) == "number" then play3D(e, m) end
		end)
	end
	if m == player.Character then
		m:GetAttributeChangedSignal("ScentStartedAt"):Connect(function()
			if typeof(m:GetAttribute("ScentStartedAt")) == "number" then play("scent") end
		end)
	end
end
local function watchAbility(pl)
	pl.CharacterAdded:Connect(hookAbility)
	if pl.Character then hookAbility(pl.Character) end
end
Players.PlayerAdded:Connect(watchAbility)
for _, pl in ipairs(Players:GetPlayers()) do watchAbility(pl) end
task.spawn(function()
	local isl = workspace:WaitForChild("DinoIsland", 60)
	local bots = isl and isl:WaitForChild("Bots", 60)
	if not bots then return end
	bots.ChildAdded:Connect(hookAbility)
	for _, b in ipairs(bots:GetChildren()) do hookAbility(b) end
end)

-- kill (any dino's KilledAt with you as the killer) ------------------------------------------------------------------------
local killSeen = setmetatable({}, {__mode = "k"})
local hookedKill = setmetatable({}, {__mode = "k"})
local function hookKill(m)
	if hookedKill[m] or not m:IsA("Model") then return end
	hookedKill[m] = true
	m:GetAttributeChangedSignal("KilledAt"):Connect(function()
		task.wait() -- KilledBy / KilledByUserId can land after KilledAt in the same update; read them a frame later
		local at = m:GetAttribute("KilledAt")
		if at == nil or killSeen[m] == at then return end
		local by, byId = m:GetAttribute("KilledBy"), m:GetAttribute("KilledByUserId")
		if by == player.Name or (tonumber(byId) or 0) == player.UserId then
			killSeen[m] = at
			play("kill")
		end
	end)
end
local function watchPlayer(pl)
	pl.CharacterAdded:Connect(hookKill)
	if pl.Character then hookKill(pl.Character) end
end
Players.PlayerAdded:Connect(watchPlayer)
for _, pl in ipairs(Players:GetPlayers()) do watchPlayer(pl) end
task.spawn(function()
	local isl = workspace:WaitForChild("DinoIsland", 60)
	local bots = isl and isl:WaitForChild("Bots", 60)
	if not bots then return end
	bots.ChildAdded:Connect(hookKill)
	for _, b in ipairs(bots:GetChildren()) do hookKill(b) end
end)

-- menu clicks ---------------------------------------------------------------------------------------------------------------
local clickHooked = setmetatable({}, {__mode = "k"})
local function clickGuiNamed(name)
	for n in string.gmatch(tostring(script:GetAttribute("GameSoundsClickGuis") or ""), "[^,%s]+") do
		if n == name then return true end
	end
	return false
end
local function hookButton(b)
	if clickHooked[b] or not b:IsA("GuiButton") then return end
	local sg = b:FindFirstAncestorWhichIsA("LayerCollector")
	if not (sg and clickGuiNamed(sg.Name)) then return end
	clickHooked[b] = true
	b.Activated:Connect(function() play("click", true) end)
end
task.spawn(function()
	local pg = player:WaitForChild("PlayerGui")
	pg.DescendantAdded:Connect(function(d) task.defer(hookButton, d) end) -- a ScreenGui can be named after it is parented
	for _, d in ipairs(pg:GetDescendants()) do hookButton(d) end
end)

-- hardpoint: point, countdown, GO, win / lose -------------------------------------------------------------------------------
task.spawn(function()
	local hp = ReplicatedStorage:WaitForChild("Hardpoint", 120)
	if not hp then return end
	local lastOcc = {}
	hp:GetAttributeChangedSignal("HpOcc"):Connect(function()
		if hp:GetAttribute("HpPhase") ~= "live" then return end
		local team = player:GetAttribute("HardpointTeam")
		if team ~= "A" and team ~= "B" then return end
		local occ = hp:GetAttribute("HpOcc")
		local e = (occ == team and "captured") or (occ == "C" and "contested") or ((occ == "A" or occ == "B") and "lost") or nil
		if not e then return end
		if os.clock() - (lastOcc[e] or -math.huge) < num("GameSoundsOccGap", 1) then return end
		lastOcc[e] = os.clock()
		play(e)
	end)
	local prevPhase = hp:GetAttribute("HpPhase")
	hp:GetAttributeChangedSignal("HpPhase"):Connect(function()
		local ph = hp:GetAttribute("HpPhase")
		if prevPhase == "warmup" and ph == "live" then play("go") end
		if ph == "results" and prevPhase ~= "results" then
			local team, w = player:GetAttribute("HardpointTeam"), hp:GetAttribute("HpWinner")
			if (team == "A" or team == "B") and (w == "A" or w == "B") then play(w == team and "win" or "lose", true) end
		end
		prevPhase = ph
	end)
	local warnedIndex, lastTick = nil, nil
	RunService.Heartbeat:Connect(function()
		local ph = hp:GetAttribute("HpPhase")
		local ends = tonumber(hp:GetAttribute("HpPointEndsAt"))
		if not ends then return end
		local left = ends - workspace:GetServerTimeNow()
		if ph == "warmup" then
			local s = math.ceil(left)
			if s >= 1 and s <= num("GameSoundsTickFrom", 3) and s ~= lastTick then play("tick") end
			lastTick = s
		else
			lastTick = nil
		end
		if ph == "live" then
			local idx = hp:GetAttribute("HpIndex")
			if left > 0 and left <= num("GameSoundsMoveWarn", 5) and warnedIndex ~= idx then
				warnedIndex = idx
				play("moving")
			end
		end
	end)
end)
