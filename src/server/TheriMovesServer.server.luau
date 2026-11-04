-- TheriMovesServer v1.3 (Mecha Dino Arena) — the moves of the Therizinosaurus' mecha button parts, build 1: Reaper's Hook,
-- Feather Barrage, Harvest Field, Snare Wires. Plan docs/plans/THERIZINO_PARTS_v1.0.md Task 4 (MDA-244, deterministic map),
-- mockup docs/mockups/therizino_parts_options.html v0.1 (Kepu 2026-11-04 picks; red-team "Across", "Reuse the Tether chain").
-- Settings come from the character (SkillEffects 1.42, a therizino with the part bought AND slotted): TheriHook* (Enabled,
--   Range, Cone, Stun, Cut, Cooldown), TheriFeather* (Enabled, Count, Range, Fan, Damage, SlowMul, SlowTime, Cooldown),
--   TheriField* (Enabled, Radius, Time, Bleed, SlowMul, Cooldown), TheriSnare* (Enabled, Max, Damage, Root, Radius,
--   Cooldown). Distances are world studs except the ones marked "x scale".
-- Remotes (client -> server, MechaButtons): DinoTheriHookRequest(stamp, aimDir), DinoTheriFeatherRequest(stamp, aimDir),
--   DinoTheriFieldRequest(stamp), DinoTheriSnareRequest(stamp). Checks in order (first wins) -> <Prefix>ServerResult (+
--   <Prefix>ServerResultAt): "badArg", "dead", "disabled" (switch or <Prefix>Enabled ~= true), "menu", "stunned", "pinned",
--   "dazed", "cooldown" (<Prefix>ReadyAt). ok -> <Prefix>ReadyAt = now + <Prefix>Cooldown (the hook: only when it fired).
-- Who can be hit: player characters and Workspace.DinoIsland.Bots (Hitboxes, Bitable, Species / IsBot, alive, not KO), never
--   the user, never a squadmate (SquadRules.sameChar), players only where ModeRules.canAffect allows (the Arena). Damage
--   comes off DummyHealth (ArenaPvP bridges players) x the debuff / daze multipliers; none while EnergyShieldUntil is in the
--   future; a killing blow stamps KilledBy / KilledByUserId / KilledWith ("therihook" / "therifeather" / "therifield" /
--   "therisnare") / KilledAt (last).
-- Slows (feather, field): a player gets TenoSlowUntil / TenoSlowMul (SprintTest reads them; the stronger / longer kept, as
--   TenoMovesServer 1.0); a bot's Humanoid WalkSpeed x mul from this script while it lasts (it waits while TenoAttackServer
--   (TenoSlowed) or TenoMovesServer (TenoMoveSlowed) is slowing the same bot; TheriMoveSlowed while this script does).
-- Reaper's Hook: heading = the flat aimDir (else the root's look). Target = the nearest allowed dino whose root is within
--   TheriHookCone (20) degrees of that heading and TheriHookRange studs (flat) of the root. The world between the jib tip
--   (ZPart_zhook "jib", else the root) and the target root blocks ("blocked"). None -> "noTarget"; both: no recharge,
--   TheriHookResult stamped. A shielded target -> "shielded" (recharge, no pull). A hit: the target is pulled over
--   pullTime = clamp(distance / HOOK_SPEED (140), 0.25, 0.8) s to HOOK_GAP (5) x scale studs in front of the root: a player
--   through HookPull 1.0 (HookPullBy = this therizino, HookPullGap, HookPullTime, HookPullAt last), a bot slid by this
--   script (root anchored, moved each step, then released); both get HookHeldUntil. Star (TheriHookCut): at the pull's
--   end the target is stunned TheriHookStun s (StunnedUntil, the later one kept) and TheriAttackServer 1.4's TheriStartCut
--   runs cut 1. Stamps (therizino): TheriHookAimEnd, TheriHookTarget (or ""), TheriHookResult ("hit" / "noTarget" /
--   "blocked" / "shielded"), TheriHookPullTime, TheriHookCutResult, TheriHookAt (last).
-- Feather Barrage: heading as the hook; TheriFeatherCount blades spread evenly over TheriFeatherFan degrees, each a line
--   TheriFeatherRange studs from the root. A blade hits a dino when a point on its line is within BLADE_WIDTH (1.5) studs of
--   its hitboxes; every blade that hits deals TheriFeatherDamage, and a hit dino is slowed x TheriFeatherSlowMul for
--   TheriFeatherSlowTime s. Stamps: TheriFeatherDir, TheriFeatherHits ("name=n|..."), TheriFeatherAt (last).
-- Harvest Field: a circle of radius TheriFieldRadius studs (Kepu "Across": 12 / 16 / 20 wide) on the ground under the root
--   for TheriFieldTime s; every FIELD_TICK (0.5) s each allowed dino with a hitbox within the radius (flat, at its own
--   height) takes TheriFieldBleed x 0.5 and is slowed x TheriFieldSlowMul until 0.6 s later. One field per therizino (a new
--   one replaces it). Stamps: TheriFieldCenter, TheriFieldRadiusNow, TheriFieldUntil, TheriFieldAt (last).
-- Snare Wires: a trap (Model "TheriSnare_<name>" in Workspace.DinoFX.TheriMovesFX: two steel posts and a red wire, no
--   collision) on the ground SNARE_AHEAD (8) x scale studs ahead of the root; at most TheriSnareMax alive (the oldest goes),
--   each for SNARE_LIFE (60) s. The first allowed dino (not shielded) whose root comes within TheriSnareRadius x scale studs
--   (flat) of it: TheriSnareDamage, and it is held (Kepu "Reuse the Tether chain": TetherServer's rope) by a RopeConstraint
--   from an anchored stake at the trap to its root, Length = the distance then + 0.5, for TheriSnareRoot s; stamps on it
--   TheriSnaredUntil, TheriSnaredBy; the trap is gone. Stamps (therizino): TheriSnareCount (alive), TheriSnareAt (last lay),
--   TheriSnareHitAt / TheriSnareHitTarget.
-- Switches (script attributes): TheriMovesServerEnabled, TheriMoves_<id>Enabled (zhook / zfeather / zharvest / zsnare),
--   TheriMovesModeRulesEnabled, TheriMovesSquadEnabled (default true each, read at each use).
-- Diagnostics: script TheriMovesServerVersion, TheriMovesHits, TheriMovesSlows, TheriMovesSquadSkips, TheriMovesMode,
--   TheriMovesTraps (alive, all owners).
-- v1.1 (MDA-246 Studio check: a raptor bot 22 studs straight ahead took no blade): the blade test measured from the root's
--   height, and a smaller dino's hitboxes sit lower than the therizino's root, so a blade passed over it. A blade's point is
--   now taken at the target root's height (flat fan, as the mockup draws it). Switch: script attribute
--   TheriMovesFlatBladesEnabled (default true, read at each fire; false = 1.0).
-- v1.2 (therizino parts build 2, MDA-247, plan docs/plans/THERIZINO_PARTS_v1.0.md Task 7; SkillTree 1.62): three more remotes,
--   same checks (prefixes TheriGrapple / TheriDeflect / TheriClock):
--   * Grapple Zip: DinoTheriGrappleRequest(stamp, aimDir). A ray from the root (+ 2 x scale up) along aimDir (the camera look,
--     3D) up to TheriGrappleRange studs against the world only (characters, bots, tall grass, FX ignored). A hit at least
--     GRAPPLE_MIN (6) studs away -> TheriGrappleTo = hit point + normal x 3 x scale, TheriGrappleTime = clamp(distance /
--     ZIP_SPEED (120), 0.2, 0.9) s, TheriGrappleResult "zip", TheriGrappleAt (last): the owner's client (TheriGrappleZip 1.0)
--     flies the body there. Nothing hit / too close -> "noAnchor" (no charge used). Charges: TheriGrappleCharges (1; 2 at the
--     star); each zip uses one, which comes back TheriGrappleCooldown s later; TheriGrappleReadyAt = now while a charge is
--     left, else the next refill (MechaButtons reads it); TheriGrappleLeft (charges left).
--   * Deflector Claws: DinoTheriDeflectRequest(stamp) -> TheriDeflectUntil = now + TheriDeflectTime, TheriDeflectAt (last).
--     DeflectRules 1.0 (ServerStorage.DinoArcade) does the blocking inside DiloAttackServer 1.3, TenoMovesServer 1.8 and
--     ScreechServer 1.12.
--   * Overclock Joints: DinoTheriClockRequest(stamp) -> TheriClockUntil = now + TheriClockTime, TheriClockAt (last); SprintTest
--     1.20 runs faster (and drops slows at the star), TheriAttackServer 1.5 / TheriAttackTest 1.3 shorten the tap gap.
--   Switches: TheriMoves_zgrappleEnabled, TheriMoves_zdeflectEnabled, TheriMoves_zclockEnabled (default true, read at each use).
-- v1.3 (Kepu 2026-11-04 15:21: the grapple "Barely even pulls you a significant distance for the slot. Also it's not obvious
--   where it's shooting to latch on to"; "overclocked legs should always be on but passive and take up a slot", "Same numbers,
--   always on"; mockup docs/mockups/therizino_grapple_overclock_v0.1.html picks Grapple-A, Overclock-A; plan
--   docs/plans/THERIZINO_GRAPPLE_CLOCK_v1.0.md, MDA-255 / MDA-257; SkillTree 1.63 ranges 90 / 110 / 130):
--   * Grapple v2 (script attribute TheriMovesGrappleV2Enabled, default true, read at each use; false = 1.2): zip time =
--     clamp(distance / ZIP_SPEED_V2 (150), 0.2, ZIP_MAX_V2 (1.0)) s; nothing hit inside the range -> it latches in the air:
--     TheriGrappleTo = TheriGrappleAnchor = the ray's end (origin + aim x range), TheriGrappleAir = true (false on a surface).
--     A hit closer than GRAPPLE_MIN is still "noAnchor". Characters get TheriGrappleAirLatch (= the switch) for the client
--     marker (TheriGrappleZip 1.1).
--   * Passive Overclock (script attribute TheriMovesClockPassiveEnabled, default true; false = 1.2 button): every
--     CLOCK_TICK (0.25) s, for each player's character: TheriClockEnabled true (bought + slotted, SkillEffects) -> TheriClockPassive
--     true, TheriClockUntil = now + 1e6 and TheriClockAt = now when it turns on (SprintTest / TheriAttackServer / TheriAttackTest
--     read TheriClockUntil as before); otherwise, if it was passive -> TheriClockPassive false, TheriClockUntil = now. A clock
--     request while passive -> TheriClockServerResult "passive", nothing changes.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")

local VERSION = "1.0"
VERSION = "1.1" -- v1.1 flat feather blades
VERSION = "1.2" -- v1.2 build 2: Grapple Zip, Deflector Claws, Overclock Joints
VERSION = "1.3" -- v1.3 grapple v2 (air latch, faster), passive Overclock
local HOOK_SPEED, HOOK_GAP = 140, 5
local BLADE_WIDTH = 1.5
local FIELD_TICK = 0.5
local SNARE_AHEAD, SNARE_LIFE = 8, 60

script:SetAttribute("TheriMovesServerVersion", VERSION)
for _, k in ipairs({"TheriMovesHits", "TheriMovesSlows", "TheriMovesSquadSkips", "TheriMovesTraps"}) do script:SetAttribute(k, 0) end
for _, k in ipairs({"TheriMovesServerEnabled", "TheriMoves_zhookEnabled", "TheriMoves_zfeatherEnabled", "TheriMoves_zharvestEnabled",
	"TheriMoves_zsnareEnabled", "TheriMovesModeRulesEnabled", "TheriMovesSquadEnabled"}) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, true) end
