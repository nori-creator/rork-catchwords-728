// concepts5.js — A Lift / D Index from the tag tap onward (the scan wait is chosen separately: S1–S4, which all end
// in the same tags). Each concept publishes its key times (CUES) for the sound mix and the haptics.
const CUES = {};
const PICK_U = PICK.u;

// fast scroll from one offset to another: quick start, long settle (like scrollTo with a spring)
function scrollAt(t, t0, t1, a, b) { const u = seg(t, t0, t1); const e = 1 - Math.pow(1 - E.inOutSine(Math.min(1, u * 1.15)), 2.2); return lerp(a, b, clamp(e)); }
function scrollVel(t, t0, t1, a, b) { return (scrollAt(t, t0, t1, a, b) - scrollAt(t - 1 / 60, t0, t1, a, b)); }
// the flying sticker's trail
function flyTrail(stk, path, fly, s0, s1, r1, n = 3) {
  for (let k = n; k >= 1; k--) { const fk = clamp(fly - k * .05); if (fk <= 0) continue; const e = E.inCubic(fk); const p = path(e); placeTile(stk, p[0], p[1], lerp(s0, s1, e), r1 * e, .14 / k); }
}
const ARRIVE_S = 1.3 * (SLOT * .86) / CUP_CUT_H * (1184 / 1172);   // flying tile scale that equals the slot's first frame (k0 1.3)
const FX = (I, anticip, compact = false) => ({ I, anticip, compact, k0: 1.3, r0: -.12 });
const START = { A: T_NAMES + .63, D: T_NAMES + .63 };          // the films begin with the tags already shown

