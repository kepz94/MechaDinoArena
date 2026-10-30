# Mecha Dino Arena v1.0 — Buying Skins (game passes)

**Goal:** players buy the paid raptor skins with Robux from the Lab's SKINS tab, own them for good, and are wearing the skin the moment the purchase goes through.
**Intent (Kepu 2026-10-30):** skins are a big part of monetizing; "it should just be able to pull from accounts using receipts that their accounts have to know which skins are always theirs" · RNG rolls considered, then dropped ("lets not do rng then and just price the nicer skins much more expensive") · prices "149 / 499 / 999" · after buying: "A · Buy & wear".
**Chosen direction:** A · Buy & wear — prototype `docs/mockups/skins_buy_options.html` (published artifact "Skin Buying Options").
**Architecture:** every paid skin is one Roblox game pass. Roblox is the record of ownership (`MarketplaceService:UserOwnsGamePassAsync` at join, `PromptGamePassPurchaseFinished` during the session), so a bought skin can never be lost by our DataStore. SkinServer 1.1 adds ownership, prices and a "buy" request; SkinCatalog 1.1 carries the pass id per skin; Lab 1.7 turns on the GET button and shows the unlock.

## Global Constraints
- Additive only: SkinServer 1.0 equip / paint / save behaviour is unchanged; new behaviour behind switches (`SkinBuyEnabled` on SkinServer, `LabSkinBuyEnabled` on Lab).
- Versions: SkinCatalog 1.1, SkinServer 1.1, Lab 1.7. Each with header changelog, VERSIONS.md row, ATTRIBUTES.md rows.
- Prices (Kepu): RARE 149 (Arctic, Night Stalker), EPIC 499 (Lava), LEGENDARY 999 (Gold Hunter). Classic and Desert Runner stay free. The price a player pays is the pass's own price on Roblox; the Lab shows the live pass price (fallback: catalog price).
- Skins are picked in the menu Lab only (unchanged). No trading, no random rolls.
- Install via Studio multi_edit; verify by hash + loadstring; test with the Studio tools only (no computer use). Kepu publishes.

## Do-not-touch
- SkinServer 1.0 save format and no-write-after-failed-load rule (`MDA_Skins_v1`, `{v=1, equipped, owned}`); `owned` stays carried through untouched (ownership comes from Roblox, not the DataStore).
- Skin painting / tagging (tag, paint, dress), MainMenu 1.7 hangar recopy, SkinCatalog colours and roles.
- Lab MECHA ABILITIES / STATS tabs, compact Lab (no SKINS tab).
- Every gameplay script.

## Kepu's manual step (blocks the live test, not the build)
Create 4 game passes on the Creator Dashboard for the Mecha Dino Arena experience: "Arctic Skin" R$149, "Night Stalker Skin" R$149, "Lava Skin" R$499, "Gold Hunter Skin" R$999 (each needs an icon image and "On Sale"). Send the 4 pass ids. Until then the GET button reads "SOON" and Studio tests use the test hook.

## Deterministic map
| State | Condition | End state |
|---|---|---|
| Free skin | `free = true` | owned by everyone (unchanged) |
| Paid skin, no pass id | `passId == nil` | locked; GET greyed "SOON"; buy -> "noPass" |
| Ownership pending | join, check not finished | `SkinOwnState_<id>` "checking"; GET greyed "CHECKING"; a saved paid skin paints default until owned (save untouched) |
| Owns pass | `UserOwnsGamePassAsync` true | owned; saved skin painted |
| Check failed | 3 tries fail | "failed"; retried every 30 s; GET greyed "CHECKING" (no double prompt) |
| Buy request ok | in menu, known, paid, has pass, not owned, not pending | server `PromptGamePassPurchase`; result "prompted" |
| Purchase finished, bought | `wasPurchased` true for a pass we map | owned; if still in menu: equipped + painted + save queued, result "bought"; else result "boughtNotEquipped" |
| Purchase finished, cancelled | `wasPurchased` false | result "cancelled"; nothing changes, no toast |
| Pass revoked (refund) | next join check false | locked; paints default; save untouched |
| T-Rex | only Classic | nothing to buy |

## Task 1 — SkinCatalog 1.1 · Mode: Logic
**Files:** Modify `src/shared/SkinCatalog.luau`; Test `tools/tests/SkinCatalog.spec.luau` (1.1).
**Interfaces:** Produces `skin.passId` (number or nil), `SkinCatalog.byPass(passId) -> species, skin` or nil, `SkinCatalog.buyable(species, id) -> bool` (known, not free, passId number > 0). Prices: arctic 149, night 149, lava 499, gold 999.
- [ ] Spec first: byPass on a known / unknown id, buyable for free / paid-no-pass / paid-with-pass (set a pass id on a copy), prices match the ladder, every paid skin has `passId` key (nil allowed). Run in Studio, see it fail.
- [ ] Add `passId = nil` to the 4 paid skins (filled when Kepu sends ids), prices, byPass, buyable. Version 1.1.
- [ ] Run -> PASS; commit.
**Acceptance:** spec PASS; 1.0 API (roleOf / get / default / owns / sanitize) unchanged.

