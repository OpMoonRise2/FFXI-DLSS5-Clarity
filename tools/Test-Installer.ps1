# Filesystem tests for installer\Setup.ps1 against throwaway fake bootloaders. No game or GPU involved.
param([Parameter(Mandatory)][string]$Package, [Parameter(Mandatory)][string]$NvidiaDir)
$ErrorActionPreference = 'Stop'
$root = Join-Path ([IO.Path]::GetTempPath()) ('ffxi-clarity-test-' + [guid]::NewGuid().ToString('N'))
function Assert($c, $m) { if (!$c) { throw "FAIL: $m" }; "PASS: $m" }
function Hash($p) { (Get-FileHash -LiteralPath $p).Hash }
function Get-Process { param($Name, $ErrorAction) @() }   # fixtures only: ignore any running game
function Fixture($n, [switch]$NoNvidia) {
    $p = Join-Path $root $n; New-Item -ItemType Directory (Join-Path $p 'host64') -Force | Out-Null
    [IO.File]::WriteAllText((Join-Path $p 'fixture.exe'), 'not a real exe')
    if (!$NoNvidia) { foreach ($d in 'nvngx_dlss.dll','nvngx_dlssnr.dll') { Copy-Item (Join-Path $NvidiaDir $d) (Join-Path $p "host64\$d") } }
    $p
}
$setup = Join-Path $Package 'Setup.ps1'

# 1. Fresh install
$f = Fixture 'fresh loader'
$out = & $setup -Action Install -Target $f
Assert (Test-Path "$f\host64\winmm.dll") 'fresh: patched DLL installed'
Assert (Test-Path "$f\host64\nvngx.dll_dlssnr.dll") 'fresh: forwarder installed from payload'
Assert (Test-Path "$f\ReshadeEffectShaderToggler.addon32") 'fresh: shader toggler installed'
Assert (Test-Path "$f\presets\Clarity-Lumenite-Strong.ini") 'fresh: lighting preset installed'
Assert ((Get-Content -Raw "$f\presets\Clarity-Lumenite-QuantMotion.ini") -match 'DLSS5_MV_PROVIDER=4') 'fresh: QuantMotion preset installed (motion provider 4)'
$ini = Get-Content -Raw "$f\host64\OptiScaler.ini"
Assert ($ini -match 'ResetDlaaHistory=true' -and $ini -match '(?m)^\[DlssNr\]') 'fresh: motion fix + neural section written'
Assert ($ini -match '(?m)^\s*ShortcutKey\s*=\s*0x75' -and $ini.Length -gt 10000) 'fresh: full tested OptiScaler.ini installed (F6 menu key)'
Assert ((Get-Content -Raw "$f\host64\ReShade.ini") -match '(?m)^KeyOverlay=36,') 'fresh: helper ReShade.ini installed with [INPUT]'
$cfg = Get-Content -Raw "$f\dlss5-feed.cfg"
Assert ($cfg -notmatch '(\r?\n){2}' -and !$cfg.StartsWith("`r`n") -and $cfg.EndsWith("`r`n")) 'fresh: cfg has no blank lines and ends with a newline'
Assert ($cfg -match '(?m)^work_sharpness=0.49\r?$' -and $cfg -match '(?m)^hold_tolerance=0.040\r?$') 'fresh: tested cfg keys written'
Assert ($cfg -match '(?m)^async_home=1\r?$' -and $cfg -match '(?m)^hold_strength=0.182\r?$' -and $cfg -match '(?m)^work_upscale=1\r?$') 'fresh: forced 1.17.0 stack keys written'
$rs = Get-Content -Raw "$f\ReShade.ini"
Assert ($rs -match 'FilterResolutionWidth=4096' -and $rs -match 'UseAspectRatioHeuristics=4') 'fresh: depth filter written'
Assert ($rs -notmatch '[A-Z]:\\') 'fresh: ReShade.ini has no absolute paths'
Assert (($out -join "`n") -match 'Optional lighting pack not installed') 'fresh: missing lighting pack reported'
Assert ((Get-Content -Raw "$f\dlss5-feed.cfg") -match '(?m)^host_window=1') 'fresh: helper window visible (host_window=1)'
$bk = (Get-ChildItem $f -Directory -Filter 'FFXI-Clarity-backup-*').FullName
& $setup -Action Restore -Target $f -Backup $bk | Out-Null
Assert (!(Test-Path "$f\host64\winmm.dll")) 'fresh: restore removes added DLL'

