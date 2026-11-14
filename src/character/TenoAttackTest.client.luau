-- TenoAttackTest v1.5 (Mecha Dino Arena) — the Tenontosaurus' ATTACK input on the owner's client: tap = scratch, hold and
-- release = rear tail slam. MDA-172, plan docs/plans/TENO_KIT_v1.0.md Task 6 (server: TenoAttackServer 1.0), mockup
-- docs/mockups/teno_attacks_options.html v0.2 (Kepu 2026-10-31: "Tap = scratch, hold = slam").
-- Active while the character has TenoAttackEnabled = true (TenoModelData 1.1); does nothing on other dinos.
-- Input: left mouse button (action "DinoTenoAttackClick", MouseButton1, returns Pass; a press is ignored while the menu is
--   up (player InMenu), the Lab is open (LabOpen ~= "closed"), SkillScreenOpen or a text box has focus) and action
--   "DinoTenoAttack" (gamepad ButtonR2 + a Roblox touch button titled "Attack"; ArenaTouch 1.9 lays it under the big
--   yellow ATTACK). Both use Begin (press) and End (release).
-- Press: local checks "dead", "stunned", "pinned", "menu" (TenoInputResult); else the press starts (TenoLocalState
--   "press", TenoLocalAt = server time; no pose).
-- Held >= TenoSlamHoldMin (0.22 s): with TenoSlamLeft >= 1 (published by the server) -> TenoLocalState "hold" (the
--   wind-up pose, TenoLocalAt = the press time) and DinoTenoAttack:FireServer("hold", press time); with no charge ->
--   TenoInputResult "noCharge" (no wind-up; the release scratches; ArenaTouch / AbilityBar flash the pips from
--   TenoNoChargeAt).
-- Release: after a "hold" -> TenoLocalState "slam", TenoLocalAt = now, TenoLocalHold = held seconds,
--   FireServer("slam", now, held); else (a tap, or held with no charge) -> a scratch unless the last scratch was less than
--   TenoScratchGap s ago (TenoInputResult "cooldown", no animation): TenoLocalState "scratch", TenoLocalAt = now,
--   FireServer("scratch", now).
-- While holding: death, a stun, a pin or the menu ends the hold: TenoLocalState "none", FireServer("cancel", now).
-- Server refusal (TenoAttackServerResult other than "ok" / "emptyScratch", newer than the request): the local pose stops
--   (TenoLocalState "none", TenoInputResult "denied:<reason>").
-- Switch: character attribute TenoLeftClickEnabled (default true; false = R2 / touch only).
-- Diagnostics (character, this client): TenoAttackTestVersion, TenoLocalState ("none" / "press" / "hold" / "scratch" /
--   "slam"), TenoInputResult, TenoLastInput ("click" / "key" / "touch"), TenoClickBound, TenoNoChargeAt.
-- v1.1 (Buck Off II, plan docs/plans/TENO_STATS_v1.0.md): the wind-up also starts at 0 charges while TenoBuckFree is true
--   and TenoLatchedCount > 0 (TenoStatsServer 1.0: raptors latched on you; never while stunned, the press is refused then);
--   TenoAttackServer 1.1 makes that slam free. Switch: script attribute TenoAttackTestBuckEnabled (default true, read at
--   each hold; false = 1.0).
-- v1.2 (plan docs/plans/TENO_SLAM_REWORK_v1.0.md, the bite-like soft aim): at a slam release this client predicts the aim
--   with ReplicatedStorage.TenoSlamAimShared (TenoSlamAim 1.0, copied there by TenoAttackServer 1.2) over the dinos it
--   can see (other players' characters and DinoIsland.Bots models with a HumanoidRootPart, not knocked out) and sets
--   TenoLocalSlamYaw before TenoLocalState "slam", so the own tail turns at once (TenoPose 1.2); the server's aim
--   (TenoSlamAimYaw) is the one that hits. Switch: script attribute TenoAttackTestAimEnabled (default true, read at each
--   slam; false = yaw 0).
-- v1.3 (teno stats part 2, plan docs/plans/TENO_STATS_v1.1.md): the local scratch gap is TenoClawGap when it is above 0
--   (Front Claws III: 0.35 s; SkillEffects 1.34), else TenoScratchGap, matching TenoAttackServer 1.3. Switch: script
--   attribute TenoAttackTestClawGapEnabled (default true, read at each press; false = 1.2).
-- v1.4 (Kepu 2026-11-02, slam camera "Swing behind": the look left / right nudges the slam aim): while ShoulderCam 1.7's
--   flip is past half way (ShoulderCamSlamFlip >= 0.5) the release sends the flipped view's yaw (ShoulderCamSlamYaw, degrees,
--   + = left, clamped to +-TenoSlamAimMax) as a 4th slam argument; the predicted aim and TenoAttackServer 1.4 centre the
--   soft aim on it (no target in the zone = the slam swings to that yaw). Switch: script attribute
--   TenoAttackTestCamAimEnabled (default true, read at each release; false = 1.3).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local VERSION = "1.4"
VERSION = "1.5" -- v1.5 pre-match lock
-- v1.5 (pre-match lock, MDA-529, plan docs/plans/PREMATCH_LOCK_PAN_v1.0.md rule 3; Kepu 2026-11-13 18:23 "all mecha abilities and
--   actions should be unplayable ... during the count down", pick "A · Locked everywhere"): while the character's
--   PrematchLockUntil (PracticeServer 1.12) is after the server time, blocked() answers "locked" (no local start; the server drops it too).
local ACTION = "DinoTenoAttack"
local ACTION_CLICK = "DinoTenoAttackClick"
local DEFAULTS = {TenoAttackEnabled = false, TenoSlamHoldMin = 0.22, TenoScratchGap = 0.5, TenoLeftClickEnabled = true}

local char = script.Parent
local hum = char:WaitForChild("Humanoid", 10)
local player = Players:GetPlayerFromCharacter(char) or Players.LocalPlayer
pcall(function() ContextActionService:UnbindAction(ACTION) end) -- a leftover from the previous character
pcall(function() ContextActionService:UnbindAction(ACTION_CLICK) end)
char:SetAttribute("TenoAttackTestVersion", VERSION)
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
	remote = remote or ReplicatedStorage:FindFirstChild("DinoTenoAttack")
	if remote then remote:FireServer(...) end
end

local press = nil      -- {at, src, held, noCharge}
local lastScratch = -math.huge
local lastSent = 0

local function blocked()
	local t = now()
	if hum.Health <= 0 then return "dead" end
	if (tonumber(char:GetAttribute("StunnedUntil")) or 0) > t then return "stunned" end
	if char:GetAttribute("PinHeld") == true then return "pinned" end
	if player:GetAttribute("InMenu") == true then return "menu" end
	return nil
end
local function __prematchLocked() -- v1.5: PracticeServer 1.12 pre-match lock
	return (tonumber(char:GetAttribute("PrematchLockUntil")) or 0) > workspace:GetServerTimeNow()
end
do -- v1.5: locked before GO
	local rawBlocked = blocked
	blocked = function(...)
		if __prematchLocked() then return "locked" end
		return rawBlocked(...)
	end
end

local function setState(st, at)
	char:SetAttribute("TenoLocalAt", at)
	char:SetAttribute("TenoLocalState", st)
end

local function onPress(src)
	if get("TenoAttackEnabled") ~= true or press then return end
	local r = blocked()
	show("TenoLastInput", src)
	if r then
		show("TenoInputResult", r)
		return
	end
	local t = now()
	press = {at = t, src = src, held = false, noCharge = false}
	setState("press", t)
	show("TenoInputResult", "press")
end

-- v1.2: predicted soft aim
local aimShared
-- v1.4: the soft aim centred on a preferred yaw (degrees, + = left); the same rule as TenoAttackServer 1.4
local function pickPref(mod, cands, s, pref)
	if type(pref) ~= "number" then return mod.pick(cands, s) end
	pref = math.clamp(pref, -s.aimMax, s.aimMax)
	local c, sn = math.cos(math.rad(pref)), math.sin(math.rad(pref))
	local shifted, back = {}, {}
	for _, k in ipairs(cands) do
		if type(k.x) == "number" and type(k.z) == "number" and math.abs(math.deg(math.atan2(k.x, k.z))) <= s.aimMax then
			local n = table.clone(k)
			n.x, n.z = k.x * c - k.z * sn, k.z * c + k.x * sn
			table.insert(shifted, n)
			back[n] = k
		end
	end
	local r = mod.pick(shifted, s)
	local yaw = r.target and math.clamp(r.yaw + pref, -s.aimMax, s.aimMax) or pref
	return {yaw = yaw, target = r.target and back[r.target] or nil, members = mod.members(cands, yaw, s)}
end
local function camPref()
	if script:GetAttribute("TenoAttackTestCamAimEnabled") == false then return nil end
	if (tonumber(char:GetAttribute("ShoulderCamSlamFlip")) or 0) < 0.5 then return nil end
	local y = tonumber(char:GetAttribute("ShoulderCamSlamYaw"))
	if not y then return nil end
	local mx = tonumber(char:GetAttribute("TenoSlamAimMax")) or 35
	return math.clamp(y, -mx, mx)
end
local function predictYaw(pref)
	if script:GetAttribute("TenoAttackTestAimEnabled") == false then return 0 end
	if not aimShared then
		local m = ReplicatedStorage:FindFirstChild("TenoSlamAimShared")
		if not m then return 0 end
		local ok, mod = pcall(require, m)
		if not ok then return 0 end
		aimShared = mod
	end
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return 0 end
	local s = char:GetScale()
	local function n(k, d) return tonumber(char:GetAttribute(k)) or d end
	local models = {}
	for _, pl in ipairs(Players:GetPlayers()) do if pl ~= player and pl.Character then table.insert(models, pl.Character) end end
	local isl = workspace:FindFirstChild("DinoIsland")
	local bots = isl and isl:FindFirstChild("Bots")
	for _, b in ipairs(bots and bots:GetChildren() or {}) do table.insert(models, b) end
	local cands = {}
	for _, m in ipairs(models) do
		local r = m:FindFirstChild("HumanoidRootPart")
		if r and m:GetAttribute("DummyState") ~= "ko" and m:GetAttribute("PounceLatched") ~= true then
			local lp = root.CFrame:PointToObjectSpace(r.Position)
			table.insert(cands, {id = m, x = -lp.X, z = lp.Z, gap = math.max(0, (r.Position - root.Position).Magnitude - 2 * s)})
		end
	end
	local ok, res = pcall(pickPref, aimShared, cands, {reach = n("TenoSlamReach", 18.5) * s, aimMax = n("TenoSlamAimMax", 35), cone = n("TenoSlamCone", 70)}, pref) -- v1.4: + pref
	return ok and res.yaw or 0
end

local function onRelease()
	local p = press
	if not p then return end
	press = nil
	local t = now()
	if p.held then
		local held = t - p.at
		char:SetAttribute("TenoLocalHold", held)
		local pref = camPref() -- v1.4
		char:SetAttribute("TenoLocalSlamYaw", predictYaw(pref)) -- v1.2; v1.4: + pref
		setState("slam", t)
		lastSent = t
		fire("slam", t, held, pref)
		show("TenoInputResult", "slam")
		return
	end
	local gapNow = tonumber(get("TenoScratchGap")) or 0.5 -- v1.3: Front Claws III
	local cg = tonumber(char:GetAttribute("TenoClawGap")) or 0
	if script:GetAttribute("TenoAttackTestClawGapEnabled") ~= false and cg > 0 then gapNow = cg end
	if t - lastScratch < gapNow then
		setState("none", t)
		show("TenoInputResult", "cooldown")
		return
	end
	lastScratch = t
	setState("scratch", t)
	lastSent = t
	fire("scratch", t)
	show("TenoInputResult", p.noCharge and "scratchNoCharge" or "scratch")
end

local function cancel(reason)
	if not press then return end
	local wasHeld = press.held
	press = nil
	local t = now()
	setState("none", t)
	show("TenoInputResult", "cancel:" .. reason)
	if wasHeld then fire("cancel", t) end
end

RunService.Heartbeat:Connect(function()
	if not press then return end
	local r = blocked()
	if r then
		cancel(r)
		return
	end
	if not press.held and not press.noCharge and now() - press.at >= (tonumber(get("TenoSlamHoldMin")) or 0.22) then
		local freeHold = script:GetAttribute("TenoAttackTestBuckEnabled") ~= false and char:GetAttribute("TenoBuckFree") == true
			and (tonumber(char:GetAttribute("TenoLatchedCount")) or 0) > 0 -- v1.1: Buck Off II
		if (tonumber(char:GetAttribute("TenoSlamLeft")) or 0) >= 1 or freeHold then
			press.held = true
			setState("hold", press.at)
			fire("hold", press.at)
			show("TenoInputResult", "hold")
		else
			press.noCharge = true
			char:SetAttribute("TenoNoChargeAt", now())
			show("TenoInputResult", "noCharge")
		end
	end
end)

-- server refusals stop the local pose
char:GetAttributeChangedSignal("TenoAttackServerResultAt"):Connect(function()
	local r = char:GetAttribute("TenoAttackServerResult")
	local at = tonumber(char:GetAttribute("TenoAttackServerResultAt")) or 0
	if r == "ok" or r == "emptyScratch" or at < lastSent - 0.05 then return end
	local st = char:GetAttribute("TenoLocalState")
	if st == "scratch" or st == "slam" or st == "hold" then
		if press then press = nil end
		setState("none", now())
		show("TenoInputResult", "denied:" .. tostring(r))
	end
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
		if press and press.src == "click" then onRelease() end
	end
	return Enum.ContextActionResult.Pass
end
local bound, clickBound = false, false
local function applyBinding()
	local on = get("TenoAttackEnabled") == true
	if on and not bound then
		ContextActionService:BindActionAtPriority(ACTION, onAction, true, Enum.ContextActionPriority.High.Value,
			Enum.KeyCode.ButtonR2)
		ContextActionService:SetTitle(ACTION, "Attack")
		bound = true
	elseif not on and bound then
		ContextActionService:UnbindAction(ACTION)
		bound = false
	end
	local clickOn = on and get("TenoLeftClickEnabled") ~= false and UserInputService.MouseEnabled
	if clickOn and not clickBound then
		ContextActionService:BindActionAtPriority(ACTION_CLICK, onClick, false, Enum.ContextActionPriority.High.Value,
			Enum.UserInputType.MouseButton1)
		clickBound = true
	elseif not clickOn and clickBound then
		ContextActionService:UnbindAction(ACTION_CLICK)
		clickBound = false
	end
	show("TenoClickBound", clickBound)
end
char:GetAttributeChangedSignal("TenoAttackEnabled"):Connect(applyBinding)
char:GetAttributeChangedSignal("TenoLeftClickEnabled"):Connect(applyBinding)
setState("none", now())
applyBinding()

local function cleanup()
	if bound then ContextActionService:UnbindAction(ACTION) end
	if clickBound then ContextActionService:UnbindAction(ACTION_CLICK) end
	bound, clickBound = false, false
end
hum.Died:Connect(function()
	cancel("dead")
	cleanup()
end)
char.AncestryChanged:Connect(function(_, parent)
	if not parent then cleanup() end
end)
