// W4 光の流れ（画面の縁から物へ）— the glowing screen edge (the AI at work) reaches in: from the nearest part of the
// edge a thin line of light runs to each thing, touches its outline and runs round it both ways until the two ends
// meet. Waiting: pulses of light keep travelling from the edge along each line and round its thing — the edge
// brightens where each pulse leaves — as if the AI were looking at the things. Names: the lines draw back into the
// edge, each outline flashes, the tags rise.
const W4 = (() => {
  const L0 = r => T_VIS + .04 + .3 * r, FL = .3, RUN = .55, MIN = 120;
  const LINK = {};
  function link(k) {                                      // the nearest edge at least MIN px away, and the outline point nearest it
    if (LINK[k]) return LINK[k];
    const O = objO(k); let best = null;
    O.pts.forEach((p, i) => [['l', p[0]], ['r', W - p[0]], ['t', p[1] - 0], ['b', H - p[1]]].forEach(([e, d]) => { if (d >= MIN && (!best || d < best.d)) best = { e, d, i }; }));
    const p = O.pts[best.i], root = best.e === 'l' ? [0, p[1]] : best.e === 'r' ? [W, p[1]] : best.e === 't' ? [p[0], 0] : [p[0], H];
    const dx = p[0] - root[0], dy = p[1] - root[1], len = Math.hypot(dx, dy), side = scanRank(k) % 2 ? 1 : -1;
    const c = [(root[0] + p[0]) / 2 - dy / len * len * .16 * side, (root[1] + p[1]) / 2 + dx / len * len * .16 * side];
    const pts = bezPts(root, c, p, 50);
    return LINK[k] = { root, ic: best.i, pts, edge: best.e };
  }
  const found = k => { const r = scanRank(k); return [L0(r), L0(r) + FL + RUN]; };
  const REV_END = () => Math.max(...SCAN_K.map(k => found(k)[1]));
  const TAG = k => scanRank(k) < 0 ? T_NAMES + .1 * k : Math.max(T_NAMES + .1 * k, found(k)[1] + .15);
  const arcD = (O, i, ic) => { const d = Math.abs(i - ic); return Math.min(d, O.n - d); };
  // waiting pulses: per thing one every LOOP, staggered by a third of the loop
  function pulses() {
    const out = []; SCAN_K.forEach((k, r) => { for (let t0 = REV_END() + .3 + r * LOOP / 3; t0 < T_NAMES - .1; t0 += LOOP) out.push({ t0, k, r }); });
    return out.sort((a, b) => a.t0 - b.t0);
  }
  const PF = .45, PR = .6;                                // pulse: along the line, then round the outline
  const pulseA = (t, p) => 1 - seg(t, T_NAMES, T_NAMES + .3);
  function draw(t) {
    const PS = pulses();
    SCAN_K.forEach((k, r) => {
      const O = objO(k), L = link(k), tn = TAG(k), rest = restA(t, tn); if (t < L0(r) || rest <= 0) return;
      // the line from the edge: drawn out, then it stays faint (breathing); on the names it draws back into the edge
      const u = E.outCubic(seg(t, L0(r), L0(r) + FL)), back = E.inOutCubic(seg(t, T_NAMES + .1 * r, T_NAMES + .1 * r + .32)), m = L.pts.length - 1;
      const lineA = i => { const f = i / m; if (f > u || f > 1 - back + 1e-6 && back > 0 && f > (1 - back)) return 0; const head = (u < 1 ? Math.exp(-(u - f) * 9) * .8 : 0); let a = .34 + .06 * Math.sin(2 * Math.PI * (t - T_CAP) / LOOP) + head;
        for (const p of PS) if (p.k === k && t > p.t0 && t < p.t0 + PF + .1) { const pf = (t - p.t0) / PF; a += .9 * pulseA(t, p) * Math.exp(-(((f - pf) * 9) ** 2)); }
        return a * (1 - back * .3); };
      queueLine(L.pts, lineA, { width: 9, core: 1.6 });
      // the outline: lit as the two runners pass; glints when a pulse runs round; flashes on the name
      const t1 = L0(r) + FL, flash = Math.sin(Math.PI * seg(t, tn - .12, tn + .25));
      queueOutline(O, i => {
        const d = arcD(O, i, L.ic), ti = t1 + RUN * d / (O.n / 2); if (t < ti) return 0;
        let a = .55 + .45 * Math.exp(-(t - ti) / .25);
        for (const p of PS) if (p.k === k && t > p.t0 + PF && t < p.t0 + PF + PR + .3) { const reach = (t - p.t0 - PF) / PR * (O.n / 2), b = reach - d; if (b >= 0) a += .6 * pulseA(t, p) * Math.exp(-b * 4 / 140); }
        return Math.min(1.25, a + .5 * flash) * rest;
      });
    });
  }
  function over(t) {                                      // the heads of the runners and the pulses
    const PS = pulses();
    SCAN_K.forEach((k, r) => {
      const O = objO(k), L = link(k), m = L.pts.length - 1;
      const u = seg(t, L0(r), L0(r) + FL); if (u > 0 && u < 1) { const [x, y] = toScreen(t, ...L.pts[Math.floor(E.outCubic(u) * m)]); glowDot(x, y, 26, .9); }
      const ru = seg(t, L0(r) + FL, L0(r) + FL + RUN); if (ru > 0 && ru < 1) [1, -1].forEach(sg => { const i = ((L.ic + sg * Math.floor(ru * O.n / 2)) % O.n + O.n) % O.n, [x, y] = toScreen(t, ...O.pts[i]); glowDot(x, y, 24, .85); });
      PS.filter(p => p.k === k).forEach(p => {
        const a = pulseA(t, p); if (a <= 0) return;
        const pf = (t - p.t0) / PF; if (pf > 0 && pf < 1) { const [x, y] = toScreen(t, ...L.pts[Math.floor(pf * m)]); glowDot(x, y, 20, .8 * a); }
        const pr = (t - p.t0 - PF) / PR; if (pr > 0 && pr < 1) [1, -1].forEach(sg => { const i = ((L.ic + sg * Math.floor(pr * O.n / 2)) % O.n + O.n) % O.n, [x, y] = toScreen(t, ...O.pts[i]); glowDot(x, y, 16, .6 * a * (1 - pr)); });
      });
    });
  }
  function edge(t) {
    const hits = [], PS = pulses();
    SCAN_K.forEach((k, r) => { const L = link(k), root = L.root;
      const g0 = Math.sin(Math.PI * seg(t, L0(r) - .1, L0(r) + .35)); if (g0 > 0) hits.push((x, y) => .6 * g0 * Math.exp(-((x - root[0]) ** 2 + (y - root[1]) ** 2) / (2 * 90 * 90)));
      PS.filter(p => p.k === k).forEach(p => { const g = Math.sin(Math.PI * seg(t, p.t0 - .1, p.t0 + .3)) * pulseA(t, p); if (g > 0) hits.push((x, y) => .45 * g * Math.exp(-((x - root[0]) ** 2 + (y - root[1]) ** 2) / (2 * 80 * 80))); });
      const bk = Math.sin(Math.PI * seg(t, T_NAMES + .1 * r + .15, T_NAMES + .1 * r + .5)); if (bk > 0) hits.push((x, y) => .5 * bk * Math.exp(-((x - root[0]) ** 2 + (y - root[1]) ** 2) / (2 * 90 * 90)));
    });
    return { hits };
  }
  function cues() {
    return { kind: 'stream', launch: SCAN_K.map((_, r) => +L0(r).toFixed(3)), touch: SCAN_K.map((_, r) => +(L0(r) + FL).toFixed(3)), close: SCAN_K.map(k => +found(k)[1].toFixed(3)),
      rootX: SCAN_K.map(k => Math.round(link(k).root[0])), objX: SCAN_K.map(k => Math.round(objO(k).cx)),
      pulses: pulses().map(p => ({ t: +p.t0.toFixed(3), obj: p.r, rootX: Math.round(link(p.k).root[0]), x: Math.round(objO(p.k).cx) })), retract: T_NAMES };
  }
  return { draw, over, edge, TAG, get scanned() { return REV_END() - .1; }, cues };
})();
function conceptW4(t) { CUES.W4 = Object.assign(W4.cues(), { names: T_NAMES, tags: TAGS.map((_, k) => +W4.TAG(k).toFixed(3)), tap: T_TAP, end: T_TAP + .6 }); scan7Frame(t, W4); }
