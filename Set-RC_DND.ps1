
# ===================================================================
#  RINGCENTRAL - FULLY AUTOMATED PERMANENT JWT AUTH + PRESENCE UPDATE
#  ONE SCRIPT. NO EXPIRATION. NO INPUTS. NO DEPENDENCIES.
# ===================================================================

# ---------------------
# HARD-CODED CREDENTIALS
# ---------------------
$ClientId     = 
$ClientSecret = 
$Server       = 
$Jwt          = 

# ---------------------
# STATIC SETTINGS
# ---------------------
$CachePath   = "$env:LOCALAPPDATA\RingCentral\token-cache.json"
$SkewSeconds = 120
$DndStatus   = "DoNotAcceptAnyCalls"

# ===================================================================
# TOKEN RETRIEVAL USING JWT  (NEVER EXPIRES)
# ===================================================================
function Get-RcAccessToken {
    $null = New-Item -ItemType Directory -Force -Path (Split-Path $CachePath) -ErrorAction SilentlyContinue
    $now = [DateTimeOffset]::UtcNow

    if (Test-Path $CachePath) {
        try {
            $cache = Get-Content $CachePath -Raw | ConvertFrom-Json
            if ($cache.AccessToken -and $cache.ExpiresAtUtc) {
                if ([DateTimeOffset]::Parse($cache.ExpiresAtUtc) -gt $now.AddSeconds($SkewSeconds)) {
                    return $cache.AccessToken
                }
            }
        } catch {}
    }

    $basic = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($ClientId + ":" + $ClientSecret))
    $tokenUrl = $Server.TrimEnd("/") + "/restapi/oauth/token"

    $headers = @{
        Authorization = "Basic $basic"
        Accept = "application/json"
        "Content-Type" = "application/x-www-form-urlencoded"
    }

    $body = @{
        grant_type = "urn:ietf:params:oauth:grant-type:jwt-bearer"
        assertion  = $Jwt
    }

    $resp = Invoke-RestMethod -Method Post -Uri $tokenUrl -Headers $headers -Body $body -ErrorAction Stop
    $expiresAt = $now.AddSeconds([int]$resp.expires_in).UtcDateTime.ToString("o")

    [pscustomobject]@{
        AccessToken  = $resp.access_token
        ExpiresAtUtc = $expiresAt
    } | ConvertTo-Json | Set-Content $CachePath -Encoding UTF8

    return $resp.access_token
}

# ===================================================================
# PRESENCE UPDATE
# ===================================================================
$AccessToken = Get-RcAccessToken

$uri = "$Server/restapi/v1.0/account/~/extension/~/presence"
$body = [pscustomobject]@{
    dndStatus = $DndStatus
} | ConvertTo-Json

$headers = @{
    Authorization = "Bearer $AccessToken"
    Accept = "application/json"
    "Content-Type" = "application/json"
}

try {
    $res = Invoke-RestMethod -Uri $uri -Method Put -Headers $headers -Body $body -ErrorAction Stop
    Write-Host "SUCCESS: Presence updated" -ForegroundColor Green
    $res
}
catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    if ($_.ErrorDetails) { $_.ErrorDetails.Message }
}
