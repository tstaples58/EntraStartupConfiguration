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

if (-not $config.automationCertPath -or -not (Test-Path -LiteralPath $config.automationCertPath)) {
    throw "Set automationCertPath in the config to a public certificate (.cer) or a certificate file you want embedded in the app registration."
}

$cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($config.automationCertPath)
$keyCredential = @{
    keyId           = [guid]::NewGuid()
    type            = "AsymmetricX509Cert"
    usage           = "Verify"
    displayName     = $config.automationCertDisplayName
    startDateTime   = (Get-Date).ToUniversalTime().ToString("o")
    endDateTime     = ([datetime]::Parse($config.automationCertEndDate)).ToUniversalTime().ToString("o")
    key             = [Convert]::ToBase64String($cert.RawData)
}

$filter = [uri]::EscapeDataString("displayName eq '$($config.automationAppDisplayName.Replace("'","''"))'")
$existing = Invoke-GraphRequestJson -Method GET -Uri "/v1.0/applications?`$filter=$filter"
if ($existing.value -and $existing.value.Count -gt 0) {
    $app = $existing.value[0]
    Write-Host "Application already exists: $($app.displayName) ($($app.appId))"
}
else {
    $app = Invoke-GraphRequestJson -Method POST -Uri "/v1.0/applications" -Body @{
        displayName   = $config.automationAppDisplayName
        signInAudience = "AzureADMyOrg"
        keyCredentials = @($keyCredential)
    }
    Write-Host "Created application: $($app.displayName) ($($app.appId))"
}

$spFilter = [uri]::EscapeDataString("appId eq '$($app.appId)'")
$spLookup = Invoke-GraphRequestJson -Method GET -Uri "/v1.0/servicePrincipals?`$filter=$spFilter"
if (-not $spLookup.value -or $spLookup.value.Count -eq 0) {
    $sp = Invoke-GraphRequestJson -Method POST -Uri "/v1.0/servicePrincipals" -Body @{
        appId = $app.appId
    }
    Write-Host "Created service principal: $($sp.id)"
}
else {
    $sp = $spLookup.value[0]
    Write-Host "Service principal already exists: $($sp.id)"
}

Write-Host ""
Write-Host "Use these values in your tenant config:"
Write-Host ("clientId: {0}" -f $app.appId)
Write-Host ("servicePrincipalObjectId: {0}" -f $sp.id)
Write-Host ("certificateThumbprint: {0}" -f $cert.Thumbprint)
