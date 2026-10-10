// detail4.js — E: the word page and its AI wait, v4: "dither reform" (the reference video's transition).
// What is already known — the word, its reading, the meaning, the other ways to say it — is clean from the first frame.
// The sections the AI writes (例文 / 使い方のコツ / 豆知識) open as placeholders in the exact shape of their lines; from the
// left they break into fine ink particles, which drift as a living cloud while the AI writes (and slowly gather toward
// their lines, so the page feels closer to done the longer it works). When the answer lands, the particles gather from
// the left into the real text — dithered first, then crisp — section by section, top to bottom.
// Same idea as the catch (a material that becomes the answer in place), different material: ink instead of glass.
const T_OPEN_E = .62, T_DETAIL = 1.05, T_DONE = T_DETAIL + 5.4;   // first open of a word: card generation ~5 s (P50 estimate)
const EX = [
  { zh: Z('我要一杯珍奶，半糖少冰。', 'ㄨㄛˇ ㄧㄠˋ ㄧˋ ㄅㄟ ㄓㄣ ㄋㄞˇ ㄅㄢˋ ㄊㄤˊ ㄕㄠˇ ㄅㄧㄥ'), ja: '珍奶を1杯、甘さ半分・氷少なめで。' },
  { zh: Z('這家的珍奶很好喝。', 'ㄓㄜˋ ㄐㄧㄚ ˙ㄉㄜ ㄓㄣ ㄋㄞˇ ㄏㄣˇ ㄏㄠˇ ㄏㄜ'), ja: 'この店の珍奶はおいしい。' },
];
const TIPS = ['注文では「珍奶」だけで通じる。', '甘さは 全糖・半糖・微糖・無糖、', '氷は 正常冰・少冰・去冰 で伝える。'];
const TRIVIA = ['1980年代に台湾で生まれた飲み物。', '台中と台南の店が元祖を名乗っている。'];
const DET = { x: 48, w: W - 96, sim: 1030, ex: 1340, tips: 1840, triv: 2160 };
const SEC = [{ y: DET.ex, h: 470, title: '例文' }, { y: DET.tips, h: 290, title: '使い方のコツ' }, { y: DET.triv, h: 260, title: '豆知識' }];
const T_DIS = s => T_DETAIL + .32 + .1 * s;            // when each section's placeholders start to break up
const T_REF = s => T_DONE + .16 * s;                   // when each section's text starts to form
const INK_RGB = '11,18,26', MUTED_RGB = '92,100,111';

// ---------- the lines of the AI sections (shared by the placeholders, the particles and the clean text) ----------
let DLINES = null;
function detLines() {
  if (DLINES) return DLINES;
  const L = [];
  EX.forEach((e, i) => {
    const y = DET.ex + 124 + i * 172, x = DET.x + 76;
    L.push({ sec: 0, k: L.filter(l => l.sec === 0).length, x, y, w: zyWidth(e.zh, 46), top: y - 52, bot: y + 12, bar: [y - 42, 46], rgb: INK_RGB,
      draw: c => zyDraw(e.zh, x, y, 46, { align: 'left', w: 600, c }) });
    L.push({ sec: 0, k: L.filter(l => l.sec === 0).length, x, y: y + 52, w: measure(e.ja, 500, 30), top: y + 52 - 30, bot: y + 52 + 9, bar: [y + 52 - 25, 28], rgb: MUTED_RGB,
      draw: c => text(e.ja, x, y + 52, { w: 500, size: 30, color: MUTED, align: 'left', c }) });
  });
  [[TIPS, 1, DET.tips], [TRIVIA, 2, DET.triv]].forEach(([list, s, y0]) => list.forEach((str, i) => {
    const x = DET.x + 44, y = y0 + 112 + i * 58;
    L.push({ sec: s, k: i, x, y, w: measure(str, 500, 32), top: y - 32, bot: y + 10, bar: [y - 27, 30], rgb: INK_RGB,
      draw: c => text(str, x, y, { w: 500, size: 32, color: INK, align: 'left', c }) });
  }));
  return DLINES = L;
}

