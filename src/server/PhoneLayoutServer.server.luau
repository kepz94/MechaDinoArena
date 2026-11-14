-- PhoneLayoutServer v1.0 (Mecha Dino Arena) — phone HUD v2: the move stick appears where the thumb lands (Script,
-- ServerScriptService). MDA-536, plan docs/plans/PHONE_HUD_V2_v1.0.md rule 6, mockup docs/mockups/phone_hud_v0.1.html
-- "A · your version" (Kepu 2026-11-13: "I like option A but keep the current button style that we use with the tap/swipe
-- buttons"; A: "the move stick appears where you touch").
-- Every player's DevTouchMovementMode = DynamicThumbstick while script attribute PhoneDynamicStickEnabled ~= false (default true;
--   read on join and when it changes: false puts every player back on UserChoice). Only touch devices use it; PC is unchanged.
-- Diagnostics: PhoneLayoutServerVersion, PhoneDynamicStickPlayers (players set to the dynamic stick).
local Players = game:GetService("Players")

local VERSION = "1.0"
script:SetAttribute("PhoneLayoutServerVersion", VERSION)
if script:GetAttribute("PhoneDynamicStickEnabled") == nil then script:SetAttribute("PhoneDynamicStickEnabled", true) end

local function apply(pl)
	local on = script:GetAttribute("PhoneDynamicStickEnabled") ~= false
	pcall(function()
		pl.DevTouchMovementMode = on and Enum.DevTouchMovementMode.DynamicThumbstick or Enum.DevTouchMovementMode.UserChoice
	end)
end
local function count()
	local n = 0
	for _, pl in ipairs(Players:GetPlayers()) do
		if pl.DevTouchMovementMode == Enum.DevTouchMovementMode.DynamicThumbstick then n += 1 end
	end
	script:SetAttribute("PhoneDynamicStickPlayers", n)
end
Players.PlayerAdded:Connect(function(pl) apply(pl) count() end)
for _, pl in ipairs(Players:GetPlayers()) do apply(pl) end
count()
script:GetAttributeChangedSignal("PhoneDynamicStickEnabled"):Connect(function()
	for _, pl in ipairs(Players:GetPlayers()) do apply(pl) end
	count()
end)
