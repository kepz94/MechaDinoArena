-- welcome_patch1 (WELCOME_MOVES v1.0 Tasks 2-4, MDA-594/595/596): Tutorial 1.7 welcome screen, roster title + PASSIVE, reveal PASSIVE.
local PAIRS = {
{[=====[script:SetAttribute("TutorialClientVersion", VERSION)]=====], [=====[VERSION = "1.7" -- v1.7 welcome screen, dino passives, JUMP parts in step 6
-- v1.7 (plan docs/plans/WELCOME_MOVES_v1.0.md, MDA-594..597, mockup docs/mockups/welcome_moves_v0.2.html; Kepu 2026-11-26 after his
--   first-time walkthrough: "the tutorial didn't explain that wings work through the jump button ... can climb up trees ... a
--   welcome to mecha Dino, then a here's our roster screen"; picks "A", "Just have the climbing ability in the description of
--   the Dino attack ability as a passive", "for mecha parts that's just a different mechanic to use it", "Show SKIP after
--   20 s"; "Build" 02:36). State lives in the script-global table WM (the main chunk is near its local limit).
--   * Welcome (MDA-594, script attribute TutorialWelcomeEnabled, default true, read per draw): at step 1, before the roster
--     (the 1.5 showcase), while showcaseOn(): "WELCOME TO" / "MECHA DINO ARENA" ("DINO" yellow), 3 tiles dealt in (FIGHT
--     "Squad battles on the island", UPGRADE "Mecha parts and skill points", COLLECT "7 dinos, skins, emotes, trails"),
--     LET'S GO -> WM.welcomed = true -> the roster. Client only, once per join (like the roster). Scene key "welcome".
--   * Roster (MDA-595): TutorialRosterTitleEnabled: "MEET THE ROSTER" / "1 OF THESE 7 IS YOURS FREE" (was "YOUR FIRST DINO" /
--     "1 OF THESE 7 · FREE"); TutorialRosterPassiveEnabled: a PASSIVE section under MAIN ATTACK with one card per
--     TutorialRules 1.3 passivesFor(dino) (green bar, name, tag chip PASSIVE / ON JUMP, the line on 2 rows at most); none
--     for a dino without one. The ABILITIES list gets the height that is left (min as 1.5).
--   * Reveal (MDA-596, TutorialRevealPassiveEnabled): "PASSIVE" (green) + one row per passive under MAIN ATTACK (a green tag
--     pill, the name, the line). Fit: if the panel's content is taller than the panel, the line steps down to 12 px, then
--     is cut to one row (NEXT is never pushed out).
script:SetAttribute("TutorialClientVersion", VERSION)]=====]},
{[=====[local function incubatorKey(s)]=====], [=====[-- v1.7: the welcome screen (see the header)
WM = {welcomed = false, jpN = nil, jpSince = 0, jpTapAt = -100, jpTok = 0}
for _, k in ipairs({"TutorialWelcomeEnabled", "TutorialRosterTitleEnabled", "TutorialRosterPassiveEnabled", "TutorialRevealPassiveEnabled",
	"TutorialJumpPartsEnabled"}) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, true) end
end
if script:GetAttribute("TutJumpPartSkipAfter") == nil then script:SetAttribute("TutJumpPartSkipAfter", 20) end
local function welcomeOn() return script:GetAttribute("TutorialWelcomeEnabled") ~= false end
local function drawWelcome()
	backdrop()
	local function cq(n, mn) return math.max(W * n / 100, mn or 0) end
	local head = make("Frame", {Name = "WelcomeHead", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), ZIndex = 5,
		Position = UDim2.new(0.5, 0, 0, math.max(topH + px(0.6, 4), H * 0.14)), Size = UDim2.new(0.9, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y}, root)
	list(head, nil, px(0.5, 4))
	text(head, "WELCOME TO", "black", cq(1.6, 11), C.cyan, {LayoutOrder = 1, TextWrapped = false})
	text(head, 'MECHA <font color="#FFC832">DINO</font> ARENA', "title", cq(6.4, 32), C.white, {LayoutOrder = 2})
	local tw, gap = cq(19, 118), cq(1.6, 10)
	local th = cq(13.5, 96)
	local row = make("Frame", {Name = "Tiles", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), ZIndex = 5,
		Position = UDim2.new(0.5, 0, 0, H * 0.43), Size = UDim2.fromOffset(tw * 3 + gap * 2, th)}, root)
	list(row, Enum.FillDirection.Horizontal, gap)
	local TILES = {{"\u{2694}", "FIGHT", "Squad battles on the island"}, {"\u{2699}", "UPGRADE", "Mecha parts and skill points"},
		{"\u{2605}", "COLLECT", "7 dinos, skins, emotes, trails"}}
	for i, t in ipairs(TILES) do
		local holder = make("Frame", {Name = "Slot" .. i, BackgroundTransparency = 1, LayoutOrder = i, Size = UDim2.fromOffset(tw, th)}, row)
		local card = make("Frame", {Name = "Tile", BackgroundColor3 = C.card, Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(0, px(2, 14)),
			BackgroundTransparency = 1}, holder)
		corner(card, UDim.new(0, px(1.4, 10)))
		local st = stroke(card, C.line, px(0.25, 2), 1)
		pad(card, px(1, 8), px(1, 8))
		list(card, nil, px(0.4, 3)).VerticalAlignment = Enum.VerticalAlignment.Top
		local parts = {
			text(card, t[1], "black", cq(3.2, 22), C.yellow, {LayoutOrder = 1, TextWrapped = false, TextTransparency = 1}),
			text(card, t[2], "title", cq(1.9, 14), C.white, {LayoutOrder = 2, TextTransparency = 1}),
			text(card, t[3], "body", cq(1.15, 10), C.muted, {LayoutOrder = 3, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0),
				TextTransparency = 1}),
		}
		task.delay(0.12 * (i - 1), function()
			if not card.Parent then return end
			tween(card, 0.45, {BackgroundTransparency = 0, Position = UDim2.fromOffset(0, 0)})
			tween(st, 0.45, {Transparency = 0})
			for _, l in ipairs(parts) do tween(l, 0.45, {TextTransparency = 0}) end
		end)
	end
	local b = cta(root, "LET'S GO", function()
		WM.welcomed = true
		pod.sceneKey = nil
		task.defer(function() render() end)
	end, {AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -cq(3.4, 18))})
	b.Name = "LetsGo"
	b.ZIndex = 8
end
local function incubatorKey(s)]=====]},
{[=====[	if s == 1 and rolled == "" and pod.phase ~= "open" then scene = (showcaseOn() and not pod.showcased) and "showcase" or "charge" end -- v1.4
]=====], [=====[	if s == 1 and rolled == "" and pod.phase ~= "open" then scene = (showcaseOn() and not pod.showcased) and "showcase" or "charge" end -- v1.4
	if scene == "showcase" and welcomeOn() and not WM.welcomed then scene = "welcome" end -- v1.7
]=====]},
{[=====[			if showcase2On() then drawShowcase2() else drawShowcase() end -- v1.5]=====], [=====[			if welcomeOn() and not WM.welcomed then drawWelcome() -- v1.7
			elseif showcase2On() then drawShowcase2() else drawShowcase() end -- v1.5]=====]},
{[=====[	text(tb, "YOUR FIRST DINO", "title", cq(3, 20), C.white, {LayoutOrder = 2, ZIndex = 6})
	text(tb, ("1 OF THESE %d \u{00B7} FREE"):format(#R.ROLL_POOL), "black", cq(1.2, 9), C.text, {LayoutOrder = 3, ZIndex = 6})]=====], [=====[	local rosterT = script:GetAttribute("TutorialRosterTitleEnabled") ~= false -- v1.7
	text(tb, rosterT and "MEET THE ROSTER" or "YOUR FIRST DINO", "title", cq(3, 20), C.white, {LayoutOrder = 2, ZIndex = 6})
	text(tb, (rosterT and "1 OF THESE %d IS YOURS FREE" or "1 OF THESE %d \u{00B7} FREE"):format(#R.ROLL_POOL), "black", cq(1.2, 9), C.text,
		{LayoutOrder = 3, ZIndex = 6})]=====]},
{[=====[		y += cardH + gap
		local ids = partsOf(key, false, true)]=====], [=====[		y += cardH + gap
		local pss = script:GetAttribute("TutorialRosterPassiveEnabled") ~= false and R.passivesFor(key) or {} -- v1.7: PASSIVE
		if #pss > 0 then
			local _, shp = section(body, "PASSIVE", y)
			y += shp + gap * 0.6
			for _, P in ipairs(pss) do
				local tsz = TextService:GetTextSize(P.line, lineS, Enum.Font.GothamBold, Vector2.new(iw - p0 * 3.5, 1000))
				local lineH = lineS * 1.3 * math.clamp(math.ceil(tsz.Y / (lineS * 1.05) - 0.01), 1, 2)
				local ph = p0 * 2 + cq(1.5, 12) * 1.15 + lineH
				local pc = z(make("Frame", {Name = "Passive", BackgroundColor3 = C.card, Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, 0, 0, ph)}, body), 5)
				corner(pc, UDim.new(0, px(0.7, 5)))
				stroke(pc, C.line, 1)
				z(make("Frame", {BackgroundColor3 = C.green, BorderSizePixel = 0, Size = UDim2.new(0, px(0.45, 3), 1, 0)}, pc), 6)
				text(pc, P.n, "title", cq(1.5, 12), C.white, {Position = UDim2.fromOffset(p0 * 2, p0), TextWrapped = false, ZIndex = 7})
				local tg = text(pc, " " .. P.tag .. " ", "black", cq(0.95, 8), C.ink, {BackgroundTransparency = 0, BackgroundColor3 = C.green,
					AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -p0 * 1.5, 0, p0), TextWrapped = false, ZIndex = 7})
				corner(tg, UDim.new(0, px(0.4, 3)))
				lbl(pc, P.line, Enum.Font.GothamBold, lineS, C.text, {Position = UDim2.fromOffset(p0 * 2, p0 + cq(1.5, 12) * 1.15),
					Size = UDim2.new(1, -p0 * 3.5, 0, lineH), TextWrapped = true, TextTruncate = Enum.TextTruncate.AtEnd})
				y += ph + gap
			end
		end
		local ids = partsOf(key, false, true)]=====]},
{[=====[	if ReplicatedStorage:GetAttribute("TutUnlockTextOn") == true then
		text(panel, "More dinos unlock with skill points.", "body", px(1.4, 12), C.muted, {LayoutOrder = 20})
	end
	local nb = cta(panel, "NEXT", function() send("next") end, {LayoutOrder = 21})]=====], [=====[	local pss = script:GetAttribute("TutorialRevealPassiveEnabled") ~= false and R.passivesFor(rolled) or {} -- v1.7: PASSIVE
	if #pss > 0 then
		text(panel, "PASSIVE", "title", px(1.9, 14), C.green, {LayoutOrder = 12})
		local slotW = px(9, 66)
		for i, P in ipairs(pss) do
			local row = make("Frame", {Name = "Passive", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = 12 + i}, panel)
			local tg = text(row, " " .. P.tag .. " ", "black", px(1.3, 11), C.ink, {BackgroundTransparency = 0, BackgroundColor3 = C.green,
				TextWrapped = false, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(slotW / 2, px(0.4, 3))})
			corner(tg, UDim.new(0.5, 0))
			pad(tg, px(0.4, 3), px(0.6, 4))
			local col = make("Frame", {BackgroundTransparency = 1, Position = UDim2.fromOffset(slotW + px(1.4, 8), 0), Size = UDim2.new(1, -slotW - px(1.4, 8), 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y}, row)
			list(col, nil, px(0.2, 2), Enum.HorizontalAlignment.Left).VerticalAlignment = Enum.VerticalAlignment.Top
			text(col, P.n, "black", px(2.1, 16), C.white, {LayoutOrder = 1, TextWrapped = false})
			local ln = text(col, P.line, "body", px(1.8, 14), C.muted, {LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
				TextXAlignment = Enum.TextXAlignment.Left})
			task.defer(function() -- fit: never push NEXT out of the panel
				local lay = panel:FindFirstChildOfClass("UIListLayout")
				if not (lay and ln.Parent) or lay.AbsoluteContentSize.Y <= panel.AbsoluteSize.Y then return end
				ln.TextSize = 12
				task.defer(function()
					if ln.Parent and lay.AbsoluteContentSize.Y > panel.AbsoluteSize.Y then
						ln.AutomaticSize = Enum.AutomaticSize.None
						ln.Size = UDim2.new(1, 0, 0, math.ceil(ln.TextSize * 1.25))
						ln.TextTruncate = Enum.TextTruncate.AtEnd
					end
				end)
			end)
		end
	end
	if ReplicatedStorage:GetAttribute("TutUnlockTextOn") == true then
		text(panel, "More dinos unlock with skill points.", "body", px(1.4, 12), C.muted, {LayoutOrder = 20})
	end
	local nb = cta(panel, "NEXT", function() send("next") end, {LayoutOrder = 21})]=====]},
}
local s = sc.Source
for k, pr in ipairs(PAIRS) do
	local a, b = string.find(s, pr[1], 1, true)
	assert(a, "miss " .. k .. ": " .. pr[1]:sub(1, 60))
	assert(not string.find(s, pr[1], b + 1, true), "dup " .. k)
	s = s:sub(1, a - 1) .. pr[2] .. s:sub(b + 1)
end
sc.Source = s
local h = 0 for i = 1, #s do h = (h * 31 + s:byte(i)) % 2147483647 end
return #s .. " " .. h
