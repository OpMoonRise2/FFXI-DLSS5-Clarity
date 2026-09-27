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

## Requirements

- An NVIDIA RTX GPU and a driver that ships DLSS 5 neural rendering (tested: **RTX 4060 8GB, driver 616.92**).
- Two NVIDIA files you supply yourself (licensing does not allow including them):
  `nvngx_dlss.dll` (DLSS, tested 310.9.1) and `nvngx_dlssnr.dll` (neural model, tested 310.8.0).
  See the [DLSS5-Feeder README](https://github.com/jlrouzies-fr/DLSS5-Feeder) for where to get them.
- Your FFXI client's **3D background resolution set to 4096x4096** (or pass `-DepthFilter <size>` to match yours).

## Install

1. Close FFXI. Download the release zip and extract the `FFXI-DLSS5-Clarity-<version>` folder
   **directly inside** your client's `bootloader` folder, e.g. `Ashita\bootloader\FFXI-DLSS5-Clarity-1.1.0\`.
2. Put the two NVIDIA DLLs in its `Dependencies\` folder (skip if your `bootloader\host64\` already has them).
3. Run `Check.cmd`, then `Install.cmd`. Every file it replaces is backed up; `Restore.cmd` undoes it.
4. Run `bootloader\host64\dlss5-feed-host64.exe --test` once; expect `300/300 evaluates succeeded`.
5. Launch FFXI. **F5** opens ReShade (preset `FFXI-Clarity.ini`), **F6** opens OptiScaler in the helper window.

Options: `Setup.ps1 -Action Install -Target "D:\Games\Ashita\bootloader" -DepthFilter 2048`.
The installer refuses unknown graphics wrappers rather than overwriting them.

## Looks

- `FFXI-Clarity.ini` (default): VORT motion vectors + DLSS feed only. Clean and cheap.
- `presets\Clarity-Lumenite-Strong.ini`: adds LumeniteFX lighting and Zenteon TurboGI. These
  shaders are **not included**; see [LIGHTING-EXTRAS.md](LIGHTING-EXTRAS.md).

## Performance (RTX 4060 8GB, 2560x1440, 55-71% model resolution)

| Neural passes | FPS | Notes |
|---|---|---|
| 1 | ~28-30 | smoothest |
| 2 (taper 0.5) | ~22-24 | clear quality jump |
| 3 | ~15 | works, too slow on this card |

Frame generation (e.g. Lossless Scaling) is separate and not configured by this package.

## Building

- DLL: `git clone -b ffxi-clarity --recurse-submodules https://github.com/OpMoonRise2/OptiScaler_DLSSNR`,
  then build `OptiScaler.sln` Release x64 (VS 2022+/v143 or v145). Output `x64\Release\OptiScaler.dll`
  becomes `host64\winmm.dll`; `x64\Release\a\nvngx.dll_dlssnr.dll` ships beside it.
- Release zip: `tools\Build-Release.ps1 -StackDir <working bootloader> -ForkBuildDir <fork>\x64\Release`.

## Status

Unofficial community mod, not affiliated with Square Enix, NVIDIA or any server. Personal-rig tested;
other GPUs, drivers and loaders are unverified. Report the loader, GPU, driver and failing step.
