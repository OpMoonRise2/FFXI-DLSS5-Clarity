# Credits and licences

This project is glue and a small patch on top of other people's work. Thank you all.

## Included in the release

| Component | Author | Licence | Link |
|---|---|---|---|
| OptiScaler (base of the patched `winmm.dll`) | cdozdil and OptiScaler contributors | GPL-3.0 | https://github.com/optiscaler/OptiScaler |
| OptiScaler DLSS-NR fork (neural rendering pass, forwarder) | Dagherbou | GPL-3.0 | https://github.com/Dagherbou/OptiScaler_DLSSNR |
| FFXI changes to the above (motion fix, multipass, taper, hotkeys) | OpMoonRise2 | GPL-3.0 | https://github.com/OpMoonRise2/OptiScaler_DLSSNR/tree/ffxi-clarity |
| Colour composition used by the DLSS-NR pass | clshortfuse (RenoDX) | MIT | https://github.com/clshortfuse/renodx |
| DLSS5-Feeder (add-on, 64-bit helper, `DLSS5_Feed.fx`) | jlrouzies-fr | MIT | https://github.com/jlrouzies-fr/DLSS5-Feeder |
| ReShade 6.8 (32/64-bit add-on builds, `.fxh` headers) | crosire | BSD-3 (headers CC0) | https://github.com/crosire/reshade |
| VORT motion vectors (`vort_Motion.fx`) | Vortigern | MIT (in file headers) | https://github.com/vortigern11/vort_Shaders |
| Reshade Effect Shader Toggler | 4lex4nder, Frans Bouma | MIT | https://github.com/4lex4nder/ReshadeEffectShaderToggler |
| dgVoodoo2 (`d3d8.dll`) | Dege | freeware, shipped with a game mod as its readme permits | https://dege.freeweb.hu/dgVoodoo2/ |

Full texts are in `licenses\`. The patched DLL's complete corresponding source is the fork linked above.

## Not included (you download these yourself)

| Component | Author | Why not bundled | Link |
|---|---|---|---|
| `nvngx_dlss.dll`, `nvngx_dlssnr.dll` | NVIDIA | NVIDIA licence | see README |
| LumeniteFX | Umar Afzaal | AGNYA licence, official links only | https://github.com/umar-afzaal/LumeniteFX |
| Zenteon TurboGI | Daniel Oren-Ibarra (Zenteon) | All rights reserved | https://patreon.com/Zenteon |
| Display Commander (optional FPS cap/window mode) | pmnoxx | GPL-3.0, link instead | https://github.com/pmnoxx/display-commander |
| AdjustDepth add-on (optional) | seri14 | no licence published | - |

## This repository

Installer scripts, presets and documentation: MIT (see `LICENSE`). Built with help from Claude (Anthropic).
