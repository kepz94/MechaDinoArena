#!/usr/bin/env python3
"""pounce_latch_sim v1.1 (Mecha Dino Arena) — MDA-357 latch check, a faithful Python port of the PounceServer 1.16 latch loop
and the StaminaServer 1.6 curve it reads (plan docs/plans/BALANCE_PASS_v1.0.md; no Lua / Luau runner in the repo).

What is ported (file:line as of balance/pass1):
  StaminaServer: a pounce request (new PounceStartedAt) costs PounceStaminaCost and restarts the regen delay
    (StaminaRegenDelay 0.75 s); then "refilling" at StaminaMax / StaminaRefillTime (100 / 5 = 20 per s) until the latch;
    while PounceLatched and stamina > 0 the rate is -PounceLatchDrain. The rate change is anchored on the first
    StaminaServer Heartbeat after PounceLatched turns true (the claim is a remote event between frames).
  PounceServer claim: landing hit = round(PounceLandDamage x (1 + BladeLandBonus)); nextTick = at + interval, interval =
    PounceTickInterval x BladeTickMul.
  PounceServer Heartbeat, in its order: stamina(now) <= 0 -> release "stamina"; now - at > MAX_LATCH -> "timeout";
    now >= nextTick -> tick (nextTick += interval, PounceTickDamage), then v1.16 cap: now - at >= PounceLatchMaxTime ->
    release "time"; else (v1.16) cap reached between ticks -> "time".
Scenarios: base / Blade Claws max (BladeLandBonus 0.35, BladeTickMul 0.74), early / late claim, 30 Hz server, a 50 ms
hitch right at the 2.5 s tick, the cap switch off, and the live 1.13 numbers (drain 15, tick 4, no cap) for the before row.
v1.1 (MDA-357, Kepu 2026-11-09 raptor bots "Yes, same as players"): BOT_SCENARIOS port the BotServer 1.28 latch step (no
stamina; the Heartbeat order: end check unless a tick is due at the end (1.28) -> tick -> 1.28 end after that tick) and the
1.27 order (end checked before the tick, BotLatchTime 6.7, tick 4) for the before row; Teno Stomp cut (endAt -= amount /
PounceLatchDrain) included.
Run: python3 tools/tests/pounce_latch_sim.py      (prints one line per scenario; exit 1 and "FAIL" if an expectation misses)
"""
import sys

MAX_LATCH = 30


def simulate(drain, tick_dmg, cap, land=8, interval=0.5, blade_land=0.0, blade_mul=1.0, claim_at=0.30, fps=60.0,
             hitch_at=None, hitch_len=0.0, stam_max=100.0, cost=15.0, regen_delay=0.75, refill_time=5.0):
    dt = 1.0 / fps
    # frame times (server Heartbeats) from the pounce request at t = 0
    frames, t = [], 0.0
    while t < 12:
        t += dt
        if hitch_at is not None and t > hitch_at and t - dt <= hitch_at:
            t += hitch_len  # one long frame
        frames.append(t)
    # StaminaServer curve: value / rate / anchor
    s_val, s_rate, s_at = stam_max - cost, 0.0, 0.0
    regen_until = 0.0 + regen_delay

    def stamina(now):
        return max(0.0, min(stam_max, s_val + s_rate * (now - s_at)))
    latched, at, next_tick, ticks, dmg, reason, end = False, None, None, 0, 0, None, None
    interval = interval * max(0.2, min(1.0, blade_mul))
    for now in frames:
        # the claim (remote event) arrives before this frame's Heartbeats
        if not latched and reason is None and now >= claim_at:
            latched, at = True, claim_at
            # PounceServer claim handler runs at claim_at with the curve as it stands then
            s_cur = stamina(claim_at)
            s_val, s_rate, s_at = s_cur, s_rate, claim_at
            next_tick = at + interval
            dmg += int(land * (1 + blade_land) + 0.5)
        # StaminaServer Heartbeat (rate choice, re-anchor on change)
        s = stamina(now)
        if latched and s > 0:
            want = -drain
        elif now < regen_until:
            want = 0.0
        elif s < stam_max:
            want = stam_max / refill_time
        else:
            want = 0.0
        if latched:
            regen_until = now + regen_delay
        if want != s_rate:
            s_val, s_rate, s_at = s, want, now
        if not latched:
            continue
        # PounceServer Heartbeat
        if stamina(now) <= 0:
            reason, end = "stamina", now
        elif now - at > MAX_LATCH:
            reason, end = "timeout", now
        elif now >= next_tick:
            next_tick += interval
            ticks += 1
            dmg += tick_dmg
            if cap and now - at >= cap:
                reason, end = "time", now
        elif cap and now - at >= cap:
            reason, end = "time", now
        if reason:
            break
    return {"ticks": ticks, "damage": dmg, "length": round(end - at, 3), "reason": reason,
            "stamina_left": round(stamina(end), 1)}


