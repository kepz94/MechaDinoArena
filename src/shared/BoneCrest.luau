-- BoneCrest v1.1 (Mecha Dino Arena) — the pachy's Bone Crest maths and look, shared by every script that bites or pounces
-- (ModuleScript, ServerStorage.DinoArcade.BoneCrest, server only). SkillTree 1.30 / SkillEffects 1.23.
-- Kepu 2026-10-30: "We'll do the bone crest to replace the thick hide. Whoever bites your dome does 40% less damage";
--   answers: builds up to 40% (I 20%, II 30%, III 40%, star: the biter takes 5 damage back), "Bites from the front",
--   "Spark + CLANK pop", and Thick Hide's damage cut must work against players too ("Yes, players too").
-- defense(victim) -> the victim's own StatDamageTakenMul (Thick Hide's Defense points, StatServer) when the victim is a
--   player's character, else 1. Bots already apply it to their own hits on players (BotServer 1.10), so BotServer does
--   not call this; BiteServer / PounceServer do (player bites on players in the Arena skipped it until now).
-- factor(victim, attackerPos) -> mul, front. front = the attacker's flat (X/Z) direction from the victim's
--   HumanoidRootPart is within CONE (60) degrees of where the victim faces (LookVector, flat). mul = the victim's
--   BoneCrestMul (SkillEffects 1.23; 1 when not set) when front, else 1.
-- after(victim, attacker, rawDamage, damage, kind) — call after a reduced hit (front and mul < 1): stamps the victim
--   BoneCrestBlocked (count), BoneCrestLastSaved (raw - damage, 0.1 steps), BoneCrestLastKind ("bite" / "pounce"),
--   BoneCrestBlockAt (server time, last); shows the look; and with the victim's BoneCrestReflect > 0 (star) the attacker
--   takes that much back: a model with DummyHealth (a bot, or a player bridged by ArenaPvP in the Arena: the bridge turns
--   the drop into Humanoid damage) loses it there (a killing blow stamps KilledBy / KilledByUserId / KilledWith "crest" /
--   KilledAt); otherwise its Humanoid:TakeDamage. Attacker BoneCrestReflectedAt. Rate-limited: at most one reflect per
--   attacker per REFLECT_GAP (0.4) s, so a pounce's ticks don't stack it.
-- Look (server-built, everyone sees it): at the victim's head, a white / pale-yellow spark burst ParticleEmitter (Emit 18,
--   in an Attachment "BoneCrestSpark" on the Head part or the root) and a BillboardGui "BoneCrestPop" reading "CLANK"
--   (white, dark outline, Fredoka) that rises 3 studs and fades in 0.7 s.
-- Switch: this module's attribute BoneCrestEnabled (default true): false -> factor returns 1 and after does nothing
--   (defense still applies). Separate switch for the Thick Hide fix: BoneCrestDefenseEnabled (default true; false ->
--   defense returns 1).
-- v1.1 (Kepu 2026-10-30: "It only takes 5 damage back for biters. Not slashers." / "So for example a raptor wouldn't
--   take 5 damage back"): the star reflect happens only for a bite (after() kind "bite") by an attacker that is not a
--   raptor (attacker attribute Species ~= "Raptor"; a model without Species whose name contains "Raptor", e.g.
--   Bot_Raptor_1, counts as a raptor). Raptors are slashers: their pounce latch / slash ticks (kind "pounce") and their
--   bites are still cut by the crest and still CLANK, but nothing is sent back. Victim diagnostic BoneCrestReflectSkipped
--   ("slash" / "raptor"). Switch: module attribute BoneCrestReflectBitesOnly (default true; false = 1.0, any reduced hit
--   reflects).
-- v1.2 (Dome Visor, MDA-127, plan docs/plans/PACHY_PARTS_B3_v1.0.md; Kepu 2026-10-30: visor "blocks front melee + Shock
--   Cannon", star "a blocked hit knocks the attacker back"): while the victim's VisorUntil (VisorServer 1.0) is in the
--   future, a hit from the front (the same CONE as the crest, from the attacker's position) does nothing.
--   visorFront(victim, attackerPos) -> true when the visor is up and the position is in front.
--   factor() returns 0, true for such a hit (before the crest maths, not tied to BoneCrestEnabled), so the bite /
--   pounce / bot paths that already call factor + after are blocked with no other change; after() with damage <= 0 and
--   the visor up calls visorBlock instead of the crest effects (no CLANK, no crest reflect).
--   visorBlock(victim, attacker, kind) -> victim VisorBlocked (count), VisorLastKind ("bite" / "pounce" / "headbutt" /
--   "hook" / "cannon"), VisorBlockAt (server time, last); the look: cyan sparks + a "BLOCK" pop at the head. Star
--   (victim VisorKnock true): the attacker is knocked back VISOR_KNOCK_DIST (24) studs over VISOR_KNOCK_TIME (0.35) s
--   straight away from the victim, at most once per attacker per REFLECT_GAP: a player gets HeadbuttShoveFrom /
--   HeadbuttShoveDist / HeadbuttShoveTime / HeadbuttShoveAt (HeadbuttShove 1.0 pushes it, no slow); a bot latched on
--   someone (PounceLatched) is shaken off (ShakeOffReason "visor", ShakeOffAt now; BotServer ends the latch); any other
--   bot whose root is not anchored is slid (anchored, eased, then released). An attacker with EnergyShieldUntil in the
--   future is not knocked. Diagnostics: victim VisorKnocks, VisorKnockSkipped ("shield" / "busy" / "gap"); attacker
--   VisorKnockedAt.
--   Switches (module attributes): BoneCrestVisorEnabled (default true; false = 1.1: the visor blocks nothing here),
--   BoneCrestVisorKnockEnabled (default true; false = no knockback). Settings: BoneCrestVisorKnockDist (24),
--   BoneCrestVisorKnockTime (0.35).
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local M = {}
M.VERSION = "1.2"
M.CONE = 60
local REFLECT_GAP = 0.4

if script:GetAttribute("BoneCrestEnabled") == nil then script:SetAttribute("BoneCrestEnabled", true) end
if script:GetAttribute("BoneCrestDefenseEnabled") == nil then script:SetAttribute("BoneCrestDefenseEnabled", true) end
if script:GetAttribute("BoneCrestReflectBitesOnly") == nil then script:SetAttribute("BoneCrestReflectBitesOnly", true) end -- v1.1
for k, v in pairs({BoneCrestVisorEnabled = true, BoneCrestVisorKnockEnabled = true, BoneCrestVisorKnockDist = 24,
	BoneCrestVisorKnockTime = 0.35}) do -- v1.2
	if script:GetAttribute(k) == nil then script:SetAttribute(k, v) end
end
script:SetAttribute("BoneCrestVersion", M.VERSION)

local lastReflect = setmetatable({}, {__mode = "k"})

function M.defense(victim)
	if script:GetAttribute("BoneCrestDefenseEnabled") == false then return 1 end
	if typeof(victim) ~= "Instance" or not Players:GetPlayerFromCharacter(victim) then return 1 end
	local m = victim:GetAttribute("StatDamageTakenMul")
	if type(m) == "number" and m == m and m >= 0 then return m end
	return 1
end

-- v1.2: Dome Visor up and the attacker in front
function M.visorFront(victim, attackerPos)
	if script:GetAttribute("BoneCrestVisorEnabled") == false or typeof(victim) ~= "Instance" then return false end
	if (tonumber(victim:GetAttribute("VisorUntil")) or 0) <= workspace:GetServerTimeNow() then return false end
	if typeof(attackerPos) ~= "Vector3" then return false end
	local root = victim:FindFirstChild("HumanoidRootPart")
	if not root then return false end
	local d = attackerPos - root.Position
	d = Vector3.new(d.X, 0, d.Z)
	local look = root.CFrame.LookVector
	look = Vector3.new(look.X, 0, look.Z)
	if look.Magnitude < 1e-3 then return false end
	return d.Magnitude < 1e-3 or look.Unit:Dot(d.Unit) >= math.cos(math.rad(M.CONE))
end

function M.factor(victim, attackerPos)
	if M.visorFront(victim, attackerPos) then return 0, true end -- v1.2: the visor blocks it
	if script:GetAttribute("BoneCrestEnabled") == false or typeof(victim) ~= "Instance" then return 1, false end
	local mul = tonumber(victim:GetAttribute("BoneCrestMul")) or 1
	if mul >= 1 or typeof(attackerPos) ~= "Vector3" then return 1, false end
	local root = victim:FindFirstChild("HumanoidRootPart")
	if not root then return 1, false end
	local d = attackerPos - root.Position
	d = Vector3.new(d.X, 0, d.Z)
	local look = root.CFrame.LookVector
	look = Vector3.new(look.X, 0, look.Z)
	if look.Magnitude < 1e-3 then return 1, false end
	local front = d.Magnitude < 1e-3 or look.Unit:Dot(d.Unit) >= math.cos(math.rad(M.CONE))
	return front and math.max(0, mul) or 1, front
end

local function look(victim)
	local head = victim:FindFirstChild("Head")
	local anchor = head and (head:IsA("BasePart") and head or head:FindFirstChild("Root") or head:FindFirstChildWhichIsA("BasePart"))
	anchor = anchor or victim:FindFirstChild("HumanoidRootPart")
	if not anchor then return end
	local a = Instance.new("Attachment")
	a.Name = "BoneCrestSpark"
	a.Parent = anchor
	local p = Instance.new("ParticleEmitter")
	p.Enabled = false
	p.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 226, 140))
	p.LightEmission = 1
	p.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0)})
	p.Speed = NumberRange.new(14, 24)
	p.SpreadAngle = Vector2.new(180, 180)
	p.Lifetime = NumberRange.new(0.15, 0.35)
	p.Drag = 4
	p.Parent = a
	p:Emit(18)
	local g = Instance.new("BillboardGui")
	g.Name = "BoneCrestPop"
	g.Size = UDim2.fromOffset(110, 36)
	g.StudsOffsetWorldSpace = Vector3.new(0, 2, 0)
	g.AlwaysOnTop = true
	g.Adornee = anchor
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, 1)
	l.Font = Enum.Font.FredokaOne
	l.TextSize = 28
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextStrokeColor3 = Color3.fromRGB(30, 34, 44)
	l.TextStrokeTransparency = 0
	l.Text = "CLANK"
	l.Parent = g
	g.Parent = victim
	TweenService:Create(g, TweenInfo.new(0.7), {StudsOffsetWorldSpace = Vector3.new(0, 5, 0)}):Play()
	TweenService:Create(l, TweenInfo.new(0.7), {TextTransparency = 1, TextStrokeTransparency = 1}):Play()
	task.delay(0.75, function()
		g:Destroy()
		a:Destroy()
	end)
