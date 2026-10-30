-- CloakServer v1.6 (Mecha Dino Arena) — Cloak Field, the raptor's first own mecha part: requests, timer, breaks, and the
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
-- v1.1 (MDA-55, plan docs/plans/CLOAK_LOOK_v1.1.md Task 1; Kepu 2026-10-29: "the cloak design looks too similar to the
--   thrusters" -> option C "Camo plates", docs/mockups/cloak_look_options.html): script attribute CloakLookStyle (default
--   "plates"; "fins" = the 1.0 fins). Plates: Model "Mecha_Cloak" with 4 upright hexagonal plates in the body's
--   mid-plane on top of the Torso segment at 14 / 33 / 52 / 70 % of its length from the front; radius R = 5.2 % of the
--   dino's height, centre R / 2 above the top. Plate n = Plate_n_Body_0..2 (stealth black rgb(29, 37, 51), SmoothPlastic,
--   sqrt3 R x R blocks rotated 0 / 60 / 120 degrees about the sideways axis, thickness max(0.05, 1.2 % of the height))
--   + Plate_n_Rim_0..2 (neon cyan, radius 1.12 R, 0.8 x the thickness). Plate_n_Body_0 is held to Torso.Root by a Weld
--   "PlateHinge" (attribute BaseC0 = its C0) so CloakFX 1.1 can turn the plate about the spine; the other 5 parts are
--   WeldConstraints to it. Massless, no collide / query / touch, no shadow. CloakLook "plates" ("on" = 1.0 fins).
-- v1.2 (Kepu 2026-10-29: "the camo plates i thought would run along the side of the raptor like the picture not down
--   the middle on its spine"; picked "Both sides, upper flank"): CloakLookStyle default "flanks" ("plates" = the 1.1
--   spine row, "fins" = 1.0). Flanks: the same plate build (Body / Rim hexes, PlateHinge + BaseC0) lying flat on each
--   side of the Torso segment, face outward: 4 per side at 14 / 33 / 52 / 70 % of its length from the front, centre at
--   68 % of its height (upper flank), just outside its side (x = edge +- (thickness / 2 + 0.02)). Plate_1..4 = right side,
--   Plate_5..8 = left side, front to back; each PlateHinge has attribute PlateOrder 1..4 (front to back) for CloakFX's
--   flip timing. CloakLook "flanks".
-- v1.3 (raptor parts batch 1, MDA-64, plan docs/plans/RAPTOR_PARTS_B1_v1.0.md Task 7): PART_STAMPS also lists
--   AdrenalineStartedAt (AdrenalineServer 1.0) and EnergyShieldStartedAt (EnergyShieldServer 1.0): using either part ends
--   the cloak with "part", like Thrusters. Nothing else changed.
-- v1.4 (raptor parts batch 2, MDA-73, plan docs/plans/RAPTOR_PARTS_B2_v1.0.md Task 5): PART_STAMPS also lists
--   ScentStartedAt (ScentServer 1.0) and ScreechStartedAt (ScreechServer 1.0): using either ends your cloak with "part".
--   A Raptor Screech hit (ScreechHitAt, ScreechServer 1.0) ends the hit dino's cloak with the new reason "screech".
-- v1.5 (raptor traps, MDA-80, plan docs/plans/RAPTOR_TRAPS_v1.0.md Task 5): PART_STAMPS also lists MineStartedAt
--   (MineServer 1.0): throwing a Shock Mine ends your cloak with "part", like every other part.
-- v1.6 (Lab, MDA-96, plan docs/plans/LAB_v1.0.md Task 1; Kepu 2026-10-29: "Add a preview builder"): BindableFunction
--   "BuildPreview" under this script (server only). Invoke(model) builds this part on the given dino model (a Lab
--   mannequin, not a player) with the same build code (CloakEnabled = true, then buildPack(model)) and returns its Model "Mecha_Cloak" (nil when
--   nothing was built). LabPreviewServer 1.0 turns it into the Lab card model. The live part is unchanged. Switch: script
--   attribute CloakServerPreviewEnabled (default true; false -> returns nil).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local VERSION = "1.6"
local STILL_SPEED = 1
local PART_STAMPS = {"DashStartedAt", "AdrenalineStartedAt", "EnergyShieldStartedAt"} -- other mecha parts' start stamps break the cloak; v1.3: + Adrenaline / Energy Shield
table.insert(PART_STAMPS, "ScentStartedAt") -- v1.4
table.insert(PART_STAMPS, "ScreechStartedAt") -- v1.4
table.insert(PART_STAMPS, "MineStartedAt") -- v1.5
local METAL, CYAN = Color3.fromRGB(110, 122, 134), Color3.fromRGB(95, 243, 255)

