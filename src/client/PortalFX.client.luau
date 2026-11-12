-- PortalFX v1.0 (Mecha Dino Arena) — the Rift Gate portals come alive (LocalScript, StarterPlayerScripts). MDA-475 / MDA-476,
-- plan docs/plans/RIFT_GATES_v1.0.md T2 + T3; Kepu 2026-11-12 16:20 pick A · Rift Gate (mockup docs/mockups/portal_look_v0.1.html).
-- Works on the islet HubServer puts in Workspace (Workspace.PortalIslet with PortalRiftVersion; tools/build/PortalRift.build
--   1.0 made the Rift folder in each portal and hid the 1.1 parts, tagged Legacy). Nothing happens on servers without it.
-- Each frame, while the camera is within PortalFXFar (400) studs of the islet centre:
--   * VortexHub (with its 6 Beams) turns PortalFXSpin (70) degrees a second round its facing axis, from its BaseCFrame;
--   * Conduit1..8 light in turn, PortalFXChase (6) steps a second, two lit at once (Transparency 0 lit / 0.6 off);
--   * RuneRing / RuneInner breathe: Transparency 0.15 + 0.35 x (0.5 + 0.5 sin 3t), the inner one half a beat later.
--   Further away: nothing is moved (diagnostic "far").
-- Phone budget: on a touch-only device or graphics quality 4 or lower, Sparks.Rate = BaseRate x PortalFXPhoneMul (0.5).
-- Walk-in flare (T3): when a portal model's attribute PortalFlareAt (HubServer 1.3, server time) changes and is under 2 s old:
--   for 0.6 s the VortexDisc goes from Transparency 0 back to its own, the Light's Brightness 6 back to 2; a local Neon ring
--   (PortalShock) grows on the plaza from 10 to 90 across over 0.5 s while fading; Sparks:Emit(40) (phone 18).
--   The local player, when its HubTripState turns "saving" or "teleporting", also gets a 0.25 s white flash (ScreenGui
--   PortalFlash, DisplayOrder 99, under the loader's 100).
-- Switch: script attribute PortalFXEnabled (default true, read per frame). false: the Rift parts are hidden on this client
--   (Transparency 1, beams / sparks / light off) and the 1.1 parts come back (LegacyTransparency, LegacyLight, the signs at
--   LegacyCFrame), i.e. the 1.1 look.
-- Streaming: the islet streams in after the player arrives, so the portals are looked up again every 2 s until every portal
--   model (HubPortal) has its VortexHub (and when one streams out).
-- Diagnostics: player PortalFXVersion, PortalFXState ("rift" / "legacy" / "far" / "none"), PortalFXFlares (count).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local VERSION = "1.0"
local player = Players.LocalPlayer
player:SetAttribute("PortalFXVersion", VERSION)
for k, v in pairs({PortalFXEnabled = true, PortalFXSpin = 70, PortalFXChase = 6, PortalFXFar = 400, PortalFXPhoneMul = 0.5}) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, v) end
end

local function now() return workspace:GetServerTimeNow() end
local function isPhone()
	local q = 10
	pcall(function() q = UserSettings().GameSettings.SavedQualityLevel.Value end)
	return (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled) or (q > 0 and q <= 4)
end

local portals = {} -- {model, hub, base, conduits, rune, runeInner, disc, discT, light, sparks, rift = {part -> saved}, legacy = {...}}
local islet, centre = nil, nil
local shown = nil -- true rift / false legacy / nil unknown

