"""Unlock-only v1.0 Tasks 3 + 5 (MDA-615, MDA-617). Run: python3 -I tools/launch_patch.py <outdir> <this file>"""
SSS = 'game:GetService("ServerScriptService").'
SPS = 'game:GetService("StarterPlayer").StarterPlayerScripts.'
JOBS = {}
K = []
a = 'M.Version = "1.4" -- v1.4 Elite combos\n'
K.append((a, a + '''M.Version = "1.5" -- v1.5 unlock-only: bot parts at level 1
-- v1.5 (unlock-only progression, MDA-615, plan docs/plans/UNLOCK_ONLY_v1.0.md Task 3, ADR-016): while ServerScriptService.SkillServer's
--   SkillUnlockOnlyEnabled ~= false and PracticeServer's script attribute PrKitUnlockOnlyEnabled ~= false (default on, read per spec)
--   prepareSpec's rolled steps go through SkillTree.unlockSteps: the bot's parts at level 1 and no stat rows, like players. false = 1.4.
'''))
a = '''	local loadout = {}
	for n = 1, ST.SLOTS or 4 do loadout[n] = false end
	for n, id in ipairs(slotted) do'''
K.append((a, '''	do -- v1.5: unlock-only (see the header)
		local ss = game:GetService("ServerScriptService"):FindFirstChild("SkillServer")
		local pr = script.Parent
		if ST.unlockSteps and ss and ss:GetAttribute("SkillUnlockOnlyEnabled") ~= false
			and not (pr and pr:GetAttribute("PrKitUnlockOnlyEnabled") == false) then
			steps = ST.unlockSteps(steps, species)
		end
	end
''' + a))
JOBS["PracticeKit"] = ("src/server/PracticeServer/PracticeKit.luau", SSS + "PracticeServer.PracticeKit", K)

G = []
a = 'VERSION = "1.11" -- v1.11 Free for All lineup (B: two rows of 4) + intro\n'
G.append((a, a + '''VERSION = "1.12" -- v1.12 unlock-only: FULL KIT · R$149
-- v1.12 (unlock-only progression, MDA-617, plan docs/plans/UNLOCK_ONLY_v1.0.md Task 5, ADR-016; Kepu pick "Dino + all its parts"): while
--   the player's SkillUnlockOnly is true and script attribute PregameFullKitTextEnabled ~= false (read per draw) the Robux button of
--   a locked dino reads "FULL KIT · R$149" (1.11: "MAXED · R$149"). Same purchase.
'''))
a = '''		maxBtn.Visible = lk == "locked"
'''
G.append((a, a + '''		maxBtn.Text = (player:GetAttribute("SkillUnlockOnly") == true and script:GetAttribute("PregameFullKitTextEnabled") ~= false)
			and "FULL KIT · R$149" or "MAXED · R$149" -- v1.12
'''))
JOBS["PregameScreen"] = ("src/client/PregameScreen.client.luau", SPS + "PregameScreen", G)

F = []
a = 'VERSION = "1.1" -- v1.1 card starts folded, toast on every server\n'
F.append((a, a + '''VERSION = "1.2" -- v1.2 unlock-only: step 2 copy
-- v1.2 (unlock-only progression, MDA-617, plan docs/plans/UNLOCK_ONLY_v1.0.md Task 5): while the player's SkillUnlockOnly is true and
--   script attribute FsUnlockCopyEnabled ~= false step 2 reads "UNLOCK A PART IN THE LAB" (1.1: "SPEND A POINT IN THE LAB"); the
--   tick (FirstStepsServer: SkillRequest "buy" + "ok") is unchanged.
'''))
a = '''	{"WIN AN ARENA MATCH", "+2 PTS"}}
'''
F.append((a, a + '''local function fsUnlockCopy() -- v1.2
	STEPS[2][1] = (player:GetAttribute("SkillUnlockOnly") == true and script:GetAttribute("FsUnlockCopyEnabled") ~= false)
		and "UNLOCK A PART IN THE LAB" or "SPEND A POINT IN THE LAB"
end
fsUnlockCopy()
player:GetAttributeChangedSignal("SkillUnlockOnly"):Connect(fsUnlockCopy)
'''))
JOBS["FirstSteps"] = ("src/client/FirstSteps.client.luau", SPS + "FirstSteps", F)

T = []
a = 'VERSION = "1.9" -- v1.9 welcome FIGHT tile: 4v4 Arena matches\n'
T.append((a, a + '''VERSION = "1.10" -- v1.10 unlock-only copy + level-1 ability cards
-- v1.10 (unlock-only progression, MDA-617, plan docs/plans/UNLOCK_ONLY_v1.0.md Task 5, ADR-016): while the player's SkillUnlockOnly is
--   true and script attribute TutUnlockCopyEnabled ~= false (read per draw): the gear sheet reads "All unlocked. They're yours." and
--   its part cards "UNLOCKED" (1.9: "All maxed." / "MAXED ★"); the showcase ability cards keep their type and line but drop the
--   stat chips (they were the step-4 numbers; parts are level 1 now). Passive cards unchanged.
'''))
a = '''		local inf = SC_INFO[id] or {"PASSIVE", "", {}}
		local ty = SC_TYPE[inf[1]] or C.muted
		local p0 = px(0.6, 5)
'''
T.append((a, '''		local inf = SC_INFO[id] or {"PASSIVE", "", {}}
		if player:GetAttribute("SkillUnlockOnly") == true and script:GetAttribute("TutUnlockCopyEnabled") ~= false then inf = {inf[1], inf[2], {}} end -- v1.10
		local ty = SC_TYPE[inf[1]] or C.muted
		local p0 = px(0.6, 5)
'''))
a = '''		for i, id in ipairs(ids) do
			local inf = SC_INFO[id] or {"PASSIVE", "", {}}
'''
T.append((a, a + '''			if player:GetAttribute("SkillUnlockOnly") == true and script:GetAttribute("TutUnlockCopyEnabled") ~= false then inf = {inf[1], inf[2], {}} end -- v1.10
'''))
a = '''		text(cg, passive and "PASSIVE ★" or "MAXED ★", "black", px(1.2, 11), passive and C.muted or C.yellow, {LayoutOrder = 2})
'''
T.append((a, '''		local unl = player:GetAttribute("SkillUnlockOnly") == true and script:GetAttribute("TutUnlockCopyEnabled") ~= false -- v1.10
		text(cg, passive and "PASSIVE ★" or (unl and "UNLOCKED" or "MAXED ★"), "black", px(1.2, 11), passive and C.muted or C.yellow, {LayoutOrder = 2})
'''))
a = '''#ids .. " MECHA PARTS", "All maxed. They're yours.")'''
T.append((a, '''#ids .. " MECHA PARTS", (player:GetAttribute("SkillUnlockOnly") == true and script:GetAttribute("TutUnlockCopyEnabled") ~= false) and "All unlocked. They're yours." or "All maxed. They're yours.") -- v1.10'''))
JOBS["Tutorial"] = ("src/client/Tutorial.client.luau", SPS + "Tutorial", T)
