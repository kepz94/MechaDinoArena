-- TheriSpinServer v1.0 (Mecha Dino Arena) — the Therizinosaurus' Spin Dive (Corkscrew): its JUMP leap cuts every dino it
-- passes. MDA-208, plan docs/plans/THERIZINO_SPIN_STATS_v1.0.md Task 2, mockup docs/mockups/therizino_spin_dive_v0.1.html
-- (Kepu 2026-11-02 "show more slicing ... a different jump" -> "Spin Dive"; 2026-11-03 "Corkscrew", damage "Yes, tune it in
-- Studio").
-- Who: player characters with Species "Therizino" and the model attribute TheriSpinEnabled == true (TherizinoModelData 1.5,
--   which also turns the teno landing slam off: TenoLeapEnabled / TenoLeapOnJump false). The leap itself (charges, launch)
--   stays JumpServer 1.3 / JumpTest's.
-- When: each new JumpStartedAt (JumpServer 1.3 sets it on an accepted leap). The dive is live from JumpStartedAt +
--   JumpWindup (the lift-off) until the landing or LIVE_MAX s after the take-off point (whichever is first). Landing = the root's
--   height above the ground under it was at least LEFT_UP studs above its height at the start, and is back within LAND_UP
--   (the teno's jumpSlam pattern, with lower thresholds: the therizino's leap is only ~2.6 studs high); a leap that never
--   leaves the ground ends at LIVE_MAX.
-- Cuts: every Heartbeat while live, each allowed target (TheriAttackServer 1.0's rules: players / Workspace.DinoIsland.Bots
--   with Hitboxes + Bitable + Species or IsBot, not self / KO / dead, ModeRules.canAffect, never a squadmate) whose nearest
--   hitbox is within TheriSpinRadius x the character's scale of the root (at this frame's position or halfway back to the last
--   one) takes TheriSpinDamage x takenMul (nothing while EnergyShieldUntil > now), at most TheriSpinMaxCuts times per dive and
--   at least TheriSpinCutGap s apart. Damage only (no shove, no stun).
-- Stamps (character): TheriSpinStartedAt (the dive's JumpStartedAt), per cut TheriSpinCuts (cuts this dive), TheriSpinCutTarget,
--   TheriSpinCutPoint (the target's nearest hitbox point), TheriSpinCutAt (last: TheriFX / poses react to it); at the end
--   TheriSpinLandedAt (0 when it timed out without landing). Kills: KilledWith "therispin".
-- Switches (script attributes): TheriSpinServerEnabled (default true, read at start), TheriSpinModeRulesEnabled (default true),
--   TheriSpinSquadEnabled (default true).
-- Diagnostics (script): TheriSpinServerVersion, TheriSpinDives, TheriSpinCutsTotal, TheriSpinTimeouts, TheriSpinSquadSkips,
--   TheriSpinMode.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local VERSION = "1.0"
local DEFAULTS = {TheriSpinDamage = 7, TheriSpinMaxCuts = 3, TheriSpinCutGap = 0.16, TheriSpinRadius = 7, JumpWindup = 0.27}
local LIVE_MAX = 1.6   -- s after the take-off point the dive ends at the latest
local LEFT_UP = 0.8    -- studs above the start height that count as airborne
local LAND_UP = 0.4    -- studs above the start height that count as landed again

script:SetAttribute("TheriSpinServerVersion", VERSION)
for _, k in ipairs({"TheriSpinDives", "TheriSpinCutsTotal", "TheriSpinTimeouts", "TheriSpinSquadSkips"}) do script:SetAttribute(k, 0) end
for _, k in ipairs({"TheriSpinServerEnabled", "TheriSpinModeRulesEnabled", "TheriSpinSquadEnabled"}) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, true) end
end
local enabled = script:GetAttribute("TheriSpinServerEnabled") ~= false

local function now() return workspace:GetServerTimeNow() end
local function count(k, n) script:SetAttribute(k, (script:GetAttribute(k) or 0) + (n or 1)) end
local function num(m, k, d) return tonumber(m:GetAttribute(k)) or d end
local function get(char, k) return num(char, k, DEFAULTS[k]) end
local function rootOf(m) return m:FindFirstChild("HumanoidRootPart") end

-- mode + squad rules (TheriAttackServer 1.0 / TenoAttackServer 1.4) ----------------------------------------------------------
local ModeRules = require(ServerStorage:WaitForChild("DinoArcade"):WaitForChild("ModeRules"))
local MODE = ModeRules.currentMode()
script:SetAttribute("TheriSpinMode", MODE)
local squadMod
local function squadmate(a, b)
	if script:GetAttribute("TheriSpinSquadEnabled") == false then return false end
	if not squadMod then
		local arc = ServerStorage:FindFirstChild("DinoArcade")
		local m = arc and arc:FindFirstChild("SquadRules")
		if not m then return false end
		local ok, mod = pcall(require, m)
		if not ok then return false end
		squadMod = mod
	end
	if squadMod.sameChar(a, b) then
		count("TheriSpinSquadSkips")
		return true
	end
	return false
end
local function mayAffect(source, target)
	if squadmate(source, target) then return false end
	if script:GetAttribute("TheriSpinModeRulesEnabled") == false then return true end
	local tpl = Players:GetPlayerFromCharacter(target)
	local spl = Players:GetPlayerFromCharacter(source)
	local inMenu = tpl ~= nil and tpl:GetAttribute("InMenu") == true
	return ModeRules.canAffect(spl ~= nil, tpl ~= nil, inMenu, MODE)
end

-- targets (TheriAttackServer 1.0 rules) ------------------------------------------------------------------------------------------
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
local function nearest(m, pos) -- nearest distance from a point to the target's hitboxes, and that point
	local best, bestP = math.huge, nil
	local hb = m:FindFirstChild("Hitboxes")
	for _, p in ipairs(hb and hb:GetChildren() or {}) do
		if p:IsA("BasePart") then
			local lp = p.CFrame:PointToObjectSpace(pos)
			local h = p.Size / 2
			local c = Vector3.new(math.clamp(lp.X, -h.X, h.X), math.clamp(lp.Y, -h.Y, h.Y), math.clamp(lp.Z, -h.Z, h.Z))
			local d = (lp - c).Magnitude
			if d < best then best, bestP = d, p.CFrame * c end
		end
	end
	if best == math.huge then
		local r = rootOf(m)
		if r then best, bestP = (r.Position - pos).Magnitude, r.Position end
	end
	return best, bestP
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
local function takeHealth(m, d, char, player, t)
	local hp = m:GetAttribute("DummyHealth")
	if typeof(hp) ~= "number" or d <= 0 then return end
	local after = math.max(0, hp - d)
	m:SetAttribute("DummyHealth", after)
	if hp > 0 and after <= 0 then
		m:SetAttribute("KilledBy", char.Name)
		m:SetAttribute("KilledByUserId", player.UserId)
		m:SetAttribute("KilledWith", "therispin")
		m:SetAttribute("KilledAt", t) -- last: KillRegenServer reacts to this one
	end
end

-- ground height under a point (ignores characters and bots)
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
local function heightAbove(char, pos)
	local ex = {char}
	local isl = workspace:FindFirstChild("DinoIsland")
	local b = isl and isl:FindFirstChild("Bots")
	if b then table.insert(ex, b) end
	for _, pl in ipairs(Players:GetPlayers()) do if pl.Character then table.insert(ex, pl.Character) end end
	rayParams.FilterDescendantsInstances = ex
	local hit = workspace:Raycast(pos, Vector3.new(0, -80, 0), rayParams)
	return hit and (pos.Y - hit.Position.Y) or nil
end

-- the dive ---------------------------------------------------------------------------------------------------------------------
local diving = setmetatable({}, {__mode = "k"}) -- char -> the JumpStartedAt of its live dive
local function dive(player, char, t0)
	diving[char] = t0
	count("TheriSpinDives")
	char:SetAttribute("TheriSpinCuts", 0)
	char:SetAttribute("TheriSpinStartedAt", t0)
	local hum = char:FindFirstChildOfClass("Humanoid")
	local liveFrom = t0 + math.max(0, get(char, "JumpWindup"))
	local cuts, lastCut = {}, {}
	local total = 0
	local h0, left, landed = nil, false, false
	local lastPos
	while char.Parent and diving[char] == t0 do
		local t = now()
		local root = rootOf(char)
		if not (root and hum and hum.Health > 0) then break end
		local pos = root.Position
		if t >= liveFrom then
			local h = heightAbove(char, pos)
			if h then
				h0 = h0 or h
				if not left and h > h0 + LEFT_UP then left = true end
				if left and h <= h0 + LAND_UP then landed = true end
			end
			if t - liveFrom > LIVE_MAX then break end
			local s = char:GetScale()
			local radius = math.max(0, get(char, "TheriSpinRadius")) * s
			local maxCuts = math.max(0, math.floor(get(char, "TheriSpinMaxCuts")))
			local cutGap = math.max(0, get(char, "TheriSpinCutGap"))
			local dmg = math.max(0, get(char, "TheriSpinDamage"))
			local mid = lastPos and (lastPos + pos) / 2 or pos
			for _, m in ipairs(candidates(char)) do
				local n = cuts[m] or 0
				if n < maxCuts and t - (lastCut[m] or -math.huge) >= cutGap then
					local d1, p1 = nearest(m, pos)
					local d2, p2 = nearest(m, mid)
					local d, p = d1, p1
					if d2 < d1 then d, p = d2, p2 end
					if d <= radius then
						cuts[m], lastCut[m] = n + 1, t
						total += 1
						count("TheriSpinCutsTotal")
						if not shielded(m, t) then takeHealth(m, dmg * takenMul(m, t), char, player, t) end
						char:SetAttribute("TheriSpinCuts", total)
						char:SetAttribute("TheriSpinCutTarget", m.Name)
						char:SetAttribute("TheriSpinCutPoint", p)
						char:SetAttribute("TheriSpinCutAt", t) -- last: FX
					end
				end
			end
			if landed then break end
		end
		lastPos = pos
		RunService.Heartbeat:Wait()
	end
	if diving[char] == t0 then
		diving[char] = nil
		if char.Parent then
			if not landed then count("TheriSpinTimeouts") end
			char:SetAttribute("TheriSpinLandedAt", landed and now() or 0)
		end
	end
end

local function watch(player, char)
	char:GetAttributeChangedSignal("JumpStartedAt"):Connect(function()
		if not enabled or char:GetAttribute("Species") ~= "Therizino" or char:GetAttribute("TheriSpinEnabled") ~= true then return end
		local t0 = num(char, "JumpStartedAt", nil)
		if not t0 or diving[char] == t0 then return end
		task.spawn(dive, player, char, t0)
	end)
end
local function onPlayer(p)
	p.CharacterAdded:Connect(function(c) watch(p, c) end)
	if p.Character then watch(p, p.Character) end
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do onPlayer(p) end
