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

$displayName = $config.conditionalAccess.trustedLocationDisplayName
$ranges = @($config.trustedIpRanges)
if (-not $ranges -or $ranges.Count -eq 0) {
    Write-Host "No trusted IP ranges configured. Skipping named location creation."
    return
}

$locationBody = @{
    "@odata.type" = "#microsoft.graph.ipNamedLocation"
    displayName   = $displayName
    isTrusted     = $true
    ipRanges      = @(
        foreach ($range in $ranges) {
            @{
                "@odata.type" = "#microsoft.graph.iPv4CidrRange"
                cidrAddress   = $range
            }
        }
    )
}

$existing = Get-GraphObjectByDisplayName -Collection "identity/conditionalAccess/namedLocations" -DisplayName $displayName
if ($existing) {
    Invoke-GraphRequestJson -Method PATCH -Uri "/v1.0/identity/conditionalAccess/namedLocations/$($existing.id)" -Body $locationBody | Out-Null
    Write-Host "Updated named location: $displayName ($($existing.id))"
}
else {
    $created = Invoke-GraphRequestJson -Method POST -Uri "/v1.0/identity/conditionalAccess/namedLocations" -Body $locationBody
    Write-Host "Created named location: $($created.displayName) ($($created.id))"
}
