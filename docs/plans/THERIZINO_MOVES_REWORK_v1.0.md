# Mecha Dino Arena — Therizino moves rework (plan v1.0)

**Ask (Kepu 2026-11-04 16:19, after the v439 test):** "Harvest field animation is ass I don't even know what it does. The snare
is ass what the fuck is that supposed to do. The grappling hook is fucking ass it's not obvious with locking on so just change
it to a dash for fucks sake and the reaper hook shit is fucking ass too."
**Picks:** 16:27 "Harvest-C, Snare-B, Dash-C, Hook-B" (+ the rule: the parts must look like quality mecha that fits the
dinosaur, and every animation must make its intent crystal clear). 16:47 the dash gets its own part (not the winch). 16:54 the
Reaper's Hook moves to the chest. 17:0x "Build" → "Storm Core + 30 studs (Recommended)".
**Animation spec:** the 3D storyboard tools/mockup/therizino_moves_anim.js v0.3 (docs/mockups/therizino_moves_anim.html,
artifact Fdapzg56TCAtjxRM4ngcA6). Its phase times are the game's timings below; its parts are the game's looks.

## Global constraints
- Additive; every rework behind its own switch (server, SkillTree, client). Switch off = the v439 move.
- Same part ids and remotes (zharvest / zsnare / zgrapple / zhook): bought steps and slots carry over.
- Version branding in every header, docs/VERSIONS.md, docs/ATTRIBUTES.md.
- PC and phone ship together (MechaButtons is the one button path for both).
- Kepu tests on his phone after "Publish". No publish until he says so.

## Do-not-touch
Feather Barrage, Deflector Claws, passive Overclock; the other dinos' moves; HookPull / HookServer; SprintTest; BotServer; the
v1 looks; the other five v2 looks (only the hook and grapple looks change); TheriMovesFX 1.3 (its handlers stay for the
switched-off moves; the rework FX are a new script).

## Numbers (SkillTree 1.65)
| Move | I | II | III | ★ |
|---|---|---|---|---|
| Harvest Field → Reaper Vortex | ring 30 studs wide, 3 s, pull 6 studs/s, bleed 4/s, slow 30%, recharge 20 s | 34 wide | lasts 4 s | 38 wide, 5 s |
| Snare Wires → Bola | reach 35, auto-aim 25°, held 1 s, 12 damage, 1 charge, recharge 14 s | 2 charges | held 2 s, reach 45 | 3 charges |
| Grapple Zip → Dash (Storm Core) | 30 studs the way you move, 2 charges, recharge 6 s | 40 studs | 50 studs, recharge 5 s | 3 charges |
| Reaper's Hook → Reaper Reel | reach 50, auto-aim 35°, slash 10, recharge 14 s | 65 | 80 | the slashed dino is stunned 1 s and cut 1 starts (as now) |

