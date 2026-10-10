// detail.js — E: the word page and its AI wait. Same idea as the catch (下書き → 清書), different hand: blue pencil on
// paper, like an animator's blue-line rough before the clean-up. What is already known (the word, its reading, the
// meaning, the other ways to say it) is clean at once; only the AI-written sections are drafted, line by line, in the
// exact place their text will take — then inked top to bottom in one cascade when the answer lands.
const T_OPEN_E = .62, T_DETAIL = 1.05, T_DONE = T_DETAIL + 5.4;   // first open of a word: card generation ~5 s (P50 estimate)
const EX = [
  { zh: Z('我要一杯珍奶，半糖少冰。', 'ㄨㄛˇ ㄧㄠˋ ㄧˋ ㄅㄟ ㄓㄣ ㄋㄞˇ ㄅㄢˋ ㄊㄤˊ ㄕㄠˇ ㄅㄧㄥ'), ja: '珍奶を1杯、甘さ半分・氷少なめで。' },
  { zh: Z('這家的珍奶很好喝。', 'ㄓㄜˋ ㄐㄧㄚ ˙ㄉㄜ ㄓㄣ ㄋㄞˇ ㄏㄣˇ ㄏㄠˇ ㄏㄜ'), ja: 'この店の珍奶はおいしい。' },
];
const TIPS = ['注文では「珍奶」だけで通じる。', '甘さは 全糖・半糖・微糖・無糖、', '氷は 正常冰・少冰・去冰 で伝える。'];
const TRIVIA = ['1980年代に台湾で生まれた飲み物。', '台中と台南の店が元祖を名乗っている。'];
const PENC = '0,120,255';                  // blue pencil

// layout of the AI sections (y positions), shared by the draft and the clean text so the ink lands on the sketch
const DET = { x: 48, w: W - 96, sim: 1050, ex: 1388, tips: 1912, triv: 2240 };
function exLines() {   // [{kind, x, y, w, h, i}] for the example card
  const out = []; let y = DET.ex + 124;
  EX.forEach((e, i) => { const zw = zyWidth(e.zh, 46); out.push({ kind: 'zh', x: DET.x + 76, y, w: zw, h: 46, i }); out.push({ kind: 'ja', x: DET.x + 76, y: y + 52, w: measure(e.ja, 500, 30), h: 30, i }); y += 172; });
  return out;
}
function textLines(list, y0, size = 32) { return list.map((s, i) => ({ s, x: DET.x + 44, y: y0 + 112 + i * 58, w: measure(s, 500, size), h: size })); }

