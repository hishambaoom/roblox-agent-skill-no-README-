# Download the two Lune versions the rig needs into <game repo>\tools\ (PowerShell 7 / Windows PowerShell 5.1).
# usage: .\tools\get-lune.ps1 [<game repo>]      (default: current folder)
#   tools\lune.exe   = Lune 0.8.9  (builds + tests)
#   tools\lune10.exe = Lune 0.10.5 (place files saved by a recent Studio)
# Skips a binary that already exists unless $env:FORCE='1'. Override versions with $env:LUNE_V8 / $env:LUNE_V10.
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'   # Invoke-WebRequest is 10x slower with the progress bar on 5.1
try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch {}
$root = if ($args.Count -ge 1 -and $args[0]) { [string]$args[0] } else { (Get-Location).ProviderPath }
$tools = Join-Path $root 'tools'
New-Item -ItemType Directory -Force -Path $tools | Out-Null
$v8 = if ($env:LUNE_V8) { $env:LUNE_V8 } else { '0.8.9' }
$v10 = if ($env:LUNE_V10) { $env:LUNE_V10 } else { '0.10.5' }

$isWin = ($env:OS -eq 'Windows_NT') -or ($PSVersionTable.PSEdition -eq 'Desktop') -or ((Get-Variable IsWindows -ErrorAction SilentlyContinue) -and $IsWindows)
if ($isWin) {
    $os = 'windows'; $ext = '.exe'
    $a = if ($env:PROCESSOR_ARCHITEW6432) { $env:PROCESSOR_ARCHITEW6432 } else { $env:PROCESSOR_ARCHITECTURE }
    $arch = if ($a -eq 'ARM64') { 'aarch64' } else { 'x86_64' }
} else {
    $ext = ''
    $os = if ((Get-Variable IsMacOS -ErrorAction SilentlyContinue) -and $IsMacOS) { 'macos' } else { 'linux' }
    $m = (& uname -m).Trim()
    $arch = if ($m -eq 'arm64' -or $m -eq 'aarch64') { 'aarch64' } else { 'x86_64' }
}

function Get-Lune([string]$Ver, [string]$OutName) {
    $out = Join-Path $tools ($OutName + $ext)
    if ((Test-Path -LiteralPath $out) -and $env:FORCE -ne '1') { Write-Output "  skip (exists) $out"; return }
    $myArch = $arch
    # Lune 0.8.x ships no Windows ARM build; x64 runs under emulation on ARM PCs.
    if ($os -eq 'windows' -and $Ver.StartsWith('0.8') -and $myArch -eq 'aarch64') { $myArch = 'x86_64' }
    $zipName = "lune-$Ver-$os-$myArch.zip"
    $url = "https://github.com/lune-org/lune/releases/download/v$Ver/$zipName"
    $tmp = Join-Path ([IO.Path]::GetTempPath()) ("lune-" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force -Path $tmp | Out-Null
    try {
        $zip = Join-Path $tmp $zipName
        Write-Output "  downloading $url"
        Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing
        Expand-Archive -LiteralPath $zip -DestinationPath $tmp -Force
        $bin = Get-ChildItem -LiteralPath $tmp -Recurse -File | Where-Object { $_.Name -eq ('lune' + $ext) } | Select-Object -First 1
        if (-not $bin) { throw "lune$ext not found inside $zipName" }
        Copy-Item -LiteralPath $bin.FullName -Destination $out -Force
        if ($isWin) { try { Unblock-File -LiteralPath $out } catch {} } else { & chmod +x $out }
        $got = (& $out --version) 2>&1 | Out-String
        Write-Output ("  + $out  (" + $got.Trim() + ")")
    } finally { Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue }
}

Write-Output "lune ($os-$arch):"
Get-Lune $v8 'lune'
Get-Lune $v10 'lune10'
Write-Output 'done.'
exit 0
