-- eggloader_patch5 (EggLoader 1.9 Studio fix, iPhone 17 Pro check): the title was 10 / 26 px on the phone; minimums 13 / 36 px.
local PAIRS = {
{[=====[		local tSm, tBg = math.max(2.6 * ch, 10), math.max(7 * ch, 26)]=====], [=====[		local tSm, tBg = math.max(2.6 * ch, 13), math.max(7 * ch, 36)]=====]},
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
