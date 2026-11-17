-- VictoryTitlesAnim v1.0 (Mecha Dino Arena) — the 8 victory-title animations (ModuleScript, StarterPlayerScripts, next to the
-- VictoryTitles LocalScript). MDA-556, plan docs/plans/VICTORY_TITLES_v1.0.md Task 5; a port of the approved mockup
-- docs/mockups/victory_titles_v0.1.html (tools/mockup/titles_engine.js + titles_anims.js; Kepu 2026-11-16 19:00 "Oh my gosh
-- these are so good. Let's implement them").
-- Rig: a local clone of a dino model (DinoModelBuilder structure: HumanoidRootPart + segment Models whose Root carries the
--   Motor6D). Joint angles {p, y, r} in degrees exactly as the mockup: Motor6D.Transform = Rz(p) · Ry(y) · Rx(r) (p = pitch:
--   RootJoint / Neck / Head + = rear back / nose up, Arm / Leg + = swing forward, Knee − = bend, Ankle + = toes up, Tail + =
--   droop, − = lift, Jaw − = open; y = yaw, + = to the dino's right; r = roll). The body: HumanoidRootPart (anchored) =
--   T(stage + pos) · Ry(yaw) · [pivot · Rx(rx) · Rz(rz) · pivot⁻¹] · T(0, −rest min y, 0), lifted so the feet (or every part,
--   plant "all") touch the stage floor. Springs give the overlap / follow-through. Every distance is in U = max(height,
--   0.55 × length) of the dino, so any dino fits any title. The mockup's squash / stretch is left out (a Roblox model has no
--   non-uniform scale); Carried's shrink is Model:ScaleTo(0.7).
-- API: M.new(stage, ui) -> show; show:play(titleId, model, mateModel?) builds the props and returns a runner with
--   runner:step(dt) -> false when done; runner:destroy(). ui = {counter(text, scale, color) / counter(nil), plaster(alpha, k),
--   flash(alpha)}. M.LEN[title] = seconds (VictoryTitles 1.0 LEN).
-- v1.1 (Studio Play test 2026-11-16, MDA-556): (a) EXTINCT's fossil colour is built per channel (1.0 multiplied a Color3 by a
--   number, which Luau refuses: the title stopped at the impact, 2.3 s). (b) Ctx:flash draws a soft glow (2 additive smoke
--   particles + a fading PointLight on an attachment) instead of the growing Neon ball, which read as a hard glass sphere.
--   Switch: M.SOFT_FLASH (default true; VictoryTitles 1.1 sets it per title from its attribute VictorySoftFlashEnabled;
--   false = the 1.0 ball).
-- v1.2 (MDA-552; Kepu 2026-11-17 16:35 "we need to fix the therizino tho, it needs to get scaled down when thrown into the
--   backpack so the backpack animation can always be the same when thrown onto the back of a Dino. This should be the case
--   for all dinos and the carried title"): CARRIED's bag is one size for every dino, set by the mate: height CARRIED_BAG.h
--   × the mate's height (0.42, the size 1.1 shrank the bag to on the back), width .w × that, depth .d × that. It stays that
--   size from the ground to the mate's back, so the throw onto the back is the same on every dino (1.1 sized the bag from
--   the carried dino at 70 % and shrank it on the way to the back, so a big dino like the Therizino got a huge bag and stuck
--   out of it). The poof shrinks the carried dino to whatever fits that bag in its nose-down pose (hips at the opening;
--   every part inside CARRIED_BAG.fit × the bag's width / depth / height), worked out in setup from the pose's own part
--   corners. (Sizing from the mate's torso box was tried in Studio and dropped: the Therizino's torso box is 18.5 studs
--   wide, wider than it is long, so the bag towered over it.) Switch: M.CARRIED_FIT (default true; false = 1.1). Numbers:
--   M.CARRIED_BAG = {h = 0.42, w = 0.8, d = 0.62, fit = 0.85}; VictoryTitles 1.2 sets both per title from its attributes.
--   Diagnostics: M.lastCarriedK (the shrink used by the last CARRIED), M.lastCarriedInfo (mate height and bag size, studs).
local Workspace = game:GetService("Workspace")

local M = {}
M.VERSION = "1.0"
M.VERSION = "1.1" -- v1.1 extinct colour fix, soft flash
M.SOFT_FLASH = true -- v1.1
M.VERSION = "1.2" -- v1.2 carried: one bag size, the dino shrinks to fit
M.CARRIED_FIT = true -- v1.2
M.CARRIED_BAG = {h = 0.42, w = 0.8, d = 0.62, fit = 0.85} -- v1.2
M.lastCarriedK = nil -- v1.2
M.lastCarriedInfo = "" -- v1.2
M.LEN = {apex = 5.4, king = 5.4, unkill = 5.4, medic = 5.4, masher = 5.4, carried = 6.4, pacifist = 5.6, extinct = 5.8}

-- ---------- maths ----------
local rad = math.rad
local function lerp(a, b, u) return a + (b - a) * u end
local function sat(x) return math.clamp(x, 0, 1) end
local function win(t, a, b) return sat((t - a) / (b - a)) end
local V = Vector3.new
local E = {
	lin = function(u) return u end,
	io = function(u) return u * u * (3 - 2 * u) end,
	out = function(u) return 1 - (1 - u) ^ 3 end,
	out5 = function(u) return 1 - (1 - u) ^ 5 end,
	in3 = function(u) return u * u * u end,
	in2 = function(u) return u * u end,
	back = function(u) local c = 1.9 return 1 + (c + 1) * (u - 1) ^ 3 + c * (u - 1) ^ 2 end,
	bounce = function(u)
		local n, d = 7.5625, 2.75
		if u < 1 / d then return n * u * u end
		if u < 2 / d then u -= 1.5 / d return n * u * u + 0.75 end
		if u < 2.5 / d then u -= 2.25 / d return n * u * u + 0.9375 end
		u -= 2.625 / d return n * u * u + 0.984375
	end,
}
local function kf(t, keys)
	if t <= keys[1][1] then return keys[1][2] end
	for i = 2, #keys do
		if t <= keys[i][1] then
			local a, b = keys[i - 1], keys[i]
			return lerp(a[2], b[2], E[b[3] or "io"]((t - a[1]) / (b[1] - a[1])))
		end
	end
	return keys[#keys][2]
end
local function kvec(t, keys) -- Vector3 keys
	if t <= keys[1][1] then return keys[1][2] end
	for i = 2, #keys do
		if t <= keys[i][1] then
			local a, b = keys[i - 1], keys[i]
			return a[2]:Lerp(b[2], E[b[3] or "io"]((t - a[1]) / (b[1] - a[1])))
		end
	end
	return keys[#keys][2]
end
-- poses: {Joint = {p, y, r}}
local function lerpPose(a, b, u)
	local o = {}
	for k, va in pairs(a) do local vb = b[k] or {0, 0, 0} o[k] = {lerp(va[1], vb[1], u), lerp(va[2], vb[2], u), lerp(va[3], vb[3], u)} end
	for k, vb in pairs(b) do if not a[k] then o[k] = {vb[1] * u, vb[2] * u, vb[3] * u} end end
	return o
end
local function addPose(a, b, w)
	w = w or 1
	local o = table.clone(a)
	for k, vb in pairs(b) do local va = a[k] or {0, 0, 0} o[k] = {va[1] + vb[1] * w, va[2] + vb[2] * w, va[3] + vb[3] * w} end
	return o
end
local function pk(t, keys)
	if t <= keys[1][1] then return keys[1][2] end
	for i = 2, #keys do
		if t <= keys[i][1] then
			local a, b = keys[i - 1], keys[i]
			return lerpPose(a[2], b[2], E[b[3] or "io"]((t - a[1]) / (b[1] - a[1])))
		end
	end
	return keys[#keys][2]
end
local function BOTH(o)
	local r = table.clone(o)
	for k, v in pairs(o) do
		if string.sub(k, -1) == "L" then r[string.sub(k, 1, -2) .. "R"] = {v[1], -v[2], -v[3]} end
	end
	return r
end
local function with(o, extra) local r = table.clone(o) for k, v in pairs(extra) do r[k] = v end return r end

-- springs
local function SPR(n)
	if string.match(n, "^Arm") or string.match(n, "^Elbow") or string.match(n, "^Wrist") then return 26, 0.5 end
	if n == "RootJoint" then return 30, 0.8 end
	if string.match(n, "^Leg") or string.match(n, "^Knee") or string.match(n, "^Ankle") then return 40, 0.85 end
	if n == "Neck" then return 24, 0.55 end
	if n == "Head" then return 22, 0.5 end
	if n == "Jaw" then return 36, 0.5 end
	local ti = string.match(n, "^Tail(%d)")
	if ti then return 17 - 2 * tonumber(ti), 0.38 end
	return 24, 0.7
end
local function springStep(r, target, dt)
	local steps = math.max(1, math.ceil(dt * 240))
	local h = dt / steps
	local out = {}
	local names = {}
	for n in pairs(target) do names[n] = true end
	for n in pairs(r.springs) do names[n] = true end
	for n in pairs(names) do
		local s = r.springs[n]
		local tg = target[n] or {0, 0, 0}
		if not s then
			local w, z = SPR(n)
			s = {x = {tg[1], tg[2], tg[3]}, v = {0, 0, 0}, w = w, z = z}
			r.springs[n] = s
		end
		for _ = 1, steps do
			for i = 1, 3 do
				local a = s.w * s.w * (tg[i] - s.x[i]) - 2 * s.z * s.w * s.v[i]
				s.v[i] += a * h
				s.x[i] += s.v[i] * h
			end
		end
		out[n] = {s.x[1], s.x[2], s.x[3]}
	end
	return out
end
local function snapSprings(r, target)
	r.springs = {}
	for n, v in pairs(target) do local w, z = SPR(n) r.springs[n] = {x = {v[1], v[2], v[3]}, v = {0, 0, 0}, w = w, z = z} end
end
local function kick(r, n, dp, dy, dr)
	local s = r.springs[n]
	if not s then local w, z = SPR(n) s = {x = {0, 0, 0}, v = {0, 0, 0}, w = w, z = z} r.springs[n] = s end
	s.v[1] += dp or 0
	s.v[2] += dy or 0
	s.v[3] += dr or 0
end

-- procedural layers
local function walkLayer(ph, amp, r)
	local s, c = math.sin(ph * math.pi * 2), math.cos(ph * math.pi * 2)
	local A = {}
	A.LegL = {28 * s * amp, 0, 0}; A.LegR = {-28 * s * amp, 0, 0}
	A.KneeL = {-(22 + 22 * math.max(0, c)) * amp, 0, 0}; A.KneeR = {-(22 + 22 * math.max(0, -c)) * amp, 0, 0}
	A.AnkleL = {10 * math.max(0, -s) * amp, 0, 0}; A.AnkleR = {10 * math.max(0, s) * amp, 0, 0}
	if r and r.quad then A.ArmL = {-24 * s * amp, 0, 0}; A.ArmR = {24 * s * amp, 0, 0} else A.ArmL = {-8 * s * amp, 0, 0}; A.ArmR = {8 * s * amp, 0, 0} end
	A.Tail1 = {0, 8 * c * amp, 0}; A.Tail2 = {0, 10 * c * amp, 0}; A.Tail3 = {0, 12 * c * amp, 0}
	A.Neck = {3 * math.abs(s) * amp, -3 * c * amp, 0}; A.RootJoint = {0, 4 * c * amp, 3 * s * amp}
	return A
end
local function flailLayer(t, amp)
	local A, f = {}, 9
	A.LegL = {40 * math.sin(t * f * 2) * amp, 0, 10 * amp}; A.LegR = {40 * math.sin(t * f * 2 + 2.1) * amp, 0, -10 * amp}
	A.KneeL = {-30 - 30 * math.sin(t * f * 2 + 1) * amp, 0, 0}; A.KneeR = {-30 - 30 * math.sin(t * f * 2 + 3) * amp, 0, 0}
	A.ArmL = {-40 + 35 * math.sin(t * f * 2.4) * amp, 0, 20 * amp}; A.ArmR = {-40 + 35 * math.sin(t * f * 2.4 + 1.7) * amp, 0, -20 * amp}
	A.Jaw = {-28 - 10 * math.sin(t * 30) * amp, 0, 0}
	A.Neck = {8 * math.sin(t * 7), 14 * math.sin(t * 5.3) * amp, 0}; A.Head = {6 * math.sin(t * 9), 0, 10 * math.sin(t * 6) * amp}
	for i = 1, 5 do A["Tail" .. i] = {0, 10 * math.sin(t * 8 - i * 0.6) * amp, 0} end
	return A
end
local function breathe(t, amp)
	local s = math.sin(t * 2.2)
	return {RootJoint = {1.2 * s * amp, 0, 0}, Neck = {1.6 * s * amp, 0, 0}, Head = {-1 * s * amp, 0, 0},
		Tail2 = {0, 3 * math.sin(t * 1.3) * amp, 0}, Tail3 = {0, 4 * math.sin(t * 1.3 - 0.6) * amp, 0},
		Tail4 = {0, 5 * math.sin(t * 1.3 - 1.2) * amp, 0}, Tail5 = {0, 6 * math.sin(t * 1.3 - 1.8) * amp, 0}}
end

local P = {
	IDLE = {},
	CROUCH = BOTH({RootJoint = {-8, 0, 0}, Neck = {12, 0, 0}, Head = {-10, 0, 0}, ArmL = {-18, 0, 0}, LegL = {34, 0, 0}, KneeL = {-62, 0, 0}, AnkleL = {28, 0, 0}, Tail1 = {-8, 0, 0}, Tail2 = {-4, 0, 0}}),
	STALK = BOTH({RootJoint = {-10, 0, 0}, Neck = {-12, 0, 0}, Head = {10, 0, 0}, ArmL = {-12, 0, 0}, LegL = {18, 0, 0}, KneeL = {-34, 0, 0}, AnkleL = {14, 0, 0}, Tail1 = {-6, 0, 0}, Tail2 = {-4, 0, 0}}),
	PUSH = BOTH({RootJoint = {-6, 0, 0}, Neck = {18, 0, 0}, Head = {-12, 0, 0}, ArmL = {-24, 0, 0}, LegL = {-22, 0, 0}, KneeL = {-4, 0, 0}, AnkleL = {-24, 0, 0}, Tail1 = {-8, 0, 0}}),
	AIR = BOTH({RootJoint = {-4, 0, 0}, Neck = {26, 0, 0}, Head = {-22, 0, 0}, Jaw = {-10, 0, 0}, ArmL = {-34, 0, 0}, LegL = {42, 0, 0}, KneeL = {-76, 0, 0}, AnkleL = {36, 0, 0}, Tail1 = {-10, 0, 0}, Tail2 = {-6, 0, 0}, Tail3 = {-4, 0, 0}}),
	LAND = BOTH({RootJoint = {-10, 0, 0}, Neck = {-6, 0, 0}, Head = {4, 0, 0}, ArmL = {14, 0, 0}, LegL = {30, 0, 0}, KneeL = {-58, 0, 0}, AnkleL = {26, 0, 0}, Tail1 = {8, 0, 0}}),
	ROAR_WIND = BOTH({RootJoint = {16, 0, 0}, Neck = {40, 0, 0}, Head = {-24, 0, 0}, Jaw = {-14, 0, 0}, ArmL = {-30, 0, 0}, LegL = {6, 0, 0}, KneeL = {-10, 0, 0}, Tail1 = {10, 0, 0}, Tail2 = {6, 0, 0}}),
	ROAR = BOTH({RootJoint = {-8, 0, 0}, Neck = {-14, 0, 0}, Head = {24, 0, 0}, Jaw = {-50, 0, 0}, ArmL = {30, 0, 0}, LegL = {10, 0, 0}, KneeL = {-18, 0, 0}, AnkleL = {6, 0, 0}, Tail1 = {-14, 0, 0}, Tail2 = {-10, 0, 0}, Tail3 = {-6, 0, 0}}),
	PROUD = BOTH({RootJoint = {8, 0, 0}, Neck = {22, 0, 0}, Head = {-14, 0, 0}, ArmL = {-22, 0, 0}, Tail1 = {-6, 0, 0}, Tail2 = {-4, 0, 0}}),
	SIT = BOTH({RootJoint = {8, 0, 0}, Neck = {16, 0, 0}, Head = {-10, 0, 0}, ArmL = {-12, 0, 0}, LegL = {58, 0, 0}, KneeL = {-118, 0, 0}, AnkleL = {60, 0, 0}, Tail1 = {16, 0, 0}, Tail2 = {8, 0, 0}, Tail3 = {4, 0, 0}}),
	PECK = BOTH({RootJoint = {-18, 0, 0}, Neck = {-42, 0, 0}, Head = {-16, 0, 0}, Jaw = {-4, 0, 0}, ArmL = {10, 0, 0}, LegL = {12, 0, 0}, KneeL = {-22, 0, 0}, AnkleL = {8, 0, 0}, Tail1 = {-16, 0, 0}, Tail2 = {-8, 0, 0}}),
	PECK_UP = BOTH({RootJoint = {-8, 0, 0}, Neck = {-14, 0, 0}, Head = {-4, 0, 0}, ArmL = {0, 0, 0}, LegL = {8, 0, 0}, KneeL = {-16, 0, 0}, AnkleL = {6, 0, 0}, Tail1 = {-10, 0, 0}, Tail2 = {-6, 0, 0}}),
	LOOK_UP = BOTH({RootJoint = {8, 0, 0}, Neck = {42, 0, 0}, Head = {30, 0, 0}, Jaw = {-30, 0, 0}, ArmL = {-34, 0, 0}, Tail1 = {4, 0, 0}}),
	SHRUG = BOTH({RootJoint = {4, 0, 0}, Neck = {8, 0, 10}, Head = {-6, 0, 16}, ArmL = {-62, 0, -18}, Tail1 = {-8, 0, 0}, Tail2 = {-4, 0, 0}}),
	SNIFF = BOTH({RootJoint = {-16, 0, 0}, Neck = {-40, 0, 0}, Head = {-8, 0, 0}, ArmL = {6, 0, 0}, LegL = {8, 0, 0}, KneeL = {-14, 0, 0}, AnkleL = {6, 0, 0}, Tail1 = {-12, 0, 0}}),
	STARTLED = BOTH({RootJoint = {12, 0, 0}, Neck = {32, 0, 0}, Head = {-10, 0, 0}, Jaw = {-34, 0, 0}, ArmL = {-56, 0, 0}, Tail1 = {-22, 0, 0}, Tail2 = {-12, 0, 0}}),
	CHILL = BOTH({RootJoint = {2, 0, 0}, Neck = {8, -8, 0}, Head = {-4, -6, 4}, ArmL = {-4, 0, 0}, Tail1 = {4, 0, 0}}),
	HAPPY = BOTH({RootJoint = {4, 0, 0}, Neck = {14, 0, 0}, Head = {-6, 0, 0}, Jaw = {-16, 0, 0}, ArmL = {-40, 0, 0}, Tail1 = {-10, 0, 0}, Tail2 = {-6, 0, 0}}),
	FLAT = BOTH({RootJoint = {-6, 0, 0}, Neck = {-10, 0, 0}, Head = {4, 0, 0}, Jaw = {-30, 0, 0}, ArmL = {10, 0, 30}, LegL = {10, 0, 22}, KneeL = {-10, 0, 0}, Tail1 = {6, 0, 0}, Tail2 = {4, 0, 0}}),
}

-- ---------- rig ----------
local function transformOf(v)
	if not v then return CFrame.identity end
	return CFrame.Angles(0, 0, rad(v[1])) * CFrame.Angles(0, rad(v[2]), 0) * CFrame.Angles(rad(v[3]), 0, 0)
end
local CORNERS = {}
for i = 0, 7 do table.insert(CORNERS, V(bit32.band(i, 1) ~= 0 and 0.5 or -0.5, bit32.band(i, 2) ~= 0 and 0.5 or -0.5, bit32.band(i, 4) ~= 0 and 0.5 or -0.5)) end

local function segOfPart(part, hrp, model)
	if part == hrp then return "HRP" end
	local p = part.Parent
	if p and p:IsA("Model") and p ~= model then return p.Name end
	return part.Name
end

-- (re)measure a rig: joints, parts per segment, rest dimensions and landmarks (after a ScaleTo too)
local function measure(r)
	local model, hrp = r.model, r.hrp
	local motors = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Motor6D") and d.Part0 and d.Part1 then table.insert(motors, d) end
	end
	-- parent-first order from the HRP
	local done, joints = {HRP = true}, {}
	local guard = 0
	while #joints < #motors and guard < 50 do
		guard += 1
		for _, m in ipairs(motors) do
			local s0, s1 = segOfPart(m.Part0, hrp, model), segOfPart(m.Part1, hrp, model)
			if done[s0] and not done[s1] then
				done[s1] = true
				table.insert(joints, {name = m.Name, m = m, p0 = s0, p1 = s1, c0 = m.C0, c1inv = m.C1:Inverse(), root = m.Part1})
			end
		end
	end
	r.joints = joints
	local roots = {HRP = hrp}
	for _, j in ipairs(joints) do roots[j.p1] = j.root end
	-- rigid groups: each visible part to the segment root it is welded to (welds / weld constraints, not motors)
	local adj = {}
	local function link(a, b) if a and b then adj[a] = adj[a] or {}; adj[b] = adj[b] or {}; table.insert(adj[a], b); table.insert(adj[b], a) end end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("WeldConstraint") then link(d.Part0, d.Part1)
		elseif d:IsA("JointInstance") and not d:IsA("Motor6D") then link(d.Part0, d.Part1) end
	end
	local segOf = {}
	for seg, root in pairs(roots) do
		local q, head = {root}, 1
		segOf[root] = seg
		while head <= #q do
			local cur = q[head]; head += 1
			for _, nb in ipairs(adj[cur] or {}) do
				if not segOf[nb] then segOf[nb] = seg; table.insert(q, nb) end
			end
		end
	end
	local parts = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d ~= hrp then
			local seg = segOf[d] or segOfPart(d, hrp, model)
			local root = roots[seg]
			if root and d.Transparency < 1 then
				local off = root.CFrame:Inverse() * d.CFrame
				local cs = {}
				for i, c in ipairs(CORNERS) do cs[i] = off * (c * d.Size) end
				table.insert(parts, {part = d, seg = seg, cs = cs})
			end
		end
	end
	r.parts = parts
	-- rest segment frames (relative to the HRP)
	local rel = {HRP = CFrame.identity}
	for _, j in ipairs(joints) do rel[j.p1] = rel[j.p0] * j.c0 * j.c1inv end
	local mn, mx = V(math.huge, math.huge, math.huge), V(-math.huge, -math.huge, -math.huge)
	local tmn, tmx = V(math.huge, math.huge, math.huge), V(-math.huge, -math.huge, -math.huge)
	local feetMin, armsMin = math.huge, math.huge
	for _, p in ipairs(parts) do
		local f = rel[p.seg] or CFrame.identity
		for _, c in ipairs(p.cs) do
			local w = f * c
			mn, mx = mn:Min(w), mx:Max(w)
			if p.seg == "Torso" then tmn, tmx = tmn:Min(w), tmx:Max(w) end
			if string.match(p.seg, "^Foot") then feetMin = math.min(feetMin, w.Y) end
			if string.match(p.seg, "^Arm") or string.match(p.seg, "^Fore") or string.match(p.seg, "^Hand") then armsMin = math.min(armsMin, w.Y) end
		end
	end
	r.restMinY = mn.Y
	r.H = mx.Y - mn.Y
	r.L = mx.Z - mn.Z
	r.Wd = mx.X - mn.X
	r.U = math.max(r.H, 0.55 * r.L)
	r.quad = armsMin < feetMin + 0.06 * r.H
	r.piv = (tmn.X < math.huge) and ((tmn + tmx) / 2 - V(0, mn.Y, 0)) or V(0, r.H / 2, 0)
	-- landmarks in segment space
	local function extreme(seg, which)
		local f = rel[seg]
		if not f then return nil end
		local best, bv = nil, -math.huge
		local smn, smx = V(math.huge, math.huge, math.huge), V(-math.huge, -math.huge, -math.huge)
		for _, p in ipairs(parts) do
			if p.seg == seg then
				for _, c in ipairs(p.cs) do
					local w = f * c
					smn, smx = smn:Min(w), smx:Max(w)
					local s = which == "front" and -w.Z or which == "back" and w.Z or w.Y
					if s > bv then bv, best = s, w end
				end
			end
		end
		if not best then return nil end
		local ctr = (smn + smx) / 2
		if which == "top" then best = V(ctr.X, best.Y, ctr.Z) else best = V(ctr.X, lerp(best.Y, ctr.Y, 0.5), best.Z) end
		return f:Inverse() * best, f:Inverse() * smn, f:Inverse() * smx
	end
	r.mouthL = extreme("Head", "front") or V(0, 0, -1)
	r.headTopL = extreme("Head", "top") or V(0, 1, 0)
	local tailSeg = r.hasSeg("Tail5") and "Tail5" or (r.hasSeg("Tail3") and "Tail3" or "Torso")
	r.tailSeg = tailSeg
	r.tailTipL = extreme(tailSeg, "back") or V(0, 0, 1)
	-- head box (segment space) for head props
	local hmn, hmx = V(math.huge, math.huge, math.huge), V(-math.huge, -math.huge, -math.huge)
	local tbn, tbx = V(math.huge, math.huge, math.huge), V(-math.huge, -math.huge, -math.huge)
	for _, p in ipairs(parts) do
		if p.seg == "Head" then for _, c in ipairs(p.cs) do hmn, hmx = hmn:Min(c), hmx:Max(c) end end
		if p.seg == "Torso" then for _, c in ipairs(p.cs) do tbn, tbx = tbn:Min(c), tbx:Max(c) end end
	end
	r.headBox = {mn = hmn, mx = hmx}
	r.torsoBox = {mn = tbn, mx = tbx}
end

local function newRig(model, origin)
	local hrp = model:FindFirstChild("HumanoidRootPart")
	if not hrp then return nil end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Humanoid") or d:IsA("AnimationController") or d:IsA("Animator") or d:IsA("LuaSourceContainer") then d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = d == hrp
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Massless = true
		end
	end
	local r = {model = model, hrp = hrp, O = origin, pos = V(0, 0, 0), yaw = 0, rx = 0, rz = 0, plant = "feet", springs = {}, segW = {}, A = {}}
	local segNames = {}
	for _, d in ipairs(model:GetDescendants()) do if d:IsA("Motor6D") and d.Part1 then segNames[segOfPart(d.Part1, hrp, model)] = true end end
	r.hasSeg = function(n) return segNames[n] == true end
	measure(r)
	return r
end

local function poseRig(r, A)
	local rel = {HRP = CFrame.identity}
	for _, j in ipairs(r.joints) do
		local T = transformOf(A[j.name])
		j.m.Transform = T
		rel[j.p1] = rel[j.p0] * j.c0 * T * j.c1inv
	end
	local piv = r.piv
	local base = CFrame.new(r.O.X + r.pos.X, r.O.Y, r.O.Z + r.pos.Z) * CFrame.Angles(0, r.yaw, 0)
		* CFrame.new(piv) * CFrame.Angles(r.rx, 0, 0) * CFrame.Angles(0, 0, r.rz) * CFrame.new(-piv) * CFrame.new(0, -r.restMinY, 0)
	local lift = r.pos.Y
	if r.plant ~= "none" then
		local minY = math.huge
		for _, p in ipairs(r.parts) do
			local ok = r.plant == "all" or string.match(p.seg, "^Foot") ~= nil
				or (r.quad and (string.match(p.seg, "^Arm") ~= nil or string.match(p.seg, "^Fore") ~= nil or string.match(p.seg, "^Hand") ~= nil))
			if ok then
				local f = base * (rel[p.seg] or CFrame.identity)
				for _, c in ipairs(p.cs) do local y = (f * c).Y if y < minY then minY = y end end
			end
		end
		if minY < math.huge then lift += r.O.Y - minY end
	end
	local hcf = CFrame.new(0, lift, 0) * base
	r.hrp.CFrame = hcf
	for seg, f in pairs(rel) do r.segW[seg] = hcf * f end
	r.A = A
end
local function drive(r, target, dt, layer, direct)
	local A
	if direct then snapSprings(r, target) A = target else A = springStep(r, target, dt) end
	if layer then A = addPose(A, layer) end
	poseRig(r, A)
end
local function segPt(r, seg, l) return (r.segW[seg] or r.segW.HRP) * l end
local function mouthPt(r) return segPt(r, "Head", r.mouthL) end
local function headTop(r) return segPt(r, "Head", r.headTopL) end
local function tailTip(r) return segPt(r, r.tailSeg, r.tailTipL) end
local function headC(r) return segPt(r, "Head", (r.headBox.mn + r.headBox.mx) / 2) end
local function worldBox(r, filter)
	local mn, mx = V(math.huge, math.huge, math.huge), V(-math.huge, -math.huge, -math.huge)
	for _, p in ipairs(r.parts) do
		if not filter or filter(p) then
			local f = r.segW[p.seg]
			if f then
				-- 2 opposite corners + centre are enough for framing (faster than all 8)
				local a, b = f * p.cs[1], f * p.cs[8]
				mn, mx = mn:Min(a):Min(b), mx:Max(a):Max(b)
			end
		end
	end
	return {mn = mn, mx = mx}
end
local function boxUnion(a, b) return {mn = a.mn:Min(b.mn), mx = a.mx:Max(b.mx)} end
local function boxOfParts(list)
	local mn, mx = V(math.huge, math.huge, math.huge), V(-math.huge, -math.huge, -math.huge)
	for _, p in ipairs(list) do
		local cf, s = p.CFrame, p.Size / 2
		for _, c in ipairs(CORNERS) do local w = cf * (c * p.Size) mn, mx = mn:Min(w), mx:Max(w) end
		local _ = s
	end
	return {mn = mn, mx = mx}
end
local function yawTo(from, to) return math.atan2(-(to.X - from.X), -(to.Z - from.Z)) end

-- ---------- the show object ----------
local Show = {}
Show.__index = Show

function M.new(stage, ui)
	-- stage = {origin = Vector3 (floor top centre), folder = Instance, camera = Camera}
	return setmetatable({stage = stage, ui = ui}, Show)
end

-- runner context
local Ctx = {}
Ctx.__index = Ctx

local function newPart(c, size, color, opt)
	opt = opt or {}
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Size = size
	p.Color = typeof(color) == "Color3" and color or Color3.fromHex(string.format("%06x", color))
	p.Material = opt.material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CastShadow = opt.shadow ~= false
	if opt.shape then p.Shape = opt.shape end
	if opt.transparency then p.Transparency = opt.transparency end
	p.Parent = c.folder
	return p
end
function Ctx:part(size, color, opt) return newPart(self, size, color, opt) end
function Ctx:W(x, y, z) return self.O + V(x, y, z) end
function Ctx:at(label, t0, fn)
	if self.t >= t0 and not self.fired[label] then self.fired[label] = true fn() end
end
-- generic fx: {obj, life, t, update(obj, u, dt)}; obj destroyed at the end
function Ctx:fx(obj, life, update) table.insert(self.fxList, {obj = obj, life = life, t = 0, update = update}) return obj end
function Ctx:stepFx(dt)
	for i = #self.fxList, 1, -1 do
		local f = self.fxList[i]
		f.t += dt
		local u = math.min(1, f.t / f.life)
		if f.update then f.update(f.obj, u, dt) end
		if f.t >= f.life then if f.obj then f.obj:Destroy() end table.remove(self.fxList, i) end
	end
end
-- manual debris (anchored parts thrown, bouncing on the stage floor)
function Ctx:debris(obj, v, w, opt)
	opt = opt or {}
	table.insert(self.debrisList, {obj = obj, v = v, w = w, life = opt.life or 3, t = 0, bounce = opt.bounce or 0.35, grav = opt.grav or 70,
		r = opt.r or 0.5, drag = opt.drag or 0, flutter = opt.flutter or 0, fade = opt.fade ~= false, rot = obj:IsA("BasePart") and obj.CFrame.Rotation or CFrame.identity})
end
function Ctx:stepDebris(dt)
	local floor = self.O.Y
	for i = #self.debrisList, 1, -1 do
		local d = self.debrisList[i]
		d.t += dt
		d.v -= V(0, d.grav * dt, 0)
		if d.drag > 0 then d.v *= (1 - d.drag) ^ (dt * 60) end
		if d.flutter > 0 then d.v += V(math.sin(d.t * 7 + i) * d.flutter * dt, 0, math.cos(d.t * 5 + i) * d.flutter * dt) end
		local p = d.obj:GetPivot().Position + d.v * dt
		if p.Y < floor + d.r then
			p = V(p.X, floor + d.r, p.Z)
			if d.v.Y < 0 then
				d.v = V(d.v.X * 0.6, -d.v.Y * d.bounce, d.v.Z * 0.6)
				d.w *= 0.6
				if math.abs(d.v.Y) < 2 then d.v = V(d.v.X * 0.8, 0, d.v.Z * 0.8) end
			end
		end
		d.rot = d.rot * CFrame.Angles(d.w.X * dt, d.w.Y * dt, d.w.Z * dt)
		d.obj:PivotTo(CFrame.new(p) * d.rot)
		if d.fade and d.t > d.life - 0.5 then
			local k = math.max(0, (d.life - d.t) / 0.5)
			for _, bp in ipairs(d.obj:IsA("BasePart") and {d.obj} or d.obj:GetDescendants()) do if bp:IsA("BasePart") then bp.Transparency = 1 - k end end
		end
		if d.t >= d.life then d.obj:Destroy() table.remove(self.debrisList, i) end
	end
end
-- particle bursts (Roblox's built-in particle textures)
local TEX = {spark = "rbxasset://textures/particles/sparkles_main.dds", smoke = "rbxasset://textures/particles/smoke_main.dds",
	fire = "rbxasset://textures/particles/fire_main.dds"}
function Ctx:emitter(p, dir, o)
	local a = Instance.new("Attachment")
	a.Parent = Workspace.Terrain
	a.WorldCFrame = CFrame.lookAt(p, p + (dir or V(0, 1, 0)))
	local e = Instance.new("ParticleEmitter")
	e.Texture = TEX[o.tex or "smoke"]
	e.EmissionDirection = Enum.NormalId.Front
	e.Enabled = false
	e.Speed = NumberRange.new(o.speed0 or 0, o.speed1 or o.speed0 or 0)
	e.SpreadAngle = Vector2.new(o.spread or 180, o.spread or 180)
	e.Lifetime = NumberRange.new(o.life0 or 0.5, o.life1 or o.life0 or 0.5)
	e.Size = NumberSequence.new(o.size0 or 1, o.size1 or o.size0 or 1)
	e.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, o.alpha0 or 0.2), NumberSequenceKeypoint.new(1, 1)})
	e.Color = ColorSequence.new(o.color or Color3.new(1, 1, 1))
	e.LightEmission = o.glow or 0
	e.Acceleration = o.accel or V(0, 0, 0)
	e.Drag = o.drag or 0
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-90, 90)
	e.Rate = o.rate or 0
	e.Parent = a
	table.insert(self.attachments, a)
	if o.n and o.n > 0 then e:Emit(o.n) end
	if o.rate and o.rate > 0 then e.Enabled = true end
	return a, e
end
function Ctx:sparks(p, n, size, color, spd)
	self:emitter(p, V(0, 1, 0), {tex = "spark", n = n, speed0 = spd * 0.5, speed1 = spd * 1.5, spread = 180, life0 = 0.3, life1 = 0.6,
		size0 = size * 1.6, size1 = 0, color = color or Color3.fromRGB(255, 244, 200), glow = 1, accel = V(0, -spd * 2, 0)})
end
function Ctx:puff(p, vel, size, color, life, op)
	local spd = vel.Magnitude
	self:emitter(p, spd > 0.01 and vel.Unit or V(0, 1, 0), {tex = "smoke", n = 1, speed0 = spd, spread = 10, life0 = life or 0.7,
		size0 = size, size1 = size * 3, color = color or Color3.new(1, 1, 1), alpha0 = 1 - (op or 0.7), drag = 3})
end
function Ctx:dust(p, n, size, spd, color)
	self:emitter(p + V(0, size * 0.3, 0), V(0, 1, 0), {tex = "smoke", n = n, speed0 = spd * 0.6, speed1 = spd, spread = 85, life0 = 0.7, life1 = 1.1,
		size0 = size, size1 = size * 2.6, color = color or Color3.fromRGB(217, 201, 160), alpha0 = 0.25, drag = 4})
end
function Ctx:flash(p, size, color, life)
	if M.SOFT_FLASH ~= false then -- v1.1: soft glow
		local col = color or Color3.new(1, 1, 1)
		local a = self:emitter(p, V(0, 1, 0), {tex = "smoke", n = 2, speed0 = 0, spread = 0, life0 = (life or 0.18) * 1.6,
			size0 = size * 1.2, size1 = size * 2.8, color = col, alpha0 = 0.1, glow = 1})
		local l = Instance.new("PointLight")
		l.Range = size * 4
		l.Brightness = 3
		l.Color = col
		l.Parent = a
		self:fx(l, life or 0.18, function(o, u) o.Brightness = 3 * (1 - u) end)
		return
	end
	local b = newPart(self, V(1, 1, 1) * size, color or Color3.new(1, 1, 1), {shape = Enum.PartType.Ball, material = Enum.Material.Neon, shadow = false})
	b.CFrame = CFrame.new(p)
	local l = Instance.new("PointLight")
	l.Range = size * 4
	l.Brightness = 3
	l.Color = b.Color
	l.Parent = b
	self:fx(b, life or 0.18, function(o, u) o.Size = V(1, 1, 1) * size * (0.6 + u * 1.3) o.Transparency = u l.Brightness = 3 * (1 - u) end)
end
function Ctx:ring(p, normal, r1, color, life)
	local d = newPart(self, V(0.15, 1, 1), color or Color3.new(1, 1, 1), {shape = Enum.PartType.Cylinder, material = Enum.Material.Neon, shadow = false})
	local base = CFrame.lookAt(p, p + normal) * CFrame.Angles(0, math.pi / 2, 0) -- cylinder axis (X) along the normal
	self:fx(d, life or 0.45, function(o, u)
		local s = 0.2 + r1 * E.out(u)
		o.Size = V(0.15, s * 2, s * 2)
		o.CFrame = base + normal * (r1 * 0.02 * u)
		o.Transparency = 0.45 + 0.55 * u
	end)
end
-- 3D icons that face the camera
function Ctx:icon(kind, p, size, life, rise, follow)
	local m = Instance.new("Model")
	local parts = {}
	local function add(sz, col, cf, shape)
		local q = newPart(self, sz, col, {material = Enum.Material.Neon, shadow = false, shape = shape})
		q.Parent = m
		table.insert(parts, {q = q, cf = cf})
	end
	if kind == "star" then
		local Y = Color3.fromRGB(255, 225, 74)
		for i = 0, 4 do add(V(size * 0.16, size * 0.55, size * 0.08), Y, CFrame.Angles(0, 0, i * math.pi * 2 / 5) * CFrame.new(0, size * 0.22, 0)) end
		add(V(size * 0.36, size * 0.36, size * 0.09), Y, CFrame.identity)
	elseif kind == "heart" then
		local R = Color3.fromRGB(255, 90, 122)
		add(V(size * 0.5, size * 0.5, size * 0.3), R, CFrame.new(-size * 0.17, size * 0.08, 0), Enum.PartType.Ball)
		add(V(size * 0.5, size * 0.5, size * 0.3), R, CFrame.new(size * 0.17, size * 0.08, 0), Enum.PartType.Ball)
		add(V(size * 0.42, size * 0.42, size * 0.28), R, CFrame.new(0, -size * 0.1, 0) * CFrame.Angles(0, 0, math.pi / 4))
	elseif kind == "plus" then
		local G = Color3.fromRGB(58, 212, 106)
		add(V(size * 0.24, size * 0.8, size * 0.1), G, CFrame.identity)
		add(V(size * 0.8, size * 0.24, size * 0.1), G, CFrame.identity)
	elseif kind == "bang" then
		local Y = Color3.fromRGB(255, 210, 58)
		add(V(size * 0.22, size * 0.62, size * 0.14), Y, CFrame.new(0, size * 0.16, 0))
		add(V(size * 0.24, size * 0.24, size * 0.24), Y, CFrame.new(0, -size * 0.36, 0), Enum.PartType.Ball)
	end
	m.Parent = self.folder
	local pos = p
	local cam = self.stage.camera
	self:fx(m, life, function(_, u, dt)
		local k = u < 0.18 and E.back(u / 0.18) or 1
		pos += V(0, (rise or 0) * dt, 0)
		local at = follow and follow(u) or pos
		local face = CFrame.lookAt(at, cam.CFrame.Position)
		for _, e in ipairs(parts) do
			local cf = e.cf
			e.q.CFrame = face * CFrame.new(cf.Position * k) * cf.Rotation
			e.q.Transparency = u > 0.8 and (u - 0.8) / 0.2 or 0
		end
		local _ = k
	end)
	return m
end
function Ctx:text(str, p, size, life, color, stroke)
	local a = Instance.new("Attachment")
	a.Parent = Workspace.Terrain
	a.WorldPosition = p
	local g = Instance.new("BillboardGui")
	g.Size = UDim2.fromScale(size * 3.2, size)
	g.LightInfluence = 0
	g.AlwaysOnTop = true
	g.Adornee = a
	g.Parent = a
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, 1)
	l.Text = str
	l.TextScaled = true
	l.Font = Enum.Font.FredokaOne
	l.TextColor3 = color or Color3.new(1, 1, 1)
	l.TextStrokeTransparency = 0
	l.TextStrokeColor3 = stroke or Color3.fromRGB(29, 42, 68)
	l.Parent = g
	self:fx(a, life, function(_, u) l.TextTransparency = u > 0.7 and (u - 0.7) / 0.3 or 0 l.TextStrokeTransparency = l.TextTransparency end)
