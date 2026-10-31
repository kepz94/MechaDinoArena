-- SkinCatalog.spec v1.3 (Mecha Dino Arena) — tests for ServerStorage.DinoArcade.SkinCatalog (MDA-105, plan
-- docs/plans/SKINS_v1.0.md Task 1). Run in Studio Edit through execute_luau; returns "PASS n" or "FAIL ...". Requires a
-- fresh clone so a re-run in the same Studio session sees the installed source. Reads both model data modules to check
-- that every authored colour is a skin role or on the never-paint list.
-- v1.1 (MDA-110, plan docs/plans/SKINS_BUY_v1.0.md Task 1): prices 149 / 499 / 999, rarity products, productFor /
--   rarityOfProduct / buyable.
-- v1.2 (plan docs/plans/PACHY_MODEL_v1.0.md Task 2): Pachy colour groups — every PachyModelData colour (spikes too) is
--   a Pachy role or never-paint, no hex shared between Pachy roles, none equal to a never-paint colour, Pachy classic.
-- v1.3 (plan docs/plans/PACHY_SKINS_v1.0.md Task 1): the pachy lineup — 6 skins in order, pachy_ ids (no id shared with
--   another dino), prices / free, products by rarity, ownership separate from the raptor's.
local da = game.ServerStorage:FindFirstChild("DinoArcade")
local ok, SC = pcall(function()
	local src = da.SkinCatalog
	local c = src:Clone()
	c.Parent = src.Parent
	local m = require(c)
	c:Destroy()
	return m
end)
if not ok then return "FAIL require: " .. tostring(SC) end
local function data(name)
	local src = da.Models[name]
	local c = src:Clone()
	c.Parent = src.Parent
	local m = require(c)
	c:Destroy()
	return m
end
local fails, passes = {}, 0
local function eq(name, got, want)
	if got == want then passes += 1 else table.insert(fails, ("%s: got %s want %s"):format(name, tostring(got), tostring(want))) end
end
local function hex(c3) return c3:ToHex():upper() end

eq("Version", SC.Version, "1.3")

-- roles of the authored colours
local RAPTOR = {["5E943E"] = "main", ["283A1E"] = "bands", ["8FA046"] = "limbs", ["C9C98F"] = "belly", ["302824"] = "claws",
	["2E8C82"] = "stripe", ["F0C81E"] = "eyes"}
local TREX = {["666A4A"] = "main", ["50523A"] = "dark", ["B2A278"] = "belly"}
local PACHY = {["7A6A4E"] = "main", ["3E5A55"] = "stripes", ["C8B898"] = "belly", ["E6DCC4"] = "dome", ["8C7A5A"] = "knobs",
	["3F6F7A"] = "mask", ["5E5240"] = "limbs", ["2E2620"] = "claws", ["8A2A1E"] = "eyes"} -- v1.2
for h, role in pairs(RAPTOR) do eq("Raptor role " .. h, SC.roleOf("Raptor", Color3.fromHex(h)), role) end
for h, role in pairs(TREX) do eq("TRex role " .. h, SC.roleOf("TRex", Color3.fromHex(h)), role) end
for h, role in pairs(PACHY) do eq("Pachy role " .. h, SC.roleOf("Pachy", Color3.fromHex(h)), role) end -- v1.2
do -- v1.2: skin rule for new dinos
	local seen, roles = {}, 0
	for h, role in pairs((SC.ROLES or {}).Pachy or {}) do
		roles += 1
		eq("Pachy hex " .. h .. " used once", seen[h], nil)
		seen[h] = role
		eq("Pachy hex " .. h .. " not never-paint", SC.NEVER_PAINT[h], nil)
	end
	eq("Pachy roles", roles, 9)
end
eq("unknown colour -> nil", SC.roleOf("Raptor", Color3.fromRGB(1, 2, 3)), nil)
eq("teeth never painted", SC.roleOf("Raptor", Color3.fromHex("E8E2D2")), nil)
eq("unknown species -> nil", SC.roleOf("Stego", Color3.fromHex("5E943E")), nil)
eq("raptor colour on a T-Rex -> nil", SC.roleOf("TRex", Color3.fromHex("5E943E")), nil)

