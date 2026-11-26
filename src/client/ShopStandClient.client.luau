-- ShopStandClient v1.1 (Mecha Dino Arena) — the OPEN SHOP button at the island shop stand (LocalScript, StarterPlayerScripts).
-- Kepu 2026-11-25 13:24 picks on mockup docs/mockups/shop_stand_v0.1.html: "B" (market stall), "open shop", "Right of WORLDWIDE".
-- Near: Workspace.ShopStand (ShopStandServer 1.0) exists, the player is out of the menu (InMenu ~= true), alive, and the own
--   HumanoidRootPart is within the stand's ShopStandRange (22) studs (flat) of its ShopStandFront point. Published as player
--   attribute ShopStandNear (ShopScreen 1.3 only opens from the stand while it is true).
-- Button (ScreenGui "ShopStandButton", DisplayOrder 9, DeviceSafeInsets): yellow "OPEN SHOP" (Silkscreen Bold, FontSwap keep),
--   ShopStandBtnW x ShopStandBtnH (150 x 46), corner 10, dark ink, a darker yellow 3 px lip under it. Shown while near and the Shop
--   is closed. Spot: on a touch HUD (PlayerGui.ArenaTouch has a visible button whose text is "JUMP"), centred over that button,
--   ShopStandBtnGap (10) px above it; otherwise bottom-right, AnchorPoint (1, 1) at (1, -ShopStandBtnRight, 1, -ShopStandBtnUp)
--   (24, 150). Tap / click -> ShopScreen's BindableFunction Open:Invoke("stand").
-- While the Shop is open from the stand (player ShopOpen == true and ShopOpenFrom == "stand") the own HumanoidRootPart is anchored
--   on this client so the dino stands still; it is let go when the Shop closes (or the character changes).
-- Switches (script attributes): ShopStandClientEnabled (true, read per frame; false = no button, never near).
-- Diagnostics: ShopStandClientVersion, player ShopStandNear, script ShopStandOpens (count), ShopStandBtnSpot ("jump" / "corner").
-- v1.1 (Kepu 2026-11-25 22:24 "the open shop button should be on the shop once you approach it"; pick on mockup
--   docs/mockups/shop_stand_v0.2: "3: Prompt (E / tap)"): new switch ShopStandBtnMode ("prompt", the default; "screen" = the v1.0
--   screen button above, unchanged). "prompt": while near and the Shop is closed (same test as v1.0), a ProximityPrompt made on
--   this client (Style Custom, ActionText OPEN SHOP, HoldDuration 0, no line of sight) sits on Attachment "ShopStandPromptAt"
--   ShopStandPromptUp (7) studs above the stand's CounterTop. Its look is a BillboardGui "ShopStandPrompt" in PlayerGui on that
--   attachment: dark pill ShopStandPromptW x ShopStandPromptH (190 x 52) px, yellow outline, a yellow round key cap and yellow
--   "OPEN SHOP" (Silkscreen Bold). Key cap: keyboard ShopStandPromptKey ("E"), gamepad ShopStandPromptPad ("ButtonX", shown "X"),
--   touch "TAP". Opens the Shop (Open:Invoke("stand"), as the v1.0 button) on: the prompt's Triggered, a tap / click on the pill,
--   or the key / pad button through ContextActionService at priority High + 2 (sunk), bound only while the prompt shows, so it
--   wins over RamTest 1.3's E (High, T-Rex) and Pounce's ButtonX next to the stall. 0.4 s debounce.
--   Diagnostics: ShopStandBtnSpot "prompt", ShopStandPromptShown (bool), ShopStandPromptInput ("Keyboard" / "Gamepad" / "Touch").

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local VERSION = "1.1"
script:SetAttribute("ShopStandClientVersion", VERSION)
for k, v in pairs({ShopStandClientEnabled = true, ShopStandBtnW = 150, ShopStandBtnH = 46, ShopStandBtnGap = 10,
	ShopStandBtnRight = 24, ShopStandBtnUp = 150, ShopStandOpens = 0,
	ShopStandBtnMode = "prompt", ShopStandPromptKey = "E", ShopStandPromptPad = "ButtonX", ShopStandPromptUp = 7, -- v1.1
	ShopStandPromptW = 190, ShopStandPromptH = 52}) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, v) end
end
local function A(k, d) return tonumber(script:GetAttribute(k)) or d end

