param(
    [string]$ConfigPath = (Join-Path (Split-Path $PSScriptRoot -Parent) "config\tenant.sample.json"),
    [switch]$SkipConditionalAccess
)

. (Join-Path (Split-Path $PSScriptRoot -Parent) "shared\EntraBootstrap.Common.ps1")
Import-EntraPrereqs

$config = Get-EntraBootstrapConfig -Path $ConfigPath
$licenseTier = Get-EntraBootstrapLicenseTier -Config $config
$capabilities = Get-EntraBootstrapCapabilities -LicenseTier $licenseTier

Write-EntraBootstrapTierSummary -LicenseTier $licenseTier

$ranConditionalAccess = $false
$ranRoleAssignableGroups = $false
$ranDirectoryRoles = $false

& (Join-Path $PSScriptRoot "06-Create-NamedLocations.ps1") -ConfigPath $ConfigPath
& (Join-Path $PSScriptRoot "12-Preflight-Check.ps1") -ConfigPath $ConfigPath
& (Join-Path $PSScriptRoot "08-Validate-BreakGlass.ps1") -ConfigPath $ConfigPath

if ($capabilities.SupportsRoleAssignableGroups) {
    & (Join-Path $PSScriptRoot "10-Create-RoleAssignableGroups.ps1") -ConfigPath $ConfigPath
    $ranRoleAssignableGroups = $true
}
else {
    Write-Host "Skipping role-assignable group creation because the tenant is on the free tier."
}

if (-not $SkipConditionalAccess -and $capabilities.SupportsConditionalAccess) {
    & (Join-Path $PSScriptRoot "07-Create-ConditionalAccessPolicies.ps1") -ConfigPath $ConfigPath
    $ranConditionalAccess = $true
}
elseif (-not $capabilities.SupportsConditionalAccess) {
    Write-Host "Skipping Conditional Access policy creation because the tenant is on the free tier."
}

& (Join-Path $PSScriptRoot "10-Configure-DirectoryRoles.ps1") -ConfigPath $ConfigPath
$ranDirectoryRoles = $true

& (Join-Path $PSScriptRoot "09-ExportRoleAssignments.ps1") -ConfigPath $ConfigPath
& (Join-Path $PSScriptRoot "11-Review-PrivilegedGroups.ps1") -ConfigPath $ConfigPath

Write-EntraBootstrapRunSummary `
    -ConfigPath $ConfigPath `
    -LicenseTier $licenseTier `
    -RanConditionalAccess:$ranConditionalAccess `
    -RanRoleAssignableGroups:$ranRoleAssignableGroups `
    -RanDirectoryRoles:$ranDirectoryRoles

Write-Host "Entra hardening workflow finished."
