const assert = require('node:assert/strict');
const { webkit } = require(process.env.PLAYWRIGHT_LIB || 'playwright');

const url = process.argv[2] || 'http://127.0.0.1:8137/';
const mobile = { isMobile: true, hasTouch: true, deviceScaleFactor: 3, viewport: { width: 393, height: 727 } };

async function ready(page) {
  await page.getByRole('button', { name: '開始攀登', exact: true }).waitFor({ timeout: 60000 });
}

async function checkGameFrame(page) {
  const png = await page.screenshot({ scale: 'css', style: 'body > :not(canvas) { visibility: hidden !important; }' });
  const colors = await page.evaluate(async data => {
    const image = new Image();
    image.src = 'data:image/png;base64,' + data;
    await image.decode();
    const sample = document.createElement('canvas');
    sample.width = 64;
    sample.height = 64;
    const ctx = sample.getContext('2d');
    ctx.drawImage(image, 0, 0, 64, 64);
    const rgba = ctx.getImageData(0, 0, 64, 64).data;
    const palette = new Set();
    for (let i = 0; i < rgba.length; i += 4) {
      palette.add((rgba[i] >> 4) << 8 | (rgba[i + 1] >> 4) << 4 | rgba[i + 2] >> 4);
    }
    return palette.size;
  }, png.toString('base64'));
  assert(colors > 40, 'Expected a rendered 3D scene, saw ' + colors + ' colours');
  return colors;
}

async function play(page) {
  await ready(page);
  const introColors = await checkGameFrame(page);
  await page.locator('#start').tap();
  await page.locator('#jump').tap();
  await page.waitForFunction(() => Number(document.querySelector('#height').textContent) > .4, null, { timeout: 4000 });
  const colors = await checkGameFrame(page);
  console.log('Rendered colours in menu/game', introColors, colors);
}

async function blockedStorage(browser) {
  const context = await browser.newContext(mobile);
  try {
    const other = await context.newPage();
    await other.goto(new URL('credits.txt', url).href);
    await other.evaluate(() => new Promise((resolve, reject) => {
      const request = indexedDB.open('/userfs', 1);
      request.onupgradeneeded = () => request.result.createObjectStore('old-save').put('keep', 'record');
      request.onsuccess = () => { window.heldSave = request.result; resolve(); };
      request.onerror = () => reject(request.error);
    }));
    const page = await context.newPage();
    await page.goto(url);
    await ready(page);
    assert.match(await page.locator('#error').innerText(), /暫存/);
    await play(page);
    await other.close();
    await page.reload();
    await ready(page);
    assert(await page.locator('#error').isHidden());
    const preserved = await page.evaluate(() => new Promise((resolve, reject) => {
      const request = indexedDB.open('/userfs');
      request.onsuccess = () => {
        const db = request.result;
        const read = db.transaction('old-save').objectStore('old-save').get('record');
        read.onsuccess = () => { db.close(); resolve(read.result); };
        read.onerror = () => reject(read.error);
      };
      request.onerror = () => reject(request.error);
    }));
    assert.equal(preserved, 'keep');
    console.log('PASS locked save never blocks play and old data survives reopening');
  } finally {
    await context.close();
  }
}

async function graphicsRecovery(browser) {
  const page = await browser.newPage(mobile);
  try {
    await page.goto(url);
    await play(page);
    const size = () => page.evaluate(() => {
      const c = document.querySelector('#canvas');
      return [c.width, c.height, c.clientWidth, c.clientHeight];
    });
    const [width, height, cssWidth, cssHeight] = await size();
    assert(width * height < 1200000);
    assert(Math.abs(width / height - cssWidth / cssHeight) < .01);
    await page.evaluate(() => document.querySelector('#canvas').getContext('webgl2').getExtension('WEBGL_lose_context').loseContext());
    const recovery = page.getByRole('dialog', { name: '3D 畫面中斷' });
    await recovery.getByRole('button', { name: '以輕量模式重開' }).tap({ timeout: 3000 });
    await page.waitForURL(address => address.searchParams.get('lite') === '1');
    await play(page);
    const [liteWidth, liteHeight] = await size();
    assert(liteWidth * liteHeight < width * height);
    await page.setViewportSize({ width: 727, height: 393 });
    await page.waitForFunction(() => document.querySelector('#canvas').width > document.querySelector('#canvas').height);
    const [rotatedWidth, rotatedHeight, rotatedCssWidth, rotatedCssHeight] = await size();
    assert(Math.abs(rotatedWidth / rotatedHeight - rotatedCssWidth / rotatedCssHeight) < .01);
    console.log('PASS context loss -> lightweight reload -> visible jump; portrait / lightweight / rotated buffers',
      [width, height], [liteWidth, liteHeight], [rotatedWidth, rotatedHeight]);
  } finally {
    await page.close();
  }
}

async function independentCamera(browser) {
  const page = await browser.newPage(mobile);
  try {
    await page.addInitScript(() => {
      let bridge;
      window.actions = [];
      Object.defineProperty(window, 'OnlyJumpUI', {
        get: () => bridge,
        set: value => {
          bridge = value;
          const bind = value.bindGame;
          value.bindGame = callback => bind((...args) => {
            window.actions.push(args);
            return callback(...args);
          });
        },
      });
    });
    await page.goto(url);
    await ready(page);
    await page.locator('#start').tap();
    assert.equal(await page.getByRole('button', { name: /追蹤鏡頭/ }).count(), 0);
    const pad = await page.locator('#pad').boundingBox();
    const x = pad.x + pad.width / 2, y = pad.y + pad.height / 2;
    assert(await page.evaluate(([x,y]) => document.elementFromPoint(x,y).closest('#padZone') !== null,[x,y]));
    // Every contact sample is within 19 CSS pixels of the original centre.
    await page.mouse.move(x,y);
    await page.mouse.down();
    await page.mouse.move(x + 19,y,{steps:4});
    await page.mouse.up();
    let actions = await page.evaluate(() => window.actions.filter(([name]) => name==='look' || name==='stick'));
    assert(actions.some(([name,dx]) => name==='stick' && dx>.2 && dx<1));
    assert(actions.every(([name]) => name==='stick'));
    assert.deepEqual(actions.at(-1), ['stick',0,0]);
    const lookX = 295, lookY = 360;
    assert(await page.evaluate(([x,y]) => document.elementFromPoint(x,y).id === 'look',[lookX,lookY]));
    await page.mouse.move(lookX,lookY);
    await page.mouse.down();
    await page.mouse.move(lookX+22,lookY,{steps:3});
    await page.mouse.up();
    actions = await page.evaluate(() => window.actions);
    assert(actions.some(([name,dx]) => name==='look' && dx>0));
    console.log('PASS 19px drag inside the lower-left circle only steers, right-side drag orbits');
  } finally {
    await page.close();
  }
}

(async () => {
  const browser = await webkit.launch();
  try {
    await independentCamera(browser);
    await graphicsRecovery(browser);
    await blockedStorage(browser);
  } finally {
    await browser.close();
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
