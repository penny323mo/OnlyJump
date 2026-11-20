const assert = require('node:assert/strict');
const { webkit } = require(process.env.PLAYWRIGHT_LIB || 'playwright');

const url = process.argv[2] || 'http://127.0.0.1:8137/';
const mobile = { isMobile: true, hasTouch: true, viewport: { width: 594, height: 368 } };

async function play(page) {
  await page.getByRole('button', { name: '開始攀登', exact: true }).tap({ timeout: 90000 });
  await page.locator('#jump').tap();
  await page.waitForFunction(() => Number(document.querySelector('#height').textContent) > .4);
  await page.locator('#pause').tap();
  assert.match(await page.locator('#report').innerText(), /1 次起跳 · 0 次跌落/);
}

async function retryDownloads(browser) {
  const context = await browser.newContext(mobile);
  try {
    const page = await context.newPage();
    const errors = [];
    page.on('pageerror', error => errors.push(error.message));
    for (const file of ['**/controls-*.js', '**/index-*.js', '**/*.wasm', '**/*.pck']) {
      await page.route(file, route => route.abort('failed'));
      await page.goto(url);
      const retry = page.getByRole('button', { name: '重新載入', exact: true });
      await retry.waitFor({ timeout: 15000 });
      assert(await retry.isEnabled());
      assert(await page.locator('#error').isVisible());
      assert(await page.locator('#loadPercent').isHidden());
      assert(await page.locator('#pickCast').isDisabled());
      if (file === '**/*.wasm') {
        await context.setOffline(true);
        const offline = page.getByRole('button', { name: '等候連線', exact: true });
        await offline.waitFor();
        assert(await offline.isDisabled());
        await context.setOffline(false);
        await retry.waitFor();
      }
      await page.unroute(file);
      await retry.tap();
      await play(page);
      const large = page.getByRole('radio', { name: '加大', exact: true });
      if (file === '**/controls-*.js') await large.check();
      else assert(await large.isChecked());
      console.log('PASS one-tap recovery and first jump after', file);
    }
    assert.deepEqual(errors, []);
  } finally {
    await context.close();
  }
}

async function stalledDownload(browser, disconnect) {
  const page = await browser.newPage(mobile);
  let resume;
  const hold = new Promise(resolve => { resume = resolve; });
  try {
    await page.route('**/*.pck', async route => {
      await hold;
      await route.continue();
    });
    await page.goto(url);
    if (disconnect) {
      await page.waitForFunction(() => parseInt(document.querySelector('#loadPercent').textContent) > 0);
      await page.context().setOffline(true);
      await page.getByRole('button', { name: '等候連線', exact: true }).waitFor({ timeout: 3000 });
      await page.context().setOffline(false);
    } else {
      await page.locator('#start[data-state="stalled"]').waitFor({ timeout: 45000 });
    }
    await page.getByRole('button', { name: '重新載入', exact: true }).waitFor();
    assert(await page.getByRole('button', { name: '重新載入', exact: true }).isEnabled());
    resume();
    await play(page);
    assert.equal(await page.evaluate(() => performance.getEntriesByType('navigation')[0].type), 'navigate');
    assert(await page.locator('#error').isHidden());
    console.log('PASS download finishes without a reload after', disconnect ? 'a lost connection' : 'a long stall');
  } finally {
    resume();
    await page.close();
  }
}

async function unsupportedBrowser(browser) {
  const page = await browser.newPage(mobile);
  try {
    await page.addInitScript(() => {
      const getContext = HTMLCanvasElement.prototype.getContext;
      HTMLCanvasElement.prototype.getContext = function (type, ...args) {
        return type === 'webgl2' ? null : getContext.call(this, type, ...args);
      };
    });
    await page.goto(url);
    const unsupported = page.getByRole('button', { name: '未能啟動', exact: true });
    await unsupported.waitFor();
    assert(await unsupported.isDisabled());
    assert.match(await page.locator('#error').innerText(), /WebGL/);
    console.log('PASS unsupported browser shows a compatibility message');
  } finally {
    await page.close();
  }
}

async function brokenBody(browser, extension, streaming = true) {
  const page = await browser.newPage(mobile);
  try {
    const errors = [];
    page.on('pageerror', error => errors.push(error.message));
    await page.addInitScript(({ extension, streaming }) => {
      if (!streaming) WebAssembly.instantiateStreaming = undefined;
      const fetchFile = window.fetch.bind(window);
      window.fetch = async (...args) => {
        const response = await fetchFile(...args);
        if (!new URL(response.url).pathname.endsWith(extension) || sessionStorage.cutBody) return response;
        sessionStorage.cutBody = extension;
        const reader = response.body.getReader();
        let sent = false;
        return new Response(new ReadableStream({
          async pull(controller) {
            if (sent) {
              controller.error(new TypeError('Interrupted download'));
              await reader.cancel();
              return;
            }
            const chunk = await reader.read();
            controller.enqueue(chunk.value);
            sent = true;
          },
        }), { headers: response.headers });
      };
    }, { extension, streaming });
    await page.goto(url);
    if (extension === '.wasm') {
      await page.locator('#start[data-state="retry"]').tap({ timeout: 12000 });
    }
    await play(page);
    assert.equal(await page.evaluate(() => sessionStorage.cutBody), extension);
    assert.deepEqual(errors, []);
    console.log('PASS interrupted response body', extension, streaming ? 'streaming' : 'buffered');
  } finally {
    await page.close();
  }
}

(async () => {
  const browser = await webkit.launch();
  try {
    await Promise.all([retryDownloads(browser), stalledDownload(browser, false), stalledDownload(browser, true), unsupportedBrowser(browser)]);
    await brokenBody(browser, '.pck');
    await brokenBody(browser, '.wasm');
    await brokenBody(browser, '.wasm', false);
  } finally {
    await browser.close();
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
