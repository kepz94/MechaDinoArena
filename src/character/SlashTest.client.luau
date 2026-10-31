-- SlashTest v1.3 (Mecha Dino Arena) — the Herrerasaurus' dash-through slash on the owner's client. MDA-141, plan
-- docs/plans/HERRERA_KIT_v1.0.md Task 9 (server: SlashServer 1.1), mockup docs/mockups/herrera_kit_options.html.
-- Kepu 2026-10-30: "Dash-through slash"; the drop attack "should be able to happen if I press the dash aimed at a nearby
--   target but not be its own dedicated button".
-- Active while the character has SlashEnabled = true (HerreraModelData 1.2); does nothing on other dinos.
-- Input: left mouse button (action "DinoSlashClick", MouseButton1, returns Pass; ignored while the menu is up (player
--   InMenu), the Lab is open (LabOpen ~= "closed"), SkillScreenOpen or a text box has focus) and action "DinoSlash"
--   (gamepad ButtonR2 + a Roblox touch button titled "Slash").
-- Press: local checks "disabled", "dead", "stunned", "pinned", "busy" (a dash running), "empty" (SlashChargesNow < 1,
--   published by the server). Kind: "dive" while this client's ClimbLocalState (ClimbTest) is "climbing" / "clinging" /
--   "top", else "ground". Dive target: the dino (a workspace Model with a Hitboxes folder, Bitable true, a Species or
--   IsBot, not this character, not KO) whose HumanoidRootPart is within SlashDiveRange x scale of this HumanoidRootPart,
--   lower than it, and inside SlashDiveCone degrees of the camera's look; the one nearest the look wins; none = a leap.
--   -> DinoSlashRequest:FireServer(stamp, kind, target or nil); the dash starts at once (prediction).
-- Dash (a LinearVelocity "SlashVelocity" on the HumanoidRootPart, MaxForce huge):
--   ground / leap: Plane mode (world X / Z only; gravity untouched) at SlashDist x scale / SlashTime along the body's
--     horizontal facing for SlashTime s (a leap off a tree falls on its own).
--   dive with a target: Vector mode straight at the target's HumanoidRootPart at the same speed; the time is the distance
--     / that speed (at least SlashTime), re-aimed every frame at the target's current position.
--   Each frame: the character's bounding box grown by SlashReach x scale on every side is overlap-tested against the
--   other dinos' Hitboxes parts; each dino touched -> DinoSlashHit:FireServer(stamp, model), once per dash (SlashContact
--   = its name). A server result other than "ok" for this press stops the dash ("denied:<reason>").
-- End: the LinearVelocity is switched off; state "recover" for RECOVER s, then "ready".
-- ClimbTest 1.9 lets go of the trunk while SlashLocalState is "dash".
-- Diagnostics (character, this client): SlashTestVersion, SlashLocalState ("ready" / "dash" / "recover"), SlashLocalKind
--   ("ground" / "dive" / "leap"), SlashLocalTarget, SlashInputResult, SlashLastInput ("click" / "key" / "touch"),
--   SlashContact, SlashContacts (count), SlashLocalEndAt, SlashClickBound.
-- Switch: character attribute SlashLeftClickEnabled (default true; false = R2 / touch only).
-- v1.1 (Studio check of 1.0: the dash into an anchored T-Rex bot hit it but slid around its blocking hitboxes): for the
--   dash only, every BasePart of this character whose CollisionGroup is "HerreraBody" or "DinoHitbox" (the HRP and the own
--   blocking hitboxes) is put in "SlashDash" (SlashServer 1.2: collides like HerreraBody, not with dino hitboxes), so the
--   body passes through other dinos and still stands on the ground / tree tops; the groups are put back at the dash end
--   (and on death / removal). Only when the group is registered. Switch: character attribute SlashPassThroughEnabled
--   (default true; false = 1.0). Diagnostic: SlashPassThrough (parts moved, 0 when off).
-- v1.2 (Studio check of 1.1: still slid around the anchored T-Rex bot — its HumanoidRootPart (9.6 x 9.4 x 12, CanCollide)
--   is in "Default", like the ground, so a group cannot skip it): with the groups, NoCollisionConstraints (made on this
--   client only, parented to a folder "SlashNoCollide" under the HumanoidRootPart) pair every part moved to "SlashDash"
--   with every CanCollide part of each target dino that is not in "DinoHitbox", for the targets whose root is within
--   SlashDist x scale + NOCOLLIDE_MARGIN x scale; removed with the groups at the dash end. Diagnostic: SlashNoCollide
--   (constraints made).
-- v1.3 (MDA-146, Kepu 2026-10-31 phone screenshots: the grey "Slash" touch button stayed on the pachy after switching
--   from the Herrera): a character's scripts are destroyed before their own cleanup runs, so the CAS actions stayed bound.
--   At start, on every character of this player (any dino), the actions "DinoSlash" / "DinoSlashClick" are unbound before
--   anything else (then bound again below when this dino has SlashEnabled). ArenaTouch 1.7 also hides a leftover.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")