end
function Ctx:rock(size, color)
	local q = newPart(self, V(size, size * 0.8, size * 0.9) * 2, color or Color3.fromRGB(107, 90, 74), {material = Enum.Material.Slate})
	q.CFrame = CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6)
	return q
end
function Ctx:orbitStars(r, n, life, radius)
	for i = 1, n do
		local U = r.U
		self:icon("star", headTop(r), U * 0.11, life, 0, function()
			local h = headTop(r)
			local a = self.t * 7 + i * math.pi * 2 / n
			return h + V(math.cos(a) * U * (radius or 0.16), U * 0.07 + math.sin(a * 2) * U * 0.02, math.sin(a) * U * (radius or 0.16))
		end)
	end
end
function Ctx:meteor(radius)
	local b = newPart(self, V(1, 1, 1) * radius * 2, Color3.fromRGB(90, 74, 62), {shape = Enum.PartType.Ball, material = Enum.Material.Slate})
	local l = Instance.new("PointLight")
	l.Color = Color3.fromRGB(255, 138, 58)
	l.Range = math.min(60, radius * 24)
	l.Brightness = 4
	l.Parent = b
	local a = Instance.new("Attachment")
	a.Parent = b
	local e = Instance.new("ParticleEmitter")
	e.Texture = TEX.fire
	e.Rate = 60
	e.Lifetime = NumberRange.new(0.35, 0.6)
	e.Speed = NumberRange.new(radius * 0.5, radius * 1.5)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Size = NumberSequence.new(radius * 2.4, radius * 0.6)
	e.Color = ColorSequence.new(Color3.fromRGB(255, 210, 112), Color3.fromRGB(255, 90, 32))
	e.LightEmission = 1
	e.Transparency = NumberSequence.new(0.1, 1)
	e.Parent = a
	local s = Instance.new("ParticleEmitter")
	s.Texture = TEX.smoke
	s.Rate = 25
	s.Lifetime = NumberRange.new(0.8, 1.2)
	s.Speed = NumberRange.new(0, radius * 0.3)
	s.Size = NumberSequence.new(radius * 1.5, radius * 3)
	s.Color = ColorSequence.new(Color3.fromRGB(90, 80, 72))
	s.Transparency = NumberSequence.new(0.4, 1)
	s.Parent = a
	b.Transparency = 1
	e.Enabled, s.Enabled = false, false
	return {part = b, fire = e, smoke = s, show = function(on) b.Transparency = on and 0 or 1 e.Enabled = on s.Enabled = on l.Enabled = on end}
