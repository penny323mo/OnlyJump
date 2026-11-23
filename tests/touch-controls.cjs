const test = require('node:test');
const assert = require('node:assert/strict');
const {readFileSync} = require('node:fs');
const {runInNewContext} = require('node:vm');
const {join} = require('node:path');

function fixture(jumpBounds={left:720,top:260,width:80,height:80},touchEvents=true) {
  const window = {innerWidth:844,innerHeight:390};
  if (touchEvents) window.ontouchstart=null;
  const handlers = new Map();
  window.addEventListener = (type,fn)=>handlers.set(type,fn);
  const nodes = {};
  nodes.canvas={focus(){}};
  for(const id of ['padZone','pad','sprint','jump','look']){
    nodes[id]={id,style:{},dataset:{},closest:()=>nodes[id],firstElementChild:{style:{}},
      getBoundingClientRect:()=>id==='jump'?jumpBounds:{left:20,top:229,width:136,height:136}};
  }
  const layoutSize=nodes.layoutSize={offsetWidth:844,offsetHeight:390};
  const calls=[];
  const source=readFileSync(join(__dirname,'../web/controls.js'),'utf8');
  const reset=runInNewContext(source+'\nattachControls(send,()=>true)',{
    window,document:{getElementById:id=>nodes[id]},innerWidth:844,innerHeight:390,
    send:(...args)=>calls.push(args)
  });
  const finger=(identifier,role,clientX,clientY)=>({identifier,target:nodes[role],clientX,clientY});
  const fire=(type,changedTouches,touches)=>handlers.get(type)({changedTouches,touches,cancelable:true,preventDefault(){}});
  const pointer=(type,id,role,x)=>handlers.get(type)({pointerId:id,pointerType:'touch',target:nodes[role],
    clientX:x,clientY:120,button:0,buttons:type==='pointerup'?0:1,preventDefault(){}});
  return {fire,finger,pointer,reset,calls,pad:nodes.pad,layoutSize,window};
}

test('floating pad starts neutral under the thumb, reverses, and returns home on release',()=>{
  const {fire,finger,calls,pad}=fixture();
  const center=finger(7,'padZone',272,195);
  const right=finger(7,'padZone',315,195),left=finger(7,'padZone',220,195);
  fire('touchstart',[center],[center]);
  assert.deepEqual(calls.at(-1),['stick',0,0]);
  assert.deepEqual([pad.style.left,pad.style.top],['272px','195px']);
  fire('touchmove',[right],[right]);
  fire('touchmove',[left],[left]);
  assert.deepEqual(calls.slice(-2),[['stick',1,0],['stick',-1,0]]);
  fire('touchend',[left],[]);
  assert.deepEqual(calls.at(-1),['stick',0,0]);
  assert.deepEqual([pad.style.left,pad.style.top,pad.firstElementChild.style.transform],['','','']);
  const second=finger(2,'padZone',39,322);
  fire('touchstart',[second],[second]);
  assert.deepEqual(calls.at(-1),['stick',0,0]);
  assert.equal(pad.style.left,'39px');
});

test('one right thumb can hold sprint, slide to jump once, and release independently of the pad',()=>{
  const {fire,finger,calls}=fixture();
  const pad=finger(4,'padZone',90,280),run=finger(8,'sprint',760,205),inside=finger(8,'sprint',757,312);
  fire('touchstart',[pad,run],[pad,run]);
  fire('touchmove',[inside],[pad,inside]);
  fire('touchmove',[run],[pad,run]);
  fire('touchmove',[inside],[pad,inside]);
  assert.deepEqual(calls,[['stick',0,0],['sprint',true],['jump']]);
  fire('touchend',[inside],[pad]);
  assert.deepEqual(calls.at(-1),['sprint',false]);
  assert(!calls.slice(1).some(c=>c[0]==='stick'));
});

test('left thumb crossing the centre keeps steering while a separate right thumb looks',()=>{
  const {fire,finger,calls}=fixture();
  const left=finger(1,'padZone',394,177), right=finger(2,'look',645,156);
  fire('touchstart',[left],[left]);
  const across=finger(1,'look',458,177);
  fire('touchmove',[across],[across]);
  assert.deepEqual(calls,[['stick',0,0],['stick',1,0]]);
  fire('touchstart',[right],[across,right]);
  const turn=finger(2,'look',684,156);
  fire('touchmove',[turn],[across,turn]);
  assert.deepEqual(calls.at(-1),['look',.1,0]);
  fire('touchend',[turn],[across]);
  fire('touchend',[across],[]);
  assert.deepEqual(calls.at(-1),['stick',0,0]);
});

