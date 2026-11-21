// Stavebnice 3D scén pro marketingové grafiky Dune Diggers (three.js)
import * as THREE from 'three';
import { RoundedBoxGeometry } from 'three/addons/geometries/RoundedBoxGeometry.js';
import { EffectComposer } from 'three/addons/postprocessing/EffectComposer.js';
import { RenderPass } from 'three/addons/postprocessing/RenderPass.js';
import { UnrealBloomPass } from 'three/addons/postprocessing/UnrealBloomPass.js';
import { OutputPass } from 'three/addons/postprocessing/OutputPass.js';
import { RoomEnvironment } from 'three/addons/environments/RoomEnvironment.js';

export { THREE };

// ---------------------------------------------------------------- barvy
export const COL = {
  sand: 0xe7a24e,
  sandDark: 0xb46a2c,
  sandLight: 0xf4c271,
  skin: 0xf7c58e,
  hat: 0xff7a1a,
  shirt: 0xeed8a8,
  pants: 0x6e4a2c,
  boots: 0x3d2614,
  wood: 0x9a6236,
  metal: 0xb9c2cc,
  dark: 0x2c2c33,
  gold: 0xffc829,
  cyan: 0x47e6ff,
  mythic: 0xff3c6a,
  stone: 0xe0c08c,
  stoneDark: 0xb08a5a,
  common: 0xa87a4c,
  rare: 0x3d9bff,
  epic: 0xa955ff,
  legendary: 0xffbf1f,
};

// ---------------------------------------------------------------- šum
function makePerlin(seed = 1) {
  const p = new Uint8Array(512);
  const perm = [...Array(256).keys()];
  let s = seed * 9301 + 49297;
  for (let i = 255; i > 0; i--) {
    s = (s * 9301 + 49297) % 233280;
    const j = Math.floor((s / 233280) * (i + 1));
    [perm[i], perm[j]] = [perm[j], perm[i]];
  }
  for (let i = 0; i < 512; i++) p[i] = perm[i & 255];
  const fade = (t) => t * t * t * (t * (t * 6 - 15) + 10);
  const grad = (h, x, y) => {
    const v = h & 3;
    return (v & 1 ? -x : x) + (v & 2 ? -y : y);
  };
  return (x, y) => {
    const X = Math.floor(x) & 255, Y = Math.floor(y) & 255;
    x -= Math.floor(x); y -= Math.floor(y);
    const u = fade(x), v = fade(y);
    const a = p[X] + Y, b = p[X + 1] + Y;
    return THREE.MathUtils.lerp(
      THREE.MathUtils.lerp(grad(p[a], x, y), grad(p[b], x - 1, y), u),
      THREE.MathUtils.lerp(grad(p[a + 1], x, y - 1), grad(p[b + 1], x - 1, y - 1), u),
      v,
    );
  };
}

// ---------------------------------------------------------------- materiály
export function mat(color, o = {}) {
  return new THREE.MeshStandardMaterial({
    color,
    roughness: o.rough ?? 0.75,
    metalness: o.metal ?? 0,
    emissive: o.emissive ?? 0x000000,
    emissiveIntensity: o.ei ?? 1,
    transparent: o.opacity !== undefined,
    opacity: o.opacity ?? 1,
    flatShading: o.flat ?? false,
  });
}

function shadowed(mesh) {
  mesh.castShadow = true;
  mesh.receiveShadow = true;
  return mesh;
}

export function rbox(w, h, d, r, color, o) {
  return shadowed(new THREE.Mesh(new RoundedBoxGeometry(w, h, d, 3, r), mat(color, o)));
}

export function cyl(rt, rb, h, color, o = {}, seg = 24) {
  return shadowed(new THREE.Mesh(new THREE.CylinderGeometry(rt, rb, h, seg), mat(color, o)));
}

export function sphere(r, color, o = {}) {
  return shadowed(new THREE.Mesh(new THREE.SphereGeometry(r, 32, 16), mat(color, o)));
}

// ---------------------------------------------------------------- textury
function canvasTexture(size, draw) {
  const c = document.createElement('canvas');
  c.width = c.height = size;
  draw(c.getContext('2d'), size);
  const t = new THREE.CanvasTexture(c);
  t.colorSpace = THREE.SRGBColorSpace;
  return t;
}

const glowTex = canvasTexture(256, (g, s) => {
  const grd = g.createRadialGradient(s / 2, s / 2, 0, s / 2, s / 2, s / 2);
  grd.addColorStop(0, 'rgba(255,255,255,1)');
  grd.addColorStop(0.25, 'rgba(255,255,255,0.55)');
  grd.addColorStop(1, 'rgba(255,255,255,0)');
  g.fillStyle = grd;
  g.fillRect(0, 0, s, s);
});

const starTex = canvasTexture(256, (g, s) => {
  const c = s / 2;
  const grd = g.createRadialGradient(c, c, 0, c, c, c * 0.35);
  grd.addColorStop(0, 'rgba(255,255,255,1)');
  grd.addColorStop(1, 'rgba(255,255,255,0)');
  g.fillStyle = grd;
  g.fillRect(0, 0, s, s);
  g.fillStyle = 'white';
  g.beginPath();
  for (let i = 0; i < 8; i++) {
    const a = (i / 8) * Math.PI * 2;
    const r = i % 2 === 0 ? c * 0.95 : c * 0.1;
    g.lineTo(c + Math.cos(a) * r, c + Math.sin(a) * r);
  }
  g.closePath();
  g.fill();
});

