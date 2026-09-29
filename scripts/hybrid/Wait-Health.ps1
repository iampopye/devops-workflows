[CmdletBinding()]
param(
    [Parameter(Mandatory)][uri]$Uri,
    [Parameter(Mandatory)][string]$ExpectedVersion,
    [ValidateRange(1,120)][int]$Attempts=30,
    [ValidateRange(1,60)][int]$IntervalSeconds=5
)
$ErrorActionPreference='Stop'
if ($Uri.Scheme -ne 'https') { throw 'Health endpoint must use verified HTTPS' }
$consecutive=0
for ($i=0; $i -lt $Attempts; $i++) {
    try {
        $r=Invoke-WebRequest -Uri $Uri -TimeoutSec 10 -MaximumRedirection 0
        $body=$r.Content | ConvertFrom-Json
        if ($r.StatusCode -eq 200 -and $body.status -ceq 'Healthy' -and $body.version -ceq $ExpectedVersion) { $consecutive++ } else { $consecutive=0 }
        if ($consecutive -ge 3) { return }
    } catch { $consecutive=0 }
    Start-Sleep -Seconds $IntervalSeconds
}
throw "Readiness failed for $Uri at version $ExpectedVersion"
