// CatchWords — catch → dex concept films, v3. Every frame is a pure function of time t (seconds) so the capture
// script can step through it at exactly 60 fps. core.js: maths, assets, text + zhuyin, iOS chrome, glass.
const W = 1080, H = 2340, FPS = 60;
const cv = document.getElementById('c'), ctx = cv.getContext('2d');
const Q = new URLSearchParams(location.search);
let CONCEPT = Q.get('c') || 'A';

// ---------- maths ----------
const clamp = (x, a = 0, b = 1) => Math.min(b, Math.max(a, x));
const lerp = (a, b, t) => a + (b - a) * t;
const seg = (t, a, b) => clamp((t - a) / (b - a));
const E = {
  outCubic: x => 1 - Math.pow(1 - x, 3), inCubic: x => x * x * x,
  inOutCubic: x => x < .5 ? 4 * x * x * x : 1 - Math.pow(-2 * x + 2, 3) / 2,
  outQuint: x => 1 - Math.pow(1 - x, 5), outExpo: x => x >= 1 ? 1 : 1 - Math.pow(2, -10 * x),
  inOutSine: x => -(Math.cos(Math.PI * x) - 1) / 2, inQuad: x => x * x, outQuad: x => 1 - (1 - x) * (1 - x),
  inOutQuart: x => x < .5 ? 8 * x ** 4 : 1 - Math.pow(-2 * x + 2, 4) / 2, outQuart: x => 1 - Math.pow(1 - x, 4),
  outBack: (x, s = 1.7) => 1 + (s + 1) * Math.pow(x - 1, 3) + s * Math.pow(x - 1, 2),
};
// CSS cubic-bezier(x1,y1,x2,y2) as a function of x (Newton on x(t))
function bezierEase(x1, y1, x2, y2) {
  const cx = 3 * x1, bx = 3 * (x2 - x1) - cx, ax = 1 - cx - bx, cy = 3 * y1, by = 3 * (y2 - y1) - cy, ay = 1 - cy - by;
  const X = t => ((ax * t + bx) * t + cx) * t, Y = t => ((ay * t + by) * t + cy) * t, dX = t => (3 * ax * t + 2 * bx) * t + cx;
  return x => { if (x <= 0) return 0; if (x >= 1) return 1; let t = x; for (let i = 0; i < 8; i++) { const d = dX(t); if (Math.abs(d) < 1e-6) break; t -= (X(t) - x) / d; } return Y(clamp(t)); };
}
const fillInEase = bezierEase(.3, 1.5, .5, 1);       // the app's DexFillIn curve
// damped spring step response (SwiftUI-style response / dampingFraction)
function spring(t, response = .5, damping = .8) {
  if (t <= 0) return 0;
  const w = 2 * Math.PI / response, z = damping;
  if (z >= 1) return 1 - (1 + w * t) * Math.exp(-w * t);
  const wd = w * Math.sqrt(1 - z * z);
  return 1 - Math.exp(-z * w * t) * (Math.cos(wd * t) + (z * w / wd) * Math.sin(wd * t));
}
const sp = (t, t0, r, d) => spring(t - t0, r, d);
function rnd(i) { const x = Math.sin(i * 127.1 + 311.7) * 43758.5453; return x - Math.floor(x); }
function vnoise(x, seed = 0) { const i = Math.floor(x), f = x - i, u = f * f * (3 - 2 * f); return lerp(rnd(i + seed * 101.3), rnd(i + 1 + seed * 101.3), u) * 2 - 1; }
function bez2(p0, p1, p2, u) { const v = 1 - u; return [v * v * p0[0] + 2 * v * u * p1[0] + u * u * p2[0], v * v * p0[1] + 2 * v * u * p1[1] + u * u * p2[1]]; }

// ---------- assets ----------
const A = {}; let M, CONT, PEEL = null, PH = {};
const img = src => new Promise((res, rej) => { const i = new Image(); i.onload = () => res(i); i.onerror = () => rej(src); i.src = src; });
const DEX_IMAGES = ['coffee', 'soymilk', 'douhua', 'xlb', 'umbrella', 'pcake', 'cup', 'oolong', 'juice', 'cola', 'wintermelon', 'chickencutlet',
  'lurourice', 'mangoice', 'coconut', 'fan', 'ricecooker', 'remote', 'tissue', 'keys', 'mug', 'aircon', 'pomelo', 'mango', 'banana',
  'succulent', 'stool', 'slippers', 'bikebell', 'lantern'];
