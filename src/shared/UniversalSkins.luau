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
local CollectionService = game:GetService("CollectionService")

local US = {}
US.VERSION = "1.0"
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
US.ORDER = {"classic", "desert", "riverstone", "canopy", "ghostbark", "zebra", "inkwar", "arctic", "sakura", "vipergold", "prism",
	"voidmatter", "lava", "venom", "circuit", "chrome", "opal", "gold", "obsidianfang", "spectral", "elementx"}

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
	prism = {name = "Prism", unlock = robux("RARE", 149), anim = true,
		cols = {belly = "E8F6FF", claws = "9FB6D9", eyes = "FFFFFF", mask = "BFD8FF", accent = "D9C8FF"},
		mats = {eyes = "Neon", accent = "Glass", belly = "Glass", mask = "Glass"}, sw = {"DDF3FF", "C7E3FF", "F2E9FF", "BDEFF0"},
		pattern = function(slot, lp)
			if not BODY[slot] then return nil end
			if cell(lp, 0.6, 22) < 0.09 then return "FFFFFF", "Neon", "twinkle", ph(lp, 23) end
			return pick({"DDF3FF", "C7E3FF", "F2E9FF", "FFFFFF", "BDEFF0"}, cell(lp, 0.8, 21)), "Glass"
		end},
	voidmatter = {name = "Void Matter", unlock = robux("RARE", 149), anim = true,
		cols = {belly = "1A1228", claws = "07050B", eyes = "C77DFF", mask = "07050B"}, mats = {eyes = "Neon"},
		sw = {"0D0A14", "1A1228", "8A3CFF", "C77DFF"},
		pattern = function(slot, lp)
			if slot == "accent" then return "8A3CFF", "Neon", "pulse", ph(lp, 31) end
			if not BODY[slot] then return nil end
			if cell(lp, 0.7, 31) < 0.22 or slot == "secondary" then return "8A3CFF", "Neon", "pulse", ph(lp, 32) end
			return "0D0A14", "SmoothPlastic"
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
	chrome = {name = "Chrome", unlock = robux("EPIC", 499),
		cols = {belly = "9EA6B0", claws = "2A2E36", eyes = "FF3B3B", mask = "2A2E36", accent = "2A2E36"}, mats = {eyes = "Neon"},
		sw = {"D8DEE6", "6E7682", "2A2E36"},
		pattern = function(slot, lp)
			if not BODY[slot] then return nil end
			return slot == "secondary" and "6E7682" or "D8DEE6", "Metal"
		end},
	opal = {name = "Opal", unlock = robux("EPIC", 499), anim = true,
		cols = {belly = "FFF4F8", claws = "B8A9C9", eyes = "FFFFFF", mask = "D8C9F7"}, mats = {eyes = "Neon", belly = "Opal", mask = "Opal"},
		sw = {"F7C6D9", "C6F0E4", "D8C9F7", "FFE2C4"},
		pattern = function(slot, lp)
			if slot == "accent" then return "C6F0E4", "Neon", "hue", cell(lp, 0.6, 61) end
			if not BODY[slot] then return nil end
			return pick({"F7C6D9", "C6F0E4", "D8C9F7", "FFE2C4", "C9E6FF"}, cell(lp, 0.8, 62)), "Opal"
		end},
	gold = {name = "Gold Hunter", unlock = robux("LEGENDARY", 999),
		cols = {primary = "D4A72C", secondary = "7A5A10", limbs = "E6C25A", belly = "F5E4A8", claws = "3A2A08", accent = "FFF2B0",
			eyes = "FFFFFF", mask = "7A5A10"}, mats = {accent = "Neon", eyes = "Neon"}},
	obsidianfang = {name = "Obsidian Fang", unlock = robux("LEGENDARY", 999),
		cols = {primary = "141416", secondary = "2A2A2E", belly = "3A3A40", accent = "D0202A", limbs = "1E1E22", claws = "D4A72C",
			eyes = "FFD24A", mask = "0A0A0C"}, mats = {accent = "Neon", claws = "Foil", eyes = "Neon"}},
	spectral = {name = "Spectral", unlock = robux("LEGENDARY", 999), anim = true,
		cols = {belly = "BFE9FF", claws = "1B3A5C", eyes = "E6FBFF", mask = "1B3A5C"}, mats = {eyes = "Neon", belly = "Ghost"},
		sw = {"2A5C8A", "3C7DB5", "7FE9FF", "BFE9FF"},
		pattern = function(slot, lp)
			if slot == "accent" then return "7FE9FF", "Neon", "pulse", ph(lp, 41) end
			if not BODY[slot] then return nil end
			if cell(lp, 0.75, 42) < 0.22 then return "7FE9FF", "Neon", "pulse", ph(lp, 43) end
			return pick({"2A5C8A", "3C7DB5", "4F93CC"}, cell(lp, 1.0, 44)), "Ghost"
		end},
	elementx = {name = "Element X", unlock = robux("LEGENDARY", 999), anim = true,
		cols = {belly = "2E3A30", claws = "0F1410", eyes = "5CFF6A", mask = "0F1410"}, mats = {eyes = "Neon", belly = "Slate"},
		sw = {"1E2420", "2A302A", "5CFF6A"},
		pattern = function(slot, lp)
			if slot == "accent" then return "5CFF6A", "Neon", "pulse", ph(lp, 51) end
			if not BODY[slot] then return nil end
			if cell(lp, 0.9, 52) < 0.25 then return "5CFF6A", "Neon", "pulse", ph(lp, 53) end
			return pick({"1E2420", "2A302A", "161A17"}, cell(lp, 1.1, 54)), "Slate"
		end},
}
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
	stats = type(stats) == "table" and stats or {}
	local w, l = tonumber(stats.w) or 0, tonumber(stats.l) or 0
	local have = 0
	local s = sk.unlock.stat
	if s == "matches" then have = w + l
	elseif s == "wins" then have = w
	elseif s == "kills" then have = tonumber(stats.kills) or 0
	elseif s == "best" then have = tonumber(stats.best) or 0 end
	return math.min(have, sk.unlock.need), sk.unlock.need
