"""Checks for the head maths. Run:  python3 test_head_kinematics.py"""

import math
import random

import head_kinematics as hk
from chotu import Chotu

G = hk.load_geometry()


def rod_error(pose, angles):
    """Largest gap (mm) between a rod's real length and what the pose needs."""
    balls = hk.head_ball_positions(G, **pose)
    return max(
        abs(math.dist(hk.horn_tip(G, i, angles[i]), balls[i]) - G["rod_length"])
        for i in range(6)
    )


def test_rod_length_matches_the_printed_design():
    assert abs(G["rod_length"] - 67.8) < 0.05, G["rod_length"]


def test_home_pose_has_level_horns():
    assert all(abs(a) < 1e-6 for a in hk.solve(G))


def test_solved_angles_put_every_rod_at_its_exact_length():
    random.seed(1)
    solved = 0
    for _ in range(500):
        pose = dict(
            x=random.uniform(-4, 4), y=random.uniform(-4, 4),
            z=random.uniform(-4, 4), roll=random.uniform(-8, 8),
            pitch=random.uniform(-8, 8), yaw=random.uniform(-10, 10),
        )
        try:
            angles = hk.solve(G, **pose)
        except hk.PoseUnreachable:
            continue
        solved += 1
        assert rod_error(pose, angles) < 1e-6, pose
    assert solved > 400, solved


def test_raising_the_head_raises_every_horn():
    assert all(a > 0 for a in hk.solve(G, z=8))
    assert all(a < 0 for a in hk.solve(G, z=-8))


def test_looking_up_lifts_the_front_and_drops_the_back():
    angles = hk.solve(G, pitch=12)
    for servo, angle in zip(G["servos"], angles):
        front = servo["head_ball"][1] > 0
        assert (angle > 0) == front, (servo["index"], angle)


def test_impossible_pose_is_refused():
    for pose in (dict(z=60), dict(pitch=70), dict(x=80)):
        try:
            hk.solve(G, **pose)
        except hk.PoseUnreachable:
            continue
        raise AssertionError(f"{pose} should be unreachable")


def test_driver_centres_all_servos_at_home_and_keeps_pose_on_failure():
    bot = Chotu(dry_run=True, quiet=True)
    bot.home()
    assert sorted(bot.driver.last) == list(range(9))
    assert all(abs(v - 90) < 1e-6 for v in bot.driver.last.values()), bot.driver.last
    bot.head(pitch=10)
    before = dict(bot.driver.last)
    try:
        bot.head(z=60)
    except hk.PoseUnreachable:
        pass
    assert bot.driver.last == before
    assert bot.pose["pitch"] == 10


def test_servo_direction_follows_config():
    bot = Chotu(dry_run=True, quiet=True)
    angles = bot.head(z=8)
    for servo, angle in zip(bot.config["head_servos"], angles):
        expected = 90 + servo["direction"] * angle
        assert abs(bot.driver.last[servo["channel"]] - expected) < 1e-9


if __name__ == "__main__":
    tests = [v for k, v in sorted(globals().items()) if k.startswith("test_")]
    for test in tests:
        test()
        print("ok  ", test.__name__)
    print(f"{len(tests)} tests passed")
