-- Tutorial v1.0 (Mecha Dino Arena) — the first-time flow's screens: cards, checklist, trainer, prompts, the egg, the equip and
-- stat panels (LocalScript, StarterPlayerScripts). MDA-563, plan docs/plans/FIRST_TIME_FLOW_v1.0.md Task 5, ADR-013, mockup
-- docs/mockups/first_time_flow_v0.3.html (Kepu 2026-11-22: "A + B's cards", no skip; 10:25 game-style wording; 10:41 the egg
-- roll and the phone tap / pull-down teaching).
-- Runs while ReplicatedStorage.TutorialRequest exists (TutorialServer 1.0). Draws from the player attribute TutStep (1..10;
-- 0 = hidden) and the attributes TutorialServer / DinoOwnership / SkillServer write; every button only sends a request, the
-- server judges.
-- ScreenGui "Tutorial" (DisplayOrder 45: over MainMenu 40, under EggLoader 100; IgnoreGuiInset; ResetOnSpawn false). ch =
--   screen height / 100. Phone = UserInputService.TouchEnabled (as MechaButtons).
-- Cards (steps 1, 2, 3, the step 7 level-up, 9, 10): a dim veil (black 0.45, Modal so the mouse is free) and a centred panel
--   rgb(20, 26, 36), 56% wide (82% on phones), yellow FredokaOne title, white lines, one yellow button.
--   1 "WELCOME!" / "Your first dino is free." / ROLL -> "next".
--   2 "YOUR FREE DINO" / "Tap the egg." over a cream egg; a tap shakes it 0.8 s, cracks it and sends "roll"; at 1.5 s, once
--     TutRolled is set: "IT HATCHED!" / "<DINO>!" (/ "It's yours. More dinos unlock with skill points." while ReplicatedStorage
--     TutUnlockTextOn) / NEXT -> "next".
--   3 "<n> MECHA PARTS" / "All maxed out." / the dino's live parts with a star / TO TRAINING -> "next" (TutLastResult "full"
--     -> "Training is full. Trying again." and a new "next" every 3 s).
--   7 after TutKilled: "LEVEL <n>" / "+1 skill point" / SPEND IT -> "next" (replay: "BOT DOWN" / "No XP in a replay." / NEXT).
--   9 "SKILL POINTS" / "1 every level." / tiles UPGRADE STATS "Health, attack, armor, speed.", UPGRADE PARTS "Parts go from I to
--     ★.", UNLOCK DINOS "Points from any dino count." (TutUnlockTextOn) or "Coming soon." / GOT IT -> "next".
--   10 "TRAINING DONE" / "Level <n> <Dino>" / GO TO THE ISLAND -> "island".
-- Training (4, 6, 7): checklist top-left ("TRAINING", rows ✓ green / ▸ white / · grey), prompt top-centre (key chip + action),
--   trainer box bottom-centre (top-centre-left on phones so it never covers the thumb buttons), a yellow outline and an arrow
--   on the bot; the bot's health bar only at step 7.
--   4 "See that bot? Hit it with your <attack>." -> NEXT once TutHit.
--   6 PC "Now try your parts." / phone "Tap a button to use its part." -> "Each button has a second part. Pull it down." ->
--     "Pull down again."; "All 4 done." + NEXT. Each MechaButtonsLastPress "slot<n>:<part>" (n <= TutNeed) sends "used", n.
--     Phone: a finger dot on the real MechaButtons Slot_1 / Slot_2 button, pulsing for a tap, sliding down for a pull.
--   7 "Finish it!".
-- Panels (5, 8): veil + panel 88% wide x 64% high, Modal.
--   5 "LAB · EQUIP PARTS" / PC "Your slots are R, C, T and V." / phone "2 buttons, 2 parts each. Tap for the top one. Pull down
--     for the bottom one."; the dino's owned button parts as tiles (tap -> SkillRequest("slot", first empty, id)); 4 slots
--     (tap a full one -> SkillRequest("slot", n, "")) labelled "KEY R".. (PC) or "BUTTON 1 · TAP", "BUTTON 2 · TAP",
--     "BUTTON 1 · PULL ▼", "BUTTON 2 · PULL ▼" (phone). Trainer "Pick 4. <n> left." / "Good. Now try them." + TRY THEM.
--   8 "LAB · <DINO> STATS" / "Spend your point."; the dino's stat rows (name, step I..★, + -> SkillRequest("buy", id)); points
--     box "<n> SKILL POINT(S)" / "1 every level. Kills give XP." Trainer "Tap + on a stat." -> "<Stat> went up." + NEXT
--     (replay with no points: "No points to spend." + NEXT).
-- Switch: script attribute TutorialClientEnabled (default true, read at start). Diagnostics: script TutorialClientVersion;
--   player TutClientStep (the step drawn).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")

