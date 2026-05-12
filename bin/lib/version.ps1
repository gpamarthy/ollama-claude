function Invoke-OcVersion {
    Write-Host ("ollama-claude {0}" -f $Script:OC_VERSION)
    $ollama = Get-Command ollama -ErrorAction SilentlyContinue
    if ($ollama) {
        $v = (& $ollama.Source --version 2>$null | Select-Object -First 1)
        Write-Host ("ollama        {0}" -f $v)
    } else {
        Write-Host 'ollama        not installed'
    }
    Write-Host 'release notes https://github.com/gpamarthy/ollama-claude/releases'
}
