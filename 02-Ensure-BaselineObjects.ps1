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

Write-Host "Ensuring baseline security groups..."
foreach ($group in @($config.baselineGroups)) {
    $created = Ensure-GraphObjectByDisplayName -Collection "groups" -DisplayName $group.displayName -CreateBodyFactory {
        @{
            displayName     = $group.displayName
            description     = $group.description
            mailEnabled     = $false
            mailNickname    = $group.mailNickname
            securityEnabled = [bool]$group.securityEnabled
        }
    }
    Write-Host ("Group ready: {0} ({1})" -f $created.displayName, $created.id)
}

Write-Host "Ensuring administrative units..."
foreach ($unit in @($config.administrativeUnits)) {
    $created = Ensure-GraphObjectByDisplayName -Collection "directory/administrativeUnits" -DisplayName $unit.displayName -CreateBodyFactory {
        @{
            displayName = $unit.displayName
            description = $unit.description
        }
    }
    Write-Host ("Administrative unit ready: {0} ({1})" -f $created.displayName, $created.id)
}

Write-Host "Baseline objects complete."
