-- InkServer v1.4 (Mecha Dino Arena) — the pachy's Ink Shooter, an Engineering slot part (path "ink").
-- MDA-128, plan docs/plans/PACHY_PARTS_B3_v1.0.md, mockup docs/mockups/pachy_parts_b3_options.html look A "Neck ink tank +
--   barrel". Kepu 2026-10-30: "How about an ink shooter that blinds your enemy for 2 seconds. Turns their screen black";
--   answers: fully black (HUD stays), an aimed shot like the Grappling Hook (first dino hit), bots lose you, steps II 80
--   studs / III 11 s / star splash 6 studs, "Same as Shock Cannon" for who can be inked (ModeRules).
-- Settings come from the character (SkillEffects 1.24): InkEnabled (bought AND slotted on a pachy), InkRange (60; 80 from
--   II), InkCooldown (15; 11 from III), InkBlindTime (2), InkSplash (6 at star, else 0), InkLook.
-- Client -> server: ReplicatedStorage.DinoInkRequest:FireServer(clientServerTime, aimDir) (MechaButtons 1.19 sends the
--   camera LookVector). Checks, first failing wins: "badArg" (stamp not a number, aimDir not a Vector3 of length 0.5-1.5),
--   "dead", "disabled" (InkServerEnabled false or InkEnabled ~= true), "menu", "stunned" (StunnedUntil > now), "pinned"
--   (PinHeld), "cooldown" (now < InkReadyAt), "ok". Every ok shot starts the cooldown: InkReadyAt = now + InkCooldown.
-- The shot (the Grappling Hook's aim rules, HookServer 1.5): heading from the camera, pitch clamped to -2..25 degrees;
--   origin = the barrel's muzzle (else the head hitbox, else the root). Along the aim, up to InkRange studs, the first dino
--   (Workspace models with a Hitboxes folder, Bitable true, a Species or IsBot, not self, not KO, alive) whose hitbox comes
--   within AIM_HELP (4) x scale studs of the line, and which ModeRules.canAffect allows (player target: not in the menu,
--   and only in the Arena; bots always), is the target. The world (every character / bot / tall grass excluded) blocks:
--   a world hit nearer, or a wall between the muzzle and the target = "blocked". A target with EnergyShieldUntil in the
--   future = "shielded" (the glob splats on it, no blind). Nothing found = "miss".
--   Owner stamps: InkAimDir, InkAimEnd, InkResult ("hit" / "miss" / "blocked" / "shielded"), InkHitTarget (or ""),
--   InkArriveAt, InkCount, InkStartedAt (last).
-- Flight: a black glob (Part "InkGlob", ball, anchored, Workspace.DinoFX "InkFX" folder) flies from the muzzle to the
--   end at INK_SPEED (160) studs/s; at the end a black splat (flat cylinder, fades in 1.5 s) and a burst of black drops.
-- Blind (at arrival): the target's InkedUntil = max(current, arrival + InkBlindTime), InkedBy (pachy name), InkedAt
--   (server time, last). A player's own client (InkBlind 1.0) shows a fully black screen under the HUD while InkedUntil
--   is in the future; a bot (BotServer 1.18) drops its player target and picks none while inked.
-- Star (InkSplash > 0): every other allowed, unshielded dino (not the shooter) whose hitbox is within InkSplash studs of
--   the hit point is inked the same way (also on a "shielded" main hit). Owner InkSplashCount (the last shot).
-- Look: while InkLook is true the pachy carries "Mecha_InkTank" on the Neck segment's Root (its box in Root's own frame):
--   "Tank" (dark, on top of the neck), "Window" (black ink behind glass on its side), "Cap" (steel) and "Barrel" (steel,
--   forward along the neck toward the jaw) with an Attachment "Muzzle" at the tip. Massless, no collide / query / touch.
-- Lab card (plug and play, LabPreviewServer 1.2): BindableFunction "BuildPreview_ink".
-- Switch: script attribute InkServerEnabled (default true). Mode rules: script attribute InkModeRulesEnabled (default
--   true; false = players can always be inked).
-- Diagnostics: script InkServerVersion, InkShots, InkHits, InkMode; character InkServerResult, InkLookBuilt.
-- v1.1 (Kepu 2026-10-30: "The visor should block ink"): at arrival, a dino whose Dome Visor is up and faces the ink
--   (BoneCrest 1.2 visorFront; main target: from the muzzle position at the shot; splash: from the hit point) is not
--   inked: BoneCrest.visorBlock(dino, shooter, "ink") runs (BLOCK look; star knockback). A blocked main hit sets the
--   shooter's InkResult to "visor" (and is not counted in InkHits); blocked splash dinos are left out of InkSplashCount.
--   Shooter diagnostic InkVisorBlocks (count). Switch: script attribute InkVisorEnabled (default true, read at each
--   arrival; false = 1.0).
-- v1.2 (Kepu 2026-10-30: "For the ink shooter just mount it on its stomach"): with script attribute InkBellyMount (default
--   true, read at each build; false = 1.1 neck mount) "Mecha_InkTank" is welded to the Torso segment's Root instead, under
--   the front of the belly: "Tank" lying lengthwise (Hd x 0.10 wide, 0.08 tall, 0.16 long) just below the belly, "Window"
--   (ink behind glass) along its sides, "Cap" (steel) on its back end and "Barrel" (steel, Hd x 0.14) pointing forward
--   from its front end, with the Attachment "Muzzle" at the tip (the shot starts there). Same part names as 1.1.
-- v1.3 (Kepu 2026-10-30: "I wanted it on the shoulder also the ink animation itself doesn't tell me anything as a user. It
--   should visibly splash the Dino and make them drip black on their face for a moment from my end. Or maybe just do a
--   splash on them and say blinded so I can see that"):
--   * Mount: with script attribute InkShoulderMount (default true, read at each build; false = 1.2 / 1.1 by InkBellyMount)
--     "Mecha_InkTank" sits on the pachy's LEFT shoulder (the Grappling Hook is on the right arm): on top of the Torso
--     segment's Root box, its front part, left side: "Tank" upright (Hd x 0.08 wide, 0.10 tall, 0.08 deep), "Window"
--     (ink behind glass), "Cap" (steel, on top), "Barrel" (steel, Hd x 0.12) pointing forward from its front face with the
--     Attachment "Muzzle" at the tip. Same part names as before. With the shoulder mount the aim may tilt down to
--     PITCH_MIN_SHOULDER (-20 degrees; was -2, the hook's limit) so a shot from the high shoulder can reach a raptor.
--   * Inked look (every dino that gets inked, seen by everyone; script attribute InkHitLookEnabled, default true, read at
--     each ink): on its head (Head segment Root, else a Head hitbox, else the root) an Attachment "InkHit" with a
--     ParticleEmitter "InkSplash" (black blobs thrown out all round, Emit 40) and "InkDrip" (black drops running down,
--     falling, Rate 30) that drips for the whole blind time, plus a BillboardGui "InkBlindedTag" above the head reading
--     "BLINDED" (white Fredoka, black outline, on a black ink-blot backing) that pops in, stays while InkedUntil is in the
--     future and fades out. A new ink on a dino that is still inked restarts it. Removed 0.6 s after the ink wears off.
--     On a "hit" / "shielded" shot the flat InkSplat disc is hidden (it hung in the air at the hit point); its drops
--     still burst there. Misses / blocked shots keep the disc.
-- v1.4 (Kepu 2026-10-30: "the ink shooter needs some aim assistance" -> "Snap to nearby dino"): with script attribute
--   InkAimAssistEnabled (default true, read each shot) the shot is turned toward the closest dino within InkAimAssistDeg
--   (script attribute, default 12) degrees of the aim (after the pitch clamp): of the allowed targets (same as the hit
--   search: ModeRules, not KO, alive), every hitbox part within InkRange of the muzzle with a clear line from the muzzle
--   (world only) is scored by its angle from the aim; the smallest wins and the shot flies straight at that part (no pitch
--   clamp on the snapped direction). No candidate within the angle = the aim as sent (1.3). The normal hit search then
--   runs along the new direction. Diagnostics: character InkAssisted (true / false, the last shot), InkAssistDeg (angle
--   snapped, whole degrees; 0 when not snapped).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local VERSION = "1.4"
local PITCH_MIN, PITCH_MAX = math.rad(-2), math.rad(25)
local PITCH_MIN_SHOULDER = math.rad(-20) -- v1.3: the shoulder muzzle sits high, so the shot may aim down to the ground ahead
local AIM_HELP = 4
local INK_SPEED = 160
local INK = Color3.fromRGB(11, 11, 18)
local STEEL, DARK = Color3.fromRGB(154, 166, 184), Color3.fromRGB(42, 45, 56)

script:SetAttribute("InkServerVersion", VERSION)
script:SetAttribute("InkShots", 0)
script:SetAttribute("InkHits", 0)
if script:GetAttribute("InkServerEnabled") == nil then script:SetAttribute("InkServerEnabled", true) end
if script:GetAttribute("InkModeRulesEnabled") == nil then script:SetAttribute("InkModeRulesEnabled", true) end
if script:GetAttribute("InkVisorEnabled") == nil then script:SetAttribute("InkVisorEnabled", true) end -- v1.1
if script:GetAttribute("InkBellyMount") == nil then script:SetAttribute("InkBellyMount", true) end -- v1.2
if script:GetAttribute("InkShoulderMount") == nil then script:SetAttribute("InkShoulderMount", true) end -- v1.3
if script:GetAttribute("InkHitLookEnabled") == nil then script:SetAttribute("InkHitLookEnabled", true) end -- v1.3
if script:GetAttribute("InkAimAssistEnabled") == nil then script:SetAttribute("InkAimAssistEnabled", true) end -- v1.4
if script:GetAttribute("InkAimAssistDeg") == nil then script:SetAttribute("InkAimAssistDeg", 12) end -- v1.4
local visorModCache -- v1.1: Dome Visor (ServerStorage.DinoArcade.BoneCrest 1.2), loaded on first use
local function visorMod()
	if visorModCache == nil then
		visorModCache = false
		pcall(function() visorModCache = require(game:GetService("ServerStorage"):WaitForChild("DinoArcade", 5):WaitForChild("BoneCrest", 5)) end)
	end
	return visorModCache or nil
end
-- v1.1: true (and the block handled) when the dino's visor faces fromPos
local function visorBlocks(dino, shooter, fromPos)
	if script:GetAttribute("InkVisorEnabled") == false then return false end
	local VM = visorMod()
	if not (VM and VM.visorFront(dino, fromPos)) then return false end
	VM.visorBlock(dino, shooter, "ink")
	if shooter.Parent then shooter:SetAttribute("InkVisorBlocks", (shooter:GetAttribute("InkVisorBlocks") or 0) + 1) end
	return true
end
local function enabled() return script:GetAttribute("InkServerEnabled") ~= false end

local ModeRules = require(game:GetService("ServerStorage"):WaitForChild("DinoArcade"):WaitForChild("ModeRules"))
local MODE = ModeRules.currentMode()
script:SetAttribute("InkMode", MODE)
local function mayAffect(source, target)
	if script:GetAttribute("InkModeRulesEnabled") == false then return true end
	local tpl = Players:GetPlayerFromCharacter(target)
	local spl = Players:GetPlayerFromCharacter(source)
	local inMenu = tpl ~= nil and tpl:GetAttribute("InMenu") == true
	return ModeRules.canAffect(spl ~= nil, tpl ~= nil, inMenu, MODE)
end

local remote = ReplicatedStorage:FindFirstChild("DinoInkRequest")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "DinoInkRequest"
	remote.Parent = ReplicatedStorage
end

local function now() return workspace:GetServerTimeNow() end

local function fxFolder()
	local fx = workspace:FindFirstChild("DinoFX")
	if not fx then
		fx = Instance.new("Folder")
		fx.Name = "DinoFX"
		fx.Parent = workspace
	end
	local f = fx:FindFirstChild("InkFX")
	if not f then
		f = Instance.new("Folder")
		f.Name = "InkFX"
		f.Parent = fx
	end
	return f
end

-- look ---------------------------------------------------------------------------------------------------------------
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

-- v1.2: the tank under the belly, the barrel pointing forward
local function buildBelly(char)
	local seg = char:FindFirstChild("Torso")
	local root = seg and seg:FindFirstChild("Root")
	if not (root and root:IsA("BasePart")) then return nil end
	local lo, hi = rootBox(seg, root)
	if not lo then return nil end
	local ref = char:FindFirstChild("HumanoidRootPart") or root
	local x = axisOf(root, ref.CFrame.RightVector)
	local y = axisOf(root, ref.CFrame.UpVector)
	if math.abs(x:Dot(y)) > 0.5 then y = axisOf(root, ref.CFrame.LookVector):Cross(x) end
	local back = x:Cross(y)
	local Hd = char:GetExtentsSize().Y
	local w, h, d = Hd * 0.10, Hd * 0.08, Hd * 0.16
	local c = (lo + hi) / 2 - y * (extent(lo, hi, y) + h * 0.45) - back * (extent(lo, hi, back) * 0.3)
	local cf = root.CFrame * CFrame.fromMatrix(c, x, y, back) -- local -Z = forward
	local m = Instance.new("Model")
	m.Name = "Mecha_InkTank"
	local tank = part("Tank", Vector3.new(w, h, d), cf, DARK, m, root)
	part("Window", Vector3.new(w * 1.04, h * 0.5, d * 0.6), cf * CFrame.new(0, -h * 0.05, 0), INK, m, tank, Enum.Material.Glass)
	part("Cap", Vector3.new(w * 0.7, h * 0.7, d * 0.08), cf * CFrame.new(0, 0, d * 0.54), STEEL, m, tank)
	local len = Hd * 0.14
	local bcf = cf * CFrame.new(0, 0, -(d * 0.5 + len * 0.5))
	local barrel = part("Barrel", Vector3.new(w * 0.3, w * 0.3, len), bcf, STEEL, m, tank)
	local mz = Instance.new("Attachment")
	mz.Name = "Muzzle"
	mz.Position = Vector3.new(0, 0, -len * 0.5)
	mz.Parent = barrel
	m.Parent = char
	char:SetAttribute("InkLookBuilt", true)
	return m
end

-- v1.3: the tank on the left shoulder, the barrel pointing forward
local function buildShoulder(char)
	local seg = char:FindFirstChild("Torso")
	local root = seg and seg:FindFirstChild("Root")
	if not (root and root:IsA("BasePart")) then return nil end
	local lo, hi = rootBox(seg, root)
	if not lo then return nil end
	local ref = char:FindFirstChild("HumanoidRootPart") or root
	local x = axisOf(root, ref.CFrame.RightVector)
	local y = axisOf(root, ref.CFrame.UpVector)
	if math.abs(x:Dot(y)) > 0.5 then y = axisOf(root, ref.CFrame.LookVector):Cross(x) end
	local back = x:Cross(y)
	local Hd = char:GetExtentsSize().Y
	local w, h, d = Hd * 0.08, Hd * 0.10, Hd * 0.08
	local c = (lo + hi) / 2 + y * (extent(lo, hi, y) + h * 0.45) - back * (extent(lo, hi, back) * 0.55)
		- x * (extent(lo, hi, x) * 0.55) -- -x = the dino's left
	local cf = root.CFrame * CFrame.fromMatrix(c, x, y, back) -- local -Z = forward
	local m = Instance.new("Model")
	m.Name = "Mecha_InkTank"
	local tank = part("Tank", Vector3.new(w, h, d), cf, DARK, m, root)
	part("Window", Vector3.new(w * 1.04, h * 0.55, d * 0.5), cf * CFrame.new(0, -h * 0.05, 0), INK, m, tank, Enum.Material.Glass)
	part("Cap", Vector3.new(w * 0.7, h * 0.1, d * 0.7), cf * CFrame.new(0, h * 0.55, 0), STEEL, m, tank)
	local len = Hd * 0.12
	local bcf = cf * CFrame.new(0, h * 0.1, -(d * 0.5 + len * 0.5))
	local barrel = part("Barrel", Vector3.new(w * 0.32, w * 0.32, len), bcf, STEEL, m, tank)
	local mz = Instance.new("Attachment")
	mz.Name = "Muzzle"
	mz.Position = Vector3.new(0, 0, -len * 0.5)
	mz.Parent = barrel
	m.Parent = char
	char:SetAttribute("InkLookBuilt", true)
	return m
end

local function build(char)
	if script:GetAttribute("InkShoulderMount") ~= false then return buildShoulder(char) end -- v1.3
	if script:GetAttribute("InkBellyMount") ~= false then return buildBelly(char) end -- v1.2
	local seg = char:FindFirstChild("Neck")
	local root = seg and seg:FindFirstChild("Root")
	if not (root and root:IsA("BasePart")) then return nil end
	local lo, hi = rootBox(seg, root)
	if not lo then return nil end
	local ref = char:FindFirstChild("HumanoidRootPart") or root
	local x = axisOf(root, ref.CFrame.RightVector)
	local y = axisOf(root, ref.CFrame.UpVector)
	if math.abs(x:Dot(y)) > 0.5 then y = axisOf(root, ref.CFrame.LookVector):Cross(x) end
	local back = x:Cross(y)
	local Hd = char:GetExtentsSize().Y
	local w, h, d = Hd * 0.08, Hd * 0.11, Hd * 0.08
	local c = (lo + hi) / 2 + y * (extent(lo, hi, y) + h * 0.45)
	local cf = root.CFrame * CFrame.fromMatrix(c, x, y, back)
	local m = Instance.new("Model")
	m.Name = "Mecha_InkTank"
	local tank = part("Tank", Vector3.new(w, h, d), cf, DARK, m, root)
	part("Window", Vector3.new(w * 1.04, h * 0.55, d * 0.5), cf * CFrame.new(0, -h * 0.05, 0), INK, m, tank, Enum.Material.Glass)
	part("Cap", Vector3.new(w * 0.7, h * 0.1, d * 0.7), cf * CFrame.new(0, h * 0.55, 0), STEEL, m, tank)
	local len = extent(lo, hi, back) * 1.2 + Hd * 0.08
	local bcf = cf * CFrame.new(0, -h * 0.2, -(d * 0.5 + len * 0.5))
	local barrel = part("Barrel", Vector3.new(w * 0.32, w * 0.32, len), bcf, STEEL, m, tank)
	local mz = Instance.new("Attachment")
	mz.Name = "Muzzle"
	mz.Position = Vector3.new(0, 0, -len * 0.5)
	mz.Parent = barrel
	m.Parent = char
	char:SetAttribute("InkLookBuilt", true)
	return m
end

local function setLook(char)
	local want = enabled() and char:GetAttribute("Species") == "Pachy" and char:GetAttribute("InkLook") == true
	local old = char:FindFirstChild("Mecha_InkTank")
	if not want then
		if old then old:Destroy() end
		char:SetAttribute("InkLookBuilt", false)
		return
	end
	if old then return end
	build(char)
end

-- targets -------------------------------------------------------------------------------------------------------------
local function closestOnBox(p, pos)
	local lp = p.CFrame:PointToObjectSpace(pos)
	local hh = p.Size / 2
	local c = Vector3.new(math.clamp(lp.X, -hh.X, hh.X), math.clamp(lp.Y, -hh.Y, hh.Y), math.clamp(lp.Z, -hh.Z, hh.Z))
	return p.CFrame:PointToWorldSpace(c)
end
local function isTarget(m, self)
	if not (m:IsA("Model") and m ~= self and m:IsDescendantOf(workspace)) then return nil end
	local hb = m:FindFirstChild("Hitboxes")
	if not hb or m:GetAttribute("Bitable") ~= true then return nil end
	if m:GetAttribute("Species") == nil and m:GetAttribute("IsBot") ~= true then return nil end
	if m:GetAttribute("DummyState") == "ko" then return nil end
	local hum = m:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health <= 0 then return nil end
	return hb
end
local function candidates(self)
	local list = {}
	for _, pl in ipairs(Players:GetPlayers()) do
		local c = pl.Character
		if c then local hb = isTarget(c, self) if hb and mayAffect(self, c) then table.insert(list, {m = c, hb = hb}) end end
	end
	local isl = workspace:FindFirstChild("DinoIsland")
	local bots = isl and isl:FindFirstChild("Bots")
	if bots then
		for _, b in ipairs(bots:GetChildren()) do
			local hb = isTarget(b, self) if hb and mayAffect(self, b) then table.insert(list, {m = b, hb = hb}) end
		end
	end
	return list
end
local worldParams = RaycastParams.new()
worldParams.FilterType = Enum.RaycastFilterType.Exclude
local function worldExclude()
	local ex = {}
	for _, pl in ipairs(Players:GetPlayers()) do if pl.Character then table.insert(ex, pl.Character) end end
	local isl = workspace:FindFirstChild("DinoIsland")
	for _, n in ipairs({"Bots", "TallGrass"}) do
		local f = isl and isl:FindFirstChild(n)
		if f then table.insert(ex, f) end
	end
	for _, n in ipairs({"DinoFX_Local", "DinoFX"}) do
		local f = workspace:FindFirstChild(n)
		if f then table.insert(ex, f) end
	end
	for _, d in ipairs(workspace:GetChildren()) do
		if d:IsA("Model") and (d:FindFirstChild("Hitboxes") or d:FindFirstChildOfClass("Humanoid")) then table.insert(ex, d) end
	end
	worldParams.FilterDescendantsInstances = ex
	return worldParams
end

local function muzzleOf(char)
	local m = char:FindFirstChild("Mecha_InkTank")
	local barrel = m and m:FindFirstChild("Barrel")
	local mz = barrel and barrel:FindFirstChild("Muzzle")
	if mz then return mz.WorldPosition end
	local hb = char:FindFirstChild("Hitboxes")
	if hb then
		for _, p in ipairs(hb:GetChildren()) do
			if p:IsA("BasePart") and p:GetAttribute("HitboxSegment") == "Head" then return p.Position end
		end
	end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	return hrp and hrp.Position
end

-- effects ------------------------------------------------------------------------------------------------------------
local function splat(pos, burstOnly) -- v1.3: burstOnly = the drops without the flat disc (a hit on a dino)
	local s = Instance.new("Part")
	s.Name = "InkSplat"
	s.Shape = Enum.PartType.Cylinder
	s.Size = Vector3.new(0.2, 7, 7)
	s.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90))
	s.Color = INK
	s.Material = Enum.Material.SmoothPlastic
	s.Anchored, s.CanCollide, s.CanQuery, s.CanTouch, s.CastShadow = true, false, false, false, false
	if burstOnly then s.Transparency = 1 end
	s.Parent = fxFolder()
	local a = Instance.new("Attachment")
	a.Parent = s
	local pe = Instance.new("ParticleEmitter")
	pe.Enabled = false
	pe.Color = ColorSequence.new(INK)
	pe.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 0.3)})
	pe.Speed = NumberRange.new(10, 20)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Acceleration = Vector3.new(0, -50, 0)
	pe.Lifetime = NumberRange.new(0.3, 0.6)
	pe.Parent = a
	pe:Emit(30)
	TweenService:Create(s, TweenInfo.new(1.5, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false, 0.5), {Transparency = 1}):Play()
	Debris:AddItem(s, 2.1)
