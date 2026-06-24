# Entra Bootstrap Toolkit

This folder contains a PowerShell starter kit for standing up an Entra tenant with certificate-based automation.

## What it does

- Connects to Microsoft Graph with a certificate
- Creates baseline security groups
- Creates administrative units
- Creates an automation app registration with an embedded public certificate
- Grants Microsoft Graph application permissions to that automation app
- Exports tenant inventory for auditing and documentation

## Layout

- `Config/tenant.sample.json` is the file you fill in with your tenant details
- `Shared/EntraBootstrap.Common.ps1` contains shared Graph helpers
- `Scripts/00-Install-Prereqs.ps1` installs the required PowerShell modules
- `Scripts/Invoke-EntraBootstrap.ps1` runs the full workflow

## Getting started

1. Copy `Config/tenant.sample.json` to your working config path.
2. Fill in `tenantId`, `clientId`, and either `certificateThumbprint` or `certificatePath`.
3. Put the public certificate for the automation app in `automationCertPath`.
4. Run `Scripts/00-Install-Prereqs.ps1 -InstallMissing`.
5. Run `Scripts/Invoke-EntraBootstrap.ps1 -ConfigPath .\Config\tenant.sample.json`.

## Notes

- The scripts assume Microsoft Graph application permissions will be consented by a suitably privileged admin.
- The automation app creation step uses the public certificate file so you do not need to hand-edit the app registration afterward.
- The inventory export writes JSON and CSV files into `Output`.

## Suggested next additions

- Conditional Access policy creation
- Named locations
- Role-assignable groups
- User onboarding and break-glass account checks
- Exchange Online and Teams admin helpers