test('a touch in the lower-left circle can only steer even if hit testing returns the look layer',()=>{
  const {fire,finger,calls}=fixture();
  const center=finger(3,'look',88,294), inside=finger(3,'look',107,294);
  fire('touchstart',[center],[center]);
  fire('touchmove',[inside],[inside]);
  fire('touchend',[inside],[]);
  assert.deepEqual(calls.map(([action])=>action),['stick','stick','stick']);
  assert(calls[1][1]>0 && calls[1][1]<1);
});

test('direct jump, sprint-only hold and cancelled swipe are distinct',()=>{
  const {fire,finger,calls}=fixture();
  const jump=finger(1,'jump',760,300),run=finger(3,'sprint',760,200);
  fire('touchstart',[jump],[jump]);fire('touchend',[jump],[]);
  fire('touchstart',[run],[run]);fire('touchend',[run],[]);
  fire('touchstart',[run],[run]);fire('touchcancel',[finger(3,'sprint',760,310)],[]);
  assert.deepEqual(calls,[['jump'],['sprint',true],['sprint',false],['sprint',true],['sprint',false]]);
});

test('pinch works on either side or across the screen, with one scale per touch sample',()=>{
  for(const [x1,x2] of [[150,250],[550,650],[370,470]]){
    const {fire,finger,calls,pad}=fixture();
    const contact=(id,x)=>finger(id,x<422?'padZone':'look',x,140);
    const a=contact(1,x1), b=contact(2,x2);
    fire('touchstart',[a,b],[a,b]);
    const wide=[contact(1,x1-25),contact(2,x2+25)];
    fire('touchmove',wide,wide);
    const shifted=[contact(1,x1-15),contact(2,x2+35)];
    fire('touchmove',shifted,shifted);
    fire('touchmove',[a,b],[a,b]);
    fire('touchend',[a],[b]);
    fire('touchmove',[wide[1]],[wide[1]]);
    fire('touchend',[wide[1]],[]);
    assert.deepEqual(calls.filter(([name])=>name==='zoom'),[['zoom',1.5],['zoom',2/3]]);
    assert(!calls.some(([name,x,y])=>name==='look'||(name==='stick'&&(x||y))));
    assert.equal(pad.dataset.active,undefined);
  }
});

test('a staggered pinch across the centre tolerates slight drift of the first fingertip',()=>{
  const {fire,finger,calls,pad}=fixture();
  const first=finger(1,'look',480,150), drift=finger(1,'look',477,151);
  fire('touchstart',[first],[first]);
  fire('touchmove',[drift],[drift]);
  const second=finger(2,'padZone',377,151);
  fire('touchstart',[second],[drift,second]);
  const wide=finger(1,'look',527,151);
  fire('touchmove',[wide],[wide,second]);
  fire('touchend',[wide,second],[]);
  assert.deepEqual(calls,[['zoom',1.5]]);
  assert.equal(pad.dataset.active,undefined);
});

test('a slow one-finger drag retains its full distance and subsequent fine adjustments',()=>{
  const {fire,finger,calls}=fixture();
  const start=finger(1,'look',480,150);
  fire('touchstart',[start],[start]);
  for(const x of [481,482,483,484,483]) {
    const moved=finger(1,'look',x,150);
    fire('touchmove',[moved],[moved]);
  }
  assert.deepEqual(calls,[['look',4/390,0],['look',-1/390,0]]);
});

test('two extra fingers on the left zoom without stealing a moving stick or sprint swipe',()=>{
  const {fire,finger,calls,pad}=fixture();
  const left=finger(1,'padZone',75,280), steered=finger(1,'padZone',110,280);
  const sprint=finger(4,'sprint',760,200);
  fire('touchstart',[left,sprint],[left,sprint]);
  fire('touchmove',[steered],[steered,sprint]);
  const a=finger(2,'padZone',160,140), b=finger(3,'padZone',260,140);
  fire('touchstart',[a,b],[steered,sprint,a,b]);
  const wide=finger(3,'padZone',310,140);
  const reversed=finger(1,'padZone',25,280);
  fire('touchmove',[wide,reversed],[reversed,sprint,a,wide]);
  fire('touchcancel',[wide],[reversed,sprint,a]);
  fire('touchend',[a],[reversed,sprint]);
  assert.deepEqual(calls.slice(-2),[['stick',-1,0],['zoom',1.5]]);
  assert.equal(pad.dataset.active,'true');
  const jump=finger(4,'sprint',760,300);
  fire('touchmove',[jump],[reversed,jump]);
  assert.deepEqual(calls.at(-1),['jump']);
  fire('touchend',[reversed,jump],[]);
  assert.deepEqual(calls.slice(-2),[['stick',0,0],['sprint',false]]);
});

