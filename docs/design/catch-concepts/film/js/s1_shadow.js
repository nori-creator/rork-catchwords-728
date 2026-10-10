// S1 影あわせ — the 図鑑's shadow. The moment the device has found the things in the photo (on-device masks, well under
// a second), each one is lit and gets a tag that is a 図鑑 slot not filled yet: its shadow (the same light-grey
// silhouette the 図鑑 shows for a word not caught), No.??? and ？？？. The shape is known, the name is not — a curiosity
// gap, so the wait reads as suspense, not delay; and it says plainly what is at stake: new entries for your 図鑑.
// When the answer arrives the slots are filled one by one with the 図鑑's own fill-in (the cut-out springs in with the
// DexFillIn curve), the word rolls in, and the words not yet in the 図鑑 get NEW.
const DEXNO = { cup: 1, scooter: 87, plant: 112, sign: 143 };
const dexNo = tag => 'No.' + String(DEXNO[tag.id]).padStart(3, '0');
const dexLine1 = tag => `${dexNo(tag)}  ${tag.ja}`;
function dexTagGeom(tag) {
  const tile = 84, pad = 14, gap = 18, right = 30;
  const wq = pad + tile + gap + measure('？？？', 800, 40) + right;
  const wz = measure(tag.zh, 800, 44, FONT_TC), w1 = measure(dexLine1(tag), 600, 22);
  return { tile, pad, gap, wq, wf: pad + tile + gap + Math.max(wz, w1) + right + (NEW_WORD[tag.id] ? 34 : 0), h: 112 };
}
function dexTag(i, t) {
  const tag = TAGS[i], tq = T_MASK(i) + .12, tr = T_REVEAL(i); if (t < tq) return;
  const G = dexTagGeom(tag), rev = t >= tr, h = G.h;
  const pop = clamp(sp(t, tq, .42, .62), 0, 1.15), wk = rev ? clamp(spring(t - tr - .08, .42, .62), 0, 1.12) : 0;
  const w = lerp(G.wq, G.wf, wk), cx = tag.p[0], bottom = tag.p[1] - 30;
  const x = clamp(cx - w / 2, 22, W - 22 - w), y = bottom - h;
  ctx.save(); ctx.globalAlpha *= clamp(pop * 3); tagAnchor(tag, t, 1, E.outCubic(seg(t, tq, tq + .22))); ctx.restore();
  const press = tag.id === 'cup' ? cupTagPress(t) : 0, k = pop * (1 - press * .06);
  ctx.save(); ctx.translate(cx, bottom); ctx.scale(k, k); ctx.translate(-cx, -bottom);
  glass(x, y, w, h, h / 2, { tint: 'rgba(255,255,255,0.88)', shadow: .22 });
  // the slot
  const ts = G.tile, tx = x + G.pad, ty = y + (h - ts) / 2, caught = E.outCubic(seg(t, tr + .05, tr + .22));
  ctx.save(); rr(tx, ty, ts, ts, 24); ctx.clip();
  ctx.fillStyle = '#EEF2F7'; ctx.fillRect(tx, ty, ts, ts);
  if (caught > 0) { const gg = ctx.createRadialGradient(tx + ts / 2, ty + ts * .38, 0, tx + ts / 2, ty + ts * .38, ts * .75); gg.addColorStop(0, '#fff'); gg.addColorStop(1, '#E2ECF8'); ctx.globalAlpha = caught; ctx.fillStyle = gg; ctx.fillRect(tx, ty, ts, ts); ctx.globalAlpha = 1; }
  const C = cutOf(tag.id), f = (ts - 14) / Math.max(C.w, C.h), dw = C.w * f, dh = C.h * f;
  if (!rev || t < tr + .06) {
    // the shadow, and the 図鑑's anticipation shine passing over it while the name is looked up
    ctx.save(); ctx.globalAlpha = .95; ctx.drawImage(C.s, tx + (ts - dw) / 2, ty + (ts - dh) / 2, dw, dh); ctx.restore();
    const ph = ((t - tq - .5 - i * .3) / 1.9) % 1, wait = seg(t, tq + .4, tq + .7);
    if (ph > 0 && wait > 0) { const p = tx - ts + ph * ts * 3, gg = ctx.createLinearGradient(p, ty, p + ts * .6, ty + ts * .6); gg.addColorStop(0, 'rgba(255,255,255,0)'); gg.addColorStop(.5, `rgba(255,255,255,${.85 * wait})`); gg.addColorStop(1, 'rgba(255,255,255,0)'); ctx.fillStyle = gg; ctx.fillRect(tx, ty, ts, ts); }
  }
  if (rev) {
    const u = seg(t, tr + .04, tr + .6), s = lerp(1.7, 1, fillInEase(u)), r = lerp(-10, 0, fillInEase(u)) * Math.PI / 180;
    if (u > 0) { ctx.save(); ctx.translate(tx + ts / 2, ty + ts / 2); ctx.rotate(r); ctx.scale(s, s); ctx.globalAlpha = clamp(u * 6); ctx.drawImage(C.c, -dw / 2, -dh / 2, dw, dh); ctx.restore(); }
    const fl = Math.sin(Math.PI * seg(t, tr, tr + .14)); if (fl > 0) { ctx.fillStyle = `rgba(255,255,255,${fl})`; ctx.fillRect(tx, ty, ts, ts); }
  }
  ctx.restore();
  // the text: No.??? / ？？？ until the answer, then the number rolls and the word rises in
  const bx = tx + ts + G.gap;
  ctx.save(); ctx.beginPath(); ctx.rect(bx - 4, y, w - (bx - x) - 10, h); ctx.clip();
  const out = E.inOutCubic(seg(t, tr, tr + .18));
  if (out < 1) {
    ctx.save(); ctx.globalAlpha *= 1 - out; ctx.translate(0, -out * 30);
    text('No.???', bx, y + 40, { w: 700, size: 22, f: FONT_UI, color: '#8C96A3', align: 'left', ls: 1 });
    for (let q = 0; q < 3; q++) { const bob = Math.max(0, Math.sin(2 * Math.PI * (t * 1.1 - q * .15))) * 5 * seg(t, tq + .4, tq + .7); text('？', bx + 20 + q * 40, y + 86 - bob, { w: 800, size: 40, color: '#AEB8C4' }); }
    ctx.restore();
  }
  if (rev) {
    const rin = E.outCubic(seg(t, tr + .1, tr + .3));
    text(dexNo(tag), bx, y + 40 + (1 - rin) * 30, { w: 700, size: 22, f: FONT_UI, color: BLUE, align: 'left', ls: 1, alpha: rin });
    text(tag.ja, bx + measure(dexNo(tag), 700, 22, FONT_UI, 1) + 12, y + 40, { w: 600, size: 22, color: MUTED, align: 'left', alpha: E.outCubic(seg(t, tr + .38, tr + .6)) });
    let xx = bx; const chars = [...tag.zh], n = chars.length, rv = seg(t, tr + .14, tr + .5);
    chars.forEach((ch, j) => { const p = E.outBack(clamp((rv * (n + 2) - j) / 2.2), 1.6), wch = measure(ch, 800, 44, FONT_TC); if (p > 0) text(ch, xx + wch / 2, y + 84 + (1 - p) * 30, { w: 800, size: 44, f: FONT_TC, color: INK, alpha: clamp(p * 1.4) }); xx += wch; });
  }
  ctx.restore();
  ctx.restore();
  // the fill-in moment: a ring and a twinkle round the slot
  const ru = seg(t, tr + .06, tr + .56);
  if (ru > 0 && ru < 1) {
    const rcx = (tx + ts / 2 - cx) * k + cx, rcy = (ty + ts / 2 - bottom) * k + bottom;
    ctx.save(); ctx.globalAlpha = (1 - ru) * .9; ctx.strokeStyle = BLUE2; ctx.lineWidth = 6 * (1 - ru) + 1; ctx.beginPath(); ctx.arc(rcx, rcy, ts * .5 + 70 * E.outCubic(ru), 0, Math.PI * 2); ctx.stroke(); ctx.restore();
    drawLottie('twinkle', t, tr + .05, rcx, rcy, 240, .9);
  }
  if (rev && NEW_WORD[tag.id]) {
    const nk = E.outBack(seg(t, tr + .45, tr + .75), 2.6);
    if (nk > 0) { ctx.save(); ctx.translate(x + w - 18, y + 2); ctx.scale(nk, nk); ctx.rotate(.08); ctx.shadowColor = 'rgba(0,80,200,0.35)'; ctx.shadowBlur = 12; ctx.shadowOffsetY = 4; ctx.fillStyle = BLUE; rr(-44, -19, 88, 38, 19); ctx.fill(); ctx.shadowColor = 'transparent'; text('NEW', 0, 9, { w: 800, size: 23, f: FONT_UI, color: '#fff', ls: 1.5 }); ctx.restore(); }
  }
}
function conceptS1(t) {
  CUES.S1 = { masks: TAGS.map((_, i) => +T_MASK(i).toFixed(3)), names: T_NAMES, reveals: TAGS.map((_, i) => +T_REVEAL(i).toFixed(3)), tap: T_TAP, end: SCAN_END };
  const dim = .22 * E.outCubic(seg(t, T_MASK(0) - .1, T_MASK(0) + .4)) * (1 - E.inOutCubic(seg(t, T_REVEAL(3) + .2, T_REVEAL(3) + .7)));
  spotBackdrop(t, TAGS.map((_, i) => E.outCubic(seg(t, T_MASK(i), T_MASK(i) + .45))), { dim, sat: .8 });
  makeBlur(); ctx.drawImage(BG, 0, 0);
  capFlash(t); camChrome(t);
  TAGS.forEach((_, i) => dexTag(i, t));
  scanPills(t, 99);
  tabBar({ sel: 2, t });
  scanEnd(t);
  statusBar(false); homeIndicator(false);
}
