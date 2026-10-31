-- SkinCatalog v1.2 (Mecha Dino Arena) — dino skins: the colour roles of each dino and the skin list. MDA-105, plan
-- docs/plans/SKINS_v1.0.md Task 1, mockup docs/mockups/skins_lab_tab.html (Kepu 2026-10-30: skins picked in the Lab's
-- SKINS tab from the main menu; "whatever is chosen in the menu is what youre spawning with every time unless you choose
-- a different skin"; buying with Robux is the next plan). Pure: no Instance access. Used by SkinServer 1.0 (server) and,
-- through the copy SkinServer puts in ReplicatedStorage.SkinShared, by Lab 1.6 (client).
-- A skin is a palette swap: every visible block of a dino uses one of a few authored colours (RaptorModelData /
--   TRexModelData). ROLES[species][hex] names the role of each authored colour; a skin gives a colour (and optionally a
--   Material) per role. Colours listed in NEVER_PAINT (teeth, pupils / T-Rex eyes, mouths, the T-Rex eye shine, the
--   HumanoidRootPart) have no role and are never repainted. Hex values: 6 upper-case hex digits, no "#".
-- API:
--   roleOf(species, color3) -> role or nil (exact authored colour; unknown species / colour -> nil)
--   get(species, id) -> skin or nil; default(species) -> id of the first skin ("classic")
--   owns(species, id, ownedSet) -> true for a known skin that is free or has ownedSet[id] == true
--   sanitize(species, id) -> id when it is a known skin of that species, else the default
-- Skin: {id, name, rarity ("STARTER" / "COMMON" / "RARE" / "EPIC" / "LEGENDARY"), price (Robux shown on locked cards,
--   nil for free), free (owned by everyone), colors = {[role] = hex}, materials = {[role] = Enum.Material name} or nil}.
--   Classic = the authored colours (the default look; picking it is "no skin").
-- v1.1 (MDA-110, plan docs/plans/SKINS_BUY_v1.0.md Task 1; Kepu 2026-10-30: prices "149 / 499 / 999", one developer
--   product per price tier): prices RARE 149 (Arctic, Night Stalker), EPIC 499 (Lava, was 299), LEGENDARY 999 (Gold
--   Hunter, was 499). PRODUCTS[rarity] = developer product id (Rare Skin / Epic Skin / Legendary Skin, created by Kepu,
--   checked in Studio with GetProductInfo). productFor(species, id) -> the product of a paid skin's rarity or nil (free,
--   unknown, or a rarity with no product); rarityOfProduct(productId) -> rarity or nil (numbers only);
--   buyable(species, id) -> productFor(...) ~= nil.
-- v1.2 (plan docs/plans/PACHY_MODEL_v1.0.md Task 2; Kepu 2026-10-30: "these models were making from this point forward
--   have to be made with skins in mind"): Pachy colour groups (PachyModelData 1.0: main, stripes, belly, dome, knobs
--   (knob ring and the hidden spikes), mask, limbs, claws, eyes; pupils / mouth are never-paint) and its Classic skin.
--   Skin rule for every new dino: one hex per group, no hex shared, none equal to a never-paint colour.
-- v1.3 (plan docs/plans/PACHY_SKINS_v1.0.md Task 1, mockup docs/mockups/pachy_skins_options.html; Kepu 2026-10-30:
--   lineup "Same as raptor", "Pachy-own themes", ownership "Separate per dino", picks "All option A"): the pachy lineup
--   Classic, Riverstone (COMMON, free), Fossil (RARE 149), Thunderhead (RARE 149), Ember (EPIC 499), Obsidian Crown
--   (LEGENDARY 999). Ids carry the prefix "pachy_": the save's owned set is keyed by id only, so a raptor skin never
--   unlocks a pachy one. Prices / products are the existing rarity tiers. Raptor / T-Rex lists, roles and API unchanged.
local SkinCatalog = {}
SkinCatalog.Version = "1.3"

SkinCatalog.ROLES = {
	Raptor = {["5E943E"] = "main", ["283A1E"] = "bands", ["8FA046"] = "limbs", ["C9C98F"] = "belly", ["302824"] = "claws",
		["2E8C82"] = "stripe", ["F0C81E"] = "eyes"},
	TRex = {["666A4A"] = "main", ["50523A"] = "dark", ["B2A278"] = "belly"},
	Pachy = {["7A6A4E"] = "main", ["3E5A55"] = "stripes", ["C8B898"] = "belly", ["E6DCC4"] = "dome", ["8C7A5A"] = "knobs",
		["3F6F7A"] = "mask", ["5E5240"] = "limbs", ["2E2620"] = "claws", ["8A2A1E"] = "eyes"}, -- v1.2
}

SkinCatalog.NEVER_PAINT = {["E8E2D2"] = true, ["111111"] = true, ["963C3C"] = true, ["6E342E"] = true, ["F5F5F0"] = true,
	["A3A2A5"] = true}

SkinCatalog.RARITY_ORDER = {"STARTER", "COMMON", "RARE", "EPIC", "LEGENDARY"}

