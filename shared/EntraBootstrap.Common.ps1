Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-EntraBootstrapRoot {
    if ($PSScriptRoot) {
        return (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
    }
    return (Get-Location).Path
}

function Get-EntraBootstrapConfig {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Config file not found: $Path"
    }

    $raw = Get-Content -LiteralPath $Path -Raw
    return $raw | ConvertFrom-Json
}

function Get-OptionalObjectPropertyValue {
    param(
        [Parameter(Mandatory)]
        [object]$Object,

        [Parameter(Mandatory)]
        [string]$PropertyName
    )

    if (-not $Object -or -not $Object.PSObject -or -not $Object.PSObject.Properties) {
        return $null
    }

    $property = $Object.PSObject.Properties[$PropertyName]
    if (-not $property) {
        return $null
    }

    $value = $property.Value
    if ($null -eq $value) {
        return $null
    }

    if ($value -is [string] -and [string]::IsNullOrWhiteSpace($value)) {
        return $null
    }

    return $value
}

function Get-EntraBootstrapLicenseTier {
    param(
        [Parameter(Mandatory)]
        [object]$Config
    )

    $candidate = Get-OptionalObjectPropertyValue -Object $Config -PropertyName "licenseTier"
    if (-not $candidate) {
        return "free"
    }

    switch ((([string]$candidate).ToLowerInvariant())) {
        "free" { return "free" }
        "p1" { return "p1" }
        "p2" { return "p2" }
        default { return "free" }
    }
}

function Get-EntraBootstrapCapabilities {
    param(
        [Parameter(Mandatory)]
        [string]$LicenseTier
    )

    $tier = $LicenseTier.ToLowerInvariant()
    return [pscustomobject]@{
        LicenseTier                  = $tier
        SupportsConditionalAccess    = ($tier -in @("p1", "p2"))
        SupportsRoleAssignableGroups = ($tier -in @("p1", "p2"))
    }
}

function Write-EntraBootstrapTierSummary {
    param(
        [Parameter(Mandatory)]
        [string]$LicenseTier
    )

    $capabilities = Get-EntraBootstrapCapabilities -LicenseTier $LicenseTier
    Write-Host ("License tier: {0}" -f $capabilities.LicenseTier)
    Write-Host ("Conditional Access: {0}" -f $(if ($capabilities.SupportsConditionalAccess) { "enabled" } else { "skipped" }))
    Write-Host ("Role-assignable groups: {0}" -f $(if ($capabilities.SupportsRoleAssignableGroups) { "enabled" } else { "skipped" }))
}

function Assert-Module {
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        [string]$MinimumVersion
    )

    $module = Get-Module -ListAvailable -Name $Name | Sort-Object Version -Descending | Select-Object -First 1
    if (-not $module) {
        throw "Required module not found: $Name"
    }

    if ($MinimumVersion -and ([version]$module.Version -lt [version]$MinimumVersion)) {
        throw "Module $Name is installed, but version $($module.Version) is older than required $MinimumVersion"
    }
}

function Ensure-Module {
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        [string]$MinimumVersion,
        [switch]$InstallMissing,
        [string]$Scope = "CurrentUser"
    )

    $module = Get-Module -ListAvailable -Name $Name | Sort-Object Version -Descending | Select-Object -First 1
    if (-not $module) {
        if (-not $InstallMissing) {
            throw "Module not found: $Name. Re-run with -InstallMissing or install it manually."
        }

        Install-Module -Name $Name -Scope $Scope -Force -AllowClobber
    }
    elseif ($MinimumVersion -and ([version]$module.Version -lt [version]$MinimumVersion)) {
        if (-not $InstallMissing) {
            throw "Module $Name is too old ($($module.Version)); need $MinimumVersion or newer."
        }

        Install-Module -Name $Name -Scope $Scope -Force -AllowClobber -MinimumVersion $MinimumVersion
    }
}

function Import-EntraPrereqs {
    param(
        [switch]$InstallMissing
    )

    Ensure-Module -Name "Microsoft.Graph.Authentication" -InstallMissing:$InstallMissing
    Ensure-Module -Name "Microsoft.Graph" -InstallMissing:$InstallMissing
}

