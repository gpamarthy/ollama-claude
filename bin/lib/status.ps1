. (Join-Path $Script:OC_LIB_DIR 'detect.ps1')

function Invoke-OcStatus {
    Write-Host ("ollama-claude {0}`n" -f $Script:OC_VERSION)

    Write-Host 'Hardware'
    $d = Get-OcDetection
    $d | Show-OcDetectionReport

    Write-Host "`nOllama"
    $ollama = Get-Command ollama -ErrorAction SilentlyContinue
    if ($ollama) {
        $v = (& $ollama.Source --version 2>$null | Select-Object -First 1)
        Write-Host "  Version:           $v"
        try {
            $null = Invoke-RestMethod -UseBasicParsing -Uri 'http://127.0.0.1:11434/api/tags' -TimeoutSec 2
            Write-Host '  Service:           reachable on 127.0.0.1:11434'
        } catch {
            Write-Host '  Service:           not reachable on 127.0.0.1:11434'
        }
    } else {
        Write-Host '  Not installed.'
    }

    Write-Host "`nConfiguration"
    $cfg = Join-Path $env:USERPROFILE '.config\ollama-claude'
    $topo = Join-Path $cfg 'topology'
    if (Test-Path $topo) {
        Write-Host ("  Topology:          {0}" -f (Get-Content $topo -First 1))
    } else {
        Write-Host '  Topology:          not configured'
    }

    Write-Host "`nClaude Code"
    $envFile = Join-Path $cfg 'claude-code.ps1'
    if (Test-Path $envFile) {
        Write-Host '  Env file:          ready'
    } else {
        Write-Host '  Env file:          missing (run oc install)'
    }
}
