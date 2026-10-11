// scan.js — shared by the scan-wait concepts (S1–S4): what the device knows when, the object masks, the final tags.
// Timeline (same for every concept, so they can be compared side by side):
//   T_CAP        shutter
//   T_MASK(i)    the on-device masks (Vision, iOS 17+: VNGenerateForegroundInstanceMaskRequest) — well under a second
//   T_NAMES      the AI answer (here 3.0 s after the shutter; design median 2.5 s, usually under 8 s)
//   T_REVEAL(i)  each word is revealed in turn, in the order the answer lists them (with streaming: as each arrives)
const T_MASK = i => T_CAP + .38 + .08 * i;
const T_REVEAL = i => T_NAMES + .14 * i;
const SCAN_END = T_TAP + .6;
const NEW_WORD = { cup: true, scooter: true, plant: false, sign: true };   // not yet in this user's 図鑑

// ---------- masks (precise, from masks/seg3.py) ----------
const MK = {};
async function loadScan() {
  for (const id of ['cup', 'scooter', 'plant', 'sign']) {
    const im = await img(`masks/${id}.png`);
    const c = document.createElement('canvas'); c.width = W; c.height = H; const g = c.getContext('2d', { willReadFrequently: true });
    g.drawImage(im, 0, 0); const d = g.getImageData(0, 0, W, H), p = d.data;
    let x0 = W, y0 = H, x1 = 0, y1 = 0;
    for (let i = 0, k = 0; i < p.length; i += 4, k++) { const a = p[i]; p[i] = p[i + 1] = p[i + 2] = 255; p[i + 3] = a; if (a > 20) { const x = k % W, y = (k / W) | 0; if (x < x0) x0 = x; if (x > x1) x1 = x; if (y < y0) y0 = y; if (y > y1) y1 = y; } }
    g.putImageData(d, 0, 0);
    const pad = 24; x0 = Math.max(0, x0 - pad); y0 = Math.max(0, y0 - pad); x1 = Math.min(W, x1 + pad); y1 = Math.min(H, y1 + pad);
    const b = document.createElement('canvas'); b.width = x1 - x0; b.height = y1 - y0; b.getContext('2d').drawImage(c, -x0, -y0);
    MK[id] = { c: b, x: x0, y: y0, w: x1 - x0, h: y1 - y0, alpha: g.getImageData(x0, y0, x1 - x0, y1 - y0).data };
  }
}
// the photo's transform at time t (it settles for 0.5 s after the shutter) — masks follow it exactly
function photoXform(c, t, { scale = 1, focus = null } = {}) {
  const ps = photoState(t), s = ps.s * scale, [fx, fy] = focus || [W / 2, H / 2];
  c.translate(fx + ps.dx, fy + ps.dy); c.scale(s, s); c.translate(-fx, -fy);
}
function maskAt(id, x, y) { const M = MK[id], i = Math.round(x) - M.x, j = Math.round(y) - M.y; if (i < 0 || j < 0 || i >= M.w || j >= M.h) return 0; return M.alpha[(j * M.w + i) * 4 + 3] / 255; }
const TMP = document.createElement('canvas'); TMP.width = W; TMP.height = H; const tmx = TMP.getContext('2d');

