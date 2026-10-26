const assert = require('node:assert/strict');
const { Readable } = require('node:stream');
const { pipeline } = require('node:stream/promises');
const zlib = require('node:zlib');

const invalid = Buffer.from('200010414141fcffff07002228f00b60f7f41f000000', 'hex');
const message = Buffer.from('A legitimate Brotli message. '.repeat(100));
assert.deepEqual(zlib.brotliDecompressSync(zlib.brotliCompressSync(message)), message);
assert.throws(() => zlib.brotliDecompressSync(invalid), { errno: -17 });
(async () => {
  const decoder = zlib.createBrotliDecompress();
  decoder.resume();
  await assert.rejects(pipeline(
    Readable.from([...invalid].map(byte => Buffer.from([byte]))), decoder,
  ), { errno: -17 });
  console.log(`${process.version}: invalid blocks rejected whole and bytewise; valid data round-trips`);
})().catch(error => { console.error(error); process.exitCode = 1; });
