-- RoarServer v1.3 (Dino Arcade) — TEST. Validates roar requests from players and stamps the start time.
-- Client -> server: ReplicatedStorage.DinoRoarRequest:FireServer()
-- Server -> everyone: character attribute RoarStartedAt = workspace:GetServerTimeNow() (replicates), which
--   every client's IdleAnimation (pose) and RoarFX (sound + rings) read, so all players see the same roar.
-- Checks: character alive, RoarEnabled ~= false, cooldown RoarCooldown (character attribute, default 3 s).
-- Diagnostics (character attributes): RoarCount (accepted roars), RoarLastResult ("ok" / "cooldown" / "disabled").
-- Gameplay effects (Roar of Terror debuff + slow on enemies, SRD §4) are NOT applied yet.
-- v1.1: roar debuff. After an accepted roar the server sweeps every SWEEP_STEP s, timed like the RoarFX 1.1
--   rings (they stream out from BURST to BURST_END of RoarDuration and take RING_TIME s to fly RoarRadius
--   studs). Another dino (a model with a Species attribute: other players' characters and display dinos;
--   not the roarer, not the BiteDummy) is hit once per roar when:
--     d <= RoarRadius (d = mouth front -> nearest point of its Hitboxes, or its HumanoidRootPart), and
--     the flat angle between the roarer's forward and that point <= RoarConeAngle / 2 (default 90 -> 45), and
--     a ring is passing it: burst + d / RoarRadius * RING_TIME <= now <= burstEnd + d / RoarRadius * RING_TIME.
--   Mouth front and forward come from the rest-pose head + HumanoidRootPart (the server does not animate).
--   On a hit the target gets (replicated): DebuffDamageTakenMul = RoarDebuffDamageTaken (default 1.25, read by
--   BiteServer 1.3), DebuffSpeedMul = RoarDebuffSpeed (default 1.1, read by SprintTest 1.3 on player dinos),
--   DebuffBy (roarer name), DebuffSource = "roar", DebuffCount (+1), DebuffState = "roared", and last
--   DebuffUntil = now + RoarDebuffDuration (default 8). A new hit refreshes the time (no stacking).
--   When DebuffUntil passes unchanged, DebuffState = "none".
--   Roarer settings (character attributes): RoarDebuffEnabled (default true), RoarConeAngle, RoarRadius,
--   RoarDebuffDuration, RoarDebuffDamageTaken, RoarDebuffSpeed.
--   Roarer diagnostics: RoarEffectState ("sweeping" / "done" / "disabled"), RoarHits (targets hit by the last
--   roar), RoarHitNames (comma list).
-- v1.2 (Arena squads, MDA-159, plan docs/plans/SQUADS_v1.0.md Task S2, ADR-006; Kepu 2026-10-31 "turning friendly fire off",
--   picked "Everything harmful"): the roar sweep skips a squadmate (no debuff). Nothing else in the sweep changes (its
--   missing mode / menu gate stays as it is, plan do-not-touch). Diagnostic: script RoarServerVersion. Squadmates = SquadRules 1.0 sameChar (same Arena squad; a test target's
--   SquadTestId counts). Switch: script attribute RoarServerSquadEnabled (default true, read at each check; false = 1.1).
--   Diagnostic: script RoarServerSquadSkips (count of squadmate skips / refusals).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local remote = ReplicatedStorage:FindFirstChild("DinoRoarRequest")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "DinoRoarRequest"
	remote.Parent = ReplicatedStorage
end

local DEFAULT_COOLDOWN = 3

-- v1.1 roar debuff
local BURST, BURST_END = 0.2, 0.8 -- match RoarPose.BURST / RoarFX 1.1 (rings stream out between these)
local RING_TIME = 0.75            -- matches RoarFX 1.1: seconds for a ring to fly RoarRadius studs
local SWEEP_STEP = 0.05
local DEFAULTS = {RoarDuration = 1.4, RoarRadius = 30, RoarConeAngle = 90, RoarDebuffEnabled = true,
	RoarDebuffDuration = 8, RoarDebuffDamageTaken = 1.25, RoarDebuffSpeed = 1.1}

