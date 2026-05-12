# ollama-claude installer entrypoint for Windows.
#
# Safe to run piped:
#   iwr -useb https://raw.githubusercontent.com/gpamarthy/ollama-claude/main/install.ps1 | iex
#
# Honoured env vars:
#   OC_VERSION_PIN, OC_INSTALL_PREFIX, OC_LINK_DIR, OC_TOPOLOGY,
#   OC_ALLOW_FROM, OC_HOST, OC_PROFILE, OC_ASSUME_YES, OC_SKIP_BOOTSTRAP

[CmdletBinding()]
param(
    [string]$Topology = $env:OC_TOPOLOGY,
    [string]$AllowFrom = $env:OC_ALLOW_FROM,
    [string]$RemoteHost = $env:OC_HOST,
    [string]$Profile = $env:OC_PROFILE,
    [switch]$SkipBootstrap
)

$ErrorActionPreference = 'Stop'
$RepoOwner = if ($env:OC_REPO_OWNER) { $env:OC_REPO_OWNER } else { 'gpamarthy' }
$RepoName  = if ($env:OC_REPO_NAME)  { $env:OC_REPO_NAME }  else { 'ollama-claude' }
$Prefix    = if ($env:OC_INSTALL_PREFIX) { $env:OC_INSTALL_PREFIX } else { Join-Path $env:LOCALAPPDATA 'ollama-claude' }
$LinkDir   = if ($env:OC_LINK_DIR) { $env:OC_LINK_DIR } else { Join-Path $env:USERPROFILE 'bin' }

function Log-Info($m) { Write-Host "[info] $m" }
function Log-Ok($m)   { Write-Host "[ ok ] $m" -ForegroundColor Green }
function Log-Err($m)  { Write-Host "[err ] $m" -ForegroundColor Red; exit 1 }

# OneDrive guard: refuse to install under a OneDrive-synced path.
if ($Prefix -match 'OneDrive') {
    Log-Err "Install prefix is under OneDrive ($Prefix). Set OC_INSTALL_PREFIX to a local path."
}

New-Item -ItemType Directory -Path $Prefix  -Force | Out-Null
New-Item -ItemType Directory -Path $LinkDir -Force | Out-Null

# Determine version
$Version = $env:OC_VERSION_PIN
if (-not $Version) {
    try {
        $api = "https://api.github.com/repos/$RepoOwner/$RepoName/releases/latest"
        $rel = Invoke-RestMethod -UseBasicParsing -Uri $api
        $Version = $rel.tag_name
    } catch {
        Log-Err "No release yet for $RepoOwner/$RepoName and OC_VERSION_PIN unset. Clone the repo and re-run for now."
    }
}

Log-Info "installing version $Version"
$Dest = Join-Path $Prefix $Version
$Tarball = "ollama-claude-$Version.tar.gz"
$Url = "https://github.com/$RepoOwner/$RepoName/releases/download/$Version/$Tarball"
$SumsUrl = "https://github.com/$RepoOwner/$RepoName/releases/download/$Version/SHA256SUMS"

$Work = New-Item -ItemType Directory -Path (Join-Path $env:TEMP "oc-install.$([System.Guid]::NewGuid().ToString().Substring(0,8))")
try {
    Log-Info "fetching $Tarball"
    Invoke-WebRequest -UseBasicParsing -Uri $Url -OutFile (Join-Path $Work $Tarball)

    try {
        Log-Info "fetching SHA256SUMS"
        Invoke-WebRequest -UseBasicParsing -Uri $SumsUrl -OutFile (Join-Path $Work 'SHA256SUMS')
        $expected = (Select-String -Path (Join-Path $Work 'SHA256SUMS') -Pattern ([Regex]::Escape($Tarball)) | Select-Object -First 1).Line.Split()[0]
        if ($expected) {
            $actual = (Get-FileHash -Algorithm SHA256 (Join-Path $Work $Tarball)).Hash.ToLower()
            if ($expected.ToLower() -ne $actual) {
                Log-Err "checksum mismatch for $Tarball"
            }
            Log-Ok 'checksum verified'
        }
    } catch {
        Log-Info "no SHA256SUMS published; continuing without verification (Phase 1 transitional)"
    }

    if (Test-Path $Dest) { Remove-Item -Recurse -Force $Dest }
    New-Item -ItemType Directory -Path $Dest -Force | Out-Null
    tar -xzf (Join-Path $Work $Tarball) -C $Dest --strip-components=1
} finally {
    Remove-Item -Recurse -Force $Work -ErrorAction SilentlyContinue
}

# Make oc.ps1 reachable from $LinkDir as oc.ps1 (PowerShell doesn't do POSIX symlinks).
$Source = Join-Path $Dest 'bin\oc.ps1'
$LinkTarget = Join-Path $LinkDir 'oc.ps1'
Copy-Item -Force $Source $LinkTarget
Log-Ok "wrote $LinkTarget"

# Add LinkDir to user PATH if missing.
$userPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
if (-not ($userPath -split ';' | Where-Object { $_ -eq $LinkDir })) {
    [Environment]::SetEnvironmentVariable('PATH', "$userPath;$LinkDir", 'User')
    Log-Info "added $LinkDir to user PATH (open a new shell to pick this up)"
}

if (-not $SkipBootstrap) {
    Log-Info "running: oc install"
    & "$LinkTarget" install @PSBoundParameters
}

Log-Ok ''
Log-Ok 'Setup complete.'
Write-Host ''
Write-Host 'Next steps:'
Write-Host "  . `$env:USERPROFILE\.config\ollama-claude\claude-code.ps1"
Write-Host '  claude     # Claude Code now talks to local Ollama'
Write-Host ''
Write-Host 'To make sourcing permanent: oc wire-up'
