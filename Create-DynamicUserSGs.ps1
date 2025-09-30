<#
.SYNOPSIS
Creates or updates a **Security** group with **dynamic user membership** in Entra ID.

.DESCRIPTION
Creates a new Security group with GroupTypes = "DynamicMembership" and applies the specified user membership rule. 
If a group with the same DisplayName already exists and -UpdateIfExists is supplied, updates its MembershipRule and sets MembershipRuleProcessingState to "On".
The function verifies a working Microsoft Graph connection and will connect to the specified -TenantId if needed.

.PARAMETER DisplayName
Display name for the Security group.

.PARAMETER MembershipRule
Dynamic membership rule (user-based). Examples: 
    (user.userType -eq "Guest")
    (user.accountEnabled -eq false)
    (user.userType -eq "Member") and -not (user.assignedPlans -any (assignedPlan.capabilityStatus -eq "Enabled"))

.PARAMETER Description
Optional group description. Defaults to "Created by automation".

.PARAMETER TenantId
Target tenant GUID. If connected to a different tenant, the function reconnects to this tenant.

.PARAMETER UpdateIfExists
If supplied, updates the existing group with the same DisplayName instead of failing on duplicate.

.PARAMETER SkipModuleInstall
If supplied, does not attempt to install Microsoft.Graph when missing.

.EXAMPLE
Create a **Guest Users** dynamic Security group in the specified tenant
New-EnterpriseDynamicGroup -DisplayName "Guest Users" -Description "All guest accounts" -MembershipRule '(user.userType -eq "Guest")' -TenantId aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee

.EXAMPLE
Create a **Blocked Users** dynamic Security group (disabled accounts)
New-EnterpriseDynamicGroup -DisplayName "Blocked Users" -Description "All disabled accounts" -MembershipRule '(user.accountEnabled -eq false)' -TenantId aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee

.EXAMPLE
Create an **Unlicensed Users** dynamic Security group (Members with no enabled plans)
New-EnterpriseDynamicGroup -DisplayName "Unlicensed Users" -Description "Members without enabled service plans" -MembershipRule '(user.userType -eq "Member") and -not (user.assignedPlans -any (assignedPlan.capabilityStatus -eq "Enabled"))' -TenantId aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee

.EXAMPLE
Update an existing **Unlicensed Users** group’s rule (idempotent update)
New-EnterpriseDynamicGroup -DisplayName "Unlicensed Users" -Description "Members without enabled service plans" -MembershipRule '(user.userType -eq "Member") and -not (user.assignedPlans -any (assignedPlan.capabilityStatus -eq "Enabled"))' -TenantId aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee -UpdateIfExists

.OUTPUTS
[pscustomobject] containing TenantId, GroupId, DisplayName, MailNickname, Kind, Action, MembershipRule.

.NOTES
• Dynamic membership requires Microsoft Entra ID P1. 
• Rule syntax reference: Microsoft Learn. 
#>

# Connect to Partner Center once
# Connect-PartnerCenter


function Ensure-GraphModule {
    [CmdletBinding()]
    param(
        [switch] $SkipInstall
    )
    $mod = Get-Module Microsoft.Graph -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1
    if (-not $mod -and -not $SkipInstall) {
        Install-Module Microsoft.Graph -Scope AllUsers -Force
    }
    elseif (-not $mod -and $SkipInstall) {
        throw "Microsoft.Graph module not found. Install it or omit -SkipInstall."
    }
}

function Connect-GraphIfNeeded {
    [CmdletBinding()]
    param(
        [string] $TenantId,
        [string[]] $Scopes = @('Group.ReadWrite.All','Directory.Read.All')
    )

    $ctx = $null
    try { $ctx = Get-MgContext } catch { }

    $connected = ($ctx -and $ctx.Account -and $ctx.TenantId)
    $tenantMismatch = ($TenantId -and $connected -and ($ctx.TenantId -ne $TenantId))

    if (-not $connected -or $tenantMismatch) {
        if ($tenantMismatch) {
            Disconnect-MgGraph -ErrorAction SilentlyContinue
        }
        $connectParams = @{
            Scopes = $Scopes
        }
        if ($TenantId) { $connectParams['TenantId'] = $TenantId }
        Connect-MgGraph @connectParams | Out-Null
        $ctx = Get-MgContext
    }

    if (-not $ctx -or (-not $ctx.TenantId)) {
        throw "Unable to establish Microsoft Graph connection."
    }
    [pscustomobject]@{
        TenantId   = $ctx.TenantId
        Account    = $ctx.Account
        Scopes     = $ctx.Scopes
        Connected  = $true
        Cloud      = $ctx.Environment
    }
}

