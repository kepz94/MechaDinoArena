# Mecha Dino Arena — Dilo Sniper Scope (mecha part) v1.0

**Ask (Kepu 2026-11-13 16:19):** "let's make it a sniper scope mecha part that sits over his shoulder and his eye. It'll just be a shot of venom separate from his 5 shots and this will be 40 damage hit scan and it'll be the classic sniper scope cross hair and animation. You tap and it goes straight into the scope then release to fire so you can just press and move your thumb around to aim then release for a hitscan shot." 16:22 "Look at how other games have designed something like this and try to create a mecha part using that info".
**Research (mockup section 0):** Overwatch Widowmaker (scope-in 0.32 s, damage charges 12 → 120 over 0.9 s, -65% move), Splatoon scoped chargers (first-person zoom while charging), Fortnite / Battlefield / Halo scope glint (targets can spot the sniper), Brawl Stars Piper (mobile drag + release; more damage at range).
**Mockup:** docs/mockups/dilo_sniper_scope_part_v0.1.html v2. **Picks:** "B · Monocle arm", numbers as the Lab card, "Yes: 15 → 40 over 1 s", "Red glint on the lens" (no slow, no range bonus), attack "Yes, back to before".

## Part `dscope` "Sniper Scope" (attack, Dilo, button)
1. Button: hold to look down the scope (lens swings over the right eye, view zooms in), let go to fire one venom shot that hits instantly: 15 damage at once up to 40 at a full 1 s charge, plus dart venom. Separate from your 5 spits. Recharges in 10 s
2. Reaches farther (150 → 200 studs)
3. Recharges in 8 s
4. A hit marks the dino for your squad for 3 s (outline through walls)

## Rules
- Press (key / touch slot): DinoDiloScopeRequest("start") — the usual part checks + cooldown; the server stamps DiloScoping / DiloScopeStartAt (everyone sees the red lens glint and the arm swing). Release: ("fire", dir) — hitscan from the lens along dir (no assist): world raycast + the nearest dino whose hitboxes come within 1.5 x scale of the line; charge = (fire - start) / 1 s on the server. Cancel (stun, menu, slot gone): ("cancel"), no recharge used.
- The recharge starts at the shot.
- Attack button: back to the spit on press (DiloAttackTest 1.6: DiloAttackTestSnipeEnabled default false).

## Tasks (MDA-513..518)
1. SkillTree 1.92 — the part + effects (dScopeMin 15, dScopeMax 40, dScopeCharge 1, dScopeRange 150 / 200, dScopeCooldown 10 / 8, dScopeMark 0 / 3).
2. SkillEffects 1.62 — DiloPartScope* attributes.
3. DiloPartsServer 1.x — "DPart_dscope" monocle arm on the Head (hinge behind the right eye, arm, lens; DPartAnim "scope") + Lab preview.
4. DiloMovesServer 1.x — the request, hitscan, damage, venom, mark, stamps.
5. MechaButtons 1.47 + AbilityBar 1.42 — hold-to-aim slot (PC key, touch slot with thumb drag), timers.
6. DiloSnipeCam 1.2 — the classic scope view (black mask, thick posts + thin centre lines + mil dots, 0.2 s lens raise, zoom FOV 30, charge arc + damage number, recoil on fire).
7. DiloMovesFX 1.x — lens swing anim, red glint while scoping (others), venom tracer + hit flash, squad mark outline.
8. DiloAttackTest 1.6 — attack back to spit on press.

## Do-not-touch
The 5-shot spit / reload, other dilo parts, bots (PracticeKit does not use dscope in v1.0), other dinos.

## Red-team (folded in)
- **Hitscan at 200 studs could feel unfair** -> the glint (picked) + the charge (quick taps 15).
- **Client trust** -> the server times the charge and checks range / line itself; the client only sends a direction.
- **Touch: the slot's pull gesture** -> the scope uses the thumb-aim lock (as the Screech), so a drag aims and never pulls.
- **Bots don't use it** -> accepted for v1.0 (noted).
