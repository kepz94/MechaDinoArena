-- SkinCatalog.spec v1.8 (Mecha Dino Arena) — tests for ServerStorage.DinoArcade.SkinCatalog (MDA-105, plan
-- docs/plans/SKINS_v1.0.md Task 1). Run in Studio Edit through execute_luau; returns "PASS n" or "FAIL ...". Requires a
-- fresh clone so a re-run in the same Studio session sees the installed source. Reads both model data modules to check
-- that every authored colour is a skin role or on the never-paint list.
-- v1.1 (MDA-110, plan docs/plans/SKINS_BUY_v1.0.md Task 1): prices 149 / 499 / 999, rarity products, productFor /
--   rarityOfProduct / buyable.
-- v1.2 (plan docs/plans/PACHY_MODEL_v1.0.md Task 2): Pachy colour groups — every PachyModelData colour (spikes too) is
--   a Pachy role or never-paint, no hex shared between Pachy roles, none equal to a never-paint colour, Pachy classic.
-- v1.3 (plan docs/plans/PACHY_SKINS_v1.0.md Task 1): the pachy lineup — 6 skins in order, pachy_ ids (no id shared with
--   another dino), prices / free, products by rarity, ownership separate from the raptor's.
-- v1.4 (plan docs/plans/HERRERA_MODEL_v1.0.md Task 2): Herrera colour groups — every HerreraModelData colour is a
--   Herrera role or never-paint, 10 roles, no hex shared, none never-paint, Herrera classic (Swamp olive) round trip.
-- v1.5 (plan docs/plans/HERRERA_SKINS_v1.0.md Task 1): the Herrera lineup — 6 skins in order, herrera_ ids (no id shared
--   with another dino), prices / free, products by rarity, per skin all 10 roles / no hex twice / no never-paint / valid
--   materials, ownership separate. SkinCatalog 1.5's ALL_UNLOCKED (group test) makes owns() true for every skin, so the
--   spec checks the flag is a boolean and then forces it false on its own test copy: the owns checks test the locked rules.
-- v1.6 (plan docs/plans/TENO_MODEL_v1.0.md Task 2, MDA-171): Teno colour groups — every TenoModelData colour is a Teno role
--   or never-paint, 10 roles, no hex shared, none never-paint, Teno classic (Goofy Noodle) round trip.
-- v1.7 (SkinCatalog 1.8, TenoModelData 1.3): the Teno hexes are the Old Gardener colours.
-- v1.8 (SkinCatalog 1.9; MDA-187 / 188 / 189 / 190): Troodon (Night Watcher), Therizino (Reaper), Zuul (Battering Ram) and
--   Dilo (Classic) colour groups: 10 roles each, no hex shared, none never-paint, every colour of its model data (loaded with
--   pcall: a missing module fails here, not by error) is a role or never-paint, Classic is the only skin and round-trips.
--   The Version check follows the catalog (1.9).
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
local UNLOCKED = SC.ALL_UNLOCKED -- v1.5: test copy only
SC.ALL_UNLOCKED = false
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

eq("Version", SC.Version, "1.9") -- v1.8 (was "1.7")
eq("ALL_UNLOCKED is a boolean", type(UNLOCKED), "boolean") -- v1.5

-- roles of the authored colours
local RAPTOR = {["5E943E"] = "main", ["283A1E"] = "bands", ["8FA046"] = "limbs", ["C9C98F"] = "belly", ["302824"] = "claws",
	["2E8C82"] = "stripe", ["F0C81E"] = "eyes"}
local TREX = {["666A4A"] = "main", ["50523A"] = "dark", ["B2A278"] = "belly"}
local PACHY = {["7A6A4E"] = "main", ["3E5A55"] = "stripes", ["C8B898"] = "belly", ["E6DCC4"] = "dome", ["8C7A5A"] = "knobs",
	["3F6F7A"] = "mask", ["5E5240"] = "limbs", ["2E2620"] = "claws", ["8A2A1E"] = "eyes"} -- v1.2
local HERRERA = {["6E6A3A"] = "main", ["2F3320"] = "stripes", ["D3C89A"] = "belly", ["B8414A"] = "markings",
	["5A5530"] = "limbs", ["2C2620"] = "claws", ["E8C547"] = "eyes", ["B9B26A"] = "tailbands", ["262A1A"] = "mask",
	["C9572E"] = "frill"} -- v1.4
local TENO = {["8A7350"] = "main", ["5A4632"] = "dorsal", ["D8C7A0"] = "belly", ["4A3A2A"] = "bands", ["6E5A3E"] = "limbs",
	["2E2620"] = "claws", ["D9A23A"] = "eyes", ["3A332C"] = "beak", ["6B5236"] = "scutes", ["B89A6A"] = "mask"} -- v1.7 (v1.6: Goofy Noodle)
