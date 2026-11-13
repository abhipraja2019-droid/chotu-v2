"""Chotu demo: wake up, look around, nod, wiggle the antennas.

    python3 demo.py --dry-run     # safe: only prints the servo angles
    python3 demo.py               # on the Pi, moves the real servos
    python3 demo.py --centre      # holds every servo at home, for fitting horns
"""

import argparse
import time

from chotu import Chotu


def pause(bot, seconds):
    if not bot.dry_run:
        time.sleep(seconds)


def say(bot, text):
    if not bot.driver.__dict__.get("quiet"):
        print(f"\n{text}")


def run(bot):
    say(bot, "Home")
    bot.home()
    pause(bot, 1)

    say(bot, "Wake up: stretch up and lift the antennas")
    bot.glide(z=8, pitch=8)
    bot.antennas(25, 25)
    pause(bot, 0.5)

    say(bot, "Look left, then right")
    bot.glide(yaw=20)
    bot.glide(yaw=-20, seconds=1.0)
    bot.glide()

    say(bot, "Nod yes")
    for _ in range(2):
        bot.glide(pitch=-12, seconds=0.3)
        bot.glide(pitch=6, seconds=0.3)
    bot.glide()

    say(bot, "Curious head tilt")
    bot.glide(roll=14, pitch=5)
    bot.antennas(30, -10)
    pause(bot, 0.8)
    bot.glide(roll=-14, pitch=5)
    bot.antennas(-10, 30)
    pause(bot, 0.8)

    say(bot, "Turn the body")
    bot.glide()
    bot.turn(35)
    pause(bot, 0.8)
    bot.turn(-35)
    pause(bot, 0.8)

    say(bot, "Antenna wiggle")
    for _ in range(3):
        bot.antennas(20, -20)
        pause(bot, 0.2)
        bot.antennas(-20, 20)
        pause(bot, 0.2)

    say(bot, "Back home")
    bot.home()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--dry-run", action="store_true",
                        help="print servo angles instead of moving")
    parser.add_argument("--centre", action="store_true",
                        help="hold every servo at home and wait")
    args = parser.parse_args()

    chotu = Chotu(dry_run=True if args.dry_run else None)
    if args.centre:
        chotu.home()
        if not chotu.dry_run:
            input("All servos at home. Fit the horns level, then press Enter.")
    else:
        run(chotu)
