'use strict';

// ---------- Stav ----------
const LS_FAVS = 'radio.favorites.v1';
const LS_LAST = 'radio.last.v1';
const LS_COUNTRY = 'radio.country.v1';

const $ = (s) => document.querySelector(s);
const audio = $('#audio');

const state = {
  favs: load(LS_FAVS, []),
  current: null,       // práve zvolená stanica
  candidates: [],      // URL, ktoré skúšame postupne
  status: 'idle',      // idle | loading | playing | paused | error
  editing: false,
  results: [],
  offset: 0,
  view: 'home',
};

function load(key, fallback) {
  try { return JSON.parse(localStorage.getItem(key)) ?? fallback; } catch { return fallback; }
}
function save(key, value) {
  try { localStorage.setItem(key, JSON.stringify(value)); } catch {}
}
const saveFavs = () => save(LS_FAVS, state.favs);
const isFav = (id) => state.favs.some((s) => s.id === id);

// ---------- Radio Browser API ----------
// https://api.radio-browser.info – verejná, bezplatná databáza ~50 000 rádií z celého sveta
const FALLBACK_SERVERS = ['de1.api.radio-browser.info', 'de2.api.radio-browser.info', 'fi1.api.radio-browser.info'];
let servers = null;

async function getServers() {
  if (servers) return servers;
  try {
    const r = await fetch('https://all.api.radio-browser.info/json/servers', { signal: AbortSignal.timeout(4000) });
    const list = (await r.json()).map((s) => s.name);
    servers = [...new Set(list)].sort(() => Math.random() - 0.5);
  } catch {
    servers = [...FALLBACK_SERVERS].sort(() => Math.random() - 0.5);
  }
  return servers;
}

async function api(path, params = {}) {
  const qs = new URLSearchParams(params).toString();
  const list = await getServers();
  let lastErr;
  for (let i = 0; i < list.length; i++) {
    try {
      const r = await fetch(`https://${list[i]}/json/${path}${qs ? '?' + qs : ''}`, { signal: AbortSignal.timeout(8000) });
      if (!r.ok) throw new Error(r.status);
      // úspešný server dáme na začiatok
      if (i > 0) servers = [list[i], ...list.filter((_, j) => j !== i)];
      return await r.json();
    } catch (e) { lastErr = e; }
  }
  throw lastErr;
}

function normalize(s) {
  return {
    id: s.stationuuid,
    name: (s.name || '').trim() || 'Bez názvu',
    url: s.url_resolved || s.url,
    url2: s.url,
    favicon: s.favicon || '',
    country: s.country || '',
    countrycode: s.countrycode || '',
    tags: (s.tags || '').split(',').filter(Boolean).slice(0, 3).join(', '),
    codec: s.codec || '',
    bitrate: s.bitrate || 0,
    hls: !!s.hls,
  };
}

// ---------- Pomocné ----------
const PALETTE = ['#ff5a36', '#3d8bff', '#22c38e', '#b45cff', '#ffb020', '#ff4d8d', '#00b8d9', '#7c8cff'];
function colorFor(str) {
  let h = 0;
  for (const c of str) h = (h * 31 + c.charCodeAt(0)) | 0;
  return PALETTE[Math.abs(h) % PALETTE.length];
}
function initials(name) {
  const w = name.replace(/[^\p{L}\p{N} ]/gu, '').split(/\s+/).filter(Boolean);
  return ((w[0]?.[0] || '?') + (w[1]?.[0] || '')).toUpperCase();
}
function esc(s) {
  return String(s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}
function safeImg(url) {
  return /^https:\/\//i.test(url) ? url : ''; // http obrázky by na https stránke neprešli
}

/** Vytvorí logo – obrázok, ktorý pri chybe nahradí farebné iniciály. */
function logoEl(station, cls = 'logo') {
  const src = safeImg(station.favicon);
  const fallback = () => {
    const d = document.createElement('div');
    d.className = cls;
    d.style.background = colorFor(station.name);
    d.textContent = initials(station.name);
    return d;
  };
  if (!src) return fallback();
  const img = document.createElement('img');
  img.className = cls;
  img.loading = 'lazy';
  img.alt = '';
  img.referrerPolicy = 'no-referrer';
  img.src = src;
  img.onerror = () => img.replaceWith(fallback());
  return img;
}

const regionNames = new Intl.DisplayNames(['sk'], { type: 'region' });
function countryName(s) {
  try { return (s.countrycode && regionNames.of(s.countrycode)) || s.country || ''; } catch { return s.country || ''; }
}

let toastTimer;
function toast(msg) {
  const t = $('#toast');
  t.textContent = msg;
  t.hidden = false;
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => (t.hidden = true), 2200);
}

