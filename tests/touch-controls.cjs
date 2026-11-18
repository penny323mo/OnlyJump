const test = require('node:test');
const assert = require('node:assert/strict');
const {readFileSync} = require('node:fs');
const {runInNewContext} = require('node:vm');
const {join} = require('node:path');

// Replay iOS-style touch lists against the handlers shipped in the HTML shell.
// The test deliberately does not deliver pointer capture events.
function fixture() {
  const window = {ontouchstart:null};
  const handlers = new Map();
  window.addEventListener = (type,fn)=>handlers.set(type,fn);
  const nodes = {};
  for(const id of ['pad','jump','sprint','look']){
    nodes[id]={id,closest:()=>nodes[id],firstElementChild:{style:{}},
      getBoundingClientRect:()=>({left:0,top:0,width:100,height:100})};
  }
  const calls=[];
  const source=readFileSync(join(__dirname,'../web/controls.js'),'utf8');
  const reset=runInNewContext(source+'\nattachControls(send,()=>true)',{
    window, document:{getElementById:id=>nodes[id]}, innerWidth:844, innerHeight:390,
    send:(...args)=>calls.push(args)
  });
  const finger=(id,role,x,y)=>({identifier:id,target:nodes[role],clientX:x,clientY:y});
  const fire=(type,changed,live)=>handlers.get(type)({changedTouches:changed,touches:live,cancelable:true,preventDefault(){}});
  return {fire,finger,reset,calls,knob:nodes.pad.firstElementChild};
}

test('two fingers retain independent ownership through reversal, release and cancellation',()=>{
  const {fire,finger,calls,knob}=fixture();
  const right=finger(7,'pad',88,50), left=finger(7,'pad',12,50);
  const tap=finger(4,'jump',720,330);
  fire('touchstart',[right],[right]);
  fire('touchstart',[tap],[right,tap]);
  assert.deepEqual(calls,[['stick',1,0],['jump']]);
  fire('touchmove',[left],[left,tap]);
  fire('touchend',[tap],[left]);
  assert.deepEqual(calls.at(-1),['stick',-1,0]);
  fire('touchcancel',[left],[]);
  assert.deepEqual(calls.at(-1),['stick',0,0]);
  assert.equal(knob.style.transform,'');
});

test('missing finger and reset cannot replay a stale direction',()=>{
  const {fire,finger,reset,calls,knob}=fixture();
  const pad=finger(1,'pad',50,10), look=finger(2,'look',420,165);
  fire('touchstart',[pad],[pad]);
  fire('touchstart',[look],[look]);
  assert.deepEqual(calls.at(-1),['stick',0,0]);
  fire('touchstart',[pad],[pad,look]);
  reset();
  const before=calls.length;
  fire('touchmove',[pad],[pad]);
  assert.equal(calls.length,before);
  assert.equal(knob.style.transform,'');
});

test('look and sprint leave the active joystick contact intact',()=>{
  const {fire,finger,calls}=fixture();
  const pad=finger(1,'pad',50,10), look=finger(3,'look',400,100), run=finger(5,'sprint',580,250);
  fire('touchstart',[pad,look],[pad,look]);
  fire('touchstart',[run],[pad,look,run]);
  const moved=finger(3,'look',440,118);
  fire('touchmove',[moved],[pad,moved,run]);
  assert.deepEqual(calls.map(c=>c[0]),['stick','sprint','look']);
  assert(calls.at(-1)[1]>0 && calls.at(-1)[2]>0);
  fire('touchend',[pad],[moved,run]);
  assert.deepEqual(calls.at(-1),['stick',0,0]);
});
