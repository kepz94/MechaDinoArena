-- ArenaPvP v1.0 (Mecha Dino Arena) — in the Arena, bites, pounces and Blade Claws hurt other players. MDA-89, plan
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
-- Switch: script attribute ArenaPvPEnabled (default true), read at start. false -> nothing is bridged (ArenaPvPState "off").
-- Diagnostics: script ArenaPvPVersion, ArenaPvPState ("arena" / "sandbox" / "off"), ArenaPvPHits (damaging drops),
--   ArenaPvPBlocked (drops the shield took); character ArenaPvPLastDelta, ArenaPvPBridged (true while bridged).
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local VERSION = "1.0"
local TEST_DIST = 25

script:SetAttribute("ArenaPvPVersion", VERSION)
if script:GetAttribute("ArenaPvPEnabled") == nil then script:SetAttribute("ArenaPvPEnabled", true) end
script:SetAttribute("ArenaPvPHits", 0)
script:SetAttribute("ArenaPvPBlocked", 0)

local ModeRules = require(ServerStorage:WaitForChild("DinoArcade"):WaitForChild("ModeRules"))
local MODE = ModeRules.currentMode()

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
	if inMenu then
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
end

local test = Instance.new("BindableFunction")
test.Name = "ArenaPvPTest"
test.Parent = script

local active = script:GetAttribute("ArenaPvPEnabled") ~= false and MODE == "arena"

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
elseif MODE ~= "arena" then
	script:SetAttribute("ArenaPvPState", "sandbox")
	return
end
script:SetAttribute("ArenaPvPState", "arena")

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
