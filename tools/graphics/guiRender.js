// Vykreslí exportovaný strom Roblox GUI (z mocku) do HTML – náhled UI.
import * as THREE from 'three';

const GUI_CLASSES = new Set(['Frame', 'TextLabel', 'TextButton', 'TextBox', 'ScrollingFrame', 'ViewportFrame', 'ImageLabel', 'ImageButton']);
const FONTS = {
  LuckiestGuy: "'Luckiest Guy', 'Noto Color Emoji', sans-serif",
  FredokaOne: "'Fredoka', 'Noto Color Emoji', sans-serif",
  GothamMedium: "'Liberation Sans', 'Noto Color Emoji', sans-serif",
};
const FONT_WEIGHT = { FredokaOne: 700, LuckiestGuy: 400, GothamMedium: 600 };

const rgb = (c, a = 1) => `rgba(${Math.round(c[0] * 255)},${Math.round(c[1] * 255)},${Math.round(c[2] * 255)},${a})`;
const mul = (a, b) => [a[0] * b[0], a[1] * b[1], a[2] * b[2]];
const udim2 = (u, pw, ph) => (u ? { x: u.xs * pw + u.xo, y: u.ys * ph + u.yo } : { x: 100, y: 100 });

function mods(node) {
  const m = {};
  for (const k of node.k) {
    if (GUI_CLASSES.has(k.c)) continue;
    if (k.c === 'UIStroke') {
      if ((k.p.ApplyStrokeMode ?? 'Contextual') === 'Border') m.BorderStroke = k.p;
      else m.TextStroke = k.p;
    } else {
      m[k.c] = k.p;
    }
  }
  return m;
}

function guiChildren(node) {
  return node.k.filter((k) => GUI_CLASSES.has(k.c) && k.p.Visible !== false);
}

const textJobs = [];
const viewportJobs = [];

