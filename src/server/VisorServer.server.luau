-- VisorServer v1.0 (Mecha Dino Arena) — the pachy's Dome Visor, a Defense slot part (path "visor").
-- MDA-127, plan docs/plans/PACHY_PARTS_B3_v1.0.md, mockup docs/mockups/pachy_parts_b3_options.html look A "Armored
--   faceplate". Kepu 2026-10-30: "Okay let's do the dome visor for sure"; "All the recommended ones"; it blocks
--   "Melee + Shock Cannon" from the front.
-- Settings come from the character (SkillEffects 1.24): VisorEnabled (bought AND slotted on a pachy), VisorTime (1.5; 2
--   from II), VisorCooldown (14; 10 from III), VisorKnock (star), VisorLook.
-- Client -> server: ReplicatedStorage.DinoVisorRequest:FireServer(clientServerTime) (MechaButtons 1.19). Checks, first
--   failing wins: "badArg", "dead", "disabled" (VisorServerEnabled false or VisorEnabled ~= true), "menu", "stunned"
--   (StunnedUntil > now), "pinned" (PinHeld), "active" (VisorUntil > now), "cooldown" (now < VisorReadyAt), "ok".
--   ok: VisorUntil = now + VisorTime, VisorReadyAt = now + VisorCooldown (counted from the press), VisorCount + 1,
--   VisorStartedAt = now (last). The pachy can still headbutt, bite and use parts while the visor is down.
-- What it blocks (BoneCrest 1.2, front = the Bone Crest cone, 60 degrees): bites (BiteServer), raptor pounce ticks
--   (PounceServer) and bot bites / pounces (BotServer) through BoneCrest.factor; a raptor's pounce claim (PounceServer
--   1.10: "visor"), a pachy headbutt (HeadbuttServer 1.9: "visor"), the Grappling Hook smash (HookServer 1.6: "visor")
--   and the Shock Cannon ball (ScreechServer 1.9) through BoneCrest.visorFront / visorBlock. Star: the attacker is
--   knocked back (BoneCrest 1.2).
-- End: at VisorUntil ("time"), owner death ("dead"), VisorEnabled false ("disabled") -> VisorUntil = now on an early
--   end. Character VisorEndReason.
-- Look: while VisorLook is true the pachy carries "Mecha_DomeVisor" on the Head segment's Root (its box in Root's own
--   frame): "Plate" (dark steel, a little wider than the head) on a Weld "VisorHinge" to Root, with "Slit" (neon cyan eye
--   slit) and "Rim" (steel top edge) welded to the plate. Stowed: the plate lies flat on top of the dome. While the visor
--   is up it slams down in front of the face (hinge tween DROP_TIME 0.1 s) and goes back up at the end (0.2 s). Massless,
--   no collide / query / touch, no shadow. The hinge's two positions are stored on the weld as CFrame attributes UpC0 /
--   DownC0.
-- Lab card (plug and play, LabPreviewServer 1.2): BindableFunction "BuildPreview_visor" (the plate down).
-- Switch: script attribute VisorServerEnabled (default true).
-- Diagnostics: script VisorServerVersion, VisorRequests; character VisorServerResult, VisorCount, VisorEndReason,
--   VisorLookBuilt, VisorDown (plate in front of the face).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local VERSION = "1.0"
local DROP_TIME, RAISE_TIME = 0.1, 0.2
local STEEL, DARK, CYAN = Color3.fromRGB(154, 166, 184), Color3.fromRGB(58, 64, 76), Color3.fromRGB(95, 227, 255)
script:SetAttribute("VisorServerVersion", VERSION)
script:SetAttribute("VisorRequests", 0)
if script:GetAttribute("VisorServerEnabled") == nil then script:SetAttribute("VisorServerEnabled", true) end
local function enabled() return script:GetAttribute("VisorServerEnabled") ~= false end

local remote = ReplicatedStorage:FindFirstChild("DinoVisorRequest")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "DinoVisorRequest"
	remote.Parent = ReplicatedStorage
end

local function now() return workspace:GetServerTimeNow() end

local function part(name, size, cf, color, parent, mat)
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
	return p
end
local function weld(name, p0, p1, c0)
	local w = Instance.new("Weld")
	w.Name = name
	w.Part0, w.Part1 = p0, p1
	w.C0 = c0
	w.C1 = CFrame.new()
	w.Parent = p1
	return w
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

