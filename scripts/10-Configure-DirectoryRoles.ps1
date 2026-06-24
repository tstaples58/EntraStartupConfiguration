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

if (-not $config.directoryRoleAssignments -or @($config.directoryRoleAssignments).Count -eq 0) {
    Write-Host "No directoryRoleAssignments configured. Skipping role configuration."
    return
}

foreach ($assignment in @($config.directoryRoleAssignments)) {
    $roleDef = Get-GraphObjectByDisplayName -Collection "roleManagement/directory/roleDefinitions" -DisplayName $assignment.roleDisplayName
    if (-not $roleDef) {
        Write-Warning "Role definition not found: $($assignment.roleDisplayName)"
        continue
    }

    $principal = $null
    $principalRoleAssignableGroupDisplayName = Get-OptionalObjectPropertyValue -Object $assignment -PropertyName "principalRoleAssignableGroupDisplayName"
    $principalGroupDisplayName = Get-OptionalObjectPropertyValue -Object $assignment -PropertyName "principalGroupDisplayName"
    $principalUserPrincipalName = Get-OptionalObjectPropertyValue -Object $assignment -PropertyName "principalUserPrincipalName"

    if ($principalRoleAssignableGroupDisplayName) {
        $principal = Get-GraphObjectByDisplayName -Collection "groups" -DisplayName $principalRoleAssignableGroupDisplayName
        if ($principal -and $principal.isAssignableToRole -ne $true) {
            Write-Warning "Group '$principalRoleAssignableGroupDisplayName' exists but is not role-assignable. Create it with 10-Create-RoleAssignableGroups.ps1."
            continue
        }
    }
    if ($principalGroupDisplayName) {
        $principal = Get-GraphObjectByDisplayName -Collection "groups" -DisplayName $principalGroupDisplayName
    }
    elseif ($principalUserPrincipalName) {
        $principal = Get-GraphObjectByDisplayName -Collection "users" -DisplayName $principalUserPrincipalName -FilterProperty "userPrincipalName"
    }

    if (-not $principal) {
        Write-Warning "Principal not found for role $($assignment.roleDisplayName)"
        continue
    }

    $scopeId = $assignment.directoryScopeId
    if ([string]::IsNullOrWhiteSpace($scopeId)) {
        $scopeId = "/"
    }

    $existing = Get-GraphCollectionAll -Uri "/v1.0/roleManagement/directory/roleAssignments?`$filter=principalId eq '$($principal.id)'"
    if ($existing | Where-Object { $_.roleDefinitionId -eq $roleDef.id -and $_.directoryScopeId -eq $scopeId }) {
        Write-Host "Already assigned role: $($assignment.roleDisplayName) -> $($principal.displayName)"
        continue
    }

    Invoke-GraphRequestJson -Method POST -Uri "/v1.0/roleManagement/directory/roleAssignments" -Body @{
        "@odata.type"    = "#microsoft.graph.unifiedRoleAssignment"
        roleDefinitionId = $roleDef.id
        principalId      = $principal.id
        directoryScopeId = $scopeId
    } | Out-Null

    Write-Host "Assigned role: $($assignment.roleDisplayName) -> $($principal.displayName)"
}
