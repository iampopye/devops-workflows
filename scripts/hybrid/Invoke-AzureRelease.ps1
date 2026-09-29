[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ReleaseDirectory,
    [Parameter(Mandatory)][string]$ResourceGroup,
    [Parameter(Mandatory)][string]$AppName,
    [string]$Slot='staging'
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
if ($Slot -eq 'production' -or $Slot -notmatch '^[a-zA-Z0-9-]+$') { throw 'Use an existing non-production slot' }
function Invoke-Az([string[]]$Arguments) {
    $result=& az @Arguments --only-show-errors
    if ($LASTEXITCODE -ne 0) { throw 'Azure CLI command failed; inspect Azure activity log' }
    return $result
}
$m=& "$PSScriptRoot/Test-Package.ps1" -ReleaseDirectory $ReleaseDirectory
$prod=(Invoke-Az @('webapp','show','-g',$ResourceGroup,'-n',$AppName,'--query','defaultHostName','-o','tsv')).Trim()
$stage=(Invoke-Az @('webapp','show','-g',$ResourceGroup,'-n',$AppName,'--slot',$Slot,'--query','defaultHostName','-o','tsv')).Trim()
# First bootstrap must be done explicitly; release requires a healthy rollback target.
$previous=Invoke-RestMethod "https://$prod/health/ready" -TimeoutSec 10
if ($previous.status -cne 'Healthy' -or -not $previous.version) { throw 'Production must be healthy before release' }
# Configuration and Key Vault references are pre-provisioned slot settings via IaC.
# DB expand migrations must already be approved/applied by the caller's migration job.
Invoke-Az @('webapp','deploy','-g',$ResourceGroup,'-n',$AppName,'--slot',$Slot,'--src-path',(Join-Path $ReleaseDirectory application.zip),'--type','zip') | Out-Null
& "$PSScriptRoot/Wait-Health.ps1" -Uri "https://$stage/health/ready" -ExpectedVersion $m.version
# A failed swap command is ambiguous: do not blindly swap back and accidentally promote bad code.
Invoke-Az @('webapp','deployment','slot','swap','-g',$ResourceGroup,'-n',$AppName,'--slot',$Slot,'--target-slot','production') | Out-Null
try {
    & "$PSScriptRoot/Wait-Health.ps1" -Uri "https://$prod/health/ready" -ExpectedVersion $m.version
} catch {
    $failure=$_
    Invoke-Az @('webapp','deployment','slot','swap','-g',$ResourceGroup,'-n',$AppName,'--slot',$Slot,'--target-slot','production') | Out-Null
    & "$PSScriptRoot/Wait-Health.ps1" -Uri "https://$prod/health/ready" -ExpectedVersion $previous.version
    throw "Production validation failed; previous version restored. $failure"
}