script:SetAttribute("CloakServerVersion", VERSION)
if script:GetAttribute("CloakServerEnabled") == nil then script:SetAttribute("CloakServerEnabled", true) end
script:SetAttribute("CloakRequests", 0)
if script:GetAttribute("CloakLookStyle") == nil then script:SetAttribute("CloakLookStyle", "flanks") end -- v1.1; v1.2: default "flanks"
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

-- v1.1: camo plates (option C)
local PLATE_BLACK = Color3.fromRGB(29, 37, 51)
local PLATE_AT = {0.14, 0.33, 0.52, 0.70} -- from the front of the Torso segment
local function buildPlates(char, hrp, torso, lo, hi, Hd)
	local model = Instance.new("Model")
	model.Name = "Mecha_Cloak"
	local R, U, L = hrp.CFrame.RightVector, hrp.CFrame.UpVector, hrp.CFrame.LookVector
	local r = Hd * 0.052
	local th = math.max(0.05, Hd * 0.012)
	for i, f in ipairs(PLATE_AT) do
		local local_ = Vector3.new((lo.X + hi.X) / 2, hi.Y + r * 0.5, lo.Z + (hi.Z - lo.Z) * f) -- lo.Z = front (-Z forward)
		local plateCF = CFrame.fromMatrix(hrp.CFrame:PointToWorldSpace(local_), R, U, -L) -- X right, Y up, Z back
		local root = weldPart(("Plate_%d_Body_0"):format(i), Vector3.new(th, r, r * math.sqrt(3)), plateCF, PLATE_BLACK, model, torso)
		root.Material = Enum.Material.SmoothPlastic
		local wc = root:FindFirstChildOfClass("WeldConstraint")
		if wc then wc:Destroy() end
		local hinge = Instance.new("Weld")
		hinge.Name = "PlateHinge"
		hinge.Part0, hinge.Part1 = torso, root
		hinge.C0 = torso.CFrame:ToObjectSpace(plateCF)
		hinge.C1 = CFrame.new()
		hinge:SetAttribute("BaseC0", hinge.C0)
		hinge.Parent = root
		for k = 0, 2 do
			local cf = plateCF * CFrame.Angles(math.rad(60 * k), 0, 0)
			if k > 0 then
				local b = weldPart(("Plate_%d_Body_%d"):format(i, k), Vector3.new(th, r, r * math.sqrt(3)), cf, PLATE_BLACK, model, root)
				b.Material = Enum.Material.SmoothPlastic
			end
			local rim = weldPart(("Plate_%d_Rim_%d"):format(i, k), Vector3.new(th * 0.8, r * 1.12, r * 1.12 * math.sqrt(3)), cf, CYAN, model, root)
			rim.Material = Enum.Material.Neon
		end
	end
	model.Parent = char
	char:SetAttribute("CloakLook", "plates")
end

