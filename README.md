# EntraStartupConfiguration

PowerShell 7 bootstrap and hardening toolkit for Microsoft Entra and Microsoft 365 lab or demo tenants. The repository is script-based, certificate-auth capable, and designed for controlled testing rather than blind production rollout.

## Current Status

- Baseline bootstrap flow is in place for app registration setup, Graph permission grants, core group creation, administrative unit creation, and inventory export.
- Hardening flow is tier-aware and automatically skips premium-only features on `free` tenants.
- Shared helper functions are centralized in `shared/EntraBootstrap.Common.ps1`.
- Repository defaults are set up to avoid committing common sensitive or tenant-specific artifacts.

## Safety Defaults

- Sample config values in `config/tenant.sample.json` are generic and safe to publish.
- Real tenant settings should live in `config/tenant.json` or `config/*.local.json`.
- Output exports, generated reports, and certificate artifacts should remain local.
- Conditional Access policies default to `enabledForReportingButNotEnforced` when used.
- Mutating scripts are written to be idempotent where practical and prefer warnings over silent failure.

## Known Limitations

- Conditional Access requires Microsoft Entra ID P1 or P2. On `licenseTier: free`, those steps are skipped.
- Role-assignable groups also require a premium-capable tenant. On `licenseTier: free`, those steps are skipped.
- The toolkit depends on Microsoft Graph permissions being granted and admin-consented ahead of some write operations.
- Some scripts still need live tenant validation across different licensing tiers and permission combinations.

## Recommended Run Order

1. `pwsh ./scripts/00-Install-Prereqs.ps1 -InstallMissing`
2. `pwsh ./scripts/00-Create-AuthCert.ps1 -CertificateName "Contoso Entra Automation"`
3. Update `config/tenant.json` locally using `config/tenant.sample.json` as a template.
4. `pwsh ./scripts/Invoke-EntraBootstrap.ps1 -ConfigPath ./config/tenant.json`
5. `pwsh ./scripts/Invoke-EntraHardening.ps1 -ConfigPath ./config/tenant.json`

## Folder Layout

- `config/` holds safe sample config plus ignored local tenant config files.
- `shared/` contains common helper functions used by the scripts.
- `scripts/` contains the operational bootstrap and hardening scripts.
- `output/` is for local exports and generated summaries only.
- `docs/` is reserved for future operator notes or diagrams.
- `tests/` is reserved for future validation or Pester coverage.

## Repo Safety

- `.gitignore` is configured to ignore local configs, output folders, logs, CSV exports, and certificate or key artifacts.
- Folder names are lowercase throughout this repository.
- This toolkit should not be run blindly against production tenants.
- Deprecated AzureAD and MSOnline modules are not used.

## Resume / Portfolio Summary

This project demonstrates a script-first Microsoft Entra bootstrap toolkit with certificate authentication, Microsoft Graph automation, licensing-aware hardening behavior, and repository safety controls suitable for public portfolio publication.
