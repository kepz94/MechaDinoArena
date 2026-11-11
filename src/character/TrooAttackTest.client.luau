-- TrooAttackTest v1.1 (Mecha Dino Arena) — the Troodon's ATTACK input on the owner's client (LocalScript,
-- StarterCharacterScripts). MDA-334, plan docs/plans/TROODON_KIT_v1.0.md Task 5 (Kepu 2026-11-06 15:38: attack A Glow Pod
-- Toss); server TrooAttackServer 1.0. Pattern copied from DiloAttackTest 1.2 (not edited).
-- Only while the character's TrooAttackEnabled is true (the troodon). Inputs: CAS action "DinoTrooAttack" (the phone's big
--   ATTACK button over ArenaTouch's "TrooMain", and ButtonR2) and, with a mouse, CAS "DinoTrooAttackClick" on MouseButton1
--   (not while the menu, the Lab, the skill screen or a text box has it). A tap throws (no hold).
-- Press: when the local checks pass (alive, not stunned / dazed / pinned / in the menu), at least TrooMinGap (0.35) s since the
--   last local throw and a local pod charge left (TrooLocalLeft >= 1) -> DinoTrooAttack:FireServer(server time),
--   TrooLocalLeft - 1, TrooLocalState "throw", TrooLocalAt = that time (after the state; TrooPose starts the throw on it),
--   TrooInputResult "throw"; else TrooInputResult the reason ("cooldown" / "charges" / "stunned" ...). "throw" goes back to
--   "idle" after THROW_SHOW (1.15 s: the mockup's throw track, ready pose at 1.15 s).
-- Charges: TrooLocalLeft follows the server's TrooPodLeft whenever that changes (refills and the server's own count); the
--   press takes one at once so the pips drain on the press.
-- Server refusals (TrooAttackServerResult other than "ok", newer than the press) and a wind-up cancel (TrooThrowCancelAt):
--   TrooInputResult "denied:<reason>" / "cancelled", "throw" ends at once, TrooLocalLeft = the server's count.
-- Switch: character attribute TrooLeftClickEnabled (default true; false = no mouse binding). Diagnostics (character, this
--   client): TrooAttackTestVersion, TrooLocalState, TrooLocalAt, TrooLocalLeft, TrooInputResult, TrooLastInput ("click" /
--   "touch" / "key"), TrooClickBound.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local VERSION = "1.0"
VERSION = "1.1" -- v1.1 (MDA-375) no local throw while placing a Portal Rift (TrooRiftPlacing; TrooAttackServer 1.6 refuses it too).
--   Switch: script attribute TrooAttackTestRiftBlockEnabled (default true, read at each press; false = 1.0).
VERSION = "1.2" -- v1.2 double tap = pod to a teammate
-- v1.2 (MDA-439, plan docs/plans/DILO_TROO_TUNE_v1.0.md Task 5; Kepu 2026-11-11 "double tap to shoot towards a teammate (for
--   heals). Single tap for enemy"): a press within TrooDoubleTap (0.3) s of the last local throw (once per throw) sends
--   DinoTrooAttack:FireServer("ally", server time) instead of a throw (TrooAttackServer 1.8 turns the pod still in the hands
--   toward the closest teammate in front, else the enemy as before); no charge; character TrooLocalAllyAt = that time (TrooFX's
--   green ring), TrooInputResult "ally". Switch: script attribute TrooDoubleTapEnabled (default true, read at each press;
--   false = 1.1).
local ACTION = "DinoTrooAttack"
local ACTION_CLICK = "DinoTrooAttackClick"
local DEFAULTS = {TrooAttackEnabled = false, TrooMinGap = 0.35, TrooPodCharges = 2, TrooLeftClickEnabled = true}
local THROW_SHOW = 1.15

local char = script.Parent
local hum = char:WaitForChild("Humanoid", 10)
local player = Players:GetPlayerFromCharacter(char) or Players.LocalPlayer
pcall(function() ContextActionService:UnbindAction(ACTION) end) -- a leftover from the previous character (MDA-146 lesson)
pcall(function() ContextActionService:UnbindAction(ACTION_CLICK) end)
char:SetAttribute("TrooAttackTestVersion", VERSION)
if not hum then return end

local function get(k)
	local v = char:GetAttribute(k)
	if v == nil then v = DEFAULTS[k] end
	return v
end
local function show(k, v)
	if char:GetAttribute(k) ~= v then char:SetAttribute(k, v) end
end
local function now() return workspace:GetServerTimeNow() end
local remote
local function fire(...)
	remote = remote or ReplicatedStorage:FindFirstChild("DinoTrooAttack")
	if remote then remote:FireServer(...) end
end

local lastThrow, state = -math.huge, "idle"
local function maxCharges() return math.max(1, math.floor(tonumber(get("TrooPodCharges")) or 2)) end
local localLeft = math.floor(tonumber(char:GetAttribute("TrooPodLeft")) or maxCharges())
show("TrooLocalLeft", localLeft)
local function setState(s)
	if state == s then return end
	state = s
	char:SetAttribute("TrooLocalState", s)
	char:SetAttribute("TrooLocalAt", now()) -- after the state
end
local function syncLeft()
	local v = tonumber(char:GetAttribute("TrooPodLeft"))
	if v then
		localLeft = math.floor(v)
		show("TrooLocalLeft", localLeft)
	end
end
char:GetAttributeChangedSignal("TrooPodLeft"):Connect(syncLeft)

