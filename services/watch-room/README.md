# Synchronized screening

One fullscreen web page per viewer, backed by an authoritative room clock.
The host chooses a local movie; one FFmpeg process makes shared 720p H.264/AAC
HLS segments. Guests poll position/play/pause state each second. Small drift
uses a 3% playback-rate correction; drift over 1.2 seconds seeks back into sync.
This is approximate synchronization, not frame-accurate broadcast playback.
On lost backend contact, the player pauses until it reconnects.

The movie library is read-only. No Jellyfin account or API key is needed.
The guest URL has a random 256-bit token, permits only the current screening,
expires after 12 hours, and is revoked on stop, replacement, or service restart.
Anyone with that URL can watch and download the active screening. It is not DRM.
Tokens are excluded from application and nginx access logs. No external scripts
or analytics are loaded by guests; HLS.js is pinned and served locally.

## Host controls

Open `https://watch.local.bylisa.dev/` on the home network or Tailscale with
local DNS available. nginx allows only the management LAN, main LAN, and
Tailscale address ranges; external clients are denied even with a forced DNS
override. A dedicated ACME certificate covers this exact local hostname.

Sign in with Authentik as `lisa`. The Authentik application policy and backend
both restrict host access to that account. No host key is needed; old host keys
are no longer accepted. Existing guest links still require no sign-in.

nginx checks every host request with Authentik's embedded outpost over verified
HTTPS, replaces the identity header with that response, and connects to a Unix
socket accessible only to the service and nginx. There is no host TCP listener.
Commands require the exact console Origin and JSON content type to prevent CSRF.
An expired session redirects the host back to Authentik. Authentik unavailability
fails closed. The guest endpoint does not use Authentik.

The Atlas blueprint defines the proxy provider, application, and Lisa-only user
binding. Its service adds the provider to the embedded outpost without replacing
the existing provider list. Deploy Atlas before Nook for this authentication
migration. Use `/outpost.goauthentik.io/sign_out` on the console to sign out.

Choose a movie and Start screening. Paste the guest URL into the Second Life
screen's web media URL. Guests may need to click Join screening once to enable
playback/audio. Play, Pause, and seeking on the host page affect everyone.
Seeking rebuilds the stream from the selected position and briefly buffers.
Mute and fullscreen on the guest page are local controls only.

Transcoding runs at approximately playback speed with a 20-second initial
buffer. Segments are retained until seeking, stopping, expiration, or restart;
allow roughly 9 GB free space for a maximum six-hour movie. There is one
screening per server. Encoding stops if free space falls below 256 MB.
Each guest consumes up to about 3.2 Mbps of home upload.
The host can select embedded audio and subtitle tracks after starting a screening.
Apply tracks changes them for everyone, preserving position and play/pause state
while the stream rebuilds. Subtitles default to Off and are burned into the video;
text and bitmap subtitle tracks are supported. External subtitle files and HDR
tone mapping are not provided.
Second Life embedded-browser playback still requires an in-world acceptance test.

## Verification

```sh
nix-shell -p 'python3.withPackages (ps: [ ps.aiohttp ])' ffmpeg nodejs --run \
  'cd services/watch-room && python3 -m unittest -v && node --check player.js && node --check host.js'
```

Tests use a generated clip and cover the shared clock, pause, late joins,
authorization, identity restrictions, CSRF, expiry, revocation, path boundaries,
real HLS encoding, and seek.
The public player uses `/watch/` on the existing Jellyfin HTTPS host. The host
console uses its own local DNS record and certificate; no router changes are needed.