const smokeTex = canvasTexture(256, (g, s) => {
  for (let i = 0; i < 14; i++) {
    const x = s / 2 + (Math.random() - 0.5) * s * 0.4;
    const y = s / 2 + (Math.random() - 0.5) * s * 0.4;
    const r = s * (0.15 + Math.random() * 0.2);
    const grd = g.createRadialGradient(x, y, 0, x, y, r);
    grd.addColorStop(0, 'rgba(255,255,255,0.35)');
    grd.addColorStop(1, 'rgba(255,255,255,0)');
    g.fillStyle = grd;
    g.fillRect(0, 0, s, s);
  }
});

export function glow(color, size, opacity = 1) {
  const s = new THREE.Sprite(
    new THREE.SpriteMaterial({ map: glowTex, color, blending: THREE.AdditiveBlending, depthWrite: false, transparent: true, opacity }),
  );
  s.scale.set(size, size, 1);
  return s;
}

export function sparkles(count, center, spread, color = 0xffffff, size = [0.4, 1.2], seed = 3) {
  const grp = new THREE.Group();
  let s = seed;
  const rnd = () => ((s = (s * 16807) % 2147483647) / 2147483647);
  for (let i = 0; i < count; i++) {
    const sp = new THREE.Sprite(
      new THREE.SpriteMaterial({ map: starTex, color, blending: THREE.AdditiveBlending, depthWrite: false, transparent: true }),
    );
    const k = size[0] + rnd() * (size[1] - size[0]);
    sp.scale.set(k, k, 1);
    sp.material.rotation = rnd() * Math.PI;
    sp.position.set(
      center.x + (rnd() - 0.5) * spread.x,
      center.y + (rnd() - 0.5) * spread.y,
      center.z + (rnd() - 0.5) * spread.z,
    );
    grp.add(sp);
  }
  return grp;
}

// Oblaka písku / prachu
export function dust(count, center, spread, color = 0xf0c27a, size = [2, 6], opacity = 0.5, seed = 7) {
  const grp = new THREE.Group();
  let s = seed;
  const rnd = () => ((s = (s * 16807) % 2147483647) / 2147483647);
  for (let i = 0; i < count; i++) {
    const sp = new THREE.Sprite(
      new THREE.SpriteMaterial({ map: smokeTex, color, depthWrite: false, transparent: true, opacity: opacity * (0.5 + rnd() * 0.5) }),
    );
    const k = size[0] + rnd() * (size[1] - size[0]);
    sp.scale.set(k, k, 1);
    sp.material.rotation = rnd() * Math.PI * 2;
    sp.position.set(
      center.x + (rnd() - 0.5) * spread.x,
      center.y + (rnd() - 0.5) * spread.y,
      center.z + (rnd() - 0.5) * spread.z,
    );
    grp.add(sp);
  }
  return grp;
}

// Létající zrnka písku
export function grains(count, center, spread, color = 0xf5cf86, size = 0.18, seed = 11) {
  const geo = new THREE.BufferGeometry();
  const pos = new Float32Array(count * 3);
  let s = seed;
  const rnd = () => ((s = (s * 16807) % 2147483647) / 2147483647);
  for (let i = 0; i < count; i++) {
    pos[i * 3] = center.x + (rnd() - 0.5) * spread.x;
    pos[i * 3 + 1] = center.y + (rnd() - 0.5) * spread.y;
    pos[i * 3 + 2] = center.z + (rnd() - 0.5) * spread.z;
  }
  geo.setAttribute('position', new THREE.BufferAttribute(pos, 3));
  const m = new THREE.PointsMaterial({ color, size, map: glowTex, transparent: true, depthWrite: false });
  return new THREE.Points(geo, m);
}

