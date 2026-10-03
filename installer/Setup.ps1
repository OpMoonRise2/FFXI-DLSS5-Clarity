[CmdletBinding()]
param([ValidateSet('Check','Install','Restore')][string]$Action='Check', [string]$Target, [string]$Backup, [ValidateRange(0,8192)][int]$DepthFilter=4096)
$ErrorActionPreference='Stop'
if ([string]::IsNullOrWhiteSpace($Target)) { $Target = [IO.Directory]::GetParent($PSScriptRoot).FullName }
function Hash([string]$p) { $s=[IO.File]::OpenRead($p); $h=[Security.Cryptography.SHA256]::Create(); try { ([BitConverter]::ToString($h.ComputeHash($s))).Replace('-','') } finally { $s.Dispose(); $h.Dispose() } }
function WriteText($p,$s) { [void][IO.Directory]::CreateDirectory((Split-Path $p -Parent)); [IO.File]::WriteAllText($p,$s,[Text.UTF8Encoding]::new($false)) }
function ReadText($p) { if(Test-Path -LiteralPath $p){[IO.File]::ReadAllText($p)}else{''} }
function IsX64($p) {
    $s=[IO.File]::OpenRead($p);$r=[IO.BinaryReader]::new($s)
    try {if($s.Length -lt 64 -or $r.ReadUInt16() -ne 0x5A4D){return $false};$s.Position=60;$offset=$r.ReadInt32();if($offset -lt 0 -or $offset+6 -gt $s.Length){return $false};$s.Position=$offset;return ($r.ReadUInt32() -eq 0x4550 -and $r.ReadUInt16() -eq 0x8664)} finally {$r.Dispose();$s.Dispose()}
}
function SetIni([string]$text,[string]$section,[string]$key,[string]$value) {
    $lines=[Collections.Generic.List[string]]::new(); $lines.AddRange([string[]]($text -split '\r?\n'))
    $start=-1; $end=$lines.Count
    for($i=0;$i -lt $lines.Count;$i++){if($lines[$i] -match ('^\s*\['+[regex]::Escape($section)+'\]\s*$')){$start=$i;break}}
    if($start -lt 0){$lines.Add('['+$section+']');$lines.Add($key+'='+$value);return ($lines -join "`r`n")}
    for($i=$start+1;$i -lt $lines.Count;$i++){if($lines[$i] -match '^\s*\['){$end=$i;break}}
    for($i=$start+1;$i -lt $end;$i++){if($lines[$i] -match ('^\s*'+[regex]::Escape($key)+'\s*=')){$lines[$i]=$key+'='+$value;return ($lines -join "`r`n")}}
    $lines.Insert($end,$key+'='+$value);return ($lines -join "`r`n")
}
function SafePath($base,$relative) {
    if([IO.Path]::IsPathRooted($relative)){throw 'Absolute path in package or receipt.'}
    $prefix=[IO.Path]::GetFullPath($base).TrimEnd('\')+'\';$p=[IO.Path]::GetFullPath((Join-Path $base $relative))
    if(!$p.StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)){throw 'Path escapes installation.'}
    $part=$p
    while($part -and $part.Length -ge $base.Length){if((Test-Path -LiteralPath $part) -and ((Get-Item -LiteralPath $part -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)){throw "Linked path is not supported: $part"};$part=Split-Path $part -Parent}
    return $p
}
$root=(Resolve-Path -LiteralPath $Target).Path
$manifest=Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot 'manifest.json') | ConvertFrom-Json
foreach($entry in $manifest.Files.PSObject.Properties){if((Hash (SafePath $PSScriptRoot $entry.Name)) -ne $entry.Value){throw "Package is damaged: $($entry.Name)"}}
if($Action -ne 'Check' -and @(Get-Process pol,xiloader,phoenix-loader,dlss5-feed-host64 -ErrorAction SilentlyContinue).Count){throw 'Close all FFXI / PlayOnline sessions and feeder hosts first.'}
if($Action -eq 'Restore'){
    if(!$Backup){throw 'Specify -Backup with the backup directory printed after installation.'}
    $receipt=Get-Content -Raw -LiteralPath (Join-Path $Backup 'receipt.json') | ConvertFrom-Json
    if($receipt.Target -ne $root){throw 'Backup belongs to another folder.'}
    foreach($e in $receipt.Files){$p=SafePath $root $e.Path;if(!(Test-Path -LiteralPath $p) -or (Hash $p) -ne $e.After){throw "Changed since installation; restore stopped without writes: $($e.Path)"};if($e.Before -and (Hash (SafePath $Backup $e.Path)) -ne $e.Before){throw 'Backup hash mismatch.'}}
    $retired=Join-Path $root ('FFXI-Clarity-removed-'+[guid]::NewGuid().ToString('N'))
    foreach($e in $receipt.Files){$p=SafePath $root $e.Path;if($e.Before){Copy-Item -LiteralPath (SafePath $Backup $e.Path) -Destination $p -Force}else{$dest=SafePath $retired $e.Path;[void][IO.Directory]::CreateDirectory((Split-Path $dest -Parent));Move-Item -LiteralPath $p -Destination $dest}}
    Write-Output "Restored original files. Newly added files were retained in $retired";return
}
if(!@(Get-ChildItem -LiteralPath $root -File -Filter '*.exe').Count){throw 'Choose the folder containing the FFXI loader/game executable, not the launcher download directory.'}
$problems=[Collections.Generic.List[string]]::new()
$reuseShaders=$false
$existingShaders=SafePath $root 'reshade-shaders\Shaders\DLSS5_Feed.fx'
if(Test-Path -LiteralPath $existingShaders){
    $reuseShaders=$true
    foreach($entry in $manifest.Files.PSObject.Properties){
        if($entry.Name.StartsWith('payload\ffxi-clarity-shaders\')){
            $rel=$entry.Name.Substring('payload\ffxi-clarity-shaders\'.Length)
            $old=SafePath $root ('reshade-shaders\'+$rel)
            if(!(Test-Path -LiteralPath $old) -or (Hash $old) -ne $entry.Value){$problems.Add("Existing shader differs or is incomplete: $rel")}
        }
    }
}
$runtime=@{}
# The neural forwarder ships in payload (GPL, the tested 2026-09-20 build; see tools\known-good.json); NVIDIA's two runtimes are user-supplied.
foreach($name in @('nvngx_dlss.dll','nvngx_dlssnr.dll')){
    $installed=SafePath $root ('host64\'+$name);$supplied=Join-Path $PSScriptRoot ('Dependencies\'+$name)
    if(Test-Path -LiteralPath $installed){$runtime[$name]=$installed}elseif(Test-Path -LiteralPath $supplied){$runtime[$name]=$supplied}else{$problems.Add("Supply Dependencies\$name (see START-HERE.txt)")}
    if($runtime.ContainsKey($name) -and !(IsX64 $runtime[$name])){$problems.Add("$name must be a valid x64 DLL.")}
}
$preserveWrappers=@{}
# Previously working Ashita control: dgVoodoo 4.8.2.134, D3D11 FL11.
# Match exact reviewed bytes, not just spoofable version metadata.
$knownD3d8=@('85284D3024D6AD7D4B4154CD96B97E0D64F28F6A0F7AD490E5BE70D626F62604')
foreach($pair in @(@('d3d8.dll','dgVoodoo'),@('dxgi.dll','ReShade'),@('host64\dxgi.dll','ReShade'))){
    $p=SafePath $root $pair[0]
    if(Test-Path -LiteralPath $p){
        $hash=Hash $p
        if($hash -eq $manifest.Files.('payload\'+$pair[0])){$preserveWrappers[$pair[0]]=$true}
        elseif($pair[0] -eq 'd3d8.dll' -and $hash -in $knownD3d8){$preserveWrappers[$pair[0]]=$true}
        else{$problems.Add("Existing $($pair[0]) differs from the tested stack. Automatic replacement refused; requires wrapper integration.")}
    }
}
$dg=ReadText (SafePath $root 'dgVoodoo.conf')
if($dg -and $dg -notmatch '(?im)^\s*OutputAPI\s*=\s*d3d11_fl11_0\s*$'){$problems.Add('Existing dgVoodoo.conf is not the tested D3D11 feature-level-11 path; configure it before installing.')}
$conflicts=@(Get-ChildItem -LiteralPath (Join-Path $root 'host64') -File -ErrorAction SilentlyContinue | Where-Object {$_.Name -match '^(renodx-dlss.*|deep-fried-chicken.*)\.addon64$'})
if($conflicts.Count){$problems.Add('Another neural consumer is active in host64. Disable it before using OptiScaler.')}
Write-Output "FFXI Clarity portable preflight: $root"
if($problems.Count){$problems | ForEach-Object {Write-Output "NEEDED: $_"};if($Action -eq 'Install'){throw 'No installation files changed.'};return}
Write-Output 'File prerequisites passed. GPU, driver and live rendering still require the host test and gameplay check.'
# Optional lighting pack: third-party shaders that may not be redistributed. Report, never fetch.
function ReportLightingPack {
    $roots=@('ffxi-clarity-shaders','reshade-shaders') | ForEach-Object {Join-Path $root $_} | Where-Object {Test-Path -LiteralPath $_}
    $has={param($n) foreach($d in $roots){if(Get-ChildItem -LiteralPath $d -Recurse -File -Filter $n -ErrorAction SilentlyContinue | Select-Object -First 1){return $true}}; return $false}
    $missing=@(); if(!(& $has 'lumenite_Kernel.fx')){$missing+='LumeniteFX'}; if(!(& $has 'Zenteon_TurboGI.fx')){$missing+='Zenteon TurboGI'}
    if($missing.Count){Write-Output "Optional lighting pack not installed ($($missing -join ', ')): presets\Clarity-Lumenite-Strong.ini needs it. See LIGHTING-EXTRAS.md."}
    else{Write-Output 'Optional lighting pack found: presets\Clarity-Lumenite-Strong.ini is ready.'}
}
if($Action -eq 'Check'){ReportLightingPack;return}
$changes=@{}
$payload=Join-Path $PSScriptRoot 'payload'
foreach($e in $manifest.Files.PSObject.Properties){if($e.Name.StartsWith('payload\')){if($reuseShaders -and $e.Name.StartsWith('payload\ffxi-clarity-shaders\')){continue};$rel=$e.Name.Substring(8);if($preserveWrappers.ContainsKey($rel)){continue};$dest=SafePath $root $rel;if(!(Test-Path -LiteralPath $dest) -or (Hash $dest) -ne $e.Value){$changes[$rel]=@{Source=(Join-Path $PSScriptRoot $e.Name)}}}}
foreach($n in $runtime.Keys){$rel='host64\'+$n;if(!(Test-Path -LiteralPath (SafePath $root $rel))){$changes[$rel]=@{Source=$runtime[$n]}}}
# Tested configuration (defaults\): used whole when the file is missing, never over an existing one.
$defaults=Join-Path $PSScriptRoot 'defaults'
$opti=ReadText (SafePath $root 'host64\OptiScaler.ini')
if(!$opti){$opti=ReadText (Join-Path $defaults 'OptiScaler.ini')}
$opti=SetIni $opti 'DLSS' 'ResetDlaaHistory' 'true';$opti=SetIni $opti 'DlssNr' 'Enabled' 'true'
$changes['host64\OptiScaler.ini']=@{Text=$opti}
# The helper writes a bare ReShade.ini (no [INPUT]) when it finds none; ship the tested one instead.
if(!(Test-Path -LiteralPath (SafePath $root 'host64\ReShade.ini'))){$changes['host64\ReShade.ini']=@{Text=(ReadText (Join-Path $defaults 'host64-ReShade.ini'))}}
# dlss5-feed.cfg: one key=value per line, CRLF-terminated, so a later hand edit or append cannot glue two keys.
# Forced keys are what the fixes need; every other tested key is added only if absent (host_window=1 keeps
# the helper window, where F6 opens OptiScaler, and Ctrl+F9 casts it into the game). The forced values are
# the 2026-10-02 played-on stack (Feeder 1.17.0): async home, work upscale and the 0.182 output hold.
$cfgLines=[Collections.Generic.List[string]]::new()
foreach($l in ((ReadText (SafePath $root 'dlss5-feed.cfg')) -split '\r?\n')){if($l.Trim()){$cfgLines.Add($l.Trim())}}
function CfgSet([string]$item,[bool]$force){$key=$item.Split('=')[0];for($i=0;$i -lt $cfgLines.Count;$i++){if($cfgLines[$i] -match ('^'+[regex]::Escape($key)+'=')){if($force){$cfgLines[$i]=$item};return}};$cfgLines.Add($item)}
foreach($item in @('enabled=1','mode=2','reset_every=0','async_home=1','hold_strength=0.182','mv_scale_x=1.000','mv_scale_y=1.000','work_resolution=100','work_upscale=1')){CfgSet $item $true}
foreach($l in ((ReadText (Join-Path $defaults 'dlss5-feed.cfg')) -split '\r?\n')){if($l.Trim()){CfgSet $l.Trim() $false}}
$changes['dlss5-feed.cfg']=@{Text=(($cfgLines -join "`r`n")+"`r`n")}
$rs=ReadText (SafePath $root 'ReShade.ini')
if($rs -and !$reuseShaders){
    # Keep existing presets intact. The user selects our separate preset for the first run.
    if($rs -match '(?im)^EffectSearchPaths=(.*)$'){$paths=$Matches[1].Trim()}else{$paths=''}
    if($paths -notlike '*ffxi-clarity-shaders*'){$rs=SetIni $rs 'GENERAL' 'EffectSearchPaths' ($paths+',.\ffxi-clarity-shaders\Shaders\**').Trim(',')}
    if($rs -match '(?im)^TextureSearchPaths=(.*)$'){$paths=$Matches[1].Trim()}else{$paths=''}
    if($paths -notlike '*ffxi-clarity-shaders*'){$rs=SetIni $rs 'GENERAL' 'TextureSearchPaths' ($paths+',.\ffxi-clarity-shaders\Textures\**').Trim(',')}
}elseif(!$rs){
    $rs="[GENERAL]`r`nEffectSearchPaths=.\ffxi-clarity-shaders\Shaders\**`r`nTextureSearchPaths=.\ffxi-clarity-shaders\Textures\**`r`nPresetPath=.\FFXI-Clarity.ini`r`nPreprocessorDefinitions=RESHADE_DEPTH_INPUT_IS_REVERSED=0,RESHADE_DEPTH_INPUT_IS_UPSIDE_DOWN=0,RESHADE_DEPTH_INPUT_IS_LOGARITHMIC=0,RESHADE_DEPTH_LINEARIZATION_FAR_PLANE=1000.0`r`n[INPUT]`r`nKeyOverlay=116,0,0,0`r`nKeyNextPreset=121,1,0,0`r`nKeyPreviousPreset=122,1,0,0`r`n[OVERLAY]`r`nAutoSavePreset=0`r`n[DEPTH]`r`nDepthCopyBeforeClears=0`r`n"
}
# Generic Depth: FFXI draws its 3D scene into a square buffer sized by the client's background
# resolution (registry 0003/0004). Lock the depth filter to it so the right buffer is picked on
# every launch. Applied when no filter exists yet, or when -DepthFilter is passed explicitly.
$depthIsFresh = $rs -notmatch '(?im)^FilterResolutionWidth='
if($DepthFilter -gt 0 -and ($depthIsFresh -or $PSBoundParameters.ContainsKey('DepthFilter'))){
    $rs=SetIni $rs 'DEPTH' 'FilterResolutionWidth' "$DepthFilter"
    $rs=SetIni $rs 'DEPTH' 'FilterResolutionHeight' "$DepthFilter"
    $rs=SetIni $rs 'DEPTH' 'UseAspectRatioHeuristics' '4'
}
$changes['ReShade.ini']=@{Text=$rs}
if(!$dg){$changes['dgVoodoo.conf']=@{Text="[General]`r`nOutputAPI=d3d11_fl11_0`r`nFullScreenMode=false`r`n[DirectX]`r`nResolution=unforced`r`ndgVoodooWatermark=false`r`n"}}
$backupDir=Join-Path $root ('FFXI-Clarity-backup-'+[guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($backupDir)
$records=[Collections.Generic.List[object]]::new()
foreach($rel in ($changes.Keys | Sort-Object)){$p=SafePath $root $rel;$before=$null;if(Test-Path -LiteralPath $p){$before=Hash $p;$saved=SafePath $backupDir $rel;[void][IO.Directory]::CreateDirectory((Split-Path $saved -Parent));Copy-Item -LiteralPath $p -Destination $saved};$records.Add([pscustomobject]@{Path=$rel;Before=$before;After=$null})}
try{
    foreach($r in $records){$p=SafePath $root $r.Path;$c=$changes[$r.Path];[void][IO.Directory]::CreateDirectory((Split-Path $p -Parent));if($c.ContainsKey('Source')){Copy-Item -LiteralPath $c.Source -Destination $p -Force;if((Hash $p) -ne (Hash $c.Source)){throw 'Copy verification failed.'}}else{WriteText $p $c.Text};$r.After=Hash $p}
}catch{
    $failure=$_
    $failedFiles=Join-Path $backupDir 'failed-install-files'
    foreach($r in $records){$p=SafePath $root $r.Path;if($r.Before){Copy-Item -LiteralPath (SafePath $backupDir $r.Path) -Destination $p -Force}elseif(Test-Path -LiteralPath $p){$dest=SafePath $failedFiles $r.Path;[void][IO.Directory]::CreateDirectory((Split-Path $dest -Parent));Move-Item -LiteralPath $p -Destination $dest}}
    throw $failure
}finally{@{Target=$root;Files=@($records.ToArray());Version=$manifest.Version} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $backupDir 'receipt.json') -Encoding UTF8}
Write-Output "Installed. Backup: $backupDir"
Write-Output 'Select FFXI-Clarity.ini in ReShade for the first check. Existing presets remain available. Run host64\dlss5-feed-host64.exe --test before launching FFXI.'
ReportLightingPack
