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
$gitRoot = Split-Path -Parent (Split-Path -Parent $bash)
$onPath = $env:PATH -split ';'
foreach ($dir in @("$gitRoot\usr\bin", "$gitRoot\mingw64\bin")) {
    if ((Test-Path -LiteralPath $dir) -and ($onPath -notcontains $dir)) {
        $env:PATH = "$dir;$env:PATH"
    }
}

& $bash (ConvertTo-PosixPath $syPath) @args
exit $LASTEXITCODE
