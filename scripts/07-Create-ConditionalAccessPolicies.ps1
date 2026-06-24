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

$licenseTier = Get-EntraBootstrapLicenseTier -Config $config
if ((Get-EntraBootstrapCapabilities -LicenseTier $licenseTier).SupportsConditionalAccess -ne $true) {
    Write-Host "Skipping Conditional Access policy creation because the tenant is on the free tier."
    return
}

$state = $config.conditionalAccess.defaultState
if ($state -eq "reportOnly") {
    $state = "enabledForReportingButNotEnforced"
}
elseif ($state -notin @("enabled", "disabled", "enabledForReportingButNotEnforced")) {
    $state = "enabledForReportingButNotEnforced"
}

$breakGlassGroup = Get-GraphObjectByDisplayName -Collection "groups" -DisplayName "SG-ENTRA-BreakGlass"
if (-not $breakGlassGroup) {
    throw "BreakGlass group not found. Run the baseline object creation first."
}

$trustedLocation = Get-GraphObjectByDisplayName -Collection "identity/conditionalAccess/namedLocations" -DisplayName $config.conditionalAccess.trustedLocationDisplayName
$trustedLocationId = $null
if ($trustedLocation) {
    $trustedLocationId = $trustedLocation.id
}

function New-ConditionalAccessPolicyBody {
    param(
        [Parameter(Mandatory)]
        [string]$DisplayName,

        [Parameter(Mandatory)]
        [string[]]$ClientAppTypes,

        [Parameter(Mandatory)]
        [string]$GrantControl,

        [string[]]$ExcludeLocations,

        [string[]]$ExcludeGroups
    )

    $conditions = @{
        clientAppTypes = $ClientAppTypes
        applications   = @{
            includeApplications = @("All")
        }
        users          = @{
            includeUsers = @("All")
        }
    }

    if ($ExcludeGroups -and $ExcludeGroups.Count -gt 0) {
        $conditions.users.excludeGroups = $ExcludeGroups
    }

    if ($ExcludeLocations -and $ExcludeLocations.Count -gt 0) {
        $conditions.locations = @{
            includeLocations = @("All")
            excludeLocations = $ExcludeLocations
        }
    }

    $policy = @{
        displayName   = $DisplayName
        state         = $state
        conditions    = $conditions
        grantControls = @{
            operator         = "OR"
            builtInControls  = @($GrantControl)
        }
    }

    return $policy
}

$excludeGroupId = @($breakGlassGroup.id)
$excludeLocationId = @()
if ($trustedLocationId) {
    $excludeLocationId += $trustedLocationId
}

$policies = @(
    @{
        name = $config.conditionalAccess.requireMfaPolicyDisplayName
        body = (New-ConditionalAccessPolicyBody -DisplayName $config.conditionalAccess.requireMfaPolicyDisplayName -ClientAppTypes @("browser","mobileAppsAndDesktopClients") -GrantControl "mfa" -ExcludeLocations $excludeLocationId -ExcludeGroups $excludeGroupId)
    },
    @{
        name = $config.conditionalAccess.blockLegacyAuthPolicyDisplayName
        body = (New-ConditionalAccessPolicyBody -DisplayName $config.conditionalAccess.blockLegacyAuthPolicyDisplayName -ClientAppTypes @("other") -GrantControl "block" -ExcludeGroups $excludeGroupId)
    }
)

foreach ($entry in $policies) {
    $existing = Get-GraphObjectByDisplayName -Collection "identity/conditionalAccess/policies" -DisplayName $entry.name
    if ($existing) {
        Invoke-GraphRequestJson -Method PATCH -Uri "/v1.0/identity/conditionalAccess/policies/$($existing.id)" -Body $entry.body | Out-Null
        Write-Host "Updated Conditional Access policy: $($entry.name) ($($existing.id))"
    }
    else {
        try {
            $created = Invoke-GraphRequestJson -Method POST -Uri "/v1.0/identity/conditionalAccess/policies" -Body $entry.body
            Write-Host "Created Conditional Access policy: $($created.displayName) ($($created.id))"
        }
        catch {
            $message = $_.Exception.Message
            if ($message -match "not licensed for this feature") {
                Write-Warning "Skipping Conditional Access policy '$($entry.name)' because the tenant is not licensed for Conditional Access. Entra ID P1 is required."
                continue
            }

            throw
        }
    }
}
