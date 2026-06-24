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

$root = Get-EntraBootstrapRoot
$outputPath = Ensure-OutputDirectory -Path (Join-Path $root $config.reportOutputPath)

$roleAssignments = Get-GraphCollectionAll -Uri "/v1.0/roleManagement/directory/roleAssignments?`$expand=principal,roleDefinition"
$roleDefinitions = Get-GraphCollectionAll -Uri "/v1.0/roleManagement/directory/roleDefinitions"

$roleAssignments | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $outputPath "roleAssignments.json")
$roleDefinitions | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $outputPath "roleDefinitions.json")
$roleAssignments | Export-Csv -NoTypeInformation -LiteralPath (Join-Path $outputPath "roleAssignments.csv")

Write-Host "Role assignment export complete: $outputPath"
