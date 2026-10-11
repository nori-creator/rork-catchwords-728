// O10 光のペンが追いつく — v9 with the pen catching up (owner 2026-10-11 「⑧そうして」: 名前が早く届いたら、ペンが速く
//   描き終える). v9's pen keeps its own pace however early the names come, so with the faster AI (names 2.4–3.3 s after
//   the shutter) the tags wait for the drawing: in O9 the last tag is held until the pen closes the sign at 4.08 s.
// Here the pen runs on its own clock τ: 1× until the names arrive, then it speeds up (over 0.15 s, no jerk) so that
// whatever is left to draw — the rest of this outline, the hops, the remaining outlines — is finished within 0.5 s,
// never faster than 4× (the stroke stays readable). The bracket, its click, the fresh-line glint and the hop go by the
// same clock, so the bracket still clicks just as the pen arrives. Each tag still waits for its own outline (as v9).
// Names after the drawing is done: no change from v9 (the small light goes round until they come).
// Everything else — look, sounds, the small waiting light, the tags — is v9's.
const O10 = (() => {
  const BR_IN = T_CAP + .26, IN = .26, MOVE = .54, OUT = .3, PAD = 14 * PT;
  const LW = 3 * PT, RAD = 12 * PT, ARM_END = 19 * PT, GLOW = 6 * PT, LOCKED = '#6CC8FF';
  const FULL = [26 * PT, 120 * PT, W - 26 * PT, (120 + 520) * PT];
  const mv = bezierEase(.3, 1.3, .5, 1), cssEase = bezierEase(.25, .1, .25, 1), inOut = bezierEase(.42, 0, .58, 1);
  const DUR = [1.0, .9, .6], HOP = .26, PEN_R = 34, SMALL_R = 20, SPEED = 1350;   // W2's pen and patrol
  const LOCK = []; { let t = BR_IN + IN + MOVE; SCAN_K.forEach((_, r) => { LOCK[r] = t; t += DUR[r] + HOP; }); }
  // On the pen's clock τ (v9's timings):
  const MOVE0 = r => LOCK[r] - MOVE;                        // the bracket leaves so that it clicks as the pen arrives
  const CLOSE = r => LOCK[r] + DUR[r];                      // the pen closes thing r's outline
  const DRAW_END = () => CLOSE(SCAN_K.length - 1);
  // ---------- the catch-up (⑧): τ(t) ----------
  const CATCH = .5, RAMP = .15, KMAX = 4;
  const LEFT = DRAW_END() - T_NAMES;                        // drawing still to do when the names arrive (≤ 0: done already)
  const K = LEFT <= CATCH ? 1 : Math.min(KMAX, 1 + (LEFT - CATCH) / (CATCH - RAMP / 2));
  const extra = d => d <= RAMP ? RAMP * ((d / RAMP) ** 3 - (d / RAMP) ** 4 / 2) : RAMP / 2 + (d - RAMP);   // ∫ smoothstep
  const tau = t => (K === 1 || t <= T_NAMES ? t : t + (K - 1) * extra(t - T_NAMES));
  const real = x => {                                       // τ → real time (τ only grows, so halve until close)
    if (K === 1 || x <= T_NAMES) return x;
    let lo = T_NAMES, hi = T_NAMES + (x - T_NAMES); for (let i = 0; i < 40; i++) { const m = (lo + hi) / 2; if (tau(m) < x) lo = m; else hi = m; }
    return hi;
  };
  // In real time (sounds, tags, the end of the drawing):
  const LOCK_R = r => real(LOCK[r]), CLOSE_R = r => real(CLOSE(r)), DRAW_END_R = () => real(DRAW_END());
  const FOUND = () => Math.max(T_NAMES, CLOSE_R(0));        // the names are shown when they are in (and something is drawn)
  const TAG = k => { const base = FOUND() + .14 + .13 * k, r = scanRank(k); return r < 0 ? base : Math.max(base, CLOSE_R(r) + .1); };
  const edgeD = p => Math.min(p[0], W - p[0], p[1], H - p[1]);
  const edgeFade = p => clamp((edgeD(p) - 4) / 36);         // the light leaves through the frame's edge where a thing is cut by it
  function boxOf(k) {
    const [x0, y0, x1, y1] = objO(k).box, m = 10 * PT;
    return [Math.max(m, x0 - PAD), Math.max(m, y0 - PAD), Math.min(W - m, x1 + PAD), Math.min(H - m, y1 + PAD)];
  }

  // ---------- the bracket (v8) ----------
  function corner(c, x, y, sx, sy) {
    const d = -1.5 * PT, r = RAD - 1.5 * PT;
    c.moveTo(x + sx * d, y + sy * ARM_END); c.lineTo(x + sx * d, y + sy * (d + r));
    c.arcTo(x + sx * d, y + sy * d, x + sx * (d + r), y + sy * d, r); c.lineTo(x + sx * ARM_END, y + sy * d);
  }
  function bracket(rt) {
    const t = tau(rt);                                      // the bracket moves on the pen's clock; it fades in real time
    if (t < BR_IN) return;
    const a = clamp(mv(clamp((t - BR_IN) / IN))) * (1 - clamp((rt - DRAW_END_R()) / OUT)); if (a <= 0) return;
    let r = -1; for (let i = 0; i < SCAN_K.length; i++) if (t >= MOVE0(i)) r = i;
    const to = r < 0 ? FULL : boxOf(SCAN_K[r]), from = r <= 0 ? FULL : boxOf(SCAN_K[r - 1]);
    const u = r < 0 ? 1 : mv(clamp((t - MOVE0(r)) / MOVE)), R = to.map((v, j) => lerp(from[j], v, u)), locked = r >= 0 && t >= LOCK[r];
    const sq = locked ? 1 - .06 * (1 - Math.abs(1 - 2 * clamp((t - LOCK[r]) / .26))) : 1;
    const cx = (R[0] + R[2]) / 2, cy = (R[1] + R[3]) / 2;
    ctx.save(); ctx.globalAlpha *= a; ctx.translate(cx, cy); ctx.scale(sq, sq); ctx.translate(-cx, -cy);
    ctx.lineWidth = LW; ctx.lineCap = 'butt'; ctx.lineJoin = 'round'; ctx.strokeStyle = locked ? LOCKED : '#fff';
    ctx.shadowColor = 'rgba(100,224,255,0.9)'; ctx.shadowBlur = GLOW;
    ctx.beginPath(); corner(ctx, R[0], R[1], 1, 1); corner(ctx, R[2], R[1], -1, 1); corner(ctx, R[0], R[3], 1, -1); corner(ctx, R[2], R[3], -1, -1); ctx.stroke();
    ctx.restore();
  }

  // ---------- the pen (W2) ----------
  const TD = {};
  function tdOf(k) {                                        // when the pen passes each point: slower where the outline turns (W2);
    if (TD[k]) return TD[k];                                // stretches on the frame's edge pass quickly (the pen is out of frame there)
    const O = objO(k), r = scanRank(k), n = O.n;
    const w = O.turn.map((_, i) => { let s = 0; for (let d = -4; d <= 4; d++) s += O.turn[(i + d + n) % n]; return (1 + 2.6 * s / 9) * (edgeD(O.pts[i]) < 6 ? .25 : 1); });
    let acc = 0; const T = w.map(x => (acc += x)), tot = acc;
    return TD[k] = T.map(x => LOCK[r] + DUR[r] * Math.acos(1 - 2 * Math.min(1, x / tot)) / Math.PI);
  }
  function headOf(k, t) {                                   // how far the pen has drawn (a fractional point index) and where it is
    const O = objO(k), td = tdOf(k), r = scanRank(k);
    if (t <= LOCK[r]) return { h: 0, xy: O.pts[0] };
    if (t >= CLOSE(r)) return { h: O.n, xy: O.pts[0] };
    let lo = 0, hi = O.n - 1; while (lo < hi) { const m = (lo + hi + 1) >> 1; if (td[m] <= t) lo = m; else hi = m - 1; }
    const t0 = lo === 0 && td[0] > t ? LOCK[r] : td[lo], t1 = td[Math.min(O.n - 1, lo + 1)], f = t1 > t0 ? clamp((t - t0) / (t1 - t0)) : 0;
    const p = O.pts[lo], q = O.pts[(lo + 1) % O.n];
    return { h: lo + f, xy: [lerp(p[0], q[0], f), lerp(p[1], q[1], f)] };
  }
  const hopArc = (a, b) => [(a[0] + b[0]) / 2, Math.min(a[1], b[1]) - 160];
  function penAt(rt) {
    const t = tau(rt);
    for (let r = 0; r < SCAN_K.length; r++) {
      const k = SCAN_K[r];
      if (t >= LOCK[r] && t < CLOSE(r)) return { xy: headOf(k, t).xy, a: 1 };
      if (r < SCAN_K.length - 1 && t >= CLOSE(r) && t < LOCK[r + 1]) {
        const a = objO(k).pts[0], b = objO(SCAN_K[r + 1]).pts[0], u = E.inOutSine(seg(t, CLOSE(r), LOCK[r + 1]));
        return { xy: bez2(a, hopArc(a, b), b, u), a: .55, hop: [a, b, u] };
      }
    }
    if (rt >= DRAW_END_R() && rt < DRAW_END_R() + .25) return { xy: objO(SCAN_K[SCAN_K.length - 1]).pts[0], a: 1 - seg(rt, DRAW_END_R(), DRAW_END_R() + .25) };   // it fades where it closed the last outline
    return null;
  }

  // ---------- the small light while waiting ----------
  let PATH = null;
  function patrolPath() {                                   // round outline 0, hop, outline 1, hop, outline 2, hop back (W2); constant speed
    if (PATH) return PATH;
    const segs = []; let L = 0;
    SCAN_K.forEach((k, r) => {
      const O = objO(k), cum = [0]; for (let i = 1; i <= O.n; i++) { const p = O.pts[i - 1], q = O.pts[i % O.n]; cum.push(cum[i - 1] + Math.hypot(q[0] - p[0], q[1] - p[1]) * (edgeD(p) < 6 ? .25 : 1)); }
      segs.push({ type: 'o', k, L0: L, len: cum[O.n], cum }); L += cum[O.n];
      const a = O.pts[0], b = objO(SCAN_K[(r + 1) % SCAN_K.length]).pts[0], pts = bezPts(a, hopArc(a, b), b, 40);
      let hl = 0; for (let i = 1; i < pts.length; i++) hl += Math.hypot(pts[i][0] - pts[i - 1][0], pts[i][1] - pts[i - 1][1]);
      segs.push({ type: 'h', pts, L0: L, len: hl }); L += hl;
    });
    return PATH = { segs, L };
  }
  const P0 = () => DRAW_END_R() + .3;
  const patrolA = t => T_NAMES <= P0() ? 0 : clamp((t - P0()) / .3) * (1 - clamp((t - T_NAMES) / .25));
  function at(sg, s) {                                      // a point at arc length s inside a patrol segment (and its index)
    if (sg.type === 'o') { const O = objO(sg.k); let i = 0; while (i < O.n - 1 && sg.cum[i + 1] < s) i++; const f = clamp((s - sg.cum[i]) / Math.max(1e-6, sg.cum[i + 1] - sg.cum[i])), p = O.pts[i], q = O.pts[(i + 1) % O.n]; return { i, xy: [lerp(p[0], q[0], f), lerp(p[1], q[1], f)] }; }
    const u = clamp(s / sg.len) * (sg.pts.length - 1), i = Math.min(sg.pts.length - 2, Math.floor(u)), f = u - i, p = sg.pts[i], q = sg.pts[i + 1]; return { i, xy: [lerp(p[0], q[0], f), lerp(p[1], q[1], f)] };
  }
  function patrolAt(t) {
    const P = patrolPath(), d = (((t - P0()) * SPEED) % P.L + P.L) % P.L;
    for (const sg of P.segs) if (d < sg.L0 + sg.len) return { sg, s: d - sg.L0, ...at(sg, d - sg.L0) };
    const sg = P.segs[0]; return { sg, s: 0, ...at(sg, 0) };
  }

  // ---------- the outlines (v8 style), as the pen draws them ----------
  const OL = document.createElement('canvas'); OL.width = W; OL.height = H; const olx = OL.getContext('2d');
  const OLG = document.createElement('canvas'); OLG.width = W; OLG.height = H; const olg = OLG.getContext('2d');
  function outlineAlpha(t) {
    let a = 1; const f = FOUND();
    if (t > f) { const p = ((t - f) % 2) / 2; a *= p < .5 ? lerp(1, .5, inOut(p * 2)) : lerp(.5, 1, inOut(p * 2 - 1)); }   // the prototype's pick-screen pulse
    return a * (1 - cssEase(clamp((t - T_TAP) / .5)));
  }
  function drawnPath(c, O, h) {                             // the contour from its start to the pen (fractional), minus the frame's edge
    c.beginPath(); let pen = false; const last = Math.min(O.n, Math.floor(h));
    const put = p => { if (edgeD(p) < 6) { pen = false; return; } if (pen) c.lineTo(p[0], p[1]); else { c.moveTo(p[0], p[1]); pen = true; } };
    for (let i = 0; i <= last; i++) put(O.pts[i % O.n]);
    if (h < O.n) { const f = h - last, p = O.pts[last % O.n], q = O.pts[(last + 1) % O.n]; put([lerp(p[0], q[0], f), lerp(p[1], q[1], f)]); }
  }
  function outlines(t) {
    olx.clearRect(0, 0, W, H); olg.clearRect(0, 0, W, H); const A = outlineAlpha(t), tp = tau(t); let any = false;
    if (A > .005) SCAN_K.forEach((k, r) => {
      if (tp < LOCK[r]) return; any = true;
      const O = objO(k), h = headOf(k, tp).h, [x0, y0, x1, y1] = O.box, g = olx.createLinearGradient(x0, y0, x1, y1);
      g.addColorStop(0, '#BFE8FF'); g.addColorStop(.5, '#9CC8FF'); g.addColorStop(1, '#CFE3FF');
      for (const [c, w, st] of [[olx, 1.75 * PT, g], [olg, 3.5 * PT, 'rgb(120,190,255)']]) {
        c.save(); photoXform(c, t); c.globalAlpha = A; c.lineWidth = w; c.lineJoin = 'round'; c.lineCap = 'round'; c.strokeStyle = st; drawnPath(c, O, h); c.stroke(); c.restore();
      }
    });
    if (!any) return;
    ctx.save(); ctx.globalCompositeOperation = 'screen';
    ctx.filter = `blur(${2.5 * PT}px)`; ctx.globalAlpha = .65; ctx.drawImage(OLG, 0, 0);
    ctx.filter = `blur(${8 * PT}px)`; ctx.globalAlpha = .6; ctx.drawImage(OLG, 0, 0);
    ctx.restore();
    ctx.save(); ctx.filter = `drop-shadow(0 0 ${5 * PT}px rgba(140,200,255,0.95)) drop-shadow(0 0 ${16 * PT}px rgba(40,120,255,0.6))`; ctx.drawImage(OL, 0, 0); ctx.restore();
  }

  // ---------- light trails (the fresh line behind the pen, the small light's glint, the arcs in the air) ----------
  const DT = document.createElement('canvas'); DT.width = W; DT.height = H; const dtx = DT.getContext('2d');
  function trail(pts, from, to, alphaAt, width) {           // short glowing strokes along pts[from..to]
    dtx.lineWidth = width;
    for (let i = from; i < to; i++) { const p = pts[i], q = pts[i + 1]; if (!p || !q) continue; const al = alphaAt(i) * Math.min(edgeFade(p), edgeFade(q)); if (al < .01) continue; dtx.strokeStyle = `rgba(200,232,255,${Math.min(1, al)})`; dtx.beginPath(); dtx.moveTo(p[0], p[1]); dtx.lineTo(q[0], q[1]); dtx.stroke(); }
  }
  function lights(t) {
    dtx.clearRect(0, 0, W, H); dtx.save(); photoXform(dtx, t); dtx.lineCap = 'round'; let any = false; const tp = tau(t);
    SCAN_K.forEach((k, r) => {                              // just behind the pen the new line is brighter for a moment (W2)
      if (tp < LOCK[r] || tp > CLOSE(r) + .4) return; any = true;
      const O = objO(k), td = tdOf(k), h = Math.min(O.n - 1, Math.floor(headOf(k, tp).h)), from = Math.max(0, h - 60);
      trail(O.pts, from, h, i => .75 * Math.exp(-(tp - td[i]) / .14), 2.4 * PT);
    });
    const pen = penAt(t);
    if (pen && pen.hop) { const [a, b, u] = pen.hop, pts = bezPts(a, hopArc(a, b), b, 40), m = Math.floor(u * 40); any = true; trail(pts, Math.max(0, m - 14), m, i => .3 * Math.exp(-(m - i) / 6), 1.6 * PT); }
    const pa = patrolA(t);
    if (pa > 0) {                                           // the line just behind the small light glints; in the air, a faint arc
      const p = patrolAt(t); any = true;
      if (p.sg.type === 'o') { const O = objO(p.sg.k), ext = O.pts.concat(O.pts), j = p.i + O.n; trail(ext, j - 30, j, i => .55 * pa * Math.exp(-(j - i) / 9), 2 * PT); }
      else { const m = p.i; trail(p.sg.pts, Math.max(0, m - 10), m, i => .25 * pa * Math.exp(-(m - i) / 5), 1.4 * PT); }
    }
    dtx.restore(); if (!any) return;
    ctx.save(); ctx.globalCompositeOperation = 'lighter'; ctx.filter = 'blur(5px)'; ctx.drawImage(DT, 0, 0); ctx.filter = 'none'; ctx.drawImage(DT, 0, 0); ctx.restore();
  }
  function over(t) {
    bracket(t);
    const pen = penAt(t); if (pen) { const [x, y] = toScreen(t, ...pen.xy); glowDot(x, y, PEN_R, pen.a * edgeFade(pen.xy)); }   // the big light (W2: 34 px)
    const pa = patrolA(t); if (pa > 0) { const p = patrolAt(t), [x, y] = toScreen(t, ...p.xy); glowDot(x, y, SMALL_R, .8 * pa * edgeFade(p.xy)); }   // the small one
  }
  function cues() {                                         // every time in real (film) seconds
    return { kind: 'pen-catchup', bracketIn: +BR_IN.toFixed(3), move: SCAN_K.map((_, r) => +real(MOVE0(r)).toFixed(3)), lock: SCAN_K.map((_, r) => +LOCK_R(r).toFixed(3)), lockIds: SCAN_K.map(k => TAGS[k].id),
      lockX: SCAN_K.map(k => Math.round((boxOf(k)[0] + boxOf(k)[2]) / 2)), close: SCAN_K.map((_, r) => +CLOSE_R(r).toFixed(3)), drawEnd: +DRAW_END_R().toFixed(3),
      closeV9: SCAN_K.map((_, r) => +CLOSE(r).toFixed(3)), catchUp: { k: +K.toFixed(2), from: +T_NAMES.toFixed(3), left: +LEFT.toFixed(3) },
      patrol: patrolA(T_NAMES - .01) > 0 || T_NAMES > P0() ? { from: +P0().toFixed(3), to: +T_NAMES.toFixed(3) } : null, found: +FOUND().toFixed(3) };
  }
  return { backdrop: t => photoBase(t), draw(t) { outlines(t); lights(t); }, over, TAG, get scanned() { return DRAW_END_R(); }, cues };
})();
function conceptO10(t) { CUES.O10 = Object.assign(O10.cues(), { names: T_NAMES, tags: TAGS.map((_, k) => +O10.TAG(k).toFixed(3)), tap: T_TAP, end: T_TAP + .6 }); scan7Frame(t, O10); }