local VERSION = "1.3"
local ACTION = "DinoSlash"
local ACTION_CLICK = "DinoSlashClick"
local BIND = "DinoSlashDrive"
local RECOVER = 0.15
local NOCOLLIDE_MARGIN = 15 -- v1.2: studs (x scale) beyond the dash length for the no-collide targets
local DEFAULTS = {SlashEnabled = false, SlashDist = 12.5, SlashTime = 0.3, SlashDiveRange = 20, SlashDiveCone = 35,
	SlashReach = 2, SlashLeftClickEnabled = true}

local char = script.Parent
local hum = char:WaitForChild("Humanoid", 10)
local hrp = char:WaitForChild("HumanoidRootPart", 10)
local player = Players.LocalPlayer
if not (hum and hrp) or Players:GetPlayerFromCharacter(char) ~= player then return end
pcall(function() ContextActionService:UnbindAction(ACTION) end) -- v1.3: a leftover from the previous character
pcall(function() ContextActionService:UnbindAction(ACTION_CLICK) end)
if char:GetAttribute("SlashEnabled") ~= true then return end
char:SetAttribute("SlashTestVersion", VERSION)

local requestRemote = ReplicatedStorage:WaitForChild("DinoSlashRequest", 10)
local hitRemote = ReplicatedStorage:WaitForChild("DinoSlashHit", 10)

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

-- force
local att = Instance.new("Attachment")
att.Name = "SlashAttachment"
att.Parent = hrp
local lv = Instance.new("LinearVelocity")
lv.Name = "SlashVelocity"
lv.Attachment0 = att
lv.RelativeTo = Enum.ActuatorRelativeTo.World
lv.MaxForce = math.huge
lv.Enabled = false
lv.Parent = hrp

local state = "ready"
local stamp, phaseAt
local dash -- {kind, dir, speed, time, target, hit = {}}
local targets = {}
local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Include

local function setState(s)
	state = s
	show("SlashLocalState", s)
end
setState("ready")

local function isTarget(m)
	return m and m:IsA("Model") and m ~= char and m:GetAttribute("Bitable") == true
		and (m:GetAttribute("Species") ~= nil or m:GetAttribute("IsBot") == true) and m:GetAttribute("DummyState") ~= "ko"
end

local function findTargets()
	local list, folders = {}, {}
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("Folder") and d.Name == "Hitboxes" then
			local m = d.Parent
			if isTarget(m) then
				table.insert(folders, d)
				list[d] = m
			end
		end
	end
	overlap.FilterDescendantsInstances = folders
	targets = list
end

local function onTree()
	local cs = char:GetAttribute("ClimbLocalState")
	return cs == "climbing" or cs == "clinging" or cs == "top"
end

-- the dino below, inside the cone of the camera look, nearest the look
local function diveTarget()
	local cam = workspace.CurrentCamera
	if not cam then return nil end
	local look = cam.CFrame.LookVector
	local range = get("SlashDiveRange") * char:GetScale()
	local cone = math.rad(get("SlashDiveCone"))
	local best, bestAng
	for _, m in pairs(targets) do
		local r = m:FindFirstChild("HumanoidRootPart")
		if r and m.Parent then
			local d = r.Position - hrp.Position
			if d.Magnitude <= range and d.Y < 0 and d.Magnitude > 1e-3 then
				local ang = math.acos(math.clamp(d.Unit:Dot(look), -1, 1))
				if ang <= cone and (not bestAng or ang < bestAng) then best, bestAng = m, ang end
			end
		end
	end
	return best
