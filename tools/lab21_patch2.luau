-- lab21_patch2 (Lab 2.1 Studio fix 2026-11-26): "TAP TO PUT ON 3" cut to "TAP TO PUT…" on a tile; now "PUT ON 3".
local PAIRS = {
{[=====[						sl.Text = "TAP TO PUT ON " .. L3.wslot]=====], [=====[						sl.Text = "PUT ON " .. L3.wslot -- Studio: "TAP TO PUT ON n" was cut on a tile]=====]},
{[=====[--     n" + CANCEL, owned tiles say "TAP TO PUT ON n"; tap an owned emote]=====], [=====[--     n" + CANCEL, owned tiles say "PUT ON n"; tap an owned emote]=====]},
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
