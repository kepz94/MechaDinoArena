# Mecha Dino Arena — Pachy stat lines v1.0: Last Stand + Head Down

**Goal:** the pachy gets a Health line and a second Defense line of its own, so its tree has 5 passive lines like the
Raptor and Therizino (today 3: Battering Dome, Bone Crest, Sprint Legs).
**Chosen direction:** Health B "Last Stand" + Defense A "Head Down" — Kepu 2026-11-04 00:02 ("Option B for health and
option A for defense"); mockup docs/mockups/pachy_health_defense_options.html v0.1 (artifact 93oLym8CydU5Ek9WcUfhqn).
**Architecture:** the Teno stat rows' pattern (SkillTree TENO_STATS / SkillEffects TENO_ATTRS / TenoStatsServer): two
pachy-only passive rows in SkillTree; SkillEffects writes their numbers to character attributes (one writer); a new
PachyStatsServer does the damage cut (Brace's refund on Humanoid.HealthChanged) and the no-shove switch while charging;
SkillEffects' existing StunnedUntil hook gets a Head Down branch; HeadbuttServer reads one more refill multiplier.

## Global constraints
- Additive only, each piece behind a switch; version branding in every header, VERSION constant, docs/VERSIONS.md and
  docs/ATTRIBUTES.md.
- Kepu's rule (2026-10-30): no health regen and no health steal on the pachy. Nothing here heals; the damage cut is a
  refund of part of a hit inside the same server step (Brace I's way), shown as "takes less damage".
- Saved progress is untouched (SkillPath_* / SkillSlot): new rows start at 0 for everyone.
- Steps cost 1 / 2 / 3 / 4 (SkillTree.COST); build limits unchanged (40 points, 3 lines at step III or higher, 4 slots).
- Install by multi_edit, verify by hash; Studio Play on one player only; publish only on Kepu's "Publish" (both places).

## Do-not-touch
Bone Crest, Battering Dome, Blood Rush, Sprint Legs and every pachy part; the shared Regeneration / Lifesteal / Jaws /
Thick Hide rules (still blocked for the pachy); the Teno's TenoStatsServer and Brace; HeadbuttServer's damage, run-up,
shove and Blood Rush logic (only the refill length gains a factor); other dinos' trees.

## The two rows (texts as the mockup; numbers are attributes)
| Row | I (1) | II (2) | III (3) | ★ (4) |
|---|---|---|---|---|
| Last Stand (Health) | below 30% health: take 15% less damage | 25% less | below 30%: headbutt charges refill 40% faster | once per life, the first time you drop below 30% health you are untouchable for 1.5 s |
| Head Down (Defense) | while charging a headbutt: take 15% less damage | 25% less | while charging: can't be shoved | while charging: can't be stunned |

## Deterministic map
- Charging = HeadbuttStartedAt > max(HeadbuttEndedAt, HeadbuttHitAt) (HookServer 1.x uses the same test).
- Low = Humanoid.Health < PachyLastStandBelow (0.3) x MaxHealth, measured after the hit.
- On each Humanoid health drop (HealthChanged, not our own write; h > 0; pachy; PachyStatsServerEnabled):
  - cut = max(Head Down cut if charging, Last Stand cut if low) — they do not stack (the larger wins);
  - Last Stand counts only the part of the drop that is below the 30% line (a hit from 50% to 20% gets the cut on the
    10% under the line); Head Down counts the whole drop;
  - refund = counted drop x cut; Health = min(MaxHealth, h + refund); a killing blow (h <= 0) is not refunded
    (Brace's rule: Humanoid death cannot be undone).
- Head Down III: while charging, character HeadbuttShoveEnabled = false (HeadbuttShove client 1.0 skips the push; covers
  pachy headbutts, teno scratch shove, Dome Visor knock, Stun Breaker push — TenoStatsServer 1.1's list); back to nil
  when the charge ends; never fights TenoStatsServer (a pachy is never a teno).
- Head Down ★: SkillEffects' StunnedUntil hook: charging and PachyHeadDownNoStun -> StunnedUntil = now,
  SkillStunTrimmed "headdown" (Brace II's branch). Dazes, blinds, tethers, pins are not stuns and still apply.
- Last Stand ★ (R1): the first health drop of a life that ends below the 30% line (not a killing blow) starts the
  untouchable window: PachyLastStandUntil = now + PachyLastStandTime (1.5), an invisible ForceField
  "PachyLastStandField" under the character until then (blocks Humanoid:TakeDamage and ArenaPvP's player damage, like
  the Energy Shield's), and any health drop inside the window is refunded in full (catches damage that skips the
  ForceField); used once per character (a respawn is a new life). PachyLastStandUsed = true. A killing blow is never
  refunded.
- Last Stand III: HeadbuttServer refill length x PachyLastStandRefillMul (1 / 0.714 = 40% faster) while low at the
  moment a refill starts (a refill already running keeps its length).
- Off / unbought: every new attribute at its off value (cut 1, refill mul 1, flags false) -> nothing happens.
- Diagnostics: character PachyStatsCut (last cut used), PachyStatsRefunded (total), PachyStatsLow, PachyStatsCharging;
  script PachyStatsServerVersion, PachyStatsRefunds.

## File map
- Modify `src/shared/SkillTree.luau` 1.59: PACHY_STATS flag; rows "laststand" (area health) and "headdown" (area
  defense), dino "Pachy"; effects fields lastStandMul, lastStandBelow, lastStandRefillMul, lastStandStar, headDownMul,
  headDownNoShove, headDownNoStun (off values elsewhere).
- Create `tools/tests/SkillTreePachy.spec.luau` 1.0 (Logic).
- Modify `src/server/SkillEffects.server.luau` 1.40: PACHY_ATTRS (like TENO_ATTRS / THERI_ATTRS), Head Down ★ branch.
- Create `src/server/PachyStatsServer.server.luau` 1.0: refund, shove switch, diagnostics.
- Modify `src/server/HeadbuttServer.server.luau` 1.15: refill x PachyLastStandRefillMul while low.
- Docs: VERSIONS, ATTRIBUTES; captures docs/reference/pachy/.

## Tasks
1. **SkillTree 1.59 + spec · Logic** — red spec first (rows exist for Pachy only, texts, effects per step, off values
   for every other dino, build limits still hold), then the rows; spec green; existing specs still green.
2. **SkillEffects 1.40 · Wired** — PACHY_ATTRS written on buy / respec / species switch; Head Down ★ stun branch.
3. **PachyStatsServer 1.0 · Wired** — the deterministic map above.
4. **HeadbuttServer 1.15 · Wired** — refill factor while low.
5. **Studio check + docs · Wired** — bought rows (SkillPath set on the test player only, then cleared), held bot hits:
   charging cut 15 / 25%, low cut on the part under 30%, killing blow not refunded, shove skipped while charging (III),
   stun cleared while charging (★), refill 40% faster while low (III); nothing on raptor / teno / therizino; skill screen
   shows both rows on the pachy only; ★ window once per life (second dip below 30% does nothing).

## Red-team (settled with Kepu 2026-11-04 00:0x)
- **R1 — Last Stand ★ "survive a killing blow once per life" has no safe hook.** Damage reaches Humanoid.Health from about
  20 scripts, and each stamps the kill (KilledBy / KilledAt -> kill XP, kill heal, Teno Survivor, goals) before or as
  health hits 0; a Roblox Humanoid at 0 is dead and cannot be revived. A death guard would have to change every one of
  them. Proposal: ★ = "Once per life, the first time you drop below 30% health you are untouchable for 1.5 s" (an
  invisible ForceField like the Energy Shield's; no death hook, no fake kills). **Kepu: "Untouchable at 30%".**
- **R2 — the cut cannot stop a killing blow.** Like Brace, a hit that takes the pachy to 0 is not refunded. Last Stand
  helps over a fight, not against one big hit. Accepted risk unless Kepu objects.
- **R3 — "can't be shoved or thrown" was the mockup text.** Only the shoves listed above go through HeadbuttShoveEnabled;
  Tail Grab flings, Shock Mine blasts and ram tosses use other paths. Proposal: III text "can't be shoved" (as in the
  table above). **Kepu: "Shoves only".**
- **R4 — "can't be stunned" is StunnedUntil only** (same as Teno Brace II). Strobe daze, Ink blind, Tether, pins still
  land. Text stays "can't be stunned"; noted.
- **R5 — overlap with the Teno's Brace** (damage cut while committing to an attack). Different trigger (charging a
  headbutt vs holding a slam) and no stack/heal parts; accepted.
