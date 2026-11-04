-- SkillEffects v1.41 (Mecha Dino Arena) — turns the bought skill-tree steps into game effects. MDA-13, plan
-- docs/plans/SKILLTREES_v1.0.md Task 3, ADR "Skill trees own XP and replace class stat points".
-- Reads each player's SkillPath_<pathId> attributes (SkillServer 1.0) through ServerStorage.DinoArcade.SkillTree
-- .effects and writes only attributes existing scripts already read, plus its own shield / bleed bookkeeping:
--   * Stat points (Kepu: the paths replace the class stat points): player StatAdded_Attack / StatAdded_Defense /
--     StatAdded_Speed = attackPts / defensePts / speedPts (StatServer 1.0 re-applies on change; Jaws I +1 Attack,
--     Thick Hide I +1 Defense, Sprint Legs I / II / star +1 / +5 / +1 Speed: II = run speed x1.5).
--   * Cooldowns: at spawn the character's own BiteCooldown / PounceCooldown / RamCooldown / JumpCooldown (else the move
--     scripts' defaults 0.8 / 3 / 6 / 0.5) are kept as SkillBase_<name>; written = base x multiplier. The main attack is
--     the bite while BiteEnabled ~= false, else the pounce (Kepu: Jaws upgrades the main attack): it gets mainCdMul.
--     PounceCooldown / RamCooldown / JumpCooldown get moveCdMul (Sprint Legs III).
--   * Kill heal: KillRegenFraction = SkillBase_KillRegenFraction (the character's own, else 0.25) + killRegenAdd.
--   * Regeneration: every TICK s, while health is below max and at least regenDelay s passed since the last health
--     drop, heal regenRate x MaxHealth per second.
--   * Lifesteal: a new BiteHitAt heals lifesteal x BiteHitDamage; a new PounceBiteAt heals lifesteal x PounceHitDamage.
--   * Overheal shield (Lifesteal star): healing from this script past full health goes into SkillShield (at most
--     shieldMax x MaxHealth), SkillShieldUntil = now + shieldTime (refreshed by each add); at that time it is 0. A
--     health drop while SkillShield > 0 is given back from the shield (a killing blow is not: the dino is already dead).
--   * Stuns (Thick Hide III / star): when StunnedUntil (ShakeOffServer) is set into the future: health above
--     stunImmuneAbove x MaxHealth -> StunnedUntil = now (no stun, SkillStunTrimmed "immune"); else stunMul < 1 -> what
--     is left is scaled by stunMul ("trimmed").
--   * Less knockback (Thick Hide II): when StunTossDistance is set, it is multiplied by tossMul ("tossTrimmed").
--   * Bleed (Jaws III) and crushing hit (Jaws star), on a bite or pounce hit on a bot (IsBot; found by the hit's
--     BiteHitTarget / PounceLatchTarget model name, first in DinoIsland.Bots): bleed = bleedDps per second off the bot's
--     DummyHealth for bleedTime s (a new hit restarts it); if bleed takes DummyHealth from above 0 to 0 it stamps
--     KilledBy, KilledByUserId, KilledWith = "bleed" and, last, KilledAt, exactly like BiteServer 1.6 (so SkillServer XP
--     and KillRegenServer count it). Crushing hit = the bot's StunnedUntil = now + crushStun (BotServer 1.2+ makes a
--     stunned bot lie down), at most once per crushCooldown s per bot.
-- Off: script attribute SkillEffectsEnabled = false -> StatAdded_* 0, every SkillBase_* value written back, shield 0,
--   no regen / lifesteal / stun or toss changes / bleed / crush (SkillEffectsState "off").
-- Diagnostics: script SkillEffectsVersion; character SkillEffectsState ("ready" / "off"), SkillRegenActive,
--   SkillLastHeal ("regen +3" / "lifesteal +2"), SkillShield, SkillShieldUntil, SkillStunTrimmed ("immune" / "trimmed" /
--   "tossTrimmed"), SkillBase_<name>; bot SkillBleedUntil, SkillBleedBy, SkillCrushedAt.
-- v1.1 (mecha Thrusters, MDA-26, plan docs/plans/MECHA_THRUSTERS_v1.0.md Task 3; Kepu: dash free, part only while
--   slotted): character DashEnabled = effects on AND dashCharges > 0 AND "thrusters" in SkillSlot1 / SkillSlot2
--   (SkillServer 1.1); DashCharges (0 while off), DashDistance (dashDist), DashHop (0 while off), DashTime and
--   DashRecharge (script attributes SkillDashTime 0.35 / SkillDashRecharge 8). Re-applied when a SkillPath_ or a
--   SkillSlot attribute changes. MechaServer 1.0 / MechaButtons 1.0 read them.
-- v1.2 (Thrusters boost, MDA-31; Kepu: "1.5 s boost, steerable"): DashTime = SkillTree 1.2 dashTime (1.5 s; 2 s from III)
--   while the dash is on (SkillDashTime is the fallback while off); new DashSpeedMul = script attribute SkillDashSpeedMul
--   (default 2: the boost runs at 2x the dino's run speed, MechaButtons 1.1).
-- v1.3 (MDA-35; Kepu: "its an arcade game. i want these boosts to feel significant" -> "Faster: 3x run speed"):
--   SkillDashSpeedMul default 3 (was 2).
-- v1.4 (MDA-36; Kepu: "a little too fast. maybe just make it 1.75 my run speed and 1 second long"): SkillDashSpeedMul
--   default 1.75 (boost length: SkillTree 1.4).
-- v1.5 (Cloak release, MDA-50, plan docs/plans/CLOAK_v1.0.md Task 2; SkillTree 1.5): Cloak Field. Character
--   CloakEnabled = effects on AND cloakTime > 0 AND "cloak" in any SkillSlot1..SLOTS (4); CloakTime, CloakCooldown,
--   CloakPounceMul (1 while off), CloakStill (false while off). Written with the dash attributes (same re-apply
--   triggers). CloakServer 1.0 / MechaButtons 1.4 / AbilityBar 1.2 read them.
-- v1.8 (raptor parts batch 2, MDA-71, plan docs/plans/RAPTOR_PARTS_B2_v1.0.md Task 2; SkillTree 1.9), written with the
--   other part attributes, only while the part is bought AND in a slot (0 / false otherwise):
--   * Scent Sense: ScentEnabled, ScentRadius, ScentMemory, ScentTime, ScentCooldown, ScentFresh, ScentBlood
--     (ScentServer 1.0 / ScentFX 1.0 read them).
--   * Raptor Screech: ScreechEnabled, ScreechRange, ScreechFlinch, ScreechCooldown, ScreechJam (ScreechServer 1.0 /
--     MechaButtons 1.8 read them).
-- v1.9 (raptor traps, MDA-80, plan docs/plans/RAPTOR_TRAPS_v1.0.md Task 2; SkillTree 1.12): Shock Mine (path "traps"),
--   only while bought AND slotted: MineEnabled, MineDamage, MineSlow (speed multiplier, 1 when off), MineSlowTime,
--   MineCooldown, MineMax, MineJam (MineServer 1.0 / MechaButtons 1.11 / AbilityBar 1.5 read them).
-- v1.10 (MDA-81; SkillTree 1.13): + MineLaunch (studs) and MineDaze (s), 0 when off (MineServer 1.1).
-- v1.15 (pachy Mecha Legs, MDA-123; SkillTree 1.22): on a pachy with the line bought: JumpBoost = SkillBase_JumpBoost x
--   legsBoostMul, JumpLaunchPower = SkillBase_JumpLaunchPower x legsPowerMul (bases kept at the first write), JumpCooldown =
--   legsCooldown x legsCdMul x moveCdMul (one cooldown for the leap and its double jump), JumpDoubleEnabled (star),
--   JumpDoubleMul 0.894 (80% of a leap's height), MechaLegsLook (star). Not bought / not a pachy / effects off -> the
--   bases back, JumpDoubleEnabled / MechaLegsLook false (JumpCooldown stays the 1.14 value). Switch: script attribute
--   SkillEffectsLegsEnabled (default true, read at start; false = 1.14).
-- v1.16 (Kepu 2026-10-30: "mecha legs should take up an ability slot"; SkillTree 1.23): Mecha Legs is on only while
--   "mechalegs" is in a slot (SkillSlot1-4), like the other parts. Character MechaLegsEnabled (true while on; the slot
--   tiles read it). Switch: script attribute SkillEffectsLegsSlotEnabled (default true, read at start; false = 1.15).
--   Also: JumpDoubleMul = e.legsDoubleMul (SkillTree 1.23: 1 = a full leap; 0.894 before) and JumpDoubleForward =
--   e.legsDoubleForward (studs/s, JumpTest 1.2; 0 when off).
-- v1.17 (pachy Blood Rush, MDA-124; SkillTree 1.24): on a pachy with "bloodrush" bought AND slotted: BloodRushEnabled
--   true, BloodRushCost (0.25), BloodRushMax (2), BloodRushDamageMul (II 1.25), BloodRushNoSelfSlow (III), BloodRushSlowMul /
--   BloodRushSlowTime (star 0.45 / 4); otherwise false / 0 / 0 / 1 / false / 1 / 0. HeadbuttServer 1.5, HeadbuttTest 1.1
--   and the HUD read them. Switch: script attribute SkillEffectsBloodEnabled (default true, read at start; false = 1.16).
-- v1.18 (Kepu 2026-10-30: "yes lets apply the bleeding to other players then. but shorten the time for bleeding so not
--   every pounce on another raptor is one shot"; earlier: "whatever works against bots works against players same
--   mechanic"): the Jaws III / Blade Claws III bleed also hits a player's dino. When the hit's target name is not a bot,
--   a Workspace player character with that name that ArenaPvP bridges (ArenaPvPBridged and Bitable true: the Arena only,
--   never in the menu) bleeds the same dps off its DummyHealth (ArenaPvP turns each drop into damage; an Energy Shield
--   blocks it there) for script attribute SkillBleedPlayerTime s (default 2; bots keep their 4 s), a new hit restarts
--   it, a killing tick stamps KilledBy / KilledByUserId / KilledWith "bleed" / KilledAt (last) and, for ArenaPvP's
--   credit, LastHitBy / LastHitAt. Target attributes SkillBleedUntil / SkillBleedBy as on bots. Switch: script
--   attribute SkillBleedPlayersEnabled (default true, read at start; false = 1.17, bots only). ArenaPvP's test target
--   (ArenaPvPTestTarget, bridged like a player) counts as a player's dino, for Studio checks.
-- v1.14 (pachy Grappling Hook, MDA-121; SkillTree 1.21): HookEnabled (bought, in a slot, Species "Pachy", effects on),
--   HookRange, HookCooldown, HookDamage (0 when off) and HookLook (= HookEnabled; the wrist claw is shown). HookServer 1.0
--   reads them. A new HookHitAt runs onHit like a bite (lifesteal). Switch: script attribute SkillEffectsHookEnabled
--   (default true, read at start; false = 1.13).
-- v1.13 (pachy Drop 2, Battering Dome; SkillTree 1.20): on a pachy character (Species "Pachy") the line is written as
--   HeadbuttDamageMul (1 / 1.25), HeadbuttShoveMul (1 / 1.3), HeadbuttRefillMul (1 / 0.7), HeadbuttExtraCharges (0 / 1)
--   and PachySpikes (false / true at the star); HeadbuttServer 1.1 / PachyLook 1.0 read them. Other species and effects
--   off -> 1 / 1 / 1 / 0 / false. Switch: script attribute SkillEffectsDomeEnabled (default true, read at start; false =
--   1.12, nothing written).
-- v1.12 (pachy headbutt, MDA-120, plan docs/plans/PACHY_PLAYABLE_v1.0.md Task 10): a new HeadbuttHitAt (HeadbuttServer
--   1.0, set last) counts as a hit like a bite: onHit with HeadbuttHitDamage / HeadbuttHitTarget (lifesteal heals
--   lifesteal x damage; Jaws' bleed / crush only if bought, and SkillTree 1.19 keeps Jaws off the pachy). Switch: script
--   attribute SkillEffectsHeadbuttEnabled (default true, read at start; false = 1.11).
-- v1.11 (MDA-83; SkillTree 1.14): + ScreechDamage (Shock Cannon star heavy shot, 30; 0 otherwise or when off).
-- v1.7 (Kepu 2026-10-29: thrusters "a little more of a speed boost" -> "2x run speed"): SkillDashSpeedMul default 2
--   (was 1.75).
-- v1.6 (raptor parts batch 1, MDA-59, plan docs/plans/RAPTOR_PARTS_B1_v1.0.md Task 2; SkillTree 1.6). Written with the
--   dash / cloak attributes (same re-apply triggers); everything is 0 / 1 / false while effects are off:
--   * Blade Claws (passive, bought is enough): BladeLook (steps >= 1), BladeLandBonus (0 / 0.35), BladeTickMul
--     (1 / 0.74), BladeBleedDps / BladeBleedTime (0 / 3 / 4), BladePinRefund (0 / 0.5). PounceServer 1.6 / BladeServer 1.0
--     read them. Pounce hits (PounceBiteAt) bleed with the stronger of Jaws' bleed and BladeBleedDps (time from the
--     same source); bites keep Jaws' bleed only.
--   * Adrenaline Injector (bought AND in any slot): AdrenalineEnabled, AdrenalineHeal, AdrenalineTime,
--     AdrenalineSpeedMul (1 while off), AdrenalineCooldown, AdrenalineStunClear. AdrenalineServer 1.0 reads them.
--   * Energy Shield (bought AND in any slot): EnergyShieldEnabled, EnergyShieldTime, EnergyShieldCooldown,
--     EnergyShieldSpeedMul (1 while off). EnergyShieldServer 1.0 / SprintTest 1.6 read them.
-- v1.19 (Kepu 2026-10-30: "It should be if there's been zero damage for 8 seconds slowly heal back health"; answers:
--   20% per second, every dino, a Blood Rush payment restarts the wait): every player dino whose health has not dropped
--   for SkillIdleRegenDelay (8) s heals SkillIdleRegenRate (0.20) x MaxHealth per second, every TICK (0.25 s), never
--   past MaxHealth (no shield from it). "Dropped" = the same health-drop clock the Regeneration skill uses (st.lastDrop:
--   any Humanoid.Health decrease, so a hit, a bleed tick and the Blood Rush payment all restart it). Where the
--   Regeneration skill is also ready (on and past its own delay) only the bigger of the two heals is given that tick.
--   Runs even when SkillEffectsEnabled is false. Switch: script attribute SkillEffectsIdleRegenEnabled (default true,
--   read each tick; false = 1.18). Diagnostics: character SkillIdleRegenActive (true while healing this way),
--   SkillLastHeal "idle +N". Kill heal is off in KillRegenServer 1.1.
-- v1.20 (Kepu 2026-10-30: "Health steal for raptor should be stronger then"; SkillTree 1.28): on a raptor (character
--   Species "Raptor") a hit heals e.lifestealRaptor (0.20 / 0.35 / 0.50) x damage instead of e.lifesteal; other dinos
--   unchanged. Switch: script attribute SkillEffectsRaptorLifestealEnabled (default true, read each hit; false = 1.19).
--   Diagnostic: character SkillLifestealRate (the share used on the last hit).
-- v1.21 (Kepu 2026-10-30, pachy: "I kept seeing my health regen quickly even while blood rushing"; Studio repro: 8 s
--   after the last Blood Rush payment the 1.19 heal (20%/s) filled 45 -> 90 in 2.5 s, which unlocked Blood Rush again,
--   a 45 HP payment about every 11 s; answer "Slow the heal to 5%/s"): SkillIdleRegenRate default 0.20 -> 0.05 (every
--   dino; the 8 s wait is unchanged). Pachy 45 -> 90 now takes 10 s after the wait. 0.20 = 1.20.
-- v1.22 (pachy Med-Station, MDA-125, plan docs/plans/PACHY_MEDSTATION_v1.0.md; SkillTree 1.29): on a pachy (Species
--   "Pachy") with "medstation" bought AND slotted: MedEnabled true, MedRadius / MedTime / MedRate / MedCooldown from the
--   steps (off: false / 0 / 0 / 0 / 0). MedStationServer 1.0 reads them. Red-team answer "Bigger one only": the 8 s heal
--   is skipped while the owner is healing on a running pad (character MedInside == true and MedActiveUntil > now).
--   Switch: script attribute SkillEffectsMedEnabled (default true, read at start; false = 1.21, Med* never written).
-- v1.23 (pachy Bone Crest; SkillTree 1.30): on a pachy (Species "Pachy") with "crest" bought (a passive line, no slot):
--   BoneCrestMul = crestMul (0.80 / 0.70 / 0.60; 1 off) and BoneCrestReflect = crestReflect (5 at star; 0 off). BoneCrest
--   1.0 (module) reads them. Switch: script attribute SkillEffectsCrestEnabled (default true, read at start; false = 1.22).
-- v1.24 (pachy parts batch 3, MDA-126..128; SkillTree 1.32): on a pachy with the part bought AND slotted (off values
--   otherwise): Servo Dash: ServoDashEnabled, ServoDashTime, ServoDashCooldown, ServoDashSpeedMul (1 off), ServoDashRefill,
--   ServoDashLook; Dome Visor: VisorEnabled, VisorTime, VisorCooldown, VisorKnock, VisorLook; Ink Shooter: InkEnabled,
--   InkRange, InkCooldown, InkBlindTime, InkSplash, InkLook. ServoDashServer / VisorServer / InkServer 1.0 read them.
--   Switch: script attribute SkillEffectsBatch3Enabled (default true, read at start; false = 1.23, none written).
-- v1.25 (pachy Tether Spike, MDA-129; SkillTree 1.34): on a pachy with "tether" bought AND slotted (off values otherwise):
--   TetherEnabled, TetherRange, TetherSplash, TetherReach, TetherTime, TetherCooldown, TetherYank, TetherYankReach,
--   TetherLook. TetherServer 1.0 reads them. Switch: script attribute SkillEffectsTetherEnabled (default true, read at
--   start; false = 1.24, none written).
-- v1.26 (Kepu 2026-10-31: "I need you to just have a generalized stat line that can be customized to the Dino";
--   SkillTree 1.37 option A + Tree Stalker + Blood Frenzy, plan docs/plans/STAT_LINES_v1.0.md). Switch: script attribute
--   SkillEffectsHerreraEnabled (default true, read at start; false = 1.25: no dino passed, nothing below written).
--   * Effects for a Herrera (character Species, else player DinoSpecies, = "Herrera") are ST.effects(steps, "Herrera");
--     every other dino keeps ST.effects(steps) as before. A Species change on the character refreshes.
--   * On a Herrera, from bases kept as SkillBase_<name> at the first write (the character's own value, else SlashServer /
--     ClimbTest defaults SlashRefill 4, SlashCharges 2, SlashBleedDps 3, SlashBleedTime 4, SlashDiveRange 20, ClimbSpeed 10):
--       SlashRefill = base x slashRefillMul (Razor Claws II 0.65), SlashBleedDps = slashBleedDps when > 0 (III 5) else base,
--       SlashCharges = base + slashExtraCharges (star +1), ClimbSpeed = base x climbSpeedMul (Scurry Legs III 1.35),
--       SlashDiveRange = base x diveRangeMul (Tree Stalker I 55/40), SlashBleedTime = slashBleedTime when > 0 (Blood
--       Frenzy II 6) else base; flags SlashDiveRefill (Tree Stalker II), TreeTopHidden (III), SlashDiveStun (star 0.5),
--       SlashFrenzyMul (Blood Frenzy I 1.1), SlashBleedBonus (III 3), SlashKillRefill (star). SlashServer 1.3, SprintTest
--       1.13 and TreeTopHide 1.0 read them. Off (SkillEffectsEnabled false): the bases written back, flags off.
--   * Blood Drinker (Lifesteal on the Herrera): SlashHitAt heals lifesteal x SlashHitDamage (same heal / shield as a
--     bite), SlashBleedDealtAt (SlashServer 1.3, the attacker's bleed ticks) heals lifesteal x SlashBleedDealt.
--   Diagnostic: character SkillEffectsDino ("Herrera" / "").
-- v1.27 (the Herrera's mecha parts, SkillTree 1.38, plan docs/plans/HERRERA_PARTS_v1.0.md, MDA-149..156). Switch: script
--   attribute SkillEffectsHerreraPartsEnabled (default true, read at start; false = 1.26, none written). On a Herrera
--   (character Species "Herrera") with a part bought AND in a loadout slot, its character attributes are written from the
--   effects (off values otherwise: Enabled false, multipliers 1, numbers 0). <Prefix>Enabled also tells HerreraPartsServer
--   to show the part's look.
--     Iron Claw:      IronClawEnabled, IronClawDamageMul, IronClawSpeedMul, IronClawDust
--     Back Plating:   PlatingEnabled, PlatingRearMul (BoneCrest 1.3 cuts hits from behind)
--     Blood Siphon:   SiphonEnabled, SiphonRate, SiphonRange, SiphonKillHeal
--     Glider Wings:   GliderEnabled, GliderFall, GliderDrop, GliderDropMul, GliderBurst
--     Quill Launcher: QuillEnabled, QuillCount, QuillDamage, QuillRange, QuillCooldown
--     Smoke Pods:     SmokeEnabled, SmokeRadius, SmokeTime, SmokeRunMul, SmokeSlowMul, SmokeCooldown
--     Strobe Frill:   StrobeEnabled, StrobeAngle, StrobeRange, StrobeDaze, StrobeDazedMul, StrobeCooldown
--     Stun Breaker:   BreakerEnabled, BreakerPush, BreakerCooldown, BreakerImmune
--   Blood Siphon tick (every 0.5 s): every other character or bot (workspace.DinoIsland.Bots, player characters) that is
--   bleeding (SlashBleedUntil or SkillBleedUntil in the future) with its root within SiphonRange x your scale heals you
--   SiphonRate x 0.5 each, through the same heal() as Lifesteal (overheal -> the Blood Drinker shield when bought);
--   star (SiphonKillHeal): a model in range whose KilledWith is "bleed" and KilledAt is in the last 1.5 s heals
--   SiphonKillHeal x MaxHealth once per kill. Diagnostics: character SiphonBleeding (count in range), SiphonHealAt (last).
-- v1.28 (Kepu 2026-10-31: "Blood siphon should be passive actually"; SkillTree 1.42 takes "siphon" out of BUTTONS): a
--   Herrera part that is not a button part (ST.BUTTONS[id] ~= true) is on whenever it is bought, slotted or not; button
--   parts still need a slot. Today: Blood Siphon, Iron Claw and Back Plating. Switch: script attribute SkillEffectsHerreraPassiveEnabled
--   (default true, read at each apply; false = 1.27, every Herrera part needs a slot).
-- v1.29 (Arena squads, MDA-159, plan docs/plans/SQUADS_v1.0.md Task S2, ADR-006; Kepu 2026-10-31 "turning friendly fire off",
--   picked "Everything harmful"): findBridgedPlayer never returns the attacker's squadmate, so skill bleeds / lifesteal
--   follow-ups never land on one (backstop; the hit servers already refuse squadmates). Squadmates = SquadRules 1.0 sameChar (same Arena squad; a test target's
--   SquadTestId counts). Switch: script attribute SkillEffectsSquadEnabled (default true, read at each check; false = 1.28).
--   Diagnostic: script SkillEffectsSquadSkips (count of squadmate skips / refusals).
-- v1.30 (Herrera parts pass 3, MDA-164, SkillTree 1.43; switch script attribute SkillEffectsHerreraPass3Enabled, default
--   true, read at start; false = 1.29): on a Herrera with the part bought AND slotted (off values otherwise) -
--     Razor Caltrops: CaltropEnabled, CaltropCount, CaltropRadius, CaltropTime, CaltropHidden, CaltropBleedDps,
--       CaltropBleedTime, CaltropSlowMul, CaltropSlowTime, CaltropCooldown (HerreraMovesServer 1.2);
--     Goo Blob Shooter: GooEnabled, GooToss, GooRadius, GooTime, GooCount, GooSlowMul, GooCooldown, GooAssistAngle,
--       GooAssistMin, GooAssistMax (HerreraMovesServer 1.2);
--     Adrenaline Injector ("hadren"): HerreraAdrenEnabled + HerreraAdrenSlashRefill (HerreraPartsServer 1.3's Back Tanks),
--       and the raptor's Adrenaline* attributes (AdrenalineServer, unchanged maths) are written when "hadren" is in a slot on
--       a Herrera, plus AdrenalineSlashRefill (star; AdrenalineServer 1.5 refills the slash charges).
--   Blood Siphon also counts a dino whose CaltropBleedUntil is in the future as bleeding.
--   Iron Claw / Blood Siphon / Back Plating are stat rows from SkillTree 1.43 (mech = false); they were already "on when
--   bought" (not in BUTTONS), so their writes are unchanged.
-- v1.31 (Tenontosaurus stat rows, SkillTree 1.45, plan docs/plans/TENO_STATS_v1.0.md; switch script attribute
--   SkillEffectsTenoEnabled, default true, read at start; false = 1.30): on a character with Species "Teno" (and on any
--   character that already has them, so a switch away writes the off values) the effects are written as TenoChargeMul1,
--   TenoChargeMul2, TenoChargeNoShove, TenoChargeBump, TenoChargeBumpStun, TenoBraceMul, TenoBraceNoStun, TenoBraceStack,
--   TenoBraceHeal, TenoBuckBonus, TenoBuckFree, TenoBuckImmune, TenoBuckDps (off values 1 / false / 0 when not bought, not a
--   teno or SkillEffectsEnabled false). TenoStatsServer 1.0 and TenoAttackServer 1.1 read them. Brace II: when StunnedUntil
--   is set into the future while TenoBraceNoStun is true and TenoHoldSince > 0 (holding a slam), StunnedUntil = now
--   (SkillStunTrimmed "braced"), before the Thick Hide rules.
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

-- v1.33 (teno mecha abilities, plan docs/plans/TENO_ABILITIES_v1.0.md Task 3, MDA-175; SkillTree 1.49): a TPARTS list like
--   HPARTS: on a character with Species "Teno" (or one that already has TenoGrabEnabled, so a switch away writes the off
--   values), each teno part bought (SkillPath_<id> >= 1) AND slotted writes <Prefix><Field> from effects() and
--   <Prefix>Enabled true; otherwise the off values and false. Prefixes: TenoGrab (Range, Fling, Damage, Stun, Big, Crash,
--   CrashRadius, Cooldown), TenoMortar (Range, Miss, Cone, Damage, Splash, Count, SlowMul, SlowTime, Rubble, Cooldown),
--   TenoStomp (Range, Damage, Stun, NoJump, Cooldown), TenoBellow (Range, Time, DamageMul, RunMul, ClearStun, Cooldown),
--   TenoChallenge (Range, Time, WeakMul, SlowMul, Cooldown), TenoLeap (Dist, Damage, Radius, Stun, Charges, Cooldown),
--   TenoMud (Time, Hits, SlowRadius, SlowMul, SlowTime, Splash, Cooldown). Read by TenoPartsServer 1.0 (looks),
--   TenoMovesServer 1.0, MechaButtons 1.26. Switch: script attribute SkillEffectsTenoPartsEnabled (default true, read at
--   start).
-- v1.35 (SkillTree 1.52, Kepu 2026-11-02 Stomp star = latch drain): TenoStomp gains LatchDrain (effects stompLatchDrain: 50
--   at star, off 0); TenoStompNoJump is 0 now. Switch: script attribute SkillEffectsStompDrainEnabled (default true, read at
--   start; false = 1.34 list).
-- v1.36 (bug, Kepu 2026-11-02 after playing build 2: "Leap doesn't do crap. Tail grab doesn't do anything. The stomp has no
--   cool down"): effects for a teno (character Species, else player DinoSpecies, = "Teno") are ST.effects(steps, "Teno").
--   Since 1.33 a teno got ST.effects(steps) (no dino): SkillTree's teno blocks (1.49 parts, 1.50 stats part 2, 1.52 stomp
--   drain) only fill their fields when dino == "Teno", so the parts were Enabled with every number 0 (range, cooldown,
--   leap charges). The Species-change refresh (1.26) re-reads it. Other dinos unchanged. Switch: script attribute
--   SkillEffectsTenoDinoEnabled (default true, read at each read; false = 1.35).
-- v1.37 (Kepu 2026-11-02 16:43: Hydraulic Leap fires through JUMP, "look at how we did it for the pachy"; SkillTree 1.55): on
--   a teno with "tleap" bought AND slotted (TenoLeapEnabled true, effects leapOnJump), like Mecha Legs (1.15 / 1.16):
--   JumpBoost = SkillBase_JumpBoost x leapBoostMul, JumpLaunchPower = SkillBase_JumpLaunchPower x leapPowerMul (bases kept
--   at the first write), JumpCooldown = leapCooldown x moveCdMul, JumpCharges = leapCharges (JumpServer 1.3 / JumpTest 1.4:
--   the leap uses charges, each refilling JumpCooldown s after the one before), TenoLeapOnJump true (TenoMovesServer 1.4:
--   landing slam; MechaButtons 1.28: the slot key does nothing). Otherwise the bases back (JumpCooldown from the 1.14
--   loop), JumpCharges 0, TenoLeapOnJump false. Runs after applyChar (a wrapper). Switch: script attribute
--   SkillEffectsTenoLeapJumpEnabled (default true, read at each write; false = 1.36: nothing written).
-- v1.38 (MDA-199, plan docs/plans/THERIZINO_KIT_v1.0.md Task 3, red-team item 1): the 1.37 leap writer leaves a character with
--   Species "Therizino" alone (its JumpCharges / TenoLeapOnJump / JumpBoost / JumpLaunchPower / JumpCooldown come from
--   TherizinoModelData 1.3: the Diving Rake reuses the teno's leap-on-jump landing; without this every refresh wrote
--   JumpCharges 0 and TenoLeapOnJump false). Switch: script attribute SkillEffectsTheriLeapKeepEnabled (default true, read at
--   each write; false = 1.37).
-- v1.39 (MDA-211, plan docs/plans/THERIZINO_SPIN_STATS_v1.0.md Task 5; SkillTree 1.57): a therizino's effects (character
--   Species, else player DinoSpecies, = "Therizino") are ST.effects(steps, "Therizino") (its own rows; the shared rows it no
--   longer sees give it nothing), and its row fields are written as character attributes (THERI_ATTRS, off values when not
--   bought; a character that is not a therizino but carries them gets the off values): TheriFlowWindow / TheriFlowGap /
--   TheriFlowRecover / TheriFlowRefill, TheriFuryHit2 / TheriFuryFinisher / TheriFuryStack / TheriFuryFullMul,
--   TheriFourthDamage / TheriFourthReachMul / TheriFourthFast, TheriGuardTakenMul / TheriGuardFinisherNoStun /
--   TheriGuardShoveMul / TheriGuardKeepChain, TheriHarvestHeal / TheriHarvestKillHeal / TheriHarvestLowDouble (read by
--   TheriAttackServer 1.1 / TheriAttackTest 1.1). Runs after applyChar (a wrapper). Switch: script attribute
--   SkillEffectsTheriStatsEnabled (default true, read at each read / write; false = 1.38). Diagnostic: character
--   SkillEffectsTheriRows = "flow=n,fury=n,fourth=n,guard=n,harvest=n" (sanitized steps; "" off).
-- v1.40 (MDA-231, plan docs/plans/PACHY_STATS_v1.0.md Task 2; SkillTree 1.59 Last Stand + Head Down): for a pachy (character
--   Species "Pachy") the two rows' fields are read with ST.effects(steps, "Pachy") (only for these attributes; the pachy's
--   other effects are read as before) and written as character attributes (PACHY_ATTRS, off values when not bought; a
--   character that is not a pachy but carries them gets the off values): PachyLastStandMul, PachyLastStandBelow,
--   PachyLastStandRefillMul, PachyLastStandStar, PachyLastStandTime, PachyHeadDownMul, PachyHeadDownNoShove,
--   PachyHeadDownNoStun (read by PachyStatsServer 1.0 and HeadbuttServer 1.15). Head Down star: when StunnedUntil is set into
--   the future while PachyHeadDownNoStun is true and a headbutt charge is running (HeadbuttStartedAt newer than
--   HeadbuttEndedAt and HeadbuttHitAt), StunnedUntil = now and SkillStunTrimmed = "headdown" (Brace II's branch, before the
--   Thick Hide rules). Runs after applyChar (a wrapper, after the therizino's). Switch: script attribute
--   SkillEffectsPachyStatsEnabled (default true, read at each write / stun; false = 1.39). Diagnostic: character
--   SkillEffectsPachyRows = "laststand=n,headdown=n" (sanitized steps; "" off).
-- v1.41 (MDA-236, plan docs/plans/DILO_STATS_v1.0.md Task 2; SkillTree 1.60 dilo rows): a dilo's effects (character Species,
--   else player DinoSpecies, = "Dilo") are ST.effects(steps, "Dilo") (its own rows; the shared rows it no longer sees give it
--   nothing), and its row fields are written as character attributes (DILO_ATTRS, off values when not bought; a character
--   that is not a dilo but carries them gets the off values): DiloVenomBiteDps / DiloVenomBiteTime, DiloToxicDps /
--   DiloToxicTime, DiloFeastFrac, DiloColdMul / DiloColdBelow / DiloColdVenom / DiloColdReset (read by DiloAttackServer 1.1).
--   Spit numbers go onto the attributes the readers already use (DiloAttackServer, DiloAttackTest, ArenaTouch, AbilityBar),
--   from the character's own model values captured once per character as SkillDiloBase_<key>: DiloHoldTime = drawHold (when
--   > 0) else base; DiloDartCooldown = drawCooldown (when > 0) else base; DiloDartRange / DiloAssistMax = base x spitRangeMul;
--   DiloDartSpeed = base x spitSpeedMul (0.001 steps). Not bought, switch off or SkillEffectsEnabled false = the bases written
--   back. Runs after applyChar (a wrapper, after the pachy's). Switch: script attribute SkillEffectsDiloStatsEnabled (default
--   true, read at each read / write; false = 1.40 plus the bases written back). Diagnostic: character SkillEffectsDiloRows =
--   "venombite=n,longspit=n,toxicblood=n,venomfeast=n,quickdraw=n,coldblood=n" (sanitized steps; "" off).
-- v1.32 (tail slam rework, SkillTree 1.48, plan docs/plans/TENO_SLAM_REWORK_v1.0.md): the teno attribute TenoSlamExtraCharges
--   (effects buckCharge: 1 at Buck Off star, else 0) joins TENO_ATTRS; TenoAttackServer 1.2 adds it to the slam charges.
--   Switch: script attribute SkillEffectsTenoChargeEnabled (default true, read at start).
local VERSION = "1.30" -- v1.28 (1.27 left this at "1.26"); v1.29 squads; v1.30 Herrera pass 3
VERSION = "1.31" -- v1.31 teno rows
VERSION = "1.32" -- v1.32 Buck Off star 4th slam charge
VERSION = "1.33" -- v1.33 teno mecha parts (MDA-175)
VERSION = "1.34" -- v1.34 teno stats part 2 (1.33 reserved for the teno abilities, MDA-175)
VERSION = "1.35" -- v1.35 Stomp star latch drain (SkillTree 1.52)
VERSION = "1.36" -- v1.36 teno effects read with dino "Teno"
VERSION = "1.37" -- v1.37 teno leap on JUMP
VERSION = "1.38" -- v1.38 therizino keeps its own leap values
VERSION = "1.39" -- v1.39 therizino stat rows (THERI_ATTRS)
VERSION = "1.40" -- v1.40 pachy Last Stand + Head Down (PACHY_ATTRS)
VERSION = "1.41" -- v1.41 dilo stat rows (DILO_ATTRS + spit numbers)
if script:GetAttribute("SkillEffectsTenoEnabled") == nil then script:SetAttribute("SkillEffectsTenoEnabled", true) end -- v1.31
local TENO_ON = script:GetAttribute("SkillEffectsTenoEnabled") ~= false
local TENO_ATTRS = { -- v1.31: {attribute, effect field, off value}
	{"TenoChargeMul1", "chargeMul1", 1}, {"TenoChargeMul2", "chargeMul2", 1}, {"TenoChargeNoShove", "chargeNoShove", false},
	{"TenoChargeBump", "chargeBump", 0}, {"TenoChargeBumpStun", "chargeBumpStun", 0}, {"TenoBraceMul", "braceMul", 1},
	{"TenoBraceNoStun", "braceNoStun", false}, {"TenoBraceStack", "braceStack", 0}, {"TenoBraceHeal", "braceHeal", 0},
	{"TenoBuckBonus", "buckBonus", 0}, {"TenoBuckFree", "buckFree", false}, {"TenoBuckImmune", "buckImmune", 0},
	{"TenoBuckDps", "buckDps", 0},
}
if script:GetAttribute("SkillEffectsTenoChargeEnabled") == nil then script:SetAttribute("SkillEffectsTenoChargeEnabled", true) end -- v1.32
if script:GetAttribute("SkillEffectsTenoChargeEnabled") ~= false then
	table.insert(TENO_ATTRS, {"TenoSlamExtraCharges", "buckCharge", 0}) -- v1.32: Buck Off star -> TenoAttackServer 1.2
end
-- v1.34 (teno stats part 2, MDA-183, plan docs/plans/TENO_STATS_v1.1.md; SkillTree 1.50): the Survivor / Heavy Tail / Front
--   Claws fields join TENO_ATTRS (read by TenoAttackServer 1.3 / TenoAttackTest 1.3 / TenoStatsServer 1.1); Armored Hide
--   uses the existing Thick Hide plumbing (Defense points, toss / stun multipliers). Switch: script attribute
--   SkillEffectsTenoStats2Enabled (default true, read at start).
if script:GetAttribute("SkillEffectsTenoStats2Enabled") == nil then script:SetAttribute("SkillEffectsTenoStats2Enabled", true) end
if script:GetAttribute("SkillEffectsTenoStats2Enabled") ~= false then
	for _, f in ipairs({
		{"TenoSurvivorKillHeal", "survivorKillHeal", 0}, {"TenoSurvivorNearHeal", "survivorNearHeal", 0},
		{"TenoSurvivorNearRange", "survivorNearRange", 0}, {"TenoSurvivorRefill", "survivorRefill", false},
		{"TenoHeavyBonus", "heavyBonus", 0}, {"TenoHeavyRefillMul", "heavyRefillMul", 1}, {"TenoHeavyReachMul", "heavyReachMul", 1},
		{"TenoHeavySlow", "heavySlow", 0}, {"TenoHeavySlowTime", "heavySlowTime", 0},
		{"TenoClawBonus", "clawBonus", 0}, {"TenoClawCone", "clawCone", 0}, {"TenoClawGap", "clawGap", 0},
		{"TenoClawSlow", "clawSlow", 0}, {"TenoClawSlowTime", "clawSlowTime", 0},
	}) do table.insert(TENO_ATTRS, f) end
end
if script:GetAttribute("SkillEffectsTenoPartsEnabled") == nil then script:SetAttribute("SkillEffectsTenoPartsEnabled", true) end -- v1.33
local TPARTS_ON = script:GetAttribute("SkillEffectsTenoPartsEnabled") ~= false
local TPARTS = { -- v1.33: {path id, prefix, {attribute, effect field, off value}...}
	{"tgrab", "TenoGrab", {{"Range", "grabRange", 0}, {"Fling", "grabFling", 0}, {"Damage", "grabDamage", 0}, {"Stun", "grabStun", 0},
		{"Big", "grabBig", false}, {"Crash", "grabCrash", 0}, {"CrashRadius", "grabCrashRadius", 0}, {"Cooldown", "grabCooldown", 0}}},
	{"tmortar", "TenoMortar", {{"Range", "mortarRange", 0}, {"Miss", "mortarMiss", 0}, {"Cone", "mortarCone", 0},
		{"Damage", "mortarDamage", 0}, {"Splash", "mortarSplash", 0}, {"Count", "mortarCount", 0}, {"SlowMul", "mortarSlowMul", 1},
		{"SlowTime", "mortarSlowTime", 0}, {"Rubble", "mortarRubble", 0}, {"Cooldown", "mortarCooldown", 0}}},
	{"tstomp", "TenoStomp", {{"Range", "stompRange", 0}, {"Damage", "stompDamage", 0}, {"Stun", "stompStun", 0},
		{"NoJump", "stompNoJump", 0}, {"Cooldown", "stompCooldown", 0}}},
	{"tbellow", "TenoBellow", {{"Range", "bellowRange", 0}, {"Time", "bellowTime", 0}, {"DamageMul", "bellowDamageMul", 1},
		{"RunMul", "bellowRunMul", 1}, {"ClearStun", "bellowClearStun", false}, {"Cooldown", "bellowCooldown", 0}}},
	{"tchallenge", "TenoChallenge", {{"Range", "challengeRange", 0}, {"Time", "challengeTime", 0},
		{"WeakMul", "challengeWeakMul", 1}, {"SlowMul", "challengeSlowMul", 1}, {"Cooldown", "challengeCooldown", 0}}},
	{"tleap", "TenoLeap", {{"Dist", "leapDist", 0}, {"Damage", "leapDamage", 0}, {"Radius", "leapRadius", 0}, {"Stun", "leapStun", 0},
		{"Charges", "leapCharges", 0}, {"Cooldown", "leapCooldown", 0}}},
	{"tmud", "TenoMud", {{"Time", "mudTime", 0}, {"Hits", "mudHits", 0}, {"SlowRadius", "mudSlowRadius", 0}, {"SlowMul", "mudSlowMul", 1},
		{"SlowTime", "mudSlowTime", 0}, {"Splash", "mudSplash", 0}, {"Cooldown", "mudCooldown", 0}}},
}
if script:GetAttribute("SkillEffectsStompDrainEnabled") == nil then script:SetAttribute("SkillEffectsStompDrainEnabled", true) end -- v1.35
if script:GetAttribute("SkillEffectsStompDrainEnabled") ~= false then
	for _, def in ipairs(TPARTS) do
		if def[1] == "tstomp" then table.insert(def[3], {"LatchDrain", "stompLatchDrain", 0}) end
	end
end
if script:GetAttribute("SkillEffectsHerreraEnabled") == nil then script:SetAttribute("SkillEffectsHerreraEnabled", true) end -- v1.26
local HERRERA_ON = script:GetAttribute("SkillEffectsHerreraEnabled") ~= false
if script:GetAttribute("SkillEffectsHerreraPartsEnabled") == nil then script:SetAttribute("SkillEffectsHerreraPartsEnabled", true) end -- v1.27
local HPARTS_ON = script:GetAttribute("SkillEffectsHerreraPartsEnabled") ~= false
local HPARTS = { -- v1.27: {path id, prefix, {attribute, effect field, off value}...}
	{"ironclaw", "IronClaw", {{"DamageMul", "ironClawDamageMul", 1}, {"SpeedMul", "ironClawSpeedMul", 1}, {"Dust", "ironClawDust", false}}},
	{"plating", "Plating", {{"RearMul", "platingRearMul", 1}}},
	{"siphon", "Siphon", {{"Rate", "siphonRate", 0}, {"Range", "siphonRange", 0}, {"KillHeal", "siphonKillHeal", 0}}},
	{"glider", "Glider", {{"Fall", "gliderFall", 0}, {"Drop", "gliderDrop", false}, {"DropMul", "gliderDropMul", 1}, {"Burst", "gliderBurst", 0}}},
	{"quills", "Quill", {{"Count", "quillCount", 0}, {"Damage", "quillDamage", 0}, {"Range", "quillRange", 0}, {"Cooldown", "quillCooldown", 0}}},
	{"smoke", "Smoke", {{"Radius", "smokeRadius", 0}, {"Time", "smokeTime", 0}, {"RunMul", "smokeRunMul", 1}, {"SlowMul", "smokeSlowMul", 1},
		{"Cooldown", "smokeCooldown", 0}}},
	{"strobe", "Strobe", {{"Angle", "strobeAngle", 0}, {"Range", "strobeRange", 0}, {"Daze", "strobeDaze", 0}, {"DazedMul", "strobeDazedMul", 1},
		{"Cooldown", "strobeCooldown", 0}}},
	{"breaker", "Breaker", {{"Push", "breakerPush", 0}, {"Cooldown", "breakerCooldown", 0}, {"Immune", "breakerImmune", 0}}},
}
if script:GetAttribute("SkillEffectsHerreraPass3Enabled") == nil then script:SetAttribute("SkillEffectsHerreraPass3Enabled", true) end -- v1.30
local HPASS3_ON = script:GetAttribute("SkillEffectsHerreraPass3Enabled") ~= false
if HPASS3_ON then -- v1.30
	table.insert(HPARTS, {"caltrops", "Caltrop", {{"Count", "caltropCount", 0}, {"Radius", "caltropRadius", 0}, {"Time", "caltropTime", 0},
		{"Hidden", "caltropHidden", false}, {"BleedDps", "caltropBleedDps", 0}, {"BleedTime", "caltropBleedTime", 0},
		{"SlowMul", "caltropSlowMul", 1}, {"SlowTime", "caltropSlowTime", 0}, {"Cooldown", "caltropCooldown", 0}}})
	table.insert(HPARTS, {"goo", "Goo", {{"Toss", "gooToss", 0}, {"Radius", "gooRadius", 0}, {"Time", "gooTime", 0},
		{"Count", "gooCount", 0}, {"SlowMul", "gooSlowMul", 1}, {"Cooldown", "gooCooldown", 0}, {"AssistAngle", "gooAssistAngle", 0},
		{"AssistMin", "gooAssistMin", 0}, {"AssistMax", "gooAssistMax", 0}}})
	table.insert(HPARTS, {"hadren", "HerreraAdren", {{"SlashRefill", "adrenSlashRefill", false}}})
end
local HERRERA_BASES = {SlashRefill = 4, SlashCharges = 2, SlashBleedDps = 3, SlashBleedTime = 4, SlashDiveRange = 20,
	ClimbSpeed = 10} -- v1.26
if script:GetAttribute("SkillBleedPlayersEnabled") == nil then script:SetAttribute("SkillBleedPlayersEnabled", true) end -- v1.18
local BLEED_PLAYERS = script:GetAttribute("SkillBleedPlayersEnabled") ~= false
if script:GetAttribute("SkillBleedPlayerTime") == nil then script:SetAttribute("SkillBleedPlayerTime", 2) end -- v1.18
if script:GetAttribute("SkillEffectsBloodEnabled") == nil then script:SetAttribute("SkillEffectsBloodEnabled", true) end -- v1.17
local BLOOD_ON = script:GetAttribute("SkillEffectsBloodEnabled") ~= false
if script:GetAttribute("SkillEffectsLegsEnabled") == nil then script:SetAttribute("SkillEffectsLegsEnabled", true) end -- v1.15
local LEGS_ON = script:GetAttribute("SkillEffectsLegsEnabled") ~= false
if script:GetAttribute("SkillEffectsLegsSlotEnabled") == nil then script:SetAttribute("SkillEffectsLegsSlotEnabled", true) end -- v1.16
local LEGS_SLOT = script:GetAttribute("SkillEffectsLegsSlotEnabled") ~= false
if script:GetAttribute("SkillEffectsHookEnabled") == nil then script:SetAttribute("SkillEffectsHookEnabled", true) end -- v1.14
local HOOK_ON = script:GetAttribute("SkillEffectsHookEnabled") ~= false
if script:GetAttribute("SkillEffectsDomeEnabled") == nil then script:SetAttribute("SkillEffectsDomeEnabled", true) end -- v1.13
local DOME_ON = script:GetAttribute("SkillEffectsDomeEnabled") ~= false
if script:GetAttribute("SkillEffectsHeadbuttEnabled") == nil then script:SetAttribute("SkillEffectsHeadbuttEnabled", true) end -- v1.12
local HEADBUTT_HITS = script:GetAttribute("SkillEffectsHeadbuttEnabled") ~= false
local TICK = 0.25
local BLEED_TICK = 0.5
local COOLDOWNS = {BiteCooldown = 0.8, PounceCooldown = 3, RamCooldown = 6, JumpCooldown = 0.5}
local KILL_REGEN_DEFAULT = 0.25
if script:GetAttribute("SkillEffectsMedEnabled") == nil then script:SetAttribute("SkillEffectsMedEnabled", true) end -- v1.22
local MED_ON = script:GetAttribute("SkillEffectsMedEnabled") ~= false
if script:GetAttribute("SkillEffectsCrestEnabled") == nil then script:SetAttribute("SkillEffectsCrestEnabled", true) end -- v1.23
local CREST_ON = script:GetAttribute("SkillEffectsCrestEnabled") ~= false
if script:GetAttribute("SkillEffectsBatch3Enabled") == nil then script:SetAttribute("SkillEffectsBatch3Enabled", true) end -- v1.24
local B3_ON = script:GetAttribute("SkillEffectsBatch3Enabled") ~= false
if script:GetAttribute("SkillEffectsTetherEnabled") == nil then script:SetAttribute("SkillEffectsTetherEnabled", true) end -- v1.25
local TETHER_ON = script:GetAttribute("SkillEffectsTetherEnabled") ~= false
if script:GetAttribute("SkillEffectsRaptorLifestealEnabled") == nil then script:SetAttribute("SkillEffectsRaptorLifestealEnabled", true) end -- v1.20
for k, v in pairs({SkillEffectsIdleRegenEnabled = true, SkillIdleRegenDelay = 8, SkillIdleRegenRate = 0.05}) do -- v1.19; v1.21: rate 0.20 -> 0.05
	if script:GetAttribute(k) == nil then script:SetAttribute(k, v) end
end
local ST = require(ServerStorage:WaitForChild("DinoArcade"):WaitForChild("SkillTree"))

script:SetAttribute("SkillEffectsVersion", VERSION)
if script:GetAttribute("SkillEffectsEnabled") == nil then script:SetAttribute("SkillEffectsEnabled", true) end
local function on() return script:GetAttribute("SkillEffectsEnabled") ~= false end
for k, v in pairs({SkillDashTime = 0.35, SkillDashRecharge = 8, SkillDashSpeedMul = 2}) do -- v1.1; v1.2: + SkillDashSpeedMul; v1.3: 2 -> 3; v1.4: 3 -> 1.75; v1.7: 1.75 -> 2
	if script:GetAttribute(k) == nil then script:SetAttribute(k, v) end
end

local function now() return workspace:GetServerTimeNow() end
local function round(x, step) return math.floor(x / step + 0.5) * step end

local function isHerrera(player) -- v1.26
	if not HERRERA_ON then return false end
	local c = player.Character
	local sp = c and c:GetAttribute("Species")
	if type(sp) ~= "string" or sp == "" then sp = player:GetAttribute("DinoSpecies") end
	return sp == "Herrera"
end
local function effectsOf(player)
	local steps = {}
	for _, id in ipairs(ST.PATH_ORDER) do steps[id] = player:GetAttribute("SkillPath_" .. id) end
	if isHerrera(player) then return ST.effects(steps, "Herrera") end -- v1.26
	return ST.effects(steps)
end
-- v1.36: a teno's effects are read as the teno's
if script:GetAttribute("SkillEffectsTenoDinoEnabled") == nil then script:SetAttribute("SkillEffectsTenoDinoEnabled", true) end
do
	local effectsOfV135 = effectsOf
	effectsOf = function(player)
		if script:GetAttribute("SkillEffectsTenoDinoEnabled") ~= false then
			local c = player.Character
			local sp = c and c:GetAttribute("Species")
			if type(sp) ~= "string" or sp == "" then sp = player:GetAttribute("DinoSpecies") end
			if sp == "Teno" then
				local steps = {}
				for _, id in ipairs(ST.PATH_ORDER) do steps[id] = player:GetAttribute("SkillPath_" .. id) end
				return ST.effects(steps, "Teno")
			end
		end
		return effectsOfV135(player)
	end
end

local chars = {} -- [char] = {player, hum, e, lastDrop, lastHealth, writing = {[attr] = value last written here}}

-- own writes: the value written is remembered, so the (deferred) change signal it causes is recognised and skipped
local function writeOwn(st, char, attr, value)
	st.writing[attr] = value
	char:SetAttribute(attr, value)
end

-- stat points (player attributes; StatServer applies them)
local function applyStats(player, e)
	local live = on()
	player:SetAttribute("StatAdded_Attack", live and e.attackPts or 0)
	player:SetAttribute("StatAdded_Defense", live and e.defensePts or 0)
	player:SetAttribute("StatAdded_Speed", live and e.speedPts or 0)
end

-- cooldowns and kill heal (character attributes, from the captured bases)
local function applyChar(char, st)
	local e, live = st.e, on()
	local mainIsBite = char:GetAttribute("BiteEnabled") ~= false
	for name in pairs(COOLDOWNS) do
		local mul = 1
		if live then
			if name == "BiteCooldown" and mainIsBite then mul *= e.mainCdMul end
			if name == "PounceCooldown" and not mainIsBite then mul *= e.mainCdMul end
			if name ~= "BiteCooldown" then mul *= e.moveCdMul end
		end
		writeOwn(st, char, name, round(char:GetAttribute("SkillBase_" .. name) * mul, 0.01))
	end
	writeOwn(st, char, "KillRegenFraction", char:GetAttribute("SkillBase_KillRegenFraction") + (live and e.killRegenAdd or 0))
	if not live or e.shieldMax <= 0 then
		char:SetAttribute("SkillShield", 0)
		char:SetAttribute("SkillShieldUntil", nil)
	end
	char:SetAttribute("SkillEffectsState", live and "ready" or "off")
	-- v1.1: Thrusters dash (only while slotted)
	local slotted = false
	for n = 1, ST.SLOTS or 2 do
		if st.player:GetAttribute("SkillSlot" .. n) == "thrusters" then slotted = true end
	end
	local dashOn = live and (e.dashCharges or 0) > 0 and slotted
	char:SetAttribute("DashEnabled", dashOn)
	char:SetAttribute("DashCharges", dashOn and e.dashCharges or 0)
	char:SetAttribute("DashDistance", e.dashDist or 0)
	char:SetAttribute("DashHop", dashOn and e.dashHop or 0)
	char:SetAttribute("DashTime", (dashOn and (e.dashTime or 0) > 0) and e.dashTime or script:GetAttribute("SkillDashTime")) -- v1.2
	char:SetAttribute("DashSpeedMul", script:GetAttribute("SkillDashSpeedMul")) -- v1.2
	char:SetAttribute("DashRecharge", script:GetAttribute("SkillDashRecharge"))
	-- v1.5: Cloak Field (only while slotted)
	local cloakSlotted = false
	for n = 1, ST.SLOTS or 2 do
		if st.player:GetAttribute("SkillSlot" .. n) == "cloak" then cloakSlotted = true end
	end
	local cloakOn = live and (e.cloakTime or 0) > 0 and cloakSlotted
	char:SetAttribute("CloakEnabled", cloakOn)
	char:SetAttribute("CloakTime", cloakOn and e.cloakTime or 0)
	char:SetAttribute("CloakCooldown", cloakOn and e.cloakCooldown or 0)
	char:SetAttribute("CloakPounceMul", cloakOn and (e.cloakPounceMul or 1) or 1)
	char:SetAttribute("CloakStill", cloakOn and e.cloakStill == true or false)
	-- v1.6: raptor batch 1
	local function inSlot(id)
		for n = 1, ST.SLOTS or 2 do
			if st.player:GetAttribute("SkillSlot" .. n) == id then return true end
		end
		return false
	end
	local bladeOn = live and (e.bladeLandBonus or 0) > 0
	char:SetAttribute("BladeLook", bladeOn)
	char:SetAttribute("BladeLandBonus", bladeOn and e.bladeLandBonus or 0)
	char:SetAttribute("BladeTickMul", bladeOn and (e.bladeTickMul or 1) or 1)
	char:SetAttribute("BladeBleedDps", bladeOn and (e.bladeBleedDps or 0) or 0)
	char:SetAttribute("BladeBleedTime", bladeOn and (e.bladeBleedTime or 0) or 0)
	char:SetAttribute("BladePinRefund", bladeOn and (e.bladePinRefund or 0) or 0)
	local adOn = live and (e.adrenTime or 0) > 0 and (inSlot("adrenaline")
		or (HPASS3_ON and char:GetAttribute("Species") == "Herrera" and inSlot("hadren"))) -- v1.30: the Herrera's injector
	char:SetAttribute("AdrenalineSlashRefill", adOn and e.adrenSlashRefill == true or false) -- v1.30
	char:SetAttribute("AdrenalineEnabled", adOn)
	char:SetAttribute("AdrenalineHeal", adOn and e.adrenHeal or 0)
	char:SetAttribute("AdrenalineTime", adOn and e.adrenTime or 0)
	char:SetAttribute("AdrenalineSpeedMul", adOn and (e.adrenSpeedMul or 1) or 1)
	char:SetAttribute("AdrenalineCooldown", adOn and e.adrenCooldown or 0)
	char:SetAttribute("AdrenalineStunClear", adOn and e.adrenStunClear == true or false)
	local shOn = live and (e.eshieldTime or 0) > 0 and inSlot("shield")
	char:SetAttribute("EnergyShieldEnabled", shOn)
	char:SetAttribute("EnergyShieldTime", shOn and e.eshieldTime or 0)
	char:SetAttribute("EnergyShieldCooldown", shOn and e.eshieldCooldown or 0)
	char:SetAttribute("EnergyShieldSpeedMul", shOn and (e.eshieldSpeedMul or 1) or 1)
	-- v1.8: Scent Sense / Raptor Screech (booleans with explicit if/else)
	local scOn = false
	if live and (e.scentTime or 0) > 0 and inSlot("scent") then scOn = true end
	char:SetAttribute("ScentEnabled", scOn)
	char:SetAttribute("ScentRadius", scOn and e.scentRadius or 0)
	char:SetAttribute("ScentMemory", scOn and e.scentMemory or 0)
	char:SetAttribute("ScentTime", scOn and e.scentTime or 0)
	char:SetAttribute("ScentCooldown", scOn and e.scentCooldown or 0)
	local fresh, blood = false, false
	if scOn and e.scentFresh == true then fresh = true end
	if scOn and e.scentBlood == true then blood = true end
	char:SetAttribute("ScentFresh", fresh)
	char:SetAttribute("ScentBlood", blood)
	local srOn = false
	if live and (e.screechRange or 0) > 0 and inSlot("screech") then srOn = true end
	char:SetAttribute("ScreechEnabled", srOn)
	char:SetAttribute("ScreechRange", srOn and e.screechRange or 0)
	char:SetAttribute("ScreechFlinch", srOn and e.screechFlinch or 0)
	char:SetAttribute("ScreechCooldown", srOn and e.screechCooldown or 0)
	local jam = false
	if srOn and e.screechJam == true then jam = true end
	char:SetAttribute("ScreechJam", jam)
	char:SetAttribute("ScreechDamage", srOn and (e.screechDamage or 0) or 0) -- v1.11
	-- v1.9: Shock Mine (path "traps")
	local mnOn = false
	if live and (e.mineMax or 0) > 0 and inSlot("traps") then mnOn = true end
	char:SetAttribute("MineEnabled", mnOn)
	char:SetAttribute("MineDamage", mnOn and e.mineDamage or 0)
	char:SetAttribute("MineSlow", mnOn and (e.mineSlow or 1) or 1)
	char:SetAttribute("MineSlowTime", mnOn and e.mineSlowTime or 0)
	char:SetAttribute("MineCooldown", mnOn and e.mineCooldown or 0)
	char:SetAttribute("MineMax", mnOn and e.mineMax or 0)
	local mjam = false
	if mnOn and e.mineJam == true then mjam = true end
	char:SetAttribute("MineJam", mjam)
	char:SetAttribute("MineLaunch", mnOn and (e.mineLaunch or 0) or 0) -- v1.10
	char:SetAttribute("MineDaze", mnOn and (e.mineDaze or 0) or 0) -- v1.10
	if DOME_ON then -- v1.13: Battering Dome (pachy only)
		local bdOn = live and char:GetAttribute("Species") == "Pachy"
		char:SetAttribute("HeadbuttDamageMul", bdOn and (e.hbDamageMul or 1) or 1)
		char:SetAttribute("HeadbuttShoveMul", bdOn and (e.hbShoveMul or 1) or 1)
		char:SetAttribute("HeadbuttRefillMul", bdOn and (e.hbRefillMul or 1) or 1)
		char:SetAttribute("HeadbuttExtraCharges", bdOn and (e.hbExtraCharges or 0) or 0)
		char:SetAttribute("PachySpikes", bdOn and e.pachySpikes == true)
	end
	if HOOK_ON then -- v1.14: Grappling Hook (pachy only, in a slot)
		local hkOn = live and char:GetAttribute("Species") == "Pachy" and (e.hookRange or 0) > 0 and inSlot("hookarm")
		char:SetAttribute("HookEnabled", hkOn)
		char:SetAttribute("HookRange", hkOn and e.hookRange or 0)
		char:SetAttribute("HookCooldown", hkOn and e.hookCooldown or 0)
		char:SetAttribute("HookDamage", hkOn and e.hookDamage or 0)
		char:SetAttribute("HookLook", hkOn)
	end
	if B3_ON then -- v1.24: pachy parts batch 3 (in a slot)
		local isPachy = live and char:GetAttribute("Species") == "Pachy"
		local sdOn = isPachy and (e.servoTime or 0) > 0 and inSlot("servodash")
		char:SetAttribute("ServoDashEnabled", sdOn)
		char:SetAttribute("ServoDashTime", sdOn and e.servoTime or 0)
		char:SetAttribute("ServoDashCooldown", sdOn and e.servoCd or 0)
		char:SetAttribute("ServoDashSpeedMul", sdOn and e.servoMul or 1)
		char:SetAttribute("ServoDashRefill", sdOn and e.servoRefill == true)
		char:SetAttribute("ServoDashLook", sdOn)
		local vzOn = isPachy and (e.visorTime or 0) > 0 and inSlot("visor")
		char:SetAttribute("VisorEnabled", vzOn)
		char:SetAttribute("VisorTime", vzOn and e.visorTime or 0)
		char:SetAttribute("VisorCooldown", vzOn and e.visorCd or 0)
		char:SetAttribute("VisorKnock", vzOn and e.visorKnock == true)
		char:SetAttribute("VisorLook", vzOn)
		local ikOn = isPachy and (e.inkRange or 0) > 0 and inSlot("ink")
		char:SetAttribute("InkEnabled", ikOn)
		char:SetAttribute("InkRange", ikOn and e.inkRange or 0)
		char:SetAttribute("InkCooldown", ikOn and e.inkCd or 0)
		char:SetAttribute("InkBlindTime", ikOn and e.inkBlind or 0)
		char:SetAttribute("InkSplash", ikOn and e.inkSplash or 0)
		char:SetAttribute("InkLook", ikOn)
	end
	if TETHER_ON then -- v1.25: pachy Tether Spike (in a slot)
		local ttOn = live and char:GetAttribute("Species") == "Pachy" and (e.tetherRange or 0) > 0 and inSlot("tether")
		char:SetAttribute("TetherEnabled", ttOn)
		char:SetAttribute("TetherRange", ttOn and e.tetherRange or 0)
		char:SetAttribute("TetherSplash", ttOn and e.tetherSplash or 0)
		char:SetAttribute("TetherReach", ttOn and e.tetherReach or 0)
		char:SetAttribute("TetherTime", ttOn and e.tetherTime or 0)
		char:SetAttribute("TetherCooldown", ttOn and e.tetherCd or 0)
		char:SetAttribute("TetherYank", ttOn and e.tetherYank == true)
		char:SetAttribute("TetherYankReach", ttOn and e.tetherYankReach or 0)
		char:SetAttribute("TetherLook", ttOn)
	end
	if CREST_ON then -- v1.23: Bone Crest (pachy only, passive)
		local bcOn = live and char:GetAttribute("Species") == "Pachy" and (e.crestMul or 1) < 1
		char:SetAttribute("BoneCrestMul", bcOn and e.crestMul or 1)
		char:SetAttribute("BoneCrestReflect", bcOn and (e.crestReflect or 0) or 0)
	end
	if MED_ON then -- v1.22: Med-Station (pachy only, in a slot)
		local mdOn = live and char:GetAttribute("Species") == "Pachy" and (e.medTime or 0) > 0 and inSlot("medstation")
		char:SetAttribute("MedEnabled", mdOn)
		char:SetAttribute("MedRadius", mdOn and e.medRadius or 0)
		char:SetAttribute("MedTime", mdOn and e.medTime or 0)
		char:SetAttribute("MedRate", mdOn and e.medRate or 0)
		char:SetAttribute("MedCooldown", mdOn and e.medCooldown or 0)
	end
	if LEGS_ON then -- v1.15: Mecha Legs (pachy only, passive)
		local mlOn = live and char:GetAttribute("Species") == "Pachy" and (e.legsCooldown or 0) > 0
			and (not LEGS_SLOT or inSlot("mechalegs")) -- v1.16: only while slotted
		char:SetAttribute("MechaLegsEnabled", mlOn) -- v1.16
		for _, k in ipairs({"JumpBoost", "JumpLaunchPower"}) do
			if char:GetAttribute("SkillBase_" .. k) == nil and char:GetAttribute(k) ~= nil then
				char:SetAttribute("SkillBase_" .. k, char:GetAttribute(k))
			end
		end
		local bBoost, bPower = char:GetAttribute("SkillBase_JumpBoost"), char:GetAttribute("SkillBase_JumpLaunchPower")
		if bBoost then writeOwn(st, char, "JumpBoost", round(bBoost * (mlOn and e.legsBoostMul or 1), 0.01)) end
		if bPower then writeOwn(st, char, "JumpLaunchPower", round(bPower * (mlOn and e.legsPowerMul or 1), 0.01)) end
		if mlOn then
			writeOwn(st, char, "JumpCooldown", round(e.legsCooldown * (e.legsCdMul or 1) * (e.moveCdMul or 1), 0.01))
		end
		char:SetAttribute("JumpDoubleEnabled", mlOn and e.doubleJump == true)
		char:SetAttribute("JumpDoubleMul", e.legsDoubleMul or 0.894) -- v1.16 (was 0.894)
		char:SetAttribute("JumpDoubleForward", mlOn and e.legsDoubleForward or 0) -- v1.16
		char:SetAttribute("MechaLegsLook", mlOn and e.legsLook == true)
	end
	if BLOOD_ON then -- v1.17: Blood Rush (pachy only, slotted)
		local brOn = live and char:GetAttribute("Species") == "Pachy" and e.bloodRush == true and inSlot("bloodrush")
		char:SetAttribute("BloodRushEnabled", brOn == true)
		char:SetAttribute("BloodRushCost", brOn and e.bloodCost or 0)
		char:SetAttribute("BloodRushMax", brOn and e.bloodMax or 0)
		char:SetAttribute("BloodRushDamageMul", brOn and e.bloodDamageMul or 1)
		char:SetAttribute("BloodRushNoSelfSlow", brOn and e.bloodNoSelfSlow == true or false)
		char:SetAttribute("BloodRushSlowMul", brOn and e.bloodSlowMul or 1)
		char:SetAttribute("BloodRushSlowTime", brOn and e.bloodSlowTime or 0)
	end
	if HPARTS_ON then -- v1.27: the Herrera's mecha parts (bought AND slotted)
		local isH = char:GetAttribute("Species") == "Herrera"
		for _, def in ipairs(HPARTS) do
			local id, prefix = def[1], def[2]
			local passive = script:GetAttribute("SkillEffectsHerreraPassiveEnabled") ~= false and ST.BUTTONS[id] ~= true -- v1.28
			local on = live and isH and (tonumber(st.player:GetAttribute("SkillPath_" .. id)) or 0) >= 1 and (inSlot(id) or passive)
			for _, f in ipairs(def[3]) do
				local v = f[3]
				if on and e[f[2]] ~= nil then v = e[f[2]] end
				if char:GetAttribute(prefix .. f[1]) ~= v then char:SetAttribute(prefix .. f[1], v) end
			end
			if char:GetAttribute(prefix .. "Enabled") ~= (on == true) then char:SetAttribute(prefix .. "Enabled", on == true) end
		end
	end
	if HERRERA_ON then -- v1.26: the Herrera's rows
		local hOn = char:GetAttribute("Species") == "Herrera"
		char:SetAttribute("SkillEffectsDino", hOn and "Herrera" or "")
		if hOn then
			for k, d in pairs(HERRERA_BASES) do
				if char:GetAttribute("SkillBase_" .. k) == nil then
					local v = char:GetAttribute(k)
					char:SetAttribute("SkillBase_" .. k, typeof(v) == "number" and v or d)
				end
			end
			local function base(k) return char:GetAttribute("SkillBase_" .. k) end
			local x = live and e or {}
			writeOwn(st, char, "SlashRefill", round(base("SlashRefill") * (x.slashRefillMul or 1), 0.01))
			writeOwn(st, char, "SlashBleedDps", (x.slashBleedDps or 0) > 0 and x.slashBleedDps or base("SlashBleedDps"))
			writeOwn(st, char, "SlashCharges", base("SlashCharges") + (x.slashExtraCharges or 0))
			writeOwn(st, char, "ClimbSpeed", round(base("ClimbSpeed") * (x.climbSpeedMul or 1), 0.01))
			writeOwn(st, char, "SlashDiveRange", round(base("SlashDiveRange") * (x.diveRangeMul or 1), 0.01))
			writeOwn(st, char, "SlashBleedTime", (x.slashBleedTime or 0) > 0 and x.slashBleedTime or base("SlashBleedTime"))
			char:SetAttribute("SlashDiveRefill", x.diveRefill == true)
			char:SetAttribute("TreeTopHidden", x.treeTopHidden == true)
			char:SetAttribute("SlashDiveStun", x.diveStun or 0)
			char:SetAttribute("SlashFrenzyMul", x.frenzySpeedMul or 1)
			char:SetAttribute("SlashBleedBonus", x.bleedBonus or 0)
			char:SetAttribute("SlashKillRefill", x.killRefill == true)
		end
	end
	if TENO_ON then -- v1.31: the Tenontosaurus' rows
		local tOn = char:GetAttribute("Species") == "Teno"
		if tOn or char:GetAttribute("TenoBraceMul") ~= nil then
			local x = (live and tOn) and e or {}
			for _, f in ipairs(TENO_ATTRS) do
				local v = x[f[2]]
				if v == nil then v = f[3] end
				if char:GetAttribute(f[1]) ~= v then char:SetAttribute(f[1], v) end
			end
		end
	end
	if TPARTS_ON then -- v1.33: the teno's mecha parts (bought AND slotted)
		local tOn = char:GetAttribute("Species") == "Teno"
		if tOn or char:GetAttribute("TenoGrabEnabled") ~= nil then
			for _, def in ipairs(TPARTS) do
				local id, prefix = def[1], def[2]
				local pOn = live and tOn and (tonumber(st.player:GetAttribute("SkillPath_" .. id)) or 0) >= 1 and inSlot(id)
				for _, f in ipairs(def[3]) do
					local v = f[3]
					if pOn and e[f[2]] ~= nil then v = e[f[2]] end
					if char:GetAttribute(prefix .. f[1]) ~= v then char:SetAttribute(prefix .. f[1], v) end
				end
				if char:GetAttribute(prefix .. "Enabled") ~= (pOn == true) then char:SetAttribute(prefix .. "Enabled", pOn == true) end
			end
		end
	end
end

-- v1.37: Hydraulic Leap fires through JUMP (see the header)
if script:GetAttribute("SkillEffectsTenoLeapJumpEnabled") == nil then script:SetAttribute("SkillEffectsTenoLeapJumpEnabled", true) end
do
	local applyCharV136 = applyChar
	applyChar = function(char, st)
		applyCharV136(char, st)
		if script:GetAttribute("SkillEffectsTenoLeapJumpEnabled") == false then return end
		if char:GetAttribute("Species") == "Therizino" and script:GetAttribute("SkillEffectsTheriLeapKeepEnabled") ~= false then return end -- v1.38
		local isTeno = char:GetAttribute("Species") == "Teno"
		if not isTeno and char:GetAttribute("TenoLeapOnJump") == nil then return end
		local e = st.e
		local lOn = isTeno and on() and char:GetAttribute("TenoLeapEnabled") == true and e.leapOnJump == true
		for _, k in ipairs({"JumpBoost", "JumpLaunchPower"}) do
			if char:GetAttribute("SkillBase_" .. k) == nil and char:GetAttribute(k) ~= nil then
				char:SetAttribute("SkillBase_" .. k, char:GetAttribute(k))
			end
		end
		local bB, bP = char:GetAttribute("SkillBase_JumpBoost"), char:GetAttribute("SkillBase_JumpLaunchPower")
		if bB then writeOwn(st, char, "JumpBoost", round(bB * (lOn and (e.leapBoostMul or 1) or 1), 0.01)) end
		if bP then writeOwn(st, char, "JumpLaunchPower", round(bP * (lOn and (e.leapPowerMul or 1) or 1), 0.01)) end
		if lOn then writeOwn(st, char, "JumpCooldown", round((e.leapCooldown or 6) * (e.moveCdMul or 1), 0.01)) end
		local n = lOn and math.max(1, math.floor(tonumber(e.leapCharges) or 1)) or 0
		if char:GetAttribute("JumpCharges") ~= n then char:SetAttribute("JumpCharges", n) end
		if char:GetAttribute("TenoLeapOnJump") ~= lOn then char:SetAttribute("TenoLeapOnJump", lOn) end
	end
end

-- v1.39: the therizino's own stat rows (see the header)
if script:GetAttribute("SkillEffectsTheriStatsEnabled") == nil then script:SetAttribute("SkillEffectsTheriStatsEnabled", true) end
local THERI_ATTRS = { -- {attribute, effect field, off value}
	{"TheriFlowWindow", "flowWindow", 0}, {"TheriFlowGap", "flowGap", 0}, {"TheriFlowRecover", "flowRecover", 0},
	{"TheriFlowRefill", "flowRefill", false}, {"TheriFuryHit2", "furyHit2", 0}, {"TheriFuryFinisher", "furyFinisher", 0},
	{"TheriFuryStack", "furyStack", 0}, {"TheriFuryFullMul", "furyFullMul", 1}, {"TheriFourthDamage", "fourthDamage", 0},
	{"TheriFourthReachMul", "fourthReachMul", 1}, {"TheriFourthFast", "fourthFast", false},
	{"TheriGuardTakenMul", "guardTakenMul", 1}, {"TheriGuardFinisherNoStun", "guardFinisherNoStun", false},
	{"TheriGuardShoveMul", "guardShoveMul", 1}, {"TheriGuardKeepChain", "guardKeepChain", false},
	{"TheriHarvestHeal", "harvestHeal", 0}, {"TheriHarvestKillHeal", "harvestKillHeal", 0},
	{"TheriHarvestLowDouble", "harvestLowDouble", false},
}
local function theriStatsOn() return script:GetAttribute("SkillEffectsTheriStatsEnabled") ~= false and ST.THERI_STATS == true end
do
	local effectsOfV138 = effectsOf
	effectsOf = function(player)
		if theriStatsOn() then
			local c = player.Character
			local sp = c and c:GetAttribute("Species")
			if type(sp) ~= "string" or sp == "" then sp = player:GetAttribute("DinoSpecies") end
			if sp == "Therizino" then
				local steps = {}
				for _, id in ipairs(ST.PATH_ORDER) do steps[id] = player:GetAttribute("SkillPath_" .. id) end
				return ST.effects(steps, "Therizino")
			end
		end
		return effectsOfV138(player)
	end
end
do
	local applyCharV138 = applyChar
	applyChar = function(char, st)
		applyCharV138(char, st)
		if not theriStatsOn() then return end
		local isTheri = char:GetAttribute("Species") == "Therizino"
		if not isTheri and char:GetAttribute("TheriFlowWindow") == nil then return end
		local x = (on() and isTheri) and st.e or {}
		for _, f in ipairs(THERI_ATTRS) do
			local v = x[f[2]]
			if v == nil then v = f[3] end
			if char:GetAttribute(f[1]) ~= v then char:SetAttribute(f[1], v) end
		end
		local rows = ""
		if on() and isTheri then
			local steps = {}
			for _, id in ipairs(ST.PATH_ORDER) do steps[id] = st.player:GetAttribute("SkillPath_" .. id) end
			local c = ST.sanitize(steps, "Therizino")
			rows = ("flow=%d,fury=%d,fourth=%d,guard=%d,harvest=%d"):format(c.flow or 0, c.fury or 0, c.fourth or 0, c.guard or 0, c.harvest or 0)
		end
		if char:GetAttribute("SkillEffectsTheriRows") ~= rows then char:SetAttribute("SkillEffectsTheriRows", rows) end
	end
end

-- v1.40: the pachy's Last Stand + Head Down rows (see the header)
if script:GetAttribute("SkillEffectsPachyStatsEnabled") == nil then script:SetAttribute("SkillEffectsPachyStatsEnabled", true) end
local PACHY_ATTRS = { -- {attribute, effect field, off value}
	{"PachyLastStandMul", "lastStandMul", 1}, {"PachyLastStandBelow", "lastStandBelow", 0},
	{"PachyLastStandRefillMul", "lastStandRefillMul", 1}, {"PachyLastStandStar", "lastStandStar", false},
	{"PachyLastStandTime", "lastStandTime", 0}, {"PachyHeadDownMul", "headDownMul", 1},
	{"PachyHeadDownNoShove", "headDownNoShove", false}, {"PachyHeadDownNoStun", "headDownNoStun", false},
}
local function pachyStatsOn() return script:GetAttribute("SkillEffectsPachyStatsEnabled") ~= false and ST.PACHY_STATS == true end
local function pachyCharging(char)
	local s = tonumber(char:GetAttribute("HeadbuttStartedAt")) or 0
	return s > 0 and s > (tonumber(char:GetAttribute("HeadbuttEndedAt")) or 0) and s > (tonumber(char:GetAttribute("HeadbuttHitAt")) or 0)
end
do
	local applyCharV139 = applyChar
	applyChar = function(char, st)
		applyCharV139(char, st)
		if not pachyStatsOn() then return end
		local isPachy = char:GetAttribute("Species") == "Pachy"
		if not isPachy and char:GetAttribute("PachyLastStandMul") == nil then return end
		local x, rows = {}, ""
		if on() and isPachy then
			local steps = {}
			for _, id in ipairs(ST.PATH_ORDER) do steps[id] = st.player:GetAttribute("SkillPath_" .. id) end
			x = ST.effects(steps, "Pachy")
			local c = ST.sanitize(steps, "Pachy")
			rows = ("laststand=%d,headdown=%d"):format(c.laststand or 0, c.headdown or 0)
		end
		for _, f in ipairs(PACHY_ATTRS) do
			local v = x[f[2]]
			if v == nil then v = f[3] end
			if char:GetAttribute(f[1]) ~= v then char:SetAttribute(f[1], v) end
		end
		if char:GetAttribute("SkillEffectsPachyRows") ~= rows then char:SetAttribute("SkillEffectsPachyRows", rows) end
	end
end

-- v1.41: the dilo's own stat rows (see the header)
if script:GetAttribute("SkillEffectsDiloStatsEnabled") == nil then script:SetAttribute("SkillEffectsDiloStatsEnabled", true) end
local DILO_ATTRS = { -- {attribute, effect field, off value}
	{"DiloVenomBiteDps", "venomBiteDps", 0}, {"DiloVenomBiteTime", "venomBiteTime", 0}, {"DiloToxicDps", "toxicDps", 0},
	{"DiloToxicTime", "toxicTime", 0}, {"DiloFeastFrac", "feastFrac", 0}, {"DiloColdMul", "coldMul", 1},
	{"DiloColdBelow", "coldBelow", 0}, {"DiloColdVenom", "coldVenom", false}, {"DiloColdReset", "coldReset", false},
}
local DILO_SPIT = {"DiloHoldTime", "DiloDartCooldown", "DiloDartRange", "DiloAssistMax", "DiloDartSpeed"}
local function diloStatsOn() return script:GetAttribute("SkillEffectsDiloStatsEnabled") ~= false and ST.DILO_STATS == true end
do
	local effectsOfV140 = effectsOf
	effectsOf = function(player)
		if diloStatsOn() then
			local c = player.Character
			local sp = c and c:GetAttribute("Species")
			if type(sp) ~= "string" or sp == "" then sp = player:GetAttribute("DinoSpecies") end
			if sp == "Dilo" then
				local steps = {}
				for _, id in ipairs(ST.PATH_ORDER) do steps[id] = player:GetAttribute("SkillPath_" .. id) end
				return ST.effects(steps, "Dilo")
			end
		end
		return effectsOfV140(player)
	end
end
do
	local applyCharV140 = applyChar
	applyChar = function(char, st)
		applyCharV140(char, st)
		local isDilo = char:GetAttribute("Species") == "Dilo"
		-- bases: the character's own model values, once per character
		if isDilo then
			for _, k in ipairs(DILO_SPIT) do
				if char:GetAttribute("SkillDiloBase_" .. k) == nil and typeof(char:GetAttribute(k)) == "number" then
					char:SetAttribute("SkillDiloBase_" .. k, char:GetAttribute(k))
				end
			end
		end
		local live = on() and isDilo and diloStatsOn()
		local x = live and st.e or {}
		-- spit numbers (bases back when not live)
		for _, k in ipairs(DILO_SPIT) do
			local base = char:GetAttribute("SkillDiloBase_" .. k)
			if typeof(base) == "number" then
				local v = base
				if live then
					if k == "DiloHoldTime" and (tonumber(x.drawHold) or 0) > 0 then v = x.drawHold
					elseif k == "DiloDartCooldown" and (tonumber(x.drawCooldown) or 0) > 0 then v = x.drawCooldown
					elseif k == "DiloDartRange" or k == "DiloAssistMax" then v = base * (tonumber(x.spitRangeMul) or 1)
					elseif k == "DiloDartSpeed" then v = base * (tonumber(x.spitSpeedMul) or 1) end
				end
				v = round(v, 0.001)
				if char:GetAttribute(k) ~= v then char:SetAttribute(k, v) end
			end
		end
		if not diloStatsOn() then return end
		if not isDilo and char:GetAttribute("DiloVenomBiteDps") == nil then return end
		for _, f in ipairs(DILO_ATTRS) do
			local v = x[f[2]]
			if v == nil then v = f[3] end
			if char:GetAttribute(f[1]) ~= v then char:SetAttribute(f[1], v) end
		end
		local rows = ""
		if live then
			local steps = {}
			for _, id in ipairs(ST.PATH_ORDER) do steps[id] = st.player:GetAttribute("SkillPath_" .. id) end
			local c = ST.sanitize(steps, "Dilo")
			rows = ("venombite=%d,longspit=%d,toxicblood=%d,venomfeast=%d,quickdraw=%d,coldblood=%d"):format(c.venombite or 0,
				c.longspit or 0, c.toxicblood or 0, c.venomfeast or 0, c.quickdraw or 0, c.coldblood or 0)
		end
		if char:GetAttribute("SkillEffectsDiloRows") ~= rows then char:SetAttribute("SkillEffectsDiloRows", rows) end
	end
end

-- healing (regen / lifesteal), overflow into the shield
local function heal(char, st, amount, source)
	local hum = st.hum
	if amount <= 0 or hum.Health <= 0 then return end
	local room = hum.MaxHealth - hum.Health
	local toHealth = math.min(room, amount)
	if toHealth > 0 then
		st.lastHealth = hum.Health + toHealth -- our own raise, not a drop
		hum.Health += toHealth
	end
	local over = amount - toHealth
	if over > 0 and st.e.shieldMax > 0 then
		local cap = st.e.shieldMax * hum.MaxHealth
		local shield = math.min(cap, (char:GetAttribute("SkillShield") or 0) + over)
		char:SetAttribute("SkillShield", round(shield, 0.1))
		char:SetAttribute("SkillShieldUntil", now() + st.e.shieldTime)
	end
	char:SetAttribute("SkillLastHeal", ("%s +%d"):format(source, math.floor(amount + 0.5)))
end

-- bots hit by a player
local function findBot(name)
	if type(name) ~= "string" then return nil end
	local island = workspace:FindFirstChild("DinoIsland")
	local bots = island and island:FindFirstChild("Bots")
	local m = bots and bots:FindFirstChild(name)
	if m and m:GetAttribute("IsBot") == true then return m end
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("Model") and d.Name == name and d:GetAttribute("IsBot") == true then return d end
	end
	return nil
end

local bleeds = {} -- [bot] = {char, player, dps, untilT}
-- v1.29: squadmates are never targets (SquadRules 1.0, loaded on first use)
local squadMod
local function squadmate(a, b)
	if script:GetAttribute("SkillEffectsSquadEnabled") == false then return false end
	if not squadMod then
		local arc = game:GetService("ServerStorage"):FindFirstChild("DinoArcade")
		local m = arc and arc:FindFirstChild("SquadRules")
		if not m then return false end
		local ok, mod = pcall(require, m)
		if not ok then return false end
		squadMod = mod
	end
	if squadMod.sameChar(a, b) then
		script:SetAttribute("SkillEffectsSquadSkips", (script:GetAttribute("SkillEffectsSquadSkips") or 0) + 1)
		return true
	end
	return false
end
local function findBridgedPlayer(name, attacker) -- v1.18: a player's dino ArenaPvP bridges (Arena only)
	if not BLEED_PLAYERS or type(name) ~= "string" then return nil end
	local m = workspace:FindFirstChild(name)
	if m and m ~= attacker and m:IsA("Model")
		and (game:GetService("Players"):GetPlayerFromCharacter(m) or m:GetAttribute("ArenaPvPTestTarget") == true)
		and m:GetAttribute("ArenaPvPBridged") == true and m:GetAttribute("Bitable") == true
		and not (attacker and squadmate(attacker, m)) then -- v1.29: squad
		return m
	end
	return nil
end
local crushed = setmetatable({}, {__mode = "k"}) -- [bot] = last crush time

local function onHit(char, st, damage, targetName, isPounce) -- v1.6: + isPounce
	if not on() then return end
	local e = st.e
	local stealRate = e.lifesteal
	if script:GetAttribute("SkillEffectsRaptorLifestealEnabled") ~= false and char:GetAttribute("Species") == "Raptor"
		and (e.lifestealRaptor or 0) > 0 then stealRate = e.lifestealRaptor end -- v1.20
	if stealRate > 0 and type(damage) == "number" and damage > 0 then
		char:SetAttribute("SkillLifestealRate", stealRate)
		heal(char, st, stealRate * damage, "lifesteal")
	end
	local bleedDps, bleedTime = e.bleedDps, e.bleedTime
	if isPounce and (e.bladeBleedDps or 0) > bleedDps then bleedDps, bleedTime = e.bladeBleedDps, e.bladeBleedTime end -- v1.6
	if bleedDps <= 0 and e.crushStun <= 0 then return end
	local bot = findBot(targetName)
	local isPlayer = false
	if not bot then -- v1.18: a player's dino (bleed only; the crushing hit stays bots only)
		bot = findBridgedPlayer(targetName, char)
		isPlayer = bot ~= nil
		if isPlayer then bleedTime = math.min(bleedTime, tonumber(script:GetAttribute("SkillBleedPlayerTime")) or 2) end
	end
	if not bot or (tonumber(bot:GetAttribute("DummyHealth")) or 0) <= 0 then return end
	local t = now()
	if isPlayer and bleedDps <= 0 then return end
	if bleedDps > 0 then
		bleeds[bot] = {char = char, player = st.player, dps = bleedDps, untilT = t + bleedTime, isPlayer = isPlayer}
		bot:SetAttribute("SkillBleedUntil", t + bleedTime)
		bot:SetAttribute("SkillBleedBy", char.Name)
	end
	if not isPlayer and e.crushStun > 0 and t - (crushed[bot] or -math.huge) >= e.crushCooldown then
		crushed[bot] = t
		bot:SetAttribute("StunnedUntil", math.max(bot:GetAttribute("StunnedUntil") or 0, t + e.crushStun))
		bot:SetAttribute("SkillCrushedAt", t)
	end
end

-- bleed ticks
task.spawn(function()
	while true do
		task.wait(BLEED_TICK)
		local t = now()
		for bot, b in pairs(bleeds) do
			local hp = tonumber(bot:GetAttribute("DummyHealth"))
			if not bot.Parent or not on() or not hp or hp <= 0 or t > b.untilT then
				bleeds[bot] = nil
				if bot.Parent then bot:SetAttribute("SkillBleedUntil", nil) end
				continue
			end
			local d = b.dps * BLEED_TICK
			bot:SetAttribute("DummyHealth", math.max(0, hp - d))
			if b.isPlayer and hp - d <= 0 then -- v1.18: credit for ArenaPvP on a player's dino
				bot:SetAttribute("LastHitBy", b.char.Name)
				bot:SetAttribute("LastHitAt", t)
			end
			if hp - d <= 0 then -- killing blow, stamped like BiteServer 1.6
				bot:SetAttribute("KilledBy", b.char.Name)
				bot:SetAttribute("KilledByUserId", b.player and b.player.UserId or 0)
				bot:SetAttribute("KilledWith", "bleed")
				bot:SetAttribute("KilledAt", t) -- last: SkillServer / KillRegenServer react to this one
				bleeds[bot] = nil
				bot:SetAttribute("SkillBleedUntil", nil)
			end
		end
	end
end)

-- v1.27: Blood Siphon
if HPARTS_ON then
	local SIPHON_TICK = 0.5
	local function others()
		local list = {}
		local island = workspace:FindFirstChild("DinoIsland")
		local bots = island and island:FindFirstChild("Bots")
		if bots then for _, m in ipairs(bots:GetChildren()) do if m:IsA("Model") then table.insert(list, m) end end end
		for _, p in ipairs(Players:GetPlayers()) do if p.Character then table.insert(list, p.Character) end end
		return list
	end
	task.spawn(function()
		while true do
			task.wait(SIPHON_TICK)
			if not on() then continue end
			local t = now()
			local pool
			for char, st in pairs(chars) do
				local rate = tonumber(char:GetAttribute("SiphonRate")) or 0
				local hrp = char:FindFirstChild("HumanoidRootPart")
				if char:GetAttribute("SiphonEnabled") ~= true or rate <= 0 or not hrp or st.hum.Health <= 0 then continue end
				pool = pool or others()
				local range = (tonumber(char:GetAttribute("SiphonRange")) or 0) * char:GetScale()
				local n = 0
				st.siphonKills = st.siphonKills or setmetatable({}, {__mode = "k"})
				for _, m in ipairs(pool) do
					if m ~= char and m.Parent then
						local r = m:FindFirstChild("HumanoidRootPart")
						local pos = r and r.Position or m:GetPivot().Position
						if (pos - hrp.Position).Magnitude <= range then
							local bleeding = (tonumber(m:GetAttribute("SlashBleedUntil")) or 0) > t or (tonumber(m:GetAttribute("SkillBleedUntil")) or 0) > t
								or (HPASS3_ON and (tonumber(m:GetAttribute("CaltropBleedUntil")) or 0) > t) -- v1.30
							if bleeding and m:GetAttribute("DummyState") ~= "ko" then n += 1 end
							local kh = tonumber(char:GetAttribute("SiphonKillHeal")) or 0
							local kAt = tonumber(m:GetAttribute("KilledAt"))
							if kh > 0 and m:GetAttribute("KilledWith") == "bleed" and kAt and t - kAt <= 1.5 and st.siphonKills[m] ~= kAt then
								st.siphonKills[m] = kAt
								heal(char, st, kh * st.hum.MaxHealth, "siphonKill")
								char:SetAttribute("SiphonKillAt", t)
							end
						end
					end
				end
				if char:GetAttribute("SiphonBleeding") ~= n then char:SetAttribute("SiphonBleeding", n) end
				if n > 0 and st.hum.Health < st.hum.MaxHealth + 1e6 then
					heal(char, st, rate * n * SIPHON_TICK, "siphon")
					char:SetAttribute("SiphonHealAt", t)
				end
			end
		end
	end)
end

-- regen + shield expiry
task.spawn(function()
	while true do
		task.wait(TICK)
		local t = now()
		for char, st in pairs(chars) do
			if not char.Parent or st.hum.Health <= 0 then continue end
			local e = st.e
			local regenOn = on() and e.regenRate > 0 and st.hum.Health < st.hum.MaxHealth and t - st.lastDrop >= e.regenDelay
			if char:GetAttribute("SkillRegenActive") ~= regenOn then char:SetAttribute("SkillRegenActive", regenOn) end
			-- v1.19: heal after SkillIdleRegenDelay s without a health drop (every dino), the bigger heal wins
			local idleOn = script:GetAttribute("SkillEffectsIdleRegenEnabled") ~= false
				and st.hum.Health < st.hum.MaxHealth
				and t - st.lastDrop >= (script:GetAttribute("SkillIdleRegenDelay") or 8)
				and not (MED_ON and char:GetAttribute("MedInside") == true and (tonumber(char:GetAttribute("MedActiveUntil")) or 0) > t) -- v1.22
			if char:GetAttribute("SkillIdleRegenActive") ~= idleOn then char:SetAttribute("SkillIdleRegenActive", idleOn) end
			local idleAmt = idleOn and (script:GetAttribute("SkillIdleRegenRate") or 0.05) * st.hum.MaxHealth * TICK or 0
			local skillAmt = regenOn and e.regenRate * st.hum.MaxHealth * TICK or 0
			if idleOn and idleAmt >= skillAmt then
				heal(char, st, math.min(idleAmt, st.hum.MaxHealth - st.hum.Health), "idle")
			elseif regenOn then heal(char, st, e.regenRate * st.hum.MaxHealth * TICK, "regen") end
			local untilT = char:GetAttribute("SkillShieldUntil")
			if typeof(untilT) == "number" and t >= untilT then
				char:SetAttribute("SkillShield", 0)
				char:SetAttribute("SkillShieldUntil", nil)
			end
		end
	end
end)

local function onCharacter(player, char)
	local hum = char:WaitForChild("Humanoid", 10)
	if not hum or not char.Parent then return end
	-- bases: the character's own values, else the move scripts' defaults
	for name, default in pairs(COOLDOWNS) do
		char:SetAttribute("SkillBase_" .. name, char:GetAttribute(name) or default)
	end
	char:SetAttribute("SkillBase_KillRegenFraction", char:GetAttribute("KillRegenFraction") or KILL_REGEN_DEFAULT)
	local st = {player = player, hum = hum, e = effectsOf(player), lastDrop = -math.huge, lastHealth = hum.Health,
		writing = {}}
	chars[char] = st
	char:SetAttribute("SkillShield", 0)
	applyChar(char, st)

	hum.HealthChanged:Connect(function(h)
		if h < st.lastHealth - 1e-6 then
			st.lastDrop = now()
			local shield = char:GetAttribute("SkillShield") or 0
			if h > 0 and shield > 0 and on() then
				local back = math.min(shield, st.lastHealth - h)
				char:SetAttribute("SkillShield", round(shield - back, 0.1))
				st.lastHealth = h + back
				hum.Health = h + back
				return
			end
		end
		st.lastHealth = h
	end)
	char:GetAttributeChangedSignal("BiteHitAt"):Connect(function()
		onHit(char, st, char:GetAttribute("BiteHitDamage"), char:GetAttribute("BiteHitTarget"))
	end)
	char:GetAttributeChangedSignal("PounceBiteAt"):Connect(function()
		onHit(char, st, char:GetAttribute("PounceHitDamage"), char:GetAttribute("PounceLatchTarget"), true) -- v1.6: pounce
	end)
	if HEADBUTT_HITS then -- v1.12: pachy headbutt
		char:GetAttributeChangedSignal("HeadbuttHitAt"):Connect(function()
			onHit(char, st, char:GetAttribute("HeadbuttHitDamage"), char:GetAttribute("HeadbuttHitTarget"))
		end)
	end
	if HOOK_ON then -- v1.14: the hook smash counts as a hit (lifesteal)
		char:GetAttributeChangedSignal("HookHitAt"):Connect(function()
			onHit(char, st, char:GetAttribute("HookHitDamage"), char:GetAttribute("HookHitTarget"))
		end)
	end
	char:GetAttributeChangedSignal("BiteEnabled"):Connect(function() applyChar(char, st) end)
	if HERRERA_ON then -- v1.26
		char:GetAttributeChangedSignal("Species"):Connect(function()
			st.e = effectsOf(player)
			applyStats(player, st.e)
			applyChar(char, st)
		end)
		char:GetAttributeChangedSignal("SlashHitAt"):Connect(function() -- Blood Drinker: the slash hit
			if char:GetAttribute("Species") == "Herrera" then
				onHit(char, st, char:GetAttribute("SlashHitDamage"), char:GetAttribute("SlashHitTarget"))
			end
		end)
		char:GetAttributeChangedSignal("SlashBleedDealtAt"):Connect(function() -- Blood Drinker: the bleed ticks
			local d = char:GetAttribute("SlashBleedDealt")
			if on() and char:GetAttribute("Species") == "Herrera" and st.e.lifesteal > 0 and typeof(d) == "number" and d > 0 then
				char:SetAttribute("SkillLifestealRate", st.e.lifesteal)
				heal(char, st, st.e.lifesteal * d, "lifesteal")
			end
		end)
	end
	char:GetAttributeChangedSignal("StunnedUntil"):Connect(function()
		local untilT, t = char:GetAttribute("StunnedUntil"), now()
		if untilT == st.writing.StunnedUntil or not on() then return end
		if typeof(untilT) ~= "number" or untilT <= t then return end
		local e = st.e
		if TENO_ON and char:GetAttribute("TenoBraceNoStun") == true and (tonumber(char:GetAttribute("TenoHoldSince")) or 0) > 0 then -- v1.31: Brace II
			writeOwn(st, char, "StunnedUntil", t)
			char:SetAttribute("SkillStunTrimmed", "braced")
			return
		end
		if pachyStatsOn() and char:GetAttribute("PachyHeadDownNoStun") == true and pachyCharging(char) then -- v1.40: Head Down star
			writeOwn(st, char, "StunnedUntil", t)
			char:SetAttribute("SkillStunTrimmed", "headdown")
			return
		end
		if e.stunImmuneAbove > 0 and hum.Health > e.stunImmuneAbove * hum.MaxHealth then
			writeOwn(st, char, "StunnedUntil", t)
			char:SetAttribute("SkillStunTrimmed", "immune")
		elseif e.stunMul < 1 then
			writeOwn(st, char, "StunnedUntil", t + (untilT - t) * e.stunMul)
			char:SetAttribute("SkillStunTrimmed", "trimmed")
		end
	end)
	char:GetAttributeChangedSignal("StunTossDistance"):Connect(function()
		local d = char:GetAttribute("StunTossDistance")
		if d == st.writing.StunTossDistance or not on() or st.e.tossMul >= 1 then return end
		if typeof(d) ~= "number" then return end
		writeOwn(st, char, "StunTossDistance", d * st.e.tossMul)
		char:SetAttribute("SkillStunTrimmed", "tossTrimmed")
	end)
	char.AncestryChanged:Connect(function(_, parent)
		if not parent then chars[char] = nil end
	end)
end

local function refresh(player)
	local e = effectsOf(player)
	applyStats(player, e)
	for char, st in pairs(chars) do
		if st.player == player then
			st.e = e
			applyChar(char, st)
		end
	end
end

local function onPlayer(player)
	applyStats(player, effectsOf(player))
	player.AttributeChanged:Connect(function(name)
		if name:sub(1, 10) == "SkillPath_" or name:sub(1, 9) == "SkillSlot" then refresh(player) end -- v1.1: + SkillSlot
	end)
	player.CharacterAdded:Connect(function(char) onCharacter(player, char) end)
	if player.Character then task.spawn(onCharacter, player, player.Character) end
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do task.spawn(onPlayer, p) end

script:GetAttributeChangedSignal("SkillEffectsEnabled"):Connect(function()
	for _, p in ipairs(Players:GetPlayers()) do refresh(p) end
end)
script:GetAttributeChangedSignal("SkillEffectsDiloStatsEnabled"):Connect(function() -- v1.41
	for _, p in ipairs(Players:GetPlayers()) do refresh(p) end
end)
