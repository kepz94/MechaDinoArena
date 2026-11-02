-- TenoMovesServer v1.1 (Mecha Dino Arena) — the moves of the Tenontosaurus' mecha button parts, build 1 (attacks): Tail
-- Grab & Fling, Boulder Mortar, Stomp Shockwave, Hydraulic Leap. Plan docs/plans/TENO_ABILITIES_v1.0.md Task 5 (MDA-177,
-- deterministic map), mockup docs/mockups/teno_abilities_options.html v0.3 (Kepu 2026-11-01; Mortar "Auto-target").
-- Settings come from the character (SkillEffects 1.33, a teno with the part bought AND slotted): TenoGrab* (Enabled, Range,
--   Fling, Damage, Stun, Big, Crash, CrashRadius, Cooldown), TenoMortar* (Enabled, Range, Miss, Cone, Damage, Splash,
--   Count, SlowMul, SlowTime, Rubble, Cooldown), TenoStomp* (Enabled, Range, Damage, Stun, NoJump, Cooldown), TenoLeap*
--   (Enabled, Dist, Damage, Radius, Stun, Charges, Cooldown). Distances are world studs (the Lab texts; the mockup's world).
-- Remotes (ReplicatedStorage, created here): DinoTenoGrabRequest(stamp), DinoTenoMortarRequest(stamp, aimDir),
--   DinoTenoStompRequest(stamp), DinoTenoLeapRequest(stamp) (MechaButtons 1.26).
-- Request checks, first failing wins (character <Prefix>ServerResult + <Prefix>ServerResultAt): "badArg", "dead",
--   "disabled", "menu", "stunned", "pinned", "dazed", then leap "active" (a leap in the air), then "cooldown"; grab with no
--   target "noTarget" (no cooldown); else "ok": <Prefix>ReadyAt = now + <Prefix>Cooldown (leap: per charge, below).
-- Who can be hit / grabbed / slowed: Workspace models with a Hitboxes folder, Bitable true, a Species or IsBot, not self,
--   not KO, alive; players only where ModeRules.canAffect allows (the Arena), bots always; never a squadmate (SquadRules
--   sameChar). An Energy Shield (EnergyShieldUntil > now) blocks the damage, stun and slow of these moves and can't be
--   grabbed. Damage: base x roar debuff x daze star x Stun Breaker star off DummyHealth; a killing blow stamps KilledBy /
--   KilledByUserId / KilledWith ("tailgrab" / "mortar" / "stomp" / "leap") / KilledAt.
-- Slows (mortar, rubble): a player gets TenoSlowUntil / TenoSlowMul (SprintTest 1.18; the stronger / longer is kept); a bot's
--   WalkSpeed is scaled here (TenoAttackServer 1.3's pattern; while that script slows the same bot (its TenoSlowed true) this
--   one gives the bot back its speed and waits, so the two never multiply). Bot attribute TenoMoveSlowed.
-- Tail Grab & Fling: target = the nearest allowed dino of a grabbable size (Raptor, Herrera; TenoGrabBig: + Pachy, Teno;
--   T-Rex never), not anchored, behind or beside the hips (HRP-space Z >= 0), whose hitbox gap to the tail (Tail1..5_main
--   centres and the tip, Tail5_main * (-1.6 x scale, 0, 0)) is within TenoGrabRange. A raptor latched on the teno counts
--   and is released first (ShakeOffReason "grabbed"). GRAB_CATCH (0.3) s after the press the tail catches it; a bot rides
--   the tail tip for GRAB_CARRY (0.5) s, then flies FLING_TIME (0.9) s on an arc (peak FLING_PEAK 16) to the ground
--   TenoGrabFling studs ahead of the teno (flat facing at the throw); a player is stunned for the carry and thrown by
--   StunClient (StunTossFrom behind it, StunTossDistance to the landing). Landing: TenoGrabDamage, StunnedUntil = max(old,
--   land + TenoGrabStun); star (TenoGrabCrash > 0): every other allowed dino within TenoGrabCrashRadius of the landing takes
--   TenoGrabCrash + 1 s stun. Teno: TenoGrabTarget, TenoGrabThrowAt, TenoGrabLand, TenoGrabLandAt, TenoGrabCrashHits,
--   TenoGrabStartedAt (last); target TenoGrabbedBy / TenoGrabbedAt.
-- Boulder Mortar: aim = the flat camera heading (aimDir). Target = the nearest allowed enemy root within TenoMortarRange
--   and TenoMortarCone degrees of the aim; none -> TenoMortarMiss studs straight along the aim. Points: the target / miss
--   spot on the ground; TenoMortarCount 2 -> two points +- right x MORTAR_PAIR (4.5). MORTAR_FIRE (0.35) s after the press
--   (the tail whip) each boulder (Workspace.DinoFX.TenoMovesFX "TenoBoulder", Slate ball, no collide / query / touch) leaves
--   the catapult bucket and flies MORTAR_FLIGHT (1.3) s on an arc (peak MORTAR_PEAK 30 above the higher end). Landing: every
--   allowed dino whose root is within TenoMortarSplash (flat, 15 up / down) of a point: TenoMortarDamage once, slowed
--   TenoMortarSlowMul for TenoMortarSlowTime s. Star (TenoMortarRubble > 0): a rubble patch "TenoRubble" (radius
--   0.8 x splash) per point for TenoMortarRubble s; every 0.2 s allowed enemies inside are slowed x TenoMortarSlowMul for
--   0.3 s. Teno: TenoMortarTarget, TenoMortarLand, TenoMortarFiredAt, TenoMortarLandedAt, TenoMortarHits,
--   TenoMortarStartedAt (last).
-- Stomp Shockwave: STOMP_HIT (0.5) s after the press (the rear-up): centre = the ground under the middle of ArmL_hand /
--   ArmR_hand. Every allowed dino whose hitbox gap to the centre is within TenoStompRange (15 up / down): TenoStompDamage,
--   StunnedUntil = max(old, now + TenoStompStun); star (TenoStompNoJump > 0): NoJumpUntil = now + TenoStompNoJump (a tag;
--   no reader yet: PounceServer / JumpTest are not edited). Raptors latched on the teno: released (ShakeOffReason
--   "stomped"). Teno: TenoStompCenter, TenoStompHits, TenoStompStartedAt, TenoStompAt (last).
-- Hydraulic Leap: TenoLeapCharges charges; each used charge refills TenoLeapCooldown s after it was used (one at a time).
--   TenoLeapChargesLeft, TenoLeapRefillAt; TenoLeapReadyAt = now while a charge is left, else the next refill. ok:
--   TenoLeapDistNow = TenoLeapDist, TenoLeapFlightTime = LEAP_TIME (0.9), TenoLeapUntil = now + LEAP_TIME + 0.8,
--   TenoLeapStartedAt (last: TenoLeapLaunch 1.0 on the owner's client launches the body). Landing = the first heartbeat
--   after 0.6 x LEAP_TIME with the root back within 1.5 studs of its take-off height over the ground (the server's
--   FloorMaterial of a player-owned body is not reliable), or now + LEAP_TIME + 0.8: every allowed dino whose hitbox gap to
--   the root is within TenoLeapRadius (15 up / down): TenoLeapDamage; III (TenoLeapStun > 0): StunnedUntil = max(old, now +
--   TenoLeapStun). No tail slam charge is used. Teno: TenoLeapLandedAt, TenoLeapHits, TenoLeapUntil = 0.
-- Switches: script attributes TenoMovesServerEnabled, TenoMoves_tgrabEnabled, TenoMoves_tmortarEnabled,
--   TenoMoves_tstompEnabled, TenoMoves_tleapEnabled, TenoMovesModeRulesEnabled, TenoMovesServerSquadEnabled (default true
--   each, read at each use).
-- Diagnostics: script TenoMovesServerVersion, TenoMovesMode, TenoMovesGrabs, TenoMovesMortars, TenoMovesStomps,
--   TenoMovesLeaps, TenoMovesHits, TenoMovesSlows, TenoMovesSquadSkips; character results above.
-- v1.1 (Kepu 2026-11-02: the stomp "doesn't knock it off, it lowers the stamina for the current pounce", -50; SkillTree
--   1.52 / SkillEffects 1.35): the stomp no longer releases raptors latched on the teno (they are still not hit by the
--   shockwave). Star (TenoStompLatchDrain > 0): each allowed raptor latched on the teno gets StaminaDrainAmount =
--   TenoStompLatchDrain and StaminaDrainAt = now (StaminaServer 1.6 takes it off a player's stamina, so the latch ends
--   sooner; BotServer 1.23 cuts a bot's latch time by amount / PounceLatchDrain). NoJumpUntil is no longer written
--   (TenoStompNoJump is 0). Switch: script attribute TenoMovesStompDrainEnabled (default true, read at each stomp; false =
--   1.0: latched raptors released). Diagnostic: character TenoStompDrained (count).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local VERSION = "1.1"
local GRAB_CATCH, GRAB_CARRY, FLING_TIME, FLING_PEAK = 0.3, 0.5, 0.9, 16
local MORTAR_FIRE, MORTAR_FLIGHT, MORTAR_PEAK, MORTAR_PAIR = 0.35, 1.3, 30, 4.5
local STOMP_HIT = 0.5
local LEAP_TIME = 0.9
local DY = 15

script:SetAttribute("TenoMovesServerVersion", VERSION)
if script:GetAttribute("TenoMovesStompDrainEnabled") == nil then script:SetAttribute("TenoMovesStompDrainEnabled", true) end -- v1.1
for _, k in ipairs({"TenoMovesServerEnabled", "TenoMoves_tgrabEnabled", "TenoMoves_tmortarEnabled", "TenoMoves_tstompEnabled",
	"TenoMoves_tleapEnabled", "TenoMovesModeRulesEnabled", "TenoMovesServerSquadEnabled"}) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, true) end
end
local function on(id)
	return script:GetAttribute("TenoMovesServerEnabled") ~= false and script:GetAttribute("TenoMoves_" .. id .. "Enabled") ~= false
end
local function now() return workspace:GetServerTimeNow() end
local function count(k, n) script:SetAttribute(k, (script:GetAttribute(k) or 0) + (n or 1)) end
local function num(m, k, d) return tonumber(m:GetAttribute(k)) or d end
local function flat(v) return Vector3.new(v.X, 0, v.Z) end
local function rootOf(m) return m:FindFirstChild("HumanoidRootPart") end

local ModeRules = require(ServerStorage:WaitForChild("DinoArcade"):WaitForChild("ModeRules"))
local MODE = ModeRules.currentMode()
script:SetAttribute("TenoMovesMode", MODE)
local squadMod
local function squadmate(a, b)
	if script:GetAttribute("TenoMovesServerSquadEnabled") == false then return false end
	if not squadMod then
		local arc = ServerStorage:FindFirstChild("DinoArcade")
		local m = arc and arc:FindFirstChild("SquadRules")
		if not m then return false end
		local ok, mod = pcall(require, m)
		if not ok then return false end
		squadMod = mod
	end
	if squadMod.sameChar(a, b) then
		count("TenoMovesSquadSkips")
		return true
	end
	return false
end
local function mayAffect(source, target)
	if squadmate(source, target) then return false end
	if script:GetAttribute("TenoMovesModeRulesEnabled") == false then return true end
	local tpl = Players:GetPlayerFromCharacter(target)
	local spl = Players:GetPlayerFromCharacter(source)
	local inMenu = tpl ~= nil and tpl:GetAttribute("InMenu") == true
	return ModeRules.canAffect(spl ~= nil, tpl ~= nil, inMenu, MODE)
end

local function remote(name)
	local r = ReplicatedStorage:FindFirstChild(name)
	if not r then
		r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = ReplicatedStorage
	end
	return r
end
local grabRemote, mortarRemote = remote("DinoTenoGrabRequest"), remote("DinoTenoMortarRequest")
local stompRemote, leapRemote = remote("DinoTenoStompRequest"), remote("DinoTenoLeapRequest")

-- targets ------------------------------------------------------------------------------------------------------------------
local function isTarget(m, self)
	if not (m:IsA("Model") and m ~= self and m:IsDescendantOf(workspace)) then return false end
	if not m:FindFirstChild("Hitboxes") or m:GetAttribute("Bitable") ~= true then return false end
	if m:GetAttribute("Species") == nil and m:GetAttribute("IsBot") ~= true then return false end
	if m:GetAttribute("DummyState") == "ko" then return false end
	local hum = m:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health <= 0 then return false end
	return rootOf(m) ~= nil
end
local function bots()
	local isl = workspace:FindFirstChild("DinoIsland")
	local f = isl and isl:FindFirstChild("Bots")
	return f and f:GetChildren() or {}
end
local function candidates(self)
	local list = {}
	for _, pl in ipairs(Players:GetPlayers()) do
		local c = pl.Character
		if c and isTarget(c, self) and mayAffect(self, c) then table.insert(list, c) end
	end
	for _, b in ipairs(bots()) do
		if isTarget(b, self) and mayAffect(self, b) then table.insert(list, b) end
	end
	return list
end
local function gap(m, pos) -- nearest distance from a point to the target's hitboxes
	local best = math.huge
	local hb = m:FindFirstChild("Hitboxes")
	for _, p in ipairs(hb and hb:GetChildren() or {}) do
		if p:IsA("BasePart") then
			local lp = p.CFrame:PointToObjectSpace(pos)
			local h = p.Size / 2
			local c = Vector3.new(math.clamp(lp.X, -h.X, h.X), math.clamp(lp.Y, -h.Y, h.Y), math.clamp(lp.Z, -h.Z, h.Z))
			best = math.min(best, (lp - c).Magnitude)
		end
	end
	if best == math.huge then
		local r = rootOf(m)
		best = r and (r.Position - pos).Magnitude or math.huge
	end
	return best
end
local function shielded(m, t) return num(m, "EnergyShieldUntil", 0) > t end
local function takenMul(m, t)
	local mul = 1
	local u, dm = m:GetAttribute("DebuffUntil"), m:GetAttribute("DebuffDamageTakenMul")
	if typeof(u) == "number" and typeof(dm) == "number" and t < u then mul = dm end
	if num(m, "DazedUntil", 0) > t then mul *= math.max(1, num(m, "DazedDamageMul", 1)) end
	if num(m, "StunBreakImmuneUntil", 0) > t then mul = 0 end
	return mul
end
local function damage(char, player, m, base, with, t)
	if shielded(m, t) then return 0 end
	local d = math.max(0, base) * takenMul(m, t)
	local hp = m:GetAttribute("DummyHealth")
	if typeof(hp) ~= "number" or d <= 0 then return 0 end
	local after = math.max(0, hp - d)
	m:SetAttribute("DummyHealth", after)
	if hp > 0 and after <= 0 then
		m:SetAttribute("KilledBy", char.Name)
		m:SetAttribute("KilledByUserId", player.UserId)
		m:SetAttribute("KilledWith", with)
		m:SetAttribute("KilledAt", t) -- last: KillRegenServer / TenoStatsServer react to this one
	end
	count("TenoMovesHits")
	return d
end
local function stun(m, untilT)
	m:SetAttribute("StunnedUntil", math.max(num(m, "StunnedUntil", 0), untilT))
end
local function latchedOnMe(m, char)
	if m:GetAttribute("PounceLatched") ~= true or m:GetAttribute("PounceMode") == "pin" then return false end
	local v = m:FindFirstChild("PounceLatchPart")
	return v and v:IsA("ObjectValue") and v.Value ~= nil and v.Value:IsDescendantOf(char) or false
end
local function latchedOnes(char)
	local out = {}
	local all = {}
	for _, pl in ipairs(Players:GetPlayers()) do if pl.Character then table.insert(all, pl.Character) end end
	for _, b in ipairs(bots()) do table.insert(all, b) end
	for _, m in ipairs(all) do
		if m ~= char and latchedOnMe(m, char) and mayAffect(char, m) then table.insert(out, m) end
	end
	return out
end

-- ground ---------------------------------------------------------------------------------------------------------------------
local fxFolder
local function fx()
	local root = workspace:FindFirstChild("DinoFX")
	if not root then
		root = Instance.new("Folder")
		root.Name = "DinoFX"
		root.Parent = workspace
	end
	if not (fxFolder and fxFolder.Parent) then
		fxFolder = root:FindFirstChild("TenoMovesFX") or Instance.new("Folder")
		fxFolder.Name = "TenoMovesFX"
		fxFolder.Parent = root
	end
	return fxFolder
end
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
local function groundY(pos, fallback)
	local ex = {}
	for _, pl in ipairs(Players:GetPlayers()) do if pl.Character then table.insert(ex, pl.Character) end end
	local isl = workspace:FindFirstChild("DinoIsland")
	for _, n in ipairs({"Bots", "TallGrass"}) do
		local f = isl and isl:FindFirstChild(n)
		if f then table.insert(ex, f) end
	end
	for _, n in ipairs({"DinoFX_Local", "DinoFX", "TenoFX"}) do
		local f = workspace:FindFirstChild(n)
		if f then table.insert(ex, f) end
	end
	rayParams.FilterDescendantsInstances = ex
	local g = workspace:Raycast(Vector3.new(pos.X, pos.Y + 60, pos.Z), Vector3.new(0, -200, 0), rayParams)
	return g and g.Position.Y or fallback
end
local function onGround(p) return Vector3.new(p.X, groundY(p, p.Y), p.Z) end

-- slows -----------------------------------------------------------------------------------------------------------------------
local botSlow = {} -- [model] = {hum, untilT, mul, base, set, yielded}
local function slow(m, mul, untilT, t)
	if not (mul and mul < 1 and untilT and untilT > t) or shielded(m, t) then return end
	count("TenoMovesSlows")
	if Players:GetPlayerFromCharacter(m) then
		local cu, cm = num(m, "TenoSlowUntil", 0), num(m, "TenoSlowMul", 1)
		if cu <= t then cm = 1 end
		m:SetAttribute("TenoSlowMul", math.min(cm, mul))
		m:SetAttribute("TenoSlowUntil", math.max(cu, untilT))
		return
	end
	local hum = m:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	local e = botSlow[m]
	if e then
		e.untilT, e.mul = math.max(e.untilT, untilT), math.min(e.mul, mul)
	else
		botSlow[m] = {hum = hum, untilT = untilT, mul = mul}
	end
end
RunService.Stepped:Connect(function()
	local t = now()
	for m, e in pairs(botSlow) do
		local hum = e.hum
		if not m.Parent or not hum.Parent then
			botSlow[m] = nil
		elseif m:GetAttribute("TenoSlowed") == true then -- TenoAttackServer is slowing it: give the speed back and wait
			if e.set ~= nil and e.base and math.abs(hum.WalkSpeed - e.set) <= 1e-3 then hum.WalkSpeed = e.base end
			e.set = nil
			if t >= e.untilT then
				botSlow[m] = nil
				m:SetAttribute("TenoMoveSlowed", false)
			end
		else
			local cur = hum.WalkSpeed
			if e.set == nil or math.abs(cur - e.set) > 1e-3 then e.base = cur end
			if t < e.untilT then
				e.set = e.base * math.clamp(e.mul, 0.05, 1)
				hum.WalkSpeed = e.set
				if m:GetAttribute("TenoMoveSlowed") ~= true then m:SetAttribute("TenoMoveSlowed", true) end
			else
				hum.WalkSpeed = e.base
				m:SetAttribute("TenoMoveSlowed", false)
				botSlow[m] = nil
			end
		end
	end
end)

-- request checks ----------------------------------------------------------------------------------------------------------------
local leapState = {} -- [char] = {charges, max, refills = {times}}
local function check(player, stamp, id, prefix, opts)
	local char = player.Character
	if not char then return nil end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local t = now()
	local r
	if typeof(stamp) ~= "number" or stamp ~= stamp or (opts.aim and (typeof(opts.aimDir) ~= "Vector3" or opts.aimDir.Magnitude < 0.5
		or opts.aimDir.Magnitude > 1.5)) then
		r = "badArg"
	elseif not hum or hum.Health <= 0 or not rootOf(char) then
		r = "dead"
	elseif not on(id) or char:GetAttribute(prefix .. "Enabled") ~= true then
		r = "disabled"
	elseif player:GetAttribute("InMenu") == true then
		r = "menu"
	elseif num(char, "StunnedUntil", 0) > t then
		r = "stunned"
	elseif char:GetAttribute("PinHeld") == true then
		r = "pinned"
	elseif num(char, "DazedUntil", 0) > t then
		r = "dazed"
	elseif opts.leap and num(char, "TenoLeapUntil", 0) > t then
		r = "active"
	end
	if not r and t < num(char, prefix .. "ReadyAt", 0) then r = "cooldown" end
	if r then
		char:SetAttribute(prefix .. "ServerResult", r)
		char:SetAttribute(prefix .. "ServerResultAt", t)
		return nil
	end
	return char, t
end
local function ok(char, prefix, t, setCooldown)
	char:SetAttribute(prefix .. "ServerResult", "ok")
	char:SetAttribute(prefix .. "ServerResultAt", t)
	if setCooldown ~= false then char:SetAttribute(prefix .. "ReadyAt", t + math.max(0.5, num(char, prefix .. "Cooldown", 15))) end
end

-- Tail Grab & Fling ---------------------------------------------------------------------------------------------------------------
local SMALL = {Raptor = true, Herrera = true}
local BIG = {Pachy = true, Teno = true}
local function speciesOf(m) return m:GetAttribute("Species") or m:GetAttribute("BotSpecies") end
local function tailPoints(char)
	local sc = char:GetScale()
	local pts = {}
	for i = 1, 5 do
		local p = char:FindFirstChild("Tail" .. i .. "_main", true)
		if p and p:IsA("BasePart") then table.insert(pts, p.Position) end
	end
	local tip = char:FindFirstChild("Tail5_main", true)
	if tip and tip:IsA("BasePart") then table.insert(pts, (tip.CFrame * CFrame.new(-1.6 * sc, 0, 0)).Position) end
	return pts, tip
end
local function pickGrab(char, t)
	local root = rootOf(char)
	local range = num(char, "TenoGrabRange", 0)
	local big = char:GetAttribute("TenoGrabBig") == true
	local pts = tailPoints(char)
	local best, bestD
	local pool = candidates(char)
	for _, m in ipairs(pool) do
		local sp = speciesOf(m)
		local mr = rootOf(m)
		local okSize = SMALL[sp] or (big and BIG[sp])
		if okSize and not shielded(m, t) and (not mr.Anchored or latchedOnMe(m, char)) then
			local lp = root.CFrame:PointToObjectSpace(mr.Position)
			if lp.Z >= 0 or latchedOnMe(m, char) then -- behind or beside the hips
				local d = math.huge
				for _, p in ipairs(pts) do d = math.min(d, gap(m, p)) end
				if d <= range and (not bestD or d < bestD) then best, bestD = m, d end
			end
		end
	end
	return best
end
local function flyBot(m, hrp, from, to, dur, peak, rot)
	local t0 = os.clock()
	while m.Parent and hrp.Parent do
		local u = math.min(1, (os.clock() - t0) / dur)
		local pos = from:Lerp(to, u) + Vector3.new(0, 4 * peak * u * (1 - u), 0)
		hrp.CFrame = CFrame.new(pos) * rot * CFrame.Angles(2 * math.pi * u, 0, 0)
		if u >= 1 then break end
		RunService.Heartbeat:Wait()
	end
end
grabRemote.OnServerEvent:Connect(function(player, stamp)
	local char, t = check(player, stamp, "tgrab", "TenoGrab", {})
	if not char then return end
	local target = pickGrab(char, t)
	if not target then
		char:SetAttribute("TenoGrabServerResult", "noTarget")
		char:SetAttribute("TenoGrabServerResultAt", t)
		return
	end
	ok(char, "TenoGrab", t)
	count("TenoMovesGrabs")
	local sc = char:GetScale()
	local fling = num(char, "TenoGrabFling", 30)
	local dmg, stunT = num(char, "TenoGrabDamage", 8), num(char, "TenoGrabStun", 1)
	local crash, crashR = num(char, "TenoGrabCrash", 0), num(char, "TenoGrabCrashRadius", 0)
	char:SetAttribute("TenoGrabTarget", target.Name)
	char:SetAttribute("TenoGrabCrashHits", 0)
	char:SetAttribute("TenoGrabStartedAt", t) -- last: poses / FX
	target:SetAttribute("TenoGrabbedBy", char.Name)
	target:SetAttribute("TenoGrabbedAt", t)
	local isPlayer = Players:GetPlayerFromCharacter(target) ~= nil
	local latched = latchedOnMe(target, char)
	if latched then
		target:SetAttribute("ShakeOffReason", "grabbed")
		target:SetAttribute("ShakeOffAt", t) -- last: PounceServer / BotServer release the latch
	end
	stun(target, t + GRAB_CATCH + GRAB_CARRY + FLING_TIME + stunT)
	local hrp0 = rootOf(target)
	local lift = math.clamp(hrp0.Position.Y - groundY(hrp0.Position, hrp0.Position.Y - 3), 1, 12) -- its root height over the ground (a latched raptor: capped), kept on landing
	task.spawn(function()
		task.wait(GRAB_CATCH)
		if latched then
			local w0 = os.clock()
			while target.Parent and target:GetAttribute("PounceLatched") == true and os.clock() - w0 < 0.5 do RunService.Heartbeat:Wait() end
		end
		local hrp, root = rootOf(target), rootOf(char)
		if not (hrp and root and char.Parent and target.Parent) then return end
		local _, tip = tailPoints(char)
		-- carry (bots ride the tail tip; a player stays stunned where it is)
		if not isPlayer then
			hrp.Anchored = true
			local c0 = os.clock()
			while os.clock() - c0 < GRAB_CARRY and target.Parent and tip and tip.Parent do
				hrp.CFrame = CFrame.new((tip.CFrame * CFrame.new(-2.0 * sc, -0.6 * sc, 0)).Position - Vector3.new(0, 5, 0)) * (hrp.CFrame - hrp.Position)
				RunService.Heartbeat:Wait()
			end
		else
			task.wait(GRAB_CARRY)
		end
		if not (target.Parent and root.Parent) then return end
		-- throw
		local fwd = flat(root.CFrame.LookVector)
		fwd = fwd.Magnitude > 1e-3 and fwd.Unit or -Vector3.zAxis
		local start = hrp.Position
		local land = onGround(root.Position + fwd * fling)
		local landPos = land + Vector3.new(0, lift, 0)
		local throwAt = now()
		char:SetAttribute("TenoGrabThrowAt", throwAt)
		char:SetAttribute("TenoGrabLand", land)
		if isPlayer then
			local dir = flat(landPos - start)
			local dist = dir.Magnitude
			dir = dist > 1e-3 and dir.Unit or fwd
			target:SetAttribute("StunTossFrom", start - dir * 2)
			target:SetAttribute("StunTossDistance", dist)
			target:SetAttribute("StunTossAt", throwAt) -- last: StunClient throws it
			task.wait(FLING_TIME)
		else
			hrp.Anchored = true
			flyBot(target, hrp, start, landPos, FLING_TIME, FLING_PEAK, CFrame.lookAt(Vector3.zero, -fwd))
			if target.Parent then
				hrp.CFrame = CFrame.new(landPos) * CFrame.lookAt(Vector3.zero, -fwd)
				hrp.Anchored = false
			end
		end
		local tl = now()
		char:SetAttribute("TenoGrabLandAt", tl)
		if target.Parent then
			damage(char, player, target, dmg, "tailgrab", tl)
			if not shielded(target, tl) then stun(target, tl + stunT) end
		end
		if crash > 0 and crashR > 0 then
			local n = 0
			for _, m in ipairs(candidates(char)) do
				local mr = rootOf(m)
				if m ~= target and flat(mr.Position - land).Magnitude <= crashR and math.abs(mr.Position.Y - land.Y) <= DY then
					damage(char, player, m, crash, "tailgrab", tl)
					if not shielded(m, tl) then stun(m, tl + 1) end
					n += 1
				end
			end
			char:SetAttribute("TenoGrabCrashHits", n)
		end
	end)
end)

-- Boulder Mortar --------------------------------------------------------------------------------------------------------------------
local function boulder(from, to)
	local b = Instance.new("Part")
	b.Name = "TenoBoulder"
	b.Shape = Enum.PartType.Ball
	b.Size = Vector3.one * 2.8
	b.Material, b.Color = Enum.Material.Slate, Color3.fromRGB(138, 132, 120)
	b.Anchored, b.CanCollide, b.CanQuery, b.CanTouch = true, false, false, false
	b.CFrame = CFrame.new(from)
	b.Parent = fx()
	local peak = math.max(from.Y, to.Y) + MORTAR_PEAK
	task.spawn(function()
		local t0 = os.clock()
		while b.Parent do
			local u = math.min(1, (os.clock() - t0) / MORTAR_FLIGHT)
			local base = from:Lerp(to, u)
			local y0 = from.Y + (to.Y - from.Y) * u
			local arc = 4 * (peak - math.max(from.Y, to.Y)) * u * (1 - u)
			b.CFrame = CFrame.new(base.X, y0 + arc, base.Z) * CFrame.Angles(u * 9, u * 5, 0)
			if u >= 1 then break end
			RunService.Heartbeat:Wait()
		end
		b:Destroy()
	end)
end
local function rubblePatch(char, player, pt, r, untilT, mul)
	local p = Instance.new("Part")
	p.Name = "TenoRubble"
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(0.3, r * 2, r * 2)
	p.CFrame = CFrame.new(pt + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, 0, math.rad(90))
	p.Material, p.Color = Enum.Material.Slate, Color3.fromRGB(106, 92, 68)
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p:SetAttribute("Until", untilT)
	p.Parent = fx()
	for i = 1, 10 do
		local s = 0.8 + ((i * 37) % 10) / 10
		local a, rr = i * 2.399, r * 0.85 * math.sqrt(i / 10)
		local q = Instance.new("Part")
		q.Name = "RubbleRock"
		q.Size = Vector3.new(s, s * 0.6, s)
		q.CFrame = CFrame.new(pt + Vector3.new(math.cos(a) * rr, s * 0.3, math.sin(a) * rr)) * CFrame.Angles(0, a, 0)
		q.Material, q.Color = Enum.Material.Slate, Color3.fromRGB(138, 132, 120)
		q.Anchored, q.CanCollide, q.CanQuery, q.CanTouch = true, false, false, false
		q.Parent = p
	end
	task.spawn(function()
		while p.Parent and now() < untilT do
			local t = now()
			if char.Parent then
				for _, m in ipairs(candidates(char)) do
					local mr = rootOf(m)
					if flat(mr.Position - pt).Magnitude <= r and math.abs(mr.Position.Y - pt.Y) <= DY then slow(m, mul, t + 0.3, t) end
				end
			end
			task.wait(0.2)
		end
		p:Destroy()
	end)
end
mortarRemote.OnServerEvent:Connect(function(player, stamp, aimDir)
	local char, t = check(player, stamp, "tmortar", "TenoMortar", {aim = true, aimDir = aimDir})
	if not char then return end
	ok(char, "TenoMortar", t)
	count("TenoMovesMortars")
	local root = rootOf(char)
	local sc = char:GetScale()
	local aim = flat(aimDir)
	aim = aim.Magnitude > 1e-3 and aim.Unit or flat(root.CFrame.LookVector).Unit
	local range, miss = num(char, "TenoMortarRange", 60), num(char, "TenoMortarMiss", 45)
	local cone = math.rad(math.clamp(num(char, "TenoMortarCone", 30), 1, 180))
	local best, bestD
	for _, m in ipairs(candidates(char)) do
		local v = flat(rootOf(m).Position - root.Position)
		local d = v.Magnitude
		if d > 1e-3 and d <= range and math.acos(math.clamp(aim:Dot(v.Unit), -1, 1)) <= cone and (not bestD or d < bestD) then best, bestD = m, d end
	end
	local centre = best and onGround(rootOf(best).Position) or onGround(root.Position + aim * miss)
	local right = aim:Cross(Vector3.yAxis).Unit
	local pts = num(char, "TenoMortarCount", 1) >= 2 and {onGround(centre + right * MORTAR_PAIR), onGround(centre - right * MORTAR_PAIR)} or {centre}
	local splash, dmg = num(char, "TenoMortarSplash", 10), num(char, "TenoMortarDamage", 12)
	local smul, stime, rubble = num(char, "TenoMortarSlowMul", 1), num(char, "TenoMortarSlowTime", 0), num(char, "TenoMortarRubble", 0)
	char:SetAttribute("TenoMortarTarget", best and best.Name or "")
	char:SetAttribute("TenoMortarLand", centre)
	char:SetAttribute("TenoMortarHits", 0)
	char:SetAttribute("TenoMortarStartedAt", t) -- last: poses / FX
	task.delay(MORTAR_FIRE, function()
		if not char.Parent then return end
		local tail = char:FindFirstChild("Tail3_main", true)
		local from = (tail and tail:IsA("BasePart")) and (tail.CFrame * CFrame.new(0.1 * sc, 1.1 * sc, 0)).Position or root.Position + Vector3.new(0, 6, 0)
		char:SetAttribute("TenoMortarFiredAt", now())
		for _, pt in ipairs(pts) do boulder(from, pt) end
		task.wait(MORTAR_FLIGHT)
		local tl = now()
		local hit, n = {}, 0
		for _, m in ipairs(candidates(char)) do
			local mr = rootOf(m)
			for _, pt in ipairs(pts) do
				if not hit[m] and flat(mr.Position - pt).Magnitude <= splash and math.abs(mr.Position.Y - pt.Y) <= DY then
					hit[m] = true
					n += 1
					damage(char, player, m, dmg, "mortar", tl)
					slow(m, smul, tl + stime, tl)
				end
			end
		end
		char:SetAttribute("TenoMortarHits", n)
		char:SetAttribute("TenoMortarLandedAt", tl)
		if rubble > 0 and smul < 1 then
			for _, pt in ipairs(pts) do rubblePatch(char, player, pt, splash * 0.8, tl + rubble, smul) end
		end
	end)
end)

-- Stomp Shockwave ---------------------------------------------------------------------------------------------------------------------
stompRemote.OnServerEvent:Connect(function(player, stamp)
	local char, t = check(player, stamp, "tstomp", "TenoStomp", {})
	if not char then return end
	ok(char, "TenoStomp", t)
	count("TenoMovesStomps")
	local range, dmg, stunT, noJump = num(char, "TenoStompRange", 14), num(char, "TenoStompDamage", 6), num(char, "TenoStompStun", 0.5),
		num(char, "TenoStompNoJump", 0)
	char:SetAttribute("TenoStompHits", 0)
	char:SetAttribute("TenoStompStartedAt", t)
	task.delay(STOMP_HIT, function()
		local root = rootOf(char)
		local hum = char:FindFirstChildOfClass("Humanoid")
		if not (char.Parent and root and hum and hum.Health > 0) then return end
		local tl = now()
		local hl, hr = char:FindFirstChild("ArmL_hand", true), char:FindFirstChild("ArmR_hand", true)
		local mid = (hl and hr) and (hl.Position + hr.Position) / 2 or (root.Position + flat(root.CFrame.LookVector) * 6)
		local centre = onGround(mid)
		local drain = num(char, "TenoStompLatchDrain", 0)
		local drained = 0
		for _, m in ipairs(latchedOnes(char)) do
			if script:GetAttribute("TenoMovesStompDrainEnabled") == false then
				m:SetAttribute("ShakeOffReason", "stomped")
				m:SetAttribute("ShakeOffAt", tl)
			elseif drain > 0 then -- v1.1: star drains the latch's stamina
				m:SetAttribute("StaminaDrainAmount", drain)
				m:SetAttribute("StaminaDrainAt", tl) -- last: StaminaServer / BotServer react
				drained += 1
			end
		end
		char:SetAttribute("TenoStompDrained", drained)
		local n = 0
		for _, m in ipairs(candidates(char)) do
			local mr = rootOf(m)
			if not latchedOnMe(m, char) and gap(m, centre) <= range and math.abs(mr.Position.Y - centre.Y) <= DY then
				n += 1
				damage(char, player, m, dmg, "stomp", tl)
				if not shielded(m, tl) then
					stun(m, tl + stunT)
					if noJump > 0 then m:SetAttribute("NoJumpUntil", math.max(num(m, "NoJumpUntil", 0), tl + noJump)) end
				end
			end
		end
		char:SetAttribute("TenoStompCenter", centre)
		char:SetAttribute("TenoStompHits", n)
		char:SetAttribute("TenoStompAt", tl) -- last: FX
	end)
end)

-- Hydraulic Leap ----------------------------------------------------------------------------------------------------------------------
local function leapPublish(char, st, t)
	char:SetAttribute("TenoLeapChargesLeft", st.charges)
	local nextAt = st.refills[1]
	char:SetAttribute("TenoLeapRefillAt", nextAt or 0)
	char:SetAttribute("TenoLeapReadyAt", st.charges > 0 and t or (nextAt or t))
end
local function leapStateOf(char, t)
	local mx = math.max(0, math.floor(num(char, "TenoLeapCharges", 0)))
	local st = leapState[char]
	if not st or st.max ~= mx then
		st = {charges = mx, max = mx, refills = {}}
		leapState[char] = st
		leapPublish(char, st, t)
	end
	return st
end
RunService.Heartbeat:Connect(function()
	local t
	for char, st in pairs(leapState) do
		if not char.Parent then
			leapState[char] = nil
		elseif st.refills[1] and (t or now()) >= st.refills[1] then
			t = t or now()
			table.remove(st.refills, 1)
			st.charges = math.min(st.max, st.charges + 1)
			leapPublish(char, st, t)
		end
	end
end)
leapRemote.OnServerEvent:Connect(function(player, stamp)
	local c0 = player.Character
	if c0 and c0:GetAttribute("TenoLeapEnabled") == true then
		local st = leapStateOf(c0, now())
		leapPublish(c0, st, now())
	end
	local char, t = check(player, stamp, "tleap", "TenoLeap", {leap = true})
	if not char then return end
	local st = leapStateOf(char, t)
	if st.charges <= 0 then
		char:SetAttribute("TenoLeapServerResult", "cooldown")
		char:SetAttribute("TenoLeapServerResultAt", t)
		return
	end
	ok(char, "TenoLeap", t, false)
	count("TenoMovesLeaps")
	st.charges -= 1
	local cd = math.max(0.5, num(char, "TenoLeapCooldown", 14))
	local last = st.refills[#st.refills]
	table.insert(st.refills, math.max(t, last or t) + cd)
	leapPublish(char, st, t)
	local dist, dmg, radius, stunT = num(char, "TenoLeapDist", 40), num(char, "TenoLeapDamage", 10), num(char, "TenoLeapRadius", 12),
		num(char, "TenoLeapStun", 0)
	char:SetAttribute("TenoLeapDistNow", dist)
	char:SetAttribute("TenoLeapFlightTime", LEAP_TIME)
	char:SetAttribute("TenoLeapUntil", t + LEAP_TIME + 0.8)
	char:SetAttribute("TenoLeapHits", 0)
	char:SetAttribute("TenoLeapStartedAt", t) -- last: TenoLeapLaunch launches the body
	local r0 = rootOf(char)
	local h0 = r0.Position.Y - groundY(r0.Position, r0.Position.Y - 3) -- standing height over the ground
	task.spawn(function()
		local hum = char:FindFirstChildOfClass("Humanoid")
		local w0 = os.clock()
		while char.Parent and hum and hum.Parent and os.clock() - w0 < LEAP_TIME + 0.8 do
			local rr = rootOf(char)
			if os.clock() - w0 >= LEAP_TIME * 0.6 and rr and rr.Position.Y - groundY(rr.Position, rr.Position.Y - 3) <= h0 + 1.5 then break end
			RunService.Heartbeat:Wait()
		end
		local root = rootOf(char)
		if not (char.Parent and root and hum and hum.Health > 0) then
			if char.Parent then char:SetAttribute("TenoLeapUntil", 0) end
			return
		end
		local tl = now()
		local n = 0
		for _, m in ipairs(candidates(char)) do
			local mr = rootOf(m)
			if gap(m, root.Position) <= radius and math.abs(mr.Position.Y - root.Position.Y) <= DY then
				n += 1
				damage(char, player, m, dmg, "leap", tl)
				if stunT > 0 and not shielded(m, tl) then stun(m, tl + stunT) end
			end
		end
		char:SetAttribute("TenoLeapHits", n)
		char:SetAttribute("TenoLeapUntil", 0)
		char:SetAttribute("TenoLeapLandedAt", tl) -- last: FX
	end)
end)

-- leap charges: publish for MechaButtons as soon as the part turns on / changes
local function watch(char)
	local function refresh()
		if char:GetAttribute("TenoLeapEnabled") == true then
			local t = now()
			leapPublish(char, leapStateOf(char, t), t)
		end
	end
	char:GetAttributeChangedSignal("TenoLeapEnabled"):Connect(refresh)
	char:GetAttributeChangedSignal("TenoLeapCharges"):Connect(refresh)
	task.defer(refresh)
end
local function onPlayer(p)
	p.CharacterAdded:Connect(watch)
	if p.Character then watch(p.Character) end
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do onPlayer(p) end