local player = Players.LocalPlayer
local pg = player:WaitForChild("PlayerGui")
local YELLOW, LIP, INK = Color3.fromRGB(255, 200, 50), Color3.fromRGB(184, 138, 16), Color3.fromRGB(26, 19, 0)

local old = pg:FindFirstChild("ShopStandButton")
if old then old:Destroy() end
local gui = Instance.new("ScreenGui")
gui.Name = "ShopStandButton"
gui.DisplayOrder = 9
gui.ResetOnSpawn = false
gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
gui.Enabled = false
gui.Parent = pg
local holder = Instance.new("Frame") -- the lip sits behind the button (children always draw over their parent)
holder.Name = "Holder"
holder.BackgroundTransparency = 1
holder.Parent = gui
local btn = Instance.new("TextButton")
btn.Name = "Open"
btn.Size = UDim2.fromScale(1, 1)
btn.ZIndex = 2
btn.AutoButtonColor = true
btn.BackgroundColor3 = YELLOW
btn.TextColor3 = INK
btn.FontFace = Font.new("rbxassetid://12187371840", Enum.FontWeight.Bold) -- Silkscreen Bold
btn:SetAttribute("FontSwap", "keep")
btn.TextSize = 16
btn.Text = "OPEN SHOP"
btn.Parent = holder
do
	local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 10) c.Parent = btn
end
local lip = Instance.new("Frame")
lip.Name = "Lip"
lip.BackgroundColor3 = LIP
lip.BorderSizePixel = 0
lip.Position = UDim2.fromOffset(0, 3)
lip.Size = UDim2.fromScale(1, 1)
lip.ZIndex = 1
lip.Parent = holder
do
	local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 10) c.Parent = lip
end

local function shopScript()
	local ps = player:FindFirstChild("PlayerScripts")
	return ps and ps:FindFirstChild("ShopScreen")
end
btn.Activated:Connect(function()
	local s = shopScript()
	local fn = s and s:FindFirstChild("Open")
	if not fn then return end
	local ok, res = pcall(function() return fn:Invoke("stand") end)
	if ok and res then script:SetAttribute("ShopStandOpens", (script:GetAttribute("ShopStandOpens") or 0) + 1) end
end)

local function jumpButton()
	local at = pg:FindFirstChild("ArenaTouch")
	if not (at and at:IsA("ScreenGui") and at.Enabled) then return nil end
	for _, d in ipairs(at:GetDescendants()) do
		if d:IsA("GuiButton") and d.Visible then
			local t = d:IsA("TextButton") and d.Text or ""
			if t == "" then
				local l = d:FindFirstChildWhichIsA("TextLabel")
				t = l and l.Text or ""
			end
			if string.upper(t) == "JUMP" then return d end
		end
	end
	return nil
end

-- v1.1: the prompt on the stall (ShopStandBtnMode "prompt")
local ContextActionService = game:GetService("ContextActionService")
local PROMPT_ACTION = "ShopStandPromptKey"
local SILK = Font.new("rbxassetid://12187371840", Enum.FontWeight.Bold)
local promptAt, prompt, promptGui, promptKey = nil, nil, nil, nil
local promptBound, lastPromptOpen = false, 0
local function promptOpen()
	if os.clock() - lastPromptOpen < 0.4 then return end
	lastPromptOpen = os.clock()
	local s = shopScript()
	local fn = s and s:FindFirstChild("Open")
	if not fn then return end
	local ok, res = pcall(function() return fn:Invoke("stand") end)
	if ok and res then script:SetAttribute("ShopStandOpens", (script:GetAttribute("ShopStandOpens") or 0) + 1) end
end
local function keyOf(name, fallback)
	local ok, k = pcall(function() return Enum.KeyCode[name] end)
	return ok and k or fallback
end
local function promptUnbind()
	if promptBound then
		ContextActionService:UnbindAction(PROMPT_ACTION)
		promptBound = false
	end
end
local function promptBind()
	if promptBound then return end
	promptBound = true
	ContextActionService:BindActionAtPriority(PROMPT_ACTION, function(_, st)
		if st == Enum.UserInputState.Begin then promptOpen() end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value + 2,
		keyOf(tostring(script:GetAttribute("ShopStandPromptKey")), Enum.KeyCode.E),
		keyOf(tostring(script:GetAttribute("ShopStandPromptPad")), Enum.KeyCode.ButtonX))
