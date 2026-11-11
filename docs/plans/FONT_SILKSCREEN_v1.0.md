# Mecha Dino Arena — Silkscreen font for titles, buttons and numbers (v1.0)

**Goal:** the game's short, loud text (titles, buttons, tabs, chips, score, ability names, kill feed, damage numbers, name
tags) uses the Silkscreen pixel font; sentences stay in the current clean fonts so they stay readable on phones.
**Kepu 2026-11-11 16:33-16:38:** "can we fix the font of the game now. I have a specific font in mind but idk if we have to buy
rights to it" -> "Let's use SilkScreen font". **Picks (16:4x):** "B · Titles, buttons, numbers", "Shrink to fit". Mockup:
docs/mockups/font_silkscreen_v0.1.html (artifact "Silkscreen Font Options").
**Rights:** Silkscreen is in Roblox's own font library: asset 12187371840, creator Roblox, asset type 73 (font), Regular and
Bold (checked in Studio 2026-11-11 with MarketplaceService:GetProductInfo and TextService:GetTextBoundsAsync). It is also a
Google Font under the SIL Open Font License, so nothing to buy.

## What's live
- 51 scripts set fonts with Enum.Font: FredokaOne 100 places (titles, names, big numbers), GothamBlack 56 (labels, buttons,
  chips, some sentences), GothamBold 14 (mostly sentences: Lab step texts), RobotoMono 4 (small tags), SourceSansBold 2, Code 1.
  Some text is made by server scripts (BillboardGuis over characters: damage numbers, status words, name tags).
- Measured width for "MECHA ABILITIES" at size 20: GothamBlack 164 px, Silkscreen Regular 156, Silkscreen Bold 185 (+13%).

## Global constraints
- Additive: no edit to the 51 scripts. One new client script swaps fonts as text appears; a switch puts every original font
  and size back.
- PC and phone together. Version + VERSIONS / ATTRIBUTES rows.

## Do-not-touch
- Every script's own text, layout and sizes; Roblox's own menus (CoreGui); TextBoxes (typing fields).

## Rules
**Which text switches (FontSwapRules.classify)**
- Text from FredokaOne, GothamBlack, GothamBold, SourceSansBold (the "loud" fonts) switches to Silkscreen Bold when it is short:
  not TextWrapped and at most 24 visible characters (rich-text tags not counted), or TextScaled (scaled text always fits).
- Kept as it is: wrapped text and anything longer than 24 characters (sentences, descriptions, hints, step texts), TextBoxes,
  RobotoMono / Code (small mono tags), and any text with the attribute FontSwap = "keep". FontSwap = "silk" forces the swap.
- Re-checked when the text, the wrapping or the font changes (a label that grows into a sentence goes back to its font).

**Where:** everything under the LocalPlayer's PlayerGui, and BillboardGuis / SurfaceGuis in Workspace (in-world numbers and
tags; the change is on this client only).

**Shrink to fit:** a swapped label that is not TextScaled gets TextSize = round(its own size x the fit factor) so it takes
the space the old text did. Fit factor per original font = width of a sample in that font / width in Silkscreen Bold, measured
once at start (TextService:GetTextBoundsAsync, sample "MECHA ABILITIES 0123456789"), clamped 0.7-1.0; fallback 0.88. When a
script later sets a new TextSize, that becomes the label's own size and the factor is applied again. Minimum 8 px.

**Switch and diagnostics:** script attribute FontSwapEnabled (default true; read live: false puts every original font and size
back, true swaps again). LocalPlayer attributes FontSwapVersion, FontSwapCount (labels swapped now), FontSwapKept (labels
checked and kept), FontSwapFit ("Fredoka 0.86, GothamBlack 0.89, ...").

## Tasks
1. FontSwapRules 1.0 (src/client/FontSwapRules.luau, pure): plainLength(text), classify(info) -> "silk" / "keep", fitSize(size,
   factor). Mode Logic: tools/tests/FontSwapRules.spec.luau. (MDA-449)
2. FontSwap 1.0 (src/client/FontSwap.client.luau): watch PlayerGui + Workspace GUIs, swap / restore, fit factors, switch,
   diagnostics. Mode Wired. (MDA-450)
3. QA + docs: screenshots of the main menu, species picker, Lab (parts + clip panel + skins), match HUD (score card, SKILLS,
   ability bar), kill feed, damage numbers and name tags; switch off = the old fonts; count of swapped vs kept; frame time.
   (MDA-451)

## Red-team (2026-11-11)
1. **The 24-character rule guesses wrong** (a short sentence turns pixel, or a long title stays). Mitigation: per-label
   FontSwap attribute ("keep" / "silk") to fix any case without touching the rule; QA screenshots every main screen.
2. **Scripts that change TextSize every frame** could fight the shrink. Mitigation: the swap only reacts when the size differs
   from the one it set; QA watches the change count and frame time.
3. **Small pixel text on phones.** Silkscreen at 8-9 px can be hard to read. Mitigation: minimum 8 px; long text isn't swapped;
   Kepu's phone check after publish.
4. **The font loads a moment after joining**, so the first screen may flash the old font. Accepted (a fraction of a second);
   the swap preloads the font at start.

## Status (2026-11-11)
Plan + tickets filed; waiting for Kepu's "Build".
