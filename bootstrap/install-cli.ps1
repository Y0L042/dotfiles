<#
.SYNOPSIS
    Step 1: install CLI tools and runtimes (git, python, node, rust, .NET, nvim, ripgrep, ...).

.DESCRIPTION
    Reads the Cli list from packages.psd1. Anything already on PATH or known to winget/scoop
    is skipped, whatever installed it. Nothing is upgraded or downgraded.
    Run from a normal (non-elevated) shell; Scoop refuses to install when elevated.

.PARAMETER DryRun
    Only report what is present/missing; install nothing.

.PARAMETER Yes
    Do not ask for confirmation before installing.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File bootstrap\install-cli.ps1 -DryRun
#>
[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$Yes
)

. (Join-Path $PSScriptRoot 'lib.ps1')

$packages = Import-Packages
$failed = Invoke-Bootstrap -Title 'Step 1: CLI tools' -Packages $packages.Cli `
    -ScoopBuckets $packages.ScoopBuckets -DryRun:$DryRun -Yes:$Yes
exit $failed
