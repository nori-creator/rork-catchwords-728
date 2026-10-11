// node cues.js (from film/) -> ../audio/cues5.json: every cue of the v5 films (for the sound mix and haptics), plus geometry the mix pans by
const { chromium } = require('playwright'); const fs = require('fs');
(async () => {
  const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome' });
  const p = await b.newPage({ viewport: { width: 1080, height: 2340 } });
  await p.goto('http://127.0.0.1:8765/film.html?c=P1&t=0'); await p.evaluate(() => window.ready);
  const cues = await p.evaluate(() => {
    for (const c of Object.keys(window.DUR)) window.renderFrame((window.START[c] || 0) + window.DUR[c] - .3, c);
    const out = JSON.parse(JSON.stringify(window.CUES));
    out.shared = { T_PRESS, T_CAP, T_NAMES, T_TAP, T_VIS: typeof T_VIS !== 'undefined' ? T_VIS : null,
      tags: TAGS.map(tg => ({ id: tg.id, x: tg.p[0], y: tg.p[1] })), start: window.START, dur: window.DUR,
      depthOf: Object.fromEntries(['cup', 'scooter', 'sign'].map(id => { const M = MK[id]; let s = 0, n = 0; for (let y = M.y; y < M.y + M.h; y += 6) for (let x = M.x; x < M.x + M.w; x += 6) if (maskAt(id, x, y) > .5) { s += DEPTH[Math.round(y) * W + Math.round(x)]; n++; } return [id, s / n]; })) };
    return out;
  });
  fs.writeFileSync('../audio/cues5.json', JSON.stringify(cues, null, 1));
  console.log(Object.keys(cues).join(' '), JSON.stringify(cues.shared.dur)); await b.close();
})();
