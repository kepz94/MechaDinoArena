-- ArenaScope v1.0 (Mecha Dino Arena) — check-only report of which systems are switched on / off in Mecha Dino Arena.
-- Plan docs/plans/ARENASCOPE_v1.0.md (Kepu 2026-10-28: "its not a survival game anymore"). Changes nothing: the scope is
--   set by each script's Enabled property (Studio place) and its .meta.json "Enabled" (repo / Rojo).
-- At start, for every script in SCOPE: script attribute ArenaScope_<Name> = "off" / "on" when it matches the expected
--   state, "mismatch" when it does not, "missing" when the script is not there. Script attributes ArenaScopeVersion,
--   ArenaScopeMismatches (mismatch + missing count). Bot hiding (BotServer 1.11 BotHidingEnabled) is reported as
--   ArenaScope_BotHiding ("off" when the attribute is false, else "mismatch").
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")

local VERSION = "1.0"
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
script:SetAttribute("ArenaScopeMismatches", bad)
