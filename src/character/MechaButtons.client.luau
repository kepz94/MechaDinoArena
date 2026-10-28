-- MechaButtons v1.0 (Mecha Dino Arena) — the 2 mecha loadout buttons (touch), PC keys 1 / 2, and the Thrusters dash on the
-- owner's client. MDA-28, plan docs/plans/MECHA_THRUSTERS_v1.0.md Task 6, mockup docs/mockups/mecha_thrusters_options.html
-- option A "Thumb arc" (Kepu 2026-10-28).
-- Slots: player attributes SkillSlot1 / SkillSlot2 (SkillServer 1.1; path id or ""). A press on a slot holding "thrusters"
--   fires ReplicatedStorage.DinoDashRequest:FireServer(server time) (MechaServer 1.0 gates it). An empty slot does nothing.
-- Touch (UserInputService.TouchEnabled): ScreenGui "MechaButtons" (DisplayOrder 5), buttons Slot_1 / Slot_2, AnchorPoint
--   (1, 1), position and size in fractions of the screen like ArenaTouch 1.2:
--     AutoRun true  (RUN hidden):  Slot_1 right 21%, bottom 8%;   Slot_2 right 32.5%, bottom 18%; 9.5% of the width
--     AutoRun false (RUN shown):   Slot_1 right 33%, bottom 8%;   Slot_2 right 33%, bottom 28%;   9.5% of the width
--   Look: rounded square (corner 22%), panel (20, 20, 26) at 0.3, 2.5 px Engineer-orange (255, 155, 46) stroke.
--   Full slot: "DASH", charge pips top right (DashChargesLeft of DashCharges), a dark fill from the bottom showing the time
--   to the next charge (DashNextChargeAt, DashRecharge), key hint "1" / "2"; dimmed (0.5) while DashEnabled is not true.
--   Empty slot: white stroke at 0.5, "+" and "slot n".
-- PC / no touch: no buttons; keys 1 and 2 press slot 1 and 2 (when the key is not used by a text box). Test hook: script
--   attribute MechaButtonsForceTouch (default nil / false) = true draws the touch buttons without touch (layout checks).
-- Dash physics (this client owns the character): on a new DashStartedAt, a LinearVelocity on the HumanoidRootPart
--   (VelocityConstraintMode Plane, world X / Z) at DashDistance / DashTime studs/s along the flat look direction, for
--   DashTime s; with DashHop > 0 the root also gets an upward speed sqrt(2 x gravity x DashHop) and the Humanoid is put in
--   Freefall. At the end the root's horizontal speed is set to 0 (keeps its vertical speed), so the dino stops where the
--   dash ends instead of sliding on.
-- Diagnostics (character attributes, this client): MechaButtonsVersion, MechaButtonsState ("on" touch / "keys"),
--   MechaButtonsLastPress ("slot1:thrusters" / "slot2:empty" ...), MechaDashLocal ("idle" / "dashing"), MechaDashLocalCount.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local VERSION = "1.0"
local PANEL = Color3.fromRGB(20, 20, 26)
local ORANGE = Color3.fromRGB(255, 155, 46)
local SPOTS = {
	[true] = {{0.21, 0.08}, {0.325, 0.18}},  -- AutoRun on: RUN's spot + the arc
	[false] = {{0.33, 0.08}, {0.33, 0.28}},  -- RUN shown: inner column
}
local SIZE = 0.095

local char = script.Parent
local player = Players.LocalPlayer
local hum = char:WaitForChild("Humanoid", 10)
local hrp = char:WaitForChild("HumanoidRootPart", 10)
char:SetAttribute("MechaButtonsVersion", VERSION)
char:SetAttribute("MechaDashLocal", "idle")
local remote = ReplicatedStorage:WaitForChild("DinoDashRequest", 20)

local function slotPart(n)
	local v = player:GetAttribute("SkillSlot" .. n)
	return (type(v) == "string" and v ~= "") and v or nil
end

local function press(n)
	local id = slotPart(n)
	char:SetAttribute("MechaButtonsLastPress", ("slot%d:%s"):format(n, id or "empty"))
	if id == "thrusters" and remote then remote:FireServer(workspace:GetServerTimeNow()) end
end

