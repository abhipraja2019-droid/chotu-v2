"""Chotu robot driver: head, body turn and antennas through one PCA9685 board.

On the Raspberry Pi it drives the real servos. Anywhere else (or with
dry_run=True) it only prints what it would send, so you can try every move
safely before powering the servos.

    from chotu import Chotu
    bot = Chotu()              # real servos if the PCA9685 is found
    bot.head(pitch=10)         # look up 10 degrees
    bot.turn(30)               # turn the body 30 degrees to the left
    bot.antennas(left=20, right=-20)
    bot.home()
"""

import json
import time
from pathlib import Path

import head_kinematics as hk

CONFIG_FILE = Path(__file__).resolve().parent / "config.json"


class _PrintDriver:
    """Stands in for the servo board: prints instead of moving anything."""

    def __init__(self, quiet=False):
        self.quiet = quiet
        self.last = {}

    def set_angle(self, channel, angle):
        self.last[channel] = angle
        if not self.quiet:
            print(f"  ch{channel:<2d} -> {angle:6.1f} deg")

    def release(self):
        if not self.quiet:
            print("  (servos released)")


class _Pca9685Driver:
    """Real servo board, using Adafruit's ServoKit library."""

    def __init__(self, config):
        from adafruit_servokit import ServoKit  # only installed on the Pi

        board = config["pca9685"]
        pulse = config["pulse_us"]
        self.kit = ServoKit(
            channels=16, address=board["address"], frequency=board["frequency_hz"]
        )
        for ch in range(16):
            self.kit.servo[ch].actuation_range = pulse["range_deg"]
            self.kit.servo[ch].set_pulse_width_range(pulse["min"], pulse["max"])

    def set_angle(self, channel, angle):
        self.kit.servo[channel].angle = angle

    def release(self):
        for ch in range(16):
            self.kit.servo[ch].angle = None


def _clamp(value, low, high):
    return max(low, min(high, value))


class Chotu:
    def __init__(self, dry_run=None, quiet=False, config_file=CONFIG_FILE):
        self.config = json.loads(Path(config_file).read_text())
        self.geometry = hk.load_geometry()
        self.pose = dict(x=0, y=0, z=0, roll=0, pitch=0, yaw=0)
        self.dry_run = True
        self.driver = _PrintDriver(quiet)
        if dry_run is not True:
            try:
                self.driver = _Pca9685Driver(self.config)
                self.dry_run = False
            except Exception as err:  # no library or no board found
                if dry_run is False:
                    raise
                if not quiet:
                    print(f"No servo board found ({err}). Running in dry-run mode.")

    # -- low level -----------------------------------------------------------
    def _write(self, servo, angle_from_centre):
        """Send one servo an angle measured from its centre (0 = mid travel)."""
        centre = self.config["pulse_us"]["range_deg"] / 2
        raw = centre + servo["direction"] * angle_from_centre + servo["trim"]
        self.driver.set_angle(
            servo["channel"], _clamp(raw, 0, self.config["pulse_us"]["range_deg"])
        )

    # -- moves ---------------------------------------------------------------
    def head(self, x=0, y=0, z=0, roll=0, pitch=0, yaw=0):
        """Put the head in a pose. mm for x, y, z; degrees for the rest.

        Raises head_kinematics.PoseUnreachable (and does not move) if the
        pose is outside what the rods can reach.
        """
        pose = dict(x=x, y=y, z=z, roll=roll, pitch=pitch, yaw=yaw)
        angles = hk.solve(
            self.geometry, limit_deg=self.config["head_limit_deg"], **pose
        )
        for servo, angle in zip(self.config["head_servos"], angles):
            self._write(servo, angle)
        self.pose = pose
        return angles

    def glide(self, seconds=0.6, steps=20, **target):
        """Move the head smoothly from where it is to a new pose."""
        start = dict(self.pose)
        end = {**dict(x=0, y=0, z=0, roll=0, pitch=0, yaw=0), **target}
        for n in range(1, steps + 1):
            f = n / steps
            f = f * f * (3 - 2 * f)  # ease in and out
            self.head(**{k: start[k] + (end[k] - start[k]) * f for k in start})
            if not self.dry_run:
                time.sleep(seconds / steps)

    def turn(self, angle):
        """Turn the whole upper body. + = to Chotu's left. Degrees."""
        servo = self.config["yaw_servo"]
        self._write(servo, _clamp(angle, -servo["limit_deg"], servo["limit_deg"]))

    def antennas(self, left=0, right=0):
        """Swing the antennas. 0 = straight up, + = forward. Degrees."""
        for name, angle in (("left", left), ("right", right)):
            servo = self.config["antennas"][name]
            self._write(servo, _clamp(angle, -servo["limit_deg"], servo["limit_deg"]))

    def home(self):
        self.head()
        self.turn(0)
        self.antennas(0, 0)

    def relax(self):
        """Stop holding position (servos go limp). Support the head first."""
        self.driver.release()
