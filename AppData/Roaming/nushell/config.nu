# config.nu: the single Nushell config file.
#
# PATH lives in Windows PATH, not here. The one exception is the MSVC section,
# whose folders carry the toolset version and only work alongside INCLUDE/LIB.

# --- Shell -------------------------------------------------------------------

$env.config.show_banner = false
$env.config.buffer_editor = 'C:\nvim\bin\nvim.exe'
$env.config.history.max_size = 100_000

$env.COMPUTER_ID = '01'

# --- Editor ------------------------------------------------------------------

$env.EDITOR = 'C:\nvim\bin\nvim.exe'
$env.VISUAL = 'C:\nvim\bin\nvim.exe'

# --- Compilers: MSVC, with Visual Studio's CMake and Ninja -------------------
#
# vcvars64.bat takes seconds, so its result is cached in ~/.cache/msvc-env.json.
# The cache regenerates when VS updates its default toolset. To force that, run
# `msvc-refresh`.

const MSVC_VERSION_FILE = 'VC\Auxiliary\Build\Microsoft.VCToolsVersion.default.txt'
const MSVC_CMAKE_SUBDIR = 'Common7\IDE\CommonExtensions\Microsoft\CMake'
# VCPKG_ROOT is left out on purpose: vcvars points it at VS's bundled vcpkg.
const MSVC_VARS = [
    INCLUDE LIB LIBPATH VCINSTALLDIR VCToolsInstallDir VCToolsVersion
    VSINSTALLDIR VisualStudioVersion WindowsSdkDir WindowsSDKVersion
    UCRTVersion UniversalCRTSdkDir
]

def msvc-cache-file [] {
    $nu.home-dir | path join '.cache' 'msvc-env.json'
}

def msvc-read-version [root: string] {
    open --raw ($root | path join $MSVC_VERSION_FILE) | str trim
}

def msvc-cache-is-current [] {
    let file = (msvc-cache-file)
    if not ($file | path exists) { return false }
    let cache = (open $file)
    if not ($cache.root | path join $MSVC_VERSION_FILE | path exists) { return false }
    (msvc-read-version $cache.root) == $cache.version
}

def msvc-generate-cache [] {
    let vswhere = 'C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe'
    let root = (
        ^$vswhere -latest -products '*'
            -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64
            -property installationPath
        | str trim
    )
    if ($root | is-empty) { error make {msg: 'vswhere found no Visual Studio with C++ tools'} }

    let file = (msvc-cache-file)
    mkdir ($file | path dirname)
    let bat = $'($file).bat'

    # Start vcvars from a clean state, so everything it adds to PATH is visible
    # even when this shell already has the MSVC environment loaded.
    [
        '@echo off'
        ...($MSVC_VARS | each {|name| $'set ($name)=' })
        'set "PATH=%SystemRoot%\system32;%SystemRoot%;%SystemRoot%\System32\WindowsPowerShell\v1.0;%ProgramFiles(x86)%\Microsoft Visual Studio\Installer"'
        $'call "($root)\VC\Auxiliary\Build\vcvars64.bat" >nul || exit /b 1'
        'set'
    ] | str join "\r\n" | save --force $bat

    let result = (^cmd.exe /c $bat | complete)
    rm --force $bat
    if $result.exit_code != 0 { error make {msg: 'vcvars64.bat failed'} }

    let vars = (
        $result.stdout | lines
        | parse --regex '^(?<name>[^=]+)=(?<value>.*)$'
    )
    let path_value = ($vars | where {|row| ($row.name | str uppercase) == 'PATH' } | first | get value)
    let msvc_path = (
        $path_value | split row ';'
        | where {|dir|
            let lower = ($dir | str lowercase)
            not (
                ($lower | is-empty)
                or ($lower | str starts-with 'c:\windows')
                or ($lower | str contains 'vcpkg')
                or ($lower | str ends-with '\cmake\cmake\bin')
                or ($lower | str ends-with '\cmake\ninja')
            )
        }
    )
    let env_vars = (
        $vars | where name in $MSVC_VARS
        | reduce --fold {} {|row, acc| $acc | insert $row.name $row.value }
    )
    if 'INCLUDE' not-in $env_vars { error make {msg: 'vcvars64.bat did not set INCLUDE'} }

    {
        version: (msvc-read-version $root)
        root: $root
        path: [
            ($root | path join $MSVC_CMAKE_SUBDIR 'CMake' 'bin')
            ($root | path join $MSVC_CMAKE_SUBDIR 'Ninja')
            ...$msvc_path
        ]
        env: $env_vars
    } | save --force $file
}

