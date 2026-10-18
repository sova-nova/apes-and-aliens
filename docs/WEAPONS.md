# Weapons

The weapon system for Apes vs Aliens: what's decided, how it will be built, and what's still open.
Companion to `GAME_DESIGN.md`. Status words are the same: **Decided**, **Leaning**, **Open**.

*Last updated: 10/18/26. Weapon system v1, range-aware bots, the dynamic crosshair, and a first balance pass are done (see section 9).*

---

## 1. Decisions

| Topic | Choice | Status |
|---|---|---|
| Behaviors | Both **hitscan** (instant) and **projectile** (travels). Fast weapons are hitscan, slow weapons are projectiles. | Decided |
| Exceptions | **Allowed.** Not every weapon has to follow the rule, as long as the reason is written down. | Decided |
| Accuracy | **Spread**, in the spirit of TF2. | Decided |
| Moving and spread | **Moving does not widen spread.** | Decided |
| Damage over distance | **Falloff curves**, so each class must play within its range. | Decided |
| Weapons per class | **One** at launch. Unlocks later (see section 6). | Decided |
| Faction identity | Factions' weapons **feel different**. Some weapons may still feel alike. | Decided |
| Reloads | **Different for each weapon.** Built so far: whole-magazine and round-by-round. | Decided |
| Explosions | **Knockback and self-damage are allowed.** Set per weapon (see section 5) and decided case by case for abilities. | Decided |
| Classes per faction | **Four** as a baseline: a healer, a tank, a long-range class, and a short/mid-range class. Three at the very start is fine while we build. | Decided |
| The Ghost's sniper | Hitscan, as an exception to the rule. | Leaning |
| Headshots | Not at launch (they need hitboxes, animation, and tuning). | Leaning |
| Spread shown on the crosshair | The crosshair can widen to show current bloom (optional setting). | Leaning |

**The rule is a guideline.** "Fast is hitscan, slow is projectile" describes the default. A weapon can be an exception on purpose, as long as the reason is written down here.

**The healer needs a weapon too.** A healer's "gun" restores allies instead of hurting enemies. The weapon format will need to support that (a heal amount, and the ability to hit teammates). It is not built yet, and is the main thing to design before the healer class.

---

## 2. How a weapon is described: data, not code

Every weapon is a data file (a Godot *resource*), the way classes are today. Players and bots fire the **same** weapon data through the **same** code. That is what keeps damage in one place, and it is what the server will run later.

A weapon has:

| Group | Fields |
|---|---|
| Basics | name, behavior (`HITSCAN` or `PROJECTILE`), damage, seconds between shots, pellets per shot (1 for a rifle, more for a shotgun) |
| Ammo | magazine size, reload time |
| Spread | base spread, bloom per shot, maximum bloom, recovery speed, whether the first shot after a pause is perfectly accurate |
| Falloff | a curve of damage multiplier against distance (editable in the Inspector) |
| Range hints | the distances where this weapon is strongest, which bots use to choose where to fight |
| Projectile only | speed, gravity, lifetime, hit radius, splash radius, splash damage curve |
| Feel | tracer or projectile look, sounds, muzzle effect, camera shake |

A class then simply *has* a weapon.

---

## 3. Spread

Spread is a cone around where you aim. Each shot goes in a random direction inside it.

- **Base spread** applies when you're standing and not firing.
- **Bloom** widens the cone with every shot and shrinks back when you stop. Tapping is accurate; holding the trigger is not.
- **The first shot after a pause is accurate** (Leaning), which rewards controlled bursts.
- **Pellet weapons** fire several pellets, each at a random spot in the cone.
- **Projectile weapons** have little or no spread by default.

**Skill over luck.** The *size* of the cone is entirely in the player's control (how you fire), so the randomness is a bounded risk, not a coin flip.

**Why it is seeded.** Online, the server and the player's game must agree on where each shot went. Each shot's randomness will come from a seed both sides can compute, so nothing needs to be sent for it.

**Moving does not widen the cone** (decided). Spread comes only from how you fire, never from how you move.

---

## 4. Falloff and range bands

Each weapon has a falloff curve: full damage in its sweet spot, less beyond it. Together with spread, this is what makes "short range" and "long range" real.

Starting archetypes (to tune on real maps; the current prototype map is about 50 by 120 meters, and most fights happen between 5 and 30 meters):

