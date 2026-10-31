# QuickBridge v1.0.0 public release -- user-local install; never changes global IME config.
# Check: no network, no writes. Install: explicit consent, pinned-source downloads.
[CmdletBinding()]
param([ValidateSet('Check','Install')][string]$Mode='Check')
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$base=Split-Path -Parent $PSScriptRoot
$rime=Join-Path $env:APPDATA 'Rime'
$lua=Join-Path $rime 'lua'
$predictUrl='https://raw.githubusercontent.com/kenspc/rime-predict-zh/main/dist/predict-zht.db'
$predictBlob='e0a0e92bff6690a7f630a6fd5f09b674d83526b0'
$assocUrl='https://raw.githubusercontent.com/hoho97/openvanilla-kai/68ea31b643ee7e72c9b19a2a08be83a40db9d522/DataTables/associated-phrases.cin'
$assocBlob='cff9bbba57f7b5858066c8b52ccf66f4d21717c2'
$assocBytes=407157
function Assert-PlainFolder([string]$p) {
  if(-not(Test-Path -LiteralPath $p -PathType Container)){throw "Missing Rime folder: $p (install Weasel first)"}
  if(((Get-Item -LiteralPath $p -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0){throw "Refuse linked folder: $p"}
}
function Assert-PlainFile([string]$p) {
  if(-not(Test-Path -LiteralPath $p -PathType Leaf)){throw "Missing source file: $p"}
  if(((Get-Item -LiteralPath $p -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0){throw "Refuse linked file: $p"}
}
function SHA256([string]$p){(Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash.ToUpperInvariant()}
function Blob-Sha([byte[]]$bytes){
  [byte[]]$prefix=[Text.Encoding]::ASCII.GetBytes("blob $($bytes.Length)`0")
  [byte[]]$all=[byte[]]::new($prefix.Length+$bytes.Length)
  [Array]::Copy($prefix,0,$all,0,$prefix.Length)
  [Array]::Copy($bytes,0,$all,$prefix.Length,$bytes.Length)
  $hasher=[Security.Cryptography.SHA1]::Create()
  try{return ([BitConverter]::ToString($hasher.ComputeHash($all))).Replace('-','').ToLowerInvariant()}
  finally{$hasher.Dispose()}
}
function LuaQuoted([string]$s){'"'+$s.Replace('\','\\').Replace('"','\"')+'"'}
Assert-PlainFolder $rime
$files=@(
  @{From='quickbridge.schema.yaml';To='quickbridge.schema.yaml'},
  @{From='qb_quick.dict.yaml';To='qb_quick.dict.yaml'},
  @{From='lua/quickbridge_processor_v29.lua';To='lua/quickbridge_processor_v29.lua'},
  @{From='lua/quickbridge_prediction_guard_v21.lua';To='lua/quickbridge_prediction_guard_v21.lua'},
  @{From='lua/quickbridge_openvanilla_filter_v21.lua';To='lua/quickbridge_openvanilla_filter_v21.lua'}
)
$manifestPath=Join-Path $base 'SHA256SUMS.json'
Assert-PlainFile $manifestPath
$manifest=Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
$pending=New-Object 'System.Collections.Generic.List[Object]'
foreach($i in $files){
  $s=Join-Path $base ($i.From.Replace('/','\'))
  $t=Join-Path $rime ($i.To.Replace('/','\'))
  Assert-PlainFile $s
  $item=$manifest.PSObject.Properties[$i.From]
  if($null -eq $item){throw "Manifest lacks $($i.From)"}
  $want=[string]$item.Value
  if((SHA256 $s) -cne $want){throw "SHA256 mismatch: $($i.From)"}
  if(Test-Path -LiteralPath $t){
    Assert-PlainFile $t
    if((SHA256 $t) -cne $want){throw "Existing different file at $t; refusing overwrite. Install in clean Rime user profile or keep existing version."}
  } else {$pending.Add(@{Src=$s;Dest=$t;Expected=$want})}
}
$predDest=Join-Path $rime 'qb_predict_zht_lab.db'
$assocDest=Join-Path $lua 'quickbridge_openvanilla_assoc_v21.lua'
foreach($p in @($predDest,$assocDest)){
 if(Test-Path -LiteralPath $p){Assert-PlainFile $p}
}
if($Mode -eq 'Check'){
 Write-Host 'CHECK PASS: sources verified; no downloads, no file writes.'
 Write-Host "New files pending: $($pending.Count); prediction data may be downloaded if missing."
 Write-Host 'The shared predictor / association data are downloaded only during Install.'
 exit 0
}
Write-Host 'QuickBridge v1.0 uses third-party prediction data (GPL-3.0) and historical OpenVanilla associations.'
Write-Host 'Source data downloaded only if missing. No registry, default.custom.yaml, Weasel theme or other schemes changed.'
if((Read-Host 'Type QB-INSTALL-1 to install') -cne 'QB-INSTALL-1'){Write-Host 'CANCELLED';exit 0}
[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
$client=New-Object Net.WebClient
[byte[]]$predBytes=@()
[byte[]]$assocData=@()
try{
  if(-not(Test-Path -LiteralPath $predDest)){
    [byte[]]$predBytes=$client.DownloadData($predictUrl)
    if($predBytes.Length -lt 100000 -or $predBytes.Length -gt 2000000){throw 'Unexpected predictor DB byte length'}
    if((Blob-Sha $predBytes) -cne $predictBlob){throw 'Predictor Git blob hash mismatch'}
    if([Text.Encoding]::ASCII.GetString($predBytes,0,17) -cne 'Rime::Predict/1.0'){throw 'Predictor DB header invalid'}
  }
  if(-not(Test-Path -LiteralPath $assocDest)){
    [byte[]]$assocData=$client.DownloadData($assocUrl)
    if($assocData.Length -ne $assocBytes -or (Blob-Sha $assocData) -cne $assocBlob){throw 'Association source hash / size mismatch'}
  }
}finally{$client.Dispose()}
# Parse and verify association data before touching destination.
[byte[]]$assocLuaBytes=@()
if($assocData.Length -gt 0){
  $utf8=[Text.UTF8Encoding]::new($false,$true)
  $txt=$utf8.GetString($assocData)
  $lists=@{};$inside=$false;$ended=$false;$rows=0
  foreach($line in ($txt -split '\r?\n')){
    if($line -ceq '%chardef begin'){$inside=$true;continue}
    if($line -ceq '%chardef end'){$ended=$true;break}
    if(-not $inside -or $line.Length -eq 0 -or $line.StartsWith('#')){continue}
    if($line -cnotmatch '^(\S+)\s+(\S+)\s*$'){throw "Malformed association line at row $rows"}
    $head=$Matches[1];$suffix=$Matches[2]
    if(-not $lists.ContainsKey($head)){$lists[$head]=New-Object 'System.Collections.Generic.List[string]'}
    $lists[$head].Add($suffix);$rows++
  }
  if(-not $ended -or $rows -ne 44572 -or $lists.Count -ne 4017){throw "Unexpected source shape rows=$rows heads=$($lists.Count)"}
  $ref=Get-Content -LiteralPath (Join-Path $base 'data/windows11_first_page_51_reference.json') -Raw -Encoding UTF8 | ConvertFrom-Json
  $heads=0;$positions=0
  foreach($p in $ref.PSObject.Properties){
    if(-not $lists.ContainsKey([string]$p.Name)){throw "Reference head missing $($p.Name)"}
    $refList=@($p.Value)
    for($j=0;$j -lt $refList.Count;$j++){
      if($j -ge $lists[$p.Name].Count -or $lists[$p.Name][$j] -cne [string]$refList[$j]){throw "Reference order differs for $($p.Name) rank=$($j+1)"}
      $positions++
    }
    $heads++
  }
  if($heads -ne 51 -or $positions -ne 442){throw "Reference count mismatch $heads/$positions"}
  $builder=[Text.StringBuilder]::new()
  [void]$builder.AppendLine('-- Historical OpenVanilla association data; see THIRD_PARTY_NOTICES.md')
  [void]$builder.AppendLine('return {')
  foreach($head in ($lists.Keys | Sort-Object)){
    [void]$builder.Append('  [');[void]$builder.Append((LuaQuoted $head));[void]$builder.Append('] = {')
    foreach($suffix in $lists[$head]){[void]$builder.Append((LuaQuoted $suffix));[void]$builder.Append(',')}
    [void]$builder.AppendLine('},')
  }
  [void]$builder.AppendLine('}')
  $assocLuaBytes=$utf8.GetBytes($builder.ToString())
  Write-Host 'SOURCE VERIFIED: 44,572 associations, 4,017 heads, Windows observations 442/442.'
}
# Re-check for conflicts; only create absent files and roll back THIS run's new files.
$created=New-Object 'System.Collections.Generic.List[string]'
try{
  if(-not(Test-Path -LiteralPath $lua)){New-Item -ItemType Directory -Path $lua -ErrorAction Stop | Out-Null}
  Assert-PlainFolder $lua
  foreach($p in $pending){
    [IO.File]::Copy([string]$p.Src,[string]$p.Dest,$false)
    $created.Add([string]$p.Dest)
    if((SHA256 ([string]$p.Dest)) -cne ([string]$p.Expected)){throw "Post-copy hash mismatch $($p.Dest)"}
  }
  if($predBytes.Length -gt 0){
    $fp=[IO.File]::Open($predDest,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
    try{$created.Add($predDest);$fp.Write($predBytes,0,$predBytes.Length)}finally{$fp.Dispose()}
    if((Blob-Sha ([IO.File]::ReadAllBytes($predDest))) -cne $predictBlob){throw 'Predictor post-copy hash mismatch'}
  }
  if($assocLuaBytes.Length -gt 0){
    $fa=[IO.File]::Open($assocDest,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
    try{$created.Add($assocDest);$fa.Write($assocLuaBytes,0,$assocLuaBytes.Length)}finally{$fa.Dispose()}
  }
  Write-Host 'INSTALL PASS: QuickBridge v1.0.0 scheme installed with verified data.'
  Write-Host 'Now use Weasel Input Method Settings to enable "速橋 QuickBridge", then Redeploy.'
}catch{
  foreach($p in $created){if(Test-Path -LiteralPath $p -PathType Leaf){Remove-Item -LiteralPath $p -Force -ErrorAction SilentlyContinue}}
  throw
}
