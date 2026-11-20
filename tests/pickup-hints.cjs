const assert = require('node:assert/strict');
const { webkit } = require(process.env.PLAYWRIGHT_LIB || 'playwright');
const poses = require('./duo-viewports.cjs');

async function jumpWithHint(page) {
  await page.locator('#pickupHint').waitFor({state:'visible'});
  await page.evaluate(()=>{
    window.jumpFrames=[];
    window.onPickupFrame=()=>{
      const tag=document.querySelector('#pickupHint');
      const box=tag.getBoundingClientRect();
      const [cx,cy]=window.itemHint;
      const [x1,y1,x2,y2]=window.itemHint.slice(11);
      const hasMark=x2>x1 && y2>y1;
      window.jumpFrames.push({
        visible:!tag.hidden && tag.textContent.includes('二段跳'),
        offsetX:box.left-cx*innerWidth,offsetY:box.top-cy*innerHeight,
        hasMark, coversMark:hasMark && box.right>x1*innerWidth && box.left<x2*innerWidth &&
          box.bottom>y1*innerHeight && box.top<y2*innerHeight,
      });
    };
    window.onPickupFrame();
  });
  await page.locator('#jump').tap();
  await page.waitForFunction(()=>Number(document.querySelector('#height').textContent)>1.1);
  await page.waitForFunction(()=>Number(document.querySelector('#height').textContent)===0);
  const samples=await page.evaluate(()=>{delete window.onPickupFrame;return window.jumpFrames});
  assert(samples.some(s=>s.hasMark),'the real jump displayed its landing cross');
  assert(samples.every(s=>s.visible && !s.coversMark),'duck stays labelled without covering the landing cross');
  let maxShift=0;
  for(let i=1;i<samples.length;i++){
    const prev=samples[i-1], next=samples[i];
    maxShift=Math.max(maxShift,Math.hypot(next.offsetX-prev.offsetX,next.offsetY-prev.offsetY));
  }
  assert(maxShift<24,'callout shifted '+maxShift.toFixed(1)+' px relative to its pickup');
  console.log('Standing jump, largest shift relative to duck:',maxShift.toFixed(1),'px');
}

async function orbit(page) {
  return page.evaluate(async () => {
    const el = id => document.getElementById(id);
    const step = async () => {
      const start = window.gameTime;
      while (window.gameTime < start+.07) await new Promise(requestAnimationFrame);
    };
    const visible = node => node.getBoundingClientRect();
    const overlaps = (a,b) => b.width && b.height &&
      Math.min(a.right,b.right)-Math.max(a.left,b.left) > .5 &&
      Math.min(a.bottom,b.bottom)-Math.max(a.top,b.top) > .5;
    const controls = document.querySelectorAll('header .brand,header .actions,.alt-card,#follow,#notice,#pad,#sprint,#jump');
    const x=innerWidth*.26, y=innerHeight*.66;
    const target=document.elementFromPoint(x,y);
    if (!target.closest('#padZone')) throw Error('Could not place the floating pad');
    const finger={identifier:1,clientX:x,clientY:y,target};
    function contact(type,touches) {
      const event=new Event(type,{bubbles:true,cancelable:true});
      Object.defineProperties(event,{touches:{value:touches},changedTouches:{value:[finger]}});
      target.dispatchEvent(event);
    }
    contact('touchstart',[finger]);
    window.drive('align');
    window.drive('look',0,-.10);
    let shown=0, lines=0, hidden=0;
    for (let angle=0; angle<36; angle++) {
      window.drive('look',-Math.PI*2/(3.55*36),0);
      await step();
      const tag=el('pickupHint'), line=el('pickupLine');
      const [, , name, ...projected]=window.itemHint;
      if (!name) {
        if (!tag.hidden || (line && !line.hidden)) throw Error('Stale hint after the item left view');
        hidden++;
        continue;
      }
      if (tag.hidden) throw Error('Visible pickup lost its tag');
      const box=visible(tag);
      if (box.left<34 || box.top<14 || box.right>innerWidth-22 || box.bottom>innerHeight-18)
        throw Error('Pickup outside safe area at camera step '+angle);
      const hit=Array.from(controls).find(node=>overlaps(box,visible(node)));
      if (hit) throw Error('Pickup overlaps '+(hit.id||hit.className)+' at camera step '+angle);
      if(projected.length!==12 || !projected.every(Number.isFinite)) throw Error('Missing pickup, climber or landing bounds');
      for(const [i,subject] of ['pickup','climber','landing cross'].entries()){
        const [x1,y1,x2,y2]=projected.slice(i*4,i*4+4);
        const rect={left:x1*innerWidth,top:y1*innerHeight,right:x2*innerWidth,bottom:y2*innerHeight};
        if (overlaps(box,{...rect,width:rect.right-rect.left,height:rect.bottom-rect.top}))
          throw Error('Label covers '+subject+' at camera step '+angle);
      }
      if (!tag.textContent.includes('二段跳') || !tag.textContent.includes('15 秒') || !tag.textContent.includes('3 次'))
        throw Error('Missing double-jump limits');
      if (line && !line.hidden) lines++;
      shown++;
    }
    contact('touchend',[]);
    return {shown,lines,hidden};
  });
}

