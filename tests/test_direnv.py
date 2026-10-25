"""Check NixOS wrapper precedence after loading a development environment."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ENVRC = Path(__file__).resolve().parents[1] / ".envrc"


@unittest.skipUnless(Path("/run/wrappers/bin/sudo").is_file(), "requires NixOS sudo wrapper")
class DirenvWrapperTest(unittest.TestCase):
    def test_cached_shell_cannot_shadow_privileged_wrappers(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            checkout = root / "checkout with spaces"
            checkout.mkdir()
            for name in ("modules", "packages"):
                (checkout / name).mkdir()
            for name in ("flake.nix", "flake.lock"):
                (checkout / name).touch()
            (checkout / ".envrc").write_text('''
nix_direnv_version() { return 0; }
use() {
  export PATH="/run/current-system/sw/bin:$PATH"
}
''' + ENVRC.read_text())
            env = dict(os.environ,
                       XDG_CONFIG_HOME=str(root / "config"),
                       XDG_CACHE_HOME=str(root / "cache"),
                       XDG_DATA_HOME=str(root / "data"),
                       DIRENV_CONFIG=str(root / "config/direnv"))
            for name in tuple(env):
                if name.startswith("DIRENV_") and name != "DIRENV_CONFIG":
                    del env[name]
            subprocess.run(["direnv", "allow", str(checkout)], env=env,
                           check=True, capture_output=True, text=True, timeout=10)

            # Exercise repeated imports, including the same bad ordering in the caller.
            for caller_path in (os.environ["PATH"],
                                f"/run/current-system/sw/bin:{os.environ['PATH']}"):
                with self.subTest(caller_path=caller_path):
                    result = subprocess.run(
                        ["direnv", "exec", str(checkout), "bash", "-c", "command -v sudo"],
                        env=dict(env, PATH=caller_path),
                        capture_output=True, text=True, timeout=10,
                    )
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertEqual(result.stdout.strip(), "/run/wrappers/bin/sudo")


if __name__ == "__main__":
    unittest.main()