local VERSION = "1.0"
VERSION = "1.0.1" -- v1.0.1 finds the bot in DinoIsland.Bots; > in the checklist
script:SetAttribute("TutorialClientVersion", VERSION)
if script:GetAttribute("TutorialClientEnabled") == nil then script:SetAttribute("TutorialClientEnabled", true) end
if script:GetAttribute("TutorialClientEnabled") == false then return end

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("TutorialRequest", 60)
if not remote then return end
local R = require(ReplicatedStorage:WaitForChild("TutorialShared"):WaitForChild("TutorialRules"))
local ST = require(ReplicatedStorage:WaitForChild("SkillShared", 60):WaitForChild("SkillTree"))
local skillRemote = ReplicatedStorage:WaitForChild("SkillRequest", 30)

local YELLOW = Color3.fromRGB(255, 200, 50)
local PANEL = Color3.fromRGB(20, 26, 36)
local PANEL2 = Color3.fromRGB(30, 38, 52)
local LINE = Color3.fromRGB(60, 72, 92)
local WHITE = Color3.new(1, 1, 1)
local MUTED = Color3.fromRGB(143, 153, 170)
local CYAN = Color3.fromRGB(127, 233, 255)
local GREEN = Color3.fromRGB(70, 224, 138)
local ORANGE = Color3.fromRGB(255, 155, 46)
local DARK = Color3.fromRGB(27, 20, 6)
local ATTACK = {Raptor = {"Pounce", "F"}, Dilo = {"Bite"}, Herrera = {"Slash"}, Troodon = {"Glow Pod Toss"}, Pachy = {"Headbutt"},
	Teno = {"Scratch / Tail Slam"}, Therizino = {"Claw Combo"}}
local SLOT_KEYS = {"R", "C", "T", "V"}
local ROMAN = {"I", "II", "III", "★"}

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
local function make(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do o[k] = v end
	o.Parent = parent
	return o
end
local function corner(o, r) make("UICorner", {CornerRadius = UDim.new(0, r)}, o) end
local function stroke(o, c, t, th) make("UIStroke", {Color = c, Transparency = t or 0, Thickness = th or 2,
	ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, o) end
local function label(parent, text, font, size, color, props)
	local l = make("TextLabel", {BackgroundTransparency = 1, Text = text, Font = font, TextSize = size, TextColor3 = color,
		TextWrapped = true, RichText = true}, parent)
	for k, v in pairs(props or {}) do l[k] = v end
	return l
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
local function partsOf(dino, buttonsOnly)
	local out = {}
	for _, id in ipairs(ST.PATH_ORDER) do
		local p = ST.PATHS[id]
		if p and p.mech and ST.LIVE_MECH[id] and not p.soon and (not ST.seesPath or ST.seesPath(p, dino))
			and (not buttonsOnly or ST.BUTTONS[id]) and pathStep(id) >= 1 then
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
local function usedSet()
	local s = {}
	for k in string.gmatch(player:GetAttribute("TutUsed") or "", "%d") do s[tonumber(k)] = true end
	return s
end
local function botModel() -- v1.0.1: TutorialServer 1.0.1 keeps the bot in DinoIsland.Bots (TutOwner); 1.0 in the lane
	local isl = workspace:FindFirstChild("DinoIsland")
	local ib = isl and isl:FindFirstChild("Bots")
	if ib then
		for _, m in ipairs(ib:GetChildren()) do
			if m:IsA("Model") and m:GetAttribute("TutOwner") == player.UserId then return m end
		end
	end
	local tg = workspace:FindFirstChild("TrainingGround")
	local lane = tg and tg:FindFirstChild("Lane" .. tostring(player:GetAttribute("TutLane") or 0))
	local bots = lane and lane:FindFirstChild("Bots")
	return bots and bots:FindFirstChildWhichIsA("Model")
end

-- ---------- building blocks ----------
local ch, W, H = 8, 800, 600
local function button(parent, text, onClick, props)
	local b = make("TextButton", {AutoButtonColor = true, BackgroundColor3 = YELLOW, Text = text, Font = Enum.Font.GothamBlack,
		TextSize = math.max(2.2 * ch, 13), TextColor3 = DARK, AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, math.max(5.6 * ch, 34)), Modal = true}, parent)
	corner(b, 1.2 * ch)
	make("UIPadding", {PaddingLeft = UDim.new(0, 2.6 * ch), PaddingRight = UDim.new(0, 2.6 * ch)}, b)
	for k, v in pairs(props or {}) do b[k] = v end
	b.Activated:Connect(onClick)
	return b
end
local function veil()
	return make("TextButton", {Name = "Veil", Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45, Size = UDim2.fromScale(1, 1), Modal = true}, root)
end
local function card(title, lines, btnText, onClick, opts)
	opts = opts or {}
	if not opts.noVeil then veil() end
	local w = (isTouch() and 0.82 or 0.56) * W
	local f = make("Frame", {Name = "Card", BackgroundColor3 = PANEL, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = opts.pos or UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(opts.w or w, 0),
		AutomaticSize = Enum.AutomaticSize.Y}, root)
	corner(f, 1.6 * ch)
	stroke(f, LINE, 0, 2)
	make("UIPadding", {PaddingTop = UDim.new(0, 2.4 * ch), PaddingBottom = UDim.new(0, 2.4 * ch),
		PaddingLeft = UDim.new(0, 2.6 * ch), PaddingRight = UDim.new(0, 2.6 * ch)}, f)
	make("UIListLayout", {FillDirection = Enum.FillDirection.Vertical, HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 1.4 * ch), SortOrder = Enum.SortOrder.LayoutOrder}, f)
	local n = 0
	local function add(o) n += 1 o.LayoutOrder = n return o end
	add(label(f, title, Enum.Font.FredokaOne, math.max(5 * ch, 24), YELLOW, {Size = UDim2.new(1, 0, 0, math.max(5.6 * ch, 28))}))
	for _, l in ipairs(lines) do
		local big = type(l) == "table" and l.big
		local t = type(l) == "table" and l.text or l
		add(label(f, t, big and Enum.Font.FredokaOne or Enum.Font.GothamBold, big and math.max(4.4 * ch, 22) or math.max(2.2 * ch, 13),
			WHITE, {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y}))
	end
	if opts.extra then add(opts.extra(f)) end
	if btnText then add(button(f, btnText, onClick)) end
	return f
