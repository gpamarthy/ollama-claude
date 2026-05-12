# firewall.ps1
# Open port 11434 to a specific CIDR via Windows Firewall.
# Used by `oc install --topology split-host`. Idempotent.

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$AllowFrom,

    [string]$RuleName = 'OllamaClaude-11434'
)

$ErrorActionPreference = 'Stop'

$current = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($current)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'This script requires Administrator privileges.'
}

if (-not ($AllowFrom -match '^[0-9a-fA-F:.]+/[0-9]+$')) {
    throw "Invalid CIDR: $AllowFrom"
}

if (Get-NetFirewallRule -DisplayName $RuleName -ErrorAction SilentlyContinue) {
    Write-Host "[info] firewall rule '$RuleName' already exists; updating"
    Remove-NetFirewallRule -DisplayName $RuleName
}

New-NetFirewallRule `
    -DisplayName $RuleName `
    -Direction Inbound `
    -Action Allow `
    -Protocol TCP `
    -LocalPort 11434 `
    -RemoteAddress $AllowFrom `
    -Profile Any | Out-Null

Write-Host "[ok] firewall rule added: $RuleName ($AllowFrom -> :11434)"
