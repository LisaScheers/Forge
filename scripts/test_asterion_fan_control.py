"""Verify fan targets, sensor failures and restoration using a fake hwmon tree."""

import importlib.util
import os
from pathlib import Path
import signal
import subprocess
import tempfile
import time
import unittest


CONTROLLER = Path(os.environ.get("ASTERION_FAN_CONTROL", Path(__file__).with_name("asterion-fan-control.py")))
spec = importlib.util.spec_from_file_location("fan_control", CONTROLLER)
fan_control = importlib.util.module_from_spec(spec)
spec.loader.exec_module(fan_control)
CURVE = fan_control.parse_curve("40:30,55:50,65:75,75:100")


class FanControlTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.device = self.root / "hwmon17"
        self.device.mkdir()
        files = {
            "name": "macsmc_hwmon", "temp1_label": "SoC die Tf14", "temp1_input": "55000",
            "temp2_label": "SoC die Tf25", "temp2_input": "65000",
            "fan1_min": "1350", "fan1_max": "5349", "fan1_target": "0",
            "fan2_min": "1458", "fan2_max": "5777", "fan2_target": "0",
        }
        for name, value in files.items():
            (self.device / name).write_text(value + "\n")
        self.targets = [self.device / f"fan{number}_target" for number in (1, 2)]
        self.fans = [(self.targets[0], 1350, 5349), (self.targets[1], 1458, 5777)]
        self.sensors = [self.device / f"temp{number}_input" for number in (1, 2)]

    def test_points_interpolation_and_clamping(self):
        for temperature, duty in [(20, 30), (40, 30), (55, 50), (60, 62.5), (65, 75), (75, 100), (100, 100)]:
            self.assertEqual(fan_control.duty_at(temperature, CURVE), duty)
        for value in ("40:30", "55:50,40:100", "40:70,55:50,75:100", "40:0,75:100", "40:30,75:101", "40:30,75:90", "40:30:10,75:100"):
            with self.assertRaises(ValueError):
                fan_control.parse_curve(value)

    def test_hottest_sensor_and_individual_fan_ranges(self):
        self.assertEqual(fan_control.find_hwmon(self.root), self.device)
        fan_control.update(self.fans, self.sensors, CURVE)
        self.assertEqual([int(target.read_text()) for target in self.targets], [4012, 4333])
        fan_control.update(self.fans, self.sensors, [(40, 1), (75, 100)])
        for target, minimum, maximum in self.fans:
            self.assertTrue(minimum <= int(target.read_text()) <= maximum)
        for sensor in self.sensors:
            sensor.write_text("20000\n")
        fan_control.update(self.fans, self.sensors, [(40, 1), (75, 100)])
        self.assertEqual([int(target.read_text()) for target in self.targets], [1350, 1458])

    def test_sensor_failure_requests_full_speed_then_recovers(self):
        for invalid in ("bad", "0", "-1000", "150000"):
            self.sensors[1].write_text(invalid)
            fan_control.update(self.fans, self.sensors, CURVE)
            self.assertEqual([int(target.read_text()) for target in self.targets], [5349, 5777])
        self.sensors[1].unlink()
        fan_control.update(self.fans, self.sensors, CURVE)
        self.assertEqual([int(target.read_text()) for target in self.targets], [5349, 5777])
        self.sensors[1].write_text("55000\n")
        fan_control.update(self.fans, self.sensors, CURVE)
        self.assertEqual([int(target.read_text()) for target in self.targets], [2674, 2888])

    def start_controller(self):
        process = subprocess.Popen([os.sys.executable, "-B", str(CONTROLLER), "--hwmon-root", str(self.root)])
        self.addCleanup(lambda: process.poll() is None and process.kill())
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline:
            if all(target.read_text().strip() not in ("", "0") for target in self.targets):
                return process
            if process.poll() is not None:
                self.fail("Controller exited before setting fan speeds")
            time.sleep(0.01)
        self.fail("Controller did not set fan speeds")

    def test_sigterm_restores_firmware_control(self):
        process = self.start_controller()
        process.send_signal(signal.SIGTERM)
        self.assertEqual(process.wait(timeout=5), 0)
        self.assertEqual([target.read_text() for target in self.targets], ["0\n", "0\n"])

    def test_restore_after_forced_termination(self):
        process = self.start_controller()
        process.kill()
        process.wait(timeout=5)
        subprocess.run([os.sys.executable, "-B", str(CONTROLLER), "--hwmon-root", str(self.root), "--restore"], check=True)
        self.assertEqual([target.read_text() for target in self.targets], ["0\n", "0\n"])

    def test_restore_attempts_both_fans_after_failure(self):
        self.targets[0].unlink()
        self.targets[0].mkdir()
        self.targets[1].write_text("4333\n")
        with self.assertRaises(RuntimeError):
            fan_control.restore(self.targets)
        self.assertEqual(self.targets[1].read_text(), "0\n")


if __name__ == "__main__":
    unittest.main()
