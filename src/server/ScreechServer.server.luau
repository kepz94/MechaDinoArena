-- ScreechServer v1.5 (Mecha Dino Arena) — Raptor Screech, a raptor button part (raptor parts batch 2): an aimed sonic
-- bolt that makes the first dino it hits flinch. MDA-73, plan docs/plans/RAPTOR_PARTS_B2_v1.0.md Task 5, mockup
-- docs/mockups/raptor_parts_b2_scent_screech.html option C "Hold to aim" (Kepu 2026-10-29: "Raptor screech is too
-- powerful it needs to be aimed"; Thick Hide counts; star jams all three parts).
-- Settings come from the character (SkillEffects 1.8): ScreechEnabled (bought AND slotted), ScreechRange (50; 67.5
--   from II: the longest the held aim can reach), ScreechFlinch (0.5 s), ScreechCooldown (14; 10.3 from III),
--   ScreechJam (star).
-- Client -> server: ReplicatedStorage.DinoScreechRequest:FireServer(clientServerTime, heldRange). The held range is
--   how far the aim line had grown when the button was let go (MechaButtons 1.8); it is clamped to
--   [MIN_RANGE (8), ScreechRange]. Checks, first failing wins: "badArg" (stamp or range not a number), "dead",
--   "disabled" (ScreechServerEnabled false or ScreechEnabled ~= true), "stunned" (StunnedUntil > now), "latched"
--   (PounceLatched), "cooldown" (now < ScreechReadyAt), "ok". ok: ScreechReadyAt = now + ScreechCooldown,
--   ScreechCount + 1, ScreechLastRange, ScreechStartedAt = now (last; CloakServer 1.4 ends your own cloak on it).
-- Bolt: starts BOLT_AHEAD (4) studs in front of the shooter's HumanoidRootPart at its height and flies along the
--   shooter's flat facing at BOLT_SPEED (70) studs/s until it has gone the held range, hits a dino, or hits anything
--   solid (raycast that respects CanCollide; tall grass does not stop it). Each step it hits the first dino (another
--   player's character or a bot in DinoIsland.Bots, alive) whose HumanoidRootPart is within HIT_RADIUS (4) studs +
--   half its smaller width of the step's path, flat, and within its height. Look: a red neon Ball "ScreechBolt" with
--   a Trail, anchored, no collide / query / touch; a hit or the end leaves a short expanding "ScreechBurst".
-- Hit (the target's character or bot model):
--   * raptor: StunnedUntil = max(current, now + ScreechFlinch) — the game's normal stun, so Thick Hide III shortens it
--     and Thick Hide star stops it above half health (SkillEffects); a bot lies down for it like any stun.
--     ScreechHitAt = now (CloakServer 1.4 ends its cloak with "screech").
--   * T-Rex: ScreechSlowUntil = now + ScreechFlinch (SprintTest 1.7 halves a player T-Rex's speed while it lasts; bots
--     do not read it). ScreechHitAt = now.
--   * star (shooter's ScreechJam): PartsJammedAt = now on the target (AdrenalineServer 1.3, EnergyShieldServer 1.3 and
--     MechaButtons 1.8 end the target's Adrenaline, Shield and boost).
--   Target diagnostics: ScreechHitBy (shooter name), ScreechHitCount.
-- v1.1 (Kepu 2026-10-29 after v76: renamed "Shock Dart"; "the dart doesn't even shoot far at all" -> 100 / 135 studs
--   (SkillTree 1.10), "Glowing dart"): BOLT_SPEED 110 (was 70) so the longer shot still lands in about 1 s; the bolt
--   looks like a dart: "ScreechBolt" is a steel body (0.45 x 0.45 x 3.2, pointing the way it flies) with a red neon tip
--   "ScreechDartTip" (0.5 x 0.5 x 1) and a red-to-white Trail streak (1.4 tall); both anchored, no collide / query / touch.
--   From the default camera the dart flies end-on and was 2-3 px wide at 45 studs, so the tip carries a red neon glow
--   ball "ScreechDartGlow" (GLOW_SIZE 2.2, transparency 0.55, welded to the tip, no collide / query / touch).
--   Everything else as 1.0.
-- v1.2 (Kepu 2026-10-29 after v80: "its distance is short as hell ... cant even see the damn thing travel ... make it a
--   cannon that sits somewhere on the raptor and shoots an electricity ball that disables a target for 1.5 seconds max",
--   "not real but obvious" -> mockup docs/mockups/shock_cannon_options.html B "Shoulder cannon", "Always full range",
--   "1.1 s -> 1.5 s at star" on raptor and T-Rex, "75 studs/s"). Shock Cannon mode (script attribute
--   ScreechShockCannonEnabled, default true; false = everything as 1.1):
--   * Cannon: while ScreechEnabled is true the character carries a Model "Mecha_ShockCannon" on the right shoulder
--     (welded to Torso.Root like Mecha_Adrenaline, sized by the dino's height Hd, massless, no collide / query / touch):
--     "Pod" (dark block Hd x 0.14 / 0.14 / 0.22), "Barrel" (steel cylinder Hd x 0.42 long, Hd x 0.08 wide, pointing
--     forward), two neon cyan "Coil_1" / "Coil_2" rings, a dark "MuzzleRing" and a neon "MuzzleGlow" ball (bright when
--     ready, dim while recharging). Attachment "ShockMuzzle" in Pod marks the barrel's mouth. Rebuilt when
--     ScreechEnabled or the toggles change. Character diagnostics: ScreechCannon ("on" / "none" / "noTorso"),
--     ScreechCannonReady.
--   * Range: always the full ScreechRange (the held range is ignored; character attribute ScreechFullRange = true tells
--     MechaButtons 1.10 to draw the full aim line at once).
--   * Shot: starts at ShockMuzzle (or 4 studs ahead of the root without a cannon) and flies along the flat facing at
--     SHOCK_SPEED (75) studs/s. Look: "ShockBall" (white-cyan neon core BALL_SIZE 3) with "ShockBallShell" (cyan neon,
--     SHELL_SIZE 5, transparency 0.65, welded), 5 crackling Beams re-drawn every 0.05 s, sparks, a PointLight and a
--     Trail; a cyan muzzle flash "ShockMuzzleFlash" at the shot; the hit / end burst is cyan.
--   * Hit: any dino (raptor or T-Rex, player or bot): StunnedUntil = max(current, now + ScreechFlinch) (SkillTree 1.11:
--     1.1 s, 1.5 s at star; Thick Hide rules apply as before); while the stun lasts the target's root carries sparks
--     "ShockStunSparks" and a light "ShockStunLight". Target diagnostic ScreechStunTime (s, after Thick Hide).
--     ScreechHitAt / jam / counters as 1.0.
-- v1.3 (MDA-83; Kepu 2026-10-29: different star for the cannon -> "Heavy shot"; SkillTree 1.14): the shooter's
--   ScreechDamage (30 at star, else 0) is dealt on a hit: a player through Humanoid:TakeDamage (LastHitBy / LastHitAt
--   stamped; Energy Shield blocks it), a bot through DummyHealth (a killing blow stamps KilledBy / KilledByUserId /
--   KilledWith "cannon" / KilledAt last). A damaging hit shows a rising "-30" (or "BLOCKED") BillboardGui
--   "ScreechDamagePop" over the target. The star jam is gone from the tree (ScreechJam false), so jam code stays idle.
-- Settings: script attribute ScreechServerEnabled (default true).
-- Diagnostics: script ScreechServerVersion, ScreechRequests, ScreechHits, ScreechMisses; shooter character
--   ScreechServerResult, ScreechCount, ScreechLastRange, ScreechLastHit (target name or "" for a miss), ScreechLastEnd
--   ("hit" / "range" / "wall").
-- v1.4 (Main Menu, MDA-88, plan docs/plans/MAIN_MENU_v1.0.md Task 4, ADR-005): a bolt / shock ball only stops on a target
--   for which ModeRules 1.0 canAffect(shooter is a player, target is a player, target's player InMenu, ModeRules.currentMode()
--   at start) is true; any other target is passed through (no stun, flinch, jam or damage), noted once per bolt per target:
--   target ModeBlockedAt (server time), shooter ModeBlockedTarget (target name), script ScreechModeBlocks + 1. Sandbox:
--   a player's cannon hits bots only; Arena: players too; nobody hits a player in the menu. Switch: script attribute
--   ScreechModeRulesEnabled (default true; false = v1.3, read on every check). Diagnostic: script ScreechMode.
-- v1.5 (Lab, MDA-96, plan docs/plans/LAB_v1.0.md Task 1; Kepu 2026-10-29: "Add a preview builder"): BindableFunction
--   "BuildPreview" under this script (server only). Invoke(model) builds this part on the given dino model (a Lab
--   mannequin, not a player) with the same build code (ScreechEnabled = true, then buildCannon(model)) and returns its Model "Mecha_ShockCannon" (nil when
--   nothing was built). LabPreviewServer 1.0 turns it into the Lab card model. The live part is unchanged. Switch: script
--   attribute ScreechServerPreviewEnabled (default true; false -> returns nil).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local VERSION = "1.5"
local MIN_RANGE, BOLT_SPEED, BOLT_AHEAD, HIT_RADIUS = 8, 110, 4, 4 -- v1.1: speed 110 (was 70)
local GLOW_SIZE = 2.2 -- v1.1: glow ball round the dart tip (the 1.0 ball was 2.4)
local SHOCK_SPEED, BALL_SIZE, SHELL_SIZE = 75, 3, 5 -- v1.2: Shock Cannon ball
local VOLT, VOLT_CORE = Color3.fromRGB(127, 233, 255), Color3.fromRGB(225, 250, 255) -- v1.2
local CANNON_DARK, CANNON_STEEL = Color3.fromRGB(58, 67, 80), Color3.fromRGB(142, 154, 168) -- v1.2
local RED = Color3.fromRGB(240, 90, 79)

script:SetAttribute("ScreechServerVersion", VERSION)
if script:GetAttribute("ScreechServerEnabled") == nil then script:SetAttribute("ScreechServerEnabled", true) end
script:SetAttribute("ScreechRequests", 0)
script:SetAttribute("ScreechHits", 0)
script:SetAttribute("ScreechMisses", 0)
if script:GetAttribute("ScreechShockCannonEnabled") == nil then script:SetAttribute("ScreechShockCannonEnabled", true) end -- v1.2
local function shockOn() return script:GetAttribute("ScreechShockCannonEnabled") ~= false end -- v1.2
local function on() return script:GetAttribute("ScreechServerEnabled") ~= false end
local function now() return workspace:GetServerTimeNow() end

-- v1.4: ModeRules
local ModeRules = require(game:GetService("ServerStorage"):WaitForChild("DinoArcade"):WaitForChild("ModeRules"))
local MODE = ModeRules.currentMode()
script:SetAttribute("ScreechMode", MODE)
script:SetAttribute("ScreechModeBlocks", 0)
if script:GetAttribute("ScreechModeRulesEnabled") == nil then script:SetAttribute("ScreechModeRulesEnabled", true) end
local function mayAffect(source, target)
	if script:GetAttribute("ScreechModeRulesEnabled") == false then
		return true
	else
		local tpl = Players:GetPlayerFromCharacter(target)
		local spl = Players:GetPlayerFromCharacter(source)
		local inMenu = tpl ~= nil and tpl:GetAttribute("InMenu") == true
		return ModeRules.canAffect(spl ~= nil, tpl ~= nil, inMenu, MODE)
	end
end

local remote = ReplicatedStorage:FindFirstChild("DinoScreechRequest")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "DinoScreechRequest"
	remote.Parent = ReplicatedStorage
end

local chars = {} -- [char] = {hum}
local bolts = {} -- {shooter, part, pos, dir, left, flinch, jam}

local function isTRex(model)
	local pl = Players:GetPlayerFromCharacter(model)
	local sp = tostring(pl and pl:GetAttribute("DinoSpecies") or model.Name)
	return sp:find("TRex") ~= nil
end

local function alive(model)
	local hum = model:FindFirstChildOfClass("Humanoid")
	if Players:GetPlayerFromCharacter(model) then return hum ~= nil and hum.Health > 0 end
	local dh = model:GetAttribute("DummyHealth")
	if dh ~= nil then return (tonumber(dh) or 0) > 0 end
	return hum == nil or hum.Health > 0
end

local function targets(shooter)
	local out = {}
	for _, pl in ipairs(Players:GetPlayers()) do
		local c = pl.Character
		if c and c ~= shooter then table.insert(out, c) end
	end
	local island = workspace:FindFirstChild("DinoIsland")
	local bots = island and island:FindFirstChild("Bots")
	if bots then
		for _, m in ipairs(bots:GetChildren()) do
			if m:IsA("Model") then table.insert(out, m) end
		end
	end
	return out
end

local function burst(pos, size, color)
	local p = Instance.new("Part")
	p.Name = "ScreechBurst"
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.one * 2
	p.Position = pos
	p.Color = color or RED -- v1.2: cyan for the Shock Cannon
	p.Material = Enum.Material.Neon
	p.Transparency = 0.2
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Parent = workspace
	TweenService:Create(p, TweenInfo.new(0.3), {Size = Vector3.one * size, Transparency = 1}):Play()
	Debris:AddItem(p, 0.35)
end

-- v1.3: heavy shot damage + a rising number
local function damagePop(target, text)
	local root = target:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local h = target:GetExtentsSize().Y
	local bb = Instance.new("BillboardGui")
	bb.Name = "ScreechDamagePop"
	bb.Size = UDim2.fromOffset(140, 56)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.MaxDistance = 300
	bb.StudsOffset = Vector3.new(0, h * 0.5 + 1.5, 0)
	local tl = Instance.new("TextLabel")
	tl.BackgroundTransparency = 1
	tl.Size = UDim2.fromScale(1, 1)
	tl.Font = Enum.Font.GothamBlack
	tl.TextScaled = true
	tl.Text = text
	tl.TextColor3 = VOLT_CORE
	tl.TextStrokeColor3 = Color3.fromRGB(10, 40, 70)
	tl.TextStrokeTransparency = 0
	tl.Parent = bb
	bb.Adornee = root
	bb.Parent = root
	TweenService:Create(bb, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{StudsOffset = bb.StudsOffset + Vector3.new(0, 4, 0)}):Play()
	TweenService:Create(tl, TweenInfo.new(0.5, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false, 0.4),
		{TextTransparency = 1, TextStrokeTransparency = 1}):Play()
	Debris:AddItem(bb, 1)
end
local function heavyDamage(b, target, t)
	local dmg = b.dmg or 0
	if dmg <= 0 then return end
	local text = "-" .. math.floor(dmg + 0.5)
	if Players:GetPlayerFromCharacter(target) then
		local hum = target:FindFirstChildOfClass("Humanoid")
		target:SetAttribute("LastHitBy", b.shooter.Name)
		target:SetAttribute("LastHitAt", t)
		if hum then
			local before = hum.Health
			hum:TakeDamage(dmg)
			if hum.Health >= before then text = "BLOCKED" end
		end
	else
		local hp = target:GetAttribute("DummyHealth")
		if typeof(hp) == "number" then
			target:SetAttribute("DummyHealth", math.max(0, hp - dmg))
			if hp > 0 and hp - dmg <= 0 then
				local killer = Players:GetPlayerFromCharacter(b.shooter)
				target:SetAttribute("KilledBy", b.shooter.Name)
				target:SetAttribute("KilledByUserId", killer and killer.UserId or 0)
				target:SetAttribute("KilledWith", "cannon")
				target:SetAttribute("KilledAt", t) -- last: KillRegenServer reacts to this one
			end
		end
	end
	damagePop(target, text)
end

local function hit(b, target)
	local t = now()
	local flinch = b.flinch
	if b.shock then -- v1.2: a full stun on any dino, sparks while it lasts
		target:SetAttribute("StunnedUntil", math.max(tonumber(target:GetAttribute("StunnedUntil")) or 0, t + flinch))
		task.delay(0.1, function() -- after Thick Hide (SkillEffects) has had its say
			local dur = (tonumber(target:GetAttribute("StunnedUntil")) or 0) - now()
			target:SetAttribute("ScreechStunTime", math.max(0, math.floor(dur * 100 + 0.5) / 100))
			local root = target.Parent and target:FindFirstChild("HumanoidRootPart")
			if not root or dur <= 0.05 then return end
			local pe = Instance.new("ParticleEmitter")
			pe.Name = "ShockStunSparks"
			pe.Color = ColorSequence.new(VOLT_CORE, VOLT)
			pe.LightEmission = 1
			pe.Rate = 70
			pe.Lifetime = NumberRange.new(0.15, 0.35)
			pe.Speed = NumberRange.new(8, 16)
			pe.SpreadAngle = Vector2.new(180, 180)
			pe.Size = NumberSequence.new(0.7, 0)
			pe.Parent = root
			local li = Instance.new("PointLight")
			li.Name = "ShockStunLight"
			li.Color, li.Range, li.Brightness = VOLT, 14, 3
			li.Parent = root
			Debris:AddItem(pe, dur)
			Debris:AddItem(li, dur)
		end)
	elseif isTRex(target) then
		target:SetAttribute("ScreechSlowUntil", t + flinch)
	else
		target:SetAttribute("StunnedUntil", math.max(tonumber(target:GetAttribute("StunnedUntil")) or 0, t + flinch))
	end
	if b.jam then target:SetAttribute("PartsJammedAt", t) end
	if b.shock then heavyDamage(b, target, t) end -- v1.3
	target:SetAttribute("ScreechHitBy", b.shooter.Name)
	target:SetAttribute("ScreechHitCount", (target:GetAttribute("ScreechHitCount") or 0) + 1)
	target:SetAttribute("ScreechHitAt", t) -- last: CloakServer reacts to it
	b.shooter:SetAttribute("ScreechLastHit", target.Name)
	script:SetAttribute("ScreechHits", (script:GetAttribute("ScreechHits") or 0) + 1)
end

local function endBolt(b, reason)
	b.done = true
	b.shooter:SetAttribute("ScreechLastEnd", reason)
	if reason ~= "hit" then
		b.shooter:SetAttribute("ScreechLastHit", "")
		script:SetAttribute("ScreechMisses", (script:GetAttribute("ScreechMisses") or 0) + 1)
	end
	burst(b.pos, reason == "hit" and 10 or 6, b.shock and VOLT or nil)
	b.part:Destroy()
	if b.tip then b.tip:Destroy() end -- v1.1
end
-- v1.1: put the dart (body + tip) at pos, pointing along its flight
local function place(b, pos)
	local cf = CFrame.lookAt(pos, pos + b.dir)
	b.part.CFrame = cf
	if b.tip then b.tip.CFrame = cf * CFrame.new(0, 0, -2.0) end
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.RespectCanCollide = true

RunService.Heartbeat:Connect(function(dt)
	for i = #bolts, 1, -1 do
		local b = bolts[i]
		if b.done then
			table.remove(bolts, i)
		else
			local step = math.min(b.left, (b.speed or BOLT_SPEED) * dt) -- v1.2: per-shot speed
			if b.arcs and os.clock() >= (b.nextArc or 0) then -- v1.2: re-draw the crackle
				b.nextArc = os.clock() + 0.05
				for _, arc in ipairs(b.arcs) do
					local v = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5)
					v = v.Magnitude > 1e-3 and v.Unit or Vector3.yAxis
					arc.a.Position = v * BALL_SIZE * (0.8 + math.random() * 0.7)
					arc.beam.CurveSize0 = (math.random() - 0.5) * 3
					arc.beam.CurveSize1 = (math.random() - 0.5) * 3
				end
			end
			local a, z = b.pos, b.pos + b.dir * step
			-- first dino along this step
			local best, bestT
			for _, m in ipairs(targets(b.shooter)) do
				local root = m:FindFirstChild("HumanoidRootPart")
				if root and alive(m) then
					local size = m:GetExtentsSize()
					local rel = Vector3.new(root.Position.X - a.X, 0, root.Position.Z - a.Z)
					local seg = Vector3.new(z.X - a.X, 0, z.Z - a.Z)
					local len2 = seg:Dot(seg)
					local k = len2 > 0 and math.clamp(rel:Dot(seg) / len2, 0, 1) or 0
					local d = (rel - seg * k).Magnitude
					local reach = HIT_RADIUS + math.min(size.X, size.Z) / 2
					if d <= reach and math.abs(root.Position.Y - a.Y) <= size.Y / 2 + HIT_RADIUS and (not bestT or k < bestT) then
						if mayAffect(b.shooter, m) then -- v1.4
							best, bestT = m, k
						elseif not (b.modeIgnored and b.modeIgnored[m]) then -- v1.4: passed through, noted once
							b.modeIgnored = b.modeIgnored or {}
							b.modeIgnored[m] = true
							m:SetAttribute("ModeBlockedAt", now())
							if b.shooter.Parent then b.shooter:SetAttribute("ModeBlockedTarget", m.Name) end
							script:SetAttribute("ScreechModeBlocks", (script:GetAttribute("ScreechModeBlocks") or 0) + 1)
						end
					end
				end
			end
			-- anything solid first?
			local ex = {b.shooter, b.part, b.tip} -- v1.1: tip too
			for _, m in ipairs(targets(b.shooter)) do table.insert(ex, m) end
			rayParams.FilterDescendantsInstances = ex
			local wall = step > 0 and workspace:Raycast(a, z - a, rayParams)
			local wallT = wall and (wall.Position - a).Magnitude / step or nil
			if best and (not wallT or bestT <= wallT) then
				b.pos = a + (z - a) * bestT
				place(b, b.pos)
				hit(b, best)
				endBolt(b, "hit")
			elseif wall then
				b.pos = wall.Position
				place(b, b.pos)
				endBolt(b, "wall")
			else
				b.pos = z
				b.left -= step
				place(b, z)
				if b.left <= 1e-3 then endBolt(b, "range") end
			end
		end
	end
end)

local function makeBolt(pos, dir) -- v1.1: a glowing dart (was a red ball)
	local cf = CFrame.lookAt(pos, pos + dir)
	local p = Instance.new("Part")
	p.Name = "ScreechBolt"
	p.Size = Vector3.new(0.45, 0.45, 3.2)
	p.CFrame = cf
	p.Color = Color3.fromRGB(201, 210, 220)
	p.Material = Enum.Material.Metal
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0.7, 1.2)
	a0.Parent = p
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -0.7, 1.2)
	a1.Parent = p
	local tr = Instance.new("Trail")
	tr.Attachment0, tr.Attachment1 = a0, a1
	tr.Color = ColorSequence.new(RED, Color3.new(1, 1, 1))
	tr.LightEmission = 1
	tr.Lifetime = 0.3
	tr.Transparency = NumberSequence.new(0.1, 1)
	tr.Parent = p
	local tip = Instance.new("Part")
	tip.Name = "ScreechDartTip"
	tip.Size = Vector3.new(0.5, 0.5, 1)
	tip.CFrame = cf * CFrame.new(0, 0, -2.0)
	tip.Color = RED
	tip.Material = Enum.Material.Neon
	tip.Anchored, tip.CanCollide, tip.CanQuery, tip.CanTouch, tip.CastShadow = true, false, false, false, false
	-- glow round the tip so the dart reads from the default camera (end-on it is only a few pixels)
	local glow = Instance.new("Part")
	glow.Name = "ScreechDartGlow"
	glow.Shape = Enum.PartType.Ball
	glow.Size = Vector3.one * GLOW_SIZE
	glow.CFrame = tip.CFrame
	glow.Color = RED
	glow.Material = Enum.Material.Neon
	glow.Transparency = 0.55
	glow.Anchored, glow.CanCollide, glow.CanQuery, glow.CanTouch, glow.CastShadow = false, false, false, false, false
	glow.Massless = true
	local w = Instance.new("WeldConstraint")
	w.Part0, w.Part1 = tip, glow
	w.Parent = glow
	glow.Parent = tip -- moves with the tip; destroyed with it
	p.Parent = workspace
	tip.Parent = workspace
	return p, tip
end

-- v1.2: the Shock Cannon's electric ball (anchored core, moved like the bolt; everything else rides on it)
local function makeBall(pos, dir)
	local core = Instance.new("Part")
	core.Name = "ShockBall"
	core.Shape = Enum.PartType.Ball
	core.Size = Vector3.one * BALL_SIZE
	core.CFrame = CFrame.lookAt(pos, pos + dir)
	core.Color = VOLT_CORE
	core.Material = Enum.Material.Neon
	core.Anchored, core.CanCollide, core.CanQuery, core.CanTouch, core.CastShadow = true, false, false, false, false
	local shell = Instance.new("Part")
	shell.Name = "ShockBallShell"
	shell.Shape = Enum.PartType.Ball
	shell.Size = Vector3.one * SHELL_SIZE
	shell.CFrame = core.CFrame
	shell.Color = VOLT
	shell.Material = Enum.Material.Neon
	shell.Transparency = 0.65
	shell.Anchored, shell.CanCollide, shell.CanQuery, shell.CanTouch, shell.CastShadow = false, false, false, false, false
	shell.Massless = true
	local w = Instance.new("WeldConstraint")
	w.Part0, w.Part1 = core, shell
	w.Parent = shell
	shell.Parent = core
	local li = Instance.new("PointLight")
	li.Color, li.Range, li.Brightness = VOLT, 18, 4
	li.Parent = core
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, BALL_SIZE * 0.45, 0)
	a0.Parent = core
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -BALL_SIZE * 0.45, 0)
	a1.Parent = core
	local tr = Instance.new("Trail")
	tr.Attachment0, tr.Attachment1 = a0, a1
	tr.Color = ColorSequence.new(VOLT_CORE, VOLT)
	tr.LightEmission = 1
	tr.FaceCamera = true
	tr.Lifetime = 0.35
	tr.Transparency = NumberSequence.new(0.2, 1)
	tr.Parent = core
	local pe = Instance.new("ParticleEmitter")
	pe.Color = ColorSequence.new(VOLT_CORE, VOLT)
	pe.LightEmission = 1
	pe.Rate = 80
	pe.Lifetime = NumberRange.new(0.15, 0.35)
	pe.Speed = NumberRange.new(8, 14)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Size = NumberSequence.new(0.5, 0)
	pe.Parent = core
	local c0 = Instance.new("Attachment")
	c0.Parent = core
	local arcs = {}
	for i = 1, 5 do
		local a = Instance.new("Attachment")
		a.Name = "ArcEnd_" .. i
		a.Position = Vector3.new(0, BALL_SIZE, 0)
		a.Parent = core
		local bm = Instance.new("Beam")
		bm.Name = "Arc_" .. i
		bm.Attachment0, bm.Attachment1 = c0, a
		bm.Color = ColorSequence.new(Color3.new(1, 1, 1), VOLT)
		bm.LightEmission = 1
		bm.FaceCamera = true
		bm.Segments = 8
		bm.Width0, bm.Width1 = 0.35, 0.08
		bm.Transparency = NumberSequence.new(0)
		bm.Parent = core
		table.insert(arcs, {a = a, beam = bm})
	end
	core.Parent = workspace
	return core, arcs