function New-EnterpriseDynamicGroup {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
    param(
        [Parameter(Mandatory)]
        [string] $DisplayName,

        [Parameter(Mandatory)]
        [string] $MembershipRule,

        [string] $Description = "Created by SpotMigration automation",

        [string] $TenantId,

        [switch] $UpdateIfExists,
        [switch] $SkipModuleInstall
    )

    Ensure-GraphModule -SkipInstall:$SkipModuleInstall
    $conn = Connect-GraphIfNeeded -TenantId $TenantId

    $found = Get-MgGroup -Filter "displayName eq '$DisplayName'" -ConsistencyLevel eventual -CountVariable cnt -All

    $mailNick = ($DisplayName -replace '[^a-zA-Z0-9]', '').ToLower() + ((Get-Random -Minimum 100 -Maximum 999).ToString())

    $newParams = @{
        DisplayName                      = $DisplayName
        Description                      = $Description
        MailNickname                     = $mailNick
        MailEnabled                      = $false
        SecurityEnabled                  = $true
        GroupTypes                       = @('DynamicMembership')
        MembershipRule                   = $MembershipRule
        MembershipRuleProcessingState    = 'On'
    }

    if ($found) {
        $target = $found | Select-Object -First 1
        $action = 'NoChange'
        if ($UpdateIfExists) {
            if ($PSCmdlet.ShouldProcess("$($target.Id)", "Update dynamic rule")) {
                $updateParams = @{
                    GroupId                         = $target.Id
                    MembershipRule                  = $MembershipRule
                    MembershipRuleProcessingState   = 'On'
                    Description                     = $Description
                }
                Update-MgGroup @updateParams
                $action = 'Updated'
            }
        }
        [pscustomobject]@{
            TenantId        = $conn.TenantId
            GroupId         = $target.Id
            DisplayName     = $DisplayName
            Action          = $action
            MembershipRule  = $MembershipRule
        }
    }
    else {
        if ($PSCmdlet.ShouldProcess($DisplayName, "Create dynamic Security group")) {
            $created = New-MgGroup @newParams
            [pscustomobject]@{
                TenantId        = $conn.TenantId
                GroupId         = $created.Id
                DisplayName     = $DisplayName
                Action          = 'Created'
                MembershipRule  = $MembershipRule
            }
        }
    }
}

function Create-StandardDynamicGroups {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string] $TenantId,

        [switch] $UpdateIfExists,
        [switch] $SkipModuleInstall
    )

    $results = [System.Collections.Generic.List[object]]::new()

    $sets = @(
        [pscustomobject]@{
            DisplayName    = 'Guest Users'
            Description    = 'SM - All guest accounts'
            Rule           = '(user.userType -eq "Guest")'
        },
        [pscustomobject]@{
            DisplayName    = 'Blocked Users'
            Description    = 'SM - All disabled accounts'
            Rule           = '(user.accountEnabled -eq false)'
        },
        [pscustomobject]@{
            DisplayName    = 'Unlicensed Users'
            Description    = 'SM - All members without any enabled service plans'
            Rule           = '(user.userType -eq "Member") and -not (user.assignedPlans -any (assignedPlan.capabilityStatus -eq "Enabled"))'
        },
        [pscustomobject]@{
            DisplayName    = 'Active Users'
            Description    = 'SM - All active users'
            Rule           = '(user.accountEnabled -eq True) and (user.userType -eq "Member") and (user.assignedPlans -any (assignedplan.serviceplanid -ne null))'
        }
    )

    foreach ($s in $sets) {
        $params = @{
            DisplayName      = $s.DisplayName
            Description      = $s.Description
            MembershipRule   = $s.Rule
            TenantId         = $TenantId
            UpdateIfExists   = $UpdateIfExists
            SkipModuleInstall= $SkipModuleInstall
            Confirm          = $false
        }
        $out = New-EnterpriseDynamicGroup @params
        if ($out) { $results.Add($out) | Out-Null }
    }
    $results
}