test('a thumb resting on the visible stick can start steering during a pinch, in either touchdown order',()=>{
  for(const stickFirst of [true,false]){
    const {fire,finger,calls,pad}=fixture();
    const stick=finger(1,'padZone',88,297), first=finger(2,'look',590,150), second=finger(3,'padZone',270,150);
    const touches=stickFirst?[stick,first]:[first,stick];
    fire('touchstart',[touches[0]],[touches[0]]);
    fire('touchstart',[touches[1]],touches);
    assert.equal(pad.dataset.active,'true');
    fire('touchstart',[second],[...touches,second]);
    const wide=finger(3,'padZone',190,150), drive=finger(1,'padZone',108,297);
    fire('touchmove',[drive,wide],[drive,first,wide]);
    assert(calls.some(([name,x])=>name==='stick' && x>0.4));
    assert.deepEqual(calls.filter(([name])=>name==='zoom'),[['zoom',1.25]]);
    fire('touchend',[first,wide],[drive]);
    assert.equal(pad.dataset.active,'true');
    const reverse=finger(1,'padZone',68,297);
    fire('touchmove',[reverse],[reverse]);
    assert(calls.at(-1)[1]<-0.4);
    fire('touchend',[reverse],[]);
    assert.deepEqual(calls.at(-1),['stick',0,0]);
    assert.equal(pad.dataset.active,undefined);
    assert(!calls.some(([name])=>name==='look' || name==='jump'));
  }
});

test('the home stick and two left-side pinch fingers keep their roles in all six touchdown orders',()=>{
  for(const order of ['012','021','102','120','201','210']){
    const {fire,finger,calls,pad}=fixture();
    const contacts=[finger(1,'padZone',88,297),finger(2,'padZone',170,135),finger(3,'padZone',310,135)];
    const held=[];
    for(const index of order){
      held.push(contacts[index]);
      fire('touchstart',[contacts[index]],held);
    }
    const drive=finger(1,'padZone',113,297), wide=finger(3,'padZone',345,135);
    fire('touchmove',[drive,wide],[drive,contacts[1],wide]);
    assert.deepEqual(calls.filter(([name])=>name==='zoom'),[['zoom',1.25]],order);
    assert(calls.some(([name,x,y])=>name==='stick' && x>.6 && y===0),order);
    fire('touchend',[wide,contacts[1]],[drive]);
    assert.equal(pad.dataset.active,'true',order);
    const reverse=finger(1,'padZone',63,297);
    fire('touchmove',[reverse],[reverse]);
    assert(calls.at(-1)[0]==='stick' && calls.at(-1)[1]<-.6,order);
    fire('touchend',[reverse],[]);
    assert.deepEqual(calls.at(-1),['stick',0,0],order);
    assert.equal(pad.dataset.active,undefined,order);
  }
});

test('a floating stick which has already steered keeps its thumb after returning to neutral',()=>{
  const {fire,finger,calls,pad}=fixture();
  const float=finger(1,'padZone',212,140), drive=finger(1,'padZone',242,140);
  const home=finger(2,'padZone',88,297), other=finger(3,'padZone',188,297);
  fire('touchstart',[float],[float]);
  fire('touchmove',[drive],[drive]);
  fire('touchmove',[float],[float]);
  fire('touchstart',[home],[float,home]);
  fire('touchstart',[other],[float,home,other]);
  const wide=finger(3,'padZone',238,297);
  fire('touchmove',[wide],[float,home,wide]);
  assert.deepEqual(calls.at(-1),['zoom',1.5]);
  assert.equal(pad.style.left,'212px');
  fire('touchmove',[drive],[drive,home,wide]);
  assert(calls.at(-1)[0]==='stick' && calls.at(-1)[1]>.7);
  fire('touchend',[drive,home,wide],[]);
  assert.deepEqual(calls.at(-1),['stick',0,0]);
});

