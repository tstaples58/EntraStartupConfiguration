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

$appFilter = [uri]::EscapeDataString("displayName eq '$($config.automationAppDisplayName.Replace("'","''"))'")
$appLookup = Invoke-GraphRequestJson -Method GET -Uri "/v1.0/applications?`$filter=$appFilter"
if (-not $appLookup.value -or $appLookup.value.Count -eq 0) {
    throw "Automation application not found. Run 03-NewAutomationApp.ps1 first."
}

$app = $appLookup.value[0]
$spFilter = [uri]::EscapeDataString("appId eq '$($app.appId)'")
$spLookup = Invoke-GraphRequestJson -Method GET -Uri "/v1.0/servicePrincipals?`$filter=$spFilter"
if (-not $spLookup.value -or $spLookup.value.Count -eq 0) {
    throw "Service principal for the automation application was not found."
}

$sp = $spLookup.value[0]
$graphFilter = [uri]::EscapeDataString("appId eq '00000003-0000-0000-c000-000000000000'")
$graphSpLookup = Invoke-GraphRequestJson -Method GET -Uri "/v1.0/servicePrincipals?`$filter=$graphFilter"
$graphSp = $graphSpLookup.value[0]

$permissionMap = @{}
foreach ($role in (Get-GraphCollectionAll -Uri "/v1.0/servicePrincipals/$($graphSp.id)/appRoles")) {
    $permissionMap[$role.value] = $role.id
}

foreach ($permissionName in @($config.graphApplicationPermissions)) {
    if (-not $permissionMap.ContainsKey($permissionName)) {
        Write-Warning "Microsoft Graph permission not found: $permissionName"
        continue
    }

    $existingAssignment = Invoke-GraphRequestJson -Method GET -Uri "/v1.0/servicePrincipals/$($sp.id)/appRoleAssignments?`$filter=appRoleId eq $($permissionMap[$permissionName])"
    if ($existingAssignment.value -and $existingAssignment.value.Count -gt 0) {
        Write-Host "Already assigned: $permissionName"
        continue
    }

    Invoke-GraphRequestJson -Method POST -Uri "/v1.0/servicePrincipals/$($sp.id)/appRoleAssignments" -Body @{
        principalId = $sp.id
        resourceId  = $graphSp.id
        appRoleId   = $permissionMap[$permissionName]
    } | Out-Null

    Write-Host "Assigned Graph application permission: $permissionName"
}
