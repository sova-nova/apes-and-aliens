#!/usr/bin/env python3
"""
Time-to-kill simulator for Apes vs Aliens.

Reads the project's class files (classes/*.tres) and weapon files (weapons/*.tres), then simulates
duels at several distances and prints:

  1. How long each weapon takes to kill each class (time-to-kill, "TTK"), two ways:
       hold  = holding the trigger the whole time
       best  = the best of holding and several burst-fire rhythms (a player with fire discipline)
  2. Duel results: when two classes shoot at each other from the same distance, who wins and by how much.

Usage (from the project folder):
    python3 tools/balance_sim.py
    python3 tools/balance_sim.py --sigma 1.2 --distances 5 10 20 35 --trials 600

Needs only Python 3 (no extra packages).

HOW TO READ IT
  * Stationary targets and a steady aim, so absolute numbers are best-case. Use them to COMPARE
    classes and ranges, not as a promise of real-world times.
  * --sigma is how wobbly the shooter's aim is, in degrees (0 = perfect). Around 0.8 is a steady
    player; 1.5 or more is a rushed one.
  * Projectile weapons (rockets and the like) are skipped: splash makes them a different problem.
  * Keep WEAPON_DEFAULTS in sync with scripts/weapon_data.gd if you add weapon fields.
"""
import argparse
import glob
import math
import os
import random
import re
import statistics
import sys

WEAPON_DEFAULTS = dict(
    weapon_name="Rifle", behavior=0, damage=25.0, fire_interval=0.12, pellets=1, max_range=100.0,
    magazine_size=30, reload_style=0, reload_time=1.5,
    spread_base=0.0, spread_bloom_per_shot=0.0, spread_bloom_max=0.0, spread_recovery=3.0,
    first_shot_accurate=False, accuracy_reset_time=0.3,
    falloff_start=20.0, falloff_end=50.0, falloff_min=1.0, falloff_shape=1.0,
    engage_range=15.0, ideal_range_min=0.0, ideal_range_max=0.0,
)
CLASS_DEFAULTS = dict(
    class_name_str="Grunt", max_health=100.0, gun_damage=25.0, fire_rate=0.12,
    gun_range=100.0, mag_size=30, reload_time=1.5,
)

HALF_WIDTH = 0.3   # the target's capsule is 0.6 m wide...
HALF_HEIGHT = 0.75 # ...and 1.5 m tall, and we aim at its middle
CAP_SECONDS = 15.0 # a duel that lasts longer than this is shown as "never"


# ───────────────────────── reading the project ─────────────────────────

def parse_value(text):
    text = text.strip()
    if text in ("true", "false"):
        return text == "true"
    m = re.match(r'^ExtResource\("([^"]+)"\)$', text)
    if m:
        return ("ext", m.group(1))
    if text.startswith('"') and text.endswith('"'):
        return text[1:-1]
    try:
        return int(text)
    except ValueError:
        pass
    try:
        return float(text)
    except ValueError:
        return text


def parse_tres(path):
    """Returns (properties of the [resource] section, {ext_resource id: res:// path})."""
    text = open(path, encoding="utf-8").read()
    ext = {}
    for line in text.splitlines():
        if line.startswith("[ext_resource"):
            p = re.search(r'path="([^"]+)"', line)
            i = re.search(r'\bid="([^"]+)"', line)
            if p and i:
                ext[i.group(1)] = p.group(1)
    props, in_resource = {}, False
    for line in text.splitlines():
        if line.strip() == "[resource]":
            in_resource = True
            continue
        if in_resource and line.startswith("["):
            in_resource = False
        if in_resource and " = " in line:
            key, value = line.split(" = ", 1)
            props[key.strip()] = parse_value(value)
    return props, ext


