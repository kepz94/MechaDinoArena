const { chromium } = require('playwright');
(async () => {
  const b = await chromium.launch({args:['--use-gl=swiftshader','--enable-webgl','--ignore-gpu-blocklist']});
  const ctx = await b.newContext({viewport:{width:1000,height:1400}, recordVideo:{dir:'/tmp/ic/vid', size:{width:1000,height:1400}}});
  const p = await ctx.newPage();
  await p.route('**/*', r=>r.request().url().startsWith('file:')?r.continue():r.abort());
  await p.goto('file:///home/claude/mechadinoarena/docs/mockups/herrera_ironclaw_options.html');
  await p.evaluate(()=>{document.querySelectorAll('#looks .tab')[1].click(); window.scrollTo(0, document.getElementById('stage').offsetTop-10);});
  await p.waitForTimeout(5200);                       // two normal-speed passes
  await p.click('#slowBtn'); await p.waitForTimeout(7000); // one slow-mo pass
  await p.click('#slowBtn'); await p.click('#slotBtn'); await p.waitForTimeout(3000); // unslotted (today's slash)
  await ctx.close(); await b.close();
})();