test('reset clears a pinch and fresh fingers can orbit and pinch again',()=>{
  const {fire,finger,reset,calls}=fixture();
  const a=finger(1,'look',520,150), b=finger(2,'look',620,150);
  fire('touchstart',[a,b],[a,b]);
  reset();
  fire('touchmove',[b],[b]);
  assert.deepEqual(calls,[]);
  fire('touchstart',[a],[a]);
  const right=finger(1,'look',559,150);
  fire('touchmove',[right],[right]);
  assert.deepEqual(calls.at(-1),['look',.1,0]);
  fire('touchstart',[b],[right,b]);
  const wider=finger(2,'look',681,150);
  fire('touchmove',[wider],[right,wider]);
  assert.deepEqual(calls.at(-1),['zoom',2]);
});

test('a new joystick finger can steer while the other thumb is already orbiting',()=>{
  const {fire,finger,calls}=fixture();
  const look=finger(1,'look',545,155), turned=finger(1,'look',575,155);
  fire('touchstart',[look],[look]);
  fire('touchmove',[turned],[turned]);
  const joy=finger(2,'padZone',80,275), steered=finger(2,'padZone',120,275);
  fire('touchstart',[joy],[turned,joy]);
  fire('touchmove',[steered],[turned,steered]);
  assert.deepEqual(calls.map(([name])=>name),['look','stick','stick']);
  assert.deepEqual(calls.at(-1),['stick',1,0]);
});

test('pointer-only touchscreens sample both fingers together and retire cancelled pinches',()=>{
  const {pointer,calls,window}=fixture(undefined,false);
  const frames=[];
  window.requestAnimationFrame=fn=>frames.push(fn);
  pointer('pointerdown',1,'padZone',250);
  pointer('pointerdown',2,'look',500);
  pointer('pointermove',1,'padZone',275);
  pointer('pointermove',2,'look',525);
  assert.equal(frames.length,1);
  frames.shift()();
  assert.deepEqual(calls,[['stick',0,0]]);
  pointer('pointermove',2,'look',650);
  frames.shift()();
  assert.deepEqual(calls.at(-1),['zoom',1.5]);
  pointer('pointermove',2,'look',680);
  pointer('pointercancel',2,'look',680);
  frames.shift()();
  pointer('pointerup',1,'padZone',275);
  assert.equal(calls.length,2);
});

test('a fast slide can finish over the jump button without a final move event',()=>{
  const {fire,finger,calls}=fixture();
  const run=finger(1,'sprint',760,200);
  fire('touchstart',[run],[run]);fire('touchend',[finger(1,'sprint',760,355)],[]);
  assert.deepEqual(calls,[['sprint',true],['jump'],['sprint',false]]);
});

test('a two-thumb swipe samples the new stick direction before the jump in either contact order',()=>{
  for(const actionFirst of [true,false]){
    const {fire,finger,calls}=fixture();
    const pad=finger(1,'padZone',90,280), run=finger(2,'sprint',760,200);
    const forward=finger(1,'padZone',90,235), jump=finger(2,'sprint',760,300);
    const batch=actionFirst?[jump,forward]:[forward,jump];
    fire('touchstart',[pad,run],[pad,run]);
    fire('touchmove',batch,batch);
    assert.deepEqual(calls.slice(-2),[['stick',0,-1],['jump']]);
  }
});

test('lifting both thumbs keeps the held direction for a last-segment jump, then releases both controls',()=>{
  for(const actionFirst of [true,false]){
    const {fire,finger,calls,pad}=fixture();
    const joy=finger(1,'padZone',90,280),run=finger(2,'sprint',760,200);
    const forward=finger(1,'padZone',90,235),jump=finger(2,'sprint',760,300);
    fire('touchstart',[joy,run],[joy,run]);
    fire('touchmove',[forward],[forward,run]);
    fire('touchend',actionFirst?[jump,forward]:[forward,jump],[]);
    const at=calls.findIndex(([action])=>action==='jump');
    assert.deepEqual(calls[at-1],['stick',0,-1]);
    assert.equal(calls.filter(([action])=>action==='jump').length,1);
    assert(calls.slice(at+1).some(([action,x,y])=>action==='stick' && x===0 && y===0));
    assert(calls.slice(at+1).some(([action,held])=>action==='sprint' && held===false));
    assert.equal(pad.dataset.active,undefined);
  }
});

