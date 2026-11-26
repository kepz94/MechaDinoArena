# Front page v0.1 (game icon, thumbnails, title + description)

Kepu 2026-11-25 19:16: "Let's work on having our front page now/logo". Scope picked (19:17): game icon / logo (512x512),
thumbnails (1920x1080), title + description text; icon shown both with and without the name text.

## Research (Roblox creator docs)
- Icons (create.roblox.com/docs/production/promotion/game-icons): square, at least 512x512; shown as small as 150x150, so
  check detail at that size; show what players find in game, avoid ambiguous graphics; one icon per locale; moderated.
- Thumbnails (create.roblox.com/docs/production/promotion/thumbnails): 16:9, ideally 1920x1080; up to 10 images or videos;
  personalization needs 2+ active (activate 2-5), files under 3 MB; keep text and key elements off the bottom edge (player
  count covers it); show real gameplay.
- Kepu's 18:52 screen recording of the Discover page: icons are one big character face, little or no text; the 16:9 tiles
  in the rows use big bold text tags.

## Mockup v0.1
docs/mockups/front_page_v0.1/index.html (+ images). All pictures are real Studio frames (Game Bar recordings 19-22-50 and
19-23-51 for the lineup and icon shots; 18-39-24 and 18-59-30 from the trailer shoot), cropped and scaled, text added in
post with Silkscreen 700 and the trailer's MECHA DINO ARENA logo card.
- Icons: A Lava Raptor up close with the T-Rex behind; B Lava Raptor against the sky; C T-Rex looming over the Raptor. Each
  as 1 (no text) and 2 (with the name). Previewed at 150 px.
- Thumbnails: T1 8 DINOS (all 8 playable dinos lined up: Therizino, Teno, Herrera, T-Rex, Raptor, Pachy, Troodon, Dilo),
  T2 MECHA PARTS, T3 BATTLE ON THE ISLAND, T4 SKINS & TRAILS, T5 SHOCK CANNON.
- Title options: 1 "Mecha Dino Arena", 2 "Mecha Dino Arena 🦖", 3 "[NEW] Mecha Dino Arena". Description draft in the mockup.
Filming setup (Play session only, nothing saved): practice bots cloned to ServerStorage.TrailerBots, a 7-dino lineup in
Workspace.CINE_Lineup (scripts removed, anchored; the T-Rex is a StarterCharacter copy scaled x1.63 to its in-game length,
about 62 studs). Account: Raptor slots set to adrenaline / screech / thrusters for the shots, cleared after. Restored: Play
stopped, ModeTestPractice nil, SkillTestMaxAllEnabled false, panels and window as before.
Waiting on Kepu's picks. Final files (1920x1080 / 512x512) are rendered from the same frames once picked; upload is Kepu's.

## Mockup v0.2 (2026-11-25 19:58)
Kepu 19:35: "Looks trash"; 19:38: "Everything other than T2 and T4 is straight ass. You're not following the rules for how to
market a game / key things to have in an icon."
Rules applied (sources: Roblox game icons + thumbnails docs; rowatcher.com "Your Roblox Game Icon Is Losing You Players";
supersonic.com icon A/B tests): one dominant subject filling the frame on a clean high-contrast background; clear emotion
and action; the fantasy in one look; works as an ad, not a screenshot; warm colours stand out from Roblox's cool UI; no title
text on the icon (A/B: removing text and enlarging the character +10%); heavier outline (+7%); judge at 150 px.
Method: Studio green screen. A magenta box (Workspace.CINE_Stage at 600, 300, 600, Play only) behind the dinos; the Lava
Raptor's jaw held open locally (Jaw Motor6D Transform, client only, as in the bite pose); showcase dinos are anchored copies
of practice bots in Workspace.CINE_Show; recording 19-40-18. tools/frontpage/key.py keys out the magenta (min(r,b) - g,
greys kept) with despill; tools/frontpage/comp.py builds the sunburst backgrounds, the white + dark outline with glow, and
the 3D title text (gold gradient, dark extrusion, shadow).
- Icons: V1 roaring Raptor + charged Shock Cannon on a blue burst; V2 the same on an orange burst; V1 + NAME (shown only
  because Kepu asked to see both).
- Thumbnails: T1 PICK YOUR DINO (6 cutouts on an orange burst), T2 MECHA PARTS (kept), T3 MECHA BATTLES (Raptor fires on
  the Pachy, blue burst), T4 SKINS & TRAILS (kept). T2 / T4 get the new 3D title text. Old T3 / T5 dropped.
- Description: "and emotes" removed from the Shop line (not confirmed that emotes are sold there).
Restored: Play stopped, ModeTestPractice nil, SkillTestMaxAllEnabled false, Raptor slots empty, panels and window as before.

## Front page v1.0 (final, 2026-11-25 20:19)
Kepu 20:06: "V1 + name. And I approve the rest of it." Kepu 20:13: "Mecha battles is glitched" (a stray part from the filming
stage was pasted over the Pachy's head; fixed by keeping only the largest cut-out piece); 20:14: "For the mecha battles just
have the raptor shooting the shock cannon at you in a cool style".
Files (docs/front_page_v1.0/, copies on Kepu's PC in C:\Users\Kepu_\Videos\MechaDinoArena_FrontPage):
- icon_512.png (upload) and icon_1024.png (master): V1 + NAME.
- thumb_1_pick_your_dino.jpg: re-filmed closer (recording 20-09-37), same layout as v0.2 T1. The Pachy bot's skin is the
  grey / blue one this time (v0.2 showed the tan one).
- thumb_2_mecha_parts.jpg, thumb_4_skins_and_trails.jpg: as approved in v0.2.
- thumb_3_mecha_battles.jpg: the Lava Raptor fires the Shock Cannon toward the viewer (recording 20-17-29, frame 3.563 s:
  the ball just out of the barrel with the muzzle ring), 3/4 front, cut out on the blue burst. No Pachy.
Title not picked (options 1-3 in the mockup); description approved as in the v0.2 mockup. Upload is Kepu's.
Restored after each shoot: Play stopped, ModeTestPractice nil, SkillTestMaxAllEnabled false, Raptor slots empty, panels and
window as before.
- 20:19 Kepu: "that's literally glitchy as hell. There's two shocks and the raptor face is blocked." The second "shock" was the
  cannon's muzzle flash (ScreechServer muzzleFlash part "ShockMuzzleFlash", a see-through ball at the barrel for 0.2 s)
  sitting on the Raptor's face. Re-shot (recording 20-20-55) with that part hidden on the filming client only
  (LocalTransparencyModifier 1, Play session), Raptor turned so the ball leaves past the camera on the left; frame 3.50 s:
  one ball clear of the head, face and cannon visible. Built with tools/frontpage/t3build.py (keeps the two largest
  cut-out pieces: the Raptor and the ball). A cyan re-tint of the ball was tried and dropped (it flattened the glow).