// ---------- particles: one per dithered cell of the final text ----------
const DSTEP = 3;
let DOTS = null;
const OFF = document.createElement('canvas'); OFF.width = W; OFF.height = H; const ofx = OFF.getContext('2d', { willReadFrequently: true });
function gauss(i) { const u = Math.max(1e-6, rnd(i)), v = rnd(i + 77.7); return Math.sqrt(-2 * Math.log(u)) * Math.cos(2 * Math.PI * v); }
function buildDots() {
  if (DOTS) return DOTS;
  const lines = detLines(), X0 = DET.x + 30, X1 = DET.x + DET.w - 30;
  lines.forEach((l, li) => {
    // targets: the line rendered alone, cut into 3 px cells; a cell keeps a particle with a probability = its ink (dither)
    ofx.clearRect(0, 0, W, H); l.draw(ofx);
    const x0 = Math.floor(l.x - 6), x1 = Math.ceil(l.x + l.w + 6), y0 = Math.floor(l.top), y1 = Math.ceil(l.bot), ww = x1 - x0;
    const data = ofx.getImageData(x0, y0, ww, y1 - y0).data, tg = [];
    for (let y = 0; y + DSTEP <= y1 - y0; y += DSTEP) for (let x = 0; x + DSTEP <= ww; x += DSTEP) {
      let a = 0; for (let yy = 0; yy < DSTEP; yy++) for (let xx = 0; xx < DSTEP; xx++) a += data[((y + yy) * ww + x + xx) * 4 + 3];
      a /= DSTEP * DSTEP * 255;
      const seed = li * 9173 + x * 3.17 + y * 11.3;
      if (a > .05 && a > rnd(seed) * .9) tg.push([x0 + x + 1.5 + (rnd(seed + 1) - .5) * .8, y0 + y + 1.5 + (rnd(seed + 2) - .5) * .8, Math.min(1, .5 + a * .6)]);
    }
    tg.sort((p, q) => p[0] - q[0]);
    const n = tg.length;
    // placeholder: the same particles packed into the line's bar (jittered grid), ordered by x
    const [by, bh] = l.bar, sp = Math.sqrt(l.w * bh / n), sk = [];
    for (let y = by + sp / 2; y < by + bh; y += sp) for (let x = l.x + sp / 2; x < l.x + l.w; x += sp) sk.push([x + (rnd(x * 1.3 + y) - .5) * sp * .8, y + (rnd(x + y * 2.1) - .5) * sp * .8]);
    while (sk.length < n) sk.push([l.x + rnd(sk.length + li) * l.w, by + rnd(sk.length * 3 + li) * bh]);
    const skp = sk.map((p, i) => [p, rnd(i * 5.1 + li)]).sort((a, b) => a[1] - b[1]).slice(0, n).map(a => a[0]).sort((p, q) => p[0] - q[0]);
    // the cloud: across the card, banded loosely round the line; each particle wanders on its own noise
    const mid = (l.top + l.bot) / 2, cl = [];
    for (let i = 0; i < n; i++) cl.push({ bx: X0 + (i + rnd(i * 2.3 + li)) / n * (X1 - X0), g: gauss(i * 1.7 + li * 31), seed: li * 101 + i * .37 });
    l.n = n; l.tg = tg; l.sk = skp; l.cl = cl; l.mid = mid; l.X0 = X0; l.X1 = X1;
    // which target each particle gathers into: decided by x order at the moment the line starts to form
    const tr0 = T_REF(l.sec) + .05 * l.k, order = cl.map((c, i) => [cloudPos(l, i, tr0)[0], i]).sort((a, b) => a[0] - b[0]);
    l.tgOf = new Int32Array(n); order.forEach(([, i], k) => l.tgOf[i] = k);
    // a crisp copy of the line for the final crossfade
    const cc = document.createElement('canvas'); cc.width = ww; cc.height = y1 - y0; const cx = cc.getContext('2d'); cx.translate(-x0, -y0); l.draw(cx);
    l.crisp = { c: cc, x: x0, y: y0 };
  });
  return DOTS = lines;
}
// a particle's place in the cloud at time t (a pure function of t, so any frame can be drawn on its own)
function cloudPos(l, i, t) {
  const c = l.cl[i], el = Math.max(0, t - T_DIS(l.sec));
  const sig = 30 * (.5 + .5 * Math.exp(-el / 3.2));                    // the cloud slowly gathers toward its line
  const wx = l.X1 - l.X0, x = l.X0 + (((c.bx - l.X0 + 16 * el + 14 * vnoise(t * .8 + c.seed * 3, 1)) % wx) + wx) % wx;
  const S = SEC[l.sec], y = clamp(l.mid + c.g * sig + 9 * vnoise(t * .9 + c.seed * 5, 2), S.y + 92, S.y + S.h - 22);
  return [x, y];
}

