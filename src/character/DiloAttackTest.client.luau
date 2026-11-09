-- DiloAttackTest v1.3 (Mecha Dino Arena) — the Dilophosaurus' ATTACK input on the owner's client (LocalScript,
-- StarterCharacterScripts). MDA-225, plan docs/plans/DILO_KIT_v1.0.md Task 5 (Kepu 2026-11-03: "C and J1", "Bite on press",
-- "Soft aim, near-sure hit"); server DiloAttackServer 1.0.
-- Only while the character's DiloAttackEnabled is true (the dilo). Inputs: CAS action "DinoDiloAttack" (the phone's big
--   ATTACK button over ArenaTouch 1.15's "DiloMain", and ButtonR2) and, with a mouse, CAS "DinoDiloAttackClick" on
--   MouseButton1 (not while the menu, the Lab, the skill screen or a text box has it). Both give a press and a release.
-- Press: the bite at once (on the press): when the local checks pass (alive, not stunned / dazed / pinned / in the menu) and
--   at least DiloMinGap (0.35) s since the last local bite -> DinoDiloAttack:FireServer("bite", server time),
--   DiloLocalBiteAt = that time, DiloInputResult "bite"; else DiloInputResult the reason ("cooldown" ...). The hold starts
--   either way (DiloHoldStart = server time of the press).
-- Hold: DiloLocalState "bite" for the first COIL_AFTER (0.15) s, then "coil" (neck coils, frill opens: DiloPose 1.0); once
--   held DiloHoldTime (0.4) s and the dart is ready (DiloDartCooldown 1.5 s since the last local spit) -> "armed".
-- Release: armed -> DinoDiloAttack:FireServer("dart", server time), DiloLocalDartAt = that time, DiloLocalState "spit",
--   DiloInputResult "dart"; not armed -> DiloLocalState "idle" (DiloInputResult "dartCooldown" when the hold was long enough
--   but the dart was not ready). A stun / daze / pin / menu while held cancels the hold ("idle", DiloInputResult the reason).
--   "spit" goes back to "idle" after SPIT_SHOW (0.45) s. Every state change stamps DiloLocalAt (server time) after the state.
-- Server refusals (DiloAttackServerResult other than "ok", newer than the request): DiloInputResult "denied:<reason>"; a
--   refused dart ends "spit" at once.
-- Switch: character attribute DiloLeftClickEnabled (default true; false = no mouse binding). Diagnostics (character, this
--   client): DiloAttackTestVersion, DiloLocalState, DiloLocalAt, DiloHoldStart, DiloLocalBiteAt, DiloLocalDartAt,
--   DiloInputResult, DiloLastInput ("click" / "touch" / "key"), DiloClickBound.
-- v1.1 (MDA-238, plan docs/plans/DILO_STATS_v1.0.md Task 4; Kepu 2026-11-04 "Yes, change both"): Cold Blood star. When the
--   server stamps the character's DiloDartResetAt (DiloAttackServer 1.1) later than this client's last spit, the local dart
--   recharge is cleared (the dart is ready at once) and DiloDartReadyAt = server now is stamped (ArenaTouch 1.16 / AbilityBar
--   1.27 show the dart pip full from it). Switch: script attribute DiloAttackTestResetEnabled (default true, read at each
--   stamp; false = 1.0).
-- v1.2 (plan docs/plans/DILO_MOVES_ANIM_v1.0.md Task 2, MDA-300; Kepu 2026-11-05 22:32 picked Spit Dart "A · Hood Flare": the
--   other players see the coil too): when the local state first becomes "coil" or "armed" in a hold ->
--   DinoDiloAttack:FireServer("coil", server time) (DiloAttackServer 1.4 stamps DiloCoilAt); when that hold then goes back
--   to "idle" without a spit (release not armed, stun / daze / pin / menu) -> FireServer("uncoil", server time). A spit
--   ends it on the server by itself. Switch: character attribute DiloCoilStampEnabled (default true, read at each change;
--   false = 1.1). Diagnostic: DiloCoilSent (count).
-- v1.3 (MDA-360; Kepu 2026-11-09 dilo spit only, confirmed tap to spit, a spit every 0.35 s; PC and phone together, the same
--   CAS actions): spit only = script attribute DiloAttackTestSpitOnlyEnabled ~= false (default true, read at each press) and the
--   character's DiloSpitOnly == true (DiloModelData 1.7). Press (tap, click, ButtonR2): the local checks (alive, not stunned /
--   dazed / pinned / in the menu), then the spit dart at once when at least DiloSpitGap (0.35; Quick Draw 0.26 / 0.19 / 0.14 /
--   0.14) s since the last local spit -> DinoDiloAttack:FireServer("dart", server time), DiloLocalDartAt = that time,
--   DiloInputResult "dart", DiloLocalState "spit" (back to "idle" after SPIT_SHOW 0.45 s, or at the next spit); else
--   DiloInputResult "dartCooldown". No bite, no hold, no coil / armed state (so no coil stamps); a release does nothing. The
--   Cold Blood star reset and the server refusals work as before. Off = 1.2 (bite on press, hold then release = dart).
--   Diagnostics: DiloAttackTestMode ("spit" / "bite+hold", at each press), DiloSpitTaps (count of spits sent).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")