# 2. Existing install keeps tuning, custom depth
$e = Fixture 'existing loader'
[IO.File]::WriteAllText("$e\host64\OptiScaler.ini", "[DlssNr]`r`nIntensity=1.234`r`n")
[IO.File]::WriteAllText("$e\ReShade.ini", "[GENERAL]`r`nPresetPath=.\mine.ini`r`n[DEPTH]`r`nFilterResolutionWidth=2048`r`nFilterResolutionHeight=2048`r`n")
& $setup -Action Install -Target $e | Out-Null
Assert ((Get-Content -Raw "$e\host64\OptiScaler.ini") -match 'Intensity=1.234') 'existing: tuning kept'
Assert (!(Test-Path "$e\FFXI-Clarity-backup-*\host64\ReShade.ini")) 'existing: no host ReShade.ini existed, none backed up'

# 2b. 1.1.0 regression: a cfg with no trailing newline must not glue keys together
$g = Fixture 'glued cfg'
[IO.File]::WriteAllText("$g\dlss5-feed.cfg", "enabled=1`r`nwork_upscale=0host_window=1`r`nwork_sharpness=0.40")
[IO.File]::WriteAllText("$g\host64\ReShade.ini", "[INPUT]`r`nKeyOverlay=35,0,0,0`r`n")
& $setup -Action Install -Target $g | Out-Null
$cfg = Get-Content -Raw "$g\dlss5-feed.cfg"
Assert ($cfg -match '(?m)^work_upscale=1\r?$' -and $cfg -match '(?m)^host_window=1\r?$' -and $cfg -notmatch '0host_window') 'glued cfg: every key on its own line'
Assert ($cfg -match '(?m)^work_sharpness=0.40\r?$' -and $cfg.EndsWith("`r`n")) 'glued cfg: user value kept, newline-terminated'
Assert ($cfg -match '(?m)^cast_key=120\r?$' -and $cfg -match '(?m)^cast_mods=2\r?$') 'glued cfg: Ctrl+F9 cast key added when missing'

# 2c. cast_key=0 (Ctrl+F9 switched off) is re-bound; a user's own key is kept
$k = Fixture 'cast off'
[IO.File]::WriteAllText("$k\dlss5-feed.cfg", "cast_key=0`r`ncast_mods=0`r`n")
& $setup -Action Install -Target $k | Out-Null
$cfg = Get-Content -Raw "$k\dlss5-feed.cfg"
Assert ($cfg -match '(?m)^cast_key=120\r?$' -and $cfg -match '(?m)^cast_mods=2\r?$') 'cast_key=0: re-bound to Ctrl+F9'
$k2 = Fixture 'cast custom'
[IO.File]::WriteAllText("$k2\dlss5-feed.cfg", "cast_key=119`r`ncast_mods=4`r`n")
& $setup -Action Install -Target $k2 | Out-Null
$cfg = Get-Content -Raw "$k2\dlss5-feed.cfg"
Assert ($cfg -match '(?m)^cast_key=119\r?$' -and $cfg -match '(?m)^cast_mods=4\r?$') 'custom cast key kept'
Assert ((Get-Content -Raw "$g\host64\ReShade.ini") -match 'KeyOverlay=35') 'existing helper ReShade.ini kept'
$rs = Get-Content -Raw "$e\ReShade.ini"
Assert ($rs -match 'PresetPath=.\\mine.ini' -and $rs -match 'FilterResolutionWidth=2048') 'existing: preset and user depth filter kept'

