import ctypes as c
import sys

decoder = c.CDLL(sys.argv[1])
encoder = c.CDLL(sys.argv[2])
decoder.BrotliDecoderCreateInstance.restype = c.c_void_p
decoder.BrotliDecoderDestroyInstance.argtypes = [c.c_void_p]
get_error = getattr(decoder, "BrotliDecoderGetErrorCode", None)
if get_error:
    get_error.argtypes = [c.c_void_p]
decoder.BrotliDecoderDecompressStream.argtypes = [
    c.c_void_p, c.POINTER(c.c_size_t), c.POINTER(c.c_void_p),
    c.POINTER(c.c_size_t), c.POINTER(c.c_void_p), c.c_void_p,
]

def decode(data, chunk_size=None):
    state = decoder.BrotliDecoderCreateInstance(None, None, None)
    output = bytearray()
    chunk_size = chunk_size or len(data)
    for start in range(0, len(data), chunk_size):
        chunk = data[start:start + chunk_size]
        source = c.create_string_buffer(chunk)
        available_in = c.c_size_t(len(chunk))
        next_in = c.c_void_p(c.addressof(source))
        while True:
            target = c.create_string_buffer(65536)
            available_out = c.c_size_t(len(target))
            next_out = c.c_void_p(c.addressof(target))
            result = decoder.BrotliDecoderDecompressStream(
                state, c.byref(available_in), c.byref(next_in),
                c.byref(available_out), c.byref(next_out), None,
            )
            output.extend(target.raw[:len(target) - available_out.value])
            assert len(output) < 32 * 1024 * 1024
            if result != 3:
                break
        if result in (0, 1):
            break
    error = get_error(state) if get_error else None
    decoder.BrotliDecoderDestroyInstance(state)
    return result, error, bytes(output)

message = b"A legitimate Brotli message. " * 100
encoded = c.create_string_buffer(65536)
encoded_size = c.c_size_t(len(encoded))
assert encoder.BrotliEncoderCompress(5, 22, 0, len(message), message,
                                    c.byref(encoded_size), encoded) == 1
valid = encoded.raw[:encoded_size.value]
# Node's upstream regression input exercises the original invalid block switch.
# https://github.com/nodejs/node/commit/b5f41529df78a8af7b395abd6a97d2dcb6c52c61
invalid = bytes.fromhex("200010414141fcffff07002228f00b60f7f41f000000")
for chunk_size in (len(invalid), 1):
    control = decode(valid, chunk_size)
    assert control[0] == 1 and control[2] == message, control[:2]
    result, error, _ = decode(invalid, chunk_size)
    assert result == 0 and error in (-17, None), (result, error)
print("Brotli rejects invalid block switches whole and bytewise; valid data round-trips")
