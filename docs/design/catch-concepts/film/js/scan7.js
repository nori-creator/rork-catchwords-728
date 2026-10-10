// scan7.js — shared by the v7 scan proposals (W1–W4): from the shutter to the word tags.
// Owner (2026-10-10): the part from the shot to the tags must be redone from scratch, picture and sound, in several
// proposals; keep the idea of a blue light round the things' edges; the brackets may go; while the AI analyses, the
// iPhone's screen edge glows blue; design for the real wait (production: median 6.0 s, 90th percentile 11.5 s).
// Every proposal has the same three phases, so it never finishes early and then stands still:
//   1. found   (from 0.3 s after the shutter, on device): each thing's real outline appears in blue
//   2. waiting (until the names arrive, any length): a calm loop that keeps moving, with the screen edge glowing
//   3. names   (the AI answer): the loop resolves, the edge glow flares and fades, each tag rises (standard tags)
let OUTL = null;
async function loadOutlines() { OUTL = await (await fetch('masks/outlines.json')).json(); }
const SCAN_K = [0, 1, 3];                                 // what the device segments (largest first); the blurred plant is named by the AI only
const scanRank = k => SCAN_K.indexOf(k);
const T_VIS = T_CAP + .3;                                // all instance masks in one Vision pass
const LOOP = 2.4;                                        // the waiting loop's period (4 beats at 100 BPM; the sound uses the same grid)
const OUT_RGB = '72,168,255', CORE_RGB = '222,243,255';  // the outline's glow (the app's blue, lighter) and its core

