// Jednotlivé grafiky
import * as L from './lib.js';
import * as O from './overlay.js';

const { THREE, COL } = L;
const V = (x, y, z) => new THREE.Vector3(x, y, z);
const rad = THREE.MathUtils.degToRad;

function onGround(obj, terrain, x, z, dy = 0) {
  obj.position.set(x, terrain.userData.heightAt(x, z) + dy, z);
  return obj;
}

function daySky(scene, opts = {}) {
  scene.add(L.sky({ top: 0x1f7cff, mid: 0x8fd3ff, bottom: 0xffe6b8, ...opts }));
}

export const SCENES = {};

// ============================================================ 1) IKONA HRY
SCENES.icon = async ({ W, H, ov }) => {
  const r = L.setup(W, H, { fov: 38 });
  const { scene, camera } = r;
  daySky(scene, { top: 0x1565f0, mid: 0x6cc4ff, bottom: 0xffe2a8, sunDir: V(-0.5, 0.35, 1) });
  const t = L.dunes({ amp: 5, scale: 55, seed: 4, craters: [{ x: 0, z: 0, r: 26, depth: 6, rim: 1.5 }] });
  scene.add(t);
  L.lights(scene, { sun: V(-30, 45, -40), target: V(0, -5, 0), shadowSize: 25 });

  const d = L.digger({ pose: 'cheer', tool: L.shovel({ golden: true }), toolRot: [0, 0, -28] });
  onGround(d, t, -1.5, 0.5);
  d.rotation.y = rad(-15);
  scene.add(d);
  const gy = d.position.y;

  const ch = L.chest({ color: COL.legendary, open: true, scale: 0.9 });
  onGround(ch, t, 4.2, -1.2);
  ch.rotation.y = rad(-32);
  scene.add(ch);
  scene.add(L.coinRain(12, V(3.8, gy + 6.5, -1.5), V(6, 5, 2), [0.3, 0.5], 9));
  scene.add(L.sparkles(22, V(0.5, gy + 7, -2), V(14, 9, 3), 0xfff0a0, [0.35, 1.0]));
  scene.add(L.grains(140, V(-1, gy + 1.5, -1.5), V(8, 3, 3), 0xf6d08a, 0.2));
  scene.add(L.cloud(-70, 55, 240, 2.4), L.cloud(80, 70, 280, 2));

  camera.position.set(1.5, gy + 5.5, -19);
  camera.lookAt(1.0, gy + 5.3, 0);

  O.logo(ov, W / 2, H - 140, 0.92);
  return r;
};

// ============================================================ 2) TEASER – CO JE POD POUŠTÍ?
SCENES.teaser = async ({ W, H, ov }) => {
  const r = L.setup(W, H, { fov: 40, bloom: 0.55, bloomThreshold: 0.85, env: 0.3, exposure: 0.9 });
  const { scene, camera } = r;
  scene.add(L.sky({ top: 0x2a35a8, mid: 0xf27a4e, bottom: 0xffb36e, sunDir: V(0.15, 0.1, 1) }));
  const ruinsPos = V(0, -1, 30);
  const t = L.dunes({
    amp: 6, scale: 60, seed: 9,
    craters: [
      { x: ruinsPos.x, z: ruinsPos.z, r: 34, depth: -7, rim: 0 },
      { x: ruinsPos.x, z: ruinsPos.z, r: 9, depth: 6.5, rim: 1 },
    ],
    color: 0xe39f55, light: 0xf5c47e, dark: 0xa8612c,
  });
  scene.add(t);
  L.lights(scene, { sun: V(-45, 28, -35), sunColor: 0xffb779, sunI: 3.4, hemiSky: 0x9aa8ff, hemiGround: 0xe6a05a, hemiI: 0.45, target: V(0, 0, 25), shadowSize: 60 });

  const ru = L.ruins({ ring: 15, pillars: 8, height: 15, broken: [1, 4, 6] });
  ru.position.copy(ruinsPos);
  scene.add(ru);
  const g = L.glow(COL.cyan, 22, 0.75); g.position.set(ruinsPos.x, ruinsPos.y + 6, ruinsPos.z); scene.add(g);
  scene.add(L.sparkles(30, V(ruinsPos.x, ruinsPos.y + 10, ruinsPos.z), V(18, 10, 10), COL.cyan, [0.5, 1.3], 21));

  const d = L.digger({ pose: 'hold', tool: L.shovel() });
  onGround(d, t, -11, 10);
  d.rotation.y = rad(145);
  scene.add(d);

  camera.position.set(-2, 27, -24);
  camera.lookAt(0, 9, 30);

  O.logo(ov, W / 2, 120, 0.7);
  O.bigText(ov, { text: "WHAT'S UNDER", x: W / 2, y: 345, size: 112, fill: ['#ffffff', '#ffe9b8', '#ffc76a'] });
  O.bigText(ov, { text: 'THE DESERT?', x: W / 2, y: 470, size: 124, fill: ['#c9fbff', '#5ee9ff', '#17a8e6'], extrudeColor: '#0c4f73' });
  O.pill(ov, 'COMING SOON TO ROBLOX', { x: W / 2, y: H - 110, size: 46, icon: O.robloxBadge(46) });
  O.vignette(ov, 0.35);
  return r;
};

