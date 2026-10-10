// O8 旧版の認識 — v8 of the shot-to-tags phase (owner 2026-10-10, with a screen recording of the card-catch prototype
// running in the Claude app on the iPhone):
//   「ピントで後ろをボケさせなくていい。カメラを撮ったら、iosの前のバージョンのようにものを認識して（効果音も再現して）、
//     四角い枠でカチャッと認識し、ものの周りを青く囲って。待ち時間の間はものの周りの光の点が回り続けるようにして。」
// Reproduced from the prototype's source (docs/prototype/cardcatch-src.html: shoot → analyze → anaFocus → showPick,
// outlineEl, the SFX object) and checked against the recording frame by frame:
//   bracket  ONE set of four rounded corners (.bracket i: 22 pt squares incl. a 3 pt white border, 12 pt outer radius,
//            drop-shadow 6 pt rgba(100,224,255,.9)). 260 ms after the shutter it fades in round the whole picture
//            (26 pt in, 120 pt down, 338 × 520 pt, 260 ms), then moves to each thing in turn — to the thing's box
//            + 14 pt, cubic-bezier(.3,1.3,.5,1), 540 ms — and locks: the click (cc-tick), the corners turn blue
//            (#6CC8FF: white while moving, blue from the click — measured in the recording), a squeeze (scale
//            1 → .94 → 1, 260 ms) and the thing's outline fades in (0.5 s). 400 ms later it moves on; after the last
//            thing it fades out (300 ms). The boxes are the things' on-device masks (Vision, ~0.3 s), as before.
//   outline  the thing's real contour as a thin pale-blue line (#BFE8FF → #9CC8FF → #CFE3FF) with the prototype's
//            glow: drop-shadow 5 pt rgba(140,200,255,.95), then 16 pt rgba(40,120,255,.6). It stays.
//   waiting  (the owner's addition) the prototype's points of light (white, 9 pt blue glow) keep running round every
//            outline, evenly spaced, all at one calm speed, until the names arrive.
//   names    the points fade, the found chime (cc-found), the tags pop 140 ms + 130 ms apart (cc-pop each) and the
//            outlines pulse (opacity 1 → .5 → 1 every 2 s) as on the prototype's pick screen, until a tag is tapped.
//   photo    sharp: no blur, no dimming (the prototype's frozen photo). The screen edge glows blue while the AI works.
const O8 = (() => {
  const BR_IN = T_CAP + .26, IN = .26, MOVE = .54, HOLD = .4, OUT = .3, PAD = 14 * PT;
  const LW = 3 * PT, RAD = 12 * PT, ARM_END = 19 * PT, GLOW = 6 * PT, LOCKED = '#6CC8FF';
  const FULL = [26 * PT, 120 * PT, W - 26 * PT, (120 + 520) * PT];
  const mv = bezierEase(.3, 1.3, .5, 1), cssEase = bezierEase(.25, .1, .25, 1), inOut = bezierEase(.42, 0, .58, 1);
  const MOVE0 = r => BR_IN + IN + r * (MOVE + HOLD);       // the bracket leaves for thing r
  const LOCK = r => MOVE0(r) + MOVE;                        // … and locks onto it (the click)
  const OUT0 = () => LOCK(SCAN_K.length - 1) + HOLD;        // it fades after the last thing
  const FOUND = () => Math.max(T_NAMES, OUT0() + OUT);      // the names are shown once they are in and the bracket is done
  const TAG = k => FOUND() + .14 + .13 * k;                 // showPick: setTimeout(140 + i * 130)
  function boxOf(k) {                                       // the thing's box + 14 pt, kept on screen so all four corners show
    const [x0, y0, x1, y1] = objO(k).box, m = 10 * PT;
    return [Math.max(m, x0 - PAD), Math.max(m, y0 - PAD), Math.min(W - m, x1 + PAD), Math.min(H - m, y1 + PAD)];
  }

  // ---------- the bracket ----------
  function corner(c, x, y, sx, sy) {                       // a corner piece's border, stroked along its middle (1.5 pt outside the box)
    const d = -1.5 * PT, r = RAD - 1.5 * PT;
    c.moveTo(x + sx * d, y + sy * ARM_END); c.lineTo(x + sx * d, y + sy * (d + r));
    c.arcTo(x + sx * d, y + sy * d, x + sx * (d + r), y + sy * d, r); c.lineTo(x + sx * ARM_END, y + sy * d);
  }
  function bracketState(t) {
    let r = -1; for (let i = 0; i < SCAN_K.length; i++) if (t >= MOVE0(i)) r = i;
    const to = r < 0 ? FULL : boxOf(SCAN_K[r]), from = r <= 0 ? FULL : boxOf(SCAN_K[r - 1]);
    const u = r < 0 ? 1 : mv(clamp((t - MOVE0(r)) / MOVE));
    return { r, R: to.map((v, j) => lerp(from[j], v, u)), locked: r >= 0 && t >= LOCK(r) };
  }
  function bracket(t) {
    if (t < BR_IN) return;
    const a = clamp(mv(clamp((t - BR_IN) / IN))) * (1 - clamp((t - OUT0()) / OUT)); if (a <= 0) return;
    const { r, R, locked } = bracketState(t);
    const sq = locked ? 1 - .06 * (1 - Math.abs(1 - 2 * clamp((t - LOCK(r)) / .26))) : 1;
    const cx = (R[0] + R[2]) / 2, cy = (R[1] + R[3]) / 2;
    ctx.save(); ctx.globalAlpha *= a; ctx.translate(cx, cy); ctx.scale(sq, sq); ctx.translate(-cx, -cy);
    ctx.lineWidth = LW; ctx.lineCap = 'butt'; ctx.lineJoin = 'round'; ctx.strokeStyle = locked ? LOCKED : '#fff';
    ctx.shadowColor = 'rgba(100,224,255,0.9)'; ctx.shadowBlur = GLOW;
    ctx.beginPath(); corner(ctx, R[0], R[1], 1, 1); corner(ctx, R[2], R[1], -1, 1); corner(ctx, R[0], R[3], 1, -1); corner(ctx, R[2], R[3], -1, -1); ctx.stroke();
    ctx.restore();
  }

  // ---------- the outlines ----------
  const OL = document.createElement('canvas'); OL.width = W; OL.height = H; const olx = OL.getContext('2d');
  const edgeD = p => Math.min(p[0], W - p[0], p[1], H - p[1]);
  function outlineAlpha(k, t) {
    const r = scanRank(k); if (r < 0 || t < LOCK(r)) return 0;
    let a = cssEase(clamp((t - LOCK(r)) / .5));            // .outline { transition: opacity .5s }
    const f = FOUND(); if (t > f) { const p = ((t - f) % 2) / 2; a *= p < .5 ? lerp(1, .5, inOut(p * 2)) : lerp(.5, 1, inOut(p * 2 - 1)); }   // @keyframes opulse { 50% { opacity: .5 } } 2s ease-in-out
    return a * (1 - cssEase(clamp((t - T_TAP) / .5)));     // they go when a tag is tapped
  }
  function contour(c, O) {                                  // the closed contour, minus the stretches on the frame's edge (the prototype's
    c.beginPath(); let pen = false;                         // ring lies outside the cut-out, so where the frame cuts a thing it is off-screen)
    for (let i = 0; i <= O.n; i++) { const p = O.pts[i % O.n]; if (edgeD(p) < 6) { pen = false; continue; } if (pen) c.lineTo(p[0], p[1]); else { c.moveTo(p[0], p[1]); pen = true; } }
  }
  const OLG = document.createElement('canvas'); OLG.width = W; OLG.height = H; const olg = OLG.getContext('2d');
  function outlines(t) {
    olx.clearRect(0, 0, W, H); olg.clearRect(0, 0, W, H); let any = false;
    SCAN_K.forEach(k => {
      const a = outlineAlpha(k, t); if (a <= .005) return; any = true;
      const O = objO(k), [x0, y0, x1, y1] = O.box, g = olx.createLinearGradient(x0, y0, x1, y1);
      g.addColorStop(0, '#BFE8FF'); g.addColorStop(.5, '#9CC8FF'); g.addColorStop(1, '#CFE3FF');
      for (const [c, w, st] of [[olx, 1.75 * PT, g], [olg, 3.5 * PT, 'rgb(120,190,255)']]) {
        c.save(); photoXform(c, t); c.globalAlpha = a; c.lineWidth = w; c.lineJoin = 'round'; c.lineCap = 'round'; c.strokeStyle = st; contour(c, O); c.stroke(); c.restore();
      }
    });
    if (!any) return;
    // the glow: the prototype's two drop-shadows (5 pt light blue, 16 pt deep blue), cast from a wider line so it reads on this photo
    ctx.save(); ctx.globalCompositeOperation = 'screen';
    ctx.filter = `blur(${2.5 * PT}px)`; ctx.globalAlpha = .65; ctx.drawImage(OLG, 0, 0);
    ctx.filter = `blur(${8 * PT}px)`; ctx.globalAlpha = .6; ctx.drawImage(OLG, 0, 0);
    ctx.restore();
    ctx.save(); ctx.filter = `drop-shadow(0 0 ${5 * PT}px rgba(140,200,255,0.95)) drop-shadow(0 0 ${16 * PT}px rgba(40,120,255,0.6))`; ctx.drawImage(OL, 0, 0); ctx.restore();
  }

  // ---------- the points of light while the AI works ----------
  const SPEED = 480, GAP = 760, TAIL = 24;                  // px/s along every outline (≈175 pt/s); about one point per 760 px of outline; tail 24 × 4 px
  const DOT0 = r => LOCK(r) + .5;                           // once the outline is in
  const dotsOf = k => Math.max(2, Math.round(objO(k).n * 4 / GAP));
  const dotA = (r, t) => cssEase(clamp((t - DOT0(r)) / .4)) * (1 - cssEase(clamp((t - FOUND()) / .3)));
  const edgeFade = p => clamp((edgeD(p) - 4) / 36);         // a point leaves through the frame's edge where the thing is cut by it
  const DT = document.createElement('canvas'); DT.width = W; DT.height = H; const dtx = DT.getContext('2d');
  function dots(t) {
    const heads = []; dtx.clearRect(0, 0, W, H);
    SCAN_K.forEach((k, r) => {
      const a = dotA(r, t); if (a <= .005) return;
      const O = objO(k), L = O.n, n = dotsOf(k), s0 = (t - DOT0(r)) * SPEED / 4, at = i => O.pts[((i % L) + L) % L];
      dtx.save(); photoXform(dtx, t); dtx.lineCap = 'round'; dtx.lineWidth = 2.2 * PT;
      for (let j = 0; j < n; j++) {
        const h = s0 + j * L / n, hi = Math.floor(h), fr = h - hi, p = at(hi), q = at(hi + 1), head = [lerp(p[0], q[0], fr), lerp(p[1], q[1], fr)];
        for (let s = 0; s < TAIL; s++) {                    // the line behind the point glows, fading
          const b = s === 0 ? head : at(hi - s + 1), e = at(hi - s), al = a * .6 * (1 - s / TAIL) ** 2 * edgeFade(e); if (al < .01) continue;
          dtx.strokeStyle = `rgba(190,228,255,${al})`; dtx.beginPath(); dtx.moveTo(b[0], b[1]); dtx.lineTo(e[0], e[1]); dtx.stroke();
        }
        heads.push([...toScreen(t, head[0], head[1]), a * edgeFade(head)]);
      }
      dtx.restore();
    });
    if (!heads.length) return;
    ctx.save(); ctx.globalCompositeOperation = 'lighter'; ctx.filter = 'blur(5px)'; ctx.drawImage(DT, 0, 0); ctx.filter = 'none'; ctx.drawImage(DT, 0, 0); ctx.restore();
    heads.forEach(([x, y, a]) => {
      if (a <= .01) return;
      glowDot(x, y, 12 * PT, .75 * a, '120,195,255');
      ctx.save(); ctx.fillStyle = `rgba(255,255,255,${a})`; ctx.shadowColor = 'rgba(150,210,255,0.95)'; ctx.shadowBlur = 9 * PT;
      ctx.beginPath(); ctx.arc(x, y, 2.6 * PT, 0, Math.PI * 2); ctx.fill(); ctx.restore();
    });
  }

  function cues() {
    return { kind: 'old', bracketIn: +BR_IN.toFixed(3), move: SCAN_K.map((_, r) => +MOVE0(r).toFixed(3)), lock: SCAN_K.map((_, r) => +LOCK(r).toFixed(3)),
      lockIds: SCAN_K.map(k => TAGS[k].id), lockX: SCAN_K.map(k => Math.round((boxOf(k)[0] + boxOf(k)[2]) / 2)), bracketOut: +OUT0().toFixed(3), found: +FOUND().toFixed(3),
      dots: SCAN_K.map((k, r) => ({ id: TAGS[k].id, t: +DOT0(r).toFixed(3), n: dotsOf(k), lap: +(objO(k).n * 4 / SPEED).toFixed(2) })) };
  }
  return { backdrop: t => photoBase(t), draw(t) { outlines(t); dots(t); }, over: bracket, TAG, get scanned() { return OUT0(); }, cues };
})();
function conceptO8(t) { CUES.O8 = Object.assign(O8.cues(), { names: T_NAMES, tags: TAGS.map((_, k) => +O8.TAG(k).toFixed(3)), tap: T_TAP, end: T_TAP + .6 }); scan7Frame(t, O8); }
