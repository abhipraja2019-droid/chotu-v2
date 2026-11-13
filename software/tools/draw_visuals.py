"""Draw the pictures used in the README (needs numpy and matplotlib).

    python3 software/tools/draw_visuals.py

Writes into renders/v2/:
  parts.png          every printable part, drawn from its STL file
  head_geometry.png  the six-servo head mechanism, at home and looking up
  head_range.png     how far the head can move on each axis
"""

import sys
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
from mpl_toolkits.mplot3d.art3d import Poly3DCollection

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "software"))
import head_kinematics as hk  # noqa: E402

OUT = ROOT / "renders" / "v2"
INK, MUTED, GRID = "#1f2430", "#6b7280", "#d9dde3"
BLUE, ORANGE, GREY = "#2f6fde", "#e8590c", "#9aa3af"

PARTS = [
    ("base_plate", "Base plate"), ("base_shell", "Base shell"),
    ("torso", "Torso"), ("body_shell", "Body shell"),
    ("head_platform", "Head platform"), ("head_shell", "Head shell"),
    ("visor", "Visor"), ("antenna", "Antenna (x2)"),
    ("antenna_hub", "Antenna hub (x2)"),
]


def read_stl(path):
    """Triangles of an ASCII STL as an (n, 3, 3) array."""
    rows = [line.split()[1:4] for line in path.read_text().splitlines()
            if line.lstrip().startswith("vertex")]
    return np.array(rows, dtype=float).reshape(-1, 3, 3)


def draw_part(ax, tris, title):
    normals = np.cross(tris[:, 1] - tris[:, 0], tris[:, 2] - tris[:, 0])
    lengths = np.linalg.norm(normals, axis=1)
    keep = lengths > 0
    tris, normals = tris[keep], normals[keep] / lengths[keep, None]
    light = np.array([0.35, -0.55, 0.75])
    shade = 0.45 + 0.55 * np.clip(normals @ light / np.linalg.norm(light), 0, 1)
    colours = np.outer(shade, np.array([0.80, 0.84, 0.90]))
    ax.add_collection3d(Poly3DCollection(tris, facecolors=colours, linewidths=0))
    lo, hi = tris.reshape(-1, 3).min(0), tris.reshape(-1, 3).max(0)
    mid, half = (lo + hi) / 2, (hi - lo).max() / 2
    for setter, m in zip((ax.set_xlim, ax.set_ylim, ax.set_zlim), mid):
        setter(m - half, m + half)
    ax.set_box_aspect((1, 1, 1))
    ax.view_init(elev=28, azim=-58)
    ax.set_axis_off()
    size = hi - lo
    ax.set_title(f"{title}\n{size[0]:.0f} x {size[1]:.0f} x {size[2]:.0f} mm",
                 fontsize=10, color=INK, y=0.94)


def parts_sheet():
    fig = plt.figure(figsize=(11, 10.5), dpi=140)
    for n, (name, title) in enumerate(PARTS, start=1):
        ax = fig.add_subplot(3, 3, n, projection="3d")
        draw_part(ax, read_stl(ROOT / f"{name}.stl"), title)
    fig.suptitle("Chotu v2: printable parts (as they sit on the print bed)",
                 fontsize=14, color=INK, y=0.985)
    fig.subplots_adjust(left=0, right=1, bottom=0, top=0.93, wspace=0, hspace=0.08)
    fig.savefig(OUT / "parts.png", facecolor="white")
    plt.close(fig)