local VERSION = "1.1" -- v1.1 Cold Blood dart reset
VERSION = "1.2" -- v1.2 coil stamps
VERSION = "1.3" -- v1.3 spit only: tap = spit dart
local ACTION = "DinoDiloAttack"
local ACTION_CLICK = "DinoDiloAttackClick"
local DEFAULTS = {DiloAttackEnabled = false, DiloMinGap = 0.35, DiloHoldTime = 0.4, DiloDartCooldown = 1.5,
	DiloLeftClickEnabled = true}
local COIL_AFTER, SPIT_SHOW = 0.15, 0.45

local char = script.Parent
local hum = char:WaitForChild("Humanoid", 10)
local player = Players:GetPlayerFromCharacter(char) or Players.LocalPlayer
pcall(function() ContextActionService:UnbindAction(ACTION) end) -- a leftover from the previous character (MDA-146 lesson)
pcall(function() ContextActionService:UnbindAction(ACTION_CLICK) end)
char:SetAttribute("DiloAttackTestVersion", VERSION)
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
	remote = remote or ReplicatedStorage:FindFirstChild("DinoDiloAttack")
	if remote then remote:FireServer(...) end
end

local lastBite, lastDart, lastSent = -math.huge, -math.huge, 0
local holding, pressAt, state = false, 0, "idle"
local function setState(s)
	if state == s then return end
	state = s
	char:SetAttribute("DiloLocalState", s)
	char:SetAttribute("DiloLocalAt", now()) -- after the state
end
-- v1.2: tell the server when the coil shows, so other players see it
local coilSent = false
local setState11 = setState
setState = function(s)
	local before = state
	setState11(s)
	if state == before then return end
	if char:GetAttribute("DiloCoilStampEnabled") == false then coilSent = false return end
	if (state == "coil" or state == "armed") and not coilSent then
		coilSent = true
		fire("coil", now())
		char:SetAttribute("DiloCoilSent", (char:GetAttribute("DiloCoilSent") or 0) + 1)
	elseif state == "idle" and coilSent then
		coilSent = false
		fire("uncoil", now())
	elseif state == "spit" or state == "bite" then
		coilSent = false
	end
end

local function blocked()
	local t = now()
	if hum.Health <= 0 then return "dead" end
	if (tonumber(char:GetAttribute("StunnedUntil")) or 0) > t then return "stunned" end
	if (tonumber(char:GetAttribute("DazedUntil")) or 0) > t then return "dazed" end
	if char:GetAttribute("PinHeld") == true then return "pinned" end
	if player:GetAttribute("InMenu") == true then return "menu" end
	return nil
end
local function dartReady(t) return t - lastDart >= (tonumber(get("DiloDartCooldown")) or 1.5) end

local function spitOnly() -- v1.3
	return script:GetAttribute("DiloAttackTestSpitOnlyEnabled") ~= false and char:GetAttribute("DiloSpitOnly") == true
end
local function onPress(src)
	if get("DiloAttackEnabled") ~= true then return end
	if script:GetAttribute("DiloAttackTestSpitOnlyEnabled") == nil then script:SetAttribute("DiloAttackTestSpitOnlyEnabled", true) end
	show("DiloAttackTestMode", spitOnly() and "spit" or "bite+hold")
	if spitOnly() then -- v1.3: tap = the spit dart at once
		show("DiloLastInput", src)
		local r = blocked()
		if r then
			show("DiloInputResult", r)
			return
		end
		local t = now()
		if t - lastDart < math.max(0, tonumber(get("DiloSpitGap")) or 0.35) then
			show("DiloInputResult", "dartCooldown")
			return
		end
		lastDart, lastSent = t, t
		fire("dart", t)
		char:SetAttribute("DiloLocalDartAt", t)
		char:SetAttribute("DiloSpitTaps", (char:GetAttribute("DiloSpitTaps") or 0) + 1)
		show("DiloInputResult", "dart")
		state = nil
		setState("spit")
		task.delay(SPIT_SHOW, function()
			if state == "spit" and char:GetAttribute("DiloLocalDartAt") == t then setState("idle") end
		end)
		return
	end
	show("DiloLastInput", src)
	local r = blocked()
	if r then
		show("DiloInputResult", r)
		return
	end
	local t = now()
	holding, pressAt = true, t
	char:SetAttribute("DiloHoldStart", t)
	if t - lastBite >= (tonumber(get("DiloMinGap")) or 0.35) then
		lastBite, lastSent = t, t
		fire("bite", t)
		char:SetAttribute("DiloLocalBiteAt", t)
		show("DiloInputResult", "bite")
		state = nil
		setState("bite")
	else
		show("DiloInputResult", "cooldown")
	end
