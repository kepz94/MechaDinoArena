-- RespawnServer v1.0 (Mecha Dino Arena) — match respawn: 5 s wait, swap dino + loadout while dead, a CHANGE window after
-- spawning (Script, ServerScriptService). MDA-537, plan docs/plans/RESPAWN_SWAP_v1.0.md rules 1, 4, 5, mockup
-- docs/mockups/respawn_change_v0.1.html; Kepu 2026-11-13 21:18 "the ability to change Dino and load out mid match. Maybe a 5 second
-- respawn wait with the option to change Dino in that time and the few seconds after you spawn have the button stay there";
-- picks "C · Death cam + button", "Wait for me", "5 s or until you attack/get hit".
-- Who: players in a match (player PrInMatch == true and ReplicatedStorage.Practice PrPhase == "match"). Island deaths keep the
--   global 3 s respawn (DinoHealthServer); bots are not touched.
-- Death (Humanoid.Died of a match player's character): player attributes RespawnHold = true, RespawnDiedAt = server time,
--   RespawnAt = died + RespawnWait (5), RespawnPickOpen = false, RespawnGraceUntil = 0. Roblox still respawns at 3 s;
--   PracticeServer 1.13 parks that body (anchored RespawnParkY studs up) while RespawnHold is true.
-- Release (checked every 0.1 s): now >= RespawnAt and the picker closed, or now >= died + RespawnWait + RespawnPickMax (10)
--   ("Wait for me" cap); and the current body is alive and is the wanted dino (DinoSpecies) -> RespawnHold = false (PracticeServer
--   places it on a spawn spot); when the player's PrPlacedAt changes after that, RespawnGraceUntil = now + RespawnGrace (5).
--   Leaving the match / the match ending / RespawnServerEnabled false -> RespawnHold false at once, grace 0.
-- RemoteEvent ReplicatedStorage.RespawnRequest(action, arg):
--   "open"     while held or in the grace -> RespawnPickOpen = true
--   "close" / "ready"  -> RespawnPickOpen = false
--   "dino", id (a SpeciesServer species: Raptor TRex Pachy Herrera Teno Therizino Dilo Troodon; 1 s between picks):
--              held: DinoSpecies = id; if the current body is alive and another dino, player:LoadCharacter() (T-Rex, then
--              SpeciesServer swaps it; PracticeServer parks it again); still dead: nothing more (the 3 s respawn + SpeciesServer
--              do it). In the grace: another dino -> DinoSpecies = id, grace 0, back on hold at once (RespawnAt = now, cap now +
--              RespawnPickMax, player RespawnFromGrace = true: no death screen), player:LoadCharacter() (PracticeServer parks the new
--              body, the picker stays on its parts step; closing it places the body on a spawn spot, full health, no second
--              window); the same dino -> "same" (window and picker stay: the parts step). Otherwise "denied".
--   "attacked" in the grace -> grace 0 (the client reports an attack press: RespawnScreen 1.0).
--   Any health loss of the character in the grace -> grace 0. The window ending (any way) while not on hold closes the picker.
-- Each accepted pick also sets player RespawnPicked = id first (SpeciesServer 1.9 remembers it).
-- Diagnostics: RespawnServerVersion, RespawnDeaths, RespawnSwaps, RespawnGraceSwaps, player RespawnLastResult.
-- Switch: script attribute RespawnServerEnabled (default true, read per death / tick / request). Numbers: RespawnWait (5),
--   RespawnPickMax (10), RespawnGrace (5), RespawnParkY (3000; read by PracticeServer 1.13).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local VERSION = "1.0"
script:SetAttribute("RespawnServerVersion", VERSION)
for k, v in pairs({RespawnServerEnabled = true, RespawnWait = 5, RespawnPickMax = 10, RespawnGrace = 5, RespawnParkY = 3000,
	RespawnDeaths = 0, RespawnSwaps = 0, RespawnGraceSwaps = 0}) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, v) end
