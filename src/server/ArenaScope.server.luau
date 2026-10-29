-- ArenaScope v1.5 (Mecha Dino Arena) — check-only report of which systems are switched on / off in Mecha Dino Arena.
-- Plan docs/plans/ARENASCOPE_v1.0.md (Kepu 2026-10-28: "its not a survival game anymore"). Changes nothing: the scope is
--   set by each script's Enabled property (Studio place) and its .meta.json "Enabled" (repo / Rojo).
-- At start, for every script in SCOPE: script attribute ArenaScope_<Name> = "off" / "on" when it matches the expected
--   state, "mismatch" when it does not, "missing" when the script is not there. Script attributes ArenaScopeVersion,
--   ArenaScopeMismatches (mismatch + missing count). Bot hiding (BotServer 1.11 BotHidingEnabled) is reported as
--   ArenaScope_BotHiding ("off" when the attribute is false, else "mismatch").
-- v1.1 (Arena HUD, MDA-9, plan docs/plans/ARENAHUD_v1.0.md Task 4): HealthBar, SpeciesPicker and StaminaBar expected off
--   (replaced by ArenaStatus 1.0); ArenaStatus, ArenaTouch and ArenaRules expected on.
-- v1.2 (skill trees, MDA-15, plan docs/plans/SKILLTREES_v1.0.md Task 5): SkillServer, SkillEffects and SkillScreen
--   expected on (ClassCard stays off).
-- v1.3 (territories + bigger raptors, MDA-21, plan docs/plans/TERRITORIES_v1.0.md Task 5): RaptorScale expected on; bot
--   fights (BotServer 1.9 BotFightEnabled) reported as ArenaScope_BotFight ("off" when the attribute is false, else
--   "mismatch").
-- v1.4 (mecha parts framework + Thrusters, MDA-30, plan docs/plans/MECHA_THRUSTERS_v1.0.md Task 8): MechaServer and
--   MechaButtons expected on.
-- v1.5 (ability bar, MDA-43, plan docs/plans/ABILITY_BAR_v1.0.md Task 2): AbilityBar expected on.
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")

local VERSION = "1.5"
local SSS, SCS = ServerScriptService, StarterPlayer:WaitForChild("StarterCharacterScripts")
-- {container, name, expected Enabled}
local SCOPE = {
	-- off: survival layer, ambush / creep, roar, dummy, class card (until the skill tree screen)
	{SSS, "SurvivalServer", false}, {SCS, "SurvivalBars", false},
	{SSS, "PreyServer", false},
	{SCS, "CarcassFlies", false},
	{SSS, "GoalServer", false}, {SCS, "GoalTracker", false},
	{SSS, "CreepServer", false}, {SCS, "CreepTest", false}, {SCS, "CoverHint", false}, {SCS, "BushView", false},
	{SSS, "RoarServer", false}, {SCS, "RoarTest", false}, {SCS, "RoarFX", false},
	{SSS, "BiteDummy", false},
	{SCS, "ClassCard", false},
	-- on: combat, bots, stats, growth (kept for part 3), debug
	{SSS, "BotServer", true}, {SSS, "BiteServer", true}, {SCS, "BiteTest", true}, {SCS, "SprintTest", true},
	{SSS, "RamServer", true}, {SCS, "RamTest", true}, {SSS, "ShakeOffServer", true},
	{SSS, "PounceServer", true}, {SCS, "PounceTest", true}, {SSS, "JumpServer", true}, {SCS, "JumpTest", true},
	{SSS, "StatServer", true}, {SSS, "GrowthServer", true}, {SCS, "HitboxView", true},
	-- v1.1: the Arena HUD replaces the bottom-centre HUD and the top-left picker
	{SCS, "HealthBar", false}, {SCS, "SpeciesPicker", false}, {SCS, "StaminaBar", false},
	{SCS, "ArenaStatus", true}, {SCS, "ArenaTouch", true}, {SSS, "ArenaRules", true},
	-- v1.2: skill trees
	{SSS, "SkillServer", true}, {SSS, "SkillEffects", true}, {SCS, "SkillScreen", true},
	-- v1.3: bigger raptors
	{SSS, "RaptorScale", true},
	-- v1.4: mecha parts
	{SSS, "MechaServer", true}, {SCS, "MechaButtons", true},
	-- v1.5: ability bar (PC)
	{SCS, "AbilityBar", true},
}

script:SetAttribute("ArenaScopeVersion", VERSION)
local bad = 0
for _, e in ipairs(SCOPE) do
	local s = e[1]:FindFirstChild(e[2])
	local state
	if not s or not s:IsA("BaseScript") then
		state, bad = "missing", bad + 1
	elseif s.Enabled == e[3] then
		state = e[3] and "on" or "off"
	else
		state, bad = "mismatch", bad + 1
	end
	script:SetAttribute("ArenaScope_" .. e[2], state)
end
local bot = SSS:FindFirstChild("BotServer")
if bot and bot:GetAttribute("BotHidingEnabled") == false then
	script:SetAttribute("ArenaScope_BotHiding", "off")
else
	script:SetAttribute("ArenaScope_BotHiding", "mismatch")
	bad += 1
end
if bot and bot:GetAttribute("BotFightEnabled") == false then -- v1.3
	script:SetAttribute("ArenaScope_BotFight", "off")
else
	script:SetAttribute("ArenaScope_BotFight", "mismatch")
	bad += 1
end
script:SetAttribute("ArenaScopeMismatches", bad)
