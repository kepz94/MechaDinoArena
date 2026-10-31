const { chromium } = require('playwright');
(async () => {
  const b = await chromium.launch({args:['--use-gl=swiftshader','--enable-webgl','--ignore-gpu-blocklist']});
  const p = await b.newPage({viewport:{width:1000,height:1500}});
  const errs=[]; p.on('pageerror',e=>errs.push(String(e)));
  await p.route('**/*', r=>r.request().url().startsWith('file:')?r.continue():r.abort());
  await p.goto('file:///home/claude/mechadinoarena/docs/mockups/herrera_parts_b3_options.html');
  await p.waitForTimeout(800);
  const stage = await p.$('#stage');
  const which = process.argv[2] ? process.argv[2].split(',').map(Number) : [0,1,2];
  for (const pi of which) for (const li of [0,1]) {
    await p.evaluate(([pi,li])=>{document.querySelectorAll('#parts .tab')[pi].click(); document.querySelectorAll('#looks .tab')[li].click();}, [pi,li]);
    for (let k=0;k<6;k++){ await p.waitForTimeout([480,700,520][pi]); await stage.screenshot({path:`/tmp/ic/shots3/p${pi}${li}_${k}.png`}); }
    await p.click('#viewBtn'); await p.waitForTimeout(700); await stage.screenshot({path:`/tmp/ic/shots3/p${pi}${li}_lab.png`}); await p.click('#viewBtn');
  }
  console.log('errors:', JSON.stringify(errs));
  await b.close();
})();
