"""Kepu 2026-11-27 15:39: "I think we have to balance the Dino's first. Right now it's way too easy to get kills with the Dilo and
Troodon after you boosted them" (standing pick: recommended option).
Measured (SkillTree.effects with every stat at step 4, SkillServer 1.18 stats maxed; DinoMaxHealth Herrera 40, Troodon 55, Dilo 70,
Therizino 80, Pachy 90, Teno 150): the 2026-11-26 buffs were sized on sustained DPS, but both dinos kill from range in one volley:
* Troodon (TrooAttackServer 1.11 x5): 3 pod charges, 0.35 s apart, 108-stud lock-on (Hunter's Eyes), 10-stud splash: volley
  20 + 22 + 22 (marked x1.1) = 64 in ~1.1 s + zone 5.5/s. One volley kills a Herrera or a Troodon.
* Dilo (DiloAttackServer 1.14 / DiloMovesServer 1.16 x1.5): 5-dart mag, 0.14 s apart (Quick Draw), 77 studs/s (40 x 1.4 x 1.375),
  dart 7.5 + venom (4 + Venom Bite 5) x1.5 = 13.5/s for 2.25 s after the last dart: ~75 per mag in ~3 s (x2 under 30% HP).
* TrooAttackServer 1.12: pod / zone multiplier TrooDamageMul112 (3): volley ~38, zone 3.3/s (no one-volley kill on any dino).
* DiloAttackServer 1.15 + DiloMovesServer 1.17: Dilo multiplier DiloDamageMul115 (1.15): ~58 per mag; parts x1.15.
  Spit speed (DiloSpitSpeedMul 1.375) unchanged.
Switches TrooBalance112Enabled / DiloBalance115Enabled / DiloBalance117Enabled (default true, read per hit; false = the 11-26 buff).
Run: python3 -I tools/launch_patch.py <outdir> tools/jobs/jobs_balance2.py"""
SSS = 'game:GetService("ServerScriptService").'
JOBS = {}

T = []
a = '''script:SetAttribute("TrooAttackServerVersion", "1.11") -- v1.11 troodon pod / zone damage x5 (see the note at takeHealth)
'''
T.append((a, a + '''script:SetAttribute("TrooAttackServerVersion", "1.12") -- v1.12 balance: pod / zone x3 (see the note at takeHealth)
'''))
a = '''for k, v in pairs({TrooDamageMul = 5, TrooBuff111Enabled = true}) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, v) end
end
'''
T.append((a, a + '''-- v1.12 (Kepu 2026-11-27 15:39 "way too easy to get kills with the Dilo and Troodon after you boosted them"; every stat maxed: 3
--   charges 0.35 s apart, 108-stud lock-on, splat 4 x5 = 20 (22 marked): a 3-pod volley dealt ~64 in ~1.1 s, a one-volley kill on a
--   Herrera (40) or a Troodon (55)): while script attribute TrooBalance112Enabled ~= false (default true, read per hit) the v1.11
--   multiplier is TrooDamageMul112 (3, read per hit): splat 12 (13.2 marked), zone 3 a second, volley ~38. false = 1.11 (x5).
for k, v in pairs({TrooDamageMul112 = 3, TrooBalance112Enabled = true}) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, v) end
end
'''))
a = '''		d *= math.max(0, tonumber(script:GetAttribute("TrooDamageMul")) or 5)
'''
T.append((a, '''		if script:GetAttribute("TrooBalance112Enabled") ~= false then -- v1.12
			d *= math.max(0, tonumber(script:GetAttribute("TrooDamageMul112")) or 3)
		else
			d *= math.max(0, tonumber(script:GetAttribute("TrooDamageMul")) or 5)
		end
'''))
JOBS["TrooAttackServer"] = ("src/server/TrooAttackServer.server.luau", SSS + "TrooAttackServer", T)

