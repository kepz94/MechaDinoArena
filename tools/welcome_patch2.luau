-- welcome_patch2 (WELCOME_MOVES v1.0 Task 5, MDA-597): Tutorial 1.7 JUMP parts in step 6 (real check, JUMP coach, SKIP).
local PAIRS = {
{[=====[--     is cut to one row (NEXT is never pushed out).]=====], [=====[--     is cut to one row (NEXT is never pushed out).
--   * JUMP parts in step 6 (MDA-597, TutorialJumpPartsEnabled): for a slot (1..TutNeed) holding a TutorialRules 1.3 JUMP part
--     (Glider Wings, Mecha Legs, Hydraulic Leap; their slot buttons do nothing, MechaButtons), a slot press no longer counts
--     (tip for 2 s: "That button does nothing for <part>. It works on JUMP."); the part counts when its stamp changes on the
--     character (GlideStartedAt / JumpDoubleAt / JumpStartedAt with TenoLeapOnJump true) -> "used", n. Coach: touch = ring +
--     finger + callout left of ArenaTouch's JUMP button ("Leap"; callout only if it is missing or hidden), PC = the callout
--     with the key words; tip = the part's line. After TutJumpPartSkipAfter (20) s on the same part: " Or tap SKIP." and a
--     SKIP button inside the objective box -> "used", n (WM.markUsed). Other parts: as 1.6.]=====]},
{[=====[		objective(6, tip)
]=====], [=====[		local J = nextI and script:GetAttribute("TutorialJumpPartsEnabled") ~= false and R.jumpPart(slotOf(nextI)) or nil -- v1.7
		local skipNow = false
		if J then
			local key = nextI .. ":" .. slotOf(nextI)
			if WM.jpN ~= key then WM.jpN, WM.jpSince = key, os.clock() end
			local after = math.max(0, tonumber(script:GetAttribute("TutJumpPartSkipAfter")) or 20)
			local waited, tapAgo = os.clock() - WM.jpSince, os.clock() - WM.jpTapAt
			skipNow = waited >= after
			tip = tapAgo < 2 and ("That button does nothing for " .. J.small .. ". It works on JUMP.") or J.tip
			if skipNow then tip ..= " Or tap SKIP." end
			WM.jpTok += 1
			local tok = WM.jpTok
			local wake = math.min(skipNow and math.huge or after - waited, tapAgo < 2 and 2 - tapAgo or math.huge)
			if wake < math.huge then task.delay(wake + 0.05, function() if WM.jpTok == tok and step() == 6 then render() end end) end
		else
			WM.jpN = nil
		end
		local obj = objective(6, tip)
		if J and skipNow then
			local k = nextI
			local sk = cta(obj:FindFirstChild("Body") or obj, "SKIP", function() if WM.markUsed then WM.markUsed(k) end end, {LayoutOrder = 6})
			sk.Name = "SkipPart"
		end
]=====]},
{[=====[			if isTouch() then
				local pull = nextI > 2]=====], [=====[			if J then -- v1.7: a JUMP part: the JUMP button and the real input
				local at = player.PlayerGui:FindFirstChild("ArenaTouch")
				local leap = at and at:FindFirstChild("Leap", true)
				if isTouch() and leap and leap:IsA("GuiObject") and leap.Visible then
					pointAt(leap, true, string.find(J.big, "HOLD") and "hold" or "tap", J.big, J.small, "left")
				else
					pcCallout(isTouch() and J.big or J.pcBig, J.small)
				end
			elseif isTouch() then
				local pull = nextI > 2]=====]},
{[=====[		if n and n <= need() and id ~= "empty" then
			localUsed[n] = true
			send("used", n)
		end
	end)
]=====], [=====[		if n and n <= need() and id ~= "empty" then
			if script:GetAttribute("TutorialJumpPartsEnabled") ~= false and R.jumpPart(id) then -- v1.7: that button does nothing
				WM.jpTapAt = os.clock()
				queue()
				return
			end
			localUsed[n] = true
			send("used", n)
		end
	end)
	c.AttributeChanged:Connect(function(name) -- v1.7: a JUMP part counts when its move really happens (TutorialRules 1.3)
		if step() ~= 6 or script:GetAttribute("TutorialJumpPartsEnabled") == false then return end
		for k = 1, math.min(4, need()) do
			local J = R.jumpPart(slotOf(k))
			if J and not localUsed[k] and R.jumpPartEvent(J, name, J.needAttr and c:GetAttribute(J.needAttr) or nil) then
				localUsed[k] = true
				send("used", k)
			end
		end
	end)
]=====]},
{[=====[local localUsed = {}
]=====], [=====[local localUsed = {}
WM.markUsed = function(n) localUsed[n] = true send("used", n) end -- v1.7: SKIP on a JUMP part
]=====]},
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
