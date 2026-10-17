# APES vs ALIENS

A hobby 3D third-person shooter about the whimsy and chaos of team battles, in the spirit of Garden Warfare 2.
Two factions, the **Primal Apes** and the **Chrome Legion**, fight over capture points against AI bots.

<!-- Add a screenshot or GIF here, for example: ![Gameplay](docs/screenshot.png) -->

> **Status:** early development. Expect rough edges, placeholder art, and placeholder sound effects.

## The game

- **Attack and defend.** One team pushes through three capture points (A, B, C) while the other holds them. Capturing a point opens the next gate, moves the spawns forward, and adds time to the clock. Attackers win by taking every point; defenders win by running out the clock.
- **Pick your side.** Choose either faction, then choose to attack, defend, or let it be random. Optionally swap sides every round. A running tally tracks the series.
- **Three classes, nine abilities.**

  | Class | Role | Abilities |
  |---|---|---|
  | **Breacher** | Fast-firing all-rounder | Phase Dash, Overcharge, Adrenaline Spike |
  | **Warden** | Heavy tank | Deploy Cover, Bulwark, Shockwave |
  | **Ghost** | Fragile sniper | Grapple Hook, Target Lock, Life Siphon |

- **Bots with jobs.** Attackers push the point. Defenders hold positions around it and step in to contest. Bots aim imperfectly, react with a delay, and use their abilities.
- **Difficulty, pause, and settings.** Easy, Normal, or Hard opponents; mouse sensitivity, volume, and fullscreen options.

## Controls

| Key | Action |
|---|---|
| **W A S D** | Move |
| **Space** | Jump |
| **Mouse** | Aim |
| **Left click** | Shoot |
| **R** | Reload |
| **Q / E / Shift** | Abilities (class-specific) |
| **Esc** | Pause |

## Play it

Download the latest build from this repository's **Releases** page.

**Windows (64-bit)**
1. Unzip `ApesVsAliens-<version>-windows.zip`. Keep `ApesVsAliens.exe` and `ApesVsAliens.pck` together in the same folder.
2. Run `ApesVsAliens.exe`.
3. Windows may show *"Windows protected your PC"* because the game isn't code-signed. Choose **More info**, then **Run anyway**.

**Linux (x86_64)**
```bash
tar -xzf ApesVsAliens-<version>-linux.tar.gz
chmod +x ApesVsAliens.x86_64
./ApesVsAliens.x86_64
```

**Requirements:** a 64-bit system with a GPU and driver that support **Vulkan** (the game uses Godot's Forward+ renderer). On Linux that usually means your distribution's Vulkan/Mesa packages are installed.

Settings are saved automatically in your user data folder.

## Build from source

1. Install [Godot](https://godotengine.org/) **4.5.1**.
2. Clone this repository and open `project.godot` in the editor.
3. Press **F5** to run.

To make Windows and Linux builds, see [RELEASING.md](RELEASING.md).

## Project layout

```
scripts/        Game code (GameManager, player, bots, HUD, menus, ...)
classes/        The three playable classes (.tres resources: stats and abilities)
assets/audio/   Sound effects
tools/          Helper scripts (tools/make_sfx.py regenerates the placeholder sounds)
*.tscn          Scenes: main menu, class select, level, HUD, round end
```

Handy places to tune the game:
- **Class stats and bot aim:** `classes/*.tres`
- **Difficulty multipliers:** the table at the top of `scripts/game_settings.gd`
- **Ability descriptions shown in the UI:** `scripts/character_class.gd`

## Credits

- Built with the [Godot Engine](https://godotengine.org/) (MIT license).
- Placeholder sound effects (abilities, countdown, jingles, and so on) are synthesized by `tools/make_sfx.py`.
- The shoot, hit, capture, and Bulwark sounds: [Kenney Sounds](https://kenney.nl/assets/sci-fi-sounds) [CCO License](https://creativecommons.org/publicdomain/zero/1.0/)

## License

Not yet decided.
