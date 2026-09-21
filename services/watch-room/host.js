'use strict';
sessionStorage.removeItem('watch-host-key');
history.replaceState(null, '', location.pathname);
const movie = document.querySelector('#movie'), message = document.querySelector('#message');
let trackSignature = '';
let busy = false, initialized = false, dragging = false;
async function api(command) {
  const response = await fetch('api', {
    method: command ? 'POST' : 'GET',
    headers: {'Content-Type': 'application/json'},
    body: command ? JSON.stringify(command) : undefined,
    signal: AbortSignal.timeout(30000)
  });
  if (response.status === 401) {
    location.replace('/');
    throw new Error('Redirecting to sign in…');
  }
  if (!response.ok) throw new Error(await response.text());
  return response.json();
}
function time(seconds) { return new Date(seconds * 1000).toISOString().slice(11, 19); }
async function refresh() {
  if (busy) return;
  try {
    const data = await api();
    if (!initialized) {
      movie.replaceChildren(...data.movies.map(item => new Option(item.title, item.id)));
      initialized = true;
    }
    const signature = JSON.stringify([data.tracks, data.audio, data.subtitle, Boolean(data.url)]);
    if (signature !== trackSignature) {
      trackSignature = signature;
      for (const kind of ['audio', 'subtitle']) {
        const select = document.querySelector(`#${kind}`);
        const options = data.tracks[kind].map(track => new Option(track.label, track.id));
        if (kind === 'subtitle') options.unshift(new Option('Off', ''));
        if (kind === 'audio' && !options.length) options.push(new Option('No audio', ''));
        select.replaceChildren(...options);
        select.value = data[kind] === null ? '' : String(data[kind]);
        select.disabled = !data.url || !data.tracks[kind].length;
      }
    }
    document.querySelector('#tracks').disabled = !data.url;
    const guest = document.querySelector('#guest');
    guest.textContent = data.url || ''; guest.href = data.url || '#';
    const seek = document.querySelector('#seek');
    seek.max = Math.max(0, data.state.duration - 1);
    if (!dragging) seek.value = data.state.position;
    document.querySelector('#position').textContent = `${time(data.state.position)} / ${time(data.state.duration)}`;
    message.textContent = data.state.error || (data.url ? (data.state.preparing ? 'Preparing…' : data.state.playing ? 'Playing' : 'Paused') : 'No active screening');
  } catch (error) { message.textContent = error.message; }
}
async function command(action, extra = {}) {
  busy = true;
  document.querySelectorAll('button').forEach(button => { button.disabled = true; });
  try { await api({action, ...extra}); }
  catch (error) { message.textContent = error.message; }
  finally {
    busy = false;
    document.querySelectorAll('button').forEach(button => { button.disabled = false; });
  }
  await refresh();
}
document.querySelector('#tracks').onclick = () => command('tracks', Object.fromEntries(
  ['audio', 'subtitle'].map(kind => {
    const value = document.querySelector(`#${kind}`).value;
    return [kind, value === '' ? null : Number(value)];
  })
));
for (const action of ['play', 'pause', 'stop']) document.querySelector(`#${action}`).onclick = () => command(action);
document.querySelector('#start').onclick = () => command('start', {id: movie.value});
document.querySelector('#seek').addEventListener('input', () => { dragging = true; });
document.querySelector('#seek').addEventListener('change', event => { dragging = false; command('seek', {position: Number(event.target.value)}); });
refresh(); setInterval(refresh, 2000);