// ---------- Obľúbené ----------
function toggleFav(station) {
  if (isFav(station.id)) {
    state.favs = state.favs.filter((s) => s.id !== station.id);
    toast('Odstránené z obľúbených');
  } else {
    state.favs.push(station);
    toast('Pridané do obľúbených ★');
  }
  saveFavs();
  renderFavs();
  renderResults();
  renderPlayer();
}

function renderFavs() {
  const grid = $('#favGrid');
  grid.innerHTML = '';
  grid.classList.toggle('editing', state.editing);
  grid.classList.toggle('paused', state.status !== 'playing');
  $('#favEmpty').hidden = state.favs.length > 0;
  $('#editBtn').hidden = state.view !== 'home' || state.favs.length === 0;
  $('#editBtn').textContent = state.editing ? 'Hotovo' : 'Upraviť';

  state.favs.forEach((s, i) => {
    const tile = document.createElement('div');
    tile.className = 'tile' + (state.current?.id === s.id && state.status !== 'idle' ? ' playing' : '');
    tile.setAttribute('role', 'button');

    const art = logoEl(s, 'art');
    if (art.tagName === 'IMG') {
      const wrap = document.createElement('div');
      wrap.className = 'art';
      art.className = '';
      art.onerror = () => { wrap.style.background = colorFor(s.name); wrap.textContent = initials(s.name); };
      wrap.append(art);
      tile.append(wrap);
    } else tile.append(art);

    tile.insertAdjacentHTML('beforeend',
      `<div class="name">${esc(s.name)}</div>
       <div class="eq"><i></i><i></i><i></i></div>
       <button class="remove" aria-label="Odstrániť">−</button>
       <button class="move" aria-label="Posunúť dopredu">↖</button>`);

    tile.addEventListener('click', (e) => {
      if (e.target.closest('.remove')) {
        state.favs.splice(i, 1);
        saveFavs();
        if (!state.favs.length) state.editing = false;
        renderFavs();
        renderResults();
        renderPlayer();
        return;
      }
      if (e.target.closest('.move')) {
        if (i > 0) {
          [state.favs[i - 1], state.favs[i]] = [state.favs[i], state.favs[i - 1]];
          saveFavs();
          renderFavs();
        }
        return;
      }
      if (state.editing) return;
      if (state.current?.id === s.id && state.status !== 'idle' && state.status !== 'error') togglePlay();
      else play(s);
    });
    grid.append(tile);
  });
}

// ---------- Prehrávanie ----------
let watchdog;

function buildCandidates(station) {
  const urls = [station.url, station.url2].filter(Boolean);
  const out = [];
  for (const u of urls) {
    // na https stránke iOS blokuje http streamy – skúsime najprv https verziu
    if (location.protocol === 'https:' && u.startsWith('http://')) out.push(u.replace(/^http:/, 'https:'));
    out.push(u);
  }
  return [...new Set(out)];
}

function play(station) {
  state.current = station;
  state.candidates = buildCandidates(station);
  save(LS_LAST, station);
  // nahlásime klik (pomáha rebríčku popularity v Radio Browser)
  if (station.id && !station.id.startsWith('manual-')) api(`url/${station.id}`).catch(() => {});
  tryNext();
}

function tryNext() {
  const url = state.candidates.shift();
  if (!url) return setStatus('error', 'Stream sa nepodarilo prehrať');
  setStatus('loading');
  audio.src = url;
  audio.play().catch((e) => {
    if (e.name === 'NotAllowedError') setStatus('paused');
    // ostatné chyby rieši 'error' event
  });
  clearTimeout(watchdog);
  watchdog = setTimeout(() => {
    if (state.status === 'loading') tryNext();
  }, 15000);
  updateMediaSession();
}

function stop() {
  audio.pause();
  audio.removeAttribute('src');
  audio.load();
}

function togglePlay() {
  if (!state.current) return;
  if (state.status === 'playing' || state.status === 'loading') {
    stop();
    setStatus('paused');
  } else {
    // živé rádio – po pauze sa pripojíme nanovo, aby sme boli „naživo“
    play(state.current);
  }
}