// ===================================================================================================================
// A — Lift: the clean outline lights round the cup, it lifts off; the ways to say it appear under it; choose; the 図鑑
// opens underneath and the sticker flies into its slot.
function conceptA(t) {
  const C = C0, cc = cupCenter(), P = C + 1.5, I = P + 1.9, OPEN = P + .7;
  CUES.A = Object.assign({ start: START.A }, { tap: T_TAP, C, P, voice: P + .12, open: OPEN, scroll0: P + .85, scroll1: P + 1.45, anticip: P + 1.4, launch: P + 1.58, I, end: I + 2.5 });
  const lift = sp(t, C + .22, .55, .78);
  const back = E.inOutCubic(seg(t, C + .2, C + .7));
  photoBase(t, { blur: 26 * back, bright: 1 - .45 * back, scale: 1 - .05 * back, focus: cc });
  makeBlur(); ctx.drawImage(BG, 0, 0);
  tagsSettled(t, { cupAlpha: 1, otherAlpha: 1 - seg(t, C, C + .2), cupPress: cupTagPress(t), hideCup: seg(t, C, C + .12) });
  topPill(t, -1, C, '覚えたいことばをタップ', { icon: 'sparkles' });
  // clean rim light round the cup the moment its cut-out is used
  inkSweep(shapeOf('cup'), E.inOutCubic(seg(t, C + .02, C + .34)), 1 - seg(t, C + .34, C + .6));
  // dex page rising underneath
  const sy0 = scrollToCat(4), pageUp = sp(t, OPEN, .5, .9), top = lerp(H + 60, 0, clamp(pageUp));
  let slotXY = null;
  if (t > OPEN) slotXY = drawDexPage(t, { top: Math.max(0, top), sy: scrollAt(t, P + .85, P + 1.45, sy0, 0), vy: scrollVel(t, P + .85, P + 1.45, sy0, 0), fx: FX(I, P + 1.4) });
  // the sticker
  const A_POS = [540, 800], A_S = .5, HOVER = [800, 1760], HS = .3;
  if (t >= C + .2 && t < I) {
    const L = clamp(lift, 0, 1.2);
    let cx = lerp(cc[0], A_POS[0], L), cy = lerp(cc[1], A_POS[1], L), s = lerp(1, A_S, L), r = 0;
    const toHover = E.inOutCubic(seg(t, OPEN, OPEN + .55)); cx = lerp(cx, HOVER[0], toHover); cy = lerp(cy, HOVER[1], toHover); s = lerp(s, HS, toHover);
    cy += Math.sin((t - C) * 2.4) * 8 * seg(t, C + .8, C + 1.2);
    const wind = Math.sin(Math.PI * seg(t, P + 1.45, P + 1.6)) * .08;          // anticipation: a little gather before the throw
    s *= 1 + wind;
    const fly = seg(t, P + 1.58, I), e = E.inCubic(fly);
    const border = 22 * E.outCubic(seg(t, C + .3, C + .66));
    const stk = sticker({ border, sheen: seg(t, C + .66, C + 1.2) });
    const tgt = slotXY || [180, 600];
    const p0 = [cx, cy], path = u => bez2(p0, [p0[0] - 80, p0[1] - 900], tgt, u);
    if (fly > 0) { flyTrail(stk, path, fly, s, ARRIVE_S, -.12); const p = path(e); cx = p[0]; cy = p[1]; s = lerp(s, ARRIVE_S, e); r = -.12 * e; }
    shadowTile(cx, cy, s, .5 * clamp(L) * (1 - fly), 34 * clamp(L));
    placeTile(stk, cx, cy, s, r, 1);
  }
  // choosing the way to say it (under the sticker), then the chosen word
  const pickXY = pickerGlass(t, C + .5, P, 1340, { out: E.inOutCubic(seg(t, P + .1, P + .4)) });
  const wordIn = E.outCubic(seg(t, P + .08, P + .42)), wordOut = seg(t, OPEN - .05, OPEN + .2);
  if (wordIn > 0 && wordOut < 1) {
    const from = pickXY || [300, 1560], fs = 60, ts = 128;
    const x = lerp(from[0] - 30, W / 2, wordIn), y = lerp(from[1] + 10, 1250, wordIn), sz = lerp(fs, ts, wordIn);
    ctx.save(); ctx.globalAlpha = 1 - wordOut;
    zyDraw(PICK_U, x, y, sz, { color: '#fff', zcolor: 'rgba(255,255,255,0.85)', align: 'center' });
    text(PICK.mean, W / 2, 1350, { w: 500, size: 42, color: 'rgba(255,255,255,0.9)', alpha: E.outCubic(seg(t, P + .3, P + .5)) });
    text(PICK.note, W / 2, 1410, { w: 600, size: 32, color: 'rgba(160,210,255,0.95)', alpha: E.outCubic(seg(t, P + .36, P + .56)) });
    ctx.restore();
  }
  tabBar({ sel: t > OPEN ? 1 : 2, alpha: t < OPEN ? 1 - seg(t, C + .3, C + .55) : E.outCubic(seg(t, OPEN + .2, OPEN + .5)), dy: t > OPEN ? (1 - E.outCubic(seg(t, OPEN + .2, OPEN + .5))) * 80 : 0, t });
  goalToast(t, I + .85, 99);
  finger(tagFinger[0], tagFinger[1], t, T_TAP - .22, T_TAP);
  if (pickXY) finger(pickXY[0], pickXY[1], t, P - .3, P);
  statusBar(t > OPEN + .2); homeIndicator(t > OPEN + .2);
}

