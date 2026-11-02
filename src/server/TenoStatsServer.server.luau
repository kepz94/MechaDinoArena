-- TenoStatsServer v1.1 (Mecha Dino Arena) — the Tenontosaurus' stat rows in play: Charge Up, Brace and Buck Off. Plan
-- docs/plans/TENO_STATS_v1.0.md (deterministic map), mockup docs/mockups/teno_stats_options.html (Kepu 2026-10-31: speed C,
-- defense C, signature "Buck Off": "This only works when latched. If you're stunned and then latched it doesn't work",
-- stun rule "Off only while stunned"). Reads the character attributes SkillEffects 1.31 writes (SkillTree 1.45 effects).
-- Who: player characters with Species "Teno"; everything below is off on other dinos and when a row is not bought.
-- Charge Up:
--   * Running = flat speed >= RUN_FRAC (0.8) x MoveRunSpeed; a dip below for more than DIP_GRACE (0.3) s, a stun or death
--     resets the timer. TenoChargeLevel 1 after 2 s, 2 after 3 s. TenoChargeMul = TenoChargeMul2 at level 2,
--     TenoChargeMul1 at level 1, else 1 (SprintTest 1.17 multiplies the speed by it).
--   * II: at level 2 with TenoChargeNoShove the character's HeadbuttShoveEnabled = false (no shove from a pachy headbutt,
--     a teno scratch, a Dome Visor knock or a Stun Breaker push); back to nil when it ends.
--   * III: at level 2 with TenoChargeBump > 0, each allowed target (players where ModeRules allow, bots; never a squadmate,
--     never a latched raptor, never one with its Energy Shield up) whose root is inside a 70-degree cone ahead and whose
--     hitboxes are within BUMP_REACH (3) x scale of the point BUMP_AHEAD (5) x scale ahead of the root is shoved
--     TenoChargeBump studs to the side it is on (players: HeadbuttShove*, 0.3 s; bots: an anchored slide); once per
--     target per BUMP_GAP (1.5) s. Star: it is also stunned TenoChargeBumpStun s (StunnedUntil = max(it, now + stun)).
-- Brace (holding = TenoHoldSince > 0, TenoAttackServer):
--   * I: each Humanoid health drop while holding is refunded drop x (1 - TenoBraceMul) (a killing blow is not refunded).
--   * II: SkillEffects 1.31 cancels stuns while holding; here the shove switch above is also set while holding with
--     TenoBraceNoStun.
--   * III: each health drop while holding adds TenoBraceStack to TenoBraceBonus (TenoAttackServer 1.1 adds it to every
--     slam target); reset when a new hold starts and after the slam's impact.
--   * Star: at TenoSlamImpactAt the teno heals TenoBraceHeal x MaxHealth x TenoSlamHits.
-- Buck Off (latched = a raptor with PounceLatched whose PounceLatchPart is inside the teno, not a pin; nothing while the
--   teno is stunned):
--   * TenoLatchedCount = how many are latched now (TenoAttackTest 1.1 uses it for the free hold).
--   * III: a slam that bucked off >= 1 raptor (TenoSlamBucked) with TenoBuckImmune > 0 sets TenoLatchImmuneUntil = impact +
--     TenoBuckImmune; until then any latch on the teno is shaken off at once (ShakeOffReason "buckoff", ShakeOffAt now; no
--     damage, no toss).
--   * Star: every latched raptor loses TenoBuckDps DummyHealth each full second it stays latched (a killing tick stamps
--     KilledBy / KilledByUserId / KilledWith "buckoff" / KilledAt).
-- Switch: script attribute TenoStatsServerEnabled (default true, read at each step; false = nothing here runs and the
--   shove switch / TenoChargeMul go back to off).
-- Diagnostics: script TenoStatsServerVersion, TenoStatsBumps, TenoStatsRepelled, TenoStatsTicks; character TenoChargeLevel,
--   TenoChargeMul, TenoBumpCount, TenoBumpLast, TenoBraceHits, TenoBraceBonus, TenoBraceRefunded (total), TenoBraceHealed,
--   TenoLatchedCount, TenoLatchImmuneUntil, TenoBuckTicks.
-- v1.1 (teno stats part 2, MDA-185, plan docs/plans/TENO_STATS_v1.1.md; SkillEffects 1.34 / SkillTree 1.50) Survivor. Switch:
--   script attribute TenoStatsSurvivorEnabled (default true, read at each step; false = 1.0). Every 0.2 s each model in
--   play (players' characters, DinoIsland.Bots) whose KilledAt changed is a death; for each living teno character:
--   * KilledBy = the teno's name and TenoSurvivorKillHeal > 0 -> heal TenoSurvivorKillHeal x MaxHealth over 4 s (its own
--     stream, capped at MaxHealth); with TenoSurvivorRefill (star) also +1 slam charge (TenoAttackServer 1.3's BindableEvent
--     TenoAddCharge, never above the max).
--   * else, TenoSurvivorNearHeal > 0, the dead model allowed for the teno (ModeRules, not a squadmate) and its root within
--     TenoSurvivorNearRange studs (25) of the teno's root -> heal TenoSurvivorNearHeal x MaxHealth over 4 s (III).
--   A kill by the teno never also gives the near heal. Diagnostics: character TenoSurvivorHeals (count), TenoSurvivorLast
--   ("kill" / "near"); script TenoStatsSurvivorHeals.
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")

