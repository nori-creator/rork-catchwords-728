// dex.js — the 図鑑 page (the app's DexGallery: one white card per category, 4-column grid of slots — caught words
// as cut-outs, the next things to find as grey shadows) and the landing finale designed on collection psychology.
const S = (k, o = {}) => Object.assign({ k }, o);
const DEXCATS = [
  { no: 1, emoji: '🧋', label: '飲み物', total: 19, caught: 6, slots: [
    S('t', { no: 1, sil: 'cup', h: PICK.h, zy: PICK.zy }),
    S('c', { img: 'coffee', no: 2, h: '咖啡', zy: 'ㄎㄚ ㄈㄟ' }), S('c', { img: 'oolong', no: 3, h: '茶', zy: 'ㄔㄚˊ' }),
    S('c', { img: 'juice', no: 4, h: '果汁', zy: 'ㄍㄨㄛˇ ㄓ' }), S('c', { img: 'soymilk', no: 104, h: '豆漿', zy: 'ㄉㄡˋ ㄐㄧㄤ' }),
    S('c', { img: 'cola', no: 117, h: '可樂', zy: 'ㄎㄜˇ ㄌㄜˋ' }), S('c', { img: 'wintermelon', no: 126, h: '冬瓜茶', zy: 'ㄉㄨㄥ ㄍㄨㄚ ㄔㄚˊ' }),
    S('s', { sil: 'oolong', no: 5, h: '水', goal: true }), S('s', { sil: 'juice', h: '牛奶' }), S('s', { sil: 'mug', h: '紅茶' }),
    S('s', { sil: 'wintermelon', h: '綠茶' }), S('s', { sil: 'coffee', h: '奶茶', refill: true }),
  ] },
  { no: 2, emoji: '🍜', label: '料理・屋台', total: 19, caught: 3, slots: [
    S('c', { img: 'lurourice', no: 109, h: '滷肉飯', zy: 'ㄌㄨˇ ㄖㄡˋ ㄈㄢˋ' }), S('c', { img: 'xlb', no: 112, h: '小籠包', zy: 'ㄒㄧㄠˇ ㄌㄨㄥˊ ㄅㄠ' }),
    S('c', { img: 'chickencutlet', no: 121, h: '炸雞', zy: 'ㄓㄚˊ ㄐㄧ' }),
    S('s', { ph: 'bowl-food', no: 6, h: '飯' }), S('s', { ph: 'bowl-steam', no: 7, h: '麵' }), S('s', { cus: 'bento', no: 8, h: '便當' }),
    S('s', { cus: 'dumpling', no: 9, h: '水餃' }), S('s', { cus: 'bun', no: 10, h: '包子' }),
  ] },
  { no: 3, emoji: '🍎', label: '果物・野菜', total: 19, caught: 3, slots: [
    S('c', { img: 'banana', no: 12, h: '香蕉', zy: 'ㄒㄧㄤ ㄐㄧㄠ' }), S('c', { img: 'mango', no: 13, h: '芒果', zy: 'ㄇㄤˊ ㄍㄨㄛˇ' }),
    S('c', { img: 'pomelo', no: 118, h: '柚子', zy: 'ㄧㄡˋ ˙ㄗ' }),
    S('s', { cus: 'apple', no: 11, h: '蘋果' }), S('s', { cus: 'tomato', no: 14, h: '番茄' }), S('s', { cus: 'cabbage', no: 15, h: '高麗菜' }),
    S('s', { ph: 'orange', h: '橘子' }), S('s', { cus: 'watermelon', h: '西瓜' }),
  ] },
  { no: 4, emoji: '🍰', label: 'お菓子・パン', total: 19, caught: 3, slots: [
    S('c', { img: 'pcake', no: 20, h: '鳳梨酥', zy: 'ㄈㄥˋ ㄌㄧˊ ㄙㄨ' }), S('c', { img: 'douhua', no: 106, h: '豆花', zy: 'ㄉㄡˋ ㄏㄨㄚ' }),
    S('c', { img: 'mangoice', no: 143, h: '剉冰', zy: 'ㄘㄨㄛˋ ㄅㄧㄥ' }),
    S('s', { ph: 'bread', no: 16, h: '麵包' }), S('s', { ph: 'cake', no: 17, h: '蛋糕' }), S('s', { ph: 'cookie', no: 18, h: '餅乾' }),
    S('s', { ph: 'ice-cream', no: 19, h: '冰淇淋' }), S('s', { cus: 'candy', h: '糖果' }),
  ] },
  { no: 5, emoji: '🥢', label: '食器・台所', total: 20, caught: 1, slots: [
    S('c', { img: 'mug', no: 21, h: '杯子', zy: 'ㄅㄟ ˙ㄗ' }),
    S('s', { cus: 'bowl', no: 22, h: '碗' }), S('s', { cus: 'chopsticks', no: 23, h: '筷子' }), S('s', { cus: 'plate', no: 24, h: '盤子' }),
    S('s', { cus: 'spoon', no: 25, h: '湯匙' }), S('s', { ph: 'fork-knife', h: '叉子' }),
  ] },
  { no: 6, emoji: '🛋️', label: '家具・インテリア', total: 19, caught: 1, slots: [
    S('c', { img: 'stool', no: 26, h: '椅子', zy: 'ㄧˇ ˙ㄗ' }),
    S('s', { ph: 'table', no: 27, h: '桌子' }), S('s', { ph: 'bed', no: 28, h: '床' }), S('s', { ph: 'couch', no: 29, h: '沙發' }),
    S('s', { ph: 'clock', no: 30, h: '時鐘' }), S('s', { cus: 'window', h: '窗戶' }),
  ] },
  { no: 7, emoji: '🔌', label: '家電', total: 19, caught: 4, slots: [
    S('c', { img: 'aircon', no: 31, h: '冷氣', zy: 'ㄌㄥˇ ㄑㄧˋ' }), S('c', { img: 'fan', no: 35, h: '電風扇', zy: 'ㄉㄧㄢˋ ㄈㄥ ㄕㄢˋ' }),
    S('c', { img: 'ricecooker', no: 152, h: '電鍋', zy: 'ㄉㄧㄢˋ ㄍㄨㄛ' }), S('c', { img: 'remote', no: 160, h: '遙控器', zy: 'ㄧㄠˊ ㄎㄨㄥˋ ㄑㄧˋ' }),
    S('s', { cus: 'fridge', no: 32, h: '冰箱' }), S('s', { ph: 'television', no: 33, h: '電視' }), S('s', { ph: 'washing-machine', no: 34, h: '洗衣機' }),
    S('s', { ph: 'oven', h: '微波爐' }), S('s', { cus: 'hairdryer', h: '吹風機' }),
  ] },
];
DEXCATS.forEach(c => c.slots.forEach(s => { if (s.zy) s.u = Z(s.h, s.zy); }));