async function load() {
  M = await (await fetch('assets/meta.json')).json();
  CONT = await (await fetch('assets/contours.json')).json();
  PH = await (await fetch('assets/phosphor.json')).json();
  const list = { photo: 'assets/photo_1080.jpg', cut: 'assets/cup_cut.png', shadow: 'assets/cup_shadow.png',
    b4: 'assets/cup_b4.png', b8: 'assets/cup_b8.png', b12: 'assets/cup_b12.png', b16: 'assets/cup_b16.png', b20: 'assets/cup_b20.png', b24: 'assets/cup_b24.png' };
  for (const k of DEX_IMAGES) { list['d_' + k] = `assets/dex/${k}.png`; list['ds_' + k] = `assets/dex/${k}_sil.png`; }
  await Promise.all(Object.entries(list).map(async ([k, v]) => A[k] = await img(v)));
  for (const n of ['burst', 'twinkle', 'ripple']) A['L_' + n] = await (await fetch(`lottie/${n}.json`)).json();
  try { // Blender peel frames (concept B)
    PEEL = await (await fetch('blender/peel_full/peel.json')).json();
    PEEL.img = await Promise.all(PEEL.frames.map(f => img(`blender/peel_full/peel_${String(f.i).padStart(3, '0')}.png`)));
  } catch (e) { PEEL = null; }
  for (const w of ['500', '700', '900']) await document.fonts.load(`${w} 40px "Noto Sans TC"`);
  for (const w of ['400', '500', '600', '700', '800']) await document.fonts.load(`${w} 40px "Noto Sans JP"`);
  for (const w of ['500', '600', '700', '800']) await document.fonts.load(`${w} 40px Inter`);
  await document.fonts.ready;
  prepLottie(); prepPhosphor();
}
const LP = {};
function prepLottie() {
  for (const n of ['burst', 'twinkle', 'ripple']) {
    const d = A['L_' + n], c = document.createElement('canvas'); c.width = d.w; c.height = d.h;
    const holder = document.createElement('div'); holder.style.cssText = `position:absolute;left:-9999px;width:${d.w}px;height:${d.h}px`;
    document.body.appendChild(holder);
    const anim = lottie.loadAnimation({ container: holder, renderer: 'canvas', loop: false, autoplay: false, animationData: JSON.parse(JSON.stringify(d)),
      rendererSettings: { context: c.getContext('2d'), clearCanvas: true, preserveAspectRatio: 'xMidYMid meet' } });
    LP[n] = { anim, c, d };
  }
}
function drawLottie(n, t, t0, cx, cy, size, alpha = 1, c = ctx) {
  const L = LP[n], f = (t - t0) * FPS; if (f < 0 || f > L.d.op) return;
  L.anim.goToAndStop(Math.min(f, L.d.op - 1), true);
  c.save(); c.globalAlpha *= alpha; c.drawImage(L.c, cx - size / 2, cy - size / 2, size, size); c.restore();
}
const PHP = {};
function prepPhosphor() { for (const [k, ds] of Object.entries(PH)) PHP[k] = ds.map(d => new Path2D(d)); }

// ---------- scene constants ----------
const cupCenter = () => [M.cup.tx + M.cup.tw / 2, M.cup.ty + M.cup.th / 2 + 6];
const FONT_JP = '"Noto Sans JP", Inter, sans-serif', FONT_TC = '"Noto Sans TC", "Noto Sans JP", sans-serif', FONT_UI = 'Inter, "Noto Sans JP", sans-serif';
const FONT_EMOJI = '"Noto Color Emoji"';
const BLUE = '#0083FF', BLUE2 = '#2A9BFF', INK = '#0B121A', MUTED = '#5C646F', BG_APP = '#F9FCFF';
const PT = 2.75;                                         // px per iOS point in this 1080-wide frame

// shared timeline (seconds). The AI analysis takes 3.0 s here (design target median 2.5 s; QA: usually under 8 s).
// the AI wait comes from real data (web app, last 7 days, funnel 'candidates_shown': median 6.0 s, 90th percentile 11.5 s);
// ?ai=11.5 renders the slow case
const T_PRESS = .62, T_CAP = .72, T_ANALYSIS = parseFloat(Q.get('ai') || '6.0'), T_NAMES = T_CAP + T_ANALYSIS, T_TAP = Math.max(T_NAMES + 1.25, parseFloat(Q.get('tapmin') || '0')), C0 = T_TAP + .10;   // tapmin: a film may hold the tap until its last tag is in

