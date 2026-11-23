import json
import os
from pathlib import Path
import socket
import subprocess
import tempfile
import time
import unittest
from urllib.error import HTTPError
from urllib.parse import urlencode
from urllib.request import Request, urlopen

from ingest import archive, ClickHouse
from test_ingest import transcript


def archive_query(port, sql, **settings):
    """Query as the archive's account, the way services/ai-archive does."""
    request = Request(f"http://127.0.0.1:{port}/?" + urlencode({"query": sql, **settings}), data=b"",
                      headers={"X-ClickHouse-User": "ai_archive", "X-ClickHouse-Key": "archive-test"})
    with urlopen(request, timeout=30) as response:
        return response.read()


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
            tcp_port = free_port()
            users = root / "users.xml"
            users.write_text("""<clickhouse><profiles><default/></profiles><users><default>
                <password>test</password><networks><ip>127.0.0.1</ip></networks>
                <profile>default</profile><quota>default</quota></default></users>
                <quotas><default/></quotas></clickhouse>""")
            # Nook's accounts, merged over the base file as the NixOS module does.
            (root / "users.d").mkdir()
            (root / "users.d" / "ai-usage.xml").write_text(Path(__file__).with_name("clickhouse-users.xml").read_text())
            config = root / "config.xml"
            config.write_text(f"""<clickhouse><logger><level>warning</level><console>1</console></logger>
                <path>{root}/data/</path><tmp_path>{root}/tmp/</tmp_path>
                <users_config>{users}</users_config><listen_host>127.0.0.1</listen_host>
                <http_port>{port}</http_port><tcp_port>{tcp_port}</tcp_port><timezone>UTC</timezone>
                <max_server_memory_usage>1073741824</max_server_memory_usage>
                <background_schedule_pool_size>2</background_schedule_pool_size>
                <background_message_broker_schedule_pool_size>2</background_message_broker_schedule_pool_size>
                <background_distributed_schedule_pool_size>2</background_distributed_schedule_pool_size>
                <background_buffer_flush_schedule_pool_size>2</background_buffer_flush_schedule_pool_size>
                </clickhouse>""")
            with (root / "server.log").open("w+") as output:
                environment = {**os.environ, "AI_USAGE_CLICKHOUSE_PASSWORD": "test",
                               "AI_ARCHIVE_CLICKHOUSE_PASSWORD": "archive-test",
                               "AI_OTEL_CLICKHOUSE_PASSWORD": "otel-test"}
                process = subprocess.Popen([os.environ["CLICKHOUSE_BINARY"], "server", f"--config-file={config}"],
                                           stdout=output, stderr=output, env=environment)
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
                    # The archive account reads captures but cannot change them,
                    # even when its client asks to leave read-only mode.
                    self.assertEqual(archive_query(port, "SELECT count() FROM ai_usage.requests").strip(), b"1")
                    for sql, settings in [("TRUNCATE TABLE ai_usage.requests", {}),
                                          ("TRUNCATE TABLE ai_usage.requests", {"readonly": "0"}),
                                          ("SELECT name FROM system.users", {})]:
                        with self.assertRaises(HTTPError, msg=sql) as raised:
                            archive_query(port, sql, **settings)
                        raised.exception.close()
                    self.assertEqual(destination.query("SELECT count() FROM ai_usage.requests").strip(), b"1")
                    if os.environ.get("OTELCOL_BINARY"):
                        self.collector_writes_otel_only(root, tcp_port, port)
                    if os.environ.get("CLIPROXY_BINARY"):
                        from test_gateway_fixture import verify
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


    def collector_writes_otel_only(self, root, tcp_port, http_port):
        """Nook's collector configuration stores an OTLP log through its own account."""
        listen = free_port()
        with (root / "collector.log").open("w+") as output:
            collector = subprocess.Popen(
                [os.environ["OTELCOL_BINARY"], f"--config=file:{os.environ['OTELCOL_CONFIG']}",
                 f"--set=receivers::otlp::protocols::http::endpoint=127.0.0.1:{listen}",
                 f"--set=exporters::clickhouse::endpoint=tcp://127.0.0.1:{tcp_port}"],
                stdout=output, stderr=output, env={**os.environ, "AI_OTEL_CLICKHOUSE_PASSWORD": "otel-test"})
            try:
                log = {"resourceLogs": [{"resource": {"attributes": [
                    {"key": "service.name", "value": {"stringValue": "claude-code"}}]},
                    "scopeLogs": [{"logRecords": [{"body": {"stringValue": "forge-telemetry-test"}}]}]}]}
                body = json.dumps(log).encode()
                for _ in range(300):
                    try:
                        request = Request(f"http://127.0.0.1:{listen}/v1/logs", data=body,
                                          headers={"Content-Type": "application/json"})
                        with urlopen(request, timeout=5) as response:
                            self.assertEqual(response.status, 200)
                        break
                    except OSError:
                        if collector.poll() is not None:
                            output.seek(0)
                            self.fail(output.read())
                        time.sleep(0.1)
                else:
                    output.seek(0)
                    self.fail("collector did not start: " + output.read())
                for _ in range(300):
                    try:
                        if archive_query(http_port, "SELECT count() FROM otel.otel_logs "
                                         "WHERE Body = 'forge-telemetry-test'").strip() == b"1":
                            break
                    except HTTPError as error:
                        error.close()
                    time.sleep(0.1)
                else:
                    output.seek(0)
                    self.fail("the log never reached otel.otel_logs: " + output.read())
            finally:
                collector.terminate()
                collector.wait(timeout=15)
        # The collector's account cannot read the gateway's captures.
        request = Request(f"http://127.0.0.1:{http_port}/?" + urlencode({"query": "SELECT count() FROM ai_usage.requests"}),
                          data=b"", headers={"X-ClickHouse-User": "ai_otel", "X-ClickHouse-Key": "otel-test"})
        with self.assertRaises(HTTPError) as raised:
            urlopen(request, timeout=30).close()
        raised.exception.close()


if __name__ == "__main__":
    unittest.main()
