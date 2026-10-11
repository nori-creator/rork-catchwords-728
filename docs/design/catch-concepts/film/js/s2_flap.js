// S2 パタパタ — the split-flap board. As soon as the device has found a thing, a small split-flap board unfolds on
// it and its flaps start to run through characters: the name is being looked up. When the answer arrives each board
// slows down and stops on the word, flap by flap from the left, with a clack you can feel (a haptic per flap), board
// after board — a rhythm that builds to the last one. Anticipation of a moving, uncertain result is pleasant; the
// mechanical stop is the payoff. With a streamed answer each board can stop the moment its own word arrives.
const POOL = [...'車機茶奶珍板黑盆栽花店門窗桌椅杯水果燈書包紙傘鞋帽衣椰竹籃筆碗盤瓶鍋牌路石葉草木人山口日月天中大小上下好有來去吃喝看說走光風雲雨電話糖冰'];
const FLAP = { cw: 58, ch: 78, gap: 7, padL: 64, padR: 24, h: 104, hf: 142, fd: .072 };
const LOCK_T = (i, c) => T_REVEAL(i) + .12 + c * .09;
const GLY = {};
function glyph(ch) {          // a character on its flap, cached
  if (GLY[ch]) return GLY[ch];
  const c = document.createElement('canvas'); c.width = FLAP.cw; c.height = FLAP.ch; const g = c.getContext('2d');
  font(800, 50, FONT_TC, g); g.fillStyle = INK; g.textAlign = 'center'; g.textBaseline = 'middle'; g.fillText(ch, FLAP.cw / 2, FLAP.ch / 2 + 3);
  return GLY[ch] = c;
}
let FLIPS = null;
function flipPlan() {       // every flip of every flap (deterministic), also exported for the sound and the haptics
  if (FLIPS) return FLIPS;
  FLIPS = TAGS.map((tag, i) => {
    const word = [...tag.zh], n = Math.max(2, word.length);
    return Array.from({ length: n }, (_, c) => {
      const L = LOCK_T(i, c), ev = []; let prev = POOL[(i * 7 + c * 3) % POOL.length], k = 0;
      const push = (t0, dur, ch, land = false) => { ev.push({ t0, dur, a: prev, b: ch, land }); prev = ch; };
      const early = c < 2;                                    // the board starts with two flaps; more unfold at the answer
      let t = early ? T_MASK(i) + .2 + c * .06 : T_REVEAL(i) + .06 + (c - 2) * .05;
      const stop = L - .46;
      while (early && t < stop) {
        push(t, FLAP.fd, POOL[Math.floor(rnd(i * 977 + c * 131 + k * 7.1) * POOL.length)]);
        k++; t += .085 + rnd(i * 31 + c * 17 + k * 3.3) * .09 + (k % 9 === 0 ? .22 + rnd(k + i) * .15 : 0);
      }
      // slowing down: the last flips before the stop come further and further apart
      const tail = early ? [.42, .3, .2] : [.2];
      tail.forEach((d, j) => { if (L - d > t - .02) push(L - d, FLAP.fd * (1 + j * .2), POOL[Math.floor(rnd(i * 53 + c * 29 + j * 11) * POOL.length)]); });
      push(L - FLAP.fd * 1.5, FLAP.fd * 1.5, word[c] || ' ', true);
      return { L, ev, appear: early ? T_MASK(i) + .1 : T_REVEAL(i) + .02 + (c - 2) * .05 };
    });
  });
  return FLIPS;
}
// one flap at time t: static halves, the falling top flap, the unfolding bottom flap (with a little bounce at the end)
function drawFlap(cell, x, y, t) {
  const { cw, ch } = FLAP, hh = ch / 2;
  let cur = cell.ev.length ? cell.ev[0].a : ' ', fl = null;
  for (const e of cell.ev) { if (t >= e.t0 + e.dur) cur = e.b; else if (t >= e.t0) { fl = e; break; } else break; }
  ctx.save(); rr(x, y, cw, ch, 10); ctx.clip();
  const bg = ctx.createLinearGradient(0, y, 0, y + ch); bg.addColorStop(0, '#FFFFFF'); bg.addColorStop(.5, '#F3F6FA'); bg.addColorStop(.5, '#EBEFF5'); bg.addColorStop(1, '#F6F8FB');
  ctx.fillStyle = bg; ctx.fillRect(x, y, cw, ch);
  const half = (chr, top, sy = 1, shade = 0) => {           // draw the top or bottom half of a character, squashed toward the split
    const G = glyph(chr), s0 = top ? 0 : hh;
    ctx.save(); ctx.translate(x, y + hh); ctx.scale(1, sy); ctx.translate(-x, -(y + hh));
    if (shade) { ctx.fillStyle = top ? `rgba(240,244,249,1)` : `rgba(235,239,245,1)`; ctx.fillRect(x, top ? y : y + hh, cw, hh); }
    ctx.drawImage(G, 0, s0, cw, hh, x, y + s0, cw, hh);
    if (shade) { ctx.fillStyle = `rgba(20,30,45,${shade})`; ctx.fillRect(x, top ? y : y + hh, cw, hh); }
    ctx.restore();
  };
  if (!fl) { half(cur, true); half(cur, false); }
  else {
    const p = (t - fl.t0) / fl.dur;
    if (p < .5) { const k = Math.cos(p * Math.PI); half(fl.b, true); half(fl.a, false); half(fl.a, true, k, .28 * (1 - k)); }
    else { const k = -Math.cos(p * Math.PI); half(fl.b, true); half(fl.a, false); half(fl.b, false, k, .2 * (1 - k)); }
  }
  // the landing flap bounces a hair, then settles
  const last = cell.ev[cell.ev.length - 1], b = t - (last.t0 + last.dur);
  if (b > 0 && b < .18) { ctx.fillStyle = `rgba(20,30,45,${.08 * Math.sin(b / .18 * Math.PI)})`; ctx.fillRect(x, y + hh, cw, hh * .5); }
  ctx.fillStyle = 'rgba(120,135,155,0.55)'; ctx.fillRect(x, y + hh - 1, cw, 2);
  ctx.fillStyle = 'rgba(255,255,255,0.9)'; ctx.fillRect(x, y + hh + 1, cw, 1);
  ctx.restore();
  ctx.save(); ctx.strokeStyle = 'rgba(160,172,190,0.45)'; ctx.lineWidth = 1.5; rr(x + .75, y + .75, cw - 1.5, ch - 1.5, 9.5); ctx.stroke(); ctx.restore();
}
function flapBoard(i, t) {
  const tag = TAGS[i], P = flipPlan()[i], ta = T_MASK(i) + .08; if (t < ta) return;
  const n = P.length, word = [...tag.zh], tr = T_REVEAL(i);
  // how many flaps are showing (2, then the board widens if the word is longer), and the board's size
  const extra = n > 2 ? clamp(spring(t - tr - .02, .36, .7), 0, 1.06) : 0;
  const nShow = 2 + (n - 2) * extra, { cw, ch, gap, padL, padR } = FLAP;
  const done = Math.max(...P.map(c => c.L)) + .1, grow = clamp(spring(t - done, .36, .72), 0, 1.08);
  const w = padL + nShow * cw + (nShow - 1) * gap + padR, wja = measure(tag.ja, 500, 26) + 64;
  const W2 = Math.max(w, lerp(w, wja, grow)), h = lerp(FLAP.h, FLAP.hf, grow);
  const cx = tag.p[0], bottom = tag.p[1] - 30, x = clamp(cx - W2 / 2, 22, W - 22 - W2), y = bottom - h;
  const open = clamp(sp(t, ta, .38, .66), 0, 1.12), press = tag.id === 'cup' ? cupTagPress(t) : 0;
  ctx.save(); ctx.globalAlpha *= clamp(open * 3); tagAnchor(tag, t, 1, E.outCubic(seg(t, ta, ta + .2))); ctx.restore();
  ctx.save(); ctx.translate(cx, bottom); ctx.scale(1 - press * .06, open * (1 - press * .06)); ctx.translate(-cx, -bottom);
  glass(x, y, W2, h, Math.min(h / 2, 46), { tint: 'rgba(255,255,255,0.86)', shadow: .22 });
  // the dot: grey while looking, blue when the word is in
  const dl = seg(t, done - .05, done + .15);
  ctx.fillStyle = dl > 0 ? `rgb(${Math.round(lerp(154, 42, dl))},${Math.round(lerp(166, 155, dl))},${Math.round(lerp(181, 255, dl))})` : '#9AA6B5';
  ctx.beginPath(); ctx.arc(x + 34, y + 14 + ch / 2, 11, 0, Math.PI * 2); ctx.fill();
  const fx0 = x + padL - 8, fy = y + 13;
  for (let c = 0; c < n; c++) {
    if (c >= 2 && t < P[c].appear) continue;
    const ua = c >= 2 ? clamp(sp(t, P[c].appear, .3, .7), 0, 1.1) : 1;
    const xx = fx0 + c * (cw + gap);
    ctx.save(); ctx.translate(xx + cw / 2, fy + ch / 2); ctx.scale(1, ua); ctx.translate(-(xx + cw / 2), -(fy + ch / 2)); ctx.globalAlpha *= clamp(ua * 2);
    drawFlap(P[c], xx, fy, t); ctx.restore();
  }
  if (grow > 0) text(tag.ja, x + 34 - 11, y + h - 22, { w: 500, size: 26, color: MUTED, align: 'left', alpha: E.outCubic(seg(t, done + .05, done + .3)) });
  ctx.restore();
  if (NEW_WORD[tag.id]) {
    const nk = E.outBack(seg(t, done + .1, done + .4), 2.6);
    if (nk > 0) { ctx.save(); ctx.translate(x + W2 - 16, y + 2); ctx.scale(nk, nk); ctx.rotate(.08); ctx.shadowColor = 'rgba(0,80,200,0.35)'; ctx.shadowBlur = 12; ctx.shadowOffsetY = 4; ctx.fillStyle = BLUE; rr(-44, -19, 88, 38, 19); ctx.fill(); ctx.shadowColor = 'transparent'; text('NEW', 0, 9, { w: 800, size: 23, f: FONT_UI, color: '#fff', ls: 1.5 }); ctx.restore(); }
  }
}
function conceptS2(t) {
  const P = flipPlan();
  CUES.S2 = { masks: TAGS.map((_, i) => +T_MASK(i).toFixed(3)), names: T_NAMES, tap: T_TAP, end: SCAN_END,
    flips: P.flatMap((cells, i) => cells.flatMap((c, k) => c.ev.map(e => [+e.t0.toFixed(3), i, k, e.land ? 1 : 0]))).sort((a, b) => a[0] - b[0]),
    boardDone: P.map(cells => +(Math.max(...cells.map(c => c.L)) + .1).toFixed(3)) };
  const dim = .18 * E.outCubic(seg(t, T_MASK(0) - .1, T_MASK(0) + .4)) * (1 - E.inOutCubic(seg(t, CUES.S2.boardDone[3], CUES.S2.boardDone[3] + .5)));
  spotBackdrop(t, TAGS.map((_, i) => E.outCubic(seg(t, T_MASK(i), T_MASK(i) + .45))), { dim, sat: .85 });
  makeBlur(); ctx.drawImage(BG, 0, 0);
  capFlash(t); camChrome(t);
  TAGS.forEach((_, i) => flapBoard(i, t));
  scanPills(t, 99, { hint: CUES.S2.boardDone[3] + .35 });
  tabBar({ sel: 2, t });
  scanEnd(t);
  statusBar(false); homeIndicator(false);
}
