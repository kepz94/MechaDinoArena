-- TheriAttackTest v1.0 (Mecha Dino Arena) — the Therizinosaurus' ATTACK input on the owner's client: each tap is the next
-- hit of the 3-hit claw combo. MDA-202, plan docs/plans/THERIZINO_KIT_v1.0.md Task 5 (server: TheriAttackServer 1.0), mockup
-- docs/mockups/therizino_kit_options_v0.3.html (Kepu 2026-11-02: "3-hit combo", "A Reaper Sweeps").
-- Pattern: TenoAttackTest 1.4 (same bindings, blocks and refusal handling; no hold: the press is the tap).
-- Active while the character has TheriAttackEnabled = true (TherizinoModelData 1.3); does nothing on other dinos.
-- Input: left mouse button (action "DinoTheriAttackClick", MouseButton1, returns Pass; ignored while the menu is up (player
--   InMenu), the Lab is open (LabOpen ~= "closed"), SkillScreenOpen or a text box has focus) and action "DinoTheriAttack"
--   (gamepad ButtonR2 + a Roblox touch button titled "Attack"; ArenaTouch 1.11 lays it under the big yellow ATTACK).
-- Press: local checks "dead", "stunned", "dazed", "pinned", "menu" (TheriInputResult); then the server's rules predicted
--   locally (TheriMinGap -> "cooldown", TheriFinisherRecover after a finisher -> "recover"; no animation); else the next
--   step (TheriChainWindow: 1 -> 2 -> 3, else 1): TheriLocalStep, TheriLocalAt = server time (TheriPose 1.0 starts the
--   swing at once), DinoTheriAttack:FireServer(now).
-- Server refusal (TheriAttackServerResult other than "ok", newer than the request): the local swing stops (TheriLocalStep 0,
--   TheriInputResult "denied:<reason>") and the local combo restarts at step 1.
-- Switch: character attribute TheriLeftClickEnabled (default true; false = R2 / touch only).
-- Diagnostics (character, this client): TheriAttackTestVersion, TheriLocalStep (0 = none), TheriLocalAt, TheriInputResult,
--   TheriLastInput ("click" / "key" / "touch"), TheriClickBound.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local VERSION = "1.0"
local ACTION = "DinoTheriAttack"
local ACTION_CLICK = "DinoTheriAttackClick"
local DEFAULTS = {TheriAttackEnabled = false, TheriMinGap = 0.33, TheriChainWindow = 0.8, TheriFinisherRecover = 0.9,
	TheriLeftClickEnabled = true}

local char = script.Parent
local hum = char:WaitForChild("Humanoid", 10)
local player = Players:GetPlayerFromCharacter(char) or Players.LocalPlayer
pcall(function() ContextActionService:UnbindAction(ACTION) end) -- a leftover from the previous character
pcall(function() ContextActionService:UnbindAction(ACTION_CLICK) end)
char:SetAttribute("TheriAttackTestVersion", VERSION)
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
local remote -- found on first use
local function fire(...)
	remote = remote or ReplicatedStorage:FindFirstChild("DinoTheriAttack")
	if remote then remote:FireServer(...) end
end

local step, lastTap, finisherAt, lastSent = 0, -math.huge, -math.huge, 0

local function blocked()
	local t = now()
	if hum.Health <= 0 then return "dead" end
	if (tonumber(char:GetAttribute("StunnedUntil")) or 0) > t then return "stunned" end
	if (tonumber(char:GetAttribute("DazedUntil")) or 0) > t then return "dazed" end
	if char:GetAttribute("PinHeld") == true then return "pinned" end
	if player:GetAttribute("InMenu") == true then return "menu" end
	return nil
end

local function onTap(src)
	if get("TheriAttackEnabled") ~= true then return end
	show("TheriLastInput", src)
	local r = blocked()
	if r then
		show("TheriInputResult", r)
		return
	end
	local t = now()
	local since = t - lastTap
	if step == 3 and t - finisherAt < (tonumber(get("TheriFinisherRecover")) or 0.9) then
		show("TheriInputResult", "recover")
		return
	end
	if since < (tonumber(get("TheriMinGap")) or 0.33) then
		show("TheriInputResult", "cooldown")
		return
	end
	local nxt = 1
	if (step == 1 or step == 2) and since <= (tonumber(get("TheriChainWindow")) or 0.8) then nxt = step + 1 end
	step, lastTap = nxt, t
	if nxt == 3 then finisherAt = t end
	char:SetAttribute("TheriLocalAt", t)
	char:SetAttribute("TheriLocalStep", nxt) -- last: TheriPose reacts to this one
	lastSent = t
	fire(t)
	show("TheriInputResult", "hit" .. nxt)
end

-- server refusals stop the local swing
char:GetAttributeChangedSignal("TheriAttackServerResultAt"):Connect(function()
	local r = char:GetAttribute("TheriAttackServerResult")
	local at = tonumber(char:GetAttribute("TheriAttackServerResultAt")) or 0
	if r == "ok" or at < lastSent - 0.05 then return end
	step = 0
	char:SetAttribute("TheriLocalAt", now())
	char:SetAttribute("TheriLocalStep", 0)
	show("TheriInputResult", "denied:" .. tostring(r))
end)

-- bindings
local function onAction(_, inputState, input)
	local src = (input and input.UserInputType == Enum.UserInputType.Touch) and "touch" or "key"
	if inputState == Enum.UserInputState.Begin then
		onTap(src)
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
		onTap("click")
	end
	return Enum.ContextActionResult.Pass
end
local bound, clickBound = false, false
local function applyBinding()
	local on = get("TheriAttackEnabled") == true
	if on and not bound then
		ContextActionService:BindActionAtPriority(ACTION, onAction, true, Enum.ContextActionPriority.High.Value,
			Enum.KeyCode.ButtonR2)
		ContextActionService:SetTitle(ACTION, "Attack")
		bound = true
	elseif not on and bound then
		ContextActionService:UnbindAction(ACTION)
		bound = false
	end
	local clickOn = on and get("TheriLeftClickEnabled") ~= false and UserInputService.MouseEnabled
	if clickOn and not clickBound then
		ContextActionService:BindActionAtPriority(ACTION_CLICK, onClick, false, Enum.ContextActionPriority.High.Value,
			Enum.UserInputType.MouseButton1)
		clickBound = true
	elseif not clickOn and clickBound then
		ContextActionService:UnbindAction(ACTION_CLICK)
		clickBound = false
	end
	show("TheriClickBound", clickBound)
end
char:GetAttributeChangedSignal("TheriAttackEnabled"):Connect(applyBinding)
char:GetAttributeChangedSignal("TheriLeftClickEnabled"):Connect(applyBinding)
char:SetAttribute("TheriLocalStep", 0)
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
