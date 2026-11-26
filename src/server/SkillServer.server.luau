-- SkillServer v1.8 (Mecha Dino Arena) — skill tree XP, levels, points, buy / respec and saving. MDA-12, plan
-- docs/plans/SKILLTREES_v1.0.md Task 2, ADR "Skill trees own XP and replace class stat points".
-- Kepu: kills give XP, each level gives 1 skill point (cap 60), free respec any time, keep everything on death, builds
--   saved. GrowthServer stays off (adult spawns); this script owns skill XP. Maths: ServerStorage.DinoArcade.SkillTree.
-- Client copy: at start SkillTree is cloned into ReplicatedStorage.SkillShared (folder) for SkillScreen 1.0.
-- XP: every model with IsBot = true is watched (the KillRegenServer 1.0 pattern). A new KilledAt value on a bot
--   (BiteServer / PounceServer / SkillEffects bleed stamp KilledBy, KilledByUserId, KilledWith, then KilledAt) credits
--   the player KilledByUserId (else the player named KilledBy) with DummyMaxHealth x SkillKillXpFraction XP, rounded.
--   Each bot's KilledAt value is counted once. A killer who is not in the game is not credited (bot attribute
--   SkillXpCredited = "noPlayer"; else the player's name). Dead killers are credited (state lives on the Player).
--   Player kills come later with PvP.
-- Requests: RemoteEvent ReplicatedStorage.SkillRequest, client -> server ("buy", pathId) or ("respec"). Before the
--   player's data is loaded, or within REQUEST_GAP s of the last request -> "busy". Bad arguments -> "badArg".
--   buy: SkillTree.buy with the player's points; respec: every step back to 0 (free). Result in SkillLastResult.
-- Saving: DataStore SAVE_STORE, key "u" .. UserId, value {v = 1, xp = total XP, steps = {[pathId] = n}}. Loaded at join
--   (SkillSaveState "loading" -> "loaded" (data found) / "new" (no data) / "noApi" (Studio without API access) /
--   "failed" (any other error: the session goes on with a fresh build and saving is retried every RETRY_GAP s)).
--   Saved when something changed, at most every SAVE_GAP s, and on leave and server close -> "saved" (or "failed").
--   SkillSaveEnabled = false: no loading or saving ("off"), session only.
-- Player attributes (all written here): SkillLevel, SkillXP (total), SkillXPInto, SkillXPNext (0 at max), SkillPoints
--   (earned), SkillSpent, SkillLeft, SkillPath_<pathId> (0-4, every path), SkillLastResult, SkillLastXp ("kill +30"),
--   SkillSaveState, SkillLevelUpAt (server time, on a level-up from XP).
-- Script attributes: SkillServerVersion, SkillEnabled (default true; false = no XP and requests -> "disabled"),
--   SkillKillXpFraction (0.5), SkillSaveEnabled (true), SkillKillsCounted (total credited kills).
-- v1.1 (mecha loadout, MDA-25, plan docs/plans/MECHA_THRUSTERS_v1.0.md Task 2): 2 loadout slots (SkillTree 1.1).
--   Save value {v = 1, xp, steps, loadout = {[1] = id or false, [2] = id or false}}; loaded through
--   SkillTree.sanitizeLoadout (a save without loadout -> both empty). Buying a step of a BUTTONS path runs
--   SkillTree.autoSlot (the first step fills the first empty slot). Request ("slot", n, pathId or "") -> SkillTree.setSlot
--   ("" = clear); result "ok" / "badSlot" / "notButton" / "notOwned" in SkillLastResult (bad argument types -> "badArg").
--   Respec empties both slots. Player attributes SkillSlot1 / SkillSlot2 (path id or ""). Script attribute
--   SkillLoadoutEnabled (default true; false -> slot requests "disabled", buys don't auto-slot, the loadout stays as is).
-- v1.2 (skills per dino, MDA-44, plan docs/plans/SKILLS_PER_DINO_v1.0.md Task 1; Kepu 2026-10-29: "the skill points
--   should be separate for each dino" -> everything per dino, reset all):
--   * Each dino has its own record {xp, steps, loadout}. The dino key = the character's Species attribute, else the
--     player's DinoSpecies, else "TRex"; script attribute SkillPerDinoEnabled (default true) = false -> one record "All".
--   * The active record lives in the same d.xp / d.steps / d.loadout fields as before, so buy / respec / slot and the kill
--     XP act on the dino being played (a kill credits the dino played when its KilledAt is counted). On CharacterAdded and
--     when the character's Species changes, a different key stores the active fields in d.dinos[old key], loads the new
--     key's record (fresh {0 XP, no steps, empty loadout} if none) and publishes it with no level-up stamp. Player
--     attribute SkillDino = the active key.
--   * Saving: new DataStore SAVE_STORE_V2 "MDA_Skills_v2" (Kepu: reset all; "MDA_Skills_v1" is no longer read or written
--     and stays as it is), value {v = 2, dinos = {[key] = {xp, steps, loadout}}}. Each loaded record is sanitized like
--     1.1 (a build over its points is refunded, the loadout sanitized); a value without v = 2 counts as "new".
-- v1.3 (Cloak release, MDA-50, plan docs/plans/CLOAK_v1.0.md Task 2; SkillTree 1.5, ADR-003 / ADR-004):
--   * The active dino key goes into every SkillTree call (sanitize / spent / buy / autoSlot / setSlot / sanitizeLoadout):
--     a dino only buys, slots and keeps its own paths plus the shared ones it isn't skipped from. A buy of another
--     dino's path -> SkillLastResult "otherDino"; a 4th mastered line -> "masteryFull" (SkillTree 1.5).
--   * Loaded records (cleanRecord(raw, key)) are sanitized for their dino (e.g. a T-Rex record's Thrusters / Regeneration
--     steps are dropped and their points come back); a record over Mastery 3 has every line cut back to step II; then,
--     as before, a build over its points (now 40 at level 41) is refunded.
--   * Empty loadouts are built from SkillTree.SLOTS (4): fresh records, the load default and respec.
-- v1.4 (test unlock; Kepu 2026-10-29: "for testing sake we'll have whatever we just implemented unlocked", private
--   publish; picked "Cloak given" + "Test switch only"): script attribute SkillTestCloakEnabled (default false; set true
--   on the place's SkillServer for testing). While it is true and the active dino is "Raptor", publish shows a test layer
--   over the real record: SkillPath_cloak = 4 (star) and SkillSlot1 = "cloak" (Cloak removed from any other slot; the
--   real slot-1 part is hidden while the layer is on). SkillEffects / CloakServer / the screens read those attributes, so
--   the Cloak works at star in R. The layer is never stored: d.steps / d.loadout, points, buys, slots and the save stay
--   the real record, so switching the attribute off (or playing the T-Rex) shows the real build again at once.
--   Points are not charged for the given Cloak. Diagnostic: player attribute SkillTestCloak ("on" / "off").
-- v1.5 (bug, Kepu 2026-10-29: "i unlocked thrusters and its not assigning to the button"): 1.4 forced SkillSlot1 =
--   "cloak" over the real loadout, so (a) a bought part auto-slotted into the real slot 1 was hidden under the Cloak, and
--   (b) the SKILLS loadout tiles cycled to the given Cloak first and the server refused it ("notOwned": the real record
--   has no Cloak), so a tile never reached Thrusters. Now, while the layer is on, the dino's loadout works with the
--   effective steps (real steps + cloak 4, stepsFor): sanitizeLoadout in publish, autoSlot on a buy and setSlot on a
--   slot request treat the Cloak as owned, and the Cloak is placed once (autoSlot: the first empty slot, R on an empty
--   loadout) when the layer turns on for that dino (d.testPlaced[key]; cleared when the layer is off for it and on
--   respec). Nothing is hidden: SkillSlot1..4 are the loadout itself. Points, steps and buys stay real; a "cloak" left
--   in a saved loadout is dropped on load (not owned) and when the layer is off.
-- v1.6 (Kepu 2026-10-29, after raptor parts batch 1 shipped and Blade Claws had to be bought: "all things that are added
--   need to be maxed unlocked for testing"): the same switch (SkillTestCloakEnabled) now gives EVERY live mecha part of
--   the active dino at star (SkillTree.LIVE_MECH paths the dino owns: today the raptor's Cloak Field, Thrusters, Blade
--   Claws, Adrenaline Injector, Energy Shield; later batches join automatically), not only the Cloak, and for any dino
--   (1.5: raptor only). stepsFor = real steps with each of those set to 4. Each button part among them is placed once
--   into the first empty slot (d.testPlaced[key] is now a set of part ids; an old boolean counts as {cloak}); passive
--   parts (Blade Claws) need no slot. Points, steps, buys and the save stay real, as before. New diagnostic: player
--   attribute SkillTestParts (the given ids, comma-separated; "" when off).
-- v1.7 (bug, Kepu 2026-10-30: "let me edit the stats on the test run because it isn't letting me upgrade the stat tree on
--   the test raptor"): with the test layer on, the given parts sit at star in the published SkillPath_ values, and the
--   Lab (SkillTree.canBuy over those values with the real SkillPoints) counted them as spent (5 parts x 10 points) and as
--   mastered lines (5 >= MASTERY_MAX 3): every stat buy read "NEED .. PTS" / "MASTERY FULL", although the server's own
--   check used the real steps. While the layer is on (and script attribute SkillTestFreeGivenEnabled ~= false), the
--   given parts are now left out of every points and mastery count, on the server and in the Lab (Lab 1.4): buys are
--   judged on buyBase = the real steps with each given part set to 0, SkillSpent / SkillLeft are published from
--   buyBase, and a given part itself is refused as "maxed". The buy still lands in the real steps and is saved. Note: a
--   given part that was also bought for real costs nothing while the layer is on; when the layer is switched off, a build
--   that is then over its points is reset by the load check, as before.
-- v1.8 (bug MDA-157, Kepu 2026-10-31: "sometimes I set my load out in the menu then load in with something totally
--   different"; "It should just auto save whatever is the last Dino and last loadout equipped in the main menu"): with the
--   test layer on, the slots hold parts the layer gives (not bought), and the saved loadout was sanitized on load with the
--   real steps (cleanRecord), so those slots came back empty and publish refilled them with the given parts in
--   PATH_ORDER. Now cleanRecord also keeps the saved loadout as it was (record field rawLoadout, never saved); the first
--   publish of that dino in the session, while the layer is on for it, sanitizes that saved loadout with the effective
--   steps (real + given at star) instead, and counts every given part as already placed, so nothing is refilled: the
--   slots come back exactly as last equipped, empty slots included. No saved record for the dino -> the 1.7 first
--   placement. Layer off -> the 1.7 sanitize with the real steps (a part not bought is dropped). The loadout is already
--   saved on every slot change (dirty -> at most SAVE_GAP s, and on leave / close); the last dino is saved by
--   SpeciesServer 1.3 (lastSpecies). Switch: script attribute SkillLoadoutKeepTestEnabled (default true, read at each
--   publish; false = 1.7). A save writes, for a dino not played yet this session, its saved loadout as it was (1.7 wrote
--   the copy sanitized with the real steps, so it lost the given parts too); rawLoadout itself is never written.
--   Diagnostic: player attribute SkillLoadoutRestored ("saved" when a saved loadout was put
--   back this way, else "").
--   Save race (found in the same Studio check): save() snapshots the data, waits on SetAsync, then cleared d.dirty; a
--   change made while the write was in flight (e.g. slots 3 and 4 set right after slots 1 and 2) was marked dirty and
--   then un-marked, so it was never written (Studio: live slots strobe / breaker / empty / smoke, store strobe / breaker
--   / glider / smoke). Now d.dirty is cleared when the snapshot is taken and set again if the write fails, so a change
--   made during the write is saved by the next periodic save (or on leave). Switch: script attribute
--   SkillSaveRaceFixEnabled (default true, read at each save; false = 1.7).
-- v1.9 (practice match, MDA-405, plan docs/plans/PRACTICE_MATCH_v1.0.md Task 1, red-team 3; Kepu 2026-11-10 "10% (like CoD
--   Mobile)"): a killed bot's model attribute SkillXpMul (number, default 1) multiplies its kill XP (PracticeServer's bots carry
--   0.1). Switch: script attribute SkillBotXpMulEnabled (default true; false = 1.8, every bot gives full XP).
-- v1.10 (match end, MDA-462, plan docs/plans/MATCH_END_v1.0.md Task 2; Kepu 2026-11-11 19:43 "Build with all the recs"): server-only
--   BindableFunction SkillGrantXp (child of this script): Invoke(player, amount, reason) -> "ok", before, after (before / after =
--   {level, into, next} from SkillTree.levelOf on the active dino's XP) | "disabled" (SkillEnabled or SkillGrantEnabled false) |
--   "notLoaded" (no loaded data for the player) | "badArg" (not a Player, amount not a whole number > 0). Adds amount to the
--   active dino's XP (as a bot kill does), marks it for saving, publishes (level-up stamp as a kill), SkillLastXp =
--   (reason or "xp") .. " +" .. amount. Switch: script attribute SkillGrantEnabled (default true, read per call). Diagnostic:
--   script SkillGrants (count of "ok").
-- v1.11 (Kepu 2026-11-13 12:58 "have all Dino's stats maxed out for testing"; picks "Live, behind a switch", "Stats + all
--   parts maxed"): script attribute SkillTestMaxAllEnabled (default true, read at each publish; changes republish everyone).
--   While on, the test layer (v1.4-v1.7) is on for every dino even with SkillTestCloakEnabled false: every live mecha part at
--   star (testParts, placed once into empty slots as before) AND every stat row the dino sees (not soon, not a mecha part) at
--   its top step (4). Like the parts, the stat rows are never stored: d.steps, points, buys and the save stay the real record;
--   given rows are left out of points / mastery (buyBase) and a buy of one is refused "maxed". false = 1.10 exactly.
--   Diagnostic: player attribute SkillTestStats (count of stat rows given; 0 when off).
-- v1.12 (saved loadout, MDA-502, plan docs/plans/PREMATCH_AND_SAVED_LOADOUT_v1.0.md B1, mockup docs/mockups/save_loadout_v0.1.html
--   A; Kepu 2026-11-13 "allow players to save their Dino loadouts in the lab so when they select a Dino in the pregame it
--   automatically loads their saved load out", picks "A SAVE button only", "Yes, on arrival too"): each dino can have a saved
--   loadout (d.saved[key] = 4 part ids, "" = empty), apart from its last slots (which work as before).
--   * SkillRequest("saveLoadout"): the active dino's saved loadout = its current 4 slots; marked for saving; SkillLastResult
--     "saved". Saved with the record (field saved of value.dinos[key]); loaded with it (cleanSaved: 4 strings).
--   * Player attribute SkillSavedLoadout = the active dino's saved loadout "a,b,c,d" ("" when none), set in every publish.
--   * Pre-game: while ReplicatedStorage.Practice PgPhase == "lineup", the saved loadout is put in the slots (sanitized with the
--     effective steps: parts no longer owned are dropped) once per dino per lineup: when the active dino changes (a pick) and
--     for the dino you arrive with (the lineup starting, or loading in during it). Player SkillLoadoutFrom = "saved" after it,
--     "" when the dino has no saved loadout. Changing slots afterwards does not change the saved loadout.
--   Switch: script attribute SkillSavedLoadoutEnabled (default true, read per request / apply; false = 1.11).
-- v1.13 (first-time flow, MDA-560, plan docs/plans/FIRST_TIME_FLOW_v1.0.md Task 2, ADR-013; Kepu 2026-11-22: the free dino gets
--   "all the mecha parts unlocked", "Fully maxed"): player attribute FreeDino (DinoOwnership 1.0) names the player's free dino.
--   While the active dino is that dino, its live mecha parts are given at star exactly like the test layer's parts (testParts:
--   stepsFor sets them to 4, buyBase leaves them out of points and mastery, a buy of one is refused "maxed", the v1.8 saved
--   loadout restore keeps them). Unlike the test layer they are NOT auto-placed into empty slots (the tutorial's "Equip 4
--   parts" step fills the slots); placement still happens while the test layer itself is on. Never stored: d.steps and the save
--   stay the real record. A FreeDino change republishes the player. Switch: script attribute SkillFreePartsEnabled (default true,
--   read per publish / buy; false = 1.12).
-- v1.14 (account reset, Kepu 2026-11-22 11:22 "reset everyone's account anyways to zero so we can see how hard it is to grind players"; picks "Fresh saves, keep old", "Levels, XP, stats, parts, loadouts"): the save store name is the
--   script attribute SkillSaveStoreName (default "MDA_Skills_v3", read at start). Every player starts at level 1 with nothing bought;
--   "MDA_Skills_v2" is no longer read or written and stays as it is (set the attribute back to "MDA_Skills_v2" to bring those saves back).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local DataStoreService = game:GetService("DataStoreService")

local VERSION = "1.9"
VERSION = "1.10" -- v1.10 match XP grant
VERSION = "1.11" -- v1.11 max-all test switch
VERSION = "1.12" -- v1.12 saved loadout + pre-game apply
VERSION = "1.13" -- v1.13 free dino parts
VERSION = "1.14" -- v1.14 fresh save store (account reset)
VERSION = "1.15" -- v1.15 universal skill points + bonus points
VERSION = "1.16" -- v1.16 maxed dinos (Favorite Egg)
-- v1.16 (Favorite Egg, plan docs/plans/FAVORITE_EGG_v1.0.md Task 2, MDA-608): the v1.13 free-dino rule also holds for every dino in
--   the player attribute MaxedDinos (comma list, DinoOwnership 1.2: a dino won from the Favorite Egg). A MaxedDinos change
--   republishes the player. Switch: script attribute SkillMaxedDinosEnabled (true, read per publish / buy; false = 1.15).
VERSION = "1.17" -- v1.17 dino unlock spend
-- v1.17 (Kepu 2026-11-26 08:06 "make dinos 40 skill points to unlock base", pick "Spend 40 (as said)"): server-only BindableFunction
--   SkillSpendUnlock (child of this script): Invoke(player, amount, reason) -> "ok", before, after (the account pool) | "notEnough",
--   have | "notLoaded" | "disabled" (universal off / SkillSpendUnlockEnabled false) | "badArg". The amount is kept in d.unlock (saved
--   as value.unlock, a whole number >= 0) and taken off the account pool: SkillPoints = level points + bonus - unlock. Every dino
--   build that is now over the pool goes back to nothing (as a respec: steps 0, empty loadout), so nobody keeps parts the pool no
--   longer pays for. Load: each record is checked against the pool after unlock. Player SkillUnlockSpent (total), SkillLastPoints
--   ("unlock -40"). Switch: script attribute SkillSpendUnlockEnabled (true, read per call). Diagnostic: SkillUnlockSpends.
--   Launch reset (Kepu 2026-11-26 08:10 "everybody has clean sheets nothing on their accounts ready for launch"): SkillSaveStoreName default "MDA_Skills_v4" ("MDA_Skills_v3" kept).
VERSION = "1.18" -- v1.18 every stat row maxed for everyone
-- v1.18 (Kepu 2026-11-26 11:14 "lets remove stats entirely. everyone should be automatically maxed out."; standing pick "whatever the recommended option is ... just choose that" ->
--   stats only, mecha parts still bought with points): script attribute SkillAllStatsMaxEnabled (true, read at each publish; a change
--   republishes everyone). While on, the v1.11 stat layer is on for every player and every dino: every stat row the active dino sees
--   (Lab STATS tab: not soon, not a live mecha part) is at its top step (4), never stored, left out of points (buyBase), and a buy of
--   one is refused "maxed". Points a player already spent on stat rows are free again: every points check (publish, load
--   cleanRecord, SkillSpendUnlock) counts each record without its stat rows (noStats). Mecha parts, the free dino, MaxedDinos and
--   SkillTestMaxAllEnabled are unchanged. Player attribute SkillAllStatsMax (true / false) tells the Lab (2.3) to hide the STATS tab.
-- v1.15 (universal points, plan docs/plans/UNIVERSAL_POINTS_v1.0.md Task 2; Kepu 2026-11-26 "Make all points universal", "the daily
--   quest rewards will be skill points"; picks "Full pool on every dino", "Highest dino's XP", "Yes, past 40"; red-team "Accept",
--   "Yes, that's the point", "No cap"). While script attribute SkillUniversalEnabled ~= false (read at each player's load, d.universal):
--   * One account XP (so one level) for every dino: it lives in d.xp and is NOT swapped when the dino changes (switchTo keeps it;
--     stash still writes it into the record). Kill XP and SkillGrantXp raise it, so every dino levels together.
--   * Load: account XP = SkillPool.accountXp(value) = max(value.uxp, every dino record's xp) (the migration from 1.14 saves;
--     nobody goes down); bonus = SkillPool.cleanBonus(value.bonus, SkillBonusMax). A record's build-over-points reset uses the
--     account points instead of the record's own level points.
--   * Points: SkillPoints = pointsOf(account level) + bonus (SkillPool.earned); each dino spends from the full pool on its own
--     build (builds, loadouts, saved loadouts stay per dino); buys use the same number. Bonus can go past 40 (no cap unless
--     script attribute SkillBonusMax is set). Mastery 3 unchanged.
--   * Save: top-level uxp (account XP) and bonus are added to the value; v stays 2, so 1.14 still reads it. With the switch off,
--     the loaded uxp / bonus are written back untouched (nothing is lost).
--   * Server-only BindableFunction SkillGrantPoints (child of this script): Invoke(player, amount, reason) -> "ok", before, after
--     (bonus totals) | "disabled" (SkillEnabled / SkillGrantPointsEnabled false or universal off for the player) | "notLoaded" |
--     "badArg" (not a Player, amount not a whole number 1..100). For the Quest Stand (roadmap piece 4).
--   Player attributes: SkillBonusPoints, SkillUniversal ("on" / "off"), SkillAccountFrom ("new" / "max of N dinos" / "uxp of N
--   dinos"), SkillLastPoints ("quest +3"). Script attributes: SkillUniversalEnabled (true), SkillGrantPointsEnabled (true),
--   SkillBonusMax (unset = no cap), SkillPointGrants (count). Switch off = 1.14 (per-dino XP; bonus ignored but kept in the save).
local SAVE_STORE = "MDA_Skills_v1"
local SAVE_STORE_V2 = "MDA_Skills_v2" -- v1.2: per-dino records (reset all)
if script:GetAttribute("SkillSaveStoreName") == nil then script:SetAttribute("SkillSaveStoreName", "MDA_Skills_v4") end -- v1.17 launch reset (1.14: "MDA_Skills_v3")
SAVE_STORE_V2 = script:GetAttribute("SkillSaveStoreName") -- v1.14: account reset (v2 kept as it is)
local SAVE_GAP = 10
local RETRY_GAP = 30
local REQUEST_GAP = 0.2
local DEFAULTS = {SkillEnabled = true, SkillKillXpFraction = 0.5, SkillSaveEnabled = true}
DEFAULTS.SkillLoadoutEnabled = true -- v1.1
DEFAULTS.SkillPerDinoEnabled = true -- v1.2
DEFAULTS.SkillTestCloakEnabled = false -- v1.4: test layer (raptor Cloak at star in slot 1, not saved)
DEFAULTS.SkillBotXpMulEnabled = true -- v1.9: a bot's SkillXpMul scales its kill XP

local treeModule = ServerStorage:WaitForChild("DinoArcade"):WaitForChild("SkillTree")
local ST = require(treeModule)
local SkillPool = require(ServerStorage:WaitForChild("DinoArcade"):WaitForChild("SkillPool")) -- v1.15
if script:GetAttribute("SkillUniversalEnabled") == nil then script:SetAttribute("SkillUniversalEnabled", true) end -- v1.15
if script:GetAttribute("SkillGrantPointsEnabled") == nil then script:SetAttribute("SkillGrantPointsEnabled", true) end -- v1.15
local function bonusMax() local m = script:GetAttribute("SkillBonusMax") return type(m) == "number" and m or nil end -- v1.15
local function earnedOf(d) -- v1.15: account level points + bonus when universal, else 1.14
	if d.universal then return math.max(0, SkillPool.earned(d.xp, d.bonus, ST, bonusMax()) - (d.unlock or 0)) end -- v1.17: - unlock
	return ST.pointsOf((ST.levelOf(d.xp)))
end

script:SetAttribute("SkillServerVersion", VERSION)
for k, v in pairs(DEFAULTS) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, v) end
end
script:SetAttribute("SkillKillsCounted", 0)

-- client copy of the tree
local shared = ReplicatedStorage:FindFirstChild("SkillShared")
if not shared then
	shared = Instance.new("Folder")
	shared.Name = "SkillShared"
	shared.Parent = ReplicatedStorage
end
local oldCopy = shared:FindFirstChild("SkillTree")
if oldCopy then oldCopy:Destroy() end
treeModule:Clone().Parent = shared

local remote = ReplicatedStorage:FindFirstChild("SkillRequest")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "SkillRequest"
	remote.Parent = ReplicatedStorage
end

local store
do
	local ok, s = pcall(function() return DataStoreService:GetDataStore(SAVE_STORE_V2) end) -- v1.2 (was SAVE_STORE)
	store = ok and s or nil
end

local data = {} -- [player] = {xp, steps, loaded, dirty, lastSave, lastRequest; v1.2: dinos, active}

-- v1.6: the live mecha parts the active dino owns (PATH_ORDER order)
local function maxAll() return script:GetAttribute("SkillTestMaxAllEnabled") ~= false end -- v1.11
if script:GetAttribute("SkillFreePartsEnabled") == nil then script:SetAttribute("SkillFreePartsEnabled", true) end -- v1.13
if script:GetAttribute("SkillMaxedDinosEnabled") == nil then script:SetAttribute("SkillMaxedDinosEnabled", true) end -- v1.16
local function freeOn(d) -- v1.13: the active dino is the player's free dino
	if script:GetAttribute("SkillFreePartsEnabled") ~= false and script:GetAttribute("SkillMaxedDinosEnabled") ~= false -- v1.16
		and type(d.maxedDinos) == "string" and d.active and table.find(string.split(d.maxedDinos, ","), d.active) then return true end
	return script:GetAttribute("SkillFreePartsEnabled") ~= false and type(d.freeDino) == "string" and d.freeDino ~= ""
		and d.active == d.freeDino
end
local function layerOn() return script:GetAttribute("SkillTestCloakEnabled") == true or maxAll() end -- v1.13
local function testParts(d)
	local out = {}
	if (script:GetAttribute("SkillTestCloakEnabled") ~= true and not maxAll() and not freeOn(d)) or not d.active then return out end -- v1.11: or max-all; v1.13: or the free dino
	for _, id in ipairs(ST.PATH_ORDER) do
		local p = ST.PATHS[id]
		if ST.LIVE_MECH[id] and p and not p.soon and ST.seesPath(p, d.active) then table.insert(out, id) end
	end
	return out
end
local function testCloak(d) -- v1.4; v1.6: true when the layer gives any part to this dino
	return #testParts(d) > 0
end
-- v1.11: every stat row the active dino sees (not soon, not a live mecha part) while max-all is on
local function testStats(d)
	local out = {}
	if not (maxAll() or script:GetAttribute("SkillAllStatsMaxEnabled") ~= false) or not d.active then return out end -- v1.18: or every stat maxed
	for _, id in ipairs(ST.PATH_ORDER) do
		local p = ST.PATHS[id]
		if p and not p.soon and not ST.LIVE_MECH[id] and ST.seesPath(p, d.active) then table.insert(out, id) end
	end
	return out
end
if script:GetAttribute("SkillAllStatsMaxEnabled") == nil then script:SetAttribute("SkillAllStatsMaxEnabled", true) end -- v1.18
local function noStats(steps, key) -- v1.18: a record's steps without its stat rows while every stat is maxed (points checks)
	if script:GetAttribute("SkillAllStatsMaxEnabled") == false or type(steps) ~= "table" then return steps end
	local s = table.clone(steps)
	for _, id in ipairs(testStats({active = key})) do s[id] = nil end
	return s
end
local function stepsFor(d) -- v1.5: real steps, plus the test parts at star while the layer is on (v1.6: all live parts)
	local stats = testStats(d) -- v1.11
	if #stats > 0 then
		local s = table.clone(d.steps)
		for _, id in ipairs(testParts(d)) do s[id] = 4 end
		for _, id in ipairs(stats) do s[id] = 4 end
		return s
	end
	local parts = testParts(d)
	if #parts == 0 then return d.steps end
	local s = table.clone(d.steps)
	for _, id in ipairs(parts) do s[id] = 4 end
	return s
end

-- v1.7: the steps buys and points are judged on (the given test parts left out)
if script:GetAttribute("SkillTestFreeGivenEnabled") == nil then script:SetAttribute("SkillTestFreeGivenEnabled", true) end
local function buyBase(d)
	local stats = testStats(d) -- v1.11: given stat rows count as given too
	if #stats > 0 and script:GetAttribute("SkillTestFreeGivenEnabled") ~= false then
		local s = table.clone(d.steps)
		local given = {}
		for _, id in ipairs(testParts(d)) do s[id] = 0; given[id] = true end
		for _, id in ipairs(stats) do s[id] = 0; given[id] = true end
		return s, given
	end
	local parts = testParts(d)
	if #parts == 0 or script:GetAttribute("SkillTestFreeGivenEnabled") == false then return d.steps, {} end
	local s = table.clone(d.steps)
	local given = {}
	for _, id in ipairs(parts) do s[id] = 0; given[id] = true end
	return s, given
end

local function publish(player, d, levelUp)
	d.freeDino = player:GetAttribute("FreeDino") -- v1.13
	d.maxedDinos = player:GetAttribute("MaxedDinos") -- v1.16
	local test = testCloak(d) -- v1.4
	player:SetAttribute("SkillTestCloak", test and "on" or "off")
	local given = testParts(d) -- v1.6
	player:SetAttribute("SkillTestParts", table.concat(given, ","))
	player:SetAttribute("SkillTestStats", #testStats(d)) -- v1.11
	player:SetAttribute("SkillAllStatsMax", script:GetAttribute("SkillAllStatsMaxEnabled") ~= false) -- v1.18
	local level, into, nxt = ST.levelOf(d.xp)
	local earned = earnedOf(d) -- v1.15 (1.14: ST.pointsOf(level))
	local spent = ST.spent((buyBase(d)), d.active) -- v1.3: + dino; v1.7: given test parts left out
	if levelUp and (player:GetAttribute("SkillLevel") or level) < level then
		player:SetAttribute("SkillLevelUpAt", workspace:GetServerTimeNow())
	end
	player:SetAttribute("SkillLevel", level)
	player:SetAttribute("SkillXP", d.xp)
	player:SetAttribute("SkillXPInto", into)
	player:SetAttribute("SkillXPNext", nxt)
	player:SetAttribute("SkillPoints", earned)
	player:SetAttribute("SkillSpent", spent)
	player:SetAttribute("SkillLeft", earned - spent)
	player:SetAttribute("SkillBonusPoints", d.universal and SkillPool.cleanBonus(d.bonus, bonusMax()) or 0) -- v1.15
	player:SetAttribute("SkillUniversal", d.universal and "on" or "off") -- v1.15
	local eff = stepsFor(d) -- v1.5 (1.4: cloak 4 here only)
	for _, id in ipairs(ST.PATH_ORDER) do
		player:SetAttribute("SkillPath_" .. id, eff[id] or 0)
	end
	d.testPlaced = d.testPlaced or {}
	local restored = false -- v1.8: put the saved loadout back with the effective steps (MDA-157)
	if d.rawLoadout ~= nil then
		if test and d.active and script:GetAttribute("SkillLoadoutKeepTestEnabled") ~= false then
			d.loadout = d.rawLoadout
			local placed = {}
			for _, id in ipairs(given) do placed[id] = true end
			d.testPlaced[d.active] = placed
			restored = true
		end
		d.rawLoadout = nil
	end
	player:SetAttribute("SkillLoadoutRestored", restored and "saved" or "")
	d.loadout = ST.sanitizeLoadout(d.loadout, eff, d.active) -- v1.1; v1.3: + dino; v1.5: effective steps
	if test then -- v1.5: the given Cloak takes the first empty slot once (1.4 forced slot 1 and hid the real part)
		if d.active then -- v1.6: every given button part, each once
			local placed = d.testPlaced[d.active]
			if type(placed) ~= "table" then placed = placed and {cloak = true} or {} end
			for _, id in ipairs(given) do
				if not placed[id] then
					placed[id] = true
					if layerOn() then d.loadout = ST.autoSlot(d.loadout, eff, id, d.active) end -- passive parts are left out by autoSlot; v1.13: not for free parts alone
				end
			end
			d.testPlaced[d.active] = placed
		end
	elseif d.active then
		d.testPlaced[d.active] = nil
	end
	for n = 1, ST.SLOTS do player:SetAttribute("SkillSlot" .. n, d.loadout[n] or "") end
	local sv = d.saved and d.active and d.saved[d.active] -- v1.12
	player:SetAttribute("SkillSavedLoadout", sv and table.concat(sv, ",") or "")
end

-- v1.2: per-dino records -------------------------------------------------------------------------------------------
local function dinoKey(player)
	if script:GetAttribute("SkillPerDinoEnabled") == false then return "All" end
	local c = player.Character
	local s = c and c:GetAttribute("Species")
	if type(s) == "string" and s ~= "" then return s end
	s = player:GetAttribute("DinoSpecies")
	if type(s) == "string" and s ~= "" then return s end
	return "TRex"
end
local function emptyLoadout() -- v1.3: SLOTS empties (4)
	local l = {}
	for n = 1, ST.SLOTS do l[n] = false end
	return l
end
local function stash(d) -- the active fields back into their record
	if d.active then d.dinos[d.active] = {xp = d.xp, steps = d.steps, loadout = d.loadout} end
end
local function switchTo(player, d, key)
	if d.active == key then return end
	if d.universal and d.active then d.uxp = d.xp end -- v1.15: the account XP so far
	stash(d)
	local r = d.dinos[key] or {xp = 0, steps = ST.sanitize({}, key), loadout = emptyLoadout()} -- v1.3
	d.xp, d.steps, d.loadout = r.xp, r.steps, r.loadout
	if d.universal then d.xp = d.uxp or 0 end -- v1.15: one account XP, not the record's
	d.rawLoadout, r.rawLoadout = r.rawLoadout, nil -- v1.8: the saved loadout, used once by the next publish
	d.active = key
	player:SetAttribute("SkillDino", key)
	if d.loaded then publish(player, d, false) end
end
local function cleanRecord(raw, key, cap) -- v1.15: + cap (account points when universal) -- a saved record -> {xp, steps, loadout}, sanitized like 1.1; v1.3: for its dino
	local xp = math.max(0, math.floor(tonumber(type(raw) == "table" and raw.xp) or 0))
	local steps = ST.sanitize(type(raw) == "table" and raw.steps or {}, key)
	if not ST.masteryOk(steps, key) then -- v1.3: over Mastery 3 -> every line back to step II
		for id, n in pairs(steps) do if n > 2 then steps[id] = 2 end end
	end
	if ST.spent(noStats(steps, key), key) > (cap or ST.pointsOf((ST.levelOf(xp)))) then steps = ST.sanitize({}, key) end -- v1.18: noStats
	return {xp = xp, steps = steps, loadout = ST.sanitizeLoadout(type(raw) == "table" and raw.loadout or nil, steps, key),
		rawLoadout = type(raw) == "table" and type(raw.loadout) == "table" and table.clone(raw.loadout) or nil} -- v1.8
end

local function save(player, d)
	if script:GetAttribute("SkillSaveEnabled") == false or not store then return end
	local st = player:GetAttribute("SkillSaveState")
	if st == "noApi" or st == "loading" then return end
	d.lastSave = os.clock()
	stash(d) -- v1.2
	local value = {v = 2, dinos = d.dinos} -- v1.2 (1.1: {v = 1, xp, steps, loadout})
	if script:GetAttribute("SkillLoadoutKeepTestEnabled") ~= false then -- v1.8: a dino not played yet this session keeps
		local dinos = {} -- its saved loadout as it was (not the copy sanitized with the real steps)
		for key, r in pairs(d.dinos) do
			dinos[key] = {xp = r.xp, steps = r.steps, loadout = r.rawLoadout or r.loadout}
		end
		value = {v = 2, dinos = dinos}
	end
	if d.universal then value.uxp, value.bonus = d.xp, d.bonus -- v1.15
	else value.uxp, value.bonus = d.rawUxp, d.rawBonus end
	value.unlock = d.unlock or 0 -- v1.17
	if type(d.saved) == "table" then -- v1.12: each dino's saved loadout rides in its record
		for key, sv in pairs(d.saved) do
			if value.dinos[key] then value.dinos[key].saved = sv end
		end
	end
	local raceFix = script:GetAttribute("SkillSaveRaceFixEnabled") ~= false -- v1.8
	if raceFix then d.dirty = false end -- v1.8: cleared at the snapshot, so a change during the write stays dirty
	local ok, err = pcall(function() store:SetAsync("u" .. player.UserId, value) end)
	if ok then
		if not raceFix then d.dirty = false end -- v1.8: 1.7 cleared it here
		if player.Parent then player:SetAttribute("SkillSaveState", "saved") end
	else
		if raceFix then d.dirty = true end -- v1.8: the snapshot was not written
		if player.Parent then
			player:SetAttribute("SkillSaveState", tostring(err):find("not allowed") and "noApi" or "failed")
		end
	end
end

local applySaved -- v1.12 (below)
local function load(player)
	local d = {xp = 0, steps = ST.sanitize({}), loaded = false, dirty = false, lastSave = os.clock(), lastRequest = 0,
		loadout = emptyLoadout()} -- v1.1: + loadout; v1.3: SLOTS empties
	d.dinos, d.active = {}, nil -- v1.2
	d.saved = {} -- v1.12
	d.universal = script:GetAttribute("SkillUniversalEnabled") ~= false -- v1.15
	d.uxp, d.bonus = 0, 0
	d.unlock = 0 -- v1.17
	player:SetAttribute("SkillAccountFrom", "new")
	data[player] = d
	if script:GetAttribute("SkillSaveEnabled") == false or not store then
		player:SetAttribute("SkillSaveState", "off")
	else
		player:SetAttribute("SkillSaveState", "loading")
		local ok, value = pcall(function() return store:GetAsync("u" .. player.UserId) end)
		if not player.Parent then return end
		if not ok then
			player:SetAttribute("SkillSaveState", tostring(value):find("not allowed") and "noApi" or "failed")
		elseif type(value) == "table" and value.v == 2 and type(value.dinos) == "table" then -- v1.2: per-dino records
			d.rawUxp, d.rawBonus = value.uxp, value.bonus -- v1.15: written back as they are while universal is off
			d.unlock = math.max(0, math.floor(tonumber(value.unlock) or 0)) -- v1.17
			local cap -- v1.15: the account points every record is checked against
			if d.universal then
				d.uxp, d.bonus = SkillPool.accountXp(value), SkillPool.cleanBonus(value.bonus, bonusMax())
				cap = math.max(0, SkillPool.earned(d.uxp, d.bonus, ST, bonusMax()) - d.unlock) -- v1.17: - unlock
				local n = 0 for _ in pairs(value.dinos) do n += 1 end
				player:SetAttribute("SkillAccountFrom", (type(value.uxp) == "number" and "uxp" or "max") .. " of " .. n .. " dinos")
			end
			for key, raw in pairs(value.dinos) do
				if type(key) == "string" then d.dinos[key] = cleanRecord(raw, key, cap) end -- v1.3: + key
				if type(key) == "string" and type(raw) == "table" and type(raw.saved) == "table" then -- v1.12
					local sv = {}
					for n = 1, ST.SLOTS do sv[n] = type(raw.saved[n]) == "string" and raw.saved[n] or "" end
					d.saved[key] = sv
				end
			end
			player:SetAttribute("SkillSaveState", "loaded")
		else
			player:SetAttribute("SkillSaveState", "new")
		end
	end
	switchTo(player, d, dinoKey(player)) -- v1.2: the dino being played (d.loaded is still false: no publish yet)
	d.loaded = true
	publish(player, d, false)
	applySaved(player, d) -- v1.12: loading in during a lineup
end

-- v1.12: the saved loadout in the pre-game lineup (see the header)
local function lineupOn()
	local pr = ReplicatedStorage:FindFirstChild("Practice")
	return pr ~= nil and pr:GetAttribute("PgPhase") == "lineup"
end
applySaved = function(player, d)
	if script:GetAttribute("SkillSavedLoadoutEnabled") == false or not (d and d.loaded and d.active) or not lineupOn() then return end
	d.pgApplied = d.pgApplied or {}
	if d.pgApplied[d.active] then return end
	d.pgApplied[d.active] = true
	local sv = d.saved and d.saved[d.active]
	if not sv then
		player:SetAttribute("SkillLoadoutFrom", "")
		return
	end
	local raw = {}
	for n = 1, ST.SLOTS do raw[n] = (sv[n] ~= nil and sv[n] ~= "") and sv[n] or false end
	d.loadout = ST.sanitizeLoadout(raw, stepsFor(d), d.active)
	d.dirty = true
	publish(player, d, false)
	player:SetAttribute("SkillLoadoutFrom", "saved")
end
task.spawn(function()
	local pr = ReplicatedStorage:WaitForChild("Practice", 60)
	if not pr then return end
	pr:GetAttributeChangedSignal("PgPhase"):Connect(function()
		for player, d in pairs(data) do
			if lineupOn() then applySaved(player, d) else d.pgApplied = nil end
		end
	end)
end)

-- v1.2: follow the dino being played
local function hookCharacter(player, char)
	local function check()
		local d = data[player]
		if d and d.active then switchTo(player, d, dinoKey(player)) end
		if d and d.active then applySaved(player, d) end -- v1.12
	end
	check()
	char:GetAttributeChangedSignal("Species"):Connect(check)
end
local function hookPlayer(player)
	player.CharacterAdded:Connect(function(char) hookCharacter(player, char) end)
	if player.Character then hookCharacter(player, player.Character) end
end
Players.PlayerAdded:Connect(hookPlayer)
for _, p in ipairs(Players:GetPlayers()) do hookPlayer(p) end
script:GetAttributeChangedSignal("SkillTestCloakEnabled"):Connect(function() -- v1.4
	for player, d in pairs(data) do
		if d.loaded then publish(player, d, false) end
	end
end)
local function hookFree(player) -- v1.13: a FreeDino change republishes
	player:GetAttributeChangedSignal("FreeDino"):Connect(function()
		local d = data[player]
		if d and d.loaded then publish(player, d, false) end
	end)
	player:GetAttributeChangedSignal("MaxedDinos"):Connect(function() -- v1.16
		local d = data[player]
		if d and d.loaded then publish(player, d, false) end
	end)
end
Players.PlayerAdded:Connect(hookFree)
for _, p in ipairs(Players:GetPlayers()) do hookFree(p) end
script:GetAttributeChangedSignal("SkillAllStatsMaxEnabled"):Connect(function() -- v1.18
	for player, d in pairs(data) do
		if d.loaded then publish(player, d, false) end
	end
end)
script:GetAttributeChangedSignal("SkillTestMaxAllEnabled"):Connect(function() -- v1.11
	for player, d in pairs(data) do
		if d.loaded then publish(player, d, false) end
	end
end)
script:GetAttributeChangedSignal("SkillPerDinoEnabled"):Connect(function()
	for player, d in pairs(data) do
		if d.active then switchTo(player, d, dinoKey(player)) end
	end
end)

Players.PlayerAdded:Connect(load)
for _, p in ipairs(Players:GetPlayers()) do task.spawn(load, p) end
Players.PlayerRemoving:Connect(function(player)
	local d = data[player]
	if d and d.loaded and d.dirty then save(player, d) end
	data[player] = nil
end)
game:BindToClose(function()
	for player, d in pairs(data) do
		if d.loaded and d.dirty then save(player, d) end
	end
end)

-- periodic saves (changed data at most every SAVE_GAP s; failed ones retried every RETRY_GAP s)
task.spawn(function()
	while true do
		task.wait(1)
		for player, d in pairs(data) do
			if d.loaded and d.dirty then
				local gap = player:GetAttribute("SkillSaveState") == "failed" and RETRY_GAP or SAVE_GAP
				if os.clock() - d.lastSave >= gap then task.spawn(save, player, d) end
			end
		end
	end
end)

-- requests
remote.OnServerEvent:Connect(function(player, action, pathId, slotPath) -- v1.1: + slotPath ("slot": pathId = slot n)
	local d = data[player]
	if script:GetAttribute("SkillEnabled") == false then
		player:SetAttribute("SkillLastResult", "disabled")
		return
	end
	if not d or not d.loaded or os.clock() - d.lastRequest < REQUEST_GAP then
		player:SetAttribute("SkillLastResult", "busy")
		return
	end
	d.lastRequest = os.clock()
	if action == "buy" and type(pathId) == "string" then
		local earned = earnedOf(d) -- v1.15 (1.14: ST.pointsOf((ST.levelOf(d.xp))))
		local base, given = buyBase(d) -- v1.7
		local new, why
		if given[pathId] then
			why = "maxed"
		else
			new, why = ST.buy(base, pathId, earned, d.active) -- v1.3: + dino; v1.7: on buyBase
			if new then
				new = ST.sanitize(d.steps, d.active)
				new[pathId] += 1
			end
		end
		if new then
			d.steps = new
			if script:GetAttribute("SkillLoadoutEnabled") ~= false then d.loadout = ST.autoSlot(d.loadout, stepsFor(d), pathId, d.active) end -- v1.1; v1.3: + dino; v1.5: effective steps
			d.dirty = true
			publish(player, d, false)
		end
		player:SetAttribute("SkillLastResult", why)
	elseif action == "slot" then -- v1.1
		if script:GetAttribute("SkillLoadoutEnabled") == false then
			player:SetAttribute("SkillLastResult", "disabled")
		elseif type(pathId) ~= "number" or (type(slotPath) ~= "string" and slotPath ~= nil) then
			player:SetAttribute("SkillLastResult", "badArg")
		else
			local new, why = ST.setSlot(d.loadout, stepsFor(d), pathId, slotPath or "", d.active) -- v1.3: + dino; v1.5: effective steps
			if new then
				d.loadout = new
				d.dirty = true
				publish(player, d, false)
			end
			player:SetAttribute("SkillLastResult", why)
		end
	elseif action == "saveLoadout" then -- v1.12
		if script:GetAttribute("SkillSavedLoadoutEnabled") == false or not d.active then
			player:SetAttribute("SkillLastResult", "disabled")
		else
			local sv = {}
			for n = 1, ST.SLOTS do sv[n] = type(d.loadout[n]) == "string" and d.loadout[n] or "" end
			d.saved = d.saved or {}
			d.saved[d.active] = sv
			d.dirty = true
			publish(player, d, false)
			player:SetAttribute("SkillLastResult", "saved")
		end
	elseif action == "respec" then
		d.steps = ST.sanitize({}, d.active)
		d.loadout = emptyLoadout() -- v1.1; v1.3: SLOTS empties
		if d.testPlaced and d.active then d.testPlaced[d.active] = nil end -- v1.5: the test Cloak is placed again
		d.dirty = true
		publish(player, d, false)
		player:SetAttribute("SkillLastResult", "ok")
	else
		player:SetAttribute("SkillLastResult", "badArg")
	end
end)

-- XP from bot kills
local counted = setmetatable({}, {__mode = "k"}) -- [bot] = the KilledAt value already credited
local function credit(bot)
	local at = bot:GetAttribute("KilledAt")
	if typeof(at) ~= "number" or counted[bot] == at then return end
	counted[bot] = at
	if script:GetAttribute("SkillEnabled") == false then return end
	local player = Players:GetPlayerByUserId(bot:GetAttribute("KilledByUserId") or 0)
		or Players:FindFirstChild(tostring(bot:GetAttribute("KilledBy")))
	local d = player and data[player]
	if not d or not d.loaded then
		bot:SetAttribute("SkillXpCredited", "noPlayer")
		return
	end
	local maxHp = tonumber(bot:GetAttribute("DummyMaxHealth")) or 0
	local frac = script:GetAttribute("SkillKillXpFraction") or 0.5
	local mul = bot:GetAttribute("SkillXpMul") -- v1.9
	if script:GetAttribute("SkillBotXpMulEnabled") ~= false and type(mul) == "number" and mul >= 0 then frac *= mul end
	local gain = math.floor(maxHp * frac + 0.5)
	d.xp += gain
	d.dirty = true
	publish(player, d, true)
	player:SetAttribute("SkillLastXp", "kill +" .. gain)
	bot:SetAttribute("SkillXpCredited", player.Name)
	script:SetAttribute("SkillKillsCounted", (script:GetAttribute("SkillKillsCounted") or 0) + 1)
end

local watched = setmetatable({}, {__mode = "k"})
local function watch(m)
	if watched[m] or not m:IsA("Model") or m:GetAttribute("IsBot") ~= true then return end
	watched[m] = true
	m:GetAttributeChangedSignal("KilledAt"):Connect(function() credit(m) end)
end
workspace.DescendantAdded:Connect(function(d)
	if d:IsA("Model") then
		if d:GetAttribute("IsBot") == true then
			watch(d)
		else
			local conn
			conn = d:GetAttributeChangedSignal("IsBot"):Connect(function()
				conn:Disconnect()
				watch(d)
			end)
			task.delay(2, function() if conn.Connected then conn:Disconnect() end end)
		end
	end
end)
for _, d in ipairs(workspace:GetDescendants()) do watch(d) end

-- ---------- v1.10: match XP grant (see the header) ----------
if script:GetAttribute("SkillGrantEnabled") == nil then script:SetAttribute("SkillGrantEnabled", true) end
script:SetAttribute("SkillGrants", script:GetAttribute("SkillGrants") or 0)
local grantFn = script:FindFirstChild("SkillGrantXp")
if not grantFn then
	grantFn = Instance.new("BindableFunction")
	grantFn.Name = "SkillGrantXp"
	grantFn.Parent = script
end
grantFn.OnInvoke = function(player, amount, reason)
	if script:GetAttribute("SkillEnabled") == false or script:GetAttribute("SkillGrantEnabled") == false then return "disabled" end
	if typeof(player) ~= "Instance" or not player:IsA("Player") or type(amount) ~= "number" or amount ~= amount
		or amount <= 0 or amount ~= math.floor(amount) then
		return "badArg"
	end
	local d = data[player]
	if not d or not d.loaded then return "notLoaded" end
	local l1, i1, n1 = ST.levelOf(d.xp)
	d.xp += amount
	d.dirty = true
	publish(player, d, true)
	local l2, i2, n2 = ST.levelOf(d.xp)
	player:SetAttribute("SkillLastXp", tostring(reason or "xp") .. " +" .. amount)
	script:SetAttribute("SkillGrants", (script:GetAttribute("SkillGrants") or 0) + 1)
	return "ok", {level = l1, into = i1, next = n1}, {level = l2, into = i2, next = n2}
end

-- ---------- v1.15: bonus skill points grant (see the v1.15 note) ----------
script:SetAttribute("SkillPointGrants", script:GetAttribute("SkillPointGrants") or 0)
local pointsFn = script:FindFirstChild("SkillGrantPoints")
if not pointsFn then
	pointsFn = Instance.new("BindableFunction")
	pointsFn.Name = "SkillGrantPoints"
	pointsFn.Parent = script
end
pointsFn.OnInvoke = function(player, amount, reason)
	if script:GetAttribute("SkillEnabled") == false or script:GetAttribute("SkillGrantPointsEnabled") == false then return "disabled" end
	if typeof(player) ~= "Instance" or not player:IsA("Player") or not SkillPool.grantOk(amount) then return "badArg" end
	local d = data[player]
	if not d or not d.loaded then return "notLoaded" end
	if not d.universal then return "disabled" end
	local before = SkillPool.cleanBonus(d.bonus, bonusMax())
	d.bonus = SkillPool.cleanBonus(before + amount, bonusMax())
	d.dirty = true
	publish(player, d, false)
	player:SetAttribute("SkillLastPoints", tostring(reason or "points") .. " +" .. amount)
	script:SetAttribute("SkillPointGrants", (script:GetAttribute("SkillPointGrants") or 0) + 1)
	return "ok", before, d.bonus
end

-- ---------- v1.17: dino unlock spend (see the v1.17 note) ----------
local spendFn = script:FindFirstChild("SkillSpendUnlock") or Instance.new("BindableFunction")
spendFn.Name = "SkillSpendUnlock"
spendFn.Parent = script
spendFn.OnInvoke = function(player, amount, reason)
	if script:GetAttribute("SkillEnabled") == false or script:GetAttribute("SkillSpendUnlockEnabled") == false then return "disabled" end
	if typeof(player) ~= "Instance" or not player:IsA("Player") or not SkillPool.grantOk(amount) then return "badArg" end
	local d = data[player]
	if not d or not d.loaded then return "notLoaded" end
	if not d.universal then return "disabled" end
	local before = earnedOf(d)
	if before < amount then return "notEnough", before end
	d.unlock = (d.unlock or 0) + amount
	local cap = earnedOf(d)
	if d.active and ST.spent((buyBase(d)), d.active) > cap then -- the active build, as a respec (v1.18: given rows left out)
		d.steps = ST.sanitize({}, d.active)
		d.loadout = emptyLoadout()
		if d.testPlaced then d.testPlaced[d.active] = nil end
	end
	for key, r in pairs(d.dinos) do
		if key ~= d.active and type(r) == "table" and ST.spent(noStats(r.steps or {}, key), key) > cap then -- v1.18: noStats
			r.steps = ST.sanitize({}, key)
			r.loadout = emptyLoadout()
		end
	end
	d.dirty = true
	publish(player, d, false)
	player:SetAttribute("SkillUnlockSpent", d.unlock)
	player:SetAttribute("SkillLastPoints", tostring(reason or "unlock") .. " -" .. amount)
	script:SetAttribute("SkillUnlockSpends", (script:GetAttribute("SkillUnlockSpends") or 0) + 1)
	return "ok", before, cap
end
