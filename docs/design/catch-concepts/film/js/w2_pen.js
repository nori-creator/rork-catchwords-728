// W2 光のペン（一筆書き）— a point of blue light draws each thing's real outline in one stroke, like a pen: slower
// round the turns, quicker along the straight runs; then it lifts and glides to the next thing. Waiting: the light
// keeps going round — along every outline in turn, hopping between them — and the line just behind it glints, while
// the screen edge glows. Names: the pen goes once more, quickly, round each thing, and its tag rises.
const W2 = (() => {
  const DUR = [1.0, .9, .6], HOP = .26, SPEED = 1350;
  const S = []; { let t0 = T_VIS + .05; SCAN_K.forEach((_, r) => { S[r] = t0; t0 += DUR[r] + HOP; }); }
  const TD = {};
  function tdOf(k) {                                      // when the pen passes each point (slower where the outline turns)
    if (TD[k]) return TD[k];
    const O = objO(k), r = scanRank(k), n = O.n, w = O.turn.map((_, i) => { let s = 0; for (let d = -4; d <= 4; d++) s += O.turn[(i + d + n) % n]; return 1 + 2.6 * s / 9; });
    let acc = 0; const T = w.map(x => (acc += x)); const tot = acc;
    return TD[k] = T.map(x => S[r] + DUR[r] * Math.acos(1 - 2 * Math.min(1, x / tot)) / Math.PI);
  }
  const found = k => { const r = scanRank(k); return [S[r], S[r] + DUR[r]]; };
  const DRAW_END = () => S[2] + DUR[2];
  const TAG = k => scanRank(k) < 0 ? T_NAMES + .1 * k : Math.max(T_NAMES + .1 * k, found(k)[1] + .15);
  const hopArc = (a, b) => { const m = [(a[0] + b[0]) / 2, Math.min(a[1], b[1]) - 160]; return m; };
  // the patrol while waiting: round outline 0, hop, outline 1, hop, outline 2, hop back; constant speed
  let PATH = null;
  function patrolPath() {
    if (PATH) return PATH;
    const segs = []; let L = 0;
    SCAN_K.forEach((k, r) => {
      const O = objO(k); segs.push({ type: 'o', k, L0: L, len: O.n * 4 }); L += O.n * 4;
      const a = O.pts[0], b = objO(SCAN_K[(r + 1) % 3]).pts[0], c = hopArc(a, b), pts = bezPts(a, c, b, 40);
      let hl = 0; for (let i = 1; i < pts.length; i++) hl += Math.hypot(pts[i][0] - pts[i - 1][0], pts[i][1] - pts[i - 1][1]);
      segs.push({ type: 'h', pts, L0: L, len: hl }); L += hl;
    });
    return PATH = { segs, L };
  }
  const P0 = () => DRAW_END() + .3;
  const patrolA = t => clamp((t - P0()) / .3) * (1 - seg(t, T_NAMES - .05, T_NAMES + .2));
  function patrolAt(t) {                                  // where the patrol light is: { seg, s (arc length within seg), xy }
    const P = patrolPath(), d = ((t - P0()) * SPEED) % P.L;
    for (const sg of P.segs) if (d < sg.L0 + sg.len) {
      const s = d - sg.L0;
      if (sg.type === 'o') { const O = objO(sg.k), i = Math.min(O.n - 1, Math.floor(s / 4)); return { sg, s, xy: O.pts[i] }; }
      const u = s / sg.len, i = Math.min(sg.pts.length - 1, Math.floor(u * (sg.pts.length - 1))); return { sg, s, xy: sg.pts[i], u };
    }
    return { sg: P.segs[0], s: 0, xy: objO(SCAN_K[0]).pts[0] };
  }
  function penAt(t) {                                     // the drawing pen (during the found phase)
    for (let r = 0; r < 3; r++) {
      const k = SCAN_K[r], O = objO(k), td = tdOf(k);
      if (t >= S[r] && t <= S[r] + DUR[r]) { let i = 0; while (i < O.n - 1 && td[i + 1] <= t) i++; return { xy: O.pts[i], a: 1 }; }
      if (r < 2 && t > S[r] + DUR[r] && t < S[r + 1]) { const a = O.pts[0], b = objO(SCAN_K[r + 1]).pts[0], u = E.inOutSine(seg(t, S[r] + DUR[r], S[r + 1])); return { xy: bez2(a, hopArc(a, b), b, u), a: .55, hop: [a, b, u] }; }
    }
    return null;
  }
  function draw(t) {
    SCAN_K.forEach((k, r) => {
      const O = objO(k), td = tdOf(k), tn = TAG(k), rest = restA(t, tn); if (t < S[r] || rest <= 0) return;
      // the patrol's glint and the final quick retrace
      const pa = patrolA(t), here = pa > 0 ? patrolAt(t) : null, onMe = here && here.sg.type === 'o' && here.sg.k === k;
      const rt0 = tn - .12, ru = seg(t, rt0, rt0 + .36), rhead = E.inOutSine(ru) * O.n;
      queueOutline(O, i => {
        const dt = t - td[i]; if (dt < 0) return 0;
        let a = .58 + .42 * Math.exp(-dt / .3);
        if (onMe) { const behind = here.s / 4 - i; if (behind >= 0) a += .5 * pa * Math.exp(-behind * 4 / 120); }
        if (ru > 0 && ru < 1) { const b = rhead - i; if (b >= 0) a += .7 * Math.exp(-b * 4 / 160); }
        return Math.min(1.25, a) * rest;
      });
    });
    // the pen in the air between things: a faint arc of its path
    const pen = penAt(t);
    if (pen && pen.hop) { const [a, b, u] = pen.hop, pts = bezPts(a, hopArc(a, b), b, 40), m = Math.floor(u * 40); queueLine(pts, i => (i <= m ? .28 * Math.exp(-(m - i) / 10) : 0), { width: 8, core: 1.2, coreMul: .5 }); }
    // the patrol's hops
    if (patrolA(t) > 0) { const h = patrolAt(t); if (h.sg.type === 'h') { const m = Math.floor(h.u * (h.sg.pts.length - 1)); queueLine(h.sg.pts, i => (i <= m ? .22 * patrolA(t) * Math.exp(-(m - i) / 8) : 0), { width: 8, core: 1.2, coreMul: .5 }); } }
  }
  function over(t) {                                      // the points of light (screen space)
    const pen = penAt(t); if (pen) { const [x, y] = toScreen(t, ...pen.xy); glowDot(x, y, 34, pen.a); }
    const pa = patrolA(t); if (pa > 0) { const [x, y] = toScreen(t, ...patrolAt(t).xy); glowDot(x, y, 24, .75 * pa); }
    SCAN_K.forEach(k => { const O = objO(k), tn = TAG(k), ru = seg(t, tn - .12, tn + .24); if (ru <= 0 || ru >= 1) return; const [x, y] = toScreen(t, ...O.pts[Math.min(O.n - 1, Math.floor(E.inOutSine(ru) * O.n))]); glowDot(x, y, 30, Math.sin(Math.PI * ru)); });
  }
  function cues() {
    const notes = [];
    SCAN_K.forEach((k, r) => { const O = objO(k), td = tdOf(k); [0, .25, .5, .75].forEach((f, j) => { const i = Math.min(O.n - 1, Math.floor(f * O.n)); notes.push({ t: +td[i].toFixed(3), x: Math.round(O.pts[i][0]), obj: r, step: j }); }); });
    const patrol = []; for (let t0 = P0() + .3; t0 < T_NAMES - .1; t0 += LOOP / 4) patrol.push({ t: +t0.toFixed(3), x: Math.round(patrolAt(t0).xy[0]) });
    return { kind: 'pen', start: S, dur: DUR, close: SCAN_K.map((_, r) => +(S[r] + DUR[r]).toFixed(3)), closeX: SCAN_K.map(k => Math.round(objO(k).cx)), notes, patrol };
  }
  return { draw, over, TAG, get scanned() { return DRAW_END() - .1; }, cues };
})();
function conceptW2(t) { CUES.W2 = Object.assign(W2.cues(), { names: T_NAMES, tags: TAGS.map((_, k) => +W2.TAG(k).toFixed(3)), tap: T_TAP, end: T_TAP + .6 }); scan7Frame(t, W2); }