test('releasing a direct jump and a crossing sprint finger together cannot queue a second jump',()=>{
  for(const actionFirst of [true,false]){
    const {fire,finger,calls}=fixture();
    const run=finger(2,'sprint',760,200),jump=finger(3,'jump',760,300);
    const across=finger(2,'sprint',760,300);
    fire('touchstart',[run,jump],[run,jump]);
    fire('touchend',actionFirst?[across,jump]:[jump,across],[]);
    assert.deepEqual(calls,[['sprint',true],['jump'],['sprint',false]]);
  }
});

test('a wide jump button accepts its outer edge and ignores the empty corner',()=>{
  const {fire,finger,calls}=fixture({left:700,top:230,width:144,height:100});
  const run=finger(1,'sprint',708,180), corner=finger(1,'sprint',708,232);
  fire('touchstart',[run],[run]);fire('touchmove',[corner],[corner]);
  assert.deepEqual(calls,[['sprint',true]]);
  const beyond=finger(1,'sprint',708,335);
  fire('touchmove',[beyond],[beyond]);fire('touchend',[beyond],[]);
  assert.deepEqual(calls,[['sprint',true],['jump'],['sprint',false]]);
});

test('separate sprint, jump and camera fingers keep their own roles',()=>{
  const {fire,finger,calls}=fixture();
  const run=finger(1,'sprint',760,200), look=finger(2,'look',465,150),jump=finger(3,'jump',760,300);
  fire('touchstart',[run,look,jump],[run,look,jump]);
  const moved=finger(2,'look',500,165);
  fire('touchmove',[moved],[run,moved,jump]);
  fire('touchend',[jump],[run,moved]);
  assert.deepEqual(calls.map(c=>c[0]),['sprint','jump','look']);
  fire('touchcancel',[run],[moved]);
  assert.deepEqual(calls.at(-1),['sprint',false]);
});

test('missing contacts, interruption and reset release controls exactly once',()=>{
  const {fire,finger,reset,calls,pad}=fixture();
  const joy=finger(1,'padZone',44,277),sprint=finger(2,'sprint',760,195);
  fire('touchstart',[joy],[joy]);
  fire('touchmove',[finger(1,'padZone',90,277)],[joy]);
  fire('touchstart',[sprint],[sprint]);
  assert.deepEqual(calls.filter(c=>c[0]==='stick'),[['stick',0,0],['stick',1,0],['stick',0,0]]);
  assert.deepEqual(calls.filter(c=>c[0]==='sprint'),[['sprint',true]]);
  reset();
  const before=calls.length;
  fire('touchmove',[joy],[joy]);
  assert.equal(calls.length,before);
  assert.equal(pad.style.top,'');
  assert.deepEqual(calls.at(-1),['sprint',false]);
});

test('resizing a foldable viewport releases held sprint and movement until a fresh contact',()=>{
  const {fire,finger,calls,pad,layoutSize}=fixture();
  const joy=finger(1,'padZone',60,290),run=finger(2,'sprint',760,205);
  fire('touchstart',[joy,run],[joy,run]);
  fire('touchmove',[finger(1,'padZone',18,290)],[joy,run]);
  layoutSize.offsetWidth=594;
  fire('resize');
  assert.deepEqual(calls.slice(-2),[['stick',0,0],['sprint',false]]);
  assert.equal(pad.style.left,'');
  const released=calls.length;
  fire('touchmove',[finger(2,'sprint',760,300)],[joy,run]);
  fire('touchend',[joy,run],[]);
  assert.equal(calls.length,released);
  fire('touchstart',[joy],[joy]);
  assert.equal(pad.style.left,'60px');
});

test('browser toolbar resizes preserve moving and sprinting fingers until the swipe or release',()=>{
  const {fire,finger,calls,pad}=fixture();
  const joy=finger(1,'padZone',90,280), left=finger(1,'padZone',38,280);
  const run=finger(2,'sprint',760,205), jump=finger(2,'sprint',760,300);
  fire('touchstart',[joy,run],[joy,run]);
  fire('touchmove',[left],[left,run]);
  const held=calls.length;
  fire('resize');
  fire('resize');
  assert.equal(calls.length,held);
  assert.equal(pad.dataset.active,'true');
  fire('touchmove',[jump],[left,jump]);
  fire('touchend',[left,jump],[]);
  assert.deepEqual(calls.slice(held),[['jump'],['stick',0,0],['sprint',false]]);
});

