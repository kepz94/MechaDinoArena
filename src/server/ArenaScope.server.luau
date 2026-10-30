-- ArenaScope v1.17 (Mecha Dino Arena) — check-only report of which systems are switched on / off in Mecha Dino Arena.
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
-- v1.6 (Cloak release, MDA-54, plan docs/plans/CLOAK_v1.0.md Task 6): CloakServer (ServerScriptService) and CloakFX
--   (StarterPlayer.StarterPlayerScripts, SPS) expected on.
-- v1.7 (raptor parts batch 1, MDA-65, plan docs/plans/RAPTOR_PARTS_B1_v1.0.md Task 8): BladeServer, AdrenalineServer and
--   EnergyShieldServer (ServerScriptService) expected on.
-- v1.8 (raptor parts batch 2, MDA-76, plan docs/plans/RAPTOR_PARTS_B2_v1.0.md Task 9): ScentServer, ScreechServer
--   (ServerScriptService) and ScentFX (StarterPlayerScripts) expected on.
-- v1.9 (raptor traps, MDA-80, plan docs/plans/RAPTOR_TRAPS_v1.0.md Task 7): MineServer (ServerScriptService) expected on.
-- v1.10 (Main Menu, MDA-91, plan docs/plans/MAIN_MENU_v1.0.md Task 8, ADR-005): PlaceGate, ModeServer, ArenaPvP
--   (ServerScriptService) and MainMenu (StarterPlayerScripts) expected on; module ServerStorage.DinoArcade.ModeRules
--   expected present (ArenaScope_ModeRules "on" / "missing"). BotServer's Enabled is set by PlaceGate 1.0 at start, so it
--   is expected to match PlaceGate's decision: this script waits up to 10 s for PlaceGate's PlaceGateState and expects
--   BotServer on for "sandboxBotsOn" / "off" (switch off = bots in both places), off for anything else ("arenaNoBots",
--   "noBotServer", or no PlaceGate). Diagnostic: ArenaScopeGateState.
-- v1.11 (Egg Loader, MDA-95, plan docs/plans/EGG_LOADER_v1.0.md Task 3): EggLoader (ReplicatedFirst) expected on.
-- v1.12 (Lab, MDA-99, plan docs/plans/LAB_v1.0.md Task 4): Lab (StarterPlayerScripts) and LabPreviewServer
--   (ServerScriptService) expected on; the SkillScreen entry is removed (SkillScreen deleted, Kepu 2026-10-29: "Delete it").
-- v1.13 (music, Kepu 2026-10-29): Music (ReplicatedFirst) and MusicServer (ServerScriptService) expected on.
-- v1.14 (enemy health bar, Kepu 2026-10-29): TargetHUD (StarterCharacterScripts) expected on.
-- v1.15 (no red flash on a dino switch, Kepu 2026-10-29): HurtFlashGuard (StarterPlayerScripts) expected on.
-- v1.16 (mine colours, Kepu 2026-10-30): MineColors (StarterPlayerScripts) expected on.
-- v1.17 (skins, MDA-109, plan docs/plans/SKINS_v1.0.md Task 5): SkinServer (ServerScriptService) expected on.
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")

local VERSION = "1.17"
local SSS, SCS = ServerScriptService, StarterPlayer:WaitForChild("StarterCharacterScripts")
local SPS = StarterPlayer:WaitForChild("StarterPlayerScripts") -- v1.6
local RF = game:GetService("ReplicatedFirst") -- v1.11
-- v1.10: what PlaceGate decided for BotServer
local gate = SSS:FindFirstChild("PlaceGate")
local gateState = gate and gate:GetAttribute("PlaceGateState")
local waitStart = os.clock()
while gate and gateState == nil and os.clock() - waitStart < 10 do
	task.wait(0.1)
	gateState = gate:GetAttribute("PlaceGateState")
end
local botsExpected = gateState == "sandboxBotsOn" or gateState == "off"
script:SetAttribute("ArenaScopeGateState", tostring(gateState))
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
	{SSS, "BotServer", botsExpected}, {SSS, "BiteServer", true}, {SCS, "BiteTest", true}, {SCS, "SprintTest", true}, -- v1.10: BotServer was true
	{SSS, "RamServer", true}, {SCS, "RamTest", true}, {SSS, "ShakeOffServer", true},
	{SSS, "PounceServer", true}, {SCS, "PounceTest", true}, {SSS, "JumpServer", true}, {SCS, "JumpTest", true},
	{SSS, "StatServer", true}, {SSS, "GrowthServer", true}, {SCS, "HitboxView", true},
	-- v1.1: the Arena HUD replaces the bottom-centre HUD and the top-left picker
	{SCS, "HealthBar", false}, {SCS, "SpeciesPicker", false}, {SCS, "StaminaBar", false},
	{SCS, "ArenaStatus", true}, {SCS, "ArenaTouch", true}, {SSS, "ArenaRules", true},
	-- v1.2: skill trees
	{SSS, "SkillServer", true}, {SSS, "SkillEffects", true}, -- v1.12: SkillScreen entry removed (deleted)
	-- v1.3: bigger raptors
	{SSS, "RaptorScale", true},
	-- v1.4: mecha parts
	{SSS, "MechaServer", true}, {SCS, "MechaButtons", true},
	-- v1.5: ability bar (PC)
	{SCS, "AbilityBar", true},
	-- v1.6: Cloak Field
	{SSS, "CloakServer", true}, {SPS, "CloakFX", true},
	-- v1.7: raptor parts batch 1
	{SSS, "BladeServer", true}, {SSS, "AdrenalineServer", true}, {SSS, "EnergyShieldServer", true},
	{SSS, "ScentServer", true}, {SSS, "ScreechServer", true}, {SPS, "ScentFX", true}, -- v1.8
	{SSS, "MineServer", true}, -- v1.9
	{SSS, "PlaceGate", true}, {SSS, "ModeServer", true}, {SSS, "ArenaPvP", true}, {SPS, "MainMenu", true}, -- v1.10
	{RF, "EggLoader", true}, -- v1.11
	{SPS, "Lab", true}, {SSS, "LabPreviewServer", true}, -- v1.12
	{RF, "Music", true}, {SSS, "MusicServer", true}, -- v1.13
	{SCS, "TargetHUD", true}, -- v1.14
	{SPS, "HurtFlashGuard", true}, -- v1.15
	{SPS, "MineColors", true}, -- v1.16
	{SSS, "SkinServer", true}, -- v1.17
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
local da = game:GetService("ServerStorage"):FindFirstChild("DinoArcade") -- v1.10
if da and da:FindFirstChild("ModeRules") and da.ModeRules:IsA("ModuleScript") then
	script:SetAttribute("ArenaScope_ModeRules", "on")
else
	script:SetAttribute("ArenaScope_ModeRules", "missing")
	bad += 1
end
script:SetAttribute("ArenaScopeMismatches", bad)
