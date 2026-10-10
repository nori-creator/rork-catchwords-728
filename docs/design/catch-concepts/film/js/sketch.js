// sketch.js — the wait design shared by every concept: 下書き → 清書 (draft, then ink).
// While the AI works, what is already known is drawn as a live pencil draft (shapes first — the on-device masks are
// ready in well under a second — then the places where the names will go). When the answer arrives, the draft is
// inked over in one quick sweep and the clean UI takes its exact place.

// ---------- polyline utilities ----------
function chaikin(pts, it = 2, closed = true) {
  let p = pts;
  for (let k = 0; k < it; k++) {
    const q = []; const n = p.length;
    for (let i = 0; i < (closed ? n : n - 1); i++) {
      const a = p[i], b = p[(i + 1) % n];
      q.push([a[0] * .75 + b[0] * .25, a[1] * .75 + b[1] * .25], [a[0] * .25 + b[0] * .75, a[1] * .25 + b[1] * .75]);
    }
    if (!closed) { q.unshift(p[0]); q.push(p[n - 1]); }
    p = q;
  }
  return p;
}
function resample(pts, step = 8, closed = true) {
  const src = closed ? [...pts, pts[0]] : pts; const out = [src[0].slice()]; let carry = 0;
  for (let i = 0; i < src.length - 1; i++) {
    const a = src[i], b = src[i + 1], L = Math.hypot(b[0] - a[0], b[1] - a[1]); let d = step - carry;
    while (d <= L) { const u = d / L; out.push([a[0] + (b[0] - a[0]) * u, a[1] + (b[1] - a[1]) * u]); d += step; }
    carry = L - (d - step);
  }
  return out;
}
const SHAPES = {};   // id -> resampled, smoothed outline (screen px)
function shapeOf(id) {
  if (SHAPES[id]) return SHAPES[id];
  const raw = CONT[id]; const sm = chaikin(raw.length > 300 ? raw.filter((_, i) => i % 3 === 0) : raw, 2, true);
  // start the stroke at the top of the shape (where a hand would start)
  let top = 0; sm.forEach((p, i) => { if (p[1] < sm[top][1]) top = i; });
  const rot = [...sm.slice(top), ...sm.slice(0, top)];
  return SHAPES[id] = resample(rot, 7, true);
}

