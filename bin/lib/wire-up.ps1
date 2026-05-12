function Invoke-OcWireUp {
    [CmdletBinding()]
    param(
        [switch]$DryRun,
        [switch]$ClaudeSettings
    )

    $cfg = Join-Path $env:USERPROFILE '.config\ollama-claude'
    $envFile = Join-Path $cfg 'claude-code.ps1'
    if (-not (Test-Path $envFile)) {
        throw "env file not found: $envFile (run oc install first)"
    }

    # PowerShell profile path
    if (-not $PROFILE) {
        throw 'no $PROFILE path available in this session'
    }

    $line = ". `"$envFile`""
    if ((Test-Path $PROFILE) -and (Select-String -Path $PROFILE -SimpleMatch -Pattern $envFile -Quiet)) {
        Write-Host "[ ok ] `$PROFILE already sources $envFile (no change)"
        return
    }

    if ($DryRun) {
        Write-Host "[info] would append to $PROFILE:"
        Write-Host "  $line"
        return
    }

    $profileDir = Split-Path -Parent $PROFILE
    New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
    Add-Content -Path $PROFILE -Value @"

# ollama-claude: route Claude Code to local Ollama
$line
"@
    Write-Host "[ ok ] appended to $PROFILE; open a new shell to apply"

    if ($ClaudeSettings) {
        $settingsDir = Join-Path $env:USERPROFILE '.config\claude'
        $settings = Join-Path $settingsDir 'settings.json'
        $src = Join-Path $Script:OC_PROJECT_ROOT 'config\claude-code.settings.example.json'
        New-Item -ItemType Directory -Path $settingsDir -Force | Out-Null
        if (Test-Path $settings) {
            Write-Host "[warn] $settings exists; refusing to overwrite. Merge manually from $src."
        } else {
            Copy-Item -Force $src $settings
            Write-Host "[ ok ] wrote $settings"
        }
    }
}
