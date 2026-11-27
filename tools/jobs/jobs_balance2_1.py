"""Kepu 2026-11-27 15:51 "Troodon should be x2.5": TrooAttackServer 1.12.1, TrooDamageMul112 default 3 -> 2.5 (splat 10, 11 marked;
zone 2.5 a second; 3-pod volley ~32). Run: python3 -I tools/launch_patch.py <outdir> tools/jobs/jobs_balance2_1.py"""
SSS = 'game:GetService("ServerScriptService").'
JOBS = {}
T = []
a = '''script:SetAttribute("TrooAttackServerVersion", "1.12") -- v1.12 balance: pod / zone x3 (see the note at takeHealth)
'''
T.append((a, a + '''script:SetAttribute("TrooAttackServerVersion", "1.12.1") -- v1.12.1 balance: pod / zone x2.5 (Kepu 2026-11-27 15:51)
'''))
a = '''for k, v in pairs({TrooDamageMul112 = 3, TrooBalance112Enabled = true}) do
'''
T.append((a, '''-- v1.12.1 (Kepu 2026-11-27 15:51 "Troodon should be x2.5"): TrooDamageMul112 default 2.5 (was 3): splat 10 (11 marked), zone 2.5 a
--   second, 3-pod volley ~32.
for k, v in pairs({TrooDamageMul112 = 2.5, TrooBalance112Enabled = true}) do
'''))
a = '''			d *= math.max(0, tonumber(script:GetAttribute("TrooDamageMul112")) or 3)
'''
T.append((a, '''			d *= math.max(0, tonumber(script:GetAttribute("TrooDamageMul112")) or 2.5) -- v1.12.1 (1.12: 3)
'''))
JOBS["TrooAttackServer"] = ("src/server/TrooAttackServer.server.luau", SSS + "TrooAttackServer", T)