end
if script:GetAttribute("TheriMovesFlatBladesEnabled") == nil then script:SetAttribute("TheriMovesFlatBladesEnabled", true) end -- v1.1
local function on(id)
	return script:GetAttribute("TheriMovesServerEnabled") ~= false and script:GetAttribute("TheriMoves_" .. id .. "Enabled") ~= false
end
local function now() return workspace:GetServerTimeNow() end
local function count(k, n) script:SetAttribute(k, (script:GetAttribute(k) or 0) + (n or 1)) end
local function num(m, k, d) return tonumber(m:GetAttribute(k)) or d end
local function flat(v) return Vector3.new(v.X, 0, v.Z) end
local function rootOf(m) return m:FindFirstChild("HumanoidRootPart") end

-- mode + squad rules (TenoMovesServer 1.0) ------------------------------------------------------------------------------------
local ModeRules = require(ServerStorage:WaitForChild("DinoArcade"):WaitForChild("ModeRules"))
local MODE = ModeRules.currentMode()
script:SetAttribute("TheriMovesMode", MODE)
local squadMod
local function squadmate(a, b)
	if script:GetAttribute("TheriMovesSquadEnabled") == false then return false end
	if not squadMod then
		local arc = ServerStorage:FindFirstChild("DinoArcade")
		local m = arc and arc:FindFirstChild("SquadRules")
		if not m then return false end
		local ok, mod = pcall(require, m)
		if not ok then return false end
		squadMod = mod
	end
	if squadMod.sameChar(a, b) then
		count("TheriMovesSquadSkips")
		return true
	end
	return false
