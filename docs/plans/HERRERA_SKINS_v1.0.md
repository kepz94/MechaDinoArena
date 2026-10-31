# Mecha Dino Arena v1.0 — Herrera Skins Drop (SkinCatalog 1.6)

**Goal:** the Herrera gets its own skin lineup in the Lab SKINS tab, worn and bought exactly like the raptor and pachy skins.
**Intent (Kepu 2026-10-31):** "let's do some skins for the herrerra now" · lineup "Same as pachy" (Classic + 1 free Common + 2 Rare + 1 Epic + 1 Legendary) · themes "Herrera-own themes" · mecha parts "No, body only".
**Chosen direction:** prototype `docs/mockups/herrera_skins_options.html` (HerreraModelData 1.2 painted through its 10 skin roles in three.js) — picks Common A Canopy, Rare 1 A Bloodmoon, Rare 2 A Ghost Bark, Epic A Venom, Legendary B Obsidian Fang.
**Architecture:** data only. `SkinCatalog.SKINS.Herrera` gains 5 entries. SkinServer (paint / equip / save / buy by rarity product) and Lab (SKINS tab lists `SKINS[species]`) are species-generic and already serve the Herrera (its Classic is live since SkinCatalog 1.4). Ids carry a `herrera_` prefix because the save's `owned` set is keyed by skin id only.

## Global Constraints
- Additive only: Raptor / T-Rex / Pachy skins, Herrera roles, Herrera Classic, prices, products, API, ALL_UNLOCKED unchanged.
- Version: SkinCatalog 1.6 (header changelog), SkinCatalog.spec 1.5, VERSIONS.md + ATTRIBUTES.md rows.
- Prices = the existing tiers: RARE 149, EPIC 499, LEGENDARY 999 (products 3724102107 / 3724102265 / 3724102407). No new developer products.
- Every Herrera skin: all 10 roles (main, stripes, belly, markings, limbs, claws, eyes, tailbands, mask, frill) as 6-digit upper-case hex; no hex used twice in one skin; none equal to a never-paint colour; materials only valid `Enum.Material` names (Neon, Foil).
- Skins paint body colour groups only; HerreraPartsServer pieces (HPart_*) are never repainted.
- Install via Studio multi_edit, verify by hash + loadstring; test with Studio tools only. Publish only on Kepu's "publish".

## Do-not-touch
- SkinServer, Lab, MainMenu, HerreraModelData, HerreraPartsServer, Raptor / T-Rex / Pachy skins, `SkinCatalog.ALL_UNLOCKED` (still true for the group test).

## The lineup (Lab order)
| id | name | rarity | price | main, stripes, belly, markings, limbs, claws, eyes, tailbands, mask, frill | materials |
|---|---|---|---|---|---|
| classic | Classic | STARTER | free | 6E6A3A 2F3320 D3C89A B8414A 5A5530 2C2620 E8C547 B9B26A 262A1A C9572E | — |
| herrera_canopy | Canopy | COMMON | free | 4F7A3A 24391C C8D49A D9A23A 3F6530 2A2A1E F0E04A 8DB85A 1D2A16 6FA83C | — |
| herrera_bloodmoon | Bloodmoon | RARE | 149 | 3A3436 1C191A 8A7E78 C8202E 2E2A2B 0E0C0C FF3B3B 9A1E28 151213 B0182A | eyes Neon |
| herrera_ghostbark | Ghost Bark | RARE | 149 | D8D2C2 4A4640 EFE9DA 2A2724 C4BDAB 3A3530 7FE9FF 9A9488 5A554C B8AE9A | eyes Neon |
| herrera_venom | Venom | EPIC | 499 | 1E2420 A6E22E 3A4438 7CFF4A 2A3229 0D100D C6FF3A 5FBF2A 121612 8FE03A | stripes, markings, eyes, frill Neon |
| herrera_obsidian | Obsidian Fang | LEGENDARY | 999 | 141416 2A2A2E 3A3A40 D0202A 1E1E22 D4A72C FFD24A B81822 0A0A0C 9E1520 | markings Neon, claws Foil, eyes Neon, frill Neon |

## Task 1 — SkinCatalog 1.6 · Mode: Logic
**Files:** Modify `src/shared/SkinCatalog.luau` (SKINS.Herrera, Version, header) · Test `tools/tests/SkinCatalog.spec.luau`.
**Interfaces:** Consumes nothing new. Produces `SKINS.Herrera` (6 entries, order above); `get("Herrera", id)`, `owns`, `productFor`, `buyable` answer for them through the existing functions.
- [ ] Step 1: spec 1.5 — Version "1.6"; `#SKINS.Herrera == 6`; ids / rarity / price / free / product per table; every non-classic id starts with `herrera_` and is not used by another dino; per skin all 10 roles, no hex twice, none never-paint, materials valid; ownership separate (`owns("Herrera","herrera_bloodmoon",{pachy_fossil=true, arctic=true}) == false` with ALL_UNLOCKED forced false on the test copy, true with `{herrera_bloodmoon=true}`); `sanitize("Herrera","pachy_ember") == "classic"`. The 1.3 / 1.4 owns checks also run with ALL_UNLOCKED forced false (they test the locked rules; 1.5 made them answer true).
- [ ] Step 2: run the spec in Studio against installed 1.5 -> FAIL.
- [ ] Step 3: add the 5 entries + Version 1.6 + header -> install -> spec PASS.
- [ ] Step 4: Play: Herrera, Lab SKINS tab shows 6 cards; equip each (ALL_UNLOCKED: all "ok"); the live body takes the colours on its tagged parts (Neon / Foil on the right groups), HPart_* pieces unchanged; the menu preview follows (SkinApplied re-copy). Captures to `docs/reference/herrera/`.
- [ ] Step 5: commit + push; VERSIONS / ATTRIBUTES rows.
**Acceptance:**
- Spec PASS.
- Lab SKINS tab lists 6 Herrera cards in the order above with rarity and price.
- Equipping a skin paints the live Herrera; mecha parts keep their colours; teeth / pupils / mouth unchanged.
- Raptor / pachy skin lists and ownership unchanged.
**Out of scope:** SkinServer, Lab and MainMenu code; T-Rex skins; turning ALL_UNLOCKED off.

## Deterministic map
| State | Condition | End state |
|---|---|---|
| Free Herrera skin | Classic / Canopy | owned by all; equip "ok" |
| Paid, not owned, ALL_UNLOCKED false | Bloodmoon / Ghost Bark / Venom / Obsidian, `owned[id]` nil | equip "locked"; card shows R$ price; buy -> credit or Roblox prompt |
| Paid, ALL_UNLOCKED true (group test, today) | any | owned; equip "ok"; buy answers "owned" |
| Paid, owned | `owned[herrera_x] = true` | equip "ok" |
| Raptor / pachy owner | `owned.arctic` / `owned.pachy_fossil` | no Herrera skin owned (ids differ) |
| Unknown stored id | id not in SKINS.Herrera | paints Classic, stored value kept (SkinServer rule) |

## How this fails (red-team, single-ticket change)
- **Id collision** would hand other dinos' buyers a Herrera skin — prevented by the `herrera_` prefix and a spec check.
- **Credits cross dinos:** an unspent rarity credit can be spent on a Herrera skin of that rarity — the existing per-rarity design, accepted.
- **Render vs game look:** the mockup draws Neon unlit and Foil shiny under a studio light; island lighting differs — checked in Play on the live body.
- **Similar look to the frill part:** the Strobe Frill mecha part sits on the frill; skins recolour only the body frill blocks, not HPart_strobe — checked in Play.
