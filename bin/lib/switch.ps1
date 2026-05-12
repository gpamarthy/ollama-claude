function Invoke-OcSwitch {
    param([string]$Mode)

    $cfg = Join-Path $env:USERPROFILE '.config\ollama-claude'
    $envFile = Join-Path $cfg 'claude-code.ps1'

    if (-not $Mode) {
        if ($env:ANTHROPIC_BASE_URL -match '127\.0\.0\.1|localhost') { Write-Host 'switch state: local' }
        elseif ($env:ANTHROPIC_BASE_URL) { Write-Host 'switch state: custom' }
        else { Write-Host 'switch state: cloud' }
        return
    }

    $profileFile = Join-Path $cfg 'profile'
    if ($Mode -eq 'cloud' -and (Test-Path $profileFile)) {
        $prof = (Get-Content $profileFile -First 1)
        if ($prof -eq 'security-research') {
            throw "profile '$prof' forbids cloud mode. Fork the profile if you intend to switch."
        }
    }

    switch ($Mode) {
        'local' {
            @"
`$env:ANTHROPIC_BASE_URL = 'http://127.0.0.1:11434'
`$env:ANTHROPIC_AUTH_TOKEN = 'ollama'
Remove-Item Env:ANTHROPIC_API_KEY -ErrorAction SilentlyContinue
"@ | Set-Content -Path $envFile -Encoding UTF8
            Write-Host "[ ok ] switched to local; dot-source $envFile in your shell or restart Claude Code"
        }
        'cloud' {
            @"
Remove-Item Env:ANTHROPIC_BASE_URL -ErrorAction SilentlyContinue
Remove-Item Env:ANTHROPIC_AUTH_TOKEN -ErrorAction SilentlyContinue
"@ | Set-Content -Path $envFile -Encoding UTF8
            Write-Host "[ ok ] switched to cloud; dot-source $envFile or restart Claude Code"
        }
        default { throw "invalid switch: $Mode (use local or cloud)" }
    }
}
