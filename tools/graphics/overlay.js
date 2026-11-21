// 2D vrstva nad 3D scénou: herní nadpisy (SVG), štítky a odznaky (HTML)
const NS = 'http://www.w3.org/2000/svg';
let uid = 0;

export function createOverlay(W, H) {
  const wrap = document.getElementById('wrap');
  wrap.style.width = W + 'px';
  wrap.style.height = H + 'px';
  const root = document.getElementById('overlay');
  root.style.width = W + 'px';
  root.style.height = H + 'px';
  const svg = document.createElementNS(NS, 'svg');
  svg.setAttribute('width', W);
  svg.setAttribute('height', H);
  svg.setAttribute('viewBox', `0 0 ${W} ${H}`);
  svg.style.position = 'absolute';
  svg.style.inset = '0';
  const defs = document.createElementNS(NS, 'defs');
  svg.appendChild(defs);
  root.appendChild(svg);
  return { root, svg, defs, W, H };
}

function el(tag, attrs = {}, parent) {
  const e = document.createElementNS(NS, tag);
  for (const [k, v] of Object.entries(attrs)) e.setAttribute(k, v);
  if (parent) parent.appendChild(e);
  return e;
}

function gradient(ov, stops, vertical = true) {
  const id = 'g' + uid++;
  const g = el('linearGradient', { id, x1: 0, y1: 0, x2: vertical ? 0 : 1, y2: vertical ? 1 : 0 }, ov.defs);
  stops.forEach((c, i) => el('stop', { offset: `${(i / (stops.length - 1)) * 100}%`, 'stop-color': c }, g));
  return `url(#${id})`;
}

// Velký "herní" nápis s obrysem a 3D vytažením
export function bigText(ov, {
  text, x, y, size = 120, fill = ['#fff7a8', '#ffd23c', '#ff8a1f'], stroke = '#3d1d08', strokeW = null,
  extrude = null, extrudeColor = '#6b2f0c', anchor = 'middle', rotate = 0, font = 'Luckiest Guy', spacing = 0,
  shadow = true,
}) {
  const sw = strokeW ?? size * 0.12;
  const ex = extrude ?? Math.round(size * 0.09);
  const g = el('g', { transform: `rotate(${rotate} ${x} ${y})` }, ov.svg);
  const base = {
    x, 'text-anchor': anchor, 'font-family': font, 'font-size': size,
    'letter-spacing': spacing, 'paint-order': 'stroke', 'stroke-linejoin': 'round', 'stroke-linecap': 'round',
  };
  if (shadow) {
    const t = el('text', { ...base, y: y + ex + size * 0.07, fill: 'rgba(0,0,0,0.35)', stroke: 'rgba(0,0,0,0.35)', 'stroke-width': sw }, g);
    t.textContent = text;
  }
  for (let i = ex; i >= 1; i -= 1) {
    const t = el('text', { ...base, y: y + i, fill: extrudeColor, stroke, 'stroke-width': sw }, g);
    t.textContent = text;
  }
  const main = el('text', { ...base, y, fill: Array.isArray(fill) ? gradient(ov, fill) : fill, stroke, 'stroke-width': sw }, g);
  main.textContent = text;
  return g;
}

// Logo hry
export function logo(ov, x, y, s = 1, { stacked = true } = {}) {
  if (stacked) {
    bigText(ov, { text: 'DUNE', x, y: y, size: 70 * s, fill: ['#fff3cf', '#ffd98a', '#e9a44a'], extrudeColor: '#8a4a16' });
    bigText(ov, { text: 'DIGGERS', x, y: y + 92 * s, size: 104 * s, fill: ['#fff9b0', '#ffc928', '#ff7a12'] });
  } else {
    bigText(ov, { text: 'DUNE DIGGERS', x, y, size: 80 * s, fill: ['#fff9b0', '#ffc928', '#ff7a12'] });
  }
}

// HTML prvek na pozici
export function html(ov, markup, style = {}) {
  const d = document.createElement('div');
  d.innerHTML = markup;
  d.style.position = 'absolute';
  Object.assign(d.style, style);
  ov.root.appendChild(d);
  return d;
}

export function pill(ov, text, { x, y, bg = 'linear-gradient(#ff9b2f,#ff6a00)', color = '#fff', size = 40, anchor = 'center', border = '#3d1d08', icon = '' } = {}) {
  const tx = anchor === 'center' ? '-50%' : anchor === 'right' ? '-100%' : '0';
  return html(ov, `${icon}<span>${text}</span>`, {
    left: x + 'px', top: y + 'px', transform: `translate(${tx}, -50%)`,
    background: bg, color, font: `${size}px 'Luckiest Guy'`, letterSpacing: '1px',
    padding: `${size * 0.38}px ${size * 0.75}px ${size * 0.22}px`, borderRadius: size * 2 + 'px',
    border: `${Math.max(4, size * 0.13)}px solid ${border}`,
    boxShadow: `0 ${size * 0.18}px 0 ${border}, 0 ${size * 0.4}px ${size * 0.6}px rgba(0,0,0,0.35)`,
    textShadow: `0 ${size * 0.07}px 0 rgba(0,0,0,0.35)`, whiteSpace: 'nowrap', display: 'flex', alignItems: 'center', gap: size * 0.3 + 'px',
  });
}

