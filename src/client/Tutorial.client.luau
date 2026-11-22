-- Tutorial v1.1 (Mecha Dino Arena) — the first-time flow's screens (LocalScript, StarterPlayerScripts). MDA-563, plan
-- docs/plans/FIRST_TIME_FLOW_v1.0.md Task 5 + "v1.1 redesign", ADR-013, mockup docs/mockups/first_time_flow_v0.4.html.
-- v1.1 (Kepu 2026-11-22 11:38, after playing 1.0 live on his phone: "unplayable and unprofessional ... The teno has two different
--   attack styles and it doesn't even teach you it ... Look at how big time games handle this ... layout on mobile and spacing";
--   12:09 "Build" on mockup v0.4). A rewrite of the screens; the server flow (TutorialServer 1.1) and every request stay the same.
-- Runs while ReplicatedStorage.TutorialRequest exists. Draws from the player attribute TutStep (0 = hidden).
-- ScreenGui "Tutorial": DisplayOrder 45 (over the game HUD, under EggLoader 100), IgnoreGuiInset, ResetOnSpawn false.
--   u = min(screen width, screen height x 1.9) / 100 (the mockup's 1 cqw on a phone). Text never below its minimum pixel size.
--   Nothing is placed under the Roblox buttons: content starts below GuiService.TopbarInset (its height; 58 px if 0), and the
--   objective box sits top-centre, narrower than the space right of the Roblox buttons (TopbarInset.Min.X).
-- Fonts: titles / buttons FredokaOne with FontSwap = "silk" (Silkscreen, like the rest of the game); every sentence
--   GothamBold / GothamBlack with FontSwap = "keep" (one body font, never mixed; ✓ / ★ / ▼ draw in these, checked live in 1.0).
-- Full-screen moments (opaque backdrop, the game HUD hidden under it):
--   steps 1-2 egg: "MECHA DINO ARENA" / "YOUR FIRST DINO" / "It's free. Tap the egg." A cream egg on a glowing stand, 3 dots;
--     each tap shakes it and adds a crack; the 1st tap sends "next" (step 1); the 3rd hatches it: flash, then "roll" (re-sent
--     every 0.8 s until TutRolled is set).
--   step 2 rolled: "IT HATCHED" + the dino's 3D model (ReplicatedStorage.PregameModels[dino] in a ViewportFrame) in a yellow
--     frame, its role chip (TutorialRules.ROLE), its name, "MAIN ATTACK" and one line per lesson (how + tip); NEXT.
--   step 3: "<DINO>'S GEAR" / "<n> MECHA PARTS" / "All maxed. They're yours." Part cards dealt in (orange "MAXED ★"; passive
--     parts grey "PASSIVE ★"); START TRAINING (TutLastResult "full" -> "Training is full. Trying again." + a new "next" every 3 s).
--   step 7 after TutKilled: "LEVEL UP" / the level / "+1 skill point" / SPEND IT (replay: "BOT DOWN" / "No XP in a replay." / NEXT).
--   step 9: "HOW YOU GET STRONGER" / "SKILL POINTS" / "1 every level. Kills give XP." + 3 tiles; GOT IT.
--   step 10: "TRAINING COMPLETE" / "LEVEL <n> <DINO>" / "<k> parts equipped"; GO TO THE ISLAND.
-- Training (4, 6, 7) and sheets (5, 8): the objective box top-centre ("STEP n/5", the goal, the lessons of step 4 with ticks, one
--   tip line, 5 progress bars). Phone: a pulsing yellow ring, a finger (tap / hold / pull) and a yellow callout on the REAL control
--   (ArenaTouch's visible main attack button; MechaButtons Slot_1 / Slot_2); PC: the callout above the AbilityBar with the key.
--   Step 4 hides the phone's other buttons (ArenaTouch Leap, MechaButtons slots) and puts them back after (only what it hid).
--   4: one lesson at a time (TutLesson / TutLessonsDone); a tick toast per lesson; moves on by itself (server).
--   5: bottom sheet: left the 2 real buttons, each a TAP socket and a PULL socket (PC: 4 keys); right the parts as cards
--      (tap -> SkillRequest("slot", first empty, id); tap a full socket -> clear it); TRY THEM.
--   6: ring + finger + callout on the button of the next unused part (tap for 1 / 2, pull down for 3 / 4); every
--      MechaButtonsLastPress "slot<n>:<part>" sends "used", n (re-sent every 0.5 s until the server has it); moves on by itself.
--   7: "Finish it. Use anything."; the bot's health bar.
--   8: bottom sheet: points box + the dino's stat rows with +; NEXT once a point is spent ("No points to spend." on a replay).
-- Bot marks (steps 4, 6, 7): yellow outline (Highlight) and arrow; health bar at step 7.
-- Switch: script attribute TutorialClientEnabled (default true, read at start). Diagnostics: script TutorialClientVersion;
--   player TutClientStep.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")

local VERSION = "1.1"
script:SetAttribute("TutorialClientVersion", VERSION)
if script:GetAttribute("TutorialClientEnabled") == nil then script:SetAttribute("TutorialClientEnabled", true) end
if script:GetAttribute("TutorialClientEnabled") == false then return end

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("TutorialRequest", 60)
if not remote then return end
local R = require(ReplicatedStorage:WaitForChild("TutorialShared"):WaitForChild("TutorialRules"))
local ST = require(ReplicatedStorage:WaitForChild("SkillShared", 60):WaitForChild("SkillTree"))
local skillRemote = ReplicatedStorage:WaitForChild("SkillRequest", 30)

local C = {
	bg = Color3.fromRGB(11, 15, 22), glow = Color3.fromRGB(38, 50, 74), panel = Color3.fromRGB(13, 19, 28),
	card = Color3.fromRGB(21, 29, 43), line = Color3.fromRGB(42, 52, 70), yellow = Color3.fromRGB(255, 200, 50),
	yellowDark = Color3.fromRGB(181, 138, 18), ink = Color3.fromRGB(27, 20, 6), white = Color3.new(1, 1, 1),
	text = Color3.fromRGB(223, 230, 240), muted = Color3.fromRGB(138, 149, 168), green = Color3.fromRGB(70, 224, 138),
	orange = Color3.fromRGB(255, 155, 46), cyan = Color3.fromRGB(127, 233, 255), pink = Color3.fromRGB(255, 107, 132),
}
local OBJ = {[4] = "ATTACK", [5] = "EQUIP 4 PARTS", [6] = "USE EACH PART", [7] = "DEFEAT THE BOT", [8] = "SPEND YOUR POINT"}
local SLOT_KEYS = {"R", "C", "T", "V"}
local ATTACK_BUTTONS = {"Bite", "PounceMain", "HeadbuttMain", "SlashMain", "TenoMain", "TheriMain", "DiloMain", "TrooMain"}

local gui = Instance.new("ScreenGui")
gui.Name = "Tutorial"
gui.DisplayOrder = 45
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")
local root = Instance.new("Frame")
root.Name = "Root"
root.BackgroundTransparency = 1
root.Size = UDim2.fromScale(1, 1)
root.Parent = gui

-- ---------- helpers ----------
local u, W, H, topH, freeLeft = 8, 800, 400, 58, 300
local function measure()
	W, H = root.AbsoluteSize.X, root.AbsoluteSize.Y
	if W < 10 then W, H = workspace.CurrentCamera.ViewportSize.X, workspace.CurrentCamera.ViewportSize.Y end
	u = math.min(W, H * 1.9) / 100
	local ok, rect = pcall(function() return GuiService.TopbarInset end)
	topH = ok and rect and rect.Height > 0 and rect.Max.Y or 58
	freeLeft = ok and rect and rect.Min.X > 0 and rect.Min.X or math.min(W * 0.32, 300)
end
local function px(n, min) return math.max(n * u, min or 0) end
local function make(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do o[k] = v end
	o.Parent = parent
	return o
end
local function corner(o, r) return make("UICorner", {CornerRadius = r or UDim.new(0, px(1, 6))}, o) end
local function stroke(o, c, th, t) return make("UIStroke", {Color = c, Thickness = th or 2, Transparency = t or 0,
	ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, o) end
local function pad(o, t, r, b, l) make("UIPadding", {PaddingTop = UDim.new(0, t), PaddingRight = UDim.new(0, r or t),
	PaddingBottom = UDim.new(0, b or t), PaddingLeft = UDim.new(0, l or r or t)}, o) end
local function list(o, dir, gap, align)
	return make("UIListLayout", {FillDirection = dir or Enum.FillDirection.Vertical, Padding = UDim.new(0, gap or 0),
		HorizontalAlignment = align or Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder}, o)
end
-- kind: "title" (FredokaOne -> Silkscreen), "black" / "body" (GothamBlack / GothamBold, kept as Gotham)
local function text(parent, s, kind, size, color, props)
	local font = kind == "title" and Enum.Font.FredokaOne or kind == "black" and Enum.Font.GothamBlack or Enum.Font.GothamBold
	local l = make("TextLabel", {BackgroundTransparency = 1, Text = s, Font = font, TextSize = size, TextColor3 = color or C.white,
		RichText = true, TextWrapped = kind ~= "title", AutomaticSize = Enum.AutomaticSize.XY, Size = UDim2.new()}, parent)
	l:SetAttribute("FontSwap", kind == "title" and "silk" or "keep")
	for k, v in pairs(props or {}) do l[k] = v end
	return l
end
local function cta(parent, s, onClick, props)
	local b = make("TextButton", {AutoButtonColor = true, BackgroundColor3 = C.yellow, Text = s, Font = Enum.Font.FredokaOne,
		TextSize = px(2.3, 18), TextColor3 = C.ink, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, px(5.4, 44)),
		Modal = true}, parent)
	b:SetAttribute("FontSwap", "silk")
	corner(b, UDim.new(0, px(1.2, 8)))
	pad(b, 0, px(3.6, 22))
	stroke(b, C.yellowDark, px(0.35, 2))
	for k, v in pairs(props or {}) do b[k] = v end
	b.Activated:Connect(onClick)
	return b
end
local function isTouch() return UserInputService.TouchEnabled end
local function step() return tonumber(player:GetAttribute("TutStep")) or 0 end
local function dinoKey()
	local c = player.Character
	local s = c and c:GetAttribute("Species")
	if type(s) == "string" and s ~= "" then return s end
	s = player:GetAttribute("DinoSpecies")
	return type(s) == "string" and s ~= "" and s or "TRex"
end
local function dinoName(k) return k == "TRex" and "T-Rex" or k end
local function send(action, arg) remote:FireServer(action, arg) end
local function pathStep(id) return tonumber(player:GetAttribute("SkillPath_" .. id)) or 0 end
local function partsOf(dino, buttonsOnly, given) -- v1.1 given: the free dino's parts as SkillServer 1.13 gives them (owned or not yet)
	local out = {}
	for _, id in ipairs(ST.PATH_ORDER) do
		local p = ST.PATHS[id]
		if p and p.mech and ST.LIVE_MECH[id] and not p.soon and (not ST.seesPath or ST.seesPath(p, dino))
			and (not buttonsOnly or ST.BUTTONS[id]) and (given or pathStep(id) >= 1) then
			table.insert(out, id)
		end
	end
	return out
end
local function statsOf(dino)
	local out = {}
	for _, a in ipairs(ST.AREAS) do
		for _, p in ipairs(ST.pathsFor and ST.pathsFor(a.id, dino) or a.paths) do
			if not p.mech and not p.soon then table.insert(out, p.id) end
		end
	end
	return out
end
local function pname(id) local p = ST.PATHS[id] return p and p.name or id end
local function need() return tonumber(player:GetAttribute("TutNeed")) or 4 end
local function slotOf(n) local v = player:GetAttribute("SkillSlot" .. n) return type(v) == "string" and v or "" end
local function usedSet() return R.parseDone(player:GetAttribute("TutUsed")) end
local function howWords(L)
	if isTouch() then
		return L.how == "hold" and "HOLD, THEN LET GO" or L.how == "tap3" and "TAP 3 TIMES" or "TAP"
	end
	if L.key then return "PRESS " .. L.key end
	return L.how == "hold" and "HOLD CLICK, LET GO" or L.how == "tap3" and "CLICK 3 TIMES" or "CLICK"
end
local function howLine(L)
	local w = howWords(L):lower()
	return (w:gsub("^%l", string.upper)) .. ". " .. L.line
end
local function botModel()
	local isl = workspace:FindFirstChild("DinoIsland")
	local ib = isl and isl:FindFirstChild("Bots")
	if ib then
		for _, m in ipairs(ib:GetChildren()) do
			if m:IsA("Model") and m:GetAttribute("TutOwner") == player.UserId then return m end
		end
	end
	return nil
end
local function tween(o, t, props, style, dir, rep, rev)
	local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out, rep or 0, rev or false), props)
	tw:Play()
	return tw
end

-- ---------- full-screen moments ----------
local function backdrop()
	local bg = make("TextButton", {Name = "Backdrop", Text = "", AutoButtonColor = false, BackgroundColor3 = C.bg, Size = UDim2.fromScale(1, 1),
		Modal = true}, root)
	local g = make("Frame", {BackgroundColor3 = C.glow, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(px(62), px(62))}, bg)
	corner(g, UDim.new(0.5, 0))
	make("UIGradient", {Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.35),
		NumberSequenceKeypoint.new(1, 1)})}, g)
	return bg
