# spawnlock_generator v1.0 — writes tools/spawnlock_patch_<Name>.luau (pairs patches) for SPAWN_LOCK_v1.0 (piece 1).
# Each anchor must appear exactly once in the current repo file. Run: python3 -I tools/spawnlock_generator.py
import os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KEPU = 'Kepu 2026-11-26 "having attack buttons locked on spawn and up until the timer goes down"' 
RET = '\treturn (tonumber(char:GetAttribute("PrematchLockUntil")) or 0) > workspace:GetServerTimeNow()\n'
RET_NEW = ('\treturn (tonumber(char:GetAttribute("PrematchLockUntil")) or 0) > workspace:GetServerTimeNow()\n'
           '\t\tor (script:GetAttribute("HubSafeAttackLockEnabled") ~= false and char:GetAttribute("HubSafe") == true) -- island spawn lock\n')
TAIL = '''\
if script:GetAttribute("HubSafeAttackLockEnabled") == nil then script:SetAttribute("HubSafeAttackLockEnabled", true) end'''

def note(v, old):
    return (f'-- v{v} (island spawn lock, plan docs/plans/SPAWN_LOCK_v1.0.md Task 2; {KEPU},\n'
            f'--   picks "Island PROTECTED timer", "Attacks only"): the pre-match lock check also says locked while the character\n'
            f'--   attribute HubSafe is true (HubServer: on the islet or the 3 s PROTECTED guard after leaving it), so a press does\n'
            f'--   nothing there. Movement keeps working. Switch: script attribute HubSafeAttackLockEnabled (default true, read per\n'
            f'--   press; false = {old}).\n')

ATTACK = [
    # name, version anchor (exact line), new version line, old version
    ('BiteTest', 'char:SetAttribute("BiteTestVersion", "1.8") -- v1.8 pre-match lock', 'char:SetAttribute("BiteTestVersion", "1.9") -- v1.9 island spawn lock', '1.9', '1.8'),
    ('PounceTest', 'char:SetAttribute("PounceTestVersion", "1.9") -- v1.9 pre-match lock', 'char:SetAttribute("PounceTestVersion", "1.10") -- v1.10 island spawn lock', '1.10', '1.9'),
    ('RamTest', 'char:SetAttribute("RamTestVersion", "1.3") -- v1.3 pre-match lock', 'char:SetAttribute("RamTestVersion", "1.4") -- v1.4 island spawn lock', '1.4', '1.3'),
    ('RoarTest', 'char:SetAttribute("RoarTestVersion", "1.1") -- v1.1 pre-match lock', 'char:SetAttribute("RoarTestVersion", "1.2") -- v1.2 island spawn lock', '1.2', '1.1'),
    ('HeadbuttTest', 'VERSION = "1.4" -- v1.4 pre-match lock', 'VERSION = "1.5" -- v1.5 island spawn lock', '1.5', '1.4'),
    ('SlashTest', 'VERSION = "1.8" -- v1.8 pre-match lock', 'VERSION = "1.9" -- v1.9 island spawn lock', '1.9', '1.8'),
    ('TenoAttackTest', 'VERSION = "1.5" -- v1.5 pre-match lock', 'VERSION = "1.6" -- v1.6 island spawn lock', '1.6', '1.5'),
    ('TheriAttackTest', 'VERSION = "1.4" -- v1.4 pre-match lock', 'VERSION = "1.5" -- v1.5 island spawn lock', '1.5', '1.4'),
    ('DiloAttackTest', 'VERSION = "1.7" -- v1.7 pre-match lock', 'VERSION = "1.8" -- v1.8 island spawn lock', '1.8', '1.7'),
    ('TrooAttackTest', 'VERSION = "1.3" -- v1.3 pre-match lock', 'VERSION = "1.4" -- v1.4 island spawn lock', '1.4', '1.3'),
]