end
local function cfg(k) return tonumber(script:GetAttribute(k)) or 0 end
local function on() return script:GetAttribute("RespawnServerEnabled") ~= false end
local function now() return workspace:GetServerTimeNow() end
local function bump(k) script:SetAttribute(k, (script:GetAttribute(k) or 0) + 1) end
local SPECIES = {Raptor = true, TRex = true, Pachy = true, Herrera = true, Teno = true, Therizino = true, Dilo = true, Troodon = true}

local remote = ReplicatedStorage:FindFirstChild("RespawnRequest")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "RespawnRequest"
	remote.Parent = ReplicatedStorage
end

local function practice() return ReplicatedStorage:FindFirstChild("Practice") end
local function inMatch(pl)
	local pr = practice()
	return pl:GetAttribute("PrInMatch") == true and pr ~= nil and pr:GetAttribute("PrPhase") == "match"
end
local function speciesOf(c) return c and c:GetAttribute("Species") end
local function alive(c)
	local h = c and c:FindFirstChildOfClass("Humanoid")
	return h ~= nil and h.Health > 0
end
local function clear(pl)
	if pl:GetAttribute("RespawnHold") == true then pl:SetAttribute("RespawnHold", false) end
	pl:SetAttribute("RespawnPickOpen", false)
	pl:SetAttribute("RespawnGraceUntil", 0)
end
local function graceOn(pl) return (tonumber(pl:GetAttribute("RespawnGraceUntil")) or 0) > now() end
local function endGrace(pl, why)
	if graceOn(pl) then
		pl:SetAttribute("RespawnGraceUntil", 0)
		pl:SetAttribute("RespawnLastResult", "graceEnd:" .. why)
		if pl:GetAttribute("RespawnHold") ~= true then pl:SetAttribute("RespawnPickOpen", false) end
	end
end

local graceArmed = {} -- [player] = true: the next placement starts the grace
local function onCharacter(pl, c)
	local hum = c:WaitForChild("Humanoid", 10)
	if not hum then return end
	local last = hum.Health
	hum.HealthChanged:Connect(function(h)
		if h < last - 0.01 then endGrace(pl, "hit") end
		last = h
	end)
	hum.Died:Connect(function()
		if not on() or not inMatch(pl) then return end
		local t = now()
		pl:SetAttribute("RespawnDiedAt", t)
		pl:SetAttribute("RespawnAt", t + cfg("RespawnWait"))
		pl:SetAttribute("RespawnPickOpen", false)
		pl:SetAttribute("RespawnGraceUntil", 0)
		pl:SetAttribute("RespawnFromGrace", false)
		pl:SetAttribute("RespawnHold", true)
		graceArmed[pl] = true
		bump("RespawnDeaths")
	end)
end
local function onPlayer(pl)
	pl.CharacterAdded:Connect(function(c) onCharacter(pl, c) end)
	if pl.Character then task.spawn(onCharacter, pl, pl.Character) end
	pl:GetAttributeChangedSignal("PrPlacedAt"):Connect(function()
		if graceArmed[pl] and pl:GetAttribute("RespawnHold") ~= true then
			graceArmed[pl] = nil
			if on() and inMatch(pl) then pl:SetAttribute("RespawnGraceUntil", now() + cfg("RespawnGrace")) end
		end
	end)
	pl:GetAttributeChangedSignal("PrInMatch"):Connect(function()
		if pl:GetAttribute("PrInMatch") ~= true then graceArmed[pl] = nil clear(pl) end
	end)
end
Players.PlayerAdded:Connect(onPlayer)
for _, pl in ipairs(Players:GetPlayers()) do task.spawn(onPlayer, pl) end
Players.PlayerRemoving:Connect(function(pl) graceArmed[pl] = nil end)