// ---------------------------------------------------------------- terén
export function dunes({
  size = 500, seg = 260, amp = 7, scale = 70, seed = 2, craters = [], ripples = 0.12,
  color = COL.sand, dark = COL.sandDark, light = COL.sandLight, offsetY = 0,
} = {}) {
  const noise = makePerlin(seed);
  const g = new THREE.PlaneGeometry(size, size, seg, seg);
  g.rotateX(-Math.PI / 2);
  const pos = g.attributes.position;
  const colors = new Float32Array(pos.count * 3);
  const cBase = new THREE.Color(color), cDark = new THREE.Color(dark), cLight = new THREE.Color(light);
  const tmp = new THREE.Color();
  for (let i = 0; i < pos.count; i++) {
    const x = pos.getX(i), z = pos.getZ(i);
    const n1 = noise(x / scale, z / scale);
    const n2 = noise(x / (scale * 0.4) + 10, z / (scale * 0.4) + 10);
    const ridge = 1 - Math.abs(n2) * 2;
    let h = n1 * amp * 1.4 + ridge * amp * 0.45;
    h += Math.sin(x * 0.9 + noise(x / 9, z / 9) * 4 + z * 0.25) * ripples;
    let shade = 0;
    for (const c of craters) {
      const d = Math.hypot(x - c.x, z - c.z);
      if (d < c.r) {
        const t = 1 - (d / c.r) ** 2;
        h -= c.depth * t;
        shade = Math.max(shade, t * 0.55);
      } else if (d < c.r * 1.35) {
        const t = 1 - (d - c.r) / (c.r * 0.35);
        h += (c.rim ?? 1.2) * Math.sin(t * Math.PI);
      }
    }
    pos.setY(i, h + offsetY);
    const v = THREE.MathUtils.clamp(0.5 + n2 * 0.6, 0, 1);
    tmp.copy(cBase).lerp(cLight, v * 0.5).lerp(cDark, shade);
    colors[i * 3] = tmp.r; colors[i * 3 + 1] = tmp.g; colors[i * 3 + 2] = tmp.b;
  }
  g.setAttribute('color', new THREE.BufferAttribute(colors, 3));
  g.computeVertexNormals();
  const m = new THREE.Mesh(g, new THREE.MeshStandardMaterial({ vertexColors: true, roughness: 0.95 }));
  m.receiveShadow = true;
  m.castShadow = true;
  // výška v bodě (pro pokládání objektů)
  m.userData.heightAt = (x, z) => {
    const ray = new THREE.Raycaster(new THREE.Vector3(x, 200, z), new THREE.Vector3(0, -1, 0));
    const hit = ray.intersectObject(m);
    return hit.length ? hit[0].point.y : 0;
  };
  return m;
}

// ---------------------------------------------------------------- obloha
export function sky({ top = 0x2f8cff, mid = 0x9fd8ff, bottom = 0xffe0a8, sunDir = new THREE.Vector3(0.4, 0.5, -1) } = {}) {
  const m = new THREE.ShaderMaterial({
    side: THREE.BackSide,
    depthWrite: false,
    uniforms: {
      top: { value: new THREE.Color(top) },
      mid: { value: new THREE.Color(mid) },
      bottom: { value: new THREE.Color(bottom) },
      sunDir: { value: sunDir.clone().normalize() },
    },
    vertexShader: `varying vec3 vW; void main(){ vW = normalize(position); gl_Position = projectionMatrix*modelViewMatrix*vec4(position,1.0); }`,
    fragmentShader: `uniform vec3 top; uniform vec3 mid; uniform vec3 bottom; uniform vec3 sunDir; varying vec3 vW;
      void main(){
        float h = vW.y;
        vec3 c = mix(bottom, mid, smoothstep(-0.05, 0.18, h));
        c = mix(c, top, smoothstep(0.18, 0.85, h));
        float sun = max(dot(normalize(vW), sunDir), 0.0);
        c += vec3(1.0,0.85,0.55) * pow(sun, 18.0) * 0.6 + vec3(1.0,0.95,0.8) * pow(sun, 400.0) * 3.0;
        gl_FragColor = vec4(c, 1.0);
        #include <colorspace_fragment>
      }`,
  });
  return new THREE.Mesh(new THREE.SphereGeometry(1800, 32, 16), m);
}

export function cloud(x, y, z, s = 1) {
  const g = new THREE.Group();
  const m = mat(0xffffff, { rough: 1, emissive: 0xfff6e8, ei: 0.35 });
  [[0, 0, 0, 6], [5, -1, 1, 4.5], [-5, -1.2, 0, 4.2], [2, 2.5, 0, 4.5], [-2.5, 2, 1, 3.8], [8, -2, 0, 3]].forEach(([a, b, c, r]) => {
    const sp = new THREE.Mesh(new THREE.SphereGeometry(r, 24, 12), m);
    sp.position.set(a, b, c);
    g.add(sp);
  });
  g.scale.set(s, s * 0.7, s * 0.8);
  g.position.set(x, y, z);
  return g;
}