def draw_mechanism(ax, g, pose, title):
    angles = hk.solve(g, **pose)
    balls = np.array(hk.head_ball_positions(g, **pose))
    shafts = np.array([s["shaft"] for s in g["servos"]])
    tips = np.array([hk.horn_tip(g, i, angles[i]) for i in range(6)])
    ring = np.vstack([shafts, shafts[:1]])
    ax.plot(*ring.T, color=GREY, lw=1, ls="--")
    head = np.vstack([balls, balls[:1]])
    ax.add_collection3d(Poly3DCollection([balls], facecolors=BLUE, alpha=0.18))
    ax.plot(*head.T, color=BLUE, lw=2)
    for i in range(6):
        ax.plot(*np.array([shafts[i], tips[i]]).T, color=ORANGE, lw=3.5,
                solid_capstyle="round")
        ax.plot(*np.array([tips[i], balls[i]]).T, color=INK, lw=1.6)
        ax.text(*(shafts[i] * [1.22, 1.22, 1] - [0, 0, 6]), str(i),
                color=MUTED, fontsize=9, ha="center")
    ax.scatter(*shafts.T, color=GREY, s=22, depthshade=False)
    ax.scatter(*tips.T, color=ORANGE, s=18, depthshade=False)
    ax.scatter(*balls.T, color=BLUE, s=18, depthshade=False)
    centre = balls.mean(0)
    ax.quiver(*centre, 0, 34, 0, color=BLUE, lw=1.5, arrow_length_ratio=0.25)
    ax.text(centre[0], centre[1] + 40, centre[2], "front", color=BLUE, fontsize=9)
    ax.set_xlim(-70, 70); ax.set_ylim(-70, 70); ax.set_zlim(80, 170)
    ax.set_box_aspect((140, 140, 90))
    ax.view_init(elev=20, azim=-62)
    ax.set_axis_off()
    ax.set_title(title, fontsize=11, color=INK, y=0.97)


def head_geometry(g):
    fig = plt.figure(figsize=(11, 5.4), dpi=140)
    draw_mechanism(fig.add_subplot(1, 2, 1, projection="3d"), g, {},
                   "Home: all six horns level")
    draw_mechanism(fig.add_subplot(1, 2, 2, projection="3d"), g,
                   {"pitch": 14, "z": 3}, "Looking up 14°: front horns rise, back horns drop")
    fig.suptitle("Chotu's head mechanism", fontsize=14, color=INK, y=0.99)
    fig.text(0.5, 0.035,
             "Orange = servo horn (14 mm)    Black = rod (67.8 mm)    "
             "Blue = head joints    Numbers = servo / PCA9685 channel",
             ha="center", fontsize=9.5, color=MUTED)
    fig.subplots_adjust(left=0, right=1, bottom=0.05, top=0.94, wspace=0)
    fig.savefig(OUT / "head_geometry.png", facecolor="white")
    plt.close(fig)


def axis_limit(g, axis, sign, step=0.25):
    value = 0.0
    while value < 90:
        try:
            hk.solve(g, **{axis: sign * (value + step)})
        except hk.PoseUnreachable:
            break
        value += step
    return sign * value


def head_range(g):
    rows = [("x", "Shift left / right", "mm"), ("y", "Shift back / forward", "mm"),
            ("z", "Lower / raise", "mm"), ("roll", "Lean left / right", "°"),
            ("pitch", "Look down / up", "°"), ("yaw", "Turn right / left", "°")]
    fig, ax = plt.subplots(figsize=(8.5, 3.9), dpi=140)
    for n, (axis, label, unit) in enumerate(reversed(rows)):
        lo, hi = axis_limit(g, axis, -1), axis_limit(g, axis, 1)
        ax.barh(n, hi - lo, left=lo, height=0.5, color=BLUE)
        ax.text(lo - 1, n, f"{lo:.0f}{unit}", va="center", ha="right",
                fontsize=9, color=INK)
        ax.text(hi + 1, n, f"+{hi:.0f}{unit}", va="center", ha="left",
                fontsize=9, color=INK)
    ax.set_yticks(range(len(rows)), [r[1] for r in reversed(rows)], fontsize=10)
    ax.axvline(0, color=INK, lw=1)
    ax.set_xlim(-42, 42)
    ax.set_xlabel("mm for shifts, degrees for tilts (0 = home)", color=MUTED, fontsize=9)
    ax.tick_params(colors=MUTED, length=0)
    ax.xaxis.grid(True, color=GRID, lw=0.8)
    ax.set_axisbelow(True)
    for side in ("top", "right", "left", "bottom"):
        ax.spines[side].set_visible(False)
    ax.set_title("How far the head can move, one direction at a time\n"
                 "(calculated, horns limited to ±60°)", fontsize=11.5,
                 color=INK, loc="left")
    fig.tight_layout()
    fig.savefig(OUT / "head_range.png", facecolor="white")
    plt.close(fig)


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    geometry = hk.load_geometry()
    parts_sheet()
    head_geometry(geometry)
    head_range(geometry)
    print("wrote", ", ".join(p.name for p in sorted(OUT.glob("*.png"))))
