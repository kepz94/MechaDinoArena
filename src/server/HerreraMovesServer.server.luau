-- HerreraMovesServer v1.0 (Mecha Dino Arena) — the moves of the Herrera's keyed mecha parts (pass 2): Quill Launcher
-- (MDA-151), Smoke Pods (MDA-152), Strobe Frill (MDA-155), Stun Breaker (MDA-156), and the Glider Wings' glide state
-- (MDA-150). Plan docs/plans/HERRERA_PARTS_v1.0.md (Parts 2, 3, 4, 7, 8 and "Pass 2 — build map"); Kepu 2026-10-31.
-- Settings come from the character (SkillEffects 1.27, a Herrera with the part bought AND slotted):
--   QuillEnabled / QuillCount / QuillDamage / QuillRange / QuillCooldown, SmokeEnabled / SmokeRadius / SmokeTime /
--   SmokeRunMul / SmokeSlowMul / SmokeCooldown, StrobeEnabled / StrobeAngle / StrobeRange / StrobeDaze / StrobeDazedMul /
--   StrobeCooldown, BreakerEnabled / BreakerPush / BreakerCooldown / BreakerImmune, GliderEnabled / GliderDrop.
-- Remotes (ReplicatedStorage, created here): DinoQuillRequest(stamp, aimDir), DinoSmokeRequest(stamp),
--   DinoStrobeRequest(stamp), DinoBreakerRequest(stamp) (MechaButtons 1.24), DinoGlideRequest(on) (GliderTest 1.0).
-- Request checks, first failing wins (character <Prefix>ServerResult + <Prefix>ServerResultAt):
--   quills / strobe: "badArg", "dead", "disabled", "menu", "stunned", "pinned", "dazed", "cooldown", "ok".
--   smoke:           "badArg", "dead", "disabled", "menu", "stunned", "pinned", "cooldown", "ok".
--   breaker:         "badArg", "dead", "disabled", "menu", "notStunned" (StunnedUntil <= now and PinHeld not true),
--                    "cooldown", "ok".
--   Every ok starts the cooldown: <Prefix>ReadyAt = now + <Prefix>Cooldown.
-- Who can be hit (quills, smoke slow, strobe, breaker push): Workspace models with a Hitboxes folder, Bitable true, a
--   Species or IsBot, not self, not KO, alive; players only where ModeRules.canAffect allows (the Arena), bots always.
-- Quill Launcher: target = the allowed dino whose root is nearest the aim inside a 35-degree flat cone around the camera
--   heading, within QuillRange x scale, in line of sight (the world blocks). None -> the quills fly straight ahead
--   QuillRange x scale ("miss"). QuillCount quills leave one every QUILL_GAP (0.045) s at QUILL_SPEED (90) studs/s; each
--   that arrives on a live, unshielded target does QuillDamage x roar debuff x daze star x Stun Breaker immunity off
--   DummyHealth (a killing blow stamps KilledBy / KilledByUserId / KilledWith "quills" / KilledAt). No bleed, no slow.
--   Shooter: QuillResult ("hit" / "miss"), QuillTarget (name or ""), QuillShot (count), QuillAimEnd, QuillFlightTime (s
--   for the first quill), QuillStartedAt (last; HerreraMovesFX draws the volley), then QuillLanded (hits),
--   QuillTotalDamage, QuillLandedAt (last). Target QuillHitAt / QuillHitBy.
-- Smoke Pods: the cloud stays at the drop point: SmokeCenter, SmokeRadiusNow (SmokeRadius x scale), SmokeUntil
--   (now + SmokeTime), SmokeStartedAt (last). Every SMOKE_TICK (0.1 s): the owner's root inside -> SmokeHidden true (bots
--   drop it, BotServer 1.22; other players' screens hide its BillboardGuis, TreeTopHide 1.1) and, with SmokeRunMul > 1,
--   SmokeRunUntil = the cloud's end (SprintTest 1.15); outside / over -> SmokeHidden false, SmokeRunUntil 0. When the owner
--   goes hidden, each bot whose BotTarget is this player gets SmokeLostAt (the "?" pop). Star (SmokeSlowMul < 1): every
--   allowed enemy inside: a player gets SmokeSlowUntil (the cloud's end) / SmokeSlowMul (SprintTest 1.15), cleared to 0
--   on leaving; a bot's WalkSpeed is scaled while inside (MineServer's pattern, BotServer untouched; SmokeSlowed).
-- Strobe Frill: the flash lands STROBE_WINDUP (0.15) s after the request (the rear-up), from the root's position and
--   facing at that moment: every allowed enemy whose root is within StrobeRange x scale and within StrobeAngle / 2 of the
--   facing (flat) and has no Energy Shield up is dazed: DazedUntil = max(old, now + StrobeDaze), DazedDamageMul =
--   StrobeDazedMul (1.2 at star; the higher one while an older daze runs), DazedBy, DazedAt (last). Dazed = the attack
--   servers refuse ("dazed") and bots start no attack; the damage multiplier is read by BoneCrest 1.4 / SlashServer 1.5
--   / HeadbuttServer 1.11 / HookServer 1.7 / the quills. Owner StrobeStartedAt (request), StrobeAt (flash, last),
--   StrobeHits (dinos dazed by the last flash).
-- Stun Breaker: StunnedUntil = now; when PinHeld, the pinner (PinnedBy, a player character) gets ShakeOffReason
--   "breaker" + ShakeOffAt now (PounceServer releases the pin); II (BreakerPush > 0): every allowed enemy within
--   BreakerPush x scale is pushed BreakerPush x scale straight away over BREAK_PUSH_TIME (0.3) s (a player:
--   HeadbuttShove*; a bot latched on someone: shaken off; another bot: slid); star (BreakerImmune > 0):
--   StunBreakImmuneUntil = now + BreakerImmune (BoneCrest 1.4 / SlashServer 1.5 / HeadbuttServer 1.11 / HookServer 1.7 /
--   the quills deal 0). Owner BreakerAt (last), BreakerPushed (count).
-- Glide: DinoGlideRequest(true) with GliderEnabled -> Gliding true, GlideStartedAt; (false), GliderEnabled off, death
--   -> Gliding false, GlideEndedAt. HerreraPartsServer 1.2 opens the wings; SlashServer 1.5 takes a dive while gliding.
-- Switches: script attributes HerreraMovesServerEnabled (default true, read at each request), HerreraMoves_quillsEnabled,
--   HerreraMoves_smokeEnabled, HerreraMoves_strobeEnabled, HerreraMoves_breakerEnabled, HerreraMoves_gliderEnabled
--   (default true each), HerreraMovesModeRulesEnabled (default true; false = players can always be hit).
-- Diagnostics: script HerreraMovesServerVersion, HerreraMovesMode, QuillVolleys, QuillHits, SmokeClouds, StrobeFlashes,
--   StrobeDazes, BreakerBreaks; character results above.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local VERSION = "1.0"
local QUILL_GAP, QUILL_SPEED, QUILL_CONE = 0.045, 90, math.rad(35)
local SMOKE_TICK = 0.1
local STROBE_WINDUP = 0.15
local BREAK_PUSH_TIME = 0.3