// ---------- drawing helpers ----------
function rr(x, y, w, h, r, c = ctx) { c.beginPath(); c.roundRect(x, y, w, h, r); }
function font(w, s, f = FONT_JP, c = ctx) { c.font = `${w} ${s}px ${f}`; }
function text(s, x, y, { w = 500, size = 40, f = FONT_JP, color = INK, align = 'center', base = 'alphabetic', alpha = 1, ls = 0, c = ctx } = {}) {
  if (alpha <= 0) return;
  c.save(); c.globalAlpha *= alpha; font(w, size, f, c); c.fillStyle = color; c.textAlign = align; c.textBaseline = base;
  if (ls) c.letterSpacing = ls + 'px';
  c.fillText(s, x, y); c.restore();
}
function measure(s, w, size, f = FONT_JP, ls = 0) { ctx.save(); font(w, size, f); if (ls) ctx.letterSpacing = ls + 'px'; const m = ctx.measureText(s).width; ctx.restore(); return m; }
// wrap Japanese text by characters into lines of max width
function wrapJP(s, w, size, maxW, f = FONT_JP) {
  const out = []; let line = '';
  for (const ch of s) { const t = line + ch; if (measure(t, w, size, f) > maxW && line) { out.push(line); line = ch; } else line = t; }
  if (line) out.push(line); return out;
}

// ---------- zhuyin ----------
// Z('珍奶', 'ㄓㄣ ㄋㄞˇ') -> units; punctuation gets no reading; '˙' (neutral tone) is placed above the column.
function Z(h, zy = '') {
  const syl = zy.trim() ? zy.trim().split(/\s+/) : []; let k = 0; const out = [];
  for (const ch of h) {
    if (/[，。、！？：「」\s]/.test(ch)) { out.push({ h: ch, z: '', tone: '', punct: true }); continue; }
    let s = syl[k++] || ''; let neutral = false, tone = '';
    if (s.startsWith('˙')) { neutral = true; s = s.slice(1); }
    const last = s.slice(-1); if ('ˊˇˋ'.includes(last)) { tone = last; s = s.slice(0, -1); }
    out.push({ h: ch, z: s, tone, neutral });
  }
  return out;
}
function zyCell(size) { const zs = size * .31; return { zs, cell: size + zs * 1.2, punct: size * .62 }; }
function zyWidth(units, size) { const { zs, cell, punct } = zyCell(size); return units.reduce((a, u) => a + (u.punct ? punct : cell), 0) - zs * .2; }
// draw a zhuyin word; per-character reveal when t/t0 given (stagger + rise + blur)
function zyDraw(units, x, y, size, { t = 99, t0 = 0, color = INK, zcolor = MUTED, stagger = .05, dur = .32, alpha = 1, align = 'center', w = 700, blur = true, c = ctx } = {}) {
  const { zs, cell, punct } = zyCell(size), total = zyWidth(units, size);
  let cx = align === 'center' ? x - total / 2 : align === 'right' ? x - total : x;
  units.forEach((u, i) => {
    const adv = u.punct ? punct : cell;
    const p = E.outCubic(seg(t, t0 + i * stagger, t0 + i * stagger + dur)); if (p <= 0 || alpha <= 0) { cx += adv; return; }
    c.save(); c.globalAlpha *= alpha * p; c.translate(0, (1 - p) * size * .22);
    if (blur && p < 1) c.filter = `blur(${(1 - p) * 10}px)`;
    text(u.h, cx + (u.punct ? size * .3 : size / 2), y, { w, size, f: FONT_TC, color, c });
    if (!u.punct && u.z) {
      const zx = cx + size + zs * .62, n = [...u.z].length, top = y - size * .42 - (n * zs * 1.02) / 2;
      [...u.z].forEach((z, j) => text(z, zx, top + (j + 1) * zs * 1.02, { w: 500, size: zs, f: FONT_TC, color: zcolor, c }));
      if (u.tone) text(u.tone, zx + zs * .62, top + zs * 1.02 * (n - .35), { w: 700, size: zs * .9, f: FONT_TC, color: zcolor, c });
      if (u.neutral) text('˙', zx, top - zs * .05, { w: 700, size: zs * .9, f: FONT_TC, color: zcolor, c });
    }
    c.restore(); cx += adv;
  });
  return total;
}

