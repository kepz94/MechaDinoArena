# Mecha Dino Arena — Pre-match lock + camera fly-over + intro bodies v1.0

**Ask (Kepu 2026-11-13 18:23):** "some dinos 3d body don't fully load up on the intro screens. Also during the countdown for game start the camera should pan to the point then pan back to the dinos and all mecha abilities and actions should be unplayable because as of right now it lets me use them during the count down".
**Mockup:** docs/mockups/prematch_pan_lock_v0.1.html. **Picks:** camera "A · Fly over", buttons "A · Locked", strictness "A · Locked everywhere".

## Root cause — intro bodies (bug)
- Code facts:
  - PregameModels 1.0 builds the bodies and parts at runtime, 3 s after the server starts, with a `task.wait()` between builds.
  - An Arena match is a fresh private server (PracticeServer 1.10), so players are already on the lineup while the bodies replicate. Each body is about 300 instances.
  - PregameScreen 1.2's `dinoView.set` caches its key, and `refresh()` only re-runs when the roster signature changes. So a view that cloned a body mid-replication keeps the partial copy, and a view that found no body stays empty.
- Studio cannot show this: all 8 bodies were complete on the client (replication is local).
- Not reproduced live. Kepu was asked for a screenshot.

## Rules
1. **Lock signal.** PracticeServer 1.12 sets the character attribute `PrematchLockUntil` on every held human: the server time `HpPointEndsAt + 0.25`, refreshed on each place.
   - It is set to 0 when HpPhase turns "live" and when the hold is released.
   - The lock is active while `PrematchLockUntil > server time`, so it expires on its own even if a clear is missed.
   - Switch: `PrPrematchLockEnabled` (default true, read per place). False means no attribute is set and nothing is locked.
2. **Server gate (every combat / part remote).** A request from a player whose character is locked is dropped before the handler runs.
   - The botHook shim (19 servers) wraps `fn`. Direct handlers are wrapped at their Connect.
   - Bots are never locked (BotUse / BotMechaUse call the handlers directly).
   - Scripts: Adrenaline, Bite, Cloak, DiloAttack, DiloMoves, EnergyShield, Headbutt, HerreraMissile, HerreraMoves, Hook, Ink, Jump, Mecha, MedStation, Mine, Pounce, Ram, Roar, Scent, Screech, ServoDash, Slash, TenoAttack, TenoMoves, Tether, TheriAttack, TheriMoves, TrooAttack, TrooMoves, TrooSlot, Visor.
   - Not gated: Survival (eat / drink), Climb, Creep, Stamina, Turn, menus.
3. **Client gate (no local prediction).** While locked, presses do nothing in: MechaButtons (press / aimStart / tacStart; the guard sits before MechaButtons' PC-only return so keys are covered — found in the Studio test), SlashTest, BiteTest, DiloAttackTest, TenoAttackTest, TheriAttackTest, TrooAttackTest, HeadbuttTest, RamTest, PounceTest, JumpTest, RoarTest. The press functions are wrapped additively.
4. **Locked look (pick A).** While locked, every tile / button gets a lock overlay that is removed when the lock ends:
   - the overlay is dark (black, 0.45 transparent);
   - a padlock (shackle + body, light grey) sits in the middle;
   - it covers AbilityBar tiles (PC), MechaButtons touch slots and ArenaTouch styled buttons (phone).
5. **Fly-over (pick A).** PrematchCam 1.0 (new, StarterPlayerScripts) runs while Practice `PrPrematch` and HpPhase "warmup", with L = HpPointEndsAt − now:
   - L > 9: normal camera.
   - 9 → 7: takes the camera (ShoulderCamExternal, Scriptable) and glides from the current view up over a high midpoint to the orbit start.
   - 7 → 5: circles P1 (HpPoints[HpIndex or 1]) at PanOrbitRadius 60 / PanOrbitHeight 70, looking at the point; it starts from the side facing your dino.
   - 5 → 3: glides back to the saved view.
   - L ≤ 3: hands the camera back.
   - Late join with L ≤ 7 (PanOrbitAt): no pan.
   - Death / menu / phase change: hands back at once.
   - Character attribute `PrematchPanning` is set during the pan.
   - Switch: `PrematchCamEnabled`. All timings and distances are attributes.
6. **Chip.** PrematchCountdown 1.1: the bottom chip reads "HELD UNTIL GO" while `PrematchPanning`, otherwise "HELD UNTIL GO · LOOK AROUND".
7. **Intro bodies.**
   - PregameModels 1.1 stamps `PieceCount` (descendant count) on every Body and part model before parenting.
   - PregameScreen 1.3:
     - `rig()` waits for completeness: a body / part counts only when its replicated descendant count ≥ PieceCount (no attribute = complete).
     - The view key carries a readiness flag.
     - `refresh()` also re-runs when the client's count of complete models changes.
     - So a missing or partial body shows once it is complete.
   - Switch: `PregameWaitCompleteEnabled`.

## Tasks (MDA-526..531)
1. MDA-526 PregameModels 1.1 + PregameScreen 1.3: intro bodies wait until complete (rule 7).
2. MDA-527 PracticeServer 1.12: PrematchLockUntil (rule 1).
3. MDA-528 Server gates (rule 2), each script +0.1.
4. MDA-529 Client gates (rule 3), each script +0.1.
5. MDA-530 Lock look: AbilityBar 1.44, MechaButtons 1.50, ArenaTouch 1.21 (rule 4). MechaButtons 1.50 also carries rule 3.
6. MDA-531 PrematchCam 1.0 (new) + PrematchCountdown 1.1 (rules 5–6).

## Do-not-touch
Bots (never locked), the hold itself (PracticeServer 1.11 anchoring), the countdown text and layout, the HardpointHUD P1 marker, the cooldowns and numbers of every part.

## Red-team (folded in)
- **A lock that never clears would ruin the match.** It is a self-expiring time (`PrematchLockUntil`), not a boolean. It is also cleared at "live" and on release.
- **About 45 scripts touched means a wide regression surface.** The change is one identical wrapper per remote, and handler bodies are unchanged. Every script is hash-checked. The Studio test covers a locked press and a press after GO on 3 species (Herrera, Dilo, Raptor), PC + forced touch.
- **The camera could fight ShoulderCam / CameraModes / the Cruise Missile cam.** It uses ShoulderCamExternal, the way the Dilo scope and the Cruise cam do. It never takes the camera if another owner has ShoulderCamExternal set.
- **The pan blocks looking around during the countdown.** This is accepted (Kepu's ask). The last 3 s are free.
- **The intro bodies are not reproduced.** The fix is safe either way: it waits for a complete copy. The live check is a pending_human item.
