"""One private screening, with an authoritative clock and revocable guest URL."""
import asyncio
import contextlib
import hashlib
import json
import math
import os
from pathlib import Path
import re
import secrets
import shutil
import time

from aiohttp import web

ASSETS = Path(__file__).parent
VIDEO_EXTENSIONS = {'.mkv', '.mp4', '.m4v', '.avi', '.mov', '.webm'}


class Room:
    def __init__(self, library, cache, ffmpeg='ffmpeg', ffprobe='ffprobe'):
        self.library = Path(library).resolve()
        self.cache = Path(cache)
        self.cache.mkdir(parents=True, exist_ok=True)
        self.ffmpeg, self.ffprobe = ffmpeg, ffprobe
        self.token = None
        self.process = None
        self.generation = 0
        self.base = self.position = self.duration = 0.0
        self.updated = time.monotonic()
        self.playing = False
        self.preparing = False
        self.error = None
        self.title = ''
        self.expires = 0.0
        self.lock = asyncio.Lock()

    def catalog(self):
        result = {}
        for path in self.library.rglob('*'):
            if path.suffix.lower() in VIDEO_EXTENSIONS and path.is_file():
                resolved = path.resolve()
                if resolved.is_relative_to(self.library):
                    key = hashlib.sha256(str(path.relative_to(self.library)).encode()).hexdigest()
                    result[key] = (resolved, path.parent.name)
        return result

    def snapshot(self):
        position = self.position
        if self.playing and not self.preparing:
            position += time.monotonic() - self.updated
        return dict(generation=self.generation, base=self.base,
                    position=min(position, self.duration), duration=self.duration,
                    playing=self.playing and position < self.duration,
                    preparing=self.preparing, error=self.error, title=self.title)

    async def kill(self):
        if self.process and self.process.returncode is None:
            self.process.terminate()
            try:
                await asyncio.wait_for(self.process.wait(), 5)
            except TimeoutError:
                self.process.kill()
                await self.process.wait()
        self.process = None

    async def stop(self):
        self.token = None  # Revoke access before stopping the encoder.
        self.playing = False
        await self.kill()
        for child in self.cache.iterdir():
            if child.is_dir():
                shutil.rmtree(child)

    async def start(self, item):
        catalog = await asyncio.to_thread(self.catalog)
        if item not in catalog:
            raise web.HTTPBadRequest(text='Choose a movie from the library.')
        path, title = catalog[item]
        probe = await asyncio.create_subprocess_exec(
            self.ffprobe, '-v', 'error', '-show_entries', 'format=duration',
            '-of', 'json', str(path), stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.DEVNULL)
        try:
            output, _ = await asyncio.wait_for(probe.communicate(), 20)
            duration = float(json.loads(output)['format']['duration'])
            if probe.returncode or not math.isfinite(duration) or not 0 < duration <= 21600:
                raise ValueError()
        except (TimeoutError, ValueError, KeyError):
            if probe.returncode is None:
                probe.kill()
                await probe.wait()
            raise web.HTTPBadRequest(text='Cannot read this movie (maximum length: 6 hours).')
        await self.stop()
        self.path, self.title, self.duration = path, title, duration
        self.token = secrets.token_urlsafe(32)
        self.expires = time.monotonic() + 12 * 3600
        await self.seek(0, True)

    async def seek(self, position, playing):
        if shutil.disk_usage(self.cache).free < 512 * 1024 * 1024:
            raise web.HTTPInsufficientStorage(text='Not enough free space to prepare the movie.')
        await self.kill()
        for child in self.cache.iterdir():
            if child.is_dir():
                shutil.rmtree(child)
        self.generation += 1
        directory = self.cache / str(self.generation)
        directory.mkdir()
        self.base = self.position = position
        self.playing, self.preparing, self.error = playing, True, None
        self.updated = self.preparation_started = time.monotonic()
        # One shared H.264/AAC rendition. Event HLS keeps earlier segments so
        # guests can recover from buffering without advancing the room clock.
        self.process = await asyncio.create_subprocess_exec(
            self.ffmpeg, '-hide_banner', '-loglevel', 'error', '-nostdin',
            '-readrate', '1', '-readrate_initial_burst', '20', '-ss', str(position),
            '-i', str(self.path), '-map', '0:v:0', '-map', '0:a:0?',
            '-sn', '-dn', '-map_metadata', '-1', '-threads', '4',
            '-vf', 'scale=w=1280:h=720:force_original_aspect_ratio=decrease:force_divisible_by=2',
            '-c:v', 'libx264', '-preset', 'veryfast', '-pix_fmt', 'yuv420p',
            '-b:v', '2500k', '-maxrate', '3000k', '-bufsize', '6000k',
            '-force_key_frames', 'expr:gte(t,n_forced*2)', '-sc_threshold', '0',
            '-c:a', 'aac', '-ac', '2', '-b:a', '128k',
            '-f', 'hls', '-hls_time', '2', '-hls_playlist_type', 'event',
            '-hls_segment_type', 'fmp4', '-hls_flags', 'independent_segments+temp_file',
            '-hls_segment_filename', str(directory / 'segment%06d.m4s'),
            str(directory / 'index.m3u8'),
            stdout=asyncio.subprocess.DEVNULL, stderr=asyncio.subprocess.DEVNULL)

    async def maintain(self):
        while True:
            await asyncio.sleep(0.25)
            async with self.lock:
                if not self.token:
                    continue
                if time.monotonic() >= self.expires:
                    await self.stop()
                    continue
                if self.process and self.process.returncode is None and shutil.disk_usage(self.cache).free < 256 * 1024 * 1024:
                    self.position = self.snapshot()['position']
                    self.playing = self.preparing = False
                    self.error = 'Screening stopped because the server is low on disk space.'
                    await self.kill()
                    continue
                manifest = self.cache / str(self.generation) / 'index.m3u8'
                if self.process and self.process.returncode not in (None, 0):
                    self.position = self.snapshot()['position']
                    self.playing = self.preparing = False
                    self.error = 'The movie could not be encoded. Ask the host to restart it.'
                elif self.preparing and manifest.exists():
                    self.preparing = False
                    self.updated = time.monotonic()
                elif self.preparing and time.monotonic() - self.preparation_started > 90:
                    self.playing = self.preparing = False
                    self.error = 'The movie took too long to prepare.'
                    await self.kill()


