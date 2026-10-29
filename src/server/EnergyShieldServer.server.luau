-- EnergyShieldServer v1.3 (Mecha Dino Arena) — Energy Shield, a raptor button part (raptor parts batch 1): block all
-- damage for a short time, but move slower while it's up. MDA-63, plan docs/plans/RAPTOR_PARTS_B1_v1.0.md Task 6, mockup
-- docs/mockups/raptor_parts_b1_options.html option B "Hard-light shell" (Kepu 2026-10-29: full block; "If we're allowing
-- it to block all attacks then the push back shouldn't exist"; "You block all damage but you're slower during the
-- blocking period" -> half speed, lighter at star).
-- Settings come from the character (SkillEffects 1.6): EnergyShieldEnabled (bought AND slotted), EnergyShieldTime (1.5;
--   2.05 from II; 2.77 at star), EnergyShieldCooldown (16; 11.8 from III), EnergyShieldSpeedMul (0.5; 0.68 at star;
--   SprintTest 1.6 applies it while EnergyShieldUntil > now).
-- Client -> server: ReplicatedStorage.DinoEnergyShieldRequest:FireServer(clientServerTime). Checks, first failing wins:
--   "badArg", "dead", "disabled" (EnergyShieldServerEnabled false or EnergyShieldEnabled ~= true), "stunned"
--   (StunnedUntil > now), "latched" (PounceLatched), "active" (EnergyShieldUntil > now), "cooldown" (now <
--   EnergyShieldReadyAt), "ok". ok: EnergyShieldStartedAt = now, EnergyShieldUntil = now + time, EnergyShieldReadyAt =
--   EnergyShieldUntil + cooldown (counted from the end, like Cloak), EnergyShieldCount + 1, EnergyShieldBlocks = 0.
-- Block: a ForceField "EnergyShieldField" (Visible = false) under the character while it is up, so every
--   Humanoid:TakeDamage (bot bites, bot latch / pin bites) does nothing. Each new LastHitAt (BotServer stamps it on every
--   hit attempt that reaches TakeDamage) while up counts a block: EnergyShieldBlocks + 1, EnergyShieldBlockAt.
-- Look: a Highlight "EnergyShieldShell" on the character while up (fill and outline blue 90,160,255, FillTransparency
--   0.85, OutlineTransparency 0; everyone sees it); on a block the outline turns white for 0.12 s. While
--   EnergyShieldEnabled: a small emitter disc "Emitter" (dark ring + blue neon core) on the chest (front of the Torso
--   segment's box in its Root's own frame, lower part), welded to Torso.Root; Model "Mecha_EnergyShield".
-- End: at EnergyShieldUntil ("time"), death ("dead") or EnergyShieldEnabled turning false ("disabled"): the ForceField
--   and the Highlight are destroyed (not disabled: disabled Highlights still count toward the per-client limit); early
--   ends set EnergyShieldUntil = now and EnergyShieldReadyAt = now + cooldown. EnergyShieldEndReason.
-- v1.1 (Kepu 2026-10-29: "the ability themselves don't seem obvious enough" -> mockup
--   docs/mockups/raptor_parts_b1_looks.html, picked A "Hex dome"): script attribute EnergyShieldLookStyle (default
--   "dome"; "shell" = the 1.0 Highlight shell + chest emitter). Dome look:
--   * Shoulder emitters: one disc each side of the torso, front top ("EmitterL" / "EmitterR" dark ring + "EmitterCoreL"
--     / "EmitterCoreR" blue neon), size by the player's SkillPath_shield: I 0.06, II 0.08, III 0.1, star 0.12 x dino
--     height; from III a second neon ring "EmitterHaloL" / "EmitterHaloR". Rebuilt when that step changes.
--   * While up: "EnergyShieldDome", an ellipsoid Part (SpecialMesh Sphere) of Material ForceField, blue, around the
--     whole character (its box in the HumanoidRootPart's frame x DOME_PAD), welded to the HumanoidRootPart, massless, no collide / query.
--     Parented to workspace, not the character, so the character's size (pounce latch / pin check, stun, growth)
--     doesn't change while it's up.
--     Width at least its height (a round bubble from the camera behind). Transparency 0.25 (III and star: 0 =
--     brighter); star adds "EnergyShieldDome2" at x1.08; inside, "EnergyShieldDomeTint" (same ellipsoid x0.98,
--     SmoothPlastic blue, Transparency DOME_TINT 0.8) so the bubble reads as solid. No Highlight in this style.
--     A block flashes the dome white for 0.12 s and puts a white neon ripple ball "EnergyShieldRipple" on the dome
--     surface toward the attacker (LastHitBy model; front if not found) that grows and fades in 0.3 s. The dome fades
--     out (Transparency -> 1) over the last DOME_FADE (0.4) s.
--   Diagnostics: EnergyShieldLook "dome" / "on" (shell) / "none" / "noTorso"; EnergyShieldLookStep; EnergyShieldRipples.
-- v1.2 (Kepu 2026-10-29: "the shield is so ugly. Just go back to the first version of the shield where the blue is
--   wrapped around the body of the raptor just make it persist for the whole duration of the shield"):
--   * EnergyShieldLookStyle default is "shell" again (the 1.0 Highlight "EnergyShieldShell"); "dome" keeps the 1.1 dome.
--   * The shoulder emitters stay (1.1); new script attribute EnergyShieldEmitterStyle ("shoulders" default; "chest" =
--     the 1.0 chest disc). EnergyShieldLook "shoulders" / "on" (chest) / "none" / "noTorso".
--   * Persist: only one Highlight shows on a character at a time and the newest one wins (Play: the Adrenaline glow
--     hid the shell while both were up). While the shield is up in shell style, any other Highlight added to the
--     character makes the shell be rebuilt (deferred) so it is the newest and stays visible for the whole shield.
--     The other Highlight shows again once the shell is gone. Diagnostic: character EnergyShieldShellRefreshes.
-- v1.3 (raptor parts batch 2, MDA-74, plan docs/plans/RAPTOR_PARTS_B2_v1.0.md Task 6): a new PartsJammedAt on the
--   character (a star Raptor Screech hit, ScreechServer 1.0) ends a running shield at once with EnergyShieldEndReason "jammed" (the
--   cooldown then counts from now, like any early end).
-- Settings: script attribute EnergyShieldServerEnabled (default true).
-- Diagnostics: script EnergyShieldServerVersion, EnergyShieldRequests; character EnergyShieldServerResult,
--   EnergyShieldCount, EnergyShieldBlocks, EnergyShieldBlockAt, EnergyShieldEndReason, EnergyShieldState ("off" / "on"),
--   EnergyShieldLook ("none" / "on" / "noTorso").
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService") -- v1.1

local VERSION = "1.3"
local BLUE, DARK, WHITE = Color3.fromRGB(90, 160, 255), Color3.fromRGB(44, 52, 64), Color3.new(1, 1, 1)

script:SetAttribute("EnergyShieldServerVersion", VERSION)
if script:GetAttribute("EnergyShieldServerEnabled") == nil then script:SetAttribute("EnergyShieldServerEnabled", true) end
script:SetAttribute("EnergyShieldRequests", 0)
if script:GetAttribute("EnergyShieldLookStyle") == nil then script:SetAttribute("EnergyShieldLookStyle", "shell") end -- v1.2: shell (1.1: dome)
if script:GetAttribute("EnergyShieldEmitterStyle") == nil then script:SetAttribute("EnergyShieldEmitterStyle", "shoulders") end -- v1.2
local DOME_PAD, DOME_FADE = 1.15, 0.4 -- v1.1
local DOME_TINT = 0.8 -- v1.1: tint layer transparency
local EMIT_SIZE = {0.06, 0.08, 0.1, 0.12} -- v1.1: x dino height, by step I..star
local function domeStyle() return script:GetAttribute("EnergyShieldLookStyle") == "dome" end -- v1.2: dome only when asked
local function shoulderEmitters() return script:GetAttribute("EnergyShieldEmitterStyle") ~= "chest" end -- v1.2
local function stepOf(char)
	local pl = Players:GetPlayerFromCharacter(char)
	return pl and tonumber(pl:GetAttribute("SkillPath_shield")) or 0
end
local function on() return script:GetAttribute("EnergyShieldServerEnabled") ~= false end
local function now() return workspace:GetServerTimeNow() end

local remote = ReplicatedStorage:FindFirstChild("DinoEnergyShieldRequest")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "DinoEnergyShieldRequest"
	remote.Parent = ReplicatedStorage
end

local chars = {} -- [char] = {hum, active, flashToken}

local function part(name, size, cf, color, parent, mount)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Anchored, p.Massless = false, true
	p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
	p.CastShadow = false
	p.Parent = parent
	local w = Instance.new("WeldConstraint")
	w.Part0, w.Part1 = mount, p
	w.Parent = p
	return p
end

-- the segment's box in its Root's own frame (so the pose at build time doesn't matter)
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
-- the Root-space axis (unit +-X / Y / Z) nearest to a world direction
local function axisOf(root, dir)
	local v = root.CFrame:VectorToObjectSpace(dir)
	local a = Vector3.new(math.abs(v.X), math.abs(v.Y), math.abs(v.Z))
	if a.X >= a.Y and a.X >= a.Z then return Vector3.new(v.X >= 0 and 1 or -1, 0, 0) end
	if a.Y >= a.Z then return Vector3.new(0, v.Y >= 0 and 1 or -1, 0) end
	return Vector3.new(0, 0, v.Z >= 0 and 1 or -1)
end
-- distance from the box centre to its face along a unit axis
local function extent(lo, hi, axis)
	local h = (hi - lo) / 2
	return math.abs(axis.X) * h.X + math.abs(axis.Y) * h.Y + math.abs(axis.Z) * h.Z
end
-- Root-space right / up / back axes that follow the body's right / up (z = x cross y = back)
local function bodyAxes(root, hrp)
	local x = axisOf(root, hrp.CFrame.RightVector)
	local y = axisOf(root, hrp.CFrame.UpVector)
	if math.abs(x:Dot(y)) > 0.5 then y = axisOf(root, hrp.CFrame.LookVector):Cross(x) end
	return x, y, x:Cross(y)
end

local function build(char)
	local old = char:FindFirstChild("Mecha_EnergyShield")
	if old then old:Destroy() end
	if not on() or char:GetAttribute("EnergyShieldEnabled") ~= true then
		char:SetAttribute("EnergyShieldLook", "none")
		return
	end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	local seg = char:FindFirstChild("Torso")
	local root = seg and seg:FindFirstChild("Root")
	if not (hrp and root) then char:SetAttribute("EnergyShieldLook", "noTorso") return end
	local lo, hi = rootBox(seg, root)
	if not lo then char:SetAttribute("EnergyShieldLook", "noTorso") return end
	local Hd = char:GetExtentsSize().Y
	if shoulderEmitters() then -- v1.1: shoulder emitters, size by step (v1.2: own switch)
		local step = math.clamp(stepOf(char), 1, 4)
		char:SetAttribute("EnergyShieldLookStep", step)
		local d = Hd * EMIT_SIZE[step]
		local model = Instance.new("Model")
		model.Name = "Mecha_EnergyShield"
		local x, y, z = bodyAxes(root, hrp)
		for _, side in ipairs({{"L", -1}, {"R", 1}}) do
			-- side face of the torso box, front top; the cylinder's axis (its X) points out sideways
			local pLocal = (lo + hi) / 2 + x * side[2] * (extent(lo, hi, x) + d * 0.1) + y * (extent(lo, hi, y) * 0.45)
				- z * (extent(lo, hi, z) * 0.45)
			local out = x * side[2]
			local cf = root.CFrame * CFrame.fromMatrix(pLocal, out, y)
			local ring = part("Emitter" .. side[1], Vector3.new(d * 0.3, d, d), cf, DARK, model, root)
			ring.Shape = Enum.PartType.Cylinder
			local core = part("EmitterCore" .. side[1], Vector3.new(d * 0.36, d * 0.55, d * 0.55), cf, BLUE, model, root)
			core.Shape = Enum.PartType.Cylinder
			core.Material = Enum.Material.Neon
			if step >= 3 then
				local halo = part("EmitterHalo" .. side[1], Vector3.new(d * 0.12, d * 1.35, d * 1.35), cf * CFrame.new(-d * 0.05, 0, 0), BLUE, model, root)
				halo.Shape = Enum.PartType.Cylinder
				halo.Material = Enum.Material.Neon
				halo.Transparency = 0.35
			end
		end
		model.Parent = char
		char:SetAttribute("EnergyShieldLook", "shoulders") -- v1.2 (1.1: "dome")
		return
	end
	local d = Hd * 0.06
	local model = Instance.new("Model")
	model.Name = "Mecha_EnergyShield"
	-- chest: front face of the torso box (forward = -z), lower part; the cylinder's axis (its X) points forward
	local x, y, z = bodyAxes(root, hrp)
	local pLocal = (lo + hi) / 2 - z * (extent(lo, hi, z) + d * 0.05) - y * (extent(lo, hi, y) * 0.3)
	local cf = root.CFrame * CFrame.fromMatrix(pLocal, -z, y)
	local ring = part("Emitter", Vector3.new(d * 0.25, d, d), cf, DARK, model, root)
	ring.Shape = Enum.PartType.Cylinder
	local core = part("EmitterCore", Vector3.new(d * 0.3, d * 0.5, d * 0.5), cf, BLUE, model, root)
	core.Shape = Enum.PartType.Cylinder
	core.Material = Enum.Material.Neon
	model.Parent = char
	char:SetAttribute("EnergyShieldLook", "on")
end

-- v1.2: the 1.0 shell as a function, so it can be rebuilt to stay the newest Highlight
local function shell(char)
	local old = char:FindFirstChild("EnergyShieldShell")
	while old do
		old:Destroy()
		old = char:FindFirstChild("EnergyShieldShell")
	end
	local hl = Instance.new("Highlight")
	hl.Name = "EnergyShieldShell"
	hl.FillColor, hl.OutlineColor = BLUE, BLUE
	hl.FillTransparency, hl.OutlineTransparency = 0.85, 0
	hl.DepthMode = Enum.HighlightDepthMode.Occluded
	hl.Parent = char
	return hl
end

local function clearFx(char)
	local st = chars[char] -- v1.1: the domes live in workspace
	if st and st.domes then
		for _, dm in ipairs(st.domes) do dm:Destroy() end
		st.domes = nil
	end
	for _, n in ipairs({"EnergyShieldField", "EnergyShieldShell", "EnergyShieldDome", "EnergyShieldDome2"}) do -- v1.1: + domes
		local x = char:FindFirstChild(n)
		while x do
			x:Destroy()
			x = char:FindFirstChild(n)
		end
	end
end

local function finish(char, reason)
	local st = chars[char]
	if not st or not st.active then return end
	st.active = false
	local t = now()
	if reason ~= "time" then
		char:SetAttribute("EnergyShieldUntil", t)
		char:SetAttribute("EnergyShieldReadyAt", t + (tonumber(char:GetAttribute("EnergyShieldCooldown")) or 0))
	end
	clearFx(char)
	char:SetAttribute("EnergyShieldEndReason", reason)
	char:SetAttribute("EnergyShieldState", "off")
end

remote.OnServerEvent:Connect(function(player, stamp)
	local char = player.Character
	local st = char and chars[char]
	if not st then return end
	script:SetAttribute("EnergyShieldRequests", (script:GetAttribute("EnergyShieldRequests") or 0) + 1)
	local t = now()
	local hum = st.hum
	local result
	if typeof(stamp) ~= "number" or stamp ~= stamp then
		result = "badArg"
	elseif not hum or hum.Health <= 0 then
		result = "dead"
	elseif not on() or char:GetAttribute("EnergyShieldEnabled") ~= true then
		result = "disabled"
	elseif (tonumber(char:GetAttribute("StunnedUntil")) or 0) > t then
		result = "stunned"
	elseif char:GetAttribute("PounceLatched") == true then
		result = "latched"
	elseif (tonumber(char:GetAttribute("EnergyShieldUntil")) or 0) > t then
		result = "active"
	elseif t < (tonumber(char:GetAttribute("EnergyShieldReadyAt")) or 0) then
		result = "cooldown"
	else
		result = "ok"
	end
	char:SetAttribute("EnergyShieldServerResult", result)
	if result ~= "ok" then return end
	local dur = math.max(0.1, tonumber(char:GetAttribute("EnergyShieldTime")) or 1.5)
	clearFx(char)
	local ff = Instance.new("ForceField")
	ff.Name = "EnergyShieldField"
	ff.Visible = false
	ff.Parent = char
	if domeStyle() then -- v1.1: hex dome
		local hrp = char:FindFirstChild("HumanoidRootPart")
		if hrp then
			-- the character's box in the HumanoidRootPart's own frame (GetBoundingBox follows the PrimaryPart, which can
			-- be a tilted segment: Play showed a thin slab)
			local blo, bhi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
			for _, bp in ipairs(char:GetDescendants()) do
				if bp:IsA("BasePart") and bp ~= hrp and bp.Transparency < 1 then
					for _, sx in ipairs({-0.5, 0.5}) do for _, sy in ipairs({-0.5, 0.5}) do for _, sz in ipairs({-0.5, 0.5}) do
						local q = hrp.CFrame:PointToObjectSpace(bp.CFrame * Vector3.new(bp.Size.X * sx, bp.Size.Y * sy, bp.Size.Z * sz))
						blo, bhi = blo:Min(q), bhi:Max(q)
					end end end
				end
			end
			if blo.X == math.huge then blo, bhi = -hrp.Size / 2, hrp.Size / 2 end
			local bcf, bsize = hrp.CFrame * CFrame.new((blo + bhi) / 2), bhi - blo
			bsize = Vector3.new(math.max(bsize.X, bsize.Y), bsize.Y, bsize.Z) -- a round bubble from the camera behind, not a thin oval
			local step = stepOf(char)
			st.domes = {}
			for i = 1, (step >= 4 and 2 or 1) do
				local dome = Instance.new("Part")
				dome.Name = i == 1 and "EnergyShieldDome" or "EnergyShieldDome2"
				dome.Size = bsize * DOME_PAD * (i == 1 and 1 or 1.08)
				dome.CFrame = bcf
				dome.Color = BLUE
				dome.Material = Enum.Material.ForceField
				dome.Transparency = step >= 3 and 0 or 0.25
				dome.Anchored, dome.Massless = false, true
				dome.CanCollide, dome.CanQuery, dome.CanTouch = false, false, false
				dome.CastShadow = false
				local mesh = Instance.new("SpecialMesh")
				mesh.MeshType = Enum.MeshType.Sphere
				mesh.Parent = dome
				local w = Instance.new("WeldConstraint")
				w.Part0, w.Part1 = hrp, dome
				w.Parent = dome
				dome:SetAttribute("BaseTransparency", dome.Transparency)
				dome.Parent = workspace
				table.insert(st.domes, dome)
				local fadeIn = math.max(0, dur - DOME_FADE)
				task.delay(fadeIn, function()
					if dome.Parent then TweenService:Create(dome, TweenInfo.new(math.min(DOME_FADE, dur)), {Transparency = 1}):Play() end
				end)
			end
			-- a light blue tint inside the hex layer, so the bubble reads as solid from the game camera
			local first = st.domes[1]
			local tint = first:Clone()
			tint:ClearAllChildren()
			tint.Name = "EnergyShieldDomeTint"
			tint.Material = Enum.Material.SmoothPlastic
			tint.Size = first.Size * 0.98
			tint.CFrame = first.CFrame
			tint.Transparency = DOME_TINT
			local tm = Instance.new("SpecialMesh")
			tm.MeshType = Enum.MeshType.Sphere
			tm.Parent = tint
			local tw = Instance.new("WeldConstraint")
			tw.Part0, tw.Part1 = hrp, tint
			tw.Parent = tint
			tint.Parent = workspace
			table.insert(st.domes, tint)
			task.delay(math.max(0, dur - DOME_FADE), function()
				if tint.Parent then TweenService:Create(tint, TweenInfo.new(math.min(DOME_FADE, dur)), {Transparency = 1}):Play() end
			end)
		end
	else
	shell(char) -- v1.2: same Highlight as 1.0, built by shell()
	end -- v1.1: end of the 1.0 shell
	st.active = true
	st.lastHit = char:GetAttribute("LastHitAt")
	char:SetAttribute("EnergyShieldBlocks", 0)
	char:SetAttribute("EnergyShieldEndReason", "")
	char:SetAttribute("EnergyShieldUntil", t + dur)
	char:SetAttribute("EnergyShieldReadyAt", t + dur + (tonumber(char:GetAttribute("EnergyShieldCooldown")) or 0))
	char:SetAttribute("EnergyShieldCount", (char:GetAttribute("EnergyShieldCount") or 0) + 1)
	char:SetAttribute("EnergyShieldState", "on")
	char:SetAttribute("EnergyShieldStartedAt", t) -- last: readers react to this one
end)

RunService.Heartbeat:Connect(function()
	local t = now()
	for char, st in pairs(chars) do
		if st.active then
			if not char.Parent or st.hum.Health <= 0 then
				finish(char, "dead")
			elseif t >= (tonumber(char:GetAttribute("EnergyShieldUntil")) or 0) then
				finish(char, "time")
			end
		end
	end
end)

local function onCharacter(char)
	if chars[char] then return end
	local hum = char:WaitForChild("Humanoid", 10)
	if not hum then return end
	local st = {hum = hum, active = false}
	chars[char] = st
	char:SetAttribute("EnergyShieldUntil", 0)
	char:SetAttribute("EnergyShieldReadyAt", 0)
	char:SetAttribute("EnergyShieldState", "off")
	char:SetAttribute("EnergyShieldLook", "none")
	char:GetAttributeChangedSignal("LastHitAt"):Connect(function()
		local at = char:GetAttribute("LastHitAt")
		if not st.active or at == st.lastHit then return end
		st.lastHit = at
		char:SetAttribute("EnergyShieldBlocks", (char:GetAttribute("EnergyShieldBlocks") or 0) + 1)
		char:SetAttribute("EnergyShieldBlockAt", now())
		local dome = st.domes and st.domes[1] -- v1.1: dome flash + ripple
		if dome and dome.Parent then
			local token = {}
			st.flashToken = token
			dome.Color = WHITE
			task.delay(0.12, function()
				if st.flashToken == token and dome.Parent then dome.Color = BLUE end
			end)
			local c = dome.Position
			local dir = dome.CFrame.LookVector
			local by = char:GetAttribute("LastHitBy")
			local att = typeof(by) == "string" and workspace:FindFirstChild(by, true)
			local ap = att and att:IsA("Model") and att:GetPivot().Position
			if ap and (ap - c).Magnitude > 0.1 then dir = (ap - c).Unit end
			local l = dome.CFrame:VectorToObjectSpace(dir) -- the ellipsoid's surface point along dir
			local hs = dome.Size / 2
			local k = 1 / math.sqrt((l.X / hs.X) ^ 2 + (l.Y / hs.Y) ^ 2 + (l.Z / hs.Z) ^ 2)
			local rp = Instance.new("Part")
			rp.Name = "EnergyShieldRipple"
			rp.Shape = Enum.PartType.Ball
			rp.Size = Vector3.one * 0.3
			rp.Position = c + dir * k
			rp.Color = WHITE
			rp.Material = Enum.Material.Neon
			rp.Anchored, rp.CanCollide, rp.CanQuery, rp.CanTouch, rp.CastShadow = true, false, false, false, false
			rp.Parent = workspace
			local big = math.max(1, dome.Size.Y * 0.35)
			TweenService:Create(rp, TweenInfo.new(0.3), {Size = Vector3.one * big, Transparency = 1}):Play()
			task.delay(0.35, function() rp:Destroy() end)
			char:SetAttribute("EnergyShieldRipples", (char:GetAttribute("EnergyShieldRipples") or 0) + 1)
		end
		local hl = char:FindFirstChild("EnergyShieldShell")
		if hl then
			local token = {}
			st.flashToken = token
			hl.OutlineColor = WHITE
			task.delay(0.12, function()
				if st.flashToken == token and hl.Parent then hl.OutlineColor = BLUE end
			end)
		end
	end)
	char:GetAttributeChangedSignal("EnergyShieldEnabled"):Connect(function()
		if char:GetAttribute("EnergyShieldEnabled") ~= true then finish(char, "disabled") end
		build(char)
	end)
	char:GetAttributeChangedSignal("PartsJammedAt"):Connect(function() finish(char, "jammed") end) -- v1.3
	char.ChildAdded:Connect(function(ch) -- v1.2: keep the shell the newest Highlight while the shield is up
		if not ch:IsA("Highlight") or ch.Name == "EnergyShieldShell" then return end
		if not st.active or domeStyle() then return end
		task.defer(function()
			if st.active and not domeStyle() then
				shell(char)
				char:SetAttribute("EnergyShieldShellRefreshes", (char:GetAttribute("EnergyShieldShellRefreshes") or 0) + 1)
			end
		end)
	end)
	local pl = Players:GetPlayerFromCharacter(char) -- v1.1: the emitters follow the step
	if pl then
		local conn = pl:GetAttributeChangedSignal("SkillPath_shield"):Connect(function()
			if char.Parent then build(char) end
		end)
		char.AncestryChanged:Connect(function(_, parent) if not parent then conn:Disconnect() end end)
	end
	char.AncestryChanged:Connect(function(_, parent)
		if not parent then clearFx(char) chars[char] = nil end -- v1.1: + clearFx (domes are outside the character)
	end)
	build(char)
end

script:GetAttributeChangedSignal("EnergyShieldEmitterStyle"):Connect(function() -- v1.2
	for char in pairs(chars) do build(char) end
end)
script:GetAttributeChangedSignal("EnergyShieldLookStyle"):Connect(function() -- v1.1
	for char in pairs(chars) do build(char) end
end)
script:GetAttributeChangedSignal("EnergyShieldServerEnabled"):Connect(function()
	for char in pairs(chars) do
		if not on() then finish(char, "disabled") end
		build(char)
	end
end)

local function onPlayer(player)
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then task.spawn(onCharacter, player.Character) end
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do onPlayer(p) end