// ---------- backdrop + glass ----------
const BG = document.createElement('canvas'); BG.width = W; BG.height = H; const bgx = BG.getContext('2d');
const BL = document.createElement('canvas'); BL.width = W / 4; BL.height = H / 4; const blx = BL.getContext('2d');
function makeBlur(src = BG) { blx.clearRect(0, 0, BL.width, BL.height); blx.filter = 'blur(6px)'; blx.drawImage(src, -8, -8, BL.width + 16, BL.height + 16); blx.filter = 'none'; }
function glass(x, y, w, h, r, { tint = 'rgba(255,255,255,0.58)', dark = false, alpha = 1, shadow = .16, c = ctx } = {}) {
  if (alpha <= 0) return;
  c.save(); c.globalAlpha *= alpha;
  if (shadow) { c.save(); c.shadowColor = `rgba(0,0,0,${shadow})`; c.shadowBlur = 40; c.shadowOffsetY = 12; rr(x, y, w, h, r, c); c.fillStyle = dark ? 'rgba(20,24,32,0.4)' : 'rgba(255,255,255,0.2)'; c.fill(); c.restore(); }
  c.save(); rr(x, y, w, h, r, c); c.clip(); c.drawImage(BL, 0, 0, W, H);
  c.fillStyle = dark ? 'rgba(18,22,30,0.42)' : tint; c.fillRect(x, y, w, h);
  const g = c.createLinearGradient(0, y, 0, y + h); g.addColorStop(0, dark ? 'rgba(255,255,255,0.10)' : 'rgba(255,255,255,0.45)'); g.addColorStop(.55, 'rgba(255,255,255,0)');
  c.fillStyle = g; c.fillRect(x, y, w, h); c.restore();
  rr(x + 1, y + 1, w - 2, h - 2, r - 1, c); c.lineWidth = 2; c.strokeStyle = dark ? 'rgba(255,255,255,0.18)' : 'rgba(255,255,255,0.85)'; c.stroke();
  c.restore();
}

// ---------- iOS chrome ----------
function statusBar(dark = false) {
  const col = dark ? '#000' : '#fff';
  text('9:41', 150, 98, { w: 600, size: 52, f: FONT_UI, color: col });
  ctx.save(); ctx.fillStyle = col; ctx.strokeStyle = col;
  for (let i = 0; i < 4; i++) { rr(780 + i * 20, 92 - 12 - i * 8, 13, 12 + i * 8, 3); ctx.fill(); }
  ctx.lineWidth = 7; ctx.lineCap = 'round';
  for (let i = 0; i < 3; i++) { ctx.beginPath(); ctx.arc(890, 96, 10 + i * 13, Math.PI * 1.25, Math.PI * 1.75); ctx.stroke(); }
  ctx.globalAlpha = .4; rr(935, 66, 76, 36, 11); ctx.lineWidth = 3; ctx.stroke(); rr(1015, 78, 6, 13, 2); ctx.fill(); ctx.globalAlpha = 1;
  rr(940, 71, 62, 26, 7); ctx.fill(); ctx.restore();
  ctx.fillStyle = '#000'; rr(W / 2 - 189, 33, 378, 111, 56); ctx.fill();
}
function homeIndicator(dark = false) { ctx.fillStyle = dark ? 'rgba(0,0,0,0.85)' : 'rgba(255,255,255,0.92)'; rr(W / 2 - 201, H - 30, 402, 15, 8); ctx.fill(); }

