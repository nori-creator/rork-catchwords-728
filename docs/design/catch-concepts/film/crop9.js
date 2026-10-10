// node crop4.js A t x y w h out.png [scale] — render one frame and crop a region (for close look-dev)
const { chromium } = require('playwright'); const fs = require('fs');
(async () => {
  const [c, t, x, y, w, h, out, sc] = process.argv.slice(2);
  const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome' });
  const p = await b.newPage({ viewport: { width: 1080, height: 2340 } });
  const errs = []; p.on('pageerror', e => errs.push(e.message));
  await p.goto('http://127.0.0.1:8765/film9.html?c=' + c + '&t=0' + (process.env.AI ? '&ai=' + process.env.AI : '') + (process.env.TAPMIN ? '&tapmin=' + process.env.TAPMIN : '')); await p.evaluate(() => window.ready);
  const data = await p.evaluate(([t, c, x, y, w, h, sc]) => {
    window.renderFrame(t, c); const src = document.getElementById('c');
    const o = document.createElement('canvas'); o.width = w * sc; o.height = h * sc; const g = o.getContext('2d'); g.imageSmoothingEnabled = sc < 1;
    g.drawImage(src, x, y, w, h, 0, 0, w * sc, h * sc); return o.toDataURL('image/png');
  }, [+t, c, +x, +y, +w, +h, +(sc || 1)]);
  fs.writeFileSync(out, Buffer.from(data.split(',')[1], 'base64')); console.log('errors', errs); await b.close();
})();