// ---------------------------------------------------------------- postavička "Digger"
export function digger({
  hat = COL.hat, shirt = COL.shirt, pants = COL.pants, skin = COL.skin, pose = 'hold', tool = null,
  face = 'happy', toolRot = null,
} = {}) {
  const root = new THREE.Group();
  const add = (m, x, y, z, parent = root) => { m.position.set(x, y, z); parent.add(m); return m; };

  // nohy
  const legL = new THREE.Group(); legL.position.set(-0.5, 2, 0); root.add(legL);
  const legR = new THREE.Group(); legR.position.set(0.5, 2, 0); root.add(legR);
  for (const leg of [legL, legR]) {
    add(rbox(0.95, 1.6, 0.95, 0.12, pants), 0, -0.75, 0, leg);
    add(rbox(1.02, 0.5, 1.15, 0.14, COL.boots), 0, -1.75, -0.07, leg);
  }
  // trup
  add(rbox(2, 2, 1, 0.16, shirt), 0, 3, 0);
  add(rbox(2.06, 0.32, 1.06, 0.1, 0x5a3416), 0, 2.15, 0);
  add(rbox(0.36, 0.3, 0.12, 0.05, COL.gold, { metal: 0.8, rough: 0.3 }), 0, 2.15, -0.56);
  // kapsy
  add(rbox(0.5, 0.45, 0.08, 0.06, 0xdcc08a), -0.5, 3.35, -0.52);
  add(rbox(0.5, 0.45, 0.08, 0.06, 0xdcc08a), 0.5, 3.35, -0.52);
  // šátek
  add(rbox(1.2, 0.35, 1.1, 0.12, 0xe8463a), 0, 3.95, -0.05);

  // ruce (pivot v rameni)
  const armL = new THREE.Group(); armL.position.set(-1.5, 3.8, 0); root.add(armL);
  const armR = new THREE.Group(); armR.position.set(1.5, 3.8, 0); root.add(armR);
  for (const arm of [armL, armR]) {
    add(rbox(0.95, 1.1, 0.95, 0.12, shirt), 0, -0.45, 0, arm);
    add(rbox(0.9, 0.9, 0.9, 0.14, skin), 0, -1.45, 0, arm);
  }
  const handR = new THREE.Group(); handR.position.set(0, -1.6, 0); armR.add(handR);
  const handL = new THREE.Group(); handL.position.set(0, -1.6, 0); armL.add(handL);

  // hlava
  const head = new THREE.Group(); head.position.set(0, 4.75, 0); root.add(head);
  add(rbox(1.35, 1.3, 1.3, 0.3, skin), 0, 0, 0, head);
  const eyeM = (x) => {
    const e = add(rbox(0.2, face === 'wow' ? 0.34 : 0.3, 0.08, 0.08, 0x1d1410), x, 0.12, -0.66, head);
    add(sphere(0.05, 0xffffff, { emissive: 0xffffff, ei: 0.5 }), x + 0.04, 0.2, -0.71, head);
    return e;
  };
  eyeM(-0.28); eyeM(0.28);
  add(rbox(0.3, 0.07, 0.06, 0.03, 0x6b3b1c), -0.28, 0.38, -0.66, head).rotation.z = 0.12;
  add(rbox(0.3, 0.07, 0.06, 0.03, 0x6b3b1c), 0.28, 0.38, -0.66, head).rotation.z = -0.12;
  if (face === 'wow') {
    const mouth = add(new THREE.Mesh(new THREE.TorusGeometry(0.12, 0.05, 8, 20), mat(0x3a1a10)), 0, -0.28, -0.66, head);
    mouth.scale.set(1, 1.3, 1);
  } else {
    const smile = add(new THREE.Mesh(new THREE.TorusGeometry(0.24, 0.055, 8, 20, Math.PI), mat(0x3a1a10)), 0, -0.12, -0.66, head);
    smile.rotation.z = Math.PI;
  }
  // tváře
  add(sphere(0.12, 0xff8f7a, { opacity: 0.6 }), -0.48, -0.12, -0.63, head).scale.set(1, 0.6, 0.3);
  add(sphere(0.12, 0xff8f7a, { opacity: 0.6 }), 0.48, -0.12, -0.63, head).scale.set(1, 0.6, 0.3);

  // klobouk (průzkumnický)
  const brim = add(cyl(1.15, 1.15, 0.12, hat, { rough: 0.6 }, 32), 0, 0.62, 0, head);
  brim.scale.set(1, 1, 1.05);
  const dome = add(new THREE.Mesh(new THREE.SphereGeometry(0.78, 32, 16, 0, Math.PI * 2, 0, Math.PI / 2), mat(hat, { rough: 0.55 })), 0, 0.66, 0, head);
  dome.castShadow = true;
  dome.scale.set(1, 0.8, 1);
  add(cyl(0.8, 0.8, 0.18, 0x5a3416, {}, 32), 0, 0.76, 0, head);
  add(rbox(0.3, 0.3, 0.06, 0.06, COL.gold, { metal: 0.8, rough: 0.3 }), 0, 0.85, -0.79, head);

  // pózy (postava se dívá směrem -Z; kladná rotace X = ruka dopředu)
  const rad = THREE.MathUtils.degToRad;
  let defaultToolRot = [0, 0, 0];
  if (pose === 'hold') {
    armR.rotation.set(rad(70), 0, rad(6));
    armL.rotation.set(rad(18), 0, rad(-8));
    defaultToolRot = [-55, 0, 0];
  } else if (pose === 'dig') {
    armR.rotation.set(rad(50), rad(-10), rad(8));
    armL.rotation.set(rad(60), rad(10), rad(-18));
    root.rotation.x = rad(-6);
    defaultToolRot = [-13, 0, 0];
  } else if (pose === 'cheer') {
    armR.rotation.set(rad(160), 0, rad(32));
    armL.rotation.set(rad(155), 0, rad(-30));
    head.rotation.x = rad(8);
    defaultToolRot = [0, 0, 0];
  } else if (pose === 'brace') {
    armL.rotation.set(rad(115), rad(-25), rad(-25));
    armR.rotation.set(rad(40), 0, rad(12));
    head.rotation.set(rad(-10), rad(-10), 0);
    root.rotation.z = rad(-6);
    defaultToolRot = [-20, 0, 0];
  } else if (pose === 'point') {
    armR.rotation.set(rad(95), rad(10), rad(5));
    armL.rotation.set(rad(10), 0, rad(-10));
  } else if (pose === 'shoulder') {
    armR.rotation.set(rad(150), rad(10), rad(-25));
    armL.rotation.set(rad(20), 0, rad(-10));
    defaultToolRot = [-150, 0, 0];
  }

  if (tool) {
    const tr = toolRot ?? defaultToolRot;
    tool.rotation.set(rad(tr[0]), rad(tr[1]), rad(tr[2]));
    handR.add(tool);
  }
  root.userData = { head, armL, armR, handR, handL };
  return root;
}

