
<#
.SYNOPSIS
Updates Display Names of all Active Directory users in a specified OU to Title Case (First Letter Caps).

.EXAMPLE
Set-ADUsersDisplayNameTitleCase -OU "OU=Sales,DC=domain,DC=com"
.EXAMPLE
Set-ADUsersDisplayNameTitleCase -OU "OU=IT,OU=Departments,DC=domain,DC=com" -DomainController DC01 -WhatIf
#>

function Set-ADUsersDisplayNameTitleCase {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true)]
        [string]$OU,

        [Parameter()]
        [string]$DomainController
    )

    $users = Get-ADUser -Filter * -SearchBase $OU -Properties DisplayName -Server $DomainController
    if (-not $users) {
        Write-Error "No users found in OU: $OU"
        return
    }

    $textInfo = (Get-Culture).TextInfo
    $results = New-Object System.Collections.Generic.List[PSObject]


foreach ($user in $users) {
   
$oldName = $user.DisplayName.Trim() -replace '\s+', ' '
$newName = $textInfo.ToTitleCase(($user.DisplayName.ToLower()).Trim()) -replace '\s+', ' '

if ($oldName -cne $newName) {
    if ($PSCmdlet.ShouldProcess($user.SamAccountName, "Update DisplayName to '$newName'")) {
        Set-ADUser -Identity $user.DistinguishedName -Replace @{ displayName = $newName } -Verbose
    }
    $status = "Updated"
} else {
    $status = "No Change"
}


    $results.Add([PSCustomObject]@{
        SamAccountName = $user.SamAccountName
        OldDisplayName = $oldNameNormalized
        NewDisplayName = $newNameNormalized
        Status         = $status
    })
}


    $results | Format-Table -AutoSize
}
