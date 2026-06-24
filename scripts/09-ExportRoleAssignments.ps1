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

$root = Get-EntraBootstrapRoot
$outputPath = Ensure-OutputDirectory -Path (Join-Path $root $config.reportOutputPath)

$roleAssignments = Get-GraphCollectionAll -Uri "/v1.0/roleManagement/directory/roleAssignments"
$roleDefinitions = Get-GraphCollectionAll -Uri "/v1.0/roleManagement/directory/roleDefinitions"
$users = Get-GraphCollectionAll -Uri "/v1.0/users?`$select=id,displayName,userPrincipalName"
$groups = Get-GraphCollectionAll -Uri "/v1.0/groups?`$select=id,displayName"
$servicePrincipals = Get-GraphCollectionAll -Uri "/v1.0/servicePrincipals?`$select=id,displayName,appId"

$roleDefinitionMap = @{}
foreach ($roleDefinition in $roleDefinitions) {
    $roleDefinitionMap[$roleDefinition.id] = $roleDefinition
}

$principalMap = @{}
foreach ($user in $users) {
    $principalMap[$user.id] = [pscustomobject]@{
        principalType = "User"
        displayName   = $user.displayName
        signInName    = $user.userPrincipalName
    }
}
foreach ($group in $groups) {
    $principalMap[$group.id] = [pscustomobject]@{
        principalType = "Group"
        displayName   = $group.displayName
        signInName    = $null
    }
}
foreach ($servicePrincipal in $servicePrincipals) {
    $principalMap[$servicePrincipal.id] = [pscustomobject]@{
        principalType = "ServicePrincipal"
        displayName   = $servicePrincipal.displayName
        signInName    = $servicePrincipal.appId
    }
}

$roleAssignmentExport = foreach ($assignment in $roleAssignments) {
    $roleDefinition = $null
    if ($roleDefinitionMap.ContainsKey($assignment.roleDefinitionId)) {
        $roleDefinition = $roleDefinitionMap[$assignment.roleDefinitionId]
    }

    $principal = $null
    if ($principalMap.ContainsKey($assignment.principalId)) {
        $principal = $principalMap[$assignment.principalId]
    }

    [pscustomobject]@{
        id                  = $assignment.id
        roleDefinitionId    = $assignment.roleDefinitionId
        roleDefinitionName  = $(if ($roleDefinition) { $roleDefinition.displayName } else { $null })
        principalId         = $assignment.principalId
        principalType       = $(if ($principal) { $principal.principalType } else { "Unknown" })
        principalDisplayName = $(if ($principal) { $principal.displayName } else { $null })
        principalSignInName = $(if ($principal) { $principal.signInName } else { $null })
        directoryScopeId    = (Get-OptionalObjectPropertyValue -Object $assignment -PropertyName "directoryScopeId")
        appScopeId          = (Get-OptionalObjectPropertyValue -Object $assignment -PropertyName "appScopeId")
    }
}

$roleAssignments | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $outputPath "roleAssignments.json")
$roleAssignmentExport | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $outputPath "roleAssignments.enriched.json")
$roleDefinitions | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $outputPath "roleDefinitions.json")
$roleAssignmentExport | Export-Csv -NoTypeInformation -LiteralPath (Join-Path $outputPath "roleAssignments.csv")

Write-Host "Role assignment export complete: $outputPath"