end

local function reflect(victim, attacker, amount)
	local t = workspace:GetServerTimeNow()
	if (lastReflect[attacker] or -math.huge) > t - REFLECT_GAP then return end
	lastReflect[attacker] = t
	local hp = attacker:GetAttribute("DummyHealth")
	if typeof(hp) == "number" then
		attacker:SetAttribute("DummyHealth", math.max(0, hp - amount))
		if hp > 0 and hp - amount <= 0 then
			local owner = Players:GetPlayerFromCharacter(victim)
			attacker:SetAttribute("KilledBy", victim.Name)
			attacker:SetAttribute("KilledByUserId", owner and owner.UserId or 0)
			attacker:SetAttribute("KilledWith", "crest")
			attacker:SetAttribute("KilledAt", t) -- last
		end
	else
		local hum = attacker:FindFirstChildOfClass("Humanoid")
		if hum then hum:TakeDamage(amount) end
	end
	attacker:SetAttribute("BoneCrestReflectedAt", t)
end

-- v1.2: Dome Visor block look (cyan sparks + "BLOCK")
local function visorLook(victim)
	local head = victim:FindFirstChild("Head")
	local anchor = head and (head:IsA("BasePart") and head or head:FindFirstChild("Root") or head:FindFirstChildWhichIsA("BasePart"))
	anchor = anchor or victim:FindFirstChild("HumanoidRootPart")
	if not anchor then return end
	local a = Instance.new("Attachment")
	a.Name = "VisorBlockSpark"
	a.Parent = anchor
	local p = Instance.new("ParticleEmitter")
	p.Enabled = false
	p.Color = ColorSequence.new(Color3.fromRGB(220, 250, 255), Color3.fromRGB(95, 227, 255))
	p.LightEmission = 1
	p.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0)})
	p.Speed = NumberRange.new(16, 26)
	p.SpreadAngle = Vector2.new(180, 180)
	p.Lifetime = NumberRange.new(0.15, 0.35)
	p.Drag = 4
	p.Parent = a
	p:Emit(22)
	local g = Instance.new("BillboardGui")
	g.Name = "VisorBlockPop"
	g.Size = UDim2.fromOffset(110, 36)
	g.StudsOffsetWorldSpace = Vector3.new(0, 2, 0)
	g.AlwaysOnTop = true
	g.Adornee = anchor
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, 1)
	l.Font = Enum.Font.FredokaOne
	l.TextSize = 28
	l.TextColor3 = Color3.fromRGB(95, 227, 255)
	l.TextStrokeColor3 = Color3.fromRGB(20, 30, 44)
	l.TextStrokeTransparency = 0
	l.Text = "BLOCK"
	l.Parent = g
	g.Parent = victim
	TweenService:Create(g, TweenInfo.new(0.7), {StudsOffsetWorldSpace = Vector3.new(0, 5, 0)}):Play()
	TweenService:Create(l, TweenInfo.new(0.7), {TextTransparency = 1, TextStrokeTransparency = 1}):Play()
	task.delay(0.75, function()
		g:Destroy()
		a:Destroy()
	end)
