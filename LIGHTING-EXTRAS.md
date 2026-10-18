# Optional lighting pack (Clarity-Lumenite presets)

The lighting presets use shader packs whose licences do not allow re-hosting.
Get them from their authors, then drop them in:

1. **LumeniteFX** by Umar Afzaal: https://github.com/umar-afzaal/LumeniteFX
   Copy `lumenite_Kernel.fx`, `lumenite_RTAO.fx`, `lumenite_SSSR.fx`, `lumenite_AnamorphicBloom.fx`
   (and for the QuantMotion preset also `lumenite_QuantMotion.fx`, `lumenite_LSAO.fx`, `lumenite_QuantAO.fx`,
   `lumenite_TRAA.fx`) and its `include\` folder into `bootloader\ffxi-clarity-shaders\Shaders\LumeniteFX\`,
   and `lumenite_bluenoise256.png` into `bootloader\ffxi-clarity-shaders\Textures\`.
2. **Zenteon TurboGI** by Zenteon: https://patreon.com/Zenteon
   Copy `Zenteon_TurboGI.fx` and `ZenteonCommon.fxh` into `bootloader\ffxi-clarity-shaders\Shaders\ZenteonFX\`,
   and `ZenteonBN.png` into `bootloader\ffxi-clarity-shaders\Textures\ZenteonFX\`.

(If your install already uses `bootloader\reshade-shaders\`, use that folder instead.)

Then in ReShade (F5): Reload, and select `presets\Clarity-Lumenite-Strong.ini` (LumeniteFX + TurboGI)
or `presets\Clarity-Lumenite-QuantMotion.ini` (LumeniteFX only; the current played-on look).
Re-running `Check.cmd` reports whether both packs are found.

Effect order matters: the motion effect (VORT, or Lumenite QuantMotion), then DLSS5 Feed, then the lighting
effects. Both presets already set it.

In the QuantMotion preset, Lumenite TRAA and SSSR read the flow, normal and depth textures that only
`lumenite_Kernel.fx` writes, and `Lumenite_Kernel` is off there (that is the look that was played). Turn it on,
above DLSS 5 Feed, if you want TRAA's reprojection and SSSR fed with real guides; it costs GPU time.