function layoutNode(node, parentEl, pw, ph, forced) {
  const p = node.p;
  const m = mods(node);
  const isText = node.c === 'TextLabel' || node.c === 'TextButton' || node.c === 'TextBox';
  let size = forced?.size ?? udim2(p.Size, pw, ph);
  let pos;
  if (forced?.pos) {
    pos = forced.pos;
  } else {
    const ap = p.AnchorPoint ?? [0, 0];
    const pp = udim2(p.Position ?? { xs: 0, xo: 0, ys: 0, yo: 0 }, pw, ph);
    pos = { x: pp.x - ap[0] * size.x, y: pp.y - ap[1] * size.y };
  }
  const el = document.createElement('div');
  el.style.position = 'absolute';
  el.style.left = pos.x + 'px';
  el.style.top = pos.y + 'px';
  el.style.width = size.x + 'px';
  el.style.height = size.y + 'px';
  el.style.zIndex = p.ZIndex ?? 1;
  el.style.boxSizing = 'border-box';
  parentEl.appendChild(el);

  // pozadí (+ UIGradient násobí barvu)
  const bgT = p.BackgroundTransparency ?? 0;
  const bg = p.BackgroundColor3 ?? [163 / 255, 162 / 255, 165 / 255];
  const grad = m.UIGradient;
  if (bgT < 1) {
    if (grad && grad.Color && !isText) {
      const angle = (grad.Rotation ?? 0) + 90;
      el.style.background = `linear-gradient(${angle}deg, ${rgb(mul(bg, grad.Color[0]), 1 - bgT)}, ${rgb(mul(bg, grad.Color[1]), 1 - bgT)})`;
    } else {
      el.style.background = rgb(bg, 1 - bgT);
    }
  }
  if (m.UICorner) {
    const r = m.UICorner.CornerRadius;
    el.style.borderRadius = Math.min((r?.o ?? 8) + (r?.s ?? 0) * Math.min(size.x, size.y), Math.min(size.x, size.y) / 2) + 'px';
  }
  const border = m.BorderStroke ?? (!isText ? m.TextStroke : null);
  if (border) {
    el.style.boxShadow = `0 0 0 ${border.Thickness ?? 1}px ${rgb(border.Color ?? [0, 0, 0])}`;
  }
  const stroke = isText ? m.TextStroke : null;
  if (p.Rotation) el.style.transform = `rotate(${p.Rotation}deg)`;
  if (m.UIScale && m.UIScale.Scale !== undefined && m.UIScale.Scale !== 1) {
    const ap = p.AnchorPoint ?? [0, 0];
    el.style.transformOrigin = `${ap[0] * 100}% ${ap[1] * 100}%`;
    el.style.transform = (el.style.transform || '') + ` scale(${m.UIScale.Scale})`;
  }
  if (node.c === 'ScrollingFrame') el.style.overflow = 'hidden';

  // text
  if (isText) {
    let text = p.Text ?? '';
    let color = p.TextColor3 ?? [0, 0, 0];
    if (node.c === 'TextBox' && !text) {
      text = p.PlaceholderText ?? '';
      color = p.PlaceholderColor3 ?? [0.5, 0.5, 0.5];
    }
    if (text) {
      const span = document.createElement('div');
      span.textContent = text;
      const font = p.Font ?? 'FredokaOne';
      Object.assign(span.style, {
        position: 'absolute', inset: '0', display: 'flex', whiteSpace: 'pre-wrap', wordBreak: 'normal', overflowWrap: 'normal',
        fontFamily: FONTS[font] ?? FONTS.FredokaOne, fontWeight: FONT_WEIGHT[font] ?? 600, lineHeight: '1.05',
        color: rgb(color, 1 - (p.TextTransparency ?? 0)),
        justifyContent: { Left: 'flex-start', Right: 'flex-end' }[p.TextXAlignment] ?? 'center',
        textAlign: { Left: 'left', Right: 'right' }[p.TextXAlignment] ?? 'center',
        alignItems: { Top: 'flex-start', Bottom: 'flex-end' }[p.TextYAlignment] ?? 'center',
      });
      const pad = m.UIPadding;
      if (pad) {
        span.style.left = (pad.PaddingLeft?.o ?? 0) + 'px';
        span.style.right = (pad.PaddingRight?.o ?? 0) + 'px';
        span.style.top = (pad.PaddingTop?.o ?? 0) + 'px';
        span.style.bottom = (pad.PaddingBottom?.o ?? 0) + 'px';
      }
      if (stroke) {
        span.style.webkitTextStroke = `${(stroke.Thickness ?? 1) * 2}px ${rgb(stroke.Color ?? [0, 0, 0])}`;
        span.style.paintOrder = 'stroke fill';
      }
      if (grad && grad.Color && stroke) {
        // obrys pod textem s přechodem (jinak by přes výplň přerostl)
        const under = span.cloneNode(true);
        under.style.color = rgb(stroke.Color ?? [0, 0, 0]);
        el.appendChild(under);
        textJobs.push({ span: under, max: 100 });
        span.style.webkitTextStroke = '0';
      }
      if (grad && grad.Color) {
        span.style.background = `linear-gradient(${(grad.Rotation ?? 0) + 90}deg, ${rgb(mul(color, grad.Color[0]))}, ${rgb(mul(color, grad.Color[1]))})`;
        span.style.webkitBackgroundClip = 'text';
        span.style.backgroundClip = 'text';
        span.style.color = 'transparent';
      }
      el.appendChild(span);
      if (p.TextScaled) textJobs.push({ span, max: 100 });
      else span.style.fontSize = (p.TextSize ?? 14) + 'px';
      if (p.AutomaticSize === 'X') {
        span.style.position = 'relative';
        span.style.whiteSpace = 'nowrap';
        span.style.height = '100%';
        el.style.width = 'auto';
      }
    }
  }

  // obsah (padding, layouty)
  const pad = m.UIPadding;
  const inner = {
    l: pad?.PaddingLeft?.o ?? 0, r: pad?.PaddingRight?.o ?? 0, t: pad?.PaddingTop?.o ?? 0, b: pad?.PaddingBottom?.o ?? 0,
  };
  const content = document.createElement('div');
  Object.assign(content.style, { position: 'absolute', left: inner.l + 'px', top: inner.t + 'px', right: inner.r + 'px', bottom: inner.b + 'px' });
  el.appendChild(content);
  const cw = Math.max(0, size.x - inner.l - inner.r);
  const ch = Math.max(0, size.y - inner.t - inner.b);

  const kids = guiChildren(node).map((k, i) => ({ k, i }));
  kids.sort((a, b) => ((a.k.p.LayoutOrder ?? 0) - (b.k.p.LayoutOrder ?? 0)) || a.i - b.i);
  let extentY = 0;
  if (m.UIGridLayout) {
    const g = m.UIGridLayout;
    const cell = udim2(g.CellSize, cw, ch);
    const gap = udim2(g.CellPadding ?? { xs: 0, xo: 5, ys: 0, yo: 5 }, cw, ch);
    const perRow = Math.max(1, Math.floor((cw + gap.x) / (cell.x + gap.x)));
    kids.forEach(({ k }, i) => {
      const col = i % perRow, row = Math.floor(i / perRow);
      const pos = { x: col * (cell.x + gap.x), y: row * (cell.y + gap.y) };
      layoutNode(k, content, cw, ch, { size: cell, pos });
      extentY = Math.max(extentY, pos.y + cell.y);
    });
  } else if (m.UIListLayout) {
    const l = m.UIListLayout;
    const horizontal = l.FillDirection === 'Horizontal';
    const gap = l.Padding?.o ?? 0;
    let cursor = 0;
    kids.forEach(({ k }) => {
      const s = udim2(k.p.Size, cw, ch);
      let x = horizontal ? cursor : 0;
      let y = horizontal ? 0 : cursor;
      if (!horizontal && l.HorizontalAlignment === 'Center') x = (cw - s.x) / 2;
      if (!horizontal && l.HorizontalAlignment === 'Right') x = cw - s.x;
      const childEl = layoutNode(k, content, cw, ch, { size: s, pos: { x, y } });
      const real = k.p.AutomaticSize === 'X' ? null : s;
      cursor += (horizontal ? (real ? real.x : 0) : s.y) + gap;
      if (horizontal && !real) {
        childEl.dataset.autoflow = '1';
      }
      extentY = Math.max(extentY, y + s.y);
    });
    if (horizontal && content.querySelector(':scope > [data-autoflow]')) content.dataset.hflow = String(gap);
  } else {
    kids.forEach(({ k }) => layoutNode(k, content, cw, ch));
  }
  if (p.AutomaticSize === 'Y' && extentY > size.y) {
    el.style.height = extentY + inner.t + inner.b + 'px';
  }
  if (node.c === 'ViewportFrame') viewportJobs.push({ node, el, size });
  return el;
}

