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
$n = Fixture 'no nvidia' -NoNvidia
$refused = $false; try { & $setup -Action Install -Target $n | Out-Null } catch { $refused = $true }
Assert ($refused -and !(Test-Path "$n\host64\winmm.dll")) 'missing NVIDIA DLLs: refused, no writes'

# 5. Lighting pack detection
$l = Fixture 'lighting'
New-Item -ItemType Directory "$l\reshade-shaders\Shaders\x" -Force | Out-Null
foreach ($s in 'lumenite_Kernel.fx','Zenteon_TurboGI.fx') { [IO.File]::WriteAllText("$l\reshade-shaders\Shaders\x\$s", '//') }
Assert (((& $setup -Action Check -Target $l) -join "`n") -match 'Optional lighting pack found') 'lighting pack detected on Check'

Remove-Item $root -Recurse -Force
'All installer tests passed.'