// ---------- outlines ----------
const OUTP = {};
function outlineOf(id) {                                 // resampled every 4 px, starting at the top, clockwise on screen; per-point turning
  if (OUTP[id]) return OUTP[id];
  const raw = OUTL[id][0]; let pts = chaikin(raw, 3, true);
  for (let it = 0; it < 2; it++) { const m = pts.length, q = pts.map((_, i) => { let sx = 0, sy = 0; for (let d = -5; d <= 5; d++) { const r = pts[(i + d + m) % m]; sx += r[0]; sy += r[1]; } return [sx / 11, sy / 11]; }); pts = q; }
  let area = 0; for (let i = 0; i < pts.length; i++) { const [x0, y0] = pts[i], [x1, y1] = pts[(i + 1) % pts.length]; area += x0 * y1 - x1 * y0; }
  if (area < 0) pts = pts.reverse();
  let top = 0; pts.forEach((p, i) => { if (p[1] < pts[top][1]) top = i; });
  pts = resample([...pts.slice(top), ...pts.slice(0, top)], 4, true);
  const n = pts.length; let x0 = 1e9, y0 = 1e9, x1 = -1e9, y1 = -1e9; pts.forEach(([x, y]) => { x0 = Math.min(x0, x); y0 = Math.min(y0, y); x1 = Math.max(x1, x); y1 = Math.max(y1, y); });
  const turn = pts.map((p, i) => { const a = pts[(i - 3 + n) % n], b = pts[(i + 3) % n]; const a1 = Math.atan2(p[1] - a[1], p[0] - a[0]), a2 = Math.atan2(b[1] - p[1], b[0] - p[0]); let d = Math.abs(a2 - a1); if (d > Math.PI) d = 2 * Math.PI - d; return d; });
  return OUTP[id] = { pts, n, turn, cx: (x0 + x1) / 2, cy: (y0 + y1) / 2, box: [x0, y0, x1, y1] };
}
const objO = k => outlineOf(TAGS[k].id);
// glow + crisp core along an outline; alphaAt(i) → 0..1 (glow) — the core follows it. Drawn in photo space.
const GL7 = document.createElement('canvas'); GL7.width = W; GL7.height = H; const gl7 = GL7.getContext('2d');
let glowQueue = [];
function queueOutline(O, alphaAt, { scale = 1, width = 16, core = 2.6, coreMul = .85, rgb = OUT_RGB, crgb = CORE_RGB } = {}) { glowQueue.push({ O, alphaAt, scale, width, core, coreMul, rgb, crgb }); }
function runSegs(c, O, alphaAt, width, rgb, mul = 1) {
  c.lineCap = 'round'; c.lineJoin = 'round'; c.lineWidth = width;
  for (let i = 0; i < (O.open ? O.n - 1 : O.n); i += 2) {
    const al = alphaAt(i) * mul; if (al <= .01) continue;
    const p = O.pts[i], q = O.pts[O.open ? Math.min(O.n - 1, i + 2) : (i + 2) % O.n];
    c.strokeStyle = `rgba(${rgb},${Math.min(1, al)})`; c.beginPath(); c.moveTo(p[0], p[1]); c.lineTo(q[0], q[1]); c.stroke();
  }
}
function flushOutlines(t) {
  if (!glowQueue.length) return;
  gl7.clearRect(0, 0, W, H);
  glowQueue.forEach(({ O, alphaAt, scale, width, rgb }) => { gl7.save(); photoXform(gl7, t); gl7.translate(O.cx, O.cy); gl7.scale(scale, scale); gl7.translate(-O.cx, -O.cy); runSegs(gl7, O, alphaAt, width, rgb); gl7.restore(); });
  ctx.save(); ctx.globalCompositeOperation = 'screen'; ctx.filter = 'blur(10px)'; ctx.drawImage(GL7, 0, 0); ctx.filter = 'none'; ctx.drawImage(GL7, 0, 0); ctx.restore();
  glowQueue.forEach(({ O, alphaAt, scale, core, coreMul, crgb }) => { ctx.save(); photoXform(ctx, t); ctx.translate(O.cx, O.cy); ctx.scale(scale, scale); ctx.translate(-O.cx, -O.cy); ctx.globalCompositeOperation = 'lighter'; runSegs(ctx, O, alphaAt, core, crgb, coreMul); ctx.restore(); });
  glowQueue = [];
}
// an open line of light (a filament, a pen's path in the air): points every few px, alphaAt(i) per point
function queueLine(pts, alphaAt, opts = {}) { queueOutline({ pts, n: pts.length, cx: W / 2, cy: H / 2, open: true }, alphaAt, opts); }
function bezPts(a, c, b, n = 48) { const out = []; for (let i = 0; i <= n; i++) out.push(bez2(a, c, b, i / n)); return out; }
function glowDot(x, y, r, a, rgb = '160,215,255') {     // a point of light (a pen tip, a pulse)
  if (a <= .01) return; ctx.save(); ctx.globalCompositeOperation = 'lighter';
  const g = ctx.createRadialGradient(x, y, 0, x, y, r); g.addColorStop(0, `rgba(255,255,255,${a})`); g.addColorStop(.28, `rgba(${rgb},${.6 * a})`); g.addColorStop(1, `rgba(${rgb},0)`);
  ctx.fillStyle = g; ctx.beginPath(); ctx.arc(x, y, r, 0, Math.PI * 2); ctx.fill(); ctx.restore();
}
function toScreen(t, x, y) { const ps = photoState(t); return [W / 2 + ps.dx + (x - W / 2) * ps.s, H / 2 + ps.dy + (y - H / 2) * ps.s]; }

// ---------- the photo while the AI analyses: a little darker so the blue reads ----------
const dimOf = t => E.outCubic(seg(t, T_CAP + .1, T_CAP + .6)) * (1 - E.inOutCubic(seg(t, T_NAMES + .25, T_NAMES + .85)));
function photo7(t, { blur = 0, extraDim = 0 } = {}) { const d = dimOf(t); photoBase(t, { blur, bright: 1 - .2 * d - extraDim, sat: 1 - .15 * d }); }