end
local function onRelease()
	if not holding then return end
	holding = false
	local t = now()
	if state == "armed" then
		lastDart, lastSent = t, t
		fire("dart", t)
		char:SetAttribute("DiloLocalDartAt", t)
		show("DiloInputResult", "dart")
		setState("spit")
		task.delay(SPIT_SHOW, function()
			if state == "spit" and char:GetAttribute("DiloLocalDartAt") == t then setState("idle") end
		end)
	else
		if t - pressAt >= (tonumber(get("DiloHoldTime")) or 0.4) and not dartReady(t) then show("DiloInputResult", "dartCooldown") end
		if state == "bite" then
			task.delay(math.max(0, COIL_AFTER - (t - pressAt)), function() if state == "bite" and not holding then setState("idle") end end)
		else
			setState("idle")
		end
	end
end

RunService.Heartbeat:Connect(function()
	if not holding then return end
	local r = blocked()
	if r then
		holding = false
		show("DiloInputResult", r)
		setState("idle")
		return
	end
	local t = now()
	local held = t - pressAt
	if held >= (tonumber(get("DiloHoldTime")) or 0.4) and dartReady(t) then
		setState("armed")
	elseif held >= COIL_AFTER and state ~= "armed" then
		setState("coil")
	end
end)

-- server refusals
char:GetAttributeChangedSignal("DiloAttackServerResultAt"):Connect(function()
	local r = char:GetAttribute("DiloAttackServerResult")
	local at = tonumber(char:GetAttribute("DiloAttackServerResultAt")) or 0
	if r == "ok" or at < lastSent - 0.05 then return end
	show("DiloInputResult", "denied:" .. tostring(r))
	if state == "spit" then setState("idle") end
end)

-- v1.1: Cold Blood star (see the header)
if script:GetAttribute("DiloAttackTestResetEnabled") == nil then script:SetAttribute("DiloAttackTestResetEnabled", true) end
char:GetAttributeChangedSignal("DiloDartResetAt"):Connect(function()
	if script:GetAttribute("DiloAttackTestResetEnabled") == false then return end
	local at = tonumber(char:GetAttribute("DiloDartResetAt")) or 0
	if at <= 0 or at <= lastDart then return end
	lastDart = -math.huge
	char:SetAttribute("DiloDartReadyAt", now())
end)

-- bindings
local function onAction(_, inputState, input)
	local src = (input and input.UserInputType == Enum.UserInputType.Touch) and "touch" or "key"
	if inputState == Enum.UserInputState.Begin then
		onPress(src)
		return Enum.ContextActionResult.Sink
	elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
		onRelease()
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
	elseif inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel then
		onRelease()
	end
	return Enum.ContextActionResult.Pass
end
local bound, clickBound = false, false
local function applyBinding()
	local on = get("DiloAttackEnabled") == true
	if on and not bound then
		ContextActionService:BindActionAtPriority(ACTION, onAction, true, Enum.ContextActionPriority.High.Value,
			Enum.KeyCode.ButtonR2)
		ContextActionService:SetTitle(ACTION, "Attack")
		bound = true
	elseif not on and bound then
		ContextActionService:UnbindAction(ACTION)
		bound = false
	end
	local clickOn = on and get("DiloLeftClickEnabled") ~= false and UserInputService.MouseEnabled
	if clickOn and not clickBound then
		ContextActionService:BindActionAtPriority(ACTION_CLICK, onClick, false, Enum.ContextActionPriority.High.Value,
			Enum.UserInputType.MouseButton1)
		clickBound = true
	elseif not clickOn and clickBound then
		ContextActionService:UnbindAction(ACTION_CLICK)
		clickBound = false
	end
	show("DiloClickBound", clickBound)
end
char:GetAttributeChangedSignal("DiloAttackEnabled"):Connect(applyBinding)
char:GetAttributeChangedSignal("DiloLeftClickEnabled"):Connect(applyBinding)
char:SetAttribute("DiloLocalState", "idle")
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
