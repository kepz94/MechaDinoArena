"""Skin drop v1.0 (Kepu 2026-11-26 16:14-16:15). Run: python3 -I tools/launch_patch.py <outdir> tools/jobs/jobs_skin_drop.py"""
Q = ('Kepu 2026-11-26 16:14 on mockup docs/mockups/skin_drop_v0.1.html: "A1-a3 should be free as well as the holiday ones" / "They\'re '
     'the ones to earn" / 16:15 "Okay let\'s build"; earn goals and the rest of the lineup: standing pick, recommended')
SS = 'game:GetService("ServerStorage").DinoArcade.'
JOBS = {}

U = []
a = 'US.VERSION = "1.5" -- v1.5 streak skins claimed at the Quest Stand\n'
U.append((a, a + '''US.VERSION = "1.6" -- v1.6 skin drop: 13 new skins (3 earn, 4 holiday earn, 6 Robux)
-- v1.6 (''' + Q + '''):
--   * Earn (any time): Tiger (50 kills), Leopard (win 10), Jungle Camo (play 25).
--   * Holiday earn, only while the window is open (US.HOLIDAY_FROM 2026-12-01 00:00 UTC .. US.HOLIDAY_TO 2027-01-01 00:00 UTC):
--     Gingerbread (play 10), Candy Cane (40 kills), Frostbite (win 8), Holiday Lights (win 5 in a row). Progress reads the lifetime
--     stats as every earn skin does; outside the window progress() returns 0 (locked, the text says when), so SkinServer never grants
--     them then. Owners keep them. EggRules 1.1 keeps them out of the Favorite Egg.
--   * Robux: Bubblegum (RARE 149, bland), Biohazard / Deep Sea / Sunset (EPIC 499, glowing), Galaxy / Aurora (LEGENDARY 999, animated:
--     Galaxy breathe + twinkle stars, Aurora wave), on the existing products by rarity.
--   * Looks = the Studio renders on the mockup (tuned Leopard, Jungle Camo, Galaxy, Deep Sea, Gingerbread, Holiday Lights).
--   * ORDER: the earn ones after Ink War, the holiday ones after them, Bubblegum after Chrome, the EPIC ones after Obsidian Fang,
--     Galaxy / Aurora after Hellfire.
--   Switches (module constants): US.SKIN_DROP (true; false = the 1.5 lineup), US.HOLIDAY_WINDOW (true; false = holiday skins earnable
--   any time). API: US.windowOpen(sk, now) -> bool (true when the skin has no window).
US.SKIN_DROP = true -- v1.6
US.HOLIDAY_WINDOW = true -- v1.6
US.HOLIDAY_FROM, US.HOLIDAY_TO = 1796083200, 1798761600 -- v1.6: 2026-12-01 .. 2027-01-01 00:00 UTC
'''))
a = 'US.ISLAND_STREAK_UNLOCKS = true -- v1.4\n'
U.append((a, '''-- v1.6: skin drop (see the header)
if US.SKIN_DROP then
	local function earnD(stat, need, text, holiday)
		local u = {kind = "earn", stat = stat, need = need, text = text}
		if holiday then
			u.window = {US.HOLIDAY_FROM, US.HOLIDAY_TO}
			u.text = "Dec 1 to Jan 1: " .. text
			u.holiday = true
		end
		return u
	end
	local function robuxD(rarity, price) return {kind = "robux", rarity = rarity, price = price} end
	local S = US.SKINS
	S.tiger = {name = "Tiger", unlock = earnD("kills", 50, "Get 50 kills"),
		cols = {belly = "F2E6CC", claws = "1A1410", eyes = "F0C81E", mask = "151210", accent = "151210"}, sw = {"E8771E", "151210", "F2E6CC"},
		pattern = function(slot, lp)
			if not BODY[slot] then return nil end
			local z = lp.Z + math.sin(lp.Y * 1.8 + lp.X) * 0.35
			return (math.floor(z / 0.7) % 3 == 0) and "151210" or "E8771E"
		end}
	S.leopard = {name = "Leopard", unlock = earnD("wins", 10, "Win 10 Arena matches"),
		cols = {belly = "F3E3C0", claws = "2A1E12", eyes = "9BE04A", mask = "2A1E12", accent = "2A1E12"}, sw = {"E0AE52", "24180E", "7A4A20"},
		pattern = function(slot, lp)
			if not BODY[slot] then return nil end
			local r = cell(lp, 0.7, 91)
			if r < 0.3 then return "24180E" end
			if r < 0.45 then return "7A4A20" end
			return "E0AE52"
		end}
	S.junglecamo = {name = "Jungle Camo", unlock = earnD("matches", 25, "Play 25 Arena matches"),
		cols = {belly = "A9A77A", claws = "1E2414", eyes = "E8D23A", mask = "2E3A1E", accent = "2E3A1E"},
		sw = {"3E4F22", "7A8A44", "1F2914", "A08E58"},
		pattern = function(slot, lp)
			if not BODY[slot] then return nil end
			return pick({"3E4F22", "7A8A44", "1F2914", "A08E58"}, cell(lp, 1.0, 95))
		end}
	S.gingerbread = {name = "Gingerbread", unlock = earnD("matches", 10, "Play 10 Arena matches", true),
		cols = {belly = "C98A55", claws = "3A2010", eyes = "1A0F08", mask = "7A4420", accent = "F7F2E8", limbs = "A8642E"},
		sw = {"A8642E", "F7F2E8", "C98A55"},
		pattern = function(slot, lp)
			if not BODY[slot] then return nil end
			if frac(lp.Z / 1.3) < 0.18 or frac(lp.Y / 1.3) < 0.12 then return "F7F2E8" end
			return "A8642E"
		end}
	S.candycane = {name = "Candy Cane", unlock = earnD("kills", 40, "Get 40 kills", true),
		cols = {belly = "FFFFFF", claws = "8A1A1E", eyes = "2ECC71", mask = "D8232A", accent = "2ECC71"}, sw = {"D8232A", "F7F7F7", "2ECC71"},
		pattern = function(slot, lp)
			if not BODY[slot] then return nil end
			return frac((lp.Z - lp.Y * 0.8) / 1.4) < 0.5 and "D8232A" or "F7F7F7"
		end}
	S.frostbite = {name = "Frostbite", unlock = earnD("wins", 8, "Win 8 Arena matches", true),
		cols = {belly = "EAF6FF", claws = "3A5A78", eyes = "7FE9FF", mask = "8FB8D8", accent = "7FE9FF"},
		mats = {eyes = "Neon", accent = "Neon", belly = "Glass"}, sw = {"CFE8F7", "8FB8D8", "7FE9FF"},
		pattern = function(slot, lp)
			if not BODY[slot] then return nil end
			if cell(lp, 0.6, 131) < 0.13 then return "7FE9FF", "Neon" end
			return slot == "secondary" and "8FB8D8" or "CFE8F7", "Glass"
		end}
	S.holidaylights = {name = "Holiday Lights", unlock = earnD("best", 5, "Win 5 Arena matches in a row", true), anim = true,
		cols = {eyes = "FFD23A", claws = "0E2414", accent = "1E4D2B"}, mats = {eyes = "Neon"},
		sw = {"1E4D2B", "FF3B3B", "FFD23A", "3BA0FF"},
		pattern = function(slot, lp)
			if not WHOLE[slot] then return nil end
			if cell(lp, 0.5, 141) < 0.3 then
				return pick({"FF3B3B", "FFD23A", "3BA0FF", "3BFF6A"}, cell(lp, 0.5, 142)), "Neon", "twinkle", ph(lp, 143)
			end
			return pick({"1E4D2B", "17402A", "245A32"}, cell(lp, 1.0, 144))
		end}
	S.bubblegum = {name = "Bubblegum", unlock = robuxD("RARE", 149),
		cols = {belly = "FFF0F7", claws = "C85A8A", eyes = "FF4FA0", mask = "FF8FC0", accent = "8FD8FF"}, sw = {"FFB7D5", "8FD8FF", "FFF27A"},
		pattern = function(slot, lp)
			if not BODY[slot] then return nil end
			local r = cell(lp, 0.9, 97)
			if r < 0.14 then return "8FD8FF" end
			if r < 0.24 then return "FFF27A" end
			return "FFB7D5"
		end}
	S.biohazard = {name = "Biohazard", unlock = robuxD("EPIC", 499),
		cols = {belly = "2A2E22", claws = "0E100C", eyes = "7CFF4A", mask = "141414", accent = "7CFF4A"},
		mats = {eyes = "Neon", accent = "Neon"}, sw = {"F2D21E", "141414", "7CFF4A"},
		pattern = function(slot, lp)
			if not BODY[slot] then return nil end
			if slot == "secondary" then return "7CFF4A", "Neon" end
			return frac((lp.Z + lp.Y) / 1.6) < 0.5 and "F2D21E" or "141414"
		end}
	S.deepsea = {name = "Deep Sea", unlock = robuxD("EPIC", 499),
		cols = {belly = "1A4E6E", claws = "08141F", eyes = "3AF0FF", mask = "08141F", accent = "3AF0FF"},
		mats = {eyes = "Neon", accent = "Neon"}, sw = {"123C66", "18508A", "3AF0FF"},
		pattern = function(slot, lp)
			if not BODY[slot] then return nil end
			if cell(lp, 0.6, 101) < 0.24 then return "3AF0FF", "Neon" end
			return pick({"123C66", "18508A", "0E2E55"}, cell(lp, 1.1, 102))
		end}
	S.sunset = {name = "Sunset", unlock = robuxD("EPIC", 499),
		cols = {belly = "FFC27A", claws = "2A1430", eyes = "FFD23A", mask = "3A1A4A", accent = "FFD23A"},
		mats = {eyes = "Neon", accent = "Neon"}, sw = {"FF5E3A", "FF9A3C", "C2457A", "5A2A8A"},
		pattern = function(slot, lp, info)
			if not BODY[slot] then return nil end
			local yf = info and info.yf or 0.5
			return yf < 0.35 and "FF5E3A" or (yf < 0.6 and "FF9A3C" or (yf < 0.8 and "C2457A" or "5A2A8A"))
		end}
	S.galaxy = {name = "Galaxy", unlock = robuxD("LEGENDARY", 999), anim = true, glow = "7A5CFF", hi = "E0C8FF",
		cols = {eyes = "FFFFFF", claws = "0A0614"}, mats = {eyes = "Neon"}, sw = {"2A1A5A", "3A2478", "1E2A6A", "FFFFFF"},
		pattern = function(slot, lp)
			if not WHOLE[slot] then return nil end
			if BODY[slot] and cell(lp, 0.5, 111) < 0.2 then
				return pick({"FFFFFF", "BFD8FF", "FFD6F5"}, cell(lp, 0.5, 114)), "Neon", "twinkle", ph(lp, 112)
			end
			return pick({"3A2478", "2A1A5A", "1E2A6A", "4A2A8A"}, cell(lp, 1.0, 113)), "Neon", "breathe", 0
		end}
	S.aurora = {name = "Aurora", unlock = robuxD("LEGENDARY", 999), anim = true, glow = "3CFFB0", hi = "B8FFF0",
		cols = {eyes = "B8FFF0", claws = "06141A"}, mats = {eyes = "Neon"}, sw = {"0A2A30", "0E3A3E", "3CFFB0"},
		pattern = function(slot, lp)
			if not WHOLE[slot] then return nil end
			if slot == "accent" or cell(lp, 0.8, 121) < 0.25 then return "3CFFB0", "Neon", "wave", 0 end
			return pick({"0A2A30", "0E3A3E", "143246"}, cell(lp, 1.0, 122)), "Neon", "wave", 0
		end}
	local function insertAfter(after, ids)
		local at = table.find(US.ORDER, after) or #US.ORDER
		for i, id in ipairs(ids) do table.insert(US.ORDER, at + i, id) end
	end
	insertAfter("inkwar", {"tiger", "leopard", "junglecamo", "gingerbread", "candycane", "frostbite", "holidaylights"})
	insertAfter("chrome", {"bubblegum"})
	insertAfter("obsidianfang", {"biohazard", "deepsea", "sunset"})
	insertAfter("hellfire", {"galaxy", "aurora"})
end
function US.windowOpen(sk, now) -- v1.6: true when the skin has no window or it is open
	local w = sk and sk.unlock and sk.unlock.window
	if not w or not US.HOLIDAY_WINDOW then return true end
	now = now or os.time()
	return now >= w[1] and now < w[2]
end
''' + a))
a = '\tif not (sk and sk.unlock.kind == "earn") then return nil, nil end\n'
U.append((a, a + '\tif not US.windowOpen(sk) then return 0, sk.unlock.need end -- v1.6: holiday skins only in their window\n'))
JOBS["UniversalSkins"] = ("src/shared/UniversalSkins.luau", SS + "UniversalSkins", U)

E = []
a = 'M.EXCLUDE = {skin = {zebra = true, storm = true}} -- the Quest Stand specials (red-team R4)\n'
E.append((a, a + '''M.VERSION = "1.1" -- v1.1 (''' + Q + '''): the December holiday skins (UniversalSkins 1.6) are never Favorite Egg prizes, so they stay
-- earn-only in their window. Switch: M.EXCLUDE_HOLIDAY (true; false = 1.0).
M.EXCLUDE_HOLIDAY = true
if M.EXCLUDE_HOLIDAY then
	for _, id in ipairs({"gingerbread", "candycane", "frostbite", "holidaylights"}) do M.EXCLUDE.skin[id] = true end
end
'''))
JOBS["EggRules"] = ("src/shared/EggRules.luau", SS + "EggRules", E)
