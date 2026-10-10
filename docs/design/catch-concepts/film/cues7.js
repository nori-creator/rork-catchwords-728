// node cues7.js -> audio/cues7.json: every cue of the v7 scan proposals (W2–W5) at the median AI wait (6.0 s) and at
// the 90th percentile (?ai=11.5) — for the sound mix and the haptics
const { chromium } = require('playwright'); const fs = require('fs');
(async () => {
  const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome' });
  const out = {};
  for (const [ai, suffix] of [[null, ''], ['11.5', 's']]) {
    const p = await b.newPage({ viewport: { width: 1080, height: 2340 } });
    await p.goto('http://127.0.0.1:8765/film7.html?c=W2&t=0' + (ai ? '&ai=' + ai : '')); await p.evaluate(() => window.ready);
    const r = await p.evaluate(() => {
      const list = Object.keys(window.DUR); for (const c of list) window.renderFrame(window.DUR[c] - .3, c);
      const o = {}; for (const c of list) o[c] = JSON.parse(JSON.stringify(window.CUES[c]));
      o._shared = { T_PRESS, T_CAP, T_NAMES, T_TAP, T_VIS, LOOP, tags: TAGS.map(tg => ({ id: tg.id, x: tg.p[0], y: tg.p[1] })), dur: window.DUR };
      return o;
    });
    for (const c of Object.keys(r)) if (c !== '_shared') { out[c + suffix] = r[c]; out[c + suffix].shared = r._shared; }
    await p.close();
  }
  fs.writeFileSync('../audio/cues7.json', JSON.stringify(out, null, 1));
  console.log(Object.keys(out).map(k => `${k}:${out[k].end}`).join(' '));
  await b.close();
})();
