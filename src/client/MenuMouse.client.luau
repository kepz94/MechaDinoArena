-- MenuMouse v1.0 (Mecha Dino Arena) — on PC the mouse cursor is free and visible whenever a menu-type screen is up (LocalScript,
--   StarterPlayerScripts). Kepu 2026-11-26 12:12 "ON PC THE MOUSE ISNT VISIBLE ON FIRST LOAD IN. HAVE THE MOUSE BE VISIBLE AT ALL TIMES
--   ON MENU AREAS FOR PC."
-- Cause: ShoulderCam (character script, RenderStep at Camera) sets MouseBehavior LockCenter and hides the cursor every frame while a
--   body exists, including under the first-load screens and the menu.
-- Every frame right after the camera (RenderStep "MenuMouse", Camera + 2, the Lab / FavEgg / Quest pattern), on a device with a
--   mouse (UserInputService.MouseEnabled): when a menu area is up, MouseBehavior = Default and MouseIconEnabled = true. Menu areas:
--   player InMenu true; player EggLoaderState is a loader screen ("loading" / "splash" / "travel" / "hatching" / "hatched" /
--   "fading"); an enabled ScreenGui named MainMenu, Tutorial or PregameScreen in PlayerGui; player IslandPickOpen,
--   RespawnPickOpen or RespawnHold (the match death wait) true. Not the RespawnScreen's 5 s grace after spawning (you fight then). Outside these the game's own camera rules are untouched.
-- Switches (script attributes): MenuMouseEnabled (true, read per frame). Diagnostics: MenuMouseVersion, MenuMouseActive (true while
--   it frees the mouse), MenuMouseWhy (the first reason found).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")

local VERSION = "1.0"
script:SetAttribute("MenuMouseVersion", VERSION)
if script:GetAttribute("MenuMouseEnabled") == nil then script:SetAttribute("MenuMouseEnabled", true) end
local player = Players.LocalPlayer
local LOADER = {loading = true, splash = true, travel = true, hatching = true, hatched = true, fading = true}
local GUIS = {"MainMenu", "Tutorial", "PregameScreen"}

local function why()
	if player:GetAttribute("InMenu") == true then return "menu" end
	if LOADER[player:GetAttribute("EggLoaderState")] then return "loader" end
	if player:GetAttribute("IslandPickOpen") == true then return "islandPick" end
	if player:GetAttribute("RespawnPickOpen") == true then return "respawnPick" end
	if player:GetAttribute("RespawnHold") == true then return "respawnWait" end
	local pg = player:FindFirstChildOfClass("PlayerGui")
	if pg then
		for _, n in ipairs(GUIS) do
			local g = pg:FindFirstChild(n)
			if g and g:IsA("ScreenGui") and g.Enabled then return n end
		end
	end
	return nil
end

local last
RunService:BindToRenderStep("MenuMouse", Enum.RenderPriority.Camera.Value + 2, function()
	local w = (script:GetAttribute("MenuMouseEnabled") ~= false and UIS.MouseEnabled) and why() or nil
	if w then
		UIS.MouseBehavior = Enum.MouseBehavior.Default
		UIS.MouseIconEnabled = true
	end
	if w ~= last then
		last = w
		script:SetAttribute("MenuMouseActive", w ~= nil)
		script:SetAttribute("MenuMouseWhy", w or "")
	end
end)