// ---------- layout (content coordinates; 1 pt = 2.75 px) ----------
const DX = 18 * PT, DCW = W - 2 * DX, DPAD = 12 * PT, GAP = 9 * PT;
const SLOT = (DCW - 2 * DPAD - 3 * GAP) / 4;
const ROW_H = SLOT + 8 + 28 + 8 + 50;
const DTITLE = 2 * PT + 38.5 + 10 * PT, DBAR = 28;
const DEX_HEAD = 352;                                    // header height (title + counts), list starts below it
let DLAY = null;
function dexLayout() {
  if (DLAY) return DLAY;
  let y = DEX_HEAD + 12 * PT; const cats = [];
  for (const c of DEXCATS) {
    const n = c.slots.length, rows = Math.ceil(n / 4);
    const h = DPAD + DTITLE + DBAR + rows * ROW_H + (rows - 1) * GAP + 14 * PT;
    const slots = c.slots.map((s, i) => ({ s, x: DX + DPAD + (i % 4) * (SLOT + GAP), y: y + DPAD + DTITLE + DBAR + Math.floor(i / 4) * (ROW_H + GAP) }));
    cats.push({ c, y, h, slots }); y += h + 12 * PT;
  }
  return DLAY = { cats, height: y + 400 };
}
const catY = no => dexLayout().cats[no - 1].y;
// scroll offset that brings a category's card to just under the header
const scrollToCat = no => catY(no) - DEX_HEAD - 12 * PT;
function targetSlot() { const L = dexLayout().cats[0].slots[0]; return { x: L.x, y: L.y, cx: L.x + SLOT / 2, cy: L.y + SLOT / 2 }; }