REQ = ('local __HL = (function() -- HubLockRules 1.0 (StarterPlayerScripts); missing = no island padlocks\n'
       '\tlocal ps = Players.LocalPlayer and Players.LocalPlayer:FindFirstChild("PlayerScripts")\n'
       '\tlocal m = ps and ps:WaitForChild("HubLockRules", 5)\n'
       '\tlocal ok, r = pcall(function() return m and require(m) end)\n'
       '\treturn ok and r or nil\n'
       'end)()\n'
       'local function __hubLocked() -- the island spawn lock (HubSafe) is on for this character\n'
       '\treturn __HL ~= nil and __HL.locked(char, script:GetAttribute("HubSafeAttackLockEnabled"))\n'
       'end\n')

def ui_note(v, old, what):
    return (f'-- v{v} (island spawn lock, plan docs/plans/SPAWN_LOCK_v1.0.md Task 3; {KEPU},\n'
            f'--   picks "Island PROTECTED timer", "Attacks only"): {what}\n'
            f'--   Same padlock as the Arena countdown. Switch: script attribute HubSafeAttackLockEnabled (default true, read per frame;\n'
            f'--   false = {old}). Diagnostic: character attribute {{DIAG}}.\n')

UI = {
    'ArenaTouch': [
        ('VERSION = "1.21" -- v1.21 pre-match padlocks',
         'VERSION = "1.21" -- v1.21 pre-match padlocks\nVERSION = "1.22" -- v1.22 island spawn padlocks\n'
         + ui_note('1.22', '1.21', 'while the character attribute HubSafe is true (islet + 3 s guard)\n'
                   '--   the main attack buttons (HubLockRules.ATTACK_BUTTONS: Bite, PounceMain, Ram, HeadbuttMain, SlashMain, TenoMain,\n'
                   '--   TheriMain, DiloMain, TrooMain) show the padlock; JUMP / RUN do not. The press itself is dropped by each attack script.'
                   ).replace('{DIAG}', 'ArenaTouchHubLocked (true while any button shows it)').rstrip('\n')),
        ('RunService.RenderStepped:Connect(function() -- v1.21\n\tlocal on = __prematchLocked()\n',
         REQ + 'RunService.RenderStepped:Connect(function() -- v1.21\n\tlocal on = __prematchLocked()\n'
         '\tlocal hub, hubAny = __hubLocked(), false -- v1.22\n'),
        ('\t\t\tsetLock(b, on, b:FindFirstChildOfClass("UICorner").CornerRadius)\n\t\tend\n\tend\n\tif char:GetAttribute("ArenaTouchLocked") ~= on then char:SetAttribute("ArenaTouchLocked", on) end\n',
         '\t\t\tlocal hubB = hub and __HL.isAttackButton(b.Name) -- v1.22\n'
         '\t\t\tif hubB then hubAny = true end\n'
         '\t\t\tsetLock(b, on or hubB, b:FindFirstChildOfClass("UICorner").CornerRadius)\n\t\tend\n\tend\n'
         '\tif char:GetAttribute("ArenaTouchLocked") ~= on then char:SetAttribute("ArenaTouchLocked", on) end\n'
         '\tif char:GetAttribute("ArenaTouchHubLocked") ~= hubAny then char:SetAttribute("ArenaTouchHubLocked", hubAny) end -- v1.22\n'),
    ],
    'AbilityBar': [
        ('VERSION = "1.44" -- v1.44 pre-match padlocks',
         'VERSION = "1.44" -- v1.44 pre-match padlocks\nVERSION = "1.45" -- v1.45 island spawn padlocks\n'
         + ui_note('1.45', '1.44', 'while the character attribute HubSafe is true (islet + 3 s guard)\n'
                   '--   the attack move tiles (HubLockRules.ATTACK_MOVES; not LEAP / HOP / JUMP) and the slot tiles holding an ATTACK or\n'
                   '--   CONTROL part (HubLockRules.ATTACK_PARTS) show the padlock. The press itself is dropped by the attack / mecha scripts.'
                   ).replace('{DIAG}', 'AbilityBarHubLocked (true while any tile shows it)').rstrip('\n')),
        ('table.insert(conns, RunService.RenderStepped:Connect(function() -- v1.44\n\tlocal on = __prematchLocked()\n\tfor _, e in ipairs(tiles) do setLock(e.t and e.t.f, on, UDim.new(0.22, 0)) end\n',
         REQ + 'table.insert(conns, RunService.RenderStepped:Connect(function() -- v1.44\n\tlocal on = __prematchLocked()\n'
         '\tlocal hub, hubAny = __hubLocked(), false -- v1.45\n'
         '\tfor _, e in ipairs(tiles) do\n'
         '\t\tlocal hubT = hub and ((e.kind == "move" and __HL.isAttackMove(e.id)) or (e.kind == "slot" and __HL.isAttackPart(e.part)))\n'
         '\t\tif hubT then hubAny = true end\n'
         '\t\tsetLock(e.t and e.t.f, on or hubT, UDim.new(0.22, 0))\n'
         '\tend\n'
         '\tshow("AbilityBarHubLocked", hubAny) -- v1.45\n'),
    ],
    'MechaButtons': [
        ('VERSION = "1.53" -- v1.53 tether aim stamps on PC too (MDA-552)',
         'VERSION = "1.53" -- v1.53 tether aim stamps on PC too (MDA-552)\nVERSION = "1.54" -- v1.54 island spawn lock\n'
         + ui_note('1.54', '1.53', 'while the character attribute HubSafe is true (islet + 3 s guard)\n'
                   '--   a press / aim / tactical start of a slot holding an ATTACK or CONTROL part (HubLockRules.ATTACK_PARTS) is dropped\n'
                   '--   (keys and touch), and a touch slot button shows the padlock when its tap part is one. MOVE / DEFENSE / HEAL /\n'
                   '--   STEALTH / SCOUT / SUPPORT parts keep working. A pull-down attack part sharing a button with a non-attack tap part\n'
                   '--   is blocked but that button shows no padlock (plan red-team, accepted).'
                   ).replace('{DIAG}', 'MechaButtonsHubLockedPresses (count of dropped presses)').rstrip('\n')),
        ('\tpress, aimStart, tacStart = guard(press), guard(aimStart), guard(tacStart) -- a touch gesture ends in press / aimStart\nend\n',
         '\tpress, aimStart, tacStart = guard(press), guard(aimStart), guard(tacStart) -- a touch gesture ends in press / aimStart\nend\n'
         + REQ +
         'do -- v1.54: no attack / control part on the islet or in the 3 s guard\n'
         '\tlocal function hubGuard(fn)\n'
         '\t\treturn function(n, ...)\n'
         '\t\t\tif __hubLocked() and __HL.isAttackPart(slotPart(n)) then\n'
         '\t\t\t\tchar:SetAttribute("MechaButtonsHubLockedPresses", (char:GetAttribute("MechaButtonsHubLockedPresses") or 0) + 1)\n'
         '\t\t\t\treturn\n'
         '\t\t\tend\n'
         '\t\t\treturn fn(n, ...)\n'
         '\t\tend\n'
         '\tend\n'
         '\tpress, aimStart, tacStart = hubGuard(press), hubGuard(aimStart), hubGuard(tacStart)\n'
         'end\n'),
        ('\tlocal on = __prematchLocked()\n\tfor _, sl in ipairs(slots) do setLock(sl.b, on, UDim.new(0.22, 0)) end\n',
         '\tlocal on = __prematchLocked()\n\tlocal hub = __hubLocked() -- v1.54\n'
         '\tfor n, sl in ipairs(slots) do setLock(sl.b, on or (hub and __HL.isAttackPart(slotPart(n))), UDim.new(0.22, 0)) end\n'),
    ],
}

