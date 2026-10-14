# Install the skill into a Roblox game repo (PowerShell twin of install.sh; pwsh 7 / Windows PowerShell 5.1).
# usage: .\adapters\install.ps1 <target repo> [claude] [codex] [antigravity] [cursor] [opencode] [all]
#   Always copies: AGENTS.md, SKILL.md, INSTALL_FOR_AGENTS.md, docs\, tools\, scripts\, assets\. Never overwrites an
#   existing file unless $env:FORCE='1'. Then downloads Lune 0.8.9 -> tools\lune.exe and 0.10.5 -> tools\lune10.exe
#   (tools\get-lune.ps1); set $env:NO_LUNE='1' to skip. See docs/windows.md.
$ErrorActionPreference = 'Stop'
if ($args.Count -lt 1 -or -not $args[0]) { [Console]::Error.WriteLine('usage: install.ps1 <target repo> [claude|codex|antigravity|cursor|opencode|all]'); exit 1 }
$SRC = (Resolve-Path (Join-Path $PSScriptRoot '..')).ProviderPath
New-Item -ItemType Directory -Force -Path ([string]$args[0]) | Out-Null
$DST = (Resolve-Path -LiteralPath ([string]$args[0])).ProviderPath
$TARGETS = @($args | Select-Object -Skip 1 | ForEach-Object { [string]$_ })

function Copy-Safe([string]$From, [string]$To) {
    if ((Test-Path -LiteralPath $To) -and $env:FORCE -ne '1') { Write-Output "  skip (exists) $To"; return }
    $d = Split-Path -Parent $To; if ($d) { New-Item -ItemType Directory -Force -Path $d | Out-Null }
    Copy-Item -LiteralPath $From -Destination $To -Force; Write-Output "  + $To"
}
function Copy-Tree([string]$From, [string]$To) {
    $root = (Resolve-Path -LiteralPath $From).ProviderPath
    foreach ($f in (Get-ChildItem -LiteralPath $root -Recurse -File -Force | Sort-Object FullName)) {
        Copy-Safe $f.FullName (Join-Path $To $f.FullName.Substring($root.Length).TrimStart('\', '/'))
    }
}
function Test-Want([string]$Name) { return ($TARGETS -contains $Name) -or ($TARGETS -contains 'all') }

Write-Output 'core:'
Copy-Safe (Join-Path $SRC 'AGENTS.md') (Join-Path $DST 'AGENTS.md')
Copy-Safe (Join-Path $SRC 'SKILL.md') (Join-Path $DST 'SKILL.md')
Copy-Tree (Join-Path $SRC 'docs') (Join-Path $DST 'docs')
Copy-Safe (Join-Path $SRC 'INSTALL_FOR_AGENTS.md') (Join-Path $DST 'INSTALL_FOR_AGENTS.md')
Copy-Tree (Join-Path $SRC 'tools') (Join-Path $DST 'tools')
Copy-Tree (Join-Path $SRC 'scripts') (Join-Path $DST 'scripts')
Copy-Tree (Join-Path $SRC 'assets') (Join-Path $DST 'assets')
$A = Join-Path $SRC 'adapters'
if (Test-Want 'claude') { Write-Output 'claude code:'; Copy-Tree (Join-Path $A 'claude-code') $DST }
if (Test-Want 'codex') {
    Write-Output 'codex:'; Copy-Tree (Join-Path (Join-Path $A 'codex') '.agents') (Join-Path $DST '.agents')
    Write-Output '  (merge adapters\codex\config.toml.example into %USERPROFILE%\.codex\config.toml yourself)'
}
if (Test-Want 'antigravity') { Write-Output 'antigravity:'; Copy-Tree (Join-Path (Join-Path $A 'antigravity') '.agents') (Join-Path $DST '.agents') }
if (Test-Want 'cursor') { Write-Output 'cursor:'; Copy-Tree (Join-Path (Join-Path $A 'cursor') '.cursor') (Join-Path $DST '.cursor') }
if (Test-Want 'opencode') { Write-Output 'opencode:'; Copy-Safe (Join-Path (Join-Path $A 'opencode') 'opencode.json') (Join-Path $DST 'opencode.json') }
$q = Join-Path $DST 'QUEUE.md'
if (-not (Test-Path -LiteralPath $q)) { [IO.File]::WriteAllText($q, "# QUEUE (version log) - format: docs/project-state-template.md`n"); Write-Output '  + QUEUE.md' }
$pj = Join-Path $DST 'PROJECT.md'
if (-not (Test-Path -LiteralPath $pj)) { [IO.File]::WriteAllText($pj, "# Project brief - template: docs/project-state-template.md`n"); Write-Output '  + PROJECT.md' }
$gi = Join-Path $DST '.gitignore'
$has = (Test-Path -LiteralPath $gi) -and (Select-String -LiteralPath $gi -Pattern '^\.env$' -Quiet)
if (-not $has) { [IO.File]::AppendAllText($gi, ".env`nwork/x/`nwork/rig/out/`n*.rbxl.log.txt`n"); Write-Output '  + .gitignore entries' }
if ($env:NO_LUNE -ne '1') {
    try { & (Join-Path $SRC 'tools\get-lune.ps1') $DST }
    catch { Write-Output ("  lune download failed: " + $_.Exception.Message + " - run tools\get-lune.ps1 later (needs internet)") }
}
Write-Output 'done. Next: set ROBLOX_API_KEY UNIVERSE_ID PLACE_ID (only to publish), read docs/windows.md'
exit 0