// ---------- silhouettes ----------
const CUS = {};
function cusPath(name) {
  if (CUS[name]) return CUS[name];
  const p = new Path2D();
  switch (name) {
    case 'apple': p.moveTo(128, 78); p.bezierCurveTo(92, 52, 30, 64, 34, 132); p.bezierCurveTo(38, 196, 84, 236, 110, 228); p.bezierCurveTo(120, 224, 136, 224, 146, 228); p.bezierCurveTo(172, 236, 218, 196, 222, 132); p.bezierCurveTo(226, 64, 164, 52, 128, 78); p.closePath(); p.moveTo(122, 76); p.bezierCurveTo(124, 54, 132, 38, 146, 26); p.lineTo(152, 32); p.bezierCurveTo(140, 44, 134, 58, 132, 76); p.closePath(); p.moveTo(140, 58); p.bezierCurveTo(156, 28, 190, 26, 204, 36); p.bezierCurveTo(186, 62, 160, 66, 140, 58); p.closePath(); break;
    case 'tomato': p.arc(128, 142, 92, 0, Math.PI * 2); p.moveTo(128, 46); for (let i = 0; i < 5; i++) { const a = -Math.PI / 2 + i * Math.PI * 2 / 5, b = a + Math.PI / 5; p.lineTo(128 + Math.cos(a) * 52, 62 + Math.sin(a) * 26 + 10); p.lineTo(128 + Math.cos(b) * 16, 62 + Math.sin(b) * 8); } p.closePath(); break;
    case 'cabbage': for (let i = 0; i <= 64; i++) { const a = i / 64 * Math.PI * 2, r = 96 + 7 * Math.sin(a * 7); i ? p.lineTo(128 + Math.cos(a) * r, 136 + Math.sin(a) * r * .92) : p.moveTo(128 + r, 136); } p.closePath(); break;
    case 'watermelon': p.moveTo(26, 96); p.arc(128, 96, 102, 0, Math.PI, false); p.lineTo(230, 96); p.closePath(); break;
    case 'bento': p.roundRect(30, 74, 196, 136, 22); p.roundRect(22, 58, 212, 30, 12); break;
    case 'dumpling': p.moveTo(30, 170); p.bezierCurveTo(40, 80, 216, 80, 226, 170); p.bezierCurveTo(180, 196, 76, 196, 30, 170); p.closePath(); for (let i = 0; i < 5; i++) { const x = 70 + i * 29; p.moveTo(x, 104 - Math.sin(i / 4 * Math.PI) * 14); p.arc(x, 104 - Math.sin(i / 4 * Math.PI) * 14, 12, 0, Math.PI * 2); } break;
    case 'bun': p.moveTo(32, 186); p.bezierCurveTo(30, 90, 90, 56, 128, 56); p.bezierCurveTo(166, 56, 226, 90, 224, 186); p.closePath(); p.arc(128, 60, 14, 0, Math.PI * 2); break;
    case 'bowl': p.moveTo(28, 104); p.lineTo(228, 104); p.bezierCurveTo(226, 172, 182, 204, 128, 204); p.bezierCurveTo(74, 204, 30, 172, 28, 104); p.closePath(); p.roundRect(98, 200, 60, 20, 6); break;
    case 'chopsticks': p.moveTo(70, 30); p.lineTo(84, 28); p.lineTo(120, 230); p.lineTo(110, 232); p.closePath(); p.moveTo(150, 28); p.lineTo(164, 30); p.lineTo(146, 232); p.lineTo(136, 230); p.closePath(); break;
    case 'plate': p.ellipse(128, 138, 108, 62, 0, 0, Math.PI * 2); break;
    case 'spoon': p.ellipse(128, 70, 44, 54, 0, 0, Math.PI * 2); p.moveTo(118, 116); p.lineTo(138, 116); p.lineTo(134, 232); p.lineTo(122, 232); p.closePath(); break;
    case 'window': p.rect(40, 34, 176, 188); p.rect(56, 50, 64, 74); p.rect(136, 50, 64, 74); p.rect(56, 136, 64, 70); p.rect(136, 136, 64, 70); break;
    case 'fridge': p.roundRect(62, 20, 132, 216, 18); p.rect(62, 92, 132, 6); p.rect(80, 50, 8, 30); p.rect(80, 112, 8, 40); break;
    case 'candy': p.ellipse(128, 128, 56, 40, 0, 0, Math.PI * 2); p.moveTo(74, 128); p.lineTo(26, 92); p.lineTo(34, 164); p.closePath(); p.moveTo(182, 128); p.lineTo(230, 92); p.lineTo(222, 164); p.closePath(); break;
    case 'hairdryer': p.arc(104, 96, 62, 0, Math.PI * 2); p.roundRect(160, 74, 72, 44, 10); p.moveTo(90, 150); p.lineTo(130, 150); p.lineTo(150, 234); p.lineTo(112, 234); p.closePath(); break;
  }
  return CUS[name] = p;
}
const DXI = { border: '#E6ECF3', sart: '#EEF2F7', sil: '#C5CFDC', top: '#FFFFFF', edge: '#E2ECF8', no: '#8C96A3', q: '#AEB8C4' };
function drawSil(c, s, x, y, size, alpha = 1) {
  const box = size * .72, cx = x + size / 2, cy = y + size / 2;
  c.save(); c.globalAlpha *= alpha;
  if (s.sil) { const im = A['ds_' + s.sil], k = Math.min(box / im.width, box / im.height); c.drawImage(im, cx - im.width * k / 2, cy - im.height * k / 2, im.width * k, im.height * k); }
  else { c.translate(cx - box / 2, cy - box / 2); c.scale(box / 256, box / 256); c.fillStyle = DXI.sil;
    if (s.ph) PHP[s.ph].forEach(p => c.fill(p, 'evenodd')); else c.fill(cusPath(s.cus), 'evenodd'); }
  c.restore();
}
function drawCut(c, key, x, y, size, { k = 1, rot = 0, sx = 1, sy = 1, alpha = 1 } = {}) {
  const im = A['d_' + key], box = size * .86, f = Math.min(box / im.width, box / im.height);
  c.save(); c.globalAlpha *= alpha; c.translate(x + size / 2, y + size / 2); c.rotate(rot); c.scale(k * sx, k * sy);
  c.shadowColor = 'rgba(0,30,70,0.25)'; c.shadowBlur = 6; c.shadowOffsetY = 8;
  c.drawImage(im, -im.width * f / 2, -im.height * f / 2, im.width * f, im.height * f); c.restore();
}
function slotBg(c, x, y, caught) {
  if (caught) { const g = c.createRadialGradient(x + SLOT / 2, y + SLOT * .38, 0, x + SLOT / 2, y + SLOT * .38, SLOT * .75); g.addColorStop(0, DXI.top); g.addColorStop(1, DXI.edge); c.fillStyle = g; }
  else c.fillStyle = DXI.sart;
  rr(x, y, SLOT, SLOT, 16 * PT, c); c.fill();
}
const noStr = no => no ? 'No.' + String(no).padStart(3, '0') : 'No.---';
function fitZy(c, u, cx, y, size, maxW, opts = {}) {
  const w = zyWidth(u, size), k = Math.min(1, maxW / w);
  c.save(); c.translate(cx, y); c.scale(k, k); zyDraw(u, 0, 0, size, Object.assign({ c, w: 800 }, opts)); c.restore();
}

