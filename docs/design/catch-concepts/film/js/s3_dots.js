// S3 粒子 — reading the photo into ink. When the device has found a thing, a fine glitter of light runs over it from the
// point its word belongs to (no frame, no scan line: the surface itself sparkles, as if being read), and a small white
// tag opens above it. Particles keep lifting off the thing and drifting up into the tag, where they gather as a
// living cloud of ink — the tag visibly fills while the AI works (fast at first, then slower; it never fills before
// the answer). When the answer arrives the cloud forms the word from the left — dithered first, then crisp — the same
// reform as the word page (E), so the whole app speaks one language for "the AI is writing this".
const S3 = { step: 3, qw: 236 };
let PHOTO_PX = null;
function photoPx() {
  if (PHOTO_PX) return PHOTO_PX;
  const c = document.createElement('canvas'); c.width = W; c.height = H; const g = c.getContext('2d', { willReadFrequently: true });
  g.drawImage(A.photo, 0, 0, W, H); return PHOTO_PX = g.getImageData(0, 0, W, H).data;
}
function lumAt(x, y) { const p = photoPx(), k = (Math.round(clamp(y, 0, H - 1)) * W + Math.round(clamp(x, 0, W - 1))) * 4; return (p[k] * .299 + p[k + 1] * .587 + p[k + 2] * .114) / 255; }
// the tag's final text (blue dot, word, meaning) drawn on its own canvas, for the particle targets and the crisp fade
function tagTextCanvas(tag) {
  const g = tagGeom(tag), c = document.createElement('canvas'); c.width = Math.ceil(g.w); c.height = g.h; const x = c.getContext('2d');
  const X = g.w / 2, Y = g.h / 2, body = g.w - 64 - (g.hint ? g.hint + 10 : 0), tx = 32 + body / 2;
  const cw = measure(tag.zh, 800, 46, FONT_TC), wordW = cw + TAG_DOT * 2 + 14; let xx = tx - wordW / 2;
  x.fillStyle = BLUE2; x.beginPath(); x.arc(xx + TAG_DOT, Y - 16, TAG_DOT, 0, Math.PI * 2); x.fill();
  text(tag.zh, xx + TAG_DOT * 2 + 14, Y, { w: 800, size: 46, f: FONT_TC, color: INK, align: 'left', c: x });
  text(tag.ja, tx, Y + 38, { w: 500, size: 28, color: MUTED, c: x });
  return { c, w: g.w, h: g.h, X, Y };
}
let S3D = null;
function s3Data() {
  if (S3D) return S3D;
  S3D = TAGS.map((tag, i) => {
    const M = MK[tag.id], [ax, ay] = tag.p, g = tagGeom(tag), T = tagTextCanvas(tag);
    // glitter points on the thing (jittered grid inside its mask), each knows its distance from the anchor and its light
    const gl = [];
    for (let y = M.y; y < M.y + M.h; y += 7) for (let x = M.x; x < M.x + M.w; x += 7) {
      const jx = x + rnd(x * 1.7 + y) * 6, jy = y + rnd(x + y * 2.3) * 6;
      if (maskAt(tag.id, jx, jy) > .6 && rnd(jx * 3.1 + jy * .7) < .55) gl.push([jx, jy, Math.hypot(jx - ax, jy - ay), Math.pow(lumAt(jx, jy), .6), rnd(jx + jy * 9.1)]);
    }
    const maxD = Math.max(...gl.map(p => p[2]));
    // particle targets: the final text, cut into 3 px cells, kept with a probability = its ink (dither); colour sampled
    const td = T.c.getContext('2d', { willReadFrequently: true }).getImageData(0, 0, T.c.width, T.c.height).data, tg = [];
    for (let y = 0; y + 3 <= T.h; y += 3) for (let x = 0; x + 3 <= T.c.width; x += 3) {
      let a = 0, r = 0, gg = 0, b = 0;
      for (let yy = 0; yy < 3; yy++) for (let xx = 0; xx < 3; xx++) { const k = ((y + yy) * T.c.width + x + xx) * 4, al = td[k + 3] / 255; a += al; r += td[k] * al; gg += td[k + 1] * al; b += td[k + 2] * al; }
      if (a <= 0) continue; const cov = a / 9;
      if (cov > .05 && cov > rnd(i * 733 + x * 3.1 + y * 7.7) * .9) tg.push([x + 1.5, y + 1.5, Math.min(1, .5 + cov * .6), `${Math.round(r / a)},${Math.round(gg / a)},${Math.round(b / a)}`]);
    }
    tg.sort((p, q) => p[0] - q[0]);
    const n = tg.length, t0 = T_MASK(i) + .32, span = (T_NAMES - t0) * 1.55;
    // each particle: where it lifts off the thing, when, and where it drifts in the cloud
    const pt = Array.from({ length: n }, (_, k) => {
      const src = gl[Math.floor(rnd(k * 2.7 + i * 91) * gl.length)];
      return { sx: src[0], sy: src[1], ts: t0 + span * Math.pow(rnd(k * 1.3 + i * 17), 1.9), cu: rnd(k * 4.1 + i), cv: rnd(k * 6.7 + i * 3), seed: k * .61 + i * 13 };
    });
    // which target each particle forms: by x order at the moment the word starts to form
    const tr0 = T_REVEAL(i), order = pt.map((p, k) => [cloudXY(i, p, tr0, g)[0], k]).sort((a, b) => a[0] - b[0]);
    const tgOf = new Int32Array(n); order.forEach(([, k], r) => tgOf[k] = r);
    return { gl, maxD, tg, pt, tgOf, T, n };
  });
  return S3D;
}
// the tag's box: compact while it waits, the final size once the word forms
function s3Box(i, t) {
  const tag = TAGS[i], g = tagGeom(tag), tr = T_REVEAL(i), k = clamp(spring(t - tr, .4, .66), 0, 1.1);
  const w = lerp(S3.qw, g.w, k), h = g.h, cx = tag.p[0], bottom = tag.p[1] - 30;
  return { x: cx - w / 2, y: bottom - h, w, h, cx, cy: bottom - h / 2, bottom, k };
}
function cloudXY(i, p, t, g) {       // a particle's place in the waiting cloud (a pure function of t)
  const tag = TAGS[i], bottom = tag.p[1] - 30, w = S3.qw - 56, h = TAG_H - 40;
  const x = tag.p[0] - w / 2 + ((p.cu * w + 9 * t + 10 * vnoise(t * .9 + p.seed * 3, 1)) % w + w) % w;
  const y = bottom - TAG_H + 20 + clamp(p.cv * h + 7 * vnoise(t * 1.1 + p.seed * 5, 2), 0, h);
  return [x, y];
}
function s3Tag(i, t) {
  const tag = TAGS[i], D = s3Data()[i], tq = T_MASK(i) + .22, tr = T_REVEAL(i); if (t < T_MASK(i)) return;
  const B = s3Box(i, t), g = tagGeom(tag), press = tag.id === 'cup' ? cupTagPress(t) : 0;
  const ink = [], light = [];
  // 1) glitter: a front runs out from the anchor over the thing; it comes back, fainter, while the name is looked up
  const pass = (t1, dur, amp) => {
    const u = (t - t1) / dur; if (u < 0 || u > 1.3) return;
    const front = u * D.maxD, band = 70;
    for (const [x, y, d, l, r] of D.gl) { const q = 1 - Math.abs(d - front) / band; if (q > 0 && r < .8) light.push([x, y, amp * l * q * (.55 + .45 * Math.sin(t * 40 + r * 50)), 2.6]); }
  };
  pass(T_MASK(i), .62, 1);
  for (let k = 1; k < 4; k++) { const t1 = T_MASK(i) + .4 + k * 1.15 + i * .2; if (t1 < T_NAMES - .3) pass(t1, .9, .4); }
  // 2) the tag
  if (t >= tq) {
    const pop = clamp(sp(t, tq, .4, .62), 0, 1.12);
    ctx.save(); ctx.globalAlpha *= clamp(pop * 3); tagAnchor(tag, t, 1, E.outCubic(seg(t, tq, tq + .2))); ctx.restore();
    ctx.save(); ctx.translate(B.cx, B.bottom); ctx.scale(pop * (1 - press * .07), pop * (1 - press * .07)); ctx.translate(-B.cx, -B.bottom);
    glass(B.x, B.y, B.w, B.h, B.h / 2, { tint: 'rgba(255,255,255,0.9)', shadow: .22 });
    ctx.restore();
  }
  // 3) particles: lift off the thing, drift into the tag (light → ink as they enter), gather, then form the word
  const tx0 = B.cx - g.w / 2, ty0 = B.y, cr0 = tr + .34, cfront = tx0 - 20 + (g.w + 60) * seg(t, cr0, cr0 + .5);
  for (let k = 0; k < D.n; k++) {
    const p = D.pt[k], tj = D.tg[D.tgOf[k]], xr = tj[0] / g.w, tf = tr + .03 + xr * .4 + rnd(k * 7.7 + i) * .05;
    const late = p.ts > tf - .3, ts = late ? tf - .3 : p.ts; if (t < ts) continue;
    const fu = seg(t, ts, ts + .55), e = E.inOutSine(fu);
    let x, y, a, col;
    if (t < tf) {
      const [cx, cy] = cloudXY(i, p, t, g), mid = [(p.sx + cx) / 2 + (rnd(k * 9.1) - .5) * 120, Math.min(p.sy, cy) - 60 - rnd(k * 3.9) * 80];
      [x, y] = fu < 1 ? bez2([p.sx, p.sy], mid, [cx, cy], e) : [cx, cy];
      a = fu < 1 ? .9 : .72; col = fu < .78 ? 'light' : 'ink';
    } else {
      const v = seg(t, tf, tf + .38), ev = E.outCubic(v), [cx, cy] = late && t < ts + .55 ? bez2([p.sx, p.sy], [(p.sx + cx0(i)) / 2, p.sy - 120], [cx0(i), B.cy], e) : cloudXY(i, p, t, g), nz = (1 - v) * 6;
      x = lerp(cx, tx0 + tj[0], ev) + (rnd(k + Math.floor(t * 30)) - .5) * nz; y = lerp(cy, ty0 + tj[1], ev) + (rnd(k * 2.3 + Math.floor(t * 30)) - .5) * nz;
      a = lerp(.72, tj[2], ev) * clamp(1 - (cfront - (tx0 + tj[0]) - 6) / 30); col = ev > .6 ? tj[3] : 'ink';
    }
    if (col === 'light') light.push([x, y, a, 2.8]); else ink.push([x, y, a, col === 'ink' ? INK_RGB : col]);
  }
  // light particles: white with a soft shadow so they read on any part of the photo
  if (light.length) {
    ctx.save(); const sh = new Path2D(), lp = Array.from({ length: 4 }, () => new Path2D());
    for (const [x, y, a, s] of light) { if (a <= .03) continue; lp[Math.min(3, Math.floor(a * 4))].rect(x - s / 2, y - s / 2, s, s); sh.rect(x - s / 2 + .6, y - s / 2 + 1.2, s, s); }
    ctx.fillStyle = 'rgba(0,0,0,0.18)'; ctx.fill(sh);
    lp.forEach((pth, lv) => { ctx.fillStyle = `rgba(255,255,255,${(lv + .6) / 4})`; ctx.fill(pth); }); ctx.restore();
  }
  if (ink.length) {
    const groups = {};
    for (const [x, y, a, rgb] of ink) { if (a <= .03) continue; const key = rgb + '|' + Math.min(4, Math.floor(a * 5)); (groups[key] || (groups[key] = new Path2D())).rect(x - 1.35, y - 1.35, 2.7, 2.7); }
    for (const [key, pth] of Object.entries(groups)) { const [rgb, lv] = key.split('|'); ctx.fillStyle = `rgba(${rgb},${(+lv + .5) / 5})`; ctx.fill(pth); }
  }
  // 4) the crisp word, revealed from the left behind the formed particles; the hint chip and NEW come last
  if (cfront > tx0 - 20) {
    const T = D.T; ctx.save(); ctx.beginPath(); ctx.rect(tx0, ty0, Math.max(0, cfront - tx0 - 20), T.h); ctx.clip(); ctx.drawImage(T.c, tx0, ty0); ctx.restore();
    const edge = ctx.createLinearGradient(cfront - 40, 0, cfront, 0);
    ctx.save(); ctx.beginPath(); ctx.rect(cfront - 40, ty0, 40, T.h); ctx.clip(); ctx.globalAlpha = .5; ctx.drawImage(T.c, tx0, ty0); ctx.restore();
  }
  if (g.hint && t > cr0 + .4) {
    const ha = E.outCubic(seg(t, cr0 + .4, cr0 + .62)), hx = B.cx + g.w / 2 - 24 - g.hint, hy = B.cy - 22;
    ctx.save(); ctx.globalAlpha *= ha; ctx.fillStyle = 'rgba(0,131,255,0.12)'; rr(hx, hy, g.hint, 44, 22); ctx.fill();
    text(`ほか${tag.more}`, hx + g.hint / 2 - 7, hy + 31, { w: 700, size: 24, color: BLUE }); icon('chev', hx + g.hint - 16, hy + 22, 22, BLUE, 9); ctx.restore();
  }
  if (NEW_WORD[tag.id]) newBadge(tag, t, cr0 + .45, { cy: B.cy });
}
const cx0 = i => TAGS[i].p[0];
function conceptS3(t) {
  CUES.S3 = { masks: TAGS.map((_, i) => +T_MASK(i).toFixed(3)), names: T_NAMES, reveals: TAGS.map((_, i) => +T_REVEAL(i).toFixed(3)), tap: T_TAP, end: SCAN_END };
  const dim = .2 * E.outCubic(seg(t, T_MASK(0) - .1, T_MASK(0) + .4)) * (1 - E.inOutCubic(seg(t, T_REVEAL(3) + .4, T_REVEAL(3) + .9)));
  spotBackdrop(t, TAGS.map((_, i) => E.outCubic(seg(t, T_MASK(i), T_MASK(i) + .5))), { dim, sat: .85 });
  makeBlur(); ctx.drawImage(BG, 0, 0);
  capFlash(t); camChrome(t);
  TAGS.forEach((_, i) => s3Tag(i, t));
  scanPills2(t, T_MASK(3) + .5, T_REVEAL(3) + .85);
  tabBar({ sel: 2, t });
  scanEnd(t);
  statusBar(false); homeIndicator(false);
}