end
local function checklist()
	local f = make("Frame", {Name = "Checklist", BackgroundColor3 = PANEL, BackgroundTransparency = 0.12,
		Position = UDim2.fromOffset(1.6 * ch, 1.6 * ch), Size = UDim2.fromOffset(math.max(22 * ch, 140), 0),
		AutomaticSize = Enum.AutomaticSize.Y}, root)
	corner(f, 1.2 * ch)
	make("UIPadding", {PaddingTop = UDim.new(0, 1.2 * ch), PaddingBottom = UDim.new(0, 1.2 * ch), PaddingLeft = UDim.new(0, 1.4 * ch),
		PaddingRight = UDim.new(0, 1.4 * ch)}, f)
	make("UIListLayout", {Padding = UDim.new(0, 0.5 * ch), SortOrder = Enum.SortOrder.LayoutOrder}, f)
	local s = math.max(1.7 * ch, 10)
	label(f, "TRAINING", Enum.Font.GothamBlack, s, YELLOW, {Size = UDim2.new(1, 0, 0, s * 1.6), TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 0})
	for i, name in ipairs(R.STEPS) do
		local cur, done = step(), i < step()
		local mark = done and "✓ " or (i == cur and "> " or "· ") -- v1.0.1: the game font has no ▸
		label(f, mark .. name, Enum.Font.GothamBold, s, done and GREEN or (i == cur and WHITE or MUTED),
			{Size = UDim2.new(1, 0, 0, s * 1.4), TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = i})
	end
	return f