def --env msvc-load [] {
    let cache = (open (msvc-cache-file))
    load-env $cache.env
    # PATH is still a string while config.nu runs under `nu --mcp`; a list otherwise.
    $env.PATH = ($cache.path ++ ($env.PATH | split row (char esep)) | uniq)
    $env.CC = 'cl'
    $env.CXX = 'cl'
    $env.CMAKE_GENERATOR = 'Ninja'
    $env.VCPKG_DEFAULT_TRIPLET = 'x64-windows'
}

# Rebuild the cached MSVC environment and load it into this shell.
def --env msvc-refresh [] {
    msvc-generate-cache
    msvc-load
}

$env.VCPKG_ROOT = 'D:\Projects\_Tools\vcpkg'

try {
    if not (msvc-cache-is-current) { msvc-generate-cache }
    msvc-load
} catch {|err|
    print --stderr $'config.nu: MSVC environment unavailable: ($err.msg)'
}

# --- daslang -----------------------------------------------------------------

$env.DASLANG_ROOT = 'C:\Programs\daslang'
$env.DASLANG_DIR = 'C:\Programs\daslang'
$env.DASLANG_BIN = 'C:\Programs\daslang\bin\Release\daslang.exe'

# Run a .das script through the daslang interpreter.
#   dasex [--log] [--pause] <script.das> [-- arg1 ...]
def --wrapped dasex [
    --log
    --pause
    script?: string
    ...args: string
] {
    if $script == null {
        print 'Usage: dasex [--log] [--pause] <script.das> [-- arg1 ...]'
        return
    }
    if not ($script | path exists) {
        print $'dasex: file not found: ($script)'
        return
    }
    let script_args = ($args | where $it != '--')
    mut cmd = [$script '-dasroot' $env.DASLANG_ROOT]
    if $log { $cmd = ($cmd | append '-log') }
    if $pause { $cmd = ($cmd | append '-pause') }
    if ($script_args | is-not-empty) { $cmd = ($cmd | append ['--' ...$script_args]) }
    ^$env.DASLANG_BIN ...$cmd
}

# --- Duin: DuinDasHost, the binding-aware daslang compile host ---------------

# DuinDasHost validates this with fopen, and falls back to the daslang root it
# derives from its own exe location if it's rejected.
$env.DUIN_DAS_ROOT = 'D:/Projects/CPP_Projects/Duin/Duin/vendor/daslang'
$env.DUIN_DASHOST_DIR = 'D:\Projects\CPP_Projects\Duin\DuinDasHost\bin\Debug-windows-x86_64\DuinDasHost'
$env.DUIN_DASHOST_BIN = ($env.DUIN_DASHOST_DIR | path join 'DuinDasHost.exe')

const DUIN_DEFAULT_PROJECT = 'D:/Projects/CPP_Projects/Duin/DuinDasHost/scripts/duindashost.das_project'

# Run DuinDasHost on a .das file from anywhere. Without --project, uses the
# DuinDasHost smoke-test project so a bare `dnsh foo.das` resolves dn_* modules.
#   dnsh <file.das> [--project <p.das_project>] [extra host args...]
def --wrapped dnsh [
    --project: string
    file?: string
    ...rest: string
] {
    if $file == null {
        print 'Usage: dnsh <file.das> [--project <p.das_project>] [host args...]'
        return
    }
    if not ($file | path exists) {
        print $'dnsh: file not found: ($file)'
        return
    }
    ^$env.DUIN_DASHOST_BIN $file --project ($project | default $DUIN_DEFAULT_PROJECT) ...$rest
}

def ddh-native-path [path: string] {
    $path | path expand | str replace --all '\' '/'
}

# The project is, in order: --project, the single *.das_project in the current
# directory, then the DuinDasHost smoke-test project.
def ddh-resolve-project [project?: string] {
    let chosen = if $project != null {
        $project
    } else {
        let found = (glob '*.das_project')
        if ($found | length) > 1 {
            error make {msg: $'ddh: multiple .das_project files in (pwd); pass --project'}
        }
        $found | get 0? | default $DUIN_DEFAULT_PROJECT
    }
    if not ($chosen | path exists) { error make {msg: $'ddh: project not found: ($chosen)'} }
    ddh-native-path $chosen
}