end
local function mayAffect(source, target)
	if squadmate(source, target) then return false end
	if script:GetAttribute("TheriMovesModeRulesEnabled") == false then return true end
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
local hookRemote, featherRemote = remote("DinoTheriHookRequest"), remote("DinoTheriFeatherRequest")
local fieldRemote, snareRemote = remote("DinoTheriFieldRequest"), remote("DinoTheriSnareRequest")

-- targets (TenoMovesServer 1.0 rules) -----------------------------------------------------------------------------------------
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
		m:SetAttribute("KilledAt", t) -- last
	end
	count("TheriMovesHits")
	return d
end
local function stun(m, untilT)
	m:SetAttribute("StunnedUntil", math.max(num(m, "StunnedUntil", 0), untilT))
end

-- world / fx -------------------------------------------------------------------------------------------------------------------
local fxFolder
local function fx()
	local root = workspace:FindFirstChild("DinoFX")
	if not root then
		root = Instance.new("Folder")
		root.Name = "DinoFX"
		root.Parent = workspace
	end
	if not (fxFolder and fxFolder.Parent) then
		fxFolder = root:FindFirstChild("TheriMovesFX") or Instance.new("Folder")
		fxFolder.Name = "TheriMovesFX"
		fxFolder.Parent = root
	end
	return fxFolder