const TAB_Y = H - 72 - 186, TAB_H = 186, TAB_X = 54, TAB_W = W - 108;
const TABS = [['house', 'ホーム'], ['book', '図鑑'], ['camera', 'カメラ'], ['sparkles', '復習'], ['gear', '設定']];
function tabCenter(i) { return [TAB_X + TAB_W / 10 * (2 * i + 1), TAB_Y + 72]; }
function icon(name, x, y, s, color, lw = 7, c = ctx) {
  c.save(); c.translate(x, y); c.scale(s / 72, s / 72); c.strokeStyle = color; c.fillStyle = color; c.lineWidth = lw; c.lineJoin = 'round'; c.lineCap = 'round';
  c.beginPath();
  if (name === 'house') { c.moveTo(-28, -2); c.lineTo(0, -28); c.lineTo(28, -2); c.moveTo(-20, -8); c.lineTo(-20, 26); c.lineTo(20, 26); c.lineTo(20, -8); c.moveTo(-6, 26); c.lineTo(-6, 8); c.lineTo(6, 8); c.lineTo(6, 26); c.stroke(); }
  if (name === 'book') { c.moveTo(0, -18); c.quadraticCurveTo(-14, -28, -32, -24); c.lineTo(-32, 22); c.quadraticCurveTo(-14, 18, 0, 26); c.quadraticCurveTo(14, 18, 32, 22); c.lineTo(32, -24); c.quadraticCurveTo(14, -28, 0, -18); c.lineTo(0, 26); c.stroke(); }
  if (name === 'camera') { c.roundRect(-32, -18, 64, 46, 10); c.moveTo(-12, -18); c.lineTo(-6, -28); c.lineTo(6, -28); c.lineTo(12, -18); c.stroke(); c.beginPath(); c.arc(0, 4, 12, 0, Math.PI * 2); c.stroke(); }
  if (name === 'sparkles') { const st = (cx, cy, R) => { c.moveTo(cx, cy - R); c.quadraticCurveTo(cx, cy, cx + R, cy); c.quadraticCurveTo(cx, cy, cx, cy + R); c.quadraticCurveTo(cx, cy, cx - R, cy); c.quadraticCurveTo(cx, cy, cx, cy - R); }; st(-6, 4, 24); st(20, -18, 11); c.stroke(); }
  if (name === 'gear') { c.arc(0, 0, 10, 0, Math.PI * 2); c.stroke(); c.beginPath(); for (let i = 0; i < 8; i++) { const a = i / 8 * Math.PI * 2; c.moveTo(Math.cos(a) * 20, Math.sin(a) * 20); c.lineTo(Math.cos(a) * 29, Math.sin(a) * 29); } c.stroke(); c.beginPath(); c.arc(0, 0, 21, 0, Math.PI * 2); c.stroke(); }
  if (name === 'speaker') { c.moveTo(-26, -10); c.lineTo(-12, -10); c.lineTo(4, -24); c.lineTo(4, 24); c.lineTo(-12, 10); c.lineTo(-26, 10); c.closePath(); c.fill(); c.beginPath(); c.arc(6, 0, 16, -0.8, 0.8); c.stroke(); c.beginPath(); c.arc(6, 0, 28, -0.8, 0.8); c.stroke(); }
  if (name === 'pin') { c.moveTo(0, 28); c.bezierCurveTo(-30, -2, -22, -28, 0, -28); c.bezierCurveTo(22, -28, 30, -2, 0, 28); c.fill(); c.fillStyle = '#fff'; c.beginPath(); c.arc(0, -8, 8, 0, Math.PI * 2); c.fill(); }
  if (name === 'flash') { c.moveTo(6, -30); c.lineTo(-16, 4); c.lineTo(2, 4); c.lineTo(-6, 30); c.lineTo(16, -6); c.lineTo(-2, -6); c.closePath(); c.stroke(); }
  if (name === 'flip') { c.arc(0, 0, 22, -2.6, 0.3); c.stroke(); c.beginPath(); c.arc(0, 0, 22, 0.55, 3.4); c.stroke(); c.beginPath(); c.moveTo(22, 4); c.lineTo(16, -6); c.lineTo(28, -6); c.closePath(); c.fill(); }
  if (name === 'check') { c.moveTo(-18, 2); c.lineTo(-5, 15); c.lineTo(20, -12); c.stroke(); }
  if (name === 'chev') { c.moveTo(-8, -16); c.lineTo(8, 0); c.lineTo(-8, 16); c.stroke(); }
  if (name === 'chevL') { c.moveTo(8, -16); c.lineTo(-8, 0); c.lineTo(8, 16); c.stroke(); }
  if (name === 'close') { c.moveTo(-14, -14); c.lineTo(14, 14); c.moveTo(14, -14); c.lineTo(-14, 14); c.stroke(); }
  if (name === 'pencil') { c.moveTo(-22, 22); c.lineTo(-18, 8); c.lineTo(14, -24); c.lineTo(24, -14); c.lineTo(-8, 18); c.closePath(); c.stroke(); c.beginPath(); c.moveTo(8, -18); c.lineTo(18, -8); c.stroke(); }
  c.restore();
}
function tabBar({ sel = 2, alpha = 1, dy = 0, bump = 0, t = 0 } = {}) {
  if (alpha <= 0) return;
  ctx.save(); ctx.translate(0, dy);
  glass(TAB_X, TAB_Y, TAB_W, TAB_H, TAB_H / 2, { alpha, tint: 'rgba(255,255,255,0.62)' });
  ctx.globalAlpha = alpha;
  TABS.forEach(([ic, label], i) => {
    const [cx, cy] = tabCenter(i); const on = i === sel;
    if (on) { ctx.fillStyle = 'rgba(0,131,255,0.13)'; rr(cx - 92, TAB_Y + 18, 184, TAB_H - 36, (TAB_H - 36) / 2); ctx.fill(); }
    const s = i === 1 ? 1 + bump : 1;
    ctx.save(); ctx.translate(cx, cy - 6); ctx.scale(s, s); icon(ic, 0, 0, 66, on ? BLUE : '#3A4250'); ctx.restore();
    text(label, cx, TAB_Y + 148, { w: 600, size: 29, color: on ? BLUE : '#3A4250' });
  });
  ctx.restore();
}

