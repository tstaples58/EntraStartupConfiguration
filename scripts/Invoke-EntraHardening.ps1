param(
    [string]$ConfigPath = (Join-Path (Split-Path $PSScriptRoot -Parent) "Config\tenant.sample.json"),
    [switch]$SkipConditionalAccess
)

& (Join-Path $PSScriptRoot "06-Create-NamedLocations.ps1") -ConfigPath $ConfigPath
& (Join-Path $PSScriptRoot "08-Validate-BreakGlass.ps1") -ConfigPath $ConfigPath

if (-not $SkipConditionalAccess) {
    & (Join-Path $PSScriptRoot "07-Create-ConditionalAccessPolicies.ps1") -ConfigPath $ConfigPath
}

& (Join-Path $PSScriptRoot "09-ExportRoleAssignments.ps1") -ConfigPath $ConfigPath

Write-Host "Entra hardening workflow finished."
