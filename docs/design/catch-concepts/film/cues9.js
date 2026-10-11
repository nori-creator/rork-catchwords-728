// node cues9.js '[["O9","3.3","5.65"],["O9s","8.0",""]]' -> ../audio/cues9.json: every cue of the v9 scan (O9) for each
// [name, AI wait (s from the shutter to the names), tapmin] — for the sound mix and the haptics
const { chromium } = require('playwright'); const fs = require('fs');
(async () => {
  const cfg = JSON.parse(process.argv[2]);
  const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome' });
  const out = {};
  for (const [name, ai, tapmin] of cfg) {
    const p = await b.newPage({ viewport: { width: 1080, height: 2340 } });
    await p.goto('http://127.0.0.1:8765/film9.html?c=O9&t=0&ai=' + ai + (tapmin ? '&tapmin=' + tapmin : '')); await p.evaluate(() => window.ready);
    out[name] = await p.evaluate(() => {
      window.renderFrame(window.DUR.O9 - .3, 'O9');
      const o = JSON.parse(JSON.stringify(window.CUES.O9));
      o.shared = { T_PRESS, T_CAP, T_NAMES, T_TAP, T_VIS, LOOP, tags: TAGS.map(tg => ({ id: tg.id, x: tg.p[0], y: tg.p[1] })), dur: window.DUR };
      return o;
    });
    out[name].ai = +ai; out[name].tapmin = tapmin ? +tapmin : null;
    await p.close();
  }
  fs.writeFileSync('../audio/cues9.json', JSON.stringify(out, null, 1));
  console.log(Object.keys(out).map(k => `${k}:${out[k].end}`).join(' '));
  await b.close();
})();
