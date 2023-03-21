<#
.SYNOPSIS
  <Overview of script>
.DESCRIPTION
  <Brief description of script>
.PARAMETER <Parameter_Name>
    <Brief description of parameter input required. Repeat this attribute if required>
.INPUTS
  <Inputs if any, otherwise state None>
.OUTPUTS
  <Outputs if any, otherwise state None - example: Log file stored in C:\Windows\Temp\<name>.log>
.NOTES
  Version:        1.0
  Author:         <Name>
  Creation Date:  <Date>
  Purpose/Change: Initial script development
  
.EXAMPLE
https://learn.microsoft.com/en-us/powershell/azure/active-directory/install-msonlinev1?source=recommendations&view=azureadps-1.0

  <Example goes here. Repeat this attribute for more than one example>
#>



# Tests required Connection and or Installation of MSOnline Module

Try {
    $MsOn = ((Get-MsolCompanyInformation -ErrorAction Stop | Select-Object InitialDomain).InitialDomain) -split "\." -replace "\." | Select-Object -First 1
    Write-Host "You're currently connected to"$MsOn" Office 365 Online Module" -BackgroundColor DarkGreen
  
  }
  Catch {
    Write-Host "You are not connected to any Microsoft Office Online Tenants" -BackgroundColor Red
    Write-Host "Please login to your Office 365 Tenant"
    Connect-MsolService
  }


Write-Host "Finding Azure Active Directory Accounts..."

$Users = Get-MsolUser -All -EnabledFilter EnabledOnly | Where-Object { $_.UserType -ne "Guest" }

# Creates Output ojbect list that allows for the creation of an output file
$Report = [System.Collections.Generic.List[Object]]::new() 

Write-Host "Processing" $Users.Count "accounts..." 


ForEach ($User in $Users) {
    $MFAEnforced = $User.StrongAuthenticationRequirements.State
    $MFAPhone = $User.StrongAuthenticationUserDetails.PhoneNumber
    $DefaultMFAMethod = ($User.StrongAuthenticationMethods | Where-Object { $_.IsDefault -eq "True" }).MethodType
    If (($MFAEnforced -eq "Enforced") -or ($MFAEnforced -eq "Enabled")) {
        Switch ($DefaultMFAMethod) {
            "OneWaySMS" { $MethodUsed = "One-way SMS" }
            "TwoWayVoiceMobile" { $MethodUsed = "Phone call verification" }
            "PhoneAppOTP" { $MethodUsed = "Hardware token or authenticator app" }
            "PhoneAppNotification" { $MethodUsed = "Authenticator app" }
        }
    }
    Else {
        $MFAEnforced = "Not Enabled"
        $MethodUsed = "MFA Not Used" 
    }
  
    $ReportLine = [PSCustomObject] @{
        User        = $User.UserPrincipalName
        Name        = $User.DisplayName
        MFAUsed     = $MFAEnforced
        MFAMethod   = $MethodUsed 
        PhoneNumber = $MFAPhone
    }
                 
    $Report.Add($ReportLine) 
}


#Output Configuration

#   Generate Name data
$Date = Get-Date
$Company = ((Get-MsolCompanyInformation | Select-Object InitialDomain).InitialDomain) -split "\." -replace "\." | Select-Object -First 1
$Name = ("MFA-Report", $Company, $Date.Month, $Date.Day, $Date.Year, $Date.Second) -join "."
#   Save report to .CSV file
$Report | Sort-Object Name | Export-CSV -NoTypeInformation -Encoding UTF8 $ENV:TEMP\$Name.csv
#   Confirmation box
$title = 'Confirm'
$question = 'Do you want to open file in Excel?'
$choices = '&Yes', '&No'
$decision = $Host.UI.PromptForChoice($title, $question, $choices, 1)
#   Logic for Confirmation box
if ($decision -eq 0) {
    Write-Host "Opening in Excel..."
    Start-Process Excel $ENV:TEMP\$Name.csv
}
else {
    Write-Host "The Report is located in $ENV:TEMP\MFAUsers.csv"
}