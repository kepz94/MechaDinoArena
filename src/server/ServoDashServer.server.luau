-- ServoDashServer v1.0 (Mecha Dino Arena) — the pachy's Overclocked Servo Dash, a Speed slot part (path "servodash").
-- MDA-126, plan docs/plans/PACHY_PARTS_B3_v1.0.md, mockup docs/mockups/pachy_parts_b3_options.html look A "Hip thrusters".
-- Kepu 2026-10-30: "An active thruster burn that gives an instantaneous burst of top-speed forward velocity. It instantly
--   overrides the headbutt empty-charge speed debuff for 1.5 seconds, letting you quickly escape after missing a charge."
--   Answers: "Launch + steerable speed" (an instant shove forward, then 1.6x run speed you can steer); steps as the mockup.
-- Settings come from the character (SkillEffects 1.24): ServoDashEnabled (bought AND slotted on a pachy), ServoDashTime
--   (1.5; 2 from II), ServoDashCooldown (12; 8 from III), ServoDashSpeedMul (1.6), ServoDashRefill (star), ServoDashLook.
-- Client -> server: ReplicatedStorage.DinoServoDashRequest:FireServer(clientServerTime) (MechaButtons 1.19). Checks, first
--   failing wins: "badArg", "dead", "disabled" (ServoDashServerEnabled false or ServoDashEnabled ~= true), "menu",
--   "stunned" (StunnedUntil > now), "pinned" (PinHeld), "active" (ServoDashUntil > now), "cooldown" (now <
--   ServoDashReadyAt), "ok".
--   ok: ServoDashUntil = now + ServoDashTime, ServoDashReadyAt = now + ServoDashCooldown (counted from the press),
--   ServoDashCount + 1, ServoDashStartedAt = now (last: ServoDashLaunch 1.0 shoves the owner forward; SprintTest 1.10 runs
--   the owner at MoveRunSpeed x ServoDashSpeedMul and skips the headbutt self-slow until ServoDashUntil).
-- End: at ServoDashUntil ("time"), owner death ("dead"), ServoDashEnabled false ("disabled") -> ServoDashUntil = now on an
--   early end. Star (ServoDashRefill): at a "time" end the owner gets one headbutt charge back: character attribute
--   HeadbuttGiveChargeAt = now (HeadbuttServer 1.8 adds it, capped at the max). Character ServoDashEndReason,
--   ServoDashRefills.
-- Look: while ServoDashLook is true the pachy carries "Mecha_ServoDash" welded to the Torso segment's Root (its box in
--   Root's own frame): per side ("L" / "R") a dark housing "Housing_<s>" on the rear of the hip pointing backward, a steel
--   bell "Bell_<s>" behind it, and in the bell an Attachment "Exhaust" with a ParticleEmitter "Flame" (orange-yellow fire)
--   and two Attachments for a white Trail "SpeedLine". Flame and SpeedLine are on only while the dash runs. Massless, no
--   collide / query / touch, no shadow. Hd = the dino's height.
-- Lab card (plug and play, LabPreviewServer 1.2): BindableFunction "BuildPreview_servodash".
-- Switch: script attribute ServoDashServerEnabled (default true).
-- Diagnostics: script ServoDashServerVersion, ServoDashRequests; character ServoDashServerResult, ServoDashCount,
--   ServoDashEndReason, ServoDashLookBuilt.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local VERSION = "1.0"
local STEEL, DARK = Color3.fromRGB(154, 166, 184), Color3.fromRGB(58, 64, 76)
script:SetAttribute("ServoDashServerVersion", VERSION)
script:SetAttribute("ServoDashRequests", 0)
if script:GetAttribute("ServoDashServerEnabled") == nil then script:SetAttribute("ServoDashServerEnabled", true) end
local function enabled() return script:GetAttribute("ServoDashServerEnabled") ~= false end

local remote = ReplicatedStorage:FindFirstChild("DinoServoDashRequest")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "DinoServoDashRequest"
	remote.Parent = ReplicatedStorage
end

local function now() return workspace:GetServerTimeNow() end

local function part(name, size, cf, color, parent, mount, mat)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or Enum.Material.Metal
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Anchored, p.Massless = false, true
	p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
	p.CastShadow = false
	p.Parent = parent
	if mount then
		local w = Instance.new("WeldConstraint")
		w.Part0, w.Part1 = mount, p
		w.Parent = p
	end
	return p
