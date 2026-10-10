# Diff two run_all log dirs: which tests changed rc, and per-log FAIL-line counts.
# PowerShell twin of compare_runs.sh (pwsh 7 / Windows PowerShell 5.1).
# usage: tools\rig\compare_runs.ps1 <base logdir> <new logdir>
if ($args.Count -lt 2) { [Console]::Error.WriteLine('usage: compare_runs.ps1 <base logdir> <new logdir>'); exit 1 }
$BaseDir = [string]$args[0]; $NewDir = [string]$args[1]   # (PowerShell names are case-insensitive)
function Read-Rc([string]$dir) {
    $h = [ordered]@{}; $f = Join-Path $dir 'rc.txt'
    if (Test-Path -LiteralPath $f) { foreach ($l in (Get-Content -LiteralPath $f)) { $p = $l.Trim() -split '\s+', 2; if ($p[0]) { $h[$p[0]] = $(if ($p.Count -gt 1) { $p[1] } else { '' }) } } }
    return $h
}
$ra = Read-Rc $BaseDir; $rb = Read-Rc $NewDir
Write-Output '== rc changes (base -> new)'
$names = @(@($ra.Keys) + @($rb.Keys) | Sort-Object -Unique -Culture ([Globalization.CultureInfo]::InvariantCulture))
$same = $true
foreach ($n in $names) {
    $x = if ($ra.Contains($n)) { $ra[$n] } else { 'MISSING' }
    $y = if ($rb.Contains($n)) { $rb[$n] } else { 'MISSING' }
    if ($x -ne $y) { Write-Output "  $n $x $y"; $same = $false }
}
if ($same) { Write-Output '  (identical rc set)' }
Write-Output '== FAIL-line counts that differ'
foreach ($f in (Get-ChildItem -Path (Join-Path $NewDir '*.log') -File -ErrorAction SilentlyContinue | Sort-Object Name)) {
    $n = $f.Name; $base = Join-Path $BaseDir $n
    $ca = if (Test-Path -LiteralPath $base) { @(Select-String -LiteralPath $base -Pattern 'FAIL' -SimpleMatch -CaseSensitive).Count } else { '-' }
    $cb = @(Select-String -LiteralPath $f.FullName -Pattern 'FAIL' -SimpleMatch -CaseSensitive).Count
    if ("$ca" -ne "$cb") { Write-Output "  ${n}: $ca -> $cb" }
}
Write-Output 'done'
exit 0