// rolling number: digits that changed roll up from old to new
function rollText(c, oldS, newS, x, y, size, t, t0, { w = 700, f = FONT_UI, color = MUTED, hi = BLUE, align = 'left', dur = .42 } = {}) {
  const r = t0 < 0 ? 0 : E.outBack(seg(t, t0, t0 + dur), 1.4), done = seg(t, t0, t0 + dur);
  font(w, size, f, c); const wNew = c.measureText(newS).width, wOld = c.measureText(oldS).width, wd = lerp(wOld, wNew, clamp(r));
  let xx = align === 'right' ? x - wd : x;
  c.save(); c.textAlign = 'left'; c.textBaseline = 'alphabetic';
  const n = Math.max(oldS.length, newS.length), O = oldS.padStart(n, ' '), N = newS.padStart(n, ' ');
  for (let i = 0; i < n; i++) {
    const a = O[i], b = N[i], cw = c.measureText(b.trim() ? b : a).width;
    if (a === b) { c.fillStyle = done > .5 && t0 >= 0 ? hi : color; if (a.trim()) c.fillText(a, xx, y); }
    else {
      c.save(); c.beginPath(); c.rect(xx - 2, y - size * 1.05, cw + 4, size * 1.35); c.clip();
      c.fillStyle = color; c.fillText(a, xx, y - r * size * 1.1);
      c.fillStyle = hi; c.fillText(b, xx, y + (1 - r) * size * 1.1);
      c.restore();
    }
    xx += cw;
  }
  c.restore();
}

