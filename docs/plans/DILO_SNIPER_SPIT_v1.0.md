# Mecha Dino Arena — Dilo Sniper Spit v1.0

**Ask (Kepu 2026-11-13 15:38):** "For the dilo, if you hold the attack button for 1.5s it goes into fps mode where you're aiming the head of the dilo manually no aim assist and it shoots the spit twice as fast with all the damage into one ball with twice the range like a sniper shot."
**Mockup:** docs/mockups/dilo_sniper_spit_v0.1.html. **Picks:** "A · Head cam", "Whole clip: 25, then reload", "Let go of attack", "Spit on release", "Build it".

## Rules
- Spit-only dilo. A tap (press + release before 1.5 s) = the normal spit, fired on release.
- Hold 1.5 s (`DiloSnipeHold`) with a full clip -> aim mode: first-person camera at the head, no aim assist, zoom (FOV 50). Release = fire; Cancel input = no shot.
- Not a full clip at 1.5 s: no aim mode; the release fires a normal spit.
- The ball: 25 damage (`DiloSnipeDamage`; Cold Blood multiplies as the dart), the spit's poison as now, 2x range (`DiloSnipeRangeMul` x DiloDartRange = 120), 2x speed (`DiloSnipeSpeedMul` x DiloDartSpeed = 80), straight along the aim, stops at the world / a Sap Wall. Uses the whole clip -> the usual reload.
- PC: mouse turns the head. Phone: drag the thumb that holds ATTACK (or any touch on the right side). Gamepad: right stick.

## Do-not-touch
Dart numbers / aim assist for normal spits, ammo / reload numbers, bots (BotUse), Overdrive / Gatling, camera modes outside aim mode.

## Tasks
1. **DiloAttackServer 1.11** — request `("snipe", stamp, dir)`; full clip required ("notFull"); line hit (first dino whose body passes within `DiloSnipeRadius` 1.5 x scale of the line at landing), world raycast stop, Sap Wall, Deflector Claws, shield, plating; stamps DiloDartFrom/To/Target/Flight + `DiloSnipeAt` (= DiloDartAt) then DiloDartAt; hit via DiloHitAt as the dart. Switch `DiloSnipeEnabled`.
2. **DiloAttackTest 1.5** — spit on release; hold -> coil pose (existing stamps) -> aim at 1.5 s with a full clip; release fires `snipe` along the camera's look; clip -> 0 locally. Switch `DiloAttackTestSnipeEnabled`.
3. **DiloSnipeCam 1.0 (new)** — owns the camera while `DiloSnipeAim`: head cam, FOV 50, look input (mouse / touch / pad), body turns to aim (TurnLimit aim look); charge ring from 0.25 s of the hold, green crosshair + "SNIPER SPIT" in aim. Restores the camera after. Switch `DiloSnipeCamEnabled`.
4. **ShoulderCam 1.10** — steps aside while `ShoulderCamExternal` is true (no framing, no Classic claim). Switch `ShoulderCamExternalEnabled`.
5. **DiloFX 1.5** — a snipe ball is 2x the glob, brighter; hit = big splash + "-25" pop. Switch `DiloFXSnipeEnabled`.

## Red-team (folded in)
- **Taps now fire on release** (Kepu's pick): a tap is ~0.1 s later. Accepted.
- **Camera fights:** ShoulderCam / Classic claim would take the camera back every frame -> the external flag (Task 4).
- **Moving targets:** the ball flies straight with no homing; the hit is checked along the line at landing (lead your shot). That is the sniper skill.
- **Phone thumbs:** the ATTACK thumb aims by dragging; the move stick stays on the left.
- **Bots** never send "snipe"; unchanged.
