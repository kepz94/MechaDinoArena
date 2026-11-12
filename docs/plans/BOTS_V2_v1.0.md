# Mecha Dino Arena — Bots v2 (practice bots that play like real players)

**Goal:** the bots match is the first thing new players see, so its bots must feel like real players. They should cross water by
swimming, never freeze or sit around, come in a mix of skill levels, and use their attacks, their mecha buttons and their
movement parts (Raptor thrusters, Troodon portal feathers and so on) the way a player would.

**Kepu's words, 2026-11-11 20:39:** "The bots are still dumb. Fix the water make it swimable across. Bots keep getting stuck
there. Also some bots just sit in spawn after a while … mixed at all times. Some really hard bots and some easy ones … the damn
bots don't even use their attack buttons or their mecha … raptors using their mobility to fly over dashing and Troodon too.
Make this a realistic experience versus bots".

**Picks, 20:4x (AskUserQuestion):**
- Swim for everyone.
- Each team: 1 Elite · 1 Hard · 2 Normal · 1 Easy, tiers re-rolled at every respawn.
- Remove the EASY / NORMAL / HARD buttons; the lobby says MIXED BOTS.
- No tier tag over the bots.

## What I found (Studio, 2026-11-11 20:45, practice match, Normal bots, 4 minutes logged)

1. **"Sitting" bots are frozen bots (root cause).**
   - After a few fights, 2 of 9 bots had Humanoid.WalkSpeed 0.0055 and 0.0000 (expected 40.8 and 48.2). Clank the Teno sat
     at (458, 22, 71) for more than 60 s.
   - Cause: several scripts each run their own "bot slow" loop, and they fight each other:
     - TrooAttackServer, TenoMovesServer, TenoAttackServer, TheriMovesServer, HerreraMovesServer, MineServer and
       HeadbuttServer each keep a `botSlow` table.
     - Each Stepped frame, a loop sees WalkSpeed ≠ its own `set`, takes the current (already slowed) speed as its new `base`
       and multiplies again.
     - Two overlapping slows therefore compound every frame towards the 0.05 floor and below, and when both end they restore
       a near-zero "base".
   - Players don't suffer from this, because their client sets WalkSpeed every frame. Practice bots never reset it.
2. **Water:**
   - Lakes and rivers are parts: a "Water" surface at y ≈ −1.5 (no collide), with "Seabed" (top −8) and "Shallows" blocks
     underneath. A dino walks on the bottom, 6.5 studs under the surface, and has to climb 4–5 stud steps out.
   - Bots followed straight MoveTo lines into the south lake between Centre Meadow and East Shore, and got stuck at the
     banks. For example, Talon the Raptor sat at (348, 3, 125) in the water.
3. **Movement:**
   - Paths are used only for trips over 80 studs. Unstuck is a 10-stud sidestep (plus a jump the second time).
   - "Hold below" uses the closest spot reached so far. If the goal is taken while the bot is still at its spawn, that spot
     can be the spawn itself.
   - Team B respawns at x ≈ 470–660, which is 550–700 studs from Centre Meadow.
4. **Abilities:**
   - PracticeRules.BOT_LIVE = {} (empty), and bots use only their main attack.
   - Bots have parts in their steps and a loadout (PracticeLoadout), but SkillEffects never turns them into character
     attributes for bots.
   - No mecha part server has a bot entrance. There are 51 live button parts, 22 part servers and about 48 handlers.
   - Thrusters (MechaServer), Teno Hydraulic Leap, Therizino Dash, Troodon flap / portal and some others move the dino on
     the owner's client, so a bot has to be moved by the server.
5. **Skill:** one difficulty for every bot (PrDifficulty).

## Global constraints
- Additive only. Every change goes behind a switch, every number is an attribute, and every version is tagged in the
  headers, VERSIONS and ATTRIBUTES.
- PC and phone ship together. Never test with a second player. Bots match only: the Arena and the hub island don't change,
  except that swimming works everywhere.
- Bot XP stays at ×0.1. Bots never pick the T-Rex (as today).
- Bots can't see through walls. They sense like a player does today (cone, line of sight, cloak).

## Do-not-touch
- Player movement code: SprintTest, RamTest and MechaButtons physics.
- The part servers' player paths: every BotUse calls the existing handler, with its body unchanged.
- HardpointServer scoring; MatchAwards / HUD; SkillServer XP; the hub, portals and squads.

