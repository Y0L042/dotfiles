<#
.SYNOPSIS
    Step 2: install GUI apps (VS Code, Notepad++, Visual Studio 2026).

.DESCRIPTION
    Reads the Gui list from packages.psd1. Anything already installed is skipped; nothing is
    upgraded or downgraded. A missing Visual Studio 2026 is installed with the workloads in
    vs2026.vsconfig. An existing one is left alone unless -ApplyVsConfig is given.

.PARAMETER DryRun
    Only report what is present/missing; install nothing.

.PARAMETER Yes
    Do not ask for confirmation before installing.

.PARAMETER ApplyVsConfig
    If Visual Studio 2026 is already installed, add any workloads from vs2026.vsconfig that it
    is missing (VS installer 'modify'). Never removes workloads.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File bootstrap\install-gui.ps1 -DryRun
#>
[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$Yes,
    [switch]$ApplyVsConfig
)

. (Join-Path $PSScriptRoot 'lib.ps1')

$packages = Import-Packages
$failed = Invoke-Bootstrap -Title 'Step 2: GUI apps' -Packages $packages.Gui -DryRun:$DryRun -Yes:$Yes

if ($ApplyVsConfig) {
    $vs = $packages.Gui | Where-Object { $_.Kind -eq 'vs' } | Select-Object -First 1
    $path = if ($vs) { Get-VsInstallPath $vs } else { $null }
    Write-Host ''
    if (-not $path) {
        Write-Host 'Visual Studio 2026 is not installed; nothing to modify.' -ForegroundColor Yellow
    } elseif (-not (Invoke-VsModify $vs $path -DryRun:$DryRun)) {
        $failed++
    }
}

exit $failed