# 3. Explicit -DepthFilter overrides
$d = Fixture 'depth loader'
[IO.File]::WriteAllText("$d\ReShade.ini", "[DEPTH]`r`nFilterResolutionWidth=4096`r`n")
& $setup -Action Install -Target $d -DepthFilter 2048 | Out-Null
Assert ((Get-Content -Raw "$d\ReShade.ini") -match 'FilterResolutionWidth=2048') 'explicit -DepthFilter applied'

# 4. Unknown wrapper refused, missing NVIDIA refused, nothing written
$u = Fixture 'unknown wrapper'; [IO.File]::WriteAllText("$u\d3d8.dll", 'x')
$refused = $false; try { & $setup -Action Install -Target $u | Out-Null } catch { $refused = $true }
Assert ($refused -and !(Test-Path "$u\host64\winmm.dll")) 'unknown wrapper: refused, no writes'
Assert (((& $setup -Action Check -Target $u) -join "`n") -match 'NEEDED: Existing d3d8.dll is not dgVoodoo.*Move it out') 'unknown wrapper: Check says to move it aside'

# 4b. Another dgVoodoo / ReShade build (a launcher's, Deep Fried Chicken's): replaced with a backup, Restore undoes it.
#     1.2.1 refused these with "differs from the tested stack". Same version resource, different bytes.
$w = Fixture 'other wrapper builds'
foreach ($rel in 'd3d8.dll','dxgi.dll','host64\dxgi.dll') {
    $b = [IO.File]::ReadAllBytes((Join-Path $Package "payload\$rel")); [IO.File]::WriteAllBytes("$w\$rel", $b + [byte[]](1,2,3))
}
$before = Hash "$w\d3d8.dll"
$chk = (& $setup -Action Check -Target $w) -join "`n"
Assert ($chk -notmatch 'NEEDED' -and $chk -match 'd3d8.dll is dgVoodoo .*Install replaces it' -and $chk -match 'host64\\dxgi.dll is ReShade .*Install replaces it') 'other builds: preflight passes and announces the replacements'
& $setup -Action Install -Target $w | Out-Null
Assert ((Hash "$w\d3d8.dll") -eq (Hash (Join-Path $Package 'payload\d3d8.dll')) -and (Hash "$w\host64\dxgi.dll") -eq (Hash (Join-Path $Package 'payload\host64\dxgi.dll'))) 'other builds: tested wrappers installed'
$bk = (Get-ChildItem $w -Directory -Filter 'FFXI-Clarity-backup-*').FullName
Assert ((Hash "$bk\d3d8.dll") -eq $before) 'other builds: original d3d8.dll backed up'
& $setup -Action Restore -Target $w -Backup $bk | Out-Null
Assert ((Hash "$w\d3d8.dll") -eq $before) 'other builds: restore put the original d3d8.dll back'
$n = Fixture 'no nvidia' -NoNvidia
$refused = $false; try { & $setup -Action Install -Target $n | Out-Null } catch { $refused = $true }
Assert ($refused -and !(Test-Path "$n\host64\winmm.dll")) 'missing NVIDIA DLLs: refused, no writes'

# 5. Lighting pack detection
$l = Fixture 'lighting'
New-Item -ItemType Directory "$l\reshade-shaders\Shaders\x" -Force | Out-Null
foreach ($s in 'lumenite_Kernel.fx','Zenteon_TurboGI.fx') { [IO.File]::WriteAllText("$l\reshade-shaders\Shaders\x\$s", '//') }
Assert (((& $setup -Action Check -Target $l) -join "`n") -match 'Optional lighting pack found') 'lighting pack detected on Check'