// ------------------------------------------------------------ pomocníci
function floatAt(obj, x, y, z) {
  obj.position.set(0, 0, 0);
  obj.updateMatrixWorld(true);
  const b = new THREE.Box3().setFromObject(obj, true);
  obj.position.set(x - (b.min.x + b.max.x) / 2, y - b.min.y, z - (b.min.z + b.max.z) / 2);
  obj.updateMatrixWorld(true);
  return obj;
}
function bounds(obj) {
  obj.updateMatrixWorld(true);
  return new THREE.Box3().setFromObject(obj, true);
}
function display(tool, { tilt = 0, yaw = 0, roll = 0, scale = 1 } = {}) {
  const g = new THREE.Group();
  tool.rotation.set(rad(tilt), rad(yaw), rad(roll));
  g.add(tool);
  g.scale.setScalar(scale);
  return g;
}
function proj(camera, v, W, H) {
  camera.updateMatrixWorld(true);
  return L.project(camera, v, W, H);
}

// ============================================================ 3) PROGRES NÁSTROJŮ
SCENES.tools = async ({ W, H, ov }) => {
  const r = L.setup(W, H, { fov: 40, bloom: 0.45, bloomThreshold: 0.8 });
  const { scene, camera } = r;
  daySky(scene, { top: 0x1565f0, mid: 0x6cc4ff, bottom: 0xffe2a8, sunDir: V(-0.3, 0.3, 1) });
  const t = L.dunes({ amp: 3.5, scale: 50, seed: 12 });
  scene.add(t);
  L.lights(scene, { sun: V(30, 50, -40), target: V(0, 0, 8), shadowSize: 45 });
  scene.add(L.cloud(-90, 70, 260, 2.6), L.cloud(70, 55, 230, 2));

  const items = [
    { tool: L.spoon(), name: 'SPOON', price: '40', color: COL.common, css: '#b98552', x: 5.6, z: 9, r: 2.3, s: 1.7, tilt: 12, yaw: 30 },
    { tool: L.shovel(), name: 'SHOVEL', price: '1.5K', color: COL.rare, css: '#3d9bff', x: -5.6, z: 9, r: 2.5, s: 0.9, tilt: 8, yaw: -30 },
    { tool: L.vacuum(), name: 'VACUUM', price: '9K', color: COL.epic, css: '#a955ff', x: 5.4, z: -5, r: 2.7, s: 1.25, tilt: 8, yaw: 35 },
    { tool: L.claw(), name: 'TITAN EXCAVATOR', price: '350K', color: COL.legendary, css: '#ffb21f', x: -5.4, z: -5, r: 3.2, s: 1.15, tilt: 10, yaw: -40 },
  ];
  const bases = [];
  const tops = [];
  for (const it of items) {
    const gy = t.userData.heightAt(it.x, it.z) - 0.4;
    const p = L.podium(it.color, it.r, 1.4); p.position.set(it.x, gy, it.z); scene.add(p);
    const disp = display(it.tool, { tilt: it.tilt, yaw: it.yaw, scale: it.s });
    floatAt(disp, it.x, gy + 2.2, it.z);
    scene.add(disp);
    const b = bounds(disp);
    scene.add(L.sparkles(6, V(it.x, (b.min.y + b.max.y) / 2, it.z), V(it.r * 2, b.max.y - b.min.y, 2), 0xffffff, [0.3, 0.7], Math.round(it.x * 7 + it.z * 3 + 50)));
    tops.push(V(it.x, b.max.y, it.z));
    bases.push(V(it.x, gy, it.z - it.r));
  }

  camera.position.set(0, 17, -34);
  camera.lookAt(0, 3.6, 3);

  O.bigText(ov, { text: 'UPGRADE YOUR', x: W / 2, y: 130, size: 90, fill: ['#ffffff', '#fff2cf', '#ffd98a'] });
  O.bigText(ov, { text: 'TOOLS!', x: W / 2, y: 255, size: 145 });
  items.forEach((it, i) => {
    const p = proj(camera, bases[i], W, H);
    O.label(ov, p.x, p.y + 78, it.name, `${O.coinIcon(30)}${it.price}`, it.css, { size: i === 3 ? 38 : 36 });
    const tp = proj(camera, tops[i], W, H);
    O.numberBadge(ov, tp.x + (it.x > 0 ? -95 : 95), tp.y + 40, String(i + 1), `linear-gradient(#fff2a8,${it.css})`, 84);
  });
  O.pill(ov, '8 TOOLS • 8 BACKPACKS', { x: W / 2, y: H - 95, size: 44 });
  return r;
};