// ---------- the screen edge while the AI analyses (owner's request): the display's own rounded edge glows blue ----------
// Like Siri's edge light, in the app's blues: two bands of colour flowing round the edge in opposite directions,
// a soft wide glow, a brighter thin line at the very edge. It lights at the shutter, breathes on the loop's beat while
// the AI works, flares once when the names arrive and fades. `hits` add light where something reaches the edge.
const DISPLAY_R = 55 * PT;                                // iPhone 15/16 Pro display corner radius ≈ 55 pt
const EG = document.createElement('canvas'); EG.width = W / 2; EG.height = H / 2; const egx = EG.getContext('2d');
let PERIM = null;
function perimeter() {                                    // points round the rounded display edge (half-res coordinates), with arc length
  if (PERIM) return PERIM;
  const w = W / 2, h = H / 2, r = DISPLAY_R / 2, pts = [];
  const seg2 = (x0, y0, x1, y1, n) => { for (let i = 0; i < n; i++) pts.push([lerp(x0, x1, i / n), lerp(y0, y1, i / n)]); };
  const arc = (cx, cy, a0, n) => { for (let i = 0; i < n; i++) { const a = a0 + (i / n) * Math.PI / 2; pts.push([cx + Math.cos(a) * r, cy + Math.sin(a) * r]); } };
  seg2(r, 0, w - r, 0, 60); arc(w - r, r, -Math.PI / 2, 14); seg2(w, r, w, h - r, 140); arc(w - r, h - r, 0, 14); seg2(w - r, h, r, h, 60); arc(r, h - r, Math.PI / 2, 14); seg2(0, h - r, 0, r, 140); arc(r, r, Math.PI, 14);
  return PERIM = pts;
}
function edgePath(c, inset) { const r = DISPLAY_R / 2; c.beginPath(); c.roundRect(inset, inset, W / 2 - 2 * inset, H / 2 - 2 * inset, Math.max(0, r - inset)); }
function edgeLevel(t) {
  const on = E.outCubic(seg(t, T_CAP + .08, T_CAP + .75)), off = 1 - E.inOutCubic(seg(t, T_NAMES + .15, T_NAMES + .8));
  const breathe = .86 + .14 * Math.sin(2 * Math.PI * (t - T_CAP) / LOOP - Math.PI / 2);
  const flare = Math.sin(Math.PI * seg(t, T_NAMES - .03, T_NAMES + .4));
  return { a: on * off * breathe, flare: flare * on, on: on * off };
}
function edgeGlow(t, { hits = null, boost = 0 } = {}) {
  const { a, flare } = edgeLevel(t), A = a * (1 + boost) + .9 * flare; if (A <= .01) return;
  const w = W / 2, h = H / 2; egx.setTransform(1, 0, 0, 1, 0, 0); egx.clearRect(0, 0, w, h); egx.globalCompositeOperation = 'lighter';
  const band = (rot, stops, lw, blur, alpha) => {
    const g = egx.createConicGradient(rot, w / 2, h / 2); stops.forEach(([o, c]) => g.addColorStop(o, c));
    egx.save(); egx.globalAlpha = alpha; egx.strokeStyle = g; egx.lineWidth = lw; egx.filter = blur ? `blur(${blur}px)` : 'none'; edgePath(egx, 0); egx.stroke(); egx.restore();
  };
  const s1 = [[0, 'rgba(0,96,224,0.15)'], [.1, 'rgba(0,131,255,1)'], [.2, 'rgba(100,224,255,1)'], [.28, 'rgba(0,131,255,0.35)'], [.45, 'rgba(42,155,255,0.9)'], [.55, 'rgba(0,96,224,0.25)'], [.7, 'rgba(100,224,255,0.95)'], [.82, 'rgba(0,131,255,0.5)'], [1, 'rgba(0,96,224,0.15)']];
  const s2 = [[0, 'rgba(120,140,255,0.0)'], [.18, 'rgba(110,130,255,0.7)'], [.32, 'rgba(0,131,255,0.0)'], [.6, 'rgba(160,230,255,0.75)'], [.76, 'rgba(0,131,255,0.0)'], [1, 'rgba(120,140,255,0.0)']];
  const r1 = (t - T_CAP) * .55, r2 = -(t - T_CAP) * .37 + 1.7;
  band(r1, s1, 64, 16, .55 * A); band(r2, s2, 48, 14, .5 * A);           // the soft wide glow, flowing
  band(r1, s1, 16, 4, .85 * A); band(r2, s2, 12, 3, .6 * A);             // the bright band near the edge
  band(r1, s1.map(([o, c]) => [o, c.replace(/[\d.]+\)$/, '1)')]), 3, 0, .55 * A);   // the line at the very edge
  if (hits && hits.length) {                                             // light where something reaches the edge
    const P = perimeter(); egx.save(); egx.filter = 'blur(8px)'; egx.lineCap = 'round';
    for (let i = 0; i < P.length; i++) {
      let v = 0; for (const f of hits) v = Math.max(v, f(P[i][0] * 2, P[i][1] * 2)); if (v <= .02) continue;
      const q = P[(i + 1) % P.length]; egx.strokeStyle = `rgba(150,220,255,${Math.min(1, v) * Math.max(.4, A)})`; egx.lineWidth = 30; egx.beginPath(); egx.moveTo(P[i][0], P[i][1]); egx.lineTo(q[0], q[1]); egx.stroke();
    }
    egx.restore();
  }
  ctx.save(); ctx.globalCompositeOperation = 'screen'; ctx.imageSmoothingQuality = 'high'; ctx.drawImage(EG, 0, 0, W, H); ctx.restore();
}