// ---------- the pencil ----------
// boil: the line is redrawn slightly differently 12 times a second, like a hand-drawn animation's "line boil"
function boiled(pts, t, seed, amp) {
  const F = Math.floor(t * 12);
  return pts.map((p, i) => [p[0] + vnoise(i / 9, seed + F * 3.1) * amp, p[1] + vnoise(i / 9, seed + 57 + F * 3.1) * amp]);
}
// draw a pencil stroke along pts up to fraction p (0..1, may exceed 1 on closed shapes for the overshoot)
function pencil(pts, p, t, { seed = 1, amp = 3.2, color = '255,255,255', width = 4.5, alpha = 1, glow = true, tip = true, passes = 2, closed = true, c = ctx } = {}) {
  if (p <= 0 || alpha <= 0) return;
  const n = pts.length, m = Math.min(Math.floor((n - 1) * p), closed ? Math.floor((n - 1) * 1.07) : n - 1);
  if (m < 1) return;
  const at = j => pts[j % n];
  c.save(); c.lineCap = 'round'; c.lineJoin = 'round';
  for (let k = 0; k < passes; k++) {
    const q = boiled(Array.from({ length: m + 1 }, (_, j) => at(j)), t, seed + k * 19, amp * (k ? 1.35 : 1));
    const path = () => { c.beginPath(); q.forEach((v, j) => j ? c.lineTo(v[0], v[1]) : c.moveTo(v[0], v[1])); };
    if (glow && k === 0) {
      path(); c.strokeStyle = `rgba(0,0,0,${.22 * alpha})`; c.lineWidth = width + 2; c.save(); c.translate(1.5, 2); c.stroke(); c.restore();
      path(); c.strokeStyle = `rgba(${color},${.16 * alpha})`; c.lineWidth = width * 4; c.filter = 'blur(6px)'; c.stroke(); c.filter = 'none';
    }
    // pressure: the line is a little thinner where the pencil is moving fast (the end of the stroke)
    path(); c.strokeStyle = `rgba(${color},${(k ? .38 : .92) * alpha})`; c.lineWidth = k ? width * .6 : width; c.stroke();
  }
  if (tip && p < 1.07) {
    const h = at(m), g = c.createRadialGradient(h[0], h[1], 0, h[0], h[1], 26);
    g.addColorStop(0, `rgba(255,255,255,${alpha})`); g.addColorStop(.35, `rgba(${color},${.5 * alpha})`); g.addColorStop(1, `rgba(${color},0)`);
    c.fillStyle = g; c.beginPath(); c.arc(h[0], h[1], 26, 0, Math.PI * 2); c.fill();
  }
  c.restore();
}
// clean ink over a shape: a bright line that runs the whole outline fast, then fades (the 清書 moment)
function inkSweep(pts, p, fade, { color = '255,255,255', width = 5, c = ctx } = {}) {
  if (p <= 0 || fade <= 0) return;
  const n = pts.length, m = Math.floor((n - 1) * clamp(p));
  if (m < 1) return;
  c.save(); c.globalAlpha *= fade; c.lineCap = 'round'; c.lineJoin = 'round'; c.globalCompositeOperation = 'lighter';
  const path = () => { c.beginPath(); for (let j = 0; j <= m; j++) { const q = pts[j]; j ? c.lineTo(q[0], q[1]) : c.moveTo(q[0], q[1]); } };
  path(); c.strokeStyle = `rgba(140,200,255,0.35)`; c.lineWidth = 22; c.filter = 'blur(10px)'; c.stroke(); c.filter = 'none';
  path(); c.strokeStyle = `rgba(${color},0.95)`; c.lineWidth = width; c.stroke();
  c.restore();
}
// a scribble that "writes" left to right: loops of a cursive hand, continuously, with the tail fading out
function scribble(x, y, w, h, t, t0, { seed = 3, alpha = 1, color = '255,255,255', speed = 1.6, width = 3.5, c = ctx } = {}) {
  if (t < t0 || alpha <= 0) return;
  const N = 90, pts = [];
  for (let i = 0; i <= N; i++) {
    const u = i / N, ph = u * 7.5 * Math.PI + seed;
    pts.push([x + u * w + Math.cos(ph) * h * .28, y + Math.sin(ph) * h * .5 + vnoise(u * 6, seed) * h * .18]);
  }
  const head = ((t - t0) * speed) % 1.35;                 // the pen keeps writing; the line ahead of the tail stays
  const q = boiled(pts, t, seed, 1.6);
  c.save(); c.lineCap = 'round'; c.lineJoin = 'round';
  for (let i = 1; i <= N; i++) {
    const u = i / N; if (u > head) break;
    const age = head - u, a = alpha * clamp(1 - (age - .55) / .35) * .85;
    if (a <= 0) continue;
    c.strokeStyle = `rgba(${color},${a})`; c.lineWidth = width;
    c.beginPath(); c.moveTo(q[i - 1][0], q[i - 1][1]); c.lineTo(q[i][0], q[i][1]); c.stroke();
  }
  if (head <= 1) { const hp = q[Math.min(N, Math.floor(head * N))]; c.fillStyle = `rgba(255,255,255,${alpha})`; c.beginPath(); c.arc(hp[0], hp[1], width * 1.4, 0, Math.PI * 2); c.fill(); }
  c.restore();
}
// rounded-rect outline as points (for sketching a pill)
function pillPts(x, y, w, h, r, step = 7) {
  const pts = []; const arc = (cx, cy, a0, a1) => { const n = Math.max(3, Math.ceil(Math.abs(a1 - a0) * r / step)); for (let i = 0; i <= n; i++) { const a = a0 + (a1 - a0) * i / n; pts.push([cx + Math.cos(a) * r, cy + Math.sin(a) * r]); } };
  arc(x + w - r, y + r, -Math.PI / 2, 0); arc(x + w - r, y + h - r, 0, Math.PI / 2); arc(x + r, y + h - r, Math.PI / 2, Math.PI); arc(x + r, y + r, Math.PI, Math.PI * 1.5);
  // start at the top-middle like a hand would
  const k = Math.floor(pts.length * .875); return resample([...pts.slice(k), ...pts.slice(0, k)], step, true);
}