end

local knockParams = RaycastParams.new()
knockParams.FilterType = Enum.RaycastFilterType.Exclude
local lastKnock = setmetatable({}, {__mode = "k"})
-- v1.2: star knockback (see the header); returns the result for VisorKnockSkipped / VisorKnocks
local function visorKnock(victim, attacker)
	local t = workspace:GetServerTimeNow()
	if (tonumber(attacker:GetAttribute("EnergyShieldUntil")) or 0) > t then return "shield" end
	if (lastKnock[attacker] or -math.huge) > t - REFLECT_GAP then return "gap" end
	local vRoot = victim:FindFirstChild("HumanoidRootPart")
	local aRoot = attacker:FindFirstChild("HumanoidRootPart")
	if not (vRoot and aRoot) then return "busy" end
	local dist = tonumber(script:GetAttribute("BoneCrestVisorKnockDist")) or 24
	local time = math.max(0.05, tonumber(script:GetAttribute("BoneCrestVisorKnockTime")) or 0.35)
	if Players:GetPlayerFromCharacter(attacker) then
		attacker:SetAttribute("HeadbuttShoveFrom", vRoot.Position)
		attacker:SetAttribute("HeadbuttShoveDist", dist)
		attacker:SetAttribute("HeadbuttShoveTime", time)
		attacker:SetAttribute("HeadbuttShoveAt", t) -- last: HeadbuttShove 1.0 pushes it
	elseif attacker:GetAttribute("PounceLatched") == true then
		attacker:SetAttribute("ShakeOffReason", "visor")
		attacker:SetAttribute("ShakeOffAt", t) -- BotServer ends the latch
	elseif aRoot.Anchored then
		return "busy"
	else
		local start = aRoot.Position
		local away = Vector3.new(start.X - vRoot.Position.X, 0, start.Z - vRoot.Position.Z)
		away = away.Magnitude > 1e-3 and away.Unit or Vector3.zAxis
		local land = start + away * dist
		local ex = {attacker, victim}
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
		local rot = aRoot.CFrame - aRoot.Position
		aRoot.Anchored = true
		task.spawn(function()
			local t0 = os.clock()
			while os.clock() - t0 < time do
				local u = math.clamp((os.clock() - t0) / time, 0, 1)
				local e = 1 - (1 - u) * (1 - u)
				if not aRoot.Parent then return end
				aRoot.CFrame = CFrame.new(start:Lerp(landPos, e)) * rot
				task.wait()
			end
			if aRoot.Parent then
				aRoot.CFrame = CFrame.new(landPos) * rot
				aRoot.Anchored = false
			end
		end)
	end
	lastKnock[attacker] = t
	attacker:SetAttribute("VisorKnockedAt", t)
	return "knocked"