// ---------- the page ----------
const DL = document.createElement('canvas'); DL.width = W; DL.height = H; const dlx = DL.getContext('2d');
// fx: { I: impact time, anticip: start of anticipation, compact: bool (shorter finale for the peek sheet) }
function drawDexList(c, t, top, sy, fx) {
  const L = dexLayout(), I = fx ? fx.I : 99, after = t >= I;
  for (const cat of L.cats) {
    const y0 = top + cat.y - sy; if (y0 > H || y0 + cat.h < 0) continue;
    const c1 = cat.c.no === 1;
    // card
    c.save(); c.shadowColor = 'rgba(20,50,90,0.10)'; c.shadowBlur = 24; c.shadowOffsetY = 10; c.fillStyle = '#fff'; rr(DX, y0, DCW, cat.h, 22 * PT, c); c.fill(); c.restore();
    c.strokeStyle = DXI.border; c.lineWidth = 2.75; rr(DX, y0, DCW, cat.h, 22 * PT, c); c.stroke();
    // title + count + progress (the bar is the proposal: a fixed goal per category)
    const ty = y0 + DPAD + 2 * PT + 34;
    font(800, 38.5, FONT_JP, c); c.fillStyle = INK; c.textAlign = 'left';
    c.font = `38px ${FONT_EMOJI}`; c.fillText(cat.c.emoji, DX + DPAD + 4, ty); font(800, 38.5, FONT_JP, c); c.fillText(cat.c.label, DX + DPAD + 58, ty);
    const n0 = cat.c.caught, tC = c1 && fx ? I + (fx.compact ? .18 : .3) : -1;
    rollText(c, `${n0}`, `${c1 && fx ? n0 + 1 : n0}`, DX + DCW - DPAD - measureC(c, ` / ${cat.c.total}`, 600, 33), ty, 33, t, tC, { w: 600, f: FONT_UI, align: 'right' });
    text(` / ${cat.c.total}`, DX + DCW - DPAD, ty, { w: 600, size: 33, f: FONT_UI, color: MUTED, align: 'right', c });
    const by = ty + 22, bw = DCW - 2 * DPAD, pr = c1 && fx ? lerp(n0 / cat.c.total, (n0 + 1) / cat.c.total, E.outCubic(seg(t, tC, tC + .45))) : n0 / cat.c.total;
    c.fillStyle = '#EDF1F6'; rr(DX + DPAD, by, bw, 10, 5, c); c.fill();
    const bg = c.createLinearGradient(DX + DPAD, 0, DX + DPAD + bw * pr, 0); bg.addColorStop(0, '#5AB4FF'); bg.addColorStop(1, BLUE);
    c.fillStyle = bg; rr(DX + DPAD, by, Math.max(10, bw * pr), 10, 5, c); c.fill();
    if (c1 && fx) { const gl = seg(t, tC + .25, tC + .7); if (gl > 0 && gl < 1) { const gx = DX + DPAD + bw * pr * gl; const gg = c.createLinearGradient(gx - 60, 0, gx + 60, 0); gg.addColorStop(0, 'rgba(255,255,255,0)'); gg.addColorStop(.5, 'rgba(255,255,255,0.9)'); gg.addColorStop(1, 'rgba(255,255,255,0)'); c.save(); rr(DX + DPAD, by, bw * pr, 10, 5, c); c.clip(); c.fillStyle = gg; c.fillRect(gx - 60, by, 120, 10); c.restore(); } }
    // slots
    cat.slots.forEach(({ s, x, y }, i) => {
      const yy = top + y - sy; if (yy > H || yy + ROW_H < 0) return;
      let alpha = 1, k = 1;
      if (s.refill) { if (!fx) return; const r = seg(t, I + (fx.compact ? .4 : .7), I + (fx.compact ? .75 : 1.1)); if (r <= 0) return; alpha = r; k = lerp(.55, 1, E.outBack(r, 2)); }
      c.save(); if (k !== 1) { c.translate(x + SLOT / 2, yy + SLOT / 2); c.scale(k, k); c.translate(-(x + SLOT / 2), -(yy + SLOT / 2)); } c.globalAlpha *= alpha;
      if (s.k === 't') drawTargetSlot(c, s, x, yy, t, fx);
      else {
        slotBg(c, x, yy, s.k === 'c');
        if (s.k === 'c') drawCut(c, s.img, x, yy, SLOT); else drawSil(c, s, x, yy, SLOT);
        text(noStr(s.no), x + SLOT / 2, yy + SLOT + 8 + 24, { w: 700, size: 26, f: FONT_UI, color: DXI.no, ls: 1, c });
        if (s.k === 'c') fitZy(c, s.u, x + SLOT / 2, yy + SLOT + 8 + 28 + 8 + 38, 36, SLOT, { color: INK, zcolor: MUTED });
        else text(s.h, x + SLOT / 2, yy + SLOT + 8 + 28 + 8 + 38, { w: 700, size: 36, f: FONT_TC, color: DXI.q, c });
        // the next goal: the last base word of the category breathes once the toast points at it
        if (s.goal && fx) { const gp = seg(t, I + (fx.compact ? .55 : 1.0), I + (fx.compact ? .75 : 1.2)); if (gp > 0) { const ph = (t - I) * 4.2; c.save(); c.globalAlpha *= gp * (.55 + .45 * Math.sin(ph)); c.setLineDash([14, 10]); c.lineDashOffset = -t * 40; c.strokeStyle = BLUE; c.lineWidth = 5; rr(x - 6, yy - 6, SLOT + 12, SLOT + 12, 16 * PT + 6, c); c.stroke(); c.restore(); } }
      }
      c.restore();
    });
  }
}
function measureC(c, s, w, size) { c.save(); font(w, size, FONT_UI, c); const m = c.measureText(s).width; c.restore(); return m; }

