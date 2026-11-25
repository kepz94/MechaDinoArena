# Dino Trails v1.0 (build plan)

Status: plan, waiting for Kepu's "Build". Picks: docs/plans/TRAILS_v0.1.md (23:18 whenever moving / like emotes / island and matches
/ 10; 23:31 all 10, Neon Streak free, Fossil Prints = 25 Arena wins, Comet Tail = 250 kills; 23:55 Shop tab yes, Lab pill yes, equip A
"one trail for every dino"). Mockups: docs/mockups/trails_v0.1.html (the 10 looks), docs/mockups/trails_shop_lab_v0.1.html (Shop + Lab).

## Global constraints
- Additive, every number an attribute, version-branded, hash-checked installs. Master switch: TrailServer attribute TrailsEnabled
  (false = no remote, no TrailId stamps; clients draw nothing).
- Do-not-touch: the ability trails (ServoDash, Adrenaline, Tether, Screech, Blade, HerreraParts, DiloPartsVFX, TrooFX, TrooSlotFX,
  TheriFX), SkinServer's skin logic and the 1.3 emote hook (only an added trail check in front), EmoteServer, IdleAnimation, the HUD.
- One trail for every dino (pick A). NO TRAIL is a choice. Shows whenever the dino moves (flat speed over TrailMoveSpeed 2 studs/s),
  fades out when it stops. Island = full look; any non-hub server (matches) = soft look (opacity x0.55, life x0.6, bits x0.5).
- Every local part: Anchored, CanCollide / CanQuery / CanTouch false (never blocks aim raycasts), CastShadow false, client only.

## Pieces
| Piece | Version | Where | Job |
|---|---|---|---|
| TrailCatalog | 1.0 (new) | src/shared -> ServerStorage.DinoArcade, copied to ReplicatedStorage.TrailShared | 10 ids in order (neon, fossil, comet, rainbow, bolt, lava, leaf, bubble, pixel, bones), name, swatch colours, unlock (free / earn stat+need / robux 149 RARE), desc, look numbers |
| TrailServer | 1.0 (new) | src/server | own / save (MDA_Trails_v1) / earn / equip / buy intent; remote DinoTrailRequest; character attribute TrailId |
| SkinServer | 1.4 | src/server | receipt: a trail intent newer than the skin and emote intents for the same 149 product goes to TrailServer (BindableFunction TrailReceipt) |
| TrailLook | 1.0 (new) | src/client (ModuleScript) | the 10 looks, two outputs: world (Roblox Trail objects between Attachments on the Tail1 / Tail5 segments + capped local parts for prints and bits) and preview (part chains inside a ViewportFrame: Trail objects don't draw there) |
| TrailFX | 1.0 (new) | src/client | every character within TrailFXRange (150) with a TrailId: builds the look, on while moving, soft in matches; caps TrailFXMaxBits (24 a character, 120 total) |
| ShopScreen | 1.2 | src/client | TRAILS tab after EMOTES (7 x 149, no FEATURED row), swatch cards, preview walks the dino with the trail (TrailLook preview), BUY -> DinoTrailRequest "buy" |
| Lab | 1.20 | src/client | LOOKS: TRAILS pill after EMOTES; NO TRAIL + 10 cards (ON / OWNED / FREE / earn progress / R$149), stage preview, EQUIP / EQUIPPED / TURN TRAIL OFF / BUY · R$149 / LOCKED · KEEP PLAYING; new code in a script-global table TRL (main chunk at the 200-local limit) |

## Rules (deterministic map)
- own: neon free; fossil when ArenaW >= 25; comet when StatKills >= 250; the other 7 by the 149 product; every trail while
  SkinCatalog.ALL_UNLOCKED (still on).
- equip(id): id owned or "none" -> player TrailEquipped = id, saved; the character's TrailId = id ("" for none) now and on every spawn.
  Not owned -> TrailResult "notOwned".
- buy(id): robux trail not owned -> intent {id, at} + PromptProductPurchase(SkinCatalog.PRODUCTS.RARE). Receipt: SkinServer 1.4 asks
  TrailReceipt "intent" (and EmoteReceipt "intent", and its own skin intent); the newest of the three takes it; trail -> owned[id],
  receipt id saved once, TrailResult "bought", toast "<NAME> UNLOCKED!".
- show: TrailFX draws a character's TrailId while flat speed > TrailMoveSpeed, alive, not InMenu, not parked (PrParked), not frozen
  (PrResultsFreezeEnabled anchors roots at results: no speed, no trail). Ribbons stop emitting (Trail.Enabled false) and fade.
- Default for a new player: equipped "neon" (free).

## Red-team
1. Three 149 intents (skin, emote, trail) share one product. Newest intent wins; an expired trail intent falls back to the older
   rules (emote hook, then skins' credit path), never lost. Test: buy a trail right after opening a skin prompt (ALL_UNLOCKED off).
2. Phone cost: ribbons are Trail objects (GPU, cheap); bits are capped per character and in total, only within 150 studs, half in
   matches. Studio phone emulator check with 8 dinos on Bone Zone.
3. Read as an ability: soft look in matches, hip height or lower, no Neon on ribbons in matches, short life. Side by side check with
   Servo Dash and Adrenaline in Studio.
4. Previews can't use Trail objects (ViewportFrame): the preview is a part-chain copy, so it looks close but not identical. Compare
   in Studio; accept small differences.
5. Aim raycasts: every local part CanQuery false.
6. Lab register limit: TRL global table, as EMO in 1.19.

## Tests (Studio, when the PC is on)
- Each trail on 3 dinos (Raptor, T-Rex, Therizino): walk, run, stop; island vs a match server look.
- Equip from the Lab -> another dino keeps the same trail; NO TRAIL turns it off; rejoin keeps it (MDA_Trails_v1, test store).
- Earned: set ArenaW 25 / StatKills 250 -> unlock + toast. Shop TRAILS tab cards + preview + BUY prompt (ALL_UNLOCKED on: "ALREADY
  YOURS"). Phone emulator for both screens.