function Connect-EntraGraphWithCertificate {
    param(
        [Parameter(Mandatory)]
        [string]$TenantId,

        [Parameter(Mandatory)]
        [string]$ClientId,

        [string]$CertificateThumbprint,

        [string]$CertificatePath,

        [string]$CertificatePassword
    )

    if ($CertificateThumbprint) {
        Connect-MgGraph -TenantId $TenantId -ClientId $ClientId -CertificateThumbprint $CertificateThumbprint | Out-Null
        return
    }

    if ($CertificatePath) {
        if (-not (Test-Path -LiteralPath $CertificatePath)) {
            throw "Certificate file not found: $CertificatePath"
        }

        $securePassword = $null
        if ($CertificatePassword) {
            $securePassword = ConvertTo-SecureString -String $CertificatePassword -AsPlainText -Force
        }

        $flags = [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::PersistKeySet -bor
            [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::MachineKeySet

        $certificate = if ($securePassword) {
            [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($CertificatePath, $securePassword, $flags)
        }
        else {
            [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($CertificatePath, $null, $flags)
        }

        Connect-MgGraph -TenantId $TenantId -ClientId $ClientId -Certificate $certificate | Out-Null
        return
    }

    throw "Provide either CertificateThumbprint or CertificatePath for certificate-based authentication."
}

function Invoke-GraphRequestJson {
    param(
        [Parameter(Mandatory)]
        [ValidateSet("GET", "POST", "PATCH", "PUT", "DELETE")]
        [string]$Method,

        [Parameter(Mandatory)]
        [string]$Uri,

        [object]$Body
    )

    $params = @{
        Method = $Method
        Uri    = $Uri
    }

    if ($PSBoundParameters.ContainsKey("Body") -and $null -ne $Body) {
        $params.Body = ($Body | ConvertTo-Json -Depth 20)
        $params.ContentType = "application/json"
    }

    return Invoke-MgGraphRequest @params
}

function Get-GraphCollectionAll {
    param(
        [Parameter(Mandatory)]
        [string]$Uri
    )

    $items = New-Object System.Collections.Generic.List[object]
    $next = $Uri
    while ($next) {
        $response = Invoke-MgGraphRequest -Method GET -Uri $next
        if ($response -is [System.Array]) {
            foreach ($entry in $response) {
                [void]$items.Add($entry)
            }
        }
        elseif ($response.value) {
            foreach ($entry in $response.value) {
                [void]$items.Add($entry)
            }
        }

        $nextLinkProp = $null
        if ($response -and $response.PSObject -and $response.PSObject.Properties) {
            $nextLinkProp = $response.PSObject.Properties['@odata.nextLink']
        }

        if ($nextLinkProp) {
            $next = $nextLinkProp.Value
        }
        else {
            $next = $null
        }
    }

    return $items
}

function Ensure-GraphObjectByDisplayName {
    param(
        [Parameter(Mandatory)]
        [ValidateSet("groups", "directory/administrativeUnits", "identity/conditionalAccess/namedLocations", "identity/conditionalAccess/policies")]
        [string]$Collection,

        [Parameter(Mandatory)]
        [string]$DisplayName,

        [Parameter(Mandatory)]
        [scriptblock]$CreateBodyFactory,

        [string]$FilterProperty = "displayName"
    )

    $safeName = $DisplayName.Replace("'", "''")
    $filter = [uri]::EscapeDataString("$FilterProperty eq '$safeName'")
    $uri = "/v1.0/${Collection}?`$filter=$filter"
    $existing = Invoke-GraphRequestJson -Method GET -Uri $uri
    if ($existing.value -and $existing.value.Count -gt 0) {
        return $existing.value[0]
    }

    $body = & $CreateBodyFactory
    return Invoke-GraphRequestJson -Method POST -Uri "/v1.0/$Collection" -Body $body
}

function Get-GraphObjectByDisplayName {
    param(
        [Parameter(Mandatory)]
        [string]$Collection,

        [Parameter(Mandatory)]
        [string]$DisplayName,

        [string]$FilterProperty = "displayName"
    )

    $safeName = $DisplayName.Replace("'", "''")
    $filter = [uri]::EscapeDataString("$FilterProperty eq '$safeName'")
    $uri = "/v1.0/${Collection}?`$filter=$filter"
    $response = Invoke-GraphRequestJson -Method GET -Uri $uri
    if ($response.value -and $response.value.Count -gt 0) {
        return $response.value[0]
    }

    return $null
}

function Ensure-OutputDirectory {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path | Out-Null
    }

    return (Resolve-Path -LiteralPath $Path).Path
}

function Write-EntraBootstrapRunSummary {
    param(
        [Parameter(Mandatory)]
        [string]$ConfigPath,

        [Parameter(Mandatory)]
        [string]$LicenseTier,

        [Parameter(Mandatory)]
        [bool]$RanConditionalAccess,

        [Parameter(Mandatory)]
        [bool]$RanRoleAssignableGroups,

        [Parameter(Mandatory)]
        [bool]$RanDirectoryRoles
    )

    $config = Get-EntraBootstrapConfig -Path $ConfigPath
    $root = Get-EntraBootstrapRoot
    $outputPath = Ensure-OutputDirectory -Path (Join-Path $root $config.reportOutputPath)
    $summary = [pscustomobject]@{
        timestampUtc             = (Get-Date).ToUniversalTime().ToString("o")
        configPath               = $ConfigPath
        tenantId                 = $config.tenantId
        automationAppDisplayName = $config.automationAppDisplayName
        licenseTier              = $LicenseTier
        ranConditionalAccess     = $RanConditionalAccess
        ranRoleAssignableGroups  = $RanRoleAssignableGroups
        ranDirectoryRoles        = $RanDirectoryRoles
    }

    $summaryPath = Join-Path $outputPath "hardening-summary.json"
    $summary | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $summaryPath
    return $summary
}