end
local function promptLook(at)
	if promptGui then promptGui:Destroy() end
	local w, h = A("ShopStandPromptW", 190), A("ShopStandPromptH", 52)
	local bb = Instance.new("BillboardGui")
	bb.Name = "ShopStandPrompt"
	bb.Adornee = at
	bb.Size = UDim2.fromOffset(w + 10, h + 8)
	bb.LightInfluence = 0
	bb.Active = true
	bb.ResetOnSpawn = false
	bb.Enabled = false
	local pill = Instance.new("TextButton")
	pill.Name = "Pill"
	pill.AutoButtonColor = true
	pill.Text = ""
	pill.AnchorPoint = Vector2.new(0.5, 0.5)
	pill.Position = UDim2.fromScale(0.5, 0.5)
	pill.Size = UDim2.fromOffset(w, h)
	pill.BackgroundColor3 = Color3.fromRGB(20, 26, 36)
	pill.BackgroundTransparency = 0.15
	pill.Parent = bb
	do local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 10) c.Parent = pill end
	do local st = Instance.new("UIStroke") st.Color = YELLOW st.Thickness = 2 st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border st.Parent = pill end
	local cap = h - 14
	local key = Instance.new("TextLabel")
	key.Name = "Key"
	key.Size = UDim2.fromOffset(cap, cap)
	key.Position = UDim2.fromOffset(8, 7)
	key.BackgroundColor3 = YELLOW
	key.TextColor3 = INK
	key.FontFace = SILK
	key:SetAttribute("FontSwap", "keep")
	key.TextScaled = true
	key.Text = "E"
	key.Parent = pill
	do local c = Instance.new("UICorner") c.CornerRadius = UDim.new(1, 0) c.Parent = key end
	do local pd = Instance.new("UIPadding") pd.PaddingTop, pd.PaddingBottom, pd.PaddingLeft, pd.PaddingRight = UDim.new(0.24, 0), UDim.new(0.24, 0), UDim.new(0.16, 0), UDim.new(0.16, 0) pd.Parent = key end
	local lb = Instance.new("TextLabel")
	lb.Name = "Label"
	lb.BackgroundTransparency = 1
	lb.Size = UDim2.new(1, -(cap + 22), 1, 0)
	lb.Position = UDim2.fromOffset(cap + 16, 0)
	lb.TextXAlignment = Enum.TextXAlignment.Left
	lb.TextColor3 = YELLOW
	lb.FontFace = SILK
	lb:SetAttribute("FontSwap", "keep")
	lb.TextSize = 16
	lb.Text = "OPEN SHOP"
	lb.Parent = pill
	pill.Activated:Connect(promptOpen)
	bb.Parent = pg
	promptGui, promptKey = bb, key
end
local function promptMake(stand)
	local top = stand:FindFirstChild("CounterTop")
	if not (top and top:IsA("BasePart")) then return false end
	if promptAt and promptAt.Parent == top and prompt and prompt.Parent == promptAt then return true end
	if promptAt then promptAt:Destroy() end
	promptUnbind()
	local at = Instance.new("Attachment")
	at.Name = "ShopStandPromptAt"
	at.Position = Vector3.new(0, top.Size.Y / 2 + A("ShopStandPromptUp", 7), 0)
	at.Parent = top
	local pr = Instance.new("ProximityPrompt")
	pr.Name = "ShopStandPrompt"
	pr.Style = Enum.ProximityPromptStyle.Custom
	pr.ActionText = "OPEN SHOP"
	pr.ObjectText = ""
	pr.HoldDuration = 0
	pr.RequiresLineOfSight = false
	pr.MaxActivationDistance = (tonumber(stand:GetAttribute("ShopStandRange")) or 22) + 24 -- shown / hidden by the near test, not by this
	pr.KeyboardKeyCode = keyOf(tostring(script:GetAttribute("ShopStandPromptKey")), Enum.KeyCode.E)
	pr.GamepadKeyCode = keyOf(tostring(script:GetAttribute("ShopStandPromptPad")), Enum.KeyCode.ButtonX)
	pr.Enabled = false
	pr.Parent = at
	promptLook(at)
	pr.PromptShown:Connect(function(inputType)
		local kind = inputType == Enum.ProximityPromptInputType.Gamepad and "Gamepad"
			or inputType == Enum.ProximityPromptInputType.Touch and "Touch" or "Keyboard"
		if promptKey then
			promptKey.Text = kind == "Touch" and "TAP"
				or kind == "Gamepad" and (string.gsub(pr.GamepadKeyCode.Name, "^Button", ""))
				or pr.KeyboardKeyCode.Name
		end
		if promptGui then promptGui.Enabled = true end
		promptBind()
		script:SetAttribute("ShopStandPromptShown", true)
		script:SetAttribute("ShopStandPromptInput", kind)
	end)
	pr.PromptHidden:Connect(function()
		if promptGui then promptGui.Enabled = false end
		promptUnbind()
		script:SetAttribute("ShopStandPromptShown", false)
	end)
	pr.Triggered:Connect(promptOpen)
	promptAt, prompt = at, pr
	return true
