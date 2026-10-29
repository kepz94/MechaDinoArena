-- ScentServer v1.0 (Mecha Dino Arena) — Scent Sense, a raptor button part (raptor parts batch 2): the server gate and
-- cooldown for the sniff; the trails themselves are drawn by the owner's client (ScentFX 1.0, visible to you only).
-- MDA-72, plan docs/plans/RAPTOR_PARTS_B2_v1.0.md Task 3, mockup docs/mockups/raptor_parts_b2_scent_screech.html
-- (Kepu 2026-10-29: "I like scent sense. Let's add that" -> A "Glowing paw prints", cloaked raptors leave faint prints).
-- Settings come from the character (SkillEffects 1.8): ScentEnabled (bought AND slotted), ScentRadius (60; 81 from II),
--   ScentMemory (8; 10.8 from III), ScentTime (6), ScentCooldown (16), ScentFresh (III), ScentBlood (star).
-- Client -> server: ReplicatedStorage.DinoScentRequest:FireServer(clientServerTime). Checks, first failing wins:
--   "badArg", "dead", "disabled" (ScentServerEnabled false or ScentEnabled ~= true), "stunned" (StunnedUntil > now),
--   "active" (ScentUntil > now), "cooldown" (now < ScentReadyAt), "ok". ok: ScentUntil = now + ScentTime, ScentReadyAt
--   = ScentUntil + ScentCooldown (counted from the end, like the other timed parts), ScentCount + 1, ScentStartedAt =
--   now (last; ScentFX and CloakServer react to it). ScentEnabled turning false ends a running sniff early
--   (ScentUntil = now, ScentReadyAt = now + cooldown, ScentEndReason "disabled"); the end by time sets ScentEndReason
--   "time".
-- Settings: script attribute ScentServerEnabled (default true).
-- Diagnostics: script ScentServerVersion, ScentRequests; character ScentServerResult, ScentCount, ScentEndReason,
--   ScentState ("off" / "on").
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local VERSION = "1.0"

script:SetAttribute("ScentServerVersion", VERSION)
if script:GetAttribute("ScentServerEnabled") == nil then script:SetAttribute("ScentServerEnabled", true) end
script:SetAttribute("ScentRequests", 0)
local function on() return script:GetAttribute("ScentServerEnabled") ~= false end
local function now() return workspace:GetServerTimeNow() end

local remote = ReplicatedStorage:FindFirstChild("DinoScentRequest")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "DinoScentRequest"
	remote.Parent = ReplicatedStorage
end

local chars = {} -- [char] = {hum, active}

local function finish(char, reason)
	local st = chars[char]
	if not st or not st.active then return end
	st.active = false
	local t = now()
	if reason ~= "time" then
		char:SetAttribute("ScentUntil", t)
		char:SetAttribute("ScentReadyAt", t + (tonumber(char:GetAttribute("ScentCooldown")) or 0))
	end
	char:SetAttribute("ScentEndReason", reason)
	char:SetAttribute("ScentState", "off")
end

remote.OnServerEvent:Connect(function(player, stamp)
	local char = player.Character
	local st = char and chars[char]
	if not st then return end
	script:SetAttribute("ScentRequests", (script:GetAttribute("ScentRequests") or 0) + 1)
	local t = now()
	local hum = st.hum
	local result
	if typeof(stamp) ~= "number" or stamp ~= stamp then
		result = "badArg"
	elseif not hum or hum.Health <= 0 then
		result = "dead"
	elseif not on() or char:GetAttribute("ScentEnabled") ~= true then
		result = "disabled"
	elseif (tonumber(char:GetAttribute("StunnedUntil")) or 0) > t then
		result = "stunned"
	elseif (tonumber(char:GetAttribute("ScentUntil")) or 0) > t then
		result = "active"
	elseif t < (tonumber(char:GetAttribute("ScentReadyAt")) or 0) then
		result = "cooldown"
	else
		result = "ok"
	end
	char:SetAttribute("ScentServerResult", result)
	if result ~= "ok" then return end
	local dur = math.max(0.1, tonumber(char:GetAttribute("ScentTime")) or 6)
	st.active = true
	char:SetAttribute("ScentEndReason", "")
	char:SetAttribute("ScentUntil", t + dur)
	char:SetAttribute("ScentReadyAt", t + dur + (tonumber(char:GetAttribute("ScentCooldown")) or 0))
	char:SetAttribute("ScentCount", (char:GetAttribute("ScentCount") or 0) + 1)
	char:SetAttribute("ScentState", "on")
	char:SetAttribute("ScentStartedAt", t) -- last: readers react to this one
end)

RunService.Heartbeat:Connect(function()
	local t = now()
	for char, st in pairs(chars) do
		if st.active then
			if not char.Parent or st.hum.Health <= 0 then
				finish(char, "dead")
			elseif t >= (tonumber(char:GetAttribute("ScentUntil")) or 0) then
				finish(char, "time")
			end
		end
	end
end)

local function onCharacter(char)
	if chars[char] then return end
	local hum = char:WaitForChild("Humanoid", 10)
	if not hum then return end
	chars[char] = {hum = hum, active = false}
	char:SetAttribute("ScentUntil", 0)
	char:SetAttribute("ScentReadyAt", 0)
	char:SetAttribute("ScentState", "off")
	char:GetAttributeChangedSignal("ScentEnabled"):Connect(function()
		if char:GetAttribute("ScentEnabled") ~= true then finish(char, "disabled") end
	end)
	char.AncestryChanged:Connect(function(_, parent)
		if not parent then chars[char] = nil end
	end)
end

script:GetAttributeChangedSignal("ScentServerEnabled"):Connect(function()
	if on() then return end
	for char in pairs(chars) do finish(char, "disabled") end
end)

local function onPlayer(player)
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then task.spawn(onCharacter, player.Character) end
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do onPlayer(p) end