// touch indicator: appear, press, release ripple
function finger(x, y, t, tIn, tPress, tOut = tPress + .35) {
  if (t < tIn || t > tOut + .4) return;
  const a = seg(t, tIn, tIn + .12) * (1 - seg(t, tOut, tOut + .2));
  const pr = seg(t, tPress, tPress + .08) * (1 - seg(t, tPress + .1, tPress + .22));
  const rip = seg(t, tPress + .08, tPress + .5);
  ctx.save();
  if (rip > 0 && rip < 1) { ctx.globalAlpha = (1 - rip) * .55; ctx.strokeStyle = '#fff'; ctx.lineWidth = 4; ctx.beginPath(); ctx.arc(x, y, 46 + 70 * E.outCubic(rip), 0, Math.PI * 2); ctx.stroke(); }
  ctx.globalAlpha = a; ctx.shadowColor = 'rgba(0,0,0,0.3)'; ctx.shadowBlur = 24;
  ctx.fillStyle = 'rgba(255,255,255,0.42)'; ctx.beginPath(); ctx.arc(x, y, 46 * (1 - .14 * pr), 0, Math.PI * 2); ctx.fill();
  ctx.shadowBlur = 0; ctx.lineWidth = 3; ctx.strokeStyle = 'rgba(255,255,255,0.9)'; ctx.stroke();
  ctx.restore();
}
// a finger that travels between points (path of [t, x, y] keys, eased), with presses at given times
function fingerPath(t, keys, presses, tIn, tOut) {
  if (t < tIn || t > tOut + .25) return;
  let x = keys[0][1], y = keys[0][2];
  for (let i = 0; i < keys.length - 1; i++) { const [t0, x0, y0] = keys[i], [t1, x1, y1] = keys[i + 1]; if (t >= t0) { const u = E.inOutCubic(seg(t, t0, t1)); x = lerp(x0, x1, u); y = lerp(y0, y1, u); } }
  const a = seg(t, tIn, tIn + .12) * (1 - seg(t, tOut, tOut + .2));
  let pr = 0, rip = -1; for (const p of presses) { pr = Math.max(pr, seg(t, p, p + .08) * (1 - seg(t, p + .1, p + .22))); if (t > p + .08 && t < p + .5) rip = seg(t, p + .08, p + .5); }
  ctx.save();
  if (rip > 0 && rip < 1) { ctx.globalAlpha = (1 - rip) * .55; ctx.strokeStyle = '#fff'; ctx.lineWidth = 4; ctx.beginPath(); ctx.arc(x, y, 46 + 70 * E.outCubic(rip), 0, Math.PI * 2); ctx.stroke(); }
  ctx.globalAlpha = a; ctx.shadowColor = 'rgba(0,0,0,0.3)'; ctx.shadowBlur = 24;
  ctx.fillStyle = 'rgba(255,255,255,0.42)'; ctx.beginPath(); ctx.arc(x, y, 46 * (1 - .14 * pr), 0, Math.PI * 2); ctx.fill();
  ctx.shadowBlur = 0; ctx.lineWidth = 3; ctx.strokeStyle = 'rgba(255,255,255,0.9)'; ctx.stroke();
  ctx.restore();
  return [x, y];
}
// speaker button with voice wave rings
function speakerBtn(x, y, r, t, tVoice, { alpha = 1, blue = true } = {}) {
  ctx.save(); ctx.globalAlpha *= alpha;
  const v = seg(t, tVoice, tVoice + .9);
  if (v > 0 && v < 1) for (let k = 0; k < 2; k++) { const u = clamp(v * 1.4 - k * .3); if (u <= 0 || u >= 1) continue; ctx.save(); ctx.globalAlpha *= (1 - u) * .5; ctx.strokeStyle = BLUE; ctx.lineWidth = 4; ctx.beginPath(); ctx.arc(x, y, r + 40 * E.outCubic(u), 0, Math.PI * 2); ctx.stroke(); ctx.restore(); }
  ctx.shadowColor = 'rgba(0,131,255,0.35)'; ctx.shadowBlur = 24; ctx.shadowOffsetY = 8;
  ctx.fillStyle = blue ? BLUE : 'rgba(255,255,255,0.9)'; ctx.beginPath(); ctx.arc(x, y, r, 0, Math.PI * 2); ctx.fill(); ctx.shadowColor = 'transparent';
  icon('speaker', x - 2, y, r * 1.05, blue ? '#fff' : BLUE, 6);
  ctx.restore();
}