-- every authored colour is a role or never-paint: the raptor from RaptorModelData, the T-Rex from the StarterCharacter
-- (TRexModelData is not installed in Studio; the StarterCharacter is the live T-Rex body)
local authored = {Raptor = {}, TRex = {}, Pachy = {}} -- v1.2: Pachy from PachyModelData (spikes included)
do
	local d = data("RaptorModelData")
	authored.Raptor[d.hrp.color:upper()] = true
	for _, seg in ipairs(d.segments) do
		for _, p in ipairs(seg.parts) do authored.Raptor[p.color:upper()] = true end
	end
	local pd = data("PachyModelData")
	for _, seg in ipairs(pd.segments) do
		for _, p in ipairs(seg.parts) do authored.Pachy[p.color:upper()] = true end
	end
	for _, p in ipairs(game.StarterPlayer.StarterCharacter:GetDescendants()) do
		if p:IsA("BasePart") and p.Transparency < 1 and p.Name ~= "HumanoidRootPart" and not p:FindFirstAncestor("Hitboxes") then
			authored.TRex[p.Color:ToHex():upper()] = true
		end
	end
end
for species, seen in pairs(authored) do
	local n = 0
	for h in pairs(seen) do
		n += 1
		local covered = (SC.ROLES[species] or {})[h] ~= nil or SC.NEVER_PAINT[h] == true
		eq(species .. " colour " .. h .. " covered", covered, true)
	end
	eq(species .. " has colours", n > 0, true)
end

