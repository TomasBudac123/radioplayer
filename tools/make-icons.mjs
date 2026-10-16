// Vygeneruje PNG ikony bez externých závislostí: node tools/make-icons.mjs
import { writeFileSync } from 'node:fs';
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
  const raw = Buffer.alloc(size * (size * 4 + 1));
  for (let y = 0; y < size; y++) {
    raw[y * (size * 4 + 1)] = 0;
    for (let x = 0; x < size; x++) {
      // 4x supersampling pre hladké hrany
      let r = 0, g = 0, b = 0;
      for (let sy = 0; sy < 2; sy++) for (let sx = 0; sx < 2; sx++) {
        const [pr, pg, pb] = pixel((x + (sx + 0.5) / 2) / size, (y + (sy + 0.5) / 2) / size);
        r += pr; g += pg; b += pb;
      }
      const o = y * (size * 4 + 1) + 1 + x * 4;
      raw[o] = r / 4; raw[o + 1] = g / 4; raw[o + 2] = b / 4; raw[o + 3] = 255;
    }
  }
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(size, 0); ihdr.writeUInt32BE(size, 4);
  ihdr[8] = 8; ihdr[9] = 6;
  return Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk('IHDR', ihdr), chunk('IDAT', deflateSync(raw)), chunk('IEND', Buffer.alloc(0))]);
}

const mix = (a, b, t) => a.map((v, i) => v + (b[i] - v) * t);
const A = [255, 90, 54], B = [255, 160, 60], W = [255, 255, 255];

// Pozadie: diagonálny gradient; motív: bod + dva oblúky (vysielanie), centrované – bezpečné aj pre maskable
function pixel(u, v) {
  let c = mix(A, B, (u + v) / 2);
  const dx = u - 0.5, dy = v - 0.56;
  const d = Math.hypot(dx, dy);
  const ang = Math.atan2(dy, dx); // hore = -PI/2
  const inArc = Math.abs(ang + Math.PI / 2) < 0.75;
  if (d < 0.065) c = W;
  for (const r of [0.15, 0.24]) if (inArc && Math.abs(d - r) < 0.028) c = W;
  return c;
}

for (const [name, size] of [['icon-192', 192], ['icon-512', 512], ['apple-touch-icon', 180]]) {
  writeFileSync(new URL(`../icons/${name}.png`, import.meta.url), png(size, pixel));
}
console.log('ok');