# Reads a field from the daemon's .ddh file. Returns null if it isn't there.
def ddh-field [ddh_file: string, field: string] {
    if not ($ddh_file | path exists) { return null }
    try { open --raw $ddh_file | from json | get --optional $field } catch { null }
}

# Sends one JSON request line, and returns the response. Empty if no daemon.
def ddh-send [ddh_file: string, request: string] {
    let port = (ddh-field $ddh_file port)
    if $port == null { return '' }
    let result = ($'($request)(char newline)' | ^ncat -w 5 127.0.0.1 ($port | into string) | complete)
    if $result.exit_code == 0 { $result.stdout | str trim } else { '' }
}

def ddh-alive [ddh_file: string] {
    ddh-send $ddh_file '{"ping":true}' | str contains '"ready":true'
}

def ddh-start [project: string] {
    let ddh_file = $'($project).ddh'
    if (ddh-alive $ddh_file) {
        print $'ddh: already running [port (ddh-field $ddh_file port), pid (ddh-field $ddh_file pid)]'
        return
    }
    # A leftover .ddh from a dead daemon has to go before respawning.
    rm --force $ddh_file
    print $'ddh: starting daemon for ($project) ...'
    let log = $'($project).ddh.log'
    # Start-Process detaches it, so the daemon survives this shell.
    ^powershell.exe -NoProfile -Command $"Start-Process -WindowStyle Hidden -FilePath '($env.DUIN_DASHOST_BIN)' -ArgumentList '--serve-tcp','--project','($project)' -RedirectStandardError '($log)' -RedirectStandardOutput '($project).ddh.out.log'"
    for attempt in 1..100 {
        if (ddh-alive $ddh_file) {
            print $'ddh: up on port (ddh-field $ddh_file port) [pid (ddh-field $ddh_file pid)]; log: ($log)'
            return
        }
        sleep 100ms
    }
    error make {msg: $'ddh: daemon did not come up in time; see ($log)'}
}

def ddh-stop [project: string] {
    let ddh_file = $'($project).ddh'
    if not ($ddh_file | path exists) {
        print 'ddh: no daemon [.ddh absent]'
        return
    }
    let daemon_pid = (ddh-field $ddh_file pid)
    ddh-send $ddh_file '{"quit":true}' | ignore
    # Give it a moment to remove its own .ddh, then force-kill if it lingers.
    for attempt in 1..30 {
        if not ($ddh_file | path exists) { break }
        sleep 100ms
    }
    if ($ddh_file | path exists) {
        if $daemon_pid != null { do --ignore-errors { ^taskkill /F /PID ($daemon_pid | into string) | ignore } }
        rm --force $ddh_file
    }
    print $'ddh: stopped [pid ($daemon_pid | default "?")]'
}

def ddh-compile [project: string, file: string, refresh: bool] {
    let ddh_file = $'($project).ddh'
    if not ($file | path exists) { error make {msg: $'ddh: file not found: ($file)'} }
    if not (ddh-alive $ddh_file) { error make {msg: $'ddh: no running daemon for ($project) [try: ddh start]'} }
    let request = {file: (ddh-native-path $file), project: $project}
    let request = if $refresh { $request | insert refresh true } else { $request }
    ddh-send $ddh_file ($request | to json --raw)
}