end
local function trainer(text, btnText, onClick)
	local phoneTop = isTouch() and ({[4] = true, [6] = true, [7] = true})[step()]
	local f = make("Frame", {Name = "Trainer", BackgroundColor3 = Color3.fromRGB(13, 18, 24), BackgroundTransparency = 0.08,
		AnchorPoint = phoneTop and Vector2.new(0, 0) or Vector2.new(0.5, 1),
		Position = phoneTop and UDim2.new(0.22, 0, 0, 16 * ch) or UDim2.new(0.5, 0, 1, -14 * ch),
		Size = phoneTop and UDim2.new(0.34, 0, 0, 0) or UDim2.new(0.56, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y}, root)
	corner(f, 1.2 * ch)
	stroke(f, CYAN, 0, 2)
	make("UIPadding", {PaddingTop = UDim.new(0, 1.2 * ch), PaddingBottom = UDim.new(0, 1.2 * ch), PaddingLeft = UDim.new(0, 1.4 * ch),
		PaddingRight = UDim.new(0, 1.4 * ch)}, f)
	make("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 1.4 * ch), SortOrder = Enum.SortOrder.LayoutOrder}, f)
	local face = make("Frame", {BackgroundColor3 = Color3.fromRGB(58, 123, 213), Size = UDim2.fromOffset(5 * ch, 5 * ch), LayoutOrder = 1}, f)
	corner(face, ch)
	label(face, "🦖", Enum.Font.GothamBold, 3 * ch, WHITE, {Size = UDim2.fromScale(1, 1)})
	local body = make("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, -(btnText and 22 or 7) * ch, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2}, f)
	make("UIListLayout", {Padding = UDim.new(0, 0.3 * ch), SortOrder = Enum.SortOrder.LayoutOrder}, body)
	label(body, "TRAINER", Enum.Font.GothamBlack, math.max(1.4 * ch, 9), CYAN, {Size = UDim2.new(1, 0, 0, math.max(1.6 * ch, 10)),
		TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 1})
	label(body, text, Enum.Font.GothamBold, math.max(2 * ch, 12), WHITE, {Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = 2})
	if btnText then
		local b = button(f, btnText, onClick, {BackgroundColor3 = CYAN, LayoutOrder = 3, TextColor3 = Color3.fromRGB(6, 32, 48)})
		b.Size = UDim2.fromOffset(0, math.max(4.6 * ch, 28))
	end
	return f
end
local function prompt(keyText, action)
	local f = make("Frame", {Name = "Prompt", BackgroundColor3 = Color3.fromRGB(13, 18, 24), BackgroundTransparency = 0.1,
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 7 * ch), Size = UDim2.fromOffset(0, math.max(6 * ch, 34)),
		AutomaticSize = Enum.AutomaticSize.X}, root)
	corner(f, 1.2 * ch)
	stroke(f, YELLOW, 0, 2)
	make("UIPadding", {PaddingLeft = UDim.new(0, 1.6 * ch), PaddingRight = UDim.new(0, 1.6 * ch)}, f)
	make("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 1.2 * ch), SortOrder = Enum.SortOrder.LayoutOrder}, f)
	local s = math.max(2.6 * ch, 15)
	if keyText then
		local k = label(f, keyText, Enum.Font.GothamBlack, s, DARK, {BackgroundTransparency = 0, BackgroundColor3 = YELLOW,
			AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, s * 1.5), TextWrapped = false, LayoutOrder = 1})
		corner(k, 0.6 * ch)
		make("UIPadding", {PaddingLeft = UDim.new(0, 0.8 * ch), PaddingRight = UDim.new(0, 0.8 * ch)}, k)
	end
	label(f, action, Enum.Font.GothamBlack, s, WHITE, {AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, s * 1.5),
		TextWrapped = false, LayoutOrder = 2})
	return f
end
local function attackPrompt()
	local a = ATTACK[dinoKey()] or {"attack"}
	if isTouch() then return "Tap", "ATTACK" end
	return a[2] or "CLICK", a[1]
end
local function panel(title, sub)
	veil()
	local f = make("Frame", {Name = "Panel", BackgroundColor3 = PANEL, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 3 * ch),
		Size = UDim2.new(0.88, 0, 0, 64 * ch)}, root)
	corner(f, 1.6 * ch)
	stroke(f, LINE, 0, 2)
	label(f, title, Enum.Font.FredokaOne, math.max(3.4 * ch, 18), YELLOW, {Position = UDim2.fromOffset(2.4 * ch, 1.6 * ch),
		Size = UDim2.new(1, -4.8 * ch, 0, 4 * ch), TextXAlignment = Enum.TextXAlignment.Left})
	label(f, sub, Enum.Font.GothamBold, math.max(1.8 * ch, 11), MUTED, {Position = UDim2.fromOffset(2.4 * ch, 5.8 * ch),
		Size = UDim2.new(1, -4.8 * ch, 0, 3 * ch), TextXAlignment = Enum.TextXAlignment.Left})
	return f
end

-- ---------- bot marks (outline + arrow + health at step 7) ----------
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
			mark.hl = make("Highlight", {FillTransparency = 1, OutlineColor = YELLOW, OutlineTransparency = 0.1,
				DepthMode = Enum.HighlightDepthMode.AlwaysOnTop}, bot)
			local head = bot:FindFirstChild("Head") or bot:FindFirstChild("HumanoidRootPart")
			mark.bb = make("BillboardGui", {Size = UDim2.fromOffset(160, 70), StudsOffset = Vector3.new(0, 7, 0), AlwaysOnTop = true,
				Adornee = head, LightInfluence = 0}, bot)
			label(mark.bb, "▼", Enum.Font.GothamBlack, 34, YELLOW, {Name = "Arrow", Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromOffset(0, 26)})
			local bar = make("Frame", {Name = "Bar", BackgroundColor3 = Color3.fromRGB(40, 20, 24), Size = UDim2.new(1, 0, 0, 10)}, mark.bb)
			corner(bar, 5)
			local fill = make("Frame", {Name = "Fill", BackgroundColor3 = Color3.fromRGB(255, 107, 132), Size = UDim2.fromScale(1, 1)}, bar)
			corner(fill, 5)
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