end

function M.visorBlock(victim, attacker, kind)
	if typeof(victim) ~= "Instance" then return end
	victim:SetAttribute("VisorBlocked", (victim:GetAttribute("VisorBlocked") or 0) + 1)
	victim:SetAttribute("VisorLastKind", kind)
	victim:SetAttribute("VisorBlockAt", workspace:GetServerTimeNow())
	pcall(visorLook, victim)
	if victim:GetAttribute("VisorKnock") == true and script:GetAttribute("BoneCrestVisorKnockEnabled") ~= false
		and typeof(attacker) == "Instance" and attacker.Parent and attacker ~= victim then
		local ok, r = pcall(visorKnock, victim, attacker)
		r = ok and r or "error"
		if r == "knocked" then
			victim:SetAttribute("VisorKnocks", (victim:GetAttribute("VisorKnocks") or 0) + 1)
		else
			victim:SetAttribute("VisorKnockSkipped", r)
		end
	end
end

function M.after(victim, attacker, rawDamage, damage, kind)
	if (tonumber(damage) or 0) <= 0 and typeof(victim) == "Instance" and typeof(attacker) == "Instance" then -- v1.2: visor
		local aRoot = attacker:FindFirstChild("HumanoidRootPart")
		if aRoot and M.visorFront(victim, aRoot.Position) then
			M.visorBlock(victim, attacker, kind)
			return
		end
	end
	if script:GetAttribute("BoneCrestEnabled") == false or typeof(victim) ~= "Instance" then return end
	victim:SetAttribute("BoneCrestBlocked", (victim:GetAttribute("BoneCrestBlocked") or 0) + 1)
	victim:SetAttribute("BoneCrestLastSaved", math.floor(((tonumber(rawDamage) or 0) - (tonumber(damage) or 0)) * 10 + 0.5) / 10)
	victim:SetAttribute("BoneCrestLastKind", kind)
	victim:SetAttribute("BoneCrestBlockAt", workspace:GetServerTimeNow())
	pcall(look, victim)
	local amount = tonumber(victim:GetAttribute("BoneCrestReflect")) or 0
	if amount > 0 and script:GetAttribute("BoneCrestReflectBitesOnly") ~= false then -- v1.1: biters only, raptors are slashers
		local sp = typeof(attacker) == "Instance" and attacker:GetAttribute("Species") or nil
		local raptor = sp == "Raptor" or (sp == nil and typeof(attacker) == "Instance" and attacker.Name:find("Raptor") ~= nil)
		if kind ~= "bite" or raptor then
			victim:SetAttribute("BoneCrestReflectSkipped", kind ~= "bite" and "slash" or "raptor")
			amount = 0
		end
	end
	if amount > 0 and typeof(attacker) == "Instance" and attacker.Parent then pcall(reflect, victim, attacker, amount) end
end

return M
