# FFXI-DLSS5-Clarity

DLSS DLAA + DLSS 5 neural rendering for **Final Fantasy XI**, packaged for the loaders people
actually use (Ashita, HorizonXI, Phoenix, retail-style bootloaders), without blurring when the camera moves.

FFXI is a 2002 32-bit Direct3D 8 game with no DLSS of its own. This package wires together
existing community work (credited in [CREDITS.md](CREDITS.md)) and adds a patched OptiScaler build
that fixes the problems we hit on FFXI:

| Problem | Fix (in the [OptiScaler_DLSSNR `ffxi-clarity` fork](https://github.com/OpMoonRise2/OptiScaler_DLSSNR/tree/v1.1.0-ffxi)) |
|---|---|
| Everything smears while the camera moves | **Prevent DLAA motion smearing**: DLAA's history is reset every frame while neural rendering keeps its own |
| One neural pass is too subtle | **Neural passes 1-3**, each pass with its own history, refining the previous pass's result |
| Extra passes crush dark detail to black | **Extra-pass taper**: passes 2-3 run local structure/tone at a fraction of pass 1 |
| Switching pass count means opening a menu | **Ctrl+Shift+F1 / Ctrl+Shift+F2** for 1 or 2 passes, while the game has focus |

**FFXI only.** Every part is set up for FFXI: dgVoodoo's Direct3D 8 path, the depth filter (FFXI draws its
3D scene into a square background buffer), the Shader Toggler's shader list (FFXI's UI shaders, which keep
the effects off the UI) and the fork's FFXI history fixes. On other games none of that applies, and
dgVoodoo's licence only allows shipping it with a mod for a particular game. For other games use
[DLSS5-Feeder](https://github.com/jlrouzies-fr/DLSS5-Feeder) directly.

## What to expect

- **Look:** DLAA anti-aliasing plus DLSS 5's neural relighting of the image. The shipped style is
  **Cinematic** (film-like, less shine); see [Looks](#looks).
- **Cost:** heavy. On an RTX 4060 8GB at 2560x1440 the neural model takes about 23 ms of GPU time per
  frame (19-29 ms), and the game runs at about 27-29 fps, against FFXI's own 30 fps cap. Slower cards or
  higher resolutions land below that.
- **A second window:** a "DLSS 5 Feed host" window runs beside the game. It is the 64-bit helper that talks
  to NVIDIA's runtime, which a 32-bit game cannot load.
- **dgVoodoo2** renders FFXI through Direct3D 11 so ReShade can see the scene's depth.

## Requirements

- An NVIDIA RTX GPU. NVIDIA officially enables DLSS 5 neural rendering on RTX 50 cards only. This package
  was tested on an **RTX 4060 8GB** with drivers **616.92 and 616.56** (the current stack was played on
  616.56). On RTX 20/30/40, whether the neural pass runs depends on the `nvngx_dlssnr.dll` you supply
  (see the DLSS5-Feeder README); if it does not run, you still get DLAA.
- Two NVIDIA files you supply yourself (licensing does not allow including them):
  `nvngx_dlss.dll` (DLSS, tested 310.9.1) and `nvngx_dlssnr.dll` (neural model, tested 310.8.0).
  See the [DLSS5-Feeder README](https://github.com/jlrouzies-fr/DLSS5-Feeder) for where to get them.
- Your FFXI client's **3D background resolution set to 4096x4096** (or pass `-DepthFilter <size>` to match yours).

## Install

1. Close FFXI. Download the release zip and extract the `FFXI-DLSS5-Clarity-<version>` folder
   **directly inside** your client's `bootloader` folder, e.g. `Ashita\bootloader\FFXI-DLSS5-Clarity-1.2.0\`.
2. Put the two NVIDIA DLLs in its `Dependencies\` folder (skip if your `bootloader\host64\` already has them).
3. Run `Check.cmd`, then `Install.cmd`. Every file it replaces is backed up; `Restore.cmd` undoes it.
4. Run `bootloader\host64\dlss5-feed-host64.exe --test` once; expect `300/300 evaluates succeeded`.
5. Launch FFXI. On a fresh install **F5** opens ReShade (preset `FFXI-Clarity.ini`). The "DLSS 5 Feed host"
   window opens beside the game: **F6** there opens OptiScaler, and **Ctrl+F9** shows that panel inside the game.

Options: `Setup.ps1 -Action Install -Target "D:\Games\Ashita\bootloader" -DepthFilter 2048`.

**Phoenix launcher:** it manages the renderer itself. On every launch it re-stages its own dgVoodoo and
regenerates `bootloader\dgVoodoo.conf` from its settings, so hand edits to that file never last. Before
installing, set its graphics output to **D3D11** (the installer refuses D3D12) and **MSAA Off**, and keep
MSAA off: with MSAA on, the Shader Toggler can no longer keep the effects off the game's UI.

## What the installer changes

It works only inside the bootloader folder it is pointed at (by default, the bootloader the package folder sits in).

- **Installed if missing, kept if identical, otherwise the install is refused:** `d3d8.dll` (dgVoodoo; one
  other tested build is also accepted), `dxgi.dll` and `host64\dxgi.dll` (ReShade). It never overwrites
  another graphics wrapper.
- **Added, or replaced when different:** `dlss5-feed.addon32`, `ReshadeEffectShaderToggler.addon32` and
  `.ini`, `FFXI-Clarity.ini`, `presets\`, `ffxi-clarity-shaders\`, `host64\dlss5-feed-host64.exe`,
  `host64\winmm.dll` (the patched OptiScaler), `host64\nvngx.dll_dlssnr.dll`, and the two NVIDIA DLLs from
  `Dependencies\` when `host64\` has none.
- **Settings it writes:**
  - `dlss5-feed.cfg`: forces `enabled`, `mode`, `reset_every`, `async_home`, `hold_strength`, `mv_scale_x/y`,
    `work_resolution` and `work_upscale` to the tested values, and adds the other tested keys only if missing.
  - `host64\OptiScaler.ini`: the tested file if you have none. An existing one keeps your values; only
    `ResetDlaaHistory=true` and DLSS-NR `Enabled=true` are set in it.
  - `host64\ReShade.ini`: only if missing.
  - `ReShade.ini`: adds the `ffxi-clarity-shaders` search paths and, unless you already set one, the depth filter.
    If there is none, it writes a minimal one (F5 overlay, preset `FFXI-Clarity.ini`).
  - `dgVoodoo.conf`: only if missing (Direct3D 11, no watermark).
- **Backups:** every file it replaces goes to `FFXI-Clarity-backup-<id>\` with a receipt. `Restore.cmd` puts
  them back and moves the files it added aside; it stops if anything changed since the install.
- **It refuses, and writes nothing,** when FFXI or the helper is running, a wrapper differs from the tested
  ones, `dgVoodoo.conf` is not Direct3D 11 FL11, another neural consumer (RenoDX, Deep Fried Chicken) is in
  `host64\`, the NVIDIA DLLs are missing, an existing `reshade-shaders\` already has a `DLSS5_Feed.fx` but not
  exactly this package's shaders, or a package file fails its hash check.
- **It never** downloads anything, touches drivers or launcher settings, or installs LumeniteFX or Zenteon shaders.

## Looks

- `FFXI-Clarity.ini` (default): VORT motion vectors + DLSS feed only. Clean and cheap.
- `presets\Clarity-Lumenite-Strong.ini`: adds LumeniteFX lighting and Zenteon TurboGI. These
  shaders are **not included**; see [LIGHTING-EXTRAS.md](LIGHTING-EXTRAS.md).
- `presets\Clarity-Lumenite-QuantMotion.ini`: the current played-on look. LumeniteFX QuantMotion supplies
  DLSS's motion vectors (provider 4), with Lumenite AO, TRAA and SSSR. Also needs LumeniteFX.
- Neural style: OptiScaler (**F6**) > DLSS-NR > Style: Default, Natural or **Cinematic** (`Style = 2` in
  `host64\OptiScaler.ini`; fresh installs get Cinematic). Cinematic tones down shine and over-processing for
  a film-like look. Press **Save INI** in that menu after changing anything, or it is lost on exit.

## Performance (RTX 4060 8GB, 2560x1440)

| Setup | FPS | Notes |
|---|---|---|
| Shipped defaults: 1 neural pass, working scale 0.93, Cinematic | ~27-29 | FFXI caps at 30; neural model ~23 ms/frame |
| 1 pass at 55-71% model resolution (1.1.x tuning) | ~28-30 | smoothest |
| 2 passes (taper 0.5) at 55-71% | ~22-24 | clear quality jump |
| 3 passes | ~15 | works, too slow on this card |

Frame generation (e.g. Lossless Scaling) is separate and not configured by this package.

## Changes

- **1.2.0** (played on 2026-10-02: RTX 4060, driver 616.56, Phoenix and Ashita): DLSS5-Feeder **1.17.0**
  (protocol v11). `dlss5-feed.addon32`, `host64\dlss5-feed-host64.exe` and `DLSS5_Feed.fx` must come from
  the same Feeder release; `tools\known-good.json` now pins all three. Same OptiScaler fork DLL and neural
  forwarder as 1.1.1. New tested tuning: `OptiScaler.ini` DLSS-NR preset 1, Style 2 (Cinematic), intensity
  1.30, working scale 0.93, pass taper 0.16; `dlss5-feed.cfg` async home, work upscale, sharpness 0.49 and
  output hold 0.182/0.040, which the installer now forces in place of the 1.1.1 values. New
  `presets\Clarity-Lumenite-QuantMotion.ini`. Release zips now carry every licence notice their files need
  (VORT, and MinHook, Dear ImGui and dlss5-bridge inside the Feeder binaries) and no longer ship the unused
  `ReShadeUI.fxh`. `Build-Release.ps1` takes the feeder effect and VORT from whichever shader folder has
  them. Phoenix launcher notes (D3D11, MSAA off).
- **1.1.1**: fixes regressions in 1.1.0. Ships the tested neural forwarder (`nvngx.dll_dlssnr.dll`,
  the one every tested setup used) instead of a fresh build that made extra passes crush detail. A fresh
  install now gets the full tested `OptiScaler.ini` (F6 menu key, pass and taper tuning) and the helper's
  `ReShade.ini`, instead of a minimal stub. `dlss5-feed.cfg` is written one key per line with a final
  newline, so `host_window=1` can no longer end up glued to the previous line (hidden helper window).
  Existing files are still kept, never replaced.
- **1.1.0**: first release.

## Building

- DLL: `git clone -b ffxi-clarity --recurse-submodules https://github.com/OpMoonRise2/OptiScaler_DLSSNR`,
  then build `OptiScaler.sln` Release x64 (VS 2022+/v143 or v145). Output `x64\Release\OptiScaler.dll`
  becomes `host64\winmm.dll`. The shipped `winmm.dll` is built from the source at tag `v1.1.0-ffxi`
  (identical apart from the embedded commit id).
- Release zip: `tools\Build-Release.ps1 -StackDir <working, played-on bootloader>`. It refuses to build unless
  the stack's `host64\winmm.dll`, `host64\nvngx.dll_dlssnr.dll`, Feeder pair and `DLSS5_Feed.fx` match
  `tools\known-good.json`, nothing non-redistributable slipped in, and every licence notice is present.
- Tests: `tools\Test-Installer.ps1 -Package dist\FFXI-DLSS5-Clarity-<version> -NvidiaDir <folder with the two
  NVIDIA DLLs>` installs into throwaway fake bootloaders and checks the result.

## Status

Unofficial community mod, not affiliated with Square Enix, NVIDIA or any server. Square Enix's terms for
its official servers prohibit third-party tools that modify the game client; check your server's rules
before using this. Personal-rig tested; other GPUs, drivers and loaders are unverified. Report the loader,
GPU, driver and failing step.
