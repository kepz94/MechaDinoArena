# Shop v1.0 (main menu shop)

Status: built in Studio Edit 2026-11-24 (ShopScreen 1.0, MainMenu 1.29). Not published.
Mockup: docs/mockups/main_menu_shop_v0.1.html, option A "Featured + rows".

## Asks (Kepu 2026-11-24)
- 18:58 "a shop button on the main menu where it's dedicated to buying stuff you don't have. Look at how other games handle this".
- 19:11 "we're going to be selling other things in the store like animations and accessories".
- 19:12 "build the shop knowing other tabs will be added"; picks "A · Featured + rows", featured "Change every day".

## What it does
- MainMenu 1.29: orange SHOP tile under LAB (hero layout), NEW pill while ShopBadge. TUTORIAL moves under it.
- ShopScreen 1.0 (client): category tabs (CATEGORIES; v1.0 = SKINS), FEATURED (2 items, same for everyone, new every UTC day,
  one animated + one other), rows by price (149 / 499 / 999), 3D preview on your dino or any of the 8, BUY.
- Lists only items the player does not own. While SkinCatalog.ALL_UNLOCKED is on (test switch) every player owns every skin, so the
  shop says "YOU OWN EVERY SKIN".
- Buying a skin goes through the existing SkinServer 1.2 path (DinoSkinRequest "buy", tier product 149 / 499 / 999, credits).

## Adding animations / accessories later (agreed direction, 19:11)
- One purchase handler: Roblox allows one ProcessReceipt per game; today it is SkinServer. When a second item type is sold, move
  receipt handling into one ShopServer that routes grants to each item type's own server (skins, animations, accessories).
- One developer product per price, shared by every item type; the server remembers which item was tapped (SkinServer's intent).
- Each new type = one CATEGORIES entry in ShopScreen (all / owned / kind / buy) + its own server for owning and equipping.
- Equipping stays in the Lab; the SKINS tab would become LOOKS (Skins / Animations / Accessories) when the second type lands.

## Checked in Studio
- Phone emulator: tile + NEW badge on the menu; shop opens; featured (Element X, Obsidian Fang that day), rows, preview.
- Desktop clicks: tile opens the shop, card select, dino ◀ ▶ (T-REX), BUY -> server "owned" (test switch on) -> "ALREADY YOURS".
- Not checked: a real purchase (needs the test switch off and a Roblox purchase).
