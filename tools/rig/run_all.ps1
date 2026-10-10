# FULL suite: every *.luau test in $TESTS against one place, in parallel. Writes rc.txt + one log per test.
# PowerShell twin of run_all.sh (pwsh 7 / Windows PowerShell 5.1).
# usage: tools\rig\run_all.ps1 <place.rbxl> <logdir>
# Compare two builds:
#   tools\rig\run_all.ps1 work\x\v144.rbxl work\logs\a; tools\rig\run_all.ps1 work\x\v145.rbxl work\logs\b
#   tools\rig\compare_runs.ps1 work\logs\a work\logs\b
# The rule is "same pass/fail set as the base build, plus the new test passing". Pre-existing failures are fine
# as long as they are known (stale assertions vs a later owner decision) and listed in the report.
. (Join-Path $PSScriptRoot 'config.ps1')
if ($args.Count -lt 2) { Exit-RigUsage 'usage: run_all.ps1 <place> <logdir>' }
$P = [string]$args[0]; $D = [string]$args[1]
New-Item -ItemType Directory -Force -Path $D | Out-Null
$rcFile = Join-Path $D 'rc.txt'
$jobs = @()
foreach ($f in (Get-ChildItem -Path (Join-Path $TESTS '*.luau') -File -ErrorAction SilentlyContinue)) {
    $n = $f.BaseName
    if ($n -eq 'rbxsim' -or $n -like '*_lib' -or $n -like '*sim') { continue }   # helpers, not tests
    $jobs += [pscustomobject]@{ N = $n; R = (Start-RigProc $LUNE @('run', $f.FullName, $P) (Join-Path $D "$n.log")) }
}
$lines = @(foreach ($j in $jobs) { "$($j.N) rc=$(Wait-RigProc $j.R)" })
$sorted = @($lines | Sort-Object -Culture ([Globalization.CultureInfo]::InvariantCulture))
if ($sorted.Count) { Set-Content -LiteralPath $rcFile -Value $sorted -Encoding ascii }
else { [IO.File]::WriteAllText($ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($rcFile), '') }
$ok = @($sorted | Where-Object { $_ -match 'rc=0$' }).Count
Write-Output "suite: $ok pass / $($sorted.Count - $ok) fail  (logs $D)"
exit 0
