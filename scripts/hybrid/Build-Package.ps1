[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Project,
    [Parameter(Mandatory)][string]$TestProject,
    [Parameter(Mandatory)][string]$SpaDirectory,
    [string]$SpaOutput = 'dist',
    [Parameter(Mandatory)][string]$Version,
    [Parameter(Mandatory)][string]$Commit
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
function Invoke-Native([scriptblock]$Command) {
    & $Command
    if ($LASTEXITCODE -ne 0) { throw "Build command failed: $LASTEXITCODE" }
}
if (Test-Path release) { throw 'release/ must not exist; build in a clean workspace' }
New-Item release, .publish -ItemType Directory -ErrorAction Stop | Out-Null
# Consumer commits NuGet packages.lock.json and npm package-lock.json.
Invoke-Native { dotnet restore $Project --locked-mode }
Invoke-Native { dotnet restore $TestProject --locked-mode }
Invoke-Native { dotnet test $TestProject -c Release --no-restore }
Push-Location $SpaDirectory
try {
    Invoke-Native { npm ci }
    Invoke-Native { npm run test:ci }
    Invoke-Native { npm run build }
} finally { Pop-Location }
Invoke-Native { dotnet publish $Project -c Release --no-restore --self-contained false -o .publish }
if (-not (Test-Path .publish/web.config)) { throw 'Expected ASP.NET Core IIS publish output' }
# Contract: ASP.NET Core serves SPA via UseStaticFiles + MapFallbackToFile.
New-Item .publish/wwwroot -ItemType Directory -Force | Out-Null
Copy-Item (Join-Path $SpaDirectory "$SpaOutput/*") .publish/wwwroot -Recurse -Force
@{ version=$Version; commit=$Commit } | ConvertTo-Json | Set-Content .publish/release.json -Encoding utf8
# appsettings files contain defaults only. Never bake server secrets into this package.
Compress-Archive -Path .publish/* -DestinationPath release/application.zip
@{ schemaVersion=1; version=$Version; commit=$Commit; file='application.zip'; sha256=(Get-FileHash release/application.zip -Algorithm SHA256).Hash.ToLower() } |
    ConvertTo-Json | Set-Content release/manifest.json -Encoding utf8
