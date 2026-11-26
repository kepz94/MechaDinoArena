-- PlaceGate v1.0 (Mecha Dino Arena) — starts the bots only in the Sandbox place. MDA-86, plan docs/plans/MAIN_MENU_v1.0.md
-- Task 2, ADR-005 (Kepu 2026-10-29: "The arena will be the same island with no bots"; one file published to both places;
-- "No, leave BotServer"). BotServer's code is not changed: its Enabled property is false in the place file and in
-- BotServer.meta.json, and this script turns it on when the server is the Sandbox.
-- Mode = ServerStorage.DinoArcade.ModeRules 1.0 currentMode() (Arena place 75433819286625, or Workspace ModeTestArena = true
--   in Studio).
--   "sandbox" -> ServerScriptService.BotServer.Enabled = true (bots start as before). PlaceGateState "sandboxBotsOn".
--   "arena"   -> BotServer stays off; every Workspace Model with IsBot = true or BiteDummy = true, or with Bitable = true
--                that is not a player character and not an ArenaPvP test target (ArenaPvPTestTarget = true), is removed at
--                start and whenever one is added. PlaceGateState "arenaNoBots"; PlaceGateRemoved counts removals.
--   BotServer missing -> PlaceGateState "noBotServer" (nothing else changes).
-- Switch: script attribute PlaceGateEnabled (default true). false -> BotServer turned on in both places (pre-1.0
--   behaviour), PlaceGateState "off". Read once at start.
-- Diagnostics (script attributes): PlaceGateVersion, PlaceMode, PlaceGateState, PlaceGateRemoved.
-- v1.1 (practice match, MDA-405, plan docs/plans/PRACTICE_MATCH_v1.0.md Task 1; Kepu 2026-11-10 "default for sandbox for
--   now"): in the Sandbox, while ServerScriptService.PracticeServer exists, is Enabled and its PracticeEnabled attribute is not
--   false (nil = its default true), BotServer stays off (the practice bots replace the roaming ones): PlaceGateState
--   "sandboxPractice". Switch: script attribute PlaceGatePracticeEnabled (default true; false = 1.0). Read once at start.
-- v1.2 (island hub, MDA-454, plan docs/plans/ISLAND_HUB_v1.0.md Task 3, ADR-011; Kepu 2026-11-11 "No bots" on the hub island):
--   when ModeRules 1.2 serverKind() == "hub" the Sandbox does what the Arena does: BotServer stays off and bot models are
--   removed at start and when added. PlaceGateState "hubNoBots". Kinds "practice" / "arena": exactly 1.1. Switch: script
--   attribute PlaceGateHubEnabled (default true; false = 1.1). Read once at start. Diagnostic: PlaceKind.
-- v1.3 (first-time flow, MDA-561, plan docs/plans/FIRST_TIME_FLOW_v1.0.md Task 3, ADR-013; found in the Studio check 2026-11-22:
--   the hub removed the training bot 0.26 s after TutorialServer 1.0 spawned it): a model with TutBot = true, or inside
--   Workspace.TrainingGround (the training lanes), is never removed. Switch: script attribute PlaceGateTutorialEnabled
--   (default true, read per removal; false = 1.2).
-- v1.4 (filler bots, plan docs/plans/FILLER_BOTS_v1.0.md T4, MDA-577; found in the T2 Studio check 2026-11-25: the hub removed a
--   persona bot at once): a model with FillerPersona = true (PracticeBots 1.2 persona: FillerServer on the hub, Arena match
--   fill bots) is never removed. Switch: script attribute PlaceGateFillerEnabled (default true, read per removal; false = 1.3).
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local VERSION = "1.2"
VERSION = "1.3" -- v1.3 training bots stay
VERSION = "1.4" -- v1.4 filler bots stay
script:SetAttribute("PlaceGateVersion", VERSION)
if script:GetAttribute("PlaceGateEnabled") == nil then script:SetAttribute("PlaceGateEnabled", true) end
if script:GetAttribute("PlaceGatePracticeEnabled") == nil then script:SetAttribute("PlaceGatePracticeEnabled", true) end -- v1.1
if script:GetAttribute("PlaceGateHubEnabled") == nil then script:SetAttribute("PlaceGateHubEnabled", true) end -- v1.2
if script:GetAttribute("PlaceGateTutorialEnabled") == nil then script:SetAttribute("PlaceGateTutorialEnabled", true) end -- v1.3
if script:GetAttribute("PlaceGateFillerEnabled") == nil then script:SetAttribute("PlaceGateFillerEnabled", true) end -- v1.4

local ModeRules = require(ServerStorage:WaitForChild("DinoArcade"):WaitForChild("ModeRules"))
local mode = ModeRules.currentMode()
script:SetAttribute("PlaceMode", mode)
local hubKind = false -- v1.2
if script:GetAttribute("PlaceGateHubEnabled") ~= false and ModeRules.serverKind then
	local kind = ModeRules.serverKind()
	script:SetAttribute("PlaceKind", kind)
	hubKind = kind == "hub"
end
script:SetAttribute("PlaceGateRemoved", 0)

local bot = ServerScriptService:FindFirstChild("BotServer")

local function isBotModel(m)
	if not m:IsA("Model") then
		return false
	elseif Players:GetPlayerFromCharacter(m) ~= nil then
		return false
	elseif m:GetAttribute("ArenaPvPTestTarget") == true then
		return false
	elseif script:GetAttribute("PlaceGateFillerEnabled") ~= false and m:GetAttribute("FillerPersona") == true then -- v1.4
		return false
	elseif script:GetAttribute("PlaceGateTutorialEnabled") ~= false and (m:GetAttribute("TutBot") == true -- v1.3
		or (workspace:FindFirstChild("TrainingGround") ~= nil and m:IsDescendantOf(workspace.TrainingGround))) then
		return false
	elseif m:GetAttribute("IsBot") == true or m:GetAttribute("BiteDummy") == true or m:GetAttribute("Bitable") == true then
		return true
	else
		return false
	end
end

local function removeIfBot(m)
	if isBotModel(m) then
		m:Destroy()
		script:SetAttribute("PlaceGateRemoved", (script:GetAttribute("PlaceGateRemoved") or 0) + 1)
	end
end

if script:GetAttribute("PlaceGateEnabled") == false then
	if bot then bot.Enabled = true end
	script:SetAttribute("PlaceGateState", "off")
elseif not bot then
	script:SetAttribute("PlaceGateState", "noBotServer")
elseif mode == "arena" or hubKind then -- v1.2: the hub too
	bot.Enabled = false
	script:SetAttribute("PlaceGateState", hubKind and "hubNoBots" or "arenaNoBots")
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("Model") then removeIfBot(d) end
	end
	workspace.DescendantAdded:Connect(function(d)
		if d:IsA("Model") then
			task.defer(function() -- attributes are set right after parenting by some builders
				if d.Parent then removeIfBot(d) end
			end)
		end
	end)
else
	-- v1.1: the practice match replaces the roaming bots
	local practice = ServerScriptService:FindFirstChild("PracticeServer")
	if script:GetAttribute("PlaceGatePracticeEnabled") ~= false and practice and practice:IsA("BaseScript") and practice.Enabled
		and practice:GetAttribute("PracticeEnabled") ~= false then
		bot.Enabled = false
		script:SetAttribute("PlaceGateState", "sandboxPractice")
	else
		bot.Enabled = true
		script:SetAttribute("PlaceGateState", "sandboxBotsOn")
	end
end
