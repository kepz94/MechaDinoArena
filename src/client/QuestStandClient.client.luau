-- QuestStandClient v1.0 (Mecha Dino Arena) — the OPEN QUESTS prompt at the island Quest Stand (LocalScript, StarterPlayerScripts).
-- Plan docs/plans/QUEST_STAND_v1.0.md Task 5, mockup docs/mockups/quest_stand_v0.1.html (the stall card: "E OPEN QUESTS 2 READY").
-- A copy of ShopStandClient 1.1's "prompt" mode (that script is not touched):
-- Near: Workspace.QuestStand (QuestStandServer 1.0) exists, the player is out of the menu (InMenu ~= true), alive, and the own
--   HumanoidRootPart is within the stand's QuestStandRange (24) studs (flat) of its QuestStandFront point. Player attribute
--   QuestStandNear.
-- Prompt: while near and the Quest screen is closed, a ProximityPrompt made on this client (Style Custom, ActionText OPEN QUESTS,
--   HoldDuration 0, no line of sight) on Attachment "QuestStandPromptAt" QuestStandPromptUp (7) studs above the stall's CounterTop.
--   Look: BillboardGui "QuestStandPrompt" in PlayerGui: dark pill QuestStandPromptW x QuestStandPromptH (190 x 52) px, yellow outline,
--   a yellow round key cap (keyboard QuestStandPromptKey "E", gamepad QuestStandPromptPad "ButtonX" shown "X", touch "TAP") and yellow
--   "OPEN QUESTS" (Silkscreen Bold); when player QuestReady (QuestServer 1.0) > 0 a red "<n> READY" tag on the pill's right end
--   (the pill grows by the tag's width).
--   Opens the Quest screen (QuestScreen 1.0 BindableFunction Open:Invoke("stand")) on the prompt's Triggered, a tap / click on the
--   pill, or the key / pad button through ContextActionService at priority High + 2 (sunk), bound only while the prompt shows.
--   0.4 s debounce.
-- While the Quest screen is open (player QuestOpen == true) the own HumanoidRootPart is anchored on this client; let go on close.
-- Switch: script attribute QuestStandClientEnabled (true, read per frame). Diagnostics: QuestStandClientVersion, QuestStandOpens,
--   QuestStandPromptShown, QuestStandPromptInput.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")

local VERSION = "1.0"
script:SetAttribute("QuestStandClientVersion", VERSION)
for k, v in pairs({QuestStandClientEnabled = true, QuestStandOpens = 0, QuestStandPromptKey = "E", QuestStandPromptPad = "ButtonX",
	QuestStandPromptUp = 7, QuestStandPromptW = 190, QuestStandPromptH = 52}) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, v) end
end
local function A(k, d) return tonumber(script:GetAttribute(k)) or d end

local player = Players.LocalPlayer
local pg = player:WaitForChild("PlayerGui")
local YELLOW, INK, RED = Color3.fromRGB(255, 200, 50), Color3.fromRGB(26, 19, 0), Color3.fromRGB(255, 90, 110)
local SILK = Font.new("rbxassetid://12187371840", Enum.FontWeight.Bold)
local PROMPT_ACTION = "QuestStandPromptKey"

local function questScript()
	local ps = player:FindFirstChild("PlayerScripts")
	return ps and ps:FindFirstChild("QuestScreen")
end
local promptAt, prompt, promptGui, promptKey, promptPill, readyTag
local promptBound, lastOpen = false, 0
local function open()
	if os.clock() - lastOpen < 0.4 then return end
	lastOpen = os.clock()
	local s = questScript()
	local fn = s and s:FindFirstChild("Open")
	if not fn then return end
	local ok, res = pcall(function() return fn:Invoke("stand") end)
	if ok and res then script:SetAttribute("QuestStandOpens", (script:GetAttribute("QuestStandOpens") or 0) + 1) end
end
local function keyOf(name, fallback)
	local ok, k = pcall(function() return Enum.KeyCode[name] end)
	return ok and k or fallback
end
local function unbind()
	if promptBound then
		ContextActionService:UnbindAction(PROMPT_ACTION)
		promptBound = false
	end
end
local function bind()
	if promptBound then return end
	promptBound = true
	ContextActionService:BindActionAtPriority(PROMPT_ACTION, function(_, st)
		if st == Enum.UserInputState.Begin then open() end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value + 2,
		keyOf(tostring(script:GetAttribute("QuestStandPromptKey")), Enum.KeyCode.E),
		keyOf(tostring(script:GetAttribute("QuestStandPromptPad")), Enum.KeyCode.ButtonX))