FILLER = [
    ('VERSION = "1.1" -- v1.1 EmoteId cleared after the emote',
     'VERSION = "1.1" -- v1.1 EmoteId cleared after the emote\nVERSION = "1.2" -- v1.2 safe guard: no fights on / right off the islet\n'
     '-- v1.2 (island spawn lock, plan docs/plans/SPAWN_LOCK_v1.0.md Task 4; Kepu 2026-11-26 "the bots are just fighting right at\n'
     '--   spawn even without damage", pick "Fighting each other"): a bot inside the safe area gets safeUntil = now + FillerSafeGuard\n'
     '--   (default HubRules.GUARD, 3) s, renewed every tick while inside, so it keeps the protection for 3 s after leaving like a player.\n'
     '--   While os.clock() < safeUntil the bot is not a target for other bots and steps with no enemies (it walks, it does not\n'
     '--   swing) and its old target is dropped. Switch: script attribute FillerSafeGuardEnabled (default true, read per tick;\n'
     '--   false = 1.1). Diagnostic: script attribute FillerSafeBots (bots guarded this tick).'),
    ('\t\tlocal eligible = {}\n\t\tfor _, r in ipairs(recs) do\n\t\t\tif r.model and r.model.Parent and r.hrp and r.hrp.Parent and not r.deadAt and not r.leaving\n\t\t\t\tand not inSafe(r.hrp.Position) then\n',
     '\t\tlocal safeOn, safeNow, safeN = get("FillerSafeGuardEnabled") ~= false, os.clock(), 0 -- v1.2\n'
     '\t\tfor _, r in ipairs(recs) do\n'
     '\t\t\tif safeOn and r.hrp and r.hrp.Parent and not r.deadAt and inSafe(r.hrp.Position) then\n'
     '\t\t\t\tr.safeUntil = safeNow + (tonumber(get("FillerSafeGuard")) or HR.GUARD or 3)\n'
     '\t\t\tend\n'
     '\t\t\tif safeOn and r.safeUntil and safeNow < r.safeUntil then safeN += 1 end\n'
     '\t\tend\n'
     '\t\tset("FillerSafeBots", safeN)\n'
     '\t\tlocal eligible = {}\n\t\tfor _, r in ipairs(recs) do\n\t\t\tif r.model and r.model.Parent and r.hrp and r.hrp.Parent and not r.deadAt and not r.leaving\n\t\t\t\tand not inSafe(r.hrp.Position)\n'
     '\t\t\t\tand not (safeOn and r.safeUntil and safeNow < r.safeUntil) then -- v1.2\n'),
    ('\t\t\t\t\tif not rec.busy then\n\t\t\t\t\t\tlocal ctx = {bots = eligible, R = R, H = H,',
     '\t\t\t\t\tlocal guarded = safeOn and rec.safeUntil and os.clock() < rec.safeUntil -- v1.2\n'
     '\t\t\t\t\tif guarded then rec.target = nil end\n'
     '\t\t\t\t\tif not rec.busy then\n\t\t\t\t\t\tlocal ctx = {bots = guarded and {} or eligible, R = R, H = H,'),
]

