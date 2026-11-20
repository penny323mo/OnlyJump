// The initiating contact owns one control until that contact ends. iOS can
// cancel one finger while another still controls movement or the camera.
function attachControls(send, isPlaying) {
  const pad = document.getElementById('pad');
  const knob = pad.firstElementChild;
  const owners = new Map();
  const active = new Map();
  const roles = '#padZone,#pad,#jump,#sprint,#look';
  // Safari can deliver input on the new display before its resize event.
  // Large viewport units stay fixed during browser toolbar transitions.
  const layoutSize=document.getElementById('layoutSize');
  let width=layoutSize.offsetWidth, height=layoutSize.offsetHeight;
  let viewWidth=window.innerWidth, viewHeight=window.innerHeight;
  function syncLayout() {
    viewWidth=window.innerWidth;
    viewHeight=window.innerHeight;
    const w=layoutSize.offsetWidth, h=layoutSize.offsetHeight;
    if (w===width && h===height) return;
    width=w;
    height=h;
    reset();
  }
  function syncBeforeInput() {
    if (window.innerWidth!==viewWidth || window.innerHeight!==viewHeight) syncLayout();
  }
  function restorePad() {
    pad.style.left = pad.style.top = '';
    delete pad.dataset.active;
    knob.style.transform = '';
  }
  function begin(id, target, x, y, touch) {
    if (!isPlaying()) return false;
    const hit = target.closest?.(roles)?.id;
    const leftLookHit = touch && hit === 'look' && x < viewWidth / 2;
    const role = hit === 'padZone' || leftLookHit ? 'pad' : hit;
    if (!role || active.has(role) || owners.has(id)) return false;
    const contact = {role,x,y};
    owners.set(id, contact);
    active.set(role,id);
    if (role === 'jump') send('jump');
    if (role === 'sprint') send('sprint',true);
    if (role === 'pad') {
      contact.originX=x; contact.originY=y;
      contact.travel=pad.getBoundingClientRect().width*.29;
      pad.style.left=x+'px'; pad.style.top=y+'px'; pad.dataset.active='true';
      send('stick',0,0);
    }
    return true;
  }
  function move(id,x,y) {
    const contact = owners.get(id);
    if (!contact) return false;
    if (contact.role === 'pad') {
      let dx = (x-contact.originX)/contact.travel;
      let dy = (y-contact.originY)/contact.travel;
      const radius = Math.hypot(dx,dy);
      if (radius < 0.11) dx = dy = 0;
      else { dx /= Math.max(1,radius); dy /= Math.max(1,radius); }
      knob.style.transform = 'translate('+dx*contact.travel+'px,'+dy*contact.travel+'px)';
      send('stick',dx,dy);
    } else if (contact.role === 'sprint' && !contact.jumped) {
      // In button-radius units the ellipse is a unit circle. Check the
      // whole swipe segment so coalesced events can still cross its edge.
      const r=document.getElementById('jump').getBoundingClientRect();
      if (!r.width || !r.height) return false;
      const rx=r.width/2, ry=r.height/2;
      const startX=(contact.x-r.left-rx)/rx, startY=(contact.y-r.top-ry)/ry;
      const dx=(x-contact.x)/rx, dy=(y-contact.y)/ry;
      const length2=dx*dx+dy*dy;
      const t=length2 ? Math.max(0,Math.min(1,-(startX*dx+startY*dy)/length2)) : 0;
      // A toolbar animation can move the button under a stationary finger.
      // Require the finger to enter the current button from outside.
      if (length2>0 && Math.hypot(startX,startY)>1 && Math.hypot(startX+t*dx,startY+t*dy)<=1) {
        contact.jumped=true;
        if (!active.has('jump')) send('jump');
      }
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
    if (contact.role==='pad') { restorePad(); send('stick',0,0); }
    if (contact.role==='sprint') send('sprint',false);
    return true;
  }
  const touchEvents = 'ontouchstart' in window;
  if (touchEvents) {
    for (const type of ['touchstart','touchmove','touchend','touchcancel']) {
      window.addEventListener(type,e=>{
        syncBeforeInput();
        // Retire a missing or reused finger before a new one claims its role.
        // Keep ending fingers long enough to process their final swipe segment.
        const keep=new Set(Array.from(e.touches,t=>'t'+t.identifier));
        for (const t of e.changedTouches) {
          const id='t'+t.identifier;
          if (type==='touchstart') keep.delete(id);
          else if (type==='touchend' || type==='touchcancel') keep.add(id);
        }
        for (const id of owners.keys()) if (id.startsWith('t') && !keep.has(id)) end(id);
        let used=false;
        const moving=type==='touchmove';
        if (moving || type==='touchend') {
          // One sample can move both thumbs or lift them together. Take the
          // jump against this sample's aim while its held controls still exist.
          const sprintId=active.get('sprint');
          let swipe;
          for (const t of e.changedTouches) {
            const id='t'+t.identifier;
            if (id===sprintId) swipe=t;
            else if (moving) used=move(id,t.clientX,t.clientY) || used;
          }
          if (swipe) used=move(sprintId,swipe.clientX,swipe.clientY) || used;
        }
        if (!moving) {
          for (const t of e.changedTouches) {
            const id='t'+t.identifier;
            const handled=type==='touchstart' ? begin(id,t.target,t.clientX,t.clientY,true) : end(id);
            used=handled || used;
          }
        }
        if (used && e.cancelable) e.preventDefault();
      },{capture:true,passive:false});
    }
  }
  window.addEventListener('pointerdown',e=>{
    if ((touchEvents && e.pointerType==='touch') || (e.button!==0 && e.button!==2)) return;
    syncBeforeInput();
    if (!begin('p'+e.pointerId,e.target,e.clientX,e.clientY,e.pointerType==='touch')) return;
    e.preventDefault();
    document.getElementById('canvas').focus({preventScroll:true});
    const target=e.target.closest(roles);
    try { target.setPointerCapture(e.pointerId); } catch { /* Window still receives release. */ }
  });
  window.addEventListener('pointermove',e=>{
    const id='p'+e.pointerId;
    if (!owners.has(id)) return;
    syncBeforeInput();
    if (e.buttons===0) end(id);
    else move(id,e.clientX,e.clientY);
  });
  for (const type of ['pointerup','pointercancel','lostpointercapture']) {
    window.addEventListener(type,e=>{
      const id='p'+e.pointerId;
      if (!owners.has(id)) return;
      syncBeforeInput();
      if(type==='pointerup' && owners.get(id)?.role==='sprint') move(id,e.clientX,e.clientY);
      end(id);
    },true);
  }
  document.getElementById('look').oncontextmenu=e=>e.preventDefault();
  function reset() {
    for (const id of Array.from(owners.keys())) end(id);
    restorePad();
  }
  window.addEventListener('resize',syncLayout);
  return reset;
}