script:SetAttribute("HerreraMovesServerVersion", VERSION)
for _, k in ipairs({"HerreraMovesServerEnabled", "HerreraMoves_quillsEnabled", "HerreraMoves_smokeEnabled",
	"HerreraMoves_strobeEnabled", "HerreraMoves_breakerEnabled", "HerreraMoves_gliderEnabled", "HerreraMovesModeRulesEnabled"}) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, true) end
end
local function on(id)
	return script:GetAttribute("HerreraMovesServerEnabled") ~= false and script:GetAttribute("HerreraMoves_" .. id .. "Enabled") ~= false
end
local function now() return workspace:GetServerTimeNow() end

local ModeRules = require(ServerStorage:WaitForChild("DinoArcade"):WaitForChild("ModeRules"))
local MODE = ModeRules.currentMode()
script:SetAttribute("HerreraMovesMode", MODE)
local function mayAffect(source, target)
	if script:GetAttribute("HerreraMovesModeRulesEnabled") == false then return true end
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
local quillRemote, smokeRemote = remote("DinoQuillRequest"), remote("DinoSmokeRequest")
local strobeRemote, breakerRemote, glideRemote = remote("DinoStrobeRequest"), remote("DinoBreakerRequest"), remote("DinoGlideRequest")

local function count(k, n) script:SetAttribute(k, (script:GetAttribute(k) or 0) + (n or 1)) end
local function num(m, k, d) return tonumber(m:GetAttribute(k)) or d end