SkinCatalog.SKINS = {
	Raptor = {
		{id = "classic", name = "Classic", rarity = "STARTER", free = true,
			colors = {main = "5E943E", bands = "283A1E", limbs = "8FA046", belly = "C9C98F", claws = "302824", stripe = "2E8C82", eyes = "F0C81E"}},
		{id = "desert", name = "Desert Runner", rarity = "COMMON", free = true,
			colors = {main = "C9A46A", bands = "7A5530", limbs = "B08A55", belly = "EBDDB8", claws = "3B2A1C", stripe = "C2552E", eyes = "F0C81E"}},
		{id = "arctic", name = "Arctic", rarity = "RARE", price = 149, free = false,
			colors = {main = "E6EEF3", bands = "7FA6C2", limbs = "C7D8E3", belly = "FFFFFF", claws = "3A4A57", stripe = "3FB4E6", eyes = "7FE9FF"}},
		{id = "night", name = "Night Stalker", rarity = "RARE", price = 149, free = false,
			colors = {main = "22262B", bands = "0E1012", limbs = "33393F", belly = "4A5058", claws = "0B0C0D", stripe = "5FD16A", eyes = "5FD16A"},
			materials = {stripe = "Neon", eyes = "Neon"}},
		{id = "lava", name = "Lava", rarity = "EPIC", price = 499, free = false,
			colors = {main = "2E2524", bands = "FF6A1A", limbs = "3D302E", belly = "5A3A30", claws = "120D0C", stripe = "FFC832", eyes = "FF6A1A"},
			materials = {bands = "Neon", stripe = "Neon", eyes = "Neon"}},
		{id = "gold", name = "Gold Hunter", rarity = "LEGENDARY", price = 999, free = false,
			colors = {main = "D4A72C", bands = "7A5A10", limbs = "E6C25A", belly = "F5E4A8", claws = "3A2A08", stripe = "FFF2B0", eyes = "FFFFFF"},
			materials = {stripe = "Neon", eyes = "Neon"}},
	},
	TRex = {
		{id = "classic", name = "Classic", rarity = "STARTER", free = true,
			colors = {main = "666A4A", dark = "50523A", belly = "B2A278"}},
	},
	Pachy = { -- v1.2
		{id = "classic", name = "Classic", rarity = "STARTER", free = true,
			colors = {main = "7A6A4E", stripes = "3E5A55", belly = "C8B898", dome = "E6DCC4", knobs = "8C7A5A", mask = "3F6F7A",
				limbs = "5E5240", claws = "2E2620", eyes = "8A2A1E"}},
		-- v1.3: the pachy drop
		{id = "pachy_riverstone", name = "Riverstone", rarity = "COMMON", free = true,
			colors = {main = "6F7F6A", stripes = "3C4A3E", belly = "C9CDB8", dome = "D8D4C0", knobs = "8E9A84", mask = "4E6E78",
				limbs = "5A6658", claws = "2A2E2A", eyes = "D9A23A"}},
		{id = "pachy_fossil", name = "Fossil", rarity = "RARE", price = 149, free = false,
			colors = {main = "C9BFA4", stripes = "5A5246", belly = "E3DAC4", dome = "F2EAD2", knobs = "B8AE96", mask = "4A443A",
				limbs = "B5AA90", claws = "2B2722", eyes = "7A1E12"},
			materials = {dome = "Marble", knobs = "Marble"}},
		{id = "pachy_thunderhead", name = "Thunderhead", rarity = "RARE", price = 149, free = false,
			colors = {main = "4A5566", stripes = "FFD23F", belly = "9AA6B5", dome = "C9D3DF", knobs = "FFD23F", mask = "2C3440",
				limbs = "3A4452", claws = "1A1E24", eyes = "FFD23F"},
			materials = {stripes = "Neon", eyes = "Neon"}},
		{id = "pachy_ember", name = "Ember", rarity = "EPIC", price = 499, free = false,
			colors = {main = "2B2422", stripes = "FF6A1A", belly = "4A3530", dome = "3A2E2A", knobs = "FFB02E", mask = "FF6A1A",
				limbs = "352B28", claws = "0F0B0A", eyes = "FFB02E"},
			materials = {stripes = "Neon", knobs = "Neon", eyes = "Neon"}},
		{id = "pachy_obsidian", name = "Obsidian Crown", rarity = "LEGENDARY", price = 999, free = false,
			colors = {main = "151517", stripes = "D4A72C", belly = "2A2A2E", dome = "F2C14A", knobs = "FFE08A", mask = "D4A72C",
				limbs = "1F1F22", claws = "D4A72C", eyes = "FFE08A"},
			materials = {dome = "Foil", stripes = "Neon", knobs = "Neon", eyes = "Neon"}},
	},
}

function SkinCatalog.roleOf(species, color3)
	local roles = SkinCatalog.ROLES[species]
	if not roles or typeof(color3) ~= "Color3" then return nil end
	return roles[color3:ToHex():upper()]
end

function SkinCatalog.get(species, id)
	local list = SkinCatalog.SKINS[species]
	if not list or type(id) ~= "string" then return nil end
	for _, s in ipairs(list) do
		if s.id == id then return s end
	end
	return nil
end

function SkinCatalog.default(species)
	local list = SkinCatalog.SKINS[species]
	return list and list[1] and list[1].id or "classic"
end

function SkinCatalog.owns(species, id, ownedSet)
	local s = SkinCatalog.get(species, id)
	if not s then return false end
	if s.free == true then return true end
	return type(ownedSet) == "table" and ownedSet[id] == true
end

function SkinCatalog.sanitize(species, id)
	if SkinCatalog.get(species, id) then return id end
	return SkinCatalog.default(species)
end

-- v1.1: buying (one developer product per rarity)
SkinCatalog.PRODUCTS = {RARE = 3724102107, EPIC = 3724102265, LEGENDARY = 3724102407}

function SkinCatalog.productFor(species, id)
	local s = SkinCatalog.get(species, id)
	if not s or s.free == true then return nil end
	return SkinCatalog.PRODUCTS[s.rarity]
end

function SkinCatalog.rarityOfProduct(productId)
	if type(productId) ~= "number" then return nil end
	for rarity, pid in pairs(SkinCatalog.PRODUCTS) do
		if pid == productId then return rarity end
	end
	return nil
end

function SkinCatalog.buyable(species, id)
	return SkinCatalog.productFor(species, id) ~= nil
end

return SkinCatalog
