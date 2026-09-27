<#
.SYNOPSIS
  Assembles the redistributable FFXI-DLSS5-Clarity release folder and zip.

.PARAMETER StackDir
  A working FFXI bootloader that holds the stock third-party files: d3d8.dll (dgVoodoo2),
  dxgi.dll (ReShade 32-bit add-on build), dlss5-feed.addon32, ReshadeEffectShaderToggler.*,
  host64\dxgi.dll (ReShade 64-bit), host64\dlss5-feed-host64.exe, and reshade-shaders\ with
  DLSS5_Feed.fx, ReShade.fxh, ReShadeUI.fxh and vort_Shaders.

.PARAMETER ForkBuildDir
  x64\Release of the OptiScaler_DLSSNR ffxi-clarity fork: OptiScaler.dll and a\nvngx.dll_dlssnr.dll.

  NVIDIA runtimes, LumeniteFX, Zenteon shaders, Display Commander and AdjustDepth are never copied:
  their licences do not allow it (see CREDITS.md).
#>
param(
    [Parameter(Mandatory)][string]$StackDir,
    [Parameter(Mandatory)][string]$ForkBuildDir,
    [string]$Version = '1.1.0',
    [string]$ForkCommit = ''
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$name = "FFXI-DLSS5-Clarity-$Version"
$out  = Join-Path $repo "dist\$name"
if (Test-Path -LiteralPath $out) { throw "$out already exists; bump -Version or delete it." }

function Hash($p) { $s=[IO.File]::OpenRead($p); $h=[Security.Cryptography.SHA256]::Create(); try { ([BitConverter]::ToString($h.ComputeHash($s))).Replace('-','') } finally { $s.Dispose(); $h.Dispose() } }
function Put($from, $rel) {
    if (!(Test-Path -LiteralPath $from)) { throw "Missing input: $from" }
    $to = Join-Path $out $rel; [void][IO.Directory]::CreateDirectory((Split-Path $to -Parent)); Copy-Item -LiteralPath $from -Destination $to
}

# Installer, docs, licences, presets
foreach ($f in 'Setup.ps1','Install.cmd','Check.cmd','Restore.cmd') { Put (Join-Path $repo "installer\$f") $f }
foreach ($f in 'README.md','CREDITS.md','LIGHTING-EXTRAS.md','LICENSE') { Put (Join-Path $repo $f) $f }
Get-ChildItem (Join-Path $repo 'licenses') -File | ForEach-Object { Put $_.FullName "licenses\$($_.Name)" }
Put (Join-Path $repo 'presets\FFXI-Clarity.ini') 'payload\FFXI-Clarity.ini'
Put (Join-Path $repo 'presets\Clarity-Lumenite-Strong.ini') 'payload\presets\Clarity-Lumenite-Strong.ini'

# Redistributable binaries
foreach ($f in 'd3d8.dll','dxgi.dll','dlss5-feed.addon32','ReshadeEffectShaderToggler.addon32','ReshadeEffectShaderToggler.ini','host64\dxgi.dll','host64\dlss5-feed-host64.exe') {
    Put (Join-Path $StackDir $f) "payload\$f"
}
Put (Join-Path $ForkBuildDir 'OptiScaler.dll') 'payload\host64\winmm.dll'
Put (Join-Path $ForkBuildDir 'a\nvngx.dll_dlssnr.dll') 'payload\host64\nvngx.dll_dlssnr.dll'

# Shaders: the feeder effect, ReShade headers (CC0) and VORT (MIT) only
$sh = Join-Path $StackDir 'reshade-shaders'
foreach ($f in 'DLSS5_Feed.fx','ReShade.fxh','ReShadeUI.fxh','vort_Shaders\vort_Motion.fx') { Put (Join-Path $sh "Shaders\$f") "payload\ffxi-clarity-shaders\Shaders\$f" }
Get-ChildItem (Join-Path $sh 'Shaders\vort_Shaders\Includes') -File | ForEach-Object { Put $_.FullName "payload\ffxi-clarity-shaders\Shaders\vort_Shaders\Includes\$($_.Name)" }
Get-ChildItem (Join-Path $sh 'Textures\vort_Shaders') -File | ForEach-Object { Put $_.FullName "payload\ffxi-clarity-shaders\Textures\vort_Shaders\$($_.Name)" }

[void][IO.Directory]::CreateDirectory((Join-Path $out 'Dependencies'))
[IO.File]::WriteAllText((Join-Path $out 'Dependencies\PUT-FILES-HERE.txt'),
  "Place nvngx_dlss.dll and nvngx_dlssnr.dll here (NVIDIA; not redistributable). See README.md.`r`n")

# Guard: nothing non-redistributable may slip in
$banned = 'nvngx_dlss.dll','nvngx_dlssnr.dll','lumenite_*','Zenteon*','zzz_display_commander*','*AdjustDepth*','DisplayCommander.ini'
foreach ($b in $banned) { if (Get-ChildItem $out -Recurse -File -Filter $b) { throw "Non-redistributable file in release: $b" } }

$hashes = @{}
Get-ChildItem $out -Recurse -File | ForEach-Object { $hashes[$_.FullName.Substring($out.Length + 1)] = Hash $_.FullName }
@{ Version = $Version; ForkCommit = $ForkCommit; Files = $hashes } | ConvertTo-Json -Depth 4 |
  Set-Content -LiteralPath (Join-Path $out 'manifest.json') -Encoding UTF8

Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = "$out.zip"; if (Test-Path $zip) { Remove-Item $zip }
[IO.Compression.ZipFile]::CreateFromDirectory($out, $zip, [IO.Compression.CompressionLevel]::Optimal, $true)
"Built $zip  ($([math]::Round((Get-Item $zip).Length / 1MB)) MB)  SHA256 $(Hash $zip)"
