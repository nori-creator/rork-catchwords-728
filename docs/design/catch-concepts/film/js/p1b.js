// p1b.js — v6 scan: P1 (v5, unchanged) combined with the old iOS lock-on brackets (owner's choice: "枠あり（古いiOSの
// 動きのまま）"). The brackets are the old analysing screen's FocusBrackets as they were (git 9fca1bc^,
// Views/AnalyzingView.swift): four corners, #BFEFFF 2.5 pt, cyan glow (.shadow(Theme.cyan 0.8, radius 6)), arm =
// 22 % of the shorter side; each one appears at 1.25× and transparent and springs in (response 0.38, damping 0.62) with
// Haptics.selection(), the first 250 ms after the things are found and then every 380 ms; once locked it breathes
// (1.0 ↔ 1.02, ease in-out 1.1 s each way). The only difference: each box is a real thing in this photo — the bounding
// box of its on-device instance mask — not the same every time. When a bracket locks, P1's light runs round that thing.
// The bracket leaves when that thing's tag appears.
let OUTL = null;
async function loadOutlines() { OUTL = await (await fetch('masks/outlines.json')).json(); }
const SCAN_K = [0, 1, 3];                                 // what the device segments (largest first); the plant is named by the AI only
const scanRank = k => SCAN_K.indexOf(k);
const T_VIS = T_CAP + .3;                                // all instance masks in one Vision pass (~0.2–0.4 s on device)

// ---------- the old FocusBrackets timing ----------
function firstCross(resp, damp) { const w = 2 * Math.PI / resp, wd = w * Math.sqrt(1 - damp * damp); return (Math.PI - Math.atan(wd / (damp * w))) / wd; }
const LOCK0 = r => T_VIS + .25 + .38 * r;               // Task.sleep(i == 0 ? 250 : 380 ms), then withAnimation(.spring(0.38, 0.62)) { locked = i + 1 }
const CLICK = r => LOCK0(r) + firstCross(.38, .62);      // the corners reach the box (the click / haptic)
const P1_START = k => scanRank(k) < 0 ? 99 : CLICK(scanRank(k)) + .04;   // P1's light starts round the outline as the bracket locks
const P1_DONE = k => scanRank(k) < 0 ? T_VIS : P1_START(k) + .9;
const P1_NAME = k => Math.max(T_NAMES + .1 * k, P1_DONE(k));

