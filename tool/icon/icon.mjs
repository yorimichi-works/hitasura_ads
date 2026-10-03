// App icon source for ひたすら広告.
// A fanned, endless stack of ad screens on a sunburst night sky; the front
// screen carries a sticker-style "AD" and a video-ad progress bar.
//
// iconSvg({bg, fg, scale, shape}) returns a 1024x1024 SVG string:
//   bg     draw the background (gradient + sunburst)
//   fg     draw the foreground (cards, letters, sparkles)
//   scale  foreground scale around the centre (safe zones for maskable icons)
//   shape  'square' (full bleed), 'round' (rounded square), 'mac' (Big Sur grid)

const C = {
  ink: '#140E2A',
  night: '#1B1140',
  night2: '#2A1462',
  violet: '#5B2BD9',
  yellow: '#FFD23F',
  yellowHi: '#FFE88A',
  pink: '#FF4FA3',
  pinkDeep: '#E0247E',
  cyan: '#2EE6F0',
  purple: '#8C4DFF',
  white: '#FFFFFF',
};

function rays(cx, cy, n, r) {
  let d = '';
  const step = (Math.PI * 2) / n;
  for (let i = 0; i < n; i += 2) {
    const a0 = i * step - Math.PI / 2;
    const a1 = a0 + step;
    d += `M${cx},${cy}L${cx + r * Math.cos(a0)},${cy + r * Math.sin(a0)}` +
      `L${cx + r * Math.cos(a1)},${cy + r * Math.sin(a1)}Z`;
  }
  return d;
}

function sparkle(x, y, r, fill, rot = 0) {
  const k = r * 0.22;
  return `<path transform="translate(${x} ${y}) rotate(${rot})" fill="${fill}" ` +
    `stroke="${C.ink}" stroke-width="${Math.max(6, r * 0.16)}" stroke-linejoin="round" ` +
    `d="M0,${-r}Q${k},${-k} ${r},0Q${k},${k} 0,${r}Q${-k},${k} ${-r},0Q${-k},${-k} 0,${-r}Z"/>`;
}

// A card ("ad screen") centred on 0,0.
function card(w, h, fill, rot, dx, dy, inner) {
  return `<g transform="translate(${dx} ${dy}) rotate(${rot})">
    <rect x="${-w / 2 + 6}" y="${-h / 2 + 26}" width="${w}" height="${h}" rx="78" fill="${C.ink}" opacity=".55"/>
    <rect x="${-w / 2}" y="${-h / 2}" width="${w}" height="${h}" rx="78" fill="${fill}" stroke="${C.ink}" stroke-width="26"/>
    ${inner || ''}
  </g>`;
}

const LETTERS =
  'M-205,95 L-122,-108 L-39,95 M-176,32 L-68,32 ' +
  'M38,-108 L92,-108 Q205,-108 205,-6.5 Q205,95 92,95 L38,95 Z';

function frontInner(w, h) {
  const sw = 66;
  const barY = h / 2 - 78;
  const barX0 = -w / 2 + 70;
  const barX1 = w / 2 - 70;
  const knobX = barX0 + (barX1 - barX0) * 0.68;
  return `
    <clipPath id="frontClip"><rect x="${-w / 2}" y="${-h / 2}" width="${w}" height="${h}" rx="78"/></clipPath>
    <g clip-path="url(#frontClip)">
      <path d="M${-w / 2},${-h / 2}H${w / 2}V${-h / 2 + 120}Q0,${-h / 2 + 40} ${-w / 2},${-h / 2 + 150}Z" fill="${C.yellowHi}"/>
    </g>
    <g transform="translate(0 -20)" stroke-linecap="round" stroke-linejoin="round" fill="none">
      <path d="${LETTERS}" stroke="${C.ink}" stroke-width="${sw + 34}" transform="translate(0 16)"/>
      <path d="${LETTERS}" stroke="${C.ink}" stroke-width="${sw + 34}"/>
      <path d="${LETTERS}" stroke="url(#letterGrad)" stroke-width="${sw}"/>
      <path d="M-178,40 L-126,-86 M40,-80 L40,30" stroke="${C.white}" stroke-opacity=".55" stroke-width="14" transform="translate(-6 -2)"/>
    </g>
    <g stroke-linecap="round">
      <line x1="${barX0}" y1="${barY}" x2="${barX1}" y2="${barY}" stroke="${C.ink}" stroke-width="30"/>
      <line x1="${barX0}" y1="${barY}" x2="${knobX}" y2="${barY}" stroke="${C.pink}" stroke-width="12"/>
      <circle cx="${knobX}" cy="${barY}" r="24" fill="${C.white}" stroke="${C.ink}" stroke-width="12"/>
    </g>`;
}