end
local function sceneColumn(kicker, title, sub)
	local col = make("Frame", {Name = "Scene", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.5, topH / 2), Size = UDim2.new(0.9, 0, 1, -topH - px(4))}, root)
	list(col, nil, px(1.2, 8))
	local n = 0
	local function add(o) n += 1 o.LayoutOrder = n return o end
	if kicker then add(text(col, kicker, "title", px(1.8, 14), C.yellow)) end -- v1.1 phone check: sizes up (Silkscreen draws ~0.7x)
	if title then add(text(col, title, "title", px(4.6, 32), C.white)) end
	if sub then add(text(col, sub, "body", px(1.8, 16), C.text)) end
	return col, add
end
local function flash()
	local f = make("Frame", {BackgroundColor3 = C.white, Size = UDim2.fromScale(1, 1), ZIndex = 20, BackgroundTransparency = 0.1}, root)
	tween(f, 0.5, {BackgroundTransparency = 1})
	task.delay(0.6, function() f:Destroy() end)
end
local function toast(s)
	local t = text(root, s, "black", px(2.6, 22), C.green, {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, topH + px(10)),
		ZIndex = 15, TextStrokeTransparency = 0.4})
	tween(t, 1.2, {Position = UDim2.new(0.5, 0, 0, topH + px(6)), TextTransparency = 1, TextStrokeTransparency = 1})
	task.delay(1.3, function() t:Destroy() end)