@web.middleware
async def headers(request, handler):
    try:
        response = await handler(request)
    except web.HTTPException as error:
        response = web.Response(status=error.status, text=error.text, headers=error.headers)
    response.headers.update({
        'Cache-Control': 'no-store', 'Referrer-Policy': 'no-referrer',
        'X-Content-Type-Options': 'nosniff',
        'Content-Security-Policy': "default-src 'self'; script-src 'self'; style-src 'self'; media-src 'self' blob:; worker-src 'self' blob:; connect-src 'self'; frame-ancestors 'none'",
    })
    return response


def applications(room, host_key, public_url, hls_js):
    async def guest(request):
        if (not room.token or time.monotonic() >= room.expires
                or not secrets.compare_digest(request.match_info['token'], room.token)):
            raise web.HTTPNotFound(text='This screening has ended.')
        name = request.match_info['name']
        if name == 'state':
            return web.json_response(room.snapshot())
        if name in ('', 'player.js', 'style.css'):
            return web.FileResponse(ASSETS / (name or 'player.html'))
        if name == 'hls.js':
            return web.FileResponse(hls_js)
        if re.fullmatch(r'\d+/(index\.m3u8|init\.mp4|segment\d+\.m4s)', name):
            generation, filename = name.split('/')
            if generation != str(room.generation):
                raise web.HTTPNotFound()
            file = room.cache / generation / filename
            if file.is_file():
                response = web.FileResponse(file)
                response.content_type = ('application/vnd.apple.mpegurl' if filename.endswith('.m3u8')
                                         else 'video/mp4')
                return response
        raise web.HTTPNotFound()

    async def host(request):
        name = request.match_info['name']
        if request.method == 'GET' and name in ('', 'host.js', 'style.css'):
            return web.FileResponse(ASSETS / (name or 'host.html'))
        if not secrets.compare_digest(request.headers.get('Authorization', ''), 'Bearer ' + host_key):
            raise web.HTTPUnauthorized()
        if request.method == 'GET' and name == 'api':
            catalog = await asyncio.to_thread(room.catalog)
            return web.json_response(dict(
                movies=[dict(id=k, title=v[1]) for k, v in sorted(catalog.items(), key=lambda kv: kv[1][1])],
                state=room.snapshot(),
                url=f'{public_url}/watch/{room.token}/' if room.token else None))
        if request.method != 'POST' or name != 'api':
            raise web.HTTPNotFound()
        try:
            data = await request.json()
            if not isinstance(data, dict):
                raise ValueError()
            action = data.get('action')
            if action not in ('start', 'stop', 'play', 'pause', 'seek'):
                raise ValueError()
            async with room.lock:
                if action == 'start':
                    if not isinstance(data.get('id'), str):
                        raise ValueError()
                    await room.start(data['id'])
                elif action == 'stop':
                    await room.stop()
                elif not room.token:
                    raise web.HTTPConflict(text='Start a screening first.')
                elif action == 'seek':
                    position = float(data['position'])
                    if not math.isfinite(position) or not 0 <= position < room.duration:
                        raise ValueError()
                    await room.seek(position, room.playing)
                else:
                    room.position = room.snapshot()['position']
                    room.updated = time.monotonic()
                    room.playing = action == 'play'
            return web.json_response({'ok': True})
        except (ValueError, TypeError, KeyError):
            raise web.HTTPBadRequest(text='Invalid playback command.')

    public = web.Application(middlewares=[headers], client_max_size=4096)
    public.router.add_get('/watch/{token}/{name:.*}', guest)
    private = web.Application(middlewares=[headers], client_max_size=4096)
    private.router.add_route('*', '/{name:.*}', host)
    return public, private


async def main():
    state = Path(os.environ.get('STATE_DIRECTORY', '/var/lib/watch-room'))
    state.mkdir(parents=True, exist_ok=True)
    key_file = state / 'host-key'
    if not key_file.exists():
        fd = os.open(key_file, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(fd, 'w') as stream:
            stream.write(secrets.token_urlsafe(32))
    room = Room(os.environ['WATCH_LIBRARY'], state / 'stream')
    await room.stop()  # Restart always revokes the previous screening.
    apps = applications(room, key_file.read_text().strip(), os.environ['WATCH_PUBLIC_URL'],
                        Path(os.environ['WATCH_HLS_JS']))
    runners = []
    task = asyncio.create_task(room.maintain())
    try:
        for app, port in zip(apps, (8098, 8099)):
            runner = web.AppRunner(app, access_log=None)
            await runner.setup()
            runners.append(runner)
            await web.TCPSite(runner, '127.0.0.1', port).start()
        await asyncio.Event().wait()
    finally:
        task.cancel()
        with contextlib.suppress(asyncio.CancelledError):
            await task
        await room.stop()
        for runner in runners:
            await runner.cleanup()


if __name__ == '__main__':
    asyncio.run(main())
