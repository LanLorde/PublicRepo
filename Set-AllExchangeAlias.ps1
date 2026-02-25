#Requires -Version 5.1
[CmdletBinding(SupportsShouldProcess=$true)]
param()

function Test-ExchangeConnection {
    try {
        $null = Get-OrganizationConfig -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

function Connect-EXO {
    Write-Host "Not connected to Exchange Online." -ForegroundColor Yellow
    if (-not (Get-Module -ListAvailable -Name ExchangeOnlineManagement)) {
        Install-Module -Name ExchangeOnlineManagement -Force -AllowClobber
    }
    Import-Module ExchangeOnlineManagement
    Connect-ExchangeOnline -ShowBanner:$false
}

function Get-Domains {
    try {
        return @(Get-AcceptedDomain | Select-Object -ExpandProperty Name)
    } catch {
        Write-Error "Failed to get domains: $_"
        return @()
    }
}

function Add-Aliases {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param([Parameter(Mandatory=$true)][string[]]$Domains)
    
    if (-not $Domains) { return }
    
    $allUsers = Get-Mailbox -ResultSize Unlimited
    $users = $allUsers | Where-Object {$_.RecipientTypeDetails -notmatch 'Discovery'}
    $added = 0
    $skipped = 0
    
    foreach ($user in $users) {
        $upn = $user.UserPrincipalName
        $primary = ($user.PrimarySmtpAddress -split '@')[1]
        
        foreach ($domain in $Domains) {
            if ($domain -eq $primary) { 
                $skipped++
                continue 
            }
            
            $alias = $upn.Split('@')[0] + "@$domain"
            
            $exists = $user.EmailAddresses | Where-Object {$_ -eq "smtp:$alias"}
            if ($exists) { 
                $skipped++
                continue 
            }
            
            if ($PSCmdlet.ShouldProcess($upn, "Add alias $alias")) {
                try {
                    Set-Mailbox -Identity $upn -EmailAddresses @{add=$alias} -ErrorAction Stop
                    Write-Host "Added: $alias" -ForegroundColor Green
                    $added++
                } catch {
                    Write-Host "Failed: $alias - $_" -ForegroundColor Red
                }
            }
        }
    }
    
    Write-Host "`nAdded: $added | Skipped: $skipped" -ForegroundColor Cyan
}

Write-Host "Exchange Alias Management" -ForegroundColor Cyan

if (-not (Test-ExchangeConnection)) {
    Connect-EXO
}

$domains = Get-Domains
Write-Host "Domains: $($domains -join ', ')" -ForegroundColor Green

$resp = Read-Host "Proceed? (y/n)"
if ($resp -eq 'y') {
    Add-Aliases -Domains $domains
}
