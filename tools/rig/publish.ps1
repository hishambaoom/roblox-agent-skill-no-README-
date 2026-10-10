# Publish a built place LIVE through Roblox Open Cloud (Place Publishing API). Only when the owner asked for it,
# or when the project's standing rule says fast-lane fixes ship after tests pass.
# PowerShell twin of publish.sh (pwsh 7 / Windows PowerShell 5.1).
# usage: tools\rig\publish.ps1 <place.rbxl>
# env:   ROBLOX_API_KEY (Open Cloud key, scope universe-places:write, restricted to this universe), UNIVERSE_ID, PLACE_ID
#        VERSION_TYPE=Published (default; live for players) | Saved (uploads a version without making it live)
#        OPEN_CLOUD_BASE (default https://apis.roblox.com; only for pointing the rig at a local mock server)
# Retries HTTP 409 (another publish/save in progress) up to 3 times with backoff. Prints versionNumber.
# Never hardcode the key in this file, a hook, a log, a commit or a chat message.
#        DRY_RUN=1 prints what would be sent (no network, no key needed) - use it to test the rig.
. (Join-Path $PSScriptRoot 'config.ps1')
if ($args.Count -lt 1 -or -not $args[0]) { Exit-RigUsage 'usage: publish.ps1 <place.rbxl>' }
$P = [string]$args[0]
if (-not (Test-Path -LiteralPath $P -PathType Leaf)) { Write-Output "publish.ps1: no place $P"; exit 2 }
$VT = if ($env:VERSION_TYPE) { $env:VERSION_TYPE } else { 'Published' }
$BASEURL = if ($env:OPEN_CLOUD_BASE) { $env:OPEN_CLOUD_BASE.TrimEnd('/') } else { 'https://apis.roblox.com' }
if ($env:DRY_RUN -eq '1') {
    $u = if ($env:UNIVERSE_ID) { $env:UNIVERSE_ID } else { '<UNIVERSE_ID>' }
    $pl = if ($env:PLACE_ID) { $env:PLACE_ID } else { '<PLACE_ID>' }
    $k = if ($env:ROBLOX_API_KEY) { 'set' } else { 'MISSING' }
    Write-Output "DRY_RUN: would POST $((Get-Item -LiteralPath $P).Length) bytes of $P to $BASEURL/universes/v1/$u/places/$pl/versions?versionType=$VT (x-api-key: $k) and copy it to $CANON"
    exit 0
}
if (-not $env:ROBLOX_API_KEY) { Exit-RigUsage 'publish.ps1: set ROBLOX_API_KEY (Open Cloud API key) in the environment' }
if (-not $env:UNIVERSE_ID) { Exit-RigUsage 'publish.ps1: set UNIVERSE_ID' }
if (-not $env:PLACE_ID) { Exit-RigUsage 'publish.ps1: set PLACE_ID' }
$CT = if ($P -like '*.rbxlx') { 'application/xml' } else { 'application/octet-stream' }
$canonDir = Split-Path -Parent $CANON
if ($canonDir) { New-Item -ItemType Directory -Force -Path $canonDir | Out-Null }
$src = (Resolve-Path -LiteralPath $P).ProviderPath
$dst = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($CANON)
if ($src -ne $dst) { Copy-Item -LiteralPath $src -Destination $dst -Force }
$URL = "$BASEURL/universes/v1/$($env:UNIVERSE_ID)/places/$($env:PLACE_ID)/versions?versionType=$VT"
try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch {}

for ($try = 1; $try -le 4; $try++) {
    $code = '000'; $body = ''
    try {
        $r = Invoke-WebRequest -Uri $URL -Method Post -Headers @{ 'x-api-key' = $env:ROBLOX_API_KEY } -ContentType $CT -InFile $dst -UseBasicParsing
        $code = [string][int]$r.StatusCode; $body = Get-RigBodyText $r
    } catch { $e = Get-RigHttpError $_; $code = $e.Code; $body = $e.Body }
    if ($code -eq '200') {
        $v = $null; try { $v = ($body | ConvertFrom-Json).versionNumber } catch {}
        Write-Output "published ($VT) versionNumber=$(if ($null -eq $v) { 'None' } else { $v })"
        exit 0
    }
    Write-Output "publish try ${try}: HTTP $code $(Get-RigHead $body)"
    if ($code -eq '409' -and $try -lt 4) { Start-Sleep -Seconds ($try * 5); continue }
    # 401/403: key wrong, expired, missing scope, or IP not allowed. 404: wrong universe/place pair. 413: file too big.
    exit 1
}
exit 1
