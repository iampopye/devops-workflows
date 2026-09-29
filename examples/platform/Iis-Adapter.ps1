# Implement this contract for your ARR/F5/NetScaler API and WinRM configuration.
# This stub deliberately cannot deploy or switch traffic.
[CmdletBinding()]
param(
    [ValidateSet('Inspect','Preflight','PrepareInactive','VerifyInactive','ExpandDatabase','SwitchTraffic','VerifyProduction','DrainPrevious','RestoreTraffic','VerifyRollback')][string]$Action,
    [object]$Inventory, [string]$ReleaseDirectory, [object]$Manifest, [object]$State, [string]$Node
)
throw "Implement and integration-test adapter action '$Action' before enabling IIS delivery. See docs/platform/iis-operations.md."
