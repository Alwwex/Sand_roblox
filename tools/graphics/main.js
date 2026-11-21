import { SCENES } from './scenes.js';
import { createOverlay } from './overlay.js';

const params = new URLSearchParams(location.search);
const name = params.get('g');
const W = Number(params.get('w'));
const H = Number(params.get('h'));

window.__error = null;
window.addEventListener('error', (e) => { window.__error = String(e.message); });

(async () => {
  try {
    await document.fonts.load("100px 'Luckiest Guy'");
    await document.fonts.load("700 40px 'Fredoka'");
    await document.fonts.load("500 40px 'Fredoka'");
    const build = SCENES[name];
    if (!build) throw new Error('unknown scene ' + name);
    const ov = createOverlay(W, H);
    const ctx = await build({ W, H, ov });
    if (ctx && ctx.composer) {
      for (let i = 0; i < 3; i++) ctx.composer.render();
    }
    if (ctx && ctx.after) await ctx.after();
    await document.fonts.ready;
    window.__ready = true;
  } catch (e) {
    window.__error = String(e && e.stack || e);
  }
})();
