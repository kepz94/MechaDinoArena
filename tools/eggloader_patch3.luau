-- eggloader_patch3 (EggLoader 1.9 Studio fixes): bar rate, LOADING before the hatch, glow behind the egg.
local PAIRS = {
{[=====[--     "parked" / "noGround" / "menu" / "menuWait", nil once loaded), for live hangs (MDA-598).]=====], [=====[--     "parked" / "noGround" / "menu" / "menuWait", nil once loaded), for live hangs (MDA-598).
--   * Studio check fixes (same version): the bar rises at most EggLoaderBarRate (0.6) a second while the status words are on (the
--     asset part of the progress could jump it 54% -> 95% in one frame); the word reads LOADING (not READY) until the hatch starts;
--     the glow sits behind the egg (ZIndex 1) and is softer.]=====]},
{[=====[		s.glowA = frame(root, "GlowA", VOLT, 2)
		s.glowA.BackgroundTransparency = 0.5]=====], [=====[		s.glowA = frame(root, "GlowA", VOLT, 1)
		s.glowA.BackgroundTransparency = 0.7]=====]},
{[=====[for k, v in pairs({EggLoaderLookAEnabled = true, EggLoaderSeamlessEnabled = true, EggLoaderStatusEnabled = true, EggLoaderSwapWait = 2}) do]=====], [=====[for k, v in pairs({EggLoaderLookAEnabled = true, EggLoaderSeamlessEnabled = true, EggLoaderStatusEnabled = true, EggLoaderSwapWait = 2,
	EggLoaderBarRate = 0.6}) do]=====]},
{[=====[			local word, cap, why = stepNow(s)
			target = math.min(target, cap)]=====], [=====[			local word, cap, why = stepNow(s)
			target = math.min(target, cap)
			if word == "READY" and t < MIN_CRACK then word = "LOADING" end]=====]},
{[=====[		s.p = math.max(s.p, target)]=====], [=====[		if stOn and not ready then -- v1.9: no jumps
			local now2 = os.clock()
			local dt = math.clamp(now2 - (s.lastStep or now2), 0, 0.1)
			s.lastStep = now2
			target = math.min(target, s.p + dt * (tonumber(script:GetAttribute("EggLoaderBarRate")) or 0.6))
		end
		s.p = math.max(s.p, target)]=====]},
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
