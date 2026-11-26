import re, json, sys
ROOT='/home/claude/mechadinoarena/src/client/'
FILES=['EmoteFX','TrailFX','TenoMovesFX','TenoFX','TheriMovesFX2','TheriMovesFX','TheriFX','HerreraMovesFX','HerreraPartsFX','DiloMovesFX','DiloPartsVFX','DiloFX','TrooPartsFX','CloakFX','HookFX','MechaLegsFX']
POLL={'EmoteFX':[590],'TrailFX':[62],'CloakFX':[289],'TheriMovesFX2':[1240],'HerreraPartsFX':[269],'DiloFX':[794],'TheriFX':[723]}
out={}
for f in FILES:
    p=ROOT+f+'.client.luau'
    s=open(p).read()
    lines=s.split('\n')
    edits=[]
    # version
    vl=[i for i,l in enumerate(lines) if re.match(r'^(local )?VERSION = "(\d+)\.(\d+)"',l)]
    last=lines[vl[-1]]
    mj,mn=re.match(r'^(?:local )?VERSION = "(\d+)\.(\d+)"',last).groups()
    nv=f'{mj}.{int(mn)+1}'
    # polling first (by line number, before inserting)
    for ln in POLL.get(f,[]):
        a=lines[ln-1]; b=lines[ln]
        m=re.match(r'^(\s*)for _, (\w+) in ipairs\(Players:GetPlayers\(\)\) do$',a)
        assert m,(f,ln,a)
        old=a+'\n'+b
        new=f'{m.group(1)}for _, {m.group(2)} in ipairs(BC and BC.players(script) or Players:GetPlayers()) do -- v{nv} filler bots\n'+b
        edits.append((old,new))
    # hooks
    for i,l in enumerate(lines):
        m=re.match(r'^(\s*)Players\.PlayerAdded:Connect\((\w+)\)$',l)
        if not m: continue
        ind,fn=m.groups()
        forpat=re.compile(r'^\s*for _, (\w+) in ipairs\(Players:GetPlayers\(\)\) do '+fn+r'\(\1\) end$')
        nxt=lines[i+1] if i+1<len(lines) else ''
        prv=lines[i-1]
        if forpat.match(nxt):
            after=nxt; pair=l+'\n'+nxt; third=lines[i+2]
            if 'onBots(' in third: continue
            old=pair; new=pair+f'\n{ind}if BC then BC.watch(script, {fn}) end -- v{nv} filler bots'
        elif forpat.match(prv):
            pair=prv+'\n'+l
            if 'onBots(' in lines[i+1]: continue
            old=pair; new=pair+f'\n{ind}if BC then BC.watch(script, {fn}) end -- v{nv} filler bots'
        else:
            continue
        edits.append((old,new))
    # header + BC require before Players line
    pl='local Players = game:GetService("Players")\n'
    hdr=(f'-- v{nv} (filler bots, plan docs/plans/FILLER_BOTS_v1.0.md T3, MDA-576): bot models in Workspace.DinoIsland.Bots (practice and\n'
         f'--   filler bots) get the same effects as players through the client module BotChars 1.0 (a stand-in "player" per bot).\n'
         f'--   Switch: script attribute BotFXEnabled (default true; false = {mj}.{mn}).\n'+pl+
         'local BC = (function() -- v'+nv+' filler bots\n'
         '\tif script:GetAttribute("BotFXEnabled") == nil then script:SetAttribute("BotFXEnabled", true) end\n'
         '\tlocal ok, m = pcall(function() return require(Players.LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("BotChars", 5)) end)\n'
         '\treturn ok and m or nil\n'
         'end)()\n')
    edits.append((pl,hdr))
    edits.append((last+'\n', last+'\n'+f'VERSION = "{nv}" -- v{nv} filler bots: bots drawn too (BotChars)\n'))
    # apply with uniqueness
    for old,new in edits:
        c=s.count(old); assert c==1,(f,c,old[:80])
        s=s.replace(old,new)
    open(p,'w').write(s)
    out[f]={'v':nv,'edits':[[o,n] for o,n in edits]}
    print(f, nv, len(edits))
json.dump(out,open('/tmp/claude-0/-home-claude/7c8a0c48-2bce-579f-a00a-b76a8f986b09/scratchpad/t3/edits.json','w'))
