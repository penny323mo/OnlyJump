// Run against an exported game served over HTTP. One slow, repeatable pan
// exposes staircase jumps along high-contrast edges that a still image hides.
const assert = require('node:assert/strict');
const { webkit } = require(process.env.PLAYWRIGHT_LIB || 'playwright');

async function measure(browser, width, height, url) {
  const page = await browser.newPage({ viewport: { width, height }, deviceScaleFactor: 1, isMobile: true, hasTouch: true });
  try {
    await page.addInitScript(() => {
      let ui;
      Object.defineProperty(window, 'OnlyJumpUI', {
        get: () => ui,
        set: bridge => {
          ui = bridge;
          const bind = bridge.bindGame;
          bridge.bindGame = callback => {
            window.pan = (x,y) => callback('look',x,y);
            return bind.call(bridge,callback);
          };
        },
      });
    });
    await page.goto(url);
    await page.locator('#start:enabled').tap({ timeout: 90000 });
    await page.addStyleTag({ content: 'header,#hud,#touch,#pickupHint{visibility:hidden!important}' });
    await page.evaluate(() => window.pan(.72,-.20));
    await page.waitForTimeout(350);

    // All six patches are static scenery. The courier, moving fan, floating
    // pickups and their shadows animate even while the camera is stationary.
    const regions = [
      [.362,.11,.427,.375], [.10,.23,.22,.46], [.26,.46,.385,.53],
      [.655,.52,.73,.565], [.31,.555,.395,.60], [.76,.24,.98,.41],
    ];
    const totals = { still: 0, moving: 0, samples: 0 };
    for (let frame = 0; frame < 18; frame++) {
      await page.evaluate(async step => {
        window.pan(step,0);
        for (let i=0; i<3; i++) await new Promise(requestAnimationFrame);
      }, frame < 2 ? 0 : .00011*368/height);
      const png = await page.screenshot({ scale: 'css' });
      const pair = await page.evaluate(async ({ image,regions }) => {
        const photo = new Image();
        photo.src = 'data:image/png;base64,' + image;
        await photo.decode();
        const canvas = window.panCanvas ??= document.createElement('canvas');
        if (canvas.width !== photo.width || canvas.height !== photo.height) {
          canvas.width = photo.width;
          canvas.height = photo.height;
        }
        const ctx = canvas.getContext('2d', { willReadFrequently: true });
        ctx.drawImage(photo,0,0);
        const current = ctx.getImageData(0,0,canvas.width,canvas.height).data;
        const previous = window.panPrevious;
        window.panPrevious = current;
        let spikes = 0, samples = 0;
        if (previous) {
          for (const [left,top,right,bottom] of regions) {
            const x1=Math.round(left*canvas.width), x2=Math.round(right*canvas.width);
            const y1=Math.round(top*canvas.height), y2=Math.round(bottom*canvas.height);
            for (let y=y1; y<y2; y++) for (let x=x1; x<x2; x++) {
              const p=(y*canvas.width+x)*4;
              const delta = Math.max(Math.abs(previous[p]-current[p]),
                Math.abs(previous[p+1]-current[p+1]), Math.abs(previous[p+2]-current[p+2]));
              if (delta >= 24) spikes++;
              samples++;
            }
          }
        }
        return { spikes,samples };
      }, { image: png.toString('base64'), regions });
      if (frame === 1) totals.still = pair.spikes;
      if (frame >= 2) {
        totals.moving += pair.spikes;
        totals.samples += pair.samples;
      }
    }
    return totals;
  } finally {
    await page.close();
  }
}

(async () => {
  const browser = await webkit.launch();
  try {
    for (const [w,h] of [[594,368],[951,585]]) {
      const { still,moving,samples } = await measure(browser,w,h,process.argv[2] || 'http://127.0.0.1:8137/');
      console.log(w + '×' + h, { still,moving,samples });
      assert.equal(still,0,'stationary samples must be free of animation');
      assert(moving/samples < .0022,'too many abrupt edge changes during the subpixel pan');
    }
  } finally {
    await browser.close();
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