// ---------------------------------------------------------------- nástroje (staví se podél +Y, úchop v 0)
function spadeShape(w, h) {
  const s = new THREE.Shape();
  s.moveTo(-w / 2, 0);
  s.lineTo(w / 2, 0);
  s.lineTo(w / 2, -h * 0.65);
  s.quadraticCurveTo(w / 2, -h, 0, -h * 1.12);
  s.quadraticCurveTo(-w / 2, -h, -w / 2, -h * 0.65);
  s.closePath();
  return s;
}

export function shovel({ golden = false } = {}) {
  const g = new THREE.Group();
  const shaftColor = golden ? 0x5a3418 : COL.wood;
  const bladeColor = golden ? COL.gold : 0x8f99a6;
  const metalOpt = { metal: golden ? 0.55 : 0.8, rough: golden ? 0.3 : 0.35, emissive: golden ? 0x9a5c00 : 0, ei: golden ? 0.55 : 1 };
  const shaft = cyl(0.14, 0.14, 4.6, shaftColor, {}, 16); shaft.position.y = -1.0; g.add(shaft);
  const grip = rbox(0.9, 0.22, 0.22, 0.08, golden ? COL.gold : 0x2a2a2a, golden ? metalOpt : {}); grip.position.y = 1.35; g.add(grip);
  const gripL = rbox(0.16, 0.6, 0.16, 0.06, golden ? COL.gold : 0x2a2a2a, golden ? metalOpt : {}); gripL.position.set(-0.38, 1.05, 0); gripL.rotation.z = 0.25; g.add(gripL);
  const gripR = gripL.clone(); gripR.position.x = 0.38; gripR.rotation.z = -0.25; g.add(gripR);
  const collar = cyl(0.22, 0.26, 0.5, golden ? COL.gold : 0x666d77, metalOpt, 16); collar.position.y = -3.3; g.add(collar);
  const blade = shadowed(new THREE.Mesh(
    new THREE.ExtrudeGeometry(spadeShape(1.5, 1.9), { depth: 0.1, bevelEnabled: true, bevelThickness: 0.04, bevelSize: 0.05, bevelSegments: 2 }),
    mat(bladeColor, metalOpt),
  ));
  blade.position.set(0, -3.45, -0.05);
  g.add(blade);
  if (golden) {
    const gem = shadowed(new THREE.Mesh(new THREE.OctahedronGeometry(0.28), mat(COL.cyan, { emissive: COL.cyan, ei: 1.4 })));
    gem.position.set(0, -4.1, -0.12);
    g.add(gem);
  }
  return g;
}

export function spoon() {
  const g = new THREE.Group();
  const m = { metal: 0.9, rough: 0.25 };
  const h = rbox(0.28, 2.2, 0.1, 0.05, COL.metal, m); h.position.y = -0.6; g.add(h);
  const bowl = sphere(0.55, COL.metal, m); bowl.scale.set(0.85, 1.15, 0.3); bowl.position.y = -2.2; g.add(bowl);
  return g;
}

export function trowel() {
  const g = new THREE.Group();
  const h = rbox(0.35, 1.3, 0.35, 0.12, 0xd8452f); h.position.y = 0; g.add(h);
  const n = cyl(0.06, 0.06, 0.6, COL.metal, { metal: 0.9, rough: 0.3 }); n.position.y = -0.9; g.add(n);
  const blade = shadowed(new THREE.Mesh(new THREE.ExtrudeGeometry(spadeShape(0.95, 1.4), { depth: 0.06, bevelEnabled: false }), mat(COL.metal, { metal: 0.9, rough: 0.3 })));
  blade.position.y = -1.15; g.add(blade);
  return g;
}