function setStatus(status, msg) {
  state.status = status;
  if (status !== 'loading') clearTimeout(watchdog);
  if (status === 'error') stop();
  state.statusMsg = msg;
  if ('mediaSession' in navigator) {
    navigator.mediaSession.playbackState = status === 'playing' ? 'playing' : status === 'idle' ? 'none' : 'paused';
  }
  renderPlayer();
  renderFavs();
  renderResults();
}

audio.addEventListener('playing', () => setStatus('playing'));
audio.addEventListener('waiting', () => state.status === 'playing' && setStatus('loading'));
audio.addEventListener('error', () => {
  if (!audio.getAttribute('src')) return; // chyba po zastavení
  if (state.status === 'loading' || state.status === 'playing') tryNext();
});
audio.addEventListener('pause', () => {
  // pozastavené systémom (napr. hovor, slúchadlá)
  if (state.status === 'playing') setStatus('paused');
});

function renderPlayer() {
  const s = state.current;
  $('#player').hidden = !s;
  if (!s) return;
  $('#pName').textContent = s.name;
  const status = $('#pStatus');
  status.classList.toggle('err', state.status === 'error');
  status.textContent = {
    loading: 'Pripájam…',
    playing: 'Naživo' + (s.bitrate ? ` · ${s.bitrate} kbps` : '') + (countryName(s) ? ` · ${countryName(s)}` : ''),
    paused: 'Pozastavené',
    error: state.statusMsg || 'Chyba',
    idle: countryName(s),
  }[state.status];

  const slot = $('#pLogo');
  if (slot.dataset.id !== s.id) {
    slot.dataset.id = s.id;
    slot.replaceChildren(logoEl(s));
  }

  const btn = $('#pToggle');
  btn.classList.toggle('playing', state.status === 'playing');
  btn.classList.toggle('loading', state.status === 'loading');

  const fav = $('#pFav');
  fav.textContent = isFav(s.id) ? '★' : '☆';
  fav.classList.toggle('on', isFav(s.id));
}

$('#pToggle').addEventListener('click', togglePlay);
$('#pFav').addEventListener('click', () => state.current && toggleFav(state.current));

// Ovládanie zo zamknutej obrazovky / Control Center
function updateMediaSession() {
  if (!('mediaSession' in navigator) || !state.current) return;
  const s = state.current;
  const art = safeImg(s.favicon);
  navigator.mediaSession.metadata = new MediaMetadata({
    title: s.name,
    artist: [countryName(s), s.tags].filter(Boolean).join(' · ') || 'Internetové rádio',
    album: 'Rádio',
    artwork: art ? [{ src: art, sizes: '512x512' }] : [{ src: 'icons/icon-512.png', sizes: '512x512', type: 'image/png' }],
  });
}

function step(dir) {
  if (!state.favs.length) return;
  const i = state.favs.findIndex((s) => s.id === state.current?.id);
  const next = state.favs[(i + dir + state.favs.length) % state.favs.length];
  play(next);
}

if ('mediaSession' in navigator) {
  const ms = navigator.mediaSession;
  const set = (a, h) => { try { ms.setActionHandler(a, h); } catch {} };
  set('play', () => state.current && play(state.current));
  set('pause', () => { stop(); setStatus('paused'); });
  set('stop', () => { stop(); setStatus('paused'); });
  set('nexttrack', () => step(1));
  set('previoustrack', () => step(-1));
}

// ---------- Hľadanie ----------
const PAGE = 40;
let searchSeq = 0;
let debounce;
const LS_TAG = 'radio.tag.v1';

// Vybrané žánre – surové tagy v Radio Browser sú nejednotné, preto ponúkame overený zoznam
const GENRES = [
  ['pop', 'Pop'], ['rock', 'Rock'], ['alternative', 'Alternatívna'], ['hits', 'Hity'], ['top 40', 'Top 40'],
  ['news', 'Správy'], ['talk', 'Diskusie a talk'], ['sport', 'Šport'],
  ['dance', 'Dance'], ['electronic', 'Elektronická'], ['house', 'House'], ['techno', 'Techno'], ['trance', 'Trance'],
  ['chillout', 'Chillout'], ['lounge', 'Lounge'], ['ambient', 'Ambient'],
  ['jazz', 'Jazz'], ['blues', 'Blues'], ['soul', 'Soul'], ['funk', 'Funk'], ['rnb', 'R&B'], ['hip hop', 'Hip-hop'],
  ['classical', 'Klasická'], ['soundtrack', 'Filmová hudba'],
  ['oldies', 'Oldies'], ['60s', '60. roky'], ['70s', '70. roky'], ['80s', '80. roky'], ['90s', '90. roky'], ['2000s', '2000-ky'],
  ['disco', 'Disco'], ['classic rock', 'Classic rock'], ['metal', 'Metal'], ['punk', 'Punk'],
  ['indie', 'Indie'],
  ['country', 'Country'], ['folk', 'Folk'], ['reggae', 'Reggae'], ['latin', 'Latino'], ['world', 'World music'],
  ['christian', 'Kresťanské'], ['kids', 'Pre deti'], ['comedy', 'Humor'], ['public radio', 'Verejnoprávne'],
];

