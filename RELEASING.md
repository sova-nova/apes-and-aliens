# Releasing

How to turn the project into builds that other people can run. Windows is the priority; Linux works the same way.

## One-time setup

1. **Install export templates.** In the Godot editor: **Editor > Manage Export Templates > Download and Install**. The version must match your editor exactly.
2. **Set the project info.** **Project > Project Settings** (turn on *Advanced Settings* for the last one):
   - *Application > Config > Name*: `Apes vs Aliens`. This becomes the window title. (It also names your settings folder, so your saved settings reset once.)
   - *Application > Config > Version*: `0.1.0`. Shown on the main menu and used by the Windows build.
   - *Display > Window > Stretch > Mode*: `canvas_items`, and *Aspect*: `expand`. Without this the UI stays tiny on big monitors and fullscreen.
   - Optional: *Application > Config > Icon*. The default is the Godot logo. The Windows build converts your icon automatically.
3. **Check the presets.** **Project > Export** should list **Windows Desktop** and **Linux** (they come from `export_presets.cfg`). If they're missing, click **Add...** and create them with those exact names.
   - Windows: leave **Embed PCK** *off*. A separate `.pck` avoids antivirus false positives.
   - Linux: **Embed PCK** *on* (a single file).

## Make a build by hand

1. **Project > Export**, pick the preset, click **Export Project...**.
2. Make sure **Export With Debug** is *unchecked*. A debug build is slower and turns the dev-only class-swap keys back on.
3. Save to the path the preset suggests (`build/windows/...` or `build/linux/...`). The `build/` folder is git-ignored.

**Windows** gives you `ApesVsAliens.exe` and `ApesVsAliens.pck`. You need both. Ignore any `*.console.exe`.
Zip the two files as `ApesVsAliens-v0.1.0-windows.zip`.

**Linux** gives you one file, `ApesVsAliens.x86_64`. Package it as a `.tar.gz` (a zip would lose the executable permission):
```
tar -czf ApesVsAliens-v0.1.0-linux.tar.gz -C build/linux .
```
If you exported from Windows the file isn't marked executable; players run `chmod +x` (the README says so).

## Test the exported build, not just the editor

Copy the Windows folder somewhere else (Desktop, a USB stick, another PC) and run it from there.

- It starts and shows the right title, icon, and version on the main menu.
- Play a full round: shooting, abilities, capturing points, the round-end screen, Next Round.
- Pause (Esc): Resume, Restart Round, Settings, Quit to Main Menu.
- Settings (sensitivity, volume, fullscreen, difficulty) survive closing and reopening.
- Sounds play. The 1/2/3 class-swap keys do **nothing** (they're debug-only).
- It runs at a good frame rate in fullscreen.

## Publish on GitHub

**By hand:** go to **Releases > Draft a new release**, create a tag like `v0.1.0`, attach the zip and the tar.gz, write a few lines about what's in it, and tick **Set as a pre-release** while the game is early. Publish.

**Automatically (GitHub Actions):** `.github/workflows/export.yml` builds both platforms and drafts a release.
1. In that file, set `godot_version` to your editor's version (**Help > About**, e.g. `4.5` or `4.5.1`). It must match.
2. Commit and push, then tag a release:
   ```
   git tag v0.1.0
   git push origin v0.1.0
   ```
3. Watch the **Actions** tab. When it finishes, a **draft** release appears under **Releases** with both downloads. Download and test them, then publish.

You can also run it from the Actions tab with **Run workflow** to get the builds as downloadable artifacts without making a release.

The workflow is new and hasn't been run yet, so the first run may need a small fix. If it fails, open the failed step in the Actions log and share the error.

## Things players might hit

- **Windows SmartScreen** warns about unsigned programs ("Windows protected your PC"). Players choose **More info > Run anyway**. Removing the warning needs a paid code-signing certificate.
- **Antivirus false positives** are possible for any unsigned game. Keeping the `.pck` separate (as configured) helps. Checking the exe on virustotal.com before release is a good habit.
- **Won't start / blank window:** the game needs a Vulkan-capable GPU and driver. If testers on older machines report this, we can switch the renderer to a more compatible one.

## Before every release

- Bump the version in **Project Settings** and tag it (`v0.1.1`, ...).
- Commit the `.import` files Godot generates next to new assets.
- Re-run the test list above on the exported build.
