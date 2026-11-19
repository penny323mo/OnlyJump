const test = require('node:test');
const assert = require('node:assert/strict');
const {readFileSync} = require('node:fs');
const {runInNewContext} = require('node:vm');
const {join} = require('node:path');

function fixture(jumpBounds={left:720,top:260,width:80,height:80}) {
  const window = {ontouchstart:null};
  const handlers = new Map();
  window.addEventListener = (type,fn)=>handlers.set(type,fn);
  const nodes = {};
  for(const id of ['padZone','pad','sprint','jump','look']){
    nodes[id]={id,style:{},dataset:{},closest:()=>nodes[id],firstElementChild:{style:{}},
      getBoundingClientRect:()=>id==='jump'?jumpBounds:{width:136,height:136}};
  }
  const calls=[];
  const source=readFileSync(join(__dirname,'../web/controls.js'),'utf8');
  const reset=runInNewContext(source+'\nattachControls(send,()=>true)',{
    window,document:{getElementById:id=>nodes[id]},innerWidth:844,innerHeight:390,
    send:(...args)=>calls.push(args)
  });
  const finger=(identifier,role,clientX,clientY)=>({identifier,target:nodes[role],clientX,clientY});
  const fire=(type,changedTouches,touches)=>handlers.get(type)({changedTouches,touches,cancelable:true,preventDefault(){}});
  return {fire,finger,reset,calls,pad:nodes.pad};
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

test('direct jump, sprint-only hold and cancelled swipe are distinct',()=>{
  const {fire,finger,calls}=fixture();
  const jump=finger(1,'jump',760,300),run=finger(3,'sprint',760,200);
  fire('touchstart',[jump],[jump]);fire('touchend',[jump],[]);
  fire('touchstart',[run],[run]);fire('touchend',[run],[]);
  fire('touchstart',[run],[run]);fire('touchcancel',[finger(3,'sprint',760,310)],[]);
  assert.deepEqual(calls,[['jump'],['sprint',true],['sprint',false],['sprint',true],['sprint',false]]);
});

test('a fast slide can finish over the jump button without a final move event',()=>{
  const {fire,finger,calls}=fixture();
  const run=finger(1,'sprint',760,200);
  fire('touchstart',[run],[run]);fire('touchend',[finger(1,'sprint',760,355)],[]);
  assert.deepEqual(calls,[['sprint',true],['jump'],['sprint',false]]);
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
  fire('touchstart',[joy],[joy]);fire('touchstart',[sprint],[sprint]);
  assert.deepEqual(calls.at(-1),['stick',0,0]);
  reset();
  const before=calls.length;
  fire('touchmove',[joy],[joy]);
  assert.equal(calls.length,before);
  assert.equal(pad.style.top,'');
  assert.deepEqual(calls.at(-1),['sprint',false]);
});

test('resizing a foldable viewport releases held sprint and movement until a fresh contact',()=>{
  const {fire,finger,calls,pad}=fixture();
  const joy=finger(1,'padZone',60,290),run=finger(2,'sprint',760,205);
  fire('touchstart',[joy,run],[joy,run]);
  fire('touchmove',[finger(1,'padZone',18,290)],[joy,run]);
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
