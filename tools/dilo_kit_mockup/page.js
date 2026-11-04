const { chromium } = require('playwright');
(async () => {
  const [W, H, out, scheme] = process.argv.slice(2);
  const b = await chromium.launch();
  const p = await b.newPage({viewport: {width: +W, height: +H}, colorScheme: scheme || 'dark'});
  const errs = [];
  p.on('console', m => { if (m.type() === 'error' && !/ERR_TUNNEL/.test(m.text())) errs.push(m.text()); });
  p.on('pageerror', e => errs.push('pageerror: ' + e.message));
  await p.goto('file:///home/claude/mechadinoarena/docs/mockups/dilo_kit_options_v0.1.html');
  await p.waitForFunction(() => window.__ready);
  await p.evaluate(() => { window.__setup('A', 'J1', 'attack', 'hero'); let t = 0; while (t < 0.62) { window.__step(1/60); t += 1/60; } });
  await p.screenshot({path: out, fullPage: true});
  const sw = await p.evaluate(() => [document.documentElement.scrollWidth, window.innerWidth, document.querySelector('#cv').clientWidth, document.querySelector('#cv').clientHeight]);
  console.log(out, 'scrollWidth/inner/canvas', sw.join('/'), errs.length ? 'ERRORS ' + errs.join(' | ') : 'no errors');
  await b.close();
})();