end

-- ---------- the egg (steps 1-2) ----------
local egg = {taps = 0, hatching = false, rollLoop = false}
local render -- below
local function drawEgg()
	backdrop()
	local col, add = sceneColumn("MECHA DINO ARENA", "YOUR FIRST DINO", "It's free. Tap the egg.")
	local holder = add(make("Frame", {BackgroundTransparency = 1, Size = UDim2.fromOffset(px(20), px(20))}, col))
	local stand = make("Frame", {BackgroundColor3 = C.cyan, BackgroundTransparency = 0.75, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 1, -px(1.5)), Size = UDim2.fromOffset(px(18), px(2.6))}, holder)
	corner(stand, UDim.new(0.5, 0))
	stroke(stand, C.cyan, px(0.25, 2), 0.4)
	local e = make("TextButton", {Name = "Egg", Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.fromRGB(236, 214, 160),
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -px(1.5)), Size = UDim2.fromOffset(px(12.5), px(16)),
		Modal = true}, holder)
	corner(e, UDim.new(0.5, 0))
	make("UIGradient", {Color = ColorSequence.new(Color3.fromRGB(255, 250, 236), Color3.fromRGB(178, 146, 86)), Rotation = 55}, e)
	stroke(e, Color3.fromRGB(255, 220, 140), px(0.3, 2), 0.3)
	local cracks = {{0.18, 0.34, 0.4, -20}, {0.46, 0.52, 0.32, 25}, {0.24, 0.62, 0.5, -8}}
	local function drawCracks()
		for i = 1, math.min(egg.taps, 3) do
			local c = cracks[i]
			make("Frame", {Name = "Crack" .. i, BackgroundColor3 = Color3.fromRGB(91, 70, 40), BorderSizePixel = 0,
				Position = UDim2.fromScale(c[1], c[2]), Size = UDim2.new(c[3], 0, 0, px(0.35, 2)), Rotation = c[4]}, e)
		end
	end
	drawCracks()
	local dots = add(make("Frame", {BackgroundTransparency = 1, Size = UDim2.fromOffset(px(8), px(1.6))}, col))
	list(dots, Enum.FillDirection.Horizontal, px(0.9))
	for i = 1, 3 do
		local d = make("Frame", {BackgroundColor3 = C.yellow, BackgroundTransparency = i <= egg.taps and 0 or 1, Size = UDim2.fromOffset(px(1.4, 10), px(1.4, 10)), LayoutOrder = i}, dots)
		corner(d, UDim.new(0.5, 0))
		stroke(d, C.yellow, px(0.2, 2))
	end
	local hint
	if egg.taps == 0 then
		local d = px(3.4, 26)
		hint = make("Frame", {BackgroundColor3 = C.white, BackgroundTransparency = 0.1, AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.66, 0.66), Size = UDim2.fromOffset(d, d), ZIndex = 3}, e)
		corner(hint, UDim.new(0.5, 0))
		tween(hint, 0.5, {Size = UDim2.fromOffset(d * 0.68, d * 0.68)}, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	end
	e.Activated:Connect(function()
		if egg.hatching then return end
		egg.taps += 1
		if hint then hint:Destroy() hint = nil end
		for _, ch in ipairs(e:GetChildren()) do if ch.Name:sub(1, 5) == "Crack" then ch:Destroy() end end
		drawCracks()
		for i, d in ipairs(dots:GetChildren()) do
			if d:IsA("Frame") then d.BackgroundTransparency = d.LayoutOrder <= egg.taps and 0 or 1 end
		end
		e.Rotation = 0
		tween(e, 0.06, {Rotation = 8}, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, 3, true)
		if egg.taps == 1 and step() == 1 then send("next") end
		if egg.taps >= 3 then
			egg.hatching = true
			task.delay(0.45, function()
				flash()
				if egg.rollLoop then return end
				egg.rollLoop = true
				task.spawn(function()
					while step() > 0 and step() <= 2 and (player:GetAttribute("TutRolled") or "") == "" do
						if step() == 2 then send("roll") elseif step() == 1 then send("next") end
						task.wait(0.8)
					end
					egg.rollLoop = false
					render()
				end)
			end)
		end
	end)
end

-- ---------- the dino's 3D portrait ----------
local function portrait(parent, key, size)
	local f = make("Frame", {BackgroundColor3 = Color3.fromRGB(32, 44, 66), Size = UDim2.fromOffset(size, size)}, parent)
	corner(f, UDim.new(0, px(2, 12)))
	stroke(f, C.yellow, px(0.3, 2))
	-- v1.1: PregameModels.<Dino> is a Folder: Body (Model) + Parts.<id> (PregameModels 1.1); framed like PregameScreen's dinoView
	local models = ReplicatedStorage:FindFirstChild("PregameModels")
	local fold = models and models:FindFirstChild(key)
	local body = fold and fold:FindFirstChild("Body")
	if body and body:IsA("Model") then
		local vf = make("ViewportFrame", {BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Ambient = Color3.fromRGB(150, 160, 180),
			LightColor = Color3.new(1, 1, 1), LightDirection = Vector3.new(-0.5, -1, -0.6)}, f)
		local m = Instance.new("Model")
		body:Clone().Parent = m
		local pf = fold:FindFirstChild("Parts")
		for _, id in ipairs(partsOf(key, false, true)) do
			local pm = pf and pf:FindFirstChild(id)
			if pm and pm:GetAttribute("Free") ~= true then pm:Clone().Parent = m end
		end
		for _, d in ipairs(m:GetDescendants()) do if d:IsA("BaseScript") then d:Destroy() end end
		local bcf, bsz = body:GetBoundingBox()
		local sz = body:GetAttribute("BodySize") or bsz
		local minY = body:GetAttribute("BodyMinY") or (bcf.Position.Y - sz.Y / 2)
		m.WorldPivot = CFrame.new(bcf.Position.X, minY, bcf.Position.Z)
		m.Parent = vf
		m:PivotTo(CFrame.Angles(0, math.pi + 0.8, 0))
		local mx = math.max(sz.X, sz.Y * 1.35, sz.Z)
		local d, ty = mx * 1.8, sz.Y * 0.42
		local cam = make("Camera", {FieldOfView = 30}, vf)
		cam.CFrame = CFrame.lookAt(Vector3.new(0, ty + d * 0.22, d), Vector3.new(0, ty, 0))
		vf.CurrentCamera = cam
	else
		text(f, string.upper(dinoName(key)):sub(1, 1), "title", size * 0.4, C.yellow, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5)})
	end
	return f
