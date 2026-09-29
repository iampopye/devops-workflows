# No Azure calls: failure-injection tests for swap ambiguity and rollback behavior.
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$tmp=Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
New-Item "$tmp/release", "$tmp/payload" -ItemType Directory -Force | Out-Null
function Assert([bool]$Condition,[string]$Message) { if (-not $Condition) { throw $Message } }
function global:Start-Sleep { param($Seconds) }
function global:Invoke-RestMethod { param($Uri,$TimeoutSec) return @{status='Healthy';version='0.1'} }
function global:Invoke-WebRequest {
    param($Uri,$TimeoutSec,$MaximumRedirection)
    $version=if ($Uri -like '*stage.example*') { '1.1' } elseif ($global:swapCount -eq 1) { '1.1' } else { '0.1' }
    if ($global:scenario -eq 'unhealthy' -and $global:swapCount -eq 1 -and $Uri -like '*prod.example*') { throw 'Unhealthy production' }
    return @{StatusCode=200;Content=(@{status='Healthy';version=$version} | ConvertTo-Json)}
}
function global:az {
    $global:LASTEXITCODE=0
    if ($args -contains 'show') {
        if ($args -contains '--slot') { return 'stage.example' } else { return 'prod.example' }
    }
    if ($args -contains 'swap') {
        $global:swapCount++
        if ($global:scenario -eq 'ambiguous') { $global:LASTEXITCODE=1 }
    }
}
try {
    'test' | Set-Content "$tmp/payload/file.txt"
    Compress-Archive "$tmp/payload/*" "$tmp/release/application.zip"
    @{schemaVersion=1;version='1.1';commit=('a'*40);file='application.zip';sha256=(Get-FileHash "$tmp/release/application.zip").Hash} | ConvertTo-Json | Set-Content "$tmp/release/manifest.json"
    foreach ($case in @('success','unhealthy','ambiguous')) {
        $global:scenario=$case; $global:swapCount=0; $failed=$false
        try { & "$root/scripts/hybrid/Invoke-AzureRelease.ps1" "$tmp/release" 'test-rg' 'test-app' | Out-Null } catch { $failed=$true }
        if ($case -eq 'success') { Assert (-not $failed -and $global:swapCount -eq 1) 'Successful release must swap once' }
        if ($case -eq 'unhealthy') { Assert ($failed -and $global:swapCount -eq 2) 'Unhealthy production must swap back and fail' }
        if ($case -eq 'ambiguous') { Assert ($failed -and $global:swapCount -eq 1) 'Ambiguous swap must not blindly swap again' }
        Write-Output "PASS: Azure $case"
    }
} finally {
    Remove-Item $tmp -Recurse -Force
    Remove-Item Function:\az,Function:\Invoke-WebRequest,Function:\Invoke-RestMethod,Function:\Start-Sleep
}
