# Universal Skins v0.1 (plan, not built)

Status: unlock plan LOCKED by Kepu 2026-11-24 17:58. Lab SKINS tab layout and old-save migration still open.
Mockup: docs/mockups/universal_skins_plan_v0.4.html (artifact v0.4.1 shows the locked plan).

## Picks so far
- Unlock = Robux + earn by playing. Old per-dino skins = merge into universal. Equip = pick per dino. Look = patterns allowed.
- Lineup (Kepu): Classic + 20. Kept 12: Desert Runner, Riverstone, Canopy, Arctic, Ghost Bark, Lava, Venom, Gold Hunter,
  Obsidian Fang, Zebra, Neon Circuit, Chrome. Added 8: Prism, Void Matter, Spectral, Element X, Viper Gold, Opal, Ink War, Sakura.

## Locked unlock plan (Kepu's COPY PLAN, verbatim)
| Skin | Unlock |
|---|---|
| Classic | free |
| Desert Runner | earn: Play 3 Arena matches |
| Riverstone | earn: Get 25 kills |
| Canopy | earn: Win 5 Arena matches |
| Ghost Bark | earn: Get 100 kills |
| Zebra | earn: Win 15 Arena matches |
| Ink War | earn: Win 3 Arena matches in a row |
| Arctic, Sakura, Viper Gold, Prism, Void Matter | Robux 149 (RARE product) |
| Lava, Venom, Neon Circuit, Chrome, Opal | Robux 499 (EPIC product) |
| Gold Hunter, Obsidian Fang, Spectral, Element X | Robux 999 (LEGENDARY product) |

Totals: 6 earned, 14 Robux (5 x 149, 5 x 499, 4 x 999), 1 free.

## What the challenges read (grounded in main @ 94d0fbd)
- Arena wins: saved today. ArenaRecordServer 1.4, store MDA_ArenaRecord_v1 {w, l, last, s}; player ArenaW.
- Arena matches played: ArenaW + ArenaL. Per ArenaRecordRules 1.1 a leave counts as a loss, a draw counts as nothing,
  so "Play 3 Arena matches" counts finished, counted matches only (decision to confirm, see Open).
- Win streak: saved today. Record field s, player ArenaStreak (+n after n wins in a row). Unlock fires when s reaches 3.
- Kills: NOT saved. KillRegenServer only bumps the session attribute DinoKills. Needs a new saved lifetime kill count.
- Hardpoint time and per-dino wins: not needed by the locked plan.

## Products (grounded)
- SkinServer 1.1 sells by rarity tier: RARE 149, EPIC 499, LEGENDARY 999 (SkinCatalog PRODUCTS). The locked prices map 1:1
  onto those three products. No new products.

## Decisions (Kepu 2026-11-24 ~18:05)
- Lab SKINS tab: "Yes, as shown" (mockup v0.4: cards left with ALL / OWNED / EARN / ROBUX, 3D stage + 8-dino strip middle,
  detail + EQUIP ON <DINO> / BUY / LOCKED right).
- Old paid skins cut from the lineup: "Nobody bought any so don't worry about it". No compensation path.
- "Play 3 Arena matches" = ArenaW + ArenaL (counted matches only).
- Kills (R2): "Arena + island bots" = KillFeedServer kills by a player (players and Arena / practice bots) plus
  KillRegenServer island bot kills. One death counts once (dedupe by victim model + KilledAt, both scripts can see a practice bot).