local function scan()
	portals = {}
	islet = workspace:FindFirstChild("PortalIslet")
	if not (islet and islet:GetAttribute("PortalRiftVersion")) then islet = nil return end
	centre = islet:GetAttribute("IsletCentre") or (islet.PrimaryPart and islet.PrimaryPart.Position)
	for _, m in ipairs(islet:GetChildren()) do
		local rift = m:IsA("Model") and m:FindFirstChild("Rift")
		local hub = rift and rift:FindFirstChild("VortexHub")
		if hub then
			local p = {model = m, hub = hub, base = hub:GetAttribute("BaseCFrame") or hub.CFrame, conduits = {}, riftParts = {},
				legacy = {}, signs = {}}
			for i = 1, 8 do p.conduits[i] = rift:FindFirstChild("Conduit" .. i) end
			p.rune, p.runeInner = rift:FindFirstChild("RuneRing"), rift:FindFirstChild("RuneInner")
			p.disc = rift:FindFirstChild("VortexDisc")
			p.discT = p.disc and p.disc.Transparency or 0.35
			p.light = hub:FindFirstChild("Light")
			p.sparks = hub:FindFirstChild("Sparks")
			if p.sparks then
				p.sparks.Rate = (p.sparks:GetAttribute("BaseRate") or p.sparks.Rate)
					* (isPhone() and (tonumber(script:GetAttribute("PortalFXPhoneMul")) or 0.5) or 1)
			end
			for _, x in ipairs(rift:GetDescendants()) do
				if x:IsA("BasePart") then p.riftParts[x] = x.Transparency end
			end
			for _, x in ipairs(m:GetChildren()) do
				if x:IsA("BasePart") and x:GetAttribute("Legacy") then table.insert(p.legacy, x) end
				if x:IsA("BasePart") and x:GetAttribute("LegacyCFrame") then p.signs[x] = x.CFrame end
			end
			local at = m:GetAttribute("PortalFlareAt") -- a flare under 2 s old still plays after a (re)scan
			p.flareSeen = (type(at) == "number" and now() - at < 2) and -1 or at
			table.insert(portals, p)
		end
	end
	shown = nil
end

local function show(rift)
	if shown == rift then return end
	shown = rift
	for _, p in ipairs(portals) do
		for part, t in pairs(p.riftParts) do part.Transparency = rift and t or 1 end
		for _, x in ipairs(p.hub:GetDescendants()) do
			if x:IsA("Beam") or x:IsA("ParticleEmitter") or x:IsA("Light") then x.Enabled = rift end
		end
		for _, part in ipairs(p.legacy) do
			part.Transparency = rift and 1 or (part:GetAttribute("LegacyTransparency") or 0)
			for _, l in ipairs(part:GetChildren()) do
				if l:IsA("Light") then l.Enabled = (not rift) and (l:GetAttribute("LegacyLight") ~= false) end
			end
		end
		for part, cf in pairs(p.signs) do part.CFrame = rift and cf or part:GetAttribute("LegacyCFrame") end
	end
end

-- flare
local shockFolder = nil
local function flare(p)
	player:SetAttribute("PortalFXFlares", (player:GetAttribute("PortalFXFlares") or 0) + 1)
	local start = os.clock()
	if p.sparks then pcall(function() p.sparks:Emit(isPhone() and 18 or 40) end) end
	local rune = p.rune
	local shock
	if rune then
		shockFolder = shockFolder or Instance.new("Folder")
		shockFolder.Name = "PortalFXLocal"
		shockFolder.Parent = workspace
		shock = Instance.new("Part")
		shock.Name = "PortalShock"
		shock.Anchored, shock.CanCollide, shock.CanQuery, shock.CanTouch, shock.CastShadow = true, false, false, false, false
		shock.Shape = Enum.PartType.Cylinder
		shock.Material = Enum.Material.Neon
		shock.Color = rune.Color
		shock.CFrame = rune.CFrame * CFrame.new(0.05, 0, 0)
		shock.Size = Vector3.new(0.12, 10, 10)
		shock.Parent = shockFolder
	end
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local k = math.clamp((os.clock() - start) / 0.6, 0, 1)
		if p.disc then p.disc.Transparency = p.discT * k end
		if p.light then p.light.Brightness = 6 - 4 * k end
		if shock then
			local s = math.clamp((os.clock() - start) / 0.5, 0, 1)
			local d = 10 + 80 * s
			shock.Size = Vector3.new(0.12, d, d)
			shock.Transparency = s
		end
		if k >= 1 then
			conn:Disconnect()
			if shock then shock:Destroy() end
		end
	end)
end