local VERSION = "1.1"
local RUN_FRAC, DIP_GRACE, LEVEL1_T, LEVEL2_T = 0.8, 0.3, 2, 3
local BUMP_AHEAD, BUMP_REACH, BUMP_CONE, BUMP_GAP, BUMP_TIME = 5, 3, math.rad(35), 1.5, 0.3

script:SetAttribute("TenoStatsServerVersion", VERSION)
for _, k in ipairs({"TenoStatsBumps", "TenoStatsRepelled", "TenoStatsTicks"}) do script:SetAttribute(k, 0) end
if script:GetAttribute("TenoStatsServerEnabled") == nil then script:SetAttribute("TenoStatsServerEnabled", true) end
local function on() return script:GetAttribute("TenoStatsServerEnabled") ~= false end

local function now() return workspace:GetServerTimeNow() end
local function count(k, n) script:SetAttribute(k, (script:GetAttribute(k) or 0) + (n or 1)) end
local function num(m, k, d) return tonumber(m:GetAttribute(k)) or d end
local function flat(v) return Vector3.new(v.X, 0, v.Z) end
local function rootOf(m) return m:FindFirstChild("HumanoidRootPart") end
local function show(m, k, v) if m:GetAttribute(k) ~= v then m:SetAttribute(k, v) end end

-- mode + squad rules (TenoAttackServer 1.0) ----------------------------------------------------------------------------
local ModeRules = require(ServerStorage:WaitForChild("DinoArcade"):WaitForChild("ModeRules"))
local MODE = ModeRules.currentMode()
local squadMod
local function squadmate(a, b)
	if not squadMod then
		local arc = ServerStorage:FindFirstChild("DinoArcade")
		local m = arc and arc:FindFirstChild("SquadRules")
		if not m then return false end
		local ok, mod = pcall(require, m)
		if not ok then return false end
		squadMod = mod
	end
	return squadMod.sameChar(a, b) == true
end
local function mayAffect(source, target)
	if squadmate(source, target) then return false end
	local tpl = Players:GetPlayerFromCharacter(target)
	local spl = Players:GetPlayerFromCharacter(source)
	local inMenu = tpl ~= nil and tpl:GetAttribute("InMenu") == true
	return ModeRules.canAffect(spl ~= nil, tpl ~= nil, inMenu, MODE)
end
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
local function allModels()
	local list = {}
	for _, pl in ipairs(Players:GetPlayers()) do if pl.Character then table.insert(list, pl.Character) end end
	for _, b in ipairs(bots()) do table.insert(list, b) end
	return list
end
local function gap(m, pos)
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
local function latchersOn(char)
	local list = {}
	for _, m in ipairs(allModels()) do
		if m ~= char and m:GetAttribute("PounceLatched") == true and m:GetAttribute("PounceMode") ~= "pin" then
			local v = m:FindFirstChild("PounceLatchPart")
			if v and v:IsA("ObjectValue") and v.Value ~= nil and v.Value:IsDescendantOf(char) then table.insert(list, m) end
		end
	end
	return list
end

-- the bump's sideways shove (TenoAttackServer 1.0 shove's pattern, with a direction)
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
local function groundY(pos, fallback)
	local g = workspace:Raycast(Vector3.new(pos.X, pos.Y + 40, pos.Z), Vector3.new(0, -160, 0), rayParams)
	return g and g.Position.Y or fallback