end
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
local function worldOnly()
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
	return rayParams
end
local function groundY(pos, fallback)
	local g = workspace:Raycast(Vector3.new(pos.X, pos.Y + 60, pos.Z), Vector3.new(0, -200, 0), worldOnly())
	return g and g.Position.Y or fallback
end

-- slows (TenoMovesServer 1.0's rule) -----------------------------------------------------------------------------------------------
local botSlow = {} -- [model] = {hum, untilT, mul, base, set}
local function slow(m, mul, untilT, t)
	if not (mul and mul < 1 and untilT and untilT > t) or shielded(m, t) then return end
	count("TheriMovesSlows")
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
		elseif m:GetAttribute("TenoSlowed") == true or m:GetAttribute("TenoMoveSlowed") == true then -- another slower: give it back, wait
			if e.set ~= nil and e.base and math.abs(hum.WalkSpeed - e.set) <= 1e-3 then hum.WalkSpeed = e.base end
			e.set = nil
			if t >= e.untilT then
				botSlow[m] = nil
				m:SetAttribute("TheriMoveSlowed", false)
			end
		else
			local cur = hum.WalkSpeed
			if e.set == nil or math.abs(cur - e.set) > 1e-3 then e.base = cur end
			if t < e.untilT then
				e.set = e.base * math.clamp(e.mul, 0.05, 1)
				hum.WalkSpeed = e.set
				if m:GetAttribute("TheriMoveSlowed") ~= true then m:SetAttribute("TheriMoveSlowed", true) end
			else
				hum.WalkSpeed = e.base
				m:SetAttribute("TheriMoveSlowed", false)
				botSlow[m] = nil
			end
		end
	end
end)

-- request checks -------------------------------------------------------------------------------------------------------------------
local function check(player, stamp, id, prefix, aimDir, needAim)
	local char = player.Character
	if not char then return nil end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local t = now()
	local r
	if typeof(stamp) ~= "number" or stamp ~= stamp or (needAim and aimDir ~= nil and (typeof(aimDir) ~= "Vector3"
		or aimDir.Magnitude < 0.5 or aimDir.Magnitude > 1.5)) then
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
local function heading(char, aimDir)
	local d = typeof(aimDir) == "Vector3" and flat(aimDir) or Vector3.zero
	if d.Magnitude < 1e-3 then d = flat(rootOf(char).CFrame.LookVector) end
	return d.Magnitude > 1e-3 and d.Unit or -Vector3.zAxis
end

-- Reaper's Hook -------------------------------------------------------------------------------------------------------------------
local function jibTip(char)
	local m = char:FindFirstChild("ZPart_zhook")
	if m then
		for _, p in ipairs(m:GetChildren()) do
			if p:IsA("BasePart") and p:GetAttribute("ZPartRole") == "jib" then return p.Position end
		end
	end
	return rootOf(char).Position
end
local function slideBot(m, goalFn, dur)
	local r = rootOf(m)
	if not r then return end
	local wasAnchored = r.Anchored
	r.Anchored = true
	local start = r.Position
	local t0 = os.clock()
	while os.clock() - t0 < dur and m.Parent and r.Parent do
		local k = math.clamp((os.clock() - t0) / dur, 0, 1)
		local goal = goalFn()
		local p = start:Lerp(goal, k)
		r.CFrame = CFrame.new(p) * r.CFrame.Rotation
		RunService.Heartbeat:Wait()
	end
	if m.Parent and r.Parent then
		r.CFrame = CFrame.new(goalFn()) * r.CFrame.Rotation
		r.Anchored = wasAnchored
	end
end
local startCut
local function cutFn()
	if startCut and startCut.Parent then return startCut end
	local s = game:GetService("ServerScriptService"):FindFirstChild("TheriAttackServer")
	startCut = s and s:FindFirstChild("TheriStartCut")
	return startCut
