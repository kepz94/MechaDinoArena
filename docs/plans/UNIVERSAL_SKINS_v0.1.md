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

## Open
1. Lab SKINS tab layout (mockup v0.4): Kepu's pick.
2. Old saves: skins in the current catalog that are NOT in the 20 and were sold before SkinCatalog 1.5 turned
   ALL_UNLOCKED on (2026-10-31, 6bf3e02): Night Stalker (Raptor, 149), Fossil (Pachy, 149), Thunderhead (Pachy, 149),
   Ember (Pachy, 499), Obsidian Crown (Pachy, 999), Bloodmoon (Herrera, 149). What an owner of one of these gets.
3. ALL_UNLOCKED (SkinCatalog 1.9, still true) must be off at launch.
4. "Play 3 Arena matches": count only counted matches (W + L), or every match joined.
