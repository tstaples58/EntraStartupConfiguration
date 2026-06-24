param(
    [string]$ConfigPath = (Join-Path (Split-Path $PSScriptRoot -Parent) "Config\tenant.sample.json")
)

. (Join-Path (Split-Path $PSScriptRoot -Parent) "Shared\EntraBootstrap.Common.ps1")
Import-EntraPrereqs

$config = Get-EntraBootstrapConfig -Path $ConfigPath

Connect-EntraGraphWithCertificate `
    -TenantId $config.tenantId `
    -ClientId $config.clientId `
    -CertificateThumbprint $config.certificateThumbprint `
    -CertificatePath $config.certificatePath `
    -CertificatePassword $config.certificatePassword

$context = Get-MgContext
Write-Host ("Connected to tenant {0} as application {1}" -f $context.TenantId, $context.ClientId)
