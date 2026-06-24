# AGENTS.md

## Project goal

This repository contains a PowerShell 7 toolkit for bootstrapping and auditing Microsoft Entra ID / Microsoft 365 tenants using Microsoft Graph.

## Rules

- Use PowerShell 7 compatible syntax.
- Prefer Microsoft Graph PowerShell or direct Microsoft Graph REST calls.
- Do not use deprecated AzureAD or MSOnline modules.
- Do not hardcode tenant IDs, client IDs, domains, secrets, object IDs, or usernames.
- Never commit real certificates, private keys, secrets, or tenant-specific config.
- Mutating scripts should support WhatIf or provide an explicit dry-run/plan mode.
- Scripts should be idempotent where possible.
- Export tenant state before making changes.
- Use structured errors and return objects where practical.
- Keep sample config files generic.