-- the faceplate (returns the model, or nil); down = start in front of the face
local function build(char, down)
	local seg = char:FindFirstChild("Head")
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
	local c = (lo + hi) / 2
	local wid, hgt, th = extent(lo, hi, x) * 2.1, extent(lo, hi, y) * 1.9, math.max(0.1, Hd * 0.03)
	-- down: in front of the face, facing forward; up: flat on top of the dome, its face pointing up
	local downC0 = CFrame.fromMatrix(c - back * (extent(lo, hi, back) + th * 0.6), x, y, back)
	local upC0 = CFrame.fromMatrix(c + y * (extent(lo, hi, y) + th * 0.6) - back * (extent(lo, hi, back) * 0.25), x, back, -y)
	local m = Instance.new("Model")
	m.Name = "Mecha_DomeVisor"
	local start = down and downC0 or upC0
	local plate = part("Plate", Vector3.new(wid, hgt, th), root.CFrame * start, DARK, m)
	local hinge = weld("VisorHinge", root, plate, start)
	local slit = part("Slit", Vector3.new(wid * 0.7, hgt * 0.1, th * 0.4), plate.CFrame * CFrame.new(0, hgt * 0.12, -th * 0.4), CYAN, m, Enum.Material.Neon)
	weld("SlitWeld", plate, slit, CFrame.new(0, hgt * 0.12, -th * 0.4))
	local rim = part("Rim", Vector3.new(wid * 1.04, hgt * 0.1, th * 1.4), plate.CFrame * CFrame.new(0, hgt * 0.47, 0), STEEL, m)
	weld("RimWeld", plate, rim, CFrame.new(0, hgt * 0.47, 0))
	m.Parent = char
	hinge:SetAttribute("UpC0", upC0) -- the two hinge positions live on the weld (no Lua table keyed by Instances)
	hinge:SetAttribute("DownC0", downC0)
	char:SetAttribute("VisorLookBuilt", true)
	char:SetAttribute("VisorDown", down == true)
	return m
end

local function setDown(char, down)
	local m = char:FindFirstChild("Mecha_DomeVisor")
	local plate = m and m:FindFirstChild("Plate")
	local w = plate and plate:FindFirstChild("VisorHinge")
	local goal = w and w:GetAttribute(down and "DownC0" or "UpC0")
	if typeof(goal) ~= "CFrame" then return end
	TweenService:Create(w, TweenInfo.new(down and DROP_TIME or RAISE_TIME, Enum.EasingStyle.Quad,
		down and Enum.EasingDirection.In or Enum.EasingDirection.Out), {C0 = goal}):Play()
	char:SetAttribute("VisorDown", down)
end

local function setLook(char)
	local want = enabled() and char:GetAttribute("Species") == "Pachy" and char:GetAttribute("VisorLook") == true
	local old = char:FindFirstChild("Mecha_DomeVisor")
	if not want then
		if old then old:Destroy() end
		char:SetAttribute("VisorLookBuilt", false)
		char:SetAttribute("VisorDown", false)
		return
	end
	if old then return end
	build(char, (tonumber(char:GetAttribute("VisorUntil")) or 0) > now())
end

local running = {} -- [char] = untilT

local function finish(char, reason)
	if not running[char] then return end
	running[char] = nil
	setDown(char, false)
	if char.Parent then
		if reason ~= "time" then char:SetAttribute("VisorUntil", now()) end
		char:SetAttribute("VisorEndReason", reason)
	end
end

local function setResult(char, r)
	char:SetAttribute("VisorServerResult", r)
	char:SetAttribute("VisorServerResultAt", now())
end

remote.OnServerEvent:Connect(function(player, stamp)
	script:SetAttribute("VisorRequests", (script:GetAttribute("VisorRequests") or 0) + 1)
	local char = player.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local t = now()
	local r
	if typeof(stamp) ~= "number" or stamp ~= stamp then
		r = "badArg"
	elseif not hum or hum.Health <= 0 then
		r = "dead"
	elseif not enabled() or char:GetAttribute("VisorEnabled") ~= true then
		r = "disabled"
	elseif player:GetAttribute("InMenu") == true then
		r = "menu"
	elseif (tonumber(char:GetAttribute("StunnedUntil")) or 0) > t then
		r = "stunned"
	elseif char:GetAttribute("PinHeld") == true then
		r = "pinned"
	elseif (tonumber(char:GetAttribute("VisorUntil")) or 0) > t then
		r = "active"
	elseif t < (tonumber(char:GetAttribute("VisorReadyAt")) or 0) then
		r = "cooldown"
	end
	if r then setResult(char, r) return end
	local dur = math.max(0.2, tonumber(char:GetAttribute("VisorTime")) or 1.5)
	running[char] = t + dur
	char:SetAttribute("VisorUntil", t + dur)
	char:SetAttribute("VisorReadyAt", t + (tonumber(char:GetAttribute("VisorCooldown")) or 14))
	char:SetAttribute("VisorCount", (char:GetAttribute("VisorCount") or 0) + 1)
	setLook(char)
	setDown(char, true)
	setResult(char, "ok")
	char:SetAttribute("VisorStartedAt", t) -- last
end)

RunService.Heartbeat:Connect(function()
	local t = now()
	for char, untilT in pairs(running) do
		local hum = char.Parent and char:FindFirstChildOfClass("Humanoid")
		if not char.Parent or not hum then
			running[char] = nil
		elseif hum.Health <= 0 then
			finish(char, "dead")
		elseif char:GetAttribute("VisorEnabled") ~= true then
			finish(char, "disabled")
		elseif t >= untilT then
			finish(char, "time")
		end
	end
end)

local function onCharacter(char)
	char:GetAttributeChangedSignal("VisorLook"):Connect(function() setLook(char) end)
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
	fn.Name = "BuildPreview_visor"
	fn.OnInvoke = function(model)
		if not enabled() or typeof(model) ~= "Instance" then return nil end
		return build(model, true)
	end
	fn.Parent = script
end
