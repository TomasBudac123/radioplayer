// Ikona natívnych aplikácií v neutrálnej palete (design/tokens.json): node tools/make-app-icons.mjs
// Android používa rovnaký motív ako vektor (android/app/src/main/res/drawable/ic_launcher_foreground.xml).
import { mkdirSync, writeFileSync } from 'node:fs';
import { deflateSync } from 'node:zlib';

const crcTable = Array.from({ length: 256 }, (_, n) => {
  let c = n;
  for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
  return c >>> 0;
});
const crc = (buf) => { let c = 0xffffffff; for (const b of buf) c = crcTable[(c ^ b) & 0xff] ^ (c >>> 8); return (c ^ 0xffffffff) >>> 0; };
function chunk(type, data) {
  const len = Buffer.alloc(4); len.writeUInt32BE(data.length);
  const td = Buffer.concat([Buffer.from(type), data]);
  const c = Buffer.alloc(4); c.writeUInt32BE(crc(td));
  return Buffer.concat([len, td, c]);
}
function png(size, pixel) {
  const raw = Buffer.alloc(size * (size * 3 + 1));
  const ss = 3;
  for (let y = 0; y < size; y++) {
    raw[y * (size * 3 + 1)] = 0;
    for (let x = 0; x < size; x++) {
      let r = 0, g = 0, b = 0;
      for (let sy = 0; sy < ss; sy++) for (let sx = 0; sx < ss; sx++) {
        const [pr, pg, pb] = pixel((x + (sx + 0.5) / ss) / size, (y + (sy + 0.5) / ss) / size);
        r += pr; g += pg; b += pb;
      }
      const o = y * (size * 3 + 1) + 1 + x * 3;
      raw[o] = r / ss ** 2; raw[o + 1] = g / ss ** 2; raw[o + 2] = b / ss ** 2;
    }
  }
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(size, 0); ihdr.writeUInt32BE(size, 4);
  ihdr[8] = 8; ihdr[9] = 2; // RGB bez alfa kanála (App Store vyžaduje nepriehľadnú ikonu)
  return Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk('IHDR', ihdr), chunk('IDAT', deflateSync(raw)), chunk('IEND', Buffer.alloc(0))]);
}

const mix = (a, b, t) => a.map((v, i) => v + (b[i] - v) * t);
const TOP = [0x2d, 0x2d, 0x32], BOTTOM = [0x0d, 0x0d, 0x0f], INK = [0xf3, 0xf3, 0xf5];

// Grafitový gradient; motív: bod + dva oblúky (vysielanie).
function pixel(u, v) {
  let c = mix(TOP, BOTTOM, v);
  const dx = u - 0.5, dy = v - 0.56;
  const d = Math.hypot(dx, dy);
  const ang = Math.atan2(dy, dx);
  const inArc = Math.abs(ang + Math.PI / 2) < 0.75;
  if (d < 0.065) c = INK;
  for (const r of [0.15, 0.24]) if (inArc && Math.abs(d - r) < 0.028) c = INK;
  return c;
}

const dir = new URL('../ios/App/Resources/Assets.xcassets/AppIcon.appiconset/', import.meta.url);
mkdirSync(dir, { recursive: true });
writeFileSync(new URL('AppIcon-1024.png', dir), png(1024, pixel));
console.log('ok');
