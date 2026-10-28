-- StatSheet.spec v1.1 (Mecha Dino Arena) — tests for ServerStorage.DinoArcade.StatSheet (MDA-1, plan docs/plans/CLASSSTATS_v1.0.md).
-- Run in Studio Edit through execute_luau (copy in ServerStorage.DinoArcadeTools.StatSheet_spec); returns "PASS n" or "FAIL ...".
local ok, SS = pcall(function() return require(game.ServerStorage.DinoArcade.StatSheet) end)
if not ok then return "FAIL require: " .. tostring(SS) end
local fails, passes = {}, 0
local function eq(name, got, want, tol)
	local good
	if type(want) == "number" and type(got) == "number" then good = math.abs(got - want) <= (tol or 1e-9) else good = got == want end
	if good then passes += 1 else table.insert(fails, ("%s: got %s want %s"):format(name, tostring(got), tostring(want))) end
end

-- today's values (TRexModelData / RaptorModelData, DinoHealthServer 1.0)
local TREX = {MaxHealth = 200, BiteDamage = 25, MoveWalkSpeed = 20, MoveRunSpeed = 44, MoveCreepSpeed = 10}
local RAPTOR = {MaxHealth = 60, BiteDamage = 8, PounceLandDamage = 8, PounceTickDamage = 4, MoveWalkSpeed = 30, MoveRunSpeed = 52,
	MoveCreepSpeed = 10}

eq("Version", SS.Version, "1.1")
eq("STATS", table.concat(SS.STATS, ","), "Health,Attack,Defense,Speed,Support")
eq("MAX_ADDED", SS.MAX_ADDED, 10)
eq("HEALTH_PER_POINT", SS.HEALTH_PER_POINT, 15)
eq("ATTACK bite", SS.ATTACK_PER_POINT.BiteDamage, 2)
eq("ATTACK land", SS.ATTACK_PER_POINT.PounceLandDamage, 2)
eq("ATTACK tick", SS.ATTACK_PER_POINT.PounceTickDamage, 1)
eq("SPEED_RATE", SS.SPEED_RATE, 0.10)
eq("DEFENSE_RATE", SS.DEFENSE_RATE, 0.05)
-- sheets
eq("TRex class", SS.SPECIES.TRex.class, "Bulky")
eq("Raptor class", SS.SPECIES.Raptor.class, "Roamer")
local function sheet(sp) local s = SS.SPECIES[sp].start return ("%d/%d/%d/%d/%d"):format(s.Health, s.Attack, s.Defense, s.Speed, s.Support) end
eq("TRex start", sheet("TRex"), "9/7/7/4/1")
eq("Raptor start", sheet("Raptor"), "3/4/3/9/1")
eq("TRex abilities", table.concat(SS.SPECIES.TRex.abilities, ","), "Roar,Ram")
eq("Raptor abilities", table.concat(SS.SPECIES.Raptor.abilities, ","), "Pounce + latch,Jump")

-- 0 added = today's values exactly
local zero = SS.added("TRex", {})
for _, s in ipairs(SS.STATS) do eq("zero " .. s, zero[s], 0) end
local v = SS.values(TREX, zero)
for k, want in pairs(TREX) do eq("TRex 0 " .. k, v[k], want) end
eq("TRex 0 mul", v.StatDamageTakenMul, 1)
eq("TRex 0 no pounce key", v.PounceLandDamage, nil)
v = SS.values(RAPTOR, SS.added("Raptor", nil))
for k, want in pairs(RAPTOR) do eq("Raptor 0 " .. k, v[k], want) end
eq("Raptor 0 mul", v.StatDamageTakenMul, 1)