// ---------- sticker composite (the cup) ----------
const SK = document.createElement('canvas'); const skx = SK.getContext('2d');
const HL = document.createElement('canvas'); const hlx = HL.getContext('2d');
function borderImg(r) {
  const rs = [4, 8, 12, 16, 20, 24]; r = clamp(r, 0, 24);
  if (r <= 0) return [];
  let lo = rs[0], hi = rs[0];
  for (let i = 0; i < rs.length; i++) { if (rs[i] <= r) lo = rs[i]; if (rs[i] >= r) { hi = rs[i]; break; } }
  if (r < 4) return [[A.b4, r / 4]];
  if (lo === hi) return [[A['b' + lo], 1]];
  const f = (r - lo) / (hi - lo); return [[A['b' + lo], 1], [A['b' + hi], f]];
}
function sticker({ border = 20, sheen = -1, holo = -1, white = 1, alphaCut = 1 } = {}) {
  const c = M.cup; if (SK.width !== c.tw) { SK.width = c.tw; SK.height = c.th; }
  skx.clearRect(0, 0, SK.width, SK.height);
  for (const [im, a] of borderImg(border)) { skx.globalAlpha = a * white; skx.drawImage(im, 0, 0); }
  skx.globalAlpha = alphaCut; skx.drawImage(A.cut, 0, 0); skx.globalAlpha = 1;
  if (sheen >= 0 && sheen <= 1) {
    skx.save(); skx.globalCompositeOperation = 'source-atop';
    const L = c.tw + c.th, p = -L * .35 + sheen * L * 1.3;
    const g = skx.createLinearGradient(p, p * .6, p + 260, p * .6 + 160);
    g.addColorStop(0, 'rgba(255,255,255,0)'); g.addColorStop(.5, 'rgba(255,255,255,0.55)'); g.addColorStop(1, 'rgba(255,255,255,0)');
    skx.fillStyle = g; skx.fillRect(0, 0, c.tw, c.th); skx.restore();
  }
  if (holo >= 0 && holo <= 1) {
    skx.save();
    const L = c.tw + c.th, p = -L * .5 + holo * L * 1.5;
    const g = skx.createLinearGradient(p, p * .5, p + 700, p * .5 + 420);
    [[0, 'rgba(120,255,240,0)'], [.2, 'rgba(120,255,240,0.55)'], [.4, 'rgba(255,120,220,0.55)'], [.6, 'rgba(255,230,120,0.55)'], [.8, 'rgba(120,180,255,0.5)'], [1, 'rgba(120,180,255,0)']].forEach(([o, col]) => g.addColorStop(o, col));
    if (HL.width !== c.tw) { HL.width = c.tw; HL.height = c.th; }
    hlx.globalCompositeOperation = 'source-over'; hlx.clearRect(0, 0, c.tw, c.th); hlx.fillStyle = g; hlx.fillRect(0, 0, c.tw, c.th);
    hlx.globalCompositeOperation = 'destination-in'; hlx.drawImage(SK, 0, 0);
    skx.globalCompositeOperation = 'soft-light'; skx.globalAlpha = .9; skx.drawImage(HL, 0, 0);
    skx.globalCompositeOperation = 'source-atop'; skx.globalAlpha = .22; skx.drawImage(HL, 0, 0);
    skx.restore();
  }
  return SK;
}
function placeTile(src, cx, cy, s, r = 0, alpha = 1, sx = 1, sy = 1) {
  const c = M.cup; ctx.save(); ctx.globalAlpha *= alpha; ctx.translate(cx, cy); ctx.rotate(r); ctx.scale(s * sx, s * sy);
  ctx.drawImage(src, -c.tw / 2, -c.th / 2); ctx.restore();
}
function shadowTile(cx, cy, s, alpha, off = 30, r = 0) {
  if (alpha <= 0) return; const c = M.cup; ctx.save(); ctx.globalAlpha *= alpha; ctx.translate(cx, cy + off * s); ctx.rotate(r); ctx.scale(s, s);
  ctx.drawImage(A.shadow, -c.tw / 2, -c.th / 2); ctx.restore();
}
// scale that puts the cup's cut-out (not the tile) into a box of `box` px height
const CUP_CUT_H = 1172;
const slotScale = box => box / CUP_CUT_H;

