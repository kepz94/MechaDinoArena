-- TrooStatsServer v1.0 (Mecha Dino Arena) — server side of the Troodon's own stat rows that no other script owns (SkillTree 1.88
-- TROO_STATS / SkillEffects 1.60; plan docs/plans/TROODON_STATS_v1.0.md, MDA-388; Kepu 2026-11-10 12:00 picks, 12:03 "Build").
-- * LastDealtAt: whenever a model is hit (its LastHitAt / TrooHitAt / KilledAt changes), the attacker named in LastHitBy /
--   TrooHitBy / KilledBy (a player's character or a bot of that name) gets LastDealtAt = now. Night Watcher star reads it
--   (TrooAttackServer 1.7: "hasn't hit anyone in 5 s"). Best effort: only hits whose script writes those stamps count.
-- * Night Watcher: every TrooStats_watchTick (0.25) s, for each troodon character with TrooStatWatchRadius > 0 (40 / 54), every
--   enemy (another player's character that is not a squadmate, or a bot; alive) within that many studs (flat) gets
--   TrooSeenUntil = now + TrooStats_watchHold (0.45), TrooSeenBy (the troodon's name), TrooSeenSquad (the troodon's SquadId
--   with TrooStatWatchSquad, III, else ""). TrooStatsFX 1.0 outlines it for the troodon (and that squad).
-- * Quick Feet star: RemoteEvent DinoTrooTrailRequest(pos) from TrooStatsFX 1.0 when the troodon's glide ends. Accepted for a
--   live troodon with TrooStatFeetTrailOn, at most every TrooStats_trailGap (1.5) s, pos within TrooStats_trailReach (12) x
--   scale studs of its root: a trail pad at the ground under pos, radius TrooStats_trailRadius (10) studs, for
--   TrooStatFeetTrailTime (3) s. Every 0.2 s each squadmate standing on a live pad gets TrooTrailUntil = now +
--   TrooStatFeetTrailTime and TrooTrailMul = TrooStatFeetTrailMul (1.1) (SprintTest 1.25). Owner stamps TrooTrailPadCenter,
--   TrooTrailPadRadius, TrooTrailPadUntil, then TrooTrailPadAt (last; TrooStatsFX). Result: owner TrooTrailResult ("ok", "off",
--   "dead", "gap", "far", "badArg").
-- Switches (script attributes, default true, read at each use): TrooStatsServerEnabled, TrooStats_dealtEnabled,
--   TrooStats_watchEnabled, TrooStats_trailEnabled. Diagnostics (script): TrooStatsSeenStamps, TrooStatsTrails, TrooStatsBoosts.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")

local VERSION = "1.0"
script:SetAttribute("TrooStatsServerVersion", VERSION)
for _, k in ipairs({"TrooStatsServerEnabled", "TrooStats_dealtEnabled", "TrooStats_watchEnabled", "TrooStats_trailEnabled"}) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, true) end
end
for k, v in pairs({watchTick = 0.25, watchHold = 0.45, trailGap = 1.5, trailReach = 12, trailRadius = 10}) do
	if script:GetAttribute("TrooStats_" .. k) == nil then script:SetAttribute("TrooStats_" .. k, v) end
end
for _, k in ipairs({"TrooStatsSeenStamps", "TrooStatsTrails", "TrooStatsBoosts"}) do script:SetAttribute(k, 0) end
local function on(k) return script:GetAttribute("TrooStatsServerEnabled") ~= false and (not k or script:GetAttribute("TrooStats_" .. k .. "Enabled") ~= false) end
local function cfg(k, d) local v = script:GetAttribute("TrooStats_" .. k); return typeof(v) == "number" and v or d end
local function now() return workspace:GetServerTimeNow() end
local function num(m, k, d) return tonumber(m:GetAttribute(k)) or d end
local function count(k) script:SetAttribute(k, (script:GetAttribute(k) or 0) + 1) end
local function rootOf(m) return m:FindFirstChild("HumanoidRootPart") end
local function flat(v) return Vector3.new(v.X, 0, v.Z) end
local function scaleOf(m) local ok, v = pcall(function() return m:GetScale() end); return ok and v or 1 end
local function bots()
	local isl = workspace:FindFirstChild("DinoIsland")
	local f = isl and isl:FindFirstChild("Bots")
	return f and f:GetChildren() or {}
end
local squadMod
local function squad()
	if squadMod == nil then
		squadMod = false
		pcall(function() squadMod = require(ServerStorage:WaitForChild("DinoArcade", 5):WaitForChild("SquadRules", 5)) end)
	end
	return squadMod or nil
end
local function sameSquad(a, b)
	local S = squad()
	return S ~= nil and a ~= b and S.sameChar(a, b) == true
end
local function alive(m)
	local hum = m:FindFirstChildOfClass("Humanoid")
	if Players:GetPlayerFromCharacter(m) then return hum ~= nil and hum.Health > 0 end
	if m:GetAttribute("DummyState") == "ko" then return false end
	local hp = m:GetAttribute("DummyHealth")
	return typeof(hp) ~= "number" or hp > 0
end
local function models()
	local list = {}
	for _, pl in ipairs(Players:GetPlayers()) do if pl.Character then table.insert(list, pl.Character) end end
	for _, b in ipairs(bots()) do if b:IsA("Model") then table.insert(list, b) end end
	return list
end
local function byName(name)
	if type(name) ~= "string" or name == "" then return nil end
	local pl = Players:FindFirstChild(name)
	if pl and pl:IsA("Player") then return pl.Character end
	local isl = workspace:FindFirstChild("DinoIsland")
	local f = isl and isl:FindFirstChild("Bots")
	return f and f:FindFirstChild(name) or nil
end

-- LastDealtAt ----------------------------------------------------------------------------------------------------------------
local hooked = setmetatable({}, {__mode = "k"})
local function hook(m)
	if hooked[m] or not m:IsA("Model") then return end
	hooked[m] = true
	for _, pair in ipairs({{"LastHitAt", "LastHitBy"}, {"TrooHitAt", "TrooHitBy"}, {"KilledAt", "KilledBy"}}) do
		m:GetAttributeChangedSignal(pair[1]):Connect(function()
			if not on("dealt") then return end
			local a = byName(m:GetAttribute(pair[2]))
			if a and a ~= m then a:SetAttribute("LastDealtAt", now()) end
		end)
	end
end
local function onPlayer(pl)
	pl.CharacterAdded:Connect(hook)
	if pl.Character then hook(pl.Character) end
end
Players.PlayerAdded:Connect(onPlayer)
for _, pl in ipairs(Players:GetPlayers()) do onPlayer(pl) end
task.spawn(function()
	local isl = workspace:WaitForChild("DinoIsland", 30)
	local f = isl and isl:WaitForChild("Bots", 30)
	if not f then return end
	f.ChildAdded:Connect(hook)
	for _, b in ipairs(f:GetChildren()) do hook(b) end
end)

-- Night Watcher + trail pads -------------------------------------------------------------------------------------------------
local pads = {} -- {owner, center, radius, untilT, mul, hold}
local accW, accT = 0, 0
RunService.Heartbeat:Connect(function(dt)
	if not on() then return end
	accW += dt
	accT += dt
	local t = now()
	if accW >= cfg("watchTick", 0.25) and on("watch") then
		accW = 0
		local hold = cfg("watchHold", 0.45)
		for _, pl in ipairs(Players:GetPlayers()) do
			local c = pl.Character
			local R = c and num(c, "TrooStatWatchRadius", 0) or 0
			local root = c and rootOf(c)
			if R > 0 and root and c:GetAttribute("Species") == "Troodon" and alive(c) then
				local sid = c:GetAttribute("TrooStatWatchSquad") == true and tostring(pl:GetAttribute("SquadId") or "") or ""
				for _, m in ipairs(models()) do
					local r = m ~= c and rootOf(m)
					if r and alive(m) and not sameSquad(c, m) and flat(r.Position - root.Position).Magnitude <= R then
						m:SetAttribute("TrooSeenUntil", t + hold)
						m:SetAttribute("TrooSeenBy", c.Name)
						m:SetAttribute("TrooSeenSquad", sid)
						count("TrooStatsSeenStamps")
					end
				end
			end
		end
	end
	if accT >= 0.2 and #pads > 0 then
		accT = 0
		for i = #pads, 1, -1 do
			local p = pads[i]
			if t >= p.untilT or not p.owner.Parent then
				table.remove(pads, i)
			elseif on("trail") then
				for _, m in ipairs(models()) do
					local r = rootOf(m)
					if r and m ~= p.owner and alive(m) and sameSquad(p.owner, m) and flat(r.Position - p.center).Magnitude <= p.radius
						and math.abs(r.Position.Y - p.center.Y) <= 12 * scaleOf(m) then
						m:SetAttribute("TrooTrailMul", p.mul)
						m:SetAttribute("TrooTrailUntil", t + p.hold)
						count("TrooStatsBoosts")
					end
				end
			end
		end
	end
end)

local remote = ReplicatedStorage:FindFirstChild("DinoTrooTrailRequest")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "DinoTrooTrailRequest"
	remote.Parent = ReplicatedStorage
end
local lastTrail = setmetatable({}, {__mode = "k"})
local function groundBelow(pos, char)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {char}
	local hit = workspace:Raycast(pos + Vector3.new(0, 5, 0), Vector3.new(0, -60, 0), params)
	return hit and hit.Position or pos
end
remote.OnServerEvent:Connect(function(player, pos)
	local c = player.Character
	if not c then return end
	local function result(r) c:SetAttribute("TrooTrailResult", r) end
	if typeof(pos) ~= "Vector3" or pos ~= pos then result("badArg") return end
	if not (on() and on("trail")) or c:GetAttribute("TrooStatFeetTrailOn") ~= true or c:GetAttribute("Species") ~= "Troodon" then result("off") return end
	local root = rootOf(c)
	if not root or not alive(c) then result("dead") return end
	local t = now()
	if t - (lastTrail[c] or -math.huge) < cfg("trailGap", 1.5) then result("gap") return end
	if (pos - root.Position).Magnitude > cfg("trailReach", 12) * scaleOf(c) then result("far") return end
	lastTrail[c] = t
	local life = math.max(0.5, num(c, "TrooStatFeetTrailTime", 3))
	local center = groundBelow(pos, c)
	local p = {owner = c, center = center, radius = cfg("trailRadius", 10), untilT = t + life,
		mul = math.clamp(num(c, "TrooStatFeetTrailMul", 1.1), 1, 2), hold = life}
	table.insert(pads, p)
	c:SetAttribute("TrooTrailPadCenter", center)
	c:SetAttribute("TrooTrailPadRadius", p.radius)
	c:SetAttribute("TrooTrailPadUntil", p.untilT)
	c:SetAttribute("TrooTrailPadAt", t) -- last: TrooStatsFX
	count("TrooStatsTrails")
	result("ok")
end)
