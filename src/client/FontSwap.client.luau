-- FontSwap v1.0 (Mecha Dino Arena) — Silkscreen for the game's short, loud text (LocalScript, StarterPlayerScripts; plan
-- docs/plans/FONT_SILKSCREEN_v1.0.md Task 2, MDA-450; Kepu 2026-11-11 "Let's use SilkScreen font" -> "B · Titles, buttons,
-- numbers", "Shrink to fit"; mockup docs/mockups/font_silkscreen_v0.1.html).
-- Silkscreen = Roblox font library asset 12187371840 (creator Roblox, free; Bold weight used).
-- Watches every TextLabel / TextButton under this player's PlayerGui and in BillboardGuis / SurfaceGuis in Workspace (no other
-- script is edited). FontSwapRules.classify decides per text (font, text, wrapping, scaling, the instance attribute FontSwap
-- "keep" / "silk"); "silk" -> FontFace Silkscreen Bold and, unless TextScaled, TextSize = FontSwapRules.fitSize(its own size,
-- the fit factor of its original font) so it takes the space the old text did. Re-checked when Text, TextWrapped, TextScaled or
-- the font change (a script setting a new font or size makes that the label's own). "keep" puts the original font and size back.
-- Fit factor per original font = width of "MECHA ABILITIES 0123456789" at size 40 in that font / in Silkscreen Bold
-- (TextService:GetTextBoundsAsync, measured once at start; FontSwapRules.FIT_DEFAULT until then).
-- A swapped text carries its original font and size as attributes (FontSwapFrom "family|weight|style|EnumName",
--   FontSwapSize), so a copy a script clones from it still knows its own font (and is not shrunk twice).
-- Switch: script attribute FontSwapEnabled (default true, read live: false puts every original font and size back).
-- Diagnostics (LocalPlayer): FontSwapVersion, FontSwapCount (texts in Silkscreen now), FontSwapKept (texts checked and kept),
--   FontSwapFit ("FredokaOne 0.86, ...").
local Players = game:GetService("Players")
local TextService = game:GetService("TextService")
local ContentProvider = game:GetService("ContentProvider")

local VERSION = "1.0"
local SILK_ID = "rbxassetid://12187371840"
local player = Players.LocalPlayer
local Rules = require(script.Parent:WaitForChild("FontSwapRules"))
if script:GetAttribute("FontSwapEnabled") == nil then script:SetAttribute("FontSwapEnabled", true) end
player:SetAttribute("FontSwapVersion", VERSION)

local SILK = Font.new(SILK_ID, Enum.FontWeight.Bold)
local fit = {} -- [original Enum.Font name] = factor
local st = setmetatable({}, {__mode = "k"}) -- [text object] = {face, name, size, mine, silk, busy}

local function enabled() return script:GetAttribute("FontSwapEnabled") ~= false end

local function setFace(o, s, face)
	s.busy = true
	o.FontFace = face
	s.busy = false
end
local function setSize(o, s, size)
	s.busy = true
	o.TextSize = size
	s.busy = false
end

local function evaluate(o)
	local s = st[o]
	if not s or not o.Parent then return end
	local want = "keep"
	if enabled() then
		local ov = o:GetAttribute("FontSwap")
		want = Rules.classify({font = s.name, text = o.Text, wrapped = o.TextWrapped, scaled = o.TextScaled,
			isBox = o:IsA("TextBox"), override = type(ov) == "string" and ov or nil})
	end
	if want == "silk" then
		if not s.silk then
			s.silk = true
			o:SetAttribute("FontSwapFrom", ("%s|%s|%s|%s"):format(s.face.Family, s.face.Weight.Name, s.face.Style.Name, s.name))
			o:SetAttribute("FontSwapSize", s.size)
			setFace(o, s, SILK)
		end
		if not o.TextScaled then
			local m = Rules.fitSize(s.size, fit[s.name])
			if o.TextSize ~= m then
				s.mine = m
				setSize(o, s, m)
			end
		end
	elseif s.silk then
		s.silk = false
		setFace(o, s, s.face)
		if not o.TextScaled and o.TextSize ~= s.size then setSize(o, s, s.size) end
		s.mine = nil
	end
end

local function track(o)
	if st[o] or not (o:IsA("TextLabel") or o:IsA("TextButton")) then return end
	local s = {face = o.FontFace, name = o.Font.Name, size = o.TextSize, silk = false, busy = false}
	local from = o:GetAttribute("FontSwapFrom")
	if o.FontFace.Family == SILK_ID and type(from) == "string" then -- a clone of a swapped text: take its original back
		local fam, w, sty, name = string.match(from, "^(.-)|(.-)|(.-)|(.-)$")
		local ok, face = pcall(function() return Font.new(fam, Enum.FontWeight[w], Enum.FontStyle[sty]) end)
		if ok and face then
			s.face, s.name, s.silk, s.mine = face, name, true, o.TextSize
			s.size = tonumber(o:GetAttribute("FontSwapSize")) or o.TextSize
		end
	end
	st[o] = s
	o:GetPropertyChangedSignal("Text"):Connect(function() evaluate(o) end)
	o:GetPropertyChangedSignal("TextWrapped"):Connect(function() evaluate(o) end)
	o:GetPropertyChangedSignal("TextScaled"):Connect(function() evaluate(o) end)
	o:GetPropertyChangedSignal("FontFace"):Connect(function()
		if s.busy then return end
		-- (signals can arrive deferred: our own Silkscreen set, or our restore to the original, is not a script's change)
		if s.silk and o.FontFace.Family == SILK_ID then return end
		if not s.silk and o.FontFace == s.face then return end
		-- a script set a new font: that is the label's own font now
		s.face, s.name, s.silk = o.FontFace, o.Font.Name, false
		evaluate(o)
	end)
	o:GetPropertyChangedSignal("TextSize"):Connect(function()
		if s.busy or o.TextSize == s.mine or (not s.silk and o.TextSize == s.size) then return end
		s.size = o.TextSize -- a script set a new size: its own size now
		if s.silk then
			o:SetAttribute("FontSwapSize", s.size)
			evaluate(o)
		end
	end)
	o:GetAttributeChangedSignal("FontSwap"):Connect(function() evaluate(o) end)
	evaluate(o)
end

local function inWorldGui(o)
	return o:FindFirstAncestorWhichIsA("BillboardGui") ~= nil or o:FindFirstAncestorWhichIsA("SurfaceGui") ~= nil
end

-- the font file, then the fit factors
task.spawn(function()
	local probe = Instance.new("TextLabel")
	probe.FontFace = SILK
	probe.Text = "MECHA"
	pcall(function() ContentProvider:PreloadAsync({probe}) end)
	probe:Destroy()
	local SAMPLE = "MECHA ABILITIES 0123456789"
	local function width(font)
		local ok, v = pcall(function()
			local p = Instance.new("GetTextBoundsParams")
			p.Text, p.Font, p.Size, p.Width = SAMPLE, font, 40, 100000
			return TextService:GetTextBoundsAsync(p).X
		end)
		return ok and v or nil
	end
	local ws = width(SILK)
	local parts = {}
	if ws and ws > 0 then
		for name in pairs(Rules.LOUD) do
			local ok, enum = pcall(function() return Enum.Font[name] end)
			local w = ok and width(Font.fromEnum(enum)) or nil
			if w then
				fit[name] = math.clamp(w / ws, Rules.FIT_MIN, 1)
				table.insert(parts, ("%s %.2f"):format(name, fit[name]))
			end
		end
	end
	table.sort(parts)
	player:SetAttribute("FontSwapFit", #parts > 0 and table.concat(parts, ", ") or "default " .. Rules.FIT_DEFAULT)
	for o in pairs(st) do evaluate(o) end -- re-fit with the measured factors
end)

local pg = player:WaitForChild("PlayerGui")
for _, o in ipairs(pg:GetDescendants()) do track(o) end
pg.DescendantAdded:Connect(track)
for _, o in ipairs(workspace:GetDescendants()) do
	if (o:IsA("TextLabel") or o:IsA("TextButton")) and inWorldGui(o) then track(o) end
end
workspace.DescendantAdded:Connect(function(o)
	if (o:IsA("TextLabel") or o:IsA("TextButton")) and inWorldGui(o) then track(o) end
end)

script:GetAttributeChangedSignal("FontSwapEnabled"):Connect(function()
	for o in pairs(st) do evaluate(o) end
end)

-- diagnostics
task.spawn(function()
	while script.Parent do
		local n, k = 0, 0
		for o, s in pairs(st) do
			if o.Parent then
				if s.silk then n += 1 else k += 1 end
			end
		end
		player:SetAttribute("FontSwapCount", n)
		player:SetAttribute("FontSwapKept", k)
		task.wait(1)
	end
end)