// ============================================================ 4) KÓD
SCENES.code = async ({ W, H, ov }) => {
  const r = L.setup(W, H, { fov: 40, bloom: 0.55, bloomThreshold: 0.8 });
  const { scene, camera } = r;
  daySky(scene, { top: 0x1565f0, mid: 0x6cc4ff, bottom: 0xffe2a8, sunDir: V(0, 0.4, 1) });
  const t = L.dunes({ amp: 4, scale: 45, seed: 21 });
  scene.add(t);
  L.lights(scene, { sun: V(-20, 40, -35), target: V(0, 0, 0), shadowSize: 20 });
  const ch = L.chest({ color: 0x2f7dff, open: true, scale: 1.3 });
  onGround(ch, t, 0, 0, -0.2);
  ch.rotation.y = rad(-12);
  scene.add(ch);
  const gy = ch.position.y;
  scene.add(L.coinRain(18, V(0, gy + 6.5, 0), V(12, 6, 4), [0.3, 0.55], 13));
  scene.add(L.sparkles(30, V(0, gy + 6, -1), V(16, 10, 4), 0xfff0a0, [0.4, 1.2], 17));

  scene.add(L.cloud(-70, 60, 230, 2.3), L.cloud(60, 75, 260, 2));
  camera.position.set(0, gy + 6, -17);
  camera.lookAt(0, gy + 0.6, 0);
  O.bigText(ov, { text: 'FREE CODE!', x: W / 2, y: 190, size: 150, rotate: -3 });
  O.html(ov, `
    <div style="font:700 34px Fredoka;color:#7a4a1c;letter-spacing:6px">ENTER THIS CODE</div>
    <div style="font:150px 'Luckiest Guy';line-height:1;margin-top:14px;color:#ff8a1f;-webkit-text-stroke:12px #3d1d08;paint-order:stroke;text-shadow:0 9px 0 #3d1d08">TIKTOK</div>
    <div style="margin-top:8px;display:inline-flex;align-items:center;gap:12px;font:58px 'Luckiest Guy';color:#ffc928;-webkit-text-stroke:7px #3d1d08;paint-order:stroke">${O.coinIcon(58)} +500 COINS</div>
  `, {
    left: W / 2 + 'px', top: H - 420 + 'px', transform: 'translate(-50%,-50%) rotate(-3deg)', textAlign: 'center',
    background: 'linear-gradient(#fffaf0,#ffe9c2)', border: '10px solid #3d1d08', borderRadius: '36px',
    padding: '34px 70px 40px', outline: '6px dashed #e9b066', outlineOffset: '-28px',
    boxShadow: '0 14px 0 #3d1d08, 0 30px 60px rgba(0,0,0,0.35)', whiteSpace: 'nowrap',
  });
  O.html(ov, `Open <b style="color:#ffc928">CODES</b> in Dune Diggers`, {
    left: W / 2 + 'px', top: H - 95 + 'px', transform: 'translate(-50%,-50%)', font: "700 40px Fredoka", color: '#fff',
    textShadow: '0 3px 0 #3d1d08, 0 0 18px rgba(0,0,0,0.5)', whiteSpace: 'nowrap',
  });
  return r;
};

// ============================================================ 5) MÝTICKÁ RELIKVIE
SCENES.relic = async ({ W, H, ov }) => {
  const r = L.setup(W, H, { fov: 42, bloom: 0.9, bloomThreshold: 0.7, bloomRadius: 0.7, env: 0.15, exposure: 1.05 });
  const { scene, camera } = r;
  scene.add(L.sky({ top: 0x070a26, mid: 0x2b1e6a, bottom: 0x8a3d6e, sunDir: V(-0.4, 0.5, 1) }));
  const t = L.dunes({ amp: 4, scale: 50, seed: 31, craters: [{ x: 0, z: 0, r: 34, depth: 11, rim: 2 }], color: 0xc98d55, light: 0xe0a86a, dark: 0x8a5530 });
  scene.add(t);
  L.lights(scene, { sun: V(-30, 50, -25), sunColor: 0x9db4ff, sunI: 1.1, hemiSky: 0x5a63c8, hemiGround: 0x6a3a40, hemiI: 0.45, target: V(0, -8, 0), shadowSize: 40 });
  const gy = t.userData.heightAt(0, 0);
  const ru = L.ruins({ ring: 15, pillars: 8, height: 14, broken: [5, 6, 7], head: true });
  ru.position.set(0, gy - 0.5, 0);
  scene.add(ru);
  const altarTop = gy - 0.5 + 3.8;
  const ch = L.chest({ color: COL.mythic, open: true, coins: false, glowColor: 0xff4070, scale: 1.1 });
  ch.position.set(0, altarTop, 0);
  ch.rotation.y = rad(-10);
  scene.add(ch);
  const heart = L.gem(COL.mythic, 1.3);
  heart.position.set(0, altarTop + 6.5, 0);
  heart.rotation.y = 0.5;
  scene.add(heart);
  scene.add(L.sparkles(40, V(0, altarTop + 6, 0), V(12, 9, 6), 0xff9ab0, [0.4, 1.2], 41));
  scene.add(L.sparkles(120, V(0, 160, 600), V(1400, 300, 50), 0xffffff, [1.5, 4], 43));
  const fill = new THREE.PointLight(0xffa080, 30, 30, 1.5); fill.position.set(2, altarTop + 4, -9); scene.add(fill);
  camera.position.set(0, altarTop + 6, -23);
  camera.lookAt(0, altarTop + 3.6, 0);

  O.bigText(ov, { text: 'ONLY 1%', x: W / 2, y: 215, size: 190, fill: ['#ffd1dc', '#ff5c85', '#d81b4a'], extrudeColor: '#5a0820' });
  O.bigText(ov, { text: 'FIND THIS...', x: W / 2, y: 335, size: 96, fill: ['#ffffff', '#f3e6ff', '#d6c2ff'], extrudeColor: '#3a1f6a' });
  O.pill(ov, 'MYTHIC', { x: W / 2, y: H - 175, size: 62, bg: 'linear-gradient(#ff6b8e,#d81b4a)' });
  O.html(ov, 'Heart of the Dunes &nbsp;•&nbsp; +100% coins forever', {
    left: W / 2 + 'px', top: H - 80 + 'px', transform: 'translate(-50%,-50%)', font: '700 38px Fredoka', color: '#fff',
    textShadow: '0 3px 0 #2a0a1a, 0 0 18px rgba(0,0,0,0.6)', whiteSpace: 'nowrap',
  });
  O.vignette(ov, 0.55);
  return r;
};