end

-- v1.1: pass through other dinos during the dash
local PhysicsService = game:GetService("PhysicsService")
local savedGroups = nil -- {[part] = group}
local function passThrough(on)
	if on then
		if savedGroups or char:GetAttribute("SlashPassThroughEnabled") == false then return end
		local okReg, reg = pcall(function() return PhysicsService:IsCollisionGroupRegistered("SlashDash") end)
		if not (okReg and reg) then show("SlashPassThrough", 0) return end
		savedGroups = {}
		local n = 0
		for _, p in ipairs(char:GetDescendants()) do
			if p:IsA("BasePart") and (p.CollisionGroup == "HerreraBody" or p.CollisionGroup == "DinoHitbox") then
				savedGroups[p] = p.CollisionGroup
				p.CollisionGroup = "SlashDash"
				n += 1
			end
		end
		show("SlashPassThrough", n)
		-- v1.2: the targets' own colliding parts outside "DinoHitbox" (e.g. a bot's root box in "Default")
		local folder = Instance.new("Folder")
		folder.Name = "SlashNoCollide"
		local reach = (get("SlashDist") + NOCOLLIDE_MARGIN) * char:GetScale()
		local mine = {}
		for p in pairs(savedGroups) do table.insert(mine, p) end
		local made = 0
		for _, m in pairs(targets) do
			local r = m:FindFirstChild("HumanoidRootPart")
			if r and m.Parent and (r.Position - hrp.Position).Magnitude <= reach + r.Size.Magnitude then
				for _, q in ipairs(m:GetDescendants()) do
					if q:IsA("BasePart") and q.CanCollide and q.CollisionGroup ~= "DinoHitbox" then
						for _, p in ipairs(mine) do
							local nc = Instance.new("NoCollisionConstraint")
							nc.Part0, nc.Part1 = p, q
							nc.Parent = folder
							made += 1
						end
					end
				end
			end
		end
		folder.Parent = hrp
		savedGroups[folder] = false -- removed below
		show("SlashNoCollide", made)
	elseif savedGroups then
		for p, g in pairs(savedGroups) do
			if g == false then
				p:Destroy() -- v1.2: the no-collide folder
			elseif p.Parent then
				p.CollisionGroup = g
			end
		end
		savedGroups = nil
	end
end

local function stopDash()
	lv.Enabled = false
	dash = nil
	passThrough(false) -- v1.1
end

local function finishLocal(nextState)
	stopDash()
	show("SlashLocalEndAt", workspace:GetServerTimeNow())
	setState(nextState)
	phaseAt = os.clock()
end

local function tryPress(source)
	local result
	local t = workspace:GetServerTimeNow()
	if get("SlashEnabled") ~= true then
		result = "disabled"
	elseif hum.Health <= 0 then
		result = "dead"
	elseif (tonumber(char:GetAttribute("StunnedUntil")) or 0) > t then
		result = "stunned"
	elseif char:GetAttribute("PinHeld") == true then
		result = "pinned"
	elseif state ~= "ready" then
		result = "busy"
	elseif (tonumber(char:GetAttribute("SlashChargesNow")) or 0) < 1 then
		result = "empty"
	end
	show("SlashLastInput", source)
	if result then
		show("SlashInputResult", result)
		return
	end
	findTargets()
	local scale = char:GetScale()
	local L = get("SlashDist") * scale
	local T = math.max(0.05, get("SlashTime"))
	local speed = L / T
	local look = hrp.CFrame.LookVector
	local dir = Vector3.new(look.X, 0, look.Z)
	dir = dir.Magnitude > 1e-3 and dir.Unit or Vector3.new(0, 0, -1)
	local kind = onTree() and "dive" or "ground"
	local target = kind == "dive" and diveTarget() or nil
	local localKind = kind == "dive" and (target and "dive" or "leap") or "ground"
	local time = T
	if target then
		local r = target:FindFirstChild("HumanoidRootPart")
		time = math.max(T, (r.Position - hrp.Position).Magnitude / speed)
	end
	stamp = t
	char:SetAttribute("SlashPredictedAt", stamp)
	dash = {kind = localKind, dir = dir, speed = speed, time = time, target = target, hit = {}}
	show("SlashLocalKind", localKind)
	show("SlashLocalTarget", target and target.Name or "")
	if requestRemote then requestRemote:FireServer(stamp, kind, target) end
	show("SlashInputResult", "sent")
	passThrough(true) -- v1.1
	setState("dash")
	phaseAt = os.clock()
