"""Apply selected Nix preferences without replacing an application's private state."""

import copy
import json
import os
from pathlib import Path
import sys
import tempfile
import xml.etree.ElementTree as ET

import yaml


def merge(current, selected):
    if isinstance(selected, dict):
        if not isinstance(current, dict):
            raise ValueError("Expected a settings object")
        result = copy.deepcopy(current)
        for key, value in selected.items():
            result[key] = merge(result[key], value) if key in result else copy.deepcopy(value)
        return result
    if isinstance(selected, list) and selected and all(
        isinstance(item, dict) and "id" in item for item in selected
    ):
        if not isinstance(current, list):
            raise ValueError("Expected a provider list")
        result = copy.deepcopy(current)
        for item in selected:
            matches = [i for i, old in enumerate(result) if old.get("id") == item["id"]]
            if len(matches) > 1:
                raise ValueError("Duplicate provider identifier")
            if matches:
                result[matches[0]] = merge(result[matches[0]], item)
            else:
                result.append(copy.deepcopy(item))
        return result
    return copy.deepcopy(selected)


def merge_freecad(current, selected):
    if current.tag != selected.tag:
        raise ValueError("Unexpected FreeCAD document root")
    for item in selected:
        matches = [child for child in current if (child.tag, child.get("Name")) == (item.tag, item.get("Name"))]
        if len(matches) > 1:
            raise ValueError("Duplicate FreeCAD preference")
        if item.tag == "FCParamGroup" and matches:
            merge_freecad(matches[0], item)
        else:
            if matches:
                current.remove(matches[0])
            current.append(copy.deepcopy(item))


def llsd_pairs(root):
    if root.tag != "llsd" or len(root) != 1 or root[0].tag != "map":
        raise ValueError("Expected an LLSD settings map")
    children = list(root[0])
    if len(children) % 2 or any(child.tag != "key" for child in children[::2]):
        raise ValueError("Malformed LLSD settings map")
    pairs = list(zip(children[::2], children[1::2]))
    if len({key.text for key, _ in pairs}) != len(pairs):
        raise ValueError("Duplicate LLSD preference")
    return pairs


def render(current, source, kind):
    if kind in {"json", "yaml"}:
        load = json.loads if kind == "json" else yaml.safe_load
        selected = load(source)
        live = load(current) if current.strip() else ({} if isinstance(selected, dict) else [])
        updated = merge(live, selected)
        if updated == live:
            return current
        return json.dumps(updated, indent=2, ensure_ascii=False) + "\n" if kind == "json" else yaml.safe_dump(updated, sort_keys=False)
    if kind == "lines":
        selected = json.loads(source)
        lines = current.splitlines()
        for key, value in selected.items():
            positions = [i for i, line in enumerate(lines) if line.split("=", 1)[0] == key]
            if len(positions) > 1:
                raise ValueError("Duplicate preference key")
            line = f"{key}={value}"
            if positions:
                lines[positions[0]] = line
            else:
                lines.append(line)
        return "\n".join(lines) + "\n"
    if kind not in {"llsd", "freecad", "xml"}:
        raise ValueError("Unsupported preference format")
    selected = ET.fromstring(source)
    if not current.strip():
        return source
    live = ET.fromstring(current)
    if kind == "xml":
        if live.tag != selected.tag:
            raise ValueError("Unexpected XML document root")
        return current if ET.tostring(live) == ET.tostring(selected) else source
    before = ET.tostring(live)
    if kind == "freecad":
        merge_freecad(live, selected)
    else:
        existing = {key.text: (key, value) for key, value in llsd_pairs(live)}
        for key, value in llsd_pairs(selected):
            if key.text in existing:
                old_key, old_value = existing[key.text]
                if ET.tostring(old_value) == ET.tostring(value):
                    continue
                offset = list(live[0]).index(old_key)
                live[0].remove(old_value)
                live[0].insert(offset + 1, copy.deepcopy(value))
            else:
                live[0].extend([copy.deepcopy(key), copy.deepcopy(value)])
    if ET.tostring(live) == before:
        return current
    ET.indent(live, space="  ")
    return ET.tostring(live, encoding="unicode", xml_declaration=True) + "\n"


def sync(home, entry):
    relative = Path(entry["target"])
    if relative.is_absolute() or ".." in relative.parts:
        raise ValueError("Preference targets must be relative to the home directory")
    target = home / relative
    if target.is_symlink() or not target.resolve().is_relative_to(home.resolve()):
        raise ValueError("Refusing to replace a symlink or a target outside the home directory")
    original = target.read_bytes() if target.exists() else b""
    updated = render(original.decode(), Path(entry["source"]).read_text(), entry["format"]).encode()
    if updated == original:
        return
    target.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix=".nix-preferences-", dir=target.parent)
    try:
        with os.fdopen(fd, "wb") as output:
            output.write(updated)
        # Do not silently overwrite app edits made while preparing the update.
        if (target.read_bytes() if target.exists() else b"") != original:
            raise RuntimeError("Application changed preferences during activation")
        os.replace(temporary, target)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


if __name__ == "__main__":
    home = Path(sys.argv[1])
    for entry in json.loads(Path(sys.argv[2]).read_text()):
        sync(home, entry)
