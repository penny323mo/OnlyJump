const assert = require('node:assert/strict');
const { webkit } = require(process.env.PLAYWRIGHT_LIB || 'playwright');

async function run() {
  const browser = await webkit.launch();
  try {
    const page = await browser.newPage({
      viewport: { width: 848, height: 392 }, deviceScaleFactor: 3, isMobile: true, hasTouch: true,
    });
    await page.addInitScript(() => {
      window.drawCount = 0;
      const gl = WebGL2RenderingContext.prototype;
      for (const name of ['drawElements', 'drawArrays', 'drawElementsInstanced', 'drawArraysInstanced']) {
        const draw = gl[name];
        gl[name] = function (...args) {
          window.drawCount++;
          return draw.apply(this, args);
        };
      }
      let ui;
      Object.defineProperty(window, 'OnlyJumpUI', {
        get: () => ui,
        set: bridge => {
          ui = bridge;
          const bind = bridge.bindGame;
          bridge.bindGame = callback => {
            window.drive = callback;
            return bind.call(bridge, callback);
          };
        },
      });
    });
    await page.goto(process.argv[2] || 'http://127.0.0.1:8137/');
    await page.getByRole('button', { name: '開始攀登', exact: true }).tap({ timeout: 90000 });
    const median = await page.evaluate(async () => {
      const frame = () => new Promise(requestAnimationFrame);
      for (let i = 0; i < 25; i++) await frame();
      const draws = [];
      for (let i = 0; i < 150; i++) {
        const direction = i % 60 < 30 ? 1 : -1;
        if (i % 30 === 0) window.drive('stick', direction * .2, 0);
        window.drive('look', direction * .002, 0);
        const before = window.drawCount;
        await frame();
        if (window.drawCount > before) draws.push(window.drawCount - before);
      }
      if (draws.length < 50) throw Error('Too few rendered frames in the rooftop pan');
      return draws.sort((a, b) => a - b)[Math.floor(draws.length / 2)];
    });
    console.log('Rooftop pan, median WebGL draws per rendered frame:', median);
    assert(median < 1100, 'Mobile rooftop shadow rendering exceeded its draw budget');
  } finally {
    await browser.close();
  }
}
run().catch(error => { console.error(error); process.exitCode = 1; });