// ---------- tags (the clean result) ----------
const TAGS = [
  { id: 'cup', zh: '珍珠奶茶', ja: 'タピオカミルクティー', p: [540, 1560], more: 2, order: 0 },
  { id: 'scooter', zh: '機車', ja: 'バイク', p: [228, 800], more: 1, order: 1 },
  { id: 'plant', zh: '盆栽', ja: '鉢植え', p: [700, 600], more: 0, order: 2 },
  { id: 'sign', zh: '黑板', ja: '黒板', p: [836, 1080], more: 0, order: 3 },
];
const TAG_H = 112;
function tagGeom(tag) {
  const w1 = measure(tag.zh, 700, 46, FONT_TC), w2 = measure(tag.ja, 500, 28);
  const hint = tag.more ? measure(`ほか${tag.more}`, 700, 24) + 40 : 0;
  const w = Math.max(w1, w2) + 60 + (hint ? hint + 8 : 0);
  return { w, h: TAG_H, x: tag.p[0] - w / 2, y: tag.p[1] - 30 - TAG_H, hint };
}
const OUTLINE_T = id => T_CAP + .55 + .2 * TAGS.find(g => g.id === id).order;   // when its shape starts to be drawn
const NAME_T = tag => T_NAMES + .085 * tag.order;                                   // when its name is inked in
// the anchor dot + stem
function tagAnchor(tag, t, a) {
  if (a <= 0) return;
  ctx.save(); ctx.globalAlpha *= a;
  ctx.shadowColor = 'rgba(0,0,0,0.35)'; ctx.shadowBlur = 10; ctx.fillStyle = '#fff'; ctx.beginPath(); ctx.arc(tag.p[0], tag.p[1], 11, 0, Math.PI * 2); ctx.fill();
  ctx.shadowBlur = 0; ctx.strokeStyle = 'rgba(255,255,255,0.9)'; ctx.lineWidth = 3; ctx.beginPath(); ctx.moveTo(tag.p[0], tag.p[1] - 12); ctx.lineTo(tag.p[0], tag.p[1] - 30); ctx.stroke();
  ctx.restore();
}
// clean glass tag. `ink` 0..1 = how far the 清書 has gone (outline sweep, then fill, then text reveal left→right)
function drawTag(tag, t, { alpha = 1, press = 0, done = 0, ink = 1 } = {}) {
  if (alpha <= 0 || ink <= 0) return;
  const g = tagGeom(tag);
  const fill = E.outCubic(seg(ink, .25, .7)), reveal = E.outCubic(seg(ink, .35, 1));
  const s = (lerp(.94, 1, fill)) * (1 - press * .07);
  ctx.save(); ctx.translate(tag.p[0], tag.p[1] - 30); ctx.scale(s, s); ctx.translate(-tag.p[0], -(tag.p[1] - 30));
  if (done > 0) { ctx.save(); ctx.globalAlpha *= alpha; ctx.shadowColor = 'rgba(0,0,0,0.2)'; ctx.shadowBlur = 30; ctx.shadowOffsetY = 10; rr(g.x, g.y, g.w, g.h, 34); ctx.fillStyle = `rgba(0,169,92,${.92 * done})`; ctx.fill(); ctx.restore(); }
  glass(g.x, g.y, g.w, g.h, 34, { alpha: alpha * fill * (1 - done), tint: 'rgba(255,255,255,0.72)' });
  // text revealed by a soft mask moving left → right (the pen finishing the line)
  ctx.save(); ctx.globalAlpha *= alpha;
  const mx = g.x + 10 + (g.w + 60) * reveal;
  ctx.beginPath(); ctx.rect(g.x - 10, g.y - 10, mx - g.x + 10, g.h + 20); ctx.clip();
  const tx = g.x + 30 + (g.w - 60 - (g.hint ? g.hint + 8 : 0)) / 2;
  text(tag.zh, tx, g.y + 56, { w: 700, size: 46, f: FONT_TC, color: done > .5 ? '#fff' : INK });
  text(tag.ja, tx, g.y + 94, { w: 500, size: 28, color: done > .5 ? 'rgba(255,255,255,0.9)' : MUTED });
  if (g.hint) { // 「ほかn」: other ways to say it (opens the picker)
    const hx = g.x + g.w - 22 - g.hint, hy = g.y + 34;
    ctx.fillStyle = done > .5 ? 'rgba(255,255,255,0.22)' : 'rgba(0,131,255,0.12)'; rr(hx, hy, g.hint, 44, 22); ctx.fill();
    text(`ほか${tag.more}`, hx + g.hint / 2 - 7, hy + 31, { w: 700, size: 24, color: done > .5 ? '#fff' : BLUE });
    icon('chev', hx + g.hint - 16, hy + 22, 22, done > .5 ? '#fff' : BLUE, 9);
  }
  ctx.restore();
  ctx.restore();
}

