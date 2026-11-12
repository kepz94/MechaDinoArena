-- ArenaPvP v1.2 (Mecha Dino Arena) — in the Arena, bites, pounces and Blade Claws hurt other players. MDA-89, plan
-- docs/plans/MAIN_MENU_v1.0.md Task 5, ADR-005 (Kepu 2026-10-29: "Add player damage in this plan"; Arena = the same island,
-- no bots, PvP on; the Sandbox keeps no player damage).
-- BiteServer / PounceServer are not changed: they damage a model's DummyHealth when the model has Bitable = true (and, for
--   pounces, a Species). This script makes player characters such targets in the Arena only and turns each DummyHealth
--   drop into real damage:
--   * Mode = ServerStorage.DinoArcade.ModeRules 1.0 currentMode() at start. "sandbox" -> nothing is done (ArenaPvPState
--     "sandbox"); player characters never get Bitable.
--   * "arena": every player character (CharacterAdded, one frame after it is in Workspace, so BiteTargetHealth's deferred
--     DescendantAdded check has already run and never adopts it: no health bar, no KO reset) is bridged. While the player's InMenu ~= true: Bitable = true, DummyMaxHealth =
--     Humanoid.MaxHealth, DummyHealth = Humanoid.Health. While InMenu == true: Bitable = false (nobody can bite / pounce a
--     player in the menu).
--   * Bridge: when DummyHealth drops below the last value this script wrote, d = the drop -> Humanoid:TakeDamage(d)
--     (Energy Shield's ForceField blocks it), character ArenaPvPLastDelta = d; then DummyHealth := Humanoid.Health. A
--     Humanoid health change (regen, kill regen, respawn) also copies Health into DummyHealth. A killing blow keeps the
--     attackers' own KilledBy / KilledByUserId / KilledWith / KilledAt writes (BiteServer / PounceServer).
--   * Attacker credit: when a player's character BiteHitAt changes and its BiteHitTarget is a bridged character's name,
--     or its PounceBiteAt changes while its PounceLatchPart points into a bridged character, that character gets
--     LastHitBy (attacker name), LastHitAt (server time).
-- Test hook (server only; clients cannot reach it): BindableFunction "ArenaPvPTest" under this script.
--   Invoke("hit", character, dmg) -> lowers a bridged character's DummyHealth by dmg the way a bite does; returns
--     "ok" / "notBridged" / "badArg".
--   Invoke("target", nearCharacter) -> builds a test T-Rex "ArenaPvPTestTarget" (copy of StarterPlayer.StarterCharacter,
--     no scripts, Species "TRex", ArenaPvPTestTarget = true so PlaceGate keeps it, HumanoidRootPart anchored, 200 / 200)
--     25 studs in front of nearCharacter, bridged like a player (Bitable set one frame after it is in Workspace); an older one is
--     removed. Returns the model, or nil when the mode is "sandbox" or the switch is off.
-- v1.1 (pachy headbutt, MDA-120, plan docs/plans/PACHY_PLAYABLE_v1.0.md Task 10): attacker credit also when a player's
--   character HeadbuttHitAt changes (HeadbuttServer 1.0, set last) and its HeadbuttHitTarget is a bridged character's
--   name -> LastHitBy / LastHitAt as for a bite. Switch: script attribute ArenaPvPHeadbuttEnabled (default true, read at
--   start; false = 1.0, no headbutt credit). The headbutt damage itself already goes through DummyHealth (the bridge).
-- v1.2 (Grappling Hook, MDA-122): the same credit on HookHitAt + HookHitTarget (HookServer 1.0), under the same switch.
-- v1.3 (practice match, MDA-405, plan docs/plans/PRACTICE_MATCH_v1.0.md Task 1): the bridge also runs in the Sandbox while the
--   practice match is set up there (ServerScriptService.PracticeServer exists, Enabled, PracticeEnabled not false), so the
--   practice bots' real attacks reach players through DummyHealth exactly as in the Arena. ArenaPvPState "practice". Switch:
--   script attribute ArenaPvPPracticeEnabled (default true; false = 1.2: Sandbox not bridged). Read once at start.
-- v1.4 (island hub, MDA-454, plan docs/plans/ISLAND_HUB_v1.0.md Task 3, ADR-011; Kepu 2026-11-11 "PvP on" off the safe islet):
--   when ModeRules 1.2 serverKind() == "hub" the bridge runs as in the Arena (ArenaPvPState "hub"; the practice flag is off
--   there), and the test target can be built. While a bridged character's attribute HubSafe is true (HubServer 1.0: on the
--   islet or in the 3 s guard) its Bitable is false, like a player in the menu; re-checked when HubSafe changes. Switch:
--   script attribute ArenaPvPHubEnabled (default true; false = 1.3, the hub is not bridged). Read once at start.
-- Switch: script attribute ArenaPvPEnabled (default true), read at start. false -> nothing is bridged (ArenaPvPState "off").
-- Diagnostics: script ArenaPvPVersion, ArenaPvPState ("arena" / "sandbox" / "off"), ArenaPvPHits (damaging drops),
--   ArenaPvPBlocked (drops the shield took); character ArenaPvPLastDelta, ArenaPvPBridged (true while bridged).
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local VERSION = "1.4"
local TEST_DIST = 25

