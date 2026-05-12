# ollama-service.ps1
# Manage the Ollama Windows Service via sc.exe. Used by oc install on
# Windows. Idempotent; safe to re-run.

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('install', 'remove', 'start', 'stop', 'status')]
    [string]$Action,

    [string]$BinPath = 'C:\Program Files\Ollama\ollama.exe',
    [string]$OllamaHost = '127.0.0.1:11434',
    [string]$KeepAlive = '5m',
    [int]$NumCtx = 8192
)

$ErrorActionPreference = 'Stop'
$ServiceName = 'OllamaClaude'
$DisplayName = 'Ollama Service (ollama-claude managed)'

function Require-Admin {
    $current = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($current)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'This action requires Administrator privileges.'
    }
}

switch ($Action) {
    'install' {
        Require-Admin
        if (-not (Test-Path $BinPath)) {
            throw "Ollama binary not found at: $BinPath"
        }
        if (Get-Service -Name $ServiceName -ErrorAction SilentlyContinue) {
            Write-Host "[info] service $ServiceName already exists; removing first"
            sc.exe delete $ServiceName | Out-Null
            Start-Sleep -Seconds 1
        }
        $envArgs = @(
            "OLLAMA_HOST=$OllamaHost",
            "OLLAMA_KEEP_ALIVE=$KeepAlive",
            "OLLAMA_NUM_CTX=$NumCtx",
            'OLLAMA_KV_CACHE_TYPE=q8_0',
            'OLLAMA_FLASH_ATTENTION=1',
            'OLLAMA_MAX_LOADED_MODELS=1',
            'OLLAMA_NUM_PARALLEL=1',
            'OLLAMA_DEBUG=0'
        ) -join '|'

        New-Service -Name $ServiceName -BinaryPathName "`"$BinPath`" serve" `
            -DisplayName $DisplayName -StartupType Automatic | Out-Null

        # Persist env via the service ImagePath is messy; recommend using
        # the user-level / system-level environment variables instead.
        foreach ($pair in $envArgs.Split('|')) {
            $k, $v = $pair.Split('=', 2)
            [Environment]::SetEnvironmentVariable($k, $v, 'Machine')
        }

        Write-Host "[ok] installed service: $ServiceName"
    }

    'remove' {
        Require-Admin
        if (Get-Service -Name $ServiceName -ErrorAction SilentlyContinue) {
            Stop-Service -Name $ServiceName -Force -ErrorAction SilentlyContinue
            sc.exe delete $ServiceName | Out-Null
            Write-Host "[ok] removed service: $ServiceName"
        } else {
            Write-Host "[info] service $ServiceName not installed"
        }
    }

    'start'  { Require-Admin; Start-Service -Name $ServiceName }
    'stop'   { Require-Admin; Stop-Service -Name $ServiceName -Force }
    'status' {
        $svc = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
        if ($svc) {
            Write-Host "$ServiceName  $($svc.Status)"
        } else {
            Write-Host "$ServiceName  not installed"
        }
    }
}