end

local function glob(from, to, fly)
	local g = Instance.new("Part")
	g.Name = "InkGlob"
	g.Shape = Enum.PartType.Ball
	g.Size = Vector3.one * 1.6
	g.Color = INK
	g.Material = Enum.Material.SmoothPlastic
	g.Anchored, g.CanCollide, g.CanQuery, g.CanTouch, g.CastShadow = true, false, false, false, false
	g.CFrame = CFrame.new(from)
	g.Parent = fxFolder()
	TweenService:Create(g, TweenInfo.new(math.max(0.03, fly), Enum.EasingStyle.Linear), {CFrame = CFrame.new(to)}):Play()
	Debris:AddItem(g, fly + 0.05)
end

-- v1.3: the inked look on the target's head (see the header)
local function headAnchor(model)
	local head = model:FindFirstChild("Head")
	local a = head and (head:IsA("BasePart") and head or head:FindFirstChild("Root"))
	if a and a:IsA("BasePart") then return a end
	local hb = model:FindFirstChild("Hitboxes")
	if hb then
		for _, p in ipairs(hb:GetChildren()) do
			if p:IsA("BasePart") and p:GetAttribute("HitboxSegment") == "Head" then return p end
		end
	end
	return model:FindFirstChild("HumanoidRootPart")
