-- TrailFX v1.0 (Mecha Dino Arena) — draws every nearby dino's trail, local to this client (plan docs/plans/TRAILS_v1.0.md; Kepu
-- 2026-11-25 11:00 "Build"). Looks: TrailLook 1.0 (same folder). Which trail: the character attribute TrailId (TrailServer 1.0;
-- "" = no trail).
-- A character is drawn while: TrailFXEnabled, its TrailId is a known trail, alive, its player is not InMenu and not PrParked, and its
-- HumanoidRootPart is within TrailFXRange (150) studs of the camera. TrailLook shows the trail only while the dino moves (flat speed
-- over TrailMoveSpeed 2 studs/s): frozen dinos at the results (PracticeServer 1.15) leave no trail.
-- Soft look on every server that is not the island (ReplicatedStorage ServerKind ~= "hub"): matches. TrailFXSoft = "auto" (that rule) /
-- "on" / "off".
-- Caps: TrailFXMaxBits (24) a dino, TrailFXMaxTotal (120) prints + bits for everyone (a dino over the total spawns no new bits).
-- Local parts live in workspace.TrailFXLocal (not replicated; CanCollide / CanQuery / CanTouch false).
-- Diagnostics: TrailFXVersion, TrailFXActive (dinos drawn), TrailFXParts (prints + bits alive).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local VERSION = "1.0"
script:SetAttribute("TrailFXVersion", VERSION)
for k, v in pairs({TrailFXEnabled = true, TrailFXRange = 150, TrailMoveSpeed = 2, TrailFXMaxBits = 24, TrailFXMaxTotal = 120, TrailFXSoft = "auto"}) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, v) end
end
script:SetAttribute("TrailFXActive", 0)
script:SetAttribute("TrailFXParts", 0)

local TL = require(script.Parent:WaitForChild("TrailLook"))

local folder = workspace:FindFirstChild("TrailFXLocal")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "TrailFXLocal"
	folder.Parent = workspace
end

local handles = {} -- [character] = {h, id}

local function softNow()
	local m = script:GetAttribute("TrailFXSoft")
	if m == "on" then return true end
	if m == "off" then return false end
	return ReplicatedStorage:GetAttribute("ServerKind") ~= "hub"
end

local function drop(char)
	local e = handles[char]
	if e then
		pcall(function() e.h:destroy() end)
		handles[char] = nil
	end
end

RunService.RenderStepped:Connect(function(dt)
	local on = script:GetAttribute("TrailFXEnabled") ~= false
	local cam = workspace.CurrentCamera
	local camPos = cam and cam.CFrame.Position or Vector3.zero
	local range = tonumber(script:GetAttribute("TrailFXRange")) or 150
	local maxBits = tonumber(script:GetAttribute("TrailFXMaxBits")) or 24
	local maxTotal = tonumber(script:GetAttribute("TrailFXMaxTotal")) or 120
	local moveSpeed = tonumber(script:GetAttribute("TrailMoveSpeed")) or 2
	local soft = softNow()
	local seen, active, total = {}, 0, 0
	for _, e in pairs(handles) do total += e.h:bits() end
	for _, pl in ipairs(Players:GetPlayers()) do
		local char = pl.Character
		if char then
			seen[char] = true
			local id = char:GetAttribute("TrailId")
			local hrp = char:FindFirstChild("HumanoidRootPart")
			local hum = char:FindFirstChildOfClass("Humanoid")
			local want = on and type(id) == "string" and TL.LOOKS[id] ~= nil and hrp ~= nil and hum ~= nil and hum.Health > 0
				and pl:GetAttribute("InMenu") ~= true and pl:GetAttribute("PrParked") ~= true
				and (hrp.Position - camPos).Magnitude <= range
			local e = handles[char]
			if e and (not want or e.id ~= id) then drop(char) e = nil end
			if want and not e then
				local h = TL.world(char, id, {parent = folder, maxBits = maxBits, moveSpeed = moveSpeed})
				if h then e = {h = h, id = id} handles[char] = e end
			end
			if e then
				e.h.core.maxBits = total >= maxTotal and 0 or maxBits
				local ok = pcall(e.h.step, e.h, dt, soft)
				if not ok then drop(char) else active += 1 end
			end
		end
	end
	for char in pairs(handles) do
		if not seen[char] or not char.Parent then drop(char) end
	end
	if script:GetAttribute("TrailFXActive") ~= active then script:SetAttribute("TrailFXActive", active) end
	local n = #folder:GetChildren()
	if script:GetAttribute("TrailFXParts") ~= n then script:SetAttribute("TrailFXParts", n) end
end)