# 6. Compatible existing setup (the played-on layout): the active preset's effects live in reshade-shaders\
#    with this release's DLSS5_Feed.fx and LumeniteFX, VORT is absent there, and a stale 1.1.x copy of the
#    feeder effect sits in ffxi-clarity-shaders\. 1.2.0 refused this with 21 "differs or is incomplete" lines.
$feedFx = Join-Path $Package 'payload\ffxi-clarity-shaders\Shaders\DLSS5_Feed.fx'
$c = Fixture 'compatible existing'
New-Item -ItemType Directory "$c\reshade-shaders\Shaders","$c\reshade-shaders\Textures","$c\ffxi-clarity-shaders\Shaders" -Force | Out-Null
Copy-Item $feedFx "$c\reshade-shaders\Shaders\DLSS5_Feed.fx"
Copy-Item (Join-Path $Package 'payload\ffxi-clarity-shaders\Shaders\ReShade.fxh') "$c\reshade-shaders\Shaders\ReShade.fxh"
[IO.File]::WriteAllText("$c\reshade-shaders\Shaders\lumenite_Kernel.fx", '//')
[IO.File]::WriteAllText("$c\ffxi-clarity-shaders\Shaders\DLSS5_Feed.fx", '// stale 1.1.x feeder effect')
[IO.File]::WriteAllText("$c\ReShade.ini", "[GENERAL]`r`nEffectSearchPaths=.\reshade-shaders\Shaders\**`r`nTextureSearchPaths=.\reshade-shaders\Textures\**`r`nPreprocessorDefinitions=DLSS5_MV_PROVIDER=3`r`nPresetPath=.\ReshadePreset.ini`r`n[DEPTH]`r`nFilterResolutionWidth=4096`r`nFilterResolutionHeight=4096`r`nUseAspectRatioHeuristics=4`r`n")
$chk = (& $setup -Action Check -Target $c) -join "`n"
Assert ($chk -notmatch 'NEEDED' -and $chk -match 'stays the effect root' -and $chk -match 'no depth orientation') 'compatible: preflight passes, reports the kept effect root and the depth orientation'
& $setup -Action Install -Target $c | Out-Null
Assert ((Hash "$c\reshade-shaders\Shaders\DLSS5_Feed.fx") -eq (Hash $feedFx)) 'compatible: matching feeder effect in reshade-shaders left as is'
Assert ((Hash "$c\ffxi-clarity-shaders\Shaders\DLSS5_Feed.fx") -eq (Hash $feedFx)) 'compatible: stale ffxi-clarity-shaders copy refreshed'
Assert (Test-Path "$c\ffxi-clarity-shaders\Shaders\vort_Shaders\vort_Motion.fx") 'compatible: VORT installed into ffxi-clarity-shaders'
$rs = Get-Content -Raw "$c\ReShade.ini"
Assert ($rs.Contains('EffectSearchPaths=.\reshade-shaders\Shaders\**,.\ffxi-clarity-shaders\Shaders\vort_Shaders\**')) 'compatible: only the VORT path added to the effect search path (no second DLSS5_Feed.fx)'
Assert ($rs.Contains('TextureSearchPaths=.\reshade-shaders\Textures\**,.\ffxi-clarity-shaders\Textures\**')) 'compatible: texture path added'
Assert ($rs.Contains('PreprocessorDefinitions=DLSS5_MV_PROVIDER=3,RESHADE_DEPTH_INPUT_IS_REVERSED=0,RESHADE_DEPTH_INPUT_IS_UPSIDE_DOWN=0,RESHADE_DEPTH_INPUT_IS_LOGARITHMIC=0')) 'compatible: depth orientation added after the user''s definitions'
Assert ($rs -match 'PresetPath=.\\ReshadePreset.ini' -and $rs -match 'FilterResolutionWidth=4096') 'compatible: preset and depth filter kept'
Assert (Test-Path "$c\host64\winmm.dll") 'compatible: patched DLL installed'

