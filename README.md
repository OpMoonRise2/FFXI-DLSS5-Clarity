# FFXI-DLSS5-Clarity

DLSS DLAA + DLSS 5 neural rendering for **Final Fantasy XI**, packaged for the loaders people
actually use (Ashita, HorizonXI, Phoenix, Windower 4, retail PlayOnline / Steam), without blurring when the camera moves.

> **Use at your own risk.** Free, unofficial community mod, provided **as is, with no warranty**. The author is
> **not liable** for any damage or loss from using it (see [DISCLAIMER.md](DISCLAIMER.md) and [LICENSE](LICENSE)).
> The installer backs up every file it changes and `Restore.cmd` undoes it, but keep your own backups. You are
> responsible for your own system, drivers, settings and other mods, and for the NVIDIA DLLs you download from
> third parties. Client mods may break a server's rules: check yours first, because any account action is your
> responsibility. Not affiliated with Square Enix, NVIDIA or any server. By installing, you accept these terms.

FFXI is a 2002 32-bit Direct3D 8 game with no DLSS of its own. This package wires together
existing community work (credited in [CREDITS.md](CREDITS.md)) and adds a patched OptiScaler build
that fixes the problems we hit on FFXI:

| Problem | Fix (in the [OptiScaler_DLSSNR `ffxi-clarity` fork](https://github.com/OpMoonRise2/OptiScaler_DLSSNR/tree/v1.2.1-ffxi)) |
|---|---|
| Everything smears while the camera moves | **Prevent DLAA motion smearing**: DLAA's history is reset every frame while neural rendering keeps its own |
| One neural pass is too subtle | **Neural passes 1-3**, each pass with its own history, refining the previous pass's result |
| Extra passes crush dark detail to black | **Extra-pass taper**: passes 2-3 run local structure/tone at a fraction of pass 1 |
| Switching pass count means opening a menu | **Ctrl+Shift+F1 / Ctrl+Shift+F2** for 1 or 2 passes, while the game has focus |
| Comparing neural off/on and styles means opening a menu | **Ctrl+Shift+F3** neural pass off (DLAA stays); **Ctrl+Shift+F4 / F5 / F6** neural on with Default / Natural / Cinematic |
| On a fresh install the helper window had no ReShade, so no **Ctrl+F9** panel in the game | **ReShade-first dxgi load**: OptiScaler loads the `dxgi.dll` beside the helper before Windows' own, every launch, not only when the helper wins a start-up race |

**FFXI only.** Every part is set up for FFXI: dgVoodoo's Direct3D 8 path, the depth filter (FFXI draws its
3D scene into a background buffer larger than the screen), the Shader Toggler's shader list (FFXI's UI shaders, which keep
the effects off the UI) and the fork's FFXI history fixes. On other games none of that applies, and
dgVoodoo's licence only allows shipping it with a mod for a particular game. For other games use
[DLSS5-Feeder](https://github.com/jlrouzies-fr/DLSS5-Feeder) directly.

## What to expect

- **Look:** DLAA anti-aliasing plus DLSS 5's neural relighting of the image. The shipped style is
  **Cinematic** (film-like, less shine); see [Looks](#looks).
- **Cost:** heavy. On an RTX 4060 8GB at 2560x1440 the neural model takes about 20-23 ms of GPU time per
  frame (20 ms at the shipped working scale 0.86, 23 ms at 0.93), and the game runs at about 27-29 fps,
  against FFXI's own 30 fps cap. Slower cards or higher resolutions land below that.
- **A second window:** a "DLSS 5 Feed host" window runs beside the game. It is the 64-bit helper that talks
  to NVIDIA's runtime, which a 32-bit game cannot load.
- **dgVoodoo2** renders FFXI through Direct3D 11 so ReShade can see the scene's depth.

## Requirements

- **An NVIDIA RTX GPU** (GeForce RTX 20 series or newer, or an RTX workstation card). GTX, MX, AMD and Intel
  cards cannot run DLSS: `Check.cmd` refuses them. This package was tested on an **RTX 4060 8GB** with
  drivers **616.92 and 616.56** (the current stack was played on 616.56).
- Two NVIDIA files you supply yourself (licensing does not allow including them):
  - `nvngx_dlss.dll` (DLSS, tested 310.9.1; from any DLSS game or DLSS Swapper).
  - `nvngx_dlssnr.dll` (the neural model). **Which build matters, and the version number does not tell them
    apart:** both say 310.8.0.
    - **RTX 20/30/40:** you need the **modified build** from the [RenoDX Discord](https://discord.com/invite/renodx)
      (see the [DLSS5-Feeder README](https://github.com/jlrouzies-fr/DLSS5-Feeder)). The tested copy has SHA-256
      `8270B350CD82DE5CE89806872CDD6B6A9249B80836B91BBEB3573470744CC206`.
    - **RTX 50:** NVIDIA's original signed build works, and so does the modified one.

    NVIDIA's original build creates the neural feature on RTX 50 cards only. On an RTX 20/30/40 card it fails
    without any visible error and you get DLAA alone. `Check.cmd` refuses that combination and says what to do;
    see [Troubleshooting](#troubleshooting).
- Your FFXI client's **3D background resolution set to 4096x4096** (or pass `-DepthFilter <size>` to match yours).
  It must not equal your window resolution; see [Why the background resolution matters](#why-the-background-resolution-matters).
  **Windower 4** has no background resolution setting: the installer sets it for you. See [Windower 4](#windower-4).

## Install

1. Close FFXI. Download the release zip and extract the `FFXI-DLSS5-Clarity-<version>` folder
   **directly inside** your client's `bootloader` folder, e.g. `Ashita\bootloader\FFXI-DLSS5-Clarity-1.3.1\`.
   On Windower 4 that is the folder your Windower profile starts the game from: the folder holding its loader
   on a private server, or the PlayOnline folder holding `pol.exe` on retail (see [Windower 4](#windower-4)).
   On retail started from PlayOnline or Steam, it is the PlayOnline folder holding `pol.exe` (see
   [Retail](#retail-playonline--steam)).
2. Put the two NVIDIA DLLs in its `Dependencies\` folder. You can skip this if your `bootloader\host64\` already
   has them; a file you put in `Dependencies\` replaces a different one in `host64\` (backed up).
3. Run `Check.cmd`, then `Install.cmd`. Every file it replaces is backed up; `Restore.cmd` undoes it.
4. Run `Test.cmd` once; expect `300/300 evaluates succeeded`. (Double-clicking `host64\dlss5-feed-host64.exe`
   only shows "nothing to run here": the helper is started by the game.)
5. Launch FFXI. A second window, "DLSS 5 Feed host", opens beside the game. See [Shortcuts](#shortcuts) for
   how to open each settings menu.

Something not working? Run `CollectLogs.cmd` and see [Reporting a problem](#reporting-a-problem).

## Shortcuts

Where you press a key matters: the game window and the "DLSS 5 Feed host" helper window are two programs.

| Key | Press it in | What it does |
|---|---|---|
| **Ctrl+F9** | the game | Shows the helper window (with OptiScaler's menu, if open) inside the game, and hides it again. Use this if you don't want to Alt+Tab |
| **F6** or **Insert** | the helper window (Alt+Tab to it, or Ctrl+F9 first) | Opens **OptiScaler**, where the DLSS and neural settings are (DLSS-NR section). Press **Save INI** there or changes are lost on exit. F6 is set in `host64\OptiScaler.ini` (`ShortcutKey = 0x75`) for keyboards without Insert; Insert always works too |
| **Home** | the helper window | Opens the helper's own ReShade overlay (DLSS 5 Feed host settings) |
| **F5** (fresh install) or your own ReShade key | the game | Opens the game's ReShade overlay: effects, preset and the DLSS 5 Feed effect. An existing `ReShade.ini` keeps its key (often **Home**) |
| **Ctrl+Shift+F1 / F2** | the game (works anywhere) | 1 or 2 neural passes |
| **Ctrl+Shift+F3** | the game (works anywhere) | Neural pass off, DLAA stays on (for comparisons) |
| **Ctrl+Shift+F4 / F5 / F6** | the game (works anywhere) | Neural pass on with style Default / Natural / Cinematic |

The Ctrl+Shift keys are not saved: the next start uses `host64\OptiScaler.ini` again. To start with 2 neural
passes every time, set them in OptiScaler's DLSS-NR section and press **Save INI**, or, with the game closed, set
`Passes = 2` under `[DlssNr]` in `host64\OptiScaler.ini` (the shipped `auto` means 1). The helper's title bar
names the menu key in use (for example "press F6/Insert HERE for OptiScaler's menu | in game: Ctrl+F9 shows this window").

Options: `Setup.ps1 -Action Install -Target "D:\Games\Ashita\bootloader" -DepthFilter 2048`.

**Phoenix launcher:** it manages the renderer itself. On every launch it re-stages its own dgVoodoo and
regenerates `bootloader\dgVoodoo.conf` from its settings, so hand edits to that file never last. Before
installing, set its graphics output to **D3D11** (the installer refuses D3D12) and **MSAA Off**, and keep
MSAA off: with MSAA on, the Shader Toggler can no longer keep the effects off the game's UI.

## Retail (PlayOnline / Steam)

Retail works when started straight from PlayOnline or Steam (played on Steam retail, 2026-10-22). Square Enix's
terms for the official servers prohibit third-party tools that modify the client: see the notice at the top.

1. Close FFXI and PlayOnline. Extract the package into the PlayOnline folder that holds `pol.exe`, for example
   `C:\Program Files (x86)\PlayOnline\SquareEnix\PlayOnlineViewer\FFXI-DLSS5-Clarity-1.3.1\` or, on Steam,
   `...\steamapps\common\FFXINA\SquareEnix\PlayOnlineViewer\FFXI-DLSS5-Clarity-1.3.1\`.
2. Run `Check.cmd`, then `Install.cmd`, as in [Install](#install). It recognises the PlayOnline folder (from
   the registry, or the `FINAL FANTASY XI` folder beside it) and says so.

What is different from a loader install:

- **Two folders.** PlayOnline runs the game inside `pol.exe`, but the game loads Direct3D 8 from the
  `FINAL FANTASY XI` folder, not from beside `pol.exe`. The installer also puts dgVoodoo's `d3d8.dll` and the
  same `dgVoodoo.conf` there (backed up; `Restore.cmd` takes them out again). ReShade, the add-ons and
  `host64\` stay beside `pol.exe`. Without the copy in the game folder the game runs on Windows' own
  Direct3D 8 and ReShade never sees it.
- **No ReShade in the PlayOnline menus.** A DirectDraw wrapper beside `pol.exe` (dgVoodoo's `DDraw.dll` and
  `D3DImm.dll`, often left over from another mod) puts ReShade into the PlayOnline menus, and `pol.exe` then
  crashes when PlayOnline starts FFXI. `Check.cmd` refuses it: move those two files out. ReShade and the
  "DLSS 5 Feed host" window then appear when the game window opens, not before.
- **Nothing else in the game folder.** Another graphics mod's `d3d9.dll` (DXVK), `dxgi.dll` (ReShade),
  `version.dll` (DLSS Enabler), `d3d11.dll` or `dinput8.dll` in `FINAL FANTASY XI` is refused: move it out.
- **Depth filter from the registry.** The depth filter is set to FFXI's background resolution in the registry
  (4096x4096 played on). The current FINAL FANTASY XI Config tool writes that value from its own graphics
  settings every time you save (often 3840x2160 or 4096x2304), so run `Install.cmd` again after changing
  settings there. The background must be larger than the window, see
  [Why the background resolution matters](#why-the-background-resolution-matters). To set 4096x4096 yourself,
  close the Config tool and run in an administrator command prompt:
  ```
  reg add "HKLM\SOFTWARE\WOW6432Node\PlayOnlineUS\SquareEnix\FinalFantasyXI" /v 0003 /t REG_DWORD /d 4096 /f
  reg add "HKLM\SOFTWARE\WOW6432Node\PlayOnlineUS\SquareEnix\FinalFantasyXI" /v 0004 /t REG_DWORD /d 4096 /f
  ```
  (`PlayOnlineEU` / `PlayOnline` on European and Japanese clients.) `-DepthFilter <size>` overrides it.

Windower on retail: see [Windower 4](#windower-4); the game-folder copy above is made there too.

## Windower 4

Windower 4 works on private servers and on retail. Close the Windower launcher and the game first.

- **Private server:** extract the package into the folder holding the loader your Windower profile starts
  (the profile's executable is, for example, `bootloader\xiloader.exe`). When that folder sits inside the
  Windower folder it is found by itself: run `Check.cmd` and `Install.cmd` as usual. Otherwise pass Windower's
  folder: `Install.cmd -Windower "D:\Games\Windower4"`.
- **Retail:** your profile starts `pol.exe`, so extract the package into the PlayOnline folder that holds it
  (for example `C:\Program Files (x86)\PlayOnline\SquareEnix\PlayOnlineViewer\FFXI-DLSS5-Clarity-1.3.1\`)
  and pass Windower's folder: `Check.cmd -Windower "C:\Windower4"`, then `Install.cmd -Windower "C:\Windower4"`.
  The installer finds `pol.exe` the way Windower does (beside Windower, then PlayOnline's install folder).

For the profile that starts the game from this folder, the installer sets these in Windower's `settings.xml`.
The Windower launcher writes them to the registry on every start, so they last:

| Setting | Value | Why |
|---|---|---|
| `supersampling` | **1.6** (one you set above 1 is kept; `-SuperSampling 2.0` picks another) | Windower's background (3D) resolution is window size x supersampling. At 1.0 it equals the screen, see below |
| `width` / `height` | your window resolution, from the registry if the profile has none | without them Windower cannot work out the 3D size |
| `bumpmapping` | **true** | the setting the Shader Toggler list was taken on (Ashita, bump mapping on) |

`ReShade.ini`'s depth filter is set to that 3D size, for example **4096x2304** at 2560x1440 (**3072x1728** at
1920x1080). It is not square on Windower, so `-DepthFilter` is not used there. If you later change the window
resolution or supersampling in the Windower launcher, run `Install.cmd` again so the depth filter follows.
**Do not set supersampling back to 1** in the Windower launcher: the blinking comes back.

`Restore.cmd` puts those `settings.xml` values back, except any you changed in the launcher since (it says so).
The original `settings.xml` is also kept in the backup folder as `windower-settings.xml`.

Known limits on Windower, the same as on Ashita: nameplates get the effects (FFXI draws them with the
world's shaders), and some shadows flicker slightly.

### Why the background resolution matters

The Shader Toggler starts the effects on the first draw whose render target is the size of the screen. When
FFXI's 3D background resolution is different from the screen, the 3D scene is drawn into its own buffer and
the first screen-sized draw is the scale-down of the finished scene, after all the 3D and before the UI:
one clean point every frame. When the two sizes are equal (Windower's default, supersampling 1.0), the 3D
draws themselves are screen-sized. The effects then start somewhere inside the scene, at a point that moves
with draw order. Characters and NPC body parts blink and lose shading, shadows in tunnels shake, nameplates
move with the camera, zones load in dark, and the DLSS feed rebuilds every few seconds, which wipes its
history. Picking other shader hashes only moves the problem.

## What the installer changes

It works only inside the bootloader folder it is pointed at (by default, the bootloader the package folder sits in).

- **Wrappers: installed if missing, kept if identical, replaced if another build:** `d3d8.dll` (dgVoodoo 2.87.5;
  2.87.2, which 1.2.x shipped, is replaced), `dxgi.dll` and `host64\dxgi.dll` (ReShade). Another dgVoodoo or ReShade
  build (from a launcher or another mod such as Deep Fried Chicken) is backed up and replaced by the tested one.
  A file that is some other wrapper is never overwritten: `Check.cmd` says which file to move aside.
- **Added, or replaced when different:** `dlss5-feed.addon32`, `ReshadeEffectShaderToggler.addon32` and
  `.ini`, `FFXI-Clarity.ini`, `presets\`, `ffxi-clarity-shaders\`, `host64\dlss5-feed-host64.exe`,
  `host64\winmm.dll` (the patched OptiScaler), `host64\nvngx.dll_dlssnr.dll`, the two NVIDIA DLLs from
  `Dependencies\` when `host64\` has none or a different copy (that one is backed up), and `reshade-shaders\Shaders\DLSS5_Feed.fx` when an existing one is
  from another Feeder release (the effect must match the shipped add-on). An existing `reshade-shaders\` that
  already holds the feeder effect stays your effect root; nothing else is required inside it.
- **Settings it writes:**
  - `dlss5-feed.cfg`: forces `enabled`, `mode`, `reset_every`, `async_home`, `hold_strength`, `mv_scale_x/y`,
    `work_resolution` and `work_upscale` to the tested values, and adds the other tested keys only if missing.
    `cast_key=0` (Ctrl+F9 switched off) is set back to Ctrl+F9; a different key you chose is kept.
  - `host64\OptiScaler.ini`: the tested file if you have none. An existing one keeps your values; only
    `ResetDlaaHistory=true` and DLSS-NR `Enabled=true` are set in it.
  - `host64\ReShade.ini`: only if missing.
  - `ReShade.ini`: adds the `ffxi-clarity-shaders` search paths (only its VORT folder when your
    `reshade-shaders\` already holds the feeder effect, so ReShade never sees two `DLSS5_Feed.fx`, and only its
    textures when VORT is there too, so ReShade never sees two VORTs), the depth
    filter unless you already set one, and `RESHADE_DEPTH_INPUT_IS_REVERSED=0` (with upside-down and
    logarithmic at 0) unless the orientation is already decided there: FFXI's depth is not reversed, and
    ReShade assumes reversed when nothing says otherwise. If there is none, it writes a minimal one (F5
    overlay, preset `FFXI-Clarity.ini`).
  - `dgVoodoo.conf`: written if missing (Direct3D 11, no watermark); an existing one set to another output API
    (for example D3D12) gets `OutputAPI = d3d11_fl11_0`, everything else kept.
- **Backups:** every file it replaces goes to `FFXI-Clarity-backup-<id>\` with a receipt. `Restore.cmd` puts
  them back and moves the files it added aside; it stops if anything changed since the install.
- **It refuses, and writes nothing,** when Windows reports no NVIDIA RTX card, FFXI or the helper is running, `d3d8.dll` / `dxgi.dll` belong to
  another wrapper (not dgVoodoo / ReShade), `dgVoodoo.conf` is in dgVoodoo's binary format, another neural
  consumer (RenoDX, Deep Fried Chicken) is in `host64\`, the NVIDIA DLLs are missing, or a package file fails
  its hash check. Each `NEEDED:` line in `Check.cmd` names the file and what to do.
- **Windower 4 only:** the profile values in [Windower 4](#windower-4), in Windower's `settings.xml`.
- **Retail PlayOnline only:** `d3d8.dll` and `dgVoodoo.conf` in the `FINAL FANTASY XI` folder too (backed up
  under `game\` in the backup folder), and the depth filter from the registry's background resolution. It
  refuses a DirectDraw wrapper beside `pol.exe` and other graphics wrappers in the game folder. See
  [Retail](#retail-playonline--steam).
- **It never** downloads anything, touches drivers or the registry, changes launcher settings other than
  Windower's (above), or installs LumeniteFX or Zenteon shaders.

## Looks

- `FFXI-Clarity.ini` (default): VORT motion vectors + DLSS feed only. Clean and cheap.
- `presets\Clarity-Lumenite-Strong.ini`: adds LumeniteFX lighting and Zenteon TurboGI. These
  shaders are **not included**; see [LIGHTING-EXTRAS.md](LIGHTING-EXTRAS.md).
- `presets\Clarity-Lumenite-QuantMotion.ini`: the current played-on look. LumeniteFX QuantMotion supplies
  DLSS's motion vectors (provider 4), with Lumenite AO, TRAA and SSSR. Also needs LumeniteFX. Known quirk,
  kept because it is the look that was played and recorded: Lumenite TRAA and SSSR read the `Kernel::` flow,
  normal and depth textures that only `lumenite_Kernel.fx` writes, and `Lumenite_Kernel` is not enabled in
  this preset, so TRAA reprojects with zero flow (its sharpening still applies) and SSSR traces against empty
  guides. Enable `Lumenite_Kernel` above DLSS 5 Feed if you want them fed; it costs GPU time.
- Neural style: OptiScaler (**F6** or **Insert** in the helper window) > DLSS-NR > Style: Default, Natural or
  **Cinematic** (`Style = 2` in `host64\OptiScaler.ini`; fresh installs get Cinematic; an existing ini keeps
  yours). Cinematic tones down shine and over-processing for a film-like look. Press **Save INI** in that menu
  after changing anything, or it is lost on exit. Ctrl+Shift+F4/F5/F6 switch styles for a quick comparison.

## Performance (RTX 4060 8GB, 2560x1440)

| Setup | FPS | Notes |
|---|---|---|
| Shipped defaults: 1 neural pass, working scale 0.86, Cinematic | ~27-29 | FFXI caps at 30; neural model ~20 ms/frame (23 ms at 0.93) |
| 1 pass at 55-71% model resolution (1.1.x tuning) | ~28-30 | smoothest |
| 2 passes (taper 0.5) at 55-71% | ~22-24 | clear quality jump |
| 3 passes | ~15 | works, too slow on this card |

Frame generation (e.g. Lossless Scaling) is separate and not configured by this package.

## Changes

- **1.3.1** (installer, tests and README; same binaries and settings as 1.3.0): **retail PlayOnline / Steam.**
  Started from PlayOnline or Steam without a loader, retail either crashed right after "Play Online" or ran
  without ReShade. Found on Steam retail on 2026-10-22, and played there after the fix:
  - The game loads Direct3D 8 from the `FINAL FANTASY XI` folder, not from beside `pol.exe`, so with dgVoodoo
    only beside `pol.exe` it ran on Windows' own Direct3D 8, which ReShade never sees. The installer now
    recognises the PlayOnline folder and also puts `d3d8.dll` and `dgVoodoo.conf` in the game folder (backed up,
    restorable).
  - A leftover dgVoodoo `DDraw.dll` / `D3DImm.dll` beside `pol.exe` put ReShade into the PlayOnline menus. When
    PlayOnline hands over to the game, ReShade unloads its add-ons, the Shader Toggler does not unregister, and
    `pol.exe` crashes in `ntdll.dll` (`0xc0000005`). Refused now, as are other graphics wrappers in the game folder.
  - The depth filter follows the background resolution in the registry, which the current FINAL FANTASY XI
    Config tool rewrites on every save.
  - An older VORT already in `reshade-shaders\` is used as it is; adding Clarity's VORT beside it made both
    fail with `X3067 ambiguous function` errors.
- **1.3.0** (dgVoodoo update; installer, tests and README): **fixes the crash on launch on RTX 50 PCs**
  ([#11](https://github.com/OpMoonRise2/FFXI-DLSS5-Clarity/issues/11),
  [#12](https://github.com/OpMoonRise2/FFXI-DLSS5-Clarity/issues/12)). 1.2.x shipped dgVoodoo 2.87.2, which
  crashes with an access violation at `d3d8.dll+0xa33cc` while FFXI creates its device, seen on an RTX 5060
  and an RTX 5090, each with a second graphics adapter. dgVoodoo 2.87.5 runs on the same PC. Both builds say
  4.8.2.134, so on Phoenix the installer also replaced the launcher's working 2.87.5 with 2.87.2. 1.3.0 ships
  2.87.5 (pinned in `tools\known-good.json`) and replaces 2.87.2 with its own message. Played on 2026-10-22
  (Windower 4, RTX 4060, 2560x1440): Shader Toggler hashes, UI masking and depth unchanged. Everything else is
  as in 1.2.9.
- **1.2.9** (installer, tests and README; same binaries and settings as 1.2.8): **retail Windower.** 1.2.8 only
  recognised Windower profiles that start a loader from the bootloader folder, so a retail profile (which
  starts `pol.exe`) was refused ([#10](https://github.com/OpMoonRise2/FFXI-DLSS5-Clarity/issues/10)).
  Profiles are now resolved the way the Windower launcher does it (the path as given, then beside Windower,
  then PlayOnline's install folder from the registry), so a package in the PlayOnline folder with
  `-Windower <folder>` gets the same supersampling, bump mapping and depth filter. The refusal now names what
  each profile starts and where to install instead.
- **1.2.8** (installer, support tools and README; same binaries and settings as 1.2.7): **Windower 4 support.**
  Under Windower the effects started inside the 3D scene, so characters blinked and lost shading, nameplates
  and tunnel shadows moved with draw order, and the DLSS feed rebuilt every few seconds. The cause: Windower
  sets FFXI's background resolution to window size x supersampling, 1.0 by default, so it equals the screen
  (Ashita's 4096x4096 does not). `Install.cmd` now finds Windower (or takes `-Windower <folder>`), sets
  supersampling 1.6 and bump mapping in the profile that starts this folder's loader, and sets the depth
  filter to the resulting 3D size (4096x2304 at 2560x1440). `Restore.cmd` puts those values back.
  `CollectLogs.cmd` adds Windower's `settings.xml`, with launch argument values (logins) redacted. Played on
  2026-10-22 (Windower 4, LSB, RTX 4060, 2560x1440): UI clean, zones load normally, the feed built once in
  17 minutes of play, and Generic Depth picked the 4096x2304 buffer by itself.
- **1.2.7** (documentation only; same binaries, installer and settings as 1.2.6): adds `DISCLAIMER.md`
  (as-is, assumption of risk, limitation of liability, no affiliation) to the package and a use-at-your-own-risk
  notice at the top of the README.
- **1.2.6** (installer and support tools; same binaries and settings as 1.2.5): 1.2.5's check for NVIDIA's
  original `nvngx_dlssnr.dll` could be skipped. When `Check.cmd` / `Install.cmd` were started from PowerShell 7 (or a
  tool that passes on its environment), Windows PowerShell could not load the signature check and treated the
  file as unknown, so the RTX 50-only build was installed. The module is now loaded explicitly; `CollectLogs.cmd`
  likewise. `Test.cmd` now prints the self-test result (it only went to the helper log).
- **1.2.5** (installer and support tools; same binaries and settings as 1.2.4): stops the "DLAA only on RTX
  20/30/40" trap. Both `nvngx_dlssnr.dll` builds say 310.8.0, but NVIDIA's original runs the neural pass on RTX 50
  only.
  - `Check.cmd` and `Install.cmd` tell the builds apart (by hash, else by NVIDIA's signature) and refuse the
    original build on a confirmed RTX 20/30/40, naming the card and the fix (`-AllowDlaaOnly` overrides).
  - A DLL you put in `Dependencies\` now replaces a different copy in `host64\` (backed up). Before, `host64\`
    always won and a corrected file was silently ignored.
  - New `Test.cmd` runs the helper's self-test, which double-clicking the helper cannot do.
  - `CollectLogs.cmd` records both NVIDIA DLLs' version, hash and signature status.
  - README: which `nvngx_dlssnr.dll` to get, how to save 2 neural passes, and a Troubleshooting entry for
    `FAIL_FeatureNotSupported`.
- **1.2.4** (installer only; same binaries and settings as 1.2.3): `Check.cmd` and `Install.cmd` refuse a PC
  without an NVIDIA RTX card and name the card they found, instead of installing something that cannot run.
  Any RTX adapter passes (laptops also list their Intel/AMD graphics). If Windows cannot report the card, it
  warns and continues. `Restore.cmd` is not affected.
- **1.2.3** (support tools only; same binaries, settings and installer behaviour as 1.2.2):
  `CollectLogs.cmd` saves one zip with every log, config, the installed-file list with versions, `Check.cmd`'s
  output, GPU/driver and recent crash records (Windows user and PC names removed), so a problem report needs one
  attachment. GitHub issue form, and a crash-on-launch entry in Troubleshooting.
- **1.2.2** (installer only; same binaries and settings as 1.2.1): no more dead end for setups coming from
  another mod or launcher. 1.2.1 refused any other dgVoodoo or ReShade build with `Existing d3d8.dll differs from
  the tested stack ... requires wrapper integration`, which told users nothing they could act on. Now another
  build of the same wrapper is backed up and replaced (Restore.cmd puts it back), a text `dgVoodoo.conf` on D3D12
  or another output API is switched to D3D11 FL11, and every remaining refusal names the file and the fix (move
  the other wrapper or `host64\deep-fried-chicken*.addon64` aside, run Check.cmd again). New installer tests.
- **1.2.1** (release candidate; installer and helper verified in isolated installs, not yet played on): fixes two
  1.2.0 release defects. (1) On a fresh install the helper `host64\dlss5-feed-host64.exe` ran **without
  ReShade**: OptiScaler's GPU enumeration pinned Windows' `dxgi.dll` into the process before the helper loaded
  its own, so there was no overlay and no **Ctrl+F9** panel in the game (the helper log said `dxgi.dll here is
  Windows' own`). The played-on rig escaped this only because its extra `host64\OptiScaler\` libraries slowed
  OptiScaler's start by about 100 ms. The fork now loads the `dxgi.dll` beside the executable first (fork tag
  `v1.2.1-ffxi`; new `host64\winmm.dll`, which also ships the **Ctrl+Shift+F3-F6** neural off / style hotkeys
  the played-on rig already had). (2) The installer refused a working setup whose `reshade-shaders\` held the
  feeder effect but not VORT, with 21 `Existing shader differs or is incomplete` lines; it refused the very
  setup this package was tuned on. Now only the feeder effect must match (one from another Feeder release is
  replaced and backed up), VORT is added from `ffxi-clarity-shaders\`, and a stale `ffxi-clarity-shaders\`
  copy is refreshed. Also: `ReShade.ini` gets `RESHADE_DEPTH_INPUT_IS_REVERSED=0` when the orientation was
  never set; the shipped `OptiScaler.ini` is the 2026-10-02 reset default (working scale 0.86, FPS readout on);
  new Troubleshooting section; installer tests for the compatible-existing, stale-effect, explicit-depth and
  refusal cases. Settings access: Insert now opens OptiScaler in the helper alongside the configured key (F6),
  matching what the helper itself tells users; the helper's title bar names the real key; `cast_key=0` in an
  existing `dlss5-feed.cfg` (Ctrl+F9 off) is set back to Ctrl+F9; new Shortcuts table. Played on 2026-10-17
  (Ashita, LSB, RTX 4060, 616.56): ReShade in both processes, DLSS 310.9.1, depth reversed=0, ~29 fps.
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
  becomes `host64\winmm.dll`. The shipped `winmm.dll` is built from the source at tag `v1.2.1-ffxi` (its
  `ProductVersion` carries that commit id and the build time). The shipped `nvngx.dll_dlssnr.dll` is the unmodified
  forwarder from [Dagherbou's release `v0.2.0-patch1`](https://github.com/Dagherbou/OptiScaler_DLSSNR/releases/tag/v0.2.0-patch1).
- Release zip: `tools\Build-Release.ps1 -StackDir <working, played-on bootloader>`. It refuses to build unless
  the stack's `host64\winmm.dll`, `host64\nvngx.dll_dlssnr.dll`, Feeder pair and `DLSS5_Feed.fx` match
  `tools\known-good.json`, nothing non-redistributable slipped in, and every licence notice is present.
- Tests: `tools\Test-Installer.ps1 -Package dist\FFXI-DLSS5-Clarity-<version> -NvidiaDir <folder with the two
  NVIDIA DLLs>` installs into throwaway fake bootloaders and checks the result.

## Troubleshooting

Logs: `bootloader\dlss5-feed.log` (game side), `bootloader\host64\dlss5-feed-host.log` (helper),
`bootloader\host64\OptiScaler.log` (upscaler and neural pass), `bootloader\ReShade.log` and `host64\ReShade.log`.
`CollectLogs.cmd` gathers all of them (see [Reporting a problem](#reporting-a-problem)).

- **`Check.cmd` says `This needs an NVIDIA RTX graphics card`.** DLSS runs only on RTX cards, so the card it
  names cannot run this mod. `Microsoft Basic Display Adapter` means no graphics driver is installed: install
  the NVIDIA driver and run `Check.cmd` again. If you do have an RTX card and the name shown is wrong, open a
  command prompt in the package folder and run `Install.cmd -SkipGpuCheck`.
- **The game runs, DLSS works, but the neural look is missing (DLAA only).** `host64\OptiScaler.log` has
  `DLSS-NR create failed: ... create 0xBAD00001 (FAIL_FeatureNotSupported)` followed by `DLSS-NR did not run`,
  and the frame cost is a couple of milliseconds instead of ~20 ms. Before the game starts, the helper log has
  already said `feature 18 ... ADAPTER unsupported (min GPU architecture 0x1B0)`. Your `nvngx_dlssnr.dll` is
  NVIDIA's original build, which runs on RTX 50 only. On RTX 20/30/40 get the modified build (see
  [Requirements](#requirements)), put it in `Dependencies\` and run `Install.cmd`: it replaces the one in
  `host64\` and backs it up. When the neural pass runs, `OptiScaler.log` has `DLSS-NR cost: ... ms` lines.
  The helper's requirements line is a hint, not proof: on the tested RTX 4060 it reads `NotImplemented`, and the
  neural pass runs. `OptiScaler.log` is what decides.
- **`Check.cmd` says `nvngx_dlssnr.dll is NVIDIA's original build`.** Same cause, caught before installing:
  replace the file as above. To install anyway for DLAA only, run `Install.cmd -AllowDlaaOnly` from a command
  prompt in the package folder.
- **The game crashes on launch, and `crashes.txt` names `d3d8.dll` with fault offset `0x000a33cc`.** That is
  dgVoodoo 2.87.2, which Clarity 1.2.0-1.2.9 shipped. It crashes while the game creates its device on some
  RTX 50 PCs, notably with a second graphics adapter. Install 1.3.0 or newer, which ships dgVoodoo 2.87.5. On
  Phoenix this also stops the installer replacing Phoenix's own 2.87.5 with the older build.
- **The game crashes or closes on launch.** First run `Restore.cmd` if you need to play now: it puts your previous
  files back. Then, one at a time:
  1. Run `bootloader\host64\dlss5-feed-host64.exe --test`. Anything but `300/300 evaluates succeeded` points at
     the GPU, the driver or the two NVIDIA DLLs in `host64\`, not at the game.
  2. Look for leftovers from another graphics mod (DLSS 5 Manager, a standalone DLSS5-Feeder, Deep Fried
     Chicken, RenoDX): any `.addon32`, `.addon64` or `.asi` in `bootloader\` or `host64\` that is not in
     [What the installer changes](#what-the-installer-changes) belongs to something else. Move it out (keep it
     to switch back) and launch again. `installed-files.txt` in the `CollectLogs` zip lists every file with
     its product name.
  3. `crashes.txt` in the `CollectLogs` zip shows Windows' crash records. `Faulting module name` names the DLL
     that crashed; include it when you report the problem.
- **Retail: `pol.exe` closes right after "Play Online" / when FFXI starts** (`ntdll.dll`, `0xc0000005` in
  `crashes.txt`; `ReShade.log` ends with `Add-on "Reshade Effect Shader Toggler" was not unregistered!`).
  ReShade was running in the PlayOnline menus (a ReShade banner or the rainbow loading circle in the PlayOnline
  window) through a DirectDraw wrapper beside `pol.exe`. Move `DDraw.dll` and `D3DImm.dll` out of the PlayOnline
  folder; see [Retail](#retail-playonline--steam).
- **Retail: the game runs, but ReShade and the "DLSS 5 Feed host" window never appear in it.** `ReShade.log`
  shows the `FFXiClass` window but no swap chain after it. dgVoodoo's `d3d8.dll` is missing from the
  `FINAL FANTASY XI` folder (installed by 1.3.0 or older only beside `pol.exe`): run 1.3.1's `Install.cmd`.
- **Steam: `POL-1155` "Version Update Communication Error" with `R:FFXi.dll`.** Not caused by this mod: PlayOnline
  cannot replace `FFXi.dll` / `FFXiMain.dll` while updating (`*.tmp2` copies are left beside them). Steam's
  "Verify integrity of game files" puts back an older copy and does not help. Close PlayOnline, rename
  `FFXi.dll` and `FFXiMain.dll` in the `FINAL FANTASY XI` folder (for example to `.old`) and start again; the
  update then writes new ones.
- **`ReShade.log`: `error X3067: ambiguous function` in `vort_Motion.fx` / `vort_Defs.fxh`.** Two VORTs are on
  the effect search path: an older one in `reshade-shaders\` and Clarity's in `ffxi-clarity-shaders\`. Move the
  older `reshade-shaders\Shaders\vort_Motion.fx` and `Includes\vort_*.fxh` aside (1.3.1 no longer adds a second
  VORT on new installs).

- **Helper log: `WARNING: OptiScaler refused the feature-18 requirements query ... builds FSR 2.1.2 in place of
  DLSS`.** Expected with this stack, on every launch; the Feeder cannot see which upscaler ran and says so in
  the next lines. `host64\OptiScaler.log` can: `Creating DLSS upscaler feature`, `_CreateFeature result:
  NVSDK_NGX_Result_Success` and `DLSS v310.9.1 loaded` mean DLSS ran. `fsr` or `xess` there means
  `nvngx_dlss.dll` is missing from `host64\`.
- **Helper log: `neural consumer outcome: consumer did not intercept`.** Also expected: OptiScaler reaches the
  neural model through its own forwarder, where the Feeder's probe cannot see it. `OptiScaler.log` shows
  `DLSS-NR forwarder loaded`, `MULTIPASS: evaluated 1 passes successfully` and `DLSS-NR cost: ... ms`.
- **Helper log: `dxgi.dll here is Windows' own`.** 1.2.0 did this on fresh installs (see Changes). With 1.2.1's
  `winmm.dll` the helper log reads `dxgi.dll: ...\host64\dxgi.dll`, `OptiScaler.log` has `dxgi.dll loaded from
  the application folder`, and `host64\ReShade.log` exists. If not, report it with those three logs.
- **Depth looks wrong** (effects on the sky, or the `DLSS5_Feed_Debug` raw-depth view is inverted). `ReShade.ini`
  `PreprocessorDefinitions` must contain `RESHADE_DEPTH_INPUT_IS_REVERSED=0`; `DisplayDepth.fx` should show near
  objects dark. `host64\OptiScaler.ini` keeps `[InitFlags] DepthInverted = false`.
- **1.2.0 refused with `Existing shader differs or is incomplete` lines.** Fixed in 1.2.1; nothing to change.
- **1.2.1 refused with `Existing d3d8.dll differs from the tested stack`** (or `dxgi.dll`). Fixed in 1.2.2:
  another dgVoodoo / ReShade build is replaced (backed up). With 1.2.1, move that file out of `bootloader\`
  and run `Check.cmd` again; the installer then puts in the tested one.
- **Coming from Deep Fried Chicken.** Move `host64\deep-fried-chicken*.addon64` out of `host64\` (keep it to
  switch back) and run `Check.cmd`. Its dgVoodoo / ReShade files are replaced and backed up by `Install.cmd`.
- **Ctrl+F9 does nothing.** Click the game first (it is read by the game). `bootloader\dlss5-feed.log` shows
  `cast_key=` in its `config:` line; 0 means off. Re-run `Install.cmd` or set `cast_key=120` and `cast_mods=2`.
- **The OptiScaler menu does not open.** The key goes to the helper window, not the game: Alt+Tab to "DLSS 5
  Feed host" (or Ctrl+F9 in game) and press F6 or Insert. The title bar names the key.
- **Low fps right after login or zoning.** The first `600 frames:` line in `dlss5-feed.log` can read ~10 fps
  while the zone loads; check the next lines. Also check that FFXI's own background fps limit is not active
  while the game window lacks focus.
- **No neural effect after a hotkey.** Ctrl+Shift+F3 is the neural-off comparison key; Ctrl+Shift+F6 brings
  Cinematic back. Hotkey changes are not saved: the `OptiScaler.ini` values return at the next start.

## Reporting a problem

1. Run `CollectLogs.cmd` from the `FFXI-DLSS5-Clarity-<version>` folder, right after the problem and before
   launching again (the logs are rewritten on each start). It changes nothing and saves
   `FFXI-Clarity-support-<date>.zip` on your desktop: the logs and configs above, the list of files in
   `bootloader\` and `host64\` with versions, what `Check.cmd` prints, Windows/GPU/driver and recent crash
   records. Your Windows user name and PC name are replaced with `<user>` and `<pc>`. On Windower 4 it also
   saves Windower's `settings.xml` (found like `Install.cmd` does, or `CollectLogs.cmd -Windower "<folder>"`),
   with every launch argument value replaced by `<redacted>` except `--server` and `--port`, so a login
   in the arguments is not included.
2. [Open an issue](https://github.com/OpMoonRise2/FFXI-DLSS5-Clarity/issues/new/choose) and attach the zip.

Comments on videos and forum posts are hard to troubleshoot in: please use an issue so the logs stay together.

## Status

Unofficial community mod, not affiliated with Square Enix, NVIDIA or any server. Square Enix's terms for
its official servers prohibit third-party tools that modify the game client; check your server's rules
before using this. Personal-rig tested; other GPUs, drivers and loaders are unverified. Problems: see
[Reporting a problem](#reporting-a-problem).
