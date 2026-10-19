[CmdletBinding()]
param([string]$Target, [string]$OutDir)
# Gathers everything a problem report needs into one zip: logs, configs, the wrapper files present (with hashes
# and versions), Check output, GPU/driver and recent crash records. Reads only; never changes the install.
# The Windows user name is replaced with <user> in every text file so paths do not identify the reporter.
$ErrorActionPreference='Stop'
if ([string]::IsNullOrWhiteSpace($Target)) { $Target = [IO.Directory]::GetParent($PSScriptRoot).FullName }
if ([string]::IsNullOrWhiteSpace($OutDir)) { $OutDir = [Environment]::GetFolderPath('Desktop') }
$root=(Resolve-Path -LiteralPath $Target).Path
$stamp=Get-Date -Format 'yyyyMMdd-HHmmss'
$work=Join-Path ([IO.Path]::GetTempPath()) "FFXI-Clarity-support-$stamp"
[void][IO.Directory]::CreateDirectory($work)
function Scrub([string]$s) { if($env:USERNAME){$s=[regex]::Replace($s,'(?<=[\\/])'+[regex]::Escape($env:USERNAME)+'(?=[\\/])','<user>','IgnoreCase')}; $s }
function Save($name,$text) { [IO.File]::WriteAllText((Join-Path $work $name),(Scrub ($text | Out-String)),[Text.UTF8Encoding]::new($false)) }
# Not Get-FileHash: it is missing from some Windows PowerShell sessions (same helper as Setup.ps1)
function Hash($p) { try{$s=[IO.File]::OpenRead($p);$h=[Security.Cryptography.SHA256]::Create();try{([BitConverter]::ToString($h.ComputeHash($s))).Replace('-','')}finally{$s.Dispose();$h.Dispose()}}catch{'unreadable'} }

# Logs and configs, kept in their bootloader-relative place
$files='dlss5-feed.log','dlss5-feed.cfg','ReShade.log','ReShade.log1','ReShade.ini','dgVoodoo.conf','ReshadeEffectShaderToggler.ini',
       'host64\dlss5-feed-host.log','host64\OptiScaler.log','host64\OptiScaler.ini','host64\ReShade.log','host64\ReShade.ini'