for h, role in pairs(RAPTOR) do eq("Raptor role " .. h, SC.roleOf("Raptor", Color3.fromHex(h)), role) end
for h, role in pairs(TREX) do eq("TRex role " .. h, SC.roleOf("TRex", Color3.fromHex(h)), role) end
for h, role in pairs(PACHY) do eq("Pachy role " .. h, SC.roleOf("Pachy", Color3.fromHex(h)), role) end -- v1.2
for h, role in pairs(HERRERA) do eq("Herrera role " .. h, SC.roleOf("Herrera", Color3.fromHex(h)), role) end -- v1.4
for h, role in pairs(TENO) do eq("Teno role " .. h, SC.roleOf("Teno", Color3.fromHex(h)), role) end -- v1.6
for species, count in pairs({Pachy = 9, Herrera = 10, Teno = 10}) do -- v1.2: skin rule for new dinos (v1.4: + Herrera)
	local seen, roles = {}, 0
	for h, role in pairs((SC.ROLES or {})[species] or {}) do
		roles += 1
		eq(species .. " hex " .. h .. " used once", seen[h], nil)
		seen[h] = role
		eq(species .. " hex " .. h .. " not never-paint", SC.NEVER_PAINT[h], nil)
	end
	eq(species .. " roles", roles, count)
end
eq("unknown colour -> nil", SC.roleOf("Raptor", Color3.fromRGB(1, 2, 3)), nil)
eq("teeth never painted", SC.roleOf("Raptor", Color3.fromHex("E8E2D2")), nil)
eq("unknown species -> nil", SC.roleOf("Stego", Color3.fromHex("5E943E")), nil)
eq("raptor colour on a T-Rex -> nil", SC.roleOf("TRex", Color3.fromHex("5E943E")), nil)

