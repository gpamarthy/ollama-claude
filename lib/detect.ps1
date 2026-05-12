# detect.ps1 — Hardware + OS detection on Windows. Mirror of lib/detect.sh.

function Get-OcDetection {
    [CmdletBinding()]
    param([switch]$Refresh)

    $stateDir = Join-Path $env:LOCALAPPDATA 'ollama-claude\state'
    $cacheFile = Join-Path $stateDir 'detected.json'
    if (-not $Refresh -and (Test-Path $cacheFile)) {
        $age = (Get-Date) - (Get-Item $cacheFile).LastWriteTime
        if ($age.TotalDays -lt 7) {
            return Get-Content $cacheFile -Raw | ConvertFrom-Json
        }
    }

    $os = 'windows'
    $arch = $env:PROCESSOR_ARCHITECTURE.ToLower()

    # WSL2 is the *Linux* world; this PowerShell branch is Win32 only.
    $ramBytes = (Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory
    $ramGb = [int]($ramBytes / 1GB)

    $gpuVendor = 'cpu'
    $vramGb = 0
    $hsaOverride = ''
    $rosetta = 0
    $fanless = 0

    # NVIDIA
    try {
        $smi = (Get-Command nvidia-smi -ErrorAction Stop).Source
        $line = & $smi --query-gpu=memory.total --format=csv,noheader,nounits 2>$null | Select-Object -First 1
        if ($line) {
            $vramMb = [int]($line -replace '\s', '')
            $vramGb = [int]($vramMb / 1024)
            $gpuVendor = 'nvidia'
        }
    } catch { }

    # Fallback: any GPU via WMI
    if ($gpuVendor -eq 'cpu') {
        $gpu = Get-CimInstance Win32_VideoController | Select-Object -First 1
        if ($gpu) {
            $vramBytes = [int64]$gpu.AdapterRAM
            if ($vramBytes -gt 0) {
                $vramGb = [int]($vramBytes / 1GB)
                if ($gpu.Name -match 'AMD|Radeon') { $gpuVendor = 'amd' }
                elseif ($gpu.Name -match 'Intel')  { $gpuVendor = 'intel_vulkan' }
                else                                { $gpuVendor = 'unknown' }
            }
        }
    }

    $effective = $vramGb
    $tier = if     ($effective -lt 4)  { 'cpu' }
            elseif ($effective -lt 8  -and $ramGb -ge 8)  { 'low' }
            elseif ($effective -lt 16 -and $ramGb -ge 16) { 'mid' }
            elseif ($effective -lt 24 -and $ramGb -ge 24) { 'high' }
            elseif ($effective -ge 24 -and $ramGb -ge 32) { 'workstation' }
            else { 'cpu' }

    $result = [pscustomobject]@{
        schema_version    = 1
        generated_at      = (Get-Date).ToUniversalTime().ToString('s') + 'Z'
        generated_at_unix = [int][double]::Parse((Get-Date -UFormat %s))
        os                = $os
        arch              = $arch
        gpu_vendor        = $gpuVendor
        vram_gb           = $vramGb
        effective_vram_gb = $effective
        ram_gb            = $ramGb
        tier              = $tier
        fanless           = $fanless
        rosetta           = $rosetta
        wsl2              = 0
        hsa_override      = $hsaOverride
    }

    New-Item -ItemType Directory -Path $stateDir -Force | Out-Null
    $result | ConvertTo-Json | Set-Content -Path $cacheFile -Encoding UTF8
    return $result
}

function Show-OcDetectionReport {
    param([Parameter(ValueFromPipeline = $true)]$d)
    process {
        Write-Host ("  OS:                {0} ({1})" -f $d.os, $d.arch)
        Write-Host ("  GPU:               {0}" -f $d.gpu_vendor)
        Write-Host ("  VRAM:              {0} GB" -f $d.vram_gb)
        Write-Host ("  Effective VRAM:    {0} GB" -f $d.effective_vram_gb)
        Write-Host ("  RAM:               {0} GB" -f $d.ram_gb)
        Write-Host ("  Tier:              {0}" -f $d.tier)
    }
}
