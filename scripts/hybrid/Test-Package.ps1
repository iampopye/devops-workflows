[CmdletBinding()]
param([Parameter(Mandatory)][string]$ReleaseDirectory)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$m = Get-Content (Join-Path $ReleaseDirectory manifest.json) -Raw | ConvertFrom-Json
if ($m.schemaVersion -ne 1 -or $m.file -cne 'application.zip' -or $m.sha256 -notmatch '^[a-fA-F0-9]{64}$' -or $m.version -notmatch '^[0-9]+\.[0-9]+$' -or $m.commit -notmatch '^[a-fA-F0-9]{40}$') {
    throw 'Invalid release manifest'
}
$zip = Join-Path $ReleaseDirectory application.zip
if ((Get-FileHash $zip -Algorithm SHA256).Hash -ine $m.sha256) { throw 'Artifact checksum mismatch' }
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead((Resolve-Path $zip))
try {
    foreach ($entry in $archive.Entries) {
        if ($entry.FullName -match '(^[\\/]|^[A-Za-z]:|(^|[\\/])\.\.([\\/]|$))') { throw 'Unsafe ZIP entry' }
    }
} finally { $archive.Dispose() }
$m
