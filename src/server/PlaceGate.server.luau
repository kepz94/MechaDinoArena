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
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local VERSION = "1.0"
script:SetAttribute("PlaceGateVersion", VERSION)
if script:GetAttribute("PlaceGateEnabled") == nil then script:SetAttribute("PlaceGateEnabled", true) end

local ModeRules = require(ServerStorage:WaitForChild("DinoArcade"):WaitForChild("ModeRules"))
local mode = ModeRules.currentMode()
script:SetAttribute("PlaceMode", mode)
script:SetAttribute("PlaceGateRemoved", 0)

local bot = ServerScriptService:FindFirstChild("BotServer")

local function isBotModel(m)
	if not m:IsA("Model") then
		return false
	elseif Players:GetPlayerFromCharacter(m) ~= nil then
		return false
	elseif m:GetAttribute("ArenaPvPTestTarget") == true then
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
elseif mode == "arena" then
	bot.Enabled = false
	script:SetAttribute("PlaceGateState", "arenaNoBots")
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
	bot.Enabled = true
	script:SetAttribute("PlaceGateState", "sandboxBotsOn")
end
