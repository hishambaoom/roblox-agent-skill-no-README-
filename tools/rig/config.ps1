# Shared settings for the PowerShell rig scripts (Windows-native twin of config.sh). Dot-source it; override any
# value from the environment. Run every rig script from your game repo root (the folder that holds tools\ and games\).
# Works in PowerShell 7 (pwsh) and Windows PowerShell 5.1. See docs/windows.md.
#
#   $env:ROBLOX_API_KEY = '...'   # Open Cloud key with universe-places:write (NEVER commit it)
#   $env:UNIVERSE_ID = '<your-universe-id>'; $env:PLACE_ID = '<your-place-id>'
#
# Everything here is also exported to $env: so child processes (Lune, Python, nested scripts) see the same values.

$RIG_ON_WINDOWS = ($PSVersionTable.PSVersion.Major -lt 6) -or $IsWindows

function Set-RigDefault([string]$Name, [string]$Value) {
    $cur = [Environment]::GetEnvironmentVariable($Name)
    if ([string]::IsNullOrEmpty($cur)) { $cur = $Value; [Environment]::SetEnvironmentVariable($Name, $cur) }
    Set-Variable -Name $Name -Value $cur -Scope Script
}

# Resolve a program: an existing file (also tries <name>.exe), else a command on PATH, else the name unchanged.
function Get-RigExe([string]$Path) {
    if (Test-Path -LiteralPath $Path -PathType Leaf) { return (Resolve-Path -LiteralPath $Path).ProviderPath }
    if (Test-Path -LiteralPath "$Path.exe" -PathType Leaf) { return (Resolve-Path -LiteralPath "$Path.exe").ProviderPath }
    $c = Get-Command $Path -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($c) { return $c.Path }
    return $Path
}

$_defLune = if ($RIG_ON_WINDOWS) { Join-Path 'tools' 'lune.exe' } else { Join-Path 'tools' 'lune' }
if (-not (Test-Path -LiteralPath $_defLune) -and (Test-Path -LiteralPath (Join-Path 'tools' 'lune'))) { $_defLune = Join-Path 'tools' 'lune' }
$_defLune10 = if ($RIG_ON_WINDOWS) { Join-Path 'tools' 'lune10.exe' } else { Join-Path 'tools' 'lune10' }

Set-RigDefault GAME_DIR   (Join-Path 'games' 'my-game')       # the game folder: build.luau, build_*.luau hooks, src\, tests\
Set-RigDefault LUNE       $_defLune                          # Lune binary for builds + tests (0.8.9 in the reference project)
Set-RigDefault LUNE_NEW   $_defLune10                        # newer Lune (0.10.x) for place files saved by a recent Studio
Set-RigDefault TESTS      (Join-Path $GAME_DIR 'tests')       # Lune test folder
Set-RigDefault XDIR       (Join-Path 'work' 'x')              # scratch builds: work\x\<name>.rbxl
Set-RigDefault RIG_OUT    (Join-Path (Join-Path 'work' 'rig') 'out')   # screenshots + fast-test logs
Set-RigDefault CANON      (Join-Path (Join-Path $GAME_DIR 'build') 'game.rbxl')  # "what is live" copy written by publish
Set-RigDefault FAST_TESTS 'studio_rule_test text_size_test'  # always-run guard tests (STRICT)
Set-RigDefault PHONE_W '667'; Set-RigDefault PHONE_H '375'    # iPhone SE/8 landscape: smallest common phone
Set-RigDefault PC_W '1920';   Set-RigDefault PC_H '1080'

# Python: $env:PYTHON if set, else python / python3 (skipping the Microsoft Store stub), else the py launcher (py -3).
function Get-RigPython {
    if ($env:PYTHON) { return ,@((Get-RigExe $env:PYTHON)) }
    foreach ($n in 'python', 'python3') {
        $c = Get-Command $n -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $c) { continue }
        & $c.Path -c 'import sys' 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) { return ,@($c.Path) }
    }
    $py = Get-Command py -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($py) { return ,@($py.Path, '-3') }
    return ,@('python')
}

# Quote one argument for a Windows command line (CommandLineToArgvW rules).
function ConvertTo-RigArg([string]$a) {
    if ($a -ne '' -and $a -notmatch '[\s"]') { return $a }
    return '"' + (($a -replace '(\\*)"', '$1$1\"') -replace '(\\+)$', '$1$1') + '"'
}

