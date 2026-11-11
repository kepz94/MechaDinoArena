# Mecha Dino Arena — Team Tags v1.0 (friend or foe)

**Goal:** in a Hardpoint match (Arena and the Sandbox practice match), you can tell at a glance which dinos are on your team
and which are enemies, without a name and health bar over every dino.
**Chosen direction:** B · Friends marked, enemies when it matters (Kepu 2026-11-10 21:5x, "B · Friends marked (Recommended)").
Mockup: docs/mockups/team_readability_v0.1.html (artifact "Friend or Foe Options").
**Architecture:** one new client script, TeamTags 1.0, draws per-viewer markers (each player sees their own team blue) from a
pure rules module, TeamTagRules 1.0. The plates that are live today are not changed on the server: BiteTargetHealth's
"TargetBar" billboards are only hidden on this client while TeamTags runs, by MaxDistance 0, and enemy bars get a red fill, so
TargetHUD's existing on-screen bar for the dino you are hitting turns red with no change to TargetHUD.

## The problem (live v699, 2026-11-10 21:42)
- Every practice bot has BiteTargetHealth's plate: white name and green bar, a fixed 170 x 40 px at any distance, out to 200
  studs. Nothing on it shows the team. Checked in Play: 8 TargetBar plus 9 StatusBadges billboards on screen.
- Players get HardpointHUD 1.2's blue / red name tags; bots don't.

## Global constraints
- Additive only; every number is an attribute; every piece has a switch; version headers + VERSIONS / ATTRIBUTES rows.
- PC and phone ship together. Phone = UserInputService.TouchEnabled or the character's ArenaTouchState == "on".
- Runs only while ReplicatedStorage.Hardpoint HpLive == true and your HardpointTeam is "A" / "B". Otherwise nothing
  changes (free-roam Sandbox, BotServer bots, the training dummy, the Lab).
- Your team is always blue rgb(90,160,255) (text rgb(140,192,255)), enemies red rgb(224,40,74) (text rgb(255,143,163)), as
  in HardpointHUD and KillFeed.

## Do-not-touch
- BiteTargetHealth (server plates, KO / reset), TargetHUD 1.2 (target choice, the float copy), CloakFX 1.4, StatusBadges,
  KillFeed, PracticeServer / PracticeBrain, every attack server.

