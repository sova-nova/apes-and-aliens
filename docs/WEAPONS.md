# Weapons

The weapon system for Apes vs Aliens: what's decided, how it will be built, and what's still open.
Companion to `GAME_DESIGN.md`. Status words are the same: **Decided**, **Leaning**, **Open**.

*Last updated: 10/18/26. Weapon system v1 is built (see section 9).*

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
5. **Next: make bots range-aware.** Bots now start shooting at their weapon's own range, but they don't yet *move* to fight at it.
6. **Next: dynamic crosshair** that shows bloom (optional).
7. **Next: balance pass,** time-to-kill across range bands.
8. **Later: healing weapons, per-weapon sounds and effects, and more reload styles.**

**What changed in play:**
- Your own shots now have spread, so tapping and bursting beat holding the trigger at range.
- Weapons have different magazines and reloads. Bots reload too, which creates gaps you can use (a switch on each bot turns it off).
- Falloff matters: the Heavy Repeater is nearly useless past 25 m, the Long Rifle isn't.

---

## 10. Open questions

1. **Healer weapon:** how does it work? A beam that heals while held, a projectile that heals on contact, or something else? This decides the format change above.
2. **Reload styles beyond these two:** overheating, a per-weapon "tactical reload", or reloading a partly full magazine faster.
3. **Per-weapon sound and effects.** Today every weapon shares one shot sound and a tracer. Giving each weapon its own is a large part of how it *feels*.
4. **Controller aim assist** and how it interacts with spread and projectiles.
5. **Starting numbers.** The spread, falloff, magazine, and reload values are a first pass from simulation. They need real play to tune.