// ---------- shared pieces ----------
const cupTag = TAGS[0];
const cupTagPress = t => seg(t, T_TAP, T_TAP + .06) * (1 - seg(t, T_TAP + .1, T_TAP + .2));
const tagFinger = [cupTag.p[0] + 40, cupTag.p[1] - 86];
function photoBase(t, { blur = 0, bright = 1, sat = 1, scale = 1, focus = null } = {}) {
  bgx.clearRect(0, 0, W, H); drawPhoto(bgx, t, { blur, bright, sat, scale, focus });
}
function scanPills(t, tHide, { found = T_MASK(3) + .25, hint = T_REVEAL(3) + .55 } = {}) {
  if (t < found) topPill(t, T_CAP + .15, Math.min(tHide, T_NAMES), 'AIが写真を見ています', { shimmer: true });
  else topPill(t, T_CAP + .15, Math.min(tHide, T_NAMES + .1), `${TAGS.length}つ見つけました・名前を調べています`, { shimmer: true, prev: 'AIが写真を見ています', tSwap: found });
  topPill(t, hint, tHide, '覚えたいことばをタップ', { icon: 'sparkles' });
}
// status for the decoupled scan: the device scans (no network) → the AI looks the names up → tap
function scanPills2(t, tScanned, tHint, tHide = 99) {
  if (t < tScanned) topPill(t, T_CAP + .15, tHide, '写真をスキャンしています', { shimmer: true });
  else topPill(t, T_CAP + .15, Math.min(tHide, T_NAMES + .1), '名前を調べています', { shimmer: true, prev: '写真をスキャンしています', tSwap: tScanned });
  topPill(t, tHint, tHide, '覚えたいことばをタップ', { icon: 'sparkles' });
}
// the NEW badge on a tag (blue capsule at its top-right corner)
function newBadge(tag, t, t0, { alpha = 1, cx = null, cy = null } = {}) {
  const g = tagGeom(tag), k = E.outBack(seg(t, t0, t0 + .32), 2.6); if (k <= 0 || alpha <= 0) return;
  const X = (cx == null ? tag.p[0] : cx) + g.w / 2 - 18, Y = (cy == null ? g.y + g.h / 2 : cy) - g.h / 2 + 2;
  ctx.save(); ctx.globalAlpha *= alpha; ctx.translate(X, Y); ctx.scale(k, k); ctx.rotate(.08);
  ctx.shadowColor = 'rgba(0,80,200,0.35)'; ctx.shadowBlur = 12; ctx.shadowOffsetY = 4; ctx.fillStyle = BLUE; rr(-46, -20, 92, 40, 20); ctx.fill(); ctx.shadowColor = 'transparent';
  text('NEW', 0, 9, { w: 800, size: 24, f: FONT_UI, color: '#fff', ls: 1.5 }); ctx.restore();
}
// every concept ends in this state: the app's tags on the photo (used by A and D from the tap onward)
function tagsSettled(t, { cupAlpha = 1, otherAlpha = 1, cupPress = 0, hideCup = 0, badges = true } = {}) {
  TAGS.forEach(tag => {
    const a = tag.id === 'cup' ? cupAlpha * (1 - hideCup) : otherAlpha; if (a <= 0) return;
    ctx.save(); ctx.globalAlpha *= a; tagAnchor(tag, t, 1, 1); ctx.restore();
    drawTag(tag, t, { alpha: a, press: tag.id === 'cup' ? cupPress : 0 });
    if (badges && NEW_WORD[tag.id]) newBadge(tag, t, -1, { alpha: a });
  });
}
function scanEnd(t) {   // the tap on the cup's tag (every scan film ends here)
  finger(tagFinger[0], tagFinger[1], t, T_TAP - .22, T_TAP);
}

// the photo dimmed a little, with the found things lit (each fades in from the point its word belongs to)
const SPOT5 = document.createElement('canvas'); SPOT5.width = W; SPOT5.height = H; const sp5 = SPOT5.getContext('2d');
function spotBackdrop(t, lit, { dim = 0, blur = 0, scale = 1, focus = null, sat = 1 } = {}) {
  photoBase(t, { blur, bright: 1 - dim, sat: lerp(1, sat, dim / .25), scale, focus });
  if (dim <= .001) return;
  TAGS.forEach((tag, i) => {
    const a = lit[i]; if (!(a > 0)) return; const M = MK[tag.id];
    sp5.save(); sp5.clearRect(M.x - 40, M.y - 40, M.w + 80, M.h + 80); sp5.beginPath(); sp5.rect(M.x - 40, M.y - 40, M.w + 80, M.h + 80); sp5.clip();
    drawPhoto(sp5, t, { blur, scale, focus });
    sp5.globalCompositeOperation = 'destination-in'; sp5.save(); photoXform(sp5, t, { scale, focus }); sp5.drawImage(M.c, M.x, M.y); sp5.restore();
    const [ax, ay] = tag.p, R = Math.hypot(M.w, M.h) * a + 1, g = sp5.createRadialGradient(ax, ay, R * .55, ax, ay, R);
    g.addColorStop(0, '#000'); g.addColorStop(1, 'rgba(0,0,0,0)'); sp5.fillStyle = g; sp5.fillRect(M.x - 40, M.y - 40, M.w + 80, M.h + 80);
    sp5.restore();
    bgx.drawImage(SPOT5, M.x - 40, M.y - 40, M.w + 80, M.h + 80, M.x - 40, M.y - 40, M.w + 80, M.h + 80);
  });
}
// the found thing as a cut-out (photo through its mask), cropped to its box — for tiles and particles
const CUTS = {};
function cutOf(id) {
  if (CUTS[id]) return CUTS[id];
  const M = MK[id], c = document.createElement('canvas'); c.width = M.w; c.height = M.h; const g = c.getContext('2d');
  g.drawImage(A.photo, -M.x, -M.y, W, H); g.globalCompositeOperation = 'destination-in'; g.drawImage(M.c, 0, 0);
  const s = document.createElement('canvas'); s.width = M.w; s.height = M.h; const sx = s.getContext('2d');
  sx.drawImage(M.c, 0, 0); sx.globalCompositeOperation = 'source-in'; sx.fillStyle = '#B4C0CF'; sx.fillRect(0, 0, M.w, M.h);
  return CUTS[id] = { c, s, w: M.w, h: M.h };
}
