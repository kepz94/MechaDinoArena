-- killfeed_patch1 (KillFeed 1.5): hidden while the phone menu drawer is open.
local PAIRS = {
{[=====[VERSION = "1.4" -- v1.4 filler bot personas: no BOT tag]=====], [=====[VERSION = "1.4" -- v1.4 filler bot personas: no BOT tag
VERSION = "1.5" -- v1.5 hidden while the phone menu drawer is open
-- v1.5 (Kepu 2026-11-26 03:27 "When I press the menu button top right, I can't see anything because it's hidden behind kill feed"):
--   on phone HUD v2 the lines sit right under the ☰ (v1.2), the same spot as the drawer's MENU / SKILLS / camera / SQUAD buttons
--   (PhoneMenu 1.0 PhoneMenuY_*), all in DisplayOrder 6 guis. While the player attribute PhoneMenuOpen is true the kill feed
--   (lines and banner) is hidden; it shows again when the drawer closes. Switch: script attribute KillFeedHideOnMenuEnabled
--   (default true, read per frame; false = 1.4).]=====]},
{[=====[	gui.Enabled = script:GetAttribute("KillFeedEnabled") ~= false and player:GetAttribute("InMenu") ~= true]=====], [=====[	gui.Enabled = script:GetAttribute("KillFeedEnabled") ~= false and player:GetAttribute("InMenu") ~= true
		and not (script:GetAttribute("KillFeedHideOnMenuEnabled") ~= false and player:GetAttribute("PhoneMenuOpen") == true) -- v1.5]=====]},
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