function loadGenres() {
  const sel = $('#tag');
  for (const [value, label] of GENRES) sel.add(new Option(label, value));
  const saved = load(LS_TAG, '');
  if (GENRES.some(([v]) => v === saved)) sel.value = saved;
}

function searchParams() {
  const p = { hidebroken: 'true', order: 'clickcount', reverse: 'true', limit: PAGE, offset: state.offset };
  const q = $('#q').value.trim();
  const tag = $('#tag').value;
  const cc = $('#country').value;
  if (q) p.name = q;
  if (tag) p.tag = tag;
  if (cc) p.countrycode = cc;
  return p;
}

async function search(append = false) {
  const seq = ++searchSeq;
  if (!append) state.offset = 0;
  const info = $('#searchInfo');
  info.textContent = 'Hľadám…';
  $('#moreBtn').hidden = true;
  try {
    const data = await api('stations/search', searchParams());
    if (seq !== searchSeq) return;
    const items = data.map(normalize).filter((s) => s.url);
    // odstránime duplicity (rovnaký názov + url)
    const seen = new Set(append ? state.results.map((s) => s.url) : []);
    const fresh = items.filter((s) => !seen.has(s.url) && seen.add(s.url));
    state.results = append ? [...state.results, ...fresh] : fresh;
    state.offset += PAGE;
    const hasQuery = $('#q').value.trim() || $('#tag').value;
    info.textContent = state.results.length
      ? (hasQuery ? `Výsledky (${state.results.length}${data.length === PAGE ? '+' : ''})` : 'Najpopulárnejšie')
      : 'Nič sa nenašlo. Skús iný názov, žáner alebo krajinu.';
    $('#moreBtn').hidden = data.length < PAGE;
    renderResults();
  } catch {
    if (seq !== searchSeq) return;
    info.textContent = 'Nepodarilo sa načítať rádiá. Skontroluj pripojenie.';
  }
}

function renderResults() {
  const ul = $('#results');
  ul.innerHTML = '';
  for (const s of state.results) {
    const li = document.createElement('li');
    const active = state.current?.id === s.id && state.status !== 'idle';
    if (active) li.className = 'playing';
    li.append(logoEl(s));
    const sub = [s.countrycode, s.tags, s.bitrate ? s.bitrate + ' kbps' : ''].filter(Boolean).join(' · ');
    li.insertAdjacentHTML('beforeend',
      `<div class="meta"><strong>${esc(s.name)}</strong><small>${esc(sub)}</small></div>
       <button class="icon-btn fav ${isFav(s.id) ? 'on' : ''}" aria-label="Obľúbené">${isFav(s.id) ? '★' : '☆'}</button>`);
    li.addEventListener('click', (e) => {
      if (e.target.closest('.fav')) return toggleFav(s);
      if (active && state.status !== 'error') togglePlay();
      else play(s);
    });
    ul.append(li);
  }
}

async function loadCountries() {
  const sel = $('#country');
  const names = new Intl.DisplayNames(['sk'], { type: 'region' });
  const saved = load(LS_COUNTRY, null);
  const guess = (navigator.language.split('-')[1] || 'SK').toUpperCase();
  try {
    const data = await api('countries', { hidebroken: 'true' });
    const list = data
      .filter((c) => c.iso_3166_1 && c.stationcount > 0)
      .map((c) => {
        let label = c.name;
        try { label = names.of(c.iso_3166_1) || c.name; } catch {}
        return { code: c.iso_3166_1.toUpperCase(), label, n: c.stationcount };
      });
    // tá istá krajina môže byť v dátach viackrát – zlúčime
    const merged = new Map();
    for (const c of list) {
      const m = merged.get(c.code);
      if (m) m.n += c.n; else merged.set(c.code, c);
    }
    [...merged.values()]
      .sort((a, b) => a.label.localeCompare(b.label, 'sk'))
      .forEach((c) => sel.add(new Option(`${flag(c.code)} ${c.label} (${c.n})`, c.code)));
  } catch {}
  const want = saved ?? guess;
  if ([...sel.options].some((o) => o.value === want)) sel.value = want;
}

