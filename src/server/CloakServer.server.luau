-- CloakServer v1.0 (Mecha Dino Arena) — Cloak Field, the raptor's first own mecha part: requests, timer, breaks, and the
-- visible emitter pack. MDA-51, plan docs/plans/CLOAK_v1.0.md Tasks 3 + 4b (Kepu 2026-10-29: faint shimmer, bots lose
-- you at once, breaks on pounce / damage / another part, 12 s cooldown, star capped at 2x; every mecha part is visible
-- hardware).
-- Settings come from SkillEffects 1.5 on the character: CloakEnabled (bought and slotted), CloakTime, CloakCooldown,
--   CloakPounceMul, CloakStill. Script attribute CloakServerEnabled (default true; false = every request "disabled").
-- Request: ReplicatedStorage.DinoCloakRequest:FireServer(stamp) (MechaButtons 1.4). Checks in order -> CloakResult:
--   "badArg" (stamp not a number), "dead", "disabled" (CloakServerEnabled false or CloakEnabled ~= true), "stunned"
--   (StunnedUntil > now), "latched" (PounceLatched), "active" (CloakedUntil > now), "cooldown" (now < CloakReadyAt),
--   "ok": CloakStartedAt = now, CloakedUntil = now + CloakTime, CloakState "on", CloakCount + 1.
-- While on, every Heartbeat, first match ends it (CloakEndReason):
--   "dead"   - health 0 or the character removed;
--   "pounce" - PounceStartedAt changed to a value >= CloakStartedAt (also CloakPounceArmed = that PounceStartedAt, which
--              PounceServer 1.5 uses for the landing bonus);
--   "damage" - Humanoid.Health dropped below the last value seen (healing never breaks it);
--   "part"   - another mecha part started: DashStartedAt changed (Thrusters); PART_STAMPS lists the attributes;
--   "time"   - now >= CloakedUntil.
--   Star (CloakStill): while the flat speed is under STILL_SPEED (1 stud/s) CloakedUntil = max(CloakedUntil,
--   min(now + 0.25, CloakStartedAt + 2 x CloakTime)) - standing still keeps the cloak, up to twice its time.
--   On any end: CloakedUntil = now, CloakState "off", CloakReadyAt = now + CloakCooldown (counted from the end).
-- Visible part (plan Task 4b): while CloakEnabled is true the character carries a Model "Mecha_Cloak": two thin grey
--   metal fins on top of the Torso segment (40% from the front, +-15% of its width; size from the dino's height), each
--   with a neon cyan strip (Transparency 0.7 dim, 0.2 while cloaked), welded to Torso.Root like Mecha_Thrusters (massless,
--   no collide / query / touch). Removed when CloakEnabled goes false. CloakFX 1.0 makes it see-through with the body.
-- Diagnostics: script CloakServerVersion, CloakRequests; character CloakResult, CloakState, CloakEndReason, CloakCount,
--   CloakLook ("on" / "none" / "noTorso").
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local VERSION = "1.0"
local STILL_SPEED = 1
local PART_STAMPS = {"DashStartedAt"} -- other mecha parts' start stamps break the cloak
local METAL, CYAN = Color3.fromRGB(110, 122, 134), Color3.fromRGB(95, 243, 255)

script:SetAttribute("CloakServerVersion", VERSION)
if script:GetAttribute("CloakServerEnabled") == nil then script:SetAttribute("CloakServerEnabled", true) end
script:SetAttribute("CloakRequests", 0)
local function now() return workspace:GetServerTimeNow() end

local remote = ReplicatedStorage:FindFirstChild("DinoCloakRequest")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "DinoCloakRequest"
	remote.Parent = ReplicatedStorage
end

local chars = {} -- [char] = {hum, lastHealth}

-- the visible part ---------------------------------------------------------------------------------------------------
local function weldPart(name, size, cf, color, parent, torso)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.Metal
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Anchored, p.Massless = false, true
	p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
	p.CastShadow = false
	p.Parent = parent
	local w = Instance.new("WeldConstraint")
	w.Part0, w.Part1 = torso, p
	w.Parent = p
	return p
end

local function setGlow(char, on)
	local m = char:FindFirstChild("Mecha_Cloak")
	if not m then return end
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") and d.Name:sub(1, 6) == "Strip_" then d.Transparency = on and 0.2 or 0.7 end
	end
end

local function buildPack(char)
	local old = char:FindFirstChild("Mecha_Cloak")
	if old then old:Destroy() end
	if char:GetAttribute("CloakEnabled") ~= true then
		char:SetAttribute("CloakLook", "none")
		return
	end
	local seg = char:FindFirstChild("Torso")
	local hrp = char:FindFirstChild("HumanoidRootPart")
	local torso = seg and (seg:FindFirstChild("Root") or seg:FindFirstChild("Torso_body", true))
	if not (seg and hrp and torso and torso:IsA("BasePart")) then
		char:SetAttribute("CloakLook", "noTorso")
		return
	end
	-- the Torso segment's box in the HumanoidRootPart frame (+X right, +Y up, -Z forward), as MechaServer measures it
	local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, p in ipairs(seg:GetDescendants()) do
		if p:IsA("BasePart") and p ~= torso then
			for _, sx in ipairs({-0.5, 0.5}) do for _, sy in ipairs({-0.5, 0.5}) do for _, sz in ipairs({-0.5, 0.5}) do
				local q = hrp.CFrame:PointToObjectSpace(p.CFrame * Vector3.new(p.Size.X * sx, p.Size.Y * sy, p.Size.Z * sz))
				lo, hi = lo:Min(q), hi:Max(q)
			end end end
		end
	end
	if lo.X == math.huge then
		char:SetAttribute("CloakLook", "noTorso")
		return
	end
	local R, U, L = hrp.CFrame.RightVector, hrp.CFrame.UpVector, hrp.CFrame.LookVector
	local W, Ln = hi.X - lo.X, hi.Z - lo.Z
	local Hd = char:GetExtentsSize().Y
	local fs = Vector3.new(Hd * 0.035, Hd * 0.16, Hd * 0.18) -- fin: right, up, look
	local model = Instance.new("Model")
	model.Name = "Mecha_Cloak"
	local baseLocal = Vector3.new((lo.X + hi.X) / 2, hi.Y + fs.Y * 0.4, lo.Z + Ln * 0.4)
	local base = hrp.CFrame:PointToWorldSpace(baseLocal)
	for _, side in ipairs({{"L", -1}, {"R", 1}}) do
		local c = base + R * side[2] * math.max(W * 0.15, fs.X * 2)
		local rot = CFrame.fromMatrix(c, R, U, -L) * CFrame.Angles(math.rad(-20), 0, 0) -- swept back a little
		weldPart("Fin_" .. side[1], fs, rot, METAL, model, torso)
		local strip = weldPart("Strip_" .. side[1], Vector3.new(fs.X * 1.15, fs.Y * 0.75, fs.Z * 0.18),
			rot * CFrame.new(0, 0, -fs.Z * 0.3), CYAN, model, torso)
		strip.Material = Enum.Material.Neon
		strip.Transparency = 0.7
	end
	model.Parent = char
	char:SetAttribute("CloakLook", "on")
	setGlow(char, char:GetAttribute("CloakState") == "on")
end

-- cloak state --------------------------------------------------------------------------------------------------------
local function endCloak(char, reason)
	if char:GetAttribute("CloakState") ~= "on" then return end
	local t = now()
	char:SetAttribute("CloakedUntil", t)
	char:SetAttribute("CloakEndReason", reason)
	char:SetAttribute("CloakReadyAt", t + (tonumber(char:GetAttribute("CloakCooldown")) or 0))
	char:SetAttribute("CloakState", "off") -- last: readers react to this one
	setGlow(char, false)
end

remote.OnServerEvent:Connect(function(player, stamp)
	local char = player.Character
	if not char or not chars[char] then return end
	script:SetAttribute("CloakRequests", (script:GetAttribute("CloakRequests") or 0) + 1)
	local t = now()
	local hum = chars[char].hum
	local result
	if typeof(stamp) ~= "number" or stamp ~= stamp then
		result = "badArg"
	elseif not hum or hum.Health <= 0 then
		result = "dead"
	elseif script:GetAttribute("CloakServerEnabled") == false or char:GetAttribute("CloakEnabled") ~= true then
		result = "disabled"
	elseif (tonumber(char:GetAttribute("StunnedUntil")) or 0) > t then
		result = "stunned"
	elseif char:GetAttribute("PounceLatched") == true then
		result = "latched"
	elseif (char:GetAttribute("CloakedUntil") or 0) > t then
		result = "active"
	elseif t < (char:GetAttribute("CloakReadyAt") or 0) then
		result = "cooldown"
	else
		result = "ok"
	end
	char:SetAttribute("CloakResult", result)
	if result ~= "ok" then return end
	chars[char].lastHealth = hum.Health
	char:SetAttribute("CloakStartedAt", t)
	char:SetAttribute("CloakedUntil", t + (tonumber(char:GetAttribute("CloakTime")) or 0))
	char:SetAttribute("CloakEndReason", "")
	char:SetAttribute("CloakCount", (char:GetAttribute("CloakCount") or 0) + 1)
	char:SetAttribute("CloakState", "on") -- last
	setGlow(char, true)
end)

local function onCharacter(char)
	if chars[char] then return end
	local hum = char:WaitForChild("Humanoid", 10)
	if not hum then return end
	local st = {hum = hum, lastHealth = hum.Health}
	chars[char] = st
	char:SetAttribute("CloakState", "off")
	char:SetAttribute("CloakedUntil", 0)
	char:SetAttribute("CloakReadyAt", 0)
	char:SetAttribute("CloakLook", "none")
	hum.HealthChanged:Connect(function(h)
		if char:GetAttribute("CloakState") == "on" and h < st.lastHealth - 1e-3 then endCloak(char, h <= 0 and "dead" or "damage") end
		st.lastHealth = h
	end)
	char:GetAttributeChangedSignal("PounceStartedAt"):Connect(function()
		local ps = char:GetAttribute("PounceStartedAt")
		if char:GetAttribute("CloakState") == "on" and typeof(ps) == "number" and ps >= (char:GetAttribute("CloakStartedAt") or math.huge) then
			char:SetAttribute("CloakPounceArmed", ps)
			endCloak(char, "pounce")
		end
	end)
	for _, a in ipairs(PART_STAMPS) do
		char:GetAttributeChangedSignal(a):Connect(function()
			if char:GetAttribute("CloakState") == "on" then endCloak(char, "part") end
		end)
	end
	char:GetAttributeChangedSignal("CloakEnabled"):Connect(function()
		if char:GetAttribute("CloakEnabled") ~= true then endCloak(char, "part") end
		buildPack(char)
	end)
	char.AncestryChanged:Connect(function(_, parent)
		if not parent then chars[char] = nil end
	end)
	buildPack(char)
end

RunService.Heartbeat:Connect(function()
	local t = now()
	for char, st in pairs(chars) do
		if char:GetAttribute("CloakState") == "on" then
			if not char.Parent or st.hum.Health <= 0 then
				endCloak(char, "dead")
			else
				if char:GetAttribute("CloakStill") == true then
					local hrp = char:FindFirstChild("HumanoidRootPart")
					local v = hrp and hrp.AssemblyLinearVelocity
					if v and Vector3.new(v.X, 0, v.Z).Magnitude < STILL_SPEED then
						local cap = (char:GetAttribute("CloakStartedAt") or t) + 2 * (tonumber(char:GetAttribute("CloakTime")) or 0)
						local u = char:GetAttribute("CloakedUntil") or t
						local want = math.max(u, math.min(t + 0.25, cap))
						if want ~= u then char:SetAttribute("CloakedUntil", want) end
					end
				end
				if t >= (char:GetAttribute("CloakedUntil") or 0) then endCloak(char, "time") end
			end
		end
	end
end)

local function onPlayer(player)
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then task.spawn(onCharacter, player.Character) end
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do onPlayer(p) end
