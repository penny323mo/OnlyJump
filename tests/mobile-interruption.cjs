const assert = require('node:assert/strict');
const { webkit } = require(process.env.PLAYWRIGHT_LIB || 'playwright');

const url = process.argv[2] || 'http://127.0.0.1:8137/';

async function run(browser) {
  const page = await browser.newPage({ isMobile: true, hasTouch: true, viewport: {width: 844, height: 390} });
  const errors = [];
  page.on('pageerror', e => errors.push(e.message));
  await page.addInitScript(() => {
    let bridge;
    Object.defineProperty(window, 'OnlyJumpUI', {get: () => bridge, set(value) {
      bridge = value;
      const update = value.update;
      value.update = function (...args) {
        const [mode,height,,,,sprint,elapsed,falls,jumps] = args;
        window.sample = {mode,height,sprint,elapsed,falls,jumps};
        return update.apply(this,args);
      };
    }});
  });
  await page.goto(url);
  const button = id => page.locator('#'+id);
  const tap = id => button(id).tap();
  const sample = () => page.evaluate(() => window.sample);
  const hide = () => page.evaluate(() => window.dispatchEvent(new PageTransitionEvent('pagehide', {persisted:true})));
  await page.getByRole('button', {name:'開始攀登',exact:true}).tap({timeout:90000});
  await page.evaluate(() => {
    // WebKit automation supports tap. Replay the thumb contacts against
    // their original DOM targets for the simultaneous hold and drag.
    const contacts = new Map();
    window.touch = (type,id,element,dx=0,dy=0) => {
      if (type==='touchstart') {
        const r=document.getElementById(element).getBoundingClientRect();
        const x=r.x+r.width/2, y=r.y+r.height/2;
        contacts.set(id,{identifier:id,target:document.elementFromPoint(x,y),x,y});
      }
      const t=contacts.get(id);
      t.clientX=t.x+dx;
      t.clientY=t.y+dy;
      if (type==='touchend') contacts.delete(id);
      const event=new Event(type,{bubbles:true,cancelable:true});
      Object.defineProperties(event,{touches:{value:[...contacts.values()]},changedTouches:{value:[t]}});
      t.target.dispatchEvent(event);
    };
  });
  await page.evaluate(() => {
    touch('touchstart',1,'pad');
    touch('touchmove',1,'pad',12);
    touch('touchstart',2,'sprint');
    touch('touchstart',5,'jump');
    touch('touchend',5,'jump');
  });
  await page.waitForFunction(() => sample.height>.35 && sample.jumps===1 && sample.sprint);
  assert.equal(await button('pad').getAttribute('data-active'),'true');
  await hide();
  const frozen=await sample();
  assert.equal(frozen.mode,'interrupted');
  assert.equal(frozen.sprint,false);
  assert.equal(await button('pad').getAttribute('data-active'),null);
  assert(await button('overlay').isHidden() && await button('resumeHere').isVisible());
  await page.evaluate(() => {
    touch('touchmove',1,'pad',30);
    touch('touchmove',2,'sprint',0,120);
    touch('touchend',1,'pad');
    touch('touchend',2,'sprint');
    touch('touchstart',3,'pad');
    touch('touchstart',4,'sprint');
  });
  await page.waitForTimeout(650);
  assert.deepEqual(await sample(),{...frozen,sprint:true});
  await page.evaluate(() => touch('touchmove',3,'pad',19));
  const resumed=await sample();
  assert.equal(resumed.mode,'playing');
  assert.equal(resumed.jumps,1);
  assert(resumed.sprint && resumed.elapsed-frozen.elapsed<.15);
  await page.evaluate(() => {touch('touchend',3,'pad');touch('touchend',4,'sprint');});
  await page.waitForFunction(() => sample.height<.03 && !sample.sprint);
  await hide();
  await tap('jump');
  await page.waitForFunction(() => sample.mode==='playing' && sample.height>.35 && sample.jumps===2);
  await hide();
  await tap('pause');
  await hide();
  assert.equal((await sample()).mode,'paused');
  assert(await button('overlay').isVisible() && await button('resumeHere').isHidden());
  await tap('continue');
  await hide();
  await tap('resumeHere');
  await page.waitForFunction(() => sample.height<.03 && sample.mode==='playing');
  assert.equal((await sample()).falls,0);
  assert.deepEqual(errors,[]);
  console.log('PASS interrupted jump, old contacts ignored, prepared sprint, steer/jump/neutral resume and manual pause');
}

(async () => {
  const browser = await webkit.launch();
  try { await run(browser); }
  finally { await browser.close(); }
})().catch(error => { console.error(error); process.exitCode=1; });