end
hookRemote.OnServerEvent:Connect(function(player, stamp, aimDir)
	local char, t = check(player, stamp, "zhook", "TheriHook", aimDir, true)
	if not char then return end
	local root = rootOf(char)
	local dir = heading(char, aimDir)
	local range = math.max(0, num(char, "TheriHookRange", 50))
	local half = math.rad(math.clamp(num(char, "TheriHookCone", 20), 0, 90))
	local best, bestD = nil, math.huge
	for _, m in ipairs(candidates(char)) do
		local v = flat(rootOf(m).Position - root.Position)
		local d = v.Magnitude
		if d > 1e-3 and d <= range and math.acos(math.clamp(dir:Dot(v.Unit), -1, 1)) <= half and d < bestD then best, bestD = m, d end
	end
	local from = jibTip(char)
	local result, aimEnd = "noTarget", root.Position + dir * range
	if best then
		local to = rootOf(best).Position
		aimEnd = to
		local hit = workspace:Raycast(from, to - from, worldOnly())
		if hit then
			result, aimEnd = "blocked", hit.Position
		elseif shielded(best, t) then
			result = "shielded"
		else
			result = "hit"
		end
	end
	char:SetAttribute("TheriHookAimEnd", aimEnd)
	char:SetAttribute("TheriHookTarget", (result == "hit" or result == "shielded") and best.Name or "")
	char:SetAttribute("TheriHookResult", result)
	if result == "noTarget" or result == "blocked" then
		char:SetAttribute("TheriHookPullTime", 0)
		char:SetAttribute("TheriHookAt", t) -- last
		char:SetAttribute("TheriHookServerResult", result)
		char:SetAttribute("TheriHookServerResultAt", t)
		return
	end
	ok(char, "TheriHook", t)
	local s = char:GetScale()
	local pullTime = result == "hit" and math.clamp(bestD / HOOK_SPEED, 0.25, 0.8) or 0
	char:SetAttribute("TheriHookPullTime", pullTime)
	char:SetAttribute("TheriHookAt", t) -- last: FX
	if result ~= "hit" then return end
	local gapStuds = HOOK_GAP * s
	best:SetAttribute("HookHeldUntil", t + pullTime)
	if Players:GetPlayerFromCharacter(best) then
		best:SetAttribute("HookPullBy", char.Name)
		best:SetAttribute("HookPullGap", gapStuds)
		best:SetAttribute("HookPullTime", pullTime)
		best:SetAttribute("HookPullAt", t) -- last: HookPull 1.0
		task.wait(pullTime)
	else
		slideBot(best, function()
			local r = rootOf(char)
			local f = r and flat(r.CFrame.LookVector) or dir
			f = f.Magnitude > 1e-3 and f.Unit or dir
			local p = (r and r.Position or root.Position) + f * gapStuds
			local br = rootOf(best)
			return Vector3.new(p.X, br and br.Position.Y or p.Y, p.Z)
		end, pullTime)
	end
	if char:GetAttribute("TheriHookCut") == true and best.Parent and char.Parent then
		stun(best, now() + math.max(0, num(char, "TheriHookStun", 1)))
		local fn = cutFn()
		local r = "noCut"
		if fn then
			local okCall, res = pcall(function() return fn:Invoke(player) end)
			r = okCall and tostring(res) or "error"
		end
		char:SetAttribute("TheriHookCutResult", r)
	end
end)

-- Feather Barrage -----------------------------------------------------------------------------------------------------------------
featherRemote.OnServerEvent:Connect(function(player, stamp, aimDir)
	local char, t = check(player, stamp, "zfeather", "TheriFeather", aimDir, true)
	if not char then return end
	ok(char, "TheriFeather", t)
	local root = rootOf(char)
	local dir = heading(char, aimDir)
	local n = math.max(1, math.floor(num(char, "TheriFeatherCount", 8)))
	local range = math.max(0, num(char, "TheriFeatherRange", 20))
	local fan = math.rad(math.clamp(num(char, "TheriFeatherFan", 60), 0, 180))
	local dmg = math.max(0, num(char, "TheriFeatherDamage", 3))
	local slowMul, slowT = num(char, "TheriFeatherSlowMul", 1), math.max(0, num(char, "TheriFeatherSlowTime", 0))
	local origin = root.Position
	local dirs = {}
	for i = 1, n do
		local a = n == 1 and 0 or (-fan / 2 + fan * (i - 1) / (n - 1))
		table.insert(dirs, (CFrame.Angles(0, a, 0) * dir).Unit)
	end
	local hits = {}
	for _, m in ipairs(candidates(char)) do
		local mr = rootOf(m)
		local blades = 0
		for _, d in ipairs(dirs) do
			local along = math.clamp(flat(mr.Position - origin):Dot(d), 0, range)
			local pt = origin + d * along
			if script:GetAttribute("TheriMovesFlatBladesEnabled") ~= false then pt = Vector3.new(pt.X, mr.Position.Y, pt.Z) end -- v1.1
			if gap(m, pt) <= BLADE_WIDTH then blades += 1 end
		end
		if blades > 0 then
			for _ = 1, blades do damage(char, player, m, dmg, "therifeather", t) end
			slow(m, slowMul, t + slowT, t)
			table.insert(hits, m.Name .. "=" .. blades)
		end
	end
	char:SetAttribute("TheriFeatherDir", dir)
	char:SetAttribute("TheriFeatherHits", table.concat(hits, "|"))
	char:SetAttribute("TheriFeatherAt", t) -- last: FX
end)