(async () => {
  const browser=await webkit.launch();
  try {
    const page=await browser.newPage({isMobile:true,hasTouch:true,viewport:{width:594,height:368}});
    await page.addInitScript(()=>{
      let ui;
      Object.defineProperty(window,'OnlyJumpUI',{get:()=>ui,set:bridge=>{
        ui=bridge;
        const bind=ui.bindGame, update=ui.update, hint=ui.pickupHint;
        ui.bindGame=fn=>{window.drive=fn;return bind.call(ui,fn)};
        ui.update=(...args)=>{window.gameTime=args[6];return update.apply(ui,args)};
        ui.pickupHint=(...args)=>{
          window.itemHint=args;
          const result=hint.apply(ui,args);
          if(window.onPickupFrame)window.onPickupFrame();
          return result;
        };
      }});
    });
    await page.goto(process.argv[2] || 'http://127.0.0.1:8137/');
    await page.locator('#start:enabled').tap({timeout:90000});
    await jumpWithHint(page);
    await page.addStyleTag({content:':root{--safe-left:34px;--safe-right:22px;--safe-top:14px;--safe-bottom:18px}'});
    await page.locator('#pause').tap();
    await page.locator('label').filter({has:page.locator('input[value=large]')}).tap();
    await page.locator('#continue').tap();
    for(const [pose,width,small,large] of poses) {
      for(const height of [small,large]) {
        await page.setViewportSize({width,height});
        await page.waitForFunction(([w,h])=>innerWidth===w && innerHeight===h,[width,height]);
        if(await page.locator('#continue').isVisible())await page.locator('#continue').tap();
        const result=await orbit(page);
        assert(result.shown>0,'expected a visible pickup');
        if(width<400)assert(result.lines>0 && result.hidden>0,'expected both a displaced label and the pickup to rotate out of view');
        console.log(pose,width+'×'+height,result);
      }
    }
    await page.locator('#branch').tap();
    await page.locator('#pickupHint').waitFor({state:'visible'});
    assert.match(await page.locator('#pickupHint').textContent(), /二段跳/);
    await page.locator('#pause').tap();
    assert(await page.locator('#pickupHint').isHidden() && await page.locator('#pickupLine').isHidden());
    await page.locator('#continue').tap();
    await page.evaluate(async()=>{
      async function runFor(seconds) {
        const until=window.gameTime+seconds;
        while(window.gameTime+.00001<until)await new Promise(requestAnimationFrame);
      }
      window.drive('sprint',true);
      window.drive('stick',0,-.78);
      await runFor(.20);
      window.drive('jump');
      await runFor(.27);
      window.drive('stick',0,0);
      window.drive('sprint',false);
    });
    await page.waitForFunction(()=>document.querySelector('#power').textContent.includes('餘 3 次'),null,{timeout:5000});
    // The awning can come into view beyond the trampoline as the duck disappears.
    const hint=await page.evaluate(()=>({
      target:window.itemHint[2],
      text:document.querySelector('#pickupHint').textContent,
      hidden:document.querySelector('#pickupHint').hidden,
      lineHidden:document.querySelector('#pickupLine').hidden,
    }));
    if(hint.target){
      assert.equal(hint.target,'飛爪\n扣銅環 · 一次');
      assert.equal(hint.hidden,false);
      assert.equal(hint.text,'道具 · '+hint.target);
    }else{
      assert(hint.hidden && hint.lineHidden,'No pickup should leave a label or line on screen');
    }
    console.log('Collected the duck, removed its hint and equipped three extra jumps');
  } finally {
    await browser.close();
  }
})().catch(error=>{console.error(error);process.exitCode=1});