export function vacuum() {
  const g = new THREE.Group();
  const body = rbox(1.1, 1.5, 1.2, 0.25, 0xf0582c, { rough: 0.4 }); body.position.y = 0.2; g.add(body);
  const stripe = rbox(1.14, 0.22, 1.24, 0.08, 0x2c2c33); stripe.position.y = 0.5; g.add(stripe);
  const tank = cyl(0.42, 0.42, 1.1, 0xbfe8ff, { opacity: 0.55, rough: 0.1 }); tank.position.set(0, 0.25, 0.7); tank.rotation.x = Math.PI / 2; g.add(tank);
  const sandIn = cyl(0.36, 0.36, 0.6, COL.sand); sandIn.position.set(0, 0.1, 0.7); sandIn.rotation.x = Math.PI / 2; g.add(sandIn);
  const tube = cyl(0.22, 0.22, 3.4, 0x2c2c33, { rough: 0.5 }); tube.position.y = -2.0; g.add(tube);
  for (let i = 0; i < 6; i++) { const r = cyl(0.26, 0.26, 0.12, 0x44444c); r.position.y = -1.0 - i * 0.45; g.add(r); }
  const nozzle = rbox(1.5, 0.4, 0.55, 0.12, 0x1c1c1f); nozzle.position.y = -3.8; g.add(nozzle);
  const ring = shadowed(new THREE.Mesh(new THREE.TorusGeometry(0.3, 0.07, 10, 24), mat(COL.cyan, { emissive: COL.cyan, ei: 1.6 })));
  ring.rotation.x = Math.PI / 2; ring.position.y = -3.4; g.add(ring);
  return g;
}

export function claw() {
  const g = new THREE.Group();
  const yel = 0xffc21a;
  const m = { metal: 0.3, rough: 0.45 };
  const arm = rbox(0.7, 5.2, 0.7, 0.12, yel, m); arm.position.y = -1.6; g.add(arm);
  const piston = cyl(0.16, 0.16, 3.2, COL.metal, { metal: 0.9, rough: 0.2 }); piston.position.set(0, -1.6, 0.55); g.add(piston);
  const stripe = rbox(0.74, 0.5, 0.74, 0.08, 0x222222); stripe.position.y = 0.3; g.add(stripe);
  const joint = cyl(0.5, 0.5, 1, 0x333338, m); joint.rotation.z = Math.PI / 2; joint.position.y = -4.3; g.add(joint);
  const bucket = new THREE.Group(); bucket.position.y = -4.6; g.add(bucket);
  const back = rbox(3.2, 0.3, 2.0, 0.08, yel, m); back.position.set(0, -0.15, 0); bucket.add(back);
  const bottom = rbox(3.2, 2.0, 0.3, 0.08, yel, m); bottom.position.set(0, -1.1, -0.9); bucket.add(bottom);
  const sideL = rbox(0.3, 2.0, 2.0, 0.08, yel, m); sideL.position.set(-1.5, -1.1, 0); bucket.add(sideL);
  const sideR = sideL.clone(); sideR.position.x = 1.5; bucket.add(sideR);
  for (let i = -2; i <= 2; i++) {
    const t = shadowed(new THREE.Mesh(new THREE.ConeGeometry(0.2, 0.7, 4), mat(0x333338, m)));
    t.position.set(i * 0.62, -2.35, -0.9); t.rotation.x = Math.PI; bucket.add(t);
  }
  const sandLoad = sphere(1.25, COL.sand); sandLoad.scale.set(1.15, 0.6, 0.85); sandLoad.position.set(0, -0.9, 0.05); bucket.add(sandLoad);
  return g;
}

// ---------------------------------------------------------------- truhla
export function chest({ color = COL.legendary, open = false, scale = 1, glowColor = null, coins = true } = {}) {
  const g = new THREE.Group();
  const trim = { metal: 0.9, rough: 0.25 };
  const base = rbox(3, 1.8, 2, 0.12, color, { rough: 0.55 }); base.position.y = 0.9; g.add(base);
  for (const x of [-1.2, 1.2]) { const b = rbox(0.28, 1.86, 2.06, 0.06, COL.gold, trim); b.position.set(x, 0.9, 0); g.add(b); }
  const band = rbox(3.06, 0.24, 2.06, 0.06, COL.gold, trim); band.position.y = 1.72; g.add(band);
  const lidPivot = new THREE.Group(); lidPivot.position.set(0, 1.8, 1); g.add(lidPivot);
  const lid = shadowed(new THREE.Mesh(new THREE.CylinderGeometry(1, 1, 3, 24, 1, false, 0, Math.PI), mat(color, { rough: 0.55 })));
  lid.rotation.z = Math.PI / 2; lid.position.set(0, 0, -1); lidPivot.add(lid);
  for (const x of [-1.2, 1.2]) {
    const lb = shadowed(new THREE.Mesh(new THREE.CylinderGeometry(1.03, 1.03, 0.28, 24, 1, false, 0, Math.PI), mat(COL.gold, trim)));
    lb.rotation.z = Math.PI / 2; lb.position.set(x, 0, -1); lidPivot.add(lb);
  }
  const lock = rbox(0.5, 0.6, 0.2, 0.08, COL.gold, { ...trim, emissive: 0x8a5a00, ei: 0.4 }); lock.position.set(0, 1.55, -1.08); g.add(lock);
  if (open) {
    lidPivot.rotation.x = THREE.MathUtils.degToRad(-105);
    if (coins) {
      const pile = sphere(1.25, COL.gold, { metal: 0.9, rough: 0.3, emissive: 0xffa000, ei: 0.35 });
      pile.scale.set(1.15, 0.55, 0.75); pile.position.y = 1.75; g.add(pile);
      for (let i = 0; i < 9; i++) {
        const c = coin(0.38); c.position.set(-1 + Math.random() * 2, 1.9 + Math.random() * 0.4, -0.6 + Math.random() * 1.2);
        c.rotation.set(Math.random() * 3, Math.random() * 3, Math.random() * 3); g.add(c);
      }
    }
    const light = new THREE.PointLight(glowColor ?? 0xffc040, 14, 12, 1.8); light.position.set(0, 3, -0.5); g.add(light);
    const gl = glow(glowColor ?? 0xffd060, 6, 0.65); gl.position.set(0, 2.6, 0); g.add(gl);
  } else if (glowColor) {
    const gl = glow(glowColor, 8, 0.7); gl.position.set(0, 1.4, 0); g.add(gl);
  }
  g.scale.setScalar(scale);
  return g;
}

