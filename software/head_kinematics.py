"""Head maths for Chotu: turn "where should the head be" into 6 servo angles.

Chotu's head sits on six rods. Each rod hangs from the horn of one small
servo. To put the head in a pose (tilt, nod, turn, shift) we work out, for
each servo, how far its horn must swing so that its rod exactly reaches the
head joint. This is called inverse kinematics of a rotary Stewart platform.

Pure Python, no extra packages, so it runs the same on a laptop and on the Pi.

Axes: +X = Chotu's right, +Y = forward (the face), +Z = up.
Angles: pitch + = look up, roll + = lean to Chotu's right,
        yaw + = turn to Chotu's left (anticlockwise seen from above).
"""

import json
import math
from pathlib import Path

GEOMETRY_FILE = Path(__file__).resolve().parent / "chotu_head_geometry.json"


class PoseUnreachable(ValueError):
    """The rods are too short or too long to reach this pose."""


def load_geometry(path=GEOMETRY_FILE):
    return json.loads(Path(path).read_text())


def _rotation(roll, pitch, yaw):
    """3x3 rotation matrix. Angles in degrees. Order: yaw, then pitch, then roll."""
    r, p, y = (math.radians(v) for v in (roll, pitch, yaw))
    cr, sr = math.cos(r), math.sin(r)
    cp, sp = math.cos(p), math.sin(p)
    cy, sy = math.cos(y), math.sin(y)
    rz = ((cy, -sy, 0), (sy, cy, 0), (0, 0, 1))      # yaw about Z
    rx = ((1, 0, 0), (0, cp, -sp), (0, sp, cp))      # pitch about X
    ry = ((cr, 0, sr), (0, 1, 0), (-sr, 0, cr))      # roll about Y

    def mul(a, b):
        return tuple(
            tuple(sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3))
            for i in range(3)
        )

    return mul(rz, mul(rx, ry))


def head_ball_positions(geometry, x=0, y=0, z=0, roll=0, pitch=0, yaw=0):
    """Where the 6 head ball joints end up for a pose (mm and degrees)."""
    centre = geometry["head_centre_home"]
    rot = _rotation(roll, pitch, yaw)
    out = []
    for servo in geometry["servos"]:
        local = [servo["head_ball"][k] - centre[k] for k in range(3)]
        turned = [sum(rot[i][k] * local[k] for k in range(3)) for i in range(3)]
        out.append([
            centre[0] + x + turned[0],
            centre[1] + y + turned[1],
            centre[2] + z + turned[2],
        ])
    return out


def horn_tip(geometry, index, angle_deg):
    """Where servo `index`'s horn ball is when the horn is raised by angle_deg."""
    servo = geometry["servos"][index]
    a = geometry["horn_length"]
    t = math.radians(angle_deg)
    return [
        servo["shaft"][0] + a * math.cos(t) * servo["horn_dir"][0],
        servo["shaft"][1] + a * math.cos(t) * servo["horn_dir"][1],
        servo["shaft"][2] + a * math.sin(t),
    ]


def solve(geometry, x=0, y=0, z=0, roll=0, pitch=0, yaw=0, limit_deg=60):
    """Return the 6 horn angles (degrees) for a head pose.

    0 = horn level (the home pose). Positive = horn tip goes up.
    x, y, z are shifts from home in mm. roll, pitch, yaw are in degrees.
    Raises PoseUnreachable if any rod cannot reach, or if a horn would have
    to swing more than limit_deg either way.
    """
    a = geometry["horn_length"]
    s = geometry["rod_length"]
    balls = head_ball_positions(geometry, x, y, z, roll, pitch, yaw)
    angles = []
    for servo, ball in zip(geometry["servos"], balls):
        leg = [ball[k] - servo["shaft"][k] for k in range(3)]
        along = sum(leg[k] * servo["horn_dir"][k] for k in range(3))
        up = leg[2]
        length_sq = sum(v * v for v in leg)
        # Solve  A*sin(t) + B*cos(t) = C  for the horn angle t.
        big_a = 2 * a * up
        big_b = 2 * a * along
        big_c = length_sq + a * a - s * s
        reach = math.hypot(big_a, big_b)
        if reach == 0 or abs(big_c) > reach:
            raise PoseUnreachable(
                f"servo {servo['index']}: rod cannot reach this pose"
            )
        angle = math.degrees(math.asin(big_c / reach) - math.atan2(big_b, big_a))
        if abs(angle) > limit_deg:
            raise PoseUnreachable(
                f"servo {servo['index']}: needs {angle:.1f} deg, "
                f"limit is +/-{limit_deg} deg"
            )
        angles.append(angle)
    return angles


if __name__ == "__main__":
    g = load_geometry()
    print("rod length:", g["rod_length"], "mm")
    for name, pose in [
        ("home", {}),
        ("look up 15", {"pitch": 15}),
        ("lean right 15", {"roll": 15}),
        ("turn left 20", {"yaw": 20}),
        ("raise 10 mm", {"z": 10}),
    ]:
        print(f"{name:14s}", " ".join(f"{v:7.2f}" for v in solve(g, **pose)))
