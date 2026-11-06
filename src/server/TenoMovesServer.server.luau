-- TenoMovesServer v1.12 (Mecha Dino Arena) — the moves of the Tenontosaurus' mecha button parts, build 1 (attacks): Tail
-- Grab & Fling, Boulder Mortar, Stomp Shockwave, Hydraulic Leap. Plan docs/plans/TENO_ABILITIES_v1.0.md Task 5 (MDA-177,
-- deterministic map), mockup docs/mockups/teno_abilities_options.html v0.3 (Kepu 2026-11-01; Mortar "Auto-target").
-- Settings come from the character (SkillEffects 1.33, a teno with the part bought AND slotted): TenoGrab* (Enabled, Range,
--   Fling, Damage, Stun, Big, Crash, CrashRadius, Cooldown), TenoMortar* (Enabled, Range, Miss, Cone, Damage, Splash,
--   Count, SlowMul, SlowTime, Rubble, Cooldown), TenoStomp* (Enabled, Range, Damage, Stun, NoJump, Cooldown), TenoLeap*
--   (Enabled, Dist, Damage, Radius, Stun, Charges, Cooldown). Distances are world studs (the Lab texts; the mockup's world).
-- Remotes (ReplicatedStorage, created here): DinoTenoGrabRequest(stamp), DinoTenoMortarRequest(stamp, aimDir),
--   DinoTenoStompRequest(stamp), DinoTenoLeapRequest(stamp) (MechaButtons 1.26).
-- Request checks, first failing wins (character <Prefix>ServerResult + <Prefix>ServerResultAt): "badArg", "dead",
--   "disabled", "menu", "stunned", "pinned", "dazed", then leap "active" (a leap in the air), then "cooldown"; grab with no
--   target "noTarget" (no cooldown); else "ok": <Prefix>ReadyAt = now + <Prefix>Cooldown (leap: per charge, below).
-- Who can be hit / grabbed / slowed: Workspace models with a Hitboxes folder, Bitable true, a Species or IsBot, not self,
--   not KO, alive; players only where ModeRules.canAffect allows (the Arena), bots always; never a squadmate (SquadRules
--   sameChar). An Energy Shield (EnergyShieldUntil > now) blocks the damage, stun and slow of these moves and can't be
--   grabbed. Damage: base x roar debuff x daze star x Stun Breaker star off DummyHealth; a killing blow stamps KilledBy /
--   KilledByUserId / KilledWith ("tailgrab" / "mortar" / "stomp" / "leap") / KilledAt.
-- Slows (mortar, rubble): a player gets TenoSlowUntil / TenoSlowMul (SprintTest 1.18; the stronger / longer is kept); a bot's
--   WalkSpeed is scaled here (TenoAttackServer 1.3's pattern; while that script slows the same bot (its TenoSlowed true) this
--   one gives the bot back its speed and waits, so the two never multiply). Bot attribute TenoMoveSlowed.
-- Tail Grab & Fling: target = the nearest allowed dino of a grabbable size (Raptor, Herrera; TenoGrabBig: + Pachy, Teno;
--   T-Rex never), not anchored, behind or beside the hips (HRP-space Z >= 0), whose hitbox gap to the tail (Tail1..5_main
--   centres and the tip, Tail5_main * (-1.6 x scale, 0, 0)) is within TenoGrabRange. A raptor latched on the teno counts
--   and is released first (ShakeOffReason "grabbed"). GRAB_CATCH (0.3) s after the press the tail catches it; a bot rides
--   the tail tip for GRAB_CARRY (0.5) s, then flies FLING_TIME (0.9) s on an arc (peak FLING_PEAK 16) to the ground
--   TenoGrabFling studs ahead of the teno (flat facing at the throw); a player is stunned for the carry and thrown by
--   StunClient (StunTossFrom behind it, StunTossDistance to the landing). Landing: TenoGrabDamage, StunnedUntil = max(old,
--   land + TenoGrabStun); star (TenoGrabCrash > 0): every other allowed dino within TenoGrabCrashRadius of the landing takes
--   TenoGrabCrash + 1 s stun. Teno: TenoGrabTarget, TenoGrabThrowAt, TenoGrabLand, TenoGrabLandAt, TenoGrabCrashHits,
--   TenoGrabStartedAt (last); target TenoGrabbedBy / TenoGrabbedAt.
-- Boulder Mortar: aim = the flat camera heading (aimDir). Target = the nearest allowed enemy root within TenoMortarRange
--   and TenoMortarCone degrees of the aim; none -> TenoMortarMiss studs straight along the aim. Points: the target / miss
--   spot on the ground; TenoMortarCount 2 -> two points +- right x MORTAR_PAIR (4.5). MORTAR_FIRE (0.35) s after the press
--   (the tail whip) each boulder (Workspace.DinoFX.TenoMovesFX "TenoBoulder", Slate ball, no collide / query / touch) leaves
--   the catapult bucket and flies MORTAR_FLIGHT (1.3) s on an arc (peak MORTAR_PEAK 30 above the higher end). Landing: every
--   allowed dino whose root is within TenoMortarSplash (flat, 15 up / down) of a point: TenoMortarDamage once, slowed
--   TenoMortarSlowMul for TenoMortarSlowTime s. Star (TenoMortarRubble > 0): a rubble patch "TenoRubble" (radius
--   0.8 x splash) per point for TenoMortarRubble s; every 0.2 s allowed enemies inside are slowed x TenoMortarSlowMul for
--   0.3 s. Teno: TenoMortarTarget, TenoMortarLand, TenoMortarFiredAt, TenoMortarLandedAt, TenoMortarHits,
--   TenoMortarStartedAt (last).
-- Stomp Shockwave: STOMP_HIT (0.5) s after the press (the rear-up): centre = the ground under the middle of ArmL_hand /
--   ArmR_hand. Every allowed dino whose hitbox gap to the centre is within TenoStompRange (15 up / down): TenoStompDamage,
--   StunnedUntil = max(old, now + TenoStompStun); star (TenoStompNoJump > 0): NoJumpUntil = now + TenoStompNoJump (a tag;
--   no reader yet: PounceServer / JumpTest are not edited). Raptors latched on the teno: released (ShakeOffReason
--   "stomped"). Teno: TenoStompCenter, TenoStompHits, TenoStompStartedAt, TenoStompAt (last).
-- Hydraulic Leap: TenoLeapCharges charges; each used charge refills TenoLeapCooldown s after it was used (one at a time).
--   TenoLeapChargesLeft, TenoLeapRefillAt; TenoLeapReadyAt = now while a charge is left, else the next refill. ok:
--   TenoLeapDistNow = TenoLeapDist, TenoLeapFlightTime = LEAP_TIME (0.9), TenoLeapUntil = now + LEAP_TIME + 0.8,
--   TenoLeapStartedAt (last: TenoLeapLaunch 1.0 on the owner's client launches the body). Landing = the first heartbeat
--   after 0.6 x LEAP_TIME with the root back within 1.5 studs of its take-off height over the ground (the server's
--   FloorMaterial of a player-owned body is not reliable), or now + LEAP_TIME + 0.8: every allowed dino whose hitbox gap to
--   the root is within TenoLeapRadius (15 up / down): TenoLeapDamage; III (TenoLeapStun > 0): StunnedUntil = max(old, now +
--   TenoLeapStun). No tail slam charge is used. Teno: TenoLeapLandedAt, TenoLeapHits, TenoLeapUntil = 0.
-- Switches: script attributes TenoMovesServerEnabled, TenoMoves_tgrabEnabled, TenoMoves_tmortarEnabled,
--   TenoMoves_tstompEnabled, TenoMoves_tleapEnabled, TenoMovesModeRulesEnabled, TenoMovesServerSquadEnabled (default true
--   each, read at each use).
-- Diagnostics: script TenoMovesServerVersion, TenoMovesMode, TenoMovesGrabs, TenoMovesMortars, TenoMovesStomps,
--   TenoMovesLeaps, TenoMovesHits, TenoMovesSlows, TenoMovesSquadSkips; character results above.
-- v1.1 (Kepu 2026-11-02: the stomp "doesn't knock it off, it lowers the stamina for the current pounce", -50; SkillTree
--   1.52 / SkillEffects 1.35): the stomp no longer releases raptors latched on the teno (they are still not hit by the
--   shockwave). Star (TenoStompLatchDrain > 0): each allowed raptor latched on the teno gets StaminaDrainAmount =
--   TenoStompLatchDrain and StaminaDrainAt = now (StaminaServer 1.6 takes it off a player's stamina, so the latch ends
--   sooner; BotServer 1.23 cuts a bot's latch time by amount / PounceLatchDrain). NoJumpUntil is no longer written
--   (TenoStompNoJump is 0). Switch: script attribute TenoMovesStompDrainEnabled (default true, read at each stomp; false =
--   1.0: latched raptors released). Diagnostic: character TenoStompDrained (count).
-- v1.2 (Kepu 2026-11-02 after playing v334: "the tail grab does nothing, the mortar is useless it only lands directly on the
--   teno and is slow as hell"; picked "Any direction", "Crosshair + snap"):
--   * Tail Grab: the target may be in any direction: the nearest allowed grabbable dino whose hitbox gap to the teno (the
--     tail points, the root, Torso_chest, Neck_upper, Head_cranium) is within TenoGrabRange. Switch: script attribute
--     TenoMovesGrabAnyDirEnabled (default true, read at each grab; false = 1.1, behind / beside only).
--   * Boulder Mortar: DinoTenoMortarRequest(stamp, aimDir, aimPoint) - aimPoint = where the owner's crosshair ray hits
--     (MechaButtons 1.27). Landing: the flat point from the root toward aimPoint, its distance clamped to TenoMortarMin (15)
--     .. TenoMortarRange (60) (no aimPoint, or one more than 400 studs away: TenoMortarMiss along the aim); then it snaps
--     to the nearest allowed enemy root within TenoMortarSnap (8) studs flat of that spot. Faster: MORTAR_FIRE 0.35 -> 0.15
--     s, MORTAR_FLIGHT 1.3 -> 0.7 s, MORTAR_PEAK 30 -> 14 (press to impact 1.65 -> 0.85 s). Switch: script attribute
--     TenoMovesMortarAimEnabled (default true, read at each shot; false = 1.1 aim and timing). Diagnostic: character
--     TenoMortarAimMode ("crosshair" / "snap" / "auto").
-- v1.3 (build 2, plan docs/plans/TENO_ABILITIES_v1.0.md Task 6, MDA-178, deterministic map; Kepu 2026-11-02 "Next"; SkillTree
--   1.54 makes the parts live): Herd Bellow, Challenge Call, Mud Armor. Settings from the character (SkillEffects 1.33):
--   TenoBellow* (Enabled, Range, Time, DamageMul, RunMul, ClearStun, Cooldown), TenoChallenge* (Enabled, Range, Time,
--   WeakMul, SlowMul, Cooldown), TenoMud* (Enabled, Time, Hits, SlowRadius, SlowMul, SlowTime, Splash, Cooldown).
--   Remotes DinoTenoBellowRequest(stamp), DinoTenoChallengeRequest(stamp), DinoTenoMudRequest(stamp) (MechaButtons 1.26
--   entries); the same checks and results as the attacks; ok: <Prefix>ReadyAt = now + Cooldown, <Prefix>StartedAt = now
--   (poses). Timings follow the mockup v0.3: the bellow / call land BELLOW_AT / CHALLENGE_AT (0.5) s after the press; mud:
--   latched raptors slide off at MUD_SLIDE_AT (0.7) s, the coat goes on at MUD_COAT_AT (1.2) s (the end of the wallow).
--   * Herd Bellow: the teno + every player character that is its squadmate (SquadRules sameChar) whose root is within
--     TenoBellowRange (flat, 15 up / down): TenoBellowedUntil = max(old, now + TenoBellowTime) (a second bellow refreshes,
--     never stacks), TenoBellowedDamageMul = TenoBellowDamageMul, TenoBellowedRunMul = TenoBellowRunMul (SprintTest 1.19),
--     TenoBellowedBy. While TenoBellowedUntil > now, each Humanoid health drop is refunded drop x (1 - DamageMul) (a
--     killing blow is not: the Brace rule; with Brace the two refunds add up). Star (TenoBellowClearStun): StunnedUntil
--     = now on each one still stunned. Teno: TenoBellowTargets ("|"-joined names), TenoBellowCount, TenoBellowCleared,
--     TenoBellowAt (last). Diagnostic on a buffed character: TenoBellowRefunded (total).
--   * Challenge Call: every allowed enemy (players where ModeRules allows, bots; never a squadmate; not while its Energy
--     Shield is up) whose root is within TenoChallengeRange (flat, 15 up / down) gets the debuff tags TenoMarkedBy (the
--     teno's name), TenoMarkedByUserId, TenoWeakMul = min(an active one, TenoChallengeWeakMul), TenoWeakUntil = max(old,
--     now + TenoChallengeTime) (StatServer 1.2 weakens a player's attack attributes; BotServer 1.24 weakens a bot's hits
--     and sends it at TenoMarkedBy). Star (TenoChallengeSlowMul < 1): slowed x TenoChallengeSlowMul for the mark time.
--     Teno: TenoChallengeTargets, TenoChallengeHits, TenoChallengeAt (last).
--   * Mud Armor: raptors latched on the teno released (ShakeOffReason "mud"); then a hidden ForceField "TenoMudShield"
--     (Visible false) under the character blocks every Humanoid:TakeDamage (bot bites, the ArenaPvP bridge, Screech) for
--     TenoMudTime s or TenoMudHits blocks, whichever first. A block = a new LastHitAt or ArenaPvPLastDelta write on the
--     teno (at most one per MUD_BLOCK_GAP 0.15 s): TenoMudHitsLeft - 1, TenoMudBlocks + 1, TenoMudBlockAt, and every
--     allowed enemy within TenoMudSlowRadius is slowed x TenoMudSlowMul for TenoMudSlowTime s. End ("hits" / "time" /
--     "dead" / "disabled"): the ForceField is destroyed, TenoMudHitsLeft 0, TenoMudEndReason, TenoMudEndedAt (last);
--     star (TenoMudSplash > 0, not "dead"): every allowed enemy within TenoMudSplash is slowed the same way,
--     TenoMudSplashHits, TenoMudSplashAt. Teno while on: TenoMudUntil, TenoMudHitsLeft, TenoMudCoatAt (last).
--   Switches: script attributes TenoMoves_tbellowEnabled, TenoMoves_tchallengeEnabled, TenoMoves_tmudEnabled (default true
--   each, read at each use). Diagnostics: script TenoMovesBellows, TenoMovesChallenges, TenoMovesMuds, TenoMovesMudBlocks.
-- v1.4 (Kepu 2026-11-02 16:43: Hydraulic Leap fires through JUMP like the pachy's Mecha Legs, 2 charges; SkillEffects 1.37
--   sets TenoLeapOnJump, JumpServer 1.3 owns the charges): while the character's TenoLeapOnJump is true:
--   * DinoTenoLeapRequest is refused ("onJump", TenoLeapServerResult); the slot key no longer leaps (MechaButtons 1.28).
--   * Each new JumpStartedAt (an accepted JUMP leap) with TenoLeapEnabled: TenoLeapUntil = start + 3, TenoLeapHits 0; the
--     root must rise 2 studs above its standing height, then the landing = the first heartbeat back within 1.5 studs (or
--     3 s): the same slam as 1.0 (TenoLeapDamage to every allowed dino within TenoLeapRadius, 15 up / down; III stun
--     TenoLeapStun), TenoLeapHits, TenoLeapUntil 0, TenoLeapLandedAt (last: FX + TenoPose 1.7 landing pose). Never left the
--     ground: TenoLeapUntil 0, no slam.
--   * TenoLeapChargesLeft / TenoLeapRefillAt / TenoLeapReadyAt mirror JumpChargesLeft / JumpChargeRefillAt (ReadyAt = now
--     while a charge is left, else the refill), so the slot tile and phone button show the jump's charges.
--   Switch: script attribute TenoMovesLeapOnJumpEnabled (default true, read at each use; false = 1.3). Diagnostic: script
--   TenoMovesJumpLeaps.
-- v1.6 (MDA-200, plan docs/plans/THERIZINO_KIT_v1.0.md Task 3b; Kepu 2026-11-02 landing "Front only"): the JUMP landing slam
--   (1.4) counts a target only when the flat angle between the root's facing and the target's root is <= TenoLeapArc / 2
--   (character attribute; TherizinoModelData 1.3 sets 180 = the front half). No TenoLeapArc (every teno) = all around, as
--   1.4. Switch: script attribute TenoMovesLeapArcEnabled (default true, read at each landing; false = 1.5). Diagnostic:
--   character TenoLeapArcSkips (targets in the radius left out by the arc at the last landing).
-- v1.5 (Kepu 2026-11-02 17:29: "the mortar animation and range needs to be beefed up" -> range 90 (SkillTree 1.56), "Big
--   wind-up + whip"; "the shield takes way too long to actually appear on screen"):
--   * Boulder Mortar: the boulder leaves MORTAR_FIRE3 (0.55) s after the press (TenoPose 1.8's 0.5 s wind-up, then the whip),
--     was 0.15. Shots past 60 studs fly longer and higher: flight 0.7 + 0.3 x k s, peak 14 + 8 x k studs, k = (distance - 60)
--     / 30 clamped 0..1 (90 studs: 1.0 s, 22). Switch: script attribute TenoMovesMortarBigEnabled (default true, read at each
--     shot; false = 1.4 timing).
--   * Shield Armor: the shield (ForceField + TenoMudCoatAt) goes on TenoMovesShieldCoatAt (default 0.2) s after the press,
--     was MUD_COAT_AT 1.2 (the old mud wallow). Latched raptors are still knocked off at MUD_SLIDE_AT 0.7. Switch: script
--     attribute TenoMovesShieldFastEnabled (default true, read at each press; false = 1.2 s).
-- v1.7 (MDA-216, plan docs/plans/TENO_TAIL_GRAB_v1.0.md Task 2, mockup docs/mockups/teno_tail_grab_v0.1.html; Kepu
--   2026-11-03 "have the tail actually grab the Dino and throw it ... If the Dino is in front ... Same for behind", picked A
--   "Over the Top"): Tail Grab & Fling, same target rules / numbers, new timeline, nothing stepped by the server:
--   * side = "front" when the target's root is ahead of the teno's root (HRP space Z < 0), else "back". From the press t:
--     front catch t + 0.70, throw t + 1.35; back catch t + 0.45, throw t + 1.10; flight OT_FLIGHT 0.85 s.
--   * stamps (teno): ObjectValue child TenoGrabTargetRef = the target, TenoGrabSide, TenoGrabCatchAt, TenoGrabThrowAtPlan,
--     TenoGrabFlight, TenoGrabTarget, TenoGrabCrashHits 0, TenoGrabStartedAt last (IdleAnimation 1.41 aims the tail;
--     TenoBotMotion 1.0 draws the bot). TenoGrabLand (the ground point) + TenoGrabLandLift are stamped OT_LAND_LEAD (0.15) s
--     before the throw; TenoGrabThrowAt at the throw; TenoGrabLandAt at the landing (as 1.6).
--   * landing point (flat facing at OT_LAND_LEAD before the throw): front -> root - fwd x TenoGrabFling (thrown out behind),
--     back -> root + fwd x TenoGrabFling (thrown out ahead). Height: the target's root height over the ground (as 1.6).
--   * a bot: TenoGrabHeldUntil = landing + 0.05 (BotServer 1.25 holds it), Bitable false while held, stunned to landing +
--     TenoGrabStun, anchored at the press (a raptor latched on the teno: at the catch, after its release) and never moved by
--     this script until the landing: then its root is put at the landing point facing away from the teno, Bitable restored,
--     TenoGrabDamage + the crash (as 1.6). Cancelled (teno or target gone): hold cleared, Bitable restored, unanchored.
--   * a player: stunned from the catch (StunClient's toss must come within 1 s of the stun start) and thrown by StunClient
--     at the throw toward the landing point (StunTossFrom / StunTossDistance / StunTossAt, as 1.6).
--   Switch: script attribute TenoMovesGrabOverTopEnabled (default true, read at each grab; false = 1.6). Diagnostics: script
--   TenoMovesGrabsFront, TenoMovesGrabsBack; teno TenoGrabSide.
-- v1.7 (MDA-219, plan Task 5; Kepu picked L1 "Shove Clear"): the JUMP leap's landing slam (1.4 path, every jumper that uses
--   it) when it comes down on a dino:
--   * landed also when, after the take-off, a ray straight down from the root or the Torso_chest part (h0 + 2 studs long;
--     only the jumper, TallGrass and the FX folders left out) hits an allowed target while the root is not going up: the
--     jumper stands on a dino. 1.6 only counted the ground (Bots and players left out), so it stood on the dino's back with
--     no slam until it slid off. The ray also looks LEAP_LOOKAHEAD (0.15) s of the fall ahead (+ falling speed x 0.15), so
--     the slam and the shove start just before the feet touch the dino. Switch: script attribute TenoMovesLeapOnDinoEnabled
--     (default true, read at each leap). On a dino the slam's reach is measured from where the root will stand on it (the
--     ray's hit + h0) and the dino under it is always hit. Diagnostic: character TenoLeapLandedOn ("ground" / "dino").
--   * shove: each target hit by the slam whose root lies under the jumper's body (root space: |X| < half the jumper's width +
--     half the target's width along it, |Z| < half the jumper's length) is moved sideways to the nearer side (root-space X sign,
--     0 -> right) until its near edge is LEAP_SHOVE_GAP (1.5) studs past the body. A bot: TenoGrabHeldUntil = now +
--     LEAP_SHOVE_TIME + 0.05 (BotServer 1.25 holds it), anchored, TenoMoveFrom / TenoMoveTo / TenoMoveTime (LEAP_SHOVE_TIME
--     0.28) / TenoMovePeak (3) then TenoMoveAt last (TenoBotMotion 1.0 draws the slide), its root put at TenoMoveTo after
--     LEAP_SHOVE_TIME (unanchored when it is not stunned). A player (only with a stun, TenoLeapStun > 0): StunTossFrom /
--     StunTossDistance / StunTossAt set before the stun, so StunClient tosses it sideways. Switch: script attribute
--     TenoMovesLeapShoveEnabled (default true, read at each landing). Diagnostic: character TenoLeapShoves.
-- v1.8 (therizino Deflector Claws, MDA-247, plan docs/plans/THERIZINO_PARTS_v1.0.md Task 7; Kepu "Yes, in build 2"): a mortar
--   boulder landing on a dino asks DeflectRules 1.0 (kind "boulder", from the teno's root) before its damage / slow; blocked
--   = nothing for that dino; reflect (the star) = the boulder's damage to the teno instead (KilledWith "deflect"). Switch:
--   script attribute TenoMovesDeflectEnabled (default true, read at each landing; false = 1.7).
-- v1.9 (MDA-276, plan docs/plans/TENO_PARTS_LOOKS_v2.0.md Task 4; Kepu 2026-11-05 picked the Back Cannon look): at the shot,
--   when the character's TPart_tmortar holds a part with TPartRole "muzzle" (TenoPartsServer 1.3), the boulders start at
--   that part's position (the cannon's barrel tip) instead of Tail3_main's bucket. No muzzle = 1.8. Switch: script attribute
--   TenoMovesMortarMuzzleEnabled (default true, read at each shot; false = 1.8).
-- v1.10 (MDA-278, plan docs/plans/TENO_GRAB_SCORPION_v1.0.md Task 1, mockup docs/mockups/teno_moves_anim.html v0.1; Kepu
--   2026-11-05 18:10 picked A "Scorpion Strike", fling kept 45): the Over-the-Top grab (1.7) on the Scorpion timeline. From
--   the press t: front catch t + 0.55, throw t + 1.15; back catch t + 0.40, throw t + 1.00 (SC_TIMES); flight SC_FLIGHT 0.6.
--   Stamps before TenoGrabStartedAt: TenoGrabStyle "scorpion" and TenoGrabFlightPeak SC_PEAK (8 studs; TenoBotMotion 1.3
--   arcs the thrown bot with it). Landing point, fling, damage, stun, crash unchanged. Switch: script attribute
--   TenoMovesGrabScorpionEnabled (default true, read at each grab; false = 1.9: OT_TIMES, OT_FLIGHT, TenoGrabStyle
--   "overtop", TenoGrabFlightPeak nil). Diagnostic: script TenoMovesGrabsScorpion.
-- v1.11 (MDA-282, plan docs/plans/TENO_MOVES_ANIM_v1.0.md Task 1, mockup docs/mockups/teno_moves_anim.html v0.2; Kepu
--   2026-11-05 18:47 picked Mortar A "Anchored Shot", Stomp A "Quake Smash", Challenge A "Watcher Alarm"):
--   * Boulder Mortar: the boulder leaves MORTAR_FIRE_A (0.70) s after the press (TenoPose 1.12's brace + aim + charge), was
--     MORTAR_FIRE3 0.55. Switch: script attribute TenoMovesMortarAnchorEnabled (default true, read at each shot).
--   * Stomp Shockwave: the hit (TenoStompAt) comes STOMP_HIT_A (0.60) s after the press (the higher rear + hang), was
--     STOMP_HIT 0.5. Switch: script attribute TenoMovesStompQuakeEnabled (default true, read at each stomp).
--   * Challenge Call: at the press, TenoChallengeAimYaw = the flat yaw in degrees from the teno's facing to the nearest
--     candidate within TenoChallengeRange (15 up / down), + toward the root's +X side, clamped to +-40; 0 when none.
--     Stamped before TenoChallengeStartedAt (TenoPose 1.12 snaps the head to it, TenoMovesFX 1.7 sweeps the scan cone).
--     Switch: script attribute TenoMovesChallengeAimEnabled (default true; false = no stamp).
-- v1.12 (MDA-325, plan docs/plans/FIXES_2026-11-06_v1.0.md Fix 3, mockup docs/mockups/teno_grab_attack_options.html v0.1;
--   Kepu 2026-11-06 "A" Back Pluck + red-team "Bots and players"): a Tail Grab on a raptor latched on this teno plays the back
--   timeline (side "back": catch t + 0.40, throw t + 1.00) and, before ShakeOffAt, stamps on the target TenoGrabPluckAt = the
--   catch time. BotServer 1.26 / PounceServer 1.14 keep the raptor riding at its latch point until then (no leap-off), so the
--   Scorpion strike (TenoPose 1.11 aims at the target's live box) clamps it where it clings. Unlatched targets unchanged.
--   Switch: script attribute TenoGrabPluckEnabled (default true, read at each grab; false = 1.11). Diagnostic: script
--   TenoMovesGrabsPluck.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local VERSION = "1.3"
VERSION = "1.4" -- v1.4 leap on JUMP
VERSION = "1.5" -- v1.5 mortar wind-up + 90 studs, shield at 0.2 s
VERSION = "1.6" -- v1.6 TenoLeapArc (front-only landing)
VERSION = "1.7" -- v1.7 Over-the-Top grab, leap landing on dinos + shove
VERSION = "1.8" -- v1.8 Deflector Claws (mortar)
VERSION = "1.9" -- v1.9 boulder from the cannon muzzle
VERSION = "1.10" -- v1.10 Scorpion Strike grab timeline
VERSION = "1.11" -- v1.11 animation pass timings (mortar 0.70, stomp 0.60, challenge aim)
VERSION = "1.12" -- v1.12 Back Pluck on a latched raptor
if script:GetAttribute("TenoGrabPluckEnabled") == nil then script:SetAttribute("TenoGrabPluckEnabled", true) end -- v1.12
if script:GetAttribute("TenoMovesMortarMuzzleEnabled") == nil then script:SetAttribute("TenoMovesMortarMuzzleEnabled", true) end -- v1.9
local GRAB_CATCH, GRAB_CARRY, FLING_TIME, FLING_PEAK = 0.3, 0.5, 0.9, 16
local MORTAR_FIRE, MORTAR_FLIGHT, MORTAR_PEAK, MORTAR_PAIR = 0.35, 1.3, 30, 4.5
local MORTAR_FIRE2, MORTAR_FLIGHT2, MORTAR_PEAK2 = 0.15, 0.7, 14 -- v1.2
local STOMP_HIT = 0.5
local BELLOW_AT, CHALLENGE_AT, MUD_SLIDE_AT, MUD_COAT_AT, MUD_BLOCK_GAP = 0.5, 0.5, 0.7, 1.2, 0.15 -- v1.3
local LEAP_TIME = 0.9
local MORTAR_FIRE3 = 0.55 -- v1.5
if script:GetAttribute("TenoMovesMortarBigEnabled") == nil then script:SetAttribute("TenoMovesMortarBigEnabled", true) end -- v1.5
if script:GetAttribute("TenoMovesShieldFastEnabled") == nil then script:SetAttribute("TenoMovesShieldFastEnabled", true) end -- v1.5
if script:GetAttribute("TenoMovesShieldCoatAt") == nil then script:SetAttribute("TenoMovesShieldCoatAt", 0.2) end -- v1.5
local DY = 15
local OT_TIMES = {front = {catch = 0.70, throw = 1.35}, back = {catch = 0.45, throw = 1.10}} -- v1.7
local OT_FLIGHT, OT_LAND_LEAD = 0.85, 0.15 -- v1.7
local SC_TIMES = {front = {catch = 0.55, throw = 1.15}, back = {catch = 0.40, throw = 1.00}} -- v1.10
local SC_FLIGHT, SC_PEAK = 0.6, 8 -- v1.10
local MORTAR_FIRE_A, STOMP_HIT_A, CHALLENGE_AIM_MAX = 0.70, 0.60, 40 -- v1.11
for _, k in ipairs({"TenoMovesMortarAnchorEnabled", "TenoMovesStompQuakeEnabled", "TenoMovesChallengeAimEnabled"}) do -- v1.11
	if script:GetAttribute(k) == nil then script:SetAttribute(k, true) end
end
if script:GetAttribute("TenoMovesGrabScorpionEnabled") == nil then script:SetAttribute("TenoMovesGrabScorpionEnabled", true) end -- v1.10
if script:GetAttribute("TenoMovesGrabOverTopEnabled") == nil then script:SetAttribute("TenoMovesGrabOverTopEnabled", true) end -- v1.7
for _, k in ipairs({"TenoMovesLeapOnDinoEnabled", "TenoMovesLeapShoveEnabled"}) do -- v1.7
	if script:GetAttribute(k) == nil then script:SetAttribute(k, true) end
end
local LEAP_SHOVE_TIME, LEAP_SHOVE_PEAK, LEAP_SHOVE_GAP = 0.28, 3, 1.5 -- v1.7
local LEAP_LOOKAHEAD = 0.15 -- v1.7

script:SetAttribute("TenoMovesServerVersion", VERSION)
if script:GetAttribute("TenoMovesStompDrainEnabled") == nil then script:SetAttribute("TenoMovesStompDrainEnabled", true) end -- v1.1
for _, k in ipairs({"TenoMoves_tbellowEnabled", "TenoMoves_tchallengeEnabled", "TenoMoves_tmudEnabled"}) do -- v1.3
	if script:GetAttribute(k) == nil then script:SetAttribute(k, true) end
end
for _, k in ipairs({"TenoMovesGrabAnyDirEnabled", "TenoMovesMortarAimEnabled"}) do -- v1.2
	if script:GetAttribute(k) == nil then script:SetAttribute(k, true) end
end
for _, k in ipairs({"TenoMovesServerEnabled", "TenoMoves_tgrabEnabled", "TenoMoves_tmortarEnabled", "TenoMoves_tstompEnabled",
	"TenoMoves_tleapEnabled", "TenoMovesModeRulesEnabled", "TenoMovesServerSquadEnabled"}) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, true) end
end
local function on(id)
	return script:GetAttribute("TenoMovesServerEnabled") ~= false and script:GetAttribute("TenoMoves_" .. id .. "Enabled") ~= false
end
local function now() return workspace:GetServerTimeNow() end
local function count(k, n) script:SetAttribute(k, (script:GetAttribute(k) or 0) + (n or 1)) end
local function num(m, k, d) return tonumber(m:GetAttribute(k)) or d end
local function flat(v) return Vector3.new(v.X, 0, v.Z) end
local function rootOf(m) return m:FindFirstChild("HumanoidRootPart") end

local ModeRules = require(ServerStorage:WaitForChild("DinoArcade"):WaitForChild("ModeRules"))
local MODE = ModeRules.currentMode()
script:SetAttribute("TenoMovesMode", MODE)
local squadMod
local function squadmate(a, b)
	if script:GetAttribute("TenoMovesServerSquadEnabled") == false then return false end
	if not squadMod then
		local arc = ServerStorage:FindFirstChild("DinoArcade")
		local m = arc and arc:FindFirstChild("SquadRules")
		if not m then return false end
		local ok, mod = pcall(require, m)
		if not ok then return false end
		squadMod = mod
	end
	if squadMod.sameChar(a, b) then
		count("TenoMovesSquadSkips")
		return true
	end
	return false
end
local function mayAffect(source, target)
	if squadmate(source, target) then return false end
	if script:GetAttribute("TenoMovesModeRulesEnabled") == false then return true end
	local tpl = Players:GetPlayerFromCharacter(target)
	local spl = Players:GetPlayerFromCharacter(source)
	local inMenu = tpl ~= nil and tpl:GetAttribute("InMenu") == true
	return ModeRules.canAffect(spl ~= nil, tpl ~= nil, inMenu, MODE)
end

local function remote(name)
	local r = ReplicatedStorage:FindFirstChild(name)
	if not r then
		r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = ReplicatedStorage
	end
	return r
end
local grabRemote, mortarRemote = remote("DinoTenoGrabRequest"), remote("DinoTenoMortarRequest")
local stompRemote, leapRemote = remote("DinoTenoStompRequest"), remote("DinoTenoLeapRequest")

-- targets ------------------------------------------------------------------------------------------------------------------
local function isTarget(m, self)
	if not (m:IsA("Model") and m ~= self and m:IsDescendantOf(workspace)) then return false end
	if not m:FindFirstChild("Hitboxes") or m:GetAttribute("Bitable") ~= true then return false end
	if m:GetAttribute("Species") == nil and m:GetAttribute("IsBot") ~= true then return false end
	if m:GetAttribute("DummyState") == "ko" then return false end
	local hum = m:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health <= 0 then return false end
	return rootOf(m) ~= nil
end
local function bots()
	local isl = workspace:FindFirstChild("DinoIsland")
	local f = isl and isl:FindFirstChild("Bots")
	return f and f:GetChildren() or {}
end
local function candidates(self)
	local list = {}
	for _, pl in ipairs(Players:GetPlayers()) do
		local c = pl.Character
		if c and isTarget(c, self) and mayAffect(self, c) then table.insert(list, c) end
	end
	for _, b in ipairs(bots()) do
		if isTarget(b, self) and mayAffect(self, b) then table.insert(list, b) end
	end
	return list
end
local function gap(m, pos) -- nearest distance from a point to the target's hitboxes
	local best = math.huge
	local hb = m:FindFirstChild("Hitboxes")
	for _, p in ipairs(hb and hb:GetChildren() or {}) do
		if p:IsA("BasePart") then
			local lp = p.CFrame:PointToObjectSpace(pos)
			local h = p.Size / 2
			local c = Vector3.new(math.clamp(lp.X, -h.X, h.X), math.clamp(lp.Y, -h.Y, h.Y), math.clamp(lp.Z, -h.Z, h.Z))
			best = math.min(best, (lp - c).Magnitude)
		end
	end
	if best == math.huge then
		local r = rootOf(m)
		best = r and (r.Position - pos).Magnitude or math.huge
	end
	return best
end
local function shielded(m, t) return num(m, "EnergyShieldUntil", 0) > t end
local function takenMul(m, t)
	local mul = 1
	local u, dm = m:GetAttribute("DebuffUntil"), m:GetAttribute("DebuffDamageTakenMul")
	if typeof(u) == "number" and typeof(dm) == "number" and t < u then mul = dm end
	if num(m, "DazedUntil", 0) > t then mul *= math.max(1, num(m, "DazedDamageMul", 1)) end
	if num(m, "StunBreakImmuneUntil", 0) > t then mul = 0 end
	return mul
end
local function damage(char, player, m, base, with, t)
	if shielded(m, t) then return 0 end
	local d = math.max(0, base) * takenMul(m, t)
	local hp = m:GetAttribute("DummyHealth")
	if typeof(hp) ~= "number" or d <= 0 then return 0 end
	local after = math.max(0, hp - d)
	m:SetAttribute("DummyHealth", after)
	if hp > 0 and after <= 0 then
		m:SetAttribute("KilledBy", char.Name)
		m:SetAttribute("KilledByUserId", player.UserId)
		m:SetAttribute("KilledWith", with)
		m:SetAttribute("KilledAt", t) -- last: KillRegenServer / TenoStatsServer react to this one
	end
	count("TenoMovesHits")
	return d
end
local function stun(m, untilT)
	m:SetAttribute("StunnedUntil", math.max(num(m, "StunnedUntil", 0), untilT))
end
local function latchedOnMe(m, char)
	if m:GetAttribute("PounceLatched") ~= true or m:GetAttribute("PounceMode") == "pin" then return false end
	local v = m:FindFirstChild("PounceLatchPart")
	return v and v:IsA("ObjectValue") and v.Value ~= nil and v.Value:IsDescendantOf(char) or false
end
local function latchedOnes(char)
	local out = {}
	local all = {}
	for _, pl in ipairs(Players:GetPlayers()) do if pl.Character then table.insert(all, pl.Character) end end
	for _, b in ipairs(bots()) do table.insert(all, b) end
	for _, m in ipairs(all) do
		if m ~= char and latchedOnMe(m, char) and mayAffect(char, m) then table.insert(out, m) end
	end
	return out
end

-- ground ---------------------------------------------------------------------------------------------------------------------
local fxFolder
local function fx()
	local root = workspace:FindFirstChild("DinoFX")
	if not root then
		root = Instance.new("Folder")
		root.Name = "DinoFX"
		root.Parent = workspace
	end
	if not (fxFolder and fxFolder.Parent) then
		fxFolder = root:FindFirstChild("TenoMovesFX") or Instance.new("Folder")
		fxFolder.Name = "TenoMovesFX"
		fxFolder.Parent = root
	end
	return fxFolder
end
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
local function groundY(pos, fallback)
	local ex = {}
	for _, pl in ipairs(Players:GetPlayers()) do if pl.Character then table.insert(ex, pl.Character) end end
	local isl = workspace:FindFirstChild("DinoIsland")
	for _, n in ipairs({"Bots", "TallGrass"}) do
		local f = isl and isl:FindFirstChild(n)
		if f then table.insert(ex, f) end
	end
	for _, n in ipairs({"DinoFX_Local", "DinoFX", "TenoFX"}) do
		local f = workspace:FindFirstChild(n)
		if f then table.insert(ex, f) end
	end
	rayParams.FilterDescendantsInstances = ex
	local g = workspace:Raycast(Vector3.new(pos.X, pos.Y + 60, pos.Z), Vector3.new(0, -200, 0), rayParams)
	return g and g.Position.Y or fallback
end
local function onGround(p) return Vector3.new(p.X, groundY(p, p.Y), p.Z) end

-- slows -----------------------------------------------------------------------------------------------------------------------
local botSlow = {} -- [model] = {hum, untilT, mul, base, set, yielded}
local function slow(m, mul, untilT, t)
	if not (mul and mul < 1 and untilT and untilT > t) or shielded(m, t) then return end
	count("TenoMovesSlows")
	if Players:GetPlayerFromCharacter(m) then
		local cu, cm = num(m, "TenoSlowUntil", 0), num(m, "TenoSlowMul", 1)
		if cu <= t then cm = 1 end
		m:SetAttribute("TenoSlowMul", math.min(cm, mul))
		m:SetAttribute("TenoSlowUntil", math.max(cu, untilT))
		return
	end
	local hum = m:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	local e = botSlow[m]
	if e then
		e.untilT, e.mul = math.max(e.untilT, untilT), math.min(e.mul, mul)
	else
		botSlow[m] = {hum = hum, untilT = untilT, mul = mul}
	end
end
RunService.Stepped:Connect(function()
	local t = now()
	for m, e in pairs(botSlow) do
		local hum = e.hum
		if not m.Parent or not hum.Parent then
			botSlow[m] = nil
		elseif m:GetAttribute("TenoSlowed") == true then -- TenoAttackServer is slowing it: give the speed back and wait
			if e.set ~= nil and e.base and math.abs(hum.WalkSpeed - e.set) <= 1e-3 then hum.WalkSpeed = e.base end
			e.set = nil
			if t >= e.untilT then
				botSlow[m] = nil
				m:SetAttribute("TenoMoveSlowed", false)
			end
		else
			local cur = hum.WalkSpeed
			if e.set == nil or math.abs(cur - e.set) > 1e-3 then e.base = cur end
			if t < e.untilT then
				e.set = e.base * math.clamp(e.mul, 0.05, 1)
				hum.WalkSpeed = e.set
				if m:GetAttribute("TenoMoveSlowed") ~= true then m:SetAttribute("TenoMoveSlowed", true) end
			else
				hum.WalkSpeed = e.base
				m:SetAttribute("TenoMoveSlowed", false)
				botSlow[m] = nil
			end
		end
	end
end)

-- request checks ----------------------------------------------------------------------------------------------------------------
local leapState = {} -- [char] = {charges, max, refills = {times}}
local function check(player, stamp, id, prefix, opts)
	local char = player.Character
	if not char then return nil end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local t = now()
	local r
	if typeof(stamp) ~= "number" or stamp ~= stamp or (opts.aim and (typeof(opts.aimDir) ~= "Vector3" or opts.aimDir.Magnitude < 0.5
		or opts.aimDir.Magnitude > 1.5)) then
		r = "badArg"
	elseif not hum or hum.Health <= 0 or not rootOf(char) then
		r = "dead"
	elseif not on(id) or char:GetAttribute(prefix .. "Enabled") ~= true then
		r = "disabled"
	elseif player:GetAttribute("InMenu") == true then
		r = "menu"
	elseif num(char, "StunnedUntil", 0) > t then
		r = "stunned"
	elseif char:GetAttribute("PinHeld") == true then
		r = "pinned"
	elseif num(char, "DazedUntil", 0) > t then
		r = "dazed"
	elseif opts.leap and num(char, "TenoLeapUntil", 0) > t then
		r = "active"
	end
	if not r and t < num(char, prefix .. "ReadyAt", 0) then r = "cooldown" end
	if r then
		char:SetAttribute(prefix .. "ServerResult", r)
		char:SetAttribute(prefix .. "ServerResultAt", t)
		return nil
	end
	return char, t
end
local function ok(char, prefix, t, setCooldown)
	char:SetAttribute(prefix .. "ServerResult", "ok")
	char:SetAttribute(prefix .. "ServerResultAt", t)
	if setCooldown ~= false then char:SetAttribute(prefix .. "ReadyAt", t + math.max(0.5, num(char, prefix .. "Cooldown", 15))) end
end

-- v1.8: Deflector Claws
if script:GetAttribute("TenoMovesDeflectEnabled") == nil then script:SetAttribute("TenoMovesDeflectEnabled", true) end
local deflectMod -- DeflectRules 1.0 (ServerStorage.DinoArcade), loaded on first use
local function deflected(target, fromPos, kind, t, switch)
	if script:GetAttribute(switch) == false then return false, false end
	if deflectMod == nil then
		deflectMod = false
		pcall(function()
			local arc = game:GetService("ServerStorage"):FindFirstChild("DinoArcade")
			local m = arc and arc:FindFirstChild("DeflectRules")
			if m then deflectMod = require(m) end
		end)
	end
	if not deflectMod then return false, false end
	return deflectMod.check(target, fromPos, kind, t)
end

-- Tail Grab & Fling ---------------------------------------------------------------------------------------------------------------
local SMALL = {Raptor = true, Herrera = true}
local BIG = {Pachy = true, Teno = true}
local function speciesOf(m) return m:GetAttribute("Species") or m:GetAttribute("BotSpecies") end
local function tailPoints(char)
	local sc = char:GetScale()
	local pts = {}
	for i = 1, 5 do
		local p = char:FindFirstChild("Tail" .. i .. "_main", true)
		if p and p:IsA("BasePart") then table.insert(pts, p.Position) end
	end
	local tip = char:FindFirstChild("Tail5_main", true)
	if tip and tip:IsA("BasePart") then table.insert(pts, (tip.CFrame * CFrame.new(-1.6 * sc, 0, 0)).Position) end
	return pts, tip
end
local function pickGrab(char, t)
	local root = rootOf(char)
	local range = num(char, "TenoGrabRange", 0)
	local big = char:GetAttribute("TenoGrabBig") == true
	local pts = tailPoints(char)
	local anyDir = script:GetAttribute("TenoMovesGrabAnyDirEnabled") ~= false -- v1.2
	if anyDir then
		table.insert(pts, root.Position)
		for _, n in ipairs({"Torso_chest", "Neck_upper", "Head_cranium"}) do
			local p = char:FindFirstChild(n, true)
			if p and p:IsA("BasePart") then table.insert(pts, p.Position) end
		end
	end
	local best, bestD
	local pool = candidates(char)
	for _, m in ipairs(pool) do
		local sp = speciesOf(m)
		local mr = rootOf(m)
		local okSize = SMALL[sp] or (big and BIG[sp])
		if okSize and not shielded(m, t) and (not mr.Anchored or latchedOnMe(m, char)) then
			local lp = root.CFrame:PointToObjectSpace(mr.Position)
			if anyDir or lp.Z >= 0 or latchedOnMe(m, char) then -- behind or beside the hips (v1.2: any direction)
				local d = math.huge
				for _, p in ipairs(pts) do d = math.min(d, gap(m, p)) end
				if d <= range and (not bestD or d < bestD) then best, bestD = m, d end
			end
		end
	end
	return best
end
local function flyBot(m, hrp, from, to, dur, peak, rot)
	local t0 = os.clock()
	while m.Parent and hrp.Parent do
		local u = math.min(1, (os.clock() - t0) / dur)
		local pos = from:Lerp(to, u) + Vector3.new(0, 4 * peak * u * (1 - u), 0)
		hrp.CFrame = CFrame.new(pos) * rot * CFrame.Angles(2 * math.pi * u, 0, 0)
		if u >= 1 then break end
		RunService.Heartbeat:Wait()
	end
end
-- v1.7: Over-the-Top grab (see the header)
local function grabOverTop(char, player, target, t, fling, dmg, stunT, crash, crashR)
	local root, hrp0 = rootOf(char), rootOf(target)
	local side = root.CFrame:PointToObjectSpace(hrp0.Position).Z < 0 and "front" or "back"
	local pluck = script:GetAttribute("TenoGrabPluckEnabled") ~= false and latchedOnMe(target, char) -- v1.12
	if pluck then side = "back" end -- v1.12: the tail comes over the back to where it clings
	local scorpion = script:GetAttribute("TenoMovesGrabScorpionEnabled") ~= false -- v1.10
	local tm = scorpion and SC_TIMES[side] or OT_TIMES[side]
	local flightT = scorpion and SC_FLIGHT or OT_FLIGHT
	local catchAt, throwAt = t + tm.catch, t + tm.throw
	local landAt = throwAt + flightT
	if scorpion then count("TenoMovesGrabsScorpion") end
	count(side == "front" and "TenoMovesGrabsFront" or "TenoMovesGrabsBack")
	local isPlayer = Players:GetPlayerFromCharacter(target) ~= nil
	local latched = latchedOnMe(target, char)
	local ref = char:FindFirstChild("TenoGrabTargetRef")
	if not (ref and ref:IsA("ObjectValue")) then
		ref = Instance.new("ObjectValue")
		ref.Name = "TenoGrabTargetRef"
		ref.Parent = char
	end
	ref.Value = target
	char:SetAttribute("TenoGrabSide", side)
	char:SetAttribute("TenoGrabCatchAt", catchAt)
	char:SetAttribute("TenoGrabThrowAtPlan", throwAt)
	char:SetAttribute("TenoGrabFlight", flightT) -- v1.10 (was OT_FLIGHT)
	char:SetAttribute("TenoGrabStyle", scorpion and "scorpion" or "overtop") -- v1.10
	char:SetAttribute("TenoGrabFlightPeak", scorpion and SC_PEAK or nil) -- v1.10
	char:SetAttribute("TenoGrabTarget", target.Name)
	char:SetAttribute("TenoGrabCrashHits", 0)
	char:SetAttribute("TenoGrabStartedAt", t) -- last: poses / bot motion / FX
	target:SetAttribute("TenoGrabbedBy", char.Name)
	target:SetAttribute("TenoGrabbedAt", t)
	if latched then
		if pluck then -- v1.12: ride until the clamp
			target:SetAttribute("TenoGrabPluckAt", catchAt)
			count("TenoMovesGrabsPluck")
		end
		target:SetAttribute("ShakeOffReason", "grabbed")
		target:SetAttribute("ShakeOffAt", t) -- last: PounceServer / BotServer release the latch
	end
	local lift = math.clamp(hrp0.Position.Y - groundY(hrp0.Position, hrp0.Position.Y - 3), 1, 12)
	local bitable = target:GetAttribute("Bitable")
	if not isPlayer then
		target:SetAttribute("TenoGrabHeldUntil", landAt + 0.05) -- before the stun: BotServer 1.25 holds instead of lying down
		target:SetAttribute("Bitable", false)
		stun(target, landAt + stunT)
		if not latched then hrp0.Anchored = true end
	end
	local function cancel()
		if isPlayer or not target.Parent then return end
		target:SetAttribute("TenoGrabHeldUntil", 0)
		target:SetAttribute("Bitable", bitable)
		local h = rootOf(target)
		if h then h.Anchored = false end
	end
	task.spawn(function()
		task.wait(math.max(0, catchAt - now()))
		if latched then
			local w0 = os.clock()
			while target.Parent and target:GetAttribute("PounceLatched") == true and os.clock() - w0 < 0.5 do RunService.Heartbeat:Wait() end
		end
		local hrp, r = rootOf(target), rootOf(char)
		if not (hrp and r and char.Parent and target.Parent) then cancel() return end
		if isPlayer then stun(target, landAt + stunT) else hrp.Anchored = true end
		task.wait(math.max(0, throwAt - OT_LAND_LEAD - now()))
		if not (target.Parent and r.Parent) then cancel() return end
		local fwd = flat(r.CFrame.LookVector)
		fwd = fwd.Magnitude > 1e-3 and fwd.Unit or -Vector3.zAxis
		local dir = side == "front" and -fwd or fwd
		local land = onGround(r.Position + dir * fling)
		local landPos = land + Vector3.new(0, lift, 0)
		char:SetAttribute("TenoGrabLandLift", lift)
		char:SetAttribute("TenoGrabLand", land)
		task.wait(math.max(0, throwAt - now()))
		if not target.Parent then cancel() return end
		char:SetAttribute("TenoGrabThrowAt", now())
		if isPlayer then
			local start = hrp.Position
			local d = flat(landPos - start)
			local dist = d.Magnitude
			d = dist > 1e-3 and d.Unit or dir
			target:SetAttribute("StunTossFrom", start - d * 2)
			target:SetAttribute("StunTossDistance", dist)
			target:SetAttribute("StunTossAt", now()) -- last: StunClient throws it
		end
		task.wait(math.max(0, landAt - now()))
		if not isPlayer and target.Parent then
			hrp.CFrame = CFrame.new(landPos) * CFrame.lookAt(Vector3.zero, dir)
			target:SetAttribute("Bitable", bitable)
		end
		local tl = now()
		char:SetAttribute("TenoGrabLandAt", tl)
		if target.Parent then
			damage(char, player, target, dmg, "tailgrab", tl)
			if not shielded(target, tl) then stun(target, tl + stunT) end
		end
		if crash > 0 and crashR > 0 then
			local n = 0
			for _, m in ipairs(candidates(char)) do
				local mr = rootOf(m)
				if m ~= target and flat(mr.Position - land).Magnitude <= crashR and math.abs(mr.Position.Y - land.Y) <= DY then
					damage(char, player, m, crash, "tailgrab", tl)
					if not shielded(m, tl) then stun(m, tl + 1) end
					n += 1
				end
			end
			char:SetAttribute("TenoGrabCrashHits", n)
		end
	end)
end

grabRemote.OnServerEvent:Connect(function(player, stamp)
	local char, t = check(player, stamp, "tgrab", "TenoGrab", {})
	if not char then return end
	local target = pickGrab(char, t)
	if not target then
		char:SetAttribute("TenoGrabServerResult", "noTarget")
		char:SetAttribute("TenoGrabServerResultAt", t)
		return
	end
	ok(char, "TenoGrab", t)
	count("TenoMovesGrabs")
	local sc = char:GetScale()
	local fling = num(char, "TenoGrabFling", 30)
	local dmg, stunT = num(char, "TenoGrabDamage", 8), num(char, "TenoGrabStun", 1)
	local crash, crashR = num(char, "TenoGrabCrash", 0), num(char, "TenoGrabCrashRadius", 0)
	if script:GetAttribute("TenoMovesGrabOverTopEnabled") ~= false then -- v1.7
		grabOverTop(char, player, target, t, fling, dmg, stunT, crash, crashR)
		return
	end
	char:SetAttribute("TenoGrabTarget", target.Name)
	char:SetAttribute("TenoGrabCrashHits", 0)
	char:SetAttribute("TenoGrabStartedAt", t) -- last: poses / FX
	target:SetAttribute("TenoGrabbedBy", char.Name)
	target:SetAttribute("TenoGrabbedAt", t)
	local isPlayer = Players:GetPlayerFromCharacter(target) ~= nil
	local latched = latchedOnMe(target, char)
	if latched then
		target:SetAttribute("ShakeOffReason", "grabbed")
		target:SetAttribute("ShakeOffAt", t) -- last: PounceServer / BotServer release the latch
	end
	stun(target, t + GRAB_CATCH + GRAB_CARRY + FLING_TIME + stunT)
	local hrp0 = rootOf(target)
	local lift = math.clamp(hrp0.Position.Y - groundY(hrp0.Position, hrp0.Position.Y - 3), 1, 12) -- its root height over the ground (a latched raptor: capped), kept on landing
	task.spawn(function()
		task.wait(GRAB_CATCH)
		if latched then
			local w0 = os.clock()
			while target.Parent and target:GetAttribute("PounceLatched") == true and os.clock() - w0 < 0.5 do RunService.Heartbeat:Wait() end
		end
		local hrp, root = rootOf(target), rootOf(char)
		if not (hrp and root and char.Parent and target.Parent) then return end
		local _, tip = tailPoints(char)
		-- carry (bots ride the tail tip; a player stays stunned where it is)
		if not isPlayer then
			hrp.Anchored = true
			local c0 = os.clock()
			while os.clock() - c0 < GRAB_CARRY and target.Parent and tip and tip.Parent do
				hrp.CFrame = CFrame.new((tip.CFrame * CFrame.new(-2.0 * sc, -0.6 * sc, 0)).Position - Vector3.new(0, 5, 0)) * (hrp.CFrame - hrp.Position)
				RunService.Heartbeat:Wait()
			end
		else
			task.wait(GRAB_CARRY)
		end
		if not (target.Parent and root.Parent) then return end
		-- throw
		local fwd = flat(root.CFrame.LookVector)
		fwd = fwd.Magnitude > 1e-3 and fwd.Unit or -Vector3.zAxis
		local start = hrp.Position
		local land = onGround(root.Position + fwd * fling)
		local landPos = land + Vector3.new(0, lift, 0)
		local throwAt = now()
		char:SetAttribute("TenoGrabThrowAt", throwAt)
		char:SetAttribute("TenoGrabLand", land)
		if isPlayer then
			local dir = flat(landPos - start)
			local dist = dir.Magnitude
			dir = dist > 1e-3 and dir.Unit or fwd
			target:SetAttribute("StunTossFrom", start - dir * 2)
			target:SetAttribute("StunTossDistance", dist)
			target:SetAttribute("StunTossAt", throwAt) -- last: StunClient throws it
			task.wait(FLING_TIME)
		else
			hrp.Anchored = true
			flyBot(target, hrp, start, landPos, FLING_TIME, FLING_PEAK, CFrame.lookAt(Vector3.zero, -fwd))
			if target.Parent then
				hrp.CFrame = CFrame.new(landPos) * CFrame.lookAt(Vector3.zero, -fwd)
				hrp.Anchored = false
			end
		end
		local tl = now()
		char:SetAttribute("TenoGrabLandAt", tl)
		if target.Parent then
			damage(char, player, target, dmg, "tailgrab", tl)
			if not shielded(target, tl) then stun(target, tl + stunT) end
		end
		if crash > 0 and crashR > 0 then
			local n = 0
			for _, m in ipairs(candidates(char)) do
				local mr = rootOf(m)
				if m ~= target and flat(mr.Position - land).Magnitude <= crashR and math.abs(mr.Position.Y - land.Y) <= DY then
					damage(char, player, m, crash, "tailgrab", tl)
					if not shielded(m, tl) then stun(m, tl + 1) end
					n += 1
				end
			end
			char:SetAttribute("TenoGrabCrashHits", n)
		end
	end)
end)

-- Boulder Mortar --------------------------------------------------------------------------------------------------------------------
local function boulder(from, to, flight, peakUp)
	local b = Instance.new("Part")
	b.Name = "TenoBoulder"
	b.Shape = Enum.PartType.Ball
	b.Size = Vector3.one * 2.8
	b.Material, b.Color = Enum.Material.Slate, Color3.fromRGB(138, 132, 120)
	b.Anchored, b.CanCollide, b.CanQuery, b.CanTouch = true, false, false, false
	b.CFrame = CFrame.new(from)
	b.Parent = fx()
	flight, peakUp = flight or MORTAR_FLIGHT, peakUp or MORTAR_PEAK -- v1.2
	local peak = math.max(from.Y, to.Y) + peakUp
	task.spawn(function()
		local t0 = os.clock()
		while b.Parent do
			local u = math.min(1, (os.clock() - t0) / flight)
			local base = from:Lerp(to, u)
			local y0 = from.Y + (to.Y - from.Y) * u
			local arc = 4 * (peak - math.max(from.Y, to.Y)) * u * (1 - u)
			b.CFrame = CFrame.new(base.X, y0 + arc, base.Z) * CFrame.Angles(u * 9, u * 5, 0)
			if u >= 1 then break end
			RunService.Heartbeat:Wait()
		end
		b:Destroy()
	end)
end
local function rubblePatch(char, player, pt, r, untilT, mul)
	local p = Instance.new("Part")
	p.Name = "TenoRubble"
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(0.3, r * 2, r * 2)
	p.CFrame = CFrame.new(pt + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, 0, math.rad(90))
	p.Material, p.Color = Enum.Material.Slate, Color3.fromRGB(106, 92, 68)
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p:SetAttribute("Until", untilT)
	p.Parent = fx()
	for i = 1, 10 do
		local s = 0.8 + ((i * 37) % 10) / 10
		local a, rr = i * 2.399, r * 0.85 * math.sqrt(i / 10)
		local q = Instance.new("Part")
		q.Name = "RubbleRock"
		q.Size = Vector3.new(s, s * 0.6, s)
		q.CFrame = CFrame.new(pt + Vector3.new(math.cos(a) * rr, s * 0.3, math.sin(a) * rr)) * CFrame.Angles(0, a, 0)
		q.Material, q.Color = Enum.Material.Slate, Color3.fromRGB(138, 132, 120)
		q.Anchored, q.CanCollide, q.CanQuery, q.CanTouch = true, false, false, false
		q.Parent = p
	end
	task.spawn(function()
		while p.Parent and now() < untilT do
			local t = now()
			if char.Parent then
				for _, m in ipairs(candidates(char)) do
					local mr = rootOf(m)
					if flat(mr.Position - pt).Magnitude <= r and math.abs(mr.Position.Y - pt.Y) <= DY then slow(m, mul, t + 0.3, t) end
				end
			end
			task.wait(0.2)
		end
		p:Destroy()
	end)
end
mortarRemote.OnServerEvent:Connect(function(player, stamp, aimDir, aimPoint)
	local char, t = check(player, stamp, "tmortar", "TenoMortar", {aim = true, aimDir = aimDir})
	if not char then return end
	ok(char, "TenoMortar", t)
	count("TenoMovesMortars")
	local root = rootOf(char)
	local sc = char:GetScale()
	local aim = flat(aimDir)
	aim = aim.Magnitude > 1e-3 and aim.Unit or flat(root.CFrame.LookVector).Unit
	local range, miss = num(char, "TenoMortarRange", 60), num(char, "TenoMortarMiss", 45)
	local cone = math.rad(math.clamp(num(char, "TenoMortarCone", 30), 1, 180))
	local best, bestD
	for _, m in ipairs(candidates(char)) do
		local v = flat(rootOf(m).Position - root.Position)
		local d = v.Magnitude
		if d > 1e-3 and d <= range and math.acos(math.clamp(aim:Dot(v.Unit), -1, 1)) <= cone and (not bestD or d < bestD) then best, bestD = m, d end
	end
	local centre = best and onGround(rootOf(best).Position) or onGround(root.Position + aim * miss)
	local newAim = script:GetAttribute("TenoMovesMortarAimEnabled") ~= false -- v1.2: crosshair + snap
	local fireT, flightT, peakT = MORTAR_FIRE, MORTAR_FLIGHT, MORTAR_PEAK
	if newAim then
		fireT, flightT, peakT = MORTAR_FIRE2, MORTAR_FLIGHT2, MORTAR_PEAK2
		local minR = num(char, "TenoMortarMin", 15)
		local spot
		if typeof(aimPoint) == "Vector3" and aimPoint == aimPoint and (aimPoint - root.Position).Magnitude <= 400 then
			local v = flat(aimPoint - root.Position)
			local d = math.clamp(v.Magnitude, minR, range)
			local dir = v.Magnitude > 1e-3 and v.Unit or aim
			spot = onGround(root.Position + dir * d)
			char:SetAttribute("TenoMortarAimMode", "crosshair")
		else
			spot = onGround(root.Position + aim * math.clamp(miss, minR, range))
			char:SetAttribute("TenoMortarAimMode", "auto")
		end
		local snapR = num(char, "TenoMortarSnap", 8)
		best, bestD = nil, nil
		for _, m in ipairs(candidates(char)) do
			local d = flat(rootOf(m).Position - spot).Magnitude
			if d <= snapR and (not bestD or d < bestD) then best, bestD = m, d end
		end
		if best then
			spot = onGround(rootOf(best).Position)
			char:SetAttribute("TenoMortarAimMode", "snap")
		end
		centre = spot
	end
	if newAim and script:GetAttribute("TenoMovesMortarBigEnabled") ~= false then -- v1.5: wind-up, longer shots fly longer
		fireT = MORTAR_FIRE3
		if script:GetAttribute("TenoMovesMortarAnchorEnabled") ~= false then fireT = MORTAR_FIRE_A end -- v1.11
		local k = math.clamp((flat(centre - root.Position).Magnitude - 60) / 30, 0, 1)
		flightT, peakT = flightT + 0.3 * k, peakT + 8 * k
	end
	local right = aim:Cross(Vector3.yAxis).Unit
	local pts = num(char, "TenoMortarCount", 1) >= 2 and {onGround(centre + right * MORTAR_PAIR), onGround(centre - right * MORTAR_PAIR)} or {centre}
	local splash, dmg = num(char, "TenoMortarSplash", 10), num(char, "TenoMortarDamage", 12)
	local smul, stime, rubble = num(char, "TenoMortarSlowMul", 1), num(char, "TenoMortarSlowTime", 0), num(char, "TenoMortarRubble", 0)
	char:SetAttribute("TenoMortarTarget", best and best.Name or "")
	char:SetAttribute("TenoMortarLand", centre)
	char:SetAttribute("TenoMortarHits", 0)
	char:SetAttribute("TenoMortarStartedAt", t) -- last: poses / FX
	task.delay(fireT, function()
		if not char.Parent then return end
		local tail = char:FindFirstChild("Tail3_main", true)
		local from = (tail and tail:IsA("BasePart")) and (tail.CFrame * CFrame.new(0.1 * sc, 1.1 * sc, 0)).Position or root.Position + Vector3.new(0, 6, 0)
		if script:GetAttribute("TenoMovesMortarMuzzleEnabled") ~= false then -- v1.9: the Back Cannon's barrel tip
			local tp = char:FindFirstChild("TPart_tmortar")
			if tp then
				for _, d in ipairs(tp:GetDescendants()) do
					if d:IsA("BasePart") and d:GetAttribute("TPartRole") == "muzzle" then from = d.Position break end
				end
			end
		end
		char:SetAttribute("TenoMortarFiredAt", now())
		for _, pt in ipairs(pts) do boulder(from, pt, flightT, peakT) end
		task.wait(flightT)
		local tl = now()
		local hit, n = {}, 0
		for _, m in ipairs(candidates(char)) do
			local mr = rootOf(m)
			for _, pt in ipairs(pts) do
				if not hit[m] and flat(mr.Position - pt).Magnitude <= splash and math.abs(mr.Position.Y - pt.Y) <= DY then
					hit[m] = true
					local cr = rootOf(char)
					local defl, refl = deflected(m, cr and cr.Position or pt, "boulder", tl, "TenoMovesDeflectEnabled") -- v1.8
					if defl then
						if refl then
							local mp = Players:GetPlayerFromCharacter(m)
							damage(m, mp or {UserId = 0}, char, dmg, "deflect", tl)
						end
					else
						n += 1
						damage(char, player, m, dmg, "mortar", tl)
						slow(m, smul, tl + stime, tl)
					end
				end
			end
		end
		char:SetAttribute("TenoMortarHits", n)
		char:SetAttribute("TenoMortarLandedAt", tl)
		if rubble > 0 and smul < 1 then
			for _, pt in ipairs(pts) do rubblePatch(char, player, pt, splash * 0.8, tl + rubble, smul) end
		end
	end)
end)

-- Stomp Shockwave ---------------------------------------------------------------------------------------------------------------------
stompRemote.OnServerEvent:Connect(function(player, stamp)
	local char, t = check(player, stamp, "tstomp", "TenoStomp", {})
	if not char then return end
	ok(char, "TenoStomp", t)
	count("TenoMovesStomps")
	local range, dmg, stunT, noJump = num(char, "TenoStompRange", 14), num(char, "TenoStompDamage", 6), num(char, "TenoStompStun", 0.5),
		num(char, "TenoStompNoJump", 0)
	char:SetAttribute("TenoStompHits", 0)
	char:SetAttribute("TenoStompStartedAt", t)
	task.delay(script:GetAttribute("TenoMovesStompQuakeEnabled") ~= false and STOMP_HIT_A or STOMP_HIT, function() -- v1.11
		local root = rootOf(char)
		local hum = char:FindFirstChildOfClass("Humanoid")
		if not (char.Parent and root and hum and hum.Health > 0) then return end
		local tl = now()
		local hl, hr = char:FindFirstChild("ArmL_hand", true), char:FindFirstChild("ArmR_hand", true)
		local mid = (hl and hr) and (hl.Position + hr.Position) / 2 or (root.Position + flat(root.CFrame.LookVector) * 6)
		local centre = onGround(mid)
		local drain = num(char, "TenoStompLatchDrain", 0)
		local drained = 0
		for _, m in ipairs(latchedOnes(char)) do
			if script:GetAttribute("TenoMovesStompDrainEnabled") == false then
				m:SetAttribute("ShakeOffReason", "stomped")
				m:SetAttribute("ShakeOffAt", tl)
			elseif drain > 0 then -- v1.1: star drains the latch's stamina
				m:SetAttribute("StaminaDrainAmount", drain)
				m:SetAttribute("StaminaDrainAt", tl) -- last: StaminaServer / BotServer react
				drained += 1
			end
		end
		char:SetAttribute("TenoStompDrained", drained)
		local n = 0
		for _, m in ipairs(candidates(char)) do
			local mr = rootOf(m)
			if not latchedOnMe(m, char) and gap(m, centre) <= range and math.abs(mr.Position.Y - centre.Y) <= DY then
				n += 1
				damage(char, player, m, dmg, "stomp", tl)
				if not shielded(m, tl) then
					stun(m, tl + stunT)
					if noJump > 0 then m:SetAttribute("NoJumpUntil", math.max(num(m, "NoJumpUntil", 0), tl + noJump)) end
				end
			end
		end
		char:SetAttribute("TenoStompCenter", centre)
		char:SetAttribute("TenoStompHits", n)
		char:SetAttribute("TenoStompAt", tl) -- last: FX
	end)
end)

-- Hydraulic Leap ----------------------------------------------------------------------------------------------------------------------
local function leapPublish(char, st, t)
	char:SetAttribute("TenoLeapChargesLeft", st.charges)
	local nextAt = st.refills[1]
	char:SetAttribute("TenoLeapRefillAt", nextAt or 0)
	char:SetAttribute("TenoLeapReadyAt", st.charges > 0 and t or (nextAt or t))
end
local function leapStateOf(char, t)
	local mx = math.max(0, math.floor(num(char, "TenoLeapCharges", 0)))
	local st = leapState[char]
	if not st or st.max ~= mx then
		st = {charges = mx, max = mx, refills = {}}
		leapState[char] = st
		leapPublish(char, st, t)
	end
	return st
end
RunService.Heartbeat:Connect(function()
	local t
	for char, st in pairs(leapState) do
		if not char.Parent then
			leapState[char] = nil
		elseif st.refills[1] and (t or now()) >= st.refills[1] then
			t = t or now()
			table.remove(st.refills, 1)
			st.charges = math.min(st.max, st.charges + 1)
			leapPublish(char, st, t)
		end
	end
end)
leapRemote.OnServerEvent:Connect(function(player, stamp)
	local c0 = player.Character
	if c0 and script:GetAttribute("TenoMovesLeapOnJumpEnabled") ~= false and c0:GetAttribute("TenoLeapOnJump") == true then -- v1.4
		c0:SetAttribute("TenoLeapServerResult", "onJump")
		c0:SetAttribute("TenoLeapServerResultAt", now())
		return
	end
	if c0 and c0:GetAttribute("TenoLeapEnabled") == true then
		local st = leapStateOf(c0, now())
		leapPublish(c0, st, now())
	end
	local char, t = check(player, stamp, "tleap", "TenoLeap", {leap = true})
	if not char then return end
	local st = leapStateOf(char, t)
	if st.charges <= 0 then
		char:SetAttribute("TenoLeapServerResult", "cooldown")
		char:SetAttribute("TenoLeapServerResultAt", t)
		return
	end
	ok(char, "TenoLeap", t, false)
	count("TenoMovesLeaps")
	st.charges -= 1
	local cd = math.max(0.5, num(char, "TenoLeapCooldown", 14))
	local last = st.refills[#st.refills]
	table.insert(st.refills, math.max(t, last or t) + cd)
	leapPublish(char, st, t)
	local dist, dmg, radius, stunT = num(char, "TenoLeapDist", 40), num(char, "TenoLeapDamage", 10), num(char, "TenoLeapRadius", 12),
		num(char, "TenoLeapStun", 0)
	char:SetAttribute("TenoLeapDistNow", dist)
	char:SetAttribute("TenoLeapFlightTime", LEAP_TIME)
	char:SetAttribute("TenoLeapUntil", t + LEAP_TIME + 0.8)
	char:SetAttribute("TenoLeapHits", 0)
	char:SetAttribute("TenoLeapStartedAt", t) -- last: TenoLeapLaunch launches the body
	local r0 = rootOf(char)
	local h0 = r0.Position.Y - groundY(r0.Position, r0.Position.Y - 3) -- standing height over the ground
	task.spawn(function()
		local hum = char:FindFirstChildOfClass("Humanoid")
		local w0 = os.clock()
		while char.Parent and hum and hum.Parent and os.clock() - w0 < LEAP_TIME + 0.8 do
			local rr = rootOf(char)
			if os.clock() - w0 >= LEAP_TIME * 0.6 and rr and rr.Position.Y - groundY(rr.Position, rr.Position.Y - 3) <= h0 + 1.5 then break end
			RunService.Heartbeat:Wait()
		end
		local root = rootOf(char)
		if not (char.Parent and root and hum and hum.Health > 0) then
			if char.Parent then char:SetAttribute("TenoLeapUntil", 0) end
			return
		end
		local tl = now()
		local n = 0
		for _, m in ipairs(candidates(char)) do
			local mr = rootOf(m)
			if gap(m, root.Position) <= radius and math.abs(mr.Position.Y - root.Position.Y) <= DY then
				n += 1
				damage(char, player, m, dmg, "leap", tl)
				if stunT > 0 and not shielded(m, tl) then stun(m, tl + stunT) end
			end
		end
		char:SetAttribute("TenoLeapHits", n)
		char:SetAttribute("TenoLeapUntil", 0)
		char:SetAttribute("TenoLeapLandedAt", tl) -- last: FX
	end)
end)

-- v1.3: support moves (build 2) ------------------------------------------------------------------------------------------
local bellowRemote, challengeRemote, mudRemote = remote("DinoTenoBellowRequest"), remote("DinoTenoChallengeRequest"), remote("DinoTenoMudRequest")
local function sameSquad(a, b) -- squadmate() without the skip count
	if script:GetAttribute("TenoMovesServerSquadEnabled") == false then return false end
	if not squadMod then
		local arc = ServerStorage:FindFirstChild("DinoArcade")
		local m = arc and arc:FindFirstChild("SquadRules")
		if not m then return false end
		local okR, mod = pcall(require, m)
		if not okR then return false end
		squadMod = mod
	end
	return squadMod.sameChar(a, b) == true
end
local function within(m, pos, r)
	local mr = rootOf(m)
	return mr ~= nil and flat(mr.Position - pos).Magnitude <= r and math.abs(mr.Position.Y - pos.Y) <= DY
end
local function round1(v) return math.floor(v * 10 + 0.5) / 10 end
local function alive(char)
	local hum = char:FindFirstChildOfClass("Humanoid")
	return char.Parent ~= nil and hum ~= nil and hum.Health > 0 and rootOf(char) ~= nil
end

-- Herd Bellow
local bellowTrack = {} -- [character] = {last, own}
local function trackBellow(m)
	if bellowTrack[m] then return end
	local hum = m:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	local st = {last = hum.Health}
	bellowTrack[m] = st
	hum.HealthChanged:Connect(function(h)
		if st.own and math.abs(h - st.own) < 1e-3 then st.own, st.last = nil, h return end
		local drop = st.last - h
		st.last = h
		if drop <= 0 or h <= 0 or not on("tbellow") then return end
		if num(m, "TenoBellowedUntil", 0) <= now() then return end
		local mul = math.clamp(num(m, "TenoBellowedDamageMul", 1), 0, 1)
		if mul >= 1 then return end
		local refund = drop * (1 - mul)
		local new = math.min(hum.MaxHealth, h + refund)
		st.own, st.last = new, new
		hum.Health = new
		m:SetAttribute("TenoBellowRefunded", round1(num(m, "TenoBellowRefunded", 0) + refund))
	end)
	m.AncestryChanged:Connect(function()
		if not m:IsDescendantOf(workspace) then bellowTrack[m] = nil end
	end)
end
bellowRemote.OnServerEvent:Connect(function(player, stamp)
	local char, t = check(player, stamp, "tbellow", "TenoBellow", {})
	if not char then return end
	ok(char, "TenoBellow", t)
	count("TenoMovesBellows")
	char:SetAttribute("TenoBellowStartedAt", t)
	local range, time = num(char, "TenoBellowRange", 25), num(char, "TenoBellowTime", 4)
	local dmul, rmul = num(char, "TenoBellowDamageMul", 1), num(char, "TenoBellowRunMul", 1)
	local clear = char:GetAttribute("TenoBellowClearStun") == true
	task.delay(BELLOW_AT, function()
		if not alive(char) then return end
		local tl = now()
		local centre = rootOf(char).Position
		local list = {char}
		for _, pl in ipairs(Players:GetPlayers()) do
			local c = pl.Character
			if c and c ~= char and alive(c) and within(c, centre, range) and sameSquad(char, c) then table.insert(list, c) end
		end
		local names, cleared = {}, 0
		for _, m in ipairs(list) do
			m:SetAttribute("TenoBellowedDamageMul", dmul)
			m:SetAttribute("TenoBellowedRunMul", rmul)
			m:SetAttribute("TenoBellowedBy", char.Name)
			m:SetAttribute("TenoBellowedUntil", math.max(num(m, "TenoBellowedUntil", 0), tl + time))
			trackBellow(m)
			if clear and num(m, "StunnedUntil", 0) > tl then
				m:SetAttribute("StunnedUntil", tl)
				cleared += 1
			end
			table.insert(names, m.Name)
		end
		char:SetAttribute("TenoBellowTargets", table.concat(names, "|"))
		char:SetAttribute("TenoBellowCount", #list)
		char:SetAttribute("TenoBellowCleared", cleared)
		char:SetAttribute("TenoBellowAt", tl) -- last: FX
	end)
end)

-- Challenge Call
challengeRemote.OnServerEvent:Connect(function(player, stamp)
	local char, t = check(player, stamp, "tchallenge", "TenoChallenge", {})
	if not char then return end
	ok(char, "TenoChallenge", t)
	count("TenoMovesChallenges")
	local range, time = num(char, "TenoChallengeRange", 30), num(char, "TenoChallengeTime", 5)
	if script:GetAttribute("TenoMovesChallengeAimEnabled") ~= false then -- v1.11: where the head snaps
		local root, yaw, bestD = rootOf(char), 0, nil
		if root then
			for _, m in ipairs(candidates(char)) do
				local mr = rootOf(m)
				local d = mr and flat(mr.Position - root.Position).Magnitude
				if d and d <= range and math.abs(mr.Position.Y - root.Position.Y) <= DY and (not bestD or d < bestD) then
					local lp = root.CFrame:PointToObjectSpace(mr.Position)
					yaw, bestD = math.clamp(math.deg(math.atan2(lp.X, -lp.Z)), -CHALLENGE_AIM_MAX, CHALLENGE_AIM_MAX), d
				end
			end
		end
		char:SetAttribute("TenoChallengeAimYaw", math.floor(yaw * 10 + 0.5) / 10)
	end
	char:SetAttribute("TenoChallengeStartedAt", t)
	local weak, smul = math.clamp(num(char, "TenoChallengeWeakMul", 1), 0, 1), num(char, "TenoChallengeSlowMul", 1)
	task.delay(CHALLENGE_AT, function()
		if not alive(char) then return end
		local tl = now()
		local centre = rootOf(char).Position
		local names = {}
		for _, m in ipairs(candidates(char)) do
			if within(m, centre, range) and not shielded(m, tl) then
				local cu, cm = num(m, "TenoWeakUntil", 0), num(m, "TenoWeakMul", 1)
				if cu <= tl then cm = 1 end
				m:SetAttribute("TenoMarkedBy", char.Name)
				m:SetAttribute("TenoMarkedByUserId", player.UserId)
				m:SetAttribute("TenoWeakMul", math.min(cm, weak))
				m:SetAttribute("TenoWeakUntil", math.max(cu, tl + time)) -- last: StatServer / BotServer react
				if smul < 1 then slow(m, smul, tl + time, tl) end
				table.insert(names, m.Name)
			end
		end
		char:SetAttribute("TenoChallengeTargets", table.concat(names, "|"))
		char:SetAttribute("TenoChallengeHits", #names)
		char:SetAttribute("TenoChallengeAt", tl) -- last: FX
	end)
end)

-- Mud Armor
local mudState = {} -- [char] = {ff, conns, hitsLeft, untilT, lastBlock, done}
local function mudSlowAround(char, r, mul, time, t)
	if r <= 0 or mul >= 1 or time <= 0 then return 0 end
	local root = rootOf(char)
	if not root then return 0 end
	local n = 0
	for _, m in ipairs(candidates(char)) do
		if within(m, root.Position, r) then
			slow(m, mul, t + time, t)
			n += 1
		end
	end
	return n
end
local function mudEnd(char, st, reason)
	if st.done then return end
	st.done = true
	mudState[char] = nil
	for _, c in ipairs(st.conns) do c:Disconnect() end
	if st.ff then st.ff:Destroy() end
	local t = now()
	if not char.Parent then return end
	char:SetAttribute("TenoMudHitsLeft", 0)
	if reason ~= "time" then char:SetAttribute("TenoMudUntil", t) end
	char:SetAttribute("TenoMudEndReason", reason)
	local splash = num(char, "TenoMudSplash", 0)
	if splash > 0 and reason ~= "dead" and alive(char) then
		local n = mudSlowAround(char, splash, num(char, "TenoMudSlowMul", 1), num(char, "TenoMudSlowTime", 4), t)
		char:SetAttribute("TenoMudSplashHits", n)
		char:SetAttribute("TenoMudSplashAt", t)
	end
	char:SetAttribute("TenoMudEndedAt", t) -- last: FX
end
local function mudBlock(char, st)
	if st.done then return end
	local t = now()
	if st.lastBlock and t - st.lastBlock < MUD_BLOCK_GAP then return end
	st.lastBlock = t
	st.hitsLeft -= 1
	count("TenoMovesMudBlocks")
	char:SetAttribute("TenoMudHitsLeft", math.max(0, st.hitsLeft))
	char:SetAttribute("TenoMudBlocks", num(char, "TenoMudBlocks", 0) + 1)
	mudSlowAround(char, num(char, "TenoMudSlowRadius", 0), num(char, "TenoMudSlowMul", 1), num(char, "TenoMudSlowTime", 0), t)
	char:SetAttribute("TenoMudBlockAt", t)
	if st.hitsLeft <= 0 then mudEnd(char, st, "hits") end
end
mudRemote.OnServerEvent:Connect(function(player, stamp)
	local char, t = check(player, stamp, "tmud", "TenoMud", {})
	if not char then return end
	ok(char, "TenoMud", t)
	count("TenoMovesMuds")
	if mudState[char] then mudEnd(char, mudState[char], "disabled") end
	char:SetAttribute("TenoMudBlocks", 0)
	char:SetAttribute("TenoMudStartedAt", t)
	task.delay(MUD_SLIDE_AT, function()
		if not alive(char) then return end
		local tl = now()
		for _, m in ipairs(latchedOnes(char)) do
			m:SetAttribute("ShakeOffReason", "mud")
			m:SetAttribute("ShakeOffAt", tl) -- last: PounceServer / BotServer release the latch
		end
	end)
	local coatAt = MUD_COAT_AT
	if script:GetAttribute("TenoMovesShieldFastEnabled") ~= false then coatAt = math.max(0, tonumber(script:GetAttribute("TenoMovesShieldCoatAt")) or 0.2) end -- v1.5
	task.delay(coatAt, function()
		if not alive(char) or char:GetAttribute("TenoMudEnabled") ~= true or not on("tmud") then return end
		local tc = now()
		local ff = Instance.new("ForceField")
		ff.Name = "TenoMudShield"
		ff.Visible = false
		ff.Parent = char
		local st = {ff = ff, conns = {}, hitsLeft = math.max(1, math.floor(num(char, "TenoMudHits", 3))),
			untilT = tc + num(char, "TenoMudTime", 8)}
		mudState[char] = st
		for _, k in ipairs({"LastHitAt", "ArenaPvPLastDelta"}) do
			table.insert(st.conns, char:GetAttributeChangedSignal(k):Connect(function() mudBlock(char, st) end))
		end
		char:SetAttribute("TenoMudHitsLeft", st.hitsLeft)
		char:SetAttribute("TenoMudUntil", st.untilT)
		char:SetAttribute("TenoMudCoatAt", tc) -- last: FX
		task.spawn(function()
			while not st.done do
				local hum = char:FindFirstChildOfClass("Humanoid")
				if not char.Parent or not hum or hum.Health <= 0 then
					mudEnd(char, st, "dead")
				elseif char:GetAttribute("TenoMudEnabled") ~= true or not on("tmud") then
					mudEnd(char, st, "disabled")
				elseif now() >= st.untilT then
					mudEnd(char, st, "time")
				end
				task.wait(0.1)
			end
		end)
	end)
end)

-- leap charges: publish for MechaButtons as soon as the part turns on / changes
local function watch(char)
	local function refresh()
		if char:GetAttribute("TenoLeapEnabled") == true then
			local t = now()
			leapPublish(char, leapStateOf(char, t), t)
		end
	end
	char:GetAttributeChangedSignal("TenoLeapEnabled"):Connect(refresh)
	char:GetAttributeChangedSignal("TenoLeapCharges"):Connect(refresh)
	task.defer(refresh)
end
local function onPlayer(p)
	p.CharacterAdded:Connect(watch)
	if p.Character then watch(p.Character) end
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do onPlayer(p) end

-- v1.4: Hydraulic Leap through JUMP (see the header) ------------------------------------------------------------------------
if script:GetAttribute("TenoMovesLeapOnJumpEnabled") == nil then script:SetAttribute("TenoMovesLeapOnJumpEnabled", true) end
local function leapOnJump(char)
	return script:GetAttribute("TenoMovesLeapOnJumpEnabled") ~= false and char:GetAttribute("TenoLeapOnJump") == true
end
local function leapMirror(char)
	local t = now()
	local left = math.floor(num(char, "JumpChargesLeft", num(char, "JumpCharges", 1)))
	local refill = num(char, "JumpChargeRefillAt", 0)
	char:SetAttribute("TenoLeapChargesLeft", left)
	char:SetAttribute("TenoLeapRefillAt", refill)
	char:SetAttribute("TenoLeapReadyAt", left > 0 and t or refill)
end
do
	local leapPublishV13 = leapPublish
	leapPublish = function(char, st, t)
		if leapOnJump(char) then return leapMirror(char) end
		return leapPublishV13(char, st, t)
	end
end
local function inLeapArc(char, root, mr) -- v1.6
	if script:GetAttribute("TenoMovesLeapArcEnabled") == false then return true end
	local arc = tonumber(char:GetAttribute("TenoLeapArc"))
	if not arc or arc >= 360 then return true end
	local d = (mr.Position - root.Position) * Vector3.new(1, 0, 1)
	local f = root.CFrame.LookVector * Vector3.new(1, 0, 1)
	if d.Magnitude < 0.5 or f.Magnitude < 1e-3 then return true end
	return math.deg(math.acos(math.clamp(f.Unit:Dot(d.Unit), -1, 1))) <= arc / 2
end
local function jumpSlam(char)
	local player = Players:GetPlayerFromCharacter(char)
	local hum = char:FindFirstChildOfClass("Humanoid")
	local r0 = rootOf(char)
	if not (player and hum and hum.Health > 0 and r0) then return end
	local t0 = num(char, "JumpStartedAt", now())
	count("TenoMovesJumpLeaps")
	char:SetAttribute("TenoLeapHits", 0)
	char:SetAttribute("TenoLeapUntil", t0 + 3)
	local h0 = r0.Position.Y - groundY(r0.Position, r0.Position.Y - 3)
	task.spawn(function()
		local w0, left = os.clock(), false
		while char.Parent and hum.Parent and hum.Health > 0 and os.clock() - w0 < 3 do
			local rr = rootOf(char)
			if not rr then break end
			local h = rr.Position.Y - groundY(rr.Position, rr.Position.Y - 3)
			if not left then
				if h > h0 + 2 then left = true end
			elseif h <= h0 + 1.5 then
				break
			end
			RunService.Heartbeat:Wait()
		end
		local root = rootOf(char)
		if not (left and char.Parent and root and hum.Health > 0) then
			if char.Parent then char:SetAttribute("TenoLeapUntil", 0) end
			return
		end
		local tl = now()
		local dmg, radius, stunT = num(char, "TenoLeapDamage", 10), num(char, "TenoLeapRadius", 12), num(char, "TenoLeapStun", 0)
		local n, arcSkips = 0, 0
		for _, m in ipairs(candidates(char)) do
			local mr = rootOf(m)
			local near = gap(m, root.Position) <= radius and math.abs(mr.Position.Y - root.Position.Y) <= DY
			if near and not inLeapArc(char, root, mr) then near = false; arcSkips += 1 end -- v1.6
			if near then
				n += 1
				damage(char, player, m, dmg, "leap", tl)
				if stunT > 0 and not shielded(m, tl) then stun(m, tl + stunT) end
			end
		end
		char:SetAttribute("TenoLeapHits", n)
		char:SetAttribute("TenoLeapArcSkips", arcSkips) -- v1.6
		char:SetAttribute("TenoLeapUntil", 0)
		char:SetAttribute("TenoLeapLandedAt", tl) -- last: FX
	end)
end
-- v1.7: landing on a dino + shove (see the header)
local dinoRay = RaycastParams.new()
dinoRay.FilterType = Enum.RaycastFilterType.Exclude
local function ownerModel(part)
	local m = part:FindFirstAncestorOfClass("Model")
	while m and not m:FindFirstChild("Hitboxes") do m = m.Parent and m.Parent:FindFirstAncestorOfClass("Model") end
	return m
end
local function onDino(char, set, h0, ahead)
	local ex = {char}
	local isl = workspace:FindFirstChild("DinoIsland")
	local tg = isl and isl:FindFirstChild("TallGrass")
	if tg then table.insert(ex, tg) end
	for _, n in ipairs({"DinoFX_Local", "DinoFX", "TenoFX"}) do
		local f = workspace:FindFirstChild(n)
		if f then table.insert(ex, f) end
	end
	dinoRay.FilterDescendantsInstances = ex
	local root = rootOf(char)
	local origins = {root.Position}
	local chest = char:FindFirstChild("Torso_chest", true)
	if chest and chest:IsA("BasePart") then table.insert(origins, chest.Position) end
	for _, o in ipairs(origins) do
		local hit = workspace:Raycast(o, Vector3.new(0, -(h0 + 2 + (ahead or 0)), 0), dinoRay)
		local m = hit and ownerModel(hit.Instance)
		if m and set[m] then return true, m, hit.Position end
	end
	return false
end
local function widthAlong(m, axis) -- the model's extent along a flat axis
	local cf, size = m:GetBoundingBox()
	return math.abs(axis:Dot(cf.RightVector)) * size.X + math.abs(axis:Dot(cf.UpVector)) * size.Y + math.abs(axis:Dot(cf.LookVector)) * size.Z
end
local function leapShove(char, root, m, tl, stunT)
	local mr = rootOf(m)
	if not mr then return false end
	local right = flat(root.CFrame.RightVector)
	right = right.Magnitude > 1e-3 and right.Unit or Vector3.xAxis
	local lp = root.CFrame:PointToObjectSpace(mr.Position)
	local myCF, mySize = char:GetBoundingBox()
	local halfW = (math.abs(right:Dot(myCF.RightVector)) * mySize.X + math.abs(right:Dot(myCF.LookVector)) * mySize.Z) / 2
	local fwd = flat(root.CFrame.LookVector)
	local halfL = fwd.Magnitude > 1e-3 and widthAlong(char, fwd.Unit) / 2 or mySize.Z / 2
	local halfT = widthAlong(m, right) / 2
	if math.abs(lp.X) >= halfW + halfT or math.abs(lp.Z) >= halfL then return false end
	local sgn = lp.X >= 0 and 1 or -1
	local move = sgn * (halfW + halfT + LEAP_SHOVE_GAP) - lp.X
	local from = mr.Position
	local over = math.clamp(from.Y - groundY(from, from.Y - 3), 1, 12)
	local to = onGround(from + right * move) + Vector3.new(0, over, 0)
	if Players:GetPlayerFromCharacter(m) then
		if stunT <= 0 then return false end
		local d = flat(to - from)
		if d.Magnitude < 1e-3 then return false end
		m:SetAttribute("StunTossFrom", from - d.Unit * 2)
		m:SetAttribute("StunTossDistance", d.Magnitude)
		m:SetAttribute("StunTossAt", tl) -- before the stun: StunClient takes the toss at the stun start
		return true
	end
	m:SetAttribute("TenoGrabHeldUntil", tl + LEAP_SHOVE_TIME + 0.05)
	mr.Anchored = true
	m:SetAttribute("TenoMoveFrom", from)
	m:SetAttribute("TenoMoveTo", to)
	m:SetAttribute("TenoMoveTime", LEAP_SHOVE_TIME)
	m:SetAttribute("TenoMovePeak", LEAP_SHOVE_PEAK)
	m:SetAttribute("TenoMoveAt", tl) -- last: TenoBotMotion draws the slide
	local rot = mr.CFrame - mr.Position
	task.delay(LEAP_SHOVE_TIME, function()
		if not (m.Parent and mr.Parent) then return end
		mr.CFrame = CFrame.new(to) * rot
		if num(m, "StunnedUntil", 0) <= now() then mr.Anchored = false end
	end)
	return true
end
local function jumpSlamV17(char)
	local player = Players:GetPlayerFromCharacter(char)
	local hum = char:FindFirstChildOfClass("Humanoid")
	local r0 = rootOf(char)
	if not (player and hum and hum.Health > 0 and r0) then return end
	local t0 = num(char, "JumpStartedAt", now())
	count("TenoMovesJumpLeaps")
	char:SetAttribute("TenoLeapHits", 0)
	char:SetAttribute("TenoLeapUntil", t0 + 3)
	local h0 = r0.Position.Y - groundY(r0.Position, r0.Position.Y - 3)
	task.spawn(function()
		local w0, left, landedOn, dinoHit, dinoY = os.clock(), false, "ground", nil, nil
		while char.Parent and hum.Parent and hum.Health > 0 and os.clock() - w0 < 3 do
			local rr = rootOf(char)
			if not rr then break end
			local h = rr.Position.Y - groundY(rr.Position, rr.Position.Y - 3)
			if not left then
				if h > h0 + 2 then left = true end
			elseif h <= h0 + 1.5 then
				break
			elseif script:GetAttribute("TenoMovesLeapOnDinoEnabled") ~= false and rr.AssemblyLinearVelocity.Y <= 1 then
				local set = {}
				for _, m in ipairs(candidates(char)) do set[m] = true end
				local onIt, dm, dp = false, nil, nil
				if next(set) then onIt, dm, dp = onDino(char, set, h0, math.max(0, -rr.AssemblyLinearVelocity.Y) * LEAP_LOOKAHEAD) end
				if onIt then landedOn, dinoHit, dinoY = "dino", dm, dp.Y break end
			end
			RunService.Heartbeat:Wait()
		end
		local root = rootOf(char)
		if not (left and char.Parent and root and hum.Health > 0) then
			if char.Parent then char:SetAttribute("TenoLeapUntil", 0) end
			return
		end
		char:SetAttribute("TenoLeapLandedOn", landedOn)
		local tl = now()
		local dmg, radius, stunT = num(char, "TenoLeapDamage", 10), num(char, "TenoLeapRadius", 12), num(char, "TenoLeapStun", 0)
		local n, arcSkips, shoves = 0, 0, 0
		local shoveOn = script:GetAttribute("TenoMovesLeapShoveEnabled") ~= false
		local slamPos = root.Position -- on a dino: where the root will be standing on it (the look-ahead fires above it)
		if dinoY then slamPos = Vector3.new(slamPos.X, math.min(slamPos.Y, dinoY + h0), slamPos.Z) end
		for _, m in ipairs(candidates(char)) do
			local mr = rootOf(m)
			local near = m == dinoHit or (gap(m, slamPos) <= radius and math.abs(mr.Position.Y - slamPos.Y) <= DY)
			if near and not inLeapArc(char, root, mr) then near = false; arcSkips += 1 end
			if near then
				n += 1
				local shoved = shoveOn and not shielded(m, tl) and leapShove(char, root, m, tl, stunT)
				if shoved then shoves += 1 end
				damage(char, player, m, dmg, "leap", tl)
				if stunT > 0 and not shielded(m, tl) then stun(m, tl + stunT) end
			end
		end
		char:SetAttribute("TenoLeapHits", n)
		char:SetAttribute("TenoLeapArcSkips", arcSkips)
		char:SetAttribute("TenoLeapShoves", shoves)
		char:SetAttribute("TenoLeapUntil", 0)
		char:SetAttribute("TenoLeapLandedAt", tl) -- last: FX
	end)
end
do
	local jumpSlamV16 = jumpSlam
	jumpSlam = function(char)
		if script:GetAttribute("TenoMovesLeapOnDinoEnabled") ~= false or script:GetAttribute("TenoMovesLeapShoveEnabled") ~= false then
			return jumpSlamV17(char)
		end
		return jumpSlamV16(char)
	end
end
local function watchJump(char)
	local function mirrorNow() if leapOnJump(char) then leapMirror(char) end end
	for _, k in ipairs({"JumpChargesLeft", "JumpChargeRefillAt", "TenoLeapOnJump", "TenoLeapEnabled"}) do
		char:GetAttributeChangedSignal(k):Connect(function() task.defer(mirrorNow) end)
	end
	char:GetAttributeChangedSignal("JumpStartedAt"):Connect(function()
		if leapOnJump(char) and char:GetAttribute("TenoLeapEnabled") == true then jumpSlam(char) end
	end)
	task.defer(mirrorNow)
end
local function onPlayerJ(p)
	p.CharacterAdded:Connect(watchJump)
	if p.Character then watchJump(p.Character) end
end
Players.PlayerAdded:Connect(onPlayerJ)
for _, p in ipairs(Players:GetPlayers()) do onPlayerJ(p) end
