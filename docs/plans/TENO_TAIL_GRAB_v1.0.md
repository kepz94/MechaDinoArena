# Mecha Dino Arena — Teno Tail Grab A + Leap Landing L1 (plan v1.0)

**Goal:** the teno's tail really reaches a dino in front or behind, clamps it and throws it to the other side, smoothly on every
screen; a leap that comes down on a dino slams at once and shoves the dino out from under the body.
**Chosen direction:** Grab **A · Over the Top**, Leap landing **L1 · Shove Clear** (Kepu 2026-11-03 18:03: "Option A for both";
the leap options were L1 / L2, L1 is the first). Mockup `docs/mockups/teno_tail_grab_v0.1.html`.
**Root causes (Studio, 2026-11-03, client per-frame logs):** see the bug notes in the mockup. In short: TenoMovesServer 1.6
CFrames an anchored bot on the server every Heartbeat (clients see ~30 Hz steps, the carry reads the server's unanimated tail
tip so it never moves); the grab's stun makes BotServer 1.24 `lieDown` at once (sinks 0.3 s, `downFrom` = the grab spot) and
`standUp` later rolls it back up at the grab spot underground; `jumpSlam` measures height over ground with Bots and players
excluded, so standing on a dino is "still in the air"; many bots have automatic network ownership (owned by the nearest
player after an anchor / unanchor cycle).

## Global constraints
- Additive, every change behind a switch (default on; off = the previous version exactly). Version branding in headers,
  VERSION, docs/VERSIONS.md, docs/ATTRIBUTES.md. Diagnostics in attributes.
- Studio HTTP off: install with multi_edit / execute_luau, verify by hash. Commit + push each change.
- No HUD change in this plan (if one appears: PC AbilityBar AND touch ArenaTouch together).
- Saved progress (SkillPath_ / SkillSlot) untouched. Numbers unchanged: TenoGrabDamage / Stun / Fling / Range, TenoLeap*.
- Publish only on Kepu's word.

## Do-not-touch
StunClient (players keep the existing StunToss path), pickGrab's target rules (v1.2 any direction already), Mortar / Stomp /
Bellow / Mud, TenoAttackServer, the teno leap launch (TenoLeapLaunch / JumpServer / JumpTest), BotServer AI behaviours other
than the three guards below, TenoPartsServer (the clamp jaws stay static parts).

## Tasks

### Task 1 — BotServer 1.25: grab hold, get-up where it is, server ownership guard · Wired
- `step()`: while bot attribute `TenoGrabHeldUntil` > server now: BotState "grabbed", no lieDown / AI (the mover owns it).
  Switch script `BotGrabHoldEnabled`.
- `standUp`: if the root is more than 1 stud (flat) from `downFrom`, `downFrom` / `downGround` are re-read from where it is
  now (a bot moved while down gets up there). Switch `BotDownRefreshEnabled`. Diagnostic bot `BotDownRefreshes`.
- `step()`: a not-anchored bot whose root `GetNetworkOwner()` is not nil gets `SetNetworkOwner(nil)`. Switch
  `BotOwnerGuardEnabled`. Diagnostic script `BotOwnerFixes`.
- Acceptance: a grabbed bot never shows BotState "stunned" before it lands; after landing it lies and gets up at the landing
  spot (Y within 0.5 of a normal stand); `GetNetworkOwnershipAuto` false / owner nil on every unanchored bot after 2 s of Play
  near them; each switch off = 1.24.

### Task 2 — TenoMovesServer 1.7: Over-the-Top grab (server) · Wired
- Side = HRP-space Z of the target root < 0 → "front", else "back". Timeline from the press t: front catch t + 0.70, throw
  t + 1.35; back catch t + 0.45, throw t + 1.10; flight FLIGHT_A 0.85 s; land = flat facing at the throw: front → root −
  fwd × fling (behind you), back → root + fwd × fling (in front).
- Stamps on the teno: `TenoGrabSide`, `TenoGrabCatchAt`, `TenoGrabThrowAtPlan`, `TenoGrabFlight`, ObjectValue child
  `TenoGrabTargetRef` (= target), then `TenoGrabStartedAt` last (existing). `TenoGrabLand` is stamped 0.15 s before the throw
  (lead for the clients), `TenoGrabThrowAt` / `TenoGrabLandAt` as now.
- Bot: anchored at the catch and NOT moved by the server until the landing; `TenoGrabHeldUntil` = land time + 0.05;
  `Bitable` false while held (restored at the landing; nothing hits the server copy at the grab spot). At the landing:
  CFrame at the land point (flat, facing away), damage + stun as now; BotServer then lies it down there.
