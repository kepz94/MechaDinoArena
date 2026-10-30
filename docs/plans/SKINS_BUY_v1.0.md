# Mecha Dino Arena v1.0 — Buying Skins (developer products by rarity)

**Goal:** players buy the paid raptor skins with Robux from the Lab's SKINS tab, own them for good, and are wearing the skin the moment the purchase goes through.
**Intent (Kepu 2026-10-30):** skins are a big part of monetizing; "it should just be able to pull from accounts using receipts that their accounts have to know which skins are always theirs" · RNG rolls considered, then dropped ("lets not do rng then and just price the nicer skins much more expensive") · prices "149 / 499 / 999" · after buying: "A · Buy & wear" · game passes per skin questioned ("why do i need to create 4 game passes these are in game skins") -> one developer product per price tier ("okay how do i create these products then").
**Chosen direction:** A · Buy & wear — prototype `docs/mockups/skins_buy_options.html` (published artifact "Skin Buying Options").
**Products (created by Kepu 2026-10-30, checked in Studio with GetProductInfo):** Rare Skin 3724102107 (R$149), Epic Skin 3724102265 (R$499), Legendary Skin 3724102407 (R$999). Experience: gameId 10773455700, Arena placeId 84022023159448.
**Architecture:** every paid skin's rarity maps to one developer product. Roblox does not record developer product ownership, so SkinServer records it in the existing save (`MDA_Skins_v1`, field `owned`, reserved in 1.0) through `MarketplaceService.ProcessReceipt`: each receipt's PurchaseId is stored with the grant in one UpdateAsync, and Roblox is told "granted" only after that write succeeds (Roblox retries the receipt otherwise). The skin a receipt pays for is the one the player tapped GET on (the "intent"); a receipt with no matching intent (e.g. a future Shop listing) becomes an unlock credit for that rarity, spent on the next skin of that rarity the player picks.

## Global Constraints
- Additive only: SkinServer 1.0 equip / paint / save behaviour is unchanged; new behaviour behind switches (`SkinBuyEnabled` on SkinServer, `LabSkinBuyEnabled` on Lab).
- Versions: SkinCatalog 1.1, SkinServer 1.1, Lab 1.7. Each with header changelog, VERSIONS.md row, ATTRIBUTES.md rows.
- Prices (Kepu): RARE 149 (Arctic, Night Stalker), EPIC 499 (Lava), LEGENDARY 999 (Gold Hunter). Classic and Desert Runner stay free. The Lab shows the product's live price (GetProductInfo), catalog price as fallback.
- Skins are picked in the menu Lab only (unchanged). No trading, no random rolls.
- SkinServer is the only ProcessReceipt in the game (checked: none in repo or Studio). Any later product must be added to its dispatch.
- Products stay unlisted in Monetization -> Shop until Kepu has checked a live purchase.
- Install via Studio multi_edit; verify by hash + loadstring; test with the Studio tools only (no computer use). Kepu publishes.

## Do-not-touch
- SkinServer 1.0 save rules: no writes before a successful load for the equip save; UpdateAsync merge; BindToClose. (The receipt write is its own UpdateAsync that reads the stored value, so it is safe even when the session load failed.)
- Skin painting / tagging (tag, paint, dress), MainMenu 1.7 hangar recopy, SkinCatalog colours and roles.
- Lab MECHA ABILITIES / STATS tabs, compact Lab (no SKINS tab).
- Every gameplay script.

## Save value (MDA_Skins_v1, key u<UserId>)
`{v = 1, equipped = {[species] = id}, owned = {[skinId] = true}, credits = {[RARITY] = n}, receipts = {[PurchaseId] = unixTime}}` — `owned` was reserved in 1.0; `credits` and `receipts` are new and ignored by 1.0. Receipts keep the newest RECEIPT_KEEP (200).

## Deterministic map
| State | Condition | End state |
|---|---|---|
| Free skin | `free = true` | owned by everyone (unchanged) |
| Paid skin, no product for its rarity | `productFor == nil` | GET greyed "SOON"; buy -> "noProduct" |
| Save not loaded | SkinSaveState not loaded / new / saved | GET greyed "LOADING"; buy -> "notLoaded" |
| Owned | `owned[id]` | EQUIP / EQUIPPED (1.0) |
| Credit for the rarity | `credits[r] > 0` | button "UNLOCK · 1 CREDIT"; buy -> credit spent in one UpdateAsync -> "bought" (+ equip) |
| Buy | in menu, loaded, known, paid, not owned, product exists, no credit | intent = {id, rarity}; PromptProductPurchase -> "prompted"; button disabled |
| Prompt closed without buying | PromptProductPurchaseFinished isPurchased false | intent cleared, "cancelled", nothing else |
| Receipt, player in game, intent matches rarity, skin not owned | ProcessReceipt | owned[id] = true + receipt stored (one UpdateAsync) -> PurchaseGranted; equip if InMenu -> "bought", else "boughtNotEquipped" |
| Receipt, no matching intent (or intent skin already owned) | ProcessReceipt | credits[r] += 1 + receipt stored -> PurchaseGranted -> "credit" |
| Receipt already stored | receipts[PurchaseId] exists | nothing added -> PurchaseGranted (no double grant) |
| Receipt, player not in game / write failed / unknown product | ProcessReceipt | NotProcessedYet (Roblox retries; nothing written) |