TAIL_LUAU = '''}
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
'''

def write(name, path, pairs, title):
    src = open(os.path.join(ROOT, path), encoding='utf-8').read()
    for o, n in pairs:
        assert not o.startswith('\n') and not n.startswith('\n'), (name, 'leading newline')
        assert src.count(o) == 1, (name, src.count(o), o[:70])
        assert ']=====]' not in o + n
    out = [f'-- spawnlock_patch_{name} ({title}): SPAWN_LOCK_v1.0.\nlocal PAIRS = {{\n']
    for o, n in pairs:
        out.append('{[=====[' + o + ']=====], [=====[' + n + ']=====]},\n')
    p = os.path.join(ROOT, 'tools', f'spawnlock_patch_{name}.luau')
    open(p, 'w', encoding='utf-8').write(''.join(out) + TAIL_LUAU)
    print('wrote', p)

for name, anchor, newline, v, old in ATTACK:
    write(name, f'src/character/{name}.client.luau',
          [(anchor, anchor + '\n' + newline + '\n' + note(v, old) + TAIL), (RET, RET_NEW)], f'{name} {v}')
for name, pairs in UI.items():
    write(name, f'src/character/{name}.client.luau', pairs, name)
write('FillerServer', 'src/server/FillerServer.server.luau', FILLER, 'FillerServer 1.2')
