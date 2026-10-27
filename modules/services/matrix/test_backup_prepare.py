"""Run the real prepare/resume scripts against isolated files and fake services."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

HERE = Path(__file__).resolve().parent
PREPARE = Path(os.environ.get("BACKUP_PREPARE_SCRIPT", HERE / "backup-prepare.sh"))
RESUME = Path(os.environ.get("BACKUP_RESUME_SCRIPT", HERE / "backup-resume.sh"))


class PrepareTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name).resolve()
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.checkpoint = self.root / "var/backup/matrix-coordinated"
        self.checkpoint.mkdir(parents=True)
        (self.checkpoint / "COMPLETE").write_text("old checkpoint\n")
        for directory in ["run/lock", "run/agenix", "var/lib/postgresql", "var/lib/matrix-synapse/media_store/local_content",
                          "var/lib/mautrix-discord", "var/lib/pluralmatrix", "var/lib/pluralmatrix-registration", "var/lib/sec-hive-migration"]:
            (self.root / directory).mkdir(parents=True, exist_ok=True)
        (self.root / "var/lib/matrix-synapse/media_store/local_content/original").write_text("original bytes")
        for name in ["matrix-registration-secret", "matrix-turn-secret", "discord-bridge-env"]:
            (self.root / "run/agenix" / name).write_text("isolated fixture")
        for name in ["history-manifest.json", "sec-hive-pilot.json"]:
            (self.root / "var/lib/sec-hive-migration" / name).write_text("{}")
        (self.root / "run/current-system").symlink_to(self.root)
        self.state = self.root / "services.json"
        self.initial = {name: True for name in ["matrix-synapse.service", "mautrix-discord.service", "pluralmatrix.service"]}
        self.state.write_text(json.dumps(self.initial))
        self.events = self.root / "events.jsonl"
        self.audit = self.root / "audit.json"
        self.audit.write_text('{"source_state":"unchanged"}\n')
        self.env = dict(os.environ, PATH=str(self.bin) + os.pathsep + os.environ["PATH"], PLURAL_ENABLED="1",
                        FIXTURE_ROOT=str(self.root), FIXTURE_SERVICES=str(self.state), FIXTURE_EVENTS=str(self.events),
                        FIXTURE_AUDIT=str(self.audit))
        for name in ["MATRIX_BACKUP_WARM_HOOK", "MATRIX_BACKUP_COLD_HOOK", "MEDIA_RSYNC_SSH", "MATRIX_BACKUP_STATE_FILE"]:
            self.env.pop(name, None)
        config = self.root / "config.json"
        config.write_text("{}")
        self.env.update(SYNAPSE_CONFIG=str(config), PLURAL_CONFIG=str(config))
        self.prepare = self.root / "prepare.sh"
        self.prepare.write_text(self.remap(PREPARE.read_text()))
        resume = self.root / "resume.sh"
        resume.write_text("#!" + shutil.which("bash") + "\nset -euo pipefail\n" + self.remap(RESUME.read_text()))
        resume.chmod(0o700)
        self.env["RESUME_COMMAND"] = str(resume)
        self.command("flock", "pass")
        self.command("sleep", "pass")
        self.command("systemctl", '''
args = sys.argv[1:]
state = json.loads(Path(os.environ['FIXTURE_SERVICES']).read_text())
if args[0] == 'is-active':
    sys.exit(0 if state[args[-1]] else 3)
record(args[0], unit=args[-1])
state[args[-1]] = args[0] == 'start'
Path(os.environ['FIXTURE_SERVICES']).write_text(json.dumps(state))
if args == ['stop', 'matrix-synapse.service'] and os.environ.get('CHANGE_DURING_PAUSE'):
    Path(os.environ['FIXTURE_AUDIT']).write_text('changed source state')
''')
        self.command("runuser", '''
args = sys.argv[sys.argv.index('--') + 1:]
if args[0] == 'pg_dump':
    record('dump', database=args[-1]); print('isolated dump')
elif 'pg_stat_activity' in ' '.join(args):
    count = 1 if os.environ.get('CONNECTIONS_BUSY') else 0
    record('connections', count=count); print(count)
else:
    record('counts'); print('{}')
''')
        self.command("rsync", '''
source, destination = map(Path, sys.argv[-2:])
record('rsync')
shutil.copytree(source, destination, dirs_exist_ok=True,
    ignore=shutil.ignore_patterns('media_store') if '--exclude=/media_store/' in sys.argv else None)
''')
        media = self.command("copy-media", '''
source, destination = map(Path, sys.argv[-2:])
record('media_copy')
shutil.copytree(source, destination, dirs_exist_ok=True)
''')
        self.env["MEDIA_COPY_COMMAND"] = str(media)
        # Nix checks run as nixbld. Model root ownership while keeping actual
        # permission bits, so the production trust checks run unchanged.
        self.command("stat", '''
format_string, filename = sys.argv[2], sys.argv[-1]
if format_string == '%u':
    if filename == os.environ.get('UNTRUSTED_OWNER'):
        print(1000)
    elif 'VISIBLE_ROOT_UID' in os.environ:
        owner = Path(filename).stat().st_uid
        print(0 if owner == int(os.environ['VISIBLE_ROOT_UID']) else owner)
    else:
        print(0)
elif format_string == '%a':
    print(format(Path(filename).stat().st_mode & 0o7777, 'o'))
else:
    sys.exit(2)
''')
        self.warm = self.command("warm hook", '''
assert len(sys.argv) == 1
checkpoint = Path(os.environ['MATRIX_BACKUP_CHECKPOINT'])
assert checkpoint == Path(os.environ['FIXTURE_ROOT']) / 'var/backup/matrix-coordinated'
assert (checkpoint / 'synapse/media_store/local_content/original').read_text() == 'original bytes'
assert json.loads((checkpoint / 'media-backup-policy.json').read_text())['original_media'] == 'preserved'
assert json.loads(Path(os.environ['FIXTURE_SERVICES']).read_text()) == json.loads(os.environ['INITIAL_SERVICES'])
record('warm')
if os.environ.get('WARM_FAIL'): sys.exit(24)
(Path(os.environ['FIXTURE_ROOT']) / 'warm-audit.json').write_bytes(Path(os.environ['FIXTURE_AUDIT']).read_bytes())
''')
        self.cold = self.command("cold-hook", '''
assert len(sys.argv) == 1
assert not any(json.loads(Path(os.environ['FIXTURE_SERVICES']).read_text()).values())
events = [json.loads(line) for line in Path(os.environ['FIXTURE_EVENTS']).read_text().splitlines()]
assert events[-1] == {'event': 'connections', 'count': 0}
record('cold')
if os.environ.get('COLD_TERM'):
    import signal
    os.kill(os.getppid(), signal.SIGTERM); sys.exit(0)
audit = Path(os.environ['FIXTURE_AUDIT']).read_bytes()
if audit != (Path(os.environ['FIXTURE_ROOT']) / 'warm-audit.json').read_bytes(): sys.exit(25)
verification = Path(os.environ['MATRIX_BACKUP_CHECKPOINT']) / 'verification'
(verification / 'post-wave-reaction-changes.json').write_bytes(audit)
(verification / 'post-wave-snapshot-boundary.json').write_text('{"cold_audit_equal":true}\\n')
''')

    def remap(self, source):
        return source.replace("/var/", str(self.root) + "/var/").replace("/run/", str(self.root) + "/run/")

    def command(self, name, source):
        filename = self.bin / name
        filename.write_text("#!" + sys.executable + "\nimport json,os,shutil,sys\nfrom pathlib import Path\n"
            "def record(event, **extra):\n with Path(os.environ['FIXTURE_EVENTS']).open('a') as stream: stream.write(json.dumps({'event':event,**extra})+'\\n')\n" + source)
        filename.chmod(0o700)
        return filename

    def run_prepare(self, hooks=True):
        self.env["INITIAL_SERVICES"] = self.state.read_text()
        if hooks:
            self.env.update(MATRIX_BACKUP_WARM_HOOK=str(self.warm), MATRIX_BACKUP_COLD_HOOK=str(self.cold))
        return subprocess.run([shutil.which("bash"), "-euo", "pipefail", str(self.prepare)], env=self.env,
                              stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)

    def records(self):
        return [json.loads(line) for line in self.events.read_text().splitlines()] if self.events.exists() else []

    def assert_failed_capture(self, result, *, resumed):
        self.assertNotEqual(result.returncode, 0, result.stderr)
        self.assertFalse((self.checkpoint / "COMPLETE").exists())
        self.assertFalse(any(item["event"] == "dump" for item in self.records()))
        self.assertEqual(json.loads(self.state.read_text()), self.initial)
        starts = [item["unit"] for item in self.records() if item["event"] == "start"]
        self.assertEqual(starts, [name for name in ["matrix-synapse.service", "pluralmatrix.service", "mautrix-discord.service"] if self.initial[name]] if resumed else [])

    def test_paired_hooks_capture_at_the_required_boundaries(self):
        result = self.run_prepare()
        self.assertEqual(result.returncode, 0, result.stderr)
        names = [item["event"] for item in self.records()]
        self.assertLess(names.index("media_copy"), names.index("warm"))
        self.assertLess(names.index("warm"), names.index("stop"))
        self.assertLess(max(i for i, name in enumerate(names) if name == "stop"), names.index("connections"))
        self.assertLess(names.index("connections"), names.index("cold"))
        self.assertLess(names.index("cold"), names.index("dump"))
        self.assertEqual(names.count("dump"), 3)
        self.assertEqual(json.loads(self.state.read_text()), self.initial)
        self.assertTrue((self.checkpoint / "COMPLETE").exists())
        self.assertEqual((self.checkpoint / "verification/post-wave-reaction-changes.json").read_bytes(), self.audit.read_bytes())
        checksums = (self.checkpoint / "SHA256SUMS").read_text()
        self.assertIn("./verification/post-wave-reaction-changes.json", checksums)
        self.assertIn("./verification/post-wave-snapshot-boundary.json", checksums)

    def test_unset_hooks_keep_the_daily_capture(self):
        result = self.run_prepare(hooks=False)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((self.checkpoint / "COMPLETE").exists())
        self.assertFalse({"warm", "cold"} & {item["event"] for item in self.records()})
        self.assertEqual(sum(item["event"] == "dump" for item in self.records()), 3)

    def test_real_root_owned_nix_store_commands_are_accepted(self):
        root_uid = Path("/").stat().st_uid
        if root_uid == 0:
            (self.bin / "stat").unlink()
        else:
            # Nix's build user namespace maps host root to nobody. Translate
            # that UID only; use the real ownership and modes of store files.
            self.env["VISIBLE_ROOT_UID"] = str(root_uid)
        command = shutil.which("true")
        self.assertTrue(str(Path(command).resolve()).startswith("/nix/store/"), command)
        self.env.update(MATRIX_BACKUP_WARM_HOOK=command, MATRIX_BACKUP_COLD_HOOK=command)
        result = self.run_prepare(hooks=False)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((self.checkpoint / "COMPLETE").exists())

    def test_later_daily_capture_removes_only_the_optional_staging_proofs(self):
        result = self.run_prepare()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((self.checkpoint / "verification/post-wave-reaction-changes.json").is_file())
        audit = self.audit.read_bytes()
        self.env.pop("MATRIX_BACKUP_WARM_HOOK"); self.env.pop("MATRIX_BACKUP_COLD_HOOK")
        result = self.run_prepare(hooks=False)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((self.checkpoint / "COMPLETE").exists())
        self.assertFalse((self.checkpoint / "verification/post-wave-reaction-changes.json").exists())
        self.assertFalse((self.checkpoint / "verification/post-wave-snapshot-boundary.json").exists())
        self.assertTrue((self.checkpoint / "verification/history-manifest.json").is_file())
        self.assertEqual(self.audit.read_bytes(), audit)
        self.assertEqual((self.root / "warm-audit.json").read_bytes(), audit)
        self.assertNotIn("post-wave-", (self.checkpoint / "SHA256SUMS").read_text())

    def test_half_configured_hooks_fail_before_copy_or_pause(self):
        for variable, value in [("MATRIX_BACKUP_WARM_HOOK", str(self.warm)), ("MATRIX_BACKUP_COLD_HOOK", str(self.cold))]:
            with self.subTest(variable=variable):
                self.env.pop("MATRIX_BACKUP_WARM_HOOK", None); self.env.pop("MATRIX_BACKUP_COLD_HOOK", None)
                self.env[variable] = value
                self.assert_failed_capture(self.run_prepare(hooks=False), resumed=False)
                self.assertEqual(self.records(), [])

    def test_warm_failure_precedes_pause(self):
        self.env["WARM_FAIL"] = "1"
        self.assert_failed_capture(self.run_prepare(), resumed=False)
        self.assertFalse(any(item["event"] in {"stop", "connections", "cold"} for item in self.records()))

    def test_cold_mismatch_resumes_original_services_without_dump(self):
        self.env["CHANGE_DURING_PAUSE"] = "1"
        self.assert_failed_capture(self.run_prepare(), resumed=True)
        self.assertIn("cold", [item["event"] for item in self.records()])

    def test_term_during_cold_hook_uses_the_resume_trap(self):
        self.env["COLD_TERM"] = "1"
        result = self.run_prepare()
        self.assertEqual(result.returncode, 143, result.stderr)
        self.assert_failed_capture(result, resumed=True)

    def test_inactive_bridge_is_not_started_on_cold_failure(self):
        self.initial["mautrix-discord.service"] = False
        self.state.write_text(json.dumps(self.initial))
        self.env["CHANGE_DURING_PAUSE"] = "1"
        self.assert_failed_capture(self.run_prepare(), resumed=True)

    def test_nonzero_database_connections_prevent_cold_hook_and_dumps(self):
        self.env["CONNECTIONS_BUSY"] = "1"
        self.assert_failed_capture(self.run_prepare(), resumed=True)
        self.assertNotIn("cold", [item["event"] for item in self.records()])

    def test_command_strings_and_relative_paths_are_not_executed(self):
        for value in [str(self.warm) + " --argument", "warm hook"]:
            with self.subTest(value=value):
                self.env.update(MATRIX_BACKUP_WARM_HOOK=value, MATRIX_BACKUP_COLD_HOOK=str(self.cold))
                self.assert_failed_capture(self.run_prepare(hooks=False), resumed=False)
                self.assertEqual(self.records(), [])

    def test_untrusted_owner_or_writable_executable_is_rejected(self):
        self.env["UNTRUSTED_OWNER"] = str(self.warm)
        self.assert_failed_capture(self.run_prepare(), resumed=False)
        self.env.pop("UNTRUSTED_OWNER")
        self.warm.chmod(0o722)
        self.assert_failed_capture(self.run_prepare(), resumed=False)
        self.assertEqual(self.records(), [])

    def test_writable_nonsticky_parent_is_rejected(self):
        self.bin.chmod(0o777)
        self.assert_failed_capture(self.run_prepare(), resumed=False)
        self.assertEqual(self.records(), [])


if __name__ == "__main__":
    unittest.main()
