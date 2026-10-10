const { chromium } = require('playwright'); const fs = require('fs');
(async () => { const b = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium-1194/chrome-linux/chrome' });
 const p = await b.newPage({ viewport: { width: 1080, height: 2340 } }); await p.goto('http://127.0.0.1:8765/cards/card.html');
 const cards = JSON.parse(fs.readFileSync('cards/cards3.json'));
 for (const k of Object.keys(cards)) { const d = await p.evaluate(([k, v]) => window.draw(k, v), [k, cards[k]]); fs.writeFileSync(`cards/v3_${k}.png`, Buffer.from(d.split(',')[1], 'base64')); }
 await b.close(); console.log('cards ok'); })();
