// Render check for docs/mockups/camera_options_v0.1.html: screenshots each camera mode and each pick direction.
// Run: node tools/camera_mockup/shot.js  (needs playwright + Chromium)
const { chromium } = require("playwright");
const path = require("path");
const page0 = "file://" + path.resolve(__dirname, "../../docs/mockups/camera_options_v0.1.html");
const outDir = path.resolve(__dirname, "../../docs/mockups/camera_options_v0.1");

(async () => {
  const browser = await chromium.launch({ args: ["--use-gl=swiftshader", "--enable-webgl", "--ignore-gpu-blocklist"] });
  const errors = [];
  async function open(vp, hash) {
    const ctx = await browser.newContext({ viewport: vp, deviceScaleFactor: 1, hasTouch: vp.width < 900 });
    const p = await ctx.newPage();
    p.on("pageerror", (e) => errors.push(String(e)));
    p.on("console", (m) => { if (m.type() === "error") errors.push(m.text()); });
    await p.goto(page0 + (hash || ""));
    await p.waitForTimeout(700);
    await p.evaluate(() => { MOCK.S.paused = true; });
    return p;
  }
  const phoneShot = async (p, name) => {
    const el = await p.$("#phone");
    await el.screenshot({ path: path.join(outDir, name) });
    console.log("saved", name);
  };
  // 1) each camera mode at 1280 x 720: walk forward, then turn the camera 60 deg right while walking left
  for (const m of ["classic", "shift", "shoulder"]) {
    const p = await open({ width: 1280, height: 720 }, "#v=C&m=" + m);
    await p.evaluate(() => { MOCK.S.mode = MOCK.S.mode; MOCK.sim(0.5, { y: 1 }); MOCK.sim(0.5, { x: -1, look: 90 }); MOCK.attack(); MOCK.sim(0.15, {}); });
    await phoneShot(p, `mode_${m}.png`);
    if (m === "classic") { // staged: the dino faces the bot (screen left), the camera looks 90 deg away
      const stage = () => { const S = MOCK.S, B = MOCK.B; S.pos.set(0, 0, 8); S.bodyYaw = Math.PI / 2; S.camYaw = 0; S.camPitch = -22 * Math.PI / 180;
        B.pos.set(-16, 0, 8); B.yaw = -Math.PI / 2; B.wait = 99; B.target.copy(B.pos); MOCK.sim(0.05, {}); MOCK.slot(1, false); MOCK.slot(2, false); MOCK.sim(0.25, {}); };
      await p.evaluate(stage);
      await phoneShot(p, "mode_classic_fix_fire.png");
      await p.click('#aimSeg button[data-aim="cam"]');
      await p.evaluate(() => MOCK.sim(2.5, {}));
      await p.evaluate(stage);
      await phoneShot(p, "mode_classic_today_fire.png");
    }
    await p.context().close();
  }
  // 2) each direction at 1280 x 720 (full page) + their pickers
  for (const v of ["A", "B", "C"]) {
    const p = await open({ width: 1280, height: 720 }, "#v=" + v + "&m=shift");
    await p.evaluate(() => MOCK.sim(0.5, { y: 1 }));
    await p.screenshot({ path: path.join(outDir, `variant_${v}_page.png`), fullPage: true });
    console.log("saved", `variant_${v}_page.png`);
    if (v !== "A") {
      await p.click("#menuPill"); await p.waitForTimeout(100);
      await phoneShot(p, `variant_${v}_menucard.png`);
      await p.click("#leaveBtn"); await p.click("#setPill"); await p.waitForTimeout(100);
      await phoneShot(p, `variant_${v}_settings.png`);
    } else {
      await p.click("#camBtn"); await p.waitForTimeout(120);
      await phoneShot(p, "variant_A_button_tap.png");
      await p.click("#menuPill"); await p.waitForTimeout(100);
      await phoneShot(p, "variant_A_menucard.png");
    }
    await p.context().close();
  }
  // 3) phone viewports: portrait page + landscape full screen
  {
    const p = await open({ width: 390, height: 844 }, "#v=C&m=shift");
    await p.evaluate(() => MOCK.sim(0.5, { y: 1 }));
    await p.screenshot({ path: path.join(outDir, "phone_portrait_page.png"), fullPage: false });
    await p.screenshot({ path: path.join(outDir, "phone_portrait_full.png"), fullPage: true });
    console.log("saved phone_portrait_*");
    await p.context().close();
    const q = await open({ width: 844, height: 390 }, "#v=C&m=classic");
    await q.click("#fsBtn"); await q.waitForTimeout(150);
    await q.evaluate(() => MOCK.sim(0.6, { x: 0.7, y: 0.7 }));
    await q.screenshot({ path: path.join(outDir, "phone_landscape_fullscreen.png") });
    console.log("saved phone_landscape_fullscreen.png");
    // real touch: drag the thumbstick, then tap the camera button
    await q.touchscreen.tap(803, 74);
    await q.waitForTimeout(150);
    const st = await q.evaluate(() => MOCK.S.mode);
    console.log("after camera-button tap, mode =", st);
    await q.context().close();
  }
  await browser.close();
  console.log(errors.length ? "ERRORS:\n" + errors.join("\n") : "no page errors");
})();