function playBadge(x, y, r) {
  return `<g transform="translate(${x} ${y}) rotate(8)">
    <circle r="${r}" cy="12" fill="${C.ink}" opacity=".55"/>
    <circle r="${r}" fill="${C.pink}" stroke="${C.ink}" stroke-width="22"/>
    <path d="M${-r * 0.28},${-r * 0.42} L${r * 0.46},0 L${-r * 0.28},${r * 0.42} Z" fill="${C.white}" stroke="${C.white}" stroke-width="18" stroke-linejoin="round"/>
  </g>`;
}

function foreground() {
  const w = 620;
  const h = 480;
  return `
    <g transform="translate(512 560)">
      ${card(w, h, C.pink, 3, 20, -150)}
      ${card(w, h, C.cyan, -15, -48, -96)}
      ${card(w, h, C.purple, 12, 52, -66)}
      ${card(w, h, C.yellow, -4, 0, 18, frontInner(w, h))}
    </g>
    ${playBadge(812, 330, 90)}
    ${sparkle(170, 250, 62, C.yellow, 0)}
    ${sparkle(120, 400, 30, C.white, 15)}
    ${sparkle(860, 860, 46, C.cyan, 10)}
    ${sparkle(228, 880, 26, C.pink, -10)}`;
}

function background() {
  return `
    <rect width="1024" height="1024" fill="url(#bgGrad)"/>
    <path d="${rays(512, 560, 28, 1100)}" fill="${C.white}" opacity=".06"/>
    <rect width="1024" height="1024" fill="url(#glow)"/>`;
}

function defs() {
  return `<defs>
    <radialGradient id="bgGrad" cx=".5" cy=".42" r=".75">
      <stop offset="0" stop-color="${C.violet}"/>
      <stop offset=".55" stop-color="${C.night2}"/>
      <stop offset="1" stop-color="${C.ink}"/>
    </radialGradient>
    <radialGradient id="glow" cx=".5" cy=".55" r=".5">
      <stop offset="0" stop-color="${C.pink}" stop-opacity=".55"/>
      <stop offset="1" stop-color="${C.pink}" stop-opacity="0"/>
    </radialGradient>
    <linearGradient id="letterGrad" x1="0" y1="-120" x2="0" y2="110" gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="#FF6FB5"/>
      <stop offset="1" stop-color="${C.pinkDeep}"/>
    </linearGradient>
    <filter id="macShadow" x="-20%" y="-20%" width="140%" height="140%">
      <feDropShadow dx="0" dy="10" stdDeviation="12" flood-color="#000" flood-opacity=".35"/>
    </filter>
  </defs>`;
}

export function iconSvg({ bg = true, fg = true, scale = 1, shape = 'square' } = {}) {
  const fgSvg = fg
    ? `<g transform="translate(512 512) scale(${scale}) translate(-512 -512)">${foreground()}</g>`
    : '';
  let body;
  if (shape === 'square') {
    body = `${bg ? background() : ''}${fgSvg}`;
  } else {
    // 'round': full canvas rounded square; 'mac': 824px tile on the macOS grid.
    const [o, s, r] = shape === 'mac' ? [100, 824, 185] : [0, 1024, 225];
    const k = s / 1024;
    body = `
      <clipPath id="tile"><rect x="${o}" y="${o}" width="${s}" height="${s}" rx="${r}"/></clipPath>
      ${shape === 'mac' ? `<rect x="${o}" y="${o}" width="${s}" height="${s}" rx="${r}" fill="${C.ink}" filter="url(#macShadow)"/>` : ''}
      <g clip-path="url(#tile)">
        <g transform="translate(${o} ${o}) scale(${k})">${bg ? background() : ''}${fgSvg}</g>
      </g>`;
  }
  return `<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">${defs()}${body}</svg>`;
}
