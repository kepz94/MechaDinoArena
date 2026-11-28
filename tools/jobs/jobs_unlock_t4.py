"""Unlock-only v1.0 Task 4 (MDA-616): Lab 2.5 layout C. Run: python3 -I tools/launch_patch.py <outdir> <this file>"""
SPS = 'game:GetService("StarterPlayer").StarterPlayerScripts.'
JOBS = {}
P = []
a = 'VERSION = "2.4" -- v2.4 island DINO hub\n'
P.append((a, a + '''VERSION = "2.5" -- v2.5 unlock-only layout (C)
-- v2.5 (unlock-only progression, MDA-616, plan docs/plans/UNLOCK_ONLY_v1.0.md Task 4, ADR-016; Kepu 2026-11-27 pick "C: A + FULL KIT
--   button" on docs/mockups/unlock_only_v0.1/unlock_only_v0.1_sheet.jpg; "Build" 19:43). While the player's SkillUnlockOnly is true
--   (SkillServer 1.19) and script attribute LabUnlockLayoutEnabled ~= false (read per draw):
--   * part cards: no pips; a locked part (SkillPath 0) gets a dark lock badge over its art, state "LOCKED" (muted) and the yellow
--     button "UNLOCK · <SkillPartPrice> PTS" (SkillLeft >= price) or "NEED <price> PTS"; an owned part: state "UNLOCKED" (green) /
--     "ON <key>" and the 2.0 EQUIP / PUT ON / TAKE OFF buttons; a tap on UNLOCK sends SkillRequest("buy", id), toast "<NAME>
--     UNLOCKED".
--   * detail sheet (INFO): only the level-1 text (no I-IV list, no badge); its button = the card's (UNLOCK / NEED / UNLOCKED).
--   * top bar: the MASTERY chip reads "KIT <SkillKitOwned>/<SkillKitTotal>"; the stage tag "YOUR KIT" (2.4: "ALL UPGRADES"); a new
--     button left of CHANGE DINO, "FULL KIT · R$149" ("R$149 KIT" when the Lab box is under 900 px wide), green outline, 44 tall
--     (closeS), shown while the dino's kit is not complete and the dino is neither the free dino (FreeDino) nor in MaxedDinos;
--     tap -> DinoUnlockRequest:InvokeServer("robux", dino) (DinoUnlockServer: owned, not maxed -> Roblox's window; the receipt grants
--     the dino maxed = every part). Switch LabFullKitEnabled (true, per draw). Toasts "ALREADY YOURS" / "TRY AGAIN".
--   New code lives in the script-global table L5 (the main chunk is at the 200-local limit). false = 2.4.
'''))
a = 'local remote = ReplicatedStorage:WaitForChild("SkillRequest", 30)\n'
P.append((a, a + '''L5 = {} -- v2.5: unlock-only layout helpers (script-global)
function L5.on() return player:GetAttribute("SkillUnlockOnly") == true and script:GetAttribute("LabUnlockLayoutEnabled") ~= false end
'''))
a = 'L4.chgL.AutomaticSize = Enum.AutomaticSize.X\n'
P.append((a, a + '''L5.kitB = button(barRight, "FullKit", PANEL) -- v2.5: FULL KIT · R$149
L5.kitB.LayoutOrder = -1
L5.kitB.AutomaticSize = Enum.AutomaticSize.X
L5.kitB.Visible = false
corner(L5.kitB)
stroke(L5.kitB, Color3.fromRGB(70, 224, 138), 0.1, 2)
L5.kitPad = pad(L5.kitB, 12)
L5.kitL = label(L5.kitB, "T", Enum.Font.FredokaOne, 14, WHITE, "FULL KIT · R$149")
L5.kitL.AutomaticSize = Enum.AutomaticSize.X
L5.kitB.Activated:Connect(function() if L5.kitPress then L5.kitPress() end end)
'''))
a = '\tfor i = 1, 4 do\n\t\tlocal row = frame(stepsBox, "Step" .. i)\n'
P.append((a, '\tfor i = 1, (L5.on() and 1 or 4) do -- v2.5: level 1 only in unlock-only\n\t\tlocal row = frame(stepsBox, "Step" .. i)\n'))
a = '\t\t\ttx.TextColor3 = WHITE\n\t\tend\n\tend\n\t-- buttons\n'
P.append((a, '''			tx.TextColor3 = WHITE
		end
		if L5.on() then -- v2.5: the level-1 text, no badge
			bd.Visible = false
			tx.Position = UDim2.fromOffset(0, 0)
			tx.Size = UDim2.new(1, 0, 0, math.max(3 * S.ch, 18))
			tx.TextColor3 = WHITE
		end
	end
	-- buttons
'''))
a = '\tlocal eqBtn = nil\n\tlocal eqIdx = slotIndex(id)\n'
P.append((a, '\tif L5.on() then ok, buyText = L2.buyState(id) end -- v2.5\n' + a))
a = '\t\tshowToast(("%s %s"):format(pathName(p), ROMAN[n + 1]))\n'
P.append((a, '\t\tshowToast(L5.on() and (string.upper(pathName(p)) .. " UNLOCKED") or ("%s %s"):format(pathName(p), ROMAN[n + 1])) -- v2.5\n'))
a = "function L2.buyState(id) -- the BUY / UPGRADE label (the detail's 1.4 rules)\n"
P.append((a, a + '''	if L5.on() then -- v2.5: unlock-only
		if stepsOf(id) >= 1 then return false, "UNLOCKED" end
		local price = tonumber(player:GetAttribute("SkillPartPrice")) or 10
		if (tonumber(player:GetAttribute("SkillLeft")) or 0) >= price then return true, ("UNLOCK · %d PTS"):format(price) end
		return false, ("NEED %d PTS"):format(price)
	end
'''))
a = '\t\tshowToast(("%s %s"):format(string.upper(pathName(p)), ROMAN[stepsOf(id) + 1] or ""))\n'
P.append((a, '\t\tshowToast(L5.on() and (string.upper(pathName(p)) .. " UNLOCKED") or ("%s %s"):format(string.upper(pathName(p)), ROMAN[stepsOf(id) + 1] or "")) -- v2.5\n'))
a = '\t\telse stText, stCol = "NOT ON A SLOT", MUTED end\n'
P.append((a, a + '''		if L5.on() then -- v2.5
			pp.Visible = false
			if not p.soon then
				if n == 0 then stText, stCol = "LOCKED", MUTED
				elseif eq then stText, stCol = "ON " .. (SLOT_KEYS[eq] or tostring(eq)), ORANGE
				else stText, stCol = "UNLOCKED", GREEN end
			end
		end
'''))
a = '\t\tsl.Position = UDim2.fromOffset(x0 + pw + 0.8 * ch, my)\n\t\tsl.Size = UDim2.fromOffset(math.max(tw - pw - 0.8 * ch, 10), L.metaH)\n'
P.append((a, a + '\t\tif L5.on() then sl.Position, sl.Size = UDim2.fromOffset(x0, my), UDim2.fromOffset(tw, L.metaH) end -- v2.5: no pips\n'))
a = '\t\t\tq.TextTransparency = 0.3\n\t\tend\n\t\tlocal nm = label(b, "Name", Enum.Font.FredokaOne, L.text.card, WHITE, pathName(p))\n'
P.append((a, '''			q.TextTransparency = 0.3
		end
		if L5.on() and n == 0 and not p.soon then -- v2.5: locked
			local lk = label(art, "Lock", Enum.Font.GothamBlack, math.max(artH * 0.3, 14), WHITE, "🔒")
			lk.Size = UDim2.fromScale(1, 1)
			lk.BackgroundTransparency = 0.35
			lk.BackgroundColor3 = Color3.fromRGB(8, 10, 14)
			lk.ZIndex = 20
		end
		local nm = label(b, "Name", Enum.Font.FredokaOne, L.text.card, WHITE, pathName(p))
'''))
a = 'local function drawBar()\n'
P.append((a, '''function L5.kitPress() -- v2.5: FULL KIT · R$149 (see the header)
	local d = species()
	local r = ReplicatedStorage:FindFirstChild("DinoUnlockRequest")
	if not r then showToast("TRY AGAIN") return end
	press("fullKit:" .. tostring(d))
	local ok, res = pcall(function() return r:InvokeServer("robux", d) end)
	if not (ok and res == "prompted") then showToast(ok and res == "owned" and "ALREADY YOURS" or "TRY AGAIN") end
end
''' + a))
a = '\tmasL.Text = ("MASTERY %d/%d"):format(mastered, ST.MASTERY_MAX or 3)\n'
P.append((a, a + '''	do -- v2.5
		local own, total = tonumber(player:GetAttribute("SkillKitOwned")) or 0, tonumber(player:GetAttribute("SkillKitTotal")) or 0
		if L5.on() then masL.Text = ("KIT %d/%d"):format(own, total) end
		local mx = player:GetAttribute("MaxedDinos")
		local given = player:GetAttribute("FreeDino") == dino or (type(mx) == "string" and table.find(string.split(mx, ","), dino) ~= nil)
		L5.kitB.Visible = L5.on() and script:GetAttribute("LabFullKitEnabled") ~= false and not given and total > 0 and own < total
		L5.kitL.Text = (S.bw and S.bw < 900) and "R$149 KIT" or "FULL KIT · R$149"
	end
'''))
a = 'stageTag.Text = tab == "skins" and "PREVIEW" or "ALL UPGRADES"'
P.append((a, 'stageTag.Text = tab == "skins" and "PREVIEW" or (L5.on() and "YOUR KIT" or "ALL UPGRADES") -- v2.5'))
a = '\tL4.chgL.Size = UDim2.fromOffset(0, S.closeS)\n'
P.append((a, a + '''	L5.kitB.Size = UDim2.fromOffset(0, S.closeS) -- v2.5
	L5.kitPad.PaddingLeft, L5.kitPad.PaddingRight = UDim.new(0, 1.6 * ch), UDim.new(0, 1.6 * ch)
	L5.kitL.TextSize = math.max(2.0 * ch, 12)
	L5.kitL.Size = UDim2.fromOffset(0, S.closeS)
'''))
JOBS["Lab"] = ("src/client/Lab.client.luau", SPS + "Lab", P)
