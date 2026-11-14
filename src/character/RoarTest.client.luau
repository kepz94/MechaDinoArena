-- RoarTest v1.1 (Dino Arcade) — TEST ONLY. Press R (keyboard), Y (gamepad) or the on-screen Roar button
-- (touch) to roar. Sends the request to RoarServer; while this character is roaring it sets the
-- character attribute Roaring = true, which SprintTest uses to slow movement to MoveRoarSpeed.
-- Diagnostic: character attribute Roaring (true/false).
local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local char = script.Parent
local hum = char:WaitForChild("Humanoid")
local remote = ReplicatedStorage:WaitForChild("DinoRoarRequest")

local ACTION = "DinoRoarTest"
local DEFAULT_DURATION = 1.4

local function onRoar(_, inputState)
	if inputState == Enum.UserInputState.Begin then
		remote:FireServer()
	end
	return Enum.ContextActionResult.Sink
end
local function __prematchLocked() -- v1.1: PracticeServer 1.12 pre-match lock
	return (tonumber(char:GetAttribute("PrematchLockUntil")) or 0) > workspace:GetServerTimeNow()
end
char:SetAttribute("RoarTestVersion", "1.1") -- v1.1 pre-match lock
-- v1.1 (pre-match lock, MDA-529, plan docs/plans/PREMATCH_LOCK_PAN_v1.0.md rule 3; Kepu 2026-11-13 18:23 "all mecha abilities and
--   actions should be unplayable ... during the count down", pick "A · Locked everywhere"): while the character's
--   PrematchLockUntil (PracticeServer 1.12) is after the server time, onRoar() does nothing (no local start; the server drops it too).
do -- v1.1: no press before GO
	local rawPress = onRoar
	onRoar = function(...)
		if __prematchLocked() then return Enum.ContextActionResult.Sink end
		return rawPress(...)
	end
end

ContextActionService:BindActionAtPriority(ACTION, onRoar, true, Enum.ContextActionPriority.High.Value,
	Enum.KeyCode.R, Enum.KeyCode.ButtonY)
ContextActionService:SetTitle(ACTION, "Roar")

-- slow while roaring: driven by the server's start stamp so it matches what everyone sees
char:GetAttributeChangedSignal("RoarStartedAt"):Connect(function()
	local started = char:GetAttribute("RoarStartedAt")
	if not started then return end
	char:SetAttribute("Roaring", true)
	local duration = char:GetAttribute("RoarDuration") or DEFAULT_DURATION
	local remaining = started + duration - workspace:GetServerTimeNow()
	task.delay(math.max(0, remaining), function()
		-- only end if no newer roar started meanwhile
		if char:GetAttribute("RoarStartedAt") == started then
			char:SetAttribute("Roaring", false)
		end
	end)
end)
char:SetAttribute("Roaring", false)

local function cleanup()
	ContextActionService:UnbindAction(ACTION)
end
hum.Died:Connect(cleanup)
char.AncestryChanged:Connect(function(_, parent)
	if not parent then cleanup() end
end)
