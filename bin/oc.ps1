#requires -Version 5.1
# ollama-claude dispatcher for Windows.

[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(Position = 0)]
    [string]$Command,

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Args
)

$ErrorActionPreference = 'Stop'
$Script:OC_VERSION = '0.1.0-dev'

# Resolve self path (handles symlinks/copies)
$Script:OC_BIN_DIR = Split-Path -Parent $PSCommandPath
$Script:OC_PROJECT_ROOT = Split-Path -Parent $Script:OC_BIN_DIR
$Script:OC_LIB_DIR = Join-Path $Script:OC_PROJECT_ROOT 'lib'

function Show-Help {
    @'
ollama-claude — hardware-aware bridge between Ollama and Claude Code

USAGE
  oc <command> [options]

COMMANDS
  install         Detect hardware, install Ollama, pull tier models, configure
  init            Interactive 3-question wizard
  sync            Apply current project .ollama-claude.toml on top of global config
  status          Health, models, topology, wire-up state, switch state
  doctor          End-to-end probe with per-role inference smoke test
  switch          oc switch local|cloud
  wire-up         Inject env-source into PowerShell `$PROFILE`
  version         Print version

See `oc <command> --help` for command-specific options.
'@ | Write-Host
}

if (-not $Command -or $Command -in @('-h', '--help', 'help')) {
    Show-Help
    return
}

$cmdPath = Join-Path $Script:OC_BIN_DIR "lib\$Command.ps1"
if (-not (Test-Path $cmdPath)) {
    Write-Host "[err ] unknown command: $Command" -ForegroundColor Red
    Show-Help
    exit 2
}

. $cmdPath

$fn = 'Invoke-Oc' + ($Command -split '-' | ForEach-Object { $_.Substring(0,1).ToUpper() + $_.Substring(1) }) -join ''
if (-not (Get-Command $fn -ErrorAction SilentlyContinue)) {
    Write-Host "[err ] subcommand $Command is missing its entry function ($fn)" -ForegroundColor Red
    exit 1
}

& $fn @Args