# 7. Feeder effect from another release in reshade-shaders\: replaced with a backup, and Restore brings it back
$s = Fixture 'stale feeder effect'
New-Item -ItemType Directory "$s\reshade-shaders\Shaders" -Force | Out-Null
[IO.File]::WriteAllText("$s\reshade-shaders\Shaders\DLSS5_Feed.fx", '// 1.1.x feeder effect')
$chk = (& $setup -Action Check -Target $s) -join "`n"
Assert ($chk -match 'from another Feeder release: Install replaces it') 'stale feeder: preflight announces the replacement'
& $setup -Action Install -Target $s | Out-Null
Assert ((Hash "$s\reshade-shaders\Shaders\DLSS5_Feed.fx") -eq (Hash $feedFx)) 'stale feeder: replaced with the shipped effect'
$bk = (Get-ChildItem $s -Directory -Filter 'FFXI-Clarity-backup-*').FullName
Assert ((Get-Content -Raw "$bk\reshade-shaders\Shaders\DLSS5_Feed.fx") -eq '// 1.1.x feeder effect') 'stale feeder: original backed up'
& $setup -Action Restore -Target $s -Backup $bk | Out-Null
Assert ((Get-Content -Raw "$s\reshade-shaders\Shaders\DLSS5_Feed.fx") -eq '// 1.1.x feeder effect') 'stale feeder: restore put the original back'
Assert (!(Test-Path "$s\host64\winmm.dll")) 'stale feeder: restore removed the added DLL'

# 8. An explicit depth orientation (either value) is the user's decision and stays
$o = Fixture 'explicit depth'
[IO.File]::WriteAllText("$o\ReShade.ini", "[GENERAL]`r`nPreprocessorDefinitions=RESHADE_DEPTH_INPUT_IS_REVERSED=1`r`n")
& $setup -Action Install -Target $o | Out-Null
Assert ((Get-Content -Raw "$o\ReShade.ini") -match '(?m)^PreprocessorDefinitions=RESHADE_DEPTH_INPUT_IS_REVERSED=1\r?$') 'explicit depth orientation kept'

# 9. A D3D12 text dgVoodoo.conf is switched to D3D11 FL11 (backed up); a binary one and another neural consumer
#    still refuse with no writes, naming what to do.
$x = Fixture 'd3d12 dgvoodoo'; [IO.File]::WriteAllText("$x\dgVoodoo.conf", "[General]`r`nOutputAPI                            = d3d12_fl11_0`r`nFullScreenMode = false`r`n")
Assert (((& $setup -Action Check -Target $x) -join "`n") -match 'Install sets OutputAPI = d3d11_fl11_0') 'D3D12 dgVoodoo.conf: preflight announces the fix'
& $setup -Action Install -Target $x | Out-Null
$dgc = Get-Content -Raw "$x\dgVoodoo.conf"
Assert ($dgc -match '(?m)^OutputAPI\s*= d3d11_fl11_0\r?$' -and $dgc -match 'FullScreenMode = false' -and (Test-Path "$x\host64\winmm.dll")) 'D3D12 dgVoodoo.conf: set to D3D11 FL11, other keys kept, installed'
Assert ((Get-Content -Raw "$x\FFXI-Clarity-backup-*\dgVoodoo.conf") -match 'd3d12_fl11_0') 'D3D12 dgVoodoo.conf: original backed up'
$xb = Fixture 'binary dgvoodoo'; [IO.File]::WriteAllBytes("$xb\dgVoodoo.conf", [byte[]](0x44,0x47,0x56,0,1,0,0,0))
$refused = $false; try { & $setup -Action Install -Target $xb | Out-Null } catch { $refused = $true }
Assert ($refused -and !(Test-Path "$xb\host64\winmm.dll") -and !(Get-ChildItem $xb -Directory -Filter 'FFXI-Clarity-backup-*')) 'binary dgVoodoo.conf: refused, no writes'
$y = Fixture 'neural consumer'; [IO.File]::WriteAllText("$y\host64\deep-fried-chicken.addon64", 'x')
$refused = $false; try { & $setup -Action Install -Target $y | Out-Null } catch { $refused = $true }
Assert ($refused -and !(Test-Path "$y\host64\winmm.dll")) 'other neural consumer in host64: refused, no writes'
Assert (((& $setup -Action Check -Target $y) -join "`n") -match 'host64\\deep-fried-chicken.addon64 is another neural consumer.*Move it out of host64') 'other neural consumer: Check names the file to move'

Remove-Item $root -Recurse -Force
'All installer tests passed.'
