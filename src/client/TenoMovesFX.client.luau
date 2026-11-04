-- TenoMovesFX v1.5 (Mecha Dino Arena) — the client effects of the teno's mecha moves, build 1 (LocalScript in
-- StarterPlayerScripts; every client draws every teno). Plan docs/plans/TENO_ABILITIES_v1.0.md Task 7 (MDA-179), mockup
-- docs/mockups/teno_abilities_options.html v0.3 (rings, dust, heat glow, the catapult boulder leaving the bucket).
-- Reads TenoMovesServer 1.0's character stamps (the server also draws the boulders and rubble patches itself):
--   * Tail Grab: TenoGrabStartedAt + 0.3 s -> a white flash at the tail tip (Tail5_main * (-1.6 x scale, 0, 0));
--     TenoGrabLandAt -> a ring at TenoGrabLand, radius TenoGrabCrashRadius (6 when 0), plus dust.
--   * Boulder Mortar: TenoMortarFiredAt -> the TPart_tmortar "rock" piece hides (Transparency 1) and comes back after
--     ROCK_RELOAD (2.4) s; TenoMortarLandedAt -> a ring at TenoMortarLand, radius TenoMortarSplash, plus dust.
--   * Stomp Shockwave: TenoStompStartedAt -> the TPart_tstomp "heat" plates glow in over 0.5 s and fade out over 0.6 s
--     after the hit; TenoStompAt -> a ring at TenoStompCenter, radius TenoStompRange, plus dust.
--   * Hydraulic Leap: TenoLeapLandedAt -> a ring under the root, radius TenoLeapRadius, plus dust.
--   Ring: a flat Neon cylinder in Workspace.DinoFX_Local.TenoMovesFX growing from 2 studs to 2 x radius over RING_TIME
--   (0.5) s while fading out; dust: 10 grey puffs thrown out flat and fading over 0.8 s. Nothing collides or is queried.
-- Switch: script attribute TenoMovesFXEnabled (default true, read at each event; false = none of the above).
-- Diagnostics (LocalPlayer): TenoMovesFXVersion, TenoMovesFXEvents (count), TenoMovesFXLast (event name).
-- v1.1 (build 2, TenoMovesServer 1.3; mockup v0.3: green bellow rings, the Target Painter's red beams + reticles, the mud
--   coat; Kepu 2026-11-02 "Next"):
--   * Herd Bellow: TenoBellowAt -> a green ring (radius TenoBellowRange) at the teno and a green flash on each name in
--     TenoBellowTargets; each of them gets a green disc "TenoBellowAura" under it until its TenoBellowedUntil passes.
--   * Challenge Call: TenoChallengeAt -> one thin red beam "TenoPaintBeam" from the TPart_tchallenge "lens" (else
--     Torso_chest) to each name in TenoChallengeTargets (k-th one 0.15 x k s later, 0.9 s each) and a red disc
--     "TenoMarkReticle" under each until its TenoWeakUntil passes.
--   * Mud Armor: TenoMudStartedAt -> brown puffs around the teno for the 1.2 s wallow; TenoMudCoatAt -> "TenoMudCoat"
--     plates (3 on each of 13 body parts, two mud browns) that follow the body until TenoMudEndedAt or TenoMudUntil;
--     TenoMudBlockAt -> a brown flash at the root; TenoMudSplashAt -> a brown ring (radius TenoMudSplash) and puffs.
--   Followers (auras, reticles, plates) are anchored local parts moved every RenderStepped (nothing welded to a body).
--   Names resolve to player characters, then Workspace.DinoIsland.Bots children. Switch: script attribute
--   TenoMovesFXSupportEnabled (default true, read at each event; false = 1.0).
-- v1.2 (Kepu 2026-11-02 visual check, "fix all the failed ones"):
--   * Stomp: a shockwave ring you can see. TenoStompAt -> "TenoWave": 28 Neon blocks in a circle that grow from 2 studs to
--     TenoStompRange over 0.7 s and fade (heat orange), a second cream one 0.1 s later over 0.5 s, and 16 dust puffs
--     thrown out to 0.6 x range (1.0's flat disc ring and 10 puffs stay).
--   * Herd Bellow: TenoBellowAt -> three green waves (radius TenoBellowRange, 1.0 s each, 0.3 s apart) and, on each buffed
--     dino, a second larger aura disc "TenoBellowAura2" (11 studs, Transparency 0.4) until its TenoBellowedUntil.
--   * Mud Armor: the coat now shows. TenoMudCoatAt -> every visible body part of the teno (not mecha parts, not hitboxes)
--     is tinted locally 50% toward mud brown, and "TenoMudCoat2" plates (3 per coat part, 0.3 x scale thick) sit on the
--     face of each part that points up in the world. Both end at TenoMudEndedAt or TenoMudUntil; the tint puts the exact
--     colours back. (1.1's plates used the part's own Y face, which is a side or inside face on these parts.)
--   Switch: script attribute TenoMovesFXV12Enabled (default true, read at each event; false = 1.1).
-- v1.3 (Kepu 2026-11-02 16:43: "Change the mud armor to be a purple shield armor because the mud armor isn't doing enough
--   visuals" -> "Look only", look "B Energy Armor"): with the switch on, none of the mud visuals play (1.1 puffs, coat,
--   block flash, splash; 1.2 tint and plates). Instead:
--   * TenoMudStartedAt: a purple flash at the root and a 0.5 s purple wave to 8 studs.
--   * TenoMudCoatAt: "TenoShieldPlate" Neon purple shells (every visible body part over 2 cubic studs - not mecha parts,
--     hitboxes or the root - at its size x 1.12 + 0.25, Transparency 0.62) follow the body until TenoMudEndedAt or
--     TenoMudUntil. Each blocked hit (TenoMudBlockAt) flashes them to 0.2 for
--     0.25 s; their resting transparency rises 0.06 per blocked hit (fewer hits left = fainter).
--   * TenoMudEndedAt: a 0.4 s purple wave to 6 studs. TenoMudSplashAt (star): a 0.7 s purple wave to TenoMudSplash.
--   Switch: script attribute TenoMovesFXShieldEnabled (default true, read at each event; false = 1.2 mud look).
-- v1.4 (Kepu 2026-11-02 17:29: the mortar "needs to be beefed up" -> "Big wind-up + whip ... with launch dust and a flash
--   at the bucket"): on TenoMortarFiredAt, a white-hot flash (8 studs) at the catapult bucket's rock, dust around the teno's
--   root (spread 10) and a 0.4 s cream wave to 10 studs on the ground. Switch: script attribute TenoMovesFXMortarBigEnabled
--   (default true, read at each shot; false = 1.3).
-- v1.5 (MDA-217, plan docs/plans/TENO_TAIL_GRAB_v1.0.md; TenoMovesServer 1.7 Over-the-Top grab): the Tail Grab's white flash
--   at the tail tip comes at the catch, TenoGrabCatchAt (when it is newer than TenoGrabStartedAt), instead of 0.3 s after the
--   press. Switch: script attribute TenoMovesFXGrabCatchEnabled (default true, read at each grab; false = 1.4).
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local VERSION = "1.2"
VERSION = "1.3" -- v1.3 purple shield look
VERSION = "1.4" -- v1.4 mortar launch FX
VERSION = "1.5" -- v1.5 grab flash at the catch
if script:GetAttribute("TenoMovesFXGrabCatchEnabled") == nil then script:SetAttribute("TenoMovesFXGrabCatchEnabled", true) end -- v1.5
local RING_TIME, ROCK_RELOAD = 0.5, 2.4
local player = Players.LocalPlayer
player:SetAttribute("TenoMovesFXVersion", VERSION)
if script:GetAttribute("TenoMovesFXEnabled") == nil then script:SetAttribute("TenoMovesFXEnabled", true) end
local function on() return script:GetAttribute("TenoMovesFXEnabled") ~= false end
if script:GetAttribute("TenoMovesFXShieldEnabled") == nil then script:SetAttribute("TenoMovesFXShieldEnabled", true) end -- v1.3
local function shieldLook() return script:GetAttribute("TenoMovesFXShieldEnabled") ~= false end

local folder
local function fx()
	if folder and folder.Parent then return folder end
	local root = workspace:FindFirstChild("DinoFX_Local")
	if not root then
		root = Instance.new("Folder")
		root.Name = "DinoFX_Local"
		root.Parent = workspace
	end
	folder = root:FindFirstChild("TenoMovesFX") or Instance.new("Folder")
	folder.Name = "TenoMovesFX"
	folder.Parent = root
	return folder
end
local function part(name, shape, size, cf, color, transparency)
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.Neon
	p.Transparency = transparency or 0
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Parent = fx()
	return p
end
local function count(name)
	player:SetAttribute("TenoMovesFXEvents", (player:GetAttribute("TenoMovesFXEvents") or 0) + 1)
	player:SetAttribute("TenoMovesFXLast", name)
end
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
local function ground(pos)
	local ex = {fx()}
	for _, pl in ipairs(Players:GetPlayers()) do if pl.Character then table.insert(ex, pl.Character) end end
	rayParams.FilterDescendantsInstances = ex
	local g = workspace:Raycast(pos + Vector3.new(0, 20, 0), Vector3.new(0, -80, 0), rayParams)
	return g and g.Position or pos
end
local function ring(pos, radius, color)
	local at = ground(pos) + Vector3.new(0, 0.2, 0)
	local r = part("TenoRing", Enum.PartType.Cylinder, Vector3.new(0.3, 2, 2), CFrame.new(at) * CFrame.Angles(0, 0, math.rad(90)), color, 0.15)
	local d = math.max(2, radius * 2)
	TweenService:Create(r, TweenInfo.new(RING_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{Size = Vector3.new(0.3, d, d), Transparency = 1}):Play()
	task.delay(RING_TIME + 0.1, function() r:Destroy() end)
end
local function dust(pos, spread)
	local at = ground(pos)
	for i = 1, 10 do
		local a = i * 0.628 + math.random() * 0.4
		local s = 1.5 + math.random() * 1.5
		local p = part("TenoDust", Enum.PartType.Ball, Vector3.one * s, CFrame.new(at + Vector3.new(0, s / 2, 0)),
			Color3.fromRGB(205, 196, 176), 0.35)
		p.Material = Enum.Material.SmoothPlastic
		local to = at + Vector3.new(math.cos(a) * spread, s * 0.8, math.sin(a) * spread)
		TweenService:Create(p, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{CFrame = CFrame.new(to), Size = Vector3.one * s * 1.8, Transparency = 1}):Play()
		task.delay(0.9, function() p:Destroy() end)
	end
end
local function flash(pos, size)
	local p = part("TenoFlash", Enum.PartType.Ball, Vector3.one * size * 0.4, CFrame.new(pos), Color3.new(1, 1, 1), 0.15)
	TweenService:Create(p, TweenInfo.new(0.3), {Size = Vector3.one * size * 1.4, Transparency = 1}):Play()
	task.delay(0.35, function() p:Destroy() end)
end
local function roles(char, id, role)
	local out = {}
	local m = char:FindFirstChild("TPart_" .. id)
	if m then
		for _, d in ipairs(m:GetChildren()) do
			if d:IsA("BasePart") and d:GetAttribute("TPartRole") == role then table.insert(out, d) end
		end
	end
	return out
end
local function num(char, k, d) return tonumber(char:GetAttribute(k)) or d end
local function fresh(char, k) -- a stamp younger than 2 s
	local at = char:GetAttribute(k)
	return typeof(at) == "number" and math.abs(workspace:GetServerTimeNow() - at) < 2
end

-- v1.5: the grab flash waits for the catch (see the header)
local function grabFlashDelay(char)
	local st, ca = tonumber(char:GetAttribute("TenoGrabStartedAt")), tonumber(char:GetAttribute("TenoGrabCatchAt"))
	if script:GetAttribute("TenoMovesFXGrabCatchEnabled") == false or not st or not ca or ca <= st then return 0.3 end
	return math.clamp(ca - workspace:GetServerTimeNow(), 0, 2)
end
local function watch(char)
	char:GetAttributeChangedSignal("TenoGrabStartedAt"):Connect(function()
		if not on() or not fresh(char, "TenoGrabStartedAt") then return end
		task.delay(grabFlashDelay(char), function()
			local tip = char:FindFirstChild("Tail5_main", true)
			if tip and tip:IsA("BasePart") then
				flash((tip.CFrame * CFrame.new(-1.6 * char:GetScale(), 0, 0)).Position, 4)
				count("grab")
			end
		end)
	end)
	char:GetAttributeChangedSignal("TenoGrabLandAt"):Connect(function()
		local land = char:GetAttribute("TenoGrabLand")
		if not on() or not fresh(char, "TenoGrabLandAt") or typeof(land) ~= "Vector3" then return end
		local r = num(char, "TenoGrabCrashRadius", 0)
		ring(land, r > 0 and r or 6, Color3.fromRGB(255, 226, 160))
		dust(land, 8)
		count("grabLand")
	end)
	char:GetAttributeChangedSignal("TenoMortarFiredAt"):Connect(function()
		if not on() or not fresh(char, "TenoMortarFiredAt") then return end
		for _, rock in ipairs(roles(char, "tmortar", "rock")) do
			rock.Transparency = 1
			task.delay(ROCK_RELOAD, function() if rock.Parent then rock.Transparency = 0 end end)
		end
		count("mortarFire")
	end)
	char:GetAttributeChangedSignal("TenoMortarLandedAt"):Connect(function()
		local land = char:GetAttribute("TenoMortarLand")
		if not on() or not fresh(char, "TenoMortarLandedAt") or typeof(land) ~= "Vector3" then return end
		ring(land, num(char, "TenoMortarSplash", 10), Color3.fromRGB(255, 226, 160))
		dust(land, 10)
		count("mortarLand")
	end)
	char:GetAttributeChangedSignal("TenoStompStartedAt"):Connect(function()
		if not on() or not fresh(char, "TenoStompStartedAt") then return end
		for _, h in ipairs(roles(char, "tstomp", "heat")) do
			h.Transparency = 1
			local up = TweenService:Create(h, TweenInfo.new(0.5), {Transparency = 0})
			up.Completed:Connect(function()
				if h.Parent then TweenService:Create(h, TweenInfo.new(0.6), {Transparency = 1}):Play() end
			end)
			up:Play()
		end
		count("stompRear")
	end)
	char:GetAttributeChangedSignal("TenoStompAt"):Connect(function()
		local c = char:GetAttribute("TenoStompCenter")
		if not on() or not fresh(char, "TenoStompAt") or typeof(c) ~= "Vector3" then return end
		ring(c, num(char, "TenoStompRange", 14), Color3.fromRGB(255, 241, 200))
		dust(c, 12)
		count("stomp")
	end)
	char:GetAttributeChangedSignal("TenoLeapLandedAt"):Connect(function()
		local root = char:FindFirstChild("HumanoidRootPart")
		if not on() or not fresh(char, "TenoLeapLandedAt") or not root then return end
		ring(root.Position, num(char, "TenoLeapRadius", 12), Color3.fromRGB(255, 211, 77))
		dust(root.Position, 10)
		count("leapLand")
	end)
end
local function onPlayer(p)
	p.CharacterAdded:Connect(watch)
	if p.Character then watch(p.Character) end
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do onPlayer(p) end

-- v1.1: build-2 effects ---------------------------------------------------------------------------------------------------
local RunService = game:GetService("RunService")
if script:GetAttribute("TenoMovesFXSupportEnabled") == nil then script:SetAttribute("TenoMovesFXSupportEnabled", true) end
local function on2() return on() and script:GetAttribute("TenoMovesFXSupportEnabled") ~= false end
local GREEN, RED, MUD, MUD2 = Color3.fromRGB(95, 209, 106), Color3.fromRGB(255, 42, 42), Color3.fromRGB(91, 61, 34), Color3.fromRGB(122, 85, 48)
local function serverNow() return workspace:GetServerTimeNow() end
local function modelNamed(name)
	for _, pl in ipairs(Players:GetPlayers()) do
		if pl.Character and pl.Character.Name == name then return pl.Character end
	end
	local isl = workspace:FindFirstChild("DinoIsland")
	local bots = isl and isl:FindFirstChild("Bots")
	return bots and bots:FindFirstChild(name) or nil
end
local function namesOf(char, k)
	local out = {}
	local v = char:GetAttribute(k)
	if typeof(v) ~= "string" then return out end
	for n in string.gmatch(v, "[^|]+") do
		local m = modelNamed(n)
		if m then table.insert(out, m) end
	end
	return out
end
local followers = {} -- {part, step(part) -> keep}
RunService.RenderStepped:Connect(function()
	for i = #followers, 1, -1 do
		local f = followers[i]
		local okF, keep = pcall(f.step, f.part)
		if not okF or not keep or not f.part.Parent then
			f.part:Destroy()
			table.remove(followers, i)
		end
	end
end)
local function follow(part, step) table.insert(followers, {part = part, step = step}) end
local discRay = RaycastParams.new()
discRay.FilterType = Enum.RaycastFilterType.Exclude
local function groundUnder(m, pos) -- like ground(), but also skips the model itself (a bot is not a player character)
	local ex = {fx(), m}
	for _, pl in ipairs(Players:GetPlayers()) do if pl.Character then table.insert(ex, pl.Character) end end
	discRay.FilterDescendantsInstances = ex
	local g = workspace:Raycast(pos + Vector3.new(0, 2, 0), Vector3.new(0, -60, 0), discRay)
	return g and g.Position or pos
end
local function disc(m, name, color, untilKey, size)
	local d = part(name, Enum.PartType.Cylinder, Vector3.new(0.2, size, size), CFrame.new(0, -1000, 0), color, 0.55)
	follow(d, function(p)
		local r = m.Parent and m:FindFirstChild("HumanoidRootPart")
		local u = m:GetAttribute(untilKey)
		if not r or typeof(u) ~= "number" or serverNow() >= u then return false end
		local g = groundUnder(m, r.Position)
		p.CFrame = CFrame.new(g + Vector3.new(0, 0.25, 0)) * CFrame.Angles(0, os.clock() * 2, 0) * CFrame.Angles(0, 0, math.rad(90))
		return true
	end)
end
local function puff(pos, spread, color)
	local at = ground(pos)
	for i = 1, 6 do
		local a = i * 1.047 + math.random() * 0.5
		local sz = 1.2 + math.random()
		local p = part("TenoMudPuff", Enum.PartType.Ball, Vector3.one * sz, CFrame.new(at + Vector3.new(0, sz / 2, 0)), color, 0.3)
		p.Material = Enum.Material.SmoothPlastic
		TweenService:Create(p, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{CFrame = CFrame.new(at + Vector3.new(math.cos(a) * spread, sz, math.sin(a) * spread)), Size = Vector3.one * sz * 1.6, Transparency = 1}):Play()
		task.delay(0.8, function() p:Destroy() end)
	end
end
local COAT_PARTS = {"Torso_hips", "Torso_barrel", "Torso_chest", "Neck_base", "Neck_upper", "Tail1_main", "Tail2_main", "Tail3_main",
	"LegL_thigh", "LegR_thigh", "ArmL_upper", "ArmR_upper", "Head_cranium"}
local function watch2(char)
	char:GetAttributeChangedSignal("TenoBellowAt"):Connect(function()
		local root = char:FindFirstChild("HumanoidRootPart")
		if not on2() or not fresh(char, "TenoBellowAt") or not root then return end
		ring(root.Position, num(char, "TenoBellowRange", 25), GREEN)
		for _, m in ipairs(namesOf(char, "TenoBellowTargets")) do
			local r = m:FindFirstChild("HumanoidRootPart")
			if r then
				flash(r.Position, 5)
				disc(m, "TenoBellowAura", GREEN, "TenoBellowedUntil", 7)
			end
		end
		count("bellow")
	end)
	char:GetAttributeChangedSignal("TenoChallengeAt"):Connect(function()
		if not on2() or not fresh(char, "TenoChallengeAt") then return end
		local lens = roles(char, "tchallenge", "lens")[1] or char:FindFirstChild("Torso_chest", true)
		for k, m in ipairs(namesOf(char, "TenoChallengeTargets")) do
			disc(m, "TenoMarkReticle", RED, "TenoWeakUntil", 7)
			task.delay(0.15 * (k - 1), function()
				local b = part("TenoPaintBeam", Enum.PartType.Block, Vector3.new(0.25, 0.25, 1), CFrame.new(0, -1000, 0), RED, 0.1)
				local t0 = os.clock()
				follow(b, function(p)
					local r = m.Parent and m:FindFirstChild("HumanoidRootPart")
					if not r or not lens or not lens.Parent or os.clock() - t0 > 0.9 then return false end
					local a, z = lens.Position, r.Position + Vector3.new(0, 2, 0)
					local len = (z - a).Magnitude
					p.Size = Vector3.new(0.25, 0.25, math.max(0.1, len))
					p.CFrame = CFrame.lookAt((a + z) / 2, z)
					return true
				end)
			end)
		end
		count("challenge")
	end)
	char:GetAttributeChangedSignal("TenoMudStartedAt"):Connect(function()
		if shieldLook() or not on2() or not fresh(char, "TenoMudStartedAt") then return end
		task.spawn(function()
			for _ = 1, 6 do
				local root = char:FindFirstChild("HumanoidRootPart")
				if not root then break end
				puff(root.Position + Vector3.new((math.random() - 0.5) * 8, 0, (math.random() - 0.5) * 10), 4, MUD2)
				task.wait(0.2)
			end
		end)
		count("mudWallow")
	end)
	char:GetAttributeChangedSignal("TenoMudCoatAt"):Connect(function()
		if shieldLook() or not on2() or not fresh(char, "TenoMudCoatAt") then return end
		local coatAt = char:GetAttribute("TenoMudCoatAt")
		for _, n in ipairs(COAT_PARTS) do
			local bp = char:FindFirstChild(n, true)
			if bp and bp:IsA("BasePart") then
				for i = 1, 3 do
					local sz = Vector3.new(bp.Size.X * (0.3 + math.random() * 0.3), 0.12, bp.Size.Z * (0.4 + math.random() * 0.3))
					local off = CFrame.new((math.random() - 0.5) * bp.Size.X * 0.6, bp.Size.Y / 2 + 0.03, (math.random() - 0.5) * bp.Size.Z * 0.4)
					local c = part("TenoMudCoat", Enum.PartType.Block, sz, bp.CFrame * off, i % 2 == 1 and MUD or MUD2, 0)
					c.Material = Enum.Material.Slate
					follow(c, function(p)
						if not bp.Parent or not char.Parent then return false end
						local ended = char:GetAttribute("TenoMudEndedAt")
						local u = char:GetAttribute("TenoMudUntil")
						if typeof(ended) == "number" and ended >= coatAt then return false end
						if typeof(u) == "number" and serverNow() >= u then return false end
						p.CFrame = bp.CFrame * off
						return true
					end)
				end
			end
		end
		count("mudCoat")
	end)
	char:GetAttributeChangedSignal("TenoMudBlockAt"):Connect(function()
		local root = char:FindFirstChild("HumanoidRootPart")
		if shieldLook() or not on2() or not fresh(char, "TenoMudBlockAt") or not root then return end
		flash(root.Position + Vector3.new(0, 2, 0), 6)
		puff(root.Position, 5, MUD2)
		count("mudBlock")
	end)
	char:GetAttributeChangedSignal("TenoMudSplashAt"):Connect(function()
		local root = char:FindFirstChild("HumanoidRootPart")
		if shieldLook() or not on2() or not fresh(char, "TenoMudSplashAt") or not root then return end
		ring(root.Position, num(char, "TenoMudSplash", 12), MUD2)
		puff(root.Position, 12, MUD2)
		count("mudSplash")
	end)
end
local function onPlayer2(p)
	p.CharacterAdded:Connect(watch2)
	if p.Character then watch2(p.Character) end
end
Players.PlayerAdded:Connect(onPlayer2)
for _, p in ipairs(Players:GetPlayers()) do onPlayer2(p) end

-- v1.2: stomp shockwave, bellow waves, visible mud coat ------------------------------------------------------------------
if script:GetAttribute("TenoMovesFXV12Enabled") == nil then script:SetAttribute("TenoMovesFXV12Enabled", true) end
local function on3() return on() and script:GetAttribute("TenoMovesFXV12Enabled") ~= false end
local HEAT, CREAM = Color3.fromRGB(255, 120, 30), Color3.fromRGB(255, 241, 200)
local function wave(pos, radius, color, time, segs)
	local at = ground(pos) + Vector3.new(0, 0.6, 0)
	local t0 = os.clock()
	for i = 1, segs do
		local a = (i / segs) * math.pi * 2
		local seg = part("TenoWave", Enum.PartType.Block, Vector3.new(1.2, 1, 0.5), CFrame.new(at), color, 0.1)
		follow(seg, function(p)
			local u = (os.clock() - t0) / time
			if u >= 1 then return false end
			local e = 1 - (1 - u) ^ 2
			local r = 2 + (math.max(2, radius) - 2) * e
			local w = math.max(1.2, 2 * math.pi * r / segs * 0.8)
			p.Size = Vector3.new(w, 1.2 * (1 - u) + 0.3, 0.6)
			p.CFrame = CFrame.new(at + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)) * CFrame.Angles(0, -a + math.pi / 2, 0)
			p.Transparency = 0.1 + 0.9 * u
			return true
		end)
	end
end
local tinted = {} -- [char] = {coatAt, colors = {[part] = Color3}}
local function untint(char)
	local tn = tinted[char]
	if not tn then return end
	for bp, col in pairs(tn.colors) do if bp.Parent then bp.Color = col end end
	tinted[char] = nil
end
RunService.Heartbeat:Connect(function()
	for char, tn in pairs(tinted) do
		local ended = char:GetAttribute("TenoMudEndedAt")
		local u = char:GetAttribute("TenoMudUntil")
		if not char.Parent or (typeof(ended) == "number" and ended >= tn.coatAt) or (typeof(u) == "number" and serverNow() >= u) then untint(char) end
	end
end)
local function upFace(bp)
	local best, axis, half = -2, Vector3.yAxis, bp.Size.Y / 2
	for _, d in ipairs({{bp.CFrame.UpVector, Vector3.yAxis, bp.Size.Y}, {-bp.CFrame.UpVector, -Vector3.yAxis, bp.Size.Y},
		{bp.CFrame.RightVector, Vector3.xAxis, bp.Size.X}, {-bp.CFrame.RightVector, -Vector3.xAxis, bp.Size.X},
		{-bp.CFrame.LookVector, Vector3.zAxis, bp.Size.Z}, {bp.CFrame.LookVector, -Vector3.zAxis, bp.Size.Z}}) do
		local dot = d[1]:Dot(Vector3.yAxis)
		if dot > best then best, axis, half = dot, d[2], d[3] / 2 end
	end
	return axis, half
end
local function watch3(char)
	char:GetAttributeChangedSignal("TenoStompAt"):Connect(function()
		local c = char:GetAttribute("TenoStompCenter")
		if not on3() or not fresh(char, "TenoStompAt") or typeof(c) ~= "Vector3" then return end
		local r = num(char, "TenoStompRange", 14)
		wave(c, r, HEAT, 0.7, 28)
		task.delay(0.1, function() wave(c, r * 0.85, CREAM, 0.5, 22) end)
		for _ = 1, 2 do puff(c + Vector3.new((math.random() - 0.5) * 4, 0, (math.random() - 0.5) * 4), r * 0.6, Color3.fromRGB(205, 196, 176)) end
		puff(c, r * 0.35, Color3.fromRGB(205, 196, 176))
		count("stompWave")
	end)
	char:GetAttributeChangedSignal("TenoBellowAt"):Connect(function()
		local root = char:FindFirstChild("HumanoidRootPart")
		if not on3() or not fresh(char, "TenoBellowAt") or not root then return end
		local r = num(char, "TenoBellowRange", 25)
		for k = 0, 2 do
			task.delay(k * 0.3, function()
				local rr = char:FindFirstChild("HumanoidRootPart")
				if rr then wave(rr.Position, r, GREEN, 1.0, 32) end
			end)
		end
		for _, m in ipairs(namesOf(char, "TenoBellowTargets")) do disc(m, "TenoBellowAura2", GREEN, "TenoBellowedUntil", 11) end
		count("bellowWave")
	end)
	char:GetAttributeChangedSignal("TenoMudCoatAt"):Connect(function()
		if shieldLook() or not on3() or not fresh(char, "TenoMudCoatAt") then return end
		local coatAt = char:GetAttribute("TenoMudCoatAt")
		untint(char)
		local tn = {coatAt = coatAt, colors = {}}
		for _, bp in ipairs(char:GetDescendants()) do
			if bp:IsA("BasePart") and bp.Name ~= "HumanoidRootPart" and bp.Transparency < 1 and not bp:FindFirstAncestor("Hitboxes")
				and not (bp.Parent and bp.Parent.Name:find("^TPart_")) then
				tn.colors[bp] = bp.Color
				bp.Color = bp.Color:Lerp(MUD, 0.5)
			end
		end
		tinted[char] = tn
		local sc = char:GetScale()
		for _, n in ipairs(COAT_PARTS) do
			local bp = char:FindFirstChild(n, true)
			if bp and bp:IsA("BasePart") then
				local axis, half = upFace(bp)
				for i = 1, 3 do
					local th = 0.3 * sc
					local a1 = (axis.X ~= 0) and Vector3.yAxis or Vector3.xAxis
					local a2 = axis:Cross(a1)
					local span1 = math.abs(a1.X) * bp.Size.X + math.abs(a1.Y) * bp.Size.Y + math.abs(a1.Z) * bp.Size.Z
					local span2 = math.abs(a2.X) * bp.Size.X + math.abs(a2.Y) * bp.Size.Y + math.abs(a2.Z) * bp.Size.Z
					local w1, w2 = span1 * (0.35 + math.random() * 0.3), span2 * (0.45 + math.random() * 0.3)
					local o1, o2 = (math.random() - 0.5) * (span1 - w1), (math.random() - 0.5) * (span2 - w2)
					local off = CFrame.fromMatrix(axis * (half + th / 2 - 0.02 * sc) + a1 * o1 + a2 * o2, a1, axis)
					local c = part("TenoMudCoat2", Enum.PartType.Block, Vector3.new(w1, th, w2), bp.CFrame * off, i % 2 == 1 and MUD or MUD2, 0)
					c.Material = Enum.Material.Slate
					follow(c, function(p)
						if not bp.Parent or not char.Parent then return false end
						local ended = char:GetAttribute("TenoMudEndedAt")
						local u = char:GetAttribute("TenoMudUntil")
						if typeof(ended) == "number" and ended >= coatAt then return false end
						if typeof(u) == "number" and serverNow() >= u then return false end
						p.CFrame = bp.CFrame * off
						return true
					end)
				end
			end
		end
		count("mudCoat2")
	end)
end
local function onPlayer3(p)
	p.CharacterAdded:Connect(watch3)
	if p.Character then watch3(p.Character) end
end
Players.PlayerAdded:Connect(onPlayer3)
for _, p in ipairs(Players:GetPlayers()) do onPlayer3(p) end

-- v1.3: the purple Shield Armor look (see the header) ------------------------------------------------------------------------
local PURPLE, LILAC = Color3.fromRGB(150, 70, 255), Color3.fromRGB(205, 160, 255)
local function on4() return on() and shieldLook() end
local shells = {} -- [char] = {coatAt, plates = {parts}, flashUntil}
local function shellAlpha(char, sh)
	if os.clock() < (sh.flashUntil or 0) then return 0.2 end
	local used = math.max(0, num(char, "TenoMudHits", 0) - num(char, "TenoMudHitsLeft", 0))
	return math.min(0.9, 0.62 + 0.06 * used)
end
local function watch4(char)
	char:GetAttributeChangedSignal("TenoMudStartedAt"):Connect(function()
		local root = char:FindFirstChild("HumanoidRootPart")
		if not on4() or not fresh(char, "TenoMudStartedAt") or not root then return end
		local f = part("TenoShieldFlash", Enum.PartType.Ball, Vector3.one * 3, CFrame.new(root.Position), LILAC, 0.2)
		TweenService:Create(f, TweenInfo.new(0.4), {Size = Vector3.one * 12, Transparency = 1}):Play()
		task.delay(0.45, function() f:Destroy() end)
		wave(root.Position, 8, PURPLE, 0.5, 20)
		count("shieldStart")
	end)
	char:GetAttributeChangedSignal("TenoMudCoatAt"):Connect(function()
		if not on4() or not fresh(char, "TenoMudCoatAt") then return end
		local coatAt = char:GetAttribute("TenoMudCoatAt")
		local sh = {coatAt = coatAt, plates = {}}
		shells[char] = sh
		for _, bp in ipairs(char:GetDescendants()) do
			if bp:IsA("BasePart") and bp.Name ~= "HumanoidRootPart" and bp.Transparency < 1 and not bp:FindFirstAncestor("Hitboxes")
				and not (bp.Parent and bp.Parent.Name:find("^TPart_")) and bp.Size.X * bp.Size.Y * bp.Size.Z > 2 then
				local c = part("TenoShieldPlate", Enum.PartType.Block, bp.Size * 1.12 + Vector3.new(0.25, 0.25, 0.25), bp.CFrame, PURPLE, 0.62)
				table.insert(sh.plates, c)
				follow(c, function(p)
					if not bp.Parent or not char.Parent or shells[char] ~= sh then return false end
					local ended = char:GetAttribute("TenoMudEndedAt")
					local u = char:GetAttribute("TenoMudUntil")
					if typeof(ended) == "number" and ended >= coatAt then return false end
					if typeof(u) == "number" and serverNow() >= u then return false end
					p.CFrame = bp.CFrame
					p.Transparency = shellAlpha(char, sh)
					return true
				end)
			end
		end
		count("shieldCoat")
	end)
	char:GetAttributeChangedSignal("TenoMudBlockAt"):Connect(function()
		if not on4() or not fresh(char, "TenoMudBlockAt") then return end
		local sh = shells[char]
		if sh then sh.flashUntil = os.clock() + 0.25 end
		local root = char:FindFirstChild("HumanoidRootPart")
		if root then flash(root.Position, 6) end
		count("shieldBlock")
	end)
	char:GetAttributeChangedSignal("TenoMudEndedAt"):Connect(function()
		local root = char:FindFirstChild("HumanoidRootPart")
		if not on4() or not fresh(char, "TenoMudEndedAt") or not root then return end
		wave(root.Position, 6, PURPLE, 0.4, 18)
		count("shieldEnd")
	end)
	char:GetAttributeChangedSignal("TenoMudSplashAt"):Connect(function()
		local root = char:FindFirstChild("HumanoidRootPart")
		if not on4() or not fresh(char, "TenoMudSplashAt") or not root then return end
		wave(root.Position, num(char, "TenoMudSplash", 12), PURPLE, 0.7, 28)
		count("shieldBurst")
	end)
end
local function onPlayer4(p)
	p.CharacterAdded:Connect(watch4)
	if p.Character then watch4(p.Character) end
end
Players.PlayerAdded:Connect(onPlayer4)
for _, p in ipairs(Players:GetPlayers()) do onPlayer4(p) end

-- v1.4: mortar launch FX (see the header) ------------------------------------------------------------------------------------
if script:GetAttribute("TenoMovesFXMortarBigEnabled") == nil then script:SetAttribute("TenoMovesFXMortarBigEnabled", true) end
local function watch5(char)
	char:GetAttributeChangedSignal("TenoMortarFiredAt"):Connect(function()
		local root = char:FindFirstChild("HumanoidRootPart")
		if not on() or script:GetAttribute("TenoMovesFXMortarBigEnabled") == false or not fresh(char, "TenoMortarFiredAt") or not root then return end
		local rock = roles(char, "tmortar", "rock")[1]
		local at = rock and rock.Position or (root.Position + Vector3.new(0, 6, 0))
		local f = part("TenoMortarFlash", Enum.PartType.Ball, Vector3.one * 2, CFrame.new(at), Color3.fromRGB(255, 244, 214), 0.05)
		TweenService:Create(f, TweenInfo.new(0.3), {Size = Vector3.one * 8, Transparency = 1}):Play()
		task.delay(0.35, function() f:Destroy() end)
		dust(root.Position, 10)
		wave(root.Position, 10, CREAM, 0.4, 20)
		count("mortarLaunch")
	end)
end
local function onPlayer5(p)
	p.CharacterAdded:Connect(watch5)
	if p.Character then watch5(p.Character) end
end
Players.PlayerAdded:Connect(onPlayer5)
for _, p in ipairs(Players:GetPlayers()) do onPlayer5(p) end
