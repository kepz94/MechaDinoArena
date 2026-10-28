# Mecha Dino Arena — Raptor pack section v1.0

**Goal:** a new raptor player meets lone raptors first; packs live in their own later part of the raptor half.
**Kepu (2026-10-28):** "how am i supposed to kill a pack of raptors. maybe just have there be individual ones in the beginning" /
"packs are in their own later section of the raptor half". Picks: layout **A · Bands** (docs/mockups/pack_section_options.png),
**about 7** lone raptors, **keep 4 packs of 3**. No level gate (bands, not levels).
**Chosen direction:** split the raptor zone (x >= 40, z <= 560, not near spawn) at z = -190:
- RaptorSolo: z > -190 (nearer the spawn) — lone raptors only.
- RaptorPack: z <= -190 (the far half) — packs only.

## Global constraints
- Studio target: cloud place Mecha Dino Arena, placeId 84022023159448. Check `game.PlaceId` before every install.
- Additive; header vX.Y + changelog + version attribute + VERSIONS row + ATTRIBUTES section; hash + compile check.

## Do-not-touch
- Pack behaviour (leader / follow / flank / grudge / avoid), roam spot maths, bite / pounce code, T-Rex zone, RaptorScale.

### Task 1 — Territory 1.1 · Mode: Logic
Files: `src/shared/Territory.luau`, `tools/tests/Territory.spec.luau`.
- `Territory.PACK_SPLIT_Z = -190`; `ZONES.RaptorSolo` (Raptor and z > -190), `ZONES.RaptorPack` (Raptor and z <= -190);
  `Territory.BANDS`.
- `home(zone, pos)` for a band: pos, x mirror, z mirror, both mirrors, else nil. TRex / Raptor home unchanged (v1.0).
Acceptance: spec PASS (old 28 + band cases).

### Task 2 — BotServer 1.13 · Mode: Wired
Files: `src/server/BotServer.server.luau`.
- `BotPackSectionEnabled` (default true). `zoneFor(species, multi)` / `botZone(b)`: a raptor in a pack of more than 1 →
  RaptorPack, else RaptorSolo. Every v1.12 territory call (home, wander, roam spots / paths, chase pick / border drop,
  grudge, avoid) uses the band.
- Pack tables carry `size`. `BotSoloExtra` (5) more roam groups Solo1..Solo5 of 1 raptor while the section is on at start
  (Roam3 + Roam4 + 5 = 7 lone raptors).
- Diagnostics: bot `BotTerritory` = band name; script `BotPackSectionState`.
Acceptance (Play): 12 RaptorPack + 7 RaptorSolo bots, all inside their band; a lone raptor chasing a player drops the chase
when the player crosses z -190 (BotBorderDrops); a pack still chases a raptor player inside the pack band; BotFightBites 0.

## Red-team (brief)
1. **Band line is invisible.** Players can't see where packs start. Accepted for now; a marker / sign is a later option.
2. **Line camping.** A player can stand just over the line and lone raptors won't follow (same rule as the border). Accepted
   (Kepu: a chasing bot stops at the border).
3. **BotSoloExtra is read at start.** Changing it live does nothing until the server restarts. Documented.
4. **19 raptors + 2 T-Rex = 21 bots** (was 16). Server cost is per bot tick; watch for lag on phones.
