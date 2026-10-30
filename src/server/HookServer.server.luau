-- HookServer v1.0 (Mecha Dino Arena) — the pachy's Grappling Hook (right-arm wrist claw). MDA-121, plan
-- docs/plans/PACHY_PARTS_v1.0.md Drop A, mockup docs/mockups/pachy_parts_options.html ("A · Wrist claw", crosshair + aim help).
-- Kepu 2026-10-30: "a grappling hook that can hook to players and bring them in for a headsmash at 10 damage ... pull
--   them in then the pachy would dip its head for a smash which knocks them back without the slowed effect" · "connected
--   to its right arm ... something he lifts his arm to shoot" · "dont allow the grappling hook to work on objects ... this
--   will be strictly for pvp or bots".
-- Settings (character attributes, SkillEffects 1.14): HookEnabled, HookRange, HookCooldown, HookDamage, HookLook.
-- Remote DinoHookRequest(stamp, aimDir) (MechaButtons 1.15 sends the camera look). Checks in order: "badArg", "dead",
--   "disabled" (switch / HookEnabled), "menu", "stunned", "pinned", "busy" (own hook running, or a headbutt charge running:
--   HeadbuttStartedAt newer than HeadbuttEndedAt), "cooldown" (HookReadyAt) -> the shot. Result in HookServerResult.
-- The shot: origin = the right arm (segment ArmR Root, else the HumanoidRootPart). Only dinos can be grabbed: models in
--   Workspace with a Hitboxes folder, Bitable true, a Species or IsBot, not self, not KO (DummyState "ko"). Along the aim,
--   up to HookRange studs, the first dino whose hitbox comes within AIM_HELP x scale studs of the line is the
--   target ("crosshair + aim help"). The world (terrain, trees, rocks, props; every character / bot / tall grass excluded)
--   blocks: a world hit nearer than the target, or a wall between the arm and the target, = "blocked". Nothing found = "miss".
--   Target with Energy Shield up (EnergyShieldUntil) = "shielded". Every shot starts the cooldown (HookReadyAt).
--   Pachy stamps: HookAimDir, HookAimEnd (where the claw goes), HookTargetName (or ""), HookResult ("hit" / "miss" /
--   "blocked" / "shielded"), HookLaunchAt (= start + WINDUP, the arm is up), HookContactAt (claw arrives; 0 on a miss),
--   HookSmashAt (pull ends; 0 on a miss), HookStartedAt (set last; clients react to it). HookCount.
-- On a hit: the target is held and pulled for PULL_TIME to GAP_LEN x scale in front of the pachy (followed live):
--   a player's dino gets HookPullBy (pachy name), HookPullGap, HookPullTime, HookPullAt (last; HookPull 1.0 moves it on its
--   client); a bot is slid by this script (anchored, then released). Both get HookHeldUntil (StatusBadges / poses).
-- Smash at HookSmashAt: the pachy's head must be within (16 + 2) x scale of the target's hitboxes (else "escaped").
--   Damage = HookDamage x the roar debuff, off DummyHealth (ArenaPvP bridges it for players); killing blow -> KilledBy,
--   KilledByUserId, KilledWith "hook", KilledAt (last). Knockback SHOVE studs, no slow: players get HeadbuttShoveFrom /
--   HeadbuttShoveDist / HeadbuttShoveTime / HeadbuttShoveAt (HeadbuttShove 1.0 pushes them), bots are slid away. Energy
--   Shield up at the smash = no knockback. Pachy: HookHitDamage, HookHitTarget, HookHitCount, HookHitAt (last),
--   HookSmashResult ("smash" / "escaped" / "gone").
-- Look: while HookLook is true the pachy carries "Mecha_HookArm" (a slim steel wrist cuff + claw on ArmR, colours no skin
--   role uses); removed when false. HookBusyUntil (server time) while a shot runs (HeadbuttServer 1.2 refuses then).
-- Switch: script attribute HookServerEnabled (default true, read at start). Diagnostics: script HookServerVersion,
--   HookShots, HookHits.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local VERSION = "1.0"
local WINDUP = 0.15        -- s arm raise before the claw flies
local CLAW_SPEED = 220     -- studs/s (world)
local PULL_TIME = 0.5      -- s
local GAP_LEN = 9          -- studs x scale: where the target ends up in front of the pachy's root
local AIM_HELP = 4         -- studs x scale around the aim line
local SMASH_TOL = 18       -- studs x scale head-to-hitbox for the smash
local SHOVE, SHOVE_TIME = 30, 0.35
local STEEL, STEEL_DARK = Color3.fromRGB(154, 166, 184), Color3.fromRGB(93, 104, 120)