- Old free skins (R3): "Back to Classic". No grandfathering; an equipped skin the player does not own falls back to Classic.
- Phone FX (R1): Settings gets "Animated skins" on/off, on by default (UI: needs a mockup and Kepu's pick before build).
- R4 (149 animated) stands as Kepu's plan. R5: keep all tasks.

## Build plan (after red-team, Kepu 2026-11-24)
Version tags: UniversalSkins 1.0 (new shared module), SkinServer 1.2, Lab 1.18, SkinFX 1.0 (new client),
SkinStats 1.0 (new server). Master switch: SkinServer attribute UniversalSkinsEnabled (default true once built; false = the
1.9 per-dino lists, saves untouched). Do-not-touch: ArenaRecordRules / ArenaRecordServer write path, MainMenu (it already
re-copies the dino on SkinApplied), MechaLegsServer, the Mecha_ part filter in SkinServer.tag, NEVER_PAINT.

Task 1 · Logic · UniversalSkins 1.0 (src/shared/UniversalSkins.luau, pure)
- SKINS: the 21 entries (id, name, unlock {kind = "free" / "earn" / "robux", stat, need, rarity}), slot colours /
  materials, optional pattern(slot, lp) -> hex, material, animKind, phase. Same ids as the mockup.
- SLOT map role -> slot (the 31 roles in SkinCatalog 1.9 ROLES); BODY = primary / secondary / limbs; fallbacks mask, accent
  -> secondary.
- partLook(skinId, role, lp, baseHex, baseMat) -> hex, mat, animKind, phase. classic returns the base.
- OLD_TO_NEW: pachy_riverstone -> riverstone, herrera_canopy -> canopy, herrera_ghostbark -> ghostbark, herrera_venom ->
  venom, herrera_obsidian -> obsidianfang; desert, arctic, lava, gold keep their id.
- unlocked(id, stats) for earn skins: desert W+L >= 3, riverstone kills >= 25, canopy W >= 5, ghostbark kills >= 100,
  zebra W >= 15, inkwar bestStreak >= 3.
- Tests (Studio loadstring runner, the same way ArenaRecordRules was checked): every role of all 8 species maps to a slot;
  partLook is deterministic for the same lp; every earn rule at need - 1 / need; OLD_TO_NEW covers every non-dropped id.

Task 2 · Logic + Wired · SkinStats 1.0 (new server script)
- Saved lifetime kills and best win streak per player (new store MDA_SkinStats_v1, key u<UserId>, {k, best}). Kills =
  KillFeedServer kills by a player + KillRegenServer island bot kills, one per victim + KilledAt. best = max(best,
  ArenaStreak) on every ArenaStreak change.
- Player attributes StatKills, StatBestStreak, SkinStatsReady. Switch SkinStatsEnabled; SkinStatsSaveEnabled (Studio guard
  like SkillSaveEnabled).

Task 3 · Wired · SkinServer 1.2
- tag(): also stores SkinLP (Vector3: part position in HumanoidRootPart space x 15 / model length) once per part.
- paint(): UniversalSkins.partLook per part; sets SkinAnim / SkinPhase on animated Neon parts.
- Save v2: owned keys become universal ids (OLD_TO_NEW on load, old value kept under owned_v1); equipped[species] mapped the
  same way; an unowned equipped id falls back to classic.
- Unlock check on ArenaW / ArenaL / StatKills / StatBestStreak change -> owned[id] = true, save, player attribute
  SkinUnlocked = id (toast trigger). BUY: product = the skin's rarity product (149 RARE / 499 EPIC / 999 LEGENDARY);
  receipt grants the universal id.
- SkinCatalog 1.10: ALL_UNLOCKED stays a switch; set false at launch (Kepu's call, not part of the build).

Task 4 · Wired · SkinFX 1.0 (new client script)
- Animates parts with SkinAnim (pulse / twinkle / hue) locally, on every character in range, capped part count; switch
  SkinFXEnabled. Phone budget: only parts within 120 studs, 20 Hz. Off when the player setting "Animated skins" is off
  (colours stay, no animation).

Task 5 · Wired · Lab 1.8 SKINS tab (UI, layout = mockup v0.4)
- Cards from UniversalSkins in the locked order; filters; progress bars from StatKills / ArenaW / ArenaL / StatBestStreak.
- Stage paints the copy with partLook (selected skin), 8-dino strip previews other species, EQUIP ON <DINO> fires the
  existing remote with the current species.
- Switch LabUniversalSkinsEnabled (false = Lab 1.7 tab).

Task 6 · Wired · unlock toast (UI, needs a mockup and Kepu's pick before build)

Task 7 · Wired · Settings "Animated skins" on/off row, saved per player, default on (UI, needs a mockup and Kepu's pick)

## Red-team (Phase 4.5)
R1. Animated skins on phones: Prism / Void Matter / Spectral / Element X / Opal animate many Neon parts per dino; 8+ dinos
    on screen = hundreds of colour writes per frame on low-end phones. Mitigation: SkinFX distance cap, 20 Hz, a per-frame
    part budget, and a setting to turn effects off; measure in Studio phone emulator with 8 bots before ship.
R2. "Kills" is undefined in code today: DinoKills (KillRegenServer) counts only island bot bites / pounces; Arena kills live in
    KillFeedServer (players and practice bots). Needs Kepu's pick before Task 2.
R3. Desert Runner, Riverstone and Canopy are free today and equipped by players; after launch they become earned, so a player
    wearing one gets reset to Classic until the challenge is done. Mitigation: grandfather (own it if the save had it
    equipped). Kepu's pick.
R4. 149 R$ now buys animated skins (Prism, Void Matter) while static ones cost 499 / 999. Recorded as Kepu's call; flag only.
R5. Scope: 6 tasks touching save data. Smaller first ship = Tasks 1, 3, 5 with the earn skins hidden until SkinStats lands.
    Recommendation: keep all 6; SkinStats is small and earn skins are half the point.

## Built 2026-11-24 (Studio Edit, not published)
- UniversalSkins 1.0, SkinStats 1.0, KillFeedServer 1.2, KillRegenServer 1.2, SkinServer 1.2, SkinFX 1.0, Lab 1.18 (the plan said
  "Lab 1.8"; the Lab was already 1.17). SkinCatalog untouched (ALL_UNLOCKED still true).
- Not built yet: MDA-571 unlock toast outside the Lab, MDA-572 Settings row (both need a mockup pick).

- 2026-11-24 19:05 Kepu: Prism 999 (UniversalSkins 1.2). Robux tiers now 149: Arctic, Sakura, Viper Gold, Void Matter; 499: Lava, Venom, Neon Circuit, Chrome, Glitch, Storm Front, Bloodline, Hellfire; 999: Gold Hunter, Obsidian Fang, Spectral, Element X, Prism.
