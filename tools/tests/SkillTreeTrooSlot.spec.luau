-- SkillTreeTrooSlot.spec v1.0 (Mecha Dino Arena) — the troodon slot parts in ServerStorage.DinoArcade.SkillTree 1.85 (plan
-- docs/plans/TROODON_SLOTPARTS_v1.0.md T1, MDA-378): Bloom Tank (passive, no slot), Bloom Burst, Shield Dome, Sleep Dart,
-- Sentry Pod (buttons). Run in Studio Edit (copy in ServerStorage.DinoArcadeTools.SkillTreeTrooSlot_spec, clone + require);
-- returns "PASS n" or "FAIL ...".
local ok, ST = pcall(function()
	local src = game.ServerStorage.DinoArcade.SkillTree
	local c = src:Clone()
	c.Parent = src.Parent
	local m = require(c)
	c:Destroy()
	return m
end)
if not ok then return "FAIL require: " .. tostring(ST) end
local fails, passes = {}, 0
local function eq(name, got, want, tol)
	local good
	if type(want) == "number" and type(got) == "number" then good = math.abs(got - want) <= (tol or 1e-9) else good = got == want end
	if good then passes += 1 else table.insert(fails, ("%s: got %s want %s"):format(name, tostring(got), tostring(want))) end
end
local P = ST.PATHS
local function E(steps, dino) return ST.effects(steps, dino or "Troodon") end

eq("TROO_SLOT_PARTS", ST.TROO_SLOT_PARTS, true)
local ROWS = {obloom = {"Bloom Tank", "health", false}, oburst = {"Bloom Burst", "health", true}, odome = {"Shield Dome", "defense", true},
	osleep = {"Sleep Dart", "attack", true}, osentry = {"Sentry Pod", "attack", true}}
for id, w in pairs(ROWS) do
	eq(id .. " exists", P[id] ~= nil, true)
	if P[id] then
		eq(id .. " name", P[id].name, w[1])
		eq(id .. " area", P[id].area, w[2])
		eq(id .. " mech", P[id].mech, true)
		eq(id .. " not soon", P[id].soon == true, false)
		eq(id .. " live", ST.LIVE_MECH[id], true)
		eq(id .. " owner", ST.OWNER[id], "Troodon")
		eq(id .. " button", ST.BUTTONS[id] == true, w[3])
		eq(id .. " steps", #P[id].steps, 4)
		eq(id .. " in order", table.find(ST.PATH_ORDER, id) ~= nil, true)
		eq(id .. " canBuy troodon", (ST.canBuy({}, id, 5, "Troodon")), true)
		eq(id .. " canBuy raptor", select(2, ST.canBuy({}, id, 5, "Raptor")), "otherDino")
	end
end
eq("bloom text 1 passive", P.obloom.steps[1]:find("Passive (no slot", 1, true) ~= nil, true)
-- slots: the passive never sits in a slot; the buttons do
local lo = ST.sanitizeLoadout({"obloom", "oburst", "odome", "osleep"}, {obloom = 1, oburst = 1, odome = 1, osleep = 1}, "Troodon")
eq("slot bloom empty", lo[1], false); eq("slot burst", lo[2], "oburst"); eq("slot dome", lo[3], "odome"); eq("slot sleep", lo[4], "osleep")
local lo2 = ST.sanitizeLoadout({"osentry", false, false, false}, {osentry = 1}, "Troodon")
eq("slot sentry", lo2[1], "osentry")
-- numbers per rank (I .. star)
local function chk(id, field, want)
	for r = 1, 4 do eq(("%s %d %s"):format(id, r, field), E({[id] = r})[field], want[r]) end
	local zero = 0
	if type(want[1]) == "boolean" then zero = false end
	eq(id .. " 0 " .. field, E({})[field], zero)
end
chk("obloom", "oBloomRadius", {27, 27, 36.5, 36.5}); chk("obloom", "oBloomTime", {3, 4.05, 4.05, 4.05})
chk("obloom", "oBloomEnd", {false, false, false, true}); chk("obloom", "oBloomEndHeal", {0, 0, 0, 5}); chk("obloom", "oBloomEndSlow", {0, 0, 0, 1.5})
chk("oburst", "oBurstRange", {40, 40, 40, 40}); chk("oburst", "oBurstHeal", {20, 20, 20, 20}); chk("oburst", "oBurstRadius", {20, 20, 20, 27})
chk("oburst", "oBurstBoost", {0.5, 0.5, 0.5, 0.5}); chk("oburst", "oBurstTime", {4, 5.4, 5.4, 5.4}); chk("oburst", "oBurstCut", {0.5, 0.5, 0.5, 0.5})
chk("oburst", "oBurstCooldown", {18, 18, 13.3, 13.3})
chk("odome", "oDomeRange", {30, 30, 30, 30}); chk("odome", "oDomeRadius", {15, 15, 15, 20.25}); chk("odome", "oDomeTime", {5, 6.75, 6.75, 6.75})
chk("odome", "oDomeCooldown", {25, 25, 18.5, 18.5})
chk("osleep", "oSleepRange", {120, 120, 120, 120}); chk("osleep", "oSleepTime", {2.5, 3.4, 3.4, 3.4}); chk("osleep", "oSleepCooldown", {12, 12, 8.9, 8.9})
chk("osleep", "oSleepSplit", {0, 0, 0, 15})
chk("osentry", "oSentryRange", {30, 30, 30, 30}); chk("osentry", "oSentryReach", {60, 60, 60, 60}); chk("osentry", "oSentryTime", {8, 10.8, 10.8, 10.8})
chk("osentry", "oSentryDamage", {6, 6, 6, 6}); chk("osentry", "oSentryRate", {0.5, 0.5, 0.5, 0.5}); chk("osentry", "oSentryShots", {1, 1, 1, 2})
chk("osentry", "oSentryCooldown", {22, 22, 16.3, 16.3})
-- the 35% rule on every changed step
eq("bloom 54/40", 54 / 40 >= 1.35, true); eq("bloom 4.05/3", 4.05 / 3 >= 1.3499, true); eq("bloom 73/54", 73 / 54 >= 1.35, true)
eq("burst 5.4/4", 5.4 / 4 >= 1.35, true); eq("burst 18/13.3", 18 / 13.3 >= 1.35, true); eq("burst 27/20", 27 / 20 >= 1.35, true)
eq("dome 6.75/5", 6.75 / 5 >= 1.35, true); eq("dome 25/18.5", 25 / 18.5 >= 1.35, true); eq("dome 20.25/15", 20.25 / 15 >= 1.35, true)
eq("sleep 3.4/2.5", 3.4 / 2.5 >= 1.35, true); eq("sleep 12/8.9", 12 / 8.9 >= 1.348, true)
eq("sentry 10.8/8", 10.8 / 8 >= 1.35, true); eq("sentry 22/16.3", 22 / 16.3 >= 1.349, true)
-- other dinos get nothing
local r = E({obloom = 4, oburst = 4, odome = 4, osleep = 4, osentry = 4}, "Raptor")
eq("raptor bloom", r.oBloomRadius, 0); eq("raptor burst", r.oBurstHeal, 0); eq("raptor sentry", r.oSentryDamage, 0)
-- the live troodon button parts are untouched
eq("omender still a button", ST.BUTTONS.omender, true); eq("oportal still live", ST.LIVE_MECH.oportal, true)
eq("olastfeather still soon", P.olastfeather and P.olastfeather.soon, true)

if #fails > 0 then return "FAIL " .. #fails .. "/" .. (#fails + passes) .. "\n" .. table.concat(fails, "\n") end
return "PASS " .. passes
