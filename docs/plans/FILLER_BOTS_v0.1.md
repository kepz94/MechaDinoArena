# Mecha Dino Arena: Filler Bots v0.1 (planning)

Kepu 2026-11-25 21:16: bots on the island and in matches when there aren't enough players, acting like players (custom skins,
emotes, fighting each other with abilities, unique names with records), so the first players feel like they are in a lobby
against other people; island bots only while there are not enough players.

## Picks (21:20)
- Hub island fills to 8 dinos; one bot leaves per real player who joins (gone at 8 real players).
- Hub filler bots fight real players outside the safe area too (as players do).
- Arena matches fill to 4v4 (already the rule: PREGAME_LINEUP D6, PracticeServer 1.10 fills with 2 Elite + 2 Hard).
- Bot W-L: made-up, believable, fixed per name; never saved, never on the worldwide leaderboard.

## Grounding (repo = Studio, checked 2026-11-25)
- HubServer 1.7 / HubRules 1.2: hub kind, safe area, portals, Arena queue; ISLAND_HUB pick "no hub bots".
- BotServer 1.28: old island test bots, Enabled false.
- PracticeServer 1.10 + PracticeBots 1.1 / PracticeBrain(2) / PracticeKit / BotProxy: bots of all 7 non-T-Rex dinos with real
  abilities; Arena 4v4 fill bots on reserved Sandbox servers; names from PracticeRules.NAMES (single words).
- BOT tags today: PregameScreen 1.5 ("<TIER> BOT" plaque), HardpointHUD 1.7 scoreboard, KillFeed 1.2 (PC), PracticeLobby.
- IslandTags 1.2: name + W-L bar over players on the hub (players only).
- EmoteFX / TrailFX / mecha FX client scripts watch Players only (bot FX not drawn: open issue from the trailer shoot).

## Mockup
docs/mockups/filler_bots_v0.1/index.html (artifact "Filler Bots v0.1"): A Full disguise (recommended), B Island only,
C Reveal at results. Waiting on Kepu's pick.
