-- LabClipRecipes v1.0 (Mecha Dino Arena) — what each mecha part's Lab clip shows (ModuleScript, StarterPlayerScripts, next to
-- Lab; plan docs/plans/LAB_CLIPS_v1.0.md Task 2, MDA-442; Kepu 2026-11-11 "A · Live clip", "Built in the game", "Dilo
-- first, then the rest"). Pure data + 2 helpers: no instances, no services. Read by Lab 1.15 and LabClipPlayer 1.0.
-- One entry per path id:
--   what      one plain sentence (under the clip)
--   template  "burst" | "lob" | "cone" | "ring" | "self" | "dash" (LabClipPlayer draws it)
--   mode      template variant ("pump" / "over" for self)
--   attach    the part's centre in the dino's rest space (studs at Model scale 1, relative to the HumanoidRootPart, -Z =
--             forward; measured 2026-11-11 from DiloPartsServer's BuildPreview_<id> on a DiloModelData mannequin), used
--             when the part isn't on your dino
--   muzzle    where shots leave (same space; default = attach)
--   chips     {label, key, unit}; unit "studs" / "s" / "°" / "" / "bool" (YES / NO)
--   steps     4 tables of numbers (step I, II, III, ★) — the live numbers, the same as the SkillTree 1.89 step texts
-- Numbers here must change in the same commit as a part's tune (VERSIONS change checklist).
local R = {}
R.VERSION = "1.0"
R.VERSION = "1.1" -- v1.1 the other 6 dinos (47 parts)
-- v1.1 (MDA-447, plan docs/plans/LAB_CLIPS_v1.0.md "Other dinos (v1.1)"; Kepu 2026-11-11 15:37 "Looks great keep going with
--   other Dino's"): recipes for Raptor, Pachy, Herrera, Teno, Therizino and Troodon (every live mecha part), with an optional
--   fx table per recipe (what LabClipPlayer 1.1 draws). New units for fmt: "%" (25%), "x" (1.4x), "/s" (4/s). String values
--   ("normal", "6 s", "raptor") show as they are.

R.dgatling = {
	what = "Fires a quick burst of auto-aimed darts that poison whoever they hit.",
	template = "burst",
	attach = Vector3.new(0, 2.09, -2.8), muzzle = Vector3.new(0.72, 1.95, -3.48),
	chips = {{"DARTS", "darts", ""}, {"DAMAGE", "dmg", "each"}, {"RECHARGE", "cd", "s"}},
	steps = {{darts = 4, dmg = 3, cd = 12}, {darts = 6, dmg = 3, cd = 12}, {darts = 6, dmg = 3, cd = 10}, {darts = 8, dmg = 3, cd = 10}},
}
R.dmortar = {
	what = "Lobs a canister far ahead that leaves a poison cloud where it lands.",
	template = "lob",
	attach = Vector3.new(0.55, 0.37, -1.71), muzzle = Vector3.new(1.28, 1.91, -2.09),
	chips = {{"REACH", "reach", "studs"}, {"CLOUD", "cloud", "studs"}, {"LASTS", "lasts", "s"}, {"RECHARGE", "cd", "s"}},
	steps = {{reach = 80, cloud = 24, lasts = 3, cd = 16}, {reach = 100, cloud = 30, lasts = 3, cd = 16},
		{reach = 100, cloud = 30, lasts = 4, cd = 16}, {reach = 120, cloud = 36, lasts = 5, cd = 16}},
}
R.dhiss = {
	what = "Blasts a wide cone in front of you: dinos in it are knocked back and their mecha parts shut off.",
	template = "cone",
	attach = Vector3.new(-0.01, 2.64, -2.41),
	chips = {{"RANGE", "range", "studs"}, {"CONE", "cone", "°"}, {"SILENCE", "silence", "s"}, {"RECHARGE", "cd", "s"}},
	steps = {{range = 40, cone = 140, silence = 1.5, cd = 15}, {range = 50, cone = 140, silence = 1.5, cd = 15},
		{range = 50, cone = 140, silence = 2, cd = 12}, {range = 60, cone = 140, silence = 3, cd = 12}},
}
R.dspine = {
	what = "Fires spines out all around you, hitting every dino close by.",
	template = "ring",
	attach = Vector3.new(0, 2.63, -2.63),
	chips = {{"SPINES", "spines", ""}, {"DAMAGE", "dmg", "each"}, {"VENOM", "venom", "bool"}, {"RECHARGE", "cd", "s"}},
	steps = {{spines = 6, dmg = 4, venom = false, cd = 12}, {spines = 8, dmg = 4, venom = false, cd = 12},
		{spines = 8, dmg = 4, venom = true, cd = 12}, {spines = 12, dmg = 4, venom = true, cd = 12}},
}
R.dpump = {
	what = "Clears your debuffs and heals you.",
	template = "self", mode = "pump",
	attach = Vector3.new(0, 1.53, -0.24),
	chips = {{"HEAL", "heal", ""}, {"IMMUNE", "immune", "s"}, {"RECHARGE", "cd", "s"}},
	steps = {{heal = 15, immune = 0, cd = 20}, {heal = 20, immune = 0, cd = 20}, {heal = 30, immune = 0, cd = 20}, {heal = 30, immune = 4, cd = 20}},
}
R.djets = {
	what = "Dashes you a short way in the direction you're moving.",
	template = "dash",
	attach = Vector3.new(0, 0.97, 1.94), muzzle = Vector3.new(0, 1.1, 2.75),
	chips = {{"DASH", "dist", "studs"}, {"CHARGES", "charges", ""}, {"POISON TRAIL", "trail", "bool"}, {"RECHARGE", "cd", "s"}},
	steps = {{dist = 40, charges = 1, trail = false, cd = 4.2}, {dist = 50, charges = 2, trail = false, cd = 4.2},
		{dist = 65, charges = 2, trail = true, cd = 4.2}, {dist = 65, charges = 3, trail = true, cd = 4.2}},
}
R.dover = {
	what = "For a few seconds your spit never runs out and never has to wait.",
	template = "self", mode = "over",
	attach = Vector3.new(0, 0.71, -1.54), muzzle = Vector3.new(0, 2.7, -4.2),
	chips = {{"LASTS", "lasts", "s"}, {"DOUBLE VENOM", "double", "bool"}, {"RECHARGE", "cd", "s"}},
	steps = {{lasts = 4, double = false, cd = 30}, {lasts = 6, double = false, cd = 30}, {lasts = 6, double = true, cd = 30},
		{lasts = 8, double = true, cd = 30}},
}

-- ---------- v1.1: the other 6 dinos (MDA-447) ----------
-- Numbers = the live SkillTree 1.89 step texts (read in Studio 2026-11-11). Where a step text gives no number (for example
-- "Recharges 26% faster" with no base), the chip is a YES / NO flag instead of a made-up number. fx = what the clip shows
-- (LabClipPlayer 1.1 templates shot / throw / wave / buff / move / place; cone / burst / dash as for the dilo).
-- attach = measured from each part's BuildPreview on its dino's mannequin (rest space, scale 1).
local C3 = Color3.fromRGB
local function four(a, b, c, d) return {a, b, c, d} end
local function steps(keys) -- {key = {I, II, III, ★}} -> 4 step tables
	local out = {{}, {}, {}, {}}
	for k, v in pairs(keys) do for i = 1, 4 do out[i][k] = v[i] end end
	return out
end
local F, T = false, true

-- Raptor
R.adrenaline = {what = "Heals you over 3 seconds and makes you run faster while it lasts.", template = "buff",
	fx = {mode = "heal", starKey = "unstun", starText = "STUN ENDS"}, attach = Vector3.new(0, 1.09, -1.94),
	chips = {{"HEAL", "heal", "%"}, {"SPEED", "speed", "x"}, {"FASTER RECHARGE", "faster", "bool"}, {"ENDS A STUN", "unstun", "bool"}},
	steps = steps({heal = four(25, 34, 34, 34), speed = four(1.4, 1.4, 1.4, 1.4), faster = four(F, F, T, T), unstun = four(F, F, F, T)})}
R.cloak = {what = "Makes you nearly invisible for a few seconds; bots lose track of you.", template = "buff",
	fx = {mode = "cloak", text = "CLOAKED %s s"}, attach = Vector3.new(0, 0.39, -0.89),
	chips = {{"LASTS", "lasts", "s"}, {"AMBUSH +35%", "ambush", "bool"}, {"STAND STILL x2", "still", "bool"}},
	steps = steps({lasts = four(3, 4.1, 4.1, 4.1), ambush = four(F, F, T, T), still = four(F, F, F, T)})}
R.scent = {what = "Sniff to see glowing trails of every dino that passed near you.", template = "buff",
	fx = {mode = "scan"}, attach = Vector3.new(0, 1.2, -4.85),
	chips = {{"RADIUS", "radius", "studs"}, {"MEMORY", "memory", "s"}, {"BLOOD TRAILS", "blood", "bool"}},
	steps = steps({radius = four(60, 81, 81, 81), memory = four(8, 8, 10.8, 10.8), pulse = four(F, F, T, T), blood = four(F, F, F, T)})}
R.screech = {what = "Fires an electric ball that stuns the first dino it hits and drops its cloak.", template = "shot",
	fx = {color = C3(127, 233, 255), tint = C3(127, 233, 255), hitLabel = "STUNNED %s s", hitKey = "stun", dmgKey = "dmg"},
	attach = Vector3.new(0.94, 0.55, -2.35),
	chips = {{"RANGE", "range", "studs"}, {"STUN", "stun", "s"}, {"DAMAGE", "dmg", ""}, {"FASTER RECHARGE", "faster", "bool"}},
	steps = steps({range = four(200, 270, 270, 270), stun = four(1.1, 1.1, 1.1, 1.1), dmg = four(0, 0, 0, 30), faster = four(F, F, T, T)})}
R.shield = {what = "Blocks all damage for a moment, but you move at half speed while it's up.", template = "buff",
	fx = {mode = "shield", text = "HALF SPEED"}, attach = Vector3.new(0, 0.46, -1.43),
	chips = {{"BLOCKS ALL", "lasts", "s"}, {"STRONGER", "stronger", "bool"}, {"SHORTER COOLDOWN", "shorter", "bool"}, {"LIGHTER SLOW", "lighter", "bool"}},
	steps = steps({lasts = four(1.5, 1.5, 1.5, 2.77), stronger = four(F, T, T, T), shorter = four(F, F, T, T), lighter = four(F, F, F, T)})}
R.thrusters = {what = "Rockets you forward at double run speed; you can steer while it boosts.", template = "move",
	fx = {mode = "boost", text = "2x RUN SPEED"}, attach = Vector3.new(0, 0.99, 0.67),
	chips = {{"BOOST", "boost", "s"}, {"CHARGES", "charges", ""}, {"HOP", "hop", "studs"}},
	steps = steps({boost = four(1.37, 1.37, 1.85, 1.85), go = four(121, 121, 163, 163), charges = four(1, 2, 2, 2), hop = four(0, 0, 0, 25)})}
R.traps = {what = "Throws shock mines ahead; a dino that walks into one is blasted back and dazed.", template = "throw",
	fx = {kind = "mine", countKey = "mines", color = C3(255, 155, 46)},
	chips = {{"MINES", "mines", ""}, {"DAMAGE", "dmg", ""}, {"FASTER RECHARGE", "faster", "bool"}, {"JAMS PARTS", "jam", "bool"}},
	steps = steps({reach = four(60, 60, 60, 60), mines = four(3, 4, 4, 4), dmg = four(25, 25, 25, 25), faster = four(F, F, T, T), jam = four(F, F, F, T)})}

-- Pachy
R.bloodrush = {what = "Out of headbutts? Spend some of your health for one more.", template = "buff",
	fx = {mode = "lunge"}, attach = Vector3.new(0, 2.4, -3.15),
	chips = {{"COSTS", "cost", "%"}, {"HITS +25%", "harder", "bool"}, {"NO SELF-SLOW", "noslow", "bool"}, {"SLOWS TARGET", "slow", "bool"}},
	steps = steps({cost = four(25, 25, 25, 25), harder = four(F, T, T, T), noslow = four(F, F, T, T), slow = four(F, F, F, T)})}
R.hookarm = {what = "Fires a claw at a dino and pulls it in for a head smash.", template = "shot",
	fx = {mode = "pull", color = C3(220, 220, 230), tint = C3(240, 90, 79), hitLabel = "PULLED IN", dmgKey = "dmg"},
	attach = Vector3.new(0.87, -0.74, -2.9),
	chips = {{"RANGE", "range", "studs"}, {"DAMAGE", "dmg", ""}, {"RECHARGE", "cd", ""}},
	steps = steps({range = four(120, 160, 160, 160), dmg = four(10, 10, 10, 15), cd = four("normal", "normal", "6 s", "6 s")})}
R.ink = {what = "Shoots an ink glob that blinds the first dino it hits.", template = "shot",
	fx = {color = C3(70, 40, 110), tint = C3(70, 40, 110), labelColor = C3(184, 166, 255), hitLabel = "BLINDED %s s", hitKey = "blind", second = "splash"},
	attach = Vector3.new(-0.61, 2.77, -2.7),
	chips = {{"RANGE", "range", "studs"}, {"BLIND", "blind", "s"}, {"RECHARGE", "cd", "s"}, {"SPLASH", "splash", "studs"}},
	steps = steps({range = four(120, 160, 160, 160), blind = four(2, 2, 2, 2), cd = four(15, 15, 11, 11), splash = four(0, 0, 0, 6)})}
R.mechalegs = {what = "Boosts your leap farther and higher; at full upgrade you can jump again in mid-air.", template = "move",
	fx = {mode = "leap", double = true, text = "LEAP +50%"}, attach = Vector3.new(0.06, -2.75, 0),
	chips = {{"LAUNCH +", "launch", "%"}, {"COOLDOWN", "cd", "s"}, {"DOUBLE JUMP", "double", "bool"}},
	steps = steps({leap = four(45, 45, 45, 45), launch = four(20, 45, 45, 45), cd = four(4.2, 4.2, 2.73, 2.73), double = four(F, F, F, T)})}
R.medstation = {what = "Drops a healing pad at your feet; stand in it to heal.", template = "place",
	fx = {kind = "pad"}, attach = Vector3.new(0, 0.23, 0),
	chips = {{"AREA", "area", "studs"}, {"HEAL", "heal", ""}, {"LASTS", "lasts", "s"}},
	steps = steps({area = four(12, 18, 18, 18), heal = four("10%/s", "10%/s", "10%/s", "10%/s"), lasts = four(5, 5, 7, 10)})}
R.servodash = {what = "Blasts you forward, then you run at double speed for a moment.", template = "move",
	fx = {mode = "boost", text = "2x TOP SPEED"}, attach = Vector3.new(0, 0.32, 0.45),
	chips = {{"LASTS", "lasts", "s"}, {"RECHARGE", "cd", "s"}, {"REFILLS A HEADBUTT", "refill", "bool"}},
	steps = steps({lasts = four(1, 1.5, 1.5, 1.5), go = four(88, 132, 132, 132), cd = four(8.4, 8.4, 5.6, 5.6), refill = four(F, F, F, T)})}
R.tether = {what = "Lobs a spike that chains the closest dino to the ground for a few seconds.", template = "throw",
	fx = {kind = "spike", color = C3(150, 140, 128)}, attach = Vector3.new(0.12, 1.83, 1.48),
	chips = {{"RANGE", "reach", "studs"}, {"CHAINED", "chained", "s"}, {"RECHARGE", "cd", "s"}, {"YANKS IN", "yank", "bool"}},
	steps = steps({reach = four(180, 180, 180, 180), chained = four(4, 5, 5, 5), cd = four(14, 14, 10, 10), yank = four(F, F, F, T)})}
R.visor = {what = "Projects a force field in front of you that blocks attacks from the front.", template = "buff",
	fx = {mode = "front", starKey = "knock", starText = "KNOCKED BACK"}, attach = Vector3.new(-0.04, 3.78, -5.73),
	chips = {{"LASTS", "lasts", "s"}, {"RECHARGE", "cd", "s"}, {"KNOCKBACK", "knock", "bool"}},
	steps = steps({lasts = four(1.5, 2, 2, 2), cd = four(14, 14, 10, 10), knock = four(F, F, F, T)})}

-- Herrera
R.breaker = {what = "Breaks you free when you're stunned or pinned.", template = "buff",
	fx = {mode = "free", immuneText = "NO DAMAGE %s s"}, attach = Vector3.new(0, 1.86, -1),
	chips = {{"RECHARGE", "cd", "s"}, {"PUSHES BACK", "push", "studs"}, {"NO DAMAGE", "safe", "s"}},
	steps = steps({cd = four(20, 20, 14, 14), push = four(0, 10, 10, 10), safe = four(0, 0, 0, 1)})}
R.caltrops = {what = "Drops razor spikes behind you; enemies who step on them bleed and slow down.", template = "place",
	fx = {kind = "caltrops"}, attach = Vector3.new(0.01, 0.84, 1.4),
	chips = {{"SPIKES", "spikes", ""}, {"PATCH", "patch", "studs"}, {"LASTS", "lasts", "s"}, {"HIDDEN", "hidden", "bool"}},
	steps = steps({spikes = four(6, 10, 10, 10), patch = four(10, 14, 14, 14), lasts = four(8, 8, 14, 14), hidden = four(F, F, F, T)})}
R.glider = {what = "Hold jump in the air to glide down slowly and keep your run speed.", template = "move",
	fx = {mode = "glide"}, attach = Vector3.new(0.04, 0.85, 0.1),
	chips = {{"FALL", "fall", "studs/s"}, {"DROP ATTACK", "drop", "bool"}, {"DROP +30%", "dropMore", "bool"}, {"BLEED BURST", "bleed", "bool"}},
	steps = steps({fall = four(8, 8, 8, 8), drop = four(F, T, T, T), dropMore = four(F, F, T, T), bleed = four(F, F, F, T)})}
R.goo = {what = "Tosses a goo blob that leaves a sticky puddle; enemies in it slow down.", template = "throw",
	fx = {kind = "goo", countKey = "blobs", color = C3(200, 230, 70)}, attach = Vector3.new(0, 0.09, -3.26),
	chips = {{"PUDDLE", "puddle", "studs"}, {"BLOBS", "blobs", ""}, {"LASTS", "lasts", "s"}, {"SLOW", "slow", "%"}},
	steps = steps({reach = four(60, 60, 60, 60), puddle = four(21, 29, 29, 29), blobs = four(1, 1, 2, 2), lasts = four(5, 5, 5, 8), slow = four(50, 50, 50, 50)})}
R.hadren = {what = "Heals you over 3 seconds and makes you run faster while it lasts.", template = "buff",
	fx = {mode = "heal", starKey = "refill", starText = "SLASHES REFILLED"}, attach = Vector3.new(0.77, 1.54, -1.27),
	chips = {{"HEAL", "heal", "%"}, {"SPEED", "speed", "x"}, {"FASTER RECHARGE", "faster", "bool"}, {"REFILLS SLASHES", "refill", "bool"}},
	steps = steps({heal = four(25, 34, 34, 34), speed = four(1.4, 1.4, 1.4, 1.4), faster = four(F, F, T, T), refill = four(F, F, F, T)})}
R.quills = {what = "Fires a volley of quills at your target.", template = "burst",
	attach = Vector3.new(0.04, 1.16, -0.94),
	chips = {{"QUILLS", "darts", ""}, {"DAMAGE", "dmg", "each"}, {"RANGE", "range", "studs"}, {"RECHARGE", "cd", "s"}},
	steps = steps({darts = four(5, 6, 7, 8), dmg = four(4, 4, 4, 4), range = four(80, 80, 80, 80), cd = four(20, 20, 20, 20)})}
R.smoke = {what = "Puts out a big smoke cloud: inside it bots lose you and your name is hidden.", template = "buff",
	fx = {mode = "smoke", text = "HIDDEN %s s"}, attach = Vector3.new(0, 0.89, 1.17),
	chips = {{"CLOUD", "cloud", "studs"}, {"LASTS", "lasts", "s"}, {"RUN FASTER", "faster", "%"}, {"SLOWS ENEMIES", "slows", "bool"}},
	steps = steps({cloud = four(28, 28, 28, 28), lasts = four(4, 6, 6, 6), faster = four(0, 0, 25, 25), slows = four(F, F, F, T)})}
R.strobe = {what = "Flashes your frill in a cone; enemies in it are dazed and can't attack.", template = "cone",
	fx = {hitLabel = "DAZED %s s", hitKey = "daze", push = 0, tint = C3(255, 200, 50)}, attach = Vector3.new(-0.02, 0.6, -2.71),
	chips = {{"CONE", "cone", "°"}, {"RANGE", "range", "studs"}, {"DAZE", "daze", "s"}, {"+20% DAMAGE TAKEN", "vuln", "bool"}},
	steps = steps({cone = four(60, 60, 90, 90), range = four(20, 20, 25, 25), daze = four(1, 1.5, 1.5, 1.5), vuln = four(F, F, F, T)})}

-- Teno
R.tbellow = {what = "You and nearby squadmates take less damage and run faster for a few seconds.", template = "wave",
	fx = {kind = "buff", text = "-50% DAMAGE, +50% SPEED", color = C3(90, 160, 255)}, attach = Vector3.new(0, -0.08, -3.35),
	chips = {{"REACH", "reach", "studs"}, {"LASTS", "lasts", "s"}, {"CLEARS STUNS", "clear", "bool"}},
	steps = steps({reach = four(25, 25, 40, 40), lasts = four(4, 6, 6, 6), clear = four(F, F, F, T)})}
R.tchallenge = {what = "Marks nearby enemies: they deal less damage and bots come after you.", template = "wave",
	fx = {kind = "mark", color = C3(240, 90, 79)}, attach = Vector3.new(0, 1.24, -3.15),
	chips = {{"REACH", "reach", "studs"}, {"MARK", "mark", "s"}, {"SLOW", "slow", "%"}},
	steps = steps({reach = four(30, 30, 45, 45), mark = four(5, 7, 7, 7), slow = four(0, 0, 0, 20)})}
R.tgrab = {what = "Your tail grabs a nearby dino and flings it ahead.", template = "buff",
	fx = {mode = "fling"}, attach = Vector3.new(0, 0.55, 11.73),
	chips = {{"FLING", "fling", "studs"}, {"GRABS UP TO", "grabs", ""}, {"CRASH DAMAGE", "crash", "bool"}},
	steps = steps({fling = four(30, 45, 45, 45), grabs = four("raptor", "raptor", "pachy", "pachy"), crash = four(F, F, F, T)})}
R.tleap = {what = "Every jump becomes a big leap forward that slams the ground where you land.", template = "move",
	fx = {mode = "leap", slam = true}, attach = Vector3.new(0, -1.67, -0.08),
	chips = {{"LEAP", "leap", "studs"}, {"LANDING STUN", "stun", "s"}, {"LEAPS", "charges", ""}, {"RECHARGE", "cd", "s"}},
	steps = steps({leap = four(40, 55, 55, 55), stun = four(0, 0, 0.5, 0.5), charges = four(1, 1, 1, 2), cd = four(4.2, 4.2, 4.2, 4.2)})}
R.tmortar = {what = "Lobs a boulder where you aim; it splashes damage and slows enemies.", template = "throw",
	fx = {kind = "boulder", countKey = "boulders", color = C3(150, 140, 128)}, attach = Vector3.new(0.41, 2.82, -2.29),
	chips = {{"RANGE", "reach", "studs"}, {"SPLASH", "splash", "studs"}, {"BOULDERS", "boulders", ""}, {"RUBBLE", "rubble", "bool"}},
	steps = steps({reach = four(180, 180, 180, 180), splash = four(10, 14, 14, 14), boulders = four(1, 1, 2, 2), dmg = four(12, 12, 12, 12), rubble = four(F, F, F, T)})}
R.tmud = {what = "A shield that completely blocks your next few hits and slows enemies nearby.", template = "buff",
	fx = {mode = "shield", counter = true, color = C3(160, 110, 255), starKey = "burst", starText = "BURST: SLOWED 40%"},
	attach = Vector3.new(-0.14, -0.15, -2.66),
	chips = {{"BLOCKS", "blocks", "hits"}, {"LASTS", "lasts", "s"}, {"END BURST", "burst", "bool"}},
	steps = steps({blocks = four(3, 4, 4, 4), lasts = four(8, 8, 12, 12), burst = four(F, F, F, T)})}
R.tstomp = {what = "Rear up and stomp: a shockwave damages and stuns enemies around you.", template = "wave",
	fx = {kind = "stomp", color = C3(255, 200, 50)}, attach = Vector3.new(0, -0.7, -2.28),
	chips = {{"SHOCKWAVE", "reach", "studs"}, {"STUN", "stun", "s"}, {"DAMAGE", "dmg", ""}, {"DRAINS A LATCHED RAPTOR", "latch", "bool"}},
	steps = steps({reach = four(14, 14, 20, 20), stun = four(0.5, 1, 1, 1), dmg = four(6, 6, 6, 6), latch = four(F, F, F, T)})}

-- Therizino
R.zclock = {what = "Passive: always on once bought, so you run faster.", template = "buff",
	fx = {mode = "speed", text = "RUN +40%", cutsText = "CUTS 30% FASTER", jumpText = "EXTRA JUMP", noslowText = "SLOWS DON'T WORK"},
	attach = Vector3.new(0.01, -1.83, -0.2),
	chips = {{"RUN +", "run", "%"}, {"FASTER CUTS", "cuts", "bool"}, {"EXTRA JUMP", "jump", "bool"}, {"NO SLOWS", "noslow", "bool"}},
	steps = steps({run = four(40, 40, 40, 40), cuts = four(F, T, T, T), jump = four(F, F, T, T), noslow = four(F, F, F, T)})}
R.zdeflect = {what = "Your claws spin in front of you and block incoming shots.", template = "buff",
	fx = {mode = "front", spin = true, starKey = "reflect", starText = "BOUNCED BACK"}, attach = Vector3.new(0, 3.45, -3.47),
	chips = {{"SPIN", "lasts", "s"}, {"BLOCKS BOULDERS", "boulders", "bool"}, {"RECHARGE", "cd", "s"}, {"REFLECTS", "reflect", "bool"}},
	steps = steps({lasts = four(1, 1.5, 2, 2), boulders = four(F, T, T, T), cd = four(16, 16, 13, 13), reflect = four(F, F, F, T)})}
R.zfeather = {what = "Fires a fan of feather blades that cut and slow the dinos they hit.", template = "burst",
	fx = {fan = true, hitLabel = "SLOWED %s s", hitKey = "slow"}, attach = Vector3.new(-0.13, -0.7, -2.61),
	chips = {{"BLADES", "darts", ""}, {"FAN", "reach", "studs"}, {"DAMAGE", "dmg", "each"}, {"SLOW", "slow", "s"}},
	steps = steps({darts = four(8, 10, 10, 12), reach = four(70, 80, 80, 100), dmg = four(3, 3, 3, 3), slow = four(1, 1, 2, 2)})}
R.zgrapple = {what = "Jolts you a short way in the direction you're moving.", template = "dash",
	attach = Vector3.new(0, 1.08, -1.7),
	chips = {{"DASH", "dist", "studs"}, {"CHARGES", "charges", ""}, {"RECHARGE", "cd", "s"}},
	steps = steps({dist = four(30, 40, 50, 50), charges = four(2, 2, 2, 3), trail = four(F, F, F, F), cd = four(4.2, 4.2, 3, 3)})}
R.zharvest = {what = "A spinning sickle ring drags enemies toward you and makes them bleed.", template = "wave",
	fx = {kind = "drag", diameter = true, radiusKey = "ring", color = C3(240, 90, 79)}, attach = Vector3.new(0, -1.96, -4.03),
	chips = {{"RING", "ring", "studs"}, {"LASTS", "lasts", "s"}, {"BLEED", "bleed", "/s"}},
	steps = steps({ring = four(30, 34, 34, 38), lasts = four(3, 3, 4, 5), bleed = four(4, 4, 4, 4)})}
R.zhook = {what = "Fires your chest claw at an enemy and reels you in for a double slash.", template = "shot",
	fx = {mode = "reel", color = C3(220, 220, 230), tint = C3(240, 90, 79), hitLabel = "STUNNED %s s", hitKey = "stun", missLabel = "SLASH", dmgKey = "dmg"},
	attach = Vector3.new(0, 1.86, -4.47),
	chips = {{"RANGE", "range", "studs"}, {"DAMAGE", "dmg", ""}, {"STUN", "stun", "s"}},
	steps = steps({range = four(100, 130, 160, 160), dmg = four(10, 10, 10, 10), stun = four(0, 0, 0, 1)})}
R.zsnare = {what = "Slings a bola that wraps an enemy's legs and holds it in place.", template = "shot",
	fx = {color = C3(255, 200, 50), tint = C3(255, 200, 50), hitLabel = "HELD %s s", hitKey = "hold", dmgKey = "dmg"},
	attach = Vector3.new(0, 0.44, 4.53),
	chips = {{"RANGE", "range", "studs"}, {"HELD", "hold", "s"}, {"DAMAGE", "dmg", ""}, {"BOLAS", "bolas", ""}},
	steps = steps({range = four(120, 120, 160, 160), hold = four(1, 1, 2, 2), dmg = four(12, 12, 12, 12), bolas = four(1, 2, 2, 3)})}

-- Troodon
R.obloom = {what = "Passive: always on once bought, so your glow zones get bigger and last longer.", template = "buff",
	fx = {mode = "zone"}, attach = Vector3.new(0, 0.99, 1.45),
	chips = {{"ZONES", "zone", "studs"}, {"LASTS", "lasts", "s"}, {"END BLOOM", "bloom", "bool"}},
	steps = steps({zone = four(44, 44, 54, 54), lasts = four(3, 4.05, 4.05, 4.05), bloom = four(F, F, F, T)})}
R.oburst = {what = "Throws a bud that heals squadmates and makes enemies heal less.", template = "throw",
	fx = {kind = "heal", color = C3(156, 240, 90)}, attach = Vector3.new(0, -0.32, -1.71),
	chips = {{"BURST", "burst", "studs"}, {"HEAL", "heal", ""}, {"BOOST", "boost", "s"}, {"RECHARGE", "cd", "s"}},
	steps = steps({reach = four(40, 40, 40, 40), burst = four(40, 40, 40, 54), heal = four(20, 20, 20, 20), boost = four(4, 5.4, 5.4, 5.4), cd = four(18, 18, 13.3, 13.3)})}
R.odome = {what = "Throws a canister that becomes a dome; enemy shots from outside stop on it.", template = "throw",
	fx = {kind = "dome", color = C3(127, 233, 255)}, attach = Vector3.new(-0.37, 0.34, 1.38),
	chips = {{"DOME", "dome", "studs"}, {"LASTS", "lasts", "s"}, {"RECHARGE", "cd", "s"}},
	steps = steps({reach = four(30, 30, 30, 30), dome = four(90, 90, 90, 121.5), lasts = four(5, 6.75, 6.75, 6.75), cd = four(25, 25, 18.5, 18.5)})}
R.olantern = {what = "Throws a lantern that zaps the nearest enemy and chains to more.", template = "throw",
	fx = {kind = "lantern", color = C3(255, 200, 50)}, attach = Vector3.new(0.86, -0.6, 0.36),
	chips = {{"CHAINS", "chains", ""}, {"CHAIN REACH", "chainReach", "studs"}, {"DAMAGE", "dmg", ""}, {"RECHARGE", "cd", "s"}},
	steps = steps({reach = four(80, 80, 80, 80), chains = four(1, 1, 1, 3), chainReach = four(24, 32.4, 32.4, 32.4), dmg = four(12, 12, 12, 12), cd = four(14, 14, 10.3, 10.3)})}
R.omender = {what = "A drone heals your most hurt squadmate for a few seconds.", template = "buff",
	fx = {mode = "drone"}, attach = Vector3.new(0, 1.02, -0.31),
	chips = {{"HEAL", "heal", "/s"}, {"LASTS", "lasts", "s"}, {"RECHARGE", "cd", "s"}, {"MOVES ON", "moveson", "bool"}},
	steps = steps({heal = four(4, 4, 4, 4), lasts = four(4, 5.4, 5.4, 5.4), cd = four(20, 20, 14.8, 14.8), moveson = four(F, F, F, T)})}
R.oportal = {what = "Drop a portal, run a path and drop the other end; any dino can zip along it.", template = "place",
	fx = {kind = "portal"}, attach = Vector3.new(0, 0.39, 2.68),
	chips = {{"REACH", "reach", "studs"}, {"OPEN", "open", "s"}, {"RECHARGE", "cd", "s"}},
	steps = steps({reach = four(185, 250, 250, 250), open = four(22, 22, 30, 30), cd = four(61, 61, 61, 45)})}
R.osapwall = {what = "Throws a sap pod that hardens into a wall that blocks dinos and shots.", template = "throw",
	fx = {kind = "wall", color = C3(230, 170, 70)}, attach = Vector3.new(0.7, 0.72, -0.95),
	chips = {{"WALL", "wall", "studs"}, {"HEIGHT", "height", "studs"}, {"LASTS", "lasts", "s"}},
	steps = steps({reach = four(80, 80, 80, 80), wall = four(74, 100, 100, 100), height = four(30, 30, 30, 30), lasts = four(4.2, 4.2, 5.8, 8)})}
R.osentry = {what = "Throws a turret that shoots the nearest enemy for a few seconds.", template = "throw",
	fx = {kind = "turret", countKey = "pods", color = C3(120, 200, 160)}, attach = Vector3.new(0, 0.99, 0.31),
	chips = {{"LASTS", "lasts", "s"}, {"MAX DAMAGE", "maxdmg", ""}, {"TWIN PODS", "twin", "bool"}, {"RECHARGE", "cd", "s"}},
	steps = steps({reach = four(30, 30, 30, 30), pods = four(1, 1, 1, 2), lasts = four(8, 10.8, 10.8, 10.8), maxdmg = four(20, 20, 20, 20), twin = four(F, F, F, T), cd = four(22, 22, 16.3, 16.3)})}
R.oshed = {what = "Sheds your feathers to break out of a stun, pin or grab.", template = "buff",
	fx = {mode = "free", color = C3(255, 195, 90), stuckText = "GRABBED"}, attach = Vector3.new(0, 0.46, -0.07),
	chips = {{"IMMUNE", "immune", "s"}, {"RECHARGE", "cd", "s"}, {"KNOCKBACK", "push", "studs"}},
	steps = steps({immune = four(1, 1.4, 1.4, 1.4), cd = four(24, 24, 17.7, 17.7), push = four(0, 0, 0, 20)})}
R.osleep = {what = "Fires a dart that puts the first enemy it hits to sleep until it takes damage.", template = "shot",
	fx = {color = C3(184, 166, 255), tint = C3(184, 166, 255), hitLabel = "ASLEEP %s s", hitKey = "sleep", second = "split"},
	attach = Vector3.new(0.28, 2.11, -3.13),
	chips = {{"RANGE", "range", "studs"}, {"SLEEP", "sleep", "s"}, {"RECHARGE", "cd", "s"}, {"SPLITS", "split", "bool"}},
	steps = steps({range = four(120, 120, 120, 120), sleep = four(2.5, 3.4, 3.4, 3.4), cd = four(12, 12, 8.9, 8.9), split = four(F, F, F, T)})}

R.TEMPLATES = {burst = true, lob = true, cone = true, ring = true, self = true, dash = true}
for _, k in ipairs({"shot", "throw", "wave", "buff", "move", "place"}) do R.TEMPLATES[k] = true end -- v1.1

-- "40 studs" / "1.5 s" / "140°" / "4" / "YES"
function R.fmt(v, unit)
	if unit == "bool" then return v and "YES" or "NO" end
	local s
	if type(v) == "number" then
		s = (math.abs(v - math.floor(v)) < 1e-6) and tostring(math.floor(v)) or tostring(math.floor(v * 10 + 0.5) / 10)
	else
		s = tostring(v)
	end
	if unit == "°" then return s .. "°" end
	if unit == "%" or unit == "x" or unit == "/s" then return s .. unit end -- v1.1
	if unit == nil or unit == "" then return s end
	return s .. " " .. unit
end

-- the chips of a recipe at step `shown` (1..4) against the owned step `owned` (0..4):
-- {{label, text, up}} where up = the value changed from the owned step (owned >= 1 and shown > owned)
function R.chips(recipe, shown, owned)
	local out = {}
	if type(recipe) ~= "table" or type(recipe.steps) ~= "table" then return out end
	shown = math.clamp(math.floor(tonumber(shown) or 1), 1, #recipe.steps)
	owned = math.floor(tonumber(owned) or 0)
	local now = recipe.steps[shown]
	local base = owned >= 1 and recipe.steps[math.min(owned, #recipe.steps)] or nil
	for _, c in ipairs(recipe.chips or {}) do
		local label, key, unit = c[1], c[2], c[3]
		local v = now[key]
		local up = base ~= nil and shown > owned and base[key] ~= v
		local text = R.fmt(v, unit)
		if up then text = R.fmt(base[key], unit == "°" and "°" or (unit == "bool" and "bool" or "")) .. " → " .. text end
		table.insert(out, {label, text, up})
	end
	return out
end

return R
