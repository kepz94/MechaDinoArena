-- HeadbuttTest v1.4 (Mecha Dino Arena) — the pachy's headbutt charge on the owner's client. MDA-119, plan
-- docs/plans/PACHY_PLAYABLE_v1.0.md Task 6 (server: HeadbuttServer 1.0).
-- Active while the character has HeadbuttEnabled = true (PachyModelData 1.1). Kepu 2026-10-30: the headbutt is the
--   pachy's ATTACK ("Headbutt = ATTACK"), "when its in charge mode it should be pretty manueverable", "it should be able to
--   leap as well as charge and leap".
-- Input: left mouse button (action "DinoHeadbuttClick", MouseButton1, returns Pass; ignored while the menu is up (player
--   InMenu), the Lab is open (LabOpen ~= "closed"), SkillScreenOpen or a text box has focus) and action "DinoHeadbutt"
--   (F, gamepad ButtonX, Roblox touch button that ArenaTouch 1.5 lays its ATTACK button over).
-- Press: local checks "dead", "stunned", "busy" (a charge running), "empty" (HeadbuttChargesNow < 1, published by the
--   server) -> HeadbuttPredictedAt = server time, DinoHeadbuttRequest:FireServer(stamp), state "windup".
-- Windup (HeadbuttWindup s): the body keeps its movement; the pose dips the head (IdleAnimation / HeadbuttPose).
-- Charge (up to HeadbuttMaxTime s): every frame after the controls (RenderStep Character + 6) WalkSpeed = MoveRunSpeed x
--   HeadbuttSpeedMul and the body is driven: with move input (PlayerModule controls' move vector, camera relative) it
--   steers toward the input, without input it keeps charging straight ahead; TurnLimitRate is x HeadbuttTurnMul while
--   charging (TurnLimit turns the body toward the move direction). The leap (JumpTest) works during the charge; the
--   charge speed is kept in the air.
-- Contact: the own Hitboxes "Head" part, grown by HeadbuttReach x scale on every side, overlapping a hitbox of another
--   Bitable dino (players and bots; not KO) -> DinoHeadbuttHit:FireServer(stamp, model), state "recover" (RECOVER s).
--   No contact by the end -> DinoHeadbuttEnd:FireServer(stamp, "timeout"). A server result other than "ok" for this
--   press cancels the charge ("denied").
-- End: WalkSpeed and TurnLimitRate are put back (SprintTest re-applies its speed on the next change).
-- Diagnostics (character, this client): HeadbuttTestVersion, HeadbuttTestState / HeadbuttLocalState ("ready" / "windup" /
--   "charge" / "recover"), HeadbuttInputResult, HeadbuttLastInput ("click" / "key" / "touch"), HeadbuttLocalEndAt,
--   HeadbuttContact (target name), HeadbuttClickBound, HeadbuttSteer ("input" / "straight").
-- Switch: character attribute HeadbuttLeftClickEnabled (default true; false = F / X / touch only).
-- v1.1 (pachy Blood Rush, MDA-124): at 0 charges the press still goes to the server (a sacrifice, HeadbuttServer 1.5)
--   when BloodRushEnabled is true, health is above half of MaxHealth and HeadbuttSacrifices < BloodRushMax; the press
--   result is then "sacrifice" until the server answers. Otherwise "empty" as before. Switch: character attribute
--   HeadbuttSacrificeInputEnabled (default true; false = 1.0).
-- v1.2 (Arena squads, MDA-160, plan docs/plans/SQUADS_v1.0.md Task S3, ADR-006; Kepu 2026-10-31 "turning friendly fire off"): a squadmate is not a headbutt target (findTargets), so the charge
--   passes through a squadmate instead of ending on contact.
--   Squadmates = ReplicatedStorage.SquadShared.SquadRules (SquadServer 1.0's copy) sameChar. Switch: script attribute
--   HeadbuttTestSquadEnabled (default true, read at each check; false = 1.1).
-- v1.3 (MDA-355 + MDA-356; Kepu 2026-11-08 "Hits from too far" -> reach "Front, short reach", tail "Yes, tail counts";
--   "pachy headbutt when trapped by zino still works which defeats the purpose of throwing a trap" -> "No movement moves"):
--   * precise contact: the grown head box (1.2) is only the broad check. A target hitbox part counts when the gap from the
--     un-grown head box to it (closest points, 4 passes) is at most HeadbuttReach x scale ahead (along the flat facing),
--     HeadbuttReachSide (character attribute, default 0.5) x scale to either side and HeadbuttReach x scale up / down;
--     a part behind the head's front counts its distance back as side. Any target segment counts (tail too). Switch:
--     script attribute HeadbuttTestPreciseEnabled (default true, read every frame; false = 1.2's grown-box overlap).
--     Diagnostics: HeadbuttContactGap ("fwd/side/up" studs, 0.1 steps, at contact), HeadbuttNearMisses (broad-box parts
--     refused, count).
--   * snare block: while TheriSnaredUntil (Snare Wires bola) or HookHeldUntil (Reaper Hook / Grappling Hook hold) is
--     after now, a press is refused ("snared") and a windup / charge in progress ends at once (DinoHeadbuttEnd reason
--     "snared", diag HeadbuttSnareCancels). Switch: script attribute HeadbuttTestSnareBlockEnabled (default true, read at
--     each press / frame; false = 1.2).
--   * slow back: after the charge puts WalkSpeed back, the character attribute SprintApplyRequest (os.clock) is set so
--     SprintTest 1.23 recomputes the speed with any slow that landed during the charge (the charge overwrote it every
--     frame). Switch: script attribute HeadbuttTestReapplyEnabled (default true; false = 1.2).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local VERSION = "1.2"
VERSION = "1.3" -- v1.3 precise front contact, snare block, slow back
VERSION = "1.4" -- v1.4 pre-match lock
-- v1.4 (pre-match lock, MDA-529, plan docs/plans/PREMATCH_LOCK_PAN_v1.0.md rule 3; Kepu 2026-11-13 18:23 "all mecha abilities and
--   actions should be unplayable ... during the count down", pick "A · Locked everywhere"): while the character's
--   PrematchLockUntil (PracticeServer 1.12) is after the server time, tryPress() does nothing (no local start; the server drops it too).
local ACTION = "DinoHeadbutt"
local ACTION_CLICK = "DinoHeadbuttClick"
local BIND = "DinoHeadbuttDrive"
local RECOVER = 0.3
local DEFAULTS = {HeadbuttEnabled = false, HeadbuttWindup = 0.15, HeadbuttSpeedMul = 1.4, HeadbuttMaxTime = 1.8,
	HeadbuttTurnMul = 2, HeadbuttReach = 2, HeadbuttReachSide = 0.5, MoveRunSpeed = 30, TurnLimitRate = 180, HeadbuttLeftClickEnabled = true}

local char = script.Parent
local hum = char:WaitForChild("Humanoid", 10)
local hrp = char:WaitForChild("HumanoidRootPart", 10)
local player = Players.LocalPlayer
if not (hum and hrp) or Players:GetPlayerFromCharacter(char) ~= player then return end
char:SetAttribute("HeadbuttTestVersion", VERSION)

for _, k in ipairs({"HeadbuttTestPreciseEnabled", "HeadbuttTestSnareBlockEnabled", "HeadbuttTestReapplyEnabled"}) do -- v1.3
	if script:GetAttribute(k) == nil then script:SetAttribute(k, true) end
end
local requestRemote = ReplicatedStorage:WaitForChild("DinoHeadbuttRequest", 10)
local hitRemote = ReplicatedStorage:WaitForChild("DinoHeadbuttHit", 10)
local endRemote = ReplicatedStorage:WaitForChild("DinoHeadbuttEnd", 10)

local function get(k)
	local v = char:GetAttribute(k)
	if v == nil then v = DEFAULTS[k] end
	return v
end
local shown = {}
local function show(attr, value)
	if shown[attr] ~= value then
		shown[attr] = value
		char:SetAttribute(attr, value)
	end
end

-- move input from the default controls (camera relative), if available
local controls
do
	local ps = player:FindFirstChild("PlayerScripts")
	local pm = ps and ps:FindFirstChild("PlayerModule")
	if pm then
		local ok, m = pcall(require, pm)
		if ok and m then
			local ok2, c = pcall(function() return m:GetControls() end)
			if ok2 then controls = c end
		end
	end
end
local function moveInput()
	if controls then
		local ok, v = pcall(function() return controls:GetMoveVector() end)
		if ok and typeof(v) == "Vector3" and v.Magnitude > 0.1 then
			local cam = workspace.CurrentCamera
			local cf = cam and cam.CFrame or CFrame.identity
			local fwd = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)
			local right = Vector3.new(cf.RightVector.X, 0, cf.RightVector.Z)
			if fwd.Magnitude < 1e-3 then return nil end
			local w = fwd.Unit * -v.Z + right.Unit * v.X
			if w.Magnitude > 1e-3 then return w.Unit end
		end
	end
	return nil
end

local state = "ready"
local stamp, phaseAt
local savedSpeed, savedTurn
local targets = {}
local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Include

local function setState(s)
	state = s
	show("HeadbuttTestState", s)
	show("HeadbuttLocalState", s)
end
setState("ready")

local function headBox()
	local hb = char:FindFirstChild("Hitboxes")
	if hb then
		for _, p in ipairs(hb:GetChildren()) do
			if p:IsA("BasePart") and p:GetAttribute("HitboxSegment") == "Head" then return p end
		end
	end
	return nil
end

-- v1.2: squadmates are never targets (ReplicatedStorage.SquadShared.SquadRules, loaded on first use)
local squadMod
local function squadmate(a, b)
	if script:GetAttribute("HeadbuttTestSquadEnabled") == false then return false end
	if not squadMod then
		local sh = game:GetService("ReplicatedStorage"):FindFirstChild("SquadShared")
		local m = sh and sh:FindFirstChild("SquadRules")
		if not m then return false end
		local ok, mod = pcall(require, m)
		if not ok then return false end
		squadMod = mod
	end
	return squadMod.sameChar(a, b)
end
local function findTargets()
	local list, folders = {}, {}
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("Folder") and d.Name == "Hitboxes" then
			local m = d.Parent
			if m and m:IsA("Model") and m ~= char and m:GetAttribute("Bitable") == true
				and (m:GetAttribute("Species") ~= nil or m:GetAttribute("IsBot") == true) and m:GetAttribute("DummyState") ~= "ko"
				and not squadmate(char, m) then -- v1.2: squad
				table.insert(folders, d)
				list[d] = m
			end
		end
	end
	overlap.FilterDescendantsInstances = folders
	targets = list
end

local turnSaved = false
local function restore()
	local had = savedSpeed ~= nil -- v1.3
	if savedSpeed then hum.WalkSpeed = savedSpeed end
	if turnSaved then char:SetAttribute("TurnLimitRate", savedTurn) end
	savedSpeed, savedTurn, turnSaved = nil, nil, false
	if had and script:GetAttribute("HeadbuttTestReapplyEnabled") ~= false then -- v1.3: SprintTest re-applies any slow
		char:SetAttribute("SprintApplyRequest", os.clock())
	end
end
local function snared() -- v1.3: Snare Wires bola / Reaper Hook hold
	if script:GetAttribute("HeadbuttTestSnareBlockEnabled") == false then return false end
	local t = workspace:GetServerTimeNow()
	return (tonumber(char:GetAttribute("TheriSnaredUntil")) or 0) > t or (tonumber(char:GetAttribute("HookHeldUntil")) or 0) > t
end
-- v1.3: precise contact (closest points between the un-grown head box and a target part)
local function closestOn(part, pos)
	local lp = part.CFrame:PointToObjectSpace(pos)
	local h = part.Size / 2
	return part.CFrame:PointToWorldSpace(Vector3.new(math.clamp(lp.X, -h.X, h.X), math.clamp(lp.Y, -h.Y, h.Y),
		math.clamp(lp.Z, -h.Z, h.Z)))
end
local function frontReach(head, p) -- true when p is within the forward-weighted reach of the head box; + the gap text
	local a, b = head.Position, nil
	for _ = 1, 4 do
		b = closestOn(p, a)
		a = closestOn(head, b)
	end
	local d = b - a
	local look = Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z)
	look = look.Magnitude > 1e-3 and look.Unit or Vector3.zAxis
	local flatD = Vector3.new(d.X, 0, d.Z)
	local fwd = flatD:Dot(look)
	local side = (flatD - look * fwd).Magnitude
	if fwd < 0 then side, fwd = math.sqrt(side * side + fwd * fwd), 0 end
	local up = math.abs(d.Y)
	local sc = char:GetScale()
	local reach = get("HeadbuttReach") * sc
	local ok = fwd <= reach and side <= get("HeadbuttReachSide") * sc and up <= reach
	local function r1(x) return math.floor(x * 10 + 0.5) / 10 end
	return ok, r1(fwd) .. "/" .. r1(side) .. "/" .. r1(up)
end

local function finishLocal(nextState, reason)
	restore()
	show("HeadbuttLocalEndAt", workspace:GetServerTimeNow())
	if reason and endRemote and stamp then endRemote:FireServer(stamp, reason) end
	setState(nextState)
	phaseAt = os.clock()
end

local function tryPress(source)
	local result
	if get("HeadbuttEnabled") ~= true then
		result = "disabled"
	elseif hum.Health <= 0 then
		result = "dead"
	elseif (char:GetAttribute("StunnedUntil") or 0) > workspace:GetServerTimeNow() then
		result = "stunned"
	elseif snared() then -- v1.3
		result = "snared"
	elseif state ~= "ready" then
		result = "busy"
	elseif (tonumber(char:GetAttribute("HeadbuttChargesNow")) or 0) < 1 then
		result = "empty"
		if char:GetAttribute("HeadbuttSacrificeInputEnabled") ~= false and char:GetAttribute("BloodRushEnabled") == true
			and hum.Health > hum.MaxHealth * 0.5
			and (tonumber(char:GetAttribute("HeadbuttSacrifices")) or 0) < (tonumber(char:GetAttribute("BloodRushMax")) or 2) then
			result = nil -- v1.1: Blood Rush sacrifice (the server checks again and takes the health)
			show("HeadbuttSacrificeInput", (char:GetAttribute("HeadbuttSacrificeInput") or 0) + 1)
		end
	end
	show("HeadbuttLastInput", source)
	if result then
		show("HeadbuttInputResult", result)
		return
	end
	stamp = workspace:GetServerTimeNow()
	char:SetAttribute("HeadbuttPredictedAt", stamp)
	if requestRemote then requestRemote:FireServer(stamp) end
	show("HeadbuttInputResult", "sent")
	setState("windup")
	phaseAt = os.clock()
end
local function __prematchLocked() -- v1.4: PracticeServer 1.12 pre-match lock
	return (tonumber(char:GetAttribute("PrematchLockUntil")) or 0) > workspace:GetServerTimeNow()
end
do -- v1.4: no press before GO
	local rawPress = tryPress
	tryPress = function(...)
		if __prematchLocked() then return end
		return rawPress(...)
	end
end

-- a denied request cancels the local charge
char:GetAttributeChangedSignal("HeadbuttServerResultAt"):Connect(function()
	local r = char:GetAttribute("HeadbuttServerResult")
	if r ~= "ok" and (state == "windup" or state == "charge") then
		show("HeadbuttInputResult", "denied:" .. tostring(r))
		finishLocal("ready", nil)
	end
end)

local function drive(dt)
	if state == "ready" then return end
	local t = os.clock() - (phaseAt or os.clock())
	if hum.Health <= 0 then
		finishLocal("ready", nil)
		return
	end
	if (state == "windup" or state == "charge") and snared() then -- v1.3: a snare ends the charge
		show("HeadbuttSnareCancels", (char:GetAttribute("HeadbuttSnareCancels") or 0) + 1)
		show("HeadbuttInputResult", "snared")
		finishLocal("ready", "snared")
		return
	end
	if state == "windup" then
		if t >= get("HeadbuttWindup") then
			findTargets()
			savedSpeed = hum.WalkSpeed
			savedTurn, turnSaved = char:GetAttribute("TurnLimitRate"), true
			char:SetAttribute("TurnLimitRate", (tonumber(savedTurn) or DEFAULTS.TurnLimitRate) * get("HeadbuttTurnMul"))
			setState("charge")
			phaseAt = os.clock()
		end
		return
	end
	if state == "recover" then
		if t >= RECOVER then setState("ready") end
		return
	end
	-- charge
	if t >= get("HeadbuttMaxTime") then
		finishLocal("ready", "timeout")
		return
	end
	hum.WalkSpeed = (tonumber(char:GetAttribute("MoveRunSpeed")) or DEFAULTS.MoveRunSpeed) * get("HeadbuttSpeedMul")
	local want = moveInput()
	if want then
		hum:Move(want, false)
		show("HeadbuttSteer", "input")
	else
		local look = Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z)
		if look.Magnitude > 1e-3 then hum:Move(look.Unit, false) end
		show("HeadbuttSteer", "straight")
	end
	-- contact
	local head = headBox()
	if head then
		local grow = get("HeadbuttReach") * char:GetScale()
		local hits = workspace:GetPartBoundsInBox(head.CFrame, head.Size + Vector3.new(grow, grow, grow) * 2, overlap)
		local precise = script:GetAttribute("HeadbuttTestPreciseEnabled") ~= false -- v1.3
		for _, p in ipairs(hits) do
			local m = targets[p.Parent]
			local reachOk = true
			if precise and m then
				local okR, gapText = frontReach(head, p)
				reachOk = okR
				if okR then
					show("HeadbuttContactGap", gapText)
				else
					char:SetAttribute("HeadbuttNearMisses", (char:GetAttribute("HeadbuttNearMisses") or 0) + 1)
				end
			end
			if m and reachOk and m.Parent and m:GetAttribute("DummyState") ~= "ko" then
				show("HeadbuttContact", m.Name)
				if hitRemote then hitRemote:FireServer(stamp, m) end
				finishLocal("recover", nil)
				return
			end
		end
	end
end
RunService:BindToRenderStep(BIND, Enum.RenderPriority.Character.Value + 6, drive)

-- bindings
local function onAction(_, inputState, input)
	if inputState ~= Enum.UserInputState.Begin then return Enum.ContextActionResult.Pass end
	local src = (input and input.UserInputType == Enum.UserInputType.Touch) and "touch" or "key"
	tryPress(src)
	return Enum.ContextActionResult.Sink
end
local bound, clickBound = false, false
local function onClick(_, inputState, input)
	if inputState ~= Enum.UserInputState.Begin or not input or input.UserInputType ~= Enum.UserInputType.MouseButton1 then
		return Enum.ContextActionResult.Pass
	end
	local lab = player:GetAttribute("LabOpen")
	if player:GetAttribute("InMenu") == true or (lab ~= nil and lab ~= "closed") or char:GetAttribute("SkillScreenOpen") == true
		or UserInputService:GetFocusedTextBox() then
		return Enum.ContextActionResult.Pass
	end
	tryPress("click")
	return Enum.ContextActionResult.Pass
end
local function applyBinding()
	local on = get("HeadbuttEnabled") == true
	if on and not bound then
		ContextActionService:BindActionAtPriority(ACTION, onAction, true, Enum.ContextActionPriority.High.Value,
			Enum.KeyCode.F, Enum.KeyCode.ButtonX)
		ContextActionService:SetTitle(ACTION, "Attack")
		bound = true
	elseif not on and bound then
		ContextActionService:UnbindAction(ACTION)
		bound = false
	end
	local clickOn = on and get("HeadbuttLeftClickEnabled") ~= false and UserInputService.MouseEnabled
	if clickOn and not clickBound then
		ContextActionService:BindActionAtPriority(ACTION_CLICK, onClick, false, Enum.ContextActionPriority.High.Value,
			Enum.UserInputType.MouseButton1)
		clickBound = true
	elseif not clickOn and clickBound then
		ContextActionService:UnbindAction(ACTION_CLICK)
		clickBound = false
	end
	show("HeadbuttClickBound", clickBound)
end
char:GetAttributeChangedSignal("HeadbuttEnabled"):Connect(applyBinding)
char:GetAttributeChangedSignal("HeadbuttLeftClickEnabled"):Connect(applyBinding)
applyBinding()

local function cleanup()
	if bound then ContextActionService:UnbindAction(ACTION) end
	if clickBound then ContextActionService:UnbindAction(ACTION_CLICK) end
	RunService:UnbindFromRenderStep(BIND)
	restore()
end
hum.Died:Connect(cleanup)
char.AncestryChanged:Connect(function(_, parent)
	if not parent then cleanup() end
end)