-- formula rows
v = SS.values(TREX, SS.added("TRex", {Health = 2}))
eq("TRex Health 2", v.MaxHealth, 230)
v = SS.values(RAPTOR, SS.added("Raptor", {Health = 2}))
eq("Raptor Health 2 (flat)", v.MaxHealth, 90)
v = SS.values(RAPTOR, SS.added("Raptor", {Attack = 2}))
eq("Raptor Attack 2 bite", v.BiteDamage, 12)
eq("Raptor Attack 2 land", v.PounceLandDamage, 12)
eq("Raptor Attack 2 tick", v.PounceTickDamage, 6)
v = SS.values(TREX, SS.added("TRex", {Attack = 2}))
eq("TRex Attack 2 bite", v.BiteDamage, 29)
v = SS.values(RAPTOR, SS.added("Raptor", {Speed = 1}))
eq("Raptor Speed 1 walk", v.MoveWalkSpeed, 33)
eq("Raptor Speed 1 run", v.MoveRunSpeed, 57.2, 1e-6)
eq("Raptor Speed 1 creep", v.MoveCreepSpeed, 11)
v = SS.values(TREX, SS.added("TRex", {Speed = 3}))
eq("TRex Speed 3 run", v.MoveRunSpeed, 57.2, 1e-6)
eq("TRex Speed 3 walk", v.MoveWalkSpeed, 26)
v = SS.values(TREX, SS.added("TRex", {Defense = 3}))
eq("Defense 3", v.StatDamageTakenMul, 0.85)
v = SS.values(TREX, SS.added("TRex", {Defense = 10}))
eq("Defense 10", v.StatDamageTakenMul, 0.5)
-- other stats untouched by one stat
v = SS.values(TREX, SS.added("TRex", {Defense = 3}))
eq("Defense leaves health", v.MaxHealth, 200)
eq("Defense leaves bite", v.BiteDamage, 25)

-- clamps
local a, c = SS.added("TRex", {Health = 12})
eq("cap 12 -> 10", a.Health, 10) eq("cap flag", c, true)
a, c = SS.added("Raptor", {Speed = 10})
eq("cap 10 stays", a.Speed, 10) eq("no flag at 10", c, false)
a, c = SS.added("Raptor", {Defense = -3})
eq("negative -> 0", a.Defense, 0) eq("negative flag", c, true)
a, c = SS.added("Raptor", {Attack = "x"})
eq("string -> 0", a.Attack, 0) eq("string flag", c, true)
a, c = SS.added("Raptor", {Attack = 2.7})
eq("2.7 -> 2", a.Attack, 2) eq("floor no flag", c, false)
a, c = SS.added("TRex", {Support = 4})
eq("Support -> 0", a.Support, 0) eq("Support flag", c, true)
a, c = SS.added("TRex", {Health = 1/0})
eq("inf -> 10", a.Health, 10) eq("inf flag", c, true)
a, c = SS.added("TRex", {Health = 0/0})
eq("nan -> 0", a.Health, 0) eq("nan flag", c, true)
-- points
local p = SS.points("Raptor", SS.added("Raptor", {Defense = 7}))
eq("points Defense 3+7", p.Defense, 10)
eq("points Speed 9", p.Speed, 9)
-- unknown species
a, c = SS.added("Stego", {Health = 1})
eq("unknown species nil", a, nil) eq("unknown flag", c, false)
eq("unknown points nil", SS.points("Stego", {}), nil)
-- v1.1: Speed cap 16, others 10
eq("MAX_ADDED_BY Speed", SS.MAX_ADDED_BY.Speed, 16)
a, c = SS.added("Raptor", {Speed = 16})
eq("Speed 16 stays", a.Speed, 16) eq("Speed 16 no flag", c, false)
a, c = SS.added("Raptor", {Speed = 20})
eq("Speed 20 -> 16", a.Speed, 16) eq("Speed 20 flag", c, true)
a, c = SS.added("TRex", {Attack = 12})
eq("Attack still 10", a.Attack, 10)
eq("Speed 16 run x2.6", SS.values({MoveRunSpeed = 44}, {Speed = 16}).MoveRunSpeed, 114.4, 1e-6)

if #fails > 0 then return "FAIL " .. #fails .. " (pass " .. passes .. ")\n" .. table.concat(fails, "\n") end
return "PASS " .. passes
