# Mecha Dino Arena v1.0 — Pachy Skins Drop (SkinCatalog 1.3)

**Goal:** the pachy gets its own skin lineup in the Lab SKINS tab, bought and worn exactly like the raptor skins.
**Intent (Kepu 2026-10-30):** "let's look at pachy skins to drop. I want us to plan first then push" · lineup "Same as raptor" (Classic + 1 free Common + 2 Rare + 1 Epic + 1 Legendary) · themes "Pachy-own themes" · ownership "Separate per dino" · picks "All option A".
**Chosen direction:** option A in every slot — prototype `docs/mockups/pachy_skins_options.html` (Studio renders of PachyModelData painted through its 9 skin roles).
**Architecture:** data only. SkinCatalog `SKINS.Pachy` gains 5 entries; SkinServer 1.1 (paint / equip / save / buy by rarity product) and Lab (SKINS tab lists `SKINS[species]`) are species-generic and already serve the pachy. Ids carry a `pachy_` prefix because the save's `owned` set is keyed by skin id only (`owned[id] = true`), so a shared id would hand a raptor buyer the pachy skin.

## Global Constraints
- Additive only: the Raptor / T-Rex skin lists, Pachy roles, Pachy Classic, prices, products, API unchanged.
- Version: SkinCatalog 1.3 (header changelog), SkinCatalog.spec 1.3, VERSIONS.md + ATTRIBUTES.md rows.
- Prices = the existing tiers: RARE 149, EPIC 499, LEGENDARY 999 (products 3724102107 / 3724102265 / 3724102407). No new developer products.
- Every pachy skin: all 9 roles (main, stripes, belly, dome, knobs, mask, limbs, claws, eyes) as 6-digit upper-case hex; materials only valid `Enum.Material` names.
- Install via Studio multi_edit, verify by hash + loadstring; test with Studio tools only. Publish only on Kepu's "publish".

## Do-not-touch
- SkinServer (tag / paint / equip / save / receipts), Lab, MainMenu, PachyModelData, the hidden knob spikes (skins set Color / Material only, never Transparency), Raptor / T-Rex skins.

## The lineup (Lab order)
| id | name | rarity | price | colours (main, stripes, belly, dome, knobs, mask, limbs, claws, eyes) | materials |
|---|---|---|---|---|---|
| classic | Classic | STARTER | free | 7A6A4E 3E5A55 C8B898 E6DCC4 8C7A5A 3F6F7A 5E5240 2E2620 8A2A1E | — |
| pachy_riverstone | Riverstone | COMMON | free | 6F7F6A 3C4A3E C9CDB8 D8D4C0 8E9A84 4E6E78 5A6658 2A2E2A D9A23A | — |
| pachy_fossil | Fossil | RARE | 149 | C9BFA4 5A5246 E3DAC4 F2EAD2 B8AE96 4A443A B5AA90 2B2722 7A1E12 | dome Marble, knobs Marble |
| pachy_thunderhead | Thunderhead | RARE | 149 | 4A5566 FFD23F 9AA6B5 C9D3DF FFD23F 2C3440 3A4452 1A1E24 FFD23F | stripes Neon, eyes Neon |
| pachy_ember | Ember | EPIC | 499 | 2B2422 FF6A1A 4A3530 3A2E2A FFB02E FF6A1A 352B28 0F0B0A FFB02E | stripes Neon, knobs Neon, eyes Neon |
| pachy_obsidian | Obsidian Crown | LEGENDARY | 999 | 151517 D4A72C 2A2A2E F2C14A FFE08A D4A72C 1F1F22 D4A72C FFE08A | dome Foil, stripes Neon, knobs Neon, eyes Neon |

## Task 1 — SkinCatalog 1.3 · Mode: Logic
**Files:** Modify `src/shared/SkinCatalog.luau` (SKINS.Pachy, Version, header) · Test `tools/tests/SkinCatalog.spec.luau`.
**Interfaces:** Consumes nothing new. Produces `SKINS.Pachy` (6 entries, order above); `get("Pachy", id)`, `owns`, `productFor`, `buyable` answer for them through the existing functions.
- [ ] Step 1: spec 1.3 — Version "1.3"; `#SKINS.Pachy == 6`; ids in order; every non-classic Pachy id starts with `pachy_`; no Pachy id equals a Raptor / T-Rex id; prices / free per table; `productFor` RARE / EPIC / LEGENDARY per table, nil for the free two; `owns("Pachy","pachy_fossil",{fossil=true}) == false` (ownership separate).
- [ ] Step 2: run the spec in Studio against installed 1.2 -> FAIL.
- [ ] Step 3: add the 5 entries + Version 1.3 + header -> install -> spec PASS.
- [ ] Step 4: commit + push.
**Acceptance:**
- Spec PASS (the existing raptor / T-Rex / Pachy role checks included).
- Play: a pachy in the menu equips each free skin ("ok"), each paid skin is "locked" until owned; a Studio test receipt (memory store) for RARE / EPIC / LEGENDARY with a pachy intent grants that pachy skin ("bought"), and `SkinOwned_Pachy` lists it; `SkinOwned_Raptor` unchanged.
- The live pachy body takes the skin's colours on its tagged parts; the hidden spikes stay hidden.
- Lab SKINS tab lists 6 pachy cards when the pachy is selected.
**Out of scope:** SkinServer, Lab and MainMenu code; T-Rex skins.

## Deterministic map
| State | Condition | End state |
|---|---|---|
| Free pachy skin | Classic / Riverstone | owned by all; equip "ok" in the menu |
| Paid, not owned | Fossil / Thunderhead / Ember / Obsidian, `owned[id]` nil | equip "locked"; card shows R$ price; buy -> credit or Roblox prompt |
| Paid, owned | `owned[pachy_x] = true` | equip "ok" |
| Raptor owner | `owned.arctic = true` etc. | no pachy skin owned (ids differ) |
| Unknown stored id | id not in SKINS.Pachy | paints Classic, stored value kept (SkinServer 1.0 rule) |

## How this fails (red-team, single-ticket change)
- **Id collision** (a pachy id reusing a raptor id) would give raptor buyers the pachy skin free — prevented by the `pachy_` prefix and a spec check.
- **Credits cross dinos**: an unspent rarity credit (receipt with no intent) can be spent on a pachy skin of that rarity. That is the existing per-rarity design (one product per tier), accepted.
- **Render vs game look**: Neon / Foil / Marble may read differently under island lighting than in the daylight mockup renders — checked in Play on the live body.
- **Lab card preview** paints a clone of the selected dino; if it were raptor-only the pachy cards would preview wrong — checked in Play (Lab is species-generic by code: `SKINS[species()]`).