| Archetype | Full damage out to | Falls to (at distance) | Spread |
|---|---|---|---|
| Short range | about 10 m | about 35% at 30 m | wide |
| Mid range | about 20 m | about 60% at 50 m | moderate |
| Long range | about 25 m, and strong beyond | stays high | tight |

**Consequence for bots.** Bots currently engage everything at 15 meters. Once weapons have ranges, a bot must prefer its weapon's range: short-range bots close in, long-range bots hold back and use cover.

---

## 5. Projectiles

- **Simulated by the server** online. Players' games show a cosmetic copy instantly so shooting doesn't feel laggy.
- **Simple motion, not physics bodies.** The projectile moves each frame and checks a line from its old position to its new one (so fast ones can't skip through a wall or a player). This is cheap, which matters for the low-end hardware target.
- **Reused objects.** Projectiles are recycled instead of created and destroyed constantly.
- **Splash damage** uses an area check with a line-of-sight test, and falls off toward the edge. Cover blocks the blast.
- **Knockback and self-damage** are set per weapon: how hard enemies are pushed, how much of the damage the shooter takes from their own explosion, and how much of the push they get. Teammates are never hurt. Abilities that explode are decided case by case.
- **Slow, high-impact weapons only** by default, which keeps the number of live projectiles (and network traffic) down.

---

## 6. One weapon per class, and unlocks later

At launch every class has exactly one weapon, plus its three abilities.

Unlocks (your doc lists them as a goal) will be **variants of an existing weapon**, such as different stats or an alternate fire mode, not new models and animations. That keeps art and balance work small enough for one developer.

---

## 7. Factions: different feel, shared building blocks

Both factions use the same behaviors (hitscan and projectile) and the same data format. Their weapons feel different through:

- Tuning: rate of fire, spread, falloff shape, and magazine size.
- Look, sound, and effects. This is the largest part of "feel".
- Occasionally a different behavior on purpose (an exception worth recording here).

Counterpart classes share the same *job* and range band, but differ in how they do it, so balance stays manageable. It's fine, and cheaper, if some counterpart weapons feel alike.

---

## 8. What this means for the rest of the project

| Area | Consequence |
|---|---|
| Online play | Hitscan needs "lag compensation" (the server rewinds targets to what the shooter saw). Projectiles are server-simulated. Both are well understood, and the weapon data design keeps them separate. |
| Bots | Range-aware behavior (above). Projectile bots must lead their targets. |
| Controller | Aim assist must be tuned separately for hitscan and projectile weapons. |
| Hardware | Hitscan is very cheap. Projectiles are cheap if kept simple and recycled. |
| HUD | The crosshair can show bloom. The ammo display already exists. |
| Art and audio | One weapon per class means about six weapons at launch, each needing a model, shot and reload sounds, and effects. |

---

## 9. Build status

**Weapon system v1: built** (offline and network-friendly).

1. **Done:** the weapon data format (`WeaponData`), and one shared firing system (`WeaponController`) that players and bots both use. Today's firing code is out of the player and bot scripts.
2. **Done:** the three existing classes use weapon data, with spread and falloff, and each has a different magazine and reload.
3. **Done:** the projectile behavior (`Projectile`), with splash, knockback, self-damage, pooling, and bots that lead their targets.
4. **Done, for testing:** two extra weapons you can assign to any class: a *Scatter Gun* (shotgun pellets, round-by-round reload) and a *Rocket Launcher* (projectile with splash).
5. **Done: range-aware bots.** Each weapon declares a best-range band, and bots fight inside it (see "Bots and range" below).
6. **Done: dynamic crosshair.** The crosshair opens up by exactly as much as your shots can scatter (see "The dynamic crosshair" below). It can be turned off in settings.
7. **Done: first balance pass** on time-to-kill across range bands (see section 11), with a reusable simulator in `tools/balance_sim.py`.
8. **Later: healing weapons, per-weapon sounds and effects, and more reload styles.**

**Bots and range.** A bot with a weapon that has a best-range band behaves like this while fighting:

- **Enemy farther than the band's maximum:** it steps toward them until it's in range.
- **Enemy closer than the band's minimum:** it backs away (mostly the long-range class).
- **Inside the band:** it holds its ground and shoots.
- **Close-range weapons charge:** a bot whose weapon is marked "closes in" also charges a visible enemy that's just out of shooting range (10 m past it by default).
- **A leash keeps bots on the objective.** A bot never repositions more than 16 m from its capture point or guard post, so a fight can't pull it away from its job.
- **A small tolerance** (2 m) outside the band is allowed before it moves, so bots don't jitter back and forth. A bot boxed in by a wall just holds and shoots.

All of it is in the bot's "Range" settings, and each weapon file has its own band (`ideal_range_min`, `ideal_range_max`, `bots_close_in`). A weapon with no band set makes bots stand where they are, as before.

Not yet: bots using cover, strafing, or choosing *which* fights to take. Those are later behavior work.

**The dynamic crosshair.** The weapon's current spread is an angle. The crosshair converts it to screen pixels using the camera's field of view, so the opening you see is the real cone: a shot that deviates by that angle lands exactly on its edge. It opens quickly (about 0.2 s) and closes a little slower (about 0.45 s), so a burst feels like bloom. Each style shows it differently: arms move outward, the circle grows, the chevron spreads, and the dot gets a thin ring. It is the **Dynamic** checkbox on the Crosshair settings tab, with a pulsing preview so you can see the effect.

**What changed in play:**
- Your own shots now have spread, so tapping and bursting beat holding the trigger at range.
- Weapons have different magazines and reloads. Bots reload too, which creates gaps you can use (a switch on each bot turns it off).
- Falloff matters: the Heavy Repeater is nearly useless past 25 m, the Long Rifle isn't.

---

## 10. Range identity: what "balanced" means here

Each weapon should win fights **inside its own range band**, and lose them outside it. That is the rock-paper-scissors the design asks for:

| Role | Wins | Loses |
|---|---|---|
| Short range (Heavy Repeater) | up close (about 0-10 m) | at range, where its damage fades and spread opens |
| Mid range (Assault Rifle) | the middle (about 6-20 m) | far away, and against a tank up close |
| Long range (Long Rifle) | far away (about 30 m and out) | up close, where it is helpless |

Time-to-kill pace is kept where it was: a mirror rifle duel at its best range takes about half a second to a second against a steady shooter.

---

## 11. Balance pass 1 (10/18/26)

`tools/balance_sim.py` reads the class and weapon files and simulates duels at several distances. Run it from the project folder:

```
python3 tools/balance_sim.py
python3 tools/balance_sim.py --sigma 1.2 --distances 5 10 20 35
```

**What it found.** The short-range and mid-range identities were right, but the long-range class did not win at long range. The Ghost lost the duel to the Breacher at **25 m (0.58x)** and even at **40 m (0.69x)**, because the rifle's damage only faded to 60% at 50 m, and it fires seven times as often as the sniper, which swamps any aim error.

**What changed.**
- Assault Rifle falloff: full damage out to **18 m** (was 20), fading to **30%** at **35 m** (was 60% at 50 m). This matches its stated best range of 6-18 m.
- Long Rifle: preferred minimum range **20 m** (was 14), so Ghost bots keep their distance.

**Result (duel ratio, Breacher against Ghost; above 1 means the Breacher wins):**

| Distance | 5 m | 15 m | 25 m | 30 m | 40 m |
|---|---|---|---|---|---|
| Before | 2.31 | 1.73 | 1.73 | 1.98 | 1.17 |
| After | 2.31 | 1.73 | 1.38 | 0.96 | **0.43** |

Close and mid-range fights are unchanged. The Ghost is now even at 30 m and clearly ahead from about 35 m.

**What it does not tell you.** Targets stand still and the aim is steady, so absolute times are best-case. Use it to compare classes and ranges. Movement, cover, and real aim will lengthen real fights. Projectile weapons are not modeled.

**Left for later.** The Warden is a tank with a short-range gun, and the planned roster separates those jobs, so Warden numbers should be revisited when the tank and short-range classes are built.

---

## 10. Open questions

1. **Healer weapon:** how does it work? A beam that heals while held, a projectile that heals on contact, or something else? This decides the format change above.
2. **Reload styles beyond these two:** overheating, a per-weapon "tactical reload", or reloading a partly full magazine faster.
3. **Per-weapon sound and effects.** Today every weapon shares one shot sound and a tracer. Giving each weapon its own is a large part of how it *feels*.
4. **Controller aim assist** and how it interacts with spread and projectiles.
5. **Starting numbers.** The spread, falloff, magazine, and reload values are a first pass from simulation. They need real play to tune.
