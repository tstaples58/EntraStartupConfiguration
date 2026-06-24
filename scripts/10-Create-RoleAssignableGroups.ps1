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

$licenseTier = Get-EntraBootstrapLicenseTier -Config $config
if ((Get-EntraBootstrapCapabilities -LicenseTier $licenseTier).SupportsRoleAssignableGroups -ne $true) {
    Write-Host "Skipping role-assignable group creation because the tenant is on the free tier."
    return
}

if (-not $config.roleAssignableGroups -or @($config.roleAssignableGroups).Count -eq 0) {
    Write-Host "No roleAssignableGroups configured. Skipping role-assignable group creation."
    return
}

foreach ($group in @($config.roleAssignableGroups)) {
    $existing = Get-GraphObjectByDisplayName -Collection "groups" -DisplayName $group.displayName
    if ($existing) {
        if ($existing.isAssignableToRole -eq $true) {
            Write-Host "Role-assignable group already exists: $($group.displayName) ($($existing.id))"
            continue
        }

        Write-Warning "A non-role-assignable group already exists with the same name: $($group.displayName). Create a new name or remove the old group if you want role assignment."
        continue
    }

    try {
        $created = Ensure-GraphObjectByDisplayName -Collection "groups" -DisplayName $group.displayName -CreateBodyFactory {
            @{
                displayName        = $group.displayName
                description        = $group.description
                mailEnabled        = $false
                mailNickname       = $group.mailNickname
                securityEnabled    = $true
                isAssignableToRole = $true
            }
        }

        Write-Host "Created role-assignable group: $($created.displayName) ($($created.id))"
    }
    catch {
        $message = $_.Exception.Message
        if ($message -match "AAD Premium" -or $message -match "isAssignableToRole" -or $message -match "Only companies who have purchased AAD Premium") {
            Write-Warning "Skipping role-assignable group '$($group.displayName)' because this tenant cannot create role-assignable groups on the current license."
            continue
        }

        throw
    }
}
