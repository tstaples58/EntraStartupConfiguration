param(
    [string]$CertificateName = "Entra BootStrap Cert",
    [string]$ExportFolder,
    [int]$ValidYears = 1,
    [switch]$ExportPfx,
    [string]$PfxPassword
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($ExportFolder)) {
    $ExportFolder = Join-Path (Split-Path $PSScriptRoot -Parent) "output"
}
else {
    $resolvedExport = Resolve-Path -LiteralPath $ExportFolder -ErrorAction SilentlyContinue
    if ($resolvedExport) {
        $ExportFolder = $resolvedExport.Path
    }
}

if (-not (Test-Path -LiteralPath $ExportFolder)) {
    New-Item -ItemType Directory -Path $ExportFolder | Out-Null
}

$notAfter = (Get-Date).AddYears($ValidYears)
$cert = New-SelfSignedCertificate `
    -Subject "CN=$CertificateName" `
    -CertStoreLocation "Cert:\CurrentUser\My" `
    -KeyExportPolicy Exportable `
    -KeySpec Signature `
    -KeyLength 2048 `
    -KeyAlgorithm RSA `
    -HashAlgorithm SHA256 `
    -NotAfter $notAfter

$safeName = $CertificateName -replace '[\\/:*?"<>|]', '_'
$cerPath = Join-Path $ExportFolder "$safeName.cer"
Export-Certificate -Cert $cert -FilePath $cerPath | Out-Null

$pfxPath = $null
if ($ExportPfx) {
    if ([string]::IsNullOrWhiteSpace($PfxPassword)) {
        throw "When using -ExportPfx, supply -PfxPassword."
    }

    $securePassword = ConvertTo-SecureString -String $PfxPassword -AsPlainText -Force
    $pfxPath = Join-Path $ExportFolder "$safeName.pfx"
    Export-PfxCertificate -Cert $cert -FilePath $pfxPath -Password $securePassword | Out-Null
}

Write-Host "Created certificate in CurrentUser\My:"
Write-Host ("Subject: {0}" -f $cert.Subject)
Write-Host ("Thumbprint: {0}" -f $cert.Thumbprint)
Write-Host ("Public cert (.cer): {0}" -f $cerPath)
if ($pfxPath) {
    Write-Host ("Private key package (.pfx): {0}" -f $pfxPath)
}
Write-Host ""
Write-Host "Next step: upload the .cer file to Entra under App registrations > your app > Certificates & secrets > Certificates > Upload certificate."