function flag(cc) {
  return /^[A-Z]{2}$/.test(cc) ? String.fromCodePoint(...[...cc].map((c) => 0x1f1a5 + c.charCodeAt(0))) : '';
}

$('#searchForm').addEventListener('submit', (e) => {
  e.preventDefault();
  document.activeElement?.blur();
  search();
});
$('#q').addEventListener('input', () => {
  clearTimeout(debounce);
  debounce = setTimeout(() => search(), 450);
});
$('#tag').addEventListener('change', () => {
  save(LS_TAG, $('#tag').value);
  search();
});
$('#country').addEventListener('change', () => {
  save(LS_COUNTRY, $('#country').value);
  search();
});
$('#moreBtn').addEventListener('click', () => search(true));

// ---------- Nastavenia ----------
$('#exportBtn').addEventListener('click', async () => {
  const json = JSON.stringify({ app: 'radio', version: 1, favorites: state.favs }, null, 2);
  const file = new File([json], 'radio-oblubene.json', { type: 'application/json' });
  if (navigator.canShare?.({ files: [file] })) {
    try { await navigator.share({ files: [file], title: 'Obľúbené rádiá' }); return; } catch (e) { if (e.name === 'AbortError') return; }
  }
  const a = document.createElement('a');
  a.href = URL.createObjectURL(file);
  a.download = file.name;
  a.click();
  setTimeout(() => URL.revokeObjectURL(a.href), 1000);
});

$('#importFile').addEventListener('change', async (e) => {
  const f = e.target.files[0];
  if (!f) return;
  try {
    const data = JSON.parse(await f.text());
    const list = Array.isArray(data) ? data : data.favorites;
    if (!Array.isArray(list)) throw new Error();
    let added = 0;
    for (const s of list) {
      if (s?.id && s?.url && !isFav(s.id)) { state.favs.push(s); added++; }
    }
    saveFavs();
    renderFavs();
    toast(`Importovaných: ${added}`);
  } catch {
    toast('Neplatný súbor zálohy');
  }
  e.target.value = '';
});

$('#manualForm').addEventListener('submit', (e) => {
  e.preventDefault();
  const name = $('#mName').value.trim();
  const url = $('#mUrl').value.trim();
  if (!name || !url) return;
  state.favs.push({ id: 'manual-' + Date.now(), name, url, favicon: '', country: '', countrycode: '', tags: '', codec: '', bitrate: 0 });
  saveFavs();
  renderFavs();
  e.target.reset();
  toast('Pridané do obľúbených ★');
});

// ---------- Navigácia ----------
const TITLES = { home: 'Obľúbené', search: 'Hľadať', settings: 'Nastavenia' };
let searchedOnce = false;

function show(view) {
  state.view = view;
  if (view !== 'home') state.editing = false;
  document.querySelectorAll('.view').forEach((v) => v.classList.toggle('active', v.id === 'view-' + view));
  document.querySelectorAll('.tabs button').forEach((b) => b.classList.toggle('active', b.dataset.view === view));
  $('#title').textContent = TITLES[view];
  renderFavs();
  window.scrollTo(0, 0);
  if (view === 'search' && !searchedOnce) {
    searchedOnce = true;
    countriesReady.then(() => search());
  }
}

document.querySelectorAll('.tabs button').forEach((b) => b.addEventListener('click', () => show(b.dataset.view)));
document.querySelectorAll('[data-goto]').forEach((b) => b.addEventListener('click', () => show(b.dataset.goto)));
$('#editBtn').addEventListener('click', () => { state.editing = !state.editing; renderFavs(); });

// ---------- Štart ----------
loadGenres();
const countriesReady = loadCountries();
const last = load(LS_LAST, null);
if (last) { state.current = last; state.status = 'idle'; updateMediaSession(); }
show(state.favs.length ? 'home' : 'search');
renderPlayer();

if ('serviceWorker' in navigator && location.protocol === 'https:') {
  navigator.serviceWorker.register('sw.js').catch(() => {});
}
