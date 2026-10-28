-- ArenaTouch v1.0 (Mecha Dino Arena) — this game's own touch buttons (LocalScript, touch devices only).
-- MDA-7, plan docs/plans/ARENAHUD_v1.0.md Task 2, mockup docs/mockups/mobile_hud_options.html option A ("Stack + thumb
--   arc"; Kepu: no shoulder button on mobile, no T-Rex jump).
-- Off when UserInputService.TouchEnabled is false (ArenaTouchState "off"): PC / gamepad input is unchanged.
-- How a press reaches the move: ContextActionService:CallFunction is not allowed for game scripts (measured in Play:
--   "lacking capability RobloxScript"), so the moves keep their own Roblox touch buttons (ContextActionGui, made by
--   ContextActionService for BiteTest / SprintTest / RamTest / PounceTest) and this script lays each one, invisible
--   (image + title + icon transparency 1), exactly over its styled button every frame (CAS:GetButton(action) ->
--   Position / Size from the styled button's AbsolutePosition / AbsoluteSize). The touch lands on Roblox's button, so
--   the move script gets a real press and release; the styled buttons only draw (Frames, not buttons) and sit below
--   (ScreenGui DisplayOrder -1). The shoulder-swap touch button ("DinoShoulderSwap") is kept Visible = false (Kepu: no
--   shoulder button on mobile). Roblox's TouchGui JumpButton is kept Visible = false.
--   Diagnostics ArenaTouchCASMode = "overlay" / "noGui", ArenaTouchJumpHidden = true or "notFound".
-- Buttons (circles, AnchorPoint (1, 1), size and position in fractions of the screen width / height like the mockup):
--   BITE  big yellow, right 5%, bottom 10%, 13.5% of the width   over CAS "DinoBiteTest"
--   RUN   right 21%, bottom 8%, 9.5% ("hold")                     over CAS "DinoRunTest"
--   RAM   (T-Rex) right 19.5%, bottom 33%, 9.5%                   over CAS "DinoRam"; shown only while RamEnabled and
--         RamLatchGate ~= "closed" (RamTest 1.1: only while a raptor is latched on)
--   POUNCE (raptor) same place                                   over CAS "DinoPounce"; shown while PounceEnabled
--   LEAP  (raptor) right 7%, bottom 43%, 9.5%: this script's own button -> Humanoid.Jump = true for LEAP_HOLD s
--         (JumpTest 1.0 reads Humanoid.Jump when the JumpAction input is not used); shown while JumpEnabled
--   A styled button whose CAS button does not exist (action not bound) is hidden. Press feedback (scale 0.92) and
--   ArenaTouchLastPress come from the CAS button's InputBegan / InputEnded.
--   RAM / POUNCE / LEAP are dimmed (0.5) while RamTestState / PounceTestState / JumpTestState is not "ready".
-- Diagnostics (character attributes, this client): ArenaTouchVersion, ArenaTouchState ("off" / "on"),
--   ArenaTouchLastPress (button name), ArenaTouchCASMode, ArenaTouchJumpHidden.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")

local VERSION = "1.0"
local LEAP_HOLD = 0.15
local PANEL = Color3.fromRGB(20, 20, 26)
local YELLOW, YELLOW_TEXT = Color3.fromRGB(255, 200, 50), Color3.fromRGB(30, 26, 10)

local char = script.Parent
local player = Players.LocalPlayer
local hum = char:WaitForChild("Humanoid", 10)
char:SetAttribute("ArenaTouchVersion", VERSION)
if not UserInputService.TouchEnabled then
	char:SetAttribute("ArenaTouchState", "off")
	return
end
char:SetAttribute("ArenaTouchState", "on")
local pg = player:WaitForChild("PlayerGui")

-- Roblox's jump button stays hidden (the raptor uses LEAP; the T-Rex can't jump, ArenaRules 1.0)
local function keepOff(inst, prop, value, attr)
	inst[prop] = value
	inst:GetPropertyChangedSignal(prop):Connect(function()
		if inst[prop] ~= value then inst[prop] = value end
	end)
	char:SetAttribute(attr, true)
end
char:SetAttribute("ArenaTouchJumpHidden", "notFound")
local function watchJump(d)
	if d.Name == "JumpButton" and d:IsA("GuiObject") then keepOff(d, "Visible", false, "ArenaTouchJumpHidden") end
end
for _, d in ipairs(pg:GetDescendants()) do watchJump(d) end
pg.DescendantAdded:Connect(watchJump)

local old = pg:FindFirstChild("ArenaTouch")
if old then old:Destroy() end
local gui = Instance.new("ScreenGui")
gui.Name = "ArenaTouch"
gui.ResetOnSpawn = true
gui.DisplayOrder = -1 -- below ContextActionGui (0): touches reach the invisible CAS buttons

local function button(name, label, sub, right, bottom, size, big, own)
	local b = Instance.new(own and "TextButton" or "Frame") -- only LEAP is this script's own button
	b.Name = name
	b.AnchorPoint = Vector2.new(1, 1)
	b.Position = UDim2.new(1 - right, 0, 1 - bottom, 0)
	b.Size = UDim2.fromScale(size, size)
	b.SizeConstraint = Enum.SizeConstraint.RelativeXX
	b.BackgroundColor3 = big and YELLOW or PANEL
	b.BackgroundTransparency = big and 0.08 or 0.4
	if own then
		b.AutoButtonColor = false
		b.Text = ""
	end
	b.Parent = gui
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0.5, 0)
	c.Parent = b
	local s = Instance.new("UIStroke")
	s.Color, s.Transparency, s.Thickness = Color3.new(1, 1, 1), big and 0 or 0.4, 2
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = b
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, sub and 0.62 or 1)
	l.Font = Enum.Font.FredokaOne
	l.Text = label
	l.TextScaled = true
	l.TextColor3 = big and YELLOW_TEXT or Color3.new(1, 1, 1)
	l.Parent = b
	local tc = Instance.new("UITextSizeConstraint")
	tc.MaxTextSize = big and 26 or 18
	tc.Parent = l
	local lp = Instance.new("UIPadding")
	lp.PaddingLeft, lp.PaddingRight = UDim.new(0.12, 0), UDim.new(0.12, 0)
	lp.PaddingTop = UDim.new(sub and 0.28 or 0.3, 0)
	lp.PaddingBottom = UDim.new(sub and 0 or 0.3, 0)
	lp.Parent = l
	if sub then
		local sl = l:Clone()
		sl.Text = sub
		sl.Position = UDim2.fromScale(0, 0.58)
		sl.Size = UDim2.fromScale(1, 0.3)
		sl.TextTransparency = 0.25
		sl:FindFirstChildOfClass("UITextSizeConstraint").MaxTextSize = 12
		sl:FindFirstChildOfClass("UIPadding").PaddingTop = UDim.new(0, 0)
		sl.Parent = b
	end
	local scale = Instance.new("UIScale")
	scale.Parent = b
	return b, l, scale