## Tasks

### T1 — PracticeRules 1.2 · Logic
- **Tiers.** `TIERS` table (react, sight, aimErr, abil, strafe, dodge, retreat, focusLow, lead, speedMul, thinkHz, jumpy):
  - Easy: react 0.9, aimErr 16, abil 0.15, no strafe or dodge.
  - Normal: react 0.5, aimErr 8, abil 0.45.
  - Hard: react 0.3, aimErr 4, abil 0.75, strafe and dodge.
  - Elite: react 0.18, aimErr 2, abil 0.95, strafe, dodge, focusLow, lead aim, combos, speedMul 1.0 (others 0.95).
- **Mix.** `TEAM_MIX = {Elite 1, Hard 1, Normal 2, Easy 1}`. `dealTiers(slots, rng)` gives each team that spread; a
  respawning bot gets a tier the living team can still use, so the spread holds.
- **Ability rules.** Pure functions: `abilityWant(kind, ctx) -> score`. kind = mobility / gapClose / escape / ranged /
  aoe / defend / heal / zone / trap. ctx = {dist, gap, hpFrac, foesNear, matesNear, onPoint, water, stuckFor, cdReady,
  tierAbil}.
- **Speed.** `slowMul(attrs, now)`: the product of the active `SlowMul_*` values, clamped to 0.25..1.
- Spec PASS.

### T2 — WaterSwim 1.0 (new server script) · Wired
- At start, while `WaterSwimEnabled`: Terrain water fills every water body. For each Seabed / Shallows part, and for each
  Ground part whose top is below −0.8, its XZ footprint is filled from the part's top up to the surface −1.5.
- Terrain.WaterTransparency is set to 1 and waves to 0, so the existing water parts keep the look. The old values are kept
  and put back when the switch goes off.
- Roblox's own swimming then works for every Humanoid: players and bots float, swim and climb out, and PathfindingService
  plans swims.
- Diagnostics: WaterSwimCells, WaterSwimState.
- Acceptance: a player dino and a bot swim across the south lake and climb out at both banks; a path is found across it.

### T3 — Bot slows owned by the brain (7 scripts, small additive blocks) · Wired
- In each `botSlow` loop, a model with `PracticeBot == true` (while `<Script>BotSlowAttrEnabled`) gets
  `SlowMul_<script>` / `SlowUntil_<script>` attributes instead of a WalkSpeed write.
- The brain sets WalkSpeed = base × tier × slowMul every tick.
- Acceptance: two overlapping slows on one bot → speed = base × m1 × m2 while both are on, and full speed after.

### T4 — PracticeBrain 2.0 movement · Wired
- **Speed owner.** See T3.
- **Paths.**
  - Every trip over 24 studs uses PathfindingService (Costs: Water 4; agent sized from the body). Waypoints, including
    Jump waypoints, are followed with lookahead.
  - Repath every 1.5 s, or when the goal moves more than 20 studs, or when stuck.
- **Unstuck ladder.**
  1. After 1.2 s with no progress, sidestep + jump.
  2. After 2.5 s, repath from a point 8 studs back.
  3. After 5 s, swim or jump across if in water, else walk to the last path waypoint that was reached.
  4. After 9 s, if no enemy can see it, it is moved to the nearest open spot on its path (logged in BotRescues).
- **Hold below.**
  - The climb timer starts when the bot first gets within 150 studs of the point, not at spawn or respawn.
  - The best spot can't be the spawn.
  - The Summit's hold spot is the highest spot reached.

### T5 — PracticeBrain 2.0 combat · Wired
- Per-tier micro:
  - **Melee:** orbit at reach and strafe. Hard and Elite side-jump when the enemy's attack starts (BiteStartedAt /
    PounceStartedAt / HeadbuttStartedAt / SlashStartedAt within 10 studs).
  - **Ranged (Troodon, Dilo darts):** keep 25–45 studs, backpedal and strafe.
  - **Focus:** Elite and Hard prefer low-HP enemies within reach and finish kills.
  - **Disengage:** under 30% HP with no mates near, back off to mates; come back over 60%.
  - **Lead:** Elite aims where the target will be.
  - **Easy:** slower reactions, wider aim error, sometimes loses track of its target (2 s), never strafes.

