-- SkillTree v1.78 (1.78 troodon parts build 2 live: Last Feather / Overheal Plume / Fortify Field / Ricochet Pod; 1.77 dilo spit poison time halved: Venom Spit +0.75 s; 1.76 dilo Spring Jets 40 / 50 / 65 studs + Toxin Mortar cloud x1.5; 1.75 dilo spit only: Quick Draw = spit gap, Venom Bite = spit poison; 1.74 shot pass: projectile ranges x2 + 45-degree assist cones + texts; 1.73 balance pass 1: Razor Claws / Building Fury / Quick Draw kept over the new bases, texts; 1.72 troodon mecha parts; 1.71 Bola reach 60 / 80; 1.69 / 1.70 dilo mecha parts; 1.68 Goo Blob: 1.3x puddle, 50% slow, 3 s after leaving; 1.67 Feather Barrage range 35 / 40 / 50; 1.66 Overclock III: an extra jump; 1.65 therizino moves rework: vortex, bola, dash, reel; 1.64 grapple lock-on text; 1.63 grapple v2 + passive overclock; 1.49 teno abilities; 1.50 teno stats part 2; 1.55 teno leap on JUMP + Shield Armor; 1.56 mortar 90; 1.57 therizino stats; 1.58 Fourth Cut live; 1.59 pachy Last Stand + Head Down; 1.60 dilo stats; 1.61 therizino parts; 1.62 therizino parts build 2) (Mecha Dino Arena) — skill tree data and maths: areas, paths, step costs, the level curve, buy / respec
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
-- v1.38 (Kepu 2026-10-31 "Build"; plan docs/plans/HERRERA_PARTS_v1.0.md, MDA-149..156; mockups
--   docs/mockups/herrera_ironclaw_options.html B, herrera_parts_b1_options.html, herrera_parts_b2_options.html). Switch
--   SkillTree.HERRERA_PARTS (default true): the Herrera's 8 mecha parts, each mech, live (LIVE_MECH), a loadout slot
--   (BUTTONS), dino / OWNER "Herrera": ironclaw "Iron Claw" (attack), quills "Quill Launcher" (attack), glider "Glider
--   Wings" (speed), smoke "Smoke Pods" (eng), strobe "Strobe Frill" (eng), plating "Back Plating" (defense), breaker
--   "Stun Breaker" (defense), siphon "Blood Siphon" (health). effects() fields (off values when not bought):
--     ironClawDamageMul 1.1 / 1.2 / 1.3 / 1.5, ironClawSpeedMul 0.95 / 0.90 / 0.85 / 0.75, ironClawDust (III);
--     gliderFall 8 (I), gliderDrop (II), gliderDropMul 1.3 (III), gliderBurst 10 studs (star);
--     quillCount 5 / 8 / 12 / 17, quillDamage 4, quillRange 40, quillCooldown 20;
--     smokeRadius 12, smokeTime 4 / 6 (II), smokeRunMul 1.25 (III), smokeSlowMul 0.75 (star), smokeCooldown 18;
--     platingRearMul 0.90 / 0.85 / 0.78 / 0.70;
--     siphonRate 1 / 1.5 (II), siphonRange 15 / 25 (III), siphonKillHeal 0.25 (star);
--     strobeAngle 60 / 90 (III), strobeRange 20 / 25 (III), strobeDaze 1 / 1.5 (II), strobeDazedMul 1.2 (star),
--       strobeCooldown 16;
--     breaker (I), breakerPush 10 (II), breakerCooldown 20 / 14 (III), breakerImmune 1 (star).
-- v1.49 (teno mecha abilities, plan docs/plans/TENO_ABILITIES_v1.0.md Task 1, MDA-173; mockup
--   docs/mockups/teno_abilities_options.html v0.3, step texts from it; Mortar I worded for the auto-target Kepu picked).
--   Switch SkillTree.TENO_PARTS (default true): 7 teno-only mecha button parts (dino / OWNER "Teno", mech, BUTTONS):
--   tgrab "Tail Grab & Fling" (attack), tmortar "Boulder Mortar" (attack), tstomp "Stomp Shockwave" (defense), tbellow
--   "Herd Bellow" (health), tchallenge "Challenge Call" (defense), tleap "Hydraulic Leap" (speed), tmud "Mud Armor"
--   (defense). SkillTree.TENO_PARTS_SUPPORT_SOON (default true; build 1, Kepu "two builds"): tbellow / tchallenge / tmud
--   soon (not buyable, not LIVE_MECH); the other 4 are LIVE_MECH. effects() (teno only; off values elsewhere / unbought):
--   grabRange 12, grabFling 30 / 45 (II), grabDamage 8, grabStun 1, grabBig (III: pachy / teno size too), grabCrash 8 +
--   grabCrashRadius 8 (star), grabCooldown 16; mortarRange 60, mortarMiss 45, mortarCone 30, mortarDamage 12, mortarSplash
--   10 / 14 (II), mortarCount 1 / 2 (III), mortarSlowMul 0.7, mortarSlowTime 2, mortarRubble 4 (star), mortarCooldown 14;
--   stompRange 14 / 20 (III), stompDamage 6, stompStun 0.5 / 1 (II), stompNoJump 3 (star), stompCooldown 15; leapDist
--   40 / 55 (II), leapDamage 10, leapRadius 12, leapStun 0.5 (III), leapCharges 1 / 2 (star), leapCooldown 14;
--   bellowRange 25 / 40 (III), bellowTime 4 / 6 (II), bellowDamageMul 0.5, bellowRunMul 1.5, bellowClearStun (star),
--   bellowCooldown 30; challengeRange 30 / 45 (III), challengeTime 5 / 7 (II), challengeWeakMul 0.6, challengeSlowMul 0.8
--   (star), challengeCooldown 20; mudTime 8 / 12 (III), mudHits 3 / 4 (II), mudSlowRadius 15, mudSlowMul 0.6, mudSlowTime
--   4, mudSplash 12 (star), mudCooldown 20. Off: 0 / 1 (muls) / false.
-- v1.50 (teno stats part 2, plan docs/plans/TENO_STATS_v1.1.md, mockup docs/mockups/teno_stats_v0.2.html; Kepu 2026-11-01:
--   "Let's do heals on kills. Add heavy tail and look for one more" -> "Add a and b" -> "I like it"). Switch
--   SkillTree.TENO_STATS_2 (default true; false = 1.48 rows): three teno-only rows (dino / OWNER "Teno", mech false):
--   "survivor" Survivor (health), "heavytail" Heavy Tail (attack), "frontclaws" Front Claws (attack); the shared "hide"
--   row re-opened for the teno (notFor.Teno cleared) as "Armored Hide" (nameFor / stepsFor Teno). The teno's rows read
--   survivor, heavytail, frontclaws, hide, brace, chargeup, buckoff. effects() (teno only; off values elsewhere):
--   survivorKillHeal 0.15 / 0.25 (II), survivorNearHeal 0.10 + survivorNearRange 25 (III), survivorRefill (star);
--   heavyBonus 3, heavyRefillMul 0.75 (II), heavyReachMul 1.2 (III), heavySlow 0.3 + heavySlowTime 3 (star); clawBonus 3,
--   clawCone 130 (II; 0 = the default 90), clawGap 0.35 (III; 0 = the default), clawSlow 0.3 + clawSlowTime 1.5 (star);
--   Armored Hide: 2 Defense points at I (10%; Thick Hide gives 6 under the 35% rule), stunMul 0.7 at III (as Thick Hide);
--   toss / immune as Thick Hide.
-- v1.48 (Kepu 2026-11-01, tail slam rework): Buck Off star text + effects field buckCharge (1 at star, 0 otherwise / other
--   dinos); SkillEffects 1.32 writes it as TenoSlamExtraCharges. Switch SkillTree.TENO_BUCK_CHARGE (default true).
-- v1.47 (Kepu 2026-11-01: "the herrerra has too many stackable stat upgrades ... look over the redundant ones to make this
--   a fair dino" -> picked "Trim overlap"). Switch SkillTree.HERRERA_TRIM (default true; false = 1.46):
--   * Removed for the Herrera (saved steps dropped by sanitize, so spent points come back): Regeneration (notFor.Herrera),
--     Blood Siphon and Iron Claw (dino / OWNER "none": shown to nobody, like Dart Launcher). Its heals: Blood Drinker
--     (lifesteal) + Adrenaline Injector (button); its slash damage row: Razor Claws.
--   * Razor Claws I: +3 Attack points (was +5; slash 7 -> 10), III: slash bleed 3 per second (was 5).
--   * Blood Frenzy II: bleed lasts 5 s (was 6), III: +2 on a bleeding dino (was +3).
--   Maxed Herrera: slash on a bleeding dino 12 (was 19 with Iron Claw), bleed per hit 15 (was 30). Other dinos unchanged.
-- v1.46 (Kepu 2026-10-31: Herrera damage "a little too strong" -> "Both a little"; HerreraModelData 1.3 slash 8 -> 7, bleed
--   3 -> 2 per second): Razor Claws step texts only - I "slash 7 -> 12", III "(was 2)". Effects unchanged.
-- v1.45 (Tenontosaurus stat rows, plan docs/plans/TENO_STATS_v1.0.md, mockup docs/mockups/teno_stats_options.html; Kepu
--   2026-10-31: "No life steal and no regeneration for this one", speed C, defense C, signature 2 "Buck Off", "No attack
--   row", stun rule "Off only while stunned"). Switch SkillTree.TENO_STATS (default true; false = 1.44):
--   * PATHS regen / lifesteal / jaws / hide / legs get notFor.Teno (the teno sees none of the shared stat rows).
--   * New area "sig" (Signature, rgb(201, 162, 255)) and three teno-only rows (dino / OWNER "Teno", mech false):
--     "chargeup" Charge Up (speed), "brace" Brace (defense), "buckoff" Buck Off (sig).
--   * effects(): chargeMul1 1.1 (I), chargeMul2 1.2 (II; = chargeMul1 below II), chargeNoShove (II), chargeBump 10 (III),
--     chargeBumpStun 0.5 (star); braceMul 0.8 (I), braceNoStun (II), braceStack 3 (III), braceHeal 0.05 (star); buckBonus 10
--     (I), buckFree (II), buckImmune 2 (III), buckDps 3 (star). Off values (1 / false / 0) on every other build.
--     SkillEffects 1.31 writes them, TenoStatsServer 1.0 / TenoAttackServer 1.1 act on them.
-- v1.44 (Kepu 2026-10-31: "Slotted parts and equipped stats show up. Anything not equipped is not shown"; Blade Claws
--   picked "Make it a raptor stat line"): SkillTree.RAPTOR_BLADE_STAT (default true): "blade" Blade Claws gets mech = false
--   (a raptor stat row in Attack, listed under STATS in the Lab, bought like the other rows) instead of an "always on" mecha
--   card that could not be slotted. It stays in LIVE_MECH (the Studio test layer still gives it at star) and keeps its path
--   id, steps and effects, so bought steps carry over; BladeLook (Mecha_Blade) still shows once owned, like the
--   Herrera's stat rows. Set false = 1.43.
-- v1.43 (Kepu 2026-10-31 16:26: "the herrerra changes we made need to be their own stat lines, the claws the blood sucker.
--   Remove the speed debuff from the claws but make the damage 25% more max"; picked "Move to STATS rows, keep looks",
--   "+5 / +10 / +15 / +25%", plating too):
--   * SkillTree.HERRERA_PASSIVE_STATS (default true): "ironclaw", "siphon" and "plating" get mech = false (Herrera stat rows
--     in their areas Attack / Health / Defense, bought like Tree Stalker / Blood Frenzy; the Lab lists them under STATS) and
--     leave BUTTONS. They stay in LIVE_MECH (the test layer still gives them at star) and keep their path ids, so bought
--     steps carry over; HerreraPartsServer still shows their looks.
--   * SkillTree.HERRERA_IRONCLAW_TUNE (default true): Iron Claw = slash damage x HERRERA_IRONCLAW_MULS (1.05 / 1.10 / 1.15 /
--     1.25), no run-speed change (ironClawSpeedMul 1); step texts "+5%" / "+10%" / "+15%" / "+25%".
--   * SkillTree.HERRERA_PASS3 (default true; plan docs/plans/HERRERA_PARTS_v1.0.md Pass 3, MDA-164): Herrera button parts
--     "caltrops" Razor Caltrops (eng), "goo" Goo Blob Shooter (eng), "hadren" Adrenaline Injector (health). Effects (off
--     values when not bought): caltropCount 6 / 10 (II), caltropRadius 5 / 7 (II; half the patch width), caltropTime 8 / 14
--     (III), caltropHidden (star), caltropBleedDps 3, caltropBleedTime 3, caltropSlowMul 0.7, caltropSlowTime 1,
--     caltropCooldown 16; gooToss 30, gooRadius 8 / 11 (II), gooTime 5 / 8 (star), gooCount 1 / 2 (III), gooSlowMul 0.6,
--     gooCooldown 14, gooAssistAngle 30, gooAssistMin 15, gooAssistMax 45; hadren on a Herrera: adrenHeal 0.25 / 0.34 (II),
--     adrenTime 3, adrenSpeedMul 1.4, adrenCooldown 20 / 14.8 (III), adrenStunClear false, adrenSlashRefill (star).
-- v1.42 (Kepu 2026-10-31: "Blood siphon should be passive actually"): with SkillTree.HERRERA_SIPHON_PASSIVE (default
--   true) "siphon" leaves BUTTONS: it takes no loadout slot and works whenever it is bought (SkillEffects 1.28), like the
--   raptor's Blade Claws. The Lab lists it with the always-on parts on the STATS tab ("Mech part · always on"); a saved
--   loadout slot holding it is dropped by sanitizeLoadout (not slottable). Step texts and effects unchanged.
--   Kepu, right after: "And claws" -> SkillTree.HERRERA_IRONCLAW_PASSIVE (default true): "ironclaw" (Iron Claw) leaves
--   BUTTONS the same way. Then "Yes make it passive too" -> SkillTree.HERRERA_PLATING_PASSIVE (default true): "plating"
--   (Back Plating) too. Then Kepu "Boost the darts up 8" (picked "5 / 6 / 7 / 8"): HERRERA_QUILL_COUNTS = 5 / 6 / 7 / 8
--   (1.41: 3 / 4 / 5 / 6) and the Quill Launcher step texts.
-- v1.41 (Kepu 2026-10-31 after playing pass 2: "We need the smoke cloud to be way bigger and thicker. Also lower the
--   quill count to 6 quills"; picked smoke "B · 28 studs, 260 puffs" and quills "3 / 4 / 5 / 6"): switch
--   SkillTree.HERRERA_TUNE_1 (default true). effects() is wrapped (the 1.38 maths unchanged inside): on a Herrera with the
--   parts on, quillCount = 3 / 4 / 5 / 6 for I-star (was 5 / 8 / 12 / 17; 4 damage each, 40 studs, 20 s unchanged) and
--   smokeRadius = 28 (was 12; time 4 / 6 s, run and slow steps unchanged). The Lab step texts of Quill Launcher and Smoke
--   Pods say the same. The thicker puffs are HerreraMovesFX 1.1.
-- v1.40 (Herrera parts pass 2 built: HerreraMovesServer 1.0, GliderTest 1.0, HerreraMovesFX 1.0): HERRERA_PASS2_SOON
--   = false, so Glider Wings, Quill Launcher, Smoke Pods, Strobe Frill and Stun Breaker are live (buyable, slottable, in
--   LIVE_MECH). Set it back to true to hide them as SOON again (1.39).
-- v1.39 (Kepu 2026-10-31, publishing pass 1: the 5 parts whose moves come in pass 2 go out as "Mark them SOON"): with
--   SkillTree.HERRERA_PASS2_SOON (default true) glider, quills, smoke, strobe and breaker get soon = true and leave
--   LIVE_MECH: shown in the Lab as SOON, not buyable (canBuy "soon"), not given by SkillServer's Studio test layer.
--   Iron Claw, Back Plating and Blood Siphon stay live. Set false when pass 2 ships.
-- v1.37 (Kepu 2026-10-31: "you keep applying these to any new Dino ... I need you to just have a generalized stat line that
--   can be customized to the Dino"; mockup docs/mockups/stat_lines_per_dino_options.html option A "Same rows, own names",
--   new rows Tree Stalker + Blood Frenzy; plan docs/plans/STAT_LINES_v1.0.md). Switch SkillTree.HERRERA_STATS (default true):
--   * path.nameFor[dino] (new, like stepsFor): the name that dino sees. The Herrera: Lifesteal -> "Blood Drinker",
--     Jaws -> "Razor Claws", Thick Hide -> "Wiry Frame", Sprint Legs -> "Scurry Legs" (same path ids, so saved steps
--     keep their pips), each with its own stepsFor.
--   * Sprint Legs III text per dino (stepsFor TRex / Raptor / Pachy / Herrera) names only that dino's own moves.
--   * New area "hunt" (Hunt, rgb(201, 162, 255)) and two Herrera-only paths: "stalker" Tree Stalker (hunt) and "frenzy"
--     Blood Frenzy (attack).
--   * effects(steps, "Herrera"): Jaws II-star off (mainCdMul 1, bleedDps / bleedTime / crush 0) and instead
--     slashRefillMul 0.65 (II), slashBleedDps 5 (III), slashExtraCharges 1 (star); Sprint Legs III climbSpeedMul 1.35;
--     Tree Stalker diveRangeMul 55/40, diveRefill, treeTopHidden, diveStun 0.5; Blood Frenzy frenzySpeedMul 1.1,
--     slashBleedTime 6, bleedBonus 3, killRefill. These fields are 1 / 0 / false on every other dino.
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
-- v1.31 (Kepu 2026-10-30: "It only takes 5 damage back for biters. Not slashers."; BoneCrest 1.1): Bone Crest star text
--   reads "Biters that bite your dome take 5 damage back (not raptor slashes)"; Kepu: "So for example a raptor wouldn't take
--   5 damage back".
-- v1.32 (pachy parts batch 3, MDA-126..128, plan docs/plans/PACHY_PARTS_B3_v1.0.md, mockup
--   docs/mockups/pachy_parts_b3_options.html, Kepu: "All the recommended ones"): three pachy-only live slot parts
--   (OWNER Pachy, LIVE_MECH, BUTTONS), each behind its own switch:
--   * "servodash" Overclocked Servo Dash (Speed; SkillTree.PACHY_SERVO_DASH): effects servoTime 1.5 (II 2), servoCd 12
--     (III 8), servoMul 1.6, servoRefill (star true).
--   * "visor" Dome Visor (Defense; SkillTree.PACHY_DOME_VISOR): visorTime 1.5 (II 2), visorCd 14 (III 10), visorKnock (star
--     true).
--   * "ink" Ink Shooter (Engineering; SkillTree.PACHY_INK_SHOOTER): inkRange 60 (II 80), inkCd 15 (III 11), inkBlind 2,
--     inkSplash 6 at star (0 below). All fields 0 / false below step I. false = 1.31 for that part.
-- v1.33 (Kepu 2026-10-30: "the speed boost was not significant at all. At least 2x speed" -> "1 s / 1.5 s"; "Just give it
--   goggles that create a force field" -> mockup docs/mockups/pachy_visor_goggles_options.html A "Curved shield wall"):
--   * SkillTree.SERVO_DASH_2X (default true): servoMul 2 (was 1.6), servoTime 1 s at I, 1.5 s from II (was 1.5 / 2);
--     step texts I and II say so. servoCd / servoRefill unchanged. false = 1.32 numbers.
--   * SkillTree.VISOR_GOGGLES (default true): Dome Visor step I text describes the goggles' force field and adds ink
--     (InkServer 1.1). Numbers unchanged.
-- v1.34 (pachy Tether Spike, Engineering, MDA-129; Kepu 2026-10-30: "a tether spike where if it lands it latches the person to
--   a chain to the ground ... It will launch like a splash. So it will shoot vertical and do a splash area that you're
--   aiming at"; mockup docs/mockups/pachy_tether_options.html B "Tail-base launcher"; answers: hold / circle / release,
--   8-stud circle, 60 range, only the closest dino, 10 studs / 2.5 s, star yank, Energy Shield blocks it):
--   SkillTree.PACHY_TETHER (default true) adds the pachy part "tether" ("Tether Spike", eng, OWNER Pachy, LIVE_MECH,
--   BUTTONS). effects(): tetherRange 60, tetherSplash 8, tetherReach 10, tetherTime 2.5 (II 3.5), tetherCd 14 (III 10),
--   tetherYank (star: true; the chain pulls them to tetherYankReach 5). All 0 / false below step I.
-- v1.35 (Kepu 2026-10-30 after playing v205: "the radius is so short" -> "Range: 60 to 90 studs"): SkillTree.TETHER_RANGE_90
--   (default true) tetherRange 90 (was 60) and step I text "(90 studs)". false = 1.34.
-- v1.36 (Kepu 2026-10-30: "I need the splash radius to be larger and the time it's holding an enemy down to be longer" ->
--   "15 studs", "4 s / 5 s"): SkillTree.TETHER_BIGGER (default true) tetherSplash 15 (was 8), tetherTime 4 s at I, 5 s from
--   II (was 2.5 / 3.5); step texts I / II follow (tap to aim, as MechaButtons 1.22). false = 1.35.
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
-- v1.32: pachy parts batch 3 (button parts)
do
	local function addPart(flag, id, name, area, steps)
		if not flag or SkillTree.PATHS[id] then return end
		local p = path(id, name, true, false, steps)
		p.area = area
		p.dino = "Pachy"
		SkillTree.OWNER[id] = "Pachy"
		SkillTree.LIVE_MECH[id] = true
		SkillTree.BUTTONS[id] = true
		for _, a in ipairs(SkillTree.AREAS) do
			if a.id == area then table.insert(a.paths, p) end
		end
		SkillTree.PATHS[id] = p
		table.insert(SkillTree.PATH_ORDER, id)
	end
	SkillTree.PACHY_SERVO_DASH = true
	addPart(SkillTree.PACHY_SERVO_DASH, "servodash", "Overclocked Servo Dash", "speed", {
		"Button: hip thrusters launch you forward, then you run 1.6x top speed for 1.5 s and ignore the headbutt slow",
		"Lasts 2 s",
		"Recharges in 8 s (was 12 s)",
		"Ending the dash refills one headbutt charge"})
	SkillTree.PACHY_DOME_VISOR = true
	addPart(SkillTree.PACHY_DOME_VISOR, "visor", "Dome Visor", "defense", {
		"Button: an armored faceplate drops for 1.5 s and blocks every bite, pounce, headbutt, hook smash and Shock Cannon shot from the front. You can still headbutt",
		"Lasts 2 s",
		"Recharges in 10 s (was 14 s)",
		"A hit the visor blocks knocks the attacker back"})
	SkillTree.PACHY_INK_SHOOTER = true
	addPart(SkillTree.PACHY_INK_SHOOTER, "ink", "Ink Shooter", "eng", {
		"Button: aim and fire an ink glob (60 studs). The first dino hit is blinded for 2 s: a player's screen goes black, a bot forgets you",
		"Reaches 80 studs",
		"Recharges in 11 s (was 15 s)",
		"The ink splashes: everyone within 6 studs of the hit is blinded too"})
	SkillTree.SERVO_DASH_2X = true -- v1.33
	if SkillTree.PACHY_SERVO_DASH and SkillTree.SERVO_DASH_2X and SkillTree.PATHS.servodash then
		local st = SkillTree.PATHS.servodash.steps
		st[1] = "Button: hip thrusters blast you forward, then you run 2x top speed for 1 s and ignore the headbutt slow"
		st[2] = "Lasts 1.5 s"
	end
	SkillTree.VISOR_GOGGLES = true -- v1.33
	if SkillTree.PACHY_DOME_VISOR and SkillTree.VISOR_GOGGLES and SkillTree.PATHS.visor then
		SkillTree.PATHS.visor.steps[1] = "Button: your goggles project a force field in front of you for 1.5 s that blocks every bite, pounce, headbutt, hook smash, Shock Cannon shot and ink glob from the front. You can still headbutt"
	end
	SkillTree.PACHY_TETHER = true -- v1.34
	addPart(SkillTree.PACHY_TETHER, "tether", "Tether Spike", "eng", {
		"Button: hold to aim a landing circle, let go to lob a spike (60 studs). The closest dino caught in the 8-stud circle is chained to the ground: it can't go more than 10 studs from the spike for 2.5 s",
		"Chained for 3.5 s",
		"Recharges in 10 s (was 14 s)",
		"The chain yanks them in close to the spike (5 studs)"})
	SkillTree.TETHER_RANGE_90 = true -- v1.35
	if SkillTree.PACHY_TETHER and SkillTree.TETHER_RANGE_90 and SkillTree.PATHS.tether then
		SkillTree.PATHS.tether.steps[1] = "Button: hold to aim a landing circle (tilt the camera to move it nearer or farther), let go to lob a spike (90 studs). The closest dino caught in the 8-stud circle is chained to the ground: it can't go more than 10 studs from the spike for 2.5 s"
	end
	SkillTree.TETHER_BIGGER = true -- v1.36
	if SkillTree.PACHY_TETHER and SkillTree.TETHER_BIGGER and SkillTree.PATHS.tether then
		SkillTree.PATHS.tether.steps[1] = "Button: tap to aim from above (move the circle, keep walking), tap again to lob a spike (90 studs). The closest dino caught in the 15-stud circle is chained to the ground: it can't go more than 10 studs from the spike for 4 s"
		SkillTree.PATHS.tether.steps[2] = "Chained for 5 s"
	end
end
-- v1.30: the pachy's Bone Crest replaces Thick Hide (Defense)
SkillTree.PACHY_BONE_CREST = true
if SkillTree.PACHY_BONE_CREST and not SkillTree.PATHS.crest then
	local p = path("crest", "Bone Crest", false, false, {
		"Bites and pounces on your dome (from in front) do 20% less damage",
		"Dome bites do 30% less",
		"Dome bites do 40% less",
		"Biters that bite your dome take 5 damage back (not raptor slashes)"}) -- v1.31: biters only
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
-- v1.37: one stat-line shape, each dino its own rows (mockup docs/mockups/stat_lines_per_dino_options.html option A;
--   Kepu 2026-10-31 "you wouldn't call it jaws here because the herera doesn't use jaws at all"; new rows Tree Stalker
--   and Blood Frenzy)
SkillTree.HERRERA_STATS = true
if SkillTree.HERRERA_STATS and not SkillTree.PATHS.stalker then
	local P = SkillTree.PATHS
	local function nameFor(id, dino, name)
		P[id].nameFor = P[id].nameFor or {}
		P[id].nameFor[dino] = name
	end
	local function stepsFor(id, dino, steps)
		P[id].stepsFor = P[id].stepsFor or {}
		P[id].stepsFor[dino] = steps
	end
	nameFor("lifesteal", "Herrera", "Blood Drinker")
	stepsFor("lifesteal", "Herrera", {
		"5% of your slash and bleed damage heals you",
		"10% of your slash and bleed damage heals you",
		"15% of your slash and bleed damage heals you",
		"Healing past full becomes a shield (up to 20% of max health, lasts 6 s)"})
	nameFor("jaws", "Herrera", "Razor Claws")
	stepsFor("jaws", "Herrera", {
		"Slash hits harder (+5 Attack points: slash 7 -> 12)",
		"Slash charges refill 35% faster (4 s -> 2.6 s)",
		"Bleed burns hotter: 5 per second (was 2)",
		"A 3rd slash charge"})
	nameFor("hide", "Herrera", "Wiry Frame")
	stepsFor("hide", "Herrera", {P.hide.steps[1], "Less knockback: thrown half as far by rams and shoves", P.hide.steps[3],
		P.hide.steps[4]})
	nameFor("legs", "Herrera", "Scurry Legs")
	stepsFor("legs", "Herrera", {P.legs.steps[1], P.legs.steps[2], "Climb 35% faster", P.legs.steps[4]})
	-- Sprint Legs III names only that dino's own moves
	stepsFor("legs", "TRex", {P.legs.steps[1], P.legs.steps[2], "Ram and leap recharge 35% faster", P.legs.steps[4]})
	stepsFor("legs", "Raptor", {P.legs.steps[1], P.legs.steps[2], "Pounce and leap recharge 35% faster", P.legs.steps[4]})
	stepsFor("legs", "Pachy", {P.legs.steps[1], P.legs.steps[2], "Leap recharges 35% faster", P.legs.steps[4]})
	-- the Herrera's own rows: Tree Stalker (new area Hunt) and Blood Frenzy (attack)
	table.insert(SkillTree.AREAS, {id = "hunt", name = "Hunt", color = {201, 162, 255}, paths = {}})
	local function add(id, name, areaId, steps)
		local p = path(id, name, false, false, steps)
		p.area = areaId
		p.dino = "Herrera"
		SkillTree.OWNER[id] = "Herrera"
		for _, a in ipairs(SkillTree.AREAS) do
			if a.id == areaId then table.insert(a.paths, p) end
		end
		P[id] = p
		table.insert(SkillTree.PATH_ORDER, id)
	end
	add("stalker", "Tree Stalker", "hunt", {
		"Drop attack reaches 55 studs (was 40)",
		"Landing a drop attack refills a slash charge",
		"On a tree top, enemies cannot see your name or health bar",
		"A drop attack hit stuns for 0.5 s"})
	add("frenzy", "Blood Frenzy", "attack", {
		"Run 10% faster while an enemy near you bleeds",
		"Bleed lasts 6 s (was 4)",
		"Slash a bleeding dino: +3 damage",
		"A kill while they bleed refills all slash charges"})
end
-- v1.38: the Herrera's mecha parts
SkillTree.HERRERA_PARTS = true
if SkillTree.HERRERA_PARTS and not SkillTree.PATHS.ironclaw then
	local function part(id, name, areaId, steps)
		local p = path(id, name, true, false, steps)
		p.area = areaId
		p.dino = "Herrera"
		SkillTree.OWNER[id] = "Herrera"
		SkillTree.LIVE_MECH[id] = true
		SkillTree.BUTTONS[id] = true
		for _, a in ipairs(SkillTree.AREAS) do
			if a.id == areaId then table.insert(a.paths, p) end
		end
		SkillTree.PATHS[id] = p
		table.insert(SkillTree.PATH_ORDER, id)
	end
	part("ironclaw", "Iron Claw", "attack", {
		"Iron hook blades: slash damage +10%, run 5% slower",
		"Slash damage +20%, run 10% slower",
		"Slash damage +30%, run 15% slower",
		"Slash damage +50%, run 25% slower"})
	part("quills", "Quill Launcher", "attack", {
		"Button: fire 5 quills at your target, 4 damage each (40 studs). Recharges in 20 s",
		"8 quills", "12 quills", "17 quills"})
	part("glider", "Glider Wings", "speed", {
		"Hold JUMP in the air to glide: fall at 8 studs/s and keep your run speed",
		"SLASH while gliding = drop attack on anything below (55 studs)",
		"Drop attack from a glide +30% damage",
		"The glide drop lands with a bleed burst (10 studs around)"})
	part("smoke", "Smoke Pods", "eng", {
		"Button: a smoke cloud (12 studs) for 4 s. Inside it your name and health bar are hidden and bots lose you. Recharges in 18 s",
		"The cloud lasts 6 s", "Run 25% faster inside the smoke", "Enemies inside the smoke are slowed 25%"})
	part("strobe", "Strobe Frill", "eng", {
		"Button: your frill flashes in a 60° cone (20 studs). Enemies in it are dazed (can't attack) for 1 s. Recharges in 16 s",
		"Daze lasts 1.5 s", "Cone 90°, 25 studs", "Dazed enemies take +20% damage"})
	part("plating", "Back Plating", "defense", {
		"Steel plates on your back: hits from behind -10% damage",
		"Hits from behind -15%", "Hits from behind -22%", "Hits from behind -30%"})
	part("breaker", "Stun Breaker", "defense", {
		"Button (while stunned or pinned): break free. Recharges in 20 s",
		"Breaking free pushes enemies near you back 10 studs", "Recharges in 14 s", "1 s of no damage after breaking free"})
	part("siphon", "Blood Siphon", "health", {
		"Heal 1 HP/s for each bleeding enemy within 15 studs",
		"1.5 HP/s each", "Range 25 studs", "A bleed kill near you heals 25% of your max health"})
end
-- v1.39: the pass-2 parts are SOON until their moves are built
SkillTree.HERRERA_PASS2_SOON = true
SkillTree.HERRERA_PASS2_SOON = false -- v1.40: pass 2 built
-- v1.41: Kepu's tuning after playing pass 2 (step texts here, numbers in the effects() wrapper at the end)
SkillTree.HERRERA_TUNE_1 = true
SkillTree.HERRERA_QUILL_COUNTS = {3, 4, 5, 6}
SkillTree.HERRERA_QUILL_COUNTS = {5, 6, 7, 8} -- v1.42: "Boost the darts up 8"
SkillTree.HERRERA_SMOKE_RADIUS = 28
-- v1.42: Blood Siphon is passive (no slot)
SkillTree.HERRERA_SIPHON_PASSIVE = true
if SkillTree.HERRERA_PARTS and SkillTree.HERRERA_SIPHON_PASSIVE then SkillTree.BUTTONS.siphon = nil end
SkillTree.HERRERA_IRONCLAW_PASSIVE = true -- v1.42: "And claws"
if SkillTree.HERRERA_PARTS and SkillTree.HERRERA_IRONCLAW_PASSIVE then SkillTree.BUTTONS.ironclaw = nil end
SkillTree.HERRERA_PLATING_PASSIVE = true -- v1.42: "Yes make it passive too"
if SkillTree.HERRERA_PARTS and SkillTree.HERRERA_PLATING_PASSIVE then SkillTree.BUTTONS.plating = nil end
if SkillTree.HERRERA_PARTS and SkillTree.HERRERA_TUNE_1 then
	if SkillTree.PATHS.quills then
		SkillTree.PATHS.quills.steps = {"Button: fire 5 quills at your target, 4 damage each (40 studs). Recharges in 20 s",
			"6 quills", "7 quills", "8 quills"} -- v1.42 (1.41: 3 / 4 / 5 / 6)
	end
	if SkillTree.PATHS.smoke then
		SkillTree.PATHS.smoke.steps = {"Button: a big smoke cloud (28 studs) for 4 s. Inside it your name and health bar are hidden and bots lose you. Recharges in 18 s",
			"The cloud lasts 6 s", "Run 25% faster inside the smoke", "Enemies inside the smoke are slowed 25%"}
	end
end
if SkillTree.HERRERA_PARTS and SkillTree.HERRERA_PASS2_SOON then
	for _, id in ipairs({"glider", "quills", "smoke", "strobe", "breaker"}) do
		if SkillTree.PATHS[id] then
			SkillTree.PATHS[id].soon = true
			SkillTree.LIVE_MECH[id] = nil
		end
	end
end

-- v1.43: claws / siphon / plating are Herrera stat rows; Iron Claw retuned; pass 3 parts
SkillTree.HERRERA_PASSIVE_STATS = true
if SkillTree.HERRERA_PARTS and SkillTree.HERRERA_PASSIVE_STATS then
	for _, id in ipairs({"ironclaw", "siphon", "plating"}) do
		local p = SkillTree.PATHS[id]
		if p then
			p.mech = false
			SkillTree.BUTTONS[id] = nil
		end
	end
end
SkillTree.HERRERA_IRONCLAW_TUNE = true
SkillTree.HERRERA_IRONCLAW_MULS = {1.05, 1.10, 1.15, 1.25}
if SkillTree.HERRERA_PARTS and SkillTree.HERRERA_IRONCLAW_TUNE and SkillTree.PATHS.ironclaw then
	SkillTree.PATHS.ironclaw.steps = {"Iron hook blades: slash damage +5%", "Slash damage +10%", "Slash damage +15%",
		"Slash damage +25%"}
end
SkillTree.HERRERA_PASS3 = true
if SkillTree.HERRERA_PARTS and SkillTree.HERRERA_PASS3 and not SkillTree.PATHS.caltrops then
	local function part(id, name, areaId, steps)
		local p = path(id, name, true, false, steps)
		p.area = areaId
		p.dino = "Herrera"
		SkillTree.OWNER[id] = "Herrera"
		SkillTree.LIVE_MECH[id] = true
		SkillTree.BUTTONS[id] = true
		for _, a in ipairs(SkillTree.AREAS) do
			if a.id == areaId then table.insert(a.paths, p) end
		end
		SkillTree.PATHS[id] = p
		table.insert(SkillTree.PATH_ORDER, id)
	end
	part("caltrops", "Razor Caltrops", "eng", {
		"Button: drop 6 razor spikes in a 10-stud patch behind you for 8 s. An enemy that steps on one bleeds 3/s for 3 s and is slowed 30% for 1 s. Recharges in 16 s",
		"10 spikes, 14-stud patch", "Spikes last 14 s", "Enemies can't see the spikes (only you and your squad do)"})
	part("goo", "Goo Blob Shooter", "eng", {
		"Button: toss a goo blob 30 studs ahead (straight down while gliding). It splats into a 16-stud puddle for 5 s; enemies in it are slowed 40%. Recharges in 14 s",
		"Puddle 22 studs wide", "Fires 2 blobs side by side", "Puddles last 8 s"})
	part("hadren", "Adrenaline Injector", "health", {
		"Button: heal 25% of max health over 3 s and run 1.4x faster while it lasts. Recharges in 20 s",
		"Heal 34%", "Recharges 26% faster", "Also refills every slash charge at once"})
end
-- v1.44: Blade Claws is a raptor stat row
SkillTree.RAPTOR_BLADE_STAT = true
if SkillTree.RAPTOR_BLADE_STAT and SkillTree.PATHS.blade then
	SkillTree.PATHS.blade.mech = false
	SkillTree.BUTTONS.blade = nil
end
-- v1.45: the Tenontosaurus' stat rows
SkillTree.TENO_STATS = true
if SkillTree.TENO_STATS and not SkillTree.PATHS.chargeup then
	local P = SkillTree.PATHS
	for _, id in ipairs({"regen", "lifesteal", "jaws", "hide", "legs"}) do
		if P[id] then
			P[id].notFor = P[id].notFor or {}
			P[id].notFor.Teno = true
		end
	end
	table.insert(SkillTree.AREAS, {id = "sig", name = "Signature", color = {201, 162, 255}, paths = {}})
	local function add(id, name, areaId, steps)
		local p = path(id, name, false, false, steps)
		p.area = areaId
		p.dino = "Teno"
		SkillTree.OWNER[id] = "Teno"
		for _, a in ipairs(SkillTree.AREAS) do
			if a.id == areaId then table.insert(a.paths, p) end
		end
		P[id] = p
		table.insert(SkillTree.PATH_ORDER, id)
	end
	add("chargeup", "Charge Up", "speed", {
		"After 2 s of running: run 10% faster",
		"After 3 s of running: run 20% faster, and you can't be shoved",
		"Running into a dino at full speed bumps it 10 studs aside",
		"Full-speed hits stun 0.5 s"})
	add("brace", "Brace", "defense", {
		"While holding a slam: take 20% less damage",
		"While holding: can't be stunned or knocked back",
		"While holding: every hit you take adds +3 damage to that slam",
		"Releasing a slam heals 5% of max health per enemy hit"})
	add("buckoff", "Buck Off", "sig", {
		"Latched raptors take +10 slam damage (Buck Off does nothing while you are stunned)",
		"A slam while something is latched on costs no charge",
		"After a buck-off, nothing can latch on for 2 s",
		"A raptor that latches on takes 3 damage per second until it lets go"})
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
	-- v1.32: pachy parts batch 3
	local sd, vz, ik = s.servodash or 0, s.visor or 0, s.ink or 0
	e.servoTime, e.servoCd, e.servoMul, e.servoRefill = 0, 0, 1, false
	if SkillTree.PACHY_SERVO_DASH then
		if sd >= 1 then e.servoTime, e.servoCd, e.servoMul = 1.5, 12, 1.6 end
		if sd >= 2 then e.servoTime = 2 end
		if sd >= 3 then e.servoCd = 8 end
		if sd >= 4 then e.servoRefill = true end
		if SkillTree.SERVO_DASH_2X then -- v1.33
			if sd >= 1 then e.servoTime, e.servoMul = 1, 2 end
			if sd >= 2 then e.servoTime = 1.5 end
		end
	end
	e.visorTime, e.visorCd, e.visorKnock = 0, 0, false
	if SkillTree.PACHY_DOME_VISOR then
		if vz >= 1 then e.visorTime, e.visorCd = 1.5, 14 end
		if vz >= 2 then e.visorTime = 2 end
		if vz >= 3 then e.visorCd = 10 end
		if vz >= 4 then e.visorKnock = true end
	end
	e.inkRange, e.inkCd, e.inkBlind, e.inkSplash = 0, 0, 0, 0
	if SkillTree.PACHY_INK_SHOOTER then
		if ik >= 1 then e.inkRange, e.inkCd, e.inkBlind = 60, 15, 2 end
		if ik >= 2 then e.inkRange = 80 end
		if ik >= 3 then e.inkCd = 11 end
		if ik >= 4 then e.inkSplash = 6 end
	end
	-- v1.34: Tether Spike
	local tt = s.tether or 0
	e.tetherRange, e.tetherSplash, e.tetherReach, e.tetherTime, e.tetherCd, e.tetherYank, e.tetherYankReach = 0, 0, 0, 0, 0, false, 0
	if SkillTree.PACHY_TETHER then
		if tt >= 1 then e.tetherRange, e.tetherSplash, e.tetherReach, e.tetherTime, e.tetherCd = 60, 8, 10, 2.5, 14 end
		if tt >= 2 then e.tetherTime = 3.5 end
		if tt >= 3 then e.tetherCd = 10 end
		if tt >= 4 then e.tetherYank, e.tetherYankReach = true, 5 end
		if tt >= 1 and SkillTree.TETHER_RANGE_90 then e.tetherRange = 90 end -- v1.35
		if SkillTree.TETHER_BIGGER then -- v1.36
			if tt >= 1 then e.tetherSplash, e.tetherTime = 15, 4 end
			if tt >= 2 then e.tetherTime = 5 end
		end
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
	-- v1.37: the Herrera's rows (Razor Claws / Scurry Legs III / Tree Stalker / Blood Frenzy; Blood Drinker = lifesteal,
	--   Wiry Frame = hide, both as before)
	e.slashRefillMul, e.slashBleedDps, e.slashExtraCharges, e.climbSpeedMul = 1, 0, 0, 1
	e.diveRangeMul, e.diveRefill, e.treeTopHidden, e.diveStun = 1, false, false, 0
	e.frenzySpeedMul, e.slashBleedTime, e.bleedBonus, e.killRefill = 1, 0, 0, false
	if SkillTree.HERRERA_STATS and dino == "Herrera" then
		local jw, lg, ts, bf = s.jaws or 0, s.legs or 0, s.stalker or 0, s.frenzy or 0
		e.mainCdMul, e.bleedDps, e.bleedTime, e.crushStun, e.crushCooldown = 1, 0, 0, 0, 0 -- Razor Claws, not Jaws II-star
		if jw >= 2 then e.slashRefillMul = 0.65 end
		if jw >= 3 then e.slashBleedDps = 5 end
		if jw >= 4 then e.slashExtraCharges = 1 end
		if lg >= 3 then e.climbSpeedMul = 1.35 end
		if ts >= 1 then e.diveRangeMul = 55 / 40 end
		if ts >= 2 then e.diveRefill = true end
		if ts >= 3 then e.treeTopHidden = true end
		if ts >= 4 then e.diveStun = 0.5 end
		if bf >= 1 then e.frenzySpeedMul = 1.1 end
		if bf >= 2 then e.slashBleedTime = 6 end
		if bf >= 3 then e.bleedBonus = 3 end
		if bf >= 4 then e.killRefill = true end
	end
	-- v1.38: the Herrera's mecha parts (off values when not bought)
	local function st(id) return s[id] or 0 end
	local ic, gl, qu, sm, pl, si, sb, br = st("ironclaw"), st("glider"), st("quills"), st("smoke"), st("plating"),
		st("siphon"), st("strobe"), st("breaker")
	local on = SkillTree.HERRERA_PARTS
	e.ironClawDamageMul = on and ({1.1, 1.2, 1.3, 1.5})[ic] or 1
	e.ironClawSpeedMul = on and ({0.95, 0.90, 0.85, 0.75})[ic] or 1
	e.ironClawDust = on and ic >= 3
	e.gliderFall = on and gl >= 1 and 8 or 0
	e.gliderDrop = on and gl >= 2
	e.gliderDropMul = on and gl >= 3 and 1.3 or 1
	e.gliderBurst = on and gl >= 4 and 10 or 0
	e.quillCount = on and ({5, 8, 12, 17})[qu] or 0
	e.quillDamage, e.quillRange, e.quillCooldown = (on and qu >= 1) and 4 or 0, (on and qu >= 1) and 40 or 0, 20
	e.smokeRadius = on and sm >= 1 and 12 or 0
	e.smokeTime = on and (sm >= 2 and 6 or (sm >= 1 and 4 or 0)) or 0
	e.smokeRunMul = on and sm >= 3 and 1.25 or 1
	e.smokeSlowMul = on and sm >= 4 and 0.75 or 1
	e.smokeCooldown = 18
	e.platingRearMul = on and ({0.90, 0.85, 0.78, 0.70})[pl] or 1
	e.siphonRate = on and (si >= 2 and 1.5 or (si >= 1 and 1 or 0)) or 0
	e.siphonRange = on and (si >= 3 and 25 or (si >= 1 and 15 or 0)) or 0
	e.siphonKillHeal = on and si >= 4 and 0.25 or 0
	e.strobeAngle = on and (sb >= 3 and 90 or (sb >= 1 and 60 or 0)) or 0
	e.strobeRange = on and (sb >= 3 and 25 or (sb >= 1 and 20 or 0)) or 0
	e.strobeDaze = on and (sb >= 2 and 1.5 or (sb >= 1 and 1 or 0)) or 0
	e.strobeDazedMul = on and sb >= 4 and 1.2 or 1
	e.strobeCooldown = 16
	e.breaker = on and br >= 1
	e.breakerPush = on and br >= 2 and 10 or 0
	e.breakerCooldown = on and br >= 3 and 14 or 20
	e.breakerImmune = on and br >= 4 and 1 or 0
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

-- v1.41: Herrera tuning around the 1.38 effects (quill counts, smoke radius)
do
	local effectsV140 = SkillTree.effects
	function SkillTree.effects(steps, dino)
		local e = effectsV140(steps, dino)
		if SkillTree.HERRERA_PARTS and SkillTree.HERRERA_TUNE_1 and type(e) == "table" then
			local s = type(steps) == "table" and steps or {}
			local qu, sm = s.quills or 0, s.smoke or 0
			if qu >= 1 and (e.quillCount or 0) > 0 then e.quillCount = SkillTree.HERRERA_QUILL_COUNTS[math.min(4, qu)] end
			if sm >= 1 and (e.smokeRadius or 0) > 0 then e.smokeRadius = SkillTree.HERRERA_SMOKE_RADIUS end
		end
		return e
	end
end

-- v1.43: Iron Claw retune + the pass 3 parts around the 1.42 effects
do
	local effectsV142 = SkillTree.effects
	function SkillTree.effects(steps, dino)
		local e = effectsV142(steps, dino)
		if type(e) ~= "table" or not SkillTree.HERRERA_PARTS then return e end
		local s = type(steps) == "table" and steps or {}
		if SkillTree.HERRERA_IRONCLAW_TUNE then
			local ic = s.ironclaw or 0
			if ic >= 1 then
				e.ironClawDamageMul = SkillTree.HERRERA_IRONCLAW_MULS[math.min(4, ic)]
				e.ironClawSpeedMul = 1
			end
		end
		if SkillTree.HERRERA_PASS3 then
			local ca, go, ha = s.caltrops or 0, s.goo or 0, s.hadren or 0
			e.caltropCount = ca >= 2 and 10 or (ca >= 1 and 6 or 0)
			e.caltropRadius = ca >= 2 and 7 or (ca >= 1 and 5 or 0)
			e.caltropTime = ca >= 3 and 14 or (ca >= 1 and 8 or 0)
			e.caltropHidden = ca >= 4
			e.caltropBleedDps, e.caltropBleedTime = ca >= 1 and 3 or 0, ca >= 1 and 3 or 0
			e.caltropSlowMul, e.caltropSlowTime = ca >= 1 and 0.7 or 1, ca >= 1 and 1 or 0
			e.caltropCooldown = 16
			e.gooToss = go >= 1 and 30 or 0
			e.gooRadius = go >= 2 and 11 or (go >= 1 and 8 or 0)
			e.gooTime = go >= 4 and 8 or (go >= 1 and 5 or 0)
			e.gooCount = go >= 3 and 2 or (go >= 1 and 1 or 0)
			e.gooSlowMul = go >= 1 and 0.6 or 1
			e.gooCooldown = 14
			e.gooAssistAngle, e.gooAssistMin, e.gooAssistMax = 30, 15, 45
			if dino == "Herrera" and ha >= 1 then
				e.adrenHeal = ha >= 2 and 0.34 or 0.25
				e.adrenTime, e.adrenSpeedMul, e.adrenStunClear = 3, 1.4, false
				e.adrenCooldown = ha >= 3 and 14.8 or 20
			end
			e.adrenSlashRefill = dino == "Herrera" and ha >= 4
		end
		return e
	end
end

-- v1.47: Herrera trim (header): rows hidden here, numbers in the effects wrapper below
SkillTree.HERRERA_TRIM = true
SkillTree.HERRERA_TRIM_ATTACK, SkillTree.HERRERA_TRIM_BLEED_DPS = 3, 3
SkillTree.HERRERA_TRIM_BLEED_TIME, SkillTree.HERRERA_TRIM_BLEED_BONUS = 5, 2
if SkillTree.HERRERA_TRIM then
	local P = SkillTree.PATHS
	if P.regen then
		P.regen.notFor = P.regen.notFor or {}
		P.regen.notFor.Herrera = true
	end
	for _, id in ipairs({"siphon", "ironclaw"}) do
		if P[id] and P[id].dino == "Herrera" then
			P[id].dino = "none"
			SkillTree.OWNER[id] = "none"
			SkillTree.BUTTONS[id] = nil
		end
	end
	if P.jaws and P.jaws.stepsFor and P.jaws.stepsFor.Herrera then
		P.jaws.stepsFor.Herrera = {
			("Slash hits harder (+%d Attack points: slash 7 -> %d)"):format(SkillTree.HERRERA_TRIM_ATTACK, 7 + SkillTree.HERRERA_TRIM_ATTACK),
			P.jaws.stepsFor.Herrera[2],
			("Bleed burns hotter: %d per second (was 2)"):format(SkillTree.HERRERA_TRIM_BLEED_DPS),
			P.jaws.stepsFor.Herrera[4]}
	end
	if P.frenzy then
		P.frenzy.steps = {P.frenzy.steps[1], ("Bleed lasts %d s (was 4)"):format(SkillTree.HERRERA_TRIM_BLEED_TIME),
			("Slash a bleeding dino: +%d damage"):format(SkillTree.HERRERA_TRIM_BLEED_BONUS), P.frenzy.steps[4]}
	end
end
do
	local effectsV146 = SkillTree.effects
	function SkillTree.effects(steps, dino)
		local e = effectsV146(steps, dino)
		if type(e) ~= "table" or not SkillTree.HERRERA_TRIM or dino ~= "Herrera" then return e end
		local s = SkillTree.sanitize(steps, dino)
		local jw, bf = s.jaws or 0, s.frenzy or 0
		if jw >= 1 then e.attackPts = SkillTree.HERRERA_TRIM_ATTACK end
		if jw >= 3 then e.slashBleedDps = SkillTree.HERRERA_TRIM_BLEED_DPS end
		if bf >= 2 then e.slashBleedTime = SkillTree.HERRERA_TRIM_BLEED_TIME end
		if bf >= 3 then e.bleedBonus = SkillTree.HERRERA_TRIM_BLEED_BONUS end
		-- the removed rows give their off values even from unsanitized steps
		e.regenDelay, e.regenRate, e.killRegenAdd = 0, 0, 0
		e.siphonRate, e.siphonRange, e.siphonKillHeal = 0, 0, 0
		e.ironClawDamageMul, e.ironClawSpeedMul, e.ironClawDust = 1, 1, false
		return e
	end
end

-- v1.45: the Tenontosaurus' rows around the 1.44 effects (off values on every build without them)
do
	local effectsV144 = SkillTree.effects
	function SkillTree.effects(steps, dino)
		local e = effectsV144(steps, dino)
		if type(e) ~= "table" then return e end
		local s = SkillTree.sanitize(steps, dino)
		local on = SkillTree.TENO_STATS
		local cu, bc, bo = on and s.chargeup or 0, on and s.brace or 0, on and s.buckoff or 0
		e.chargeMul1 = cu >= 1 and 1.1 or 1
		e.chargeMul2 = cu >= 2 and 1.2 or e.chargeMul1
		e.chargeNoShove = cu >= 2
		e.chargeBump = cu >= 3 and 10 or 0
		e.chargeBumpStun = cu >= 4 and 0.5 or 0
		e.braceMul = bc >= 1 and 0.8 or 1
		e.braceNoStun = bc >= 2
		e.braceStack = bc >= 3 and 3 or 0
		e.braceHeal = bc >= 4 and 0.05 or 0
		e.buckBonus = bo >= 1 and 10 or 0
		e.buckFree = bo >= 2
		e.buckImmune = bo >= 3 and 2 or 0
		e.buckDps = bo >= 4 and 3 or 0
		return e
	end
end

-- v1.48: Buck Off star also gives the tail slam a 4th charge (Kepu 2026-11-01: "4 charges at max" -> "3 base, 4 with an
-- upgrade" -> "Buck Off star adds it"; plan docs/plans/TENO_SLAM_REWORK_v1.0.md). Switch SkillTree.TENO_BUCK_CHARGE.
SkillTree.TENO_BUCK_CHARGE = true
if SkillTree.TENO_STATS and SkillTree.TENO_BUCK_CHARGE and SkillTree.PATHS.buckoff then
	SkillTree.PATHS.buckoff.steps[4] = "A raptor that latches on takes 3 damage per second until it lets go, and your tail slam gets a 4th charge"
end
do
	local effectsV147 = SkillTree.effects
	function SkillTree.effects(steps, dino)
		local e = effectsV147(steps, dino)
		if type(e) ~= "table" then return e end
		local s = SkillTree.sanitize(steps, dino)
		local bo = (SkillTree.TENO_STATS and SkillTree.TENO_BUCK_CHARGE) and (s.buckoff or 0) or 0
		e.buckCharge = bo >= 4 and 1 or 0
		return e
	end
end


-- v1.49: the teno's mecha button parts (see the header)
SkillTree.TENO_PARTS = true
SkillTree.TENO_PARTS_SUPPORT_SOON = true
if SkillTree.TENO_PARTS and not SkillTree.PATHS.tgrab then
	local function part(id, name, areaId, steps)
		local p = path(id, name, true, false, steps)
		p.area = areaId
		p.dino = "Teno"
		SkillTree.OWNER[id] = "Teno"
		SkillTree.LIVE_MECH[id] = true
		SkillTree.BUTTONS[id] = true
		for _, a in ipairs(SkillTree.AREAS) do
			if a.id == areaId then table.insert(a.paths, p) end
		end
		SkillTree.PATHS[id] = p
		table.insert(SkillTree.PATH_ORDER, id)
	end
	part("tgrab", "Tail Grab & Fling", "attack", {
		"Button: grab the nearest raptor-size dino within 12 studs with your tail and fling it 30 studs ahead. 8 damage, stunned 1 s when it lands. Recharges in 16 s",
		"Fling 45 studs", "Grabs bigger dinos too (up to pachy size)", "The flung dino crashes into others where it lands: 8 damage to each"})
	part("tmortar", "Boulder Mortar", "attack", {
		"Button: lob a boulder at the nearest enemy in front, up to 60 studs (none: 45 studs ahead). 12 damage in a 10-stud splash, enemies slowed 30% for 2 s. Recharges in 14 s",
		"Splash 14 studs", "Lobs 2 boulders side by side", "Leaves a rubble patch for 4 s: enemies in it are slowed 30%"})
	part("tstomp", "Stomp Shockwave", "defense", {
		"Button: rear up and stomp. A 14-stud shockwave: 6 damage, stuns 0.5 s and knocks off latched raptors. Recharges in 15 s",
		"Stun 1 s", "Shockwave 20 studs", "Stomped dinos can't jump or pounce for 3 s"})
	part("tbellow", "Herd Bellow", "health", {
		"Button: you and squadmates within 25 studs take 50% less damage and run 50% faster for 4 s. Recharges in 30 s",
		"Lasts 6 s", "Reaches 40 studs", "Also clears stuns on everyone it reaches"})
	part("tchallenge", "Challenge Call", "defense", {
		"Button: enemies within 30 studs are marked for 5 s: they deal 40% less damage, and bots go for you. Recharges in 20 s",
		"Mark lasts 7 s", "Reaches 45 studs", "Marked enemies are also slowed 20%"})
	part("tleap", "Hydraulic Leap", "speed", {
		"Button: a hydraulic leap 40 studs forward. Landing slams the tail: 10 damage in 12 studs (no slam charge used). Recharges in 14 s",
		"Leap 55 studs", "Landing stuns 0.5 s", "2 leaps (2 charges)"})
	part("tmud", "Mud Armor", "defense", {
		"Button: wallow in mud. A mud coat for 8 s blocks your next 3 hits completely, and each blocked hit slows every enemy within 15 studs 40% for 4 s. Latched raptors slide off. Recharges in 20 s",
		"Blocks 4 hits", "Coat lasts 12 s", "When the coat ends it splashes 12 studs around: enemies slowed 40% for 4 s"})
	if SkillTree.TENO_PARTS_SUPPORT_SOON then
		for _, id in ipairs({"tbellow", "tchallenge", "tmud"}) do
			SkillTree.PATHS[id].soon = true
			SkillTree.LIVE_MECH[id] = nil
		end
	end
end
do
	local effectsPre149 = SkillTree.effects
	function SkillTree.effects(steps, dino)
		local e = effectsPre149(steps, dino)
		if type(e) ~= "table" then return e end
		local on = SkillTree.TENO_PARTS and dino == "Teno" and SkillTree.PATHS.tgrab ~= nil
		local s = on and SkillTree.sanitize(steps, dino) or {}
		local g, m, st, b, c, l, md = s.tgrab or 0, s.tmortar or 0, s.tstomp or 0, s.tbellow or 0, s.tchallenge or 0, s.tleap or 0, s.tmud or 0
		e.grabRange, e.grabDamage, e.grabStun = g >= 1 and 12 or 0, g >= 1 and 8 or 0, g >= 1 and 1 or 0
		e.grabFling = g >= 2 and 45 or (g >= 1 and 30 or 0)
		e.grabBig = g >= 3
		e.grabCrash, e.grabCrashRadius = g >= 4 and 8 or 0, g >= 4 and 8 or 0
		e.grabCooldown = g >= 1 and 16 or 0
		e.mortarRange, e.mortarMiss, e.mortarCone = m >= 1 and 60 or 0, m >= 1 and 45 or 0, m >= 1 and 30 or 0
		e.mortarDamage = m >= 1 and 12 or 0
		e.mortarSplash = m >= 2 and 14 or (m >= 1 and 10 or 0)
		e.mortarCount = m >= 3 and 2 or (m >= 1 and 1 or 0)
		e.mortarSlowMul, e.mortarSlowTime = m >= 1 and 0.7 or 1, m >= 1 and 2 or 0
		e.mortarRubble = m >= 4 and 4 or 0
		e.mortarCooldown = m >= 1 and 14 or 0
		e.stompRange = st >= 3 and 20 or (st >= 1 and 14 or 0)
		e.stompDamage = st >= 1 and 6 or 0
		e.stompStun = st >= 2 and 1 or (st >= 1 and 0.5 or 0)
		e.stompNoJump = st >= 4 and 3 or 0
		e.stompCooldown = st >= 1 and 15 or 0
		e.leapDist = l >= 2 and 55 or (l >= 1 and 40 or 0)
		e.leapDamage, e.leapRadius = l >= 1 and 10 or 0, l >= 1 and 12 or 0
		e.leapStun = l >= 3 and 0.5 or 0
		e.leapCharges = l >= 4 and 2 or (l >= 1 and 1 or 0)
		e.leapCooldown = l >= 1 and 14 or 0
		e.bellowRange = b >= 3 and 40 or (b >= 1 and 25 or 0)
		e.bellowTime = b >= 2 and 6 or (b >= 1 and 4 or 0)
		e.bellowDamageMul, e.bellowRunMul = b >= 1 and 0.5 or 1, b >= 1 and 1.5 or 1
		e.bellowClearStun = b >= 4
		e.bellowCooldown = b >= 1 and 30 or 0
		e.challengeRange = c >= 3 and 45 or (c >= 1 and 30 or 0)
		e.challengeTime = c >= 2 and 7 or (c >= 1 and 5 or 0)
		e.challengeWeakMul = c >= 1 and 0.6 or 1
		e.challengeSlowMul = c >= 4 and 0.8 or 1
		e.challengeCooldown = c >= 1 and 20 or 0
		e.mudTime = md >= 3 and 12 or (md >= 1 and 8 or 0)
		e.mudHits = md >= 2 and 4 or (md >= 1 and 3 or 0)
		e.mudSlowRadius, e.mudSlowMul, e.mudSlowTime = md >= 1 and 15 or 0, md >= 1 and 0.6 or 1, md >= 1 and 4 or 0
		e.mudSplash = md >= 4 and 12 or 0
		e.mudCooldown = md >= 1 and 20 or 0
		return e
	end
end


-- v1.50: teno stats part 2 (see the header)
SkillTree.TENO_STATS_2 = true
if SkillTree.TENO_STATS and SkillTree.TENO_STATS_2 and SkillTree.PATHS.chargeup and not SkillTree.PATHS.survivor then
	local P = SkillTree.PATHS
	local function add(id, name, areaId, steps)
		local p = path(id, name, false, false, steps)
		p.area = areaId
		p.dino = "Teno"
		SkillTree.OWNER[id] = "Teno"
		for _, a in ipairs(SkillTree.AREAS) do
			if a.id == areaId then table.insert(a.paths, p) end
		end
		P[id] = p
		table.insert(SkillTree.PATH_ORDER, id)
	end
	add("survivor", "Survivor", "health", {
		"A kill heals 15% of your max health over 4 s",
		"Kill heal 25%",
		"Any enemy that dies within 25 studs of you heals you 10% (whoever killed it)",
		"A kill also refills one tail slam charge"})
	add("heavytail", "Heavy Tail", "attack", {
		"Tail slam +3 damage (15 -> 18)",
		"Slam charges refill 25% faster (8 s -> 6 s)",
		"Your tail reaches 20% further",
		"Slammed dinos are slowed 30% for 3 s after the stun"})
	add("frontclaws", "Front Claws", "attack", {
		"Scratch hits harder (8 -> 11)",
		"A wider swipe in front (90° -> 130°)",
		"Scratch faster (0.5 s -> 0.35 s between scratches)",
		"A scratch hit slows the target 30% for 1.5 s"})
	if P.hide then
		if P.hide.notFor then P.hide.notFor.Teno = nil end
		P.hide.nameFor = P.hide.nameFor or {}
		P.hide.nameFor.Teno = "Armored Hide"
		P.hide.stepsFor = P.hide.stepsFor or {}
		P.hide.stepsFor.Teno = {
			"Take 10% less damage, always",
			"Thrown half as far by rams and shoves",
			"Stuns are 30% shorter",
			"No stuns while above 50% health"}
	end
end
do
	local effectsV148 = SkillTree.effects
	function SkillTree.effects(steps, dino)
		local e = effectsV148(steps, dino)
		if type(e) ~= "table" then return e end
		local on = SkillTree.TENO_STATS and SkillTree.TENO_STATS_2 and dino == "Teno" and SkillTree.PATHS.survivor ~= nil
		local s = on and SkillTree.sanitize(steps, dino) or {}
		local sv, ht, fc, h = s.survivor or 0, s.heavytail or 0, s.frontclaws or 0, s.hide or 0
		e.survivorKillHeal = sv >= 2 and 0.25 or (sv >= 1 and 0.15 or 0)
		e.survivorNearHeal, e.survivorNearRange = sv >= 3 and 0.10 or 0, sv >= 3 and 25 or 0
		e.survivorRefill = sv >= 4
		e.heavyBonus = ht >= 1 and 3 or 0
		e.heavyRefillMul = ht >= 2 and 0.75 or 1
		e.heavyReachMul = ht >= 3 and 1.2 or 1
		e.heavySlow, e.heavySlowTime = ht >= 4 and 0.3 or 0, ht >= 4 and 3 or 0
		e.clawBonus = fc >= 1 and 3 or 0
		e.clawCone = fc >= 2 and 130 or 0
		e.clawGap = fc >= 3 and 0.35 or 0
		e.clawSlow, e.clawSlowTime = fc >= 4 and 0.3 or 0, fc >= 4 and 1.5 or 0
		if on and h >= 1 then e.defensePts += 2 - (SkillTree.STRONG and 6 or 1) end -- Armored Hide: 2 points (10%) instead of Thick Hide's 6 (35% rule; 1 without it)
		if on and h >= 3 then e.stunMul = 0.7 end -- = Thick Hide III under the 35% rule
		return e
	end
end


-- v1.51 (Pachy redesign, PachyModelData 1.4 / PachyLook 1.1; Kepu 2026-11-02: battering dome spikes as "the default look"
-- -> "Nothing new just the stat boosts"): the dome spikes are always on, so the Battering Dome star text drops "and spikes on
-- your dome"; its effects (hbExtraCharges, pachySpikes) are unchanged. Switch SkillTree.PACHY_SPIKES_ALWAYS (false = 1.20
-- text). Numbered after the planned teno 1.49 / 1.50; renumber at build time if the order changes.
SkillTree.PACHY_SPIKES_ALWAYS = true
if SkillTree.PACHY_SPIKES_ALWAYS and SkillTree.PATHS.dome then
	SkillTree.PATHS.dome.steps[4] = "A 3rd headbutt charge"
end

-- v1.52 (Kepu 2026-11-02: Stomp Shockwave "No, it just lowers the stamina for a raptor that's latched on" -> "It doesn't knock
-- it off, it lowers the stamina for the current pounce", picked "Never knock off; star drains", -50). Switch
-- SkillTree.TENO_STOMP_DRAIN (default true; false = 1.51 texts / numbers): tstomp step I no longer says it knocks latched
-- raptors off; the star is "A raptor latched on you loses 50 stamina from its pounce": effects stompLatchDrain 50 at star
-- (0 otherwise / other dinos), stompNoJump always 0 on the teno (TenoMovesServer 1.1 / SkillEffects 1.35).
SkillTree.TENO_STOMP_DRAIN = true
if SkillTree.TENO_PARTS and SkillTree.TENO_STOMP_DRAIN and SkillTree.PATHS.tstomp then
	SkillTree.PATHS.tstomp.steps[1] = "Button: rear up and stomp. A 14-stud shockwave: 6 damage and stuns 0.5 s. Recharges in 15 s"
	SkillTree.PATHS.tstomp.steps[4] = "A raptor latched on you loses 50 stamina from its pounce"
end
do
	local effectsPre152 = SkillTree.effects
	function SkillTree.effects(steps, dino)
		local e = effectsPre152(steps, dino)
		if type(e) ~= "table" then return e end
		local on = SkillTree.TENO_PARTS and SkillTree.TENO_STOMP_DRAIN and dino == "Teno" and SkillTree.PATHS.tstomp ~= nil
		local st = on and (SkillTree.sanitize(steps, dino).tstomp or 0) or 0
		if on then e.stompNoJump = 0 end
		e.stompLatchDrain = st >= 4 and 50 or 0
		return e
	end
end

-- v1.53 (Kepu 2026-11-02: the mortar "only lands directly on the teno" -> picked "Crosshair + snap"; TenoMovesServer 1.2):
-- Boulder Mortar step I text says it lands where the crosshair points (15-60 studs) and snaps onto a dino near that spot.
-- Switch SkillTree.TENO_MORTAR_AIM (default true; false = 1.52 text). Numbers unchanged.
SkillTree.TENO_MORTAR_AIM = true
if SkillTree.TENO_PARTS and SkillTree.TENO_MORTAR_AIM and SkillTree.PATHS.tmortar then
	SkillTree.PATHS.tmortar.steps[1] = "Button: lob a boulder where your crosshair points (15-60 studs); it snaps onto a dino within 8 studs of that spot. 12 damage in a 10-stud splash, enemies slowed 30% for 2 s. Recharges in 14 s"
end


-- v1.54 (teno abilities build 2, plan docs/plans/TENO_ABILITIES_v1.0.md Tasks 2 + 6, MDA-174 / MDA-178; Kepu 2026-11-02
-- "Next"): Herd Bellow, Challenge Call and Mud Armor go live: soon = false and LIVE_MECH again (buyable, slottable, their
-- effects written; TenoMovesServer 1.3 runs them). Texts and numbers are the 1.49 ones. Switch SkillTree.TENO_SUPPORT_LIVE
-- (default true; false = 1.53: the three stay "soon").
SkillTree.TENO_SUPPORT_LIVE = true
if SkillTree.TENO_PARTS and SkillTree.TENO_SUPPORT_LIVE then
	for _, id in ipairs({"tbellow", "tchallenge", "tmud"}) do
		if SkillTree.PATHS[id] then
			SkillTree.PATHS[id].soon = false
			SkillTree.LIVE_MECH[id] = true
		end
	end
end


-- v1.55 (Kepu 2026-11-02 16:43: "You also didn't make the leap just a part of the jump button" -> "look at how we did it for
-- the pachy"; picked "Same, but keep 2 charges"; "Change the mud armor to be a purple shield armor" -> "Look only", look
-- "B Energy Armor"):
--   * SkillTree.TENO_LEAP_ON_JUMP (default true; false = 1.54): Hydraulic Leap works like the pachy's Mecha Legs: it stays
--     in BUTTONS (takes a slot) but fires through JUMP (JumpTest / JumpServer, the shared leap). Effects (1 / 0 when not
--     bought): leapBoostMul (I 1.65, II 2.1) and leapPowerMul (I 1.2, II 1.45) on the teno's own JumpBoost /
--     JumpLaunchPower (SkillEffects 1.37), leapCooldown 6 (was 14: Mecha Legs' cooldown), leapCharges I 1 / star 2 (each
--     charge refills leapCooldown s after the one before), leapDamage / leapRadius / leapStun unchanged (TenoMovesServer
--     1.4 slams on landing). leapDist stays 40 / 55 (the step texts' distance; Studio, sprinting: I 1.5 -> 37.6 studs,
--     II 1.8 -> 50.1 studs, so the boost was raised to 1.65 / 2.1).
--   * SkillTree.TENO_SHIELD_ARMOR (default true; false = 1.54 name / texts): "tmud" is named "Shield Armor" and its step
--     texts say shield instead of mud. Numbers and rules unchanged.
SkillTree.TENO_LEAP_ON_JUMP = true
if SkillTree.TENO_PARTS and SkillTree.TENO_LEAP_ON_JUMP and SkillTree.PATHS.tleap then
	SkillTree.PATHS.tleap.steps = {
		"Fires through JUMP: every jump is a hydraulic leap, 40 studs forward. Landing slams the tail: 10 damage in 12 studs (no slam charge used). Recharges in 6 s",
		"Leap 55 studs", "Landing stuns 0.5 s", "2 leaps (2 charges)"}
end
SkillTree.TENO_SHIELD_ARMOR = true
if SkillTree.TENO_PARTS and SkillTree.TENO_SHIELD_ARMOR and SkillTree.PATHS.tmud then
	SkillTree.PATHS.tmud.name = "Shield Armor"
	SkillTree.PATHS.tmud.steps = {
		"Button: a purple energy shield for 8 s blocks your next 3 hits completely, and each blocked hit slows every enemy within 15 studs 40% for 4 s. Latched raptors are knocked off. Recharges in 20 s",
		"Blocks 4 hits", "Shield lasts 12 s", "When the shield ends it bursts 12 studs around: enemies slowed 40% for 4 s"}
end
do
	local effectsPre155 = SkillTree.effects
	function SkillTree.effects(steps, dino)
		local e = effectsPre155(steps, dino)
		if type(e) ~= "table" then return e end
		local on = SkillTree.TENO_PARTS and SkillTree.TENO_LEAP_ON_JUMP and dino == "Teno" and SkillTree.PATHS.tleap ~= nil
		local l = on and (SkillTree.sanitize(steps, dino).tleap or 0) or 0
		e.leapBoostMul = l >= 2 and 2.1 or (l >= 1 and 1.65 or 1)
		e.leapPowerMul = l >= 2 and 1.45 or (l >= 1 and 1.2 or 1)
		if on and l >= 1 then e.leapCooldown = 6 end
		e.leapOnJump = on and l >= 1
		return e
	end
end


-- v1.56 (Kepu 2026-11-02 17:29: "the mortar animation and range needs to be beefed up" -> range "90 studs"): with
-- SkillTree.TENO_MORTAR_90 (default true; false = 1.55) Boulder Mortar step I reaches 15-90 studs: mortarRange 60 -> 90 (the
-- crosshair clamp, TenoMovesServer 1.5). Step I text says 15-90. Other numbers unchanged.
SkillTree.TENO_MORTAR_90 = true
if SkillTree.TENO_PARTS and SkillTree.TENO_MORTAR_90 and SkillTree.PATHS.tmortar then
	SkillTree.PATHS.tmortar.steps[1] = "Button: lob a boulder where your crosshair points (15-90 studs); it snaps onto a dino within 8 studs of that spot. 12 damage in a 10-stud splash, enemies slowed 30% for 2 s. Recharges in 14 s"
end
do
	local effectsPre156 = SkillTree.effects
	function SkillTree.effects(steps, dino)
		local e = effectsPre156(steps, dino)
		if type(e) ~= "table" then return e end
		if SkillTree.TENO_PARTS and SkillTree.TENO_MORTAR_90 and dino == "Teno" and (e.mortarRange or 0) > 0 then e.mortarRange = 90 end
		return e
	end
end


-- v1.57 (Therizinosaurus stat rows, plan docs/plans/THERIZINO_SPIN_STATS_v1.0.md Task 4, MDA-210, mockup
-- docs/mockups/therizino_spin_dive_v0.1.html; Kepu 2026-11-02/03: shared rows "None, all its own", theme "Combo flow", rows
-- "Keep all five", Fourth Cut "Mock it up first"). Switch SkillTree.THERI_STATS (default true; false = 1.56):
--   * PATHS regen / lifesteal / jaws / hide / legs get notFor.Therizino (the therizino sees none of the shared stat rows).
--   * Five therizino-only rows (dino / OWNER "Therizino", mech false): Flowing Cuts (flow, speed), Building Fury (fury,
--     attack), Fourth Cut (fourth, sig), Flow Guard (guard, defense), Reaper's Harvest (harvest, health). The therizino's
--     STATS list reads harvest, fury, guard, flow (+ fourth once it is live).
--   * SkillTree.THERI_FOURTH (default false until the Fourth Cut mockup is picked, MDA-213): while false the fourth row has
--     dino "none" (shown to nobody; saved steps dropped by sanitize) and its effects stay off.
--   * Effects (off values when not bought / other dinos): flowWindow 0 (I 1.0 s chain window), flowGap 0 (II 0.26 s between
--     taps), flowRecover 0 (III 0.55 s finisher recovery), flowRefill false (star: a landed finisher refills a JUMP charge);
--     furyHit2 0 (I cut 2 = 12), furyFinisher 0 (II finisher = 26), furyStack 0 (III +2 per landed cut on the same dino),
--     furyFullMul 1 (star 1.5 on a full 3-hit chain); fourthDamage 0 (I 10, II 14), fourthReachMul 1 (III 1.3), fourthFast
--     false (star); guardTakenMul 1 (I 0.85 mid-chain), guardFinisherNoStun false (II), guardShoveMul 1 (III 0.5), guardKeepChain
--     false (star); harvestHeal 0 (I 0.04, II 0.06 of max health per finisher hit), harvestKillHeal 0 (III 0.15 over 3 s),
--     harvestLowDouble false (star: doubled under 30% health). SkillEffects 1.39 writes them; TheriAttackServer 1.1 acts on them.
SkillTree.THERI_STATS = true
SkillTree.THERI_FOURTH = false
if SkillTree.THERI_STATS and not SkillTree.PATHS.flow then
	local P = SkillTree.PATHS
	for _, id in ipairs({"regen", "lifesteal", "jaws", "hide", "legs"}) do
		if P[id] then
			P[id].notFor = P[id].notFor or {}
			P[id].notFor.Therizino = true
		end
	end
	local hasSig = false
	for _, a in ipairs(SkillTree.AREAS) do if a.id == "sig" then hasSig = true end end
	if not hasSig then table.insert(SkillTree.AREAS, {id = "sig", name = "Signature", color = {201, 162, 255}, paths = {}}) end
	local function add(id, name, areaId, steps)
		local p = path(id, name, false, false, steps)
		p.area = areaId
		p.dino = "Therizino"
		SkillTree.OWNER[id] = "Therizino"
		for _, a in ipairs(SkillTree.AREAS) do
			if a.id == areaId then table.insert(a.paths, p) end
		end
		P[id] = p
		table.insert(SkillTree.PATH_ORDER, id)
	end
	add("flow", "Flowing Cuts", "speed", {
		"Chain window 0.8 -> 1.0 s: more time to tap the next cut",
		"Taps come faster (0.33 -> 0.26 s apart)",
		"Finisher recovery 0.9 -> 0.55 s",
		"A finisher that lands refills one Spin Dive charge"})
	add("fury", "Building Fury", "attack", {
		"Cut 2 hits harder (9 -> 12)",
		"The finisher hits harder (20 -> 26)",
		"Each landed cut on the same dino adds +2 to the next",
		"A full 3-hit chain on one dino: the finisher deals x1.5"})
	add("fourth", "Fourth Cut", "sig", {
		"Tap after the finisher: a spinning sweep, 10 damage all around",
		"Sweep 14 damage",
		"The sweep reaches 30% further",
		"The sweep comes out faster and chains back into cut 1"})
	if not SkillTree.THERI_FOURTH then
		P.fourth.dino = "none"
		SkillTree.OWNER.fourth = "Therizino"
	end
	add("guard", "Flow Guard", "defense", {
		"Take 15% less damage while a chain is going",
		"Not stunned during the finisher",
		"Shoves push you half as far mid-chain",
		"A hit mid-chain does not break the chain"})
	add("harvest", "Reaper's Harvest", "health", {
		"Each finisher hit heals 4% of your max health",
		"Finisher heal 6%",
		"A combo kill heals 15% of your max health over 3 s",
		"Combo heals doubled under 30% health"})
end
do
	local effectsPre157 = SkillTree.effects
	function SkillTree.effects(steps, dino)
		local e = effectsPre157(steps, dino)
		if type(e) ~= "table" then return e end
		local on = SkillTree.THERI_STATS and dino == "Therizino" and SkillTree.PATHS.flow ~= nil
		local s = on and SkillTree.sanitize(steps, dino) or {}
		local fl, fu, fo, gu, ha = s.flow or 0, s.fury or 0, s.fourth or 0, s.guard or 0, s.harvest or 0
		e.flowWindow = fl >= 1 and 1.0 or 0
		e.flowGap = fl >= 2 and 0.26 or 0
		e.flowRecover = fl >= 3 and 0.55 or 0
		e.flowRefill = fl >= 4
		e.furyHit2 = fu >= 1 and 12 or 0
		e.furyFinisher = fu >= 2 and 26 or 0
		e.furyStack = fu >= 3 and 2 or 0
		e.furyFullMul = fu >= 4 and 1.5 or 1
		e.fourthDamage = fo >= 2 and 14 or (fo >= 1 and 10 or 0)
		e.fourthReachMul = fo >= 3 and 1.3 or 1
		e.fourthFast = fo >= 4
		e.guardTakenMul = gu >= 1 and 0.85 or 1
		e.guardFinisherNoStun = gu >= 2
		e.guardShoveMul = gu >= 3 and 0.5 or 1
		e.guardKeepChain = gu >= 4
		e.harvestHeal = ha >= 2 and 0.06 or (ha >= 1 and 0.04 or 0)
		e.harvestKillHeal = ha >= 3 and 0.15 or 0
		e.harvestLowDouble = ha >= 4
		return e
	end
end


-- v1.58 (MDA-213, plan docs/plans/THERIZINO_SPIN_STATS_v1.0.md Task 7; mockup docs/mockups/therizino_fourth_cut_v0.1.html, Kepu
-- 2026-11-03 picked "C" Ground Scythe): the Fourth Cut row goes live for the therizino (TheriAttackServer / TheriAttackTest 1.2,
-- TheriPose 1.4): SkillTree.THERI_FOURTH = true and the row's dino is "Therizino" again (it was "none" in 1.57). Texts and
-- effects are 1.57's (fourthDamage I 10 / II 14, fourthReachMul III 1.3, fourthFast star). The therizino's STATS list reads
-- harvest, fury, guard, flow, fourth. Switch SkillTree.THERI_FOURTH_LIVE (default true; false = 1.57: hidden).
SkillTree.THERI_FOURTH_LIVE = true
if SkillTree.THERI_STATS and SkillTree.THERI_FOURTH_LIVE and SkillTree.PATHS.fourth then
	SkillTree.THERI_FOURTH = true
	SkillTree.PATHS.fourth.dino = "Therizino"
end

-- v1.59 (pachy stat rows, MDA-230, plan docs/plans/PACHY_STATS_v1.0.md Task 1; mockup
-- docs/mockups/pachy_health_defense_options.html v0.1; Kepu 2026-11-04 "Option B for health and option A for defense", star
-- "Untouchable at 30%", step III "Shoves only"). Switch SkillTree.PACHY_STATS (default true; false = 1.58):
--   * Two pachy-only rows (dino / OWNER "Pachy", mech false, no slot): Last Stand (laststand, health) and Head Down
--     (headdown, defense). The pachy's STATS list reads laststand, dome, crest, headdown, legs. Regeneration / Lifesteal /
--     Jaws / Thick Hide stay blocked for the pachy (Kepu 2026-10-30); nothing here heals.
--   * Effects (off values when not bought / other dinos): lastStandMul 1 (I 0.85, II 0.75: damage taken below the line),
--     lastStandBelow 0 (0.3 from I: the health fraction), lastStandRefillMul 1 (III 0.714: headbutt refill 40% faster while
--     low), lastStandStar false / lastStandTime 0 (star: once per life, untouchable 1.5 s at the first drop below the line);
--     headDownMul 1 (I 0.85, II 0.75 while charging a headbutt), headDownNoShove false (III), headDownNoStun false (star).
--     SkillEffects 1.40 writes them; PachyStatsServer 1.0 and HeadbuttServer 1.15 act on them.
SkillTree.PACHY_STATS = true
if SkillTree.PACHY_STATS and not SkillTree.PATHS.laststand then
	local P = SkillTree.PATHS
	local function add(id, name, areaId, steps)
		local p = path(id, name, false, false, steps)
		p.area = areaId
		p.dino = "Pachy"
		SkillTree.OWNER[id] = "Pachy"
		for _, a in ipairs(SkillTree.AREAS) do
			if a.id == areaId then table.insert(a.paths, p) end
		end
		P[id] = p
		table.insert(SkillTree.PATH_ORDER, id)
	end
	add("laststand", "Last Stand", "health", {
		"Below 30% health: take 15% less damage",
		"Below 30% health: take 25% less damage",
		"Below 30% health: headbutt charges refill 40% faster",
		"Once per life, the first time you drop below 30% health you are untouchable for 1.5 s"})
	add("headdown", "Head Down", "defense", {
		"While charging a headbutt: take 15% less damage",
		"While charging: take 25% less damage",
		"While charging: can't be shoved",
		"While charging: can't be stunned"})
end
do
	local effectsPre159 = SkillTree.effects
	function SkillTree.effects(steps, dino)
		local e = effectsPre159(steps, dino)
		if type(e) ~= "table" then return e end
		local on = SkillTree.PACHY_STATS and dino == "Pachy" and SkillTree.PATHS.laststand ~= nil
		local s = on and SkillTree.sanitize(steps, dino) or {}
		local ls, hd = s.laststand or 0, s.headdown or 0
		e.lastStandMul = ls >= 2 and 0.75 or (ls >= 1 and 0.85 or 1)
		e.lastStandBelow = ls >= 1 and 0.3 or 0
		e.lastStandRefillMul = ls >= 3 and 0.714 or 1
		e.lastStandStar = ls >= 4
		e.lastStandTime = ls >= 4 and 1.5 or 0
		e.headDownMul = hd >= 2 and 0.75 or (hd >= 1 and 0.85 or 1)
		e.headDownNoShove = hd >= 3
		e.headDownNoStun = hd >= 4
		return e
	end
end


-- v1.60 (dilo stat rows, MDA-235, plan docs/plans/DILO_STATS_v1.0.md Task 1; Kepu 2026-11-04 picks 2 Venom Bite, 3 Quick Draw,
-- 5 Long Spit, 9 Toxic Blood, 14 Venom Feast, 20 Cold Blood; shared lines "Only its own"). Switch SkillTree.DILO_STATS
-- (default true; false = 1.59):
--   * PATHS regen / lifesteal / jaws / hide / legs get notFor.Dilo (the dilo sees none of the shared stat rows; saved steps on
--     them are dropped by sanitize for the dilo, so the points come back).
--   * Six dilo-only rows (dino / OWNER "Dilo", mech false, no slot): Venom Feast (venomfeast, health), Venom Bite (venombite,
--     attack), Long Spit (longspit, attack), Toxic Blood (toxicblood, defense), Quick Draw (quickdraw, speed), Cold Blood
--     (coldblood, sig). The dilo's STATS list reads venomfeast, venombite, longspit, toxicblood, quickdraw, coldblood.
--   * Effects (off values when not bought / other dinos): venomBiteDps 0 / venomBiteTime 0 (I 1/s 2 s, II 1/s 3 s, III 2/s 2 s,
--     star 2/s 3 s: bite poison); spitRangeMul 1 (I 7/6, II-III 4/3, star 1.5: dart range and soft-aim reach), spitSpeedMul 1
--     (III-star 1.4); toxicDps 0 / toxicTime 0 (Venom Bite's ladder: poison on a close attacker); feastFrac 0 (0.2 / 0.3 / 0.4
--     / 0.5 of the poison damage dealt is healed); drawHold 0 (= the model's hold; I 0.35, II-III 0.3, star 0.25), drawCooldown
--     0 (= the model's recharge; III 1.25, star 1.0); coldMul 1 (1.25 / 1.5 / 1.75 / 2), coldBelow 0 (0.3 from I), coldVenom
--     false (II up: the poison too), coldReset false (star: the dart recharges once per life at the first drop below the line).
--     SkillEffects 1.41 writes them; DiloAttackServer 1.1 / DiloAttackTest 1.1 act on them.
SkillTree.DILO_STATS = true
if SkillTree.DILO_STATS and not SkillTree.PATHS.venombite then
	local P = SkillTree.PATHS
	for _, id in ipairs({"regen", "lifesteal", "jaws", "hide", "legs"}) do
		if P[id] then
			P[id].notFor = P[id].notFor or {}
			P[id].notFor.Dilo = true
		end
	end
	local hasSig = false
	for _, a in ipairs(SkillTree.AREAS) do if a.id == "sig" then hasSig = true end end
	if not hasSig then table.insert(SkillTree.AREAS, {id = "sig", name = "Signature", color = {201, 162, 255}, paths = {}}) end
	local function add(id, name, areaId, steps)
		local p = path(id, name, false, false, steps)
		p.area = areaId
		p.dino = "Dilo"
		SkillTree.OWNER[id] = "Dilo"
		for _, a in ipairs(SkillTree.AREAS) do
			if a.id == areaId then table.insert(a.paths, p) end
		end
		P[id] = p
		table.insert(SkillTree.PATH_ORDER, id)
	end
	add("venomfeast", "Venom Feast", "health", {
		"Heal 20% of the poison damage you deal",
		"Heal 30% of your poison damage",
		"Heal 40% of your poison damage",
		"Heal 50% of your poison damage"})
	add("venombite", "Venom Bite", "attack", {
		"Bites poison 1/s for 2 s",
		"Bite poison lasts 3 s",
		"Bite poison 2/s for 2 s",
		"Bites poison 2/s for 3 s"})
	add("longspit", "Long Spit", "attack", {
		"Dart range 60 -> 70 studs",
		"Dart range 80 studs",
		"Darts fly 40% faster",
		"Dart range 90 studs"})
	add("toxicblood", "Toxic Blood", "defense", {
		"A dino that hits you up close is poisoned 1/s for 2 s",
		"Its poison lasts 3 s",
		"Its poison 2/s for 2 s",
		"Its poison 2/s for 3 s"})
	add("quickdraw", "Quick Draw", "speed", {
		"Spit ready after a 0.35 s hold (was 0.4)",
		"Spit ready after a 0.3 s hold",
		"Dart recharges in 1.25 s (was 1.5)",
		"0.25 s hold, and the dart recharges in 1.0 s"})
	add("coldblood", "Cold Blood", "sig", {
		"Below 30% health: darts deal 25% more damage",
		"Below 30% health: darts and poison deal 50% more",
		"Below 30% health: darts and poison deal 75% more",
		"Below 30% health: double damage, and once per life the dart recharges the moment you drop below 30%"})
end
do
	local effectsPre160 = SkillTree.effects
	local function ladder(n) -- poison dps / time: I 1/2, II 1/3, III 2/2, star 2/3
		if n >= 4 then return 2, 3 elseif n == 3 then return 2, 2 elseif n == 2 then return 1, 3 elseif n == 1 then return 1, 2 end
		return 0, 0
	end
	function SkillTree.effects(steps, dino)
		local e = effectsPre160(steps, dino)
		if type(e) ~= "table" then return e end
		local on = SkillTree.DILO_STATS and dino == "Dilo" and SkillTree.PATHS.venombite ~= nil
		local s = on and SkillTree.sanitize(steps, dino) or {}
		local vb, ls, tb, vf, qd, cb = s.venombite or 0, s.longspit or 0, s.toxicblood or 0, s.venomfeast or 0, s.quickdraw or 0,
			s.coldblood or 0
		e.venomBiteDps, e.venomBiteTime = ladder(vb)
		e.spitRangeMul = ls >= 4 and 1.5 or (ls >= 2 and 4 / 3 or (ls >= 1 and 7 / 6 or 1))
		e.spitSpeedMul = ls >= 3 and 1.4 or 1
		e.toxicDps, e.toxicTime = ladder(tb)
		e.feastFrac = vf >= 4 and 0.5 or (vf >= 3 and 0.4 or (vf >= 2 and 0.3 or (vf >= 1 and 0.2 or 0)))
		e.drawHold = qd >= 4 and 0.25 or (qd >= 2 and 0.3 or (qd >= 1 and 0.35 or 0))
		e.drawCooldown = qd >= 4 and 1.0 or (qd >= 3 and 1.25 or 0)
		e.coldMul = cb >= 4 and 2 or (cb >= 3 and 1.75 or (cb >= 2 and 1.5 or (cb >= 1 and 1.25 or 1)))
		e.coldBelow = cb >= 1 and 0.3 or 0
		e.coldVenom = cb >= 2
		e.coldReset = cb >= 4
		return e
	end
end

-- v1.61 (therizino mecha button parts, plan docs/plans/THERIZINO_PARTS_v1.0.md Task 1, MDA-241; mockup
-- docs/mockups/therizino_parts_options.html v0.1; Kepu 2026-11-04 picks 1, 3, 5, 12, 16, 18, 19; red-team "Across", "Yes, in
-- build 2", "Reuse the Tether chain", "Two builds"). Switch SkillTree.THERI_PARTS (default true; false = 1.60): 7
-- therizino-only mecha button parts (dino / OWNER "Therizino", mech, BUTTONS): zhook "Reaper's Hook" (attack), zfeather
-- "Feather Barrage" (attack), zharvest "Harvest Field" (attack), zgrapple "Grapple Zip" (speed), zdeflect "Deflector Claws"
-- (defense), zclock "Overclock Joints" (speed), zsnare "Snare Wires" (eng). SkillTree.THERI_PARTS_B2_SOON (default true;
-- build 1): zgrapple / zdeflect / zclock soon (not buyable, not LIVE_MECH). effects() (therizino only; off values elsewhere /
-- unbought): hookRange 50 / 65 (II) / 80 (III), hookCone 20, hookStun 1 + hookCut (star), hookCooldown 18 / 15 (III);
-- featherCount 8 / 10 (II) / 12 (star), featherRange 20 / 25 (II) / 30 (star), featherFan 60, featherDamage 3,
-- featherSlowMul 0.75, featherSlowTime 1 / 2 (III), featherCooldown 14; fieldRadius 6 / 8 (II) / 10 (star) (Kepu "Across":
-- 12 / 16 / 20 studs wide), fieldTime 3 / 4 (III) / 5 (star), fieldBleed 4, fieldSlowMul 0.7, fieldCooldown 20;
-- grappleRange 40 / 55 (II) / 70 (III), grappleCharges 1 / 2 (star), grappleCooldown 12 / 10 (III); deflectTime 1 / 1.5
-- (II) / 2 (III), deflectAngle 70, deflectLevel 1 (darts) / 2 (II: + boulders, cannon shots), deflectReflect (star),
-- deflectCooldown 16 / 13 (III); clockTime 3 / 4 (II) / 5 (III), clockRunMul 1.4, clockTapMul 0.7 (II), clockNoSlow (star),
-- clockCooldown 22 / 18 (III); snareMax 1 / 2 (II) / 3 (star), snareDamage 12, snareRoot 1 / 2 (III), snareRadius 4,
-- snareCooldown 18. Off: 0 / 1 (muls) / false.
SkillTree.THERI_PARTS = true
SkillTree.THERI_PARTS_B2_SOON = true
if SkillTree.THERI_PARTS and not SkillTree.PATHS.zhook then
	local function part(id, name, areaId, steps)
		local p = path(id, name, true, false, steps)
		p.area = areaId
		p.dino = "Therizino"
		SkillTree.OWNER[id] = "Therizino"
		SkillTree.LIVE_MECH[id] = true
		SkillTree.BUTTONS[id] = true
		for _, a in ipairs(SkillTree.AREAS) do
			if a.id == areaId then table.insert(a.paths, p) end
		end
		SkillTree.PATHS[id] = p
		table.insert(SkillTree.PATH_ORDER, id)
	end
	part("zhook", "Reaper's Hook", "attack", {
		"Button: fire a claw chain up to 50 studs and yank the dino in. Recharges in 18 s",
		"Chain reaches 65 studs", "Chain reaches 80 studs; recharges in 15 s",
		"The yanked dino is stunned 1 s and cut 1 starts on it"})
	part("zfeather", "Feather Barrage", "attack", {
		"Button: fire 8 feather blades in a 20-stud fan: 3 damage each, hit dinos slowed 25% for 1 s. Recharges in 14 s",
		"10 blades, fan reaches 25 studs", "Slow lasts 2 s", "12 blades, fan reaches 30 studs"})
	part("zharvest", "Harvest Field", "attack", {
		"Button: stab the claws down: a 12-stud-wide circle for 3 s. Enemies inside bleed 4/s and are slowed 30%. Recharges in 20 s",
		"Circle 16 studs wide", "Lasts 4 s", "Circle 20 studs wide, lasts 5 s"})
	part("zgrapple", "Grapple Zip", "speed", {
		"Button: hook a tree or wall up to 40 studs away and zip there. Recharges in 12 s",
		"Reaches 55 studs", "Reaches 70 studs; recharges in 10 s", "2 charges"})
	part("zdeflect", "Deflector Claws", "defense", {
		"Button: claws spin in front for 1 s and block darts. Recharges in 16 s",
		"Spin 1.5 s; blocks boulders and cannon shots too", "Spin 2 s; recharges in 13 s",
		"Blocked shots bounce back at the shooter"})
	part("zclock", "Overclock Joints", "speed", {
		"Button: for 3 s, run 40% faster. Recharges in 22 s",
		"Lasts 4 s; cut taps come 30% faster too", "Lasts 5 s; recharges in 18 s",
		"Slows don't work on you while it's on"})
	part("zsnare", "Snare Wires", "eng", {
		"Button: lay a wire trap. The first dino to cross it is rooted 1 s and takes 12. Recharges in 18 s",
		"2 traps at once", "Rooted 2 s", "3 traps at once"})
	if SkillTree.THERI_PARTS_B2_SOON then
		for _, id in ipairs({"zgrapple", "zdeflect", "zclock"}) do
			SkillTree.PATHS[id].soon = true
			SkillTree.LIVE_MECH[id] = nil
		end
	end
end
do
	local effectsPre161 = SkillTree.effects
	function SkillTree.effects(steps, dino)
		local e = effectsPre161(steps, dino)
		if type(e) ~= "table" then return e end
		local on = SkillTree.THERI_PARTS and dino == "Therizino" and SkillTree.PATHS.zhook ~= nil
		local s = on and SkillTree.sanitize(steps, dino) or {}
		local h, f, fd, g, d, c, sn = s.zhook or 0, s.zfeather or 0, s.zharvest or 0, s.zgrapple or 0, s.zdeflect or 0,
			s.zclock or 0, s.zsnare or 0
		e.hookRange = h >= 3 and 80 or (h >= 2 and 65 or (h >= 1 and 50 or 0))
		e.hookCone = h >= 1 and 20 or 0
		e.hookStun = h >= 4 and 1 or 0
		e.hookCut = h >= 4
		e.hookCooldown = h >= 3 and 15 or (h >= 1 and 18 or 0)
		e.featherCount = f >= 4 and 12 or (f >= 2 and 10 or (f >= 1 and 8 or 0))
		e.featherRange = f >= 4 and 30 or (f >= 2 and 25 or (f >= 1 and 20 or 0))
		e.featherFan = f >= 1 and 60 or 0
		e.featherDamage = f >= 1 and 3 or 0
		e.featherSlowMul = f >= 1 and 0.75 or 1
		e.featherSlowTime = f >= 3 and 2 or (f >= 1 and 1 or 0)
		e.featherCooldown = f >= 1 and 14 or 0
		e.fieldRadius = fd >= 4 and 10 or (fd >= 2 and 8 or (fd >= 1 and 6 or 0))
		e.fieldTime = fd >= 4 and 5 or (fd >= 3 and 4 or (fd >= 1 and 3 or 0))
		e.fieldBleed = fd >= 1 and 4 or 0
		e.fieldSlowMul = fd >= 1 and 0.7 or 1
		e.fieldCooldown = fd >= 1 and 20 or 0
		e.grappleRange = g >= 3 and 70 or (g >= 2 and 55 or (g >= 1 and 40 or 0))
		e.grappleCharges = g >= 4 and 2 or (g >= 1 and 1 or 0)
		e.grappleCooldown = g >= 3 and 10 or (g >= 1 and 12 or 0)
		e.deflectTime = d >= 3 and 2 or (d >= 2 and 1.5 or (d >= 1 and 1 or 0))
		e.deflectAngle = d >= 1 and 70 or 0
		e.deflectLevel = d >= 2 and 2 or (d >= 1 and 1 or 0)
		e.deflectReflect = d >= 4
		e.deflectCooldown = d >= 3 and 13 or (d >= 1 and 16 or 0)
		e.clockTime = c >= 3 and 5 or (c >= 2 and 4 or (c >= 1 and 3 or 0))
		e.clockRunMul = c >= 1 and 1.4 or 1
		e.clockTapMul = c >= 2 and 0.7 or 1
		e.clockNoSlow = c >= 4
		e.clockCooldown = c >= 3 and 18 or (c >= 1 and 22 or 0)
		e.snareMax = sn >= 4 and 3 or (sn >= 2 and 2 or (sn >= 1 and 1 or 0))
		e.snareDamage = sn >= 1 and 12 or 0
		e.snareRoot = sn >= 3 and 2 or (sn >= 1 and 1 or 0)
		e.snareRadius = sn >= 1 and 4 or 0
		e.snareCooldown = sn >= 1 and 18 or 0
		return e
	end
end

-- v1.62 (therizino parts build 2, plan docs/plans/THERIZINO_PARTS_v1.0.md Task 7, MDA-247; Kepu 2026-11-04 "Publish then
-- continue building"): Grapple Zip (zgrapple), Deflector Claws (zdeflect) and Overclock Joints (zclock) go live: not soon,
-- LIVE_MECH, buyable and slottable; their effects follow 1.61's numbers. Switch SkillTree.THERI_PARTS_B2_LIVE (default true;
-- false = 1.61: soon).
SkillTree.THERI_PARTS_B2_LIVE = true
if SkillTree.THERI_PARTS and SkillTree.THERI_PARTS_B2_LIVE and SkillTree.PATHS.zgrapple then
	SkillTree.THERI_PARTS_B2_SOON = false
	for _, id in ipairs({"zgrapple", "zdeflect", "zclock"}) do
		SkillTree.PATHS[id].soon = false
		SkillTree.LIVE_MECH[id] = true
	end
end

-- v1.63 (Kepu 2026-11-04 15:21 "The grappling hook feels off, also the overclocked legs should always be on but passive and
-- take up a slot"; mockup docs/mockups/therizino_grapple_overclock_v0.1.html picks Grapple-A, Overclock-A; plan
-- docs/plans/THERIZINO_GRAPPLE_CLOCK_v1.0.md, MDA-255 / MDA-257):
--   * SkillTree.THERI_GRAPPLE_V2 (default true): grappleRange 90 / 110 (II) / 130 (III) (was 40 / 55 / 70); new zgrapple texts
--     (the marker, the air latch). Charges and recharge as before. false = 1.62.
--   * SkillTree.THERI_CLOCK_PASSIVE (default true): new zclock texts (always on while slotted, same numbers; TheriMovesServer
--     1.3 makes it passive). Effects unchanged (clockTime / clockCooldown are no longer used while passive). false = 1.62.
SkillTree.THERI_GRAPPLE_V2 = true
SkillTree.THERI_CLOCK_PASSIVE = true
if SkillTree.THERI_PARTS and SkillTree.PATHS.zgrapple and SkillTree.THERI_GRAPPLE_V2 then
	SkillTree.PATHS.zgrapple.steps = {
		"Button: zip to the yellow marker, up to 90 studs. With nothing to grab it latches in the air. Recharges in 12 s",
		"Reaches 110 studs", "Reaches 130 studs; recharges in 10 s", "2 charges"}
	local effectsPre163 = SkillTree.effects
	function SkillTree.effects(steps, dino)
		local e = effectsPre163(steps, dino)
		if type(e) ~= "table" or not SkillTree.THERI_GRAPPLE_V2 then return e end
		local r = tonumber(e.grappleRange) or 0
		if r >= 70 then e.grappleRange = 130 elseif r >= 55 then e.grappleRange = 110 elseif r >= 40 then e.grappleRange = 90 end
		return e
	end
end
if SkillTree.THERI_PARTS and SkillTree.PATHS.zclock and SkillTree.THERI_CLOCK_PASSIVE then
	SkillTree.PATHS.zclock.steps = {
		"Always on while slotted (no button): run 40% faster", "Cut taps come 30% faster too",
		"Nothing extra yet (it's always on now)", "Slows don't work on you"}
end

-- v1.64 (grapple lock-on, Kepu 2026-11-04 pick "A"; plan docs/plans/THERIZINO_GRAPPLE_LOCKON_v1.0.md, MDA-260): with
-- SkillTree.THERI_GRAPPLE_LOCKON (default true) the zgrapple step 1 text says hold to lock, let go to zip. false = 1.63.
SkillTree.THERI_GRAPPLE_LOCKON = true
if SkillTree.THERI_PARTS and SkillTree.PATHS.zgrapple and SkillTree.THERI_GRAPPLE_LOCKON then
	SkillTree.PATHS.zgrapple.steps[1] = "Button: hold to lock onto the furthest tree or rock ahead (up to 90 studs), let go to zip there. Nothing ahead: it latches in the air. Recharges in 12 s"
end

-- v1.65 (therizino moves rework, Kepu 2026-11-04 picks "Harvest-C, Snare-B, Dash-C, Hook-B", dash look "Storm Core", ring "30
-- studs"; storyboard tools/mockup/therizino_moves_anim.js v0.3; plan docs/plans/THERIZINO_MOVES_REWORK_v1.0.md, MDA-262). Same
-- ids, steps and slots; new texts and numbers, one switch each (default true; false = 1.64 for that part):
--   * SkillTree.THERI_VORTEX (zharvest, Reaper Vortex): fieldRadius 15 / 17 (II) / 19 (star) = 30 / 34 / 38 studs wide
--     (1.61's +4-stud steps kept); time, bleed, slow, recharge as before (TheriMovesServer 1.4 pulls 6 studs/s).
--   * SkillTree.THERI_BOLA (zsnare, Bola): snareRange 35 / 45 (III) (new; 0 off), snareCooldown 14 (was 18); snareMax = charges
--     1 / 2 (II) / 3 (star), snareRoot 1 / 2 (III), snareDamage 12 as before.
--   * SkillTree.THERI_DASH (zgrapple, name "Dash", Storm Core): grappleRange 30 / 40 (II) / 50 (III), grappleCharges 2 / 3
--     (star), grappleCooldown 6 / 5 (III).
--   * SkillTree.THERI_REEL (zhook, Reaper Reel): hookCone 35 (was 20), hookCooldown 14 (was 18 / 15); range 50 / 65 / 80 and the
--     star (stun 1 s + cut 1) as before.
SkillTree.THERI_VORTEX = true
SkillTree.THERI_BOLA = true
SkillTree.THERI_DASH = true
SkillTree.THERI_REEL = true
if SkillTree.THERI_PARTS and SkillTree.PATHS.zhook then
	local P = SkillTree.PATHS
	if SkillTree.THERI_VORTEX and P.zharvest then
		P.zharvest.steps = {
			"Button: stab the claws in: a spinning sickle ring 30 studs wide drags enemies toward you for 3 s. They bleed 4/s and are slowed 30%. Recharges in 20 s",
			"Ring 34 studs wide", "Lasts 4 s", "Ring 38 studs wide, lasts 5 s"}
	end
	if SkillTree.THERI_BOLA and P.zsnare then
		P.zsnare.steps = {
			"Button: sling a bola from the tail at the nearest enemy ahead (35 studs). It wraps their legs: held 1 s, 12 damage. Recharges in 14 s",
			"2 bolas ready at once", "Held 2 s; reaches 45 studs", "3 bolas ready at once"}
	end
	if SkillTree.THERI_DASH and P.zgrapple then
		P.zgrapple.name = "Dash"
		P.zgrapple.steps = {
			"Button: jolt 30 studs the way you're moving (standing still: forward). 2 charges, each back in 6 s",
			"Dashes 40 studs", "Dashes 50 studs; charges back in 5 s", "3 charges"}
	end
	if SkillTree.THERI_REEL and P.zhook then
		P.zhook.steps = {
			"Button: fire the chest claw at the nearest enemy ahead (50 studs) and reel yourself in for a double claw slash: 10 damage. Recharges in 14 s",
			"Chain reaches 65 studs", "Chain reaches 80 studs", "The slashed dino is stunned 1 s and cut 1 starts on it"}
	end
	local effectsPre165 = SkillTree.effects
	function SkillTree.effects(steps, dino)
		local e = effectsPre165(steps, dino)
		if type(e) ~= "table" then return e end
		e.snareRange = 0
		if dino ~= "Therizino" then return e end
		local s = SkillTree.sanitize(steps, dino) or {}
		local fd, sn, g, h = s.zharvest or 0, s.zsnare or 0, s.zgrapple or 0, s.zhook or 0
		if SkillTree.THERI_VORTEX and fd >= 1 and (tonumber(e.fieldRadius) or 0) > 0 then
			e.fieldRadius = fd >= 4 and 19 or (fd >= 2 and 17 or 15)
		end
		if SkillTree.THERI_BOLA and sn >= 1 and (tonumber(e.snareDamage) or 0) > 0 then
			e.snareRange = sn >= 3 and 45 or 35
			e.snareCooldown = 14
		end
		if SkillTree.THERI_DASH and g >= 1 and (tonumber(e.grappleRange) or 0) > 0 then
			e.grappleRange = g >= 3 and 50 or (g >= 2 and 40 or 30)
			e.grappleCharges = g >= 4 and 3 or 2
			e.grappleCooldown = g >= 3 and 5 or 6
		end
		if SkillTree.THERI_REEL and h >= 1 and (tonumber(e.hookRange) or 0) > 0 then
			e.hookCone = 35
			e.hookCooldown = 14
		end
		return e
	end
end

-- v1.66 (Kepu 2026-11-04 17:54 "Make it overclock tier 3 to give you an extra jump"): SkillTree.THERI_CLOCK_JUMP (default true;
-- false = 1.65): zclock step 3 text "One extra jump charge"; effect clockJump = 1 from step 3 (0 below / off / other dinos).
-- SkillEffects 1.44 writes it as TheriClockJump; TheriMovesServer 1.5 adds it to JumpCharges while Overclock is passive.
SkillTree.THERI_CLOCK_JUMP = true
if SkillTree.THERI_PARTS and SkillTree.PATHS.zclock and SkillTree.THERI_CLOCK_JUMP then
	SkillTree.PATHS.zclock.steps[3] = "One extra jump charge"
end
do
	local effectsPre166 = SkillTree.effects
	function SkillTree.effects(steps, dino)
		local e = effectsPre166(steps, dino)
		if type(e) ~= "table" then return e end
		e.clockJump = 0
		if not (SkillTree.THERI_CLOCK_JUMP and SkillTree.THERI_PARTS and dino == "Therizino" and SkillTree.PATHS.zclock) then return e end
		local s = SkillTree.sanitize(steps, dino) or {}
		if (s.zclock or 0) >= 3 then e.clockJump = 1 end
		return e
	end
end

-- v1.67 (Kepu 2026-11-05 15:01 "I think the feather thing needs more range", pick "35 / 40 / 50"): SkillTree.THERI_FEATHER_RANGE2
-- (default true; false = 1.66): zfeather texts say 35 / 40 / 50 studs; effect featherRange = 35 (step 1) / 40 (II) / 50 (star)
-- for a therizino with the part (0 below / off / other dinos, as before). Nothing else of zfeather changes.
SkillTree.THERI_FEATHER_RANGE2 = true
if SkillTree.THERI_PARTS and SkillTree.PATHS.zfeather and SkillTree.THERI_FEATHER_RANGE2 then
	SkillTree.PATHS.zfeather.steps[1] = "Button: fire 8 feather blades in a 35-stud fan: 3 damage each, hit dinos slowed 25% for 1 s. Recharges in 14 s"
	SkillTree.PATHS.zfeather.steps[2] = "10 blades, fan reaches 40 studs"
	SkillTree.PATHS.zfeather.steps[4] = "12 blades, fan reaches 50 studs"
end
do
	local effectsPre167 = SkillTree.effects
	function SkillTree.effects(steps, dino)
		local e = effectsPre167(steps, dino)
		if type(e) ~= "table" then return e end
		if not (SkillTree.THERI_FEATHER_RANGE2 and SkillTree.THERI_PARTS and dino == "Therizino" and SkillTree.PATHS.zfeather) then return e end
		local f = (SkillTree.sanitize(steps, dino) or {}).zfeather or 0
		if f >= 1 and (e.featherRange or 0) > 0 then e.featherRange = f >= 4 and 50 or (f >= 2 and 40 or 35) end
		return e
	end
end

-- v1.68 (Kepu 2026-11-05 21:53 "make it 50% slower and even when they step out they're slow for 3 seconds. Make the splash
-- area 1.3x bigger"): SkillTree.HERRERA_GOO_TUNE (default true; false = 1.67): goo effects gooRadius x 1.3 (8 -> 10.4,
-- II 11 -> 14.3) and gooSlowMul 0.5 (was 0.6) for a Herrera with the part (0 / 1 below or off, as before); the texts say the
-- 21-stud puddle (29 at II), 50% and the 3 s after leaving (HerreraMovesServer 1.6 keeps the slow 3 s after the last tick).
-- Nothing else of goo changes.
SkillTree.HERRERA_GOO_TUNE = true
if SkillTree.HERRERA_PARTS and SkillTree.PATHS.goo and SkillTree.HERRERA_GOO_TUNE then
	SkillTree.PATHS.goo.steps[1] = "Button: toss a goo blob 30 studs ahead (straight down while gliding). It splats into a 21-stud puddle for 5 s; enemies in it are slowed 50%, and stay slowed for 3 s after they leave. Recharges in 14 s"
	SkillTree.PATHS.goo.steps[2] = "Puddle 29 studs wide"
end
do
	local effectsPre168 = SkillTree.effects
	function SkillTree.effects(steps, dino)
		local e = effectsPre168(steps, dino)
		if type(e) ~= "table" then return e end
		if not (SkillTree.HERRERA_GOO_TUNE and SkillTree.HERRERA_PARTS and SkillTree.PATHS.goo) then return e end
		if (e.gooRadius or 0) > 0 then e.gooRadius = math.floor(e.gooRadius * 1.3 * 10 + 0.5) / 10 end
		if (e.gooSlowMul or 1) < 1 then e.gooSlowMul = 0.5 end
		return e
	end
end


-- v1.69 (dilo mecha button parts, plan docs/plans/DILO_PARTS_v1.0.md Task 1, MDA-314; mockup docs/mockups/dilo_parts_options.html
-- v0.1; Kepu 2026-11-06 picks 1, 3, 9, 13, 15, 16, 20, looks "All recommended except Venom Gatling - C, Toxin Mortar - C",
-- red-team "Use the proposals", "Same venom system"). Switch SkillTree.DILO_PARTS (default true; false = 1.68): 7 dilo-only mecha
-- button parts (dino / OWNER "Dilo", mech, BUTTONS): dgatling "Venom Gatling" (attack), dmortar "Toxin Mortar" (attack), dhiss
-- "Sonic Hiss" (attack), dspine "Spine Burst" (defense), dpump "Antivenom Pump" (defense), djets "Spring Jets" (speed), dover
-- "Venom Overdrive" (sig). SkillTree.DILO_PARTS_B2_SOON (default true; build 1): dhiss / dpump / djets soon (not buyable, not
-- LIVE_MECH). effects() writes ONLY new d* fields (the 1.61 lesson: never a field another dino uses); dilo only, off values
-- (0 / 1 for muls / false) elsewhere or unbought: dGatlingCount 4 / 6 (II) / 8 (star), dGatlingDamage 3, dGatlingCone 25,
-- dGatlingTime 1, dGatlingCooldown 12 / 10 (III); dMortarRange 40 / 50 (II) / 60 (star), dMortarRadius 8 / 10 (II) / 12 (star)
-- (16 / 20 / 24 studs wide), dMortarTime 3 / 4 (III) / 5 (star), dMortarCooldown 16; dHissRange 20 / 25 (II) / 30 (star),
-- dHissAngle 35, dHissKnock 18, dHissSilence 1.5 / 2 (III) / 3 (star), dHissCooldown 15 / 12 (III); dSpineCount 6 / 8 (II) / 12
-- (star), dSpineDamage 4, dSpineRange 22, dSpineVenom (III), dSpineCooldown 12; dPumpHeal 15 / 20 (II) / 30 (III), dPumpImmune
-- 4 (star), dPumpCooldown 20; dJetsDist 25 / 30 (II) / 40 (III), dJetsCharges 1 / 2 (II) / 3 (star), dJetsTrail 6 (III, s),
-- dJetsCooldown 6 (per charge); dOverTime 4 / 6 (II) / 8 (star), dOverVenomMul 2 (III), dOverCooldown 30.
SkillTree.DILO_PARTS = true
SkillTree.DILO_PARTS_B2_SOON = true
if SkillTree.DILO_PARTS and not SkillTree.PATHS.dgatling then
	local function part(id, name, areaId, steps)
		local p = path(id, name, true, false, steps)
		p.area = areaId
		p.dino = "Dilo"
		SkillTree.OWNER[id] = "Dilo"
		SkillTree.LIVE_MECH[id] = true
		SkillTree.BUTTONS[id] = true
		local found = false
		for _, a in ipairs(SkillTree.AREAS) do
			if a.id == areaId then table.insert(a.paths, p); found = true end
		end
		if not found then table.insert(SkillTree.AREAS, {id = areaId, name = "Signature", color = {201, 162, 255}, paths = {p}}) end
		SkillTree.PATHS[id] = p
		table.insert(SkillTree.PATH_ORDER, id)
	end
	part("dgatling", "Venom Gatling", "attack", {
		"Button: the hood barrels fire 4 auto-aimed darts in 1 s: 3 damage each plus dart venom. Recharges in 12 s",
		"6 darts", "Recharges in 10 s", "8 darts"})
	part("dmortar", "Toxin Mortar", "attack", {
		"Button: the chest launcher lobs a canister up to 40 studs: a 16-stud poison cloud for 3 s. Recharges in 16 s",
		"Reaches 50 studs, cloud 20 studs wide", "Cloud lasts 4 s", "Reaches 60 studs, cloud 24 studs wide, lasts 5 s"})
	part("dhiss", "Sonic Hiss", "attack", {
		"Button: the hood speakers blast a 20-stud cone: dinos are knocked back and their mecha parts are silenced 1.5 s. Recharges in 15 s",
		"Cone reaches 25 studs", "Silence lasts 2 s; recharges in 12 s", "Cone reaches 30 studs, silence lasts 3 s"})
	part("dspine", "Spine Burst", "defense", {
		"Button: the frill fires 6 spines all around: 4 damage each. Recharges in 12 s",
		"8 spines", "Spines add dart venom", "12 spines"})
	part("dpump", "Antivenom Pump", "defense", {
		"Button: the back pump clears your debuffs and heals 15. Recharges in 20 s",
		"Heals 20", "Heals 30", "Then 4 s immune to slows, stuns and blinds"})
	part("djets", "Spring Jets", "speed", {
		"Button: the tail booster dashes you 25 studs the way you move. Recharges in 6 s",
		"30 studs, 2 charges", "40 studs; leaves a poison trail", "3 charges"})
	part("dover", "Venom Overdrive", "sig", {
		"Button: for 4 s your darts recharge at once. Recharges in 30 s",
		"Lasts 6 s", "Your venom does double damage while it's on", "Lasts 8 s"})
	if SkillTree.DILO_PARTS_B2_SOON then
		for _, id in ipairs({"dhiss", "dpump", "djets"}) do
			SkillTree.PATHS[id].soon = true
			SkillTree.LIVE_MECH[id] = nil
		end
	end
end
-- v1.70 (dilo parts build 2, MDA-320, plan docs/plans/DILO_PARTS_v1.0.md Task 7; Kepu 2026-11-06 "Publish then build"):
-- SkillTree.DILO_PARTS_B2_LIVE (default true; false = 1.69): dhiss / dpump / djets lose `soon` and become LIVE_MECH (buyable,
-- slottable; SkillEffects 1.45 then writes their DiloPart* attributes, DiloMovesServer 1.1 acts on them). Texts / effects unchanged.
SkillTree.DILO_PARTS_B2_LIVE = true
if SkillTree.DILO_PARTS and SkillTree.DILO_PARTS_B2_LIVE and SkillTree.PATHS.dgatling then
	for _, id in ipairs({"dhiss", "dpump", "djets"}) do
		if SkillTree.PATHS[id] then
			SkillTree.PATHS[id].soon = nil
			SkillTree.LIVE_MECH[id] = true
		end
	end
end
do
	local effectsPre169 = SkillTree.effects
	function SkillTree.effects(steps, dino)
		local e = effectsPre169(steps, dino)
		if type(e) ~= "table" then return e end
		if not SkillTree.DILO_PARTS or not SkillTree.PATHS.dgatling then return e end
		local on = dino == "Dilo"
		local s = on and SkillTree.sanitize(steps, dino) or {}
		local g, m, h, sp, pu, j, o = s.dgatling or 0, s.dmortar or 0, s.dhiss or 0, s.dspine or 0, s.dpump or 0, s.djets or 0,
			s.dover or 0
		e.dGatlingCount = g >= 4 and 8 or (g >= 2 and 6 or (g >= 1 and 4 or 0))
		e.dGatlingDamage = g >= 1 and 3 or 0
		e.dGatlingCone = g >= 1 and 25 or 0
		e.dGatlingTime = g >= 1 and 1 or 0
		e.dGatlingCooldown = g >= 3 and 10 or (g >= 1 and 12 or 0)
		e.dMortarRange = m >= 4 and 60 or (m >= 2 and 50 or (m >= 1 and 40 or 0))
		e.dMortarRadius = m >= 4 and 12 or (m >= 2 and 10 or (m >= 1 and 8 or 0))
		e.dMortarTime = m >= 4 and 5 or (m >= 3 and 4 or (m >= 1 and 3 or 0))
		e.dMortarCooldown = m >= 1 and 16 or 0
		e.dHissRange = h >= 4 and 30 or (h >= 2 and 25 or (h >= 1 and 20 or 0))
		e.dHissAngle = h >= 1 and 35 or 0
		e.dHissKnock = h >= 1 and 18 or 0
		e.dHissSilence = h >= 4 and 3 or (h >= 3 and 2 or (h >= 1 and 1.5 or 0))
		e.dHissCooldown = h >= 3 and 12 or (h >= 1 and 15 or 0)
		e.dSpineCount = sp >= 4 and 12 or (sp >= 2 and 8 or (sp >= 1 and 6 or 0))
		e.dSpineDamage = sp >= 1 and 4 or 0
		e.dSpineRange = sp >= 1 and 22 or 0
		e.dSpineVenom = sp >= 3
		e.dSpineCooldown = sp >= 1 and 12 or 0
		e.dPumpHeal = pu >= 3 and 30 or (pu >= 2 and 20 or (pu >= 1 and 15 or 0))
		e.dPumpImmune = pu >= 4 and 4 or 0
		e.dPumpCooldown = pu >= 1 and 20 or 0
		e.dJetsDist = j >= 3 and 40 or (j >= 2 and 30 or (j >= 1 and 25 or 0))
		e.dJetsCharges = j >= 4 and 3 or (j >= 2 and 2 or (j >= 1 and 1 or 0))
		e.dJetsTrail = j >= 3 and 6 or 0
		e.dJetsCooldown = j >= 1 and 6 or 0
		e.dOverTime = o >= 4 and 8 or (o >= 2 and 6 or (o >= 1 and 4 or 0))
		e.dOverVenomMul = o >= 3 and 2 or 1
		e.dOverCooldown = o >= 1 and 30 or 0
		return e
	end
end

-- v1.71 (Bola reach, MDA-324, plan docs/plans/FIXES_2026-11-06_v1.0.md Fix 2; Kepu 2026-11-06 "B: 60 / 80"): with
-- SkillTree.THERI_BOLA_RANGE_V2 (default true; false = 1.70: 35 / 45) the zsnare (Bola) reach is 60 studs (I-II) and 80 (III+)
-- and the step texts say so. Only the therizino's own snareRange is set (other dinos keep the 1.65 wrapper's 0). SkillEffects
-- 1.43 writes it as TheriSnareRange; TheriMovesServer reads it (flight clamp(d / 80, 0.25, 0.6) unchanged: faster at 80).
SkillTree.THERI_BOLA_RANGE_V2 = true
if SkillTree.THERI_PARTS and SkillTree.THERI_BOLA and SkillTree.THERI_BOLA_RANGE_V2 and SkillTree.PATHS.zsnare then
	local st = SkillTree.PATHS.zsnare.steps
	st[1] = "Button: sling a bola from the tail at the nearest enemy ahead (60 studs). It wraps their legs: held 1 s, 12 damage. Recharges in 14 s"
	st[3] = "Held 2 s; reaches 80 studs"
	local effectsPre171 = SkillTree.effects
	function SkillTree.effects(steps, dino)
		local e = effectsPre171(steps, dino)
		if type(e) ~= "table" or dino ~= "Therizino" then return e end
		local r = tonumber(e.snareRange) or 0
		if r > 0 then e.snareRange = r >= 45 and 80 or 60 end
		return e
	end
end


-- v1.72 (troodon mecha parts, plan docs/plans/TROODON_PARTS_v1.0.md ticket 2, MDA-346; looks + moves mockup
-- docs/mockups/troodon_parts_options.html v0.2; Kepu 2026-11-06 19:44 picks H1 / A6 / D1 / D18 / S6 / H7 / H12 / D5 / A10,
-- passives "Slotted parts", 21:24 "the areas should be doubled", 21:3x "two builds", "Do 50 studs", bounce "30 / 40").
-- Switch SkillTree.TROO_PARTS (default true; false = 1.71): 9 troodon-only mecha parts (dino / OWNER "Troodon", mech, all in
-- BUTTONS so each takes a slot, like Mecha Legs): buttons omender "Mender Drone" (health), olantern "Arc Lantern" (attack),
-- osapwall "Sap Wall" (defense), oshed "Feather Shed" (defense), oportal "Portal Feathers" (speed); always on (still take a
-- slot) olastfeather "Last Feather" (health), oplume "Overheal Plume" (health), ofortify "Fortify Field" (defense), oricochet
-- "Ricochet Pod" (attack). SkillTree.TROO_PARTS_B2_SOON (default true; build 1): the 4 always-on parts are listed but "soon"
-- (not buyable, not LIVE_MECH; their effects come in build 2, MDA-349). effects() writes ONLY new o* fields (the 1.61
-- lesson); troodon only (dino == "Troodon"), off values (0 / false) elsewhere or unbought. Studs are game studs (the texts):
-- oMenderHeal 4 (per s), oMenderTime 4 / 5.4 (II), oMenderRange 40, oMenderHop (star), oMenderCooldown 20 / 14.8 (III);
-- oLanternRange 40, oLanternChain 24 / 32.4 (II), oLanternTargets 2 / 3 (star), oLanternDamage 8, oLanternCooldown 14 / 10.3
-- (III); oSapRange 40, oSapWidth 50 / 67.5 (II), oSapTime 2.1 / 2.9 (III) / 4 (star), oSapCooldown 18; oShedImmune 1 / 1.4
-- (II), oShedCooldown 24 / 17.7 (III), oShedKnockRadius 20 (star), oShedSlowMul 0.75 (star; 1 below), oShedSlowTime 2 (star);
-- oPortalRange 40 / 54 (II), oPortalTime 6 / 8.1 (III), oPortalSquad (star), oPortalCooldown 20.
SkillTree.TROO_PARTS = true
SkillTree.TROO_PARTS_B2_SOON = true
if SkillTree.TROO_PARTS and not SkillTree.PATHS.omender then
	local function part(id, name, areaId, steps)
		local p = path(id, name, true, false, steps)
		p.area = areaId
		p.dino = "Troodon"
		SkillTree.OWNER[id] = "Troodon"
		SkillTree.LIVE_MECH[id] = true
		SkillTree.BUTTONS[id] = true
		local found = false
		for _, a in ipairs(SkillTree.AREAS) do
			if a.id == areaId then table.insert(a.paths, p); found = true end
		end
		if not found then table.insert(SkillTree.AREAS, {id = areaId, name = "Signature", color = {201, 162, 255}, paths = {p}}) end
		SkillTree.PATHS[id] = p
		table.insert(SkillTree.PATH_ORDER, id)
	end
	part("omender", "Mender Drone", "health", {
		"Button: the drone heals the most hurt squadmate within 40 studs (you, with no squad) 4 per second for 4 s. Recharges in 20 s",
		"Heals for 5.4 s", "Recharges in 14.8 s", "When its target is full it moves on to the next most hurt squadmate"})
	part("olantern", "Arc Lantern", "attack", {
		"Button: throw a lantern up to 40 studs; it zaps the nearest enemy near it, then chains to 1 more within 24 studs: 8 damage each. Recharges in 14 s",
		"Chains reach 32.4 studs", "Recharges in 10.3 s", "Chains to 3 enemies"})
	part("osapwall", "Sap Wall", "defense", {
		"Button: throw a sap pod up to 40 studs: it hardens into a 50-stud wall that blocks dinos and shots for 2.1 s. Recharges in 18 s",
		"Wall 67.5 studs wide", "Lasts 2.9 s", "Lasts 4 s"})
	part("oshed", "Feather Shed", "defense", {
		"Button: shed your feathers to break out of a stun, pin or grab; immune to them for 1 s. Recharges in 24 s",
		"Immune 1.4 s", "Recharges in 17.7 s", "The burst knocks dinos within 20 studs back and slows them 25% for 2 s"})
	part("oportal", "Portal Feathers", "speed", {
		"Button: fling two linked feather rings, one just ahead and one up to 40 studs away; walk into one, come out of the other. They last 6 s, you only. Recharges in 20 s",
		"The far ring reaches 54 studs", "They last 8.1 s", "Squadmates can use them too"})
	part("olastfeather", "Last Feather", "health", {
		"Always on (takes a slot): once per life a killing hit leaves you at 1 HP, untouchable for 0.7 s",
		"You also burst up into a glide (a free flap)", "Untouchable 1 s", "You drop a glow zone (40 studs) where you were"})
	part("oplume", "Overheal Plume", "health", {
		"Always on (takes a slot): healing above your max becomes a plume that soaks up to 10 damage; it fades after 5 s",
		"Soaks up to 14", "Fades after 7 s", "Squadmates you heal above their max get a plume too"})
	part("ofortify", "Fortify Field", "defense", {
		"Always on (takes a slot): squadmates inside your glow zones (40 studs) take 25% less damage",
		"It lingers 1 s after they leave", "Lingers 1.4 s", "You're fortified too inside your own zones"})
	part("oricochet", "Ricochet Pod", "attack", {
		"Always on (takes a slot): the pod bounces once and splats a second, half-size zone (20 studs) on the next enemy within 30 studs; it lasts 2.2 s",
		"Bounce reach 40 studs", "The second zone lasts the full 3 s", "The second zone is full size (40 studs)"})
	if SkillTree.TROO_PARTS_B2_SOON then
		for _, id in ipairs({"olastfeather", "oplume", "ofortify", "oricochet"}) do
			SkillTree.PATHS[id].soon = true
			SkillTree.LIVE_MECH[id] = nil
		end
	end
end
do
	local effectsPre172 = SkillTree.effects
	function SkillTree.effects(steps, dino)
		local e = effectsPre172(steps, dino)
		if type(e) ~= "table" then return e end
		if not SkillTree.TROO_PARTS or not SkillTree.PATHS.omender then return e end
		local on = dino == "Troodon"
		local s = on and SkillTree.sanitize(steps, dino) or {}
		local m, l, w, h, p = s.omender or 0, s.olantern or 0, s.osapwall or 0, s.oshed or 0, s.oportal or 0
		e.oMenderHeal = m >= 1 and 4 or 0
		e.oMenderTime = m >= 2 and 5.4 or (m >= 1 and 4 or 0)
		e.oMenderRange = m >= 1 and 40 or 0
		e.oMenderHop = m >= 4
		e.oMenderCooldown = m >= 3 and 14.8 or (m >= 1 and 20 or 0)
		e.oLanternRange = l >= 1 and 40 or 0
		e.oLanternChain = l >= 2 and 32.4 or (l >= 1 and 24 or 0)
		e.oLanternTargets = l >= 4 and 3 or (l >= 1 and 2 or 0)
		e.oLanternDamage = l >= 1 and 8 or 0
		e.oLanternCooldown = l >= 3 and 10.3 or (l >= 1 and 14 or 0)
		e.oSapRange = w >= 1 and 40 or 0
		e.oSapWidth = w >= 2 and 67.5 or (w >= 1 and 50 or 0)
		e.oSapTime = w >= 4 and 4 or (w >= 3 and 2.9 or (w >= 1 and 2.1 or 0))
		e.oSapCooldown = w >= 1 and 18 or 0
		e.oShedImmune = h >= 2 and 1.4 or (h >= 1 and 1 or 0)
		e.oShedCooldown = h >= 3 and 17.7 or (h >= 1 and 24 or 0)
		e.oShedKnockRadius = h >= 4 and 20 or 0
		e.oShedSlowMul = h >= 4 and 0.75 or 1
		e.oShedSlowTime = h >= 4 and 2 or 0
		e.oPortalRange = p >= 2 and 54 or (p >= 1 and 40 or 0)
		e.oPortalTime = p >= 3 and 8.1 or (p >= 1 and 6 or 0)
		e.oPortalSquad = p >= 4
		e.oPortalCooldown = p >= 1 and 20 or 0
		return e
	end
end

-- v1.73 (balance pass 1, plan docs/plans/BALANCE_PASS_v1.0.md, MDA-358 / MDA-360 / MDA-361 / MDA-362 / MDA-363; Kepu
-- 2026-11-09 10:48 "very strong for everything"; plan rule "Stat-tree rows and parts keep their current additions on top of
-- the new base numbers"). Switch SkillTree.BALANCE_PASS1 (default true; false = 1.72 texts and numbers). The new bases come
-- from HerreraModelData 1.5, DiloModelData 1.4, TenoModelData 1.5, TherizinoModelData 1.6, TRexModelData 2.1 (SkillTree.BAL1
-- holds old / new). Rows that ADD or MULTIPLY (Attack points, Razor Claws refill x0.65 / +1 charge, Front Claws / Heavy Tail
-- +3, Buck Off, Cold Blood, Long Spit, Overclock +1 jump charge) already work on the new base: only their texts change. Rows
-- that REPLACE a base number keep their old step over the old base:
--   * Herrera Razor Claws III slashBleedDps (an absolute 3 with HERRERA_TRIM, 5 without) + (4 - 2): 5 (7 without the trim).
--     Texts: I "slash 15 -> 18" (+3 points), II "(2.5 s -> 1.6 s)", III "5 per second (was 4)", star "A 4th slash charge".
--   * Therizino Building Fury furyHit2 12 + (11 - 9) = 14, furyFinisher 26 + (24 - 20) = 30; texts "(11 -> 14)", "(24 -> 30)".
--   * Dilo Quick Draw (absolute hold / recharge): the same ratio to the new base (hold x 0.25 / 0.4, recharge x 0.75 / 1.5),
--     rounded to 0.01: drawHold 0.35 / 0.3 / 0.3 / 0.25 -> 0.22 / 0.19 / 0.19 / 0.16, drawCooldown 1.25 / 1.0 -> 0.63 / 0.5
--     (the plan's "additions" read literally would give 0.2 / 0.15 / 0.15 / 0.1 s holds and a 0.25 s recharge; open question
--     in the build report). Texts follow.
--   * Teno texts: Front Claws I "(12 -> 15)", Heavy Tail I "(25 -> 28)". T-Rex Jaws I text "T-Rex bite 30 -> 40".
SkillTree.BALANCE_PASS1 = true
SkillTree.BAL1 = {herreraSlash = {7, 15}, herreraRefill = {4, 2.5}, herreraCharges = {2, 3}, herreraBleed = {2, 4},
	theriHit2 = {9, 11}, theriHit3 = {20, 24}, diloHold = {0.4, 0.25}, diloDartCd = {1.5, 0.75}, tenoScratch = {8, 12},
	tenoSlam = {15, 25}, trexBite = {25, 30}}
if SkillTree.BALANCE_PASS1 then
	local P, B = SkillTree.PATHS, SkillTree.BAL1
	local function r2(x) return math.floor(x * 100 + 0.5) / 100 end
	local function fmtS(x) return (("%.2f"):format(x):gsub("0+$", ""):gsub("%.$", "")) end
	SkillTree.BAL1_DRAW = function(v, isCd) -- Quick Draw: the same ratio to the new base
		if (tonumber(v) or 0) <= 0 then return v end
		local b = isCd and B.diloDartCd or B.diloHold
		return r2(v * b[2] / b[1])
	end
	-- Herrera Razor Claws (jaws stepsFor.Herrera)
	if P.jaws and P.jaws.stepsFor and P.jaws.stepsFor.Herrera then
		local pts =SkillTree.HERRERA_TRIM and SkillTree.HERRERA_TRIM_ATTACK or 5
		local bleed = (SkillTree.HERRERA_TRIM and SkillTree.HERRERA_TRIM_BLEED_DPS or 5) + B.herreraBleed[2] - B.herreraBleed[1]
		SkillTree.BAL1_HERRERA_BLEED = bleed
		P.jaws.stepsFor.Herrera = {
			("Slash hits harder (+%d Attack points: slash %d -> %d)"):format(pts, B.herreraSlash[2], B.herreraSlash[2] + pts),
			("Slash charges refill 35%% faster (%s s -> %s s)"):format(fmtS(B.herreraRefill[2]), fmtS(math.floor(B.herreraRefill[2] * 0.65 * 10 + 0.5) / 10)),
			("Bleed burns hotter: %d per second (was %d)"):format(bleed, B.herreraBleed[2]),
			("A %dth slash charge"):format(B.herreraCharges[2] + 1)}
	end
	-- Therizino Building Fury
	if P.fury then
		P.fury.steps[1] = ("Cut 2 hits harder (%d -> %d)"):format(B.theriHit2[2], 12 + B.theriHit2[2] - B.theriHit2[1])
		P.fury.steps[2] = ("The finisher hits harder (%d -> %d)"):format(B.theriHit3[2], 26 + B.theriHit3[2] - B.theriHit3[1])
	end
	-- Dilo Quick Draw
	if P.quickdraw then
		local d = SkillTree.BAL1_DRAW
		P.quickdraw.steps = {
			("Spit ready after a %s s hold (was %s)"):format(fmtS(d(0.35)), fmtS(B.diloHold[2])),
			("Spit ready after a %s s hold"):format(fmtS(d(0.3))),
			("Dart recharges in %s s (was %s)"):format(fmtS(d(1.25, true)), fmtS(B.diloDartCd[2])),
			("%s s hold, and the dart recharges in %s s"):format(fmtS(d(0.25)), fmtS(d(1.0, true)))}
	end
	-- Teno Front Claws / Heavy Tail (the +3 bonuses are unchanged)
	if P.frontclaws then P.frontclaws.steps[1] = ("Scratch hits harder (%d -> %d)"):format(B.tenoScratch[2], B.tenoScratch[2] + 3) end
	if P.heavytail then P.heavytail.steps[1] = ("Tail slam +3 damage (%d -> %d)"):format(B.tenoSlam[2], B.tenoSlam[2] + 3) end
	-- T-Rex Jaws I (+5 Attack points = bite +10)
	if P.jaws and P.jaws.steps[1] == "Main attack hits harder (+5 Attack points: T-Rex bite 25 -> 35)" then
		P.jaws.steps[1] = ("Main attack hits harder (+5 Attack points: T-Rex bite %d -> %d)"):format(B.trexBite[2], B.trexBite[2] + 10)
	end
end
do
	local effectsPre173 = SkillTree.effects
	function SkillTree.effects(steps, dino)
		local e = effectsPre173(steps, dino)
		if type(e) ~= "table" or not SkillTree.BALANCE_PASS1 then return e end
		local B = SkillTree.BAL1
		if dino == "Herrera" and (e.slashBleedDps or 0) > 0 then e.slashBleedDps = e.slashBleedDps + B.herreraBleed[2] - B.herreraBleed[1] end
		if dino == "Therizino" then
			if (e.furyHit2 or 0) > 0 then e.furyHit2 = e.furyHit2 + B.theriHit2[2] - B.theriHit2[1] end
			if (e.furyFinisher or 0) > 0 then e.furyFinisher = e.furyFinisher + B.theriHit3[2] - B.theriHit3[1] end
		end
		if dino == "Dilo" then
			e.drawHold = SkillTree.BAL1_DRAW(e.drawHold, false)
			e.drawCooldown = SkillTree.BAL1_DRAW(e.drawCooldown, true)
		end
		return e
	end
end

-- v1.74 shot pass (Kepu 2026-11-09 "all the projectile shots need to be faster and more auto aim assist on it and longer
--   range" -> "2x range", "Strong" assist; plan docs/plans/SHOT_PASS_v1.0.md). With SkillTree.SHOT_PASS (default true)
--   effects() doubles every projectile part's reach (SHOT_RANGE_KEYS x SHOT_RANGE_MUL 2: Ink Shooter, Tether Spike, Shock
--   Cannon, Grappling Hook / Reaper's Hook, Quill Launcher, Goo Blob toss + its assist reach, Boulder Mortar range + auto
--   distance, Feather Barrage fan, Snare Wires, Toxin Mortar, Spine Burst, Arc Lantern, Sap Wall throw) and raises the
--   lock-on cones to at least SHOT_ASSIST_DEG 45 (SHOT_CONE_KEYS: goo assist, Venom Gatling, Reaper's Hook, Boulder Mortar).
--   The step texts that name those reaches are rewritten (SHOT_TEXTS, exact old -> new; a text that no longer matches is
--   left as it was and counted in SkillTree.SHOT_TEXT_MISSES). Speeds and the snap code live in the servers (shot pass
--   versions); the Dilo dart and the Troodon pod come from DiloModelData 1.6 / TroodonModelData 1.7. SHOT_PASS = false
--   restores 1.73.
SkillTree.SHOT_PASS = true
SkillTree.SHOT_RANGE_MUL = 2
SkillTree.SHOT_ASSIST_DEG = 45
SkillTree.SHOT_RANGE_KEYS = {"inkRange", "tetherRange", "screechRange", "hookRange", "quillRange", "gooToss", "gooAssistMax",
	"mortarRange", "mortarMiss", "featherRange", "snareRange", "dMortarRange", "dSpineRange", "oLanternRange", "oSapRange"}
SkillTree.SHOT_CONE_KEYS = {"gooAssistAngle", "dGatlingCone", "hookCone", "mortarCone"}
SkillTree.SHOT_TEXTS = {
	{"ink", 1, "(60 studs)", "(120 studs)"}, {"ink", 2, "Reaches 80 studs", "Reaches 160 studs"},
	{"tether", 1, "(90 studs)", "(180 studs)"},
	{"screech", 1, "(100 studs)", "(200 studs)"}, {"screech", 2, "Reaches 135 studs", "Reaches 270 studs"},
	{"hookarm", 1, "(60 studs)", "(120 studs)"}, {"hookarm", 2, "Reaches 80 studs", "Reaches 160 studs"},
	{"quills", 1, "(40 studs)", "(80 studs)"},
	{"goo", 1, "30 studs ahead", "60 studs ahead"},
	{"tmortar", 1, "(15-90 studs)", "(15-180 studs)"},
	{"zfeather", 1, "35-stud fan", "70-stud fan"}, {"zfeather", 2, "fan reaches 40 studs", "fan reaches 80 studs"},
	{"zfeather", 4, "fan reaches 50 studs", "fan reaches 100 studs"},
	{"zhook", 1, "(50 studs)", "(100 studs)"}, {"zhook", 2, "reaches 65 studs", "reaches 130 studs"},
	{"zhook", 3, "reaches 80 studs", "reaches 160 studs"},
	{"zsnare", 1, "(60 studs)", "(120 studs)"}, {"zsnare", 3, "reaches 80 studs", "reaches 160 studs"},
	{"dmortar", 1, "up to 40 studs", "up to 80 studs"}, {"dmortar", 2, "Reaches 50 studs", "Reaches 100 studs"},
	{"dmortar", 4, "Reaches 60 studs", "Reaches 120 studs"},
	{"olantern", 1, "up to 40 studs", "up to 80 studs"},
	{"osapwall", 1, "up to 40 studs", "up to 80 studs"},
	{"traps", 1, "30 studs ahead", "60 studs ahead"},
}
SkillTree.SHOT_TEXT_MISSES = 0
if SkillTree.SHOT_PASS then
	for _, row in ipairs(SkillTree.SHOT_TEXTS) do
		local path = SkillTree.PATHS[row[1]]
		local text = path and path.steps and path.steps[row[2]]
		local a, b
		if type(text) == "string" then a, b = text:find(row[3], 1, true) end
		if a then
			path.steps[row[2]] = text:sub(1, a - 1) .. row[4] .. text:sub(b + 1)
		else
			SkillTree.SHOT_TEXT_MISSES += 1
		end
	end
end
do
	local effectsPre174 = SkillTree.effects
	function SkillTree.effects(steps, dino)
		local e = effectsPre174(steps, dino)
		if type(e) ~= "table" or not SkillTree.SHOT_PASS then return e end
		for _, k in ipairs(SkillTree.SHOT_RANGE_KEYS) do
			if type(e[k]) == "number" and e[k] > 0 then e[k] = e[k] * SkillTree.SHOT_RANGE_MUL end
		end
		for _, k in ipairs(SkillTree.SHOT_CONE_KEYS) do
			if type(e[k]) == "number" and e[k] > 0 then e[k] = math.max(e[k], SkillTree.SHOT_ASSIST_DEG) end
		end
		return e
	end
end


-- v1.75 (MDA-360, plan docs/plans/BALANCE_PASS_v1.0.md; Kepu 2026-11-09 "for dilo make the spit the only attack method. remove
-- the bite and make it extra fast", confirmed tap to spit, a spit every 0.35 s at base, Quick Draw "extra fast" each rank >= 35%
-- faster 0.26 / 0.19 / 0.14 / 0.14; Venom Bite "Becomes spit poison"). Switch SkillTree.DILO_SPIT_ONLY (default true; false =
-- 1.74). DiloModelData 1.7 carries DiloSpitOnly / DiloSpitGap 0.35 (SkillTree.SPIT holds the base numbers for the texts).
--   * Quick Draw: new effect field spitGap (s between spits; 0 = the model's DiloSpitGap): I 0.26, II 0.19, III 0.14, star 0.14
--     (Kepu's numbers; 0.35 / 0.26 = 1.35, 0.26 / 0.19 = 1.37, 0.19 / 0.14 = 1.36). drawHold / drawCooldown are kept (they only
--     act while the spit-only switches are off). Texts "Spit every 0.26 s (was 0.35)" ...
--   * Venom Bite (row id venombite kept, so spent points stay; shown as "Venom Spit"): new effect fields spitVenomAddDps /
--     spitVenomAddTime = extra poison on the spit dart's own venom (DiloVenomDps 4 for DiloVenomTime 3 s), the bite ladder's
--     shape kept (I dps, II longer, III stronger, star both) with every changed number >= 1.35x: +2 / +2 / +5 / +5 per s and
--     +0 / +1.5 / +0 / +1.5 s -> the dart poisons 6/s 3 s, 6/s 4.5 s, 9/s 3 s, 9/s 4.5 s (bite ladder before: its own bite
--     poison 1/s 2 s, 1/s 3 s, 2/s 2 s, 2/s 3 s). venomBiteDps / venomBiteTime stay (they act on the bite, only with the
--     spit-only switches off). The never-stack rule (stronger wins) is the server's and unchanged.
SkillTree.DILO_SPIT_ONLY = true
SkillTree.SPIT = {gap = 0.35, venomDps = 4, venomTime = 3, gaps = {0.26, 0.19, 0.14, 0.14}, addDps = {2, 2, 5, 5},
	addTime = {0, 1.5, 0, 1.5}}
if SkillTree.DILO_SPIT_ONLY then
	local P, S = SkillTree.PATHS, SkillTree.SPIT
	local function fmtS(x) return (("%.2f"):format(x):gsub("0+$", ""):gsub("%.$", "")) end
	if P.quickdraw then
		P.quickdraw.steps = {
			("Spit every %s s (was %s)"):format(fmtS(S.gaps[1]), fmtS(S.gap)),
			("Spit every %s s"):format(fmtS(S.gaps[2])),
			("Spit every %s s"):format(fmtS(S.gaps[3])),
			("Spit every %s s, the fastest spit"):format(fmtS(S.gaps[4]))}
	end
	if P.venombite then
		P.venombite.name = "Venom Spit"
		P.venombite.steps = {
			("Spit poison %s/s (was %s)"):format(fmtS(S.venomDps + S.addDps[1]), fmtS(S.venomDps)),
			("Spit poison lasts %s s (was %s)"):format(fmtS(S.venomTime + S.addTime[2]), fmtS(S.venomTime)),
			("Spit poison %s/s for %s s"):format(fmtS(S.venomDps + S.addDps[3]), fmtS(S.venomTime + S.addTime[3])),
			("Spit poison %s/s for %s s"):format(fmtS(S.venomDps + S.addDps[4]), fmtS(S.venomTime + S.addTime[4]))}
	end
end
do
	local effectsPre175 = SkillTree.effects
	function SkillTree.effects(steps, dino)
		local e = effectsPre175(steps, dino)
		if type(e) ~= "table" then return e end
		e.spitGap, e.spitVenomAddDps, e.spitVenomAddTime = 0, 0, 0
		if not SkillTree.DILO_SPIT_ONLY or dino ~= "Dilo" or not SkillTree.PATHS.venombite then return e end
		local s = SkillTree.sanitize(steps, dino)
		local S = SkillTree.SPIT
		local qd, vb = math.clamp(s.quickdraw or 0, 0, 4), math.clamp(s.venombite or 0, 0, 4)
		if qd >= 1 then e.spitGap = S.gaps[qd] end
		if vb >= 1 then e.spitVenomAddDps, e.spitVenomAddTime = S.addDps[vb], S.addTime[vb] end
		return e
	end
end
-- v1.76 (Kepu 2026-11-09 Spring Jets "a bit longer" -> "Longer + faster"; mortar "not big enough of a splatter" -> "1.5x cloud
--   + damage area"): with SkillTree.DILO_FX_PASS (default true) effects() sets dJetsDist 25 / 30 / 40 -> 40 / 50 / 65 studs
--   (DiloMovesServer 1.8 also flies the burst at 200 studs/s) and dMortarRadius x1.5 (8 / 10 / 12 -> 12 / 15 / 18: the cloud
--   and its damage area). The Lab texts that name them are rewritten (DILO_FX_TEXTS, exact old -> new; a miss counts in
--   SkillTree.DILO_FX_TEXT_MISSES). DILO_FX_PASS = false restores 1.75.
SkillTree.DILO_FX_PASS = true
SkillTree.DILO_JETS_DIST = {[25] = 40, [30] = 50, [40] = 65}
SkillTree.DILO_MORTAR_RADIUS_MUL = 1.5
SkillTree.DILO_FX_TEXTS = {
	{"dmortar", 1, "a 16-stud poison cloud", "a 24-stud poison cloud"}, {"dmortar", 2, "cloud 20 studs wide", "cloud 30 studs wide"},
	{"dmortar", 4, "cloud 24 studs wide", "cloud 36 studs wide"},
	{"djets", 1, "dashes you 25 studs", "dashes you 40 studs"}, {"djets", 2, "30 studs, 2 charges", "50 studs, 2 charges"},
	{"djets", 3, "40 studs; leaves", "65 studs; leaves"},
}
SkillTree.DILO_FX_TEXT_MISSES = 0
if SkillTree.DILO_FX_PASS then
	for _, row in ipairs(SkillTree.DILO_FX_TEXTS) do
		local path = SkillTree.PATHS[row[1]]
		local text = path and path.steps and path.steps[row[2]]
		local a, b
		if type(text) == "string" then a, b = text:find(row[3], 1, true) end
		if a then
			path.steps[row[2]] = text:sub(1, a - 1) .. row[4] .. text:sub(b + 1)
		else
			SkillTree.DILO_FX_TEXT_MISSES += 1
		end
	end
end
do
	local effectsPre176 = SkillTree.effects
	function SkillTree.effects(steps, dino)
		local e = effectsPre176(steps, dino)
		if type(e) ~= "table" or not SkillTree.DILO_FX_PASS then return e end
		if type(e.dJetsDist) == "number" and SkillTree.DILO_JETS_DIST[e.dJetsDist] then e.dJetsDist = SkillTree.DILO_JETS_DIST[e.dJetsDist] end
		if type(e.dMortarRadius) == "number" and e.dMortarRadius > 0 then e.dMortarRadius = e.dMortarRadius * SkillTree.DILO_MORTAR_RADIUS_MUL end
		return e
	end
end

-- v1.77 (Kepu 2026-11-09 after v588 "lower the poison time" -> base "1.5 s", Venom Spit's extra time "Shrink it the same"):
--   DiloModelData 1.12 sets DiloVenomTime 1.5 (was 3). With SkillTree.DILO_VENOM_TIME_PASS (default true) effects() gives
--   spitVenomAddTime from SkillTree.DILO_SPIT_ADD_TIME (0 / 0.75 / 0 / 0.75, was 0 / 1.5 / 0 / 1.5: the same half), so the
--   spit poison lasts 1.5 / 1.5 / 2.25 / 1.5 / 2.25 s (base, I, II, III, star; were 3 / 3 / 4.5 / 3 / 4.5). The Venom Spit
--   texts that name a time are rewritten (DILO_VENOM_TIME_TEXTS, exact old -> new; a miss counts in
--   SkillTree.DILO_VENOM_TIME_TEXT_MISSES, expected 0). SkillTree.SPIT is not changed. DILO_VENOM_TIME_PASS = false restores
--   1.76 (with DiloModelData 1.11's 3 s base).
SkillTree.DILO_VENOM_TIME_PASS = true
SkillTree.DILO_SPIT_ADD_TIME = {0, 0.75, 0, 0.75}
SkillTree.DILO_VENOM_TIME_TEXTS = {
	{"venombite", 2, "Spit poison lasts 4.5 s (was 3)", "Spit poison lasts 2.25 s (was 1.5)"},
	{"venombite", 3, "Spit poison 9/s for 3 s", "Spit poison 9/s for 1.5 s"},
	{"venombite", 4, "Spit poison 9/s for 4.5 s", "Spit poison 9/s for 2.25 s"},
}
SkillTree.DILO_VENOM_TIME_TEXT_MISSES = 0
if SkillTree.DILO_VENOM_TIME_PASS and SkillTree.DILO_SPIT_ONLY then
	for _, row in ipairs(SkillTree.DILO_VENOM_TIME_TEXTS) do
		local path = SkillTree.PATHS[row[1]]
		local text = path and path.steps and path.steps[row[2]]
		if text == row[3] then
			path.steps[row[2]] = row[4]
		else
			SkillTree.DILO_VENOM_TIME_TEXT_MISSES += 1
		end
	end
end
do
	local effectsPre177 = SkillTree.effects
	function SkillTree.effects(steps, dino)
		local e = effectsPre177(steps, dino)
		if type(e) ~= "table" or not SkillTree.DILO_VENOM_TIME_PASS then return e end
		if not SkillTree.DILO_SPIT_ONLY or dino ~= "Dilo" or not SkillTree.PATHS.venombite then return e end
		local s = SkillTree.sanitize(steps, dino)
		local vb = math.clamp(s.venombite or 0, 0, 4)
		if vb >= 1 then e.spitVenomAddTime = SkillTree.DILO_SPIT_ADD_TIME[vb] end
		return e
	end
end

-- v1.78 (troodon parts build 2, MDA-349, plan docs/plans/TROODON_PARTS_v1.0.md ticket 5; Kepu 2026-11-09 17:17 "Build all of them" (the 4 always-on troodon parts) + "Use the references we chose from the previous mockups"):
--   SkillTree.TROO_PARTS_B2_LIVE (default true; false = 1.77): olastfeather / oplume / ofortify / oricochet lose `soon` and become
--   LIVE_MECH (buyable, slottable; they stay in BUTTONS, so each takes a slot). Texts unchanged (the plan's table). effects()
--   writes ONLY new o* fields (troodon only; off values elsewhere / unbought):
--   oLastUntouch 0.7 / 1 (III), oLastGlide (II+), oLastZone (star); oPlumeMax 10 / 14 (II), oPlumeFade 5 / 7 (III), oPlumeSquad
--   (star); oFortifyMul 0.75 (I+; 1 = off), oFortifyLinger 0 / 1 (II) / 1.4 (III), oFortifySelf (star); oRicochetReach 30 / 40
--   (II), oRicochetTime 2.2 / 3 (III), oRicochetSize 0.5 / 1 (star: x the main zone radius).
SkillTree.TROO_PARTS_B2_LIVE = false -- parked 2026-11-09 (Kepu: not with the troodon for now); true = the 4 parts live
if SkillTree.TROO_PARTS and SkillTree.TROO_PARTS_B2_LIVE and SkillTree.PATHS.omender then
	for _, id in ipairs({"olastfeather", "oplume", "ofortify", "oricochet"}) do
		if SkillTree.PATHS[id] then
			SkillTree.PATHS[id].soon = nil
			SkillTree.LIVE_MECH[id] = true
		end
	end
end
do
	local effectsPre178 = SkillTree.effects
	function SkillTree.effects(steps, dino)
		local e = effectsPre178(steps, dino)
		if type(e) ~= "table" then return e end
		if not SkillTree.TROO_PARTS or not SkillTree.PATHS.olastfeather then return e end
		local live = SkillTree.TROO_PARTS_B2_LIVE and dino == "Troodon"
		local s = live and SkillTree.sanitize(steps, dino) or {}
		local lf, pl, fo, ri = s.olastfeather or 0, s.oplume or 0, s.ofortify or 0, s.oricochet or 0
		e.oLastUntouch = lf >= 3 and 1 or (lf >= 1 and 0.7 or 0)
		e.oLastGlide = lf >= 2
		e.oLastZone = lf >= 4
		e.oPlumeMax = pl >= 2 and 14 or (pl >= 1 and 10 or 0)
		e.oPlumeFade = pl >= 3 and 7 or (pl >= 1 and 5 or 0)
		e.oPlumeSquad = pl >= 4
		e.oFortifyMul = fo >= 1 and 0.75 or 1
		e.oFortifyLinger = fo >= 3 and 1.4 or (fo >= 2 and 1 or 0)
		e.oFortifySelf = fo >= 4
		e.oRicochetReach = ri >= 2 and 40 or (ri >= 1 and 30 or 0)
		e.oRicochetTime = ri >= 3 and 3 or (ri >= 1 and 2.2 or 0)
		e.oRicochetSize = ri >= 4 and 1 or (ri >= 1 and 0.5 or 0)
		return e
	end
end

return SkillTree
