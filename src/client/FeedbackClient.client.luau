-- FeedbackClient v1.0 (Mecha Dino Arena) — the FEEDBACK kiosk's prompt opens Roblox's feedback window (LocalScript,
--   StarterPlayerScripts).
-- Kepu 2026-11-26 08:06 "make a feedback stand where i can receive all the feedback from players"; pick "Roblox feedback window
--   (Recommended)". Works with FeedbackStandServer 1.0 (Workspace.FeedbackStand, Base.FeedbackPrompt, streamed Persistent).
-- Prompt triggered (one at a time) -> SocialService:PromptFeedbackSubmissionAsync() in a pcall. The notes are read in Creator Hub >
--   Creations > Mecha Dino Arena > Audience > Feedback. On an error -> toast "FEEDBACK IS NOT OPEN RIGHT NOW" (yellow outline, 2.4 s).
-- PC mouse: while the call is open (and for FeedbackMouseHold (1.5) s after it returns) MouseBehavior Default and the cursor shown
--   right after the camera (RenderStep "FeedbackMouse", the Lab / FavEgg pattern), so the shoulder camera can't lock the mouse away
--   from the window.
-- Switches / numbers (script attributes): FeedbackClientEnabled (true, read at start), FeedbackMouseHold (1.5, read per prompt).
-- Diagnostics: FeedbackClientVersion, FeedbackClientState ("off" / "waiting" / "ready" / "noStand"), FeedbackOpens (count),
--   FeedbackLastResult ("ok" / "error: ...").
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SocialService = game:GetService("SocialService")
local UIS = game:GetService("UserInputService")

local VERSION = "1.0"
VERSION = "1.1" -- v1.1 mouse held free until the player moves
-- v1.1 (Studio check 2026-11-26: PromptFeedbackSubmissionAsync returns in ~0.4 s while Roblox's window stays open): the mouse stays
--   free from the prompt until at least FeedbackMouseHold (1.5) s have passed and the player's dino moves (Humanoid.MoveDirection),
--   or FeedbackMouseMax (30) s. Switch: FeedbackHoldUntilMove (true, read per prompt; false = 1.0, free for FeedbackMouseHold only).
script:SetAttribute("FeedbackClientVersion", VERSION)
for k, v in pairs({FeedbackClientEnabled = true, FeedbackMouseHold = 1.5, FeedbackMouseMax = 30, FeedbackHoldUntilMove = true}) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, v) end
end
local function state(s) script:SetAttribute("FeedbackClientState", s) end
if script:GetAttribute("FeedbackClientEnabled") == false then state("off") return end
local player = Players.LocalPlayer

-- toast
local toastGui = Instance.new("ScreenGui")
toastGui.Name = "FeedbackToast"
toastGui.DisplayOrder = 71
toastGui.ResetOnSpawn = false
toastGui.Parent = player:WaitForChild("PlayerGui")
local toast = Instance.new("TextLabel")
toast.AnchorPoint = Vector2.new(0.5, 1)
toast.Position = UDim2.new(0.5, 0, 1, -120)
toast.BackgroundColor3 = Color3.fromRGB(13, 18, 24)
toast.Font = Enum.Font.GothamBlack
toast.TextSize = 18
toast.TextColor3 = Color3.new(1, 1, 1)
toast.Visible = false
toast.Parent = toastGui
do
	local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 12) c.Parent = toast
	local s = Instance.new("UIStroke") s.Color = Color3.fromRGB(255, 200, 50) s.Thickness = 3 s.Parent = toast
end
local toastId = 0
local function showToast(t)
	toastId += 1
	local my = toastId
	toast.Text = t
	toast.Size = UDim2.fromOffset(math.max(260, #t * 14 + 48), 48)
	toast.Visible = true
	task.delay(2.4, function() if toastId == my then toast.Visible = false end end)
end

local busy = false
local function onPrompt(who)
	if who ~= player or busy then return end
	busy = true
	script:SetAttribute("FeedbackOpens", (script:GetAttribute("FeedbackOpens") or 0) + 1)
	pcall(function() RunService:UnbindFromRenderStep("FeedbackMouse") end)
	RunService:BindToRenderStep("FeedbackMouse", Enum.RenderPriority.Camera.Value + 1, function()
		UIS.MouseBehavior = Enum.MouseBehavior.Default
		UIS.MouseIconEnabled = true
	end)
	local ok, err = pcall(function() SocialService:PromptFeedbackSubmissionAsync() end)
	script:SetAttribute("FeedbackLastResult", ok and "ok" or ("error: " .. tostring(err)))
	if not ok then showToast("FEEDBACK IS NOT OPEN RIGHT NOW") end
	task.spawn(function() -- v1.1: Roblox's window stays up after the call returns, so hold until the player moves or FeedbackMouseMax
		local t0 = os.clock()
		local hold = tonumber(script:GetAttribute("FeedbackMouseHold")) or 1.5
		local max = math.max(hold, tonumber(script:GetAttribute("FeedbackMouseMax")) or 30)
		while os.clock() - t0 < max do
			task.wait(0.2)
			local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if os.clock() - t0 >= hold and (script:GetAttribute("FeedbackHoldUntilMove") == false
				or (hum and hum.MoveDirection.Magnitude > 0.1)) then break end
		end
		pcall(function() RunService:UnbindFromRenderStep("FeedbackMouse") end)
		busy = false
	end)
end

state("waiting")
local stand = workspace:WaitForChild("FeedbackStand", 240)
local base = stand and stand:WaitForChild("Base", 30)
local prompt = base and base:WaitForChild("FeedbackPrompt", 30)
if not prompt then state("noStand") return end
prompt.Triggered:Connect(onPrompt)
state("ready")