export const coinIcon = (s = 40) => `<svg width="${s}" height="${s}" viewBox="0 0 40 40" style="flex:none;margin-top:-${s * 0.12}px"><circle cx="20" cy="20" r="18" fill="#ffc928" stroke="#3d1d08" stroke-width="3"/><circle cx="20" cy="20" r="12" fill="#ffe27a" stroke="#d68a00" stroke-width="2"/><rect x="17" y="12" width="6" height="16" rx="2" fill="#d68a00"/></svg>`;

export const robloxBadge = (s = 40) => `<svg width="${s}" height="${s}" viewBox="0 0 40 40" style="flex:none;margin-top:-${s * 0.12}px"><rect x="6" y="6" width="28" height="28" rx="4" fill="#fff" stroke="#3d1d08" stroke-width="3" transform="rotate(15 20 20)"/><rect x="16" y="16" width="8" height="8" fill="#3d1d08" transform="rotate(15 20 20)"/></svg>`;

// Vinětace + světlé paprsky pro "wow" efekt
export function vignette(ov, strength = 0.45) {
  html(ov, '', { inset: '0', background: `radial-gradient(ellipse at center, rgba(0,0,0,0) 55%, rgba(30,10,0,${strength}) 100%)`, pointerEvents: 'none' });
}

export function rays(ov, cx, cy, color = 'rgba(255,240,180,0.22)', count = 18) {
  const stops = [];
  for (let i = 0; i < count; i++) {
    const a = (i / count) * 360;
    stops.push(`${color} ${a}deg ${a + 360 / count / 2}deg`, `transparent ${a + 360 / count / 2}deg ${a + 360 / count}deg`);
  }
  html(ov, '', {
    left: '0', top: '0', width: ov.W + 'px', height: ov.H + 'px',
    background: `conic-gradient(from 0deg at ${cx}px ${cy}px, ${stops.join(',')})`,
    WebkitMaskImage: `radial-gradient(circle at ${cx}px ${cy}px, black 0%, transparent 70%)`,
    maskImage: `radial-gradient(circle at ${cx}px ${cy}px, black 0%, transparent 70%)`, mixBlendMode: 'screen',
  });
}

export function label(ov, x, y, title, sub, color, { size = 34 } = {}) {
  return html(ov, `
    <div style="font:${size}px 'Luckiest Guy';color:#fff;-webkit-text-stroke:${size * 0.1}px #3d1d08;paint-order:stroke;text-shadow:0 ${size * 0.1}px 0 #3d1d08">${title}</div>
    ${sub ? `<div style="margin-top:6px;display:inline-flex;align-items:center;gap:6px;background:${color};border:4px solid #3d1d08;border-radius:30px;padding:${size * 0.22}px ${size * 0.45}px ${size * 0.1}px;font:${size * 0.75}px 'Luckiest Guy';color:#fff;-webkit-text-stroke:${size * 0.06}px #3d1d08;paint-order:stroke;box-shadow:0 5px 0 #3d1d08">${sub}</div>` : ''}
  `, { left: x + 'px', top: y + 'px', transform: 'translate(-50%,-100%)', textAlign: 'center', whiteSpace: 'nowrap' });
}

// Zakřivená šipka (bílá s tmavým obrysem)
export function arrow(ov, x1, y1, x2, y2, bend = -60, color = '#ffffff') {
  const mx = (x1 + x2) / 2, my = (y1 + y2) / 2 + bend;
  const d = `M ${x1} ${y1} Q ${mx} ${my} ${x2} ${y2}`;
  const g = el('g', {}, ov.svg);
  el('path', { d, fill: 'none', stroke: '#3d1d08', 'stroke-width': 20, 'stroke-linecap': 'round', 'stroke-dasharray': '2 26' }, g);
  el('path', { d, fill: 'none', stroke: color, 'stroke-width': 11, 'stroke-linecap': 'round', 'stroke-dasharray': '2 26' }, g);
  const ang = Math.atan2(y2 - my, x2 - mx);
  const s = 26;
  const pts = [
    [x2 + Math.cos(ang) * s * 0.6, y2 + Math.sin(ang) * s * 0.6],
    [x2 + Math.cos(ang + 2.4) * s, y2 + Math.sin(ang + 2.4) * s],
    [x2 + Math.cos(ang - 2.4) * s, y2 + Math.sin(ang - 2.4) * s],
  ].map((p) => p.join(',')).join(' ');
  el('polygon', { points: pts, fill: color, stroke: '#3d1d08', 'stroke-width': 6, 'stroke-linejoin': 'round' }, g);
}

export function numberBadge(ov, x, y, n, color, size = 110) {
  return html(ov, `<span>${n}</span>`, {
    left: x + 'px', top: y + 'px', width: size + 'px', height: size + 'px', transform: 'translate(-50%,-50%) rotate(-6deg)',
    borderRadius: '50%', background: `radial-gradient(circle at 35% 30%, #ffffff55, transparent 40%), ${color}`,
    border: `${size * 0.08}px solid #3d1d08`, boxShadow: `0 ${size * 0.08}px 0 #3d1d08, 0 10px 30px rgba(0,0,0,0.35)`,
    display: 'flex', alignItems: 'center', justifyContent: 'center', font: `${size * 0.62}px 'Luckiest Guy'`, color: '#fff',
    WebkitTextStroke: `${size * 0.05}px #3d1d08`, paintOrder: 'stroke', paddingTop: size * 0.12 + 'px', boxSizing: 'border-box',
  });
}