end
local function rootBox(seg, root)
	local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, p in ipairs(seg:GetDescendants()) do
		if p:IsA("BasePart") and p ~= root then
			for _, sx in ipairs({-0.5, 0.5}) do for _, sy in ipairs({-0.5, 0.5}) do for _, sz in ipairs({-0.5, 0.5}) do
				local q = root.CFrame:PointToObjectSpace(p.CFrame * Vector3.new(p.Size.X * sx, p.Size.Y * sy, p.Size.Z * sz))
				lo, hi = lo:Min(q), hi:Max(q)
			end end end
		end
	end
	if lo.X == math.huge then return nil end
	return lo, hi
end
local function extent(lo, hi, axis)
	local h = (hi - lo) / 2
	return math.abs(axis.X) * h.X + math.abs(axis.Y) * h.Y + math.abs(axis.Z) * h.Z
end
local function axisOf(root, dir)
	local v = root.CFrame:VectorToObjectSpace(dir)
	local a = Vector3.new(math.abs(v.X), math.abs(v.Y), math.abs(v.Z))
	if a.X >= a.Y and a.X >= a.Z then return Vector3.new(v.X >= 0 and 1 or -1, 0, 0) end
	if a.Y >= a.Z then return Vector3.new(0, v.Y >= 0 and 1 or -1, 0) end
	return Vector3.new(0, 0, v.Z >= 0 and 1 or -1)
end

-- the hip thrusters (returns the model, or nil)
local function build(char)
	local seg = char:FindFirstChild("Torso")
	local root = seg and seg:FindFirstChild("Root")
	if not (root and root:IsA("BasePart")) then return nil end
	local lo, hi = rootBox(seg, root)
	if not lo then return nil end
	local ref = char:FindFirstChild("HumanoidRootPart") or root
	local x = axisOf(root, ref.CFrame.RightVector)
	local y = axisOf(root, ref.CFrame.UpVector)
	if math.abs(x:Dot(y)) > 0.5 then y = axisOf(root, ref.CFrame.LookVector):Cross(x) end
	local back = x:Cross(y) -- Right x Up = Back
	local Hd = char:GetExtentsSize().Y
	local w, len = Hd * 0.07, Hd * 0.1
	local m = Instance.new("Model")
	m.Name = "Mecha_ServoDash"
	for _, side in ipairs({-1, 1}) do
		local s = side < 0 and "L" or "R"
		local c = (lo + hi) / 2 + x * side * (extent(lo, hi, x) + w * 0.35) + back * (extent(lo, hi, back) * 0.45)
			- y * (extent(lo, hi, y) * 0.15)
		-- local -Z (look) points backward
		local cf = root.CFrame * CFrame.fromMatrix(c, x, y, -back)
		local housing = part("Housing_" .. s, Vector3.new(w, w, len), cf, DARK, m, root)
		local bell = part("Bell_" .. s, Vector3.new(w * 0.8, w * 0.8, len * 0.35), cf * CFrame.new(0, 0, -len * 0.62), STEEL, m, housing)
		local ex = Instance.new("Attachment")
		ex.Name = "Exhaust"
		ex.Position = Vector3.new(0, 0, -len * 0.2)
		ex.Parent = bell
		local f = Instance.new("ParticleEmitter")
		f.Name = "Flame"
		f.Enabled = false
		f.EmissionDirection = Enum.NormalId.Front
		f.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 240, 160)),
			ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 154, 46)), ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 60, 20))})
		f.LightEmission = 1
		f.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, w * 0.9), NumberSequenceKeypoint.new(1, w * 0.2)})
		f.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(1, 1)})
		f.Speed = NumberRange.new(Hd * 1.2, Hd * 1.8)
		f.SpreadAngle = Vector2.new(8, 8)
		f.Lifetime = NumberRange.new(0.12, 0.22)
		f.Rate = 160
		f.Parent = ex
		local a0 = Instance.new("Attachment")
		a0.Name = "TrailA"
		a0.Position = Vector3.new(0, w * 0.3, 0)
		a0.Parent = bell
		local a1 = Instance.new("Attachment")
		a1.Name = "TrailB"
		a1.Position = Vector3.new(0, -w * 0.3, 0)
		a1.Parent = bell
		local tr = Instance.new("Trail")
		tr.Name = "SpeedLine"
		tr.Attachment0, tr.Attachment1 = a0, a1
		tr.Color = ColorSequence.new(Color3.new(1, 1, 1))
		tr.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1)})
		tr.Lifetime = 0.35
		tr.LightEmission = 0.6
		tr.Enabled = false
		tr.Parent = bell
	end
	m.Parent = char
	char:SetAttribute("ServoDashLookBuilt", true)
	return m
