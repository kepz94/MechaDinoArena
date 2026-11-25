# Battle Emotes v1.0 (build plan)

Status: Kepu 2026-11-24 20:27 "Build"; published 20:47 (Sandbox v948 + Arena): EmoteCatalog, EmotePose, IdleAnimation 1.48,
EmoteServer, SkinServer 1.3, EmoteFX, EmoteWheel. Built 2026-11-24 after "Build next" (not published): ShopScreen 1.1 EMOTES tab, Lab 1.19 LOOKS / EMOTES. Picks: docs/plans/EMOTES_v0.1.md (12 emotes locked 20:12, prices 20:13, unlocks 20:14,
wheel A / Lab LOOKS / PC B / greyed shop slots 20:27). Mockups: docs/mockups/battle_emotes_v0.2.html, docs/mockups/emote_wheel_v0.1.html.

## Global constraints
- Additive, every number an attribute, version-branded, hash-checked installs. Master switch: EmoteServer attribute EmotesEnabled
  (false = no remote, no stamps; clients see no EmoteShared folder and build nothing).
- Do-not-touch: every existing pose module, the roar / bite / ability servers, SkinServer's skin logic (only an additive receipt
  hook), Phone HUD v2 pieces (PhoneMenu, drawer, kill feed), MechaButtons / ArenaTouch, the PC HUD layout.

## Pieces
| Piece | Version | Where | Job |
|---|---|---|---|
| EmoteCatalog | 1.0 (new) | src/shared -> ServerStorage.DinoArcade, copied to ReplicatedStorage.EmoteShared | 12 ids in locked order, name, HUD tag, length, unlock (free / earn stat+need / robux 149), word list |
| EmotePose | 1.0 (new) | src/character/IdleAnimation/EmotePose.luau | the 12 poses from mockup v0.2 (same maths), pure: get(id, f, t, R) -> joint offsets |
| IdleAnimation | 1.48 | src/character/IdleAnimation/init | emote layer after the boost lean, before the dead pose, while EmoteId + EmoteStartedAt are live; switch EmotePoseEnabled |
| EmoteServer | 1.0 (new) | src/server | own / save (MDA_Emotes_v1) / unlock / wheel / play / cancel / cooldown / buy intent; remote DinoEmoteRequest |
| SkinServer | 1.3 | src/server | receipt hook: a newer emote intent for the same 149 product goes to EmoteServer (BindableFunction EmoteReceipt) |
| EmoteFX | 1.0 (new) | src/client | props (Parts welded to Head / hand Root) and pop-up words (BillboardGui), every character in range |
| EmoteWheel | 1.0 (new) | src/client | phone ☻ pill left of ☰ + 8-slot middle wheel; PC hold B; 3 s cooldown on the pill; greyed shop slots |
| ShopScreen | 1.1 | src/client | EMOTES category tab (149 R$ items), BUY -> DinoEmoteRequest "buy" |
| Lab | 1.19 | src/client | SKINS tab reads LOOKS with SKINS / EMOTES; EMOTES: cards, stage plays the emote, detail + your wheel |

## Rules (deterministic map)
- play(id): refused unless EmotesEnabled, loaded, owned, alive, not InMenu, EmoteCooldownUntil passed, standing still
  (MoveDirection and flat HRP speed under EmoteStillSpeed 2). OK -> character EmoteId, EmoteStartedAt (server time), EmoteDuration;
  player EmoteCooldownUntil = now + EmoteCooldown (3). Result attribute EmoteResult.
- cancel: MoveDirection > 0.1, Jump, health drop, any character attribute ending "StartedAt" (attacks / abilities) other than
  EmoteStartedAt, or the emote's length passing -> EmoteId / EmoteStartedAt cleared (EmoteEndReason).
- own: GG Party free; Stomp Stomp when ArenaW >= 10; Play Dead when StatBestStreak >= 5; the other 9 by the 149 product; every emote
  while SkinCatalog.ALL_UNLOCKED (the same test switch the skins use; still on).
- wheel: 8 ids saved; a new grant fills the first empty slot; equip(slot, id) only for owned ids.
- buy(id): robux emote not owned -> intent {id, at} + PromptProductPurchase(SkinCatalog.PRODUCTS.RARE); receipt via SkinServer hook ->
  owned[id] + receipt id saved once.

## Red-team
1. One receipt handler: a skin tap then an emote tap could both hold a 149 intent. Newest intent wins (timestamps compared in the hook);
   an expired emote intent falls back to SkinServer's credit path, never lost.
2. Phone cost: props are a handful of Parts per emote, words one BillboardGui; only characters within EmoteFXRange (120) build them.
3. Emote as a shield: any damage, move, jump or attack ends it; the camera is untouched.
4. Pose fit on 8 rigs: the mockup ran the same maths on the real ModelData rigs; Studio check on each species before publish.

## Checked in Studio Play (2026-11-24, Therizino, desktop)
- All 12 emotes: server "playing", EmotePoseState = the emote id on the client, effect parts spawned (party 46 at peak), ended "done".
- Moving cancels (EmoteEndReason "move"); a second play inside 3 s -> "cooldown".
- PC: hold B opens the wheel (8 owned emotes, test switch on), mouse direction highlights a slot, release plays it (EmoteWheelPlays 1).
- No script errors in the output.
- Fixes from the test: word size now uses the body height from segment parts (GetExtentsSize counted mecha parts: 27.6 vs ~14);
  sign scale R.h x 0.35 (was 0.5, board went off the top).
- Not checked yet: the phone pill in the phone emulator, other species in Play, a real Robux purchase (test switch on).

## Checked in Studio Play: Shop 1.1 + Lab 1.19 (2026-11-24, desktop)
- Shop EMOTES tab: word cards, preview plays the emote with the word, detail EMOTE · R$149 + BUY.
- Lab: LOOKS tab, EMOTES pill, 12 cards, stage animates (Therizino, T-Rex), PUT ON WHEEL -> TAP A SLOT -> slot 8 -> "equipped" +
  toast; SKINS pill unchanged. Fix from the test: ring slots were 0.3 wide and overlapped their neighbours; now 0.24.
- Not checked yet: phone emulator for the Lab EMOTES view and the ☻ pill, a real Robux purchase (test switch on).
