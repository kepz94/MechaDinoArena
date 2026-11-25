-- ShopStandClient v1.0 (Mecha Dino Arena) — the OPEN SHOP button at the island shop stand (LocalScript, StarterPlayerScripts).
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

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local VERSION = "1.0"
script:SetAttribute("ShopStandClientVersion", VERSION)
for k, v in pairs({ShopStandClientEnabled = true, ShopStandBtnW = 150, ShopStandBtnH = 46, ShopStandBtnGap = 10,
	ShopStandBtnRight = 24, ShopStandBtnUp = 150, ShopStandOpens = 0}) do
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
