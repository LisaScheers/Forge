"""Control Asterion's fans from the hottest SoC die sensor."""

import argparse
from pathlib import Path
import signal
import sys
import threading


def parse_curve(value):
    points = [tuple(map(int, point.split(":"))) for point in value.split(",")]
    if (
        len(points) < 2
        or any(len(point) != 2 for point in points)
        or any(not 0 < temperature < 150 or not 0 < duty <= 100 for temperature, duty in points)
        or any(t1 >= t2 or d1 > d2 for (t1, d1), (t2, d2) in zip(points, points[1:]))
        or points[-1][1] != 100
    ):
        raise ValueError("Use increasing temperature:percent points ending at 100%")
    return points


def duty_at(temperature, points):
    if temperature <= points[0][0]:
        return points[0][1]
    for (t1, d1), (t2, d2) in zip(points, points[1:]):
        if temperature <= t2:
            return d1 + (d2 - d1) * (temperature - t1) / (t2 - t1)
    return 100


def find_hwmon(root):
    devices = [device for device in root.glob("hwmon*") if (device / "name").read_text().strip() == "macsmc_hwmon"]
    if len(devices) != 1:
        raise RuntimeError("Expected exactly one macsmc_hwmon device")
    return devices[0]


def restore(targets):
    errors = []
    for target in targets:
        try:
            # Zero returns control to the SMC; it does not request a stopped fan.
            target.write_text("0\n")
        except OSError as error:
            errors.append(str(error))
    if errors:
        raise RuntimeError("Could not restore firmware control: " + "; ".join(errors))


def temperature_at(sensors):
    readings = [int(sensor.read_text()) for sensor in sensors]
    if not readings or any(not 0 < value < 150000 for value in readings):
        raise ValueError("Missing or invalid SoC temperature")
    return max(readings) / 1000


def update(fans, sensors, points):
    try:
        duty = duty_at(temperature_at(sensors), points)
    except (OSError, ValueError) as error:
        print(f"SoC sensor unavailable; requesting full speed: {error}", file=sys.stderr, flush=True)
        duty = 100
    for target, minimum, maximum in fans:
        target.write_text(f"{max(minimum, min(maximum, round(maximum * duty / 100)))}\n")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--hwmon-root", type=Path, default=Path("/sys/class/hwmon"))
    parser.add_argument("--curve", type=parse_curve, default="40:30,55:50,65:75,75:100")
    parser.add_argument("--restore", action="store_true", help="Return both fans to firmware control")
    args = parser.parse_args()
    device = find_hwmon(args.hwmon_root)
    targets = sorted(device.glob("fan*_target"))
    if len(targets) != 2:
        raise RuntimeError("Expected both Asterion fans")
    if args.restore:
        restore(targets)
        return
    sensors = [
        label.with_name(label.name.replace("_label", "_input"))
        for label in sorted(device.glob("temp*_label"))
        if label.read_text().strip().startswith("SoC die ")
    ]
    if not sensors:
        raise RuntimeError("No SoC die sensors; leaving firmware control unchanged")
    fans = []
    for target in targets:
        minimum = int(target.with_name(target.name.replace("_target", "_min")).read_text())
        maximum = int(target.with_name(target.name.replace("_target", "_max")).read_text())
        if not 0 < minimum <= maximum:
            raise ValueError(f"Invalid fan range for {target.name}")
        fans.append((target, minimum, maximum))
    stopped = threading.Event()
    for signum in (signal.SIGTERM, signal.SIGINT):
        signal.signal(signum, lambda _signum, _frame: stopped.set())
    try:
        while not stopped.is_set():
            update(fans, sensors, args.curve)
            stopped.wait(2)
    finally:
        restore(targets)


if __name__ == "__main__":
    main()
