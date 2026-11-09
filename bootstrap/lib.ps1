# Shared helpers for install-cli.ps1 / install-gui.ps1. Windows PowerShell 5.1 compatible.
# Keep this file ASCII-only (PS 5.1 reads BOM-less scripts as ANSI).

$script:BootstrapDir = $PSScriptRoot

# winget exit codes that mean "nothing to do" rather than failure.
$script:WingetOkCodes = @(
    0
    -1978335189   # 0x8A15002B  APPINSTALLER_CLI_ERROR_UPDATE_NOT_APPLICABLE
    -1978335135   # 0x8A150061  APPINSTALLER_CLI_ERROR_PACKAGE_ALREADY_INSTALLED
)

function Import-Packages {
    Import-PowerShellDataFile -Path (Join-Path $script:BootstrapDir 'packages.psd1')
}

function Expand-PathString([string]$Path) {
    [Environment]::ExpandEnvironmentVariables($Path)
}

# Merge Machine + User PATH from the registry into this session (keeps session-only entries),
# so tools installed by earlier steps - or before this shell started - are found.
function Update-SessionPath {
    $parts = New-Object System.Collections.Generic.List[string]
    $seen = @{}
    $sources = @(
        [Environment]::GetEnvironmentVariable('Path', 'Machine'),
        [Environment]::GetEnvironmentVariable('Path', 'User'),
        $env:Path
    )
    foreach ($src in $sources) {
        if (-not $src) { continue }
        foreach ($p in $src.Split(';')) {
            if (-not $p) { continue }
            $p = Expand-PathString $p
            $key = $p.TrimEnd('\').ToLowerInvariant()
            if (-not $seen.ContainsKey($key)) { $seen[$key] = $true; $parts.Add($p) }
        }
    }
    $env:Path = $parts -join ';'
}

function Get-PackageSource($Pkg) {
    if ($Pkg.Kind) { return 'special' }
    if ($Pkg.Scoop) { return 'scoop' }
    if ($Pkg.WingetId) { return 'winget' }
    return '?'
}

function Get-VsWhere {
    $p = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    if (Test-Path -LiteralPath $p) { return $p }
    return $null
}

function Get-VsInstallPath($Pkg) {
    $vswhere = Get-VsWhere
    if (-not $vswhere) { return $null }
    $path = & $vswhere -version $Pkg.VersionRange -products '*' -prerelease -property installationPath 2>$null |
        Select-Object -First 1
    if ($path) { return $path.Trim() }
    return $null
}

function Test-ScoopAvailable {
    [bool](Get-Command scoop -ErrorAction SilentlyContinue)
}

# Returns a string describing where the package was found, or $null if it is missing.
function Test-Present($Pkg) {
    switch ($Pkg.Kind) {
        'scoop' {
            $c = Get-Command scoop -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($c) { return $c.Source }
            return $null
        }
        'vcpkg' {
            $roots = @()
            if ($env:VCPKG_ROOT) { $roots += $env:VCPKG_ROOT }
            $roots += (Expand-PathString $Pkg.Root)
            foreach ($r in $roots) {
                if (Test-Path -LiteralPath (Join-Path $r 'vcpkg.exe')) { return (Join-Path $r 'vcpkg.exe') }
                if (Test-Path -LiteralPath (Join-Path $r '.git')) {
                    return "$r (not bootstrapped: run $r\bootstrap-vcpkg.bat)"
                }
            }
            return $null
        }
        'vs' {
            return (Get-VsInstallPath $Pkg)
        }
    }

    if ($Pkg.Command) {
        $c = Get-Command $Pkg.Command -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($c) { return $c.Source }
    }
    foreach ($p in @($Pkg.Paths)) {
        if ($p -and (Test-Path -LiteralPath (Expand-PathString $p))) { return (Expand-PathString $p) }
    }
    if ($Pkg.Scoop -and (Test-ScoopAvailable)) {
        $prefix = & scoop prefix $Pkg.Scoop 2>$null 6>$null
        if ($LASTEXITCODE -eq 0 -and $prefix) { return "scoop: $prefix (not on PATH)" }
    }
    foreach ($id in @($Pkg.WingetId, $Pkg.DetectWinget)) {
        if (-not $id) { continue }
        & winget list --id $id -e --accept-source-agreements --disable-interactivity *> $null
        if ($LASTEXITCODE -eq 0) { return "winget: $id (not on PATH)" }
    }
    return $null
}

# ---------------------------------------------------------------- installers

function Install-WingetPackage($Pkg) {
    Write-Host "  winget install $($Pkg.WingetId)" -ForegroundColor DarkGray
    & winget install --id $Pkg.WingetId -e --no-upgrade `
        --accept-source-agreements --accept-package-agreements --disable-interactivity | Out-Host
    $code = $LASTEXITCODE
    if ($script:WingetOkCodes -contains $code) { return $true }
    Write-Host ("  winget exit code {0} (0x{1:X8})" -f $code, $code) -ForegroundColor Red
    return $false
}

function Install-ScoopPackage($Pkg) {
    if (-not (Test-ScoopAvailable)) {
        Write-Host '  Scoop is not available; cannot install.' -ForegroundColor Red
        return $false
    }
    Write-Host "  scoop install $($Pkg.Scoop)" -ForegroundColor DarkGray
    & scoop install $Pkg.Scoop | Out-Host
    return ($LASTEXITCODE -eq 0 -or $null -eq $LASTEXITCODE)
}

function Install-Scoop {
    if (Test-IsAdmin) {
        Write-Host '  Scoop must be installed from a non-elevated shell.' -ForegroundColor Red
        return $false
    }
    $policy = Get-ExecutionPolicy -Scope CurrentUser
    if (@('Restricted', 'AllSigned', 'Undefined') -contains [string]$policy) {
        $effective = Get-ExecutionPolicy
        if (@('Restricted', 'AllSigned') -contains [string]$effective) {
            Write-Host '  Setting CurrentUser execution policy to RemoteSigned' -ForegroundColor DarkGray
            Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force | Out-Host
        }
    }
    Write-Host '  irm get.scoop.sh | iex' -ForegroundColor DarkGray
    try {
        Invoke-RestMethod -Uri 'https://get.scoop.sh' | Invoke-Expression | Out-Host
    } catch {
        Write-Host "  Scoop install failed: $_" -ForegroundColor Red
        return $false
    }
    Update-SessionPath
    return (Test-ScoopAvailable)
}

function Add-ScoopBuckets([string[]]$Buckets) {
    if (-not $Buckets -or -not (Test-ScoopAvailable)) { return }
    $existing = @(& scoop bucket list 2>$null | ForEach-Object { if ($_.Name) { $_.Name } else { "$_" } })
    foreach ($b in $Buckets) {
        if ($existing -notcontains $b) {
            Write-Host "  scoop bucket add $b" -ForegroundColor DarkGray
            & scoop bucket add $b | Out-Host
        }
    }
}

function Install-Vcpkg($Pkg) {
    $root = Expand-PathString $Pkg.Root
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Host '  git is required to clone vcpkg.' -ForegroundColor Red
        return $false
    }
    Write-Host "  git clone https://github.com/microsoft/vcpkg $root" -ForegroundColor DarkGray
    & git clone https://github.com/microsoft/vcpkg $root | Out-Host
    if ($LASTEXITCODE -ne 0) { return $false }
    & (Join-Path $root 'bootstrap-vcpkg.bat') -disableMetrics | Out-Host
    if ($LASTEXITCODE -ne 0) { return $false }
    [Environment]::SetEnvironmentVariable('VCPKG_ROOT', $root, 'User')
    $env:VCPKG_ROOT = $root
    Write-Host "  VCPKG_ROOT set to $root (user env)" -ForegroundColor DarkGray
    return $true
}

function Get-VsConfigPath($Pkg) {
    Join-Path $script:BootstrapDir $Pkg.Config
}

function Install-VisualStudio($Pkg) {
    $cfg = Get-VsConfigPath $Pkg
    if ($cfg -match ' ') {
        # Avoid nested quotes inside --override: use the 8.3 short path instead.
        $cfg = (New-Object -ComObject Scripting.FileSystemObject).GetFile($cfg).ShortPath
    }
    $override = "--wait --passive --includeRecommended --config $cfg"
    $argLine = "install --id $($Pkg.WingetId) -e --no-upgrade --accept-source-agreements " +
               "--accept-package-agreements --disable-interactivity --override `"$override`""
    Write-Host "  winget $argLine" -ForegroundColor DarkGray
    $p = Start-Process -FilePath 'winget' -ArgumentList $argLine -Wait -NoNewWindow -PassThru
    if ($script:WingetOkCodes -contains $p.ExitCode) { return $true }
    Write-Host ("  winget exit code {0}" -f $p.ExitCode) -ForegroundColor Red
    return $false
}

# Adds any missing workloads from the .vsconfig to an existing install. Never removes anything.
function Invoke-VsModify($Pkg, [string]$InstallPath, [switch]$DryRun) {
    $setup = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\setup.exe'
    $cfg = Get-VsConfigPath $Pkg
    $argLine = "modify --installPath `"$InstallPath`" --config `"$cfg`" --includeRecommended --passive --norestart"
    if ($DryRun) {
        Write-Host "Would run: `"$setup`" $argLine" -ForegroundColor Yellow
        return $true
    }
    Write-Host "Running: `"$setup`" $argLine" -ForegroundColor Cyan
    $p = Start-Process -FilePath $setup -ArgumentList $argLine -Wait -PassThru
    if ($p.ExitCode -eq 0 -or $p.ExitCode -eq 3010) { return $true }   # 3010 = reboot required
    Write-Host "  VS installer exit code $($p.ExitCode)" -ForegroundColor Red
    return $false
}

function Invoke-AfterInstall($Pkg) {
    switch ($Pkg.After) {
        'rustup-default-stable' {
            if (-not (Get-Command rustup -ErrorAction SilentlyContinue)) { return }
            $tc = (& rustup toolchain list 2>&1) -join "`n"
            if ($tc -match 'no installed toolchains' -or -not $tc.Trim()) {
                Write-Host '  rustup default stable' -ForegroundColor DarkGray
                & rustup default stable | Out-Host
            }
        }
    }
}

function Install-Package($Pkg) {
    switch ($Pkg.Kind) {
        'scoop' { return (Install-Scoop) }
        'vcpkg' { return (Install-Vcpkg $Pkg) }
        'vs'    { return (Install-VisualStudio $Pkg) }
    }
    if ($Pkg.Scoop) { return (Install-ScoopPackage $Pkg) }
    if ($Pkg.WingetId) { return (Install-WingetPackage $Pkg) }
    Write-Host "  No install source for $($Pkg.Name)" -ForegroundColor Red
    return $false
}

function Test-IsAdmin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    (New-Object Security.Principal.WindowsPrincipal $id).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# ---------------------------------------------------------------- driver

# Checks every package, prints a report, and (unless -DryRun) installs what is missing
# after confirmation. Returns the number of failed installs.
function Invoke-Bootstrap {
    param(
        [Parameter(Mandatory)] [string]$Title,
        [Parameter(Mandatory)] [object[]]$Packages,
        [string[]]$ScoopBuckets = @(),
        [switch]$DryRun,
        [switch]$Yes
    )

    Update-SessionPath
    Write-Host ''
    Write-Host "== $Title ==" -ForegroundColor Cyan
    Write-Host 'Checking what is already installed...' -ForegroundColor DarkGray

    $results = foreach ($pkg in $Packages) {
        $where = Test-Present $pkg
        [pscustomobject]@{
            Name   = $pkg.Name
            Source = Get-PackageSource $pkg
            Status = if ($where) { 'present' } else { 'missing' }
            Where  = $where
            Pkg    = $pkg
        }
    }

    # Scoop itself is only needed if a Scoop package is missing.
    $needScoop = @($results | Where-Object { $_.Status -eq 'missing' -and $_.Pkg.Scoop }).Count -gt 0
    foreach ($r in $results) {
        if ($r.Pkg.Kind -eq 'scoop' -and $r.Status -eq 'missing' -and -not $needScoop) {
            $r.Status = 'not needed'
        }
    }

    $table = $results | Format-Table Name, Source, Status, Where -AutoSize -Wrap | Out-String -Width 220
    Write-Host ((($table -split "`r?`n") | ForEach-Object { $_.TrimEnd() }) -join "`n").Trim("`n")
    Write-Host ''

    $missing = @($results | Where-Object { $_.Status -eq 'missing' })
    if ($missing.Count -eq 0) {
        Write-Host 'Nothing to install.' -ForegroundColor Green
        return 0
    }

    if ($DryRun) {
        Write-Host ("Dry run: would install {0} package(s): {1}" -f $missing.Count, (($missing | ForEach-Object Name) -join ', ')) -ForegroundColor Yellow
        return 0
    }

    if (-not $Yes) {
        $answer = Read-Host ("Install {0} package(s): {1}? [y/N]" -f $missing.Count, (($missing | ForEach-Object Name) -join ', '))
        if ($answer -notmatch '^(y|yes)$') {
            Write-Host 'Aborted; nothing installed.' -ForegroundColor Yellow
            return 0
        }
    }

    $installed = @(); $failed = @(); $bucketsDone = $false
    foreach ($r in $missing) {
        Write-Host ''
        Write-Host "-> $($r.Name)" -ForegroundColor Cyan
        if ($r.Pkg.Scoop -and -not $bucketsDone) { Add-ScoopBuckets $ScoopBuckets; $bucketsDone = $true }
        $ok = $false
        try { $ok = [bool](Install-Package $r.Pkg) } catch { Write-Host "  $_" -ForegroundColor Red }
        Update-SessionPath
        if ($ok) {
            try { Invoke-AfterInstall $r.Pkg } catch { Write-Host "  follow-up failed: $_" -ForegroundColor Yellow }
            $installed += $r.Name
        } else {
            $failed += $r.Name
        }
    }

    $present = @($results | Where-Object { $_.Status -eq 'present' }).Count
    Write-Host ''
    Write-Host '== Summary ==' -ForegroundColor Cyan
    Write-Host ("installed:       {0}" -f ($(if ($installed) { $installed -join ', ' } else { '-' })))
    Write-Host ("already present: {0}" -f $present)
    if ($failed) {
        Write-Host ("failed:          {0}" -f ($failed -join ', ')) -ForegroundColor Red
    } else {
        Write-Host 'failed:          -'
    }
    if ($installed) {
        Write-Host 'Open a new shell to pick up PATH changes.' -ForegroundColor DarkGray
    }
    return $failed.Count
}
