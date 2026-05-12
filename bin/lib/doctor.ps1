. (Join-Path $Script:OC_LIB_DIR 'detect.ps1')

function Invoke-OcDoctor {
    $fail = 0

    Write-Host '==> Hardware detection'
    $d = Get-OcDetection
    $d | Show-OcDetectionReport
    if (-not $d.tier) { Write-Host '[err ] could not determine tier' -ForegroundColor Red; $fail++ }

    Write-Host "`n==> Ollama health"
    $ollama = Get-Command ollama -ErrorAction SilentlyContinue
    if (-not $ollama) {
        Write-Host '[err ] Ollama not found in PATH' -ForegroundColor Red; $fail++
    } else {
        $v = (& $ollama.Source --version 2>$null | Select-Object -First 1)
        Write-Host "[ ok ] $v"
        try {
            $null = Invoke-RestMethod -UseBasicParsing -Uri 'http://127.0.0.1:11434/api/tags' -TimeoutSec 2
            Write-Host '[ ok ] service reachable on 127.0.0.1:11434'
        } catch {
            Write-Host '[err ] service not reachable on 127.0.0.1:11434' -ForegroundColor Red; $fail++
        }
    }

    if ($fail -eq 0) {
        Write-Host '[ ok ] doctor: all checks passed' -ForegroundColor Green
    } else {
        Write-Host "[err ] doctor: $fail check(s) failed" -ForegroundColor Red
        exit 1
    }
}