end
local function inkedLook(target)
	local anchor = headAnchor(target)
	if not anchor then return end
	local oldA = anchor:FindFirstChild("InkHit")
	if oldA then oldA:Destroy() end
	local oldT = target:FindFirstChild("InkBlindedTag")
	if oldT then oldT:Destroy() end
	local a = Instance.new("Attachment")
	a.Name = "InkHit"
	a.Parent = anchor
	local splash = Instance.new("ParticleEmitter")
	splash.Name = "InkSplash"
	splash.Enabled = false
	splash.Color = ColorSequence.new(INK)
	splash.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 1.1), NumberSequenceKeypoint.new(1, 0.4)})
	splash.Speed = NumberRange.new(12, 22)
	splash.SpreadAngle = Vector2.new(180, 180)
	splash.Acceleration = Vector3.new(0, -50, 0)
	splash.Drag = 2
	splash.Lifetime = NumberRange.new(0.35, 0.6)
	splash.Parent = a
	splash:Emit(40)
	local drip = Instance.new("ParticleEmitter")
	drip.Name = "InkDrip"
	drip.Color = ColorSequence.new(INK)
	drip.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 0.25)})
	drip.Speed = NumberRange.new(0.5, 2)
	drip.SpreadAngle = Vector2.new(60, 60)
	drip.EmissionDirection = Enum.NormalId.Bottom
	drip.Acceleration = Vector3.new(0, -40, 0)
	drip.Lifetime = NumberRange.new(0.5, 0.9)
	drip.Rate = 30
	drip.Parent = a
	local g = Instance.new("BillboardGui")
	g.Name = "InkBlindedTag"
	g.Size = UDim2.fromOffset(150, 44)
	g.StudsOffsetWorldSpace = Vector3.new(0, 4, 0)
	g.AlwaysOnTop = true
	g.MaxDistance = 300
	g.Adornee = anchor
	local blot = Instance.new("Frame")
	blot.Name = "Blot"
	blot.AnchorPoint = Vector2.new(0.5, 0.5)
	blot.Position = UDim2.fromScale(0.5, 0.5)
	blot.Size = UDim2.fromScale(0.2, 0.2)
	blot.BackgroundColor3 = INK
	blot.BackgroundTransparency = 0.15
	blot.Parent = g
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = blot
	local l = Instance.new("TextLabel")
	l.Name = "Text"
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, 1)
	l.Font = Enum.Font.FredokaOne
	l.TextSize = 26
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextStrokeColor3 = INK
	l.TextStrokeTransparency = 0
	l.Text = "BLINDED"
	l.Parent = g
	g.Parent = target
	TweenService:Create(blot, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.fromScale(1, 1)}):Play()
	task.spawn(function()
		while a.Parent and g.Parent and target.Parent do
			if (tonumber(target:GetAttribute("InkedUntil")) or 0) <= now() then break end
			task.wait(0.1)
		end
		if not a.Parent then return end -- replaced by a newer ink
		drip.Enabled = false
		if g.Parent then
			TweenService:Create(l, TweenInfo.new(0.3), {TextTransparency = 1, TextStrokeTransparency = 1}):Play()
			TweenService:Create(blot, TweenInfo.new(0.3), {BackgroundTransparency = 1}):Play()
		end
		task.wait(0.6)
		if a.Parent then a:Destroy() end
		if g.Parent then g:Destroy() end
	end)