-- Harvest Field ---------------------------------------------------------------------------------------------------------------------
local fields = {} -- [char] = {center, radius, untilT, nextTick, player, bleed, slowMul}
fieldRemote.OnServerEvent:Connect(function(player, stamp)
	local char, t = check(player, stamp, "zharvest", "TheriField", nil, false)
	if not char then return end
	ok(char, "TheriField", t)
	local root = rootOf(char)
	local c = Vector3.new(root.Position.X, groundY(root.Position, root.Position.Y - 6), root.Position.Z)
	local f = {center = c, radius = math.max(0, num(char, "TheriFieldRadius", 6)), untilT = t + math.max(0, num(char, "TheriFieldTime", 3)),
		nextTick = t, player = player, bleed = math.max(0, num(char, "TheriFieldBleed", 4)), slowMul = num(char, "TheriFieldSlowMul", 1)}
	fields[char] = f
	char:SetAttribute("TheriFieldCenter", c)
	char:SetAttribute("TheriFieldRadiusNow", f.radius)
	char:SetAttribute("TheriFieldUntil", f.untilT)
	char:SetAttribute("TheriFieldAt", t) -- last: FX
end)

-- Snare Wires -----------------------------------------------------------------------------------------------------------------------
local traps = {} -- [char] = {{model, pos, bornAt, player}...}
local function trapCount()
	local n = 0
	for _, list in pairs(traps) do n += #list end
	script:SetAttribute("TheriMovesTraps", n)
end
local function buildTrap(char, pos, s)
	local m = Instance.new("Model")
	m.Name = "TheriSnare_" .. char.Name
	local fwd = flat(rootOf(char).CFrame.RightVector)
	fwd = fwd.Magnitude > 1e-3 and fwd.Unit or Vector3.xAxis
	local span = 3 * s
	local function piece(name, size, cf, color, mat)
		local p = Instance.new("Part")
		p.Name = name
		p.Size, p.CFrame = size, cf
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
		p.Color, p.Material = color, mat
		p.CastShadow = mat ~= Enum.Material.Neon
		p.Parent = m
		return p
	end
	local steel = Color3.fromRGB(154, 163, 173)
	for _, sd in ipairs({-1, 1}) do
		piece("Post", Vector3.new(0.3, 1.2, 0.3) * s / 2, CFrame.new(pos + fwd * sd * span / 2 + Vector3.new(0, 0.3 * s, 0)), steel, Enum.Material.Metal)
	end
	piece("Wire", Vector3.new(span, 0.08 * s, 0.08 * s), CFrame.lookAt(pos + Vector3.new(0, 0.45 * s, 0), pos + Vector3.new(0, 0.45 * s, 0) + fwd)
		* CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(224, 42, 42), Enum.Material.Neon)
	m:SetAttribute("TheriSnareOwner", char.Name)
	m.Parent = fx()
	return m
end
local function hold(char, m, pos, rootT, t)
	local mr = rootOf(m)
	if not mr then return end
	local stake = Instance.new("Part")
	stake.Name = "TheriSnareStake"
	stake.Size = Vector3.new(0.5, 0.5, 0.5)
	stake.Anchored, stake.CanCollide, stake.CanQuery, stake.CanTouch = true, false, false, false
	stake.Transparency = 1
	stake.CFrame = CFrame.new(pos)
	stake.Parent = fx()
	local a0 = Instance.new("Attachment")
	a0.Parent = stake
	local a1 = Instance.new("Attachment")
	a1.Name = "TheriSnareAttachment"
	a1.Parent = mr
	local rope = Instance.new("RopeConstraint")
	rope.Name = "TheriSnareRope"
	rope.Attachment0, rope.Attachment1 = a0, a1
	rope.Length = (mr.Position - pos).Magnitude + 0.5
	rope.Visible = true
	rope.Color = BrickColor.new("Really red")
	rope.Thickness = 0.15 * char:GetScale()
	rope.Parent = stake
	m:SetAttribute("TheriSnaredUntil", t + rootT)
	m:SetAttribute("TheriSnaredBy", char.Name)
	task.delay(rootT, function()
		stake:Destroy()
		if a1.Parent then a1:Destroy() end
	end)
