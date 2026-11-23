import tempfile
import unittest
from pathlib import Path

from skills_catalogue import missing_references, render


class SkillsCatalogueTests(unittest.TestCase):
    def test_rows_show_clients_and_the_first_sentence(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        skill = Path(directory.name, "file-pr")
        skill.mkdir()
        (skill / "SKILL.md").write_text('---\nname: file-pr\ndescription: "Use when filing a PR. Also | more."\n---\nBody\n')
        text = render([
            {"name": "file-pr", "source": "bundled", "clients": ["Claude", "Codex"], "dir": str(skill)},
            {"name": "reverse-engineer-anything", "source": "REA", "clients": ["Codex"], "dir": None},
        ])
        self.assertIn("| `file-pr` | bundled | yes | yes |  |  | Use when filing a PR. |", text)
        self.assertIn("| `reverse-engineer-anything` | REA |  | yes |  |  | Shipped by its package", text)

    def test_named_skills_must_be_installed(self):
        agents = "Use `file-pr`, then `babysit-pr`. Ask the `council`. Set `background=true` in `life`."
        self.assertEqual(missing_references(agents, ["file-pr", "council"]), ["babysit-pr"])
        self.assertEqual(missing_references(agents, ["file-pr", "babysit-pr", "council"]), [])


if __name__ == "__main__":
    unittest.main()