end

local function ink(target, shooter, untilT, t)
	target:SetAttribute("InkedUntil", math.max(tonumber(target:GetAttribute("InkedUntil")) or 0, untilT))
	target:SetAttribute("InkedBy", shooter.Name)
	target:SetAttribute("InkedAt", t) -- last
	if script:GetAttribute("InkHitLookEnabled") ~= false then pcall(inkedLook, target) end -- v1.3 (after InkedUntil)
end

local function setResult(char, r)
	char:SetAttribute("InkServerResult", r)
	char:SetAttribute("InkServerResultAt", now())
end

remote.OnServerEvent:Connect(function(player, stamp, aimDir)
	local char = player.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local t = now()
	local r
	if typeof(stamp) ~= "number" or stamp ~= stamp or typeof(aimDir) ~= "Vector3" or aimDir.Magnitude < 0.5 or aimDir.Magnitude > 1.5 then
		r = "badArg"
	elseif not hum or hum.Health <= 0 then
		r = "dead"
	elseif not enabled() or char:GetAttribute("InkEnabled") ~= true then
		r = "disabled"
	elseif player:GetAttribute("InMenu") == true then
		r = "menu"
	elseif (tonumber(char:GetAttribute("StunnedUntil")) or 0) > t then
		r = "stunned"
	elseif char:GetAttribute("PinHeld") == true then
		r = "pinned"
	elseif t < (tonumber(char:GetAttribute("InkReadyAt")) or 0) then
		r = "cooldown"
	end
	if r then setResult(char, r) return end
	setResult(char, "ok")
	setLook(char)
	local s = char:GetScale()
	local dir = aimDir.Unit
	do -- heading from the camera, pitch held near level (as the Grappling Hook)
		local flat = Vector3.new(dir.X, 0, dir.Z)
		if flat.Magnitude < 1e-3 then
			local hrp0 = char:FindFirstChild("HumanoidRootPart")
			flat = hrp0 and hrp0.CFrame.LookVector * Vector3.new(1, 0, 1) or Vector3.zAxis
		end
		local pmin = script:GetAttribute("InkShoulderMount") ~= false and PITCH_MIN_SHOULDER or PITCH_MIN -- v1.3
		local pitch = math.clamp(math.asin(math.clamp(dir.Y, -1, 1)), pmin, PITCH_MAX)
		dir = flat.Unit * math.cos(pitch) + Vector3.yAxis * math.sin(pitch)
	end
	local origin = muzzleOf(char) or char:GetPivot().Position
	local range = tonumber(char:GetAttribute("InkRange")) or 60
	local params = worldExclude()
	do -- v1.4: aim assist, snap to the closest dino near the aim
		local snapDir, snapAng
		if script:GetAttribute("InkAimAssistEnabled") ~= false then
			local maxAng = math.rad(math.clamp(tonumber(script:GetAttribute("InkAimAssistDeg")) or 12, 0, 45))
			for _, c in ipairs(candidates(char)) do
				for _, p in ipairs(c.hb:GetChildren()) do
					if p:IsA("BasePart") then
						local v = p.Position - origin
						local d = v.Magnitude
						if d > 0.5 and d <= range then
							local ang = math.acos(math.clamp(dir:Dot(v / d), -1, 1))
							if ang <= maxAng and (not snapAng or ang < snapAng) and not workspace:Raycast(origin, v, params) then
								snapDir, snapAng = v / d, ang
							end
						end
					end
				end
			end
		end
		if snapDir then dir = snapDir end
		char:SetAttribute("InkAssisted", snapDir ~= nil)
		char:SetAttribute("InkAssistDeg", snapAng and math.floor(math.deg(snapAng) + 0.5) or 0)
	end
	local wall = workspace:Raycast(origin, dir * range, params)
	local wallDist = wall and (wall.Position - origin).Magnitude or math.huge
	local best, bestT, bestPoint
	for _, c in ipairs(candidates(char)) do
		for _, p in ipairs(c.hb:GetChildren()) do
			if p:IsA("BasePart") then
				local tt = math.clamp((p.Position - origin):Dot(dir), 0, range)
				local onLine = origin + dir * tt
				local cp = closestOnBox(p, onLine)
				if (cp - onLine).Magnitude <= AIM_HELP * s and tt > 0 and (not bestT or tt < bestT) then
					best, bestT, bestPoint = c.m, tt, cp
				end
			end
		end
	end
	local result, aimEnd = "miss", origin + dir * math.min(range, wallDist)
	if best then
		if bestT > wallDist then
			result = "blocked"
		else
			local los = workspace:Raycast(origin, bestPoint - origin, params)
			if los then
				result, aimEnd = "blocked", los.Position
			elseif (tonumber(best:GetAttribute("EnergyShieldUntil")) or 0) > t then
				result, aimEnd = "shielded", bestPoint
			else
				result, aimEnd = "hit", bestPoint
			end
		end
	end
	local fly = (aimEnd - origin).Magnitude / INK_SPEED
	local arrive = t + fly
	char:SetAttribute("InkReadyAt", t + math.max(0.5, tonumber(char:GetAttribute("InkCooldown")) or 15))
	char:SetAttribute("InkAimDir", dir)
	char:SetAttribute("InkAimEnd", aimEnd)
	char:SetAttribute("InkResult", result)
	char:SetAttribute("InkHitTarget", (result == "hit" or result == "shielded") and best.Name or "")
	char:SetAttribute("InkArriveAt", arrive)
	char:SetAttribute("InkCount", (char:GetAttribute("InkCount") or 0) + 1)
	char:SetAttribute("InkStartedAt", t) -- last
	script:SetAttribute("InkShots", (script:GetAttribute("InkShots") or 0) + 1)
	glob(origin, aimEnd, fly)
	local target = best
	task.delay(fly, function()
		local ta = now()
		splat(aimEnd, script:GetAttribute("InkHitLookEnabled") ~= false and (result == "hit" or result == "shielded")) -- v1.3
		local blind = math.max(0.1, tonumber(char:GetAttribute("InkBlindTime")) or 2)
		if target and target.Parent and (result == "hit" or result == "shielded") then
			if result == "hit" and (tonumber(target:GetAttribute("EnergyShieldUntil")) or 0) <= ta then
				if visorBlocks(target, char, origin) then -- v1.1
					if char.Parent then char:SetAttribute("InkResult", "visor") end
				else
					ink(target, char, ta + blind, ta)
					script:SetAttribute("InkHits", (script:GetAttribute("InkHits") or 0) + 1)
				end
			end
		end
		local splash = tonumber(char:GetAttribute("InkSplash")) or 0
		local n = 0
		if splash > 0 and (result == "hit" or result == "shielded") and char.Parent then
			for _, c in ipairs(candidates(char)) do
				if c.m ~= target and (tonumber(c.m:GetAttribute("EnergyShieldUntil")) or 0) <= ta then
					local near = math.huge
					for _, p in ipairs(c.hb:GetChildren()) do
						if p:IsA("BasePart") then near = math.min(near, (closestOnBox(p, aimEnd) - aimEnd).Magnitude) end
					end
					if near <= splash and not visorBlocks(c.m, char, aimEnd) then -- v1.1: + visor
						ink(c.m, char, ta + blind, ta)
						n += 1
					end
				end
			end
		end
		if char.Parent then char:SetAttribute("InkSplashCount", n) end
	end)
end)

local function onCharacter(char)
	char:GetAttributeChangedSignal("InkLook"):Connect(function() setLook(char) end)
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
	fn.Name = "BuildPreview_ink"
	fn.OnInvoke = function(model)
		if not enabled() or typeof(model) ~= "Instance" then return nil end
		return build(model)
	end
	fn.Parent = script
end
