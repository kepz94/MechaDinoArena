# Mecha Dino Arena v1.0 — Favorite Egg (roadmap piece 6)

**Goal:** a floating egg in an incubator on the island. Favorite the game, get one free roll for anything in the game.

**Kepu 2026-11-26:**
- 07:36: "an egg floating in an incubator that says like and favorite for free egg roll. it will be a roll for anything at all in
  the game from dinos to skin to emote to trail. we'll have a limited time offer timer going off above it and even though it says
  like and favorite we'll only really be able to check if they favorited". Weekly quest rotation parked for later.
- Picks:
  - Rolls: "One ever".
  - Odds: "By rarity", "Keep as shown" (50 / 30 / 10 / 5 / 5).
  - Duplicates: "Reroll to new".
  - Timer: "Per player, 48 h".
  - Dino prize: "Owned + parts maxed".
  - Mockup `docs/mockups/favorite_egg_v0.1.html` (artifact "Favorite Egg"): "B · Prize reel".
  - Red-team: "Lower paid odds", "When they first see it", "Leave them out".

**Facts the design rests on (web, 2026-11-26):**
- `AvatarEditorService:PromptSetFavorite` (client) shows Roblox's own favorite window, and `PromptSetFavoriteCompleted` says
  Success / Failure / PermissionDenied.
- `GetFavoriteAsync` needs a second "allow inventory read" prompt every session, so we don't use it.
- Roblox has no like prompt and no way to read likes. The only in-game prompt is the PlayerFeedback API (written feedback, no
  thumbs).
- No official rule against a reward for favoriting was found. A 2026 DevForum post "Roblox Kids and Select: New Restrictions on
  Reward-Driven Media Feeds" could not be read (maintenance) and must be read before publish.

## Architecture
New pieces:
- **EggRules 1.0:** data + maths, spec.
- **FavEggServer 1.0:** store, timer, roll, grant.
- **FavEggStandServer 1.0:** the incubator, hub only.
- **FavEggClient 1.0:** favorite window, reel, prize card, the per-player timer on the billboard.

Grants go through each owner's own server, one additive hook each:
- SkinServer `SkinGrant` (exists).
- EmoteServer 1.1 `EmoteGrant` (new).
- TrailServer 1.1 `TrailGrant` (new).
- DinoOwnership 1.2 `OwnGrant` (new, with a saved `maxed` list).
- SkillServer 1.16: dinos in player `MaxedDinos` get maxed parts like `FreeDino`.

## Prize pool (EggRules.TIERS, built from the live catalogs)

| Tier (odds) | What |
|---|---|
| Common 60% | earn skins (Desert Runner, Riverstone, Canopy, Ghost Bark, Ink War), earn emotes (Stomp Stomp, Play Dead), earn trails (Fossil Prints, Comet Tail) |
| Rare 30% | R$149 skins (Arctic, Sakura, Viper Gold, Chrome), R$149 emotes (9), R$149 trails (7) |
| Epic 5% | R$499 skins (Lava, Venom, Neon Circuit, Gold Hunter, Obsidian Fang) |
| Legendary 2% | R$999 skins (Prism, Void Matter, Glitch, Bloodline, Hellfire, Spectral, Element X) |
| Dino 3% | the 8 dinos, owned + every mecha part maxed |

Free items (Classic, GG Party, Neon Streak) are never in the pool. The Quest Stand specials (Zebra, Storm Front) are left out; see
red-team R4. Odds are attributes (`EggOddsCommon` and so on).

**Pick:**
1. Roll a tier by the odds.
2. Take a uniform pick from that tier's items the player does not own.
3. If that tier is empty for them, roll again among the tiers that still have something, keeping their odds.
4. If they own everything, they get `EggAllOwnedPoints` (10) skill points (SkillGrantPoints "egg").

## Tasks
1. **EggRules 1.0 · Logic** (`src/shared/EggRules.luau`, spec `tools/tests/EggRules.spec.luau`):
   - `TIERS`, `ODDS`.
   - `pool(catalogs)`.
   - `pick(owned = {skins, emotes, trails, dinos}, rng)` → `{kind, id, tier}` | `{kind = "points"}`.
   - `endsAt(first)` = first + 48 h.
   - `state(rec, now)`: "open" / "rolled" / "expired".