def load_project(root):
    weapons = {}
    for path in sorted(glob.glob(os.path.join(root, "weapons", "*.tres"))):
        props, _ = parse_tres(path)
        w = dict(WEAPON_DEFAULTS)
        w.update({k: v for k, v in props.items() if k in WEAPON_DEFAULTS})
        weapons["res://weapons/" + os.path.basename(path)] = w

    classes = []
    for path in sorted(glob.glob(os.path.join(root, "classes", "*.tres"))):
        props, ext = parse_tres(path)
        c = dict(CLASS_DEFAULTS)
        c.update({k: v for k, v in props.items() if k in CLASS_DEFAULTS})
        weapon = None
        ref = props.get("weapon")
        if isinstance(ref, tuple) and ref[0] == "ext":
            weapon = weapons.get(ext.get(ref[1]))
        if weapon is None:  # No Weapon assigned: the game builds a plain one from the older gun fields
            weapon = dict(WEAPON_DEFAULTS, weapon_name=c["class_name_str"] + " Gun", damage=c["gun_damage"],
                          fire_interval=c["fire_rate"], max_range=c["gun_range"],
                          magazine_size=c["mag_size"], reload_time=c["reload_time"])
        classes.append(dict(name=c["class_name_str"], hp=float(c["max_health"]), weapon=weapon))
    return classes


# ───────────────────────── the simulation ─────────────────────────

def falloff(w, d):
    if w["falloff_min"] >= 0.999 or d <= w["falloff_start"]:
        return 1.0
    span = max(w["falloff_end"] - w["falloff_start"], 0.001)
    t = min(1.0, max(0.0, (d - w["falloff_start"]) / span))
    return 1.0 + (w["falloff_min"] - 1.0) * (t ** w["falloff_shape"])


def hits(rng, spread_deg, sigma_deg, dist):
    """One pellet: does it land on the target? (Aim wobble, plus a random point inside the spread cone.)"""
    ax, ay = rng.gauss(0, sigma_deg), rng.gauss(0, sigma_deg)
    if spread_deg > 0:
        r = spread_deg * math.sqrt(rng.random())
        a = rng.random() * 2 * math.pi
        ax += r * math.cos(a)
        ay += r * math.sin(a)
    x = math.tan(math.radians(ax)) * dist
    y = math.tan(math.radians(ay)) * dist
    return abs(x) <= HALF_WIDTH and abs(y) <= HALF_HEIGHT


def one_kill(w, hp, dist, burst, sigma, rng):
    """Seconds from the first shot to the killing shot. `burst` = shots per burst (0 = hold the trigger)."""
    if dist > w["max_range"]:
        return CAP_SECONDS
    t, ammo, bloom, bloom_t, last_shot, in_burst = 0.0, w["magazine_size"], 0.0, 0.0, -999.0, 0
    per_pellet = w["damage"] * falloff(w, dist)
    while t < CAP_SECONDS:
        if ammo <= 0:                                    # empty: reload, then carry on
            t += w["reload_time"]
            ammo = w["magazine_size"] if w["reload_style"] == 0 else 1
            continue
        bloom = max(0.0, bloom - w["spread_recovery"] * (t - bloom_t))
        bloom_t = t
        if w["first_shot_accurate"] and (t - last_shot) >= w["accuracy_reset_time"]:
            spread = 0.0
        else:
            spread = w["spread_base"] + bloom
        for _ in range(w["pellets"]):
            if hits(rng, spread, sigma, dist):
                hp -= per_pellet
        if hp <= 0:
            return t
        ammo -= 1
        bloom = min(bloom + w["spread_bloom_per_shot"], w["spread_bloom_max"])
        bloom_t, last_shot = t, t
        in_burst += 1
        wait = w["fire_interval"]
        if burst and in_burst >= burst:                  # end of a burst: pause so accuracy can recover
            in_burst = 0
            pause = w["accuracy_reset_time"] + 0.03 if w["first_shot_accurate"] else w["fire_interval"] + 0.2
            wait = max(wait, pause)
        t += wait
    return CAP_SECONDS


