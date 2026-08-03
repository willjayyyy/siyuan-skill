<#
.SYNOPSIS
    Windows entry point for the SiYuan client. Runs `sy` under Git Bash.

.DESCRIPTION
    `sy` is a shell script. PowerShell and CMD cannot execute it directly —
    Windows dispatches on file extension and knows nothing about the `#!` line.
    This wrapper finds Git Bash and hands the script over to it, so that from
    PowerShell you can write:

        .\sy.ps1 nb
        .\sy.ps1 sql "SELECT COUNT(*) AS n FROM blocks WHERE type='d'"
        .\sy.ps1 /api/notebook/lsNotebooks -q '.notebooks|length'

    Inside Git Bash itself, call `sy` directly — this wrapper is not needed.

    Three Windows-specific problems are handled here:

    1. `bash` on PATH is usually C:\Windows\System32\bash.exe — that is WSL's
       bash, a separate Linux install that normally lacks jq and takes tens of
       seconds to cold-start. This wrapper deliberately skips it.
    2. MSYS2 rewrites arguments that look like POSIX paths, so an endpoint like
       /api/query/sql would arrive as C:/Program Files/Git/api/query/sql.
       MSYS2_ARG_CONV_EXCL=* switches that off.
    3. `sy` locates its own directory with dirname "${BASH_SOURCE[0]}", which
       fails on a backslashed Windows path, so the script path is converted to
       POSIX form (C:\x\y -> /c/x/y) before being passed in.

    The exit code is propagated unchanged — in particular 3, which means a
    destructive endpoint was refused and needs explicit confirmation.
#>

$ErrorActionPreference = 'Stop'

function Find-GitBash {
    # Build candidates only from variables that are actually set — passing $null
    # to Join-Path throws under ErrorActionPreference = 'Stop'.
    $candidates = @()
    foreach ($root in @($env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:ProgramW6432)) {
        if ($root) { $candidates += (Join-Path $root 'Git\bin\bash.exe') }
    }
    if ($env:LOCALAPPDATA) {
        $candidates += (Join-Path $env:LOCALAPPDATA 'Programs\Git\bin\bash.exe')
    }
    foreach ($c in $candidates) {
        if (Test-Path -LiteralPath $c) { return $c }
    }
    # Fall back to PATH, but never to WSL's bash under System32.
    $onPath = Get-Command bash.exe -All -ErrorAction SilentlyContinue |
              Where-Object { $_.Source -and $_.Source -notmatch '\\System32\\' }
    if ($onPath) { return $onPath[0].Source }
    return $null
}

function ConvertTo-PosixPath([string]$Path) {
    $full = (Resolve-Path -LiteralPath $Path).Path
    if ($full -match '^([A-Za-z]):\\(.*)$') {
        return '/' + $Matches[1].ToLower() + '/' + ($Matches[2] -replace '\\', '/')
    }
    return ($full -replace '\\', '/')
}

$bash = Find-GitBash
if (-not $bash) {
    Write-Error @'
Git Bash was not found, and the SiYuan client is a shell script that needs it.

Install Git for Windows, which provides bash, curl and iconv:

    winget install Git.Git

Then open a NEW PowerShell window and try again.

Note: WSL's bash (C:\Windows\System32\bash.exe) is deliberately not used — it is
a separate Linux environment, usually without jq, and slow to start.
'@
    exit 1
}

$syPath = Join-Path $PSScriptRoot 'sy'
if (-not (Test-Path -LiteralPath $syPath)) {
    Write-Error "sy not found next to this wrapper (expected: $syPath)"
    exit 1
}

# Keep MSYS2 from turning /api/... arguments into Windows paths.
$env:MSYS2_ARG_CONV_EXCL = '*'