// ===================================================================================================================
// D — Index: the photo clears into the app's own page (light, with the soft blue halo of the word page); the cup floats
// in it; the card *is* the choice (the usual word largest, the other ways below, the app's white card and blue);
// choosing files it straight into its slot in the full 図鑑.
const D_POS = [540, 560], D_S = .34;
const D_CARD = { x: 40, y: 1150, w: W - 80 };
function conceptD(t) {
  const C = C0, P = C + 1.6, I = P + 1.35;
  CUES.D = Object.assign({ start: START.D }, { tap: T_TAP, C, melt: C + .05, card: C + .45, P, voice: P + .12, open: P + .45, scroll0: P + .55, scroll1: P + 1.1, anticip: P + 1.0, launch: P + .95, I, end: I + 2.5 });
  const cc = cupCenter();
  const melt = E.inOutCubic(seg(t, C + .05, C + .6)), toDex = E.inOutCubic(seg(t, P + .45, P + .85));
  photoBase(t, { blur: 40 * melt, bright: 1 + .06 * melt, scale: 1 + .08 * melt, focus: cc });
  if (melt > 0) {
    bgx.save(); bgx.globalAlpha = melt;
    bgx.fillStyle = BG_APP; bgx.fillRect(0, 0, W, H);
    // the word page's hero halo (detail page: #EAF4FF), a little stronger where the cup floats
    const r = bgx.createRadialGradient(D_POS[0], D_POS[1] + 20, 0, D_POS[0], D_POS[1] + 20, 620);
    r.addColorStop(0, '#DDEEFF'); r.addColorStop(.55, 'rgba(234,244,255,0.75)'); r.addColorStop(1, 'rgba(234,244,255,0)');
    bgx.fillStyle = r; bgx.fillRect(0, 0, W, H);
    bgx.restore();
  }
  makeBlur(); ctx.drawImage(BG, 0, 0);
  tagsSettled(t, { otherAlpha: 1 - seg(t, C, C + .15), cupAlpha: 1 - seg(t, C, C + .15), cupPress: cupTagPress(t) });
  topPill(t, -1, C, '覚えたいことばをタップ', { icon: 'sparkles' });
  let slotXY = null;
  if (toDex > 0) slotXY = drawDexPage(t, { top: (1 - toDex) * 140, alpha: toDex, sy: scrollAt(t, P + .55, P + 1.1, scrollToCat(3), 0), vy: scrollVel(t, P + .55, P + 1.1, scrollToCat(3), 0), fx: FX(I, P + 1.0) });
  // the card (the choice), in the app's own components: white card, hairline border, blue selection, blue NEW chip
  const out = E.inOutCubic(seg(t, P + .3, P + .55));
  if (t > C + .4 && out < 1) {
    ctx.save(); ctx.globalAlpha = 1 - out; const k = 1 - .06 * out; ctx.translate(540, D_CARD.y); ctx.scale(k, k); ctx.translate(-540, -D_CARD.y);
    const a1 = E.outCubic(seg(t, C + .45, C + .7)) * (1 - E.inOutCubic(seg(t, P + .02, P + .16))), rise = (1 - E.outCubic(seg(t, C + .45, C + .7))) * 30;
    ctx.save(); ctx.translate(0, rise); ctx.globalAlpha *= a1;
    ctx.fillStyle = BLUE; rr(64, 900, 120, 52, 26); ctx.fill(); text('NEW', 124, 936, { w: 800, size: 26, f: FONT_UI, color: '#fff', ls: 2 });
    text('No.001 · 飲み物', 206, 937, { w: 600, size: 30, color: MUTED, align: 'left' });
    text('覚える言い方を選ぶ', 64, 1050, { w: 800, size: 50, color: INK, align: 'left' });
    text('写っている物：タピオカミルクティー', 64, 1104, { w: 500, size: 30, color: MUTED, align: 'left' });
    ctx.restore();
    // the list card
    const sel = seg(t, P + .06, P + .26), press = seg(t, P, P + .06) * (1 - seg(t, P + .12, P + .24));
    const sizes = [84, 64, 64], hs = VAR.map((v, i) => pickRow(v, 0, 0, D_CARD.w, t, { size: sizes[i], alpha: 0 })), total = hs.reduce((a, b) => a + b, 0);
    const cardIn = E.outCubic(seg(t, C + .5, C + .82));
    ctx.save(); ctx.globalAlpha *= cardIn; ctx.translate(0, (1 - cardIn) * 40);
    ctx.save(); ctx.shadowColor = 'rgba(15,40,80,0.08)'; ctx.shadowBlur = 40; ctx.shadowOffsetY = 12; ctx.fillStyle = '#fff'; rr(D_CARD.x, D_CARD.y, D_CARD.w, total, 48); ctx.fill(); ctx.restore();
    ctx.strokeStyle = '#E0E5EB'; ctx.lineWidth = 2.5; rr(D_CARD.x, D_CARD.y, D_CARD.w, total, 48); ctx.stroke();
    let cy = D_CARD.y;
    VAR.forEach((v, i) => {
      const ri = E.outCubic(seg(t, C + .58 + i * .07, C + .9 + i * .07)), isPick = v === PICK;
      ctx.save(); ctx.translate(0, (1 - ri) * 18);
      pickRow(v, D_CARD.x, cy, D_CARD.w, t, { size: sizes[i], pal: PAL.light, alpha: ri * (isPick ? 1 : 1 - sel * .55), sel: isPick ? sel : 0, press: isPick ? press : 0 });
      ctx.restore();
      if (isPick) CUES.D.pickXY = [D_CARD.x + D_CARD.w * .4, cy + hs[i] / 2];
      if (i < 2) { ctx.save(); ctx.globalAlpha *= ri; ctx.fillStyle = '#E0E5EB'; ctx.fillRect(D_CARD.x + 30, cy + hs[i], D_CARD.w - 60, 2); ctx.restore(); }
      cy += hs[i];
    });
    ctx.restore();
    text('選ぶと、そのことばで図鑑に入ります', W / 2, cy + 70, { w: 500, size: 30, color: MUTED, alpha: E.outCubic(seg(t, C + .9, C + 1.1)) });
    ctx.restore();
  }
  // the cup
  if (t >= C && t < I) {
    const pose = sp(t, C + .05, .62, .8), bob = Math.sin((t - C) * 2.6) * 10 * seg(t, C + .6, C + 1) * (1 - toDex);
    let cx = lerp(cc[0], D_POS[0], clamp(pose)), cy = lerp(cc[1], D_POS[1], clamp(pose)) + bob, s = lerp(1, D_S, clamp(pose)), r = 0;
    const fly = seg(t, P + .95, I), e = E.inCubic(fly);
    const tgt = slotXY || [180, 600];
    const path = u => bez2([D_POS[0], D_POS[1]], [D_POS[0] + 80, D_POS[1] - 260], tgt, u);
    const border = 20 * E.outCubic(seg(t, P + .5, P + .8));
    const stk = sticker({ border, sheen: seg(t, C + .6, C + 1.1) });
    if (fly > 0) { flyTrail(stk, path, fly, D_S, ARRIVE_S, -.12); const p = path(e); cx = p[0]; cy = p[1]; s = lerp(D_S, ARRIVE_S, e); r = -.12 * e; }
    // a neutral contact shadow on the light page (narrower when the cup bobs up)
    if (fly <= 0) { const sa = .2 * clamp(pose) * (1 - toDex); ctx.save(); ctx.globalAlpha = sa; ctx.fillStyle = '#0F2850'; ctx.filter = 'blur(16px)'; ctx.beginPath(); ctx.ellipse(cx, D_POS[1] + 236 - bob * .3, 112 - bob, 18, 0, 0, Math.PI * 2); ctx.fill(); ctx.filter = 'none'; ctx.restore(); }
    placeTile(stk, cx, cy, s, r, 1);
  }
  // the chosen word appears by the cup while the voice plays
  const wa = E.outCubic(seg(t, P + .12, P + .3)) * (1 - seg(t, P + .7, P + .9));
  if (wa > 0) { ctx.save(); ctx.globalAlpha = wa; zyDraw(PICK_U, W / 2, 960, 112, { t, t0: P + .12, color: INK, zcolor: MUTED }); text(PICK.mean, W / 2, 1040, { w: 500, size: 36, color: MUTED, alpha: E.outCubic(seg(t, P + .24, P + .4)) }); ctx.restore(); }
  const tabIn = E.outCubic(seg(t, P + .7, P + 1.0));
  tabBar({ sel: t > P + .5 ? 1 : 2, alpha: t < C + .5 ? 1 - seg(t, C + .05, C + .3) : tabIn, dy: (1 - tabIn) * 100, t });
  goalToast(t, I + .85, 99);
  finger(tagFinger[0], tagFinger[1], t, T_TAP - .22, T_TAP);
  const pk = CUES.D.pickXY; if (pk) finger(pk[0], pk[1], t, P - .3, P);
  statusBar(melt > .5); homeIndicator(melt > .5);
}
