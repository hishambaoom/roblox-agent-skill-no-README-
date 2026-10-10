# Change a game pass or developer product price (and/or for-sale flag) through Open Cloud.
# PowerShell twin of prices.sh (pwsh 7 / Windows PowerShell 5.1).
# usage: tools\rig\prices.ps1 pass    <gamePassId> <priceRobux> [isForSale=true]
#        tools\rig\prices.ps1 product <productId>  <priceRobux> [isForSale=true]
# env:   ROBLOX_API_KEY (needs the game-pass / developer-product write scopes for this universe), UNIVERSE_ID
#        OPEN_CLOUD_BASE (default https://apis.roblox.com; only for pointing the rig at a local mock server)
# Endpoints (Open Cloud reference, features/game-passes and features/developer-products), multipart/form-data body:
#   PATCH https://apis.roblox.com/game-passes/v1/universes/{universeId}/game-passes/{gamePassId}
#   PATCH https://apis.roblox.com/developer-products/v2/universes/{universeId}/developer-products/{productId}
# A price is a money decision: only run this with the owner's explicit number. Report old -> new.
. (Join-Path $PSScriptRoot 'config.ps1')
if (-not $env:ROBLOX_API_KEY) { [Console]::Error.WriteLine('prices.ps1: set ROBLOX_API_KEY'); exit 1 }
if (-not $env:UNIVERSE_ID) { [Console]::Error.WriteLine('prices.ps1: set UNIVERSE_ID'); exit 1 }
if ($args.Count -lt 3) { [Console]::Error.WriteLine('usage: prices.ps1 pass|product <id> <price> [isForSale=true]'); exit 1 }
$KIND = [string]$args[0]; $ID = [string]$args[1]; $PRICE = [string]$args[2]
$SALE = if ($args.Count -gt 3) { [string]$args[3] } else { 'true' }
$BASEURL = if ($env:OPEN_CLOUD_BASE) { $env:OPEN_CLOUD_BASE.TrimEnd('/') } else { 'https://apis.roblox.com' }
switch ($KIND) {
    'pass'    { $URL = "$BASEURL/game-passes/v1/universes/$($env:UNIVERSE_ID)/game-passes/$ID" }
    'product' { $URL = "$BASEURL/developer-products/v2/universes/$($env:UNIVERSE_ID)/developer-products/$ID" }
    default   { Write-Output 'kind must be pass or product'; exit 2 }
}
try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch {}
# multipart/form-data built by hand: Windows PowerShell 5.1 has no -Form parameter
$bd = [Guid]::NewGuid().ToString('N'); $nl = "`r`n"
$body = "--$bd${nl}Content-Disposition: form-data; name=`"price`"${nl}${nl}$PRICE${nl}" +
        "--$bd${nl}Content-Disposition: form-data; name=`"isForSale`"${nl}${nl}$SALE${nl}--$bd--$nl"
$code = '000'; $resp = ''
try {
    $r = Invoke-WebRequest -Uri $URL -Method Patch -Headers @{ 'x-api-key' = $env:ROBLOX_API_KEY } `
         -ContentType "multipart/form-data; boundary=$bd" -Body ([Text.Encoding]::UTF8.GetBytes($body)) -UseBasicParsing
    $code = [string][int]$r.StatusCode; $resp = Get-RigBodyText $r
} catch { $e = Get-RigHttpError $_; $code = $e.Code; $resp = $e.Body }
$resp = Get-RigHead $resp
Write-Output "$KIND $ID -> $PRICE R`$ (isForSale=$SALE): HTTP $code $resp"
if ($code -eq '200' -or $code -eq '204') { exit 0 } else { exit 1 }