end
local function bump(m, dir, dist, t)
	local mRoot = rootOf(m)
	if not mRoot or dist <= 0 then return false end
	if Players:GetPlayerFromCharacter(m) then
		m:SetAttribute("HeadbuttShoveFrom", mRoot.Position - dir * 5)
		m:SetAttribute("HeadbuttShoveDist", dist)
		m:SetAttribute("HeadbuttShoveTime", BUMP_TIME)
		m:SetAttribute("HeadbuttShoveAt", t) -- last: HeadbuttShove 1.0 pushes it
		return true
	elseif mRoot.Anchored then
		return false
	end
	local start = mRoot.Position
	local land = start + dir * dist
	local ex = allModels()
	local isl = workspace:FindFirstChild("DinoIsland")
	local tg = isl and isl:FindFirstChild("TallGrass")
	if tg then table.insert(ex, tg) end
	rayParams.FilterDescendantsInstances = ex
	local lift = start.Y - groundY(start, start.Y - 3)
	local landPos = Vector3.new(land.X, groundY(land, start.Y - lift) + lift, land.Z)
	local rot = mRoot.CFrame - mRoot.Position
	mRoot.Anchored = true
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < BUMP_TIME do
			local u = math.clamp((os.clock() - t0) / BUMP_TIME, 0, 1)
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

-- per character --------------------------------------------------------------------------------------------------------
local chars = {} -- [char] = state
local function isTeno(char) return char:GetAttribute("Species") == "Teno" end
local function holding(char) return num(char, "TenoHoldSince", 0) > 0 end

local function track(char, player)
	if chars[char] then return end
	local hum = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 10)
	if not hum then return end
	local st = {player = player, hum = hum, runSince = nil, lowSince = nil, level = 0, shoveOwned = false,
		last = hum.Health, hits = 0, ownHealth = nil, bumped = {}, acc = {}, immuneUntil = 0}
	chars[char] = st
	hum.HealthChanged:Connect(function(h)
		if st.ownHealth and math.abs(h - st.ownHealth) < 1e-3 then st.ownHealth = nil st.last = h return end
		local drop = st.last - h
		st.last = h
		if drop <= 0 or h <= 0 or not on() or not isTeno(char) or not holding(char) then return end
		st.hits += 1
		show(char, "TenoBraceHits", st.hits)
		local stack = math.max(0, num(char, "TenoBraceStack", 0))
		show(char, "TenoBraceBonus", stack * st.hits)
		local mul = math.clamp(num(char, "TenoBraceMul", 1), 0, 1)
		if mul < 1 then -- Brace I: refund the cut
			local refund = drop * (1 - mul)
			local new = math.min(hum.MaxHealth, h + refund)
			st.ownHealth, st.last = new, new
			hum.Health = new
			char:SetAttribute("TenoBraceRefunded", math.floor(((char:GetAttribute("TenoBraceRefunded") or 0) + refund) * 10 + 0.5) / 10)
		end
	end)
	char:GetAttributeChangedSignal("TenoHoldSince"):Connect(function()
		if holding(char) then -- a new hold: Brace III starts from 0
			st.hits = 0
			show(char, "TenoBraceHits", 0)
			show(char, "TenoBraceBonus", 0)
		end
	end)
	char:GetAttributeChangedSignal("TenoSlamImpactAt"):Connect(function()
		local t = now()
		if on() and isTeno(char) and hum.Health > 0 then
			local frac, n = math.max(0, num(char, "TenoBraceHeal", 0)), math.max(0, num(char, "TenoSlamHits", 0))
			if frac > 0 and n > 0 then -- Brace star
				local new = math.min(hum.MaxHealth, hum.Health + frac * hum.MaxHealth * n)
				show(char, "TenoBraceHealed", math.floor((new - hum.Health) * 10 + 0.5) / 10)
				st.ownHealth, st.last = new, new
				hum.Health = new
			end
			local immune = math.max(0, num(char, "TenoBuckImmune", 0))
			if immune > 0 and num(char, "TenoSlamBucked", 0) > 0 and num(char, "StunnedUntil", 0) <= t then -- Buck Off III
				st.immuneUntil = t + immune
				char:SetAttribute("TenoLatchImmuneUntil", st.immuneUntil)
			end
		end
		st.hits = 0
		show(char, "TenoBraceHits", 0)
		show(char, "TenoBraceBonus", 0)
	end)
	char.AncestryChanged:Connect(function(_, parent)
		if not parent then chars[char] = nil end
	end)
end