end

local bite, _, biteScale = button("Bite", "BITE", nil, 0.05, 0.10, 0.135, true)
local run, _, runScale = button("Run", "RUN", "hold", 0.21, 0.08, 0.095)
local ram, ramLabel, ramScale = button("Ram", "RAM", nil, 0.195, 0.33, 0.095)
local pounce, pounceLabel, pounceScale = button("Pounce", "POUNCE", nil, 0.195, 0.33, 0.095)
local leap, leapLabel, leapScale = button("Leap", "LEAP", nil, 0.07, 0.43, 0.095, false, true)
leap.InputBegan:Connect(function(input)
	if input.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
	leapScale.Scale = 0.92
	char:SetAttribute("ArenaTouchLastPress", "Leap")
	if not hum then return end
	hum.Jump = true
	task.delay(LEAP_HOLD, function() if hum.Parent then hum.Jump = false end end)
end)
leap.InputEnded:Connect(function() leapScale.Scale = 1 end)

-- overlay: Roblox's CAS button for each move, invisible, laid over its styled button every frame
local OVERLAY = {
	{action = "DinoBiteTest", vis = bite, scale = biteScale, name = "Bite"},
	{action = "DinoRunTest", vis = run, scale = runScale, name = "Run"},
	{action = "DinoRam", vis = ram, scale = ramScale, name = "Ram"},
	{action = "DinoPounce", vis = pounce, scale = pounceScale, name = "Pounce"},
}
local wanted = {Bite = true, Run = true, Ram = false, Pounce = false} -- set by refresh()
local hooked = setmetatable({}, {__mode = "k"})
local function hook(btn, o)
	if hooked[btn] then return end
	hooked[btn] = true
	btn.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.Touch and input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
		o.scale.Scale = 0.92
		char:SetAttribute("ArenaTouchLastPress", o.name)
	end)
	btn.InputEnded:Connect(function() o.scale.Scale = 1 end)
