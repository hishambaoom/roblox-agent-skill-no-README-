# FAST LANE, one command: build -> PC + phone screenshots -> fast tests -> publish (only if tests pass) -> ui-map refresh.
# PowerShell twin of go.sh (pwsh 7 / Windows PowerShell 5.1).
# usage: tools\rig\go.ps1 <name> [open=<MenuName>] [extra dump flags] [test names...]
#   tools\rig\go.ps1 v145 open=ShopFrame                                   # tweak a menu, check it, ship it
#   $env:NOPUBLISH='1'; tools\rig\go.ps1 v145 open=ShopFrame               # same, but stop before publishing
# Typical wall time in the reference project: build ~2 s, shots ~1-2 s, fast tests ~3 s, publish ~3-5 s.
. (Join-Path $PSScriptRoot 'config.ps1')
if ($args.Count -lt 1 -or -not $args[0]) { Exit-RigUsage 'usage: go.ps1 <name> [open=Menu] [flags] [tests...]' }
$N = [string]$args[0]
$SHOT = @(); $TST = @()
foreach ($a in ($args | Select-Object -Skip 1)) {
    $a = [string]$a
    if ($a -like 'open=*' -or $a -eq 'touch' -or $a -eq 'lair' -or $a -like '*=*') { $SHOT += $a } else { $TST += $a }
}
New-Item -ItemType Directory -Force -Path $XDIR | Out-Null
$P = Join-Path $XDIR "$N.rbxl"
$t0 = [Diagnostics.Stopwatch]::StartNew()
$blog = Join-Path $XDIR "$N.build.log"
$rc = Invoke-RigProc $LUNE @('run', (Join-Path $GAME_DIR 'build.luau')) $blog @{ BUILD_OUT = $P }
if ($rc -ne 0) { Write-Output "BUILD FAIL ($blog)"; Get-Content -LiteralPath $blog -Tail 5; exit 1 }

$sh = Get-RigShell
$shotArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $PSScriptRoot 'shot.ps1'), $P, $N) + $SHOT
New-Item -ItemType Directory -Force -Path $RIG_OUT | Out-Null
$S = Start-RigProc $sh $shotArgs (Join-Path $RIG_OUT "$N.shot.log")
$pcPng = Join-Path $RIG_OUT "${N}_pc.png"; $phPng = Join-Path $RIG_OUT "${N}_phone.png"
& (Join-Path $PSScriptRoot 'fast.ps1') $P @TST
if ($LASTEXITCODE -ne 0) {
    $null = Wait-RigProc $S
    Write-Output "TESTS FAIL - not published. shots: $pcPng $phPng"; exit 1
}
$null = Wait-RigProc $S
Write-Output "shots: $pcPng $phPng   <- LOOK at both before reporting"
if ($env:NOPUBLISH -eq '1') { Write-Output "NOPUBLISH=1: built + tested, not published ($P)" }
else { & (Join-Path $PSScriptRoot 'publish.ps1') $P; if ($LASTEXITCODE -ne 0) { exit 1 } }
$uimap = Join-Path (Join-Path 'tools' 'uimap') 'uimap_build.py'
if (Test-Path -LiteralPath $uimap) {   # background, not waited for (like `( ... & )` in go.sh)
    $py = Get-RigPython
    $null = Start-RigProc $py[0] (@($py | Select-Object -Skip 1) + @($uimap, $P)) (Join-Path $RIG_OUT 'uimap.log')
}
Write-Output "total $([int][Math]::Floor($t0.Elapsed.TotalSeconds)) s"
exit 0
