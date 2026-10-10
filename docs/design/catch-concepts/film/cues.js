// node cues3.js > audio/cues3.json — exact event times from the film for the mix and haptics
const { chromium } = require('playwright');
(async () => {
  const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome' });
  const p = await b.newPage({ viewport: { width: 1080, height: 2340 } });
  await p.goto('http://127.0.0.1:8765/film.html?c=A&t=0'); await p.evaluate(() => window.ready);
  const out = await p.evaluate(() => {
    const res = { shared: { T_PRESS, T_CAP, T_NAMES, T_TAP, C0 } };
    res.shared.outlines = TAGS.map(g => { const pts = shapeOf(g.id); return { id: g.id, t: OUTLINE_T(g.id), dur: .5 + pts.length / 2600, x: g.p[0], draft: OUTLINE_T(g.id) + (.5 + pts.length / 2600) * .85 }; });
    res.shared.names = TAGS.map(g => ({ id: g.id, t: NAME_T(g), x: g.p[0] }));
    const from = { A: 4, B: 3, C: 2, D: 3 };
    for (const c of ['A', 'B', 'C', 'D', 'E']) {
      CONCEPTS[c](0); const cu = Object.assign({}, CUES[c]); delete cu.pickXY; res[c] = cu;
      if (from[c]) { // card tops passing the header while the list scrolls
        const a = scrollToCat(from[c]), ticks = []; let prev = a;
        for (let t = cu.scroll0; t <= cu.scroll1 + .3; t += 1 / 240) {
          const sy = scrollAt(t, cu.scroll0, cu.scroll1, a, 0);
          for (let k = 1; k < from[c]; k++) { const th = scrollToCat(k); if (prev > th && sy <= th) ticks.push({ t: +t.toFixed(3), cat: k }); }
          prev = sy;
        }
        cu.ticks = ticks;
      }
    }
    res.E.lines = Array.from({ length: N_LINES }, (_, i) => ({ draft: +draftStart(i).toFixed(3), refine: +refineStart(i).toFixed(3), ink: +(T_DONE + i * .055).toFixed(3) }));
    res.DUR = window.DUR;
    return res;
  });
  console.log(JSON.stringify(out, null, 1)); await b.close();
})();