-- ---------- phone finger on the real slot buttons ----------
local finger
local function slotButton(b)
	local mg = player.PlayerGui:FindFirstChild("MechaButtons")
	return mg and mg:FindFirstChild("Slot_" .. b, true), mg
end
local function showFinger(b, pull)
	local btn, mg = slotButton(b)
	if not (btn and btn:IsA("GuiObject") and btn.Visible) then return end
	local inset = (mg and not mg.IgnoreGuiInset) and GuiService:GetGuiInset() or Vector2.zero
	local c = btn.AbsolutePosition + inset + btn.AbsoluteSize / 2
	local d = math.max(btn.AbsoluteSize.X * 0.38, 18)
	finger = make("Frame", {Name = "Finger", BackgroundColor3 = WHITE, BackgroundTransparency = 0.15, AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(d, d), Position = UDim2.fromOffset(c.X, c.Y - (pull and d * 0.6 or 0)), ZIndex = 10}, root)
	corner(finger, d)
	stroke(finger, WHITE, 0, 3)
	if pull then
		TweenService:Create(finger, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, -1),
			{Position = UDim2.fromOffset(c.X, c.Y + d * 1.4)}):Play()
	else
		TweenService:Create(finger, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{Size = UDim2.fromOffset(d * 0.7, d * 0.7)}):Play()
	end
end

-- ---------- the egg (step 2) ----------
local render -- below
local egg = {state = "idle", t = 0}
local function drawEgg()
	local e = make("TextButton", {Name = "Egg", Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.fromRGB(247, 236, 205),
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.6), Size = UDim2.fromOffset(15 * ch, 19 * ch), Modal = true}, root)
	corner(e, 9 * ch)
	make("UIGradient", {Color = ColorSequence.new(Color3.fromRGB(255, 250, 235), Color3.fromRGB(196, 168, 110)), Rotation = 60}, e)
	stroke(e, Color3.fromRGB(120, 96, 56), 0.3, 2)
	local crack = label(e, "╱╲╱╲╱", Enum.Font.GothamBlack, 3 * ch, Color3.fromRGB(91, 70, 40), {Name = "Crack",
		Size = UDim2.new(1, 0, 0, 4 * ch), Position = UDim2.fromScale(0, 0.42), Visible = egg.state ~= "idle", TextWrapped = false})
	local hint
	if egg.state == "idle" then
		local d = 3.2 * ch
		local f = make("Frame", {BackgroundColor3 = WHITE, BackgroundTransparency = 0.2, AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.62, 0.66), Size = UDim2.fromOffset(d, d)}, e)
		corner(f, d)
		TweenService:Create(f, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{Size = UDim2.fromOffset(d * 0.65, d * 0.65)}):Play()
		hint = f
	else
		TweenService:Create(e, TweenInfo.new(0.07, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1, true), {Rotation = 7}):Play()
	end
	e.Activated:Connect(function()
		if egg.state ~= "idle" then return end
		egg.state, egg.t = "shaking", os.clock()
		send("roll")
		task.delay(0.8, function() if egg.state == "shaking" then crack.Visible = true end end)
		task.delay(1.5, function()
			egg.state = "hatched"
			if step() == 2 then task.defer(render) end
		end)
		if hint then hint:Destroy() end
		TweenService:Create(e, TweenInfo.new(0.07, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1, true), {Rotation = 7}):Play()
	end)
end