// ---------- the section cards and the known part of the page ----------
function sectionCard(y, h, title, { alpha = 1, lift = 0 } = {}) {
  ctx.save(); ctx.globalAlpha *= alpha;
  ctx.save(); ctx.shadowColor = `rgba(15,40,80,${.06 + .06 * lift})`; ctx.shadowBlur = 24 + 20 * lift; ctx.shadowOffsetY = 8 + 6 * lift; ctx.fillStyle = '#fff'; rr(DET.x, y, DET.w, h, 44); ctx.fill(); ctx.restore();
  ctx.strokeStyle = '#E0E5EB'; ctx.lineWidth = 2.5; rr(DET.x, y, DET.w, h, 44); ctx.stroke();
  text(title, DET.x + 44, y + 64, { w: 800, size: 34, align: 'left' });
  ctx.restore();
}
function drawDetail(t) {
  // backdrop: the 図鑑 page underneath, the page grows out of the slot (iOS zoom transition)
  const zoom = E.inOutQuart(seg(t, T_OPEN_E, T_DETAIL));
  if (zoom < 1) drawDexPage(t, { fx: FX(-10, -11) });
  const ts = targetSlot(), sx = ts.x, sy = ts.y;
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
  const g = ctx.createRadialGradient(540, 470, 0, 540, 470, 420); g.addColorStop(0, '#EAF4FF'); g.addColorStop(1, 'rgba(234,244,255,0)'); ctx.fillStyle = g; ctx.fillRect(0, 150, W, 700);
  ctx.save(); ctx.fillStyle = '#EDF2F8'; ctx.beginPath(); ctx.arc(96, 220, 44, 0, Math.PI * 2); ctx.fill(); icon('chevL', 92, 220, 40, INK, 8); ctx.restore();
  text('図鑑', 160, 232, { w: 600, size: 34, color: MUTED, align: 'left' });
  // the word (known): reading, register, meaning, the note — clean from the first frame
  zyDraw(PICK_U, 500, 820, 132, {});
  speakerBtn(820, 772, 50, t, T_DETAIL + .12, {});
  const chip = REG[PICK.reg], cw = measure(chip, 600, 26) + 34; ctx.fillStyle = '#EDF2F8'; rr(W / 2 - 300, 868, cw, 46, 23); ctx.fill(); text(chip, W / 2 - 300 + cw / 2, 900, { w: 600, size: 26, color: MUTED });
  text(PICK.mean, W / 2 - 300 + cw + 22, 902, { w: 500, size: 34, color: MUTED, align: 'left' });
  text(PICK.note, W / 2, 970, { w: 600, size: 30, color: '#0066CC' });
  // 似た言い方 (known from the candidates — no wait)
  sectionCard(DET.sim, 260, '似た言い方');
  [[VAR[0], 'ふだんの言い方'], [VAR[2], '大粒タピオカ']].forEach(([v, s], i) => {
    const y = DET.sim + 150 + i * 72; zyDraw(v.u, DET.x + 44, y, 46, { align: 'left', w: 600 });
    text(s, DET.x + DET.w - 44, y - 4, { w: 500, size: 30, color: MUTED, align: 'right' });
  });
  // the AI sections: titles and layout known at once; bodies are the particles
  const lift = E.outCubic(seg(t, T_DONE + .7, T_DONE + 1.0)) * (1 - seg(t, T_DONE + 1.2, T_DONE + 1.8));
  SEC.forEach(s => sectionCard(s.y, s.h, s.title, { lift }));
  // the example bubbles are layout (known), the speaker buttons come with the text
  [0, 1].forEach(i => {
    const by = DET.ex + 84 + i * 172, bh = 136, bw = DET.w - 88, bx = DET.x + 44;
    ctx.save(); ctx.fillStyle = '#F4F8FD'; ctx.strokeStyle = '#E3ECF6'; ctx.lineWidth = 2; rr(bx, by, bw, bh, 34); ctx.fill(); ctx.stroke(); ctx.restore();
    const sa = E.outBack(seg(t, T_REF(0) + .75 + i * .08, T_REF(0) + 1.05 + i * .08), 2);
    if (sa > 0) { ctx.save(); const cx = bx + bw - 54, cy = by + bh / 2; ctx.translate(cx, cy); ctx.scale(sa, sa); ctx.translate(-cx, -cy); speakerBtn(cx, cy, 32, t, -9, { blue: false }); ctx.restore(); }
  });
  aiStatus4(t);
  drawAIText(t);
}