-- release loop
local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < 0.1 then return end
	acc = 0
	local t = now()
	for _, pl in ipairs(Players:GetPlayers()) do
		if pl:GetAttribute("RespawnHold") == true then
			if not on() or not inMatch(pl) then
				graceArmed[pl] = nil
				clear(pl)
			else
				local died = tonumber(pl:GetAttribute("RespawnDiedAt")) or t
				local at = tonumber(pl:GetAttribute("RespawnAt")) or t
				local cap = died + cfg("RespawnWait") + cfg("RespawnPickMax")
				local due = (t >= at and pl:GetAttribute("RespawnPickOpen") ~= true) or t >= cap
				local c = pl.Character
				local want = pl:GetAttribute("DinoSpecies")
				if due and alive(c) and (want == nil or speciesOf(c) == want) then
					pl:SetAttribute("RespawnPickOpen", false)
					pl:SetAttribute("RespawnHold", false)
				end
			end
		elseif graceOn(pl) and (not on() or not inMatch(pl)) then
			pl:SetAttribute("RespawnGraceUntil", 0)
		elseif pl:GetAttribute("RespawnPickOpen") == true and not graceOn(pl) then -- the window ended: the picker closes
			pl:SetAttribute("RespawnPickOpen", false)
		end
	end
end)

local lastPick = {}
remote.OnServerEvent:Connect(function(pl, action, arg)
	if not on() or not inMatch(pl) or type(action) ~= "string" then pl:SetAttribute("RespawnLastResult", "off") return end
	local held, grace = pl:GetAttribute("RespawnHold") == true, graceOn(pl)
	if action == "open" then
		if held or grace then pl:SetAttribute("RespawnPickOpen", true) pl:SetAttribute("RespawnLastResult", "open")
		else pl:SetAttribute("RespawnLastResult", "denied") end
	elseif action == "close" or action == "ready" then
		pl:SetAttribute("RespawnPickOpen", false)
		pl:SetAttribute("RespawnLastResult", action)
	elseif action == "attacked" then
		endGrace(pl, "attack")
	elseif action == "dino" then
		if type(arg) ~= "string" or not SPECIES[arg] then pl:SetAttribute("RespawnLastResult", "badArg") return end
		if lastPick[pl] and os.clock() - lastPick[pl] < 1 then pl:SetAttribute("RespawnLastResult", "cooldown") return end
		lastPick[pl] = os.clock()
		if held then
			pl:SetAttribute("RespawnPicked", arg) -- SpeciesServer 1.9 remembers it
			pl:SetAttribute("DinoSpecies", arg)
			local c = pl.Character
			if alive(c) and speciesOf(c) ~= arg then pl:LoadCharacter() end
			bump("RespawnSwaps")
			pl:SetAttribute("RespawnLastResult", "dino:" .. arg)
		elseif grace then
			if speciesOf(pl.Character) == arg then -- the same dino: keep the window (the parts step comes next)
				pl:SetAttribute("RespawnLastResult", "same")
				return
			end
			local t = now()
			pl:SetAttribute("RespawnGraceUntil", 0)
			pl:SetAttribute("RespawnPicked", arg)
			pl:SetAttribute("DinoSpecies", arg)
			pl:SetAttribute("RespawnDiedAt", t - cfg("RespawnWait")) -- cap = now + RespawnPickMax
			pl:SetAttribute("RespawnAt", t)
			pl:SetAttribute("RespawnFromGrace", true)
			pl:SetAttribute("RespawnHold", true) -- before LoadCharacter: PracticeServer parks the new body
			pl:LoadCharacter()
			bump("RespawnGraceSwaps")
			pl:SetAttribute("RespawnLastResult", "graceDino:" .. arg)
		else
			pl:SetAttribute("RespawnLastResult", "denied")
		end
	else
		pl:SetAttribute("RespawnLastResult", "badArg")
	end
end)
Players.PlayerRemoving:Connect(function(pl) lastPick[pl] = nil end)
