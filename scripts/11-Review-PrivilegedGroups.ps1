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

$groups = @("SG-ENTRA-Global-Admins","SG-ENTRA-BreakGlass","SG-ENTRA-Helpdesk","SG-ENTRA-ConditionalAccess-Exclusions")
foreach ($groupName in $groups) {
    $group = Get-GraphObjectByDisplayName -Collection "groups" -DisplayName $groupName
    if (-not $group) {
        Write-Warning "Missing privileged group: $groupName"
        continue
    }

    $members = Get-GraphCollectionAll -Uri "/v1.0/groups/$($group.id)/members?`$select=id,displayName,userPrincipalName"
    Write-Host "Group: $groupName"
    foreach ($member in $members) {
        $label = $member.userPrincipalName
        if ([string]::IsNullOrWhiteSpace($label)) {
            $label = $member.displayName
        }
        Write-Host ("  - {0}" -f $label)
    }
}