// ============================================================ 6) PÍSEČNÁ BOUŘE
SCENES.storm = async ({ W, H, ov }) => {
  const r = L.setup(W, H, { fov: 42, bloom: 0.35, fog: { color: 0xd38a45, near: 14, far: 95 }, exposure: 1.0, env: 0.3 });
  const { scene, camera } = r;
  scene.add(L.sky({ top: 0x7a3e1c, mid: 0xcf7f3c, bottom: 0xe29b55, sunDir: V(0.3, 0.25, 1) }));
  scene.children[0].material.fog = false;
  const t = L.dunes({ amp: 6, scale: 45, seed: 51, color: 0xe0a057, light: 0xf0bd78, dark: 0xb06a32 });
  scene.add(t);
  L.lights(scene, { sun: V(-25, 35, -30), sunColor: 0xffc690, sunI: 2.2, hemiSky: 0xffb070, hemiGround: 0xb36a33, hemiI: 0.7, target: V(0, 0, 0), shadowSize: 20 });
  const d = L.digger({ pose: 'brace', tool: null, face: 'wow' });
  d.userData.head.rotation.set(0, rad(-12), 0);
  onGround(d, t, 0, 0);
  d.rotation.y = rad(-20);
  scene.add(d);
  const gy = d.position.y;
  scene.add(L.dust(60, V(0, gy + 5, 15), V(60, 14, 40), 0xe9b070, [5, 14], 0.55, 61));
  scene.add(L.dust(20, V(-4, gy + 3, -3), V(18, 6, 4), 0xf0c080, [3, 7], 0.5, 67));
  scene.add(L.grains(900, V(0, gy + 4, 2), V(40, 12, 14), 0xffd59a, 0.22, 71));
  const sun = L.glow(0xfff0c0, 60, 0.6); sun.position.set(-40, 50, 160); scene.add(sun);
  camera.position.set(0.5, gy + 4.5, -17);
  camera.lookAt(0, gy + 5.2, 0);

  const tape = (top) => O.html(ov, '', {
    left: '-60px', width: W + 120 + 'px', top: top + 'px', height: '64px', transform: `rotate(${top < 300 ? -3 : 3}deg)`,
    background: 'repeating-linear-gradient(-45deg,#ffd21f 0 46px,#1d1a17 46px 92px)', border: '6px solid #1d1a17',
    boxShadow: '0 10px 30px rgba(0,0,0,0.4)',
  });
  tape(28);
  tape(H - 92);
  O.bigText(ov, { text: 'SANDSTORM', x: W / 2, y: 270, size: 150, fill: ['#fff1b0', '#ffae3a', '#ff5a14'], extrudeColor: '#5a1e05' });
  O.bigText(ov, { text: 'INCOMING!', x: W / 2, y: 385, size: 96, fill: ['#ffffff', '#ffe9d0', '#ffc9a0'] });
  O.pill(ov, '00:20', { x: W / 2, y: 485, size: 54, bg: 'linear-gradient(#ff5a5a,#c81e1e)' });
  O.html(ov, 'The desert gets buried again...<br><b style="color:#ffe14a">with NEW treasure!</b>', {
    left: W / 2 + 'px', top: H - 215 + 'px', transform: 'translate(-50%,-50%)', font: '700 46px Fredoka', color: '#fff', textAlign: 'center',
    textShadow: '0 4px 0 #4a1c05, 0 0 20px rgba(0,0,0,0.5)', lineHeight: '1.2',
  });
  O.vignette(ov, 0.5);
  return r;
};