end
local function look(at)
	if promptGui then promptGui:Destroy() end
	local w, h = A("QuestStandPromptW", 190), A("QuestStandPromptH", 52)
	local bb = Instance.new("BillboardGui")
	bb.Name = "QuestStandPrompt"
	bb.Adornee = at
	bb.Size = UDim2.fromOffset(w + 110, h + 8)
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
	lb.Size = UDim2.fromOffset(w - (cap + 22), h)
	lb.Position = UDim2.fromOffset(cap + 16, 0)
	lb.TextXAlignment = Enum.TextXAlignment.Left
	lb.TextColor3 = YELLOW
	lb.FontFace = SILK
	lb:SetAttribute("FontSwap", "keep")
	lb.TextSize = 16
	lb.Text = "OPEN QUESTS"
	lb.Parent = pill
	local tag = Instance.new("TextLabel")
	tag.Name = "Ready"
	tag.AnchorPoint = Vector2.new(1, 0.5)
	tag.Position = UDim2.new(1, -10, 0.5, 0)
	tag.Size = UDim2.fromOffset(84, 22)
	tag.BackgroundColor3 = RED
	tag.TextColor3 = Color3.new(1, 1, 1)
	tag.FontFace = SILK
	tag:SetAttribute("FontSwap", "keep")
	tag.TextSize = 12
	tag.Visible = false
	tag.Parent = pill
	do local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 8) c.Parent = tag end
	pill.Activated:Connect(open)
	bb.Parent = pg
	promptGui, promptKey, promptPill, readyTag = bb, key, pill, tag
end
local function make(stand)
	local top = stand:FindFirstChild("CounterTop")
	if not (top and top:IsA("BasePart")) then return false end
	if promptAt and promptAt.Parent == top and prompt and prompt.Parent == promptAt then return true end
	if promptAt then promptAt:Destroy() end
	unbind()
	local at = Instance.new("Attachment")
	at.Name = "QuestStandPromptAt"
	at.Position = Vector3.new(0, top.Size.Y / 2 + A("QuestStandPromptUp", 7), 0)
	at.Parent = top
	local pr = Instance.new("ProximityPrompt")
	pr.Name = "QuestStandPrompt"
	pr.Style = Enum.ProximityPromptStyle.Custom
	pr.ActionText = "OPEN QUESTS"
	pr.ObjectText = ""
	pr.HoldDuration = 0
	pr.RequiresLineOfSight = false
	pr.MaxActivationDistance = (tonumber(stand:GetAttribute("QuestStandRange")) or 24) + 24
	pr.KeyboardKeyCode = keyOf(tostring(script:GetAttribute("QuestStandPromptKey")), Enum.KeyCode.E)
	pr.GamepadKeyCode = keyOf(tostring(script:GetAttribute("QuestStandPromptPad")), Enum.KeyCode.ButtonX)
	pr.Enabled = false
	pr.Parent = at
	look(at)
	pr.PromptShown:Connect(function(inputType)
		local kind = inputType == Enum.ProximityPromptInputType.Gamepad and "Gamepad"
			or inputType == Enum.ProximityPromptInputType.Touch and "Touch" or "Keyboard"
		if promptKey then
			promptKey.Text = kind == "Touch" and "TAP"
				or kind == "Gamepad" and (string.gsub(pr.GamepadKeyCode.Name, "^Button", ""))
				or pr.KeyboardKeyCode.Name
		end
		if promptGui then promptGui.Enabled = true end
		bind()
		script:SetAttribute("QuestStandPromptShown", true)
		script:SetAttribute("QuestStandPromptInput", kind)
	end)
	pr.PromptHidden:Connect(function()
		if promptGui then promptGui.Enabled = false end
		unbind()
		script:SetAttribute("QuestStandPromptShown", false)
	end)
	pr.Triggered:Connect(open)
	promptAt, prompt = at, pr
	return true
end
local function step(stand, show)
	if not (show and stand) then
		if prompt then prompt.Enabled = false end
		if promptGui then promptGui.Enabled = false end
		unbind()
		return
	end
	if not make(stand) then return end
	prompt.Enabled = true
	local n = tonumber(player:GetAttribute("QuestReady")) or 0
	local w = A("QuestStandPromptW", 190)
	if readyTag then
		readyTag.Visible = n > 0
		local txt = n .. " READY"
		if readyTag.Text ~= txt then readyTag.Text = txt end
		promptPill.Size = UDim2.fromOffset(w + (n > 0 and 94 or 0), A("QuestStandPromptH", 52))
	end
end

local frozen
local function letGo()
	if frozen then
		if frozen.Parent then frozen.Anchored = false end
		frozen = nil
	end
end
RunService.RenderStepped:Connect(function()
	local on = script:GetAttribute("QuestStandClientEnabled") ~= false
	local stand = workspace:FindFirstChild("QuestStand")
	local c = player.Character
	local hrp = c and c:FindFirstChild("HumanoidRootPart")
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	local near = false
	if on and stand and hrp and hum and hum.Health > 0 and player:GetAttribute("InMenu") ~= true then
		local f = stand:GetAttribute("QuestStandFront")
		local r = tonumber(stand:GetAttribute("QuestStandRange")) or 24
		if typeof(f) == "Vector3" then near = Vector3.new(hrp.Position.X - f.X, 0, hrp.Position.Z - f.Z).Magnitude <= r end
	end
	if player:GetAttribute("QuestStandNear") ~= near then player:SetAttribute("QuestStandNear", near) end
	local isOpen = player:GetAttribute("QuestOpen") == true
	if isOpen and hrp then
		if frozen ~= hrp then
			letGo()
			frozen = hrp
			hrp.AssemblyLinearVelocity = Vector3.zero
			hrp.Anchored = true
		end
	else
		letGo()
	end
	step(stand, near and not isOpen)
end)
player.CharacterRemoving:Connect(letGo)
