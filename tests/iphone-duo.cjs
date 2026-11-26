const assert = require('node:assert/strict');
const { webkit } = require(process.env.PLAYWRIGHT_LIB || 'playwright');

const poses = require('./duo-viewports.cjs');

async function exercise(page, url) {
  // Read the game clock for the run-up, so slow rendering doesn't shorten it.
  await page.addInitScript(() => {
    let bridge;
    Object.defineProperty(window, 'OnlyJumpUI', {
      get: () => bridge,
      set: value => {
        bridge = value;
        const update = bridge.update;
        bridge.update = (...args) => {
          window.runSeconds = args[6];
          return update.apply(bridge,args);
        };
      },
    });
  });
  await page.goto(url);
  const button = id => page.locator('#' + id);
  const tap = id => button(id).tap();
  await button('start').waitFor();
  await page.waitForFunction(() => !document.querySelector('#start').disabled, null, { timeout: 90000 });
  assert.match(await button('introGuide').innerText(), /搖桿.*絲絨腳凳/);
  assert.doesNotMatch(await button('introGuide').innerText(), /空白鍵/);
  await tap('pickCast');
  await page.getByRole('button', { name: '短手暴龍', exact: true }).tap();
  await tap('start');
  await tap('align');
  await page.waitForFunction(() => document.body.dataset.mode === 'playing');

  // Drive the game's actual touch handlers using the elements under the two
  // fingertips. WebKit automation offers native tap but no multi-touch swipe.
  async function gesture(step, running = false) {
    await page.evaluate(({ step, running }) => {
      const center = id => {
        const r = document.getElementById(id).getBoundingClientRect();
        return [r.left + r.width / 2, r.top + r.height / 2];
      };
      const finger = (id, [x,y]) => ({
        identifier: id, clientX: x, clientY: y, target: document.elementFromPoint(x,y),
      });
      const dispatch = (type, changedTouches, touches) => {
        const event = new Event(type, { bubbles: true, cancelable: true });
        Object.defineProperties(event, { changedTouches: {value: changedTouches}, touches: {value: touches} });
        changedTouches[0].target.dispatchEvent(event);
      };
      if (step === 'start') {
        const pad = finger(1, center('pad')), run = finger(2, center('sprint'));
        if (!pad.target.closest('#padZone') || !run.target.closest('#sprint')) throw Error('Thumb control obscured');
        window.heldFingers = [pad, run];
        dispatch('touchstart', [pad,run], [pad,run]);
        if (running) {
          pad.clientY -= 48;
          dispatch('touchmove', [pad], [pad,run]);
        }
      } else {
        const [pad, run] = window.heldFingers;
        if (step === 'slide' || step === 'return') {
          const button=step==='slide'?'jump':'sprint';
          [run.clientX, run.clientY] = center(button);
          if (document.elementFromPoint(run.clientX,run.clientY)?.id !== button) throw Error(button+' obscured');
          dispatch('touchmove', [run], [pad,run]);
        } else {
          dispatch('touchend', [pad,run], []);
          delete window.heldFingers;
        }
      }
    }, { step, running });
  }

  // Reach a real ledge before resizing. The ledge and jump counter then
  // distinguish keeping this run from silently starting a fresh one.
  await page.waitForFunction(() => Number(document.querySelector('#height').textContent) === 0);
  await gesture('start', true);
  await page.waitForFunction(() => document.querySelector('#sprint').getAttribute('aria-pressed') === 'true');
  const started = await page.evaluate(() => window.runSeconds);
  await page.waitForFunction(t => window.runSeconds-t >= .29, started);
  await gesture('slide');
  await page.waitForFunction(() => Number(document.querySelector('#height').textContent) > .4);
  await gesture('end');
  await page.waitForFunction(() => document.querySelector('#ledge').textContent === '1 / 24');
  await tap('pause');
  const guide=button('controlGuide');
  await guide.locator('summary').tap();
  assert.match(await guide.innerText(), /同一隻手指滑落「跳躍」/);
  assert.doesNotMatch(await guide.innerText(), /Shift/);
  assert.match(await button('report').innerText(), /1 次起跳 · 0 次跌落/);
  await tap('continue');
  await tap('pause');
  assert.equal(await guide.evaluate(node=>node.open), false);
  assert.match(await button('report').innerText(), /1 次起跳 · 0 次跌落/);
  assert.equal(await button('ledge').textContent(), '1 / 24');
  await tap('continue');
  let jumps = 1;
  for (const [name, width, small, large] of poses) {
    for (const height of [small, large]) {
      await page.setViewportSize({ width, height });
      await page.waitForFunction(([w,h]) => innerWidth === w && innerHeight === h, [width,height]);
      if (await button('continue').isVisible()) await tap('continue');
      assert.equal(await button('ledge').innerText(), '1 / 24');
      assert.equal(await button('chosenCast').textContent(), '短手暴龍');
      const canvas = await button('canvas').boundingBox();
      assert(Math.abs(canvas.width-width) <= 1 && Math.abs(canvas.height-height) <= 1);
      await gesture('start');
      await page.waitForFunction(() => document.querySelector('#sprint').getAttribute('aria-pressed') === 'true');
      await gesture('slide');
      await page.waitForFunction(() => Number(document.querySelector('#height').textContent) > 1.1);
      await page.waitForFunction(() => Number(document.querySelector('#height').textContent) < .8);
      await gesture('return');
      assert.equal(await button('sprint').getAttribute('aria-pressed'), 'true');
      await gesture('slide');
      await page.waitForFunction(() => Number(document.querySelector('#height').textContent) > 1.1);
      await gesture('end');
      await page.waitForFunction(() => Number(document.querySelector('#height').textContent) < .8);
      assert.equal(await button('pad').getAttribute('data-active'), null);
      assert.equal(await button('sprint').getAttribute('aria-pressed'), 'false');
      await tap('pause');
      jumps+=2;
      assert.match(await button('report').innerText(), new RegExp('· ' + jumps + ' 次起跳 · 0 次跌落'));
      await tap('continue');
      console.log(name, width, height, 'ledge 1, jumps', jumps);
    }
  }
}

(async () => {
  const browser = await webkit.launch();
  try {
    const page = await browser.newPage({ isMobile: true, hasTouch: true, viewport: { width: 382, height: 580 } });
    const errors = [];
    page.on('pageerror', e => errors.push(e.message));
    await exercise(page, process.argv[2] || 'http://127.0.0.1:8137/');
    assert.deepEqual(errors, []);
  } finally {
    await browser.close();
  }
})().catch(error => { console.error(error); process.exitCode = 1; });