def median_ttk(w, hp, dist, burst, sigma, trials, rng):
    results = [one_kill(w, hp, dist, burst, sigma, rng) for _ in range(trials)]
    results.sort()
    # The median kill time, or "never" if fewer than half the duels finish in time
    return statistics.median(results) if results[len(results) // 2] < CAP_SECONDS else math.inf


def ttk(w, hp, dist, sigma, trials, rng):
    """Returns (hold, best). `best` also tries burst rhythms, which only matter for fast weapons."""
    hold = median_ttk(w, hp, dist, 0, sigma, trials, rng)
    best = hold
    if w["fire_interval"] < 0.5:
        for n in (1, 2, 3, 4, 5):
            best = min(best, median_ttk(w, hp, dist, n, sigma, trials, rng))
    return hold, best


# ───────────────────────── reporting ─────────────────────────

def fmt(v):
    return "never" if v == math.inf else f"{v:5.2f}s"


def main():
    ap = argparse.ArgumentParser(description="Time-to-kill simulator for Apes vs Aliens.")
    ap.add_argument("--root", default=".", help="project folder (default: the current folder)")
    ap.add_argument("--distances", type=float, nargs="+", default=[5, 10, 15, 25, 40])
    ap.add_argument("--sigma", type=float, default=0.8, help="aim wobble in degrees (default 0.8)")
    ap.add_argument("--trials", type=int, default=300, help="duels simulated per cell (default 300)")
    ap.add_argument("--seed", type=int, default=7)
    args = ap.parse_args()

    classes = load_project(args.root)
    if not classes:
        sys.exit("No classes found. Run this from the project folder (or pass --root).")
    skipped = [c["name"] for c in classes if c["weapon"]["behavior"] == 1]
    classes = [c for c in classes if c["weapon"]["behavior"] != 1]
    rng = random.Random(args.seed)

    print("=" * 78)
    print(f"CLASSES  (aim wobble {args.sigma} deg, {args.trials} duels per cell)")
    print("=" * 78)
    for c in classes:
        w = c["weapon"]
        band = f"{w['ideal_range_min']:g}-{w['ideal_range_max']:g} m" if w["ideal_range_max"] > 0 else "no band"
        print(f"  {c['name']:10s} {c['hp']:5.0f} HP   {w['weapon_name']:16s} {w['damage']:g} x{w['pellets']} / {w['fire_interval']:g}s "
              f"= {w['damage'] * w['pellets'] / w['fire_interval']:4.0f} DPS   falloff {w['falloff_start']:g}->{w['falloff_end']:g} m to {w['falloff_min']:g}   best {band}")
    if skipped:
        print(f"  (not modeled, projectile weapons: {', '.join(skipped)})")

    table = {}
    for d in args.distances:
        for a in classes:
            for b in classes:
                table[(d, a["name"], b["name"])] = ttk(a["weapon"], b["hp"], d, args.sigma, args.trials, rng)

    names = [c["name"] for c in classes]
    for d in args.distances:
        print("\n" + "=" * 78)
        print(f"{d:g} METERS   time-to-kill:  hold / best   (rows shoot, columns are shot)")
        print("=" * 78)
        print(f"{'':12s}" + "".join(f"{n:>22s}" for n in names))
        for a in names:
            row = ""
            for b in names:
                hold, best = table[(d, a, b)]
                row += f"{fmt(hold).strip():>9s} / {fmt(best).strip():<9s}   "
            print(f"{a:12s}{row}")

    print("\n" + "=" * 78)
    print("DUELS   who wins when both shoot from the same distance (best fire discipline)")
    print("        number = how many times faster the row class kills the column class.")
    print("        above 1.0 = the ROW class wins; below 1.0 = it loses.")
    print("=" * 78)
    for d in args.distances:
        print(f"\n{d:g} m")
        print(f"{'':12s}" + "".join(f"{n:>12s}" for n in names))
        for a in names:
            row = ""
            for b in names:
                if a == b:
                    row += f"{'-':>12s}"
                    continue
                mine = table[(d, a, b)][1]       # my time to kill them
                theirs = table[(d, b, a)][1]     # their time to kill me
                if mine == math.inf and theirs == math.inf:
                    cell = "-"
                elif mine == math.inf:
                    cell = "0.00x"
                elif theirs == math.inf:
                    cell = "inf"
                else:
                    cell = f"{theirs / mine:.2f}x"
                row += f"{cell:>12s}"
            print(f"{a:12s}{row}")
    print()


if __name__ == "__main__":
    main()
