-- EmoteFX v1.0 (Mecha Dino Arena) — props and pop-up words for the battle emotes, on every dino in range, local to this client.
-- Plan docs/plans/EMOTES_v1.0.md; looks and timings from mockup docs/mockups/battle_emotes_v0.2.html (Kepu 2026-11-24 "keep all of these").
-- Reads each character's EmoteId / EmoteStartedAt / EmoteDuration (EmoteServer 1.0). Joints are moved by EmotePose 1.0 (IdleAnimation 1.48).
-- Props: anchored local Parts placed every frame from the segment Root they belong to (Head: chef hat, party hat, shades; L hand =
--   ArmL Root, HandL on the Therizino: pan, mic, teacup, sign; above the Torso: halo). Sizes come from the dino: hats and shades from the
--   Head_eye parts, hand props from the root height and pushed out a torso half-width so tiny arms and frills never hide them.
-- Words: a BillboardGui on a tiny local part (Font Bangers), styles burst / cool / bubble / zzz, pop with overshoot, rise, fade.
-- Effects: dust rings (Stomp Stomp, Mic Drop), sound rings (Moon Call), droplets (Shake Off), eggs + steam (Cooked), steam (Tea Time),
--   confetti (GG Party). All local parts live in workspace.EmoteFXLocal (not replicated).
-- Switches (script attributes): EmoteFXEnabled (true), EmoteFXRange (120 studs from the camera), EmoteWordsEnabled (true),
--   EmotePropsEnabled (true). Diagnostics: EmoteFXVersion, EmoteFXActive (characters with an emote in range), EmoteFXParts.

-- v1.1 (filler bots, plan docs/plans/FILLER_BOTS_v1.0.md T3, MDA-576): bot models in Workspace.DinoIsland.Bots (practice and
--   filler bots) get the same effects as players through the client module BotChars 1.0 (a stand-in "player" per bot).
--   Switch: script attribute BotFXEnabled (default true; false = 1.0).
local Players = game:GetService("Players")
local BC = (function() -- v1.1 filler bots
	if script:GetAttribute("BotFXEnabled") == nil then script:SetAttribute("BotFXEnabled", true) end
	local ok, m = pcall(function() return require(Players.LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("BotChars", 5)) end)
	return ok and m or nil
end)()
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VERSION = "1.0"
VERSION = "1.1" -- v1.1 filler bots: bots drawn too (BotChars)
local function default(name, v) if script:GetAttribute(name) == nil then script:SetAttribute(name, v) end end
script:SetAttribute("EmoteFXVersion", VERSION)
default("EmoteFXEnabled", true)
default("EmoteFXRange", 120)
default("EmoteWordsEnabled", true)
default("EmotePropsEnabled", true)

local rad, sin, cos, abs, exp, max, min, pi, rnd = math.rad, math.sin, math.cos, math.abs, math.exp, math.max, math.min, math.pi, math.random
local function cl(x, a, b) return min(b or 1, max(a or 0, x)) end
local function sm(x) x = cl(x) return x * x * (3 - 2 * x) end
local function eob(x) x = cl(x) local c1 = 1.70158 local c3 = c1 + 1 return 1 + c3 * (x - 1) ^ 3 + c1 * (x - 1) ^ 2 end
local function popW(t, a, b, inT, outT)
	inT, outT = inT or .22, outT or .15
	if t < a then return 0 elseif t < a + inT then return eob((t - a) / inT) elseif t < b then return 1 end
	return 1 - sm((t - b) / outT)
end
local function pulse(t, a, b, c, d) return sm((t - a) / (b - a)) * (1 - sm((t - c) / (d - c))) end

local folder = workspace:FindFirstChild("EmoteFXLocal")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "EmoteFXLocal"
	folder.Parent = workspace
end

local function part(size, color, mat, shape)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Size = size
	p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	if shape then p.Shape = shape end
	p.Parent = folder
	return p
end
local C = Color3.fromHex

-- ---------- rig anchors (segment Root space; X forward, Y up, Z side) ----------
local function segRoot(char, name)
	local m = char:FindFirstChild(name)
	return m and m:FindFirstChild("Root")
