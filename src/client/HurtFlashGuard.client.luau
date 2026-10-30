-- HurtFlashGuard v1.1 (Mecha Dino Arena) — no red flash when you switch dinos (LocalScript in StarterPlayerScripts, this
-- client only). Kepu 2026-10-29: "when I switch between dinos there's a red flash that happens we need to remove that".
-- Cause (seen in Play, 2026-10-29): Roblox's own health display (CoreGui "Health") flashes the screen edges red when your
--   health goes down. It keeps the last health it saw across bodies, so T-Rex (200) -> Raptor (60) looked like 140
--   damage. With the Health core GUI off there was no flash; giving the new raptor body 60 / 60 before it spawned did
--   not stop it (tried and taken back).
-- Rule: the Health core GUI is switched off from the moment a body change starts until GUARD_HOLD (1.0) s after the new
--   body's health is set, then switched back on. A body change starts on any of:
--     * the player attribute DinoSpecies changing (SpeciesServer sets it before it respawns you),
--     * Players.LocalPlayer.CharacterRemoving (death respawn, LoadCharacter),
--     * Players.LocalPlayer.CharacterAdded (also the raptor swap after a respawn).
--   "Health is set" = the new body's attribute DinoHealthVersion (DinoHealthServer 1.0) is present, or SETTLE_MAX (3) s
--   after it was added. Each new start restarts the hold. The core GUI is only switched back on if this script switched it
--   off (a value set by another script is left alone). Real damage while you play still flashes as before.
-- Switch: script attribute HurtFlashGuardEnabled (default true, read at start; false = Roblox's flash on every switch).
-- v1.1 (Kepu 2026-10-30: "theres two health bars for some reason. clean that up. theres one in the top corner"): the
--   top-corner bar is Roblox's own health display (CoreGui "Health"), shown once health is below max; the game's own bar
--   is ArenaStatus's (bottom left). With script attribute HurtFlashGuardHideRobloxHealth (default true, read at start)
--   Roblox's display is switched off at start and never switched back on (the guard's "back on" step keeps it off). That
--   also removes Roblox's red screen-edge flash on damage. false = 1.0 (shown, off only around a dino switch).
--   Diagnostic: LocalPlayer HurtFlashGuardRobloxHealth ("hidden" / "shown").
-- Diagnostics (LocalPlayer attributes, this client): HurtFlashGuardVersion, HurtFlashGuardState ("guarding" / "idle"),
--   HurtFlashGuardCount (body changes guarded).
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

local VERSION = "1.1"
local GUARD_HOLD = 1.0
local SETTLE_MAX = 3

local player = Players.LocalPlayer
player:SetAttribute("HurtFlashGuardVersion", VERSION)
if script:GetAttribute("HurtFlashGuardEnabled") == nil then script:SetAttribute("HurtFlashGuardEnabled", true) end
if script:GetAttribute("HurtFlashGuardEnabled") == false then
	player:SetAttribute("HurtFlashGuardState", "off")
	return
end

local token = 0
local weDisabled = false
local count = 0

if script:GetAttribute("HurtFlashGuardHideRobloxHealth") == nil then script:SetAttribute("HurtFlashGuardHideRobloxHealth", true) end -- v1.1
local HIDE_ROBLOX_HEALTH = script:GetAttribute("HurtFlashGuardHideRobloxHealth") ~= false
local function setHealthGui(on)
	if HIDE_ROBLOX_HEALTH then on = false end -- v1.1: Roblox's health display stays off (one health bar: ArenaStatus)
	pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, on) end)
end
if HIDE_ROBLOX_HEALTH then -- v1.1
	task.spawn(function()
		for _ = 1, 10 do -- the core GUI may not be ready at the very start
			local ok = pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false) end)
			if ok then break end
			task.wait(0.5)
		end
	end)
end
player:SetAttribute("HurtFlashGuardRobloxHealth", HIDE_ROBLOX_HEALTH and "hidden" or "shown")

local function suppress()
	token += 1
	if not weDisabled then
		local ok, enabled = pcall(function() return StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType.Health) end)
		if ok and enabled then
			setHealthGui(false)
			weDisabled = true
			count += 1
			player:SetAttribute("HurtFlashGuardCount", count)
		end
	end
	player:SetAttribute("HurtFlashGuardState", "guarding")
	return token
end

-- back on GUARD_HOLD s after the body's health is set, unless another change started meanwhile
local function releaseAfter(char, t)
	task.spawn(function()
		local start = os.clock()
		while char.Parent and char:GetAttribute("DinoHealthVersion") == nil and os.clock() - start < SETTLE_MAX do
			task.wait(0.1)
		end
		task.wait(GUARD_HOLD)
		if t ~= token then return end
		if weDisabled then
			setHealthGui(true)
			weDisabled = false
		end
		player:SetAttribute("HurtFlashGuardState", "idle")
	end)
end

player:GetAttributeChangedSignal("DinoSpecies"):Connect(function()
	local t = suppress()
	-- a switch to the same dino respawns nothing: let go after the settle time
	task.delay(SETTLE_MAX + GUARD_HOLD, function()
		if t == token and weDisabled then
			setHealthGui(true)
			weDisabled = false
			player:SetAttribute("HurtFlashGuardState", "idle")
		end
	end)
end)
player.CharacterRemoving:Connect(function() suppress() end)
player.CharacterAdded:Connect(function(char)
	releaseAfter(char, suppress())
end)
player:SetAttribute("HurtFlashGuardState", "idle")
