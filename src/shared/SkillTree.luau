-- SkillTree v1.53 (1.49 teno abilities; 1.50 teno stats part 2) (Mecha Dino Arena) — skill tree data and maths: areas, paths, step costs, the level curve, buy / respec
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

return SkillTree
