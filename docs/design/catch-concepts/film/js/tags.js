// tags.js — the word tags on the photo, outline utilities and the clean rim light (used by A when the cut is made).

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
const SHAPES = {};
function shapeOf(id) {
  if (SHAPES[id]) return SHAPES[id];
  const raw = CONT[id]; const sm = chaikin(raw.length > 300 ? raw.filter((_, i) => i % 3 === 0) : raw, 2, true);
  let top = 0; sm.forEach((p, i) => { if (p[1] < sm[top][1]) top = i; });
  return SHAPES[id] = resample([...sm.slice(top), ...sm.slice(0, top)], 7, true);
}
function centroidOf(id) {
  const p = shapeOf(id); let a = 0, cx = 0, cy = 0;
  for (let i = 0; i < p.length; i++) { const [x0, y0] = p[i], [x1, y1] = p[(i + 1) % p.length]; const c = x0 * y1 - x1 * y0; a += c; cx += (x0 + x1) * c; cy += (y0 + y1) * c; }
  return [cx / (3 * a), cy / (3 * a)];
}
// clean light over a shape: a bright line that runs the whole outline fast, then fades (A's rim light on the cut)
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

// ---------- tags ----------
const TAGS = [
  { id: 'cup', zh: '珍珠奶茶', ja: 'タピオカミルクティー', p: [540, 1560], more: 2 },
  { id: 'scooter', zh: '機車', ja: 'バイク', p: [228, 800], more: 1 },
  { id: 'plant', zh: '盆栽', ja: '鉢植え', p: [700, 600], more: 0 },
  { id: 'sign', zh: '黑板', ja: '黒板', p: [836, 1080], more: 0 },
];
const TAG_H = 112;
const TAG_DOT = 13;                                       // the app's tag: a blue dot before the word (CandidatePickerView)
function tagGeom(tag) {
  const w1 = measure(tag.zh, 800, 46, FONT_TC) + TAG_DOT * 2 + 14, w2 = measure(tag.ja, 500, 28);
  const hint = tag.more ? measure(`ほか${tag.more}`, 700, 24) + 40 : 0;
  const w = Math.max(w1, w2) + 64 + (hint ? hint + 10 : 0);
  return { w, h: TAG_H, x: tag.p[0] - w / 2, y: tag.p[1] - 30 - TAG_H, hint };
}
function tagAnchor(tag, t, a, stem = 1) {
  if (a <= 0) return;
  ctx.save(); ctx.globalAlpha *= a;
  ctx.shadowColor = 'rgba(0,0,0,0.35)'; ctx.shadowBlur = 10; ctx.fillStyle = '#fff'; ctx.beginPath(); ctx.arc(tag.p[0], tag.p[1], 11, 0, Math.PI * 2); ctx.fill();
  if (stem > 0) { ctx.shadowBlur = 0; ctx.strokeStyle = 'rgba(255,255,255,0.9)'; ctx.lineWidth = 3; ctx.beginPath(); ctx.moveTo(tag.p[0], tag.p[1] - 12); ctx.lineTo(tag.p[0], tag.p[1] - 12 - 18 * stem); ctx.stroke(); }
  ctx.restore();
}
// the tag: a white glass capsule (the app's tag), blue dot + the word, its meaning under it, 「ほかN ›」 when there are
// other ways to say it. `reveal` 0..1 drives the text (characters rise in, left to right); w/h/cx/cy may be animated.
function drawTag(tag, t, { alpha = 1, press = 0, done = 0, reveal = 1, w = null, h = null, cx = null, cy = null, flash = 0, textAlpha = null } = {}) {
  const ta = textAlpha == null ? alpha : textAlpha;
  if (alpha <= 0 && (ta <= 0 || reveal <= 0)) return;
  const g = tagGeom(tag), gw = w == null ? g.w : w, gh = h == null ? g.h : h;
  const X = cx == null ? tag.p[0] : cx, Y = cy == null ? g.y + g.h / 2 : cy;
  const x = X - gw / 2, y = Y - gh / 2, r = gh / 2;
  const s = 1 - press * .07;
  ctx.save(); ctx.translate(X, Y + gh / 2); ctx.scale(s, s); ctx.translate(-X, -(Y + gh / 2));
  if (done > 0) { ctx.save(); ctx.globalAlpha *= alpha; ctx.shadowColor = 'rgba(0,0,0,0.2)'; ctx.shadowBlur = 30; ctx.shadowOffsetY = 10; rr(x, y, gw, gh, r); ctx.fillStyle = `rgba(0,169,92,${.92 * done})`; ctx.fill(); ctx.restore(); }
  if (alpha > 0) glass(x, y, gw, gh, r, { alpha: alpha * (1 - done), tint: 'rgba(255,255,255,0.84)', shadow: .2 });
  // the moment the drop sets into the tag: a bright rim runs once round the capsule
  if (flash > 0 && flash < 1) {
    ctx.save(); ctx.globalAlpha *= Math.max(alpha, ta) * Math.sin(flash * Math.PI); rr(x + 1.5, y + 1.5, gw - 3, gh - 3, r - 1.5);
    const gg = ctx.createLinearGradient(x - gw + flash * gw * 3, y, x + flash * gw * 3, y + gh); gg.addColorStop(0, 'rgba(255,255,255,0)'); gg.addColorStop(.5, 'rgba(255,255,255,1)'); gg.addColorStop(1, 'rgba(255,255,255,0)');
    ctx.strokeStyle = gg; ctx.lineWidth = 4; ctx.stroke(); ctx.restore();
  }
  if (reveal > 0 && ta > 0) {
    ctx.save(); ctx.globalAlpha *= ta; ctx.beginPath(); ctx.roundRect(x, y, gw, gh, r); ctx.clip();
    const body = g.w - 64 - (g.hint ? g.hint + 10 : 0), tx = X - g.w / 2 + 32 + body / 2;     // text block centre
    const size = 46, cw = measure(tag.zh, 800, size, FONT_TC), wordW = cw + TAG_DOT * 2 + 14;
    let xx = tx - wordW / 2;
    // the blue dot (the app's tag), then the characters
    const dp = E.outBack(clamp(reveal * 3), 2.2);
    if (dp > 0) { ctx.save(); ctx.fillStyle = done > .5 ? '#fff' : BLUE2; ctx.beginPath(); ctx.arc(xx + TAG_DOT, Y - 16, TAG_DOT * dp, 0, Math.PI * 2); ctx.fill(); ctx.restore(); }
    xx += TAG_DOT * 2 + 14;
    const chars = [...tag.zh], n = chars.length;
    chars.forEach((ch, i) => {
      const p = E.outBack(clamp((reveal * (n + 2) - i) / 2.2), 1.6), wch = measure(ch, 800, size, FONT_TC);
      if (p > 0) text(ch, xx + wch / 2, Y + (1 - p) * 26, { w: 800, size, f: FONT_TC, color: done > .5 ? '#fff' : INK, alpha: clamp(p * 1.4) });
      xx += wch;
    });
    text(tag.ja, tx, Y + 38, { w: 500, size: 28, color: done > .5 ? 'rgba(255,255,255,0.9)' : MUTED, alpha: E.outCubic(seg(reveal, .45, 1)) });
    if (g.hint) {
      const ha = E.outCubic(seg(reveal, .6, 1)), hx = X + g.w / 2 - 24 - g.hint, hy = Y - 22;
      ctx.save(); ctx.globalAlpha *= ha; ctx.fillStyle = done > .5 ? 'rgba(255,255,255,0.22)' : 'rgba(0,131,255,0.12)'; rr(hx, hy, g.hint, 44, 22); ctx.fill();
      text(`ほか${tag.more}`, hx + g.hint / 2 - 7, hy + 31, { w: 700, size: 24, color: done > .5 ? '#fff' : BLUE });
      icon('chev', hx + g.hint - 16, hy + 22, 22, done > .5 ? '#fff' : BLUE, 9); ctx.restore();
    }
    ctx.restore();
  }
  ctx.restore();
}
