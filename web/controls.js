// The initiating contact owns one control until that contact ends. iOS can
// cancel one finger while another still controls movement or the camera.
function attachControls(send, isPlaying) {
  const pad = document.getElementById('pad');
  const knob = pad.firstElementChild;
  const owners = new Map();
  const active = new Map();
  function begin(id, target, x, y) {
    if (!isPlaying()) return false;
    const role = target.closest?.('#pad,#jump,#sprint,#look')?.id;
    if (!role || active.has(role) || owners.has(id)) return false;
    owners.set(id, {role,x,y});
    active.set(role,id);
    if (role === 'jump') send('jump');
    if (role === 'sprint') send('sprint');
    if (role === 'pad') move(id,x,y);
    return true;
  }
  function move(id,x,y) {
    const contact = owners.get(id);
    if (!contact) return false;
    if (contact.role === 'pad') {
      const r = pad.getBoundingClientRect();
      let dx = (x-r.left-r.width/2)/(r.width*0.34);
      let dy = (y-r.top-r.height/2)/(r.height*0.34);
      const radius = Math.hypot(dx,dy);
      if (radius < 0.12) dx = dy = 0;
      else { dx /= Math.max(1,radius); dy /= Math.max(1,radius); }
      knob.style.transform = 'translate('+dx*26+'px,'+dy*26+'px)';
      send('stick',dx,dy);
    } else if (contact.role === 'look') {
      const span = Math.max(240,Math.min(innerWidth,innerHeight));
      send('look',(x-contact.x)/span,(y-contact.y)/span);
    }
    contact.x=x; contact.y=y;
    return true;
  }
  function end(id) {
    const contact=owners.get(id);
    if (!contact) return false;
    owners.delete(id);
    active.delete(contact.role);
    if (contact.role==='pad') { knob.style.transform=''; send('stick',0,0); }
    return true;
  }
  const touchEvents = 'ontouchstart' in window;
  if (touchEvents) {
    for (const type of ['touchstart','touchmove','touchend','touchcancel']) {
      window.addEventListener(type,e=>{
        let used=false;
        for (const t of e.changedTouches) {
          const id='t'+t.identifier;
          let handled;
          if (type==='touchstart') handled=begin(id,t.target,t.clientX,t.clientY);
          else if (type==='touchmove') handled=move(id,t.clientX,t.clientY);
          else handled=end(id);
          used=handled || used;
        }
        const live=new Set(Array.from(e.touches,t=>'t'+t.identifier));
        for (const id of owners.keys()) if (id.startsWith('t') && !live.has(id)) end(id);
        if (used && e.cancelable) e.preventDefault();
      },{capture:true,passive:false});
    }
  }
  window.addEventListener('pointerdown',e=>{
    if ((touchEvents && e.pointerType==='touch') || (e.button!==0 && e.button!==2)) return;
    if (!begin('p'+e.pointerId,e.target,e.clientX,e.clientY)) return;
    e.preventDefault();
    document.getElementById('canvas').focus({preventScroll:true});
    const target=e.target.closest('#pad,#jump,#sprint,#look');
    try { target.setPointerCapture(e.pointerId); } catch { /* Window still receives release. */ }
  });
  window.addEventListener('pointermove',e=>{
    const id='p'+e.pointerId;
    if (e.buttons===0) end(id);
    else move(id,e.clientX,e.clientY);
  });
  for (const type of ['pointerup','pointercancel','lostpointercapture']) {
    window.addEventListener(type,e=>end('p'+e.pointerId),true);
  }
  document.getElementById('look').oncontextmenu=e=>e.preventDefault();
  return function reset() {
    owners.clear(); active.clear();
    knob.style.transform='';
  };
}
