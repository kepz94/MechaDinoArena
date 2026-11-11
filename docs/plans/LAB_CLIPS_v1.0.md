# Mecha Dino Arena — Lab part clips: a live 3D clip + one-line explanation per mecha part, Dilo first (v1.0)

**Goal:** in the Lab, every mecha part shows a short looping 3D clip of what it does, a plain one-line explanation and its key
numbers, so a player knows what a part does before buying it.
**Kepu 2026-11-11 14:37:** "I want each mecha part to have a preview of what it does in the lab menu with a short explanation.
Look at how other games handle menu attachments like this".
**Picks (2026-11-11):** "A · Live clip" (mockup docs/mockups/lab_part_preview_v0.1.html, artifact "Lab Part Previews");
"Built in the game" (not uploaded videos: 2,000 Robux per video, 54 parts); "Dilo first, then the rest" (this plan = the clip
system + Dilo's 7 parts; the other 6 dinos are follow-on plans after Kepu sees it); "Yes, fix them too" (stale texts).
Research: League of Legends / Valorant / Overwatch show a short clip per ability next to its text (League's clips went stale
after reworks, Riot re-records them in batches); Call of Duty Gunsmith shows stat bars and the stat change of an attachment
before you equip it; Deadlock tooltips label range / duration upgrades. Roblox: ViewportFrames do not draw ParticleEmitters
(or Beams / Trails / Highlights / BillboardGuis), so clip effects are made of neon parts and a 2D text layer.

## What's live
- Lab.client.luau v1.14: right detail panel (ScrollingFrame "Detail", UIListLayout by LayoutOrder): Sub (1) "AREA · KIND",
  Title (2), Steps (3: rows I / II / III / ★ from SkillTree stepText), Actions (4: BUY / UPGRADE, EQUIP / UNEQUIP), Hint (5).
  Cards use ReplicatedStorage.LabPreviews.<id> (LabPreviewServer 1.2). The stage is a ViewportFrame with a cleaned copy of the
  live character (scripts / sounds / billboards / particles / beams / trails / Hitboxes removed, all parts anchored).
- Dinos are animated by the character's IdleAnimation script (no Animation assets), so a copy in a ViewportFrame stands still.
- Live mecha parts: 54 (Dilo 7: dgatling, dmortar, dhiss, dspine, dpump, djets, dover).
- Stale Dilo texts after v680: Sonic Hiss steps say 20 / 25 / 30 studs (live 40 / 50 / 60, a 140° cone, DiloMovesServer 1.11);
  Venom Overdrive I says "your darts recharge at once" (live: also no ammo use and the 5 shots refill, DiloAttackServer 1.10);
  Cold Blood ★ says "the dart recharges" (live: refills all 5); StatSheet Dilo abilities say "Bite + Spit Dart" (spit only
  since DiloAttackServer 1.7).

## Global constraints
- Additive; numbers are attributes or recipe data; every change behind a switch; versions in headers + VERSIONS / ATTRIBUTES.
- PC and phone ship together (the full and the compact Lab, both sizes).
- Wording: "passive" in my reports; the in-game ALWAYS ON label is not changed here.

## Do-not-touch
- Every part's server / FX script and its numbers; SkillServer buying / slots; LabPreviewServer and the card models; the stage
  and the slots; the STATS rows; the SKINS tab and its detail panel; every other dino's texts.

## Rules
**Clip (Lab detail panel, MECHA ABILITIES and STATS part cards; not skins, not stat rows)**
- Under the Title: Clip box (width 100%, height = min(width x 10/16, 38% of the panel's visible height); corner 1.2ch;
  background 0B0E14; 1 px white stroke 0.92). Tags inside: "LIVE CLIP" (volt on 06242F, top-left) and "STEP I / II / III / ★"
  (yellow, top-right).
- Scene (ViewportFrame + WorldModel, one at a time): a 60 x 60-stud dark pad with a faint 8-stud grid; your dino (a copy made
  as the stage copy is) at the pad's back third facing forward; dummies (grey blocks 3 x 6 x 3, the practice-dummy grey) placed
  by the recipe. Camera behind and above the dino (FOV 40), framed to the recipe's reach. If the part isn't on your dino, its
  LabPreviews model is welded on at the recipe's attach point (bone name + offset).
- The dino moves as a whole (slide, lunge, hop, lean via the root pivot); no walk cycle (IdleAnimation can't run there).
- Effects are neon parts with tweened size / transparency; numbers ("-3", "+20", "SILENCED") are TextLabels on a layer over
  the ViewportFrame, placed by projecting the 3D point with the clip camera.
- Loop: 2.4–4 s per recipe, then a 0.3 s fade and restart; plays only while the Lab is open, the part is selected and the
  clip is on screen; destroyed on redraw, tab change and close.
- Under the clip: the What line (one sentence, GothamBlack max(1.75ch, 10), white, wraps) and the chips (wrapping row; chip =
  "LABEL value", GothamBlack max(1.35ch, 8), PANEL2 background, corner 0.8ch). Numbers are the shown step's.
- Step preview: tapping a step row shows that step in the clip and chips; chips whose value goes up from the step you own read
  "old → new" in yellow (3A2F0A background). The tapped row gets a yellow 0.4 stroke; tap it again (or pick another card) =
  back to the step you own (step I for a part you don't own).
- Order with the clip on: Sub 1, Title 2, Clip 3, What 4, Chips 5, then Steps 13, Actions 14, Hint 15 (the 1.14 items move
  by +10 only while the switch is on). A part with no recipe = no clip / what / chips (1.14 look).
- Switch: Lab script attribute LabClipEnabled (default true, read at each redraw; false = 1.14 exactly).
- Diagnostics (LocalPlayer): LabClipVersion, LabClipState ("off" / "none" / "playing" / "paused"), LabClipPart, LabClipStep
  (1–4), LabClipParts (instances in the scene).

**Recipes (src/shared/LabClipRecipes.luau)** — one per part id: what, chips (label, key, unit) and per-step numbers, attach,
template + its placement. Templates in this plan (enough for the Dilo; later dinos add their own):
- burst: n darts from the attach point to 1–2 dummies over 1 s, "-dmg" pops, the dummy tints venom green.
- lob: a canister arcs to `reach` over 1 s, a green disc `cloud` wide grows and pulses for min(lasts, 3) s; dummies in it tint
  and pop "-poison".
- cone: a fan of neon slats `range` long and `cone`° wide sweeps out in 0.45 s; dummies inside slide back 9 studs and show
  "SILENCED n s"; one dummy outside is untouched.
- ring: n spines fly out all around to 14 studs; dummies hit pop "-dmg" (green when venom).
- self: a glow shell on the dino + "+heal" / "CLEANSED" / "IMMUNE n s" pops; for dover a fast spit stream at a dummy with the
  ammo pips staying full (labelled "NO AMMO USED").
- dash: `charges` dashes of `dist` studs (zig-zag), a ghost trail, green poison trail when the step has it.
Dilo recipes (numbers from the SkillTree step texts and the live server values):
- dgatling burst: darts 4 / 6 / 6 / 8, damage 3, recharge 12 / 12 / 10 / 10.
- dmortar lob: reach 40 / 50 / 50 / 60, cloud 16 / 20 / 20 / 24, lasts 3 / 3 / 4 / 5, recharge 16.
- dhiss cone: range 40 / 50 / 50 / 60, cone 140°, silence 1.5 / 1.5 / 2 / 3, recharge 15 / 15 / 12 / 12.
- dspine ring: spines 6 / 8 / 8 / 12, damage 4, venom no / no / yes / yes, recharge 12.
- dpump self: heal 15 / 20 / 30 / 30, immune 0 / 0 / 0 / 4 s, recharge 20.
- djets dash: dash 25 / 30 / 40 / 40, charges 1 / 2 / 2 / 3, poison trail no / no / yes / yes, recharge 6.
- dover self: lasts 4 / 6 / 6 / 8, double venom no / no / yes / yes, recharge 30.
What lines: dgatling "Fires a quick burst of auto-aimed darts that poison whoever they hit."; dmortar "Lobs a canister far
ahead that leaves a poison cloud where it lands."; dhiss "Blasts a wide cone in front of you: dinos in it are knocked back and
their mecha parts shut off."; dspine "Fires spines out all around you, hitting every dino close by."; dpump "Clears your
debuffs and heals you."; djets "Dashes you a short way in the direction you're moving."; dover "For a few seconds your spit
never runs out and never has to wait."

**Stale texts (SkillTree / StatSheet, behind SkillTree.DILO_TEXTS_V2 / StatSheet.DILO_ABILITY_V2, default true)**
- dhiss: "Button: the hood speakers blast a 40-stud, 140° cone: dinos are knocked back and their mecha parts are silenced
  1.5 s. Recharges in 15 s" / "Cone reaches 50 studs" / "Silence lasts 2 s; recharges in 12 s" / "Cone reaches 60 studs,
  silence lasts 3 s".
- dover I: "Button: for 4 s you spit with no wait and no ammo use, and your 5 shots refill. Recharges in 30 s".
- coldblood ★: "Below 30% health: double damage, and once per life your 5 shots refill the moment you drop below 30%".
- StatSheet Dilo abilities: "Spit Dart (5 shots)", "Cobra Leap".

## Tasks
1. SkillTree 1.89 + StatSheet 1.8: the stale texts (Mode Logic: tools/tests/DiloTexts.spec.luau checks the four texts and
   that the switches off give the 1.88 / 1.7 texts). (MDA-441)
2. LabClipRecipes 1.0: the 7 Dilo recipes (Mode Logic: tools/tests/LabClipRecipes.spec.luau — every live Dilo part has a
   recipe, 4 steps of numbers, every chip key present, known template, the dhiss / dmortar / djets numbers appear in that
   step's SkillTree text). (MDA-442)
3. LabClipPlayer 1.0 (src/shared, used by the client only): mount(parent, id, step, ctx) / setStep / unmount; the scene,
   the camera fit, the six templates, the text layer, the loop and pause. (Mode Wired.) (MDA-443)
4. Lab 1.15: clip + what + chips under the title, the +10 order shift, step rows tap to preview, unmount on redraw / tab /
   close; full and compact Lab, PC and phone. (Mode Wired.) (MDA-444)
5. QA + docs: each of the 7 Dilo clips on PC and forced-touch phone size, full and compact Lab; step preview yellow chips;
   switch off = 1.14 (layout hash of the detail children); LabClipParts back to 0 on close; frame time with the clip running;
   VERSIONS / ATTRIBUTES rows. (MDA-445)

## Red-team (2026-11-11)
1. **The dino doesn't walk in the clip.** A copy in a ViewportFrame has no running IdleAnimation, so it slides and lunges
   stiffly. Mitigation: root-pivot motion (lean, hop, recoil) per template; Kepu sees the 7 Dilo clips before any other dino
   is built (that's the rollout pick). If it looks too stiff, a follow-on can pose the joints from DiloPose.
2. **Numbers in two places** (recipe vs the server scripts), the same staleness League has. Mitigation: the recipe spec checks
   the numbers against the SkillTree step texts, and any future tune changes the recipe in the same commit (added to the
   change checklist in VERSIONS).
3. **Phone room.** The clip, the line and the chips push BUY / EQUIP down in the compact Lab on a phone. Mitigation: the clip
   height is capped at 38% of the panel's visible height and the panel already scrolls; QA screenshots the compact Lab at
   phone size and checks the buttons are reachable.
4. **Cost on phones.** A WorldModel costs physics time even when idle. Mitigation: only one clip exists, everything is
   anchored, it's destroyed on close / tab change, and it pauses while off screen; QA measures frame time.
5. **54 recipes is a lot of data.** Accepted: 6 templates cover the Dilo; later dinos reuse them and add only what they need
   (place-an-object, pull, passive hit), one dino per follow-on plan.

## Status (2026-11-11)
Plan + tickets filed; Kepu "Build" 14:59.

## Build (2026-11-11)
Commits b3093d3 (texts), a091d99 (recipes), 3c78c7a (player + Lab), 966d663 + 17f7e20 (QA fixes); all installed in Studio,
hashes match.
- Changes from the plan: the two modules live in StarterPlayerScripts next to Lab (src/client/LabClipRecipes.luau,
  src/client/LabClipPlayer.luau), as DiloPartsVFXLib does, because src/shared maps to ServerStorage (server only). The live
  numbers are the SkillTree texts after the 1.76 pass (Toxin Mortar reach 80 / 100 / 120, cloud 24 / 30 / 36; Spring Jets
  40 / 50 / 65 studs, recharge 4.2 s), not the raw part() numbers the plan listed.
- Attach points measured in Play from DiloPartsServer's BuildPreview_<id> on a DiloModelData mannequin (rest space, scale 1).
- Camera: behind-right 3/4 view (M.CAM); the scene grows to at least 1.8 dino lengths (the Studio test dino is scale 2,
  26 studs long), and the close-range templates (burst / ring / over) place targets past the dino's head.
- QA: see the VERSIONS row. Not checked on a real phone; Studio's Play view is a 325 px column.

## Other dinos (v1.1, 2026-11-11)
Kepu 15:37 after the v686 check: "Looks great keep going with other Dino's" (the rollout pick's go-ahead; same look as the
Dilo, so no new mockup). MDA-446 (LabClipPlayer 1.1), MDA-447 (LabClipRecipes 1.1), MDA-448 (QA).
- Recipes for every live mecha part of Raptor 7, Pachy 8, Herrera 8, Teno 7, Therizino 7, Troodon 10 (47). Numbers = the live
  SkillTree 1.89 step texts read in Studio; where a text gives no number (for example "Recharges 26% faster"), the chip is a
  YES / NO flag instead of an invented number. Attach points measured from each part's BuildPreview on its dino's mannequin.
- New templates (LabClipPlayer 1.1): shot (stun / pull / reel / hold / split), throw (mine / spike / boulder / goo / dome /
  wall / turret / lantern / heal), wave (buff / mark / stomp / drag), buff (heal / speed / cloak / smoke / scan / shield /
  front / free / drone / zone / lunge / fling), move (boost / leap / glide), place (pad / caltrops / portal). cone and burst
  take optional fx with the 1.0 values as defaults, so the Dilo clips are unchanged. Allies are blue dummies.
- Lab 1.15 needed no change (it shows a clip for any part with a recipe; passive cards on STATS too).
- QA: LabClipRecipesAll.spec PASS 1461 (54 live parts all have recipes; 47 parts' numbers found in their texts); every one of
  the 47 clips run frame by frame at step I and ★ on its own dino with no error; screenshots of 20 of them at the PC panel
  size; Lab check as the Troodon (MECHA ABILITIES cards and the passive Bloom Tank on STATS mount clips; one ClipView at a
  time). Fixed in QA: see-through puddles / heal burst, solid sap wall, a long boost shown shorter (the chips keep the time),
  leap framing, stacked labels spaced out.
- Long-reach parts (Shock Cannon 200-270, tether 180, Boulder Mortar 180, portal 185-250) show the target closer than the real
  reach; the chips show the real number.
