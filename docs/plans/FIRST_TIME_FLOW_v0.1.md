# Mecha Dino Arena — First-time flow v0.1 (planning, not built)

**Ask (Kepu 2026-11-22 06:19):** "Let's look at creating tutorials on how to use abilities as well as attacking."
06:2x: "look at how professional games handle this process and report back" (research below). 06:32, the flow:
"First someone gets welcomed to the game / they get to roll for a free Dino. It shows which one then next it also says you
get all the mecha parts unlocked for your first Dino as well. Then it goes into the first time using your attack button for
that Dino. Then it goes into equipping mecha parts then goes into trying out those abilities. Then on your first kill on a
bot in training you level up your Dino and unlock a skill point then equip it to a stat on the Dino. Then shows that you can
use skill points to upgrade your Dino stats and unlock mecha parts and unlock other Dino's too. Then go into the island."

**Kepu's answers (06:3x):**
- The other 6 dinos: "Locked until unlocked" (a new ownership system; today every dino is free to pick).
- Unlocking another dino is paid with: "Any dino's points" (today each dino has its own level and points).
- The free dino's mecha parts: "Fully maxed" (every part at its top step, free).
- Where the training happens: "Training area" (a small separate training ground with target bots).

## Code facts (main, 2026-11-22)
- No tutorial exists. No dino ownership or roll: SpeciesServer 1.8 switches to any known species; DinoSpecies saved as
  lastSpecies.
- Levels / points: per dino (SkillServer 1.2+); xpToNext(L) = 30 + 10 (L - 1); 1 point per level (SkillTree BUILD_LIMITS);
  practice bots give 10% kill XP (SkillServer 1.9, SkillXpMul 0.1); SkillGrantXp (1.10) can grant XP server-side.
- SkillTestMaxAllEnabled (SkillServer 1.11) is ON in the live game: every dino's stats and parts are maxed for testing. A
  real first-time flow needs it off for new players (decision).
- Attack inputs: PC per dino (Raptor Pounce F; the others left click), phone the big yellow ATTACK (ArenaTouch). Slots:
  PC keys R / C / T / V (MechaButtons), phone 4 slot buttons.
- The Lab already plays a live 3D clip of each mecha part (LabClipPlayer 1.0). PracticeBots can spawn a passive target bot.

## Research (how other games teach attacks and abilities)
- Apex Legends Training: required before any mode; HUD checklist, one task at a time; a training dummy; teaches one legend's
  two abilities. The Firing Range came later so players could try every legend / ability on dummies.
- Marvel Rivals Practice Range: hero targets with real HP, static / moving bots, ult refills, timed practice, a wall to break.
- Street Fighter 6 Character Guides: a looping demo of each move, press to try. Overwatch 2 Hero Mastery: per-hero courses,
  stars, rewards.
- Roblox Creator Docs: just-in-time tutorials; timed hints shown once, only to players who need them (e.g. 10 s / 11 s);
  arrows, spotlight dimming, clear feedback.
- League tutorial: quests, highlight + sound. Pokémon UNITE: small objectives, then a bot match. Brawl Stars: bot matches,
  hold-to-aim line on phone.

## Mockup
docs/mockups/first_time_flow_v0.1.html (artifact "First-Time Flow"): the 10 steps in three directions — A coach + checklist
(Apex Training), B story cards + spotlight, C quest board + timed hints (League / UNITE / Roblox) — PC and phone prompts.

## Waiting on Kepu
- The direction (A / B / C or a mix).
- Open decisions for the plan: the price to unlock a dino; skip (what a skipping player gets); existing players (they never
  see it? they keep every dino?); a replay button; the test layer (SkillTestMaxAllEnabled) for new players; the first kill's
  level-up (a tutorial XP grant, since practice bots give 10%).

## Writing (Kepu 2026-11-22 10:25: the mockup's text "sounded like AI too much"; research on how games write these modes)
- Apex Legends Training: checklist objectives are 1-5 word action phrases ("Jump", "Use your syringe", "Ping an enemy",
  "Pick up a second weapon"); the characters' lines are separate and longer.
- Game Developer, mobile dialogue: write like people talk (contractions, fragments, exclamations), cut filler words, teach
  mechanics with pop-ups and pointers rather than character speeches, show (the art) instead of describing.
- GameAnalytics, mobile game copy: about 14 words a sentence, rarely over 25; few exclamation marks and capitals; plain words
  ("get" not "obtain"); show what the player gets instead of adjectives; read it aloud.
- GDevelop (citing Nielsen Norman): people read about 20-28% of words on a page, fewer in games; one mechanic at a time;
  contextual prompts ("Space = Jump").
- AI tells to avoid (Fast Company, Wikipedia's guide): "It's not X, it's Y", em dashes used for punch, the rule of three,
  puffery / sales tags ("yours to keep").
- Animal Crossing: a friendly tone even when the player says no; let players skip text they've seen.
- The mockup v0.1 lines that broke these: em dashes in 7 lines, "yours to keep", "comes with every mecha part, fully
  upgraded", "Let's get you a dino of your own", "Nice!", explanations of what the player can already see.
