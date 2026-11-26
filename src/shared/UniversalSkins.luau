-- UniversalSkins v1.0 (Mecha Dino Arena) — skins that work on every dino. MDA-566, plan docs/plans/UNIVERSAL_SKINS_v0.1.md
-- Task 1, mockup docs/mockups/universal_skins_plan_v0.4.html (Kepu 2026-11-24: "a call of duty like skin system where once you
-- unlock/buy a skin, it can be applied to other Dino's as well"; picks Robux + earn by playing, merge old skins into universal,
-- pick per dino, patterns; lineup and unlock plan locked 17:58; SKINS tab "Yes, as shown").
-- Pure data + maths, plus two Instance helpers (tagModel, setAnim) shared by SkinServer 1.2 (server) and Lab 1.8 (client copy in
-- ReplicatedStorage.SkinShared).
-- Slots: every colour role of SkinCatalog 1.9 ROLES maps to one slot (SLOT). A skin gives a colour / material per slot; a slot it
--   leaves out keeps the dino's own (base) colour / material. mask and accent fall back to secondary (as the mockup).
-- Patterns: some skins colour each block by its position. lp = the block's position in the body's HumanoidRootPart space,
--   scaled so the body's longest side is 15 (SkinLP, stored once per block by tagModel). Hash: frac(sin(a * 12.9898 +
--   b * 78.233 + c * 37.719 + seed * 4.123) * 43758.5453) on floor(lp / size) (same numbers as the mockup).
-- Animated blocks: partLook returns an anim kind ("pulse" / "twinkle" / "hue") and a phase (0-1) for Neon blocks of Prism,
--   Void Matter, Spectral, Element X and Opal; SkinFX 1.0 animates them on the client.
-- Materials: the mockup's names map to Enum.Material names in MAT (Ghost / Opal -> Glass; no Transparency change, so cloaks and
--   other see-through effects keep working).
-- Unlocks (Kepu 2026-11-24 17:58, verbatim plan): Classic free; earn: Desert Runner play 3 Arena matches (W + L), Riverstone 25
--   kills, Canopy win 5, Ghost Bark 100 kills, Zebra win 15, Ink War win 3 in a row; RARE 149: Arctic, Sakura, Viper Gold,
--   Prism, Void Matter; EPIC 499: Lava, Venom, Neon Circuit, Chrome, Opal; LEGENDARY 999: Gold Hunter, Obsidian Fang,
--   Spectral, Element X. Robux skins use SkinCatalog's existing product per rarity.
-- Old saves: OLD_TO_NEW maps the 1.9 per-dino ids that stay; dropped ids (night, pachy_fossil, pachy_thunderhead, pachy_ember,
--   pachy_obsidian, herrera_bloodmoon: never sold, Kepu) map to nil.
-- API:
--   slotOf(role) -> slot or nil; get(id) -> skin or nil; sanitize(id) -> id or "classic" (old ids mapped first)
--   fromOld(id) -> universal id or nil; owns(id, ownedSet, allUnlocked) -> bool (free, or ownedSet[id] == true, or allUnlocked)
--   partLook(id, role, lp, baseHex, baseMat) -> hex, matName, animKind or nil, phase or nil
--   progress(id, stats) -> have, need (earn skins; stats = {w, l, kills, best}); unlocked(id, stats) -> bool
--   tagModel(model, species, roleOf, skip) -> parts tagged (SkinRole, SkinBaseMaterial, SkinBaseHex, SkinLP; once per part)
--   setAnim(part, kind, phase, baseHex) -> sets / clears SkinAnim, SkinPhase, SkinAnimBase and the CollectionService tag "SkinAnim"
-- v1.1 (Kepu 2026-11-24 18:31 "These animated skins are weak asf ... animated on the smallest panels"; 18:40 picks on
--   docs/mockups/animated_skins_v0.5/0.6.html: Void Matter "A · Body wave", Spectral "B · Full breathe", Element X "A · Body wave",
--   Prism "C · Big panels"; 18:45 "Remove opal and add all the new ones you suggested as they are", all four Robux 499):
--   * Whole-body animation: every block of the slots primary, secondary, limbs, belly, accent, mask (WHOLE) is Neon and animated
--     for Void Matter / Element X (kind "wave": a bright band nose to tail), Spectral ("breathe": all blocks together); Prism
--     ("rainbow") on the biggest 45% of the WHOLE blocks (SkinBig) plus its twinkle blocks; colours from the 1.0 pattern are the
--     dark base, SkinGlow / SkinHi the lit colours.
--   * New skins (EPIC 499, whole body, own motion): Glitch ("glitch": cyan / magenta flicker), Storm Front ("storm": lightning
--     flashes), Bloodline ("beat": double heartbeat from the chest), Hellfire ("fire": flames climbing from the feet).
--   * Opal removed (ORDER and SKINS; a saved "opal" now reads as Classic).
--   * tagModel also stores SkinZF (0 nose / tail .. 1 along the body), SkinYF (0 feet .. 1 top) and SkinBig (biggest 45% of the
--     WHOLE blocks by volume); partLook takes a 6th argument info = {big, yf}; setAnim also sets SkinGlow / SkinHi and re-adds
--     the tag so SkinFX re-reads a repainted block.
-- v1.2 (Kepu 2026-11-24 19:05 "Make prism $999 actually"): Prism moves from RARE 149 to LEGENDARY 999 (the 999 product). Now
--   RARE 149: Arctic, Sakura, Viper Gold, Void Matter; LEGENDARY 999: Gold Hunter, Obsidian Fang, Spectral, Element X, Prism.
-- v1.3 (Kepu 2026-11-24 19:07 "logical step ups ... non animated bland skins for the cheapest, then ones with neon/glowing a step
--   up, then animated at the highest"; prices "149 / 499 / 999" on the existing products; sorting confirmed): RARE 149 = bland
--   (no glowing body blocks): Arctic, Sakura, Viper Gold, Chrome. EPIC 499 = glowing (Neon on the body): Lava, Venom, Neon Circuit,
--   Gold Hunter, Obsidian Fang. LEGENDARY 999 = animated: Prism, Void Matter, Spectral, Element X, Glitch, Storm Front, Bloodline,
--   Hellfire. ORDER follows the tiers (cheapest first).
local CollectionService = game:GetService("CollectionService")

local US = {}
US.VERSION = "1.3" -- v1.3 price steps bland 149 / glowing 499 / animated 999 (v1.2 Prism 999; v1.1 whole-body animation)
US.VERSION = "1.4" -- v1.4 island streak unlocks (Zebra 10, Storm Front 25)
US.VERSION = "1.5" -- v1.5 streak skins claimed at the Quest Stand
US.VERSION = "1.6" -- v1.6 skin drop: 13 new skins (3 earn, 4 holiday earn, 6 Robux)
-- v1.6 (Kepu 2026-11-26 16:14 on mockup docs/mockups/skin_drop_v0.1.html: "A1-a3 should be free as well as the holiday ones" / "They're the ones to earn" / 16:15 "Okay let's build"; earn goals and the rest of the lineup: standing pick, recommended):
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
-- v1.5 (Quest Stand, plan docs/plans/QUEST_STAND_v1.0.md Task 3; Kepu 2026-11-26 "this is the only place where you can claim them",
--   picks "Claim at the stand", "Always claimable"): with US.STAND_CLAIMS (true) the Zebra and Storm Front unlocks get
--   claim = "stand" (SkinServer 1.7 no longer grants them by itself; QuestServer 1.0 grants them through SkinGrant when claimed) and
--   the text "10 / 25 kill streak on the island, claim at the Quest Stand". Progress (istreak) is unchanged. false = 1.4.
-- v1.4 (island kill streak, plan docs/plans/ISLAND_STREAK_v1.0.md Task 1; Kepu 2026-11-26 "a fire streak emblem once you go on a killing spree on the main island. 25 kills streak unlocks the
--   thunder storm skin. 10 kill streak unlocks the zebra"; roadmap D3 "Streak replaces old";
--   Storm Front "Earn only"): with US.ISLAND_STREAK_UNLOCKS (true) Zebra unlocks at a 10 kill streak on the island and Storm Front
--   at a 25 kill streak (earn stat "istreak" = stats.istreak, SkinServer / Lab: max(StatIslandBest, IslandStreak) from SkinStats
--   1.1). Storm Front is no longer a Robux skin (owners keep it); its look, anim and ORDER place are unchanged. false = 1.3.
US.ANIM_TAG = "SkinAnim"
US.DINOS = {"Raptor", "TRex", "Pachy", "Herrera", "Teno", "Therizino", "Dilo", "Troodon"}
US.DINO_NAMES = {Raptor = "RAPTOR", TRex = "T-REX", Pachy = "PACHY", Herrera = "HERRERA", Teno = "TENO", Therizino = "THERIZINO",
	Dilo = "DILO", Troodon = "TROODON"}

US.SLOT = {main = "primary", bands = "secondary", dark = "secondary", stripes = "secondary", dorsal = "secondary", back = "secondary",
	coat = "secondary", feathers = "secondary", plates = "secondary", belly = "belly", limbs = "limbs", claws = "claws",
	beak = "claws", eyes = "eyes", mask = "mask", stripe = "accent", dome = "accent", knobs = "accent", markings = "accent",
	tailbands = "accent", frill = "accent", scutes = "accent", crest = "accent", tailfan = "accent", mane = "accent",
	frillmark = "accent", headplate = "accent", horns = "accent", spikes = "accent", club = "accent"}
local BODY = {primary = true, secondary = true, limbs = true}
local WHOLE = {primary = true, secondary = true, limbs = true, belly = true, accent = true, mask = true} -- v1.1
US.WHOLE = WHOLE
US.MAT = {Neon = "Neon", Metal = "Metal", Glass = "Glass", Opal = "Glass", Ghost = "Glass", Slate = "Slate",
	SmoothPlastic = "SmoothPlastic", Foil = "Foil"}

-- ---------- pattern maths (mockup numbers) ----------
local function frac(x) return x - math.floor(x) end
local function hsh(a, b, c, s)
	return frac(math.sin(a * 12.9898 + b * 78.233 + c * 37.719 + (s or 0) * 4.123) * 43758.5453)
end
local function cell(lp, size, seed)
	return hsh(math.floor(lp.X / size), math.floor(lp.Y / size), math.floor(lp.Z / size), seed)
end
local function pick(l, r)
	return l[math.min(#l, math.max(1, math.floor(r * #l) + 1))]
end
local function ph(lp, seed) return cell(lp, 0.6, seed) end
US._hsh, US._cell = hsh, cell -- tests

-- ---------- skins (ORDER = the Lab's card order, Kepu's plan order) ----------
US.ORDER = {"classic", "desert", "riverstone", "canopy", "ghostbark", "zebra", "inkwar", "arctic", "sakura", "vipergold", "chrome",
	"lava", "venom", "circuit", "gold", "obsidianfang", "prism", "voidmatter", "spectral", "elementx", "glitch", "storm", "bloodline",
	"hellfire"} -- v1.3: by price step (v1.1: opal out; glitch, storm, bloodline, hellfire in)

local function earn(stat, need, text) return {kind = "earn", stat = stat, need = need, text = text} end
local function robux(rarity, price) return {kind = "robux", rarity = rarity, price = price} end

US.SKINS = {
	classic = {name = "Classic", unlock = {kind = "free"}, classic = true, sw = {"5E943E", "283A1E", "C9C98F", "2E8C82"}},
	desert = {name = "Desert Runner", unlock = earn("matches", 3, "Play 3 Arena matches"),
		cols = {primary = "C9A46A", secondary = "7A5530", limbs = "B08A55", belly = "EBDDB8", claws = "3B2A1C", accent = "C2552E",
			eyes = "F0C81E", mask = "7A5530"}},
	riverstone = {name = "Riverstone", unlock = earn("kills", 25, "Get 25 kills"),
		cols = {primary = "6F7F6A", secondary = "3C4A3E", belly = "C9CDB8", accent = "D8D4C0", mask = "4E6E78", limbs = "5A6658",
			claws = "2A2E2A", eyes = "D9A23A"}},
	canopy = {name = "Canopy", unlock = earn("wins", 5, "Win 5 Arena matches"),
		cols = {primary = "4F7A3A", secondary = "24391C", belly = "C8D49A", accent = "D9A23A", limbs = "3F6530", claws = "2A2A1E",
			eyes = "F0E04A", mask = "1D2A16"}},
	ghostbark = {name = "Ghost Bark", unlock = earn("kills", 100, "Get 100 kills"),
		cols = {primary = "D8D2C2", secondary = "4A4640", belly = "EFE9DA", accent = "2A2724", limbs = "C4BDAB", claws = "3A3530",
			eyes = "7FE9FF", mask = "5A554C"}, mats = {eyes = "Neon"}},
	zebra = {name = "Zebra", unlock = earn("wins", 15, "Win 15 Arena matches"),
		cols = {belly = "FFFFFF", claws = "111111", eyes = "E04A4A", mask = "111111", accent = "111111"}, sw = {"F4F4F4", "111111"},
		pattern = function(slot, lp)
			if not BODY[slot] then return nil end
			local z = lp.Z + math.sin(lp.Y * 2.2 + lp.X) * 0.4
			return (math.floor(z / 0.9) % 2 == 0) and "111111" or "F4F4F4"
		end},
	inkwar = {name = "Ink War", unlock = earn("best", 3, "Win 3 Arena matches in a row"),
		cols = {belly = "EDE3D3", claws = "141010", eyes = "FFFFFF", mask = "141010", accent = "141010"}, sw = {"C8231E", "141010", "EDE3D3"},
		pattern = function(slot, lp)
			if not BODY[slot] then return nil end
			return cell(lp, 1.3, 71) < 0.35 and "141010" or "C8231E"
		end},
	arctic = {name = "Arctic", unlock = robux("RARE", 149),
		cols = {primary = "E6EEF3", secondary = "7FA6C2", limbs = "C7D8E3", belly = "FFFFFF", claws = "3A4A57", accent = "3FB4E6",
			eyes = "7FE9FF", mask = "7FA6C2"}},
	sakura = {name = "Sakura", unlock = robux("RARE", 149),
		cols = {belly = "FFFFFF", claws = "5A3A44", eyes = "D9577E", mask = "D9577E", accent = "D9577E"}, sw = {"F6EFF2", "F48FB1", "D9577E"},
		pattern = function(slot, lp)
			if not BODY[slot] then return nil end
			if cell(lp, 0.9, 81) < 0.3 then return "F48FB1" end
			if cell(lp, 0.9, 82) < 0.15 then return "FFC6DA" end
			return "F6EFF2"
		end},
	vipergold = {name = "Viper Gold", unlock = robux("RARE", 149),
		cols = {belly = "F0D27A", claws = "1A1408", eyes = "6CFF4A", mask = "1A1408", accent = "1A1408"},
		mats = {eyes = "Neon", belly = "Metal"}, sw = {"D4A72C", "1A1408", "F0D27A"},
		pattern = function(slot, lp)
			if not BODY[slot] then return nil end
			if (math.floor(lp.Z / 0.8) + math.floor(lp.Y / 0.8)) % 3 == 0 then return "1A1408", "SmoothPlastic" end
			return "D4A72C", "Metal"
		end},
	prism = {name = "Prism", unlock = robux("LEGENDARY", 999), anim = true, glow = "FFFFFF", hi = "FFFFFF", -- v1.1 C · Big panels; v1.2: was RARE 149
		cols = {belly = "E8F6FF", claws = "9FB6D9", eyes = "FFFFFF", mask = "BFD8FF", accent = "D9C8FF"},
		mats = {eyes = "Neon", accent = "Glass", belly = "Glass", mask = "Glass"}, sw = {"DDF3FF", "C7E3FF", "F2E9FF", "BDEFF0"},
		pattern = function(slot, lp, info)
			if not WHOLE[slot] then return nil end
			local hex, mat
			if BODY[slot] then
				hex, mat = pick({"DDF3FF", "C7E3FF", "F2E9FF", "FFFFFF", "BDEFF0"}, cell(lp, 0.8, 21)), "Glass"
			else
				hex, mat = ({belly = "E8F6FF", accent = "D9C8FF", mask = "BFD8FF"})[slot], "Glass"
			end
			local tw = BODY[slot] and cell(lp, 0.6, 22) < 0.09
			if tw then return "FFFFFF", "Neon", "rainbow", ph(lp, 23) end
			if info and info.big then return hex, "Neon", "rainbow", 0 end
			return hex, mat
		end},
	voidmatter = {name = "Void Matter", unlock = robux("LEGENDARY", 999), anim = true, glow = "8A3CFF", hi = "C77DFF", -- v1.1 A · Body wave; v1.3: was RARE 149
		cols = {belly = "1A1228", claws = "07050B", eyes = "C77DFF", mask = "07050B"}, mats = {eyes = "Neon"},
		sw = {"0D0A14", "1A1228", "8A3CFF", "C77DFF"},
		pattern = function(slot, lp)
			if not WHOLE[slot] then return nil end
			local hex
			if slot == "belly" then hex = "1A1228"
			elseif slot == "mask" then hex = "07050B"
			elseif slot == "accent" or slot == "secondary" or cell(lp, 0.7, 31) < 0.22 then hex = "8A3CFF"
			else hex = "0D0A14" end
			return hex, "Neon", "wave", 0
		end},
	lava = {name = "Lava", unlock = robux("EPIC", 499),
		cols = {primary = "2E2524", secondary = "FF6A1A", limbs = "3D302E", belly = "5A3A30", claws = "120D0C", accent = "FFC832",
			eyes = "FF6A1A", mask = "FF6A1A"}, mats = {secondary = "Neon", accent = "Neon", eyes = "Neon", mask = "Neon"}},
	venom = {name = "Venom", unlock = robux("EPIC", 499),
		cols = {primary = "1E2420", secondary = "A6E22E", belly = "3A4438", accent = "7CFF4A", limbs = "2A3229", claws = "0D100D",
			eyes = "C6FF3A", mask = "121612"}, mats = {secondary = "Neon", accent = "Neon", eyes = "Neon", mask = "Neon"}},
	circuit = {name = "Neon Circuit", unlock = robux("EPIC", 499),
		cols = {belly = "22262E", claws = "0E1014", eyes = "33E1FF", mask = "0E1014"}, mats = {eyes = "Neon"}, sw = {"15171C", "33E1FF"},
		pattern = function(slot, lp)
			if slot == "accent" or slot == "secondary" then return "33E1FF", "Neon" end
			if not BODY[slot] then return nil end
			if frac(lp.Z / 2.4) < 0.12 then return "33E1FF", "Neon" end
			return "15171C", "SmoothPlastic"
		end},
	chrome = {name = "Chrome", unlock = robux("RARE", 149), -- v1.3: was EPIC 499
		cols = {belly = "9EA6B0", claws = "2A2E36", eyes = "FF3B3B", mask = "2A2E36", accent = "2A2E36"}, mats = {eyes = "Neon"},
		sw = {"D8DEE6", "6E7682", "2A2E36"},
		pattern = function(slot, lp)
			if not BODY[slot] then return nil end
			return slot == "secondary" and "6E7682" or "D8DEE6", "Metal"
		end},
	-- v1.1: four new whole-body skins (mockup v0.6, Kepu "add all the new ones you suggested as they are", Robux 499 each)
	glitch = {name = "Glitch", unlock = robux("LEGENDARY", 999), anim = true, -- v1.3: was EPIC 499
		cols = {eyes = "00F0FF", claws = "0E1218"}, mats = {eyes = "Neon"}, sw = {"101418", "00F0FF", "FF2BD6"},
		pattern = function(slot, lp)
			if not WHOLE[slot] then return nil end
			local r = ph(lp, 9)
			return r < 0.25 and "00F0FF" or (r < 0.4 and "FF2BD6" or "121822"), "Neon", "glitch", 0
		end},
	storm = {name = "Storm Front", unlock = robux("LEGENDARY", 999), anim = true, -- v1.3: was EPIC 499
		cols = {eyes = "FFF27A", claws = "1A1F2A"}, mats = {eyes = "Neon"}, sw = {"2A3140", "3A4458", "FFF27A"},
		pattern = function(slot, lp)
			if not WHOLE[slot] then return nil end
			local r = ph(lp, 9)
			return r < 0.2 and "3A5CB0" or (r < 0.6 and "2A3140" or "3A4458"), "Neon", "storm", 0
		end},
	bloodline = {name = "Bloodline", unlock = robux("LEGENDARY", 999), anim = true, -- v1.3: was EPIC 499
		cols = {eyes = "FF2A3A", claws = "140A0C"}, mats = {eyes = "Neon"}, sw = {"140A0C", "B0102A", "FF2A3A"},
		pattern = function(slot, lp)
			if not WHOLE[slot] then return nil end
			return ph(lp, 9) < 0.35 and "B0102A" or "140A0C", "Neon", "beat", 0
		end},
	hellfire = {name = "Hellfire", unlock = robux("LEGENDARY", 999), anim = true, -- v1.3: was EPIC 499
		cols = {eyes = "FFD23A", claws = "120D0C"}, mats = {eyes = "Neon"}, sw = {"1A1210", "C8231E", "FF6A1A", "FFD23A"},
		pattern = function(slot, lp, info)
			if not WHOLE[slot] then return nil end
			local yf = info and info.yf or 0.5
			return yf < 0.3 and "FF6A1A" or (yf < 0.6 and "C8231E" or "1A1210"), "Neon", "fire", 0
		end},
	gold = {name = "Gold Hunter", unlock = robux("EPIC", 499), -- v1.3: was LEGENDARY 999
		cols = {primary = "D4A72C", secondary = "7A5A10", limbs = "E6C25A", belly = "F5E4A8", claws = "3A2A08", accent = "FFF2B0",
			eyes = "FFFFFF", mask = "7A5A10"}, mats = {accent = "Neon", eyes = "Neon"}},
	obsidianfang = {name = "Obsidian Fang", unlock = robux("EPIC", 499), -- v1.3: was LEGENDARY 999
		cols = {primary = "141416", secondary = "2A2A2E", belly = "3A3A40", accent = "D0202A", limbs = "1E1E22", claws = "D4A72C",
			eyes = "FFD24A", mask = "0A0A0C"}, mats = {accent = "Neon", claws = "Foil", eyes = "Neon"}},
	spectral = {name = "Spectral", unlock = robux("LEGENDARY", 999), anim = true, glow = "3FC8FF", hi = "BFF6FF", -- v1.1 B · Full breathe
		cols = {belly = "BFE9FF", claws = "1B3A5C", eyes = "E6FBFF", mask = "1B3A5C"}, mats = {eyes = "Neon", belly = "Ghost"},
		sw = {"2A5C8A", "3C7DB5", "7FE9FF", "BFE9FF"},
		pattern = function(slot, lp)
			if not WHOLE[slot] then return nil end
			local hex
			if slot == "belly" then hex = "BFE9FF"
			elseif slot == "mask" then hex = "1B3A5C"
			elseif slot == "accent" or cell(lp, 0.75, 42) < 0.22 then hex = "7FE9FF"
			else hex = pick({"2A5C8A", "3C7DB5", "4F93CC"}, cell(lp, 1.0, 44)) end
			return hex, "Neon", "breathe", 0
		end},
	elementx = {name = "Element X", unlock = robux("LEGENDARY", 999), anim = true, glow = "5CFF6A", hi = "D2FFD0", -- v1.1 A · Body wave
		cols = {belly = "2E3A30", claws = "0F1410", eyes = "5CFF6A", mask = "0F1410"}, mats = {eyes = "Neon"},
		sw = {"1E2420", "2A302A", "5CFF6A"},
		pattern = function(slot, lp)
			if not WHOLE[slot] then return nil end
			local hex
			if slot == "belly" then hex = "2E3A30"
			elseif slot == "mask" then hex = "0F1410"
			elseif slot == "accent" or cell(lp, 0.9, 52) < 0.25 then hex = "5CFF6A"
			else hex = pick({"1E2420", "2A302A", "161A17"}, cell(lp, 1.1, 54)) end
			return hex, "Neon", "wave", 0
		end},
}
-- v1.6: skin drop (see the header)
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
US.ISLAND_STREAK_UNLOCKS = true -- v1.4
if US.ISLAND_STREAK_UNLOCKS then
	US.SKINS.zebra.unlock = earn("istreak", 10, "Get a 10 kill streak on the island")
	US.SKINS.storm.unlock = earn("istreak", 25, "Get a 25 kill streak on the island")
end
US.STAND_CLAIMS = true -- v1.5
if US.ISLAND_STREAK_UNLOCKS and US.STAND_CLAIMS then
	US.SKINS.zebra.unlock.claim = "stand"
	US.SKINS.zebra.unlock.text = "10 kill streak on the island, claim at the Quest Stand"
	US.SKINS.storm.unlock.claim = "stand"
	US.SKINS.storm.unlock.text = "25 kill streak on the island, claim at the Quest Stand"
end
for id, sk in pairs(US.SKINS) do
	sk.id = id
	if not sk.sw and sk.cols then
		sk.sw = {}
		for _, s in ipairs({"primary", "secondary", "belly", "accent"}) do
			if sk.cols[s] then table.insert(sk.sw, sk.cols[s]) end
		end
	end
end

US.OLD_TO_NEW = {classic = "classic", desert = "desert", arctic = "arctic", lava = "lava", gold = "gold",
	pachy_riverstone = "riverstone", herrera_canopy = "canopy", herrera_ghostbark = "ghostbark", herrera_venom = "venom",
	herrera_obsidian = "obsidianfang"}

function US.slotOf(role) return US.SLOT[role] end
function US.get(id) return type(id) == "string" and US.SKINS[id] or nil end
function US.fromOld(id)
	if type(id) ~= "string" then return nil end
	if US.SKINS[id] then return id end
	return US.OLD_TO_NEW[id]
end
function US.sanitize(id) return US.fromOld(id) or "classic" end
function US.owns(id, ownedSet, allUnlocked)
	local sk = US.get(id)
	if not sk then return false end
	if sk.unlock.kind == "free" or allUnlocked == true then return true end
	return type(ownedSet) == "table" and ownedSet[id] == true
end

-- stats = {w, l, kills, best}; earn stats: matches (w + l), wins (w), kills, best (best win streak)
function US.progress(id, stats)
	local sk = US.get(id)
	if not (sk and sk.unlock.kind == "earn") then return nil, nil end
	if not US.windowOpen(sk) then return 0, sk.unlock.need end -- v1.6: holiday skins only in their window
	stats = type(stats) == "table" and stats or {}
	local w, l = tonumber(stats.w) or 0, tonumber(stats.l) or 0
	local have = 0
	local s = sk.unlock.stat
	if s == "matches" then have = w + l
	elseif s == "wins" then have = w
	elseif s == "kills" then have = tonumber(stats.kills) or 0
	elseif s == "best" then have = tonumber(stats.best) or 0
	elseif s == "istreak" then have = tonumber(stats.istreak) or 0 end -- v1.4
	return math.min(have, sk.unlock.need), sk.unlock.need
end
function US.unlocked(id, stats)
	local have, need = US.progress(id, stats)
	return have ~= nil and have >= need
end

-- the look of one block: slot colour / material, then the pattern
function US.partLook(id, role, lp, baseHex, baseMat, info) -- v1.1: info = {big, yf}
	local sk = US.get(id)
	local slot = US.SLOT[role]
	if not sk or sk.classic or not slot then return baseHex, baseMat, nil, nil end
	local hex, mat = baseHex, baseMat
	if sk.cols and sk.cols[slot] then hex = sk.cols[slot] end
	if sk.mats and sk.mats[slot] then mat = sk.mats[slot] end
	local kind, phase
	if sk.pattern then
		local h, m, k, p = sk.pattern(slot, typeof(lp) == "Vector3" and lp or Vector3.zero, info)
		if h then
			hex = h
			if m then mat = m end
			kind, phase = k, p
		end
	end
	if mat and US.MAT[mat] then mat = US.MAT[mat] end
	if kind and mat ~= "Neon" then kind, phase = nil, nil end
	return hex, mat, kind, phase
end

-- ---------- Instance helpers ----------
local function hexOf(c3) return c3:ToHex():upper() end
-- tags every visible body block once: SkinRole (when its colour has a role), SkinBaseMaterial, SkinBaseHex, SkinLP.
-- skip(part) -> true to leave a part out (hitboxes, mech parts). roleOf = SkinCatalog.roleOf.
function US.tagModel(model, species, roleOf, skip)
	local hrp = model:FindFirstChild("HumanoidRootPart")
	local origin = (hrp and hrp:IsA("BasePart")) and hrp.CFrame or model:GetPivot()
	local fresh = {}
	local n = 0
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" and p.Transparency < 1 and not (skip and skip(p)) then
			if p:GetAttribute("SkinRole") == nil then
				local role = roleOf(species, p.Color)
				if role then
					p:SetAttribute("SkinRole", role)
					p:SetAttribute("SkinBaseMaterial", p.Material.Name)
				end
			end
			if p:GetAttribute("SkinRole") ~= nil then
				n += 1
				if p:GetAttribute("SkinLP") == nil then table.insert(fresh, p) end
			end
		end
	end
	if #fresh > 0 then
		-- scale: the longest side of all tagged blocks' centres -> 15 (as the mockup's models)
		local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
		local pos = {}
		for i, p in ipairs(fresh) do
			local v = origin:PointToObjectSpace(p.Position)
			pos[i] = v
			lo, hi = lo:Min(v), hi:Max(v)
		end
		local span = math.max(hi.X - lo.X, hi.Y - lo.Y, hi.Z - lo.Z, 1e-3)
		local k = 15 / span
		-- v1.1: SkinZF / SkinYF (0..1 along the body / up it) and SkinBig (biggest 45% of the WHOLE blocks)
		local zr, yr = math.max(hi.Z - lo.Z, 1e-3), math.max(hi.Y - lo.Y, 1e-3)
		local whole = {}
		for i, p in ipairs(fresh) do
			p:SetAttribute("SkinZF", (pos[i].Z - lo.Z) / zr)
			p:SetAttribute("SkinYF", (pos[i].Y - lo.Y) / yr)
			if WHOLE[US.SLOT[p:GetAttribute("SkinRole")] or ""] then table.insert(whole, p) end
		end
		table.sort(whole, function(a, b) return a.Size.X * a.Size.Y * a.Size.Z > b.Size.X * b.Size.Y * b.Size.Z end)
		local nBig = math.ceil(#whole * 0.45)
		for i, p in ipairs(whole) do p:SetAttribute("SkinBig", i <= nBig) end
		for i, p in ipairs(fresh) do
			p:SetAttribute("SkinLP", pos[i] * k)
			if p:GetAttribute("SkinBaseHex") == nil then
				-- the authored colour: a block already painted keeps the hex it was tagged with
				p:SetAttribute("SkinBaseHex", hexOf(p.Color))
			end
		end
	end
	return n
end

function US.setAnim(part, kind, phase, baseHex, glow, hi)
	if kind then
		part:SetAttribute("SkinAnim", kind)
		part:SetAttribute("SkinPhase", phase or 0)
		part:SetAttribute("SkinAnimBase", baseHex)
		part:SetAttribute("SkinGlow", glow) -- v1.1
		part:SetAttribute("SkinHi", hi) -- v1.1
		-- v1.1: re-add the tag so SkinFX reads the new look of a repainted block
		if CollectionService:HasTag(part, US.ANIM_TAG) then CollectionService:RemoveTag(part, US.ANIM_TAG) end
		CollectionService:AddTag(part, US.ANIM_TAG)
	elseif part:GetAttribute("SkinAnim") ~= nil then
		part:SetAttribute("SkinAnim", nil)
		part:SetAttribute("SkinPhase", nil)
		part:SetAttribute("SkinAnimBase", nil)
		part:SetAttribute("SkinGlow", nil)
		part:SetAttribute("SkinHi", nil)
		CollectionService:RemoveTag(part, US.ANIM_TAG)
	end
end

-- paints one model (every block with SkinRole); classicColors[role] = hex fallback when a block has no SkinBaseHex
function US.paintModel(model, id, classicColors)
	for _, p in ipairs(model:GetDescendants()) do
		local role = p:IsA("BasePart") and p:GetAttribute("SkinRole")
		if role then
			local base = p:GetAttribute("SkinBaseHex") or (classicColors and classicColors[role]) or hexOf(p.Color)
			local hex, mat, kind, phase = US.partLook(id, role, p:GetAttribute("SkinLP"), base, p:GetAttribute("SkinBaseMaterial"),
				{big = p:GetAttribute("SkinBig") == true, yf = p:GetAttribute("SkinYF")}) -- v1.1
			if hex then p.Color = Color3.fromHex(hex) end
			if type(mat) == "string" then
				local ok, m = pcall(function() return Enum.Material[mat] end)
				if ok and m then p.Material = m end
			end
			local sk = US.SKINS[id]
			US.setAnim(p, kind, phase, hex, sk and sk.glow, sk and sk.hi)
		end
	end
end

return US
