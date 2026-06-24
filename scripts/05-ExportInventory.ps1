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

$tenant = Invoke-GraphRequestJson -Method GET -Uri "/v1.0/organization"
$domains = Get-GraphCollectionAll -Uri "/v1.0/domains"
$users = Get-GraphCollectionAll -Uri "/v1.0/users?`$select=id,displayName,userPrincipalName,accountEnabled,userType"
$groups = Get-GraphCollectionAll -Uri "/v1.0/groups?`$select=id,displayName,mailNickname,securityEnabled,mailEnabled"
$servicePrincipals = Get-GraphCollectionAll -Uri "/v1.0/servicePrincipals?`$select=id,appId,displayName,servicePrincipalType"
$applications = Get-GraphCollectionAll -Uri "/v1.0/applications?`$select=id,appId,displayName,signInAudience"

$tenant | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $outputPath "tenant.json")
$domains | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $outputPath "domains.json")
$users | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $outputPath "users.json")
$groups | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $outputPath "groups.json")
$servicePrincipals | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $outputPath "servicePrincipals.json")
$applications | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $outputPath "applications.json")

$groups | Export-Csv -NoTypeInformation -LiteralPath (Join-Path $outputPath "groups.csv")
$users | Export-Csv -NoTypeInformation -LiteralPath (Join-Path $outputPath "users.csv")

Write-Host "Inventory exported to $outputPath"