-- targets (InkServer 1.4's rules) ------------------------------------------------------------------------------------
local function rootOf(m) return m:FindFirstChild("HumanoidRootPart") end
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
	for _, n in ipairs({"DinoFX_Local", "DinoFX", "HerreraPartsFX", "HerreraMovesFX"}) do
		local f = workspace:FindFirstChild(n)
		if f then table.insert(ex, f) end
	end
	worldParams.FilterDescendantsInstances = ex
	return worldParams
end
local function flat(v) return Vector3.new(v.X, 0, v.Z) end
local function shielded(m, t) return num(m, "EnergyShieldUntil", 0) > t end

-- damage taken multiplier: roar debuff x daze star x Stun Breaker star
local function takenMul(m, t)
	local mul = 1
	local u, dm = m:GetAttribute("DebuffUntil"), m:GetAttribute("DebuffDamageTakenMul")
	if typeof(u) == "number" and typeof(dm) == "number" and t < u then mul = dm end
	if num(m, "DazedUntil", 0) > t then mul *= math.max(1, num(m, "DazedDamageMul", 1)) end
	if num(m, "StunBreakImmuneUntil", 0) > t then mul = 0 end
	return mul
end
local function takeHealth(m, d, char, player, with, t)
	local hp = m:GetAttribute("DummyHealth")
	if typeof(hp) ~= "number" or d <= 0 then return false end
	local after = math.max(0, hp - d)
	m:SetAttribute("DummyHealth", after)
	if hp > 0 and after <= 0 then
		m:SetAttribute("KilledBy", char.Name)
		m:SetAttribute("KilledByUserId", player.UserId)
		m:SetAttribute("KilledWith", with)
		m:SetAttribute("KilledAt", t) -- last: KillRegenServer reacts to this one
		return true
	end
	return false
end

-- common request checks -------------------------------------------------------------------------------------------------
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
	elseif opts.breaker then
		if num(char, "StunnedUntil", 0) <= t and char:GetAttribute("PinHeld") ~= true then r = "notStunned" end
	elseif num(char, "StunnedUntil", 0) > t then
		r = "stunned"
	elseif char:GetAttribute("PinHeld") == true then
		r = "pinned"
	elseif opts.attack and num(char, "DazedUntil", 0) > t then
		r = "dazed"
	end
	if not r and t < num(char, prefix .. "ReadyAt", 0) then r = "cooldown" end
	char:SetAttribute(prefix .. "ServerResult", r or "ok")
	char:SetAttribute(prefix .. "ServerResultAt", t)
	if r then return nil end
	char:SetAttribute(prefix .. "ReadyAt", t + math.max(0.5, num(char, prefix .. "Cooldown", 15)))
	return char, t
end

-- Quill Launcher ------------------------------------------------------------------------------------------------------
quillRemote.OnServerEvent:Connect(function(player, stamp, aimDir)
	local char, t = check(player, stamp, "quills", "Quill", {attack = true, aim = true, aimDir = aimDir})
	if not char then return end
	local root = rootOf(char)
	local s = char:GetScale()
	local range = math.max(1, num(char, "QuillRange", 40)) * s
	local heading = flat(aimDir)
	if heading.Magnitude < 1e-3 then heading = flat(root.CFrame.LookVector) end
	heading = heading.Magnitude > 1e-3 and heading.Unit or Vector3.zAxis
	local origin = root.Position + Vector3.new(0, 1.2 * s, 0)
	local params = worldExclude()
	local best, bestAng
	for _, m in ipairs(candidates(char)) do
		local p = rootOf(m).Position
		local v = p - origin
		local fv = flat(v)
		if v.Magnitude <= range and fv.Magnitude > 1e-3 then
			local ang = math.acos(math.clamp(heading:Dot(fv.Unit), -1, 1))
			if ang <= QUILL_CONE and (not bestAng or ang < bestAng) and not workspace:Raycast(origin, v, params) then
				best, bestAng = m, ang
			end
		end
	end
	local n = math.max(1, math.floor(num(char, "QuillCount", 5)))
	local dmg = math.max(0, num(char, "QuillDamage", 4))
	local aimEnd = best and rootOf(best).Position or (origin + heading * range)
	local fly = (aimEnd - origin).Magnitude / QUILL_SPEED
	char:SetAttribute("QuillResult", best and "hit" or "miss")
	char:SetAttribute("QuillTarget", best and best.Name or "")
	char:SetAttribute("QuillShot", n)
	char:SetAttribute("QuillAimEnd", aimEnd)
	char:SetAttribute("QuillFlightTime", math.floor(fly * 1000 + 0.5) / 1000)
	char:SetAttribute("QuillStartedAt", t) -- last: HerreraMovesFX draws the volley
	count("QuillVolleys")
	if not best then return end
	local target = best
	local landed, total = 0, 0
	for i = 1, n do
		local launch = (i - 1) * QUILL_GAP
		task.delay(launch + fly, function()
			local ta = now()
			if target.Parent and isTarget(target, char) and not shielded(target, ta) then
				local d = math.floor(dmg * takenMul(target, ta) * 10 + 0.5) / 10
				if d > 0 then
					takeHealth(target, d, char, player, "quills", ta)
					landed += 1
					total += d
					count("QuillHits")
					target:SetAttribute("QuillHitBy", char.Name)
					target:SetAttribute("QuillHitAt", ta)
				end
			end
			if i == n and char.Parent then
				char:SetAttribute("QuillLanded", landed)
				char:SetAttribute("QuillTotalDamage", total)
				char:SetAttribute("QuillLandedAt", ta) -- last: the total pop
			end
		end)
	end
end)

-- Smoke Pods ----------------------------------------------------------------------------------------------------------
local clouds = {} -- [char] = {center, radius, untilT, player, runMul, slowMul, hidden, slowed = {[model] = true}}
local botSlow = {} -- [bot] = {hum, base, set, untilT, mul}
smokeRemote.OnServerEvent:Connect(function(player, stamp)
	local char, t = check(player, stamp, "smoke", "Smoke", {})
	if not char then return end
	local root = rootOf(char)
	local s = char:GetScale()
	local c = {center = root.Position, radius = math.max(1, num(char, "SmokeRadius", 12)) * s,
		untilT = t + math.max(0.5, num(char, "SmokeTime", 4)), player = player, runMul = num(char, "SmokeRunMul", 1),
		slowMul = num(char, "SmokeSlowMul", 1), slowed = {}}
	local old = clouds[char]
	if old then for m in pairs(old.slowed) do if m.Parent and Players:GetPlayerFromCharacter(m) then m:SetAttribute("SmokeSlowUntil", 0) end end end
	clouds[char] = c
	char:SetAttribute("SmokeCenter", c.center)
	char:SetAttribute("SmokeRadiusNow", c.radius)
	char:SetAttribute("SmokeUntil", c.untilT)
	char:SetAttribute("SmokeStartedAt", t) -- last: HerreraMovesFX puffs the cloud
	count("SmokeClouds")
end)

local function setHidden(char, c, hidden, t)
	if char:GetAttribute("SmokeHidden") == hidden then return end
	char:SetAttribute("SmokeHidden", hidden)
	if hidden then
		for _, b in ipairs(bots()) do
			if b:GetAttribute("BotTarget") == c.player.Name then b:SetAttribute("SmokeLostAt", t) end
		end
	end
end
local smokeAcc = 0
RunService.Heartbeat:Connect(function(dt)
	smokeAcc += dt
	if smokeAcc < SMOKE_TICK then return end
	smokeAcc = 0
	local t = now()
	for char, c in pairs(clouds) do
		local live = char.Parent and t < c.untilT and on("smoke") and char:GetAttribute("SmokeEnabled") == true
		local root = live and rootOf(char)
		local inside = root and (root.Position - c.center).Magnitude <= c.radius
		setHidden(char, c, inside and true or false, t)
		local runU = (inside and c.runMul > 1) and c.untilT or 0
		if char.Parent and char:GetAttribute("SmokeRunUntil") ~= runU then char:SetAttribute("SmokeRunUntil", runU) end
		-- star: enemies inside
		local now_in = {}
		if live and c.slowMul < 1 then
			for _, m in ipairs(candidates(char)) do
				if (rootOf(m).Position - c.center).Magnitude <= c.radius then now_in[m] = true end
			end
		end
		for m in pairs(now_in) do
			if Players:GetPlayerFromCharacter(m) then
				if m:GetAttribute("SmokeSlowUntil") ~= c.untilT then
					m:SetAttribute("SmokeSlowMul", c.slowMul)
					m:SetAttribute("SmokeSlowUntil", c.untilT)
				end
			else
				local hum = m:FindFirstChildOfClass("Humanoid")
				if hum then
					local e = botSlow[m] or {hum = hum}
					e.untilT, e.mul = t + SMOKE_TICK * 2.5, c.slowMul
					botSlow[m] = e
				end
			end
		end
		for m in pairs(c.slowed) do
			if not now_in[m] and m.Parent and Players:GetPlayerFromCharacter(m) then m:SetAttribute("SmokeSlowUntil", 0) end
		end
		c.slowed = now_in
		if not live then
			for m in pairs(c.slowed) do if m.Parent and Players:GetPlayerFromCharacter(m) then m:SetAttribute("SmokeSlowUntil", 0) end end
			if char.Parent then
				char:SetAttribute("SmokeHidden", false)
				char:SetAttribute("SmokeRunUntil", 0)
			end
			clouds[char] = nil
		end
	end
end)
-- bots: scale the AI's WalkSpeed while inside a star cloud (MineServer 1.1's pattern, BotServer untouched)
RunService.Stepped:Connect(function()
	local t = now()
	for m, e in pairs(botSlow) do
		local hum = e.hum
		if not m.Parent or not hum.Parent then
			botSlow[m] = nil
		else
			local cur = hum.WalkSpeed
			if e.set == nil or math.abs(cur - e.set) > 1e-3 then e.base = cur end
			if t < e.untilT then
				e.set = e.base * math.clamp(e.mul, 0.05, 1)
				hum.WalkSpeed = e.set
				if m:GetAttribute("SmokeSlowed") ~= true then m:SetAttribute("SmokeSlowed", true) end
			else
				hum.WalkSpeed = e.base
				m:SetAttribute("SmokeSlowed", false)
				botSlow[m] = nil
			end
		end
	end
end)