end
local function promptStep(stand, show)
	if not (show and stand) then
		if prompt then prompt.Enabled = false end
		if promptGui then promptGui.Enabled = false end
		promptUnbind()
		return
	end
	if not promptMake(stand) then return end
	prompt.Enabled = true
	if script:GetAttribute("ShopStandBtnSpot") ~= "prompt" then script:SetAttribute("ShopStandBtnSpot", "prompt") end
end

local frozen = nil -- the HumanoidRootPart anchored here while the Shop is open from the stand
local function letGo()
	if frozen then
		if frozen.Parent then frozen.Anchored = false end
		frozen = nil
	end
end
local lastJumpScan, jumpBtn = 0, nil

RunService.RenderStepped:Connect(function()
	local on = script:GetAttribute("ShopStandClientEnabled") ~= false
	local stand = workspace:FindFirstChild("ShopStand")
	local c = player.Character
	local hrp = c and c:FindFirstChild("HumanoidRootPart")
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	local near = false
	if on and stand and hrp and hum and hum.Health > 0 and player:GetAttribute("InMenu") ~= true then
		local f = stand:GetAttribute("ShopStandFront")
		local r = tonumber(stand:GetAttribute("ShopStandRange")) or 22
		if typeof(f) == "Vector3" then
			local d = Vector3.new(hrp.Position.X - f.X, 0, hrp.Position.Z - f.Z).Magnitude
			near = d <= r
		end
	end
	if player:GetAttribute("ShopStandNear") ~= near then player:SetAttribute("ShopStandNear", near) end
	-- freeze while the Shop is open from the stand
	local shopOpen = player:GetAttribute("ShopOpen") == true and player:GetAttribute("ShopOpenFrom") == "stand"
	if shopOpen and hrp then
		if frozen ~= hrp then
			letGo()
			frozen = hrp
			hrp.AssemblyLinearVelocity = Vector3.zero
			hrp.Anchored = true
		end
	else
		letGo()
	end
	-- v1.1: the prompt on the stall (mode "prompt"); the screen button below is mode "screen"
	if script:GetAttribute("ShopStandBtnMode") ~= "screen" then
		gui.Enabled = false
		promptStep(stand, near and not (player:GetAttribute("ShopOpen") == true))
		return
	end
	promptStep(nil, false)
	-- the button
	gui.Enabled = near and not (player:GetAttribute("ShopOpen") == true)
	if not gui.Enabled then return end
	local w, h = A("ShopStandBtnW", 150), A("ShopStandBtnH", 46)
	holder.Size = UDim2.fromOffset(w, h)
	if os.clock() - lastJumpScan > 1 then lastJumpScan, jumpBtn = os.clock(), jumpButton() end
	if jumpBtn and jumpBtn.Parent and jumpBtn.Visible then
		local origin = gui.AbsolutePosition
		local jp, js = jumpBtn.AbsolutePosition, jumpBtn.AbsoluteSize
		holder.AnchorPoint = Vector2.new(0.5, 1)
		holder.Position = UDim2.fromOffset(jp.X + js.X / 2 - origin.X, jp.Y - origin.Y - A("ShopStandBtnGap", 10))
		if script:GetAttribute("ShopStandBtnSpot") ~= "jump" then script:SetAttribute("ShopStandBtnSpot", "jump") end
	else
		holder.AnchorPoint = Vector2.new(1, 1)
		holder.Position = UDim2.new(1, -A("ShopStandBtnRight", 24), 1, -A("ShopStandBtnUp", 150))
		if script:GetAttribute("ShopStandBtnSpot") ~= "corner" then script:SetAttribute("ShopStandBtnSpot", "corner") end
	end
end)
player.CharacterRemoving:Connect(letGo)