// the target slot through the finale: held shadow → anticipation → (the caller flies the sticker in) → filled
let SILC = null;
function silCanvas() { if (!SILC) { SILC = document.createElement('canvas'); SILC.width = Math.ceil(SLOT); SILC.height = Math.ceil(SLOT); } return SILC; }
function drawTargetSlot(c, s, x, y, t, fx) {
  const I = fx ? fx.I : 99, after = t >= I, an = fx ? seg(t, fx.anticip, I) : 0;
  slotBg(c, x, y, after);
  if (!after) {
    // held shadow; anticipation: it breathes, a light runs over it, the dashed ring tightens
    const br = 1 + .04 * Math.sin(an * Math.PI * 3) * an;
    c.save(); c.translate(x + SLOT / 2, y + SLOT / 2); c.scale(br, br); c.translate(-(x + SLOT / 2), -(y + SLOT / 2));
    // the shadow, tinted toward blue as the moment comes, with a light running over it (only over the shadow)
    const sc = silCanvas(); const sx = sc.getContext('2d'); sx.setTransform(1, 0, 0, 1, 0, 0); sx.clearRect(0, 0, SLOT, SLOT);
    drawSil(sx, s, 0, 0, SLOT); sx.globalCompositeOperation = 'source-atop';
    sx.fillStyle = `rgba(42,155,255,${.55 * an})`; sx.fillRect(0, 0, SLOT, SLOT);
    if (an > 0) { const p = -SLOT * .6 + an * SLOT * 2.2; const g = sx.createLinearGradient(p, 0, p + 110, SLOT); g.addColorStop(0, 'rgba(255,255,255,0)'); g.addColorStop(.5, 'rgba(255,255,255,0.95)'); g.addColorStop(1, 'rgba(255,255,255,0)'); sx.fillStyle = g; sx.fillRect(0, 0, SLOT, SLOT); }
    sx.globalCompositeOperation = 'source-over';
    c.drawImage(sc, x, y);
    c.restore();
    if (an > 0) { c.save(); c.globalAlpha *= an; c.setLineDash([16, 12]); c.lineDashOffset = -t * 160; c.strokeStyle = BLUE2; c.lineWidth = 5 + 3 * an; const gr = 12 * (1 - an); rr(x - gr, y - gr, SLOT + 2 * gr, SLOT + 2 * gr, 16 * PT + gr, c); c.stroke(); c.restore(); }
    text(noStr(s.no), x + SLOT / 2, y + SLOT + 8 + 24, { w: 700, size: 26, f: FONT_UI, color: DXI.no, ls: 1, c });
    text('？', x + SLOT / 2, y + SLOT + 8 + 28 + 8 + 38, { w: 700, size: 36, f: FONT_TC, color: DXI.q, c });
    return;
  }
  const u = t - I;
  // ring (the app's .slot.fill: 2.5 pt #2A9BFF + glow), held a while, then it relaxes
  const ring = seg(u, 0, .08) * (1 - seg(u, 1.5, 1.9));
  if (ring > 0) { c.save(); c.globalAlpha *= ring; c.shadowColor = 'rgba(42,155,255,0.6)'; c.shadowBlur = 60; c.strokeStyle = BLUE2; c.lineWidth = 7; rr(x - 3.5, y - 3.5, SLOT + 7, SLOT + 7, 16 * PT + 3.5, c); c.stroke(); c.restore(); }
  // the cup settles from its arrival pose (bigger, tilted) with the squash of the contact
  const st = spring(u, .42, .52), k = lerp(fx.k0 || 1.3, 1, st), rot = lerp(fx.r0 || -.12, 0, st);
  const sq = Math.sin(clamp(u / .22) * Math.PI) * Math.exp(-u * 6), sx = 1 + .14 * sq, sy = 1 - .12 * sq;
  drawCut(c, 'cup', x, y, SLOT, { k, rot, sx, sy });
  // white flash on contact
  const fl = 1 - seg(u, 0, .16); if (fl > 0) { c.save(); c.globalAlpha *= fl * .75; c.fillStyle = '#fff'; rr(x, y, SLOT, SLOT, 16 * PT, c); c.fill(); c.restore(); }
  // NEW badge
  const nb = seg(u, fx.compact ? .06 : .1, (fx.compact ? .06 : .1) + .32);
  if (nb > 0) { const s2 = E.outBack(nb, 2.4); c.save(); c.translate(x + SLOT - 18, y + 16); c.rotate(-.14); c.scale(s2, s2); c.shadowColor = 'rgba(255,59,48,0.45)'; c.shadowBlur = 16; c.fillStyle = '#FF3B30'; rr(-58, -24, 116, 48, 24, c); c.fill(); c.shadowColor = 'transparent'; text('NEW', 0, 11, { w: 800, size: 28, f: FONT_UI, color: '#fff', ls: 2, c }); c.restore(); }
  // number + name write in
  const tl = fx.compact ? .1 : .16;
  text(noStr(s.no), x + SLOT / 2, y + SLOT + 8 + 24, { w: 700, size: 26, f: FONT_UI, color: u > tl ? BLUE : DXI.no, ls: 1, c });
  fitZy(c, s.u, x + SLOT / 2, y + SLOT + 8 + 28 + 8 + 38, 36, SLOT, { t, t0: I + tl, stagger: .07, dur: .26, color: INK, zcolor: MUTED });
}