Ring tiers: Kepu picked 30 studs; II / ★ keep 1.61's +4-stud steps (flagged in the report). Bola reach 45 sits on III with held
2 s (the mockup's "35 / 45" + "1 / 2"), charges on II / ★ (mockup "1 / 2 / 3 charges at the star").

## Timings (from the 3D storyboard, s after the press)
- **Vortex:** 0–0.4 rear up, sleeves glow · 0.4–0.58 stab, red cracks race out · 0.58–0.95 six bone sickles fly from the wrist
  cuffs to the ring · 0.95 → 0.95 + time: the ring spins (disc, spiral, edge ring, orbiting sickles), pulls, bleeds, slows ·
  then 0.4 s sickles return. Ring centre: VORTEX_AHEAD (10) × scale studs ahead of the root, on the ground, fixed.
- **Bola:** 0–0.45 tail winds out, bola whirls at the tail tip · 0.45–0.6 tail whips · 0.6 → 0.6 + flight (distance / 80,
  0.25–0.6 s) the bola arcs to the target's feet · hit: wraps the legs, 12 damage, held · then the wire snaps.
- **Dash:** 0–0.16 charge (arcs horn↔horn↔core) · 0.16 → 0.16 + jolt (distance / 330, 0.08–0.16 s) lightning bolt along the
  path, the dino flashes white, 3 yellow afterimages · landing: shock ring + sparks, skid.
- **Reel:** 0–0.3 brace (chest out, arms wide, claw opens in the muzzle) · 0.3 → 0.3 + fly (distance / 220, 0.12–0.35 s) the
  claw flies on its chain and clamps · reel (distance / 90, 0.3–0.8 s): the drum spins, YOU fly at the target claws up ·
  slash: double claw arcs, 10 damage · 0.3 s the claw reels back into the muzzle.

## Deterministic map (server TheriMovesServer 1.4; checks as 1.3's check())
**Vortex** (switch TheriMovesVortexEnabled): ok → recharge starts; stamps TheriVortexCenter, TheriVortexRadius,
TheriVortexStart (= t + 0.95), TheriFieldUntil (= start + TheriFieldTime), TheriVortexAt (last). From start to until, every
FIELD_TICK (0.5) s: each allowed dino with a hitbox within the radius (flat) takes bleed × 0.5 and is slowed × TheriFieldSlowMul
until 0.6 s later; every Heartbeat each one inside (and not shielded) is moved PULL (6) studs/s toward the centre (stops at
1.5 × its scale from it): a bot by its root CFrame on the server, a player through its own client (victim stamps
TheriVortexBy, TheriVortexCenter, TheriVortexPull, TheriVortexUntil; TheriVortexPull.client 1.0 moves it). One vortex per
therizino (a new one replaces it).
**Bola** (switch TheriMovesBolaEnabled): charges TheriSnareMax, each back TheriSnareCooldown s after use (as the grapple's).
Target = nearest allowed dino within TheriSnareRange (flat) and BOLA_CONE (25°) of the heading. None → stamps a miss
(TheriBolaTarget "", TheriBolaEnd = root + heading × range), no charge used. Else a charge is used, stamps TheriBolaTarget,
TheriBolaFlight, TheriBolaAt (last); at t + 0.6 + flight: target gone / dead / KO / out of reach + 15 → TheriBolaResult "missed";
shielded → "shielded"; else 12 damage ("therisnare"), held TheriSnareRoot s (1.3's rope hold + slowed × 0.1), TheriSnaredUntil /
TheriSnaredBy on it, TheriBolaResult "hit", TheriBolaHitAt.
**Dash** (switch TheriMovesDashEnabled; characters get TheriDashMode = the switch): request dir = the move direction (flat);
zero → the root's look. Charges / refills = 1.3's grapple charges (TheriGrappleCharges / Cooldown / Left / ReadyAt). Path: a ray
at root height along dir for TheriGrappleRange studs (world only); a hit → stop 3 × scale short. Shorter than DASH_MIN (4) →
"blocked", no charge. Else stamps TheriDashFrom, TheriDashTo, TheriDashDelay (0.16), TheriDashTime, TheriDashAt (last);
TheriGrappleZip 1.3 (owner) holds still for the delay, then moves the root there in TheriDashTime and keeps 15% speed.
**Reel** (switch TheriMovesReelEnabled): target = nearest allowed within TheriHookRange and TheriHookCone (35) of the heading;
the world between the chest muzzle (role "muzzle", else "jib", else root) and the target blocks. None / blocked → claw shoots to
the aim end and back, no recharge (TheriReelResult "noTarget" / "blocked"). Else recharge starts, stamps TheriReelTarget,
TheriReelBrace (0.3), TheriReelFly, TheriReelTime, TheriReelResult "hit" / "shielded", TheriReelAt (last). The target is held in
place for brace + fly + reel (bot: root held; player: slowed × 0.1, HookHeldUntil). The owner's client flies it to REEL_GAP (7)
× scale studs in front of the target. At t + brace + fly + reel: target within REEL_REACH (gap + 12) studs and not shielded → 10
damage ("therihook"), TheriReelHitAt; star → stun TheriHookStun s + TheriStartCut (1.3's star). Else TheriReelResult "missed".

## Client
- **TheriGrappleZip 1.3:** dash mover (TheriDashAt) and reel mover (TheriReelAt, follows the target root); both stop when
  stunned / dead. The 1.2 lock-on stays off while TheriDashMode (MechaButtons never sets TheriGrappleHolding then).
- **TheriVortexPull.client 1.0 (new, StarterCharacterScripts):** the victim's own pull.
- **TheriMovesFX2.client 1.0 (new, StarterPlayerScripts):** all four moves' effects as the storyboard draws them.
- **TheriPose 1.8:** poses VORTEX (ARMS_UP → STAB), BOLA_WIND / BOLA_THROW, DODGE / SKID, HOOK_SET / REEL / SLASH.
- **TheriPartsAnim 1.2:** u for the new stamps (the chest claw's prongs open, the chain drum spins, the Storm Core glass shows
  while charging; hookhead pieces hidden while the claw is out).
- **MechaButtons 1.33:** with TheriDashMode the grapple button is a tap that sends the move direction; label DASH.
- **Looks (TheriPartsLooksV2 1.2):** zhook = Reaper Launcher (chest plate, barrel, brass muzzle, claw in the muzzle, chain
  drum), zgrapple = Storm Core (belly glass capacitor + coil, two shoulder Tesla coils). The back crane and the Belly Winch go.

## Red-team (synthesized)
1. **A 5 s vortex that drags players is strong in the Arena.** Same pull as the storyboard (6 studs/s), victims can walk out
   (pull < walk speed), and the ring is big and red so it is read. Accepted; numbers are SkillTree rows.
2. **Client movers and lag:** the owner's client moves the owner (as the grapple did); the server judges the slash by distance
   at the end, so a laggy reel just misses ("missed"), no teleport.
3. **The therizino stays free to move during the vortex** (the storyboard holds the stab pose): the pose holds only while
   standing still; walking ends it and the ring keeps spinning at its fixed centre. Flagged to Kepu.
4. **Players already slotted with the old moves** get the new ones with the same id; the steps stay; texts change. No save
   change.
5. **Phone:** the dash direction comes from Humanoid.MoveDirection, which the thumbstick drives, so it works the same.