$missing=[Collections.Generic.List[string]]::new()
foreach($rel in $files){
    $p=Join-Path $root $rel
    if(!(Test-Path -LiteralPath $p)){$missing.Add($rel);continue}
    $dest=Join-Path $work ('files\'+$rel);[void][IO.Directory]::CreateDirectory((Split-Path $dest -Parent))
    # A binary dgVoodoo.conf is copied as is; text is scrubbed
    try{$bytes=[IO.File]::ReadAllBytes($p);if([Array]::IndexOf($bytes,[byte]0) -ge 0){[IO.File]::WriteAllBytes($dest,$bytes)}else{[IO.File]::WriteAllText($dest,(Scrub ([IO.File]::ReadAllText($p))),[Text.UTF8Encoding]::new($false))}}catch{$missing.Add("$rel (unreadable: $($_.Exception.Message))")}
}

# What is installed: every file in bootloader\ and host64\ with size, date, version and hash. Another mod's
# wrapper or neural consumer shows up here even when no log mentions it.
$listing=foreach($dir in @($root,(Join-Path $root 'host64'))){
    if(!(Test-Path -LiteralPath $dir)){continue}
    Get-ChildItem -LiteralPath $dir -File -Force | Sort-Object Name | ForEach-Object {
        $v=$_.VersionInfo
        [pscustomobject]@{Path=$_.FullName.Substring($root.Length).TrimStart('\');Size=$_.Length;Modified=$_.LastWriteTime.ToString('yyyy-MM-dd HH:mm');
            Product=$v.ProductName;Version=$v.FileVersion;SHA256=$(if($_.Extension -match '^\.(dll|exe|addon32|addon64|asi)$'){Hash $_.FullName}else{''})}
    }
}
Save 'installed-files.txt' ($listing | Format-Table -AutoSize -Wrap | Out-String -Width 400)
Save 'folders.txt' ((Get-ChildItem -LiteralPath $root -Directory -Force | ForEach-Object Name) -join "`r`n")

# Check output (the same text Check.cmd prints), including a refusal or a damaged package
$setup=Join-Path $PSScriptRoot 'Setup.ps1'
$check=try{& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $setup -Action Check -Target $root 2>&1 | Out-String}catch{"Check failed to run: $($_.Exception.Message)"}
Save 'check.txt' $check

# System: Windows, GPU and driver, display, running game processes
$sys=[Text.StringBuilder]::new()
[void]$sys.AppendLine("Collected: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')")
[void]$sys.AppendLine("Package: $(Split-Path $PSScriptRoot -Leaf)")
try{$m=Get-Content -Raw -LiteralPath (Join-Path $PSScriptRoot 'manifest.json') | ConvertFrom-Json;[void]$sys.AppendLine("Package version: $($m.Version)")}catch{}
[void]$sys.AppendLine("Bootloader: $(Scrub $root)")
try{$os=Get-CimInstance Win32_OperatingSystem;[void]$sys.AppendLine("Windows: $($os.Caption) $($os.Version) build $($os.BuildNumber)")}catch{}
try{$cpu=Get-CimInstance Win32_Processor | Select-Object -First 1;[void]$sys.AppendLine("CPU: $($cpu.Name.Trim())")}catch{}
try{[void]$sys.AppendLine("RAM: $([math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory/1GB)) GB")}catch{}
try{foreach($g in Get-CimInstance Win32_VideoController){[void]$sys.AppendLine("GPU: $($g.Name) | driver $($g.DriverVersion) ($($g.DriverDate)) | $($g.CurrentHorizontalResolution)x$($g.CurrentVerticalResolution) @ $($g.CurrentRefreshRate) Hz")}}catch{}
try{$nv=& nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader 2>$null;if($nv){[void]$sys.AppendLine("nvidia-smi: $nv")}}catch{}
try{$bg=Get-ItemProperty -LiteralPath 'HKLM:\SOFTWARE\WOW6432Node\PlayOnlineUS\SquareEnix\FinalFantasyXI' -ErrorAction Stop;[void]$sys.AppendLine("FFXI registry: window $($bg.'0001')x$($bg.'0002'), background $($bg.'0003')x$($bg.'0004')")}catch{[void]$sys.AppendLine('FFXI registry: PlayOnlineUS key not found (other region or private-server client)')}
$running=@(Get-Process pol,xiloader,phoenix-loader,ashita-cli,windower,dlss5-feed-host64 -ErrorAction SilentlyContinue | ForEach-Object Name)
[void]$sys.AppendLine("Running now: $(if($running.Count){$running -join ', '}else{'none'})")
if($missing.Count){[void]$sys.AppendLine("Not found: $($missing -join ', ')")}
Save 'system.txt' $sys.ToString()

# Crashes: Windows Error Reporting / Application Error records for the game and helper, last 14 days.
# The faulting module line names the DLL that crashed.
$crash=try{
    Get-WinEvent -FilterHashtable @{LogName='Application';Id=1000,1001,1002;StartTime=(Get-Date).AddDays(-14)} -ErrorAction Stop |
      Where-Object {$_.Message -match 'pol\.exe|xiloader|phoenix|ashita|windower|dlss5-feed|ffxi'} | Select-Object -First 20 |
      ForEach-Object {"[$($_.TimeCreated.ToString('yyyy-MM-dd HH:mm:ss'))] Event $($_.Id)`r`n$($_.Message)`r`n"}
}catch{"No matching crash records in the last 14 days."}
if(!$crash){$crash='No matching crash records in the last 14 days.'}
Save 'crashes.txt' ($crash -join "`r`n")

[void][IO.Directory]::CreateDirectory($OutDir)
$zip=Join-Path $OutDir "FFXI-Clarity-support-$stamp.zip"
# Entries are written by hand: .NET Framework's CreateFromDirectory stores backslash paths, which other unzip tools reject
Add-Type -AssemblyName System.IO.Compression,System.IO.Compression.FileSystem
$archive=[IO.Compression.ZipFile]::Open($zip,[IO.Compression.ZipArchiveMode]::Create)
try{Get-ChildItem -LiteralPath $work -Recurse -File | ForEach-Object {[void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive,$_.FullName,$_.FullName.Substring($work.Length+1).Replace('\','/'),[IO.Compression.CompressionLevel]::Optimal)}}finally{$archive.Dispose()}
Remove-Item -LiteralPath $work -Recurse -Force
Write-Output "Saved $zip"
Write-Output 'Attach this zip to a GitHub issue: https://github.com/OpMoonRise2/FFXI-DLSS5-Clarity/issues/new/choose'
Write-Output 'Your Windows user name was replaced with <user>. Open the zip first if you want to check what it contains.'
if(!$env:CLARITY_NO_EXPLORER){try{Start-Process explorer.exe "/select,`"$zip`""}catch{}}
