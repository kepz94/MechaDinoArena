# Mecha Dino Arena — Pushed into the map: fix + auto-free v1.0

**Report (Kepu 2026-11-15 11:18):** "I got stuck in the island and couldn't do anything about it. How about a button for getting you unstuck unless you can totally fix the island issue". At 11:22: "i was pushed into the ground from an attack and i was in the map".
**Screenshot:** a practice match (P3 · SECURED, 82–6), as Herrera, with the camera inside the ground.
**Mockup:** docs/mockups/unstuck_v0.1.html. Kepu's picks:
- "B · Auto prompt only", then "how would you detect if a player is stuck … i need you to actually be able to for sure identify when a player is stuck".
- "Nearest open ground".
- Final: "Both, but free me automatically". So there is no prompt and no new UI.

## Today (code facts)
- Every knockback on a player goes through the same path:
  - **Which attacks:** Pachy headbutt (HeadbuttServer), Teno shove (TenoAttackServer), Herrera Stun Breaker (HerreraMovesServer push), Dilo hiss (DiloMovesServer shove), Troodon shove (TrooMovesServer).
  - **How:** they set HeadbuttShoveFrom / Dist / Time / At on the player's character, and the owner's HeadbuttShove 1.0 pushes the body.
  - **The push:** a plane-mode LinearVelocity at up to 2 × dist / time studs/s (40 studs in a short time), with MaxForce = mass × 20000.
  - **Why it sticks:** nothing checks what is ahead, so the body can be driven through block edges into the ground, steps or rocks.
- The map's solid pieces are all Block Parts: DinoIsland.Ground 4667, MountainSteps 1065, Rocks 173, EdgeWalls 4, Trees 2940 (collidable). There is no Terrain. Water is non-solid parts (LakeWater, Water).
- The dino's collision body is its HumanoidRootPart. The T-Rex HRP is 6.5 × 8.5 × 8.7. The body center sits HipHeight + half the HRP height above the feet.
- Only the bots unstick themselves (PracticeBrain).

## Rules
1. **The push stops before entering the map (HeadbuttShove 1.1).**
   - Every Heartbeat of a push, a Blockcast of the HRP is run along the push. The box is the HRP size × (ShoveCastScaleXZ 0.9, ShoveCastScaleY 0.6, 0.9). The distance is this frame's travel + ShoveCastAhead (1.5) studs.
   - It only sees collidable parts in DinoIsland Ground / MountainSteps / Rocks / EdgeWalls / Trees.
   - A hit whose surface is not floor-like (normal.Y < ShoveFloorNormal 0.6) ends the push. The constraint is turned off and HeadbuttShoveState becomes "blocked".
   - Switch: character attribute ShoveBlockEnabled.
2. **Exact stuck detection (StuckServer 1.0, new, ServerScriptService).** Every StuckTick (0.5) s, for each player with a live, unanchored body (not InMenu, not RespawnHold):
   - **Inside:** a body point is inside a solid block. The points are the HRP center and a point StuckLowFrac (0.25) of the HRP height below it. The test is exact: the point is in the block's object space, StuckInset (0.25) inside every face. Candidates come from GetPartBoundsInRadius. The solid set is Ground / MountainSteps / Rocks / EdgeWalls; Trees are not used, because climbing goes through leaves.
   - **Under:** a ray up from the center hits the underside of a solid block (normal.Y < -0.5) within StuckUpRange (400), and a ray down finds no solid floor within StuckFloorRange (60).
   - Stuck = the same answer on StuckConfirm (2) checks in a row, so at least 0.5–1 s.
3. **Auto-free (StuckServer 1.0).** Find the nearest open ground around the stuck spot:
   - Rings every StuckRingStep (4) studs out to StuckRingMax (120), with 16 directions per ring.
   - For each spot: a ray straight down from y 1000 over the solid set + Trees. The hit must be on Ground / MountainSteps / Rocks with normal.Y > 0.8. The spot must not be in water (no water part within 1.5 studs above the top). The standing body box (the HRP at its standing height, × 0.95) must be clear of the solid set + Trees.
   - Move: the root is anchored and server-owned, then pivoted to the spot. The flat facing and velocity are kept at zero. After StuckHold (0.3) s it is unanchored with ownership back to auto.
   - None found: the SpawnLocation top.
   - Player attributes StuckLast ("inside" / "under"), StuckFreedAt, StuckFreeDist. Script counters StuckFrees and StuckNoSpot.
   - The same player isn't checked again for StuckCooldown (2) s.
   - Switch: StuckServerEnabled.
4. **Scope.** Players only: island, practice and Arena (all servers with DinoIsland). Bots unchanged. No UI.

## Tasks (MDA-546..547)
1. MDA-546 HeadbuttShove 1.1: rule 1.
2. MDA-547 StuckServer 1.0 (new): rules 2, 3.

## Do-not-touch
The five attack servers (their shove stamps), bot knockbacks, SpeciesServer, HubServer / PracticeServer placement, ClimbTest.

## Red-team (folded in)
- **"A false positive teleports a player who wasn't stuck."**
  - The body center never enters a block during normal movement.
  - "Under" needs a solid ceiling above *and* no floor below, so standing under a mountain trail doesn't count.
  - Two checks in a row are needed.
  - Trees are left out of the detection because climbing passes through leaves.
- **"The push stops early on bumpy ground."** Floor-like hits (normal.Y ≥ 0.6) don't stop it, and the cast box sits above the feet.
- **"Being freed into water or inside a tree."** Water is skipped, and the body box must be clear of the solid set + Trees.
- **"It gets used as a teleport."** There is no button. Only the server's own detection triggers a free.

## Studio test (2026-11-15, bots match, Herrera, PC)
- **No false frees:**
  - 20 s walking 144 studs across the island.
  - 24 s on the mountain trail, from height 197 down to 12.
  - In both, StuckFrees stayed the same.
- **Shallow sink (6 studs):** Roblox physics pushed the body back out by itself, so it was never stuck.
- **Deep sink (25 studs, like the report):** freed after 1.08 s. StuckLast "under", moved 28.9 studs onto open ground, feet 0.3 above the ground.
- **The exact inside test on map blocks:** 139 sampled block centers all read inside. 2 of 139 points 0.3 above a block's top read inside, because another block sits on top there, so that spot really is solid.
- **Shove into a MountainStep face** (40 studs, 0.4 s, 12 studs of run-up): HeadbuttShoveState "blocked" after 8.1 studs, before the face.
- **Shove over open ground:** moved 39.8 of 40 studs.