// header (title, counts, the mode segment) over a material backdrop
function dexHeader(c, t, top, fx) {
  const I = fx ? fx.I : 99;
  const g = c.createLinearGradient(0, top, 0, top + DEX_HEAD + 40); g.addColorStop(0, 'rgba(249,252,255,0.97)'); g.addColorStop(.86, 'rgba(249,252,255,0.94)'); g.addColorStop(1, 'rgba(249,252,255,0)');
  c.fillStyle = g; c.fillRect(0, top, W, DEX_HEAD + 40);
  const y1 = top + 236, y2 = top + 292, x0 = 16 * PT + 2 * PT;
  text('図鑑', x0, y1, { w: 900, size: 66, align: 'left', c });
  // 「129枚・影 37 / 100」 → 「130枚・影 38 / 100」 (the app's own header line), both numbers roll
  const tA = fx ? I + (fx.compact ? .26 : .42) : -1, tB = fx ? I + (fx.compact ? .32 : .5) : -1;
  font(600, 33, FONT_JP, c); let x = x0;
  rollText(c, '129', fx ? '130' : '129', x, y2, 33, t, tA, { w: 600, f: FONT_UI }); x += measureC(c, '130', 600, 33);
  text('枚・影 ', x, y2, { w: 600, size: 33, color: MUTED, align: 'left', c }); c.save(); font(600, 33, FONT_JP, c); x += c.measureText('枚・影 ').width; c.restore();
  rollText(c, '37', fx ? '38' : '37', x, y2, 33, t, tB, { w: 600, f: FONT_UI }); x += measureC(c, '38', 600, 33);
  text(' / 100', x, y2, { w: 600, size: 33, f: FONT_UI, color: MUTED, align: 'left', c });
  // mode segment (#dxSeg): four round buttons in a capsule, grid chosen
  const sw = 4 * 36 * PT + 3 * 6 * PT + 8 * PT, sx = W - 16 * PT - sw, sy2 = top + 196;
  c.fillStyle = '#F1F3F8'; rr(sx, sy2, sw, 44 * PT, 22 * PT, c); c.fill();
  for (let i = 0; i < 4; i++) {
    const bx = sx + 4 * PT + i * (42 * PT) + 18 * PT, by = sy2 + 22 * PT;
    if (i === 2) { c.save(); c.shadowColor = 'rgba(0,0,0,0.12)'; c.shadowBlur = 4; c.shadowOffsetY = 3; c.fillStyle = '#fff'; c.beginPath(); c.arc(bx, by, 18 * PT, 0, Math.PI * 2); c.fill(); c.restore(); }
    c.save(); c.strokeStyle = i === 2 ? INK : MUTED; c.lineWidth = 5.5; c.lineCap = 'round'; c.lineJoin = 'round'; c.translate(bx - 25, by - 25); c.scale(50 / 24, 50 / 24); c.lineWidth = 2;
    const P = d => c.stroke(new Path2D(d));
    if (i === 0) { P('M8 4h8a2 2 0 0 1 2 2v12a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2z'); P('M2 7v10M22 7v10'); }
    if (i === 1) { P('M9 4L3 6v14l6-2 6 2 6-2V4l-6 2z'); P('M9 4v14M15 6v14'); }
    if (i === 2) { ['M4 3h5a1 1 0 0 1 1 1v5a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1z', 'M15 3h5a1 1 0 0 1 1 1v5a1 1 0 0 1-1 1h-5a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1z', 'M4 14h5a1 1 0 0 1 1 1v5a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1v-5a1 1 0 0 1 1-1z', 'M15 14h5a1 1 0 0 1 1 1v5a1 1 0 0 1-1 1h-5a1 1 0 0 1-1-1v-5a1 1 0 0 1 1-1z'].forEach(P); }
    if (i === 3) P('M8 6h13M8 12h13M8 18h13M3 6h.01M3 12h.01M3 18h.01');
    c.restore();
  }
}

