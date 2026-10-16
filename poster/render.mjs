// Vyrenderuje plagát do PNG cez headless Chrome (bez závislostí, Node 22+).
// Najprv spusti lokálny server v koreni projektu: python3 -m http.server 5173
// Potom: node poster/render.mjs
import { spawn } from 'node:child_process';
import { writeFileSync, mkdtempSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const CHROME = process.env.CHROME || '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';
const URL_ = process.env.POSTER_URL || 'http://localhost:5173/poster/poster.html';
const OUT = new URL('./radio-plagat.png', import.meta.url);
const PORT = 9333;

const chrome = spawn(CHROME, [
  '--headless=new', '--mute-audio', '--hide-scrollbars', '--no-first-run',
  `--remote-debugging-port=${PORT}`, `--user-data-dir=${mkdtempSync(join(tmpdir(), 'poster-'))}`,
  'about:blank',
], { stdio: 'ignore' });

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
try {
  let target;
  for (let i = 0; i < 50 && !target; i++) {
    try { target = (await (await fetch(`http://127.0.0.1:${PORT}/json/list`)).json()).find((t) => t.type === 'page'); }
    catch { await sleep(200); }
  }
  const ws = new WebSocket(target.webSocketDebuggerUrl);
  await new Promise((r) => ws.addEventListener('open', r));
  let id = 0;
  const pending = new Map();
  ws.addEventListener('message', (e) => {
    const m = JSON.parse(e.data);
    if (m.id && pending.has(m.id)) { pending.get(m.id)(m.result); pending.delete(m.id); }
  });
  const send = (method, params = {}) => new Promise((r) => { pending.set(++id, r); ws.send(JSON.stringify({ id, method, params })); });

  await send('Emulation.setDeviceMetricsOverride', { width: 1240, height: 1754, deviceScaleFactor: 2, mobile: false });
  await send('Page.navigate', { url: URL_ });
  for (let i = 0; i < 60; i++) {
    const r = await send('Runtime.evaluate', { expression: "document.body && document.body.dataset.ready === '1'", returnByValue: true });
    if (r?.result?.value) break;
    await sleep(500);
  }
  await sleep(2500); // dočítanie log rádií
  const shot = await send('Page.captureScreenshot', { format: 'png', clip: { x: 0, y: 0, width: 1240, height: 1754, scale: 1 } });
  writeFileSync(OUT, Buffer.from(shot.data, 'base64'));
  console.log('Uložené:', OUT.pathname);
  ws.close();
} finally {
  chrome.kill();
}