local function setShove(char, st, want)
	if want and not st.shoveOwned then
		char:SetAttribute("HeadbuttShoveEnabled", false)
		st.shoveOwned = true
	elseif not want and st.shoveOwned then
		char:SetAttribute("HeadbuttShoveEnabled", nil)
		st.shoveOwned = false
	end
end

RunService.Heartbeat:Connect(function(dt)
	local t = now()
	for char, st in pairs(chars) do
		local hrp, hum = rootOf(char), st.hum
		local active = on() and isTeno(char) and hrp ~= nil and hum.Health > 0
		local stunned = num(char, "StunnedUntil", 0) > t
		if not active then
			st.runSince, st.lowSince, st.level = nil, nil, 0
			if char:GetAttribute("TenoChargeMul") ~= nil then char:SetAttribute("TenoChargeMul", 1) end
			setShove(char, st, false)
			continue
		end
		-- Charge Up: the run timer
		local run = math.max(1, num(char, "MoveRunSpeed", 28))
		local moving = not stunned and flat(hrp.AssemblyLinearVelocity).Magnitude >= RUN_FRAC * run
		if moving then
			st.runSince = st.runSince or t
			st.lowSince = nil
		elseif st.runSince then
			st.lowSince = st.lowSince or t
			if stunned or t - st.lowSince > DIP_GRACE then st.runSince, st.lowSince = nil, nil end
		end
		local ran = st.runSince and (t - st.runSince) or 0
		st.level = ran >= LEVEL2_T and 2 or (ran >= LEVEL1_T and 1 or 0)
		show(char, "TenoChargeLevel", st.level)
		local mul = st.level == 2 and num(char, "TenoChargeMul2", 1) or (st.level == 1 and num(char, "TenoChargeMul1", 1) or 1)
		show(char, "TenoChargeMul", mul)
		-- Charge Up II / Brace II: no shoves
		setShove(char, st, (st.level == 2 and char:GetAttribute("TenoChargeNoShove") == true)
			or (holding(char) and char:GetAttribute("TenoBraceNoStun") == true))
		-- Charge Up III / star: the bump
		local bumpDist = math.max(0, num(char, "TenoChargeBump", 0))
		if st.level == 2 and bumpDist > 0 then
			local s = char:GetScale()
			local fwd = flat(hrp.CFrame.LookVector)
			fwd = fwd.Magnitude > 1e-3 and fwd.Unit or Vector3.zAxis
			local right = flat(hrp.CFrame.RightVector)
			right = right.Magnitude > 1e-3 and right.Unit or Vector3.xAxis
			local front = hrp.Position + fwd * BUMP_AHEAD * s
			for _, m in ipairs(allModels()) do
				if isTarget(m, char) and mayAffect(char, m) and m:GetAttribute("PounceLatched") ~= true and not shielded(m, t)
					and t - (st.bumped[m] or -math.huge) >= BUMP_GAP then
					local v = flat(rootOf(m).Position - hrp.Position)
					if v.Magnitude > 1e-3 and math.acos(math.clamp(fwd:Dot(v.Unit), -1, 1)) <= BUMP_CONE and gap(m, front) <= BUMP_REACH * s then
						st.bumped[m] = t
						local dir = right * (right:Dot(v) >= 0 and 1 or -1)
						bump(m, dir, bumpDist, t)
						local stun = math.max(0, num(char, "TenoChargeBumpStun", 0))
						if stun > 0 then m:SetAttribute("StunnedUntil", math.max(num(m, "StunnedUntil", 0), t + stun)) end
						char:SetAttribute("TenoBumpCount", (char:GetAttribute("TenoBumpCount") or 0) + 1)
						char:SetAttribute("TenoBumpLast", m.Name)
						count("TenoStatsBumps")
					end
				end
			end
		end
		-- Buck Off
		local latched = latchersOn(char)
		show(char, "TenoLatchedCount", #latched)
		local keep = {}
		if not stunned then
			for _, m in ipairs(latched) do
				if mayAffect(char, m) then
					if t < st.immuneUntil then -- III: shaken off at once
						m:SetAttribute("ShakeOffReason", "buckoff")
						m:SetAttribute("ShakeOffAt", t) -- last: PounceServer / BotServer release the latch
						count("TenoStatsRepelled")
					else
						local dps = math.max(0, num(char, "TenoBuckDps", 0))
						if dps > 0 and not shielded(m, t) then -- star: a tick per full second latched
							keep[m] = true
							st.acc[m] = (st.acc[m] or 0) + dt
							while st.acc[m] >= 1 do
								st.acc[m] -= 1
								takeHealth(m, dps, char, st.player, "buckoff", t)
								char:SetAttribute("TenoBuckTicks", (char:GetAttribute("TenoBuckTicks") or 0) + 1)
								count("TenoStatsTicks")
							end
						end
					end
				end
			end
		end
		for m in pairs(st.acc) do if not keep[m] then st.acc[m] = nil end end
	end
end)

-- v1.1: Survivor --------------------------------------------------------------------------------------------------------
if script:GetAttribute("TenoStatsSurvivorEnabled") == nil then script:SetAttribute("TenoStatsSurvivorEnabled", true) end
script:SetAttribute("TenoStatsSurvivorHeals", 0)
local SURVIVOR_TIME, SURVIVOR_POLL = 4, 0.2
local seenKill = {} -- [model] = last KilledAt
local streams = {} -- [char] = {{rate, untilT}, ...}
local function survivorOn() return on() and script:GetAttribute("TenoStatsSurvivorEnabled") ~= false end
local function addStream(char, frac, why)
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 or frac <= 0 then return end
	streams[char] = streams[char] or {}
	table.insert(streams[char], {rate = frac * hum.MaxHealth / SURVIVOR_TIME, untilT = os.clock() + SURVIVOR_TIME})
	char:SetAttribute("TenoSurvivorHeals", (char:GetAttribute("TenoSurvivorHeals") or 0) + 1)
	char:SetAttribute("TenoSurvivorLast", why)
	count("TenoStatsSurvivorHeals")
end
local function addCharge(char)
	local tas = game:GetService("ServerScriptService"):FindFirstChild("TenoAttackServer")
	local ev = tas and tas:FindFirstChild("TenoAddCharge")
	if ev and ev:IsA("BindableEvent") then ev:Fire(char) end
end
local survAcc = 0
RunService.Heartbeat:Connect(function(dt)
	-- heal streams
	local c = os.clock()
	for char, list in pairs(streams) do
		local hum = char.Parent and char:FindFirstChildOfClass("Humanoid")
		if not hum or hum.Health <= 0 then
			streams[char] = nil
		else
			local add = 0
			for i = #list, 1, -1 do
				local e = list[i]
				add += e.rate * dt
				if c >= e.untilT then table.remove(list, i) end
			end
			if add > 0 and hum.Health < hum.MaxHealth then hum.Health = math.min(hum.MaxHealth, hum.Health + add) end
			if #list == 0 then streams[char] = nil end
		end
	end
	survAcc += dt
	if survAcc < SURVIVOR_POLL then return end
	survAcc = 0
	local on2 = survivorOn()
	local deaths = {}
	for _, m in ipairs(allModels()) do
		local at = m:GetAttribute("KilledAt")
		if typeof(at) == "number" and seenKill[m] ~= at then
			if seenKill[m] ~= nil or (now() - at) < 1 then table.insert(deaths, m) end -- first sight: only a fresh death counts
			seenKill[m] = at
		end
	end
	for m in pairs(seenKill) do if not m.Parent then seenKill[m] = nil end end
	if not on2 or #deaths == 0 then return end
	for _, pl in ipairs(Players:GetPlayers()) do
		local char = pl.Character
		local root = char and rootOf(char)
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if root and hum and hum.Health > 0 and isTeno(char) then
			local killHeal, nearHeal = num(char, "TenoSurvivorKillHeal", 0), num(char, "TenoSurvivorNearHeal", 0)
			local nearRange = num(char, "TenoSurvivorNearRange", 0)
			for _, m in ipairs(deaths) do
				if m ~= char then
					if m:GetAttribute("KilledBy") == char.Name and killHeal > 0 then
						addStream(char, killHeal, "kill")
						if char:GetAttribute("TenoSurvivorRefill") == true then addCharge(char) end
					elseif nearHeal > 0 and nearRange > 0 and m:GetAttribute("KilledBy") ~= char.Name and mayAffect(char, m) then
						local r = rootOf(m)
						if r and (r.Position - root.Position).Magnitude <= nearRange then addStream(char, nearHeal, "near") end
					end
				end
			end
		end
	end
end)

local function onPlayer(p)
	p.CharacterAdded:Connect(function(c) task.defer(track, c, p) end)
	if p.Character then task.defer(track, p.Character, p) end
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do onPlayer(p) end
