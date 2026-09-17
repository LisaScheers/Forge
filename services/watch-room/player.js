'use strict';
const video = document.querySelector('video');
const join = document.querySelector('#join');
const message = document.querySelector('#message');
let hls, generation = -1, state, receivedAt = 0, joined = false, stopped = false;
function tell(text) { message.textContent = text; message.hidden = !text; }
function clearMedia() {
  video.pause();
  if (hls) { hls.destroy(); hls = undefined; }
  video.removeAttribute('src'); video.load();
}
function sync() {
  if (!state || stopped) return;
  if (state.error || state.preparing) {
    video.pause(); tell(state.error || 'Preparing movie…'); return;
  }
  if (generation !== state.generation) {
    clearMedia(); generation = state.generation;
    const source = `${generation}/index.m3u8`;
    if (Hls.isSupported()) {
      hls = new Hls({startPosition: Math.max(0, state.position - state.base)});
      hls.loadSource(source); hls.attachMedia(video);
      hls.on(Hls.Events.ERROR, (_event, data) => {
        if (data.fatal) {
          tell('Reconnecting…'); clearMedia(); generation = -1;
        }
      });
    } else if (video.canPlayType('application/vnd.apple.mpegurl')) video.src = source;
    else { tell('This viewer cannot play this video format.'); stopped = true; return; }
  }
  if (!joined || video.readyState < 1) return;
  const elapsed = state.playing ? (performance.now() - receivedAt) / 1000 : 0;
  const target = Math.max(0, Math.min(state.duration, state.position + elapsed) - state.base);
  const drift = target - video.currentTime;
  if (Math.abs(drift) > 1.2 || (!state.playing && Math.abs(drift) > 0.2)) {
    for (let i = 0; i < video.seekable.length; i++) {
      if (target >= video.seekable.start(i) && target <= video.seekable.end(i)) {
        video.currentTime = target; break;
      }
    }
  }
  video.playbackRate = state.playing && Math.abs(drift) > 0.2 && Math.abs(drift) <= 1.2
    ? (drift > 0 ? 1.03 : 0.97) : 1;
  if (state.playing) {
    video.play().catch(() => { joined = false; join.hidden = false; tell('Click to enable playback.'); });
    if (!video.paused) tell('');
  } else { video.pause(); tell('Paused by host'); }
}
async function poll() {
  const started = performance.now();
  try {
    const response = await fetch('state', {cache: 'no-store', signal: AbortSignal.timeout(4000)});
    if (response.status === 404) {
      stopped = true; clearMedia(); join.hidden = true; tell('This screening has ended.'); return;
    }
    if (!response.ok) throw new Error('Connection failed');
    state = await response.json();
    receivedAt = started + (performance.now() - started) / 2;
    sync();
  } catch {
    // A disconnected client must not keep drifting away from the host.
    state = undefined; video.pause(); tell('Connection lost. Reconnecting…');
  }
  if (!stopped) setTimeout(poll, 1000);
}
join.addEventListener('click', () => {
  joined = true; join.hidden = true;
  // Call play in the click handler to satisfy viewer autoplay policies.
  video.play().catch(() => {}); sync();
});
video.addEventListener('loadedmetadata', sync);
video.addEventListener('canplay', sync);
video.addEventListener('waiting', () => tell('Buffering…'));
document.addEventListener('visibilitychange', () => { if (!document.hidden) sync(); });
document.querySelector('#sound').addEventListener('click', (event) => {
  video.muted = !video.muted; event.target.textContent = video.muted ? 'Unmute' : 'Mute';
});
document.querySelector('#fullscreen').addEventListener('click', () => {
  if (document.fullscreenElement) document.exitFullscreen();
  else document.documentElement.requestFullscreen().catch(() => tell('Use your viewer’s media zoom.'));
});
poll();