function Create-DynamicGroupsForAllCustomers {
    [CmdletBinding()]
    param(
        [string[]] $IncludeDomains,
        [string[]] $ExcludeDomains,
        [string[]] $IncludeTenantIds,
        [string[]] $ExcludeTenantIds,
        [switch]   $UpdateIfExists,
        [string]   $OutputCsv,
        [switch]   $SkipModuleInstall
    )

    function Ensure-PartnerCenterModule {
        [CmdletBinding()]
        param([switch] $SkipInstall)
        $mod = Get-Module PartnerCenter -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1
        if (-not $mod -and -not $SkipInstall) {
            Install-Module PartnerCenter -Scope AllUsers -Force
        }
        elseif (-not $mod -and $SkipInstall) {
            throw "PartnerCenter module not found. Install it or omit -SkipInstall."
        }
    }

    function Ensure-GraphModule {
        [CmdletBinding()]
        param([switch] $SkipInstall)
        $mod = Get-Module Microsoft.Graph -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1
        if (-not $mod -and -not $SkipInstall) {
            Install-Module Microsoft.Graph -Scope AllUsers -Force
        }
        elseif (-not $mod -and $SkipInstall) {
            throw "Microsoft.Graph module not found. Install it or omit -SkipInstall."
        }
    }

    Ensure-PartnerCenterModule -SkipInstall:$SkipModuleInstall
    Ensure-GraphModule        -SkipInstall:$SkipModuleInstall

    # Single interactive sign-in to Partner Center
    try {
        if (-not (Get-Command Get-PartnerCustomer -ErrorAction SilentlyContinue)) {
            throw "PartnerCenter module not loaded."
        }
        # Test Partner Center session; connect if necessary
        try {
            $null = Get-PartnerCustomer -ErrorAction Stop | Select-Object -First 1
        }
        catch {
            Connect-PartnerCenter
        }
    }
    catch {
        throw "Failed to initialize Partner Center session: $($_.Exception.Message)"
    }

    # Enumerate customers
    $customers = Get-PartnerCustomer | Select-Object CompanyProfile.CompanyName, CustomerId, Domain

    # Normalize filters
    $toProcess = $customers

    if ($IncludeTenantIds -and $IncludeTenantIds.Count -gt 0) {
        $set = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        $IncludeTenantIds | ForEach-Object { [void]$set.Add($_) }
        $toProcess = $toProcess | Where-Object { $set.Contains($_.CustomerId) }
    }
    else {
        if ($IncludeDomains -and $IncludeDomains.Count -gt 0) {
            $inc = $IncludeDomains | ForEach-Object { [regex]::Escape($_) }
            $pattern = ($inc -join '|')
            $toProcess = $toProcess | Where-Object { $_.Domain -match $pattern }
        }
        if ($ExcludeDomains -and $ExcludeDomains.Count -gt 0) {
            $exc = $ExcludeDomains | ForEach-Object { [regex]::Escape($_) }
            $pattern = ($exc -join '|')
            $toProcess = $toProcess | Where-Object { $_.Domain -notmatch $pattern }
        }
    }

    if ($ExcludeTenantIds -and $ExcludeTenantIds.Count -gt 0) {
        $ex = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        $ExcludeTenantIds | ForEach-Object { [void]$ex.Add($_) }
        $toProcess = $toProcess | Where-Object { -not $ex.Contains($_.CustomerId) }
    }

    $results = [System.Collections.Generic.List[object]]::new()

    foreach ($cust in $toProcess) {
        $tenantId = $cust.CustomerId
        $name     = $cust.'CompanyProfile.CompanyName'
        $domain   = $cust.Domain

        $row = [pscustomobject]@{
            CompanyName  = $name
            TenantId     = $tenantId
            Domain       = $domain
            Success      = $false
            Error        = $null
            GroupResults = $null
        }

        try {
            # Acquire a Graph token for this tenant via Partner Center refresh token
            $pat = Get-PartnerAccessToken

            $tokenParams = @{
                Resource      = "https://graph.microsoft.com"
                Tenant        = $tenantId
                RefreshToken  = $pat.RefreshToken
                ApplicationId = $pat.ApplicationId
                Scopes        = "https://graph.microsoft.com/.default"
            }
            $token = New-PartnerAccessToken @tokenParams
            # Connect to Graph with the token (no interactive prompt)
            Connect-MgGraph -AccessToken $token.AccessToken | Out-Null

            # Invoke your dynamic Security group creation (Security only)
            $stdParams = @{
                TenantId       = $tenantId
                UpdateIfExists = $UpdateIfExists
                SkipModuleInstall = $SkipModuleInstall
            }
            $grpResults = Create-StandardDynamicGroups @stdParams

            $row.GroupResults = $grpResults
            $row.Success = $true
        }
        catch {
            $row.Error = $_.Exception.Message
        }
        finally {
            # Optional: Disconnect-MgGraph to avoid stale contexts between tenants
            Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null
        }

        $results.Add($row) | Out-Null
    }

    if ($OutputCsv) {
        try { $results | Export-Csv -Path $OutputCsv -NoTypeInformation -Encoding UTF8 }
        catch { Write-Warning "Failed to write CSV '$OutputCsv': $($_.Exception.Message)" }
    }

    $results
}
