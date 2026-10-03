# Credits and licences

This project is glue and a small patch on top of other people's work. Thank you all.

## Included in the release zip

| Component | Author | Licence | Link |
|---|---|---|---|
| OptiScaler (base of the patched `host64\winmm.dll`) | cdozdil and OptiScaler contributors | GPL-3.0 | https://github.com/optiscaler/OptiScaler |
| OptiScaler DLSS-NR fork (neural rendering pass, `nvngx.dll_dlssnr.dll` forwarder) | Dagherbou | GPL-3.0 | https://github.com/Dagherbou/OptiScaler_DLSSNR |
| FFXI changes to the above (motion fix, multipass, taper, hotkeys) | OpMoonRise2 | GPL-3.0 | https://github.com/OpMoonRise2/OptiScaler_DLSSNR/tree/ffxi-clarity |
| Colour composition used by the DLSS-NR pass | clshortfuse (RenoDX) | MIT | https://github.com/clshortfuse/renodx |
| DLSS5-Feeder (`dlss5-feed.addon32`, `host64\dlss5-feed-host64.exe`, `DLSS5_Feed.fx`) | jlrouzies-fr | MIT | https://github.com/jlrouzies-fr/DLSS5-Feeder |
| ↳ built into the Feeder binaries: dlss5-bridge | NIGos | MIT | named in the Feeder licence |
| ↳ built into the Feeder binaries: MinHook | Tsuda Kageyu | BSD-2-Clause | https://github.com/TsudaKageyu/minhook |
| ↳ built into the Feeder binaries: Dear ImGui | Omar Cornut | MIT | https://github.com/ocornut/imgui |
| ReShade 6.8 (`dxgi.dll` 32-bit and `host64\dxgi.dll` 64-bit add-on builds) | crosire | BSD-3-Clause | https://github.com/crosire/reshade |
| `ReShade.fxh` shader header | crosire | CC0-1.0 (stated in the file) | https://github.com/crosire/reshade-shaders |
| VORT motion vectors (`vort_Motion.fx` and its includes) | Vortigern | MIT | https://github.com/vortigern11/vort_Shaders |
| ↳ ACES colour code in `vort_ACES.fxh` | A.M.P.A.S. | ACES licence (kept in the file) | https://github.com/ampas/aces-dev |
| Reshade Effect Shader Toggler | 4lex4nder, Frans Bouma | MIT | https://github.com/4lex4nder/ReshadeEffectShaderToggler |
| dgVoodoo2 (`d3d8.dll`) | Dege | freeware; its readme allows shipping "your game or game mod with individual dgVoodoo files included" | https://dege.freeweb.hu/dgVoodoo2/ |

Licence texts are in `licenses\` and in every release zip. The patched DLL's complete corresponding source is
the fork linked above; the shipped build comes from its tag `v1.1.0-ffxi`.

dgVoodoo's readme also says it may not be bundled "inside launchers or frameworks, for general use across
multiple applications". This package is a mod for one game, FFXI, and ships dgVoodoo only for FFXI.

## Not included (you download these yourself)

| Component | Author | Why not bundled | Link |
|---|---|---|---|
| `nvngx_dlss.dll`, `nvngx_dlssnr.dll` | NVIDIA | NVIDIA licence | see README |
| LumeniteFX | Umar Afzaal | AGNYA licence, official links only | https://github.com/umar-afzaal/LumeniteFX |
| Zenteon TurboGI | Daniel Oren-Ibarra (Zenteon) | All rights reserved | https://patreon.com/Zenteon |
| Display Commander (optional FPS cap/window mode) | pmnoxx | GPL-3.0, link instead | https://github.com/pmnoxx/display-commander |
| AdjustDepth add-on (optional) | seri14 | no licence published | - |

The presets in `presets\` only name these shaders and set their options; they contain no shader code.

## This repository

Installer scripts, tools, presets and documentation: MIT (see `LICENSE`). One exception:
`defaults/OptiScaler.ini` is OptiScaler's configuration file with tuned values and stays GPL-3.0
(`licenses/OptiScaler-GPL.txt`). Built with help from Claude (Anthropic).