function sectionCard(y, h, title, iconName, { alpha = 1, lift = 0 } = {}) {
  ctx.save(); ctx.globalAlpha *= alpha;
  ctx.save(); ctx.shadowColor = `rgba(15,40,80,${.06 + .06 * lift})`; ctx.shadowBlur = 24 + 20 * lift; ctx.shadowOffsetY = 8 + 6 * lift; ctx.fillStyle = '#fff'; rr(DET.x, y, DET.w, h, 44); ctx.fill(); ctx.restore();
  ctx.strokeStyle = '#E6ECF3'; ctx.lineWidth = 2.5; rr(DET.x, y, DET.w, h, 44); ctx.stroke();
  text(title, DET.x + 44, y + 64, { w: 800, size: 34, align: 'left' });
  ctx.restore();
}
// how far the draft has grown at time t: lines start at a slowing pace (fast at first, then steady), never finishing
// before the answer — the pen is always somewhere
function draftStart(i) { return T_DETAIL + .25 + 2.1 * Math.log(1 + i * .4); }
// after the first pass, the pen goes over the lines again (a refining pass) so the page never just waits
const N_LINES = 10;
function refineStart(i) { return draftStart(N_LINES - 1) + .7 + i * .42; }
function drawDetail(t) {
  // backdrop: the 図鑑 page underneath (after the landing), the page zooms out of the slot
  const zoom = E.inOutQuart(seg(t, T_OPEN_E, T_DETAIL));
  if (zoom < 1) drawDexPage(t, { fx: FX(-10, -11) });
  const ts = targetSlot(), sx = ts.x, sy = ts.y;
  // the page grows out of the slot (iOS zoom transition)
  const x0 = lerp(sx, 0, zoom), y0 = lerp(sy, 0, zoom), w0 = lerp(SLOT, W, zoom), h0 = lerp(SLOT, H, zoom), r0 = lerp(44, 0, zoom);
  if (zoom > 0) {
    ctx.save(); ctx.fillStyle = BG_APP; ctx.shadowColor = 'rgba(0,0,0,0.2)'; ctx.shadowBlur = 60 * (1 - zoom); rr(x0, y0, w0, h0, r0); ctx.fill(); ctx.restore();
    ctx.save(); rr(x0, y0, w0, h0, r0); ctx.clip(); ctx.globalAlpha = seg(zoom, .55, 1); detailContent(t); ctx.restore();
  }
  // the cut-out travels from the slot to the hero position
  const hx = lerp(ts.cx, 540, zoom), hy = lerp(ts.cy, 470, zoom), hk = lerp(SLOT * .86, 420, zoom);
  const im = A.d_cup, f = hk / im.height;
  ctx.save(); ctx.shadowColor = 'rgba(0,30,70,0.25)'; ctx.shadowBlur = 12; ctx.shadowOffsetY = 10; ctx.drawImage(im, hx - im.width * f / 2, hy - im.height * f / 2, im.width * f, im.height * f); ctx.restore();
  finger(ts.cx + 20, ts.cy + 30, t, .3, .52);
  statusBar(true); homeIndicator(true);
}
function detailContent(t) {
  // hero backdrop + nav
  const g = ctx.createRadialGradient(540, 470, 0, 540, 470, 420); g.addColorStop(0, '#EAF4FF'); g.addColorStop(1, 'rgba(234,244,255,0)'); ctx.fillStyle = g; ctx.fillRect(0, 150, W, 700);
  ctx.save(); ctx.fillStyle = '#EEF2F7'; ctx.beginPath(); ctx.arc(96, 220, 44, 0, Math.PI * 2); ctx.fill(); icon('chevL', 92, 220, 40, INK, 8); ctx.restore();
  text('図鑑', 160, 232, { w: 600, size: 34, color: MUTED, align: 'left' });
  // the word (known): reading, register, meaning, the note — clean from the first frame
  zyDraw(PICK_U, 500, 820, 132, {});
  speakerBtn(820, 772, 50, t, T_DETAIL + .12, {});
  const chip = REG[PICK.reg], cw = measure(chip, 600, 26) + 34; ctx.fillStyle = '#EEF1F5'; rr(W / 2 - 300, 868, cw, 46, 23); ctx.fill(); text(chip, W / 2 - 300 + cw / 2, 900, { w: 600, size: 26, color: MUTED });
  text(PICK.mean, W / 2 - 300 + cw + 22, 902, { w: 500, size: 34, color: MUTED, align: 'left' });
  text(PICK.note, W / 2, 970, { w: 600, size: 30, color: '#0066CC' });
  // 似た言い方 (known from the candidates — no wait)
  sectionCard(DET.sim, 260, '似た言い方');
  [[VAR[0], 'ふだんの言い方'], [VAR[2], '大粒タピオカ']].forEach(([v, s], i) => {
    const y = DET.sim + 150 + i * 72; zyDraw(v.u, DET.x + 44, y, 46, { align: 'left', w: 600 });
    text(s, DET.x + DET.w - 44, y - 4, { w: 500, size: 30, color: MUTED, align: 'right' });
  });
  // AI sections: titles known; bodies drafted, then inked
  const done = t >= T_DONE, cas = t - T_DONE;
  const lift = E.outCubic(seg(t, T_DONE + .6, T_DONE + 1.0)) * (1 - seg(t, T_DONE + 1.2, T_DONE + 1.8));
  sectionCard(DET.ex, 480, '例文', null, { lift });
  sectionCard(DET.tips, 300, '使い方のコツ', null, { lift });
  sectionCard(DET.triv, 260, '豆知識', null, { lift });
  // status line under the word: what the AI is doing, honestly
  aiStatus(t);
  // drafts + ink, one sequence across the sections (top → bottom)
  const lines = [];
  exLines().forEach(l => lines.push(Object.assign({ sec: 'ex' }, l)));
  textLines(TIPS, DET.tips).forEach(l => lines.push(Object.assign({ sec: 'tips' }, l)));
  textLines(TRIVIA, DET.triv).forEach(l => lines.push(Object.assign({ sec: 'triv' }, l)));
  // speech bubbles for the two examples (drafted as soon as the section has started)
  [0, 1].forEach(i => {
    const by = DET.ex + 84 + i * 172, bh = 136, bw = DET.w - 88, bx = DET.x + 44;
    const st = draftStart(i * 2) - .2, p = E.inOutSine(seg(t, st, st + .45));
    const ink = seg(t, T_DONE + i * .1, T_DONE + i * .1 + .3);
    const pts = bubblePts(bx, by, bw, bh);
    if (ink < 1) pencil(pts, p * 1.04, t, { seed: 30 + i, amp: 2, width: 3, color: PENC, alpha: .55 * (1 - ink), glow: false, passes: 2 });
    if (ink > 0) { ctx.save(); ctx.globalAlpha *= ink; ctx.fillStyle = '#F4F8FD'; ctx.strokeStyle = '#E3ECF6'; ctx.lineWidth = 2; const path = new Path2D(); pts.forEach((q, j) => j ? path.lineTo(q[0], q[1]) : path.moveTo(q[0], q[1])); path.closePath(); ctx.fill(path); ctx.stroke(path); ctx.restore(); }
    if (ink >= 1) speakerBtn(bx + bw - 54, by + bh / 2, 32, t, -9, { blue: false, alpha: E.outCubic(seg(t, T_DONE + .7, T_DONE + 1.0)) * (1 + 0) });
  });
  lines.forEach((l, i) => {
    const st = draftStart(i), dp = seg(t, st, st + .55 + l.w / 1600);
    const ti = T_DONE + i * .055, ink = seg(t, ti, ti + .2);
    // the pencil draft of this line (its exact width and place)
    if (ink < 1 && dp > 0) {
      const amp = l.kind === 'zh' ? l.h * .55 : l.h * .42;
      draftLine(l.x, l.y - l.h * .32, l.w, amp, dp, t, i, (1 - E.inQuad(ink)));
      const rs = refineStart(i), rp = seg(t, rs, rs + .5 + l.w / 2000);
      if (rp > 0) draftLine(l.x, l.y - l.h * .32, l.w, amp * .9, rp, t + .37, i + 50, .8 * (1 - E.inQuad(ink)), true);
    }
    // the clean text, revealed behind an ink head that runs along the sketch
    if (ink > 0) {
      const mx = l.x + (l.w + 40) * E.outCubic(ink);
      ctx.save(); ctx.beginPath(); ctx.rect(l.x - 20, l.y - l.h * 1.4, mx - l.x + 20, l.h * 2); ctx.clip();
      if (l.kind === 'zh') zyDraw(EX[l.i].zh, l.x, l.y, 46, { align: 'left', w: 600 });
      else if (l.kind === 'ja') text(EX[l.i].ja, l.x, l.y, { w: 500, size: 30, color: MUTED, align: 'left' });
      else text(l.s, l.x, l.y, { w: 500, size: 32, color: INK, align: 'left' });
      ctx.restore();
      if (ink < 1) { const hx = mx - 20, hy = l.y - l.h * .35; const gg = ctx.createRadialGradient(hx, hy, 0, hx, hy, 34); gg.addColorStop(0, 'rgba(255,255,255,0.95)'); gg.addColorStop(.3, 'rgba(90,170,255,0.55)'); gg.addColorStop(1, 'rgba(90,170,255,0)'); ctx.fillStyle = gg; ctx.beginPath(); ctx.arc(hx, hy, 34, 0, Math.PI * 2); ctx.fill(); }
    }
  });
  // the last line's ink ends with a little sparkle; the play buttons come in after
  if (done) drawLottie('twinkle', t, T_DONE + lines.length * .055 + .1, DET.x + 120, DET.ex + 120, 300);
}
// a draft line: the pen writes a loose cursive line left → right, the boil keeps it alive
function draftLine(x, y, w, h, p, t, seed, alpha, refine = false) {
  const N = Math.max(24, Math.floor(w / 9)), pts = [];
  for (let i = 0; i <= N; i++) { const u = i / N, ph = u * (w / 26) * Math.PI + seed; pts.push([x + u * w + Math.cos(ph) * h * .22, y + Math.sin(ph) * h * .42 + vnoise(u * 5, seed) * h * .12]); }
  const q = boiled(pts, t, seed * 3 + 7, 1.2), m = Math.floor(N * clamp(p));
  if (m < 1) return;
  ctx.save(); ctx.lineCap = 'round'; ctx.lineJoin = 'round'; ctx.globalAlpha *= alpha;
  ctx.beginPath(); for (let j = 0; j <= m; j++) j ? ctx.lineTo(q[j][0], q[j][1]) : ctx.moveTo(q[j][0], q[j][1]);
  ctx.strokeStyle = `rgba(${PENC},${refine ? .3 : .42})`; ctx.lineWidth = refine ? 4.5 : 3; ctx.stroke();
  if (p < 1) { const hp = q[m]; const g = ctx.createRadialGradient(hp[0], hp[1], 0, hp[0], hp[1], 18); g.addColorStop(0, `rgba(${PENC},0.9)`); g.addColorStop(1, `rgba(${PENC},0)`); ctx.fillStyle = g; ctx.beginPath(); ctx.arc(hp[0], hp[1], 18, 0, Math.PI * 2); ctx.fill(); }
  ctx.restore();
}
function bubblePts(x, y, w, h) {
  const pts = pillPts(x, y, w, h, 34, 7);
  return pts;
}
function aiStatus(t) {
  const a = seg(t, T_DETAIL + .2, T_DETAIL + .45), y = DET.ex - 22, x = DET.x + 8;
  if (a <= 0) return;
  const done = t >= T_DONE + .2, fin = seg(t, T_DONE + .2, T_DONE + .4), gone = seg(t, T_DONE + 1.6, T_DONE + 2.0);
  ctx.save(); ctx.globalAlpha *= a * (1 - gone);
  if (!done) {
    // the pencil glyph writes a tiny loop
    const ph = t * 5; ctx.save(); ctx.translate(x + 26 + Math.cos(ph) * 4, y - 12 + Math.sin(ph * 2) * 3); icon('pencil', 0, 0, 34, BLUE, 7); ctx.restore();
    const s = t < T_DETAIL + 3.6 ? 'AIが例文と解説を書いています' : 'もう少しで書き終わります';
    text(s, x + 60, y, { w: 600, size: 28, color: BLUE, align: 'left' });
  } else {
    const s2 = E.outBack(fin, 2.5); ctx.save(); ctx.translate(x + 26, y - 10); ctx.scale(s2, s2); ctx.fillStyle = '#00A95C'; ctx.beginPath(); ctx.arc(0, 0, 18, 0, Math.PI * 2); ctx.fill(); icon('check', 0, 1, 22, '#fff', 9); ctx.restore();
    text('書き終わりました', x + 60, y, { w: 600, size: 28, color: '#00A95C', align: 'left', alpha: fin });
  }
  ctx.restore();
}
function conceptE(t) {
  CUES.E = { tap: .52, open: T_OPEN_E, detail: T_DETAIL, voice: T_DETAIL + .12, draft0: draftStart(0), done: T_DONE, nLines: N_LINES, end: T_DONE + 2.6 };
  drawDetail(t);
}
