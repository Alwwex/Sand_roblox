// Náhledy hry: lobby ve 3D a UI nad ní (data z tests/preview_export.luau)
import * as L from './lib.js';
import { renderGuiTree, partMesh } from './guiRender.js';

const { THREE } = L;
const V = (x, y, z) => new THREE.Vector3(x, y, z);

async function load(name) {
  const res = await fetch(`/out/preview/${name}.json`);
  return res.json();
}

function textCanvas(text, color, w, h, font = "Luckiest Guy") {
  const c = document.createElement('canvas');
  c.width = w; c.height = h;
  const g = c.getContext('2d');
  let size = h * 0.8;
  g.font = `${size}px '${font}'`;
  while (g.measureText(text).width > w * 0.92 && size > 8) { size -= 2; g.font = `${size}px '${font}'`; }
  g.textAlign = 'center'; g.textBaseline = 'middle';
  g.lineJoin = 'round';
  g.lineWidth = size * 0.16; g.strokeStyle = '#3d1d08';
  g.strokeText(text, w / 2, h / 2 + size * 0.05);
  g.fillStyle = `rgb(${color.map((v) => Math.round(v * 255)).join(',')})`;
  g.fillText(text, w / 2, h / 2 + size * 0.05);
  const t = new THREE.CanvasTexture(c);
  t.colorSpace = THREE.SRGBColorSpace;
  return t;
}

async function buildLobby(W, H, { camPos, camTarget, fov = 38, character = false }) {
  const data = await load('lobby');
  const r = L.setup(W, H, { fov, bloom: 0.35, bloomThreshold: 0.9, env: 0.3, exposure: 0.95 });
  const { scene, camera } = r;
  scene.add(L.sky({ top: 0x1565f0, mid: 0x6cc4ff, bottom: 0xffe2a8, sunDir: V(-0.4, 0.35, 1) }));
  L.lights(scene, { sun: V(-60, 90, -70), target: V(0, 20, 0), shadowSize: 140, sunI: 3.0 });
  scene.add(L.cloud(-200, 110, 500, 4), L.cloud(150, 130, 600, 3.5), L.cloud(450, 100, 300, 3));

  // terén
  const { heights, step, origin } = data;
  const nz = heights.length, nx = heights[0].length;
  const pos = new Float32Array(nx * nz * 3);
  const col = new Float32Array(nx * nz * 3);
  const base = new THREE.Color(0xe7a24e), light = new THREE.Color(0xf4c271), dark = new THREE.Color(0xc27b3a), tmp = new THREE.Color();
  for (let iz = 0; iz < nz; iz++) {
    for (let ix = 0; ix < nx; ix++) {
      const x = origin + ix * step, z = origin + iz * step;
      let h = heights[iz][ix];
      if (Math.max(Math.abs(x), Math.abs(z)) < 62) h = Math.max(h, 28);
      const i = (iz * nx + ix) * 3;
      pos[i] = x; pos[i + 1] = h; pos[i + 2] = z;
      const n = Math.sin(x * 0.11) * Math.cos(z * 0.09) * 0.5 + 0.5;
      tmp.copy(base).lerp(light, n * 0.6).lerp(dark, Math.max(0, (24 - h) / 40));
      col[i] = tmp.r; col[i + 1] = tmp.g; col[i + 2] = tmp.b;
    }
  }
  const idx = [];
  for (let iz = 0; iz < nz - 1; iz++) for (let ix = 0; ix < nx - 1; ix++) {
    const a = iz * nx + ix, b = a + 1, c = a + nx, d = c + 1;
    idx.push(a, c, b, b, c, d);
  }
  const tg = new THREE.BufferGeometry();
  tg.setAttribute('position', new THREE.BufferAttribute(pos, 3));
  tg.setAttribute('color', new THREE.BufferAttribute(col, 3));
  tg.setIndex(idx);
  tg.computeVertexNormals();
  const terrain = new THREE.Mesh(tg, new THREE.MeshStandardMaterial({ vertexColors: true, roughness: 0.95 }));
  terrain.receiveShadow = true;
  scene.add(terrain);
  const far = L.dunes({ size: 1600, seg: 200, amp: 8, scale: 90, seed: 3, offsetY: 22 });
  far.position.y = -0.5;
  scene.add(far);

  // voda v oáze
  const water = new THREE.Mesh(new THREE.PlaneGeometry(24, 24), new THREE.MeshStandardMaterial({ color: 0x1fb3c9, roughness: 0.05, metalness: 0.3, transparent: true, opacity: 0.85 }));
  water.rotation.x = -Math.PI / 2; water.position.y = 29.8;
  scene.add(water);

  // party
  const meshes = data.parts.map((p) => { const m = partMesh(p); scene.add(m); return m; });
  // nápisy
  for (const lb of data.labels) {
    const p = data.parts[lb.i - 1];
    if (!p) continue;
    const sx = lb.size?.xs ?? 8, sy = lb.size?.ys ?? 2;
    const sprite = new THREE.Sprite(new THREE.SpriteMaterial({ map: textCanvas(lb.text, lb.col ?? [1, 1, 1], 1024, Math.round(1024 * sy / sx)), transparent: true, depthWrite: false }));
    sprite.scale.set(sx, sy, 1);
    sprite.position.set(p.cf[0] + lb.off[0], p.cf[1] + lb.off[1], p.cf[2] + lb.off[2]);
    scene.add(sprite);
  }
  for (const sg of data.signs) {
    const p = data.parts[sg.i - 1];
    if (!p) continue;
    const plane = new THREE.Mesh(new THREE.PlaneGeometry(p.s[0] * 0.95, p.s[1] * 0.9), new THREE.MeshBasicMaterial({ map: textCanvas(sg.text, sg.col ?? [1, 1, 1], 1024, Math.round(1024 * p.s[1] / p.s[0])), transparent: true }));
    const front = sg.face !== 'Back';
    const local = new THREE.Matrix4().makeTranslation(0, 0, front ? -p.s[2] / 2 - 0.05 : p.s[2] / 2 + 0.05);
    if (front) local.multiply(new THREE.Matrix4().makeRotationY(Math.PI));
    plane.matrixAutoUpdate = false;
    plane.matrix.copy(meshes[sg.i - 1].matrix).multiply(local);
    scene.add(plane);
  }
  if (character) {
    const d = L.digger({ pose: 'hold', tool: L.vacuum(), toolRot: [-35, 0, 0] });
    d.position.set(0, 30.4, -21);
    d.rotation.y = Math.PI;
    scene.add(d);
  }
  camera.position.copy(camPos);
  camera.lookAt(camTarget);
  return r;
}

