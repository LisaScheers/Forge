import json
import os
from pathlib import Path
import socket
import subprocess
import tempfile
import time
import unittest
from urllib.error import HTTPError

from ingest import archive, ClickHouse
from test_ingest import transcript


def free_port():
    with socket.socket() as listener:
        listener.bind(("127.0.0.1", 0))
        return listener.getsockname()[1]


@unittest.skipUnless(os.environ.get("CLICKHOUSE_BINARY"), "requires isolated ClickHouse test runtime")
class ClickHouseTests(unittest.TestCase):
    def test_schema_replay_unicode_and_token_counts(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            port = free_port()
            users = root / "users.xml"
            users.write_text("""<clickhouse><profiles><default/></profiles><users><default>
                <password>test</password><networks><ip>127.0.0.1</ip></networks>
                <profile>default</profile><quota>default</quota></default></users>
                <quotas><default/></quotas></clickhouse>""")
            config = root / "config.xml"
            config.write_text(f"""<clickhouse><logger><level>warning</level><console>1</console></logger>
                <path>{root}/data/</path><tmp_path>{root}/tmp/</tmp_path>
                <users_config>{users}</users_config><listen_host>127.0.0.1</listen_host>
                <http_port>{port}</http_port><tcp_port>{free_port()}</tcp_port><timezone>UTC</timezone>
                <max_server_memory_usage>1073741824</max_server_memory_usage>
                <background_schedule_pool_size>2</background_schedule_pool_size>
                <background_message_broker_schedule_pool_size>2</background_message_broker_schedule_pool_size>
                <background_distributed_schedule_pool_size>2</background_distributed_schedule_pool_size>
                <background_buffer_flush_schedule_pool_size>2</background_buffer_flush_schedule_pool_size>
                </clickhouse>""")
            with (root / "server.log").open("w+") as output:
                process = subprocess.Popen([os.environ["CLICKHOUSE_BINARY"], "server", f"--config-file={config}"],
                                           stdout=output, stderr=output)
                destination = ClickHouse(f"http://127.0.0.1:{port}")
                try:
                    for _ in range(300):
                        try:
                            destination.query("SELECT 1")
                            break
                        except Exception:
                            if process.poll() is not None:
                                output.seek(0)
                                self.fail(output.read())
                            time.sleep(0.1)
                    else:
                        output.seek(0)
                        self.fail("ClickHouse did not start: " + output.read())
                    schema = Path(__file__).with_name("schema.sql").read_text()
                    for _ in range(2):
                        for statement in schema.split(";"):
                            if statement.strip():
                                try:
                                    destination.query(statement)
                                except HTTPError as error:
                                    with error:
                                        self.fail(error.read().decode())
                    response = {"type": "response.completed", "response": {"id": "resp_1", "model": "test",
                        "usage": {"input_tokens": 20, "input_tokens_details": {"cached_tokens": 8},
                                  "output_tokens": 7, "output_tokens_details": {"reasoning_tokens": 3},
                                  "future_tokens": 2}}}
                    log = root / "responses.log"
                    text = transcript(response)
                    log.write_text(text)
                    archive(log, log.name, destination)
                    archive(log, log.name, destination)
                    record = json.loads(destination.query("SELECT transcript FROM ai_usage.requests FORMAT JSONEachRow"))
                    self.assertEqual(record["transcript"], text)
                    count = destination.query("SELECT count() FROM ai_usage.usage_events").strip()
                    self.assertEqual(count, b"1")
                    counts = dict(json.loads(line).values() for line in destination.query(
                        "SELECT token_category, token_count FROM ai_usage.token_counts FORMAT JSONEachRow").splitlines())
                    self.assertEqual(int(counts["input_tokens"]), 20)
                    self.assertEqual(int(counts["input_tokens_details.cached_tokens"]), 8)
                    self.assertEqual(int(counts["output_tokens_details.reasoning_tokens"]), 3)
                    self.assertEqual(int(counts["future_tokens"]), 2)
                    if os.environ.get("CLIPROXY_BINARY"):
                        from verify_gateway import verify
                        gateway_root = root / "gateway"
                        gateway_root.mkdir()
                        captures = verify(gateway_root)
                        for capture in captures:
                            archive(capture, "gateway/" + capture.name, destination)
                        total = destination.query("SELECT sum(token_count) FROM ai_usage.token_counts "
                            "WHERE startsWith(file_name, 'gateway/') AND token_category = 'future_tokens'").strip()
                        self.assertEqual(total, b"12")
                finally:
                    process.terminate()
                    try:
                        process.wait(timeout=15)
                    except subprocess.TimeoutExpired:
                        process.kill()
                        process.wait()


if __name__ == "__main__":
    unittest.main()
