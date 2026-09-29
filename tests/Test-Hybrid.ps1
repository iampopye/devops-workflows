$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root=Split-Path $PSScriptRoot -Parent
$tmp=Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
New-Item $tmp -ItemType Directory | Out-Null
function Assert([bool]$Condition,[string]$Message) { if (-not $Condition) { throw $Message } }
try {
    New-Item "$tmp/release", "$tmp/payload" -ItemType Directory | Out-Null
    'test' | Set-Content "$tmp/payload/file.txt"
    Compress-Archive "$tmp/payload/*" "$tmp/release/application.zip"
    @{schemaVersion=1;version='1.1';commit=('a'*40);file='application.zip';sha256=(Get-FileHash "$tmp/release/application.zip").Hash} | ConvertTo-Json | Set-Content "$tmp/release/manifest.json"
    $m=& "$root/scripts/hybrid/Test-Package.ps1" "$tmp/release"
    Assert ($m.version -eq '1.1') 'Valid package rejected'
    @{nodes=@('iis1','iis2','iis3')} | ConvertTo-Json | Set-Content "$tmp/inventory.json"
    @'
param($Action,$Inventory,$ReleaseDirectory,$Manifest,$State,$Node)
Add-Content $env:TEST_LOG "$Action/$Node"
if ($Action -eq $env:FAIL_ACTION) { throw 'Injected failure' }
if ($Action -eq 'Inspect') { return @{activeColour='blue';previousVersion='0.1';snapshotId='test-snapshot'} }
'@ | Set-Content "$tmp/adapter.ps1"
    $env:TEST_LOG="$tmp/actions.log"
    foreach ($scenario in @('success','VerifyInactive','SwitchTraffic','VerifyProduction','DrainPrevious')) {
        Remove-Item $env:TEST_LOG -ErrorAction SilentlyContinue
        $env:FAIL_ACTION=if ($scenario -eq 'success') { '' } else { $scenario }
        $failed=$false
        try { & "$root/scripts/hybrid/Invoke-IisRelease.ps1" "$tmp/release" "$tmp/inventory.json" "$tmp/adapter.ps1" | Out-Null } catch { $failed=$true }
        $log=@(Get-Content $env:TEST_LOG)
        if ($scenario -eq 'success') {
            Assert (-not $failed) 'Success scenario failed'
            Assert (@($log | Where-Object { $_ -like 'PrepareInactive/*' }).Count -eq 3) 'All three nodes must be prepared'
            Assert (@($log | Where-Object { $_ -like 'ExpandDatabase/*' }).Count -eq 1) 'Migration must run once'
            Assert (-not ($log -contains 'RestoreTraffic/')) 'Unexpected rollback'
        } elseif ($scenario -eq 'VerifyInactive') {
            Assert $failed 'Unhealthy inactive node must fail'
            Assert (-not ($log -contains 'SwitchTraffic/')) 'Traffic switched before readiness'
        } else {
            Assert $failed 'Release failure must propagate'
            Assert ($log -contains 'RestoreTraffic/') 'Ambiguous/failed switch must restore'
            Assert ($log -contains 'VerifyRollback/') 'Rollback must be validated'
        }
        Write-Output "PASS: $scenario"
    }
    Add-Content "$tmp/release/application.zip" 'tampering'
    $rejected=$false
    try { & "$root/scripts/hybrid/Test-Package.ps1" "$tmp/release" | Out-Null } catch { $rejected=$true }
    Assert $rejected 'Corrupt artifact accepted'
    Write-Output 'PASS: corrupt artifact rejected'
    $parseErrors=@()
    Get-ChildItem "$root/scripts","$root/tests","$root/examples/platform" -Filter *.ps1 -Recurse | ForEach-Object {
        $tokens=$null; $errors=$null
        [System.Management.Automation.Language.Parser]::ParseFile($_.FullName,[ref]$tokens,[ref]$errors) | Out-Null
        $parseErrors+=@($errors)
    }
    Assert ($parseErrors.Count -eq 0) "PowerShell parse errors: $parseErrors"
    Write-Output 'PASS: PowerShell syntax'
} finally {
    Remove-Item $tmp -Recurse -Force
    Remove-Item Env:TEST_LOG,Env:FAIL_ACTION -ErrorAction SilentlyContinue
}