// Horizontální řádky s automatickou šířkou (čipy) – přepočet po změření textu
function reflowHorizontal(root) {
  root.querySelectorAll('[data-hflow]').forEach((content) => {
    const gap = Number(content.dataset.hflow);
    let x = 0;
    [...content.children].forEach((child) => {
      if (child.style.display === 'none') return;
      child.style.left = x + 'px';
      x += child.getBoundingClientRect().width / currentScale + gap;
    });
  });
}
let currentScale = 1;

function fitText() {
  for (const job of textJobs) {
    const span = job.span;
    let lo = 4, hi = job.max;
    const box = span.getBoundingClientRect();
    if (box.width < 2 || box.height < 2) continue;
    hi = Math.min(hi, box.height / currentScale);
    while (hi - lo > 0.5) {
      const mid = (lo + hi) / 2;
      span.style.fontSize = mid + 'px';
      if (span.scrollWidth <= span.clientWidth + 1 && span.scrollHeight <= span.clientHeight + 1) lo = mid;
      else hi = mid;
    }
    span.style.fontSize = lo + 'px';
  }
}

// 3D náhledy nástrojů ve ViewportFrame
function renderViewports() {
  if (!viewportJobs.length) return;
  const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: true, preserveDrawingBuffer: true });
  for (const job of viewportJobs) {
    const parts = [];
    const collect = (n) => { if (n.part) parts.push(n.part); n.k.forEach(collect); };
    collect(job.node);
    if (!parts.length) continue;
    const w = Math.max(2, Math.round(job.size.x * 2)), h = Math.max(2, Math.round(job.size.y * 2));
    renderer.setSize(w, h);
    const scene = new THREE.Scene();
    scene.add(new THREE.HemisphereLight(0xfff4e0, 0x806040, 1.6));
    const dir = new THREE.DirectionalLight(0xffffff, 2.2); dir.position.set(-3, 5, -4); scene.add(dir);
    const group = new THREE.Group();
    for (const p of parts) {
      if (p.t >= 1) continue;
      group.add(partMesh(p));
    }
    scene.add(group);
    const box = new THREE.Box3().setFromObject(group);
    const center = box.getCenter(new THREE.Vector3());
    const radius = box.getSize(new THREE.Vector3()).length() / 2;
    const camera = new THREE.PerspectiveCamera(32, w / h, 0.1, 500);
    const dist = radius / Math.sin(THREE.MathUtils.degToRad(16)) * 0.95;
    camera.position.copy(center).add(new THREE.Vector3(dist * 0.55, dist * 0.35, -dist * 0.75));
    camera.lookAt(center);
    renderer.render(scene, camera);
    const img = document.createElement('img');
    img.src = renderer.domElement.toDataURL();
    Object.assign(img.style, { position: 'absolute', inset: '0', width: '100%', height: '100%' });
    job.el.appendChild(img);
  }
}