end
function US.unlocked(id, stats)
	local have, need = US.progress(id, stats)
	return have ~= nil and have >= need
end

-- the look of one block: slot colour / material, then the pattern
function US.partLook(id, role, lp, baseHex, baseMat)
	local sk = US.get(id)
	local slot = US.SLOT[role]
	if not sk or sk.classic or not slot then return baseHex, baseMat, nil, nil end
	local hex, mat = baseHex, baseMat
	if sk.cols and sk.cols[slot] then hex = sk.cols[slot] end
	if sk.mats and sk.mats[slot] then mat = sk.mats[slot] end
	local kind, phase
	if sk.pattern then
		local h, m, k, p = sk.pattern(slot, typeof(lp) == "Vector3" and lp or Vector3.zero)
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

function US.setAnim(part, kind, phase, baseHex)
	if kind then
		part:SetAttribute("SkinAnim", kind)
		part:SetAttribute("SkinPhase", phase or 0)
		part:SetAttribute("SkinAnimBase", baseHex)
		if not CollectionService:HasTag(part, US.ANIM_TAG) then CollectionService:AddTag(part, US.ANIM_TAG) end
	elseif part:GetAttribute("SkinAnim") ~= nil then
		part:SetAttribute("SkinAnim", nil)
		part:SetAttribute("SkinPhase", nil)
		part:SetAttribute("SkinAnimBase", nil)
		CollectionService:RemoveTag(part, US.ANIM_TAG)
	end
end

-- paints one model (every block with SkinRole); classicColors[role] = hex fallback when a block has no SkinBaseHex
function US.paintModel(model, id, classicColors)
	for _, p in ipairs(model:GetDescendants()) do
		local role = p:IsA("BasePart") and p:GetAttribute("SkinRole")
		if role then
			local base = p:GetAttribute("SkinBaseHex") or (classicColors and classicColors[role]) or hexOf(p.Color)
			local hex, mat, kind, phase = US.partLook(id, role, p:GetAttribute("SkinLP"), base, p:GetAttribute("SkinBaseMaterial"))
			if hex then p.Color = Color3.fromHex(hex) end
			if type(mat) == "string" then
				local ok, m = pcall(function() return Enum.Material[mat] end)
				if ok and m then p.Material = m end
			end
			US.setAnim(p, kind, phase, hex)
		end
	end
end

return US
