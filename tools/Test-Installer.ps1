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
$ini = Get-Content -Raw "$f\host64\OptiScaler.ini"
Assert ($ini -match 'ResetDlaaHistory=true' -and $ini -match 'Passes=1' -and $ini -match 'PassTaper=0.5') 'fresh: motion fix + pass defaults written'
$rs = Get-Content -Raw "$f\ReShade.ini"
Assert ($rs -match 'FilterResolutionWidth=4096' -and $rs -match 'UseAspectRatioHeuristics=4') 'fresh: depth filter written'
Assert ($rs -notmatch '[A-Z]:\\') 'fresh: ReShade.ini has no absolute paths'
Assert (($out -join "`n") -match 'Optional lighting pack not installed') 'fresh: missing lighting pack reported'
$bk = (Get-ChildItem $f -Directory -Filter 'FFXI-Clarity-backup-*').FullName
& $setup -Action Restore -Target $f -Backup $bk | Out-Null
Assert (!(Test-Path "$f\host64\winmm.dll")) 'fresh: restore removes added DLL'

# 2. Existing install keeps tuning, custom depth
$e = Fixture 'existing loader'
[IO.File]::WriteAllText("$e\host64\OptiScaler.ini", "[DlssNr]`r`nIntensity=1.234`r`n")
[IO.File]::WriteAllText("$e\ReShade.ini", "[GENERAL]`r`nPresetPath=.\mine.ini`r`n[DEPTH]`r`nFilterResolutionWidth=2048`r`nFilterResolutionHeight=2048`r`n")
& $setup -Action Install -Target $e | Out-Null
Assert ((Get-Content -Raw "$e\host64\OptiScaler.ini") -match 'Intensity=1.234') 'existing: tuning kept'
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