script:SetAttribute("ArenaPvPVersion", VERSION)
if script:GetAttribute("ArenaPvPEnabled") == nil then script:SetAttribute("ArenaPvPEnabled", true) end
if script:GetAttribute("ArenaPvPHeadbuttEnabled") == nil then script:SetAttribute("ArenaPvPHeadbuttEnabled", true) end -- v1.1
script:SetAttribute("ArenaPvPHits", 0)
script:SetAttribute("ArenaPvPBlocked", 0)

local ModeRules = require(ServerStorage:WaitForChild("DinoArcade"):WaitForChild("ModeRules"))
local MODE = ModeRules.currentMode()
if script:GetAttribute("ArenaPvPPracticeEnabled") == nil then script:SetAttribute("ArenaPvPPracticeEnabled", true) end -- v1.3
local PRACTICE = false -- v1.3
do
	local ps = game:GetService("ServerScriptService"):FindFirstChild("PracticeServer")
	PRACTICE = MODE == "sandbox" and script:GetAttribute("ArenaPvPPracticeEnabled") ~= false and ps ~= nil and ps:IsA("BaseScript")
		and ps.Enabled and ps:GetAttribute("PracticeEnabled") ~= false
end
if script:GetAttribute("ArenaPvPHubEnabled") == nil then script:SetAttribute("ArenaPvPHubEnabled", true) end -- v1.4
local HUB = MODE == "sandbox" and script:GetAttribute("ArenaPvPHubEnabled") ~= false and ModeRules.serverKind ~= nil
	and ModeRules.serverKind() == "hub" -- v1.4
if HUB then PRACTICE = false end

local bridged = {} -- [model] = {hum, last, writing}
local testTarget

local function now() return workspace:GetServerTimeNow() end

local function writeHealth(model)
	local b = bridged[model]
	if not b then return end
	b.writing = true
	b.last = b.hum.Health
	model:SetAttribute("DummyMaxHealth", b.hum.MaxHealth)
	model:SetAttribute("DummyHealth", b.last)
	b.writing = false
end

local function setBitable(model, player)
	local inMenu = player ~= nil and player:GetAttribute("InMenu") == true
	if inMenu or (HUB and model:GetAttribute("HubSafe") == true) then -- v1.4: + safe on the hub islet
		model:SetAttribute("Bitable", false)
	else
		model:SetAttribute("Bitable", true)
	end
end

local function bridge(model, player)
	local hum = model:FindFirstChildOfClass("Humanoid")
	if not hum or bridged[model] then return end
	local b = {hum = hum, last = hum.Health, writing = false}
	bridged[model] = b
	model:SetAttribute("ArenaPvPBridged", true)
	writeHealth(model)
	setBitable(model, player)
	if HUB then -- v1.4
		model:GetAttributeChangedSignal("HubSafe"):Connect(function()
			if bridged[model] == b then setBitable(model, player) end
		end)
	end
	model:GetAttributeChangedSignal("DummyHealth"):Connect(function()
		if b.writing or bridged[model] ~= b then return end
		local v = tonumber(model:GetAttribute("DummyHealth")) or b.last
		if v < b.last then
			local d = b.last - v
			local before = hum.Health
			hum:TakeDamage(d)
			model:SetAttribute("ArenaPvPLastDelta", d)
			if hum.Health < before then
				script:SetAttribute("ArenaPvPHits", (script:GetAttribute("ArenaPvPHits") or 0) + 1)
			else
				script:SetAttribute("ArenaPvPBlocked", (script:GetAttribute("ArenaPvPBlocked") or 0) + 1)
			end
		end
		writeHealth(model)
	end)
	hum.HealthChanged:Connect(function()
		if bridged[model] == b then writeHealth(model) end
	end)
	model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(workspace) then bridged[model] = nil end
	end)
end

-- attacker credit (BiteServer / PounceServer write these on the attacker after the damage)
local function credit(victim, attacker)
	if victim and bridged[victim] then
		victim:SetAttribute("LastHitBy", attacker.Name)
		victim:SetAttribute("LastHitAt", now())
	end
end