end
local function corners(root, seg, filter)
	local out = {}
	for _, p in ipairs(seg:GetChildren()) do
		if p:IsA("BasePart") and p ~= root and p.Transparency < 1 and (not filter or filter(p)) then
			local rel = root.CFrame:ToObjectSpace(p.CFrame)
			local s = p.Size / 2
			for i = 0, 7 do
				local c = Vector3.new((i % 2 == 1) and s.X or -s.X, (math.floor(i / 2) % 2 == 1) and s.Y or -s.Y, (i >= 4) and s.Z or -s.Z)
				table.insert(out, rel * c)
			end
		end
	end
	return out
end
local function bounds(pts)
	if #pts == 0 then return nil end
	local lo, hi = pts[1], pts[1]
	for _, v in ipairs(pts) do lo, hi = lo:Min(v), hi:Max(v) end
	return lo, hi
end
local function rigOf(char)
	local hrp = char:FindFirstChild("HumanoidRootPart")
	local hum = char:FindFirstChildOfClass("Humanoid")
	local headM, headR = char:FindFirstChild("Head"), segRoot(char, "Head")
	if not (hrp and hum and headM and headR) then return nil end
	local R = {h = hrp.Size.Y / 2 + hum.HipHeight}
	-- body height from the segment parts only (GetExtentsSize also counts mecha parts and tags)
	local top = hrp.Position.Y
	for _, m in ipairs(char:GetChildren()) do
		local r = m:IsA("Model") and m:FindFirstChild("Root")
		if r then
			for _, p in ipairs(m:GetChildren()) do
				if p:IsA("BasePart") and p ~= r and p.Transparency < 1 then top = max(top, p.Position.Y + p.Size.Magnitude * .3) end
			end
		end
	end
	R.H = max(R.h * 1.2, top - (hrp.Position.Y - R.h))
	local legL = char:FindFirstChild("LegL")
	local mL = legL and legL:FindFirstChild("Root") and legL.Root:FindFirstChildOfClass("Motor6D")
	R.sL = (mL and mL.C0.Position.Z < 0) and -1 or 1
	local hlo, hhi = bounds(corners(headR, headM))
	local elo, ehi = bounds(corners(headR, headM, function(p) return p.Name:match("^Head_eye[LR]?$") ~= nil end))
	elo, ehi = elo or hlo, ehi or hhi
	R.eye = {x = (elo.X + ehi.X) / 2, y = (elo.Y + ehi.Y) / 2, zmin = elo.Z, zmax = ehi.Z, w = max(.1, ehi.X - elo.X), h = max(.1, ehi.Y - elo.Y)}
	R.headTop, R.headZc = hhi.Y, (hlo.Z + hhi.Z) / 2
	R.hw = min(hhi.Z - hlo.Z, (ehi.Z - elo.Z) * 1.25)
	local handName = char:FindFirstChild("HandL") and "HandL" or "ArmL"
	local handM, handR = char:FindFirstChild(handName), segRoot(char, handName)
	if handM and handR then
		local tip
		for _, c in ipairs(corners(handR, handM)) do if not tip or (-c.Y + .3 * c.X) > (-tip.Y + .3 * tip.X) then tip = c end end
		tip = tip or Vector3.zero
		-- lateral distance of the tip from the body centre line, measured in the torso root frame
		local torsoM, torsoR = char:FindFirstChild("Torso"), segRoot(char, "Torso")
		local tw = 0
		if torsoM and torsoR then local lo, hi = bounds(corners(torsoR, torsoM)) if lo then tw = (hi.Z - lo.Z) / 2 end end
		local lat = torsoR and abs(torsoR.CFrame:PointToObjectSpace(handR.CFrame * tip).Z) or 0
		local extra = max(0, tw + .12 * R.h - lat)
		R.hand = {name = handName, tip = tip + Vector3.new(R.h * .12, 0, R.sL * (R.h * .12 + extra))}
	end
	return R
end

-- ---------- props: a list of blocks in prop space, scaled by s * pop ----------
local function blk(list, sz, col, pos, mat, shape, rot)
	table.insert(list, {size = sz, color = col, pos = pos, mat = mat, shape = shape, rot = rot or CFrame.identity})
