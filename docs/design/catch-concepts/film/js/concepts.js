// concepts.js — A Lift / B Peel / C Instant / D Index. Shared: the analysis (sketch → ink), choosing the way to say it,
// and the landing in the full 図鑑. Each concept also publishes its key times (CUES) for the sound mix and haptics.
const CUES = {};
const cupTag = TAGS[0];
const cupTagPress = t => seg(t, T_TAP, T_TAP + .06) * (1 - seg(t, T_TAP + .1, T_TAP + .2));
const tagFinger = [cupTag.p[0] + 40, cupTag.p[1] - 86];
const PICK_U = PICK.u;

// fast scroll from one offset to another: quick start, long settle (like scrollTo with a spring)
function scrollAt(t, t0, t1, a, b) { const u = seg(t, t0, t1); const e = 1 - Math.pow(1 - E.inOutSine(Math.min(1, u * 1.15)) , 2.2); return lerp(a, b, clamp(e)); }
function scrollVel(t, t0, t1, a, b) { return (scrollAt(t, t0, t1, a, b) - scrollAt(t - 1 / 60, t0, t1, a, b)); }
// the flying sticker's trail
function flyTrail(stk, path, fly, s0, s1, r1, n = 3) {
  for (let k = n; k >= 1; k--) { const fk = clamp(fly - k * .05); if (fk <= 0) continue; const e = E.inCubic(fk); const p = path(e); placeTile(stk, p[0], p[1], lerp(s0, s1, e), r1 * e, .14 / k); }
}
const ARRIVE_S = 1.3 * (SLOT * .86) / CUP_CUT_H * (1184 / 1172);   // flying tile scale that equals the slot's first frame (k0 1.3)
const FX = (I, anticip, compact = false) => ({ I, anticip, compact, k0: 1.3, r0: -.12 });