end
snareRemote.OnServerEvent:Connect(function(player, stamp)
	local char, t = check(player, stamp, "zsnare", "TheriSnare", nil, false)
	if not char then return end
	ok(char, "TheriSnare", t)
	local root = rootOf(char)
	local s = char:GetScale()
	local f = flat(root.CFrame.LookVector)
	f = f.Magnitude > 1e-3 and f.Unit or -Vector3.zAxis
	local p = root.Position + f * SNARE_AHEAD * s
	p = Vector3.new(p.X, groundY(p, root.Position.Y - 6), p.Z)
	local list = traps[char] or {}
	traps[char] = list
	local max = math.max(1, math.floor(num(char, "TheriSnareMax", 1)))
	while #list >= max do
		local old = table.remove(list, 1)
		if old.model then old.model:Destroy() end
	end
	table.insert(list, {model = buildTrap(char, p, s), pos = p, bornAt = t, player = player})
	char:SetAttribute("TheriSnareCount", #list)
	char:SetAttribute("TheriSnareAt", t) -- last
	trapCount()
end)

-- ticks: fields + traps ---------------------------------------------------------------------------------------------------------------
RunService.Heartbeat:Connect(function()
	local t = now()
	for char, f in pairs(fields) do
		if not char.Parent or t >= f.untilT or not on("zharvest") then
			fields[char] = nil
		elseif t >= f.nextTick then
			f.nextTick = t + FIELD_TICK
			for _, m in ipairs(candidates(char)) do
				local mr = rootOf(m)
				if gap(m, Vector3.new(f.center.X, mr.Position.Y, f.center.Z)) <= f.radius then
					damage(char, f.player, m, f.bleed * FIELD_TICK, "therifield", t)
					slow(m, f.slowMul, t + 0.6, t)
				end
			end
		end
	end
	local changed = false
	for char, list in pairs(traps) do
		local s = char.Parent and char:GetScale() or 1
		local radius = num(char, "TheriSnareRadius", 4) * s
		for i = #list, 1, -1 do
			local tr = list[i]
			local gone = not char.Parent or t - tr.bornAt >= SNARE_LIFE or not on("zsnare")
			if not gone then
				for _, m in ipairs(candidates(char)) do
					local mr = rootOf(m)
					if flat(mr.Position - tr.pos).Magnitude <= radius and not shielded(m, t) then
						damage(char, tr.player, m, num(char, "TheriSnareDamage", 12), "therisnare", t)
						hold(char, m, tr.pos, math.max(0, num(char, "TheriSnareRoot", 1)), t)
						char:SetAttribute("TheriSnareHitTarget", m.Name)
						char:SetAttribute("TheriSnareHitAt", t)
						gone = true
						break
					end
				end
			end
			if gone then
				if tr.model then tr.model:Destroy() end
				table.remove(list, i)
				changed = true
			end
		end
		if char.Parent then
			if char:GetAttribute("TheriSnareCount") ~= #list then char:SetAttribute("TheriSnareCount", #list) end
		elseif #list == 0 then
			traps[char] = nil
		end
	end
	if changed then trapCount() end
end)

-- v1.2: build 2 (see the header) ---------------------------------------------------------------------------------------------------
for _, k in ipairs({"TheriMoves_zgrappleEnabled", "TheriMoves_zdeflectEnabled", "TheriMoves_zclockEnabled"}) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, true) end
end
local GRAPPLE_MIN, ZIP_SPEED = 6, 120
local ZIP_SPEED_V2, ZIP_MAX_V2 = 150, 1.0 -- v1.3
if script:GetAttribute("TheriMovesGrappleV2Enabled") == nil then script:SetAttribute("TheriMovesGrappleV2Enabled", true) end -- v1.3
if script:GetAttribute("TheriMovesClockPassiveEnabled") == nil then script:SetAttribute("TheriMovesClockPassiveEnabled", true) end -- v1.3
local grappleRemote, deflectRemote, clockRemote = remote("DinoTheriGrappleRequest"), remote("DinoTheriDeflectRequest"), remote("DinoTheriClockRequest")
local zips = setmetatable({}, {__mode = "k"}) -- [char] = {refills = {times}}
local function grappleLeft(char, t)
	local st = zips[char]
	if not st then
		st = {refills = {}}
		zips[char] = st
	end
	for i = #st.refills, 1, -1 do
		if st.refills[i] <= t then table.remove(st.refills, i) end
	end
	local max = math.max(1, math.floor(num(char, "TheriGrappleCharges", 1)))
	return max - #st.refills, st, max
end
local function grapplePublish(char, t)
	local left, st = grappleLeft(char, t)
	local nextAt = math.huge
	for _, r in ipairs(st.refills) do nextAt = math.min(nextAt, r) end
	char:SetAttribute("TheriGrappleLeft", left)
	char:SetAttribute("TheriGrappleReadyAt", left > 0 and t or nextAt)
	if left <= 0 and nextAt < math.huge then
		task.delay(nextAt - t + 0.02, function() if char.Parent then grapplePublish(char, now()) end end)
	end