-- dash physics --------------------------------------------------------------------------------------------------------
local lastDash = char:GetAttribute("DashStartedAt")
local function dash()
	if not (hrp and hum and hum.Health > 0) then return end
	local dist = tonumber(char:GetAttribute("DashDistance")) or 0
	local t = tonumber(char:GetAttribute("DashTime")) or 0.35
	local hop = tonumber(char:GetAttribute("DashHop")) or 0
	local look = Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z)
	if dist <= 0 or t <= 0 or look.Magnitude < 1e-3 then return end
	local v = look.Unit * (dist / t)
	local at = Instance.new("Attachment")
	at.Name = "MechaDashAt"
	at.Parent = hrp
	local lv = Instance.new("LinearVelocity")
	lv.Name = "MechaDash"
	lv.Attachment0 = at
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	lv.PrimaryTangentAxis = Vector3.xAxis
	lv.SecondaryTangentAxis = Vector3.zAxis
	lv.PlaneVelocity = Vector2.new(v.X, v.Z)
	lv.MaxForce = math.huge
	lv.Parent = hrp
	if hop > 0 then
		hum:ChangeState(Enum.HumanoidStateType.Freefall)
		local cur = hrp.AssemblyLinearVelocity
		hrp.AssemblyLinearVelocity = Vector3.new(cur.X, math.sqrt(2 * workspace.Gravity * hop), cur.Z)
	end
	char:SetAttribute("MechaDashLocal", "dashing")
	char:SetAttribute("MechaDashLocalCount", (char:GetAttribute("MechaDashLocalCount") or 0) + 1)
	task.delay(t, function()
		lv:Destroy()
		at:Destroy()
		-- stop the dash speed (measured in Play: without this the dino slid ~60 studs more after a 50-stud dash)
		if hrp.Parent then
			local cur = hrp.AssemblyLinearVelocity
			hrp.AssemblyLinearVelocity = Vector3.new(0, cur.Y, 0)
		end
		if char.Parent then char:SetAttribute("MechaDashLocal", "idle") end
	end)
end
char:GetAttributeChangedSignal("DashStartedAt"):Connect(function()
	local s = char:GetAttribute("DashStartedAt")
	if s == lastDash then return end
	lastDash = s
	dash()
end)

-- PC keys ------------------------------------------------------------------------------------------------------------
UserInputService.InputBegan:Connect(function(input, processed)
	if processed or UserInputService:GetFocusedTextBox() then return end
	if input.KeyCode == Enum.KeyCode.One then press(1)
	elseif input.KeyCode == Enum.KeyCode.Two then press(2) end
end)

-- test hook: script attribute MechaButtonsForceTouch = true draws the touch buttons on PC too (Studio layout checks)
if not UserInputService.TouchEnabled and script:GetAttribute("MechaButtonsForceTouch") ~= true then
	char:SetAttribute("MechaButtonsState", "keys")
	return
end
char:SetAttribute("MechaButtonsState", "on")

-- touch buttons ------------------------------------------------------------------------------------------------------
local pg = player:WaitForChild("PlayerGui")
local old = pg:FindFirstChild("MechaButtons")
if old then old:Destroy() end
local gui = Instance.new("ScreenGui")
gui.Name = "MechaButtons"
gui.ResetOnSpawn = true
gui.DisplayOrder = 5

local function label(parent, text, pos, size, maxSize, color)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Position, l.Size = pos, size
	l.Font = Enum.Font.FredokaOne
	l.Text = text
	l.TextScaled = true
	l.TextColor3 = color or Color3.new(1, 1, 1)
	l.Parent = parent
	local c = Instance.new("UITextSizeConstraint")
	c.MaxTextSize = maxSize
	c.Parent = l
	return l
end