local function get(char, k)
	local v = char:GetAttribute(k)
	if v == nil then v = DEFAULTS[k] end
	return v
end

-- mouth front + flat forward from the rest-pose head (same as BiteServer)
local function mouthFrame(char)
	local head = char:FindFirstChild("Head")
	local mouth = head and head:FindFirstChild("Head_mouth")
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not (mouth and hrp) then return nil end
	local fwd = Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z).Unit
	return mouth.CFrame * Vector3.new(mouth.Size.X / 2, 0, 0), fwd
end

local function closestPoint(part, p)
	local lp = part.CFrame:PointToObjectSpace(p)
	local h = part.Size / 2
	return part.CFrame * Vector3.new(math.clamp(lp.X, -h.X, h.X), math.clamp(lp.Y, -h.Y, h.Y), math.clamp(lp.Z, -h.Z, h.Z))
end

-- the dino model (Species attribute) a part belongs to, or nil
-- v1.2: squadmates are never targets (SquadRules 1.0, loaded on first use)
local squadMod
local function squadmate(a, b)
	if script:GetAttribute("RoarServerSquadEnabled") == false then return false end
	if not squadMod then
		local arc = game:GetService("ServerStorage"):FindFirstChild("DinoArcade")
		local m = arc and arc:FindFirstChild("SquadRules")
		if not m then return false end
		local ok, mod = pcall(require, m)
		if not ok then return false end
		squadMod = mod
	end
	if squadMod.sameChar(a, b) then
		script:SetAttribute("RoarServerSquadSkips", (script:GetAttribute("RoarServerSquadSkips") or 0) + 1)
		return true
	end
	return false