## Task 2 — SkinServer 1.1 · Mode: Wired
**Files:** Modify `src/server/SkinServer.server.luau`.
**Interfaces:** Consumes Task 1. Produces: `DinoSkinRequest:FireServer("buy", id)`; player attributes `SkinOwned_<Species>` (comma list of owned paid ids), `SkinOwnState` ("checking" / "done" / "failed"), `SkinPrice_<id>` (live Robux price or catalog price), `SkinForSale_<id>` (bool); results "prompted" / "bought" / "boughtNotEquipped" / "cancelled" / "noPass" / "owned" / "pending" plus the 1.0 ones; player `SkinLastBought` (id) + `SkinLastBoughtAt`.
- [ ] Switch `SkinBuyEnabled` (default true; false = 1.0 behaviour, "buy" -> "badArg").
- [ ] Join: for each buyable skin, `UserOwnsGamePassAsync` in pcall, 3 tries (2, 4 s); owned ids into a session set `st.passOwned` (never written to the DataStore); `owns` checks use `st.owned` ∪ `st.passOwned`; then publish + dress. Failed -> retry every 30 s.
- [ ] Prices: `GetProductInfo(passId, Enum.InfoType.GamePass)` once per pass at start (pcall), `SkinPrice_<id>` / `SkinForSale_<id>` on each player (fallback catalog price, for sale true).
- [ ] "buy": badArg / notInMenu / noBody / unknown / free (already owned) / noPass / pending (ownership not done) / owned / prompted -> `MarketplaceService:PromptGamePassPurchase(player, passId)`.
- [ ] `PromptGamePassPurchaseFinished(player, passId, wasPurchased)`: map with byPass; bought -> passOwned, then equip if InMenu (same path as "equip" ok: equipped, changed, publish, dress, save queued); results as the map.
- [ ] Test hook (Studio only, `RunService:IsStudio()`): script attribute `SkinTestGrant` = skin id -> runs the finished handler with wasPurchased true for the first player, then clears itself.
**Acceptance:** Studio Play with the hook: lava "buy" -> "noPass" (no pass id); hook lava -> "bought", SkinEquipped_Raptor lava, body painted, SkinOwned_Raptor contains lava; respawn keeps lava; "equip" lava -> "same"; hook while on the island -> "boughtNotEquipped"; SkinBuyEnabled false -> "buy" "badArg". With real pass ids: Studio test purchase -> "bought" (no Robux charged in Studio).

## Task 3 — Lab 1.7 · Mode: Wired
**Files:** Modify `src/client/Lab.client.luau`.
**Interfaces:** Consumes Task 2 attributes.
**Layout:** unchanged from 1.6 except: the badge and button read the live price `SkinPrice_<id>`; GET · R$n is enabled (ROBUX green, white text) when `SkinForSale_<id>` and a pass exists and SkinOwnState "done"; greyed "CHECKING" while ownership is checking / failed; greyed "SOON" with no pass; the "Buying comes in the next step." line is replaced by "Buy it once, keep it for good."; owned = free or in `SkinOwned_<Species>`. On "bought": gold toast "<NAME> UNLOCKED!" and the card stroke flashes YELLOW for 1 s; on "boughtNotEquipped": gold toast "<NAME> UNLOCKED!" only. "cancelled": nothing.
- [ ] Switch `LabSkinBuyEnabled` (default true; false = 1.6 greyed button).
- [ ] Owned set from `SkinOwned_<Species>`; redraw on its change and on `SkinPrice_*` / `SkinOwnState` changes.
- [ ] GET -> `DinoSkinRequest:FireServer("buy", id)`; button disabled until a result arrives (no double prompt).
**Acceptance:** Studio Play (menu Lab, SKINS tab): lava card badge R$499; GET greyed "SOON" without pass id; hook grant -> toast "LAVA UNLOCKED!", card ON, stage + live body lava; respawn keeps it; compact Lab unchanged.

## Red-team (Phase 4.5)
1. **Shown price ≠ charged price** (catalog says 499, pass set to 450). Mitigation: Lab shows the pass's live price from GetProductInfo; catalog price is only a fallback.
2. **Ownership check fails at join** -> a paying player sees their skin locked and could get prompted again. Mitigation: "CHECKING" state blocks GET; retries every 30 s; a saved paid skin is never overwritten (1.0 rule: locked paints default, save untouched).
3. **Fake purchase from a client** -> only the server's PromptGamePassPurchaseFinished grants; the client "buy" only opens Roblox's prompt. The test hook only runs in Studio.
4. **Purchase finishes after the player left the menu** -> unlock without auto-equip (equip stays menu-only), toast only.
5. **Passes belong to one experience.** They must be created on the experience the Arena place is published in (where Kepu publishes); a pass id from another experience never reports ownership. Check: Studio test purchase with the real ids (Task 2 acceptance).