local slots = {}
for n = 1, 2 do
	local b = Instance.new("TextButton")
	b.Name = "Slot_" .. n
	b.AnchorPoint = Vector2.new(1, 1)
	b.Size = UDim2.fromScale(SIZE, SIZE)
	b.SizeConstraint = Enum.SizeConstraint.RelativeXX
	b.BackgroundColor3 = PANEL
	b.BackgroundTransparency = 0.3
	b.AutoButtonColor = false
	b.Text = ""
	b.ClipsDescendants = true
	b.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.22, 0)
	corner.Parent = b
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2.5
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = b
	local cd = Instance.new("Frame")
	cd.Name = "Cooldown"
	cd.AnchorPoint = Vector2.new(0, 1)
	cd.Position = UDim2.fromScale(0, 1)
	cd.Size = UDim2.fromScale(1, 0)
	cd.BackgroundColor3 = Color3.new(0, 0, 0)
	cd.BackgroundTransparency = 0.45
	cd.BorderSizePixel = 0
	cd.Parent = b
	local cdCorner = Instance.new("UICorner") -- ClipsDescendants does not follow the button's rounded corners
	cdCorner.CornerRadius = UDim.new(0.22, 0)
	cdCorner.Parent = cd
	local main = label(b, "DASH", UDim2.fromScale(0.1, 0.3), UDim2.fromScale(0.8, 0.4), 18)
	main.Name = "Main"
	local sub = label(b, "", UDim2.fromScale(0.1, 0.68), UDim2.fromScale(0.8, 0.22), 11)
	sub.Name = "Sub"
	sub.TextTransparency = 0.25
	local key = label(b, tostring(n), UDim2.fromScale(0.08, 0.04), UDim2.fromScale(0.22, 0.22), 10,
		Color3.fromRGB(154, 160, 173))
	key.Name = "Key"
	local pips = Instance.new("Frame")
	pips.Name = "Pips"
	pips.BackgroundTransparency = 1
	pips.AnchorPoint = Vector2.new(1, 0)
	pips.Position = UDim2.fromScale(0.92, 0.07)
	pips.Size = UDim2.fromScale(0.4, 0.12)
	pips.Parent = b
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Right
	list.Padding = UDim.new(0.08, 0)
	list.Parent = pips
	local pipFrames = {}
	for i = 1, 2 do
		local p = Instance.new("Frame")
		p.Name = "Pip_" .. i
		p.Size = UDim2.fromScale(1, 1) -- a circle as tall as the pip row
		p.SizeConstraint = Enum.SizeConstraint.RelativeYY
		p.BorderSizePixel = 0
		p.Parent = pips
		local pc = Instance.new("UICorner")
		pc.CornerRadius = UDim.new(0.5, 0)
		pc.Parent = p
		pipFrames[i] = p
	end
	local scale = Instance.new("UIScale")
	scale.Parent = b
	b.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
		scale.Scale = 0.92
		press(n)
	end)
	b.InputEnded:Connect(function() scale.Scale = 1 end)
	slots[n] = {b = b, stroke = stroke, cd = cd, main = main, sub = sub, pips = pipFrames}
end

local function layout()
	local spots = SPOTS[char:GetAttribute("AutoRun") == true]
	for n, s in ipairs(slots) do
		s.b.Position = UDim2.new(1 - spots[n][1], 0, 1 - spots[n][2], 0)
	end
end

local function draw()
	local ready = char:GetAttribute("DashEnabled") == true
	local max = math.clamp(tonumber(char:GetAttribute("DashCharges")) or 0, 0, 2)
	local left = tonumber(char:GetAttribute("DashChargesLeft")) or 0
	for n, s in ipairs(slots) do
		local id = slotPart(n)
		if id then
			s.stroke.Color, s.stroke.Transparency = ORANGE, ready and 0 or 0.5
			s.main.Text = id == "thrusters" and "DASH" or string.upper(id)
			s.main.TextTransparency = ready and 0 or 0.5
			s.sub.Text = ""
			for i, p in ipairs(s.pips) do
				p.Visible = i <= max
				p.BackgroundColor3 = i <= left and ORANGE or Color3.fromRGB(85, 85, 85)
			end
		else
			s.stroke.Color, s.stroke.Transparency = Color3.new(1, 1, 1), 0.5
			s.main.Text, s.main.TextTransparency = "+", 0.4
			s.sub.Text = "slot " .. n
			for _, p in ipairs(s.pips) do p.Visible = false end
			s.cd.Size = UDim2.fromScale(1, 0)
		end
	end
end

RunService.RenderStepped:Connect(function()
	local nextAt = tonumber(char:GetAttribute("DashNextChargeAt")) or 0
	local rc = tonumber(char:GetAttribute("DashRecharge")) or 8
	local frac = 0
	if nextAt > 0 and rc > 0 then frac = math.clamp((nextAt - workspace:GetServerTimeNow()) / rc, 0, 1) end
	for n, s in ipairs(slots) do
		s.cd.Size = UDim2.fromScale(1, slotPart(n) == "thrusters" and frac or 0)
	end
end)

local WATCH = {DashEnabled = true, DashCharges = true, DashChargesLeft = true, AutoRun = true}
char.AttributeChanged:Connect(function(name)
	if name == "AutoRun" then layout() end
	if WATCH[name] then draw() end
end)
player.AttributeChanged:Connect(function(name)
	if name == "SkillSlot1" or name == "SkillSlot2" then draw() end
end)
layout()
draw()
gui.Parent = pg