def simulate_bot(end_time, tick_dmg, balance=True, land=8, interval=0.5, latch_at=0.0, fps=60.0, hitch_at=None, hitch_len=0.0,
                 stomp_at=None, stomp_amount=0.0, drain=32.0):
    """BotServer 1.28 / 1.27 latch step (Heartbeat), from latchOn at latch_at."""
    dt = 1.0 / fps
    frames, t = [], latch_at
    while t < latch_at + 12:
        t += dt
        if hitch_at is not None and t > hitch_at and t - dt <= hitch_at:
            t += hitch_len
        frames.append(t)
    next_tick, end_at, ticks, dmg = latch_at + interval, latch_at + end_time, 0, land
    stomp_seen = False
    for now in frames:
        if stomp_at is not None and not stomp_seen and now >= stomp_at:  # v1.23 drain branch (one frame, no tick)
            stomp_seen = True
            end_at -= max(0.0, stomp_amount) / max(1.0, drain)
            continue
        if now >= end_at and not (balance and next_tick <= end_at + 1e-3):
            return {"ticks": ticks, "damage": dmg, "length": round(now - latch_at, 3)}
        if now >= next_tick:
            next_tick += interval
            ticks += 1
            dmg += tick_dmg
        if balance and now >= end_at and next_tick > end_at + 1e-3:
            return {"ticks": ticks, "damage": dmg, "length": round(now - latch_at, 3)}
    return {"ticks": ticks, "damage": dmg, "length": None}


BOT_NEW = dict(end_time=2.5, tick_dmg=5)
BOT_SCENARIOS = [
    ("bot 1.28: 2.5 s, 5 per tick, 60 Hz", dict(BOT_NEW), 5, 33),
    ("bot 1.28: 30 Hz", dict(BOT_NEW, fps=30), 5, 33),
    ("bot 1.28: latch mid-frame (0.007 s)", dict(BOT_NEW, latch_at=0.007), 5, 33),
    ("bot 1.28: 50 ms hitch at the 2.5 s tick", dict(BOT_NEW, hitch_at=2.49, hitch_len=0.05), 5, 33),
    ("bot 1.28: Teno Stomp star (50 / 32 = 1.56 s cut) at 0.2 s", dict(BOT_NEW, stomp_at=0.2, stomp_amount=50), 1, 13),
    ("bot 1.27 (before / switch off): 6.7 s, 4 per tick, end first", dict(end_time=6.7, tick_dmg=4, balance=False), 13, 60),
]


# RaptorModelData 1.14 (MDA-357) and 1.13 (live)
NEW = dict(drain=32, tick_dmg=5, cap=2.5)
OLD = dict(drain=15, tick_dmg=4, cap=None)
BLADE = dict(blade_land=0.35, blade_mul=0.74)
SCENARIOS = [
    # name, kwargs, expected ticks, expected damage (target without Defense), expected reason
    ("1.14 base, claim 0.30 s, 60 Hz", dict(NEW), 5, 33, "time"),
    ("1.14 base, claim 0.10 s", dict(NEW, claim_at=0.10), 5, 33, "time"),
    ("1.14 base, late claim 0.88 s (refill began)", dict(NEW, claim_at=0.88), 5, 33, "time"),
    ("1.14 base, 30 Hz server", dict(NEW, fps=30), 5, 33, "time"),
    ("1.14 base, 50 ms hitch at the 2.5 s tick", dict(NEW, hitch_at=0.30 + 2.49, hitch_len=0.05), 5, 33, "time"),
    ("1.14 Blade Claws max", dict(NEW, **BLADE), 6, 41, "time"),
    ("1.14 Blade Claws max, late claim 0.88 s", dict(NEW, claim_at=0.88, **BLADE), 6, 41, "time"),
    ("1.14 Blade Claws max, 30 Hz", dict(NEW, fps=30, **BLADE), 6, 41, "time"),
    ("1.14 data, cap switch off (PounceLatchMaxTimeEnabled false)", dict(NEW, cap=None), 5, 33, "stamina"),
    ("1.14 data, cap off, Blade max (7th tick at 2.59 < 2.66 s)", dict(NEW, cap=None, **BLADE), 7, 46, "stamina"),
    # why not stamina alone: drain 34 (85 / 34 = exactly 2.5 s) loses the 2.5 s tick on a frame-aligned claim, and the
    # ticket's 33.5 (2.54 s) loses it to a 50 ms server hitch; 32 + the 2.5 s cap keeps it in every case above
    ("drain 34, no cap (rejected)", dict(NEW, drain=34, cap=None), 4, 28, "stamina"),
    ("drain 33.5, no cap, 50 ms hitch (rejected)", dict(NEW, drain=33.5, cap=None, hitch_at=0.30 + 2.49, hitch_len=0.05), 4, 28,
     "stamina"),
    ("1.13 live (before): drain 15, tick 4, no cap", dict(OLD), 11, 52, "stamina"),
    ("1.13 live, Blade max", dict(OLD, **BLADE), 15, 71, "stamina"),
]


def main():
    fails = 0
    for name, kw, want_ticks, want_dmg, want_reason in SCENARIOS:
        r = simulate(**kw)
        ok = r["ticks"] == want_ticks and r["damage"] == want_dmg and r["reason"] == want_reason
        fails += 0 if ok else 1
        print(("PASS" if ok else "FAIL") + f"  {name}: ticks {r['ticks']} (want {want_ticks}), damage {r['damage']} (want {want_dmg}),"
              f" length {r['length']} s, release {r['reason']} (want {want_reason}), stamina left {r['stamina_left']}")
    for name, kw, want_ticks, want_dmg in BOT_SCENARIOS:  # v1.1
        r = simulate_bot(**kw)
        ok = r["ticks"] == want_ticks and r["damage"] == want_dmg
        fails += 0 if ok else 1
        print(("PASS" if ok else "FAIL") + f"  {name}: ticks {r['ticks']} (want {want_ticks}), damage {r['damage']} (want {want_dmg}),"
              f" length {r['length']} s")
    n = len(SCENARIOS) + len(BOT_SCENARIOS)
    print(f"{'FAIL' if fails else 'PASS'} {n - fails}/{n}")
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
