# Run on the Windows host through authenticated WinRM or local administration.
# Provisioning only: load-balancer membership is managed by the adapter.
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)][ValidatePattern('^[A-Za-z0-9_-]+$')][string]$SiteName,
    [Parameter(Mandatory)][string]$PhysicalPath,
    [Parameter(Mandatory)][string]$HostName,
    [Parameter(Mandatory)][ValidatePattern('^[A-Fa-f0-9]{40}$')][string]$CertificateThumbprint,
    [ValidateRange(1,65535)][int]$Port=443
)
$ErrorActionPreference='Stop'
Import-Module WebAdministration
$path=(Resolve-Path $PhysicalPath).Path
$cert=Get-Item "Cert:\LocalMachine\My\$CertificateThumbprint"
if (-not $cert.HasPrivateKey -or $cert.NotAfter -lt (Get-Date).AddDays(7)) { throw 'Certificate missing private key or expiring' }
if (-not (Get-WebGlobalModule | Where-Object Name -eq 'AspNetCoreModuleV2')) { throw 'Install/repair approved .NET 10 Hosting Bundle after IIS installation' }
if (-not (Test-Path "$path/web.config")) { throw 'Missing publish-generated web.config' }
if (Test-Path "IIS:\Sites\$SiteName") { throw 'Site already exists; use a reviewed configuration update, never overwrite an active site' }
if (Test-Path "IIS:\AppPools\$SiteName") { throw 'App pool already exists; choose a fresh inactive-site name' }
if ($PSCmdlet.ShouldProcess($SiteName,'Create isolated inactive IIS site and app pool')) {
    New-WebAppPool -Name $SiteName | Out-Null
    Set-ItemProperty "IIS:\AppPools\$SiteName" -Name managedRuntimeVersion -Value ''
    Set-ItemProperty "IIS:\AppPools\$SiteName" -Name startMode -Value AlwaysRunning
    Set-ItemProperty "IIS:\AppPools\$SiteName" -Name processModel.idleTimeout -Value ([TimeSpan]::Zero)
    New-Website -Name $SiteName -PhysicalPath $path -ApplicationPool $SiteName -Port $Port -HostHeader $HostName -Ssl -SslFlags 1 | Out-Null
    $binding=Get-WebBinding -Name $SiteName -Protocol https -Port $Port -HostHeader $HostName
    $binding.AddSslCertificate($CertificateThumbprint,'My')
    Start-Website $SiteName
}
# Ensure read/execute ACL for IIS AppPool\<SiteName>; grant write only to external data/log directories.
# Validate hostname/SAN trust, HTTPS readiness and runtime version before LB registration.
