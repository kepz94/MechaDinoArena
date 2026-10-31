const { chromium } = require('playwright');
const fs = require('fs');
(async () => {
  const b = await chromium.launch({args:['--use-gl=swiftshader','--enable-webgl','--ignore-gpu-blocklist']});
  const p = await b.newPage({viewport:{width:1100,height:1500}});
  const errs=[]; p.on('pageerror',e=>errs.push(String(e))); p.on('console',m=>{if(m.type()==='error')errs.push(m.text())});
  await p.route('**/*', r=>r.request().url().startsWith('file:')?r.continue():r.abort());
  await p.route('**/fonts.googleapis.com/**', r=>r.abort());
  await p.goto('file:///home/claude/mechadinoarena/docs/mockups/herrera_ironclaw_options.html');
  await p.waitForTimeout(1500);
  const stage = await p.$('#stage');
  for (const [li,name] of [[0,'A'],[1,'B'],[2,'C']]) {
    await p.evaluate(i=>document.querySelectorAll('#looks .tab')[i].click(), li);
    await p.click('#viewBtn'); await p.waitForTimeout(900);
    await stage.screenshot({path:`/tmp/ic/shots/lab_${name}.png`});
    await p.click('#viewBtn');
    await p.evaluate(()=>document.getElementById('slowBtn').click());
    await p.click('#slashBtn');
    for (let k=0;k<6;k++){ await p.waitForTimeout(260); await stage.screenshot({path:`/tmp/ic/shots/run_${name}_${k}.png`}); }
    await p.evaluate(()=>document.getElementById('slowBtn').click());
  }
  await p.screenshot({path:'/tmp/ic/shots/page.png', fullPage:true});
  console.log('errors:', JSON.stringify(errs));
  await b.close();
})();