// ---------- the standard tags (as v5/v6): each rises from its pin when both its outline and its name are in ----------
function tags7(t, TAG) {
  TAGS.forEach((tag, k) => {
    const tn = TAG(k); if (t < tn - .08) return;
    const pop = E.outBack(seg(t, tn - .08, tn + .14), 2.4);
    ctx.save(); ctx.translate(tag.p[0], tag.p[1]); ctx.scale(pop, pop); ctx.translate(-tag.p[0], -tag.p[1]); tagAnchor(tag, t, 1, E.outCubic(seg(t, tn - .02, tn + .16))); ctx.restore();
    if (scanRank(k) < 0) { const ru = seg(t, tn - .1, tn + .5); if (ru > 0 && ru < 1) { ctx.save(); ctx.globalAlpha = (1 - ru) * .8; ctx.strokeStyle = '#fff'; ctx.lineWidth = 3; ctx.beginPath(); ctx.arc(tag.p[0], tag.p[1], 14 + 90 * E.outCubic(ru), 0, Math.PI * 2); ctx.stroke(); ctx.restore(); } }
    const u = seg(t, tn, tn + .32), s = clamp(sp(t, tn, .42, .7), 0, 1.1), bottom = tag.p[1] - 30;
    if (u <= 0) return;
    ctx.save(); ctx.globalAlpha *= E.outCubic(clamp(u * 1.6)); if (u < 1) ctx.filter = `blur(${(1 - E.outCubic(u)) * 9}px)`;
    const k2 = lerp(.86, 1, s); ctx.translate(tag.p[0], bottom); ctx.scale(k2, k2); ctx.translate(-tag.p[0], -bottom); ctx.translate(0, (1 - E.outCubic(u)) * 16);
    drawTag(tag, t, { reveal: seg(t, tn + .06, tn + .5), press: tag.id === 'cup' ? cupTagPress(t) : 0 });
    ctx.restore();
    if (NEW_WORD[tag.id]) newBadge(tag, t, tn + .38);
  });
}
// a proposal = { found(k): [start, end], draw(t) } → the shared frame around it
function scan7Frame(t, P) {
  P.backdrop ? P.backdrop(t) : photo7(t);
  makeBlur(); ctx.drawImage(BG, 0, 0);
  capFlash(t); camChrome(t);
  P.draw(t);
  flushOutlines(t);
  if (P.over) P.over(t);
  tags7(t, P.TAG);
  scanPills2(t, P.scanned, Math.max(...TAGS.map((_, k) => P.TAG(k))) + .5);
  tabBar({ sel: 2, t });
  scanEnd(t);
  edgeGlow(t, P.edge ? P.edge(t) : {});                  // above the app, like the system's own edge light
  statusBar(false); homeIndicator(false);
}
const restA = (t, tn) => 1 - E.inOutCubic(seg(t, tn + .05, tn + .5));       // an outline leaves as its tag arrives