end

-- v1.2: cannon geometry helpers (the same maths as AdrenalineServer 1.3's tanks)
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
local function axisOf(root, dir)
	local v = root.CFrame:VectorToObjectSpace(dir)
	local a = Vector3.new(math.abs(v.X), math.abs(v.Y), math.abs(v.Z))
	if a.X >= a.Y and a.X >= a.Z then return Vector3.new(v.X >= 0 and 1 or -1, 0, 0) end
	if a.Y >= a.Z then return Vector3.new(0, v.Y >= 0 and 1 or -1, 0) end
	return Vector3.new(0, 0, v.Z >= 0 and 1 or -1)
end
local function extent(lo, hi, axis)
	local h = (hi - lo) / 2
	return math.abs(axis.X) * h.X + math.abs(axis.Y) * h.Y + math.abs(axis.Z) * h.Z
end
local function bodyAxes(root, hrp)
	local x = axisOf(root, hrp.CFrame.RightVector)
	local y = axisOf(root, hrp.CFrame.UpVector)
	if math.abs(x:Dot(y)) > 0.5 then y = axisOf(root, hrp.CFrame.LookVector):Cross(x) end
	return x, y, x:Cross(y)
end
local function cannonPart(name, size, cf, color, parent, mount, shape, neon)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	if shape then p.Shape = shape end
	if neon then p.Material = Enum.Material.Neon else p.Material = Enum.Material.Metal end
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Anchored, p.Massless = false, true
	p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = false, false, false, false
	p.Parent = parent
	local w = Instance.new("WeldConstraint")
	w.Part0, w.Part1 = mount, p
	w.Parent = p
	return p
end
local function buildCannon(char)
	local old = char:FindFirstChild("Mecha_ShockCannon")
	if old then old:Destroy() end
	char:SetAttribute("ScreechFullRange", shockOn())
	if not on() or not shockOn() or char:GetAttribute("ScreechEnabled") ~= true then
		char:SetAttribute("ScreechCannon", "none")
		return
	end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	local seg = char:FindFirstChild("Torso")
	local root = seg and seg:FindFirstChild("Root")
	local lo, hi
	if hrp and root then lo, hi = rootBox(seg, root) end
	if not lo then char:SetAttribute("ScreechCannon", "noTorso") return end
	local Hd = char:GetExtentsSize().Y
	local x, y, z = bodyAxes(root, hrp)
	local ps = Vector3.new(Hd * 0.14, Hd * 0.14, Hd * 0.22) -- pod: right, up, back (Play: 0.09 / 0.1 / 0.16 was too small to read)
	local pLocal = (lo + hi) / 2 + x * (extent(lo, hi, x) + ps.X * 0.45) + y * (extent(lo, hi, y) * 0.55)
		- z * (extent(lo, hi, z) * 0.25) -- right shoulder, upper half, a little forward
	local cf = root.CFrame * CFrame.fromMatrix(pLocal, x, y, z) -- LookVector = forward
	local model = Instance.new("Model")
	model.Name = "Mecha_ShockCannon"
	local pod = cannonPart("Pod", ps, cf, CANNON_DARK, model, root)
	local L, d = Hd * 0.42, Hd * 0.08 -- (Play: 0.3 / 0.045 was too thin from the game camera)
	local yb = ps.Y * 0.1
	local along = CFrame.Angles(0, math.rad(90), 0) -- a cylinder's axis is X; turn it to point forward
	cannonPart("Barrel", Vector3.new(L, d, d), cf * CFrame.new(0, yb, -(ps.Z / 2 + L / 2)) * along, CANNON_STEEL, model, pod,
		Enum.PartType.Cylinder)
	for i, k in ipairs({0.3, 0.6}) do
		cannonPart("Coil_" .. i, Vector3.new(Hd * 0.014, d * 1.4, d * 1.4), cf * CFrame.new(0, yb, -(ps.Z / 2 + L * k)) * along,
			VOLT, model, pod, Enum.PartType.Cylinder, true)
	end
	cannonPart("MuzzleRing", Vector3.new(Hd * 0.03, d * 1.5, d * 1.5), cf * CFrame.new(0, yb, -(ps.Z / 2 + L)) * along,
		CANNON_DARK, model, pod, Enum.PartType.Cylinder)
	local glow = cannonPart("MuzzleGlow", Vector3.one * d * 1.1, cf * CFrame.new(0, yb, -(ps.Z / 2 + L + Hd * 0.01)), VOLT,
		model, pod, Enum.PartType.Ball, true)
	glow.Transparency = 0.2
	local m = Instance.new("Attachment")
	m.Name = "ShockMuzzle"
	m.Position = Vector3.new(0, yb, -(ps.Z / 2 + L + Hd * 0.03))
	m.Parent = pod
	model.Parent = char
	char:SetAttribute("ScreechCannon", "on")
end
local function muzzleFlash(pos)
	local p = Instance.new("Part")
	p.Name = "ShockMuzzleFlash"
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.one * 2
	p.Position = pos
	p.Color = VOLT
	p.Material = Enum.Material.Neon
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Parent = workspace
	TweenService:Create(p, TweenInfo.new(0.15), {Size = Vector3.one * 4, Transparency = 1}):Play()
	Debris:AddItem(p, 0.2)
end

remote.OnServerEvent:Connect(function(player, stamp, held)
	local char = player.Character
	local st = char and chars[char]
	if not st then return end
	script:SetAttribute("ScreechRequests", (script:GetAttribute("ScreechRequests") or 0) + 1)
	local t = now()
	local hum = st.hum
	local root = char:FindFirstChild("HumanoidRootPart")
	local result
	if typeof(stamp) ~= "number" or stamp ~= stamp or typeof(held) ~= "number" or held ~= held then
		result = "badArg"
	elseif not hum or hum.Health <= 0 or not root then
		result = "dead"
	elseif not on() or char:GetAttribute("ScreechEnabled") ~= true then
		result = "disabled"
	elseif (tonumber(char:GetAttribute("StunnedUntil")) or 0) > t then
		result = "stunned"
	elseif char:GetAttribute("PounceLatched") == true then
		result = "latched"
	elseif t < (tonumber(char:GetAttribute("ScreechReadyAt")) or 0) then
		result = "cooldown"
	else
		result = "ok"
	end
	char:SetAttribute("ScreechServerResult", result)
	if result ~= "ok" then return end
	local maxR = math.max(MIN_RANGE, tonumber(char:GetAttribute("ScreechRange")) or 50)
	local range = math.clamp(held, MIN_RANGE, maxR)
	local shock = shockOn() -- v1.2
	if shock then range = maxR end -- v1.2: always the full range
	local look = root.CFrame.LookVector
	local dir = Vector3.new(look.X, 0, look.Z)
	dir = dir.Magnitude > 1e-3 and dir.Unit or Vector3.new(0, 0, -1)
	local pos = root.Position + dir * BOLT_AHEAD
	local jam = false
	if char:GetAttribute("ScreechJam") == true then jam = true end
	local flinch = math.max(0.05, tonumber(char:GetAttribute("ScreechFlinch")) or 0.5)
	if shock then -- v1.2: the ball leaves the cannon's mouth
		local cm = char:FindFirstChild("Mecha_ShockCannon")
		local pod = cm and cm:FindFirstChild("Pod")
		local mz = pod and pod:FindFirstChild("ShockMuzzle")
		if mz then pos = mz.WorldPosition end
		muzzleFlash(pos)
		local core, arcs = makeBall(pos, dir)
		table.insert(bolts, {shooter = char, part = core, arcs = arcs, pos = pos, dir = dir, left = range, flinch = flinch,
			jam = jam, shock = true, speed = SHOCK_SPEED, dmg = math.max(0, tonumber(char:GetAttribute("ScreechDamage")) or 0)}) -- v1.3: + dmg
	else
		local body, tip = makeBolt(pos, dir) -- v1.1: dart
		table.insert(bolts, {shooter = char, part = body, tip = tip, pos = pos, dir = dir, left = range,
			flinch = flinch, jam = jam})
	end
	char:SetAttribute("ScreechReadyAt", t + (tonumber(char:GetAttribute("ScreechCooldown")) or 0))
	char:SetAttribute("ScreechCount", (char:GetAttribute("ScreechCount") or 0) + 1)
	char:SetAttribute("ScreechLastRange", math.floor(range * 10 + 0.5) / 10)
	char:SetAttribute("ScreechStartedAt", t) -- last: readers react to this one
end)

local function onCharacter(char)
	if chars[char] then return end
	local hum = char:WaitForChild("Humanoid", 10)
	if not hum then return end
	chars[char] = {hum = hum}
	char:SetAttribute("ScreechReadyAt", 0)
	buildCannon(char) -- v1.2
	char:GetAttributeChangedSignal("ScreechEnabled"):Connect(function() buildCannon(char) end) -- v1.2
	char.AncestryChanged:Connect(function(_, parent)
		if not parent then chars[char] = nil end
	end)
end

-- v1.2: toggles rebuild every cannon; the muzzle glows bright when ready, dim while recharging
local function rebuildAll() for char in pairs(chars) do buildCannon(char) end end
script:GetAttributeChangedSignal("ScreechShockCannonEnabled"):Connect(rebuildAll)
script:GetAttributeChangedSignal("ScreechServerEnabled"):Connect(rebuildAll)
local glowAcc = 0
RunService.Heartbeat:Connect(function(dt)
	glowAcc += dt
	if glowAcc < 0.2 then return end
	glowAcc = 0
	local t = now()
	for char in pairs(chars) do
		local cm = char:FindFirstChild("Mecha_ShockCannon")
		local g = cm and cm:FindFirstChild("MuzzleGlow")
		if g then
			local ready = t >= (tonumber(char:GetAttribute("ScreechReadyAt")) or 0)
			if ready then g.Transparency = 0.2 else g.Transparency = 0.8 end
			if char:GetAttribute("ScreechCannonReady") ~= ready then char:SetAttribute("ScreechCannonReady", ready) end
		end
	end
end)

local function onPlayer(player)
	player.CharacterAdded:Connect(onCharacter)
	if player.Character then task.spawn(onCharacter, player.Character) end
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do onPlayer(p) end

-- v1.5: Lab card preview (LabPreviewServer 1.0)
if script:GetAttribute("ScreechServerPreviewEnabled") == nil then script:SetAttribute("ScreechServerPreviewEnabled", true) end
local previewFn = script:FindFirstChild("BuildPreview") or Instance.new("BindableFunction")
previewFn.Name = "BuildPreview"
previewFn.Parent = script
previewFn.OnInvoke = function(model)
	if script:GetAttribute("ScreechServerPreviewEnabled") == false or typeof(model) ~= "Instance" then return nil end
	model:SetAttribute("ScreechEnabled", true)
	buildCannon(model)
	return model:FindFirstChild("Mecha_ShockCannon")
end