end
local PROPS = {}
PROPS.chef = function(R)
	local L = {}
	blk(L, Vector3.new(1, .32, 1), C("f2f2f2"), Vector3.new(0, .16, 0))
	local spots = {{-.22, -.22}, {.22, -.22}, {-.22, .22}, {.22, .22}}
	for i, s in ipairs(spots) do blk(L, Vector3.new(.62, .55, .62), C("ffffff"), Vector3.new(s[1], .58 + (i % 2) * .06, s[2])) end
	blk(L, Vector3.new(.72, .5, .72), C("ffffff"), Vector3.new(0, .9, 0))
	return {seg = "Head", s = R.hw * 1.2, pos = Vector3.new(R.eye.x - .1 * R.hw, R.headTop - .08 * R.hw, R.headZc), list = L}
end
PROPS.party = function(R)
	local L = {}
	local layers = {{.86, "ff3fa4"}, {.62, "ffe14d"}, {.4, "46d0ff"}, {.2, "ff3fa4"}}
	for i, l in ipairs(layers) do blk(L, Vector3.new(l[1], .32, l[1]), C(l[2]), Vector3.new(0, .16 + (i - 1) * .32, 0)) end
	blk(L, Vector3.new(.22, .22, .22), C("ffffff"), Vector3.new(0, 1.42, 0))
	return {seg = "Head", s = R.hw * 1.05, pos = Vector3.new(R.eye.x, R.headTop - .05 * R.hw, R.headZc), list = L, tilt = CFrame.Angles(0, 0, -.18)}
end
PROPS.glasses = function(R)
	local L, ey, hw = {}, R.eye, R.hw
	local lw, lh = max(ey.w * 3, hw * .75), max(ey.h * 2.8, hw * .48)
	for _, sd in ipairs({1, -1}) do
		local z = sd > 0 and ey.zmax + .06 or ey.zmin - .06
		blk(L, Vector3.new(lw * 1.12, lh * 1.15, .05), C("ff3fa4"), Vector3.new(ey.x, ey.y, z - sd * .01))
		blk(L, Vector3.new(lw, lh, .07), C("0b0b10"), Vector3.new(ey.x, ey.y, z), Enum.Material.Glass)
		blk(L, Vector3.new(lw * .3, lh * .22, .08), C("ffffff"), Vector3.new(ey.x + lw * .2, ey.y + lh * .22, z), Enum.Material.Neon)
	end
	blk(L, Vector3.new(lw * .3, lh * .35, ey.zmax - ey.zmin + .1), C("0b0b10"), Vector3.new(ey.x + lw * .2, ey.y + lh * .3, (ey.zmin + ey.zmax) / 2))
	return {seg = "Head", s = 1, pos = Vector3.zero, list = L, abs = true}
end
local function handProp(R, L, hot, s)
	if not R.hand then return nil end
	return {seg = R.hand.name, s = s or R.h * .42, pos = R.hand.tip, list = L, hot = hot}
end
PROPS.pan = function(R)
	local L = {}
	blk(L, Vector3.new(.9, .12, .14), C("5a3a22"), Vector3.new(.45, 0, 0))
	blk(L, Vector3.new(.12, 1.1, 1.1), C("2b2d33"), Vector3.new(1.3, .04, 0), Enum.Material.Metal, Enum.PartType.Cylinder, CFrame.Angles(0, 0, pi / 2))
	blk(L, Vector3.new(.4, .06, .3), C("fff4d6"), Vector3.new(1.3, .12, 0))
	blk(L, Vector3.new(.16, .07, .16), C("ffc21a"), Vector3.new(1.3, .14, 0))
	return handProp(R, L, Vector3.new(1.3, .2, 0))
end
PROPS.mic = function(R)
	local L = {}
	blk(L, Vector3.new(.16, .62, .16), C("222228"), Vector3.new(0, .2, 0))
	blk(L, Vector3.new(.2, .06, .2), C("ff3f6c"), Vector3.new(0, .48, 0))
	blk(L, Vector3.new(.34, .34, .34), C("9aa3ad"), Vector3.new(0, .66, 0), Enum.Material.Metal)
	return handProp(R, L)
