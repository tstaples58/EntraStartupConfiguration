param(
    [string]$ConfigPath = (Join-Path (Split-Path $PSScriptRoot -Parent) "config\tenant.sample.json")
)

. (Join-Path (Split-Path $PSScriptRoot -Parent) "shared\EntraBootstrap.Common.ps1")
Import-EntraPrereqs

$config = Get-EntraBootstrapConfig -Path $ConfigPath
Connect-EntraGraphWithCertificate `
    -TenantId $config.tenantId `
    -ClientId $config.clientId `
    -CertificateThumbprint $config.certificateThumbprint `
    -CertificatePath $config.certificatePath `
    -CertificatePassword $config.certificatePassword

$licenseTier = Get-EntraBootstrapLicenseTier -Config $config
$capabilities = Get-EntraBootstrapCapabilities -LicenseTier $licenseTier

Write-Host "Preflight check"
Write-EntraBootstrapTierSummary -LicenseTier $licenseTier

if ($config.trustedIpRanges -and @($config.trustedIpRanges).Count -gt 0) {
    Write-Host ("Trusted IP ranges configured: {0}" -f @($config.trustedIpRanges).Count)
}
else {
    Write-Warning "No trustedIpRanges configured."
}

if ($config.breakGlassAccounts -and @($config.breakGlassAccounts).Count -gt 0) {
    foreach ($upn in @($config.breakGlassAccounts)) {
        $user = Get-GraphObjectByDisplayName -Collection "users" -DisplayName $upn -FilterProperty "userPrincipalName"
        if (-not $user) {
            Write-Warning "Configured break-glass account not found: $upn"
        }
        else {
            Write-Host "Configured break-glass account found: $upn"
        }
    }
}
else {
    Write-Warning "No breakGlassAccounts configured."
}

if ($config.directoryRoleAssignments -and @($config.directoryRoleAssignments).Count -gt 0) {
    foreach ($assignment in @($config.directoryRoleAssignments)) {
        $principalUserPrincipalName = Get-OptionalObjectPropertyValue -Object $assignment -PropertyName "principalUserPrincipalName"
        $principalGroupDisplayName = Get-OptionalObjectPropertyValue -Object $assignment -PropertyName "principalGroupDisplayName"

        if ($principalUserPrincipalName) {
            $principal = Get-GraphObjectByDisplayName -Collection "users" -DisplayName $principalUserPrincipalName -FilterProperty "userPrincipalName"
            if (-not $principal) {
                Write-Warning "Directory role principal not found: $principalUserPrincipalName for role $($assignment.roleDisplayName)"
            }
        }
        elseif ($principalGroupDisplayName) {
            $principal = Get-GraphObjectByDisplayName -Collection "groups" -DisplayName $principalGroupDisplayName
            if (-not $principal) {
                Write-Warning "Directory role group not found: $principalGroupDisplayName for role $($assignment.roleDisplayName)"
            }
        }
    }
}

if (-not $capabilities.SupportsConditionalAccess) {
    Write-Host "Conditional Access will be skipped on this tier."
}

if (-not $capabilities.SupportsRoleAssignableGroups) {
    Write-Host "Role-assignable group creation will be skipped on this tier."
}

Write-Host "Preflight check complete."