export const PREVIEW_SCENES = {};

PREVIEW_SCENES.lobby_aerial = ({ W, H }) => buildLobby(W, H, { camPos: V(-135, 105, -150), camTarget: V(0, 22, 6), fov: 40 });
PREVIEW_SCENES.lobby_ground = ({ W, H }) => buildLobby(W, H, { camPos: V(4, 39, -34), camTarget: V(0, 33, 12), fov: 55, character: true });

const UI_STATES = {
  menu: { cam: [V(-135, 105, -150), V(0, 22, 6), 40], blur: false },
  hud: { cam: [V(4, 39, -34), V(0, 33, 12), 55], blur: false, character: true },
  shop: { blur: true }, store: { blur: true }, top: { blur: true }, index: { blur: true }, rebirth: { blur: true }, settings: { blur: true },
  hud2: { cam: [V(4, 39, -34), V(0, 33, 12), 55], blur: false, character: true },
  egg: { blur: true }, pets: { blur: true }, quests: { blur: true }, hatch: { blur: true },
};

PREVIEW_SCENES.lobby_hatchery = ({ W, H }) => buildLobby(W, H, { camPos: V(10, 44, 18), camTarget: V(28, 33, 50), fov: 50 });
PREVIEW_SCENES.lobby_buyer = ({ W, H }) => buildLobby(W, H, { camPos: V(-22, 40, -16), camTarget: V(-44, 33, 0), fov: 50 });

// Studiové náhledy 3D modelů (mazlíčci, vajíčka, nástroje)
async function buildModels(W, H, name, { camPos, camTarget, fov }) {
  const data = await load(name);
  const r = L.setup(W, H, { fov, bloom: 0.3, bloomThreshold: 0.9, env: 0.35, exposure: 1.0 });
  const { scene, camera } = r;
  scene.add(L.sky({ top: 0x1565f0, mid: 0x6cc4ff, bottom: 0xffe2a8, sunDir: V(-0.4, 0.35, 1) }));
  L.lights(scene, { sun: V(-30, 50, -40), target: V(0, 0, 4), shadowSize: 40, sunI: 3.0 });
  const ground = new THREE.Mesh(new THREE.CircleGeometry(120, 64), new THREE.MeshStandardMaterial({ color: 0xf0c27a, roughness: 0.95 }));
  ground.rotation.x = -Math.PI / 2;
  ground.receiveShadow = true;
  scene.add(ground);
  for (const p of data.parts) scene.add(partMesh(p));
  camera.position.copy(camPos);
  camera.lookAt(camTarget);
  return r;
}
PREVIEW_SCENES.models_pets = ({ W, H }) => buildModels(W, H, 'models_pets', { camPos: V(4, 13, -24), camTarget: V(0, 1.5, 5), fov: 42 });
PREVIEW_SCENES.models_tools = ({ W, H }) => buildModels(W, H, 'models_tools', { camPos: V(4, 6, -26), camTarget: V(4, 3, 0), fov: 40 });
PREVIEW_SCENES.models_pets_close = ({ W, H }) => buildModels(W, H, 'models_pets', { camPos: V(9, 4.5, -3), camTarget: V(9, 1.6, 6), fov: 45 });
for (const [name, cfg] of Object.entries(UI_STATES)) {
  PREVIEW_SCENES['ui_' + name] = async ({ W, H }) => {
    const cam = cfg.cam ?? UI_STATES.hud.cam;
    const r = await buildLobby(W, H, { camPos: cam[0], camTarget: cam[1], fov: cam[2], character: cfg.character || cfg.blur });
    for (let i = 0; i < 3; i++) r.composer.render();
    if (cfg.blur) r.renderer.domElement.style.filter = 'blur(7px)';
    const tree = await load('ui_' + name);
    await renderGuiTree(tree, W, H, name === 'menu' ? {} : { leaderstats: '48.2K &nbsp;&nbsp;&nbsp; 2' });
    return { after: async () => {} };
  };
}