-- ---------- render ----------
local lastSpentId = nil
local fullRetry = false
function render()
	root:ClearAllChildren()
	finger = nil
	local s = step()
	gui.Enabled = s > 0
	player:SetAttribute("TutClientStep", s)
	updateMark()
	if s <= 0 then return end
	W, H = root.AbsoluteSize.X, root.AbsoluteSize.Y
	if W < 10 then W, H = workspace.CurrentCamera.ViewportSize.X, workspace.CurrentCamera.ViewportSize.Y end
	ch = H / 100
	local dino = dinoKey()
	local replay = player:GetAttribute("TutReplay") == true
	local unlockText = ReplicatedStorage:GetAttribute("TutUnlockTextOn") == true
	if s == 1 then
		card("WELCOME!", {"Your first dino is free."}, "ROLL", function() send("next") end)
	elseif s == 2 then
		local rolled = player:GetAttribute("TutRolled") or ""
		if rolled ~= "" and egg.state ~= "shaking" then
			local lines = {{text = string.upper(dinoName(rolled)) .. "!", big = true}}
			if unlockText then table.insert(lines, "It's yours. More dinos unlock with skill points.") else table.insert(lines, "It's yours.") end
			card("IT HATCHED!", lines, "NEXT", function() send("next") end)
		else
			veil()
			card("YOUR FREE DINO", {"Tap the egg."}, nil, nil, {noVeil = true, pos = UDim2.fromScale(0.5, 0.24)})
			drawEgg()
		end
	elseif s == 3 then
		local free = player:GetAttribute("FreeDino")
		local key = (type(free) == "string" and free ~= "") and free or dino
		local ids = partsOf(key, false)
		card(#ids .. " MECHA PARTS", {"All maxed out."}, "TO TRAINING", function()
			send("next")
			fullRetry = true
		end, {extra = function(f)
			local g = make("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y}, f)
			make("UIGridLayout", {CellSize = UDim2.new(0.32, 0, 0, math.max(4.6 * ch, 28)), CellPadding = UDim2.new(0.02, 0, 0, 0.8 * ch),
				SortOrder = Enum.SortOrder.LayoutOrder}, g)
			for i, id in ipairs(ids) do
				local t = label(g, pname(id) .. "  <font color=\"#ffc832\">★</font>", Enum.Font.GothamBold, math.max(1.6 * ch, 10), WHITE,
					{BackgroundTransparency = 0, BackgroundColor3 = PANEL2, LayoutOrder = i})
				corner(t, 0.8 * ch)
			end
			if player:GetAttribute("TutLastResult") == "full" then
				label(g, "Training is full. Trying again.", Enum.Font.GothamBold, math.max(1.6 * ch, 10), ORANGE, {LayoutOrder = 99})
			end
			return g
		end})
	elseif s == 4 or s == 6 or s == 7 then
		checklist()
		if s == 4 then
			local k, a = attackPrompt()
			prompt(k, a)
			local hit = player:GetAttribute("TutHit") == true
			local atk = (ATTACK[dino] or {"attack"})[1]
			trainer("See that bot? Hit it with your " .. atk .. ".", hit and "NEXT" or nil, function() send("next") end)
		elseif s == 6 then
			local used, n = usedSet(), need()
			local nextI
			for i = 1, n do if not used[i] then nextI = i break end end
			if not nextI then
				trainer(n == 4 and "All 4 done." or "All done.", "NEXT", function() send("next") end)
			else
				local part = pname(slotOf(nextI))
				if not isTouch() then
					prompt(SLOT_KEYS[nextI], part)
					trainer("Now try your parts.")
				else
					local pull = nextI > 2
					prompt(pull and "Pull down" or "Tap", (pull and "▼ " or "") .. part)
					local line = "Tap a button to use its part."
					if pull then line = (used[3] or used[4]) and "Pull down again." or "Each button has a second part. Pull it down." end
					trainer(line)
					showFinger(pull and nextI - 2 or nextI, pull)
				end
			end
		else
			if player:GetAttribute("TutKilled") == true then
				if replay then
					card("BOT DOWN", {"No XP in a replay."}, "NEXT", function() send("next") end)
				else
					card("LEVEL " .. tostring(player:GetAttribute("SkillLevel") or 2), {"+1 skill point"}, "SPEND IT", function() send("next") end)
				end
			else
				local k, a = attackPrompt()
				prompt(k, a)
				trainer("Finish it!")
			end
		end
	elseif s == 5 then
		local n = need()
		local f = panel("LAB · EQUIP PARTS", isTouch() and "2 buttons, 2 parts each. Tap for the top one. Pull down for the bottom one."
			or "Your slots are R, C, T and V.")
		local ids = partsOf(dino, true)
		local g = make("Frame", {BackgroundTransparency = 1, Position = UDim2.fromOffset(2.4 * ch, 10 * ch), Size = UDim2.new(1, -4.8 * ch, 0, 30 * ch)}, f)
		make("UIGridLayout", {CellSize = UDim2.new(0.32, 0, 0, math.max(6 * ch, 34)), CellPadding = UDim2.new(0.02, 0, 0, ch),
			SortOrder = Enum.SortOrder.LayoutOrder}, g)
		local inSlot = {}
		for k = 1, 4 do inSlot[slotOf(k)] = k end
		for i, id in ipairs(ids) do
			local b = make("TextButton", {Text = pname(id) .. "\n<font color=\"#ffc832\">" .. ROMAN[math.clamp(pathStep(id), 1, 4)] .. "</font>",
				RichText = true, Font = Enum.Font.GothamBold, TextSize = math.max(1.7 * ch, 10), TextColor3 = inSlot[id] and MUTED or WHITE,
				BackgroundColor3 = PANEL2, AutoButtonColor = true, LayoutOrder = i}, g)
			corner(b, ch)
			stroke(b, inSlot[id] and LINE or ORANGE, 0, 2)
			b.Activated:Connect(function()
				if inSlot[id] or not skillRemote then return end
				for k = 1, 4 do
					if slotOf(k) == "" then skillRemote:FireServer("slot", k, id) return end
				end
			end)
		end
		local row = make("Frame", {BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 2.4 * ch, 1, -2 * ch),
			Size = UDim2.new(1, -4.8 * ch, 0, 8 * ch)}, f)
		make("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, ch), SortOrder = Enum.SortOrder.LayoutOrder}, row)
		local labels = isTouch() and {"BUTTON 1 · TAP", "BUTTON 2 · TAP", "BUTTON 1 · PULL ▼", "BUTTON 2 · PULL ▼"}
			or {"KEY R", "KEY C", "KEY T", "KEY V"}
		for k = 1, 4 do
			local id = slotOf(k)
			local b = make("TextButton", {Text = (id ~= "" and pname(id) or "EMPTY") .. "\n<font color=\"#ff9b2e\">" .. labels[k] .. "</font>",
				RichText = true, Font = Enum.Font.GothamBold, TextSize = math.max(1.6 * ch, 10), TextColor3 = id ~= "" and WHITE or MUTED,
				BackgroundColor3 = Color3.fromRGB(16, 20, 28), Size = UDim2.new(0.25, -ch, 1, 0), LayoutOrder = k}, row)
			corner(b, ch)
			stroke(b, id ~= "" and ORANGE or LINE, 0, 2)
			b.Activated:Connect(function() if id ~= "" and skillRemote then skillRemote:FireServer("slot", k, "") end end)
		end
		local filled = 0
		for k = 1, n do if slotOf(k) ~= "" then filled += 1 end end
		if n == 0 then
			trainer("No parts yet.", "NEXT", function() send("next") end)
		elseif filled >= n then
			trainer("Good. Now try them.", "TRY THEM", function() send("next") end)
		else
			trainer("Pick " .. n .. ". " .. (n - filled) .. " left.")
		end
	elseif s == 8 then
		local f = panel("LAB · " .. string.upper(dinoName(dino)) .. " STATS", "Spend your point.")
		local left = tonumber(player:GetAttribute("SkillLeft")) or 0
		local spentNow = (tonumber(player:GetAttribute("SkillSpent")) or 0) > (tonumber(player:GetAttribute("TutPtsStart")) or 0)
		local list = make("Frame", {BackgroundTransparency = 1, Position = UDim2.fromOffset(2.4 * ch, 10 * ch), Size = UDim2.new(0.66, 0, 0, 50 * ch)}, f)
		make("UIListLayout", {Padding = UDim.new(0, 0.8 * ch), SortOrder = Enum.SortOrder.LayoutOrder}, list)
		for i, id in ipairs(statsOf(dino)) do
			local n = pathStep(id)
			local r = make("Frame", {BackgroundColor3 = PANEL2, Size = UDim2.new(1, 0, 0, math.max(5 * ch, 30)), LayoutOrder = i}, list)
			corner(r, ch)
			label(r, pname(id), Enum.Font.GothamBold, math.max(1.9 * ch, 11), WHITE, {Position = UDim2.fromOffset(1.4 * ch, 0),
				Size = UDim2.new(0.6, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Left})
			label(r, n > 0 and ROMAN[n] or "-", Enum.Font.GothamBlack, math.max(1.9 * ch, 11), n > 0 and GREEN or MUTED,
				{Position = UDim2.new(0.62, 0, 0, 0), Size = UDim2.new(0.16, 0, 1, 0)})
			if n < 4 and left > 0 then
				local b = button(r, "+", function()
					lastSpentId = id
					if skillRemote then skillRemote:FireServer("buy", id) end
				end, {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -0.8 * ch, 0.5, 0), AutomaticSize = Enum.AutomaticSize.None,
					Size = UDim2.fromOffset(math.max(6 * ch, 34), math.max(3.8 * ch, 24))})
				b:FindFirstChildOfClass("UIPadding"):Destroy()
			end
		end
		local box = make("Frame", {BackgroundColor3 = PANEL2, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -2.4 * ch, 0, 10 * ch),
			Size = UDim2.new(0.26, 0, 0, 18 * ch)}, f)
		corner(box, ch)
		label(box, tostring(left), Enum.Font.FredokaOne, math.max(6 * ch, 30), YELLOW, {Size = UDim2.new(1, 0, 0, 7 * ch), Position = UDim2.fromOffset(0, ch)})
		label(box, (left == 1 and "SKILL POINT" or "SKILL POINTS") .. "\n1 every level. Kills give XP.", Enum.Font.GothamBold,
			math.max(1.6 * ch, 10), WHITE, {Size = UDim2.new(1, -2 * ch, 0, 8 * ch), Position = UDim2.fromOffset(ch, 8.5 * ch)})
		if spentNow then
			trainer((lastSpentId and pname(lastSpentId) or "Your stat") .. " went up.", "NEXT", function() send("next") end)
		elseif replay and left == 0 then
			trainer("No points to spend.", "NEXT", function() send("next") end)
		else
			trainer("Tap + on a stat.")
		end
	elseif s == 9 then
		checklist()
		card("SKILL POINTS", {"1 every level."}, "GOT IT", function() send("next") end, {noVeil = true,
			pos = UDim2.new(0.5, 11 * ch, 0.5, 0), w = math.min(0.7 * W, W - 30 * ch), extra = function(f)
			local g = make("Frame", {BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 14 * ch)}, f)
			make("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, ch), SortOrder = Enum.SortOrder.LayoutOrder}, g)
			local tiles = {{"UPGRADE STATS", "Health, attack, armor, speed."}, {"UPGRADE PARTS", "Parts go from I to ★."},
				{"UNLOCK DINOS", unlockText and "Points from any dino count." or "Coming soon."}}
			for i, t in ipairs(tiles) do
				local tf = make("Frame", {BackgroundColor3 = PANEL2, Size = UDim2.new(1 / 3, -ch, 1, 0), LayoutOrder = i}, g)
				corner(tf, ch)
				label(tf, t[1], Enum.Font.GothamBlack, math.max(1.7 * ch, 10), WHITE, {Position = UDim2.fromOffset(ch, ch),
					Size = UDim2.new(1, -2 * ch, 0, 2.4 * ch), TextXAlignment = Enum.TextXAlignment.Left})
				label(tf, t[2], Enum.Font.GothamBold, math.max(1.6 * ch, 10), MUTED, {Position = UDim2.fromOffset(ch, 4 * ch),
					Size = UDim2.new(1, -2 * ch, 1, -5 * ch), TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top})
			end
			return g
		end})
	elseif s == 10 then
		card("TRAINING DONE", {"Level " .. tostring(player:GetAttribute("SkillLevel") or 1) .. " " .. dinoName(dino)}, "GO TO THE ISLAND",
			function() send("island") end)
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
	TutReplay = true, TutLastResult = true, SkillSpent = true, SkillLeft = true, SkillLevel = true, FreeDino = true,
	SkillSlot1 = true, SkillSlot2 = true, SkillSlot3 = true, SkillSlot4 = true}