-- v1.2: plates flat on both flanks (upper half), 4 per side
local function buildFlankPlates(char, hrp, torso, lo, hi, Hd)
	local model = Instance.new("Model")
	model.Name = "Mecha_Cloak"
	local R, U, L = hrp.CFrame.RightVector, hrp.CFrame.UpVector, hrp.CFrame.LookVector
	local r = Hd * 0.052
	local th = math.max(0.05, Hd * 0.012)
	local y = lo.Y + (hi.Y - lo.Y) * 0.68
	local n = 0
	for _, side in ipairs({{hi.X, 1}, {lo.X, -1}}) do -- right, then left
		for order, f in ipairs(PLATE_AT) do
			n += 1
			local local_ = Vector3.new(side[1] + side[2] * (th / 2 + 0.02), y, lo.Z + (hi.Z - lo.Z) * f)
			local plateCF = CFrame.fromMatrix(hrp.CFrame:PointToWorldSpace(local_), R, U, -L) -- X right, Y up, Z back
			local root = weldPart(("Plate_%d_Body_0"):format(n), Vector3.new(th, r, r * math.sqrt(3)), plateCF, PLATE_BLACK, model, torso)
			root.Material = Enum.Material.SmoothPlastic
			local wc = root:FindFirstChildOfClass("WeldConstraint")
			if wc then wc:Destroy() end
			local hinge = Instance.new("Weld")
			hinge.Name = "PlateHinge"
			hinge.Part0, hinge.Part1 = torso, root
			hinge.C0 = torso.CFrame:ToObjectSpace(plateCF)
			hinge.C1 = CFrame.new()
			hinge:SetAttribute("BaseC0", hinge.C0)
			hinge:SetAttribute("PlateOrder", order)
			hinge.Parent = root
			for k = 0, 2 do
				local cf = plateCF * CFrame.Angles(math.rad(60 * k), 0, 0)
				if k > 0 then
					local b = weldPart(("Plate_%d_Body_%d"):format(n, k), Vector3.new(th, r, r * math.sqrt(3)), cf, PLATE_BLACK, model, root)
					b.Material = Enum.Material.SmoothPlastic
				end
				local rim = weldPart(("Plate_%d_Rim_%d"):format(n, k), Vector3.new(th * 0.8, r * 1.12, r * 1.12 * math.sqrt(3)), cf, CYAN, model, root)
				rim.Material = Enum.Material.Neon
			end
		end
	end
	model.Parent = char
	char:SetAttribute("CloakLook", "flanks")
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
	local style = script:GetAttribute("CloakLookStyle")
	if style == "plates" then -- v1.1: camo plates on the spine (option C)
		buildPlates(char, hrp, torso, lo, hi, Hd)
		return
	elseif style ~= "fins" then -- v1.2: camo plates on both flanks (default)
		buildFlankPlates(char, hrp, torso, lo, hi, Hd)
		return
	end
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
	char:GetAttributeChangedSignal("ScreechHitAt"):Connect(function() -- v1.4: a screech hit knocks you out of the cloak
		if char:GetAttribute("CloakState") == "on" then endCloak(char, "screech") end
	end)
	char:GetAttributeChangedSignal("CloakEnabled"):Connect(function()
		if char:GetAttribute("CloakEnabled") ~= true then endCloak(char, "part") end
		buildPack(char)
	end)
	char.AncestryChanged:Connect(function(_, parent)
		if not parent then chars[char] = nil end
	end)
	script:GetAttributeChangedSignal("CloakLookStyle"):Connect(function() -- v1.1
		if chars[char] then buildPack(char) end
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

-- v1.6: Lab card preview (LabPreviewServer 1.0)
if script:GetAttribute("CloakServerPreviewEnabled") == nil then script:SetAttribute("CloakServerPreviewEnabled", true) end
local previewFn = script:FindFirstChild("BuildPreview") or Instance.new("BindableFunction")
previewFn.Name = "BuildPreview"
previewFn.Parent = script
previewFn.OnInvoke = function(model)
	if script:GetAttribute("CloakServerPreviewEnabled") == false or typeof(model) ~= "Instance" then return nil end
	model:SetAttribute("CloakEnabled", true)
	buildPack(model)
	return model:FindFirstChild("Mecha_Cloak")
end
