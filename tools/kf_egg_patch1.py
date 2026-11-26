import sys
def build(path, outp, pairs, title):
    src = open(path, encoding='utf-8').read()
    for o, n in pairs: assert src.count(o) == 1, (o[:80], src.count(o))
    out = ['-- ' + title, 'local PAIRS = {']
    for o, n in pairs: out.append('{[=====[' + o + ']=====], [=====[' + n + ']=====]},')
    out.append('}')
    out.append('''local s = sc.Source
for k, pr in ipairs(PAIRS) do
	local a, b = string.find(s, pr[1], 1, true)
	assert(a, "miss " .. k .. ": " .. pr[1]:sub(1, 60))
	assert(not string.find(s, pr[1], b + 1, true), "dup " .. k)
	s = s:sub(1, a - 1) .. pr[2] .. s:sub(b + 1)
end
sc.Source = s
local h = 0 for i = 1, #s do h = (h * 31 + s:byte(i)) % 2147483647 end
return #s .. " " .. h
''')
    open(outp, 'w', encoding='utf-8').write('\n'.join(out))
kf = [
('VERSION = "1.4" -- v1.4 filler bot personas: no BOT tag', '''VERSION = "1.4" -- v1.4 filler bot personas: no BOT tag
VERSION = "1.5" -- v1.5 hidden while the phone menu drawer is open
-- v1.5 (Kepu 2026-11-26 03:27 "When I press the menu button top right, I can't see anything because it's hidden behind kill feed"):
--   on phone HUD v2 the lines sit right under the ☰ (v1.2), the same spot as the drawer's MENU / SKILLS / camera / SQUAD buttons
--   (PhoneMenu 1.0 PhoneMenuY_*), all in DisplayOrder 6 guis. While the player attribute PhoneMenuOpen is true the kill feed
--   (lines and banner) is hidden; it shows again when the drawer closes. Switch: script attribute KillFeedHideOnMenuEnabled
--   (default true, read per frame; false = 1.4).'''),
('	gui.Enabled = script:GetAttribute("KillFeedEnabled") ~= false and player:GetAttribute("InMenu") ~= true',
 '''	gui.Enabled = script:GetAttribute("KillFeedEnabled") ~= false and player:GetAttribute("InMenu") ~= true
		and not (script:GetAttribute("KillFeedHideOnMenuEnabled") ~= false and player:GetAttribute("PhoneMenuOpen") == true) -- v1.5'''),
]
build('src/client/KillFeed.client.luau', 'tools/killfeed_patch1.luau', kf, 'killfeed_patch1 (KillFeed 1.5): hidden while the phone menu drawer is open.')
eg = [
('VERSION = "1.7" -- v1.7 the tutorial takes over from the join egg', '''VERSION = "1.7" -- v1.7 the tutorial takes over from the join egg
VERSION = "1.8" -- v1.8 the baby has one mouth
-- v1.8 (Kepu 2026-11-26 03:27 "the loading screen baby Dino has two mouths one on the front and teeth on the side"): the baby's face
--   looks forward (two eyes, two blush spots, the smile in the middle), but the 1.0 drawing also kept a side snout from the
--   mockup's profile (unit rects 100,40 28x28 snout, 104,60 24x8 jaw, 112,64 and 120,64 4x4 teeth). Those 4 are no longer drawn.
--   Switch: script attribute EggLoaderBabyFrontEnabled (default true, read per build; false = 1.7).'''),
('	}) do unitRect(bb, t[1], t[2], t[3], t[4], t[5]) end',
 '''	}) do
		if not (script:GetAttribute("EggLoaderBabyFrontEnabled") ~= false and ({["100,40"] = true, ["104,60"] = true, ["112,64"] = true,
			["120,64"] = true})[t[1] .. "," .. t[2]]) then -- v1.8: no side snout / jaw / teeth
			unitRect(bb, t[1], t[2], t[3], t[4], t[5])
		end
	end'''),
]
build('src/first/EggLoader.client.luau', 'tools/eggloader_patch1.luau', eg, 'eggloader_patch1 (EggLoader 1.8): the baby has one mouth (no side snout / teeth).')
print('ok')