-- Strobe Frill --------------------------------------------------------------------------------------------------------
strobeRemote.OnServerEvent:Connect(function(player, stamp)
	local char, t = check(player, stamp, "strobe", "Strobe", {attack = true})
	if not char then return end
	char:SetAttribute("StrobeStartedAt", t) -- the rear-up (HerreraMovesPose)
	task.delay(STROBE_WINDUP, function()
		local root = char.Parent and rootOf(char)
		if not root then return end
		local ta = now()
		local s = char:GetScale()
		local range = math.max(1, num(char, "StrobeRange", 20)) * s
		local half = math.rad(math.clamp(num(char, "StrobeAngle", 60), 1, 359) / 2)
		local face = flat(root.CFrame.LookVector)
		face = face.Magnitude > 1e-3 and face.Unit or Vector3.zAxis
		local daze = math.max(0.1, num(char, "StrobeDaze", 1))
		local dmul = math.max(1, num(char, "StrobeDazedMul", 1))
		local hits = 0
		for _, m in ipairs(candidates(char)) do
			local v = flat(rootOf(m).Position - root.Position)
			local d = (rootOf(m).Position - root.Position).Magnitude
			if d <= range and (v.Magnitude < 1e-3 or math.acos(math.clamp(face:Dot(v.Unit), -1, 1)) <= half) and not shielded(m, ta) then
				local old = num(m, "DazedUntil", 0)
				local keep = old > ta and math.max(1, num(m, "DazedDamageMul", 1)) or 1
				m:SetAttribute("DazedDamageMul", math.max(keep, dmul))
				m:SetAttribute("DazedUntil", math.max(old, ta + daze))
				m:SetAttribute("DazedBy", char.Name)
				m:SetAttribute("DazedAt", ta) -- last: HerreraMovesFX shows the stars
				hits += 1
			end
		end
		char:SetAttribute("StrobeHits", hits)
		char:SetAttribute("StrobeAt", ta) -- last: the flash
		count("StrobeFlashes")
		count("StrobeDazes", hits)
	end)
end)