## Rules (direction B)
| Dino | Shown | PC | Phone |
|---|---|---|---|
| Teammate (same team, alive, not you) | always, through walls and trees, out to TeamTagsFriendMax 400 studs | blue ◆ + name (FredokaOne 14) | blue ◆ + name (FredokaOne 12) |
| Enemy, "engaged" | you hit it (TargetHUD's target), or it lost health in the last 4 s while within 60 studs, or it is within 25 studs; and in sight, not cloaked | red bar + red name | red bar only |
| Enemy, otherwise | within TeamTagsChevronMax 130 studs, in sight, not cloaked | small red ▼ | small red ▼ |
| Enemy out of sight / cloaked / further | nothing | — | — |

- "In sight" = a ray from the camera to the dino's head is not blocked by the world (bushes, tall grass and trees count);
  dinos and their hitboxes are left out of the ray. Checked every 0.2 s per enemy.
- The dino you are hitting keeps TargetHUD 1.2's floating bar (kept on screen, 4 s after your last hit); TeamTags does not
  draw a second bar for that dino, it only makes its fill red.

## Deterministic map
| State | Trigger | End state |
|---|---|---|
| off | TeamTagsEnabled false, or HpLive not true, or your HardpointTeam not A / B, or you are in the menu | no markers; every hidden TargetBar back to MaxDistance 200 and its own fill colour |
| friend | other dino's team == yours, alive | ◆ + name |
| friend dead / removed | Humanoid health 0 / DummyHealth <= 0 / model gone | marker removed |
| enemy chevron | enemy, alive, dist <= 130, in sight, not cloaked, not engaged | ▼ |
| enemy engaged | as above and (TargetHUD target or hurt within 4 s at <= 60 studs or dist <= 25) | bar (+ name on PC); skipped when it is TargetHUD's shown target |
| enemy hidden | out of sight, cloaked (CloakedUntil in the future), dist > 130, dead | nothing |
| team unknown | a dino with no team (no HardpointTeam / HardpointBotTeam) | nothing; its TargetBar left as it is |

## Tasks (build order)

### Task 1 — TeamTagRules 1.0 + spec · Mode: Logic
**Files:** create src/shared/TeamTagRules.luau (ReplicatedStorage.TeamTagShared), tools/tests/TeamTagRules.spec.luau.
**Interfaces:** `relation(myTeam, theirTeam) -> "friend" | "enemy" | "none"`;
`markFor(rel, info) -> "none" | "friend" | "chevron" | "bar"`, info = {alive, dist, inSight, cloaked, isTarget, hurtAgo, phone};
constants FRIEND_MAX 400, CHEVRON_MAX 130, ENGAGE_NEAR 25, HURT_WINDOW 4, HURT_MAX 60.
**Acceptance:** every row of the rules table and the map; spec PASS count recorded.

### Task 2 — TeamTags 1.0 (client) · Mode: Wired
**Files:** create src/client/TeamTags.client.luau.
**Layout:** ScreenGui "TeamTags" (ResetOnSpawn false) holding one BillboardGui per dino (Adornee = Head.Root, else Head, else
HumanoidRootPart; StudsOffsetWorldSpace above the head like TargetBar; AlwaysOnTop true; LightInfluence 0). Sizes in px
(they don't grow up close): ◆ 10 px, name 14 px (PC) / 12 px (phone); ▼ 12 x 9 px; bar 70 x 7 px (phone 56 x 6).
Who: other players' characters with HardpointTeam, and models in DinoIsland.Bots with HardpointBotTeam.
Old plates: while on, each such dino's TargetBar gets MaxDistance 0 (stored old value in attribute TeamTagsOldMax) and, on
enemies, Fill colour red (old colour in TeamTagsOldFill); both put back when off. Players' HardpointHUD name tags are left to
Task 3.
Updates: markers every frame from cached state; sight rays + team / hurt reads every 0.2 s.
Switches: TeamTagsEnabled (true); numbers TeamTagsFriendMax, TeamTagsChevronMax, TeamTagsEngageNear, TeamTagsHurtWindow,
TeamTagsHurtMax. Diagnostics: TeamTagsVersion, TeamTagsState ("off" / "on"), TeamTagsFriends, TeamTagsChevrons, TeamTagsBars.
**Acceptance:** practice match PC + forced touch screenshots; a teammate behind a tree keeps ◆; an enemy behind a tree has
nothing; a cloaked enemy has nothing; hitting an enemy turns TargetHUD's bar red; leaving the match restores the old plates.

### Task 3 — HardpointHUD 1.3: name tags step aside · Mode: Wired
**Files:** modify src/client/HardpointHUD.client.luau. While PlayerGui.TeamTags exists and its script's TeamTagsState is "on",
the 1.0 name tags are not drawn (switch HardpointHUDTagsYieldEnabled, default true; false = 1.2).
**Acceptance:** in the Arena, players show TeamTags markers only, not both.

### Task 4 — QA + docs · Mode: Wired
Practice match: 5v5 screenshots PC + forced touch; client frame time with TeamTags on vs off; Arena check with the
ArenaPvPTest target dummy. VERSIONS / ATTRIBUTES rows, Dev Hub notes.

## Red-team (2026-11-10)
1. **"An enemy you hit" is not one signal.** TargetHUD knows bites, pounces, bleed and Shock Cannon / Mine / Arena hits; other
   attacks (slash, headbutt, claws, scratch, dart, pod) leave no "who hit" mark on bots. Mitigation in the rules: an enemy
   that lost health in the last 4 s within 60 studs also counts, and anything within 25 studs does. Effect: a bar can show on
   an enemy a teammate is hitting near you. Decision for Kepu.
2. **Markers can give away hidden dinos.** A ▼ through a wall would reveal a cloaked or bush-hidden enemy. Mitigation: enemy
   markers need a clear line of sight and no cloak; only teammates show through walls.
3. **Three scripts touch the same billboard.** TargetHUD and CloakFX switch TargetBar.Enabled on and off. Mitigation:
   TeamTags never touches Enabled; it uses MaxDistance 0 and the fill colour, so their toggling keeps working.
4. **Scope.** Arena players get it too (Task 3 removes the old tags so there are not two). Free-roam Sandbox / BotServer bots
   unchanged. Decision for Kepu: Arena now, or practice only first.
5. **Phone.** Teammates show the ◆ only (no names), enemies bar only. Decision for Kepu if names are wanted on phones.

## Kepu's answers (2026-11-10)
- Hit rule: "Hurt nearby counts" — kept as written (hurt in the last 4 s within 60 studs, or within 25 studs).
- Scope: "Both, Arena too" — Task 3 stays.
- Phone: "Teammate names on phone" — teammates show ◆ + name (12 px) on phones too; enemies stay bar only on phones.

## Build notes (2026-11-10)
- TargetBar hiding uses MaxDistance 0.001: in the Play check, MaxDistance 0 still showed the plates (0 = no limit).
- TeamTags 1.1: BillboardGuis with AlwaysOnTop did not draw at all, so markers are screen Frames placed every frame from
  WorldToViewportPoint (same look and rules; teammates still show through walls).
