param(
    [switch]$InstallMissing,
    [string[]]$Modules = @(
        "Microsoft.Graph.Authentication",
        "Microsoft.Graph",
        "Microsoft.Entra",
        "ExchangeOnlineManagement"
    )
)

. (Join-Path (Split-Path $PSScriptRoot -Parent) "shared\EntraBootstrap.Common.ps1")

foreach ($moduleName in $Modules) {
    Ensure-Module -Name $moduleName -InstallMissing:$InstallMissing
    Write-Host "Ready: $moduleName"
}

Write-Host "Prerequisites checked. If you passed -InstallMissing, missing modules were installed."