player.AttributeChanged:Connect(function(name)
	if name == "TutStep" then
		egg.state = "idle"
		if step() ~= 8 then lastSpentId = nil end
	end
	if WATCH[name] or (step() == 5 and name:sub(1, 10) == "SkillPath_") then queue() end
end)
ReplicatedStorage:GetAttributeChangedSignal("TutUnlockTextOn"):Connect(queue)
root:GetPropertyChangedSignal("AbsoluteSize"):Connect(queue)

-- step 6: each part used (MechaButtonsLastPress lives on the character, written by MechaButtons on this client)
local charConn
local function onChar(c)
	if charConn then charConn:Disconnect() end
	charConn = c:GetAttributeChangedSignal("MechaButtonsLastPress"):Connect(function()
		if step() ~= 6 then return end
		local n, id = string.match(c:GetAttribute("MechaButtonsLastPress") or "", "^slot(%d):(.+)$")
		n = tonumber(n)
		if n and n <= need() and id ~= "empty" then send("used", n) end
	end)
	c:GetAttributeChangedSignal("Species"):Connect(queue)
	queue()
end
player.CharacterAdded:Connect(onChar)
if player.Character then onChar(player.Character) end

-- the bot marks and the "full" retry
task.spawn(function()
	local lastRetry = 0
	while true do
		task.wait(0.2)
		if step() > 0 then updateMark() end
		if step() == 3 and fullRetry and player:GetAttribute("TutLastResult") == "full" and os.clock() - lastRetry > 3 then
			lastRetry = os.clock()
			send("next")
		end
		if step() ~= 3 then fullRetry = false end
	end
end)
render()