// the whole page: background, list (with motion blur while it scrolls fast), header. Returns the target slot centre.
function drawDexPage(t, { top = 0, sy = 0, vy = 0, alpha = 1, fx = null, sheet = false } = {}) {
  if (alpha <= 0) return null;
  dlx.setTransform(1, 0, 0, 1, 0, 0); dlx.clearRect(0, 0, W, H);
  drawDexList(dlx, t, top, sy, fx);
  ctx.save(); ctx.globalAlpha *= alpha;
  if (sheet) { ctx.save(); ctx.shadowColor = 'rgba(0,0,0,0.28)'; ctx.shadowBlur = 70; ctx.fillStyle = BG_APP; rr(0, top, W, H - top + 80, 56); ctx.fill(); ctx.restore(); ctx.save(); rr(0, top, W, H - top + 80, 56); ctx.clip(); }
  else { ctx.fillStyle = BG_APP; ctx.fillRect(0, top, W, H - top); ctx.save(); ctx.beginPath(); ctx.rect(0, top, W, H - top); ctx.clip(); }
  // shake (micro screen shake on impact) applies to the list
  let shx = 0, shy = 0; if (fx && t > fx.I) { const u = t - fx.I, a = (fx.compact ? 5 : 8) * Math.exp(-u / .055); shx = a * Math.sin(u * 2 * Math.PI * 27); shy = a * .6 * Math.cos(u * 2 * Math.PI * 23); }
  const blurPx = Math.min(36, Math.abs(vy) * .5);
  if (blurPx > 1.5) { const n = 7; for (let i = 0; i < n; i++) { ctx.globalAlpha = alpha / n * 1.0; ctx.drawImage(DL, shx, shy + (i / (n - 1) - .5) * blurPx); } ctx.globalAlpha = alpha; }
  else ctx.drawImage(DL, shx, shy);
  dexFx(t, top, sy, fx, shx, shy);
  dexHeader(ctx, t, top, fx);
  ctx.restore();
  if (sheet) { ctx.fillStyle = 'rgba(60,66,80,0.22)'; rr(W / 2 - 60, top + 20, 120, 14, 7); ctx.fill(); }
  ctx.restore();
  const ts = targetSlot(); return [ts.cx + shx, top + ts.cy - sy + shy];
}
// effects that spill out of the slot: rays, shockwave, sparkles
function dexFx(t, top, sy, fx, shx, shy) {
  if (!fx || t < fx.I - .01) return;
  const ts = targetSlot(), cx = ts.cx + shx, cy = top + ts.cy - sy + shy, u = t - fx.I;
  // light rays behind (an "item get" glow), turning slowly
  const ra = E.outCubic(seg(u, 0, .12)) * (1 - seg(u, .45, 1.0)) * (fx.compact ? .7 : 1);
  if (ra > 0) { ctx.save(); ctx.globalCompositeOperation = 'lighter'; ctx.globalAlpha = .38 * ra; ctx.translate(cx, cy); ctx.rotate(u * .6);
    for (let i = 0; i < 12; i++) { ctx.rotate(Math.PI * 2 / 12); const g = ctx.createLinearGradient(0, 0, 0, -330); g.addColorStop(0, 'rgba(120,190,255,0.9)'); g.addColorStop(1, 'rgba(120,190,255,0)'); ctx.fillStyle = g; ctx.beginPath(); ctx.moveTo(-10, 0); ctx.lineTo(-34, -330); ctx.lineTo(34, -330); ctx.lineTo(10, 0); ctx.fill(); }
    ctx.restore(); }
  // shockwaves
  for (const [d, a0, w0, R] of [[0, .75, 12, 300], [.07, .45, 6, 380]]) {
    const p = seg(u, d, d + .5); if (p <= 0 || p >= 1) continue;
    ctx.save(); ctx.globalAlpha = a0 * (1 - p); ctx.strokeStyle = '#fff'; ctx.shadowColor = BLUE2; ctx.shadowBlur = 24; ctx.lineWidth = w0 * (1 - p) + 1;
    ctx.beginPath(); ctx.arc(cx, cy, 70 + (R - 70) * E.outCubic(p), 0, Math.PI * 2); ctx.stroke(); ctx.restore();
  }
  drawLottie('burst', t, fx.I, cx, cy, fx.compact ? 520 : 640);
  drawLottie('twinkle', t, fx.I + .1, cx, cy - 40, 420);
}

// goal-gradient toast: the next goal is one word away (the empty dot breathes in time with the 水 slot's ring)
function goalToast(t, tIn, tOut, { y = TAB_Y - 196 } = {}) {
  const a = E.outCubic(seg(t, tIn, tIn + .35)) * (1 - seg(t, tOut, tOut + .25)); if (a <= 0) return;
  const w = 940, h = 150, x = W / 2 - w / 2, yy = y + (1 - a) * 40;
  glass(x, yy, w, h, 75, { alpha: a, tint: 'rgba(255,255,255,0.86)' });
  ctx.save(); ctx.globalAlpha *= a;
  ctx.font = `56px ${FONT_EMOJI}`; ctx.textAlign = 'center'; ctx.fillText('🧋', x + 84, yy + 96);
  text('飲み物の基本5語', x + 150, yy + 64, { w: 800, size: 36, align: 'left' });
  text('あと1語でコンプリート', x + 150, yy + 112, { w: 600, size: 32, color: BLUE, align: 'left' });
  for (let i = 0; i < 5; i++) {
    const dx = x + w - 300 + i * 54, dy = yy + h / 2;
    const filled = i < 3 || (i === 3 && t > tIn + .25);
    const pop = i === 3 ? E.outBack(seg(t, tIn + .25, tIn + .5), 3) : 1;
    ctx.save(); ctx.translate(dx, dy);
    if (filled) { ctx.scale(pop, pop); ctx.fillStyle = BLUE; ctx.beginPath(); ctx.arc(0, 0, 18, 0, Math.PI * 2); ctx.fill(); icon('check', 0, 1, 22, '#fff', 9); }
    else { const ph = .55 + .45 * Math.sin((t - tIn) * 4.2); ctx.globalAlpha *= ph; ctx.setLineDash([6, 5]); ctx.strokeStyle = BLUE; ctx.lineWidth = 4; ctx.beginPath(); ctx.arc(0, 0, 16, 0, Math.PI * 2); ctx.stroke(); }
    ctx.restore();
  }
  ctx.restore();
}
