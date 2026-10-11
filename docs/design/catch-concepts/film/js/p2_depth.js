// P2 深度スキャン — the camera measures the scene. A depth map of the photo (on device: the capture's depth data where
// the camera gives it, else a Core ML depth model) drives a pulse of light that travels from near to far through the
// real geometry — it runs down the table, wraps round the cup, climbs the scooter, fades into the street — leaving a
// fine point cloud coloured by distance. A second, quicker pulse finds the things themselves: their points brighten
// and they light up. Independent of the AI; the names arrive when they arrive.
let DEPTH = null, DQ = null, DQW = 0, DQH = 0, DOTS2 = null;
async function loadDepth() {
  const im = await img('masks/depth.png'), c = document.createElement('canvas'); c.width = W; c.height = H; const g = c.getContext('2d', { willReadFrequently: true });
  g.drawImage(im, 0, 0); const p = g.getImageData(0, 0, W, H).data;
  DEPTH = new Float32Array(W * H); for (let i = 0; i < W * H; i++) DEPTH[i] = p[i * 4] / 255;
  DQW = W / 4; DQH = Math.round(H / 4); DQ = new Float32Array(DQW * DQH);
  for (let y = 0; y < DQH; y++) for (let x = 0; x < DQW; x++) DQ[y * DQW + x] = DEPTH[Math.min(H - 1, y * 4 + 2) * W + x * 4 + 2];
}
const P2_SCAN = ['cup', 'scooter', 'sign'];
// (the point cloud of the first version read as a screen-door pattern; replaced by iso-depth contour lines)
const PULSE1 = [T_VIS, T_VIS + 1.15], PULSE2 = [T_VIS + 1.35, T_VIS + 2.05];
const pulseS = (t, [a, b]) => lerp(1.04, -.06, E.inOutSine(seg(t, a, b)));          // the depth the light is at
function p2Dots() {
  if (DOTS2) return DOTS2;
  const step = 9, pp = photoPx(); DOTS2 = [];
  for (let y = 4; y < H; y += step) for (let x = 4 + ((y / step) % 2) * 4.5; x < W; x += step) {
    const xi = Math.round(x), yi = Math.round(y), d = DEPTH[yi * W + xi], k = (yi * W + xi) * 4;
    const l = (pp[k] * .299 + pp[k + 1] * .587 + pp[k + 2] * .114) / 255;
    let obj = -1; P2_SCAN.forEach(id => { if (maskAt(id, x, y) > .5) obj = TAGS.findIndex(tg => tg.id === id); });
    // when pulse 1 reaches this depth (inverse of pulseS)
    const u = clamp((1.04 - d) / 1.1), e = u <= 0 ? 0 : u >= 1 ? 1 : (Math.acos(1 - 2 * u) / Math.PI);
    DOTS2.push({ x, y, d, l, obj, tp: lerp(PULSE1[0], PULSE1[1], e), j: rnd(x * 3.1 + y * .7) });
  }
  return DOTS2;
}
const BAND = document.createElement('canvas'); let bandx = null, BW = 0, BH = 0, DH2 = null, DG2 = null;
function p2Field(t) {
  if (!bandx) { BW = W / 2; BH = H / 2; BAND.width = BW; BAND.height = BH; bandx = BAND.getContext('2d');
    DH2 = new Float32Array(BW * BH); for (let y = 0; y < BH; y++) for (let x = 0; x < BW; x++) DH2[y * BW + x] = DEPTH[Math.min(H - 1, y * 2) * W + x * 2];
    // depth gradient per pixel, so the contour lines keep a constant width on screen (no blobs where the depth is flat)
    DG2 = new Float32Array(BW * BH); for (let y = 1; y < BH - 1; y++) for (let x = 1; x < BW - 1; x++) { const i = y * BW + x; DG2[i] = Math.hypot(DH2[i + 1] - DH2[i - 1], DH2[i + BW] - DH2[i - BW]) * .5; } }
  const s1 = pulseS(t, PULSE1), s2 = pulseS(t, PULSE2), on1 = t > PULSE1[0] && t < PULSE1[1] + .5, on2 = t > PULSE2[0] && t < PULSE2[1] + .1;
  const names = T_NAMES, idle = t > PULSE1[0] ? 1 - E.inOutCubic(seg(t, names, names + .5)) : 0;
  if (!on1 && !on2 && idle <= 0) return;
  const im = bandx.createImageData(BW, BH), o = im.data, N = 30, bw = .05;
  for (let y = 0; y < BH; y++) for (let x = 0; x < BW; x++) {
    const i = y * BW + x, d = DH2[i]; let a = 0, wr = 255, wg = 255, wb = 255;
    // 1) the pulse: a sharp white front and a coloured wake behind it (toward the near side, already passed)
    const far = .3 + .7 * clamp(d * 1.6), gl = Math.max(2e-4, DG2[i]);
    if (on1) { const dd = d - s1; if (dd > -.05 && dd < .3) { const lp = Math.abs(dd) / gl, front = Math.exp(-(lp * lp) / 2.6) * clamp(gl * 260), wake = dd > 0 ? Math.exp(-dd / .07) * .2 : 0; a = Math.max(a, (front + wake * (1 - front)) * far); } }
    // 2) contour lines left in the wake: iso-depth lines every 1/N, fading a while after the pulse passed
    const passed = on1 ? (d - s1) / .5 : 9;
    let obj = 0; if ((x & 1) === 0 && (y & 1) === 0 || true) { const X = x * 2, Y = y * 2; obj = Math.max(maskAt('cup', X, Y), maskAt('scooter', X, Y), maskAt('sign', X, Y)); }
    const namesFade = 1 - E.inOutCubic(seg(t, names, names + .5)), seen = t > PULSE1[0] ? (on1 ? clamp(passed * 3) : 1) : 0;
    const keepLine = obj > .5 ? seen * .5 * namesFade * (.8 + .2 * Math.sin(t * 2.4 + d * 20)) : (on1 ? clamp(passed * 3) * Math.exp(-Math.max(0, passed) * 2.2) * .6 : 0);
    if (keepLine > .01) { const f = d * N, fr = Math.abs(f - Math.round(f)), gpx = Math.max(1e-4, DG2[i] * N), dpx = fr / gpx; const line = Math.exp(-(dpx * dpx) / (2 * .7 * .7)) * clamp(gpx * 40); a = Math.max(a, line * keepLine); }
    // 3) the second pulse runs over the things only
    if (on2 && obj > .5) { const dd = d - s2, lp = Math.abs(dd) / Math.max(2e-4, DG2[i]); a = Math.max(a, Math.exp(-(lp * lp) / 3) * clamp(DG2[i] * 260) + (dd > 0 && dd < .2 ? Math.exp(-dd / .05) * .16 : 0)); }
    if (a <= .01) continue;
    const c = clamp(d * 1.25); const [r, g, b] = depthRGB(d); const white = clamp(a * 1.2 - .2);
    const k = i * 4; o[k] = lerp(r, 255, white); o[k + 1] = lerp(g, 255, white); o[k + 2] = 255; o[k + 3] = 255 * Math.min(1, a);
  }
  bandx.putImageData(im, 0, 0);
  ctx.save(); ctx.globalCompositeOperation = 'screen'; ctx.imageSmoothingQuality = 'high';
  ctx.globalAlpha = .55; ctx.filter = 'blur(6px)'; ctx.drawImage(BAND, 0, 0, W, H); ctx.filter = 'none';
  ctx.globalAlpha = 1; ctx.drawImage(BAND, 0, 0, W, H); ctx.restore();
}
function depthRGB(d) {               // near: white-cyan → mid: the app's cyan → far: violet-blue
  const c = clamp(d * 1.25);
  if (c > .55) { const u = (c - .55) / .45; return [lerp(100, 220, u), lerp(224, 250, u), 255]; }
  const u = c / .55; return [lerp(96, 100, u), lerp(96, 224, u), 255];
}
function p2Tags(t) {
  TAGS.forEach((tag, k) => {
    const tn = T_NAMES + .1 * k; if (t < tn - .08) return;
    const ai = !P2_SCAN.includes(tag.id);
    if (ai) { const ru = seg(t, tn - .1, tn + .5); if (ru > 0 && ru < 1) { ctx.save(); ctx.globalAlpha = (1 - ru) * .8; ctx.strokeStyle = '#fff'; ctx.lineWidth = 3; ctx.beginPath(); ctx.arc(tag.p[0], tag.p[1], 14 + 90 * E.outCubic(ru), 0, Math.PI * 2); ctx.stroke(); ctx.restore(); } }
    const pop = E.outBack(seg(t, tn - .08, tn + .14), 2.4);
    ctx.save(); ctx.translate(tag.p[0], tag.p[1]); ctx.scale(pop, pop); ctx.translate(-tag.p[0], -tag.p[1]); tagAnchor(tag, t, 1, E.outCubic(seg(t, tn - .02, tn + .16))); ctx.restore();
    const u = seg(t, tn, tn + .32), s = clamp(sp(t, tn, .42, .7), 0, 1.1), bottom = tag.p[1] - 30; if (u <= 0) return;
    ctx.save(); ctx.globalAlpha *= E.outCubic(clamp(u * 1.6)); if (u < 1) ctx.filter = `blur(${(1 - E.outCubic(u)) * 9}px)`;
    const k2 = lerp(.86, 1, s); ctx.translate(tag.p[0], bottom); ctx.scale(k2, k2); ctx.translate(-tag.p[0], -bottom); ctx.translate(0, (1 - E.outCubic(u)) * 16);
    drawTag(tag, t, { reveal: seg(t, tn + .06, tn + .5), press: tag.id === 'cup' ? cupTagPress(t) : 0 }); ctx.restore();
    if (NEW_WORD[tag.id]) newBadge(tag, t, tn + .38);
  });
}
function conceptP2(t) {
  CUES.P2 = { vis: T_VIS, pulse1: PULSE1, pulse2: PULSE2, names: T_NAMES, tags: TAGS.map((_, k) => +(T_NAMES + .1 * k).toFixed(3)), tap: T_TAP, end: SCAN_END };
  const dim = .34 * E.outCubic(seg(t, T_VIS - .05, T_VIS + .35)) * (1 - E.inOutCubic(seg(t, T_NAMES + .3, T_NAMES + .9)));
  const lit = TAGS.map(tag => P2_SCAN.includes(tag.id) ? E.outCubic(seg(t, PULSE2[0] + .2, PULSE2[1])) : 0);
  spotBackdrop(t, lit, { dim, sat: .7 });
  makeBlur(); ctx.drawImage(BG, 0, 0);
  capFlash(t); camChrome(t);
  p2Field(t);
  p2Tags(t);
  scanPills2(t, PULSE2[1], T_NAMES + .85);
  tabBar({ sel: 2, t });
  scanEnd(t);
  statusBar(false); homeIndicator(false);
}
