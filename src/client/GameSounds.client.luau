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
--   Not while you are in the menu (player InMenu), except click.
-- Switch: script attribute GameSoundsEnabled (default true, read per event). SoundGroup GameSFX volume: GameSoundsVolume (1).
-- Diagnostics: GameSoundsVersion, GameSoundsLast ("<event>"), GameSoundsCount_<event>.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local VERSION = "1.0"
script:SetAttribute("GameSoundsVersion", VERSION)
local player = Players.LocalPlayer

local EVENTS = {"hit", "kill", "captured", "lost", "contested", "moving", "tick", "go", "click", "win", "lose"}
local VOL = {hit = 0.5, kill = 0.7, captured = 0.6, lost = 0.6, contested = 0.5, moving = 0.6, tick = 0.6, go = 0.7,
	click = 0.4, win = 0.7, lose = 0.7}
for k, v in pairs({GameSoundsEnabled = true, GameSoundsVolume = 1, GameSoundsHitGap = 0.07, GameSoundsOccGap = 1,
	GameSoundsMoveWarn = 5, GameSoundsTickFrom = 3,
	GameSoundsClickGuis = "MainMenu,Lab,LabButton,PregameScreen,IslandDino,PhoneMenu,RespawnScreen,CameraButton,SquadButton,PortalHUD,ArenaQueue,ArenaStatus,HardpointHUD"}) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, v) end
end
for _, e in ipairs(EVENTS) do
	if script:GetAttribute("GameSounds_" .. e .. "Enabled") == nil then script:SetAttribute("GameSounds_" .. e .. "Enabled", true) end
	if script:GetAttribute("GameSoundsId_" .. e) == nil then script:SetAttribute("GameSoundsId_" .. e, "") end
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
