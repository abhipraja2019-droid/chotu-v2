"""Write chotu_head_geometry.json from the same numbers chotu.scad uses.

Run this again whenever you change a size in chotu.scad:

    python3 software/tools/make_geometry.py

The formulas below mirror the "DERIVED NUMBERS" section of chotu.scad, so the
head maths and the printed parts always agree.
"""

import json
import math
from pathlib import Path

# ---- copied from chotu.scad (millimetres) --------------------------------
SV_LEN = 22.8        # MG90S body length
SV_SHAFT_X = 6.1     # shaft centre -> near end of the body
SV_TAB_Z = 18.0      # underside of the mounting tabs
SV_SPLINE_Z = 30.0   # top of the output spline
HORN_R = 14.0        # shaft centre -> ball stud hole on the horn
BALL_OFF = 4.5       # horn surface -> centre of the M3 ball

BASE_H = 52.0        # table -> top of the base deck
LS_H = 8.0           # lazy-susan bearing thickness
HEX_A = 44.0         # centre -> outer face of each servo wall
SV_AXIS_Z = 32.0     # servo shaft height above the torso floor
PLAT_R = 32.0        # radius of the 6 head ball joints
HOME_H = 55.0        # head ball joints above the servo shafts at "home"
PAIR_HALF_ANGLE = 15.0
# ---------------------------------------------------------------------------

Z_SHAFT = BASE_H + LS_H + SV_AXIS_Z
Z_BALL_HEAD = Z_SHAFT + HOME_H
BALL_R = HEX_A + (SV_SPLINE_Z - SV_TAB_Z) - 1 + BALL_OFF
SV_BODY_MID = SV_LEN / 2 - SV_SHAFT_X


def horn_side(i):
    """-1 or +1: which way along the wall servo i's horn points at home."""
    return -1 if i % 2 == 0 else 1


def face(i):
    """Unit vectors of servo wall i: (radial, tangential)."""
    a = math.radians(60 * i)
    return (math.cos(a), math.sin(a), 0.0), (-math.sin(a), math.cos(a), 0.0)


def shaft(i):
    """Centre of servo i's horn pivot (the point the horn turns about)."""
    r, t = face(i)
    u = horn_side(i) * SV_BODY_MID
    return [BALL_R * r[0] + u * t[0], BALL_R * r[1] + u * t[1], Z_SHAFT]


def horn_dir(i):
    """Direction the horn points at home (level, along the wall)."""
    _, t = face(i)
    s = horn_side(i)
    return [s * t[0], s * t[1], 0.0]


def head_ball(i):
    """Head ball joint i at home."""
    if i % 2 == 0:
        ang = 60 * i + 30 - PAIR_HALF_ANGLE
    else:
        ang = 60 * (i - 1) + 30 + PAIR_HALF_ANGLE
    a = math.radians(ang)
    return [PLAT_R * math.cos(a), PLAT_R * math.sin(a), Z_BALL_HEAD]


def build():
    servos = []
    for i in range(6):
        s, d, p = shaft(i), horn_dir(i), head_ball(i)
        servos.append({
            "index": i,
            "shaft": [round(v, 9) for v in s],
            "horn_dir": [round(v, 9) for v in d],
            "horn_side": horn_side(i),
            "head_ball": [round(v, 9) for v in p],
        })
    tip0 = [shaft(0)[k] + HORN_R * horn_dir(0)[k] for k in range(3)]
    rod = math.dist(tip0, head_ball(0))
    return {
        "units": "mm",
        "axes": "+X = Chotu's right, +Y = forward (the face), +Z = up. "
                "Origin = centre of the table under Chotu.",
        "horn_length": HORN_R,
        "rod_length": round(rod, 9),
        "head_centre_home": [0.0, 0.0, Z_BALL_HEAD],
        "servos": servos,
    }


if __name__ == "__main__":
    out = Path(__file__).resolve().parent.parent / "chotu_head_geometry.json"
    geometry = build()
    out.write_text(json.dumps(geometry, indent=2) + "\n")
    print(f"rod length = {geometry['rod_length']:.2f} mm")
    print(f"wrote {out}")
