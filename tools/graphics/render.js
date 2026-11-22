// Spustí lokální server a vyrenderuje grafiky do PNG
const http = require('http');
const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');

const ROOT = __dirname;
const OUT = process.argv[2];
const only = process.argv.slice(3);
const JOBS = [
  ['icon', 1024, 1024],
  ['teaser', 1080, 1350],
  ['tools', 1080, 1350],
  ['code', 1080, 1350],
  ['relic', 1080, 1350],
  ['storm', 1080, 1350],
  ['choose', 1080, 1350],
  ['story', 1080, 1920],
  ['thumbnail', 1920, 1080],
  ['mockup', 2400, 1600],
  ['lobby_aerial', 1920, 1080],
  ['lobby_ground', 1920, 1080],
  ['ui_menu', 1920, 1080],
  ['ui_hud', 1920, 1080],
  ['ui_shop', 1920, 1080],
  ['ui_store', 1920, 1080],
  ['ui_top', 1920, 1080],
  ['ui_index', 1920, 1080],
  ['ui_rebirth', 1920, 1080],
  ['ui_settings', 1920, 1080],
  ['ui_hud2', 1920, 1080],
  ['ui_egg', 1920, 1080],
  ['ui_pets', 1920, 1080],
  ['ui_quests', 1920, 1080],
  ['ui_hatch', 1920, 1080],
  ['lobby_hatchery', 1920, 1080],
  ['lobby_buyer', 1920, 1080],
  ['models_pets', 1920, 1080],
  ['models_tools', 1920, 1080],
  ['models_pets_close', 1920, 1080],
];
const TYPES = { '.html': 'text/html', '.js': 'text/javascript', '.woff2': 'font/woff2', '.png': 'image/png', '.json': 'application/json' };

const server = http.createServer((req, res) => {
  const url = decodeURIComponent(req.url.split('?')[0]);
  let file = path.join(ROOT, url === '/' ? 'page.html' : url);
  if (url.startsWith('/out/')) file = path.join(OUT, url.slice(5));
  if (!file.startsWith(ROOT) && !file.startsWith(OUT)) { res.writeHead(403); return res.end(); }
  fs.readFile(file, (err, data) => {
    if (err) { res.writeHead(404); return res.end('not found'); }
    res.writeHead(200, { 'Content-Type': TYPES[path.extname(file)] || 'application/octet-stream' });
    res.end(data);
  });
});

(async () => {
  await new Promise((r) => server.listen(8765, r));
  fs.mkdirSync(OUT, { recursive: true });
  const browser = await chromium.launch({ args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
  for (const [name, w, h] of JOBS) {
    if (only.length && !only.includes(name)) continue;
    const page = await browser.newPage({ viewport: { width: w, height: h }, deviceScaleFactor: 1 });
    page.on('console', (m) => { if (m.type() === 'error' || m.type() === 'warning') console.log(`  [${name}] ${m.type()}: ${m.text()}`); });
    page.on('pageerror', (e) => console.log(`  [${name}] pageerror: ${e.message}`));
    const t0 = Date.now();
    await page.goto(`http://localhost:8765/page.html?g=${name}&w=${w}&h=${h}`);
    await page.waitForFunction(() => window.__ready || window.__error, null, { timeout: 240000 });
    const err = await page.evaluate(() => window.__error);
    if (err) { console.log(`✘ ${name}: ${err}`); await page.close(); continue; }
    await page.screenshot({ path: path.join(OUT, `${name}.png`), clip: { x: 0, y: 0, width: w, height: h } });
    console.log(`✔ ${name} (${((Date.now() - t0) / 1000).toFixed(1)} s)`);
    await page.close();
  }
  await browser.close();
  server.close();
})();
