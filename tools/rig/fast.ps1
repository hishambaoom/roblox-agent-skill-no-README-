# Fast tests: the STRICT guard tests ($env:FAST_TESTS) + any tests you name, all in parallel, one-line summary.
# PowerShell twin of fast.sh (pwsh 7 / Windows PowerShell 5.1).
# usage: tools\rig\fast.ps1 <place.rbxl> [test names or paths...]
#   tools\rig\fast.ps1 work\x\v145.rbxl shop_cards_test
# Exit 0 only if every test exits 0. Logs: $RIG_OUT\fast\<test>.log (+ <test>.rc)
. (Join-Path $PSScriptRoot 'config.ps1')
if ($args.Count -lt 1 -or -not $args[0]) { Exit-RigUsage 'usage: fast.ps1 <place> [tests...]' }
$P = [string]$args[0]; $rest = @($args | Select-Object -Skip 1)
if (-not (Test-Path -LiteralPath $P -PathType Leaf)) { Write-Output "fast.ps1: no place $P"; exit 2 }
$D = Join-Path $RIG_OUT 'fast'; New-Item -ItemType Directory -Force -Path $D | Out-Null
Get-ChildItem -LiteralPath $D -Filter '*.rc' -File -ErrorAction SilentlyContinue | Remove-Item -Force
$sw = [Diagnostics.Stopwatch]::StartNew()

function Resolve-Test([string]$x) {
    if (Test-Path -LiteralPath $x -PathType Leaf) { return $x }
    $a = Join-Path $TESTS "$x.luau"; if (Test-Path -LiteralPath $a -PathType Leaf) { return $a }
    $b = Join-Path $TESTS $x;        if (Test-Path -LiteralPath $b -PathType Leaf) { return $b }
    return $null
}

$jobs = @()
foreach ($t in ($FAST_TESTS -split '\s+' | Where-Object { $_ })) {
    $f = Resolve-Test $t
    if ($f) { $jobs += [pscustomobject]@{ N = $t; R = (Start-RigProc $LUNE @('run', $f, $P) (Join-Path $D "$t.log") @{ STRICT = '1' }) } }
}
foreach ($x in $rest) {
    $f = Resolve-Test ([string]$x)
    if (-not $f) { Write-Output "fast.ps1: no test $x"; foreach ($j in $jobs) { $null = Wait-RigProc $j.R }; exit 2 }
    $n = [IO.Path]::GetFileNameWithoutExtension($f)
    $jobs += [pscustomobject]@{ N = $n; R = (Start-RigProc $LUNE @('run', $f, $P) (Join-Path $D "$n.log") @{ FAST = '1' }) }
}
foreach ($j in $jobs) { $rc = Wait-RigProc $j.R; Set-Content -LiteralPath (Join-Path $D "$($j.N).rc") -Value $rc -Encoding ascii }

$pass = 0; $fail = 0; $s = ''
foreach ($r in (Get-ChildItem -LiteralPath $D -Filter '*.rc' -File | Sort-Object Name)) {
    $n = $r.BaseName
    if ((Get-Content -LiteralPath $r.FullName -Raw).Trim() -eq '0') { $pass++; $s += " ${n}:ok" } else { $fail++; $s += " ${n}:FAIL" }
}
$verdict = if ($fail -eq 0) { 'PASS' } else { 'FAIL' }
Write-Output ("fast {0}: {1} pass / {2} fail |{3}  ({4} s, logs {5})" -f $verdict, $pass, $fail, $s, (Format-RigSeconds $sw.Elapsed.TotalSeconds), $D)
if ($fail -eq 0) { exit 0 } else { exit 1 }