// ---------- the analysis (shared opening) ----------
// shapes: 0.55 s after the shutter the on-device masks are drawn, one by one (largest first)
// drafts: each found thing gets a pencilled pill where its name will go, with a pen still writing in it
// names: at T_NAMES the answer arrives and every draft is inked over, in quick succession
function analysis(t, { cupAlpha = 1, otherAlpha = 1, cupPress = 0, cupDone = 0, hideCup = 0 } = {}) {
  if (t < T_CAP + .4) return;
  const cleanup = seg(t, T_NAMES + .05, T_NAMES + .5);          // outlines leave once the names are in
  for (const tag of TAGS) {
    const isCup = tag.id === 'cup', a = (isCup ? cupAlpha * (1 - hideCup) : otherAlpha);
    if (a <= 0) continue;
    const pts = shapeOf(tag.id), t0 = OUTLINE_T(tag.id), dur = .5 + pts.length / 2600;
    const draw = E.inOutSine(seg(t, t0, t0 + dur)) * 1.07;
    const tn = NAME_T(tag);
    // pencil outline (live until the name comes), then the clean sweep that inks it and fades
    if (t < tn + .5) pencil(pts, draw, t, { seed: tag.order * 7 + 1, alpha: a * .85 * (1 - cleanup) });
    inkSweep(pts, E.outCubic(seg(t, tn - .02, tn + .16)), a * (1 - seg(t, tn + .16, tn + .5)));
    // draft pill where the name will be
    const g = tagGeom(tag), dw = Math.max(260, g.w * .82), dx = tag.p[0] - dw / 2;
    const tp = t0 + dur * .85, drawP = E.inOutSine(seg(t, tp, tp + .38));
    const inkP = seg(t, tn, tn + .34);
    tagAnchor(tag, t, a * seg(t, tp, tp + .12));
    if (drawP > 0 && inkP < 1) {
      const pp = pillPts(dx, g.y, dw, g.h, 34);
      const fade = a * (1 - E.inQuad(seg(inkP, .2, .7)));
      pencil(pp, drawP * 1.04, t, { seed: tag.order * 11 + 4, amp: 2.4, width: 3.6, alpha: fade, glow: true, passes: 2 });
      // the pen writing the name and the meaning (two lines), until the answer arrives
      const wr = fade * seg(t, tp + .3, tp + .45);
      scribble(dx + 34, g.y + 46, dw - 68, 26, t, tp + .3, { seed: tag.order * 5 + 2, alpha: wr, width: 3.6 });
      scribble(dx + 54, g.y + 86, (dw - 108) * .8, 14, t, tp + .5, { seed: tag.order * 5 + 9, alpha: wr * .8, width: 2.6, speed: 2 });
    }
    // the clean tag
    if (t >= tn) drawTag(tag, t, { alpha: a, press: isCup ? cupPress : 0, done: isCup ? cupDone : 0, ink: inkP });
  }
}
// status messages during the analysis (honest, specific, with what is already known)
function analysisPills(t, tHide) {
  const nFound = TAGS.filter(g => t > OUTLINE_T(g.id) + .4).length;
  if (t < T_CAP + 1.45) topPill(t, T_CAP + .15, Math.min(tHide, T_NAMES), 'AIが写真を見ています', { shimmer: true });
  else topPill(t, T_CAP + .15, Math.min(tHide, T_NAMES), `${Math.max(nFound, 1)}つ見つけました・名前を調べています`, { shimmer: true, prev: 'AIが写真を見ています', tSwap: T_CAP + 1.45 });
  topPill(t, T_NAMES + .3, tHide, '覚えたいことばをタップ', { icon: 'sparkles' });
}
