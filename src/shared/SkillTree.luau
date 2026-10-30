-- SkillTree v1.30 (Mecha Dino Arena) — skill tree data and maths: areas, paths, step costs, the level curve, buy / respec
-- checks and what a build does. MDA-11, plan docs/plans/SKILLTREES_v1.0.md Task 1, ADR "Skill trees own XP and replace
-- class stat points". Pure: no Instance access. Used by SkillServer 1.0 / SkillEffects 1.0 (server) and, through the copy
-- SkillServer puts in ReplicatedStorage.SkillShared, by SkillScreen 1.0 (client).
-- Kepu: layout A; the paths replace the class stat points; Jaws upgrades the main attack (bite / pounce); 1 point per
--   level, cap 60; costs 1-2-3-4 along a path; free respec; fast start, slower later; the 5 missing effects are real
--   (bleed, crushing hit, less knockback, overheal shield) and Sprint Legs II is run speed x1.5.
-- Tree: AREAS = 5 areas (health, attack, defense, speed, eng) x 3 paths x 4 steps (I, II, III, star). PATHS[id] =
--   {id, name, area, mech, soon, steps}. Only regen, lifesteal, jaws, hide, legs are buyable in this piece; the other
--   10 have soon = true.
-- Level: xpToNext(L) = 30 + 10 (L - 1). levelOf(totalXp) -> level, xpIntoLevel, xpNext (0 at MAX_LEVEL 61; a bad or
--   negative total counts as 0). pointsOf(level) = min(level - 1, MAX_POINTS 60).
-- Builds: steps = {[pathId] = 0..4}. sanitize(raw) -> a clean copy: known ids only, whole numbers 0..4, soon paths 0, a
--   non-number -> 0. spent(steps) = sum of COST over the bought steps of the sanitized build.
--   canBuy(steps, pathId, pointsEarned) -> ok, reason ("ok" / "unknownPath" / "soon" / "maxed" / "noPoints").
--   buy(...) -> a new steps table and "ok", or nil and the reason; never changes its input. Respec = {}.
-- effects(steps) -> what the build does (sanitized; soon paths never count):
--   attackPts / defensePts / speedPts: player StatAdded_* points (StatServer: +2 bite / +2 land / +1 tick, -5% damage
--     taken, +10% walk / run per point)
--   regenDelay (s without damage) / regenRate (fraction of max health per s); killRegenAdd (added to KillRegenFraction)
--   lifesteal (fraction of damage dealt healed); shieldMax (fraction of max health) / shieldTime (s)
--   mainCdMul (main attack cooldown), moveCdMul (pounce / ram / jump cooldowns)
--   bleedDps / bleedTime; crushStun (s) / crushCooldown (s per target)
--   tossMul (ram toss distance), stunMul (stun length), stunImmuneAbove (health fraction; 0 = off)
-- v1.1 (mecha parts framework + Thrusters, MDA-24, plan docs/plans/MECHA_THRUSTERS_v1.0.md Task 1, mockup
--   docs/mockups/mecha_thrusters_options.html; Kepu 2026-10-28: framework + 1 part, Thrusters first, numbers as proposed):
--   LIVE_MECH = {thrusters = true}: these mecha paths get soon = false at load (buyable); the other 9 stay "soon".
--   BUTTONS = {thrusters = true}: mecha parts that take a loadout slot. SLOTS = 2.
--   effects(steps) adds dashCharges (0; 1 at I; 2 from II), dashDist (35; 50 from III), dashHop (0; 25 at star).
--   Loadout = {[1] = pathId or false, [2] = pathId or false}:
--   sanitizeLoadout(raw, steps) -> a clean loadout: each slot a BUTTONS id bought (steps >= 1) and not soon, no id twice
--     (the lower slot wins), anything else false.
--   autoSlot(loadout, steps, pathId) -> a new loadout: a bought, unslotted BUTTONS id goes in the first empty slot;
--     otherwise the clean loadout unchanged.
--   setSlot(loadout, steps, n, pathId or false) -> a new loadout, "ok" | nil, reason ("badSlot" / "notButton" /
--     "notOwned"); the id leaves its other slot. None of these change their inputs.
-- v1.2 (Thrusters boost, MDA-31, plan docs/plans/MECHA_THRUSTERS_v1.0.md "v1.1 changes"; Kepu 2026-10-28 after trying it:
--   "make the thrusters actually last longer" -> "1.5 s boost, steerable"): effects adds dashTime (0; 1.5 s from I; 2 s
--   from III). The Thrusters step texts describe the boost. dashDist stays as in 1.1 (no longer used by the boost).
-- v1.3 (35% rule, MDA-34; Kepu 2026-10-28: "its an arcade game. i want these boosts to feel significant" / "every single
--   boost you made needs to be at least 35% of an improvement from before" -> each step's number at least 1.35x the
--   step before (for times, cooldowns and damage taken: at most 1 / 1.35 of it), whole tree): STRONG (default true;
--   false = the 1.2 numbers). While on, effects() uses: Regeneration II delay 4.4 s, III 3.2 s and 4.5%/s; Jaws I +5
--   Attack (T-Rex bite 25 -> 35), II main attack cooldown x0.74; Thick Hide I +6 Defense (damage taken x0.70), III stuns
--   x0.70; Sprint Legs I +4 Speed (run x1.4), II 9 (x1.9), III move cooldowns x0.74, star 16 (x2.6; StatSheet 1.1 cap 16);
--   Thrusters III boost 2.1 s. The step texts of those paths say the new numbers (Thrusters I: 3x run speed, SkillEffects
--   1.3).
-- v1.4 (MDA-36; Kepu 2026-10-28 after playing it: "the thrusters might be a little too fast. maybe just make it 1.75 my
--   run speed and 1 second long"): while STRONG, the Thrusters boost is 1 s (I / II) and 1.35 s from III (the 35% rule:
--   1.35 x 1 s); texts say 1 s at 1.75x run speed (SkillEffects 1.4) and 1.35 s.
-- v1.5 (Cloak release, MDA-49, plan docs/plans/CLOAK_v1.0.md; ADR-003 / ADR-004; Kepu 2026-10-29):
--   * Per-dino trees: path.dino = nil (shared stat path) / "Raptor" / "TRex" / "none" (kept, shown to nobody);
--     path.notFor = {[dino] = true} for a shared path a dino skips (regen: TRex). New paths are added to AREAS after the
--     1.4 ones (raptor: adrenaline, blade, dart, cloak, beacon, decoy; T-Rex: repairdrone, biobattery, reactive, ramjet,
--     shieldproj, roaramp); shield / grapple / thrusters become Raptor, rocket / armor TRex, medstation / turret / sentry
--     / traps / barricade "none". seesPath(p, dino): dino nil = every path (1.4 behaviour), "All" = every path but
--     "none", any other key = shared paths it isn't skipped from + its own. pathsFor(areaId, dino) -> the area's paths
--     the dino sees, shared first, then its own, each in AREAS order.
--   * Every build function takes an optional last argument dino: sanitize(raw, dino) zeroes paths the dino doesn't see;
--     spent / canBuy / buy / effects / sanitizeLoadout / autoSlot / setSlot pass it on. canBuy reasons in order:
--     unknownPath, otherDino, soon, maxed, masteryFull, noPoints, ok.
--   * Build limits (BUILD_LIMITS, default true; false = 1.4): MAX_POINTS 40, MAX_LEVEL 41 (one point per level), and
--     Mastery 3: a line is mastered at step >= 3; buying step III of a line while MASTERY_MAX (3) other lines are
--     mastered -> "masteryFull". mastered(steps, dino) -> ids in PATH_ORDER; masteryOk(steps, dino) -> count <= max.
--   * SLOTS = 4 (slot 1 = button 1 tap / R, 2 = button 2 tap / C, 3 = button 1 pull / T, 4 = button 2 pull / V).
--   * Cloak Field live (LIVE_MECH, BUTTONS): effects cloakTime (0; 3 s at I; 4.1 s from II), cloakCooldown (0; 12 s),
--     cloakPounceMul (1; 1.35 from III, added with other same-hit bonuses by PounceServer), cloakStill (false; true at
--     star: standing still keeps the cloak, up to 2 x cloakTime). BUTTONS also lists every button part (not live ones
--     stay "soon", so they can't be slotted).
-- v1.6 (raptor parts batch 1, MDA-58, plan docs/plans/RAPTOR_PARTS_B1_v1.0.md; Kepu picked mockup
--   docs/mockups/raptor_parts_b1_options.html Blade A / Adrenaline A / Shield B): Blade Claws, Adrenaline Injector and
--   Energy Shield are live (LIVE_MECH). Blade Claws is passive (not in BUTTONS). New effects fields (0 / 1 / false when
--   not owned, and always for a dino that doesn't own the path):
--     Blade Claws: bladeLandBonus (0.35 from I, added to the other landing bonuses), bladeTickMul (1; 0.74 from II: the
--       latch / pin bite interval), bladeBleedDps / bladeBleedTime (0; 3 / 4 from III: pounce hits bleed),
--       bladePinRefund (0; 0.5 at star: share of PounceStaminaCost given back on a pin kill).
--     Adrenaline Injector: adrenHeal (0; 0.20 at I, 0.27 from II: share of max health healed over adrenTime),
--       adrenTime (0; 3), adrenSpeedMul (1; 1.3), adrenCooldown (0; 20, 14.8 from III), adrenStunClear (false; true at
--       star: usable while stunned and ends the stun).
--     Energy Shield (Kepu 2026-10-29: no push-back - "If we're allowing it to block all attacks then the push back
--       shouldn't exist" -> star "Longer block"; "You block all damage but you're slower during the blocking period" ->
--       half speed, lighter at star): eshieldTime (0; 1.5, 2.05 from II, 2.77 at star), eshieldCooldown (0; 16, 11.8
--       from III), eshieldSpeedMul (1; 0.5 while blocking, 0.68 at star). Step texts I and star replaced to say so
--       (the 1.0 texts "a bubble that blocks damage for a few seconds" / "Bursts and knocks enemies back" are gone;
--       II / III unchanged).
--   Jaws is not for raptors (Kepu 2026-10-29: "jaws 1 shouldn't be an ability for raptors because that's what the claws
--     are doing" -> "Remove Jaws for raptors"): PATHS.jaws.notFor = {Raptor = true}, the same rule as Regeneration for
--     the T-Rex. The raptor's Attack area is Blade Claws + Dart Launcher; a raptor record holding Jaws steps is refunded
--     on load (sanitize). The T-Rex keeps Jaws.
local SkillTree = {}
SkillTree.Version = "1.15"
SkillTree.COST = {1, 2, 3, 4}
SkillTree.MAX_POINTS = 60
SkillTree.MAX_LEVEL = 61
-- v1.5: build limits (ADR-003 Mastery 3, ADR-004 40 points / level cap 41)
SkillTree.BUILD_LIMITS = true
SkillTree.MASTERY_MAX = 3
if SkillTree.BUILD_LIMITS then
	SkillTree.MAX_POINTS = 40
	SkillTree.MAX_LEVEL = 41
end

local function path(id, name, mech, soon, steps)
	return {id = id, name = name, mech = mech, soon = soon, steps = steps}
end

SkillTree.AREAS = {
	{id = "health", name = "Health", color = {95, 209, 106}, paths = {
		path("regen", "Regeneration", false, false, {
			"Heal 2% of max health per second after 6 s without damage",
			"Starts after 5 s, 3% per second",
			"Starts after 4 s, 4% per second",
			"Kill heal doubled: each kill heals 50% over 5 s (was 25%)"}),
		path("medstation", "Med-Station", true, true, {
			"Button: drop a machine that heals everyone nearby", "Bigger heal area", "Lasts longer", "Two stations"}),
		path("lifesteal", "Lifesteal", false, false, {
			"5% of the damage you deal heals you",
			"10% of the damage you deal heals you",
			"15% of the damage you deal heals you",
			"Healing past full becomes a shield (up to 20% of max health, lasts 6 s)"}),
	}},
	{id = "attack", name = "Attack", color = {240, 90, 79}, paths = {
		path("jaws", "Jaws", false, false, {
			"Main attack hits harder (+1 Attack point)",
			"Main attack recharges 10% faster",
			"Hits make the target bleed: 3 damage per second for 4 s",
			"Crushing hit: a hit stuns the target for 0.75 s (once every 4 s per target)"}),
		path("turret", "Back Turret", true, true, {
			"A turret on your back fires at the nearest enemy", "Faster fire", "Longer range", "Twin barrels"}),
		path("rocket", "Shoulder Rocket", true, true, {
			"Button: aimed rocket with splash damage", "Faster reload", "Bigger blast", "3-rocket burst"}),
	}},
	{id = "defense", name = "Defense", color = {90, 160, 255}, paths = {
		path("hide", "Thick Hide", false, false, {
			"Take 5% less damage (+1 Defense point)",
			"Less knockback: thrown half as far when a T-Rex rams you off",
			"Stuns are 25% shorter",
			"No stuns while above 50% health"}),
		path("armor", "Armor Plating", true, true, {
			"Button: absorb damage, press again to release it as a blast", "Bigger charge", "Faster recharge",
			"Bigger blast at max charge"}),
		path("shield", "Energy Shield", true, true, {
			"Button: a bubble that blocks damage for a few seconds", "Stronger", "Shorter cooldown",
			"Bursts and knocks enemies back"}),
	}},
	{id = "speed", name = "Speed", color = {255, 211, 77}, paths = {
		path("legs", "Sprint Legs", false, false, {
			"Run 10% faster (+1 Speed point)",
			"Run speed x1.5",
			"Pounce, ram and leap recharge 15% faster",
			"Run 10% faster again"}),
		path("thrusters", "Thrusters", true, true, {
			"Button: dash forward", "2 charges", "Longer dash", "Rocket hop"}),
	}},
	{id = "eng", name = "Engineer", color = {255, 155, 46}, paths = {
		path("sentry", "Sentry", true, true, {"Button: drop an auto-turret", "More health", "More damage", "Two sentries"}),
		path("traps", "Traps", true, true, {
			"Button: drop mines", "Slowing net trap", "More mines", "EMP mine: shuts off enemy mech skills"}),
		path("barricade", "Barricade", true, true, {"Button: drop a wall", "Bigger", "Tougher", "A dome the squad can stand in"}),
	}},
}

-- v1.7 (Kepu 2026-10-29: "adrenaline should be faster or a bigger health charge" -> "Both"): adrenHeal 0.25 at I,
--   0.34 from II (was 0.20 / 0.27); adrenSpeedMul 1.4 (was 1.3). Cooldown and time unchanged. Step texts updated.
-- v1.8 (Kepu 2026-10-29: thrusters "half a second longer" at max -> "star 1.85 s, lower steps 1.37 s"; "2x run
--   speed"): while STRONG, dashTime 1.37 s (I / II; was 1.0) and 1.85 s from III (was 1.35; 1.85 / 1.37 = 1.35, the
--   35% rule). Speed is SkillEffects 1.7 SkillDashSpeedMul 2. Step texts I / III.
-- v1.9 (raptor parts batch 2, MDA-70, plan docs/plans/RAPTOR_PARTS_B2_v1.0.md; Kepu 2026-10-29: "these need to be Raptor
--   specific ... the Raptor is a natural roamer"; mockup docs/mockups/raptor_parts_b2_scent_screech.html): two new raptor
--   button parts, live: "screech" Raptor Screech (attack, appended after dart) and "scent" Scent Sense (eng, appended
--   after roaramp). Dart Launcher and Pack Beacon are kept but shown to nobody (OWNER "none"). New effects fields (0 / 1
--   / false when not owned):
--     Scent Sense: scentRadius (0; 60, 81 from II), scentMemory (0; 8, 10.8 from III), scentTime (0; 6), scentCooldown
--       (0; 16), scentFresh (false; true from III: the freshest end of each trail pulses), scentBlood (false; true at
--       star: bleeding dinos leave a blood trail you see all the time).
--     Raptor Screech: screechRange (0; 50, 67.5 from II: max held range), screechFlinch (0; 0.5 s), screechCooldown
--       (0; 14, 10.3 from III), screechJam (false; true at star: the hit dino's boost, Shield and Adrenaline end).
-- v1.10 (Kepu 2026-10-29 after v76: "the screech shouldn't be called that because it's not even a screech also the dart
--   doesn't even shoot far at all" -> "Shock Dart", "100 / 135 studs"): the "screech" path is shown as "Shock Dart"
--   (path id kept, so saves and attributes stay); screechRange 100 at I, 135 from II (was 50 / 67.5; 1.35x kept);
--   step texts I / II.
-- v1.11 (Kepu 2026-10-29 after v80: "make it a cannon that sits somewhere on the raptor and shoots an electricity ball
--   that disables a target for 1.5 seconds max" -> mockup docs/mockups/shock_cannon_options.html B, "1.1 s -> 1.5 s at
--   star"): the "screech" path is shown as "Shock Cannon"; screechFlinch (now a full stun on any dino, ScreechServer 1.2)
--   1.1 s from I, 1.5 s at star (1.5 / 1.1 = 1.36); step texts I / star.
-- v1.12 (Kepu 2026-10-29: "scrap it [Grapple] and introduce traps" -> mockup docs/mockups/raptor_traps_options.html
--   B "Shock mine", Engineer; plan docs/plans/RAPTOR_TRAPS_v1.0.md): Grapple Hook shown to nobody (OWNER "none");
--   "traps" becomes the raptor's live button part "Shock Mine" (OWNER Raptor, LIVE_MECH, BUTTONS) with step texts.
--   Effects: mineDamage (0; 15), mineSlow (1; 0.5 speed multiplier), mineSlowTime (0; 2 s), mineCooldown (0; 12,
--   8.8 from III), mineMax (0; 1, 2 from II), mineJam (false; true at star).
-- v1.13 (Kepu 2026-10-29 after v84: "a bot walked on it but it didn't do anything to the bot noticeably ... make this an
--   actual useful gadget" -> "Blast + launch", "25"): mineDamage 25 (was 15); new mineLaunch (0; 25 studs thrown back)
--   and mineDaze (0; 1 s dazed after landing); step I text. mineSlow / mineSlowTime stay for MineServer's old mode.
-- v1.14 (Kepu 2026-10-29: "let's give them different star attributes ... for the canon maybe make it deal more damage
--   and remove the stun" -> "Heavy shot"; "Let's also forget about the hologram"): Shock Cannon star no longer stuns
--   longer or jams parts (screechFlinch stays 1.1, screechJam false); new screechDamage (0; 30 at star); star text.
--   Decoy Hologram shown to nobody (OWNER "none"). The Shock Mine keeps the parts jam as its star.
-- v1.15 (MDA-84; Kepu 2026-10-29, raptor complete: "Just delete them"): the four hidden raptor paths are deleted from
--   the tree: Grapple Hook (speed), Dart Launcher (attack), Pack Beacon and Decoy Hologram (eng); their OWNER entries,
--   the dino / OWNER lines that hid them and their BUTTONS entries go with them. Saved steps for these ids are dropped
--   by sanitize (it walks PATHS); a request naming one is refused ("unknownPath").
-- v1.16 (Kepu 2026-10-30 after the v126 test: "I maxed out the Raptor speed and it was way too fast. The testers said the
--   base speed is fast enough. Maybe just a little faster than that is perfect" -> "Maybe Max speed +40 percent"): with
--   SkillTree.LEGS_GENTLE (default true) Sprint Legs gives speedPts I 1 / II 2 / star 4 (StatServer +10% per point:
--   +10% / +20% / +40%; was 4 / 9 / 16 = +40% / +90% / +160%) and the step texts say so. III (moves recharge 35%
--   faster) is unchanged. LEGS_GENTLE = false restores 1.15.
-- v1.17 (MDA-103; Kepu 2026-10-30: "do a 4th charge then"): MineServer 1.6 gives every Shock Mine owner max(3, MineMax)
--   charges, so rank II's "2 mines out at once" did nothing. With SkillTree.MINE_FOURTH (default true) rank II sets
--   mineMax 4 (4 charges, 4 mines on the ground at once); rank I keeps mineMax 1 (= 3 charges). Step texts: I says
--   "(3 charges)", II "4th charge: 4 mines". MINE_FOURTH = false restores 1.16 (mineMax 2 at II).
-- v1.18 (Kepu 2026-10-30: the pounce button is now "ATTACK" for every dino because testers were confused what pounce
--   meant; "number 1 is fine" = the skill texts follow): with SkillTree.ATTACK_WORDING (default true) the step texts say
--   attack instead of pounce: Blade Claws I / III / star, Cloak Field I / III, Sprint Legs III. Sprint Legs III names
--   "the raptor's attack" because moveCdMul does not touch the T-Rex bite (SkillEffects skips BiteCooldown). Texts only;
--   no effect changes. ATTACK_WORDING = false restores 1.17 texts.
-- v1.19 (pachy, MDA-120, plan docs/plans/PACHY_PLAYABLE_v1.0.md Task 10; Kepu 2026-10-30 "Own attack line"): with
--   SkillTree.PACHY_NO_JAWS (default true) PATHS.jaws.notFor gains Pachy (its attack line is Battering Dome, Drop 2).
--   The pachy sees the shared paths except Jaws, plus no dino-owned paths yet. false = 1.18.
-- v1.20 (pachy Drop 2, plan docs/plans/PACHY_PLAYABLE_v1.0.md "Drop 2"; Kepu 2026-10-30 "Own attack line", "lets do
--   battering dome first"): with SkillTree.BATTERING_DOME (default true) the pachy's own attack line "dome" ("Battering
--   Dome", not a mecha part, OWNER Pachy) is appended to the attack area, PATHS and PATH_ORDER. Effects (0 / 1 when
--   not bought): hbDamageMul (I: 1.25), hbShoveMul (II: 1.3), hbRefillMul (III: 0.7 = refill 30% faster),
--   hbExtraCharges (star: 1 = a 3rd charge), pachySpikes (star: true). false = 1.19 (no line).
-- v1.21 (pachy Grappling Hook, MDA-121, plan docs/plans/PACHY_PARTS_v1.0.md Drop A; mockup
--   docs/mockups/pachy_parts_options.html "A · Wrist claw"): with SkillTree.HOOK_ARM (default true) the pachy's button
--   part "hookarm" ("Grappling Hook", mecha, live, OWNER Pachy, BUTTONS) is appended to the attack area, PATHS and
--   PATH_ORDER (new id; the deleted raptor "grapple" stays unknown). Effects (0 when not bought): hookRange (I 60, II 80),
--   hookCooldown (I 8, III 6), hookDamage (I 10, star 15). false = 1.20 (no line).
-- v1.22 (pachy Mecha Legs, MDA-123, plan docs/plans/PACHY_PARTS_v1.0.md Drop B; mockup "A · Piston shins"; Kepu
--   2026-10-30: "they should have a cool down since this is a boosted jump" -> "One shared cooldown", "6 s; III = 35%
--   faster"): with SkillTree.MECHA_LEGS (default true) the pachy's passive mecha part "mechalegs" ("Mecha Legs", live,
--   OWNER Pachy, not a button) is appended to the speed area, PATHS and PATH_ORDER. Effects (1 / 0 / false when not
--   bought): legsBoostMul (I: 1.25, leap forward boost), legsPowerMul (II: 1.2, leap launch power), legsCooldown (from I:
--   6 s, one cooldown for the whole leap incl. its double jump), legsCdMul (III: 0.65), doubleJump + legsLook (star).
--   false = 1.21 (no line).
-- v1.23 (Kepu 2026-10-30: "mecha legs should take up an ability slot. It's not a passive one, it just doesn't
--   traditionally trigger through the ability buttons like others it's through the jump button"): with
--   SkillTree.MECHA_LEGS_SLOT (default true) "mechalegs" is also in BUTTONS, so it takes a loadout slot like the other
--   parts (sanitizeLoadout / autoSlot) and SkillEffects 1.16 only turns it on while slotted. It still fires through the
--   jump (JumpTest), not its slot key. false = 1.22 (passive, no slot).
--   Stronger (Kepu 2026-10-30: "Leaping isn't powerful enough. This should have some typa strong jump feeling and the
--   second should be really strong too"), with SkillTree.MECHA_LEGS_STRONG (default true; false = the 1.22 numbers):
--   I legsBoostMul 1.5 + legsPowerMul 1.2, II legsPowerMul 1.45 (about 2.1 x the base leap height), star doubleJump with
--   legsDoubleMul 1 (a full leap from mid-air) and legsDoubleForward 15 studs/s. Step texts follow the numbers.
-- v1.24 (pachy Blood Rush, MDA-124, plan docs/plans/PACHY_BLOODRUSH_v1.0.md, mockup "C · Both"; Kepu 2026-10-30): with
--   SkillTree.BLOOD_RUSH (default true) the pachy's part "bloodrush" ("Blood Rush", mecha, live, OWNER Pachy, BUTTONS:
--   takes a slot like Mecha Legs and fires through ATTACK) is appended to the attack area, PATHS and PATH_ORDER. Effects
--   (off values when not bought): bloodRush (I: true), bloodCost (I: 0.25 of max health), bloodMax (I: 2 per empty
--   spell), bloodDamageMul (II: 1.25), bloodNoSelfSlow (III: true), bloodSlowMul / bloodSlowTime (star: 0.45 / 4 s).
--   false = 1.23 (no line).
-- v1.25 (Kepu 2026-10-30: "don't allow for blood rush to be used again until full health is restored"; HeadbuttServer
--   1.6): Blood Rush step I text reads "2, then not again until you are back at full health".
-- v1.26 (Kepu 2026-10-30: "health regen should never be a skill for pachy. take that off."): with
--   SkillTree.PACHY_NO_REGEN (default true) PATHS.regen.notFor gains Pachy (the same rule as Regeneration for the T-Rex):
--   the pachy's tree has no Regeneration line and saved Regeneration steps on the pachy are dropped by sanitize (their
--   points come back). Lifesteal and the built-in kill regen are not changed. false = 1.25.
-- v1.27 (Kepu 2026-10-30: "I noticed health steal is still a thing for the patchy"): with SkillTree.PACHY_NO_LIFESTEAL
--   (default true) PATHS.lifesteal.notFor gains Pachy (same rule as v1.26): no Lifesteal line (and no Lifesteal star
--   shield) on the pachy; saved Lifesteal steps on the pachy are dropped by sanitize (their points come back). The
--   built-in kill regen (25% over 5 s) is not changed. Raptor / T-Rex keep Lifesteal. false = 1.26.
-- v1.28 (Kepu 2026-10-30: "Health steal for raptor should be stronger then"; answers: 20% / 35% / 50%, raptor only): with
--   SkillTree.RAPTOR_LIFESTEAL_STRONG (default true) effects() also gives e.lifestealRaptor = 0.20 / 0.35 / 0.50 at
--   Lifesteal I / II / III (0 below I); SkillEffects 1.20 uses it on a raptor instead of e.lifesteal. The T-Rex keeps
--   e.lifesteal 0.05 / 0.10 / 0.15; the star (overheal shield) is the same for both. PATHS.lifesteal.stepsFor.Raptor holds
--   the raptor's step texts (Lab 1.8 shows them on a raptor). false = 1.27.
-- v1.29 (pachy Med-Station, MDA-125, plan docs/plans/PACHY_MEDSTATION_v1.0.md, mockup
--   docs/mockups/pachy_medstation_options.html look "C · Pulse pad"): with SkillTree.PACHY_MEDSTATION (default true) the
--   shared path "medstation" (Health area, shown to nobody until now) becomes the pachy's live slot part: dino "Pachy",
--   soon false, LIVE_MECH, BUTTONS, step texts I-star below. effects() gives medRadius / medTime / medRate / medCooldown:
--   I 12 studs / 5 s / 0.10 per s / 30 s; II radius 18; III 7 s; star 10 s (Kepu: "Just extend the duration to be able to
--   full heal in 10 seconds"); 0 below I. MedStationServer 1.0 runs it. Raptor / T-Rex still never see it. false = 1.28.
-- v1.30 (Kepu 2026-10-30: "We'll do the bone crest to replace the thick hide. Whoever bites your dome does 40% less
--   damage"; answers: builds up to 40%, front bites only, spark + CLANK, Thick Hide vs players fixed too): with
--   SkillTree.PACHY_BONE_CREST (default true) a pachy-only Defense line "crest" "Bone Crest" (not a mech part, no slot) is
--   added and PATHS.hide.notFor gains Pachy (saved Thick Hide steps on the pachy are dropped by sanitize, points come
--   back). effects(): crestMul 0.80 / 0.70 / 0.60 at I / II / III (bites and pounces from in front of the pachy do that
--   share of their damage), crestReflect 5 at star (the biter takes 5 back); 1 / 0 below I. BoneCrest 1.0 (module) does
--   the maths for BiteServer / PounceServer / BotServer. false = 1.29.
-- v1.5: per-dino paths, appended to their areas (1.4 order kept)
do
	local add = {
		health = {
			path("adrenaline", "Adrenaline Injector", true, true, {
				"Button: heal 20% of max health over 3 s and run 1.3x faster while it lasts", "Heal 27%",
				"Recharges 26% faster", "Also ends a stun at once"}),
			path("repairdrone", "Repair Drone", true, true, {
				"Button: a drone lifts off your back and heals 20% of max health over 5 s", "Heals 27%",
				"Recharges 26% faster", "The drone also heals an ally next to you"}),
			path("biobattery", "Bio-Battery Spine", true, true, {
				"Every hit you land fills a cell (5 cells); full = heal 15% of max health", "Heal 20%",
				"4 cells to fill", "A full battery also gives 3 s of 35% faster bite recharge"}),
		},
		attack = {
			path("blade", "Blade Claws", true, true, {
				"Mech sickle claws: pounce landing hits 35% harder", "Latch / pin bites tick 35% faster",
				"Pounce hits make the target bleed", "A pin kill gives back half your pounce stamina"}),
		},
		defense = {
			path("cloak", "Cloak Field", true, true, {
				"Button: nearly invisible for 3 s; bots lose you. Ends when you pounce, get hit or use another part",
				"Lasts 4.1 s", "A pounce out of the cloak hits 35% harder",
				"Standing still keeps you cloaked, up to twice as long"}),
			path("reactive", "Reactive Armor", true, true, {
				"Each hit you take charges the panels (6 hits); full = your next bite deals +35% damage", "4 hits to charge",
				"The charged bite also knocks the target back", "The charged bite also stuns for 0.75 s"}),
		},
		speed = {
			path("ramjet", "Ramjet Charge", true, true, {
				"Button: charge straight ahead at 1.75x run speed for 1 s; dinos in the way are knocked aside",
				"2 charges", "Lasts 1.35 s", "Hitting a dino stuns it for 0.75 s"}),
		},
		eng = {
			path("shieldproj", "Shield Projector", true, true, {
				"Button: a hard-light wall in front of you for 3 s that blocks hits and rockets", "Lasts 4.1 s",
				"Wider wall", "The wall moves with you"}),
			path("roaramp", "Roar Amplifier", true, true, {
				"Button: roar; enemies in the cone take 25% more damage for 5 s", "Lasts 6.75 s",
				"Enemies take 35% more damage", "The roar also shields allies near you (25% less damage for 5 s)"}),
		},
	}
	for _, a in ipairs(SkillTree.AREAS) do
		for _, p in ipairs(add[a.id] or {}) do table.insert(a.paths, p) end
	end
end
-- v1.9: raptor parts batch 2, appended to their areas
do
	local add = {
		attack = {
			path("screech", "Raptor Screech", true, true, {
				"Button: hold to aim, release to screech. The first dino hit flinches for 0.5 s and loses its cloak (a T-Rex is slowed)",
				"Reaches 35% farther", "Recharges 26% faster", "Jams parts: the hit dino's boost, Shield and Adrenaline end at once"}),
		},
		eng = {
			path("scent", "Scent Sense", true, true, {
				"Button: sniff. Trails of every dino that passed within 60 studs in the last 8 s glow for you for 6 s",
				"Wider: 81 studs", "Longer memory (10.8 s); the freshest end of each trail pulses",
				"Blood scent: bleeding dinos leave a blood trail you see all the time"}),
		},
	}
	for _, a in ipairs(SkillTree.AREAS) do
		for _, p in ipairs(add[a.id] or {}) do table.insert(a.paths, p) end
	end
end

SkillTree.PATHS = {}
SkillTree.PATH_ORDER = {}
for _, a in ipairs(SkillTree.AREAS) do
	for _, p in ipairs(a.paths) do
		p.area = a.id
		SkillTree.PATHS[p.id] = p
		table.insert(SkillTree.PATH_ORDER, p.id)
	end
end

-- v1.1: mecha parts that are built (buyable) and the ones that take a loadout slot
SkillTree.LIVE_MECH = {thrusters = true}
SkillTree.BUTTONS = {thrusters = true}
SkillTree.SLOTS = 2
-- v1.5: ownership, Cloak live, every button part listed, 4 slots
SkillTree.OWNER = {
	adrenaline = "Raptor", blade = "Raptor", cloak = "Raptor", shield = "Raptor", thrusters = "Raptor", -- v1.15: - dart, grapple, beacon, decoy
	repairdrone = "TRex", biobattery = "TRex", rocket = "TRex", armor = "TRex", reactive = "TRex", ramjet = "TRex",
	shieldproj = "TRex", roaramp = "TRex",
	medstation = "none", turret = "none", sentry = "none", traps = "none", barricade = "none",
}
for id, dino in pairs(SkillTree.OWNER) do
	if SkillTree.PATHS[id] then SkillTree.PATHS[id].dino = dino end
end
SkillTree.PATHS.regen.notFor = {TRex = true}
SkillTree.PATHS.jaws.notFor = {Raptor = true} -- v1.6 (Kepu: Blade Claws does the raptor's pounce upgrades)
SkillTree.LIVE_MECH.cloak = true
SkillTree.LIVE_MECH.blade = true -- v1.6: raptor batch 1
SkillTree.LIVE_MECH.adrenaline = true -- v1.6
SkillTree.LIVE_MECH.shield = true -- v1.6
SkillTree.PATHS.shield.steps[1] = "Button: block all damage for 1.5 s, but move at half speed while it's up" -- v1.6 (Kepu)
SkillTree.PATHS.shield.steps[4] = "Blocks even longer (2.77 s) and the slow is lighter" -- v1.6 (Kepu: no push-back)
SkillTree.PATHS.adrenaline.steps[1] = "Button: heal 25% of max health over 3 s and run 1.4x faster while it lasts" -- v1.7
SkillTree.PATHS.adrenaline.steps[2] = "Heal 34%" -- v1.7
-- v1.9: batch 2 owners, live, buttons; Dart Launcher / Pack Beacon shown to nobody
SkillTree.OWNER.screech, SkillTree.OWNER.scent = "Raptor", "Raptor"
for _, id in ipairs({"screech", "scent"}) do SkillTree.PATHS[id].dino = SkillTree.OWNER[id] end -- v1.15: dart / beacon deleted
SkillTree.LIVE_MECH.screech, SkillTree.LIVE_MECH.scent = true, true
SkillTree.BUTTONS.screech, SkillTree.BUTTONS.scent = true, true
-- v1.10: Raptor Screech is shown as Shock Dart (id "screech" kept)
SkillTree.PATHS.screech.name = "Shock Dart"
SkillTree.PATHS.screech.steps[1] = "Button: hold to aim (up to 100 studs), release to fire. The first dino hit flinches for 0.5 s and loses its cloak (a T-Rex is slowed)"
SkillTree.PATHS.screech.steps[2] = "Reaches 135 studs"
-- v1.11: Shock Cannon (id "screech" kept)
SkillTree.PATHS.screech.name = "Shock Cannon"
SkillTree.PATHS.screech.steps[1] = "Button: a shoulder cannon fires an electric ball (100 studs). The first dino hit is stunned for 1.1 s and loses its cloak"
SkillTree.PATHS.screech.steps[4] = "Stun lasts 1.5 s and jams parts: the hit dino's boost, Shield and Adrenaline end at once"
-- v1.12: Grapple scrapped (hidden); Traps -> the raptor's Shock Mine
SkillTree.OWNER.traps = "Raptor" -- v1.15: grapple deleted
SkillTree.PATHS.traps.dino = "Raptor"
SkillTree.LIVE_MECH.traps = true
SkillTree.BUTTONS.traps = true
SkillTree.PATHS.traps.name = "Shock Mine"
SkillTree.PATHS.traps.steps[1] = "Button: throw a mine 30 studs ahead. A dino that comes within 6 studs takes 15 damage and is slowed 50% for 2 s"
SkillTree.PATHS.traps.steps[2] = "2 mines out at once"
SkillTree.PATHS.traps.steps[3] = "Recharges 36% faster (8.8 s)"
SkillTree.PATHS.traps.steps[4] = "Mines also jam parts: the dino's boost, Shield and Adrenaline end at once"
SkillTree.PATHS.traps.steps[1] = "Button: throw a mine 30 studs ahead. A dino that comes within 6 studs takes 25 damage, is blasted 25 studs back and dazed for 1 s" -- v1.13
-- v1.14: Shock Cannon star = heavy shot; Decoy Hologram dropped
SkillTree.PATHS.screech.steps[4] = "Heavy shot: the hit also deals 30 damage"
for _, id in ipairs({"adrenaline", "cloak", "shield", "repairdrone", "rocket", -- v1.15: decoy, dart, grapple, beacon deleted
	"armor", "ramjet", "shieldproj", "roaramp"}) do
	SkillTree.BUTTONS[id] = true
end
SkillTree.SLOTS = 4
for id in pairs(SkillTree.LIVE_MECH) do
	if SkillTree.PATHS[id] then SkillTree.PATHS[id].soon = false end
end
-- v1.2: Thrusters is a steerable rocket boost
SkillTree.PATHS.thrusters.steps = {
	"Button: rocket boost for 1.5 s at 2x run speed (steer while boosting)",
	"2 charges",
	"Longer boost: 2 s",
	"Rocket hop: the boost starts with a 25-stud hop"}

-- v1.3: the 35% rule
SkillTree.STRONG = true
if SkillTree.STRONG then
	local P = SkillTree.PATHS
	P.regen.steps[2] = "Starts after 4.4 s, 3% per second"
	P.regen.steps[3] = "Starts after 3.2 s, 4.5% per second"
	P.jaws.steps[1] = "Main attack hits harder (+5 Attack points: T-Rex bite 25 -> 35)"
	P.jaws.steps[2] = "Main attack recharges 35% faster"
	P.hide.steps[1] = "Take 30% less damage (+6 Defense points)"
	P.hide.steps[3] = "Stuns are 30% shorter"
	P.legs.steps[1] = "Run 40% faster (+4 Speed points)"
	P.legs.steps[2] = "Run speed x1.9"
	P.legs.steps[3] = "Pounce, ram and leap recharge 35% faster"
	P.legs.steps[4] = "Run speed x2.6"
	P.thrusters.steps[1] = "Button: rocket boost for 1 s at 1.75x run speed (steer while boosting)" -- v1.4 (1.3: 1.5 s at 3x)
	P.thrusters.steps[3] = "Longer boost: 1.35 s" -- v1.4 (1.3: 2.1 s)
	P.thrusters.steps[1] = "Button: rocket boost for 1.37 s at 2x run speed (steer while boosting; in the air with no stick: straight up)" -- v1.8
	P.thrusters.steps[3] = "Longer boost: 1.85 s" -- v1.8
end
-- v1.17: Shock Mine rank II = 4th charge
SkillTree.MINE_FOURTH = true
if SkillTree.MINE_FOURTH then
	SkillTree.PATHS.traps.steps[1] = "Button: throw a mine 30 studs ahead (3 charges). A dino that comes within 6 studs takes 25 damage, is blasted 25 studs back and dazed for 1 s"
	SkillTree.PATHS.traps.steps[2] = "4th charge: 4 mines"
end
-- v1.16: gentle Sprint Legs (max +40%)
SkillTree.LEGS_GENTLE = true
if SkillTree.LEGS_GENTLE then
	local P = SkillTree.PATHS
	P.legs.steps[1] = "Run 10% faster (+1 Speed point)"
	P.legs.steps[2] = "Run 20% faster"
	P.legs.steps[4] = "Run 40% faster"
end
-- v1.18: "attack" instead of "pounce" in the step texts
SkillTree.ATTACK_WORDING = true
if SkillTree.ATTACK_WORDING then
	local P = SkillTree.PATHS
	P.blade.steps[1] = "Mech sickle claws: your attack lands 35% harder"
	P.blade.steps[3] = "Attack hits make the target bleed"
	P.blade.steps[4] = "A pin kill gives back half your attack stamina"
	P.cloak.steps[1] = "Button: nearly invisible for 3 s; bots lose you. Ends when you attack, get hit or use another part"
	P.cloak.steps[3] = "An attack out of the cloak hits 35% harder"
	P.legs.steps[3] = "Ram, leap and the raptor's attack recharge 35% faster"
end
-- v1.20: the pachy's own attack line, Battering Dome
SkillTree.BATTERING_DOME = true
if SkillTree.BATTERING_DOME and not SkillTree.PATHS.dome then
	local p = path("dome", "Battering Dome", false, false, {
		"Headbutt hits 25% harder",
		"Headbutt shoves 30% farther",
		"Headbutt charges refill 30% faster",
		"A 3rd headbutt charge, and spikes on your dome"})
	p.area = "attack"
	p.dino = "Pachy"
	SkillTree.OWNER.dome = "Pachy"
	for _, a in ipairs(SkillTree.AREAS) do
		if a.id == "attack" then table.insert(a.paths, p) end
	end
	SkillTree.PATHS.dome = p
	table.insert(SkillTree.PATH_ORDER, "dome")
end
-- v1.21: the pachy's Grappling Hook (button part)
SkillTree.HOOK_ARM = true
if SkillTree.HOOK_ARM and not SkillTree.PATHS.hookarm then
	local p = path("hookarm", "Grappling Hook", true, false, {
		"Button: lift your arm and fire a claw at a dino (60 studs); it is pulled in for a head smash: 10 damage and a knockback",
		"Reaches 80 studs",
		"Recharges faster (6 s)",
		"The smash hits harder: 15 damage"})
	p.area = "attack"
	p.dino = "Pachy"
	SkillTree.OWNER.hookarm = "Pachy"
	SkillTree.LIVE_MECH.hookarm = true
	SkillTree.BUTTONS.hookarm = true
	for _, a in ipairs(SkillTree.AREAS) do
		if a.id == "attack" then table.insert(a.paths, p) end
	end
	SkillTree.PATHS.hookarm = p
	table.insert(SkillTree.PATH_ORDER, "hookarm")
end
-- v1.22: the pachy's Mecha Legs (passive part)
SkillTree.MECHA_LEGS = true
if SkillTree.MECHA_LEGS and not SkillTree.PATHS.mechalegs then
	local p = path("mechalegs", "Mecha Legs", true, false, {
		"Piston-boosted leap: 25% farther forward. The leap now has a 6 s cooldown",
		"Leap 20% higher",
		"The leap cooldown recharges 35% faster (3.9 s)",
		"Mecha legs: jump again in mid-air (double jump), part of the same leap"})
	p.area = "speed"
	p.dino = "Pachy"
	SkillTree.OWNER.mechalegs = "Pachy"
	SkillTree.LIVE_MECH.mechalegs = true
	for _, a in ipairs(SkillTree.AREAS) do
		if a.id == "speed" then table.insert(a.paths, p) end
	end
	SkillTree.PATHS.mechalegs = p
	table.insert(SkillTree.PATH_ORDER, "mechalegs")
end
-- v1.23: Mecha Legs takes a slot (fires through the jump)
SkillTree.MECHA_LEGS_SLOT = true
SkillTree.MECHA_LEGS_STRONG = true -- v1.23: stronger numbers (read by effects())
if SkillTree.MECHA_LEGS_STRONG and SkillTree.PATHS.mechalegs then
	SkillTree.PATHS.mechalegs.steps = {
		"Piston-boosted leap: 50% farther forward and 20% more launch power. The leap now has a 6 s cooldown",
		"Leap launch power +45% (about twice as high)",
		"The leap cooldown recharges 35% faster (3.9 s)",
		"Mecha legs: jump again in mid-air at full leap power with a forward burst (double jump), part of the same leap"}
end
if SkillTree.MECHA_LEGS_SLOT and SkillTree.PATHS.mechalegs then SkillTree.BUTTONS.mechalegs = true end
-- v1.26: no Regeneration for the pachy
SkillTree.PACHY_NO_REGEN = true
if SkillTree.PACHY_NO_REGEN and SkillTree.PATHS.regen then
	SkillTree.PATHS.regen.notFor = SkillTree.PATHS.regen.notFor or {}
	SkillTree.PATHS.regen.notFor.Pachy = true
end
-- v1.27: no Lifesteal for the pachy
SkillTree.PACHY_NO_LIFESTEAL = true
if SkillTree.PACHY_NO_LIFESTEAL and SkillTree.PATHS.lifesteal then
	SkillTree.PATHS.lifesteal.notFor = SkillTree.PATHS.lifesteal.notFor or {}
	SkillTree.PATHS.lifesteal.notFor.Pachy = true
end
-- v1.29: the pachy's Med-Station (button part)
SkillTree.PACHY_MEDSTATION = true
if SkillTree.PACHY_MEDSTATION and SkillTree.PATHS.medstation then
	local p = SkillTree.PATHS.medstation
	p.dino = "Pachy"
	p.soon = false
	p.steps = {
		"Button: drop a Med-Station pad at your feet. Standing in its circle heals 10% of max health per second for 5 s (50%). Not while pinned or stunned",
		"Bigger heal area (12 -> 18 studs)",
		"Lasts longer: 7 s (up to 70%)",
		"Lasts 10 s: a full heal"}
	SkillTree.OWNER.medstation = "Pachy"
	SkillTree.LIVE_MECH.medstation = true
	SkillTree.BUTTONS.medstation = true
end
-- v1.30: the pachy's Bone Crest replaces Thick Hide (Defense)
SkillTree.PACHY_BONE_CREST = true
if SkillTree.PACHY_BONE_CREST and not SkillTree.PATHS.crest then
	local p = path("crest", "Bone Crest", false, false, {
		"Bites and pounces on your dome (from in front) do 20% less damage",
		"Dome bites do 30% less",
		"Dome bites do 40% less",
		"Whoever bites your dome takes 5 damage back"})
	p.area = "defense"
	p.dino = "Pachy"
	SkillTree.OWNER.crest = "Pachy"
	for _, a in ipairs(SkillTree.AREAS) do
		if a.id == "defense" then table.insert(a.paths, p) end
	end
	SkillTree.PATHS.crest = p
	table.insert(SkillTree.PATH_ORDER, "crest")
	SkillTree.PATHS.hide.notFor = SkillTree.PATHS.hide.notFor or {}
	SkillTree.PATHS.hide.notFor.Pachy = true
end
-- v1.28: stronger Lifesteal for the raptor (texts; the numbers are in effects)
SkillTree.RAPTOR_LIFESTEAL_STRONG = true
if SkillTree.RAPTOR_LIFESTEAL_STRONG and SkillTree.PATHS.lifesteal then
	local st = SkillTree.PATHS.lifesteal.steps
	SkillTree.PATHS.lifesteal.stepsFor = SkillTree.PATHS.lifesteal.stepsFor or {}
	SkillTree.PATHS.lifesteal.stepsFor.Raptor = {
		"20% of the damage you deal heals you",
		"35% of the damage you deal heals you",
		"50% of the damage you deal heals you",
		st[4]}
end
-- v1.24: the pachy's Blood Rush (slot part, fires through ATTACK)
SkillTree.BLOOD_RUSH = true
if SkillTree.BLOOD_RUSH and not SkillTree.PATHS.bloodrush then
	local p = path("bloodrush", "Blood Rush", true, false, {
		"Out of headbutt charges? ATTACK pays 25% of your max health for one more headbutt (above half health; 2, then not again until you are back at full health)",
		"Sacrifice headbutts hit 25% harder",
		"No self-slow after a sacrifice headbutt",
		"A sacrifice headbutt that lands slows the target hard: speed x0.45 for 4 s"})
	p.area = "attack"
	p.dino = "Pachy"
	SkillTree.OWNER.bloodrush = "Pachy"
	SkillTree.LIVE_MECH.bloodrush = true
	SkillTree.BUTTONS.bloodrush = true
	for _, a in ipairs(SkillTree.AREAS) do
		if a.id == "attack" then table.insert(a.paths, p) end
	end
	SkillTree.PATHS.bloodrush = p
	table.insert(SkillTree.PATH_ORDER, "bloodrush")
end
-- v1.19: no Jaws for the pachy
SkillTree.PACHY_NO_JAWS = true
if SkillTree.PACHY_NO_JAWS then
	SkillTree.PATHS.jaws.notFor = SkillTree.PATHS.jaws.notFor or {}
	SkillTree.PATHS.jaws.notFor.Pachy = true
end

-- level curve
function SkillTree.xpToNext(level)
	return 30 + 10 * (level - 1)
end

function SkillTree.levelOf(totalXp)
	local xp = tonumber(totalXp)
	if not xp or xp ~= xp or xp < 0 then xp = 0 end
	xp = math.floor(xp)
	local level = 1
	while level < SkillTree.MAX_LEVEL do
		local need = SkillTree.xpToNext(level)
		if xp < need then return level, xp, need end
		xp -= need
		level += 1
	end
	return SkillTree.MAX_LEVEL, xp, 0
end

function SkillTree.pointsOf(level)
	return math.clamp(math.floor(tonumber(level) or 1) - 1, 0, SkillTree.MAX_POINTS)
end

-- v1.5: which paths a dino sees
function SkillTree.seesPath(p, dino)
	if type(p) == "string" then p = SkillTree.PATHS[p] end
	if not p then return false end
	if dino == nil then return true end
	if p.dino == "none" then return false end
	if dino == "All" then return true end
	if p.dino == nil then return not (p.notFor and p.notFor[dino]) end
	return p.dino == dino
end

function SkillTree.pathsFor(areaId, dino)
	local shared, own = {}, {}
	for _, a in ipairs(SkillTree.AREAS) do
		if a.id == areaId then
			for _, p in ipairs(a.paths) do
				if SkillTree.seesPath(p, dino) then table.insert(p.dino == nil and shared or own, p) end
			end
		end
	end
	for _, p in ipairs(own) do table.insert(shared, p) end
	return shared
end

-- builds
function SkillTree.sanitize(raw, dino) -- v1.5: + dino
	local clean = {}
	for id, p in pairs(SkillTree.PATHS) do
		local n = type(raw) == "table" and raw[id] or nil
		if type(n) ~= "number" or n ~= n or p.soon or not SkillTree.seesPath(p, dino) then n = 0 end
		clean[id] = math.clamp(math.floor(n), 0, 4)
	end
	return clean
end

function SkillTree.spent(steps, dino) -- v1.5: + dino
	local s = 0
	for _, n in pairs(SkillTree.sanitize(steps, dino)) do
		for i = 1, n do s += SkillTree.COST[i] end
	end
	return s
end

-- v1.5: Mastery 3
function SkillTree.mastered(steps, dino)
	local clean, out = SkillTree.sanitize(steps, dino), {}
	for _, id in ipairs(SkillTree.PATH_ORDER) do
		if (clean[id] or 0) >= 3 then table.insert(out, id) end
	end
	return out
end

function SkillTree.masteryOk(steps, dino)
	return not SkillTree.BUILD_LIMITS or #SkillTree.mastered(steps, dino) <= SkillTree.MASTERY_MAX
end

function SkillTree.canBuy(steps, pathId, pointsEarned, dino) -- v1.5: + dino, otherDino, masteryFull
	local p = SkillTree.PATHS[pathId]
	if not p then return false, "unknownPath" end
	if not SkillTree.seesPath(p, dino) then return false, "otherDino" end
	if p.soon then return false, "soon" end
	local clean = SkillTree.sanitize(steps, dino)
	local n = clean[pathId]
	if n >= 4 then return false, "maxed" end
	if SkillTree.BUILD_LIMITS and n == 2 and #SkillTree.mastered(clean, dino) >= SkillTree.MASTERY_MAX then
		return false, "masteryFull"
	end
	local left = (tonumber(pointsEarned) or 0) - SkillTree.spent(clean, dino)
	if left < SkillTree.COST[n + 1] then return false, "noPoints" end
	return true, "ok"
end

function SkillTree.buy(steps, pathId, pointsEarned, dino) -- v1.5: + dino
	local ok, why = SkillTree.canBuy(steps, pathId, pointsEarned, dino)
	if not ok then return nil, why end
	local new = SkillTree.sanitize(steps, dino)
	new[pathId] += 1
	return new, "ok"
end

-- effects
function SkillTree.effects(steps, dino) -- v1.5: + dino
	local s = SkillTree.sanitize(steps, dino)
	local e = {attackPts = 0, defensePts = 0, speedPts = 0, regenDelay = 0, regenRate = 0, killRegenAdd = 0,
		lifesteal = 0, shieldMax = 0, shieldTime = 0, mainCdMul = 1, moveCdMul = 1, bleedDps = 0, bleedTime = 0,
		crushStun = 0, crushCooldown = 0, tossMul = 1, stunMul = 1, stunImmuneAbove = 0}
	-- Regeneration
	local r = s.regen
	if r >= 1 then e.regenDelay, e.regenRate = 6, 0.02 end
	if r >= 2 then e.regenDelay, e.regenRate = 5, 0.03 end
	if r >= 3 then e.regenDelay, e.regenRate = 4, 0.04 end
	if r >= 4 then e.killRegenAdd = 0.25 end
	-- Lifesteal
	local l = s.lifesteal
	if l >= 1 then e.lifesteal = 0.05 end
	if l >= 2 then e.lifesteal = 0.10 end
	if l >= 3 then e.lifesteal = 0.15 end
	if l >= 4 then e.shieldMax, e.shieldTime = 0.20, 6 end
	local md = s.medstation or 0 -- v1.29: Med-Station (pachy)
	e.medRadius, e.medTime, e.medRate, e.medCooldown = 0, 0, 0, 0
	if SkillTree.PACHY_MEDSTATION then
		if md >= 1 then e.medRadius, e.medTime, e.medRate, e.medCooldown = 12, 5, 0.10, 30 end
		if md >= 2 then e.medRadius = 18 end
		if md >= 3 then e.medTime = 7 end
		if md >= 4 then e.medTime = 10 end
	end
	e.lifestealRaptor = 0 -- v1.28
	if SkillTree.RAPTOR_LIFESTEAL_STRONG then
		if l >= 1 then e.lifestealRaptor = 0.20 end
		if l >= 2 then e.lifestealRaptor = 0.35 end
		if l >= 3 then e.lifestealRaptor = 0.50 end
	end
	-- Jaws (main attack)
	local j = s.jaws
	if j >= 1 then e.attackPts += 1 end
	if j >= 2 then e.mainCdMul = 0.9 end
	if j >= 3 then e.bleedDps, e.bleedTime = 3, 4 end
	if j >= 4 then e.crushStun, e.crushCooldown = 0.75, 4 end
	-- Thick Hide
	local h = s.hide
	if h >= 1 then e.defensePts += 1 end
	if h >= 2 then e.tossMul = 0.5 end
	if h >= 3 then e.stunMul = 0.75 end
	if h >= 4 then e.stunImmuneAbove = 0.5 end
	-- v1.30: Bone Crest (pachy)
	local bc = s.crest or 0
	e.crestMul, e.crestReflect = 1, 0
	if SkillTree.PACHY_BONE_CREST then
		if bc >= 1 then e.crestMul = 0.80 end
		if bc >= 2 then e.crestMul = 0.70 end
		if bc >= 3 then e.crestMul = 0.60 end
		if bc >= 4 then e.crestReflect = 5 end
	end
	-- Sprint Legs
	local g = s.legs
	if g >= 1 then e.speedPts += 1 end
	if g >= 2 then e.speedPts += 5 end -- run speed x1.5 (StatServer: +10% per point)
	if g >= 3 then e.moveCdMul = 0.85 end
	if g >= 4 then e.speedPts += 1 end
	-- v1.1: Thrusters
	e.dashCharges, e.dashDist, e.dashHop = 0, 0, 0
	local t = s.thrusters or 0
	if t >= 1 then e.dashCharges, e.dashDist = 1, 35 end
	if t >= 2 then e.dashCharges = 2 end
	if t >= 3 then e.dashDist = 50 end
	if t >= 4 then e.dashHop = 25 end
	-- v1.2: boost length
	e.dashTime = 0
	if t >= 1 then e.dashTime = 1.5 end
	if t >= 3 then e.dashTime = 2.0 end
	-- v1.3: the 35% rule (each step >= 1.35x the step before)
	if SkillTree.STRONG then
		if r >= 2 then e.regenDelay = 4.4 end
		if r >= 3 then e.regenDelay, e.regenRate = 3.2, 0.045 end
		e.attackPts = j >= 1 and 5 or 0
		if j >= 2 then e.mainCdMul = 0.74 end
		e.defensePts = h >= 1 and 6 or 0
		if h >= 3 then e.stunMul = 0.70 end
		e.speedPts = g >= 4 and 16 or g >= 2 and 9 or g >= 1 and 4 or 0
		if g >= 3 then e.moveCdMul = 0.74 end
		if t >= 1 then e.dashTime = 1.37 end -- v1.8: 1.37 (v1.4: 1.0; 1.3: 1.5)
		if t >= 3 then e.dashTime = 1.85 end -- v1.8: 1.85 (v1.4: 1.35; 1.3: 2.1)
	end
	-- v1.5: Cloak Field
	local c = s.cloak or 0
	e.cloakTime, e.cloakCooldown, e.cloakPounceMul, e.cloakStill = 0, 0, 1, false
	if c >= 1 then e.cloakTime, e.cloakCooldown = 3, 12 end
	if c >= 2 then e.cloakTime = 4.1 end
	if c >= 3 then e.cloakPounceMul = 1.35 end
	if c >= 4 then e.cloakStill = true end
	-- v1.6: Blade Claws (passive)
	local bl = s.blade or 0
	e.bladeLandBonus, e.bladeTickMul, e.bladeBleedDps, e.bladeBleedTime, e.bladePinRefund = 0, 1, 0, 0, 0
	if bl >= 1 then e.bladeLandBonus = 0.35 end
	if bl >= 2 then e.bladeTickMul = 0.74 end
	if bl >= 3 then e.bladeBleedDps, e.bladeBleedTime = 3, 4 end
	if bl >= 4 then e.bladePinRefund = 0.5 end
	-- v1.6: Adrenaline Injector
	local ad = s.adrenaline or 0
	e.adrenHeal, e.adrenTime, e.adrenSpeedMul, e.adrenCooldown, e.adrenStunClear = 0, 0, 1, 0, false
	if ad >= 1 then e.adrenHeal, e.adrenTime, e.adrenSpeedMul, e.adrenCooldown = 0.25, 3, 1.4, 20 end -- v1.7: 0.25 / 1.4 (was 0.20 / 1.3)
	if ad >= 2 then e.adrenHeal = 0.34 end -- v1.7 (was 0.27)
	if ad >= 3 then e.adrenCooldown = 14.8 end
	if ad >= 4 then e.adrenStunClear = true end
	-- v1.6: Energy Shield
	local sh = s.shield or 0
	e.eshieldTime, e.eshieldCooldown, e.eshieldSpeedMul = 0, 0, 1
	if sh >= 1 then e.eshieldTime, e.eshieldCooldown, e.eshieldSpeedMul = 1.5, 16, 0.5 end
	if sh >= 2 then e.eshieldTime = 2.05 end
	if sh >= 3 then e.eshieldCooldown = 11.8 end
	if sh >= 4 then e.eshieldTime, e.eshieldSpeedMul = 2.77, 0.68 end
	-- v1.9: Scent Sense
	local sc = s.scent or 0
	e.scentRadius, e.scentMemory, e.scentTime, e.scentCooldown, e.scentFresh, e.scentBlood = 0, 0, 0, 0, false, false
	if sc >= 1 then e.scentRadius, e.scentMemory, e.scentTime, e.scentCooldown = 60, 8, 6, 16 end
	if sc >= 2 then e.scentRadius = 81 end
	if sc >= 3 then e.scentMemory, e.scentFresh = 10.8, true end
	if sc >= 4 then e.scentBlood = true end
	-- v1.9: Raptor Screech
	local sr = s.screech or 0
	e.screechRange, e.screechFlinch, e.screechCooldown, e.screechJam = 0, 0, 0, false
	if sr >= 1 then e.screechRange, e.screechFlinch, e.screechCooldown = 100, 1.1, 14 end -- v1.10: 100 (was 50); v1.11: stun 1.1 (was 0.5)
	if sr >= 2 then e.screechRange = 135 end -- v1.10: 135 (was 67.5)
	if sr >= 3 then e.screechCooldown = 10.3 end -- 14 / 10.3 = 1.36 (10.4 failed the 35% rule)
	if sr >= 4 then e.screechJam, e.screechFlinch = true, 1.5 end -- v1.11: + stun 1.5 s
	e.screechDamage = 0 -- v1.14
	if sr >= 4 then e.screechJam, e.screechFlinch, e.screechDamage = false, 1.1, 30 end -- v1.14: star = heavy shot (no jam, no longer stun)
	-- v1.12: Shock Mine (path "traps")
	local tr = s.traps or 0
	e.mineDamage, e.mineSlow, e.mineSlowTime, e.mineCooldown, e.mineMax, e.mineJam = 0, 1, 0, 0, 0, false
	if tr >= 1 then e.mineDamage, e.mineSlow, e.mineSlowTime, e.mineCooldown, e.mineMax = 15, 0.5, 2, 12, 1 end
	e.mineLaunch, e.mineDaze = 0, 0 -- v1.13
	if tr >= 1 then e.mineDamage, e.mineLaunch, e.mineDaze = 25, 25, 1 end -- v1.13: blast + launch (damage was 15)
	if tr >= 2 then e.mineMax = 2 end
	if tr >= 3 then e.mineCooldown = 8.8 end -- 12 / 8.8 = 1.36
	if tr >= 4 then e.mineJam = true end
	if SkillTree.MINE_FOURTH and tr >= 2 then e.mineMax = 4 end -- v1.17: 4th charge
	if SkillTree.LEGS_GENTLE then -- v1.16: +10% / +20% / +40%
		e.speedPts = g >= 4 and 4 or g >= 2 and 2 or g >= 1 and 1 or 0
	end
	-- v1.20: Battering Dome (pachy)
	local bd = s.dome or 0
	e.hbDamageMul, e.hbShoveMul, e.hbRefillMul, e.hbExtraCharges, e.pachySpikes = 1, 1, 1, 0, false
	if bd >= 1 then e.hbDamageMul = 1.25 end
	if bd >= 2 then e.hbShoveMul = 1.3 end
	if bd >= 3 then e.hbRefillMul = 0.7 end
	if bd >= 4 then e.hbExtraCharges, e.pachySpikes = 1, true end
	-- v1.21: Grappling Hook (pachy)
	local hk = s.hookarm or 0
	e.hookRange, e.hookCooldown, e.hookDamage = 0, 0, 0
	if hk >= 1 then e.hookRange, e.hookCooldown, e.hookDamage = 60, 8, 10 end
	if hk >= 2 then e.hookRange = 80 end
	if hk >= 3 then e.hookCooldown = 6 end
	if hk >= 4 then e.hookDamage = 15 end
	-- v1.22: Mecha Legs (pachy)
	local ml = s.mechalegs or 0
	e.legsBoostMul, e.legsPowerMul, e.legsCooldown, e.legsCdMul, e.doubleJump, e.legsLook = 1, 1, 0, 1, false, false
	if ml >= 1 then e.legsBoostMul, e.legsCooldown = 1.25, 6 end
	if ml >= 2 then e.legsPowerMul = 1.2 end
	if ml >= 3 then e.legsCdMul = 0.65 end
	if ml >= 4 then e.doubleJump, e.legsLook = true, true end
	e.legsDoubleMul, e.legsDoubleForward = 0.894, 0 -- v1.23
	-- v1.24: Blood Rush (pachy)
	local br = s.bloodrush or 0
	e.bloodRush, e.bloodCost, e.bloodMax, e.bloodDamageMul, e.bloodNoSelfSlow, e.bloodSlowMul, e.bloodSlowTime =
		false, 0, 0, 1, false, 1, 0
	if br >= 1 then e.bloodRush, e.bloodCost, e.bloodMax = true, 0.25, 2 end
	if br >= 2 then e.bloodDamageMul = 1.25 end
	if br >= 3 then e.bloodNoSelfSlow = true end
	if br >= 4 then e.bloodSlowMul, e.bloodSlowTime = 0.45, 4 end
	if SkillTree.MECHA_LEGS_STRONG then -- v1.23: stronger leap and double jump
		if ml >= 1 then e.legsBoostMul, e.legsPowerMul = 1.5, 1.2 end
		if ml >= 2 then e.legsPowerMul = 1.45 end
		if ml >= 4 then e.legsDoubleMul, e.legsDoubleForward = 1, 15 end
	end
	return e
end

-- v1.1: loadout
local function slottable(clean, id) -- clean = sanitized with the dino (v1.5)
	local p = type(id) == "string" and SkillTree.PATHS[id]
	return p and SkillTree.BUTTONS[id] == true and not p.soon and (clean[id] or 0) >= 1 or false
end

function SkillTree.sanitizeLoadout(raw, steps, dino) -- v1.5: + dino
	local clean = SkillTree.sanitize(steps, dino)
	local out, seen = {}, {}
	for n = 1, SkillTree.SLOTS do
		local id = type(raw) == "table" and raw[n] or nil
		if slottable(clean, id) and not seen[id] then
			out[n], seen[id] = id, true
		else
			out[n] = false
		end
	end
	return out
end

function SkillTree.autoSlot(loadout, steps, pathId, dino) -- v1.5: + dino
	local out = SkillTree.sanitizeLoadout(loadout, steps, dino)
	if not slottable(SkillTree.sanitize(steps, dino), pathId) then return out end
	for n = 1, SkillTree.SLOTS do
		if out[n] == pathId then return out end
	end
	for n = 1, SkillTree.SLOTS do
		if out[n] == false then
			out[n] = pathId
			return out
		end
	end
	return out
end

function SkillTree.setSlot(loadout, steps, n, pathId, dino) -- v1.5: + dino
	if type(n) ~= "number" or n ~= math.floor(n) or n < 1 or n > SkillTree.SLOTS then return nil, "badSlot" end
	local out = SkillTree.sanitizeLoadout(loadout, steps, dino)
	if pathId == false or pathId == nil or pathId == "" then
		out[n] = false
		return out, "ok"
	end
	if type(pathId) ~= "string" or not SkillTree.PATHS[pathId] or SkillTree.BUTTONS[pathId] ~= true then
		return nil, "notButton"
	end
	if not slottable(SkillTree.sanitize(steps, dino), pathId) then return nil, "notOwned" end
	for m = 1, SkillTree.SLOTS do
		if out[m] == pathId then out[m] = false end
	end
	out[n] = pathId
	return out, "ok"
end

return SkillTree