local function watchAttacker(char)
	char:GetAttributeChangedSignal("BiteHitAt"):Connect(function()
		local name = char:GetAttribute("BiteHitTarget")
		for model in pairs(bridged) do
			if model ~= char and model.Name == name then credit(model, char) end
		end
	end)
	char:GetAttributeChangedSignal("PounceBiteAt"):Connect(function()
		local v = char:FindFirstChild("PounceLatchPart")
		local part = v and v.Value
		for model in pairs(bridged) do
			if model ~= char and part and part:IsDescendantOf(model) then credit(model, char) end
		end
	end)
	if script:GetAttribute("ArenaPvPHeadbuttEnabled") ~= false then -- v1.1
		char:GetAttributeChangedSignal("HeadbuttHitAt"):Connect(function()
			local name = char:GetAttribute("HeadbuttHitTarget")
			for model in pairs(bridged) do
				if model ~= char and model.Name == name then credit(model, char) end
			end
		end)
		char:GetAttributeChangedSignal("HookHitAt"):Connect(function() -- v1.2
			local name = char:GetAttribute("HookHitTarget")
			for model in pairs(bridged) do
				if model ~= char and model.Name == name then credit(model, char) end
			end
		end)
	end
end

local test = Instance.new("BindableFunction")
test.Name = "ArenaPvPTest"
test.Parent = script

local active = script:GetAttribute("ArenaPvPEnabled") ~= false and (MODE == "arena" or PRACTICE or HUB) -- v1.3: + PRACTICE, v1.4: + HUB

test.OnInvoke = function(what, a, b)
	if what == "hit" then
		if typeof(a) ~= "Instance" or type(b) ~= "number" then
			return "badArg"
		elseif not bridged[a] then
			return "notBridged"
		else
			local hp = tonumber(a:GetAttribute("DummyHealth")) or 0
			a:SetAttribute("DummyHealth", math.max(0, hp - b))
			return "ok"
		end
	elseif what == "target" then
		if not active or typeof(a) ~= "Instance" then return nil end
		local root = a:FindFirstChild("HumanoidRootPart")
		local sc = StarterPlayer:FindFirstChild("StarterCharacter")
		if not (root and sc) then return nil end
		if testTarget then testTarget:Destroy() end
		local was = sc.Archivable
		sc.Archivable = true
		local m = sc:Clone()
		sc.Archivable = was
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("BaseScript") then d:Destroy() end
		end
		m.Name = "ArenaPvPTestTarget"
		m:SetAttribute("Species", "TRex")
		m:SetAttribute("ArenaPvPTestTarget", true)
		m:SetAttribute("DisplayName", "PvP test T-Rex")
		local hum = m:FindFirstChildOfClass("Humanoid")
		local hrp = m:FindFirstChild("HumanoidRootPart")
		if not (hum and hrp) then m:Destroy() return nil end
		hum.MaxHealth, hum.Health = 200, 200
		hum.BreakJointsOnDeath = false
		hrp.Anchored = true
		local flat = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
		if flat.Magnitude < 1e-3 then flat = Vector3.new(0, 0, -1) end
		local pos = root.Position + flat.Unit * TEST_DIST
		m:PivotTo(CFrame.lookAt(pos, Vector3.new(root.Position.X, pos.Y, root.Position.Z)))
		m.Parent = workspace
		testTarget = m
		task.wait() -- after Workspace's DescendantAdded handlers (deferred signals) ran: BiteTargetHealth must not adopt it
		if m.Parent then bridge(m, nil) end
		return m
	else
		return "badArg"
	end
end

if script:GetAttribute("ArenaPvPEnabled") == false then
	script:SetAttribute("ArenaPvPState", "off")
	return
elseif MODE ~= "arena" and not PRACTICE and not HUB then -- v1.3: + not PRACTICE, v1.4: + not HUB
	script:SetAttribute("ArenaPvPState", "sandbox")
	return
end
script:SetAttribute("ArenaPvPState", HUB and "hub" or PRACTICE and "practice" or "arena") -- v1.3, v1.4: "hub"

local function onPlayer(player)
	local function onChar(char)
		watchAttacker(char)
		if not char:IsDescendantOf(workspace) then char.AncestryChanged:Wait() end
		task.wait() -- after Workspace's DescendantAdded handlers (deferred signals) ran: BiteTargetHealth must not adopt it
		if player.Character == char and char.Parent then bridge(char, player) end
	end
	player.CharacterAdded:Connect(onChar)
	if player.Character then task.spawn(onChar, player.Character) end
	player:GetAttributeChangedSignal("InMenu"):Connect(function()
		local c = player.Character
		if c and bridged[c] then setBitable(c, player) end
	end)
end

Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do task.spawn(onPlayer, p) end