-- the traveller's flash
local flashGui
local function flash()
	if script:GetAttribute("PortalFXEnabled") == false then return end
	if not flashGui then
		flashGui = Instance.new("ScreenGui")
		flashGui.Name = "PortalFlash"
		flashGui.IgnoreGuiInset = true
		flashGui.DisplayOrder = 99
		flashGui.ResetOnSpawn = false
		local f = Instance.new("Frame")
		f.Name = "White"
		f.Size = UDim2.fromScale(1, 1)
		f.BackgroundColor3 = Color3.new(1, 1, 1)
		f.BorderSizePixel = 0
		f.BackgroundTransparency = 1
		f.Parent = flashGui
		flashGui.Parent = player:WaitForChild("PlayerGui")
	end
	local f = flashGui.White
	local start = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local k = (os.clock() - start) / 0.25
		f.BackgroundTransparency = math.clamp(k, 0, 1)
		if k >= 1 then conn:Disconnect() end
	end)
end
local lastTrip = nil
player:GetAttributeChangedSignal("HubTripState"):Connect(function()
	local st = player:GetAttribute("HubTripState")
	if (st == "saving" or st == "teleporting") and lastTrip ~= "saving" and lastTrip ~= "teleporting" then flash() end
	lastTrip = st
end)

workspace.ChildAdded:Connect(function(c) if c.Name == "PortalIslet" then task.wait(1) scan() end end)
workspace.ChildRemoved:Connect(function(c) if c == islet then scan() end end)
scan()

local state = nil
local function setState(s)
	if s ~= state then state = s player:SetAttribute("PortalFXState", s) end
end
local lastScan = os.clock()
local function wanted() -- portal models on the islet (each should have a Rift with a VortexHub)
	local n = 0
	if islet then for _, m in ipairs(islet:GetChildren()) do if m:IsA("Model") and m:GetAttribute("HubPortal") then n += 1 end end end
	return math.max(n, 1)
end
local function allHere()
	for _, p in ipairs(portals) do if not p.hub.Parent then return false end end
	return true
end
RunService.RenderStepped:Connect(function()
	-- streaming: the islet's parts arrive after this script starts (and can stream out) -> look again every 2 s until found
	if os.clock() - lastScan > 2 and (not islet or #portals < wanted() or not allHere()) then
		lastScan = os.clock()
		scan()
	end
	if not islet or #portals == 0 then setState("none") return end
	local on = script:GetAttribute("PortalFXEnabled") ~= false
	show(on)
	if not on then setState("legacy") return end
	-- flares (any portal, even far away: a squadmate's trip still flashes if you look)
	for _, p in ipairs(portals) do
		local at = p.model:GetAttribute("PortalFlareAt")
		if at ~= p.flareSeen then
			p.flareSeen = at
			if type(at) == "number" and now() - at < 2 then flare(p) end
		end
	end
	local cam = workspace.CurrentCamera
	if centre and cam and (cam.CFrame.Position - centre).Magnitude > (tonumber(script:GetAttribute("PortalFXFar")) or 400) then
		setState("far")
		return
	end
	setState("rift")
	local t = os.clock()
	local spin = math.rad(tonumber(script:GetAttribute("PortalFXSpin")) or 70)
	local lit = math.floor(t * (tonumber(script:GetAttribute("PortalFXChase")) or 6)) % 8 + 1
	local lit2 = (lit + 6) % 8 + 1
	local pulse = 0.5 + 0.5 * math.sin(t * 3)
	local pulse2 = 0.5 + 0.5 * math.sin(t * 3 - 1.5)
	for _, p in ipairs(portals) do
		p.hub.CFrame = p.base * CFrame.Angles(0, 0, -t * spin)
		for i, c in ipairs(p.conduits) do
			if c then c.Transparency = (i == lit or i == lit2) and 0 or 0.6 end
		end
		if p.rune then p.rune.Transparency = 0.15 + 0.35 * pulse end
		if p.runeInner then p.runeInner.Transparency = 0.15 + 0.35 * pulse2 end
	end
end)