// ---------- P1 (v5) ----------
const OUTP = {};
function outlineOf(id) {                                 // resampled every 4 px, starting at the top, clockwise on screen
  if (OUTP[id]) return OUTP[id];
  const raw = OUTL[id][0]; let pts = chaikin(raw, 3, true);
  for (let it = 0; it < 2; it++) { const m = pts.length, q = pts.map((_, i) => { let sx = 0, sy = 0; for (let d = -5; d <= 5; d++) { const r = pts[(i + d + m) % m]; sx += r[0]; sy += r[1]; } return [sx / 11, sy / 11]; }); pts = q; }
  let area = 0; for (let i = 0; i < pts.length; i++) { const [x0, y0] = pts[i], [x1, y1] = pts[(i + 1) % pts.length]; area += x0 * y1 - x1 * y0; }
  if (area < 0) pts = pts.reverse();
  let top = 0; pts.forEach((p, i) => { if (p[1] < pts[top][1]) top = i; });
  pts = resample([...pts.slice(top), ...pts.slice(0, top)], 4, true);
  let x0 = 1e9, y0 = 1e9, x1 = -1e9, y1 = -1e9; pts.forEach(([x, y]) => { x0 = Math.min(x0, x); y0 = Math.min(y0, y); x1 = Math.max(x1, x); y1 = Math.max(y1, y); });
  return OUTP[id] = { pts, n: pts.length, cx: (x0 + x1) / 2, cy: (y0 + y1) / 2, box: [x0, y0, x1, y1] };
}
// where the light is on the outline at time t (the sound follows it)
function headAt(k, t) { const O = outlineOf(TAGS[k].id), u = E.inOutSine(seg(t, P1_START(k), P1_START(k) + .62)); return O.pts[Math.min(O.n - 1, Math.floor(u * O.n))]; }
const GLOWC = document.createElement('canvas'); GLOWC.width = W; GLOWC.height = H; const gwx = GLOWC.getContext('2d');
function strokeRun(c, O, a, b, alphaAt, width, rgb) {
  c.lineCap = 'round'; c.lineJoin = 'round'; c.lineWidth = width;
  const step = 3;
  for (let i = a; i < b; i += step) {
    const al = alphaAt(i); if (al <= .01) continue;
    const p = O.pts[((i % O.n) + O.n) % O.n], q = O.pts[(((i + step) % O.n) + O.n) % O.n];
    c.strokeStyle = `rgba(${rgb},${Math.min(1, al)})`; c.beginPath(); c.moveTo(p[0], p[1]); c.lineTo(q[0], q[1]); c.stroke();
  }
}
function liftOf(k, t) {
  const s = P1_START(k), up = clamp(sp(t, s + .04, .42, .62), 0, 1.15), down = E.inOutCubic(seg(t, P1_NAME(k) + .1, P1_NAME(k) + .6));
  const settle = lerp(1, .55, E.inOutCubic(seg(t, s + .7, s + 1.2)));
  return t < s ? 0 : up * settle * (1 - down);
}
function p1Backdrop(t) {
  const dimT = E.outCubic(seg(t, T_VIS, T_VIS + .4)) * (1 - E.inOutCubic(seg(t, P1_NAME(3) + .2, P1_NAME(3) + .7)));
  photoBase(t, { bright: 1 - .2 * dimT, sat: 1 - .12 * dimT });
  [3, 1, 0].forEach(k => {
    const L = liftOf(k, t); if (L <= .001 && dimT <= .001) return;
    const tag = TAGS[k], M = MK[tag.id], C = cutOf(tag.id), O = outlineOf(tag.id), sc = 1 + .018 * L;
    bgx.save(); photoXform(bgx, t); bgx.translate(O.cx, O.cy); bgx.scale(sc, sc); bgx.translate(-O.cx, -O.cy);
    if (L > .001) { bgx.save(); bgx.globalAlpha = .38 * Math.min(1, L); bgx.filter = 'blur(16px)'; bgx.globalCompositeOperation = 'multiply'; bgx.translate(0, 12 * L); bgx.drawImage(SHAD(tag.id), M.x, M.y); bgx.restore(); }
    bgx.drawImage(C.c, M.x, M.y);
    bgx.restore();
  });
}
const SHC = {};
function SHAD(id) { if (SHC[id]) return SHC[id]; const M = MK[id], c = document.createElement('canvas'); c.width = M.w; c.height = M.h; const g = c.getContext('2d'); g.drawImage(M.c, 0, 0); g.globalCompositeOperation = 'source-in'; g.fillStyle = '#1a1f2a'; g.fillRect(0, 0, M.w, M.h); return SHC[id] = c; }
function p1Light(t) {
  gwx.clearRect(0, 0, W, H);
  const cores = [];
  TAGS.forEach((tag, k) => {
    const s = P1_START(k); if (t < s || scanRank(k) < 0) return;
    const O = outlineOf(tag.id), L = liftOf(k, t), sc = 1 + .018 * L, tn = P1_NAME(k);
    const fadeName = 1 - E.inOutCubic(seg(t, tn + .05, tn + .45)); if (fadeName <= 0) return;
    const run = E.inOutSine(seg(t, s, s + .62)), head = run * O.n, tail = O.n * .32;
    const pulse = Math.sin(Math.PI * seg(t, s + .55, s + .95)), rest = .16 + .07 * Math.sin(2 * Math.PI * (t - s) / 2.4 + k * 1.3) * seg(t, s + 1, s + 1.4);
    const base = (run >= 1 ? Math.max(rest, pulse * .95) : 0) * fadeName;
    const alphaAt = i => {
      const behind = head - i;
      let a = run < 1 ? (behind >= 0 ? Math.max(.22, Math.pow(1 - Math.min(1, behind / tail), 1.6)) : 0) : base;
      const tw = t - (s + 1.3 + k * .45); if (tw > 0 && run >= 1) { const ph = (tw % 2.6) / 1.1; if (ph < 1) { const hp = ph * O.n, d = ((hp - i) % O.n + O.n) % O.n; a = Math.max(a, .55 * Math.pow(1 - Math.min(1, d / (O.n * .18)), 2) * fadeName); } }
      return a * fadeName;
    };
    gwx.save(); photoXform(gwx, t); gwx.translate(O.cx, O.cy); gwx.scale(sc, sc); gwx.translate(-O.cx, -O.cy);
    strokeRun(gwx, O, 0, O.n, alphaAt, 18, '150,205,255');
    gwx.restore();
    cores.push({ O, sc, alphaAt, head: run < 1 ? O.pts[Math.min(O.n - 1, Math.floor(head))] : null });
  });
  ctx.save(); ctx.globalCompositeOperation = 'screen'; ctx.filter = 'blur(12px)'; ctx.drawImage(GLOWC, 0, 0); ctx.filter = 'none'; ctx.restore();
  cores.forEach(({ O, sc, alphaAt, head }) => {
    ctx.save(); photoXform(ctx, t); ctx.translate(O.cx, O.cy); ctx.scale(sc, sc); ctx.translate(-O.cx, -O.cy);
    ctx.globalCompositeOperation = 'lighter'; strokeRun(ctx, O, 0, O.n, i => alphaAt(i) * .8, 2.4, '255,255,255');
    if (head) { const g = ctx.createRadialGradient(head[0], head[1], 0, head[0], head[1], 30); g.addColorStop(0, 'rgba(255,255,255,1)'); g.addColorStop(.3, 'rgba(190,225,255,0.6)'); g.addColorStop(1, 'rgba(190,225,255,0)'); ctx.fillStyle = g; ctx.beginPath(); ctx.arc(head[0], head[1], 30, 0, Math.PI * 2); ctx.fill(); }
    ctx.restore();
  });
}
function p1Sheen(t) {
  TAGS.forEach((tag, k) => {
    if (scanRank(k) < 0) return;
    const u = seg(t, P1_START(k) + .3, P1_START(k) + .95); if (u <= 0 || u >= 1) return;
    const M = MK[tag.id], O = outlineOf(tag.id), sc = 1 + .018 * liftOf(k, t);
    tmx.save(); tmx.clearRect(M.x - 30, M.y - 30, M.w + 60, M.h + 60);
    tmx.drawImage(M.c, M.x, M.y); tmx.globalCompositeOperation = 'source-in';
    const L = M.w + M.h, p = M.x - M.h * .6 + E.inOutSine(u) * L * 1.1, g = tmx.createLinearGradient(p, M.y, p + M.h * .5, M.y + M.h * .5);
    g.addColorStop(0, 'rgba(255,255,255,0)'); g.addColorStop(.5, 'rgba(255,255,255,0.55)'); g.addColorStop(1, 'rgba(255,255,255,0)');
    tmx.fillStyle = g; tmx.fillRect(M.x, M.y, M.w, M.h); tmx.restore();
    ctx.save(); photoXform(ctx, t); ctx.translate(O.cx, O.cy); ctx.scale(sc, sc); ctx.translate(-O.cx, -O.cy);
    ctx.globalCompositeOperation = 'screen'; ctx.globalAlpha = Math.sin(Math.PI * u); ctx.drawImage(TMP, M.x - 30, M.y - 30, M.w + 60, M.h + 60, M.x - 30, M.y - 30, M.w + 60, M.h + 60); ctx.restore();
  });
}
function p1Tags(t) {
  TAGS.forEach((tag, k) => {
    const tn = P1_NAME(k); if (t < tn - .08) return;
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

// ---------- the old FocusBrackets, on each real thing ----------
const BR_LW = 2.5 * PT, BR_GLOW = 6 * PT;
function boxOf(k) {                                       // the thing's mask box (kept just inside the screen so all four corners show)
  const [x0, y0, x1, y1] = outlineOf(TAGS[k].id).box, e = BR_LW / 2 + 1;
  return [Math.max(e, x0), Math.max(e, y0), Math.min(W - e, x1), Math.min(H - e, y1)];
}
function bracketPath(c, x0, y0, x1, y1, arm) {
  c.beginPath();
  for (const [cx, cy, sx, sy] of [[x0, y0, 1, 1], [x1, y0, -1, 1], [x0, y1, 1, -1], [x1, y1, -1, -1]]) { c.moveTo(cx, cy + sy * arm); c.lineTo(cx, cy); c.lineTo(cx + sx * arm, cy); }
}
function brackets(t) {
  SCAN_K.forEach((k, r) => {
    const t0 = LOCK0(r); if (t < t0) return;
    const s = spring(t - t0, .38, .62), tn = P1_NAME(k);
    const breathe = .02 * (.5 - .5 * Math.cos(Math.PI * (t - t0) / 1.1));          // .easeInOut(1.1).repeatForever(autoreverses)
    const alpha = clamp(s) * (1 - seg(t, tn - .05, tn + .2));                       // opacity springs with the lock; leaves with the tag
    if (alpha <= 0) return;
    const sc = lerp(1.25, 1, s) * (1 + breathe), b = boxOf(k);
    const [px, py] = toScreen(t, (b[0] + b[2]) / 2, (b[1] + b[3]) / 2), ps = photoState(t).s;
    const w = (b[2] - b[0]) * ps, h = (b[3] - b[1]) * ps, arm = Math.min(w, h) * .22;
    ctx.save(); ctx.globalAlpha *= alpha; ctx.translate(px, py); ctx.scale(sc, sc);
    ctx.lineCap = 'round'; ctx.lineJoin = 'round'; ctx.lineWidth = BR_LW; ctx.strokeStyle = '#BFEFFF';
    ctx.shadowColor = 'rgba(100,224,255,0.8)'; ctx.shadowBlur = BR_GLOW;
    bracketPath(ctx, -w / 2, -h / 2, w / 2, h / 2, arm); ctx.stroke();
    ctx.restore();
  });
}
function toScreen(t, x, y) { const ps = photoState(t); return [W / 2 + ps.dx + (x - W / 2) * ps.s, H / 2 + ps.dy + (y - H / 2) * ps.s]; }

function scanCues() {
  return { vis: T_VIS, lock0: SCAN_K.map((_, r) => +LOCK0(r).toFixed(3)), click: SCAN_K.map((_, r) => +CLICK(r).toFixed(3)), scanIds: SCAN_K.map(k => TAGS[k].id),
    clickX: SCAN_K.map(k => { const b = boxOf(k); return Math.round((b[0] + b[2]) / 2); }),
    scans: SCAN_K.map(k => +P1_START(k).toFixed(3)), done: SCAN_K.map(k => +P1_DONE(k).toFixed(3)),
    headX: SCAN_K.map(k => Array.from({ length: 25 }, (_, i) => Math.round(headAt(k, P1_START(k) + .62 * i / 24)[0]))),
    names: T_NAMES, tags: TAGS.map((_, k) => +P1_NAME(k).toFixed(3)), tap: T_TAP };
}
// the scan scene (v5 P1 + the brackets), from the camera to the tap on the cup's tag
function scanScene(t) {
  p1Backdrop(t);
  makeBlur(); ctx.drawImage(BG, 0, 0);
  capFlash(t); camChrome(t);
  p1Sheen(t);
  p1Light(t);
  brackets(t);
  p1Tags(t);
  scanPills2(t, P1_DONE(3) - .2, Math.max(...TAGS.map((_, k) => P1_NAME(k))) + .5);
  tabBar({ sel: 2, t });
  scanEnd(t);
  statusBar(false); homeIndicator(false);
}