export function partMesh(p) {
  let geo;
  const [sx, sy, sz] = p.s;
  if (p.sh === 'Cylinder') {
    geo = new THREE.CylinderGeometry(sy / 2, sy / 2, sx, 28);
    geo.rotateZ(-Math.PI / 2);
  } else if (p.sh === 'Ball') {
    geo = new THREE.SphereGeometry(Math.min(sx, sy, sz) / 2, 24, 16);
  } else if (p.sp) {
    geo = new THREE.SphereGeometry(0.5, 24, 16);
    geo.scale(sx, sy, sz);
  } else {
    geo = new THREE.BoxGeometry(sx, sy, sz);
  }
  const color = new THREE.Color(p.col[0], p.col[1], p.col[2]);
  const opts = { color, roughness: 0.75, metalness: 0 };
  if (p.m === 'Neon') Object.assign(opts, { emissive: color, emissiveIntensity: 1.6, roughness: 0.4 });
  if (p.m === 'Metal') Object.assign(opts, { metalness: 0.7, roughness: 0.3 });
  if (p.m === 'Marble') Object.assign(opts, { roughness: 0.35 });
  if (p.m === 'Glass') Object.assign(opts, { transparent: true, opacity: 0.45, roughness: 0.1 });
  if (p.m === 'ForceField') Object.assign(opts, { transparent: true, opacity: 0.35, emissive: color, emissiveIntensity: 1 });
  if (p.t > 0) Object.assign(opts, { transparent: true, opacity: Math.min(opts.opacity ?? 1, 1 - p.t) });
  const mesh = new THREE.Mesh(geo, new THREE.MeshStandardMaterial(opts));
  const c = p.cf;
  const m4 = new THREE.Matrix4().set(c[3], c[4], c[5], c[0], c[6], c[7], c[8], c[1], c[9], c[10], c[11], c[2], 0, 0, 0, 1);
  mesh.matrixAutoUpdate = false;
  mesh.matrix.copy(m4);
  mesh.castShadow = true;
  mesh.receiveShadow = true;
  mesh.userData.material = p.m;
  return mesh;
}

// Napodobení základního UI Robloxu (horní lišta, seznam hráčů, hotbar)
function robloxChrome(stage, W, H, state) {
  const add = (css, html = '') => { const d = document.createElement('div'); d.innerHTML = html; Object.assign(d.style, { position: 'absolute', zIndex: 900 }, css); stage.appendChild(d); return d; };
  const circle = (left) => add({ left: left + 'px', top: '12px', width: '44px', height: '44px', borderRadius: '12px', background: 'rgba(25,27,29,0.6)' });
  circle(14); circle(66);
  if (state.leaderstats) {
    add({ right: '14px', top: '12px', width: '300px', borderRadius: '10px', background: 'rgba(25,27,29,0.6)', color: '#fff', font: "600 17px 'Liberation Sans'", padding: '8px 12px', boxSizing: 'border-box' },
      `<div style="display:flex;justify-content:space-between;opacity:.75;font-size:14px"><span>People</span><span>Coins &nbsp; Rebirths</span></div><div style="display:flex;justify-content:space-between;margin-top:6px"><span>Tester</span><span>${state.leaderstats}</span></div>`);
  }
  if (state.tool) {
    add({ left: '50%', bottom: '12px', transform: 'translateX(-50%)', width: '64px', height: '64px', borderRadius: '10px', background: 'rgba(25,27,29,0.6)', border: '2px solid #fff', color: '#fff', font: "600 12px 'Liberation Sans'", display: 'flex', alignItems: 'center', justifyContent: 'center', textAlign: 'center' }, `<span><b style="position:absolute;left:6px;top:4px">1</b>${state.tool}</span>`);
  }
}

function normalize(node) {
  if (!Array.isArray(node.k)) node.k = [];
  if (!node.p || Array.isArray(node.p)) node.p = {};
  node.k.forEach(normalize);
}

export async function renderGuiTree(tree, W, H, chrome = {}) {
  normalize(tree);
  textJobs.length = 0;
  viewportJobs.length = 0;
  const stage = document.getElementById('overlay');
  const scaleNode = tree.k.find((k) => k.c === 'UIScale');
  const inset = 58;
  const scale = scaleNode?.p?.Scale ?? Math.min(Math.max(Math.min(W / 1280, (H - inset) / 720), 0.5), 1.5);
  currentScale = scale;
  const screen = document.createElement('div');
  const vw = W / scale, vh = (H - inset) / scale;
  Object.assign(screen.style, { position: 'absolute', left: '0', top: inset + 'px', width: vw + 'px', height: vh + 'px', transform: `scale(${scale})`, transformOrigin: '0 0' });
  stage.appendChild(screen);
  for (const k of guiChildren(tree)) layoutNode(k, screen, vw, vh);
  await document.fonts.ready;
  fitText();
  reflowHorizontal(screen);
  renderViewports();
  robloxChrome(stage, W, H, chrome);
}
