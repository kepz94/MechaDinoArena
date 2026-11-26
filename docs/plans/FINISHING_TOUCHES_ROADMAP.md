# Mecha Dino Arena — Finishing Touches Roadmap (2026-11-26)

Kepu 2026-11-26 03:55: "a quest stand where 3 daily quests are placed as well as special quests. this is the only place where you can claim them ... random achievements they can collect on through either the island fighting or the arena or both ... a skin unlock for favoriting the game/liking it ... a fire streak emblem once you go on a killing spree on the main island. 25 kills streak unlocks the thunder storm skin. 10 kill streak unlocks the zebra. these will also be in the daily quest thingy for this week ... having attack buttons locked on spawn and up until the timer goes down. the bots are just fighting right at spawn even without damage". 03:56: "the daily quest rewards will be skill points for the basic daily quest".

This is several independent systems, so it is split into separate plans (feature-planning scope check). Each gets its own mockup / plan / red-team / build.

## Decisions so far (Kepu 2026-11-26)
| # | Decision |
|---|---|
| D1 | Basic daily quest reward = skill points. |
| D2 | "Make all points universal": skill points become one shared pool across dinos (replaces the Oct 29 per-dino rule, SkillServer 1.2). Structural change, own plan + migration + red-team. |
| D3 | Zebra and Storm Front: the 10 / 25 island kill streaks REPLACE their old unlocks (Zebra "Win 15 Arena matches", Storm Front 999 Robux). |
| D4 | Streak kills = players and bots, main island only, reset on death. |
| D5 | Favorite reward: an in-game FAVORITE button opens Roblox's favorite prompt (AvatarEditorService:PromptSetFavorite); the skin unlocks once the game is favorited (GetFavoriteAsync). Likes can't be detected by any Roblox API, so likes are not rewarded. |
| D6 | Attack lock = the island PROTECTED timer (on the islet and the 3 s guard after leaving it), not the Arena countdown. |

## Pieces and order (proposed)
1. **Island spawn attack lock** (bug-sized). Grounding: HubServer 1.x sets character HubSafe on the islet and for HubRules.GUARD (3) s after leaving; ArenaPvP makes a HubSafe dino un-hittable; FillerServer 1.1 already skips HubSafe players as targets. The existing lock (PrematchLockUntil) blocks every move incl. JUMP and dashes, so it can't be reused as is on the islet.
2. **Universal skill points** (SkillServer structural change, D2).
3. **Island kill streak + fire emblem + Zebra / Storm Front unlocks** (D3, D4).
4. **Quest Stand**: 3 daily quests (skill points) + special / weekly quests (this week: 10 streak -> Zebra, 25 streak -> Storm Front); claim only at the stand. Needs a mockup.
5. **Achievements**: a set of island / Arena / both achievements (list drafted for Kepu's approval), shown at the Quest Stand. Needs a mockup.
6. **Favorite skin** (D5): which skin is the reward is open.

## Open questions
- Piece 1: lock attacks only (JUMP, dashes, shield, heals still work on the islet) or everything like the Arena countdown?
- Piece 1: what did the bots do: attack you at spawn, or fight each other near the islet?
- Order of the pieces.
- Piece 6: which skin (a new one, or an existing one)?