// ---------- background photo ----------
function photoState(t) {
  const live = t < T_CAP; const settle = E.outCubic(seg(t, T_CAP, T_CAP + .5));
  const dx = live ? Math.sin(t * 2.1) * 7 + Math.sin(t * 5.3) * 2 : lerp(Math.sin(T_CAP * 2.1) * 7, 0, settle);
  const dy = live ? Math.cos(t * 1.7) * 6 : lerp(Math.cos(T_CAP * 1.7) * 6, 0, settle);
  const s = live ? 1.05 : lerp(1.05, 1, settle);
  return { dx, dy, s };
}
function drawPhoto(c, t, { blur = 0, bright = 1, sat = 1, scale = 1, focus = null, alpha = 1 } = {}) {
  const ps = photoState(t); const s = ps.s * scale; const [fx, fy] = focus || [W / 2, H / 2];
  c.save(); c.globalAlpha = alpha;
  const f = []; if (blur > .3) f.push(`blur(${blur}px)`); if (bright !== 1) f.push(`brightness(${bright})`); if (sat !== 1) f.push(`saturate(${sat})`);
  c.filter = f.length ? f.join(' ') : 'none';
  c.translate(fx + ps.dx, fy + ps.dy); c.scale(s, s); c.translate(-fx, -fy);
  const m = blur > 1 ? blur * 2 : 0; c.drawImage(A.photo, -m, -m, W + 2 * m, H + 2 * m);
  c.restore(); c.filter = 'none';
}
function camChrome(t) {
  const out = E.inOutCubic(seg(t, T_CAP + .05, T_CAP + .4)); if (out >= 1) return;
  ctx.save(); ctx.globalAlpha = 1 - out; ctx.translate(0, out * 80);
  const cy = TAB_Y - 170, pr = seg(t, T_PRESS, T_PRESS + .06) * (1 - seg(t, T_PRESS + .1, T_PRESS + .2));
  ctx.lineWidth = 14; ctx.strokeStyle = '#fff'; ctx.beginPath(); ctx.arc(W / 2, cy, 104, 0, Math.PI * 2); ctx.stroke();
  ctx.fillStyle = '#fff'; ctx.beginPath(); ctx.arc(W / 2, cy, 86 * (1 - pr * .12), 0, Math.PI * 2); ctx.fill();
  glass(150, cy - 62, 124, 124, 62, { dark: true, shadow: 0 }); icon('flash', 212, cy, 54, '#fff', 6);
  glass(W - 274, cy - 62, 124, 124, 62, { dark: true, shadow: 0 }); icon('flip', W - 212, cy, 54, '#fff', 6);
  glass(W / 2 - 66, cy - 220, 132, 72, 36, { dark: true, shadow: 0 }); text('1×', W / 2, cy - 172, { w: 700, size: 34, f: FONT_UI, color: '#FFD60A' });
  ctx.restore();
}
function capFlash(t) { const u = seg(t, T_CAP, T_CAP + .22); if (u <= 0 || u >= 1) return; ctx.fillStyle = `rgba(0,0,0,${.55 * Math.sin(u * Math.PI)})`; ctx.fillRect(0, 0, W, H); }

// a status pill at the top (glass). `label` may change: crossfade from prev label at tSwap.
function topPill(t, tIn, tOut, label, { shimmer = false, prev = null, tSwap = -1, icon: ic = 'sparkles' } = {}) {
  const a = seg(t, tIn, tIn + .2) * (1 - seg(t, tOut, tOut + .18)); if (a <= 0) return;
  const swap = tSwap < 0 ? 1 : E.inOutCubic(seg(t, tSwap, tSwap + .3));
  const w1 = measure(label, 700, 38) + 120, w0 = prev ? measure(prev, 700, 38) + 120 : w1, w = lerp(w0, w1, swap);
  const x = W / 2 - w / 2, y = 176 + (1 - E.outCubic(seg(t, tIn, tIn + .3))) * -20;
  glass(x, y, w, 92, 46, { alpha: a, tint: 'rgba(255,255,255,0.72)' });
  ctx.save(); ctx.globalAlpha *= a;
  ctx.save(); ctx.translate(x + 52, y + 46); const tw = 1 + .15 * Math.sin(t * 9); ctx.scale(tw, tw); icon(ic, 0, 0, 40, BLUE, 6); ctx.restore();
  const draw = (s, al, dy) => {
    if (al <= 0) return; ctx.save(); ctx.globalAlpha *= al; font(700, 38); ctx.textAlign = 'left'; ctx.textBaseline = 'middle';
    if (shimmer) { const g = ctx.createLinearGradient(x, 0, x + w, 0); const p = (t * .9) % 1.6 - .3; g.addColorStop(clamp(p - .2), INK); g.addColorStop(clamp(p), '#8FC4FF'); g.addColorStop(clamp(p + .2), INK); ctx.fillStyle = g; } else ctx.fillStyle = INK;
    ctx.beginPath(); ctx.rect(x, y, w, 92); ctx.clip(); ctx.fillText(s, x + 86, y + 48 + dy); ctx.restore();
  };
  if (prev && swap < 1) draw(prev, 1 - swap, -30 * swap);
  draw(label, swap, 30 * (1 - swap));
  ctx.restore();
}