end
grappleRemote.OnServerEvent:Connect(function(player, stamp, aimDir)
	local c0 = player.Character
	if c0 then grappleLeft(c0, now()) grapplePublish(c0, now()) end -- refills first, so ReadyAt is current for check()
	local char, t = check(player, stamp, "zgrapple", "TheriGrapple", aimDir, true)
	if not char then return end
	local left, st = grappleLeft(char, t)
	if left <= 0 then
		char:SetAttribute("TheriGrappleServerResult", "cooldown")
		char:SetAttribute("TheriGrappleServerResultAt", t)
		return
	end
	local root = rootOf(char)
	local s = char:GetScale()
	local dir = typeof(aimDir) == "Vector3" and aimDir.Magnitude > 0.5 and aimDir.Unit or root.CFrame.LookVector
	local from = root.Position + Vector3.new(0, 2 * s, 0)
	local range = math.max(0, num(char, "TheriGrappleRange", 40))
	local hit = workspace:Raycast(from, dir * range, worldOnly())
	local v2 = script:GetAttribute("TheriMovesGrappleV2Enabled") ~= false -- v1.3
	if v2 and not hit and range > 0 then -- v1.3: nothing to grab -> latch in the air at full range
		local to = from + dir * range
		table.insert(st.refills, t + math.max(0.5, num(char, "TheriGrappleCooldown", 12)))
		char:SetAttribute("TheriGrappleServerResult", "ok")
		char:SetAttribute("TheriGrappleServerResultAt", t)
		grapplePublish(char, t)
		char:SetAttribute("TheriGrappleAir", true)
		char:SetAttribute("TheriGrappleAnchor", to)
		char:SetAttribute("TheriGrappleTo", to)
		char:SetAttribute("TheriGrappleTime", math.clamp((to - root.Position).Magnitude / ZIP_SPEED_V2, 0.2, ZIP_MAX_V2))
		char:SetAttribute("TheriGrappleResult", "zip")
		char:SetAttribute("TheriGrappleAt", t) -- last: TheriGrappleZip + FX
		return
	end
	if not hit or (hit.Position - from).Magnitude < GRAPPLE_MIN then
		char:SetAttribute("TheriGrappleResult", "noAnchor")
		char:SetAttribute("TheriGrappleServerResult", "noAnchor")
		char:SetAttribute("TheriGrappleServerResultAt", t)
		return
	end
	local to = hit.Position + hit.Normal * 3 * s
	local dist = (to - root.Position).Magnitude
	table.insert(st.refills, t + math.max(0.5, num(char, "TheriGrappleCooldown", 12)))
	char:SetAttribute("TheriGrappleServerResult", "ok")
	char:SetAttribute("TheriGrappleServerResultAt", t)
	grapplePublish(char, t)
	char:SetAttribute("TheriGrappleAnchor", hit.Position)
	char:SetAttribute("TheriGrappleTo", to)
	char:SetAttribute("TheriGrappleAir", false) -- v1.3
	if v2 then -- v1.3: faster, up to 1 s
		char:SetAttribute("TheriGrappleTime", math.clamp(dist / ZIP_SPEED_V2, 0.2, ZIP_MAX_V2))
	else
		char:SetAttribute("TheriGrappleTime", math.clamp(dist / ZIP_SPEED, 0.2, 0.9))
	end
	char:SetAttribute("TheriGrappleResult", "zip")
	char:SetAttribute("TheriGrappleAt", t) -- last: TheriGrappleZip + FX
end)
deflectRemote.OnServerEvent:Connect(function(player, stamp)
	local char, t = check(player, stamp, "zdeflect", "TheriDeflect", nil, false)
	if not char then return end
	ok(char, "TheriDeflect", t)
	char:SetAttribute("TheriDeflectUntil", t + math.max(0, num(char, "TheriDeflectTime", 1)))
	char:SetAttribute("TheriDeflectAt", t) -- last: FX + poses
end)
clockRemote.OnServerEvent:Connect(function(player, stamp)
	local c0 = player.Character -- v1.3: passive -> the button does nothing
	if c0 and c0:GetAttribute("TheriClockPassive") == true and script:GetAttribute("TheriMovesClockPassiveEnabled") ~= false then
		c0:SetAttribute("TheriClockServerResult", "passive")
		c0:SetAttribute("TheriClockServerResultAt", now())
		return
	end
	local char, t = check(player, stamp, "zclock", "TheriClock", nil, false)
	if not char then return end
	ok(char, "TheriClock", t)
	char:SetAttribute("TheriClockUntil", t + math.max(0, num(char, "TheriClockTime", 3)))
	char:SetAttribute("TheriClockAt", t) -- last: FX
end)

-- v1.3: passive Overclock + the air-latch flag for the marker (see the header) -----------------------------------------------------
local CLOCK_TICK = 0.25
task.spawn(function()
	while true do
		task.wait(CLOCK_TICK)
		local t = now()
		local passiveOn = script:GetAttribute("TheriMovesClockPassiveEnabled") ~= false and on("zclock")
		local air = script:GetAttribute("TheriMovesGrappleV2Enabled") ~= false
		for _, pl in ipairs(Players:GetPlayers()) do
			local char = pl.Character
			if char and char.Parent then
				if char:GetAttribute("TheriGrappleEnabled") ~= nil and char:GetAttribute("TheriGrappleAirLatch") ~= air then
					char:SetAttribute("TheriGrappleAirLatch", air)
				end
				local want = passiveOn and char:GetAttribute("TheriClockEnabled") == true
				if want then
					if char:GetAttribute("TheriClockPassive") ~= true or num(char, "TheriClockUntil", 0) < t + 1e5 then
						char:SetAttribute("TheriClockPassive", true)
						char:SetAttribute("TheriClockUntil", t + 1e6)
						char:SetAttribute("TheriClockAt", t) -- last: FX
					end
				elseif char:GetAttribute("TheriClockPassive") == true then
					char:SetAttribute("TheriClockPassive", false)
					char:SetAttribute("TheriClockUntil", t)
				end
			end
		end
	end
end)