// ===================================================================================================================
// A — Lift: the clean outline inks round the cup, it lifts off; the ways to say it appear under it; choose; the 図鑑
// opens underneath and the sticker flies into its slot.
function conceptA(t) {
  const C = C0, cc = cupCenter(), P = C + 1.5, I = P + 1.9, OPEN = P + .7;
  CUES.A = { tap: T_TAP, C, P, voice: P + .12, open: OPEN, scroll0: P + .85, scroll1: P + 1.45, anticip: P + 1.4, launch: P + 1.58, I, end: I + 2.5 };
  const lift = sp(t, C + .22, .55, .78);
  const back = E.inOutCubic(seg(t, C + .2, C + .7));
  bgx.clearRect(0, 0, W, H);
  drawPhoto(bgx, t, { blur: 26 * back, bright: 1 - .45 * back, scale: 1 - .05 * back, focus: cc });
  makeBlur(); ctx.drawImage(BG, 0, 0);
  capFlash(t); camChrome(t);
  analysis(t, { cupAlpha: 1, otherAlpha: 1 - seg(t, C, C + .2), cupPress: cupTagPress(t), hideCup: seg(t, C, C + .12) });
  analysisPills(t, C);
  // clean rim light — the analysis outline inked for real now that the cut is used
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
// B — Peel: choose on a sheet; the die-cut runs round the cup; holographic flash; the finger peels it all the way off
// (Blender render), it turns face-up; the 図鑑 rises and the finger places it into its slot.
const B_REST = [600, 1250], B_S = .62;
function conceptB(t) {
  const P = T_TAP + 1.45, C = P + .35, PEEL0 = C + 1.38, NA = PEEL ? PEEL.na : 66, NB = PEEL ? PEEL.nb : 27;
  const PEEL1 = PEEL0 + NA / 60, FLIP1 = PEEL1 + NB / 60, OPEN = FLIP1 + .02, I = OPEN + 1.06;
  CUES.B = { tap: T_TAP, sheet: T_TAP + .06, P, C, voice: C + .7, peel0: PEEL0, peel1: PEEL1, flip1: FLIP1, open: OPEN, scroll0: OPEN + .1, scroll1: OPEN + .65, anticip: OPEN + .6, grab: OPEN + .52, I, end: I + 2.5 };
  const cc = cupCenter();
  const dream = E.inOutCubic(seg(t, C + .3, C + .8)), dim = seg(t, T_TAP + .06, T_TAP + .4) * (1 - seg(t, P + .15, P + .5));
  bgx.clearRect(0, 0, W, H);
  drawPhoto(bgx, t, { blur: 40 * dream, sat: 1 + .3 * dream, bright: 1 - .14 * dream - .35 * dim, scale: 1 + .05 * dream, focus: cc });
  makeBlur(); ctx.drawImage(BG, 0, 0);
  capFlash(t); camChrome(t);
  analysis(t, { otherAlpha: 1 - seg(t, P + .2, P + .45), cupAlpha: 1 - seg(t, P + .2, P + .45), cupPress: cupTagPress(t) });
  analysisPills(t, T_TAP + .05);
  // die-cut line (the analysis outline turned into a cut line)
  const cut = seg(t, C + .04, C + .6), cutFade = 1 - seg(t, C + .62, C + .8);
  if (cut > 0 && cutFade > 0) dieCut(t, E.inOutCubic(cut), cutFade);
  // dex page
  const sy0 = scrollToCat(3), pageUp = sp(t, OPEN, .5, .9), top = lerp(H + 60, 0, clamp(pageUp));
  let slotXY = null;
  if (t > OPEN) slotXY = drawDexPage(t, { top: Math.max(0, top), sy: scrollAt(t, OPEN + .1, OPEN + .65, sy0, 0), vy: scrollVel(t, OPEN + .1, OPEN + .65, sy0, 0), fx: FX(I, OPEN + .6) });
  // the sticker
  const form = E.outCubic(seg(t, C + .5, C + .8)), pose = sp(t, C + .55, .6, .82);
  let fingerXY = null;
  if (t >= C + .45 && t < I) {
    if (t < PEEL0 + 4 / 60 || !PEEL) {
      const cx = lerp(cc[0], B_REST[0], clamp(pose)), cy = lerp(cc[1], B_REST[1], clamp(pose)), s = lerp(1, B_S, clamp(pose));
      const stk = sticker({ border: 24 * form, holo: seg(t, C + .88, C + 1.5) });
      shadowTile(cx, cy, s, .45 * form, 26);
      const xf = PEEL ? 1 - seg(t, PEEL0, PEEL0 + 4 / 60) : 1;          // crossfade into the rendered peel
      placeTile(stk, cx, cy, s, 0, xf);
      if (PEEL && t >= PEEL0) peelFrame(t, PEEL0, 1 - xf);
    } else if (t < FLIP1) { fingerXY = peelFrame(t, PEEL0, 1); }
    else {
      // free sticker presented face-up (the render's last pose), then picked up and placed into the slot
      const F = PEEL.final, grab = OPEN + .52, place = seg(t, grab + .1, I), e = E.inOutCubic(place);
      const hov = Math.sin((t - FLIP1) * 2.2) * 6 * (1 - place);
      const tgt = slotXY || [180, 600];
      const path = u => bez2([F.center[0], F.center[1] + hov], [F.center[0] - 60, F.center[1] - 420], tgt, u);
      const p = path(e), s = lerp(F.scale, ARRIVE_S, e), r = lerp(F.rot, -.12, e);
      const stk = sticker({ border: 24 });
      shadowTile(p[0], p[1], s, .35 * (1 - e), 40);
      placeTile(stk, p[0], p[1], s, r, 1);
      if (t > grab - .2) fingerXY = [p[0] + 30, p[1] + 60];
    }
  }
  // the chosen word over the sticker
  const wa = E.outCubic(seg(t, C + .55, C + .85)) * (1 - seg(t, OPEN, OPEN + .2));
  if (wa > 0) { ctx.save(); ctx.globalAlpha = wa; zyDraw(PICK_U, W / 2, 560, 112, { t, t0: C + .55, color: '#fff', zcolor: 'rgba(255,255,255,0.85)' }); text(PICK.mean, W / 2, 648, { w: 500, size: 40, color: 'rgba(255,255,255,0.9)' }); ctx.restore(); }
  const hintA = seg(t, C + 1.0, C + 1.2) * (1 - seg(t, PEEL0 + .1, PEEL0 + .3));
  if (hintA > 0) { const w = 560; glass(W / 2 - w / 2, 1830, w, 92, 46, { alpha: hintA, tint: 'rgba(255,255,255,0.7)' }); text('指ではがして図鑑へ', W / 2, 1890, { w: 700, size: 36, alpha: hintA }); }
  // the sheet to choose the way to say it
  tabBar({ sel: t > OPEN ? 1 : 2, alpha: t < OPEN ? 1 - seg(t, T_TAP + .05, T_TAP + .3) : E.outCubic(seg(t, OPEN + .2, OPEN + .5)), dy: t > OPEN ? (1 - E.outCubic(seg(t, OPEN + .2, OPEN + .5))) * 80 : 0, t });
  const pickXY = pickerSheet(t, T_TAP + .06, P, P + .18);
  goalToast(t, I + .85, 99);
  finger(tagFinger[0], tagFinger[1], t, T_TAP - .22, T_TAP);
  if (pickXY) finger(pickXY[0], pickXY[1], t, P - .3, P);
  if (fingerXY && t >= PEEL0 - .1 && t < FLIP1) finger(fingerXY[0], fingerXY[1], t, PEEL0 - .12, PEEL0 - .02, PEEL1 - .02);
  if (t > PEEL0 - .3 && t < PEEL0) { const f0 = PEEL ? PEEL.frames[0].finger : [700, 1500]; finger(f0[0], f0[1], t, PEEL0 - .3, PEEL0 - .02, PEEL0 + .1); }
  if (fingerXY && t >= OPEN) finger(fingerXY[0], fingerXY[1], t, OPEN + .3, OPEN + .52, I + .02);
  statusBar(t > OPEN + .2); homeIndicator(t > OPEN + .2);
}
// the rendered peel: backing paper where the sticker has left (half-plane behind the fold), then the frame
function peelFrame(t, t0, alpha) {
  const n = PEEL.img.length, i = clamp(Math.floor((t - t0) * 60), 0, n - 1), fr = PEEL.frames[i];
  if (fr.phase === 'a' || i < PEEL.na) {
    const c = M.cup, d = PEEL.d, p0 = PEEL.p0, f = fr.fold;
    ctx.save(); ctx.globalAlpha *= alpha; ctx.translate(B_REST[0], B_REST[1]); ctx.scale(B_S, B_S); ctx.translate(-c.tw / 2, -c.th / 2);
    const far = 4000, nx = -d[1], ny = d[0], bx = p0[0] + d[0] * f, by = p0[1] + d[1] * f;
    ctx.beginPath(); ctx.moveTo(bx + nx * far, by + ny * far); ctx.lineTo(bx - nx * far, by - ny * far); ctx.lineTo(bx - nx * far - d[0] * far, by - ny * far - d[1] * far); ctx.lineTo(bx + nx * far - d[0] * far, by + ny * far - d[1] * far); ctx.closePath(); ctx.clip();
    ctx.drawImage(linerSil(), 0, 0); ctx.restore();
  } else { // after it is free, the backing paper stays on the photo and fades as the page comes
    const c = M.cup; ctx.save(); ctx.globalAlpha *= alpha; ctx.translate(B_REST[0], B_REST[1]); ctx.scale(B_S, B_S); ctx.translate(-c.tw / 2, -c.th / 2); ctx.drawImage(linerSil(), 0, 0); ctx.restore();
  }
  ctx.save(); ctx.globalAlpha *= alpha; ctx.drawImage(PEEL.img[i], 0, 0); ctx.restore();
  return fr.finger;
}
let LINER = null;
function linerSil() {
  if (LINER) return LINER; const c = M.cup; LINER = document.createElement('canvas'); LINER.width = c.tw; LINER.height = c.th; const x = LINER.getContext('2d');
  x.drawImage(A.b24, 0, 0); x.globalCompositeOperation = 'source-in'; const g = x.createLinearGradient(0, 0, c.tw, c.th); g.addColorStop(0, '#EEEAE3'); g.addColorStop(1, '#DEDAD2'); x.fillStyle = g; x.fillRect(0, 0, c.tw, c.th);
  x.globalCompositeOperation = 'source-over'; x.globalAlpha = .07; for (let i = 0; i < 900; i++) { x.fillStyle = i % 2 ? '#000' : '#fff'; x.fillRect(rnd(i) * c.tw, rnd(i + 99) * c.th, 2, 2); }
  return LINER;
}
function dieCut(t, p, alpha) {
  const pts = M.cup.cutline, n = pts.length; let top = 0; for (let i = 1; i < n; i++) if (pts[i][1] < pts[top][1]) top = i;
  const m = Math.floor(n * p); if (m < 2) return;
  ctx.save(); ctx.globalAlpha *= alpha; ctx.lineCap = 'round'; ctx.lineJoin = 'round';
  ctx.beginPath(); for (let j = 0; j <= m; j++) { const q = pts[(top + j) % n]; j ? ctx.lineTo(q[0], q[1]) : ctx.moveTo(q[0], q[1]); }
  ctx.setLineDash([22, 14]); ctx.lineDashOffset = -t * 120; ctx.strokeStyle = '#fff'; ctx.lineWidth = 7; ctx.shadowColor = 'rgba(0,0,0,0.35)'; ctx.shadowBlur = 8; ctx.stroke();
  const h = pts[(top + m) % n]; ctx.setLineDash([]); ctx.globalCompositeOperation = 'lighter';
  const g = ctx.createRadialGradient(h[0], h[1], 0, h[0], h[1], 50); g.addColorStop(0, 'rgba(255,255,255,1)'); g.addColorStop(.3, 'rgba(255,240,190,0.7)'); g.addColorStop(1, 'rgba(255,240,190,0)');
  ctx.fillStyle = g; ctx.beginPath(); ctx.arc(h[0], h[1], 50, 0, Math.PI * 2); ctx.fill();
  for (let k = 0; k < 5; k++) { const a = rnd(k + Math.floor(t * 30)) * Math.PI * 2, d = 20 + rnd(k * 3 + Math.floor(t * 30)) * 40; ctx.fillStyle = 'rgba(255,245,210,0.9)'; ctx.beginPath(); ctx.arc(h[0] + Math.cos(a) * d, h[1] + Math.sin(a) * d, 3, 0, Math.PI * 2); ctx.fill(); }
  ctx.restore();
}

// ===================================================================================================================
// C — Instant: the tag opens a small popover; choose; the cup pops in place, the tag answers; the 図鑑 peeks up as a
// sheet, a small copy lands in its slot; the sheet drops and the camera is ready for the next word.
function conceptC(t) {
  const P = T_TAP + 1.0, C = P + .06, I = C + .78, DOWN = I + 1.3;
  CUES.C = { tap: T_TAP, pop0: T_TAP + .04, P, C, voice: C + .12, open: C + .3, scroll0: C + .36, scroll1: C + .66, anticip: C + .55, I, down: DOWN, end: DOWN + 1.0 };
  const cc = cupCenter();
  const pop = sp(t, C + .02, .32, .55), back = seg(t, C + .34, C + .6);
  const dim = E.outCubic(seg(t, T_TAP + .04, T_TAP + .2)) * (1 - E.inOutCubic(seg(t, C + .35, C + .65)));
  bgx.clearRect(0, 0, W, H);
  drawPhoto(bgx, t, { bright: 1 - .3 * dim });
  makeBlur(); ctx.drawImage(BG, 0, 0);
  capFlash(t); camChrome(t);
  analysis(t, { otherAlpha: 1 - .5 * dim, cupAlpha: t < C ? 1 : 0, cupPress: cupTagPress(t) });
  analysisPills(t, T_TAP);
  if (t > C && back < 1) {
    const k = clamp(pop, 0, 1.3), s = 1 + .07 * Math.sin(Math.min(1, k) * Math.PI / 2) * (1 - back) + .02 * (k - 1) * (1 - back);
    const border = 18 * Math.min(1, k * 1.4) * (1 - back);
    shadowTile(cc[0], cc[1], s, .35 * Math.min(1, k) * (1 - back), 20);
    placeTile(sticker({ border, sheen: seg(t, C + .05, C + .4) }), cc[0], cc[1] - 14 * Math.min(1, k) * (1 - back), s, 0, 1);
  }
  instantTag(t, C);
  // the peek sheet
  const sheetUp = sp(t, C + .3, .42, .86), down = E.inCubic(seg(t, DOWN, DOWN + .32));
  const top = lerp(H + 60, 600, clamp(sheetUp)) + down * (H - 560);
  let slotXY = null;
  if (t > C + .3 && top < H) slotXY = drawDexPage(t, { top, sy: scrollAt(t, C + .36, C + .66, scrollToCat(2), 0), vy: scrollVel(t, C + .36, C + .66, scrollToCat(2), 0), fx: FX(I, C + .55, true), sheet: true });
  // mini copy flies into the slot
  const fly = seg(t, C + .3, I), e = E.inCubic(fly);
  if (fly > 0 && fly < 1) {
    const tgt = slotXY || [180, 1200], p0 = [cc[0], cc[1] - 20], stk = sticker({ border: 18 });
    const path = u => bez2(p0, [p0[0] - 360, p0[1] - 300], tgt, u);
    flyTrail(stk, path, fly, .42, ARRIVE_S, -.12);
    const p = path(e); placeTile(stk, p[0], p[1], lerp(.42, ARRIVE_S, e), -.12 * e, 1);
  }
  if (t < DOWN + .3) goalToast(t, I + .45, DOWN - .1, { y: H - 300 });
  const pickXY = pickerPopover(t, T_TAP + .04, P, cupTag);
  tabBar({ sel: 2, alpha: 1 - seg(t, T_TAP, T_TAP + .2) * (1 - seg(t, DOWN + .2, DOWN + .5)), t });
  if (t > DOWN + .3) topPill(t, DOWN + .3, 99, '次のことばもタップできます', { icon: 'sparkles' });
  finger(tagFinger[0], tagFinger[1], t, T_TAP - .22, T_TAP);
  if (pickXY) finger(pickXY[0], pickXY[1], t, P - .3, P);
  statusBar(top < 300); homeIndicator(top < 1400);
}
function instantTag(t, doneT) {
  const tag = cupTag;
  if (t < doneT) return;
  const u = sp(t, doneT, .38, .7), a = clamp(u * 1.5);
  const w = 560, h = 236, x = tag.p[0] - w / 2, y = tag.p[1] - 30 - h + (1 - Math.min(1, u)) * 40;
  ctx.save(); const k = lerp(.8, 1, Math.min(1.08, u)); ctx.translate(tag.p[0], tag.p[1] - 30); ctx.scale(k, k); ctx.translate(-tag.p[0], -(tag.p[1] - 30));
  glass(x, y, w, h, 48, { alpha: a, tint: 'rgba(255,255,255,0.84)' });
  ctx.globalAlpha *= a;
  ctx.fillStyle = '#00A95C'; ctx.beginPath(); ctx.arc(x + 62, y + 62, 30, 0, Math.PI * 2); ctx.fill(); icon('check', x + 62, y + 63, 40, '#fff', 8);
  text('図鑑に追加', x + 108, y + 74, { w: 700, size: 32, color: '#00A95C', align: 'left' });
  speakerBtn(x + w - 66, y + 62, 36, t, doneT + .1, {});
  zyDraw(PICK_U, tag.p[0], y + 176, 80, { t, t0: doneT + .02, stagger: .04, dur: .2 });
  text(PICK.mean, tag.p[0], y + 214, { w: 500, size: 26, color: MUTED, alpha: E.outCubic(seg(t, doneT + .1, doneT + .3)) });
  ctx.restore();
  tagAnchor(tag, t, 1);
}

// ===================================================================================================================
// D — Index: the photo melts into a warm page; the cup floats; the card *is* the choice (the usual word largest, the
// other ways below); choosing files it straight into its slot in the full 図鑑.
const D_POS = [540, 540], D_S = .34;
function conceptD(t) {
  const C = C0, P = C + 1.6, I = P + 1.35;
  CUES.D = { tap: T_TAP, C, melt: C + .05, card: C + .45, P, voice: P + .12, open: P + .45, scroll0: P + .55, scroll1: P + 1.1, anticip: P + 1.0, launch: P + .95, I, end: I + 2.5 };
  const cc = cupCenter();
  const melt = E.inOutCubic(seg(t, C + .05, C + .6)), toDex = E.inOutCubic(seg(t, P + .45, P + .85));
  bgx.clearRect(0, 0, W, H);
  drawPhoto(bgx, t, { blur: 40 * melt, bright: 1 + .1 * melt, scale: 1 + .08 * melt, focus: cc });
  if (melt > 0) {
    bgx.save(); bgx.globalAlpha = melt;
    const g = bgx.createLinearGradient(0, 0, 0, H); g.addColorStop(0, '#FBF3EA'); g.addColorStop(.55, '#F4E6D6'); g.addColorStop(1, '#EFDCC8'); bgx.fillStyle = g; bgx.fillRect(0, 0, W, H);
    const r = bgx.createRadialGradient(540, 620, 0, 540, 620, 700); r.addColorStop(0, 'rgba(255,255,255,0.85)'); r.addColorStop(1, 'rgba(255,255,255,0)'); bgx.fillStyle = r; bgx.fillRect(0, 0, W, H);
    bgx.restore();
  }
  makeBlur(); ctx.drawImage(BG, 0, 0);
  capFlash(t); camChrome(t);
  analysis(t, { otherAlpha: 1 - seg(t, C, C + .15), cupAlpha: 1 - seg(t, C, C + .15), cupPress: cupTagPress(t) });
  analysisPills(t, C);
  let slotXY = null;
  if (toDex > 0) slotXY = drawDexPage(t, { top: (1 - toDex) * 140, alpha: toDex, sy: scrollAt(t, P + .55, P + 1.1, scrollToCat(3), 0), vy: scrollVel(t, P + .55, P + 1.1, scrollToCat(3), 0), fx: FX(I, P + 1.0) });
  // the card (the choice)
  const out = E.inOutCubic(seg(t, P + .3, P + .55));
  if (t > C + .4 && out < 1) {
    ctx.save(); ctx.globalAlpha = 1 - out; const k = 1 - .06 * out; ctx.translate(540, 1000); ctx.scale(k, k); ctx.translate(-540, -1000);
    const a1 = E.outCubic(seg(t, C + .45, C + .7));
    ctx.save(); ctx.globalAlpha *= a1; ctx.fillStyle = '#A0522D'; rr(64, 1006, 132, 56, 28); ctx.fill(); text('NEW', 130, 1045, { w: 800, size: 28, f: FONT_UI, color: '#fff', ls: 2 });
    text('No.001 · 🧋 飲み物', 222, 1046, { w: 600, size: 30, color: '#8A6A4C', align: 'left' }); ctx.restore();
    text('覚える言い方を選ぶ', 64, 1140, { w: 800, size: 46, color: '#2B1D12', align: 'left', alpha: a1 });
    const sel = seg(t, P + .06, P + .26), press = seg(t, P, P + .06) * (1 - seg(t, P + .12, P + .24));
    let cy = 1176; const x = 40, w = W - 80;
    VAR.forEach((v, i) => {
      const ri = E.outCubic(seg(t, C + .55 + i * .07, C + .87 + i * .07)), isPick = v === PICK;
      const hgt = pickRow(v, x, cy, w, t, { size: i ? 64 : 84, pal: PAL.warm, alpha: ri * (isPick ? 1 : 1 - sel * .6), sel: isPick ? sel : 0, press: isPick ? press : 0 });
      if (isPick) CUES.D.pickXY = [x + w * .4, cy + hgt / 2];
      if (i < 2) { ctx.save(); ctx.globalAlpha *= ri * .7; ctx.fillStyle = PAL.warm.line; ctx.fillRect(x + 30, cy + hgt, w - 60, 2); ctx.restore(); }
      cy += hgt;
    });
    text('選ぶと、そのことばで図鑑に入ります', W / 2, cy + 64, { w: 500, size: 30, color: '#8A6A4C', alpha: E.outCubic(seg(t, C + .9, C + 1.1)) });
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
    if (fly <= 0) { const sa = .25 * clamp(pose) * (1 - toDex); ctx.save(); ctx.globalAlpha = sa; ctx.fillStyle = '#5C3A1C'; ctx.filter = 'blur(18px)'; ctx.beginPath(); ctx.ellipse(cx, D_POS[1] + 236 - bob * .3, 110 - bob, 20, 0, 0, Math.PI * 2); ctx.fill(); ctx.filter = 'none'; ctx.restore(); }
    placeTile(stk, cx, cy, s, r, 1);
  }
  // the chosen word appears by the cup while the voice plays
  const wa = E.outCubic(seg(t, P + .1, P + .3)) * (1 - seg(t, P + .7, P + .9));
  if (wa > 0) { ctx.save(); ctx.globalAlpha = wa; zyDraw(PICK_U, W / 2, 920, 104, { t, t0: P + .1, color: '#2B1D12', zcolor: '#8A6A4C' }); ctx.restore(); }
  const tabIn = E.outCubic(seg(t, P + .7, P + 1.0));
  tabBar({ sel: t > P + .5 ? 1 : 2, alpha: t < C + .5 ? 1 - seg(t, C + .05, C + .3) : tabIn, dy: (1 - tabIn) * 100, t });
  goalToast(t, I + .85, 99);
  finger(tagFinger[0], tagFinger[1], t, T_TAP - .22, T_TAP);
  const pk = CUES.D.pickXY; if (pk) finger(pk[0], pk[1], t, P - .3, P);
  statusBar(melt > .5); homeIndicator(melt > .5);
}
