param(
    [string]$ConfigPath = (Join-Path (Split-Path $PSScriptRoot -Parent) "config\tenant.sample.json"),
    [switch]$SkipPermissions
)

& (Join-Path $PSScriptRoot "01-Connect-Entra.ps1") -ConfigPath $ConfigPath
& (Join-Path $PSScriptRoot "02-Ensure-BaselineObjects.ps1") -ConfigPath $ConfigPath
& (Join-Path $PSScriptRoot "03-NewAutomationApp.ps1") -ConfigPath $ConfigPath

if (-not $SkipPermissions) {
    & (Join-Path $PSScriptRoot "04-GrantGraphPermissions.ps1") -ConfigPath $ConfigPath
}

& (Join-Path $PSScriptRoot "05-ExportInventory.ps1") -ConfigPath $ConfigPath

Write-Host "Entra bootstrap workflow finished."
