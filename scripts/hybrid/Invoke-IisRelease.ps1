[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ReleaseDirectory,
    [Parameter(Mandatory)][string]$InventoryPath,
    [Parameter(Mandatory)][string]$AdapterPath
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$m=& "$PSScriptRoot/Test-Package.ps1" -ReleaseDirectory $ReleaseDirectory
$inventory=Get-Content $InventoryPath -Raw | ConvertFrom-Json
if (@($inventory.nodes).Count -lt 2) { throw 'Require at least two IIS nodes' }
if (@($inventory.nodes | Select-Object -Unique).Count -ne @($inventory.nodes).Count) { throw 'Duplicate nodes' }
# Adapter is trusted reviewed code from the protected caller commit, not from the artifact.
$adapter=(Resolve-Path $AdapterPath).Path
function Invoke-Adapter([string]$Action, [object]$State, [string]$Node='') {
    & $adapter -Action $Action -Inventory $inventory -ReleaseDirectory (Resolve-Path $ReleaseDirectory).Path -Manifest $m -State $State -Node $Node
    if (-not $?) { throw "Adapter failed: $Action" }
}
$state=Invoke-Adapter 'Inspect' $null
if ($state.activeColour -notin @('blue','green') -or -not $state.previousVersion -or -not $state.snapshotId) { throw 'Adapter must return authoritative LB state and durable snapshot' }
# Confirm inactive colour receives no traffic, enough capacity, valid certs/runtime, and deployment lock.
Invoke-Adapter 'Preflight' $state | Out-Null
foreach ($node in $inventory.nodes) {
    Invoke-Adapter 'PrepareInactive' $state $node | Out-Null
    Invoke-Adapter 'VerifyInactive' $state $node | Out-Null
}
# Exactly once per release, outside the node loop. No automatic destructive DB rollback.
Invoke-Adapter 'ExpandDatabase' $state | Out-Null
foreach ($node in $inventory.nodes) { Invoke-Adapter 'VerifyInactive' $state $node | Out-Null }
$mayHaveSwitched=$false
try {
    # Set before call: a timeout may mean that the LB accepted the mutation.
    $mayHaveSwitched=$true
    Invoke-Adapter 'SwitchTraffic' $state | Out-Null
    Invoke-Adapter 'VerifyProduction' $state | Out-Null
    # Drains old connections without stopping sites. Retain old colour for rollback.
    Invoke-Adapter 'DrainPrevious' $state | Out-Null
} catch {
    $failure=$_
    if ($mayHaveSwitched) {
        try {
            Invoke-Adapter 'RestoreTraffic' $state | Out-Null
            Invoke-Adapter 'VerifyRollback' $state | Out-Null
        } catch { throw "Release and rollback failed; use durable LB snapshot $($state.snapshotId). Original failure: $failure. Rollback: $_" }
    }
    throw $failure
}
Write-Output "Released version $($m.version); keep previous colour and DB compatibility until rollback window closes."
