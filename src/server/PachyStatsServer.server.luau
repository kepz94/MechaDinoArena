-- PachyStatsServer v1.1 (Mecha Dino Arena) — the Pachycephalosaurus' Last Stand and Head Down rows in play. MDA-232, plan
-- docs/plans/PACHY_STATS_v1.0.md Task 3 (deterministic map); mockup docs/mockups/pachy_health_defense_options.html v0.1
-- (Kepu 2026-11-04 "Option B for health and option A for defense", star "Untouchable at 30%", step III "Shoves only").
-- Reads the character attributes SkillEffects 1.40 writes (SkillTree 1.59 effects); all off values = nothing happens.
-- Who: player characters with Species "Pachy". Every other character: nothing.
-- Damage cut (Teno Brace I's way: a refund of part of the hit in the same server step; Kepu's rule "no health regen and no
--   health steal on the pachy" is kept: nothing is healed beyond the hit just taken). On each Humanoid health drop (not this
--   script's own write; health after the hit > 0):
--   * charging = HeadbuttStartedAt newer than HeadbuttEndedAt and HeadbuttHitAt (HookServer's test);
--   * Head Down: while charging, cutHD = drop x (1 - PachyHeadDownMul) (I 0.85, II 0.75);
--   * Last Stand: line = PachyLastStandBelow (0.3) x MaxHealth; only the part of the drop under the line counts:
--     cutLS = min(drop, max(0, line - health after)) x (1 - PachyLastStandMul) (I 0.85, II 0.75);
--   * refund = max(cutHD, cutLS) (they do not stack); Health = min(MaxHealth, health after + refund).
--   A killing blow (health after <= 0) is never refunded (a Humanoid at 0 is dead).
-- Last Stand star (PachyLastStandStar): the first drop of a life whose result (after the refund) is under the line starts the
--   untouchable window: PachyLastStandUntil = now + PachyLastStandTime (1.5 s), PachyLastStandUsed = true, an invisible
--   ForceField "PachyLastStandField" under the character until then (blocks Humanoid:TakeDamage, so bot bites and Arena hits
--   through ArenaPvP's bridge do nothing, like the Energy Shield's field), and any health drop inside the window is
--   refunded in full (catches damage that skips the ForceField). Once per character (a respawn is a new life). As with the
--   Energy Shield, a hit large enough to take an Arena attacker's DummyHealth copy to 0 inside the window can still stamp the
--   attacker's kill record while the pachy lives (BiteServer / PounceServer do not check shields).
-- Head Down III (PachyHeadDownNoShove): while charging, character HeadbuttShoveEnabled = false (HeadbuttShove client 1.0 skips
--   the push: pachy headbutts, teno scratch shoves, Dome Visor knocks, Stun Breaker pushes); back to nil when the charge ends.
--   Only this script's own false is cleared. (Head Down star "can't be stunned" is SkillEffects 1.40's StunnedUntil branch.)
-- Switch: script attribute PachyStatsServerEnabled (default true, read every step; false = nothing here runs, the shove
--   switch goes back and an open window's ForceField is removed).
-- Diagnostics: script PachyStatsServerVersion, PachyStatsRefunds (count); character PachyStatsCut (last refund / drop, 0.01
--   steps), PachyStatsRefunded (total, 0.1 steps), PachyStatsLow (under the line now), PachyStatsCharging, PachyLastStandUsed,
--   PachyLastStandUntil.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local VERSION = "1.0"
-- v1.1 (MDA-313, plan docs/plans/PACHY_MOVES_ANIM_v1.0.md Task 11; Kepu 2026-11-05 "A · Battle Roar", red-team "Keep both"):
--   when a drop takes the pachy (Last Stand bought: PachyLastStandBelow > 0) from at or above the line to under it,
--   PachyLastStandAt = now (each crossing; PachyMovesPose 1.0 roars, PachyMovesFX 1.0 bursts a ring). Switch: script
--   attribute PachyLastStandStampEnabled (default true, read at each drop; false = 1.0).
VERSION = "1.1" -- v1.1 Last Stand crossing stamp
local FIELD = "PachyLastStandField"
if script:GetAttribute("PachyLastStandStampEnabled") == nil then script:SetAttribute("PachyLastStandStampEnabled", true) end -- v1.1

script:SetAttribute("PachyStatsServerVersion", VERSION)
script:SetAttribute("PachyStatsRefunds", 0)
if script:GetAttribute("PachyStatsServerEnabled") == nil then script:SetAttribute("PachyStatsServerEnabled", true) end
local function on() return script:GetAttribute("PachyStatsServerEnabled") ~= false end

local function now() return workspace:GetServerTimeNow() end
local function num(m, k, d) local v = tonumber(m:GetAttribute(k)) return v ~= nil and v == v and v or d end
local function show(m, k, v) if m:GetAttribute(k) ~= v then m:SetAttribute(k, v) end end
local function isPachy(char) return char:GetAttribute("Species") == "Pachy" end
local function charging(char)
	local s = num(char, "HeadbuttStartedAt", 0)
	return s > 0 and s > num(char, "HeadbuttEndedAt", 0) and s > num(char, "HeadbuttHitAt", 0)
end
local function round(x, step) return math.floor(x / step + 0.5) * step end

local chars = {} -- [char] = state

local function closeWindow(char, st)
	st.untilT = nil
	if st.field and st.field.Parent then st.field:Destroy() end
	st.field = nil
end

local function track(char)
	if chars[char] then return end
	local hum = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid", 10)
	if not hum or chars[char] then return end
	local st = {hum = hum, last = hum.Health, own = nil, used = false, untilT = nil, field = nil, shoveOwned = false, refunded = 0}
	chars[char] = st
	hum.HealthChanged:Connect(function(h)
		if st.own and math.abs(h - st.own) < 1e-3 then st.own = nil st.last = h return end
		local drop = st.last - h
		st.last = h
		if drop <= 0 or h <= 0 or not on() or not isPachy(char) then return end
		local t = now()
		local max = hum.MaxHealth
		local refund
		if st.untilT and t < st.untilT then -- star window: the whole hit back
			refund = drop
		else
			local cutHD = charging(char) and drop * (1 - math.clamp(num(char, "PachyHeadDownMul", 1), 0, 1)) or 0
			local below = math.clamp(num(char, "PachyLastStandBelow", 0), 0, 1)
			local line = below * max
			local cutLS = below > 0 and math.min(drop, math.max(0, line - h)) * (1 - math.clamp(num(char, "PachyLastStandMul", 1), 0, 1)) or 0
			refund = math.max(cutHD, cutLS)
		end
		local new = h
		if refund > 0 then
			new = math.min(max, h + refund)
			st.own, st.last = new, new
			hum.Health = new
			st.refunded += new - h
			script:SetAttribute("PachyStatsRefunds", (script:GetAttribute("PachyStatsRefunds") or 0) + 1)
			show(char, "PachyStatsRefunded", round(st.refunded, 0.1))
		end
		show(char, "PachyStatsCut", round((new - h) / drop, 0.01))
		-- star: the first drop of this life that ends under the line
		local below = math.clamp(num(char, "PachyLastStandBelow", 0), 0, 1)
		if script:GetAttribute("PachyLastStandStampEnabled") ~= false and below > 0 and new > 0 and new < below * max
			and h + drop >= below * max then -- v1.1: crossed the line on this drop
			char:SetAttribute("PachyLastStandAt", t)
		end
		if char:GetAttribute("PachyLastStandStar") == true and not st.used and below > 0 and new > 0 and new < below * max then
			st.used = true
			st.untilT = t + math.max(0, num(char, "PachyLastStandTime", 1.5))
			local ff = Instance.new("ForceField")
			ff.Name = FIELD
			ff.Visible = false
			ff.Parent = char
			st.field = ff
			char:SetAttribute("PachyLastStandUsed", true)
			char:SetAttribute("PachyLastStandUntil", st.untilT)
		end
	end)
	char.AncestryChanged:Connect(function(_, parent)
		if not parent then
			closeWindow(char, st)
			chars[char] = nil
		end
	end)
end

local function setShove(char, st, want)
	if want and not st.shoveOwned then
		char:SetAttribute("HeadbuttShoveEnabled", false)
		st.shoveOwned = true
	elseif not want and st.shoveOwned then
		if char:GetAttribute("HeadbuttShoveEnabled") == false then char:SetAttribute("HeadbuttShoveEnabled", nil) end
		st.shoveOwned = false
	end
end

RunService.Heartbeat:Connect(function()
	local t = now()
	local running = on()
	for char, st in pairs(chars) do
		local active = running and isPachy(char) and st.hum.Health > 0
		if st.untilT and (not active or t >= st.untilT) then closeWindow(char, st) end
		if not active then
			setShove(char, st, false)
			continue
		end
		local isCharging = charging(char)
		setShove(char, st, isCharging and char:GetAttribute("PachyHeadDownNoShove") == true)
		show(char, "PachyStatsCharging", isCharging)
		local below = math.clamp(num(char, "PachyLastStandBelow", 0), 0, 1)
		show(char, "PachyStatsLow", below > 0 and st.hum.Health < below * st.hum.MaxHealth)
	end
end)

local function onPlayer(pl)
	pl.CharacterAdded:Connect(function(c) task.defer(track, c) end)
	if pl.Character then task.defer(track, pl.Character) end
end
Players.PlayerAdded:Connect(onPlayer)
for _, pl in ipairs(Players:GetPlayers()) do onPlayer(pl) end