end
PROPS.cup = function(R)
	local L = {}
	blk(L, Vector3.new(.62, .05, .62), C("ffffff"), Vector3.new(0, .02, 0))
	blk(L, Vector3.new(.38, .34, .38), C("ffffff"), Vector3.new(0, .22, 0))
	blk(L, Vector3.new(.4, .07, .4), C("ff8fb0"), Vector3.new(0, .33, 0))
	blk(L, Vector3.new(.3, .02, .3), C("8a5a2b"), Vector3.new(0, .39, 0))
	blk(L, Vector3.new(.07, .2, .07), C("ffffff"), Vector3.new(0, .22, .25))
	return handProp(R, L, Vector3.new(0, .45, 0))
end
PROPS.sign = function(R)
	local L = {}
	blk(L, Vector3.new(.09, 2.5, .09), C("8a6236"), Vector3.new(0, 1.25, 0))
	blk(L, Vector3.new(.07, 1, 2), C("fffdf4"), Vector3.new(0, 2.85, 0), nil, nil, nil)
	L[#L].sign = true
	return handProp(R, L, nil, R.h * .35)
end
PROPS.halo = function(R)
	local L = {}
	for i = 0, 9 do
		local a = i / 10 * 2 * pi
		blk(L, Vector3.new(.22, .1, .22), C("ffe066"), Vector3.new(cos(a) * .5, 0, sin(a) * .5), Enum.Material.Neon)
	end
	return {follow = "Torso", s = R.H * .32, list = L}
end

local function signGui(p)
	for _, face in ipairs({Enum.NormalId.Right, Enum.NormalId.Left}) do
		local g = Instance.new("SurfaceGui")
		g.Face = face
		g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		g.PixelsPerStud = 60
		g.LightInfluence = 0
		local f = Instance.new("Frame")
		f.Size = UDim2.fromScale(1, 1)
		f.BackgroundColor3 = C("fffdf4")
		f.Parent = g
		local s = Instance.new("UIStroke")
		s.Color = C("e8302a")
		s.Thickness = 6
		s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		s.Parent = f
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(.9, .9)
		t.Position = UDim2.fromScale(.05, .05)
		t.Font = Enum.Font.Bangers
		t.TextScaled = true
		t.TextColor3 = C("111111")
		t.Text = "SKILL\nISSUE"
		t.Parent = f
		g.Parent = p
	end
end

-- ---------- words ----------
local STYLE = {
	burst = {fill = "ffe14d", back = "ff3b2f"},
	cool = {fill = "7fe9ff", back = "062a33", pill = true},
	bubble = {fill = "ffffff"},
	zzz = {fill = "cfd8ff"},
}
local function makeWord(text, style, o)
	local st = STYLE[style] or STYLE.bubble
	local anchor = part(Vector3.new(.1, .1, .1), Color3.new(), nil)
	anchor.Transparency = 1
	local bb = Instance.new("BillboardGui")
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.Size = UDim2.fromScale(0, 0)
	bb.Parent = anchor
	local root = Instance.new("Frame")
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.Parent = bb
	if style == "burst" then
		for i = 0, 2 do -- 3 rotated squares = a 12-point burst
			local sq = Instance.new("Frame")
			sq.AnchorPoint = Vector2.new(.5, .5)
			sq.Position = UDim2.fromScale(.5, .5)
			sq.Size = UDim2.fromScale(.62, 1.15)
			sq.Rotation = i * 60
			sq.BackgroundColor3 = C(o.burst or st.back)
			sq.BorderSizePixel = 0
			sq:SetAttribute("FxFill", true)
			sq.Parent = root
			local s = Instance.new("UIStroke")
			s.Color = Color3.new(0, 0, 0)
			s.Thickness = 2
			s.Parent = sq
		end
	elseif st.pill then
		local pf = Instance.new("Frame")
		pf.AnchorPoint = Vector2.new(.5, .5)
		pf.Position = UDim2.fromScale(.5, .5)
		pf.Size = UDim2.fromScale(1, .62)
		pf.BackgroundColor3 = C(st.back)
		pf:SetAttribute("FxFill", true)
		pf.Parent = root
		local cr = Instance.new("UICorner")
		cr.CornerRadius = UDim.new(.5, 0)
		cr.Parent = pf
		local s = Instance.new("UIStroke")
		s.Color = C(st.fill)
		s.Thickness = 3
		s.Parent = pf
	end
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.AnchorPoint = Vector2.new(.5, .5)
	t.Position = UDim2.fromScale(.5, .52)
	t.Size = UDim2.fromScale(.92, .6)
	t.Font = Enum.Font.Bangers
	t.TextScaled = true
	t.Text = text
	t.TextColor3 = C(o.fill or st.fill)
	t.Parent = root
	local ts = Instance.new("UIStroke")
	ts.Color = Color3.new(0, 0, 0)
	ts.Thickness = 3
	ts.Parent = t
	return anchor, bb, root
end

-- ---------- per character ----------
local active = {} -- [char] = state
local fxList = {} -- free-moving effect parts {p, age, life, kind, ...}

local function clearState(st)
	for _, pr in pairs(st.props) do for _, b in ipairs(pr.parts) do b.p:Destroy() end end
	st.props = {}
end

local function propFor(char, st, kind, opts)
	local pr = st.props[kind]
	if pr then return pr end
	local def = PROPS[kind] and PROPS[kind](st.R)
	if not def then return nil end
	pr = {def = def, parts = {}}
	for _, b in ipairs(def.list) do
		local p = part(b.size, b.color, b.mat, b.shape)
		if b.sign then signGui(p) end
		table.insert(pr.parts, {p = p, b = b})
	end
	st.props[kind] = pr
	return pr
end
-- place a prop at weight w (0 = hidden); o.rz (deg, counter the arm pitch), o.dy (studs, shades falling)
local function placeProp(char, st, kind, w, o)
	if script:GetAttribute("EmotePropsEnabled") == false then return end
	local pr = propFor(char, st, kind, o)
	if not pr then return end
	pr.seen = st.frame
	local def = pr.def
	local base
	if def.follow then
		local r = segRoot(char, def.follow)
		if not r then return end
		base = CFrame.new(r.Position + Vector3.new(0, st.R.H * .5 + .04 * st.R.H * sin(os.clock() * 4), 0)) * CFrame.Angles(0, os.clock() * 2, 0)
	else
		local r = segRoot(char, def.seg)
		if not r then return end
		base = r.CFrame * CFrame.new(def.pos + Vector3.new(0, o and o.dy or 0, 0)) * CFrame.Angles(0, 0, rad(o and o.rz or 0)) * (def.tilt or CFrame.identity)
	end
	local k = def.s * max(w, .001)
	pr.cf, pr.k = base, k
	for _, e in ipairs(pr.parts) do
		local b = e.b
		e.p.Size = Vector3.new(max(.02, b.size.X * k), max(.02, b.size.Y * k), max(.02, b.size.Z * k))
		e.p.CFrame = base * CFrame.new(b.pos * k) * b.rot
		e.p.Transparency = w < .02 and 1 or 0
	end
end
local function hotPoint(st, kind)
	local pr = st.props[kind]
	if not (pr and pr.cf and pr.def.hot) then return nil end
	return pr.cf * (pr.def.hot * pr.k)
end

local function addFx(p, life, kind, extra)
	local e = extra or {}
	e.p, e.age, e.life, e.kind = p, 0, life, kind
	table.insert(fxList, e)
	return e
end
local function ring(pos, size, color)
	local p = part(Vector3.new(.2, size, size), color or C("e8d6a8"), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	p.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, pi / 2)
	p.Transparency = .3
	addFx(p, .55, "ring", {s = size, pos = pos})
end

local function word(char, st, key, text, style, o)
	if st.words[key] or script:GetAttribute("EmoteWordsEnabled") == false then return end
	st.words[key] = true
	o = o or {}
	local R = st.R
	local pos
	if o.at == "drop" and st.dropPos then pos = st.dropPos + Vector3.new(0, R.H * .3, 0)
	else
		local r = segRoot(char, o.at or "Head")
		if not r then return end
		pos = r.Position + Vector3.new(0, R.H * (o.at and .55 or .5), 0)
	end
	local cam = workspace.CurrentCamera
	if o.dx and cam then pos += cam.CFrame.RightVector * (o.dx * R.H) end
	local anchor, bb, root = makeWord(text, style, o)
	anchor.Position = pos
	local base = R.H * .42 * (o.size or 1)
	addFx(anchor, o.life or 1.3, "word", {bb = bb, root = root, base = base, rise = R.H * .22 * (o.rise or 1), rot = (rnd() - .5) * 14})
end

-- the effect timeline of each emote (same calls as the mockup)
local TIMELINE = {}
TIMELINE.cooked = function(char, st, t, f, R)
	placeProp(char, st, "chef", popW(t, .08, 2.75))
	placeProp(char, st, "pan", popW(t, .25, 2.75))
	for i, at in ipairs({.72, 1.27}) do
		if t > at and not st.eggs[i] then
			st.eggs[i] = true
			local hp = hotPoint(st, "pan")
			if hp then
				local g = R.h * 9
				local p = part(Vector3.new(1, .25, 1) * R.h * .12, C("fff6e0"))
				addFx(p, .5, "egg", {v = Vector3.new(0, g * .25, 0), g = g})
				p.Position = hp
			end
		end
	end
	if t > .5 and t < 2.6 and rnd() < .3 then
		local hp = hotPoint(st, "pan")
		if hp then local p = part(Vector3.one * R.h * .05, C("ffffff")) p.Position = hp p.Transparency = .5 addFx(p, .9, "steam", {v = Vector3.new(0, R.h * .45, 0), s = R.h * .05}) end
	end
	if t > 1.82 then word(char, st, "c", "COOKED!", "burst", {size = 1.2}) end
end
TIMELINE.mic = function(char, st, t, f, R)
	if t < 1 then placeProp(char, st, "mic", popW(t, .1, 99), {rz = -(75 * sm((t - .15) / .35) + 10) * .7}) return end
	if not st.released then
		st.released = true
		local pr = st.props.mic
		if pr and pr.cf then
			for _, e in ipairs(pr.parts) do
				local c = e.p:Clone()
				c.Transparency = 0
				c.Parent = folder
				addFx(c, 2, "fall", {v = Vector3.zero, g = R.h * 14, ground = (char.HumanoidRootPart.Position.Y - R.h) + c.Size.Y / 2,
					onLand = function(pos)
						if st.dropPos then return end
						st.dropPos = pos
						ring(Vector3.new(pos.X, char.HumanoidRootPart.Position.Y - R.h + .05, pos.Z), R.h * .8)
						word(char, st, "b", "BOOM", "burst", {size = 1.2, at = "drop"})
					end})
			end
		end
	end
end
TIMELINE.skill = function(char, st, t, f, R)
	local e = sm(f / .06) * (1 - sm((f - .9) / .1))
	local pump = sin(2 * pi * 2.2 * t) * sm((t - .1) / .3)
	local ap = (55 + 14 * pump) * e
	placeProp(char, st, "sign", popW(t, .12, 2.65), {rz = -(ap + (char:FindFirstChild("HandL") and 25 * e or 0))})
end
TIMELINE.tea = function(char, st, t, f, R)
	local e = sm(f / .06) * (1 - sm((f - .9) / .1))
	local up = pulse(t, .45, .8, 1.55, 1.9)
	placeProp(char, st, "cup", popW(t, .12, 2.8), {rz = -(30 + 40 * up) * e})
	if t < 2.6 and rnd() < .3 then
		local hp = hotPoint(st, "cup")
		if hp then local p = part(Vector3.one * R.h * .05, C("ffffff")) p.Position = hp p.Transparency = .5 addFx(p, .9, "steam", {v = Vector3.new(0, R.h * .45, 0), s = R.h * .05}) end
	end
	if t > 1.05 then word(char, st, "s", "*sip*", "bubble", {size = .75, life = 1}) end
	if t > 2.2 then word(char, st, "a", "ahh~", "bubble", {size = .65, life = .9}) end
end
TIMELINE.easy = function(char, st, t, f, R)
	local fall = t < .2 and 0 or eob((t - .2) / .4)
	placeProp(char, st, "glasses", t < .2 and 0 or (t < 2.45 and 1 or 1 - sm((t - 2.45) / .12)), {dy = (1 - fall) * R.H * .8})
	if t > 1 then word(char, st, "e", "TOO EASY", "cool", {size = 1}) end
end
TIMELINE.party = function(char, st, t, f, R)
	placeProp(char, st, "party", popW(t, .05, 2.45))
	if t > .52 and not st.conf then
		st.conf = true
		local r = segRoot(char, "Head")
		if r then
			local cols = {"ff3fa4", "ffe14d", "46d0ff", "46e08a", "ff6412", "b98cff"}
			for i = 1, 40 do
				local s = R.h * .045
				local p = part(Vector3.new(s, s * .2, s * 1.4), C(cols[i % #cols + 1]), Enum.Material.Neon)
				p.Position = r.Position + Vector3.new(0, R.H * .15, 0)
				local a = rnd() * 2 * pi
				local sp = R.h * (.6 + rnd() * 1.6)
				addFx(p, 1.5, "conf", {v = Vector3.new(cos(a) * sp, R.h * (1.8 + rnd() * 1.6), sin(a) * sp), g = R.h * 4, spin = rnd() * 12})
			end
		end
		word(char, st, "g", "GG!", "burst", {size = 1.2, fill = "ffe14d", burst = "ff3fa4"})
	end
end
TIMELINE.stomp = function(char, st, t, f, R)
	local u = (t - .2) / .42
	local k = math.floor(u)
	local p = u - k
	if k >= 0 and k < 4 and p >= .68 and not st.hits[k] then
		st.hits[k] = true
		local side = (k % 2 == 0) and 1 or -1
		local foot = segRoot(char, side == 1 and "FootL" or "FootR")
		local hrp = char:FindFirstChild("HumanoidRootPart")
		if foot and hrp then ring(Vector3.new(foot.Position.X, hrp.Position.Y - R.h + .05, foot.Position.Z), R.h * .9) end
		if k == 3 then word(char, st, "s", "STOMP!", "burst", {size = 1}) end
	end
end
TIMELINE.moon = function(char, st, t, f, R)
	local c = pulse(f, .28, .38, .8, .9)
	if c > .6 then
		local slot = math.floor(t / .24)
		if not st.howls[slot] then
			st.howls[slot] = true
			local r = segRoot(char, "Head")
			if r then
				local p = part(Vector3.new(.15, R.h * .35, R.h * .35), C("bfe9ff"), Enum.Material.Neon, Enum.PartType.Cylinder)
				p.Transparency = .3
				p.CFrame = r.CFrame * CFrame.new(R.h * .35, 0, 0)
				addFx(p, .8, "howl", {v = r.CFrame.XVector * R.h * 1.6, s = R.h * .35})
			end
		end
	end
	if t > 1.15 then word(char, st, "a", "AWOOO!", "bubble", {size = 1}) end
end
TIMELINE.shake = function(char, st, t, f, R)
	local A = sm(f / .1) * (1 - sm((f - .72) / .28))
	if A > .5 and rnd() < .55 then
		local segs = {"Head", "Neck", "Torso", "Tail1", "Tail2", "Tail3"}
		local r = segRoot(char, segs[rnd(1, #segs)])
		if r then
			local p = part(Vector3.one * R.h * .05, C("7fd8ff"), Enum.Material.Neon)
			p.Position = r.Position
			local a = rnd() * 2 * pi
			local sp = R.h * (1.2 + rnd())
			addFx(p, .7, "drop", {v = Vector3.new(cos(a) * sp, R.h * (1 + rnd()), sin(a) * sp), g = R.h * 5})
		end
	end
end
TIMELINE.arms = function(char, st, t, f, R)
	if t > .9 then word(char, st, "f", "FLEX!", "burst", {size = .9, fill = "ffffff", burst = "ff6412"}) end
end
TIMELINE.dead = function(char, st, t, f, R)
	placeProp(char, st, "halo", popW(t, 1, 2.5))
	if t > 1.15 then word(char, st, "r", "RIP", "bubble", {size = .9, at = "Torso"}) end
end
TIMELINE.yawn = function(char, st, t, f, R)
	for i, a in ipairs({.9, 1.2, 1.5}) do
		if t > a then word(char, st, "z" .. i, "Z", "zzz", {size = .45 + (i - 1) * .12, dx = .25 + (i - 1) * .2, rise = 1.4}) end
	end
	if t > 1.86 then word(char, st, "c", "CHOMP", "burst", {size = .8, fill = "ffffff", burst = "7f8cff"}) end
end

local function stepFx(dt)
	for i = #fxList, 1, -1 do
		local o = fxList[i]
		o.age += dt
		local k = o.age / o.life
		if k >= 1 or not o.p.Parent then
			o.p:Destroy()
			table.remove(fxList, i)
		elseif o.kind == "ring" then
			local s = o.s * (.4 + 2.2 * math.sqrt(k))
			o.p.Size = Vector3.new(.15, s, s)
			o.p.Transparency = .3 + .7 * k
		elseif o.kind == "drop" or o.kind == "egg" or o.kind == "conf" then
			o.v = Vector3.new(o.v.X, o.v.Y - o.g * dt, o.v.Z)
			if o.kind == "conf" then o.v *= (1 - dt * 1.5) end
			o.p.CFrame = (o.p.CFrame + o.v * dt) * CFrame.Angles(o.kind == "conf" and o.spin * dt or 0, 0, o.kind == "egg" and dt * 14 or 0)
		elseif o.kind == "steam" then
			o.p.Position += o.v * dt
			o.p.Size = Vector3.one * o.s * (1 + 2 * k)
			o.p.Transparency = .5 + .5 * k
		elseif o.kind == "howl" then
			o.p.CFrame += o.v * dt
			local s = o.s * (1 + 2 * k)
			o.p.Size = Vector3.new(.15, s, s)
			o.p.Transparency = .3 + .7 * k
		elseif o.kind == "fall" then
			if not o.landed then
				o.v = Vector3.new(0, o.v.Y - o.g * dt, 0)
				o.p.CFrame += o.v * dt
				if o.p.Position.Y <= o.ground then
					o.landed = true
					o.p.Position = Vector3.new(o.p.Position.X, o.ground, o.p.Position.Z)
					if o.onLand then o.onLand(o.p.Position) end
				end
			end
		elseif o.kind == "word" then
			local s = o.age < .2 and eob(o.age / .2) or 1
			local fade = k > .75 and 1 - (k - .75) / .25 or 1
			o.bb.Size = UDim2.fromScale(o.base * 2 * s, o.base * s)
			o.p.Position += Vector3.new(0, o.rise * dt, 0)
			o.root.Rotation = o.rot * exp(-o.age * 4) * sin(o.age * 16) + o.rot * .3
			for _, d in ipairs(o.root:GetDescendants()) do
				if d:IsA("TextLabel") then d.TextTransparency = 1 - fade
				elseif d:IsA("Frame") and d:GetAttribute("FxFill") then d.BackgroundTransparency = 1 - fade
				elseif d:IsA("UIStroke") then d.Transparency = 1 - fade end
			end
		end
	end
end

local frame = 0
RunService.RenderStepped:Connect(function(dt)
	frame += 1
	if script:GetAttribute("EmoteFXEnabled") == false then
		for char, st in pairs(active) do clearState(st) active[char] = nil end
		return
	end
	local cam = workspace.CurrentCamera
	local range = script:GetAttribute("EmoteFXRange") or 120
	local now = workspace:GetServerTimeNow()
	local seen = {}
	for _, pl in ipairs(BC and BC.players(script) or Players:GetPlayers()) do -- v1.1 filler bots
		local char = pl.Character
		local id = char and char:GetAttribute("EmoteId")
		local at, dur = char and char:GetAttribute("EmoteStartedAt"), char and char:GetAttribute("EmoteDuration")
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if type(id) == "string" and TIMELINE[id] and typeof(at) == "number" and typeof(dur) == "number" and hrp and cam
			and (hrp.Position - cam.CFrame.Position).Magnitude < range then
			local t = now - at
			if t >= 0 and t <= dur then
				local st = active[char]
				if not st or st.at ~= at then
					if st then clearState(st) end
					local R = rigOf(char)
					st = R and {at = at, R = R, props = {}, words = {}, hits = {}, eggs = {}, howls = {}} or nil
					active[char] = st
				end
				if st then
					st.frame = frame
					seen[char] = true
					TIMELINE[id](char, st, t, t / dur, st.R)
					for kind, pr in pairs(st.props) do
						if pr.seen ~= frame then for _, e in ipairs(pr.parts) do e.p.Transparency = 1 end end
					end
				end
			end
		end
	end
	local n = 0
	for char, st in pairs(active) do
		if not seen[char] then clearState(st) active[char] = nil else n += 1 end
	end
	stepFx(dt)
	script:SetAttribute("EmoteFXActive", n)
	script:SetAttribute("EmoteFXParts", #fxList)
end)