end
local function hideCas(btn)
	btn.ImageTransparency = 1
	for _, d in ipairs(btn:GetDescendants()) do
		if d:IsA("TextLabel") then d.TextTransparency = 1 d.TextStrokeTransparency = 1
		elseif d:IsA("ImageLabel") then d.ImageTransparency = 1 end
	end
end
local function getButton(action)
	-- only for bound actions: GetButton on an unbound action prints "ContextActionService could not find the function
	-- passed in" every call (measured in Play: Pounce on the T-Rex, Ram while nothing is latched)
	local okInfo, info = pcall(function() return ContextActionService:GetBoundActionInfo(action) end)
	if not okInfo or type(info) ~= "table" or next(info) == nil then return nil end
	local ok, btn = pcall(function() return ContextActionService:GetButton(action) end)
	return ok and btn or nil
end
RunService.RenderStepped:Connect(function()
	local cg = pg:FindFirstChild("ContextActionGui")
	if char:GetAttribute("ArenaTouchCASMode") ~= (cg and "overlay" or "noGui") then
		char:SetAttribute("ArenaTouchCASMode", cg and "overlay" or "noGui")
	end
	for _, o in ipairs(OVERLAY) do
		local btn = getButton(o.action)
		o.vis.Visible = wanted[o.name] and btn ~= nil
		if btn and btn.Parent then
			hideCas(btn)
			hook(btn, o)
			btn.Visible = o.vis.Visible
			local parentPos = btn.Parent:IsA("GuiObject") and btn.Parent.AbsolutePosition or Vector2.zero
			btn.AnchorPoint = Vector2.zero
			btn.Position = UDim2.fromOffset(o.vis.AbsolutePosition.X - parentPos.X, o.vis.AbsolutePosition.Y - parentPos.Y)
			btn.Size = UDim2.fromOffset(o.vis.AbsoluteSize.X, o.vis.AbsoluteSize.Y)
		end
	end
	local sb = getButton("DinoShoulderSwap")
	if sb and sb.Visible then sb.Visible = false end
end)

local function dim(b, l, stateAttr)
	local ready = char:GetAttribute(stateAttr) == "ready"
	b.BackgroundTransparency = ready and 0.4 or 0.7
	l.TextTransparency = ready and 0 or 0.5
end
local function refresh()
	wanted.Ram = char:GetAttribute("RamEnabled") == true and char:GetAttribute("RamLatchGate") ~= nil
		and char:GetAttribute("RamLatchGate") ~= "closed"
	wanted.Pounce = char:GetAttribute("PounceEnabled") == true
	leap.Visible = char:GetAttribute("JumpEnabled") == true
	dim(ram, ramLabel, "RamTestState")
	dim(pounce, pounceLabel, "PounceTestState")
	dim(leap, leapLabel, "JumpTestState")
end
local WATCH = {RamEnabled = true, RamLatchGate = true, PounceEnabled = true, JumpEnabled = true, RamTestState = true,
	PounceTestState = true, JumpTestState = true}
char.AttributeChanged:Connect(function(name)
	if WATCH[name] then refresh() end
end)
refresh()
gui.Parent = pg
