[CmdletBinding()]
param([ValidateSet('Check','Install','Restore')][string]$Action='Check', [string]$Target, [string]$Backup, [ValidateRange(0,8192)][int]$DepthFilter=4096, [switch]$SkipGpuCheck, [switch]$AllowDlaaOnly, [string]$Windower, [ValidateRange(1.1,4.0)][double]$SuperSampling=1.6)
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
if($Action -ne 'Check' -and @(Get-Process pol,xiloader,phoenix-loader,dlss5-feed-host64,Windower -ErrorAction SilentlyContinue).Count){throw 'Close all FFXI / PlayOnline sessions, the Windower launcher and feeder hosts first.'}
# Windower's settings.xml may carry an XML 1.1 declaration, which .NET's XmlDocument refuses; it is parsed as 1.0
# and written back with its own declaration. Windower reads either.
function ReadWindowerXml([string]$p){
    $text=[IO.File]::ReadAllText($p);$decl='<?xml version="1.0" encoding="utf-8"?>'
    if($text.TrimStart([char]0xFEFF) -match '^(<\?xml[^>]*\?>)'){$decl=$Matches[1]}
    $doc=New-Object Xml.XmlDocument;$doc.LoadXml(($text.TrimStart([char]0xFEFF) -replace '^<\?xml[^>]*\?>',''))
    $head=[byte[]]::new(3);$s=[IO.File]::OpenRead($p);try{$n=$s.Read($head,0,3)}finally{$s.Dispose()}
    return @{Doc=$doc;Decl=$decl;Bom=($n -eq 3 -and $head[0] -eq 0xEF -and $head[1] -eq 0xBB -and $head[2] -eq 0xBF)}
}
function WindowerXmlText($x){
    $sw=New-Object IO.StringWriter;$ws=New-Object Xml.XmlWriterSettings;$ws.Indent=$true;$ws.IndentChars='  ';$ws.OmitXmlDeclaration=$true;$ws.NewLineChars="`r`n"
    $w=[Xml.XmlWriter]::Create($sw,$ws);try{$x.Doc.Save($w)}finally{$w.Dispose()}
    return $x.Decl+"`r`n"+$sw.ToString()
}
function WriteWindowerXml($p,$x){[IO.File]::WriteAllText($p,(WindowerXmlText $x),[Text.UTF8Encoding]::new([bool]$x.Bom))}
if($Action -eq 'Restore'){
    if(!$Backup){throw 'Specify -Backup with the backup directory printed after installation.'}
    $receipt=Get-Content -Raw -LiteralPath (Join-Path $Backup 'receipt.json') | ConvertFrom-Json
    if($receipt.Target -ne $root){throw 'Backup belongs to another folder.'}
    foreach($e in $receipt.Files){$p=SafePath $root $e.Path;if(!(Test-Path -LiteralPath $p) -or (Hash $p) -ne $e.After){throw "Changed since installation; restore stopped without writes: $($e.Path)"};if($e.Before -and (Hash (SafePath $Backup $e.Path)) -ne $e.Before){throw 'Backup hash mismatch.'}}
    # Retail game-folder files: plain names only, checked like the rest before anything is written.
    $gameFiles=@();if($receipt.Game){$gameFiles=@($receipt.Game.Files)}
    foreach($e in $gameFiles){if($e.Path -match '[\\/:]'){throw 'Unexpected game-folder path in receipt.'};$p=Join-Path $receipt.Game.Dir $e.Path;if(!(Test-Path -LiteralPath $p) -or (Hash $p) -ne $e.After){throw "Changed since installation; restore stopped without writes: $p"};if($e.Before -and (Hash (SafePath $Backup "game\$($e.Path)")) -ne $e.Before){throw 'Backup hash mismatch.'}}
    $retired=Join-Path $root ('FFXI-Clarity-removed-'+[guid]::NewGuid().ToString('N'))
    foreach($e in $receipt.Files){$p=SafePath $root $e.Path;if($e.Before){Copy-Item -LiteralPath (SafePath $Backup $e.Path) -Destination $p -Force}else{$dest=SafePath $retired $e.Path;[void][IO.Directory]::CreateDirectory((Split-Path $dest -Parent));Move-Item -LiteralPath $p -Destination $dest}}
    foreach($e in $gameFiles){$p=Join-Path $receipt.Game.Dir $e.Path;if($e.Before){Copy-Item -LiteralPath (SafePath $Backup "game\$($e.Path)") -Destination $p -Force}else{$dest=SafePath $retired "game\$($e.Path)";[void][IO.Directory]::CreateDirectory((Split-Path $dest -Parent));Move-Item -LiteralPath $p -Destination $dest}}
    Write-Output "Restored original files. Newly added files were retained in $retired"
    # Windower rewrites settings.xml whenever its launcher saves, so a whole-file hash would block every restore.
    # Only the elements Install set are put back, and only while they still hold the value Install wrote.
    if($receipt.Windower){
        $ws=$receipt.Windower.Settings
        if(!(Test-Path -LiteralPath $ws)){Write-Output "Windower settings.xml not found at $ws; nothing to restore there. The original is in $(Join-Path $Backup 'windower-settings.xml').";return}
        $x=ReadWindowerXml $ws
        foreach($pr in $receipt.Windower.Profiles){
            $node=@($x.Doc.SelectNodes('/settings/profile') | Where-Object {$_.GetAttribute('name') -eq $pr.Name})[0]
            $label=$(if($pr.Name){"'$($pr.Name)'"}else{'(default)'})
            if(!$node){Write-Output "Windower profile $label no longer exists; skipped.";continue}
            foreach($s in $pr.Set){
                $el=$node.SelectSingleNode($s.Element)
                if(!$el -or $el.InnerText -ne $s.After){Write-Output "Windower profile $label`: <$($s.Element)> was changed after installation; kept as it is.";continue}
                if($null -eq $s.Before){[void]$node.RemoveChild($el)}else{$el.InnerText=$s.Before}
            }
        }
        WriteWindowerXml $ws $x
        Write-Output "Windower settings.xml: the profile values Install set were put back. The original file is also in $(Join-Path $Backup 'windower-settings.xml')."
    }
    return
}
if(!@(Get-ChildItem -LiteralPath $root -File -Filter '*.exe').Count){throw 'Choose the folder containing the FFXI loader/game executable, not the launcher download directory.'}
$problems=[Collections.Generic.List[string]]::new()
# DLSS needs an NVIDIA RTX card (tensor cores): GTX, MX, AMD and Intel cards cannot run it, and users without one
# crashed or got nothing after installing. Any RTX adapter counts (laptops also list their Intel/AMD graphics).
# Refused only on a confirmed miss: when Windows cannot list the adapters (WMI broken, cmdlet missing), the
# registry is tried, then it is a warning. -SkipGpuCheck overrides a wrong detection. Restore is never gated.
$gpuNote=$null;$gpus=@()
if(!$SkipGpuCheck){
    try{$gpus=@(Get-CimInstance -ClassName Win32_VideoController -ErrorAction Stop | ForEach-Object {$_.Name} | Where-Object {$_})}catch{}
    if(!$gpus.Count){try{$gpus=@(Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0*' -ErrorAction SilentlyContinue | ForEach-Object {$_.DriverDesc} | Where-Object {$_})}catch{}}
    if(!$gpus.Count){$gpuNote='Windows did not report a graphics card, so it was not checked. This only works on an NVIDIA RTX card (GTX, AMD and Intel cards cannot run DLSS).'}
    elseif(!@($gpus | Where-Object {$_ -match '\bRTX\b'}).Count){
        $msg="This needs an NVIDIA RTX graphics card. DLSS runs on RTX cards only; GTX, AMD and Intel cards cannot run it. Found: $(($gpus | Select-Object -Unique) -join ', ')."
        if(@($gpus | Where-Object {$_ -match 'Basic (Display|Render)'}).Count){$msg+=' "Microsoft Basic Display Adapter" means no graphics driver is installed: if you have an RTX card, install the NVIDIA driver, then run Check.cmd again.'}
        else{$msg+=' This PC cannot use FFXI-DLSS5-Clarity. (If the card above is wrong, see README.md, Troubleshooting.)'}
        $problems.Add($msg)
    }
}
# An existing reshade-shaders\ that already carries the feeder effect is the active preset's effect root
# (a played-on setup keeps LumeniteFX and the feeder effect there). It stays the root. Only the feeder
# effect has to match the shipped dlss5-feed.addon32 (same Feeder release), so one from another release is
# replaced (backed up, restorable). VORT and the package's own ffxi-clarity-shaders\ copy are installed
# beside it and are never required inside reshade-shaders\ (1.2.0 demanded all 23 files there and refused
# the very setup this package was tuned on).
$reuseShaders=$false;$staleFeed=$false;$oldVort=$false
$existingFeed=SafePath $root 'reshade-shaders\Shaders\DLSS5_Feed.fx'
$feedEntry='payload\ffxi-clarity-shaders\Shaders\DLSS5_Feed.fx'
if(Test-Path -LiteralPath $existingFeed){
    $reuseShaders=$true
    if((Hash $existingFeed) -ne $manifest.Files.$feedEntry){$staleFeed=$true}
    # A VORT already in that root is used as it is: a second VORT on the search path makes both copies'
    # includes ambiguous (X3067 'PostProcessVS', 'SRGBToLin'), and the older copy fails to compile on every start.
    $oldVort=Test-Path -LiteralPath (SafePath $root 'reshade-shaders\Shaders\vort_Motion.fx')
}
$runtime=@{};$runtimeNotes=[Collections.Generic.List[string]]::new()
# The neural forwarder ships in payload (GPL, the tested 2026-09-20 build; see tools\known-good.json); NVIDIA's two runtimes are user-supplied.
# A file in Dependencies\ is the one the user just supplied, so it replaces a different copy in host64\ (backed up).
# Before 1.2.5 host64\ always won, and a corrected DLL put in Dependencies\ was silently ignored.
foreach($name in @('nvngx_dlss.dll','nvngx_dlssnr.dll')){
    $installed=SafePath $root ('host64\'+$name);$supplied=Join-Path $PSScriptRoot ('Dependencies\'+$name)
    if(Test-Path -LiteralPath $supplied){
        $runtime[$name]=$supplied
        if((Test-Path -LiteralPath $installed) -and (Hash $installed) -ne (Hash $supplied)){$runtimeNotes.Add("Dependencies\$name differs from host64\$name`: Install replaces it with the one in Dependencies\ (backed up; Restore.cmd puts it back).")}
    }elseif(Test-Path -LiteralPath $installed){$runtime[$name]=$installed}else{$problems.Add("Supply Dependencies\$name (see README.md, Requirements)")}
    if($runtime.ContainsKey($name) -and !(IsX64 $runtime[$name])){$problems.Add("$name must be a valid x64 DLL.")}
}
# nvngx_dlssnr.dll comes in two builds that both say 310.8.0. NVIDIA's signed original creates the neural feature on
# RTX 50 only: on RTX 20/30/40 it fails (OptiScaler.log: create 0xBAD00001 FAIL_FeatureNotSupported) and the game
# silently gets DLAA alone. The modified build (RenoDX Discord) runs on RTX 20/30/40; editing it broke NVIDIA's
# signature, which is how an unknown copy is told apart. The tested copy (played on, RTX 4060) and a copy that
# failed this way on an RTX 4070 Ti (2026-10-19 report; the tested copy fixed it) are recognised by hash, so the
# common cases do not depend on the signature cmdlet being available.
$testedDlssNr='8270B350CD82DE5CE89806872CDD6B6A9249B80836B91BBEB3573470744CC206'
$originalDlssNr=@('E16BCF15E16E13F527491CDF7845B2FE6521A738D8F7C9C721866A8496E1FC8E')
# Started from PowerShell 7 (or a tool that inherits its environment), Windows PowerShell gets PowerShell 7's module
# paths and cannot autoload Get-AuthenticodeSignature; 1.2.5 then silently treated NVIDIA's original as unknown.
# Loading the module from this PowerShell's own folder works either way.
try{Import-Module (Join-Path $PSHOME 'Modules\Microsoft.PowerShell.Security\Microsoft.PowerShell.Security.psd1') -ErrorAction Stop}catch{}
function DlssNrBuild([string]$p){
    $h=Hash $p
    if($h -eq $testedDlssNr){return 'tested'};if($h -in $originalDlssNr){return 'original'}
    try{$status=[string](Get-AuthenticodeSignature -LiteralPath $p -ErrorAction Stop).Status}catch{return 'unknown'}
    if($status -eq 'Valid'){return 'original'};if($status -eq 'HashMismatch'){return 'modified'};return 'unknown'
}
# GeForce RTX x0x0 names the generation; Blackwell workstation cards are RTX 50 class. Other names (TITAN RTX,
# RTX A4000, RTX 5000 Ada) are not guessed, and no refusal is based on them.
$rtx50=@($gpus | Where-Object {$_ -match 'GeForce RTX 50\d0|Blackwell'}).Count -gt 0
$rtxOlder=@($gpus | Where-Object {$_ -match 'GeForce RTX [234]0\d0'} | Select-Object -Unique)
if($runtime.ContainsKey('nvngx_dlssnr.dll') -and !$rtx50){
    $dlssNrFile=$(if($runtime['nvngx_dlssnr.dll'].StartsWith($PSScriptRoot,[StringComparison]::OrdinalIgnoreCase)){'Dependencies\nvngx_dlssnr.dll'}else{'host64\nvngx_dlssnr.dll'})
    $build=DlssNrBuild $runtime['nvngx_dlssnr.dll']
    $fix='Get the modified nvngx_dlssnr.dll for RTX 20/30/40 (see README.md, Requirements), put it in Dependencies\ and run Check.cmd again: Install then replaces the one in host64\ (backed up).'
    if($build -eq 'original' -and $rtxOlder.Count){
        $msg="$dlssNrFile is NVIDIA's original build, which runs the neural pass on RTX 50 cards only. On your $($rtxOlder -join ', ') DLSS 5 would silently do nothing (DLAA only). $fix"
        if($AllowDlaaOnly){$runtimeNotes.Add("WARNING: $msg Installing anyway (-AllowDlaaOnly).")}else{$problems.Add("$msg To install for DLAA only, run Install.cmd -AllowDlaaOnly.")}
    }
    elseif($build -eq 'original'){$runtimeNotes.Add("WARNING: $dlssNrFile is NVIDIA's original build, which runs the neural pass on RTX 50 cards only. On an RTX 20/30/40 card you get DLAA only. $fix")}
    elseif($build -ne 'tested' -and $rtxOlder.Count){$runtimeNotes.Add("$dlssNrFile is not the tested build. If the neural pass does not run (no 'DLSS-NR cost' lines in host64\OptiScaler.log), see README.md, Troubleshooting.")}
}
$preserveWrappers=@{};$replacedWrappers=[Collections.Generic.List[string]]::new()
# dgVoodoo 2.87.2 and 2.87.5 both carry FileVersion 4.8.2.134. 1.2.x shipped 2.87.2, which crashes on start-up
# (access violation at d3d8.dll+0xa33cc while the device is created) on RTX 50 PCs with a second adapter, and
# "replaced" a launcher's working 2.87.5 with it (#11, #12). 2.87.5 is shipped now; 2.87.2 is replaced like any
# other build, with its own message. Matched by exact bytes, not spoofable version metadata.
$knownD3d8=@()
$crashingD3d8=@('85284D3024D6AD7D4B4154CD96B97E0D64F28F6A0F7AD490E5BE70D626F62604')
# Another build of the same wrapper (a launcher's or another mod's dgVoodoo / ReShade) is replaced by the tested
# one and backed up like any replaced file. Metadata only decides "same product" here, never "keep it": a file
# that is some other wrapper is still never overwritten. 1.2.1 refused every other dgVoodoo / ReShade build.
foreach($pair in @(@('d3d8.dll','dgVoodoo'),@('dxgi.dll','ReShade'),@('host64\dxgi.dll','ReShade'))){
    $p=SafePath $root $pair[0]
    if(Test-Path -LiteralPath $p){
        $hash=Hash $p
        if($hash -eq $manifest.Files.('payload\'+$pair[0])){$preserveWrappers[$pair[0]]=$true}
        elseif($pair[0] -eq 'd3d8.dll' -and $hash -in $knownD3d8){$preserveWrappers[$pair[0]]=$true}
        elseif($pair[0] -eq 'd3d8.dll' -and $hash -in $crashingD3d8){$replacedWrappers.Add('Existing d3d8.dll is dgVoodoo 2.87.2 (shipped by Clarity 1.2.x), which crashes on start-up on some RTX 50 PCs: Install replaces it with dgVoodoo 2.87.5 (backed up; Restore.cmd puts it back).')}
        else{
            $v=(Get-Item -LiteralPath $p).VersionInfo
            if($v.ProductName -eq $pair[1]){$replacedWrappers.Add("Existing $($pair[0]) is $($pair[1]) $($v.ProductVersion), not the tested build: Install replaces it with the tested one (backed up; Restore.cmd puts it back).")}
            else{$problems.Add("Existing $($pair[0]) is not $($pair[1]), so it belongs to another graphics wrapper or mod and is never overwritten. Move it out of $root (keep a copy to switch back), then run Check.cmd again.")}
        }
    }
}
# dgVoodoo.conf: a text config set to anything but D3D11 FL11 is switched to it (backed up). Only the binary form,
# which this script cannot edit safely, still needs dgVoodooCpl.exe.
$dg=ReadText (SafePath $root 'dgVoodoo.conf');$dgFixed=$null
if($dg -and $dg -notmatch '(?im)^\s*OutputAPI\s*=\s*d3d11_fl11_0\s*$'){
    if($dg -match '(?im)^\s*OutputAPI\s*='){$dgFixed=$dg -replace '(?im)^(\s*OutputAPI\s*=)[^\r\n]*','${1} d3d11_fl11_0'}
    elseif($dg -match '(?im)^\s*\[General\]\s*$'){$dgFixed=SetIni $dg 'General' 'OutputAPI' 'd3d11_fl11_0'}
    else{$problems.Add('dgVoodoo.conf is not a text config this installer can edit. Run dgVoodooCpl.exe, set Output API to "Direct3D 11 (feature level 11.0)" and MSAA off, Apply, then run Check.cmd again.')}
}
$conflicts=@(Get-ChildItem -LiteralPath (Join-Path $root 'host64') -File -ErrorAction SilentlyContinue | Where-Object {$_.Name -match '^(renodx-dlss.*|deep-fried-chicken.*)\.addon64$'})
foreach($c in $conflicts){$problems.Add("host64\$($c.Name) is another neural consumer (RenoDX / Deep Fried Chicken) and would fight OptiScaler for the neural pass. Move it out of host64 (put it back to switch back), then run Check.cmd again.")}
# Windower 4 writes FFXI's background (3D) resolution as window size x <supersampling>, 1.0 unless set, so the
# 3D scene is drawn at the swapchain's own size. The Shader Toggler's RESOLUTION match then fires inside the
# scene instead of on the scale-down to the screen (Ashita's 4096x4096 keeps the two apart): effects land
# mid-scene, characters blink and lose shading, nameplates and tunnel shadows move with draw order, and the
# DLSS feed rebuilds every few seconds. Supersampling above 1 restores the split, bump mapping on matches the
# Ashita setup the toggler list was taken from, and the depth filter follows the (non-square) 3D size. The
# launcher rewrites the registry from settings.xml on every start, so only settings.xml is edited.
# Found automatically when the bootloader folder sits inside the Windower folder; otherwise pass -Windower
# (retail: the PlayOnline folder holding pol.exe is the target, and Windower lives elsewhere).
$win=$null
# Where Windower starts a profile's <executable> (pol.exe when unset), in the launcher's own order: the path as
# given, then beside Windower, then the PlayOnline install folder from the registry (retail).
function WindowerExe([string]$exe,[string]$winDir){
    if([IO.Path]::IsPathRooted($exe)){return [IO.Path]::GetFullPath($exe)}
    $beside=[IO.Path]::GetFullPath((Join-Path $winDir $exe));if(Test-Path -LiteralPath $beside){return $beside}
    foreach($k in 'PlayOnlineUS','PlayOnlineEU','PlayOnline'){
        $pol=(Get-ItemProperty -Path "HKLM:\SOFTWARE\WOW6432Node\$k\InstallFolder" -ErrorAction SilentlyContinue).'1000'
        if($pol){$p=[IO.Path]::GetFullPath((Join-Path $pol $exe));if(Test-Path -LiteralPath $p){return $p}}
    }
    return $beside
}
if(!$Windower){$up=Split-Path $root -Parent;if($up -and (Test-Path -LiteralPath (Join-Path $up 'Windower.exe')) -and (Test-Path -LiteralPath (Join-Path $up 'settings.xml'))){$Windower=$up}}
if($Windower -and !(Test-Path -LiteralPath $Windower -PathType Container)){$problems.Add("-Windower `"$Windower`" is not a folder. Pass the folder that holds Windower.exe and settings.xml (for example -Windower `"D:\Games\Windower4`").");$Windower=$null}
if($Windower){
    $winDir=(Resolve-Path -LiteralPath $Windower).Path;$winSettings=Join-Path $winDir 'settings.xml'
    if(!(Test-Path -LiteralPath (Join-Path $winDir 'Windower.exe'))){$problems.Add("No Windower.exe in $winDir. Pass the Windower 4 folder itself with -Windower.")}
    elseif(!(Test-Path -LiteralPath $winSettings)){$problems.Add("No settings.xml in $winDir. Start the Windower launcher once, close it, then run Check.cmd again.")}
    else{
        try{$winXml=ReadWindowerXml $winSettings}catch{$winXml=$null;$problems.Add("Windower settings.xml could not be read ($($_.Exception.Message)). Open and close the Windower launcher to rewrite it, then run Check.cmd again.")}
        if($winXml){
            # Windower uses a profile's <executable> as the game loader; pol.exe when unset.
            $rootPrefix=$root.TrimEnd('\')+'\';$winProfiles=@();$started=@()
            foreach($node in $winXml.Doc.SelectNodes('/settings/profile')){
                $exe=$node.SelectSingleNode('executable');$exe=$(if($exe -and $exe.InnerText.Trim()){$exe.InnerText.Trim()}else{'pol.exe'})
                $full=WindowerExe $exe $winDir;$started+=$full
                if($full.StartsWith($rootPrefix,[StringComparison]::OrdinalIgnoreCase)){$winProfiles+=$node}
            }
            if(!$winProfiles.Count){$problems.Add("No Windower profile in $winSettings starts a game from $root (they start: $(($started | Select-Object -Unique) -join ', ')). Install into the folder your profile starts: on retail the PlayOnline folder that holds pol.exe, on a private server the folder holding its loader (or set the profile's executable to the loader in this folder, for example $(Join-Path $root 'xiloader.exe'), in the Windower launcher). Then run Check.cmd again.")}
            else{
                # The launcher's last start left the window size in the registry; used when the profile has none.
                $reg=$null;foreach($k in 'PlayOnlineUS','PlayOnline','PlayOnlineEU'){$p="HKLM:\SOFTWARE\WOW6432Node\$k\SquareEnix\FinalFantasyXI";if(Test-Path $p){$reg=Get-ItemProperty $p;break}}
                $win=@{Settings=$winSettings;Profiles=@()}
                foreach($node in $winProfiles){
                    $name=$node.GetAttribute('name');$label=$(if($name){"'$name'"}else{'(default)'})
                    $get={param($n) $e=$node.SelectSingleNode($n);if($e){$e.InnerText.Trim()}else{$null}}
                    $w=0;$h=0;[void][int]::TryParse((& $get 'width'),[ref]$w);[void][int]::TryParse((& $get 'height'),[ref]$h)
                    $set=@()
                    if($w -le 0 -or $h -le 0){
                        if($reg -and [int]$reg.'0001' -gt 0 -and [int]$reg.'0002' -gt 0){$w=[int]$reg.'0001';$h=[int]$reg.'0002';$set+=@{Element='width';Before=(& $get 'width');After="$w"},@{Element='height';Before=(& $get 'height');After="$h"}}
                        else{$problems.Add("Windower profile $label has no window resolution. Set it in the Windower launcher, save, close the launcher, then run Check.cmd again.");continue}
                    }
                    $ss=0.0;$ssText=& $get 'supersampling'
                    if(!$ssText -or ![double]::TryParse($ssText,[Globalization.NumberStyles]::Float,[Globalization.CultureInfo]::InvariantCulture,[ref]$ss) -or $ss -le 1.0){$ss=$SuperSampling;$set+=@{Element='supersampling';Before=$ssText;After=$ss.ToString([Globalization.CultureInfo]::InvariantCulture)}}
                    if((& $get 'bumpmapping') -ne 'true'){$set+=@{Element='bumpmapping';Before=(& $get 'bumpmapping');After='true'}}
                    # Same arithmetic as the launcher: float multiply, stored as a DWORD (rounded to even).
                    $bgW=[Convert]::ToInt32([single]([single]$w*[single]$ss));$bgH=[Convert]::ToInt32([single]([single]$h*[single]$ss))
                    $win.Profiles+=@{Name=$name;Label=$label;Node=$node;Set=$set;Width=$w;Height=$h;SS=$ss;BgW=$bgW;BgH=$bgH}
                }
                $sizes=@($win.Profiles | ForEach-Object {"$($_.BgW)x$($_.BgH)"} | Select-Object -Unique)
                if($sizes.Count -gt 1){$problems.Add("Windower profiles starting from $root would give different 3D sizes ($($sizes -join ', ')), but ReShade's depth filter in this folder can match only one. Give them the same window resolution and supersampling, or point only one at this folder.")}
            }
        }
    }
}
# Retail (PlayOnline / Steam; played on Steam retail 2026-10-22): Square Enix's pol.exe runs the game in its own
# process, but FFXiMain.dll is loaded from the FINAL FANTASY XI folder and its d3d8.dll import is resolved there,
# not beside pol.exe. With dgVoodoo beside pol.exe only, the game got Windows' Direct3D 8, which ReShade never
# sees. d3d8.dll and dgVoodoo.conf therefore also go into the game folder (beside pol.exe they still serve loaders
# that load d3d8.dll early). A DirectDraw wrapper beside pol.exe (dgVoodoo DDraw.dll / D3DImm.dll) puts ReShade
# into the PlayOnline menus; when PlayOnline hands over to the game its device closes, ReShade unloads the
# add-ons, the Shader Toggler does not unregister and pol.exe crashes in ntdll.dll. That wrapper is refused, and
# so are other graphics wrappers in the game folder.
$retail=$null
if(Test-Path -LiteralPath (Join-Path $root 'pol.exe')){
    $game=$null;$fromReg=$false
    foreach($k in 'PlayOnlineUS','PlayOnlineEU','PlayOnline'){
        $f=Get-ItemProperty -Path "HKLM:\SOFTWARE\WOW6432Node\$k\InstallFolder" -ErrorAction SilentlyContinue
        if($f -and $f.'1000' -and [IO.Path]::GetFullPath($f.'1000').TrimEnd('\') -eq $root.TrimEnd('\')){$fromReg=$true;if($f.'0001'){$game=[IO.Path]::GetFullPath($f.'0001')};break}
    }
    if(!$game -or !(Test-Path -LiteralPath (Join-Path $game 'FFXiMain.dll'))){$game=Join-Path (Split-Path $root -Parent) 'FINAL FANTASY XI'}
    if(Test-Path -LiteralPath (Join-Path $game 'FFXiMain.dll')){$retail=@{Game=(Resolve-Path -LiteralPath $game).Path}}
    elseif($fromReg){$problems.Add("$root is PlayOnline's install folder, but the FINAL FANTASY XI folder (FFXiMain.dll) was not found beside it or in the registry. Start FFXI from PlayOnline once so it finishes updating, then run Check.cmd again.")}
}
if($retail){
    $isWindows={param($p) (Get-Item -LiteralPath $p).VersionInfo.ProductName -match 'Microsoft'}
    $ddraw=@('DDraw.dll','D3DImm.dll' | Where-Object {(Test-Path -LiteralPath (Join-Path $root $_)) -and !(& $isWindows (Join-Path $root $_))})
    if($ddraw.Count){$problems.Add("$($ddraw -join ' and ') beside pol.exe $(if($ddraw.Count -gt 1){'are'}else{'is'}) DirectDraw wrapper code (for example dgVoodoo's). It puts ReShade into the PlayOnline menus, and pol.exe then crashes when PlayOnline starts FFXI. Move $($ddraw -join ' and ') out of $root (keep them to switch back), then run Check.cmd again.")}
    foreach($n in 'd3d9.dll','dxgi.dll','d3d11.dll','version.dll','dinput8.dll'){
        $p=Join-Path $retail.Game $n
        if((Test-Path -LiteralPath $p) -and !(& $isWindows $p)){$problems.Add("$n in $($retail.Game) belongs to another graphics mod (for example DXVK, ReShade or DLSS Enabler) and takes over FFXI's rendering there. Move it out of that folder (keep it to switch back), then run Check.cmd again.")}
    }
    $gd=Join-Path $retail.Game 'd3d8.dll'
    if(Test-Path -LiteralPath $gd){
        $h=Hash $gd
        if($h -ne $manifest.Files.'payload\d3d8.dll' -and $h -notin $knownD3d8){
            if($h -in $crashingD3d8){$replacedWrappers.Add("Existing d3d8.dll in $($retail.Game) is dgVoodoo 2.87.2 (shipped by Clarity 1.2.x), which crashes on start-up on some RTX 50 PCs: Install replaces it with dgVoodoo 2.87.5 (backed up; Restore.cmd puts it back).")}
            elseif((Get-Item -LiteralPath $gd).VersionInfo.ProductName -eq 'dgVoodoo'){$replacedWrappers.Add("Existing d3d8.dll in $($retail.Game) is dgVoodoo $((Get-Item -LiteralPath $gd).VersionInfo.ProductVersion), not the tested build: Install replaces it with the tested one (backed up; Restore.cmd puts it back).")}
            else{$problems.Add("d3d8.dll in $($retail.Game) is not dgVoodoo, so it belongs to another graphics wrapper or mod and is never overwritten. Move it out of that folder (keep a copy to switch back), then run Check.cmd again.")}
        }
    }
    # FFXI draws its 3D scene at the background resolution in the registry. The FINAL FANTASY XI Config tool writes
    # it from its own settings on every save (not always 4096x4096), so the depth filter follows the registry.
    foreach($k in 'PlayOnlineUS','PlayOnline','PlayOnlineEU'){
        $r=Get-ItemProperty -Path "HKLM:\SOFTWARE\WOW6432Node\$k\SquareEnix\FinalFantasyXI" -ErrorAction SilentlyContinue
        if($r -and [int]$r.'0003' -gt 0 -and [int]$r.'0004' -gt 0){$retail.BgW=[int]$r.'0003';$retail.BgH=[int]$r.'0004';$retail.W=[int]$r.'0001';$retail.H=[int]$r.'0002';break}
    }
}
Write-Output "FFXI Clarity portable preflight: $root"
if($gpuNote){Write-Output "WARNING: $gpuNote"}
if($problems.Count){$problems | ForEach-Object {Write-Output "NEEDED: $_"};Write-Output 'Nothing was changed. Fix the NEEDED lines above and run Check.cmd again.';if($Action -eq 'Install'){throw 'No installation files changed.'};return}
$replacedWrappers | ForEach-Object {Write-Output $_}
$runtimeNotes | ForEach-Object {Write-Output $_}
if($win){
    foreach($pr in $win.Profiles){
        $what=$(if($pr.Set.Count){'Install sets '+(($pr.Set | ForEach-Object {"$($_.Element)=$($_.After)"}) -join ', ')+' (Restore.cmd puts them back)'}else{'already set'})
        Write-Output "Windower profile $($pr.Label): $($pr.Width)x$($pr.Height), 3D drawn at $($pr.BgW)x$($pr.BgH); $what."
    }
    Write-Output "ReShade.ini depth filter: Install sets $($win.Profiles[0].BgW)x$($win.Profiles[0].BgH) to match the Windower 3D size (-DepthFilter is not used with Windower)."
}
if($retail){
    Write-Output "Retail PlayOnline: FFXI loads Direct3D 8 from $($retail.Game). Install also puts dgVoodoo's d3d8.dll and dgVoodoo.conf there (backed up; Restore.cmd takes them out again)."
    if(!$win -and !$PSBoundParameters.ContainsKey('DepthFilter') -and $retail.BgW){
        Write-Output "ReShade.ini depth filter: Install sets $($retail.BgW)x$($retail.BgH), FFXI's background resolution in the registry. If you change it later (FINAL FANTASY XI Config rewrites it on every save), run Install.cmd again."
        if($retail.BgW -eq $retail.W -and $retail.BgH -eq $retail.H){Write-Output "WARNING: FFXI's background resolution equals the window size ($($retail.W)x$($retail.H)), so the Shader Toggler cannot tell the 3D scene from the screen (blinking characters). Set a larger background resolution; see README.md, Retail."}
    }
}
if($dgFixed){Write-Output 'dgVoodoo.conf is not set to Direct3D 11 feature level 11: Install sets OutputAPI = d3d11_fl11_0 (backed up). Phoenix launcher rewrites this file every launch: set its graphics output to D3D11 there too.'}
Write-Output 'File prerequisites passed. GPU, driver and live rendering still require the host test and gameplay check.'
if($reuseShaders){
    if($staleFeed){Write-Output 'Existing reshade-shaders\Shaders\DLSS5_Feed.fx is from another Feeder release: Install replaces it (backed up) so it matches the shipped dlss5-feed.addon32.'}
    elseif($oldVort){Write-Output 'Existing reshade-shaders\ already has this release''s DLSS5_Feed.fx and VORT: it stays the effect root, and only textures are added from ffxi-clarity-shaders\ (a second VORT on the search path fails to compile).'}
    else{Write-Output 'Existing reshade-shaders\ already has this release''s DLSS5_Feed.fx: it stays the effect root; VORT is added from ffxi-clarity-shaders\.'}
}
$rsPeek=ReadText (SafePath $root 'ReShade.ini')
if($rsPeek -and $rsPeek -notmatch 'RESHADE_DEPTH_INPUT_IS_REVERSED='){Write-Output 'ReShade.ini has no depth orientation: Install adds RESHADE_DEPTH_INPUT_IS_REVERSED=0 (FFXI depth is not reversed; ReShade assumes reversed).'}
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
foreach($e in $manifest.Files.PSObject.Properties){if($e.Name.StartsWith('payload\')){$rel=$e.Name.Substring(8);if($preserveWrappers.ContainsKey($rel)){continue};$dest=SafePath $root $rel;if(!(Test-Path -LiteralPath $dest) -or (Hash $dest) -ne $e.Value){$changes[$rel]=@{Source=(Join-Path $PSScriptRoot $e.Name)}}}}
# The feeder effect in an existing reshade-shaders\ must be the one built with the shipped add-on.
if($staleFeed){$changes['reshade-shaders\Shaders\DLSS5_Feed.fx']=@{Source=(Join-Path $PSScriptRoot $feedEntry)}}
foreach($n in $runtime.Keys){$rel='host64\'+$n;$dest=SafePath $root $rel;if(!(Test-Path -LiteralPath $dest) -or (Hash $dest) -ne (Hash $runtime[$n])){$changes[$rel]=@{Source=$runtime[$n]}}}
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
# Ctrl+F9 (show the helper window, and with it OptiScaler's menu, inside the game) is the documented way to
# reach the settings without Alt+Tab. cast_key=0 switches it off, which left users with no in-game route;
# an unbound key is bound to Ctrl+F9. Any other key the user chose is kept.
for($i=0;$i -lt $cfgLines.Count;$i++){if($cfgLines[$i] -match '^cast_key=0*\s*$'){$cfgLines[$i]='cast_key=120';CfgSet 'cast_mods=2' $true}}
$changes['dlss5-feed.cfg']=@{Text=(($cfgLines -join "`r`n")+"`r`n")}
$rs=ReadText (SafePath $root 'ReShade.ini')
if($rs){
    # Keep existing presets intact. The user selects our separate preset for the first run.
    # With an existing reshade-shaders\ as the effect root, only VORT (and the textures) are added from
    # ffxi-clarity-shaders\: adding its whole Shaders\** too would hand ReShade two DLSS5_Feed.fx.
    if($oldVort){$fxPath=$null}elseif($reuseShaders){$fxPath='.\ffxi-clarity-shaders\Shaders\vort_Shaders\**'}else{$fxPath='.\ffxi-clarity-shaders\Shaders\**'}
    if($rs -match '(?im)^EffectSearchPaths=(.*)$'){$paths=$Matches[1].Trim()}else{$paths=''}
    if($fxPath -and $paths -notlike '*ffxi-clarity-shaders*'){$rs=SetIni $rs 'GENERAL' 'EffectSearchPaths' ($paths+','+$fxPath).Trim(',')}
    if($rs -match '(?im)^TextureSearchPaths=(.*)$'){$paths=$Matches[1].Trim()}else{$paths=''}
    if($paths -notlike '*ffxi-clarity-shaders*'){$rs=SetIni $rs 'GENERAL' 'TextureSearchPaths' ($paths+',.\ffxi-clarity-shaders\Textures\**').Trim(',')}
    # FFXI's depth (dgVoodoo, Direct3D 8 projection) is not reversed; ReShade assumes reversed when nothing
    # says otherwise, which flips the feeder effect's depth tests and the orientation it reports to the host.
    # Decide it once where the user has not; an explicit RESHADE_DEPTH_INPUT_IS_REVERSED of any value is kept.
    if($rs -notmatch 'RESHADE_DEPTH_INPUT_IS_REVERSED='){
        if($rs -match '(?im)^PreprocessorDefinitions=(.*)$'){$defs=$Matches[1].Trim()}else{$defs=''}
        $rs=SetIni $rs 'GENERAL' 'PreprocessorDefinitions' ($defs+',RESHADE_DEPTH_INPUT_IS_REVERSED=0,RESHADE_DEPTH_INPUT_IS_UPSIDE_DOWN=0,RESHADE_DEPTH_INPUT_IS_LOGARITHMIC=0').Trim(',')
    }
}else{
    $rs="[GENERAL]`r`nEffectSearchPaths=.\ffxi-clarity-shaders\Shaders\**`r`nTextureSearchPaths=.\ffxi-clarity-shaders\Textures\**`r`nPresetPath=.\FFXI-Clarity.ini`r`nPreprocessorDefinitions=RESHADE_DEPTH_INPUT_IS_REVERSED=0,RESHADE_DEPTH_INPUT_IS_UPSIDE_DOWN=0,RESHADE_DEPTH_INPUT_IS_LOGARITHMIC=0,RESHADE_DEPTH_LINEARIZATION_FAR_PLANE=1000.0`r`n[INPUT]`r`nKeyOverlay=116,0,0,0`r`nKeyNextPreset=121,1,0,0`r`nKeyPreviousPreset=122,1,0,0`r`n[OVERLAY]`r`nAutoSavePreset=0`r`n[DEPTH]`r`nDepthCopyBeforeClears=0`r`n"
}
# Generic Depth: FFXI draws its 3D scene into a square buffer sized by the client's background
# resolution (registry 0003/0004). Lock the depth filter to it so the right buffer is picked on
# every launch. Applied when no filter exists yet, or when -DepthFilter is passed explicitly.
$depthIsFresh = $rs -notmatch '(?im)^FilterResolutionWidth='
if($win){
    # Windower's 3D buffer is window size x supersampling, not square: always lock the filter to it.
    $rs=SetIni $rs 'DEPTH' 'FilterResolutionWidth' "$($win.Profiles[0].BgW)"
    $rs=SetIni $rs 'DEPTH' 'FilterResolutionHeight' "$($win.Profiles[0].BgH)"
    $rs=SetIni $rs 'DEPTH' 'UseAspectRatioHeuristics' '4'
}elseif($retail -and $retail.BgW -and !$PSBoundParameters.ContainsKey('DepthFilter')){
    # Retail: the background resolution from the registry, which the FFXI Config tool rewrites (often not square).
    $rs=SetIni $rs 'DEPTH' 'FilterResolutionWidth' "$($retail.BgW)"
    $rs=SetIni $rs 'DEPTH' 'FilterResolutionHeight' "$($retail.BgH)"
    $rs=SetIni $rs 'DEPTH' 'UseAspectRatioHeuristics' '4'
}elseif($DepthFilter -gt 0 -and ($depthIsFresh -or $PSBoundParameters.ContainsKey('DepthFilter'))){
    $rs=SetIni $rs 'DEPTH' 'FilterResolutionWidth' "$DepthFilter"
    $rs=SetIni $rs 'DEPTH' 'FilterResolutionHeight' "$DepthFilter"
    $rs=SetIni $rs 'DEPTH' 'UseAspectRatioHeuristics' '4'
}
$changes['ReShade.ini']=@{Text=$rs}
if($dgFixed){$changes['dgVoodoo.conf']=@{Text=$dgFixed}}
if(!$dg){$changes['dgVoodoo.conf']=@{Text="[General]`r`nOutputAPI=d3d11_fl11_0`r`nFullScreenMode=false`r`n[DirectX]`r`nResolution=unforced`r`ndgVoodooWatermark=false`r`n"}}
# Retail: the same dgVoodoo and configuration beside FFXiMain.dll, where the game resolves d3d8.dll.
$gameChanges=@{}
if($retail){
    $gd=Join-Path $retail.Game 'd3d8.dll';$src=Join-Path $PSScriptRoot 'payload\d3d8.dll'
    if(!(Test-Path -LiteralPath $gd) -or (Hash $gd) -ne (Hash $src)){$gameChanges['d3d8.dll']=@{Source=$src}}
    $dgText=$(if($changes.ContainsKey('dgVoodoo.conf')){$changes['dgVoodoo.conf'].Text}else{$dg})
    if((ReadText (Join-Path $retail.Game 'dgVoodoo.conf')) -ne $dgText){$gameChanges['dgVoodoo.conf']=@{Text=$dgText}}
}
$backupDir=Join-Path $root ('FFXI-Clarity-backup-'+[guid]::NewGuid().ToString('N'))
[void][IO.Directory]::CreateDirectory($backupDir)
$records=[Collections.Generic.List[object]]::new()
foreach($rel in ($changes.Keys | Sort-Object)){$p=SafePath $root $rel;$before=$null;if(Test-Path -LiteralPath $p){$before=Hash $p;$saved=SafePath $backupDir $rel;[void][IO.Directory]::CreateDirectory((Split-Path $saved -Parent));Copy-Item -LiteralPath $p -Destination $saved};$records.Add([pscustomobject]@{Path=$rel;Before=$before;After=$null})}
# Game-folder files are kept under game\ in the backup and recorded with that folder, outside the receipt's Target.
$gameRecords=[Collections.Generic.List[object]]::new()
foreach($n in ($gameChanges.Keys | Sort-Object)){$p=Join-Path $retail.Game $n;$before=$null;if(Test-Path -LiteralPath $p){$before=Hash $p;$saved=SafePath $backupDir "game\$n";[void][IO.Directory]::CreateDirectory((Split-Path $saved -Parent));Copy-Item -LiteralPath $p -Destination $saved};$gameRecords.Add([pscustomobject]@{Path=$n;Before=$before;After=$null})}
$gameRecord=$(if($gameRecords.Count){[pscustomobject]@{Dir=$retail.Game;Files=$gameRecords}}else{$null})
# Windower's settings.xml lives outside the bootloader folder: kept whole in the backup, and recorded per element.
$winRecord=$null
if($win -and @($win.Profiles | Where-Object {$_.Set.Count}).Count){
    Copy-Item -LiteralPath $win.Settings -Destination (Join-Path $backupDir 'windower-settings.xml')
    $winRecord=[pscustomobject]@{Settings=$win.Settings;Profiles=@($win.Profiles | Where-Object {$_.Set.Count} | ForEach-Object {[pscustomobject]@{Name=$_.Name;Set=@($_.Set | ForEach-Object {[pscustomobject]$_})}})}
}
try{
    foreach($r in $records){$p=SafePath $root $r.Path;$c=$changes[$r.Path];[void][IO.Directory]::CreateDirectory((Split-Path $p -Parent));if($c.ContainsKey('Source')){Copy-Item -LiteralPath $c.Source -Destination $p -Force;if((Hash $p) -ne (Hash $c.Source)){throw 'Copy verification failed.'}}else{WriteText $p $c.Text};$r.After=Hash $p}
    foreach($r in $gameRecords){$p=Join-Path $retail.Game $r.Path;$c=$gameChanges[$r.Path];if($c.ContainsKey('Source')){Copy-Item -LiteralPath $c.Source -Destination $p -Force;if((Hash $p) -ne (Hash $c.Source)){throw 'Copy verification failed.'}}else{WriteText $p $c.Text};$r.After=Hash $p}
    if($winRecord){
        foreach($pr in $win.Profiles){foreach($s in $pr.Set){$el=$pr.Node.SelectSingleNode($s.Element);if(!$el){$el=$pr.Node.AppendChild($winXml.Doc.CreateElement($s.Element))};$el.InnerText=$s.After}}
        WriteWindowerXml $win.Settings $winXml
    }
}catch{
    $failure=$_
    $failedFiles=Join-Path $backupDir 'failed-install-files'
    foreach($r in $records){$p=SafePath $root $r.Path;if($r.Before){Copy-Item -LiteralPath (SafePath $backupDir $r.Path) -Destination $p -Force}elseif(Test-Path -LiteralPath $p){$dest=SafePath $failedFiles $r.Path;[void][IO.Directory]::CreateDirectory((Split-Path $dest -Parent));Move-Item -LiteralPath $p -Destination $dest}}
    foreach($r in $gameRecords){$p=Join-Path $retail.Game $r.Path;if($r.Before){Copy-Item -LiteralPath (SafePath $backupDir "game\$($r.Path)") -Destination $p -Force}elseif(Test-Path -LiteralPath $p){$dest=SafePath $failedFiles "game\$($r.Path)";[void][IO.Directory]::CreateDirectory((Split-Path $dest -Parent));Move-Item -LiteralPath $p -Destination $dest}}
    if($winRecord){Copy-Item -LiteralPath (Join-Path $backupDir 'windower-settings.xml') -Destination $win.Settings -Force}
    throw $failure
}finally{@{Target=$root;Files=@($records.ToArray());Game=$gameRecord;Windower=$winRecord;Version=$manifest.Version} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $backupDir 'receipt.json') -Encoding UTF8}
if($winRecord){Write-Output "Windower settings.xml updated (supersampling / bump mapping). Do not lower supersampling to 1 in the Windower launcher: that brings the blinking back."}
Write-Output "Installed. Backup: $backupDir"
Write-Output 'Select FFXI-Clarity.ini in ReShade for the first check. Existing presets remain available. Run Test.cmd before launching FFXI.'
ReportLightingPack