end

-- a denied request stops the local dash
char:GetAttributeChangedSignal("SlashServerResultAt"):Connect(function()
	local r = char:GetAttribute("SlashServerResult")
	if r ~= "ok" and state == "dash" and (os.clock() - (phaseAt or 0)) < 1 then
		show("SlashInputResult", "denied:" .. tostring(r))
		finishLocal("ready")
	end
end)

local function drive()
	if state == "ready" then return end
	local t = os.clock() - (phaseAt or os.clock())
	if hum.Health <= 0 then
		finishLocal("ready")
		return
	end
	if state == "recover" then
		if t >= RECOVER then setState("ready") end
		return
	end
	-- dash
	if not dash or t >= dash.time then
		finishLocal("recover")
		return
	end
	if dash.kind == "dive" and dash.target and dash.target.Parent then
		local r = dash.target:FindFirstChild("HumanoidRootPart")
		local d = r and (r.Position - hrp.Position)
		if d and d.Magnitude > 1 then
			lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
			lv.VectorVelocity = d.Unit * dash.speed
		else
			lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
			lv.VectorVelocity = Vector3.zero
		end
	else
		lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
		lv.PrimaryTangentAxis = Vector3.xAxis
		lv.SecondaryTangentAxis = Vector3.zAxis
		lv.PlaneVelocity = Vector2.new(dash.dir.X * dash.speed, dash.dir.Z * dash.speed)
	end
	lv.Enabled = true
	-- contacts
	local cf, size = char:GetBoundingBox()
	local grow = get("SlashReach") * char:GetScale()
	local hits = workspace:GetPartBoundsInBox(cf, size + Vector3.new(grow, grow, grow) * 2, overlap)
	for _, p in ipairs(hits) do
		local m = targets[p.Parent]
		if m and m.Parent and not dash.hit[m] and m:GetAttribute("DummyState") ~= "ko" then
			dash.hit[m] = true
			show("SlashContact", m.Name)
			show("SlashContacts", (char:GetAttribute("SlashContacts") or 0) + 1)
			if hitRemote then hitRemote:FireServer(stamp, m) end
		end
	end
end
RunService:BindToRenderStep(BIND, Enum.RenderPriority.Character.Value + 7, drive)

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
	local on = get("SlashEnabled") == true
	if on and not bound then
		ContextActionService:BindActionAtPriority(ACTION, onAction, true, Enum.ContextActionPriority.High.Value,
			Enum.KeyCode.ButtonR2)
		ContextActionService:SetTitle(ACTION, "Slash")
		bound = true
	elseif not on and bound then
		ContextActionService:UnbindAction(ACTION)
		bound = false
	end
	local clickOn = on and get("SlashLeftClickEnabled") ~= false and UserInputService.MouseEnabled
	if clickOn and not clickBound then
		ContextActionService:BindActionAtPriority(ACTION_CLICK, onClick, false, Enum.ContextActionPriority.High.Value,
			Enum.UserInputType.MouseButton1)
		clickBound = true
	elseif not clickOn and clickBound then
		ContextActionService:UnbindAction(ACTION_CLICK)
		clickBound = false
	end
	show("SlashClickBound", clickBound)
end
char:GetAttributeChangedSignal("SlashEnabled"):Connect(applyBinding)
char:GetAttributeChangedSignal("SlashLeftClickEnabled"):Connect(applyBinding)
applyBinding()

local function cleanup()
	if bound then ContextActionService:UnbindAction(ACTION) end
	if clickBound then ContextActionService:UnbindAction(ACTION_CLICK) end
	RunService:UnbindFromRenderStep(BIND)
	stopDash()
end
hum.Died:Connect(cleanup)
char.AncestryChanged:Connect(function(_, parent)
	if not parent then cleanup() end
end)
