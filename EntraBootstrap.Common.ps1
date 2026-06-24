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
        if ($response.value) {
            foreach ($entry in $response.value) {
                [void]$items.Add($entry)
            }
        }
        $next = $response.'@odata.nextLink'
    }
    return $items
}

function Ensure-GraphObjectByDisplayName {
    param(
        [Parameter(Mandatory)]
        [ValidateSet("groups", "directory/administrativeUnits")]
        [string]$Collection,

        [Parameter(Mandatory)]
        [string]$DisplayName,

        [Parameter(Mandatory)]
        [scriptblock]$CreateBodyFactory,

        [string]$FilterProperty = "displayName"
    )

    $safeName = $DisplayName.Replace("'", "''")
    $filter = [uri]::EscapeDataString("$FilterProperty eq '$safeName'")
    $uri = "/v1.0/$Collection?`$filter=$filter"
    $existing = Invoke-GraphRequestJson -Method GET -Uri $uri
    if ($existing.value -and $existing.value.Count -gt 0) {
        return $existing.value[0]
    }

    $body = & $CreateBodyFactory
    return Invoke-GraphRequestJson -Method POST -Uri "/v1.0/$Collection" -Body $body
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