D = []
a = '''script:SetAttribute("DiloAttackServerVersion", "1.14") -- v1.14 dilo buff: damage x1.5, spit 55 studs/s (see the note at takeHealth)
'''
D.append((a, a + '''script:SetAttribute("DiloAttackServerVersion", "1.15") -- v1.15 balance: damage x1.15 (see the note at takeHealth)
'''))
a = '''for k, v in pairs({DiloDamageMul = 1.5, DiloSpitSpeedMul = 1.375, DiloBuff114Enabled = true}) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, v) end
end
'''
D.append((a, a + '''-- v1.15 (Kepu 2026-11-27 15:39 "way too easy to get kills with the Dilo and Troodon after you boosted them"; every stat maxed: 5
--   darts 0.14 s apart at 77 studs/s, dart 7.5 + venom 13.5 a second for 2.25 s after the last dart: ~75 per mag in ~3 s): while
--   script attribute DiloBalance115Enabled ~= false (default true, read per hit) the v1.14 multiplier is DiloDamageMul115 (1.15,
--   read per hit): dart 5.75, venom 10.35 a second, ~58 per mag. The spit speed (DiloSpitSpeedMul) is unchanged. false = 1.14 (x1.5).
for k, v in pairs({DiloDamageMul115 = 1.15, DiloBalance115Enabled = true}) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, v) end
end
'''))
a = '''		d *= math.max(0, tonumber(script:GetAttribute("DiloDamageMul")) or 1.5)
		script:SetAttribute("DiloBuffHits", (script:GetAttribute("DiloBuffHits") or 0) + 1)
	end
	d *= armorMul(m) -- v1.8 (MDA-366): armor
'''
D.append((a, '''		if script:GetAttribute("DiloBalance115Enabled") ~= false then -- v1.15
			d *= math.max(0, tonumber(script:GetAttribute("DiloDamageMul115")) or 1.15)
		else
			d *= math.max(0, tonumber(script:GetAttribute("DiloDamageMul")) or 1.5)
		end
		script:SetAttribute("DiloBuffHits", (script:GetAttribute("DiloBuffHits") or 0) + 1)
	end
	d *= armorMul(m) -- v1.8 (MDA-366): armor
'''))
JOBS["DiloAttackServer"] = ("src/server/DiloAttackServer.server.luau", SSS + "DiloAttackServer", D)

M = []
a = '''script:SetAttribute("DiloMovesServerVersion", "1.16") -- v1.16 dilo buff: part damage x1.5 (see the note at damage())
'''
M.append((a, a + '''script:SetAttribute("DiloMovesServerVersion", "1.17") -- v1.17 balance: part damage x1.15 (see the note at damage())
'''))
a = '''for k, v in pairs({DiloDamageMul = 1.5, DiloBuff116Enabled = true}) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, v) end
end
'''
M.append((a, a + '''-- v1.17 (Kepu 2026-11-27 15:39 "way too easy to get kills with the Dilo and Troodon after you boosted them"; DiloAttackServer 1.15):
--   while script attribute DiloBalance117Enabled ~= false (default true, read per hit) the v1.16 multiplier is DiloDamageMul115
--   (1.15, read per hit). false = 1.16 (x1.5).
for k, v in pairs({DiloDamageMul115 = 1.15, DiloBalance117Enabled = true}) do
	if script:GetAttribute(k) == nil then script:SetAttribute(k, v) end
end
'''))
a = '''	if script:GetAttribute("DiloBuff116Enabled") ~= false then -- v1.16
		d *= math.max(0, tonumber(script:GetAttribute("DiloDamageMul")) or 1.5)
'''
M.append((a, '''	if script:GetAttribute("DiloBuff116Enabled") ~= false then -- v1.16
		if script:GetAttribute("DiloBalance117Enabled") ~= false then -- v1.17
			d *= math.max(0, tonumber(script:GetAttribute("DiloDamageMul115")) or 1.15)
		else
			d *= math.max(0, tonumber(script:GetAttribute("DiloDamageMul")) or 1.5)
		end
'''))
JOBS["DiloMovesServer"] = ("src/server/DiloMovesServer.server.luau", SSS + "DiloMovesServer", M)