# Start a program in the background, stdout+stderr to $Log (merged when it is waited for). $Env: extra variables
# for this child only. Returns a handle for Wait-RigProc.
function Start-RigProc([string]$Exe, [string[]]$ArgList, [string]$Log, [hashtable]$Env = @{}) {
    $dir = Split-Path -Parent $Log
    if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    $saved = @{}
    foreach ($k in $Env.Keys) { $saved[$k] = [Environment]::GetEnvironmentVariable($k); [Environment]::SetEnvironmentVariable($k, [string]$Env[$k]) }
    try {
        $sp = @{ FilePath = (Get-RigExe $Exe); NoNewWindow = $true; PassThru = $true
                 RedirectStandardOutput = $Log; RedirectStandardError = "$Log.err" }
        if ($ArgList -and $ArgList.Count) { $sp.ArgumentList = ($ArgList | ForEach-Object { ConvertTo-RigArg $_ }) -join ' ' }
        $p = Start-Process @sp
        $null = $p.Handle   # cache the handle so ExitCode is readable later
    } finally {
        foreach ($k in $saved.Keys) { [Environment]::SetEnvironmentVariable($k, $saved[$k]) }
    }
    return [pscustomobject]@{ P = $p; Log = $Log }
}

# Wait for a Start-RigProc handle (timeout like `timeout 600`, rc 124 on timeout); appends stderr to the log.
function Wait-RigProc($R, [int]$TimeoutSec = 600) {
    if (-not $R.P.WaitForExit($TimeoutSec * 1000)) { try { $R.P.Kill() } catch {}; $rc = 124 }
    else { $R.P.WaitForExit(); $rc = $R.P.ExitCode; if ($null -eq $rc) { $rc = 1 } }
    $err = "$($R.Log).err"
    for ($i = 0; $i -lt 20 -and (Test-Path -LiteralPath $err); $i++) {
        try {
            $bytes = [IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $err).ProviderPath)
            if ($bytes.Length) { $fs = [IO.File]::Open((Resolve-Path -LiteralPath $R.Log).ProviderPath, 'Append'); $fs.Write($bytes, 0, $bytes.Length); $fs.Close() }
            Remove-Item -LiteralPath $err -Force; break
        } catch { Start-Sleep -Milliseconds 50 }
    }
    return [int]$rc
}

# Run a program in the foreground with output to $Log; returns its exit code.
function Invoke-RigProc([string]$Exe, [string[]]$ArgList, [string]$Log, [hashtable]$Env = @{}, [int]$TimeoutSec = 600) {
    return Wait-RigProc (Start-RigProc $Exe $ArgList $Log $Env) $TimeoutSec
}

function Format-RigSeconds([double]$s) { return $s.ToString('0.0', [Globalization.CultureInfo]::InvariantCulture) }

# The PowerShell that is running us (pwsh.exe or powershell.exe), for nested scripts run in the background.
function Get-RigShell { return [Diagnostics.Process]::GetCurrentProcess().MainModule.FileName }

# HTTP helpers (Invoke-WebRequest behaves differently in 5.1 and 7): status code + body text of a failed request.
function Get-RigHttpError($E) {
    $code = '000'; $body = ''
    $resp = $E.Exception.Response
    if ($resp) {
        $code = [string][int]$resp.StatusCode
        if ($E.ErrorDetails -and $E.ErrorDetails.Message) { $body = $E.ErrorDetails.Message }
        elseif ($resp.PSObject.Methods['GetResponseStream']) {   # 5.1: HttpWebResponse
            try { $body = (New-Object IO.StreamReader($resp.GetResponseStream())).ReadToEnd() } catch {} }
        elseif ($resp.Content) {                                 # 7: HttpResponseMessage
            try { $body = $resp.Content.ReadAsStringAsync().GetAwaiter().GetResult() } catch {} }
    } else { $body = $E.Exception.Message }
    return @{ Code = $code; Body = $body }
}
function Get-RigBodyText($R) { if ($R.Content -is [byte[]]) { return [Text.Encoding]::UTF8.GetString($R.Content) }; return [string]$R.Content }
# first 300 chars on one line (like `head -c 300`, minus the pretty-printing pwsh adds to JSON error bodies)
function Get-RigHead([string]$s) {
    if ($null -eq $s) { return '' }
    $s = ($s -replace '\s*\r?\n\s*', ' ').Trim()
    if ($s.Length -gt 300) { return $s.Substring(0, 300) }; return $s
}

function Exit-RigUsage([string]$Msg) { [Console]::Error.WriteLine($Msg); exit 1 }