script:SetAttribute("HookServerVersion", VERSION)
script:SetAttribute("HookShots", 0)
script:SetAttribute("HookHits", 0)
if script:GetAttribute("HookServerEnabled") == nil then script:SetAttribute("HookServerEnabled", true) end
local enabled = script:GetAttribute("HookServerEnabled") ~= false

local remote = ReplicatedStorage:FindFirstChild("DinoHookRequest")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "DinoHookRequest"
	remote.Parent = ReplicatedStorage
end

local function now() return workspace:GetServerTimeNow() end

local function armOrigin(char)
	local seg = char:FindFirstChild("ArmR")
	local root = seg and (seg:IsA("BasePart") and seg or seg:FindFirstChild("Root"))
	if root and root:IsA("BasePart") then return root.Position end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	return hrp and hrp.Position
end

local function headPos(char)
	local hb = char:FindFirstChild("Hitboxes")
	if hb then
		for _, p in ipairs(hb:GetChildren()) do
			if p:IsA("BasePart") and p:GetAttribute("HitboxSegment") == "Head" then return p.Position end
		end
	end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	return hrp and hrp.Position
end

local function closestOnBox(part, pos)
	local lp = part.CFrame:PointToObjectSpace(pos)
	local h = part.Size / 2
	local c = Vector3.new(math.clamp(lp.X, -h.X, h.X), math.clamp(lp.Y, -h.Y, h.Y), math.clamp(lp.Z, -h.Z, h.Z))
	return part.CFrame:PointToWorldSpace(c)
end

local function gapTo(pos, hb)
	local best = math.huge
	for _, p in ipairs(hb:GetChildren()) do
		if p:IsA("BasePart") then best = math.min(best, (closestOnBox(p, pos) - pos).Magnitude) end
	end
	return best
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
		if c then local hb = isTarget(c, self) if hb then table.insert(list, {m = c, hb = hb}) end end
	end
	local isl = workspace:FindFirstChild("DinoIsland")
	local bots = isl and isl:FindFirstChild("Bots")
	if bots then
		for _, b in ipairs(bots:GetChildren()) do
			local hb = isTarget(b, self) if hb then table.insert(list, {m = b, hb = hb}) end
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
	local fx = workspace:FindFirstChild("DinoFX_Local")
	if fx then table.insert(ex, fx) end
	for _, d in ipairs(workspace:GetChildren()) do
		if d:IsA("Model") and (d:FindFirstChild("Hitboxes") or d:FindFirstChildOfClass("Humanoid")) then table.insert(ex, d) end
	end
	worldParams.FilterDescendantsInstances = ex
	return worldParams
end

-- the look: slim cuff + claw on the right wrist
local function setLook(char)
	local want = char:GetAttribute("HookLook") == true and char:GetAttribute("Species") == "Pachy"
	local old = char:FindFirstChild("Mecha_HookArm")
	if not want then
		if old then old:Destroy() end
		return
	end
	if old then return end
	local seg = char:FindFirstChild("ArmR")
	local root = seg and (seg:IsA("BasePart") and seg or seg:FindFirstChild("Root"))
	if not (root and root:IsA("BasePart")) then return end
	-- the arm's lowest visible part = the forearm / hand
	local hand, low = nil, math.huge
	for _, p in ipairs(seg:GetDescendants()) do
		if p:IsA("BasePart") and p.Transparency < 1 and p ~= root then
			local y = root.CFrame:PointToObjectSpace(p.Position).Y
			if y < low then hand, low = p, y end
		end
	end
	hand = hand or root
	local s = char:GetScale()
	local m = Instance.new("Model")
	m.Name = "Mecha_HookArm"
	local function part(name, size, color, cf)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size * s
		p.Color = color
		p.Material = Enum.Material.Metal
		p.CanCollide, p.CanQuery, p.CanTouch, p.Massless = false, false, false, true
		p.CFrame = hand.CFrame * CFrame.new(cf.Position * s) * cf.Rotation
		p.Parent = m
		local w = Instance.new("WeldConstraint")
		w.Part0, w.Part1 = hand, p
		w.Parent = p
		return p
	end
	part("Cuff", Vector3.new(0.5, 0.35, 0.5), STEEL, CFrame.new(0, 0, 0))
	part("Barrel", Vector3.new(0.18, 0.18, 0.45), STEEL_DARK, CFrame.new(0, 0.05, -0.3))
	part("ClawL", Vector3.new(0.08, 0.08, 0.22), STEEL, CFrame.new(-0.1, 0.05, -0.55))
	part("ClawR", Vector3.new(0.08, 0.08, 0.22), STEEL, CFrame.new(0.1, 0.05, -0.55))
	m.Parent = char
	char:SetAttribute("HookLookBuilt", true)