-- skins
for species, roles in pairs({Raptor = RAPTOR, TRex = TREX, Pachy = PACHY}) do
	local list = SC.SKINS[species]
	eq(species .. " has skins", type(list) == "table" and #list > 0, true)
	eq(species .. " default", SC.default(species), "classic")
	eq(species .. " first = default", list[1].id, "classic")
	local classic = SC.get(species, "classic")
	for h, role in pairs(roles) do
		eq(species .. " classic round trip " .. role, classic.colors[role] and classic.colors[role]:upper(), h)
	end
	local ids = {}
	for _, s in ipairs(list) do
		eq(species .. " " .. s.id .. " unique", ids[s.id], nil)
		ids[s.id] = true
		eq(species .. " " .. s.id .. " name", type(s.name) == "string" and #s.name > 0, true)
		eq(species .. " " .. s.id .. " rarity", type(s.rarity) == "string", true)
		eq(species .. " " .. s.id .. " free or priced", s.free == true or type(s.price) == "number", true)
		for _, role in pairs(roles) do
			local v = s.colors[role]
			local good = type(v) == "string" and #v == 6 and v:match("^%x+$") ~= nil
			eq(species .. " " .. s.id .. " colour " .. role, good, true)
		end
		for role, mat in pairs(s.materials or {}) do
			local okMat = pcall(function() return Enum.Material[mat] end)
			eq(species .. " " .. s.id .. " material " .. role, okMat, true)
		end
	end
end
eq("raptor skins", #SC.SKINS.Raptor, 6)
eq("get unknown", SC.get("Raptor", "nope"), nil)
eq("get other species", SC.get("TRex", "lava"), nil)

-- sanitize / owns
eq("sanitize nil", SC.sanitize("Raptor", nil), "classic")
eq("sanitize unknown", SC.sanitize("Raptor", "nope"), "classic")
eq("sanitize known", SC.sanitize("Raptor", "lava"), "lava")
eq("sanitize number", SC.sanitize("Raptor", 5), "classic")
eq("owns free", SC.owns("Raptor", "desert", {}), true)
eq("owns locked", SC.owns("Raptor", "lava", {}), false)
eq("owns locked, owned", SC.owns("Raptor", "lava", {lava = true}), true)
eq("owns unknown", SC.owns("Raptor", "nope", {nope = true}), false)
eq("owns nil set", SC.owns("Raptor", "classic", nil), true)

-- v1.1: buying
local RARE, EPIC, LEG = 3724102107, 3724102265, 3724102407
eq("product RARE", SC.PRODUCTS and SC.PRODUCTS.RARE, RARE)
eq("product EPIC", SC.PRODUCTS and SC.PRODUCTS.EPIC, EPIC)
eq("product LEGENDARY", SC.PRODUCTS and SC.PRODUCTS.LEGENDARY, LEG)
for id, price in pairs({arctic = 149, night = 149, lava = 499, gold = 999}) do
	eq("price " .. id, SC.get("Raptor", id).price, price)
end
local okF = type(SC.productFor) == "function"
eq("productFor exists", okF, true)
if okF then
	eq("productFor classic", SC.productFor("Raptor", "classic"), nil)
	eq("productFor desert", SC.productFor("Raptor", "desert"), nil)
	eq("productFor arctic", SC.productFor("Raptor", "arctic"), RARE)
	eq("productFor night", SC.productFor("Raptor", "night"), RARE)
	eq("productFor lava", SC.productFor("Raptor", "lava"), EPIC)
	eq("productFor gold", SC.productFor("Raptor", "gold"), LEG)
	eq("productFor unknown", SC.productFor("Raptor", "nope"), nil)
	eq("productFor bad species", SC.productFor("Stego", "lava"), nil)
	eq("productFor TRex classic", SC.productFor("TRex", "classic"), nil)
end
local okR = type(SC.rarityOfProduct) == "function"
eq("rarityOfProduct exists", okR, true)
if okR then
	eq("rarityOfProduct RARE", SC.rarityOfProduct(RARE), "RARE")
	eq("rarityOfProduct EPIC", SC.rarityOfProduct(EPIC), "EPIC")
	eq("rarityOfProduct LEGENDARY", SC.rarityOfProduct(LEG), "LEGENDARY")
	eq("rarityOfProduct unknown", SC.rarityOfProduct(123), nil)
	eq("rarityOfProduct string", SC.rarityOfProduct(tostring(RARE)), nil)
end
local okB = type(SC.buyable) == "function"
eq("buyable exists", okB, true)
if okB then
	eq("buyable classic", SC.buyable("Raptor", "classic"), false)
	eq("buyable lava", SC.buyable("Raptor", "lava"), true)
	eq("buyable unknown", SC.buyable("Raptor", "nope"), false)
end

-- v1.3: pachy lineup
do
	local want = {
		{"classic", "STARTER", nil}, {"pachy_riverstone", "COMMON", nil}, {"pachy_fossil", "RARE", 149},
		{"pachy_thunderhead", "RARE", 149}, {"pachy_ember", "EPIC", 499}, {"pachy_obsidian", "LEGENDARY", 999},
	}
	local list = SC.SKINS.Pachy or {}
	eq("pachy skins", #list, 6)
	for i, w in ipairs(want) do
		local s = list[i] or {}
		eq("pachy order " .. i, s.id, w[1])
		eq("pachy rarity " .. w[1], s.rarity, w[2])
		eq("pachy price " .. w[1], s.price, w[3])
		eq("pachy free " .. w[1], s.free == true, w[3] == nil)
		eq("pachy product " .. w[1], SC.productFor("Pachy", w[1]), w[3] and SC.PRODUCTS[w[2]] or nil)
	end
	local other = {}
	for _, sp in ipairs({"Raptor", "TRex"}) do for _, s in ipairs(SC.SKINS[sp]) do other[s.id] = sp end end
	for _, s in ipairs(list) do
		if s.id ~= "classic" then
			eq("pachy id prefix " .. s.id, s.id:sub(1, 6), "pachy_")
			eq("pachy id not shared " .. s.id, other[s.id], nil)
		end
	end
	eq("pachy owns separate", SC.owns("Pachy", "pachy_fossil", {fossil = true, arctic = true}), false)
	eq("pachy owns owned", SC.owns("Pachy", "pachy_fossil", {pachy_fossil = true}), true)
	eq("pachy owns free", SC.owns("Pachy", "pachy_riverstone", {}), true)
	eq("pachy sanitize raptor id", SC.sanitize("Pachy", "lava"), "classic")
end

if #fails > 0 then return "FAIL " .. #fails .. " / " .. (passes + #fails) .. ": " .. table.concat(fails, "; ") end
return "PASS " .. passes
