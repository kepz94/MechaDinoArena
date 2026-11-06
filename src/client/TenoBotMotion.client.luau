-- TenoBotMotion v1.2 (Mecha Dino Arena) — draws bots that a teno grabs, throws or shoves, on every client (LocalScript in
-- StarterPlayerScripts). MDA-217, plan docs/plans/TENO_TAIL_GRAB_v1.0.md Task 3, mockup docs/mockups/teno_tail_grab_v0.1.html
-- (Kepu 2026-11-03: "It lags the dinos when I toss them", picked A "Over the Top" + L1 "Shove Clear").
-- Why: TenoMovesServer 1.6 moved the anchored bot from the server every Heartbeat; clients only got about 30 updates a second
--   (the bot stepped) and the carry followed the server's tail, which the client-side animation never moves. TenoMovesServer
--   1.7 leaves the bot anchored where it was grabbed until the landing; this script moves each client's own copy of the
--   bot's root every frame (a local CFrame on an anchored part stays until the server changes it).
-- Grab (a teno character's TenoGrabStartedAt with TenoGrabSide, younger than 4 s, its TenoGrabTargetRef a model under
--   Workspace.DinoIsland.Bots; times are server time):
--   * TenoGrabCatchAt - PULL_TIME (0.12) -> TenoGrabCatchAt: the root slides from where it stands to the hold point.
--   * catch -> TenoGrabThrowAtPlan: hold point = the teno's local Tail5_main x (CLAMP_X (-2.6) x scale, 0, 0) (between the
--     Clamp Tail's jaws) + (0, hang, 0), hang = the root's height under the top of the bot's bounding box at the catch (the
--     clamp holds it by the back); a small swing (pitch 10 deg x sin 8t, roll 12 deg x sin 6t) on its own rotation.
--   * throw -> throw + TenoGrabFlight (0.85): from the release point to TenoGrabLand + (0, TenoGrabLandLift, 0) on an arc
--     (FLING_PEAK 16), turning to face away from the teno over the first 20 % and one forward flip. Until a TenoGrabLand
--     newer than the grab arrives the landing is predicted (the teno's local facing: front -> behind, back -> ahead,
--     x TenoGrabFling); a stamp that arrives later is blended in over BLEND_TIME (0.1 s).
--   * after: nothing (TenoMovesServer puts the root at the same landing point; BotServer lies it down there).
-- Shove (a bot's TenoMoveAt, younger than 2 s): TenoMoveFrom -> TenoMoveTo over TenoMoveTime with an arc TenoMovePeak,
--   smoothstep; rotation kept.
-- Only anchored roots are written. Switch: script attribute TenoBotMotionEnabled (default true, read each frame; false =
--   nothing drawn, the bot stays where the server has it). Diagnostics (local player): TenoBotMotionVersion,
--   TenoBotMotionActive (jobs running), TenoBotMotionJobs (jobs started).
-- v1.1 (Kepu 2026-11-03 19:02 "Teno landing polish": after 1.0 the teno still stood ~0.25 s on the dino's back while the
--   server's shove slid it out - the server only hears of the landing after the body has touched it): on this client's own
--   character, during a slam leap (JumpStartedAt with TenoLeapOnJump, or TenoLeapStartedAt, younger than 3 s) while the root is falling, a ray straight
--   down from the root and the Torso_chest part (HipHeight + half the root + 2 + falling speed x LAND_AHEAD (0.25) s long,
--   only this character left out) that hits another dino (a model with a Hitboxes folder) makes that dino's parts
--   non-colliding on this client for LAND_THROUGH_TIME (1.0) s (then put back as they were). The body then comes down
--   through it to the ground while TenoMovesServer 1.7's slam shoves it out sideways; nothing changes for the server or
--   other players. Switch: script attribute TenoBotMotionLandThroughEnabled (default true, read each frame). Diagnostic
--   (local player): TenoLandThroughs (dinos let through).
-- v1.2 (Kepu 2026-11-05 17:40 "some of the tail grab animations ain't looking good"; the v460 Pincer Tail grips ~2 units
--   further out than the Clamp Tail): the hold point's x (Tail5_main frame, scale 1) = the teno's TenoGrabClampX
--   (TenoPartsServer 1.4) when it is set, else CLAMP_X (-2.6). Switch: script attribute TenoBotMotionClampAttrEnabled
--   (default true, read each frame).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local VERSION = "1.0"
VERSION = "1.1" -- v1.1 land through the dino under a leap
VERSION = "1.2" -- v1.2 the look's clamp point
if script:GetAttribute("TenoBotMotionClampAttrEnabled") == nil then script:SetAttribute("TenoBotMotionClampAttrEnabled", true) end -- v1.2
local LAND_AHEAD, LAND_THROUGH_TIME = 0.25, 1.0 -- v1.1
if script:GetAttribute("TenoBotMotionLandThroughEnabled") == nil then script:SetAttribute("TenoBotMotionLandThroughEnabled", true) end -- v1.1
local PULL_TIME, CLAMP_X, FLING_PEAK, BLEND_TIME = 0.12, -2.6, 16, 0.1
local lp = Players.LocalPlayer
if script:GetAttribute("TenoBotMotionEnabled") == nil then script:SetAttribute("TenoBotMotionEnabled", true) end
lp:SetAttribute("TenoBotMotionVersion", VERSION)

local function now() return workspace:GetServerTimeNow() end
local function num(m, k) return tonumber(m:GetAttribute(k)) end
local function flat(v) return Vector3.new(v.X, 0, v.Z) end
local function smooth(u) u = math.clamp(u, 0, 1) return u * u * (3 - 2 * u) end
local function botsFolder()
	local isl = workspace:FindFirstChild("DinoIsland")
	return isl and isl:FindFirstChild("Bots")
end

local jobs = {} -- key (bot model) -> job
local started = 0

-- grab jobs ---------------------------------------------------------------------------------------------------------------------
local function onGrab(char)
	local t0, side = num(char, "TenoGrabStartedAt"), char:GetAttribute("TenoGrabSide")
	if not t0 or (side ~= "front" and side ~= "back") or now() - t0 > 4 then return end
	local ref = char:FindFirstChild("TenoGrabTargetRef")
	local bot = ref and ref:IsA("ObjectValue") and ref.Value
	local bots = botsFolder()
	if not (bot and bots and bot:IsDescendantOf(bots)) then return end
	local hrp = bot:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	started += 1
	lp:SetAttribute("TenoBotMotionJobs", started)
	jobs[bot] = {kind = "grab", char = char, bot = bot, hrp = hrp, side = side, t0 = t0,
		catchAt = num(char, "TenoGrabCatchAt") or t0 + 0.45, throwAt = num(char, "TenoGrabThrowAtPlan") or t0 + 1.1,
		flight = num(char, "TenoGrabFlight") or 0.85, landStamp = nil, landStampAt = nil}
end
local function onLand(char)
	for _, j in pairs(jobs) do
		if j.kind == "grab" and j.char == char then
			local land = char:GetAttribute("TenoGrabLand")
			if typeof(land) == "Vector3" then
				j.landStamp = land + Vector3.new(0, num(char, "TenoGrabLandLift") or 0, 0)
				j.landStampAt = os.clock()
			end
		end
	end
end
local function watchChar(char)
	char:GetAttributeChangedSignal("TenoGrabStartedAt"):Connect(function() onGrab(char) end)
	char:GetAttributeChangedSignal("TenoGrabLand"):Connect(function() onLand(char) end)
end
local function watchPlayer(p)
	p.CharacterAdded:Connect(watchChar)
	if p.Character then watchChar(p.Character) end
end
Players.PlayerAdded:Connect(watchPlayer)
for _, p in ipairs(Players:GetPlayers()) do watchPlayer(p) end

local function holdPoint(j)
	local tail = j.char:FindFirstChild("Tail5_main", true)
	if not (tail and tail:IsA("BasePart")) then return nil end
	local sc = j.char:GetScale()
	local cx = CLAMP_X
	if script:GetAttribute("TenoBotMotionClampAttrEnabled") ~= false then cx = tonumber(j.char:GetAttribute("TenoGrabClampX")) or CLAMP_X end -- v1.2
	return (tail.CFrame * CFrame.new(cx * sc, 0, 0)).Position + Vector3.new(0, j.hang or 0, 0)
end
local function predictLand(j)
	local root = j.char:FindFirstChild("HumanoidRootPart")
	if not root then return j.hrp.Position end
	local fwd = flat(root.CFrame.LookVector)
	fwd = fwd.Magnitude > 1e-3 and fwd.Unit or -Vector3.zAxis
	local dir = j.side == "front" and -fwd or fwd
	local fling = num(j.char, "TenoGrabFling") or 30
	return Vector3.new(root.Position.X, j.hrp.Position.Y, root.Position.Z) + dir * fling
end

local function stepGrab(j, t)
	local hrp = j.hrp
	if t < j.catchAt - PULL_TIME then
		j.rest = hrp.CFrame -- where the server has it (anchored at the press)
		return true
	end
	if not j.rest then j.rest = hrp.CFrame end
	if not j.hang then
		local cf, size = j.bot:GetBoundingBox()
		j.hang = math.min(-0.5, j.rest.Position.Y - (cf.Position.Y + size.Y / 2))
	end
	local rot = j.rest - j.rest.Position
	if t < j.throwAt then
		local p = holdPoint(j)
		if not p then return false end
		local swing = CFrame.Angles(math.rad(10) * math.sin(t * 8), 0, math.rad(12) * math.sin(t * 6))
		local pos = p
		if t < j.catchAt then pos = j.rest.Position:Lerp(p, smooth((t - (j.catchAt - PULL_TIME)) / PULL_TIME)) end
		local cf = CFrame.new(pos) * rot * swing
		j.release = cf
		hrp.CFrame = cf
		return true
	end
	local u = (t - j.throwAt) / j.flight
	if u >= 1 then return false end
	local from = (j.release or hrp.CFrame).Position
	local to = j.landStamp or predictLand(j)
	if j.landStamp and j.predicted and j.landStampAt then -- blend from the prediction to the stamp
		local k = smooth((os.clock() - j.landStampAt) / BLEND_TIME)
		to = j.predicted:Lerp(j.landStamp, k)
	elseif not j.landStamp then
		j.predicted = to
	end
	local dir = flat(to - from)
	dir = dir.Magnitude > 1e-3 and dir.Unit or -Vector3.zAxis
	local face = CFrame.lookAt(Vector3.zero, dir)
	local r0 = (j.release or hrp.CFrame) - (j.release or hrp.CFrame).Position
	local turn = r0:Lerp(face, smooth(u / 0.2))
	local pos = from:Lerp(to, u) + Vector3.new(0, 4 * FLING_PEAK * u * (1 - u), 0)
	hrp.CFrame = CFrame.new(pos) * turn * CFrame.Angles(-2 * math.pi * smooth(u), 0, 0)
	return true
end

-- shove jobs ---------------------------------------------------------------------------------------------------------------------
local function onMove(bot)
	local at, from, to = num(bot, "TenoMoveAt"), bot:GetAttribute("TenoMoveFrom"), bot:GetAttribute("TenoMoveTo")
	if not at or typeof(from) ~= "Vector3" or typeof(to) ~= "Vector3" or now() - at > 2 then return end
	local hrp = bot:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	started += 1
	lp:SetAttribute("TenoBotMotionJobs", started)
	jobs[bot] = {kind = "move", bot = bot, hrp = hrp, at = at, from = from, to = to,
		time = math.max(0.05, num(bot, "TenoMoveTime") or 0.28), peak = num(bot, "TenoMovePeak") or 0, rot = hrp.CFrame - hrp.Position}
end
local function stepMove(j, t)
	local u = (t - j.at) / j.time
	if u >= 1 then return false end
	if u < 0 then return true end
	local e = smooth(u)
	j.hrp.CFrame = CFrame.new(j.from:Lerp(j.to, e) + Vector3.new(0, 4 * j.peak * u * (1 - u), 0)) * j.rot
	return true
end
local function watchBot(bot)
	if not bot:IsA("Model") then return end
	bot:GetAttributeChangedSignal("TenoMoveAt"):Connect(function() onMove(bot) end)
end
task.spawn(function()
	local bots
	repeat bots = botsFolder() if not bots then task.wait(1) end until bots
	bots.ChildAdded:Connect(watchBot)
	for _, b in ipairs(bots:GetChildren()) do watchBot(b) end
end)

-- every frame --------------------------------------------------------------------------------------------------------------------
RunService.RenderStepped:Connect(function()
	local n = 0
	if script:GetAttribute("TenoBotMotionEnabled") == false then
		table.clear(jobs)
	else
		local t = now()
		for bot, j in pairs(jobs) do
			local keep = bot.Parent ~= nil and j.hrp.Parent ~= nil
			if keep and j.hrp.Anchored then
				if j.kind == "grab" then keep = j.char.Parent ~= nil and stepGrab(j, t) else keep = stepMove(j, t) end
			elseif keep then
				keep = (j.kind == "grab" and t < j.catchAt) or (j.kind == "move" and t < j.at + j.time) -- not anchored yet
			end
			if keep then n += 1 else jobs[bot] = nil end
		end
	end
	if lp:GetAttribute("TenoBotMotionActive") ~= n then lp:SetAttribute("TenoBotMotionActive", n) end
end)

-- v1.1: the own leap comes down through the dino under it (see the header) ----------------------------------------------------
local landRay = RaycastParams.new()
landRay.FilterType = Enum.RaycastFilterType.Exclude
local through = {} -- dino model -> {until = os.clock() time, parts = {part = old CanCollide}}
local throughs = 0
local function dinoOf(part)
	local m = part:FindFirstAncestorOfClass("Model")
	while m and not m:FindFirstChild("Hitboxes") do m = m.Parent and m.Parent:FindFirstAncestorOfClass("Model") end
	return m
end
local function letThrough(m)
	local rec = through[m]
	if rec then rec.untilAt = os.clock() + LAND_THROUGH_TIME return end
	rec = {untilAt = os.clock() + LAND_THROUGH_TIME, parts = {}}
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") and d.CanCollide then
			rec.parts[d] = true
			d.CanCollide = false
		end
	end
	through[m] = rec
	throughs += 1
	lp:SetAttribute("TenoLandThroughs", throughs)
end
RunService.Heartbeat:Connect(function()
	local nowC = os.clock()
	for m, rec in pairs(through) do
		if nowC >= rec.untilAt or not m.Parent then
			for part in pairs(rec.parts) do if part.Parent then part.CanCollide = true end end
			through[m] = nil
		end
	end
	if script:GetAttribute("TenoBotMotionLandThroughEnabled") == false then return end
	local char = lp.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not (hrp and hum and hum.Health > 0) then return end
	local t = now()
	local js = char:GetAttribute("TenoLeapOnJump") == true and num(char, "JumpStartedAt") or 0 -- only leaps that slam (TenoMovesServer)
	local ls = num(char, "TenoLeapStartedAt") or 0
	if t - math.max(js, ls) > 3 then return end
	local vy = hrp.AssemblyLinearVelocity.Y
	if vy > 0 then return end
	landRay.FilterDescendantsInstances = {char}
	local len = hum.HipHeight + hrp.Size.Y / 2 + 2 + (-vy) * LAND_AHEAD
	local origins = {hrp.Position}
	local chest = char:FindFirstChild("Torso_chest", true)
	if chest and chest:IsA("BasePart") then table.insert(origins, chest.Position) end
	for _, o in ipairs(origins) do
		local hit = workspace:Raycast(o, Vector3.new(0, -len, 0), landRay)
		local m = hit and dinoOf(hit.Instance)
		if m and m ~= char then letThrough(m) end
	end
end)