# Per-project DuinDasHost daemon manager (TCP, with a .ddh discovery file).
#
#   ddh start   [--project P]                       start daemon (no-op if up)
#   ddh stop    [--project P]                       stop daemon
#   ddh status  [--project P]                       is a daemon up?
#   ddh compile <file.das> [--project P] [--refresh]  compile against running daemon
#   ddh run     <file.das> [--project P] [--refresh]  start if needed, compile, stop
#
# --refresh re-reads the dn_* engine bindings from disk after you edit a binding
# .das. The default reuses the warm cached graph, so only the target recompiles.
def ddh [
    sub?: string
    file?: string
    --project: string
    --refresh
] {
    if $sub in [null help] {
        help ddh
        return
    }
    let resolved = (ddh-resolve-project $project)
    let ddh_file = $'($resolved).ddh'
    match $sub {
        'start' => { ddh-start $resolved }
        'stop' => { ddh-stop $resolved }
        'status' => {
            if (ddh-alive $ddh_file) {
                print $'ddh: UP   project=($resolved) port=(ddh-field $ddh_file port) pid=(ddh-field $ddh_file pid)'
            } else if ($ddh_file | path exists) {
                print $'ddh: STALE .ddh present but daemon not answering [($ddh_file)]'
            } else {
                print $'ddh: DOWN  project=($resolved)'
            }
        }
        'compile' | 'exec' => {
            if $file == null { error make {msg: 'Usage: ddh compile <file.das> [--project P] [--refresh]'} }
            ddh-compile $resolved $file $refresh
        }
        'run' => {
            if $file == null { error make {msg: 'Usage: ddh run <file.das> [--project P] [--refresh]'} }
            let started = not (ddh-alive $ddh_file)
            if $started { ddh-start $resolved }
            let response = (try { ddh-compile $resolved $file $refresh } catch {|err|
                if $started { ddh-stop $resolved }
                error make {msg: $err.msg}
            })
            if $started { ddh-stop $resolved }
            $response
        }
        _ => { error make {msg: $"ddh: unknown subcommand '($sub)' [try: ddh help]"} }
    }
}

# --- raylib ------------------------------------------------------------------

$env.RAYLIB_DIR = 'D:\Projects\C_Libs\raylib\build\shared\raylib'

# --- Zellij ------------------------------------------------------------------

$env.ZELLIJ_CONFIG_DIR = ($nu.home-dir | path join '.config' 'zellij')

# --- Tools -------------------------------------------------------------------

# Windows' tar reads zip files, so this stands in for unzip.
def unzip [archive: path] {
    ^tar -xf $archive
}

# --- zoxide ------------------------------------------------------------------
# A parent nu (e.g. one that launched zellij) passes __zoxide_hooked down as the
# string "true", which the generated check below can't use as a boolean. The hook
# itself lives in $env.config and isn't inherited, so clear it to register again.
if ($env.__zoxide_hooked? | describe) == 'string' { hide-env __zoxide_hooked }

# Paste the output of `zoxide init nushell` below this line.
# Code generated by zoxide. DO NOT EDIT.

# =============================================================================
#
# Hook configuration for zoxide.
#

# Initialize hook to add new entries to the database.
if (not ($env | default false __zoxide_hooked | get __zoxide_hooked)) {
  $env.__zoxide_hooked = true
  $env.config = ($env | default {} config).config
  $env.config = ($env.config | default {} hooks)
  $env.config = ($env.config | update hooks ($env.config.hooks | default {} env_change))
  $env.config = ($env.config | update hooks.env_change ($env.config.hooks.env_change | default [] PWD))
  $env.config = ($env.config | update hooks.env_change.PWD ($env.config.hooks.env_change.PWD | append {|_, dir|
    zoxide add -- $dir
  }))
}

# =============================================================================
#
# When using zoxide with --no-cmd, alias these internal functions as desired.
#

# Jump to a directory using only keywords.
def --env __zoxide_z [...rest:string] {
  let arg0 = ($rest | append '~').0
  let path = if (($rest | length) <= 1) and ($arg0 == '-' or ($arg0 | path expand | path type) == dir) {
    $arg0
  } else {
    (zoxide query --exclude $env.PWD -- ...$rest | str trim -r -c "\n")
  }
  cd $path
}

# Jump to a directory using interactive search.
def --env __zoxide_zi [...rest:string] {
  cd $'(zoxide query --interactive -- ...$rest | str trim -r -c "\n")'
}

# =============================================================================
#
# Commands for zoxide. Disable these using --no-cmd.
#

alias z = __zoxide_z
alias zi = __zoxide_zi

# =============================================================================
#
# Add this to your env file (find it by running `$nu.env-path` in Nushell):
#
#   zoxide init nushell | save -f ~/.zoxide.nu
#
# Now, add this to the end of your config file (find it by running
# `$nu.config-path` in Nushell):
#
#   source ~/.zoxide.nu
#
# Note: zoxide only supports Nushell v0.89.0+.








mkdir ($nu.data-dir | path join "vendor/autoload")
starship init nu | save -f ($nu.data-dir | path join "vendor/autoload/starship.nu")