-- every authored colour is a role or never-paint: the raptor from RaptorModelData, the T-Rex from the StarterCharacter
-- (TRexModelData is not installed in Studio; the StarterCharacter is the live T-Rex body)
local authored = {Raptor = {}, TRex = {}, Pachy = {}, Herrera = {}, Teno = {}} -- v1.2: Pachy from PachyModelData (spikes included); v1.4 Herrera
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
	local hd = data("HerreraModelData") -- v1.4
	for _, seg in ipairs(hd.segments) do
		for _, p in ipairs(seg.parts) do authored.Herrera[p.color:upper()] = true end
	end
	local td = data("TenoModelData") -- v1.6
	for _, seg in ipairs(td.segments) do
		for _, p in ipairs(seg.parts) do authored.Teno[p.color:upper()] = true end
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
for species, roles in pairs({Raptor = RAPTOR, TRex = TREX, Pachy = PACHY, Herrera = HERRERA, Teno = TENO}) do
	local list = SC.SKINS[species]
	eq(species .. " has skins", type(list) == "table" and #list > 0, true)
	if type(list) ~= "table" or #list == 0 then continue end -- v1.4: a missing species list fails above, not by error
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

-- v1.5: Herrera lineup
do
	local want = {
		{"classic", "STARTER", nil}, {"herrera_canopy", "COMMON", nil}, {"herrera_bloodmoon", "RARE", 149},
		{"herrera_ghostbark", "RARE", 149}, {"herrera_venom", "EPIC", 499}, {"herrera_obsidian", "LEGENDARY", 999},
	}
	local ROLES = {"main", "stripes", "belly", "markings", "limbs", "claws", "eyes", "tailbands", "mask", "frill"}
	local list = SC.SKINS.Herrera or {}
	eq("herrera skins", #list, 6)
	for i, w in ipairs(want) do
		local s = list[i] or {}
		eq("herrera order " .. i, s.id, w[1])
		eq("herrera rarity " .. w[1], s.rarity, w[2])
		eq("herrera price " .. w[1], s.price, w[3])
		eq("herrera free " .. w[1], s.free == true, w[3] == nil)
		eq("herrera product " .. w[1], SC.productFor("Herrera", w[1]), w[3] and SC.PRODUCTS[w[2]] or nil)
		local seen, ok10 = {}, 0
		for _, r in ipairs(ROLES) do
			local h = s.colors and s.colors[r]
			if type(h) == "string" and h:match("^%x%x%x%x%x%x$") and h == h:upper() then ok10 += 1 end
			if h then
				eq("herrera " .. w[1] .. " " .. r .. " not never-paint", SC.NEVER_PAINT[h], nil)
				eq("herrera " .. w[1] .. " " .. r .. " hex once", seen[h], nil)
				seen[h] = r
			end
		end
		eq("herrera " .. w[1] .. " 10 roles", ok10, 10)
		for r, m in pairs(s.materials or {}) do
			eq("herrera " .. w[1] .. " material " .. r, (pcall(function() return Enum.Material[m] end)), true)
		end
	end
	local other = {}
	for _, sp in ipairs({"Raptor", "TRex", "Pachy"}) do for _, s in ipairs(SC.SKINS[sp]) do other[s.id] = sp end end
	for _, s in ipairs(list) do
		if s.id ~= "classic" then
			eq("herrera id prefix " .. s.id, s.id:sub(1, 8), "herrera_")
			eq("herrera id not shared " .. s.id, other[s.id], nil)
		end
	end
	eq("herrera owns separate", SC.owns("Herrera", "herrera_bloodmoon", {pachy_fossil = true, arctic = true}), false)
	eq("herrera owns owned", SC.owns("Herrera", "herrera_bloodmoon", {herrera_bloodmoon = true}), true)
	eq("herrera owns free", SC.owns("Herrera", "herrera_canopy", {}), true)
	eq("herrera sanitize pachy id", SC.sanitize("Herrera", "pachy_ember"), "classic")
end


-- v1.8: the four model-only dinos (SkinCatalog 1.9)
local NEW = {
	Troodon = {model = "TroodonModelData", roles = {["4E4A44"] = "main", ["2A2622"] = "stripes", ["B8AE98"] = "belly",
		["3C3833"] = "feathers", ["6B5A48"] = "crest", ["3A3632"] = "limbs", ["1C1A18"] = "claws", ["F0A62A"] = "eyes",
		["1E1C1A"] = "mask", ["8C7E6A"] = "tailfan"}},
	Therizino = {model = "TherizinoModelData", roles = {["3E3B38"] = "main", ["2A2826"] = "back", ["8C857A"] = "belly",
		["4A4642"] = "coat", ["6E6A64"] = "mane", ["2F2D2B"] = "limbs", ["E2DCCB"] = "claws", ["F2C83A"] = "eyes",
		["1E1C1B"] = "beak", ["161514"] = "mask"}},
	Zuul = {model = "ZuulModelData", roles = {["B08A62"] = "main", ["8E6A48"] = "plates", ["E2C8A0"] = "spikes",
		["D6C4A0"] = "belly", ["9A7650"] = "headplate", ["F0DCB8"] = "horns", ["7A5A3E"] = "limbs", ["2E2620"] = "claws",
		["D8A030"] = "eyes", ["6A4C34"] = "club"}},
	Dilo = {model = "DiloModelData", roles = {["6E7A3A"] = "main", ["3A3F22"] = "stripes", ["D8D0A0"] = "belly",
		["C8362E"] = "frill", ["E2C23A"] = "frillmark", ["C24A2A"] = "crest", ["5A6430"] = "limbs", ["2C2822"] = "claws",
		["F0E04A"] = "eyes", ["1C1C1A"] = "mask"}},
}
for species, def in pairs(NEW) do
	local n, seenRole = 0, {}
	for h, role in pairs(def.roles) do
		n += 1
		eq(species .. " role " .. h, SC.roleOf(species, Color3.fromHex(h)), role)
		eq(species .. " " .. h .. " not never-paint", SC.NEVER_PAINT[h], nil)
		eq(species .. " role name " .. role .. " once", seenRole[role], nil)
		seenRole[role] = true
	end
	eq(species .. " test roles", n, 10)
	local have = 0
	for _ in pairs((SC.ROLES or {})[species] or {}) do have += 1 end
	eq(species .. " roles", have, 10)
	local okD, d = pcall(data, def.model)
	eq(species .. " model data loads", okD, true)
	if okD then
		local cols = 0
		for _, seg in ipairs(d.segments) do
			for _, p in ipairs(seg.parts) do
				cols += 1
				local h = p.color:upper()
				local covered = (SC.ROLES[species] or {})[h] ~= nil or SC.NEVER_PAINT[h] == true
				if not covered then eq(species .. " colour " .. h .. " covered", covered, true) end
			end
		end
		eq(species .. " has parts", cols > 0, true)
	end
	local list = SC.SKINS[species]
	eq(species .. " one skin", type(list) == "table" and #list, 1)
	eq(species .. " default", SC.default(species), "classic")
	local classic = SC.get(species, "classic")
	eq(species .. " classic free", classic and classic.free, true)
	for h, role in pairs(def.roles) do
		eq(species .. " classic round trip " .. role, classic and classic.colors[role] and classic.colors[role]:upper(), h)
	end
	eq(species .. " sanitize other", SC.sanitize(species, "pachy_ember"), "classic")
end
eq("teno unchanged", SC.roleOf("Teno", Color3.fromHex("8A7350")), "main")
eq("raptor unchanged", SC.roleOf("Raptor", Color3.fromHex("5E943E")), "main")
eq("troodon colour on raptor -> nil", SC.roleOf("Raptor", Color3.fromHex("4E4A44")), nil)

if #fails > 0 then return "FAIL " .. #fails .. " / " .. (passes + #fails) .. ": " .. table.concat(fails, "; ") end
return "PASS " .. passes