## Task 1 — SkinCatalog 1.1 · Mode: Logic
**Files:** Modify `src/shared/SkinCatalog.luau`; Test `tools/tests/SkinCatalog.spec.luau` (1.1).
**Interfaces:** Produces `SkinCatalog.PRODUCTS = {RARE = 3724102107, EPIC = 3724102265, LEGENDARY = 3724102407}`, `productFor(species, id) -> productId or nil` (paid skin of a rarity with a product), `rarityOfProduct(productId) -> rarity or nil`, `buyable(species, id) -> bool`. Prices: arctic 149, night 149, lava 499, gold 999.
- [ ] Spec first (fails on 1.0): prices, productFor for free / rare / epic / legendary / unknown, rarityOfProduct for each id and an unknown one, buyable. Run in Studio, see it fail.
- [ ] Module changes; version 1.1. Run -> PASS; commit.
**Acceptance:** spec PASS; 1.0 API unchanged.

## Task 2 — SkinServer 1.1 · Mode: Wired
**Files:** Modify `src/server/SkinServer.server.luau`.
**Interfaces:** Consumes Task 1. Produces: `DinoSkinRequest:FireServer("buy", id)`; player attributes `SkinOwned_<Species>` (comma list of owned paid ids), `SkinCredits_<RARITY>` (n), `SkinPrice_<RARITY>` (live price or catalog), results "prompted" / "bought" / "boughtNotEquipped" / "credit" / "cancelled" / "noProduct" / "notLoaded" / "owned" / "free" plus 1.0's; `SkinLastBought` + `SkinLastBoughtAt`; script `SkinReceipts` (granted), `SkinReceiptsDeferred` (NotProcessedYet count).
- [ ] Switch `SkinBuyEnabled` (default true, read at start; false = 1.0: "buy" -> "badArg", no ProcessReceipt set).
- [ ] Load: credits read with owned (same GetAsync).
- [ ] Prices: GetProductInfo(productId, Enum.InfoType.Product) per rarity at start (pcall), published to every player.
- [ ] "buy" checks in the map's order; credit path; prompt path with intent.
- [ ] ProcessReceipt + PromptProductPurchaseFinished as the map.
- [ ] Studio test store: script attribute `SkinTestMemoryStore` (Studio only, read at start): an in-memory store with GetAsync / UpdateAsync replaces the DataStore so loads, saves and receipts run in Studio. Test hook `SkinTestReceipt` = "<rarity>" (Studio only): runs ProcessReceipt for the first player with a fresh PurchaseId; `SkinTestReceiptRepeat` = true re-sends the last receipt (double-grant check).
**Acceptance (Studio Play, memory store):** tap-buy lava -> "prompted" (Roblox test prompt shown in Studio); hook EPIC with lava intent -> "bought", SkinEquipped_Raptor lava, body painted, SkinOwned_Raptor has lava, save has receipt; repeat receipt -> no second grant; hook RARE with no intent -> "credit", SkinCredits_RARE 1; buy arctic -> credit spent, "bought"; respawn keeps the skin; "buy" lava again -> "owned"; island receipt -> "boughtNotEquipped"; SkinBuyEnabled false -> "badArg".

## Task 3 — Lab 1.7 · Mode: Wired
**Files:** Modify `src/client/Lab.client.luau`.
**Interfaces:** Consumes Task 2 attributes.
**Layout:** as 1.6 except the button and line: owned -> EQUIP / EQUIPPED; credit -> "UNLOCK · 1 CREDIT" (ROBUX); buyable -> "GET · R$<price>" (ROBUX, enabled; price = SkinPrice_<RARITY>); not loaded -> greyed "LOADING"; no product -> greyed "SOON"; after a press greyed "…" until a result. Line: owned "Owned. Equip it and you spawn in it every time." / locked "Buy it once, keep it for good." Badge price from SkinPrice_<RARITY>. Owned set = free or SkinOwned_<Species>. "bought": gold toast "<NAME> UNLOCKED!" and the card stroke YELLOW for 1 s; "boughtNotEquipped": the same toast; "credit": toast "<RARITY> UNLOCK READY · PICK A SKIN"; "cancelled": nothing.
- [ ] Switch `LabSkinBuyEnabled` (default true; false = 1.6 greyed button).
- [ ] Redraw on SkinOwned_* / SkinCredits_* / SkinPrice_* / SkinSaveState changes.
**Acceptance:** Studio Play (menu Lab, SKINS tab): badges R$149 / R$499 / R$999; GET opens the Roblox test prompt; hook receipt -> toast, card ON, stage and live body painted; credit button shows and spends; compact Lab unchanged.

## Red-team (Phase 4.5)
1. **Shown price ≠ charged price.** Mitigation: Lab shows the product's live price; catalog only as fallback.
2. **A paid receipt is lost or granted twice.** Mitigation: grant and PurchaseId in one UpdateAsync; PurchaseGranted only after it succeeds; a stored PurchaseId is never granted again; NotProcessedYet when the player is gone or the write fails (Roblox retries).
3. **Which skin did a tier product pay for?** Mitigation: the GET intent; no intent -> a credit for that rarity, never a guess.
4. **Fake purchase from a client.** Only ProcessReceipt grants; the client "buy" only opens Roblox's prompt; test hooks run only in Studio.
5. **Purchase finishes after the player left the menu.** Unlock without auto-equip (equip stays menu-only).
6. **Accepted risk:** our save is the only record of who owns a paid skin (Kepu chose products over passes). Covered by 2.