local function blocked()
	local t = now()
	if hum.Health <= 0 then return "dead" end
	if (tonumber(char:GetAttribute("StunnedUntil")) or 0) > t then return "stunned" end
	if (tonumber(char:GetAttribute("DazedUntil")) or 0) > t then return "dazed" end
	if char:GetAttribute("PinHeld") == true then return "pinned" end
	if player:GetAttribute("InMenu") == true then return "menu" end
	if char:GetAttribute("TrooRiftPlacing") == true and script:GetAttribute("TrooAttackTestRiftBlockEnabled") ~= false then return "placing" end -- v1.1 (MDA-375)
	return nil
end

if script:GetAttribute("TrooDoubleTapEnabled") == nil then script:SetAttribute("TrooDoubleTapEnabled", true) end -- v1.2
if script:GetAttribute("TrooDoubleTap") == nil then script:SetAttribute("TrooDoubleTap", 0.3) end
local allyFor = nil -- v1.2: the throw a double tap already marked
local function onPress(src)
	if get("TrooAttackEnabled") ~= true then return end
	show("TrooLastInput", src)
	local r = blocked()
	if r then
		show("TrooInputResult", r)
		return
	end
	local t = now()
	if script:GetAttribute("TrooDoubleTapEnabled") ~= false and allyFor ~= lastThrow
		and t - lastThrow <= (tonumber(script:GetAttribute("TrooDoubleTap")) or 0.3) then -- v1.2: the second tap
		allyFor = lastThrow
		fire("ally", t)
		char:SetAttribute("TrooLocalAllyAt", t)
		show("TrooInputResult", "ally")
		return
	end
	if t - lastThrow < (tonumber(get("TrooMinGap")) or 0.35) then
		show("TrooInputResult", "cooldown")
		return
	end
	if localLeft < 1 then
		show("TrooInputResult", "charges")
		return
	end
	lastThrow = t
	localLeft -= 1
	show("TrooLocalLeft", localLeft)
	fire(t)
	show("TrooInputResult", "throw")
	state = nil
	setState("throw")
	task.delay(THROW_SHOW, function()
		if state == "throw" and lastThrow == t then setState("idle") end
	end)
end

-- server refusals / wind-up cancel
char:GetAttributeChangedSignal("TrooAttackServerResultAt"):Connect(function()
	local r = char:GetAttribute("TrooAttackServerResult")
	local at = tonumber(char:GetAttribute("TrooAttackServerResultAt")) or 0
	if r == "ok" or at < lastThrow - 0.05 then return end
	show("TrooInputResult", "denied:" .. tostring(r))
	syncLeft()
	if state == "throw" then setState("idle") end
end)
char:GetAttributeChangedSignal("TrooThrowCancelAt"):Connect(function()
	show("TrooInputResult", "cancelled")
	syncLeft()
	if state == "throw" then setState("idle") end
end)

-- bindings
local function onAction(_, inputState, input)
	local src = (input and input.UserInputType == Enum.UserInputType.Touch) and "touch" or "key"
	if inputState == Enum.UserInputState.Begin then
		onPress(src)
		return Enum.ContextActionResult.Sink
	elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
		return Enum.ContextActionResult.Sink
	end
	return Enum.ContextActionResult.Pass
end
local function onClick(_, inputState, input)
	if not input or input.UserInputType ~= Enum.UserInputType.MouseButton1 then return Enum.ContextActionResult.Pass end
	if inputState == Enum.UserInputState.Begin then
		local lab = player:GetAttribute("LabOpen")
		if player:GetAttribute("InMenu") == true or (lab ~= nil and lab ~= "closed") or char:GetAttribute("SkillScreenOpen") == true
			or UserInputService:GetFocusedTextBox() then
			return Enum.ContextActionResult.Pass
		end
		onPress("click")
	end
	return Enum.ContextActionResult.Pass
end
local bound, clickBound = false, false
local function applyBinding()
	local on = get("TrooAttackEnabled") == true
	if on and not bound then
		ContextActionService:BindActionAtPriority(ACTION, onAction, true, Enum.ContextActionPriority.High.Value,
			Enum.KeyCode.ButtonR2)
		ContextActionService:SetTitle(ACTION, "Attack")
		bound = true
	elseif not on and bound then
		ContextActionService:UnbindAction(ACTION)
		bound = false
	end
	local clickOn = on and get("TrooLeftClickEnabled") ~= false and UserInputService.MouseEnabled
	if clickOn and not clickBound then
		ContextActionService:BindActionAtPriority(ACTION_CLICK, onClick, false, Enum.ContextActionPriority.High.Value,
			Enum.UserInputType.MouseButton1)
		clickBound = true
	elseif not clickOn and clickBound then
		ContextActionService:UnbindAction(ACTION_CLICK)
		clickBound = false
	end
	show("TrooClickBound", clickBound)
end
char:GetAttributeChangedSignal("TrooAttackEnabled"):Connect(applyBinding)
char:GetAttributeChangedSignal("TrooLeftClickEnabled"):Connect(applyBinding)
char:SetAttribute("TrooLocalState", "idle")
applyBinding()

local function cleanup()
	if bound then ContextActionService:UnbindAction(ACTION) end
	if clickBound then ContextActionService:UnbindAction(ACTION_CLICK) end
	bound, clickBound = false, false
end
hum.Died:Connect(cleanup)
char.AncestryChanged:Connect(function(_, parent)
	if not parent then cleanup() end
end)