end

-- bot slides (anchored, followed live)
local function slide(model, goalFn, time, done)
	local hrp = model:FindFirstChild("HumanoidRootPart")
	if not hrp or hrp.Anchored then return false end
	local start = hrp.Position
	local rot = hrp.CFrame - hrp.Position
	hrp.Anchored = true
	task.spawn(function()
		local t0 = os.clock()
		while os.clock() - t0 < time do
			if not hrp.Parent then return end
			local u = math.clamp((os.clock() - t0) / time, 0, 1)
			local e = 1 - (1 - u) * (1 - u)
			local g = goalFn()
			hrp.CFrame = CFrame.new(start:Lerp(Vector3.new(g.X, start.Y, g.Z), e)) * rot
			RunService.Heartbeat:Wait()
		end
		if hrp.Parent then
			local g = goalFn()
			hrp.CFrame = CFrame.new(Vector3.new(g.X, start.Y, g.Z)) * rot
			hrp.Anchored = false
		end
		if done then done() end
	end)
	return true
end

local busy = {} -- [char] = true while a shot runs

local function smash(char, player, target, hb)
	local t = now()
	local result
	if not char.Parent or not target.Parent or not isTarget(target, char) then
		result = "gone"
	else
		local hp = headPos(char)
		local s = char:GetScale()
		if not hp or gapTo(hp, hb) > SMASH_TOL * s then result = "escaped" end
	end
	char:SetAttribute("HookSmashResult", result or "smash")
	if result then return end
	local mul = 1
	local untilT, dmul = target:GetAttribute("DebuffUntil"), target:GetAttribute("DebuffDamageTakenMul")
	if typeof(untilT) == "number" and typeof(dmul) == "number" and t < untilT then mul = dmul end
	local d = math.floor((tonumber(char:GetAttribute("HookDamage")) or 10) * mul + 0.5)
	local hpv = target:GetAttribute("DummyHealth")
	if typeof(hpv) == "number" then target:SetAttribute("DummyHealth", math.max(0, hpv - d)) end
	if typeof(hpv) == "number" and hpv > 0 and hpv - d <= 0 then
		target:SetAttribute("KilledBy", char.Name)
		target:SetAttribute("KilledByUserId", player.UserId)
		target:SetAttribute("KilledWith", "hook")
		target:SetAttribute("KilledAt", t)
	end
	local root = char:FindFirstChild("HumanoidRootPart")
	local from = root and root.Position or target:GetPivot().Position
	local shielded = (tonumber(target:GetAttribute("EnergyShieldUntil")) or 0) > t
	if not shielded then
		local dist = SHOVE
		if Players:GetPlayerFromCharacter(target) then
			target:SetAttribute("HeadbuttShoveFrom", from)
			target:SetAttribute("HeadbuttShoveDist", dist)
			target:SetAttribute("HeadbuttShoveTime", SHOVE_TIME)
			target:SetAttribute("HeadbuttShoveAt", t) -- HeadbuttShove 1.0 pushes it; no slow stamps
		else
			local thrp = target:FindFirstChild("HumanoidRootPart")
			if thrp then
				local away = (thrp.Position - from) * Vector3.new(1, 0, 1)
				away = away.Magnitude > 1e-3 and away.Unit or Vector3.zAxis
				local goal = thrp.Position + away * dist
				slide(target, function() return goal end, SHOVE_TIME)
			end
		end
	end
	target:SetAttribute("HookSmashedBy", char.Name)
	char:SetAttribute("HookHitDamage", d)
	char:SetAttribute("HookHitTarget", target.Name)
	char:SetAttribute("HookHitCount", (char:GetAttribute("HookHitCount") or 0) + 1)
	char:SetAttribute("HookHitAt", t) -- last: ArenaPvP / SkillEffects / clients
	script:SetAttribute("HookHits", (script:GetAttribute("HookHits") or 0) + 1)
end

local function setResult(char, r)
	char:SetAttribute("HookServerResult", r)
	char:SetAttribute("HookServerResultAt", now())
end

