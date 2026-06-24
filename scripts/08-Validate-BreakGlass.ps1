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

$breakGlassGroup = Get-GraphObjectByDisplayName -Collection "groups" -DisplayName "SG-ENTRA-BreakGlass"
if (-not $breakGlassGroup) {
    throw "BreakGlass group not found."
}

$memberUris = Get-GraphCollectionAll -Uri "/v1.0/groups/$($breakGlassGroup.id)/members?`$select=id,displayName,userPrincipalName"
$memberMap = @{}
foreach ($member in $memberUris) {
    if ($member.userPrincipalName) {
        $memberMap[$member.userPrincipalName.ToLowerInvariant()] = $member
    }
}

if (-not $config.breakGlassAccounts -or @($config.breakGlassAccounts).Count -eq 0) {
    Write-Warning "No breakGlassAccounts configured in the config file."
    return
}

foreach ($upn in @($config.breakGlassAccounts)) {
    $user = Get-GraphObjectByDisplayName -Collection "users" -DisplayName $upn -FilterProperty "userPrincipalName"
    if (-not $user) {
        Write-Warning "Break-glass account not found: $upn"
        continue
    }

    if ($memberMap.ContainsKey($upn.ToLowerInvariant())) {
        Write-Host "Break-glass account already in group: $upn"
        continue
    }

    Invoke-GraphRequestJson -Method POST -Uri "/v1.0/groups/$($breakGlassGroup.id)/members/`$ref" -Body @{
        "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$($user.id)"
    } | Out-Null

    Write-Host "Added break-glass account to group: $upn"
}