end

-- camera: keyed shot on a framed box (see the mockup's camShot)
local camF = {}
function Ctx:camShot(t, dt, keys, box, head, over, overW)
	local cam = self.stage.camera
	if self.camHold and camF.t then
		local s = (self.shake or 0) * camF.d * 0.012
		cam.CFrame = CFrame.lookAt(self.camHoldPos + V((math.random() - .5) * s, (math.random() - .5) * s, (math.random() - .5) * s), self.camHoldLook)
		return
	end
	local dir = kvec(t, (function() local o = {} for _, k in ipairs(keys) do table.insert(o, {k[1], k[2], k[6]}) end return o end)()).Unit
	local function sk(i) local o = {} for _, k in ipairs(keys) do table.insert(o, {k[1], k[i] or 0, k[6]}) end return o end
	local zoom, yb, hw = kf(t, sk(3)), kf(t, sk(4)), kf(t, sk(5))
	local ctr, size = (box.mn + box.mx) / 2, box.mx - box.mn
	local rr = size.Magnitude / 2
	if head then ctr = ctr:Lerp(head, hw) end
	local lk = ctr + V(0, yb * size.Y, 0)
	if over then lk = lk:Lerp(over, overW or 0) end
	local vp = cam.ViewportSize
	local vf = rad(cam.FieldOfView / 2)
	local hf = math.atan(math.tan(vf) * vp.X / math.max(1, vp.Y))
	local d = rr / math.tan(math.min(vf, hf)) * zoom
	if not camF.t or self.camSnap then camF.t, camF.lk, camF.d = ctr, lk, d self.camSnap = false
	else
		local k = 1 - math.exp(-dt * 4)
		camF.t, camF.lk, camF.d = camF.t:Lerp(ctr, k), camF.lk:Lerp(lk, k), lerp(camF.d, d, k)
	end
	local pos = camF.t + dir * camF.d
	local look = camF.lk
	local right = dir:Cross(V(0, 1, 0))
	right = right.Magnitude > 1e-4 and right.Unit or V(1, 0, 0)
	local off = -0.16 * camF.d * math.tan(hf) -- subject a little right of centre, clear of the title card
	pos -= right * off
	look -= right * off
	if (self.shake or 0) > 0 then local s = self.shake * camF.d * 0.012 pos += V((math.random() - .5) * s, (math.random() - .5) * s, (math.random() - .5) * s) end
	cam.CFrame = CFrame.lookAt(pos, look)
	self.camHoldPos, self.camHoldLook = pos, look
end
function Ctx:camFrame(box, dir, dt, pad, minR)
	local cam = self.stage.camera
	local ctr, size = (box.mn + box.mx) / 2, box.mx - box.mn
	local rr = math.max(minR or 0, size.Magnitude / 2) * (pad or 1)
	local vp = cam.ViewportSize
	local vf = rad(cam.FieldOfView / 2)
	local hf = math.atan(math.tan(vf) * vp.X / math.max(1, vp.Y))
	local d = rr / math.tan(math.min(vf, hf))
	if not camF.t then camF.t, camF.lk, camF.d = ctr, ctr, d
	else local k = 1 - math.exp(-dt * 3.2) camF.t, camF.d = camF.t:Lerp(ctr, k), lerp(camF.d, d, k) camF.lk = camF.t end
	local u = dir.Unit
	local pos, look = camF.t + u * camF.d, camF.t
	local right = u:Cross(V(0, 1, 0)).Unit
	local off = -0.16 * camF.d * math.tan(hf)
	pos -= right * off
	look -= right * off
	if (self.shake or 0) > 0 then local s = self.shake * camF.d * 0.012 pos += V((math.random() - .5) * s, (math.random() - .5) * s, (math.random() - .5) * s) end
	cam.CFrame = CFrame.lookAt(pos, look)
end

local TITLES = {}

-- =====================================================================================================================
-- 1 · APEX PREDATOR
TITLES.apex = {
	setup = function(c)
		local r, U = c.r, c.r.U
		c.mh = 0.12 * r.H
		local mnd = c:part(V(1.3 * U, c.mh * 2, 1.3 * U), Color3.fromRGB(125, 96, 64))
		local mesh = Instance.new("SpecialMesh") mesh.MeshType = Enum.MeshType.Sphere mesh.Parent = mnd
		mnd.CFrame = CFrame.new(c:W(0, 0, 0))
		local top = c:part(V(c.mh * 0.16, 0.62 * U, 0.62 * U), Color3.fromRGB(106, 138, 58), {shape = Enum.PartType.Cylinder})
		top.CFrame = CFrame.new(c:W(0, c.mh * 0.92, 0)) * CFrame.Angles(0, 0, math.pi / 2)
		c.bones = {}
		local rnd = Random.new(5)
		for i = 1, 18 do
			local a, rr = rnd:NextNumber() * math.pi * 2, 0.16 * U + rnd:NextNumber() * 0.48 * U
			local m = Instance.new("Model")
			if i % 6 == 0 then
				local h = c:part(V(0.13, 0.09, 0.15) * U, Color3.fromRGB(224, 40, 74)) h.Parent = m
				local vz = c:part(V(0.11, 0.03, 0.02) * U, Color3.fromRGB(27, 27, 34)) vz.CFrame = h.CFrame * CFrame.new(0, 0.01 * U, -0.075 * U) vz.Parent = m
				local fin = c:part(V(0.02, 0.04, 0.1) * U, Color3.fromRGB(138, 26, 48)) fin.CFrame = h.CFrame * CFrame.new(0, 0.06 * U, 0) fin.Parent = m
			else
				local L, th = (0.12 + rnd:NextNumber() * 0.08) * U, 0.028 * U
				local sh = c:part(V(L, th, th), Color3.fromRGB(238, 230, 210)) sh.Parent = m
				for _, sx in ipairs({-1, 1}) do for _, sz in ipairs({-1, 1}) do
					local k = c:part(V(1, 1, 1) * th * 1.6, Color3.fromRGB(246, 240, 224)) k.CFrame = sh.CFrame * CFrame.new(sx * L / 2, 0, sz * th * 0.7) k.Parent = m
				end end
			end
			m.Parent = c.folder
			local surf = rr < 0.3 * U and c.mh * 0.95 or c.mh * math.sqrt(math.max(0, 1 - (rr / (0.65 * U)) ^ 2))
			local base = CFrame.new(c:W(math.cos(a) * rr, surf + 0.02 * U, math.sin(a) * rr)) * CFrame.Angles((rnd:NextNumber() - .5) * 0.5, rnd:NextNumber() * 6.28, (rnd:NextNumber() - .5) * 0.5)
			m:PivotTo(base)
			table.insert(c.bones, {m = m, base = base, y = 0, vy = 0})
		end
		r.pos = V(0, 0, 0.8 * U)
	end,
	update = function(c, t, dt)
		local r, U = c.r, c.r.U
		local z0, z1 = 0.82 * U, 0.6 * U
		local z = t < 0.78 and lerp(z0, z1, E.io(win(t, 0, 0.78))) or (t < 1.1 and z1) or (t < 1.5 and lerp(z1, 0, E.io(win(t, 1.1, 1.5)))) or 0
		local y = 0
		if t >= 1.1 and t < 1.5 then local u = win(t, 1.1, 1.5) y = lerp(0, c.mh, u) + 4 * 0.32 * r.H * u * (1 - u) elseif t >= 1.5 then y = c.mh end
		r.pos = V(0, y, z)
		local A = pk(t, {{0, P.STALK}, {0.75, P.STALK}, {1.02, P.CROUCH}, {1.12, P.PUSH, "out"}, {1.24, P.AIR, "out"}, {1.44, P.AIR}, {1.53, P.LAND, "out"}, {1.85, P.IDLE}, {2.1, P.ROAR_WIND}, {2.26, P.ROAR, "out5"}, {3.5, P.ROAR}, {3.75, P.PROUD, "out"}, {5.4, P.PROUD}})
		local layer
		if t < 0.8 then
			A = addPose(A, walkLayer(t * 1.7, 0.7 * (1 - win(t, 0.6, 0.8)), r))
			A = addPose(A, {Neck = {0, 16 * math.sin(t * 4.4), 0}, Head = {0, 8 * math.sin(t * 4.4 - 0.5), 0}})
		end
		if t > 2.26 and t < 3.5 then
			local k = 1 - win(t, 3.3, 3.5)
			layer = {Neck = {0, 3 * math.sin(t * 47) * k, 0}, Head = {2 * math.sin(t * 39) * k, 0, 3.5 * math.sin(t * 43) * k}, Jaw = {5 * math.sin(t * 55) * k, 0, 0}, Tail4 = {0, 6 * math.sin(t * 30) * k, 0}, Tail5 = {0, 9 * math.sin(t * 30 - 1) * k, 0}}
			c.shake = math.max(c.shake, 0.9 * k)
		end
		if t > 3.75 then
			local q = t - 3.75
			layer = {Tail1 = {0, 10 * math.sin(q * 3.2), 0}, Tail2 = {0, 12 * math.sin(q * 3.2 - 0.6), 0}, Tail3 = {0, 14 * math.sin(q * 3.2 - 1.2), 0}, Neck = {0, -10 * E.io(win(t, 4.3, 4.9)), 0}}
		end
		c:at("land", 1.5, function()
			kick(r, "Neck", -260)
			c:dust(c:W(0, c.mh, 0), 12, 0.22 * U, 0.9 * U)
			c.shake = 0.6
			for _, b in ipairs(c.bones) do b.vy = (0.6 + math.random() * 0.8) * U end
		end)
		c:at("roar", 2.26, function() c:flash(mouthPt(r), 0.3 * U, Color3.fromRGB(255, 242, 192)) end)
		if t > 2.26 and t < 3.45 then
			c.roarT = (c.roarT or 0) - dt
			if c.roarT <= 0 then
				c.roarT = 0.15
				local m = mouthPt(r)
				local d = (m - headC(r)).Unit
				d = d:Lerp((c.stage.camera.CFrame.Position - m).Unit, 0.35).Unit
				c:ring(m + d * 0.08 * U, d, 0.65 * U, Color3.fromRGB(255, 246, 216), 0.45)
				c:emitter(m, d, {tex = "smoke", n = 4, speed0 = 1.2 * U, speed1 = 2.2 * U, spread = 35, life0 = 0.6, life1 = 0.9, size0 = 0.05 * U, size1 = 0.03 * U, color = Color3.fromRGB(95, 176, 74), alpha0 = 0})
				c:puff(m, d * 1.4 * U, 0.12 * U, Color3.new(1, 1, 1), 0.5, 0.35)
			end
		end
		for _, b in ipairs(c.bones) do
			b.vy -= 5 * U * dt
			b.y += b.vy * dt
			if b.y < 0 then b.y = 0 b.vy = math.abs(b.vy) > 0.3 * U and -b.vy * 0.35 or 0 end
			local rat = (t > 2.26 and t < 3.45) and 0.012 * U or 0
			b.m:PivotTo(b.base + V((math.random() - .5) * rat, b.y + math.random() * rat, (math.random() - .5) * rat))
		end
		drive(r, A, dt, layer)
		c:camShot(t, dt, {{0, V(-0.55, 0.3, -1), 1.0, 0, 0}, {1.4, V(-0.5, 0.28, -1), 0.95, 0, 0}, {2.15, V(-0.42, 0.12, -1), 0.8, 0.06, 0.3}, {3.5, V(-0.36, 0.1, -1), 0.7, 0.06, 0.4, "lin"}, {3.95, V(-0.48, 0.24, -1), 0.85, 0, 0.15}, {5.4, V(-0.52, 0.26, -1), 0.9, 0, 0.15}},
			boxUnion(worldBox(r), {mn = c:W(-0.5 * U, 0, -0.5 * U), mx = c:W(0.5 * U, 0.2 * U, 0.5 * U)}), headC(r))
	end,
}

-- =====================================================================================================================
-- 2 · KING OF THE HILL
TITLES.king = {
	setup = function(c)
		local r, U = c.r, c.r.U
		c.mh = 0.09 * r.H
		local mnd = c:part(V(1.2 * U, c.mh * 2, 1.2 * U), Color3.fromRGB(125, 96, 64))
		local mesh = Instance.new("SpecialMesh") mesh.MeshType = Enum.MeshType.Sphere mesh.Parent = mnd
		mnd.CFrame = CFrame.new(c:W(0, 0, 0))
		-- the point ring (blue, pulsing)
		c.ringParts = {}
		for i = 0, 35 do
			local a = i / 36 * math.pi * 2
			local s = c:part(V(0.16 * U, 0.02 * U, 0.05 * U), Color3.fromRGB(90, 160, 255), {material = Enum.Material.Neon, shadow = false})
			s.CFrame = CFrame.new(c:W(math.cos(a) * 0.9 * U, 0.01 * U, math.sin(a) * 0.9 * U)) * CFrame.Angles(0, -a + math.pi / 2, 0)
			table.insert(c.ringParts, s)
		end
		-- flag
		local fx0, fz0, ph = 0.5 * U, 0.38 * U, 1.05 * r.H
		local pole = c:part(V(0.025 * U, ph, 0.025 * U), Color3.fromRGB(216, 220, 228)) pole.CFrame = CFrame.new(c:W(fx0, ph / 2, fz0))
		local knob = c:part(V(1, 1, 1) * 0.06 * U, Color3.fromRGB(255, 210, 90), {shape = Enum.PartType.Ball}) knob.CFrame = CFrame.new(c:W(fx0, ph + 0.02 * U, fz0))
		c.flag = {}
		local n, fw, fh = 9, 0.5 * U, 0.3 * U
		for i = 0, n - 1 do table.insert(c.flag, {p = c:part(V(fw / n * 1.12, fh, 0.01 * U), Color3.fromRGB(90, 160, 255), {shadow = false}), i = i}) end
		c.flagBase, c.fw, c.fn = c:W(fx0, ph - fh / 2 - 0.02 * U, fz0), fw, n
		-- crown (head-segment units)
		local hb = r.headBox
		local hw = math.max(hb.mx.X - hb.mn.X, (hb.mx.Z - hb.mn.Z) * 0.6)
		local cr = hw * 0.42
		c.crownR = cr
		c.crown = {}
		local gold = Color3.fromRGB(255, 210, 90)
		for i = 0, 9 do
			local a = i / 10 * math.pi * 2
			local seg = c:part(V(cr * 0.68, cr * 0.36, cr * 0.12), gold, {material = Enum.Material.Metal})
			table.insert(c.crown, {p = seg, rel = CFrame.new(math.cos(a) * cr, cr * 0.18, math.sin(a) * cr) * CFrame.Angles(0, -a + math.pi / 2, 0)})
			local sp = c:part(V(cr * 0.2, cr * 0.2, cr * 0.08), gold, {material = Enum.Material.Metal})
			table.insert(c.crown, {p = sp, rel = CFrame.new(math.cos(a) * cr, cr * 0.5, math.sin(a) * cr) * CFrame.Angles(0, -a + math.pi / 2, 0) * CFrame.Angles(0, 0, math.pi / 4)})
			if i % 2 == 0 then
				local gem = c:part(V(cr * 0.14, cr * 0.14, cr * 0.06), i % 4 == 0 and Color3.fromRGB(224, 40, 74) or Color3.fromRGB(90, 160, 255), {material = Enum.Material.Neon})
				table.insert(c.crown, {p = gem, rel = CFrame.new(math.cos(a) * cr * 1.06, cr * 0.18, math.sin(a) * cr * 1.06) * CFrame.Angles(0, -a + math.pi / 2, 0)})
			end
		end
		c.crownScale = 1
		r.pos = V(0, c.mh, 0)
	end,
	update = function(c, t, dt)
		local r, U = c.r, c.r.U
		r.pos = V(0, c.mh, 0)
		local A = pk(t, {{0, P.SIT}, {0.45, P.SIT}, {0.8, addPose(P.SIT, {Neck = {18, 0, 0}, Head = {16, 0, 0}, Jaw = {-8, 0, 0}})}, {0.98, addPose(P.SIT, {Neck = {22, 0, 0}, Head = {18, 0, 0}, Jaw = {-12, 0, 0}})}, {1.05, P.SIT, "out"}, {2.6, P.SIT}, {3.15, P.PROUD, "back"}, {5.4, P.PROUD}})
		local layer = breathe(t, 1)
		if t > 1.0 and t < 1.85 then local k = 1 - win(t, 1.4, 1.85) layer = addPose(layer, {Neck = {6 * math.sin(t * 11) * k, 16 * math.sin(t * 6.5) * k, 10 * math.cos(t * 6.5) * k}, Head = {0, 0, 10 * math.sin(t * 6.5 + 1) * k}}) end
		if t > 1.9 and t < 2.55 then local u = win(t, 1.9, 2.55) local env = math.sin(u * math.pi) layer = addPose(layer, {Neck = {0, 26 * math.sin(u * math.pi * 7) * env, 0}, Head = {0, 10 * math.sin(u * math.pi * 7 - 0.7) * env, 0}}) end
		if t > 3.2 then layer = addPose(layer, {Tail2 = {0, 8 * math.sin(t * 2.4), 0}, Tail3 = {0, 12 * math.sin(t * 2.4 - .6), 0}, Tail4 = {0, 14 * math.sin(t * 2.4 - 1.2), 0}}) end
		c:at("bonk", 1.0, function()
			kick(r, "Neck", -420) kick(r, "Head", -240, 0, 160)
			local h = headTop(r)
			c:flash(h, 0.25 * U, Color3.fromRGB(255, 242, 192))
			c:sparks(h, 10, 0.05 * U, Color3.fromRGB(255, 224, 128), 1.2 * U)
			c:orbitStars(r, 4, 1.0)
			c.shake = 0.5
			c.hit = h
		end)
		c:at("ding", 2.55, function() local p = headTop(r) c:sparks(p, 16, 0.06 * U, Color3.fromRGB(255, 240, 160), 1.0 * U) c:flash(p, 0.35 * U, Color3.fromRGB(255, 240, 160), 0.3) end)
		drive(r, A, dt, layer)
		-- crown
		local crownCF
		local sc = 1
		if t < 0.45 then crownCF = nil
		elseif t < 1.0 then
			local u = E.in2(win(t, 0.45, 1.0))
			local h = headTop(r)
			local st = h + V(0.12 * U, 2.6 * U, -0.1 * U)
			crownCF = CFrame.new(st:Lerp(h, u)) * CFrame.Angles(0.4 * math.sin(t * 9), t * 14, 0.3 * math.cos(t * 7))
		elseif t < 1.55 then
			local u = win(t, 1.0, 1.55)
			local p = c.hit:Lerp(headTop(r), u) + V(math.sin(math.pi * u) * 0.22 * U, 4 * 0.42 * U * u * (1 - u), -math.sin(math.pi * u) * 0.05 * U)
			crownCF = CFrame.new(p) * CFrame.Angles(u * math.pi * 2, u * 3, 0.5 * math.sin(u * 9))
		else
			local tilt, slide = 0.5, 0.25
			if t < 1.75 then local u = win(t, 1.55, 1.75) tilt = 0.5 + 0.15 * math.sin(u * math.pi * 3) * (1 - u)
			elseif t < 2.55 then local u = win(t, 1.9, 2.55) tilt = 0.5 * (1 - E.io(u)) + (u > 0 and 0.18 * math.sin(t * 38) * (1 - u) or 0) slide = 0.25 * (1 - E.io(u))
			else tilt = 0.06 * math.sin((t - 2.55) * 30) * math.exp(-(t - 2.55) * 6) slide = 0 end
			crownCF = r.segW.Head * CFrame.new(r.headTopL + V(slide * c.crownR, -c.crownR * 0.05, 0)) * CFrame.Angles(0, 0, -tilt)
		end
		for _, e in ipairs(c.crown) do
			if crownCF then e.p.Transparency = 0 e.p.CFrame = crownCF * e.rel else e.p.Transparency = 1 end
		end
		local _ = sc
		if t > 3.3 then c.glT = (c.glT or 0) - dt if c.glT <= 0 and crownCF then c.glT = 0.9 c:flash((crownCF * CFrame.new(0, c.crownR * 0.9, 0)).Position, 0.12 * U, Color3.new(1, 1, 1), 0.35) end end
		for _, f in ipairs(c.flag) do
			local u = f.i / (c.fn - 1)
			local w = math.sin(t * 7 - f.i * 0.8) * 0.06 * U * u * (t > 2.6 and 1.6 or 1)
			f.p.CFrame = CFrame.new(c.flagBase + V(-0.012 * U - u * c.fw, math.sin(t * 5 - f.i) * 0.008 * U * u, w)) * CFrame.Angles(0, math.cos(t * 7 - f.i * 0.8) * 0.18 * u, 0)
		end
		for _, s in ipairs(c.ringParts) do s.Transparency = 0.15 + 0.25 * (0.5 + 0.5 * math.sin(t * 4)) end
		c:camShot(t, dt, {{0, V(-0.5, 0.28, -1), 1.0, 0, 0}, {0.5, V(-0.5, 0.18, -1), 1.05, 0.35, 0}, {0.95, V(-0.42, 0.3, -1), 0.62, 0, 0.6, "out"}, {2.55, V(-0.42, 0.3, -1), 0.6, 0, 0.6}, {3.2, V(-0.52, 0.12, -1), 0.98, 0, 0.1}, {5.4, V(-0.56, 0.14, -1), 1.02, 0, 0.1}}, worldBox(r), headC(r))
	end,
}

-- =====================================================================================================================
-- 3 · UNKILLABLE
TITLES.unkill = {
	setup = function(c) c.met = c:meteor(0.16 * c.r.U) end,
	update = function(c, t, dt)
		local r, U = c.r, c.r.U
		local LUP = addPose(P.CHILL, {Neck = {26, 8, 0}, Head = {20, 6, 0}, Jaw = {-6, 0, 0}})
		local LROCK = {Neck = {-10, 28, 0}, Head = {-6, 14, 0}}
		local LCAM = {RootJoint = {2, 0, 0}, Neck = {6, -16, 0}, Head = {-2, -10, 6}}
		local A = pk(t, {{0, P.CHILL}, {1.7, P.CHILL}, {1.78, addPose(P.CHILL, {Neck = {-8, 0, 0}})}, {2.0, P.CHILL}, {2.45, LUP}, {2.85, LROCK}, {3.15, LCAM}, {3.5, P.SHRUG, "back"}, {3.95, P.SHRUG}, {4.3, P.CHILL}, {5.4, P.CHILL}})
		local chew = (t < 1.7 or t > 4.25) and 1 or 0
		local layer = addPose(breathe(t, 1), {Jaw = {chew * (-5 - 7 * math.max(0, math.sin(t * 2 * math.pi * 2.4))), 0, 0}, Head = {0, 0, chew * 3 * math.sin(t * 2 * math.pi * 1.2)}})
		local h = headTop(r)
		c.metStart = c.metStart or (h + V(-1.3 * U, 3.3 * U, 0.9 * U))
		local st = c.metStart
		c:at("glint", 0.5, function() c:flash(st, 0.3 * U, Color3.fromRGB(255, 224, 176), 0.5) end)
		if t > 0.85 and t < 1.7 then
			c.met.show(true)
			c.met.part.CFrame = CFrame.new(st:Lerp(h, win(t, 0.85, 1.7))) * CFrame.Angles(t * 6, 0, t * 4)
		end
		c:at("hit", 1.7, function()
			c.met.show(false)
			c.hitStop = 0.12
			c:flash(h, 0.7 * U, Color3.fromRGB(255, 224, 160), 0.25)
			c:sparks(h, 22, 0.07 * U, Color3.fromRGB(255, 192, 96), 1.6 * U)
			c.shake = 1.0
			for i = 1, 12 do
				local a = math.random() * math.pi * 2
				local s = (0.035 + math.random() * 0.04) * U
				local rk = c:rock(s, i % 3 ~= 0 and Color3.fromRGB(90, 74, 62) or Color3.fromRGB(122, 102, 86))
				rk.CFrame = CFrame.new(h + V(0, 0.05 * U, 0))
				c:debris(rk, V(math.cos(a) * (0.6 + math.random()) * U, (0.9 + math.random() * 0.9) * U, math.sin(a) * (0.6 + math.random()) * U), V(math.random() * 9, math.random() * 9, math.random() * 9), {r = s, grav = 5 * U, life = 3.6, bounce = 0.4})
			end
			c:puff(h, V(0, 0.3 * U, 0), 0.3 * U, Color3.fromRGB(138, 128, 120), 1.0, 0.7)
			kick(r, "Neck", -170) kick(r, "Head", 0, 0, 140)
		end)
		if t > 1.75 and t < 4.9 then c.smT = (c.smT or 0) - dt if c.smT <= 0 then c.smT = 0.11 c:puff(headTop(r) + V(0, 0.02 * U, 0), V(0.05 * U, 0.35 * U, 0), 0.05 * U, Color3.fromRGB(154, 154, 154), 1.1, 0.5) end end
		if t > 4.45 and t < 4.75 then
			if not c.peb then c.peb = c:rock(0.03 * U, Color3.fromRGB(106, 90, 74)) end
			c.peb.CFrame = CFrame.new(h + V(0.05 * U, 1.4 * U * (1 - E.in2(win(t, 4.45, 4.75))), 0))
		end
		c:at("pebble", 4.75, function() if c.peb then c:debris(c.peb, V(0.5 * U, 0.8 * U, -0.2 * U), V(8, 3, 5), {r = 0.03 * U, grav = 5 * U, life = 2}) end c:flash(h, 0.1 * U, Color3.new(1, 1, 1), 0.12) end)
		drive(r, A, dt, layer)
		c:camShot(t, dt, {{0, V(-0.5, 0.28, -1), 0.9, 0, 0.2}, {0.85, V(-0.5, 0.2, -1), 1.15, 0.4, 0}, {1.55, V(-0.42, 0.3, -1), 0.68, 0.05, 0.5, "out"}, {2.6, V(-0.45, 0.3, -1), 0.8, 0, 0.3}, {5.4, V(-0.5, 0.3, -1), 0.9, 0, 0.2}},
			worldBox(r), headC(r), (t > 0.85 and t < 1.7) and c.met.part.Position or nil, kf(t, {{0.8, 0}, {1.05, 0.12}, {1.5, 0.05}, {1.7, 0}}))
	end,
}

-- =====================================================================================================================
-- 4 · MEDIC
local function peckPoint(r, pose)
	local sp, sy = r.pos, r.yaw
	r.pos, r.yaw = V(0, 0, 0), 0
	poseRig(r, pose)
	local p = mouthPt(r) - r.O
	r.pos, r.yaw = sp, sy
	poseRig(r, {})
	return p
end
TITLES.medic = {
	setup = function(c)
		local r, U = c.r, c.r.U
		local m0 = peckPoint(r, P.PECK)
		local kh = math.clamp(m0.Y - 0.02 * U, 0.12 * U, 0.4 * U)
		local kw, kd = 0.36 * U, 0.26 * U
		c.kitParts = {}
		local function add(size, col, rel, lid, mat) local p = c:part(size, col, {material = mat}) table.insert(c.kitParts, {p = p, rel = rel, lid = lid}) return p end
		local W, R = Color3.fromRGB(242, 242, 242), Color3.fromRGB(224, 40, 74)
		add(V(kw, kh * 0.78, kd), W, CFrame.new(0, kh * 0.39, 0))
		add(V(kw * 1.01, kh * 0.08, kd * 1.01), Color3.fromRGB(216, 216, 216), CFrame.new(0, kh * 0.7, 0))
		add(V(kw * 0.12, kh * 0.4, 0.01 * U), R, CFrame.new(0, kh * 0.38, -kd / 2 - 0.004 * U))
		add(V(kw * 0.36, kh * 0.13, 0.01 * U), R, CFrame.new(0, kh * 0.38, -kd / 2 - 0.004 * U))
		add(V(kw * 0.9, 0.01 * U, kd * 0.85), Color3.fromRGB(192, 48, 58), CFrame.new(0, kh * 0.77, 0))
		-- lid (rel to the hinge at the back top edge)
		add(V(kw * 1.03, kh * 0.22, kd * 1.03), Color3.fromRGB(248, 248, 248), CFrame.new(0, kh * 0.11, -kd / 2), true)
		add(V(kw * 0.12, 0.012 * U, kd * 0.6), R, CFrame.new(0, kh * 0.225, -kd / 2), true)
		add(V(kw * 0.5, 0.012 * U, kd * 0.16), R, CFrame.new(0, kh * 0.225, -kd / 2), true)
		c.hingeRel = CFrame.new(0, kh * 0.78, kd / 2)
		c.kitPos = V(m0.X, 0, m0.Z)
		c.kh = kh
		c.lid = {x = 0, v = 0, tg = 0}
		-- plaster on the snout (head-segment units)
		local hb = r.headBox
		local hw = hb.mx.X - hb.mn.X
		c.plaster = {c:part(V(hw * 1.15, hw * 0.08, hw * 0.34), Color3.fromRGB(241, 199, 156), {shadow = false}), c:part(V(hw * 0.4, hw * 0.1, hw * 0.24), Color3.fromRGB(251, 233, 214), {shadow = false})}
		c.snout = V((hb.mn.X + hb.mx.X) / 2, hb.mx.Y, lerp(r.mouthL.Z, (hb.mn.Z + hb.mx.Z) / 2, 0.45))
	end,
	update = function(c, t, dt)
		local r, U = c.r, c.r.U
		local CUR = {Neck = {-14, -6, 0}, Head = {-4, 0, 18}}
		local DIP = addPose(P.PECK, {Neck = {-8, 0, 0}, Head = {-6, 0, 0}})
		local WIND = BOTH({RootJoint = {10, 0, 0}, Neck = {28, 0, 0}, Head = {-12, 0, 0}, ArmL = {-20, 0, 0}})
		local LUNGE = BOTH({RootJoint = {-2, 0, 0}, Neck = {6, 0, 0}, Head = {-2, 0, 0}, Jaw = {-34, 0, 0}, ArmL = {-46, 0, 0}, LegL = {-10, 0, 0}, KneeL = {-10, 0, 0}})
		local A = pk(t, {{0, P.IDLE}, {0.55, P.IDLE}, {0.78, CUR}, {0.95, P.PECK_UP}, {1.05, P.PECK, "out"}, {1.18, P.PECK_UP}, {1.36, DIP}, {1.52, DIP}, {1.72, P.PECK_UP, "out"}, {2.05, P.IDLE}, {2.3, WIND}, {2.48, LUNGE, "out5"}, {2.66, LUNGE}, {3.05, P.PROUD, "out"}, {5.4, P.PROUD}})
		local layer = breathe(t, 1)
		if t > 1.72 and t < 2.12 then local u = win(t, 1.72, 2.12) local env = math.sin(u * math.pi) layer = addPose(layer, {Neck = {0, 22 * math.sin(u * math.pi * 6) * env, 0}, Head = {0, 14 * math.sin(u * math.pi * 6 - 0.8) * env, 8 * math.sin(u * math.pi * 6)}}) end
		c:at("aim", 2.0, function()
			c.camAt = c.stage.camera.CFrame.Position
			c.yawCam = yawTo(c.O + r.pos, c.camAt)
			local mo = mouthPt(r)
			c.lungeD = math.clamp(V(c.camAt.X - mo.X, 0, c.camAt.Z - mo.Z).Magnitude - 0.95 * U, 0, 0.8 * U)
		end)
		local yc = c.yawCam or 0
		r.yaw = kf(t, {{2.05, 0}, {2.32, yc}, {3.0, yc}, {3.6, yc * 0.4}})
		local dir = c.camAt and V(c.camAt.X - c.O.X, 0, c.camAt.Z - c.O.Z).Unit or V(0, 0, -1)
		local lung = kf(t, {{2.3, 0}, {2.5, c.lungeD or 0, "out5"}, {2.68, c.lungeD or 0}, {3.1, 0, "out"}})
		r.pos = dir * lung
		-- kit drop + lid
		local ky = kf(t, {{0.12, 2.6 * U}, {0.55, 0, "in2"}})
		c:at("kitland", 0.55, function() c:dust(c:W(c.kitPos.X, 0, c.kitPos.Z), 10, 0.12 * U, 0.6 * U) end)
		c:at("open", 1.05, function()
			c.lid.tg = rad(-118) c.lid.v -= 14
			local top = c:W(c.kitPos.X, c.kh, c.kitPos.Z)
			for i = 1, 9 do
				local v = V((math.random() - .5) * 0.7 * U, (0.7 + math.random() * 0.6) * U, (math.random() - .5) * 0.7 * U)
				local p0 = top
				c:icon("heart", top, 0.09 * U, 1.6, 0, function(u) return p0 + v * (1 - (0.3 ^ (u * 1.6))) / 1.2 end)
			end
			c:sparks(top, 10, 0.04 * U, Color3.fromRGB(255, 208, 224), 0.8 * U)
		end)
		local n = math.max(1, math.ceil(dt * 240))
		for _ = 1, n do local h = dt / n c.lid.v += (18 * 18 * (c.lid.tg - c.lid.x) - 2 * 0.32 * 18 * c.lid.v) * h c.lid.x += c.lid.v * h end
		local kitCF = CFrame.new(c:W(c.kitPos.X, ky, c.kitPos.Z))
		for _, e in ipairs(c.kitParts) do
			e.p.Transparency = t > 0.12 and 0 or 1
			e.p.CFrame = e.lid and (kitCF * c.hingeRel * CFrame.Angles(c.lid.x, 0, 0) * e.rel) or (kitCF * e.rel)
		end
		c:at("slap", 2.62, function() c.shake = 1.3 c.hitStop = 0.06 end)
		c.ui.flash(t < 2.62 and 0 or 0.55 * (1 - win(t, 2.62, 2.85)))
		if t >= 2.62 then local u = win(t, 2.62, 2.82) c.ui.plaster(0.95, 1.8 - 0.8 * E.back(u)) else c.ui.plaster(0, 1) end
		-- snout plaster
		local showPl = t > 1.5
		if showPl then
			local cf = r.segW.Head * CFrame.new(c.snout) * CFrame.Angles(0, 0, 0.25 + (t < 2.1 and 0.08 * math.sin(t * 20) or 0))
			c.plaster[1].CFrame = cf c.plaster[2].CFrame = cf * CFrame.new(0, 0.01, 0)
		end
		c.plaster[1].Transparency = showPl and 0 or 1
		c.plaster[2].Transparency = showPl and 0 or 1
		if t > 3.0 then
			c.hT = (c.hT or 0) - dt
			if c.hT <= 0 then
				c.hT = 0.16
				local a = math.random() * math.pi * 2
				local p0 = c:W(r.pos.X + math.cos(a) * 0.4 * U, (0.1 + math.random() * 0.6) * r.H, r.pos.Z + math.sin(a) * 0.4 * U)
				c:icon(math.random() < 0.7 and "plus" or "heart", p0, 0.08 * U, 1.2, 0.35 * U)
			end
		end
		drive(r, A, dt, layer)
		c.camHold = t > 2.2 and t < 3.0
		c:camShot(t, dt, {{0, V(-0.35, 0.32, -1), 0.95, 0, 0}, {0.6, V(-0.45, 0.35, -1), 0.85, -0.1, 0}, {1.9, V(-0.4, 0.2, -1), 0.8, 0, 0.3}, {2.2, V(-0.3, 0.06, -1), 0.9, 0, 0.45}, {3.2, V(-0.3, 0.12, -1), 0.95, 0, 0.2}, {5.4, V(-0.35, 0.22, -1), 1.0, 0, 0}},
			boxUnion(worldBox(r), boxOfParts({c.kitParts[1].p})), headC(r))
	end,
}

-- =====================================================================================================================
-- 5 · BUTTON MASHER
TITLES.masher = {
	setup = function(c)
		local r, U = c.r, c.r.U
		local m0 = peckPoint(r, P.PECK)
		local domeH = 0.05 * U
		local ph = math.max(0.08 * U, m0.Y - domeH - 0.02 * U)
		local base = CFrame.new(c:W(m0.X, 0, m0.Z))
		local ped = c:part(V(0.2 * U, ph, 0.2 * U), Color3.fromRGB(43, 50, 66)) ped.CFrame = base * CFrame.new(0, ph / 2, 0)
		local trim = c:part(V(0.23 * U, 0.025 * U, 0.23 * U), Color3.fromRGB(255, 200, 50)) trim.CFrame = base * CFrame.new(0, ph, 0)
		local stripe = c:part(V(0.205 * U, 0.03 * U, 0.205 * U), Color3.fromRGB(255, 200, 50)) stripe.CFrame = base * CFrame.new(0, ph * 0.3, 0)
		local ringm = c:part(V(0.02 * U, 0.18 * U, 0.18 * U), Color3.fromRGB(17, 17, 17), {shape = Enum.PartType.Cylinder}) ringm.CFrame = base * CFrame.new(0, ph + 0.02 * U, 0) * CFrame.Angles(0, 0, math.pi / 2)
		local dome = c:part(V(domeH * 1.6, 0.14 * U, 0.14 * U), Color3.fromRGB(224, 40, 58), {shape = Enum.PartType.Cylinder, material = Enum.Material.Neon})
		local coil = c:part(V(1, 0.04 * U, 0.04 * U), Color3.fromRGB(200, 204, 212), {shape = Enum.PartType.Cylinder, material = Enum.Material.Metal})
		coil.Transparency = 1
		c.btn = {base = base, dome = dome, coil = coil, ph = ph, domeY = ph + 0.02 * U + domeH / 2}
		c.hits, c.lastIdx, c.pop = 0, -1, 9
		c.coil = {x = 0, v = 0}
	end,
	update = function(c, t, dt)
		local r, U, B = c.r, c.r.U, c.btn
		local EYE = BOTH({RootJoint = {-4, 0, 0}, Neck = {-16, 0, 0}}) EYE.Head = {-6, 0, 16}
		local LUPB = BOTH({RootJoint = {6, 0, 0}, Neck = {40, 0, 0}, Head = {22, 0, 0}, Jaw = {-16, 0, 0}}) LUPB.Neck = {40, 22, 0}
		local LCAM = {Neck = {0, -16, 0}, Head = {-2, -8, 0}, Jaw = {-8, 0, 0}}
		local SLUMP = BOTH({RootJoint = {-6, 0, 0}, Neck = {-16, 0, 0}, Head = {4, 0, 0}, ArmL = {10, 0, 0}, Tail1 = {10, 0, 0}, Tail2 = {6, 0, 0}})
		local A, direct, layer = nil, false, nil
		local press = 0
		if t >= 0.85 and t < 3.0 then
			local ph = (t - 0.85) * 7.2
			local f = 0.5 - 0.5 * math.cos(ph * math.pi * 2)
			local idx = math.floor(ph + 0.5)
			A = lerpPose(P.PECK_UP, P.PECK, f ^ 0.7)
			direct = true
			local st = math.sin(t * math.pi * 2 * 3.6)
			A = addPose(A, {LegL = {12 * math.max(0, st), 0, 0}, KneeL = {-22 * math.max(0, st), 0, 0}, LegR = {12 * math.max(0, -st), 0, 0}, KneeR = {-22 * math.max(0, -st), 0, 0}, Tail1 = {0, 14 * math.sin(t * 46), 0}, Tail2 = {0, 18 * math.sin(t * 46 - .8), 0}, Tail3 = {0, 20 * math.sin(t * 46 - 1.6), 0}, ArmL = {-20 * f, 0, 0}, ArmR = {-20 * f, 0, 0}})
			if idx > c.lastIdx and (ph - math.floor(ph)) > 0.45 then
				c.lastIdx = idx
				c.hits = math.min(47, math.max(c.hits + 1, math.floor(47 * sat((t - 0.85) / 2.1) ^ 1.3 + 0.5)))
				c:sparks(B.base.Position + V(0, B.domeY + 0.04 * U, 0), 5, 0.04 * U, c.hits > 30 and Color3.fromRGB(255, 160, 64) or Color3.fromRGB(255, 244, 200), 0.7 * U)
				c.pop = 0
				c.shake = math.max(c.shake, 0.25)
			end
			press = f
		elseif t < 0.85 then
			A = pk(t, {{0, P.IDLE}, {0.4, EYE}, {0.62, P.PECK_UP}, {0.78, P.PECK, "out"}, {0.85, P.PECK_UP}})
			c:at("first", 0.78, function() c.hits = 1 c.pop = 0 c:sparks(B.base.Position + V(0, B.domeY + 0.04 * U, 0), 4, 0.04 * U, Color3.fromRGB(255, 244, 200), 0.6 * U) end)
		else
			A = pk(t, {{3.0, P.PECK}, {3.32, P.PECK}, {3.75, LUPB, "out"}, {4.0, LUPB}, {4.25, LCAM}, {4.38, P.PECK_UP}, {4.5, P.PECK, "out"}, {4.62, P.PECK_UP}, {4.95, SLUMP}, {5.4, SLUMP}})
			layer = breathe(t, 0.6)
		end
		local heat = sat(c.hits / 47)
		B.dome.Color = Color3.fromRGB(224, 40, 58):Lerp(Color3.fromRGB(255, 150, 40), heat)
		if not c.popped then B.dome.CFrame = B.base * CFrame.new(0, B.domeY - 0.022 * U * press, 0) * CFrame.Angles(0, 0, math.pi / 2) end
		if t > 2.1 and t < 3.6 then c.smT = (c.smT or 0) - dt if c.smT <= 0 then c.smT = 0.07 c:puff(B.base.Position + V(0, B.ph + 0.08 * U, 0), V((math.random() - .5) * 0.1 * U, 0.5 * U, 0), 0.06 * U, Color3.fromRGB(106, 106, 106), 0.9, 0.6) end end
		c:at("pop", 3.0, function()
			c.hits = 47 c.pop = 0 c.hitStop = 0.07 c.shake = 0.8
			local p = B.base.Position + V(0, B.domeY, 0)
			c:flash(p, 0.3 * U, Color3.fromRGB(255, 208, 160)) c:sparks(p, 24, 0.06 * U, Color3.fromRGB(255, 176, 64), 1.6 * U)
			c.popped = true
			c:debris(B.dome, V(0.7 * U, 4.2 * U, 0.5 * U), V(9, 4, 7), {r = 0.05 * U, grav = 2.4 * U, life = 3, bounce = 0.3, fade = false})
			c.fly = B.dome
			c.coil.v = 14
			B.coil.Transparency = 0
			for _ = 1, 3 do local bolt = c:part(V(0.02, 0.01, 0.01) * U, Color3.fromRGB(154, 160, 170)) bolt.CFrame = CFrame.new(p) c:debris(bolt, V((math.random() - .5) * 1.4 * U, (1 + math.random()) * U, (math.random() - .5) * 1.4 * U), V(10, 10, 10), {r = 0.01 * U, grav = 5 * U, life = 2.4}) end
		end)
		c:at("thunk", 3.05, function() c:dust(B.base.Position + V(0, B.ph, 0), 6, 0.06 * U, 0.3 * U, Color3.fromRGB(154, 154, 154)) end)
		c:at("sad", 4.5, function() c.hits = 48 c.pop = 0 c.sad = true c:flash(B.base.Position + V(0, B.ph + 0.03 * U, 0), 0.1 * U, Color3.new(1, 1, 1), 0.12) end)
		if B.coil.Transparency < 1 then
			local n = math.max(1, math.ceil(dt * 240))
			for _ = 1, n do local h = dt / n c.coil.v += (30 * 30 * (0 - c.coil.x) - 2 * 0.2 * 30 * c.coil.v) * h c.coil.x += c.coil.v * h end
			local L = 0.12 * U * math.max(0.2, 1 + c.coil.x * 0.4)
			B.coil.Size = V(L, 0.04 * U, 0.04 * U)
			B.coil.CFrame = B.base * CFrame.new(0, B.ph + 0.02 * U + L / 2, 0) * CFrame.Angles(0, 0, math.pi / 2)
		end
		c.pop += dt
		if c.hits > 0 and t < 5.2 then
			local k = 1 + 0.5 * math.max(0, 1 - c.pop / 0.12)
			c.ui.counter("x" .. c.hits, k, c.sad and Color3.fromRGB(143, 153, 170) or (heat > 0.6 and Color3.fromRGB(255, 176, 64) or Color3.new(1, 1, 1)))
		else c.ui.counter(nil) end
		drive(r, A, dt, layer, direct)
		local flyLook = (c.fly and t < 4.0) and c.fly.Position or nil
		c:camShot(t, dt, {{0, V(1, 0.32, -0.6), 0.95, 0, 0}, {0.85, V(1, 0.24, -0.65), 0.75, 0, 0.3}, {3.0, V(1, 0.2, -0.65), 0.66, 0, 0.35, "lin"}, {3.35, V(1, 0.28, -0.65), 1.0, 0.25, 0}, {4.1, V(1, 0.3, -0.68), 0.9, 0, 0.1}, {5.4, V(1, 0.32, -0.68), 0.95, 0, 0.1}},
			boxUnion(worldBox(r), {mn = B.base.Position - V(0.1 * U, 0, 0.1 * U), mx = B.base.Position + V(0.1 * U, B.ph, 0.1 * U)}), headC(r), flyLook, kf(t, {{3.05, 0}, {3.4, 0.45}, {3.85, 0.3}, {4.1, 0}}))
	end,
}

-- =====================================================================================================================
-- 6 · CARRIED
TITLES.carried = {
	setup = function(c)
		local r, m, U = c.r, c.m, c.r.U
		c.U0 = U
		-- mate at 1.12 × the carried dino's height
		local k = math.clamp(1.12 * r.H / math.max(0.1, m.H), 0.4, 3)
		if math.abs(k - 1) > 0.02 then m.model:ScaleTo(m.model:GetScale() * k) measure(m) end
		poseRig(r, {})
		local tt = tailTip(r) - r.O
		m.pos, m.yaw = V(0, 0, 0), 0
		local best, bd = 0, math.huge
		for b = 0, 20 do
			poseRig(m, lerpPose(P.IDLE, P.PECK, b / 20))
			local d = math.abs((mouthPt(m) - m.O).Y - tt.Y)
			if d < bd then bd, best = d, b / 20 end
		end
		c.bite = lerpPose(P.IDLE, P.PECK, best)
		poseRig(m, c.bite)
		local mm = mouthPt(m) - m.O
		c.M0 = V(tt.X - mm.X, 0, tt.Z - mm.Z)
		-- the bag: sized from the carried dino at 70 % going in nose first (1.1; v1.2 below when M.CARRIED_FIT)
		local Ls = 0.7 * r.L
		local bh = 0.46 * Ls
		c.B = V(-2.25 * U, 0, -0.55 * U)
		c.bh = bh
		-- measure the nose-down pose at 70 % on a throwaway pose (scale applied in the flight; here: rest measures × 0.7)
		local s07 = 0.7
		r.plant, r.yaw, r.rx, r.rz, r.pos = "none", 0, rad(-92), 0, V(0, 0, 0)
		poseRig(r, P.STARTLED)
		local hip = (segPt(r, "Tail1", V(0, 0, 0)) - r.O) * s07
		local inBox = worldBox(r, function(p) return true end)
		local ex = math.max(math.abs(inBox.mn.X - r.O.X), math.abs(inBox.mx.X - r.O.X)) * s07
		local ez = math.max(math.abs(inBox.mn.Z - r.O.Z), math.abs(inBox.mx.Z - r.O.Z)) * s07
		c.inBagHip = hip
		local bw = math.max(0.62 * bh, 2 * ex * 0.9)
		local bdp = math.max(0.5 * bh, 2 * ez * 0.9)
		c.bw, c.bd = bw, bdp
		c.shrinkK = 0.7
		if M.CARRIED_FIT then -- v1.2: one bag size from the mate; the carried dino shrinks to fit it
			local cb = M.CARRIED_BAG
			bh = cb.h * m.H
			bw, bdp = cb.w * bh, cb.d * bh
			c.bh, c.bw, c.bd = bh, bw, bdp
			-- the nose-down pose at full size, every part corner, measured from the hips
			r.plant, r.yaw, r.rx, r.rz, r.pos = "none", 0, rad(-92), 0, V(0, 0, 0)
			poseRig(r, P.STARTLED)
			local hipW = segPt(r, "Tail1", V(0, 0, 0))
			local ex, ez, below = 1e-3, 1e-3, 1e-3
			for _, p in ipairs(r.parts) do
				local f = r.segW[p.seg]
				if f then
					for _, cn in ipairs(p.cs) do
						local w = f * cn - hipW
						ex, ez, below = math.max(ex, math.abs(w.X)), math.max(ez, math.abs(w.Z)), math.max(below, -w.Y)
					end
				end
			end
			c.shrinkK = math.clamp(cb.fit * math.min(bw / (2 * ex), bdp / (2 * ez), bh / below), 0.05, 1)
			c.inBagHip = (hipW - r.O) * c.shrinkK
			M.lastCarriedK = c.shrinkK
			M.lastCarriedInfo = ("mate H %.2f bag %.2fx%.2fx%.2f k %.3f"):format(m.H, bw, bh, bdp, c.shrinkK)
		end
		r.plant, r.rx, r.pos = "feet", 0, V(0, 0, 0)
		poseRig(r, {})
		-- bag parts (rel to the bag base)
		local BLUE, DK = Color3.fromRGB(61, 127, 224), Color3.fromRGB(36, 80, 143)
		c.bag = {}
		local function add(size, col, rel, key) local p = c:part(size, col) table.insert(c.bag, {p = p, rel = rel, key = key}) return p end
		add(V(bw, bh, bdp), BLUE, CFrame.new(0, bh / 2, 0))
		add(V(bw * 0.92, bh * 0.06, bdp * 0.92), BLUE, CFrame.new(0, bh * 1.02, 0))
		add(V(bw * 0.7, bh * 0.38, bdp * 0.18), DK, CFrame.new(0, bh * 0.3, -bdp / 2 - bdp * 0.08))
		add(V(bw * 0.6, bh * 0.02, 0.01 * U), Color3.fromRGB(255, 200, 50), CFrame.new(0, bh * 0.47, -bdp / 2 - bdp * 0.175))
		for _, sx in ipairs({-1, 1}) do
			add(V(bw * 0.12, bh * 0.5, bdp * 0.3), DK, CFrame.new(sx * (bw / 2 + bw * 0.05), bh * 0.3, 0))
			add(V(bw * 0.1, bh * 0.8, bdp * 0.06), Color3.fromRGB(29, 42, 68), CFrame.new(sx * bw * 0.25, bh * 0.5, bdp / 2 + bdp * 0.04))
		end
		add(V(bw * 0.86, 0.01 * U, bdp * 0.8), Color3.fromRGB(13, 26, 51), CFrame.new(0, bh * 1.055, 0))
		add(V(bw * 0.9, bh * 0.025, bdp * 0.06), Color3.fromRGB(255, 200, 50), CFrame.new(0, bh * 1.06, -bdp * 0.42))
		add(V(bw * 0.06, bh * 0.1, bw * 0.06), Color3.fromRGB(29, 42, 68), CFrame.new(-bw * 0.12, bh * 1.12, 0))
		add(V(bw * 0.06, bh * 0.1, bw * 0.06), Color3.fromRGB(29, 42, 68), CFrame.new(bw * 0.12, bh * 1.12, 0))
		add(V(bw * 0.3, bh * 0.04, bw * 0.06), Color3.fromRGB(29, 42, 68), CFrame.new(0, bh * 1.17, 0))
		c.cover = add(V(1, bh * 0.05, bdp * 0.86), BLUE, CFrame.new(0, bh * 1.07, 0), "cover")
		c.pull = add(V(bw * 0.06, bh * 0.08, bw * 0.04), Color3.fromRGB(255, 224, 128), CFrame.new(0, bh * 1.1, -bdp * 0.42), "pull")
		local tcol = Color3.fromRGB(90, 120, 60)
		for _, p in ipairs(r.parts) do if string.match(p.seg, "^Tail") then tcol = p.part.Color break end end
		for i = 0, 2 do add(V(bw * 0.14 * (1 - i * 0.22), bw * 0.14 * (1 - i * 0.22), bh * 0.18), tcol, CFrame.new(bw * 0.36, bh * 1.08, 0) * CFrame.new(0, 0, i * bh * 0.16), "tail" .. i) end
		c.bagSq = {x = 1, v = 0}
		m.pos = c.M0
		poseRig(m, c.bite)
		c.M, c.matePh, c.spin = c.M0, 0, 0
		-- the mate's pick-up spot (mouth on the handle)
		local sp = m.pos
		m.pos, m.yaw = V(0, 0, 0), yawTo(c.M0, c.B)
		poseRig(m, P.PECK)
		local pm = mouthPt(m) - m.O
		c.yawBag = m.yaw
		c.Mpick = V(c.B.X - pm.X, 0, c.B.Z - pm.Z)
		m.pos, m.yaw = sp, 0
		poseRig(m, c.bite)
	end,
	update = function(c, t, dt)
		local r, m, U = c.r, c.m, c.U0
		-- ---- mate ----
		local mA
		local enter = win(t, 0.05, 0.62)
		if t < 0.95 then
			c.M = c.M0 + V(3.0 * U * (1 - E.out(enter)), 0, 0)
			m.yaw = kf(t, {{0, math.pi / 2}, {0.48, math.pi / 2}, {0.66, 0}})
			c.matePh += dt * 2.6 * (1 - enter * 0.85)
			mA = pk(t, {{0, P.STALK}, {0.5, P.STALK}, {0.66, addPose(c.bite, {Jaw = {-34, 0, 0}})}, {0.74, c.bite, "out5"}})
			if t < 0.6 then mA = addPose(mA, walkLayer(c.matePh, 1 - win(t, 0.4, 0.6), m)) end
		elseif t < 2.35 then
			local u = win(t, 0.95, 2.35)
			c.spin = 2 * math.pi * 1.6 * u * u
			m.yaw = c.spin
			c.M = c.M0
			local SPIN = BOTH({RootJoint = {14, 0, 0}, Neck = {-6, 0, 0}, Head = {6, 0, 0}, ArmL = {-24, 0, 0}, Tail1 = {-8, 0, 0}, Tail2 = {-6, 0, 0}})
			mA = addPose(lerpPose(c.bite, SPIN, E.io(win(t, 0.95, 1.2))), walkLayer(c.spin / math.pi, 0.45, m))
			c.duT = (c.duT or 0) - dt
			if c.duT <= 0 then c.duT = 0.08 local a = math.random() * math.pi * 2 c:puff(c.O + c.M + V(math.cos(a) * 0.3 * U, 0.05 * U, math.sin(a) * 0.3 * U), V(-math.sin(a), 0.2, math.cos(a)) * 0.8 * U, 0.14 * U, Color3.fromRGB(217, 201, 160), 0.7, 0.7) end
		elseif t < 3.3 then
			local u = win(t, 2.35, 3.0)
			m.yaw = c.spin + 2.2 * E.out(u)
			c.M = c.M0
			mA = addPose(BOTH({RootJoint = {-4, 0, 0}, Neck = {10, 0, 0}, Head = {-6, 0, 0}, ArmL = {-10, 0, 0}}), {Neck = {0, 14 * math.sin(t * 7), 10 * math.cos(t * 7)}, Head = {0, 0, 10 * math.sin(t * 7 + 1)}})
			c:at("dizzy", 2.4, function() c:orbitStars(m, 3, 0.9) end)
		elseif t < 4.95 then
			local yaw0 = c.spin + 2.2
			local u = win(t, 3.45, 4.3)
			m.yaw = kf(t, {{3.3, yaw0}, {3.5, c.yawBag + math.floor((yaw0 - c.yawBag) / (2 * math.pi) + 0.5) * 2 * math.pi}})
			c.M = c.M0:Lerp(c.Mpick, E.io(u))
			if u > 0 and u < 1 then c.matePh += dt * 2.2 end
			local FLING = BOTH({RootJoint = {14, 0, 0}, Neck = {46, 0, 0}, Head = {26, 0, 0}, Jaw = {-30, 0, 0}, ArmL = {-30, 0, 0}, LegL = {6, 0, 0}, KneeL = {-14, 0, 0}})
			mA = pk(t, {{3.3, P.IDLE}, {4.3, P.IDLE}, {4.44, P.PECK, "out"}, {4.52, P.PECK}, {4.66, FLING, "out5"}, {4.85, FLING}, {4.95, P.PROUD}})
			if u > 0 and u < 1 then mA = addPose(mA, walkLayer(c.matePh, 0.9, m)) end
			c:at("backland", 4.85, function() c.bagSq.v -= 5 kick(m, "Neck", -300) c:dust(c.O + c.M, 8, 0.12 * U, 0.5 * U) end)
		else
			local u = t - 4.95
			local dir = V(-1, 0, -0.32).Unit
			local yd = yawTo(V(0, 0, 0), dir)
			m.yaw = kf(t, {{4.95, c.yawBag}, {5.2, yd + math.floor((c.yawBag - yd) / (2 * math.pi) + 0.5) * 2 * math.pi}})
			c.M = c.Mpick + dir * 1.5 * U * math.max(0, u - 0.1)
			c.matePh += dt * 3.0
			mA = addPose(addPose(P.PROUD, walkLayer(c.matePh, 1, m)), {Jaw = {-10, 0, 0}})
		end
		m.pos = c.M
		drive(m, mA, dt)
		-- ---- carried ----
		local A
		if t < 0.95 then
			r.plant, r.pos, r.yaw, r.rx, r.rz = "feet", V(0, 0, 0), 0, 0, 0
			A = pk(t, {{0, P.CHILL}, {0.72, P.CHILL}, {0.82, P.STARTLED, "out5"}})
			if t < 0.72 then A = addPose(A, {Neck = {4 * math.sin(t * 3), 22 * math.sin(t * 2.6), 0}, Head = {0, 10 * math.sin(t * 2.6 - .5), 0}}) end
			c:at("bang", 0.74, function() c:icon("bang", headTop(r) + V(0, 0.18 * U, 0), 0.22 * U, 0.8, 0.1 * U) kick(r, "Neck", 300) end)
			drive(r, A, dt)
		elseif t < 2.35 then
			local u = win(t, 0.95, 2.35)
			r.plant = "none"
			local mo = mouthPt(m)
			local out = V(mo.X - (c.O.X + c.M.X), 0, mo.Z - (c.O.Z + c.M.Z))
			out = out.Magnitude > 1e-3 and out.Unit or V(0, 0, -1)
			r.yaw = math.atan2(-out.X, -out.Z)
			r.rx = rad(10) * E.io(sat(u * 2))
			r.rz = 2 * math.pi * 0.8 * u * u
			A = addPose(P.STARTLED, flailLayer(t, E.io(sat(u * 2.5))))
			r.pos = V(0, 0, 0)
			drive(r, A, dt)
			local tt = tailTip(r)
			r.pos = mo - tt
			poseRig(r, r.A)
			c.rel = {pos = r.pos, yaw = r.yaw, rx = r.rx, rz = r.rz}
		elseif t < 3.05 then
			if not c.shrunk then -- poof: shrink to 70 % for the bag (Model:ScaleTo), once (v1.2: c.shrinkK, the fit to the bag)
				c.shrunk = true
				c:puff(r.hrp.Position, V(0, 0.2 * U, 0), 0.4 * U, Color3.new(1, 1, 1), 0.5, 0.6)
				r.model:ScaleTo(r.model:GetScale() * c.shrinkK)
				local sp = r.springs
				measure(r)
				r.springs = sp
				local tt = c.rel.pos
				-- the in-bag spot for the shrunk rig: hips just over the opening
				r.plant, r.yaw, r.rx, r.rz, r.pos = "none", 0, rad(-92), 0, V(0, 0, 0)
				poseRig(r, P.STARTLED)
				local hip = segPt(r, "Tail1", V(0, 0, 0)) - r.O
				c.inBag = V(c.B.X - hip.X, c.bh * 1.05 - hip.Y + 0.04 * U, c.B.Z - hip.Z)
				c.deep = c.inBag + V(0, -0.6 * c.bh, 0)
				r.pos = tt
			end
			local u = win(t, 2.35, 3.05)
			local e = E.io(u)
			r.plant = "none"
			local p = c.rel.pos:Lerp(c.inBag, u) + V(0, 4 * 1.1 * U * u * (1 - u), 0)
			r.pos = p
			local yawT = math.floor(c.rel.yaw / (2 * math.pi) + 0.5) * 2 * math.pi
			r.yaw = lerp(c.rel.yaw, yawT, e)
			r.rx = lerp(c.rel.rx, rad(-92), E.out(u))
			r.rz = lerp(c.rel.rz, math.ceil(c.rel.rz / (2 * math.pi) + 0.5) * 2 * math.pi, e)
			drive(r, addPose(P.STARTLED, flailLayer(t, 1)), dt)
		else
			r.plant, r.yaw, r.rx, r.rz = "none", 0, rad(-92), 0
			local sink = E.in2(win(t, 3.85, 4.1))
			r.pos = c.inBag:Lerp(c.deep, sink)
			local legs = flailLayer(t * 1.3, 1)
			A = addPose(P.STARTLED, {LegL = legs.LegL, LegR = legs.LegR, KneeL = legs.KneeL, KneeR = legs.KneeR, Tail1 = {0, 20 * math.sin(t * 13), 0}, Tail2 = {0, 26 * math.sin(t * 13 - 1), 0}, Tail3 = {0, 30 * math.sin(t * 13 - 2), 0}})
			if t < 4.1 then drive(r, A, dt) elseif r.model.Parent then r.model.Parent = nil end
			c:at("landbag", 3.05, function() c.bagSq.v -= 8 c.hitStop = 0.06 c.shake = 0.7 c:dust(c.O + c.B, 12, 0.2 * U, 0.9 * U) end)
			c:at("gulp", 4.05, function() c.bagSq.v -= 6 c:puff(c.O + c.B + V(0, c.bh * 1.1, 0), V(0, 0.4 * U, 0), 0.15 * U, Color3.new(1, 1, 1), 0.5, 0.6) end)
		end
		-- ---- bag ----
		local n = math.max(1, math.ceil(dt * 240))
		for _ = 1, n do local h = dt / n c.bagSq.v += (20 * 20 * (1 - c.bagSq.x) - 2 * 0.25 * 20 * c.bagSq.v) * h c.bagSq.x += c.bagSq.v * h end
		local bs = c.bagSq.x
		local bulge = t > 4.95 and 1 + 0.1 * math.max(0, math.sin((t - 4.95) * 5.5)) ^ 8 or 1
		local sxz = bulge / math.sqrt(math.max(0.2, bs))
		local tb = m.torsoBox
		local backL = V((tb.mn.X + tb.mx.X) / 2, tb.mx.Y * 0.95, lerp((tb.mn.Z + tb.mx.Z) / 2, tb.mx.Z, 0.35))
		local kb = math.clamp(0.42 * m.H / c.bh, 0.25, 1)
		if M.CARRIED_FIT then kb = 1 end -- v1.2: the bag is already the mate's size; it stays that size on the back
		local bagCF, bagK
		if t < 4.52 then bagCF, bagK = CFrame.new(c.O + c.B), 1
		else
			local onBack = m.segW.Torso * CFrame.new(backL)
			if t < 4.85 then
				local u = win(t, 4.52, 4.85)
				local e = E.io(u)
				local p = (c.O + c.B):Lerp(onBack.Position, e) + V(0, 4 * 0.9 * U * u * (1 - u), 0)
				bagCF = CFrame.new(p) * CFrame.new():Lerp(onBack.Rotation, e) * CFrame.Angles(2 * math.pi * e, 0, 0)
				bagK = lerp(1, kb, e)
			else
				bagCF = onBack * CFrame.new(0, math.abs(math.sin(c.matePh * math.pi * 2)) * 0.06 * c.bh * kb, 0)
				bagK = kb
			end
		end
		local zu = win(t, 3.2, 3.85)
		local cw = c.bw * 0.86 * (t < 4.05 and 0.78 or 1) * zu
		for _, e in ipairs(c.bag) do
			local rel = e.rel
			local p = e.p
			if e.key == "cover" then
				p.Transparency = zu > 0 and 0 or 1
				p.Size = V(math.max(0.01, cw * bagK), c.bh * 0.05 * bagK, c.bd * 0.86 * bagK)
				rel = CFrame.new(-c.bw * 0.43 + cw / 2, c.bh * 1.07, 0)
			elseif e.key == "pull" then
				p.Transparency = zu > 0 and 0 or 1
				rel = CFrame.new(-c.bw * 0.43 + cw, c.bh * 1.1, -c.bd * 0.42)
			elseif e.key and string.match(e.key, "^tail") then
				p.Transparency = t > 4.1 and 0 or 1
				rel = CFrame.new(c.bw * 0.36, c.bh * 1.08, 0) * CFrame.Angles(-0.9 + 0.25 * math.sin(t * 9), 0.5 * math.sin(t * 6), 0) * CFrame.new(0, 0, tonumber(string.sub(e.key, 5)) * c.bh * 0.16)
			end
			if not e.size then e.size = p.Size end
			if e.key ~= "cover" then p.Size = e.size * bagK * V(sxz, bs, sxz) end
			local rp = rel.Position * bagK
			p.CFrame = bagCF * CFrame.new(rp.X * sxz, rp.Y * bs, rp.Z * sxz) * rel.Rotation
		end
		if zu > 0 and zu < 1 then c.zT = (c.zT or 0) - dt if c.zT <= 0 then c.zT = 0.05 c:sparks(c.pull.Position, 2, 0.025 * U, Color3.fromRGB(255, 224, 128), 0.4 * U) end end
		c:at("mmph", 4.25, function() c:text("mmph!", c.O + c.B + V(0.2 * U, c.bh * 1.5, 0), 0.16 * U, 1.1) end)
		c:at("mmph2", 5.3, function() c:text("mmph!!", bagCF.Position + V(0, c.bh * 0.9 * bagK + 0.3 * U, 0), 0.14 * U, 1.0) end)
		-- camera: frames whatever matters now
		local bagBox = boxOfParts({c.bag[1].p})
		local fb
		if t < 2.35 then fb = worldBox(m) if r.model.Parent then fb = boxUnion(fb, worldBox(r)) end
		elseif t < 3.1 then fb = bagBox if r.model.Parent then fb = boxUnion(fb, worldBox(r)) end
		elseif t < 4.5 then fb = {mn = bagBox.mn - V(1, 1, 1) * 0.5 * U, mx = bagBox.mx + V(1, 1, 1) * 0.5 * U} if t > 3.6 then fb = boxUnion(fb, worldBox(m)) end
		else fb = boxUnion(worldBox(m), bagBox) fb = {mn = fb.mn - V(1, 1, 1) * 0.4 * U, mx = fb.mx + V(1, 1, 1) * 0.4 * U} end
		c:camFrame(fb, (t < 2.35 and t > 0.95) and V(-0.35, 0.85, -1) or V(-0.42, 0.42, -1), dt, t < 0.95 and 0.8 or 1.0, 0.9 * U)
	end,
}

-- =====================================================================================================================
-- 7 · PACIFIST
TITLES.pacifist = {
	setup = function(c)
		local r, U = c.r, c.r.U
		local m0 = peckPoint(r, P.SNIFF)
		local fh = math.max(0.1 * U, m0.Y - 0.07 * U)
		c.fl = {base = CFrame.new(c:W(m0.X, 0, m0.Z - 0.04 * U)), fh = fh, stem = {}, petals = {}}
		for i = 1, 4 do table.insert(c.fl.stem, c:part(V(0.014 * U, fh / 4, 0.014 * U), Color3.fromRGB(63, 154, 58), {shadow = false})) end
		c.fl.leaves = {c:part(V(0.09, 0.008, 0.04) * U, Color3.fromRGB(76, 170, 68)), c:part(V(0.09, 0.008, 0.04) * U, Color3.fromRGB(76, 170, 68))}
		c.fl.ctr = c:part(V(0.02 * U, 0.07 * U, 0.07 * U), Color3.fromRGB(255, 200, 50), {shape = Enum.PartType.Cylinder})
		for i = 0, 11 do table.insert(c.fl.petals, {p = c:part(V(0.075, 0.008, 0.03) * U, Color3.new(1, 1, 1), {shadow = false}), a = i / 12 * math.pi * 2}) end
		c.bf = {}
		for i = 1, 2 do
			local body = c:part(V(0.012, 0.012, 0.05) * U, Color3.fromRGB(42, 32, 24), {shadow = false})
			local col = i == 2 and Color3.fromRGB(127, 208, 255) or Color3.fromRGB(255, 160, 64)
			table.insert(c.bf, {body = body, wl = c:part(V(0.05, 0.004, 0.045) * U, col, {shadow = false}), wr = c:part(V(0.05, 0.004, 0.045) * U, col, {shadow = false}), i = i, pos = c:W(0, 0.3 * U, -0.3 * U)})
		end
	end,
	update = function(c, t, dt)
		local r, U, F = c.r, c.r.U, c.fl
		local AH1 = addPose(P.SNIFF, {Neck = {14, 0, 0}, Head = {18, 0, 0}, Jaw = {-10, 0, 0}})
		local AH2 = BOTH({RootJoint = {2, 0, 0}, Neck = {16, 0, 0}, Head = {24, 0, 0}, Jaw = {-18, 0, 0}, ArmL = {-14, 0, 0}})
		local AH3 = BOTH({RootJoint = {14, 0, 0}, Neck = {36, 0, 0}, Head = {34, 0, 0}, Jaw = {-28, 0, 0}, ArmL = {-30, 0, 0}, Tail1 = {-10, 0, 0}})
		local CHOO = BOTH({RootJoint = {-12, 0, 0}, Neck = {-34, 0, 0}, Head = {-14, 0, 0}, Jaw = {-55, 0, 0}, ArmL = {24, 0, 0}, Tail1 = {-14, 0, 0}})
		local ONBACK = BOTH({RootJoint = {-4, 0, 0}, Neck = {-16, 0, 0}, Head = {-8, 0, 0}, Jaw = {-26, 0, 0}, ArmL = {-30, 0, 16}, LegL = {14, 0, 12}, KneeL = {-30, 0, 0}, AnkleL = {16, 0, 0}, Tail1 = {-6, 0, 0}, Tail2 = {-4, 0, 0}})
		local WATCH = {Neck = {-12, 0, 0}, Head = {-6, 0, 14}}
		local A = pk(t, {{0, P.IDLE}, {0.3, WATCH}, {0.65, WATCH}, {1.1, P.SNIFF}, {1.42, P.SNIFF}, {1.55, AH1, "out"}, {1.78, AH1}, {1.88, AH2, "out"}, {2.08, AH2}, {2.2, AH3, "out"}, {2.38, AH3}, {2.44, CHOO, "out5"}, {2.62, CHOO}, {2.95, ONBACK, "out"}, {5.6, ONBACK}})
		local layer
		if t > 1.5 and t < 2.4 then local k = win(t, 1.5, 2.38) layer = {Neck = {3 * math.sin(t * 50) * k, 0, 0}, Head = {2.5 * math.sin(t * 61) * k, 0, 0}, Jaw = {-3 * math.abs(math.sin(t * 40)) * k, 0, 0}} end
		if t > 2.95 then local burst = math.max(0, math.sin(t * 2.3)) ^ 6 + (t < 3.8 and 1 - win(t, 2.95, 3.8) or 0) layer = {KneeL = {16 * math.sin(t * 24) * burst, 0, 0}, KneeR = {16 * math.sin(t * 24 + 1.6) * burst, 0, 0}, AnkleL = {12 * math.sin(t * 24 + .5) * burst, 0, 0}, AnkleR = {12 * math.sin(t * 24 + 2.1) * burst, 0, 0}, Tail3 = {0, 6 * math.sin(t * 3), 0}} end
		c:at("choo", 2.42, function()
			kick(r, "Neck", -520) c.shake = 1.2 c.hitStop = 0.05
			local mp = mouthPt(r)
			local d = (mp - headC(r)).Unit
			c:flash(mp, 0.45 * U, Color3.new(1, 1, 1), 0.2)
			for _ = 1, 14 do c:puff(mp, d * (1.2 + math.random() * 1.6) * U + V((math.random() - .5) * U, (math.random() - .5) * 0.6 * U, (math.random() - .5) * U), (0.1 + math.random() * 0.12) * U, Color3.new(1, 1, 1), 0.9, 0.8) end
			for _, pt in ipairs(F.petals) do
				c:debris(pt.p, d * (0.9 + math.random() * 1.1) * U + V((math.random() - .5) * 0.8 * U, (0.6 + math.random() * 0.8) * U, (math.random() - .5) * 0.8 * U), V(math.random() * 8, math.random() * 8, math.random() * 8), {r = 0.004 * U, grav = 0.9 * U, drag = 0.04, flutter = 2 * U, life = 3.1, bounce = 0})
				pt.gone = true
			end
		end)
		local fall = E.in2(win(t, 2.5, 2.9))
		r.rz = math.pi * fall
		r.rx = rad(-8) * math.sin(math.pi * fall)
		r.plant = t > 2.5 and "all" or "feet"
		r.pos = V(0.12 * U * math.sin(math.pi * fall), 0.25 * U * math.sin(math.pi * fall), 0.32 * U * E.out(win(t, 2.45, 2.9)))
		c:at("thud", 2.9, function() c.shake = 0.9 c:dust(c.O + r.pos, 14, 0.22 * U, 1.0 * U) c:orbitStars(r, 4, 1.4, 0.2) end)
		drive(r, A, dt, layer)
		-- flower
		local grow = math.max(0.001, E.back(win(t, 0.08, 0.45)))
		local lean = (t > 1.0 and t < 2.42) and 0.14 * win(t, 1.0, 1.4) or 0
		local droop = t > 2.6 and 0.42 * E.bounce(win(t, 2.7, 3.6)) or 0
		local cf = F.base
		local seg = F.fh / 4 * grow
		for i, s in ipairs(F.stem) do
			local bend = (lean + droop) * (i > 1 and 1 or 0.4) + (t < 2.42 and 0.04 * math.sin(t * 6 + i) * (t > 1.0 and 2 or 1) or 0)
			cf = cf * CFrame.Angles(bend, 0, 0)
			s.Size = V(0.014 * U, math.max(0.01, seg), 0.014 * U)
			s.CFrame = cf * CFrame.new(0, seg / 2, 0)
			if i == 2 then
				F.leaves[1].CFrame = cf * CFrame.new(0.05 * U, 0.01 * U, 0) * CFrame.Angles(0, 0, 0.4)
				F.leaves[2].CFrame = cf * CFrame.new(-0.05 * U, 0.01 * U, 0) * CFrame.Angles(0, 0, -0.4)
			end
			cf = cf * CFrame.new(0, seg, 0)
		end
		local head = cf * CFrame.Angles(-0.5, 0, 0)
		F.ctr.CFrame = head * CFrame.Angles(0, 0, math.pi / 2)
		F.ctr.Size = V(0.02 * U, 0.07 * U, 0.07 * U) * math.max(0.01, grow)
		for i, pt in ipairs(F.petals) do
			if not pt.gone then
				local k = math.max(0.001, E.back(win(t, 0.3 + (i - 1) * 0.02, 0.45 + (i - 1) * 0.02)))
				pt.p.Size = V(0.075, 0.008, 0.03) * U * k
				pt.p.CFrame = head * CFrame.Angles(0, pt.a, 0) * CFrame.new(0.07 * U * k, 0, 0)
			end
		end
		c:at("bloom", 0.6, function() c:sparks(head.Position, 10, 0.03 * U, Color3.new(1, 1, 1), 0.5 * U) end)
		-- butterflies
		local fp = head.Position
		local foot = segPt(r, "FootL", V(0, 0, 0))
		for _, b in ipairs(c.bf) do
			local i = b.i - 1
			local p
			local orbit = fp + V(math.cos(t * 2.2 + i * 3) * 0.3 * U, 0.15 * U + math.sin(t * 3.1 + i) * 0.08 * U, math.sin(t * 2.2 + i * 3) * 0.3 * U)
			if t < 2.42 then p = orbit
			elseif t < 3.6 then
				b.blown = (b.blown or 0) + dt
				b.from = b.from or b.pos
				p = b.from + V((i == 1 and -1 or 1) * 0.8 * U * E.out(sat(b.blown)), 0.5 * U * E.out(sat(b.blown)), 0.3 * U)
				b.away = p
			else
				local landT = i == 0 and 4.4 or 5.0
				local u = E.io(win(t, 3.6, landT))
				local tgt = i == 0 and foot + V(0, 0.03 * U, 0) or headTop(r) + V(0.25 * U, 0.35 * U + math.sin(t * 2) * 0.05 * U, 0)
				p = (b.away or b.pos):Lerp(tgt, u) + V(0, math.sin(u * math.pi) * 0.2 * U, 0)
			end
			local dv = p - b.pos
			b.pos = p
			local yaw = dv.Magnitude > 1e-4 and math.atan2(dv.X, dv.Z) or (b.yaw or 0)
			b.yaw = yaw
			local perched = i == 0 and t > 4.4
			local fl = perched and (0.25 + 0.35 * math.max(0, math.sin(t * 3))) or 0.9 * math.sin(t * 30 + i)
			local bcf = CFrame.new(p) * CFrame.Angles(0, yaw, 0)
			b.body.CFrame = bcf
			b.wl.CFrame = bcf * CFrame.Angles(0, 0, fl) * CFrame.new(0.026 * U, 0, 0)
			b.wr.CFrame = bcf * CFrame.Angles(0, 0, -fl) * CFrame.new(-0.026 * U, 0, 0)
		end
		c:camShot(t, dt, {{0, V(-0.6, 0.3, -1), 0.9, 0, 0}, {1.15, V(-0.62, 0.2, -1), 0.62, 0, 0.5}, {2.3, V(-0.62, 0.24, -1), 0.68, 0, 0.45}, {2.95, V(-0.6, 0.75, -1), 0.85, 0, 0}, {5.6, V(-0.65, 0.8, -1), 0.9, 0, 0}},
			boxUnion(worldBox(r), {mn = F.base.Position - V(0.1, 0, 0.1) * U, mx = F.base.Position + V(0.1 * U, F.fh, 0.1 * U)}), headC(r))
	end,
}

-- =====================================================================================================================
-- 8 · EXTINCT
TITLES.extinct = {
	setup = function(c)
		local r, U = c.r, c.r.U
		c.shadow = c:part(V(0.02, 2, 2), Color3.new(0, 0, 0), {shape = Enum.PartType.Cylinder, material = Enum.Material.SmoothPlastic, shadow = false})
		c.shadow.CFrame = CFrame.new(c:W(0, 0.03, 0)) * CFrame.Angles(0, 0, math.pi / 2)
		c.shadow.Transparency = 1
		c.met = c:meteor(0.55 * U)
		c.crater = {}
		local fl = c:part(V(0.04 * U, 1.9 * U, 1.9 * U), Color3.fromRGB(58, 46, 36), {shape = Enum.PartType.Cylinder, shadow = false})
		fl.CFrame = CFrame.new(c:W(0, 0.01, 0)) * CFrame.Angles(0, 0, math.pi / 2)
		table.insert(c.crater, fl)
		for i = 0, 21 do
			local a = i / 22 * math.pi * 2
			local rk = c:rock((0.06 + math.random() * 0.06) * U, i % 2 == 0 and Color3.fromRGB(90, 74, 62) or Color3.fromRGB(74, 60, 48))
			rk.CFrame = CFrame.new(c:W(math.cos(a) * 1.0 * U, 0.03 * U, math.sin(a) * 1.0 * U)) * rk.CFrame.Rotation
			table.insert(c.crater, rk)
		end
		for _, p in ipairs(c.crater) do p.Transparency = 1 end
		-- museum sign
		local post = c:part(V(0.04, 0.45, 0.04) * U, Color3.fromRGB(90, 62, 36))
		local board = c:part(V(0.62, 0.34, 0.03) * U, Color3.fromRGB(233, 220, 192))
		local sg = Instance.new("SurfaceGui")
		sg.Face = Enum.NormalId.Front
		sg.CanvasSize = Vector2.new(512, 280)
		sg.LightInfluence = 0.3
		sg.Parent = board
		local function line(txt, y, h, col)
			local l = Instance.new("TextLabel")
			l.BackgroundTransparency = 1
			l.Size = UDim2.new(1, 0, 0, h)
			l.Position = UDim2.fromOffset(0, y)
			l.Text = txt
			l.TextScaled = true
			l.Font = Enum.Font.GothamBlack
			l.TextColor3 = col
			l.Parent = sg
		end
		line("EXHIBIT " .. tostring(c.deaths or 6), 40, 36, Color3.fromRGB(58, 42, 24))
		line("EXTINCT", 92, 76, Color3.fromRGB(58, 42, 24))
		line(c.signLine or "DIED THE MOST", 178, 30, Color3.fromRGB(58, 42, 24))
		line("LATE MECHAZOIC", 220, 26, Color3.fromRGB(122, 90, 48))
		c.sign = {post = post, board = board, at = c:W(-0.85 * U, 0, -0.75 * U)}
		post.Transparency, board.Transparency = 1, 1
		-- halo for the ghost
		c.halo = {}
		for i = 0, 11 do
			local a = i / 12 * math.pi * 2
			table.insert(c.halo, {p = c:part(V(0.06, 0.02, 0.025) * U, Color3.fromRGB(255, 224, 112), {material = Enum.Material.Neon, shadow = false}), a = a})
		end
		for _, h in ipairs(c.halo) do h.p.Transparency = 1 end
		c.tint = Instance.new("ColorCorrectionEffect")
		c.tint.TintColor = Color3.new(1, 1, 1)
		c.tint.Parent = c.stage.camera
	end,
	update = function(c, t, dt)
		local r, U, gh = c.r, c.r.U, c.gh
		local LDOWN = {Neck = {-26, 0, 0}, Head = {-10, 0, 18}, ArmL = {-10, 0, 0}, ArmR = {-10, 0, 0}}
		local GAPE = addPose(P.LOOK_UP, {Jaw = {-12, 0, 0}, ArmL = {-14, 0, 0}})
		local A = pk(t, {{0, P.HAPPY}, {1.0, P.HAPPY}, {1.2, LDOWN}, {1.45, LDOWN}, {1.85, GAPE, "out"}, {2.3, GAPE}})
		local layer
		local dance = 1 - win(t, 0.85, 1.05)
		if t < 1.1 then layer = {RootJoint = {0, 10 * math.sin(t * 7) * dance, 6 * math.sin(t * 7) * dance}, Neck = {8 * math.abs(math.sin(t * 10)) * dance, 0, 0}, ArmL = {0, 0, 26 * math.sin(t * 10) * dance}, ArmR = {0, 0, -26 * math.sin(t * 10 + 1) * dance}, Tail2 = {0, 18 * math.sin(t * 7) * dance, 0}, Tail3 = {0, 24 * math.sin(t * 7 - .8) * dance, 0}, Tail4 = {0, 26 * math.sin(t * 7 - 1.6) * dance, 0}} end
		if t > 1.6 and t < 2.3 then layer = {KneeL = {3 * math.sin(t * 60), 0, 0}, KneeR = {3 * math.sin(t * 60 + 1), 0, 0}, Jaw = {-3 * math.abs(math.sin(t * 40)), 0, 0}} end
		if t < 2.3 then
			r.pos = V(0, t < 1.05 and 0.07 * U * math.abs(math.sin(t * math.pi * 3.2)) * dance or 0, 0)
			r.yaw = t < 1.05 and 0.22 * math.sin(t * math.pi * 1.6) * dance or 0
		end
		-- doom: shadow + sky tint
		local dm = E.in2(win(t, 0.8, 2.3))
		local sr = math.max(0.02, (0.1 + 1.3 * dm) * U)
		c.shadow.Size = V(0.02, sr * 2, sr * 2)
		c.shadow.Transparency = t < 2.3 and (1 - 0.55 * win(t, 0.8, 1.3)) or 1
		local sk = t < 2.3 and E.io(win(t, 0.9, 2.2)) or 1 - E.io(win(t, 2.6, 4.2))
		c.tint.TintColor = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(255, 170, 120), sk * 0.85)
		-- meteor
		local M0, M1 = c:W(0.8 * U, 7.5 * U, 2.4 * U), c:W(0, 0.6 * U, 0.1 * U)
		if t > 1.35 and t < 2.3 then c.met.show(true) c.met.part.CFrame = CFrame.new(M0:Lerp(M1, win(t, 1.35, 2.3))) * CFrame.Angles(t * 3, 0, 0) end
		c:at("impact", 2.3, function()
			c.met.show(false)
			c.hitStop = 0.14 c.shake = 1.8
			for _, p in ipairs(c.crater) do p.Transparency = 0 end
			c.shadow.Transparency = 1
			for _, p in ipairs(r.parts) do
				local col = p.part.Color
				local _, _, v = col:ToHSV()
				local stone, k = Color3.fromRGB(203, 191, 159):Lerp(Color3.new(1, 1, 1), 0.2), 0.55 + v * 0.8 -- v1.1: per channel
				p.part.Color = Color3.new(math.min(1, stone.R * k), math.min(1, stone.G * k), math.min(1, stone.B * k))
				p.part.Material = Enum.Material.Slate
			end
			for i = 1, 24 do local a = math.random() * math.pi * 2 c:puff(c:W(math.cos(a) * 0.3 * U, 0.2 * U, math.sin(a) * 0.3 * U), V(math.cos(a) * (1.5 + math.random() * 2) * U, (0.3 + math.random() * 0.9) * U, math.sin(a) * (1.5 + math.random() * 2) * U), (0.25 + math.random() * 0.2) * U, i % 3 ~= 0 and Color3.fromRGB(184, 168, 136) or Color3.fromRGB(138, 122, 104), 1.6, 0.9) end
			for _ = 1, 16 do local a = math.random() * math.pi * 2 local s = (0.04 + math.random() * 0.07) * U local rk = c:rock(s) rk.CFrame = CFrame.new(c:W(0, 0.3 * U, 0)) c:debris(rk, V(math.cos(a) * (1 + math.random() * 1.5) * U, (1.5 + math.random() * 1.5) * U, math.sin(a) * (1 + math.random() * 1.5) * U), V(math.random() * 8, math.random() * 8, math.random() * 8), {r = s, grav = 5 * U, life = 3.4, bounce = 0.35}) end
		end)
		c.ui.flash(t < 2.3 and 0 or 1 - E.in2(win(t, 2.42, 3.1)))
		local fossil = t >= 2.3
		if fossil then
			-- a fossil lying on its side in the crater (no pancake squash on a Roblox model)
			A = P.FLAT
			r.plant, r.rz, r.rx, r.yaw, r.pos = "all", math.pi / 2, 0, 0, V(0, 0, 0)
		end
		if t > 2.6 and t < 4.6 then c.smT = (c.smT or 0) - dt if c.smT <= 0 then c.smT = 0.12 c:puff(c:W((math.random() - .5) * 0.8 * U, 0.05 * U, (math.random() - .5) * 0.6 * U), V(0, 0.35 * U, 0), 0.12 * U, Color3.fromRGB(138, 128, 120), 1.4, 0.45) end end
		drive(r, A, dt, layer, fossil)
		-- sign
		local sgk = math.max(0.001, E.back(win(t, 3.2, 3.55)))
		c:at("sign", 3.25, function() c:dust(c.sign.at, 8, 0.1 * U, 0.4 * U) end)
		local scf = CFrame.new(c.sign.at) * CFrame.Angles(0, math.pi + 0.45, 0)
		c.sign.post.Transparency = t > 3.2 and 0 or 1
		c.sign.board.Transparency = t > 3.2 and 0 or 1
		c.sign.post.CFrame = scf * CFrame.new(0, 0.22 * U * sgk, 0)
		c.sign.board.CFrame = scf * CFrame.new(0, 0.5 * U * sgk, 0)
		-- ghost
		if gh then
			local on = t > 3.45
			if on and not gh.model.Parent then gh.model.Parent = c.folder end
			if on then
				local u = win(t, 3.45, 5.8)
				gh.plant = "none"
				gh.pos = V(math.sin(t * 2) * 0.06 * U, 0.05 * U + 1.25 * U * E.io(u), 0)
				gh.yaw = 0.3 * math.sin(t * 1.3) - 0.25
				gh.rx, gh.rz = 0, 0.1 * math.sin(t * 2.2)
				local GW = BOTH({Neck = {-6, 0, 0}, Head = {-4, 0, 0}, Tail1 = {16, 0, 0}, Tail2 = {10, 0, 0}, Tail3 = {8, 0, 0}, LegL = {10, 0, 0}, KneeL = {-20, 0, 0}})
				GW.Head = {-4, 0, 16}
				GW.ArmR = {-70, 0, -30 - 25 * math.sin(t * 9)}
				GW.ArmL = {-10, 0, 0}
				drive(gh, GW, dt, {Tail4 = {0, 10 * math.sin(t * 3), 0}, Tail5 = {0, 14 * math.sin(t * 3 - 1), 0}})
				local op = 0.5 * win(t, 3.45, 3.9) * (1 - win(t, 5.3, 5.8))
				for _, p in ipairs(gh.parts) do p.part.Transparency = 1 - op end
				local ht = headTop(gh) + V(0, 0.14 * U + 0.015 * U * math.sin(t * 4), 0)
				for _, h in ipairs(c.halo) do
					h.p.Transparency = 1 - math.min(1, op * 1.8)
					h.p.CFrame = CFrame.new(ht + V(math.cos(h.a) * 0.1 * U, 0, math.sin(h.a) * 0.1 * U)) * CFrame.Angles(0, -h.a + math.pi / 2, 0)
				end
			end
		end
		c:at("cut", 2.3, function() c.camSnap = true end)
		local ebox = worldBox(r)
		if gh and gh.model.Parent then ebox = boxUnion(ebox, worldBox(gh)) end
		c:camShot(t, dt, {{0, V(-0.5, 0.3, -1), 0.92, 0, 0}, {1.35, V(-0.5, 0.24, -1), 0.8, 0, 0.3}, {1.6, V(-0.42, -0.08, -1), 0.7, 0.9, 0.2, "out"}, {2.29, V(-0.42, -0.08, -1), 0.7, 0.75, 0.2}, {2.31, V(-0.4, 1.3, -0.7), 1.2, 0, 0, "lin"}, {3.4, V(-0.55, 0.8, -1), 1.25, 0, 0}, {5.8, V(-0.55, 0.45, -1), 1.15, 0, 0}},
			ebox, headC(r), (t > 1.35 and t < 2.3) and c.met.part.Position or nil, kf(t, {{1.4, 0}, {1.7, 0.12}, {2.25, 0.05}, {2.3, 0}}))
	end,
}