export function coin(r = 0.5) {
  const m = shadowed(new THREE.Mesh(new THREE.CylinderGeometry(r, r, r * 0.22, 28), mat(COL.gold, { metal: 0.95, rough: 0.25, emissive: 0xb06a00, ei: 0.35 })));
  const inner = shadowed(new THREE.Mesh(new THREE.CylinderGeometry(r * 0.7, r * 0.7, r * 0.26, 28), mat(0xffdc5a, { metal: 0.9, rough: 0.3, emissive: 0xb06a00, ei: 0.3 })));
  m.add(inner);
  return m;
}

export function coinRain(count, center, spread, size = [0.4, 0.8], seed = 5) {
  const g = new THREE.Group();
  let s = seed;
  const rnd = () => ((s = (s * 16807) % 2147483647) / 2147483647);
  for (let i = 0; i < count; i++) {
    const c = coin(size[0] + rnd() * (size[1] - size[0]));
    c.position.set(center.x + (rnd() - 0.5) * spread.x, center.y + (rnd() - 0.5) * spread.y, center.z + (rnd() - 0.5) * spread.z);
    c.rotation.set(rnd() * 6, rnd() * 6, rnd() * 6);
    g.add(c);
  }
  return g;
}

export function gem(color = COL.mythic, size = 1.2) {
  const g = new THREE.Group();
  const m = shadowed(new THREE.Mesh(new THREE.OctahedronGeometry(size, 0), mat(color, { emissive: color, ei: 1.3, rough: 0.15, metal: 0.3, flat: true })));
  m.scale.set(0.8, 1.35, 0.8);
  g.add(m);
  const gl = glow(color, size * 9, 0.9); g.add(gl);
  const light = new THREE.PointLight(color, 60, 25, 1.5); g.add(light);
  return g;
}

// ---------------------------------------------------------------- ruiny
export function ruins({ ring = 14, pillars = 8, height = 12, broken = [2, 5], runes = true, head = true } = {}) {
  const g = new THREE.Group();
  const tops = [];
  for (let i = 0; i < pillars; i++) {
    const a = (i / pillars) * Math.PI * 2;
    const isBroken = broken.includes(i);
    const h = isBroken ? height * 0.45 : height;
    const x = Math.cos(a) * ring, z = Math.sin(a) * ring;
    const p = cyl(1.3, 1.45, h, COL.stone, { rough: 0.9 }, 12); p.position.set(x, h / 2, z); g.add(p);
    // drážky
    for (let k = 0; k < 3; k++) { const band = cyl(1.42, 1.42, 0.35, COL.stoneDark, { rough: 0.9 }, 12); band.position.set(x, h * (0.2 + k * 0.3), z); g.add(band); }
    const cap = rbox(3.6, 0.9, 3.6, 0.1, COL.stoneDark, { rough: 0.9 }); cap.position.set(x, h + 0.45, z); g.add(cap);
    if (isBroken) { cap.rotation.set(0.25, 0.4, 0.15); tops.push(null); } else tops.push(new THREE.Vector3(x, h + 1.4, z));
  }
  for (let i = 0; i < pillars; i++) {
    const a = tops[i], b = tops[(i + 1) % pillars];
    if (a && b) {
      const mid = a.clone().add(b).multiplyScalar(0.5);
      const len = a.distanceTo(b) + 2.5;
      const l = rbox(2.4, 1.4, len, 0.1, COL.stone, { rough: 0.9 });
      l.position.copy(mid); l.lookAt(b); g.add(l);
    }
  }
  // oltář
  const step = rbox(10, 1.2, 10, 0.1, COL.stoneDark, { rough: 0.9 }); step.position.y = 0.6; g.add(step);
  const altar = rbox(6, 2.6, 6, 0.12, 0xf0dcb0, { rough: 0.7 }); altar.position.y = 2.5; g.add(altar);
  if (runes) {
    for (const [x, z, ry] of [[0, -3.02, 0], [0, 3.02, 0], [-3.02, 0, Math.PI / 2], [3.02, 0, Math.PI / 2]]) {
      const r = rbox(4.2, 0.4, 0.08, 0.04, COL.cyan, { emissive: COL.cyan, ei: 2.2 }); r.position.set(x, 2.6, z); r.rotation.y = ry; g.add(r);
      for (let k = -1; k <= 1; k++) {
        const glyph = rbox(0.4, 0.7, 0.08, 0.04, COL.cyan, { emissive: COL.cyan, ei: 2.2 });
        const off = new THREE.Vector3(k * 1.2, 1.6, 0).applyAxisAngle(new THREE.Vector3(0, 1, 0), ry);
        glyph.position.set(x + off.x, off.y + 0.2, z + off.z); glyph.rotation.y = ry; g.add(glyph);
      }
    }
    const l = new THREE.PointLight(COL.cyan, 50, 30, 1.6); l.position.set(0, 4, 0); g.add(l);
  }
  if (head) {
    const hd = new THREE.Group(); hd.position.set(5, 2, 8); hd.rotation.y = -0.35; g.add(hd);
    const face = rbox(5, 6, 5, 0.4, COL.stone, { rough: 0.9 }); face.position.y = 3.5; hd.add(face);
    const dress = rbox(7, 3, 6, 0.3, 0x2f6fd1, { rough: 0.7 }); dress.position.set(0, 7.2, 0.4); hd.add(dress);
    for (let k = -1; k <= 1; k++) { const s = rbox(7.1, 0.45, 6.1, 0.1, COL.gold, { metal: 0.7, rough: 0.35 }); s.position.set(0, 6.6 + k * 0.9, 0.4); hd.add(s); }
    for (const x of [-1.1, 1.1]) { const e = rbox(1, 0.45, 0.2, 0.1, COL.gold, { emissive: 0xffb000, ei: 2 }); e.position.set(x, 4.3, -2.55); hd.add(e); }
    const nose = rbox(0.9, 1.4, 0.6, 0.2, COL.stoneDark); nose.position.set(0, 3.4, -2.6); hd.add(nose);
  }
  return g;
}