// ---------- the AI text: placeholder → particles → cloud → dithered text → crisp text ----------
const DLV = 6;
function drawAIText(t) {
  const lines = buildDots();
  const paths = { [INK_RGB]: Array.from({ length: DLV }, () => new Path2D()), [MUTED_RGB]: Array.from({ length: DLV }, () => new Path2D()) };
  const put = (rgb, x, y, a, s = 2.7) => { if (a <= .02) return; const lv = Math.min(DLV - 1, Math.floor(a * DLV)); paths[rgb][lv].rect(x - s / 2, y - s / 2, s, s); };
  for (const l of lines) {
    const td0 = T_DIS(l.sec) + .04 * l.k, tr0 = T_REF(l.sec) + .05 * l.k;
    // the placeholder bar, eaten from the left by the break-up front
    const front = l.x + (l.w + 10) * seg(t, td0, td0 + .42);
    if (front < l.x + l.w) {
      const [by, bh] = l.bar; ctx.save(); ctx.beginPath(); ctx.rect(front, by - 4, l.x + l.w - front + 4, bh + 8); ctx.clip();
      ctx.fillStyle = '#E9EEF4'; rr(l.x, by + bh * .12, l.w, bh * .76, bh * .38); ctx.fill(); ctx.restore();
    }
    // the crisp text, revealed from the left once the particles have formed the dithered text
    const cf0 = tr0 + .34, cfront = l.x - 20 + (l.w + 80) * seg(t, cf0, cf0 + .5);
    if (cfront > l.x - 20) crispLine(l, cfront);
    if (t < td0) continue;
    for (let i = 0; i < l.n; i++) {
      const [sx, sy] = l.sk[i], xr = (sx - l.x) / l.w, td = td0 + xr * .42 + rnd(i * 3.3 + l.k) * .05;
      if (t < td) continue;
      const tj = l.tg[l.tgOf[i]], xt = (tj[0] - l.x) / l.w, tr = tr0 + xt * .42 + rnd(i * 7.7 + l.k) * .06;
      let x, y, a;
      const u = seg(t, td, td + .55);
      if (t < tr) {
        const [cx, cy] = cloudPos(l, i, t), m = E.inOutCubic(seg(u, .12, 1)), tw = Math.sin(Math.PI * m) * 18, ang = rnd(i * 1.9 + l.k * 7) * Math.PI * 2;
        x = lerp(sx, cx, m) + Math.cos(ang) * tw + (1 - m) * (rnd(i + Math.floor(t * 30)) - .5) * 2;
        y = lerp(sy, cy, m) + Math.sin(ang) * tw * .6;
        a = lerp(.62, .7, m) * clamp(u * 6);
        a *= clamp((x - l.X0) / 26) * clamp((l.X1 - x) / 26);              // the cloud fades at its edges (where it wraps)
      } else {
        const v = seg(t, tr, tr + .4), e = E.outCubic(v), [cx, cy] = cloudPos(l, i, t), nz = (1 - v) * 7;
        x = lerp(cx, tj[0], e) + (rnd(i * 2.1 + Math.floor(t * 30)) - .5) * nz; y = lerp(cy, tj[1], e) + (rnd(i * 4.3 + Math.floor(t * 30)) - .5) * nz;
        a = lerp(.7, tj[2], e) * clamp(1 - (cfront - tj[0] - 6) / 30) * (e < 1 ? clamp((x - l.X0) / 26 + e) * clamp((l.X1 - x) / 26 + e) : 1);
      }
      put(l.rgb, x, y, a);
    }
  }
  for (const rgb of [INK_RGB, MUTED_RGB]) for (let lv = 0; lv < DLV; lv++) { ctx.fillStyle = `rgba(${rgb},${(lv + .5) / DLV})`; ctx.fill(paths[rgb][lv]); }
  // the last line's text ends with a small twinkle
  const last = lines.filter(l => l.sec === 1).pop();
  if (last) drawLottie('twinkle', t, T_REF(1) + .05 * last.k + .9, DET.x + DET.w - 120, DET.tips + 70, 260);
}
const CR = document.createElement('canvas'); CR.width = W; CR.height = 120; const crx = CR.getContext('2d');
function crispLine(l, front) {
  const { c, x, y } = l.crisp;
  if (front >= x + c.width + 40) { ctx.drawImage(c, x, y); return; }
  if (CR.width < c.width || CR.height < c.height) { CR.width = Math.max(CR.width, c.width); CR.height = Math.max(CR.height, c.height); }
  crx.clearRect(0, 0, CR.width, CR.height); crx.globalCompositeOperation = 'source-over'; crx.drawImage(c, 0, 0);
  crx.globalCompositeOperation = 'destination-in'; const fx = front - x, g = crx.createLinearGradient(fx - 40, 0, fx, 0); g.addColorStop(0, 'rgba(0,0,0,1)'); g.addColorStop(1, 'rgba(0,0,0,0)');
  crx.fillStyle = g; crx.fillRect(0, 0, c.width, c.height); crx.globalCompositeOperation = 'source-over';
  ctx.drawImage(CR, 0, 0, c.width, c.height, x, y, c.width, c.height);
}
// status in the 例文 header: what the AI is doing, honestly; a check when it is done
function aiStatus4(t) {
  const a = seg(t, T_DETAIL + .2, T_DETAIL + .45), gone = seg(t, T_DONE + 1.7, T_DONE + 2.1); if (a <= 0 || gone >= 1) return;
  const done = t >= T_DONE + .7, fin = seg(t, T_DONE + .7, T_DONE + .9), xr = DET.x + DET.w - 40, y = DET.ex + 62;
  const s = !done ? (t < T_DETAIL + 3.6 ? 'AIが例文と解説を書いています' : 'もう少しで書き終わります') : '書き終わりました';
  const prevS = t < T_DETAIL + 3.6 ? null : 'AIが例文と解説を書いています', sw = done ? 1 : E.inOutCubic(seg(t, T_DETAIL + 3.6, T_DETAIL + 3.9));
  const w = measure(s, 600, 25) + 70;
  ctx.save(); ctx.globalAlpha *= a * (1 - gone);
  ctx.fillStyle = done ? 'rgba(0,169,92,0.10)' : 'rgba(0,131,255,0.08)'; rr(xr - w, y - 34, w, 48, 24); ctx.fill();
  if (!done) {
    ctx.save(); ctx.translate(xr - w + 30, y - 10); const tw = 1 + .14 * Math.sin(t * 8); ctx.scale(tw, tw); icon('sparkles', 0, 0, 30, BLUE, 6); ctx.restore();
    if (prevS && sw < 1) text(prevS, xr - 18, y, { w: 600, size: 25, color: BLUE, align: 'right', alpha: 1 - sw });
    text(s, xr - 18, y, { w: 600, size: 25, color: BLUE, align: 'right', alpha: prevS ? sw : 1 });
  } else {
    const s2 = E.outBack(fin, 2.5); ctx.save(); ctx.translate(xr - w + 30, y - 10); ctx.scale(s2, s2); ctx.fillStyle = '#00A95C'; ctx.beginPath(); ctx.arc(0, 0, 15, 0, Math.PI * 2); ctx.fill(); icon('check', 0, 1, 19, '#fff', 9); ctx.restore();
    text(s, xr - 18, y, { w: 600, size: 25, color: '#00A95C', align: 'right', alpha: fin });
  }
  ctx.restore();
}
function conceptE(t) {
  CUES.E = { tap: .52, open: T_OPEN_E, detail: T_DETAIL, voice: T_DETAIL + .12, dis: [0, 1, 2].map(T_DIS), done: T_DONE, ref: [0, 1, 2].map(T_REF), finish: T_REF(2) + .9, end: T_DONE + 2.6 };
  drawDetail(t);
}
