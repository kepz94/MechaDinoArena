L=open('/tmp/ic/parts.js').read().split('\n')
def seg(a,b): return '\n'.join(L[a-1:b])
head=seg(1,5); engine=seg(38,144); botsfx=seg(226,253); ui=seg(413,442); frame=seg(443,len(L))
def rep(s,a,b):
    assert s.count(a)==1,(a[:60],s.count(a)); return s.replace(a,b)
engine=rep(engine,"const e = {mesh: m, anchor, off, glow: !!o.glow, extra: o.extra}; equip.push(e); return e;","const e = {mesh: m, anchor, off, glow: !!o.glow, extra: o.extra, flash: !!o.flash, base: color}; equip.push(e); return e;")
botsfx=rep(botsfx,"const bots = [makeBot(), makeBot()];","const bots = [makeBot(), makeBot(), makeBot()];")
i0=ui.index("  const si = stepIdx(), hud = {"); i1=ui.index("[P.id];",i0)+len("[P.id];")
ui=ui[:i0]+'''  const si = stepIdx(), hud = {siphon: si >= 0 ? `HEAL <b>${si >= 1 ? 1.5 : 1} HP/s</b> per bleeding enemy · <b>${si >= 2 ? 25 : 15} studs</b>${si >= 3 ? " · bleed kill <b>+25%</b>" : ""}` : "no siphon",
    strobe: si >= 0 ? `FLASH <b>${si >= 2 ? "90° · 25" : "60° · 20"} studs</b> · daze <b>${si >= 1 ? 1.5 : 1} s</b>${si >= 3 ? " · <b>+20%</b> dmg on dazed" : ""} · 16 s cd` : "no strobe",
    breaker: si >= 0 ? `BREAK stun${si >= 1 ? " · <b>push 10 studs</b>" : ""} · cd <b>${si >= 2 ? 14 : 20} s</b>${si >= 3 ? " · <b>1 s immune</b>" : ""}` : "no breaker"}[P.id];'''+ui[i1:]
frame=rep(frame,"  updateQuills(dt);\n","  updateQuills(dt); updateBeads(dt);\n")
c0=frame.index("  if (labView) { const g ="); c1=frame.index("cam.fov = 38; }",c0)+len("cam.fov = 38; }")
frame=frame[:c0]+'''  if (labView) { cam.position.set(PARTS[part].id === "breaker" && look === 1 ? 5 : 9, 6, 13); cam.lookAt(0, 2.2, 0); cam.fov = 28; }
  else { const tx = P === "siphon" ? -3 : P === "strobe" ? Math.max(sc.x + 3, -1) : 2;
    const ty = 1.8; camX += (tx - camX) * Math.min(1, dt * 4 + 0.001); camY += (ty - camY) * Math.min(1, dt * 4 + 0.001);
    const dist = P === "siphon" ? 19 : P === "strobe" ? 20 : 16;
    if (P === "siphon") { cam.position.set(camX + 7, camY + 4, 15); cam.lookAt(camX, camY, -1.5); } else { cam.position.set(camX + 5, camY + 5, dist); cam.lookAt(camX, camY, 0); }
    cam.fov = 38; }'''+frame[c1:]
frame=rep(frame,'''  const hiddenNow = P === "smoke" && sc.cloud && Math.abs(sc.x - sc.cloud.x) < 6 && !(sc.cloud.fade >= 1);
  meT.style.display = labView || P === "glider" || P === "quills" ? "none" : "block";''','''  const hiddenNow = false;
  meT.style.display = labView || P === "strobe" ? "none" : "block";''')
frame=rep(frame,'''bt.style.display = labView || !b0.g.visible || P === "plating" || P === "smoke" ? "none" : "block";''','''bt.style.display = labView || !b0.g.visible || P !== "strobe" ? "none" : "block";''')
frame=rep(frame,'''  if (cd) { const total = P === "quills" ? 20 : P === "smoke" ? 18 : 0; const since = sc.cdAt !== undefined ? T - sc.cdAt : (sc.cloud ? T - sc.cloud.t : -1);''','''  if (cd) { const total = P === "strobe" ? 16 : P === "breaker" ? (stepIdx() >= 2 ? 14 : 20) : 0; const since = P === "strobe" ? (sc.done.flash ? T - sc.t0 : -1) : (sc.done.brk ? T - 1.0 : -1);''')
frame=rep(frame,"  if (!labView) stepScenario(dt); else { deploy = 1; lid = 0.6; capPop = 0; }","  if (!labView) stepScenario(dt); else { deploy = 1; lid = 0.6; capPop = 0; flashParts(0); }")
js='\n'.join([head,open('/tmp/ic/p2_parts.js').read(),engine,open('/tmp/ic/p2_look.js').read(),botsfx,open('/tmp/ic/p2_scen.js').read(),ui,frame])
open('/tmp/ic/parts2.js','w').write(js)
h=open('/tmp/ic/parts2_head.html').read()
three=open('/tmp/ic/node_modules/three/build/three.min.js').read()
h=h.replace('<script>/*THREE*/</script>','<script>/* three.js r128 (MIT), inlined so the page works offline / in previews */\n'+three+'\n</script>')
open('/home/claude/mechadinoarena/docs/mockups/herrera_parts_b2_options.html','w').write(h+js.replace('__DATA__',open('/tmp/ic/herrera.json').read())+"\n</script>\n</body>\n</html>\n")
print('built')