// ---------------------------------------------------------------- podstavec
export function podium(color, r = 3, h = 1.4) {
  const g = new THREE.Group();
  const base = cyl(r, r * 1.1, h, 0xe9cf9b, { rough: 0.85 }, 40); base.position.y = h / 2; g.add(base);
  const rim = shadowed(new THREE.Mesh(new THREE.TorusGeometry(r * 1.02, 0.14, 10, 48), mat(color, { emissive: color, ei: 1.6 })));
  rim.rotation.x = Math.PI / 2; rim.position.y = h; g.add(rim);
  const gl = glow(color, r * 2.6, 0.3); gl.position.y = h + 1; g.add(gl);
  return g;
}

// ---------------------------------------------------------------- render
export function setup(width, height, { fov = 40, bloom = 0.3, bloomRadius = 0.45, bloomThreshold = 0.95, exposure = 0.9, fog = null, env = 0.25 } = {}) {
  const renderer = new THREE.WebGLRenderer({ antialias: true, preserveDrawingBuffer: true });
  renderer.setPixelRatio(1);
  renderer.setSize(width, height);
  renderer.shadowMap.enabled = true;
  renderer.shadowMap.type = THREE.PCFSoftShadowMap;
  renderer.toneMapping = THREE.NeutralToneMapping;
  renderer.toneMappingExposure = exposure;
  document.getElementById('stage').appendChild(renderer.domElement);

  const scene = new THREE.Scene();
  const pmrem = new THREE.PMREMGenerator(renderer);
  scene.environment = pmrem.fromScene(new RoomEnvironment(), 0.04).texture;
  scene.environmentIntensity = env;
  if (fog) scene.fog = new THREE.Fog(fog.color, fog.near, fog.far);
  const camera = new THREE.PerspectiveCamera(fov, width / height, 0.5, 4000);

  const composer = new EffectComposer(renderer, new THREE.WebGLRenderTarget(width, height, { type: THREE.HalfFloatType, samples: 4 }));
  composer.addPass(new RenderPass(scene, camera));
  if (bloom > 0) composer.addPass(new UnrealBloomPass(new THREE.Vector2(width, height), bloom, bloomRadius, bloomThreshold));
  composer.addPass(new OutputPass());
  return { renderer, scene, camera, composer };
}

export function lights(scene, { sun = new THREE.Vector3(40, 60, -30), sunColor = 0xfff1d6, sunI = 3.2, hemiSky = 0xbfe3ff, hemiGround = 0xf0c27a, hemiI = 0.35, shadowSize = 60, target = new THREE.Vector3() } = {}) {
  const hemi = new THREE.HemisphereLight(hemiSky, hemiGround, hemiI);
  scene.add(hemi);
  const dir = new THREE.DirectionalLight(sunColor, sunI);
  dir.position.copy(target).add(sun);
  dir.target.position.copy(target);
  dir.castShadow = true;
  dir.shadow.mapSize.set(4096, 4096);
  const s = shadowSize;
  Object.assign(dir.shadow.camera, { left: -s, right: s, top: s, bottom: -s, near: 1, far: 400 });
  dir.shadow.bias = -0.0004;
  dir.shadow.normalBias = 0.03;
  scene.add(dir, dir.target);
  return { hemi, dir };
}

// Projekce 3D bodu na pixel obrazovky (pro popisky v HTML)
export function project(camera, v, width, height) {
  const p = v.clone().project(camera);
  return { x: (p.x * 0.5 + 0.5) * width, y: (-p.y * 0.5 + 0.5) * height };
}
