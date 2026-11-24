"""Validate every skill directory passed on the command line.

Clients load a skill by its frontmatter, so a missing name or description, a
name that differs from its directory, or a broken bundled file reference makes
the skill silently unusable.
"""

import re
import sys
from pathlib import Path

import yaml

NAME = re.compile(r"^[a-z0-9][a-z0-9-]*$")
# Reference documents a skill tells the agent to open. Scripts and assets may
# name files in another repository or a packaged build, so only these are checked.
BUNDLED = re.compile(r"(?<![\w/.-])(?:\./)?(references/[\w./-]*\w)")
# `---` closes the frontmatter only on a line of its own, not inside a value.
FRONTMATTER = re.compile(r"\A---\n(.*?)^---$\n?(.*)", re.S | re.M)


def problems(skill):
    source = skill / "SKILL.md"
    if not source.is_file():
        return [f"{skill}: no SKILL.md"]
    text = source.read_text(encoding="utf-8")
    match = FRONTMATTER.match(text)
    if not match:
        return [f"{source}: no YAML frontmatter"]
    try:
        meta = yaml.safe_load(match[1]) or {}
    except yaml.YAMLError as error:
        return [f"{source}: invalid YAML frontmatter: {error}"]
    found = []
    name = meta.get("name")
    if name != skill.name or not NAME.match(str(name)):
        found.append(f"{source}: name {name!r} must equal the directory name {skill.name!r}")
    description = meta.get("description")
    if not isinstance(description, str) or not description.strip():
        found.append(f"{source}: missing description")
    elif len(description) > 1024:
        found.append(f"{source}: description is {len(description)} characters; clients truncate after 1024")
    for reference in sorted(set(BUNDLED.findall(match[2]))):
        if not (skill / reference).exists():
            found.append(f"{source}: references missing {reference}")
    return found


def main():
    skills = [path for root in sys.argv[1:] for path in sorted(Path(root).iterdir()) if path.is_dir()]
    found = [problem for skill in skills for problem in problems(skill)]
    for problem in found:
        print(problem, file=sys.stderr)
    if found:
        sys.exit(1)
    print(f"{len(skills)} skills checked")


if __name__ == "__main__":
    main()
