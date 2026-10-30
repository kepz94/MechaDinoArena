-- PounceSlash v1.0 (Dino Arcade) — which arm does what while a raptor is latched, timed by the server's hits, so every
-- slash is one hit and every hit is one slash. Kepu 2026-10-29: "the slashes need to be animated and show some wind up in
-- it as well as be accurate to the damage taken. I can't have 2 slashes only but then -4 health appears in between all
-- those slashes". Used by IdleAnimation 1.28 (angles from PouncePose 1.1 slashArm, pose from PouncePose.slash).
-- Server inputs (raptor attributes, PounceServer 1.7): PounceLatchedAt, PounceHitCount (0 at the latch, + 1 per hit,
--   landing = 1), PounceBiteAt (server time of the newest hit), PounceNextHitAt (server time of the next tick hit).
-- Rules (deterministic):
--   * arm of hit n: n odd -> "L", n even -> "R" (PounceFX 1.1 uses the same rule for the streak and number).
--   * a strike starts only when this client receives a new PounceHitCount for the current latch (a PounceBiteAt at or
--     after PounceLatchedAt - 0.01); it runs strike (PounceSlashStrike) -> rake (PounceSlashRakeTime) -> recover
--     (PounceSlashRecover) from the arm's angles at that moment. No hit, no strike.
--   * the arm of the next hit (count + 1) winds up from W = min(PounceSlashWindup, 0.7 x (PounceNextHitAt - PounceBiteAt))
--     before PounceNextHitAt (server clock) and then holds "cocked" until that hit arrives; a wind-up replaces a recover
--     still running on that arm. Before the first hit and between its own slashes an arm grips ("rest").
--   * a new tracker (new latch on this client) takes the current count as already seen, unless PounceLatchedAt is less
--     than 0.5 s old (it arrived with the landing hit), so a hit from an earlier latch never slashes again; a change of
--     PounceLatchedAt resets the count to 0 for the new latch.
--   * a schedule more than 1 s past PounceNextHitAt (or one from an earlier latch) is stale: no wind-up, a cocked arm goes
--     back to the grip.
--   * two hits arriving in one frame (lag) give one strike for the newest; Strikes / Hits diagnostics show the gap.
-- update(model, serverNow, clientNow, s) -> arms {L = {p, sp}, R = {p, sp}, dip, side}, state string
--   ("L:<phase> R:<phase>"), strikes (this latch), hits (count seen).
local PouncePose = require(script.Parent.PouncePose)

local PounceSlash = {}
PounceSlash.Version = "1.0"
local Tracker = {}
Tracker.__index = Tracker

local function sideOf(n) return (n % 2 == 1) and "L" or "R" end

function PounceSlash.new(model, serverNow)
	local self = setmetatable({}, Tracker)
	self.latchedAt = model:GetAttribute("PounceLatchedAt")
	local count = model:GetAttribute("PounceHitCount")
	local fresh = type(self.latchedAt) == "number" and serverNow - self.latchedAt < 0.5
	self.count = (type(count) == "number" and not fresh) and count or 0
	self.strikes = 0
	self.arm = {L = {phase = "rest"}, R = {phase = "rest"}}
	return self
end

-- phase change for one arm: remember the angles it starts from
local function enter(a, phase, at)
	if a.phase == phase then return end
	a.phase, a.at, a.fromP, a.fromS = phase, at, a.p, a.sp
end

function Tracker:update(model, serverNow, clientNow, s)
	local latchedAt = model:GetAttribute("PounceLatchedAt")
	if latchedAt ~= self.latchedAt then
		self.latchedAt, self.count, self.strikes = latchedAt, 0, 0
		for _, a in pairs(self.arm) do
			if a.phase == "windup" or a.phase == "cocked" then enter(a, "rest", clientNow) end
		end
	end
	local count = model:GetAttribute("PounceHitCount")
	local biteAt = model:GetAttribute("PounceBiteAt")
	local current = type(count) == "number" and type(biteAt) == "number" and type(latchedAt) == "number"
		and biteAt >= latchedAt - 0.01
	if current and count ~= self.count then
		if count > self.count then
			local a = self.arm[sideOf(count)]
			a.phase = nil -- always a new strike, even straight from another one
			enter(a, "strike", clientNow)
			a.strikeAt = clientNow
			self.strikes += 1
			self.side = sideOf(count)
		end
		self.count = count
	end
	local nextAt = model:GetAttribute("PounceNextHitAt")
	local nextSide = sideOf(self.count + 1)
	local S, Rk, V = s.PounceSlashStrike, s.PounceSlashRakeTime, s.PounceSlashRecover
	local dip, states = 0, {}
	for _, side in ipairs({"L", "R"}) do
		local a = self.arm[side]
		-- strike -> rake -> recover -> rest by local time since the strike began
		if a.phase == "strike" or a.phase == "rake" or a.phase == "recover" then
			a.strikeAt = a.strikeAt or a.at
			local age = clientNow - a.strikeAt
			if age >= S + Rk + V then
				a.strikeAt = nil
				enter(a, "rest", clientNow)
			elseif age >= S + Rk then
				enter(a, "recover", clientNow)
			elseif age >= S then
				enter(a, "rake", clientNow)
			end
		end
		-- the next hit's arm winds up and waits cocked
		local live = current and type(nextAt) == "number" and nextAt > biteAt and serverNow - nextAt < 1
		if a.phase == "cocked" and not (live and side == nextSide) then
			enter(a, "rest", clientNow) -- the expected hit never came (stale schedule)
		end
		if side == nextSide and live and (a.phase == "rest" or a.phase == "recover"
			or a.phase == "windup" or a.phase == "cocked") then
			local interval = math.max(0.05, nextAt - biteAt)
			local W = math.min(s.PounceSlashWindup, 0.7 * interval)
			local w0 = nextAt - W
			if serverNow >= nextAt then
				if a.phase ~= "cocked" then
					if a.phase ~= "windup" then enter(a, "windup", clientNow) end
					a.windU = 1
					enter(a, "cocked", clientNow)
				end
			elseif serverNow >= w0 then
				if a.phase ~= "windup" then
					a.strikeAt = nil
					enter(a, "windup", clientNow)
				end
				a.windU = (serverNow - w0) / W
			end
		end
		local u
		if a.phase == "windup" then
			u = a.windU or 0
		elseif a.phase == "strike" then
			u = (clientNow - a.strikeAt) / S
		elseif a.phase == "rake" then
			u = (clientNow - a.strikeAt - S) / Rk
		elseif a.phase == "recover" then
			u = (clientNow - a.strikeAt - S - Rk) / V
		else
			u = 0
		end
		u = math.clamp(u, 0, 1)
		if a.phase == "strike" or a.phase == "rake" then
			dip = math.max(dip, a.phase == "strike" and u or 1)
		elseif a.phase == "recover" then
			dip = math.max(dip, 1 - u * u * (3 - 2 * u))
		end
		a.p, a.sp = PouncePose.slashArm(a.phase, u, a.fromP, a.fromS, s, 1)
		states[#states + 1] = side .. ":" .. tostring(a.phase)
	end
	return {L = {p = self.arm.L.p, sp = self.arm.L.sp}, R = {p = self.arm.R.p, sp = self.arm.R.sp}, dip = dip,
		side = self.side}, table.concat(states, " "), self.strikes, self.count
end

return PounceSlash
