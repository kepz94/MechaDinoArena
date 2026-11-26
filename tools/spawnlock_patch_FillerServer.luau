-- spawnlock_patch_FillerServer (FillerServer 1.2): SPAWN_LOCK_v1.0.
local PAIRS = {
{[=====[VERSION = "1.1" -- v1.1 EmoteId cleared after the emote]=====], [=====[VERSION = "1.1" -- v1.1 EmoteId cleared after the emote
VERSION = "1.2" -- v1.2 safe guard: no fights on / right off the islet
-- v1.2 (island spawn lock, plan docs/plans/SPAWN_LOCK_v1.0.md Task 4; Kepu 2026-11-26 "the bots are just fighting right at
--   spawn even without damage", pick "Fighting each other"): a bot inside the safe area gets safeUntil = now + FillerSafeGuard
--   (default HubRules.GUARD, 3) s, renewed every tick while inside, so it keeps the protection for 3 s after leaving like a player.
--   While os.clock() < safeUntil the bot is not a target for other bots and steps with no enemies (it walks, it does not
--   swing) and its old target is dropped. Switch: script attribute FillerSafeGuardEnabled (default true, read per tick;
--   false = 1.1). Diagnostic: script attribute FillerSafeBots (bots guarded this tick).]=====]},
{[=====[		local eligible = {}
		for _, r in ipairs(recs) do
			if r.model and r.model.Parent and r.hrp and r.hrp.Parent and not r.deadAt and not r.leaving
				and not inSafe(r.hrp.Position) then
]=====], [=====[		local safeOn, safeNow, safeN = get("FillerSafeGuardEnabled") ~= false, os.clock(), 0 -- v1.2
		for _, r in ipairs(recs) do
			if safeOn and r.hrp and r.hrp.Parent and not r.deadAt and inSafe(r.hrp.Position) then
				r.safeUntil = safeNow + (tonumber(get("FillerSafeGuard")) or HR.GUARD or 3)
			end
			if safeOn and r.safeUntil and safeNow < r.safeUntil then safeN += 1 end
		end
		set("FillerSafeBots", safeN)
		local eligible = {}
		for _, r in ipairs(recs) do
			if r.model and r.model.Parent and r.hrp and r.hrp.Parent and not r.deadAt and not r.leaving
				and not inSafe(r.hrp.Position)
				and not (safeOn and r.safeUntil and safeNow < r.safeUntil) then -- v1.2
]=====]},
{[=====[					if not rec.busy then
						local ctx = {bots = eligible, R = R, H = H,]=====], [=====[					local guarded = safeOn and rec.safeUntil and os.clock() < rec.safeUntil -- v1.2
					if guarded then rec.target = nil end
					if not rec.busy then
						local ctx = {bots = guarded and {} or eligible, R = R, H = H,]=====]},
}
local s = sc.Source
for k, pr in ipairs(PAIRS) do
	local a, b = string.find(s, pr[1], 1, true)
	assert(a, "miss " .. k .. ": " .. pr[1]:sub(1, 60))
	assert(not string.find(s, pr[1], b + 1, true), "dup " .. k)
	s = s:sub(1, a - 1) .. pr[2] .. s:sub(b + 1)
end
sc.Source = s
local h = 0 for i = 1, #s do h = (h * 31 + s:byte(i)) % 2147483647 end
return #s .. " " .. h
