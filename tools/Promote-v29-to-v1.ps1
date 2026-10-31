# QuickBridge v1.0.0 alias for a user who already installed the working v2.9 lab.
# Creates ONLY quickbridge.schema.yaml. Never overwrites v2.9, dictionaries or settings.
[CmdletBinding()]
param([ValidateSet('Check','Stage')][string]$Mode='Check')
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$base=Split-Path -Parent $PSScriptRoot
$source=Join-Path $base 'quickbridge.schema.yaml'
$rime=Join-Path $env:APPDATA 'Rime'
$dest=Join-Path $rime 'quickbridge.schema.yaml'
$old=Join-Path $rime 'qb_quick_human_v29_lab.schema.yaml'
if(-not(Test-Path -LiteralPath $old -PathType Leaf)){throw "Missing validated v2.9 schema: $old"}
foreach($rel in @('qb_quick.dict.yaml','qb_predict_zht_lab.db',
 'lua\quickbridge_processor_v29.lua','lua\quickbridge_prediction_guard_v21.lua',
 'lua\quickbridge_openvanilla_filter_v21.lua','lua\quickbridge_openvanilla_assoc_v21.lua')){
 $f=Join-Path $rime $rel
 if(-not(Test-Path -LiteralPath $f -PathType Leaf)){throw "Missing existing v2.9 dependency: $f"}
}
$manifest=Get-Content -LiteralPath (Join-Path $base 'SHA256SUMS.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$want=[string]$manifest.PSObject.Properties['quickbridge.schema.yaml'].Value
$sha=(Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash.ToUpperInvariant()
if($want -cne $sha){throw 'Public v1.0 schema hash mismatch; stop.'}
if(Test-Path -LiteralPath $dest){
 $existing=(Get-FileHash -LiteralPath $dest -Algorithm SHA256).Hash.ToUpperInvariant()
 if($want -cne $existing){throw "Existing v1.0 path differs; refusing overwrite: $dest"}
 Write-Host 'ALIAS ALREADY PRESENT; no changes.';exit 0
}
if($Mode -eq 'Check'){Write-Host 'CHECK PASS: v2.9 is present; can add one new v1.0 alias schema. Nothing changed.';exit 0}
if((Read-Host 'Type QB-PROMOTE-1 to add the v1.0 schema') -cne 'QB-PROMOTE-1'){Write-Host 'CANCELLED';exit 0}
[IO.File]::Copy($source,$dest,$false)
if((Get-FileHash -LiteralPath $dest -Algorithm SHA256).Hash.ToUpperInvariant() -cne $want){
 Remove-Item -LiteralPath $dest -Force;throw 'Installed v1.0 alias hash mismatch'
}
Write-Host 'STAGE PASS: added only quickbridge.schema.yaml. Enable QuickBridge and redeploy Weasel.'