end
script:SetAttribute("RoarServerVersion", "1.2") -- v1.2
script:SetAttribute("RoarServerVersion", "1.3") -- v1.3 pre-match lock
-- v1.3 (pre-match lock, MDA-528, plan docs/plans/PREMATCH_LOCK_PAN_v1.0.md rule 2; Kepu 2026-11-13 18:23 "all mecha abilities
--   and actions should be unplayable ... during the count down", pick "A · Locked everywhere"): every request from a player whose
--   character PrematchLockUntil (PracticeServer 1.12) is after the server time is dropped before the handler runs (handler
--   bodies unchanged; bots never locked: BotUse / BotMechaUse call the handlers directly).
local function dinoOf(part)
	local model = part:FindFirstAncestorWhichIsA("Model")
	while model do
		if model:GetAttribute("Species") ~= nil then return model end
		model = model:FindFirstAncestorWhichIsA("Model")
	end
	return nil
end

-- nearest point of a dino to p: its Hitboxes, else its HumanoidRootPart
local function nearestPoint(model, p)
	local best, bestPt = math.huge, nil
	local folder = model:FindFirstChild("Hitboxes")
	if folder then
		for _, part in ipairs(folder:GetChildren()) do
			if part:IsA("BasePart") then
				local cp = closestPoint(part, p)
				local d = (cp - p).Magnitude
				if d < best then best, bestPt = d, cp end
			end
		end
	end
	if not bestPt then
		local hrp = model:FindFirstChild("HumanoidRootPart")
		if hrp then bestPt = closestPoint(hrp, p); best = (bestPt - p).Magnitude end
	end
	return best, bestPt
end

local function applyDebuff(model, roarer)
	local duration = get(roarer, "RoarDebuffDuration")
	local untilT = workspace:GetServerTimeNow() + duration
	model:SetAttribute("DebuffDamageTakenMul", get(roarer, "RoarDebuffDamageTaken"))
	model:SetAttribute("DebuffSpeedMul", get(roarer, "RoarDebuffSpeed"))
	model:SetAttribute("DebuffBy", roarer.Name)
	model:SetAttribute("DebuffSource", "roar")
	model:SetAttribute("DebuffCount", (model:GetAttribute("DebuffCount") or 0) + 1)
	model:SetAttribute("DebuffState", "roared")
	model:SetAttribute("DebuffUntil", untilT) -- last: clients react to this one
	task.delay(duration, function()
		if model.Parent and model:GetAttribute("DebuffUntil") == untilT then model:SetAttribute("DebuffState", "none") end
	end)
end

local function sweep(char, started)
	if get(char, "RoarDebuffEnabled") == false then
		char:SetAttribute("RoarEffectState", "disabled")
		return
	end
	char:SetAttribute("RoarEffectState", "sweeping")
	local duration, range = get(char, "RoarDuration"), get(char, "RoarRadius")
	local half = math.rad(get(char, "RoarConeAngle") / 2)
	local tBurst, tEnd = started + duration * BURST, started + duration * BURST_END
	local stopAt = tEnd + RING_TIME
	local hit, names = {}, {}
	local wait0 = tBurst - workspace:GetServerTimeNow()
	if wait0 > 0 then task.wait(wait0) end
	while workspace:GetServerTimeNow() <= stopAt do
		if char:GetAttribute("RoarStartedAt") ~= started or not char.Parent then break end
		local now = workspace:GetServerTimeNow()
		local origin, fwd = mouthFrame(char)
		if origin then
			local params = OverlapParams.new()
			params.FilterDescendantsInstances = {char}
			params.FilterType = Enum.RaycastFilterType.Exclude
			local seen = {}
			for _, part in ipairs(workspace:GetPartBoundsInRadius(origin, range, params)) do
				local model = dinoOf(part)
				if model and model ~= char and not seen[model] and not hit[model] and not squadmate(char, model) then -- v1.2: squad
					seen[model] = true
					local d, pt = nearestPoint(model, origin)
					if pt and d <= range then
						local flat = Vector3.new(pt.X - origin.X, 0, pt.Z - origin.Z)
						local angle = flat.Magnitude > 0.5 and math.acos(math.clamp(flat.Unit:Dot(fwd), -1, 1)) or 0
						local arrive = tBurst + d / range * RING_TIME
						local leave = tEnd + d / range * RING_TIME
						if angle <= half and now >= arrive and now <= leave then
							hit[model] = true
							table.insert(names, model.Name)
							applyDebuff(model, char)
						end
					end
				end
			end
		end
		task.wait(SWEEP_STEP)
	end
	char:SetAttribute("RoarHits", #names)
	char:SetAttribute("RoarHitNames", table.concat(names, ","))
	char:SetAttribute("RoarEffectState", "done")
end

local function __prematchLocked(player) -- v1.3: PracticeServer 1.12 pre-match lock (see VERSION 1.3)
	local c = player and player.Character
	return c ~= nil and (tonumber(c:GetAttribute("PrematchLockUntil")) or 0) > workspace:GetServerTimeNow()
end
remote.OnServerEvent:Connect(function(player)
	if __prematchLocked(player) then return end -- v1.3: dropped while pre-match locked
	local char = player.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return end
	if char:GetAttribute("RoarEnabled") == false then
		char:SetAttribute("RoarLastResult", "disabled")
		return
	end
	local now = workspace:GetServerTimeNow()
	local last = char:GetAttribute("RoarStartedAt")
	local cooldown = char:GetAttribute("RoarCooldown") or DEFAULT_COOLDOWN
	if last and now - last < cooldown then
		char:SetAttribute("RoarLastResult", "cooldown")
		return
	end
	char:SetAttribute("RoarStartedAt", now)
	char:SetAttribute("RoarCount", (char:GetAttribute("RoarCount") or 0) + 1)
	char:SetAttribute("RoarLastResult", "ok")
	task.spawn(sweep, char, now) -- v1.1: roar debuff on dinos the rings reach
end)