-- Stun Breaker --------------------------------------------------------------------------------------------------------
local knockParams = RaycastParams.new()
knockParams.FilterType = Enum.RaycastFilterType.Exclude
local function push(src, m, dist, t) -- BoneCrest 1.2 visorKnock's pattern
	local sRoot, mRoot = rootOf(src), rootOf(m)
	if not (sRoot and mRoot) then return false end
	if Players:GetPlayerFromCharacter(m) then
		m:SetAttribute("HeadbuttShoveFrom", sRoot.Position)
		m:SetAttribute("HeadbuttShoveDist", dist)
		m:SetAttribute("HeadbuttShoveTime", BREAK_PUSH_TIME)
		m:SetAttribute("HeadbuttShoveAt", t) -- last: HeadbuttShove 1.0 pushes it
		return true
	elseif m:GetAttribute("PounceLatched") == true then
		m:SetAttribute("ShakeOffReason", "breaker")
		m:SetAttribute("ShakeOffAt", t)
		return true
	elseif mRoot.Anchored then
		return false
	end
	local start = mRoot.Position
	local away = flat(start - sRoot.Position)
	away = away.Magnitude > 1e-3 and away.Unit or Vector3.zAxis
	local land = start + away * dist
	local ex = {src, m}
	local isl = workspace:FindFirstChild("DinoIsland")
	for _, n in ipairs({"Bots", "TallGrass"}) do
		local f = isl and isl:FindFirstChild(n)
		if f then table.insert(ex, f) end
	end
	knockParams.FilterDescendantsInstances = ex
	local g0 = workspace:Raycast(start + Vector3.new(0, 2, 0), Vector3.new(0, -60, 0), knockParams)
	local lift = g0 and (start.Y - g0.Position.Y) or 3
	local g1 = workspace:Raycast(Vector3.new(land.X, start.Y + 40, land.Z), Vector3.new(0, -140, 0), knockParams)
	local landPos = Vector3.new(land.X, (g1 and g1.Position.Y or (start.Y - lift)) + lift, land.Z)
	local rot = mRoot.CFrame - mRoot.Position
	mRoot.Anchored = true
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < BREAK_PUSH_TIME do
			local u = math.clamp((os.clock() - t0) / BREAK_PUSH_TIME, 0, 1)
			if not mRoot.Parent then return end
			mRoot.CFrame = CFrame.new(start:Lerp(landPos, 1 - (1 - u) * (1 - u))) * rot
			task.wait()
		end
		if mRoot.Parent then
			mRoot.CFrame = CFrame.new(landPos) * rot
			mRoot.Anchored = false
		end
	end)
	return true
