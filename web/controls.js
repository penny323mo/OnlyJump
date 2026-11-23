// Two free scene touches can pinch. Buttons and the joystick keep their
// contacts even if Safari cancels or reuses another finger.
function attachControls(send, isPlaying) {
  const pad = document.getElementById('pad');
  const knob = pad.firstElementChild;
  const owners = new Map();
  const active = new Map();
  const touchOrbitThreshold = 4; // CSS pixels to start or resume a drag
  let pinch = null;
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
  function pinchSpan(a,b) {
    return Math.max(8,Math.hypot(a.x-b.x,a.y-b.y));
  }
  function updatePinch() {
    if (!pinch) return;
    const span=pinchSpan(pinch.a,pinch.b);
    if (Math.abs(span-pinch.span)<1) return;
    const scale=span/pinch.span;
    pinch.span=span;
    send('zoom',scale);
  }
  function begin(id, target, x, y, touch) {
    if (!isPlaying() || owners.has(id)) return false;
    const hit = target.closest?.(roles)?.id;
    const leftLookHit = touch && hit === 'look' && x < viewWidth / 2;
    const role = hit === 'padZone' || leftLookHit ? 'pad' : hit;
    if (!role) return false;
    const contact = {id,role,x,y,originX:x,originY:y,touch};
    if (role==='pad') {
      const current=owners.get(active.get('pad'));
      // A first finger in empty space floats the stick before we know if
      // it will steer or pinch. Keep its home circle available to the thumb.
      const bounds=current ? current.homeBounds : pad.getBoundingClientRect();
      const {left,top,width,height}=bounds;
      // The visible stick belongs to the thumb from touchdown. Elsewhere
      // the floating pad can still become one half of a two-finger pinch.
      const atHome=Math.hypot(x-left-width/2,y-top-height/2)<=width/2;
      if (touch && current?.touch && !current.ownsStick && atHome) {
        current.role='free';
        active.delete('pad');
      }
      contact.ownsStick=atHome && !active.has('pad');
      contact.homeBounds=bounds;
      contact.travel=width*.29;
    }
    if (touch && (role==='pad' || role==='look')) {
      if (!pinch && !contact.ownsStick) {
        for (const other of owners.values()) {
          if (!other.touch || !(other.role==='look' || other.role==='free' || (other.role==='pad' && !other.ownsStick))) continue;
          if (other.orbit && other.role==='look' && role==='pad' && !active.has('pad')) continue;
          if (other.role==='pad') restorePad();
          active.delete(other.role);
          contact.role=other.role='pinch';
          owners.set(id,contact);
          pinch={a:other,b:contact,span:pinchSpan(other,contact)};
          return true;
        }
      }
      // Even with the stick held, two more fingers can zoom on the left.
      if (active.has(role) || (pinch && role==='look')) contact.role='free';
    }
    if (active.has(contact.role)) return false;
    owners.set(id, contact);
    if (contact.role==='free') return true;
    active.set(role,id);
    if (role === 'jump') send('jump');
    if (role === 'sprint') send('sprint',true);
    if (role === 'pad') {
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
      else { contact.ownsStick=true; dx /= Math.max(1,radius); dy /= Math.max(1,radius); }
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
      const starting = contact.touch && contact.orbit!=='dragging';
      const dx=x-(starting ? contact.originX : contact.x);
      const dy=y-(starting ? contact.originY : contact.y);
      // Let a second finger join a pinch despite normal fingertip drift.
      // Once a drag starts, send even small adjustments at full precision.
      if (!starting || Math.hypot(dx,dy)>=touchOrbitThreshold) {
        contact.orbit='dragging';
        const span=Math.max(240,Math.min(innerWidth,innerHeight));
        send('look',dx/span,dy/span);
      }
    }
    contact.x=x; contact.y=y;
    return true;
  }
  function end(id, lifted=false) {
    const contact=owners.get(id);
    if (!contact) return false;
    owners.delete(id);
    active.delete(contact.role);
    if (contact.role==='pinch') {
      const remaining=contact===pinch.a ? pinch.b : pinch.a;
      pinch=null;
      if (lifted && remaining.orbit && !active.has('look')) {
        // Return control only to the thumb that was already turning the view.
        // A fresh drag starts here, so pinch travel never rotates the camera.
        remaining.role='look';
        remaining.orbit='resuming';
        remaining.originX=remaining.x;
        remaining.originY=remaining.y;
        active.set('look',remaining.id);
      } else {
        remaining.role='free';
        remaining.orbit=null;
      }
    }
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
          if (pinch && type==='touchend') {
            for (const t of e.touches) {
              const id='t'+t.identifier;
              if (owners.get(id)?.role==='pinch') move(id,t.clientX,t.clientY);
            }
          }
          for (const t of e.changedTouches) {
            const id='t'+t.identifier;
            if (id===sprintId) swipe=t;
            else if (moving || owners.get(id)?.role==='pinch') used=move(id,t.clientX,t.clientY) || used;
          }
          updatePinch();
          if (swipe) used=move(sprintId,swipe.clientX,swipe.clientY) || used;
        }
        if (!moving) {
          for (const t of e.changedTouches) {
            const id='t'+t.identifier;
            const handled=type==='touchstart' ? begin(id,t.target,t.clientX,t.clientY,true) : end(id,type==='touchend');
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
    else {
      move(id,e.clientX,e.clientY);
      const pair=pinch;
      // Pointer Events report each finger separately. Sample the pair once
      // per frame so moving both in parallel does not briefly zoom the lens.
      if (pair && !pair.queued) {
        pair.queued=true;
        window.requestAnimationFrame(()=>{
          pair.queued=false;
          if (pinch===pair) updatePinch();
        });
      }
    }
  });
  for (const type of ['pointerup','pointercancel','lostpointercapture']) {
    window.addEventListener(type,e=>{
      const id='p'+e.pointerId;
      if (!owners.has(id)) return;
      syncBeforeInput();
      if(type==='pointerup' && ['sprint','pinch'].includes(owners.get(id)?.role)) {
        move(id,e.clientX,e.clientY);
        updatePinch();
      }
      end(id,type==='pointerup');
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
