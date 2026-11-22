// Vyrenderuje náhledy meshů: node render_mesh.js <out> "<jméno>|<w>|<h>|<query>" ...
const http = require('http');
const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');

const ROOT = __dirname;
const OUT = process.argv[2];
const jobs = process.argv.slice(3).map((s) => s.split('|'));
const TYPES = { '.html': 'text/html', '.js': 'text/javascript', '.woff2': 'font/woff2', '.png': 'image/png', '.json': 'application/json', '.glb': 'model/gltf-binary' };
const server = http.createServer((req, res) => {
  const url = decodeURIComponent(req.url.split('?')[0]);
  let file = path.join(ROOT, url === '/' ? 'page.html' : url);
  if (url.startsWith('/out/')) file = path.join(OUT, url.slice(5));
  fs.readFile(file, (err, data) => {
    if (err) { res.writeHead(404); return res.end('not found'); }
    res.writeHead(200, { 'Content-Type': TYPES[path.extname(file)] || 'application/octet-stream' });
    res.end(data);
  });
});
(async () => {
  await new Promise((r) => server.listen(8766, r));
  const browser = await chromium.launch({ args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
  for (const [name, w, h, query] of jobs) {
    const page = await browser.newPage({ viewport: { width: +w, height: +h }, deviceScaleFactor: 1 });
    page.on('pageerror', (e) => console.log(`  [${name}] pageerror: ${e.message}`));
    await page.goto(`http://localhost:8766/page.html?g=mesh&w=${w}&h=${h}&${query}`);
    await page.waitForFunction(() => window.__ready || window.__error, null, { timeout: 240000 });
    const err = await page.evaluate(() => window.__error);
    if (err) console.log(`✘ ${name}: ${err}`);
    else { await page.screenshot({ path: path.join(OUT, `${name}.png`) }); console.log(`✔ ${name}`); }
    await page.close();
  }
  await browser.close();
  server.close();
})();
