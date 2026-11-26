-- lab21_patch (Lab 2.0 -> 2.1, Looks Lab v1.0; Kepu 2026-11-26 01:06, picks on docs/mockups/looks_lab_v0.1: wheel "A", all three
-- tabs, Robux tile selects then BUY in the detail, no wedge upload). Pairs for src/client/Lab.client.luau.
local PAIRS = {
{[=====[VERSION = "2.0" -- v2.0 Lab Revamp v1.0: slots first
]=====], [=====[VERSION = "2.0" -- v2.0 Lab Revamp v1.0: slots first
VERSION = "2.1" -- v2.1 Looks Lab v1.0: owned first, locked tiles say why, emote wheel on the left
-- v2.1 (Looks Lab v1.0; Kepu 2026-11-26 01:06 "Instead of having a second row of tabs for owned/earned/robux and all, just have the
--   owned skins show up first, the rest locked and showing why it's locked, if it's for Robux have it say buy, if it's for a
--   challenge have it show the challenge when you click on it and the progression" / "It makes more sense to just click on the
--   wheel and replace from my list. Also make the wheel more properly spaced out and even sections"; picks on mockup
--   docs/mockups/looks_lab_v0.1: "A: Big wheel on the left", "SKINS, EMOTES and TRAILS", "Select it, BUY in the detail",
--   "No upload: lit label + lines"). Code in the script-global table L3.
--   * SKINS / EMOTES / TRAILS (switch LabLooksSortEnabled, default true, read per draw; false = 2.0 with the filter row): no
--     ALL / OWNED / EARN / ROBUX row (filter "all"); tiles in groups (LayoutOrder group x 1000 + catalog order): equipped / on the
--     wheel / on, owned, challenge, Robux. Locked tiles get the lock (as skins) and say why: Robux -> a yellow pill "BUY ·
--     R$<price>"; challenge -> the progress bar plus "<have> / <need>". The detail shows the challenge and its progress (as
--     before) or a BUY · R$<price> button (skins: "GET" became "BUY").
--   * EMOTES wheel (switch LabWheelLeftEnabled, default true, read per draw; false = 2.0 wheel in the detail): on the EMOTES tab
--     the left column shows a big wheel instead of the stage: a round base, 8 even sections split by 8 lines from a hub, each
--     section a button WSlot_<n> (>= 44 px) with its number and the emote's word ("+ EMPTY" when empty). Tap a section -> it
--     lights (yellow fill, its 2 lines yellow), the hub reads "SLOT n / PICK AN EMOTE", the head line "PICK AN EMOTE FOR SLOT
--     n" + CANCEL, owned tiles say "TAP TO PUT ON n"; tap an owned emote -> DinoEmoteRequest("equip", n, id) (as the 2.0 slot
--     tap). Tap the section again or CANCEL -> off. The detail drops the old ring and PUT ON WHEEL: "On your wheel, slot n." /
--     "Owned. Tap a wheel slot on the left, then this emote."; BUY / LOCKED stay.
--   Diagnostics (player): LabWheelSlot (0 / 1..8).
]=====]},
{[=====[if script:GetAttribute("LabSlotNameW") == nil then script:SetAttribute("LabSlotNameW", 90) end -- v2.0: slot width that shows part names
]=====], [=====[if script:GetAttribute("LabSlotNameW") == nil then script:SetAttribute("LabSlotNameW", 90) end -- v2.0: slot width that shows part names
L3 = {wslot = nil} -- v2.1: Looks Lab state + helpers (script-global)
if script:GetAttribute("LabLooksSortEnabled") == nil then script:SetAttribute("LabLooksSortEnabled", true) end -- v2.1
if script:GetAttribute("LabWheelLeftEnabled") == nil then script:SetAttribute("LabWheelLeftEnabled", true) end -- v2.1
]=====]},
{[=====[			b.Activated:Connect(function()
				press("emote:" .. id)
				EMO.sel = id]=====], [=====[			b.Activated:Connect(function()
				if L3.pick and L3.pick(id) then return end -- v2.1: a wheel section is selected -> put this emote there
				press("emote:" .. id)
				EMO.sel = id]=====]},
{[=====[			b = detailButton(detail, "GET · R$" .. tostring(uniPrice(sk) or "?"), YELLOW, DARK_TEXT, true, 8)]=====],
 [=====[			b = detailButton(detail, (L3.sortOn and L3.sortOn() and "BUY · R$" or "GET · R$") .. tostring(uniPrice(sk) or "?"), YELLOW, DARK_TEXT, true, 8) -- v2.1: BUY]=====]},
{[=====[		L2.cancel.Activated:Connect(function() press("cancelSlot") slotSel = nil redraw() end)]=====],
 [=====[		L2.cancel.Activated:Connect(function() press("cancelSlot") slotSel = nil L3.wslot = nil redraw() end) -- v2.1: + the wheel section]=====]},
{[=====[	L2.layoutTips()
end]=====], [=====[	L2.layoutTips()
	if L3.layout then L3.layout() end -- v2.1
end]=====]},
{[=====[function L2.after() -- after every draw: tips, emote wheel size, text floor, diagnostics
	if not mode or not S.L then return end]=====], [=====[function L2.after() -- after every draw: tips, emote wheel size, text floor, diagnostics
	if not mode or not S.L then return end
	if L3.after then L3.after() end -- v2.1: tile order / locked labels / emote detail]=====]},
{[=====[local function rebuildUniStage(sp) -- v1.18: another dino on the SKINS stage]=====], [=====[-- ---------- v2.1: Looks Lab v1.0 (see the header) ----------
function L3.on() return script:GetAttribute("LabWheelLeftEnabled") ~= false and EMO.on() end
function L3.sortOn() return script:GetAttribute("LabLooksSortEnabled") ~= false end

function L3.buildWheel()
	if L3.wheelF then return end
	local f = frame(mid, "EmoteWheelEdit")
	f.ZIndex = 2
	local base = frame(f, "Base", Color3.fromRGB(15, 20, 29), 0)
	base.Size = UDim2.fromScale(1, 1)
	corner(base, UDim.new(0.5, 0))
	stroke(base, Color3.fromRGB(42, 51, 68), 0, 2)
	L3.spokes, L3.slots = {}, {}
	for i = 1, 8 do
		local sp = frame(f, "Spoke" .. i, Color3.fromRGB(58, 69, 86), 0)
		sp.AnchorPoint = Vector2.new(0.5, 0.5)
		sp.ZIndex = 3
		L3.spokes[i] = sp
	end
	for i = 1, 8 do
		local b = button(f, "WSlot_" .. i, Color3.fromRGB(58, 47, 10), 1)
		b.AnchorPoint = Vector2.new(0.5, 0.5)
		b.ZIndex = 4
		local c = corner(b)
		local st = stroke(b, YELLOW, 1, 2)
		local n = label(b, "N", Enum.Font.GothamBlack, 11, MUTED, tostring(i))
		n.ZIndex = 5
		local w = label(b, "W", Enum.Font.GothamBlack, 12, WHITE, "")
		w.ZIndex = 5
		w.TextScaled = true
		w.TextWrapped = true
		local fit = Instance.new("UITextSizeConstraint")
		fit.MinTextSize, fit.MaxTextSize = 8, 14
		fit.Parent = w
		L3.slots[i] = {b = b, c = c, st = st, n = n, w = w, fit = fit}
		b.Activated:Connect(function()
			press("wheelSlot:" .. i)
			L3.wslot = L3.wslot ~= i and i or nil
			redraw()
		end)
	end
	local hub = frame(f, "Hub", Color3.fromRGB(11, 14, 20), 0)
	hub.AnchorPoint, hub.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
	hub.ZIndex = 4
	corner(hub, UDim.new(0.5, 0))
	stroke(hub, Color3.fromRGB(42, 51, 68), 0, 2)
	local hl = label(hub, "T", Enum.Font.GothamBlack, 11, MUTED, "")
	hl.Size = UDim2.fromScale(1, 1)
	hl.TextWrapped = true
	hl.ZIndex = 5
	L3.hub, L3.hubL = hub, hl
	L3.wheelF = f
end

function L3.drawWheel(d)
	local R = d / 2
	local r0 = R * 0.3
	local len = R - r0
	local EC = EMO.cat()
	local wheel = EMO.wheel()
	local ch = S.ch
	L3.hub.Size = UDim2.fromOffset(2 * r0, 2 * r0)
	L3.hubL.TextSize = S.L.text.small
	L3.hubL.Text = L3.wslot and ("SLOT %d\nPICK AN EMOTE"):format(L3.wslot) or "YOUR\nWHEEL"
	L3.hubL.TextColor3 = L3.wslot and YELLOW or MUTED
	for i = 1, 8 do -- line i runs between section i-1 and section i
		local a = math.rad((i - 1) * 45 - 112.5)
		local m = r0 + len / 2
		local sp = L3.spokes[i]
		sp.Position = UDim2.fromOffset(R + m * math.cos(a), R + m * math.sin(a))
		sp.Size = UDim2.fromOffset(len, 2)
		sp.Rotation = math.deg(a)
		local lit = L3.wslot ~= nil and (L3.wslot == i or L3.wslot % 8 + 1 == i)
		sp.BackgroundColor3 = lit and YELLOW or Color3.fromRGB(58, 69, 86)
		sp.ZIndex = lit and 6 or 3
	end
	local rr = r0 + len * 0.55
	local bs = math.max(S.L.minTap, math.min(R * 0.42, 2 * rr * math.sin(math.rad(22.5)) - 6))
	local tS = S.L.text.tag
	for i, s in ipairs(L3.slots) do
		local a = math.rad((i - 1) * 45 - 90)
		s.b.Position = UDim2.fromOffset(R + rr * math.cos(a), R + rr * math.sin(a))
		s.b.Size = UDim2.fromOffset(bs, bs)
		s.c.CornerRadius = UDim.new(0, 0.8 * ch)
		local on = L3.wslot == i
		s.b.BackgroundTransparency = on and 0 or 1
		s.st.Transparency = on and 0 or 1
		local sid = wheel[i]
		local se = sid and EC.get(sid)
		s.n.Text = tostring(i)
		s.n.TextSize = tS
		s.n.TextColor3 = on and YELLOW or MUTED
		s.n.Position, s.n.Size = UDim2.fromOffset(0, 0.08 * bs), UDim2.new(1, 0, 0, tS * 1.1)
		s.w.Text = se and se.word or "+ EMPTY"
		s.w.TextColor3 = on and YELLOW or (se and WHITE or MUTED)
		s.w.Position = UDim2.fromOffset(0.05 * bs, 0.1 * bs + tS * 1.15)
		s.w.Size = UDim2.fromOffset(0.9 * bs, math.max(bs * 0.82 - tS * 1.15, 8))
		s.fit.MaxTextSize = S.L.text.btn
	end
end

function L3.layout()
	local L, ch = S.L, S.ch
	local looks = tab == "skins" and uniTab()
	local wheelView = looks and EMO.view() and L3.on()
	if not (looks and EMO.view()) then L3.wslot = nil end
	player:SetAttribute("LabWheelSlot", L3.wslot or 0)
	stage.Visible = true
	if L3.wheelF then L3.wheelF.Visible = false end
	if not looks then return end
	local y = L.sheet.y
	if L3.sortOn() then
		uniFilter = "all"
		if uniFilterRow then uniFilterRow.Visible = false end
		if wheelView then -- the head line takes the filter row's place
			local sel = L3.wslot ~= nil
			local hh = sel and L.minTap or math.max(L.text.hdr + 1.2 * ch, 22)
			local cancelW = sel and math.max(10 * ch, 96) or 0
			L2.head.Visible, L2.cancel.Visible = true, sel
			L2.head.TextSize = L.text.hdr
			L2.head.Position, L2.head.Size = UDim2.fromOffset(0, y), UDim2.fromOffset(L.right.w - cancelW - (sel and ch or 0), hh)
			L2.cancel.Position, L2.cancel.Size = UDim2.fromOffset(L.right.w - cancelW, y), UDim2.fromOffset(cancelW, hh)
			L2.head.Text = sel and ("PICK AN EMOTE FOR SLOT %d"):format(L3.wslot) or "TAP A WHEEL SLOT, THEN AN EMOTE"
			L2.head.TextColor3 = sel and YELLOW or MUTED
			y += hh + 0.6 * ch
		end
		local h = L.body.h - y
		grid.Position, grid.Size = UDim2.fromOffset(0, y), UDim2.fromOffset(L.looksGrid.w, h)
		right.Position = UDim2.fromOffset(L.right.x + L.looksDetail.x, y)
		right.Size = UDim2.fromOffset(L.looksDetail.w, h)
		detail.Size = UDim2.fromOffset(L.looksDetail.w, h)
	end
	if wheelView then
		L3.buildWheel()
		stage.Visible = false
		local lw, bh = L.left.w, L.body.h
		local d = math.min(lw, bh) - 2 * ch
		L3.wheelF.Visible = true
		L3.wheelF.Position, L3.wheelF.Size = UDim2.fromOffset((lw - d) / 2, (bh - d) / 2), UDim2.fromOffset(d, d)
		L3.drawWheel(d)
	end
end

function L3.pick(id) -- an emote tile tapped while a wheel section is selected
	if not (L3.on() and L3.wslot and EMO.view()) then return false end
	local st = EMO.state(id)
	if st ~= "own" and st ~= "wheel" then return false end
	local n = L3.wslot
	press("emoteSlot:" .. n .. ":" .. id)
	local r = ReplicatedStorage:FindFirstChild("DinoEmoteRequest")
	if r then r:FireServer("equip", n, id) end
	EMO.sel = id
	L3.wslot = nil
	redraw()
	return true
end

function L3.after()
	if not (tab == "skins" and uniTab()) then return end
	local view = TRL.view() and "trail" or (EMO.view() and "emote" or "skin")
	local US, EC, TC = uniMod(), EMO.cat(), TRL.cat()
	local sp = uniStageSpecies()
	local tS = S.L.text.tag
	if L3.sortOn() then
		for _, b in ipairs(grid:GetChildren()) do
			if b:IsA("GuiButton") then
				local kind, id = b.Name:match("^(%a+)_(.+)$")
				local st, price, have, need
				if kind == "Skin" and US and US.SKINS[id] then
					local sk = US.SKINS[id]
					st = uniState(sk, sp)
					price = uniPrice(sk)
					if st == "earn" then have, need = US.progress(id, uniStats()) end
					if st == "eq" then st = "on" end
				elseif kind == "Emote" and EC and EC.get(id) then
					st = EMO.state(id)
					price = EC.get(id).unlock.price
					if st == "earn" then have, need = EMO.progress(id) end
					if st == "wheel" then st = "on" end
				elseif kind == "Trail" and TC then
					st = TRL.state(id)
					local t = id ~= "none" and TC.get(id) or nil
					price = t and t.unlock.price
					if st == "earn" then have, need = TRL.progress(id) end
				end
				if st then
					local g = (st == "on" and 0) or (st == "own" and 1) or (st == "earn" and 2) or 3
					b.LayoutOrder = g * 1000 + (b.LayoutOrder % 1000)
					if (st == "buy" or st == "earn") and not b:FindFirstChild("Lock") then -- emotes / trails get the skins' lock
						local cw3 = S.uniCellW or S.cellW
						local p1 = 0.8 * S.ch
						local lk = label(b, "Lock", Enum.Font.GothamBlack, math.max(1.6 * S.ch, 9), WHITE, "🔒")
						lk.AnchorPoint = Vector2.new(1, 0)
						lk.Position = UDim2.fromOffset(cw3 - p1 - 2, p1 + 1)
						lk.Size = UDim2.fromOffset(math.max(1.8 * S.ch, 10), math.max(1.8 * S.ch, 10))
						lk.ZIndex = 3
					end
					local sl = b:FindFirstChild("State")
					if st == "buy" and sl then
						sl.Text = "BUY · R$" .. tostring(price or "?")
						sl.TextColor3 = DARK_TEXT
						sl.BackgroundTransparency = 0
						sl.BackgroundColor3 = YELLOW
						sl.TextXAlignment = Enum.TextXAlignment.Center
						sl.AutomaticSize = Enum.AutomaticSize.X
						sl.Size = UDim2.fromOffset(0, sl.Size.Y.Offset)
						if not sl:FindFirstChildOfClass("UICorner") then
							corner(sl, UDim.new(0, 0.5 * S.ch))
							pad(sl, 0.5 * S.ch)
						end
					elseif st == "earn" and have and need and not b:FindFirstChild("Prog") then
						local bar = b:FindFirstChild("Bar")
						if bar then
							local w = bar.Size.X.Offset
							bar.Size = UDim2.fromOffset(w * 0.55, bar.Size.Y.Offset)
							local pl = label(b, "Prog", Enum.Font.GothamBlack, tS, YELLOW, ("%d / %d"):format(have, need))
							pl.TextXAlignment = Enum.TextXAlignment.Right
							pl.Position = UDim2.fromOffset(bar.Position.X.Offset + w * 0.58, bar.Position.Y.Offset - tS * 0.45)
							pl.Size = UDim2.fromOffset(w * 0.42, tS * 1.2)
						end
					elseif view == "emote" and L3.on() and L3.wslot and sl and (st == "own" or st == "on") then
						sl.Text = "TAP TO PUT ON " .. L3.wslot
						sl.TextColor3 = YELLOW
					end
				end
			end
		end
	end
	if view == "emote" and L3.on() and not detail:FindFirstChild("WheelLine") then -- the wheel is on the left now
		for _, n in ipairs({"WheelTitle", "Wheel"}) do
			local x = detail:FindFirstChild(n)
			if x then x:Destroy() end
		end
		local id = EMO.sel
		local st = id and EMO.state(id)
		if st == "own" or st == "wheel" then
			for _, c in ipairs(detail:GetChildren()) do
				if c:IsA("GuiButton") and c.Name == "Btn" then c:Destroy() end
			end
			local w = table.find(EMO.wheel(), id)
			local ln = label(detail, "WheelLine", Enum.Font.GothamBlack, S.stepS, w and ORANGE or GREY,
				w and ("On your wheel, slot %d."):format(w) or "Owned. Tap a wheel slot on the left, then this emote.")
			ln.TextXAlignment = Enum.TextXAlignment.Left
			ln.TextWrapped = true
			ln.AutomaticSize = Enum.AutomaticSize.Y
			ln.Size = UDim2.new(1, 0, 0, 0)
			ln.LayoutOrder = 7
		end
	end
end

local function rebuildUniStage(sp) -- v1.18: another dino on the SKINS stage]=====]},
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