// ============================================================ 7) KTERÝ BYS VYBRAL?
SCENES.choose = async ({ W, H, ov }) => {
  const r = L.setup(W, H, { fov: 38, bloom: 0.3, bloomThreshold: 0.92 });
  const { scene, camera } = r;
  daySky(scene, { top: 0x1565f0, mid: 0x6cc4ff, bottom: 0xffe2a8, sunDir: V(0, 0.35, 1) });
  const t = L.dunes({ amp: 3, scale: 50, seed: 77 });
  scene.add(t);
  L.lights(scene, { sun: V(0, 45, -40), target: V(0, 0, 0), shadowSize: 25 });
  scene.add(L.cloud(-70, 60, 240, 2.2), L.cloud(70, 70, 260, 2));

  const left = { x: 3.9, z: 2 }, right = { x: -3.9, z: 2 };
  const pL = L.podium(COL.legendary, 3, 1.4); pL.position.set(left.x, t.userData.heightAt(left.x, left.z) - 0.3, left.z); scene.add(pL);
  const pR = L.podium(COL.cyan, 3, 1.4); pR.position.set(right.x, t.userData.heightAt(right.x, right.z) - 0.3, right.z); scene.add(pR);
  const gold = display(L.shovel({ golden: true }), { tilt: 0, yaw: 25, roll: 18, scale: 1.25 });
  floatAt(gold, left.x, pL.position.y + 2.6, left.z); scene.add(gold);
  const vac = display(L.vacuum(), { tilt: 0, yaw: -35, roll: -12, scale: 1.6 });
  floatAt(vac, right.x, pR.position.y + 2.6, right.z); scene.add(vac);
  const gb = bounds(gold), vb = bounds(vac);
  const gG = L.glow(0xffc830, 9, 0.25); gG.position.set(left.x, (gb.min.y + gb.max.y) / 2, left.z + 1); scene.add(gG);
  const gV = L.glow(COL.cyan, 9, 0.25); gV.position.set(right.x, (vb.min.y + vb.max.y) / 2, right.z + 1); scene.add(gV);
  scene.add(L.sparkles(16, V(left.x, (gb.min.y + gb.max.y) / 2, left.z), V(6, 8, 3), 0xfff0a0, [0.4, 1.0], 81));
  scene.add(L.sparkles(16, V(right.x, (vb.min.y + vb.max.y) / 2, right.z), V(6, 8, 3), 0xc8f8ff, [0.4, 1.0], 83));
  camera.position.set(0, 8, -29);
  camera.lookAt(0, 6.2, 0);

  O.bigText(ov, { text: 'WHICH ONE', x: W / 2, y: 150, size: 128, fill: ['#ffffff', '#fff2cf', '#ffd98a'] });
  O.bigText(ov, { text: 'WOULD YOU PICK?', x: W / 2, y: 262, size: 86 });
  const a = proj(camera, V(left.x, gb.max.y, left.z), W, H);
  const b = proj(camera, V(right.x, vb.max.y, right.z), W, H);
  O.numberBadge(ov, a.x + 120, a.y + 60, '1', 'linear-gradient(#ffd54a,#ff9a00)');
  O.numberBadge(ov, b.x - 120, b.y + 60, '2', 'linear-gradient(#6af0ff,#1aa6e6)');
  const la = proj(camera, V(left.x, pL.position.y, left.z - 3.2), W, H);
  const lb = proj(camera, V(right.x, pR.position.y, right.z - 3.2), W, H);
  O.label(ov, la.x, la.y + 70, 'GOLDEN SHOVEL', null, null, { size: 42 });
  O.label(ov, lb.x, lb.y + 70, 'SAND VACUUM', null, null, { size: 42 });
  O.bigText(ov, { text: 'VS', x: W / 2, y: (a.y + la.y) / 2 + 40, size: 130, fill: ['#ffffff', '#ff6a6a', '#d81b1b'], extrudeColor: '#4a0505', rotate: -8 });
  O.pill(ov, 'COMMENT 1 OR 2!', { x: W / 2, y: H - 95, size: 50 });
  return r;
};

// ============================================================ 8) STORY – OUT NOW
SCENES.story = async ({ W, H, ov }) => {
  const r = L.setup(W, H, { fov: 44, bloom: 0.45, bloomThreshold: 0.82 });
  const { scene, camera } = r;
  daySky(scene, { top: 0x0f55e0, mid: 0x5cbcff, bottom: 0xffe0a0, sunDir: V(-0.4, 0.4, 1) });
  const t = L.dunes({ amp: 5, scale: 50, seed: 91, craters: [{ x: -6, z: 26, r: 26, depth: 7, rim: 2 }] });
  scene.add(t);
  L.lights(scene, { sun: V(-25, 45, -40), target: V(0, 0, 0), shadowSize: 25 });
  const d = L.digger({ pose: 'shoulder', tool: L.claw(), face: 'happy' });
  onGround(d, t, 0, 0);
  d.rotation.y = rad(-12);
  scene.add(d);
  const gy = d.position.y;
  const ch = L.chest({ color: COL.epic, open: true, scale: 0.85 });
  onGround(ch, t, -4.8, -1.5);
  ch.rotation.y = rad(30);
  scene.add(ch);
  scene.add(L.coinRain(10, V(-4, gy + 4, -2), V(5, 4, 2), [0.3, 0.5], 93));
  scene.add(L.sparkles(26, V(0, gy + 6, -2), V(16, 12, 4), 0xfff0a0, [0.4, 1.1], 97));
  scene.add(L.cloud(-60, 70, 230, 2.4), L.cloud(70, 90, 270, 2.2));
  camera.position.set(0, gy + 4, -16.5);
  camera.lookAt(-0.3, gy + 6.9, 0);

  // horních ~250 px zakrývá Instagram (jméno účtu, ukazatel) – text začíná níž
  O.logo(ov, W / 2, 350, 1.0);
  O.bigText(ov, { text: 'OUT NOW!', x: W / 2, y: 610, size: 170, fill: ['#ffffff', '#c9fbff', '#5ee9ff'], extrudeColor: '#0c4f73' });
  O.pill(ov, 'PLAY FREE ON ROBLOX', { x: W / 2, y: 730, size: 54, icon: O.robloxBadge(54) });
  return r;
};