-- ---------- running a title ----------
function Show:play(titleId, model, mateModel, extra)
	local T = TITLES[titleId]
	if not T then return nil end
	local stage = self.stage
	local folder = Instance.new("Folder")
	folder.Name = "VictoryTitle_" .. titleId
	folder.Parent = stage.folder
	model.Parent = folder
	local r = newRig(model, stage.origin)
	if not r then folder:Destroy() return nil end
	local c = setmetatable({r = r, O = stage.origin, t = 0, fired = {}, folder = folder, stage = stage, ui = self.ui, fxList = {}, debrisList = {},
		attachments = {}, shake = 0, hitStop = 0}, Ctx)
	if extra then for k, v in pairs(extra) do c[k] = v end end
	if titleId == "carried" and mateModel then
		mateModel.Parent = folder
		c.m = newRig(mateModel, stage.origin)
	end
	if titleId == "extinct" then
		local g = model:Clone()
		g.Parent = nil
		for _, d in ipairs(g:GetDescendants()) do
			if d:IsA("BasePart") then d.Material = Enum.Material.Neon d.Color = Color3.fromRGB(234, 246, 255) d.CastShadow = false end
			if d:IsA("Decal") or d:IsA("Texture") or d:IsA("SurfaceAppearance") then d:Destroy() end
		end
		g.Parent = folder
		c.gh = newRig(g, stage.origin)
		g.Parent = nil
	end
	if titleId == "carried" and not c.m then
		-- no teammate model: a twin of the carried dino does the carrying
		local twin = model:Clone()
		twin.Parent = folder
		c.m = newRig(twin, stage.origin)
	end
	for k in pairs(camF) do camF[k] = nil end
	snapSprings(r, {})
	poseRig(r, {})
	T.setup(c)
	local runner = {}
	local len = M.LEN[titleId] or 5.5
	function runner.step(_, dt)
		c.shake *= 0.015 ^ dt
		if c.hitStop > 0 then c.hitStop -= dt c:stepFx(dt) return true end
		c.t += dt
		T.update(c, c.t, dt)
		c:stepFx(dt)
		c:stepDebris(dt)
		return c.t < len
	end
	function runner.destroy()
		self.ui.counter(nil)
		self.ui.plaster(0, 1)
		self.ui.flash(0)
		for _, a in ipairs(c.attachments) do a:Destroy() end
		for _, f in ipairs(c.fxList) do if f.obj then f.obj:Destroy() end end
		for _, d in ipairs(c.debrisList) do d.obj:Destroy() end
		if c.tint then c.tint:Destroy() end
		folder:Destroy()
		if c.gh and c.gh.model then c.gh.model:Destroy() end
	end
	runner.len = len
	return runner
end

return M
