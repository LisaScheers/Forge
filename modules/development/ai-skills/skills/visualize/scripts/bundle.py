#!/usr/bin/env python3
"""Embed selected Nix-provided visualization runtimes and notices into HTML."""

import argparse
from html import escape
from pathlib import Path
import re
import sys

RUNTIMES = {
    "<!-- ECHARTS_RUNTIME -->": ("echarts.min.js", "LICENSE", "NOTICE"),
    "<!-- THREE_RUNTIME -->": ("three.min.js", "three-LICENSE"),
    "<!-- THREEDMOL_RUNTIME -->": ("3Dmol-min.js", "3Dmol-LICENSE", "3Dmol-NOTICES"),
}


def bundle(source, output, runtime_dir):
    if source.resolve() == output.resolve():
        raise ValueError("Use different draft and output paths; retain the editable draft.")
    document = source.read_text(encoding="utf-8")
    selected = [marker for marker in RUNTIMES if marker in document]
    if not selected:
        raise ValueError("The draft has no supported runtime marker; native Canvas needs no bundling.")
    for marker in selected:
        if document.count(marker) != 1:
            raise ValueError(f"The draft must contain exactly one {marker} marker.")
    notice_markers = ("<!-- VISUALIZE_NOTICES -->", "<!-- ECHARTS_NOTICES -->")
    if sum(document.count(marker) for marker in notice_markers) != 1:
        raise ValueError("The draft must contain exactly one notices marker.")
    notices_marker = next(marker for marker in notice_markers if marker in document)

    required = [runtime_dir / name for marker in selected for name in RUNTIMES[marker]]
    missing = [str(file_path) for file_path in required if not file_path.is_file()]
    if missing:
        raise ValueError(
            "Missing Nix-packaged runtime files: " + ", ".join(missing)
            + ". Run the packaged skill or pass --runtime-dir with those files."
        )

    notices = []
    for marker in selected:
        runtime_name, *license_names = RUNTIMES[marker]
        runtime = (runtime_dir / runtime_name).read_text(encoding="utf-8")
        # Prevent a literal closing tag inside library strings ending the HTML script.
        runtime = re.sub(r"</script", lambda match: "<\\/" + match[0][2:], runtime, flags=re.I)
        runtime = re.sub(r"(?m)^//# sourceMappingURL=.*$", "", runtime)
        notices.extend((runtime_dir / name).read_text(encoding="utf-8") for name in license_names)
        document = document.replace(marker, f"<script>\n{runtime}\n</script>")
    document = document.replace(
        notices_marker,
        '<details class="licenses"><summary>Open-source licenses</summary><pre>'
        + escape("\n\n".join(notices)) + "</pre></details>",
    )
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(document, encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("draft", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument(
        "--runtime-dir", type=Path,
        default=Path(__file__).resolve().parents[1] / "assets" / "vendor",
    )
    args = parser.parse_args()
    try:
        bundle(args.draft, args.output, args.runtime_dir)
    except (OSError, ValueError) as error:
        print(f"Cannot bundle visualization: {error}", file=sys.stderr)
        return 1
    print(args.output.resolve())
    return 0


if __name__ == "__main__":
    sys.exit(main())
