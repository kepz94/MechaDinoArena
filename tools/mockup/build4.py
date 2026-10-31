L=open('/tmp/ic/parts.js').read().split('\n')
def seg(a,b): return '\n'.join(L[a-1:b])
head=seg(1,5); engine=seg(38,144); botsfx=seg(226,253); ui=seg(413,442); frame=seg(443,len(L))
def rep(s,a,b):
    assert s.count(a)==1,(a[:60],s.count(a)); return s.replace(a,b)
engine=rep(engine,"const e = {mesh: m, anchor, off, glow: !!o.glow, extra: o.extra}; equip.push(e); return e;","const e = {mesh: m, anchor, off, glow: !!o.glow, extra: o.extra, flash: !!o.flash, base: color}; equip.push(e); return e;")
i0=ui.index("  const si = stepIdx(), hud = {"); i1=ui.index("[P.id];",i0)+len("[P.id];")
ui=ui[:i0]+'''  const si = stepIdx(), hud = {caltrops: si >= 0 ? `SPIKES <b>${si >= 1 ? 10 : 6}</b> · patch <b>${si >= 1 ? 14 : 10} studs</b> · lasts <b>${si >= 2 ? 14 : 8} s</b> · step = bleed 3/s × 3 s + slow 30% × 1 s${si >= 3 ? " · <b>hidden from enemies</b>" : ""} · 16 s cd` : "no caltrops",
    blob: si >= 0 ? `GOO <b>${si >= 1 ? 22 : 16} studs</b> wide · slow <b>40%</b> · lasts <b>${si >= 3 ? 8 : 5} s</b>${si >= 2 ? " · <b>2 blobs</b>" : ""} · range 60 studs · 18 s cd` : "no shooter",
    adren: si >= 0 ? `HEAL <b>${si >= 1 ? 34 : 25}%</b> over 3 s · RUN <b>×1.4</b> · cd <b>${si >= 2 ? 14.8 : 20} s</b> from the end${si >= 3 ? " · <b>refills slash charges</b>" : ""}` : "no injector"}[P.id];'''+ui[i1:]
ui=rep(ui,'''<div class="tile"><span class="k">ATK</span>SLASH</div>''','''<div class="tile"><span class="k">ATK</span>SLASH<span class="pips" id="pips"></span></div>''')
frame=rep(frame,"  updateQuills(dt);\n","  updateQuills(dt); updateP3(dt); const pe = $(\"pips\"); if (pe) pe.innerHTML = [0, 1].map(i => `<i class=\"${i < sc.pips ? \"on\" : \"\"}\"></i>`).join(\"\");\n")
c0=frame.index("  if (labView) { const g ="); c1=frame.index("cam.fov = 38; }",c0)+len("cam.fov = 38; }")
frame=frame[:c0]+'''  if (labView) { cam.position.set(9, 6, 13); cam.lookAt(0, 2.2, 0); cam.fov = 28; }
  else { const tx = P === "caltrops" ? (sc.patchX !== undefined ? sc.patchX + 1.5 : sc.x - 2) : P === "blob" ? -1.5 : sc.x - 1;
    const ty = P === "blob" ? 1 : 1.8; camX += (tx - camX) * Math.min(1, dt * 4 + 0.001); camY += (ty - camY) * Math.min(1, dt * 4 + 0.001);
    if (P === "blob") { cam.position.set(camX + 2, camY + 10, 25); cam.lookAt(camX, camY, 0); }
    else if (P === "caltrops") { cam.position.set(camX + 3, camY + 9, 19); cam.lookAt(camX, camY - 1, 0); }
    else { cam.position.set(camX + 5, camY + 4, 17); cam.lookAt(camX, camY, 0); }
    cam.fov = 38; }'''+frame[c1:]
frame=rep(frame,'''  const hiddenNow = P === "smoke" && sc.cloud && Math.abs(sc.x - sc.cloud.x) < 6 && !(sc.cloud.fade >= 1);
  meT.style.display = labView || P === "glider" || P === "quills" ? "none" : "block";''','''  const hiddenNow = false;
  meT.style.display = labView ? "none" : "block";''')
frame=rep(frame,'''bt.style.display = labView || !b0.g.visible || P === "plating" || P === "smoke" ? "none" : "block";''','''bt.style.display = labView || !b0.g.visible ? "none" : "block";''')
frame=rep(frame,'''  if (cd) { const total = P === "quills" ? 20 : P === "smoke" ? 18 : 0; const since = sc.cdAt !== undefined ? T - sc.cdAt : (sc.cloud ? T - sc.cloud.t : -1);''','''  if (cd) { const total = P === "caltrops" ? 16 : P === "blob" ? 18 : (stepIdx() >= 2 ? 14.8 : 20); const since = sc.cdAt !== undefined ? T - sc.cdAt : (P === "adren" && sc.done.shot ? 0 : -1);''')
frame=rep(frame,'''cd.style.height = "100%"; cdt.textContent = Math.ceil(total - since * 4) + "s";''','''cd.style.height = "100%"; cdt.textContent = sc.cdAt === undefined ? "on" : Math.max(0, Math.ceil(total - since * 4)) + "s";''')
frame=rep(frame,"  if (!labView) stepScenario(dt); else { deploy = 1; lid = 0.6; capPop = 0; }","  if (!labView) stepScenario(dt); else { deploy = 1; lid = 0.6; capPop = 0; flashParts(0); setDinoGlow(0); }")
js='\n'.join([head,open('/tmp/ic/p3_parts.js').read(),engine,botsfx,open('/tmp/ic/p3_scen.js').read(),ui,frame])
open('/tmp/ic/parts3.js','w').write(js)
h=open('/tmp/ic/parts2_head.html').read()
h=rep(h,"<title>Herrera Parts Batch 2</title>","<title>Herrera Parts Batch 3</title>")
h=rep(h,"<h1><span>Herrera</span> mecha parts · batch 2</h1>","<h1><span>Herrera</span> mecha parts · batch 3</h1>")
i=h.index('<p class="lede">'); j=h.index('</p>',i)
h=h[:i]+'<p class="lede">The real Herrera model (HerreraModelData 1.2) wearing each new part and playing its move. Pick a part, then a look, and tell me which look you want for each. Every part takes an ability slot and only shows on the dino while it\'s slotted. Steps follow the ladders you picked: Caltrops "Bleed trap", Blob Shooter "Two blobs" (lobbed arc), Adrenaline "like the raptor\'s" with ★ refilling slash charges.'+h[j:]
h=rep(h,".tile.empty { opacity: .45; }",".tile.empty { opacity: .45; }\n.pips { position: absolute; right: 5px; top: 4px; display: flex; gap: 3px; }\n.pips i { width: 8px; height: 8px; border-radius: 50%; background: #3a4556; display: block; }\n.pips i.on { background: var(--yellow); box-shadow: 0 0 6px var(--yellow); }")
three=open('/tmp/ic/node_modules/three/build/three.min.js').read()
h=h.replace('<script>/*THREE*/</script>','<script>/* three.js r128 (MIT), inlined so the page works offline / in previews */\n'+three+'\n</script>')
open('/home/claude/mechadinoarena/docs/mockups/herrera_parts_b3_options.html','w').write(h+js.replace('__DATA__',open('/tmp/ic/herrera.json').read())+"\n</script>\n</body>\n</html>\n")
print('built')