- Player target: unchanged (stunned in place, StunClient toss), toss direction = the side rule above.
- Switch script `TenoMovesGrabOverTopEnabled` (false = 1.6). Diagnostics: teno `TenoGrabSide`; script `TenoMovesGrabsFront`
  / `TenoMovesGrabsBack`.

### Task 3 — TenoBotMotion 1.0 (new LocalScript, StarterPlayerScripts): draws held / thrown / shoved bots · Wired
- Every client, RenderStepped, for each teno character with a fresh v1.7 grab: catch − 0.12 → catch: pull the bot root from
  where it stands to the clamp point; catch → throw: bot root = local `Tail5_main` × (−2.6 × scale, 0, 0) + (0, −4.2 × scale ÷ 2,
  0) hanging (roll 150°); throw → throw + flight: ballistic from the release point to `TenoGrabLand` + lift (peak 16, one
  forward flip; until `TenoGrabLand` arrives the land is predicted from the local facing, then blended to the stamp over
  0.1 s); after: stop (the server's CFrame takes over).
- Bots with `TenoMoveAt` (Task 5): from `TenoMoveFrom` to `TenoMoveTo` over `TenoMoveTime` with arc `TenoMovePeak`.
- Local CFrame writes only on anchored bot roots. Switch: script attribute `TenoBotMotionEnabled`. Diagnostics on the
  player: `TenoBotMotionVersion`, `TenoBotMotionActive`.

### Task 4 — IdleAnimation 1.41 + TenoPose 1.9: the tail reaches the dino (IK) · Wired
- TenoPose 1.9 `grabPath(side, t, targetLocal)` returns the clamp goal (HRP space) and body lean: wind-up 0.25 s to
  TAIL_DOWN; front: arc over the back (bezier via (0, 36, hips + 2)) onto the target's back, lift to (0, 30, hips + 1), whip
  to (0, 12, tip + 6); back: straight to the target's back, lift over, whip to (0, 18, snout − 2); recover 0.9 s.
- IdleAnimation 1.41: when `TenoPose.phase` is "tgrab" and `TenoGrabSide` is set, solve Tail1..Tail5 pitch / yaw (limits
  pitch −118..48, yaw ±82) by coordinate descent on the existing restC0 forward kinematics (warm start, 6 sweeps), and use
  those tail angles instead of the 1.3 keyframes. Switch model `TenoGrabIKEnabled` (false = TenoPose 1.8 keyframes).
  Diagnostic `TenoGrabIKMiss` (studs from the clamp to the goal).
- Acceptance: clamp-to-goal miss ≤ 1.5 studs for front and back targets at 0–12 studs from the head / tail tip; ≥ 55 FPS
  with 3 tenos grabbing (Studio).

### Task 5 — TenoMovesServer 1.7: leap L1 Shove Clear · Wired
- `jumpSlam` landing: also landed when a downward ray from the root that only excludes the teno itself (and the FX folders)
  hits a candidate dino within h0 + 1.5 (standing on it). Switch `TenoMovesLeapOnDinoEnabled`.
- Shove: each slammed target whose root is inside the teno's hitbox footprint (flat, expanded by 1.5) moves out to the
  nearer side (root-space X sign; 0 → right) to footprint half width + its own half width + 2: bot = anchored,
  `TenoMoveFrom/To/At/Time 0.28/Peak 3` stamps, server CFrame at the end, then the stun (lies down there); player =
  `StunTossFrom` / `StunTossDistance` / `StunTossAt` sideways. Switch `TenoMovesLeapShoveEnabled`. Diagnostic teno
  `TenoLeapShoves`.

### Task 6 — Docs + Studio check
VERSIONS / ATTRIBUTES rows; Play checks: front grab, back grab (bot + log no snap-back, smooth 60 Hz positions in a client
log), leap onto a frozen bot (slam at touchdown, bot beside the body, teno on the ground), screenshots.

## Red-team (folded in)
1. **Server copy of a flying bot sits at the grab spot** → Bitable false while held (Task 2). Accepted: bots can't be hit by
   anyone else during the 1.2 s hold.
2. **Clients see the land stamp late** → stamped 0.15 s before the throw + local prediction and blend (Task 3).
3. **IK can't reach / looks wrong on the real rig** → miss diagnostic + the 0.12 s pull-in to the clamp; switch back to the
   keyframes (Task 4).
4. **Players aren't carried** (the server can't move a player body smoothly) → accepted, out of scope; players keep the toss
   with the new direction.
5. **BotServer is high-functioning** → three isolated guards, each its own switch.