// ============================================================ 9) THUMBNAIL 16:9
SCENES.thumbnail = async ({ W, H, ov }) => {
  const r = L.setup(W, H, { fov: 40, bloom: 0.5, bloomThreshold: 0.8 });
  const { scene, camera } = r;
  daySky(scene, { top: 0x1565f0, mid: 0x6cc4ff, bottom: 0xffe2a8, sunDir: V(-0.5, 0.3, 1) });
  const cx = -9, cz = 14;
  const t = L.dunes({ amp: 6, scale: 55, seed: 101, craters: [{ x: cx, z: cz, r: 26, depth: 9, rim: 2.5 }] });
  scene.add(t);
  L.lights(scene, { sun: V(20, 45, -35), target: V(cx, -5, cz), shadowSize: 40 });
  const crew = [
    { x: cx + 3, z: cz - 6, tool: L.shovel(), hat: 0xff7a1a, pose: 'dig', ry: 20 },
    { x: cx - 6, z: cz - 1, tool: L.vacuum(), hat: 0x3d9bff, pose: 'dig', ry: -30, toolRot: [-25, 0, 0] },
    { x: cx + 9, z: cz + 4, tool: L.claw(), hat: 0x55c24a, pose: 'hold', ry: 40 },
    { x: cx - 2, z: cz + 8, tool: L.shovel({ golden: true }), hat: 0xa955ff, pose: 'cheer', ry: 10 },
  ];
  for (const c of crew) {
    const d = L.digger({ pose: c.pose, tool: c.tool, hat: c.hat, toolRot: c.toolRot });
    onGround(d, t, c.x, c.z);
    d.rotation.y = rad(c.ry);
    scene.add(d);
    scene.add(L.dust(5, V(c.x, d.position.y + 0.8, c.z - 1), V(5, 1.5, 3), 0xf3cd8a, [2, 4], 0.4, Math.round(c.x * 13 + 200)));
  }
  const ch1 = L.chest({ color: COL.legendary, open: false, glowColor: 0xffd060, scale: 0.9 });
  onGround(ch1, t, cx + 1, cz + 1, -0.9); ch1.rotation.y = rad(-15); scene.add(ch1);
  const ch2 = L.chest({ color: COL.epic, open: false, glowColor: 0xc58aff, scale: 0.8 });
  onGround(ch2, t, cx - 9, cz + 9, -0.8); ch2.rotation.y = rad(25); scene.add(ch2);
  const ru = L.ruins({ ring: 12, pillars: 8, height: 14, broken: [0, 5], head: false });
  ru.position.set(cx - 4, t.userData.heightAt(cx - 4, cz + 40) - 8, cz + 40); scene.add(ru);
  scene.add(L.sparkles(30, V(cx, 6, cz), V(30, 10, 20), 0xfff0a0, [0.5, 1.3], 105));
  scene.add(L.cloud(-120, 70, 300, 2.6), L.cloud(40, 85, 320, 2.2));
  camera.position.set(cx + 4, 12, cz - 26);
  camera.lookAt(cx - 5, -1.5, cz + 5);

  O.bigText(ov, { text: 'DIG THE', x: 70, y: 300, size: 130, anchor: 'start', fill: ['#ffffff', '#fff2cf', '#ffd98a'], rotate: -4 });
  O.bigText(ov, { text: 'ENTIRE', x: 60, y: 470, size: 190, anchor: 'start', rotate: -4 });
  O.bigText(ov, { text: 'DESERT!', x: 70, y: 640, size: 170, anchor: 'start', fill: ['#c9fbff', '#5ee9ff', '#17a8e6'], extrudeColor: '#0c4f73', rotate: -4 });
  O.logo(ov, 300, H - 170, 0.85);
  return r;
};

// ============================================================ 10) MOCKUP – JAK TO VYPADÁ NA INSTAGRAMU
const ICON = {
  heart: (fill = 'none', stroke = '#111') => `<svg width="30" height="30" viewBox="0 0 24 24"><path d="M12 21s-7.5-4.6-9.6-9.1C.9 8.6 3 5 6.5 5c2 0 3.5 1.1 4.3 2.6h2.4C14 6.1 15.5 5 17.5 5 21 5 23.1 8.6 21.6 11.9 19.5 16.4 12 21 12 21z" fill="${fill}" stroke="${stroke}" stroke-width="1.8" stroke-linejoin="round"/></svg>`,
  comment: `<svg width="30" height="30" viewBox="0 0 24 24"><path d="M21 11.5a8.5 8.5 0 0 1-12.6 7.4L3 20.5l1.6-5A8.5 8.5 0 1 1 21 11.5z" fill="none" stroke="#111" stroke-width="1.8" stroke-linejoin="round"/></svg>`,
  share: `<svg width="30" height="30" viewBox="0 0 24 24"><path d="M22 3 9.5 13.5M22 3l-7 18-4-8-8-4z" fill="none" stroke="#111" stroke-width="1.8" stroke-linejoin="round"/></svg>`,
  save: `<svg width="28" height="28" viewBox="0 0 24 24"><path d="M5 3h14v18l-7-5-7 5z" fill="none" stroke="#111" stroke-width="1.8" stroke-linejoin="round"/></svg>`,
  dots: `<svg width="26" height="26" viewBox="0 0 24 24"><circle cx="5" cy="12" r="1.8" fill="#111"/><circle cx="12" cy="12" r="1.8" fill="#111"/><circle cx="19" cy="12" r="1.8" fill="#111"/></svg>`,
  link: `<svg width="30" height="30" viewBox="0 0 24 24"><path d="M10 14a5 5 0 0 0 7 0l3-3a5 5 0 0 0-7-7l-1 1M14 10a5 5 0 0 0-7 0l-3 3a5 5 0 0 0 7 7l1-1" fill="none" stroke="#2a7bff" stroke-width="2.4" stroke-linecap="round"/></svg>`,
  grid: `<svg width="28" height="28" viewBox="0 0 24 24"><path d="M3 3h18v18H3zM9 3v18M15 3v18M3 9h18M3 15h18" fill="none" stroke="#111" stroke-width="1.6"/></svg>`,
};

function phone(content, { x, y, w = 600, h = 1280, rot = 0, dark = false }) {
  return `<div style="position:absolute;left:${x}px;top:${y}px;width:${w}px;height:${h}px;transform:rotate(${rot}deg);border-radius:78px;background:#16161a;padding:18px;box-sizing:border-box;box-shadow:0 40px 80px rgba(70,30,0,0.45),inset 0 0 0 3px #3a3a40">
    <div style="position:relative;width:100%;height:100%;border-radius:62px;overflow:hidden;background:${dark ? '#000' : '#fff'};font-family:'Liberation Sans',Arial,sans-serif;color:#111">
      ${content}
      <div style="position:absolute;top:14px;left:50%;transform:translateX(-50%);width:150px;height:40px;border-radius:24px;background:#000;z-index:20"></div>
    </div></div>`;
}

