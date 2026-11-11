-- LabClipRecipesAll.spec v1.0 (Mecha Dino Arena) — LabClipRecipes 1.1: every live mecha part of every dino (plan
-- docs/plans/LAB_CLIPS_v1.0.md "Other dinos (v1.1)", MDA-447). Run in Studio Edit (clones StarterPlayerScripts.LabClipRecipes
-- and ServerStorage.DinoArcade.SkillTree); returns "PASS n" or "FAIL ...".
local DA = game:GetService("ServerStorage"):FindFirstChild("DinoArcade")
local src = game:GetService("StarterPlayer").StarterPlayerScripts:FindFirstChild("LabClipRecipes")
if not DA or not src then return "FAIL require: modules missing" end
local function load(m) local c = m:Clone() c.Parent = m.Parent local okR, r = pcall(require, c) c:Destroy() if not okR then error(r) end return r end
local R, ST = load(src), load(DA.SkillTree)
local fails, passes = {}, 0
local function ok(name, cond) if cond then passes += 1 else table.insert(fails, name) end end
local function eq(name, got, want) ok(("%s: got %s want %s"):format(name, tostring(got), tostring(want)), got == want) end

eq("version", R.VERSION, "1.1")
local KINDS = {
	shot = {}, burst = {}, cone = {}, ring = {}, dash = {}, lob = {}, self = {pump = true, over = true},
	throw = {mine = true, spike = true, boulder = true, goo = true, dome = true, wall = true, turret = true, lantern = true, heal = true},
	wave = {buff = true, mark = true, stomp = true, drag = true},
	buff = {heal = true, speed = true, cloak = true, smoke = true, scan = true, shield = true, front = true, free = true, drone = true, zone = true, lunge = true, fling = true},
	move = {boost = true, leap = true, glide = true},
	place = {pad = true, caltrops = true, portal = true},
}
local n = 0
for id, p in pairs(ST.PATHS) do
	if p.mech == true and not p.soon and p.dino ~= "none" then
		n += 1
		local r = R[id]
		ok("recipe " .. id, r ~= nil)
		if r then
			ok(id .. " what", type(r.what) == "string" and #r.what > 10 and #r.what <= 110)
			ok(id .. " template " .. tostring(r.template), R.TEMPLATES[r.template] == true and KINDS[r.template] ~= nil)
			local fx = r.fx or {}
			local kind = fx.kind or fx.mode or r.mode
			if r.template == "throw" or r.template == "wave" or r.template == "move" or r.template == "place" then
				ok(id .. " kind " .. tostring(kind), KINDS[r.template][kind] == true)
			elseif r.template == "buff" then
				ok(id .. " mode " .. tostring(kind), kind == "fling" or KINDS.buff[kind] == true)
			end
			ok(id .. " attach", r.attach == nil or typeof(r.attach) == "Vector3")
			eq(id .. " steps", #r.steps, 4)
			ok(id .. " chips", #r.chips >= 1 and #r.chips <= 4)
			for s = 1, 4 do
				for _, c in ipairs(r.chips) do ok(("%s step %d key %s"):format(id, s, c[2]), r.steps[s][c[2]] ~= nil) end
			end
			-- the chips never throw
			local okC = pcall(function() for s = 1, 4 do for o = 0, 4 do R.chips(r, s, o) end end end)
			ok(id .. " chips run", okC)
		end
	end
end
eq("live parts", n, 54)
-- the numbers the chips show are in the step texts (lower case)
local WANT = {
	adrenaline = {{"25%", "1.4x"}, {"34%"}, {"26% faster"}, {"stun"}},
	cloak = {{"3 s"}, {"4.1 s"}, {"35%"}, {"twice"}},
	scent = {{"60 studs", "8 s"}, {"81 studs"}, {"10.8 s"}, {"blood"}},
	screech = {{"200 studs", "1.1 s"}, {"270 studs"}, {"26% faster"}, {"30 damage"}},
	shield = {{"1.5 s", "half speed"}, {"stronger"}, {"shorter"}, {"2.77 s"}},
	thrusters = {{"1.37 s", "2x"}, {"2 charges"}, {"1.85 s"}, {"25-stud"}},
	traps = {{"60 studs", "3 charges", "25 damage"}, {"4 mines"}, {"36% faster"}, {"jam"}},
	bloodrush = {{"25%"}, {"25% harder"}, {"self-slow"}, {"x0.45"}},
	hookarm = {{"120 studs", "10 damage"}, {"160 studs"}, {"6 s"}, {"15 damage"}},
	ink = {{"120 studs", "2 s"}, {"160 studs"}, {"11 s"}, {"6 studs"}},
	mechalegs = {{"20%", "4.2 s"}, {"45%"}, {"2.73 s"}, {"double jump"}},
	medstation = {{"10%", "5 s"}, {"18 studs"}, {"7 s"}, {"10 s"}},
	servodash = {{"2x", "1 s"}, {"1.5 s"}, {"5.6 s"}, {"refills"}},
	tether = {{"180 studs", "4 s"}, {"5 s"}, {"10 s"}, {"5 studs"}},
	visor = {{"1.5 s"}, {"2 s"}, {"10 s"}, {"knocks the attacker back"}},
	breaker = {{"20 s"}, {"10 studs"}, {"14 s"}, {"1 s"}},
	caltrops = {{"6 razor spikes", "10-stud", "8 s"}, {"10 spikes", "14-stud"}, {"14 s"}, {"can't see"}},
	glider = {{"8 studs/s"}, {"drop attack"}, {"30%"}, {"bleed"}},
	goo = {{"21-stud", "5 s", "50%"}, {"29 studs"}, {"2 blobs"}, {"8 s"}},
	hadren = {{"25%", "1.4x"}, {"34%"}, {"26% faster"}, {"slash"}},
	quills = {{"5 quills", "4 damage", "80 studs", "20 s"}, {"6 quills"}, {"7 quills"}, {"8 quills"}},
	smoke = {{"28 studs", "4 s"}, {"6 s"}, {"25% faster"}, {"25%"}},
	strobe = {{"60°", "20 studs", "1 s"}, {"1.5 s"}, {"90°", "25 studs"}, {"20%"}},
	tbellow = {{"25 studs", "4 s"}, {"6 s"}, {"40 studs"}, {"stuns"}},
	tchallenge = {{"30 studs", "5 s"}, {"7 s"}, {"45 studs"}, {"20%"}},
	tgrab = {{"30 studs"}, {"45 studs"}, {"pachy"}, {"crashes"}},
	tleap = {{"40 studs", "4.2 s"}, {"55 studs"}, {"0.5 s"}, {"2 leaps"}},
	tmortar = {{"180 studs", "10-stud", "12 damage"}, {"14 studs"}, {"2 boulders"}, {"rubble"}},
	tmud = {{"3 hits", "8 s"}, {"4 hits"}, {"12 s"}, {"bursts"}},
	tstomp = {{"14-stud", "0.5 s", "6 damage"}, {"1 s"}, {"20 studs"}, {"50 stamina"}},
	zclock = {{"40%"}, {"30%"}, {"extra jump"}, {"slows"}},
	zdeflect = {{"1 s", "16 s"}, {"1.5 s", "boulders"}, {"2 s", "13 s"}, {"bounce"}},
	zfeather = {{"8 feather", "70-stud", "3 damage", "1 s"}, {"10 blades", "80 studs"}, {"2 s"}, {"12 blades", "100 studs"}},
	zgrapple = {{"30 studs", "2 charges", "4.2 s"}, {"40 studs"}, {"50 studs", "3 s"}, {"3 charges"}},
	zharvest = {{"30 studs", "3 s", "4/s"}, {"34 studs"}, {"4 s"}, {"38 studs", "5 s"}},
	zhook = {{"100 studs", "10 damage"}, {"130 studs"}, {"160 studs"}, {"stunned 1 s"}},
	zsnare = {{"120 studs", "1 s", "12 damage"}, {"2 bolas"}, {"2 s", "160 studs"}, {"3 bolas"}},
	obloom = {{"44 studs"}, {"4.05 s"}, {"54 studs"}, {"heal 5"}},
	oburst = {{"40 studs", "heal 20", "4 s", "18 s"}, {"5.4 s"}, {"13.3 s"}, {"54 studs"}},
	odome = {{"30 studs", "90 studs", "5 s", "25 s"}, {"6.75 s"}, {"18.5 s"}, {"121.5"}},
	olantern = {{"80 studs", "24 studs", "12 damage", "14 s"}, {"32.4"}, {"10.3 s"}, {"3 enemies"}},
	omender = {{"4 per second", "4 s", "20 s"}, {"5.4 s"}, {"14.8 s"}, {"moves on"}},
	oportal = {{"185 studs", "22 s", "61 s"}, {"250 studs"}, {"30 s"}, {"45 s"}},
	osapwall = {{"80 studs", "74 studs", "30 tall", "4.2 s"}, {"100 studs"}, {"5.8 s"}, {"8 s"}},
	osentry = {{"30 studs", "8 s", "20 damage", "22 s"}, {"10.8 s"}, {"16.3 s"}, {"twin"}},
	oshed = {{"1 s", "24 s"}, {"1.4 s"}, {"17.7 s"}, {"20 studs"}},
	osleep = {{"120 studs", "2.5 s", "12 s"}, {"3.4 s"}, {"8.9 s"}, {"splits"}},
}
local nw = 0
for id, rows in pairs(WANT) do
	nw += 1
	for s, list in ipairs(rows) do
		local text = string.lower(tostring(ST.PATHS[id] and ST.PATHS[id].steps[s]))
		for _, w in ipairs(list) do ok(("%s step %d text has '%s' (%s)"):format(id, s, w, text), string.find(text, string.lower(w), 1, true) ~= nil) end
	end
end
eq("checked parts", nw, 47)
-- a few recipe numbers against those texts
eq("screech r2", R.screech.steps[2].range, 270); eq("tleap star", R.tleap.steps[4].charges, 2); eq("odome star", R.odome.steps[4].dome, 121.5)
eq("osapwall lasts", R.osapwall.steps[4].lasts, 8); eq("zfeather fan4", R.zfeather.steps[4].reach, 100); eq("goo blobs3", R.goo.steps[3].blobs, 2)
-- units
eq("fmt %", R.fmt(25, "%"), "25%"); eq("fmt x", R.fmt(1.4, "x"), "1.4x"); eq("fmt /s", R.fmt(4, "/s"), "4/s")
eq("fmt str", R.fmt("6 s", ""), "6 s"); eq("fmt studs/s", R.fmt(8, "studs/s"), "8 studs/s")
local c = R.chips(R.hookarm, 3, 1)
eq("str up", c[3][2], "normal → 6 s"); eq("str up flag", c[3][3], true)
if #fails > 0 then return "FAIL " .. #fails .. ": " .. table.concat(fails, " | ") end
return "PASS " .. passes
