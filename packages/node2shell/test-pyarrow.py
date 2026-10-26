import importlib
import tempfile

import lancedb
import pyarrow as pa
import pyarrow.parquet as pq
from PIL import Image, ImageDraw, ImageFont

assert pa.__version__ == "25.0.1"
for module in ("csv", "dataset", "feather", "flight", "fs", "json", "orc", "parquet"):
    importlib.import_module(f"pyarrow.{module}")
for filesystem in ("AzureFileSystem", "GcsFileSystem", "HadoopFileSystem", "S3FileSystem"):
    assert hasattr(pa.fs, filesystem), filesystem
for codec in ("brotli", "bz2", "gzip", "lz4_frame", "lz4", "snappy", "zstd"):
    assert pa.Codec.is_available(codec), codec
assert set(pa.supported_memory_backends()) >= {"system", "jemalloc", "mimalloc"}
invalid = bytes.fromhex("200010414141fcffff07002228f00b60f7f41f000000")
for decompress in (
    lambda: pa.decompress(invalid, decompressed_size=32 * 1024 * 1024, codec="brotli"),
    lambda: pa.CompressedInputStream(pa.BufferReader(invalid), "brotli").read(),
):
    try:
        decompress()
    except (pa.ArrowInvalid, pa.ArrowIOError):
        pass
    else:
        raise AssertionError("Arrow accepted an invalid Brotli block switch")

table = pa.table({"id": [1, 2], "text": ["first", "second"],
                  "vector": pa.array([[1.0, 0.0], [0.0, 1.0]],
                                     type=pa.list_(pa.float32(), 2))})
buffer = pa.BufferOutputStream()
pq.write_table(table, buffer, compression="brotli")
assert pq.read_table(pa.BufferReader(buffer.getvalue())).equals(table)
with tempfile.TemporaryDirectory() as directory:
    database = lancedb.connect(directory)
    stored = database.create_table("regression", table)
    assert stored.search([1.0, 0.0]).limit(1).to_list()[0]["id"] == 1

image = Image.new("RGB", (200, 30))
ImageDraw.Draw(image).text((0, 0), "Brotli regression", font=ImageFont.load_default())
print("Patched Arrow rejects invalid blocks; Parquet, LanceDB and Pillow controls pass")
