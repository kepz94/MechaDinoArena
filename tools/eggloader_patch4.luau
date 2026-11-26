-- eggloader_patch4 (EggLoader 1.9 Studio fix): the glow under the egg read as a hard band; now a thin soft line (30 ch x 2.4 ch).
local PAIRS = {
{[=====[UDim2.fromOffset(W / 2, 66 * ch), UDim2.fromOffset(34 * ch, 5 * ch)]=====], [=====[UDim2.fromOffset(W / 2, 66 * ch), UDim2.fromOffset(30 * ch, 2.4 * ch)]=====]},
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