test('a jump button moving under a held sprint finger does not count as a swipe',()=>{
  const bounds={left:720,top:260,width:80,height:80};
  const {fire,finger,calls}=fixture(bounds);
  const run=finger(2,'sprint',760,248);
  const outside=finger(2,'sprint',760,215),inside=finger(2,'sprint',760,265);
  fire('touchstart',[run],[run]);
  bounds.top=220;
  fire('resize');
  fire('touchmove',[run],[run]);
  fire('touchmove',[outside],[outside]);
  assert.deepEqual(calls,[['sprint',true]]);
  fire('touchend',[inside],[]);
  assert.deepEqual(calls,[['sprint',true],['jump'],['sprint',false]]);
});

test('changing only the split-window height still releases contacts',()=>{
  const {fire,finger,calls,layoutSize}=fixture();
  const run=finger(2,'sprint',760,205);
  fire('touchstart',[run],[run]);
  layoutSize.offsetHeight-=60;
  fire('resize');
  fire('touchend',[finger(2,'sprint',760,300)],[]);
  assert.deepEqual(calls,[['sprint',true],['sprint',false]]);
});

test('the first press on the unfolded display survives a delayed resize event',()=>{
  const {fire,finger,calls,layoutSize,window}=fixture({left:505,top:720,width:144,height:144});
  window.innerWidth=layoutSize.offsetWidth=382;
  window.innerHeight=layoutSize.offsetHeight=618;
  fire('resize');
  const old=finger(1,'padZone',74,400);
  fire('touchstart',[old],[old]);
  fire('touchmove',[finger(1,'padZone',20,400)],[old]);
  window.innerWidth=layoutSize.offsetWidth=669;
  window.innerHeight=layoutSize.offsetHeight=902;
  const run=finger(2,'sprint',577,644);
  fire('touchstart',[run],[run]);
  fire('resize');
  fire('touchend',[finger(2,'sprint',577,792)],[]);
  assert.deepEqual(calls.slice(-4),[['stick',0,0],['sprint',true],['jump'],['sprint',false]]);
});

test('a release from the outer display cannot jump on the relocated button',()=>{
  const bounds={left:467,top:226,width:125,height:125};
  const {fire,finger,calls,layoutSize,window}=fixture(bounds);
  window.innerWidth=layoutSize.offsetWidth=594;
  window.innerHeight=layoutSize.offsetHeight=368;
  fire('resize');
  const run=finger(2,'sprint',526,172);
  fire('touchstart',[run],[run]);
  window.innerWidth=layoutSize.offsetWidth=385;
  window.innerHeight=layoutSize.offsetHeight=571;
  Object.assign(bounds,{left:229,top:408,width:144,height:144});
  fire('touchend',[finger(2,'sprint',301,480)],[]);
  fire('resize');
  assert.deepEqual(calls,[['sprint',true],['sprint',false]]);
});

test('the first retouch claims the stick when its release was lost but sprint is still held',()=>{
  const {fire,finger,calls,pad}=fixture();
  const old=finger(1,'padZone',60,280), run=finger(2,'sprint',760,205);
  fire('touchstart',[old,run],[old,run]);
  fire('touchmove',[finger(1,'padZone',15,280)],[old,run]);
  const next=finger(3,'padZone',100,265);
  fire('touchstart',[next],[run,next]);
  assert.equal(pad.style.left,'100px');
  fire('touchmove',[finger(3,'padZone',145,265)],[run,next]);
  assert.deepEqual(calls.at(-1),['stick',1,0]);
  assert(!calls.some(c=>c[0]==='sprint'&&c[1]===false));
  fire('touchend',[next,run],[]);
  assert.deepEqual(calls.slice(-2),[['stick',0,0],['sprint',false]]);
});

test('a reused touch identifier releases its old role before a new press',()=>{
  const {fire,finger,calls}=fixture();
  const sprint=finger(3,'sprint',760,205),jump=finger(3,'jump',760,300);
  fire('touchstart',[sprint],[sprint]);
  fire('touchstart',[jump],[jump]);
  fire('touchend',[jump],[]);
  assert.deepEqual(calls,[['sprint',true],['sprint',false],['jump']]);
});