end

local function setFire(char, on)
	local m = char:FindFirstChild("Mecha_ServoDash")
	if not m then return end
	for _, d in ipairs(m:GetDescendants()) do
		if d.Name == "Flame" or d.Name == "SpeedLine" then d.Enabled = on end
	end
end

local function setLook(char)
	local want = enabled() and char:GetAttribute("Species") == "Pachy" and char:GetAttribute("ServoDashLook") == true
	local old = char:FindFirstChild("Mecha_ServoDash")
	if not want then
		if old then old:Destroy() end
		char:SetAttribute("ServoDashLookBuilt", false)
		return
	end
	if old then return end
	build(char)
end

local running = {} -- [char] = untilT

local function finish(char, reason)
	if not running[char] then return end
	running[char] = nil
	setFire(char, false)
	if char.Parent then
		if reason ~= "time" then char:SetAttribute("ServoDashUntil", now()) end
		char:SetAttribute("ServoDashEndReason", reason)
		if reason == "time" and char:GetAttribute("ServoDashRefill") == true then -- star
			char:SetAttribute("ServoDashRefills", (char:GetAttribute("ServoDashRefills") or 0) + 1)
			char:SetAttribute("HeadbuttGiveChargeAt", now())
		end
	end
end

local function setResult(char, r)
	char:SetAttribute("ServoDashServerResult", r)
	char:SetAttribute("ServoDashServerResultAt", now())
end

remote.OnServerEvent:Connect(function(player, stamp)
	script:SetAttribute("ServoDashRequests", (script:GetAttribute("ServoDashRequests") or 0) + 1)
	local char = player.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local t = now()
	local r
	if typeof(stamp) ~= "number" or stamp ~= stamp then
		r = "badArg"
	elseif not hum or hum.Health <= 0 then
		r = "dead"
	elseif not enabled() or char:GetAttribute("ServoDashEnabled") ~= true then
		r = "disabled"
	elseif player:GetAttribute("InMenu") == true then
		r = "menu"
	elseif (tonumber(char:GetAttribute("StunnedUntil")) or 0) > t then
		r = "stunned"
	elseif char:GetAttribute("PinHeld") == true then
		r = "pinned"
	elseif (tonumber(char:GetAttribute("ServoDashUntil")) or 0) > t then
		r = "active"
	elseif t < (tonumber(char:GetAttribute("ServoDashReadyAt")) or 0) then
		r = "cooldown"
	end
	if r then setResult(char, r) return end
	local dur = math.max(0.2, tonumber(char:GetAttribute("ServoDashTime")) or 1.5)
	running[char] = t + dur
	char:SetAttribute("ServoDashUntil", t + dur)
	char:SetAttribute("ServoDashReadyAt", t + (tonumber(char:GetAttribute("ServoDashCooldown")) or 12))
	char:SetAttribute("ServoDashCount", (char:GetAttribute("ServoDashCount") or 0) + 1)
	setLook(char)
	setFire(char, true)
	setResult(char, "ok")
	char:SetAttribute("ServoDashStartedAt", t) -- last
end)

RunService.Heartbeat:Connect(function()
	local t = now()
	for char, untilT in pairs(running) do
		local hum = char.Parent and char:FindFirstChildOfClass("Humanoid")
		if not char.Parent or not hum then
			running[char] = nil
		elseif hum.Health <= 0 then
			finish(char, "dead")
		elseif char:GetAttribute("ServoDashEnabled") ~= true then
			finish(char, "disabled")
		elseif t >= untilT then
			finish(char, "time")
		end
	end
end)

local function onCharacter(char)
	char:GetAttributeChangedSignal("ServoDashLook"):Connect(function() setLook(char) end)
	char:GetAttributeChangedSignal("Species"):Connect(function() setLook(char) end)
	task.defer(setLook, char)
end
local function onPlayer(p)
	p.CharacterAdded:Connect(onCharacter)
	if p.Character then onCharacter(p.Character) end
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do onPlayer(p) end

-- the Lab card model (plug and play: LabPreviewServer 1.2 finds BuildPreview_<pathId>)
do
	local fn = Instance.new("BindableFunction")
	fn.Name = "BuildPreview_servodash"
	fn.OnInvoke = function(model)
		if not enabled() or typeof(model) ~= "Instance" then return nil end
		return build(model)
	end
	fn.Parent = script
end
