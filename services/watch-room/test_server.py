import asyncio
import contextlib
import json
from pathlib import Path
import tempfile
import time
import unittest

from aiohttp.test_utils import TestClient, TestServer

from server import Room, applications


class WatchTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.library = self.root / 'movies'
        self.library.mkdir()
        self.room = Room(self.library, self.root / 'cache')
        public, private = applications(self.room, 'host-secret', 'https://example.test', self.root / 'hls.js')
        self.guest = TestClient(TestServer(public))
        self.host = TestClient(TestServer(private))
        await self.guest.start_server()
        await self.host.start_server()
        self.auth = {'Authorization': 'Bearer host-secret'}

    async def asyncTearDown(self):
        await self.room.stop()
        await self.guest.close()
        await self.host.close()
        self.temp.cleanup()

    async def test_clock_pause_and_late_join(self):
        self.room.token = 'guest'
        self.room.expires = time.monotonic() + 30
        self.room.duration = 100
        self.room.position = 20
        self.room.updated = time.monotonic() - 5
        self.room.playing = True
        first = await (await self.guest.get('/watch/guest/state')).json()
        second = await (await self.guest.get('/watch/guest/state')).json()
        self.assertAlmostEqual(first['position'], 25, delta=.2)
        self.assertAlmostEqual(first['position'], second['position'], delta=.1)
        response = await self.host.post('/api', json={'action': 'pause'}, headers=self.auth)
        self.assertEqual(response.status, 200)
        position = self.room.snapshot()['position']
        await asyncio.sleep(.05)
        self.assertEqual(self.room.snapshot()['position'], position)
        self.assertFalse(self.room.snapshot()['playing'])

    async def test_access_boundaries_and_revocation(self):
        self.room.token = 'guest'
        self.room.expires = time.monotonic() + 30
        self.assertEqual((await self.guest.get('/watch/wrong/state')).status, 404)
        self.assertEqual((await self.guest.post('/watch/guest/state', json={})).status, 405)
        self.assertEqual((await self.guest.get('/api')).status, 404)
        self.assertEqual((await self.host.get('/api')).status, 401)
        self.assertEqual((await self.host.post('/api', json={'action': 'stop'})).status, 401)
        page = await self.guest.get('/watch/guest/')
        self.assertNotIn('host-secret', await page.text())
        self.assertEqual(page.headers['Referrer-Policy'], 'no-referrer')
        self.assertEqual((await self.guest.get('/watch/guest/0/host-key')).status, 404)
        await self.host.post('/api', json={'action': 'stop'}, headers=self.auth)
        self.assertEqual((await self.guest.get('/watch/guest/state')).status, 404)

    async def test_expiry_and_untrusted_paths(self):
        self.room.token = 'guest'
        self.room.expires = time.monotonic() - 1
        self.assertEqual((await self.guest.get('/watch/guest/state')).status, 404)
        (self.library / 'escape.mp4').symlink_to('/etc/passwd')
        self.assertEqual(self.room.catalog(), {})
        for data in ({'action': 'start', 'id': '../../etc/passwd'}, [], {'action': 'unknown'}):
            self.assertEqual((await self.host.post('/api', json=data, headers=self.auth)).status, 400)

    async def test_actual_encoder_seek_and_segments(self):
        # Use a synthetic clip, not anything from the user's movie library.
        movie = self.library / 'test.mp4'
        process = await asyncio.create_subprocess_exec(
            'ffmpeg', '-v', 'error', '-f', 'lavfi', '-i', 'testsrc2=size=320x180:rate=24',
            '-f', 'lavfi', '-i', 'sine=frequency=440', '-t', '8', '-c:v', 'libx264',
            '-c:a', 'aac', str(movie))
        self.assertEqual(await process.wait(), 0)
        task = asyncio.create_task(self.room.maintain())
        try:
            item = next(iter(self.room.catalog()))
            response = await self.host.post('/api', json={'action': 'start', 'id': item}, headers=self.auth)
            self.assertEqual(response.status, 200, await response.text())
            token = self.room.token
            for _ in range(100):
                if not self.room.preparing:
                    break
                await asyncio.sleep(.1)
            self.assertFalse(self.room.preparing)
            self.assertIsNone(self.room.error)
            manifest = await self.guest.get(f'/watch/{token}/1/index.m3u8')
            self.assertEqual(manifest.status, 200)
            self.assertIn('#EXTM3U', await manifest.text())
            self.assertEqual((await self.guest.get(f'/watch/{token}/1/init.mp4')).status, 200)
            for value in (-1, 'NaN', 99999):
                result = await self.host.post('/api', json={'action': 'seek', 'position': value}, headers=self.auth)
                self.assertEqual(result.status, 400)
            result = await self.host.post('/api', json={'action': 'seek', 'position': 3}, headers=self.auth)
            self.assertEqual(result.status, 200)
            self.assertEqual(self.room.generation, 2)
            self.assertEqual(self.room.base, 3)
            self.assertEqual((await self.guest.get(f'/watch/{token}/1/index.m3u8')).status, 404)
        finally:
            task.cancel()
            with contextlib.suppress(asyncio.CancelledError):
                await task


if __name__ == '__main__':
    unittest.main()