// ---------------------------------------------------------------------------
// Náhled meshů z assets/models/DuneDiggersModels.glb (jak budou vypadat v Robloxu)
// URL: ?g=mesh&file=models/DuneDiggersModels.glb&assets=SandBunny,FennecFox&yaw=25&pitch=12&zoom=1
// ---------------------------------------------------------------------------
PREVIEW_SCENES.mesh = async ({ W, H }) => {
  const { GLTFLoader } = await import('three/addons/loaders/GLTFLoader.js');
  const q = new URLSearchParams(location.search);
  const file = q.get('file') || 'models/DuneDiggersModels.glb';
  const wanted = (q.get('assets') || '').split(',').filter(Boolean);
  const yaw = THREE.MathUtils.degToRad(Number(q.get('yaw') ?? 28));
  const pitch = THREE.MathUtils.degToRad(Number(q.get('pitch') ?? 14));
  const zoom = Number(q.get('zoom') ?? 1);
  const gap = Number(q.get('gap') ?? 0.9);
  const r = L.setup(W, H, { fov: 30, bloom: 0.2, bloomThreshold: 0.95, env: 0.45, exposure: 0.95 });
  const { scene, camera } = r;
  scene.background = new THREE.Color(0x9fd3f5);
  const gltf = await new Promise((res, rej) => new GLTFLoader().load('/out/' + file, res, undefined, rej));
  const groups = new Map();
  gltf.scene.traverse((o) => {
    if (!o.isMesh) return;
    const m = o.name.match(/^(\w+?)__(\w+?)__([0-9A-F]{6})__([A-Z])__/);
    if (!m) { o.visible = false; return; }
    const [, asset, , hex, mat] = m;
    if (wanted.length && !wanted.includes(asset)) { o.visible = false; return; }
    const color = new THREE.Color('#' + hex);
    const opts = { color, roughness: 0.5, metalness: 0 };
    if (mat === 'M') Object.assign(opts, { metalness: 0.75, roughness: 0.32 });
    if (mat === 'W') Object.assign(opts, { roughness: 0.85 });
    if (mat === 'N') Object.assign(opts, { emissive: color, emissiveIntensity: 1.3, roughness: 0.4 });
    if (mat === 'G') Object.assign(opts, { transparent: true, opacity: 0.55, roughness: 0.08, depthWrite: false });
    o.material = new THREE.MeshStandardMaterial(opts);
    o.castShadow = mat !== 'G';
    o.receiveShadow = true;
    if (!groups.has(asset)) groups.set(asset, []);
    groups.get(asset).push(o);
  });
  scene.add(gltf.scene);
  gltf.scene.updateMatrixWorld(true);
  // přeskládat vybrané modely do řady (zleva doprava z pohledu kamery)
  const order = wanted.length ? wanted.filter((a) => groups.has(a)) : [...groups.keys()];
  let cursor = 0;
  const all = new THREE.Box3();
  for (const asset of order) {
    const box = new THREE.Box3();
    for (const o of groups.get(asset)) box.expandByObject(o);
    const width = box.max.x - box.min.x;
    const dx = -(cursor + width / 2) - (box.min.x + box.max.x) / 2;
    const dz = -(box.min.z + box.max.z) / 2;
    for (const o of groups.get(asset)) { o.position.x += dx; o.position.z += dz; o.position.y -= box.min.y; }
    cursor += width + gap;
  }
  gltf.scene.updateMatrixWorld(true);
  for (const asset of order) for (const o of groups.get(asset)) all.expandByObject(o);
  const center = all.getCenter(new THREE.Vector3());
  const size = all.getSize(new THREE.Vector3());
  const ground = new THREE.Mesh(new THREE.CircleGeometry(400, 64), new THREE.MeshStandardMaterial({ color: 0xe9b873, roughness: 0.95 }));
  ground.rotation.x = -Math.PI / 2; ground.receiveShadow = true; scene.add(ground);
  L.lights(scene, { sun: V(-18, 30, -22), target: center, shadowSize: Math.max(size.x, size.z) * 0.8 + 4, sunI: 3.0, hemiI: 0.55 });
  const radius = Math.max(size.x / (W / H), size.y) * 0.62 / zoom + 1;
  const dist = radius / Math.tan(THREE.MathUtils.degToRad(15));
  const dir = new THREE.Vector3(Math.sin(yaw) * Math.cos(pitch), Math.sin(pitch), -Math.cos(yaw) * Math.cos(pitch));
  camera.position.copy(center).add(dir.multiplyScalar(dist));
  camera.lookAt(center);
  return r;
};