2. **Grant hooks · Wired:**
   - EmoteServer 1.1 `EmoteGrant:Invoke(player, id, reason)` → "ok" / "owned" / "unknown" / "notLoaded" (writes owned, sets EmoteUnlocked).
   - TrailServer 1.1 `TrailGrant`, the same.
   - DinoOwnership 1.2 `OwnGrant:Invoke(player, key, maxed)` → owned[key] = true, maxed[key] = true, attribute `MaxedDinos`.
   - SkillServer 1.16 reads `MaxedDinos` beside `FreeDino`.
   - Each behind its own switch.
3. **FavEggServer 1.0 · Wired:**
   - Store `MDA_FavEgg_v1` `{first, roll = {kind, id, tier, at}, granted}`.
   - `first` is written when the stand first comes near or on screen: the client asks `FavEggRequest("seen")` and the server checks the player is on the hub within the stand's range or line of sight. If missing, the offer has not started.
   - Player attributes `FavEggState`, `FavEggEndsAt`.
   - RemoteFunction `FavEggRequest("favorited")`, hub only and near the stand:
     - one UpdateAsync writes the roll (only when there is no roll yet and the offer has not expired);
     - then the grant; `granted` is retried on join.
     - Returns the prize and a reel list.
   - Studio memory switch `FavEggTestMemoryStore`. Switch `FavEggEnabled`.
4. **FavEggStandServer 1.0 · Wired:**
   - Incubator on the plaza rim at 225° (across from the ARENA portal), the shop's radius.
   - Base, glass, two lights, floating egg, yellow sign "LIKE + FAVORITE / FREE EGG ROLL", odds line, red timer billboard.
   - ProximityPrompt "FREE ROLL". Switch `FavEggStandEnabled`.
5. **FavEggClient 1.0 · Wired (layout B):**
   - Prompt → `PromptSetFavorite(SANDBOX_PLACE_ID, Asset, true)`.
   - Success → server.
   - Reel: about 40 real cards, eases onto the prize in 4 s; then the rays, the prize card, and EQUIP / PLAY IT + NICE (44 px+).
   - Cancel → toast "FAVORITE TO ROLL THE EGG".
   - The billboard timer counts `FavEggEndsAt` locally. When rolled the egg greys and the prompt reads "ROLLED ✓"; when expired the stand hides for that player.
   - Switch `FavEggClientEnabled`.
6. **Check, docs:** Studio hub Play, phone + PC, save switches off (+ `FavEggTestMemoryStore`):
   - Each prize kind grants and saves.
   - A second roll is refused.
   - Declined favorite → no roll.
   - An expired timer → refused.
   - Dino → MaxedDinos, parts at 4.
   - Before publish: read the unread Roblox rewards post.

## Do-not-touch
- Skin / emote / trail buying and receipts.
- The Quest Stand and the Shop stand (only read for placement).
- The tutorial free dino.
- The loading screen.

## Red-team (Phase 4.5)
- **R1 · The client says "favorited".** There is no server check. An exploiter can roll without favoriting: one roll per account,
  same odds. Proposed: accept.
- **R2 · Free paid items.** 15% of players get an R$499 / 999 skin. With "Reroll to new" a dino or legendary is common for an
  early player. Proposed: accept (it is the hook); the odds are attributes.
- **R3 · When the 48 h starts.** At the first join after launch, an old player who skips the island loses it unseen. Proposed:
  start when the stand first comes near / on screen (`first` written by the stand client, server-checked).
- **R4 · Quest Stand specials** (Zebra, Storm Front) in the egg would skip the quest. Proposed: leave them out.
- **R5 · Rules.** One 2026 Roblox post on reward rules is unread. Proposed: read it before publish; a pendingHuman if it bans it.

## Synthesis (Kepu 2026-11-26)
- R1 + R2 "Lower paid odds": Common 60 · Rare 30 · Epic 5 · Legendary 2 · Dino 3 (attributes). The client-trusted favorite is accepted (one roll per account).
- R3 "When they first see it": `first` is written on the first "seen" (the stand within `FavEggSeenRange` (60) studs on the hub), not on join; the billboard shows the full 48 h until then.
- R4 "Leave them out": Zebra and Storm Front never come out of the egg.
- R5 stays: read the unread Roblox rewards post before publish.