const statusBar = (light = false) => `<div style="height:64px;display:flex;align-items:flex-end;justify-content:space-between;padding:0 38px 6px;font-weight:700;font-size:22px;color:${light ? '#fff' : '#111'};position:relative;z-index:5"><span>9:41</span><span style="letter-spacing:2px">▮▮▮ ◔ ▭</span></div>`;

SCENES.mockup = async ({ W, H, ov }) => {
  const img = (n) => `/out/${n}.png`;
  const cell = (n, pos = 'center') => `<div style="aspect-ratio:3/4;background:url(${img(n)}) ${pos}/cover"></div>`;
  const hl = (n, label, pos = 'center') => `<div style="text-align:center;font-size:17px;width:96px"><div style="width:86px;height:86px;margin:0 auto 6px;border-radius:50%;padding:3px;border:2px solid #ddd;box-sizing:border-box"><div style="width:100%;height:100%;border-radius:50%;background:url(${img(n)}) ${pos}/cover"></div></div>${label}</div>`;

  const profile = `
    ${statusBar()}
    <div style="display:flex;justify-content:space-between;align-items:center;padding:10px 28px 6px"><b style="font-size:30px">dunediggers ⌄</b><span style="font-size:30px">＋ ☰</span></div>
    <div style="display:flex;align-items:center;padding:14px 26px;gap:26px">
      <div style="width:150px;height:150px;border-radius:50%;padding:5px;background:conic-gradient(#ffb800,#ff3d6e,#a64dff,#ffb800);flex:none"><div style="width:100%;height:100%;border-radius:50%;border:4px solid #fff;box-sizing:border-box;background:url(${img('icon')}) center/cover"></div></div>
      <div style="display:flex;justify-content:space-around;flex:1;text-align:center;font-size:19px"><div><b style="font-size:27px">24</b><br>posts</div><div><b style="font-size:27px">12.4K</b><br>followers</div><div><b style="font-size:27px">38</b><br>following</div></div>
    </div>
    <div style="padding:0 28px;font-size:20px;line-height:1.35"><b>Dune Diggers 🏜️</b><br><span style="color:#777">Video game</span><br>Dig up the ENTIRE desert ⛏️<br>Free on Roblox – search "Dune Diggers"<br>🎁 New codes in every post!<br><b style="color:#00376b">roblox.com/games/dune-diggers</b></div>
    <div style="display:flex;gap:8px;padding:14px 26px"><div style="flex:1;background:#0095f6;color:#fff;border-radius:12px;text-align:center;padding:12px;font-weight:700;font-size:20px">Follow</div><div style="flex:1;background:#efefef;border-radius:12px;text-align:center;padding:12px;font-weight:700;font-size:20px">Message</div></div>
    <div style="display:flex;gap:6px;padding:6px 20px 12px">${hl('code', 'CODES', '50% 70%')}${hl('storm', 'EVENTS', '50% 45%')}${hl('tools', 'TOOLS', '30% 60%')}${hl('relic', 'RUINS', '50% 60%')}${hl('choose', 'POLLS', '50% 55%')}</div>
    <div style="display:flex;justify-content:space-around;border-top:1px solid #ddd;padding:10px 0;margin-bottom:2px">${ICON.grid}<span style="font-size:26px;opacity:.4">▶</span><span style="font-size:26px;opacity:.4">☺</span></div>
    <div style="display:grid;grid-template-columns:repeat(3,1fr);gap:3px">
      ${cell('code')}${cell('choose')}${cell('storm')}${cell('relic')}${cell('tools')}${cell('teaser')}${cell('story', '50% 30%')}${cell('thumbnail', '70% 50%')}${cell('icon')}
    </div>`;

  const feed = `
    ${statusBar()}
    <div style="display:flex;justify-content:space-between;align-items:center;padding:6px 26px 10px"><b style="font-size:30px;font-family:'Luckiest Guy';letter-spacing:1px;color:#111">Home</b><span style="display:flex;gap:22px">${ICON.heart()}${ICON.share}</span></div>
    <div style="display:flex;align-items:center;gap:14px;padding:10px 20px">
      <div style="width:58px;height:58px;border-radius:50%;padding:3px;background:conic-gradient(#ffb800,#ff3d6e,#a64dff,#ffb800)"><div style="width:100%;height:100%;border-radius:50%;border:3px solid #fff;box-sizing:border-box;background:url(${img('icon')}) center/cover"></div></div>
      <div style="flex:1;font-size:20px"><b>dunediggers</b> <span style="color:#0095f6">✔</span><br><span style="font-size:16px;color:#555">Dune Diggers • Roblox</span></div>${ICON.dots}
    </div>
    <div style="width:100%;aspect-ratio:4/5;background:url(${img('teaser')}) center/cover"></div>
    <div style="display:flex;align-items:center;gap:20px;padding:14px 20px 6px">${ICON.heart('#ff3040', '#ff3040')}${ICON.comment}${ICON.share}<span style="flex:1"></span>${ICON.save}</div>
    <div style="padding:2px 22px;font-size:20px;line-height:1.4">
      <b>8,214 likes</b><br>
      <b>dunediggers</b> What's under the desert? 👀 Something ancient is buried deep below the dunes... Who digs it up first? 🏜️⛏️ <span style="color:#00376b">#roblox #robloxgame #dunediggers</span><br>
      <span style="color:#777">View all 642 comments</span><br>
      <b>sandy.kid</b> it's a pyramid 100% 🔺<br>
      <b>noob_digger</b> RELEASE WHEN 😭😭<br>
      <span style="color:#999;font-size:16px">2 hours ago</span>
    </div>`;

  const story = `
    <div style="position:absolute;inset:0;background:url(${img('story')}) center/cover"></div>
    <div style="position:absolute;top:58px;left:16px;right:16px;display:flex;gap:6px;z-index:6">${[1, 0.5, 0].map((f) => `<div style="flex:1;height:5px;border-radius:3px;background:rgba(255,255,255,.4);overflow:hidden"><div style="width:${f * 100}%;height:100%;background:#fff"></div></div>`).join('')}</div>
    <div style="position:absolute;top:80px;left:20px;display:flex;align-items:center;gap:12px;color:#fff;font-size:21px;z-index:6;text-shadow:0 1px 4px rgba(0,0,0,.5)"><div style="width:52px;height:52px;border-radius:50%;border:2px solid #fff;background:url(${img('icon')}) center/cover"></div><b>dunediggers</b><span style="opacity:.8">2h</span></div>
    <div style="position:absolute;left:50%;top:1005px;transform:translate(-50%,-50%) rotate(-3deg);width:400px;background:#fff;border-radius:26px;padding:22px 20px 18px;box-shadow:0 12px 30px rgba(0,0,0,.35);z-index:6;text-align:center">
      <div style="font:30px 'Luckiest Guy';color:#111;margin-bottom:14px">BEST TOOL? 🤔</div>
      <div style="position:relative;border-radius:16px;background:#f0f0f0;margin:8px 0;height:52px;overflow:hidden;text-align:left"><div style="position:absolute;inset:0 38% 0 0;background:linear-gradient(90deg,#ffcf3a,#ff8a1f)"></div><b style="position:relative;line-height:52px;padding-left:16px;font-size:19px">GOLDEN SHOVEL</b><b style="position:absolute;right:16px;line-height:52px;font-size:19px">62%</b></div>
      <div style="position:relative;border-radius:16px;background:#f0f0f0;margin:8px 0;height:52px;overflow:hidden;text-align:left"><div style="position:absolute;inset:0 62% 0 0;background:linear-gradient(90deg,#7af0ff,#2aa8e6)"></div><b style="position:relative;line-height:52px;padding-left:16px;font-size:19px">SAND VACUUM</b><b style="position:absolute;right:16px;line-height:52px;font-size:19px">38%</b></div>
    </div>
    <div style="position:absolute;left:50%;top:1110px;transform:translateX(-50%);background:#fff;border-radius:16px;padding:12px 22px;display:flex;align-items:center;gap:10px;font-weight:700;font-size:21px;color:#2a7bff;box-shadow:0 8px 20px rgba(0,0,0,.3);z-index:6;white-space:nowrap">${ICON.link} PLAY DUNE DIGGERS</div>
    <div style="position:absolute;bottom:26px;left:20px;right:20px;display:flex;align-items:center;gap:16px;z-index:6"><div style="flex:1;border:2px solid rgba(255,255,255,.85);border-radius:30px;padding:14px 22px;color:#fff;font-size:19px">Send message</div>${ICON.heart('none', '#fff')}</div>`;

  O.html(ov, '', { inset: '0', background: 'radial-gradient(circle at 20% 10%, #fff3d6 0%, #ffd38a 45%, #f59a45 100%)' });
  O.html(ov, '', { left: '-200px', top: '900px', width: '900px', height: '900px', borderRadius: '50%', background: 'rgba(255,255,255,0.18)' });
  O.html(ov, '', { right: '-150px', top: '-250px', width: '700px', height: '700px', borderRadius: '50%', background: 'rgba(255,255,255,0.15)' });
  ov.root.appendChild(ov.svg); // logo nad pozadím
  O.logo(ov, 230, 120, 0.55);
  O.html(ov, '<b>INSTAGRAM PREVIEW</b><br><span style="font-weight:500;font-size:30px;opacity:.85">Profile grid • Feed post • Story with poll & link</span>', {
    left: '430px', top: '70px', font: "700 54px Fredoka", color: '#4a2410', lineHeight: '1.15',
  });
  O.html(ov, phone(profile, { x: 180, y: 250 }) + phone(feed, { x: 900, y: 230 }) + phone(story, { x: 1620, y: 250, dark: true }), { inset: '0' });
  O.html(ov, ['1. Profil – grid 3:4', '2. Příspěvek ve feedu', '3. Story s anketou a odkazem'].map((t, i) => `<div style="position:absolute;left:${[180, 900, 1620][i]}px;width:600px;top:1545px;text-align:center">${t}</div>`).join(''), {
    inset: '0', font: "700 32px Fredoka", color: '#4a2410',
  });

  return {
    after: async () => {
      const urls = ['icon', 'teaser', 'tools', 'code', 'relic', 'storm', 'choose', 'story', 'thumbnail'].map(img);
      await Promise.all(urls.map((u) => new Promise((res) => { const i = new Image(); i.onload = i.onerror = res; i.src = u; })));
      await new Promise((r) => setTimeout(r, 500));
    },
  };
};
