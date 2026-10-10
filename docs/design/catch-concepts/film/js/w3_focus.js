// W3 ピント（焦点が合う）— after the shot the picture softens, as a camera does before it focuses; then the focus
// lands on each thing in turn: the thing turns sharp and its blue outline condenses from a wide soft glow into a crisp
// line — the outline comes into focus with it. Waiting: the camera keeps checking its focus — one thing at a time is
// the sharpest (its outline brighter, a hair of focus breathing), the softness of the rest breathes with the beat, the
// screen edge glows. Names: the whole picture comes into focus, the outlines settle, the tags rise.
const W3 = (() => {
  const F = r => T_VIS + .1 + .46 * r, FD = .42;
  const found = k => { const r = scanRank(k); return [F(r), F(r) + FD]; };
  const REV_END = () => F(2) + FD;
  const TAG = k => scanRank(k) < 0 ? T_NAMES + .1 * k : Math.max(T_NAMES + .1 * k, found(k)[1] + .15);
  const STEP = LOOP / 3;                                  // the focus check moves to the next thing every 0.8 s
  const W0 = () => REV_END() + .25;
  const waitA = t => clamp((t - W0()) / .3) * (1 - seg(t, T_NAMES - .05, T_NAMES + .25));
  const activeOf = t => Math.floor((t - W0()) / STEP) % 3;
  const bellOf = t => Math.sin(Math.PI * (((t - W0()) / STEP) % 1)) ** 2;
  const blurOf = t => { const on = E.inOutCubic(seg(t, T_CAP + .1, T_CAP + .5)), off = 1 - E.inOutCubic(seg(t, T_NAMES, T_NAMES + .5)); return 16 * on * off * (1 + .14 * Math.sin(2 * Math.PI * (t - W0()) / LOOP) * waitA(t)); };
  function backdrop(t) {
    photo7(t, { blur: blurOf(t) });
    // the found things, sharp, over the soft picture (they leave once the whole picture is sharp again)
    [3, 1, 0].forEach(k => {
      const r = scanRank(k), e = E.inOutCubic(seg(t, F(r), F(r) + FD)) * (1 - E.inOutCubic(seg(t, T_NAMES + .15, T_NAMES + .6))); if (e <= 0) return;
      const tag = TAGS[k], M = MK[tag.id], C = cutOf(tag.id), O = objO(k);
      const pulse = waitA(t) * (activeOf(t) === r ? bellOf(t) : 0), sc = 1 + .03 * (1 - E.outCubic(seg(t, F(r), F(r) + FD))) + .008 * pulse;
      bgx.save(); photoXform(bgx, t); bgx.translate(O.cx, O.cy); bgx.scale(sc, sc); bgx.translate(-O.cx, -O.cy); bgx.globalAlpha = e;
      bgx.filter = `brightness(${1 + .05 * pulse})`; bgx.drawImage(C.c, M.x, M.y); bgx.filter = 'none'; bgx.restore();
    });
  }
  function draw(t) {
    SCAN_K.forEach((k, r) => {
      if (t < F(r)) return;
      const O = objO(k), tn = TAG(k), rest = restA(t, tn), e = E.outCubic(seg(t, F(r), F(r) + FD)); if (rest <= 0) return;
      const pulse = waitA(t) * (activeOf(t) === r ? bellOf(t) : 0), settle = E.inOutCubic(seg(t, F(r) + FD, F(r) + FD + .5));
      const flash = Math.sin(Math.PI * seg(t, tn - .12, tn + .25));
      const a = (lerp(.3, .95, e) - .3 * settle + .38 * pulse + .45 * flash) * rest;
      queueOutline(O, () => a, { width: lerp(54, 15, e), core: lerp(.5, 2.6, e), coreMul: .85 * e });
    });
  }
  function edge(t) { return { boost: .18 * waitA(t) * bellOf(t) }; }
  function cues() {
    const checks = []; for (let t0 = W0(), i = 0; t0 < T_NAMES - .1; t0 += STEP, i++) checks.push({ t: +t0.toFixed(3), obj: i % 3, x: Math.round(objO(SCAN_K[i % 3]).cx) });
    return { kind: 'focus', defocus: T_CAP + .1, focus: SCAN_K.map((_, r) => +F(r).toFixed(3)), lock: SCAN_K.map((_, r) => +(F(r) + FD).toFixed(3)), focusX: SCAN_K.map(k => Math.round(objO(k).cx)), checks, refocus: T_NAMES };
  }
  return { backdrop, draw, edge, TAG, get scanned() { return REV_END() - .1; }, cues };
})();
function conceptW3(t) { CUES.W3 = Object.assign(W3.cues(), { names: T_NAMES, tags: TAGS.map((_, k) => +W3.TAG(k).toFixed(3)), tap: T_TAP, end: T_TAP + .6 }); scan7Frame(t, W3); }
