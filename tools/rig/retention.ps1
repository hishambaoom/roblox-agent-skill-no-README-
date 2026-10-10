# Keep the newest build + 3 older ones in $XDIR (and the LIVE file named in the version log). Deletes the rest.
# PowerShell twin of retention.sh (pwsh 7 / Windows PowerShell 5.1).
# usage: tools\rig\retention.ps1 [keep=4]       $env:DRY='1' to only list what would go.
# Never deletes: the file the latest "DONE ... LIVE = <file>" line in QUEUE.md names, or $CANON.
. (Join-Path $PSScriptRoot 'config.ps1')
$KEEP = if ($args.Count -gt 0 -and $args[0]) { [int]$args[0] } else { 4 }
function Get-Full([string]$p) { $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($p) }
$LIVE = $null
if (Test-Path -LiteralPath 'QUEUE.md') {
    $m = Select-String -LiteralPath 'QUEUE.md' -Pattern 'LIVE = [^ ]+\.rbxl' -AllMatches | ForEach-Object { $_.Matches } | Select-Object -Last 1
    if ($m) { $LIVE = ($m.Value -split ' ')[2] }
}
$liveFull = if ($LIVE) { Get-Full $LIVE } else { $null }
$canonFull = Get-Full $CANON
$files = @(Get-ChildItem -Path (Join-Path $XDIR '*.rbxl') -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -Skip $KEEP)
foreach ($f in $files) {
    $rel = Join-Path $XDIR $f.Name
    if (($liveFull -and $f.FullName -eq $liveFull) -or $f.FullName -eq $canonFull) { Write-Output "keep (LIVE) $rel"; continue }
    if ($env:DRY -eq '1') { Write-Output "would delete $rel" }
    else {
        $base = $f.FullName.Substring(0, $f.FullName.Length - 5)
        Remove-Item -LiteralPath $f.FullName, "$($f.FullName).log.txt", "$base.build.log" -Force -ErrorAction SilentlyContinue
        Write-Output "deleted $rel"
    }
}
exit 0
