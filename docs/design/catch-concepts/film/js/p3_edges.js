// P3 輪郭解析 — the camera reads the structure of the photo. The real edges of the photo (computed on device, e.g. Core
// Image / Vision contours) light up in a wave that spreads from the middle of the frame; behind it the edges of the
// background fade while those of the things stay; the corners the camera locks onto twinkle on them; then each thing's
// outline closes cleanly and it is lifted out of the scene (lit). Independent of the AI; the names arrive when they do.
let EDG = null, EDO = null, KP = null;
async function loadEdges() { EDG = await img('masks/edges.png'); EDO = await img('masks/edges_obj.png'); KP = await (await fetch('masks/keypoints.json')).json(); }
const P3_SCAN = ['cup', 'scooter', 'sign'];
const WAVE = [T_VIS, T_VIS + 1.05], P3_CENTER = [540, 1260], P3_R = Math.hypot(540, 1260) + 120;
const P3_CLOSE = k => T_VIS + .95 + .16 * P3_SCAN.indexOf(TAGS[k].id);
function p3Edges(t) {
  const u = seg(t, WAVE[0], WAVE[1]); if (t < WAVE[0]) return;
  const R = E.inOutSine(u) * P3_R, band = 260, names = T_NAMES;
  // the wave: all edges, lit inside a ring that spreads from the middle
  if (u < 1) {
    tmx.save(); tmx.clearRect(0, 0, W, H); tmx.drawImage(EDG, 0, 0); tmx.globalCompositeOperation = 'destination-in';
    const g = tmx.createRadialGradient(P3_CENTER[0], P3_CENTER[1], Math.max(0, R - band), P3_CENTER[0], P3_CENTER[1], R);
    g.addColorStop(0, 'rgba(0,0,0,0)'); g.addColorStop(.75, 'rgba(0,0,0,1)'); g.addColorStop(1, 'rgba(0,0,0,0)');
    tmx.fillStyle = g; tmx.fillRect(0, 0, W, H); tmx.restore();
    ctx.save(); photoXform(ctx, t); ctx.globalCompositeOperation = 'screen'; ctx.drawImage(TMP, 0, 0);
    ctx.globalAlpha = .55; ctx.filter = 'blur(4px)'; ctx.drawImage(TMP, 0, 0); ctx.restore();
  }
  // behind the wave the things keep their edges (they shimmer while the names are looked up)
  const keep = seg(t, WAVE[0] + .25, WAVE[0] + .7) * (1 - E.inOutCubic(seg(t, names, names + .6)));
  if (keep > 0) {
    tmx.save(); tmx.clearRect(0, 0, W, H); tmx.drawImage(EDO, 0, 0); tmx.globalCompositeOperation = 'destination-in';
    const g = tmx.createRadialGradient(P3_CENTER[0], P3_CENTER[1], Math.max(0, R - band * .6), P3_CENTER[0], P3_CENTER[1], R - band * .2);
    g.addColorStop(0, 'rgba(0,0,0,1)'); g.addColorStop(1, 'rgba(0,0,0,0)'); tmx.fillStyle = g; tmx.fillRect(0, 0, W, H); tmx.restore();
    ctx.save(); photoXform(ctx, t); ctx.globalCompositeOperation = 'screen'; ctx.globalAlpha = keep * (.42 + .1 * Math.sin(t * 3.1)); ctx.drawImage(u < 1 ? TMP : EDO, 0, 0); ctx.restore();
  }
}
function p3Keypoints(t) {
  const names = T_NAMES;
  P3_SCAN.forEach(id => {
    const k = TAGS.findIndex(tg => tg.id === id), out = 1 - E.inOutCubic(seg(t, names + .1 * k, names + .1 * k + .4)); if (out <= 0) return;
    KP[id].forEach(([x, y], j) => {
      const tp = lerp(WAVE[0], WAVE[1], clamp(Math.hypot(x - P3_CENTER[0], y - P3_CENTER[1]) / P3_R)) + .05;   // when the wave reaches it
      const a0 = seg(t, tp, tp + .12); if (a0 <= 0) return;
      const tw = .55 + .45 * Math.sin(t * 6 + j * 2.3), a = a0 * out * tw, s = 7 + 4 * Math.sin(Math.PI * seg(t, tp, tp + .3));
      ctx.save(); photoXform(ctx, t); ctx.globalAlpha = a; ctx.strokeStyle = '#fff'; ctx.lineWidth = 2; ctx.lineCap = 'round';
      ctx.beginPath(); ctx.moveTo(x - s, y); ctx.lineTo(x + s, y); ctx.moveTo(x, y - s); ctx.lineTo(x, y + s); ctx.stroke();
      ctx.fillStyle = 'rgba(100,224,255,0.9)'; ctx.beginPath(); ctx.arc(x, y, 2.4, 0, Math.PI * 2); ctx.fill(); ctx.restore();
    });
  });
}
// each thing's outline closes cleanly (a fast clockwise stroke) — the moment it is separated from the scene
function p3Outlines(t) {
  P3_SCAN.forEach(id => {
    const k = TAGS.findIndex(tg => tg.id === id), tc = P3_CLOSE(k), O = outlineOf(id), u = E.inOutCubic(seg(t, tc, tc + .42)); if (u <= 0) return;
    const fade = (1 - seg(t, tc + .5, tc + 1.1)) * .9 + .1 * (1 - E.inOutCubic(seg(t, T_NAMES + .1 * k, T_NAMES + .1 * k + .4)));
    if (fade <= 0) return;
    const m = Math.floor(O.n * u);
    ctx.save(); photoXform(ctx, t); ctx.globalCompositeOperation = 'lighter'; ctx.lineJoin = 'round'; ctx.lineCap = 'round';
    ctx.beginPath(); for (let i = 0; i <= m; i++) { const p = O.pts[i % O.n]; i ? ctx.lineTo(p[0], p[1]) : ctx.moveTo(p[0], p[1]); }
    ctx.strokeStyle = `rgba(100,224,255,${.5 * fade})`; ctx.lineWidth = 10; ctx.filter = 'blur(6px)'; ctx.stroke(); ctx.filter = 'none';
    ctx.strokeStyle = `rgba(255,255,255,${.95 * fade})`; ctx.lineWidth = 2.6; ctx.stroke(); ctx.restore();
  });
}
function conceptP3(t) {
  CUES.P3 = { vis: T_VIS, wave: WAVE, close: P3_SCAN.map(id => +P3_CLOSE(TAGS.findIndex(tg => tg.id === id)).toFixed(3)), names: T_NAMES, tags: TAGS.map((_, k) => +(T_NAMES + .1 * k).toFixed(3)), tap: T_TAP, end: SCAN_END };
  const dim = .36 * E.outCubic(seg(t, T_VIS - .05, T_VIS + .3)) * (1 - E.inOutCubic(seg(t, T_NAMES + .3, T_NAMES + .9)));
  const lit = TAGS.map((tag, k) => P3_SCAN.includes(tag.id) ? E.outCubic(seg(t, P3_CLOSE(k) + .2, P3_CLOSE(k) + .7)) : 0);
  spotBackdrop(t, lit, { dim, sat: .6 });
  makeBlur(); ctx.drawImage(BG, 0, 0);
  capFlash(t); camChrome(t);
  p3Edges(t);
  p3Keypoints(t);
  p3Outlines(t);
  p2Tags(t);
  scanPills2(t, P3_CLOSE(3) + .5, T_NAMES + .85);
  tabBar({ sel: 2, t });
  scanEnd(t);
  statusBar(false); homeIndicator(false);
}