remote.OnServerEvent:Connect(function(player, stamp, aimDir)
	local char = player.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local t = now()
	local r
	if typeof(stamp) ~= "number" or typeof(aimDir) ~= "Vector3" or aimDir.Magnitude < 0.5 or aimDir.Magnitude > 1.5 then
		r = "badArg"
	elseif not hum or hum.Health <= 0 then
		r = "dead"
	elseif not enabled or char:GetAttribute("HookEnabled") ~= true then
		r = "disabled"
	elseif player:GetAttribute("InMenu") == true then
		r = "menu"
	elseif (tonumber(char:GetAttribute("StunnedUntil")) or 0) > t then
		r = "stunned"
	elseif char:GetAttribute("PinHeld") == true then
		r = "pinned"
	elseif busy[char] or (tonumber(char:GetAttribute("HeadbuttStartedAt")) or 0) > (tonumber(char:GetAttribute("HeadbuttEndedAt")) or 0) then
		r = "busy"
	elseif t < (tonumber(char:GetAttribute("HookReadyAt")) or 0) then
		r = "cooldown"
	end
	if r then setResult(char, r) return end
	setResult(char, "ok")
	busy[char] = true
	local s = char:GetScale()
	local dir = aimDir.Unit
	local origin = armOrigin(char) or char:GetPivot().Position
	local range = tonumber(char:GetAttribute("HookRange")) or 60
	local params = worldExclude()
	local wall = workspace:Raycast(origin, dir * range, params)
	local wallDist = wall and (wall.Position - origin).Magnitude or math.huge
	-- first dino near the line
	local best, bestT, bestHb, bestPoint
	for _, c in ipairs(candidates(char)) do
		for _, p in ipairs(c.hb:GetChildren()) do
			if p:IsA("BasePart") then
				local tt = math.clamp((p.Position - origin):Dot(dir), 0, range)
				local onLine = origin + dir * tt
				local cp = closestOnBox(p, onLine)
				if (cp - onLine).Magnitude <= AIM_HELP * s and tt > 0 and (not bestT or tt < bestT) then
					best, bestT, bestHb, bestPoint = c.m, tt, c.hb, cp
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
	elseif wall then
		result = "miss"
	end
	local fly = (aimEnd - origin).Magnitude / CLAW_SPEED
	local launchAt = t + WINDUP
	local contactAt = result == "hit" and (launchAt + fly) or 0
	local smashAt = result == "hit" and (contactAt + PULL_TIME) or 0
	local endAt = result == "hit" and smashAt + 0.3 or (launchAt + fly * 2 + 0.1)
	char:SetAttribute("HookReadyAt", t + math.max(0.5, tonumber(char:GetAttribute("HookCooldown")) or 8))
	char:SetAttribute("HookBusyUntil", endAt)
	char:SetAttribute("HookAimDir", dir)
	char:SetAttribute("HookAimEnd", aimEnd)
	char:SetAttribute("HookTargetName", result == "hit" and best.Name or "")
	char:SetAttribute("HookResult", result)
	char:SetAttribute("HookLaunchAt", launchAt)
	char:SetAttribute("HookContactAt", contactAt)
	char:SetAttribute("HookSmashAt", smashAt)
	char:SetAttribute("HookCount", (char:GetAttribute("HookCount") or 0) + 1)
	char:SetAttribute("HookStartedAt", t) -- last
	script:SetAttribute("HookShots", (script:GetAttribute("HookShots") or 0) + 1)
	if result == "hit" then
		local target, hb = best, bestHb
		task.delay(contactAt - t, function()
			if not (char.Parent and target.Parent) then busy[char] = nil return end
			local s2 = char:GetScale()
			local function goal()
				local hrp = char:FindFirstChild("HumanoidRootPart")
				if not hrp then return target:GetPivot().Position end
				local f = hrp.CFrame.LookVector * Vector3.new(1, 0, 1)
				f = f.Magnitude > 1e-3 and f.Unit or Vector3.zAxis
				return hrp.Position + f * GAP_LEN * s2
			end
			target:SetAttribute("HookHeldUntil", smashAt)
			if Players:GetPlayerFromCharacter(target) then
				target:SetAttribute("HookPullBy", char.Name)
				target:SetAttribute("HookPullGap", GAP_LEN * s2)
				target:SetAttribute("HookPullTime", PULL_TIME)
				target:SetAttribute("HookPullAt", now()) -- last: HookPull 1.0 on that player's client
			else
				slide(target, goal, PULL_TIME)
			end
		end)
		task.delay(smashAt - t, function()
			busy[char] = nil
			local player2 = Players:GetPlayerFromCharacter(char)
			if player2 then smash(char, player2, target, hb) end
		end)
	else
		task.delay(endAt - t, function() busy[char] = nil end)
	end
end)

local function onCharacter(char)
	char:GetAttributeChangedSignal("HookLook"):Connect(function() setLook(char) end)
	task.defer(setLook, char)
	char.AncestryChanged:Connect(function(_, parent) if not parent then busy[char] = nil end end)
end
local function onPlayer(p)
	p.CharacterAdded:Connect(onCharacter)
	if p.Character then onCharacter(p.Character) end
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do onPlayer(p) end
