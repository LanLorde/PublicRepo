#--------------------------------------------------------------------------------
#
# check Microsoft.Graph is installed
#
#
$getmodule=get-module -listavailable "Microsoft.Graph"|sort version -Descending

$installedversion=($getmodule|select -first 1).version

if(-not $getmodule)
{
    $install = Read-Host 'The Microsoft.Graph PowerShell module is not installed. Do you want to install it now? (Y/n)'
    if($install -eq '' -Or $install -eq 'Y' -Or $install -eq 'Yes')
    {  
        If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))
        {
            Write-Warning "Administrator permissions are needed to install the Microsoft.Graph PowerShell module.`nPlease re-run this script as an Administrator."
            Exit
        }
        install-module Microsoft.Graph -scope AllUsers
    }
    else
    {
        exit
    }
}
#------------------------------------------------------------------------------

function New-UserMappingCsv {
<#
.SYNOPSIS
Builds a User Mapping CSV for ProfWiz: OldDomainSam (DOMAIN\samAccountName) → AzureUPN.
Auto-discovers the on-prem AD NetBIOS domain name and matches AD users to Azure AD users.

.PARAMETER OutputPath
Destination path for the CSV (e.g., C:\Migration\UserLookup.csv).

.PARAMETER AdUserFilter
LDAP filter for AD users. Default returns enabled, non-computer accounts.

.PARAMETER MatchStrategy
Primary matching strategy: Email or Username. Default is Email.

.EXAMPLE
New-UserMappingCsv -OutputPath C:\Migration\UserLookup.csv

.EXAMPLE
New-UserMappingCsv -OutputPath \\fileserver\share\UserLookup.csv -MatchStrategy Username
#>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$OutputPath,

        [Parameter(Mandatory=$false)]
        [string]$AdUserFilter = "(&(objectClass=user)(!(objectClass=computer))(userAccountControl:1.2.840.113556.1.4.803:=512))",

        [Parameter(Mandatory=$false)]
        [ValidateSet("Email","Username")]
        [string]$MatchStrategy = "Email"
    )

    begin {
        if (-not (Get-Module -ListAvailable -Name ActiveDirectory)) {
            throw "ActiveDirectory module not found. Install RSAT AD tools on the management workstation."
        }

        $useMg = $false
        if (Get-Module -ListAvailable -Name Microsoft.Graph.Users) { $useMg = $true }
        elseif (-not (Get-Module -ListAvailable -Name AzureAD)) {
            throw "Neither Microsoft.Graph.Users nor AzureAD module found. Install one to query Azure AD users."
        }

        $adDomain = Get-ADDomain
        $netbios  = $adDomain.NetBIOSName
        $fqdn     = $adDomain.DNSRoot
    }

    process {
        # AD users
        $adUsers = Get-ADUser -LDAPFilter $AdUserFilter -Server $fqdn -Properties mail, userPrincipalName, sAMAccountName |
                   ForEach-Object {
                       [pscustomobject]@{
                           SamAccountName = $_.SamAccountName
                           Mail           = $_.Mail
                           AdUPN          = $_.UserPrincipalName
                           OldDomainSam   = "{0}\{1}" -f $netbios, $_.SamAccountName
                       }
                   }

        if (-not $adUsers -or $adUsers.Count -eq 0) {
            throw "No AD users matched the filter. Adjust -AdUserFilter."
        }

        # Azure AD users
        $aadUsers = $null
        if ($useMg) {
            if (-not (Get-MgContext)) { Connect-MgGraph -Scopes User.Read.All | Out-Null }
            $aadUsers = Get-MgUser -All -Property Id,UserPrincipalName,Mail,ProxyAddresses |
                        ForEach-Object {
                            [pscustomobject]@{
                                AADId   = $_.Id
                                UPN     = $_.UserPrincipalName
                                Mail    = $_.Mail
                                Aliases = $_.ProxyAddresses
                                UPNUser = ($_.UserPrincipalName -split "@")[0]
                            }
                        }
        }
        else {
            if (-not (Get-Command Get-AzureADUser -ErrorAction SilentlyContinue)) { Connect-AzureAD | Out-Null }
            $aadUsers = Get-AzureADUser -All $true |
                        ForEach-Object {
                            [pscustomobject]@{
                                AADId   = $_.ObjectId
                                UPN     = $_.UserPrincipalName
                                Mail    = $_.Mail
                                Aliases = $_.ProxyAddresses
                                UPNUser = ($_.UserPrincipalName -split "@")[0]
                            }
                        }
        }

        if (-not $aadUsers -or $aadUsers.Count -eq 0) {
            throw "No Azure AD users returned. Verify module connection and permissions."
        }

        # Build mapping via pipeline (no +=)
        $mappings =
            $adUsers | ForEach-Object {
                $adUser = $_
                $candidate = $null

                if ($MatchStrategy -eq "Email" -and $adUser.Mail) {
                    # 1) Direct mail match
                    $candidate = $aadUsers | Where-Object { $_.Mail -and ($_.Mail -ieq $adUser.Mail) }

                    # 2) ProxyAddresses match (smtp:alias)
                    if (-not $candidate) {
                        $candidate = $aadUsers | Where-Object {
                            $_.Aliases -and ($_.Aliases -icontains ("smtp:{0}" -f $adUser.Mail))
                        }
                    }
                }

                if (-not $candidate) {
                    # Fallback: local-part of UPN equals sAMAccountName
                    $candidate = $aadUsers | Where-Object { $_.UPNUser -ieq $adUser.SamAccountName }
                }

                $azureUpn = $null
                if ($candidate) {
                    # Prefer UPN domain alignment with on-prem DNS root if present
                    $azureUpn = ($candidate | Sort-Object {
                        if ($_.UPN -like "*@$fqdn") { 0 } else { 1 }
                    } | Select-Object -First 1).UPN
                }

                [pscustomobject]@{
                    OldDomainSam = $adUser.OldDomainSam
                    AzureUPN     = $azureUpn
                    SourceMail   = $adUser.Mail
                    SourceUPN    = $adUser.AdUPN
                }
            }

        # Warn on unmapped rows
        $unmapped = $mappings | Where-Object { -not $_.AzureUPN }
        if ($unmapped -and $unmapped.Count -gt 0) {
            Write-Warning ("{0} users could not be matched to Azure AD UPN. Review SourceMail/SourceUPN." -f $unmapped.Count)
        }

        # Export only required columns
        $mappings | Select-Object OldDomainSam, AzureUPN | Export-Csv -Path $OutputPath -NoTypeInformation
        Write-Host ("User mapping written to {0}" -f $OutputPath)
    }

    end { }
}
