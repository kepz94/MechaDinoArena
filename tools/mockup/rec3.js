const { chromium } = require('playwright');
const pi = Number(process.argv[2]), dur = [5700, 6600, 6900][pi];
(async () => {
  const b = await chromium.launch({args:['--use-gl=swiftshader','--enable-webgl','--ignore-gpu-blocklist']});
  const ctx = await b.newContext({viewport:{width:1000,height:1400}, recordVideo:{dir:'/tmp/ic/v2d'+pi, size:{width:1000,height:1400}}});
  const p = await ctx.newPage();
  await p.route('**/*', r=>r.request().url().startsWith('file:')?r.continue():r.abort());
  await p.goto('file:///home/claude/mechadinoarena/docs/mockups/herrera_parts_b2_options.html');
  await p.addStyleTag({content:'.stage{position:fixed!important;left:16px;top:0;width:968px;z-index:9}'}); await p.evaluate(()=>window.dispatchEvent(new Event('resize')));
  for (const li of [0,1]) {
    await p.evaluate(([pi,li])=>{document.querySelectorAll('#parts .tab')[pi].click(); document.querySelectorAll('#looks .tab')[li].click(); }, [pi,li]);
    await p.waitForTimeout(dur);
  }
  await ctx.close(); await b.close();
})();
