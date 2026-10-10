# Approximate screenshots of a BUILT place, without Studio: PC 1920x1080 + phone 667x375 (touch).
# PowerShell twin of shot.sh (pwsh 7 / Windows PowerShell 5.1).
# usage: tools\rig\shot.ps1 <place.rbxl> <name> [open=<MenuName>] [extra flags passed to the dump]
#   -> $RIG_OUT\<name>_pc.png + $RIG_OUT\<name>_phone.png   (dumps in $RIG_OUT\<name>_{pc,phone}\)
# These are rbxsim layout approximations (icons/3D = placeholders). They catch overflow, overlap, tiny text and
# off-screen elements in ~1-2 s. They are NOT a device test: say "rig render" in reports, never "verified on phone".
# Needs tools\rig\dump.luau (copy dump.example.luau and adapt its boot section to your game) + render.py (Pillow).
. (Join-Path $PSScriptRoot 'config.ps1')
if ($args.Count -lt 2) { Exit-RigUsage 'usage: shot.ps1 <place.rbxl> <name> [open=Menu] [flags...]' }
$P = [string]$args[0]; $N = [string]$args[1]; $extra = @($args | Select-Object -Skip 2 | ForEach-Object { [string]$_ })
if (-not (Test-Path -LiteralPath $P -PathType Leaf)) { Write-Output "shot.ps1: no place $P"; exit 2 }
$DUMP = Join-Path $PSScriptRoot 'dump.luau'; if (-not (Test-Path -LiteralPath $DUMP)) { $DUMP = Join-Path $PSScriptRoot 'dump.example.luau' }
$O = $RIG_OUT
$pcDir = Join-Path $O "${N}_pc"; $phDir = Join-Path $O "${N}_phone"
New-Item -ItemType Directory -Force -Path $pcDir, $phDir | Out-Null
$sw = [Diagnostics.Stopwatch]::StartNew()
$a = Start-RigProc $LUNE (@('run', $DUMP, $P, $pcDir, $PC_W, $PC_H) + $extra) (Join-Path $pcDir 'dump.log')
$b = Start-RigProc $LUNE (@('run', $DUMP, $P, $phDir, $PHONE_W, $PHONE_H, 'touch') + $extra) (Join-Path $phDir 'dump.log')
$rc = 0; if ((Wait-RigProc $a) -ne 0) { $rc = 1 }; if ((Wait-RigProc $b) -ne 0) { $rc = 1 }
if ($rc -ne 0) {
    Write-Output 'shot.ps1: dump failed'
    foreach ($l in (Join-Path $pcDir 'dump.log'), (Join-Path $phDir 'dump.log')) { Write-Output "==> $l <=="; Get-Content -LiteralPath $l -Tail 5 }
    exit 1
}
$py = Get-RigPython; $render = Join-Path $PSScriptRoot 'render.py'
$pcPng = Join-Path $O "${N}_pc.png"; $phPng = Join-Path $O "${N}_phone.png"
$r1 = Start-RigProc $py[0] (@($py | Select-Object -Skip 1) + @($render, (Join-Path $pcDir "${PC_W}x${PC_H}.json"), $pcPng)) (Join-Path $pcDir 'render.log')
$r2 = Start-RigProc $py[0] (@($py | Select-Object -Skip 1) + @($render, (Join-Path $phDir "${PHONE_W}x${PHONE_H}.json"), $phPng)) (Join-Path $phDir 'render.log')
# like shot.sh, a render failure does not change the exit code - but say so
if ((Wait-RigProc $r1) -ne 0) { [Console]::Error.WriteLine("shot.ps1: render failed, see $(Join-Path $pcDir 'render.log')") }
if ((Wait-RigProc $r2) -ne 0) { [Console]::Error.WriteLine("shot.ps1: render failed, see $(Join-Path $phDir 'render.log')") }
Write-Output ("shot {0}: {1} {2}  ({3} s)" -f $N, $pcPng, $phPng, (Format-RigSeconds $sw.Elapsed.TotalSeconds))
exit 0
