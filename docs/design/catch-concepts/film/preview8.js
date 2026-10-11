// node preview.js A 0.3,1.0,... out.png  -> contact sheet of frames
const { chromium } = require('playwright'); const fs = require('fs');
(async () => {
  const [c, ts, out] = process.argv.slice(2);
  const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome', args: ['--allow-file-access-from-files'] });
  const p = await b.newPage({ viewport: { width: 1080, height: 2340 } });
  const errs = []; p.on('pageerror', e => errs.push(e.message)); p.on('console', m => { if (m.type() === 'error') errs.push(m.text()); });
  await p.goto('http://127.0.0.1:8765/film8.html?c=' + c + '&t=0' + (process.env.AI ? '&ai=' + process.env.AI : ''));
  await p.evaluate(() => window.ready);
  const times = ts.split(',').map(Number); const shots = [];
  for (const t of times) {
    const t0 = Date.now();
    const data = await p.evaluate(([t, c]) => { window.renderFrame(t, c); return document.getElementById('c').toDataURL('image/jpeg', .85); }, [t, c]);
    shots.push(data); process.stderr.write(`t=${t} ${Date.now() - t0}ms\n`);
  }
  // compose sheet in page
  const sheet = await p.evaluate(async ([shots, times]) => {
    const cols = Math.min(6, shots.length), rows = Math.ceil(shots.length / cols), w = 300, h = 650;
    const cv = document.createElement('canvas'); cv.width = cols * (w + 8); cv.height = rows * (h + 40); const x = cv.getContext('2d'); x.fillStyle = '#fff'; x.fillRect(0, 0, cv.width, cv.height);
    for (let i = 0; i < shots.length; i++) { const im = new Image(); im.src = shots[i]; await im.decode(); const cx = (i % cols) * (w + 8), cy = Math.floor(i / cols) * (h + 40); x.drawImage(im, cx, cy + 34, w, h); x.fillStyle = '#000'; x.font = '24px sans-serif'; x.fillText('t=' + times[i], cx + 6, cy + 26); }
    return cv.toDataURL('image/jpeg', .88);
  }, [shots, times]);
  fs.writeFileSync(out, Buffer.from(sheet.split(',')[1], 'base64'));
  console.log('errors', errs); await b.close();
})();
