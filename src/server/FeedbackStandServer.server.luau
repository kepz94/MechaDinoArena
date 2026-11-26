-- FeedbackStandServer v1.0 (Mecha Dino Arena) — the FEEDBACK kiosk on the island plaza (Script, ServerScriptService).
-- Kepu 2026-11-26 08:06 "make a feedback stand where i can receive all the feedback from players"; pick "Roblox feedback window
--   (Recommended)": the kiosk opens Roblox's own feedback window (FeedbackClient 1.0, SocialService:PromptFeedbackSubmissionAsync),
--   and the notes land in Creator Hub > Creations > Mecha Dino Arena > Audience > Feedback. Nothing is stored by the game.
-- Hub servers only. Waits for Workspace.ShopStand (ShopStandServer) and Workspace.PortalIslet.Plaza, then builds
--   Workspace.FeedbackStand at FeedbackStandRadius (45) studs from the plaza centre c, at FeedbackStandAngle (145) degrees from world +X
--   toward +Z (across the plaza from the Favorite Egg at 315; shop 160, LOBBY board 347, WORLD board ~110; Studio check 2026-11-26:
--   at 135 it stood in front of the WORLD board's corner from the plaza), on the ground (ray down),
--   facing c.
-- Look (studs, before scaling; the front faces c): a dark metal plinth (6 x 1 x 4, rgb(43,50,61)) with a cyan neon strip on its front
--   edge; a post (1.2 x 5 x 1.2, rgb(58,67,80)); a screen box (7 x 4.2 x 0.6, rgb(13,18,24)) tilted back 12 degrees, with a cyan neon
--   frame and a SurfaceGui: "FEEDBACK" (cyan, Silkscreen), "TELL US WHAT TO ADD OR FIX" (white), "READ BY THE DEV" (muted); a speech
--   bubble icon (yellow) on top.
-- A ProximityPrompt on the plinth: ActionText "SEND FEEDBACK", ObjectText "Feedback", HoldDuration 0, KeyboardKeyCode E,
--   MaxActivationDistance FeedbackPromptRange (14), RequiresLineOfSight false.
-- Size: Model:ScaleTo(FeedbackStandScale (2)) about its ground point; the screen's PixelsPerStud is 50 / scale so its text keeps its
--   look. ModelStreamingMode Persistent (StreamingEnabled: FeedbackClient needs the prompt).
-- Switches / numbers (script attributes, read at start): FeedbackStandEnabled (true), FeedbackStandAngle (145), FeedbackStandRadius
--   (45), FeedbackStandScale (2), FeedbackPromptRange (14).
-- Diagnostics: FeedbackStandServerVersion, FeedbackStandState ("off" / "notHub" / "waiting" / "built" / "error: ...").
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VERSION = "1.0"
VERSION = "1.1" -- v1.1 the other side of the bridge, facing it
-- v1.1 (Kepu 2026-11-26 12:14 "PUT IT ON THE OTHER SIDE OF WHERE THE EGG IS LOCATED SO THERES THE EGG MACHINE ON ONE SIDE OF THE BRIDGE ENTRANCE TO THE ISLAND AND THE FEEDBACK MACHINE ON THE OTHER SIDE"): FeedbackStandAngle default 211 (was 145), FeedbackStandRadius 100 (was 45): 22 studs to the
--   other side of the bridge line from the Favorite Egg (239). It faces the point FaceAngle / FaceRadius from the plaza centre (default 225 deg, 190 studs: out along the bridge deck, which runs 225 deg, r 125-209), so players walking back over the bridge see its front. Attributes FeedbackStandFaceAngle (225),
--   FeedbackStandFaceRadius (190); switch FeedbackStandFaceEnabled (true, read at start; false = faces the plaza centre as 1.0).
script:SetAttribute("FeedbackStandServerVersion", VERSION)
for k, v in pairs({FeedbackStandEnabled = true, FeedbackStandAngle = 211, FeedbackStandRadius = 100, FeedbackStandScale = 2, -- v1.1: 211 / 100 (1.0: 145 / 45)
	FeedbackPromptRange = 14, FeedbackStandFaceEnabled = true, FeedbackStandFaceAngle = 225, FeedbackStandFaceRadius = 190}) do -- v1.1
	if script:GetAttribute(k) == nil then script:SetAttribute(k, v) end
end
local function state(s) script:SetAttribute("FeedbackStandState", s) end
if script:GetAttribute("FeedbackStandEnabled") == false then state("off") return end

state("waiting")
local shop, plaza
local t0 = os.clock()
while os.clock() - t0 < 180 do
	local kind = ReplicatedStorage:GetAttribute("ServerKind")
	if kind ~= nil and kind ~= "hub" then state("notHub") return end
	shop = workspace:FindFirstChild("ShopStand")
	local islet = workspace:FindFirstChild("PortalIslet")
	plaza = islet and islet:FindFirstChild("Plaza")
	if kind == "hub" and shop and plaza then break end
	task.wait(0.5)
end
if not (shop and plaza) then state("waiting: no shop / plaza") return end

local SILK = Font.new("rbxassetid://12187371840", Enum.FontWeight.Bold)
local function part(parent, name, size, cf, color, mat)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored, p.CanCollide = true, false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end
local function label(parent, text, size, color, y, h)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.new(0.92, 0, h, 0)
	l.Position = UDim2.new(0.04, 0, y, 0)
	l.FontFace = SILK
	l.TextScaled = true
	l.TextColor3 = color
	l.Text = text
	l:SetAttribute("FontSwap", "keep")
	local c = Instance.new("UITextSizeConstraint")
	c.MaxTextSize = size
	c.Parent = l
	l.Parent = parent
	return l
end

local ok, err = pcall(function()
	local old = workspace:FindFirstChild("FeedbackStand")
	if old then old:Destroy() end
	local c = Vector3.new(plaza.Position.X, 0, plaza.Position.Z)
	local sp = shop:GetPivot()
	local r = tonumber(script:GetAttribute("FeedbackStandRadius")) or 45
	local a = math.rad(tonumber(script:GetAttribute("FeedbackStandAngle")) or 145)
	local x, z = c.X + math.cos(a) * r, c.Z + math.sin(a) * r
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {shop}
	local hit = workspace:Raycast(Vector3.new(x, sp.Position.Y + 60, z), Vector3.new(0, -200, 0), params)
	local gy = hit and hit.Position.Y or (sp.Position.Y - 4)
	local base = CFrame.lookAt(Vector3.new(x, gy, z), Vector3.new(c.X, gy, c.Z))
	if script:GetAttribute("FeedbackStandFaceEnabled") ~= false then -- v1.1: face out along the bridge
		local fa = math.rad(tonumber(script:GetAttribute("FeedbackStandFaceAngle")) or 225)
		local fr = tonumber(script:GetAttribute("FeedbackStandFaceRadius")) or 190
		base = CFrame.lookAt(Vector3.new(x, gy, z), Vector3.new(c.X + math.cos(fa) * fr, gy, c.Z + math.sin(fa) * fr))
	end

	local m = Instance.new("Model")
	m.Name = "FeedbackStand"
	local SC = math.clamp(tonumber(script:GetAttribute("FeedbackStandScale")) or 2, 0.5, 5)
	local METAL, POST, SCREEN, CYAN, YELLOW = Color3.fromRGB(43, 50, 61), Color3.fromRGB(58, 67, 80), Color3.fromRGB(13, 18, 24),
		Color3.fromRGB(127, 233, 255), Color3.fromRGB(255, 200, 50)
	local plinth = part(m, "Base", Vector3.new(6, 1, 4), base * CFrame.new(0, 0.5, 0), METAL, Enum.Material.Metal)
	part(m, "Strip", Vector3.new(6.1, 0.25, 0.2), base * CFrame.new(0, 0.85, -2.05), CYAN, Enum.Material.Neon)
	part(m, "Post", Vector3.new(1.2, 5, 1.2), base * CFrame.new(0, 3.5, 0.4), POST, Enum.Material.Metal)
	-- the screen, tilted back so it reads from the plaza
	local scrCF = base * CFrame.new(0, 7.6, 0.2) * CFrame.Angles(math.rad(-12), 0, 0)
	local screen = part(m, "Screen", Vector3.new(7, 4.2, 0.6), scrCF, SCREEN)
	for _, f in ipairs({{0, 2.2, 7.4, 0.25}, {0, -2.2, 7.4, 0.25}, {3.6, 0, 0.25, 4.6}, {-3.6, 0, 0.25, 4.6}}) do
		part(m, "Frame", Vector3.new(f[3], f[4], 0.7), scrCF * CFrame.new(f[1], f[2], 0), CYAN, Enum.Material.Neon)
	end
	local sg = Instance.new("SurfaceGui")
	sg.Name = "Face"
	sg.Face = Enum.NormalId.Front
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 50 / SC
	sg.LightInfluence = 0
	sg.Parent = screen
	label(sg, "FEEDBACK", 90, CYAN, 0.08, 0.38)
	label(sg, "TELL US WHAT TO ADD OR FIX", 40, Color3.new(1, 1, 1), 0.5, 0.2)
	label(sg, "READ BY THE DEV", 30, Color3.fromRGB(122, 138, 156), 0.74, 0.16)
	-- the speech bubble on top
	local bubble = part(m, "Bubble", Vector3.new(2.6, 1.8, 0.5), base * CFrame.new(0, 11.2, 0.6), YELLOW, Enum.Material.Neon)
	part(m, "Tail", Vector3.new(0.6, 0.6, 0.5), base * CFrame.new(-0.7, 10.1, 0.6) * CFrame.Angles(0, 0, math.rad(45)), YELLOW,
		Enum.Material.Neon)
	for i, dx in ipairs({-0.7, 0, 0.7}) do
		part(m, "Dot" .. i, Vector3.new(0.35, 0.35, 0.6), bubble.CFrame * CFrame.new(dx, 0, 0), SCREEN)
	end
	-- the prompt
	local pp = Instance.new("ProximityPrompt")
	pp.Name = "FeedbackPrompt"
	pp.ActionText = "SEND FEEDBACK"
	pp.ObjectText = "Feedback"
	pp.HoldDuration = 0
	pp.KeyboardKeyCode = Enum.KeyCode.E
	pp.MaxActivationDistance = tonumber(script:GetAttribute("FeedbackPromptRange")) or 14
	pp.RequiresLineOfSight = false
	pp.Parent = plinth
	m.PrimaryPart = plinth
	m.WorldPivot = base
	if SC ~= 1 then m:ScaleTo(SC) end
	pcall(function() m.ModelStreamingMode = Enum.ModelStreamingMode.Persistent end)
	m.Parent = workspace
end)
state(ok and "built" or ("error: " .. tostring(err)))