end
breakerRemote.OnServerEvent:Connect(function(player, stamp)
	local char, t = check(player, stamp, "breaker", "Breaker", {breaker = true})
	if not char then return end
	char:SetAttribute("StunnedUntil", t)
	if char:GetAttribute("PinHeld") == true then
		local by = char:GetAttribute("PinnedBy")
		local pl = typeof(by) == "string" and Players:FindFirstChild(by)
		local pc = pl and pl:IsA("Player") and pl.Character
		if pc then
			pc:SetAttribute("ShakeOffReason", "breaker")
			pc:SetAttribute("ShakeOffAt", t) -- last: PounceServer releases the pin
		else
			char:SetAttribute("PinHeld", nil)
		end
	end
	local s = char:GetScale()
	local dist = math.max(0, num(char, "BreakerPush", 0)) * s
	local n = 0
	if dist > 0 then
		local root = rootOf(char)
		for _, m in ipairs(candidates(char)) do
			if (rootOf(m).Position - root.Position).Magnitude <= dist and not shielded(m, t) and push(char, m, dist, t) then n += 1 end
		end
	end
	local imm = math.max(0, num(char, "BreakerImmune", 0))
	if imm > 0 then char:SetAttribute("StunBreakImmuneUntil", t + imm) end
	char:SetAttribute("BreakerPushed", n)
	char:SetAttribute("BreakerAt", t) -- last: HerreraMovesFX bolts
	count("BreakerBreaks")
end)

-- Glide state ---------------------------------------------------------------------------------------------------------
local function setGliding(char, v)
	if char:GetAttribute("Gliding") == v then return end
	char:SetAttribute("Gliding", v)
	char:SetAttribute(v and "GlideStartedAt" or "GlideEndedAt", now())
end
glideRemote.OnServerEvent:Connect(function(player, v)
	local char = player.Character
	if not char or typeof(v) ~= "boolean" then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local ok = v and on("glider") and char:GetAttribute("GliderEnabled") == true and hum ~= nil and hum.Health > 0
	setGliding(char, ok and true or false)
end)
local function onCharacter(char)
	char:GetAttributeChangedSignal("GliderEnabled"):Connect(function()
		if char:GetAttribute("GliderEnabled") ~= true then setGliding(char, false) end
	end)
	local hum = char:WaitForChild("Humanoid", 10)
	if hum then hum.Died:Connect(function() setGliding(char, false) end) end
end
local function onPlayer(p)
	p.CharacterAdded:Connect(onCharacter)
	if p.Character then task.spawn(onCharacter, p.Character) end
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do onPlayer(p) end