end

-- ---------- objective box ----------
local function objective(s, tip, lessons)
	local maxW = math.max(W - 2 * freeLeft - px(2), px(30))
	local f = make("Frame", {Name = "Objective", BackgroundColor3 = C.panel, BackgroundTransparency = 0.08, AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, px(1.2, 6)), Size = UDim2.fromOffset(math.min(px(36), maxW), 0), AutomaticSize = Enum.AutomaticSize.Y}, root)
	corner(f, UDim.new(0, px(1, 8)))
	stroke(f, C.white, 1.5, 0.85)
	-- v1.1 (Studio check): the accent bar stays out of the list (in it, its 100% height fed the box's automatic height)
	make("Frame", {Name = "Accent", BackgroundColor3 = C.yellow, BorderSizePixel = 0, Size = UDim2.new(0, px(0.6, 4), 1, 0)}, f)
	local body = make("Frame", {Name = "Body", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y}, f)
	pad(body, px(0.8, 6), px(1.4, 10), px(0.9, 7), px(1.8, 14))
	list(body, nil, px(0.35, 3), Enum.HorizontalAlignment.Left)
	local idx = s - 3
	text(body, ("STEP %d/5"):format(idx), "title", px(1.4, 12), C.yellow, {LayoutOrder = 1})
	text(body, OBJ[s] or "", "black", px(2.3, 19), C.white, {LayoutOrder = 2, TextWrapped = false})
	if lessons and #lessons > 1 then
		local row = make("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 3}, body)
		list(row, Enum.FillDirection.Horizontal, px(1.2, 8), Enum.HorizontalAlignment.Left)
		for i, L in ipairs(lessons) do
			local c = L.done and C.green or L.cur and C.white or C.muted
			text(row, (L.done and "✓ " or "• ") .. L.n, "black", px(1.3, 13), c, {LayoutOrder = i})
		end
	end
	if tip then
		text(body, tip, "body", px(1.6, 15), C.text, {LayoutOrder = 4, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
			TextXAlignment = Enum.TextXAlignment.Left})
	end
	local segs = make("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, px(0.5, 4)), LayoutOrder = 5}, body)
	list(segs, Enum.FillDirection.Horizontal, px(0.35, 3))
	for k = 1, 5 do
		local b = make("Frame", {BackgroundColor3 = k < idx and C.green or k == idx and C.yellow or C.white,
			BackgroundTransparency = k > idx and 0.85 or 0, Size = UDim2.new(0.2, -px(0.3, 3), 1, 0), LayoutOrder = k}, segs)
		corner(b, UDim.new(0.5, 0))
	end
	return f
end

-- ---------- pointing at the real controls ----------
local function rectOf(o)
	if not (o and o:IsA("GuiObject") and o.Visible and o.AbsoluteSize.X > 0) then return nil end
	local sg = o:FindFirstAncestorWhichIsA("ScreenGui")
	if sg and not sg.Enabled then return nil end
	local inset = (sg and not sg.IgnoreGuiInset) and GuiService:GetGuiInset() or Vector2.zero
	return o.AbsolutePosition + inset, o.AbsoluteSize
end
local function attackButton()
	local at = player.PlayerGui:FindFirstChild("ArenaTouch")
	if not at then return nil end
	for _, n in ipairs(ATTACK_BUTTONS) do
		for _, d in ipairs(at:GetDescendants()) do
			if d.Name == n and d:IsA("GuiObject") and d.Visible then return d end
		end
	end
	return nil
end
local function slotButton(b)
	local mg = player.PlayerGui:FindFirstChild("MechaButtons")
	return mg and mg:FindFirstChild("Slot_" .. b, true)
end
local function pcBar()
	local ab = player.PlayerGui:FindFirstChild("AbilityBar")
	return ab and ab:FindFirstChild("Bar", true)
end
local overlay = {}
local function pointAt(target, round, fingerKind, big, small, side)
	local pos, size = rectOf(target)
	if not pos then return false end
	local c = pos + size / 2
	local ring = make("Frame", {Name = "Ring", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(c.X, c.Y), Size = UDim2.fromOffset(size.X + px(1.6, 12), size.Y + px(1.6, 12)), ZIndex = 4}, root)
	corner(ring, round and UDim.new(0.5, 0) or UDim.new(0.24, 0))
	local rs = stroke(ring, C.yellow, px(0.45, 3))
	tween(rs, 0.5, {Transparency = 0.6}, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	if fingerKind then
		local d = math.max(size.X * 0.36, px(3, 22))
		local fg = make("Frame", {Name = "Finger", BackgroundColor3 = C.white, BackgroundTransparency = 0.08, AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(c.X, c.Y - (fingerKind == "pull" and d * 0.7 or 0)), Size = UDim2.fromOffset(d, d), ZIndex = 6}, root)
		corner(fg, UDim.new(0.5, 0))
		stroke(fg, C.white, 3)
		if fingerKind == "pull" then
			tween(fg, 1.1, {Position = UDim2.fromOffset(c.X, c.Y + d * 1.3)}, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, -1)
		elseif fingerKind == "hold" then
			tween(fg, 0.9, {Size = UDim2.fromOffset(d * 0.66, d * 0.66), BackgroundColor3 = C.yellow}, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
		else
			tween(fg, fingerKind == "tap3" and 0.22 or 0.45, {Size = UDim2.fromOffset(d * 0.66, d * 0.66)}, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
		end
	end
	if big then
		local cl = make("Frame", {Name = "Callout", BackgroundColor3 = C.yellow, AutomaticSize = Enum.AutomaticSize.XY, ZIndex = 5,
			AnchorPoint = side == "left" and Vector2.new(1, 0.5) or Vector2.new(0.5, 1),
			Position = side == "left" and UDim2.fromOffset(pos.X - px(1.6, 10), c.Y) or UDim2.fromOffset(c.X, pos.Y - px(1.4, 10))}, root)
		corner(cl, UDim.new(0, px(0.8, 6)))
		pad(cl, px(0.5, 4), px(1, 8))
		list(cl, nil, 0, Enum.HorizontalAlignment.Left)
		text(cl, big, "title", px(2.2, 18), C.ink, {LayoutOrder = 1, ZIndex = 5})
		if small and small ~= "" then text(cl, small, "body", px(1.3, 12), Color3.fromRGB(74, 58, 16), {LayoutOrder = 2, TextWrapped = false, ZIndex = 5}) end
	end
	return true
end
local function pcCallout(big, small)
	local bar = pcBar()
	local pos, size = rectOf(bar)
	local x = pos and (pos.X + size.X / 2) or W / 2
	local y = pos and pos.Y or H - px(8)
	local cl = make("Frame", {Name = "Callout", BackgroundColor3 = C.yellow, AutomaticSize = Enum.AutomaticSize.XY, ZIndex = 5,
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromOffset(x, y - px(1.4, 10))}, root)
	corner(cl, UDim.new(0, px(0.8, 6)))
	pad(cl, px(0.5, 4), px(1, 8))
	list(cl, nil, 0, Enum.HorizontalAlignment.Center)
	text(cl, big, "title", px(2.2, 18), C.ink, {LayoutOrder = 1, ZIndex = 5})
	if small and small ~= "" then text(cl, small, "body", px(1.3, 12), Color3.fromRGB(74, 58, 16), {LayoutOrder = 2, TextWrapped = false, ZIndex = 5}) end
end

-- hide the phone's other buttons during step 4 (only what this script hid comes back)
local hidden = {}
local function hideOthers(on)
	if not isTouch() then return end
	local targets = {}
	if on then
		local at = player.PlayerGui:FindFirstChild("ArenaTouch")
		local leap = at and at:FindFirstChild("Leap", true)
		if leap then table.insert(targets, leap) end
		for b = 1, 2 do local s = slotButton(b) if s then table.insert(targets, s) end end
		for _, o in ipairs(targets) do
			if o:IsA("GuiObject") and o.Visible then hidden[o] = true o.Visible = false end
		end
	else
		for o in pairs(hidden) do if o.Parent then o.Visible = true end end
		hidden = {}
	end
end

-- ---------- bot marks ----------
local mark = {bot = nil, hl = nil, bb = nil}
local function clearMark()
	if mark.hl then mark.hl:Destroy() end
	if mark.bb then mark.bb:Destroy() end
	mark.bot, mark.hl, mark.bb = nil, nil, nil
end
local function updateMark()
	local s = step()
	local bot = (s == 4 or s == 6 or s == 7) and botModel() or nil
	if bot ~= mark.bot then
		clearMark()
		if bot then
			mark.bot = bot
			mark.hl = make("Highlight", {FillTransparency = 1, OutlineColor = C.yellow, OutlineTransparency = 0.1,
				DepthMode = Enum.HighlightDepthMode.AlwaysOnTop}, bot)
			local head = bot:FindFirstChild("Head") or bot:FindFirstChild("HumanoidRootPart")
			mark.bb = make("BillboardGui", {Size = UDim2.fromOffset(150, 64), StudsOffset = Vector3.new(0, 8, 0), AlwaysOnTop = true,
				Adornee = head, LightInfluence = 0}, bot)
			text(mark.bb, "▼", "black", 34, C.yellow, {Name = "Arrow", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 22)})
			local bar = make("Frame", {Name = "Bar", BackgroundColor3 = Color3.fromRGB(40, 20, 24), Size = UDim2.new(1, 0, 0, 10)}, mark.bb)
			corner(bar, UDim.new(0.5, 0))
			local fill = make("Frame", {Name = "Fill", BackgroundColor3 = C.pink, Size = UDim2.fromScale(1, 1)}, bar)
			corner(fill, UDim.new(0.5, 0))
		end
	end
	if mark.bb then
		local bar = mark.bb:FindFirstChild("Bar")
		if bar then
			bar.Visible = s == 7
			local hp = tonumber(mark.bot:GetAttribute("DummyHealth")) or 0
			local max = tonumber(mark.bot:GetAttribute("DummyMaxHealth")) or 1
			bar.Fill.Size = UDim2.fromScale(math.clamp(hp / math.max(max, 1), 0, 1), 1)
		end
	end
end

-- ---------- bottom sheet ----------
local function sheet()
	local f = make("Frame", {Name = "Sheet", BackgroundColor3 = C.panel, BackgroundTransparency = 0.03, AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, px(2)), Size = UDim2.new(1, 0, 0, px(33, 230))}, root)
	corner(f, UDim.new(0, px(2, 14)))
	stroke(f, C.line, 2)
	local inner = make("Frame", {BackgroundTransparency = 1, Position = UDim2.fromOffset(px(6, 24), px(1.8, 12)),
		Size = UDim2.new(1, -2 * px(6, 24), 1, -px(1.8, 12) - px(3.6, 24))}, f)
	return f, inner
end
local function header(parent, s, order)
	return text(parent, s, "title", px(1.7, 13), C.yellow, {LayoutOrder = order or 0, TextXAlignment = Enum.TextXAlignment.Left})
end

-- ---------- render ----------
local lastSpentId = nil
local fullRetry = false
local shownLessons = {}
local function scenePartsCards(col, add, ids)
	local cols = math.min(5, math.max(3, math.ceil(#ids / 2)))
	local cw, chh, gap = px(15), px(6.6, 50), px(1)
	local rows = math.ceil(#ids / cols)
	local g = add(make("Frame", {BackgroundTransparency = 1, Size = UDim2.fromOffset(cols * cw + (cols - 1) * gap, rows * chh + (rows - 1) * gap)}, col))
	make("UIGridLayout", {CellSize = UDim2.fromOffset(cw, chh), CellPadding = UDim2.fromOffset(gap, gap), SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center}, g)
	for i, id in ipairs(ids) do
		local passive = not ST.BUTTONS[id]
		local cg = make("CanvasGroup", {BackgroundColor3 = C.card, LayoutOrder = i, GroupTransparency = 1}, g)
		corner(cg, UDim.new(0, px(1.2, 8)))
		stroke(cg, passive and Color3.fromRGB(107, 122, 148) or C.orange, px(0.22, 2))
		pad(cg, 0, px(1, 8))
		list(cg, nil, px(0.2, 2), Enum.HorizontalAlignment.Left)
		-- v1.1 phone check: long names shrink to the card (were cut: "Goo Blob Shoote"); the star line stays Gotham (Silkscreen has no star)
		local nm = text(cg, pname(id), "black", px(1.5, 13), C.white, {LayoutOrder = 1, TextWrapped = true, AutomaticSize = Enum.AutomaticSize.None,
			Size = UDim2.new(1, 0, 0, px(3.2, 24)), TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left})
		make("UITextSizeConstraint", {MaxTextSize = px(1.5, 13), MinTextSize = 9}, nm)
		text(cg, passive and "PASSIVE ★" or "MAXED ★", "black", px(1.2, 11), passive and C.muted or C.yellow, {LayoutOrder = 2})
		task.delay(0.06 * i, function() if cg.Parent then tween(cg, 0.3, {GroupTransparency = 0}) end end)
	end
end

function render()
	root:ClearAllChildren()
	local s = step()
	gui.Enabled = s > 0
	player:SetAttribute("TutClientStep", s)
	updateMark()
	hideOthers(false)
	if s <= 0 then return end
	measure()
	local dino = dinoKey()
	local replay = player:GetAttribute("TutReplay") == true
	local unlockText = ReplicatedStorage:GetAttribute("TutUnlockTextOn") == true
	local lessons = R.lessonsFor(dino)
	if s == 1 or (s == 2 and ((player:GetAttribute("TutRolled") or "") == "" or egg.hatching and egg.rollLoop)) then
		drawEgg()
	elseif s == 2 then
		local rolled = player:GetAttribute("TutRolled")
		local rl = R.lessonsFor(rolled)
		backdrop()
		local col, add = sceneColumn("IT HATCHED", nil, nil)
		local row = add(make("Frame", {BackgroundTransparency = 1, Size = UDim2.new(), AutomaticSize = Enum.AutomaticSize.XY}, col)) -- v1.1: grows to its content
		list(row, Enum.FillDirection.Horizontal, px(3))
		local pf = portrait(row, rolled, px(17, 120))
		pf.LayoutOrder = 1
		local facts = make("Frame", {BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.XY, Size = UDim2.new(), LayoutOrder = 2}, row)
		list(facts, nil, px(0.5, 4), Enum.HorizontalAlignment.Left)
		local chip = text(facts, " " .. (R.ROLE[rolled] or "FIGHTER") .. " ", "title", px(1.4, 12), C.ink, {BackgroundTransparency = 0,
			BackgroundColor3 = C.cyan, LayoutOrder = 1})
		corner(chip, UDim.new(0, 4))
		text(facts, string.upper(dinoName(rolled)), "title", px(4.4, 30), C.white, {LayoutOrder = 2})
		text(facts, "MAIN ATTACK", "title", px(1.4, 12), C.yellow, {LayoutOrder = 3})
		for i, L in ipairs(rl) do
			text(facts, L.n, "black", px(1.7, 15), C.white, {LayoutOrder = 3 + i * 2})
			text(facts, howLine(L), "body", px(1.35, 13), C.muted, {LayoutOrder = 4 + i * 2, Size = UDim2.fromOffset(px(30), 0),
				AutomaticSize = Enum.AutomaticSize.Y, TextXAlignment = Enum.TextXAlignment.Left})
		end
		if unlockText then add(text(col, "More dinos unlock with skill points.", "body", px(1.5, 14), C.muted)) end
		add(cta(col, "NEXT", function() send("next") end))
		flash()
	elseif s == 3 then
		backdrop()
		local free = player:GetAttribute("FreeDino")
		local key = (type(free) == "string" and free ~= "") and free or dino
		local ids = partsOf(key, false, true) -- v1.1: the body is still the old dino here, so its parts are not published yet
		local col, add = sceneColumn(string.upper(dinoName(key)) .. "'S GEAR", #ids .. " MECHA PARTS", "All maxed. They're yours.")
		scenePartsCards(col, add, ids)
		if player:GetAttribute("TutLastResult") == "full" then add(text(col, "Training is full. Trying again.", "body", px(1.5, 14), C.orange)) end
		add(cta(col, "START TRAINING", function() send("next") fullRetry = true end))
	elseif s == 4 then
		local cur = tonumber(player:GetAttribute("TutLesson")) or 1
		local done = R.parseDone(player:GetAttribute("TutLessonsDone"))
		local rows = {}
		for i, L in ipairs(lessons) do rows[i] = {n = L.n, done = done[i], cur = i == cur} end
		local all = player:GetAttribute("TutHit") == true
		local L = lessons[cur]
		objective(4, all and "Nice. That's your attack." or (L and L.line), rows)
		for i, L2 in ipairs(lessons) do
			if done[i] and not shownLessons[i] then shownLessons[i] = true toast("✓ " .. L2.n) end
		end
		if not all and L then
			if isTouch() then
				hideOthers(true)
				pointAt(attackButton(), true, L.how, howWords(L), L.n, "left")
			else
				pcCallout(howWords(L), L.n)
			end
		end
	elseif s == 5 then
		local n = need()
		local filled = 0
		for k = 1, n do if slotOf(k) ~= "" then filled += 1 end end
		objective(5, filled >= n and "Ready. Try them on the bot."
			or (isTouch() and "Each button holds 2 parts. Tap for the top one, pull down for the bottom one." or "Pick a part for each key."))
		local f, inner = sheet()
		local left = make("Frame", {BackgroundTransparency = 1, Size = UDim2.new(0, px(30, 200), 1, 0)}, inner)
		list(left, nil, px(0.8, 6), Enum.HorizontalAlignment.Left).VerticalAlignment = Enum.VerticalAlignment.Top
		header(left, isTouch() and "YOUR 2 BUTTONS" or "YOUR KEYS", 0)
		local map = make("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, -px(3, 20)), LayoutOrder = 1}, left)
		list(map, Enum.FillDirection.Horizontal, px(1.6, 10)).VerticalAlignment = Enum.VerticalAlignment.Top
		local nextEmpty
		for k = 1, n do if slotOf(k) == "" then nextEmpty = k break end end
		local function socket(parent, k, lab, h, order)
			local id = slotOf(k)
			local b = make("TextButton", {Text = "", AutoButtonColor = id ~= "", BackgroundColor3 = k == nextEmpty and Color3.fromRGB(58, 48, 18) or C.card,
				Size = UDim2.new(1, 0, 0, h), LayoutOrder = order}, parent)
			if k == nextEmpty then stroke(b, C.yellow, px(0.25, 2)) end
			list(b, nil, px(0.2, 2))
			text(b, id ~= "" and pname(id) or "EMPTY", "black", px(1.35, 12), id ~= "" and C.white or C.muted, {LayoutOrder = 1,
				Size = UDim2.new(1, -px(1, 8), 0, 0), AutomaticSize = Enum.AutomaticSize.Y})
			if lab then text(b, lab, "black", px(1.2, 11), C.orange, {LayoutOrder = 2}) end
			b.Activated:Connect(function() if id ~= "" and skillRemote then skillRemote:FireServer("slot", k, "") end end)
		end
		if isTouch() then
			for bnum = 1, 2 do
				local bb = make("Frame", {BackgroundColor3 = Color3.fromRGB(18, 26, 38), Size = UDim2.new(0.5, -px(0.8, 5), 1, 0), LayoutOrder = bnum}, map)
				corner(bb, UDim.new(0, px(1.6, 10)))
				stroke(bb, C.white, 2, 0.75)
				list(bb, nil, 0).VerticalAlignment = Enum.VerticalAlignment.Top
				text(bb, "BUTTON " .. bnum, "title", px(1.3, 11), C.muted, {LayoutOrder = 0, Size = UDim2.new(1, 0, 0, px(2.6, 18)), AutomaticSize = Enum.AutomaticSize.None})
				local hh = (bb.AbsoluteSize.Y > 0 and bb.AbsoluteSize.Y or px(24)) - px(2.6, 18)
				socket(bb, bnum, "TAP", math.max(hh / 2, px(7, 44)), 1)
				socket(bb, bnum + 2, "PULL ▼", math.max(hh / 2, px(7, 44)), 2)
			end
		else
			local grid = make("Frame", {BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), LayoutOrder = 1}, map)
			make("UIGridLayout", {CellSize = UDim2.new(0.5, -px(0.5, 4), 0.5, -px(0.5, 4)), CellPadding = UDim2.fromOffset(px(0.8, 6), px(0.8, 6)),
				SortOrder = Enum.SortOrder.LayoutOrder}, grid)
			for k = 1, 4 do
				local cell = make("Frame", {BackgroundTransparency = 1, LayoutOrder = k}, grid)
				corner(cell, UDim.new(0, px(1, 8)))
				socket(cell, k, "KEY " .. SLOT_KEYS[k], px(8, 50), 1)
			end
		end
		local right = make("Frame", {BackgroundTransparency = 1, Position = UDim2.fromOffset(px(32, 210), 0), Size = UDim2.new(1, -px(32, 210), 1, 0)}, inner)
		header(right, ("TAP A PART  %d/%d"):format(filled, n), 0)
		local sc = make("ScrollingFrame", {BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(0, px(2.6, 18)),
			Size = UDim2.new(1, 0, 1, -px(2.6, 18)), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollBarThickness = px(0.5, 4), ScrollingDirection = Enum.ScrollingDirection.Y}, right)
		make("UIGridLayout", {CellSize = UDim2.new(1 / 3, -px(0.7, 5), 0, px(5.6, 44)), CellPadding = UDim2.fromOffset(px(0.9, 6), px(0.9, 6)),
			SortOrder = Enum.SortOrder.LayoutOrder}, sc)
		local inSlot = {}
		for k = 1, 4 do inSlot[slotOf(k)] = true end
		local firstFree = true
		for i, id in ipairs(partsOf(dino, true)) do
			local used = inSlot[id]
			local b = make("TextButton", {Text = "", AutoButtonColor = not used, BackgroundColor3 = C.card, LayoutOrder = i}, sc)
			corner(b, UDim.new(0, px(1, 8)))
			local glow = not used and firstFree and nextEmpty ~= nil
			if not used then firstFree = false end
			stroke(b, used and C.line or C.orange, glow and px(0.4, 3) or px(0.22, 2))
			text(b, pname(id), "black", px(1.35, 12), used and C.muted or C.white, {AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, px(1, 8), 0.5, 0),
				Size = UDim2.new(1, -px(4, 28), 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextXAlignment = Enum.TextXAlignment.Left})
			text(b, "★", "black", px(1.4, 13), used and C.muted or C.yellow, {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -px(1, 8), 0.5, 0)})
			b.Activated:Connect(function()
				if used or not skillRemote or not nextEmpty then return end
				skillRemote:FireServer("slot", nextEmpty, id)
			end)
		end
		if filled >= n then
			cta(root, n == 0 and "NEXT" or "TRY THEM", function() send("next") end, {AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.new(1, -px(6, 24), 1, -f.Size.Y.Offset + px(2) - px(1.2, 8))})
		end
	elseif s == 6 then
		local used, n = usedSet(), need()
		local nextI
		for i = 1, n do if not used[i] then nextI = i break end end
		local tip
		if not nextI then tip = n == 4 and "All 4 done." or "All done."
		elseif not isTouch() then tip = "Each part is on its own key."
		elseif nextI > 2 then tip = (used[3] or used[4]) and "Pull down again." or "Each button has a 2nd part. Press and drag down."
		else tip = "Tap a button to use its part." end
		objective(6, tip)
		for i = 1, 4 do
			if used[i] and not shownLessons["u" .. i] then shownLessons["u" .. i] = true toast("✓ " .. pname(slotOf(i))) end
		end
		if nextI then
			local part = pname(slotOf(nextI))
			if isTouch() then
				local pull = nextI > 2
				pointAt(slotButton(pull and nextI - 2 or nextI), false, pull and "pull" or "tap", pull and "PULL DOWN ▼" or "TAP", part, "up")
			else
				pcCallout("PRESS " .. SLOT_KEYS[nextI], part)
			end
		end
	elseif s == 7 then
		if player:GetAttribute("TutKilled") == true then
			backdrop()
			if replay then
				local col, add = sceneColumn("TRAINING", "BOT DOWN", "No XP in a replay.")
				add(cta(col, "NEXT", function() send("next") end))
			else
				local col, add = sceneColumn("LEVEL UP", nil, nil)
				add(text(col, tostring(player:GetAttribute("SkillLevel") or 2), "title", px(14, 96), C.yellow))
				add(text(col, "+1 skill point", "body", px(1.9, 17), C.text))
				add(cta(col, "SPEND IT", function() send("next") end))
			end
			flash()
		else
			objective(7, "Finish it. Use anything.")
			if isTouch() then pointAt(attackButton(), true, nil, nil, nil) end
		end
	elseif s == 8 then
		local left = tonumber(player:GetAttribute("SkillLeft")) or 0
		local spentNow = (tonumber(player:GetAttribute("SkillSpent")) or 0) > (tonumber(player:GetAttribute("TutPtsStart")) or 0)
		objective(8, spentNow and ((lastSpentId and pname(lastSpentId) or "Your stat") .. " went up.")
			or (replay and left == 0) and "No points to spend." or "Tap + on a stat.")
		local f, inner = sheet()
		local box = make("Frame", {BackgroundColor3 = C.card, Size = UDim2.new(0, px(16, 110), 1, 0)}, inner)
		corner(box, UDim.new(0, px(1.4, 10)))
		list(box, nil, px(0.4, 3))
		text(box, tostring(left), "title", px(7, 48), C.yellow, {LayoutOrder = 1})
		text(box, left == 1 and "SKILL POINT" or "SKILL POINTS", "black", px(1.3, 12), C.white, {LayoutOrder = 2})
		text(box, "1 every level", "body", px(1.1, 11), C.muted, {LayoutOrder = 3})
		local right = make("Frame", {BackgroundTransparency = 1, Position = UDim2.fromOffset(px(18, 124), 0), Size = UDim2.new(1, -px(18, 124), 1, 0)}, inner)
		header(right, string.upper(dinoName(dino)) .. " STATS", 0)
		local sc = make("ScrollingFrame", {BackgroundTransparency = 1, BorderSizePixel = 0, Position = UDim2.fromOffset(0, px(2.6, 18)),
			Size = UDim2.new(1, 0, 1, -px(2.6, 18)), CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollBarThickness = px(0.5, 4), ScrollingDirection = Enum.ScrollingDirection.Y}, right)
		make("UIGridLayout", {CellSize = UDim2.new(0.5, -px(0.6, 4), 0, px(5.6, 44)), CellPadding = UDim2.fromOffset(px(0.9, 6), px(0.9, 6)),
			SortOrder = Enum.SortOrder.LayoutOrder}, sc)
		for i, id in ipairs(statsOf(dino)) do
			local n = pathStep(id)
			local r = make("Frame", {BackgroundColor3 = C.card, LayoutOrder = i}, sc)
			corner(r, UDim.new(0, px(1, 8)))
			stroke(r, C.line, 2)
			text(r, pname(id), "black", px(1.35, 12), C.white, {AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, px(1.2, 8), 0.5, 0),
				Size = UDim2.new(0.6, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextXAlignment = Enum.TextXAlignment.Left})
			text(r, n > 0 and ({"I", "II", "III", "★"})[n] or "-", "black", px(1.5, 13), n > 0 and C.green or C.muted,
				{AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -px(6.4, 48), 0.5, 0)})
			if n < 4 and left > 0 and not spentNow then
				local b = make("TextButton", {Text = "+", Font = Enum.Font.GothamBlack, TextSize = px(2.2, 20), TextColor3 = C.ink,
					BackgroundColor3 = C.yellow, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -px(0.6, 4), 0.5, 0),
					Size = UDim2.fromOffset(px(4.6, 40), px(4.2, 36)), Modal = true}, r)
				b:SetAttribute("FontSwap", "keep")
				corner(b, UDim.new(0, px(0.9, 6)))
				if i == 1 then tween(b, 0.5, {BackgroundColor3 = C.white}, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true) end
				b.Activated:Connect(function()
					lastSpentId = id
					if skillRemote then skillRemote:FireServer("buy", id) end
				end)
			end
		end
		if spentNow or (replay and left == 0) then
			cta(root, "NEXT", function() send("next") end, {AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.new(1, -px(6, 24), 1, -f.Size.Y.Offset + px(2) - px(1.2, 8))})
		end
	elseif s == 9 then
		backdrop()
		local col, add = sceneColumn("HOW YOU GET STRONGER", "SKILL POINTS", "1 every level. Kills give XP.")
		local row = add(make("Frame", {BackgroundTransparency = 1, Size = UDim2.fromOffset(px(60), px(11, 90))}, col))
		list(row, Enum.FillDirection.Horizontal, px(1.4, 10))
		local tiles = {{"+HP", "STATS", "Health, attack, armor, speed."}, {"I → ★", "PARTS", "Every part goes from I to ★."},
			{"NEW", "NEW DINOS", unlockText and "Points from any dino count." or "Coming soon."}}
		for i, t in ipairs(tiles) do
			local tf = make("Frame", {BackgroundColor3 = C.card, Size = UDim2.new(1 / 3, -px(1, 7), 1, 0), LayoutOrder = i}, row)
			corner(tf, UDim.new(0, px(1.4, 10)))
			stroke(tf, C.line, 2)
			pad(tf, px(1.2, 8))
			list(tf, nil, px(0.3, 2), Enum.HorizontalAlignment.Left).VerticalAlignment = Enum.VerticalAlignment.Top
			text(tf, t[1], "black", px(2.4, 18), C.yellow, {LayoutOrder = 1})
			text(tf, t[2], "black", px(1.5, 14), C.white, {LayoutOrder = 2})
			text(tf, t[3], "body", px(1.25, 12), C.muted, {LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
				TextXAlignment = Enum.TextXAlignment.Left})
		end
		add(cta(col, "GOT IT", function() send("next") end))
	elseif s == 10 then
		backdrop()
		local k = 0
		for i = 1, 4 do if slotOf(i) ~= "" then k += 1 end end
		local col, add = sceneColumn("TRAINING COMPLETE", "LEVEL " .. tostring(player:GetAttribute("SkillLevel") or 1) .. " " .. string.upper(dinoName(dino)),
			k .. " parts equipped")
		add(cta(col, "GO TO THE ISLAND", function() send("island") end))
	end
end

-- ---------- triggers ----------
local queued = false
local function queue()
	if queued then return end
	queued = true
	task.defer(function()
		queued = false
		render()
	end)
end
local WATCH = {TutStep = true, TutRolled = true, TutHit = true, TutUsed = true, TutKilled = true, TutNeed = true, TutLane = true,
	TutReplay = true, TutLastResult = true, TutLesson = true, TutLessonsDone = true, SkillSpent = true, SkillLeft = true,
	SkillLevel = true, FreeDino = true, SkillSlot1 = true, SkillSlot2 = true, SkillSlot3 = true, SkillSlot4 = true}
player.AttributeChanged:Connect(function(name)
	if name == "TutStep" then
		local s = step()
		if s ~= 8 then lastSpentId = nil end
		if s <= 1 then egg.taps, egg.hatching = 0, false end
		if s ~= 4 and s ~= 6 then shownLessons = {} end
	end
	if WATCH[name] or (step() == 5 and name:sub(1, 10) == "SkillPath_") then queue() end
end)
ReplicatedStorage:GetAttributeChangedSignal("TutUnlockTextOn"):Connect(queue)
root:GetPropertyChangedSignal("AbsoluteSize"):Connect(queue)

-- step 6: each part used (MechaButtonsLastPress lives on the character, written by MechaButtons on this client)
local localUsed = {}
local charConn
local function onChar(c)
	if charConn then charConn:Disconnect() end
	charConn = c:GetAttributeChangedSignal("MechaButtonsLastPress"):Connect(function()
		if step() ~= 6 then return end
		local n, id = string.match(c:GetAttribute("MechaButtonsLastPress") or "", "^slot(%d):(.+)$")
		n = tonumber(n)
		if n and n <= need() and id ~= "empty" then
			localUsed[n] = true
			send("used", n)
		end
	end)
	c:GetAttributeChangedSignal("Species"):Connect(queue)
	queue()
end
player.CharacterAdded:Connect(onChar)
if player.Character then onChar(player.Character) end

-- the bot marks, the "full" retry, re-sending used parts, keeping the phone's other buttons hidden in step 4
task.spawn(function()
	local lastRetry, lastUsed = 0, 0
	while true do
		task.wait(0.2)
		local s = step()
		if s > 0 then updateMark() end
		if s == 3 and fullRetry and player:GetAttribute("TutLastResult") == "full" and os.clock() - lastRetry > 3 then
			lastRetry = os.clock()
			send("next")
		end
		if s ~= 3 then fullRetry = false end
		if s == 6 and os.clock() - lastUsed > 0.5 then
			lastUsed = os.clock()
			local have = usedSet()
			for n in pairs(localUsed) do if not have[n] then send("used", n) end end
		elseif s ~= 6 then
			localUsed = {}
		end
		if s == 4 and player:GetAttribute("TutHit") ~= true then hideOthers(true) end
	end
end)
render()
