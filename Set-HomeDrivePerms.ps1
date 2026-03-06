function Set-HomeDirectoryAndAcl {
<#
.SYNOPSIS
Updates users’ AD HomeDirectory by replacing a path prefix AND sets NTFS ACLs on the resulting full path (user folder), safely and consistently.

.DESCRIPTION
For each user whose HomeDirectory starts with OldPathPrefix, this updates the attribute to NewPathPrefix (preserving the remainder of the path), ensures the folder exists at the updated full path, then applies a canonical ACL:
- User: FullControl (or Modify if -UseModifyForUser)
- <Domain NetBIOS>\Domain Admins: FullControl
- BUILTIN\Administrators: FullControl
- NT AUTHORITY\SYSTEM: FullControl
Inheritance is disabled (not copied), all explicit ACEs are removed, then the canonical ACEs are applied.
Supports -WhatIf/-Confirm.

.PARAMETER OldPathPrefix
Existing starting UNC prefix to replace (e.g. \\OLD-SRV\Homes).

.PARAMETER NewPathPrefix
New starting UNC prefix (e.g. \\NEW-SRV\Homes).

.PARAMETER IncludeDisabled
Include disabled accounts (default skips disabled).

.PARAMETER Server
Optional AD DC to query.

.PARAMETER Credential
Optional PSCredential for AD operations.

.PARAMETER UseModifyForUser
Grant Modify to the user instead of FullControl.

.PARAMETER OnlySetAcl
Do not touch the AD attribute; only set ACLs based on the user’s current HomeDirectory (useful for a second pass).

.EXAMPLE
Set-HomeDirectoryAndAcl -OldPathPrefix \\OLD-SRV\Homes -NewPathPrefix \\NEW-SRV\Homes -WhatIf

Dry run: shows what would change.

.EXAMPLE
Set-HomeDirectoryAndAcl -OldPathPrefix \\fs01\home$ -NewPathPrefix \\fs02\home$ -UseModifyForUser -Confirm:$false

Updates attribute and sets ACLs; user gets Modify, admins/system get FullControl.

.EXAMPLE
Set-HomeDirectoryAndAcl -OldPathPrefix \\old\users -NewPathPrefix \\new\users -OnlySetAcl -WhatIf

Leaves AD paths alone, re-applies ACLs on current folders (no attribute updates).
#>
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
    param(
        [Parameter(Mandatory = $true)]
        [ValidatePattern('^\\\\')]
        [string] $OldPathPrefix,

        [Parameter(Mandatory = $true)]
        [ValidatePattern('^\\\\')]
        [string] $NewPathPrefix,

        [Parameter(Mandatory = $false)]
        [switch] $IncludeDisabled,

        [Parameter(Mandatory = $false)]
        [string] $Server,

        [Parameter(Mandatory = $false)]
        [pscredential] $Credential,

        [Parameter(Mandatory = $false)]
        [switch] $UseModifyForUser,

        [Parameter(Mandatory = $false)]
        [switch] $OnlySetAcl
    )

    begin {
        Import-Module ActiveDirectory -ErrorAction Stop

        $adGetParams = @{
            Properties     = @('homeDirectory','enabled','samAccountName','userPrincipalName')
            ResultPageSize = 2000
        }
        if ($PSBoundParameters.ContainsKey('Server'))     { $adGetParams.Server = $Server }
        if ($PSBoundParameters.ContainsKey('Credential')) { $adGetParams.Credential = $Credential }

        $adSetParamsCommon = @{}
        if ($PSBoundParameters.ContainsKey('Server'))     { $adSetParamsCommon.Server = $Server }
        if ($PSBoundParameters.ContainsKey('Credential')) { $adSetParamsCommon.Credential = $Credential }

        $domainNB = (Get-ADDomain @($Server ? @{Server=$Server} : @()) @($Credential ? @{Credential=$Credential} : @())).NetBIOSName

        # Pre-resolve admin principals to SIDs (fail fast if wrong)
        $sidAdmins  = (New-Object System.Security.Principal.NTAccount("$domainNB","Domain Admins")).Translate([System.Security.Principal.SecurityIdentifier])
        $sidBuiltin = (New-Object System.Security.Principal.NTAccount("BUILTIN","Administrators")).Translate([System.Security.Principal.SecurityIdentifier])
        $sidSystem  = (New-Object System.Security.Principal.NTAccount("NT AUTHORITY","SYSTEM")).Translate([System.Security.Principal.SecurityIdentifier])

        $rightsUser = if ($UseModifyForUser) { 'Modify' } else { 'FullControl' }

        $escapedOld = [regex]::Escape($OldPathPrefix)
        $startsWith = "^(?i)$escapedOld"
        $now = Get-Date
    }

    process {
        # Pull users that have a HomeDirectory set; filter by enabled unless overridden
        $filterParts = @("(homeDirectory -like '*')")
        if (-not $IncludeDisabled) { $filterParts += "(enabled -eq 'true')" }
        $ldapFilter = "(&" + ($filterParts -join '') + ")"

        $users = Get-ADUser @adGetParams -LDAPFilter $ldapFilter

        foreach ($u in $users) {
            $current = $u.HomeDirectory

            if ([string]::IsNullOrWhiteSpace($current)) { continue }

            $needsUpdate = $false
            $targetPath = $current

            if (-not $OnlySetAcl) {
                if ($current -match $startsWith) {
                    $targetPath = $current -replace $startsWith, $NewPathPrefix
                    $needsUpdate = $true
                } else {
                    # HomeDirectory does not start with OldPathPrefix; skip attribute update but still consider ACL if it already points at the new root
                    if ($current.StartsWith($NewPathPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
                        $targetPath = $current
                    } else {
                        # Neither old nor new prefix; skip entirely
                        continue
                    }
                }
            } else {
                # Only setting ACLs: use existing full path
                $targetPath = $current
            }

            # 1) Update AD attribute if needed
            if ($needsUpdate) {
                if ($PSCmdlet.ShouldProcess("$($u.SamAccountName)", "Set-ADUser HomeDirectory to $targetPath")) {
                    try {
                        $adSetParams = $adSetParamsCommon.Clone()
                        $adSetParams.Identity = $u.DistinguishedName
                        $adSetParams.Replace = @{ homeDirectory = $targetPath }
                        Set-ADUser @adSetParams
                    } catch {
                        Write-Error "Failed to update HomeDirectory for $($u.SamAccountName) to '$targetPath': $($_.Exception.Message)"
                        continue
                    }
                }
            }

            # 2) Ensure folder exists at the full updated path
            if ($PSCmdlet.ShouldProcess($targetPath, "Ensure home folder exists")) {
                try {
                    if (-not (Test-Path -LiteralPath $targetPath)) {
                        New-Item -ItemType Directory -Path $targetPath | Out-Null
                    }
                } catch {
                    Write-Error "Failed to create or access '$targetPath' for $($u.SamAccountName): $($_.Exception.Message)"
                    continue
                }
            }

            # 3) Apply canonical ACLs on the full path
            try {
                $acl = Get-Acl -LiteralPath $targetPath

                # Disable inheritance, do not copy
                $acl.SetAccessRuleProtection($true, $false)

                # Remove explicit ACEs
                foreach ($ace in @($acl.Access)) { $null = $acl.RemoveAccessRule($ace) }

                # Resolve the user identity to SID (domain resolution via simple name works for domain user folders)
                $sidUser = (New-Object System.Security.Principal.NTAccount($u.SamAccountName)).Translate([System.Security.Principal.SecurityIdentifier])

                $inheritFlags = 'ContainerInherit,ObjectInherit'
                $propagation  = 'None'

                $ruleUser = New-Object System.Security.AccessControl.FileSystemAccessRule($sidUser,   $rightsUser,   $inheritFlags, $propagation, 'Allow')
                $ruleAdm  = New-Object System.Security.AccessControl.FileSystemAccessRule($sidAdmins, 'FullControl', $inheritFlags, $propagation, 'Allow')
                $ruleBlt  = New-Object System.Security.AccessControl.FileSystemAccessRule($sidBuiltin,'FullControl', $inheritFlags, $propagation, 'Allow')
                $ruleSys  = New-Object System.Security.AccessControl.FileSystemAccessRule($sidSystem, 'FullControl', $inheritFlags, $propagation, 'Allow')

                $null = $acl.AddAccessRule($ruleUser)
                $null = $acl.AddAccessRule($ruleAdm)
                $null = $acl.AddAccessRule($ruleBlt)
                $null = $acl.AddAccessRule($ruleSys)

                if ($PSCmdlet.ShouldProcess($targetPath, "Set NTFS ACLs")) {
                    Set-Acl -Path $targetPath -AclObject $acl
                }

                [pscustomobject]@{
                    TimeStamp      = $now
                    SamAccountName = $u.SamAccountName
                    OldHomeDir     = $current
                    NewHomeDir     = $targetPath
                    UpdatedAttr    = $needsUpdate
                    AclApplied     = $true
                    UserRight      = $rightsUser
                }
            } catch {
                Write-Error "ACL update failed for '$targetPath' ($($u.SamAccountName)): $($_.Exception.Message)"
                [pscustomobject]@{
                    TimeStamp      = $now
                    SamAccountName = $u.SamAccountName
                    OldHomeDir     = $current
                    NewHomeDir     = $targetPath
                    UpdatedAttr    = $needsUpdate
                    AclApplied     = $false
                    Error          = $_.Exception.Message
                }
            }
        }
    }
}
