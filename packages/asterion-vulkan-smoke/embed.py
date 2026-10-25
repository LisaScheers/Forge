"""Embed little-endian SPIR-V words in naturally aligned C arrays."""

from pathlib import Path
import struct

with Path("shaders.h").open("w") as output:
    for filename, name in (("triangle.vert", "vertex"), ("triangle.frag", "fragment"), ("compute.comp", "compute")):
        binary = Path(filename + ".spv").read_bytes()
        words = struct.unpack("<" + "I" * (len(binary) // 4), binary)
        assert words[0] == 0x07230203
        output.write(f"static const uint32_t {name}_spirv[] = {{\n")
        output.write(",\n".join(", ".join(f"0x{word:08x}" for word in words[index:index + 8]) for index in range(0, len(words), 8)))
        output.write("\n};\n")