# Put Git's Unix tools on PATH. bash.exe lives in <git>\bin, but dirname, sed,
# awk, mktemp and iconv live in <git>\usr\bin and curl in <git>\mingw64\bin.
# Windows' own PATH normally contains only <git>\cmd, and a non-login shell does
# not read /etc/profile — so without this, bash starts and then reports
# "dirname: command not found", which reads like a broken Git installation.
# Git's Unix tools: bash.exe sits in <git>\bin, but dirname, sed, awk, mktemp and
# iconv live in <git>\usr\bin and curl in <git>\mingw64\bin. Windows' PATH holds
# only <git>\cmd, and this is a non-login shell so it does not read /etc/profile
# — without these two entries bash starts and then reports
# "dirname: command not found", which reads like a broken Git installation.
#
# Scope note: this adds only what our own way of invoking bash took away. It
# deliberately does not touch PATH beyond that — if a tool you installed a moment
# ago is not visible yet, that is Windows handing every process a PATH snapshot
# at startup, and reopening the terminal is the right fix, not something for this
# wrapper to paper over.
$gitRoot = Split-Path -Parent (Split-Path -Parent $bash)
$onPath = $env:PATH -split ';'
foreach ($dir in @("$gitRoot\usr\bin", "$gitRoot\mingw64\bin")) {
    if ((Test-Path -LiteralPath $dir) -and ($onPath -notcontains $dir)) {
        $env:PATH = "$dir;$env:PATH"
    }
}

# jq is not part of Git for Windows, and package managers put it somewhere a
# restricted shell may not inherit: winget installs into a versioned Packages
# directory and exposes it through WinGet\Links, which sandboxed processes often
# do not see on PATH. Look in the standard install locations — but only when PATH
# does not already provide it, and only for this one call.
$jqSource = 'PATH'
if (-not (Get-Command jq.exe -ErrorAction SilentlyContinue)) {
    $jqCandidates = @()
    if ($env:LOCALAPPDATA) {
        $jqCandidates += (Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Links\jq.exe')
        $pkgRoot = Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages'
        if (Test-Path -LiteralPath $pkgRoot) {
            $found = Get-ChildItem -LiteralPath $pkgRoot -Filter 'jq.exe' -Recurse -Depth 2 `
                        -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($found) { $jqCandidates += $found.FullName }
        }
    }
    if ($env:USERPROFILE) { $jqCandidates += (Join-Path $env:USERPROFILE 'scoop\shims\jq.exe') }
    if ($env:ProgramData) { $jqCandidates += (Join-Path $env:ProgramData 'chocolatey\bin\jq.exe') }
    if ($env:ProgramFiles) { $jqCandidates += (Join-Path $env:ProgramFiles 'jq\jq.exe') }

    foreach ($c in $jqCandidates) {
        if ($c -and (Test-Path -LiteralPath $c)) {
            $env:PATH = "$(Split-Path -Parent $c);$env:PATH"
            $jqSource = $c
            break
        }
    }
}

# `sy.ps1 --diagnose` reports what the wrapper resolved and which tools bash can
# actually see. "command not found" alone cannot distinguish "not installed" from
# "installed but not on PATH", and that ambiguity has sent troubleshooting in the
# wrong direction more than once.
if ($args.Count -ge 1 -and $args[0] -eq '--diagnose') {
    Write-Host "sy.ps1 diagnostics"
    Write-Host "  wrapper     : $PSCommandPath"
    Write-Host "  git bash    : $bash"
    Write-Host "  git root    : $gitRoot"
    foreach ($d in @("$gitRoot\usr\bin", "$gitRoot\mingw64\bin")) {
        $state = if (Test-Path -LiteralPath $d) { 'present' } else { 'MISSING' }
        Write-Host ("  {0,-11}: {1}  [{2}]" -f (Split-Path $d -Leaf), $d, $state)
    }
    Write-Host "  jq          : $jqSource"
    Write-Host "  sy script   : $syPath"
    Write-Host "  passed as   : $(ConvertTo-PosixPath $syPath)"
    Write-Host "  tools visible to bash:"
    & $bash -c 'for t in dirname mktemp curl jq iconv awk grep cut head wc tr; do printf "    %-8s %s\n" "$t" "$(command -v "$t" 2>/dev/null || echo "NOT FOUND")"; done'
    Write-Host "  config      : $(if ($env:SIYUAN_CONF) { $env:SIYUAN_CONF } else { Join-Path $env:APPDATA 'siyuan\env' })"
    exit 0
}

& $bash (ConvertTo-PosixPath $syPath) @args
exit $LASTEXITCODE