### T6 — SkillEffects 1.61 bot pass · Wired
- Every 1 s and on spawn, each practice bot runs the same effects path as a player, with BotProxy.of(model) as the player.
- Its loadout becomes SkillSlot1..4 on the model, from PracticeLoadout.
- The part attributes (DashEnabled, CloakTime, …) are then on the bot model, as on a player's character.
- Switch: SkillEffectsBotPassEnabled.

### T7 — Bot entrances for every button part (22 part servers) · Wired
- Each anonymous remote handler becomes a named local function, with its body unchanged.
- One "BotUse" BindableFunction per server: Invoke(model, partId, …same arguments…) runs the handler with
  BotProxy.of(model), behind a per-script switch.
- Parts the server moves on the owner's client get a bot move in the brain (T8).
- Acceptance per part: BotUse returns "ok" and the effect happens on a bot in Studio, or the part is listed as "not for bots"
  with the reason.

### T8 — PracticeKit 1.0 (new module, child of PracticeServer) + Brain 2.1 abilities · Wired
- **Per part:** kind, range, aim (self / dir / point / target), when (T1 rules), and the bot move for client-physics parts.
  Bot moves include: Thrusters dash + hop, Spring Jets, Hydraulic Leap, Theri Dash, Glider Wings, Servo Dash, Grappling
  Hook pull, Portal Feathers hop.
- **Mobility:**
  - Close a gap over 40 studs to the target.
  - Cross water or a ledge when the path says Jump or Swim.
  - Escape when low.
  - Raptor thrusters hop over water and climb ledges; Troodon portal / flap the same.
- **Attack parts:** used in range, aimed with tier aim error. Defensive parts are used when hit or low; heal parts when a
  mate is low.
- **Combos:** Elite only, e.g. Raptor Shock Mine then pounce, Pachy Grappling Hook then headbutt.

### T9 — PracticeServer 1.7 · Wired
- Tiers dealt per team (T1); a respawn re-rolls its tier.
- Loadouts: 4 slots from parts that work for bots (`BOT_LIVE` = parts whose BotUse answered "ok" in T7), with mobility
  first where the dino has one.
- PrDifficulty "Mixed", so the old difficulty request answers "mixed".
- Diagnostics: PrTiersA / PrTiersB.

### T10 — PracticeLobby 1.6 · Wired (UI)
- The EASY / NORMAL / HARD buttons are hidden, and the sub line says "MIXED BOTS".
- Switch: PracticeLobbyMixedEnabled.

## Deterministic map (bot life)

| State | Trigger | Next |
|---|---|---|
| spawn | placed on a spawn | move (job goal) |
| move | path to the goal | fight (enemy seen and allowed) / holdBelow (climb timer out) / swim (in water) |
| fight | target, tier micro | attack / ability / retreat (low HP) / move (target lost 2 s) |
| retreat | HP < 30% and outnumbered | move (HP > 60% or mates near) |
| stuck ladder | no progress 1.2 / 2.5 / 5 / 9 s | sidestep / repath / cross / rescue |
| slowed | SlowUntil_* in the future | same state at base × slowMul |
| dead | DummyHealth 0 | respawn after PrBotRespawn, tier re-rolled |

## Red-team (folded in)

1. **51 parts is a lot to do at once, so some won't work for bots.**
   - Mitigation: every part's BotUse is checked in Studio. Parts that fail stay out of BOT_LIVE, so bots never get a broken
     part, and each is listed with its reason.
   - Accepted: a few parts may ship "not for bots" in the first build.
2. **Terrain water could change how water looks, or make the game slow on phones.**
   - Mitigation: water transparency 1, no waves, fill only under the existing water parts. Switch off = today.
   - Check the frame time on phone emulation.
3. **Elite bots too strong for new players.**
   - Mitigation: Elite tuning is attributes. Each team has one Elite. Bot XP is still 10%.
   - Accepted: Kepu asked for "really hard bots".
4. **Rescue teleports look like cheating if seen.** Mitigation: only when no enemy has line of sight, and only after 9 s stuck.
5. **Think time:** 10 bots × paths + ability checks.
   - Mitigation: PrServerMs watched, with a budget of 4 ms a tick; path computes are rate-limited (at most 2 per tick for
     the whole server).
6. **Ability spam looks robotic.** Mitigation: tier `abil` chance, per-part cooldowns from the real attributes, and a
   0.3–0.8 s human-like delay.
